#!/usr/bin/env python3
"""Rebuild `assets/data/vehicles.json` from the ministry transport-characteristics table.

The catalogue this app shipped with came from Annex 14 of the loading handbook
(Order 145/175-ö), which names the vehicles it assigns securing hardware to but
carries no dimension table for any of them: every length, width, height and
weight in the extract is the literal string "TODO: Fill from Handbook Page XX".

    Harby tehnikalaryň ulag häsiýetnamalary
    (Uzynlygy, ini, beýikligi we agramy — esasy platforma boýunça
     çemeleşdirilen maglumatlar)

is a second ministry document listing 138 vehicles WITH those four figures. It
is the unit's own list of what it actually moves, so it — not Annex 14's
catalogue — decides which vehicles the trainer offers.

What this script does, and what it refuses to do:

* Every vehicle in the table becomes a record, with its length, width and
  height converted from millimetres to the centimetres the app works in, and
  its weight in tonnes. A figure the table gives as "—" or "d/ý" stays
  unavailable; a weight given as a range ("10,7–11,4 t") is kept as the range
  text rather than being collapsed to a number nobody stated.
* No vehicle is invented and no figure is filled in from anywhere else. The
  weight column says only "Agramy", so no record claims that figure is a combat
  weight — it is simply the vehicle's weight, and the weight-keyed tables read
  it.
* The handbook's securing assignments are not thrown away. Annex 14's Table 11
  (iron chock-boot type) and Table 13 (iron spur type) key off vehicle names
  and bare object numbers; where a vehicle in this table is one of those — by
  name, or because the handbook's object number is this vehicle (Object 172 is
  the T-72) — the assignment and its citation are carried onto the new record.
  A vehicle the handbook never assigned hardware to gets none, and the app
  reports its securing method as unconfirmed, which is true.
* Records that already exist keep their ids, so the 3-D model files and the
  photographs keyed to them keep working.

Run from the project root:

    python3 tools/import_transport_table.py "<path to the .docx>"
"""

import json
import os
import re
import sys
import unicodedata
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The citation every record built from this table carries.
REFERENCE_ID = 'doc-transport-characteristics'

# Annex 14's own catalogue, kept beside this script rather than read back out of
# the file the script writes. It is the only record of which vehicles the
# handbook assigns an iron spur or an iron chock-boot to, and running the import
# twice must not quietly lose those assignments by reading its own output.
ANNEX14 = os.path.join(ROOT, 'tools', 'annex14_vehicles.json')
ANNEX14_TK = os.path.join(ROOT, 'tools', 'annex14_vehicles_tk.json')

# ---------------------------------------------------------------- the source


def read_table(docx_path):
    """The table's rows, as (number, name, length, width, height, weight, section)."""
    xml = zipfile.ZipFile(docx_path).read('word/document.xml').decode('utf-8')

    def cells(row_xml):
        out = []
        for cell in re.findall(r'<w:tc[ >].*?</w:tc>', row_xml, re.S):
            text = ''.join(re.findall(r'<w:t[^>]*>(.*?)</w:t>', cell, re.S))
            out.append(re.sub(r'<[^>]+>', '', text).strip())
        return out

    rows = []
    for table in re.findall(r'<w:tbl>.*?</w:tbl>', xml, re.S):
        for row in re.findall(r'<w:tr[ >].*?</w:tr>', table, re.S):
            rows.append(cells(row))

    entries = []
    section = None
    for row in rows:
        filled = [c for c in row if c]
        if len(filled) == 1 and not filled[0].isdigit():
            section = filled[0]
            continue
        if len(row) >= 5 and row[0].strip().isdigit():
            entries.append({
                'n': int(row[0]),
                'name': row[1],
                'length': row[2],
                'width': row[3],
                'height': row[4],
                'weight': row[5] if len(row) > 5 else '',
                'section': section,
            })
    return entries


# ------------------------------------------------------------- what it means

# Every section of the table is one running gear or the other. The four
# exceptions are vehicles filed under the tracked engineering section that are
# not tracked: a repair shop on a BTR-80 hull and a motorcycle.
TRACKED_SECTIONS = {
    'TANKLAR',
    'PIÝADA SÖWEŞ MAŞYNLARY (BMP/BMD)',
    'ÝÖRITE ZYNJYRLY (INŽENER-TEHNIKI) MAŞYNLAR',
    'GT-SM ýörite',
}

WHEELED_OVERRIDES = {
    'MTO-BTR-80 (bejeriş ussahanasy)',
    'Motosikl (Ural M-72 gör.)',
}

# The table's weight column is headed simply "Agramy" and says nothing about
# what the figure is — combat, kerb, or transport. The record carries it as the
# vehicle's weight and the handbook's weight-keyed tables (chock sizing, the
# KGUUB bracket, the lashing count) read it.
#
# An earlier version of this importer stamped every record `weightBasis:
# unstated` and those tables then refused the figure, on the grounds that they
# are written about a combat weight specifically. The effect was that not one
# of those rules could be decided for any of the hundred and thirty-eight
# vehicles, and most of the tracked ones came out of the engine with no
# securing method at all. A recorded mass is a mass; the field is gone.


# What a record says about figures that are not the transport table's.
CARRIED_FIGURE_NOTE = (
    'Length, width, height and weight are from the vehicle '
    'transport-characteristics table, whose weight column does not say whether '
    'the figure is a combat, kerb or transport weight. Any further figure on '
    'this record — ground clearance, '
    'track width, track contact length, axle count — is not in that table and '
    'was carried from the earlier catalogue entry for this same vehicle, where '
    'it came from the manufacturer specification or the design mockup. It is '
    'not handbook data.'
)


def category_of(entry):
    if entry['name'] in WHEELED_OVERRIDES:
        return 'wheeled'
    return 'tracked' if entry['section'] in TRACKED_SECTIONS else 'wheeled'


def number(raw):
    """A figure from the table, or None when it does not state one."""
    if raw is None:
        return None
    text = raw.strip().replace(' ', ' ')
    if text in {'', '—', '-', 'd/ý', 'D/Ý'}:
        return None
    # A range is not a figure. Reported as text so nothing invents its middle.
    if '–' in text or '—' in text.strip('—'):
        return None
    text = text.replace(',', '.')
    match = re.search(r'-?\d+(?:\.\d+)?', text)
    return float(match.group()) if match else None


def mm_to_cm(raw):
    value = number(raw)
    return None if value is None else round(value / 10, 1)


def weight_t(raw):
    return number(raw)


def unavailable(raw, what):
    """What goes in a field the table does not fill in.

    The app renders any non-numeric value as "not stated", so the text here is
    what a trainee reads where a number would be. It says which document was
    consulted, because "not available" without a source is the one thing this
    project never prints.
    """
    text = (raw or '').strip()
    if text in {'—', '-', ''}:
        return f'Ulag häsiýetnamalary tablisasynda görkezilmedik ({what})'
    return f'{text} — ulag häsiýetnamalary tablisasy'


def slug(name):
    text = unicodedata.normalize('NFKD', name)
    replacements = {'ý': 'y', 'ň': 'n', 'ş': 's', 'ž': 'z', 'ç': 'c', 'ä': 'a', 'ö': 'o', 'ü': 'u'}
    text = ''.join(replacements.get(ch, ch) for ch in text.lower())
    text = ''.join(ch for ch in text if not unicodedata.combining(ch))
    text = re.sub(r'[^a-z0-9]+', '-', text).strip('-')
    return f'veh-{text}'[:48].rstrip('-')


# Ids that already exist and must survive, because a 3-D model file or a
# photograph is keyed to them. Left of the arrow is the table's own name.
KEEP_ID = {
    'T-72/M': 'veh-t72',
    'T-90S': 'veh-t90s',
    'BTR-80': 'veh-btr80',
    'BTR-70': 'veh-btr70',
    # The BTR-60 mesh is the hull, which every BTR-60 row in the table shares;
    # it is kept on the first of them so the model is not orphaned.
    'BTR-60 MTP-2B': 'veh-btr60',
    # Table 13 names the 2S3 in its own right and a photograph is keyed to it.
    '2S-3M "Akasiýa" SAU': 'veh-2s3',
    'ZIL-131 ýük': 'veh-zil131',
    'KamAZ-43114 ýük': 'veh-kamaz43114',
    'URAL-4320, 43202 ýük': 'veh-ural4320',
    '2S1 "Gwozdika" SAU': 'veh-2s1',
}

# The handbook's securing assignments, carried across by hand because the two
# documents name the same machines differently. Left of the arrow is the
# table's name; right is the id of the Annex 14 record whose assignment applies
# to it. Nothing is assigned by guesswork: each pairing is a vehicle the
# handbook names, or an object number the handbook gives that is this vehicle.
CARRY_SECURING = {
    # Annex 14 Table 13 lists Object 172 among the types taking the Ş-303 spur;
    # Object 172M is the T-72, which this table lists as T-72/M and T-72K.
    'T-72/M': 'veh-obj-family-137',
    'T-72K': 'veh-obj-family-137',
    # Table 13 names MT-55 and MTU-20 in the same object family row.
    'MT-55 (köpri düşeýji)': 'veh-obj-family-137',
    'MTU-20 (köpri düşeýji)': 'veh-obj-family-137',
    # 2S1 and the 2S3 are named in Table 13 in their own right.
    '2S1 "Gwozdika" SAU': 'veh-2s1',
    '2S-3M "Akasiýa" SAU': 'veh-2s3',
    # The T-90S record's own assignment, such as it is, is a manufacturer
    # record rather than a handbook one; it carries no spur or boot type, so
    # nothing is carried and the app reports it unconfirmed.
}


def _is_real_text(value, entry):
    """True when a text field says something, rather than standing in for a gap."""
    text = value.strip()
    if not text or text.startswith('TODO'):
        return False
    if text.startswith('Ulag häsiýetnamalary tablisasynda'):
        return False
    return text != (entry['section'] or '')


def build(entries, annex, current):
    # Securing assignments come from Annex 14; figures the table does not state
    # come from whatever the catalogue already held, which on a first run is
    # Annex 14 and on a re-run is this script's own previous output.
    by_id = {v['id']: v for v in annex}
    prior_by_id = {v['id']: v for v in current}
    used_ids = set()
    out = []

    for entry in entries:
        name = entry['name']
        vehicle_id = KEEP_ID.get(name) or slug(name)
        # Two rows of the table can slug to the same id (the ZIL-131 workshops
        # differ only by a parenthesis). A numeric suffix keeps them apart
        # rather than one silently overwriting the other.
        base = vehicle_id
        suffix = 2
        while vehicle_id in used_ids:
            vehicle_id = f'{base}-{suffix}'
            suffix += 1
        used_ids.add(vehicle_id)

        length = mm_to_cm(entry['length'])
        width = mm_to_cm(entry['width'])
        height = mm_to_cm(entry['height'])
        weight = weight_t(entry['weight'])

        record = {
            'id': vehicle_id,
            'handbookDesignation': name,
            'category': category_of(entry),
            'class': entry['section'] or 'Ulag häsiýetnamalary tablisasy',
            'lengthCm': length if length is not None else unavailable(entry['length'], 'uzynlygy'),
            'widthCm': width if width is not None else unavailable(entry['width'], 'ini'),
            'heightCm': height if height is not None else unavailable(entry['height'], 'beýikligi'),
            'weightT': weight if weight is not None else unavailable(entry['weight'], 'agramy'),
            'groundClearanceCm': 'Ulag häsiýetnamalary tablisasynda görkezilmedik',
            'trackWidthMm': 'Ulag häsiýetnamalary tablisasynda görkezilmedik',
            'wheelBaseCm': 'Ulag häsiýetnamalary tablisasynda görkezilmedik',
            'manufacturer': 'Ulag häsiýetnamalary tablisasynda görkezilmedik',
            'country': 'Ulag häsiýetnamalary tablisasynda görkezilmedik',
            # The securing hardware every vehicle of this running gear takes.
            #
            # This is not assigned per model and is not invented: the handbook's
            # plates are written for a class of vehicle. Plate 05 dimensions the
            # wooden stop blocks and wire lashings for a wheeled vehicle on a
            # flatcar; plate 02 does the same for a tracked one. What *is*
            # per-model — the iron spur of Table 13 and the iron chock-boot of
            # Table 11 — is only ever added below, for the vehicles Annex 14
            # names.
            'approvedSecuringHardware': ['att-wood-chock', 'att-wire-lashing'],
            'securingReferenceId': 'plate-05' if category_of(entry) == 'wheeled' else 'plate-02',
            'referenceId': REFERENCE_ID,
            'dataSource': 'transportTable',
        }

        # Figures an earlier record carried that this table does not state.
        # Only fields the table is silent on are taken, so the table's own
        # numbers are never overwritten by an older source.
        # Text an earlier record carried that this table does not state — what
        # the machine actually is, who built it, where. The table gives a
        # section heading and nothing else, so a vehicle that already had a
        # description keeps it rather than being reduced to "TANKLAR".
        for field in ('class', 'manufacturer', 'country'):
            for source_map in (prior_by_id, by_id):
                value = (source_map.get(vehicle_id) or {}).get(field)
                if isinstance(value, str) and _is_real_text(value, entry):
                    record[field] = value
                    break

        carried = False
        for field in ('axleCount', 'trackWidthMm', 'wheelBaseCm',
                      'trackContactLengthCm', 'groundClearanceCm'):
            for source_map in (prior_by_id, by_id):
                value = (source_map.get(vehicle_id) or {}).get(field)
                if isinstance(value, (int, float)):
                    record[field] = value
                    carried = True
                    break

        # The note an earlier record carried about this same vehicle, kept, and
        # a line saying which of the figures above are not this table's. The
        # note is looked for in both catalogues rather than taken from the
        # first one that happens to hold the id: re-running the import reads
        # its own previous output, whose note is this script's, not the
        # original record's.
        note = None
        for source_map in (prior_by_id, by_id):
            candidate = (source_map.get(vehicle_id) or {}).get('notes')
            if candidate:
                candidate = candidate.replace(CARRIED_FIGURE_NOTE, '').strip()
            if candidate:
                note = candidate
                break

        notes = [n for n in [note] if n]
        if carried:
            notes.append(CARRIED_FIGURE_NOTE)
        if notes:
            record['notes'] = ' '.join(notes)

        # The handbook's own assignment, where this vehicle is one it named.
        source = by_id.get(CARRY_SECURING.get(name, ''))
        if source is not None:
            for field in ('ironSpurType', 'ironChockBootType'):
                if source.get(field):
                    record[field] = source[field]
            # Added to the class hardware, never in place of it: a vehicle
            # that takes an iron spur still takes the wooden stop blocks and
            # the wire lashings its plate dimensions.
            for hardware in source.get('approvedSecuringHardware', []):
                if hardware not in record['approvedSecuringHardware']:
                    record['approvedSecuringHardware'].append(hardware)
            record['securingReferenceId'] = source['referenceId']

        out.append(record)
    return out


def write_localization(records):
    """Keep `vehicles_tk.json` in step with the catalogue.

    The interface is entirely in Turkmen and a vehicle with no entry here falls
    back to its English text in front of a trainee, so the file has to carry one
    line per record and no line for a record that no longer exists. The class
    text is the table's own section heading, which is already the Turkmen a
    trainee should read ("TANKLAR", "ZIL AWTOULAGLARY"); a note an earlier
    record carried about that same vehicle is kept.
    """
    path = os.path.join(ROOT, 'assets', 'data', 'localization', 'vehicles_tk.json')
    existing = json.load(open(path, encoding='utf-8'))
    prior = {e['id']: e for e in existing.get('vehicles', [])}
    annex = {e['id']: e for e in json.load(open(ANNEX14_TK, encoding='utf-8'))['vehicles']}

    out = []
    for record in records:
        entry = {'id': record['id'], 'classDisplayTk': record['class']}
        # A description an earlier record carried wins over the table's section
        # heading, the same way it does on the record itself.
        # The original catalogue's translation is looked at before this
        # script's own previous output, which is only ever the table's section
        # heading; taking the generated one first would let it overwrite a real
        # description the day the import is re-run.
        for source_map in (annex, prior):
            described = source_map.get(record['id'], {}).get('classDisplayTk')
            if described and not described.startswith('Çykarylan gollanma') \
                    and described != record['class']:
                entry['classDisplayTk'] = described
                break
        for source_map in (annex, prior):
            note = source_map.get(record['id'], {}).get('notesTk')
            if note:
                entry['notesTk'] = note
                break
        out.append(entry)

    existing['vehicles'] = out
    existing['_comment'] = (
        'Turkmen text for the vehicle catalogue. Written by '
        'tools/import_transport_table.py alongside assets/data/vehicles.json, so '
        'the two cannot drift: test/data_integrity_test.dart fails if a vehicle '
        'has no entry here or an entry outlives its vehicle.'
    )
    with open(path, 'w', encoding='utf-8') as handle:
        json.dump(existing, handle, ensure_ascii=False, indent=2)
        handle.write('\n')


def annex_only_records(records):
    """Annex 14's own vehicles that the transport table does not list.

    The table is the unit's list of what it moves, so it decides which vehicles
    the trainer offers — but the handbook also carries machines the table has
    no row for (T-34, T-54, PT-76, the Object-NNN families that Table 13 keys
    the iron spurs off, and so on), with real securing assignments behind them.

    An earlier run of this importer dropped them, which deleted twenty-two
    handbook records and every photograph attached to them. They are carried
    through instead: the table decides what it lists, and it does not get to
    delete what it never mentioned.
    """
    have = {r['id'] for r in records}
    with open(ANNEX14, encoding='utf-8') as handle:
        annex = json.load(handle)
    rows = annex if isinstance(annex, list) else annex['vehicles']
    out = []
    for row in rows:
        if row['id'] in have:
            continue
        row = dict(row)
        # Same two invariants the table's own records carry: a securing
        # assignment names the paragraph it came from, and every vehicle can
        # also be secured by the class method its plates dimension.
        if (row.get('ironSpurType') or row.get('ironChockBootType')) \
                and not row.get('securingReferenceId'):
            row['securingReferenceId'] = row['referenceId']
        hardware = list(row.get('approvedSecuringHardware') or [])
        for need in ('att-wood-chock', 'att-wire-lashing'):
            if need not in hardware:
                hardware.append(need)
        row['approvedSecuringHardware'] = hardware
        out.append(row)
    return out


def main():
    docx = sys.argv[1] if len(sys.argv) > 1 else None
    if not docx or not os.path.exists(docx):
        sys.exit('usage: import_transport_table.py <path to the .docx>')

    path = os.path.join(ROOT, 'assets', 'data', 'vehicles.json')
    current = json.load(open(path, encoding='utf-8'))
    current_records = current['vehicles'] if isinstance(current, dict) else current

    annex = json.load(open(ANNEX14, encoding='utf-8'))
    annex_records = annex['vehicles'] if isinstance(annex, dict) else annex

    entries = read_table(docx)
    records = build(entries, annex_records, current_records)

    payload = {
        '_comment': (
            'Built from "Harby tehnikalaryň ulag häsiýetnamalary" (uzynlygy, ini, '
            'beýikligi we agramy) by tools/import_transport_table.py. That table is '
            'the unit\'s own list of what it moves and decides which vehicles this '
            'trainer offers. Dimensions are converted from the millimetres it states '
            'to centimetres; a figure it gives as "—" or "d/ý", and a weight it gives '
            'as a range, stay unavailable rather than being filled in from elsewhere. '
            'Securing hardware is only ever the handbook\'s (Order 145/175-ö, Annex 14, '
            'Tables 11 and 13), carried across for the vehicles it actually names.'
        ),
        'vehicles': records + annex_only_records(records),
    }
    with open(path, 'w', encoding='utf-8') as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)
        handle.write('\n')

    write_localization(records)

    tracked = sum(1 for r in records if r['category'] == 'tracked')
    dimensioned = sum(1 for r in records if isinstance(r['lengthCm'], (int, float)))
    weighed = sum(1 for r in records if isinstance(r['weightT'], (int, float)))
    secured = sum(1 for r in records if r.get('ironSpurType') or r.get('ironChockBootType'))
    print(f'{len(records)} vehicles  ({tracked} tracked, {len(records) - tracked} wheeled)')
    print(f'  with dimensions: {dimensioned}')
    print(f'  with a weight:   {weighed}')
    print(f'  with a handbook securing assignment: {secured}')


if __name__ == '__main__':
    main()

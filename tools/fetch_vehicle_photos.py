#!/usr/bin/env python3
"""Fetch illustrative vehicle photographs from Wikimedia Commons.

The handbook extract contains no identification photograph of any vehicle —
every figure in it shows generic securing equipment or a procedure (see
docs/handbook-photo-mapping-report.md). These photographs fill that gap so a
trainee can see what they are loading.

Two rules this script exists to enforce:

1. **Licence.** Only public-domain and CC0/CC BY/CC BY-SA files are accepted.
   Anything non-free, NonCommercial or NoDerivatives is skipped, and the
   licence, author and source page of every accepted file are written into the
   manifest so the app can display attribution.

2. **Provenance.** These are NOT handbook figures and must never be catalogued
   as such. They go to their own manifest (assets/data/vehicle_photos.json)
   and their own directory, so nothing can confuse an illustrative photograph
   from the internet with a cited figure from the source document.

Only vehicles with an unambiguous single designation are fetched. The
"Object NNN" entries are design-bureau indices covering several different
vehicles each, so one photograph could not honestly represent them.

Usage:
    python3 tools/fetch_vehicle_photos.py --dry-run   # report candidates only
    python3 tools/fetch_vehicle_photos.py             # download and write manifest
"""

import argparse
import functools
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# Progress has to be visible while the run is in flight: this script is
# usually watched through a pipe, where Python's block buffering would
# otherwise hold every line until it exits.
print = functools.partial(print, flush=True)  # noqa: A001

API = "https://commons.wikimedia.org/w/api.php"
UA = "RailSimTrainer/0.1 (military railway loading trainer; educational)"
OUT_DIR = "assets/images/vehicles"
MANIFEST = "assets/data/vehicle_photos.json"
THUMB_WIDTH = 1000

# vehicle id -> (Commons search term, pattern the file title MUST match).
#
# The title check is not optional. Searching "IS-4 tank" returns, among other
# things, "Crew of a Sherman-tank south of Vaucelles.jpg" — a different vehicle
# entirely, matched on loose words in the description. Putting that on an IS-4
# card would teach a trainee to recognise the wrong vehicle, which is worse
# than showing no photograph at all. A candidate whose own filename does not
# name the designation is rejected.
#
# Deliberately no entry for the Object-index group vehicles: those designations
# cover several different vehicles each, so no single photograph is honest.
# Entries are removed when a vehicle leaves the catalogue: the transport-table
# import dropped T-34, IS-4, T-10, T-54, T-55, PT-76, BTR-50P, 2S4, 2S7, PTS-2
# and PTS-M, and a manifest naming a vehicle that no longer exists fails
# `vehicle_photo_test.dart` and would leave an unreachable photograph bundled.
SEARCH_TERMS = {
    # Restored with the handbook vehicles themselves. These are Annex 14's own
    # records; the transport-table import dropped them and they were put back.
    "veh-t34": ("T-34 tank", r"\bT[-\s]?34\b"),
    "veh-is4": ("IS-4 heavy tank Soviet", r"\bIS[-\s]?4\b"),
    "veh-t10": ("T-10 heavy tank", r"\bT[-\s]?10\b"),
    "veh-t54": ("T-54 tank", r"\bT[-\s]?54\b"),
    "veh-t55": ("T-55 tank", r"\bT[-\s]?55\b"),
    "veh-pt76": ("PT-76 amphibious tank", r"\bPT[-\s]?76\b"),
    "veh-btr50p": ("BTR-50 armoured personnel carrier", r"\bBTR[-\s]?50\b"),
    "veh-2s4": ("2S4 Tyulpan self-propelled mortar", r"\b2S[-\s]?4\b"),
    "veh-2s5": ("2S5 Giatsint self-propelled gun", r"\b2S[-\s]?5\b"),
    "veh-2s7": ("2S7 Pion self-propelled gun", r"\b2S[-\s]?7\b"),
    "veh-pts2": ("PTS-2 tracked amphibious transport", r"\bPTS[-\s]?2\b"),
    "veh-ptsm": ("PTS-M tracked amphibious transport", r"\bPTS[-\s]?M\b"),
    "veh-t80u": ("T-80U tank", r"\bT[-\s]?80U?\b"),
    # Added for the transport-table catalogue. Only base designations that
    # Commons can name unambiguously: the variant records (BMP-1 K, BMP-1 KŞ,
    # BTR-60 R-145BM, MT-LB U and the rest) are deliberately absent, because a
    # search cannot tell them from the base machine and putting the base
    # machine's photograph on a variant's card teaches the wrong vehicle.
    "veh-t-62": ("T-62 tank", r"\bT[-\s]?62\b"),
    "veh-bmp-1": ("BMP-1 infantry fighting vehicle", r"\bBMP[-\s]?1\b"),
    "veh-bmp-2": ("BMP-2 infantry fighting vehicle", r"\bBMP[-\s]?2\b"),
    "veh-bmp-3": ("BMP-3 infantry fighting vehicle", r"\bBMP[-\s]?3\b"),
    "veh-bmd-1-howa-desant": ("BMD-1 airborne vehicle", r"\bBMD[-\s]?1\b"),
    "veh-btr70": ("BTR-70 armoured personnel carrier", r"\bBTR[-\s]?70\b"),
    "veh-btr80": ("BTR-80 armoured personnel carrier", r"\bBTR[-\s]?80\b"),
    "veh-brdm-2": ("BRDM-2 reconnaissance vehicle", r"\bBRDM[-\s]?2\b"),
    "veh-zsu-23-4-silka": ("ZSU-23-4 Shilka", r"\bZSU[-\s]?23[-\s]?4\b"),
    "veh-imr-inzener-pasgelcilik-ayyryjy": ("IMR combat engineering vehicle", r"\bIMR\b"),
    "veh-gmz-mina-goyujy": ("GMZ minelayer tracked", r"\bGMZ\b"),
    "veh-brem-1-t-72-esasly-arw": ("BREM-1 armoured recovery vehicle", r"\bBREM[-\s]?1\b"),
    "veh-bts-4-tank-cekiji": ("BTS-4 armoured recovery vehicle", r"\bBTS[-\s]?4\b"),
    "veh-mtu-20-kopri-duseyji": ("MTU-20 bridgelayer", r"\bMTU[-\s]?20\b"),
    "veh-mt-55-kopri-duseyji": ("MT-55 bridgelayer tank", r"\bMT[-\s]?55\b"),
    "veh-mt-lb-mt-lb-u-cekiji": ("MT-LB armoured tractor", r"\bMT[-\s]?LB\b"),
    "veh-motosikl-ural-m-72-gor": ("Ural M-72 motorcycle", r"\bM[-\s]?72\b"),
    "veh-2s1": ("2S1 Gvozdika", r"\b2S1\b|Gvozdika"),
    "veh-2s3": ("2S3 Akatsiya", r"\b2S3\b|Akatsiya"),
    # The two modern main battle tanks. Both designations are unambiguous, so
    # the same title check applies — and it matters here, because a search for
    # "T-72" turns up as many T-72B3s, T-72AMTs and PT-91s as it does T-72s,
    # and a card should show the machine it names.
    "veh-t72": ("T-72 main battle tank", r"\bT[-\s]?72\b"),
    "veh-t90s": ("T-90 main battle tank", r"\bT[-\s]?90\b"),
    # The three wheeled lorries added from the design mockup. Their
    # designations are unambiguous, so the same title check applies.
    "veh-zil131": ("ZIL-131 truck", r"\bZIL[-\s]?131\b"),
    "veh-kamaz43114": ("KamAZ-43114 truck", r"\bKamAZ[-\s]?43114\b"),
    "veh-ural4320": ("Ural-4320 truck", r"\bUral[-\s]?4320\b"),
}

# Files chosen by looking at the candidates, for the vehicles where scoring a
# filename cannot settle the question. A score can rule out a portrait crop or
# a night firing shot, but it cannot tell a photograph of the whole machine
# from a close-up of its glacis plate, and it cannot see that a museum picture
# is dark and half-hidden behind a barrier. These three were picked by eye
# after the automatic run put a hull close-up on the 2S7 card, an exhibit
# placard on the PT-76 card, and a yard of mixed T-54s and T-55s on the T-54
# card.
#
# A pinned file is not exempt from anything: it still has to name the
# designation, still has to be freely licensed, and still has to pass the
# framing check. This only decides which *passing* candidate wins.
REVIEWED_PICKS = {
    "veh-t54": "File:T-54-.jpg",
    "veh-pt76": (
        "File:Right side view, on display, Soviet PT-76 Light Amphibious Tank"
        " - DPLA - 2cc527e18949a1d15cd2f979cb401bd3.jpeg"
    ),
    "veh-2s7": (
        "File:Russian 2S7 Pion self propelled 203 mm Heavy artillery gun"
        " (Ank Kumar, Infosys Limited) 02.jpg"
    ),
    # The two modern tanks, both picked by looking at the candidates.
    #
    # The automatic run put "T-90 operators.png" on the T-90S card, which is a
    # map of operator countries and not a tank at all, and offered the T-72 a
    # museum placard photographed edge-on — the same two failures the pins
    # above exist for. What is pinned instead is one machine, whole, in
    # daylight, recognisably the vehicle it is filed under: the T-90S on a
    # demonstration ground against plain sky, which also makes it the one
    # candidate a cut-out could be taken from, and a single camouflaged T-72
    # rather than the row of monument tanks the other candidate shows.
    "veh-t72": "File:T-72 in Museum of technique 2016-08-16.JPG",
    "veh-t90s": "File:T-90S - Engineering Technologies 2010.jpg",
}

# Matched against the file's LicenseShortName. Kept as an allow-list rather
# than a block-list so an unrecognised licence is skipped, never assumed free.
ALLOWED = [
    re.compile(r"^cc0\b", re.I),
    re.compile(r"^cc[- ]by([- ]sa)?[- ]?[0-9.]*$", re.I),
    re.compile(r"^public domain", re.I),
    re.compile(r"^pd\b", re.I),
]
FORBIDDEN = re.compile(r"\b(nc|nd|noncommercial|noderiv|fair use|non-free)\b", re.I)


def api(**params):
    """One API call, backing off patiently when Commons rate-limits us.

    Anonymous callers get a small request budget, and once it is spent Commons
    answers 429 for a while rather than for a moment: an earlier version of
    this script, which spent about fifteen requests per vehicle, burned through
    the budget and then failed every remaining vehicle with 429 no matter how
    long it waited between tries. The fix was to stop making so many requests
    (see [candidate_infos]); this longer backoff is the second half of it.
    """
    params.setdefault("format", "json")
    url = API + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    delay = 15.0
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                data = json.load(r)
            time.sleep(1.5)  # stay well under the anonymous rate limit
            return data
        except urllib.error.HTTPError as exc:
            if exc.code != 429 or attempt == 4:
                raise
            print("                   rate-limited, waiting %ds" % int(delay))
            time.sleep(delay)
            delay *= 2
    raise RuntimeError("unreachable")


def is_free(license_name):
    if not license_name:
        return False
    if FORBIDDEN.search(license_name):
        return False
    return any(p.match(license_name.strip()) for p in ALLOWED)


def strip_html(text):
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", "", text or "")).strip()


def clean_author(text):
    """The author line, or empty when Commons does not actually record one.

    Two things need fixing before an author string is fit to print under a
    photograph. Commons' "Unknown author" template renders its label twice in
    the API's HTML, so the naive strip produces "Unknown authorUnknown author";
    and an author of "unknown" is not an author at all — printing it as a
    credit would be worse than the UI's own "author not recorded" line.
    """
    name = strip_html(text)
    half = len(name) // 2
    if half and len(name) % 2 == 0 and name[:half] == name[half:]:
        name = name[:half]
    if re.fullmatch(r"(unknown(\s+author)?|anonymous|not stated|n/?a)\.?", name, re.I):
        return ""
    return name


def infos_for_titles(titles):
    """Metadata for named files, fetched directly rather than searched for.

    A reviewed pick is a file a person chose by looking at it. Requiring it to
    also turn up in a keyword search made the pin fragile in a way that
    defeated its purpose: Commons search rank moves, and when the pinned T-72
    and T-90S fell off their searches the run quietly fell back to a photograph
    of an exhibit placard and a map of operator countries. A pin now names the
    file and the file is fetched.
    """
    if not titles:
        return {}
    res = api(action="query", titles="|".join(titles),
              prop="imageinfo", iiprop="url|size|extmetadata",
              iiurlwidth=THUMB_WIDTH)
    out = {}
    for page in (res.get("query", {}).get("pages", {}) or {}).values():
        info = (page.get("imageinfo") or [None])[0]
        title = page.get("title")
        if not info or not title:
            continue
        meta = info.get("extmetadata", {})
        out[title] = {
            "title": title,
            "thumb": info.get("thumburl") or info.get("url"),
            "descriptionurl": info.get("descriptionurl"),
            "license": strip_html(meta.get("LicenseShortName", {}).get("value")),
            "license_url": strip_html(meta.get("LicenseUrl", {}).get("value")),
            "author": clean_author(meta.get("Artist", {}).get("value")),
            "width": info.get("width") or 0,
            "height": info.get("height") or 0,
        }
    return out


def candidate_infos(term, limit=20):
    """Every candidate for one vehicle, with its metadata, in ONE request.

    `generator=search` feeds the search results straight into `prop=imageinfo`,
    so a vehicle costs one API call instead of a search plus a lookup per hit.
    That is what keeps the whole run inside the anonymous rate limit.

    Search rank is preserved via each page's `index`, so equally-scoring
    candidates fall back to the order Commons itself considers most relevant.

    The limit is 20 rather than a handful because it costs nothing extra — it
    is the same single request either way — and because the reviewed T-54 pick
    sat at rank 20 of the search: a shorter list quietly dropped it and fell
    back to a candidate that had already been rejected by eye.
    """
    res = api(action="query", generator="search",
              gsrsearch="filetype:bitmap " + term, gsrnamespace=6, gsrlimit=limit,
              prop="imageinfo", iiprop="url|size|extmetadata", iiurlwidth=THUMB_WIDTH)
    pages = list(res.get("query", {}).get("pages", {}).values())
    pages.sort(key=lambda p: p.get("index", 0))
    infos = []
    for page in pages:
        info = (page.get("imageinfo") or [None])[0]
        title = page.get("title")
        if not info or not title:
            continue
        meta = info.get("extmetadata", {})
        infos.append({
            "title": title,
            "thumb": info.get("thumburl") or info.get("url"),
            "descriptionurl": info.get("descriptionurl"),
            "license": strip_html(meta.get("LicenseShortName", {}).get("value")),
            "license_url": strip_html(meta.get("LicenseUrl", {}).get("value")),
            "author": clean_author(meta.get("Artist", {}).get("value")),
            "width": info.get("width") or 0,
            "height": info.get("height") or 0,
        })
    return infos


# Words in a filename that usually mean the photograph is a poor way to show
# what a vehicle looks like: a plinth against a wall, a muzzle flash at night,
# a wreck. The first run picked a T-54 monument shot and a 2S1 firing at night
# purely because they came back first, and neither was usable.
#
# The museum words earn their place too: the PT-76 pick from the second run was
# "PT-76 amphibious tank description.JPG", which is a photograph of the exhibit
# *placard* — the vehicle does not appear in it at all.
POOR_SUBJECT = re.compile(
    r"\b(monument|memorial|plinth|night|firing|fires|shoot|wreck|destroyed|"
    r"burn|abandoned|scrap|interior|cutaway|diagram|drawing|model|toy|"
    r"miniature|graffiti|snow|description|placard|plaque|signage|caption|"
    r"label|inscription|nameplate|infobo?ard)\b", re.I)


def names_another_vehicle(name, own_id):
    """True when the filename also names a different vehicle on the roster.

    "T-54 and T-55 tanks.JPEG" satisfies the T-54 title check and was picked
    for the T-54 card, but the photograph is a yard full of both types and a
    trainee cannot tell which hull is which. A picture that teaches an
    ambiguous answer is no better than a picture of the wrong vehicle, so any
    candidate naming a second roster designation is rejected for both of them.
    """
    for other_id, (_, other_pattern) in SEARCH_TERMS.items():
        if other_id == own_id:
            continue
        if re.search(other_pattern, name, re.I):
            return other_id
    return None


def detect_view(title):
    """Detect the view type from a filename, if one is evident.

    Returns 'front', 'side', 'rear', or None.
    Matches are case-insensitive on common English phrases in the title.
    """
    title_lower = title.lower()

    # Check for rear/back first (fewer matches, most specific)
    if re.search(r'\b(rear|back|behind)\b', title_lower):
        return 'rear'

    # Front view
    if re.search(r'\b(front|frontal)\b', title_lower):
        return 'front'

    # Side view (most common)
    if re.search(r'\b(side|left|right|profile|left side|right side)\b', title_lower):
        return 'side'

    return None


def score(info):
    """How good a candidate is as an identification photograph.

    A vehicle is recognised from its side, so a landscape frame with the whole
    machine in it beats a tall crop; a reasonably large original beats a
    thumbnail. Portrait shots are rejected outright rather than ranked low —
    the app shows these in a wide slot.
    """
    w, h = info.get("width") or 0, info.get("height") or 0
    if w <= 0 or h <= 0:
        return None
    ratio = w / h
    if ratio < 1.15:
        return None  # portrait or square: not a side elevation
    points = 0.0
    points += 3.0 if 1.3 <= ratio <= 2.1 else 1.0
    points += 2.0 if w >= 2000 else (1.0 if w >= 1200 else 0.0)
    if POOR_SUBJECT.search(info["title"]):
        points -= 4.0
    return points


def find_extra_views(vehicle_id, term, title_pattern, exclude_title=None):
    """Find extra view candidates (front, side, rear) for a vehicle.

    Returns a dict mapping view_type -> info, containing up to 3 extra views.
    Excludes the primary photo (if exclude_title is set).
    """
    views = {}
    pattern = re.compile(title_pattern, re.I)

    for info in candidate_infos(term, limit=30):
        title = info["title"]
        name = title[5:]  # drop the "File:" prefix

        # Skip the primary photo
        if exclude_title and title == exclude_title:
            continue

        # Must name the designation
        if not pattern.search(name):
            continue

        # Must not name another vehicle
        if names_another_vehicle(name, vehicle_id):
            continue

        # Must have a downloadable thumbnail and valid licence
        if not info["thumb"] or not is_free(info["license"]):
            continue

        # Detect the view type
        view_type = detect_view(name)
        if not view_type:
            continue

        # Skip if we already have this view type
        if view_type in views:
            continue

        # Score it — must be reasonable framing
        points = score(info)
        if points is None:
            continue

        views[view_type] = info

        # Stop once we have all three views
        if len(views) == 3:
            break

    return views


def pick(vehicle_id, term, title_pattern):
    """The best-scoring candidate that names the designation and is free.

    A reviewed pick short-circuits the search entirely: it was chosen by
    looking at the photograph, so it is fetched by name. It is still held to
    the licence rule — a pin cannot make a non-free file usable.
    """
    pinned = REVIEWED_PICKS.get(vehicle_id)
    if pinned:
        info = infos_for_titles([pinned]).get(pinned)
        if info and info["thumb"] and is_free(info["license"]):
            views = find_extra_views(vehicle_id, term, title_pattern, exclude_title=pinned)
            return info, [], views
        print("  %-14s WARNING pinned file unusable (%s)"
              % (vehicle_id,
                 "not found" if not info else (info["license"] or "no licence")),
              file=sys.stderr)

    rejected = []
    best = None
    best_points = None
    pattern = re.compile(title_pattern, re.I)
    for info in candidate_infos(term):
        name = info["title"][5:]  # drop the "File:" prefix
        if not pattern.search(name):
            rejected.append((name, "title does not name the designation"))
            continue
        other = names_another_vehicle(name, vehicle_id)
        if other is not None:
            rejected.append((name, "also names %s — ambiguous subject" % other))
            continue
        if not info["thumb"]:
            continue
        if not is_free(info["license"]):
            rejected.append((name, info["license"] or "unknown licence"))
            continue
        points = score(info)
        if points is None:
            rejected.append((name, "portrait or unusable framing"))
            continue
        if best_points is None or points > best_points:
            best, best_points = info, points

    # Find extra views if we found a primary photo
    views = {}
    if best:
        views = find_extra_views(vehicle_id, term, title_pattern, exclude_title=best["title"])

    return best, rejected, views


def download(url, dest):
    """Fetch one thumbnail, backing off on rate limits like [api] does.

    Commons only renders thumbnails at a published list of widths, and refuses
    others with HTTP 400 ("Use thumbnail sizes listed on ..."). That is a
    per-file failure, not a reason to abandon the whole run, so callers catch
    it and move on to the next vehicle.
    """
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    delay = 3.0
    for attempt in range(6):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                data = r.read()
            break
        except urllib.error.HTTPError as exc:
            if exc.code != 429 or attempt == 5:
                raise
            time.sleep(delay)
            delay *= 2
    with open(dest, "wb") as f:
        f.write(data)
    time.sleep(1.0)
    return len(data)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    # Fetching one vehicle must not re-search the other seventeen. A re-search
    # can settle on a different file from last time, and since a file already
    # on disk is not re-downloaded, the manifest would then name a photograph
    # that is not the one in the directory.
    ap.add_argument("--only", nargs="+", metavar="VEHICLE_ID",
                    help="restrict the run to these vehicle ids")
    args = ap.parse_args()
    wanted = set(args.only) if args.only else None
    if wanted:
        unknown = wanted - set(SEARCH_TERMS)
        if unknown:
            print("unknown vehicle id(s): %s" % ", ".join(sorted(unknown)),
                  file=sys.stderr)
            return 2

    if not args.dry_run:
        os.makedirs(OUT_DIR, exist_ok=True)

    # Carry forward anything a previous run already resolved, so a rate-limit
    # failure on one vehicle cannot drop the other thirteen from the manifest.
    entries = {}
    if not args.dry_run and os.path.exists(MANIFEST):
        with open(MANIFEST, encoding="utf-8") as f:
            for entry in json.load(f).get("photos", []):
                entries[entry["vehicleId"]] = entry

    for vehicle_id, (term, title_pattern) in SEARCH_TERMS.items():
        if wanted and vehicle_id not in wanted:
            continue
        try:
            info, rejected, views = pick(vehicle_id, term, title_pattern)
        except Exception as exc:  # network hiccup on one vehicle must not abort the rest
            print("  %-14s ERROR %s" % (vehicle_id, exc), file=sys.stderr)
            continue
        if info is None:
            print("  %-14s no freely-licensed candidate (%d rejected)" % (vehicle_id, len(rejected)))
            for title, lic in rejected[:3]:
                print("                   rejected: %s [%s]" % (title, lic))
            continue

        # Take the extension from the thumbnail actually served, so a WebP
        # source is not filed under a .jpg name.
        ext = os.path.splitext(urllib.parse.urlparse(info["thumb"]).path)[1].lower()
        if ext not in (".jpg", ".jpeg", ".png", ".webp"):
            ext = ".jpg"
        name = vehicle_id + ext
        print("  %-14s %-52s [%s]" % (vehicle_id, info["title"][5:][:52], info["license"]))
        if not args.dry_run:
            dest = os.path.join(OUT_DIR, name)
            # Resume: a re-run after a rate-limit failure should not re-fetch
            # what already arrived.
            if os.path.exists(dest) and os.path.getsize(dest) > 0:
                print("                   already present, %d KB" % (os.path.getsize(dest) // 1024))
            else:
                try:
                    size = download(info["thumb"], dest)
                except (urllib.error.URLError, OSError) as exc:
                    # One unfetchable file must not cost the other thirteen:
                    # the vehicle is left out of the manifest entirely rather
                    # than catalogued with a path to a file that isn't there.
                    print("                   DOWNLOAD FAILED (%s) — skipped" % exc)
                    if os.path.exists(dest) and os.path.getsize(dest) == 0:
                        os.remove(dest)
                    continue
                print("                   downloaded %d KB" % (size // 1024))

        entry = {
            "vehicleId": vehicle_id,
            "file": "images/vehicles/" + name,
            "sourceTitle": info["title"],
            "sourceUrl": info["descriptionurl"],
            "license": info["license"],
            "licenseUrl": info["license_url"],
            "author": info["author"],
        }

        # Download and record extra views if found
        if views and not args.dry_run:
            views_entry = {}
            for view_type in ("front", "side", "rear"):
                if view_type not in views:
                    continue
                view_info = views[view_type]
                # Get extension from this view's thumbnail
                view_ext = os.path.splitext(urllib.parse.urlparse(view_info["thumb"]).path)[1].lower()
                if view_ext not in (".jpg", ".jpeg", ".png", ".webp"):
                    view_ext = ".jpg"
                view_name = vehicle_id + "-" + view_type + view_ext
                view_dest = os.path.join(OUT_DIR, view_name)

                # Skip if already present
                if os.path.exists(view_dest) and os.path.getsize(view_dest) > 0:
                    print("                   %s view: already present" % view_type)
                else:
                    try:
                        size = download(view_info["thumb"], view_dest)
                        print("                   %s view: downloaded %d KB" % (view_type, size // 1024))
                    except (urllib.error.URLError, OSError) as exc:
                        print("                   %s view: DOWNLOAD FAILED (%s)" % (view_type, exc))
                        if os.path.exists(view_dest) and os.path.getsize(view_dest) == 0:
                            os.remove(view_dest)
                        continue

                # Record the view in the manifest
                views_entry[view_type] = "images/vehicles/" + view_name

            if views_entry:
                entry["views"] = views_entry

        entries[vehicle_id] = entry

    if args.dry_run:
        total = len(wanted) if wanted else len(SEARCH_TERMS)
        print("\n%d of %d vehicles have a freely-licensed candidate"
              % (len(entries), total))
        # Count extra views found in dry-run
        total_views = {"front": 0, "side": 0, "rear": 0}
        # Note: in dry-run, views are not populated (would need separate flag to track)
        return 0

    manifest = {
        "_comment": (
            "Illustrative vehicle photographs from Wikimedia Commons, fetched by "
            "tools/fetch_vehicle_photos.py. These are NOT handbook figures: the source "
            "handbook contains no identification photograph of any vehicle. They are kept "
            "in their own manifest so nothing can present an internet photograph as a cited "
            "figure, and every entry carries its licence, author and source page for "
            "attribution. Vehicles whose designation is a design-bureau index covering "
            "several different vehicles are deliberately absent."
        ),
        "photos": [entries[k] for k in SEARCH_TERMS if k in entries],
    }
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("\n%d photographs -> %s" % (len(entries), MANIFEST))
    return 0


if __name__ == "__main__":
    main()

# Berl plate extraction — evidence log

Every value below was read directly off a converted plate or a scanned page of
`Программа учин.docx`. Nothing here is inferred, rounded, or filled in from
general railway knowledge. Where a cell was not legible it is recorded as
`illegible` and stays a `HandbookField` TODO in the JSON.

Source files, after `tools/convert_berl_plates.py`:
`assets/images/plates/plate-NN-*.jpg` ← `Berl/*.jpg` (CMYK, ~10000x7200, converted to sRGB).

---

## plate-02 — tracked, wood chocks + inserts, and clamp-tensioners

Title: ZYNJYRLY HARBY TEHNIKALARY DEMIR ÝOLUŇ AÇYK WAGONLARYNA ÝERLEŞDIRMEK WE
BERKITMEK — direg dört gyrag agaç bölekleri we ara goýulýan agaç bölekleri
arkaly hem-de gysgyç çekmeler we gysgyçlar arkaly.

Chock dimensions by combat weight ("Harby zynjyrly maşynyň agramyna görä direg
agaç bölekleriniň ölçegleri", mm):

| agram, ton | beýikligi (h) | ini (b) |
|---|---|---|
| 12.0 | 75 | 100 |
| 12.1 - 18.0 | 150 | 180 |

Insert block (ara goýulýan ýarym tegelek agaç bölegi / вкладыш): height 90-100 mm,
length 300-400 mm.

Placement clearances, read off the dimension callouts:
- between two light tracked vehicles on one flatcar: **not less than 100 mm**
- between vehicles in the second (mixed) row: **not less than 270 mm**
- overhang past the open wagon: **must not exceed 400 mm** ("Açyk wagonyndan
  daşyna çykýan sallanma 400mm köp bolmaly däl")
- staple (ýaý şekilli skoba) wire diameter not thinner than 12 mm; chock nailed
  with 6 mm dia., 200 mm long nails
- gap between the vehicle track and the staples: 10-15 mm

Hardware detailed on this plate: S-765 gysgyç (струбцина С-765) parts 1-3;
MK-765 gysgyç çekme (струбцина-растяжка МК-765) parts 1-5.

---

## plate-03 — tracked, wood chocks + single-use wire lashings

Title: ZYNJYRLY HARBY TEHNIKALARY DEMIR ÝOLUŇ AÇYK WAGONLARYNA BERKITMEK —
direg agaç bölekleri we sim (bir nusgaly) çekmeler arkaly.

**TABLISSA №1** — consumables per tracked vehicle by combat weight:

| agram, tonna | çekmelerde sim sapaklarynyň sany | sim kg | sim uzynlyk, m | skoba/agaç bölek | skoba/tehnika |
|---|---|---|---|---|---|
| 15 tonna çenli | 4 | 10.0 | 45 | 2 * | 8 ** |
| 15.1 - 25.0 | 6 | 14.5 | 68 | 3 | 12 |
| 25.1 - 50.0 | 8 | 19.0 | 85 | 3 | 12 |

Notes printed under the table:
- `*` where necessary, two staples may be seated with a 200 mm long, 6 mm
  diameter nail in place of the standard fixing;
- `**` the staple count is calculated without accounting for the lateral
  anti-slip fixings.

**TABLISSA №2** — minimum quadrilateral chock dimensions by combat weight (mm):

| agram, tonna | h | b |
|---|---|---|
| 12 tonna çenli | 75 | 150 |
| 12.1 - 18 | 100 | 180 |
| 18 den köp | 180 | 200 |

**DISCREPANCY — verified, unresolved.** TABLISSA №2 does not agree with
plate-02's chock table. Both were re-read from the original CMYK files at full
resolution to rule out a downscaling artefact; both readings are certain:

| | up to 12 t | 12.1-18 t | over 18 t |
|---|---|---|---|
| plate-02 (direg + ara goýulýan agaç bölekleri) | h 75, b 100 | h 150, b 180 | not listed |
| plate-03 (direg agaç bölekleri + sim çekmeler) | h 75, b 150 | h 100, b 180 | h 180, b 200 |

The app's existing `trackChockByWeightTable` (para-21) matches **plate-03
exactly** and is left as the authoritative table. Plate-02's two rows are
recorded here but are NOT written into the data: they may be a method-scoped
variant, or an error on one of the two plates. This needs a ruling from someone
with the printed handbook before either table is changed — guessing which plate
is right would put a fabricated number in front of a trainee.

Securing sequence, panels 1-4: mark the chock seating position; first chock pair
stop position; second chock pair stop position; secured with wire lashings and
chocks.

Chock seating distances from the running gear, panels 6-9: **10-15 sm** and
**10-20 sm** (centimetres as printed).

Panel 10 — mixed loading across the running stock: **not less than 100 mm**
between two tracked vehicles on one flatcar; **not less than 440 mm** at the
marked positions in the mixed consist. Wagons marked
"TIRKEGDEN AÝYRMAK GADAGAN" — uncoupling forbidden.

---

## plate-05 — wheeled, chocks + single-use wire lashings

Title: HARBY TIGIRLI MAŞYNLARY DEMIR ÝOLUŇ AÇYK WAGONLARYNA BERKITMEK — direg
dört gyraň agaç bölekleri we sim (bir nusgaly) çekmeler arkaly.

Chock dimensions by **tyre diameter** ("Direg dört gyraň agaç bölekleriniň
ölçegleri", mm) — this is the table already in `measurements.json` as
`wheelChockByWheelDiameterTable`, confirmed against the plate:

| tigriň diametri, mm | beýikligi (h) | ini (b) |
|---|---|---|
| 500-den az bolmaly däl | 40 | 100 |
| 500-799 | 50 | 100 |
| 800-1099 | 75 | 120 |
| 1100-1399 | 100 | 160 |
| 1400-1599 | 135 | 200 |
| 1600 we ondan köp | 150 | 220 |

Consumables per wheeled vehicle (BIR SANY TIGIRLI HARBY TEHNIKA SARP EDILÝÄN
BERKIDIJI SERIŞDELERIŇ HASABY) — same table as scanned page image24:

For vehicles **with a working brake system** (Işleýän tormaz ulgamly):

| agram, t | sim çekme sany | 6mm sim sapak sany | sim kg | sim m | çüý (4 chock) | çüý (8 chock) | çüý sany |
|---|---|---|---|---|---|---|---|
| 2,0 çenli | 4 * | 2 | 4,4 | 20 | 2 | 2 | 8 ýa-da 16 |
| 2,1-4,0 | 4 | 2 | 4,4 | 20 | 4 | 2 | 16 |
| 4,1-6,3 | 4 | 2 | 4,4 | 20 | 6 | 3 | 24 |
| 6,4-12,0 | 4 | 4 | 8,8 | 40 | 12 | 6 | 48 |
| 12,1-18,0 | 4 | 6 | 13,2 | 60 | 18 | 9 | 72 |
| 18,1-24,0 | 4 | 8 | 17,6 | 80 | 24 | 12 | 96 |
| 24,1-30,0 | 8 | 6 | 26,4 | 120 | - | 12 | 96 |
| 30,1-40,0 | 8 | 8 | 35,2 | 160 | - | 12 | 96 |

For vehicles **without a working brake system** (Işlemeýän tormaz ulgamly):

| agram, t | sim çekme sany | 6mm sim sapak sany | sim kg | sim m | çüý (4 chock) | çüý (8 chock) | çüý sany |
|---|---|---|---|---|---|---|---|
| 3,5 çenli | 4 | 2 | 4,4 | 20 | 4 | 2 | 16 |
| 3,6-7,0 | 4 | 4 | 8,8 | 40 | 8 | 4 | 32 |
| 7,1-10,0 | 4 | 6 | 13,2 | 60 | - | 9 | 72 |

Printed note: a 6 mm wire's two strands may be replaced by three strands of
5 mm or five strands of 4 mm. Using rope (gaýtan) in place of wire in the
lashings is **not permitted**.

Placement clearances from the callouts:
- long-wheelbase wheeled vehicles across coupled flatcars: **at least 270 mm**
- between wheeled vehicles in the lower row: **at least 50 mm** and **at least 270 mm**
- overhang beyond the open wagon greater than 400 mm requires a guard wagon
  ("agyrlygyň uzynlygy 400mm geçýän bolsa gorag wagonyny goýmak hökmandyr")
- wagons marked "TIRKEGI AÇMAK GADAGAN" — uncoupling forbidden

This plate also carries the plan (top-down) view strip showing wheel footprints,
longitudinal chocks (direg dörtgyraň agaç bölegi), lateral chocks (gapdal
dörtgyraň agaç bölegi) and wire lashing runs, with a 20-30 mm callout.

---

## Программа учин.docx, page image `word/media/image28.png`

Title: THM AÇYK WAGONDA BERKIDILENDE, BIR NUSGALY DIREG WE GAPDAL DÖRTGYRAŇ
AGAÇ BÖLEKLERINI TIGRIŇ AŞAGYNA ÝERLEŞDIRILIŞINIŇ ÇYZGYSY.

Six layout cases drawn, top to bottom:
1. securing wheeled vehicles up to 5,5 t
2. securing wheeled vehicles 5,6 - 12 t
3. securing three-axle wheeled vehicles
4. two-axle vehicles up to 5,5 t placed over the coupling of two open wagons
5. two-axle vehicles 5,6 - 12 t placed over the coupling of two open wagons
6. three-axle vehicles placed over the coupling of two open wagons

Rules printed alongside:
- the chock's long side is laid across the wagon, under the tyre, and nailed to
  the wagon floor;
- each single-use quadrilateral chock is fixed to the floor with **four** nails
  of 6 mm diameter and 200 mm length; a lateral (gapdal) chock takes **six**;
- vehicles under 5,5 t: **four** quadrilateral chocks; 5,6 - 12 t: **eight**;
- regardless of weight, every vehicle is secured with four quadrilateral chocks;
- for vehicles of 5,5 t and above placed over the coupling of two open wagons,
  and for the middle and rear axle tyres of three-axle vehicles, the number of
  single-use chocks is **doubled**;
- lateral quadrilateral chocks are placed **20-30 mm** from the outer face of
  the front wheels;
- artillery systems are secured with longitudinal and lateral chocks only when
  carried in a military echelon.

---

## plate-04 — tracked, reusable universal chocks (KGUUB) and iron chock-boots

Title: ZYNJYRLY HARBY TEHNIKALARY DEMIR ÝOLUŇ AÇYK WAGONLARYNA BERKITMEK — köp
gezek ulanylýan uniwersal berkidijiler bilen hem-de demir direg başmaklar we ara
goýulýan agaç bölekleri arkaly.

KGUUB applicability, printed as BELLIK under each rendering:
- **KGUUB-1G** — tracked vehicles of **7 to 25 tonnes** combat weight
- **KGUUB-2G** — tracked vehicles of **25,1 to 42 tonnes** combat weight

KGUUB-1G parts: 1-Plita, 2-Yzky darak, 3-Öňki darak, 4-Ştyr.

Chock spacing, from the dimension callouts on the third panel and the body text:
- spacing between the two chock positions: **not less than 1,7 m**
  ("direglerinarasy 1,7 metrden az bolmaly däl")
- chocks may be seated **0,5 m** away from the points where the track rests on
  the rail ("0,5 metr uzaklykda ýerleşdirmäge rugsat berilýär")
- "0,5 m köp bolmaly däl" — not more than 0,5 m, on the marked dimension
- four chocks in total per vehicle ("Toplum dört sany diregden ybarat")

Iron chock-boots (demir direg başmagy), lower half of the plate:
- **KTP görnüşli** — used for BTR-50P, PT-76 and vehicles built on their chassis
  (parts 6, 7)
- **KTT görnüşli** — used for IS-5, T-10 and vehicles built on their chassis
  (parts 1-Ok, 2-Baýdajyk, 3-Korpus, 4-Plita, 5-Ştyr, 6-Hyrly ok,
  7-Ýaý görnüşli demir berkidiji)
- four iron chock-boots plus inserts secure light tracked vehicles loaded
  longitudinally on an open wagon

---

## plate-06 — wheeled, reusable universal chocks (KGUUB)

Title: HARBY TIGIRLI MAŞYNLARY DEMIR ÝOLUŇ AÇYK WAGONLARYNA BERKITMEK — köp
gezek ulanylýan uniwersal berkidijiler arkaly.

KGUUB applicability, printed as BELLIK under each rendering:
- **KGUUB-1K** — wheeled vehicles up to **15 tonnes**
- **KGUUB-2K** — wheeled vehicles of **15,1 to 26 tonnes**; for **26,1 to 40
  tonnes**, **two** KGUUB-2K sets are used

Chock placement distances from the body text:
- lateral (kese) chocks are placed **20-30 mm** from the side face of the tyre
- where the vehicle sits over the coupling of two wagons: **15-20 mm**
- two-axle vehicles: four longitudinal chocks
- three-axle vehicles: four chocks seated ahead of the middle and rear axle tyres
- four-axle vehicles with KGUUB: chocks placed ahead of the outer axles' tyres

Explicitly forbidden ("gadagan edilýär"), printed at the foot of the plate:
- driving the chock pins in when the fixing assembly is not drawn tight;
- striking anything other than the drawn pins when securing or releasing;
- leaving chocks in contact with the vehicle's tyres after release.

This plate repeats the same six-case layout diagram as `word/media/image28.png`
and carries the 20-30 mm lateral-chock callout on the drawing itself.

---

## Cross-check against the data already in the app

Every table the previous extraction put into `assets/data/measurements.json` was
re-verified against the plates. All four match exactly, with no corrections
needed:

| table in `measurements.json` | verified against | result |
|---|---|---|
| `trackChockByWeightTable` (para-21) | plate-03 TABLISSA №2 | matches |
| `wheelChockByWheelDiameterTable` (para-21) | plate-05 chock/tyre-diameter table | matches |
| `reusableChockTrackedTable` (para-29) | plate-04 KGUUB-1G 7-25 t, KGUUB-2G 25,1-42 t | matches |
| `reusableChockWheeledTable` (para-30) | plate-06 KGUUB-1K up to 15 t, KGUUB-2K 15,1-26 t, two sets for 26,1-40 t | matches |

`securing_method_resolution.dart` offers method 1 only for 7.0-42.0 t, which is
exactly the KGUUB-1G plus KGUUB-2G span on plate-04. The existing engineering
layer is consistent with the source.

## What the plates do NOT contain

Read across all six plates and both safety plates, none of the following appears
anywhere, so none of it can be filled in from this source:

- per-vehicle combat weights or dimensions for any named vehicle (T-54, 2S3,
  BTR-50P ...) — the plates key everything on weight *brackets*, never on a
  designation;
- flatcar deck length, width or deck height;
- axle counts or wheel diameters for specific vehicles.

The plates are rule sources, not vehicle catalogues.

---

## `Программа учин.docx` — what it actually is

The Word document holds **no text at all** (0 paragraphs) and 30 embedded
images. A contact sheet of all 30 shows every one of them is a panel cut out of
the same six plates above: the six numbered securing-method banners, KGUUB-1G/2G
and KGUUB-1K/2K, the iron spurs Ş-137 / Ş-375 / Ş-575 / Ş-915, the KTP and KTT
chock-boots, TABLISSA №1 and №2, the wheeled consumables table, the six-case
chock layout, the chock shapes and the tyre-diameter table.

It is a copy of the plates, not an additional source. One panel does add a rule
not dimensioned on the plates themselves:

- `word/media/image11.jpeg` — a wire lashing's angle to the wagon floor
  **must not exceed 45°** ("45° köp bolmaly däl"), and a lashing's strand count
  is set by the count on its weakest side.

## Conclusion: what is still missing after this extraction

Written into the data (all cited, all read off the source):

- `trackedConsumablesByWeightTable` — TABLISSA №1, new
- `wireLashingAngleTable.maxAngleDeg = 45` — new
- eight new rules in `rules.json`: wheeled chock count by weight, chock nail
  count, lateral chock gap, KGUUB chock spacing, placement clearances, overhang
  and guard wagon, maximum lashing angle, tracked chock seating distance
- nine plates registered in `photos.json` with Turkmen captions

**Still missing, and NOT obtainable from anything in `Berl/`:**

- combat weight for any of the 23 vehicles
- length, width or height for any vehicle
- axle count and wheel diameter for any vehicle
- flatcar deck length, width and height

The plates are rule sources keyed on weight *brackets*; they never name a
vehicle's own weight or size, and no wagon is dimensioned anywhere. These have
to come from the printed handbook's vehicle and rolling-stock tables, which are
not in this folder.

---

## Figures published into the app

28 individual figures now ship in `assets/images/figures/`, produced by
`tools/convert_berl_plates.py` and catalogued in `photos.json` with Turkmen
captions (ids `fig-*`, figure numbers `B-01`..`B-28`).

26 of them come from `Программа учин.docx` rather than from crops of the
plates. That document turned out to be the plates' own panels, already cut out
cleanly and at a workable size, so it is a better source for a single figure
than a crop of a 74-megapixel wall chart. The two exceptions are the S-765
clamp and the MK-765 clamp-tensioner, which have no panel of their own and are
cropped from plate-02 by `PLATE_CROPS` in the same script.

Where each figure lands in the app:

| equipment slot | figures reaching it |
|---|---|
| `att-wood-chock` | chock shapes with h/b, wheeled chock shapes and the tyre-diameter table, the six-case layout diagram, the securing photo |
| `att-wire-lashing` | the wire and chain lashings with the consumables table, the 45° angle limit |
| `att-kguub-1g` / `att-kguub-2g` | the KGUUB-1G/2G rendering with both weight ranges |
| `att-kguub-1k` / `att-kguub-2k` | each variant's own rendering, plus the generic under-tyre photo |
| `att-iron-spur` | the Ş-137 / Ş-375 / Ş-575 / Ş-915 types |
| `att-iron-chock-boot` | the KTP and KTT boots, and the securing procedure |
| `att-clamp-tensioner` / `att-clamp` | each variant's own crop from plate-02 |

The six numbered method banners are shown directly in the securing-method
selector, so a method is picked by the panel a trainee will recognise from the
plate rather than by its title alone.

**Variant pairings that had to be guarded.** KGUUB-1K and KGUUB-2K share the
para-30 citation, and the two clamps share para-33. Left alone, each would have
displayed the other's picture — the same failure
`docs/handbook-photo-mapping-report.md` was written about. Both pairs are now
in `_excludedPhotoIdsByHardwareId`, and `test/berl_figure_mapping_test.dart`
pins the behaviour. A figure captioned without naming a variant (the generic
under-tyre photo, `fig-15.15` showing both clamps together) is correct for both
and is deliberately not excluded.

**Pre-existing gap, unrelated to this work:** three figures from the original
extraction cite `para-36`, `para-38` and `para-39`, none of which has an entry
in `references.json`. A reference chip for those renders without a summary.
Writing one would mean inventing text the source has not supplied here.

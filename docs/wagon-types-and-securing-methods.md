# Wagon types, securing methods, and how the hardware is drawn

Three changes that all follow from the same decision: a trainer has to *offer*
the handbook's choices, including the wrong ones, instead of hiding what the
extracted data cannot confirm.

## Wagon types: three kinds, one correct

The wagon-type step used to filter its list down to wagons that could take the
load, which — with only one loadable wagon in the data — meant it always showed
exactly one card and there was nothing to choose. It now lists all three wagon
kinds a trainee picks between:

| Wagon | Kind | May be loaded? |
|---|---|---|
| Generic open flatcar (açyk wagon) | `openFlatcar` | yes |
| Covered wagon (ýapyk wagon) | `coveredWagon` | no |
| Tank wagon (sisterna wagony) | `tankWagon` | no |

**Where they come from.** The open flatcar is the handbook's own: para. 51
gives its axle-load and ground-pressure limits. The other two are *not* a
handbook rolling-stock catalogue — they are the wrong answers from the
project's own design mockup (`Berl/harby_yukleme_simulyator.html`, `const
WAGONS`), and `platforms.json` says so in its comment so nobody later mistakes
them for extracted data.

Their unsuitability, though, is handbook-backed: every plate that places or
secures a vehicle is titled "... demir ýoluň **açyk** wagonlaryna ..." (onto
the railway's *open* wagons), and none of the securing methods — stop-blocks
nailed to the wagon floor, wire lashings to the deck, clamps on the side frame
— can be applied inside a closed body or on a tank barrel. Each unsuitable
wagon carries a `notApprovedReason` saying exactly that, in English and
Turkmen.

Tapping one does not silently do nothing: the card is badged **ÝARAMAÝAR**, and
the screen shows the reason with the para. 51 citation. Rejecting it is the
exercise. The echelon weight classes (`echelonClass`) stay off this step — they
are an accounting unit for composing a train, not something a vehicle is loaded
onto.

## Securing methods: offered, with eligibility stated

`resolveSecuringMethodOptions` used to return `UnknownSecuringMethod` as soon as
a vehicle's combat weight was missing. Since **no vehicle in the extract records
a combat weight**, that meant the six approved methods of Annex 14 §4 — the
thing the plates are built around, and the choice the design mockup offers as
its three securing options — were never offered to anyone.

They are now offered, with the distinction kept explicit:

- `AlternativeSecuringMethods.eligibilityConfirmed == true` — the weight is
  known and was checked against Table 8's 7-42 t KGUUB coverage.
- `eligibilityConfirmed == false` — the methods are offered because the
  handbook gives them for a tracked vehicle, but the weight-dependent limits
  behind them could not be checked.

Nothing downstream is allowed to lose that distinction:

- the selector prints an amber note above the choices,
- the vehicle card uses a *different* status label
  (`securingStatusAlternativesUnconfirmed`), not the plain "alternatives
  available" one,
- and `EngineeringValidator` records the applied method as **UNKNOWN, not
  PASS**, with a detail naming the missing figure. Choosing a method never
  upgrades a verdict.

A wheeled vehicle still resolves to `UnknownSecuringMethod`: the six methods are
the tracked-vehicle annex and must not be offered for a lorry just because its
weight is missing too.

## Hardware drawn as itself

On the side elevation every piece of securing hardware used to be the same sand
triangle. A trainee reading that would learn that a squared wood stop-block, a
KGUUB chock and an iron stop-boot are interchangeable, which is the opposite of
what the plates teach. Each kind is now drawn as its own object:

| Element | Drawn as |
|---|---|
| `woodChockPair` — direg dörtgyraň agaç bölegi | squared beam with grain and the nails into the wagon floor (para. 21) |
| `spacerBoard` — ara goýulýan agaç | half-round packing block, as in figure 15.8 |
| `reusableChockPair` — KGUUB | base plate, stepped comb, locking pins, as in figure 15.11 |
| `ironSpurPair` — demir şpor | toothed triangular spur biting the floor |
| `ironChockBootPair` — demir başmak | shoe with a flat sole and an upturned toe |
| `wireLashing` — sim çekme | twisted strand at roughly the 45° cap, with its tensioner |

Each kind is labelled once, in Turkmen, with a leader line down to a two-row
label band so names cannot overprint each other; the full name with the
selected type code and Table 3 dimensions stays on the element and appears when
the trainee taps it in the plan view. The compact strip at the top of the
placement screen draws the same shapes with labels off, where there is no room
for them.

---

# Choosing the direg, and the two views a profile cannot give

## Which direg, and how it is placed

The chock was previously a size and nothing else: `schematic_builder.dart` drew
two of them at a hard-coded `[0.30, 0.70]` whatever the handbook said, so a case
calling for four chocks and one calling for sixteen looked identical. The plates
draw several arrangements, and the trainee now chooses between them.

**What the plates give, all now in `rules.json` with citations:**

- `rule-tracked-chock-arrangement` (plate-02, read off the plate's own body
  text): *"Her bir zynjyrly maşyn dört sany direg agaç bölekleri we keseligine
  dört sany ýarym aýlaw agaç bölekleri arkaly berkidilýär"* — four longitudinal
  squared blocks and four transverse half-round inserts, two per side, the first
  pair blocking forward movement and the second rearward. The chock's length may
  not be less than the track's width; each block is fixed with 6 mm x 200 mm
  nails and a staple of not less than 12 mm.
- The same paragraph gives **two alternatives, joined by "ýa-da"**, for stopping
  the vehicle sliding sideways: **twelve** staples nailed three at a time on the
  inner face of the track, **or** squared blocks of **100x100x2000 mm** along the
  inner and outer faces. The app offers exactly that choice.
- `rule-tracked-chock-seating-distance` (plate-03): seated **10-15 cm** from the
  running gear, or **10-20 cm** in the alternate arrangement the plate's panels
  draw.
- `rule-wheeled-chock-arrangement` (plate-06 and the docx page image28): the six
  layout cases — up to 5.5 t, 5.6-12 t, and three-axle, each on one open wagon
  and again over the coupling of two — with the doubling the plate states for a
  three-axle vehicle's middle and rear tyres and for a vehicle of 5.5 t or more
  spanning a coupling.

**How it flows through the app.** `chock_arrangement_catalog.dart` builds the
selectable cases from those rules (never from constants in code, exactly as
`equipment_catalog.dart` builds equipment options from `measurements.json`).
`ChockArrangementSelector` offers them with their figure and citation.
`chock_layout.dart` turns the chosen case into chock positions — seated against
the vehicle's own run indicators, ahead of and behind each tyre or at each end of
a track, because "the chock's long side is laid across the wagon, under the
tyre". `SchematicBuilder` then emits that many chocks, plus the transverse
inserts for the tracked cases, and the elevation draws them.

`checkChockArrangement` scores the choice. The coupling case is always checkable,
because whether the vehicle spans a coupling is a fact `PlacedVehicle` carries.
The weight bracket usually is not: no vehicle in the extract records a combat
weight, so the verdict stays **UNKNOWN** and names the missing figure rather than
calling a guess correct.

## The end view and the detail zoom — what was asked for as "3D"

A side view cannot show a lateral quantity, and nearly every chock rule is
lateral: the 20-30 mm gap from the tyre's outer face (15-20 mm over a coupling),
the two tracks side by side, the 400 mm overhang past the wagon's edge. That is
what a 3D scene would have been used for, so the app now draws the handbook's own
third view instead:

- `end_elevation_painter.dart` — the vehicle from the end of the wagon: deck,
  both runs, a chock outboard of each with the gap dimensioned, and the overhang
  limit against the wagon edge.
- `chock_detail_painter.dart` — the plates' circular detail bubble: one chock
  seated against the running gear, its nails (four for a longitudinal block, six
  for a lateral one), the staple over it, and the seating distance.

Both take their numbers from `chock_detail_spec.dart`, which reads them out of
`rules.json`; neither painter contains a millimetre of its own. Both remain
proportioned drawings, not scale drawings, for the same reason as the side
elevation — no vehicle or wagon in the extract has a measured width — so the
dimensions are lettered on as callouts instead of being distances on screen.

Full 3D was considered and rejected: it would add no rule the app can check, and
per-vehicle geometry does not exist in the source, so every model would have to
be invented. If the printed handbook's dimension tables ever arrive, these views
and the side elevation can become scale-accurate at once.

## Wheeled vehicles in the catalogue

Half of this was unreachable while every vehicle was tracked, so ZIL-131,
KamAZ-43114 and Ural-4320 were added from the design mockup, marked
`"dataSource": "designMockup"` and badged **MAKET MAGLUMATY** wherever they
appear. The mockup states an unladen weight (boş), which is not the combat weight
the chock rules are keyed on, so it is recorded as `transportWeightT` and the
combat weight stays a TODO — the rules that need it answer "not known" rather
than answering from the wrong number.

---

# Two vehicles on one wagon, and the deck budget

Putting a second vehicle on a wagon used to be a drawing operation and nothing
more: the placement screen accepted any number of vehicles, the schematic
squeezed them into equal slots, and no rule was ever applied between them. The
clearance figures had been extracted from the plates and sat unused in
`rules.json`.

## What the wagon now works out

`wagon_capacity.dart` computes a deck budget for each wagon:

- **Vehicle lengths** — from the vehicle record, or from a figure the
  instructor typed in (see below).
- **Clearance between neighbours** — from `rule-placement-clearance`: **100 mm**
  between two tracked vehicles on one flatcar (plate-02), **50 mm** between two
  wheeled ones in a row (plate-05), **270 mm** for a mixed pair, which is the
  only figure the source gives for vehicles of different kinds standing
  together. Charged once per *gap*, so n vehicles are charged n-1 gaps — not
  one per vehicle, which would quietly eat a gap's worth of deck.
- **Remaining length** — deck minus the above, reported in centimetres and as a
  bar, with `checkWagonCapacity` returning PASS, FAIL (by how much it is over)
  or UNKNOWN (naming the figure that is missing).

A vehicle resting across a coupling is charged to the **first** wagon of the
pair only, and the second wagon's panel says so. Charging it to both would have
made a two-wagon load look twice as long as it is.

## Where the lengths come from

The handbook extract dimensions nothing — no wagon deck, no vehicle — so the
budget would be permanently uncomputable on extracted data alone. The panel
therefore offers to take a length from the instructor, stored in
`userDimensionsProvider` under its own keys and shown as **EL BILEN GIRIZILEN**
(entered by hand) with a note that it is not handbook data. A typed figure is
never written into the vehicle or platform record, and never loses its label.

## Backend defects found and fixed in the same pass

- **A wheeled vehicle read the tracked chock table.** `equipmentOptionsFor` and
  `requiredTypeCodeFor` always used Table 3 (chock size by *combat weight*).
  Table 2 sizes a wheeled vehicle's chock by *wheel diameter*; a lorry was
  being offered — and could be scored against — a size the handbook never
  prescribed for it. Both are category-aware now, and `requiredTypeCodeFor`
  returns null for a wheeled vehicle rather than a bracket from the wrong
  table, because no record carries a wheel diameter.
- **The bracket parser could not read Table 2's wordings.** `"under 500"` and
  `"1600 and above"` matched nothing and failed silently. Both forms are
  handled now, and the function is renamed `valueMatchesRange` since it reads
  millimetres as readily as tonnes.
- **The validator carried a second copy of the lashing rule.**
  `w <= 24.0 ? 4 : (w <= 40.0 ? 8 : null)` was hardcoded beside
  `requiredWireLashingCount`, which reads the same brackets from `rules.json`.
  The duplicate is gone.
- **A wheeled vehicle with no recorded weight resolved no hardware at all** —
  no chocks, no check, no explanation, which is every lorry in the catalogue.
  The plate requires quadrilateral chocks for a wheeled vehicle whatever it
  weighs (only the count depends on the bracket), so the chock is now always
  required and the lashing count reports UNKNOWN instead of silence.
- **A tracked vehicle over a coupling could never pass its chock arrangement.**
  The tracked seating cases were built with `spansCoupling: false` hardcoded,
  so the coupling comparison failed every such placement whichever case was
  chosen. The cases are now stamped with the placement's actual situation.
- **The arrangement selector explained itself wrongly.** It showed "combat
  weight missing" whenever no case was recommended — but a tracked vehicle
  never has one, so the note appeared even where the weight was recorded. It
  now keys on the weight itself, and marks the handbook's own case when there
  is one.
- **An English evidence string leaked into the Turkmen interface** — the
  doubling reason from `rules.json` was printed verbatim under a case. The UI
  says only that the count is doubled; the wording stays in the data as the
  evidence trail.

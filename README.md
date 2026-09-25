# Military Railway Loading Simulator (RailSim)

An educational, non-game engineering trainer for securing armored vehicles on
railway flatcars, built for Flutter Desktop (Windows and Linux). This is v0.1 —
a working architectural skeleton with the **first handbook's real data**
loaded end-to-end, not a finished product. Read this file before assuming
any number in the app is fact.

## 0. This copy

This is `railsim_future`: the same application as `railsim_flutter_project`,
with the same data, the same engineering rules and the same flow, wearing a new
interface. Nothing below §1 changed in substance — what changed is how the
program looks and how it is laid out.

The visual world is recorded in `DESIGN.md`, the product record in
`PRODUCT.md`, and the direction it was built to in
`.impeccable/surfaces/`. The short version: the interface is a measuring
instrument, not a dashboard. A near-black measured field, one cyan instrument
light that always means *measured*, amber for what the handbook does not
confirm and red for what is out of tolerance, hairline rules instead of cards,
square corners everywhere, mono lettering for every legend and every measured
value and a humanist sans for prose. The five-step breadcrumb became the stage
index down the left edge; each screen's one advancing control sits at the foot
on the right and says what is missing when it is dark.

**Looking at the screens.** The application is a desktop program, so there is a
harness that renders every screen to a PNG without needing a window manager:

    RAILSIM_SHOTS=.impeccable/review flutter test test/screenshot_harness_test.dart

It writes one file per screen — both the empty state and, for the screens that
have one, a state with a consist and a placed vehicle. Without `RAILSIM_SHOTS`
the file skips, so it costs nothing in an ordinary test run. See
`test/screenshot_harness_test.dart` for why the captures are taken the way they
are.

## 1. Source of truth

Everything under `assets/data/*.json` is derived from ONE document:

> *Rules for transporting troops by rail, water, and air transport*
> Türkmenistan Ministry of Defense / Ministry of Industry & Communications,
> Joint Order No. 145/175-ö, 03 July 2019. (Turkmen language original.)

**What this handbook extract actually contains** (pages available to this
project): general echelon-loading procedure (Chapter II), and Annex 14 —
generic, weight-class-based fastening hardware and rules (wedges, nails,
wire lashings, staples, reusable universal chocks, iron spurs, iron
chock-boots, clamp-tensioners).

**What it does NOT contain**: per-vehicle spec sheets (length/width/height/
combat weight/ground clearance/track width/wheelbase), vehicle photographs,
vehicle blueprints, or a named flatcar-model catalog. It records no
centre-of-gravity height and no tie-down point count either — and neither does
any manufacturer's specification, so those two were removed from the model
rather than kept as cells nothing could ever fill (see §7).
Every vehicle IS named somewhere in the text (either a proper name like
"T-54" or a bare factory "object number" like "Object 172"), but none of
them come with a dimension table in this extract.

**Consequence for this codebase**: every dimensional field in
`Vehicle`/`Platform` is a `HandbookField` (`lib/data/models/handbook_field.dart`)
that is either a real number pulled from the handbook, or the literal string
`"TODO: Fill from Handbook Page XX"`. The UI always shows which one it is
(see the `DATA %` badge on vehicle cards). **No engineering value in this
project was invented** — where the handbook doesn't say, the app says TODO,
not a plausible-looking guess. This is enforced by construction: there is no
code path in the model layer that assigns a bare `double` to a dimension
field.

If you have additional pages of this handbook (or a different one) with
actual per-vehicle dimension tables, drop the values into `vehicles.json` /
`platforms.json` by replacing the relevant `"TODO: ..."` string with the
number and a `referenceId` pointing at a new entry in `references.json`
citing the page. Nothing else in the app needs to change.

## 2. What's real in this build right now

- **6 named legacy vehicles** with full handbook citations: T-34, IS-4,
  T-10, T-54, T-55, PT-76, BTR-50P — each mapped to its required iron
  chock-boot type (Table 11).
- **~18 "object number" vehicles** (155, 166, 172, 219, 434, 2S1, 2S3, 2S4,
  2S5, 2S7, 2A6, PTS-2, PTS-M, etc.) mapped to their required iron spur type
  (Table 13). Object numbers are kept exactly as the handbook writes them —
  no NATO/common name has been guessed onto a bare number.
- **Real hardware catalog**: KGUUB-1G/2G/1K/2K reusable chocks, Ş-series iron
  spurs, KTP/KT-34/KT-137/KTT iron chock-boots, MK-765/S-765 clamps, wire
  lashings, wood stop-blocks — all with real dimensions/weights from Tables
  2–3, 4–5, 7–11 (`assets/data/measurements.json`, `attachments.json`).
- **Real validation rules**: axle-load and ground-pressure limits for
  ramp-free flatcar loading (para. 51), wire-lashing angle→strand-count
  lookup (Table 7), weight-bracket→hardware selection (paras. 29/30/55).
- **21 real figures** extracted directly from the handbook's embedded media
  (`assets/images/`), captioned and cross-referenced in `photos.json`.
- **The engineering validation engine is honest about gaps**: for any check
  it can't compute (e.g. per-axle load, which needs an axle count this
  extract doesn't give), it reports `CheckStatus.unknown` with an explicit
  reason — never a false pass or a fabricated fail.

### 2.1 The three-dimensional loading view

The placement screen draws the selected wagon and its load as a solid you can
turn: the vehicle on the deck, the stop blocks against its tracks, the wire
lashings run to the deck rings, over rails and sleepers. It is generated by
the application from the vehicle's and the wagon's real dimensions — there is
no 3D package, no model file and no network dependency — so the heights and
overhangs it reports under the picture are readings off a measured object.

The securing gear in that scene is **placeable**: the trainee picks a piece
from a list of everything the handbook states a size for — every stop-block
weight bracket, the half-round insert, plate-02's side block and staple, the
packing board, both KGUUB variants, all eleven iron spurs, all four stop-boots
and the wire lashings — puts it on the wagon, and drags it anywhere on the
deck, with an assist that seats a block under the running gear at the
handbook's own distance. That is
the point of building the scene from real metres — the plates dimension one
thing about a stop block, how far it stands off the running gear, and the view
now measures that on a block the trainee placed themselves and checks it
against the range the chosen arrangement states.

A vehicle can also be drawn from an **actual model file** rather than from its
dimensions: drop a Wavefront `.obj` into `assets/models/`, record its author,
source and licence in `assets/data/vehicle_models.json`, and the view draws
that mesh — scaled to the dimensions the record states, seated on the running
surface, and reported on if it lands away from them. Only the appearance is
replaced; every measurement is still taken against the record. See
`assets/models/README.md`.

It appears for any vehicle whose record carries real dimensions: the T-72 and
the T-90S, and all three lorries — the ZIL-131, the KamAZ-43114 and the
Ural-4320, each drawn as the three-axle truck its record describes, cab-over or
bonneted. Every other vehicle in the catalogue has `TODO` dimensions and keeps
the flat views. Every other vehicle in the catalogue has `TODO`
dimensions and keeps the flat, explicitly illustrative views. See
`docs/three-dimensional-loading-view.md`.

## 3. What's scaffolded but not fleshed out

- Positioning is display-only (no drag-and-drop yet) — `SimulationScreen`
  renders a to-scale top view when both vehicle and platform dimensions are
  available, and an honest placeholder when they aren't.
- Side/Front/Isometric views are placeholder panels (`_ViewPlaceholder` in
  `simulation_screen.dart`) — the top-view painter
  (`lib/presentation/widgets/visualization/top_view_painter.dart`) is the
  pattern to replicate for the other three.
- PDF report export, SQLite persistence, Test Mode / grading, Instructor
  Mode, and the securing-rope/chain 3D-ish diagram overlay are **not
  implemented** — they're named extension points (see §6).

## 4. Architecture

```
lib/
  core/            theme, router, constants — no business logic
  data/
    models/        Vehicle, Platform, AttachmentType, Principle,
                    HandbookReference, SimulationResult, HandbookField
    repositories/   HandbookRepository — the ONLY place that knows the
                    data currently lives in JSON assets. Swap to SQLite
                    or a REST backend by editing only this file.
  domain/
    usecases/       EngineeringValidator — pure Dart, no Flutter imports,
                    fully unit-testable, implements the actual handbook
                    rules against a Vehicle+Platform pair
  presentation/
    providers/      Riverpod wiring (repository -> validator -> UI state)
    screens/        one folder per app-flow step (matches the required
                    Main Menu -> Vehicle -> Platform -> Simulation ->
                    Analysis -> Result flow)
    widgets/        cards/ (selection cards), visualization/ (painters),
                    common/ (citation chip, data-completeness badge)
assets/
  data/*.json       the handbook-derived database (see §1)
  images/*.png      real figures extracted from the handbook docx
test/               unit tests for HandbookField and SimulationResult
```

Patterns used: Clean Architecture layering (data → domain → presentation),
Repository pattern (`HandbookRepository`), MVVM-via-Riverpod (screens are
thin, `*Provider`s hold derived state), GoRouter for navigation matching the
mandated flow.

Manual JSON `fromJson`/`toJson` (no `freezed`/`json_serializable`
codegen) was a deliberate choice: this sandbox has no network access to run
`build_runner`, and hand-written models keep the project buildable offline.
If you want codegen once you're on a machine with pub.dev access, converting
these classes to `freezed` is mechanical.

## 5. Running this project

This container has no Flutter SDK and no network access, so the code here
has **not been compiled or run** — it's been hand-checked (brace/paren
balance, JSON validity, type consistency by inspection) but you should run
it locally before trusting it further:

```bash
flutter pub get
flutter run -d windows      # or: flutter run -d <your-desktop-device-id>
flutter test                 # runs test/handbook_field_test.dart and
                              # test/vehicle_and_result_test.dart
```

If `flutter analyze` surfaces anything, it's almost certainly a minor
import/typo issue rather than an architectural one — the module boundaries
above should hold.

## 6. Extension roadmap (why the architecture is shaped this way)

- **More vehicles/platforms**: add JSON entries; no Dart changes needed
  unless a genuinely new field type appears.
- **A second handbook**: add `vehicles_book2.json` etc., extend
  `HandbookRepository` to merge sources, tag every reference with a
  `handbookId` in `references.json`.
- **SQLite**: `sqflite_common_ffi` is already a dependency; implement a
  second `HandbookRepository` (or a decorator) that reads from a `.db` file
  instead of `rootBundle`, seeded from these same JSON files on first run.
- **Drag-and-drop positioning**: wrap `TopViewDiagram`'s vehicle rect in a
  `Draggable`/`DragTarget` pair; snap logic reuses the existing symmetry
  rule (`principle-symmetry`) as the snap target.
- **PDF report**: `pdf` + `printing` packages are already dependencies;
  build a `ReportGenerator` use case that takes a `SimulationResult` and
  renders the same data the Result screen shows.
- **Test Mode / grading**: add a `TestModeController` that hides
  `HandbookReferenceChip` tooltips and principle explanations, records the
  student's chosen hardware, and diffs it against
  `EngineeringValidator`'s resolved hardware list for a score.
- **Side/Front/Isometric views**: copy `top_view_painter.dart`'s structure;
  the only new geometry needed is which two of (length, width, height) each
  view projects.

## 7. Known data caveats to resolve before operational use

- `measurements.json` → `wireLashingAngleTable`: a few interior cells of
  Table 7 were not fully legible in this extract (marked `null`) — verify
  against the source page before relying on them.
- `measurements.json` → `staplesTable`: row values weren't captured, only
  the column structure — currently a stub.
- `vehicles.json` → `veh-is4`: the handbook table row is ambiguous between
  "IS-4" and "IS-5" — flagged, not resolved.
- `vehicles.json` → `veh-t90s`: **not a handbook vehicle.** Annex 14's
  catalogue stops at the Soviet-era types and never names a T-90 of any
  variant, so no securing method is assigned to it by name and none may be
  inferred from the tables that are. Its figures are the manufacturer's
  published specification for the T-90S, carried under
  `dataSource: manufacturerSpec` and badged as such wherever the record is
  shown. It was added so that a machine units actually move by rail could be
  worked through — and it is the only vehicle with dimensions real enough for
  the three-dimensional view to build a solid from (§2.1), and the only one
  whose record lets the para. 51 ground-pressure limit be computed at all.

  What the catalogue decides for it: Table 3 sizes its stop blocks at
  180 x 200 mm (the open-ended "over 18.0" bracket), plate-03's TABLISSA No.1
  gives eight strands per lashing, plate-02 calls for four stop blocks and four
  transverse inserts, and approved securing methods 3 and 5 resolve with
  eligibility confirmed. What it does **not** decide: at 46.5 t the vehicle is
  above Table 8's 42 t KGUUB coverage, so method 1 does not apply to it; its
  nominal ground pressure is 0.94 kg/cm² against para. 51's 0.8, and its weight
  is above that paragraph's 15 t side-ramp special case, so both of those
  checks fail — meaning it cannot cross the wagon's side edges directly and
  needs proper loading ramps. Those are real facts about the load, and the app
  reports them rather than hiding them.
- **Removed fields**: `centerOfGravityHeightAboveDeckM` and
  `tieDownPointCount` are gone from `Vehicle` and from every record. No
  source publishes either for any vehicle, so they were permanently empty:
  they dragged every vehicle's `DATA %` badge down and left para. 34's
  centre-of-gravity check reporting "cannot be decided" on every evaluation
  ever run. The rule itself is untouched in `rules.json` and still readable in
  the reference browser — a trainee can look up para. 34's limit; the
  application simply no longer pretends it can check it. `dataCompleteness` is
  now over eight fields rather than ten.
- `vehicles.json` → `veh-t72`: **the handbook does cover this one**, under its
  factory designation. Table 13 lists "Object 172" inside the grouped entry
  `veh-obj-family-137` and assigns that whole group iron spur Ş-137 — so the
  T-72's securing method is mandated by name, not chosen. The one thing here
  that is *not* from the handbook is the identification itself: the extract
  never writes "T-72". That is why this is a separate record rather than the
  family entry being renamed, which §7's own rule forbids. Dimensions are the
  manufacturer's baseline T-72 specification (41.0 t, hull 6.86 m, 3.59 m wide,
  2.19 m high, 0.47 m clearance, 580 mm shoes, 4.27 m bearing length), giving
  a nominal ground pressure of 0.83 kg/cm² against para. 51's 0.8 — over, but
  only just, where the T-90S reaches 0.94.
- Object-number vehicles are deliberately NOT given a guessed common name.
  If you can verify (from a source *other than this handbook extract*) that,
  e.g., "Object 172" is a T-72, add it as a separate verified field —
  don't overwrite `handbookDesignation`.

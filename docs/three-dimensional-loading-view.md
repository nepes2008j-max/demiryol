# The three-dimensional loading view

*Added alongside the T-90S vehicle record. Read section 1 of the README
first — the rule this subsystem lives under is the same one everything else
in the project lives under.*

## 1. What it is

A vehicle standing on a flatcar, chocked and lashed to it, over the rails,
turnable to any angle. It is drawn by the application itself: there is no 3D
package, no model file, no asset to ship, and no network access needed to
build it. The whole renderer is about 700 lines of plain Dart and one
`CustomPainter`.

Files, in the order the data flows through them:

| File | Job |
| --- | --- |
| `lib/domain/models/scene3d.dart` | `Vector3`, `Face3`, `Mesh3`, `SurfaceMaterial`. No Flutter import. |
| `lib/domain/usecases/mesh_primitives.dart` | Boxes, extrusions, lofts, cylinders, rods, track links. |
| `lib/domain/usecases/vehicle_mesh_builder.dart` | `VehicleMeshSpec`, the tracked builder, and the dispatch both kinds come through. |
| `lib/domain/usecases/wheeled_vehicle_mesh_builder.dart` | A lorry: chassis, cab, bed and tilt, wheels on their axles. |
| `lib/domain/usecases/flatcar_mesh_builder.dart` | The wagon and the permanent way under it. |
| `lib/domain/models/securing_placement.dart` | `SecuringPiece` / `SecuringLayout` — the gear as placed. |
| `lib/domain/usecases/securing_mesh_builder.dart` | One solid per placed piece, tagged `securing.<id>`. |
| `lib/domain/usecases/securing_hardware_catalog.dart` | Everything that can be put on the wagon, sized from the tables. |
| `lib/domain/usecases/securing_layout_builder.dart` | The handbook arrangement to start from, and where a new piece lands. |
| `lib/domain/usecases/securing_snap.dart` | Pulls a dragged block onto the running gear — an assist, never a rule. |
| `lib/domain/usecases/securing_measurements.dart` | How a placed block sits, and the seating-distance check. |
| `lib/domain/usecases/scene3d_picking.dart` | Ray casting: which piece is under the pointer, and where on the deck. |
| `lib/domain/usecases/loading_scene_builder.dart` | Puts the vehicle on the wagon, secures it, and measures the result. |
| `lib/domain/usecases/vehicle_mesh_catalog.dart` | Decides whether a vehicle record can be modelled at all. |
| `lib/domain/usecases/obj_mesh_loader.dart` | Reads a real `.obj` model file and fits it to the record. |
| `lib/domain/usecases/scene3d_camera.dart` | Orbit camera, projection, back-face culling, depth sort, shading. |
| `lib/presentation/widgets/visualization/scene3d_painter.dart` | Material → colour, and fill. |
| `lib/presentation/widgets/visualization/loading_scene_3d_view.dart` | The interactive view and its readouts. |

## 2. Loading a real model file

A vehicle can be drawn from an actual model instead of from its dimensions.
Drop a Wavefront `.obj` into `assets/models/`, add a record to
`assets/data/vehicle_models.json` with its author, source and licence, and the
three-dimensional view draws that mesh instead. Nothing else changes: every
vehicle without a file keeps the built one. See `assets/models/README.md`.

Three things happen to a file on load, and the third is the point:

1. **Reorient** from the convention it was authored in — y-up facing `-z`,
   y-up facing `+x`, or Blender's z-up facing `+y`.
2. **Scale uniformly** to a dimension the record states, and seat it on the
   running surface. The default is the **width**: a tank's widest point is its
   tracks or fenders, which every model has and every record states, whereas
   its length depends on where the gun is trained and on how much stowage the
   modeller hung off the rear plate. (Fitting this project's own T-72 on
   length rather than width put it a quarter of a metre narrow — the fuel
   drums are outside the 9.53 m the record means.)
3. **Report the residual.** How far the fitted mesh lands from the recorded
   height, width and length is handed back rather than swallowed. A downloaded
   mesh is modelled to *look* right, not to *measure* right, and this scene
   exists so that load height and overhang are readings. A model that comes
   out 12 cm too tall is telling you something.

**Only the appearance is replaced.** The lashing eyes, the track's bearing
range and its centre line all still come from the record's dimensions, and
they have to: a downloaded mesh knows nothing about where a stop block goes,
and every measurement the scene reports is taken against those points rather
than against whatever the file happens to contain.

A model file is somebody else's work. A record missing its author, source or
licence is **not loaded** (`VehicleModelAsset.isAttributed`), and the credit
line is shown under the scene whenever a loaded mesh is drawn.

## 3. Why the fallback is built rather than loaded

A glTF or OBJ model of a T-90S would have been quicker to display and worse
in every way that matters here. A downloaded model is drawn to *look* right;
it carries no guarantee that its hull is 6.86 m or that its roof is 2.23 m
above the ground, and the whole reason for having a solid on screen is to
read heights and overhangs off it. Building the mesh from
`TrackedVehicleMeshSpec` makes the dimensions the input rather than a
coincidence — and it means the drawn machine changes when the record changes,
which is the behaviour a data-driven trainer needs.

It also keeps the deployment honest: these machines may have no network, and
this adds no dependency to `pubspec.yaml` at all.

## 4. Lorries as well as tanks

`VehicleMeshSpec` is what the scene, the securing gear and every measurement
work in: body length, overall width and height, ground clearance, and the
width of **one bearing surface** — a track shoe or a tyre. Both concrete specs
implement it, `buildVehicleModel` dispatches on which, and nothing above that
line is a special case. A stop block is "under the running gear" by the same
test whichever it is holding down.

What differs is where the running gear *is*. A tracked vehicle bears
continuously along its track, so the securing gear seats against the ends of
that bearing length. A lorry bears at points, and plate-06 puts a chock under
**each tyre** — so `VehicleModel3.wheelContactX` carries every axle, and the
outermost tyres stand in for the ends of a track.

That distinction reaches the trainee. A block on a lorry is measured from the
**nearest wheel**, and the readout names which: *"Tigirden aralygy — 2-nji
ok"*. Measuring from the outermost tyre, as a track's bearing end is measured
from, gave a figure about nothing — a block correctly seated at the middle
axle of a six-wheeler read as a metre and a half from "the running gear". The
centimetre entry above it is measured from the same wheel, so typing a figure
and reading one back cannot disagree.

Three fields of a lorry's spec are the record's: length, width and height. They
are also the only three any reported measurement rests on — load height,
overall width, overhang past the deck, and the space to the next vehicle. The
rest (where the axles sit, wheel and tyre size, how far back the cab ends) are
**drawing proportions**, held together in `WheeledVehicleMeshSpec` and named as
such, because no record in this catalogue carries a wheelbase or a ground
clearance for any lorry. The one shape fact that *is* recorded is the axle
count, and it decides how many wheels are drawn — which is what plate-06 counts
chocks by.

The drawn lorry is held to its recorded length, width and height exactly. That
is not cosmetic: the overhang and width the scene reports are measured off the
mesh bounds, so a body that stopped 4% short of the tail, or mudguards that
overhung the recorded width, would have made those figures wrong. Both were
caught by testing the bounds against the record rather than by looking.

## 5. The world frame

* `+x` along the track, towards the head of the train.
* `+y` up, with **`y = 0` at the top of the rail head** — the same zero the
  railway measures loading gauge from, so deck height, vehicle height and
  load height are all directly comparable.
* `+z` to the right looking along `+x`.
* Everything in metres. The conversion from the handbook's centimetres and
  millimetres happens once, at the edge (`FlatcarMeshSpec.fromPlatformFigures`,
  `VehicleMeshCatalog.specFor`, and the chock sizes in the view).

## 6. The winding contract

Every primitive emits polygons wound counter-clockwise **seen from outside
the solid**, so `Face3.normal` points outwards and the renderer can cull back
faces. One reversed winding is not a shading glitch — it is a hole through
the model, and on a scene of several thousand faces it is nearly impossible
to find by eye afterwards. `test/scene3d_test.dart` therefore asserts, for
each primitive, that every face normal points away from a point known to be
inside the solid.

The renderer is a painter's-algorithm one: cull, sort far-to-near by distance
from the eye, fill in that order. Its known limitation is interpenetrating
geometry, which is why the models are assembled from many small separated
solids — the track is a chain of links, not one filled silhouette. That also
happens to be why the road wheels show between the top and bottom track runs,
as they do on the handbook's own side elevations.

## 7. What can be put on the wagon

Every piece of securing hardware the source states a size for, in one list:

| Piece | Rows | Sized from |
| --- | --- | --- |
| Wood stop block | 3 (tracked) / 6 (wheeled) | Table 3 by combat weight; Table 2 by wheel diameter |
| Half-round insert | 1 | plate-02's insert table (a range; drawn at the midpoint) |
| Side block | 1 | `rule-tracked-chock-arrangement`, 100 x 100 x 2000 mm |
| Iron staple | 1 | the same rule, Ø 12 mm minimum |
| Packing board | 1 | `att-wood-packing`, 25 mm minimum thickness |
| KGUUB chock | 2 | Table 8 base plates (tracked or wheeled, never both) |
| Iron spur | 11 | `ironSpurTable` base plate + comb height |
| Iron stop-boot | 4 | `ironChockBootTable` base plate + pin |
| Wire lashing | 3 | the diameters `att-wire-lashing` carries |

Twenty-four entries for the T-90S. Each is one row of one table: the palette
shows the piece, the row it came from and the size that row states, and the
row the vehicle's own record resolves is flagged with a tick. **A piece with
no stated size is not on the list at all** — which is the only thing that makes
the list worth trusting, and is why stripping the insert table from
`measurements.json` makes the insert disappear rather than acquire a default.

A single dropdown rather than a button per kind: eleven spurs and four boots
could not be carried any other way, and it means adding a hardware table later
adds rows to the palette without touching the interface.

Two consequences worth stating:

* **The starting arrangement is built only from rows the vehicle resolves.**
  A weight that falls in no bracket lays out no stop blocks, rather than the
  trainee finding four of somebody else's size already nailed down. The
  half-round insert has one row that applies to any tracked vehicle, so that
  one is laid out regardless.
* **Being measured is not being judged.** plate-03's 10-15 cm seating range is
  written about the wood stop block. A KGUUB has a rule of its own
  (`rule-kguub-chock-spacing`: 0.5 m from where the track rests on the rail),
  and a spur or boot is bolted through the deck. All four have their distance
  measured and reported; only the wood block is checked against the wood
  block's range.

## 8. Placing the gear by hand

The blocks and wires are not scenery: the trainee selects one by tapping it and
drags it anywhere on the deck. That exists for one reason. The plates dimension
exactly one thing about a stop block — **how far its working face stands off
the running gear**, 10–15 cm for a tracked vehicle — and that is a distance.
Until the scene was built from real metres there was nothing in this
application it could be measured on, and until the block could be moved there
was nothing to measure. Now the trainee puts it somewhere and the panel says
how far off the track it ended up, and whether that is inside the range the
chosen arrangement states.

How it works:

* **Picking** is a ray cast (`ScenePicking`) against the *gear mesh alone*, so
  a block standing behind the tank is still selectable. It searches in
  widening rings up to 18 px, because a 150 mm block seen from across a
  13-metre wagon is a handful of pixels and a pointer that has to land inside
  them exactly makes the gear feel unpickable.
* **The pick happens on pointer-down**, before any recogniser has had a say. A
  scale gesture is only accepted after the pointer has travelled the touch
  slop and reports its focal point as of that moment — by which time the
  pointer has left the block it was pressed on.
* **plate-06's nails** are drawn on every wood block that takes them, four to
  a longitudinal block, so a block reads as fixed down rather than resting on
  the deck. They are not separately placeable: a nail is not a thing anyone
  positions by hand.
* **A drag** that started on a piece moves it across the deck plane; a drag
  that started anywhere else orbits the camera. One scale recogniser handles
  both, plus pinch-zoom; a second pan recogniser would fight it in the arena.
* **Snapping** pulls a block within ~30 cm of a track onto its centre line and
  seats it at the handbook's own distance off the end of the bearing length,
  turning the wedge the right way round. It is a toggle, and a block dropped
  clear of the running gear stays exactly where it was put — including
  somewhere wrong, which the trainee must be able to do or the measurement
  could never tell them anything they did not already know.
* **The block's anchor is its working face**, not its centre, so moving a block
  never changes what is being measured.
* **A wire lashing** is made fast to a ring or to nothing, so dragging one
  chooses among the rings that exist rather than dropping its end anywhere.
* The `x`/`z` clamp holds the block's *centre* on the deck, not its whole
  footprint: the T-90S's tracks overhang this wagon by a quarter of a metre
  each side, so a block seated under one has to be allowed to overhang with it.

**The deck starts empty.** It used to open with the handbook's own arrangement
already nailed down, and that was the wrong way round for a trainer used as a
test: it handed the trainee the answer and left them nothing to do but agree
with it. They now do the job in the order it is actually done — pick the piece
from the palette, state the distance from the running gear the plate calls for,
put it down, and adjust it. `SecuringLayoutBuilder.handbookArrangement` still
exists and still describes what the plates call for; it is simply not applied
on the trainee's behalf. "Clear" clears.

## 9. What the view may and may not say

The panel under the scene reports: load height above the rail, deck height,
load width, front/rear/lateral overhang, and free deck length. These are
**measurements taken off the model**, and the caption says exactly that.

It does not judge them. The handbook extract carries no loading-gauge table
and no overhang limit, so a verdict would be an invented rule. The amber
overhang line says the machine reaches past the deck — a fact — and stops
there.

Four further guards, all covered by tests:

1. **No model without dimensions.** `VehicleMeshCatalog.specFor` returns null
   for a record whose length, width, height, ground clearance or track width
   is a `TODO` marker. A lorry needs length, width and height; the rest of
   its shape is drawing proportion and nothing reported depends on it. This governs a loaded model too — a file cannot be
   fitted to dimensions that are not there. Those screens keep the flat views, which are honest
   about being illustrative. A solid built from nothing would be the most
   convincing wrong drawing in the application.
2. **No chock without a size.** A block is only ever built to a height and
   width that came from a row of Table 3. For the T-90S at 46.5 t the table
   *does* resolve one — its top bracket, "over 18.0", is open-ended, giving a
   180 x 200 mm block — so that bracket is preselected and carried on every
   piece as its `sizeTypeCode`. Where a vehicle's weight resolves no bracket,
   the view offers the table's real rows in a picker instead, marks the choice
   as the trainee's, and says why they had to make it. Where the table is not
   loaded at all there are no rows, no way to add a block, and an amber line
   explaining that.
3. **No verdict without a chosen arrangement.** The seating distance is always
   measured and always shown. It is only judged pass/fail against the range the
   arrangement the trainee *chose* states — `recommendedArrangement` returns
   null for every tracked vehicle by design, so nothing pre-selects a case on
   their behalf, and until they choose one the check reports "not determined".
4. **No implied lashing count.** The number of lashings is fixed by
   `rule-wheeled-lashing-count`, which is the **wheeled** rule (method 2,
   para. 55) and is only ever consulted for a wheeled vehicle — asking it
   about a tracked one would answer from the wrong page. For a tracked vehicle
   the extract fixes no count, so a run per attachment point is drawn as an
   indicative arrangement and captioned as one. The *strand* count is a
   different question and the tracked table does answer it by weight
   (plate-03's TABLISSA No.1 — eight strands at 46.5 t), so the wire is laid
   up with that many threads and the figure is cited under the scene. The
   attachment points themselves remain a property of the drawing: no vehicle
   in the extract has a certified tie-down point count.

5. **No insert block without the plate's size.** `rule-tracked-chock-arrangement`
   calls for four transverse half-round inserts, two a side, and plate-02's
   insert table sizes them as *ranges* (90-100 mm high, 300-400 mm long). A
   drawn solid needs one number, so the midpoint is used and the piece is
   labelled with the range it came from — never with a single figure the
   handbook did not state.

## 10. The wagon

`FlatcarMeshSpec.standardFourAxle` is the four-axle open flatcar of the
project's design mockup — 13.30 m × 2.87 m deck at 1.31 m above the rail.
Those are **not** handbook figures; `platforms.json` records length, width
and deck height as unavailable for every wagon. `FlatcarMeshSpec
.fromPlatformFigures` substitutes each figure a platform record does supply,
and `isDefaultGeometry` drives which of the two captions the view shows. The
moment real wagon dimensions are extracted, the drawn wagon becomes the
measured one with no other change.

## 11. More than one vehicle on a wagon

A flatcar can carry more than one machine, and the plates dimension the space
between them: **100 mm** between two tracked vehicles on one flatcar, 50 mm
between wheeled ones in a row, 270 mm for a mixed pair
(`rule-placement-clearance`, read by `clearanceBetween`).

That rule sat in the data and was read by nothing, because the scene took a
single vehicle: the second machine on a wagon was simply not drawn, so neither
the trainee nor the report could see whether the pair fitted.

`buildLoadedWagonScene` now takes a **list** of `PlacedLoad`s. Each carries its
own position along the deck, its own turret angle and its own securing gear,
because each is secured separately. It returns:

* `loads` — every vehicle as placed, **sorted along the wagon**, so the gaps
  are between actual neighbours rather than between whichever two the caller
  listed first;
* `gaps` — one `LoadGap` per neighbouring pair, measured between their **full**
  extents. Not their hulls: a gun trained over the vehicle behind is exactly
  what a clearance prevents, and a figure that ignored it would pass a load
  that fouls its neighbour. Turning the rear machine's gun over its own rear
  deck widens the gap; turning the front machine's gun round narrows it, and
  the measurement shows both.

`checkPlacementClearance` pairs the measured gap with what `clearanceBetween`
requires and lands in the consist checks, so it is scored and reported like any
other. A negative gap — two vehicles fouling one another — is called out as
such rather than reported as a very small clearance.

The view still **edits one placement at a time**: the others are drawn as
`SceneCompanion`s and measured against. Which one is being worked on is the
screen's existing selection, so selecting the other vehicle in the list swaps
the roles.

Worth knowing: two T-72s do not fit on a standard 13.30 m flatcar — 9.53 m each
over their guns — and the scene now says so instead of drawing one of them and
staying quiet.

## 12. Where it appears

On the placement screen (step 4), under the side elevation, the plan view and
the photographic scene, for the selected placement. Its position slider writes
back through `ConsistNotifier.dragBy` onto the same diagram the flat views
drag, so all four views of a wagon always agree about where the vehicle is
standing. The gear itself lives in `placementSecuringLayoutProvider`, keyed by
placement id like the equipment and arrangement state beside it, and is dropped
when its placement is.

Not yet wired: the engineering analysis and the result sheet do not read the
placed layout. The seating-distance check exists as a pure function
(`checkSeatingDistance`) and is shown live in the view, but `EngineeringValidator`
does not yet fold it into the report.

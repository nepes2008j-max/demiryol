# Vehicle model files

Wavefront `.obj` geometry for individual vehicles. A file dropped in here and
listed in `assets/data/vehicle_models.json` replaces the drawn model in the
three-dimensional loading view for that vehicle. Nothing else changes: the
scene keeps working exactly as before for every vehicle that has no file.

## Formats

**`.obj` and `.stl`**, and the loader works out which from the file.

OBJ is preferred: it is plain text, a couple of hundred lines read it
completely, every package exports it, and it carries `o`/`g`/`usemtl` names —
which become the part id and choose the surface colour, so the tracks come out
dark and the hull green. `lib/domain/usecases/obj_mesh_loader.dart` reads
vertices and faces (triangles, quads and n-gons, all three index forms,
negative indices).

STL is read too, in both its ASCII and binary forms, because that is what the
sites which publish freely publish — the 3D-printing repositories. STL carries
triangles and nothing else, so an STL model comes out in one colour. That is a
real loss and not a reason to refuse the file.

glTF is not read. It would mean a binary container, accessors and shader
semantics for geometry this renderer already has everything it needs to draw.

## What happens to a file on load

1. **Reoriented** from the convention it was authored in. Say which in the
   JSON: `yUpFacingMinusZ` (the game-engine default), `yUpFacingPlusX`, or
   `zUpFacingPlusY` (Blender's default export).
2. **Scaled uniformly** so its length matches the length the vehicle's record
   states, and seated with its lowest point on the running surface.
3. **Checked.** The residual disagreement in height and width against the
   record is reported. This matters more than it looks: a downloaded mesh is
   modelled to *look* right, not to *measure* right, and this scene exists so
   that load height and overhang are readings off a measured object. A model
   that comes out 12 cm too tall is telling you something, and the application
   says so rather than rendering it quietly.

Scale is uniform on purpose. Stretching one axis to hit a number would produce
a machine that exists nowhere.

## Building one from a plate, when there is no file to download

Every site that publishes a tank model puts the download behind an account
(see *Known candidates* below), which is why this directory stayed empty for
so long. But a model is not only something you fetch — it is something a
technical drawing is enough to *make*, and this project holds drawings.

`tools/build_model_from_plate.py` takes a plate that draws a vehicle in side,
top and front elevation and intersects the three silhouettes into a solid.
That is the **visual hull**, the oldest method there is for this: a point is
inside the vehicle only where all three views agree it is. It cannot recover a
concavity that no silhouette shows — the scoop under a turret bustle comes out
filled — and it is exact wherever the shape is convex, which for a hull and a
pair of track runs is nearly all of it.

    tools/build_model_from_plate.py --spec tools/plate_specs/veh-t72.json

The spec names the plate, the pixel box of each view, and the record figures
the part rules are keyed to. It prints what the model came out as against what
the record says, which is the number to read: the width is the anchor, and the
length and height it then implies are the plate's own consistency showing.

Two things the tool does that are worth knowing, because both are the
difference between a picture and something a trainee can measure:

* **The width is the anchor, never the height.** A radio mast and a
  commander's sight stand above the recorded turret roof by different amounts
  in different views. Scaling a plate by its silhouette's total height shrinks
  the whole vehicle by however tall the artist drew the aerial.
* **The running gear is seated on the ground.** A plate draws the lower track
  run as a chain, sagging between the road wheels and sweeping up onto the
  idler and the sprocket. Read literally that is a tank with a keel, which
  rocks on a wagon deck instead of standing on it. Inside the running-gear
  band the side view is closed downwards instead, which is what a track
  actually does along its bearing length.

The result is still a **depiction**. Nothing it produces is a measurement: the
Dart loader fits it to the record's own width and reports the residual, and
`test/plate_built_model_test.dart` fails if that residual grows.

And the licence question does not go away. A mesh traced from a drawing is a
derivative of that drawing, so the plate's terms are the model's terms and go
in the record exactly as a downloaded model's would.

## Adding one

1. Get the file — download it, or build it from a plate as above. It must be
   under a licence that permits redistribution — CC0, CC BY, or something the
   ministry holds outright. The vehicle photographs in this project are
   CC BY-SA and are credited the same way.
2. Save it as `assets/models/<vehicle id>.obj`.
3. Add a record to `assets/data/vehicle_models.json` with the source page, the
   author, the licence and its URL. **A record missing any of those is not
   loaded** — see `VehicleModelAsset.isAttributed`.
4. Run the tests. `test/obj_mesh_loader_test.dart` will read it, fit it and
   tell you how far it lands from the record's dimensions.

## Known candidates

Two CC BY 4.0 T-72 models are published on Sketchfab. Both are downloadable,
and both require a (free) Sketchfab account to download — which is why neither
is bundled here:

| Model | Author | Faces | Licence |
| --- | --- | --- | --- |
| [Low Poly T-72 Tank - Game Ready](https://sketchfab.com/3d-models/low-poly-t-72-tank-game-ready-8c9d0d6640a244e39082cd9fdf565cef) | Mr. The Rich | 1 488 | CC BY 4.0 |
| [Low Poly T-72](https://sketchfab.com/3d-models/low-poly-t-72-a116335b48504edb867eb70ede62b1d9) | SIpriv | 23 866 | CC BY 4.0 |

The first is the better fit: this renderer sorts and fills every face on the
CPU, so around fifteen hundred triangles for the vehicle leaves room for the
wagon, the securing gear and the track under it. Twenty-four thousand will
work but will feel heavy while orbiting.

Download either as OBJ, save it as `assets/models/veh-t72.obj`, and fill in the
record. The licence requires the author's name to be carried with it, which is
what the record is for.

Every one of these sites — Sketchfab, Thingiverse, Printables, Poly Pizza —
puts the actual file behind a (free) account or an API key. That is why none
is bundled here: the download is a step only a person with an account can take.
Both formats above are read, so whichever of them you end up with will load.

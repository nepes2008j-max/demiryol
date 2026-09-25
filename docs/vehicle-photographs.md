# Illustrative vehicle photographs — provenance and licensing

The handbook extract contains **no identification photograph of any vehicle**.
Every figure in it shows generic securing equipment or a securing procedure;
`docs/handbook-photo-mapping-report.md` records the caption-by-caption evidence,
and `isVehicleIdentificationPhoto()` in
`lib/domain/usecases/handbook_photo_resolution.dart` returns `false` for every
figure as a result. The vehicle cards therefore had nothing to show but a
category icon, and a trainee could reach the securing stage without ever seeing
the machine they were loading.

The photographs in `assets/images/vehicles/` fill that gap. They come from
Wikimedia Commons via `tools/fetch_vehicle_photos.py` and are catalogued in
`assets/data/vehicle_photos.json`.

## They are not handbook figures, and the code keeps it that way

This is the rule the whole design turns on. An illustrative photograph must
never be presentable as evidence of how to secure anything.

- **Separate model.** `VehiclePhoto` is its own type, not a `HandbookPhoto`
  variant. It has no `figureNumber` and no `referenceId`, so it cannot be handed
  to a widget that renders a figure number or a citation chip.
- **Separate manifest and directory.** `assets/data/vehicle_photos.json` and
  `assets/images/vehicles/`, never mixed into `photos.json`.
- **Separate provider.** `vehiclePhotosProvider`, not `photosProvider`.
- **Separate widget with a visible badge.** `VehiclePhotoThumbnail` prints
  **ŞERTLI SURAT** where `HandbookPhotoThumbnail` prints the figure number, and
  `showVehiclePhotoDialog` opens with the notice that the picture came from an
  outside source and is not a handbook figure.
- **The handbook always wins.** Where both could exist, `VehicleCard` and
  `showVehicleDetailDialog` show the handbook figure and drop the illustrative
  one.

## What the fetcher accepts

`tools/fetch_vehicle_photos.py` enforces three things, each because the naive
version got it wrong:

1. **Licence allow-list, not a block-list.** Only CC0, CC BY, CC BY-SA and
   public domain are accepted; an unrecognised licence is skipped rather than
   assumed free. The licence, author and Commons file page of every accepted
   file go into the manifest, because CC BY and CC BY-SA require the credit to
   travel with the image — which is why the credit line is printed on the detail
   dialog itself, not only inside the enlarged view.
2. **The filename must name the designation.** Searching "IS-4 tank" on Commons
   returns, among other things, a photograph of a Sherman, matched on loose
   words in its description. A candidate whose own filename does not carry the
   designation is rejected, because putting the wrong hull on an IS-4 card would
   teach a trainee to recognise the wrong vehicle — worse than showing nothing.
3. **One subject, not two.** A candidate whose filename also names a *different*
   vehicle on the roster is rejected for both of them. "T-54 and T-55 tanks.JPEG"
   passed the designation check and went onto the T-54 card, but the photograph
   is a yard of mixed T-54s and T-55s and a trainee cannot tell which hull is
   which. An ambiguous answer teaches as badly as a wrong one.

4. **Framing that identifies the machine.** A vehicle is recognised from its
   side, so portrait crops are rejected outright and landscape frames of a
   reasonable size are preferred. Filenames suggesting a monument, a night
   firing shot, a wreck, a cutaway, a scale model or a museum *placard* are
   penalised; earlier runs picked a T-54 on a plinth, a 2S1 firing in the dark,
   and — for the PT-76 — a photograph of the exhibit's information sign, in
   which the vehicle does not appear at all.

## Reviewed picks

A filename score cannot see the picture. It can rule out a portrait crop or a
night shot, but it cannot tell a photograph of the whole machine from a close-up
of its glacis plate, and it cannot see that a museum picture is dark and
half-hidden behind a barrier. Every fetched photograph was therefore looked at,
and three were replaced by hand through `REVIEWED_PICKS` in the fetcher:

| Vehicle | Automatic pick | Why it failed | Reviewed pick |
|---|---|---|---|
| T-54 | `T-54 and T-55 tanks.JPEG` | a yard of mixed T-54s and T-55s | `T-54-.jpg` |
| PT-76 | `PT-76 amphibious tank description.JPG` | the exhibit placard, not the vehicle | `Right side view … Soviet PT-76 …` |
| 2S7 | `… 2S7 Pion … 01.jpg` | close-up of the front hull only | `… 2S7 Pion … 02.jpg` |

A pinned file is exempt from nothing: it still has to name the designation, be
freely licensed and pass the framing check — the override only decides which
*passing* candidate wins. If Commons search moves and a pinned file drops out of
the results, the run prints a warning rather than silently falling back to the
candidate a person already rejected.

## Staying inside the rate limit

The first working version of the fetcher spent about fifteen requests per
vehicle — one search plus one metadata lookup per candidate — which exhausted
the anonymous request budget partway through the roster and then failed every
remaining vehicle with HTTP 429, no matter how long it backed off. The fix was
to stop making so many requests: `generator=search` feeds the search results
straight into `prop=imageinfo`, so a vehicle now costs **one** request. The
longer backoff and the 1.5 s spacing are the second half of the fix, not the
first.

## What is deliberately absent

Vehicles whose designation is a **design-bureau object index** — `veh-obj429`,
`veh-obj-family-137`, `veh-obj434` and the rest — get no photograph at all. Each
of those indices covers several different vehicles, so no single photograph
could honestly represent one. `test/vehicle_photo_test.dart` asserts that no
`veh-obj*` entry ever appears in the manifest.

Any vehicle for which no freely-licensed, correctly-named candidate exists is
also simply absent from the manifest; the card falls back to the category icon
and `Surat: çeşmede ýok`, exactly as before these photographs existed.

## Re-running the fetch

```
python3 tools/fetch_vehicle_photos.py --dry-run   # report candidates only
python3 tools/fetch_vehicle_photos.py            # download and write the manifest
```

The run is resumable: files already present are not re-fetched, and entries
already in the manifest are carried forward, so a Commons rate-limit failure on
one vehicle cannot drop the others. `test/vehicle_photo_test.dart` then checks
the manifest against what is actually on disk — every entry naming a real
vehicle id, every file present and non-empty, every entry carrying a licence and
a source page, and no NonCommercial or NoDerivatives licence anywhere.

## Standing the vehicle on the wagon

Two views show the vehicle on the flatcar, because they answer different
questions and neither can answer both.

### The photographic scene

`FlatcarScene` reproduces what `Berl/harby_yukleme_simulyator.html` shows: the
machine cut out of its own photograph, seated on a photograph of a green
four-axle open flatcar, over a drawn rail strip. The flatcar picture is taken
from that mockup itself (`assets/images/rolling_stock/flatcar-side.png`), so the
wagon on screen is the wagon the design was approved on.

The cut-outs come from `tools/cutout_vehicle_photos.py`, which separates the
vehicle from its background with OpenCV's GrabCut — classical segmentation, no
model weights and no network. Two things make it work well enough to ship:
the frame border is declared certain background before the first pass, so the
hall wall and the sky are learned explicitly rather than inferred from a sliver
outside the seed rectangle; and each photograph carries its own list of
background rectangles, read off the picture by eye, striking out the exhibit
panel beside the 2S1 or the second tank parked behind the T-54.

**Seven of the fourteen were accepted.** The rest are listed in the script's
`APPROVED` set with the reason they were not: the IS-4 and T-10 stand in a hall
whose windows show through their gun barrels, the PT-76's wall is the same sand
colour as its camouflage, the PTS-M is inside its own dust cloud. A vehicle with
no accepted cut-out is never stood on the wagon photograph — the drawn elevation
is shown for it instead, and one line says why. `docs/vehicle-cutout-contact-sheet.png`
is the sheet the review was done on; re-running the script rebuilds it.

### The drawn elevation

`SideElevationPainter` draws the same arrangement the way the plates draw it:
the vehicle in profile on the deck, the wagon's solebar, stake pockets, bolsters
and bogies, the rail and its sleepers, the chocks seated against the running
gear and the lashings running down to the deck. It replaces the plan-view
painter that the placement screen's "GAPDALDAN GÖRNÜŞI" slot used to borrow,
which drew the same rectangles as the plan view directly beneath it.

Every **horizontal** position in it comes from the `SchematicDiagram` —
where the deck ends, where the user dragged the vehicle, which x each chock
sits at. Every **vertical** position is a drawing convention chosen in the
painter, and the vehicle profile is generic to tracked or wheeled rather than
specific to a designation.

That split is forced by the source, and it is the one honest option: no vehicle
and no platform in the handbook extract carries a measured length, width or
height — every such field is an explicit TODO — so a drawing claiming to be a
T-34 at scale on a 13.4 m flatcar would be inventing all of it. Both views are
therefore *proportioned, not scaled*, and both say so: the elevation keeps the
existing "not to scale" banner, and the photographic scene carries its own
caption. What they show truthfully is the arrangement and the position along the
wagon, which are exactly what the trainee controls.

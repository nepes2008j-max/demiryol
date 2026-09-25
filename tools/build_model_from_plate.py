#!/usr/bin/env python3
"""Build a vehicle's `.obj` model from the orthographic views on a plate.

Why this exists
---------------
`assets/models/README.md` says a model has to come from somewhere that permits
redistribution, and lists the Sketchfab candidates — every one of which sits
behind an account nobody here can sign into. Meanwhile the project already
holds the thing a model is normally *made* from: plates that draw each vehicle
in side, top and front elevation, at one scale, on a plain ground. That is a
technical drawing, and a technical drawing is enough to build a solid from.

The method is the oldest one there is for this — the **visual hull**. Each view
gives the silhouette the vehicle casts along one axis. A point is inside the
vehicle only if it falls inside all three silhouettes at once, so intersecting
the three extrusions bounds the solid. It cannot invent a concavity no
silhouette shows (the scoop under a turret bustle comes out filled), and it is
exact wherever the shape is convex, which for a hull and a set of tracks is
most of it. What comes out is a depiction with the right length, the right
width, the right height and the right profile — which is what this scene needs,
because the trainee reads load height and overhang off it.

What it is NOT
--------------
Not photogrammetry. These are drawings, not photographs from an orbit, and no
camera pose is recovered. Nothing here is a measurement: every dimension the
application reports still comes from the vehicle record, and the Dart loader
scales this mesh to the record's own width and reports what it had to change.
See `lib/domain/usecases/obj_mesh_loader.dart`.

Part names are a drawing choice, not a source
---------------------------------------------
A silhouette has no idea where the turret stops and the hull starts. The part
boundaries below are geometric rules keyed to the *record's* own figures —
ground clearance for the running gear, width over tracks for the track runs —
and they exist only to choose a surface colour. Getting one wrong paints a
plate the shade of a track link and does nothing else. This is the same
position `VehicleMeshCatalog` takes on shape detail no source records.

Usage
-----
    tools/build_model_from_plate.py --spec tools/plate_specs/veh-t72.json

The spec names the plate, the pixel box of each view, and the record figures
the part rules need. Writing the boxes by hand is deliberate: finding them
automatically works until a plate has a caption under one view, and then it
silently models the caption.
"""

import argparse
import json
import sys
from pathlib import Path

import cv2
import numpy as np


# --------------------------------------------------------------------------
# Silhouettes
# --------------------------------------------------------------------------

def silhouette(img, open_px=5, hole_frac=0.04, threshold=18, bg_flood=False):
    """The binary silhouette of the one object drawn on a light ground.

    `open_px` sets what counts as a hairline rather than structure. A radio
    aerial and a tow cable are drawn a pixel or two wide and are not part of
    any shape the trainee measures; an opening at 5 px removes them and leaves
    a gun barrel, which is drawn ten times that.

    Two ways to tell object from ground:

    * The default, *foreground* mode, keeps every pixel that differs from the
      background by more than `threshold` and takes the largest blob. It is
      right for a clean line drawing, where the object is a solid dark shape on
      white.

    * `bg_flood` mode instead finds the *background* — the light region that
      the border can reach — and calls everything else the object. This is the
      one to use for a shaded illustration, where the vehicle's own interior
      carries dark panel shadows and bright highlights: those fragment a
      foreground threshold into pieces, and dropping all but the largest then
      punches holes through the middle of the plan. Defining the object as
      "what the outside light cannot reach" is immune to that, because a dark
      hatch or a bright deck plate in the middle of the hull is still walled
      off from the ground by the hull around it.
    """
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    border = np.concatenate([gray[0, :], gray[-1, :], gray[:, 0], gray[:, -1]])
    bg = int(np.median(border))

    if bg_flood:
        # The ground is the light pixels the border can walk to. Seed it by
        # padding a ring of background around the view, so a shape touching an
        # edge does not wall a corner of real ground off from the seed.
        near_bg = (np.abs(gray.astype(int) - bg) <= threshold).astype(np.uint8)
        pad = cv2.copyMakeBorder(near_bg, 1, 1, 1, 1,
                                 cv2.BORDER_CONSTANT, value=1)
        _, lab = cv2.connectedComponents(pad, 8)
        ground = (lab == lab[0, 0])[1:-1, 1:-1]
        m = (~ground).astype(np.uint8)
    else:
        m = (np.abs(gray.astype(int) - bg) > threshold).astype(np.uint8)
    m = cv2.morphologyEx(m, cv2.MORPH_OPEN, np.ones((open_px, open_px), np.uint8))
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8))

    n, lab, stats, _ = cv2.connectedComponentsWithStats(m, 8)
    if n <= 1:
        raise SystemExit("no object found in the view box")
    big = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    m = (lab == big).astype(np.uint8)

    # Fill enclosed holes, and only small ones. The image is padded first so
    # that a shape touching the edge of its box does not trap the background
    # against it: the empty space under a gun barrel is background, and
    # flood-filling it would give the tank a chin.
    pad = cv2.copyMakeBorder(m, 1, 1, 1, 1, cv2.BORDER_CONSTANT, value=0)
    nh, hl, hs, _ = cv2.connectedComponentsWithStats(1 - pad, 8)
    body = float(m.sum())
    outside = hl[0, 0]
    for i in range(1, nh):
        if i == outside:
            continue
        if hs[i, cv2.CC_STAT_AREA] < hole_frac * body:
            pad[hl == i] = 1
    m = pad[1:-1, 1:-1].astype(np.uint8)

    # Trim to the object. Each view's box was drawn by hand with slack.
    ys, xs = np.nonzero(m)
    return m[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def read_view(plate, box, mirror_x=False, **kw):
    x, y, w, h = box
    m = silhouette(plate[y:y + h, x:x + w], **kw)
    return m[:, ::-1].copy() if mirror_x else m


# --------------------------------------------------------------------------
# Visual hull
# --------------------------------------------------------------------------

def visual_hull(side, top, front, rec, height_cells, category="tracked"):
    """Intersect three orthographic silhouettes into a voxel solid.

    Axes are the project's world frame: +x along the wagon towards the front
    of the train, +y up, +z to the right.

      side  is (length, height)  — the view along z
      top   is (length, width)   — the view along y
      front is (width,  height)  — the view along x

    One scale, three views
    ----------------------
    Three views share three dimensions in a ring — side and top share the
    length, top and front share the width, side and front share the height —
    so any one of them can be made to follow from the others, and the leftover
    agreement is a check on whether the plate is drawn to one scale at all.

    The **width** is the anchor, taken from the record. It is the dimension
    the two views that measure it can measure honestly: a plan view across the
    vehicle and a front elevation across it are both bounded by the fenders,
    and neither can be inflated by something sticking up. Height cannot be the
    anchor for exactly that reason — a radio mast and a commander's sight
    stand above the recorded roof, by different amounts in different views,
    and anchoring on a silhouette's total height would shrink the whole
    vehicle by however tall the aerial happened to be drawn.

    So: the top view's scale comes from the width, the length follows from it,
    and the side view is read at whatever scale makes it that long. What is
    then left over is the height each of the two elevations implies, and those
    are reported. On a plate drawn to one scale they land within a few
    centimetres of the record, over the mast and the sight.

    The grid is **cubic** — one cell size on all three axes — so nothing is
    stretched to hit a number and the residual the Dart loader reports means
    something.

    A top view cannot see the running gear
    --------------------------------------
    Under the fenders the top view shows the fender line, not the track. Its
    outline curves in at the nose and the tail while the track runs straight
    to the sprocket and the idler, so intersecting with it planes the ends off
    the running gear and leaves the tank sitting in a boat. Below the road
    wheel's diameter the plan therefore comes from the *record* — the width
    over tracks — and the top view is not consulted. That band is bounded by
    the side view along the vehicle and by the front view across it, which are
    the two views that can actually see a track.
    """
    cell = rec["heightM"] / int(height_cells)   # metres per cell, all three axes
    width_m = rec["widthM"]

    ppm_top = top.shape[0] / width_m            # a plan view across = the width
    len_m = top.shape[1] / ppm_top              # and along = the length
    ppm_side = side.shape[1] / len_m            # the side view drawn to that length
    ppm_front = front.shape[1] / width_m        # a front elevation across = the width

    # What height each elevation then implies. Not used to scale anything —
    # reported, because this is the plate's own consistency showing.
    h_side_m = side.shape[0] / ppm_side
    h_front_m = front.shape[0] / ppm_front

    nx = max(4, int(round(len_m / cell)))
    nz = max(4, int(round(width_m / cell)))
    ny = max(4, int(round(max(h_side_m, h_front_m) / cell)))

    def fit(mask, w, h):
        r = cv2.resize(mask.astype(np.float32), (max(1, w), max(1, h)),
                       interpolation=cv2.INTER_AREA)
        return r >= 0.5

    def elevation(mask, w, implied_h):
        """A view carrying height: resampled, flipped, and stood on y = 0."""
        h = max(1, int(round(implied_h / cell)))
        r = fit(mask, w, h)[::-1, :]
        out = np.zeros((ny, w), bool)
        out[:min(h, ny), :] = r[:min(h, ny), :]
        return out

    # Rows of an image run downwards; +y runs up. Flip the two views that
    # carry height so index 0 is the running surface.
    s = elevation(side, nx, h_side_m)             # [y][x]
    t = fit(top, nx, nz)                          # [z][x]
    f = elevation(front, nz, h_front_m)           # [y][z]

    # [x][y][z]: side contributes (x, y), top (x, z), front (y, z).
    sx = s.T[:, :, None]
    tx = t.T[:, None, :]
    fx = f[None, :, :]
    solid = sx & tx & fx

    if category == "tracked":
        y_gear = int(round(2.0 * 0.78 * rec["groundClearanceM"] / cell))
        z_half = rec["widthOverTracksM"] / 2.0
        zc = (nz - 1) / 2.0
        over_tracks = (np.abs(np.arange(nz) - zc) * cell <= z_half)[None, None, :]

        # The side view's own track is no use as a bottom edge: the artist
        # draws the lower run as a chain, sagging between the road wheels and
        # sweeping up onto the idler and the sprocket, so the lowest row of
        # pixels is reached only across the middle third. Read literally it
        # gives a tank with a keel, which then rocks on a wagon deck instead
        # of standing on it — and load height, the whole reason this scene
        # exists, is measured from where it stands.
        #
        # So inside the running-gear band the side view is closed downwards:
        # wherever it has anything at all, the track is taken to reach the
        # ground. That is what a track does along its bearing length. The
        # front view still cuts the band across, which is what keeps the belly
        # clear at the recorded ground clearance.
        band = sx[:, :y_gear, :] | np.zeros((nx, y_gear, nz), bool)
        band = np.flip(np.maximum.accumulate(np.flip(band, axis=1), axis=1), axis=1)
        solid[:, :y_gear, :] = band & fx[:, :y_gear, :] & over_tracks

    report = {
        "cellM": cell,
        "lengthM": len_m,
        "heightFromSideM": h_side_m,
        "heightFromFrontM": h_front_m,
    }
    return np.ascontiguousarray(solid), (nx, ny, nz), report


# --------------------------------------------------------------------------
# Part labelling
# --------------------------------------------------------------------------

# The names the Dart loader's `materialFromName` recognises. Kept as literals
# so a rename there shows up here as a model that renders in the fallback
# colour rather than as a silent mismatch.
PART_HULL = "hull"
PART_BELLY = "hull_belly"
PART_TRACK = "track"
PART_TURRET = "turret"
PART_GUN = "gun_barrel"
PART_TYRE = "wheel_tyre"
PART_CAB = "cab_glazing"


def label_tracked(solid, dims, rec, cell):
    """Name the parts of a tracked vehicle from the record's own figures.

    Running gear: everything below twice the road wheel radius, which is what
    `VehicleMeshCatalog` already takes the wheel to be — 0.78 of the recorded
    ground clearance. Outboard of the width over tracks less one track shoe it
    is the track run; inboard it is the belly between the runs.

    Turret: everything above the roof line, which is found in the silhouette
    rather than assumed — the highest level at which the vehicle is still as
    long as a hull. Forward of the hull nose at that level is the gun.
    """
    nx, ny, nz = dims
    lab = np.full(solid.shape, PART_HULL, dtype=object)

    wheel_top = 2.0 * 0.78 * rec["groundClearanceM"]
    y_gear = int(round(wheel_top / cell))

    half = rec["widthOverTracksM"] / 2.0
    z_out = int(round((half - rec["trackShoeWidthM"]) / cell))
    zc = (nz - 1) / 2.0
    z_index = np.abs(np.arange(nz) - zc)

    gear = np.zeros(solid.shape, bool)
    gear[:, :y_gear, :] = True
    outboard = (z_index >= z_out)[None, None, :]
    lab[gear & outboard] = PART_TRACK
    lab[gear & ~outboard] = PART_BELLY

    # The roof line: scan down from the top for the first level whose length
    # reaches most of the vehicle's. Above it the plan view is a turret.
    length_at = np.array([solid[:, y, :].any(axis=1).sum() for y in range(ny)])
    full = length_at.max()
    roof = ny - 1
    for y in range(ny - 1, -1, -1):
        if length_at[y] >= 0.55 * full:
            roof = y
            break
    upper = np.zeros(solid.shape, bool)
    upper[:, roof:, :] = True
    lab[upper & (lab == PART_HULL)] = PART_TURRET

    # The gun is what reaches forward of the hull at turret level. The hull
    # nose is the furthest +x any cell below the roof line reaches.
    below = solid[:, :roof, :].any(axis=(1, 2))
    nose = int(np.nonzero(below)[0].max()) if below.any() else nx - 1
    forward = np.zeros(solid.shape, bool)
    forward[nose + 1:, :, :] = True
    lab[forward & (lab != PART_TRACK) & (lab != PART_BELLY)] = PART_GUN
    return lab


def label_wheeled(solid, dims, rec, cell):
    """Name the parts of a lorry.

    Only two boundaries are drawn, because only two are legible in a
    silhouette: the tyres below the wheel diameter, and the cab glazing, which
    is not in the silhouette at all and so is left alone. Everything else is
    body.
    """
    nx, ny, nz = dims
    lab = np.full(solid.shape, PART_HULL, dtype=object)
    wheel_top = 2.0 * rec.get("wheelRadiusM", 0.19 * rec["heightM"])
    y_gear = int(round(wheel_top / cell))
    zc = (nz - 1) / 2.0
    z_index = np.abs(np.arange(nz) - zc)
    z_out = int(round(0.55 * zc))
    gear = np.zeros(solid.shape, bool)
    gear[:, :y_gear, :] = True
    lab[gear & (z_index >= z_out)[None, None, :]] = PART_TYRE
    return lab


# --------------------------------------------------------------------------
# Greedy meshing
# --------------------------------------------------------------------------

# The six face directions, as (axis, positive?).
_DIRS = [(0, False), (0, True), (1, False), (1, True), (2, False), (2, True)]


def greedy_mesh(solid, labels):
    """Turn the voxel solid into quads, merging every coplanar run.

    A face-per-voxel mesh of a grid this size is a quarter of a million quads
    and would stop the software renderer dead. Greedy meshing walks each slab
    of exposed faces and grows the largest rectangle it can over cells that
    share a part name, which collapses a flat glacis plate into one quad and
    a track run into a handful. It is exact — the surface is unchanged — and
    it suits armour, which is flat plate to begin with.

    Returns (vertices, faces) where a face is (i, j, k, l, part).
    """
    nx, ny, nz = solid.shape
    verts = {}
    order = []

    def vid(p):
        i = verts.get(p)
        if i is None:
            i = len(order) + 1          # OBJ indices are 1-based
            verts[p] = i
            order.append(p)
        return i

    faces = []
    for axis, positive in _DIRS:
        u, v = [a for a in (0, 1, 2) if a != axis]
        n_slab = solid.shape[axis]
        nu, nv = solid.shape[u], solid.shape[v]
        for s in range(n_slab):
            here = np.take(solid, s, axis=axis)
            nxt = s + (1 if positive else -1)
            if 0 <= nxt < n_slab:
                exposed = here & ~np.take(solid, nxt, axis=axis)
            else:
                exposed = here.copy()
            if not exposed.any():
                continue
            part = np.take(labels, s, axis=axis)
            done = ~exposed
            for a in range(nu):
                b = 0
                while b < nv:
                    if done[a, b]:
                        b += 1
                        continue
                    name = part[a, b]
                    # Grow along v, then along u while the whole strip matches.
                    b2 = b
                    while b2 + 1 < nv and not done[a, b2 + 1] and part[a, b2 + 1] == name:
                        b2 += 1
                    a2 = a
                    while a2 + 1 < nu:
                        row = slice(b, b2 + 1)
                        if done[a2 + 1, row].any() or (part[a2 + 1, row] != name).any():
                            break
                        a2 += 1
                    done[a:a2 + 1, b:b2 + 1] = True

                    # The quad's four corners in grid coordinates.
                    w = s + (1 if positive else 0)
                    def corner(ui, vi):
                        p = [0, 0, 0]
                        p[axis] = w
                        p[u] = ui
                        p[v] = vi
                        return tuple(p)
                    c = [corner(a, b), corner(a2 + 1, b),
                         corner(a2 + 1, b2 + 1), corner(a, b2 + 1)]
                    if positive:
                        c.reverse()
                    faces.append((*[vid(p) for p in c], name))
                    b = b2 + 1
    return order, faces


# --------------------------------------------------------------------------
# Output
# --------------------------------------------------------------------------

def write_obj(path, verts, faces, dims, report, title, extra=()):
    """Write the mesh as OBJ, in metres, y up, facing +x.

    Written in the project's own frame (`yUpFacingPlusX`) so the loader has
    nothing to rotate.

    The scale is the grid's own cell, the same on all three axes. Nothing is
    stretched to hit a recorded figure: what the plate draws is what is
    written, and the Dart loader then fits it to the record's width and says
    how far the other two landed. Forcing each axis to its recorded number
    here would make that report say zero every time and mean nothing.
    """
    nx, ny, nz = dims
    cell = report["cellM"]
    cx, cz = nx / 2.0, nz / 2.0

    lines = [
        f"# {title}",
        "# Built by tools/build_model_from_plate.py from the orthographic",
        "# views on the source plate, by intersecting their silhouettes.",
        "# Metres; +x forward, +y up, +z right; origin on the running surface.",
        f"# {len(verts)} vertices, {len(faces)} faces, grid {nx}x{ny}x{nz}",
        f"# cell {cell * 100:.2f} cm; length {report['lengthM']:.2f} m from the top"
        f" view; height over everything reads {report['heightFromSideM']:.2f} m from"
        f" the side view and {report['heightFromFrontM']:.2f} m from the front view",
    ]
    lines.extend(f"# {line}" for line in extra)
    for (i, j, k) in verts:
        lines.append(
            f"v {(i - cx) * cell:.4f} {j * cell:.4f} {(k - cz) * cell:.4f}")
    group = None
    for a, b, c, d, name in faces:
        if name != group:
            lines.append(f"g {name}")
            lines.append(f"usemtl {name}")
            group = name
        lines.append(f"f {a} {b} {c} {d}")
    Path(path).write_text("\n".join(lines) + "\n")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--spec", required=True, help="the plate spec JSON")
    ap.add_argument("--out", help="output .obj (default: assets/models/<id>.obj)")
    ap.add_argument("--height-cells", type=int,
                    help="voxel rows over the vehicle's height (default: the spec's)")
    args = ap.parse_args(argv)

    spec = json.loads(Path(args.spec).read_text())
    root = Path(args.spec).resolve().parents[2]
    plate = cv2.imread(str(root / spec["plate"]))
    if plate is None:
        raise SystemExit(f"cannot read plate {spec['plate']}")

    rec = spec["record"]
    views = spec["views"]
    opts = spec.get("silhouette", {})
    side = read_view(plate, views["side"]["box"],
                     views["side"].get("mirrorX", False), **opts)
    top = read_view(plate, views["top"]["box"],
                    views["top"].get("mirrorX", False), **opts)
    front = read_view(plate, views["front"]["box"],
                      views["front"].get("mirrorX", False), **opts)

    cells = args.height_cells or spec.get("heightCells", 56)
    category = spec.get("category", "tracked")
    solid, dims, report = visual_hull(side, top, front, rec, cells, category)
    filled = int(solid.sum())
    if filled == 0:
        raise SystemExit("the three silhouettes do not intersect — check the boxes")

    cell = report["cellM"]
    labeller = label_wheeled if category == "wheeled" else label_tracked
    labels = labeller(solid, dims, rec, cell)
    verts, faces = greedy_mesh(solid, labels)

    # What the mesh actually came out as, against what the record says. This
    # is the number worth reading: the two views' lengths disagreeing by more
    # than a few centimetres means the plate is not drawn to one scale, and
    # then the overhang this model shows on a wagon is the artist's and not
    # the vehicle's.
    occupied = np.argwhere(solid)
    span = (occupied.max(0) - occupied.min(0) + 1) * cell
    checks = [
        ("length", span[0], rec["lengthM"]),
        ("height", span[1], rec["heightM"]),
        ("width", span[2], rec["widthM"]),
    ]

    out = Path(args.out) if args.out else root / "assets/models" / f"{spec['vehicleId']}.obj"
    write_obj(out, verts, faces, dims, report,
              spec.get("title", spec["vehicleId"]),
              extra=[f"{n}: {got:.2f} m built, {want:.2f} m recorded "
                     f"({got - want:+.2f} m)" for n, got, want in checks])

    counts = {}
    for f in faces:
        counts[f[4]] = counts.get(f[4], 0) + 1
    print(f"{spec['vehicleId']}: grid {dims[0]}x{dims[1]}x{dims[2]} "
          f"at {cell * 100:.2f} cm, {filled} solid cells, "
          f"{len(verts)} vertices, {len(faces)} quads")
    for name in sorted(counts):
        print(f"    {name:<12} {counts[name]:>6} quads")
    print(f"    length {report['lengthM']:.2f} m from the top view; height over "
          f"everything {report['heightFromSideM']:.2f} m from the side view, "
          f"{report['heightFromFrontM']:.2f} m from the front view")
    for n, got, want in checks:
        mark = " " if abs(got - want) <= 0.25 else " <-- off"
        print(f"    {n:<7} built {got:5.2f} m  recorded {want:5.2f} m  "
              f"{got - want:+.2f} m{mark}")
    print(f"    -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

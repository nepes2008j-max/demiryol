#!/usr/bin/env python3
"""Author a BTR-family 8x8 APC model parametrically, as a smooth-normalled OBJ.

Why this and not build_model_from_plate.py
------------------------------------------
The visual-hull tool needs a clean silhouette on a plain ground. The reference
art for the BTR set is a *shaded* three-quarter illustration, not a line plate:
the deck carries highlights as light as the paper and hatches as dark as
shadow, so neither a foreground threshold nor a background flood segments the
plan cleanly, and the hull it intersects comes out striped and holed. A wheeled
APC is also the one shape the hull method serves worst — the top view cannot
see the running gear, and a boat hull's whole character is in slopes a
silhouette flattens.

So this builds the shape directly from the proportions the reference shows and
the record's own length, width and height, the same division of labour the
Dart mesh builders keep: the three overall dimensions are the record's, every
other number here is a drawing proportion, named as one. The output is an
ordinary Wavefront file the existing loader reads, with per-vertex normals so
the cast hull shades as a curve rather than as facets, and group names the
loader already maps to materials (hull, turret, gun_barrel, wheel_tyre).

    tools/build_btr_model.py --variant btr80 --out assets/models/veh-btr80.obj
"""

import argparse
import math
from pathlib import Path

# --------------------------------------------------------------------------
# A tiny OBJ writer that keeps one normal per vertex, averaged over the faces
# that meet there, so shared edges come out smooth.
# --------------------------------------------------------------------------


class ObjBuilder:
    def __init__(self):
        self.groups = {}  # name -> (verts list[(x,y,z)], faces list[tuple idx])

    def _g(self, name):
        return self.groups.setdefault(name, ([], []))

    def add_face(self, name, pts):
        verts, faces = self._g(name)
        base = len(verts)
        verts.extend(pts)
        faces.append(tuple(range(base, base + len(pts))))

    def add_quad(self, name, a, b, c, d):
        self.add_face(name, [a, b, c, d])

    def write(self, path, title):
        lines = [f"# {title}",
                 "# Authored by tools/build_btr_model.py — a parametric solid.",
                 "# Metres; +x forward, +y up, +z right; origin on the ground."]
        vbase = 0
        vlines, nlines, flines = [], [], []
        for name, (verts, faces) in self.groups.items():
            # Per-vertex normals, averaged over adjacent faces.
            normals = [[0.0, 0.0, 0.0] for _ in verts]
            for f in faces:
                p0, p1, p2 = verts[f[0]], verts[f[1]], verts[f[2]]
                ux, uy, uz = (p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2])
                vx, vy, vz = (p2[0] - p0[0], p2[1] - p0[1], p2[2] - p0[2])
                nx, ny, nz = (uy * vz - uz * vy, uz * vx - ux * vz,
                              ux * vy - uy * vx)
                for i in f:
                    normals[i][0] += nx
                    normals[i][1] += ny
                    normals[i][2] += nz
            flines.append(f"g {name}")
            for (x, y, z) in verts:
                vlines.append(f"v {x:.4f} {y:.4f} {z:.4f}")
            for n in normals:
                ln = math.sqrt(n[0] ** 2 + n[1] ** 2 + n[2] ** 2) or 1.0
                nlines.append(f"vn {n[0] / ln:.4f} {n[1] / ln:.4f} {n[2] / ln:.4f}")
            for f in faces:
                idx = " ".join(f"{vbase + i + 1}//{vbase + i + 1}" for i in f)
                flines.append(f"f {idx}")
            vbase += len(verts)
        Path(path).write_text("\n".join(lines + vlines + nlines + flines) + "\n")
        nverts = sum(len(v) for v, _ in self.groups.values())
        nfaces = sum(len(f) for _, f in self.groups.values())
        return nverts, nfaces


# --------------------------------------------------------------------------
# Geometry helpers
# --------------------------------------------------------------------------


def loft(obj, name, stations, close_ends=True):
    """Skin a run of cross-sections. Each station is a list of the SAME number
    of (z, y) points, at an x; consecutive stations are joined ring by ring."""
    rings = [[(x, y, z) for (z, y) in sect] for (x, sect) in stations]
    m = len(rings[0])
    for r0, r1 in zip(rings, rings[1:]):
        for i in range(m):
            j = (i + 1) % m
            obj.add_quad(name, r0[i], r0[j], r1[j], r1[i])
    if close_ends:
        # Fan the two end rings so the hull is a closed solid.
        for ring, flip in ((rings[0], True), (rings[-1], False)):
            c = (sum(p[0] for p in ring) / m, sum(p[1] for p in ring) / m,
                 sum(p[2] for p in ring) / m)
            for i in range(m):
                j = (i + 1) % m
                tri = [c, ring[j], ring[i]] if flip else [c, ring[i], ring[j]]
                obj.add_face(name, tri)


def cylinder_z(obj, name, cx, cy, cz, radius, half_len, segments=20):
    """A wheel: a cylinder whose axis runs across the vehicle (z)."""
    ring0, ring1 = [], []
    for k in range(segments):
        a = 2 * math.pi * k / segments
        y = cy + radius * math.sin(a)
        x = cx + radius * math.cos(a)
        ring0.append((x, y, cz - half_len))
        ring1.append((x, y, cz + half_len))
    for k in range(segments):
        j = (k + 1) % segments
        obj.add_quad(name, ring0[k], ring0[j], ring1[j], ring1[k])
    c0 = (cx, cy, cz - half_len)
    c1 = (cx, cy, cz + half_len)
    for k in range(segments):
        j = (k + 1) % segments
        obj.add_face(name, [c0, ring0[j], ring0[k]])
        obj.add_face(name, [c1, ring1[k], ring1[j]])


def frustum_y(obj, name, cx, cz, base_y, top_y, base_r, top_r, sides=12):
    """The turret: a low tapered drum standing on the deck."""
    ring0, ring1 = [], []
    for k in range(sides):
        a = 2 * math.pi * k / sides
        ring0.append((cx + base_r * math.cos(a), base_y, cz + base_r * math.sin(a)))
        ring1.append((cx + top_r * math.cos(a), top_y, cz + top_r * math.sin(a)))
    # Wound so the outward face is the front one. Unlike cylinder_z (whose
    # rings run along the axis, giving an outward cross product), this drum's
    # rings run up the y axis while its tangent lies in x-z, so the naive
    # winding points inward and the renderer culls the near face — the turret
    # then shows as a dark cavity. Going base->top up each seam instead of
    # around each ring flips it outward.
    for k in range(sides):
        j = (k + 1) % sides
        obj.add_quad(name, ring0[k], ring1[k], ring1[j], ring0[j])
    ctop = (cx, top_y, cz)
    cbot = (cx, base_y, cz)
    for k in range(sides):
        j = (k + 1) % sides
        # Top cap faces up (+y), base cap faces down (-y). The base is hidden
        # on the deck; it is here only so the drum is a closed solid and the
        # outward-winding self-check can measure it.
        obj.add_face(name, [ctop, ring1[j], ring1[k]])
        obj.add_face(name, [cbot, ring0[k], ring0[j]])


def cross_section(sw, yb, yd, hb, hm, ht, hdeck, y1, y2):
    """Eight points around a boat-hull cross-section, right and left symmetric.
    Widths scale with sw (the station's width fraction)."""
    hb, hm, ht, hdeck = hb * sw, hm * sw, ht * sw, hdeck * sw
    return [
        (-hb, yb), (-hm, y1), (-ht, y2), (-hdeck, yd),
        (hdeck, yd), (ht, y2), (hm, y1), (hb, yb),
    ]


# --------------------------------------------------------------------------
# The vehicle
# --------------------------------------------------------------------------

VARIANTS = {
    # length, width, height, clearance, wheelR, tyreW, axle xs (fraction of halfL)
    "btr80": dict(L=7.65, W=2.90, H=2.41, clr=0.43, wr=0.57, tw=0.30,
                  axles=[0.67, 0.29, -0.28, -0.66], turret_r=0.80, turret_h=0.46,
                  gun_len=1.05),
    "btr70": dict(L=7.54, W=2.80, H=2.32, clr=0.48, wr=0.56, tw=0.28,
                  axles=[0.66, 0.30, -0.27, -0.64], turret_r=0.74, turret_h=0.40,
                  gun_len=1.05),
    "btr60": dict(L=7.56, W=2.83, H=2.31, clr=0.48, wr=0.55, tw=0.27,
                  axles=[0.66, 0.30, -0.27, -0.64], turret_r=0.70, turret_h=0.36,
                  gun_len=1.05),
    # A tracked main battle tank. L is the hull length; the gun reaches on to
    # gunTipX so the fitted length over the gun is the record's 9.65 m.
    "t80u": dict(kind="mbt", L=7.00, W=3.60, clr=0.45, Hhull=1.15, Hturret=2.20,
                 trackW=0.60, roadR=0.33, roadWheels=6, gunTipX=6.15),
}


def build_mbt(v):
    """A tracked main battle tank: hull with a sloped glacis, two track runs
    with road wheels, a tapered turret and a long gun trained forward."""
    L, W, clr = v["L"], v["W"], v["clr"]
    Hh, Ht = v["Hhull"], v["Hturret"]
    halfL, halfW = L / 2, W / 2
    obj = ObjBuilder()

    # ---- Hull: a lofted armoured box with the front lifted into a glacis ----
    hb, hm, ht = 0.80 * halfW, 0.82 * halfW, 0.74 * halfW
    yb, yd = clr, Hh
    y1 = clr + (yd - clr) * 0.35
    y2 = clr + (yd - clr) * 0.80
    stations_def = [
        (-halfL,        0.94, yb,        yd),
        (-halfL * 0.90, 1.00, yb,        yd),
        (halfL * 0.62,  1.00, yb,        yd),
        (halfL * 0.84,  0.98, yb + 0.16, yd),
        (halfL,         0.86, yb + 0.55, yd - 0.10),
    ]
    stations = [
        (x, cross_section(sw, yb2, yd2, hb, hm, ht, ht, y1, y2))
        for (x, sw, yb2, yd2) in stations_def
    ]
    loft(obj, "hull", stations)

    # ---- Running gear: visible road wheels with a track band around them ----
    # The old solid box hid the wheels; instead the wheels ARE the running
    # gear, with a thin ground-contact run and a return run for the band, and
    # the side skirt cut back to the top so the lower half of every wheel shows.
    trackW = v["trackW"]
    rr = v["roadR"]
    tz = halfW - trackW / 2
    for side in (1, -1):
        z0, z1 = side * (tz - trackW / 2), side * (tz + trackW / 2)
        n = v["roadWheels"]
        xs = [(-0.78 + 1.56 * k / (n - 1)) * halfL for k in range(n)]
        for x in xs:
            cylinder_z(obj, "wheel", x, rr, side * tz, rr, trackW / 2, 16)
        # Front idler and rear drive sprocket, a little larger and darker.
        cylinder_z(obj, "sprocket", halfL * 0.90, rr * 1.12, side * tz,
                   rr * 1.12, trackW / 2, 16)
        cylinder_z(obj, "sprocket", -halfL * 0.90, rr * 1.12, side * tz,
                   rr * 1.12, trackW / 2, 16)
        # The track band: a thin run on the ground and a thin return run over
        # the wheel tops, so the band reads without burying the wheels.
        box_solid(obj, "track", -halfL * 0.90, halfL * 0.90, 0.0, rr * 0.24,
                  z0, z1)
        box_solid(obj, "track", -halfL * 0.90, halfL * 0.90, rr * 1.78,
                  rr * 2.04, z0, z1)
        # The side skirt covers only the return run upward, leaving the wheels
        # visible below it.
        box_solid(obj, "skirt", -halfL * 0.88, halfL * 0.70,
                  rr * 2.04, rr * 2.04 + 0.34, z0, side * (tz + trackW / 2))

    # ---- Turret: a tapered slab with a bustle, sloping to the mantlet ----
    tb = Hh
    tt = Ht
    thw = 0.72 * halfW
    tstations = [
        (-halfL * 0.42, [(-thw * 0.82, tb), (-thw * 0.86, tb + (tt - tb) * 0.5),
                         (-thw * 0.70, tt), (thw * 0.70, tt),
                         (thw * 0.86, tb + (tt - tb) * 0.5), (thw * 0.82, tb)]),
        (halfL * 0.02, [(-thw, tb), (-thw, tb + (tt - tb) * 0.5),
                        (-thw * 0.78, tt), (thw * 0.78, tt),
                        (thw, tb + (tt - tb) * 0.5), (thw, tb)]),
        (halfL * 0.20, [(-thw * 0.62, tb), (-thw * 0.66, tb + (tt - tb) * 0.45),
                        (-thw * 0.5, tt - 0.12), (thw * 0.5, tt - 0.12),
                        (thw * 0.66, tb + (tt - tb) * 0.45), (thw * 0.62, tb)]),
        (halfL * 0.30, [(-thw * 0.34, tb + 0.05), (-thw * 0.36, tb + (tt - tb) * 0.4),
                        (-thw * 0.28, tt - 0.30), (thw * 0.28, tt - 0.30),
                        (thw * 0.36, tb + (tt - tb) * 0.4), (thw * 0.34, tb + 0.05)]),
    ]
    loft(obj, "turret", tstations)

    # ---- Gun: a long barrel forward from the mantlet, with the record's
    # overhang, so the fitted length over the gun is the tank's own ----
    gun_root = (halfL * 0.30, tb + (tt - tb) * 0.45, 0.0)
    gun_tip = (v["gunTipX"], gun_root[1] + 0.02, 0.0)
    rod(obj, "gun_barrel", gun_root, (gun_tip[0] * 0.62, gun_tip[1], 0.0),
        0.115, segments=10)
    rod(obj, "gun_barrel", (gun_tip[0] * 0.58, gun_tip[1], 0.0), gun_tip,
        0.085, segments=10)
    return obj


def build(variant):
    v = VARIANTS[variant]
    if v.get("kind") == "mbt":
        return build_mbt(v)
    L, W, H, clr = v["L"], v["W"], v["H"], v["clr"]
    wr, tw = v["wr"], v["tw"]
    halfL, halfW = L / 2, W / 2
    obj = ObjBuilder()

    # Hull cross-section widths, as fractions of the half-width.
    hb, hm, ht, hdeck = 0.72 * halfW, 1.00 * halfW, 0.86 * halfW, 0.66 * halfW
    yb0 = clr
    yd0 = H * 0.77          # deck top (turret and hatches sit above this)
    y1 = clr + (yd0 - clr) * 0.28   # lower chine
    y2 = clr + (yd0 - clr) * 0.72   # upper chine

    # Stations from tail (-halfL) to the pointed bow (+halfL). sw narrows the
    # section; yb rises toward the bow so the glacis lifts clear of the ground.
    stations_def = [
        (-halfL,        0.50, yb0 + 0.18, yd0 - 0.30),
        (-halfL * 0.90, 0.86, yb0 + 0.04, yd0 - 0.06),
        (-halfL * 0.62, 0.99, yb0,        yd0),
        (halfL * 0.55,  1.00, yb0,        yd0),
        (halfL * 0.72,  0.98, yb0 + 0.06, yd0 - 0.02),
        (halfL * 0.86,  0.86, yb0 + 0.42, yd0 - 0.08),
        (halfL * 0.96,  0.66, yb0 + 0.92, yd0 - 0.20),
        (halfL,         0.42, yb0 + 1.34, yd0 - 0.34),
    ]
    stations = [
        (x, cross_section(sw, yb, yd, hb, hm, ht, hdeck, y1, y2))
        for (x, sw, yb, yd) in stations_def
    ]
    loft(obj, "hull", stations)

    # A raised superstructure box on the deck, the crew compartment roof, so
    # the deck is not a bare slab. Kept inside the deck edges.
    ss_hw = hdeck * 0.86
    ss_y0, ss_y1 = yd0 - 0.02, yd0 + 0.16
    ss_x0, ss_x1 = -halfL * 0.34, halfL * 0.44
    box_solid(obj, "hull", ss_x0, ss_x1, ss_y0, ss_y1, -ss_hw, ss_hw)

    # Turret: a low drum a little forward of centre, with a machine-gun barrel.
    tr = v["turret_r"]
    tcx = halfL * 0.10
    tbase = ss_y1
    ttop = tbase + v["turret_h"]
    frustum_y(obj, "turret", tcx, 0.0, tbase, ttop, tr, tr * 0.80, sides=16)
    # Machine gun, trained forward and a touch up.
    gl = v["gun_len"]
    gun_from = (tcx + tr * 0.7, tbase + v["turret_h"] * 0.45, 0.0)
    gun_to = (gun_from[0] + gl, gun_from[1] + 0.10, 0.0)
    rod(obj, "gun_barrel", gun_from, gun_to, 0.055, segments=8)

    # Eight wheels, in two rows of four, with a darker hub.
    wheelZ = halfW - tw * 0.55
    axle_xs = [f * halfL for f in v["axles"]]
    for x in axle_xs:
        for side in (1, -1):
            cylinder_z(obj, "wheel_tyre", x, wr, side * wheelZ, wr, tw / 2, 20)
            cylinder_z(obj, "wheel_tyre", x, wr, side * (wheelZ - tw * 0.10),
                       wr * 0.42, tw / 2 * 1.05, 12)

    # A slim mudguard running the length of each wheel row, at the top of the
    # tyres and held inside the recorded width — a fender line, not a shelf.
    fx0, fx1 = min(axle_xs) - wr * 0.9, max(axle_xs) + wr * 0.9
    for side in (1, -1):
        box_solid(obj, "fender", fx0, fx1, wr * 1.18, wr * 1.30,
                  side * (wheelZ - tw * 0.6), side * (halfW - 0.01))

    return obj


def box_solid(obj, name, x0, x1, y0, y1, z0, z1):
    lo = (min(x0, x1), min(y0, y1), min(z0, z1))
    hi = (max(x0, x1), max(y0, y1), max(z0, z1))
    p = [
        (lo[0], lo[1], lo[2]), (hi[0], lo[1], lo[2]),
        (hi[0], hi[1], lo[2]), (lo[0], hi[1], lo[2]),
        (lo[0], lo[1], hi[2]), (hi[0], lo[1], hi[2]),
        (hi[0], hi[1], hi[2]), (lo[0], hi[1], hi[2]),
    ]
    for a, b, c, d in [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4),
                       (2, 3, 7, 6), (1, 2, 6, 5), (0, 4, 7, 3)]:
        obj.add_quad(name, p[a], p[b], p[c], p[d])


def rod(obj, name, a, b, radius, segments=8):
    ax, ay, az = a
    bx, by, bz = b
    dx, dy, dz = bx - ax, by - ay, bz - az
    length = math.sqrt(dx * dx + dy * dy + dz * dz) or 1.0
    ux, uy, uz = dx / length, dy / length, dz / length
    # An arbitrary perpendicular basis.
    if abs(ux) < 0.9:
        px, py, pz = 1.0, 0.0, 0.0
    else:
        px, py, pz = 0.0, 1.0, 0.0
    qx = uy * pz - uz * py
    qy = uz * px - ux * pz
    qz = ux * py - uy * px
    ql = math.sqrt(qx * qx + qy * qy + qz * qz) or 1.0
    qx, qy, qz = qx / ql, qy / ql, qz / ql
    rx = uy * qz - uz * qy
    ry = uz * qx - ux * qz
    rz = ux * qy - uy * qx
    ring_a, ring_b = [], []
    for k in range(segments):
        ang = 2 * math.pi * k / segments
        ox = radius * (math.cos(ang) * qx + math.sin(ang) * rx)
        oy = radius * (math.cos(ang) * qy + math.sin(ang) * ry)
        oz = radius * (math.cos(ang) * qz + math.sin(ang) * rz)
        ring_a.append((ax + ox, ay + oy, az + oz))
        ring_b.append((bx + ox, by + oy, bz + oz))
    for k in range(segments):
        j = (k + 1) % segments
        obj.add_quad(name, ring_a[k], ring_a[j], ring_b[j], ring_b[k])
    cb = (bx, by, bz)
    ca = (ax, ay, az)
    for k in range(segments):
        j = (k + 1) % segments
        obj.add_face(name, [cb, ring_b[k], ring_b[j]])
        # The near cap, wound the other way, so the barrel is a closed solid.
        obj.add_face(name, [ca, ring_a[j], ring_a[k]])


def verify_outward(obj):
    """Assert every part is wound so its faces point outward, the way the
    scene renderer needs — it back-face-culls, so an inward part vanishes
    into a dark cavity (which is exactly how the turret bug looked before the
    winding was fixed). Each part is a closed solid, so its signed volume,
    summed over the faces by the divergence theorem, is positive when the
    faces face out and negative when they face in. This is shape-independent:
    it does not care whether the part is a box, a cone or a boat hull, only
    which way its skin faces. Raises on the first part that fails.

    A part may be several disjoint solids in one group (the eight wheels, say);
    because every instance a helper emits is wound the same way, a helper that
    winds inward flips the whole group's volume negative, so this still catches
    the realistic failure — a primitive helper with reversed winding."""
    def signed_volume(faces_verts):
        total = 0.0
        for poly in faces_verts:
            p0 = poly[0]
            for i in range(1, len(poly) - 1):
                p1, p2 = poly[i], poly[i + 1]
                total += (
                    p0[0] * (p1[1] * p2[2] - p1[2] * p2[1])
                    + p0[1] * (p1[2] * p2[0] - p1[0] * p2[2])
                    + p0[2] * (p1[0] * p2[1] - p1[1] * p2[0])
                ) / 6.0
        return total

    for name, (verts, faces) in obj.groups.items():
        vol = signed_volume([[verts[i] for i in f] for f in faces])
        if vol <= 1e-9:
            raise SystemExit(
                f"part '{name}' is wound inward (signed volume {vol:.4f} <= 0): "
                f"its faces would be culled and it would render as a cavity. "
                f"Reverse the winding of the helper that builds it.")


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--variant", required=True, choices=sorted(VARIANTS))
    ap.add_argument("--out", required=True)
    args = ap.parse_args(argv)
    obj = build(args.variant)
    verify_outward(obj)
    nv, nf = obj.write(args.out, f"{args.variant.upper()} — parametric 8x8 APC")
    print(f"{args.variant}: {nv} vertices, {nf} faces -> {args.out}  (winding OK)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

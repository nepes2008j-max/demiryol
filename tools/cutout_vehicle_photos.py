#!/usr/bin/env python3
"""Cut the vehicle out of each illustrative photograph, keeping only the machine.

The placement screen seats the vehicle on a photograph of a flatcar, the way
`Berl/harby_yukleme_simulyator.html` does. A rectangular photograph cannot be
used for that — the sky, the museum floor and the fence behind the vehicle
would sit on the wagon deck too — so each photograph is reduced to the machine
on a transparent background.

The separation is done with OpenCV's GrabCut, which is a classical
foreground/background segmentation seeded with a rectangle: no model weights,
no network, and it runs in a couple of seconds per photograph. It is not
reliable enough to trust blindly, which is why:

  * every result is written next to a contact sheet for review by eye, and
  * a vehicle whose cut-out does not come out clean is simply left out.

A missing cut-out is a normal state, not a failure: the app falls back to the
drawn side elevation for that vehicle, so a ragged cut-out never has to be
shipped just to fill the slot.

Usage:
    python3 tools/cutout_vehicle_photos.py                # all vehicles
    python3 tools/cutout_vehicle_photos.py veh-t34 veh-t55
    python3 tools/cutout_vehicle_photos.py --sheet-only   # rebuild the sheet
"""

import argparse
import json
import os
import sys

import cv2
import numpy as np

SRC_DIR = "assets/images/vehicles"
OUT_DIR = "assets/images/vehicles/cutouts"
MANIFEST = "assets/data/vehicle_photos.json"
SHEET = "docs/vehicle-cutout-contact-sheet.png"

# Fraction of the frame to inset the GrabCut seed rectangle on each side.
# The default assumes the machine roughly fills the frame; a photograph where
# it does not gets its own entry, measured off the picture rather than guessed.
# (left, top, right, bottom)
DEFAULT_RECT = (0.03, 0.03, 0.03, 0.03)
RECTS = {
    # The tank stands in the left two-thirds; the right third is a second
    # vehicle in the same hall, which must not be dragged into the mask.
    "veh-is4": (0.02, 0.05, 0.33, 0.02),
    "veh-t10": (0.01, 0.10, 0.22, 0.02),
    # A wide yard shot: the subject occupies the middle, with a truck at the
    # far left and another vehicle entering at the right edge.
    "veh-btr50p": (0.30, 0.25, 0.05, 0.10),
    # Sky above and a wide apron below; tightening the top and bottom keeps
    # GrabCut from taking the gravel as foreground.
    "veh-pt76": (0.04, 0.12, 0.04, 0.12),
    "veh-2s5": (0.02, 0.06, 0.02, 0.18),
    "veh-pts2": (0.02, 0.15, 0.02, 0.15),
}

# Regions of a specific photograph that are certainly background, as
# (x0, y0, x1, y1) fractions of the frame. GrabCut's colour model cannot know
# that the tan panel behind the 2S1 is a museum wall and not part of the
# vehicle's camouflage, or that the second tank parked beside the T-54 is not
# part of it. Each rectangle below was read off the photograph by eye — they
# are the digital equivalent of striking out the background with a marker
# before running the separation, which is exactly how GrabCut is meant to be
# driven.
BG_RECTS = {
    "veh-t34": [(0.00, 0.00, 0.13, 1.00), (0.93, 0.00, 1.00, 1.00)],
    "veh-is4": [(0.00, 0.00, 0.18, 0.60), (0.74, 0.00, 1.00, 0.62),
                (0.00, 0.00, 1.00, 0.10), (0.00, 0.86, 1.00, 1.00)],
    "veh-t10": [(0.00, 0.00, 0.55, 0.26), (0.60, 0.00, 1.00, 1.00),
                (0.00, 0.90, 1.00, 1.00), (0.00, 0.00, 0.06, 1.00)],
    "veh-t54": [(0.78, 0.00, 1.00, 1.00), (0.00, 0.00, 1.00, 0.10),
                (0.00, 0.92, 1.00, 1.00)],
    "veh-t55": [(0.00, 0.00, 1.00, 0.28), (0.00, 0.80, 1.00, 1.00),
                (0.84, 0.00, 1.00, 1.00), (0.00, 0.00, 0.12, 1.00)],
    "veh-pt76": [(0.00, 0.00, 1.00, 0.26), (0.00, 0.80, 1.00, 1.00),
                 (0.00, 0.00, 0.06, 1.00), (0.96, 0.00, 1.00, 1.00)],
    "veh-btr50p": [(0.00, 0.00, 0.42, 0.55), (0.00, 0.00, 0.30, 1.00),
                   (0.90, 0.00, 1.00, 1.00), (0.00, 0.00, 1.00, 0.22),
                   (0.00, 0.80, 1.00, 1.00)],
    "veh-2s1": [(0.00, 0.00, 0.24, 0.58), (0.00, 0.00, 1.00, 0.16),
                (0.00, 0.93, 1.00, 1.00)],
    "veh-2s3": [(0.00, 0.00, 1.00, 0.12), (0.00, 0.92, 1.00, 1.00)],
    "veh-2s4": [(0.00, 0.00, 1.00, 0.30), (0.82, 0.00, 1.00, 1.00),
                (0.00, 0.84, 1.00, 1.00)],
    "veh-2s5": [(0.00, 0.00, 1.00, 0.28), (0.00, 0.88, 1.00, 1.00),
                (0.88, 0.00, 1.00, 1.00)],
    "veh-2s7": [(0.00, 0.00, 1.00, 0.10), (0.00, 0.92, 1.00, 1.00)],
    "veh-pts2": [(0.00, 0.00, 1.00, 0.24), (0.00, 0.88, 1.00, 1.00),
                 (0.00, 0.00, 0.06, 1.00)],
    "veh-ptsm": [(0.00, 0.00, 1.00, 0.33), (0.45, 0.00, 1.00, 0.42),
                 (0.00, 0.78, 1.00, 1.00)],
    # Street and yard photographs: the buildings, trees and road surface are
    # struck out so GrabCut does not take them for part of the lorry.
    "veh-zil131": [(0.00, 0.00, 1.00, 0.22), (0.00, 0.86, 1.00, 1.00),
                   (0.00, 0.00, 0.14, 1.00), (0.70, 0.00, 1.00, 0.58)],
    "veh-kamaz43114": [(0.00, 0.00, 1.00, 0.18), (0.00, 0.90, 1.00, 1.00),
                       (0.00, 0.00, 0.02, 1.00), (0.52, 0.00, 1.00, 0.36)],
    "veh-ural4320": [(0.00, 0.00, 1.00, 0.16), (0.00, 0.92, 1.00, 1.00),
                     (0.00, 0.00, 0.10, 0.60), (0.95, 0.00, 1.00, 1.00)],
}

# The result of reviewing the contact sheet by eye. Only these cut-outs are
# kept and offered to the app; everything else is deleted after the run.
#
# The seven below show the machine and nothing else. The seven left out do not,
# and no amount of rectangle-tuning fixed them: the IS-4 and T-10 stand in a
# hall whose windows show through the gun barrels, the PT-76's wall is the same
# sand colour as its camouflage, the 2S1 is parked against a beige exhibit
# panel that GrabCut cannot tell from its own paint, the PTS-M is inside its own
# dust cloud, and the T-55 and 2S4 keep a fragment of the building behind them.
# Shipping a tank with a window sticking out of its turret would look worse on
# the wagon than not using a photograph at all — those vehicles fall back to the
# drawn side elevation instead.
APPROVED = {
    "veh-t34",
    "veh-t54",
    "veh-btr50p",
    "veh-2s3",
    "veh-2s5",
    "veh-2s7",
    "veh-pts2",
    "veh-zil131",
    "veh-ural4320",
    # KamAZ-43114 is deliberately absent: its cut-out keeps a strip of the blue
    # fence standing behind the cargo bed, and a fence riding on the wagon deck
    # is worse than no photograph there.
    #
    # The two modern tanks are absent for the same reason, and they were looked
    # at before being left out. The T-72 stands under a birch and a pylon, and
    # GrabCut keeps the trunk growing out of its turret along with a strip of
    # sky and the bin beside its track. The T-90S is photographed against a
    # treeline and a hangar, and the cut-out keeps essentially all of it —
    # sky, buildings, the field and the striped barrier — trimming only the
    # corners. Both photographs are good on the vehicle card, which is what
    # they are there for; neither can be put on a wagon deck, so those two
    # fall back to the drawn side elevation like the other eight.
}

ITERATIONS = 6
# A cut-out narrower or shorter than this fraction of the source frame means
# GrabCut collapsed onto a detail instead of the vehicle; such a result is
# reported rather than written.
MIN_EXTENT = 0.25


def load_manifest_ids():
    if not os.path.exists(MANIFEST):
        return []
    with open(MANIFEST, encoding="utf-8") as f:
        return [p["vehicleId"] for p in json.load(f).get("photos", [])]


def source_path(vehicle_id):
    for ext in (".jpg", ".jpeg", ".png"):
        p = os.path.join(SRC_DIR, vehicle_id + ext)
        if os.path.exists(p):
            return p
    return None


BORDER = 0.03  # fraction of the frame taken as certain background


def cut_out(path, rect_insets, bg_rects=()):
    """Return an RGBA image of the largest foreground blob, or None.

    Two passes, because one is not enough on these photographs:

    1. **Seeded from the frame border, not just a rectangle.** A plain
       rectangle init makes GrabCut learn its background model from whatever
       lies outside the rectangle, which on a museum photograph is a sliver of
       the same wall that fills the middle of the frame — so the wall came out
       as part of the tank. Marking the outer border as *certain* background
       first teaches the model the sky, the hall wall and the floor explicitly,
       and those colours are then rejected wherever else they appear.

    2. **Refined from its own result.** The first pass's blob, eroded, is
       re-declared certain foreground and everything well outside it certain
       background, so the second pass only has to decide the contested band
       along the vehicle's edge.
    """
    bgr = cv2.imread(path, cv2.IMREAD_COLOR)
    if bgr is None:
        return None, "unreadable"
    h, w = bgr.shape[:2]
    left, top, right, bottom = rect_insets
    x0, y0 = int(w * left), int(h * top)
    x1, y1 = int(w * (1 - right)), int(h * (1 - bottom))

    bx, by = max(2, int(w * BORDER)), max(2, int(h * BORDER))
    mask = np.full((h, w), cv2.GC_PR_BGD, np.uint8)
    mask[y0:y1, x0:x1] = cv2.GC_PR_FGD
    mask[:by, :] = cv2.GC_BGD
    mask[-by:, :] = cv2.GC_BGD
    mask[:, :bx] = cv2.GC_BGD
    mask[:, -bx:] = cv2.GC_BGD
    for rx0, ry0, rx1, ry1 in bg_rects:
        mask[int(h * ry0):int(h * ry1), int(w * rx0):int(w * rx1)] = cv2.GC_BGD

    bgd, fgd = np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64)
    cv2.grabCut(bgr, mask, None, bgd, fgd, ITERATIONS, cv2.GC_INIT_WITH_MASK)
    first = np.where((mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD), 255, 0).astype("uint8")

    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))
    sure_fg = cv2.erode(first, kernel, iterations=3)
    sure_bg = cv2.dilate(first, kernel, iterations=4)
    refined = np.full((h, w), cv2.GC_PR_BGD, np.uint8)
    refined[sure_bg > 0] = cv2.GC_PR_FGD
    refined[sure_fg > 0] = cv2.GC_FGD
    refined[sure_bg == 0] = cv2.GC_BGD
    if (refined == cv2.GC_FGD).any() and (refined == cv2.GC_BGD).any():
        bgd, fgd = np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64)
        cv2.grabCut(bgr, refined, None, bgd, fgd, 3, cv2.GC_INIT_WITH_MASK)
        fg = np.where((refined == cv2.GC_FGD) | (refined == cv2.GC_PR_FGD), 255, 0).astype("uint8")
    else:
        fg = first

    # GrabCut often leaves specks of "foreground" in the background and holes
    # inside the hull. Closing fills the holes, then only the largest connected
    # component is kept: the vehicle is one object, never a constellation.
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))
    fg = cv2.morphologyEx(fg, cv2.MORPH_CLOSE, kernel, iterations=2)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(fg, connectivity=8)
    if count <= 1:
        return None, "nothing separated"
    biggest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    fg = np.where(labels == biggest, 255, 0).astype("uint8")

    x, y, bw, bh = cv2.boundingRect(fg)
    if bw < w * MIN_EXTENT or bh < h * MIN_EXTENT:
        return None, "collapsed to %dx%d of %dx%d" % (bw, bh, w, h)

    # A one-pixel feathering of the alpha edge; a hard mask edge reads as a
    # sticker pasted on the wagon rather than a vehicle standing on it.
    alpha = cv2.GaussianBlur(fg, (3, 3), 0)
    rgba = cv2.cvtColor(bgr, cv2.COLOR_BGR2BGRA)
    rgba[:, :, 3] = alpha
    return rgba[y:y + bh, x:x + bw], None


def checkerboard(h, w, size=16):
    """Grey checkerboard, so a transparent edge is visible on the sheet."""
    board = np.zeros((h, w, 3), np.uint8)
    board[:] = 90
    ys, xs = np.mgrid[0:h, 0:w]
    board[((ys // size) + (xs // size)) % 2 == 0] = 130
    return board


def compose_sheet(entries, columns=3, cell=(520, 300)):
    """One image showing every cut-out over a checkerboard, with its id."""
    cw, ch = cell
    rows = (len(entries) + columns - 1) // columns
    sheet = np.zeros((rows * ch, columns * cw, 3), np.uint8)
    sheet[:] = 40
    for i, (vehicle_id, rgba) in enumerate(entries):
        r, c = divmod(i, columns)
        scale = min((cw - 20) / rgba.shape[1], (ch - 40) / rgba.shape[0])
        small = cv2.resize(rgba, (max(1, int(rgba.shape[1] * scale)),
                                  max(1, int(rgba.shape[0] * scale))))
        bh, bw = small.shape[:2]
        back = checkerboard(bh, bw)
        a = small[:, :, 3:4].astype(np.float32) / 255.0
        blended = (small[:, :, :3].astype(np.float32) * a + back.astype(np.float32) * (1 - a))
        y0, x0 = r * ch + 30, c * cw + 10
        sheet[y0:y0 + bh, x0:x0 + bw] = blended.astype(np.uint8)
        cv2.putText(sheet, vehicle_id, (c * cw + 10, r * ch + 22),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (230, 230, 230), 1, cv2.LINE_AA)
    return sheet


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("vehicles", nargs="*")
    ap.add_argument("--sheet-only", action="store_true")
    args = ap.parse_args()

    ids = args.vehicles or load_manifest_ids()
    if not ids:
        print("no vehicles to process", file=sys.stderr)
        return 1
    os.makedirs(OUT_DIR, exist_ok=True)

    entries = []
    for vehicle_id in ids:
        dest = os.path.join(OUT_DIR, vehicle_id + ".png")
        if args.sheet_only:
            existing = cv2.imread(dest, cv2.IMREAD_UNCHANGED)
            if existing is not None:
                entries.append((vehicle_id, existing))
            continue
        src = source_path(vehicle_id)
        if src is None:
            print("  %-12s no source photograph" % vehicle_id)
            continue
        rgba, problem = cut_out(src, RECTS.get(vehicle_id, DEFAULT_RECT),
                                BG_RECTS.get(vehicle_id, ()))
        if rgba is None:
            print("  %-12s SKIPPED — %s" % (vehicle_id, problem))
            continue
        cv2.imwrite(dest, rgba)
        print("  %-12s %dx%d -> %s" % (vehicle_id, rgba.shape[1], rgba.shape[0], dest))
        entries.append((vehicle_id, rgba))

    if entries:
        os.makedirs(os.path.dirname(SHEET), exist_ok=True)
        cv2.imwrite(SHEET, compose_sheet(entries))
        print("\ncontact sheet -> %s (review every cut-out before shipping it)" % SHEET)

    if not args.sheet_only:
        prune_unapproved()
        update_manifest()
    return 0


def prune_unapproved():
    """Delete every cut-out that review did not accept.

    They are written in the first place so they appear on the contact sheet
    and can be judged; leaving one on disk afterwards would let it be picked
    up as if it had passed.
    """
    for name in sorted(os.listdir(OUT_DIR)):
        vehicle_id = os.path.splitext(name)[0]
        if vehicle_id not in APPROVED:
            os.remove(os.path.join(OUT_DIR, name))
            print("  %-12s not approved — removed" % vehicle_id)


def update_manifest():
    """Record the approved cut-out path on each photograph's manifest entry.

    The app cannot ask whether an asset exists without trying to load it, so
    the manifest is what tells it which vehicles can be shown standing on the
    flatcar photograph and which fall back to the drawn elevation.
    """
    if not os.path.exists(MANIFEST):
        return
    with open(MANIFEST, encoding="utf-8") as f:
        manifest = json.load(f)
    kept = 0
    for entry in manifest.get("photos", []):
        path = os.path.join(OUT_DIR, entry["vehicleId"] + ".png")
        if os.path.exists(path):
            entry["cutout"] = "images/vehicles/cutouts/" + entry["vehicleId"] + ".png"
            kept += 1
        else:
            entry.pop("cutout", None)
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("\n%d approved cut-outs recorded in %s" % (kept, MANIFEST))


if __name__ == "__main__":
    sys.exit(main())

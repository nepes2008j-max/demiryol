#!/usr/bin/env python3
"""Convert the Berl handbook wall-charts into assets the Flutter app can load.

The six large plates are CMYK JPEGs at roughly 10000x7200 and 40-60 MB each.
Flutter's image codec cannot decode CMYK JPEG at all, and one plate would need
around 300 MB of RAM to hold decoded, so they cannot be referenced as they are.

`Image.draft()` lets libjpeg downscale while decoding, so a plate never has to
exist at full size in memory. Run from the project root:

    python3 tools/convert_berl_plates.py
"""

import io
import os
import sys
from PIL import Image

Image.MAX_IMAGE_PIXELS = None

SRC = "/home/nepes/Desktop/demiryol/Berl"
PLATES_OUT = "assets/images/plates"
FIGURES_OUT = "assets/images/figures"

FULL_EDGE = 2400
QUALITY = 82

# Source filename -> published asset stem. The numbering follows the plates'
# own titles, which the handbook cites in that order.
PLATES = [
    ("1. Zynjyrly tehnikalar.jpg", "plate-01-tracked-wood-chocks-clamps"),
    ("2. Zynjyrly tehnikalar.jpg", "plate-02-tracked"),
    ("3. Zynjyrly tehnikalar.jpg", "plate-03-tracked"),
    ("4. Zynjyrly tehnika.jpg", "plate-04-tracked"),
    ("5 Tigirli harby maşynlar.jpg", "plate-05-wheeled-chocks-wire-lashings"),
    ("6 Tigirli harby maşynlar.jpg", "plate-06-wheeled"),
    ("8  Howpsyzlyk çäre (2).jpg", "plate-08a-safety-measures"),
    ("8  Howpsyzlyk çäre дорт.jpg", "plate-08b-safety-measures"),
    ("9 Harby eşelony guramak.jpg", "plate-09-echelon-organisation"),
]


def load_downscaled(path, target_edge):
    """Open a plate at no more than `target_edge` on its long side.

    draft() is a hint honoured only by the JPEG decoder and only in powers of
    two, so the result is >= the target; thumbnail() then lands it exactly.
    convert('RGB') is what actually resolves the CMYK problem.
    """
    im = Image.open(path)
    im.draft("RGB", (target_edge, target_edge))
    im = im.convert("RGB")
    im.thumbnail((target_edge, target_edge), Image.LANCZOS)
    return im


def convert_plates():
    os.makedirs(PLATES_OUT, exist_ok=True)
    written = []
    for filename, stem in PLATES:
        src = os.path.join(SRC, filename)
        if not os.path.exists(src):
            print("  MISSING %s" % filename, file=sys.stderr)
            continue
        im = load_downscaled(src, FULL_EDGE)
        dst = os.path.join(PLATES_OUT, stem + ".jpg")
        im.save(dst, "JPEG", quality=QUALITY, optimize=True, progressive=True)
        written.append((stem, im.size, os.path.getsize(dst)))
        print("  %-46s %sx%s  %4d KB" % (stem, im.size[0], im.size[1], os.path.getsize(dst) // 1024))
    return written


# Artwork lifted from the customer's own brief (HGM.pptx), so the screens use
# the imagery the brief itself illustrates them with. Slide 2 shows a ship's
# wheel ringed with wagons: turning it is how the brief asks the wagon count to
# be chosen ("tegelek bilen içindäki otly bileleikde aýlanyp başlamaly ... her
# gezek aýlananda wagon sany köpelmeli").
PPTX = "/home/nepes/Desktop/demiryol/Berl/HGM.pptx"
UI_OUT = "assets/images/ui"
BRIEF_ART = [("ppt/media/image4.png", "wagon-counter-wheel.png", 900)]


def convert_brief_art():
    import zipfile

    if not os.path.exists(PPTX):
        print("  MISSING %s" % PPTX, file=sys.stderr)
        return []
    os.makedirs(UI_OUT, exist_ok=True)
    written = []
    with zipfile.ZipFile(PPTX) as z:
        names = set(z.namelist())
        for member, out_name, edge in BRIEF_ART:
            if member not in names:
                print("  MISSING %s in pptx" % member, file=sys.stderr)
                continue
            with z.open(member) as fh:
                im = Image.open(io.BytesIO(fh.read()))
                # Keep the alpha channel: the wheel is cut out against the
                # slide, and flattening it would paste a white square onto the
                # screen's dark theme.
                im = im.convert("RGBA")
                im.thumbnail((edge, edge), Image.LANCZOS)
            dst = os.path.join(UI_OUT, out_name)
            im.save(dst, "PNG", optimize=True)
            written.append((out_name, im.size, os.path.getsize(dst)))
            print("  %-46s %sx%s  %4d KB" % (out_name, im.size[0], im.size[1], os.path.getsize(dst) // 1024))
    return written


# Individual figures, taken from Программа учин.docx rather than cropped out of
# the plates. That document holds no text at all — its 30 images are the plates'
# own panels, already cut out cleanly and at a sane size, so they are a better
# source for a figure than a crop of a 74-megapixel wall chart would be.
#
# (docx member, published name, longest edge). image3/image4 are thin text
# strips and image27 duplicates image28, so none of the three is published.
DOCX = "/home/nepes/Desktop/demiryol/Berl/Программа учин.docx"
FIGURES_OUT = "assets/images/figures"
FIGURES = [
    ("image1.png", "tracked-methods-overview", 1400),
    ("image2.png", "tracked-method-1-banner", 1000),
    ("image6.png", "tracked-method-2-banner", 1000),
    ("image8.png", "tracked-method-3-banner", 1000),
    ("image12.png", "tracked-method-4-banner", 1000),
    ("image13.png", "tracked-method-5-banner", 1000),
    ("image14.png", "tracked-method-6-banner", 1000),
    ("image5.png", "kguub-1g-2g", 1400),
    ("image7.png", "iron-spur-types", 1200),
    ("image9.jpeg", "tracked-consumables-tables", 1400),
    ("image10.png", "wood-chock-shapes", 1400),
    ("image11.jpeg", "lashing-angle-45", 1400),
    ("image15.png", "iron-chock-boot-ktp-ktt", 1400),
    ("image16.png", "tracked-chock-boot-securing", 1600),
    ("image17.png", "wheeled-methods-overview", 1200),
    ("image18.png", "wheeled-method-1-banner", 1000),
    ("image19.jpeg", "wagon-plan-chock-layout", 1600),
    ("image20.png", "kguub-wheeled-under-tyre", 1200),
    ("image21.png", "kguub-1k", 1200),
    ("image22.png", "kguub-2k", 1200),
    ("image23.png", "wheeled-method-2-banner", 1000),
    ("image24.jpeg", "wire-lashings-and-consumables", 1600),
    ("image25.jpeg", "wheeled-chock-shapes-and-sizes", 1600),
    ("image26.png", "wheeled-method-3-banner", 1000),
    ("image28.png", "wheeled-chock-layout-cases", 1800),
    ("image29.png", "wheeled-chock-securing", 1600),
]


# Two figures with no panel of their own in the docx: the clamp-tensioner and
# the clamp. Both are published only on plate-02, so they are cropped from it.
# Fractions are of the plate's own width/height, measured off the converted
# plate and checked by eye against the printed panel borders.
PLATE_CROPS = [
    ("2. Zynjyrly tehnikalar.jpg", "clamp-s765", (0.008, 0.552, 0.180, 0.782), 900),
    ("2. Zynjyrly tehnikalar.jpg", "clamp-mk765", (0.008, 0.790, 0.178, 0.990), 900),
]


def convert_plate_crops():
    os.makedirs(FIGURES_OUT, exist_ok=True)
    written = []
    for filename, out_name, (l, t, r, b), edge in PLATE_CROPS:
        src = os.path.join(SRC, filename)
        if not os.path.exists(src):
            print("  MISSING %s" % filename, file=sys.stderr)
            continue
        # Decode at a size that leaves the crop sharp without ever holding the
        # full 74-megapixel CMYK image in memory.
        im = load_downscaled(src, 5200)
        w, h = im.size
        crop = im.crop((int(l * w), int(t * h), int(r * w), int(b * h)))
        crop.thumbnail((edge, edge), Image.LANCZOS)
        dst = os.path.join(FIGURES_OUT, out_name + ".jpg")
        crop.save(dst, "JPEG", quality=85, optimize=True, progressive=True)
        written.append((out_name, crop.size, os.path.getsize(dst)))
        print("  %-34s %sx%s  %4d KB" % (out_name, crop.size[0], crop.size[1], os.path.getsize(dst) // 1024))
    return written


def convert_figures():
    import zipfile

    if not os.path.exists(DOCX):
        print("  MISSING %s" % DOCX, file=sys.stderr)
        return []
    os.makedirs(FIGURES_OUT, exist_ok=True)
    written = []
    with zipfile.ZipFile(DOCX) as z:
        names = set(z.namelist())
        for member, out_name, edge in FIGURES:
            path = "word/media/" + member
            if path not in names:
                print("  MISSING %s" % path, file=sys.stderr)
                continue
            with z.open(path) as fh:
                im = Image.open(io.BytesIO(fh.read())).convert("RGB")
                im.thumbnail((edge, edge), Image.LANCZOS)
            dst = os.path.join(FIGURES_OUT, out_name + ".jpg")
            im.save(dst, "JPEG", quality=85, optimize=True, progressive=True)
            written.append((out_name, im.size, os.path.getsize(dst)))
            print("  %-34s %sx%s  %4d KB" % (out_name, im.size[0], im.size[1], os.path.getsize(dst) // 1024))
    return written


if __name__ == "__main__":
    print("Full-page plates -> %s" % PLATES_OUT)
    plates = convert_plates()
    print("\nFigures -> %s" % FIGURES_OUT)
    figures = convert_figures() + convert_plate_crops()
    print("\nBrief artwork -> %s" % UI_OUT)
    art = convert_brief_art()
    total = sum(size for _, _, size in plates + figures + art)
    print("\n%d plates, %d figures, %d artwork, %.1f MB total"
          % (len(plates), len(figures), len(art), total / 1e6))

"""
Makes the in-game addon icon (../Icons/logo.tga, 64x64) from the high-res logo
(logo.png, next to this script), for the AddOns list (## IconTexture in the .toc files).

The list shows the icon at about 20 px, so the logo is simplified: only the green
party arrow, with its gold rim, on the logo's dark blue background. The heart, the
shield and the health bars are left out.

Usage:  python make_icon.py [preview_png]      (needs Pillow: pip install pillow)
"""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "Icons", "logo.tga")
ARROW_SEED = (628, 520)   # a pixel inside the arrow's green fill, in logo.png (1254x1254)
RIM = 46                  # gold rim + glow kept around the green fill, in logo pixels
MARGIN = 0.10             # empty space around the arrow, as a fraction of the icon


def finish(img):
    """Downscale to 64x64 and restore some contrast and edge sharpness lost in the shrink."""
    icon = img.resize((64, 64), Image.LANCZOS)
    icon = ImageEnhance.Contrast(icon).enhance(1.1)
    return icon.filter(ImageFilter.UnsharpMask(radius=1, percent=60, threshold=2))


def main():
    logo = Image.open(os.path.join(HERE, "logo.png")).convert("RGB")

    # The arrow's green fill: green pixels connected to the seed.
    r, g, b = logo.split()
    green = ImageChops.subtract(g, ImageChops.lighter(r, b)).point(lambda v: 255 if v > 25 else 0)
    ImageDraw.floodfill(green, ARROW_SEED, 128)
    fill = green.point(lambda v: 255 if v == 128 else 0)

    # Grow it to take in the gold rim, with a soft edge.
    mask = fill.filter(ImageFilter.GaussianBlur(RIM / 2)).point(lambda v: 255 if v > 8 else 0)
    mask = mask.filter(ImageFilter.GaussianBlur(3))

    # Background: the logo's dark blue (from its top-left corner), lighter in the middle.
    corner = logo.crop((0, 0, 200, 200)).resize((1, 1), Image.BOX).getpixel((0, 0))
    light = tuple(min(255, int(c * 1.8)) for c in corner)
    glow = Image.radial_gradient("L").resize(logo.size)   # 0 in the middle, 255 at the edges
    background = Image.composite(Image.new("RGB", logo.size, corner), Image.new("RGB", logo.size, light), glow)
    arrow = Image.composite(logo, background, mask)

    x0, y0, x1, y1 = mask.getbbox()
    side = max(x1 - x0, y1 - y0) / (1 - 2 * MARGIN)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    crop = (int(cx - side / 2), int(cy - side / 2), int(cx + side / 2), int(cy + side / 2))

    icon = finish(arrow.crop(crop)).convert("RGBA")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    icon.save(OUT)
    print("wrote", os.path.normpath(OUT))
    if len(sys.argv) > 1:
        icon.resize((256, 256), Image.NEAREST).save(sys.argv[1])


if __name__ == "__main__":
    main()

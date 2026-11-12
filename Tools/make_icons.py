"""
Generates the FriendPlates marker icons (64x64 32-bit TGA), the Smooth
health bar texture (bar_smooth.tga, 128x16) and the health sphere textures
(sphere_mask, sphere_shade, sphere_shine, sphere_ring) in Icons/.

Usage:  python make_icons.py [icons_dir] [preview_png]
No dependencies. Every shape is a signed distance function, so edges are
anti-aliased without supersampling. Shapes are white with a dark outline:
the addon tints them per group (SetVertexColor), the outline stays dark.
"""
import math
import os
import struct
import sys
import zlib

SIZE = 64
OUTLINE = 0.07       # outline width (fraction of the icon)
DARK = 0.08          # outline brightness


# ---------------------------------------------------------------- SDF primitives
# Coordinates: (0, 0) top-left, (1, 1) bottom-right. Negative = inside.

def sd_circle(p, c, r):
    return math.hypot(p[0] - c[0], p[1] - c[1]) - r


def sd_box(p, c, half, r=0.0):
    qx = abs(p[0] - c[0]) - half[0] + r
    qy = abs(p[1] - c[1]) - half[1] + r
    outside = math.hypot(max(qx, 0), max(qy, 0))
    return outside + min(max(qx, qy), 0) - r


def sd_poly(p, pts):
    d = (p[0] - pts[0][0]) ** 2 + (p[1] - pts[0][1]) ** 2
    s = 1.0
    n = len(pts)
    j = n - 1
    for i in range(n):
        vi, vj = pts[i], pts[j]
        ex, ey = vj[0] - vi[0], vj[1] - vi[1]
        wx, wy = p[0] - vi[0], p[1] - vi[1]
        t = max(0.0, min(1.0, (wx * ex + wy * ey) / (ex * ex + ey * ey)))
        bx, by = wx - ex * t, wy - ey * t
        d = min(d, bx * bx + by * by)
        c1 = p[1] >= vi[1]
        c2 = p[1] < vj[1]
        c3 = ex * wy > ey * wx
        if (c1 and c2 and c3) or (not c1 and not c2 and not c3):
            s = -s
        j = i
    return s * math.sqrt(d)


def star_pts(cx, cy, R, r, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        a = math.radians(rot + i * 180 / n)
        rad = R if i % 2 == 0 else r
        pts.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))
    return pts


# ---------------------------------------------------------------- shapes

def s_circle(p):
    return sd_circle(p, (0.5, 0.5), 0.36)


def s_ring(p):
    return abs(sd_circle(p, (0.5, 0.5), 0.29)) - 0.09


def s_diamond(p):
    return sd_poly(p, [(0.5, 0.1), (0.88, 0.5), (0.5, 0.9), (0.12, 0.5)])


def s_square(p):
    return sd_box(p, (0.5, 0.5), (0.33, 0.33), 0.08)


def s_triangle(p):  # points down, at the unit
    return sd_poly(p, [(0.12, 0.18), (0.88, 0.18), (0.5, 0.86)])


def s_star(p):
    return sd_poly(p, star_pts(0.5, 0.54, 0.42, 0.18))


def s_heart(p):
    lobes = min(sd_circle(p, (0.33, 0.38), 0.2), sd_circle(p, (0.67, 0.38), 0.2))
    tip = sd_poly(p, [(0.15, 0.45), (0.5, 0.88), (0.85, 0.45), (0.5, 0.3)])
    return min(lobes, tip)


def s_shield(p):
    pts = [(0.16, 0.14), (0.84, 0.14), (0.84, 0.48), (0.78, 0.66),
           (0.64, 0.8), (0.5, 0.9), (0.36, 0.8), (0.22, 0.66), (0.16, 0.48)]
    return sd_poly(p, pts)


def s_chevron(p):  # thick arrow pointing down
    return sd_poly(p, [(0.1, 0.2), (0.34, 0.2), (0.5, 0.48), (0.66, 0.2), (0.9, 0.2), (0.5, 0.86)])


def s_plus(p):
    return min(sd_box(p, (0.5, 0.5), (0.13, 0.38), 0.03), sd_box(p, (0.5, 0.5), (0.38, 0.13), 0.03))


SHAPES = {
    "circle": s_circle,
    "ring": s_ring,
    "diamond": s_diamond,
    "square": s_square,
    "triangle": s_triangle,
    "star": s_star,
    "heart": s_heart,
    "shield": s_shield,
    "chevron": s_chevron,
    "plus": s_plus,
}


# ---------------------------------------------------------------- render

def render(shape):
    px = 1.0 / SIZE
    pixels = []  # rows of (r, g, b, a) floats
    for y in range(SIZE):
        row = []
        for x in range(SIZE):
            p = ((x + 0.5) * px, (y + 0.5) * px)
            d = shape(p)
            body = max(0.0, min(1.0, 0.5 - d / px))
            outer = max(0.0, min(1.0, 0.5 - (d - OUTLINE) / px))
            # light top, slightly darker bottom: gives the flat shape some depth
            shade = 1.0 - 0.22 * (y / SIZE)
            v = DARK + (shade - DARK) * (body / outer if outer > 0 else 0)
            row.append((v, v, v, outer))
        pixels.append(row)
    return pixels


def write_tga(path, pixels):
    h, w = len(pixels), len(pixels[0])
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 0x28)
    data = bytearray()
    for row in pixels:
        for r, g, b, a in row:
            data += bytes((int(b * 255 + 0.5), int(g * 255 + 0.5), int(r * 255 + 0.5), int(a * 255 + 0.5)))
    with open(path, "wb") as f:
        f.write(header + bytes(data))


def write_preview(path, images):
    """All icons in a row, tinted, on a mid-grey background (PNG)."""
    tints = [(0.3, 1, 0.4), (1, 0.6, 0.15), (1, 0.45, 0.75), (0.35, 0.85, 1), (0.8, 0.8, 0.8)]
    bg = 0.35
    w, h = SIZE * len(images), SIZE
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for i, img in enumerate(images):
            t = tints[i % len(tints)]
            for x in range(SIZE):
                r, g, b, a = img[y][x]
                for c, tc in zip((r, g, b), t):
                    raw.append(int((c * tc * a + bg * (1 - a)) * 255 + 0.5))

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xffffffff)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def render_bar_smooth(w=128, h=16):
    """Health bar fill: white with a soft top highlight and a darker bottom (tinted in game)."""
    rows = []
    for y in range(h):
        t = (y + 0.5) / h
        v = 1.0 - 0.45 * t
        if t < 0.35:
            v = min(1.0, v + 0.12 * (1 - t / 0.35))
        rows.append([(v, v, v, 1.0)] * w)
    return rows


# ---------------------------------------------------------------- health sphere
# The sphere is a vertical status bar cut by sphere_mask. Over the fill go
# sphere_shade (dark rim, so it looks round), sphere_shine (optional glossy spot)
# and sphere_ring (the border).

SPHERE_R = 0.45      # radius of the fill
RING_W = 0.045       # border width, drawn just outside the fill


def coverage(d, px):
    return max(0.0, min(1.0, 0.5 - d / px))


def render_sphere(kind):
    px = 1.0 / SIZE
    rows = []
    for y in range(SIZE):
        row = []
        for x in range(SIZE):
            p = ((x + 0.5) * px, (y + 0.5) * px)
            d = sd_circle(p, (0.5, 0.5), SPHERE_R)
            if kind == "mask":
                row.append((1.0, 1.0, 1.0, coverage(d, px)))
            elif kind == "ring":
                ring = abs(d - RING_W / 2) - RING_W / 2
                row.append((DARK, DARK, DARK, coverage(ring, px)))
            elif kind == "shade":  # rim gets darker
                rr = min(1.0, math.hypot(p[0] - 0.5, p[1] - 0.5) / SPHERE_R)
                row.append((0.0, 0.0, 0.0, 0.6 * rr ** 3 * coverage(d, px)))
            else:  # shine: glossy spot, top left
                hd = math.hypot(p[0] - 0.38, p[1] - 0.3) / 0.2
                light = 0.55 * max(0.0, 1 - hd) ** 2
                row.append((1.0, 1.0, 1.0, light * coverage(d, px)))
        rows.append(row)
    return rows


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "Icons")
    os.makedirs(out_dir, exist_ok=True)
    images = []
    for name, shape in SHAPES.items():
        img = render(shape)
        write_tga(os.path.join(out_dir, name + ".tga"), img)
        images.append(img)
        print("wrote", name)
    write_tga(os.path.join(out_dir, "bar_smooth.tga"), render_bar_smooth())
    print("wrote bar_smooth")
    for kind in ("mask", "shade", "shine", "ring"):
        write_tga(os.path.join(out_dir, "sphere_" + kind + ".tga"), render_sphere(kind))
        print("wrote sphere_" + kind)
    if len(sys.argv) > 2:
        write_preview(sys.argv[2], images)
        print("preview", sys.argv[2])


if __name__ == "__main__":
    main()

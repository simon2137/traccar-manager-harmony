"""Measure how much of a launcher icon tile the inner glyph occupies, in the
before/after home-screen screenshots, to pick a final icon size.

The tile is located with row spans of white pixels (the label text below the
tile is white too but thinner than the tile, so the span test filters it), and
the glyph is then measured inside that band.
"""
from PIL import Image

SHOTS = r"D:\dsh\Traccar\shots"
TRACCAR = (340, 220, 660, 520)   # device coords of one launcher tile column (1280x2832)


def is_white(px):
    return all(c > 232 for c in px)


def measure(name, crop, label, glyph_pred):
    img = Image.open(f"{SHOTS}\\{name}").convert("RGB")
    box = img.crop(crop)
    px = box.load()
    w, h = box.size
    spans = {}
    for y in range(h):
        xs = [x for x in range(w) if is_white(px[x, y])]
        if xs:
            spans[y] = (xs[-1] - xs[0] + 1, xs[0])
    rough = [y for y, (span, _) in spans.items() if span >= w * 0.4]
    if not rough:
        print(f"{name} / {label}: no tile found")
        return
    # the label text under the tile is white too: keep only rows whose span is
    # close to the widest span, which is the tile's own full width
    widest = max(spans[y][0] for y in rough)
    band = [y for y in rough if spans[y][0] >= widest * 0.9]
    top, bottom = band[0], band[-1]
    tile_w, tile_x = spans[band[len(band) // 2]]
    tile_h = bottom - top + 1
    pts = [(x, y) for y in range(top, bottom + 1) for x in range(w) if glyph_pred(px[x, y])]
    if not pts:
        print(f"{name} / {label}: tile {tile_w}x{tile_h} (y {top}..{bottom}), no glyph matched")
        return
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    gw, gh = max(xs) - min(xs) + 1, max(ys) - min(ys) + 1
    print(f"{name} / {label}: tile {tile_w}x{tile_h} (x {tile_x}, y {top}..{bottom}) | glyph {gw}x{gh}"
          f" | glyph/tile_w = {gw / tile_w:.3f}  glyph/tile_h = {gh / tile_h:.3f}"
          f" | centre offset dx={(min(xs) + max(xs)) / 2 - (tile_x + (tile_w - 1) / 2):+.1f}"
          f" dy={(min(ys) + max(ys)) / 2 - (top + bottom) / 2:+.1f}")


navy = lambda p: max(p) < 130 and p[2] >= p[0]          # our dark navy disc
colourful = lambda p: min(p) < 200 and max(p) - min(p) > 30   # a system icon's coloured glyph

measure("home1.jpeg", TRACCAR, "Traccar  (disc 620/1024)", navy)
measure("icon3.jpeg", TRACCAR, "Traccar  (disc 840/1024)", navy)
measure("icon2.jpeg", TRACCAR, "gallery  (platform ref)", colourful)

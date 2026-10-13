"""Rebuild the Traccar app icon layers so the navy disc (the icon's central element)
fills a larger share of the canvas: 620/1024 (60.5%) -> 840/1024 (82%).

Inputs/outputs (all under D:\\dsh\\Traccar\\harmony):
  AppScope/resources/base/media/foreground.png    1024 transparent, disc centered
  entry/src/main/resources/base/media/app_icon.png 216 white background
  entry/src/main/resources/base/media/startIcon.png 512 white background
  entry/src/main/resources/dark/media/startIcon.png 512 white background
"""
from PIL import Image

ROOT = r"D:\dsh\Traccar\harmony"
FOREGROUND = ROOT + r"\AppScope\resources\base\media\foreground.png"
APP_ICON = ROOT + r"\entry\src\main\resources\base\media\app_icon.png"
START_ICON = ROOT + r"\entry\src\main\resources\base\media\startIcon.png"
START_ICON_DARK = ROOT + r"\entry\src\main\resources\dark\media\startIcon.png"

CANVAS = 1024
DISC_NEW = 840          # target disc diameter on the 1024 canvas (82%)
WHITE = (255, 255, 255, 255)


def report(path, img=None):
    img = img or Image.open(path).convert("RGBA")
    print(f"{path.rsplit(chr(92), 1)[-1]}: {img.size[0]}x{img.size[1]} alpha_bbox={img.getchannel('A').getbbox()}")


print("=== before ===")
for p in (FOREGROUND, APP_ICON, START_ICON, START_ICON_DARK):
    report(p)

# 1) cut the existing disc (with its anti-aliased edge) out of foreground.png
src = Image.open(FOREGROUND).convert("RGBA")
box = src.getchannel("A").getbbox()
print(f"source disc bbox={box} size={box[2] - box[0]}x{box[3] - box[1]}")
disc = src.crop(box)
assert disc.size[0] == disc.size[1], "disc crop must be square"

# 2) scale it up to the new diameter (LANCZOS keeps the edge smooth)
master = disc.resize((DISC_NEW, DISC_NEW), Image.LANCZOS)

# 3) foreground layer: transparent canvas, disc centered
fg = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
fg.paste(master, ((CANVAS - DISC_NEW) // 2, (CANVAS - DISC_NEW) // 2), master)
fg.save(FOREGROUND)

# 4) flat icons: white canvas, disc scaled by the same ratio (disc = 82% of canvas)
for path, size in ((APP_ICON, 216), (START_ICON, 512), (START_ICON_DARK, 512)):
    scaled = master.resize((round(DISC_NEW / CANVAS * size),) * 2, Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), WHITE)
    offset = (size - scaled.size[0]) // 2
    canvas.paste(scaled, (offset, offset), scaled)
    canvas.convert("RGB").save(path)

print("=== after ===")
for p in (FOREGROUND, APP_ICON, START_ICON, START_ICON_DARK):
    report(p)

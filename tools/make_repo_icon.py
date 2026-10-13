"""Generate the repo-level icon assets used on GitHub.

Inputs (app icon source of truth, all under D:\\dsh\\Traccar\\harmony):
  AppScope/resources/base/media/foreground.png   1024 transparent canvas, navy disc centered (840 = 82%)
Outputs (under D:\\dsh\\Traccar\\assets):
  icon.png              512x512, white background, disc 82%   -> README logo
  icon-1024.png        1024x1024, white background             -> GitHub social preview upload
  social-preview.png   1280x640 banner, icon + title           -> optional social preview upload

Same geometry as the launcher icon (see tools/resize_icon.py), so the repo icon and the
installed app icon match.
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = r"D:\dsh\Traccar"
FOREGROUND = ROOT + r"\harmony\AppScope\resources\base\media\foreground.png"
OUT_DIR = ROOT + r"\assets"
WHITE = (255, 255, 255, 255)


def disc_master():
    """The disc cut out of foreground.png, kept at full 1024-canvas scale."""
    src = Image.open(FOREGROUND).convert("RGBA")
    box = src.getchannel("A").getbbox()
    disc = src.crop(box)
    print(f"disc bbox={box} size={disc.size[0]}x{disc.size[1]}")
    return disc, box[2] - box[0]


def disc_color(disc):
    """Dominant (median) colour of the disc's opaque pixels -> matches brand navy."""
    px = [p[:3] for p in disc.getdata() if p[3] > 200]
    px.sort(key=lambda c: sum(c))
    return px[len(px) // 2]


def flat(size, disc, disc_canvas):
    scaled = disc.resize((round(disc_canvas / 1024 * size),) * 2, Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), WHITE)
    off = (size - scaled.size[0]) // 2
    canvas.paste(scaled, (off, off), scaled)
    return canvas.convert("RGB")


def font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        print(f"font unavailable: {path}")
        return None


def banner(disc, disc_canvas, color):
    W, H = 1280, 640
    img = Image.new("RGB", (W, H), "white")
    d = ImageDraw.Draw(img)
    # subtle border so the card does not bleed into a white background
    d.rectangle([0, 0, W - 1, H - 1], outline=(222, 222, 228), width=2)

    icon = flat(320, disc, disc_canvas)
    img.paste(icon, (100, (H - 320) // 2))

    bold = font(r"C:\Windows\Fonts\segoeuib.ttf", 62)
    reg = font(r"C:\Windows\Fonts\segoeui.ttf", 32)
    if bold is None or reg is None:
        print("banner: no font, icon only")
        img.save(OUT_DIR + r"\social-preview.png")
        return

    x = 480
    d.text((x, 214), "Traccar Manager", font=bold, fill=color)
    d.text((x, 292), "for HarmonyOS", font=bold, fill=color)
    d.text((x, 380), "Native ArkTS / ArkWeb port of the Flutter client", font=reg, fill=(90, 96, 110))
    d.text((x, 424), "HarmonyOS 7  ·  API 26  ·  phone / tablet / 2in1", font=reg, fill=(90, 96, 110))
    img.save(OUT_DIR + r"\social-preview.png")


os.makedirs(OUT_DIR, exist_ok=True)
disc, disc_canvas = disc_master()
navy = disc_color(disc)
print(f"brand colour: #{navy[0]:02X}{navy[1]:02X}{navy[2]:02X}")

flat(512, disc, disc_canvas).save(OUT_DIR + r"\icon.png")
flat(1024, disc, disc_canvas).save(OUT_DIR + r"\icon-1024.png")
banner(disc, disc_canvas, navy)

for name in ("icon.png", "icon-1024.png", "social-preview.png"):
    p = OUT_DIR + "\\" + name
    im = Image.open(p)
    print(f"{name}: {im.size[0]}x{im.size[1]} {os.path.getsize(p)} bytes")

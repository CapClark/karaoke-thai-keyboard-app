"""Captioned App Store screenshots from the raw ones in ios/appstore/shots.

Each shot gets a headline (App Store search reads screenshot text, so the headlines carry the
main search words) above the raw screenshot in a rounded frame with a soft shadow.

The look is "graphite": a dark, low-saturation grey gradient (dark, muted colours read as
premium and sophisticated; bright saturated ones as cheap and loud), a faint warm glow in the
icon's orange behind the phone so the brand colour stays, white headlines and a champagne-gold
subline (gold reads as quality, and in Thailand as royalty and temples). It matches the demo clip.
Pure black and purple are avoided: both are mourning colours in Thailand.

    python3 tools/caption_shots.py [theme]   ->  ios/appstore/shots/captioned/{en,th}/*.png
"""
import subprocess
import tempfile
from pathlib import Path
import sys
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SHOTS = ROOT / "ios/appstore/shots"
OUT = SHOTS / "captioned"

# top and bottom of the background gradient, the glow behind the phone, headline, subline
THEMES = {
    "graphite": dict(top=(58, 60, 66), bottom=(14, 14, 16), glow=(233, 84, 32), glow_alpha=52,
                     head="FFFFFF", sub="E6C79C"),
    "midnight": dict(top=(30, 40, 66), bottom=(8, 11, 22), glow=(214, 168, 96), glow_alpha=55,
                     head="FFFFFF", sub="E6C79C"),
    "porcelain": dict(top=(250, 248, 244), bottom=(232, 228, 220), glow=(233, 84, 32), glow_alpha=40,
                      head="1C1C1E", sub="9A6B3A"),
    "orange": dict(top=(233, 84, 32), bottom=(233, 84, 32), glow=(233, 84, 32), glow_alpha=0,
                   head="FFFFFF", sub="FFECDE"),
}
THEME = THEMES["graphite"]
RENDER = ROOT / "tools/render_text.swift"
BIN = Path(tempfile.gettempdir()) / "karaoke_render_text"

# (raw file, canvas size, headline, subline) per language
SETS = {
    "en": [
        ("raw_iphone_1.png", (1320, 2868), "Thai keyboard that\ntypes by sound", "sawatdeekrap → สวัสดีครับ"),
        ("raw_iphone_2.png", (1320, 2868), "Type Thai in\nEnglish letters", "kinkhao → กินข้าว · any spelling"),
        ("ipad_13_1.png", (2064, 2752), "Romanized Thai typing,\nin every app", "Whole sentences · typos fixed · offline"),
    ],
    "th": [
        ("raw_iphone_1.png", (1320, 2868), "พิมพ์ไทยตามเสียง\nด้วยตัวอังกฤษ", "sawatdeekrap → สวัสดีครับ"),
        ("raw_iphone_2.png", (1320, 2868), "สะกดแบบไหนก็ได้\nเหมือนพิมพ์แชท", "kinkhao → กินข้าว"),
        ("ipad_13_1.png", (2064, 2752), "คีย์บอร์ดไทยคาราโอเกะ\nใช้ได้ทุกแอป", "ทั้งประโยค · แก้คำพิมพ์ผิด · ไม่ต้องต่อเน็ต"),
    ],
}


def text_image(text, size, bold, colour):
    """One line of text as an image, drawn by macOS (shapes Thai correctly)."""
    if not BIN.exists():
        subprocess.run(["swiftc", "-O", str(RENDER), "-o", str(BIN)], check=True)
    out = Path(tempfile.mkstemp(suffix=".png")[1])
    subprocess.run([str(BIN), str(out), str(size), "1" if bold else "0", colour, text], check=True)
    img = Image.open(out).convert("RGBA")
    img.load()
    out.unlink()
    return img


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.width, img.height], radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def background(size, top_y):
    """Vertical gradient, a soft glow behind the phone, and a little grain against banding."""
    W, H = size
    t = THEME
    grad = Image.linear_gradient("L").resize((W, H))
    canvas = Image.composite(Image.new("RGB", size, t["bottom"]), Image.new("RGB", size, t["top"]), grad)
    if t["glow_alpha"]:
        glow = Image.new("L", (W, H), 0)
        r = int(W * 0.5)
        cx, cy = W // 2, top_y + int((H - top_y) * 0.55)  # behind the phone: a halo at its edges
        ImageDraw.Draw(glow).ellipse([cx - r, cy - r, cx + r, cy + r], fill=t["glow_alpha"])
        glow = glow.filter(ImageFilter.GaussianBlur(W * 0.12))
        canvas = Image.composite(Image.new("RGB", size, t["glow"]), canvas, glow)
    noise = Image.effect_noise((W, H), 6).convert("RGB")
    return Image.blend(canvas, noise, 0.025)


def make(raw, size, head, sub):
    W, H = size
    scale = W / 1320
    head_size, sub_size = int(100 * scale), int(52 * scale)
    if W > 1500:  # iPad: wider canvas, same visual weight
        head_size, sub_size = int(66 * scale), int(36 * scale)
    lines = [text_image(line, head_size, True, THEME["head"]) for line in head.split("\n")]
    sub_img = text_image(sub, sub_size, False, THEME["sub"])
    y = int(150 * scale)
    heights = []
    for img in lines:
        heights.append(y)
        y += int(head_size * 1.22)
    sub_y = y + int(46 * scale)
    top = sub_y + sub_img.height + int(90 * scale)
    canvas = background(size, top)
    for img, hy in zip(lines, heights):
        canvas.paste(img, ((W - img.width) // 2, hy), img)
    canvas.paste(sub_img, ((W - sub_img.width) // 2, sub_y), sub_img)

    shot = Image.open(SHOTS / raw).convert("RGB")
    room_h = H - top + int(60 * scale)  # let the phone run off the bottom edge a little
    room_w = int(W * 0.84)
    k = min(room_w / shot.width, room_h / shot.height)
    shot = shot.resize((int(shot.width * k), int(shot.height * k)), Image.LANCZOS)
    frame = rounded(shot, int(70 * scale))
    x = (W - frame.width) // 2
    # soft drop shadow, then a hairline edge so the phone lifts off the background
    shadow = Image.new("L", size, 0)
    ImageDraw.Draw(shadow).rounded_rectangle([x, top + int(24 * scale), x + frame.width, top + frame.height + int(24 * scale)],
                                             int(70 * scale), fill=150)
    shadow = shadow.filter(ImageFilter.GaussianBlur(40 * scale))
    canvas = Image.composite(Image.new("RGB", size, (0, 0, 0)), canvas, shadow)
    edge = Image.new("RGBA", size, (0, 0, 0, 0))
    pad = int(6 * scale)
    ImageDraw.Draw(edge).rounded_rectangle([x - pad, top - pad, x + frame.width + pad, top + frame.height + pad],
                                           int(70 * scale) + pad, fill=(255, 255, 255, 38))
    canvas.paste(edge, (0, 0), edge)
    canvas.paste(frame, (x, top), frame)
    return canvas


def main():
    global THEME
    name = sys.argv[1] if len(sys.argv) > 1 else "graphite"
    THEME = THEMES[name]
    out = OUT if len(sys.argv) < 3 else Path(sys.argv[2])
    for lang, items in SETS.items():
        (out / lang).mkdir(parents=True, exist_ok=True)
        for i, (raw, size, head, sub) in enumerate(items, 1):
            img = make(raw, size, head, sub)
            if size[0] > 1500:
                paths = [(out / lang / f"ipad_13_{i}.png", None)]
            else:  # 6.9" and 6.3" iPhones (same shape)
                paths = [(out / lang / f"iphone_6.9_{i}.png", None), (out / lang / f"iphone_6.3_{i}.png", (1206, 2622))]
            for path, resize in paths:
                (img.resize(resize, Image.LANCZOS) if resize else img).save(path)
                print(path)


if __name__ == "__main__":
    main()

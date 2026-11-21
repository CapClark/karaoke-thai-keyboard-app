"""Captioned App Store screenshots from the raw ones in ios/appstore/shots.

Each shot gets a coloured band with a headline (App Store search reads screenshot text, so
the headlines carry the main search words) above the raw screenshot in a rounded frame.

    python3 tools/caption_shots.py   ->  ios/appstore/shots/captioned/{en,th}/*.png
"""
import subprocess
import tempfile
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SHOTS = ROOT / "ios/appstore/shots"
OUT = SHOTS / "captioned"

BG = (233, 84, 32)      # same orange as the app icon
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


def make(raw, size, head, sub):
    W, H = size
    canvas = Image.new("RGB", size, BG)
    scale = W / 1320
    head_size, sub_size = int(100 * scale), int(52 * scale)
    if W > 1500:  # iPad: wider canvas, same visual weight
        head_size, sub_size = int(66 * scale), int(36 * scale)
    y = int(120 * scale)
    for line in head.split("\n"):
        img = text_image(line, head_size, True, "FFFFFF")
        canvas.paste(img, ((W - img.width) // 2, y), img)
        y += int(head_size * 1.25)
    img = text_image(sub, sub_size, False, "FFECDE")
    canvas.paste(img, ((W - img.width) // 2, y + int(10 * scale)), img)
    top = y + int(sub_size * 3.2)

    shot = Image.open(SHOTS / raw).convert("RGB")
    room_h = H - top + int(60 * scale)  # let the phone run off the bottom edge a little
    room_w = int(W * 0.84)
    k = min(room_w / shot.width, room_h / shot.height)
    shot = shot.resize((int(shot.width * k), int(shot.height * k)), Image.LANCZOS)
    frame = rounded(shot, int(70 * scale))
    canvas.paste(frame, ((W - frame.width) // 2, top), frame)
    return canvas


def main():
    for lang, items in SETS.items():
        (OUT / lang).mkdir(parents=True, exist_ok=True)
        for i, (raw, size, head, sub) in enumerate(items, 1):
            kind = "ipad_13" if size[0] > 1500 else "iphone_6.9"
            path = OUT / lang / f"{kind}_{i}.png"
            make(raw, size, head, sub).save(path)
            print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()

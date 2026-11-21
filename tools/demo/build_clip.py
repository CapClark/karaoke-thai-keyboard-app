"""Builds the vertical demo clip from the simulator recording.

Copy this file into a working folder that holds raw.mov (simctl io recordVideo),
events.txt (the DEMO_EVENT lines from ios/DemoUITests) and sfx/*.wav, set T0 to the wall
clock of the recording's first frame, and run it there. Key clicks (sfx/ios_key1-4.wav,
sfx/ios_space.wav) are single taps cut from an iPhone typing recording; the other sounds
come from tools/demo/make_sfx.py (ElevenLabs).

raw.mov + events.txt (tap times) -> out/karaoke-thai-demo.mp4 (1080x1920, 30 fps)
Sound effects are mixed in when sfx/*.wav exist.
"""
import json
import subprocess
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

D = Path(__file__).resolve().parent
REPO = Path("/Users/kenpeeranat/Documents/pinyin for thai")
ASSETS = D / "assets"
ASSETS.mkdir(exist_ok=True)
W, H = 1080, 1920
ORANGE = (233, 84, 32)

# ---- timing (seconds) -------------------------------------------------------
T0 = 1795273185.926          # wall clock of raw video t=0 (first key popup at 7.97 s)
RAW_IN, RAW_OUT = 7.35, 24.0  # part of the recording used
SPEED = 1.25                  # typing sped up a little
PHONE_IN = 2.0                # phone slides up
CLIP_AT = 2.6                 # recording starts playing here
def ft(raw_t):                # raw video time -> final time
    return CLIP_AT + (raw_t - RAW_IN) / SPEED
CLIP_END = ft(RAW_OUT)
HOLD = 1.1                    # last frame held so the final caption can be read
END_AT = CLIP_END + HOLD      # end card fades in
TOTAL = END_AT + 3.4

events = []
for line in open(D / "events.txt"):
    t, kind, *rest = line.split()
    if RAW_IN <= float(t) - T0 <= RAW_OUT:
        events.append((ft(float(t) - T0), kind))
converts = [t for t, k in events if k == "convert"]
keys = [t for t, k in events if k == "key"]
spaces = [t for t, k in events if k == "space"]

# ---- text images ------------------------------------------------------------
BIN = D / "render_text"
if not BIN.exists():
    subprocess.run(["swiftc", "-O", str(REPO / "tools/render_text.swift"), "-o", str(BIN)], check=True)

def text(name, s, size, bold, colour="FFFFFF"):
    p = ASSETS / f"{name}.png"
    subprocess.run([str(BIN), str(p), str(size), "1" if bold else "0", colour, s], check=True)
    return p

def stack(name, parts, gap=12):
    """Centered lines stacked into one transparent image."""
    ims = [Image.open(text(f"{name}_{i}", *p)).convert("RGBA") for i, p in enumerate(parts)]
    w = max(i.width for i in ims)
    h = sum(i.height for i in ims) + gap * (len(ims) - 1)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    y = 0
    for im in ims:
        out.paste(im, ((w - im.width) // 2, y), im)
        y += im.height + gap
    p = ASSETS / f"{name}.png"
    out.save(p)
    return p, out.size

cards = {
    "intro": stack("intro", [("Type Thai by sound", 92, True), ("พิมพ์ไทยตามเสียง", 58, False, "FFE3D6")], 6),
    "head": stack("head", [("Spell it the way it sounds", 74, True)]),
    "p1": stack("p1", [("sawatdeekrap  →  สวัสดีครับ", 60, True), ("hello", 46, False, "FFE3D6")], 0),
    "p2": stack("p2", [("kinkhaoyang  →  กินข้าวยัง", 60, True), ("have you eaten?", 46, False, "FFE3D6")], 0),
    "end": stack("end", [("Karaoke Thai Keyboard", 80, True), ("Free on the App Store", 54, False, "FFE3D6"),
                         ("iPhone · iPad · Mac", 42, False, "FFD0BC")], 4),
}

# ---- background, phone frame ------------------------------------------------
bg = Image.new("RGB", (W, H), ORANGE)
glow = Image.new("L", (W, H), 0)
ImageDraw.Draw(glow).ellipse([-300, -500, W + 300, 900], fill=255)
glow = glow.filter(ImageFilter.GaussianBlur(220))
bg = Image.composite(Image.new("RGB", (W, H), (246, 120, 62)), bg, glow)
shade = Image.new("L", (W, H), 0)
ImageDraw.Draw(shade).rectangle([0, 1300, W, H], fill=255)
shade = shade.filter(ImageFilter.GaussianBlur(260))
bg = Image.composite(Image.new("RGB", (W, H), (205, 64, 20)), bg, shade)
bg.save(ASSETS / "bg.png")

# recording crop: message box + candidate bar + keys
CROP_Y, CROP_H = 1340, 1282          # in the 1206 x 2622 recording
PW = 1000
PH = round(CROP_H * PW / 1206)
PX, PY = (W - PW) // 2, 650
R = 56
mask = Image.new("L", (PW, PH), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, PW - 1, PH - 1], R, fill=255)
mask.save(ASSETS / "mask.png")
sh = Image.new("RGBA", (PW + 160, PH + 160), (0, 0, 0, 0))
ImageDraw.Draw(sh).rounded_rectangle([80, 100, PW + 80, PH + 100], R, fill=(90, 25, 5, 120))
sh.filter(ImageFilter.GaussianBlur(36)).save(ASSETS / "shadow.png")

icon = Image.open(REPO / "ios/App/Assets.xcassets/AppIcon.appiconset/icon.png").convert("RGBA").resize((300, 300), Image.LANCZOS)
im = Image.new("L", (300, 300), 0)
ImageDraw.Draw(im).rounded_rectangle([0, 0, 299, 299], 68, fill=255)
icon.putalpha(im)
ish = Image.new("RGBA", (420, 420), (0, 0, 0, 0))
ImageDraw.Draw(ish).rounded_rectangle([60, 80, 360, 380], 68, fill=(90, 25, 5, 140))
ish = ish.filter(ImageFilter.GaussianBlur(26))
ish.paste(icon, (60, 60), icon)
ish.save(ASSETS / "icon.png")

# ---- ffmpeg graph -----------------------------------------------------------
def ease_out(t0, dur, a, b):
    """Expression going from a to b between t0 and t0+dur with a cubic ease-out."""
    p = f"min(max((t-{t0})/{dur},0),1)"
    return f"({a}+({b}-{a})*(1-pow(1-{p},3)))"

inputs = ["-loop", "1", "-t", f"{TOTAL}", "-i", str(ASSETS / "bg.png"),
          "-ss", f"{RAW_IN}", "-to", f"{RAW_OUT}", "-i", str(D / "raw.mov"),
          "-loop", "1", "-i", str(ASSETS / "mask.png"),
          "-loop", "1", "-i", str(ASSETS / "shadow.png"),
          "-loop", "1", "-i", str(ASSETS / "icon.png")]
card_names = list(cards)
for n in card_names:
    inputs += ["-loop", "1", "-i", str(cards[n][0])]
idx = {n: 5 + i for i, n in enumerate(card_names)}

def card_window(n):
    if n == "intro":
        return 0.25, PHONE_IN + 0.1
    if n == "head":
        return CLIP_AT, END_AT
    if n == "end":
        return END_AT + 0.35, TOTAL + 1
    i = int(n[1]) - 1
    start = converts[i] - 0.05
    stop = converts[i + 1] - 0.05 if i + 1 < len(converts) else END_AT
    return start, stop

f = []
f.append("[1:v]split=2[rawA][rawB]")
f.append(f"[rawA]setpts=(PTS-STARTPTS)/{SPEED},fps=30,crop=1206:{CROP_H}:0:{CROP_Y},"
         f"scale={PW}:{PH}:flags=lanczos,format=rgba,tpad=stop_mode=clone:stop_duration={HOLD}[ph0]")
f.append(f"[2:v]format=gray,scale={PW}:{PH},split=2[m][m2]")
f.append("[ph0][m]alphamerge,setpts=PTS+%f/TB[ph]" % CLIP_AT)
# first frame of the recording held before it starts playing (the phone slides in with it)
f.append(f"[rawB]trim=end_frame=1,setpts=PTS-STARTPTS,crop=1206:{CROP_H}:0:{CROP_Y},scale={PW}:{PH}:flags=lanczos,"
         f"format=rgba,loop=loop=-1:size=1,trim=duration={CLIP_AT + 0.05}[still0]")
f.append("[still0][m2]alphamerge[still]")
y_phone = ease_out(PHONE_IN, 0.6, H + 40, PY)
y_phone_out = f"if(gte(t,{END_AT}),{y_phone}+{ease_out(END_AT, 0.55, 0, H)},{y_phone})"
f.append("[0:v]format=rgba[bg]")
f.append(f"[bg][3:v]overlay=x={PX - 80}:y='{y_phone_out}-80+20':enable='gte(t,{PHONE_IN})'[b1]")
f.append(f"[b1][still]overlay=x={PX}:y='{y_phone_out}':enable='between(t,{PHONE_IN},{CLIP_AT})'[b2]")
f.append(f"[b2][ph]overlay=x={PX}:y='{y_phone_out}':eof_action=pass[b3]")
last = "b3"
for n in card_names:
    s, e = card_window(n)
    w, h = cards[n][1]
    if n == "intro":
        y = f"(760+{ease_out(s, 0.5, 40, 0)})"
    elif n == "head":
        y = f"(170+{ease_out(s, 0.45, 30, 0)})"
    elif n == "end":
        y = f"(1060+{ease_out(s, 0.5, 40, 0)})"
    else:
        y = f"(320+{ease_out(s, 0.35, 24, 0)})"
    fade_out = f",fade=t=out:st={e - 0.2}:d=0.2:alpha=1" if e < TOTAL else ""
    f.append(f"[{idx[n]}:v]format=rgba,trim=duration={TOTAL},fade=t=in:st={s}:d=0.3:alpha=1{fade_out}[c_{n}]")
    f.append(f"[{last}][c_{n}]overlay=x=(W-{w})/2:y='{y}':enable='between(t,{s},{e})'[o_{n}]")
    last = f"o_{n}"
# app icon on the end card
s = END_AT + 0.25
f.append(f"[4:v]format=rgba,trim=duration={TOTAL},fade=t=in:st={s}:d=0.35:alpha=1[ic]")
f.append(f"[{last}][ic]overlay=x=(W-420)/2:y='(560+{ease_out(s, 0.55, 60, 0)})':enable='gte(t,{s})'[v0]")
f.append(f"[v0]fade=t=in:st=0:d=0.4,fade=t=out:st={TOTAL - 0.45}:d=0.45,format=yuv420p[v]")

# ---- sound ------------------------------------------------------------------
sfx = D / "sfx"
audio_inputs, a = [], []
def sound(path, at, vol):
    k = len(audio_inputs) + len(inputs) // 2  # placeholder, fixed below
    audio_inputs.append((path, at, vol))

if (sfx / "ios_key1.wav").exists():
    import random
    random.seed(7)
    # the iPhone's own key click (cut from the user's recording): letters, then space
    for t in keys:
        sound(sfx / f"ios_key{random.randint(1, 4)}.wav", t, 1.0)
    for t in spaces + converts:
        sound(sfx / "ios_space.wav", t, 1.0)
    for t in converts:
        sound(sfx / "convert.wav", t + 0.03, 0.62)
    sound(sfx / "intro.wav", 0.2, 0.5)
    sound(sfx / "whoosh.wav", PHONE_IN - 0.1, 0.4)
    sound(sfx / "whoosh_out.wav", END_AT - 0.05, 0.3)
    sound(sfx / "end.wav", END_AT + 0.3, 0.6)
    if (sfx / "bed.wav").exists():
        sound(sfx / "bed.wav", 0.0, 0.13)

n_video_inputs = 5 + len(card_names)
cmd = ["ffmpeg", "-y", "-v", "error", "-stats"] + inputs
for path, at, vol in audio_inputs:
    cmd += ["-i", str(path)]
labels = []
for j, (path, at, vol) in enumerate(audio_inputs):
    ms = int(at * 1000)
    f.append(f"[{n_video_inputs + j}:a]aformat=sample_rates=48000:channel_layouts=stereo,volume={vol},adelay={ms}|{ms}[a{j}]")
    labels.append(f"[a{j}]")
if labels:
    f.append("".join(labels) + f"amix=inputs={len(labels)}:normalize=0:dropout_transition=0,"
             f"atrim=duration={TOTAL},afade=t=out:st={TOTAL - 0.6}:d=0.6,"
             "alimiter=limit=0.89,loudnorm=I=-16:TP=-1.5:LRA=11[aout]")

out = D / "out"
out.mkdir(exist_ok=True)
graph = ";\n".join(f)
(D / "graph.txt").write_text(graph)
cmd += ["-/filter_complex", str(D / "graph.txt"), "-map", "[v]"]
if labels:
    cmd += ["-map", "[aout]", "-c:a", "aac", "-b:a", "192k"]
cmd += ["-t", f"{TOTAL}", "-r", "30", "-c:v", "libx264", "-preset", "slow", "-crf", "17",
        "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(out / "karaoke-thai-demo.mp4")]
print(json.dumps({"total": round(TOTAL, 2), "converts": [round(c, 2) for c in converts],
                  "keys": len(keys), "sounds": len(audio_inputs)}))
subprocess.run(cmd, check=True)
print(out / "karaoke-thai-demo.mp4")

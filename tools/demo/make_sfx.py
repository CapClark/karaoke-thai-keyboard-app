import json, os, sys, urllib.request, concurrent.futures as cf
key = open(os.path.expanduser("~/Documents/api_keys/elevenlabs.txt")).read().strip()
out = sys.argv[1]
S = {
 "key1": ("single soft muted smartphone keyboard tap, gentle subtle tick, very short, clean, dry, no reverb", 0.5),
 "key2": ("one soft gentle phone keyboard key click, light plastic tap, very short, clean, dry", 0.5),
 "key3": ("single quiet soft keyboard tap on glass screen, delicate tick, very short, clean, dry", 0.5),
 "convert": ("bright gentle magical chime pop with soft sparkle, short pleasant UI success sound, clean", 1.0),
 "whoosh": ("soft airy swoosh rising upward, smooth gentle UI transition whoosh, clean, no noise", 0.8),
 "whoosh_out": ("soft airy swoosh falling downward, smooth gentle UI transition, clean", 0.8),
 "intro": ("soft warm synth pluck with gentle shimmer swell, modern friendly app intro, clean", 1.6),
 "end": ("warm uplifting success chime with soft bells and sparkle, pleasant app logo sting, clean ending", 2.6),
 "bed": ("calm cheerful lo-fi background music, soft warm electric piano chords and light brushed beat, gentle, no vocals", 22.0),
}
def gen(name):
    text, dur = S[name]
    req = urllib.request.Request("https://api.elevenlabs.io/v1/sound-generation",
        data=json.dumps({"text": text, "duration_seconds": dur, "prompt_influence": 0.5}).encode(),
        headers={"xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/mpeg"})
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            open(f"{out}/{name}.mp3", "wb").write(r.read())
        return name, "ok"
    except urllib.error.HTTPError as e:
        return name, f"HTTP {e.code} {e.read()[:200]!r}"
with cf.ThreadPoolExecutor(4) as ex:
    for n, r in ex.map(gen, S):
        print(n, r)

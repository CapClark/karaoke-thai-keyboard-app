"""Build web/dict.js from the cached romanizations.

Inputs (made by rom_cache.py and g2p_cache.py):
  rom_cache.json  word -> romanization from the neural romanizer (thai2rom_onnx)
  g2p_cache.json  word -> IPA from the pronunciation model (thaig2p), top words only
Plus TNC corpus word and word-pair (bigram) frequencies.

Output: window.THAI_DICT = {w: [...words], r: ["rom|rom2", ...], f: [...], b: [i, j, count, ...]}
Usage: python build_dict.py
"""
import json
import os
import re
import warnings

warnings.filterwarnings("ignore")
from pythainlp.corpus import tnc

HERE = os.path.dirname(os.path.abspath(__file__))
rom = json.load(open(os.path.join(HERE, "rom_cache.json"), encoding="utf-8"))
g2p = json.load(open(os.path.join(HERE, "g2p_cache.json"), encoding="utf-8"))
freq = dict(tnc.word_freqs())

# IPA phoneme -> Latin, by position in the syllable.
INITIAL = {"kʰ": "kh", "k": "k", "pʰ": "ph", "p": "p", "tʰ": "th", "t": "t", "t͡ɕʰ": "ch",
           "t͡ɕ": "j", "b": "b", "d": "d", "m": "m", "n": "n", "ŋ": "ng", "f": "f", "s": "s",
           "h": "h", "j": "y", "w": "w", "r": "r", "l": "l", "ʔ": ""}
FINAL = {"k̚": "k", "t̚": "t", "p̚": "p", "m": "m", "n": "n", "ŋ": "ng", "j": "i", "w": "o",
         "ʔ": "", "k": "k", "t": "t", "p": "p", "s": "t", "f": "p", "l": "n"}
VOWEL = {"a": "a", "aː": "a", "i": "i", "iː": "i", "u": "u", "uː": "u", "ɯ": "ue", "ɯː": "ue",
         "e": "e", "eː": "e", "ɛ": "ae", "ɛː": "ae", "o": "o", "oː": "o", "ɔ": "o", "ɔː": "o",
         "ɤ": "oe", "ɤː": "oe", "a̯": "a", "ia": "ia", "ua": "ua", "ɯa": "uea"}
TONES = set("˥˦˧˨˩")


def ipa_to_latin(ipa):
    out = []
    for syl in ipa.split(" . "):
        ph = [p for p in syl.split() if not set(p) <= TONES]
        s, seen_vowel = "", False
        for p in ph:
            if p in VOWEL:
                s += VOWEL[p]
                seen_vowel = True
            elif not seen_vowel:
                if p not in INITIAL:
                    return None
                s += INITIAL[p]
            else:
                if p not in FINAL:
                    return None
                s += FINAL[p]
        out.append(s)
    return "".join(out)


# Compound words the corpus always splits (เมื่อวาน = เมื่อ + วาน): count them via word pairs.
from pythainlp.corpus import thai_words
from pythainlp.transliterate import romanize
dict_words = set(thai_words())
bigrams = tnc.bigram_word_freqs()
added = 0
for (a, b), c in bigrams.items():
    w = a + b
    if c >= 20 and w in dict_words and c > freq.get(w, 0):
        freq[w] = c
        if w not in rom:
            rom[w] = re.sub(r"[^a-z]", "", romanize(w, engine="thai2rom_onnx").lower())
            added += 1
json.dump(rom, open(os.path.join(HERE, "rom_cache.json"), "w", encoding="utf-8"), ensure_ascii=False)
print("compounds added", added)

# Casual online usage (tools/casual_counts.py): blend with the formal counts so chat
# words aren't under-ranked (นะ vs หน้า, ค่ะ vs ค่า). Words common online but missing
# from the vocabulary are added. CASUAL_WEIGHT = share of the blend from online text.
CASUAL_WEIGHT = float(os.environ.get("CASUAL_WEIGHT", "0.4"))  # chosen by testing 0, 0.3, 0.5, 0.7
casual_path = os.path.join(HERE, "casual_freq.json")
casual = json.load(open(casual_path, encoding="utf-8")) if os.path.exists(casual_path) else {}
if casual:
    tnc_total = sum(freq.values())
    cas_total = sum(casual.values())
    new_words = 0
    for w, c in casual.items():
        if c >= 30 and w not in rom and len(w) > 1:  # >= ~3 uses per million casual words
            rom[w] = re.sub(r"[^a-z]", "", romanize(w, engine="thai2rom_onnx").lower())
            new_words += 1
    for w in set(freq) | set(casual):
        f_formal = freq.get(w, 0) / tnc_total
        f_casual = casual.get(w, 0) / cas_total
        freq[w] = round(tnc_total * ((1 - CASUAL_WEIGHT) * f_formal + CASUAL_WEIGHT * f_casual))
    json.dump(rom, open(os.path.join(HERE, "rom_cache.json"), "w", encoding="utf-8"), ensure_ascii=False)
    print(f"casual blend: weight {CASUAL_WEIGHT}, {len(casual)} online words, {new_words} new words added")

vocab = [w for w in rom if rom[w]]
vocab.sort(key=lambda w: -freq.get(w, 0))
index = {w: i for i, w in enumerate(vocab)}

roms, bad = [], 0
for w in vocab:
    rs = [rom[w]]
    ipa = g2p.get(w)
    if ipa:
        lat = ipa_to_latin(ipa)
        # The pronunciation model sometimes stops early on long words; skip those.
        if lat and len(lat) >= 0.7 * len(rom[w]) and lat not in rs:
            rs.append(lat)
        elif lat is None:
            bad += 1
    roms.append("|".join(rs))

pairs = []
for (a, b), c in bigrams.items():
    if c >= 3 and a in index and b in index:
        pairs.append((index[a], index[b], c))
pairs.sort(key=lambda x: -x[2])
pairs = sorted(pairs[:250000])  # sorted by ids: the engine binary-searches them
flat = [x for p in pairs for x in p]

# Three-word sequences help long sentences (which word fits after the last two).
tri = []
for (a, b, c), n in tnc.trigram_word_freqs().items():
    if n >= 4 and a in index and b in index and c in index:
        tri.append((index[a], index[b], index[c], n))
tri.sort(key=lambda x: -x[3])
tri = sorted(tri[:150000])
tflat = [x for t in tri for x in t]

# Frequent 2-3 word phrases as single entries, so common phrases match in one
# lookup (faster than splitting, and the phrase's own count ranks it).
THAI_ONLY = re.compile(r"^[\u0E00-\u0E7F]+$")
phrases = {}
def add_phrase(parts, c):
    if all(THAI_ONLY.match(x) and rom.get(x) for x in parts):
        text = "".join(parts)
        if text not in index and c > phrases.get(text, (0, ""))[0]:
            phrases[text] = (c, "".join(rom[x] for x in parts), parts[-1])
for (a, b), c in bigrams.items():
    if c >= 200:
        add_phrase((a, b), c)
for (a, b, c3), c in tnc.trigram_word_freqs().items():
    if c >= 100:
        add_phrase((a, b, c3), c)
plist = sorted(([t, r, c, last] for t, (c, r, last) in phrases.items()), key=lambda x: -x[2])
print(f"phrases {len(plist)}")

data = {"w": vocab, "r": roms, "f": [freq.get(w, 0) for w in vocab], "b": flat, "t": tflat, "p": plist}
out = os.path.join(HERE, "..", "web", "dict.js")
with open(out, "w", encoding="utf-8") as fh:
    fh.write("window.THAI_DICT=")
    json.dump(data, fh, ensure_ascii=False, separators=(",", ":"))
    fh.write(";\n")
print(f"trigrams {len(tri)}")
print(f"words {len(vocab)}  with 2 spellings {sum('|' in r for r in roms)}  ipa-unparsed {bad}  bigrams {len(pairs)}")
print(f"size {os.path.getsize(out) / 1e6:.1f} MB")

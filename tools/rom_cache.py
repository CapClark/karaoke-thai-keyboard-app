"""Cache neural romanizations (PyThaiNLP thai2rom_onnx) for the vocabulary.

Vocabulary = TNC corpus words + PyThaiNLP dictionary words, most frequent first.
Seeds the cache from an old web/dict.js if present. Saves rom_cache.json.
Usage: python rom_cache.py 60000
"""
import json
import os
import re
import sys
import warnings

warnings.filterwarnings("ignore")
from pythainlp.corpus import thai_words, tnc
from pythainlp.transliterate import romanize

LIMIT = int(sys.argv[1]) if len(sys.argv) > 1 else 60000
HERE = os.path.dirname(os.path.abspath(__file__))
PATH = os.path.join(HERE, "rom_cache.json")
THAI = re.compile(r"^[฀-๿]+$")

cache = {}
if os.path.exists(PATH):
    cache = json.load(open(PATH, encoding="utf-8"))
else:
    old = os.path.join(HERE, "..", "web", "dict.js")
    if os.path.exists(old):
        src = open(old, encoding="utf-8").read()
        src = src[src.index("=") + 1 : src.rstrip().rindex(";")]
        for row in json.loads(src):
            if isinstance(row[1], str):
                cache[row[0]] = row[1]

freqs = {w: f for w, f in tnc.word_freqs() if THAI.match(w)}
for w in thai_words():
    if THAI.match(w) and w not in freqs:
        freqs[w] = 0
words = [w for w, _ in sorted(freqs.items(), key=lambda kv: (-kv[1], len(kv[0])))][:LIMIT]

todo = [w for w in words if w not in cache]
print("todo", len(todo), flush=True)
for i, w in enumerate(todo):
    try:
        cache[w] = re.sub(r"[^a-z]", "", romanize(w, engine="thai2rom_onnx").lower())
    except Exception:
        cache[w] = ""
    if i % 2000 == 0:
        json.dump(cache, open(PATH, "w", encoding="utf-8"), ensure_ascii=False)
        print(i, flush=True)
json.dump(cache, open(PATH, "w", encoding="utf-8"), ensure_ascii=False)
print("done", len(cache))

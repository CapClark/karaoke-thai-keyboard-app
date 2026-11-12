"""Cache IPA pronunciations (PyThaiNLP thaig2p) for the most frequent words.

Slow (~0.3 s/word), so results are saved to g2p_cache.json and reused.
Usage: python g2p_cache.py 10000
"""
import json
import os
import re
import sys
import warnings

warnings.filterwarnings("ignore")
from pythainlp.corpus import tnc
from pythainlp.transliterate import transliterate

LIMIT = int(sys.argv[1]) if len(sys.argv) > 1 else 10000
THAI = re.compile(r"^[฀-๿]+$")
PATH = os.path.join(os.path.dirname(__file__), "g2p_cache.json")

cache = json.load(open(PATH, encoding="utf-8")) if os.path.exists(PATH) else {}
words = [w for w, f in sorted(tnc.word_freqs(), key=lambda x: -x[1]) if THAI.match(w)][:LIMIT]

todo = [w for w in words if w not in cache]
print("todo", len(todo), flush=True)
for i, w in enumerate(todo):
    try:
        cache[w] = transliterate(w, engine="thaig2p")
    except Exception as e:
        cache[w] = None
    if i % 200 == 0:
        json.dump(cache, open(PATH, "w", encoding="utf-8"), ensure_ascii=False)
        print(i, flush=True)
json.dump(cache, open(PATH, "w", encoding="utf-8"), ensure_ascii=False)
print("done", len(cache))

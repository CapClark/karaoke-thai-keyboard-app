"""Count words in casual online Thai (social posts, reviews, tweets).

The main word counts (TNC corpus) come from formal writing, so chat words are
under-counted: นะ vs หน้า, ค่ะ vs ค่า, หรอก vs โรค. This counts real online usage
from two public datasets downloaded into tools/data/ (both allow commercial use):
  wisesight/   Wisesight sentiment corpus: social-media posts (CC0)
  wongnai/     Wongnai restaurant reviews (LGPL-3.0)
Output: tools/casual_freq.json  {word: count}. Only counts are kept, no text.
Usage: .venv/bin/python casual_counts.py
"""
import collections
import csv
import json
import os
import re
import sys
import warnings
from multiprocessing import Pool

warnings.filterwarnings("ignore")
HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "data")
THAI = re.compile(r"^[฀-๿]+$")


def texts(source):
    if source == "wisesight":
        for name in ("train.txt", "test.txt"):
            p = os.path.join(DATA, "wisesight", name)
            if os.path.exists(p):
                with open(p, encoding="utf-8") as fh:
                    yield from fh
    p = os.path.join(DATA, "wongnai", "w_review_train.csv")
    if source == "wongnai" and os.path.exists(p):
        csv.field_size_limit(sys.maxsize)
        with open(p, encoding="utf-8") as fh:
            for row in csv.reader(fh, delimiter=";"):
                if row:
                    yield row[0]


def count(chunk):
    from pythainlp.tokenize import word_tokenize

    c = collections.Counter()
    for t in chunk:
        # Stretched letters ("มากกกกก") count as the plain word.
        t = re.sub(r"(.)\1{2,}", r"\1", t)
        for w in word_tokenize(t, engine="newmm", keep_whitespace=False):
            if THAI.match(w) and len(w) > 1:  # single letters are mostly abbreviation fragments
                c[w] += 1
    return c


# Each source is counted separately, then mixed with these shares so the large
# review corpus (mostly about food) doesn't dominate: ข้าว would otherwise beat เขา.
SHARES = {"wisesight": 0.75, "wongnai": 0.25}  # reviews skew to food words

if __name__ == "__main__":
    per = {}
    with Pool() as pool:
        for src in SHARES:
            all_texts = list(texts(src))
            chunks = [all_texts[i : i + 2000] for i in range(0, len(all_texts), 2000)]
            c = collections.Counter()
            for part in pool.imap_unordered(count, chunks):
                c.update(part)
            per[src] = c
            print(f"{src}: {len(all_texts)} texts, {sum(c.values())} words", flush=True)
    # Mixed usage, as an expected count per 10 million words of casual Thai.
    mixed = collections.Counter()
    for src, c in per.items():
        n = sum(c.values()) or 1
        for w, k in c.items():
            mixed[w] += SHARES[src] * k / n * 1e7
    out = os.path.join(HERE, "casual_freq.json")
    json.dump({w: round(v, 1) for w, v in mixed.most_common() if v >= 0.5}, open(out, "w", encoding="utf-8"), ensure_ascii=False)
    print(f"{len(mixed)} distinct words -> casual_freq.json")

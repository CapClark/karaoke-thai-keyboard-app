"""Import your own Thai words from Wispr Flow dictation history (local only).

Reads ~/Library/Application Support/Wispr Flow/flow.sqlite read-only, keeps only
Thai text you dictated, splits it into words and writes web/personal.js:
    window.THAI_PERSONAL = [[word, count, romanization], ...]
Those words rank higher, and names/slang missing from the word list get added.
Nothing leaves this computer. Delete web/personal.js to undo, then rerun mac/build.sh.
Usage: .venv/bin/python import_wispr.py
"""
import collections
import json
import os
import re
import sqlite3
import warnings

warnings.filterwarnings("ignore")
from pythainlp.tokenize import word_tokenize
from pythainlp.transliterate import romanize

DB = os.path.expanduser("~/Library/Application Support/Wispr Flow/flow.sqlite")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "web", "personal.js")
THAI = re.compile(r"^[฀-๿]+$")

texts = []
if os.path.exists(DB):
    con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
    for (t,) in con.execute(
        "SELECT COALESCE(editedText, formattedText, asrText) FROM History "
        "WHERE COALESCE(isArchived,0)=0 AND COALESCE(editedText, formattedText, asrText) GLOB '*[ก-๙]*'"
    ):
        texts.append(t)
    con.close()

counts = collections.Counter()
for t in texts:
    for w in word_tokenize(t, engine="newmm", keep_whitespace=False):
        if THAI.match(w) and len(w) > 1:
            counts[w] += 1

rows = []
for w, c in counts.most_common(5000):
    r = re.sub(r"[^a-z]", "", romanize(w, engine="thai2rom_onnx").lower())
    rows.append([w, c, r])

with open(OUT, "w", encoding="utf-8") as fh:
    fh.write("window.THAI_PERSONAL=")
    json.dump(rows, fh, ensure_ascii=False, separators=(",", ":"))
    fh.write(";\n")
print(f"{len(texts)} Thai dictations -> {len(rows)} words in web/personal.js")

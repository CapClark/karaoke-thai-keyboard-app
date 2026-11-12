// Adds common chat spellings to the 15,000 most-used words in web/dict.js.
//
// The sound map (web/phonemes.js) already treats most chat habits as the same
// sound (kh/k, ee/i, oo/u, j/ch, final d/t, r/l, ...). This adds the habits it
// can't, because they change the vowel letter:
//   a -> u  for a SHORT a closed by a final consonant: ครั้ง khrang -> krung,
//           ทำ tham -> tum, ฉัน chan -> chun. Never the long aa (ตาม taam stays tam):
//           vowel length comes from the pronunciation cache (tools/g2p_cache.json),
//           since romanizations don't record it. Words without a pronunciation get no a -> u.
//   uea -> ua                      เมื่อ muea -> mua, เพื่อน phuean -> phuan
//   ue -> u                        ถึง thueng -> thung, ชื่อ chue -> chu
//   ue -> eu stays (already the same sound)
//
// Safety: a spelling is only added if no common word already matches it exactly.
// Otherwise "khun" (คุณ) would start giving การ (kan -> kun). Specifically, the
// word must be at least 5x more common than the best existing exact match, and that
// match must be used fewer than 10,000 times in the corpus.
//
// Runs at build time (mac/build.sh) so startup stays fast. Usage: node tools/chat_spellings.js
const fs = require("fs");
const path = require("path");
const P = require("../web/phonemes.js");

const VERSION = "chat-2";
const TOP = 15000;
const file = path.join(__dirname, "..", "web", "dict.js");
const src = fs.readFileSync(file, "utf8");
const dict = JSON.parse(src.slice(src.indexOf("=") + 1, src.lastIndexOf(";")));
if (dict.chat === VERSION) { console.log("chat spellings up to date"); process.exit(0); }

const g2pFile = path.join(__dirname, "g2p_cache.json");
const g2p = fs.existsSync(g2pFile) ? JSON.parse(fs.readFileSync(g2pFile, "utf8")) : {};

// IPA -> Latin, writing each short closed a as u (ครั้ง kʰ r a ŋ -> "khrung").
const INI = { "kʰ": "kh", k: "k", "pʰ": "ph", p: "p", "tʰ": "th", t: "t", "t͡ɕʰ": "ch", "t͡ɕ": "ch", b: "b", d: "d",
  m: "m", n: "n", "ŋ": "ng", f: "f", s: "s", h: "h", j: "y", w: "w", r: "r", l: "l", "ʔ": "" };
const FIN = { "k̚": "k", "t̚": "t", "p̚": "p", m: "m", n: "n", "ŋ": "ng", j: "i", w: "o", "ʔ": "", k: "k", t: "t", p: "p", s: "t", f: "p", l: "n" };
const VOW = { a: "a", "aː": "a", i: "i", "iː": "i", u: "u", "uː": "u", "ɯ": "ue", "ɯː": "ue", e: "e", "eː": "e", "ɛ": "ae",
  "ɛː": "ae", o: "o", "oː": "o", "ɔ": "o", "ɔː": "o", "ɤ": "oe", "ɤː": "oe", "a̯": "a" };
const STOPS = new Set(["k̚", "t̚", "p̚", "m", "n", "ŋ"]); // a final that closes the syllable (not j/w: ai/ao stay)
function shortAasU(ipa) {
  let out = "", changed = false;
  for (const syl of ipa.split(" . ")) {
    const ph = syl.split(" ").filter((p) => !/^[˥˦˧˨˩]+$/.test(p));
    const vi = ph.findIndex((p) => p in VOW);
    if (vi < 0) return null;
    let s = "";
    for (let i = 0; i < ph.length; i++) {
      const p = ph[i];
      if (i < vi) { if (!(p in INI)) return null; s += INI[p]; }
      else if (i === vi) {
        const closed = ph.length === vi + 2 && STOPS.has(ph[vi + 1]);
        if (p === "a" && closed) { s += "u"; changed = true; } else s += VOW[p];
      } else { if (p in VOW) { s += VOW[p]; continue; } if (!(p in FIN)) return null; s += FIN[p]; }
    }
    out += s;
  }
  return changed ? out : null;
}

// Best corpus count per sound key, over words and phrases.
const best = new Map();
const note = (key, f) => { if (!(best.get(key) >= f)) best.set(key, f); };
dict.w.forEach((w, i) => dict.r[i].split("|").forEach((r) => note(P.tokenize(r).key, dict.f[i])));
(dict.p || []).forEach(([, r, c]) => note(P.tokenize(r).key, c));

function variants(r, word) {
  const out = new Set();
  const ipa = g2p[word];
  if (ipa) {
    const u = shortAasU(ipa);
    // The pronunciation model sometimes stops early on long words; skip those.
    if (u && u.length >= 0.7 * r.length) out.add(u);
  }
  if (r.includes("uea")) out.add(r.replace(/uea/g, "ua"));
  if (/ue(?!a)/.test(r)) out.add(r.replace(/ue(?!a)/g, "u"));
  out.delete(r);
  return [...out];
}

let added = 0, blocked = 0;
const order = dict.w.map((_, i) => i).sort((a, b) => dict.f[b] - dict.f[a]).slice(0, TOP);
for (const i of order) {
  const rs = dict.r[i].split("|");
  const own = new Set(rs.map((r) => P.tokenize(r).key));
  const extra = [];
  for (const v of variants(rs[0], dict.w[i])) {
    const key = P.tokenize(v).key;
    if (!key || own.has(key)) continue;
    const fe = best.get(key) || 0;
    if (fe < dict.f[i] / 5 && fe < 10000) { extra.push(v); own.add(key); added++; }
    else blocked++;
  }
  if (extra.length) dict.r[i] = [...rs, ...extra].join("|");
}
dict.chat = VERSION;
delete dict.sig; // sound keys must be recomputed for the new spellings
fs.writeFileSync(file, "window.THAI_DICT=" + JSON.stringify(dict) + ";\n");
console.log(`chat spellings: added ${added}, skipped ${blocked} that would push out a common word`);

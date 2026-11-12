// Writes a smaller word list for the iPhone/iPad keyboard: web/dict.mobile.js.
//
// iOS stops a keyboard that uses more than about 50-70 MB of memory; the full
// list needs about 100 MB once loaded. This keeps the most-used words, word
// pairs, three-word sequences and phrases (corpus counts decide), remaps the word
// numbers, and keeps the sound keys saved at build time so startup stays fast.
//
// Usage: node tools/mobile_dict.js [words] [pairs] [triples] [phrases]
const fs = require("fs");
const path = require("path");

const [WORDS, PAIRS, TRIPLES, PHRASES] = process.argv.slice(2).map(Number);
const N_WORDS = WORDS || 40000, N_PAIRS = PAIRS || 120000, N_TRI = TRIPLES || 60000, N_PHR = PHRASES || 12000;
const dir = path.join(__dirname, "..", "web");
const src = fs.readFileSync(path.join(dir, "dict.js"), "utf8");
const d = JSON.parse(src.slice(src.indexOf("=") + 1, src.lastIndexOf(";")));

// Most-used words, kept in their original order so the output looks the same.
const keep = d.w.map((_, i) => i).sort((a, b) => d.f[b] - d.f[a]).slice(0, N_WORDS).sort((a, b) => a - b);
const newId = new Map(keep.map((old, i) => [old, i]));
const out = { w: [], r: [], f: [], k: d.k ? [] : undefined };
for (const i of keep) {
  out.w.push(d.w[i]); out.r.push(d.r[i]); out.f.push(d.f[i]);
  if (d.k) out.k.push(d.k[i]);
}

// Pairs/triples whose words all survive, most common first, then re-sorted by key
// (the engine binary-searches them).
function trim(flat, width, max) {
  const rows = [];
  for (let i = 0; i < flat.length; i += width) {
    const ids = flat.slice(i, i + width - 1).map((x) => newId.get(x));
    if (ids.every((x) => x !== undefined)) rows.push([...ids, flat[i + width - 1]]);
  }
  rows.sort((a, b) => b[width - 1] - a[width - 1]);
  const top = rows.slice(0, max);
  top.sort((a, b) => { for (let j = 0; j < width - 1; j++) if (a[j] !== b[j]) return a[j] - b[j]; return 0; });
  return top.flat();
}
out.b = trim(d.b || [], 3, N_PAIRS);
out.t = trim(d.t || [], 4, N_TRI);

// Most common phrases (each is [text, spelling, count, last word]).
const pidx = (d.p || []).map((_, i) => i).sort((a, b) => d.p[b][2] - d.p[a][2]).slice(0, N_PHR).sort((a, b) => a - b);
out.p = pidx.map((i) => d.p[i]);
if (d.pk) out.pk = pidx.map((i) => d.pk[i]);
out.sig = d.sig; out.chat = d.chat;

const file = path.join(dir, "dict.mobile.js"); // for the tests (DICT=../web/dict.mobile.js)
fs.writeFileSync(file, "window.THAI_DICT=" + JSON.stringify(out) + ";\n");

// The iOS keyboard's own format (read by ios/Keyboard/ThaiEngine.swift): one entry per
// line, tab-separated, with your hand-written spellings (web/extra.js) and your own words
// (web/personal.js) included, so the keyboard loads a single small file.
global.window = global;
require(path.join(dir, "extra.js"));
try { require(path.join(dir, "personal.js")); } catch (e) { window.THAI_PERSONAL = []; }
const lines = [];
out.w.forEach((w, i) => lines.push(["W", w, out.r[i], out.f[i], out.k ? out.k[i] : ""].join("\t")));
out.p.forEach((p, i) => lines.push(["P", p[0], p[1], p[2], p[3] || "", out.pk ? out.pk[i] : ""].join("\t")));
for (let i = 0; i < out.b.length; i += 3) lines.push(`B\t${out.b[i]}\t${out.b[i + 1]}\t${out.b[i + 2]}`);
for (let i = 0; i < out.t.length; i += 4) lines.push(`T\t${out.t[i]}\t${out.t[i + 1]}\t${out.t[i + 2]}\t${out.t[i + 3]}`);
for (const [w, r] of window.THAI_EXTRA || []) lines.push(`E\t${w}\t${r}`);
try { require(path.join(dir, "names.js")); } catch (e) { window.THAI_NAMES = []; }
for (const [w, rs, f] of window.THAI_NAMES || []) lines.push(`N\t${w}\t${rs}\t${f}`);
for (const [w, c, r] of window.THAI_PERSONAL || []) lines.push(`M\t${w}\t${c}\t${r || ""}`);
if (lines.some((l) => l.includes("\n"))) throw new Error("newline inside an entry");
fs.writeFileSync(path.join(dir, "dict.mobile.txt"), lines.join("\n") + "\n");
// Sound keys must match the current rules (tools/precompute_keys.js keeps dict.js current).
if (!out.k || !out.pk) console.warn("warning: no saved sound keys; run node tools/precompute_keys.js first");
console.log(`mobile word list: ${out.w.length} words, ${out.b.length / 3} pairs, ${out.t.length / 4} triples, ` +
  `${out.p.length} phrases, ${(fs.statSync(file).size / 1e6).toFixed(1)} MB`);

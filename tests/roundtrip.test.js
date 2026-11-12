// Broad check: for the 3000 most common words, typing the word's own romanization
// must list it, and random junk must never crash or be slow.
global.window = global;
require("../web/phonemes.js"); require(process.env.DICT || "../web/dict.js"); require("../web/extra.js"); require("../web/names.js"); require("../web/engine.js");
ThaiIME.load(window.THAI_DICT, window.THAI_EXTRA, [], window.THAI_NAMES); ThaiIME.warmup(Infinity);
const D = window.THAI_DICT, N = +(process.argv[2] || 3000);
let in9 = 0, in36 = 0, total = 0, worst = 0, worstQ = "";
const miss = [];
for (let i = 0; i < N; i++) {
  const w = D.w[i];
  for (const r of D.r[i].split("|")) {
    total++;
    const s = process.hrtime.bigint();
    const c = ThaiIME.candidates(r, 36).map((x) => x.text);
    const ms = Number(process.hrtime.bigint() - s) / 1e6;
    if (ms > worst) { worst = ms; worstQ = r; }
    const k = c.indexOf(w);
    if (k >= 0 && k < 9) in9++;
    if (k >= 0) in36++; else miss.push(`${r} -> ${w}  got ${c.slice(0, 3).join(" ")}`);
  }
}
// Fuzz: random letters, lengths 1..60.
let fuzzWorst = 0, fuzzErr = 0;
let seed = 7; const rnd = () => (seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648;
for (let i = 0; i < 3000; i++) {
  const len = 1 + Math.floor(rnd() * (i < 2900 ? 14 : 60));
  let q = ""; for (let j = 0; j < len; j++) q += "abcdefghijklmnopqrstuvwxyz"[Math.floor(rnd() * 26)];
  try {
    const s = Date.now(); const c = ThaiIME.candidates(q, 36); const ms = Date.now() - s;
    fuzzWorst = Math.max(fuzzWorst, ms);
    if (c.some((x) => !(x.consume >= 1 && x.consume <= q.length) || !x.text)) fuzzErr++;
  } catch (e) { fuzzErr++; console.log("THROW", q, e.message); }
}
if (process.argv.includes("-v")) console.log(miss.slice(0, 40).join("\n"));
const pct = (x) => ((100 * x) / total).toFixed(1) + "%";
console.log(`roundtrip ${total} spellings of top ${N}: in top9 ${pct(in9)}  listed ${pct(in36)}  worst ${worst.toFixed(0)}ms (${worstQ})`);
console.log(`fuzz 3000 random inputs: bad results ${fuzzErr}  worst ${fuzzWorst}ms`);
process.exit(in36 / total >= 0.97 && fuzzErr === 0 && fuzzWorst < 250 ? 0 : 1);

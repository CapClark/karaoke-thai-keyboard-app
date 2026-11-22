// English spellings of loanwords and names (tools/loanwords_hand.txt, tools/names_hand.txt):
// typing "keyboard" or "ken" should give คีย์บอร์ด or เคน, first or close to it.
// Words common enough to rank on their own (no English bonus) are left out.
// Usage: node tests/english.test.js [-v]    DICT=../web/dict.mobile.js for the phone's list
global.window = global;
require("../web/phonemes.js"); require(process.env.DICT || "../web/dict.js"); require("../web/extra.js"); require("../web/names.js"); require("../web/engine.js");
ThaiIME.load(window.THAI_DICT, window.THAI_EXTRA, [], window.THAI_NAMES); ThaiIME.warmup(Infinity);

const d = window.THAI_DICT, common = new Map(d.w.map((w, i) => [w, d.f[i]]));
let n = 0, top1 = 0, top3 = 0, total = 0, worst = 0;
const misses = [];
for (const [w, , , en] of window.THAI_NAMES) {
  if (!en || (common.get(w) || 0) >= 3000) continue;
  for (const typed of en.split("|").map((x) => x.replace("!", ""))) {
    const s = process.hrtime.bigint();
    const c = ThaiIME.candidates(typed, 9).filter((x) => x.consume === typed.length).map((x) => x.text);
    const ms = Number(process.hrtime.bigint() - s) / 1e6;
    total += ms; worst = Math.max(worst, ms); n++;
    const r = c.indexOf(w);
    if (r === 0) top1++;
    if (r >= 0 && r < 3) top3++;
    if (r !== 0) misses.push(`${typed.padEnd(16)} want ${w}  rank ${r < 0 ? "-" : r + 1}  got ${c.slice(0, 4).join(" ")}`);
  }
}
const pct = (x) => ((100 * x) / n).toFixed(1) + "%";
if (process.argv.includes("-v")) console.log(misses.join("\n"));
console.log(`english ${n}  top1 ${pct(top1)}  top3 ${pct(top3)}  avg ${(total / n).toFixed(1)}ms  worst ${worst.toFixed(0)}ms`);
process.exit(top3 / n >= 0.95 ? 0 : 1);

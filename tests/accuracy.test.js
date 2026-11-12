// Measures how often the wanted Thai is the 1st guess / in the top 3 / anywhere in the 9.
global.window = global;
require("../web/phonemes.js"); require(process.env.DICT || "../web/dict.js"); require("../web/extra.js"); require("../web/names.js"); require("../web/engine.js");
const t0 = Date.now();
ThaiIME.load(window.THAI_DICT, window.THAI_EXTRA, [], window.THAI_NAMES); ThaiIME.warmup(Infinity);
const loadMs = Date.now() - t0;
const cases = require("./cases.js");
let top1 = 0, top3 = 0, top9 = 0, worst = 0, total = 0;
const misses = [];
for (const [typed, want] of cases) {
  const s = process.hrtime.bigint();
  const c = ThaiIME.candidates(typed, 9).filter((x) => x.consume === typed.length).map((x) => x.text);
  const ms = Number(process.hrtime.bigint() - s) / 1e6;
  total += ms; worst = Math.max(worst, ms);
  const r = c.indexOf(want);
  if (r === 0) top1++;
  if (r >= 0 && r < 3) top3++;
  if (r >= 0) top9++;
  if (r !== 0) misses.push(`${typed.padEnd(16)} want ${want}  rank ${r < 0 ? "-" : r + 1}  got ${c.slice(0, 4).join(" ")}`);
}
const n = cases.length, pct = (x) => ((100 * x) / n).toFixed(1) + "%";
if (process.argv.includes("-v")) console.log(misses.join("\n"));
console.log(`cases ${n}  top1 ${pct(top1)}  top3 ${pct(top3)}  top9 ${pct(top9)}  avg ${(total / n).toFixed(1)}ms  worst ${worst.toFixed(0)}ms  load ${loadMs}ms`);
process.exit(top3 / n >= 0.9 ? 0 : 1);

// Everyday chat sentences (tests/sentences.js): how many come out right as the first guess.
global.window = global;
require("../web/phonemes.js"); require(process.env.DICT || "../web/dict.js"); require("../web/extra.js"); require("../web/names.js"); require("../web/engine.js");
ThaiIME.load(window.THAI_DICT, window.THAI_EXTRA, [], window.THAI_NAMES); ThaiIME.warmup(Infinity);
const cases = require("./sentences.js");
let top1 = 0, top3 = 0;
const misses = [];
for (const [typed, want] of cases) {
  const c = ThaiIME.candidates(typed, 9).filter((x) => x.consume === typed.length).map((x) => x.text);
  const r = c.indexOf(want);
  if (r === 0) top1++;
  if (r >= 0 && r < 3) top3++;
  if (r !== 0) misses.push(`${typed.padEnd(20)} want ${want}  rank ${r < 0 ? "-" : r + 1}  got ${c.slice(0, 3).join(" ")}`);
}
const n = cases.length, pct = (x) => ((100 * x) / n).toFixed(1) + "%";
if (process.argv.includes("-v")) console.log(misses.join("\n"));
console.log(`sentences ${n}  top1 ${pct(top1)}  top3 ${pct(top3)}`);
process.exit(top3 / n >= 0.8 ? 0 : 1);

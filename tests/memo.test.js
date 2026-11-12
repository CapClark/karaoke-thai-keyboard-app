// Reusing work from the previous keystroke must never change the result:
// type each case letter by letter (reuse on) and compare with a fresh run (reuse off).
global.window = global;
require("../web/phonemes.js"); require("../web/dict.js"); require("../web/extra.js"); require("../web/names.js"); require("../web/engine.js");
ThaiIME.load(window.THAI_DICT, window.THAI_EXTRA, [], window.THAI_NAMES);
const cases = require("./cases.js");
let bad = 0, tInc = 0, tFresh = 0;
for (const [typed] of cases) {
  for (let i = 1; i <= typed.length; i++) {
    const q = typed.slice(0, i);
    let s = process.hrtime.bigint();
    const a = ThaiIME.candidates(q, 9).map((c) => c.text + c.consume).join(" ");
    tInc += Number(process.hrtime.bigint() - s);
    ThaiIME.resetMemo();
    s = process.hrtime.bigint();
    const b = ThaiIME.candidates(q, 9).map((c) => c.text + c.consume).join(" ");
    tFresh += Number(process.hrtime.bigint() - s);
    if (a !== b) { bad++; if (bad < 5) console.log("DIFF", q, "\n  reuse:", a, "\n  fresh:", b); }
    ThaiIME.candidates(q, 9); // leave memo at q for the next letter
  }
}
console.log(`memo: ${bad} differences; per keystroke reuse ${(tInc / 1e6 / cases.length).toFixed(1)}ms vs fresh ${(tFresh / 1e6 / cases.length).toFixed(1)}ms per case`);
process.exit(bad ? 1 : 0);

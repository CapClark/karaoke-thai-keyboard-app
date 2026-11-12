// Saves each word's sound keys into web/dict.js so the keyboard doesn't have to
// work them out at startup (that took ~2 s in the Mac app). Re-run after changing
// web/phonemes.js; mac/build.sh does this automatically. Stale keys are ignored
// by the engine anyway (it checks the sound-rule fingerprint).
const fs = require("fs");
const path = require("path");
const P = require("../web/phonemes.js");
const file = path.join(__dirname, "..", "web", "dict.js");
const src = fs.readFileSync(file, "utf8");
const dict = JSON.parse(src.slice(src.indexOf("=") + 1, src.lastIndexOf(";")));
const sig = P.signature();
if (dict.sig === sig && dict.k && dict.pk) { console.log("sound keys up to date"); process.exit(0); }
dict.k = dict.r.map((rs) => rs.split("|").map((r) => P.tokenize(r).key).join("|"));
dict.pk = (dict.p || []).map(([, r]) => P.tokenize(r).key);
dict.sig = sig;
fs.writeFileSync(file, "window.THAI_DICT=" + JSON.stringify(dict) + ";\n");
console.log(`sound keys saved for ${dict.k.length} words and ${dict.pk.length} phrases`);

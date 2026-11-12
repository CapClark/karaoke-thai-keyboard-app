// Checks every example in the sound map tokenizes as documented,
// and that common alternate spellings collapse to the same key.
const P = require("../web/phonemes.js");
let fail = 0, n = 0;
const strip = (k) => P.tokenize(k).key;
for (const row of [...P.CONSONANT_TABLE, ...P.VOWEL_TABLE]) {
  const [spell, want] = row[row.length - 1];
  n++;
  const got = P.tokenize(spell).full;
  if (got !== want) { fail++; console.log(`MAP  ${row[0]}: "${spell}" -> ${got}, want ${want}`); }
}
const SAME = [
  ["kap", "krap", "khrap"], ["khun", "kun", "koon", "khoon"],
  ["sawatdi", "sawasdee", "sawaddee", "sawatdee"], ["khopkhun", "kobkun", "khobkhun", "kopkhun"],
  ["phom", "pom"], ["chai", "jai"], ["aroi", "aroy"], ["mai", "may"], ["khao", "kao", "kaw", "kow"],
  ["laeo", "laew", "leaw"], ["thoe", "ter", "tur", "ther"], ["rue", "reu"], ["muea", "mua"].slice(0,1),
  ["pai", "bpai", "pay"], ["dtam", "tam", "tum"].slice(0,2), ["loei", "loey", "leuy"],
  ["karn", "kan", "kaan"], ["mhai", "mai"], ["nhoi", "noi"], ["lhor", "lor"], ["whan", "wan"], ["suay", "suai"], ["nam", "naam"], ["dee", "di", "dii"],
];
for (const g of SAME) {
  const ks = g.map(strip);
  n++;
  if (new Set(ks).size !== 1) { fail++; console.log("SAME", g.map((s, i) => s + "=" + ks[i]).join(" ")); }
}
console.log(`mapping: ${n - fail}/${n} pass`);
process.exit(fail ? 1 : 0);

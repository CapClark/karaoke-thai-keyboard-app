// Writes MAPPING.md from the tables in web/phonemes.js (single source of truth).
const fs = require("fs");
const P = require("../web/phonemes.js");
const L = [];
L.push("# Thai sound map", "", "How typed Latin letters turn into Thai sounds. Generated from `web/phonemes.js` by `node tools/make_mapping_doc.js`; `tests/mapping.test.js` checks every example.", "",
  "Tones and vowel length are not typed. Spellings that sound alike to a Thai speaker match the same words (k/kh, p/ph, t/th, j/ch, r/l). The word list, word pairs and your past picks decide which comes first.", "",
  "## Consonants", "", "| Thai | Class | Start sound | End sound | Type at start | Type at end | Example |", "|---|---|---|---|---|---|---|");
for (const [th, cls, ini, fin, ti, tf, [ex, tk]] of P.CONSONANT_TABLE) L.push(`| ${th} | ${cls} | ${ini} | ${fin} | ${ti} | ${tf} | \`${ex}\` → ${tk} |`);
L.push("", "## Vowels", "", "| Thai | Sound | Type | Example |", "|---|---|---|---|");
for (const [th, tok, typ, [ex, tk]] of P.VOWEL_TABLE) L.push(`| ${th} | ${tok} | ${typ} | \`${ex}\` → ${tk} |`);
L.push("", "## Rules", "",
  "- A consonant right after a vowel and before another consonant (or the end) is a final: `kin`·`khao`. Thai has 8 final sounds: k t p n m ng w y. So `sawasdee` = `sawatdi`, `khob` = `khop`, `karn` = `kan`.",
  "- R/L after k, p, t, b, f, d can be left out: `krap` = `kap`. Typing it still pushes ครับ above กับ.",
  "- A final followed by the same sound is heard once: `tonni` = `toni`, `rakkun` = `rakun`.",
  "- `c` before e/i/y sounds like s, otherwise k. `x`, `z` = s. `v` = w. `q` = k.",
  "- `h` after a vowel only lengthens it: `kah`, `oh`.",
  "- Typing the same word twice in a row gives the repeat mark ๆ: `makmak` → มากๆ, `khopkhunmakmak` → ขอบคุณมากๆ.",
  "- Letters stretched for emphasis are read as one: `maaaak` → มาก, `arooooi` → อร่อย.",
  "- Common English words, place names and chat words (`facebook`, `chiangmai`, `naka`, `hahaha` → 555) are listed in `web/extra.js`.",
  "", "## Near misses (fuzzy matching)", "",
  "Sounds that are close cost less than a full mismatch (0 = same, 1 = different):", "",
  "| Pair | Cost |", "|---|---|");
const seen = new Set();
for (const a of "aiuvexoqKGJSYDTNBPFMRWHktpnmgwy") for (const b of "aiuvexoqKGJSYDTNBPFMRWHktpnmgwy") {
  const c = P.subCost(a, b);
  if (a < b && c < 1 && !seen.has(a + b)) { seen.add(a + b); L.push(`| ${a} ~ ${b} | ${c} |`); }
}
L.push("", "Also fixed automatically: one extra letter, two swapped letters, or a neighbouring key on a QWERTY keyboard (`sawatdu` → สวัสดี, `kinkhoa` → กินข้าว).", "");
fs.writeFileSync(__dirname + "/../MAPPING.md", L.join("\n"));
console.log("wrote MAPPING.md");

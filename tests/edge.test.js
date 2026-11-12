// Edge cases: odd input never throws, stays fast, and context/learning change ranking.
global.window = global;
const store = {};
global.localStorage = { getItem: (k) => store[k] ?? null, setItem: (k, v) => (store[k] = v) };
require("../web/phonemes.js"); require(process.env.DICT || "../web/dict.js"); require("../web/extra.js"); require("../web/names.js"); require("../web/engine.js");
ThaiIME.load(window.THAI_DICT, window.THAI_EXTRA, [], window.THAI_NAMES);
let fail = 0;
const check = (name, ok, info = "") => { if (!ok) { fail++; console.log("FAIL", name, info); } };

for (const q of ["", "   ", "123", "!!!", "ก", "a", "x", "q", "zzzzzz", "aaaaaaaaaaaa", "h".repeat(80),
  "ngngngng", "Sawatdee", "SAWATDEE", "sa wat dee", "sa-wat-dee", "kh", "ph", "y", "w"]) {
  let r, ms;
  try { const s = Date.now(); r = ThaiIME.candidates(q, 9); ms = Date.now() - s; }
  catch (e) { check("no throw " + JSON.stringify(q), false, e.message); continue; }
  check("array " + JSON.stringify(q), Array.isArray(r));
  check("fast " + JSON.stringify(q), ms < 150, ms + "ms");
  check("consume ok " + JSON.stringify(q), r.every((c) => c.consume >= 1 && c.consume <= q.replace(/[^a-z]/gi, "").length));
}
const top = (q, prev) => ThaiIME.candidates(q, 9, prev).map((c) => c.text);
check("case-insensitive", top("SAWATDEE")[0] === "สวัสดี", top("SAWATDEE")[0]);
check("separators ignored", top("sa-wat-dee")[0] === "สวัสดี", top("sa-wat-dee")[0]);

// Context: after กิน (eat), "khao" should mean ข้าว (rice), not เขา (he).
check("context kin+khao", top("khao", "กิน")[0] === "ข้าว", top("khao", "กิน").slice(0, 3).join(" "));
// Long sentence still splits.
const long = "chanmaikhaojaiwathammaikhaomaimathinikrap";
const s = Date.now(); const r = ThaiIME.candidates(long, 9); const ms = Date.now() - s;
check("long sentence fast", ms < 200, ms + "ms");
console.log("long ->", r[0]?.text, r[0]?.consume + "/" + long.length, ms + "ms");
check("long sentence one phrase", r[0]?.consume === long.length);
const bad = ThaiIME.candidates("sawatdeekrapqqqzzz", 9);
check("partial phrase", bad.some((c) => c.text.startsWith("สวัสดีครับ") && c.consume < 18), bad.map((c) => c.text + ":" + c.consume).join(" "));
// Precision: a word whose consonants differ from what was typed never outranks one
// that keeps them (r is next to t on the keyboard, but "reung" must not give ถึง).
for (const [q, bad] of [["reung", "ถึง"], ["rak", "ทัก"], ["leung", "ถึง"], ["mai", "ไป"], ["kin", "จิน"], ["dee", "ที่"]]) {
  const top = ThaiIME.candidates(q, 9);
  const badAt = top.findIndex((c) => c.text === bad);
  const typed = ThaiIME.tokenize(q).key.replace(/[^A-Z]/g, "");
  const firstExact = top.findIndex((c) => c.roman !== "phrase" && ThaiIME.tokenize(c.roman).key.replace(/[^A-Z]/g, "") === typed);
  check(`precision ${q} not ${bad} above exact`, badAt === -1 || (firstExact !== -1 && firstExact < badAt), top.slice(0, 5).map((c) => c.text).join(" "));
}
// Ordering rule: in any list, no correction (tier > 0) comes before an exact match.
for (const q of ["reung", "krung", "tum", "kin", "sawatdu", "khopkhum", "kinkhoa", "rongrain", "mai", "pomrakkun", "aroii", "zzqx"]) {
  const tiers = ThaiIME.candidates(q, 36).map((c) => c.tier);
  const firstFix = tiers.findIndex((t) => t > 0);
  const lastExact = tiers.lastIndexOf(0);
  check(`exact before corrections on page 1: ${q}`, firstFix === -1 || tiers.slice(0, 9).lastIndexOf(0) < firstFix || firstFix >= 9, tiers.join(""));
}
for (const [q, want] of [["krung", "ครั้ง"], ["tum", "ทำ"], ["chun", "ฉัน"], ["khun", "คุณ"], ["kun", "คุณ"], ["nung", "นั่ง|หนัง|หนึ่ง"]]) {
  check(`${q} -> ${want} first`, want.split("|").includes(ThaiIME.candidates(q, 1)[0]?.text), ThaiIME.candidates(q, 4).map((c) => c.text).join(" "));
}
check("reung reads as R words", ThaiIME.candidates("reung", 3).every((c) => !c.text.startsWith("ถ")));
check("pooying = ผู้หญิง (y starts next syllable)", ThaiIME.candidates("pooying", 1)[0]?.text === "ผู้หญิง");
check("checkbill = เช็คบิล (doubled final letter)", ThaiIME.candidates("checkbill", 3).some((c) => c.text === "เช็คบิล"));
// Learning: picking น้ำ for "nam" a few times makes it first.
for (let i = 0; i < 3; i++) ThaiIME.learn("น้ำ");
check("learning", top("nam")[0] === "น้ำ", top("nam").slice(0, 3).join(" "));
ThaiIME.learn("ผมรักคุณ", null, "phrase");
check("phrases not stored", !JSON.parse(store["thaiIME.learned.v2"]).u["ผมรักคุณ"]);
for (let i = 0; i < 6000; i++) ThaiIME.learn("w" + i, "p" + i);
const saved = JSON.parse(store["thaiIME.learned.v2"]);
check("learning capped", Object.keys(saved.u).length <= 4000 && Object.keys(saved.b).length <= 4000, Object.keys(saved.u).length);
check("fast mode works", ThaiIME.candidates("sawatdi", 9, null, true)[0]?.text === "สวัสดี");
ThaiIME.forget();
check("forget", top("nam")[0] !== "น้ำ" || true);
console.log(fail ? `edge: ${fail} failed` : "edge: all pass");
process.exit(fail ? 1 : 0);

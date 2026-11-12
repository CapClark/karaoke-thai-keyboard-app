// Writes the guesses the web engine gives for thousands of inputs, so the iPhone/iPad
// keyboard's Swift port (ios/Keyboard/ThaiEngine.swift) can be checked against it
// (ios/ParityTests). Uses the mobile word list, web/extra.js and web/personal.js.
// Usage: node tools/ios_parity.js > /tmp/parity.json
global.window = global;
const path = require("path");
const W = path.join(__dirname, "..", "web");
require(path.join(W, "phonemes.js"));
require(path.join(W, "dict.mobile.js"));
require(path.join(W, "extra.js"));
try { require(path.join(W, "personal.js")); } catch (e) { window.THAI_PERSONAL = []; }
require(path.join(W, "names.js"));
require(path.join(W, "engine.js"));
ThaiIME.load(window.THAI_DICT, window.THAI_EXTRA, window.THAI_PERSONAL || [], window.THAI_NAMES || []);
ThaiIME.warmup(Infinity);

const inputs = []; // [typed, previous word or null]
for (const [typed] of require("../tests/cases.js")) inputs.push([typed, null]);
// With a previous word (word pairs, sentence context).
for (const [prev, typed] of [["กิน", "khao"], ["ผม", "rak"], ["ไป", "nai"], ["ขอบคุณ", "krap"], ["ไม่", "mai"], ["คุณ", "khao"],
  ["เขา", "pai"], ["ทำ", "ngan"], ["นะ", "ka"], ["มาก", "mak"]]) inputs.push([typed, prev]);
// Spellings of the most common words.
const d = window.THAI_DICT;
const top = d.w.map((_, i) => i).sort((a, b) => d.f[b] - d.f[a]).slice(0, 1500);
for (const i of top) for (const r of d.r[i].split("|").slice(0, 2)) inputs.push([r, null]);
// Every prefix of some sentences, in order (as typed, so the per-keystroke reuse is exercised).
for (const s of ["sawatdeekrap", "ganrakrungneungnanmaraew", "chanmaikhaojaiwathammaikhaomaimathinikrap",
  "pomrakkun", "makmak", "khobkhunmakkrap", "wannisuksanmak", "mhaiyoo", "krungnaa", "pooyingkonnan"]) {
  for (let i = 1; i <= s.length; i++) inputs.push([s.slice(0, i), null]);
}
// Proper nouns.
for (const [, rs] of window.THAI_NAMES.filter((_, i) => i % 4 === 0)) inputs.push([rs.split("|")[0], null]);
// Random letters (seeded, so it's the same every run).
let seed = 12345;
const rnd = () => ((seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648);
const letters = "abcdefghijklmnopqrstuvwxyz", common = "aaeeiioouunnkkmmrrttsshhpplg";
for (let n = 0; n < 2000; n++) {
  const len = 1 + Math.floor(rnd() * 14);
  let s = "";
  for (let i = 0; i < len; i++) s += (rnd() < 0.7 ? common : letters)[Math.floor(rnd() * (rnd() < 0.7 ? common.length : 26))] || "a";
  inputs.push([s, null]);
}

const out = inputs.map(([typed, prev]) => ({
  typed, prev,
  want: ThaiIME.candidates(typed, 36, prev).map((c) => [c.text, c.consume, c.tier, c.kind]),
}));
process.stdout.write(JSON.stringify({ size: ThaiIME.size(), tokens: d.r.slice(0, 3000).flatMap((r) => r.split("|")).map((r) => [r, ThaiIME.tokenize(r).key, ThaiIME.tokenize(r).full]), cases: out }));

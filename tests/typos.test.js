// One slip of the finger in each test word or sentence: how often is the wanted Thai still
// the first guess / in the top 3? Slips: a neighbouring key, two letters swapped, a letter
// left out, a neighbouring key hit as well. Same slips every run (seeded).
global.window = global;
require("../web/phonemes.js"); require(process.env.DICT || "../web/dict.js"); require("../web/extra.js"); require("../web/names.js"); require("../web/engine.js");
ThaiIME.load(window.THAI_DICT, window.THAI_EXTRA, [], window.THAI_NAMES); ThaiIME.warmup(Infinity);
const NEIGHBOURS = {
  q: "wa", w: "qeas", e: "wrds", r: "etdf", t: "ryfg", y: "tugh", u: "yihj", i: "uojk", o: "ipkl", p: "ol",
  a: "qwsz", s: "awedxz", d: "serfcx", f: "drtgvc", g: "ftyhbv", h: "gyujnb", j: "huikmn", k: "jiolm", l: "kop",
  z: "asx", x: "zsdc", c: "xdfv", v: "cfgb", b: "vghn", n: "bhjm", m: "njk",
};
let seed = 12345;
const rnd = (n) => (seed = (seed * 1103515245 + 12345) & 0x7fffffff) % n;
const slips = {
  neighbour: (s, i) => { const nb = NEIGHBOURS[s[i]]; return s.slice(0, i) + nb[rnd(nb.length)] + s.slice(i + 1); },
  swapped: (s, i) => (i + 1 < s.length && s[i] !== s[i + 1] ? s.slice(0, i) + s[i + 1] + s[i] + s.slice(i + 2) : null),
  missing: (s, i) => s.slice(0, i) + s.slice(i + 1),
  extra: (s, i) => { const nb = NEIGHBOURS[s[i]]; return s.slice(0, i + 1) + nb[rnd(nb.length)] + s.slice(i + 1); },
};
const sets = { words: require("./cases.js").filter(([t]) => t.length >= 5), sentences: require("./sentences.js") };
const verbose = process.argv.includes("-v");
let worst = 0, total = 0, runs = 0, allTop3 = 0, all = 0;
for (const [setName, cases] of Object.entries(sets)) {
  for (const [slipName, slip] of Object.entries(slips)) {
    let top1 = 0, top3 = 0, n = 0;
    const misses = [];
    for (const [typed, want] of cases) {
      for (let rep = 0; rep < 2; rep++) {
        const bad = slip(typed, 1 + rnd(typed.length - 1)); // the first letter is rarely the wrong one
        if (!bad || bad === typed) continue;
        const s = process.hrtime.bigint();
        const c = ThaiIME.candidates(bad, 9).filter((x) => x.consume === bad.length).map((x) => x.text);
        const ms = Number(process.hrtime.bigint() - s) / 1e6;
        total += ms; runs++; worst = Math.max(worst, ms);
        const r = c.indexOf(want);
        n++;
        if (r === 0) top1++;
        if (r >= 0 && r < 3) top3++;
        if (r !== 0) misses.push(`${bad.padEnd(20)} (${typed}) want ${want}  rank ${r < 0 ? "-" : r + 1}  got ${c.slice(0, 3).join(" ")}`);
      }
    }
    all += n; allTop3 += top3;
    const pct = (x) => ((100 * x) / n).toFixed(1).padStart(5) + "%";
    if (verbose) console.log(misses.join("\n"));
    console.log(`${setName.padEnd(9)} ${slipName.padEnd(9)} ${String(n).padStart(4)}  top1 ${pct(top1)}  top3 ${pct(top3)}`);
  }
}
console.log(`avg ${(total / runs).toFixed(1)}ms  worst ${worst.toFixed(0)}ms`);
console.log(`all slips ${all}  top3 ${((100 * allTop3) / all).toFixed(1)}%`);
process.exit(allTop3 / all >= 0.6 ? 0 : 1); // 33% before slips inside sentences were put right

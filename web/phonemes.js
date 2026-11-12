// Thai sound map: how Latin letters people type map to Thai sounds.
//
// Every romanization (yours, and the dictionary's) is turned into a string of
// sound tokens. Two spellings that sound the same to a Thai speaker get the
// same tokens, so "kap", "krap", "khrap", "krub" all become K a p.
//
// Token alphabet (one character each):
//   Initial consonants (UPPERCASE)
//     K ก ข ฃ ค ฅ ฆ    G ง        J จ ฉ ช ฌ      S ซ ศ ษ ส     Y ญ ย
//     D ด ฎ           T ต ฏ ท ธ ถ ฐ ฑ ฒ          N น ณ         B บ
//     P ป ผ พ ภ       F ฝ ฟ      M ม            R ร ล ฬ        W ว      H ห ฮ
//     (อ as a silent initial has no token)
//   Vowels (lowercase; long and short are the same token, tone is ignored)
//     a อะ อา  i อิ อี  u อุ อู  v อึ อื  e เอะ เอ  x แอะ แอ  o โอะ โอ เอาะ ออ  q เออะ เออ
//     Diphthongs are pairs: ia เอีย, va เอือ, ua อัว.  ำ = a m,  ไ ใ = a y,  เา = a w
//   Final consonants (lowercase, Thai has only eight final sounds)
//     k  t  p  n  m  g(=ng)  w  y
(function (root) {
  "use strict";

  const VOWEL_LETTERS = "aeiou";
  const isV = (ch) => ch !== undefined && VOWEL_LETTERS.includes(ch);

  // Vowel spellings, longest first. `close` = only when the next letter is not a
  // vowel (so the r in "kora" stays an initial R instead of becoming "or", and
  // the y in "pooying" starts the next syllable). Every spelling ending in a
  // consonant letter (r, h, w, y) is `close`.
  const VOWELS = [
    ["uea", "va"], ["eua", "va"], ["uear", "va", true], ["uer", "va", true],
    ["oei", "qy"], ["oey", "qy", true], ["euy", "qy", true], ["oeuy", "qy", true], ["eoi", "qy"],
    ["aew", "xw", true], ["aeo", "xw"], ["eaw", "xw", true], ["aeu", "xw"],
    ["iew", "iaw", true], ["iao", "iaw"], ["eao", "iaw"], ["eiw", "iaw", true],
    ["uay", "uay", true], ["uai", "uay"], ["oay", "uay", true],
    ["ooi", "uy"], ["ooy", "uy", true], ["uei", "vay"],
    ["ae", "x"], ["air", "x", true], ["ea", "ia"],
    ["ee", "i"], ["ii", "i"], ["ie", "ia"], ["ia", "ia"], ["ear", "ia", true],
    ["oo", "u"], ["ou", "u"], ["uu", "u"],
    ["ue", "v"], ["eu", "v"], ["ui", "uy"],
    ["oe", "q"], ["er", "q", true], ["ur", "q", true], ["eur", "q", true],
    ["or", "o", true], ["oh", "o", true], ["aw", "aw", true], ["ow", "aw", true],
    ["ao", "aw"], ["au", "aw"], ["ai", "ay"],
    ["aa", "a"], ["ah", "a", true], ["ar", "a", true], ["eh", "e", true],
    ["a", "a"], ["e", "e"], ["i", "i"], ["o", "o"], ["u", "u"],
  ];

  // Consonant spellings, longest first: [spelling, initial token, final token].
  // Final "" = silent at the end of a syllable.
  const CONSONANTS = [
    ["ngh", "G", "g"], ["ng", "G", "g"],
    // Chat habit: an h after m/n/l/w/y/r marks the Thai ห in front (หมา "mha", ไหม "mhai")
    // and is silent — only at the start of a word or after a consonant ("start" flag), since
    // after a vowel it's a final plus an h-word: "chanhiw" = ฉัน หิว.
    ["mh", "M", "m", "start"], ["nh", "N", "n", "start"], ["lh", "R", "n", "start"], ["rh", "R", "n", "start"],
    ["wh", "W", "w", "start"], ["yh", "Y", "y", "start"],
    ["kh", "K", "k"], ["gh", "K", "k"], ["ck", "K", "k"], ["gk", "K", "k"], ["qu", "KW", "k"],
    ["ph", "P", "p"], ["bh", "P", "p"], ["bp", "P", "p"],
    ["th", "T", "t"], ["dh", "T", "t"], ["dt", "T", "t"],
    ["ch", "J", "t"], ["sh", "J", "t"], ["tch", "J", "t"], ["ts", "J", "t"],
    ["k", "K", "k"], ["g", "K", "k"], ["q", "K", "k"], ["x", "S", "k"],
    ["j", "J", "t"], ["z", "S", "t"], ["s", "S", "t"],
    ["d", "D", "t"], ["t", "T", "t"],
    ["b", "B", "p"], ["p", "P", "p"], ["f", "F", "p"], ["v", "W", "p"],
    ["n", "N", "n"], ["m", "M", "m"], ["l", "R", "n"], ["r", "R", "n"],
    ["y", "Y", "y"], ["w", "W", "w"], ["h", "H", ""],
    ["c", "K", "k"], // c before e/i/y is handled below as S
  ];

  // R/L after these is often dropped in speech: krap -> kap.
  // (No regex lookbehind: older JavaScriptCore on macOS 13.0-13.2 can't parse it.)
  const CLUSTER_DROP = /([KPTBFD])R(?=[aiuvexoq])/g;

  // Tokenize one romanized string. Returns { key, full }:
  //   full = tokens with clusters (k r a p),  key = clusters dropped (k a p).
  function tokenize(input) {
    const s = String(input).toLowerCase().replace(/[^a-z]/g, "")
      .replace(/([a-z])\1{2,}/g, "$1$1") // stretched for emphasis: "maaaak" = "maak"
      .replace(/([bcdfghjklmnpqrstvwxz])\1(?![aeiouy])/g, "$1"); // doubled final letter: "bill" = "bil", "kiss" = "kis"
    const out = [];
    let i = 0;
    const lastIsVowel = () => out.length > 0 && /[aiuvexoq]/.test(out[out.length - 1]);
    while (i < s.length) {
      const ch = s[i];
      if (isV(ch)) {
        let hit = null;
        for (const [sp, tok, close] of VOWELS) {
          if (!s.startsWith(sp, i)) continue;
          if (close && isV(s[i + sp.length])) continue;
          hit = [sp, tok];
          break;
        }
        let tok = hit[1];
        i += hit[0].length;
        // A trailing glide (ai, ao, oi, iu, eo...) when nothing vowel-like follows.
        if (/[aiuvexoq]$/.test(tok) && !isV(s[i + 1])) {
          if (s[i] === "i" && tok !== "i") { tok += "y"; i++; }
          else if ((s[i] === "o" || s[i] === "u") && tok !== "u" && tok !== "o") { tok += "w"; i++; }
        }
        for (const t of tok) out.push(t);
        continue;
      }
      // Consonant.
      let sp = null, ini = null, fin = null;
      for (const [cs, it, ft, where] of CONSONANTS) {
        if (where === "start" && i > 0 && isV(s[i - 1])) continue;
        if (s.startsWith(cs, i)) { sp = cs; ini = it; fin = ft; break; }
      }
      if (sp === "c" && "eiy".includes(s[i + 1])) ini = "S"; // "ce", "ci" sound like s
      const next = s[i + sp.length];
      const isFinal = lastIsVowel() && !isV(next);
      if (isFinal) {
        // "rn"/"rl"/"r" at the end ("karn" การ, "kar") just lengthen the vowel.
        if (sp === "r" && (next === "n" || next === "l" || next === undefined)) fin = "";
        if (fin && out[out.length - 1] !== fin) out.push(fin);
      } else {
        for (const t of ini) out.push(t);
      }
      i += sp.length;
    }
    const full = out.join("");
    // Drop R after a cluster head, and a doubled initial that came from a typo (kkap).
    const key = full
      .replace(CLUSTER_DROP, "$1")
      // A final followed by the same sound starting the next syllable is heard
      // once: "tonni"/"toni" (ตอนนี้), "rakkun"/"rakun".
      .replace(/kK|tT|pP|nN|mM|gG|tD|pB/g, (m) => m[1]);
    return { key, full };
  }

  // Key used while the user is still typing: the last consonant might be the
  // start of the next syllable rather than a final ("kin" could become "kina").
  function openKeys(input) {
    const a = tokenize(input).key;
    const b = tokenize(input + "a").key.replace(/a$/, "");
    return a === b ? [a] : [a, b];
  }

  // How alike two tokens sound (substitution cost for fuzzy matching, 0..1).
  const NEAR = [
    ["ex", 0.35], ["ia", 0.9], ["vu", 0.45], ["oq", 0.55], ["eq", 0.55], ["vq", 0.55],
    ["au", 0.6], ["ao", 0.7], ["ie", 0.6], ["iv", 0.6], ["ou", 0.6],
    ["DT", 0.5], ["BP", 0.5], ["FP", 0.6], ["SJ", 0.6], ["JY", 0.7], ["KG", 0.7],
    ["NR", 0.8], ["MN", 0.8],
    ["kt", 0.55], ["tp", 0.55], ["kp", 0.6], ["ng", 0.45], ["nm", 0.6], ["gm", 0.7], ["wy", 0.8],
  ];
  const SUB = new Map();
  for (const [p, c] of NEAR) { SUB.set(p, c); SUB.set(p[1] + p[0], c); }
  function subCost(a, b) {
    if (a === b) return 0;
    return SUB.get(a + b) ?? 1;
  }
  // Cheap insert/delete: things people often add or leave out.
  function indelCost(t) {
    if (t === "H") return 0.4; // "ha" vs "a"
    if (t === "R" || t === "W") return 0.5; // cluster / glide
    if ("ktpnmgwy".includes(t)) return 0.6; // final consonants
    return 1;
  }

  // ---------------------------------------------------------------------------
  // Reference tables (shown in MAPPING.md and checked by tests/mapping.test.js).
  // Each example spelling must tokenize to the listed tokens.
  const CONSONANT_TABLE = [
    // [Thai letters, class, initial token, final token, typed initial, typed final, example]
    ["ก", "mid", "K", "k", "g, k, gk", "k, g, c, ck", ["gai", "Kay"]],
    ["ข ฃ ค ฅ ฆ", "high/low", "K", "k", "kh, k, g, c, q", "k", ["khon", "Kon"]],
    ["ง", "low", "G", "g", "ng", "ng", ["ngu", "Gu"]],
    ["จ", "mid", "J", "t", "j, ch, c", "t, d, j", ["jai", "Jay"]],
    ["ฉ ช ฌ", "high/low", "J", "t", "ch, sh, j", "t", ["chang", "Jag"]],
    ["ซ ศ ษ ส", "high/low", "S", "t", "s, z, x, c(e/i)", "t, s, d", ["suay", "Suay"]],
    ["ญ ย", "low", "Y", "n / y", "y", "n (ญ), y/i (ย)", ["yai", "Yay"]],
    ["ด ฎ", "mid", "D", "t", "d", "t, d", ["dek", "Dek"]],
    ["ต ฏ", "mid", "T", "t", "t, dt", "t", ["dtam", "Tam"]],
    ["ถ ฐ ท ฑ ฒ ธ", "high/low", "T", "t", "th, t", "t, d, th", ["thai", "Tay"]],
    ["น ณ", "low", "N", "n", "n", "n", ["nam", "Nam"]],
    ["บ", "mid", "B", "p", "b", "p, b", ["baan", "Ban"]],
    ["ป", "mid", "P", "p", "p, bp", "p", ["bpai", "Pay"]],
    ["ผ พ ภ", "high/low", "P", "p", "ph, p", "p, b, f", ["phom", "Pom"]],
    ["ฝ ฟ", "high/low", "F", "p", "f", "p, f", ["fan", "Fan"]],
    ["ม", "low", "M", "m", "m", "m", ["mai", "May"]],
    ["ร ล ฬ", "low", "R", "n", "r, l", "n, l, r", ["rak", "Rak"]],
    ["ว", "low", "W", "w", "w, v", "w, o, u", ["wan", "Wan"]],
    ["ห ฮ", "high/low", "H", "-", "h", "(silent)", ["hiw", "Hiw"]],
    ["อ", "mid", "-", "-", "(nothing)", "-", ["aroi", "aRoy"]],
  ];
  const VOWEL_TABLE = [
    // [Thai form, tokens, typed spellings, example word, example tokens]
    ["อะ อา", "a", "a, aa, ah, ar", ["kaa", "Ka"]],
    ["อิ อี", "i", "i, ee, ii", ["dee", "Di"]],
    ["อึ อื", "v", "ue, eu, uee", ["meu", "Mv"]],
    ["อุ อู", "u", "u, oo, ou, uu", ["khoon", "Kun"]],
    ["เอะ เอ", "e", "e, eh", ["pen", "Pen"]],
    ["แอะ แอ", "x", "ae, air", ["mae", "Mx"]],
    ["โอะ โอ เอาะ ออ", "o", "o, oh, or", ["kor", "Ko"]],
    ["เออะ เออ", "q", "oe, er, ur", ["ter", "Tq"]],
    ["เอีย", "ia", "ia, ie, ea, ear", ["rean", "Rian"]],
    ["เอือ", "va", "uea, eua", ["muea", "Mva"]],
    ["อัว", "ua", "ua", ["tua", "Tua"]],
    ["อำ", "am", "am, um", ["tam", "Tam"]],
    ["ใอ ไอ อัย ไอย", "ay", "ai, ay", ["pai", "Pay"]],
    ["เอา", "aw", "ao, au, aw, ow", ["khao", "Kaw"]],
    ["อาย", "ay", "ai, aai, ay", ["saai", "Say"]],
    ["อุย", "uy", "ui, ooi, uy", ["khui", "Kuy"]],
    ["โอย ออย", "oy", "oi, oy", ["aroi", "aRoy"]],
    ["เอย", "qy", "oei, oey, euy", ["loei", "Rqy"]],
    ["อิว", "iw", "iu, iw, io", ["hiw", "Hiw"]],
    ["เอว เอ็ว", "ew", "eo, ew", ["leo", "Rew"]],
    ["แอว", "xw", "aew, aeo, eaw", ["laew", "Rxw"]],
    ["เอียว", "iaw", "iao, iew, eaw", ["diao", "Diaw"]],
    ["อวย", "uay", "uay, uai", ["suay", "Suay"]],
    ["เอือย", "vay", "ueai, ueay", ["nueay", "Nvay"]],
    ["ฤ ฤๅ", "Rv / Ri", "rue, ri", ["rue", "Rv"]],
  ];

  // Fingerprint of the sound rules: sound keys saved at build time are only
  // used if the rules haven't changed since.
  function signature() {
    const src = tokenize.toString() + JSON.stringify([VOWELS, CONSONANTS, String(CLUSTER_DROP)]);
    let h = 2166136261;
    for (let i = 0; i < src.length; i++) h = Math.imul(h ^ src.charCodeAt(i), 16777619) >>> 0;
    return h.toString(36);
  }

  const api = { signature, tokenize, openKeys, subCost, indelCost, CONSONANT_TABLE, VOWEL_TABLE, VOWELS, CONSONANTS };
  root.ThaiPhonemes = api;
  if (typeof module !== "undefined") module.exports = api;
})(typeof window !== "undefined" ? window : globalThis);

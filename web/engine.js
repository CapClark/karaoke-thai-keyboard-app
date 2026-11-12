// Thai "pinyin-style" input engine.
// Turns loose romanized typing (e.g. "sawasdeekrap") into ranked Thai candidates.
// Needs phonemes.js (window.ThaiPhonemes) loaded first.
(function (root) {
  "use strict";
  const P = root.ThaiPhonemes;

  const LEARN_KEY = "thaiIME.learned.v2";
  let learned = { u: {}, b: {} };
  try {
    const saved = JSON.parse(root.localStorage?.getItem(LEARN_KEY) || "null");
    if (saved && saved.u && saved.b) learned = saved;
  } catch (e) {}

  // ---- data ----------------------------------------------------------------
  const words = []; // Thai text
  const freq = []; // corpus count
  const spell = []; // all romanizations of a word, joined with "|" (one string per word: compact)
  const romans = []; // first romanization (for display)
  const byKey = new Map(); // key -> [word ids], best first
  const wordId = new Map(); // Thai text -> id
  let TOTAL = 1;
  // Word pairs / triples as sorted number arrays (binary search): far smaller than Maps.
  const B = 131072; // 2^17 > number of corpus words, so a*B+b and (a*B+b)*B+c fit in a double exactly
  let biKeys = new Float64Array(0), biCounts = new Uint32Array(0);
  let triKeys = new Float64Array(0), triCounts = new Uint32Array(0);
  function lookup(keys, counts, k) {
    let lo = 0, hi = keys.length - 1;
    while (lo <= hi) {
      const m = (lo + hi) >> 1, v = keys[m];
      if (v === k) return counts[m];
      if (v < k) lo = m + 1; else hi = m - 1;
    }
    return 0;
  }
  function sortPaired(keys, counts) {
    let sorted = true;
    for (let i = 1; i < keys.length && sorted; i++) if (keys[i] < keys[i - 1]) sorted = false;
    if (sorted) return;
    const idx = Array.from(keys.keys()).sort((x, y) => keys[x] - keys[y]);
    const k2 = Float64Array.from(idx, (i) => keys[i]), c2 = Uint32Array.from(idx, (i) => counts[i]);
    keys.set(k2); counts.set(c2);
  }
  const bigramCount = (a, b) => (a < B && b < B ? lookup(biKeys, biCounts, a * B + b) : 0);
  const trigramCount = (a, b, c) => (a < B && b < B && c < B ? lookup(triKeys, triCounts, (a * B + b) * B + c) : 0);
  const REPEAT = -1; // stands for ๆ (repeat the previous word)
  const textOf = (ids) => ids.map((i) => (i === REPEAT ? "ๆ" : words[i])).join("");
  let sortedKeys = [];
  let buckets = new Map(); // first sound -> length -> [keys], for fuzzy search
  let delIndex = new Map(); // key with one sound removed -> [keys]
  const phraseIds = new Set(); // ids that are multi-word phrases
  const phraseLast = new Map(); // phrase id -> id of its last word
  let personal = new Map(); // Thai word -> count from your own writing (Wispr import)

  const tokCache = new Map();
  function tok(s) {
    let t = tokCache.get(s);
    if (!t) {
      t = P.tokenize(s);
      if (tokCache.size > 8000) tokCache.clear();
      tokCache.set(s, t);
    }
    return t;
  }

  // keys (optional): the sound key of each spelling, saved at build time.
  function addWord(w, roms, f, keys) {
    let id = wordId.get(w);
    if (id === undefined) {
      id = words.length;
      words.push(w); freq.push(f); romans.push(roms[0]); spell.push("");
      wordId.set(w, id);
    } else if (f > freq[id]) freq[id] = f;
    for (let q = 0; q < roms.length; q++) {
      const r = roms[q];
      const key = keys ? keys[q] : tok(r).key;
      if (!key) continue;
      if (!("|" + spell[id] + "|").includes("|" + r + "|")) spell[id] = spell[id] ? spell[id] + "|" + r : r;
      let list = byKey.get(key);
      if (!list) byKey.set(key, (list = []));
      if (!list.includes(id)) list.push(id);
    }
  }

  // Does any spelling of this word have these sounds (clusters included)?
  function hasFull(id, full) {
    for (const r of spell[id].split("|")) if (tok(r).full === full) return true;
    return false;
  }
  const NONE = [];
  // Word ids for a sound key. A key with one word is stored as the bare number.
  function idsOf(k) {
    const v = byKey.get(k);
    return v === undefined ? NONE : typeof v === "number" ? [v] : v;
  }

  // Near-sound index, built in small slices after startup (warmup) so the
  // keyboard is usable right away. Anything that needs it finishes it first.
  let indexPos = Infinity;
  function buildIndex(ms) {
    const until = Date.now() + ms;
    while (indexPos < sortedKeys.length) {
      const k = sortedKeys[indexPos++];
      if (idsOf(k).every((id) => phraseIds.has(id))) continue;
      // Keys of 3+ sounds only (shorter ones never need the index); one key is
      // stored as a plain string, several as an array — most entries have one.
      if (k.length >= 3 && k.length <= 16) {
        for (let i = 0; i < k.length; i++) {
          const d = k.slice(0, i) + k.slice(i + 1);
          const a = delIndex.get(d);
          if (a === undefined) delIndex.set(d, k);
          else if (typeof a === "string") { if (a !== k) delIndex.set(d, [a, k]); }
          else if (a[a.length - 1] !== k) a.push(k);
        }
      }
      if (!buckets.has(k[0])) buckets.set(k[0], []);
      const byLen = buckets.get(k[0]);
      (byLen[k.length] ||= []).push(k);
      if ((indexPos & 255) === 0 && Date.now() > until) break;
    }
    return indexPos >= sortedKeys.length;
  }
  const warmup = (ms = 15) => buildIndex(ms);

  const T = [];
  function load(dict, extra = [], mine = [], names = []) {
    T.push(["start", Date.now()]);
    for (const [w, c] of mine) personal.set(w, (personal.get(w) || 0) + c);
    T.push(["words", Date.now()]);
    // Sound keys saved at build time skip the slow part of startup; ignored if
    // the sound rules changed since (then they're worked out here instead).
    const pre = dict.sig && dict.sig === P.signature() && dict.k && dict.pk;
    for (let i = 0; i < dict.w.length; i++) addWord(dict.w[i], dict.r[i].split("|"), dict.f[i], pre ? dict.k[i].split("|") : null);
    // Common multi-word phrases: matched whole, but left out of the near-sound
    // index (keeps it small and fast). For word-pair context a phrase acts as its last word.
    const plist = dict.p || [];
    for (let pi = 0; pi < plist.length; pi++) {
      const [t, r, c, last] = plist[pi];
      if (wordId.has(t)) continue;
      addWord(t, [r], c, pre ? [dict.pk[pi]] : null);
      const id = wordId.get(t);
      phraseIds.add(id);
      const lid = wordId.get(last);
      if (lid !== undefined) phraseLast.set(id, lid);
    }
    T.push(["phrases", Date.now()]);
    const b = dict.b || [];
    biKeys = new Float64Array(b.length / 3); biCounts = new Uint32Array(b.length / 3);
    for (let i = 0, j = 0; i < b.length; i += 3, j++) { biKeys[j] = b[i] * B + b[i + 1]; biCounts[j] = b[i + 2]; }
    const t3 = dict.t || [];
    triKeys = new Float64Array(t3.length / 4); triCounts = new Uint32Array(t3.length / 4);
    for (let i = 0, j = 0; i < t3.length; i += 4, j++) { triKeys[j] = (t3[i] * B + t3[i + 1]) * B + t3[i + 2]; triCounts[j] = t3[i + 3]; }
    sortPaired(biKeys, biCounts); sortPaired(triKeys, triCounts); // no-op when the build already sorted them
    T.push(["pairs", Date.now()]);
    for (const [w, r] of extra) {
      const id = wordId.get(w);
      addWord(w, [r], id === undefined ? 2000 : Math.max(freq[id], 2000));
    }
    // Proper nouns (web/names.js): a name that's already a word keeps its rank and only
    // gains the spellings; a new one comes in at the modest rank given.
    for (const [w, rs, f] of names) {
      const id = wordId.get(w);
      addWord(w, rs.split("|"), id === undefined ? f : freq[id]);
    }
    // Your own words (names, slang) that the word list lacks.
    for (const [w, , r] of mine) if (r && !wordId.has(w)) addWord(w, [r], 500);
    T.push(["extra", Date.now()]);
    notId = wordId.get("ไม่") ?? -2;
    enderIds = new Set([...ENDERS].map((w) => wordId.get(w)).filter((x) => x !== undefined));
    TOTAL = freq.reduce((a, b) => a + b, 0) + words.length;
    T.push(["misc", Date.now()]);
    for (const list of byKey.values()) list.sort((a, b) => uni(b) - uni(a));
    for (const [k, list] of byKey) if (list.length === 1) byKey.set(k, list[0]);
    T.push(["sortlists", Date.now()]);
    sortedKeys = [...byKey.keys()].sort();
    T.push(["sortkeys", Date.now()]);
    buckets = new Map();
    delIndex = new Map();
    indexPos = 0; // the near-sound index is built afterwards, a slice at a time (warmup)
    T.push(["index", Date.now()]);
  }

  // ---- scoring -------------------------------------------------------------
  function boost(id) {
    return Math.min(learned.u[words[id]] || 0, 10) * 0.8 + Math.log1p(personal.get(words[id]) || 0) * 0.6;
  }
  function uni(id) {
    return Math.log(freq[id] + 1) + boost(id) * 3;
  }


  // Cost of a word after `prev` = -log P(word | prev), interpolating word-pair
  // counts with plain word frequency. Always positive, so extra words cost more.
  // With prev2 (the word before prev), three-word sequences are used too.
  function wcost(prev, id, prev2) {
    if (prev != null && phraseIds.has(prev)) { prev = phraseLast.get(prev) ?? null; prev2 = null; }
    const pu = ((freq[id] + 1) / TOTAL) * Math.exp(boost(id));
    let p = pu;
    if (prev != null) {
      const c = bigramCount(prev, id);
      const l = learned.b[words[prev] + "\t" + words[id]] || 0;
      p = 0.35 * pu + 0.65 * (c / (freq[prev] + 1)) + (l ? 0.05 * l : 0);
      if (prev2 != null) {
        const c3 = trigramCount(prev2, prev, id);
        const c2 = bigramCount(prev2, prev);
        if (c3 && c2) p = 0.6 * p + 0.4 * Math.min(1, c3 / c2);
      }
    }
    return -Math.log(Math.min(p, 1)) + 1; // +1 per word: prefer fewer, longer words
  }

  // ---- lookups -------------------------------------------------------------
  function keysWithPrefix(p, max = 300) {
    let lo = 0, hi = sortedKeys.length;
    while (lo < hi) {
      const m = (lo + hi) >> 1;
      if (sortedKeys[m] < p) lo = m + 1; else hi = m;
    }
    const out = [];
    for (let i = lo; i < sortedKeys.length && out.length < max; i++) {
      if (!sortedKeys[i].startsWith(p)) break;
      out.push(sortedKeys[i]);
    }
    return out;
  }

  const ROWS = [new Float32Array(96), new Float32Array(96), new Float32Array(96)]; // reused DP rows
  // Weighted edit distance between token strings (with swaps).
  // prefix=true: best match against any start of b (word still being typed).
  function dist(a, b, budget, prefix) {
    const n = a.length, m = b.length;
    if (m + 1 > ROWS[0].length) return Infinity;
    let prev2 = ROWS[0], prev = ROWS[1], cur = ROWS[2];
    prev[0] = 0;
    for (let j = 1; j <= m; j++) prev[j] = prev[j - 1] + P.indelCost(b[j - 1]);
    for (let i = 1; i <= n; i++) {
      cur[0] = prev[0] + P.indelCost(a[i - 1]);
      let rowMin = cur[0];
      for (let j = 1; j <= m; j++) {
        let v = Math.min(
          prev[j] + P.indelCost(a[i - 1]),
          cur[j - 1] + P.indelCost(b[j - 1]),
          prev[j - 1] + P.subCost(a[i - 1], b[j - 1])
        );
        if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1]) v = Math.min(v, prev2[j - 2] + 0.7);
        cur[j] = v;
        if (v < rowMin) rowMin = v;
      }
      if (rowMin > budget) return Infinity;
      const spare = prev2; prev2 = prev; prev = cur; cur = spare;
    }
    if (!prefix) return prev[m];
    let best = Infinity;
    for (let j = Math.max(0, n - 1); j <= m; j++) best = Math.min(best, prev[j]);
    return best;
  }

  // Near-sound search. An index of every key with one sound removed finds all
  // keys one edit away in a few lookups (instead of scanning 60k keys); a small
  // scan of same-length keys catches two cheap edits in longer words.
  function fuzzy(key, budget, prefix, max = 40) {
    buildIndex(Infinity);
    const n = key.length, found = new Map();
    const tryKey = (k) => {
      if (k === key || found.has(k) || !byKey.has(k)) return;
      const d = dist(key, k, budget, prefix);
      if (d <= budget) found.set(k, d);
    };
    const probe = (d) => {
      const a = delIndex.get(d);
      if (typeof a === "string") tryKey(a);
      else if (a) for (const k of a) tryKey(k);
    };
    tryKey(key);
    probe(key); // one sound missing from what was typed
    for (let i = 0; i < n; i++) {
      const d = key.slice(0, i) + key.slice(i + 1);
      tryKey(d); // one extra sound typed
      probe(d); // one sound different / swapped
    }
    if (prefix) {
      // Still typing: compare against the start of longer keys with the same first sound.
      const byLen = buckets.get(key[0]) || [];
      for (let len = n + 1; len <= n + 6 && len < byLen.length; len++) {
        for (const k of byLen[len] || []) if (k.startsWith(key.slice(0, 2))) tryKey(k);
      }
    } else if (n >= 6 && budget >= 1) {
      const byLen = buckets.get(key[0]) || [];
      for (let len = n - 1; len <= n + 1 && len < byLen.length; len++) for (const k of byLen[len] || []) tryKey(k);
    }
    return [...found.entries()].map(([k, d]) => ({ k, d })).sort((a, b) => a.d - b.d).slice(0, max);
  }


  // ---- phrase splitting (beam search with word pairs) ---------------------
  const BEAM = 8;
  // A reading is "fluent" when it costs at most this much per letter typed. Measured
  // on the test sentences: correct readings stay under 2.2, junk splits are 2.9+.
  // (Per letter, not per word, so readings made of long set phrases aren't penalised.)
  const FLUENT = 2.5;
  // Words that end spoken sentences. The corpus is mostly formal writing, so it
  // under-counts these; give them a push when they're the last word typed.
  const ENDERS = new Set(["ครับ", "ค่ะ", "คะ", "นะ", "ไหม", "มั้ย", "เหรอ", "หรอ", "จ้า", "จ้ะ", "นะคะ", "นะครับ",
    "เลย", "ด้วย", "กัน", "แล้ว", "หรือเปล่า", "รึเปล่า", "เปล่า", "ป่ะ", "สิ", "ล่ะ", "แหละ", "เนอะ", "อะ", "อ่ะ", "ยัง", "บ้าง"]);
  let enderIds = null;
  let notId = -2;
  // Is the word's first consonant ห (after a leading vowel sign like ไ เ แ โ ใ)?
  const startsWithHo = (w) => w.replace(/^[เแโใไ]/, "")[0] === "ห";

  // English-style "u" for the short Thai a sound: krung/krub/tum/nung = khrang/khrap/tham/nang.
  // Only a u between consonants (not ue/ua/ui/uu/ou/oo) is re-read as a.
  // Each such u may or may not mean a, so try every combination (at most 3 u's).
  function uAsA(chunk) {
    const spots = [];
    const re = /([^aeiou])u(?=[^aeiouy])/g;
    let m;
    while ((m = re.exec(chunk)) && spots.length < 3) spots.push(m.index + 1);
    const out = [];
    for (let mask = 1; mask < 1 << spots.length; mask++) {
      let s = chunk.split("");
      spots.forEach((p, b) => { if (mask & (1 << b)) s[p] = "a"; });
      out.push(s.join(""));
    }
    return out;
  }

  // What a stretch of letters could be, as whole words. Cached: the same
  // stretches come up again on every keystroke.
  const lexCache = new Map();
  function lex(chunk) {
    let L = lexCache.get(chunk);
    if (L) return L;
    const t = tok(chunk);
    const ids = (idsOf(t.key) || []).slice(0, 6);
    const uaIds = [];
    for (const ua of uAsA(chunk)) {
      for (const id of (idsOf(tok(ua).key) || []).slice(0, 3)) {
        if (!ids.includes(id) && !uaIds.includes(id) && !phraseIds.has(id)) uaIds.push(id);
      }
    }
    L = { k: t.key, full: t.full, cluster: t.full !== t.key, ids, uaIds, short: t.key.length < 2 ? 5 : 0,
          hMarked: /^(mh|nh|lh|rh|wh|yh|ngh)/.test(chunk) };
    if (lexCache.size > 8000) lexCache.clear();
    lexCache.set(chunk, L);
    return L;
  }

  // Beam search over ways to split the input into words. Positions before the
  // part that changed are reused from the previous keystroke, so typing a long
  // sentence stays fast.
  let segMemo = { raw: "", prev: undefined, states: null };
  function segment(raw, prev) {
    const n = raw.length;
    let states, from = 0;
    const old = segMemo;
    if (old.states && old.prev === prev) {
      let L = 0;
      while (L < n && L < old.raw.length && raw[L] === old.raw[L]) L++;
      if (L > 0) {
        states = old.states.slice(0, L); // positions < L only depend on raw[0..L)
        while (states.length <= n) states.push([]);
        from = L;
      }
    }
    if (!states) {
      states = Array.from({ length: n + 1 }, () => []);
      states[0].push({ cost: 0, ids: [], last: prev, last2: null, lastKey: null, lens: [] });
      from = 1;
    }
    for (let i = Math.max(0, from - 30); i < n; i++) {
      if (!states[i].length) continue;
      for (let j = Math.max(i + 1, from); j <= Math.min(n, i + 30); j++) {
        const L = lex(raw.slice(i, j));
        let ids = L.ids, uaIds = L.uaIds, pen = 0;
        if (!ids.length && !uaIds.length && j === n && L.k.length >= 2) {
          // Unfinished last word: best completions.
          ids = keysWithPrefix(L.k, 60).flatMap((kk) => idsOf(kk).slice(0, 2))
            .filter((id) => !phraseIds.has(id)).sort((a, b) => uni(b) - uni(a)).slice(0, 3);
          pen = 3;
        }
        if (!ids.length && !uaIds.length && !(states[i][0]?.lastKey === L.k)) continue;
        for (const s of states[i]) {
          // Same sounds as the word just before: Thai writes the repeat as ๆ (makmak -> มากๆ).
          if (s.lastKey && L.k === s.lastKey) {
            states[j].push({ cost: s.cost + 1.5, ids: [...s.ids, REPEAT], last: s.last, last2: s.last2,
                             lastKey: null, lens: [...s.lens, j - i] });
          }
          for (let q = 0; q < ids.length + uaIds.length; q++) {
            const isUa = q >= ids.length, id = isUa ? uaIds[q - ids.length] : ids[q];
            let cost = s.cost + wcost(s.last, id, s.last2) + pen + L.short + (isUa ? (ids.length ? 5 : 1.2) : 0);
            if (L.cluster && hasFull(id, L.full)) cost -= 2.5; // typed "krap": ครับ, not กับ
            if (L.hMarked && startsWithHo(words[id])) cost -= 8; // typed "mhai": ไหม, not ไม่
            if (j === n && !pen && enderIds.has(id)) cost -= 3;
            if (j === n && id === notId) cost += 3; // ไม่ almost never ends a sentence (that's ไหม)
            states[j].push({ cost, ids: [...s.ids, id], last: id, last2: s.last, lastKey: pen ? null : L.k,
                             lens: [...s.lens, j - i] });
          }
        }
        if (states[j].length > BEAM * 4) {
          states[j].sort((a, b) => a.cost - b.cost);
          states[j].length = BEAM;
        }
      }
      if (i + 1 >= from && i + 1 <= n) {
        states[i + 1].sort((a, b) => a.cost - b.cost);
        if (states[i + 1].length > BEAM) states[i + 1].length = BEAM;
      }
    }
    segMemo = { raw, prev, states };
    // Whole input if possible; otherwise the longest start we could read
    // (pinyin-style: convert what we can, leave the rest for more typing).
    for (let j = n; j > 0; j--) {
      if (!states[j].length) continue;
      const sorted = states[j].slice().sort((a, b) => a.cost - b.cost);
      // Also keep the next-best different readings, so a wrong guess has backups.
      const alts = [], seenText = new Set();
      for (const st of sorted) {
        const tx = textOf(st.ids);
        if (seenText.has(tx)) continue;
        seenText.add(tx);
        alts.push({ text: tx, cost: st.cost, n: st.ids.length, ids: st.ids, lens: st.lens });
        if (alts.length >= 3) break;
      }
      // Word-by-word split of the best reading (for "pick just the first word"),
      // even when the best reading is a single phrase entry like ผมรักคุณ.
      const best = alts[0].text;
      const split = sorted.find((st) => st.ids.length > 1 && textOf(st.ids) === best) || sorted.find((st) => st.ids.length > 1);
      return { ...sorted[0], end: j, alts, split };
    }
    return null;
  }

  // ---- public: candidates ---------------------------------------------------
  // Returns [{text, consume, roman, kind}]; consume = input letters it uses up.
  // fast=true (key held down): skip the slow near-sound search.
  function candidates(raw, limit = 9, prevText, fast = false) {
    raw = String(raw || "").toLowerCase().replace(/[^a-z]/g, "");
    if (!raw) return [];
    if (raw.length > 60) raw = raw.slice(0, 60);
    const prev = prevText != null ? wordId.get(prevText) ?? null : null;
    const t = tok(raw);
    const [closedKey, openKey] = P.openKeys(raw);
    const cost = new Map(); // id -> cost (lower is better)
    // Strict order, best first:
    //   tier 0  every sound you typed, exactly (allowing common spelling habits:
    //           ue/uea, u for a, stretched or doubled letters), words you're still
    //           typing, and fluent whole-sentence readings
    //   tier 1  corrections that keep your consonants (vowel slip, wrong final,
    //           swapped letters) and sentence guesses that don't read fluently
    //   tier 2  corrections that change a consonant you typed
    // Within a tier, cost (how common + how close) decides. So "reung" lists
    // R-words with ue+ng first, and never ถึง (t is next to r on the keyboard) above them.
    const consonants = (k) => k.replace(/[^A-Z]/g, "");
    const typedC = consonants(closedKey);
    const tierFor = (k, prefix) => (prefix ? consonants(k).startsWith(typedC) : consonants(k) === typedC) ? 1 : 2;
    const tierOf = new Map();
    const hMarked = /^(mh|nh|lh|rh|wh|yh|ngh)/.test(raw);
    const put = (id, extra, tier = 0) => {
      let c = wcost(prev, id) + extra;
      if (hasFull(id, t.full)) c -= t.full !== t.key ? 2.5 : 0.8; // typed the cluster: krap -> ครับ
      if (("|" + spell[id] + "|").includes("|" + raw + "|")) c -= 2; // typed one of its known spellings letter for letter
      const w = words[id];
      if (hMarked && startsWithHo(w)) c -= 8; // "mhai": the typed h means a word written with ห (ไหม)
      if (w.length > 3 && w.endsWith("ไม่")) c += 2; // "...mai" at the end is usually the question ไหม
      const ot = tierOf.get(id);
      if (ot === undefined || tier < ot || (tier === ot && c < cost.get(id))) { cost.set(id, c); tierOf.set(id, tier); }
    };

    // 1. Exact sound match.
    const exactIds = idsOf(closedKey) || [];
    for (const id of exactIds) put(id, 0);
    // 2. Still typing: completions of the current sounds.
    // (The other reading of the last consonant only counts if it keeps every typed sound.)
    const useOpen = openKey && openKey.length >= closedKey.length;
    const prefKeys = new Set([...keysWithPrefix(closedKey), ...(useOpen ? keysWithPrefix(openKey) : [])]);
    prefKeys.delete(closedKey);
    for (const k of prefKeys) {
      const more = k.length - closedKey.length;
      if (more <= 0) continue; // a completion must contain at least every sound typed so far
      // Completing a multi-word phrase from a few letters is a long guess: rank it lower.
      for (const id of idsOf(k).slice(0, 4)) put(id, 2 + 0.3 * more + (phraseIds.has(id) ? 3 : 0), 0);
    }
    // Stretched letters for emphasis ("arooooi", "maaaak"): also read each run as one letter.
    const unstretched = raw.replace(/([a-z])\1{2,}/g, "$1");
    if (unstretched !== raw) {
      for (const id of (idsOf(tok(unstretched).key) || []).slice(0, 4)) put(id, 0.3);
    }
        // 3. Typos at the letter level: extra letter, swapped letters, neighbour key.
    for (const [v, vc] of typoVariants(raw)) {
      const vk = tok(v).key;
      for (const id of (idsOf(vk) || []).slice(0, 3)) put(id, vc, tierFor(vk));
    }
    // "u" written for the short a sound (krung = ครั้ง).
    for (const uaRaw of uAsA(raw)) {
      for (const id of (idsOf(tok(uaRaw).key) || []).slice(0, 4)) put(id, exactIds.length ? 2.5 : 1.2, exactIds.length ? 1 : 0);
    }

    // 4. Unusual spellings: sounds that are close but not equal. Skipped when the
    // input already reads well (several exact words, or a fluent phrase) — saves time.
    const seg = raw.length >= 4 ? segment(raw, prev) : null;
    const readsWell = exactIds.length >= 4 || (seg && seg.end === raw.length && seg.ids.length > 1 && seg.cost / raw.length <= FLUENT);
    if (closedKey.length >= 3 && !fast && !readsWell) {
      const budget = closedKey.length <= 4 ? 0.7 : closedKey.length <= 7 ? 1.1 : 1.6;
      for (const { k, d } of fuzzy(closedKey, budget, false)) {
        for (const id of idsOf(k).slice(0, 4)) put(id, 1.5 + 5 * d, tierFor(k));
      }
      if (cost.size < limit) {
        for (const { k, d } of fuzzy(closedKey, budget * 0.8, true)) {
          for (const id of idsOf(k).slice(0, 2)) put(id, 3 + 5 * d, tierFor(k, true));
        }
      }
    }

    // 5. Whole phrase, e.g. "pomrakkun" -> ผมรักคุณ, ranked on the same cost scale.
    // Long and short versions of the same vowel pair (ue/uea, i/ia, u/ua) are
    // often mixed up in typing: "reung" for เรื่อง, "rin" for เรียน.
    // ue/uea is mixed up all the time (counts as exact); i/ia and u/ua much less (a correction).
    for (const v of diphthongVariants(closedKey)) {
      const habit = v.replace(/va/g, "v") === closedKey.replace(/va/g, "v");
      for (const id of idsOf(v).slice(0, 3)) put(id, 1.5, habit ? 0 : 1);
    }

    const items = [...cost.entries()].map(([id, c]) => ({ text: words[id], c, tier: tierOf.get(id), roman: romans[id], kind: "word", consume: raw.length }));
    if (seg && (seg.ids.length > 1 || seg.end < raw.length || seg.alts.some((a) => a.n > 1))) {
      const partial = seg.end < raw.length;
      // A fluent multi-word reading (low cost per word) beats any single
      // look-alike word; long sentences would otherwise lose on total cost.
      const fluent = !partial && seg.ids.length > 1 && seg.cost / raw.length <= FLUENT;
      const phraseTier = fluent || (seg.ids.length === 1 && !partial) ? 0 : 1;
      let c = seg.cost + (partial ? 3 : 0);
      if (fluent && !exactIds.length) c = Math.min(c, ...[...cost.values()].map((x) => x - 0.01));
      if (partial && seg.end >= raw.length * 0.6) c = Math.min(c, ...[...cost.values()].map((x) => x - 0.01));
      items.push({ text: textOf(seg.ids), c, tier: phraseTier, roman: "phrase", kind: "phrase", consume: seg.end });
      for (const a of seg.alts.slice(1)) {
        // Backup readings never jump above a word that matches the whole input exactly.
        const floor = exactIds.length ? Math.min(...exactIds.map((id) => cost.get(id) ?? Infinity)) + 0.01 : -Infinity;
        const altTier = !partial && a.cost / raw.length <= FLUENT ? 0 : 1;
        if (a.n > 1) items.push({ text: a.text, c: Math.max(floor, c + 0.05 + (a.cost - seg.cost)), tier: altTier, roman: "phrase", kind: "phrase", consume: seg.end });
      }
      // Pick just the first word, keep typing the rest (like pinyin).
      // Based on the best reading that has more than one word.
      const multi = seg.ids.length > 1 ? seg : seg.split;
      const first = multi ? multi.lens[0] : raw.length;
      // The phrase's own first word goes right after the phrase; other readings of it come later.
      const firstIds = (idsOf(tok(raw.slice(0, first)).key) || []).slice(0, 4);
      const own = multi ? multi.ids[0] : null;
      for (const id of [own, ...firstIds.filter((x) => x !== own)]) {
        if (id === REPEAT || id == null || !multi) continue;
        const cc = id === own ? c + 0.02 : Math.max(c, wcost(prev, id)) + 3;
        items.push({ text: words[id], c: cc, tier: phraseTier, roman: romans[id], kind: "first", consume: first });
      }
    }
    items.sort((a, b) => (a.tier || 0) - (b.tier || 0) || a.c - b.c);

    // First page (9): exact matches first, but up to the last 3 slots go to the
    // best corrections, so a likely fix is never hidden behind many rare exact matches. Corrections still never appear above an exact match.
    const uniq = [], seen = new Set();
    for (const it of items) {
      if (seen.has(it.text)) continue;
      seen.add(it.text);
      uniq.push(it);
    }
    const PAGE = 9, RESERVE = 3;
    const exact = uniq.filter((it) => !it.tier), fixes = uniq.filter((it) => it.tier);
    // A correction only takes a slot from an exact match it is more likely than.
    let r = 0;
    while (r < RESERVE && r < fixes.length && (exact.length < PAGE - r || fixes[r].c < exact[PAGE - 1 - r].c)) r++;
    const firstExact = exact.slice(0, PAGE - r);
    const ordered = [...firstExact, ...fixes.slice(0, PAGE - firstExact.length), ...exact.slice(firstExact.length), ...fixes.slice(PAGE - firstExact.length)];
    return ordered.slice(0, limit).map((it) => ({ text: it.text, consume: it.consume, roman: it.roman, kind: it.kind,
      tier: it.tier || 0, cost: Math.round(it.c * 10) / 10 }));
  }

  function diphthongVariants(key) {
    const out = [];
    for (let i = 0; i < key.length; i++) {
      const ch = key[i];
      if ((ch === "v" || ch === "i" || ch === "u") && key[i + 1] !== "a") out.push(key.slice(0, i + 1) + "a" + key.slice(i + 1));
      if ((ch === "v" || ch === "i" || ch === "u") && key[i + 1] === "a") out.push(key.slice(0, i + 1) + key.slice(i + 2));
    }
    return out;
  }

  // Letter-level typo fixes: drop a letter, swap two, or hit a neighbouring key.
  const NEIGHBOURS = {
    q: "wa", w: "qeas", e: "wrds", r: "etdf", t: "ryfg", y: "tugh", u: "yihj", i: "uojk", o: "ipkl", p: "ol",
    a: "qwsz", s: "awedxz", d: "serfcx", f: "drtgvc", g: "ftyhbv", h: "gyujnb", j: "huikmn", k: "jiolm", l: "kop",
    z: "asx", x: "zsdc", c: "xdfv", v: "cfgb", b: "vghn", n: "bhjm", m: "njk",
  };
  // Map of variant -> cost. Swapping two letters keeps everything you typed, so
  // it's the most likely fix; a neighbouring key next; dropping a letter last.
  function typoVariants(raw) {
    const out = new Map();
    if (raw.length < 3 || raw.length > 14) return out;
    const add = (v, c) => { if (v !== raw && !(out.get(v) <= c)) out.set(v, c); };
    for (let i = 0; i < raw.length; i++) {
      if (i < raw.length - 1) add(raw.slice(0, i) + raw[i + 1] + raw[i] + raw.slice(i + 2), 3.2);
      for (const c of NEIGHBOURS[raw[i]] || "") add(raw.slice(0, i) + c + raw.slice(i + 1), 3.6);
      add(raw.slice(0, i) + raw.slice(i + 1), 4);
    }
    return out;
  }

  // Remember a pick. Whole phrases aren't stored (scoring never looks them up);
  // instead each word inside is learned via segment().
  const MAX_LEARNED = 4000;
  function learn(text, prevText, kind) {
    if (!text || kind === "phrase") return;
    learned.u[text] = Math.min(10, (learned.u[text] || 0) + 1);
    if (prevText) {
      const k = prevText + "\t" + text;
      learned.b[k] = Math.min(10, (learned.b[k] || 0) + 1);
    }
    prune(learned.u); prune(learned.b);
    if (api.autosave) save();
  }
  function prune(obj) {
    const keys = Object.keys(obj);
    if (keys.length <= MAX_LEARNED) return;
    keys.sort((a, b) => obj[a] - obj[b]);
    for (const k of keys.slice(0, keys.length - MAX_LEARNED * 0.8)) delete obj[k];
  }
  function save() {
    try { root.localStorage?.setItem(LEARN_KEY, JSON.stringify(learned)); } catch (e) {}
  }

  function forget() {
    learned = { u: {}, b: {} };
    try { root.localStorage?.setItem(LEARN_KEY, JSON.stringify(learned)); } catch (e) {}
  }

  function resetMemo() { segMemo = { raw: "", prev: undefined, states: null }; }
  const loadTimes = () => T.map((x, i) => i ? x[0] + " " + (x[1] - T[i - 1][1]) : "").filter(Boolean).join(", ");
  const api = { warmup, loadTimes, resetMemo, load, candidates, learn, forget, save, segment, autosave: true, tokenize: P.tokenize, size: () => words.length };
  root.ThaiIME = api;
  if (typeof module !== "undefined") module.exports = api;
})(typeof window !== "undefined" ? window : globalThis);

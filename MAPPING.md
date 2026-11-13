# Thai sound map

How typed Latin letters turn into Thai sounds. Generated from `web/phonemes.js` by `node tools/make_mapping_doc.js`; `tests/mapping.test.js` checks every example.

Tones and vowel length are not typed. Spellings that sound alike to a Thai speaker match the same words (k/kh, p/ph, t/th, j/ch, r/l). The word list, word pairs and your past picks decide which comes first.

## Consonants

| Thai | Class | Start sound | End sound | Type at start | Type at end | Example |
|---|---|---|---|---|---|---|
| ก | mid | K | k | g, k, gk | k, g, c, ck | `gai` → Kay |
| ข ฃ ค ฅ ฆ | high/low | K | k | kh, k, g, c, q | k | `khon` → Kon |
| ง | low | G | g | ng | ng | `ngu` → Gu |
| จ | mid | J | t | j, ch, c | t, d, j | `jai` → Jay |
| ฉ ช ฌ | high/low | J | t | ch, sh, j | t | `chang` → Jag |
| ซ ศ ษ ส | high/low | S | t | s, z, x, c(e/i) | t, s, d | `suay` → Suay |
| ญ ย | low | Y | n / y | y | n (ญ), y/i (ย) | `yai` → Yay |
| ด ฎ | mid | D | t | d | t, d | `dek` → Dek |
| ต ฏ | mid | T | t | t, dt | t | `dtam` → Tam |
| ถ ฐ ท ฑ ฒ ธ | high/low | T | t | th, t | t, d, th | `thai` → Tay |
| น ณ | low | N | n | n | n | `nam` → Nam |
| บ | mid | B | p | b | p, b | `baan` → Ban |
| ป | mid | P | p | p, bp | p | `bpai` → Pay |
| ผ พ ภ | high/low | P | p | ph, p | p, b, f | `phom` → Pom |
| ฝ ฟ | high/low | F | p | f | p, f | `fan` → Fan |
| ม | low | M | m | m | m | `mai` → May |
| ร ล ฬ | low | R | n | r, l | n, l, r | `rak` → Rak |
| ว | low | W | w | w, v | w, o, u | `wan` → Wan |
| ห ฮ | high/low | H | - | h | (silent) | `hiw` → Hiw |
| อ | mid | - | - | (nothing) | - | `aroi` → aRoy |

## Vowels

| Thai | Sound | Type | Example |
|---|---|---|---|
| อะ อา | a | a, aa, ah, ar | `kaa` → Ka |
| อิ อี | i | i, ee, ii | `dee` → Di |
| อึ อื | v | ue, eu, uee | `meu` → Mv |
| อุ อู | u | u, oo, ou, uu | `khoon` → Kun |
| เอะ เอ | e | e, eh | `pen` → Pen |
| แอะ แอ | x | ae, air | `mae` → Mx |
| โอะ โอ เอาะ ออ | o | o, oh, or | `kor` → Ko |
| เออะ เออ | q | oe, er, ur | `ter` → Tq |
| เอีย | ia | ia, ie, ea, ear | `rean` → Rian |
| เอือ | va | uea, eua | `muea` → Mva |
| อัว | ua | ua | `tua` → Tua |
| อำ | am | am, um | `tam` → Tam |
| ใอ ไอ อัย ไอย | ay | ai, ay | `pai` → Pay |
| เอา | aw | ao, au, aw, ow | `khao` → Kaw |
| อาย | ay | ai, aai, ay | `saai` → Say |
| อุย | uy | ui, ooi, uy | `khui` → Kuy |
| โอย ออย | oy | oi, oy | `aroi` → aRoy |
| เอย | qy | oei, oey, euy | `loei` → Rqy |
| อิว | iw | iu, iw, io | `hiw` → Hiw |
| เอว เอ็ว | ew | eo, ew | `leo` → Rew |
| แอว | xw | aew, aeo, eaw | `laew` → Rxw |
| เอียว | iaw | iao, iew, eow | `diao` → Diaw |
| อวย | uay | uay, uai | `suay` → Suay |
| เอือย | vay | ueai, ueay | `nueay` → Nvay |
| ฤ ฤๅ | Rv / Ri | rue, ri | `rue` → Rv |

## Rules

- A consonant right after a vowel and before another consonant (or the end) is a final: `kin`·`khao`. Thai has 8 final sounds: k t p n m ng w y. So `sawasdee` = `sawatdi`, `khob` = `khop`, `karn` = `kan`.
- R/L after k, p, t, b, f, d can be left out: `krap` = `kap`. Typing it still pushes ครับ above กับ.
- A final followed by the same sound is heard once: `tonni` = `toni`, `rakkun` = `rakun`.
- `c` before e/i/y sounds like s, otherwise k. `x`, `z` = s. `v` = w. `q` = k.
- `h` after a vowel only lengthens it: `kah`, `oh`.
- Typing the same word twice in a row gives the repeat mark ๆ: `makmak` → มากๆ, `khopkhunmakmak` → ขอบคุณมากๆ.
- Letters stretched for emphasis are read as one: `maaaak` → มาก, `arooooi` → อร่อย.
- Common English words, place names and chat words (`facebook`, `chiangmai`, `naka`, `hahaha` → 555) are listed in `web/extra.js`.

## Near misses (fuzzy matching)

Sounds that are close cost less than a full mismatch (0 = same, 1 = different):

| Pair | Cost |
|---|---|
| a ~ i | 0.9 |
| a ~ u | 0.6 |
| a ~ o | 0.7 |
| i ~ v | 0.6 |
| u ~ v | 0.45 |
| e ~ i | 0.6 |
| e ~ x | 0.35 |
| e ~ q | 0.55 |
| o ~ u | 0.6 |
| o ~ q | 0.55 |
| q ~ v | 0.55 |
| G ~ K | 0.7 |
| J ~ S | 0.6 |
| J ~ Y | 0.7 |
| D ~ T | 0.5 |
| N ~ R | 0.8 |
| B ~ P | 0.5 |
| F ~ P | 0.6 |
| M ~ N | 0.8 |
| k ~ t | 0.55 |
| k ~ p | 0.6 |
| p ~ t | 0.55 |
| m ~ n | 0.6 |
| g ~ n | 0.45 |
| g ~ m | 0.7 |
| w ~ y | 0.8 |

Also fixed automatically: one extra letter, two swapped letters, or a neighbouring key on a QWERTY keyboard (`sawatdu` → สวัสดี, `kinkhoa` → กินข้าว).

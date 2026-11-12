// Prints the engine's top 5 guesses after each letter, for the demo video.
// Usage: node demo/cands.js <repo dir> <spelling>...
global.window=global;const W=require("path").resolve(process.argv[2])+"/web/";
for(const f of ["phonemes.js","dict.js","extra.js","names.js","engine.js"]) require(W+f);
ThaiIME.load(window.THAI_DICT,window.THAI_EXTRA,[],window.THAI_NAMES);
const out={};
for(const s of process.argv.slice(3)){out[s]=[];for(let i=1;i<=s.length;i++)out[s].push(ThaiIME.candidates(s.slice(0,i),5,null).map(c=>c.text));}
console.log(JSON.stringify(out));

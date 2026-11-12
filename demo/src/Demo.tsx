import React from "react";
import {
  AbsoluteFill, Img, Sequence, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig, Easing,
} from "remotion";
import { loadFont as loadInter } from "@remotion/google-fonts/Inter";
import { loadFont as loadThai } from "@remotion/google-fonts/NotoSansThai";
import cands from "./cands.json";

const { fontFamily: inter } = loadInter("normal", { weights: ["400", "500", "600", "700", "800"], subsets: ["latin"] });
const { fontFamily: thai } = loadThai("normal", { weights: ["400", "500", "600", "700"], subsets: ["thai"] });
const FONT = `${inter}, ${thai}, sans-serif`;

const BG = "#0E0E12";
const ACCENT = "#5AC8FA";

// ---------- timing ----------
const PER_LETTER = 5;
const HOLD = 22; // after the last letter, before Space
const AFTER = 26; // after Space, before the next phrase
type Phrase = { typed: string; thai: string; meaning: string };
const PHRASES: Phrase[] = [
  { typed: "sawatdeekrap", thai: "สวัสดีครับ", meaning: "hello" },
  { typed: "kinkhaoreuyang", thai: "กินข้าวหรือยัง", meaning: "have you eaten yet?" },
  { typed: "khobkhunmakkrap", thai: "ขอบคุณมากครับ", meaning: "thank you very much" },
];
const phraseLen = (p: Phrase) => p.typed.length * PER_LETTER + HOLD + AFTER;
const TYPE_START = 20;
const TYPE_DUR = TYPE_START + PHRASES.reduce((a, p) => a + phraseLen(p), 0) + 20;

const INTRO = 100;
const VARIANTS = 190;
const PLATFORMS = 170;
const END = 150;
export const TOTAL = INTRO + TYPE_DUR + VARIANTS + PLATFORMS + END;

const fade = (frame: number, dur: number, inLen = 12, outLen = 12) =>
  interpolate(frame, [0, inLen, dur - outLen, dur], [0, 1, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

// ---------- scenes ----------
const Intro: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame: f, fps, config: { damping: 200 } });
  const s2 = spring({ frame: f - 14, fps, config: { damping: 200 } });
  return (
    <AbsoluteFill style={{ justifyContent: "center", alignItems: "center", opacity: fade(f, INTRO, 1, 14) }}>
      <div style={{ fontSize: 120, fontWeight: 800, color: "white", letterSpacing: -3, transform: `translateY(${(1 - s) * 40}px)`, opacity: s }}>
        Karaoke Thai Keyboard
      </div>
      <div style={{ fontSize: 52, color: "#A1A1AA", marginTop: 24, opacity: s2, transform: `translateY(${(1 - s2) * 30}px)` }}>
        Type Thai the way it sounds.
      </div>
    </AbsoluteFill>
  );
};

const ROWS = ["qwertyuiop", "asdfghjkl", "zxcvbnm"];

const Phone: React.FC<{ committed: string; buffer: string; guesses: string[]; pressed: string | null; pressAmt: number }> = ({
  committed, buffer, guesses, pressed, pressAmt,
}) => {
  const W = 560;
  const keyW = 44, keyH = 62, gap = 7;
  const key = (k: string, w = keyW, fn = false, label?: React.ReactNode) => {
    const on = pressed === k;
    return (
      <div key={k} style={{
        width: w, height: keyH, borderRadius: 9, display: "flex", alignItems: "center", justifyContent: "center",
        background: on ? (fn ? "#FFFFFF" : "#AEB3BE") : fn ? "#ABB0BC" : "#FFFFFF",
        boxShadow: "0 1px 0 rgba(0,0,0,0.3)", fontSize: label ? 22 : 30, color: "#111",
        transform: on ? `scale(${1 + 0.08 * pressAmt})` : undefined,
      }}>{label ?? k}</div>
    );
  };
  return (
    <div style={{
      width: W, height: 1000, borderRadius: 72, background: "#1C1C1E", padding: 14, boxShadow: "0 40px 120px rgba(0,0,0,0.6)",
    }}>
      <div style={{ width: "100%", height: "100%", borderRadius: 60, overflow: "hidden", background: "#F2F2F7", position: "relative" }}>
        <div style={{ height: 50, display: "flex", justifyContent: "space-between", padding: "18px 40px 0", fontSize: 20, fontWeight: 600, color: "#111" }}>
          <span>9:41</span><span style={{ letterSpacing: 2 }}>●●● ▮</span>
        </div>
        <div style={{ padding: "50px 28px 0" }}>
          <div style={{ fontSize: 40, fontWeight: 800, color: "#111", letterSpacing: -1 }}>Karaoke Thai</div>
          <div style={{ fontSize: 20, fontWeight: 600, color: "#8E8E93", margin: "26px 6px 10px" }}>Try it</div>
          <div style={{ background: "white", borderRadius: 22, minHeight: 170, padding: "20px 22px", fontSize: 30, color: "#111", lineHeight: 1.5 }}>
            {committed}
            <span style={{ display: "inline-block", width: 3, height: 34, background: "#3478F6", verticalAlign: "middle", marginLeft: 2 }} />
          </div>
        </div>
        {/* keyboard */}
        <div style={{ position: "absolute", bottom: 0, left: 0, right: 0, background: "#D1D4DB", paddingBottom: 46 }}>
          <div style={{ height: 66, display: "flex", alignItems: "center", gap: 28, padding: "0 18px", whiteSpace: "nowrap", overflow: "hidden" }}>
            <span style={{ fontSize: 22, color: "#6B6B70" }}>{buffer}</span>
            {guesses.slice(0, 3).map((g, i) => (
              <span key={i} style={{ fontSize: 28, color: "#111", fontWeight: i === 0 ? 600 : 400 }}>{g}</span>
            ))}
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: 12, alignItems: "center", padding: "6px 0" }}>
            {ROWS.map((r, ri) => (
              <div key={r} style={{ display: "flex", gap }}>
                {ri === 2 && key("⇧", 62, true, "⇧")}
                {ri === 2 && <div style={{ width: 4 }} />}
                {[...r].map((k) => key(k))}
                {ri === 2 && <div style={{ width: 4 }} />}
                {ri === 2 && key("⌫", 62, true, "⌫")}
              </div>
            ))}
            <div style={{ display: "flex", gap }}>
              {key("123", 62, true, "123")}
              {key("EN", 62, true, "EN")}
              {key(" ", 230, false, <span />)}
              {key("↩", 110, true, "↩")}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

const Caption: React.FC<{ top: string; big: string; small?: string; opacity: number }> = ({ top, big, small, opacity }) => (
  <div style={{ opacity }}>
    <div style={{ fontSize: 34, color: "#A1A1AA", marginBottom: 14 }}>{top}</div>
    <div style={{ fontSize: 76, fontWeight: 700, color: "white", lineHeight: 1.25 }}>{big}</div>
    {small && <div style={{ fontSize: 34, color: ACCENT, marginTop: 14 }}>{small}</div>}
  </div>
);

const Typing: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  let t = f - TYPE_START;
  let committed = "";
  let buffer = "";
  let guesses: string[] = [];
  let pressed: string | null = null;
  let pressAmt = 0;
  let idx = 0;
  let local = 0;
  for (let i = 0; i < PHRASES.length; i++) {
    const p = PHRASES[i];
    const len = phraseLen(p);
    if (t < len || i === PHRASES.length - 1) {
      idx = i; local = t;
      const typedN = Math.max(0, Math.min(p.typed.length, Math.floor(t / PER_LETTER) + 1));
      const spaceAt = p.typed.length * PER_LETTER + HOLD;
      if (t < 0) { buffer = ""; }
      else if (t < spaceAt) {
        buffer = p.typed.slice(0, typedN);
        guesses = (cands as Record<string, string[][]>)[p.typed][typedN - 1];
        if (t < p.typed.length * PER_LETTER) { pressed = p.typed[typedN - 1]; pressAmt = 1 - (t % PER_LETTER) / PER_LETTER; }
      } else {
        committed += p.thai + " ";
        if (t < spaceAt + 4) { pressed = " "; pressAmt = 1; }
      }
      break;
    }
    committed += p.thai + " ";
    t -= len;
  }
  const p = PHRASES[idx];
  const capOpacity = interpolate(local, [0, 10], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const spaceAt = p.typed.length * PER_LETTER + HOLD;
  const showThai = local >= spaceAt;
  const enter = spring({ frame: f, fps, config: { damping: 200 } });
  return (
    <AbsoluteFill style={{ opacity: fade(f, TYPE_DUR, 1, 14) }}>
      <div style={{ position: "absolute", right: 240, top: 40, transform: `translateY(${(1 - enter) * 80}px)`, opacity: enter }}>
        <Phone committed={committed.trim()} buffer={buffer} guesses={guesses} pressed={pressed} pressAmt={pressAmt} />
      </div>
      <div style={{ position: "absolute", left: 160, top: 360, width: 900 }}>
        <Caption
          top={showThai ? "You get" : "You type"}
          big={showThai ? p.thai : p.typed.slice(0, Math.max(0, Math.min(p.typed.length, Math.floor(Math.max(local, 0) / PER_LETTER) + 1)))}
          small={showThai ? `“${p.meaning}” · Space picks the first guess` : "Thai guesses update with every letter"}
          opacity={capOpacity}
        />
      </div>
    </AbsoluteFill>
  );
};

const VARIANT_ROWS: [string[], string][] = [
  [["krap", "khrap", "krub"], "ครับ"],
  [["sawasdee", "sawatdi", "sawaddee"], "สวัสดี"],
  [["khun", "khoon"], "คุณ"],
];

const Variants: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  return (
    <AbsoluteFill style={{ justifyContent: "center", alignItems: "center", opacity: fade(f, VARIANTS) }}>
      <div style={{ fontSize: 72, fontWeight: 800, color: "white", marginBottom: 70 }}>Spell it your way</div>
      <div style={{ display: "flex", flexDirection: "column", gap: 40 }}>
        {VARIANT_ROWS.map(([spellings, th], i) => {
          const s = spring({ frame: f - 15 - i * 18, fps, config: { damping: 200 } });
          return (
            <div key={th} style={{ display: "flex", alignItems: "center", gap: 36, opacity: s, transform: `translateX(${(1 - s) * -60}px)` }}>
              <div style={{ display: "flex", gap: 16, width: 860, justifyContent: "flex-end" }}>
                {spellings.map((sp) => (
                  <span key={sp} style={{ fontSize: 46, color: "#E4E4E7", background: "#26262C", borderRadius: 16, padding: "10px 24px" }}>{sp}</span>
                ))}
              </div>
              <span style={{ fontSize: 50, color: "#71717A" }}>→</span>
              <span style={{ fontSize: 70, fontWeight: 700, color: ACCENT, width: 400 }}>{th}</span>
            </div>
          );
        })}
      </div>
      <div style={{ fontSize: 34, color: "#A1A1AA", marginTop: 70, opacity: interpolate(f, [80, 95], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }) }}>
        Typos, missing tones and chat spellings all still find the right word.
      </div>
    </AbsoluteFill>
  );
};

const Platforms: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame: f, fps, config: { damping: 200 } });
  const items = [
    ["iPhone & iPad", "A keyboard for every app"],
    ["Mac", "An input method for every app"],
    ["Private", "Works offline. Nothing leaves your device."],
  ];
  return (
    <AbsoluteFill style={{ opacity: fade(f, PLATFORMS) }}>
      <div style={{ position: "absolute", left: 160, top: 250, display: "flex", flexDirection: "column", gap: 54 }}>
        {items.map(([a, b], i) => {
          const si = spring({ frame: f - 10 - i * 14, fps, config: { damping: 200 } });
          return (
            <div key={a} style={{ opacity: si, transform: `translateY(${(1 - si) * 30}px)` }}>
              <div style={{ fontSize: 64, fontWeight: 800, color: "white" }}>{a}</div>
              <div style={{ fontSize: 36, color: "#A1A1AA", marginTop: 6 }}>{b}</div>
            </div>
          );
        })}
      </div>
      <div style={{
        position: "absolute", right: 260, top: 50, borderRadius: 64, overflow: "hidden", border: "14px solid #1C1C1E",
        boxShadow: "0 40px 120px rgba(0,0,0,0.6)", transform: `translateY(${(1 - s) * 80}px) rotate(${(1 - s) * 3}deg)`, opacity: s,
      }}>
        <Img src={staticFile("shot.png")} style={{ height: 950, display: "block" }} />
      </div>
    </AbsoluteFill>
  );
};

const End: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame: f, fps, config: { damping: 200 } });
  return (
    <AbsoluteFill style={{ justifyContent: "center", alignItems: "center", opacity: fade(f, END, 12, 1) }}>
      <div style={{ fontSize: 110, fontWeight: 800, color: "white", letterSpacing: -3, opacity: s, transform: `scale(${0.94 + 0.06 * s})` }}>
        Karaoke Thai Keyboard
      </div>
      <div style={{ fontSize: 40, color: "#A1A1AA", marginTop: 30, opacity: interpolate(f, [15, 30], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }) }}>
        iPhone & iPad · Mac · Open source (GPL-3.0)
      </div>
      <div style={{ fontSize: 36, color: ACCENT, marginTop: 22, opacity: interpolate(f, [30, 45], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }) }}>
        github.com/CapClark/karaoke-thai-keyboard-app
      </div>
    </AbsoluteFill>
  );
};

export const Demo: React.FC = () => {
  let at = 0;
  const seq = (dur: number, el: React.ReactNode) => {
    const s = <Sequence from={at} durationInFrames={dur}>{el}</Sequence>;
    at += dur;
    return s;
  };
  return (
    <AbsoluteFill style={{ background: `radial-gradient(ellipse at 30% 20%, #1B2233 0%, ${BG} 60%)`, fontFamily: FONT }}>
      {seq(INTRO, <Intro />)}
      {seq(TYPE_DUR, <Typing />)}
      {seq(VARIANTS, <Variants />)}
      {seq(PLATFORMS, <Platforms />)}
      {seq(END, <End />)}
    </AbsoluteFill>
  );
};

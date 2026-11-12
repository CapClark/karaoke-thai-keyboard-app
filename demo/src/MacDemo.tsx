import React from "react";
import { AbsoluteFill, OffthreadVideo, Sequence, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { Effects, Music, Sfx } from "./Sound";
import macEvents from "./macEvents.json";
import { loadFont as loadInter } from "@remotion/google-fonts/Inter";
import { loadFont as loadThai } from "@remotion/google-fonts/NotoSansThai";

const { fontFamily: inter } = loadInter("normal", { weights: ["400", "600", "800"], subsets: ["latin"] });
const { fontFamily: thai } = loadThai("normal", { weights: ["400", "600"], subsets: ["thai"] });
const FONT = `${inter}, ${thai}, sans-serif`;
const ACCENT = "#5AC8FA";

// A real screen recording (demo/public/mac-recording.mp4): Karaoke Thai typing in TextEdit.
const REC_SECONDS = 19;
const INTRO = 75;
const END = 150;
export const MAC_TOTAL = INTRO + REC_SECONDS * 30 + END;

// When each phrase is being typed in the recording (seconds), for the caption.
const CAPTIONS: [number, number, string, string, string][] = [
  [0.6, 5.0, "sawatdeekrap", "สวัสดีครับ", "hello"],
  [5.0, 9.4, "kinkhaoreuyang", "กินข้าวหรือยัง", "have you eaten yet?"],
  [9.4, 13.9, "khobkhunmakkrap", "ขอบคุณมากครับ", "thank you very much"],
  [13.9, 19, "pomrakkun", "ผมรักคุณ", "I love you"],
];

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

const Intro: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame: f, fps, config: { damping: 200 } });
  return (
    <AbsoluteFill style={{ justifyContent: "center", alignItems: "center", opacity: interpolate(f, [INTRO - 12, INTRO], [1, 0], clamp) }}>
      <div style={{ fontSize: 110, fontWeight: 800, color: "white", letterSpacing: -3, opacity: s, transform: `translateY(${(1 - s) * 40}px)` }}>
        Karaoke Thai for Mac
      </div>
      <div style={{ fontSize: 46, color: "#A1A1AA", marginTop: 22, opacity: interpolate(f, [12, 26], [0, 1], clamp) }}>
        Type Thai by sound, in every app.
      </div>
    </AbsoluteFill>
  );
};

const Recording: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = f / fps;
  const s = spring({ frame: f, fps, config: { damping: 200 } });
  const cap = CAPTIONS.find(([a, b]) => t >= a && t < b);
  const capIn = cap ? interpolate(t, [cap[0], cap[0] + 0.3], [0, 1], clamp) : 0;
  return (
    <AbsoluteFill style={{ alignItems: "center", opacity: interpolate(f, [REC_SECONDS * 30 - 12, REC_SECONDS * 30], [1, 0], clamp) }}>
      <div style={{ marginTop: 50, height: 70, fontSize: 40, color: "white", opacity: capIn, display: "flex", gap: 22, alignItems: "baseline" }}>
        {cap && (<>
          <span style={{ color: "#A1A1AA" }}>{cap[2]}</span>
          <span style={{ color: "#71717A" }}>→</span>
          <span style={{ fontWeight: 600, color: ACCENT }}>{cap[3]}</span>
          <span style={{ color: "#A1A1AA", fontSize: 32 }}>“{cap[4]}”</span>
        </>)}
      </div>
      <div style={{
        marginTop: 20, width: 1600, height: 900, borderRadius: 18, overflow: "hidden",
        boxShadow: "0 40px 120px rgba(0,0,0,0.6)", border: "1px solid #333",
        transform: `scale(${0.96 + 0.04 * s})`, opacity: s,
      }}>
        <OffthreadVideo src={staticFile("mac-recording.mp4")} muted style={{ width: "100%", height: "100%" }} />
      </div>
    </AbsoluteFill>
  );
};

const End: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame: f, fps, config: { damping: 200 } });
  const lines = ["Space picks the first guess · 1–9 pick others", "Tap Shift alone for English", "Free download · macOS 13 or later"];
  return (
    <AbsoluteFill style={{ justifyContent: "center", alignItems: "center" }}>
      <div style={{ fontSize: 96, fontWeight: 800, color: "white", letterSpacing: -2, opacity: s }}>Karaoke Thai for Mac</div>
      <div style={{ marginTop: 34, display: "flex", flexDirection: "column", alignItems: "center", gap: 14 }}>
        {lines.map((l, i) => (
          <div key={l} style={{ fontSize: 40, color: "#D4D4D8", opacity: interpolate(f, [12 + i * 10, 26 + i * 10], [0, 1], clamp) }}>{l}</div>
        ))}
      </div>
      <div style={{ fontSize: 36, color: ACCENT, marginTop: 34, opacity: interpolate(f, [50, 64], [0, 1], clamp) }}>
        capclark.github.io/karaoke-thai-keyboard
      </div>
      <div style={{ position: "absolute", bottom: 40, fontSize: 22, color: "#71717A" }}>
        Music: “Sunset Drive” by Tokyo Music Walker (CC BY 3.0)
      </div>
    </AbsoluteFill>
  );
};

export const MacDemo: React.FC = () => (
  <AbsoluteFill style={{ background: "radial-gradient(ellipse at 30% 20%, #1B2233 0%, #0E0E12 60%)", fontFamily: FONT }}>
    <Sequence durationInFrames={INTRO}><Intro /></Sequence>
    <Sequence from={INTRO} durationInFrames={REC_SECONDS * 30}><Recording /></Sequence>
    <Sequence from={INTRO + REC_SECONDS * 30} durationInFrames={END}><End /></Sequence>
    <Music dropAt={INTRO} total={MAC_TOTAL} />
    <Effects events={[
      [INTRO - 6, "whoosh"], [INTRO + REC_SECONDS * 30 - 6, "whoosh"],
      // Key presses in the recording (seconds), from demo/mac/run.sh's typing script.
      ...(macEvents as [number, Sfx][]).map(([sec, kind]) => [INTRO + sec * 30, kind] as [number, Sfx]),
    ]} />
  </AbsoluteFill>
);

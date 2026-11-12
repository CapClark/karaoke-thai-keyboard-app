import React from "react";
import { Audio, Sequence, interpolate, staticFile, useVideoConfig } from "remotion";

// Music: "Sunset Drive" by Tokyo Music Walker (CC BY 3.0, see CREDITS.md). Its beat comes in
// 5.3 s into the track, so `dropAt` (frame) lines the beat up with the first typing.
export const Music: React.FC<{ dropAt: number; total: number; volume?: number }> = ({ dropAt, total, volume = 0.32 }) => {
  const { fps } = useVideoConfig();
  const startFrom = Math.max(0, Math.round(5.3 * fps) - dropAt);
  return (
    <Audio
      src={staticFile("sunset-drive.mp3")}
      startFrom={startFrom}
      volume={(f) =>
        volume * interpolate(f, [0, 15, total - 45, total - 1], [0, 1, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" })}
    />
  );
};

export type Sfx = "key" | "space" | "return" | "whoosh";
const FILE: Record<Sfx, string[]> = {
  key: ["key1.wav", "key2.wav", "key3.wav"],
  space: ["pick.wav"],
  return: ["return.wav"],
  whoosh: ["whoosh.wav"],
};
const VOL: Record<Sfx, number> = { key: 0.55, space: 0.32, return: 0.5, whoosh: 0.22 };

// Sound effects at given frames (synthesized by sfx/make_sfx.py).
export const Effects: React.FC<{ events: [number, Sfx][] }> = ({ events }) => (
  <>
    {events.map(([frame, kind], i) => (
      <Sequence key={i} from={Math.max(0, Math.round(frame))} durationInFrames={24} layout="none">
        <Audio src={staticFile(FILE[kind][i % FILE[kind].length])} volume={VOL[kind]} />
      </Sequence>
    ))}
  </>
);

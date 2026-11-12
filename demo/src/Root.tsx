import { Composition } from "remotion";
import { Demo, TOTAL } from "./Demo";
import { MacDemo, MAC_TOTAL } from "./MacDemo";

export const Root = () => (
  <>
    <Composition id="Demo" component={Demo} durationInFrames={TOTAL} fps={30} width={1920} height={1080} />
    <Composition id="MacDemo" component={MacDemo} durationInFrames={MAC_TOTAL} fps={30} width={1920} height={1080} />
  </>
);

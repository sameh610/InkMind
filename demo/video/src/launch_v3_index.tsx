import React from 'react';
import {Composition, registerRoot} from 'remotion';
import {LaunchV3, LAUNCH_FRAMES} from './launch_v3';

// Keep unfinished capture/voice dependencies out of the existing trailer.
const LaunchRoot: React.FC = () => <>
  <Composition id="InkMindLaunchV3Clean" component={LaunchV3} width={1920} height={1080} fps={30} durationInFrames={LAUNCH_FRAMES} defaultProps={{showCaptions:false}}/>
  <Composition id="InkMindLaunchV3" component={LaunchV3} width={1920} height={1080} fps={30} durationInFrames={LAUNCH_FRAMES} defaultProps={{showCaptions:true}}/>
</>;
registerRoot(LaunchRoot);

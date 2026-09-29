import React from 'react';
import {Composition} from 'remotion';
import type {Caption} from '@remotion/captions';
import {InkMindFilm, TRAILER_FRAMES} from './video';
import captions from './captions.json';

export const Root: React.FC = () => (
  <>
    <Composition
      id="InkMindShipaton"
      component={InkMindFilm}
      width={1920}
      height={1080}
      fps={30}
      durationInFrames={TRAILER_FRAMES}
      defaultProps={{
        narration: 'audio/narration.mp3',
        music: 'audio/inkmind-score-action.wav',
        soundDesign: 'audio/sound-design-action.wav',
        captions: captions as Caption[],
        showCaptions: true,
      }}
    />
    <Composition
      id="InkMindShipatonClean"
      component={InkMindFilm}
      width={1920}
      height={1080}
      fps={30}
      durationInFrames={TRAILER_FRAMES}
      defaultProps={{
        narration: 'audio/narration.mp3',
        music: 'audio/inkmind-score-action.wav',
        soundDesign: 'audio/sound-design-action.wav',
        captions: captions as Caption[],
        showCaptions: false,
      }}
    />
  </>
);

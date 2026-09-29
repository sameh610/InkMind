import React from 'react';
import {AbsoluteFill, Audio, Easing, OffthreadVideo, Sequence, interpolate, staticFile, useCurrentFrame} from 'remotion';
import type {Caption} from '@remotion/captions';
import edit from '../action-cut.json';

type Props = {narration: string; music: string; soundDesign: string; captions: Caption[]; showCaptions: boolean};
export type Shot = {
  from: number; to: number; clip: string; source: number; rate?: number;
  zoom?: number; endZoom?: number; focus?: [number, number]; endFocus?: [number, number]; label?: string;
};
const fps = 30;
const frame = (seconds: number) => Math.round(seconds * fps);
export const TRAILER_FRAMES = 2340; // 78.000 seconds at 30 fps; the score is 128 BPM.
const voiceStartFrame = frame(75.1);
const paper = '#f8f4ea';
const green = '#203a30';
const copper = '#bd6744';
const shots = edit.shots as Shot[];

export const SourceShot: React.FC<{shot: Shot}> = ({shot}) => {
  const local = useCurrentFrame();
  const frames = Math.max(1, frame(shot.to) - frame(shot.from));
  const progress = interpolate(local, [0, frames], [0, 1], {
    extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.inOut(Easing.quad),
  });
  const zoom = (shot.zoom ?? 1.25) + ((shot.endZoom ?? shot.zoom ?? 1.25) - (shot.zoom ?? 1.25)) * progress;
  const focusX = (shot.focus?.[0] ?? .5) + ((shot.endFocus?.[0] ?? shot.focus?.[0] ?? .5) - (shot.focus?.[0] ?? .5)) * progress;
  const focusY = (shot.focus?.[1] ?? .5) + ((shot.endFocus?.[1] ?? shot.focus?.[1] ?? .5) - (shot.focus?.[1] ?? .5)) * progress;
  const dx = (0.5 - focusX) * 1920 * zoom;
  const dy = (0.5 - focusY) * 1080 * zoom;
  return <AbsoluteFill style={{background: paper, overflow: 'hidden'}}>
    <OffthreadVideo
      src={staticFile(shot.clip)}
      startFrom={frame(shot.source)}
      playbackRate={shot.rate ?? 1}
      muted
      style={{
        width: '100%', height: '100%', objectFit: 'cover',
        transform: `translate(${dx}px, ${dy}px) scale(${zoom})`,
        filter: 'contrast(1.055) saturate(1.10)',
      }}
    />
    {shot.label && <div style={{
      position: 'absolute', left: 54, bottom: 62, padding: '11px 15px 10px',
      background: 'rgba(248,244,234,.90)', borderLeft: `3px solid ${copper}`,
      color: green, fontFamily: 'Arial, sans-serif', fontWeight: 700,
      fontSize: 17, letterSpacing: 1.8, textTransform: 'uppercase',
    }}>{shot.label}</div>}
  </AbsoluteFill>;
};

const chapters = [
  {from: 0, to: 8.44, text: '01 / ANIMATE INK'},
  {from: 8.44, to: 16.88, text: '02 / INKMATTER'},
  {from: 16.88, to: 27.19, text: '03 / INKDEBUG'},
  {from: 27.19, to: 36.56, text: '04 / NEW VISUAL'},
  {from: 36.56, to: 54.38, text: '05 / ORIGINAL STROKES'},
  {from: 54.38, to: 65.63, text: '06 / INKSCRIPT + LOCAL AI'},
  {from: 65.63, to: 75, text: 'INKMIND / IN MOTION'},
];
const ChapterRail: React.FC = () => {
  const global = useCurrentFrame() / fps;
  const chapter = chapters.find((item) => global >= item.from && global < item.to);
  if (!chapter) return null;
  return <div style={{
    position: 'absolute', top: 42, right: 56, display: 'flex', alignItems: 'center', gap: 12,
    padding: '9px 12px', borderRadius: 4, background: 'rgba(248,244,234,.80)',
    color: green, fontFamily: 'Arial, sans-serif', fontSize: 13, fontWeight: 800,
    letterSpacing: 2.2, pointerEvents: 'none',
  }}><span style={{width: 26, height: 2, background: copper}} />{chapter.text}</div>;
};

type Hit = {from: number; to: number; text: string};
const hits: Hit[] = [
  {from: 0, to: .9, text: 'DRAW IT.'},
  {from: 7.77, to: 8.43, text: 'MOVE IT.'},
  {from: 13.60, to: 14.53, text: 'CHANGE THE RULES.'},
  {from: 26.25, to: 27.12, text: 'DEBUG YOUR THINKING.'},
  {from: 33.75, to: 34.66, text: 'TOUCH THE EQUATION.'},
  {from: 43.13, to: 44.03, text: 'YOUR INK. STILL YOUR INK.'},
  {from: 58.13, to: 59.03, text: 'PROGRAM THE STROKES.'},
  {from: 61.88, to: 62.78, text: 'YOUR MODEL. YOUR DEVICE.'},
  {from: 66.56, to: 67.26, text: 'DRAW.'},
  {from: 69.38, to: 70.08, text: 'THINK.'},
  {from: 72.19, to: 72.89, text: 'RUN.'},
];
export const TextHit: React.FC<{hit: Hit}> = ({hit}) => {
  const local = useCurrentFrame();
  const length = Math.max(1, frame(hit.to) - frame(hit.from));
  const appear = interpolate(local, [0, 5], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  const leave = interpolate(local, [Math.max(0, length - 5), length], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  const move = interpolate(local, [0, 8], [14, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.out(Easing.cubic)});
  return <div style={{
    position: 'absolute', left: 72, top: 148, maxWidth: 660, pointerEvents: 'none',
    opacity: appear * leave, transform: `translateY(${move}px)`,
    color: green, fontFamily: 'Arial, sans-serif', fontWeight: 900,
    fontSize: hit.text.length > 17 ? 39 : 49, lineHeight: 1, letterSpacing: -1.1,
    textShadow: '0 1px 12px rgba(248,244,234,.94), 0 1px 29px rgba(248,244,234,.88)',
  }}>{hit.text}</div>;
};

export const ClosingCard: React.FC = () => {
  const local = useCurrentFrame();
  const pop = interpolate(local, [0, 10], [.93, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.out(Easing.cubic)});
  const alpha = interpolate(local, [0, 8], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  const underline = interpolate(local, [2, 25], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  return <AbsoluteFill style={{
    background: 'radial-gradient(circle at 50% 40%, #315848, #203a30 65%, #142a22)',
    overflow: 'hidden', justifyContent: 'center', alignItems: 'center',
  }}>
    <div style={{position: 'absolute', inset: 0, backgroundImage: 'radial-gradient(#f8f4ea 0.6px, transparent 0.8px)', backgroundSize: '8px 8px', opacity: .09}} />
    <div style={{textAlign: 'center', opacity: alpha, transform: `scale(${pop})`}}>
      <div style={{color: paper, fontFamily: 'Georgia, serif', fontSize: 130, letterSpacing: -5, lineHeight: 1}}>InkMind<span style={{color: '#e58b63'}}>.</span></div>
      <div style={{height: 3, width: 130 * underline, background: '#e58b63', margin: '26px auto 0'}} />
      <div style={{color: paper, fontFamily: 'Georgia, serif', fontSize: 33, marginTop: 28}}>Paper you can think with.</div>
    </div>
  </AbsoluteFill>;
};

export const CaptionLayer: React.FC<{captions: Caption[]}> = ({captions}) => {
  const ms = useCurrentFrame() / fps * 1000;
  const cue = captions.find((item) => ms >= item.startMs && ms < item.endMs);
  if (!cue) return null;
  return <AbsoluteFill style={{pointerEvents: 'none', justifyContent: 'flex-end', alignItems: 'center', paddingBottom: 70}}>
    <div style={{padding: '10px 17px', color: paper, background: 'rgba(10,26,20,.84)', borderRadius: 7, fontFamily: 'Arial, sans-serif', fontSize: 32}}>{cue.text}</div>
  </AbsoluteFill>;
};
const musicVolume = (f: number) => {
  const duck = interpolate(f, [voiceStartFrame - 8, voiceStartFrame + 6], [.92, .23], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  const fade = interpolate(f, [TRAILER_FRAMES - 12, TRAILER_FRAMES], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  return duck * fade;
};
export const InkMindFilm: React.FC<Props> = ({narration, music, soundDesign, captions, showCaptions}) => (
  <AbsoluteFill style={{background: paper}}>
    {shots.map((shot, index) => <Sequence key={index} from={frame(shot.from)} durationInFrames={frame(shot.to) - frame(shot.from)}><SourceShot shot={shot} /></Sequence>)}
    <Sequence from={frame(75)} durationInFrames={TRAILER_FRAMES - frame(75)}><ClosingCard /></Sequence>
    <Sequence durationInFrames={TRAILER_FRAMES}>
      <Audio src={staticFile(music)} volume={musicVolume} />
      <Audio src={staticFile(soundDesign)} volume={.72} />
    </Sequence>
    <Sequence from={voiceStartFrame} durationInFrames={TRAILER_FRAMES - voiceStartFrame}>
      <Audio src={staticFile(narration)} startFrom={2423} volume={1} />
    </Sequence>
    {hits.map((hit, index) => <Sequence key={index} from={frame(hit.from)} durationInFrames={frame(hit.to) - frame(hit.from)}><TextHit hit={hit} /></Sequence>)}
    <ChapterRail />
    {showCaptions && <CaptionLayer captions={captions} />}
  </AbsoluteFill>
);

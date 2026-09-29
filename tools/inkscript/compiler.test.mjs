import test from 'node:test';
import assert from 'node:assert/strict';
import { compileInkScript } from './compiler.js';

test('shared pivots compile for groups and reject unsafe coordinates',()=>{
  const make=p=>`export default function Animation(){const body=ink.selection(${p});animate(({time})=>{body.rotation=Math.sin(time);});}`;
  const result=compileInkScript(make('{pivotX:100,pivotY:20}'));
  assert.equal(result.ok,true);
  assert.equal(result.ir.bindings[0].pivotX,100);
  assert.equal(result.ir.bindings[0].pivotY,20);
  assert.equal(compileInkScript(make('{pivotX:999999999}')).ok,false);
  assert.equal(compileInkScript(make('{pivotX:"bad"}')).ok,false);
});

const visual = `export default function Visual() {
  const gravity = state(9.81);
  const length = state(2);
  return <App title="Pendulum Lab"><Pendulum gravity={gravity} length={length} showTrail />
    <Controls><Slider label="Gravity" value={gravity} min={1} max={25} unit="m/s²" /></Controls></App>;
}`;
const animation = `export default function Animation() {
  const bird = ink.selection();
  const wing = bird.group("wing");
  animate(({ time }) => {
    wing.rotation = Math.sin(time * 3) * 25;
    bird.y = bird.baseY + Math.sin(time) * 8;
  });
}`;

test('visual TSX becomes declarative IR with reactive state', () => {
  const result = compileInkScript(visual);
  assert.equal(result.ok, true, JSON.stringify(result.errors));
  assert.equal(result.ir.root.type, 'App');
  assert.equal(result.ir.root.children[0].type, 'Pendulum');
  assert.deepEqual(result.ir.state.map(x => x.name), ['gravity', 'length']);
});

test('animation binds existing ink and compiles expressions', () => {
  const result = compileInkScript(animation);
  assert.equal(result.ok, true, JSON.stringify(result.errors));
  assert.equal(result.ir.mode, 'animateInk');
  assert.equal(result.ir.bindings[1].selector, 'group');
  assert.equal(result.ir.animations[0].property, 'rotation');
});

test('unsafe calls and props are rejected', () => {
  for (const source of [
    'export default function Visual(){return <App onClick={evil()}/>;}',
    'export default function Visual(){return <App><Text text={fetch("x")}/></App>;}',
    'export default function Visual(){return <App><NativeWeb html="x"/></App>;}',
  ]) assert.equal(compileInkScript(source).ok, false);
});

test('normalizes minor model mistakes and produces repair diagnostics', () => {
  const fixed = compileInkScript('export default function Visual(){const x=state(1);return <App><slider value={x} min={9} max={1}/></App>;}');
  assert.equal(fixed.ok, true);
  assert.equal(fixed.ir.root.children[0].type, 'Slider');
  assert.equal(fixed.ir.root.children[0].props.min.value, 1);
  const bad = compileInkScript('export default function Visual(){return <App><Slidr/></App>;}');
  assert.equal(bad.ok, false);
  assert.match(bad.repairPrompt, /Slider/);
});

test('malformed model text returns diagnostics instead of throwing', () => {
  let seed=73;
  const alphabet='{}<>/()=;"\'abc123stateAppSlider';
  for(let n=0;n<120;n++) {
    seed=(seed*1664525+1013904223)>>>0;
    const source=Array.from({length:seed%180},(_,i)=>alphabet[(seed+i*17)%alphabet.length]).join('');
    const result=compileInkScript(source);
    assert.equal(typeof result.ok,'boolean');
    if(!result.ok) assert.ok(result.errors[0].code);
  }
});

test('derived const remains reactive and bare numeric JSX props normalize', () => {
  const source='export default function Visual(){const x=state(2);const y=x*x+3*x-2;return <App><Number value={y}/><Slider value={x} min=-3 max=3/></App>;}';
  const result=compileInkScript(source);
  assert.equal(result.ok,true,JSON.stringify(result.errors));
  assert.equal(result.ir.state[1].expression.kind,'binary');
  assert.match(result.source,/min=\{-3\}/);
  assert.ok(result.warnings.some(w=>w.code==='INK007'));
});

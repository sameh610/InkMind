import test from 'node:test';
import assert from 'node:assert/strict';
import {verifiedLinearDebug,explicitProjectile} from './grounded_math.js';
test('finds the first divergence and computes the correction',()=>{
  const result=verifiedLinearDebug('3x + 5 = 20\n3x = 25\nx = 8.33');
  assert.equal(result.firstError,1);assert.deepEqual(result.corrected,['3x = 15','x = 5']);
});
test('does not accuse correct reasoning or guess unsupported expressions',()=>{
  assert.equal(verifiedLinearDebug('2x - 4 = 8\n2x = 12\nx = 6').firstError,null);
  assert.equal(verifiedLinearDebug('x^2 = 4\nx = 2'),null);
  assert.equal(verifiedLinearDebug('unclear'),null);
});
test('preserves explicit projectile values and rejects missing units',()=>{
  assert.deepEqual([explicitProjectile('Projectile: 20 m/s, 45°').velocity,explicitProjectile('Projectile: 20 m/s, 45°').angle],[20,45]);
  assert.equal(explicitProjectile('Projectile simulation'),null);
});

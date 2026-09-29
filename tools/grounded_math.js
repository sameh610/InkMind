// Verified arithmetic after transcription. Unsupported notation stays on the
// model path; this checker never supplies a guessed equation or coefficient.
function linearSide(source) {
  const text = source.replace(/\s|\*/g, '').replace(/−/g, '-');
  if (!text || /[^0-9.x+\-]/i.test(text)) return null;
  const terms = text.match(/[+-]?[^+-]+/g) || [];
  let a = 0, b = 0;
  for (const term of terms) {
    if (/^[+-]?(?:\d+(?:\.\d*)?|\.\d+)?x$/i.test(term)) {
      const coefficient = term.slice(0,-1);
      a += coefficient === '' || coefficient === '+' ? 1 : coefficient === '-' ? -1 : Number(coefficient);
    } else if (/^[+-]?(?:\d+(?:\.\d*)?|\.\d+)$/.test(term)) b += Number(term);
    else return null;
  }
  return {a,b};
}
const fmt = n => String(Number(n.toFixed(6)));
export function verifiedLinearDebug(source) {
  const steps = String(source).split(/\r?\n/).map(s => s.trim()).filter(Boolean);
  if (steps.length < 2 || steps.length > 32) return null;
  const equations = steps.map(line => {
    const sides = line.split('=');
    if (sides.length !== 2) return null;
    const l = linearSide(sides[0]), r = linearSide(sides[1]);
    if (!l || !r || Math.abs(l.a-r.a) < 1e-9) return null;
    return {a:l.a-r.a, b:r.b-l.b, l, r};
  });
  if (equations.some(e => !e)) return null;
  const first = equations[0], solution = first.b/first.a;
  const index = equations.findIndex(e => Math.abs(e.b/e.a-solution) > .015);
  const explanation = index < 0 ? `Each step preserves x = ${fmt(solution)}.` :
    `${fmt(first.r.b)} ${first.l.b >= 0 ? '−' : '+'} ${fmt(Math.abs(first.l.b))} = ${fmt(first.b)}. Step ${index+1} is the first transition that changes the solution.`;
  return {steps,firstError:index < 0 ? null : index,explanation,
    corrected:index < 0 ? [] : [`${fmt(first.a)}x = ${fmt(first.b)}`,`x = ${fmt(solution)}`]};
}

export function explicitProjectile(source) {
  const text = String(source);
  if (!/\bprojectile\b/i.test(text)) return null;
  const velocity = text.match(/([0-9]+(?:\.[0-9]+)?)\s*m\s*\/\s*s\b/i);
  const angle = text.match(/([0-9]+(?:\.[0-9]+)?)\s*(?:°|degrees?\b)/i);
  if (!velocity || !angle) return null;
  const v = Number(velocity[1]), a = Number(angle[1]);
  if (v < 2 || v > 60 || a < 5 || a > 85) return null;
  return {kind:'Projectile',title:'Projectile lab',caption:`${v} m/s · ${a}° · drag to explore`,velocity:v,angle:a};
}

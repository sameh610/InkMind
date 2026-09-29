const fs = require('node:fs');
const path = require('node:path');

// The edit is expressed in musical sections. Every boundary is a 30 fps frame,
// so hard cuts do not leave a black frame between two real interaction takes.
const root = path.resolve(__dirname, '..');
const clip = {
  ink: 'footage/inkmind-action-ink.webm',
  debug: 'footage/inkmind-action-debug.webm',
  visual: 'footage/inkmind-action-visual.webm',
  bird: 'footage/inkmind-action-bird.webm',
  code: 'footage/inkmind-action-code.webm',
  models: 'footage/inkmind-action-models.webm',
  older: 'footage/inkmind-demo.webm',
};
const shots = [];
let from = 0;
function add(to, key, source, rate = 1, zoom = 1.55, focus = [.5, .5], label) {
  if (to <= from) throw Error(`Invalid cut at ${to}`);
  const item = {from, to, clip: clip[key], source, rate, zoom, focus};
  if (label) item.label = label;
  shots.push(item);
  from = to;
}

// 00:00–00:16.88 — a real selection and instruction, original ink in motion,
// followed by the handwritten Moon lifting and changing the running physics.
add(.94, 'ink', 1.55, 1, 1.85, [.5, .42]);
add(2.82, 'ink', 2.58, 1.35, 1.65, [.5, .43]);
add(3.75, 'ink', 5.15, 1, 1.42, [.5, .45], '3 original strokes selected');
add(4.69, 'ink', 6.6, 1, 1.13, [.5, .52]);
add(5.63, 'ink', 11.08, 1, 1.52, [.5, .51]);
add(6.56, 'ink', 12.06, 1, 1.4, [.5, .43]);
add(8.44, 'ink', 119.86, 1, 1.7, [.5, .5]);
add(9.38, 'ink', 122.15, 1, 1.44, [.5, .59]);
add(10.31, 'ink', 123.15, 1, 1.32, [.46, .58]);
add(12.66, 'ink', 124.05, 1.27, 1.27, [.5, .55]);
add(13.59, 'ink', 127, 1, 1.3, [.5, .57]);
add(15, 'ink', 127.93, 1, 1.23, [.5, .59], 'g = 1.62 m/s²');
add(16.88, 'ink', 129.4, 1, 1.3, [.5, .54]);

// 00:16.88–00:27.19 — lasso, Debug tap, actual reasoning rewind, divergence,
// and the corrected branch appearing in the app. No substitute panel.
add(18.28, 'debug', 3.3, 1, 1.6, [.43, .33]);
add(20.63, 'debug', 4.48, 1.2, 1.55, [.46, .37]);
add(21.56, 'debug', 7.14, 1, 1.13, [.51, .55]);
add(22.5, 'debug', 156.05, .9, 1.3, [.5, .56]);
add(24.38, 'debug', 156.45, .74, 1.45, [.5, .57]);
add(26.25, 'debug', 157.47, .78, 1.35, [.5, .56]);
add(27.19, 'debug', 159.16, 1, 1.3, [.5, .56], 'first divergence · step 2');

// 00:27.19–00:36.56 — exact selected equation, New Visual, graph reveal,
// and a real change from coefficient 3.0 to -3.6.
add(28.13, 'visual', 3.9, 1, 1.64, [.46, .36]);
add(30, 'visual', 4.4, 1.18, 1.5, [.47, .39]);
add(30.94, 'visual', 6.4, 1, 1.48, [.47, .39]);
add(31.88, 'visual', 7.0, 1, 1.13, [.51, .55]);
add(32.81, 'visual', 7.9, 1, 1.22, [.5, .5]);
add(33.75, 'visual', 8.75, 1, 1.28, [.5, .51]);
add(35.63, 'visual', 9.37, 1.48, 1.38, [.5, .56]);
add(36.56, 'visual', 12.18, 1.25, 1.38, [.5, .56]);

// 00:36.56–00:46.88 — a second original drawing responds to a separate
// instruction. The model wait is elided; input and output are continuous takes.
add(38.44, 'bird', 4.4, 1.12, 1.7, [.49, .43]);
add(40.31, 'bird', 6.0, 1.05, 1.65, [.5, .48]);
add(41.25, 'bird', 7.28, 1, 1.4, [.5, .5]);
add(43.13, 'bird', 55.92, 1, 1.42, [.69, .5]);
add(45, 'bird', 57.45, 1, 1.39, [.68, .5]);
add(46.88, 'bird', 59.3, 1, 1.39, [.56, .5]);

// 00:46.88–00:54.38 — four verified, different behaviors in quick succession.
// The attempted ball take did not finish, so no ball result is represented.
add(48.75, 'bird', 58.5, 1, 1.36, [.56, .5]);
add(50.63, 'visual', 11.45, 1.1, 1.42, [.5, .56]);
add(52.5, 'ink', 126.6, 1, 1.32, [.5, .56]);
add(54.38, 'debug', 157.48, .8, 1.35, [.5, .56]);

// 00:54.38–01:05.63 — actual generated InkScript and local-model controls.
add(56.25, 'code', 2.3, 1, 1.55, [.5, .54]);
add(58.13, 'code', 3.0, 1, 1.48, [.55, .5]);
add(60, 'code', 3.9, 1, 1.8, [.5, .55], 'InkScript · original stroke IDs');
add(61.88, 'models', .05, 1, 1.28, [.5, .5]);
add(63.75, 'models', 1.1, .75, 1.47, [.51, .54], 'Automatic · Q4F16 · DirectML');
add(65.63, 'code', 4.05, .8, 1.76, [.5, .55]);

// 01:05.63–01:15.00 — action recap on half-bar and two-beat cuts.
add(66.56, 'ink', 120.35, 1, 1.7, [.5, .44]);
add(67.5, 'ink', 123.18, 1, 1.58, [.37, .7]);
add(68.44, 'ink', 127.1, 1, 1.65, [.47, .7]);
add(69.38, 'debug', 157.2, 1, 1.9, [.5, .59]);
add(70.31, 'debug', 158.6, 1, 1.87, [.5, .58]);
add(71.25, 'visual', 6.5, 1, 1.54, [.48, .4]);
add(72.19, 'visual', 9.2, 1, 1.38, [.5, .56]);
add(73.13, 'visual', 12.55, 1, 1.42, [.5, .57]);
add(74.06, 'bird', 58.9, 1, 1.76, [.57, .49]);
add(75, 'bird', 60.3, 1, 1.42, [.56, .5]);

const output = path.join(root, 'demo/video/action-cut.json');
fs.writeFileSync(output, JSON.stringify({version: 2, duration: 78, shots}, null, 2) + '\n');
console.log(JSON.stringify({output, shots: shots.length, pictureSeconds: from, filmSeconds: 78}));

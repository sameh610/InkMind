import fs from 'node:fs/promises';
import path from 'node:path';
import sharp from 'sharp';

const root = process.cwd();
const svg = await fs.readFile(path.join(root, 'assets/branding/inkmind-app-icon.svg'));
const render = async (target, size) => {
  const absolute = path.join(root, target);
  await fs.mkdir(path.dirname(absolute), {recursive: true});
  await sharp(svg).resize(size, size).png().toFile(absolute);
};

await render('demo/assets/inkmind-app-icon-1024.png', 1024);
for (const size of [192, 512]) {
  await render(`web/icons/Icon-${size}.png`, size);
  await render(`web/icons/Icon-maskable-${size}.png`, size);
}
const iOS = JSON.parse(await fs.readFile(path.join(root, 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json'), 'utf8'));
for (const item of iOS.images ?? []) {
  if (!item.filename || !item.size || !item.scale) continue;
  const [width, height] = item.size.split('x').map(Number);
  const scale = Number.parseInt(item.scale, 10);
  if (!Number.isFinite(width * height * scale) || width !== height) continue;
  await render(`ios/Runner/Assets.xcassets/AppIcon.appiconset/${item.filename}`, width * scale);
}
for (const [folder, size] of Object.entries({
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192,
})) {
  await render(`android/app/src/main/res/${folder}/ic_launcher.png`, size);
}
console.log('Generated InkMind app icon for iOS, Android, and web.');

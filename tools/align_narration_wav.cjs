const fs = require('node:fs');
const path = require('node:path');

const inputPath = path.resolve(process.argv[2] || 'demo/video/out/narration.wav');
const outputPath = path.resolve(process.argv[3] || 'demo/video/out/narration-film.wav');
const source = fs.readFileSync(inputPath);
if (source.toString('ascii', 0, 4) !== 'RIFF' || source.toString('ascii', 8, 12) !== 'WAVE') throw new Error('Expected a PCM WAV source.');
const format = source.readUInt16LE(20);
const channels = source.readUInt16LE(22);
const sampleRate = source.readUInt32LE(24);
const bitsPerSample = source.readUInt16LE(34);
const dataBytes = source.readUInt32LE(40);
const sourceDataStart = 44;
const bytesPerFrame = channels * (bitsPerSample / 8);
if (format !== 1 || bitsPerSample !== 16 || dataBytes + sourceDataStart > source.length) throw new Error('Expected 16-bit PCM WAV data.');

// Match the 78-second action cut. The only spoken line is the closing tag.
const outputFramesAt30Fps = 2340;
const outputDuration = outputFramesAt30Fps / 30;
const tagFilmSeconds = 2253 / 30;
const tagSourceSeconds = 2423 / 30;
const outputFrames = Math.round(sampleRate * outputDuration);
const tagFilmFrame = Math.round(tagFilmSeconds * sampleRate);
const sourceTagFrame = Math.round(tagSourceSeconds * sampleRate);
const tagFrames = Math.max(0, dataBytes / bytesPerFrame - sourceTagFrame);
const outputDataBytes = outputFrames * bytesPerFrame;
const out = Buffer.alloc(44 + outputDataBytes);
out.write('RIFF', 0); out.writeUInt32LE(36 + outputDataBytes, 4); out.write('WAVE', 8);
out.write('fmt ', 12); out.writeUInt32LE(16, 16); out.writeUInt16LE(1, 20);
out.writeUInt16LE(channels, 22); out.writeUInt32LE(sampleRate, 24);
out.writeUInt32LE(sampleRate * bytesPerFrame, 28); out.writeUInt16LE(bytesPerFrame, 32);
out.writeUInt16LE(bitsPerSample, 34); out.write('data', 36); out.writeUInt32LE(outputDataBytes, 40);

const tagBytes = Math.min(Math.floor(tagFrames * bytesPerFrame), outputDataBytes - tagFilmFrame * bytesPerFrame);
source.copy(out, 44 + tagFilmFrame * bytesPerFrame, sourceDataStart + sourceTagFrame * bytesPerFrame, sourceDataStart + sourceTagFrame * bytesPerFrame + tagBytes);
fs.mkdirSync(path.dirname(outputPath), {recursive: true});
fs.writeFileSync(outputPath, out);
console.log(JSON.stringify({outputPath, durationSeconds: outputDuration, sampleRate, channels, taglineFilmSeconds: tagFilmSeconds, taglineSourceSeconds: tagSourceSeconds, taglineSeconds: tagBytes / (sampleRate * bytesPerFrame), bytes: out.length}, null, 2));

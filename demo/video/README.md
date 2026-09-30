# InkMind V3 launch trailer

81.167 seconds, 2435 frames, 1920 × 1080, 30 fps. The 52-shot edit follows a 132 BPM musical grid and real Flutter web interactions captured in Edge: select → invoke → instruct → transform → interact.

The authoritative edit is launch-v3-cut.json; narration timing is launch-v3-voice.json. The separate Remotion entry point is src/launch_v3_index.tsx. The previous trailer entry point remains src/index.tsx.

Render:

    npm run render:clean
    npm run render:captioned

The post-render hooks replace intermediate AAC audio with a single encode from the aligned PCM master. This removes the measured 43 ms intermediate-encoding delay. tools/verify_launch_export.py verifies less than 1 ms timing offset and waveform correlation above 0.99.

For limited disk space, tools/finish_launch_masters.py streams the reviewed master and corrected Debug segment through Pillow and FFmpeg to produce both variants without a temporary frame sequence. It requires Python with Pillow and uses the same cue JSON and original PCM audio. This is the path used for the delivered masters.

Audio: a new ElevenLabs instrumental score and Charlie narration, plus locally constructed action effects. The 53-word narration is cut into fourteen phrases after picture lock. Independent transcription matches the script. The master mix was checked for clipping and narration timing during export review. Generated validation reports are local build artifacts and are not included in a clean clone; this is technical audio verification, not a claim of human listening review.

The score's measured onset grid is near 132.3 BPM; it is trimmed by 0.355 seconds and tempo-adjusted to 132 BPM. Original and aligned audio are preserved. tools/align_launch_v3_audio.py reproduces narration timing and the master mix from the verified second take.

App: http://127.0.0.1:8084/?native-ai=1. Companion: port 8787. Flutter release build: build/web-launch-v3 at repository root. Billing uses the real RevenueCat Test Store SDK and inkmind_pro entitlement; no real charge.

Run tools/start_launch_demo.ps1 from the repository to start the local web preview and companion in hidden service windows.

Validation evidence and generated run reports are local build artifacts under launch-v3 and are not included in a clean clone. Recorded demo footage is prepared-fixture evidence rather than a guarantee for arbitrary ink. Cached recognition is fast; first-use Gemma vision can still take tens of seconds, and longer during resource contention. Vision currently uses CPU compatibility on this device because the DirectML export rejects a dynamic image reshape.

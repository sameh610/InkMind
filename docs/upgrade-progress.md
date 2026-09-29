# InkMind upgrade — 22 September 2026

This is an incremental implementation of the attached upgrade request, not a
claim that all requested phases are complete.

## Implemented in this pass

- Shared browser/native model manifest and capability router; generated Flutter
  catalog uses the same source. Unavailable LiteRT/GGUF models remain unavailable.
- Automatic latency-first selection and optional quality selection with explicit,
  estimated memory headroom. Explicit model selections take priority.
- Native vision rejects text-only model use and routes to a vision-capable model.
- Matching browser session cache identities, remembered GPU initialization failure,
  serialized mutable model sessions, and expired-queue protection.
- Native animation goes through planning instead of an unconditional reveal plan.
- Failed generation propagates an error instead of a fake result or an unexpected
  native-to-browser download. Explicit demo engines remain separate.
- Actual loaded model/quant/backend reporting; pre-load predictions are labeled.
- InkScript finite shared pivots. Pendulum rod and bob rotate around one pivot
  rather than translating independently. Cosine expressions are no longer rewritten.
- Edit InkScript on existing ink motions, compile/bind before apply, checkpoint for
  notebook Undo, and controls styled with the notebook palette.

## Verification

- 29 Node routing, bridge, planning and compiler tests pass.
- Flutter regression suite covered 38 tests. Settings test was updated to scroll
  to the model button after the new performance section; its rerun passes.
- Release Flutter web build succeeds. Static analysis still reports style lints.
- Edge loads the notebook without page/console errors. Settings opens and closes
  at desktop and phone widths; screenshots are saved in the workspace.
- Real native DirectML inference returned an accurate explanation of y=3x²−1;
  bridge reported Qwen 2.5 Coder 0.5B / Q4F16 / DirectML.
- This pass did not establish end-to-end multimodal recognition accuracy or the
  requested 10/10 animation reliability. Unit fixtures do not establish that.

## Remaining work from the request

Model artifact integrity/download management, measured benchmarks and lifecycle
unloading; full general animation hierarchy/deformations; rendering editable draw
geometry rather than snapshot metadata; general differential-equation systems;
image-engine integration/cache/hybrid components; NativeWeb sandbox audit;
appearance/paper/pen/toolbar/gesture customization; structured inspector patches
and version history; ten-page demo expansion; storage/battery controls; comprehensive
real vision, animation and device acceptance testing.

Existing JSON motion plans remain a limited vocabulary. Shared pivots and the source
editor expand what the runtime can express but do not make every requested motion
possible. Model working-memory figures are planning estimates, not measured peaks
or verified artifact sizes. No new model downloads or quantization builds were invented.

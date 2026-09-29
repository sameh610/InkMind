# InkMind V3 picture and sound lock

2435 frames at 30 fps (81.167 seconds). Score: 132 BPM. Brand card: 78.167 seconds. Narration: 53 words, fourteen individually synchronized phrases.

| Film time | Cause and visible response |
| --- | --- |
| 0–8.18 | Original pendulum strokes, lasso, Animate my ink, swing instruction, Play motion, physical swing. |
| 8.18–16.36 | Pick up the handwritten Moon token, carry and drop it; gravity becomes 1.62 m/s². |
| 16.36–29.09 | Select three rows of ink; Debug rewinds stored pen samples, stops at 3x = 25, highlights 25, and draws the corrected 3x = 15 → x = 5 branch. |
| 29.09–38.18 | Select 3x² − 1 = y, invoke New Visual, submit a graph instruction; drag the coefficient through zero and flip the curve. |
| 38.18–41.82 | Second New Visual: exact 20 m/s, 45° projectile trajectory and controls. |
| 41.82–48.18 | Select six bird strokes, request flight, then the original bird moves and its wing flaps. |
| 48.18–52.73 | Select a flower, request wind, watch original strokes bend around their root. |
| 52.73–60 | Original strokes → recognized parts → actual generated InkScript bindings → executable motion. |
| 60–63.64 | Real model panel: Automatic resolution, model and quantization choices. |
| 63.64–70.91 | Annual plan, genuine RevenueCat Test Store purchase, confirmed Pro entitlement. No billing narration. |
| 70.91–78.17 | Ten short action cuts building to the final hit. |
| 78.17–81.17 | InkMind. Paper you can think with. |

Source recordings: public/footage/v3-{pendulum,debug,graph,projectile,bird,flower,billing}.webm. The model-panel excerpt is the earlier real inkmind-action-models.webm. Reports store each interaction timestamp; tools/build_launch_v3.cjs maps them into the film. Model waiting is removed. The trailer is edited, not a latency demo.

Evidence:

- Pendulum/Moon: 10/10 live runs; original IDs preserved; gravity reaches 1.62. Symmetric rotation uses sin(time × speed × sqrt(g/9.81)).
- Debug: 10/10, 25 stored vector strokes with sample clocks; first wrong transition is row two; correction ends at x = 5.
- Graph: 10/10, selected equation retained and coefficient crosses from positive to negative.
- Bird: 10/10, six original strokes with bound translation and wing rotation.
- Flower: 1/1, ten original strokes and root-anchored bend.
- Projectile: 1/1, supplied 20 m/s and 45° preserved.
- RevenueCat: 1/1 real SDK Test Store annual purchase, sandbox inkmind_pro entitlement. No mocked result or real charge.

The sample notebook is prepared fixture content. Ink is generated vector geometry with recorded sample timestamps; the trailer does not show a person drawing it live. Graph/projectile inputs are editable text objects. The correction branch is a live Flutter visualization. The code panel is an editorial overlay containing actual generated bindings, rather than a recreated product interface.

The 10/10 sequences repeat prepared inputs. Recognition caching keys unchanged visual content, excluding transient selection UI and IDs; each output binds to that run's current stroke IDs. Cold vision remains slower and uses CPU compatibility on this device. Earlier graph runs include resource contention before worker isolation; per-run latencies are retained in launch-v3/validation-summary.json.

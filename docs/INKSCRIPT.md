# InkScript in InkMind

InkScript is restricted TSX. A program exports one `Visual()` or `Animation()` function. The browser compiler parses TypeScript/JSX with Babel, validates the syntax and component names, and emits versioned InkIR. Flutter renders InkIR; it never evaluates the source code.

## Try it

Open a notebook page, choose **Notebook settings → InkScript playground**, edit the example, and select **Compile & preview**. The preview controls are live. **Add to page** stores both the source and InkIR in the notebook. The compiler runs in a Web Worker without downloading the AI model. **Make Alive → Create a new visual** and **Make Alive → Animate my ink** use the local browser model to generate TSX and run the same compiler, with one diagnostic repair attempt.

```tsx
export default function Visual() {
  const gravity = state(9.81);
  const length = state(2);
  return (
    <App title="Pendulum Lab">
      <Pendulum gravity={gravity} length={length} showTrail />
      <Controls>
        <Slider label="Gravity" value={gravity} min={1} max={25} unit="m/s²" />
        <Slider label="Length" value={length} min={0.5} max={5} unit="m" />
      </Controls>
    </App>
  );
}
```

A Slider or Toggle whose `value` is a state reference updates that state automatically. The Flutter component tree is rebuilt from the same IR when the value changes. `Graph`, `Pendulum`, `Projectile`, `Orbit`, and `Wave` use deterministic drawing and equations.

```tsx
export default function Animation() {
  const drawing = ink.selection();
  animate(({ time }) => {
    drawing.y = drawing.baseY + Math.sin(time * 3) * 8;
  });
}
```

`ink.selection()` binds the chosen vector strokes. `ink.stroke("id")` targets a selected ID. `ink.find("label")` and `drawing.group("label")` use stored stroke labels; unmatched bindings are rejected. Animation stores bindings and expressions, while original stroke bytes remain unchanged. Play, pause and reset are in the notebook. Motion properties are `x`, `y`, `rotation` (radians), `scaleX`, `scaleY`, `opacity`, and `visible`.

## Supported syntax and safety

The compiler accepts `const` declarations, `state(literal)`, arrays and plain objects, arithmetic, comparisons, boolean logic, ternary expressions, template strings, approved Math functions, `quantity(value, unit)`, and JSX components. It rejects imports, arbitrary calls, spread props, event handlers, computed property access, loops, and direct DOM APIs. Diagnostics include line, column, code, and suggested repair. Common component capitalization and reversed slider bounds are normalized with warnings. Source is capped at 25 KB; expression evaluation is depth bounded.

Capability profiles are `LITE`, `BALANCED`, `SMART`, and `ULTRA`. Scene primitives require BALANCED; NativeWeb requires ULTRA. The app currently generates and previews at BALANCED. The prior line-command visual format is still read for saved notebook compatibility but is no longer sent to the model for new visuals.

The current Flutter component library includes layouts, text, sliders, toggles, select chips, scene primitives, and deterministic diagrams. Some named high-level components use shared diagrams, and the larger requested rigging, deformation, particle, NativeWeb bridge, simulation diagnostics, and unit-aware calculations remain future work. The playground shows compiler errors rather than executing unsupported program statements.

## Source map

- `tools/inkscript/compiler.js`: parser, validation, diagnostics, InkIR emitter.
- `tools/ai_skills.js`: compact API cards and intent-selected examples for the local model.
- `tools/ai_worker.js`: generation, compilation, one repair pass, and playground compilation.
- `lib/features/ai/ink_ir.dart`: bounded expression evaluator.
- `lib/features/visuals/ink_ir_view.dart`: Flutter InkIR visual renderer.
- `lib/features/living_ink/ink_ir_motion.dart`: binding selected strokes to animation selectors.
- `lib/features/living_ink/ink_motion_layer.dart`: non-destructive vector playback.
- `lib/features/inkscript/playground.dart`: editor, preview, diagnostics, and page insertion.

Run `node --test --test-isolation=none tools/inkscript/compiler.test.mjs` and `flutter test` for the language and app checks.


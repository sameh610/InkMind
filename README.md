<img width="1024" height="1024" alt="inkmind-app-icon-1024" src="https://github.com/user-attachments/assets/61f02a1e-5578-4293-894d-45fddc5a76a0" />

# InkMind

**Paper you can think with.**

InkMind is a local-first handwritten notebook where your ink can move, become interactive, debug your reasoning, and turn into simulations with on-device AI.

Instead of moving your thinking into a chatbot, InkMind brings intelligence directly onto the page.

---

## What makes InkMind different?

Most note-taking apps treat handwriting as something static.

InkMind treats handwriting as something that can **run**.

You can:

- animate your original drawings
- drag handwritten ideas onto other ink to change how it behaves
- rewind your reasoning and find where it went wrong
- turn equations and notes into interactive visuals
- run compatible AI models locally on-device
- customize models, quantization, tools, paper, and AI behavior

The goal is simple:

> Keep the feeling of writing on paper, but make the page computational.

---

## Core features

### Animate Ink

Select something you drew and tell InkMind how it should move.

InkMind animates the **original vector strokes** instead of replacing your drawing with generated artwork.

Examples:

- make a pendulum swing
- make a bird fly
- make a tree move in the wind
- make planets orbit
- make a hand-drawn car drive

---

### InkMatter

Handwritten concepts can modify other objects on the page.

For example:

```text
Moon → Pendulum
```

changes the pendulum to lunar gravity.

Other examples include:

```text
3× velocity → projectile

no friction → ramp

9V → circuit

sort descending → array
```

InkMind interprets the handwritten modifier and applies it to a deterministic simulation.

---

### InkDebug

InkDebug is designed to help debug reasoning, not just provide an answer.

Because InkMind stores the order and timing of handwritten strokes, it can replay how an idea developed.

Example:

```text
3x + 5 = 20
3x = 25
x = 8.33
```

InkDebug can:

1. rewind the work
2. stop at the first incorrect transformation
3. fade the dependent steps
4. explain the mistake
5. branch into a corrected path

The idea is to **debug your thinking like code**.

---

### New Visual

Turn handwriting into an interactive visual directly on the page.

For example:

```text
y = ax²
```

can become an interactive graph with a slider for `a`.

InkMind uses **InkScript**, a restricted TypeScript/JSX-like language designed for small local AI models.

The AI describes what should exist.

InkMind's runtime handles:

- layout
- rendering
- interaction
- math
- physics
- animation
- validation

This lets relatively small models create useful interactive content without having to generate large amounts of HTML, CSS, or JavaScript.

---

## InkScript

InkScript is a small, safe language for creating InkMind visuals.

Example:

```tsx
export default function Visual() {
  const a = state(1);

  return (
    <App title="Quadratic Explorer">
      <Graph equation={`${a} * x^2`} />

      <Slider
        label="a"
        value={a}
        min={-5}
        max={5}
      />
    </App>
  );
}
```

InkScript is intentionally similar to TypeScript and JSX so existing language models already understand most of its syntax.

It compiles through:

```text
InkScript
   ↓
Parser
   ↓
Validator
   ↓
InkIR
   ↓
Deterministic runtime
   ↓
Interactive visual
```

Arbitrary code is not evaluated directly.

---

## Local AI

InkMind is designed around downloadable local AI models.

Different tasks can use different models instead of forcing one model to do everything.

```text
                 InkMind
                    │
              Model Router
                    │
       ┌────────────┼────────────┐
       ↓            ↓            ↓
 deterministic   language      vision /
   engines        model        imagery
       │            │            │
       └────────────┴────────────┘
                    ↓
                  Page
```

Examples:

- deterministic math and physics when AI is unnecessary
- small models for InkScript and structured commands
- vision models only when image understanding is needed
- optional larger models for more complex creation
- optional local image generation for visual assets

InkMind can also expose advanced model settings such as available quantized builds while keeping **Automatic** as the default for normal users.

---

## Local-first by design

The notebook itself works offline.

InkMind is being designed so compatible AI features can run locally rather than requiring every note or drawing to be sent to a remote AI service.

The exact capabilities depend on which models and runtime are available on the device.

---

## Built with Flutter

InkMind is built with Flutter and is designed for:

- iPhone
- iPad
- desktop
- web development and preview

The interface is touch-first and centered around the page rather than around chat.

---

## RevenueCat

InkMind uses RevenueCat for subscription and entitlement management.

InkMind Pro is designed to unlock advanced capabilities such as:

- advanced Animate Ink
- advanced New Visuals
- additional model options
- deeper customization
- extended InkCell history

RevenueCat's Test Store is used during development and demonstration.

---

## Why I built it

Students already think by writing, sketching, solving problems, and drawing diagrams.

Most AI tools ask you to leave that workflow and start typing into a chat box.

I wanted to try the opposite approach:

**What if the paper itself became intelligent?**

That idea became InkMind.

---

## Demo

**Shipaton 2026 demo video:**  

https://github.com/user-attachments/assets/b29e912e-01a9-468a-8885-247cedd3113c

---

## Screenshots

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/f8b7733a-262e-4ec7-85d2-0812bf04322b" />

<img width="960" height="540" alt="image" src="https://github.com/user-attachments/assets/de3f691b-75d1-4889-adf3-d20ed46c92ab" />

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/23a5558c-42f7-45e9-bf07-6d49c6d78bf0" />

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/91eb985d-9ee1-4dec-a97d-e96936f865e6" />

<img width="960" height="540" alt="image" src="https://github.com/user-attachments/assets/3c999bbe-a2d1-4c56-b99e-cc5282c6e04f" />

---

## Current status

InkMind is an experimental project built for **RevenueCat Shipaton 2026 — Next Gen**.

Some functionality is still evolving, especially around:

- local model support
- model performance across different devices
- advanced animation behaviors
- local image generation
- broader InkDebug reasoning domains

The repository reflects the current working prototype and ongoing development.

---

## Running the project

### Requirements

- Flutter SDK
- Dart
- a supported Flutter target such as Edge, Android, or iOS
- Xcode is required for native iOS builds

Clone the repository:

```bash
git clone (https://github.com/sameh610/InkMind.git)
cd InkMind
```

Install dependencies:

```bash
flutter pub get
```

Run:

```bash
flutter run
```

For a web preview:

```bash
flutter run -d edge
```

---

## Tests

Run:

```bash
flutter analyze
flutter test
```

---

## Project structure

A simplified overview:

```text
InkMind/
├─ android/              Android platform project
├─ ios/                  iOS platform project
├─ web/                  Flutter web shell and browser AI bridge
├─ lib/
│  ├─ app/               App root and routing
│  ├─ core/              Models, storage, theme, shared UI
│  └─ features/
│     ├─ ai/             AI engine, model catalog, InkScript
│     ├─ canvas/         Drawing canvas and gestures
│     ├─ living_ink/     Animate Ink and motion editor
│     ├─ inkdebug/       InkDebug and stroke history
│     ├─ inkcells/       Interactive visual cells
│     ├─ visuals/        New Visual rendering
│     └─ subscriptions/  RevenueCat and demo billing
├─ assets/               Fonts and app assets
├─ tools/                Native AI runner, model tools, tests, scripts
├─ test/                 Flutter tests
├─ demo/video/            Trailer source footage and Remotion project
├─ pubspec.yaml          Flutter dependencies
├─ package.json           Node/browser AI dependencies
├─ package-lock.json
└─ .gitignore
```

The exact structure may change as the project evolves.

---

## Privacy

InkMind is being designed around local-first processing.

Downloaded local models remain on the device unless the user explicitly chooses another supported workflow.

InkMind should never imply that a feature is local if that specific feature actually requires a remote service.

---

## License

Licensed under the **Apache License 2.0**.

See the `LICENSE` file for details.

Third-party AI models and dependencies may have their own separate licenses.

---

## Shipaton

Built for:

**RevenueCat Shipaton 2026 — Next Gen**

InkMind's focus is not just adding AI to a notebook.

It is exploring a different interface for AI:

> **the page itself.**
<img width="1920" height="1080" alt="action-logo-check" src="https://github.com/user-attachments/assets/97bdad7a-0546-4aa3-8968-9ce92e6cf9fa" />

// Flutter's web tool replaces these two placeholders for release builds. The
// same template is also consumed by `flutter run`, which keeps a fresh Edge
// tab from getting stuck on the HTML loading shell.
{{flutter_js}}
{{flutter_build_config}}

// A new release must load its matching Flutter code even when Edge cached an
// earlier notebook build at this same local URL.
for (const build of _flutter.buildConfig.builds ?? []) {
  if (build.mainJsPath) build.mainJsPath += '?v=visual-style-2';
}

_flutter.loader.load({
  config: {
    renderer: 'canvaskit',
  },
});

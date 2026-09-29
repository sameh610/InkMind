import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

Widget generatedVisual(String source) => HtmlElementView.fromTagName(
  tagName: 'iframe',
  onElementCreated: (element) {
    final frame = element as web.HTMLIFrameElement;
    frame.setAttribute('sandbox', 'allow-scripts');
    frame.setAttribute('referrerpolicy', 'no-referrer');
    frame.setAttribute(
      'allow',
      "camera 'none'; microphone 'none'; geolocation 'none'; clipboard-read 'none'; clipboard-write 'none'",
    );
    frame.title = 'AI-generated interactive visual';
    frame.style.border = '0';
    frame.style.width = '100%';
    frame.style.height = '100%';
    frame.setAttribute('srcdoc', '''<!doctype html><html><head>
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:; connect-src 'none'; frame-src 'none'; worker-src 'none'; object-src 'none'; form-action 'none'; base-uri 'none'">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>html,body{margin:0;min-height:100%;font:14px system-ui;background:#fffbf2;color:#172c3d}*{box-sizing:border-box}canvas,svg{max-width:100%}button,input{font:inherit}#ink-error{position:fixed;bottom:0;left:0;right:0;padding:12px;background:#ffe1d8;color:#672e24;z-index:2147483647}</style>
<script>
function showInkError(message){let box=document.getElementById('ink-error');if(!box){box=document.createElement('div');box.id='ink-error';document.body.append(box)}box.textContent='Generated visual error: '+message+'. Use Code to inspect, or regenerate.';}
window.addEventListener('error',e=>showInkError(e.message));
window.addEventListener('unhandledrejection',e=>showInkError(String(e.reason)));
</script></head><body>$source</body></html>''');
  },
);

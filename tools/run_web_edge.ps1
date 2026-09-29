$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$node = (Get-Command node).Source
$flutter = Join-Path $root '.tooling\flutter\bin\flutter.bat'
$edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'

Write-Host 'Starting the InkMind local AI companion...'
$ai = Start-Process -FilePath $node -ArgumentList 'tools/native_ai_runner.mjs' -WorkingDirectory $root -WindowStyle Hidden -PassThru
Write-Host 'Starting InkMind Flutter Web...'
$web = Start-Process -FilePath $flutter -ArgumentList 'run','-d','web-server','--web-hostname','127.0.0.1','--web-port','8080' -WorkingDirectory $root -WindowStyle Hidden -PassThru

try {
  $ready = $false
  for ($i = 0; $i -lt 90; $i++) {
    try {
      $health = Invoke-RestMethod 'http://127.0.0.1:8787/health' -TimeoutSec 1
      $page = Invoke-WebRequest 'http://127.0.0.1:8080' -UseBasicParsing -TimeoutSec 1
      if ($health.ok -and $page.StatusCode -eq 200) { $ready = $true; break }
    } catch { Start-Sleep -Milliseconds 500 }
  }
  if (-not $ready) { throw 'InkMind did not become ready in time.' }
  Write-Host 'InkMind is ready in Edge. The companion reports the actual model, quant, and CPU/GPU backend in Settings.'
  Start-Process -FilePath $edge -ArgumentList 'http://127.0.0.1:8080/?native-ai=1'
  Write-Host 'Keep this window open while using InkMind. Press Ctrl+C to stop both services.'
  Wait-Process -Id $web.Id
} finally {
  if ($web -and -not $web.HasExited) { Stop-Process -Id $web.Id -Force }
  if ($ai -and -not $ai.HasExited) { Stop-Process -Id $ai.Id -Force }
}

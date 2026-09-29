$ErrorActionPreference = 'Stop'
$demoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
function Test-DemoEndpoint([string]$Url) {
    try { return (Invoke-WebRequest -Uri $Url -TimeoutSec 2).StatusCode -eq 200 }
    catch { return $false }
}
if (-not (Test-Path -LiteralPath (Join-Path $demoRoot 'build/web-launch-v3/index.html'))) {
    throw 'Build the Flutter web-launch-v3 release first.'
}
if (-not (Test-DemoEndpoint 'http://127.0.0.1:8084')) {
    Start-Process -FilePath 'python' -ArgumentList @('-m','http.server','8084','--bind','127.0.0.1','--directory','build/web-launch-v3') -WorkingDirectory $demoRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $demoRoot 'build/launch-v3-web.log') -RedirectStandardError (Join-Path $demoRoot 'build/launch-v3-web-error.log') | Out-Null
}
if (-not (Test-DemoEndpoint 'http://127.0.0.1:8787/health')) {
    Start-Process -FilePath 'node' -ArgumentList @('tools/native_ai_runner.mjs') -WorkingDirectory $demoRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $demoRoot 'build/launch-v3-runner.log') -RedirectStandardError (Join-Path $demoRoot 'build/launch-v3-runner-error.log') | Out-Null
}
Write-Output 'InkMind demo: http://127.0.0.1:8084/?native-ai=1'

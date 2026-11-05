param([string]$FlutterCommand = 'flutter', [switch]$AllTests)
$ErrorActionPreference = 'Stop'
$backendPath = Split-Path -Parent $PSScriptRoot
$mobilePath = Join-Path (Split-Path -Parent $backendPath) 'mobile'
$jarPath = Join-Path $backendPath 'target/ourspace-backend-0.1.0-SNAPSHOT.jar'
if (-not (Test-Path -LiteralPath $jarPath)) { throw 'Build backend first: mvn package' }
if (-not (Get-Command $FlutterCommand -ErrorAction SilentlyContinue)) { throw 'Flutter SDK not found. Set -FlutterCommand to flutter.bat.' }
$javaPath = (Get-Command java).Source
if ($env:JAVA_HOME) {
    $directJava = Join-Path $env:JAVA_HOME 'bin/java.exe'
    if (Test-Path -LiteralPath $directJava) { $javaPath = $directJava }
}
$runId = [Guid]::NewGuid().ToString('N')
$logPath = Join-Path $backendPath "target/flutter-calendar-$runId.log"
$errorPath = Join-Path $backendPath "target/flutter-calendar-$runId-error.log"
$server = $null
try {
    $arguments = @('-jar', ('"' + $jarPath + '"'), '--spring.profiles.active=dev',
        '--server.address=127.0.0.1', '--server.port=0',
        '--spring.datasource.url=jdbc:h2:mem:flutter_calendar_acceptance',
        '--spring.datasource.username=sa', '--spring.datasource.password=',
        '--spring.flyway.locations=classpath:db/h2-migration',
        '--ourspace.push.enabled=false', '--app.jwt.secret=')
    $server = Start-Process -FilePath $javaPath -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $logPath -RedirectStandardError $errorPath
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $port = $null
    while ($watch.Elapsed.TotalSeconds -lt 60) {
        $server.Refresh()
        if ($server.HasExited) { throw "Backend exited. Inspect $logPath and $errorPath" }
        if (Test-Path -LiteralPath $logPath) {
            $content = Get-Content -Raw -LiteralPath $logPath
            if ($content) {
                $match = [regex]::Match($content, 'Tomcat started on port (\d+)')
                if ($match.Success) { $port = $match.Groups[1].Value; break }
            }
        }
        Start-Sleep -Milliseconds 250
    }
    if (-not $port) { throw "Backend startup timed out. Inspect $logPath" }
    Push-Location $mobilePath
    try {
        $flutterArguments = @('test', '--no-pub')
        if (-not $AllTests) { $flutterArguments += 'test/features/calendar_backend_acceptance_test.dart' }
        $flutterArguments += "--dart-define=CALENDAR_API_BASE_URL=http://127.0.0.1:$port"
        & $FlutterCommand @flutterArguments
        if ($LASTEXITCODE -ne 0) { throw 'Flutter/backend calendar acceptance failed.' }
    } finally { Pop-Location }
    Write-Output 'Flutter -> real backend calendar acceptance PASS (isolated H2, A/B plus outsider couple, UTC, CRUD, validation, stale version and JWT).'
} finally {
    if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force }
}

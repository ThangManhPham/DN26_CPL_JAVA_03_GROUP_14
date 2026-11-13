param([string]$FlutterCommand = 'flutter', [switch]$AllTests, [switch]$UsePostgres)
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
$previousPassword = $env:SPRING_DATASOURCE_PASSWORD
try {
    $arguments = @('-jar', ('"' + $jarPath + '"'), '--spring.profiles.active=dev',
        '--server.address=127.0.0.1', '--server.port=0',
        '--ourspace.push.enabled=false', '--app.jwt.secret=')
    if ($UsePostgres) {
        if ($env:TEST_DATABASE_URL -notmatch '^jdbc:postgresql://(127\.0\.0\.1|localhost):[0-9]+/[A-Za-z0-9_]+$' -or
            $env:TEST_DATABASE_USERNAME -notmatch '^[A-Za-z0-9_]+$') {
            throw 'Set TEST_DATABASE_URL to a disposable loopback PostgreSQL database and TEST_DATABASE_USERNAME. This test creates users and applies migrations.'
        }
        $env:SPRING_DATASOURCE_PASSWORD = $env:TEST_DATABASE_PASSWORD
        $arguments += @("--spring.datasource.url=$env:TEST_DATABASE_URL",
            "--spring.datasource.username=$env:TEST_DATABASE_USERNAME",
            '--spring.flyway.locations=classpath:db/migration')
    } else {
        $arguments += @('--spring.datasource.url=jdbc:h2:mem:flutter_calendar_acceptance',
            '--spring.datasource.username=sa', '--spring.datasource.password=',
            '--spring.flyway.locations=classpath:db/h2-migration')
    }
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
    $database = if ($UsePostgres) { 'PostgreSQL' } else { 'isolated H2' }
    Write-Output "Flutter -> real backend calendar acceptance PASS ($database, A/B plus outsider couple, reminder, UTC, CRUD, validation, stale version and JWT)."
} finally {
    if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force }
    $env:SPRING_DATASOURCE_PASSWORD = $previousPassword
}

param([switch]$Calendar)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http
$backendPath = Split-Path -Parent $PSScriptRoot
$jarPath = Join-Path $backendPath 'target/ourspace-backend-0.1.0-SNAPSHOT.jar'
if (-not (Test-Path -LiteralPath $jarPath)) { throw 'Build first: mvn package' }
$logPath = Join-Path $backendPath 'target/http-smoke.log'
$errorPath = Join-Path $backendPath 'target/http-smoke-error.log'
$javaPath = (Get-Command java).Source
if ($env:JAVA_HOME) {
    $directJavaPath = Join-Path $env:JAVA_HOME 'bin/java.exe'
    if (Test-Path -LiteralPath $directJavaPath) { $javaPath = $directJavaPath }
}
$httpClient = New-Object System.Net.Http.HttpClient
$httpClient.Timeout = [TimeSpan]::FromSeconds(10)
$smokeProcess = $null
$apiRoot = $null

function Invoke-SmokeApi([string]$method, [string]$path, [string]$body, [string]$token, [int]$expected) {
    $request = New-Object System.Net.Http.HttpRequestMessage
    $request.Method = New-Object System.Net.Http.HttpMethod($method)
    $request.RequestUri = [Uri]("$apiRoot$path")
    if ($body) {
        $request.Content = New-Object System.Net.Http.StringContent($body, [Text.Encoding]::UTF8, 'application/json')
    }
    if ($token) { $request.Headers.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue('Bearer', $token) }
    try {
        $response = $httpClient.SendAsync($request).GetAwaiter().GetResult()
        try {
            $status = [int]$response.StatusCode
            if ($status -ne $expected) { throw "Smoke check failed: $method $path expected $expected, got $status" }
            $raw = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            if ($raw) { return ($raw | ConvertFrom-Json) }
        } finally { $response.Dispose() }
    } finally { $request.Dispose() }
}

try {
    # Isolated loopback server with its own in-memory DB; never touches configured databases.
    $arguments = @('-jar', ('"' + $jarPath + '"'), '--spring.profiles.active=dev',
        '--server.address=127.0.0.1', '--server.port=0',
        '--spring.datasource.url=jdbc:h2:mem:http_smoke',
        '--spring.datasource.username=sa', '--spring.datasource.password=',
        '--app.jwt.secret=')
    $smokeProcess = Start-Process -FilePath $javaPath -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $logPath -RedirectStandardError $errorPath
    $watch = [Diagnostics.Stopwatch]::StartNew()
    while ($watch.Elapsed.TotalSeconds -lt 40) {
        $smokeProcess.Refresh()
        if ($smokeProcess.HasExited) { throw "JAR exited before startup. Inspect $logPath and $errorPath" }
        if (Test-Path -LiteralPath $logPath) {
            $serverLog = Get-Content -Raw -LiteralPath $logPath
            if ([string]::IsNullOrEmpty($serverLog)) { Start-Sleep -Milliseconds 100; continue }
            $portMatch = [regex]::Match([string]$serverLog, 'Tomcat started on port (\d+)')
            if ($portMatch.Success) {
                $apiRoot = 'http://127.0.0.1:' + $portMatch.Groups[1].Value
                break
            }
        }
        Start-Sleep -Milliseconds 250
    }
    if (-not $apiRoot) { throw 'JAR startup timed out after 40 seconds.' }
    $health = Invoke-SmokeApi 'GET' '/actuator/health' '' '' 200
    if ($health.status -ne 'UP') { throw 'Health check is not UP.' }
    $email = 'http-smoke@example.com'
    $registerJson = @{ email=$email; password='ExamplePassword123!'; displayName='Smoke User' } | ConvertTo-Json
    $profile = Invoke-SmokeApi 'POST' '/api/v1/auth/register' $registerJson '' 201
    $duplicate = Invoke-SmokeApi 'POST' '/api/v1/auth/register' $registerJson '' 409
    if ($duplicate.code -ne 'EMAIL_ALREADY_EXISTS') { throw 'Unexpected duplicate email code.' }
    $loginJson = @{ email=$email; password='ExamplePassword123!' } | ConvertTo-Json
    $session = Invoke-SmokeApi 'POST' '/api/v1/auth/login' $loginJson '' 200
    $current = Invoke-SmokeApi 'GET' '/api/v1/users/me' '' $session.accessToken 200
    if ($current.id -ne $profile.id) { throw 'Wrong authenticated user.' }
    $changed = Invoke-SmokeApi 'PATCH' '/api/v1/users/me' '{"displayName":"Updated Smoke"}' $session.accessToken 200
    if ($changed.displayName -ne 'Updated Smoke') { throw 'Profile update failed.' }
    $withoutToken = Invoke-SmokeApi 'GET' '/api/v1/users/me' '' '' 401
    $invalidToken = Invoke-SmokeApi 'GET' '/api/v1/users/me' '' 'invalid-token' 401
    if ($Calendar) {
        $sessions = @{}
        foreach ($name in @('partner', 'outsider')) {
            $body = @{ email="$name@example.com"; password='ExamplePassword123!'; displayName=$name } | ConvertTo-Json
            $null = Invoke-SmokeApi 'POST' '/api/v1/auth/register' $body '' 201
            $credentials = @{ email="$name@example.com"; password='ExamplePassword123!' } | ConvertTo-Json
            $sessions[$name] = Invoke-SmokeApi 'POST' '/api/v1/auth/login' $credentials '' 200
        }
        $invite = Invoke-SmokeApi 'POST' '/api/v1/couple-invites' '' $session.accessToken 201
        $join = @{ inviteCode=$invite.inviteCode } | ConvertTo-Json
        $null = Invoke-SmokeApi 'POST' '/api/v1/couples/join' $join $sessions['partner'].accessToken 201
        $space = Invoke-SmokeApi 'PATCH' '/api/v1/couple-space' '{"anniversaryDate":"2020-02-29"}' $session.accessToken 200
        if ($space.daysTogether -lt 1) { throw 'Love counter failed.' }
        $eventBody = @{ title='Calendar smoke'; startsAt='2026-11-01T12:00:00Z'; endsAt='2026-11-01T13:00:00Z'; timezone='Asia/Ho_Chi_Minh' } | ConvertTo-Json
        $event = Invoke-SmokeApi 'POST' '/api/v1/events' $eventBody $session.accessToken 201
        $detail = Invoke-SmokeApi 'GET' "/api/v1/events/$($event.id)" '' $sessions['partner'].accessToken 200
        if ($detail.title -ne 'Calendar smoke') { throw 'Partner cannot read event.' }
        $null = Invoke-SmokeApi 'GET' "/api/v1/events/$($event.id)" '' $sessions['outsider'].accessToken 404
        $list = Invoke-SmokeApi 'GET' '/api/v1/events?from=2026-11-01T00:00:00Z&until=2026-12-01T00:00:00Z' '' $session.accessToken 200
        if (@($list.items).Count -ne 1) { throw 'Calendar range query failed.' }
        $changedEvent = Invoke-SmokeApi 'PATCH' "/api/v1/events/$($event.id)" '{"title":"Updated event","version":0}' $sessions['partner'].accessToken 200
        $null = Invoke-SmokeApi 'PATCH' "/api/v1/events/$($event.id)" '{"title":"Stale","version":0}' $session.accessToken 409
        $null = Invoke-SmokeApi 'DELETE' "/api/v1/events/$($event.id)?version=$($changedEvent.version)" '' $session.accessToken 204
        $null = Invoke-SmokeApi 'GET' "/api/v1/events/$($event.id)" '' $sessions['partner'].accessToken 404
        Write-Output 'Calendar HTTP smoke PASS: real pairing, anniversary/counter, shared CRUD, range query, outsider rejection and stale version.'
    }
    Write-Output 'HTTP smoke PASS: health, register, duplicate email, login, JWT profile, PATCH, missing/invalid token.'
} finally {
    $httpClient.Dispose()
    if ($null -ne $smokeProcess) {
        $smokeProcess.Refresh()
        if (-not $smokeProcess.HasExited) { $smokeProcess.Kill(); $smokeProcess.WaitForExit() }
        $smokeProcess.Dispose()
    }
}

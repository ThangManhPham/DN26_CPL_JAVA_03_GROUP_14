@REM ----------------------------------------------------------------------------
@REM Maven Wrapper helper for OurSpace Backend
@REM ----------------------------------------------------------------------------
@echo off
setlocal

set "INTELLIJ_MVN=F:\JAVA\lij\IntelliJ IDEA Community Edition 2025.1.1\plugins\maven\lib\maven3\bin\mvn.cmd"

if exist "%INTELLIJ_MVN%" (
    call "%INTELLIJ_MVN%" %*
    exit /b %ERRORLEVEL%
)

where mvn >nul 2>nul
if %ERRORLEVEL% equ 0 (
    call mvn %*
    exit /b %ERRORLEVEL%
)

echo ERROR: Maven not found on PATH or bundled IntelliJ path.
exit /b 1

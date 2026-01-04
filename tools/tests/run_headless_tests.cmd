@echo off
setlocal

REM Windows helper to run headless Godot tests.
REM Usage:
REM   tools\tests\run_headless_tests.cmd "C:\Path\To\Godot_v4.5-stable_win64.exe"
REM Or set GODOT_BIN and run without args:
REM   set GODOT_BIN=C:\Path\To\Godot.exe
REM   tools\tests\run_headless_tests.cmd

set GODOT_EXE=%~1

if not "%GODOT_EXE%"=="" (
  python tools\tests\run_headless_tests.py --godot "%GODOT_EXE%"
  exit /b %ERRORLEVEL%
)

python tools\tests\run_headless_tests.py
exit /b %ERRORLEVEL%

@echo off
setlocal
cd /d "%~dp0"

where julia >nul 2>nul
if errorlevel 1 (
  echo Julia was not found.
  echo Install it from https://julialang.org/downloads/ and reopen this file.
  pause
  exit /b 1
)

julia --startup-file=no --project=. start.jl
if errorlevel 1 (
  echo.
  echo Launch failed. Read START_HERE.md or copy the error above when asking for help.
  pause
)

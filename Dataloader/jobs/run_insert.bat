@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Dataloader\jobs\run_insert.ps1"
exit /b %ERRORLEVEL%

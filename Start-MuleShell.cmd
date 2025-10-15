@echo OFF

cd %~dp0
REM start "Mule Env" "C:\Program Files\PowerShell\7\pwsh.exe" -NoExit -Command ". %~dp0\MuleEnv-Tools.ps1"
start "Mule Env" "%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe" -NoExit -Command "& {Set-ExecutionPolicy Bypass -Scope Process -Force;. %~dp0\MuleEnv-Tools.ps1}"

exit

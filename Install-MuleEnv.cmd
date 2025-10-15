@echo OFF

cd %~dp0
start "Mule Env Setup" "%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe" -NoExit -Command "& {Set-ExecutionPolicy Bypass -Scope Process -Force;. %~dp0\MuleEnv-Tools.ps1; Install-MuleEnv}"

exit

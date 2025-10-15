@echo OFF

cd %~dp0
start "Mule Env" "C:\Program Files\PowerShell\7\pwsh.exe" -NoExit -Command ". %~dp0\muleenv-tools.ps1;Install-MuleEnv"
REM start "Mule Env Setup" "%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe" -NoExit -Command "& {. %~dp0\muleenv-tools.ps1; Install-MuleEnv}"

exit

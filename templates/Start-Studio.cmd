@echo OFF
cd /d %~dp0

call Set-Env.cmd

cd %ANYPOINT_HOME%
start AnypointStudio.exe
cd..
REM start "MVNConsole"

exit

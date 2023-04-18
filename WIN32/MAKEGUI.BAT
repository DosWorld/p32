@echo off
\p32\bin\p32 %1.pas
if errorlevel 1 goto badend
nasm -f win32 %1.asm
if not exist %1.rc goto skiprc
lrc /v %1.rc
if errorlevel 1 goto badend
lcclnk -v -subsystem windows %1.obj system.obj windows.obj %1.res -s
if errorlevel 1 goto badend
goto goodend
:skiprc
lcclnk -v -subsystem windows %1.obj system.obj windows.obj -s
if not errorlevel 1 goto goodend
:badend
echo Error making %1.pas
goto quit
:goodend
echo Success!!! 
:quit
echo on

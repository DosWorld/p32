@echo off
p32 %1.pas
if errorlevel 1 goto badend
nasmw -f win32 windows.asm
if errorlevel 1 goto badend
ren %1.ASM %1.AS0
nasmw -f win32 %1.asm
if errorlevel 1 goto badend
if not exist crt.asm goto skipcrt
nasmw -f win32 crt.asm
if errorlevel 1 goto badend
lcclnk -v -subsystem console %1.obj system.obj crt.obj windows.obj -s
if errorlevel 1 goto badend
goto goodend
:skipcrt
lcclnk -v -subsystem console %1.obj system.obj windows.obj -s
if errorlevel 1 goto badend
goto goodend
:badend
echo Error making %1.pas
goto quit
:goodend
echo Success!!! 
:quit
echo on

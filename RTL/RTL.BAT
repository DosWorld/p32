@echo off
REM ------------ This batch file rebuilds the RTL
%p32%\bin\p32 -cs
tasm /m9 system
del system.asm
del system.asi
%p32%\bin\p32 dos
tasm /m9 dos
del dos.asm
del dos.asi
%p32%\bin\p32 crt
tasm /m9 crt
del crt.asm
del crt.asi
%p32%\bin\p32 dpmi
tasm /m9 dpmi
del dpmi.asm
del dpmi.asi
%p32%\bin\p32 strings
tasm /m9 strings
del strings.asm
del strings.asi
%p32%\bin\p32 mmx
tasm /m9 mmx
del mmx.asm
del mmx.asi


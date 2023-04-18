:
: $Log: make.bat $
: Revision 1.3  1998/09/20 17:31:46  MikeT
: Allow for use of TASM32.EXE and check for certain error conditions.
:
: Revision 1.2  1998/09/16 22:40:37  MikeT
: Added k32spawn.asm
:
:
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::: One day, when I'm grown up, I'll become a makefile...
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
@echo off
if exist tasmver.$$$ del tasmver.$$$ > nul
if exist tlinkver.$$$ del tlinkver.$$$ > nul
if exist kernel32.wdl del kernel32.wdl > nul
if exist user32.wdl del user32.wdl > nul
if exist advapi32.wdl del advapi32.wdl >nul
if exist oleaut32.wdl del oleaut32.wdl > nul
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::: Check for TASM / TASM32
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
tasm > tasmver.$$$
if not exist tasmver.$$$ goto UseTasm32
tasm32 > tasmver.$$$
if not exist tasmver.$$$ goto Fail
tlink32 > tlinkver.$$$
if not exist tlinkver.$$$ goto Fail
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::: Make KERNEL32.WDL
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
tasm /m9 /mx kernel32.asm >k32.log
tasm /m9 /mx k32lfuns.asm >>k32.log
tasm /m9 /mx k32vmem.asm >>k32.log
tasm /m9 /mx k32file.asm >>k32.log
tasm /m9 /mx k32misc.asm >>k32.log
tasm /m9 /mx k32load.asm >>k32.log
tasm /m9 /mx k32heap.asm >>k32.log
tasm /m9 /mx console.asm >>k32.log
tasm /m9 /mx k32spawn.asm >>k32.log
tlink32 -Tpd kernel32 k32load k32lfuns k32vmem k32file k32misc k32heap k32spawn console,KERNEL32.dll >> k32.log
ren kernel32.dll kernel32.wdl
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::: Make USER32.WDL
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
tasm /m9 /mx user32.asm > u32.log
tlink32 -Tpd user32,USER32.dll >> u32.log
ren user32.dll user32.wdl
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::: Make ADVAPI32.WDL
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
tasm /m9 /mx advapi32.asm > a32.log
tlink32 -Tpd advapi32,ADVAPI32.dll >> a32.log
ren advapi32.dll advapi32.wdl
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::: Make OLEAUT32.WDL
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
tasm /m9 /mx oleaut32.asm > o32.log
tlink32 -Tpd oleaut32,OLEAUT32.dll >> o32.log
ren oleaut32.dll oleaut32.wdl
goto TheEnd

:UseTasm32
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::: Make KERNEL32.WDL
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
tasm32 /m9 /mx kernel32.asm >k32.log
tasm32 /m9 /mx k32lfuns.asm >>k32.log
tasm32 /m9 /mx k32vmem.asm >>k32.log
tasm32 /m9 /mx k32file.asm >>k32.log
tasm32 /m9 /mx k32misc.asm >>k32.log
tasm32 /m9 /mx k32load.asm >>k32.log
tasm32 /m9 /mx k32heap.asm >>k32.log
tasm32 /m9 /mx console.asm >>k32.log
tasm32 /m9 /mx k32spawn.asm >>k32.log
tlink32 -Tpd kernel32 k32load k32lfuns k32vmem k32file k32misc k32heap k32spawn console,KERNEL32.dll >> k32.log
ren kernel32.dll kernel32.wdl
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::: Make USER32.WDL
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
tasm32 /m9 /mx user32.asm > u32.log
tlink32 -Tpd user32,USER32.dll >> u32.log
ren user32.dll user32.wdl
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::: Make ADVAPI32.WDL
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
tasm32 /m9 /mx advapi32.asm > a32.log
tlink32 -Tpd advapi32,ADVAPI32.dll >> a32.log
ren advapi32.dll advapi32.wdl
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::: Make OLEAUT32.WDL
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
tasm32 /m9 /mx oleaut32.asm > o32.log
tlink32 -Tpd oleaut32,OLEAUT32.dll >> o32.log
ren oleaut32.dll oleaut32.wdl
goto TheEnd

:Fail
echo This scricpt requires TASM.EXE/TASM32.EXE and TLINK32.EXE in your search path!
goto Outtahere

:TheEnd
if not exist kernel32.wdl echo Error during build of kernel32.wdl. Check k32.log!
if not exist user32.wdl echo Error during build of user32.wdl. Check u32.log!
if not exist oleaut32.wdl echo Error during build of oleaut32.wdl. Check o32.log!
if not exist advapi32.wdl echo Error during build of advapi32.wdl. Check a32.log!

:Outtahere
del *.$$$
del *.obj
del *.map

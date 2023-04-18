::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::: This is a hack to allow the program to be reloaded by pressing CTRL-F2 :::

@echo off
:DoDebug
if exist %1 goto Label1
wudebug %1.exe %2 %3 %4 %5 %6 %7 %8 %9
goto Label2
:Label1
wudebug %1 %2 %3 %4 %5 %6 %7 %8 %9
:Label2
if errorlevel 255 goto End
if errorlevel 242 goto DoDebug
:End

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


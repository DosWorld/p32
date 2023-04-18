##############################################################################
##                 Wudebug 0.1 SAQ (Supposedly Asked Questions)             ##
##############################################################################

Q: What _is_ Wudebug in the first place?
A: Wudebug is a full screen debugger for debugging executables that use
   WDOSX as a DOS extender.

Q: Can I use it with DOS protected mode executables not running under WDOSX?
A: No.

Q: But can it be modified to work with these?
A: Yes. It's mostly a generic DPMI debugger with some parts that are specific
   to WDOSX though. I released the source code, good luck!

Q: It's still version 0.1, is there something new since the WDOSX 0.93 release?
A: Yes, some bugs have been fixed and some improvements have been made. Just
   to mention a few:

   - Breakpoints now work in a Win 3.1 DOS box.
   - For invalid intructions now there's db xx displayed in the disassembly
     Window, not just ???. This is an improvement done by Mark Junker. However,
     ??? still indicates that the memory at the questionable address isn't
     accessable ( the page fault issue ).
   - It is now possible to debug LE executables.
   - Some measures have been taken to allow the debugger to run a little more
     stable in a Windows NT DOS box.

Q: It sometimes works in a WinNT DOS box, it sometimes doesn't, it sometimes
   works first an crashes later. In either case the current NTVDM is
   terminated. Is this a bug I discovered?
A: The WinNT DPMI host does not reflect page faults to an installed handler.
   So there's no way to trap accesses to invalid memory addresses. The latest
   version of the debugger has been "corrected" to allow at least for debugging
   a program unless the debuggee itself causes a page fault. There's no way to
   trap the latter in NT.

Q: Does it work in a Win95 DOS box?
A: Wudebug is supposed to work just fine under Win95.

Q: Does it work under DOSEMU?
A: I didn't get it to work. It deals with video mode switching etc. and Linux
   doesn't like that. You may, however, try to take the sourcecode and make
   a command line (DEBUG style) debugger out of it.

Q: Does it run in an OS/2 DOS box?
A: Just try it and tell me since I don't run OS/2 anymore.

Q: You mentioned all kinds of DOS boxes, now does it work in plain DOS?
A: That's what a DOS extender and its add-on tools are for, in the first place.

Q: Well, I typed "wudebug my_exe.exe", some screen full of numbers and stuff
   is showing up but how to proceed?
A: Press F1 for the key assignments. They are similar to these used by Borland
   debuggers so you should get started quickly.

Q: When debuggig a Win32 executable using kernel32.wdl, the debugger would
   start at the kernel32 initialization code and not at then very beginning of
   my own program. Does this mean that I have to trace trough all that junk
   everytime I want to debug my program.
A: No, just press "F9" and it should step to the beginning of your program.
   The reason for this behaviour is that this way it is possible to debug the
   init code of load time linked WDLs you may have written on your own.

Q: How do I reload a program? Pressing CTRL+F2 seems to just terminate the
   debugger.
A: Use the "DB" batch file provided. Say "db my_exe" instead of "wudebug
   my_exe.exe" and CTRL+F2 will restart the entire session.

Q: Uuuh this is a hack, isn't it? Do you ever feel like correcting this?
A: It is a hack and it works fine for me. Keeping track of all DPMI resources
   is a several-hundreds-if-not-more-lines-of-code issue and I cannot be
   bothered with writing something that can also be done in a simple .bat ;-).
   If you don't like it, well, the source code is all there...

Q: Are there other known incompatibilities you know of?
A: If Wudebug detects a VESA video BIOS it uses the VBE state save / restore
   functions to switch between the debugger and user screen. At least one
   buggy video card BIOS I know of will crash ( RTVGA ). Workaround is to
   rebuild the debugger and comment out the "VESA=1" line on top of sdebug.asm
   before doing so. It may also help to use some VESA TSR, maybe Scitech's
   "Display Doctor" (former UNIVBE) that is supposed to fix this in most cases
   though, but isn't freeware...

Q: When debugging a program that uses the WDOSX Win32 emulator, I sometimes
   get an "FPU not available" exception message, but it should have been
   a FPU exception e.g. "Divide By Zero". What's this?
A: That's the way the FPU exception handling works in the Win32 emulator. FPU
   exceptions are converted into #7's. This is because they need to be trapped
   by an interrupt handler (int 75h) and this one hasn't access to the complete
   CPU state as an exception handler has, so it does some magic with the EM
   bit of CR0 instead.

Q: Why could it be that my program runs fine in the debugger but crashes
   if ran stand alone or vice versa?
A: If your program runs fine without the debugger, it's probably doing some
   funny things the debugger couldn't keep track of. You shouldn't worry about
   that. Then again, if it _only_ runs in the debugger, it may be that your
   program uses an older WDOSX stub version than the debugger does. When run
   under the debugger, your program uses the DOS extender of the debugger
   instead of its own. This is only one out of many possible reasons though.

Q: The above implies I can debug executables build with older versions of
   WDOSX as well, right?
A: Since all (released) versions of WDOSX have been backwards compatible, it'll
   work in most cases, except when the program exploits some special feature of
   the older WDOSX version that has been removed because actually it's been a
   bug.

Q: Whenever my program is doing graphics, part of the graphics screen gets
   trashed. Is there a way to overcome this?
A: I know of no safe way to save / restore the _entire_ state of the video
   subsystem that works with all SVGA cards. Such code would require register
   level manipulations and you probably know what this means considering there
   is no standard of SVGA cards with regards to register level access.
   Scitech probably are making a fortune just because there isn't...
   Doing this only for VGA modes, albeit possible, is no resonable solution
   either considering what most people are doing when they say "graphics",
   nowadays.

Q: The screen swapping is really annoying, sometimes. Can I just turn it OFF?
A: There's no simple way as of now. When single stepping, try to use F8 only
   if you actually want to step over a function call or so. In most other cases
   F7 will do fine and there's no screen flipping except when stepping over
   an INT instruction. You might want to change this in the source code and
   rebuild. The questionable code is in "main.asm".

Q: Are there plans to improve the debugger? An FPU/MMX status window would be
   nice as well as some source level debugging and so on.
A: If I only had more time...

All trademarks are the property of their respective owners, used for product
identification purposes only.

; ############################################################################
; ## WDOSX DOS Extender           Copyright (c) 1996, 1998, Michael Tippach ##
; ##                                                                        ##
; ## Realeased under the terms of the WDOSX license agreement.              ##
; ############################################################################
;
; $Header: E:/RCS/WDOSX/0.95/SRC/WIN32/kernel32.asm 1.4 1998/09/24 01:35:50 MikeT Exp MikeT $
;
; ----------------------------------------------------------------------------
;
; $Log: kernel32.asm $
; Revision 1.4  1998/09/24 01:35:50  MikeT
; At least do initialize critical section objects, when requested.
; This does not fix any known bug but anyway...
;
; Revision 1.3  1998/08/23 00:36:25  MikeT
; Add outDebString
;
; Revision 1.2  1998/08/08 14:40:50  MikeT
; Added Set/Env/Var stub
;
; Revision 1.1  1998/08/03 01:45:45  MikeT
; Initial check in
;
;
; ----------------------------------------------------------------------------
; ############################################################################
; ## Main module of kernel32 -> DPMI wrapper                                ##
; ############################################################################

.386p
.model flat

include w32struc.inc

.code

		PUBLICDLL		OutputDebugString
		PUBLICDLL		SetEnvironmentVariableA
		PUBLICDLL		RaiseException
		PUBLICDLL		UnhandledExceptionFilter
		PUBLICDLL		RtlUnwind
		PUBLICDLL		ExitProcess
		PUBLICDLL		GetCommandLineA
		PUBLICDLL		GetCurrentThreadId
		PUBLICDLL		GetLastError
		PUBLICDLL		GetEnvironmentStrings
		PUBLICDLL		GetEnvironmentStringsA
		PUBLICDLL		GetEnvironmentStringsW
		PUBLICDLL		InitializeCriticalSection
		PUBLICDLL		DeleteCriticalSection
		PUBLICDLL		LeaveCriticalSection
		PUBLICDLL		EnterCriticalSection
		PUBLICDLL		GetEnvironmentVariableA
		PUBLICDLL		GetStringTypeA
		PUBLICDLL		GetStringTypeW
		PUBLICDLL		GetDateFormatA
		PUBLICDLL		EnumCalendarInfoA	
		PUBLICDLL		WritePrivateProfileStringA
		PUBLICDLL		GetPrivateProfileStringA
		PUBLICDLL		FormatMessageA
		PUBLICDLL		CompareStringA
		PUBLICDLL		SetConsoleCtrlHandler
		PUBLICDLL		GetVersion
		PUBLICDLL		GetVersionExW
		PUBLICDLL		GetVersionExA
		PUBLICDLL		GetStartupInfoA
		PUBLICDLL		TlsAlloc
		PUBLICDLL		TlsFree
		PUBLICDLL		TlsSetValue
		PUBLICDLL		TlsGetValue
		PUBLICDLL		GlobalMemoryStatus
		PUBLICDLL		Borland32

		PUBLIC		MainModuleFileName
		PUBLIC		MainModuleHandle
		PUBLIC		GenericError
		PUBLIC		wfseHandler
		PUBLIC		isLoadTime

		EXTRN		initConsole: NEAR
		EXTRN		vmemInit: NEAR
		EXTRN		initHeap: NEAR
		EXTRN		peImport: NEAR
		EXTRN		WdlDirectory: WdlInfo
		EXTRN		lstrcpyA: NEAR
		EXTRN		lstrlenA: NEAR
		EXTRN		lstrlen: NEAR
		EXTRN		getModuleFromAddress: NEAR

;+----------------------------------------------------------------------------
; Borland C++ startup code checks for this to detect the presence of the
; PowerPack DOS extender. When running in DOS, memory allocation is done in
; increments of 1Mb, where under Windows they allocate 4Mb at once.
;
Borland32	LABEL NEAR

;+----------------------------------------------------------------------------
; DLL entry point. Called (jumped to) by the generic PE loader.
; Entry conditions are as follows:
;
; EAX = hModule of main program. This one has already been loaded and relocated
;       an we're also running on its stack. However, we still need to process
;       the imports of this module, set up the TIB and so on.
; FS = TIB (uninitialized!)
; 
; ESI = argc
; EDI = argv[]
; EBP = env[]
;
dllMain		PROC	NEAR
;
; This would have been the real Win32 arguments:
;
; arg		dwHandle:   DWORD
; arg		dwReason:   DWORD
; arg		dwReserved: DWORD

		cmp	isLoadTime, 0
		jne	@@doInit

		mov	eax, 1
		retn	12

@@doInit:
;
; Save PSP selector... and more
;
		mov	pspSelector, es
		mov	FlatDataSel, ds
		mov	MainModuleHandle, eax
		mov	envArray, ebp
		push	ds
		pop	es
;
; Get information from Stub as TIB init will destroy the first 48 bytes
; in this segment
;
		mov	eax, fs:[4]
		mov	isDebugger, al
		mov	eax, fs:[0]
		mov	WdlDirectory.Handle,eax
		mov	WdlDirectory.Count, 1
		mov	DWORD PTR [OFFSET WdlDirectory.FileName], 'NREK'
		mov	DWORD PTR [OFFSET WdlDirectory.FileName+4], '23LE'
		mov	DWORD PTR [OFFSET WdlDirectory.FileName+8], 'LDW.'
		mov	BYTE PTR [OFFSET WdlDirectory.FileName+12], 0
;
; For the very same reason we have to build the command line right here
;
		mov	ebx, [edi]
		mov	MainModuleFileName, ebx
		mov	ebx, edi
		mov	edi, OFFSET CommandLine
		cld
		mov	ecx, esi

CmdLineLoop:
		mov	esi, [ebx]

CmdCopy:
		lodsb		
		stosb
		test	al, al
		jnz	CmdCopy

		mov	BYTE PTR [edi-1], ' '
		add	ebx, 4
		loop	CmdLineLoop

;		mov	WORD PTR [edi-1], 0Dh
		mov	BYTE PTR [edi-1], 0
;
; Now initialize TIB
;
		mov	fs:[TIB.PFirstEx], -1
		mov	fs:[TIB.pTEB], OFFSET ThreadID - 24h
;		mov	fs:[TIB.pTlsArray], OFFSET TlsArray
		mov	eax, MainModuleHandle
		mov	edi, [eax+60]
		mov	edi, [edi+eax+0C0h]
		lea	eax, [edi+eax+0Ch]
		mov	fs:[TIB.pTlsArray], eax

		sub	esp, 30h
		mov	edi, esp
		mov	eax, 500h
		int	31h
;
; Initialize for GlobalMemoryStatus
;
		pop	ApiInitialFree
		add	esp, 2Ch

		mov	eax, 0FFFDh
		int	21h
		jc	noWfse

                cmp	eax, 57465345h
		sete	haveWfse

noWfse:
		call	vmemInit
		call	initSeh
		call	initFPU
		call	initHeap
		call	initConsole

		mov	eax, MainModuleHandle
		call	peImport

		mov	fs:[TIB.pStackBase], esp
		lea	ebp, [esp-30h]
		push	ebp
		push	ebp
		push	ebp
		sub	esp, 30h-12
		mov	esi, MainModuleHandle
		mov	eax, [esi+60]
		mov	eax, [eax+esi+28h]
		add	eax, esi
		mov	isLoadTime, 0
;
; Shortcut to invoke the debugger again after load time linking. When in
; Wudebug, just press F9 to jump directly to the start of the user executable.
; Until the "jmp eax", this code must remain together. IOW do not insert
; anything before the "jmp eax"!
;
		cmp	isDebugger, 0
		jz	doJmpEAX

		pushfd
		or	DWORD PTR [esp], 10100h
		popfd

doJmpEAX:
		jmp	eax

dllMain		ENDP

.data

ThreadID		dd	12345678h

.data?

ApiInitialFree		dd	?
pspSelector		dd	?
FlatDataSel		dd	?
MainModuleHandle	dd	?
MainModuleFileName	dd	?
EnvArray		dd	?
OldExcHandlers	dq	32 DUP (?)
;TlsArray		dd	64 dup (?)
CommandLine		db	262 dup (?)

.code

;+----------------------------------------------------------------------------
; Win32 - GlobalMemoryStatus
;
GlobalMemoryStatus PROC NEAR

		push	ebp
		mov	ebp, esp
		push	edi
		sub	esp, 30h
		mov	edi, esp
		mov	eax, 500h
		int	31h

		; get percentage

		mov	eax, 100
		mul	DWORD PTR [esp]
		mov	ecx, ApiInitialFree
		div	ecx
		neg	eax
		add	eax, 100
		mov	edx, [ebp+8]
		mov	dwMemoryLoad[edx], eax

		; total physical memory

		mov	eax, [esp+18h]
		shl	eax, 12
		cmp	eax, 0fffff000h
		jnz	@@Memstat00

		mov	eax, ApiInitialFree

@@MemStat00:
		mov	dwTotalPhys[edx], eax

		; available physical memory

		mov	eax, [esp+14h]
		shl	eax, 12
		cmp	eax, 0fffff000h
		jnz	@@Memstat01

		mov	eax, [esp]

@@MemStat01:
		mov	dwAvailPhys[edx], eax
;
; available page file
; this is not quite correct, but as usual, I don't care.
;
		mov	eax, [esp]
		mov	dwAvailPageFile[edx], eax

		; total page file

		mov	eax, [esp+20h]
		cmp	eax, -1
		jnz	@@MemStat03

		sub	eax, eax
		mov	dwAvailPageFile[edx], eax

@@MemStat03:
		mov	dwTotalPageFile[edx], eax
;
; the linear space thing
;
		mov	eax, [esp+0Ch]
		cmp	eax, -1
		jnz	@@MemStat04

		mov	eax, ApiInitialFree

@@MemStat04:
		mov	dwTotalVirtual[edx], eax
;
; virtual available?
;
		mov	eax, [esp+1Ch]
		cmp	eax, -1
		jnz	@@MemStat05

		mov	eax, [esp]

@@MemStat05:		
		mov	dwAvailVirtual[edx], eax
		add	esp, 30h
		pop	edi
		mov	esp, ebp
		pop	ebp
		retn	4

GlobalMemoryStatus ENDP

CriticalSection STRUC
		CsDebugInfo		dd	?
		CsLockCount		dd	?
		CsRecursionCount	dd	?
		CsOwningThread		dd	?
		CsLockSemaphore		dd	?
		CsReserved		dd	?
CriticalSection ENDS


;+----------------------------------------------------------------------------
; Win32 - Stubs for these...
;
; That they are actually doing something is because Stefan Hoffmeister has
; zero tolerance as far uninitialized data and stuff ;-)
;
DeleteCriticalSection LABEL NEAR
		retn	4

LeaveCriticalSection LABEL NEAR
		mov	eax, [esp + 4]
		dec	[eax].CriticalSection.CsLockCount
		sub	edx, edx
		mov	[eax].CriticalSection.CsLockSemaphore, edx
		mov	[eax].CriticalSection.CsOwningThread, edx
		retn	4

EnterCriticalSection LABEL NEAR
		call	GetCurrentThreadId
		mov	edx, [esp + 4]
		mov	[edx].CriticalSection.CsOwningThread, eax
		mov	[edx].CriticalSection.CsLockSemaphore, 1
		inc	[edx].CriticalSection.CsLockCount
		retn	4

InitializeCriticalSection LABEL NEAR
		mov	edx, [esp + 4]
		sub	eax, eax
		mov	[edx], eax
		mov	[edx + 4], eax
		mov	[edx + 8], eax
		mov	[edx + 12], eax
		mov	[edx + 16], eax
		mov	[edx + 20], eax
		retn	4

;+----------------------------------------------------------------------------
; Win32 - GetEnvironmentVariableA
;
GetEnvironmentVariableA PROC NEAR

		push	edi
		push	esi
		cld
		mov	edi, [esp+12]
		mov	esi, edi
		sub	eax, eax
		mov	ecx, -1
		repne	scasb
		lea	ecx, [edi-1]
		sub	ecx, esi
		mov	edx, EnvArray
		sub	eax, eax

@@gevnew:
		push	esi
		push	ecx
		mov	edi, [edx]
		add	edx, 4
		test	edi, edi
		jnz	short @@gevcont

		pop	ecx
		pop	esi
		jmp	short @@gevnotfound

@@gevcont:
		repe	cmpsb
		pop	ecx
		pop	esi
		jnz	short @@gevnew

		cmp	byte ptr [edi], '='
		jnz	short @@gevnew

		inc	edi
		or	ecx, -1
		sub	eax, eax
		repne	scasb
		lea	esi, [edi+ecx+1]
		sub	eax, ecx
		dec	eax
		test	dword ptr [esp+20], -1
		jz	short @@gevdone

		cmp	eax,[esp+20]
		ja	@@gevnotfound

		mov	ecx, eax
		dec	eax
		mov	edi, [esp+16]
		rep	movsb
		jmp	short @@gevdone

@@gevnotfound:
		sub	eax, eax

@@gevdone:
		pop	esi
		pop	edi
		retn	12

GetEnvironmentVariableA ENDP

;+----------------------------------------------------------------------------
; Win32 - SetEnvironmentVariableA (stub thereof)
SetEnvironmentVariableA PROC NEAR

		sub	eax, eax	; return error (???)
		retn	8

SetEnvironmentVariableA ENDP

;+----------------------------------------------------------------------------
; Win32 - GetEnvironmentStrings
GetEnvironmentStringsA LABEL NEAR
GetEnvironmentStrings PROC NEAR

		mov	eax, EnvArray
		mov	eax, [eax]
		ret

GetEnvironmentStringsW LABEL NEAR
		sub	eax, eax
		ret

GetEnvironmentStrings ENDP

;+----------------------------------------------------------------------------
; Win32 - GetLastError
;
GetLastError PROC NEAR

		mov	eax, LastError
		ret

GetLastError ENDP

;+----------------------------------------------------------------------------
; Win32 - GetCurrentThreadId
;
GetCurrentThreadId PROC NEAR

		mov	eax, fs:[TIB.pTEB]
		mov	eax, [eax+24h]
		ret

GetCurrentThreadId ENDP

;+----------------------------------------------------------------------------
; Win32 - GetCommandLineA
;
GetCommandLineA PROC NEAR
		mov	eax, OFFSET CommandLine
		ret

GetCommandLineA ENDP

;+----------------------------------------------------------------------------
; Win32 - ExitProcess
;
ExitProcess	PROC NEAR

		mov	eax, [esp+4]
		mov	ah, 4Ch
		int	21h

ExitProcess	ENDP

;+----------------------------------------------------------------------------
; Some more Win32 - Stubs
;
GetStringTypeW LABEL NEAR
GetStringTypeA LABEL NEAR

		int	3

GetDateFormatA LABEL NEAR

		sub	eax, eax
		retn	24

EnumCalendarInfoA LABEL NEAR	

		mov	LastError, 5555h	; "Don't-bother-me-with-this-
		sub	eax, eax		;  Error"
		retn	16

WritePrivateProfileStringA LABEL NEAR

		mov	eax, 1
		retn	16

;+----------------------------------------------------------------------------
; Win32 - GetPrivateProfileString (Returns just the default)
;
GetPrivateProfileStringA PROC NEAR

		push	dword ptr [esp+12]
		push	dword ptr [esp+20]
		call	lstrcpyA
		push	eax
		call	lstrlenA
		retn	24

GetPrivateProfileStringA ENDP

;+----------------------------------------------------------------------------
; This is ONLY for Delphi 3.01+ compatibility!
;
FormatMessageA PROC NEAR

		mov	edx, OFFSET fmsgmsg
		mov	eax, [esp+20]

@@fmsgaloop:
		mov	cl, [edx]
		inc	edx
		mov	[eax], cl
		inc	eax
		test	cl, cl
		jne	@@fmsgaloop

		sub	eax, [esp+20]
		dec	eax
		retn	28

FormatMessageA ENDP

;+----------------------------------------------------------------------------
; Only a partial implementation, too
;
CompareStringA PROC NEAR

		push	esi
		push	edi

		cmp	dword ptr [esp+24], -1
		jne	short cstra1

		push	dword ptr [esp+20]
		call	lstrlen
		mov	dword ptr [esp+24], eax

cstra1:
		cmp	dword ptr [esp+32], -1
		jne	short cstra2

		push	dword ptr [esp+28]
		call	lstrlen
		mov	dword ptr [esp+32], eax

cstra2:
		mov	eax, 2
		mov	esi, [esp+20]
		mov	edi, [esp+28]
		mov	ecx, [esp+24]
		cmp	ecx, [esp+32]
		jnc	short csta01

		mov	ecx, [esp+32]

csta01:
		cld
		repe	cmpsb
		jne	csta02

		mov	ecx, [esp+24]
		cmp	ecx, [esp+32]
		je	csta03

csta02:
		sbb	eax, eax
		and	eax, 3
		xor	al, 2
			
csta03:
		pop	esi
		pop	edi
		retn	24

CompareStringA ENDP

SetConsoleCtrlHandler LABEL NEAR

		mov	eax, 1
		retn	8

GetVersion LABEL NEAR

		mov	eax, 80000103h
		retn

GetVersionExW LABEL NEAR
GetVersionExA LABEL NEAR

		mov	edx, [esp+4]
		mov	dword ptr [edx+4], 3
		mov	dword ptr [edx+8], 5
		mov	dword ptr [edx+12], 1000
		mov	dword ptr [edx+16], 0
		mov	dword ptr [edx+20], 0
		mov	eax, 1
		retn	4


GetStartupInfoA LABEL NEAR

		mov	edx, [esp+4]
		sub	eax, eax
		mov	DWORD PTR [edx], 17 * 4
		mov	DWORD PTR [edx + 4], eax
		mov	DWORD PTR [edx + 8], eax
		mov	DWORD PTR [edx +12], eax
		mov	DWORD PTR [edx +16], eax
		mov	DWORD PTR [edx +20], eax
		mov	DWORD PTR [edx +24], eax
		mov	DWORD PTR [edx +28], eax
		mov	DWORD PTR [edx +32], 80
		mov	DWORD PTR [edx +36], 25
		mov	DWORD PTR [edx +40], 7
		mov	DWORD PTR [edx +44], eax
		mov	DWORD PTR [edx +48], eax
		mov	DWORD PTR [edx +52], eax
		mov	DWORD PTR [edx +56], eax
		inc	eax
		mov	DWORD PTR [edx +60], eax
		inc	eax
		mov	DWORD PTR [edx +64], eax
		retn	4


.data

	ALIGN 4

tlsbits		dq	-1

.code

;+----------------------------------------------------------------------------
; Win32 - TlsAlloc
;
TlsAlloc PROC NEAR

		bsf	eax, DWORD PTR ds:[OFFSET tlsbits]
		jnz	short TlsAllocSuccess

		bsf	eax, DWORD PTR ds:[offset tlsbits + 4]
		lea	eax, [eax + 32]
		jnz	short TlsAllocSuccess

		or	eax, -1
		retn

TlsAllocSuccess:
		btr	DWORD PTR ds:[offset tlsbits], eax
		retn

TlsAlloc ENDP

;+----------------------------------------------------------------------------
; Win32 - TlsFree
;
TlsFree PROC NEAR

		mov	ecx, [esp + 4]
		cmp	ecx, 64
		sbb	eax, eax
		jnc	TlsFreeError

		bts	DWORD PTR ds:[offset tlsbits], ecx

TlsFreeError:
		and	eax, 1
		retn	4

TlsFree ENDP

;+----------------------------------------------------------------------------
; Win32 - TlsSetValue
;
TlsSetValue PROC NEAR

		mov	ecx, [esp + 4]
		cmp	ecx, 64
		jnc	TlsSetError

		mov	edx, fs:[TIB.pTlsArray]
		mov	eax, [esp + 8]
		mov	[edx + ecx * 4], eax

TlsSetError:
		sbb	eax, eax
		and	eax, 1
		retn	8

TlsSetValue ENDP

;+----------------------------------------------------------------------------
; Win32 - TlsSetValue
;
TlsGetValue PROC NEAR

		mov	ecx, [esp + 4]
		or	LastError, -1			; 2do!
		sub	eax, eax
		cmp	ecx, 64
		jnc	TlsGetError

		mov	LastError, eax
		mov	edx, fs:[TIB.pTlsArray]
		mov	eax, [edx + ecx * 4]

TlsGetError:
		retn	4

TlsGetValue ENDP



;-----------------------------------------------------------------------------
;
; initFPU
;
; - set up FPU exception handler
; - discardable after DLL initialization
;
initFPU		PROC	NEAR
;
; Get CPL
;
		mov	eax, cs
		test	al, 3
		jnz	short @@FpuCheck
;
; If running with CPL=0 we reset EM and MP bits in CR0
;
		mov	eax, cr0
		and	al, NOT 6
		mov	cr0, eax
;
; Check for the presence of a floating point unit
;
@@FpuCheck:
		fninit
		push	5A5Ah
		fstsw	[esp]
		mov	eax, [esp]
		test	al, al
		jnz	short @@NoFpu

		fstcw	[esp]
		pop	eax
		and	eax, 103Fh
		cmp	eax, 3Fh
		jnz	short @@NoFpu1

;-----------------------------------------------------------------------------
; If we have an FPU, perform some magic to initialize FPU exception handling
;-----------------------------------------------------------------------------
;
; Check the CPU type. If we're running on a 386 (or Nx586 or...) we do not try
; to switch to internal FPU exception handling.
;
		mov	eax, 400h
		int	31h
		cmp	cl, 4
		jc	short @@TheHardWay
;
; Check CPL
;
		mov	eax, cs
		lar	eax, eax
		test	ah, 60h
		jnz	short @@TheHardWay
;
; If running at CPL0 we could just try to set the NE bit. If the CPU does not
; support this because it's got an external NPU no harm is caused as we still
; will catch external FPU exceptions from the PIC.
;
		mov	eax, cr0
		or	al, 22h
		mov	cr0, eax

@@TheHardWay:
		mov	bl, dl
		add	bl, 5
		mov	ecx, cs
		mov	edx, OFFSET FPUHandlerPIC
		mov	eax, 205h
		int	31h
		in	al, 0A1h
		and	al, NOT 20h
		out	0A1h, al
		in	al, 21h
		and	al, NOT 4
		out	21h, al
		jmp	short @@FpuDone

@@NoFpu: 
		pop	eax

@@NoFpu1: 
;
; Remove the comments to raise an exception if there's no FPU present but the
; user program tries to use it. Note that this will screw up most HLL compiled
; programs even if they don't actually make use of the FPU as the RTL will
; perform FPU initialization regardless. Not checking for an FPU, OTOH, might
; produce interesting results at best if the system we're running on hasn't
; got an FPU and the program actually makes use of the FPU. Then again, this
; is 1998, after all...
;
;		mov	eax, cs
;		lar	eax, eax
;		test	ah, 60h
;		jnz	short @@FpuDone
;		mov	eax, cr0
;		or	al, 4
;		and	al, NOT 2
;		mov	cr0, eax
;
@@FpuDone:
		ret

initFPU		ENDP

;-----------------------------------------------------------------------------
; initSeh - initialize Win32 - style structured exception handling
;
initSeh		PROC	NEAR
;
; Initialize passing of CPU exceptions
;
;		mov	FlatDataSel, ds
		mov	Cntx.ContextFlags, OUR_CNT
;
; check if running under Wudebug. This does not work anymore the way it used
; to in a floating segment and therefore we rely on the loader to detect the
; debugger and pass on that information.
;
;		mov	eax, cs
;		lsl	eax, eax
;		cmp	eax, esp
;		adc	IsDebugger, 0
;
; Get old exception handlers.
;
		mov	edi, OFFSET OldExcHandlers
		sub	ebx, ebx

GetOldExc:
		mov	eax, 202h
		int	31h
		mov	[edi], edx
		mov	[edi+4], ecx
		add	edi, 8
		inc	ebx
		cmp	bl, 01fh
		jna	GetOldExc
;
; Set new exception handlers.
;
		mov	ecx, cs
		sub	ebx, ebx
		lea	edx, StartEhand

SetNewExc:
		mov	eax, 0203h
		int	31h
		inc	ebx
		add	edx, (OFFSET EndEhand - OFFSET StartEhand)/32
		cmp	bl, 01Fh
		jna	SetNewExc

		ret

initSeh		ENDP

; ############################################################################
; ## Runtime code, non -discardable                                         ##
; ############################################################################

wfseHandler	PROC NEAR

		cmp	haveWfse, 0
		je	@@noWfse

		cmp	ah, 3Dh
		jz	skipHandleTest

		test	bh, 80h
		jz	@@noWfse

skipHandleTest:
		push	eax
		shl	eax, 16
		mov	ax, 0FFFDh
		int	21h
		jnc	@@wfseOk

		pop	eax
@@noWfse:
		int	21h
		ret
		
@@wfseOk:
		add	esp, 4
		ret

wfseHandler	ENDP

.data?

haveWfse	db	?

.data

		align	4

EcodeTab	label	dword

		dd	STATUS_INTEGER_DIVIDE_BY_ZERO
		dd	STATUS_SINGLE_STEP
		dd	STATUS_NONCONTINUABLE_EXCEPTION
		dd	STATUS_BREAKPOINT
		dd	STATUS_INTEGER_OVERFLOW
		dd	STATUS_ARRAY_BOUNDS_EXCEEDED
		dd	STATUS_ILLEGAL_INSTRUCTION
		dd	STATUS_NONCONTINUABLE_EXCEPTION
		dd	STATUS_NONCONTINUABLE_EXCEPTION
		dd	STATUS_NONCONTINUABLE_EXCEPTION 
		dd	STATUS_NONCONTINUABLE_EXCEPTION
		dd	STATUS_NONCONTINUABLE_EXCEPTION
		dd	STATUS_STACK_OVERFLOW
		dd	STATUS_PRIVILEGED_INSTRUCTION
		dd	STATUS_ACCESS_VIOLATION
EAddress	dd	0

BackTrans	label	dword
		dd	STATUS_INTEGER_DIVIDE_BY_ZERO
		dd	STATUS_SINGLE_STEP
		dd	STATUS_NONCONTINUABLE_EXCEPTION
		dd	STATUS_BREAKPOINT
		dd	STATUS_INTEGER_OVERFLOW
		dd	STATUS_ARRAY_BOUNDS_EXCEEDED
		dd	STATUS_ILLEGAL_INSTRUCTION
		dd	STATUS_STACK_OVERFLOW
		dd	STATUS_PRIVILEGED_INSTRUCTION
		dd	STATUS_ACCESS_VIOLATION
		dd	STATUS_NO_MEMORY
		dd	STATUS_CONTROL_C_EXIT
		dd	STATUS_FLOAT_DENORMAL_OPERAND
		dd	STATUS_FLOAT_DIVIDE_BY_ZERO
		dd	STATUS_FLOAT_INEXACT_RESULT
		dd	STATUS_FLOAT_INVALID_OPERATION
		dd	STATUS_FLOAT_OVERFLOW
		dd	STATUS_FLOAT_STACK_CHECK
		dd	STATUS_FLOAT_UNDERFLOW
		dd	0

BackString	label	near
		dd	offset ExcStr0
		dd	offset ExcStr1
		dd	offset ExcStr2
		dd	offset ExcStr3
		dd	offset ExcStr4
		dd	offset ExcStr5
		dd	offset ExcStr6
		dd	offset ExcStr7
		dd	offset ExcStr8
		dd	offset ExcStr9
		dd	offset ExcStr10
		dd	offset ExcStr11
		dd	offset ExcStr12
		dd	offset ExcStr13
		dd	offset ExcStr14
		dd	offset ExcStr15
		dd	offset ExcStr16
		dd	offset ExcStr17
		dd	offset ExcStr18
		dd	offset ExcStrUnavail

ExcStr0		db	'Integer divide by zero',0
ExcStr1		db	'Single step',0
ExcStr2		db	'Noncontiunuable exception',0
ExcStr3		db	'Breakpoint',0
ExcStr4		db	'Integer overflow',0
ExcStr5		db	'Array bounds exceeded',0
ExcStr6		db	'Illegal instruction',0
ExcStr7		db	'Stack overflow',0
ExcStr8		db	'Privileged instruction',0
ExcStr9		db	'Access violation',0
ExcStr10	db	'No memory',0
ExcStr11	db	'Control C exit',0
ExcStr12	db	'Float denormal operand',0
ExcStr13	db	'Float divide by zero',0
ExcStr14	db	'Float inexact result',0
ExcStr15	db	'Float invalid operation',0
ExcStr16	db	'Float overflow',0
ExcStr17	db	'Float stack check',0
ExcStr18	db	'Float underflow',0

IsDebugger	db	0
IsFPUExc	db	0

;-----------------------------------------------------------------------------
; Exception vectors, these are passed to the DPMI host as handler addresses
;
.code
StartEhand	label	near

i = 0
REPT	32
	elabel	CATSTR <Exception>,%i
elabel:
		push	i
		jmp	short @@UnwindException
	i = i + 1
ENDM

EndEhand	label	near

;-----------------------------------------------------------------------------
; Common code to physically process all kinds of exceptions
;
@@UnwindException:

		push	ds
		mov	ds, cs:[FlatDataSel]	; so we can write data too
;
; If load is in progress, don't call the exception handler
; Removed for true flat where this doesn't matter anymore.
;
;		cmp	DWORD PTR fs:[0], -1
;		jz	short @@ChainDebugger

		; if the exception wasn't raised within our default code
		; segment, we pass it to the old handler

		push	eax
		mov	eax, cs
		cmp	ax, [esp+28]
		pop	eax
		jnz	short @@ChainDebugger
;
; if the debugger is running, pass control to the debugger first
;
		cmp	IsDebugger, 0
		jz	short @@NoDebugger
;
; If it's been a breakpoint or single step, don't raise a WIN exception if a
; debugger is present.
;
		cmp	BYTE PTR [esp+4], 1
		jz	short @@ChainDebugger

		cmp	BYTE PTR [esp+4], 3
		jz	short @@ChainDebugger
;
; Exception triggered the first time? (swap adresses and compare)
;
		push	eax
		mov	eax, [esp+24]
		xchg	eax, EAddress
		cmp	eax, EAddress
		pop	eax
		jz	short @@NoDebugger

@@ChainDebugger:
;
; Put the address to jump to on the stack
;
		pop	ds
		xchg	eax, [esp]
		push	DWORD PTR cs:[offset OldExcHandlers+eax*8]
		mov	eax, DWORD PTR cs:[offset OldExcHandlers+eax*8+4]
		xchg	eax, [esp+4]
		retf

@@NoDebugger:
;
; Save general registers
;
		mov	Cntx.CntEax, eax
		mov	Cntx.CntEbx, ebx
		mov	Cntx.CntEcx, ecx
		mov	Cntx.CntEdx, edx
		mov	Cntx.CntEsi, esi
		mov	Cntx.CntEdi, edi
		mov	Cntx.CntEbp, ebp
;
; Save segment registers
;
		mov	eax, [esp]
		mov	Cntx.CntSegDs, eax
		mov	Cntx.CntSegEs, es
		mov	Cntx.CntSegFs, fs
		mov	Cntx.CntSegGs, gs
;
; Get things pushed on stack by the DPMI host
;
		mov	eax, [esp+20]
		mov	Cntx.CntEip, eax
		mov	Erec.ExceptionAddress, eax
		mov	eax, [esp+24]
		mov	Cntx.CntSegCs, eax
		mov	eax, [esp+28]
		mov	Cntx.CntEflags, eax
		mov	eax, [esp+32]
		mov	Cntx.CntEsp, eax
		mov	eax, [esp+36]
		mov	Cntx.CntSegSs, eax
;
; Get exception number
;
		mov	eax, [esp+4]
		cmp	al, 16
;
; Do some magic if FPU exception
;
		jnz	short @@NoFPUExc
		call	FPUSetError

@@NoFPUExc:
		cmp	al, 7
		jnz	short @@AsUsual

		cmp	IsFPUExc, 0
		jz	@@AsUsual

		mov	IsFPUExc, 0
		mov	eax, cs
		lar	eax, eax
		test	ah, 60h
		jnz	short @@Exc7TryWin

@@ExcTryHarder:
		mov	eax, cr0
		nop
		and	al, NOT 4
		or	al, 2
		mov	cr0, eax
		jmp	short @@Exc7WinDone

@@Exc7TryWin:
		mov	eax,0E01h
		push	ebx
		mov	bl, 1
		int	31h
		pop	ebx
		jc	short @@ExcTryHarder

@@Exc7WinDone:
		mov	eax, 16
;
; If no CPU exception, translate into Win32 error code
;
@@AsUsual:
		cmp	al, 16
		jz	short @@ExcNocode

		; translate into Win32 exception code

		mov	eax, ECodeTab[eax*4]
		mov	Erec.ExceptionCode, eax

		mov	Erec.NumParams, 1
		mov	eax, [esp+16]
		mov	DWORD PTR ds:[offset Erec.ExceptionInfo], eax

@@ExcNocode:
;
; Initialize segment registers
;
		mov	es, FlatDataSel
;		mov	fs, FlatDataSel
;
; Manipulate the stack frame
;
		mov	DWORD PTR [esp+20], offset CPUExceptionHandler
		add	esp, 8			; skip exception number and ds
		retf				; terminate exception handler

; ############################################################################

;-----------------------------------------------------------------------------
; FPUSetError - Translate bit positions in FPU error code to Win 32
;
.data
FPUExcTable		db	90h,8dh,8eh,91h,93h,8fh,92h

.code
FPUSetError	PROC	NEAR

		push	eax
		push	edx
		push	0
		fnstsw	[esp]
		mov	eax, [esp]
		fnstcw	[esp]
		fnclex
		pop	edx
		not	edx
		or	edx, 1000000b
		and	eax, 1111111b
		and	edx, eax
		bsf	eax, edx
		mov	edx, 0c0000000h
		mov	dl, FPUExcTable[eax]
		mov	Erec.ExceptionCode, edx
		pop	edx
		pop	eax
		retn

FPUSetError	ENDP

;-----------------------------------------------------------------------------
; FPUHandlerPIC
;
; This one is really horrible, but it seems to be the only way to get it done
; in all kinds of Windows too.
;
FPUHandlerPIC	PROC	NEAR
;
; Make the next ESC opcode cause an exception
;
		push	eax
		push	ds
		mov	ds, cs:FlatDataSel
		call	FPUSetError
		mov	eax, cs
		lar	eax, eax
		test	ah, 60h
		jnz	short @@FPUTryWin

@@FPUTryHarder:
		mov	eax, cr0
		nop
		and	al, NOT 2
		or	al, 4
		mov	cr0, eax
		jmp	short @@FPUCr0Done

@@FPUTryWin:
		push	ebx
		mov	eax, 0E01h
		mov	bl, 2
		int	31h
		pop	ebx
		jc	short @@FPUTryHarder

@@FPUCr0Done:
		mov	IsFPUExc, 1
;
; Clear the PIC (???)
;
		mov	al, 20h
		out	0a0h, al
		out	020h, al
		pop	ds
		pop	eax
		iretd

FPUHandlerPIC	ENDP

;-----------------------------------------------------------------------------
; CPUExceptionHandler - After an excetion has been physically processed,
;                       execution will continue in THIS context for logical
;                       processing of the exception.
;
CPUExceptionHandler	PROC	NEAR

		push	offset Erec.ExceptionInfo
		push	Erec.Numparams
		push	NOT_CONTINUABLE
		push	Erec.ExceptionCode
		call	RaiseException
;
; If this one returns, terminate the program
;
		push	offset Erec
		push	offset Cntx
		call	DumpCntx
;
; ....never returns
;
CPUExceptionHandler	ENDP

; ############################################################################
; ## Number display etc.                                                    ##
; ############################################################################

;-----------------------------------------------------------------------------
; OutHex4 -4 digit hex output of parameter
;
OutHex4		PROC	NEAR

		mov	ecx, [esp+4]
		mov	eax, 30000200h
		ror	ecx, 12

@@oh401:
		mov	dl, cl
		and	dl, 0Fh
		cmp	dl, 0Ah
		jc	short @@oh400
		add	dl, 7

@@oh400:
		add	dl, 30h
		int	21h
		rol	ecx, 4
		sub	eax, 10000000h
		jnc	short @@oh401
		
		retn	4

OutHex4		ENDP

;-----------------------------------------------------------------------------
; OutHex8 - 8 digit hex output of parameter
;
OutHex8		PROC	NEAR

		mov	eax, [esp+4]
		shr	eax, 16
		push	eax
		call	OutHex4
		push	DWORD PTR [esp+4]
		call	OutHex4
		retn	4

OutHex8		ENDP

;-----------------------------------------------------------------------------
; OutSel - Dump info as if parameter is a selector
;
OutSel		PROC	NEAR

		push	ebx
		mov	ebx, [esp+8]
		push	ebx
		call	OutHex4
		mov	eax, 6
		int	31h
		jnc	short @@os001
		push	offset ExcStrUnavail
		call	OutStr
		pop	ebx
		retn	4

@@os001:
		push	edx
		push	ecx
		push	offset ExcStrBase
		call	OutStr
		call	OutHex4
		call	OutHex4		
		push	offset ExcStrLimit
		call	OutStr
		lsl	eax, ebx
		push	eax
		call	OutHex8
		push	offset ExcStrAcc
		call	OutStr
		lar	eax, ebx
		shr	eax, 8
		push	eax
		call	OutHex4
		pop	ebx
		retn	4

OutSel		ENDP

;-----------------------------------------------------------------------------
; OutStr - Output parameter as string
;
OutStr		PROC	NEAR

		mov	ecx, [esp+4]

@@ost001:
		mov	dl, [ecx]
		inc	ecx
		test	dl, dl
		jz	short @@ost000
		mov	ah, 2
		int	21h
		jmp	short @@ost001

@@ost000:
		retn	4

OutStr		ENDP

;-----------------------------------------------------------------------------
; Dump Cntx - Dump an aborted programs context to sreen and say bye- bye
;
DumpCntx	PROC	NEAR
		mov	esi, [esp+4]
		mov	ebp, [esp+8]
		mov	edi, offset ExcStrContext
		mov	eax, CntEIP[esi]
		push	eax
		call	getModuleFromAddress
		xchg	edx, [esp]
		push	edx
		sub	edx, eax
		push	edx
		smsw	ax		; actually: smsw eax
		push	eax
		push	CntEflags[esi]
		push	DWORD PTR CntSegSS[esi]
		push	DWORD PTR CntSegGS[esi]
		push	DWORD PTR CntSegFS[esi]
		push	DWORD PTR CntSegES[esi]
		push	DWORD PTR CntSegDS[esi]
		push	DWORD PTR CntSegCS[esi]
		push	CntESP[esi]
		push	CntEBP[esi]
		push	CntEDI[esi]
		push	CntESI[esi]
		push	CntEDX[esi]
		push	CntECX[esi]
		push	CntEBX[esi]
		push	CntEAX[esi]
		mov	eax, [ebp]
		sub	edx, edx

@@dc00a0:
		cmp	eax, BackTrans[edx]
		jz	short @@dc00aa
		test	DWORD PTR BackTrans[edx], -1
		jz	short @@dc00aa
		add	edx, 4
		jmp	short @@dc00a0

@@dc00aa:
		push	DWORD PTR BackString[edx]
		push	eax

DC0000:
;
; Get current video mode
;
		mov	ah, 0Fh
		int	10h
		and	al, 7Fh
		cmp	al, 3
		je	short @@geDontDoModeSet

		mov	eax, 3
		int	10h

@@geDontDoModeSet:
		mov	dl, [edi]
		inc	edi
		test	dl, dl
		jz	@@dc0001
		cmp	dl, '%'
		jnz	@@dc0002
		mov	dl, [edi]
		inc	edi
		cmp	dl, '4'
		jnz	@@dc0003
		call	OutHex4
		jmp	short @@geDontDoModeSet

@@dc0003:
		cmp	dl, '8'
		jnz	@@dc0004
		call	OutHex8
		jmp	short @@geDontDoModeSet

@@dc0004:
		cmp	dl, 'a'
		jnz	@@dc0005
		call	OutStr
		jmp	short @@geDontDoModeSet

@@dc0005:
		call	OutSel
		jmp	short @@geDontDoModeSet

@@dc0002:
		mov	ah, 2
		int	21h
		jmp	short @@geDontDoModeSet

@@dc0001:
;
; Reset mouse driver, if any, to avoid a custom handler call going to nowhere
;
		sub	eax, eax
		int	33h
;
; Get out
;
		mov	eax, 4CFFh
		int	21h

DumpCntx	ENDP

;+----------------------------------------------------------------------------
; GenericError - Public wrapper for DumpCntx to report generic errors and
;                terminate afterwards.
;
; Basically, we operate in a similiar fashion as good ol' printf. Anyway,
; the format specifiers have different meanings and there are fewer of these:
;
; %a - ASCIIZ String
; %8 - 8 Digits hex number (32 bit)
; %4 - 4 Digits hex number (16 bit)
; %s - Display parameter's descriptor properties as if it was a selector
;
GenericError	PROC NEAR

		pop	edi	; Dump return address as we don't return.
		pop	edi	; Get format string
		jmp	DC0000

GenericError	ENDP

.data?

Cntx		ContextRecord <>
Erec		ExceptionRecord <>

.data

ExcStrContext	db	'WDOSX Win32 subsystem: Abort from unhandled exception.',0dh,0ah
		db	'EXCEPTION_RECORD: Code = %8  Description = %a',0dh,0ah
		db	'CONTEXT dump:',0dh,0ah
		db	'EAX = %8  EBX = %8  ECX = %8  EDX = %8',0dh,0ah
		db	'ESI = %8  EDI = %8  EBP = %8  ESP = %8',0dh,0ah
		db	'CS = %s',0dh,0ah
		db	'DS = %s',0dh,0ah
		db	'ES = %s',0dh,0ah
		db	'FS = %s',0dh,0ah
		db	'GS = %s',0dh,0ah
		db	'SS = %s',0dh,0ah
		db	'EFL = %8  CR0 = %8  '
		db	'RVA = %8  EIP = %8',0dh,0ah
		db	'Exception occured in module %a.',0dh,0ah,0
ExcStrUnavail	db	'  N/A',0
ExcStrBase	db	'   Base = ',0
ExcStrLimit	db	'  Limit = ',0
ExcStrAcc	db	'  Type/Acc = ',0

fmsgmsg		db	'Default error notification',0

.code

; ############################################################################
; ## Module export functions                                                ##
; ############################################################################

;+----------------------------------------------------------------------------
; W32 - RaiseException
;
RaiseException	PROC	NEAR

		push	ebp
		mov	ebp, esp
;
; Build ExceptionRecord on Stack
;
		mov	edx, [ebp+20]		; pointer to arguments
		mov	ecx, [ebp+16]		; number of arguments
		mov	eax, ecx
		jecxz	@@ReNoCpy

@@ReDoCpy:
		push	DWORD PTR [ecx*4-4+edx]
		loop	short @@ReDoCpy

@@ReNoCpy:
		push	eax			; Num args
		push	Cntx.CntEip
		push	0
		push	DWORD PTR [ebp+12]	; flags
		push	DWORD PTR [ebp+8]	; code

		; traverse handler chain

		mov	edx, fs: [ecx]

@@ReCallHandler:
		cmp	edx, -1
		jz	@@ReNoHandler		; should never happen

		mov	eax, esp
		push	edx
		push	edx
		push	offset Cntx
		push	edx
		push	eax
		call	pEhandler[edx]
		add	esp, 16
		pop	edx
		mov	edx, pPrevious[edx]
		test	eax, eax		; did the handler do something?
		jnz	short @@ReCallHandler

@@ReNoHandler:
		mov	esp, ebp
		pop	ebp
		retn	16

RaiseException	ENDP

;+----------------------------------------------------------------------------
; W32 - UnhandledExceptionFilter
;

UnhandledExceptionFilter PROC NEAR


		sub	eax,eax		; "EXCEPTION_CONTINUE_EXECUTION"
		retn	4

UnhandledExceptionFilter ENDP

;+----------------------------------------------------------------------------
; Win32 - RtlUnwind
;
; Since this is very poorly documented, we shall consider this a sufficient
; implementation. It will cope with all RTLs seen so far, so what?
;
RtlUnwind LABEL NEAR
;
; Check whether to unwind all exceptions
;
		cmp	DWORD PTR [esp+4], 1
;
; Set to end of chain if so
;
		sbb	DWORD PTR [esp+4], 0
;
; Kill return address
;
		pop	edx
;
; Check whether we still need to call handlers
;
		mov	edx, [esp+8]		; edx = ExceptionRecord
		test	edx, edx
		jnz	short @@UnwindChain

@@UnwindDone:
		pop	DWORD PTR fs:[0]
		retn	8

@@UnwindChain:
;
; Check if done
;
		mov	ecx, fs:[0]		; ecx = DispatchRecord

@@UnwindNext:
		cmp	ecx, [esp]
		jz	short @@UnwindDone

		push	ecx
		push	edx
		push	ecx
		push	0			; may not work
		push	ecx
		push	edx		
		call	pEHandler[ecx]
		add	esp, 16
		pop	edx
		pop	ecx
		mov	ecx, pPrevious[ecx]
		jmp	short @@UnwindNext

;+---------------------------------------------------------------------------
; Win32 - OutputDebugString
;
; We do nothing as of yet...
;
OutputDebugString PROC NEAR

		retn	4
OutputDebugString ENDP


; ############################################################################

.data
PUBLIC		LastError
		LastError	dd	0
		isLoadTime	db	1

		align	4

END	dllMain

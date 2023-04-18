; ############################################################################
; ## WDOSX DOS Extender           Copyright (c) 1996, 1998, Michael Tippach ##
; ##                                                                        ##
; ## Realeased under the terms of the WDOSX license agreement.              ##
; ############################################################################
;
; $Header: E:/RCS/WDOSX/0.95/SRC/WIN32/USER32.ASM 1.1 1998/08/03 01:48:32 MikeT Exp MikeT $
;
; ----------------------------------------------------------------------------
;
; $Log: USER32.ASM $
; Revision 1.1  1998/08/03 01:48:32  MikeT
; Initial check in
;
;
; ----------------------------------------------------------------------------
; ############################################################################
; ## Main module of User32 -> DPMI wrapper                                  ##
; ############################################################################

.386p
.model flat

include w32struc.inc

.code

		PUBLICDLL		EnumThreadWindows
		PUBLICDLL		MessageBoxA
		PUBLICDLL		GetKeyboardType
		PUBLICDLL		GetSystemMetrics
		PUBLICDLL		LoadStringA

;+----------------------------------------------------------------------------
; DLL entry point.
;
dllMain PROC NEAR
;
; This would have been the real Win32 arguments:
;
;arg		dwHandle:   DWORD
;arg		dwReason:   DWORD
;arg		dwReserved: DWORD

		mov	eax, 1
		retn	12

dllMain ENDP

EnumThreadWindows LABEL NEAR

		mov	eax, 1
		retn	12

;+----------------------------------------------------------------------------
; Win32 - MessageBoxA
;
MessageBoxA PROC NEAR

		mov	ah, 0Fh
		int	10h
		and	al, 7Fh
		cmp	al, 3
		jz	@@mbaModeOk

		mov	ax, 3
		int	10h

@@mbaModeOk:
		push	DWORD PTR [esp+12]
		call	doDosString
		mov	dl, 0Dh
		mov	ah, 2
		int	21h
		mov	dl, 0Ah
		mov	ah, 2
		int	21h
		push	DWORD PTR [esp+8]
		call	doDosString
                mov     dl, 0Dh
                mov     ah, 2
                int     21h
                mov     dl, 0Ah
                mov     ah, 2
                int     21h
		mov	eax, 1			; IDOK
		retn	16

MessageBoxA ENDP


GetKeyboardType LABEL NEAR

		mov	eax, 4
		cmp	byte ptr [esp+4], 2
		jz	short gkbt00
		mov	eax, 12

gkbt00:
		retn	4

GetSystemMetrics LABEL NEAR

		sub	eax, eax
		retn	4

; ############################################################################; ############################################################################
; ## Functions dealing with resources                                       ##
; ############################################################################

LoadStringA PROC NEAR
;
; The next is guesswork:
;
		mov	eax, [esp+8]
		add	eax, 16
		push	eax
		shr	dword ptr [esp], 4
		and	eax, 0Fh
		mov	[esp+12], eax
		push	6
		push	DWORD PTR [esp+12]
		call	GetResource
		test	eax, eax
		jz	@@lsaError
;
; EAX -> resource data entry
; [esp+8] number of strings to skip
;
		sub	ecx, ecx
		mov	edx, [eax]
		add	edx, [esp+4]

@@lsaStrLoop:
		dec	DWORD PTR [esp+8]
		mov	cx, [edx]
		js	short @@lsaIsStr

		lea	edx, [edx+ecx*2+2]
		jmp	short @@lsaStrLoop

@@lsaIsStr:
;
; EDX -> wide char string
; ECX = size in wide chars
;
		cmp	ecx, [esp+16]
		jc	short @@lsaSizeOk

		mov	ecx, [esp+16]
		test	ecx, ecx
		jz	short @@lsaError
		dec	ecx

@@lsaSizeOk:
		jecxz	@@lsaError
		mov	[esp+16], ecx
		push	ecx		
		mov	ecx, [esp+16]

@@lsaLoop:
		add	edx, 2
		mov	al, [edx]
		mov	[ecx], al
		inc	ecx
		dec	dword ptr [esp+20]
		jnz	@@lsaLoop

		mov	BYTE PTR [ecx], 0
		pop	eax
		retn	16
@@lsaError:
		sub	eax, eax
		retn	16

LoadStringA ENDP

; ############################################################################
; ## Helper functions                                                       ##
; ############################################################################

;
; void _stdcall *GetResource(unsigned long hModule, unsigned long TYID, \
;                            unsigned long NID);
; Since the API emulator does not have language support, we take the first
; entry found.
;
GetResource PROC NEAR
;
; Get start of resource section
;
		mov	eax, [esp+4]
		mov	edx, [eax+60]
		mov	edx, [edx+eax+88h]
		add	edx, eax
		push	edx
		cmp	edx, eax
		jz	@@gresError
;
; Get named entries to skip
;
		mov	eax, [edx+12]
		mov	ecx, [edx+12]
		shr	ecx, 16
		and	eax, 0FFFFh
		lea	edx, [edx+eax*8+16]
;		
; EDX = first Type ID entry
;
		jecxz	short @@gresError

@@gresTypeLoop:
		mov	eax, [edx]
		cmp	eax, [esp+12]
		jz	short @@gresTypeOk

		add	edx, 8
		loop	short @@gresTypeLoop

		jmp	short @@gresError

@@gresTypeOk:
		mov	eax, [edx+4]
		mov	edx, [esp]
		test	eax, eax
		lea	eax, [eax+edx]
		jns	@@gresDone

		; eax bit 30..0 pointing to sub directory now

		mov	edx, [eax+12-80000000h]
		mov	ecx, [eax+12-80000000h]
		shr	ecx, 16
		and	edx, 0FFFFh
		lea	edx, [eax+edx*8+16-80000000h]
		jecxz	short @@gresError

@@gresNameLoop:
		mov	eax, [edx]
		cmp	eax, [esp+16]
		jz	short @@gresNameOk

		add	edx, 8
		loop	short @@gresNameLoop

		jmp	short @@gresError

@@gresNameOk:
		mov	eax, [edx+4]
		mov	edx, [esp]
		test	eax, eax
		lea	eax, [eax+edx]
		jns	short @@gresDone
;
; the entry may exist for different languages
; we just take the first one, who cares...
;
		cmp	dword ptr [eax+12-80000000h], 0
		mov	eax, [eax+20-80000000h]
		jnz	short @@gresDone

@@gresError:
		sub	eax, eax
		sub	eax, [esp]

@@gresDone:
		pop	edx
		add	eax, edx
		retn	12

GetResource ENDP

doDosString PROC NEAR

		mov	ecx, [esp+4]
		jecxz	ddstrDone
		mov	dh, 0

ddstrLoop:
		mov	dl, [ecx]
		test	dl, dl
		jnz	ddstrDoOut

ddstrDone:
		retn	4

ddstrDoOut:
		cmp	dl, 0Ah
		jne	ddstrFixDone

		cmp	dh, 0Dh
		je	ddstrFixDone

		mov	dl, 0Dh
		dec	ecx

ddstrFixDone:
		mov	dh, dl
		mov	ah, 2
		int	21h
		inc	ecx
		jmp	ddstrLoop

doDosString ENDP

END	dllMain

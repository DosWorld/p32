; ############################################################################
; ## WDOSX DOS Extender           Copyright (c) 1996, 1998, Michael Tippach ##
; ##                                                                        ##
; ## Realeased under the terms of the WDOSX license agreement.              ##
; ############################################################################
;
; $Header: E:/RCS/WDOSX/0.95/SRC/WIN32/k32spawn.asm 1.2 1998/09/26 16:53:51 MikeT Exp MikeT $
;
; ----------------------------------------------------------------------------
;
; $Log: k32spawn.asm $
; Revision 1.2  1998/09/26 16:53:51  MikeT
; Fixed command line processing.
; Verified to work now with Borland's TVDEMO.EXE.
;
; Revision 1.1  1998/09/16 22:19:31  MikeT
; Initial check in. Still needs testing.
;
;
; ----------------------------------------------------------------------------
; ############################################################################
; ## Win32 - Spawn- type functions.                                         ##
; ############################################################################

.386p
.model flat

include w32struc.inc

.code

		PUBLICDLL	CreateProcessA
		PUBLICDLL	GetExitCodeProcess

		EXTRN		LastError: NEAR

;+----------------------------------------------------------------------------
; Win32 - CreateProcessA
;
CreateProcessA PROC NEAR
		sub	eax, eax			; assume error
		pushad
		mov	ebp, [esp + 28 + 32]
		test	ebp, ebp
		jne	@@gotEnv

		mov	ah, 62h
		int	21h
		push	ds
		mov	ds, ebx
		mov	bx, ds:[2Ch]
		pop	ds
		mov	ax, 6
		int	31h
		shrd	ebp, edx, 16
		shrd	ebp, ecx, 16

@@gotEnv:
		mov	edx, [esp + 4 + 32]
		mov	ecx, [esp + 8 + 32]
		test	edx, edx
		jne	@@gotFileName

		mov	edx, ecx

@@gotFileName:
		test	ecx, ecx
		jne	@@scanCmdLine

		mov	ecx, edx

@@scanCmdline:
;
; If ecx != edx then we do already have a valid program name and command line.
; Otherwise we have to split these.
;
		sub	eax, eax
		cmp	ecx, edx
		sete	ah


@@scanCmdLoop:
		cmp	BYTE PTR [ecx], 21h
		inc	ecx
		jnc	@@scanCmdLoop
;
; ECX -> DOS command line
;
		test	ah, ah
		jz	@@twoPointers

		mov	al, [ecx - 1]
		mov	BYTE PTR [ecx - 1], 0

@@twoPointers:
		push	eax			; save character
		push	ecx			; save ->
		sub	al, 1			; CF if already 0
		sbb	ecx, 0			; point to 0 if so
		mov	eax, ds
		shl	eax, 16
		push	eax
		add	esp, 2
		push	ecx
		push	eax
		add	esp, 2
		push	ebp
		mov	ax, 4B00h
		mov	ebx, esp
		int	21h
		lea	esp, [esp + 12]
		pop	ecx
		pop	eax
		dec	ah			; Don't modify carry flag
		jnz	@@backFixDone

		mov	[ecx - 1], al

@@backFixDone:
		mov	eax, [esp + 32 + 40]
		mov	ebx, 12345678h
		mov	[eax], ebx
		mov	[eax + 4], ebx
		mov	[eax + 8], ebx
		mov	[eax + 12], ebx
;
; 2Do: SetLastError
;
		popad
		setnc	al
		retn	40
CreateProcessA ENDP

;+----------------------------------------------------------------------------
; Win32 - GetExitCodeProcess
;
GetExitCodeProcess PROC NEAR
		sub	eax, eax
		cmp	DWORD PTR [esp + 4], 12345678h
		jne	@@exit

		mov	edx, [esp + 8]
		mov	ah, 4Dh
		int	21h
		sub	ah, ah
		mov	[edx], eax
		mov	al, 1

@@exit:
		retn	8
GetExitCodeProcess ENDP

END

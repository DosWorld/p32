; ############################################################################
; ## WDOSX DOS Extender           Copyright (c) 1996, 1998, Michael Tippach ##
; ##                                                                        ##
; ## Realeased under the terms of the WDOSX license agreement.              ##
; ############################################################################
;
; $Header: E:/RCS/WDOSX/0.95/SRC/WIN32/k32heap.asm 1.2 1998/08/23 14:17:30 MikeT Exp MikeT $
;
; ----------------------------------------------------------------------------
;
; $Log: k32heap.asm $
; Revision 1.2  1998/08/23 14:17:30  MikeT
; Add Heap* funs
;
; Revision 1.1  1998/08/03 01:41:22  MikeT
; Initial check in
;
;
; ----------------------------------------------------------------------------
; ############################################################################
; ## k32heap.asm - Very simplistic local heap manager                       ##
; ############################################################################

.386

include w32struc.inc

.model flat
.code
;
; Dummy's
;
		PUBLICDLL	GlobalAlloc
		PUBLICDLL	GlobalReAlloc
		PUBLICDLL	GlobalFree
		PUBLICDLL	GlobalLock
		PUBLICDLL	GlobalUnlock
		PUBLICDLL	GlobalSize
		PUBLICDLL	GlobalFlags
		PUBLICDLL	GlobalHandle
;
; These are experimental
;
		PUBLICDLL	HeapCreate
		PUBLICDLL	HeapDestroy
		PUBLICDLL	HeapAlloc
		PUBLICDLL	HeapFree
;
; These are for real
;
		PUBLICDLL	LocalAlloc
		PUBLICDLL	LocalFree

		PUBLIC		initHeap

		EXTRN		VirtualAlloc: NEAR
		EXTRN		GenericError: NEAR

.data
		EXTRN		MainModuleHandle: DWORD

.code

;-----------------------------------------------------------------------------
; These are stubbed out so far
;
GlobalAlloc LABEL NEAR
		sub	eax, eax
		retn	8

GlobalReAlloc LABEL NEAR
		sub	eax, eax
		retn	12

GlobalFree LABEL NEAR
GlobalLock LABEL NEAR
GlobalUnlock LABEL NEAR
GlobalSize LABEL NEAR
GlobalHandle LABEL NEAR
		sub	eax, eax
		retn	4

GlobalFlags LABEL NEAR
		mov	eax, GMEM_INVALID_HANDLE
		retn	4

;+----------------------------------------------------------------------------
; Win32 - LocalFree
;
LocalFree PROC NEAR

		mov	eax, [esp+4]
		sub	eax, 8
		mov	edx, OFFSET StartOfHeap

lf_next_mcb:
		cmp	eax, [edx]			; next one?
		jz	short lf_found

		mov	edx, [edx]
		test	edx, edx			; not an mcb anymore?
		jnz	lf_next_mcb

		mov	eax, [esp+4]
		retn	4

lf_found:
;
; Check if we can concatenate with previous one
;
		cmp	edx, OFFSET StartOfHeap	; is there?
		jz	short lf_check_behind
		test	DWORD PTR [edx.mcb_desc], mcb_free
		jz	short lf_check_behind
;
; can concatenate
;
		mov	ecx, [eax]
		mov	[edx], ecx
;
; Check if block behind next block also free
;
		test	ecx, ecx			; something behind?
		jz	short lf_done

lf_testnext:
		test	dword ptr [ecx.mcb_desc], mcb_free
		jz	short lf_done
;
; Can concatenate now
;
		mov	eax, [ecx]
		mov	[edx], eax
		jmp	short lf_done

lf_check_behind:
		or	dword ptr [eax.mcb_desc], mcb_free
		mov	edx, eax
		mov	ecx, [eax]
		test	ecx, ecx
		jnz	lf_testnext

lf_done:
		sub	eax, eax
		retn	4

LocalFree ENDP

;+----------------------------------------------------------------------------
; Win32 - LocalAlloc
;
LocalAlloc PROC NEAR
;
; find a memory block of desired size
; 2do: best fit rather than first fit ???
;
		mov	edx, [esp+8]		; get size
		add	edx, 8+3		; add mcb size & roundoff
;
; 2do: other allocation granularity ???
;
		and	dl, 0FCh
		mov	ecx, StartOfHeap

@@laexam_mcb:
		cmp	[ecx.mcb_next], 0	; last one?
		jz	short @@latry_end
;
; check if free
;
		test	[ecx.mcb_desc], mcb_free
		jnz	short @@lacheck_size
;
; get next
;
@@laget_next:
		mov	ecx, [ecx.mcb_next]
		jmp	short @@laexam_mcb

@@lacheck_size:
		mov	eax, [ecx.mcb_next]
		sub	eax, ecx
;
; actual size in eax
;
		cmp	eax, edx
		jc	short @@laget_next
;
; After all, it fits
;
		lea	edx, [ecx+8]
		and	[ecx.mcb_desc], not mcb_free	; mark as used
		jmp	short @@lasuccess

@@latry_end:
		lea	eax, [ecx+edx+8]
		cmp	eax, EndOfHeap
		jnc	short @@laerror
;
; Initialize new mcb
;
		sub	eax, 8
		mov	[ecx.mcb_next], eax
		mov	[eax.mcb_next], 0		; mark as last in chain
		and	[ecx.mcb_desc], not mcb_free	; mark as used
		lea	edx, [ecx+8]
@@lasuccess:
;
; handle in edx
; check for zeroinit
;
		test	byte ptr [esp+4], 40h
		jz	short @@laexit

		push	edi
		cld
		mov	edi, eax
		mov	ecx, [esp+8]
		add	ecx, 3
		shr	ecx, 2
		sub	eax, eax
		rep	stosd
		pop	edi

@@laexit:
		mov	eax, edx
		retn	8

@@laerror:
		sub	eax, eax
		retn	8

LocalAlloc ENDP

;+---------------------------------------------------------------------------
; Win32 - HeapCreate
;
HeapCreate PROC NEAR
		mov	eax, 1			; "handle"
		retn	12
HeapCreate ENDP


;+---------------------------------------------------------------------------
; Win32 - HeapDestroy
;
HeapDestroy PROC NEAR
		mov	eax, 1			; "o.k."
		retn	4
HeapDestroy ENDP

;+---------------------------------------------------------------------------
; Win32 - HeapAlloc
;
HeapAlloc PROC NEAR
		pop	edx
		pop	eax
		push	edx
		jmp	LocalAlloc
HeapAlloc ENDP

;+---------------------------------------------------------------------------
; Win32 - HeapFree
;
HeapFree PROC NEAR
		pop	edx
		pop	eax
		pop	eax
		push	edx
		jmp	LocalFree
HeapFree ENDP

; ############################################################################
; ## Initialization for this one                                            ##
; ############################################################################

initHeap PROC NEAR
;
; Get application's HeapCommit. We take this as a measure for how much heap
; space to reserve. Not that this would be even remotely correct mind you.
;
		pushad
		mov	eax, MainModuleHandle
		mov	esi, [eax+60]
		mov	esi, [esi+eax+6Ch]
		add	esi, 0FFFFh
		sub	si, si
		push	PAGE_EXECUTE_READWRITE
		push	MEM_RESERVE + MEM_COMMIT
		push	esi
		push	0
		call	VirtualAlloc
		test	eax, eax
		jnz	@@initCont

		push	esi
		push	OFFSET strError
		call	GenericError

@@initCont:
		mov	StartOfHeap, eax
		add	eax, esi
		mov	EndOfHeap, eax
		popad
		ret

initHeap ENDP


.data

strError	db	'FATAL: Could not allocate %8 bytes local application heap!',0Dh, 0Ah, 0

.data?
	ALIGN 4

StartOfHeap		dd	?
EndOfHeap		dd	?

	END

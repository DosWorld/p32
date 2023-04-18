; ############################################################################
; ## WDOSX DOS Extender           Copyright (c) 1996, 1998, Michael Tippach ##
; ##                                                                        ##
; ## Realeased under the terms of the WDOSX license agreement.              ##
; ############################################################################
;
; $Header: E:/RCS/WDOSX/0.95/SRC/COFF/stubcf.asm 1.2 1998/10/01 20:18:42 MikeT Exp MikeT $
;
; ----------------------------------------------------------------------------
;
; $Log: stubcf.asm $
; Revision 1.2  1998/10/01 20:18:42  MikeT
; Changed the RETF at the end of the loading process into a FAR jump
; with an CS: override. This would invoke WUDEBUG, if running.
;
; Revision 1.1  1998/08/03 02:30:50  MikeT
; Initial check in
;
;
; ----------------------------------------------------------------------------
; ############################################################################
; ## Coff loader for WDOSX/DJGPP. I did this just for fun when I realized   ##
; ## how easy it is.                                                        ##
; ############################################################################

CoffSection	struc
		SectionName	db	8 dup (?)	; 0 terminated string
		SectionPaddr	dd	?
		SectionVaddr	dd	?		; where to load
		SectionSize	dd	?		; how much to load
		SectionFoffset	dd	?		; file offset relative
							; to coff header
				dd	4 dup (?)	; rubbish
CoffSection	ends

CoffHeader	struc
		CoffMagic	dw	?		; must be 014Ch
				db	18 dup (?)	; rubbish
		AoutHeader	label	near
		AoutMagic	dw	?		; must be 010Bh
				db	14 dup (?)	; rubbish
		AoutEntry	dd	?		; initial EIP
				db	8 dup (?)	; rubbish
		TextSection	CoffSection <>
		DataSection	CoffSection <>
		BssSection	CoffSection <>
		CoffHeaderEnd	label	near
CoffHeader	ends

CoffHeaderSize	equ	offset CoffHeaderEnd-offset CoffMagic

.386p
code	segment use32			; 32 bit Tiny model
assume cs:code,ds:code

; the following is needed for DJGPP compatibility
; 2 do: fill this structure from the old stub, otherwise use defaults
; must remain at offset 0 !!!

StubInfo		label	near
StubInfoMagic		db	'go32stub, v 2.00'	; a fake
org 0
			mov	ah,4ch
			int	21h
org 16
StubInfoSize		dd	offset StubInfoEnd-offset StubInfo
StubInfoMinstack	dd	40000h
StubInfoMemoryHandle	dd	0
StubInfoInitialSize	dd	0
StubInfoMinkeep		dw	4000h
StubInfoDsSelector	dw	0
StubInfoDsSegment	dw	0			; not filled
StubInfoPspSelector	dw	0			; PSP selector
StubInfoCsSelector	dw	0
StubInfoEnvSize		dw	0			
StubInfoBasename	db	8 dup (0)
StubInfoArgv0		db	16 dup (0)
StubInfoDpmiServer	db	16 dup (0)
StubInfoEnd		label	near

	; DOS strings for possible error messages

StrErrDpmi		db	'DPMI host returned an error',0dh,0ah,'$'
StrErrFile		db	'Error reading executable',0dh,0ah,'$'
StrErrFormat		db	'Not a valid .coff executable',0dh,0ah,'$'
StrErrMem		db	'Not enough memory to load executable',0dh,0ah,'$'

	; error routines

ErrorDpmi:
	lea	edx,StrErrDpmi
	jmp	short ErrorMsg

ErrorFile:
	lea	edx,StrErrFile
	jmp	short ErrorMsg

ErrorFormat:
	lea	edx,StrErrFormat
	jmp	short ErrorMsg

ErrorMem:
	lea	edx,StrErrMem

ErrorMsg:
	mov	ah,9
	int	21h
	mov	eax,4cffh
	int	21h		

	; program entry point

start:
	mov	eax,0901h
	int	31h
	mov	StubInfoPspSelector,es
	mov	StubInfoCsSelector,cs
	cld

	; allocate transfer buffer used by the main program

	mov	ebx,400h
	mov	eax,100h
	int	31h
	jc	ErrorDpmi
	mov	StubInfoDsSelector,dx
	mov	StubInfoDsSegment,ax

	; scan environment for filename

	mov	es,es:[2ch]
	sub	edi,edi
	sub	eax,eax
	mov	ecx,-1

EnvScan:
	repne	scasb
	scasb
	jnz	short EnvScan

	sub	edi,2				; number of bytes in env.
	mov	StubInfoEnvSize,di		; store

	; 2do: store argv [0]

	; Try to open the .exe

	sub	ebp, ebp			; preload file offset
	mov	edx, OFFSET wfseName
	mov	eax, 3D00FFFDh
	int	21h
	lea	edx,[edi+4]			; start of filename
	mov	ebx, eax
	jnc	openWfse

	push	ds
	push	es
	pop	ds
	mov	ax,3D00h
	int	21h
	pop	ds
	jc	ErrorFile

	; first header is wdosx header

	mov	ebx,eax
	mov	ah,3Fh
	mov	ecx,32
	lea	edx,Headers
	int	21h
	jc	ErrorFile

	; if it wasn't there, we didn't even come here
	; get the size of wdosx.dx

	movzx	ecx,word ptr Headers[2]
	movzx	edx,word ptr Headers[4]
	neg	ecx
	shl	edx,9
	and	ecx,511
	sub	edx,ecx
	shld	ecx,edx,16
	mov	ebp,edx			; preserve this
	mov	eax,4200h
	int	21h
	jc	ErrorFile

	; read loader header

	mov	ah,3fh
	mov	ecx,32
	lea	edx,Headers
	int	21h
	jc	ErrorFile

	; this one should also cause no error...
	; get loader size and seek right behind the loader

	movzx	ecx,word ptr Headers[2]
	movzx	edx,word ptr Headers[4]
	neg	ecx
	shl	edx,9
	and	ecx,511
	sub	edx,ecx
	add	edx,ebp			; add wdosx.dx size
	shld	ecx,edx,16
	mov	ebp,edx			; preserve this
	mov	eax,4200h
	int	21h
	jc	ErrorFile

	; now (hopefully) pointing to coff header, so load this

openWfse:
	lea	edx,Headers
	mov	ecx,CoffHeaderSize
	mov	ah,3Fh
	call	WfseHandler
	jc	ErrorFile
	cmp	eax,ecx
	jnz	ErrorFormat

	; coff header sucked in, verify that it is a coff and executable

	cmp	Headers.CoffMagic,014ch
	jnz	ErrorFormat
	cmp	Headers.AoutMagic,010bh
	jnz	ErrorFormat

	; get overall memory to allocate

	push	ebx					; save file handle

	mov	ecx,Headers.BssSection.SectionVaddr
	add	ecx,Headers.BssSection.SectionSize
	add	ecx,0ffffh
	sub	cx,cx
	shld	ebx,ecx,16
	mov	StubInfoInitialSize,ecx
	mov	eax,0501h
	int	31h
	jc	ErrorMem

	; start address in bx:cx, handle in si:di

	mov	word ptr [offset StubInfoMemoryHandle],di
	mov	word ptr [offset StubInfoMemoryHandle+2],si

	push	ebx
	push	ecx

	; time to get some selectors

	sub	eax,eax
	mov	ecx,2
	int	31h
	jc	ErrorDpmi
	mov	ebx,eax

	; set base + limit

	mov	eax,8
	stc
	sbb	ecx,ecx
	sbb	edx,edx
	int	31h
	jc	ErrorDpmi		
	
	pop	edx
	pop	ecx

	mov	eax,7
	int	31h

	mov	eax,3
	int	31h
	add	ebx,eax

	mov	eax,7
	int	31h
	jc	ErrorDpmi

	stc
	sbb	ecx,ecx
	sbb	edx,edx
	mov	eax,8
	int	31h
	jc	ErrorDpmi

	; set access rights

	lar	cx,bx
	mov	cl,ch
	and	cl,060h
	or	cl,092h			; data
	mov	ch,0c0h
	mov	eax,9
	int	31h
	jc	ErrorDpmi

	mov	es,ebx

	mov	eax,3
	int	31h
	sub	ebx,eax

	mov	eax,9
	or	cl,9ah			; code
	int	31h
	jc	ErrorDpmi

	;zero out the memory
	sub	eax,eax
	sub	edi,edi	
	mov	ecx,StubInfoInitialSize
	shr	ecx,2
	rep	stosd

	; load text section

	xchg	ebx,[esp]		; code selector on stack, handle back
	push	Headers.AoutEntry	; retf will launch the app

	mov	edx,Headers.TextSection.SectionFoffset
	add	edx,ebp
	mov	ecx,edx
	shr	ecx,16
	mov	eax,4200h
	call	WfseHandler
	jc	ErrorFile


	mov	ecx,Headers.TextSection.SectionSize
	mov	edx,Headers.TextSection.SectionVaddr
	mov	ah,3Fh
	push	ds
	push	es
	pop	ds
	call	WfseHandler
	pop	ds
	jc	ErrorFile

	; load data section

	mov	edx,Headers.DataSection.SectionFoffset
	add	edx,ebp
	mov	ecx,edx
	shr	ecx,16
	mov	eax,4200h
	call	WfseHandler
	jc	ErrorFile

	mov	ecx,Headers.DataSection.SectionSize
	mov	edx,Headers.DataSection.SectionVaddr
	mov	ah,3Fh
	push	ds
	push	es
	pop	ds
	call	WfseHandler
	pop	ds
	jc	ErrorFile

	mov	ah, 3Eh
	call	WfseHandler
	push	es
	mov	es,StubInfoPspSelector
	push	ds
	pop	fs
	pop	ds
	jmp	PWORD PTR cs:[esp]
;	retf

;-----------------------------------------------------------------------------
; wfseHandler: Wrapper around DOS file accesses. If WFSE present, try WFES
;              first, then DOS.
;
wfseHandler	PROC NEAR
	cmp	bh, 80h
	jc	@@noWfse

	push	eax
	shl	eax, 16
	mov	ax, 0FFFDh
	int	21h
	jnc	@@wfseOk

	pop	eax
	jmp	wfseErr

@@noWfse:
	int	21h
	ret
		
@@wfseOk:
	add	esp, 4

wfseErr:
	ret
wfseHandler	ENDP

wfseName	db	'WdosxMain', 0

Headers	CoffHeader <>
code	ends
end	start

; ############################################################################
; ## WDOSX DOS Extender           Copyright (c) 1996, 1998, Michael Tippach ##
; ##                                                                        ##
; ## Realeased under the terms of the WDOSX license agreement.              ##
; ############################################################################
;
; $Header: G:/ASMPRJ/RCS/RCS/WDOSX/0.95/SRC/DEB/REGWIN.INC 1.1 1998/08/03 03:14:06 MikeT Exp MikeT $
;
; ----------------------------------------------------------------------------
;
; $Log: REGWIN.INC $
; Revision 1.1  1998/08/03 03:14:06  MikeT
; Initial check in
;
;
; ----------------------------------------------------------------------------
RegCursorUp	proc	near
		cmp	RegCurrentY,0
		jna	@@rcaDone
		dec	RegCurrentY
		call	ShowRegisters
@@RcaDone:
		ret
RegCursorUp	endp

RegCursorDown	proc	near
		cmp	RegCurrentY,13
		jnc	@@rcdDone
		inc	RegCurrentY
		call	ShowRegisters
@@RcdDone:
		ret
RegCursorDown	endp

RegCursorHome	proc	near
		mov	RegCurrentY,0
		call	ShowRegisters
		ret
RegCursorHome	endp

RegCursorEnd	proc	near
		mov	RegCurrentY,13
		call	ShowRegisters
		ret
RegCursorEnd	endp

RegCursorLeft	proc	near
;		mov	RegCurrentX,0
;		call	ShowRegisters
		ret
RegCursorLeft	endp

RegCursorRight	proc	near
;		cmp	RegCurrentY,5
;		ja	@@rcrDone
;		mov	RegCurrentX,1
		call	ShowRegisters
@@rcrDone:
		ret
RegCursorRight	endp

RegOnReturn	proc	near
		mov	edx,RegCurrentY
		mov	edx,[edx*4+offset DlRegisters]
		push	edx
		call	OnEnterProc[edx]
		add	esp,4
		call	ShowRegisters
		ret
RegOnReturn	endp

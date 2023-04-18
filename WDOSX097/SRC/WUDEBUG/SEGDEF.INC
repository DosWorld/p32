; ############################################################################
; ## WDOSX DOS Extender           Copyright (c) 1996, 1998, Michael Tippach ##
; ##                                                                        ##
; ## Realeased under the terms of the WDOSX license agreement.              ##
; ############################################################################
;
; $Header: G:/ASMPRJ/RCS/RCS/WDOSX/0.95/SRC/DEB/SEGDEF.INC 1.1 1998/08/03 03:14:06 MikeT Exp MikeT $
;
; ----------------------------------------------------------------------------
;
; $Log: SEGDEF.INC $
; Revision 1.1  1998/08/03 03:14:06  MikeT
; Initial check in
;
;
; ----------------------------------------------------------------------------
	.386P
 	.387
DGROUP	group	_DATA,_BSS
	ASSUME	cs:_TEXT,ds:DGROUP,ss:DGROUP

_TEXT SEGMENT PARA PUBLIC USE32  'CODE'
_TEXT ENDS

_DATA SEGMENT PARA PUBLIC USE32  'DATA'
_DATA ENDS

_BSS SEGMENT PARA PUBLIC USE32  'BSS'
_BSS ENDS


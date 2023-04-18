; ############################################################################
; ## WDOSX DOS Extender           Copyright (c) 1996, 1998, Michael Tippach ##
; ##                                                                        ##
; ## Realeased under the terms of the WDOSX license agreement.              ##
; ############################################################################
;
; $Header: E:/RCS/WDOSX/0.95/SRC/WIN32/ADVAPI32.ASM 1.1 1998/08/03 01:37:46 MikeT Exp MikeT $
;
; ----------------------------------------------------------------------------
;
; $Log: ADVAPI32.ASM $
; Revision 1.1  1998/08/03 01:37:46  MikeT
; Initial check in
;
;
; ----------------------------------------------------------------------------
; ############################################################################
; ## Stubbed out registry functions                                         ##
; ############################################################################

.386
.model flat
.code

		PUBLICDLL		RegOpenKeyA
		PUBLICDLL		RegOpenKeyExA
		PUBLICDLL		RegCloseKey
		PUBLICDLL		RegQueryValueExA

dllMain	PROC NEAR

		mov	eax, 1
		retn	12

dllMain	ENDP


RegOpenKeyA LABEL NEAR

		sub	eax, eax
		retn	12

RegOpenKeyExA LABEL NEAR

		sub	eax, eax
		retn	20

RegCloseKey LABEL NEAR

		sub	eax, eax
		retn	4

RegQueryValueExA LABEL NEAR

		or	eax, -1
		retn	24

	END dllMain

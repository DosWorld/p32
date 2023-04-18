; ############################################################################
; ## WDOSX DOS Extender           Copyright (c) 1996, 1998, Michael Tippach ##
; ##                                                                        ##
; ## Realeased under the terms of the WDOSX license agreement.              ##
; ############################################################################
;
; $Header: G:/ASMPRJ/RCS/RCS/WDOSX/0.95/SRC/DEB/DEBUG.INC 1.1 1998/08/03 03:14:03 MikeT Exp MikeT $
;
; ----------------------------------------------------------------------------
;
; $Log: DEBUG.INC $
; Revision 1.1  1998/08/03 03:14:03  MikeT
; Initial check in
;
;
; ----------------------------------------------------------------------------
.386p
.387
.model flat,C

.code
extrn LoadProgram:Near
extrn disasm:near
extrn Initialize:near
extrn SingleStep:near
extrn Run:near
extrn Here:near
extrn GetLinear:near
extrn GetBreakpoint:near
extrn SetBreakpoint:near
extrn KillBreakpoint:near
extrn KillAllBp:near
extrn ReadByte:near
extrn WriteByte:near
extrn SetUserScreen:near
extrn SetDebScreen:near
extrn GetExceptionName:near
extrn IsDebugVideo:near

extrn Deax:dword
extrn Debx:dword
extrn Decx:dword
extrn Dedx:dword
extrn Desi:dword
extrn Dedi:dword
extrn Debp:dword
extrn Desp:dword

extrn Dcs:dword
extrn Dss:dword
extrn Dds:dword
extrn Des:dword
extrn Dfs:dword
extrn Dgs:dword

extrn Deip:dword
extrn Deflags:dword

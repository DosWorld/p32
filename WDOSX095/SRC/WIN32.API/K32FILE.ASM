; ############################################################################
; ## WDOSX DOS Extender           Copyright (c) 1996, 1998, Michael Tippach ##
; ##                                                                        ##
; ## Realeased under the terms of the WDOSX license agreement.              ##
; ############################################################################
;
; $Header: E:/RCS/WDOSX/0.95/SRC/WIN32/k32file.asm 1.5 1998/09/24 19:58:52 MikeT Exp MikeT $
;
; ----------------------------------------------------------------------------
;
; $Log: k32file.asm $
; Revision 1.5  1998/09/24 19:58:52  MikeT
; CLoseHandle will now accept the handle of a child program.
;
; Revision 1.4  1998/09/16 23:43:59  MikeT
; Added PROC W2A and pseudo-unicode versions of some functions.
;
; Revision 1.3  1998/09/15 23:56:25  MikeT
; Implemented GetDiskFreeSpaceA to satisfy one more D4 requirement.
;
; Revision 1.2  1998/08/09 16:17:24  MikeT
; Fix Findfirst/next
;
; Revision 1.1  1998/08/03 01:39:45  MikeT
; Initial check in
;
;
; ----------------------------------------------------------------------------
; ############################################################################
; ## File handling routines of Win32 API emulation                          ##
; ############################################################################

.386p
.model flat

include w32struc.inc

.code

		PUBLICDLL		SetHandleCount
		PUBLICDLL		GetFullPathNameA
		PUBLICDLL		GetCurrentDirectoryA
		PUBLICDLL		CreateDirectoryA
		PUBLICDLL		CreateDirectoryW
		PUBLICDLL		RemoveDirectoryA
		PUBLICDLL		RemoveDirectoryW
		PUBLICDLL		SetCurrentDirectoryA
		PUBLICDLL		SetCurrentDirectoryW
		PUBLICDLL		GetVolumeInformationA
		PUBLICDLL		GetDiskFreeSpaceA
		PUBLICDLL		GetDriveTypeA
		PUBLICDLL		GetLogicalDrives
		PUBLICDLL		FindFirstFileA
		PUBLICDLL		FindNextFileA
		PUBLICDLL		FindClose
		PUBLICDLL		FlushFileBuffers
		PUBLICDLL		GetFileInformationByHandle
		PUBLICDLL		MoveFileA
		PUBLICDLL		DeleteFileA
		PUBLICDLL		DeleteFileW
		PUBLICDLL		WriteFile
		PUBLICDLL		SetFilePointer
		PUBLICDLL		SetEndOfFile
		PUBLICDLL		ReadFile
		PUBLICDLL		GetStdHandle
		PUBLICDLL		SetStdHandle
		PUBLICDLL		GetFileSize
		PUBLICDLL		GetFileType
		PUBLICDLL		CreateFileA
		PUBLICDLL		CreateFileW
		PUBLICDLL		CloseHandle
		PUBLICDLL		GetFileAttributesA
		PUBLICDLL		GetFileAttributesW
		PUBLICDLL		SetFileAttributesA
		PUBLICDLL		SetFileAttributesW
		PUBLICDLL		GetFileTime
		PUBLICDLL		SetFileTime

		EXTRN		DosDateTimeToFileTime: NEAR
		EXTRN		FileTimeToDosDateTime: NEAR

;
; Hook procedures to allow direct console i/o, called with:
;
;       EBX = file handle
;       EDX = -> data to read/write
;       ECX = number of bytes to read/write
;
; Return:
;       CF clear: EAX bytes actually read/written
;       CF set:   nothing done, default procedure should handle
;                 read/write operation
;
; When the request is processed by the console module, these routines may
; destroy EAX, EBX, ECX and EDX, otherwise only EAX may be destroyed.
;
		EXTRN		consoleReadFileHook: NEAR
		EXTRN		consoleWriteFileHook: NEAR

.data
		EXTRN		LastError: DWORD

align 4

ffhandles	dd	0

.data?

NewDTA		db	80h * 32 dup (?)

.code

;+----------------------------------------------------------------------------
; Win32 - GetDiskFreeSpaceA
;
GetDiskFreeSpaceA PROC NEAR
		sub	eax, eax	; assume error
		pushad
		mov	edx, [esp + 4 + 32]
		test	edx, edx
		je	@@gfdsCallDOS

		mov	dl, [edx]
		and	dl, NOT 20h
		sub	dl, 'A' - 1

@@gfdsCallDOS:
		mov	ah, 36h
		int	21h
		cmp	ax, 0FFFFh
		je	@@gfdsExit

		movzx	eax, ax
		movzx	ebx, bx
		movzx	ecx, cx
		movzx	edx, dx

		mov	esi, [esp + 8  + 32]
		mov	edi, [esp + 12 + 32]
		mov	ebp, [esp + 16 + 32]
		mov	[esi], eax
		mov	esi, [esp + 20 + 32]
		mov	[edi], ebx
		mov	[ebp], ecx
		mov	[esi], edx

		inc	BYTE PTR [esp + 28]

@@gfdsExit:
		popad
		retn	20
GetDiskFreeSpaceA ENDP

;+----------------------------------------------------------------------------
; Win32 - FlushFileBuffers
;	Flushes buffers for ALL files as there is no direct equivalent in DOS
;
FlushFileBuffers PROC NEAR
		mov	ah, 0Dh
		int	21h
		mov	eax, 1
		retn	4
FlushFileBuffers ENDP

;+----------------------------------------------------------------------------
; Win32- SetHandleCount
;
SetHandleCount	PROC NEAR

		push	ebx
		movzx	ebx, word ptr [esp+8]
		mov	eax, 20
		cmp	ebx, eax
		jna	short @@shcDone

		push	ebx
		mov	ah, 67h
		int	21h
		mov	eax, 20
		pop	ebx
		jc	short @@shcDone

		mov	eax, ebx

@@shcDone:
		pop	ebx
		retn	4

SetHandleCount	ENDP

;+----------------------------------------------------------------------------
; Win32 - GetFullPathNameA
;
GetFullPathNameA PROC NEAR

		cmp	dword ptr [esp+8], 80
		jnc	short @@gfpn00

		mov	eax, 80
		retn	16

@@gfpn00:
		push	dword ptr [esp+12]
		push	dword ptr [esp+12]
		call	GetCurrentDirectoryA
		test	eax, eax
		jnz	short @@gfpn01

		retn	16

@@gfpn01:
		mov	edx, [esp+12]
		add	edx, eax
		cmp	byte ptr [edx-1], '\'
		jz	short @@gfpn03

		mov	byte ptr [edx], '\'
		inc	edx

@@gfpn03:
		mov	ecx, [esp+16]
		mov	[ecx], edx
		mov	ecx, [esp+4]

@@gfpn02:
		mov	al, [ecx]
		inc	ecx
		mov	[edx], al
		inc	edx
		test	al, al
		jnz	short @@gfpn02

		lea	eax, [edx-1]
		sub	eax, [esp+12]
		retn	16

GetFullPathNameA ENDP

;+----------------------------------------------------------------------------
; Win32 - GetCurrentDirectoryA
;
GetCurrentDirectoryA LABEL NEAR

		push	esi
		mov	esi, [esp+12]
		mov	ah, 19h
		int	21h
		add	al, 'A'
		mov	[esi], al
		inc	esi
		mov	word ptr [esi], '\:'
		inc	esi
		inc	esi
		sub	edx, edx
		mov	ah, 47h
		int	21h
		pop	esi
		jc	short mkdirError

		mov	eax, [esp+8]
@@gcd01:
		cmp	byte ptr [eax], 0
		jz	short @@gcd00

		inc	eax
		jmp	short @@gcd01

@@gcd00:
		sub	eax, [esp+8]
		retn	8

;+----------------------------------------------------------------------------
; Win32 - CreateDirectoryA
;
CreateDirectoryW LABEL NEAR
		call	W2A
CreateDirectoryA LABEL NEAR

		mov	ah, 39h
		mov	edx, [esp+4]
		int	21h

fromCwd:
		jc	short mkdirError

		mov	eax, 1
		retn	8

mkdirError:
		movzx	eax, al
		mov	LastError, eax
		sub	eax, eax
		retn	8

;+----------------------------------------------------------------------------
; Win32 - RemoveDirectoryA
;
RemoveDirectoryW LABEL NEAR
		call	W2A
RemoveDirectoryA LABEL NEAR

		mov	ah, 3Ah
		jmp	short fromRmdir

;+----------------------------------------------------------------------------
; Win32 - SetCurrentDirectoryA
;
SetCurrentDirectoryW LABEL NEAR
		call	W2A
SetCurrentDirectoryA LABEL NEAR

		mov	eax, [esp+4]
		cmp	byte ptr [eax+1], ':'
		jnz	short fromSetdrive
		mov	dl, [eax]
		or	dl, 20h
		sub	dl, 'a'
		mov	ah, 0Eh
		int	21h
		add	dword ptr [esp+4], 2

fromSetdrive:
		mov	ah,3Bh

fromRmdir:
		mov	LastError, 0
		mov	edx, [esp+4]
		int	21h
		jc	short chdirError
		mov	eax, 1
		retn	4

chdirError:
		movzx	eax, al
		mov	LastError, eax
		sub	eax, eax
		retn	4

;+----------------------------------------------------------------------------
; Win32 - GetVolumeInformationA
;
; Note that this one returns FAT, even for a Network drive!
; No Volume name etc. returned either.
;
GetVolumeInformationA PROC NEAR
		
		mov	edx, [esp+8]
		test	edx, edx
		jz	short @@gvi01

		mov	byte ptr [edx], 0

@@gvi01:
		mov	edx, [esp+16]
		test	edx, edx
		jz	short @@gvi02

		mov	dword ptr [edx], 0

@@gvi02:
		mov	edx, [esp+20]
		test	edx, edx
		jz	short @@gvi03

		mov	dword ptr [edx], 12

@@gvi03:
		mov	edx, [esp+24]
		test	edx, edx
		jz	short @@gvi04

		and	dword ptr [edx], 0

@@gvi04:
		mov	edx, [esp+28]
		test	edx, edx
		jz	short @@gvi05

		mov	dword ptr [edx], 'TAF'

@@gvi05:
		mov	eax, 1
		retn	32

GetVolumeInformationA ENDP

;+----------------------------------------------------------------------------
; Win32 - GetDriveType
;
; For now, it returns zero on all inquiries.
;
GetDriveTypeA PROC NEAR

		sub	eax, eax
		retn	4

GetDriveTypeA ENDP

;+----------------------------------------------------------------------------
; Win32 - GetLogicalDrives
;
GetLogicalDrives PROC NEAR

		push	ebx
		mov	ebx, 32
		sub	ecx, ecx

@@gld01:
		mov	eax, 4409h
		int	21h
		cmc
		adc	ecx, ecx
		dec	ebx
		jnz	short @@gld01
		
		mov	eax, ecx
		pop	ebx
		retn

GetLogicalDrives ENDP

;+----------------------------------------------------------------------------
; Win32 - FindFirstFileA
;
FindFirstFileA PROC NEAR

		mov	edx, offset NewDTA + (80h * 31)
		mov	ecx, 31
		mov	eax, ffHandles

@@fff01:
		add	eax, eax
		jnc	short @@fff00

		sub	edx, 80h
		loop	short @@fff01

		mov	LastError, 113
		or	eax, -1
		retn	8

@@fff00:
		mov	ah, 1Ah
		int	21h
		push	ecx
		push	edx
		mov	ecx, -1
		mov	edx, [esp+12]
		mov	eax, 4E00h
		int	21h
		pop	edx
		pop	ecx
		jc	short @@fff02

		bts	ffHandles, ecx
		push	ecx
		mov	ecx, [esp+12]
		sub	eax, eax
		mov	al, [edx+15h]
		mov	[ecx], eax
		lea	eax, [ecx+4]
		push	ecx
		push	edx
		push	eax
		movzx	eax, word ptr [edx+16h]
		push	eax
		movzx	eax, word ptr [edx+18h]
		push	eax
		call	DosDateTimeToFileTime
		pop	edx
		pop	ecx
		mov	eax, [ecx+4]
		mov	[ecx+12], eax
		mov	[ecx+20], eax
		mov	eax, [ecx+8]
		mov	[ecx+16], eax
		mov	[ecx+24], eax
		and	dword ptr [ecx+28], 0
		mov	eax, [edx+1Ah]
		mov	[ecx+32], eax
		sub	eax, eax
		push	ebx
		mov	ebx, 13

@@fff03:	
		mov	al, [edx+1Eh]
		inc	edx
		mov	[ecx + 44], al
		mov	[ecx + 304], al
		inc	ecx
		dec	ebx
		jnz	short @@fff03

		pop	ebx
		pop	eax
		retn	8

@@fff02:
		mov	LastError, eax
		or	eax, -1
		retn	8

FindFirstFileA ENDP

;+----------------------------------------------------------------------------
; Win32 - FindNextFileA
;
FindNextFileA PROC NEAR

		mov	edx, [esp+4]
		mov	eax, 6
		cmp	edx, 32
		jnc	short @@fnf00

		shl	edx, 7
		add	edx, offset NewDTA
		mov	ah, 1Ah
		int	21h
		mov	ah, 4Fh
		int	21h
		jc	short @@fnf00

		mov	ecx, [esp+8]
		sub	eax, eax
		mov	al, [edx+15h]
		mov	[ecx], eax
		lea	eax, [ecx+4]
		push	ecx
		push	edx
		push	eax
		movzx	eax, word ptr [edx+16h]
		push	eax
		movzx	eax, word ptr [edx+18h]
		push	eax
		call	DosDateTimeToFileTime
		pop	edx
		pop	ecx
		mov	eax, [ecx+4]
		mov	[ecx+12], eax
		mov	[ecx+20], eax
		mov	eax, [ecx+8]
		mov	[ecx+16], eax
		mov	[ecx+24], eax
		and	dword ptr [ecx+28], 0
		mov	eax, [edx+1Ah]
		mov	[ecx+32], eax
		sub	eax, eax
		push	ebx
		mov	ebx, 13

@@fnf01:	
		mov	al, [edx+1Eh]
		inc	edx
		mov	[ecx + 44], al
		mov	[ecx + 304], al
		inc	ecx
		dec	ebx
		jnz	short @@fnf01

		pop	ebx
		mov	al, 1
		retn	8

@@fnf00:
		mov	LastError, eax
		sub	eax, eax
		retn	8

FindNextFileA ENDP

;+----------------------------------------------------------------------------
; Win32 - FindClose:

FindClose PROC NEAR

		mov	eax, [esp+4]
		cmp	eax, 32
		jc	short @@fcl00

@@fcl01:
		mov	LastError, 6
		sub	eax, eax
		retn	4

@@fcl00:
		btr	ffHandles, eax
		jnc	short @@fcl01

		mov	eax, 1
		retn	4

FindClose ENDP

;+----------------------------------------------------------------------------
; Win32 - GetFileInformationByHandle
;
; Currently unsupported, invoke the debugger, if any, otherwise crash.
;
GetFileInformationByHandle LABEL NEAR
		
		int	3

;+----------------------------------------------------------------------------
; Win32 - MoveFileA
;
; Differences to Win32 API: moving files across drives not permitted.
;
MoveFileA PROC NEAR

		push	edi
		mov	edx, [esp+8]
		mov	edi, [esp+12]
		sub	ecx, ecx
		mov	ah, 56h
		int	21h
		jnc	short @@mva01

		movzx	eax, al
		mov	LastError, eax
		sub	eax, eax
		jmp	short @@mva02

@@mva01:
		mov	eax, 1

@@mva02:
		pop	edi
		retn	8

MoveFileA ENDP

;+----------------------------------------------------------------------------
; Win32 - DeleteFileA
;
DeleteFileW LABEL NEAR
		call	W2A
DeleteFileA PROC NEAR

		mov	edx, [esp+4]
		mov	ah, 41h
		int	21h
		jnc	short @@df01

		movzx	eax, al
		mov	LastError, eax

@@df01:
		sbb	eax, eax
		inc	eax
		retn	4

DeleteFileA ENDP

;+----------------------------------------------------------------------------
; Win32 - WriteFile
;
; Too many differences to list.
;
WriteFile PROC NEAR

		push	ebx
		mov	ebx, [esp+8]
		mov	edx, [esp+12]
		mov	ecx, [esp+16]
		call	consoleWriteFileHook
		jnc	short @@wf02

		test	ecx, ecx
		mov	eax, ecx
		jz	short @@wf01

		mov	ah, 40h
		int	21h
		jnc	short @@wf02

@@wf01:
		movzx	eax, al
		mov	LastError, eax

@@wf02:
		mov	ecx, [esp+20]
		mov	[ecx], eax
		pop	ebx
		sbb	eax, eax
		inc	eax
		retn	20

WriteFile ENDP

;+----------------------------------------------------------------------------
; Win32 - SetFilePointer
;
SetFilePointer PROC NEAR

		push	ebx
		mov	ebx, [esp+8]
		mov	edx, [esp+12]
		mov	ecx, [esp+16]
		test	ecx, ecx
		jz	@@sf00

		and	DWORD PTR [ecx], 0

@@sf00:
		mov	eax, [esp+20]
		shld	ecx, edx, 16
		mov	ah, 42h
		int	21h
		mov	LastError, 0
		movzx	eax, ax
		jnc	short @@sf01

		mov	LastError, eax
		sbb	eax, eax
		jmp	@@sf02

@@sf01:
		shl	edx, 16
		or	eax, edx		

@@sf02:
		pop	ebx
		retn	16

SetFilePointer ENDP

;+----------------------------------------------------------------------------
; Win32 - SetEndOfFile
;
SetEndOfFile PROC NEAR

		push	ebx
		mov	ebx, [esp+8]
		sub	ecx, ecx
		mov	ah, 40h
		int	21h
		jnc	short @@seof01

		movzx	eax, al
		mov	LastError, eax

@@seof01:
		sbb	eax, eax
		inc	eax
		pop	ebx
		retn	4

SetEndOfFile ENDP

;+----------------------------------------------------------------------------
; Win32 - ReadFile
;
ReadFile PROC NEAR

		push	ebx
		mov	ebx, [esp+8]
		mov	edx, [esp+12]
		mov	ecx, [esp+16]
		call	consoleReadFileHook
		jnc	short @@rf01
		
		mov	ah, 3Fh
		int	21h
		jnc	short @@rf01

		movzx	eax, al
		mov	LastError, eax

@@rf01:
		mov	edx, [esp+20]
		mov	[edx], eax
		sbb	eax, eax
		inc	eax
		pop	ebx
		retn	20

ReadFile ENDP

;+----------------------------------------------------------------------------
; Win32 - GetStdHandle
;
; As we currently do not support SetStdHandle, we can handle things relaxed.
;
GetStdHandle PROC NEAR

	 	mov	eax, [esp+4]
		neg	eax
		sub	eax, 10
		jc	short @@gsh01

		cmp	eax, 3
		jnc	short @@gsh01
	
		retn	4

@@gsh01:
		or	eax, -1
		retn	4

GetStdHandle ENDP

;+----------------------------------------------------------------------------
; Win32 - SetStdHandle
;
SetStdHandle LABEL NEAR
		int	3

;+----------------------------------------------------------------------------
; Win32 - GetFileSize
;
GetFileSize PROC NEAR

		push	ebp
		push	ebx
		mov	ebp, esp
		push	ebx
		mov	ebx, [ebp+12]
		sub	edx, edx
		sub	ecx, ecx
		mov	eax, 4201h
		int	21h
		jc	short @@gfs01

		push	edx
		push	eax
		sub	edx, edx
		sub	ecx, ecx
		mov	eax, 4202h
		int	21h
		jc	short @@gfs01

		shl	edx, 16
		or	eax, edx
		pop	edx
		pop	ecx
		push	eax
		mov	eax, 4200h
		int	21h
		jc	short @@gfs01

		pop	eax
		jmp	short @@gfs02

@@gfs01:
		movzx	eax, al
		mov	LastError, eax
		sbb	eax, eax

@@gfs02:
		mov	esp, ebp
		pop	ebx
		pop	ebp
		retn	8

GetFileSize ENDP

;+----------------------------------------------------------------------------
; Win32 - GetFileType
;
GetFileType PROC NEAR

		push	ebx
		mov	ebx, [esp+8]
		mov	eax, 4400h
		int	21h
		pop	ebx
		jc	@@gft01

		and	edx, 080h
		shr	edx, 7
		mov	eax, 1
		add	eax, edx
		retn	4

@@gft01:
		movzx	eax, al
		mov	LastError, eax
		sub	eax, eax
		retn	4

GetFileType ENDP

;+----------------------------------------------------------------------------
; Win32 - CreateFileA
;
; Main difference is that we cannot create anything but a file.
;
CreateFileW LABEL NEAR
		call	W2A
CreateFileA PROC NEAR

		GEN_READ	EQU	80h
		GEN_WRITE	EQU	40h
;
; Check whether stdio handle requested
;
		mov	edx, [esp + 4]
		call	CheckConHandle
		jnc	@@cfa07

		mov	eax, 3D00h
		sub	ecx, ecx
		cmp	byte ptr [esp+20], CREATE_ALWAYS
		jnz	short @@cfa02

@@cfa01:
		mov	eax, 3C00h
		int	21h
		jc	short @@cfa06

		retn	28

@@cfa02:
		int	21h
		jc	short @@cfa05

		push	ebx
		mov	ebx, eax
		mov	ah, 3Eh
		int	21h
		pop	ebx
		mov	eax, 80				; ERROR_FILE_EXISTS
		cmp	byte ptr [esp+20], CREATE_NEW
		jz	short @@cfa06

		cmp	byte ptr [esp+20], TRUNCATE_EXISTING
		jz	short @@cfa01

		mov	eax, 3D00h
		test	byte ptr [esp+11], GEN_WRITE
		jz	short @@cfa03

		mov	al, 1

@@cfa03:
		test	byte ptr [esp+11], GEN_READ
		jz	short @@cfa04

		test	al, al
		jz	short @@cfa04

		mov	al, 2

@@cfa04:
		mov	edx, [esp+4]
		int	21h
		jc	short @@cfa06

		retn	28

@@cfa05:
		cmp	byte ptr [esp+20], OPEN_EXISTING
		jz	short @@cfa06

		cmp	byte ptr [esp+20], TRUNCATE_EXISTING
		jnz	short @@cfa01

@@cfa06:
		movzx	eax, al
		mov	LastError, eax
		or	eax, -1
@@cfa07:
		retn	28

CreateFileA ENDP

;+----------------------------------------------------------------------------
; Win32 - CloseHandle
;
CloseHandle PROC NEAR
		cmp	DWORD PTR [esp+4], 12345678h
		je	@@ch02

		push	ebx
		mov	ebx, [esp+8]
		mov	ah, 3Eh
		int	21h
		jnc	short @@ch01

		movzx	eax, al
		mov	LastError, eax

@@ch01:
		pop	ebx

@@ch02:
		sbb	eax, eax
		inc	eax
		retn	4

CloseHandle ENDP

;+----------------------------------------------------------------------------
; Win32 - GetFileAttributesA
;
GetFileAttributesW LABEL NEAR
		call	W2A
GetFileAttributesA PROC NEAR

		mov	edx, [esp+4]
		mov	eax, 4300h
		int	21h
		jc	short @@gfa02

		mov	eax, FILE_ATTRIBUTE_NORMAL
		and	ecx, 037h
		jz	short @@gfa01

		mov	eax, ecx

@@gfa01:
		retn	4

@@gfa02:
		movzx	eax, al
		mov	LastError, eax
		or	eax, -1
		retn	4

GetFileAttributesA ENDP

;+----------------------------------------------------------------------------
; Win32 - SetFileAttributesA
;
SetFileAttributesW LABEL NEAR
		call	W2A
SetFileAttributesA PROC NEAR

		mov	ecx, [esp+8]
		and	ecx, 37h
		mov	edx, [esp+4]
		mov	eax, 4301h
		int	21h
		jc	short @@sfa01

		mov	eax, 1
		retn	8

@@sfa01:
		movzx	eax, al
		mov	LastError, eax
		sub	eax, eax
		retn	8

SetFileAttributesA ENDP

;+----------------------------------------------------------------------------
; Win32 - GetFileTime
;
GetFileTime PROC NEAR

		push	ebx
		mov	ebx, [esp+8]
		mov	eax, 5700h
		int	21h
		jc	short @@gftim00

		movzx	ecx, cx
		movzx	edx, dx
		sub	esp, 8
		push	esp
		push	ecx
		push	edx
		call	DosDateTimeToFileTime
		pop	eax
		pop	edx
		mov	ecx, [esp+12]
		test	ecx, ecx
		jz	short @@gftim01

		mov	[ecx], eax
		mov	[ecx+4], edx

@@gftim01:
		mov	ecx, [esp+16]
		test	ecx, ecx
		jz	short @@gftim02

		mov	[ecx], eax
		mov	[ecx+4], edx

@@gftim02:
		mov	ecx, [esp+20]
		test	ecx, ecx
		jz	short @@gftim03

		mov	[ecx], eax
		mov	[ecx+4], edx

@@gftim03:
		mov	eax, 1
		jmp	short @@gftim04

@@gftim00:
		mov	LastError, eax
		sub	eax, eax

@@gftim04:
		pop	ebx
		retn	16

GetFileTime ENDP

;+----------------------------------------------------------------------------
; Win32 - SetFileTime
;
SetFileTime PROC NEAR

		push	ebx
		mov	ebx, [esp+8]
		mov	ecx, [esp+20]
		test	ecx, ecx
		jnz	short @@sft00

@@sft01:
		pop	ebx
		mov	eax, 1
		retn	16

@@sft00:
		sub	esp, 8
		push	esp
		lea	eax, [esp+8]
		push	eax
		push	ecx
		call	FileTimeToDosDateTime
		pop	ecx
		pop	edx
		mov	eax, 5701h
		int	21h
		jnc	short @@sft01

		mov	LastError, eax
		sub	eax, eax
		pop	ebx
		retn	16

SetFileTime ENDP

;----------------------------------------------------------------------------
; CheckConHandle
;
; In:   EDX -> file name
;
; Exit: CF clear if match, EAX = handle
;
CheckConHandle PROC NEAR
		sub	eax, eax
		pushad
		cld
		mov	esi, edx
		mov	edi, OFFSET inputStr
		mov	ecx, 7
		repe	cmpsb
		je	@@cchDone

		mov	DWORD PTR [esp + 28], hStdout
		mov	esi, edx
		mov	edi, OFFSET outputStr
		mov	ecx, 8
		repe	cmpsb
		je	@@cchDone

		stc

@@cchDone:
		popad
		retn
CheckConHandle ENDP

W2A PROC NEAR
		mov	edx, OFFSET UCFnBuffer
		mov	ecx, [esp + 8]
		mov	[esp + 8], edx

@@w2aLoop:
		mov	al, [ecx]
		add	ecx, 2
		mov	[edx], al
		inc	edx
		test	al, al
		jnz	@@w2aLoop

		retn
W2A ENDP

.data

inputStr	db	'CONIN$',0
outputStr	db	'CONOUT$',0

.data?

UCFnBuffer	db	260 dup (?)

	END

{                         P32 - 32bit Pascal Compiler                        }
{ -------------------------------------------------------------------------- }
{                       Johan Prins - jprins@knoware.nl                      }
{ ========================================================================== }
{                                                                            }
{                                                    (c) Copyright 1997-1998 }
{                                                                            }
{ -------------------------------------------------------------------------- }
{ System unit for P32 v0.5                                                   }
{ -------------------------------------------------------------------------- }
{ Specific SYSTEM unit for Win32 applications                                }
{ -------------------------------------------------------------------------- }

{$IFDEF P32V050}

unit system;

interface

const
   {boolean definition}
   FALSE      = boolean(0);
   TRUE       = boolean(1);

   {integer constants}

   maxint     = 32767;
   maxlongint = 2147483647;

   fmClosed   = $D7B0;
   fmInput    = $D7B1;
   fmOutput   = $D7B2;
   fmInOut    = $D7B3;

   ReadOnly   = $01;
   Hidden     = $02;
   SysFile    = $04;
   VolumeID   = $08;
   Directory  = $10;
   Archive    = $20;
   AnyFile    = $3F;

  {floating point constants}

  _e_        = 2.71828182845905;

type
   {- basic types -}

   byte       = 0..255;
   shortint   = -128..127;
   word       = 0..65535;
   integer    = -32768..32767;
   longint    = -2147483647-1..2147483647;

   real       = 2.9e-39..1.7e38;
   single     = 1.5e-45..3.4e38;
{   double     = 5.0e-324..1.7e308;}

   char       = #0..#255;

   pchar      = ^char;

   {- text files -}

   TextBuf    = array[0..127] of char;

   TextRec    = record
                  Handle   : longint;
                  Mode     : longint;
                  BufSize  : dword;
                  BufPos   : dword;
                  BufEnd   : dword;
                  BufPtr   : ^TextBuf;
                  OpenFunc : pointer;
                  InOutFunc: pointer;
                  FlushFunc: pointer;
                  CloseFunc: pointer;
                  {UserData : array [1..32] of byte;}
                  Name     : string[128];{array [0..259] of char;}
                  Buffer   : TextBuf;
                end;
   FileRec = record
               handle  : longint;
               mode    : longint;
               RecSize : longint;
               Private : array[1..26] of byte;
               UserData: array[1..16] of byte;
               Name    : string[127];{array[0..79] of Char;}
             end;
 
const
  FileMode: longint = 2;

var
   port    : array[0..0] of byte;
   portw   : array[0..0] of word;
   portl   : array[0..0] of longint;

(* MEM makes sense only inside process address space. Other uses may cause GPFs. *)
   mem  : array[0..0] of byte absolute $0;
   memw : array[0..0] of word absolute $0;
   meml : array[0..0] of longint absolute $0;

   input, output: text; {standard input and standard output}
   radix        : longint;

   FreeList: pointer;  { start of a linked list of free memory blocks }
   
   HeapHandle : dword;           { Win32 heap handle }
   HeapSize   : dword; external; { Size of the heap }

procedure Move(var source, dest; count:longint);
procedure FillChar(var x:pointer; count:longint; value:byte);

procedure Randomize;
function Random(max:longint):longint;
function Abs(l: longint): longint;
function Abs(d: double): double;
function Odd(l: longint): boolean;
function Hi(x: integer):byte;
function Lo(x: integer):byte;
function Swap(x: integer):integer;
function UpCase(c: char): char;
function Copy(var s: string;i: longint;len: longint): string;
function Concat(var s1,s2: string): string;
function Pos(const substr, source: string): longint;
procedure Insert(const source: string; var s: string; index: longint);
procedure Delete(var s: string; pos, num: longint);
procedure Val(const s: string; var rvar: double; var code: longint);

function Sqr(r: double): double;
function Pi: double;
function ArcTan(r: double): double;
function Sqrt(r: double): double;
function Sin(r: double): double;
function Cos(r: double): double;

function Round(r: double): longint;
function Trunc(r: double): longint;

function IOResult: longint;
procedure Halt;
procedure Halt(error: byte);
procedure ProgramExit;

procedure assign(var t: text;const s: string);
procedure rewrite(var t: text);
procedure reset(var t: text);
procedure append(var t: text);
procedure flush(var t: text);
procedure close(var t: text);

procedure FlushOutput;
procedure WriteString(var t: TextRec; var s: string; l: longint);
procedure WriteLine(var t: TextRec);
procedure WriteBoolean(var t: TextRec; b:boolean; l: longint);
procedure WriteChar(var t: TextRec; nr, l: longint);
procedure WriteUInt(var t: TextRec; nr, l: longint);
procedure WriteSInt(var t: TextRec; nr, l: longint);
procedure WritePointer(var t: TextRec; nr, l:longint);
procedure WriteReal(var t: TextRec; nr: double; l:longint);

procedure ReadString(var t: TextRec;var s : string; l:longint);
procedure ReadLine(var t: TextRec);
procedure ReadInt(var t: TextRec; var l : longint);

procedure sys_StrCopy(dest, source:pointer;l:longint);
procedure sys_StrCat(s1, s2:pointer);
procedure sys_StrCmp(s1, s2:pointer);

procedure assign(var f: file; const s:string);
procedure reset(var f: file; l: longint);
procedure reset(var f: file);
procedure rewrite(var f: file; l: longint);
procedure rewrite(var f: file);
procedure blockwrite(var f: file; var buf; count: longint; var result: longint);
procedure blockwrite(var f: file; var buf; count: longint);
procedure blockread(var f: file; var buf; count: longint; var result: longint);
procedure blockread(var f: file; var buf; count: longint);
procedure close(var f: file);
function filepos(var f: file): longint;
procedure seek(var f: file; pos: longint);
function filesize(var f: file): longint;

function ParamStr(index: longint): string;
function ParamCount: longint;

procedure GetMem(var p: pointer; size: dword);
procedure FreeMem(var p: pointer; size: dword);
procedure HeapInit(var Size: dword);
procedure HeapDone;


implementation

(* Win32 stuff: APIs, types and constants definitions needed for SYSTEM unit *)
{ Win32 types }

{ Defined in WINDOWS.PAS }
type BOOL   = LongInt;
     UINT   = LongInt;
     LONG   = LongInt;
     PLONG  = ^LONG;
     HANDLE = LongInt;
     LPDWORD= ^DWORD;
     LPVOID = Pointer;
     LPCSTR = Pointer;
     LPCTSTR= Pointer;
     SECURITY_ATTRIBUTES = record
       nLength: DWORD;
       lpSecurityDescriptor: LPVOID;
       bInheritHandle: BOOL;
     end;
     LPSECURITY_ATTRIBUTES = ^SECURITY_ATTRIBUTES;
          
{ Win32 constants }
const NULL = Pointer(0);

      STD_INPUT_HANDLE  = DWORD(-10);
      STD_OUTPUT_HANDLE = DWORD(-11);
      STD_ERROR_HANDLE  = DWORD(-12);

      CREATE_NEW        = 1;
      CREATE_ALWAYS     = 2;
      OPEN_EXISTING     = 3;
      OPEN_ALWAYS       = 4;
      TRUNCATE_EXISTING = 5;

      INVALID_HANDLE_VALUE = HANDLE(-1);
      INVALID_FILE_SIZE    = DWORD($FFFFFFFF);

      FILE_BEGIN   = 0;
      FILE_CURRENT = 1;
      FILE_END     = 2;

      GENERIC_READ    = $80000000;
      GENERIC_WRITE   = $40000000;
      GENERIC_EXECUTE = $20000000;
      GENERIC_ALL     = $10000000;

      FILE_SHARE_READ   = $00000001;
      FILE_SHARE_WRITE  = $00000002;
      FILE_SHARE_DELETE = $00000004;
      FILE_ATTRIBUTE_READONLY   = $00000001;
      FILE_ATTRIBUTE_HIDDEN     = $00000002;
      FILE_ATTRIBUTE_SYSTEM     = $00000004;
      FILE_ATTRIBUTE_DIRECTORY  = $00000010;
      FILE_ATTRIBUTE_ARCHIVE    = $00000020;
      FILE_ATTRIBUTE_NORMAL     = $00000080;
      FILE_ATTRIBUTE_TEMPORARY  = $00000100;
      FILE_ATTRIBUTE_COMPRESSED = $00000800;
      FILE_ATTRIBUTE_OFFLINE    = $00001000;

      MAX_PATH = 260;

{ ---------- Win32 APIs ---------- }

{ Console functions }
function GetStdHandle(nStdHandle: DWORD): HANDLE; win32api;

{ File functions }
function CreateFileA(lpFileName: LPCSTR; dwDesiredAccess, dwShareMode: DWORD; lpSecurityAttributes: LPSECURITY_ATTRIBUTES;
             dwCreationDisposition, dwFlagsAndAttributes: DWORD; hTemplateFile: HANDLE): HANDLE; win32api;
function DeleteFileA(lpFileName: LPCSTR): BOOL; win32api;
function GetFileSize(hFile: HANDLE; FileSizeHigh: LPDWORD): DWORD; win32api;
function MoveFileA(lpExistingFileName, lpNewFileName: LPCSTR): BOOL; win32api;
function ReadFile(hFile: HANDLE; lpBuffer: LPVOID; nNumberOfBytesToRead: DWORD;
             var NumberOfBytesRead: DWORD; lpOverlapped: LPVOID): BOOL; win32api;
function SetFilePointer(hFile: HANDLE; lDistanceToMove: LONG; DistanceToMoveHigh: PLONG;
                        dwMoveMethod: DWORD): DWORD; win32api;
function WriteFile(hFile: HANDLE; lpBuffer: LPVOID; nNumberOfBytesToWrite: DWORD;
              var NumberOfBytesWritten: DWORD; lpOverlapped: LPVOID): BOOL; win32api;

function CreateDirectoryA(lpPathName: LPCTSTR; lpSecurityAttributes: LPSECURITY_ATTRIBUTES): BOOL; win32api;
function GetCurrentDirectoryA(nBufferLength: DWORD; lpBuffer: LPCTSTR): DWORD; win32api;
function RemoveDirectoryA(lpszDir: LPCTSTR): BOOL; win32api;
function SetCurrentDirectoryA(lpszCurDir: LPCTSTR): BOOL; win32api;

{ Process and Thread functions }
function GetCommandLineA: LPCTSTR; win32api;
procedure ExitProcess(uExitCode: UINT); win32api;

{ Memory management functions }
function HeapAlloc(hHeap: HANDLE; dwFlags, dwBytes: DWORD): LPVOID; win32api;
function HeapCreate(flOptions, dwInitialSize, dwMaximumSize: DWORD): HANDLE; win32api;
function HeapDestroy(hHeap: HANDLE): BOOL; win32api;
function HeapFree(hHeap: HANDLE; dwFlags: DWORD; lpMem: LPVOID): BOOL; win32api;

{ Time functions }
function GetTickCount: DWORD; win32api;

{ Handles and objects functions }
function CloseHandle(hObject: HANDLE): BOOL; win32api;

{ Error functions }
function GetLastError: DWORD; win32api;
{ ------ End of Win32 APIs ------ }


(* ********************** END of Win32 stuff **************************** *)


const number_convert = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

var randseed:longint;
    InOutRes:longint;

    CmdLine : LPCTSTR;

{local procedures}

procedure ASCIIZ(var source: string; dest: pointer); assembler;
asm
   mov   esi, dword ptr [source]
   movzx ecx, byte ptr [esi]
   inc   esi
   mov   edi, dword ptr [dest]
   mov   eax, ecx
   shr   ecx, 2
   cld
   rep
   movsd
   mov   ecx, eax
   and   ecx, 3
   rep
   movsb
   mov   byte ptr [edi], 0
end;

procedure sys_StrCopy(dest, source:pointer;l:longint); assembler; 'strcopy';
asm
   push  eax
   mov   edi, dword ptr [dest]
   mov   esi, dword ptr [source]
   mov   ecx, dword ptr [l]
   cld
   lodsb
   cmp   al,cl
   jbe   @strcopy_1
   mov   al,cl
@strcopy_1:
   movzx eax, al
   mov   ecx,eax
   stosb
   shr   ecx,2
   rep
   movsd
   mov   cl,al
   and   cl,3
   rep
   movsb
   pop   eax
end;

procedure sys_StrCat(s1, s2:pointer); assembler; 'strcat';
asm
   push  eax
   mov   edi, dword ptr [s1]
   movzx ecx, byte ptr [edi]
   lea   edi, [edi+ecx+1]
   neg   ecx
   add   ecx, $FF
   mov   esi, dword ptr [s2]
   lodsb
   cmp   al, cl
   jbe   @strcat_2
   mov   al, cl
@strcat_2:
   mov   cl, al
   mov   ebx, dword ptr [s1]
   add   byte ptr [ebx], cl
   movzx ecx, cl
   mov   eax, ecx
   shr   ecx, 2
   cld
   rep
   movsd
   mov   ecx, eax
   and   ecx, 3
   rep
   movsb
   pop   eax
end;

procedure sys_StrCmp(s1, s2:pointer); assembler; 'strcmp';
asm
   push  eax
   mov   esi, dword ptr [ebp+12]
   mov   edi, dword ptr [ebp+ 8]
   cld
   lodsb
   mov   ah, [edi]
   inc   edi
   cmp   cl, al
   jbe   @strcmp_3
   mov   cl, ah
@strcmp_3:
   or    cl, cl
   jz    @strcmp_4
   movzx ecx, cl
   rep
   cmpsb
   jne   @strcmp_5
@strcmp_4:
   cmp   al, ah
@strcmp_5:
   pop   eax
end;

procedure Move(var source, dest; count:longint); assembler;
asm
   mov   edi, dword ptr [Dest]
   mov   esi, dword ptr [Source]
   mov   ecx, dword ptr [count]
   mov   ebx, ecx

   cmp   edi, esi
   jg    @1
   je    @2       {nothing to copy}

   sar   ecx, 2
   js    @2

   cld
   rep
   movsd

   mov   ecx, ebx
   and   ecx, 3
   rep
   movsb
   jmp   @2;

@1:
   lea   esi, [esi+ecx-4]
   lea   edi, [edi+ecx-4]

   sar   ecx, 2
   js    @2

   std
   rep
   movsd

   mov   ecx, ebx
   and   ecx, 3
   add   esi, 3
   add   edi, 3
   rep
   movsb

@2:
end;

procedure FillChar(var x:pointer; count:longint; value:byte); assembler;
asm
   mov   edi, dword ptr [x]
   mov   ecx, dword ptr [count]
   mov   al, byte ptr [value]
   mov   ah, al
   mov   bx, ax
   shl   eax, 16
   mov   ax, bx
   mov   ebx, ecx
   shr   ecx, 2
   rep
   stosd
   and   ebx, 3
   mov   ecx, ebx
   rep
   stosb
end;

function UpCase(c: char): char; assembler;
asm
   cmp   al, 'a'
   jb    @exit
   cmp   al, 'z'
   ja    @exit
   sub   al, 32
@exit:
end;

function Copy(var s: string;i: longint;len: longint): string; assembler;
{begin}
asm
	CLD
        MOV     EDI,dword ptr [ebp+20]
        MOV     ESI,[s]
	MOV	AL,[ESI]
	XOR	AH,AH
	MOV	ECX,[i]
	OR	ECX,ECX
	JG	@c1
	MOV	ECX,1
@c1:
        ADD	ESI,ECX
	SUB	EAX,ECX
	JB	@c3
	INC	EAX
	MOV	ECX,[len]
	OR	ECX,ECX
	JGE	@c2
	XOR	ECX,ECX
@c2:
        CMP	EAX,ECX
	JBE	@c4
	MOV	EAX,ECX
	JMP	@c4
@c3:
        XOR	EAX,EAX
@c4:
        STOSB  ;
	MOV	ECX,EAX
	REP
        MOVSB
end;
{end;}

function Concat(var s1,s2: string): string;
begin
asm
	CLD
        MOV     EDI,[EBP+8]
        MOV     ESI,[EBP+12]
	MOV	CL,[EDI]
	XOR	CH,CH
	LODSB   ;
	ADD	[EDI],AL
	JNC	@cc1
	MOV	BYTE PTR [EDI],255
	MOV	AL,CL
	NOT	AL
@cc1:
        ADD	EDI,ECX
	INC	EDI
	MOV	CL,AL
	REP
        MOVSB
end;
concat:=s1;
end;

function Pos(const substr, source: string): longint; assembler;
{VAR
   result:BYTE;
BEGIN}
     ASM
         MOV ESI,[substr]
         CLD
         LODSB
         OR AL,AL
         JE @lab2
         MOVZX EAX,AL
         MOV EDX,EAX
         MOV EDI,[source]
         MOVZX ECX,byte ptr [EDI+0]
         SUB ECX,EDX
         JB @lab2
         INC ECX
         INC EDI
@lab1:
         LODSB      ;
         REPNE      ;
         SCASB      ;
         JNE @lab2
         MOV EAX,EDI
         MOV EBX,ECX
         MOV ECX,EDX
         DEC ECX
         REP
         CMPSB
         JE @lab3
         MOV EDI,EAX
         MOV ECX,EBX
         MOV ESI,[substr]
         INC ESI
         JMP @lab1
@lab2:
         XOR EAX,EAX
         JMP @Lab4
@lab3:
         DEC EAX
         SUB EAX,[source]
@Lab4:
         and eax, $ff;
         {MOV [result],AL
     END;
     POS:=result;}
END;

procedure Insert(const source: string; var s: string; index: longint);
var s1:string;
BEGIN
     IF Length(Source) = 0 THEN exit;
     IF Length(S) = 0 THEN
     BEGIN
          S := Source;
          exit;
     END;
     IF Index < 1 THEN Index := 1;
     IF Index > Length(S) THEN Index := Length(S)+1;
     S1 := copy(S,1,Index-1) + Source + copy(S,Index,Length(S)-Index+1);
     s:=s1;
END;


procedure Delete(var s: string; pos, num: longint);
var s1:string;
BEGIN
     IF pos < 1 THEN exit;
     IF pos > Length(S) THEN exit;
     IF num < 1 THEN exit;
     IF pos+num > Length(S) THEN num := Length(S)-pos+1;
     S1 := copy(S,1,pos-1) + copy(S,pos+num,Length(S)-pos-num+1);
     s:=s1;
END;

(* New Randomize specific to Win32 *)
procedure Randomize;
begin
   { Initialize randseed with the number of milliseconds since Windows started }
   randseed := GetTickCount;
end;

function Random(max:longint):longint; assembler;
asm
   mov   eax, 134775813
   mul   dword ptr [randseed]
   inc   eax
   mov   dword ptr [randseed], eax
   xor   edx, edx
   div   dword ptr [max]
   mov   eax, edx
end;

{-- Routines for integer math --}

function Abs(l: longint): longint; assembler;
asm
   mov   eax, dword ptr [l]
   or    eax, eax
   jns   @abs_exit
   neg   eax
@abs_exit:
end;

function Abs(l: double): double; register;
asm
   fabs
end;

function Odd(l: longint): boolean; assembler;
asm
   mov   eax, dword ptr [l]
   and   eax, 1
   setnz al
end;

function Hi(x: integer):byte; register;
asm
  and   eax, $0000FF00 {keep only the bit 16..31}
  shr   eax, 8
end;

function Lo(x: integer):byte; register;
asm
  and   eax, $000000FF { keep only the bit 0..7       }
end;

function Swap(x: integer):integer; register;
asm
  and   eax, $0000FFFF { keep only the bit 0..31      }
  mov   bl, al         { save bit 0..7                }
  shr   eax, 8         { move bit 8..15 to lower bits }
  mov   ah, bl         { store bit 0..7 to upper bits }
end;

function Sqr(r: double): double; register;
asm
  fld   st(0)
  fmul  st(1), st(0)
end;

function Pi: double; assembler;
asm
  fldpi
end;

function ArcTan(r: double): double; register;
asm
  {fld   qword ptr [r]}
  fpatan
end;

function Sqrt(r: double): double; register;
asm
  {fld   qword ptr [r]}
  fsqrt
end;

function Sin(r: double): double; register;
asm
  {fld   qword ptr [r]}
  fsin
end;

function Cos(r: double): double; register;
asm
  {fld  qword ptr [r]}
  fcos
end;

function Round(r: double): longint;
var
  Temp: longint;
  Half: double;
  TempWord,
  CtrlWord : word;

begin
  Half  := 0.5;
  asm
    { Modifiy Rounding Control Bits }
    fstcw word ptr [CtrlWord]
    mov   ax,word ptr [CtrlWord]
    and   ax,$F3FF                   { Clear Rounding control bits  }
    or    ax,$0C00                   { Set Rounding bits to towards zero }
    mov   word ptr [TempWord],ax
    fldcw word ptr [TempWord]
    { Do + or - r := + or - Trunc(Abs(r) + 0.5) }
    fld   qword ptr [r]                { st(0) := r; st(1) := 0.5 }
    fld   qword ptr [Half]             { st(0) := 0.5 }
    test  dword ptr [r + 4],$80000000  { r negative? }
    jns   @RoundPositive
    { for now, just negate r, but should just negate 0.5 and continue... }
    fchs  ;
@RoundPositive:
    fadd st(1), st(0)                      { r := r + 0.5 }
    fistp dword ptr [Temp]

    fldcw word ptr [CtrlWord] {restore control word}
  end;
  Round := Temp;
end;

function Trunc(r: double): longint;
var
  Temp:  longint;
  TempWord,
  CtrlWord : word;
begin
  asm
    fstcw word ptr [CtrlWord]
    mov   ax,word ptr [CtrlWord]
    and   ax,$F3FF                   { Clear Rounding control bits  }
    or    ax,$0C00                   { Set Rounding bits to towards zero }
    mov   word ptr [TempWord],ax
    fldcw word ptr [TempWord]

    fld   qword ptr [r]
    fistp dword ptr [Temp]

    fldcw word ptr [CtrlWord] {restore control word}
  end;
  Trunc := Temp;
end;

function IOResult: longint;
{contains 0 or latest error code}
begin
  IOResult:=InOutRes;
  InOutRes:=0;
end;


procedure iocheck(x: longint); 'iocheck';

var
   l: longint;

begin
  l:=ioresult;
  if l<>0 then
    begin
      writeln('I/O-Error ',l,' at ', x);
      halt(1);
    end;
end;

(* Specific Halt procedure to Win32 *)
procedure Halt;
begin
  ExitProcess(0);
end;

procedure Halt(error: byte);
{stops program execution}
begin
   ExitProcess(error);
end;

procedure ProgramExit; 'programexit';
begin
  ExitProcess(0);
end;

{-- Routines for (text) file I/O, system specific --}

function sys_open(s: pointer; mode: longint): longint;
var auxhnd: longint;
{opens a file and returns file handle in eax}
begin
  case mode of
    fmInput: auxhnd:=CreateFileA(s, GENERIC_READ, 0, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    fmOutput:auxhnd:=CreateFileA(s, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    fmInOut: auxhnd:=CreateFileA(s, GENERIC_WRITE, 0, NULL, OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL, NULL);
  end;
  if auxhnd = INVALID_HANDLE_VALUE then
    InOutRes:= GetLastError
  else InOutRes:= 0;
  sys_open := auxhnd;
end;

procedure sys_close(h : longint);
{closes a file }
begin
  if CloseHandle(h) = 0 then
    InOutRes:= GetLastError
  else InOutRes:= 0;
end;

procedure sys_erase(s: pointer);
{erases a file}
begin
  if DeleteFileA(s) = 0 then
    InOutRes:= GetLastError
  else InOutRes:= 0;
end;

procedure sys_rename(s1, s2: pointer);
{renames a file}
begin
  if MoveFileA(s1, s2) = 0 then
    InOutRes:= GetLastError
  else InOutRes:= 0;
end;

function sys_write(h: longint; s: pointer; len: longint):longint;
var BytesWritten: DWORD;
{writes some bytes to a file}
begin
  if WriteFile(h, s, len, BytesWritten, NULL) = 0 then
    InOutRes:= GetLastError
  else
    InOutRes:= 0;
  sys_write:=BytesWritten
end;

function sys_read(h, len: longint; s: pointer):longint;
var BytesRead: DWORD;
{reads some bytes from a file}
begin
  if ReadFile(h, s, len, BytesRead, NULL) = 0 then
    InOutRes:= GetLastError
  else InOutRes:= 0;
  sys_read:= BytesRead;
end;

procedure sys_seek(h: longint; position: longint);
begin
  if SetFilePointer(h, position, NULL, FILE_BEGIN) = $FFFFFFFF then
    InOutRes:= GetLastError
  else InOutRes:= 0;
end;

function sys_filepos(h: longint): longint;
var dwPointer: DWORD;
{returns positions of the filepointer}
begin
  dwPointer:= SetFilePointer(h, 0, NULL, FILE_CURRENT);
  if dwPointer = $FFFFFFFF then begin
    InOutRes:= GetLastError;
    sys_filepos:= 0;
  end
  else begin
    InOutRes:= 0;
    sys_filepos:= dwPointer;
  end;
end;

function sys_filesize(h: longint) : longint;
var dwSize: DWORD;
begin
  dwSize:= GetFileSize(h, NULL);
  if dwSize = $FFFFFFFF then begin
    InOutRes:= GetLastError;
    sys_filesize:= 0;
  end
  else begin
    InOutRes:= 0;
    sys_filesize:= dwSize;
  end;
end;

procedure ULTOA(value:longint; s:pointer; radix:longint); register;
{ Input: eax - value to convert to ASCII
         edx - pointer to string
         ecx - radix to convert too [2 to 36]  }
asm
   test    edx, edx
   jz      @ultoa_exit
   mov     ebx, edx
   add     ebx, 33
   mov     edi, edx
@ultoa_loop:
   xor     edx,edx
   div     ecx
   dec     ebx
   mov     dl, byte ptr [number_convert+1+edx]
   test    eax,eax
   mov     byte ptr [ebx],dl
   jnz     @ultoa_loop

   mov     edx, edi
   add     edx, 33
   sub     edx, ebx
   dec     ebx
   mov     byte ptr [ebx], dl

   mov   esi, ebx
   movzx ecx, dl
   inc   ecx
   mov   eax, ecx
   shr   ecx, 2
   cld
   rep
   movsd
   mov   ecx, eax
   and   ecx, 3
   rep
   movsb
   jmp   @end

@ultoa_exit:
   xor     eax,eax
@end:
end;

procedure LTOA(value:longint; s:pointer; radix:longint); register;
{ Input: eax - value to convert to ASCII
         edx - pointer to string
         ecx - radix to convert too [2 to 36]  }
asm
   test  edx,edx
   jz    @ltoa_exit
   push  eax
   or    eax, eax
   jns   @ltoa_next
   neg   eax

@ltoa_next:
   mov   ebx, edx
   add   ebx, 33
   mov   edi, edx
@ltoa_loop:
   xor   edx,edx
   div   ecx
   dec   ebx
   mov   dl, byte ptr [number_convert+1+edx]
   test  eax,eax
   mov   byte ptr [ebx], dl
   jnz   @ltoa_loop

   mov     edx, edi
   add     edx, 33
   sub     edx, ebx

   pop   eax
   or    eax, eax
   jns   @ltoa_next2
   neg   eax

   dec   ebx
   inc   edx
   mov   byte ptr [ebx], 45

@ltoa_next2:
   dec   ebx
   mov   byte ptr [ebx], dl
   mov   esi, ebx
   movzx ecx, dl
   inc   ecx
   mov   eax, ecx
   shr   ecx, 2
   cld
   rep
   movsd
   mov   ecx, eax
   and   ecx, 3
   rep
   movsb
   jmp   @end

@ltoa_exit:
   xor     eax,eax
@end:
end;

function ATOI(s: pointer):longint;
var sign_flag,
    err: longint;

begin
  asm
     mov   edi, dword ptr [s] {load address of source string}
     mov   ecx, dword ptr [radix]
     dec   ecx
@skip_ch:

     mov   word ptr [sign_flag], 0
     cmp   byte ptr [edi],'-'
     jne   @gotsign
     mov   word ptr [sign_flag], 1
     inc   esi

@gotsign:
     xor   edx, edx
     mov   al, byte ptr [edi]
     sub   al, '0'
     cmp   al, cl
     ja    @error
     jmp   @LoopStart

@DEC_loop:
     sub   al, '0'
     cmp   al, cl
     ja    @GotNumber
     inc   ecx
     and   eax, $FF
     imul  edx, dword ptr [radix]
     add   edx, eax

@LoopStart:
     mov   al, byte ptr [edi]
     inc   edi
     jmp   @DEC_loop

@GotNumber:
     cmp   word ptr [sign_flag], 0
     je    @j99
     neg   edx
@j99:
     mov   dword ptr [ebp-12], edx {function result}
     mov   dword ptr [err], 0
     jmp   @exit

@error:
     mov   dword ptr [err], -1
     mov   dword ptr [ebp-12], 0
     jmp   @exit

@exit:
     mov   eax, edx
  end
  if err<>0 then writeln('invalid number');
end;

procedure Power10; {internal function}
{factor in st(0), value to be powered on st(1)}
var newcw, oldcw: word;

begin
  asm
     fldl2t                       { load log2(10) }
     fmulp   st(1), st(0)              { log2(10) * argument }
     fld     st(0)                { duplicate product }
     fstcw   word ptr [oldcw]     { get old control word }
     movsx   eax, word ptr [oldcw]{ change rounding mode }
     and     eax, $f3ff           { field to "round down" }
     or      eax, $0400
     mov     word ptr [newcw], ax
     fldcw   word ptr [newcw]     { force rounding mode }
     frndint                      { get int part of product }
     fldcw   word ptr [oldcw]     { restore old rounding mode }
     fld     st(0)                { duplicate integer part }
     fxch    st(2)                { get original product }
     fsubrp  st(1),st(0)              { find fractional part }
     fld1
     fchs
     fxch    st(1)           { scale fractional part }
     fscale
     fstp    st(1)           { discard coprocessor junk }
     f2xm1                   { raise 2 to power-1 }
     fld1
     faddp   st(1),st(0)         { correct for the -1 }
     fmul    st(0),st(0)         { square result }
     fscale                  { scale by int part }
     fstp    st(1)           { discard coprocessor junk }
     fmulp   st(1),st(0)     { multiply st(0) with st(1) }
  end;
end;

procedure FTOA(val:pointer; s:pointer; digs:longint);

var
  CtrlWord, StatWord, Digits, Exponent, Sign, tmp: word;
  Value: array[0..9] of byte;
  DigitBuf: array[0..19] of byte;

  CWNear : word;
  FCon1E18: double;
  DCon1E1 : longint;

begin
  FCon1E18:=1E18;
  CWNear:=$133F;
  DCon1E1:=10;
  asm
     mov edi, dword ptr [val]
     fld qword ptr [edi]
     mov edi, dword ptr [s]
     mov ecx, dword ptr [digs]

	FSTCW	word ptr [CtrlWord]
	FLDCW	word ptr [CWNear]
	FSTP	tbyte ptr [Value]
	push    edi
        inc     edi
	CMP	ecx, 18
	JLE	@1
	MOV	ecx, 18
@1:	CMP	ecx,-18
	JGE	@2
	MOV	ecx,-18
@2:	MOV	word ptr [Digits], cx
	CLD
	MOVsx	eAX, word ptr [Value+8]
	MOV	word ptr [Sign], AX
	AND	eAX,$7FFF
	JE	@5
	CMP	eAX,$7FFF
	JNE	@10
	CMP	word ptr [Value+6], $8000
	JE	@3
        mov     byte ptr [edi], 'N'
        mov     byte ptr [edi+1], 'A'
        mov     byte ptr [edi+2], 'N'
        add     edi, 3
	JMP	@90
@3:	CMP	word ptr [Sign], 0
	JNS	@4
        mov     byte ptr [edi], '-'
        inc     edi
@4:
        mov     byte ptr [edi], 'I'
        mov     byte ptr [edi+1], 'N'
        mov     byte ptr [edi+2], 'F'
        add     edi, 3
	JMP	@90
@5:	MOV	word ptr [Exponent], AX
	MOV	byte ptr [DigitBuf], AL
	JMP	@30
@10:	MOV	word ptr [Value+8],AX
        {movsx   eax, ax}
	FLD	tbyte ptr [Value]
	SUB	eAX, $3FFF
	MOV	edx, 19728
	IMUL	edx
        shr     eax, 16
        mov     edx, eax
	MOV	word ptr [Exponent], dx
	MOV	eax, 17
	SUB	eax, edx
        mov     word ptr [tmp], ax
        fild    word ptr [tmp]
	CALL	Power10
	FRNDINT
	FLD	qword ptr [FCon1E18]
        FCOMP   st(1)
	FSTSW	word ptr [StatWord]
	TEST	word ptr [StatWord], $4100
	JE	@11
        FIDIV   dword ptr [DCon1E1]
	INC	word ptr [Exponent]
@11:
    	FBSTP	tbyte ptr [Value]
	lea	ebx, [DigitBuf]
	MOV	ecx, 4
	MOV	esi, 9
@13:	MOV	AL, byte ptr [Value+esi-1]
	MOV	AH, AL
	SHR	AL, CL
	AND	AH, $0F
	ADD	AX, $3030 {'00'}
	MOV	word ptr [ebx],AX
	add	ebx, 2
	dec     esi
	JNE	@13
	MOV	word ptr [ebx],SI
@20:	CMP	word ptr [Digits],0
	JL	@21
	CMP	word ptr [Exponent],36
	JL	@21
	MOV	word ptr [Digits],-18
@21:	MOVSX	eSI, word ptr [Digits]
	OR	eSI,eSI
	JS	@22
        movsx   ecx, word ptr [Exponent]
	ADD	eSI, ecx
	INC	eSI
	JNS	@23
	MOV	byte ptr [DigitBuf],0
	JMP	@30
@22:	NEG	eSI
@23:	CMP	eSI,18
	JAE	@30
	CMP	byte ptr [DigitBuf + eSI],'5'
	MOV	byte ptr [DigitBuf + eSI],0
	JB	@30
@24:	DEC	eSI
	JS	@25
	INC	byte ptr [DigitBuf + eSI]
	CMP	byte ptr [DigitBuf + eSI], '9'
	JBE	@30
	MOV	byte ptr [DigitBuf + eSI],0
	JMP	@24
@25:	MOV	word ptr [DigitBuf],'1'
	INC	word ptr [Exponent]
@30:	XOR	eSI,eSI
	MOVsx	eDX,word ptr [Digits]
	OR	eDX, eDX
	JS	@40
	CMP	word ptr [Sign],0
	JNS	@31
        mov     byte ptr [edi], '-'
        inc     edi
@31:	MOVSX	eCX,word ptr [Exponent]
	OR	eCX,eCX
	JNS	@32
        mov     byte ptr [edi], '0'
        inc     edi
	JMP	@33
@32:	CALL	@GetDigit
        mov     byte ptr [edi], al
        inc     edi
	DEC	eCX
	JNS	@32
@33:	OR	eDX,eDX
        JE      near @90
        mov     byte ptr [edi], '.'
        inc     edi
@34:	INC	eCX
	JE	@35
        mov     byte ptr [edi], '0'
        inc     edi
	DEC	eDX
	JNE	@34
@35:	DEC	eDX
        JS      @90
	CALL	@GetDigit
        mov     byte ptr [edi], al
        inc     edi
	JMP	@35
@40:	MOV	AL,' '
	CMP	word ptr [Sign],0
	JNS	@46
	MOV	AL,'-'
@46:	
        mov     byte ptr [edi], al
        inc     edi
	CALL	@GetDigit
        mov     byte ptr [edi], al
        inc     edi
	INC	eDX
	JE	@42
        mov     byte ptr [edi], '.'
        inc     edi
@41:	CALL	@GetDigit
        mov     byte ptr [edi], al
        inc     edi
	INC	eDX
	JNE	@41
@42:	MOV	AL,'E'
        mov     byte ptr [edi], al
        inc     edi
	MOV	AL,'+'
	MOVSX	eDX, word ptr [Exponent]
	OR	eDX,eDX
	JNS	@43
	MOV	AL,'-'
	NEG	eDX
@43:	
        mov     byte ptr [edi], al
        inc     edi
	MOV	eAX,(100*256)+10
	XCHG	eAX,eDX
	DIV	DH
	MOV	DH,AH
	CBW
	DIV	DL
	ADD	AX,$3030 {'00'}
        mov     word ptr [edi], ax
        add     edi, 2
	MOV	AL,DH
	CBW
	DIV	DL
	ADD	AX,$3030 {'00'}
        mov     word ptr [edi], ax
        add     edi, 2
@90:	MOV	eCX,eDI
	POP	eDI
	SUB	eCX,eDI
        mov     byte ptr [edi], cl
	FCLEX
	FLDCW	word ptr [CtrlWord]
        jmp @end

{ Get digit from digit buffer}

@GetDigit:
	MOV	AL, byte ptr [DigitBuf+eSI]
	INC	eSI
	OR	AL,AL
	JNE	@stop
	MOV	AL,'0'
	DEC	eSI
@stop:	RET     0
@end:
end;
end;

function ATOF(const s:string):double;

var
   CWNear, CtrlWord, TempWord, tmp: word;
   SignChar, ExpoChar: byte;
   DCon1E1 : longint;

begin
  CWNear:=$133F;
  DCon1E1:=10;
{
; Convert string to float
; In	CX    = String length
;	ES:DI = String pointer
; Out	CX    = Remaining characters
;	ES:DI = Pointer past string
;	CF    = 1 if error
;	ST(0) = Value
}

asm
   mov  edi, dword ptr [s]
   xor  ecx, ecx
   mov  cl, byte ptr [edi]
   inc  edi
	FSTCW	word ptr [CtrlWord]
	FCLEX
	FLDCW	word ptr [CWNear]
	FLDZ
        test    ecx, ecx
        JZ      near @7
	MOV	AL, byte ptr [edi]
	MOV	byte ptr [SignChar], AL
	CMP	AL, ' '
	JE	@1
	CMP	AL, '+'
	JE	@1
	CMP	AL, '-'
	JNE	@2
@1:	INC	edi
	DEC	eCX
@2:	PUSH	eCX
	CALL	@DigitStr
	XOR	eBX, eBX
	JCXZ	@3
	MOV	AL, byte ptr [edi]
	CMP	AL,'.'
	JNE	@3
	INC	eDI
	DEC	eCX
	CALL	@DigitStr
	NEG	eBX
@3:	POP	eAX
	CMP	eAX, eCX
	JE	@7
	JeCXZ	@5
	MOV	AL, byte ptr [EDI]
	CMP	AL,'E'
	JE	@4
	CMP	AL,'e'
	JNE	@5
@4:	INC	eDI
	DEC	eCX
	PUSH	ecx

        push    edi      {pointer to string}
        call    ATOI

	POP	ecx
	JC	@7
        push    eax
        shr     eax, 16
        mov     edx, eax
        pop     eax
	MOV	SI, DX
	CWD
	CMP	SI, DX
	JNE	@7
	CMP	AX,4999
	JGE	@7
	CMP	AX,-4999
	JLE	@7
	ADD	BX, AX
@5:	MOV	AX, BX
        mov     word ptr [tmp], ax
        fild    word ptr [tmp]
	CALL	Power10
	CMP	byte ptr [SignChar],'-'
	JNE	@6
	FCHS    ;
@6:	FSTSW	word ptr [TempWord]
	TEST	word ptr [TempWord], $0009{mIE+mOE}
	JE	@8
@7:	STC     ;
@8:	FCLEX   ;
	FLDCW	word ptr [CtrlWord]
	jmp     @exit

{ Process string of digits
  Out	EBX = Digit count }

@DigitStr:
	XOR	ebx, ebx
@d1:	JCXZ	@d2
	MOV	AL, byte ptr [edi]
	SUB	AL, 58
	ADD	AL, 10
	JNC	@d2
        FIMUL   dword ptr [DCon1E1]
	CBW
	MOV	word ptr [TempWord], AX
	FIADD	word ptr [TempWord]
	INC	eBX
	INC	eDI
	DEC	eCX
	JMP	@d1
@d2:	RET     0

@exit:
        fstp    qword ptr [ebp - 32]
end;
end;

procedure Val(const s: string; var rvar: double; var code: longint);
begin
asm
        mov edi,dword ptr [s]
        xor ecx,ecx
        mov cl,byte ptr[edi]
	INC	eDI
	JeCXZ	@v2
@v1:
        CMP	BYTE PTR [eDI],' '
	JNE	@v2
	INC	eDI
	LOOP	@v1

@v2:
        dec edi
        push edi
        CALL	AtoF
	JC	@v3
	JeCXZ	@v4
@v3:
        MOV	eCX,eDI
	SUB	eCX,dword ptr[s]
        mov	eax, dword ptr [ebp + 12]
        fstp	qword ptr [eax]
        FLDZ ;
@v4:
        mov	eDI,dword ptr [code]
	MOV	dword ptr [eDI],eCX
        mov	eax, dword ptr [ebp + 12]
        fstp	qword ptr [eax]
end;
end;

{-- Routines for text file I/O --}

procedure text_close(var t: TextRec);
begin
  sys_close(t.Handle);
end;

procedure text_io(var t: TextRec);
begin
  case t.Mode of
  fmInOut, fmOutput : sys_write(t.Handle, t.BufPtr, t.BufPos);
  fmInput           : t.BufEnd:=sys_read(t.Handle, t.BufSize, t.BufPtr);
  else       Halt(100);
  end;
  t.BufPos := 0;
end;

procedure text_open(var t: TextRec);
var buf : array[0..MAX_PATH] of char;
begin
  ASCIIZ(t.name, @buf);
  t.Handle:=sys_open(@buf, t.Mode);
  if t.Mode = fmInOut then 
    sys_seek(t.Handle, sys_filesize(t.Handle));
  if InOutRes = 0 then begin
    t.InOutFunc:=@text_io;
    t.FlushFunc:=@text_io;
    t.CloseFunc:=@text_close;
  end;
end;

procedure assign(var t: text;const s: string);
{assign for text files}

begin
  TextRec(t).Mode:=fmClosed;
  TextRec(t).BufSize:=128;               {default for text files}
  TextRec(t).BufPos:=0;
  TextRec(t).BufEnd:=0;
  TextRec(t).BufPtr:=@TextRec(t).Buffer;   {pointer to the buffer}
  TextRec(t).Name:=s;                      {filename}
  TextRec(t).OpenFunc:=@text_open;         {function to call for opening the file}
end;

procedure rewrite(var t: text);
{open file for writing...}
begin
  TextRec(t).Mode:=fmOutput;
  asm
     mov   eax, dword ptr [t]
     lea   edi, [eax]
     push  edi
     call  [eax+24] {TextRec(t).OpenFunc}
  end;
end;

procedure reset(var t: text);
{open file for reading...}

begin
  TextRec(t).Mode:=fmInput;
  asm
     mov   eax, dword ptr [t]
     lea   edi, [eax]
     push  edi
     call  [eax+24] {OpenFunc}
  end;
end;

procedure append(var t: text);
{open file for appending some stuff...}
begin
  TextRec(t).Mode:=fmInOut;
  asm
     mov   eax, dword ptr [t]
     lea   edi, [eax]
     push  edi
     call  [eax+24] {OpenFunc}
  end;
end;

procedure flush(var t: text);
{flushes buffers for text file}
begin
  if TextRec(t).Mode=fmOutput then
  asm
     mov   eax, dword ptr [t]
     lea   edi, [eax]
     push  edi
     call  [eax+32] {FlushFunc}
  end;
end;

procedure close(var t: text);
begin
  if TextRec(t).Mode<>fmClosed then
    begin
      asm
         mov   eax, dword ptr [t]
         lea   edi, [eax]
         push  edi
         call  [eax+32] {FlushFunc}
      end;

      TextRec(t).Mode:=fmClosed;

      asm
         mov   eax, dword ptr [t]
         lea   edi, [eax]
         push  edi
         call  [eax+36] {CloseFunc}
      end;
    end;
end;

procedure FlushOutput; assembler; 'flushoutput';
{flushes buffers for standard output}
asm
   lea   eax, [output]
   push  eax
   call  [eax+32] {FlushFunc}
end;

procedure WriteString(var t: TextRec; var s: string; l: longint); 'writestring';

var left, todo, cnt :longint;

begin 
  if t.Mode=fmOutput then
    begin
      todo:=ord(s[0]);
      left:=t.BufSize-t.BufPos;
      cnt:=1;
      if left=0 then
        asm
           mov   eax, dword ptr [t]
           lea   edi, [eax]
           push  edi
           call  [eax+32] {FlushFunc}
        end;
      while todo>left do
        begin
          move(s[cnt], t.BufPtr^[t.BufPos], left);
          t.BufPos:=t.BufPos + left;
          dec(todo, left);
          inc(cnt, left);
          asm {call output function}
             mov   eax, dword ptr [t]
             lea   edi, [eax]
             push  edi
             call  [eax+28] {InOutFunc}
          end;
          left:=t.BufSize-t.BufPos;
        end;
      move(s[cnt], t.BufPtr^[t.BufPos], todo);
      t.BufPos:=t.BufPos+todo;
    end; 
end;

procedure WriteLine(var t: TextRec); 'writeline';

const s = #13#10;

begin
  WriteString(t.handle, s, 0);
end;

procedure WriteBoolean(var t: TextRec; b:boolean; l: longint); 'writeboolean';

const truestring  = 'TRUE';
      falsestring = 'FALSE';
begin
  if b=true then WriteString(t.handle, truestring, 0)
            else WriteString(t.handle, falsestring, 0)
end;

procedure WriteChar(var t: TextRec; nr, l: longint); 'writechar';

var c:string[1];

begin
  c[0]:=1;
  c[1]:=char(nr); 
  WriteString(t.handle, c, l);
end;

procedure WriteUInt(var t: TextRec; nr, l: longint); 'writeuint';

var buffer:string;

begin
  ULTOA(nr, @buffer, radix);
  WriteString(t.handle, buffer, l);
end;

procedure WriteSInt(var t: TextRec; nr, l: longint); 'writesint';

var buffer:string;

begin
  LTOA(nr, @buffer, radix);
  WriteString(t.handle, buffer, l);
end;

procedure WritePointer(var t: TextRec; nr,l: longint); 'writepointer';

var buffer, tmp: string;
              i: longint;
begin
  ULTOA(nr, @buffer, 16);
  tmp:='00000000';
  asm
     mov   eax, 9
     sub   al, byte ptr[buffer]
     lea   esi, [buffer]
     lea   edi, [tmp]
     add   edi, eax
     inc   esi
     movzx ecx, byte ptr [buffer]
     rep   
     movsb
  end;
  WriteString(t.handle, tmp, l);
end;

procedure WriteReal(var t: TextRec; nr: double; l:longint); 'writereal';

var buffer:string;

begin
  FTOA(@nr, @buffer, -13);
  WriteString(t.handle, buffer, l);
end;

procedure ReadString(var t: TextRec;var s : string; l:longint); 'readstring';

var i, j: longint;

begin
  if t.Mode=fmInput then
    begin
      s:='';
      if t.BufPos >= t.BufEnd then begin {buffer empty}
        t.BufPos := 0;
        asm {call input function}
           mov   eax, dword ptr [t]
           lea   edi, [eax]
           push  edi
           call  [eax+28] {InOutFunc}
        end;
      end;
      i:=t.BufPos;
      j:=1;

      while (t.BufPos<t.BufEnd) and (t.BufPtr^[i]<>#10) do {end of buffer/end of line?}
        begin
          while (t.BufPtr^[i]<>#10) and (i<t.BufEnd) do inc(i); {search linefeed in buffer}
          if (j+i-t.BufPos) <= l then
            begin
              move(t.Bufptr^[t.BufPos], s[j], i-t.BufPos);
              j:=j+i-t.BufPos;
              if s[j-1]=#13 then dec(j);
            end
          else
            begin
              if (j<=l) then move(t.BufPtr^[t.BufPos],s[j],(l+1)-j);
              j:=l+1;
            end;
          t.BufPos:=i+1;
          if i>=t.BufEnd then
            begin
              asm {call input function}
                 mov   eax, dword ptr [t]
                 lea   edi, [eax]
                 push  edi
                 call  [eax+28] {InOutFunc}
              end;
              t.BufPos:=0;
              i:=0;
            end;
        end
      s[0]:=char(j-1);
    end;
end;

procedure ReadLine(var t: TextRec); 'readline';

begin
  if t.Mode=fmInput then
    begin
      repeat
        if t.BufPos >= t.BufEnd then {buffer empty}
          asm {call input function}
             mov   eax, dword ptr [t]
             lea   edi, [eax]
             push  edi
             call  [eax+28] {InOutFunc}
          end;
        if t.BufPos >= t.BufEnd then exit; {still nothing in buffer}
        inc(t.BufPos);
      until t.BufPtr^[t.BufPos-1]=#10;
      inc(t.BufPos);
    end;
end;

procedure ReadInt(var t: TextRec; var l : longint); 'readint';

var x: char;
    s: string;
    p: pointer;

begin
  if t.Mode=fmInput then
    begin
      repeat
        if t.BufPos >= t.BufEnd then {buffer empty}
        asm {call input function}
           mov   eax, dword ptr [t]
           lea   edi, [eax]
           push  edi
           call  [eax+28] {InOutFunc}
        end;
        x:=t.BufPtr^[t.BufPos];
        inc(t.BufPos);
      until (x<>#13) and (x<>#10) and (x<>#9) and (x<>' ');

      dec(t.BufPos);
      s:='';
      repeat
        if t.BufPos >= t.BufEnd then {buffer empty}
        asm {call input function}
           mov   eax, dword ptr [t]
           lea   edi, [eax]
           push  edi
           call  [eax+28] {InOutFunc}
        end;
        x:=t.BufPtr^[t.BufPos];
        s:=s+x;
        inc(t.BufPos);
      until (x=#13) or (x=#10) or (x=#9) or (x=' ');
      l:=ATOI(@s[1]);
    end;
end;

{********** untyped file routines **********}

procedure assign(var f: file; const s:string);
begin
  FileRec(f).mode:=fmClosed;
  FileRec(f).Name:=s;
end;

procedure reset(var f: file; l: longint);
var buf : array[0..255] of char;

begin
  if FileRec(f).mode <> fmClosed then close(f);
  if l=0 then
    InOutRes:=2
  else
    begin
      FileRec(f).Mode:=fmInput;
      ASCIIZ(FileRec(f).Name, @buf);
      FileRec(f).handle:=sys_open(@buf, fmInput);
      FileRec(f).RecSize:=l;
    end;
end;

procedure reset(var f: file);
begin
  reset(f, 128);
end;

procedure rewrite(var f: file; l: longint);
var buf : array[0..255] of char;
begin
  if l=0 then
    InOutRes:=2
  else
    begin
      FileRec(f).Mode:=fmOutput;
      ASCIIZ(FileRec(f).Name, @buf);
      FileRec(f).handle:=sys_open(@buf, fmOutput);
      FileRec(f).RecSize:=l;
    end;
end;

procedure rewrite(var f: file);
begin
  rewrite(f, 128);
end;

procedure close(var f: file);
begin
  if FileRec(f).mode <> fmClosed then
    begin
      FileRec(f).mode:=fmClosed;
      sys_close(FileRec(f).Handle);
    end;
end;

procedure blockwrite(var f: file; var buf; count: longint; var result: longint);
begin
  result:=sys_write(FileRec(f).Handle, @buf, count*FileRec(f).RecSize) div FileRec(f).RecSize;
end;

procedure blockwrite(var f: file; var buf; count: longint);
var
  result : longint;
begin
  blockwrite(f, buf, count, result);
  if (result=0) and (count>0) then
   InOutRes:=101;
end;

procedure blockread(var f: file; var buf; count: longint; var result: longint);
begin
  result:=sys_read(FileRec(f).Handle, count*FileRec(f).RecSize, @buf) div FileRec(f).RecSize;
end;

procedure blockread(var f: file; var buf; count: longint);
var
  result : longint;
begin
  blockread(f, buf, count, result);
end;

function filepos(var f: file): longint;
begin
  filepos:=sys_filepos(FileRec(f).Handle) div FileRec(f).RecSize;
end;

procedure seek(var f: file; pos: longint);
begin
  sys_seek(FileRec(f).Handle, pos*FileRec(f).RecSize);
end;

function filesize(var f: file): longint;
var l:longint;
begin
  filesize:=sys_filesize(FileRec(f).Handle);
end;

{ ParamStr and ParamCount differ from DOS. Long filenames obligate that }
{ spaces and tabs between "" must be considered as one parameter only.  }
{ Function below implements a finite state machine that does both jobs. }
function GetNthParam(nparam: longint; var s: string): longint; assembler;
asm
--  count := -1;
    mov ecx, -1
--  state := Initial;
    xor edx, edx
--  ptrLine := CmdLine;
    mov esi, dword ptr [CmdLine]
--  s := '';
    mov edi, dword ptr [s]
    mov ebx, edi
    mov byte ptr [edi], 0
--  repeat
@LREPEAT:
--    case ptrLine^ of
--      0 : break;     
    cmp byte ptr [esi], 0    
    je near @LUNTIL
--{"}   34: case state of
    cmp byte ptr [esi], 34
    jne @LSPACE
--             Initial: state:= IniSpecial;
--             EndSpecial: state:= Normal;
--             Normal : state:= EndSpecial;
    cmp edx, 2
    jb @LINITIAL1
    xor edx, 1
    jmp @LENDCASE
@LINITIAL1:
    or  edx, 1
    jmp @LENDCASE
--           end;
--{spc} 32,
@LSPACE:
    cmp byte ptr [esi], 32
    je @LDOSPC
--{tab} 9 : case state of
    cmp byte ptr [esi], 9
    jne @LELSE
@LDOSPC:
--             EndSpecial: s:= s + ptrLine^;
    cmp edx, 2
    jne @LNORMAL1
    inc byte ptr [ebx]
    inc edi
    mov al, byte ptr [esi]
    mov byte ptr [edi], al
    jmp @LENDCASE	
--             Normal: begin
@LNORMAL1:
    cmp edx, 3
    jne @LENDCASE
--                       if nparam = count then break;
    cmp ecx, dword [nparam]
    je @LUNTIL
--                       state:= Initial;
    xor edx, edx
    jmp @LENDCASE
--                     end;
--           end; 
--      else case state of
@LELSE:
--             Initial: begin
--			  s:= ptrLine^;
--                        Inc(count);
--                        state:= Normal;
--                      end;
--             IniSpecial: begin
--                           s:= ptrLine^;
--                           Inc(count);
--                           state:= EndSpecial;
--                         end;
    cmp edx, 1
    ja @LNORMAL2
    mov edi, ebx
    mov byte ptr [ebx], 1
    inc edi
    mov al, byte ptr [esi]
    mov byte ptr [edi], al
    inc ecx
    xor edx, 3
    jmp @LENDCASE
--             EndSpecial, Normal: s:= s + ptrLine^;
@LNORMAL2:
    inc byte ptr [ebx]
    inc edi
    mov al, byte ptr [esi]
    mov byte ptr [edi], al
--           end;
--    end;
@LENDCASE:
--    ptrLine:= ptrLine + 1;
    inc esi
--  until FALSE;
    jmp @LREPEAT
@LUNTIL:
--  GetNthParam := count;
    mov eax, ecx
end;


function ParamCount: longint;
var s: string;
begin
  ParamCount := GetNthParam(-1, s);
end;

function ParamStr(index: longint): string;
var s: string;
begin
  GetNthParam(index, s);
  ParamStr:= s;
end;

(* New heap management routines. Simply bypasses to Win32 heap allocation APIs *)
procedure GetMem(var p: pointer; size: dword); 'new';
{ If function fail a NIL pointer is returned }
begin
  p := HeapAlloc(HeapHandle, 0, size);
end;

procedure FreeMem(var p: pointer; size: dword); 'dispose';
{ Works different from FreeMem for DOS extenders. "size" is not used,
  previous allocated size is disposed integrally }
begin
  if HeapFree(HeapHandle, 0, p) <> 0 then p := 0 { must be NIL when implemented };
end;

procedure HeapInit(var Size: dword);
begin
  HeapHandle := HeapCreate(0, Size, 0);
  if HeapHandle = 0 { must be NIL when implemented } then
    begin
      Writeln('Error allocating heap memory. Aborting.');
      Halt(1);
    end;
end;

procedure HeapDone;
begin
  if not boolean(HeapDestroy(HeapHandle)) then
    Writeln('Error releasing heap memory.');
end;

(* New initialization code for Win32 console apps *)
begin
  radix:=10;
  CmdLine := GetCommandLineA;
  {Initialize standard input and output, STDIN/STDOUT}
{  assign(input,'');}
  TextRec(input).Handle:= GetStdHandle(STD_INPUT_HANDLE);
  TextRec(input).BufSize:=1;
  TextRec(input).Mode:=fmInput;
  TextRec(input).InOutFunc:=@text_io;
  TextRec(input).FlushFunc:=@text_io;

{  assign(output,'');}
  TextRec(output).Handle:= GetStdHandle(STD_OUTPUT_HANDLE);
  TextRec(output).Mode:=fmOutput;
  TextRec(output).InOutFunc:=@text_io;
  TextRec(output).FlushFunc:=@text_io;

  InOutRes:=0;

  HeapInit(HeapSize);
end.
{$ENDIF}

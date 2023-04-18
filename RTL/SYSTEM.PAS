{                         P32 - 32bit Pascal Compiler                        }
{ -------------------------------------------------------------------------- }
{                       Johan Prins - jprins@knoware.nl                      }
{ ========================================================================== }
{                                                                            }
{                                                    (c) Copyright 1997-1999 }
{                                                                            }
{ -------------------------------------------------------------------------- }
{ System unit for P32 v0.5                                                   }
{ -------------------------------------------------------------------------- }

{$IFDEF P32}

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
{  double     = 5.0e-324..1.7e308;}

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

   mem   : array[0..0] of byte absolute $0;
   memw  : array[0..0] of word absolute $0;
   meml  : array[0..0] of longint absolute $0;

   input, output: text; {standard input and standard output}
   radix        : longint;

   FreeList: pointer;  { start of a linked list of free memory blocks }

   HeapHandle : dword;           { DPMI handle }
   HeapOrg,
   HeapEnd    : pointer;         { Base address of the heap }
   HeapSize   : dword; external; { Size of the heap }

{$IFDEF PASS32}
   {$DEFINE WDOSX}
{$ENDIF}

procedure ASCIIZ(var source: string; dest: pointer);

procedure Move(var source, dest; count:longint);
procedure FillChar(var x:pointer; count:longint; value:byte);

procedure Randomize;
function Random(max:longint):longint;
function Abs(x: longint): longint;
function Abs(x: double): double;
function Odd(x: longint): boolean;
function Hi(x: integer): byte;
function Lo(x: integer): byte;
function Swap(x: integer): integer;
function Addr(var x): pointer;

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
function MemAvail: longint;

procedure createobject;
procedure destroyobject;

implementation

const number_convert = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

var
    randseed: longint;
    InOutRes: longint;

    CmdLine : string;

{    HeapSize: dword; external;   { Size of the heap }

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
   jbe   @1
   mov   al,cl
@1:
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
   cld
   lodsb
   cmp   al, cl
   jbe   @2
   mov   al, cl
@2:
   mov   cl, al
   mov   ebx, dword ptr [s1]
   add   byte ptr [ebx], cl
   movzx ecx, cl
   mov   eax, ecx
   shr   ecx, 2
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
        STOSB
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
@Lab2:
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

procedure Randomize; assembler;
asm
   xor   eax, eax
   mov   ah, $2C
   int   $21
   mov   word ptr [randseed+2], cx
   mov   word ptr [randseed], dx
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

function Abs(x: longint): longint; assembler;
asm
   mov   eax, dword ptr [x]
   or    eax, eax
   jns   @abs_exit
   neg   eax
@abs_exit:
end;

function Abs(x: double): double; inline;
asm
   fabs
end;

function Odd(x: longint): boolean; assembler;
asm
   mov   eax, dword ptr [x]
   and   eax, 1
   setnz al
end;

function Hi(x: integer):byte; inline;
asm
  and   eax, $0000FF00 {keep only the bit 16..31}
  shr   eax, 8
end;

function Lo(x: integer):byte; inline;
asm
  and   eax, $000000FF { keep only the bit 0..7       }
end;

function Swap(x: integer):integer; register; assembler;
asm
  and   eax, $0000FFFF { keep only the bit 0..31      }
  mov   bl, al         { save bit 0..7                }
  shr   eax, 8         { move bit 8..15 to lower bits }
  mov   ah, bl         { store bit 0..7 to upper bits }
end;

function Addr(var x): pointer;
begin
  Addr:=@x;
end;

function Sqr(r: double): double; inline;
asm
  fld   st(0)
  fmul  st(0)
end;

function Pi: double; inline;
asm
  fldpi
end;

function ArcTan(r: double): double; inline;
asm
  fld1
  fpatan
end;

function Sqrt(r: double): double; inline;
asm
  fsqrt
end;

function Sin(r: double): double; inline;
asm
  fsin
end;

function Cos(r: double): double; inline;
asm
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
    fadd                             { r := r + 0.5 }
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


procedure Halt; assembler;
asm
  mov   eax, $4C00
  int   $21
end;

procedure Halt(error: byte); assembler;
{stops program execution}
asm
   mov   ah, $4C
   mov   al, byte ptr [error]
   int   $21
end;

procedure ProgramExit; assembler; 'programexit';
asm
  mov   eax, $4C00
  int   $21
end;

{-- Routines for (text) file I/O, system specific --}

function sys_open(s:pointer; f:longint): longint; assembler;
{opens a file and returns file handle in eax}
asm
   mov   eax, dword ptr [f]
   mov   edx, dword ptr [s]
   int   $21
   jnc   @sys_open_exit
   mov   word ptr [InOutres], ax {when there is an error, put value in InOutRes}
   xor   eax, eax
@sys_open_exit:
   movzx eax, ax
end;

procedure sys_close(h : longint); assembler;
{closes a file }
asm
   mov   ah, $3E
   mov   ebx, dword ptr [h]
   int   $21
   jnc   @sys_close_exit
   mov   word ptr [InOutres], ax
@sys_close_exit:
end;

procedure sys_erase(s: pointer); assembler;
{erases a file}
asm
   mov   ah, $41
   mov   edx, dword ptr [s]
   int   $21
   jnc   @sys_erase_exit
   mov   word ptr [InOutres], ax
@sys_erase_exit:
end;

procedure sys_rename(s1, s2: pointer); assembler;
{renames a file}
asm
   mov   edx, dword ptr [s1]
   mov   edi, dword ptr [s2]
   mov   ah, $56
   int   $21
   jnc   @sys_rename_exit
   mov   word ptr [InOutres], ax
@sys_rename_exit:
end;

function sys_write(handle: longint; s: pointer; length: longint):longint; register; assembler;
{writes some bytes to a file}
{  mov   eax, dword ptr [handle]
   mov   edx, dword ptr [s]
   mov   ecx, dword ptr [length]}
asm
   mov   ebx, eax
   mov   ah, $40
   int   $21
   jnc   @sys_write_exit
   mov   word ptr [InOutres], ax
@sys_write_exit:
end;

function sys_read(handle, s: pointer; length: longint):longint; register; assembler;
{reads some bytes from a file}
{  mov   eax, dword ptr [handle]
   mov   edx, dword ptr [s]
   mov   ecx, dword ptr [length]}
asm
   mov   ebx, eax
   mov   ah, $3F
   int   $21
   jnc   @sys_read_exit
   mov   word ptr [InOutres], ax
   xor   eax, eax
@sys_read_exit:
end;

procedure sys_seek(handle: longint; position: longint); assembler;
asm
   mov   ax, $4200
   mov   ebx, dword ptr [handle]
   mov   edx, dword ptr [position]
   int   $21
   jnc   @exit
   mov   word ptr [InOutres], ax
@exit:
end;

function sys_filepos(handle: longint): longint; assembler;
{returns positions of the filepointer}
asm
   xor   edx, edx
   mov   ax, $4201
   mov   ebx, dword ptr [handle]
   int   $21
   jnc   @exit
   mov   word ptr [InOutres], ax
   xor   eax, eax
@exit:
end;

function sys_seekend(handle: longint):longint; assembler;
asm
   mov   ax, $4202
   mov   ebx, dword ptr [handle]
   xor   edx, edx
   int   $21
   jnc   @exit
   mov   word ptr [InOutres], ax
   xor   eax, eax
@exit:
end;

procedure ULTOA(value:longint; s:pointer; radix:longint); register; assembler;
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
   mov     dl, byte ptr [number_convert + 1 + edx]
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

procedure LTOA(value:longint; s:pointer; radix:longint); register; assembler;
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
     fmulp   st(1),st(0)          { log2(10) * argument }
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
     fsubrp  st(1),st(0)          { find fractional part }
     fld1
     fchs
     fxch    st(1)           { scale fractional part }
     fscale
     fstp    st(1)           { discard coprocessor junk }
     f2xm1                   { raise 2 to power-1 }
     fld1
     faddp   st(1),st(0)     { correct for the -1 }
     fmul    st(0),st(0)     { square result }
     fscale                  { scale by int part }
     fstp    st(1)           { discard coprocessor junk }
     fmulp   st(1)           { multiply st(0) with st(1) }
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
	FCOMP   
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
	JE	near @90
        mov     byte ptr [edi], '.'
        inc     edi
@34:	INC	eCX
	JE	@35
        mov     byte ptr [edi], '0'
        inc     edi
	DEC	eDX
	JNE	@34
@35:	DEC	eDX
	JS	@90
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
        dec     ecx
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
        JZ	near @7
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
	FIMUL	dword ptr [DCon1E1]
	CBW     ;
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
  fmOutput : sys_write(t.Handle, t.BufPtr, t.BufPos);
  fmInput  : t.BufEnd:=sys_read(t.Handle, t.BufPtr, t.BufSize);
  else       Halt(100);
  end;
  t.BufPos:=0;
end;

procedure text_open(var t: TextRec);

var buf : array[0..255] of char;

begin
  ASCIIZ(t.name, @buf);
  t.InOutFunc:=@text_io;
  t.FlushFunc:=@text_io;
  t.CloseFunc:=@text_close;
  case t.Mode of
  fmInput  : t.Handle:=sys_open(@buf, $3D00);
  fmOutput : t.Handle:=sys_open(@buf, $3C00);
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
  TextRec(t).Mode:=fmOutput;
  asm
     mov   eax, dword ptr [t]
     lea   edi, [eax]
     push  edi
     call  [eax+20] {OpenFunc}
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

procedure spaces(l: longint; var s: string); assembler;
asm
   mov    edi, dword ptr [s]
   mov    cl, byte ptr [l]
   mov    byte ptr [edi], cl
   mov    dl, cl
   inc    edi
   jecxz  @exit
   cld
   mov    eax, '    '
   shr    cl, 2
   rep
   stosd
   mov    cl, dl
   and    cl, 3
   rep
   stosb
@exit:
end;

procedure WriteString(var t: TextRec; var s: string; l: longint); 'writestring';

var left, todo, cnt :longint;
    temp: string;

begin
  l:=l-ord(s[0]);
  if l>0 then 
    begin  
      spaces(l, temp);
      s:=temp + s;
    end

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

const crlf = #13#10;

begin
  WriteString(t.handle, crlf, 0);
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
      if t.BufPos >= t.BufEnd then {buffer empty}
        asm {call input function}
           mov   eax, dword ptr [t]
           lea   edi, [eax]
           push  edi
           call  [eax+28] {InOutFunc}
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
          t.BufPos:=i;
          if i>=t.BufEnd then
            begin
              asm {call input function}
                 mov   eax, dword ptr [t]
                 lea   edi, [eax]
                 push  edi
                 call  [eax+28] {InOutFunc}
              end;
              i:=t.BufPos;
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
      FileRec(f).handle:=sys_open(@buf, $3D00+FileMode);
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
      FileRec(f).handle:=sys_open(@buf, $3C00);
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
  result:=sys_read(FileRec(f).Handle, @buf, count*FileRec(f).RecSize) div FileRec(f).RecSize;
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
  {save current position}
  l:=sys_filepos(FileRec(f).Handle);
  filesize:=sys_seekend(FileRec(f).Handle);
  sys_seek(FileRec(f).Handle, l);
end;

{********** parameter handling, slow **********}

procedure GetCmdLine(var s:string);
var p: pointer;
    b: byte;

begin
  asm
     mov   eax, 0EE02h
     int   31h
     {ESI contains pointer to PSP}
     add   esi, 80h
     mov   dword ptr [p], esi
     mov   al, byte ptr [esi]
     {also include length byte}
     inc   al
     mov   byte ptr [b], al
  end;
  move(p^, s, b);
end;

function ParamStr(index: longint): string;
var p: pointer;
    s: string;
    cnt, pos, len, b: dword{longint};

begin
  if index=0 then
    begin
      asm
         mov   eax, 0EE02h
         int   31h
         {ECX contains pointer to executable name}
         mov   dword ptr [p], ecx
         mov   esi, ecx
         cld   ;
@1:      cmp   byte ptr [esi], 0
         jz    @2
         inc   esi
         jmp   @1
@2:      mov   eax, esi
         sub   eax, ecx
         mov   dword ptr [b], eax
      end;
      move(p^, s[1], b);
      s[0]:=char(b);
    end
  else
    begin
      pos:=0;
      cnt:=0;
      s:='';
      len:=length(CmdLine);
      if len<>0 then
        repeat
          inc(pos);
          if CmdLine[pos]=' ' then
            begin
              inc(cnt);
              while (pos<>len) and (CmdLine[pos]=' ') do inc(pos);
            end;
          if cnt=index then
            begin
              while (pos<>len+1) and (CmdLine[pos]<>' ') do
                begin
                  s:=s+CmdLine[pos];
                  inc(pos);
                end;
              break;
            end;
        until (pos>=len);
    end;
  ParamStr:=s;
end;

function ParamCount: longint;
var cnt, i, len: longint;

begin
  cnt:=0;
  i:=0;
  len:=length(CmdLine);
  while i<>len do
    begin
      inc(i);
      if CmdLine[i]=' ' then
        begin
          inc(cnt);
          while (i<>len) and (CmdLine[i]=' ') do inc(i);
        end;
    end;
  ParamCount:=cnt;
end;

{********** heap routines **********}

procedure GetMem(var p: pointer; size: dword); 'getmem';
var
  HeapAtom, Previous, NextFree: pointer;
begin
  asm
    mov  eax, dword ptr [P]      { p := nil; }
    mov  dword ptr [eax], 0
    mov  eax, dword ptr [Size]   { if (Size = 0) or (FreeList = nil) then exit }
    cmp  eax, 0
    jz   @1
    mov  ebx, dword ptr [FreeList]
    cmp  ebx, 0
    jz   @1
    add  eax, 7                  { Size := (Size + 7) and $FFFFFFF8 }
    and  eax, $FFFFFFF8
    mov  ecx, 0                  { Previous := nil }
@3:                              { cycle thru FreeList for big enough block }
    cmp  [ebx + 4], eax          { if HeapAtom^.Size >= Size then break }
    {jge @2}
    jae  @2
    mov  ecx, ebx                { no... save HeapAtom as Previous }
    mov  ebx, [ebx]              { HeapAtom := HeapAtom^.Next }
    cmp  ebx, 0                  { if HeapAtom^.Next = nil then exit }
    jz   @1
    jmp  @3
@2:
    mov  edx, eax                { if HeapAtom^.Size >= (Size + 8) then format new block }
    add  edx, 8
    cmp  [ebx + 4],edx           
    {jl   @4}
    jb   @4
    mov  esi, ebx                { NewFree       := HeapAtom + Size }
    add  esi, eax
    mov  edx, [ebx]              { NewFree^.Next := HeapAtom^.Next }
    mov  [esi], edx
    mov  edx, [ebx + 4]          { NewFree^.Size := HeapAtom^.Size - Size }
    sub  edx, eax
    mov  [esi + 4], edx
    jmp  @5
    @4:
    mov  esi, [ebx]                { else  NewFree := HeapAtom^.Next }
    @5:
    mov  eax, dword ptr [FreeList] { if HeapAtom = FreeList then update FreeList }
    cmp  eax, ebx
    jnz  @6
    mov  dword ptr [FreeList], esi { FreeList := NewFree }
    @6:
    cmp  ecx, 0                    { if Previous <> nil then unlink HeapAtom }
    jz   @7
    mov  [ecx], esi                { Previous^.Next := NewFree }
    @7:
    mov  eax, dword ptr [P]        { P := HeapAtom }
    mov  [eax], ebx
    @1:
  end;
end;

procedure FreeMem(var p: pointer; size: dword); 'freemem';
var
  HeapAtom, PrevBlock, NewFree: pointer;
  PrevDist, NextDist: dword;
begin
  asm
    mov  eax, dword ptr [p]         { if (p = nil) or (Size = 0) then exit }
    mov  eax, [eax]
    cmp  eax, 0
    jnz  @1
    jmp  @10
    @1:
    mov  ebx, dword ptr [size]
    { mov  ebx, [ebx]                  is Size a VAR variable? }
    cmp  ebx, 0
    jnz  @2
    jmp  @10
    @2:
    add  ebx, 7                    { Size := (Size + 7) and $FFFFFFF8 }
    and  ebx, 0FFFFFFF8h
    mov  ecx, dword ptr [FreeList] { if FreeList = nil then create new FreeList }
    cmp  ecx, 0
    jnz  @3
    mov  dword ptr [FreeList], eax { FreeList       := p }
    mov  dword ptr [eax], 0        { FreeList^.Next := nil }
    mov  [eax + 4],ebx             { FreeList^.Size := Size }
    mov  eax, dword ptr [p]        { p              := nil }
    mov  dword ptr [eax], 0
    jmp  @10                       { exit }
    @3:
    cmp  ecx,eax                   { if FreeList < p then find last free block < p }
    {jge  @4}
    jae  @4
    mov  dword ptr [HeapAtom], ecx  { HeapAtom  := Freelist }
    mov  dword ptr [PrevBlock], ecx { PrevBlock := FreeList }
    mov  edx,ecx                    { if HeapAtom^.Next <> nil then cycle thru blocks }
    cmp  dword ptr [edx], 0
    jz   @5
    @6:                            { While HeapAtom^.Next < p do move to next block }
    cmp  dword ptr [edx],eax
    {jge  @5}
    jae  @5
    mov  edx,[edx]                 { HeapAtom  := HeapAtom^.Next }
    mov  [PrevBlock],edx           { PrevBlock := HeapAtom }
    cmp  dword ptr [edx],0         { if HeapAtom^.Next = nil then break }
    jz   @5
    jmp  @6
    @5:
    mov  [NewFree], eax            { NewFree         := p }
    mov  edi,[PrevBlock]           { NewFree^.Next   := PrevBlock^.Next }
    mov  esi,[edi]
    mov  [eax], esi
    mov  [eax + 4], ebx            { NewFree^.Size   := Size }
    mov  [edi], eax                { PrevBlock^.Next := NewFree }
    jmp  @7
    @4:                            { else update FreeList as p < FreeList }
    mov  dword ptr [PrevBlock], 0  { PrevBlock     := nil }
    mov  dword ptr [NewFree], eax  { NewFree       := p }
    mov  edi, dword ptr [FreeList] { NewFree^.Next := Freelist }
    mov  [eax], edi
    mov  [eax + 4], ebx            { NewFree^.Size := Size }
    mov  dword ptr [Freelist], eax { FreeList      := NewFree }
    @7:
    mov  eax, dword ptr [NewFree]  { if NewFree^.Next <> nil then merge with next block }
    mov  ebx, [eax]
    cmp  ebx, 0
    jz   @8
    sub  ebx, eax                  { NextDist := NewFree^.Next - NewFree }
    mov  ecx, [eax + 4]            { if NextDist < (NewFree^.Size + 8) then blocks are adjacent }
    add  ecx, 8
    cmp  ebx, ecx
    jge  @8
    {jnz  @8}
    mov  edx, [eax]                { NewFree^.Size := NextDist + NewFree^.Next^.Size }
    add  ebx, [edx + 4]
    mov  [eax + 4], ebx
    mov  edx, [edx]                { NewFree^.Next := NewFree^.Next^.Next }
    mov  [eax], edx
    @8:
    mov  eax, dword ptr [PrevBlock] { if PrevBlock <> nil then merge with last block }
    cmp  eax, 0
    jz   @9
    mov  ebx, [eax]                { PrevDist := PrevBlock^.Next - PrevBlock }
    sub  ebx, eax
    mov  ecx, [eax + 4]            { if PrevDist < (PrevBlock^.Size+8) then blocks are adjacent }
    add  ecx, 8
    cmp  ebx, ecx
    jge  @9
    {jnz  @9}
    mov  edx, [eax]                { PrevBlock^.Size := PrevDist + PrevBlock^.Next^.Size }
    mov  ecx, [edx + 4]
    add  ebx, ecx
    mov  [eax + 4],ebx
    mov  ecx, [edx]                { PrevBlock^.Next := PrevBlock^.Next^.Next }
    mov  [eax], ecx
    @9:
    mov  ebx, dword ptr [p]        { P := nil }
    mov  dword ptr [ebx], 0
    @10:
  end;
end;

procedure HeapInit(var Size: dword); { DB 11/2/98 }
var
  Successful: dword;
begin
  Successful := 0;
  Size       := (Size + 4095) and $FFFFF000; { page align size }
  { Try and allocate memory... }
{$IFDEF DOS32}
  asm
    mov  eax, $0000EE42           { DOS32 fn allocate memory: AX = EE42 }
    mov  edx, dword ptr [Size]
    mov  edx, [edx]               { EDX = Size }
    int  $31                      { int DOS32 }
    jnc  @1                       { carry set if couldn't get requested size }
    jmp  @2
    @1:
    mov  byte ptr [Successful], 1
    mov  ebx, dword ptr [Size]
    mov  [ebx], eax               { store size rounded to nearest 4KB }
    mov  dword ptr [HeapOrg], edx
    @2:
  end;
{$ELSE}

{ $ENDIF}
{ $IFDEF WDOSX}
  asm
    mov  eax, $00000501                { DPMI: Allocate Memory Block } 
    mov  ebx, dword ptr [Size]
    mov  ebx, [ebx]
    push ebx
    pop  cx                            { BX:CX := Size - pop lo }
    pop  bx                            { pop hi }
    int  $31                           { int DPMI }
    jnc  @1
    jmp  @2
    @1:
    mov  byte ptr [Successful], 1      { Successful := true; }
    push si                            { store handle supplied by DPMI host - push hi }
    push di                            { push lo }
    pop  eax
    mov  dword ptr [HeapHandle], eax
    push bx                            { store heap linear base address - push hi }
    push cx                            { push lo }
    pop  eax
    mov  dword ptr [HeapOrg], eax

    mov  eax, $00000006                { DPMI: Get Segment Base Address }
    mov  bx, ds                        { we want to offset from selector DS }
    int  $31                           { int DPMI.  This fn should NEVER fail! }
    push cx                            { 32bit linear base address of segment - push hi }
    push dx                            { push lo }
    pop  eax                           { EAX = program base address }
    neg  eax                           { EAX = start of memory relative to DS }
    add  dword ptr [HeapOrg], eax      { now HeapOrg is relative to DS base address }

    @2:
  end;
{$ENDIF}
  if Successful <> 1 then
    begin
      Writeln('Error allocating heap memory. Aborting.');
      Halt(1);
    end;
  asm
    mov  eax, dword ptr [HeapOrg]     { if HeapOrg = nil then adjust it to next qword boundary }
    mov  ebx, dword ptr [Size]
    mov  ecx, [ebx]
    cmp  eax, 0                       { (HeapOrg cannot point to nil) }
    jnz  @3
    add  eax, 8
    mov  dword ptr [HeapOrg], eax     { HeapOrg := HeapOrg + 8 }
    sub  ecx, 8                       { Size    := Size - 8 }
    mov  [ebx], ecx
    @3:                               { now format memory for use as heap }
    mov  dword ptr [FreeList], eax    { Freelist       := HeapOrg }
    mov  dword ptr [eax], 0           { FreeList^.Next := nil }
    mov  dword ptr [eax+ 4], ecx      { FreeList^.Size := Size }

    add  eax, ecx                     { Point to first byte _after_ heap }
    mov  dword ptr [HeapEnd], eax
  end;
end;

procedure HeapDone; { DB 11/2/98 } { probably not needed as DPMI cleans up memory }
var
  Successful: dword;
begin
  Successful := 0;
{$IFDEF DOS32}
  asm
    mov  eax, $0000EE40               { DOS32 fn free previous memory block: AX = EE40 }
    int  $31
  end;
{$ELSE}

{ $ENDIF}
{ $IFDEF WDOSX}
  asm
    mov  eax, dword ptr [HeapHandle]
    push eax
    pop  di                          { DI:SI = memory handle - pop lo }
    pop  si                          { pop hi }
    mov  eax, $502                   { DPMI: Free Memory Block }
    int  $31                         { int DPMI }
    jc   @ReleaseError
    mov  byte ptr [Successful], 1
    @ReleaseError:
  end;
  if Successful = 0 then
    Writeln('Error releasing heap memory.');
{$ENDIF}
end;

function MemAvail: longint; assembler;
  asm
    xor eax, eax
    mov edx, dword ptr [FreeList]
  @loop:
    or  edx, edx
    jz  @1
    add eax, dword ptr [edx + 4]
    mov edx, dword ptr [edx]
    jmp @loop

  @1:

end;

procedure createobject; assembler; 'createobject';
asm
{
   Parameters:
In:   esi      : address of VMT
Out:  edi      : address of Self
}
   push  eax
   mov   eax, esi                { Load VMT address               }
   push  eax                     { Save VMT address               }
   sub   esp, 4
   mov   esi, esp                { Save contents of esi           }
   push  esi                     { Save esi for later use         }
   push  dword ptr [eax]         { Size of object (stored in VMT) }
   push  esi                     { Contains address on return     }
   call  GetMem
   pop   esi                     { Restore esi                    }
   mov   esi, dword ptr [esi]    { Store address of Self          }
   add   esp, 4                  { Restore stack                  }
   pop   eax                     { Restore VMT address            }
   mov   edi, esi                { Store address of Self          }
   mov   dword ptr [esi], eax    { Set VMT address                }
   pop   eax
end;

procedure destroyobject; assembler; 'destroyobject';
asm
{
   Parameters:
In:   esi      : pointer to address of Self
}
   sub   esp, 4
   mov   edi, esp
   mov   esi, dword ptr [esi]        { Get address of Self      }
   mov   eax, dword ptr [esi]        { Get address of VMT       }
   push  dword ptr [eax]             { Push size                }
   mov   dword ptr [edi], esi        { Save address in temp var }
   push  edi                         { Push address of Self     }
   call  FreeMem
   add   esp, 4
end;

begin
{$IFDEF WDOSX}
  asm {needed for WDOSX, ES normally contains PSP selector, not needed here}
     push  ds
     pop   es
  end;
  asm {initialize zero-selector: FS}
     sub   eax, eax
     mov   cx, 1
     int   $31
     jc    @00
     mov   ebx, eax
     mov   ax, 8
     stc
     sbb   ecx, ecx
     sbb   edx, edx
     int   $31
     jc    @00

     lar   cx, bx
     mov   cl, ch
     and   cl, $60
     or    cl, $92
     mov   ch, $CF
     mov   eax, 9
     int   $31
     jc    @00

     sub   ecx, ecx
     sub   edx, edx
     mov   eax, 7
     int   $31
     jc    @00

     mov   fs, bx
@00:
  end;
{$ENDIF}

{$IFDEF DOS32}
  GetCmdLine(CmdLine);
  asm {initialize zero-selector: FS}
     mov ax, $EE00
     int $31
     mov fs, bx
  end;
{$ENDIF}

  radix:=10;
  {Initialize standard input and output, STDIN/STDOUT}
  assign(input,'');
  TextRec(input).Handle:=0;
  TextRec(input).Mode:=fmInput;
  TextRec(input).InOutFunc:=@text_io;
  TextRec(input).FlushFunc:=@text_io;

  assign(output,'');
  TextRec(output).Handle:=1;
  TextRec(output).Mode:=fmOutput;
  TextRec(output).InOutFunc:=@text_io;
  TextRec(output).FlushFunc:=@text_io;

  InOutRes:=0;

  HeapInit(HeapSize); {HeapSize is defined by the compiler}
end.
{$ENDIF}

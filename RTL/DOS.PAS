unit dos;

{$IFDEF DOS32}
{$ELSE}
{$IFDEF WDOSX}
{$ELSE}
{$ERROR Cannot determine dos extender}
{$ENDIF}
{$ENDIF}

interface

type
  { Registers record used by Intr and MsDos }
  registers = record
                case integer of
                0: (edi, esi, ebp, l1, ebx, edx, ecx, eax: longint);
                1: (di, w1, si, w2, bp, w3, w4, w5, bx, w6, dx, w7, cx, w8, ax, w9,
                    Flags, es, ds, fs, gs, ip, cs, sp, ss: word);
                2: (b1: array [0..15] of Byte;
                    bl, bh, b2, b3, dl, dh, b4, b5, cl, ch, b6, b7, al, ah: byte);
                end;

  DateTime = record
               Year, Month, Day, Hour, Min, Sec: word;
             end;

  ComStr  = string[127];
  PathStr = string[79];
  DirStr  = string[67];
  NameStr = string[8];
  ExtStr  = string[4];

  SearchRec = record
                Fill: array[1..21] of Byte;
                Attr: Byte;
                Time: Longint;
                Size: Longint;
                Name: string[12];
              end;

var
  { Error code value ( 0 - no error ) }
  DosError: integer;

function DosVersion: word;

procedure Intr(IntNo: byte; var regs: registers);
procedure MsDos(var regs: registers);

procedure GetDate(var Year,Month,Day,DayOfWeek: word);
procedure SetDate(Year,Month,Day: word);
procedure GetTime(var Hour,Minute,Second,Sec100: word);
procedure SetTime(Hour,Minute,Second,Sec100: word);

procedure GetCBreak( var BreakStatus: boolean);
procedure SetCBreak( BreakStatus: boolean);

procedure GetVerify(var Verify: boolean);
procedure SetVerify(Verify: boolean);

function DiskFree(Drive: Byte): Longint;
function DiskSize(Drive: Byte): Longint;

procedure FindFirst(Path: PathStr; Attr: Word; var F: SearchRec);
procedure FindNext(var F: SearchRec);

implementation

function DosVersion: word; assembler;
asm
   mov ah, $30
   int $21
end;

procedure Intr(IntNo: byte; var regs: registers); assembler;
asm
   mov   eax, $0300
   movzx ebx, byte ptr [IntNo]
   mov   edi, dword ptr [Regs]
   xor   ecx, ecx
   int   $31
end;

procedure MsDos(var regs: registers); assembler;
asm
   mov   eax, $0300
   mov   ebx, $21
   mov   edi, dword ptr [Regs]
   xor   ecx, ecx
   int   $31
end;

procedure GetDate(var Year,Month,Day,DayOfWeek: word); assembler;
asm
   mov   ah, $2A
   int   $21
   xor   ah, ah
   mov   ebx, dword ptr [DayOfWeek]
   mov   word ptr [ebx], ax
   mov   ebx, dword ptr [Day]
   mov   al, dl
   mov   word ptr [ebx], ax
   mov   ebx, dword ptr [Month]
   mov   al, dh
   mov   word ptr [ebx], ax
   mov   ebx, dword ptr [Year]
   mov   word ptr [ebx], cx
end;

procedure SetDate(Year, Month, Day: word); register; assembler;
asm
   shl   edx,8
   mov   dl, cl
   lea   ecx, [eax - 1980]
   mov   ah, $2B
   int   $21
   movzx eax, al
   mov   word ptr [DosError], ax
end;

procedure GetTime(var Hour,Minute,Second,Sec100: word); assembler;
asm
   mov     ah, $2C
   int     $21
   lea     eax, [Hour]
   ror     ecx, 8
   sub     ch, ch
   mov     word ptr [eax], cx
   lea     eax, [Minute]
   rol     ecx, 8
   sub     ch, ch
   mov     word ptr [eax], cx
   lea     eax, [Second]
   ror     edx, 8
   sub     dh, dh
   mov     word ptr [eax], dx
   lea     eax, [Sec100]
   rol     edx, 8
   sub     dh, dh
   mov     word ptr [eax], dx
end;

procedure SetTime(Hour,Minute,Second,Sec100: word); assembler;
asm
   mov   ch, byte ptr [Hour]
   mov   cl, byte ptr [Minute]
   mov   dh, byte ptr [Second]
   mov   dl, byte ptr [Sec100]
   mov   ah, $21
   int   $21
   movzx eax, al
   mov   word ptr [DosError], ax
end;

procedure GetCBreak(var BreakStatus: boolean); assembler;
asm
   mov   eax, $3300
   int   $21
   mov   edi, dword ptr [BreakStatus]
   mov   byte ptr [edi], dl
end;

procedure SetCBreak(BreakStatus: boolean); assembler;
asm
   mov   eax, $3301
   mov   dl, byte ptr [BreakStatus]
   int   $21
end;

procedure GetVerify(var Verify: boolean); assembler;
asm
   mov   ah, $54
   int   $21
   mov   edi, dword ptr [Verify]
   mov   byte ptr [edi], al
end;

procedure SetVerify(Verify: boolean); assembler;
asm
   mov   ah, $2e
   mov   al, byte ptr [Verify]
   xor   edx, edx
   int   $21
end;

function DiskFree(Drive: byte): longint; assembler;
asm
   mov   ah, $36
   mov   dl, byte ptr [Drive]
   xor   ebx, ebx
   xor   ecx, ecx
   int   $21
   movzx eax, ax
   cmp   ax, $FFFF
   jne   @ok
   mov   word ptr [DosError], ax
@ok:
   mul   ecx
   mul   ebx
end;

function DiskSize(Drive: byte): longint; assembler;
asm
   push  ds
   xor   edx, edx
   mov   dl, byte ptr [Drive]
   xor   ecx, ecx
   mov   ah, $1C
   int   $21
   pop   ds
   movzx eax, al
   cmp   al, $ff
   jnz   @ok
   mov   word ptr [DosError],ax
@ok:
   mul   edx
   mul   ecx
end;

procedure FindFirst(Path: PathStr; Attr: Word; var F: SearchRec);
var buf : array[0..255] of char;

begin
  ASCIIZ(Path, @buf);
  asm
     lea   edx, [buf]
     movzx ecx, word ptr [Attr]
     mov   ah, 4Eh
     int   21h
  end;
end;

procedure FindNext(var F: SearchRec);
begin
end;


begin
  DosError:=0;
end.

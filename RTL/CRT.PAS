{                         P32 - 32bit Pascal Compiler                        }
{ -------------------------------------------------------------------------- }
{                       Johan Prins - jprins@knoware.nl                      }
{ ========================================================================== }
{                                                                            }
{ CRT-unit                                                                   }
{                                                    (c) Copyright 1998-1999 }
{                                                                            }
{ -------------------------------------------------------------------------- }
{ Some code copied from: CRT.PAS (c) 1996 Michael Tippach                    }
{ -------------------------------------------------------------------------- }

unit crt;


interface

const

  BW40          = 0;
  CO40          = 1;
  BW80          = 2;
  CO80          = 3;
  Mono          = 7;
  Font8x8       = 256;

{ Foreground and background color constants }

  Black         = 0;
  Blue          = 1;
  Green         = 2;
  Cyan          = 3;
  Red           = 4;
  Magenta       = 5;
  Brown         = 6;
  LightGray     = 7;

{ Foreground color constants }

  DarkGray      = 8;
  LightBlue     = 9;
  LightGreen    = 10;
  LightCyan     = 11;
  LightRed      = 12;
  LightMagenta  = 13;
  Yellow        = 14;
  White         = 15;
  Blink         = 128;

var
   CheckBreak,
   CheckEOF,
   DirectVideo,
   CheckSnow    : boolean;

   TextAttr     : byte;

   WindMin,
   WindMax,
   LastMode     : word;

procedure TextMode(mode: integer);
procedure Window(x1, y1, x2, y2: byte);
procedure GotoXY(x, y: integer);
procedure ClrScr;
procedure ClrEol;
procedure InsLine;
procedure DelLine;
procedure TextColor(color: byte);
procedure TextBackground(color: byte);
procedure LowVideo;
procedure HighVideo;
procedure NormVideo;
procedure NoSound;
procedure Sound(Hz: word);
procedure AssignCrt(var t: text);
procedure Delay(ms: word);

function WhereX: byte;
function WhereY: byte;
function KeyPressed: boolean;
function ReadKey: char;

implementation

const
   ScanCode: char = #0;

var
   NormAttr       : byte;
   CurrentCrtSize : word;

procedure CrtFillVars; assembler;
asm
   mov   ah, 0Fh
   int   10h
   push  eax
   push  ebp
   mov   eax, 1130h
   mov   bh, 0
   mov   dl, 0
   int   10h
   pop   ebp
   pop   eax
   mov   cl, 0
   or    dl, dl
   jne   @1
   mov   dl, 24
   cmp   al, 3
   ja    @1
   mov   cl, 1
@1:
   mov   dh, dl
   mov   dl, ah
   dec   dl
   mov   ah, 0
   cmp   dh, 24
   jbe   @2
   mov   ah, 1
@2:
   mov   word ptr [LastMode], ax
   mov   word ptr [CurrentCrtSize], dx
   mov   byte ptr [CheckSnow], cl
   mov   byte ptr [DirectVideo], 1
   xor   eax, eax
   mov   word ptr [WindMin], ax
   mov   word ptr [WindMax], dx
end;

procedure CrtSet(mode:word); assembler;

asm
   mov   ax, word ptr [mode]
   and   byte ptr fs:[0400h + 0087h], 0FEh
   cmp   al, 7
   je    @1
   cmp   al, 4
   jb    @1
   mov   al, 3
@1:
   push  eax
   mov   ah, 0
   int   10h
   pop   eax
   or    ah, ah
   je    @2
   push  ebp
   mov   eax, 1112h
   mov   bl, 0
   int   10h
   mov   eax, 1130h
   mov   bh, 0
   mov   dl, 0
   int   10h
   pop   ebp
   cmp   dl, 42
   jne   @2
   or    byte ptr fs:[0400h + 0087h], 1
   mov   eax, 0100h
   mov   ecx, 0600h
   int   10h
   mov   ah, 12h
   mov   bl, 20h
   int   10h
@2:
end;


function KeyPressed: boolean; assembler;
asm
   cmp   byte ptr [ScanCode], 0
   jne   @1
   mov   ah, 1
   int   16h
   mov   al, 0
   je    @2
@1:
   mov   al, 1
@2:
end;

function ReadKey: char; assembler;
asm
   mov   al, byte ptr [ScanCode]
   mov   byte ptr [ScanCode], 0
   test  al, al
   jnz   @1
   xor   ah, ah
   int   16h
   test  al, al
   jnz   @1
   mov   byte ptr [ScanCode], ah
@1:
end;

procedure GotoXY(x, y: integer); assembler;
asm
   mov   dl, byte ptr [x]
   mov   dh, byte ptr [y]
   dec   dl
   add   dl, byte ptr [WindMin]
   jc    @1
   cmp   dl, byte ptr [WindMax]
   ja    @1
   dec   dh
   add   dh, byte ptr [WindMin+1]
   jc    @1
   cmp   dh, byte ptr [WindMax+1]
   ja    @1

   mov   ah, 2    {Set cursor position}
   xor   bh, bh
   int   10h
@1:
end;

function WhereX: byte; assembler;
asm
   mov   ah, 3
   xor   bh, bh
   int   10h
   sub   dl, byte ptr [WindMin]
   inc   dl
   movzx eax, dl
end;

function WhereY: byte; assembler;
asm
   mov   ah, 3
   xor   bh, bh
   int   10h
   sub   dh, byte ptr [WindMin + 1]
   inc   dh
   movzx eax, dh
end;

procedure HighVideo;
begin
  TextAttr:=TextAttr or 8;
end;

procedure LowVideo;
begin
  TextAttr:=TextAttr and $F7;
end;

procedure NormVideo;
begin
  TextAttr:=NormAttr;
end;

procedure Delay(ms: word); assembler;
asm
   sub   ecx, ecx
   movzx edx, word ptr [ms]
   shl   edx, 10
   shld  ecx, edx, 16
   mov   ah, 86h
   int   15h
end;

procedure NoSound; assembler;
asm
   in    al, 61h
   and   al, 0FCh
   out   61h, al
end;

procedure Sound(Hz:word);
begin
  if Hz > 18 then 
    asm
       movzx ecx, word ptr [Hz]
       mov   eax, 1193180
       xor   edx, edx
       div   ecx
       mov   ecx,eax
       mov   al, 182
       out   43h, al
       mov   al, cl
       out   42h, al
       mov   al, ch
       out   42h, al
       in    al, 61h
       or    al, 3
       out   61h, al
    end;
end;

procedure TextBackground(color:byte); assembler;
asm
   mov   al, byte ptr [TextAttr]
   mov   ah, byte ptr [Color]
   and   al, 8Fh
   and   ah, 7
   shl   ah, 4
   or    al, ah
   mov   byte ptr [TextAttr], al
end;

procedure TextColor(color:byte); assembler;
asm
   mov   al, byte ptr [Color]
   test  al, 0F0h
   je    @1
   and   al, 0Fh
   or    al, 80h
@1:
   and   byte ptr [TextAttr], 70h
   or    byte ptr [TextAttr], al
end;

procedure TextMode(mode: integer);
begin
  CrtSet(mode);
  CrtFillVars;
  TextAttr:=NormAttr;
end;

procedure ClrEol; assembler;
asm
   mov   ah, 3
   xor   bh, bh
   int   10h

   mov   eax, 0600h
   mov   bh, byte ptr [TextAttr]
   mov   cx, dx
   mov   dl, byte ptr [WindMax]
   int   10h
end;

procedure InsLine; assembler;
asm
   mov   eax, 0701h
   push  eax
   mov   ah, 3
   xor   bh, bh
   int   10h
   pop   eax

   mov   bh, byte ptr [TextAttr]
   mov   cl, byte ptr [WindMin]

   mov   ch, dh
   mov   dx, word ptr [WindMax]
   cmp   ch, dh
   jne   @1
   xor   al, al
@1:
   int   10h
end;

procedure DelLine; assembler;
asm
   mov   eax, 0601h
   push  eax
   mov   ah, 3
   xor   bh, bh
   int   10h
   pop   eax

   mov   bh, byte ptr [TextAttr]
   mov   cl, byte ptr [WindMin]

   mov   ch, dh
   mov   dx, word ptr [WindMax]
   cmp   ch, dh
   jne   @1
   xor   al, al
@1:
   int   10h
end;

procedure Window(x1, y1, x2, y2: byte); assembler;
asm
   mov   dl, byte ptr [x1]
   mov   dh, byte ptr [y1]
   mov   cl, byte ptr [x2]
   mov   ch, byte ptr [y2]
   cmp   dl, cl
   ja    @1
   cmp   dh, ch
   ja    @1
   dec   dl
   js    @1
   dec   dh
   js    @1
   dec   cl
   cmp   cl, byte ptr [CurrentCrtSize]
   ja    @1
   dec   ch
   cmp   ch, byte ptr [CurrentCrtSize+1]
   ja    @1
   mov   word ptr [WindMin], dx
   mov   word ptr [WindMax], cx

   mov   ah, 2    {Set cursor position}
   xor   bh, bh
   int   10h
@1:
end;

procedure ClrScr; assembler;
asm
   mov   eax, 0600h
   mov   bh, byte ptr [TextAttr]
   mov   cx, word ptr [WindMin]
   mov   dx, word ptr [WindMax]
   int   10h

   mov   dx, word ptr [WindMin]
   mov   ah, 2    {Set cursor position}
   xor   bh, bh
   int   10h
end;

procedure Initialize;
var mode: word;

begin
  asm
     mov   ah, 0Fh
     int   10h
     cmp   al, 7
     je    @1
     cmp   al, 4
     jb    @1
     mov   ax, 3
     push  eax
     call  CrtSet
@1:
     call  CrtFillVars
     mov   ah, 8
     xor   bh, bh
     int   10h
     mov   al, ah
     and   al, 7Fh
     mov   byte ptr [NormAttr], al
     mov   byte ptr [TextAttr], al
  end;
  CheckEOF:=FALSE;
  CheckBreak:=TRUE;
end;

procedure crt_io(var t: TextRec);

begin
  if (t.Mode=fmOutput) and (t.BufPos<>0) then
    begin
       asm
          mov   eax, dword ptr [ebp + 8]
          mov   ecx, dword ptr [eax + 12]
          mov   edi, dword ptr [eax + 20]

          cmp   byte ptr [DirectVideo], 1
          jz    @direct
   @bios:
          mov   al, byte ptr [edi]

          push  ecx
          push  eax
          mov   ah, 3
          xor   bh, bh
          int   10h    {get cursor position}
          pop   eax

          cmp   al, 7  {bell}
          je    @1
          cmp   al, 8  {backspace}
          je    @2
          cmp   al, 13 {carriage return}
          je    @3
          cmp   al, 10 {linefeed}
          je    @4

          push  edx
          mov   ah, 9
          mov   bl, byte ptr [TextAttr]
          xor   bh, bh
          mov   cx, 1
          int   10h
          pop   edx

          inc   dl
          cmp   cl, byte ptr [WindMax]
          jbe   @5
          mov   dl, byte ptr [WindMin]
          jmp   @4

       @1:
          mov   ah, 14
          int   10h
          jmp   @5
       @2:
          cmp   dl, byte ptr [WindMin]
          je    @5
          dec   dl
          jmp   @5
       @3:
          mov   dl, byte ptr [WindMin]
          jmp   @5
       @4:              {do linefeed}
          inc   dh
          cmp   dh, byte ptr [WindMax+1]
          jbe   @5
          dec   dh
          push  edx
          mov   eax, 0601h
          mov   bh, byte ptr [TextAttr]
          mov   cx, word ptr [WindMin]
          mov   dx, word ptr [WindMax]
          int   10h
          pop   edx
       @5:
          mov   ah, 2    {Set cursor position}
          xor   bh, bh
          int   10h

          pop   ecx
          inc   edi
          dec   ecx
          jnz   @bios
          jmp   @exit

  @direct:
          movzx edx, word ptr fs:[0400h+50h] {cursor position}
          mov   ebx, edx
          mov   esi, edi
@11:
          mov   al, byte ptr [edi]

          cmp   al, 7  {bell}
          je    @12
          cmp   al, 8  {backspace}
          je    @13
          cmp   al, 13 {carriage return}
          je    @14
          cmp   al, 10 {linefeed}
          je    @15

          inc   edi
          inc   dl
          cmp   dl, byte ptr [WindMax]
          jbe   @18
          call  @writedirect
          inc   dh
          cmp   dh, byte ptr [WindMax+1]
          jbe   @15
          dec   dh
          push  ecx
          push  edx
          mov   eax, 0601h
          mov   bh, byte ptr [TextAttr]
          mov   cx, word ptr [WindMin]
          mov   dx, word ptr [WindMax]
          int   10h
          pop   edx
          pop   ecx

          mov   dl, byte ptr [WindMin]
          jmp   @17

      @12:
          call  @writedirect
          push   ecx
          push   edx
          mov    ax, 1407h
          int    10h
          pop    edx
          pop    ecx
          jmp    @16
      @13:
          call  @writedirect
          cmp   dl, byte ptr [WindMin]
          je    @16
          dec   dl
          jmp   @16
      @14:
          call  @writedirect
          inc   dh
          cmp   dh, byte ptr [WindMax+1]
          jbe   @15
          dec   dh
          push  ecx
          push  edx
          mov   eax, 0601h
          mov   bh, byte ptr [TextAttr]
          mov   cx, word ptr [WindMin]
          mov   dx, word ptr [WindMax]
          int   10h
          pop   edx
          pop   ecx
          jmp   @16
      @15:
          call  @writedirect
          mov   dl, byte ptr [WindMin]
      @16:
          inc   edi
      @17:
          mov   esi, edi
          mov   ebx, edx
      @18:
          dec   ecx
          jnz   @11

          call  @writedirect
          mov   word ptr fs:[0400h+50h], dx {cursor position}
          mov   al, dh
          mul   word ptr fs:[0400h+4Ah]     {crt width}
          xor   dh, dh
          add   ax, dx
          movzx ecx, ax

          mov   dx, word ptr fs:[0400h+63h]  {address of video chip}
          mov   al, 14
          out   dx, al
          nop
          nop
          nop
          mov   al, ch
          inc   dx
          out   dx, al
          nop
          nop
          nop
          dec   dx
          mov   al, 15
          out   dx, al
          nop
          nop
          nop
          mov   al, cl
          inc   dx
          out   dx, al
          jmp   @exit

@writedirect:
{ BX = cursor position
  ESI = string start
  EDI = String end}
          movzx ebx, bx
          cmp   esi, edi
          je    @28

          push  ecx
          push  edx
          push  edi

          push  es

          push  fs
          pop   es

          mov   ecx, edi
          sub   ecx, esi

          movzx eax, bh
          mul   word ptr fs:[0400h+4Ah]     {crt width}
          xor   bh, bh
          add   eax, ebx
          shl   eax, 1
          mov   edi, eax

          mov   dx, word ptr fs:[0400h+63h]  {address of video chip}
          add   dx, 6
          cmp   word ptr fs:[0400h+49h], 7
          mov   eax, 0B8000h
          jne   @21
          mov   eax, 0B0000h
@21:
          mov   bl, byte ptr [CheckSnow]
          mov   bh, byte ptr [TextAttr]

          add   edi, eax
          cld   ;

          or    bl, bl
          je    @25
@22:                   {check for snow}
          lodsb ;
          mov   bl, al
@23:
          in    al, dx
          test  al, 1
          jne   @23
          cli   ;
@24:
          in    al, dx
          test  al, 1
          je    @24

          mov   eax, ebx
          stosw ;
          sti   ;
          loop  @22
          jmp   @27
@25:
          mov   ah, bh
@26:
          lodsb ;
          stosw ;
          loop  @26
@27:
          pop   es

          pop   edi
          pop   edx
          pop   ecx
@28:
          ret   ;
@exit:
       end;
    end;
 t.BufPos:=0;
 end;

procedure AssignCrt(var t: text);

begin
  TextRec(t).InOutFunc:=@crt_io;
  TextRec(t).FlushFunc:=@crt_io;
end;

begin
  Initialize;
  AssignCrt(Output);
{ AssignCrt(Input);}
end.
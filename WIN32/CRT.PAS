{                         P32 - 32bit Pascal Compiler                        }
{ -------------------------------------------------------------------------- }
{                       Johan Prins - jprins@knoware.nl                      }
{ ========================================================================== }
{                                                                            }
{ CRT-unit                                                                   }
{                                                         (c) Copyright 1998 }
{                                                                            }
{ -------------------------------------------------------------------------- }
{ Some code copied from: CRT.PAS (c) 1996 Michael Tippach                    }
{ -------------------------------------------------------------------------- }

unit crt;

{$DEFINE CONSOLEAPP}

interface

uses windows;

const
  BW40          = 0;
  CO40          = 1;
  BW80          = 2;
  CO80          = 3;
  Mono          = 7;
  Font8x8       = 256;

{ Win32 colors }
  FOREGROUND_BLUE      = $0001; { text color contains blue }
  FOREGROUND_GREEN     = $0002; { text color contains green }
  FOREGROUND_RED       = $0004; { text color contains red }
  FOREGROUND_INTENSITY = $0008; { text color is intensified }
  BACKGROUND_BLUE      = $0010; { background color contains blue }
  BACKGROUND_GREEN     = $0020; { background color contains green }
  BACKGROUND_RED       = $0040; { background color contains red }
  BACKGROUND_INTENSITY = $0080; { background color is intensified }

{ Foreground and background color constants }

  Black         = 0;
  Blue          = FOREGROUND_BLUE;
  Green         = FOREGROUND_GREEN;
  Cyan          = FOREGROUND_GREEN or FOREGROUND_BLUE;
  Red           = FOREGROUND_RED;
  Magenta       = FOREGROUND_RED or FOREGROUND_BLUE;
  Brown         = FOREGROUND_RED or FOREGROUND_GREEN;
  LightGray     = FOREGROUND_RED or FOREGROUND_GREEN or FOREGROUND_BLUE;

{ Foreground color constants }

  DarkGray      = FOREGROUND_INTENSITY;
  LightBlue     = Blue or FOREGROUND_INTENSITY;
  LightGreen    = Green or FOREGROUND_INTENSITY;
  LightCyan     = Cyan or FOREGROUND_INTENSITY;
  LightRed      = Red or FOREGROUND_INTENSITY;
  LightMagenta  = Magenta or FOREGROUND_INTENSITY;
  Yellow        = Brown or FOREGROUND_INTENSITY;
  White         = LightGray or FOREGROUND_INTENSITY;
  Blink         = BACKGROUND_INTENSITY;

var
   CheckSnow, DirectVideo, { not used only declared by means of compatibility }
   CheckBreak,
   CheckEOF     : boolean;

   TextAttr     : byte;

   WindMin,
   WindMax,
   LastMode     : word;

procedure TextMode(mode: integer);
procedure Window(x1, y1, x2, y2: byte);

function KeyPressed: boolean;
function ReadKey: char;

procedure ClrScr;
procedure InsLine;
procedure DelLine;

procedure GotoXY(x, y:byte); 
function WhereX: byte;
function WhereY: byte;

procedure HighVideo;
procedure LowVideo;
procedure NormVideo;

procedure Delay(ms: word);
procedure NoSound;
procedure Sound(Hz:word);

procedure TextBackground(Color:byte);
procedure TextColor(Color:byte);

implementation

{uses windows;}

var
   ScanCode : char;
   CurrentPage,
   NormAttr : byte;
   CurrentCrtSize : word;
   SpecialKey : boolean;
   AttrInfo : CONSOLE_SCREEN_BUFFER_INFO;

procedure TextMode(mode: integer);
begin
  {dummy}
end;

function KeyPressed : boolean;
var nevents, nread, i: dword;
    buf: INPUT_RECORD;
begin
  KeyPressed := FALSE;
  if ScanCode <> #0 then 
    KeyPressed := TRUE
  else begin
    GetNumberOfConsoleInputEvents(TextRec(input).Handle,@nevents);
if nevents > 0 then
    For i := 1 to nevents do begin
      ReadConsoleInputA(TextRec(input).Handle,@buf,1,@nread);
      if buf.EventType = KEY_EVENT then
        if buf.KeyEvent.bKeyDown = 0 then begin
          KeyPressed := TRUE;
          if buf.KeyEvent.AsciiChar = 0 then begin
            SpecialKey := TRUE;
            ScanCode := Chr(Ord(buf.KeyEvent.wVirtualScanCode));
          end
          else begin
            SpecialKey := FALSE;
            ScanCode := Chr(Ord(buf.KeyEvent.AsciiChar));
          end;
          break;
        end;
    end;
  end;
end;

function ReadKey: char;
begin
  repeat until KeyPressed;
  if SpecialKey then begin
    ReadKey := #0;
    SpecialKey := FALSE;
  end
  else begin
    ReadKey := ScanCode;
    ScanCode := #0;
  end;
end;

procedure ClrScr;
var TopCoords : COORD; 
    ScrollRect : SMALL_RECT;
    FillAttr : CHAR_INFO;
    I : Word;
begin
{ --- The assembler code below is equivalent to: --- 
  TopCoords.X := WindMin and $FF; 
  TopCoords.Y := ((WindMin and $FF00) shr 8) + 1; 
  ScrollRect.Left := TopCoords.X;
  ScrollRect.Top := Pred(TopCoords.Y);
  ScrollRect.Right := WindMax and $FF;
  ScrollRect.Bottom := (WindMax and $FF00) shr 8;
  FillAttr.FillChar := ' ';
  FillAttr.Attributes := TextAttr;
}
  asm
    xor ebx,ebx
    mov ax, [WindMin]
    mov bl,al
    mov [TopCoords.X], bx
    mov [ScrollRect.Left], bx
    mov bl,ah
    mov [ScrollRect.Top], bx
    inc bl
    mov [TopCoords.Y], bx
    mov ax, [WindMax]
    mov bl,al
    mov [ScrollRect.Right], bx
    mov bl,ah
    mov [ScrollRect.Bottom], bx
    movzx ecx, bx
    mov bl, [TextAttr]
    mov word ptr [FillAttr.Attributes], bx
    mov word ptr [FillAttr.FillChar], 32
    movzx edx, word ptr [ScrollRect.Top]
    sub ecx, edx
    jl @2
@1:
    push ecx
  end;
{ For I := ScrollRect.Top to ScrollRect.Bottom do }
    ScrollConsoleScreenBufferA(TextRec(output).Handle, ScrollRect, ScrollRect, TopCoords.WholeCoord, FillAttr);
  asm
    pop ecx
    dec ecx
    jge @1
@2:
  end;
  Dec(TopCoords.Y);
  SetConsoleCursorPosition(TextRec(output).Handle,TopCoords.WholeCoord);
end;

procedure InsLine;
var TopCoords : COORD; 
    ScrollRect : SMALL_RECT;
    FillAttr : CHAR_INFO;
begin
  ScrollRect.Left := WindMin and $FF;
  ScrollRect.Top := WhereY - 1;
  ScrollRect.Right := WindMax and $FF;
  ScrollRect.Bottom := (WindMax and $FF00) shr 8;
  TopCoords.X := ScrollRect.Left; 
  TopCoords.Y := Succ(ScrollRect.Top); 
  FillAttr.FillChar := ' ';
  FillAttr.Attributes := TextAttr;
  ScrollConsoleScreenBufferA(TextRec(output).Handle, ScrollRect, ScrollRect, TopCoords.WholeCoord, FillAttr);
end;

procedure DelLine;
var TopCoords : COORD; 
    ScrollRect : SMALL_RECT;
    FillAttr : CHAR_INFO;
begin
  ScrollRect.Left := WindMin and $FF;
  ScrollRect.Top := WhereY;
  ScrollRect.Right := WindMax and $FF;
  ScrollRect.Bottom := (WindMax and $FF00) shr 8;
  TopCoords.X := ScrollRect.Left;
  TopCoords.Y := Pred(ScrollRect.Top); 
  FillAttr.FillChar := ' ';
  FillAttr.Attributes := TextAttr;
  ScrollConsoleScreenBufferA(TextRec(output).Handle, ScrollRect, ScrollRect, TopCoords.WholeCoord, FillAttr);
end;

procedure GotoXY(x, y : byte); 
var mycoords : COORD;
begin
{ --- The assembler code below is equivalent to: --- 
  x := Pred(x) + (WindMin and $FF);
  y := Pred(y) + ((WindMin and $FF00) shr 8);
  If (x > (WindMax and $FF)) or (y > ((WindMax and $FF00) shr 8)) Then Exit;
  mycoords.x := x;
  mycoords.y := y;
}
 asm
   xor   ebx, ebx
   mov   ax, [WindMin]
   mov   dl, byte ptr [x]
   mov   dh, byte ptr [y]
   dec   dl
   dec   dh
   mov   bl,dl 
   mov   [mycoords.X], bx
   mov   bl,dh
   mov   [mycoords.Y], bx
   add   dl, al
   add   dh, ah
   mov   ax, [WindMax]
   cmp   dl, al
   ja    @1
   cmp   dh, ah
   ja    @1
 end;
 SetConsoleCursorPosition(TextRec(output).Handle,mycoords.WholeCoord);
 asm
@1:
 end;
end;

function WhereX: byte;
var CursorInfo : CONSOLE_SCREEN_BUFFER_INFO;
begin
  GetConsoleScreenBufferInfo(TextRec(output).Handle,@CursorInfo);
  WhereX := CursorInfo.dwCursorPosition.X +1 + (WindMin and $FF);
end;

function WhereY: byte;
var CursorInfo : CONSOLE_SCREEN_BUFFER_INFO;
begin
  GetConsoleScreenBufferInfo(TextRec(output).Handle,@CursorInfo);
  WhereY := CursorInfo.dwCursorPosition.Y +1 + ((WindMin and $FF00) shr 8);
end;

procedure HighVideo;
begin
  TextAttr:=TextAttr or 8;
  SetConsoleTextAttribute(TextRec(output).Handle,TextAttr);
end;

procedure LowVideo;
begin
  TextAttr:=TextAttr and $F7;
  SetConsoleTextAttribute(TextRec(output).Handle,TextAttr);
end;

procedure NormVideo;
begin
  TextAttr:=NormAttr;
  SetConsoleTextAttribute(TextRec(output).Handle,TextAttr);
end;

procedure Delay(ms: word);
begin
  Sleep(ms);
end;

procedure NoSound; assembler;
asm
   in    al, $61
   and   al, $FC
   out   $61, al
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
       out   $43, al
       mov   al, cl
       out   $42, al
       mov   al, ch
       out   $42, al
       in    al, $61
       or    al, 3
       out   $61, al
    end;
end;

procedure TextColor(color: byte);
begin
  TextAttr := (TextAttr and $F0) or color;
  SetConsoleTextAttribute(TextRec(output).Handle,TextAttr);
end;

procedure TextBackground(color: byte);
begin
{  TextAttr := (TextAttr and $0F) or (color shl 4); }
  asm
    movzx     eax, byte ptr [TextAttr]
    and       eax, 15
    movzx     edx, byte ptr [color]
    shl       edx, 4
    or        edx, eax
    mov       byte ptr [TextAttr], dl
  end;
  SetConsoleTextAttribute(TextRec(output).Handle,TextAttr);
end;

procedure Window(x1, y1, x2, y2: byte);
begin
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
 end;
 GotoXY(1,1);
 asm
@1:
 end;
end;

procedure crt_io(var t: TextRec);
var BytesWritten, BytesRead: DWORD;
begin
  case t.Mode of
  fmInOut, fmOutput : WriteConsoleA(t.Handle, t.BufPtr, t.BufPos, BytesWritten, 0);
  fmInput           : t.BufEnd:=ReadConsoleA(t.Handle, t.BufPtr, t.BufSize, BytesRead, 0);
  else       Halt(100);
  end;
  t.BufPos := 0;
end;

procedure AssignCrt(var t: text);
begin
  TextRec(t).InOutFunc:=@crt_io;
  TextRec(t).FlushFunc:=@crt_io;
end;

begin
  SpecialKey := False;
  ScanCode := #0;
 
  CheckBreak := True;
  CheckEOF := False;

  WindMin := $0000;
  WindMax := $184F;
  CurrentCrtSize := $184F;

  GetConsoleScreenBufferInfo(TextRec(output).Handle,@AttrInfo);

{  TextAttr := AttrInfo.wAttributes;}
  asm
    mov ax,[AttrInfo.wAttributes]
    mov [TextAttr], al
  end;
  AssignCrt(Output);
end.


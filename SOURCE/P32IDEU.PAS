(****************************************************************************

              P32IDEU - 32bit Pascal Compiler with IDE

 ---------------------------------------------------------------------------
                   Michael Goddard - magnesium@hehe.com (IDE)
                       Johan Prins - jprins@knoware.nl (P32)
 ==========================================================================
 IDE Code unit                                                P32IDE (c)'99
 http://surf.to/p32
 --------------------------------------------------------------------------

 Type inheritance tree
 ---------------------

  WindowType
   |
   +-- DialogWindowType
   |   |
   |   +-- MessageBox
   |   |   |
   |   |   +-- AboutDialog
   |   |   +-- ErrMsgDialog
   |   |   +-- InformationDialog
   |   |
   |   |
   |   +-- ASCIIDialog
   |
   |
   |
   +-- TextWindow
           |
           + SourceWindow
           |
           + HelpWindow (Not done yet)

 Object Structure
-------------------

  IDE_Desktop                  (1 Object)
  |
  +-- IDE_WindowType           (x Number of Windows, type above)
      |
      +-- IDE_ItemBaseType     (x Number of items)
          |
          +-- Button
          |
          +-- IDE_CheckBoxType
          |
          +-- ScrollBar

  Method calls are passed down the tree to the active object that uses
 them, like KeyEvent or Paint.

*)

unit P32IDEU;

interface

uses P32_Vesa, objects;

const
   P32IDE_Ver  = 'v0.38';              { Current IDE version           }
   Tab = #9;                           { key definitions               }
   Lf  = #10;
   Cr  = #13;
   Bs  = #8;
   Esc = #27;

type
   LPtr       = ^LineRec;
   LineRec    = record
                  prev,
                  next      : LPtr;    { pointer to previous/next line }
                  data      : string;  { contains line                 }
                  selection : boolean; { TRUE when there's a selection }
                  sBegin,              { start of selection (pos)      }
                  sEnd      : byte;    { end of selection              }
                end;
var
   FileString   : string;              { filename passed on cmdline    }
   Modes        : PAMode;              { available video modes         }
   VideoMode    : AMode;               { active video mode             }
   TextSegment  : Word;                { address of video memory       }

   IDE: record  {- IDE variables and things like colours -}
         Width, Height: integer; { screenwidth and -height }
         Quit: Boolean;
         TabSize: Byte;
         SmartTab: Boolean;
         SyntaxHighlight: Boolean;
         BlockHighlight: Boolean;
         DoubleClick: Longint; {- miliseconds for doubleclick -}
         NestComment: Boolean;
         c: Record
              Error,
              BlockHi,
              BlockSel,
              Button,
              ButtonH: Integer;
              Syntax: Record
                        none,
                        Comment,
                        Reserved,
                        Reserved2,
                        Identifiers,
                        Symbols,
                        Strings,
                        Numbers,
                        AsmSrc: Integer;
                      end;
            end;
         P32: record
                nNoname: Longint;
                Noname : string[8];
                Ext    : string[3];
              end;
         end;
  clipboard  : record
                 firstln, endln: Lptr;
               end;


{+--------------------------------------------------------------------------+}
{|                                                                          |}
{|    Desktop Object Definitions                                            |}
{|                                                                          |}
{+--------------------------------------------------------------------------+}

type
  KeyType = record
              Shift, Ctrl, Alt: Boolean;
              ch, s: char;
            end;

const tMenuMax = 10;
      tSubMenuMax = 22;
type
  pMenuType = ^MenuType;
  MenuType  = record {info for pulldown menu's}
                NameSt : string[20];
                HelpSt : string[70];
                Accel  : KeyType;
                cItem  : Integer;
                SubMenu: array[0..tSubMenuMax] of record
                                                    NameSt: string[40];
                                                    Accel: KeyType;
                                                    ID: Word;
                                                    HelpSt: string[70];
                                                  end;
              end;

 IDE_DesktopType = object
                     IDE_BottomHelpST: string;
                     Menu_cItem: Word; {- 0 = NoneSelected else Selected -}
                     cSubMenu: record
                                 nItem: Word; {number of items}
                                 sX, eX: Integer; {Start-X & EndX}
                               end;

                     tMenu: array[1..tMenuMax] of MenuType;

                     tWin: tCollection;
                     DontDrawNext_B: Boolean;

                     constructor Init;
                     destructor Done;
                     procedure Paint;
                     procedure QuickPaint;
                     procedure MenuPaint;
                     procedure ProcessMouseEvent;
                     procedure ProcessKeyEvent;
                     procedure MenuHandler(cKey: KeyType; mX, mY: Integer;mLeft, mMiddle, mRight: Boolean);
                     procedure IDE_BottomHelp(St: string);
                     procedure DontDrawNext;
                   end;

var
 IDE_Desktop: ^IDE_DesktopType;


const
 cm_Exit        = $0001;

 cm_NewEdit     = $1000;  { These are used to call whatever code does them }
 cm_OpenEdit    = $1001;
 cm_LoadEdit    = $1002;
 cm_SaveEdit    = $1003;
 cm_SaveAsEdit  = $1004;
 cm_LoadFile    = $1005; {- LoadEdit on the first window -}

 cm_Cut         = $2001;
 cm_Copy        = $2002;
 cm_Paste       = $2003;
 cm_Clear       = $2004;
 cm_Clipboard   = $2005;

 cm_Find        = $3000;
 cm_Replace     = $3001;
 cm_SearchAgain = $3002;

 cm_DOSShell    = $6002;
 cm_AboutWindow = $6003;

 cm_Compile     = $5000;
 cm_Build       = $5001;
 cm_Run         = $5002;
 cm_Link        = $5003;
 cm_InfoBOX     = $500F;

 cm_AsmWindow   = $6000;

 cm_UserScreen  = $7000;
 cm_UserWindow  = $7001;
 cm_ASCIIWin    = $7002;

 cm_CompOptions = $8000;
 cm_EditOptions = $8001;

procedure ShowERROR(nLine: Longint;St: String);
procedure ProcessEvents;
procedure IDE_Init;
procedure IDE_Done;
procedure CompileStatus_NewFile(St: String);
procedure CompileStatus_cLineSet(l: Longint);
procedure cmSend(cm: word);
procedure SetVideoMode(Width, Height: integer);

implementation

uses Dos, Crt, MMouse,
     P32_cpuf, P32_err, P32, P32_cfg, P32_asm, P32_scan, P32_symb, P32_code, P32_prep;

procedure beep;
begin;
  sound(523);
  delay(5);
  nosound;
end;

procedure Beep2;
begin;
  sound(1000);
  delay(5);
  nosound;
end;

const
 IDE_cDesktop  = $89;

 IDE_cMenu     = $70;
 IDE_cMenuH    = $24;
 IDE_aMenu     = IDE_cMenuH shl 8 + IDE_cMenu;

 IDE_cWinFrame = $1F;
 IDE_cWinIcon  = $1A;
 IDE_cWinSize  = $1A;
 IDE_cWinSlide = $31;
 IDE_cWinBack  = $17;

 IDE_cDWinBack  = $7F;
 IDE_cDWinFrame = $7F;
 IDE_cDWinIcon  = $7A;
 IDE_cDWinSize  = $7A;
 IDE_cDWinSlide = $3A;

 Centered       = $FF;

Const
 NoKey   : KeyType =(Shift:False;Ctrl:False;Alt:False; ch:#0 ; s:#0 );
 Space   : KeyType =(Shift:False;Ctrl:False;Alt:False; ch:' '; s:#0 );
 CopyKey : KeyType =(Shift:False;Ctrl:True; Alt:False; ch:#0 ; s:#4 );
 PasteKey: KeyType =(Shift:True; Ctrl:False;Alt:False; ch:#0 ; s:#5 );
 ClearKey: KeyType =(Shift:False;Ctrl:True ;Alt:False; ch:#0 ; s:#6 );
 CutKey  : KeyType =(Shift:True; Ctrl:False;Alt:False; ch:#0 ; s:#7 );
 Enter   : KeyType =(Shift:False;Ctrl:False;Alt:False; ch:#13; s:#0 );

function NoKeyP(k: KeyType):boolean;
begin;
  if (k.Ch=#0) then NoKeyP:= True else NoKeyP := False;
end;

function IDE_MouseX: integer;
begin;
  IDE_MouseX := MMouse_GetX div 1;
end;

function IDE_MouseY: integer;
begin;
  IDE_MouseY := MMouse_GetY div 1;
end;

function IDE_MouseXL: integer;
begin;
  IDE_MouseXL := MMouse_GetXL div 1;
end;

function IDE_MouseYL: integer;
begin;
  IDE_MouseYL := MMouse_GetYL div 1;
end;

function IDE_MouseL: boolean;
begin;
  IDE_MouseL := MMouse_ButtonLeft;
end;

function IDE_MouseR: boolean;
begin;
  IDE_MouseR := MMouse_ButtonRight;
end;

function IDE_MouseMoved: boolean;
begin;
  IDE_MouseMoved := MMouse_Moved;
end;

procedure IDE_HighBack;assembler;
asm
   mov ax, 01003h
   mov bl, 0
   int 010h
end;

function KeyPressed: boolean;
Var
  i      : integer;
  reg    : registers;

begin
  reg.ah := $11;
  Intr($16, reg);
  i := reg.flags and FZero;
  KeyPressed  := (i = 0);
end;

function GetKey(var k: keytype): boolean;
Var
  i      : integer;
  status : byte;
  reg    : registers;

begin
  {wait for keypress}
  reg.ah := $11;
  Intr($16, reg);
  {is it an extended key?}
  i := reg.flags and FZero;
  {check shift/ctrl/alt status}
  reg.ah := $12;
  Intr($16, reg);
  status := reg.al;

  k.shift := (status and $03) <> 0;
  k.ctrl  := (status and $04) <> 0;
  k.alt   := (status and $08) <> 0;

  if i = 0 then
    begin
      reg.ah := $10;
      Intr($16, reg);
      byte(k.ch):= reg.al;
      byte(k.s ):= reg.ah;
      if k.ch=#$E0 then k.ch:=#0;
      GetKey  := True;
    end
  else
    GetKey := False;
end;

procedure GotoXY(x,y : word); assembler;
asm
   mov    ax,y
   mov    dh,al
   dec    dh
   mov    ax,x
   mov    dl,al
   dec    dl
   mov    ah,2
   xor    bh,bh
   int    10h
end;

function GetLTime: Longint;
var w1, w2, w3, w4: word;
begin
  GetTime(w1, w2, w3, w4);
  GetLTime := longint(w4) + longint(w3) * longint(100) + longint(w2) * longint(6000) + longint(w1) * longint(360000);
end;

{* Check's if a file exists *}
Function FileExists(FileName: String): Boolean;
var f: file;
    m: integer;
begin;
  m:=filemode;
 {$I-}                { turn OFF I/O checking so TP doesn't give us an error }
  Assign(F,FileName); { try to open the file, read-only mode }
  FileMode:=0;
  Reset(F);
  Close(F);
 {$I+}
  FileExists:=(IOResult=0)and(FileName<>'');
  FileMode:=m;
end;

Procedure DeleteFile(St: String);
var f: file;
begin;
  {$I-}
  assign(f, St);
  reset(f, 1);
  erase(f);
  {$I+}
end;

Procedure RenameFile(St, StT: String);
var f: file;
begin
  if not FileExists(StT) then
    Begin;
      {$I-}
      assign(f, St);
      rename(f, StT);
      {$I+}
    end;
end;

{* Check's if a directory exists *}
Function DirExists(DirName: String): Boolean;
var DirInfo: SearchRec;
begin
 FindFirst(DirName, Directory, DirInfo);
 if (DirInfo.Name = '') or (DirInfo.Attr and VolumeID > 0) then
    DirExists := False else DirExists := True;
end;

Function PadComma(l: Longint): String;
{* Converts a number to a Comma separated string, looks nicer than Str *}
Var St: String;i: word;
Begin
 {- Convert number 'l' to String 'St' -}
 Str(l, St);
 {- If it's over 3 characters long it needs a comma -}
 if Length(St) > 3 then
 for i:=1 to length(St)-1 do
 {- Search for every third place and insert a comma -}
  if (i+1) mod 4 = 3 then Insert(',',St,length(St)-i);
 {- Return the new string -}
 PadComma := St;
End;

Const
 IdenSt: String[60] = ('!@%^&*()-=+/.,;:<>?|\[]'#0#32#255#10#13'{}'#34#39);

 ResWord_n = 63;
 ResWord: Array[0..ResWord_n] of String[16] =(
  {- Line MUST be in order -}  'BEGIN','ASM','RECORD','CASE','END',
  'AND','ARRAY','CONST','CONSTRUCTOR','DESTRUCTOR','DIV','DO',
  'DOWNTO','ELSE','EXPORTS','FILE','FOR','FUNCTION','GOTO','IF',
  'IMPLEMENTATION','IN','INHERITED','INLINE','INTERFACE','LABEL',
  'LIBRARY','MOD','NIL','NOT','OBJECT','OF','OR','PACKED','PROCEDURE',
  'PROGRAM','REPEAT','SET','SHL','SHR','STRING','THEN','TO','TYPE',
  'UNIT','UNTIL','USES','VAR','WHILE','WITH','XOR',
  {- Things that go at the end of a line, used less -}
  'ABSOLUTE','ASSEMBLER','EXPORT','EXTERNAL','FAR','FORWARD','INDEX',
  'INTERRUPT','NEAR','PRIVATE','PUBLIC','RESIDENT','VIRTUAL');


 Res2Word_n = 10;
 Res2Word: Array[0..Res2Word_n] of String[16] =(
  {- Not really Reserved words but it's nice to hilight them -}
  'WRITE','WRITELN','INC','DEC','BYTE','WORD','DWORD','LONGINT','INTEGER',
  'BOOLEAN','CHAR');

var
 Sym: Record
  Filled: Boolean;
  LastProgST: String;
  cLine, tLine: Longint;
 end;

{ Screen variables }
 IDE_Screen: record
               CursorX, CursorY: Integer; {where's our blinking mate ;) }
               SwapBuffer: Pointer;  {- Buffer to saved display page -}
               SwapBufferSize: Word;
               SwapCx, SwapCy: Byte;
               SwapVM: Byte;
               Width, Height: Word;
               Redrawn,
               tIns: Boolean;
               BFSeg:Word;
               Buffer: PAChCo;
               LastBuffer: PAChCo; { Only used for TXT->GFX modes }
               BufferSize:WorD;
             end;

 Const HexStr: String[16] =('0123456789ABCDEF');

 Procedure IDE_WriteXYC_Ch(X,Y:Integer; C:Char;Col:Byte); assembler;
   asm
      mov  si, seg @DATA
      mov  ds, si
      mov  bx, word ptr [x]
      mov  ax, word ptr [y]
      cmp  bx, 0
      jl   @exit
      cmp  ax, 0
      jl   @exit
      cmp  bx, word ptr [IDE_Screen.Width]
      jge  @exit
      cmp  ax, word ptr [IDE_Screen.Height]
      jge   @exit

      mov  cl, byte ptr [c]
      mov  ch, byte ptr [col]

      mov  dx, word ptr [IDE_Screen.Width]
      add  dx, dx
      mul  dx
      shl  bx, 1
      add  ax, bx
      les  di, dword ptr [IDE_Screen.Buffer]
      add  di, ax
      mov  word ptr [es:di], cx
 @exit:
{ Pascal code for above:

  if (X<0) or (Y<0) or (X>IDE_Screen.ScrWidth-1) or (Y>IDE_Screen.ScrHeight-1) then exit;
  IDE_Screen.Buffer[Y, X].Ch  := Ord(Ch);
  IDE_Screen.Buffer[Y, X].Col := Col;}
end;

procedure IDE_Grey(X,Y:Integer); assembler;
   asm
      mov  bx, word ptr [x]
      mov  ax, word ptr [y]
      cmp  bx, 0
      jl   @exit
      cmp  ax, 0
      jl   @exit
      cmp  bx, word ptr [IDE_Screen.Width]
      jge  @exit
      cmp  ax, word ptr [IDE_Screen.Height]
      jge   @exit

      mov  ch, $07;

      mov  dx, word ptr [IDE_Screen.Width]
      add  dx, dx
      mul  dx
      shl  bx, 1
      add  ax, bx
      les  di, dword ptr [IDE_Screen.Buffer]
      add  di, ax
      mov  byte ptr [es:di+1], ch
 @exit:
{ Pascal code for above:

  if (X<0) or (Y<0) or (X>IDE_Screen.ScrWidth-1) or (Y>IDE_Screen.ScrHeight-1) then exit;
  IDE_Screen.Buffer[Y, X].Col := $07;}
end;

procedure IDE_SetBC(X,Y:Integer;c: byte);
begin
  if (X>=0) and (Y>=0) and (X<=(IDE_Screen.Width-1)) or (Y<=(IDE_Screen.Height-1)) then
    begin
      IDE_Screen.Buffer^[Y*IDE_Screen.Width + X].Col := (c Shl 4) + (IDE_Screen.Buffer^[Y*IDE_Screen.Width + X].Col and $F);
    end;
end;

procedure IDE_WriteXYC(X, Y: integer;const st: String;Col: Byte);
var   i, c  : byte;
    _tilda,
     _excl  : word;

begin
  c := 0;
  if St[0] > #0 then
    begin
      for i:=1 to ord(St[0]) do
         begin
           _tilda:=Pos(St[i+1], HexStr);
           if (St[i] = '~') and (_tilda > 0) then
             begin
               Col := (Col and $F0) + (_tilda - 1);
               inc(i);
             end
           else
             begin
               _excl:=Pos(St[i+1], HexStr);
               if (St[i] = '!') and (_excl > 0) then
                 begin
                   Col := (Col and $0F) + (_excl-1) * $F;
                   Inc(i);
                 end
               else
                 IDE_WriteXYC_Ch(X+c, Y, St[i], Col);inc(c);
             end;
            if i >= ord(st[0]) then break;
         end;
    end;
end;
(*
 Procedure IDE_WriteXYC_NB(X, Y: integer;const st: String;Col: Byte);
 var i, c: byte;
     _tilda, _excl:word;
 begin
  c := 0;
  if St[0] > #0 then
    begin
      for i:=1 to ord(St[0]) do
         begin
           _tilda:=Pos(St[i+1], HexStr);
           if (St[i] = '~') and (_tilda > 0) then
             begin
               Col := (Col and $F0) + (_tilda - 1);
               inc(i);
             end
           else
            IDE_WriteXYC_ChNB(X+c, Y, St[i], Col);inc(c);
            if i >= ord(st[0]) then break;
         end;
    end;
end;
*)
 Procedure IDE_WriteXY(X, Y: integer;const st: String;Col: Byte);
 var i: byte;
 begin
  if St[0] > #0 then
      for i:=1 to ord(St[0]) do
          IDE_WriteXYC_Ch(X+i-1, Y, St[i], Col);
 end;

 {- Returns the length of a string removing colour information -}
 Function LengthC(St: String): Byte;
 begin
  if (Pos('~', St) > 0) then
  repeat
   Delete(St, Pos('~', St), 2);
  until (Pos('~', St) = 0);
  if (Pos('!', St) > 0) then
  repeat
   Delete(St, Pos('!', St), 2);
  until (Pos('!', St) = 0);
  LengthC := Length(St);
 end;

 {- Returns the length of a string removing tilda information -}
 Function LengthT(St: String): Byte;
 begin
  if (Pos('~', St) > 0) then
  repeat
   Delete(St, Pos('~', St), 1);
  until (Pos('~', St) = 0);
  LengthT := Length(St);
  if St = '' then LengthT := 0;
 end;

 {- Converts Tilda's to Colour-Strings -}
function TildaToC(st: string; attr: word): string;
var i: byte; InCc: Boolean;St2: String;
{ attr: high byte = highlighted
         low byte = normal     }
begin
  i := 1; InCc := False;
  repeat
   if St[i] = '~' then
    begin
     InCc := not InCc;
     if InCc then
      Insert(HexStr[1+(Hi(attr) and $F)], St, i+1)
     else
      Insert(HexStr[1+(Lo(attr) and $F)], St, i+1);

     Inc(i);
    end;
    Inc(i);
  until i >= Length(St);
  TildaToC := St;
end;

procedure IDE_HideCursor;
begin
 SetNoCursor;
end;

procedure IDE_ShowCursor;
begin
 SetLowCursor;
end;

procedure IDE_ShowCursorINS;
begin
 SetFullCursor;
end;

procedure IDE_UpdateVideo;
begin
  IDE_Screen.Redrawn:=TRUE;
  {MMouse_Hide;}
  If (VideoMode.Intern = TRUEW) then
    Render(IDE_Screen.Buffer,IDE_Screen.LastBuffer,VideoMode)
  else
    Move(IDE_Screen.Buffer^, Mem[VideoMode.Segm:0], IDE_Screen.BufferSize);
  {MMouse_Show;}
  if (IDE_Screen.CursorX >= 0) and (IDE_Screen.CursorX < IDE_Screen.Width) and
     (IDE_Screen.CursorY >= 1) and (IDE_Screen.CursorY < IDE_Screen.Height-1) then
    begin
      GotoXy(IDE_Screen.CursorX+1, IDE_Screen.CursorY+1);
      if IDE_Screen.tIns then IDE_ShowCursorINS else IDE_ShowCursor;
    end
  else
    IDE_HideCursor;
end;

Procedure IDE_Reset;
begin
  IDE_HighBack;
end;

Procedure IDE_SwapVideoOut;
begin
  MMouse_Hide;
  TextMode(CO80);
  asm
    mov al, IDE_Screen.SwapVM
    mov ah, 0h
    int 10h
  end;
  If (IDE_Screen.LastBuffer <> Nil) Then FillChar(IDE_Screen.LastBuffer^,IDE_Screen.SwapBufferSize,#255);
  Move(IDE_Screen.SwapBuffer^, Mem[SegB800:0], IDE_Screen.SwapBufferSize);
  GotoXy(IDE_Screen.SwapCx, IDE_Screen.SwapCy);
end;

Procedure IDE_SwapVideoIn;
begin
  IDE_Screen.SwapCx := WhereX;
  IDE_Screen.SwapCy := WhereY;
  Move(Mem[SegB800:0], IDE_Screen.SwapBuffer^, IDE_Screen.SwapBufferSize);
  asm
    mov ax, 0F00h
    int 10h
    mov IDE_Screen.SwapVM, Al
  end;
  SetMode(VideoMode);
  IDE_HighBack;
  MMouse_Window(0,0, IDE_Screen.Width-1, IDE_Screen.Height-1);
end;

const
  oldpos: word = 0;
var
  attr: byte;

{**!!** Modified by Thomas! **!!**}
procedure WriteMouseCursor; far; assembler;
asm
   mov  di,SEG @Data
   shr  cx, 3
   mov  ds,di
   shr  dx, 3

{ Are these bound checks below REALLY REALLY needed?!?!?
  After all, you HAVE defined a window... right??? }
   cmp  cx, 0
   jl   @exit
   cmp  dx, 0
   jl   @exit
   cmp  cx, word ptr [IDE_Screen.Width]
   jg   @exit
   cmp  dx, word ptr [IDE_Screen.Height]
   jg   @exit

   mov  es,VideoMode.Segm

   cmp  VideoMode.Intern, TRUE
   jne  @DoGoodOlTextCursor

   push ds
   push Offset VideoMode
   push cx
   push dx
   call RenderMouse
   jmp @Exit

{ Wow.. the good ol' text cursor seems THAT much simpler.... ;) }

@DoGoodOlTextCursor:
   mov  ax, dx
   mov  bx, word ptr [IDE_Screen.Width]
   add  bx, bx
   mul  bx
   shl  cx, 1
   add  cx, ax
   mov  di, cx
   inc  di

   cmp  IDE_Screen.Redrawn, TRUE
   je   @1
   mov  si, OldPos
   mov  al, Attr
   mov  es:[si],al

@1:
   mov  OldPos, di
   mov  al, es:[di]
   mov  Attr, al

   not  al
   and  al,7fh
   mov  es:[di], al

@exit:
   mov  IDE_Screen.Redrawn, FALSE
end;

Procedure IDE_Init;
var regs:registers;

begin
  IDE_Screen.SwapBufferSize := VideoMode.Width*VideoMode.Height*2;
  GetMem(IDE_Screen.SwapBuffer, IDE_Screen.SwapBufferSize);
  IDE_SwapVideoIn;

  regs.ax:=$0C;
  regs.es:=seg(WriteMouseCursor);
  regs.dx:=ofs(WriteMouseCursor);
  regs.cx:=$1{FFFF};
  intr($33, regs);

  New(IDE_Desktop, init);
end;

Procedure IDE_Done;
begin
  Dispose(IDE_Desktop, done);
  IDE_SwapVideoOut;
  FreeMem(IDE_Screen.SwapBuffer, IDE_Screen.SwapBufferSize);
end;

{+--------------------------------------------------------------------------+}
{|                                                                          |}
{|    Window/Desktop Objects                                                |}
{|                                                                          |}
{+--------------------------------------------------------------------------+}

type
  pIDE_WindowType = ^IDE_WindowType;

  IDE_WindowType = object
                     Xo, Yo: Integer;   { X,Y origin of the window }
                     Xs, Ys: Word;      { X,Y size of the window   }
                     sXo, sYo: Integer; { stored origin of the window }
                     sXs, sYs: Word;    { stored size of the window   }

                     sDblClick_Time: Longint;
                     {- Source windows can be compiled -}
                     ID: (_NotSource, _Source);
                     {- Title String -}
                     Title, FileTitle: String;
                     {- Colours -}
                     cWinFrame, cWinIcon, cWinSize, cWinSlide, cWinBack, cText: Byte;
                     {- Cursor Positions -}

                     CPX, CPY: Integer; {current cursorposition}
                     { Internal variables used to communicate between functions }

                     Closed,
                     Moving: Boolean; { Window is being moved or resized }
                     MouseEvent_Done: Boolean;
                     Modal: Boolean;
                     SizeAble, Maximised: Boolean;
                     tItem: tCollection;     { Collection of Buttons, Text, InputLine, etc }
                     constructor Init(nXo,nYo: Integer; nXs,nYs: Word; nTitle: String);
                     destructor Done; virtual;
                     procedure Paint; virtual;
                     function InFront: Boolean;
                     procedure Maximise;
                     procedure MouseEvent(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer); virtual;
                     procedure KeyEvent(Key: KeyType); virtual;
                     procedure CloseWindow; virtual;
                     function NewLine: LPtr;
                   end;

{---------------------------------------------------------------------------

              Item Objects, that go in the windows

---------------------------------------------------------------------------}

type
  pIDE_ItemBaseType = ^IDE_ItemBaseType;

  IDE_ItemBaseType  = object
                        wXo, wYo,
                        wXs, wYs: Integer; {- Parent Window's Position - for painting -}
                                           { needed to determine the exact place of certain elements}
                        Xp, Yp: Integer;
                        Xs, Ys: Word;
                        tSt: String;
                        GotFocus,
                        ItemExit, ItemUpdate: Boolean;
                        ShortCut: char;
                        constructor init(X1, Y1, X2, Y2: integer);
                        destructor Done; virtual;
                        procedure Paint; virtual;
                        procedure MouseOn(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer); virtual;
                        procedure KeyOn(Key: KeyType); virtual;
                      end;

constructor IDE_ItemBaseType.init(X1, Y1, X2, Y2: integer);
begin
  Xp := X1;                       { set X,Y position }
  Yp := Y1;
  if X2>0 then Xs:=X2 else Xs:=0; { set window size  }
  if Y2>0 then Ys:=Y2 else Ys:=0;
  GotFocus := FALSE;
  ItemExit := FALSE;
  ItemUpdate := TRUE;
end;

destructor IDE_ItemBaseType.done;
begin
end;

procedure IDE_ItemBaseType.Paint;
begin
 IDE_Screen.CursorX := $FF;
 IDE_Screen.CursorY := $FF;
end;

procedure IDE_ItemBaseType.MouseOn(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer);
begin
end;

procedure IDE_ItemBaseType.KeyOn(Key: KeyType);
begin
end;

type
  pInputLine = ^InputLine;

   InputLine  = object(IDE_ItemBaseType)
                  iSt_cPos,
                  iSt_sPos: Integer;
                  pSt: pointer;
                  ID: string;
                  constructor init(X1, Y1, X2, Y2: Integer; p: Pointer; ntSt: String);
                  destructor Done; virtual;
                  procedure Paint; virtual;
                  procedure KeyOn(Key: KeyType); virtual;
                end;

constructor InputLine.init(X1, Y1, X2, Y2: Integer; p: Pointer; ntSt: String);
begin
  pSt := p;
  iSt_cPos := 0;
  iSt_sPos := 0;
  tSt := ntSt;
  ItemExit := False;
  ItemUpdate := False;
  inherited Init(x1, y1, x2, y2);
end;

Procedure InputLine.Paint;
var i: integer;
begin
  IDE_WriteXYC(wXo+Xp, wYo+Yp-1, tSt, $7F);
  IDE_Screen.CursorX := $FF;
  IDE_Screen.CursorY := $FF;
  if iSt_cPos > Length(ID) then iSt_cPos := Length(ID);
  iSt_sPos := 0;
  if (iSt_cPos >= Xs-1) then iSt_sPos := iSt_cPos - Xs+1;

  if pSt <> nil then Move(pSt^, ID, 256);

  for i:=0 to Xs do
   IDE_WriteXYC_Ch(wXo+Xp+i, wYo+Yp, ' ', $1F);


  for i:=1 to Xs-1 do
   if i<=Length(ID) then
     IDE_WriteXYC_CH(wXo+Xp+i, wYo+Yp, ID[iSt_sPos+i], $1F);
  IDE_Screen.CursorX := (iSt_cPos-iSt_sPos)+wXo+Xp+1;
  IDE_Screen.CursorY := wYo+Yp;
end;

Procedure InputLine.KeyOn(Key: KeyType);
var i: word;
begin
  if pSt <> nil then Move(pSt^, ID, 256);
  if not Key.Alt and not Key.Ctrl and (Key.Ch<>#0) then
    case Key.Ch of
    #13: begin
           if FileExists(ID) then
             ItemExit := True
           else
             begin
               if DirExists(ID) then
                 ItemUpdate := True
               else
                 ItemExit := True;
             end;
         end;
    #27: begin;
           ItemExit:=True;
           ID:='';
         end;
    #8:  begin
           if ID<>'' then
             begin;
               Delete(ID, iSt_cPos, 1);
               if iSt_cPos > 0 then Dec(iSt_cPos);
             end;
         end;
    else
         Insert(Key.Ch, ID, iSt_cPos+1);inc(iSt_cPos);
    end
  else
    if not Key.Alt and not Key.Ctrl and (Key.Ch=#0) then
      case Key.S of
      'K' : if iSt_cPos>0 then Dec(iSt_cPos);
      'M' : if iSt_cPos<Length(ID) then Inc(iSt_cPos);
      'S' : if ID<>'' then Delete(ID, iSt_cPos+1, 1);
      end;
  if pSt <> nil then Move(ID, pSt^, 256);
end;

destructor InputLine.Done;
begin
end;

type
  pButton = ^Button;

  Button  = object(IDE_ItemBaseType)
              IsPressed: Boolean;
              IsDown: Boolean;
              Caption: string;
              constructor init(X1, Y1, X2, Y2: Integer; s: string);
              destructor Done; virtual;
              procedure Paint; virtual;
              procedure KeyOn(Key: KeyType); Virtual;
              procedure MouseOn(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer); virtual;
            end;

constructor Button.init(X1, Y1, X2, Y2: Integer; s: string);
begin
 IsPressed := False;
 IsDown := False;
 caption := s;
 inherited init(x1, y1, x2, y2);
end;

destructor Button.done;
begin
  inherited done;
end;

procedure Button.Paint;
var     i: integer;
    color: word;

begin
  if GotFocus then
    color:=IDE.c.ButtonH shl 8 + $2F
  else
    color:=IDE.c.ButtonH shl 8 + IDE.c.Button;

  if IsDown then
    begin
      for i:=0 to Xs do IDE_WriteXYC(wXo+Xp+i+1, wYo+Yp, ' ', color);
      IDE_WriteXYC(wXo+Xp+1+((1+Xs-LengthT(Caption)) div 2), wYo+Yp, TildaToC(Caption, color), color);
    end
  else
    begin
      for i:=0 to Xs do IDE_WriteXYC(wXo+Xp+i, wYo+Yp, ' ', color);
      for i:=1 to Xs+1 do IDE_WriteXYC(wXo+Xp+i, wYo+Yp+1, 'ß', $70);
      IDE_WriteXYC(wXo+Xp+Xs+1, wYo+Yp, 'Ü', $70);
      IDE_WriteXYC(wXo+Xp+0+((1+Xs-LengthT(Caption)) div 2), wYo+Yp, TildaToC(Caption, color), color);
    end;
end;

procedure Button.KeyOn(Key: KeyType);
begin
  if Key.Ch=#13 then
    begin
      IsPressed:=TRUE;
      IDE_Desktop^.QuickPaint;
    end;
end;

procedure Button.MouseOn(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer);
begin
  if mLeft then
    begin
      IsDown := True;
      While IDE_MouseL do
        begin
          IDE_Desktop^.QuickPaint;
          While not IDE_MouseMoved do;
          if (IDE_MouseX>=wXo+Xp) and (IDE_MouseX<=wXo+Xp+Xs) and
             (IDE_MouseY>=wYo+Yp) and (IDE_MouseY<=wYo+Yp+Ys) then
            IsDown := True
          else
            IsDown := False;
        end;
      IsPressed := IsDown;
      IDE_Desktop^.QuickPaint;
    end;
end;

Type
  pIDE_CheckBoxType = ^IDE_CheckBoxType;

  IDE_CheckBoxType  = object(IDE_ItemBaseType)
                        Checked : boolean;
                        Caption : string;
                        constructor init(x1, y1: integer; s: string; state: boolean; c: char);
                        destructor Done; virtual;
                        procedure Paint; virtual;
                        procedure KeyOn(Key: KeyType); Virtual;
                        procedure MouseOn(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer); virtual;
                      end;

constructor IDE_CheckBoxType.init(x1, y1: integer; s: string; state: boolean; c: char);
begin
 checked  := state;
 shortcut := c;
 Caption  := s;
 inherited init(x1, y1, Length(s)+4, y1);
end;

destructor IDE_CheckBoxType.done;
begin
end;

procedure IDE_CheckBoxType.Paint;
var s: string[5];
begin
  if checked then s:=' [X] '
             else s:=' [ ] ';
  IDE_WriteXYC(wXo+Xp+1, wYo+Yp, s, $30);
  IDE_WriteXYC(wXo+Xp+6, wYo+Yp, TildaToC(caption, IDE_aMenu), $30);
end;

procedure IDE_CheckBoxType.KeyOn(Key: KeyType);
begin
  if upcase(key.ch)=shortcut then
    checked:=not checked;
end;

procedure IDE_CheckBoxType.MouseOn(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer);
var IsDown: boolean;
begin
  if mLeft then
    begin
      IsDown := True;
      While IDE_MouseL do
        begin
          while not IDE_MouseMoved do;
          if (IDE_MouseX>=wXo+Xp) and (IDE_MouseX<=wXo+Xp+Xs) and
             (IDE_MouseY>=wYo+Yp) and (IDE_MouseY<=wYo+Yp+Ys) then
            IsDown := True
          else
            IsDown := False;
        end;
      checked := not checked;
      IDE_Desktop^.QuickPaint;
    end;
end;

type
  orientation = (vertical, horizontal);

  pScrollBar = ^ScrollBar;
   ScrollBar = object(IDE_ItemBaseType)
                 value: integer;     { real value of scrollbar pointer }
                 min  : integer;     { minimum value                   }
                 max  : integer;     { maximum value                   }
                 o    : orientation;
                 Visible: boolean;   { switch to draw scrollbar        }
                 IsPressed: boolean; { TRUE when scrollbar is clicked  }
                 constructor Init(x1, x2, y, AMin, AMax: integer; AO: orientation);
                 procedure Paint; virtual;
                 procedure SetRange(AMin, AMax: integer);
                 procedure SetPosition(x1, x2, y: integer; AO: orientation);
                 procedure SetValue(AValue: integer);
                 procedure MouseOn(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer); virtual;
                 destructor Done; virtual;
               end;

constructor ScrollBar.Init(x1, x2, y, AMin, AMax: integer; AO: orientation);
{ Initializes the scrollbar }
begin
  value := 0;
  min   := AMin;
  max   := AMax;
  o     := AO;
  SetPosition(x1, x2, y, AO);
  visible:=TRUE;
end;

procedure ScrollBar.Paint;
{ draw the scrollbar and the value pointer }
var p, i: integer;
begin
  if not visible then exit;
  if value>max then value:=max;
  if value<min then value:=min;
  if o = horizontal then
    begin { Draw scrollbar - horizontal }
      for i:=1 to Xs do IDE_WriteXYC_Ch(wXo+Xp+i, wYo+Yp, '±', IDE_cWinSlide);
      IDE_WriteXYC_Ch(wXo+Xp   , wYo+Yp, #17, IDE_cWinSlide);
      IDE_WriteXYC_Ch(wXo+Xp+Xs, wYo+Yp, #16, IDE_cWinSlide);
      p := 1 + round((value / (max-min)) * (Xs-2)); { position of the pointer }
      IDE_WriteXYC_Ch(wXo+Xp+p , wYo+Yp, #254, IDE_cWinSlide)
    end
  else
    begin { Draw scrollbar - vertical }
      for i:=1 to Ys do IDE_WriteXYC_Ch(wXo+Xp, wYo+Yp+i, '±', IDE_cWinSlide);
      IDE_WriteXYC_Ch(wXo+Xp, wYo+Yp   , #30, IDE_cWinSlide);
      IDE_WriteXYC_Ch(wXo+Xp, wYo+Yp+Ys, #31, IDE_cWinSlide);
      p := 1 + round((value / (max-min)) * (Ys-2)); { position of the pointer }
      IDE_WriteXYC_Ch(wXo+Xp, wYo+Yp+p, #254, IDE_cWinSlide)
    end;
end;

procedure ScrollBar.SetRange(AMin, AMax: integer);
begin
  min:=AMin;
  max:=AMax;
end;

procedure ScrollBar.SetValue(AValue: integer);
begin
  value:=AValue;
end;

procedure ScrollBar.SetPosition(x1, x2, y: integer; AO: orientation);
begin
  if o = horizontal then
    begin
      Xp:=x1;    { X position relative to border }
      Xs:=x2-x1; { size (in characters)          }
      Yp:=y;     { Y position relative to border }
      Ys:=0;
    end
  else
    begin
      Yp:=x1;    { Y position relative to border }
      Ys:=x2-x1; { size (in characters)          }
      Xp:=y;     { X position relative to border }
      Xs:=0;
    end;
end;

function WaitForMouse: boolean;
var i: integer;
begin
  WaitForMouse:=FALSE;
  i:=30;
  repeat
    Delay(3);
    Dec(i);
  until (IDE_MouseMoved) or (i=0);
  if i=0 then WaitForMouse:=TRUE;
end;

procedure ScrollBar.MouseOn(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer);
begin
  if not visible then exit;
  { click on arrow }
  if (mX = 0)  and (mY = 0)  and (value<>min) then Dec(Value);
  if (mX = Xs) and (mY = Ys) and (value<>max) then Inc(Value);
  { autoscroll when arrow is being clicked}
  if WaitForMouse then
    begin
      while (IDE_MouseX-wXo=Xp) and (IDE_MouseY-wYo=Yp) and IDE_MouseL do
        begin
          if not WaitForMouse then break;
          if value<>min then Dec(Value);
          IDE_Desktop^.QuickPaint;
        end;
      while (IDE_MouseX-wXo=Xp+Xs) and (IDE_MouseY-wYo=Yp+Ys) and IDE_MouseL do
        begin
          if not WaitForMouse then break;
          if value<>max then Inc(Value);
          IDE_Desktop^.QuickPaint;
        end;
    end;
  IDE_Desktop^.QuickPaint;
end;

destructor ScrollBar.Done;
begin
end;

{+--------------------------------------------------------------------------+}
{|                                                                          |}
{|    Text window                                                           |}
{|    Window that supports scrolling and resizing                           |}
{|                                                                          |}
{+--------------------------------------------------------------------------+}

type
  pTextWindow = ^TextWindow;

   TextWindow = object(IDE_WindowType)
                  CurPosX,             {current cursor position, column}
                  CurPosY: integer;    {current cursor position, line  }
                  MaxCol,              {total nr of columns            }
                  MaxLines: integer;   {total nr of lines              }
                  StartCol,            {column where text starts       }
                  StartLine: integer;  {line where text starts         }
                  vScroll,
                  hScroll: pScrollBar;
                  constructor Init(nXo,nYo: Integer; nXs,nYs: Word; nTitle: String);
                  procedure Paint; virtual;
                  procedure KeyEvent(Key: KeyType); virtual;
                  procedure MouseEvent(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer); virtual;
                  destructor Done; virtual;
                end;

constructor TextWindow.Init(nXo,nYo: Integer; nXs,nYs: Word; nTitle: String);
begin
 {- Center when asked -}
 if (nXo = Centered) then nXo := (IDE_Screen.Width - nXs) div 2;
 if (nYo = Centered) then nYo := (IDE_Screen.Height - nYs) div 2 - 1;
 {- Set defaults -}
 Xo := nXo;
 Yo := nYo + 1;
 Xs := nXs;
 Ys := nYs;
 Title := nTitle;
 sXo := Xo;
 sYo := Yo;
 sXs := Xs;
 sYs := Ys;
 Moving := False;
 SizeAble := True;
 Maximised := False;
 Modal := False;
 Closed:= False;

 StartCol := 0;
 StartLine:= 0;

 {- Insert SELF into WindowList -}
 IDE_Desktop^.tWin.Insert(@Self);

 {- Set Colours -}
 cWinFrame := IDE_cWinFrame;
 cWinIcon  := IDE_cWinIcon;
 cWinSize  := IDE_cWinSize;
 cWinSlide := IDE_cWinSlide;
 cWinBack  := IDE_cWinBack;
 cText := cWinBack and $F0;
 { Create scrollbars }
 New(hScroll, Init(17, Xs-3, Ys-3, 0, 255, horizontal));
 New(vScroll, Init(1,  Ys-4, Xs-1, 0, 1,   vertical));
 tItem.Init(4, 4); {4 Items maximal!}
 tItem.Insert(hScroll);
 tItem.Insert(vScroll);
 ID := _NotSource;
end;

procedure TextWindow.Paint;
var i: integer; BorderCol: Byte;

   Procedure PaintItem(p: pIDE_ItemBaseType); far;
   begin
     p^.wXo := Xo; {set the window origin}
     p^.wYo := Yo;
     p^.wXs := Xs; {set window size }
     p^.wYs := Ys;
     p^.Paint;
   end;

begin
 inherited Paint;
 BorderCol:=cWinFrame;
 vScroll^.Visible:=FALSE;
 hScroll^.Visible:=FALSE;
 if Moving then      BorderCol := cWinSize;
 if not InFront then BorderCol := cWinBack;
 if not Moving and InFront then
   begin
     hScroll^.Visible:=TRUE;
     hScroll^.SetPosition(17, Xs-3, Ys-1, horizontal); {updates scrollbar, when window is resized}
     vScroll^.Visible:=TRUE;
     vScroll^.SetPosition(1,  Ys-2, Xs-1, vertical);   {updates scrollbar, when window is resized}
     { update window with (changed) scrollbar values }
     StartLine:=vScroll^.value;
     StartCol :=hScroll^.value;
   end;
 if InFront then
   begin
     if SizeAble then { Min/Max Icon }
       begin
         IDE_WriteXYC_Ch(Xo+Xs-5, Yo, '[', BorderCol);
         if Maximised then
           IDE_WriteXYC_Ch(Xo+Xs-4, Yo, #18, cWinIcon)
         else
           IDE_WriteXYC_Ch(Xo+Xs-4, Yo, #24, cWinIcon);
         IDE_WriteXYC_Ch(Xo+Xs-3, Yo, ']', BorderCol);
         IDE_WriteXYC_Ch(Xo+Xs-2, Yo+Ys-1, 'Ä', cWinIcon);
         IDE_WriteXYC_Ch(Xo+Xs-1, Yo+Ys-1, 'Ù', cWinIcon);
       end;
     if tItem.Count>0 then tItem.ForEach(@PaintItem);
   end;
end;

procedure TextWindow.KeyEvent(Key: KeyType);
begin
  hScroll^.value:=StartCol;
  vScroll^.value:=StartLine;
  vScroll^.SetRange(0, MaxLines);
  inherited KeyEvent(Key);
end;

procedure TextWindow.MouseEvent(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer);
var pI: pIDE_ItemBaseType;

  procedure CheckOn(p: pIDE_ItemBaseType); far;
  begin
    if (mX>=p^.Xp) and (mY>=p^.Yp) and (mX<=p^.Xp+p^.Xs) and (mY<=p^.Yp+p^.Ys) then
      pI := p;
  end;

begin
  inherited MouseEvent(mLeft, mMiddle, mRight, mX, mY);
  if (tItem.Count>0) and mLeft then
    begin
      pI := nil;
      tItem.ForEach(@CheckOn);
      if pI <> nil then pI^.MouseOn(mLeft, mMiddle, mRight, mX-pI^.Xp, mY-pI^.Yp);
    end;
end;

destructor TextWindow.Done;
begin
  Dispose(hScroll, Done);
  Dispose(vScroll, Done);
  tItem.DeleteAll;
  tItem.Done;
  inherited Done;
end;

type
  pListBox = ^ListBox;

  ListBox = object(IDE_ItemBaseType)
              List: Lptr;
              ArrowPressed: boolean;
              ListWindow: pTextWindow;
              InputLine: pInputLine;
              default: string;
              constructor Init(X1, Y1, X2, Y2: Integer; s: string);
              destructor Done; virtual;
              procedure Paint; virtual;
              procedure KeyOn(Key: KeyType); Virtual;
              procedure MouseOn(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer); virtual;
            end;

constructor ListBox.Init(X1, Y1, X2, Y2: integer; s: string);
begin
  ArrowPressed:=FALSE;
  default:=s;
  New(InputLine , Init(x1, y1, x2, y2, @default, ''));
  inherited init(x1, y1, x2, y2);
end;

destructor ListBox.done;
begin
  inherited done;
end;

procedure ListBox.Paint;
begin
  InputLine^.wXo := wXo; {set the window origin}
  InputLine^.wYo := wYo;
  InputLine^.Paint;
  {draw down arrow}
  IDE_WriteXYC_Ch(wXo+Xp+Xs-2, wYo+Yp, #221,   $27);
  IDE_WriteXYC_Ch(wXo+Xp+Xs-1, wYo+Yp, #25,  $20);
  IDE_WriteXYC_Ch(wXo+Xp+Xs  , wYo+Yp, #221, $72);

  if (ArrowPressed) and (IDE_Desktop^.tWin.At(IDE_Desktop^.tWin.Count-1) = ListWindow) then
    ListWindow^.Paint
end;

procedure ListBox.KeyOn(Key: KeyType);
begin
  {ArrowDown pressed?}
  if not Key.Alt and not Key.Ctrl and not Key.Shift and (Key.Ch=#0) and (Key.S='P') then
    begin
      ArrowPressed:=TRUE;
      New(ListWindow, Init(Xp, Yp, Xs, Ys, ''));
      ListWindow^.SizeAble:=FALSE;
      IDE_Desktop^.QuickPaint;
      repeat
        ProcessEvents;
        if ListWindow^.Closed then break;
      until false;
      Dispose(ListWindow);
    end
  else
    InputLine^.KeyOn(Key);
end;

procedure ListBox.MouseOn(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer);
begin
  if mLeft then
    begin
      While IDE_MouseL do
        begin
          IDE_Desktop^.QuickPaint;
          While not IDE_MouseMoved do;
          {if (IDE_MouseX>=wXo+Xp) and (IDE_MouseX<=wXo+Xp+Xs) and
             (IDE_MouseY>=wYo+Yp) and (IDE_MouseY<=wYo+Yp+Ys) then
            IsDown := True
          else
            IsDown := False;}
          ArrowPressed := TRUE;
        end;
      IDE_Desktop^.QuickPaint;
    end;
end;









const
   MaxIDEFiles = 512;                 { Maximum # of files            }

Type
  pIDE_FileTextType_pFiles = Array[0..MaxIDEFiles-1] of String[12];

  pIDE_FileTextType = ^IDE_FileTextType;

  IDE_FileTextType = object(IDE_ItemBaseType)
                       iSt_cPos, iSt_sPos: Integer;
                       pSt: Pointer;
                       FSPC: String;
                       pFiles: pIDE_FileTextType_pFiles;
                       pFiles_n: Integer;
                       InFocus: Boolean; { Is FileBox infocus }
                       TextBox: InputLine;
                       fb_cFile, fb_cFOfs: Longint;
                       FileTextLastClickT: Longint;
                       constructor init(X1, Y1, X2, Y2: Integer; p: Pointer; nFSPC: String);
                       destructor Done; virtual;
                       procedure Paint; virtual;
                       procedure GetFiles(St: String);
                       procedure KeyOn(Key: KeyType); Virtual;
                       procedure MouseOn(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer); virtual;
                     end;

constructor IDE_FileTextType.init(X1, Y1, X2, Y2: Integer; p: Pointer; nFSPC: String);
begin
 pSt := p;
 iSt_cPos := 0;
 iSt_sPos := 0;
 FSPC := nFSPC;
 InFocus := False;
 ItemExit := False;
 Move(FSPC[0], p^, 256);
 TextBox.Init(X1, Y1, X2, 2, p, '~EN~Fame');
 fb_cFile := 0;
 fb_cFOfs := 0;
{- Read Files -}
 GetFiles('*.'+IDE.P32.Ext);
 Inherited Init(x1, y1+3, x2, y2);
end;

Destructor IDE_FileTextType.done;
begin
 {inherited done;}
end;

Procedure IDE_FileTextType.Paint;
var i, x, y: integer;
begin
  IDE_WriteXYC(wXo+Xp, wYo+Yp-1, '~EF~Files', $7F);
  IDE_Screen.CursorX := $FF;
  IDE_Screen.CursorY := $FF;

if InFocus then
begin
 if fb_cFile<0 then fb_cFile := 0;
 if fb_cFile>pFiles_n-1 then fb_cFile := pFiles_n-1;
 if fb_cFile<fb_cFOfs then Dec(fb_cFOfs, Ys-1);
 if fb_cFile>=fb_cFOfs+Ys+Ys-2 then Inc(fb_cFOfs, Ys-1);
 FSPC := pFiles[fb_cFile];
 TextBox.ID := FSPC; {- This really isn't needed but who carez -}
 Move(FSPC, pSt^, 256);
end;

{- Update command signaled -}
if TextBox.ItemUpdate then
begin
 TextBox.ItemUpdate := False;
 Move(pSt^, FSPC[0], 256);
 GetFiles(FSPC);
end;
if TextBox.ItemExit then
begin
  ItemExit := True;
  TextBox.ItemExit := False;
end;

  TextBox.wXo := wXo; TextBox.wYo := wYo;

  TextBox.Paint;

 for i:=0 to Ys-2 do
 begin
   for x:=0 to Xs-1 do IDE_SetBC(wXo+Xp+x, wYo+Yp+i, 3);
   for y:=0 to 1 do
   begin
    if fb_cFile = i+y*(Ys-1)+fb_cFOfs then
    begin
     IDE_WriteXY(wXo+Xp+1+y*(Xs div 2), wYo+Yp+i, pFiles[i+y*(Ys-1)+fb_cFOfs], $3F);
     for x:=0 to (Xs div 2)-2 do IDE_SetBC(wXo+Xp+x+y*(Xs div 2), wYo+Yp+i, 2);
    end
    else
     IDE_WriteXY(wXo+Xp+1+y*(Xs div 2), wYo+Yp+i, pFiles[i+y*(Ys-1)+fb_cFOfs], $30);
   end;


  IDE_WriteXYC(wXo+Xp+(Xs div 2)-1, wYo+Yp+i, '³', $31);

 end;

  for x:=1 to Xs-2 do IDE_WriteXYC(wXo+Xp+x, wYo+Yp+Ys-1, '±', $31);
  IDE_WriteXYC(wXo+Xp+0,    wYo+Yp+Ys-1, #17, $13);
  IDE_WriteXYC(wXo+Xp+Xs-1, wYo+Yp+Ys-1, #16, $13);

 if InFocus then
 begin
  IDE_Screen.CursorX := $FF;
  IDE_Screen.CursorY := $FF;
 end;
end;

Procedure IDE_FileTextType.KeyOn(Key: KeyType);
var i: word;
begin
 if (Key.Ch = #9) and (not Key.Alt) and (not Key.Ctrl) then
   InFocus := not InFocus
 else
   if not InFocus then
     TextBox.KeyOn(Key)
   else
     if Key.Ch=#0 then
       case Key.S of
       'P': Inc(fb_cFile);
       'H': Dec(fb_cFile);
       'K': Dec(fb_cFile, Ys-1);
       'M': Inc(fb_cFile, Ys-1);
       'G': fb_cFile := 0; {- Home -}
       'O': fb_cFile := $7FFF; {- End -}
       'I': Dec(fb_cFile, (Ys-1)*2); {- Page Up -}
       'Q': Inc(fb_cFile, (Ys-1)*2); {- Page Down -}
       end
end;

Procedure IDE_FileTextType.MouseOn(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer);
var ox, oy, ofl, i: integer;
begin
 if mY<Ys then
 if mLeft then
 begin
  InFocus := True;
  ox := IDE_MouseX - mX;
  oy := IDE_MouseY - mY;
  ofl := fb_cFile;
  if (IDE_MouseX-ox) < Xs div 2 then
   fb_cFile := fb_cFOfs+(IDE_MouseY-oy)
  else
   fb_cFile := fb_cFOfs+(IDE_MouseY-oy)+(Ys-1);

  if (FileTextLastClickT>GetLTime-IDE.DoubleClick) and
      (ofl = fb_cFile) then
          begin
           if FileExists(TextBox.ID) then TextBox.ItemExit := True else
           if DirExists(TextBox.ID) then TextBox.ItemUpdate := True else
           TextBox.ItemExit := True;
           IDE_Desktop^.QuickPaint;
           exit;
          end
  else
  Repeat
   if (IDE_MouseX-ox) < Xs div 2 then
    fb_cFile := fb_cFOfs+(IDE_MouseY-oy)
   else
    fb_cFile := fb_cFOfs+(IDE_MouseY-oy)+(Ys-1);
  IDE_Desktop^.QuickPaint;
   repeat until IDE_MouseMoved;
  until not IDE_MouseL;

  FileTextLastClickT := GetLTime;

 end;
end;

Procedure IDE_FileTextType.GetFiles(St: String);
 Function InOrder(St1, St2: String): Boolean;
 var i, w: byte;
 begin
  w := Length(St1); if Length(St2)<w then w := Length(St2);
  InOrder := True;
  if (St1[Length(St1)] = '\') and (St2[Length(St2)] <> '\') then InOrder := False;
  for i:=1 to w do
  begin
   if ord(St1[i]) > ord(St2[i]) then InOrder := False;
   if ord(St1[i]) < ord(St2[i]) then break;
  end;
  if (St1[Length(St1)] <> '\') and (St2[Length(St2)] = '\') then InOrder := True;
 end;

var DirInfo: SearchRec;i, w: word;tSt2: String;
begin
 if St = '' then St := '*.' + IDE.P32.Ext;
 fb_cFile := 0; fb_cFOfs := 0;

 for i:=1 to Length(St) do if St[i] = '/' then St[i] := '\';
 if (Pos('\', St)>0) or (Pos('..', St)>0) then
 begin
{$I-}
  if St[Ord(St[0])] = '\' then Dec(St[0]);
  Chdir(St);
  if IOResult <> 0 then beep;
{$I+}
  St := '*.'+IDE.P32.Ext;
 end;

 FSPC := St;
 for i := 0 to MaxIDEFiles-1 do pFiles[i] := '';
 pFiles_n := 0;

 FindFirst(FSPC, Archive, DirInfo);
 while (DosError = 0) and (pFiles_n<MaxIDEFiles) do
 begin
   pFiles[pFiles_n] := DirInfo.Name;
   Inc(pFiles_n);
   FindNext(DirInfo);
 end;

 FindFirst('*.*', Directory, DirInfo);
 while (DosError = 0) and (pFiles_n<MaxIDEFiles) do
 begin
   if DirInfo.name <> '.' then
   if DirInfo.name <> '..' then
   if DirInfo.Attr and Directory > 0 then
   begin
    pFiles[pFiles_n] := DirInfo.Name+'\';
    Inc(pFiles_n);
   end;
   FindNext(DirInfo);
 end;

{- Sort directory entrys -}
 if pFiles_n>2 then
 for w := 0 to pFiles_n-1 do
  for i := 0 to pFiles_n-2 do
    if not InOrder(pFiles[i], pFiles[i+1]) then
      begin
       tSt2 := pFiles[i];
       pFiles[i] := pFiles[i+1];
       pFiles[i+1] := tSt2;
      end;
   { It's nicer for the ..\ to be the last entry }
   pFiles[pFiles_n] := '..\'; Inc(pFiles_n);
end;

constructor IDE_WindowType.Init(nXo,nYo: Integer; nXs,nYs: Word; nTitle: String);
begin
 {- Center when asked -}
 if (nXo = $FF) then nXo := (IDE_Screen.Width - nXs) div 2;
 if (nYo = $FF) then nYo := (IDE_Screen.Height - nYs) div 2 - 1;
 {- Set defaults -}
 Xo := nXo; Yo := nYo + 1; Xs := nXs; Ys := nYs; Title := nTitle;
 sXo := Xo; sYo := Yo; sXs := Xs; sYs := Ys;
 Moving := False; CPX := 1; CPY := 1; SizeAble := False;
 Maximised := False; Modal := False; Closed:=FALSE;
 {- Set Colours -}
 cWinFrame := IDE_cDWinFrame; cWinIcon  := IDE_cDWinIcon; cWinSize  := IDE_cDWinSize;
 cWinSlide := IDE_cDWinSlide; cWinBack  := IDE_cDWinBack; cText := cWinBack and $F0;
 ID := _NotSource;
 {- Insert SELF into WindowList -}
 IDE_Desktop^.tWin.Insert(@Self);
 {- Repaint the screen -}
 IDE_Desktop^.Paint;
 {pText := nil;}
end;

Destructor IDE_WindowType.Done;
begin
 IDE_Desktop^.tWin.Delete(@Self);
 IDE_Desktop^.Paint;
end;

function IDE_WindowType.NewLine:Lptr;
var line: LPtr;

begin
  new(line);
  FillChar(line^, sizeof(line^), 0);
  NewLine:=line;
end;

Function IDE_WindowType.InFront: Boolean;
begin
 if IDE_Desktop^.tWin.At(IDE_Desktop^.tWin.Count-1) = @Self then InFront := True else InFront := False;
end;

Procedure IDE_WindowType.Maximise;
begin
 if not SizeAble then exit;
 if Maximised then
 begin
  Xo := sXo; Yo := sYo; Xs := sXs; Ys := sYs;
  Maximised := False;
 end
 else
 begin
  sXo := Xo; sYo := Yo; sXs := Xs; sYs := Ys;
  Maximised := True;
  Xo := 0;Yo := 0; Xs := IDE_Screen.Width; Ys := IDE_Screen.Height-2;
 end;
 IDE_Desktop^.Paint;
end;

procedure IDE_WindowType.CloseWindow;
begin
  Closed:=TRUE;
end;

Procedure IDE_WindowType.Paint;
var i, ii: integer; BorderCol: Byte;
    ON_DB, ON_Front: Boolean;St: String;
begin
 { Keep window variables within bounds }
 if (Yo <= 0) then Yo := 1;
 if (Yo > IDE_Screen.Height-2) then Yo := IDE_Screen.Height-2;
 if (Xs > IDE_Screen.Width) then Xs := IDE_Screen.Width;
 If (Ys > IDE_Screen.Height-2) then Ys := IDE_Screen.Height-2;
 if (Xs < 23) then Xs := 23; if (Ys < 5) then Ys := 5;

 if (Xs = IDE_Screen.Width) and
    (Ys = IDE_Screen.Height-2) then Maximised := True else Maximised := False;


 { Hide Cursor }
{ IDE_Screen.CursorX := $FF;
 IDE_Screen.CursorY := $FF;
 IDE_Screen.tIns := False;}

BorderCol := cWinFrame;
if Moving then BorderCol := cWinSize;
if InFront then ON_Front := True else ON_Front := False;

if not ON_Front then BorderCol := cWinBack;

if (Moving) or (not InFront) then ON_DB := True else ON_DB := False;
if (InFront) then ON_Front := True else ON_Front := False;



if ON_DB then
begin
 IDE_WriteXYC_Ch(Xo,      Yo     , 'Ú', BorderCol);
 IDE_WriteXYC_Ch(Xo+Xs-1, Yo     , '¿', BorderCol);
 IDE_WriteXYC_Ch(Xo     , Yo+Ys-1, 'À', BorderCol);
 IDE_WriteXYC_Ch(Xo+Xs-1, Yo+Ys-1, 'Ù', BorderCol);
 for i:=1 to Xs-2 do IDE_WriteXYC_Ch(Xo+i, Yo, 'Ä', BorderCol);
 for i:=1 to Xs-2 do IDE_WriteXYC_Ch(Xo+i, Yo+Ys-1, 'Ä', BorderCol);

 for ii:=1 to Ys-2 do
 begin
  IDE_WriteXYC_Ch(Xo, Yo+ii, '³', BorderCol);
  IDE_WriteXYC_Ch(Xo+Xs-1, Yo+ii, '³', BorderCol);
  for i:=1 to Xs-2 do IDE_WriteXYC_Ch(Xo+i, Yo+ii, ' ', cWinFrame);
 end;
end
else
begin
 IDE_WriteXYC_Ch(Xo,      Yo     , 'É', BorderCol);
 IDE_WriteXYC_Ch(Xo+Xs-1, Yo     , '»', BorderCol);
 IDE_WriteXYC_Ch(Xo     , Yo+Ys-1, 'È', BorderCol);
 IDE_WriteXYC_Ch(Xo+Xs-1, Yo+Ys-1, '¼', BorderCol);
 for i:=1 to Xs-2 do IDE_WriteXYC_Ch(Xo+i, Yo, 'Í', BorderCol);
 for i:=1 to Xs-2 do IDE_WriteXYC_Ch(Xo+i, Yo+Ys-1, 'Í', BorderCol);

 for ii:=1 to Ys-2 do
 begin
  IDE_WriteXYC_Ch(Xo, Yo+ii, 'º', BorderCol);
  IDE_WriteXYC_Ch(Xo+Xs-1, Yo+ii, 'º', BorderCol);
  for i:=1 to Xs-2 do IDE_WriteXYC_Ch(Xo+i, Yo+ii, ' ', cWinFrame);
 end;

end;

begin
  for i:=0 to Xs-1 do if (Xo+i+2 < IDE_Screen.Height) and (Xo+i+2 >= 0) then IDE_Grey(Xo+i+2, Yo+Ys);
  for i:=0 to Ys-1 do
    if (Yo+i+1 >= 1) and (Yo+i+1 < IDE_Screen.Height-1) and (Xo+Xs >= 0) and (Xo+Xs < IDE_Screen.Width) then
  IDE_Grey(Xo+Xs, Yo+i+1);
  for i:=0 to Ys-1 do
    if (Yo+i+1 >= 1) and (Yo+i+1 < IDE_Screen.Height-1) and (Xo+Xs+1 >= 0) and (Xo+Xs+1 < IDE_Screen.Width) then
  IDE_Grey(Xo+Xs+1, Yo+i+1);
end;

{- Write Title clipping at edge of free space -}
if Title<>'' then
  begin
    St := ' ' + Title + ' ';
    for i := 1 to Length(St) do
      begin
        ii := integer(integer(integer(Xs)-integer(Length(St))) div 2)+i-1;
        if (ii >= 5) and (ii < Xs-5) and (ON_Front) then IDE_WriteXYC(Xo+ii, Yo, St[i], BorderCol);
        if (ii >= 2) and (ii < Xs-2) and (not ON_Front) then IDE_WriteXYC(Xo+ii, Yo, St[i], BorderCol);
      end;
  end;

if On_Front then
begin

{ Close Window Icon }
 IDE_WriteXYC_Ch(Xo+2, Yo, '[', BorderCol);
 IDE_WriteXYC_Ch(Xo+3, Yo, 'þ', cWinIcon);
 IDE_WriteXYC_Ch(Xo+4, Yo, ']', BorderCol);
end;

end;

Procedure IDE_WindowType.KeyEvent(Key: KeyType);
begin
  if (Modal) and (Key.Ch = #27) or (Key.Ch =  #1) then
    begin
      CloseWindow;
      IDE_Desktop^.Paint;
    end
 else
    if (Key.Alt=TRUE) and (Key.S=#106) then { Alt-F3 }
      begin
        CloseWindow;
        IDE_Desktop^.Paint;
      end;
end;

Procedure IDE_WindowType.MouseEvent(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer);
Var oXo, oYo, oXs, oYs: Integer; w1,w2,w3,w4: word;l: Longint;
begin
 {- Move Window when border pressed -}
 if (mLeft) then
 begin

  if (mX >= 2) and (mX <= 4) and (mY = 0) then
  begin
    repeat

    { Close Window Icon }
     IDE_WriteXYC_Ch(Xo+2, Yo, '[', cWinFrame);
   if (IDE_MouseX >= Xo+2) and (IDE_MouseX <= Xo+4) and (IDE_MouseY = Yo) then
     IDE_WriteXYC_Ch(Xo+3, Yo, #15, cWinIcon)
   else
     IDE_WriteXYC_Ch(Xo+3, Yo, 'þ', cWinIcon);
     IDE_WriteXYC_Ch(Xo+4, Yo, ']', cWinFrame);

     IDE_UpdateVideo;
     Repeat until IDE_MouseMoved;

    until not IDE_MouseL;
   if (IDE_MouseX >= Xo+2) and (IDE_MouseX <= Xo+4) and (IDE_MouseY = Yo) then
    begin
     {IDE_WindowType.}CloseWindow;
     {IDE_WindowType.}Done;
     IDE_Desktop^.Paint;
    end;
    MouseEvent_Done := True;
  end
  else
  if (mX >= Xs-5) and (mX <= Xs-3) and (mY = 0) and (SizeAble) then
  begin
    sDblClick_Time := 0; {- Reset DblClick count -}
    Maximise;
    MouseEvent_Done := True;
  end
  else
  if (mY=0) then
     begin
      GetTime(w1, w2, w3, w4);
      l := w4 + w3 * 100 + w2 * 6000 + w1 * 360000;
      if (l-IDE.DoubleClick < sDblClick_Time) then
      begin
       Maximise;
       sDblClick_Time := 0; {- Reset DblClick count -}
      end
      else
      begin
       GetTime(w1, w2, w3, w4);
       sDblClick_Time := w4 + w3 * 100 + w2 * 6000 + w1 * 360000;
       Moving := True;
       IDE_Desktop^.IDE_BottomHelp('#~'#24#25#26#27'~ Move  ~Shift+'#24#25#26#27'~ Resize  ~'#17'ÄÙ~ Done  ~Esc~ Cancel');
       IDE_Desktop^.Paint;
       oXo := Xo; oYo := Yo;
       repeat

        repeat until IDE_MouseMoved;
        Xo := IDE_MouseX - mX;
        Yo := IDE_MouseY - mY;
        IDE_Desktop^.Paint;

       until not IDE_MouseL;
       Moving := False;
       IDE_Desktop^.IDE_BottomHelp('');
       IDE_Desktop^.Paint;
       if (oXo <> Xo) or (oYo <> Yo) then {- Only reset if moved -}
        sDblClick_Time := 0; {- Reset DblClick count -}

      MouseEvent_Done := True;
      end;
   end
   else
   if ((mY=Ys-1) and (mX > Xs-3) and (mX < Xs)) and (SizeAble) then
   begin
      Moving := True;
      IDE_Desktop^.IDE_BottomHelp('#~'#24#25#26#27'~ Move  ~Shift+'#24#25#26#27'~ Resize  ~'#17'ÄÙ~ Done  ~Esc~ Cancel');
      IDE_Desktop^.Paint;
      oXs := Xs; oYs := Ys;
      oXo := Xo; oYo := Yo;
      sDblClick_Time := 0; {- Reset DblClick count -}
      repeat

       repeat until IDE_MouseMoved;
       Xs := (IDE_MouseX - mX)+oXs-oXo;
       Ys := (IDE_MouseY - mY)+oYs-oYo;
       if Xs > 160 then Xs := 0;
       if Ys > 50 then Ys := 0;
       IDE_Desktop^.Paint;

      until not IDE_MouseL;
      Moving := False;
      IDE_Desktop^.IDE_BottomHelp('');
      IDE_Desktop^.Paint;
      MouseEvent_Done := True;
   end;
 end;
end;

{+--------------------------------------------------------------------------+}
{|                                                                          |}
{|    Dialog window                                                         |}
{|    Basic object structure for dialog boxes                               |}
{|                                                                          |}
{+--------------------------------------------------------------------------+}
type
   pIDE_DialogWindow = ^IDE_DialogWindow;

    IDE_DialogWindow = object(IDE_WindowType)
                         constructor Init(nXo,nYo: Integer; nXs,nYs: Word; nTitle: String);
                         destructor Done; virtual;
                         procedure Paint; virtual;
                         procedure KeyEvent(Key: KeyType); virtual;
                         procedure MouseEvent(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer); virtual;
                         procedure DoEvents; virtual;
                       end;

constructor IDE_DialogWindow.Init(nXo,nYo: Integer; nXs,nYs: Word; nTitle: String);
begin
 tItem.Init(16, 4); {16 Item maximal!}
 Inherited Init(nXo, nYo, nXs, nYs, nTitle);
 Modal := True;
end;

destructor IDE_DialogWindow.Done;
begin
  tItem.DeleteAll;
  tItem.Done;
  inherited done;
end;

Procedure IDE_DialogWindow.Paint;

 Procedure PaintItem(p: pIDE_ItemBaseType); far;
 begin
  p^.wXo := Xo; {set the window origin}
  p^.wYo := Yo;
  p^.wXs := Xs; {set window size }
  p^.wYs := Ys;
  p^.Paint;
 end;

begin
 inherited Paint;
 if tItem.Count>0 then tItem.ForEach(@PaintItem);
end;

Procedure IDE_DialogWindow.MouseEvent(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer);
var pI: pIDE_ItemBaseType;
  procedure CheckOn(p: pIDE_ItemBaseType); far;
  begin
    if (mX>=p^.Xp) and (mY>=p^.Yp) and (mX<p^.Xp+p^.Xs) and(mY<p^.Yp+p^.Ys) then
      pI := p;
  end;

begin
  inherited MouseEvent(mLeft, mMiddle, mRight, mX, mY);
  if tItem.Count>0 then
    begin
      pI := nil;
      tItem.ForEach(@CheckOn);
      if pI <> nil then pI^.MouseOn(mLeft, mMiddle, mRight, mX-pI^.Xp, mY-pI^.Yp);
    end
end;

procedure IDE_DialogWindow.KeyEvent(Key: KeyType);
var pI: pIDE_ItemBaseType;

   procedure CheckShortcuts(p: pIDE_ItemBaseType); far;
   begin
     if (p^.shortcut=upcase(key.ch)) then pI := p;
   end;

   procedure CheckFocus(p: pIDE_ItemBaseType); far;
   begin
     if p^.GotFocus then pI := p;
   end;

begin
  inherited KeyEvent(Key);
  if tItem.Count>0 then
    begin
      pI := nil;
      tItem.ForEach(@CheckShortcuts);
      if pI<>NIL then
        pI^.KeyOn(Key)
      else
        begin
          tItem.ForEach(@CheckFocus);
          if pI<>NIL then
            pI^.KeyOn(Key)
          else
            begin
              pI:=tItem.At(tItem.Count-1);
              pI^.KeyOn(Key);
            end;
        end
    end;
end;

procedure IDE_DialogWindow.DoEvents;
begin
end;

type
  pIDE_UserWindowType = ^IDE_UserWindowType;

  IDE_UserWindowType = object(TextWindow)
                         vXo, vYo: integer;
                         procedure MouseEvent(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer); virtual;
                         constructor Init(nXo,nYo: Integer; nXs,nYs: Word; nTitle: String);
                         procedure Paint; virtual;
                       end;

constructor IDE_UserWindowType.Init(nXo,nYo: Integer; nXs,nYs: Word; nTitle: String);
begin
 Inherited init(nXo, nYo, nXs, nYs, nTitle);
 cWinBack  := cWinBack  and $F;
 cWinSize  := cWinSize  and $F;
 cWinIcon  := cWinIcon  and $F;
 cWinFrame := cWinFrame and $F;
 cWinSlide := cWinSlide and $F;
 cText := cWinBack and $F0;
 vXo := 0; vYo := 0;
 IDE_Desktop^.QuickPaint;
end;

Procedure IDE_UserWindowType.Paint;
var x, y, i: word;
begin
 if Ys > 27 then Ys := 27;
 if Xs > IDE_Screen.Width then Xs := IDE_Screen.Width;
 Inherited Paint;
 if (vXo+Xs > 81) then vXo := 82-Xs;
 if (vYo+Ys > 26) then vYo := 27-Ys;
 if vXo < 0 then vXo := 0;
 if vYo < 0 then vYo := 0;

 IDE_Screen.CursorX := (IDE_Screen.SwapCx+Xo)-vXo;
 IDE_Screen.CursorY := (IDE_Screen.SwapCy+Yo)-vYo;
 if (IDE_Screen.SwapCx-vXo >= Xs-1) or (IDE_Screen.SwapCy-vYo >= Ys-1) or
    (IDE_Screen.SwapCx-vXo <= 0   ) or (IDE_Screen.SwapCy-vYo <= 0   ) then
 begin;IDE_Screen.CursorX:=$FF;IDE_Screen.CursorY:=$FF;end;

 x := IDE_Screen.Width;
 if x > xs-2 then x := xs-2;
 if x+xo >= IDE_Screen.Width then y := IDE_Screen.Width-xo;
 for y:=0 to 24 do
 if (y+2< ys) and (y+yo+1 < 50) then
 begin
  for i:=0 to x-1 do
   if ((i+xo)+1 >= 0) and ((i+xo) < IDE_Screen.Width-1) then
    {Move(Mem[Seg(IDE_Screen.SwapBuffer^):Ofs(IDE_Screen.SwapBuffer^)+(i+vXo)*2+(y+vYo)*160],
         IDE_Screen.Buffer[Yo+y+1, Xo+1+i], 2);}

 end;
end;

Procedure IDE_UserWindowType.MouseEvent(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer);
var oCPX, oCPY, i: Integer;l: Longint;
begin
 inherited MouseEvent(mLeft, mMiddle, mRight, mX, mY);
end;

{+--------------------------------------------------------------------------+}
{|                                                                          |}
{|    Source window                                                         |}
{|    Edit window with syntax- and block highlighting                       |}
{|                                                                          |}
{+--------------------------------------------------------------------------+}

type
   HiLiteBlockType = record
                       typ      : (_none, _string, _comment1, _comment2, _comment3);
                       AsmSource: boolean;
                       NestLevel: integer;
                     end;

 pIDE_SourceWindow = ^IDE_SourceWindow;

  IDE_SourceWindow = object(TextWindow)

                  modified: boolean; { If window has been modified }
                       tIns: Boolean; {- InsertMode -}

                       pTextHiStart,
                       pTextHiEnd,
                       pTextHiFirst:
                       HiLiteBlockType; {- Used for quick Syntax Hilite -}
                       PaintWinOnMove: Boolean;
                       pSyntaxHighlight: Boolean;

                       Ln,                 { current, active line }
                       FirstLn,            { first line of source file }
                       EndLn     : LPtr;   { last line of source file }
                       constructor Init(nXo,nYo: Integer; nXs,nYs: Word; nTitle: String);
                       procedure Paint; virtual;
                       procedure MouseEvent(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer); virtual;
                       procedure KeyEvent(Key: KeyType); virtual;
                       procedure SetCursor;
                       procedure ShowCursorPos;
                       procedure CalcTextHI;
                       function  StringAT: string;
                       procedure LoadFile(St: String);
                       procedure SaveFile(St: String);
                       destructor Done; virtual;
                     end;

constructor IDE_SourceWindow.Init(nXo,nYo: Integer; nXs,nYs: Word; nTitle: String);
begin
  Ln:=NewLine;
  FirstLn:=Ln;
  EndLn  :=Ln;
  CurPosX   := 0;
  CurPosY   := 0;
  tIns := True;
  MaxCol := 1;
  MaxLines := 1;
  pTextHiStart.typ := _none;
  pTextHiStart.NestLevel := 0;
  pTextHiStart.AsmSource := False;
  pTextHiEnd.typ := _none;
  pTextHiEnd.NestLevel := 0;
  pTextHiEnd.AsmSource := False;
  PaintWinOnMove := False;
  FileTitle := ToUpper(nTitle);
  inherited Init(nXo, nYo, nXs, nYs, nTitle);
  SetCursor;
  ID := _Source;
end;

Destructor IDE_SourceWindow.Done;
var p: pointer;
begin
 if FirstLn<>NIL then
    begin
      Ln := FirstLn;
      repeat
        p:=Ln;
        Ln:= Ln^.next;
        dispose(p);
      until Ln^.next = NIL;
    end;
 inherited done;
end;


Procedure IDE_SourceWindow.MouseEvent(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer);
{mX, mY: relative to window origin / border }
var OldPosY, oCPX, oCPY, i: Integer;l: Longint;

begin
  inherited MouseEvent(mLeft, mMiddle, mRight, mX, mY);
  {MouseEvent_Done := False;}
  {if not MouseEvent_Done then}
  if mLeft then
      begin
        if (mX >= 1) and (mY >= 1) and (mX < Xs-1) and (mY < Ys-1) then
          begin
            OldPosY := CurPosY;
            CurPosX := ((IDE_MouseX-Xo)-1) + StartCol;
            CurPosY := ((IDE_MouseY-Yo)-1) + StartLine;
            if CurPosX <= 0 then CurPosX := 0;
            if CurPosY <= 0 then CurPosY := 0;
            if OldPosY>CurPosY then
              for i:=OldPosY downto CurPosY-1 do
                begin
                  if Ln^.prev=NIL then
                    begin
                      CurPosY:=i;
                      break;
                    end;
                  Ln:=Ln^.prev;
                end
            else
              if OldPosY<CurPosY then
                for i:=OldPosY to CurPosY-1 do
                  begin
                    if Ln^.next=NIL then
                      begin
                        CurPosY:=i;
                        break;
                      end;
                    Ln:=Ln^.next;
                  end;
     CalcTextHI;
     SetCursor;
 end;
 end;
end;

Procedure IDE_SourceWindow.KeyEvent(Key: KeyType);

  Procedure PrevWord;
  begin
    while (Ln^.data[CurPosX+1] <> ' ')do
      begin
        dec(CurPosX);
        if CurPosX <= 0 then
          begin
            dec(CurPosY);
            if CurPosY <= 0 then
              begin
                CurPosX:=0;
                CurPosY:=0;
                Ln:=FirstLn;
              end
            else
              begin
                Ln := Ln^.Prev;
                CurPosX:=Length(Ln^.data);
              end;
            break;
          end;
      end;
    while (Ln^.data[CurPosX+1]=' ') do
      begin
        dec(CurPosX);
        if CurPosX <= 0 then
          begin
            dec(CurPosY);
            if CurPosY <= 0 then
              begin
                CurPosX:=0;
                CurPosY:=0;
                Ln:=FirstLn;
              end
            else
              begin
                CurPosX:=Length(Ln^.data);
                Ln := Ln^.Prev;
              end;
            break;
          end;
      end;
  end;

  Procedure NextWord;
  begin
    while (Ln^.data[CurPosX+1] <> ' ')do
      begin
        inc(CurPosX);
        if CurPosX >= Length(Ln^.data) then
          begin
            inc(CurPosY);
            if CurPosY >= MaxLines then
              begin
                CurPosY:=MaxLines;
                Ln:=EndLn;
              end
            else
              Ln := Ln^.Next;
            CurPosX:=0;
            break;
          end;
      end;
    while (Ln^.data[CurPosX+1]=' ') do
      begin
        inc(CurPosX);
        if CurPosX >= Length(Ln^.data) then
          begin
            inc(CurPosY);
            if CurPosY >= MaxLines then
              begin
                CurPosY:=MaxLines;
                Ln:=EndLn;
              end
            else
              Ln := Ln^.Next;
            CurPosX:=0;
            break;
          end;
      end;
  end;

  Procedure InsertLn(const contents: string);  {insert after current line}
  var nextln: Lptr;
  begin
    NextLn:=NewLine;
    NextLn^.Data := contents;
    NextLn^.Prev := Ln;
    NextLn^.Next := Ln^.Next;
    Ln^.Next^.Prev := NextLn;
    Ln^.Next := NextLn;
    Ln:=Ln^.next; {advance to the new line}
    inc(CurPosY); {update cursor position}
    if Ln^.next=NIL then EndLn:=Ln;
    inc(MaxLines)
  end;

  procedure CutLine;    { start new line after <CR> }
  var
    more : string;
  begin
    More := Copy(Ln^.Data, CurPosX+1, Length(Ln^.data)-CurPosX);
    Delete(Ln^.Data, CurPosX+1, Length(Ln^.data)-CurPosX);
    InsertLn(more);
    CurPosX:=0;
  end;

  Procedure StackLine;   { put current line on top of previous line }
  var p: Lptr;
  begin
    if Ln=FirstLn then exit;
    CurPosX := length(Ln^.prev^.data);
    Ln^.prev^.data := Ln^.prev^.data + ln^.data;
    Ln^.prev^.next := Ln^.next;     { isolate current line }
    Ln^.next^.prev := Ln^.prev;
    p:=Ln^.prev;
    Dispose(Ln);                    { and zap it}
    Ln:=p;
  end;

  procedure DeleteLine;
  var p: Lptr;
  begin
    if Ln^.prev<>NIL then Ln^.prev^.next := Ln^.next;     { isolate current line }
    Ln^.next^.prev := Ln^.prev;
    p:=Ln;                         {store old pointer}
    Ln:=Ln^.next;                  {update active line}
    if p=firstln then firstln:=Ln; {update pointer to first line}
    Dispose(p);                    {zap line}
    dec(MaxLines);
  end;

  const
    separator: set of char = [' '];
    lastword: string = '';

  procedure InsertChar(Ch: Char);
  var i, len: Longint;

  begin
    Len:=Length(Ln^.data);
    Modified := True;
    while CurPosX > Len do {fill unused space with spaces}
      begin
        Inc(Len);
        Ln^.Data := Ln^.Data + ' ' ;
      end;
    if CurPosX = Len then
      begin
        Ln^.Data := Ln^.Data + Ch;
        Inc(CurPosX);
      end
    else
     if tIns then
       begin
         Inc(CurPosX);
         Insert(Ch, Ln^.Data, CurPosX);
       end
     else
       Ln^.Data[CurPosX+1] := Ch;
  end;

  procedure ClearSelection(var Ln: Lptr);
  begin
    Ln^.selection:=FALSE;
    Ln^.sBegin:=0;
    Ln^.sEnd:=0;
  end;

  procedure SetSelection(var Ln: Lptr; i, j: integer);
  begin
    Ln^.selection:=TRUE;
    Ln^.sBegin:=i;
    Ln^.sEnd:=j;
  end;

  procedure CopyBlock;
  var o, n, p: Lptr;

  begin
    {clear old clipboard}
    n := clipboard.firstln;
    if n<>NIL then
      repeat
        p := n;
        n := n^.next;
        dispose(p);
      until n = NIL;
    {find current selection}
    p:=firstln;
    repeat
      if p^.selection then
        begin
          n:=NewLine;
          clipboard.firstln:=n;
          repeat
            n^.data  := copy(p^.data, p^.sBegin+1, p^.sEnd-p^.sBegin+1);
            n^.sBegin:= p^.sBegin;
            n^.sEnd  := p^.sEnd;
            o := n;
            n := NewLine;
            n^.prev := o;
            o^.next := n;
            p:=p^.next;
          until not p^.selection or (p=NIL);
          clipboard.endln:=n;
          break;
        end;
      p:=p^.next;
    until p=endln;
  end;

  procedure PasteBlock;
  var p, old: Lptr;
      i, j: integer;
      s: string;
  begin
    p:=clipboard.firstln;
    if p=NIL then exit;
    while p<>clipboard.endln do
      begin
        for i:=1 to length(p^.data) do InsertChar(p^.data[i]);
        if (p^.sBegin=0) and (p^.sEnd=255) then KeyEvent(Enter);
        p:=p^.next;
     end;
  end;

  procedure CutBlock;
  var p, OldLn: Lptr;
      i, j: integer;
      s: string;

  begin
    p:=firstln;
    i:=0;
    repeat
      if p^.selection then
        begin
          repeat
            inc(i);
            delete(p^.data, p^.sBegin+1, p^.sEnd-p^.sBegin+1);
            ln:=p;
            p:=p^.next;
            if (Ln^.sBegin=0) and (Ln^.sEnd=255) then
              begin
                StackLine;
                dec(CurPosY);
                CurPosX:=0;
                if Ln=FirstLn then FirstLn:=Ln^.next;
                Ln:=Ln^.next;
                dec(MaxLines);
              end
            else
              begin
                CurPosX:=Ln^.sBegin;
                ClearSelection(Ln);
              end;
          until not p^.selection or (p=NIL);
          break;
        end;
      p:=p^.next;
    until p=endln;
  end;

var i, j: integer;
    p: Lptr;
begin
 {first check the normal keys}
 if not Key.Alt and not Key.Ctrl and (Key.Ch<>#0) then
   case Key.Ch of
   Tab  : begin
            for i:=0 to (IDE.TabSize-1)-(CurPosX mod IDE.TabSize) do
               KeyEvent(Space)
            {Add Smart-TABs here...}
          end;
   Bs:    begin
            if (CurPosX = 0) then
              begin
                StackLine;
                Dec(CurPosY);
                Dec(MaxLines);
              end
            else
              begin
                delete(Ln^.Data, CurPosX, 1);
                dec(CurPosX);
              end;
          end;
   Cr:    begin
            if tIns then
              begin
                if CurPosX = Length(Ln^.data) then inc(CurPosX);
                CutLine;
              end
            else
              begin
                inc(CurPosY);
                CurPosX:=0;
                Ln := Ln^.Next;
              end;
          end;
   Esc:   Exit;
   else   InsertChar(Key.Ch);
   end;

 {check extended keys}
 if not Key.Alt and not Key.Ctrl and not Key.Shift and (Key.Ch=#0) then
   case Key.s of
   'G': {Home}
        CurPosX := 0;
   'O': {End}
        CurPosX := Length(Ln^.data);
   'I': {PgUp}
        begin
          if CurPosY > Ys-2 then
            begin
              for i:=1 to Ys-2 do
                 if Ln<>FirstLn then
                   begin
                     Ln:=Ln^.prev;
                     dec(CurPosY);
                   end
                 else
                   break;
               StartLine:=CurPosY-1;
            end
          else
           begin
             CurPosY := 0;
             StartLine := 0;
             Ln:=FirstLn;
           end;
          CalcTextHI; {Update SyntaxHighlighting}
        end;
   'Q': {PgDn}
        begin
          if MaxLines > Ys then
            begin
              for i:=1 to Ys-2 do
                if Ln<>EndLn then
                  begin
                    Ln:=Ln^.next;
                    inc(CurPosY);
                  end
                else
                  break;
             StartLine:=CurPosY-1;
            end
          else
            begin
              CurPosY := MaxLines;
              StartLine := MaxLines;
              Ln:=EndLn;
            end;
          CalcTextHI; {Update SyntaxHighlighting}
        end;
   'R': {Ins}
        tIns := not tIns;
   'S': {Del}
        begin
          if CurPosX=Length(Ln^.Data) then
            begin
              if Ln^.next<>NIL then
                begin
                  Ln:=Ln^.next;
                  inc(CurPosX);
                  StackLine;
                  dec(MaxLines);
                end
            end
          else
            Delete(Ln^.Data, CurPosX+1, 1);
        end;
   'K': {ArrowLeft}
        if CurPosX > 0 then Dec(CurPosX);
   'M': {ArrowRight}
        Inc(CurPosX);
   'H': {ArrowUp}
        begin
          if CurPosY > 0 then
            begin
              Dec(CurPosY);
              Ln:=Ln^.prev;
            end;
          CalcTextHI; {Update SyntaxHighlighting}
        end;
   'P': {ArrowDown}
        begin
          if CurPosY < MaxLines then
            begin
              Inc(CurPosY);
              Ln:=Ln^.next;
            end;
          CalcTextHI; {Update SyntaxHighlighting}
        end;
   end;

 {Keys with Ctrl pressed}
 if not Key.Alt and Key.Ctrl then
   case Key.Ch of
   #25 : {Ctrl-Y}
         begin
           DeleteLine;
         end;
   end;

 {Extended keys with Ctrl pressed}
 if not Key.Alt and Key.Ctrl and (Key.Ch=#0) then
   case Key.S of
   #146,
   #4  : {Ctrl-Ins}
         CopyBlock;
   #147,
   #6  : {Ctrl-Del}
         begin
           CutBlock;
           IDE_Desktop^.QuickPaint;
         end;
   #115: {Ctrl-ArrowLeft}
         PrevWord;
   #116: {Ctrl-ArrowRight}
         NextWord;
   #132: {Ctrl-PgUp}
         begin
           StartCol := 0;
           StartLine:= 0;
           CurPosX  := 0;
           CurPosY  := 0;
           Ln:=FirstLn;
           IDE_Desktop^.QuickPaint;
         end;
   #118: {Ctrl-PgDn}
         begin
           StartCol := 0;
           if MaxLines<Ys then StartLine:=0
                          else StartLine:=MaxLines-Ys;
           CurPosX := 0;
           CurPosY := MaxLines-1;
           Ln:=EndLn;
           IDE_Desktop^.QuickPaint;
         end;
  #119: {Ctrl-Home}
        begin
         while Ln<>FirstLn do
           begin
             dec(CurPosY);
             Ln:=Ln^.prev;
             if CurPosY=StartLine then break;
           end;
         IDE_Desktop^.QuickPaint;
        end;
  #117: {Ctrl-End}
        begin
         while Ln<>EndLn do
           begin
             inc(CurPosY);
             Ln:=Ln^.next;
             if (CurPosY=MaxLines) or (CurPosY=StartLine+Ys-3) then break;
           end;
         IDE_Desktop^.QuickPaint;
        end;
 end;
 {Shift pressed}
 if not Key.Alt and not Key.Ctrl and Key.Shift and (Key.Ch=#0) then
   case Key.S of
   #82,
   #5 : {Shift-Ins}
        begin
          PasteBlock;
          IDE_Desktop^.QuickPaint;
        end;
   #83,
   #7 : {Shift-Del}
        begin
          CopyBlock;
          CutBlock;
          IDE_Desktop^.QuickPaint;
        end;
   'O': {Shift-End}
        begin
          i:=Length(Ln^.data);
          if not Ln^.selection then {nothing selected}
            begin
              SetSelection(Ln, CurPosX, i);
              CurPosX:=i;
            end
          else
            begin
              if (CurPosX=Ln^.sBegin) then
                SetSelection(Ln, Ln^.sEnd+1, i)
              else
                if (CurPosX=Ln^.sEnd+1) then
                  Ln^.sEnd:=i
                else
                  ClearSelection(Ln);
              CurPosX:=i;
              if (Ln^.sBegin=Ln^.sEnd) and (CurPosX=Ln^.sBegin) then
                ClearSelection(Ln);
            end;
          IDE_Desktop^.QuickPaint;
        end;
   'G': {Shift-Home}
        begin
          if not Ln^.selection then {nothing selected}
            begin
              if CurPosX<>0 then
                SetSelection(Ln, 0, CurPosX);
              CurPosX:=0;
            end
          else
            begin
              if (CurPosX=Ln^.sBegin) then
                Ln^.sBegin:=0
              else
                if (CurPosX=Ln^.sEnd+1) then
                  SetSelection(Ln, 0, Ln^.sBegin-1)
                else
                  ClearSelection(Ln);
              CurPosX:=0;
              if (Ln^.sBegin=Ln^.sEnd) and (CurPosX=Ln^.sBegin) then
                ClearSelection(Ln);
            end;
          IDE_Desktop^.QuickPaint;
        end;
   'H': {Shift-ArrowUp}
        begin
          if not Ln^.selection then {nothing selected}
            begin
              if CurPosY > 0 then
                begin
                  dec(CurPosY);
                  if CurPosX<>0 then
                    SetSelection(Ln, 0, CurPosX-1);
                  Ln:=Ln^.prev;
                  SetSelection(Ln, CurPosX, 255);
                end;
            end
          else
            begin
              if CurPosY > 0 then
                begin
                  SetSelection(Ln, 0, 255);
                  Ln:=Ln^.prev;
                  if CurPosX<>0 then SetSelection(Ln, CurPosX, 255);
                  dec(CurPosY);
                end;
            end;
          IDE_Desktop^.QuickPaint;
        end;
   'P': {Shift-ArrowDown}
        begin
          if not Ln^.selection then {nothing selected}
            begin
              if CurPosY < MaxLines then
                begin
                  SetSelection(Ln, CurPosX, 255);
                  Inc(CurPosY);
                  Ln:=Ln^.next;
                  if CurPosX<>0 then
                    SetSelection(Ln, 0, CurPosX-1);
                end;
            end
          else
            begin
              if CurPosY < MaxLines then
                begin
                  SetSelection(Ln, 0, 255);
                  Ln:=Ln^.next;
                  if CurPosX<>0 then SetSelection(Ln, 0, CurPosX-1);
                  Inc(CurPosY);
                end;
            end;
          IDE_Desktop^.QuickPaint;
        end;
   'K': {Shift-ArrowLeft}
        begin
          if not Ln^.selection then {nothing selected}
            begin
              if CurPosX > 0 then
                begin
                  Dec(CurPosX);
                  SetSelection(Ln, CurPosX, CurPosX);
                end
            end
          else
            begin
              if CurPosX > 0 then
                begin
                  Dec(CurPosX);
                  if (Ln^.sBegin=Ln^.sEnd) and (CurPosX=Ln^.sBegin) then
                    ClearSelection(Ln);
                  if (CurPosX+1=Ln^.sBegin) then
                    Ln^.sBegin:=CurPosX
                  else
                    if (CurPosX=Ln^.sEnd) then
                     Ln^.sEnd:=CurPosX-1
                  else
                     begin
                       ClearSelection(Ln);
                       SetSelection(Ln, CurPosX, CurPosX);
                     end;
                end;
            end;
          IDE_Desktop^.QuickPaint;
        end;
   'M': {Shift-ArrowRight}
        begin
          if not Ln^.selection then {nothing selected}
            begin
              SetSelection(Ln, CurPosX, CurPosX);
              inc(CurPosX);
            end
          else
            begin
              if (Ln^.sBegin=Ln^.sEnd) and (CurPosX=Ln^.sBegin) then
                ClearSelection(Ln);
              if (CurPosX=Ln^.sBegin) then
                Ln^.sBegin:=CurPosX+1
              else
                if (CurPosX=Ln^.sEnd+1) then
                  Ln^.sEnd:=CurPosX
                else
                  begin
                    ClearSelection(Ln);
                    SetSelection(Ln, CurPosX, CurPosX);
                  end;
              inc(CurPosX);
            end;
          IDE_Desktop^.QuickPaint;
        end;
   end;

 if IDE_Desktop^.DontDrawNext_B then exit;

 CPX:=0;CPY:=0; {- Paint wil set these -}
 {- An Arrowkey only involves moving the cursor, so don't redraw the screen -}
{ if (Key.Ch=#0) and not (Key.S in ['S','I','Q']) then
   SetCursor
 else
   begin
     if (Key.Ch=#0) and (Key.Ch = 'S') then}
       begin;
         Modified := True;
         SetCursor;
       end;
     inherited KeyEvent(Key);
     IDE_Desktop^.QuickPaint;
{   end;}
end;

Procedure IDE_SourceWindow.ShowCursorPos;
{Displays cursor position in the left bottom }
var s: string;
    c: integer;
begin
 if InFront then
   begin
     {IDE_Screen.tIns := not tIns;}
     if Moving then c:=cWinSize
               else c:=cWinFrame;
     Str(CurPosY+1, s);
     IDE_WriteXYC(Xo+10-Length(s)-1, Yo+Ys-1, ' ' + s + ':', c);
     Str(CurPosX+1, s);
     IDE_WriteXYC(Xo+11, Yo+Ys-1, s + ' ', c);
   end;
end;

procedure IDE_SourceWindow.SetCursor;
{Update blinking cursor moving while moving the scroller }
var s: string;
    i: integer;

    x, y: integer;

begin
  x := CurPosX-StartCol+1; {cursor pos, relative to border}
  if (x > Xs-2) then StartCol := CurPosX-(Xs-3); {move the screen}
  if (x < 1)    then StartCol := CurPosX;
  if StartCol > MaxCol then MaxCol := StartCol;
  if StartCol >= 255 then StartCol:=255;
  x := CurPosX-StartCol+1; {recalculate, some vars have been changed!}
  y := CurPosY-StartLine+1;
  if (y > Ys-2) then StartLine := CurPosY-(Ys-3);
  if (y < 1) then    begin
                       StartLine := CurPosY;
                       y:=1;
                     end;
  if StartLine > MaxLines then MaxLines := StartLine;
  y := CurPosY-StartLine+1;

  IDE_Screen.tIns := not tIns; {set state of [Ins]}

  {Update REAL cursor position -}
  IDE_Screen.CursorX := Xo + x;
  IDE_Screen.CursorY := Yo + y;
  if (x >= Xs-1) or (y >= Ys-1) or (x < 1) or (y < 1) or
     (x > IDE_Screen.Width) or (y > IDE_Screen.Height) then
    begin; {don't display cursor}
      IDE_Screen.CursorX:=$FF;
      IDE_Screen.CursorY:=$FF;
    end;

  ShowCursorPos;

  {blockhighlighting code...}
  s := ToUpper(StringAT);
  if (s = 'BEGIN') or (s = 'END') or (s = 'CASE') or (s = 'RECORD') or (s = 'ASM') or
     (PaintWinOnMove) then
    IDE_Desktop^.QuickPaint
  else
    IDE_UpdateVideo;
end;

procedure IDE_SourceWindow.Paint;

Var cX, cY: Integer; il: Longint;sCol, sBCol: Byte;sBNest: Integer;
    ActiveHiLite : HiLiteBlockType; {cWBack: Byte; }pCP: Longint;
    comNextLev: Longint;
    p: Lptr; {current line}

    procedure OutText(s: string; col: integer);
    var i     : byte;
        wx, wy: integer;

    begin
      for i:=1 to length(s) do
        begin
          wx := cX-StartCol;
          wy := cY;
          if (wx >= 0) and (wx < Xs-2) then
            begin
              if p^.selection and (p^.sBegin<=wX) and (p^.sEnd>=wX) then {text is selected}
                IDE_WriteXYC_Ch(wX+Xo+1, wY+Yo+1, s[i], (IDE.c.BlockSel) shl 4 + 1)
              else
                IDE_WriteXYC_Ch(wX+Xo+1, wY+Yo+1, s[i], Col);
            end;
          Inc(cX);
        end;
    end;

{    Procedure CalcCol;
    begin
     if ActiveHiLite.AsmSource then sCol := IDE.c.Syntax.AsmSrc;
     Case ActiveHiLite.typ of
     _Comment1,
     _Comment2,
     _Comment3: sCol := IDE.c.Syntax.Comment;
     _String : sCol := IDE.c.Syntax.Strings;
     end;
     sCol := (sCol and $F) + (cWinBack and $F0);
    end;
}
    Procedure ColourWord(s: string);
    var i, w: word;
    begin
      if s='' then exit;
     w:=$FF;
     s := ToUpper(s);
     sCol:=IDE.c.Syntax.None;
     for i:=0 to Res2Word_n do
      if s = Res2Word[i] then begin;sCol := IDE.c.Syntax.Reserved2;break;end;

     for i:=0 to ResWord_n do
      if s = ResWord[i] then begin;w:=i;sCol := IDE.c.Syntax.Reserved;break;end;

     {cWinBack := cWinBack and $F0;}

     if IDE.BlockHighlight then
       begin
         if (w <= 3) and
           (ActiveHiLite.NestLevel > 0) {or ((pCP >= il) and (pCP <= il+Length(s))))} then
          Inc(ActiveHiLite.NestLevel);

      if (w <= 4) and (ActiveHiLite.NestLevel = 1) then
        begin; {cWBack := IDE.c.BlockHi Shl 4;}PaintWinOnMove:=True;end;

      if (w = 4) and (ActiveHiLite.NestLevel > 0) then Dec(ActiveHiLite.NestLevel);
     end;
    end;

    procedure WriteHiLine(const s: string);
    var BreakChar: Char;
        cWord: String;
        wx,wy,l:integer;
        slen: integer;

    begin
      slen:=length(s);
      if slen = 0 then exit; {line is empty...}
      cX := 0;
      l:=1;
      repeat
        cWord := '';
        { search special characters}
        while (Pos(s[l], IdenSt) = 0) do
          begin
            cWord := cWord + s[l];
            inc(l);
            if l= slen + 1 then break;
          end;
        if (l=length(s)+1) then BreakChar := #10 else BreakChar:=s[l];
        if (l<=length(s)) then inc(l);

        if (IDE.SyntaxHighlight and pSyntaxHighlight) then
          begin
            if cWord<>'' then
              begin
                if ActiveHiLite.AsmSource then
                  begin
                    sCol := IDE.c.Syntax.AsmSrc;
                    if ToUpper(cWord)='END' then sCol := IDE.c.Syntax.Reserved;
                  end
                else
                  if (ActiveHiLite.typ = _none)  then
                    case cWord[1] of
                    '0'..'9','$': sCol := IDE.c.Syntax.Numbers;
                    '#'         : sCol := IDE.c.Syntax.Strings;
                    else          ColourWord(cWord);
                    end;
                OutText(cWord, (sCol and $F) + (cWinBack and $F0));
              end
            else
              case ActiveHiLite.typ of
              _Comment1: if BreakChar = '}' then
                           begin
                             if comNextLev>0 then Dec(comNextLev);
                             ActiveHiLite.typ := _none;
                             {sCol := IDE.c.Syntax.Comment;
                             {if (comNextLev=0) or not IDE.NestComment then
                                ActiveHiLite.typ := _none;}
                           end;
              _Comment2: if (BreakChar = ')') and (s[l-2] = '*') then
                           begin
                             if comNextLev>0 then Dec(comNextLev);
                             ActiveHiLite.typ := _none;
                             {sCol := IDE.c.Syntax.Comment;
                             {if (comNextLev=0) or (not IDE.NestComment) then begin;ActiveHiLite.typ := _none;end;}
                           end;
                            {case BreakChar of
                            '{': begin
                                    inc(comNextLev);
                                    ActiveHiLite.typ := _Comment1;
                                  end;
                             '(': if s[l] = #$2A then
                                    begin
                                      inc(comNextLev);
                                      ActiveHiLite.typ := _Comment2;
                                    end;
                                    }
                             {end;
                             if comNextLev<>0 then begin;sCol := IDE.c.Syntax.Comment;end;
                           end;}
                _string:  if BreakChar = #39 then begin;sCol := IDE.c.Syntax.Strings;ActiveHiLite.typ := _none;end;
                else       begin
                             if ActiveHiLite.AsmSource then if (ToUpper(cWord)='END') then
                             if (Pos(BreakChar, IdenSt)>0) then
                               begin;
                                 sCol := IDE.c.Syntax.Symbols;
                                 ActiveHiLite.AsmSource := False;
                               end;
                                 if ActiveHiLite.typ = _none then
                                 Case BreakChar of
                                 '{': begin;
                                        sCol := IDE.c.Syntax.Comment;
                                        ActiveHiLite.typ := _Comment1;
                                        Inc(comNextLev);
                                      end;
                                 '(': if s[l] = '*' then
                                        begin;
                                          sCol := IDE.c.Syntax.Comment;
                                          ActiveHiLite.typ := _Comment2;
                                          Inc(comNextLev);
                                        end;
                                 '-': if s[l] = '-' then
                                        begin;
                                          sCol := IDE.c.Syntax.Comment;
                                          ActiveHiLite.typ := _Comment3;
                                        end;
                                 #39: begin;
                                        sCol := IDE.c.Syntax.Strings;
                                        ActiveHiLite.typ := _string;
                                      end;
                                 #10,
                                 #32,
                                 #0,
                                 #255,
                                 ';': if (ToUpper(cWord)='ASM') then
                                        begin;
                                          sCol := IDE.c.Syntax.AsmSrc;
                                          ActiveHiLite.AsmSource := True;
                                        end;
                                 end;
                               end;
                              end;
                              if BreakChar<>#10 then OutText(BreakChar, (sCol and $F) + (cWinBack and $F0));
                            end
                            else
                            begin
                              sCol := IDE.c.Syntax.none;
                              OutText(cWord,  (sCol and $F) + (cWinBack and $F0));
                              if BreakChar<>#10 then OutText(BreakChar, (sCol and $F) + (cWinBack and $F0));
                            end;
          until l>length(s);
          Case ActiveHiLite.typ of
          _Comment3,
          _string: ActiveHiLite.typ := _none;
          end;
        {end;}
     if p^.sEnd=255 then
       begin
         for l:=Length(p^.data)+1 to 255 do
            begin
              wx := cX - StartCol;
              wy := cY;
              if (wx >= 0) and (wx < Xs-2) then
                IDE_WriteXYC_Ch(wX+Xo+1, wY+Yo+1, ' ', (IDE.c.BlockSel) shl 4 + 1);
              Inc(cX);
            end;
       end;

    end;

Var St: String;
     i: integer;

begin
 PaintWinOnMove := False;
 comNextLev := 0;
 if Pos('.PAS', ToUpper(Title)) > 0 then pSyntaxHighlight := True else pSyntaxHighlight := False;
 inherited Paint; {- Paint the window -}
 if Modified then IDE_WriteXYC_Ch(Xo+2, Yo+Ys-1, #15, cWinFrame);

 {- Display cursor position -}
 ShowCursorPos;

 ActiveHiLite := pTextHiStart;

 sCol := IDE.c.Syntax.none;
 if Ys > 3 then
   begin
     CalcTextHi;
     p:=FirstLn;
     {skip first lines that scroll off the screen}
     for i:=1 to StartLine do
       if p<>NIL then
         p:=p^.next;
     {display syntax highlighted source lines}
     for cY := 0 to Ys-3 do
       begin
         if p<>NIL then
           begin
             WriteHiLine(p^.data);
             p:=p^.next;
           end;
         if cY = 0 then pTextHiFirst := ActiveHiLite
       end;
   end;

 pTextHiEnd := ActiveHiLite;
end;

{- Quickly loads a text file into the window -}
Procedure IDE_SourceWindow.LoadFile(St: String);
var f       : text;
    Buf     : array[0..512] of byte;
    BufC, w : word;
    mX, mY  : word; {maximumX (columns) , maximumY (lines)}
    l       : longint;
    NrLines : longint;
    NrCol   : longint;

var  bufline : string;
     LastLn  : Lptr;

begin
 if FileExists(st) then
   begin
     assign(f, st);
     reset(f);
     MaxLines := MemAvail div sizeof(LineRec);
     NrLines := 0;
     NrCol:=0;
     while not eof(f) do
       begin
         readLn(f, BufLine);
         Ln^.data := BufLine;
         if length(BufLine)>NrCol then NrCol:=length(BufLine);
         LastLn   := Ln;
         Ln:=NewLine;
         Ln^.prev := LastLn;
         LastLn^.next := Ln;
         inc(NrLines);
       end;
       EndLn := Ln;
       EndLn^.next:=NIL;
       close(f);
   end;
 Ln:=FirstLn;
 MaxCol   := NrCol;
 MaxLines := NrLines;
 Modified := False;
 vScroll^.SetRange(0, MaxLines);
 IDE_Desktop^.QuickPaint;
end;

{- Quickly saves a text file into the window -}
Procedure IDE_SourceWindow.SaveFile(St: String);
var F: text;
     Buf: Array[0..514] of byte; w, mX, mY, BufC: Word; l: Longint;
    St2: String;
begin
 { Make backup }
 St2:=St;if Pos('.', St2)>0 then St2[0]:=Chr(Pos('.', St2)-1);St2:=St2+'.BAK';
 if FileExists(St) then
   begin
     if FileExists(St2) then DeleteFile(St2);
     RenameFile(St, St2);
   end;
 assign(f, St);
 rewrite(f);
 Ln := FirstLn;
 repeat
   WriteLn(f, Ln^.Data);
   Ln := Ln^.Next
 until Ln^.Next=NIL;
 close(f);
 modified := False;
 IDE_Desktop^.QuickPaint;
end;

function IDE_SourceWindow.StringAT: string;
{ returns current string/identifier the cursor is on }
var        i: integer;
    s_i, e_i: integer;
           s: string;
begin
  s := '';
  i:=CurPosX;
  if pos(Ln^.data[i], IdenSt) = 0 then {special symbol? yes, exit!}
    begin;
      while (i>0) and (pos(Ln^.data[i], IdenSt) = 0) do dec(i); { Find start of string }
      inc(i);
      s_i := i;
      while (i <= Length(Ln^.data)) and (pos(Ln^.data[i], IdenSt) = 0) do inc(i); { Find end of string }
      dec(i);
      e_i := i;
      for i:=s_i to e_i do s := s + Ln^.data[i]; { compose string }
    end;
 StringAT := s;
end;

Procedure IDE_SourceWindow.CalcTextHi;
var i, l, lend: integer;
    cWord: String[5];
    BreakChar: Char;
    comNextLev: Longint;
    s: string;
    p: Lptr;

begin
  if not IDE.SyntaxHighlight then exit;
  pTextHiStart.typ := _none;
  pTextHiStart.AsmSource := False;
  comNextLev := 0;
  p:=FirstLn;
  {scan first lines that scroll off the screen}
  for i:=1 to StartLine do
    if p<>NIL then
      begin
  l := 1;
  s:=p^.data;
  lend:=Length(s);
  while (l<lend) do
  begin
    case pTextHiStart.typ of
   _string : if s[l] = #39 then pTextHiStart.typ := _none;
   _Comment1,
   _Comment2,
   _Comment3: begin
                case s[l] of
                '{': Inc(comNextLev);
                '(': if s[l+1] = #$2A then Inc(comNextLev);
                '}': begin
                       if comNextLev>0 then Dec(comNextLev);
                       if (comNextLev=0) or (not IDE.NestComment) then begin;pTextHiStart.typ := _none;end;
                     end;
                ')': if (s[l-1] = #$2A) then begin
                       if comNextLev>0 then Dec(comNextLev);
                       if (comNextLev=0) or (not IDE.NestComment) then begin;pTextHiStart.typ := _none;end;
                     end;
                end;
                if (comNextLev<>0) and
                   (pTextHiStart.typ<>_Comment1) and
                   (pTextHiStart.typ<>_Comment2) then pTextHiStart.typ := _Comment1;
              end;
   _none:     begin
                case s[l] of
                #39:     pTextHiStart.typ := _String;
                '{':     begin;
                           pTextHiStart.typ := _Comment1;
                           Inc(comNextLev);
                         end;
                '(':     if s[l+1] = '*' then
                           begin;
                             pTextHiStart.typ := _Comment2;
                             Inc(comNextLev);
                           end;
                'A','a': if (ToUpper(cWord)='ASM') then
                           if (Pos(s[l-1], IdenSt)>0) then
                             if (Pos(s[l+3], IdenSt)>0) then
                               pTextHiStart.AsmSource := True;
                end;
                if pTextHiStart.AsmSource then
                if (Pos(s[l-1], IdenSt)>0) then
                if (Pos(s[l+3], IdenSt)>0) then
                if (ToUpper(cWord)='END') then pTextHiStart.AsmSource := False;
              end;
  end;
  Inc(l);
 end;
      p:=p^.next;
 end;
end;


Constructor IDE_DesktopType.Init;
var i, ii: word;
begin
 tWin.Init(16, 4);

 Menu_cItem := 0;

 {- Clear Menu structure -}
 for i:=1 to tMenuMax do
 begin
   tMenu[ i].NameSt      := '';
   tMenu[ i].HelpSt      := '';
   tMenu[ i].Accel.Ch    := #0;
   tMenu[ i].Accel.Alt   := False;
   tMenu[ i].Accel.Shift := False;
   tMenu[ i].Accel.Ctrl  := False;
   tMenu[ i].cItem       := 1;
  for ii:=1 to tSubMenuMax do
  begin
   tMenu[ i].SubMenu[ii].NameSt      := '';
   tMenu[ i].SubMenu[ii].HelpSt      := '';
   tMenu[ i].SubMenu[ii].Accel.Ch    := #0;
   tMenu[ i].SubMenu[ii].Accel.Alt   := False;
   tMenu[ i].SubMenu[ii].Accel.Shift := False;
   tMenu[ i].SubMenu[ii].Accel.Ctrl  := False;
  end;
 end;

 tMenu[ 1].NameSt := '~F~ile';
 tMenu[ 1].HelpSt := 'File management commands (Open, New, Save, etc.)';
 tMenu[ 1].Accel.Ch  := #33{'F'};
 tMenu[ 1].Accel.Alt := True;

 tMenu[ 1].SubMenu[1].NameSt := '~N~ew';
 tMenu[ 1].SubMenu[1].Accel.Ch := 'N';
 tMenu[ 1].SubMenu[1].ID       := cm_NewEdit;
 tMenu[ 1].SubMenu[1].HelpSt   := 'Create a new Edit window';

 tMenu[ 1].SubMenu[2].NameSt := '~O~pen...'#8'F3';
 tMenu[ 1].SubMenu[2].Accel.Ch := 'O';
 tMenu[ 1].SubMenu[2].ID       := cm_OpenEdit;
 tMenu[ 1].SubMenu[2].HelpSt   := 'Open a file in an Edit window';

 tMenu[ 1].SubMenu[3].NameSt := '~S~ave'#8'F2';
 tMenu[ 1].SubMenu[3].Accel.Ch := 'S';
 tMenu[ 1].SubMenu[3].ID       := cm_SaveEdit;
 tMenu[ 1].SubMenu[3].HelpSt   := 'Save the file in the Edit window';

 tMenu[ 1].SubMenu[4].NameSt := 'Save ~a~s...';
 tMenu[ 1].SubMenu[4].Accel.Ch := 'A';
 tMenu[ 1].SubMenu[4].ID       := cm_SaveAsEdit;
 tMenu[ 1].SubMenu[4].HelpSt   := 'Save the current Edit window under a different name';

 tMenu[ 1].SubMenu[5].NameSt := '-';

 tMenu[ 1].SubMenu[6].NameSt := '~D~OS Shell'#8'Alt-Z';
 tMenu[ 1].SubMenu[6].Accel.Ch := 'D';
 tMenu[ 1].SubMenu[6].ID       := cm_DOSShell;
 tMenu[ 1].SubMenu[6].HelpSt   := 'Shell to DOS';

 tMenu[ 1].SubMenu[7].NameSt := 'E~x~it'#8'Alt-X';
 tMenu[ 1].SubMenu[7].Accel.Ch := 'X';
 tMenu[ 1].SubMenu[7].ID       := cm_Exit;
 tMenu[ 1].SubMenu[7].HelpSt   := 'Exit P32IDE';


 tMenu[ 2].NameSt := '~E~dit';
 tMenu[ 2].HelpSt := 'Cut-and-paste editing commands';
 tMenu[ 2].Accel.Ch  := #18{'E'};
 tMenu[ 2].Accel.Alt := True;

 tMenu[ 2].SubMenu[1].NameSt := 'Cu~t~'#8'Shift-Del';
 tMenu[ 2].SubMenu[1].Accel.Ch := 'T';
 tMenu[ 2].SubMenu[1].ID       := cm_Cut;
 tMenu[ 2].SubMenu[1].HelpSt   := 'Remove the selected text and put it in the clipboard';

 tMenu[ 2].SubMenu[2].NameSt := '~C~opy'#8'Ctrl-Ins';
 tMenu[ 2].SubMenu[2].Accel.Ch := 'C';
 tMenu[ 2].SubMenu[2].ID       := cm_Copy;
 tMenu[ 2].SubMenu[2].HelpSt   := 'Copy the selected text into the clipboard';

 tMenu[ 2].SubMenu[3].NameSt := '~P~aste'#8'Shift-Ins';
 tMenu[ 2].SubMenu[3].Accel.Ch := 'P';
 tMenu[ 2].SubMenu[3].ID       := cm_Paste;
 tMenu[ 2].SubMenu[3].HelpSt   := 'Insert the selected text from the clipboard at the cursor position';

 tMenu[ 2].SubMenu[4].NameSt := 'C~l~ear'#8'Ctrl-Del';
 tMenu[ 2].SubMenu[4].Accel.Ch := 'l';
 tMenu[ 2].SubMenu[4].ID       := cm_Clear;
 tMenu[ 2].SubMenu[4].HelpSt   := 'Delete the selected text';

 tMenu[ 2].SubMenu[5].NameSt := '-';

 tMenu[ 2].SubMenu[6].NameSt := '~S~how clipboard';
 tMenu[ 2].SubMenu[6].Accel.Ch := 'S';
 tMenu[ 2].SubMenu[6].ID       := cm_Clipboard;
 tMenu[ 2].SubMenu[6].HelpSt   := 'Open the clipboard window';


 tMenu[ 3].NameSt := '~S~earch';
 tMenu[ 3].HelpSt := 'Searching commands';
 tMenu[ 3].Accel.Ch  := #31{'S'};
 tMenu[ 3].Accel.Alt := True;

 tMenu[ 3].SubMenu[1].NameSt := '~F~ind...';
 tMenu[ 3].SubMenu[1].Accel.Ch := 'F';
 tMenu[ 3].SubMenu[1].ID       := cm_Find;
 tMenu[ 3].SubMenu[1].HelpSt   := 'Search for text';

 tMenu[ 3].SubMenu[2].NameSt := '~R~eplace...';
 tMenu[ 3].SubMenu[2].Accel.Ch := 'R';
 tMenu[ 3].SubMenu[2].ID       := cm_Replace;
 tMenu[ 3].SubMenu[2].HelpSt   := 'Search for text and replace it with new text';

 tMenu[ 3].SubMenu[3].NameSt := '~S~earch again';
 tMenu[ 3].SubMenu[3].Accel.Ch := 'S';
 tMenu[ 3].SubMenu[3].ID       := cm_SearchAgain;
 tMenu[ 3].SubMenu[3].HelpSt   := 'Repeat last search';

 tMenu[ 4].NameSt := '~R~un';
 tMenu[ 4].HelpSt := 'Execution commands';
 tMenu[ 4].Accel.Ch  := #19{'R'};
 tMenu[ 4].Accel.Alt := True;

 tMenu[ 4].SubMenu[1].NameSt := '~R~un'#8'Ctrl-F9';
 tMenu[ 4].SubMenu[1].Accel.Ch := 'R';
 tMenu[ 4].SubMenu[1].ID       := cm_Run;
 tMenu[ 4].SubMenu[1].HelpSt   := 'Run the current program';


 tMenu[ 5].NameSt := '~C~ompile';
 tMenu[ 5].HelpSt := 'Source Building commands';
 tMenu[ 5].Accel.Ch  := #46{'C'};
 tMenu[ 5].Accel.Alt := True;

 tMenu[ 5].SubMenu[1].NameSt := '~C~ompile'#8'Alt-F9';
 tMenu[ 5].SubMenu[1].Accel.Ch := 'C';
 tMenu[ 5].SubMenu[1].ID       := cm_Compile;
 tMenu[ 5].SubMenu[1].HelpSt   := 'Compile source file';

 tMenu[ 5].SubMenu[2].NameSt := '~L~ink';
 tMenu[ 5].SubMenu[2].Accel.Ch := 'L';
 tMenu[ 5].SubMenu[2].ID       := cm_Link;
 tMenu[ 5].SubMenu[2].HelpSt   := 'Link precompiled source';

 tMenu[ 5].SubMenu[3].NameSt := '~B~uild';
 tMenu[ 5].SubMenu[3].Accel.Ch := 'B';
 tMenu[ 5].SubMenu[3].ID       := cm_Build;
 tMenu[ 5].SubMenu[3].HelpSt   := 'Rebuild all source files';

 tMenu[ 5].SubMenu[4].NameSt := '-';

 tMenu[ 5].SubMenu[5].NameSt := '~I~nformation...';
 tMenu[ 5].SubMenu[5].Accel.Ch := 'I';
 tMenu[ 5].SubMenu[5].ID       := cm_InfoBOX;
 tMenu[ 5].SubMenu[5].HelpSt   := 'Show status information';

 tMenu[ 6].NameSt := '~D~ebug';
 tMenu[ 6].HelpSt := 'Various Commands';
 tMenu[ 6].Accel.Ch  := #32{'D'};
 tMenu[ 6].Accel.Alt := True;

 tMenu[ 6].SubMenu[1].NameSt := '~V~iew assembly source';
 tMenu[ 6].SubMenu[1].Accel.Ch := 'V';
 tMenu[ 6].SubMenu[1].ID       := cm_AsmWindow;
 tMenu[ 6].SubMenu[1].HelpSt   := 'Show generated assembly source';

 tMenu[ 7].NameSt := '~T~ools';
 tMenu[ 7].HelpSt := 'User Installed Tools and preferences';
 tMenu[ 7].Accel.Ch  := #20{'T'};
 tMenu[ 7].Accel.Alt := True;

 tMenu[ 7].SubMenu[1].NameSt   := '~U~ser Screen'#8'Alt-F5';
 tMenu[ 7].SubMenu[1].Accel.Ch := 'U';
 tMenu[ 7].SubMenu[1].ID       := cm_UserScreen;
 tMenu[ 7].SubMenu[1].HelpSt   := 'Show the full screen user output';

 tMenu[ 7].SubMenu[2].NameSt   := 'User ~W~indow'#8'Alt-Q';
 tMenu[ 7].SubMenu[2].Accel.Ch := 'W';
 tMenu[ 7].SubMenu[2].ID       := cm_UserWindow;
 tMenu[ 7].SubMenu[2].HelpSt   := 'Show the full screen user output';

 tMenu[ 7].SubMenu[3].NameSt   := '-';

 tMenu[ 7].SubMenu[4].NameSt   := '~A~SCII Table';
 tMenu[ 7].SubMenu[4].Accel.Ch := 'A';
 tMenu[ 7].SubMenu[4].ID       := cm_ASCIIWin;
 tMenu[ 7].SubMenu[4].HelpSt   := 'Show''s an ASCII Table';

 tMenu[ 8].NameSt := '~O~ptions';
 tMenu[ 8].HelpSt := 'Set compiler options';
 tMenu[ 8].Accel.Ch  := #24{'O'};
 tMenu[ 8].Accel.Alt := True;

 tMenu[ 8].SubMenu[1].NameSt   := '~C~ompiler...';
 tMenu[ 8].SubMenu[1].Accel.Ch := 'C';
 tMenu[ 8].SubMenu[1].ID       := cm_CompOptions;
 tMenu[ 8].SubMenu[1].HelpSt   := 'Set compiler options';

 tMenu[ 8].SubMenu[2].NameSt   := '~E~ditor...';
 tMenu[ 8].SubMenu[2].Accel.Ch := 'E';
 tMenu[ 8].SubMenu[2].ID       := cm_EditOptions;
 tMenu[ 8].SubMenu[2].HelpSt   := 'Set editor options';

 tMenu[ 9].NameSt := '~W~indow';
 tMenu[ 9].HelpSt := 'Windowing commands';
 tMenu[ 9].Accel.Ch  := #17{'W'};
 tMenu[ 9].Accel.Alt := True;

 tMenu[10].NameSt := '~H~elp';
 tMenu[10].HelpSt := 'Help commands (No Online Help yet)';
 tMenu[10].Accel.Ch  := #35{'H'};
 tMenu[10].Accel.Alt := True;

 tMenu[10].SubMenu[1].NameSt   := '~A~bout'#8'Alt-A';
 tMenu[10].SubMenu[1].Accel.Ch := 'A';
 tMenu[10].SubMenu[1].ID       := cm_AboutWindow;
 tMenu[10].SubMenu[1].HelpSt   := 'Show version information';

 DontDrawNext_B := False;

 IDE_DesktopType.Paint;
end;

Destructor IDE_DesktopType.Done;
 Procedure CloseWindow(pW: pIDE_WindowType); far;
 begin
  pW^.done;
 end;

begin
{--** NOTE: This give RunTime errors?? y?  **--}
{ tWin.ForEach(@CloseWindow);}
{ tMenu.DeleteAll;}
 tWin.DeleteAll;
{ tWin.Done;}
end;

Procedure IDE_DesktopType.QuickPaint;
var pW: pIDE_WindowType;
begin
 if DontDrawNext_B then begin;DontDrawNext_B := False;exit;end;
 if tWin.count > 0 then
 begin
  pW := tWin.At(tWin.Count-1);
  pW^.Paint;
 end;

 MenuPaint;

 IDE_UpdateVideo;
end;

Procedure IDE_DesktopType.DontDrawNext;
begin
 DontDrawNext_B := True;
end;

procedure IDE_DesktopType.Paint;

   procedure PaintWin(pW: pIDE_WindowType); far;
   begin
     if pW <> nil then pW^.Paint;
   end;

var i,j: word;

begin
  if DontDrawNext_B then exit;

  IDE_Screen.CursorX := $FF;
  IDE_Screen.CursorY := $FF;

  { Paint the background }
  for i:=1 to IDE_Screen.Height-2 do
     for j:=0 to IDE_Screen.Width-1 do
       IDE_WriteXYC_Ch(j,  i, '°', IDE_cDesktop);

  { Paint the windows }
  if (@tWin <> nil) then
    tWin.ForEach(@PaintWin);

  QuickPaint;
end;

Procedure IDE_DesktopType.MenuPaint;
var
   xPos,
   cMenu,
   sxPos: integer;
   HLPSt: string;

   procedure DrawMenu(i: Word);
   begin
     if (cMenu = Menu_cItem) then
       IDE_WriteXYC(xPos, 0, ' '+TildaToC(tMenu[i].NameSt, IDE_aMenu)+' ', IDE_cMenuH)
     else
       IDE_WriteXYC(xPos, 0, ' '+TildaToC(tMenu[i].NameSt, IDE_aMenu)+' ', IDE_cMenu);
     if (cMenu = Menu_cItem) then sxPos := xPos;
     inc(xPos, LengthC(TildaToC(tMenu[i].NameSt, IDE_aMenu))+2);
   end;

   procedure ShowSubMenu(cM: Word);
   var xS, i, w: Integer;St, cSt: String;
   begin
     IDE_Screen.CursorX := $FF;
     IDE_Screen.CursorY := $FF;
     cSubMenu.nItem := 0;
     for i := 1 to tSubMenuMax do
        if LengthT(tMenu[cM].SubMenu[i].NameSt) > 0 then
          inc(cSubMenu.nItem)
        else
          break;
     { Find Max-Width }
     xS := 0;
     for i := 1 to cSubMenu.nItem do
        if Pos(#8,tMenu[cM].SubMenu[i].NameSt)>0 then
          begin
            if LengthT(tMenu[cM].SubMenu[i].NameSt)+3 > xS then
              xS := LengthT(tMenu[cM].SubMenu[i].NameSt)+3;
          end
        else
          if LengthT(tMenu[cM].SubMenu[i].NameSt) > xS then
            xS := LengthT(tMenu[cM].SubMenu[i].NameSt);

     cSubMenu.sX := sxPos+1;
     cSubMenu.eX := sxPos+xS;

     { Clip window to side of screen }
     if cSubMenu.eX >= IDE_Screen.Width then
       begin
         sxPos := IDE_Screen.Width-xS-5;
         cSubMenu.sX := sxPos+1;
         cSubMenu.eX := sxPos+xS;
       end;

     if tMenu[cM].cItem > 0 then
       HLPSt := tMenu[cM].SubMenu[tMenu[cM].cItem].HelpSt;

     St := ' Ú';
   for i:=0 to xS+1 do St := St + 'Ä';
   St := St + '¿ ';
  IDE_WriteXYC(sxPos-1, 1, St, IDE_cMenu);

  for i:=0 to 24 do
  begin
   if tMenu[cM].SubMenu[i+1].NameSt = '' then break;
   cSt := TildaToC(tMenu[cM].SubMenu[i+1].NameSt, IDE_aMenu);

   if cSt[1] = '-' then
   begin
    St := ' Ã';
    for w:=0 to xS+1 do St := St + 'Ä';
    St := St + '´ ';
    IDE_WriteXYC(sxPos-1, i+2, St, IDE_cMenu);
    IDE_Grey(sxPos-1+Length(St), i+2);
    IDE_Grey(sxPos+Length(St), i+2);
   end
   else
   begin
    St := ' ³';
    for w:=0 to xS+1 do St := St + ' ';

    St := St + '³ ';
    IDE_WriteXYC(sxPos-1, i+2, St, IDE_cMenu);
    IDE_Grey(sxPos-1+Length(St), i+2);
    IDE_Grey(sxPos+Length(St), i+2);

    if (Pos(#8, cSt) > 0) then
     begin
      St := cSt;
      w := Pos(#8, cSt);
      Delete(St, 1, w);
      cSt[0] := Chr(w-1);
      IDE_WriteXYC(sxPos-1+3, i+2, cSt, IDE_cMenu);
      IDE_WriteXYC(sxPos-1+3 + xS - Length(St), i+2, St, IDE_cMenu);
     end
    else
     IDE_WriteXYC(sxPos-1+3, i+2, cSt, IDE_cMenu);

    if (i+1=tMenu[cM].cItem) then
     for w:=0 to xS+1 do IDE_SetBC(sxPos+1+W, i+2, IDE_cMenuH Shr 4);
   end;

  end;

   w := i;
   St := ' À';
   for i:=0 to xS+1 do St := St + 'Ä';
   St := St + 'Ù ';
   IDE_WriteXYC(sxPos-1, w+2, St, IDE_cMenu);
   IDE_Grey(sxPos-1+Length(St), w+2);
   IDE_Grey(sxPos+Length(St), w+2);
   for i:=1 to xS+7 do IDE_Grey(sxPos+i-1, w+3);

 end;
var pW: pIDE_WindowType;
     i: word;
begin
  if tWin.Count>0 then
  begin
   pW := tWin.At(tWin.Count-1);
   if pW^.Moving then begin;IDE_BottomHelp(IDE_BottomHelpST);exit;end;
  end;

  {- Clear the Top and Bottom Lines -}
  for i:=0 to IDE_Screen.Width-1 do
    IDE_WriteXYC_Ch(i, 0, ' ', IDE_cMenu);

  for i:=0 to IDE_Screen.Width-1 do
    IDE_WriteXYC_Ch(i, IDE_Screen.Height-1, ' ', IDE_cMenu);
  IDE_BottomHelp('#1');

  {- Draw the top menu -}
  xPos := 1; for cMenu := 1 to tMenuMax do DrawMenu(cMenu);
  {- Show help line -}
  if Menu_cItem > 0 then
  begin
   HLPSt := tMenu[Menu_cItem].HelpSt;
   {- Display Sub-Menu -}
   ShowSubMenu(Menu_cItem);
   IDE_BottomHelp(HlpSt);
  end;
end;

Procedure IDE_DesktopType.IDE_BottomHelp(St: String);
var i: byte;
begin
 IDE_BottomHelpST := St;
 if St = '' then St := TildaToC(' ~F1~ Help ³ ', IDE_aMenu) + '~8No help available' else
 if St = '#1' then St := {TildaToC(' ~F1~ Help ³ ') + }' ~8No Shortcuts available' else
 if St[1] = '#' then begin;Delete(St,1,1);St := ' ' + TildaToC(St, IDE_aMenu);end else
   St := TildaToC(' ~F1~ Help ³ ', IDE_aMenu) + TildaToC(St, IDE_aMenu);
 St:=St+' Free: '+Numb(MemAvail) + '  '+ Numb(MMouse_GetX)+':'+ Numb(MMouse_GetY);
 for i:=0 to IDE_Screen.Width-1 do
  IDE_WriteXYC_CH(i, IDE_Screen.Height-1, ' ', IDE_cMenu);
 IDE_WriteXYC(0, IDE_Screen.Height-1, St, IDE_cMenu);
end;

Procedure IDE_DesktopType.ProcessMouseEvent;
Var ml,mm,mr:boolean;mx,my: integer;pWin: pIDE_WindowType;
    ModalFound: Boolean;

 Procedure CheckInFront(pW: pIDE_WindowType); far;
 begin
  if pW^.Modal then begin;pWin := nil;ModalFound := True;end;
  if (mx >= pW^.Xo) and (mx < pW^.Xo+pW^.Xs) and
     (my >= pW^.Yo) and (my < pW^.Yo+pW^.Ys) then
      pWin := pW;
 end;

begin
 ml := IDE_MouseL;
 mr := IDE_MouseR;
 mm := (ml and mr);
 mx := IDE_MouseXL;
 my := IDE_MouseYL;

 if Menu_cItem = 0 then
 begin
  pWin := nil;
  ModalFound := False;
  tWin.ForEach(@CheckInFront);
  { Found Window }
  if pWin <> nil then
    begin
      { Is window in front? }
      if (pWin = tWin.At(tWin.Count-1)) {or (Key_Ctrl)} then
        { Window is infront so pass on the mouse information }
        pWin^.MouseEvent(ml,mm,mr,mx-pWin^.Xo,my-pWin^.Yo)
      else
    { Window is not infront so bring to front first if clicked }
        begin
          if ml then
            begin
              tWin.Delete(pWin);
              tWin.Insert(pWin);
              IDE_Desktop^.Paint;
              if ml then repeat until not IDE_MouseL;
            end;
        end;
    end;
 end;
 { Send the MenuHandler the mousepress }
 Menu_cItem := 0;
 if not ModalFound then
 if (my = 0) and (ml) then MenuHandler(NoKey, mx, my, Ml, Mm, Mr);

end;

Procedure IDE_DesktopType.ProcessKeyEvent;
Var  k: KeyType;
    pW: pIDE_WindowType;

begin
  GetKey(k);
  if tWin.Count>0 then              { any window opened? }
    begin
      pW := tWin.At(tWin.Count-1);  { get active window  }
      if pW^.Modal then             { modal -> don't access menus/shortcuts }
        begin
          pW^.KeyEvent(K);          { send key to the active window }
          exit;                     { exit handler                  }
        end;
    end;
  { shortcut handler }
  case k.Alt of
  TRUE: case k.S of { when [Alt] pressed -}
        #106: begin
                pW := tWin.At(tWin.Count-1);
                pW^.CloseWindow;
                pW^.Done;
                IDE_Desktop^.Paint;
              end;
         #45: {Alt-X}
              cmSend(cm_Exit);
         #44: {Alt-Z}
              cmSend(cm_DOSShell);
         #49: {Alt-N}
              cmSend(cm_NewEdit);
         #38: {Alt-L}
              cmSend(cm_LoadFile);
         #16: {Alt-Q}
              cmSend(cm_UserWindow);
         #30: {Alt-A}
              cmSend(cm_AboutWindow);
        #108: {Alt-F5}
              cmSend(cm_UserScreen);
        #112: begin
                cmSend(cm_Compile);
                cmSend(cm_Link);
              end;
         else
              MenuHandler(k, 0, 0, False, False, False);
         end;
  FALSE: begin
   { F2 }   if (k.S=#60) then cmSend(cm_SaveEdit)
            else
     { F3 }   if (k.S=#61) then cmSend(cm_LoadFile)
              else
      {Ctrl-F9} if (k.Ctrl) and (k.S = #102) then
                  begin
                    {cmSend(cm_BUILD);}
                    cmSend(cm_Compile);
                    cmSend(cm_Link);
                    cmSend(cm_RUN);
                  end
                else {Send the key to a window}
                  if tWin.Count>0 then
                    begin
                      pW := tWin.At(tWin.Count-1);
                      pW^.KeyEvent(K);
                    end;
         end;
  end;
end;

Procedure IDE_DesktopType.MenuHandler(cKey: KeyType; mX, mY: Integer;mLeft, mMiddle, mRight: Boolean);
Label SelectMenu, SelectSubMenu, EndSelectMenu, SelectMenuEND;
Var xPos, cMenu, cSMenu: Integer; nMx, nMy: Integer;
var nCMD: Word;
 Procedure MouseMenuCheck(i: word);
 begin
  if nMx >= xPos then
  begin
   Inc(xPos, LengthC(TildaToC(tMenu[i].NameSt, IDE_aMenu))+2);
   if nMx <= xPos then Menu_cItem := i;
  end;
 end;
 Procedure KeyMenuCheck(i: word);
 begin
   if cKey.S = tMenu[i].Accel.Ch then Menu_cItem := i;
 end;
 Procedure KeySubMenuCheck(i: Word);
 begin
   if
      (UpCase(cKey.Ch) = UpCase(tMenu[cMenu].SubMenu[i].Accel.Ch)) then
       begin
        tMenu[cMenu].cItem := i;
        nCMD := tMenu[cMenu].SubMenu[i].ID;
       end;
 end;
begin
nCMD := 0;


SelectMenu:
 {- Mouse selection of Menu -}
   if (IDE_MouseY = 0) and (IDE_MouseL) then
   begin
    nMx := IDE_MouseX;
    Menu_cItem := 0;
    xPos := 1;
    for cMenu := 1 to tMenuMax do MouseMenuCheck(cMenu);
    if Menu_cItem > 0 then tMenu[Menu_cItem].cItem := 0;
   end;
 {- Keyboard Selection -}
   if (cKey.Alt) then
     begin
       for cMenu := 1 to tMenuMax do KeyMenuCheck(cMenu);
     end;

SelectMenuEND:

 if Menu_cItem > 0 then
   IDE_Desktop^.Paint
 else
    Goto EndSelectMenu;

cMenu := Menu_cItem;

SelectSubMenu:
nCMD := 0;

 if IDE_MouseL then
  Repeat until (IDE_MouseMoved) or KeyPressed
 else
  Repeat until ((IDE_MouseMoved) and (IDE_MouseL)) or (Keypressed);

 {- Keyboard Selection -}

   if keypressed then
     begin
       GetKey(cKey);
       if (cKey.Alt) then Goto SelectMenu;
       if not cKey.Alt then
         begin
           if cKey.Ch<>#0 then
             begin
               for cSMenu := 1 to tSubMenuMax do KeySubMenuCheck(cSMenu);
               if cKey.Ch = #13 then nCMD := tMenu[cMenu].SubMenu[tMenu[cMenu].cItem].ID;
               if nCMD > 0 then goto EndSelectMenu;
             end;
           if cKey.Ch=#0 then
             case cKey.S of
             'G':  tMenu[cMenu].cItem := 1; {- Home -}
             'O':  tMenu[cMenu].cItem := cSubMenu.nItem; {- End -}
             'K':  begin {- Left -}
                     if Menu_cItem > 1 then Dec(Menu_cItem) else Menu_cItem := tMenuMax;
                     goto SelectMenuEND;
                   end;
             'M':  begin {- Right -}
                     if Menu_cItem < tMenuMax then Inc(Menu_cItem) else Menu_cItem := 1;
                     goto SelectMenuEND;
                   end;
             'H':  begin {- Up -}
                     if tMenu[cMenu].cItem > 1 then Dec(tMenu[cMenu].cItem)
                                               else tMenu[cMenu].cItem := cSubMenu.nItem;
                     if tMenu[cMenu].SubMenu[tMenu[cMenu].cItem].NameSt = '-' then
                       Dec(tMenu[cMenu].cItem);
                   end;
             'P':  begin {- Down -}
                     if tMenu[cMenu].cItem < cSubMenu.nItem then Inc(tMenu[cMenu].cItem)
                                                            else tMenu[cMenu].cItem := 1;
                     if tMenu[cMenu].SubMenu[tMenu[cMenu].cItem].NameSt = '-' then
                       inc(tMenu[cMenu].cItem);
                   end;
             'I':  begin {- Page-Up -}
                     if tMenu[cMenu].cItem > 1 then Dec(tMenu[cMenu].cItem);
                     if tMenu[cMenu].SubMenu[tMenu[cMenu].cItem].NameSt = '-' then
                       Dec(tMenu[cMenu].cItem);
                     while (tMenu[cMenu].SubMenu[tMenu[cMenu].cItem].NameSt <> '-') and (tMenu[cMenu].cItem > 1) do
                       Dec(tMenu[cMenu].cItem);
                   end;
             'Q':  begin {- Page-Down -}
                     if tMenu[cMenu].cItem < cSubMenu.nItem then Inc(tMenu[cMenu].cItem);
                     While (tMenu[cMenu].SubMenu[tMenu[cMenu].cItem].NameSt <> '-') and
                           (tMenu[cMenu].cItem < cSubMenu.nItem) do Inc(tMenu[cMenu].cItem);
                     if tMenu[cMenu].SubMenu[tMenu[cMenu].cItem].NameSt = '-' then
                       Inc(tMenu[cMenu].cItem);
                   end;
             end;
     end;
     IDE_Desktop^.Paint;
     if (cKey.Ch = #27) or (cKey.Ch = #1) then Goto EndSelectMenu;
   end;

if (IDE_MouseL) and (IDE_MouseY = 0) then Goto SelectMenu;
if (IDE_MouseL) and (IDE_MouseY > 0) then
begin
 Repeat
  nCMD := 0;
  tMenu[cMenu].cItem := 0;
  if (IDE_MouseX >= cSubMenu.sX) and (IDE_MouseX <= cSubMenu.eX+2) and
     (IDE_MouseY >= 2) and (IDE_MouseY <= 2+cSubMenu.nItem) then
     begin
      tMenu[cMenu].cItem := IDE_MouseY-1;
      nCMD := tMenu[cMenu].SubMenu[tMenu[cMenu].cItem].ID;
      IDE_Desktop^.QuickPaint;
     end;

  if (IDE_MouseY = 0) then Goto SelectMenu;
  repeat until (IDE_MouseMoved);
 until not IDE_MouseL;
 if (IDE_MouseY = 0) then Goto SelectMenu;
 Goto EndSelectMenu
end;

nCMD := 0;
if tMenu[cMenu].cItem = 0 then
begin
 tMenu[cMenu].cItem := 1;
 IDE_Desktop^.Paint;
end;

 goto SelectSubMenu;
EndSelectMenu:

  Menu_cItem := 0;
  IDE_Desktop^.Paint;
  if nCMD > 0 then cmSend(nCMD);
end;

{+--------------------------------------------------------------------------+}
{|                                                                          |}
{|    Message Box                                                           |}
{|    Contains text and a OK button, always centered on screen              |}
{|                                                                          |}
{+--------------------------------------------------------------------------+}

type
   pMessageBox = ^MessageBox;

    MessageBox = object(IDE_DialogWindow)
                   pOKButton: pButton;
                   constructor Init(nXs,nYs: Word; nTitle: String);
                   destructor Done; virtual;
                   procedure Paint; virtual;
                   procedure CloseWindow; virtual;
                   procedure DoEvents; virtual;
                 end;

constructor MessageBox.init(nXs,nYs: Word; nTitle: string);
begin
  New(pOKButton, Init((nXs-9) div 2, nYs - 3, 9, 1, '~O~K'));
  inherited Init(Centered, Centered, nXs, nYs, nTitle);
  tItem.Insert(pOKButton);
  pOKButton^.GotFocus := TRUE; { set as default }
  IDE_Desktop^.QuickPaint;
end;

destructor MessageBox.Done;
begin
  Dispose(pOkButton, Done);
  inherited Done;
end;

procedure MessageBox.Paint;
begin
 inherited Paint;
end;

procedure MessageBox.CloseWindow;
begin
  pOKButton^.IsPressed :=TRUE;
end;

procedure MessageBox.DoEvents;
begin
  repeat
    ProcessEvents;
    if pOKButton^.IsPressed then break;
  until false;
end;

{+--------------------------------------------------------------------------+}
{|                                                                          |}
{|    About box                                                             |}
{|                                                                          |}
{+--------------------------------------------------------------------------+}

type
   pAboutDialog = ^AboutDialog;

    AboutDialog = object(MessageBox)
                    constructor Init(nXs,nYs: Word; nTitle: String);
                    procedure Paint; virtual;
                  end;

constructor AboutDialog.init(nXs,nYs: Word; nTitle: string);
begin
  inherited Init(38, 18, nTitle);
  IDE_Desktop^.QuickPaint;
end;

procedure AboutDialog.Paint;
begin
 inherited Paint;
 IDE_WriteXYC(Xo+2, Yo+ 2, '     P32 IDE version '+P32IDE_Ver, $70);
 IDE_WriteXYC(Xo+2, Yo+ 4, '      by Michael Goddard', $70);
 IDE_WriteXYC(Xo+2, Yo+ 5, '    (magnesium@hehe.com/', $70);
 IDE_WriteXYC(Xo+2, Yo+ 6, '   cgoddard@ozemail.com.au)', $70);

 IDE_WriteXYC(Xo+2, Yo+ 8, '    P32 compiler '+P32_Version, $70);
 IDE_WriteXYC(Xo+1, Yo+10, ' by Johan Prins (jprins@knoware.nl)', $70);
 IDE_WriteXYC(Xo+1, Yo+11, '       http://surf.to/p32', $70);
 IDE_WriteXYC(Xo+1, Yo+13, ' Compiled on: ' + compiledate,  $70);
end;

{+--------------------------------------------------------------------------+}
{|                                                                          |}
{|    Error message box                                                     |}
{|                                                                          |}
{+--------------------------------------------------------------------------+}

type
   pErrMsgDialog = ^ErrMsgDialog;

    ErrMsgDialog = object(MessageBox)
                     Error: string;
                     constructor Init(err: string);
                     procedure Paint; virtual;
                   end;

constructor ErrMsgDialog.Init(err: string);
var i: integer;
begin
  Error:=err;
  i:=length(error)+4;
  if i < 15 then i:=15;
  inherited Init(i, 8, 'Error!');
  IDE_Desktop^.QuickPaint;
end;

procedure ErrMsgDialog.Paint;
begin
  inherited Paint;
  IDE_WriteXYC(Xo+2, Yo+2, Error, cText);
end;

procedure ErrorBox(s: string);
var Box: pErrMsgDialog;
begin
  New(Box, Init(s));
  Box^.DoEvents;
  Dispose(Box, Done);
end;

{+--------------------------------------------------------------------------+}
{|                                                                          |}
{|    Compiler info box                                                     |}
{|                                                                          |}
{+--------------------------------------------------------------------------+}

type
   pInformationDialog = ^InformationDialog;
    InformationDialog = object(MessageBox)
                          constructor Init(nXs, nYs: Word; nTitle: String);
                          procedure Paint; virtual;
                        end;


Constructor InformationDialog.Init(nXs, nYs: Word; nTitle: String);
begin
  inherited Init(nXs, nYs, nTitle);
  IDE_Desktop^.QuickPaint;
end;

Procedure InformationDialog.Paint;
var w: word;
    s: string;
begin
  inherited Paint;

  IDE_WriteXYC(Xo+3, Yo+2, 'Memory information: ', $7F {cText});
  IDE_WriteXYC(Xo+3, Yo+3, 'Free Heap (REAL): '+PadComma(MemAvail), cText);
  if Sym.LastProgST = '' then
    IDE_WriteXYC(Xo+3, Yo+4, 'Last Program    : none', cText)
  else
    begin
      IDE_WriteXYC(Xo+3, Yo+4, 'Last Program    : '+Sym.LastProgST, cText);
      IDE_WriteXYC(Xo+3, Yo+5, '       Lines    : '+PadComma(Sym.cLine)+'/'+PadComma(Sym.tLine), cText);
    end;

  asm
     mov ax, sp
     mov w,  ax
  end;
  IDE_WriteXYC(Xo+3, Yo+6, 'Stack Free (SP) : '+PadComma(w), cText);

  CheckUpCPU;
  IDE_WriteXYC(Xo+3, Yo+8, 'CPU information: ', $7F {cText});
  IDE_WriteXYC(Xo+3, Yo+9, 'CPU: '+ CPUType, cText);

  s:='';
  if FPUSupport  then s:=s+' FPU';
  if MMXSupport  then s:=s+' MMX';
  if S3DNow      then s:=s+' 3DNow!';
  if CMOVSupport then s:=s+' CMOV';
  if SSESupport  then s:=s+' SSE';
  IDE_WriteXYC(Xo+3, Yo+10, 'Instructions sets:'+ s, cText);
end;


type
  pFileWindowType = ^FileWindowType;
  FileWindowType  = Object(IDE_DialogWindow)
                      FileSt: String;
                      pOKButton,
                      pCANCELButton,
                      pCONSTButton: pButton;

  InsConst: Boolean;

  Constructor Init(nXo, nYo: Integer; nXs, nYs: Word; nTitle: String);
  Procedure Paint; virtual;

  Procedure MouseEvent(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer); virtual;
  Procedure KeyEvent(Key: KeyType); virtual;
  Procedure CloseWin; virtual;
 end;


constructor FileWindowType.Init(nXo, nYo: Integer; nXs, nYs: Word; nTitle: String);
Var pItemText: pInputLine;
    pFileText: pIDE_FileTextType;

begin
 FileSt := '';
 InsConst := False;

 New(pOKButton, init(40, 5, 8, 1, '~O~pen'));
 New(pCANCELButton, init(40, 8, 8, 1, '~C~ancel'));
 New(pCONSTButton, init(40, 11, 8, 1, '~C~onst'));
 New(pFileText, init(3, 3, 32, 9, @FileSt, '*.PAS'));

 Inherited Init(nXo, nYo, 54, 18, nTitle);

 tItem.Insert(pOKButton);
 tItem.Insert(pCANCELButton);
 if Pos('Save', nTitle)=0 then tItem.Insert(pCONSTButton);
 tItem.Insert(pFileText);
 IDE_Desktop^.QuickPaint;
end;

Procedure FileWindowType.Paint;
var e: boolean; pEditWindow: pIDE_SourceWindow;
 Procedure CheckExit(pI: pIDE_ItemBaseType); far;
 begin
  if pI^.ItemExit then begin;e := True;pI^.ItemExit := False;end;
 end;
begin
 Modal := True;
 Inherited Paint;
 e := False;
 tItem.ForEach(@CheckExit);
 InsConst := False;

 if pOKButton^.IsPressed then
   begin;
     pOKButton^.IsDown := False;
     pOKButton^.IsPressed:=False;
     pOKButton^.Paint;
     e:=True;
   end;
 if pCANCELButton^.IsPressed then
   begin;
     pCANCELButton^.IsDown := False;
     pCANCELButton^.IsPressed:=False;
     pCANCELButton^.Paint;
     FileSt := '';
     e:=True;
   end;
 if (Pos('Save', Title)=0) and (pCONSTButton^.IsPressed) then
   begin;
     pCONSTButton^.IsDown := False;
     pCONSTButton^.IsPressed:=False;
     pCONSTButton^.Paint;
     e:=True;
     InsConst := True;
   end;
 if e then
   begin;
     CloseWin;
     done;
     exit;
   end;
end;

Procedure FileWindowType.MouseEvent(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer);
begin
 Inherited MouseEvent(mLeft, mMiddle, mRight, mX, mY);
end;

Procedure FileWindowType.KeyEvent(Key: KeyType);
var pEditWindow: pIDE_SourceWindow;
begin
 inherited KeyEvent(Key);
 IDE_Desktop^.QuickPaint;
end;

Procedure FileWindowType.CloseWin;
var e: boolean; pEditWindow: pIDE_SourceWindow;
 Procedure CheckExit(pI: pIDE_ItemBaseType); far;
 begin
  if pI^.ItemExit then e := True;
 end;
begin
{ e := False;
 tItem.ForEach(@CheckExit);
 if (e) then}
 FileSt := ToUpper(FileSt);

 if FileSt <> '' then
 begin
  if Pos('Save', Title)>0 then
  begin
    if IDE_Desktop^.tWin.Count>=2 then
    begin
     pEditWindow := IDE_Desktop^.tWin.At(IDE_Desktop^.tWin.Count-2);
     if pEditWindow^.ID = _Source then
     begin
      pEditWindow^.SaveFile(FileSt);
      pEditWindow^.Title := FileSt;
      pEditWindow^.FileTitle := FileSt;
     end else ErrorBox('Window is not a source window');
    end else ErrorBox('No window to save');

  end
  else
  if InsConst then
  begin
    pEditWindow := IDE_Desktop^.tWin.At(IDE_Desktop^.tWin.Count-2);
    {if pEditWindow^.ID = _Source then
     pEditWindow^.InsertFile(FileSt)
    else
     ErrorBox('Window is not a Source Window');}
  end
  else
  begin
   New(pEditWindow, init(0, 0, IDE_Screen.Width, IDE_Screen.Height, FileSt));
   pEditWindow^.LoadFile(FileSt);
  end;
 end else IDE_Desktop^.Paint;

end;

{**********************************************************************}
{ Compiler options dialog                                              }
{**********************************************************************}

Type
  pOptionsWindowType = ^OptionsWindowType;
  OptionsWindowType  = object(IDE_DialogWindow)
                         pOKButton,
                         pCANCELButton,
                         pHELPButton: pButton;

                         AlignStackFrame,
                         OptimizeInlineCode,
                         ShuffleRegisters,
                         AddLineNumbers,
                         NestedComments,
                         CstyleComments
                         : pIDE_CheckBoxType;
                         AlignDataBox: pListBox;
                         constructor Init(nXo, nYo: Integer; nXs, nYs: Word; nTitle: String);
                         procedure Paint; virtual;
                         procedure KeyEvent(Key: KeyType); virtual;
                         {procedure MouseEvent(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer); virtual;}
                         procedure CloseWin; virtual;
                       end;

constructor OptionsWindowType.init(nXo, nYo: Integer; nXs, nYs: Word; nTitle: String);
begin
  new(pOKButton,     init(25, 17, 7, 1, 'OK'));
  new(pCANCELButton, init(35, 17, 7, 1, 'Cancel'));
  new(pHELPButton,   init(45, 17, 7, 1, 'Help'));

  New(AlignStackFrame,  init(1, 2, '~A~lign stackframes ', Options.AlignStackFrame, 'A'));
  New(ShuffleRegisters, init(1, 3, '~S~huffle registers ', Options.ShuffleRegisters, 'S'));

  New(AlignDataBox, init(2, 5, 5, 10, '4'));

  inherited Init(nXo, nYo, 60, 20, nTitle);

  tItem.Insert(pOKButton);
  tItem.Insert(pCANCELButton);
  tItem.Insert(pHELPButton);

  tItem.Insert(AlignStackFrame);
  tItem.Insert(ShuffleRegisters);

  tItem.Insert(AlignDataBox);

  IDE_Desktop^.QuickPaint;
end;

Procedure OptionsWindowType.Paint;
var e: boolean;

procedure CheckExit(pI: pIDE_ItemBaseType); far;
begin
  if pI^.ItemExit then
    begin;
      e := True;
      pI^.ItemExit := False;
    end;
end;

begin
  inherited paint;
  e := False;

  tItem.ForEach(@CheckExit);
  if pOKButton^.IsPressed then
    begin;
      pOKButton^.IsDown := False;
      pOKButton^.IsPressed:=False;
      pOKButton^.Paint;
      e:=True;
    end;
  if pCANCELButton^.IsPressed then
    begin;
      pCANCELButton^.IsDown := False;
      pCANCELButton^.IsPressed:=False;
      pCANCELButton^.Paint;
      e:=True;
    end;

 IDE_WriteXYC(Xo+2, Yo+1, 'Code generation', $70);

 Options.AlignStackFrame:=AlignStackFrame^.checked;
 Options.ShuffleRegisters:=ShuffleRegisters^.checked;
 if e then
   begin;
     CloseWin;
     done;
     exit;
   end;
end;

procedure OptionsWindowType.KeyEvent(Key: KeyType);
begin
  inherited KeyEvent(Key);
  IDE_Desktop^.QuickPaint;
end;

Procedure OptionsWindowType.CloseWin;
var e: boolean;

begin
end;

{**********************************************************************}
{ Editor options dialog                                                }
{**********************************************************************}

Type
  pEditOptWindowType = ^EditOptWindowType;
  EditOptWindowType  = object(IDE_DialogWindow)
                         pOKButton,
                         pCANCELButton,
                         pHELPButton: pButton;
                         ScreenSize,
                         SyntaxHighlight,
                         BlockHighlight
                         : pIDE_CheckBoxType;
                         constructor Init(nXo, nYo: Integer; nXs, nYs: Word; nTitle: String);
                         procedure Paint; virtual;
                         procedure KeyEvent(Key: KeyType); virtual;
                         {procedure MouseEvent(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer); virtual;}
                         procedure CloseWin; virtual;
                       end;

constructor EditOptWindowType.init(nXo, nYo: Integer; nXs, nYs: Word; nTitle: String);
begin
  new(pOKButton,     init(25, 17, 7, 1, 'OK'));
  new(pCANCELButton, init(35, 17, 7, 1, 'Cancel'));
  new(pHELPButton,   init(45, 17, 7, 1, 'Help'));
  New(SyntaxHighlight, init(1, 2, '~S~yntax highlight ', IDE.SyntaxHighlight, 'S'));
  New(BlockHighlight,  init(1, 3, '~B~lock highlight  ', IDE.BlockHighlight, 'B'));

  inherited Init(nXo, nYo, 60, 20, nTitle);

  tItem.Insert(pOKButton);
  tItem.Insert(pCANCELButton);
  tItem.Insert(pHELPButton);

  tItem.Insert(SyntaxHighlight);
  tItem.Insert(BlockHighlight);

  IDE_Desktop^.QuickPaint;
end;

Procedure EditOptWindowType.Paint;
var e: boolean;

procedure CheckExit(pI: pIDE_ItemBaseType); far;
begin
  if pI^.ItemExit then begin;e := True;pI^.ItemExit := False;end;
end;

begin
  inherited paint;
  e := False;

  tItem.ForEach(@CheckExit);
  if pOKButton^.IsPressed then
    begin;
      pOKButton^.IsDown := False;
      pOKButton^.IsPressed:=False;
      pOKButton^.Paint;
      e:=True;
    end;
  if pCANCELButton^.IsPressed then
    begin;
      pCANCELButton^.IsDown := False;
      pCANCELButton^.IsPressed:=False;
      pCANCELButton^.Paint;
      e:=True;
    end;

 IDE_WriteXYC(Xo+2, Yo+1, 'Code generation', $70);

 IDE.SyntaxHighlight := SyntaxHighlight^.checked;
 IDE.BlockHighlight  := BlockHighlight^.checked;

 if e then
   begin;
     CloseWin;
     done;
     exit;
   end;
end;

procedure EditOptWindowType.KeyEvent(Key: KeyType);
begin
  inherited KeyEvent(Key);
  IDE_Desktop^.QuickPaint;
end;

Procedure EditOptWindowType.CloseWin;
var e: boolean;

begin
end;

{+--------------------------------------------------------------------------+}
{|                                                                          |}
{|    Compiling information dialog                                          |}
{|    Displays info while compiling...                                      |}
{+--------------------------------------------------------------------------+}

type
   pCompilingDialog = ^CompilingDialog;
   CompilingDialog  = object(MessageBox)
                        cFile, operation: String;
                        cLine, tLine: Longint;
                        constructor Init;
                        procedure Paint; virtual;
                        procedure SetOperation(s: string);
                      end;

var CompilingWindow: CompilingDialog;

constructor CompilingDialog.Init;
begin
  cFile := '';
  cLine := 0;
  tLine := 0;
  inherited Init(45, 12, 'Compiling');
end;

procedure CompilingDialog.Paint;
var w: word;
begin
 inherited Paint;
 IDE_WriteXYC(Xo+3, Yo+2, 'Operation: ' + operation, cText);
 IDE_WriteXYC(Xo+3, Yo+3, '     File: ' + cFile, cText);

 IDE_WriteXYC(Xo+3, Yo+4, 'Cur. Line: ' + PadComma(cLine), cText);
 IDE_WriteXYC(Xo+3, Yo+5, 'Tot. Line: ' + PadComma(tLine+cLine), cText);

 Asm;Mov Ax, Sp; Mov w, Ax;end;

 IDE_WriteXYC(Xo+3, Yo+6, 'Stack(SP): '+PadComma(w), cText);
 IDE_WriteXYC(Xo+3, Yo+7, 'Heap(MEM): '+PadComma(MemAvail), cText);
 IDE_WriteXYC(Xo+35, Yo+9, P32_version, cText);
end;

procedure CompilingDialog.SetOperation(s: string);
begin
  Operation := s;
  IDE_Desktop^.QuickPaint;
end;

{+--------------------------------------------------------------------------+}
{|                                                                          |}
{|    ASCII window                                                          |}
{|                                                                          |}
{+--------------------------------------------------------------------------+}

type
   pASCIIDialog = ^ASCIIDialog;
    ASCIIDialog = object(IDE_DialogWindow)
                    pCANCELButton,
                    pINSNButton,
                    pINSCButton,
                    pINSHButton,
                    pINSBButton: pButton;
                    row, col: Byte;
                    code : integer;
                    constructor Init(nXo, nYo: Integer; nXs, nYs: Word; nTitle: String);
                    destructor Done; virtual;
                    procedure Paint; virtual;
                    procedure MouseEvent(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer); virtual;
                    procedure KeyEvent(Key: KeyType); virtual;
                    procedure DoEvents; virtual;
                    procedure CloseWindow; virtual;
                  end;

constructor ASCIIDialog.Init(nXo, nYo: Integer; nXs, nYs: Word; nTitle: String);
begin
 New(pINSCButton, init(36, 4, 8, 1, '~C~har'));
 New(pINSNButton, init(36, 7, 8, 1, '~N~umber'));
 New(pINSHButton, init(48, 4, 8, 1, '~H~ex'));
 New(pINSBButton, init(48, 7, 8, 1, '~B~in'));
 New(pCANCELButton, init(48, 10, 8, 1, '~C~ancel'));

 row:=0;
 col:=0;
 code:=0;
 inherited Init(nXo, nYo, 64, 14, nTitle);

 tItem.Insert(pCANCELButton);
 tItem.Insert(pINSNButton);
 tItem.Insert(pINSCButton);
 tItem.Insert(pINSHButton);
 tItem.Insert(pINSBButton);

 IDE_Desktop^.QuickPaint;
end;

destructor ASCIIDialog.Done;
begin
  Dispose(pCANCELButton, Done);
  Dispose(pINSNButton, Done);
  Dispose(pINSCButton, Done);
  Dispose(pINSHButton, Done);
  Dispose(pINSBButton, Done);
  inherited Done;
end;

procedure ASCIIDialog.CloseWindow;
begin
  pCANCELButton^.IsPressed := TRUE;
end;

procedure ASCIIDialog.Paint;
var  x, y : word;


begin
  inherited Paint;       { paint window          }
  for y := 0 to 7 do     { paint the ASCII table }
    for x := 0 to 31 do
      IDE_WriteXYC_Ch(x+2+Xo, y+2+Yo, Chr(x+y*32), $30);

  IDE_WriteXYC_Ch(col+2+Xo, row+2+Yo, chr(code), $0F);  {highlight selected char}

  IDE_WriteXYC(Xo+36, Yo+2, 'Insert as:', $70);
  IDE_WriteXYC(2+Xo, Yo+11, 'Char: ', $70);
  IDE_WriteXYC_Ch(9+Xo, Yo+11, chr(code), $70);
  IDE_WriteXYC(16+Xo, Yo+11, 'ASCII: '+PadComma(code), $70);
end;

procedure ASCIIDialog.MouseEvent(mLeft, mMiddle, mRight: Boolean; mX, mY: Integer);
begin
 inherited MouseEvent(mLeft, mMiddle, mRight, mX, mY);
 if mLeft and (mX > 0) and (mY > 0) and (mX <= 33) and (mY <= 9) then { range of ASCII table }
   while IDE_MouseL do {while left mouse button pressed}
     begin
       if ((IDE_MouseX-Xo) > 0)   and ((IDE_MouseY-Yo) > 0) and
          ((IDE_MouseX-Xo) <= 33) and ((IDE_MouseY-Yo) <= 9) then
         begin
           col := IDE_MouseX-Xo-2;
           row := IDE_MouseY-Yo-2;
           code:=row*32+col;
           IDE_Desktop^.QuickPaint;
         end;
       while not IDE_MouseMoved do;
     end;
end;

procedure ASCIIDialog.KeyEvent(Key: KeyType);
begin
  inherited KeyEvent(Key);
end;

procedure ASCIIDialog.DoEvents;
var
     pS   : pIDE_WindowType;
     mKey : KeyType;
     x    : integer;

begin
  repeat
    ProcessEvents;
    if pCANCELButton^.IsPressed then break; {this will close the dialog}

    if (pINSCButton^.IsPressed) or (pINSNButton^.IsPressed) or
       (pINSHButton^.IsPressed) or (pINSBButton^.IsPressed) then {some button pressed?}
      begin
        pS := IDE_Desktop^.tWin.At(IDE_Desktop^.tWin.Count-2); { get window to insert to }
        if pS^.ID = _source then
          begin
            mKey.Alt   := False;
            mKey.Ctrl  := False;
            mKey.Shift := False;
            if pINSCButton^.IsPressed then { sent the character to the source window }
              begin
                mKey.Ch    := chr(code);
                pINSCButton^.IsPressed := False; {reset state}
                pS^.KeyEvent(mKey);
              end
            else
              if (pINSNButton^.IsPressed) then {insert character as decimal number }
                begin
                  pINSNButton^.IsPressed := False;
                  mKey.Ch    := chr(48+((code div 100)));
                  if code >= 100 then pS^.KeyEvent(mKey);
                  mKey.Ch    := chr(48+((code div 10) mod 10));
                  if code >= 10 then pS^.KeyEvent(mKey);
                  mKey.Ch    := chr(48+(code mod 10));
                  pS^.KeyEvent(mKey);
                end
              else
                if (pINSHButton^.IsPressed) then {insert character as hex number }
                  begin
                    pINSHButton^.IsPressed := False;
                    mKey.Ch    := '$';
                    pS^.KeyEvent(mKey);
                    mKey.Ch    := HexStr[1+((code div 16) and $F)];
                    pS^.KeyEvent(mKey);
                    mKey.Ch    := HexStr[1+(code and $F)];
                    pS^.KeyEvent(mKey);
                  end
                else
                  if (pINSBButton^.IsPressed) then {insert character as binary number }
                    begin
                      pINSBButton^.IsPressed := False;
                      for x:=0 to 7 do
                        begin
                          mKey.Ch := Chr(48+ ((code Shr (7-x)) and 1));
                          pS^.KeyEvent(mKey);
                        end;
                      mKey.Ch    := 'b';
                      pS^.KeyEvent(mKey);
                    end;
          end
        else
          ErrorBox('Cannot insert character in this window');
        CloseWindow; { this forces the window to close }
      end;
  until false;
end;


{+--------------------------------------------------------------------------+}
{|                                                                          |}
{|    Main event handler                                                    |}
{|                                                                          |}
{+--------------------------------------------------------------------------+}

var cm_Send_Wait: Boolean;

Procedure cmSend(cm: word);
var st: String;
    pAsmWindow,
    pEditWindow      : pIDE_SourceWindow;
    {pClipBoardWindow : pIDE_ClipBoardWindowType;}
    pUserWindow      : pIDE_UserWindowType;i, w: word;

    AboutDialog      : pAboutDialog;
    pFileWindow      : pFileWindowType;
    InfoWindow       : pInformationDialog;
    ASCIIWindow      : pASCIIDialog;
    pEditOptWindow   : pEditOptWindowType;
    pOptionsWindow   : pOptionsWindowType;

begin
  case cm of
  cm_Exit          : IDE.Quit := True;
  cm_UserScreen    : begin
                       IDE_SwapVideoOut;
                       repeat until keypressed or IDE_MouseL;
                       while keypressed do readkey;
                       if IDE_MouseL then repeat until not IDE_MouseL;
                       IDE_SwapVideoIn;
                       IDE_Desktop^.Paint;
                     end;
  cm_UserWindow    : New(pUserWindow, init(0, 0, 80, 25, 'User Output'));
  cm_AboutWindow   : begin
                       New(AboutDialog, Init(38, 16, 'About'));
                       AboutDialog^.DoEvents;
                       Dispose(AboutDialog, Done);
                     end;
  cm_ASCIIWin      : begin
                       New(ASCIIWindow, init($FF, $FF, 1, 1, 'ASCII table'));
                       ASCIIWindow^.DoEvents;
                       Dispose(ASCIIWindow, Done);
                     end;
  cm_DOSShell      : begin
                       IDE_SwapVideoOut;
                       SwapVectors;
                       Execute(GetENV('COMSPEC'),'');
                       SwapVectors;
                       while keypressed do readkey;
                       if IDE_MouseL then repeat until not IDE_MouseL;
                       IDE_SwapVideoIn;
                       IDE_Desktop^.Paint;
                     end;
  cm_NewEdit       : begin
                       st := '';
                       w := IDE.P32.nNoname;
                       for i:=Length(IDE.P32.NoName) to 7 do
                          begin;
                            St := Chr((w mod 10)+48) + St;
                            w:=w div 10;
                          end;
                       New(pEditWindow, init(0, 0, $FF, $FF, IDE.P32.NoName+St+'.'+IDE.P32.Ext));
                       inc(IDE.P32.nNoname);
                       {**!!** Added by Thomas **!!**}
                       IDE_Desktop^.Paint;
                     end;
  cm_Cut           : begin
                       pEditWindow := IDE_Desktop^.tWin.At(IDE_Desktop^.tWin.Count-1);
                       pEditWindow^.KeyEvent(CutKey)
                     end;
  cm_Copy          : begin
                       pEditWindow := IDE_Desktop^.tWin.At(IDE_Desktop^.tWin.Count-1);
                       pEditWindow^.KeyEvent(CopyKey)
                     end;
  cm_Paste         : begin
                       pEditWindow := IDE_Desktop^.tWin.At(IDE_Desktop^.tWin.Count-1);
                       pEditWindow^.KeyEvent(PasteKey)
                     end;
  cm_Clear         : begin
                       pEditWindow := IDE_Desktop^.tWin.At(IDE_Desktop^.tWin.Count-1);
                       pEditWindow^.KeyEvent(ClearKey)
                     end;
  cm_Clipboard     : begin
                       {New(pClipBoardWindow, init(0, 0, IDE_Screen.Width, IDE_Screen.Height, 'Clipboard'));
                       pClipBoardWindow^.Show;}
                     end;
  cm_Compile       : if IDE_Desktop^.tWin.Count>0 then
                       begin
                         pEditWindow := IDE_Desktop^.tWin.At(IDE_Desktop^.tWin.Count-1);
                         if pEditWindow^.ID = _Source then
                           begin
                             CompilingWindow.Init;
                             CompilingWindow.setOperation('Saving source...');
                             if pEditWindow^.Modified then cmSend(cm_SaveEdit);
                             CompilingWindow.setOperation('Compiling');
                             Sym.LastProgST := pEditWindow^.FileTitle;

                             ResetCompiler;
                             Init; {Reads system unit}
                             Compile(pEditWindow^.FileTitle);

                             CompilingWindow.setOperation('Assembling...');
                             CompilingWindow.setOperation('Done!');

                             if cm_Send_Wait then
                               begin
                                 while IDE_MouseL do;
                                 repeat until (keypressed) or (IDE_MouseL);
                                 while Keypressed do readkey;
                                 while IDE_MouseL do;
                               end;
                             CompilingWindow.done;
                           end
                         else
                           ErrorBox('Cannot Compile this Window type');
                       end
                     else
                       ErrorBox('Cannot Compile, there are no open windows');
  cm_LINK          : begin
                       pEditWindow := IDE_Desktop^.tWin.At(IDE_Desktop^.tWin.Count-1);
                       if pEditWindow^.ID = _Source then
                         begin
                           IDE_SwapVideoOut;
                           St:=pEditWindow^.FileTitle;
                           Delete(St, Pos('.', St), 4);

                           {ExecuteBatchFile(St);}
                           {Exec(GetENV('COMSPEC'), '/C C.BAT');}

                           IDE_SwapVideoIn;
                           IDE_Desktop^.Paint;
                         end
                       else
                         ErrorBox('Cannot compile this window type');
                     end;
  cm_BUILD         : begin;
                       cm_Send_Wait:=False;
                       cmSend(cm_Compile);
                       cmSend(cm_LINK);
                     end;
  cm_RUN           : begin;
                       cmSend(cm_BUILD);
                       IDE_SwapVideoOut;
                       St := pEditWindow^.FileTitle;
                       if Pos('.',St)>0 then St[0] := Chr(Pos('.',St)-1);
                         Execute(st+'.EXE', '');
                       IDE_SwapVideoIn;
                       IDE_Desktop^.Paint;
                     end;
  cm_InfoBOX       : begin
                       New(InfoWindow, init(50, 20, 'Information'));
                       InfoWindow^.DoEvents;
                       Dispose(InfoWindow, Done);
                     end;
  cm_SaveEdit      : if IDE_Desktop^.tWin.Count>0 then
                       begin
                         pEditWindow := IDE_Desktop^.tWin.At(IDE_Desktop^.tWin.Count-1);
                         if pEditWindow^.ID = _Source then
                           pEditWindow^.SaveFile(pEditWindow^.FileTitle);
                       end;
  cm_SaveAsEdit    : if IDE_Desktop^.tWin.Count>0 then
                       begin
                         pEditWindow := IDE_Desktop^.tWin.At(IDE_Desktop^.tWin.Count-1);
                         if pEditWindow^.ID = _Source then
                           New(pFileWindow, init($FF, $FF, 30, 8, 'Save File As'));
                       end;
  cm_LoadEdit      : begin
                       New(pEditWindow, init(0, 0, IDE_Screen.Width, IDE_Screen.Height, FileString));
                       pEditWindow^.LoadFile(FileString);
                     end;
  cm_LoadFile,
  cm_OpenEdit      : New(pFileWindow, init($FF, $FF, 30, 8, 'Load File'));
  cm_CompOptions   : New(pOptionsWindow, init($FF, $FF, 0, 0, 'Compiler options'));
  cm_EditOptions   : New(pEditOptWindow, init($FF, $FF, 0, 0, 'Editor options'));
  cm_AsmWindow     : begin
                       pEditWindow := IDE_Desktop^.tWin.At(IDE_Desktop^.tWin.Count-1);
                       St := pEditWindow^.FileTitle;
                       if Pos('.',St)>0 then St[0] := Chr(Pos('.',St)-1);
                       St:=St+'.ASM';
                       New(pAsmWindow, init(0, 0, $FF, $FF, St));
                       pAsmWindow^.LoadFile(st);
                     end;
  end;
  cm_Send_Wait := True;
end;

Procedure ProcessEvents;
begin
{***!!!*** Added by Thomas ***!!!***}
  If (VideoMode.Intern = TRUEW) then RenderCursor(@VideoMode,WhereX-1,WhereY-1);


  if IDE_MouseMoved then IDE_Desktop^.ProcessMouseEvent;
  if keypressed then
    IDE_Desktop^.ProcessKeyEvent;
end;


Procedure ShowERROR(nLine: Longint;St: String);
var i: word; pW: pIDE_SourceWindow;
begin
  {CompilingWindow.Done;}

{ JP, this code needs to be changed for the linked list }

{ pW := IDE_Desktop^.tWin.At(IDE_Desktop^.tWin.Count-1);

  pW^.CurPosY := nLine-1;}

  pW^.CurPosX := 0; {- Anyone know how to get the current cursor pos? (P32s) -}
  IDE_Desktop^.QuickPaint;

 for i:=1 to pW^.Xs-2 do
  IDE_WriteXYC_Ch(i+pW^.Xo, pW^.Yo+1, ' ', IDE.c.Error);

 for i:=1 to Length(St) do
  if (i<pW^.Xs) then IDE_WriteXYC_Ch(i+pW^.Xo+1, pW^.Yo+1, St[i], IDE.c.Error);

  IDE_UpdateVideo;

 Repeat until (Keypressed) or (IDE_MouseL);
 While IDE_MouseL do;
 While keypressed do readkey;

 IDE_Desktop^.QuickPaint;
 repeat
  ProcessEvents;
 until IDE.Quit;
 IDE_Done;
 exit;
end;

Procedure CompileStatus_NewFile(St: String);
begin
 CompilingWindow.cFile := St;
 IDE_Desktop^.QuickPaint;
end;

var CompilerStatus_cLineSet_Last: Longint;
Procedure CompileStatus_cLineSet(l: Longint);
var w1, w2, w3, w4: word; l2: longint;
begin
 if l < CompilingWindow.cLine then Inc(CompilingWindow.tLine, CompilingWindow.cLine);
 CompilingWindow.cLine := l;
 Sym.cLine := CompilingWindow.cLine;
 Sym.tLine := CompilingWindow.tLine;

  GetTime(w1, w2, w3, w4);
  l2 := longint(w4) + longint(w3) * 100 + longint(w2) * 6000 + longint(w1) * 360000;
  if l2 > CompilerStatus_cLineSet_Last + 1 then
  begin
   IDE_Desktop^.QuickPaint;
   CompilerStatus_cLineSet_Last := l2;
  end;
end;

procedure SetVideoMode(Width, Height: integer);
begin
  If (IDE_Screen.Buffer <> Nil) Then FreeMem(IDE_Screen.Buffer,IDE_Screen.BufferSize);
  If (IDE_Screen.LastBuffer <> Nil) Then FreeMem(IDE_Screen.LastBuffer,IDE_Screen.BufferSize);
  Modes := FirstMode;
  while (Modes <> nil) do
  begin
    if (Modes^.Width=Width) and (Modes^.Height=Height) then
      begin
        IDE_Screen.Width:=Modes^.Width;
        IDE_Screen.Height:=Modes^.Height;
        IDE_Screen.BufferSize := Modes^.Width*Modes^.Height*2;
        GetMem(IDE_Screen.Buffer,IDE_Screen.BufferSize);
        FillChar(IDE_Screen.Buffer^,IDE_Screen.BufferSize,#00);
        If (Modes^.Intern = TRUEW) then
         begin
          GetMem(IDE_Screen.LastBuffer, IDE_Screen.BufferSize);
          FillChar(IDE_Screen.LastBuffer^,IDE_Screen.BufferSize,#255);
         end;
        VideoMode := Modes^;
        break;
      end;
    Modes := Modes^.Next;
  end;
  if Modes=NIL then
    begin
      SetVideoMode(80, 25);
      Writeln('þ Selected video mode not found, switching to 80x25');
      delay(500);
    end;
end;

var
 i: word;


begin
  ClipBoard.FirstLn:=NIL;
  ClipBoard.EndLn:=NIL;

{- Setup default variables -}
   IDE.Width:=80;
   IDE.Height:=25;
   IDE.c.Syntax.none       := 14 + 16;
   IDE.c.Syntax.Comment    := 7  + 16;
   IDE.c.Syntax.Reserved   := 15 + 16;
   IDE.c.Syntax.Reserved2  := 11 + 16;
   IDE.c.Syntax.Identifiers:= 14 + 16;
   IDE.c.Syntax.Symbols    := 9  + 16;
   IDE.c.Syntax.Strings    := 12 + 16;
   IDE.c.Syntax.Numbers    := 13 + 16;
   IDE.c.Syntax.AsmSrc     := 10 + 16;
   IDE.c.Error             := $4F;
   IDE.c.BlockHi           := 6;
   IDE.c.BlockSel          := 7;

   IDE.c.Button            := $20;
   IDE.c.ButtonH           := $2E;

   IDE.TabSize             := 8;
   IDE.SmartTab            := True;
   IDE.SyntaxHighlight     := True;
   IDE.BlockHighlight      := True;
   IDE.DoubleClick         := 100; {- 100ms Double Click -}
   IDE.NestComment         := True;

   IDE.P32.nNoname := 0;
   IDE.P32.Noname  := 'NONAME';
   IDE.P32.Ext     := 'PAS';

   Sym.Filled := False;
  Options.NestedComments := IDE.NestComment;
  ReadConfig;
  ReadDefinition(FSearch(config.asmdef,config.asmdef+';.;'+GetEnv('P32')+';'+GetEnv('PATH')));
  IDE.NestComment := Options.NestedComments;
end.
{ Microsoft Mouse driver for TP þ by Michael Goddard (cgoddard@ozemail.com.au) }
{
 Features:
   þ Took under 1/2 hour to make , I already knew how to do it , just couldn't
     be bothered .
   þ Smooth numbers in graphics mode , cell size disapears .
   þ You can do what you want with it, I don't care. Except if you make
     something good send me a link to it :-)
 BTW: This was mostly written for my use only and from memory, but seems to work!}

{$G+} {- Enable 286 instructions for the Shift's -}
Unit MMouse;

interface

Function MMouse_Init: Boolean;
Procedure MMouse_Done;
procedure MMouse_SetSpeed(x,y: Word);
procedure MMouse_Window(Xs,Ys,Xe,Ye: Word);
Function MMouse_ButtonRight: Boolean;
Function MMouse_ButtonLeft: Boolean;
Function MMouse_GetY: Word;
Function MMouse_GetX: Word;
Function MMouse_Moved: Boolean;
Function MMouse_Movedb: Boolean; {Same as above but doesn't update vars}
Function MMouse_InArea(Xs, Ys, Xe, Ye: Integer): Boolean;
Procedure MMouse_SetDoubleSpeed(Spd: Word); { Default = 64 }
Function MMouse_Installed: Boolean;
Procedure MMouse_SetPos(x,y: word);
Procedure MMouse_Show;
Procedure MMouse_Hide;


Const MMouse_Gran = 3;

var
  MMouse_verhi, MMouse_verlo, MMouse_Type, MMouse_IRQNr : byte;
  MMouse_FakeMove: Boolean;
  MMouse_GetYL, MMouse_GetXL,
  MMouse_GetYR, MMouse_GetXR: Word;

implementation

var
 MMouse_MovedXPos, MMouse_MovedYPos: Word;
 MMouse_lButton, MMouse_rButton: Boolean;

Procedure MMouse_Show;assembler;
asm;
  Mov Ax,1;
  Int 33h;
end;
Procedure MMouse_Hide;assembler;
asm;
  Mov Ax,2;
  Int 33h;
end;

Function MMouse_Installed: Boolean;assembler;
asm
  xor ax,ax;
  int 33h;
  cmp ax,-1;
  je @skip;
  xor al,al;
@skip:
end;

Function MMouse_Init: Boolean;
begin
  MMouse_Init:=False;
  if MMouse_Installed then
    begin
      MMouse_Init:=True;
      asm
        mov ax,24h
        int 33h
        mov MMouse_verhi, bh
        mov MMouse_verlo, bl
        mov MMouse_type, ch
        mov MMouse_IRQNr, cl
      end;
    end;
end;

Procedure MMouse_Done;
begin

end;

Function MMouse_GetX: Word;assembler;
asm
  mov ax,3;
  int 33h;
  mov ax,cx ;
  shr ax, MMouse_Gran;
end;

Function MMouse_GetY: Word;assembler; asm
  mov ax,3; int 33h; mov ax,dx ; shr ax,MMouse_Gran; end;

Function MMouse_ButtonLeft: Boolean; assembler;asm
  mov ax,3; int 33h; and bx,1; mov ax,bx end;

Function MMouse_ButtonRight: Boolean; assembler;asm
  mov ax,3; int 33h; and bx,2; mov ax,bx end;

procedure MMouse_Window(Xs,Ys,Xe,Ye: Word); assembler;
asm
  mov ax, 7;
  mov cx, Xs
  shl cx, MMouse_Gran
  mov dx, Xe;
  shl dx, MMouse_Gran
  int 33h
  mov ax, 8;
  mov cx, Ys;
  shl cx, MMouse_Gran
  mov dx, Ye;
  shl dx, MMouse_Gran
  int 33h
end;

procedure MMouse_SetSpeed(x,y: Word); assembler;asm
  mov ax,1ah; mov bx,x; mov cx,y; xor dx,dx; int 33h end;

Function MMouse_Moved: Boolean;
var MX, MY: Word;MBL, MBR: Boolean;
begin

  MMouse_Moved := False;

  MX := MMouse_GetX;MY := MMouse_GetY;
  MBL := MMouse_ButtonLeft;
  MBR := MMouse_ButtonRight;

  if MX <> MMouse_MovedXPos then MMouse_Moved := True;
  if MY <> MMouse_MovedYPos then MMouse_Moved := True;

  if MMouse_lButton <> MBL then MMouse_Moved := True;
  if MMouse_rButton <> MBR then MMouse_Moved := True;

  if MMouse_FakeMove then MMouse_Moved := True;
  MMouse_FakeMove := False;

  MMouse_MovedXPos := MX;
  MMouse_MovedYPos := MY;
  MMouse_lButton := MBL;
  MMouse_rButton := MBR;

{ Update Where Pressed Vars }
if not MBL then MMouse_GetXL := MX;
if not MBL then MMouse_GetYL := MY;
if not MBR then MMouse_GetXR := MX;
if not MBR then MMouse_GetYR := MY;


end;

Function MMouse_Movedb: Boolean;
begin

  MMouse_Movedb := False;

  if MMouse_GetX <> MMouse_MovedXPos then MMouse_Movedb := True;
  if MMouse_GetY <> MMouse_MovedYPos then MMouse_Movedb := True;

  if MMouse_lButton <> MMouse_ButtonLeft then MMouse_Movedb := True;
  if MMouse_rButton <> MMouse_ButtonRight then MMouse_Movedb := True;

end;

Function MMouse_InArea(Xs, Ys, Xe, Ye: Integer): Boolean;
begin

  MMouse_InArea := False;
  if (MMouse_GetX > Xs) and
     (MMouse_GetX < Xe) and
     (MMouse_GetY > Ys) and
     (MMouse_GetY < Ye) then MMouse_InArea := True;

end;

Procedure MMouse_SetDoubleSpeed(Spd: Word);assembler;asm
  mov ax,0013h;mov dx,Spd;int 33h;end;

Procedure MMouse_SetPos(x,y: word);assembler;asm;mov ax,4;mov cx,x;
mov dx,y;
shl Cx,MMouse_Gran;Shl Dx,MMouse_Gran;int 33h;end;

Begin
 MMouse_Installed;
 MMouse_FakeMove := False;
End.

{ -------------------------------------------------------------------------- }
{                                                                            }
{                         P32 - 32 bit Pascal Compiler                       }
{                                                                            }
{ -------------------------------------------------------------------------- }
{                       Johan Prins - jprins@knoware.nl                      }
{ ========================================================================== }
{ P32 VESA Interface                                                         }
{          By Thomas Steen, TNSe@hotmail.com                                 }
{                                                   (c) Copyright 1996-1999  }
{                                                                            }
{ http://surf.to/p32                                                         }
{                                                                            }
{ -------------------------------------------------------------------------- }

Unit P32_VESA;


interface


Const
 TRUEW:Word = Word(TRUE);
 FALSEW:Word = Word(FALSE);

Type
 RAWFont       = Array[0..0] of Byte;
 PRAWFont      = ^RAWFont;
 AFont         = Array[0..0] of Byte;
 PAFont        = ^AFont;

 FontSets = (F8x8,F8x16,F8x14,F9x16);

 PAMode = ^AMode;
 AMode  = Record
           Next,Prev:PAMode;
           Width,Height:Word;
           Segm:Word;
           ModeNr:Word;
           Intern:Word;
          { The below is only used for the TXT-GFX renderer }
           FontType:FontSets;
           RealWidth,RealHeight:Word;
           PageCall:Pointer;
           PageSizeShl:Byte;
          end;

Type
 ChCo = Record Ch,Col:Byte; end;
 AChCo = Array[0..0] of ChCo;
 PAChCo = ^AChCo;


var
 FirstMode:PAMode;
 LastMode :PAMode;
 PFont    :PAFont;

Procedure SetMode(Mode:AMode);
Procedure Render(Buffer,OldBuffer:PAChCo; Mode:AMode);
Procedure RenderMouse(PMode:PAMode; Xs,Ys:Word);
Procedure RenderCursor(PMode:PAMode; Xs,Ys:Word);

Procedure SetNoCursor;
Procedure SetFullCursor;
Procedure SetLowCursor;

implementation

{$ifdef DPMI}
uses winapi;
{$endif}

Type
 Vesainfo = Record
             Ident:Array[1..4] of Char;
             Ver  :Word;
             OEM  :PChar;
             Flags:LongInt;
             Supp :^Word;
             RAM  :Word;
{ Vesa 2.0+ }
             OEMv    :Word;             { Oem software version }
             VName   :PChar;            { Vendor name }
             PName   :PChar;            { Product Name }
             PRString:PChar;            { Product revision string }
             Reserved:Array[1..222] of byte;
             Scratch :Array[1..256] of byte; { Oem Scratchpad}
            end;

 ModeInfo = Record
             Supp   :Word;
             AttrA  :Byte;
             AttrB  :Byte;
             WGran  :Word;
             WSize  :Word;
             SegmA  :Word;
             SegmB  :Word;
             FarC   :Pointer;
{ VBE 1.0/1.1 optional }
             BprLine:Word;
             Width  :Word;
             Lngth  :Word;
             ChCellW:Byte;
             ChCellL:Byte;
             MemPlan:Byte;
             BPP    :Byte;
             Banks  :Byte;
             Memmod :Byte;
             BankSize:Byte;
             ImagP  :Byte;
             Reserv1:Byte;
{ 1.2+ Info }
             RedMask:Byte;
             RedFild:Byte;
             GrnMask:Byte;
             GrnFild:Byte;
             BluMask:Byte;
             BluFild:Byte;
             ResMask:Byte;
             ResFild:Byte;
             DirecIn:Byte;
{ 2.0 Info -> }
             OffscrL:LongInt;
             StartOf:Pointer;
             KBOffSc:Word;
             Shit :Array[1..210] of byte;
            end;
var
 ModeInf:^ModeInfo;
 VesaInf:^VesaInfo;

var RMRegs:record
            case boolean of
            true:(edi,esi,ebp,reserved,ebx,edx,ecx,eax:longint;
                  flags,es,ds,fs,gs,ip,cs,sp,ss:word);
            true:(di,udi,si,usi,bp,ubp,rese,rved,bx,ubx,dx,udx,cx,ucx,ax,uax:word);
           end;


{$ifdef DPMI}

{Simulate Real Mode Interrupt}
procedure SimRMI(IntNum:byte;var CallStruc); assembler;
asm
        mov     ax,300h
        mov     bh,1
        mov     bl,IntNum
        xor     cx,cx
        les     di,CallStruc
        int     31h
end;

{Call Real Mode Procedure (with Far Return Frame)}
procedure CallRMP(var CallStruc); assembler;
asm
        mov     ax,301h
        mov     bh,1
        xor     cx,cx
        les     di,CallStruc
        int     31h
end;

function GetSegBaseAddr(Selector:word):longint; assembler;
asm
        mov     ax,0006h
        mov     bx,Selector
        int     31h
        mov     ax,dx
        mov     dx,cx
end;

function SegToDescriptor(SegAddr:word):word; assembler;
asm
        mov     ax,0002h
        mov     bx,SegAddr
        int     31h
end;

function ConvertPtr(RMPointer:Pointer):pointer; assembler;
asm
        mov     ax,0002h
        mov     bx,word ptr RMPointer+2
        int     31h
        mov     dx,ax
        mov     ax,word ptr RMPointer
end;

function IsVesaInstalled(var VESARec:VesaInfo):word;
begin
 with RMRegs do
  begin
   ax:=$4f00;
   di:=0;
   es:=GetSegBaseAddr(seg(VESARec)) shr 4;
   ss:=0; {Clear stack so DPMI handles it}
   sp:=0  {"}
  end;
 SimRMI($10,RMRegs);

 {Convert all real mode pointers to protected mode pointers}
 with VesaRec do
  begin
   Supp := ConvertPtr(Supp);
   Oem  := ConvertPtr(Oem);
  end;

 IsVesaInstalled:=RMRegs.ax
end;

function GetModeInfo(mode:Word; var ModeRec:ModeInfo): word;
var poy:pointer;
begin
 with RMRegs do
  begin
   ax:=$4f01;
   cx:=mode;
   di:=0;
   es:=GetSegBaseAddr(seg(ModeRec)) shr 4;
   sp:=0; {Clear stack so DPMI handles it}
   ss:=0  {"}
  end;
 SimRMI($10,RMRegs);

 GetModeInfo:=RMRegs.ax;
end;

{$else}

function IsVESAInstalled (var VESARec:VesaInfo): word; assembler;
asm
        mov     ax,4F00h
        les     di,VESARec
        int     10h
end;

function GetModeInfo (mode: Word;var ModeRec:ModeInfo): word; assembler;
asm
        mov     ax,4F01h
        mov     cx,[mode]
        les     di,ModeRec
        int     10h
end;
{$endif}

Const
 FontNumbers:Array[FontSets] of Word = ($0300,$0600,$0200,$0500);
 FontSizes:Array[FontSets] of record Xs,Ys:Word end = (
 (Xs:8; Ys:8),(Xs:8; Ys:16),(Xs:8; Ys:14),(Xs:9; Ys:16));

var
 CursorInsert,CursorHidden:Boolean;
 CurModeEntry:PAMode;
 FontSize:Word;
 YSize,XSize,LetSize:Word;
 FontNumber:Word;
 CurModePageShl:Byte;

Procedure SetMode(Mode:AMode);
var
 PLetters:Pointer;
 C,y,x,z:Byte;
begin
 If (PFont <> Nil) then FreeMem(PFont,FontSize);

 Case Mode.ModeNr of
  $00    :asm
           mov ax,$3
           int $10  { Default to 80x25 if any error... }
          end;
  $01,$03:asm
           mov ax,Mode.ModeNr
           int $10
          end;
  $02,$04:asm
           mov ax,Mode.ModeNr
           dec ax
           int $10
           xor bx,bx
           mov ax,$1112
           int $10
          end;
  else    asm {Must / Should be Extended VESA mode }
           mov ax,$4f02
           mov bx,Mode.ModeNr
           int $10
          end;
 end;

 If (Mode.Intern = TRUEW) then
  begin
   { Get and Decode Font }
   FontNumber := FontNumbers[Mode.FontType];
   XSize := FontSizes[Mode.FontType].Xs;
   YSize := FontSizes[Mode.FontType].Ys;
   LetSize := YSize*XSize;
   FontSize := LetSize*256;
   CurModePageShl := Mode.PageSizeShl;
  {$ifdef DPMI}
   RMRegs.ax := $1130;
   RMRegs.bx := FontNumber;
   SimRMI($10,RMRegs);
   PLetters := ConvertPtr(Ptr(RMRegs.es,RMRegs.bp));
  {$else}
   asm
    push bp
    mov ax,$1130
    mov bx,FontNumber
    int $10
    mov ax,bp
    pop bp
    mov Word Ptr [PLetters+0],ax
    mov Word Ptr [PLetters+2],es
   end;
  {$endif}
   GetMem(PFont,FontSize);
   For C := 0 to 255 do
    begin
     For y := 0 to YSize-1 do
      begin
       z := PRAWFont(PLetters)^[c*YSize+(XSize div 8-1)+y];
       For x := 0 to XSize-1 do
        begin
{****!! Try removing the XSize-x-1 and use only X, guaranteed fun!! }
         If (z AND (1 shl (XSize-x-1)) <> 0) then PFont^[C*LetSize+y*XSize+x] := 255
                                             else PFont^[C*LetSize+y*XSize+x] := 0;
        end;
      end;
    end;
  end;

end;

var
 NowPage:Word;

Procedure SetPage(Which:Word); assembler;
asm
 mov dx,Which
 mov ax,$4f05
 cmp NowPage,dx
 je @NotThisTime
 mov cl,CurModePageShl
 mov NowPage,dx
 shl dx,cl
 xor bx,bx
 int $10
@NotThisTime:
(* Call dword ptr [Mode.PageCall] (* Damn PMode! *)
end;

var
 OldMX,OldMY:Word;
 MouseStillThere:Boolean;
 OldCX,OldCY:Word;
 CursorStillThere:Boolean;
 LastCYSize:Word;
 LastTimeRendered:LongInt;
 LastTimeShown:Boolean;

Procedure RenderMouse(PMode:PAMode; Xs,Ys:Word);
var
 Smart:LongInt;
 SmartMod,SmartDiv:Word;
 x,y:Word;
 Qy:LongInt;
begin
 Ys := Ys * YSize;
 Xs := Xs * XSize;

 If MouseStillThere then
  begin
   For y := 0 to YSize-1 do
    begin
     Qy := LongInt(OldMY+y)*LongInt(PMode^.RealWidth)+OldMX;
     For x := 0 to XSize-1 do
      begin
       Smart := Qy+x;
       SmartDiv := Smart shr 16;
       SmartMod := Smart;
       SetPage(SmartDiv);
       Mem[PMode^.Segm:SmartMod] := 15-Mem[PMode^.Segm:SmartMod];
      end;
    end;

  end;

 For y := 0 to YSize-1 do
  begin
   Qy := LongInt(Ys+y)*LongInt(PMode^.RealWidth)+Xs;
   For x := 0 to XSize-1 do
    begin
     Smart := Qy+x;
     SmartDiv := Smart shr 16;
     SmartMod := Smart;
     SetPage(SmartDiv);
     Mem[PMode^.Segm:SmartMod] := 15-Mem[PMode^.Segm:SmartMod];
    end;
  end;

 OldMX := Xs;
 OldMY := Ys;
 MouseStillThere := TRUE;

end;

Procedure RenderCursor(PMode:PAMode; Xs,Ys:Word);
var
 Smart:LongInt;
 SmartMod,SmartDiv:Word;
 x,y:Word;
 Qy:LongInt;
 ThisYSize:Word;
 ThisTime:LongInt;
begin
 Ys := Ys * YSize;
 Xs := Xs * XSize;

{ ThisTime := MemL[Seg0040:$6C];
 If (ThisTime > LastTimeRendered+20) then
  begin
   LastTimeRendered := ThisTime;
   exit;
  end;
 LastTimeRendered := ThisTime;
 LastTimeShown := Not LastTimeShown;
 If LastTimeShown then exit;
For blinking, but who the heck needs that?!!?!? }

 If CursorInsert then ThisYSize := 0 else ThisYSize := YSize-3;

 If CursorStillThere then
  begin
   If (OldCX = Xs) AND (OldCY = Ys) AND (ThisYSize = LastCYSize) then exit; { Don't redraw cursor }
   For y := LastCYSize to YSize-1 do
    begin
     Qy := LongInt(OldCY+y)*LongInt(PMode^.RealWidth)+OldCX;
     For x := 0 to XSize-1 do
      begin
       Smart := Qy+x;
       SmartDiv := Smart shr 16;
       SmartMod := Smart;
       SetPage(SmartDiv);
       Mem[PMode^.Segm:SmartMod] := 15-Mem[PMode^.Segm:SmartMod];
      end;
    end;

  end;

 If CursorHidden then exit;

 For y := ThisYSize to YSize-1 do
  begin
   Qy := LongInt(Ys+y)*LongInt(PMode^.RealWidth)+Xs;
   For x := 0 to XSize-1 do
    begin
     Smart := Qy+x;
     SmartDiv := Smart shr 16;
     SmartMod := Smart;
     SetPage(SmartDiv);
     Mem[PMode^.Segm:SmartMod] := 15-Mem[PMode^.Segm:SmartMod];
    end;
  end;

 OldCX := Xs;
 OldCY := Ys;
 LastCYSize := ThisYSize;
 CursorStillThere := TRUE;

end;

Procedure SetNoCursor;
begin
 CursorHidden := TRUE;
asm
  mov ax, 0100h
  mov cx, 2607h
  int 10h
end;
end;

Procedure SetFullCursor;
begin
 CursorHidden := FALSE;
 CursorInsert := TRUE;
asm
  mov ax, 0100h
  Mov cx, 0007h
  int 10h
end;
end;

Procedure SetLowCursor;
begin
 CursorHidden := FALSE;
 CursorInsert := FALSE;
asm
  mov ax, 0100h
  mov cx, 0506h
  int 10h
end;
end;
{ the *ULTRA* slow Render Proc. Gonna hafta redo this sometime... }
Procedure Render(Buffer,OldBuffer:PAChCo; Mode:AMode);
var
 x,y:Word;
 gx,gy:Word;
 smart:LongInt;
 smartdiv,smartmod:Word;
 sp1,sp2,sp4,sp5,sp6,sp7:Word;
 sp3:LongInt;

begin
 For y := 0 to Mode.Height-1 do
  begin
   sp1 := y*Mode.Width;
   sp4 := y*YSize;
   For x := 0 to Mode.Width-1 do
    begin
     sp2 := Sp1+x;
     If (Word(Buffer^[sp2]) <> Word(OldBuffer^[sp2])) then
      begin
       If (OldMX = X*XSize) AND (OldMY = sp4) then MouseStillThere := FALSE;
       If (OldCX = X*XSize) AND (OldCY = sp4) then CursorStillThere := FALSE;
       sp5 := Buffer^[sp2].Ch*LetSize;
       For gy := 0 to YSize-1 do
        begin
         sp6 := sp5+gy*XSize;
         sp3 := LongInt(sp4+gy)*LongInt(Mode.RealWidth)+x*XSize;
         For gx := 0 to XSize-1 do
          begin
           smart := sp3+LongInt(gx);
           smartdiv := smart shr 16;
           smartmod := smart;

           SetPage(Smartdiv);
           If (PFont^[sp6+gx] = 0) then
            Mem[Mode.Segm:SmartMod] := Buffer^[sp2].Col shr 4
           else
            Mem[Mode.Segm:SmartMod] := Buffer^[sp2].Col and $0f;
          end;
        end;
      end;
    end;
  end;

 Move(Buffer^,OldBuffer^,Mode.Width*Mode.Height*2);
end;

var
 ModeTmp:^Word;
 Cn:FontSets;

begin
 New(CurModeEntry);
 With CurModeEntry^ do
  begin
   Next   := Nil;
   Prev   := Nil;
   Width  := 40;
   Height := 25;
   Segm   := SegB800;
   ModeNr := $01;
   Intern := FALSEW;
  end;

 FirstMode := CurModeEntry;
 LastMode  := CurModeEntry;

 New(CurModeEntry);
 With CurModeEntry^ do
  begin
   Next   := Nil;
   Prev   := LastMode;
   Width  := 40;
   Height := 50;
   Segm   := SegB800;
   ModeNr := $02;
   Intern := FALSEW;
   LastMode^.Next := CurModeEntry;
   LastMode := CurModeEntry;
  end;

 New(CurModeEntry);
 With CurModeEntry^ do
  begin
   Next   := Nil;
   Prev   := LastMode;
   Width  := 80;
   Height := 25;
   Segm   := SegB800;
   ModeNr := $03;
   Intern := FALSEW;
   LastMode^.Next := CurModeEntry;
   LastMode := CurModeEntry;
  end;

 New(CurModeEntry);
 With CurModeEntry^ do
  begin
   Next   := Nil;
   Prev   := LastMode;
   Width  := 80;
   Height := 50;
   Segm   := SegB800;
   ModeNr := $04;
   Intern := FALSEW;
   LastMode^.Next := CurModeEntry;
   LastMode := CurModeEntry;
  end;

 {$ifdef DPMI}
  ModeInf := GlobalLock(GlobalDosAlloc(sizeOf(ModeInfo)));
  VesaInf := GlobalLock(GlobalDosAlloc(sizeOf(VesaInfo)));
 {$else}
  new(VesaInf);
  new(ModeInf);
 {$endif}

  If (IsVESAInstalled(VesaInf^) = $4f) AND (VesaInf^.Ident = 'VESA') then
   begin
    ModeTmp := Pointer(VesaInf^.Supp);
    While (VesaInf^.Supp^ <> $ffff) do
     begin
      GetModeInfo(VesaInf^.Supp^,ModeInf^);
      If (ModeInf^.Supp AND 17 = 1) then
       begin
        New(CurModeEntry);
        With CurModeEntry^ do
         begin
          Next   := Nil;
          Prev   := LastMode;
          Width  := ModeInf^.Width;
          Height := ModeInf^.Lngth;
          {$ifdef DPMI}
          Segm   := SegToDescriptor(ModeInf^.SegmA);
          {$else}
          Segm   := ModeInf^.SegmA;
          {$endif}
          ModeNr := VesaInf^.Supp^;
          Intern := FALSEW;
          LastMode^.Next := CurModeEntry;
          LastMode := CurModeEntry;
         end;
       end;
      VesaInf^.Supp := Ptr(Seg(VesaInf^.Supp^),Ofs(VesaInf^.Supp^)+2);
     end;
    VesaInf^.Supp := Pointer(ModeTmp);
    While (VesaInf^.Supp^ <> $ffff) do
     begin
      GetModeInfo(VesaInf^.Supp^,ModeInf^);
      If (ModeInf^.BPP = 8) then
       begin
        For Cn := F8x8 to F9x16 do
         begin
          New(CurModeEntry);
          With CurModeEntry^ do
           begin
            Next      := Nil;
            Prev      := LastMode;
           {$ifdef DPMI}
            Segm      := SegToDescriptor(ModeInf^.SegmA);
           {$else}
            Segm      := ModeInf^.SegmA;
           {$endif}
            ModeNr    := VesaInf^.Supp^;
            Intern    := TRUEW;
            FontType  := Cn;
            RealWidth := ModeInf^.Width;
            RealHeight:= ModeInf^.Lngth;
            Width     := ModeInf^.Width div FontSizes[FontType].Xs;
            Height    := ModeInf^.Lngth div FontSizes[FontType].Ys;
            If (ModeInf^.BankSize = 0) then PageSizeShl := 0
            else Case 65536 div ModeInf^.BankSize of
                 2:PageSizeShl := 1; { 32k banks}
                 4:PageSizeShl := 2; { 16k }
                 8:PageSizeShl := 3; {  8k }
                16:PageSizeShl := 4; {  4k }
                32:PageSizeShl := 5; {  2k }
                64:PageSizeShl := 6; {  1k, not likely? ;) }
            end;
           {$ifdef DPMI}
            PageCall  := ConvertPtr(ModeInf^.FarC);
           {$else}
            PageCall  := ModeInf^.FarC;
           {$endif}
            LastMode^.Next := CurModeEntry;
            LastMode  := CurModeEntry;
           end;
         end;
       end;
      VesaInf^.Supp := Ptr(Seg(VesaInf^.Supp^),Ofs(VesaInf^.Supp^)+2);
     end;


   end;

{$ifdef DPMI}
 if globalunlock(seg(VesaInf^)) then globaldosfree(seg(VesaInf^));
 if globalunlock(seg(ModeInf^)) then globaldosfree(seg(ModeInf^));
{$else}
 dispose(VesaInf);
 dispose(ModeInf);
{$endif}

 CursorStillThere := FALSE;
 MouseStillThere := FALSE;
end.
program StarsForWindows;
{ Original STARS.PAS by Daniel D. Bennett }
{ Adapted for Windows 95 by Leonardo H. Liporati }
{ Modified by Michael Goddard (magnesium@hehe.com) }

uses Windows;

const
   numStars = 1200;
   strStarsCl = 'StarsAppClass'+#0;
   strTitle   = 'Stars for Win32'+#0;
   MarqSt: Array[1..3] of String[40] =('Stars by Daniel Bennett!',
                                       'Win32 version by Leonardo Liporati!',
                                       'Text & Resize by Michael Goddard.');

var
   wc        : WNDCLASS;
   winMsg    : MSG;
   winHandle : HWND;
   ghInstance: HANDLE;
   TimerId   : UINT;
   i, j      : longint;
   starx     : Array[1..numStars] of longint;
   stary     : Array[1..numStars] of longint;
   starz     : Array[1..numStars] of longint;
   staru     : Array[1..numStars] of longint;
   starv     : Array[1..numStars] of longint;
   visWidth,
   visHeight : longint;
   marqX, marqY: Array[1..3] of Longint;

function Xlat( XPos, Distance : longint): longint;
begin
   Xlat := (XPos*256) div Distance;
end;


procedure NewStar(starnum: longint);
begin
   starx[starnum]:=random(200)-100;
   stary[starnum]:=random(200)-100;
   starz[starnum]:=-255;
   staru[starnum]:=0;
   starv[starnum]:=0;
end;


procedure MoveStar(starnum : longint);
begin
  starz[starnum]:=starz[starnum]+3;
  if starz[starnum]=0 then NewStar(starnum);
  staru[starnum]:=Xlat(starx[starnum],starz[starnum])+(visWidth div 2);
  starv[starnum]:=Xlat(stary[starnum],starz[starnum])+(visHeight div 2);
  if (staru[starnum]<0) then NewStar(starnum);
  if (staru[starnum]>visWidth) then NewStar(starnum);
  if (starv[starnum]<0) then NewStar(starnum);
  if (starv[starnum]>visHeight) then NewStar(starnum);
end;


procedure InitStars;
begin
  randomize;
  visWidth := 479;
  visHeight := 639;
  for i:= 1 to 3 do
  begin
   marqX[i] := visWidth + (i * 2 * 40);
   marqY[i] := random(visHeight);
  end;
  for i:=1 to numStars do begin
     NewStar(i);
  end;
  for j := 0 to 255 do
    for i:=1 to numStars do MoveStar(i);
end;


procedure AnimateStars(DCHandle: HDC);
var colour: LongInt;
begin
  for i:=1 to numStars do begin
    SetPixel(DCHandle,staru[i],starv[i],0);
    MoveStar(i);
    colour := starz[i]+255;
    asm
      mov eax, dword ptr [colour]
      mov ah, al
      shl eax, 8
      mov al, ah
      mov dword ptr [colour], eax
    end;
    SetPixel(DCHandle,staru[i],starv[i],colour);
  end;
end;

procedure AnimateText(DCHandle: HDC);
begin
 SetBkMode(DCHandle, 1);
 for i:=1 to 3 do
 begin
   SetTextColor(DCHandle, 0);
   TextOutA(DCHandle, marqX[i], marqY[i], @MarqSt[i]+1, Length(MarqSt[i]));

   Dec(marqX[i], 4+i);
   if (marqX[i] < -300) then
   begin
    marqX[i] := visWidth + random(100);
    marqY[i] := random(visHeight);
   end;

   SetTextColor(DCHandle, 255);
   TextOutA(DCHandle, marqX[i], marqY[i], @MarqSt[i]+1, Length(MarqSt[i]));
 end;
end;

function MainWndProc(hWindow: HWND; msg: UINT; wPrm: WPARAM; lPrm: LPARAM): LRESULT;
var ps: PAINTSTRUCT;
    DCHandle: HDC;
    ptrRect : ^RECT;
begin
  ptrRect := nil;
  MainWndProc := FALSE;
  case msg of
    WM_TIMER: InvalidateRect(winHandle, ptrRect^, FALSE);
    WM_PAINT: begin
                 DCHandle := BeginPaint(winHandle, ps);
                 AnimateStars(DCHandle);
                 AnimateText(DCHandle);
                 EndPaint(winHandle, ps);
              end;
    WM_DESTROY: begin
                  KillTimer(winHandle, TimerId);
                  PostQuitMessage(0);
                end;
    WM_SIZE: begin
               visWidth  :=  LPrm and $FFFF;
               visHeight :=  (LPrm div $10000);
             end; { Someone forgot to implement SHL/SHR in P32 ?!? }
    else begin
      MainWndProc := DefWindowProcA(hWindow, msg, wPrm, lPrm);
    end;
  end;
end;

begin
  InitStars;
  ghInstance := GetModuleHandleA(NULL);
  wc.lpszClassName := @strStarsCl+1;
  wc.lpfnWndProc := @MainWndProc;
  wc.style := CS_OWNDC or CS_VREDRAW or CS_HREDRAW;
  wc.hInstance := ghInstance;
  wc.handleIcon := LoadIconA(NULL, IDI_WINLOGO);
  wc.handleCursor := LoadCursorA(NULL, IDC_ARROW);
  wc.hbrBackground := HBRUSH(COLOR_WINDOWTEXT+1);
  wc.lpszMenuName := NULL;
  wc.cbClsExtra := 0;
  wc.cbWndExtra := 0;
  RegisterClassA(wc);
  winHandle := CreateWindowExA(0, @strStarsCl+1, @strTitle+1, {WS_DLGFRAME or WS_SYSMENU}WS_OVERLAPPEDWINDOW,
                 0, 0, 639, 479, NULL, NULL, ghInstance, NULL);
  ShowWindow(winHandle, SW_SHOWDEFAULT);
  TimerId := SetTimer(winHandle, 1, 25, NULL);
  if TimerId <> 0 then
    repeat
      if GetMessageA(winMsg, NULL, 0, 0) > 0 then begin
        TranslateMessage(winMsg);
        DispatchMessageA(winMsg);
      end
      else break;
    until FALSE;
end.

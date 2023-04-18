program WinBFD;
(* BFD GUI version.
   Copyright (c) 1998 by Leonardo H. Liporati.
   Free software. Provided in an AS IS basis. No warranties.
   Feel free to make modifications and improvements.

   Known problem:
    - At least 580Kb free conventional memory needed to compile with P32 v04d.
*)

uses windows;

const IDM_ABOUT = 1000; { Menu commands constants }
      IDM_OPEN  = 1001;
      IDM_CLOSE = 1002;
      IDM_EXIT  = 1003;
      SCREEN_LINES = 23; { Default number of lines in our window }
      BYTES_PER_LINE = 16; { Number of bytes dumped in one line } 
      CHARS_PER_LINE = 4*(BYTES_PER_LINE+1)+1;
      HexDigits: String[16] = '0123456789ABCDEF';
      strBFDAppCl = 'BFDAppClass'+#0;
      strBFDAppMn = 'BFDAppMenu'+#0;
      strBFDApp   = 'Binary File Dumper - GUI version'+#0;
      strAboutDlg = 'AboutDlg'+#0;
      strCannotOpen = 'Cannot open'+#0;
      strIcon     = 'BFDIcon'+#0;
      strHeapError = 'Not enough memory to perform operation'+#0;
      strFileFilter = 'EXE Files'+#0+'*.exe'+#0+'DLL Files'+#0+'*.dll'+#0+
                      'All Files'+#0+'*.*'+#0+#0;

type VariantArray = Array [0..0] of Byte;

var FileBuffer: ^VariantArray;
    BinFile: File;
    BinFileSize, CurrentLine,
    LinesInPage, TotalLines: LongInt;
    IsOpened: Boolean;
    wc: WNDCLASS;
    winMsg: MSG;
    winHandle: HWND;
    ghInstance: HANDLE;
    ScrXSize, ScrYSize, 
    WinHeight,
    CharWidth, CharHeight: LongInt;
    FullFilePath: string;
    ofn: OPENFILENAME;


procedure InitVars(winhnd: HWND);
begin
  IsOpened:= FALSE;
  BinFileSize:= 0;
  TotalLines:= 0;
  CurrentLine:= 0;
  SetScrollRange(winhnd, SB_VERT, 0, 0, FALSE); { Hide scroll bar }
end;

procedure DoFileClose(winhnd: HWND);
begin
  FreeMem(FileBuffer,BinFileSize);
  InitVars(winhnd);
  Close(BinFile);
end;


procedure DoFileOpen(winhnd: HWND);
var NumChars, BytesReaden: Longint;
    ptrRect: LPRECT;
begin
  ofn.lStructSize:= SizeOf(ofn);         { size of struture } 
  ofn.hwndOwner:= winhnd;                { owner of dialog }
  ofn.hInstance:= 0;                     { ignored }
  ofn.lpstrFilter:= @strFileFilter+1;    { filter string pointer }
  ofn.lpstrCustomFilter:= NULL;          { not used }
  ofn.nMaxCustFilter:= 0;                { ignored }
  ofn.nFilterIndex:= 1;                  { default filter is BMP Files }
  FullFilePath:= '';                     { Initialize with no name }
  ofn.lpstrFile:= @FullFilePath+1;
  ofn.nMaxFile:= SizeOf(FullFilePath)-1;
  ofn.lpstrFileTitle:= NULL;             { we don't need NAME.EXT only }
  ofn.nMaxFileTitle:= 0;                 { ignored }
  ofn.lpstrInitialDir:= NULL;            { start in current directory }
  ofn.lpstrTitle:= NULL;                 { use default title: "Open" }
  ofn.Flags:= OFN_FILEMUSTEXIST or OFN_HIDEREADONLY;
  ofn.lpstrDefExt:= NULL;                { don't append file extension } 
  ofn.lCustData:= NULL;                  { ignored }
  ofn.lpfnHook:= NULL;                   { ignored }
  ofn.lpTemplateName:= NULL;             { ignored } 
  if GetOpenFileNameA(ofn) <> 0 then begin
    if IsOpened then DoFileClose; { Close previous file }
    { Transform null terminated string into Pascal string }
    NumChars:= 1;
    While FullFilePath[NumChars] <> #0 Do Inc(NumChars);
    FullFilePath[0]:= Char(NumChars-1);
    Assign(BinFile, FullFilePath);
    Reset(BinFile,1);
    if IOResult <> 0 then
      MessageBoxA(winhnd,@FullFilePath+1,@strCannotOpen+1,MB_OK)
    else begin
      { Discover filesize and allocated a buffer to hold the whole file }
      BinFileSize:= filesize(BinFile);
      GetMem(FileBuffer,BinFileSize);
      if FileBuffer <> nil then begin { Buffer successfully allocated }
        IsOpened:= TRUE;
        BlockRead(BinFile, FileBuffer^, BinFileSize, BytesReaden);
        { Compute total lines, adjust scroll bar range and position on first line }
        TotalLines:= (BinFileSize-1) div BYTES_PER_LINE; 
        CurrentLine:= 0;
        { Force redraw of scroll bar and window }
        SetScrollRange(winhnd, SB_VERT, 0, TotalLines, FALSE);
        SetScrollPos(winhnd, SB_VERT, 0, TRUE);
        InvalidateRect(winhnd, ptrRect^, TRUE); 
      end
      else begin { Insuficient heap space }
        Close(BinFile);
        BinFileSize:= 0;
        MessageBoxA(winhnd,@strHeapError+1,@strCannotOpen+1,MB_OK);
      end;
    end;
  end;
end;

procedure PaintCurrentBuffer(DCHandle: HDC; FromLine, ToLine: LongInt);
var I, J, K: LongInt;
    CurrentByte: Byte;
    AsciiText: String[BYTES_PER_LINE];
    HexaText: String[BYTES_PER_LINE*3+2];
begin
  if ToLine > TotalLines then ToLine:= TotalLines;
  for I:= FromLine to ToLine do begin
    AsciiText:= '                '; { Sixteen spaces }
    HexaText:= '                                                - '; 
    for J:= 0 to BYTES_PER_LINE-1 do begin
      K:= I*BYTES_PER_LINE + J;
      if K < BinFileSize then begin
        CurrentByte:= FileBuffer^[K];
        if CurrentByte < 32 then 
          AsciiText[J+1]:= '.'
        else AsciiText[J+1]:= Char(CurrentByte);
        HexaText[(J*3)+1]:= HexDigits[(CurrentByte shr 4)+1];
        HexaText[(J*3)+2]:= HexDigits[(CurrentByte and $0F)+1];
      end
      else begin
        AsciiText[J+1]:= ' '
        HexaText[(J*3)+1]:= ' ';
        HexaText[(J*3)+2]:= ' ';
      end;
    end;
    TextOutA(DCHandle, CharWidth, (I-FromLine)*CharHeight, @HexaText+1, Length(HexaText));
    TextOutA(DCHandle, CharWidth*3*(BYTES_PER_LINE+1), (I-FromLine)*CharHeight,
             @AsciiText+1, Length(AsciiText));
  end;
end;


function AboutDlgProc(hDlg: HWND; uMsg: UINT; wPrm: WPARAM; lPrm: LPARAM): LRESULT;
begin
  AboutDlgProc := FALSE;
  case uMsg of
    WM_INITDIALOG: AboutDlgProc := TRUE;
    WM_COMMAND: if wPrm = IDOK then begin
                  AboutDlgProc := TRUE;
                  EndDialog(hDlg, 0);
                end;
  end;
end;


var textmtr: TEXTMETRIC;

function MainWndProc(hWindow: HWND; msg: UINT; wPrm: WPARAM; lPrm: LPARAM): LRESULT;
var ps: PAINTSTRUCT;
    si: SCROLLINFO;
    DCHandle: HDC;
    hOldFont: HGDIOBJ;
    XPos, YPos, Width, Increment: LongInt;
    ptrRect: LPRECT;
begin
  asm   { Little bug discovered. EDI register must be preserved by callback functions }
    push edi
  end;
  ptrRect:= nil;
  MainWndProc := FALSE;
  case msg of
    WM_CREATE: begin
                 DCHandle:= GetDC(hWindow);
                 { Let's use a fixed point font. It is better for our needs }
                 hOldFont:= SelectObject(DCHandle, GetStockObject(ANSI_FIXED_FONT));
                 { Let's obtain the width and height of chars for selected font }
                 GetTextMetricsA(DCHandle, textmtr);
                 CharWidth:= textmtr.tmMaxCharWidth;
                 CharHeight:= textmtr.tmHeight + textmtr.tmExternalLeading;
                 { Let's calcule the size and the position for our window }
                 { We need a window centered in screen }
                 Width:= CharWidth*CHARS_PER_LINE + GetSystemMetrics(SM_CXVSCROLL);
                 WinHeight:= CharHeight*(SCREEN_LINES+2) + GetSystemMetrics(SM_CYMENU);
                 LinesInPage:= (WinHeight div CharHeight);
                 XPos:= (ScrXSize-Width) div 2;
                 YPos:= (ScrYSize-WinHeight) div 2;
                 { Resize and repositions window in screen }
                 MoveWindow(hWindow, XPos, YPos, Width, WinHeight, FALSE);
                 { Restore old font }
                 SelectObject(DCHandle, hOldFont);
                 ReleaseDC(hWindow, DCHandle);
              end;
    WM_GETMINMAXINFO:
              begin { Don't permit user change the Width of our window }
                Width:= CharWidth*CHARS_PER_LINE + GetSystemMetrics(SM_CXVSCROLL);
                PMINMAXINFO(lPrm)^.ptMaxSize.X:= Width;
                PMINMAXINFO(lPrm)^.ptMinTrackSize.X:= Width;
                PMINMAXINFO(lPrm)^.ptMaxTrackSize.X:= Width;
              end;
    WM_SIZE: begin { Recalculate number of lines in window }
               WinHeight:= (lprm shr 16) + GetSystemMetrics(SM_CYMENU);
               LinesInPage:= (WinHeight div CharHeight);
             end;
    WM_VSCROLL: begin
                  case wPrm and $FFFF of
                    SB_PAGEDOWN: Increment:= LinesInPage-1;
                    SB_LINEDOWN: Increment:= 1;
                    SB_PAGEUP: Increment:= -LinesInPage+1;
                    SB_LINEUP: Increment:= -1;
                    SB_THUMBPOSITION: begin
                                        { Initialize scrollinfo }     
                                        si.cbSize:= SizeOf(si);
                                        si.fMask:= SIF_TRACKPOS;
                                        { Get current tracking position }
                                        GetScrollInfo(hWindow, SB_VERT, si);
                                        Increment:= si.nTrackPos - CurrentLine;
                                      end;
                    else Increment:= 0;
                  end;
                  if Increment <> 0 then begin
                    Inc(CurrentLine, Increment);
                    if CurrentLine < 0 then CurrentLine:= 0;
                    if CurrentLine > TotalLines then CurrentLine:= TotalLines;
                    SetScrollPos(hWindow,SB_VERT,CurrentLine,TRUE);
                    InvalidateRect(hWindow, ptrRect^, TRUE);
                  end;
                end;
    WM_PAINT: begin
                DCHandle:= BeginPaint(hWindow, ps);
                if IsOpened then begin
                  hOldFont:= SelectObject(DCHandle, GetStockObject(ANSI_FIXED_FONT));
                  PaintCurrentBuffer(DCHandle,CurrentLine,CurrentLine+LinesInPage);
                  SelectObject(DCHandle, hOldFont);
                end;
                EndPaint(hWindow, ps);
              end;
    WM_COMMAND: case wPrm of
                  IDM_ABOUT: DialogBoxParamA(ghInstance, @strAboutDlg+1,
                                             hWindow, @AboutDlgProc, 0);
                  IDM_OPEN : DoFileOpen(hWindow);
                  IDM_CLOSE: If IsOpened Then DoFileClose(hWindow);
                  IDM_EXIT : SendMessageA(hWindow, WM_CLOSE, 0, 0);
                end;
    WM_DESTROY: PostQuitMessage(0);
    else MainWndProc := DefWindowProcA(hWindow, msg, wPrm, lPrm);
  end;
  asm
    pop edi
  end;
end;

begin
  ghInstance := GetModuleHandleA(NULL);
  { Setup our window class }
  wc.lpszClassName := @strBFDAppCl+1;
  wc.lpfnWndProc := @MainWndProc;
  wc.style := CS_OWNDC or CS_VREDRAW or CS_HREDRAW;
  wc.hInstance := ghInstance;
  wc.handleIcon := LoadIconA(ghInstance, @strIcon+1);
  wc.handleCursor := LoadCursorA(NULL, IDC_ARROW);
  wc.hbrBackground := HBRUSH(COLOR_WINDOW+1);
  wc.lpszMenuName := @strBFDAppMn+1;
  wc.cbClsExtra := 0;
  wc.cbWndExtra := 0;
  RegisterClassA(wc);
  { Let's obtain X and Y dimensions of the screen }
  ScrXSize := GetSystemMetrics(SM_CXSCREEN);
  ScrYSize := GetSystemMetrics(SM_CYSCREEN);
  { Create a window in default pos and size but adjust it when processing WM_CREATE }
  winHandle := CreateWindowExA(0, @strBFDAppCl+1, @strBFDApp+1, WS_VSCROLL or WS_OVERLAPPEDWINDOW,
       CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, NULL, NULL, ghInstance, NULL);
  InitVars(winHandle);
  ShowWindow(winHandle, SW_SHOWDEFAULT);
  repeat 
    if GetMessageA(winMsg, NULL, 0, 0) > 0 then begin
      TranslateMessage(winMsg);
      DispatchMessageA(winMsg);
    end
    else break;
  until FALSE;
  if IsOpened then Close(BinFile);
end.

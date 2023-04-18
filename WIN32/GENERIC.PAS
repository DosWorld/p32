program GenericGUIApp;
(* An example of a GENERIC Graphical Windows App using P32 compiler *)

uses Windows;

const IDM_ABOUT = 1000;
      strGenAppCl = 'GenericAppClass'+#0;
      strGenAppMn = 'GenericAppMenu'+#0;
      strGenApp   = 'Generic GUI Application with P32'+#0;
      strHello    = 'Hello world! P32 does Windows 95 GUI applications!';
      strAboutDlg = 'AboutDlg'+#0;
      strP32Icon  = 'P32Icon'+#0;

var wc: WNDCLASS;
    winMsg: MSG;
    winHandle: HWND;
    ghInstance: HANDLE;

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

function MainWndProc(hWindow: HWND; msg: UINT; wPrm: WPARAM; lPrm: LPARAM): LRESULT;
var ps: PAINTSTRUCT;
    DCHandle: HDC;
begin
  MainWndProc := FALSE;
  case msg of
    WM_PAINT: begin
                DCHandle := BeginPaint(winHandle, ps);
                TextOutA(DCHandle, 10, 10, @strHello+1, Length(strHello));
                EndPaint(winHandle, ps);
              end;
    WM_COMMAND: if wPrm = IDM_ABOUT then
                  DialogBoxParamA(ghInstance, @strAboutDlg+1, hWindow, @AboutDlgProc, 0);
    WM_DESTROY: PostQuitMessage(0);
    else begin
           MainWndProc := DefWindowProcA(hWindow, msg, wPrm, lPrm);
         end;
  end;  
end;

begin
  ghInstance := GetModuleHandleA(NULL);
  wc.lpszClassName := @strGenAppCl+1;
  wc.lpfnWndProc := @MainWndProc;
  wc.style := CS_OWNDC or CS_VREDRAW or CS_HREDRAW;
  wc.hInstance := ghInstance;
  wc.handleIcon := LoadIconA(ghInstance, @strP32Icon+1);
  wc.handleCursor := LoadCursorA(NULL, IDC_ARROW);
  wc.hbrBackground := HBRUSH(COLOR_WINDOW+1);
  wc.lpszMenuName := @strGenAppMn+1;
  wc.cbClsExtra := 0;
  wc.cbWndExtra := 0;
  RegisterClassA(wc);
  winHandle := CreateWindowExA(0, @strGenAppCl+1, @strGenApp+1, WS_OVERLAPPEDWINDOW,
       0, 0, 512, 256, NULL, NULL, ghInstance, NULL);
  ShowWindow(winHandle, SW_SHOWDEFAULT);
  repeat 
    if GetMessageA(winMsg, NULL, 0, 0) > 0 then begin
      TranslateMessage(winMsg);
      DispatchMessageA(winMsg);
    end
    else break;
  until FALSE;
end.

unit windows;

interface
{ Types for compatibility between P32 and Win32 }
(* Win32 stuff: APIs, types and constants definitions needed for SYSTEM and CRT units *)

{ Win32 types }
type {DWORD  = LongInt;} {already defined inside the compiler}
     ATOM   = Word;
     HICON  = LongInt;
     HBRUSH = LongInt;
     HCURSOR= HICON;
     HWND   = LongInt;
     HDC    = LongInt;
     HMENU  = LongInt;
     HBITMAP= LongInt;
     HGDIOBJ= LongInt;
     HINSTANCE=LongInt;
     HMODULE= LongInt;
     WCHAR  = Word;
     BOOL   = LongInt;
     UINT   = LongInt;
     LONG   = LongInt;
     PLONG  = ^LONG;
     HANDLE = LongInt;
     LPDWORD= ^DWORD;
     LPVOID = Pointer;
     LPCSTR = Pointer;
     LPCTSTR= Pointer;
     SECURITY_ATTRIBUTES = record
       nLength: DWORD;
       lpSecurityDescriptor: LPVOID;
       bInheritHandle: BOOL;
     end;
     LPSECURITY_ATTRIBUTES = ^SECURITY_ATTRIBUTES;
     LPTSTR = Pointer;
     WNDPROC= Pointer;
     DLGPROC= Pointer;
     WPARAM = UINT;
     LPARAM = DWORD;
     LRESULT= LongInt;
     COLORREF = LongInt;
     SHORT = Word;
     RECT = record
              Left, Top, Right, Bottom : LONG;
            end;
     LPRECT = ^RECT;
     COORD = record
               case choose : boolean of
                 false : (WholeCoord : LongInt);
                 true  : (X, Y: SHORT);
             end;
     SMALL_RECT = record
                    Left, Top, Right, Bottom : SHORT;
                  end;
     CHAR_INFO = record
                   FillChar   : WCHAR;
                   Attributes : Word;
                 end;
     CONSOLE_SCREEN_BUFFER_INFO = record
                                    dwSize, dwCursorPosition : COORD;
                                    wAttributes : WORD;
                                    srWindow    : SMALL_RECT;
                                    dwMaximumWindowSize : COORD;
                                  end;
     PCONSOLE_SCREEN_BUFFER_INFO = ^CONSOLE_SCREEN_BUFFER_INFO;
     KEY_EVENT_RECORD = record
                          bKeyDown : BOOL;
                          wRepeatCount, wVirtualKeyCode, wVirtualScanCode: WORD;
                          AsciiChar: WCHAR;
                          dwControlKeyState: DWORD;
                        end;
     INPUT_RECORD = record
                      EventType: WORD;
                      Case WhichEvent:WORD of
                        1: (KeyEvent: KEY_EVENT_RECORD);
{                        2: MouseEvent: MOUSE_EVENT_RECORD;
                        3: WindowBufferSizeEvent: WINDOW_BUFFER_SIZE_RECORD;
                        4: MenuEvent: MENU_EVENT_RECORD;
                        5: FocusEvent: FOCUS_EVENT_RECORD; }
                    end;
     PINPUT_RECORD = ^INPUT_RECORD;
     WNDCLASS = record
                  style: UINT;
                  lpfnWndProc  : WNDPROC;
                  cbClsExtra,
                  cbWndExtra   : LongInt;
                  hInstance    : HANDLE; 
                  handleIcon   : HICON; 
                  handleCursor : HCURSOR; 
                  hbrBackground: HBRUSH; 
                  lpszMenuName, 
                  lpszClassName: LPCTSTR;
                end;
     POINT = record
               X, Y: LongInt;
             end;
     MINMAXINFO = record  
                    ptReserved,
                    ptMaxSize,
                    ptMaxPosition,
                    ptMinTrackSize,
                    ptMaxTrackSize: POINT;
                  end;
     PMINMAXINFO = ^MINMAXINFO;
     MSG = record
             hwnd   : HWND;
             message: UINT;
             wParam : WPARAM;
             lParam : LPARAM;
             time   : DWORD;
             pt     : POINT;
           end;
     PAINTSTRUCT = record
                     handleDC   : HDC;
                     fErase     : BOOL;
                     rcPaint    : RECT;
                     fRestore,
                     fIncUpdate : BOOL;
                     rgbReserved: Array[0..31] of BYTE;
                   end;
     LPPAINTSTRUCT  = ^PAINTSTRUCT;
     RGBQUAD = record
                 rgbBlue, rgbGreen, rgbRed, rgbReserved : BYTE;
               end;
     BITMAPINFOHEADER = record
                          biSize         : DWORD;
                          biWidth,
                          biHeight       : LONG;
                          biPlanes,
                          biBitCount     : WORD;
                          biCompression,
                          biSizeImage    : DWORD;
                          biXPelsPerMeter,
                          biYPelsPerMeter: LONG;
                          biClrUsed,
                          biClrImportant : DWORD;
                        end;
     PBITMAPINFOHEADER = ^BITMAPINFOHEADER;
     BITMAPINFO = record
                    bmiHeader : BITMAPINFOHEADER;
                    bmiColors : array[0..255] of RGBQUAD;
                  end;
     PBITMAPINFO = ^BITMAPINFO;
     TEXTMETRIC = record
                    tmHeight,
                    tmAscent, 
                    tmDescent,
                    tmInternalLeading,
                    tmExternalLeading,
                    tmAveCharWidth,
                    tmMaxCharWidth,
                    tmWeight,
                    tmOverhang,
                    tmDigitizedAspectX,
                    tmDigitizedAspectY: LongInt;
                    tmFirstChar,
                    tmLastChar,
                    tmDefaultChar,
                    tmBreakChar: Char;
                    tmItalic,
                    tmUnderlined,
                    tmStruckOut,
                    tmPitchAndFamily,
                    tmCharSet: Byte;
                  end;
     OPENFILENAME = record
                      lStructSize: DWORD;
                      hwndOwner: HWND;
                      hInstance: HINSTANCE;
                      lpstrFilter: LPCTSTR;
                      lpstrCustomFilter: LPTSTR;
                      nMaxCustFilter,
                      nFilterIndex: DWORD;
                      lpstrFile: LPTSTR;
                      nMaxFile: DWORD;
                      lpstrFileTitle: LPTSTR;
                      nMaxFileTitle: DWORD;
                      lpstrInitialDir,
                      lpstrTitle: LPCTSTR;
                      Flags: DWORD;
                      nFileOffset,
                      nFileExtension: WORD;
                      lpstrDefExt: LPCTSTR;
                      lCustData: DWORD;
                      lpfnHook: Pointer;
                      lpTemplateName: LPCTSTR;
                    end;
     SCROLLINFO = record
                    cbSize,
                    fMask: UINT;
                    nMin,
                    nMax: LongInt;
                    nPage: UINT;
                    nPos,
                    nTrackPos: LongInt;
                  end;

{ Win32 constants }
const
      NULL = Pointer(0);

      STD_INPUT_HANDLE  = DWORD(-10);
      STD_OUTPUT_HANDLE = DWORD(-11);
      STD_ERROR_HANDLE  = DWORD(-12);

      CREATE_NEW        = 1;
      CREATE_ALWAYS     = 2;
      OPEN_EXISTING     = 3;
      OPEN_ALWAYS       = 4;
      TRUNCATE_EXISTING = 5;

      INVALID_HANDLE_VALUE = HANDLE(-1);
      INVALID_FILE_SIZE    = DWORD($FFFFFFFF);

      FILE_BEGIN   = 0;
      FILE_CURRENT = 1;
      FILE_END     = 2;

      GENERIC_READ    = $80000000;
      GENERIC_WRITE   = $40000000;
      GENERIC_EXECUTE = $20000000;
      GENERIC_ALL     = $10000000;

      FILE_SHARE_READ   = $00000001;
      FILE_SHARE_WRITE  = $00000002;
      FILE_SHARE_DELETE = $00000004;
      FILE_ATTRIBUTE_READONLY   = $00000001;
      FILE_ATTRIBUTE_HIDDEN     = $00000002;
      FILE_ATTRIBUTE_SYSTEM     = $00000004;
      FILE_ATTRIBUTE_DIRECTORY  = $00000010;
      FILE_ATTRIBUTE_ARCHIVE    = $00000020;
      FILE_ATTRIBUTE_NORMAL     = $00000080;
      FILE_ATTRIBUTE_TEMPORARY  = $00000100;
      FILE_ATTRIBUTE_COMPRESSED = $00000800; 
      FILE_ATTRIBUTE_OFFLINE    = $00001000;

      MAX_PATH = 260;
------------------------------------------------ }
      { Event types }
      KEY_EVENT                = $0001;
      MOUSE_EVENT              = $0002;
      WINDOW_BUFFER_SIZE_EVENT = $0004;
      MENU_EVENT               = $0008;
      FOCUS_EVENT              = $0010;

      { ShowWindow modes }
      SW_HIDE          = $00;
      SW_SHOWNORMAL    = $01;
      SW_SHOWMINIMIZED = $02;
      SW_SHOWMAXIMIZED = $03;
      SW_SHOWNOACTIVATE= $04;
      SW_SHOW          = $05;
      SW_MINIMIZE      = $06;
      SW_SHOWMINNOACTIVE=$07;
      SW_RESTORE       = $09;
      SW_SHOWDEFAULT   = $0A;

      { PeekMessage constants }
      PM_NOREMOVE = 0;
      PM_REMOVE   = 1;
      PM_NOYIELD  = 2;

      { Window messages }
      WM_CREATE        = $0001;
      WM_DESTROY       = $0002;
      WM_SIZE          = $0005;
      WM_ACTIVATE      = $0006;
      WM_SETFOCUS      = $0007;
      WM_KILLFOCUS     = $0008;
      WM_ENABLE        = $000A;
      WM_SETREDRAW     = $000B;
      WM_SETTEXT       = $000C;
      WM_GETTEXT       = $000D;
      WM_GETTEXTLENGTH = $000E;
      WM_PAINT         = $000F;
      WM_CLOSE         = $0010;
      WM_QUERYENDSESSION=$0011;
      WM_QUIT          = $0012;
      WM_QUERYOPEN     = $0013;
      WM_ERASEBKGND    = $0014;
      WM_SYSCOLORCHANGE= $0015;
      WM_ENDSESSION    = $0016;
      WM_SHOWWINDOW    = $0018;
      WM_WININICHANGE  = $001A;
      WM_DEVMODECHANGE = $001B;
      WM_ACTIVATEAPP   = $001C;
      WM_FONTCHANGE    = $001D;
      WM_TIMECHANGE    = $001E;
      WM_CANCELMODE    = $001F;
      WM_SETCURSOR     = $0020;
      WM_MOUSEACTIVATE = $0021;
      WM_GETMINMAXINFO = $0024;
      WM_NOTIFY        = $004E;
      WM_HELP          = $0053;
      WM_KEYDOWN       = $0100;
      WM_KEYUP         = $0101;
      WM_CHAR          = $0102;
      WM_INITDIALOG    = $0110;
      WM_COMMAND       = $0111;
      WM_TIMER         = $0113;
      WM_HSCROLL       = $0114;
      WM_VSCROLL       = $0115;
      WM_MENUSELECT    = $011F;
      WM_CTLCOLORDLG   = $0136;
      WM_MOUSEMOVE     = $0200;
      WM_LBUTTONDOWN   = $0201;
      WM_LBUTTONUP     = $0202;
      WM_LBUTTONDBLCLK = $0203;
      WM_RBUTTONDOWN   = $0204;
      WM_RBUTTONUP     = $0205;
      WM_RBUTTONDBLCLK = $0206;
      WM_MBUTTONDOWN   = $0207;
      WM_MBUTTONUP     = $0208;
      WM_MBUTTONDBLCLK = $0209;
      WM_CUT           = $0300;
      WM_COPY          = $0301;
      WM_PASTE         = $0302;
      WM_CLEAR         = $0303;
      WM_UNDO          = $0304;
      WM_USER          = $0400;

      { Class styles }
      CS_VREDRAW         = $0001;
      CS_HREDRAW         = $0002;
      CS_DBLCLKS         = $0008;
      CS_OWNDC           = $0020;
      CS_CLASSDC         = $0040;
      CS_PARENTDC        = $0080;
      CS_NOCLOSE         = $0200;
      CS_SAVEBITS        = $0800;
      CS_BYTEALIGNCLIENT = $1000;
      CS_BYTEALIGNWINDOW = $2000;
      CS_GLOBALCLASS     = $4000;

      { Cursor IDs }
      IDC_ARROW       = Pointer(32512);
      IDC_IBEAM       = Pointer(32513);
      IDC_WAIT        = Pointer(32514);
      IDC_CROSS       = Pointer(32515);
      IDC_UPARROW     = Pointer(32516);
      IDC_SIZENWSE    = Pointer(32642);
      IDC_SIZENESW    = Pointer(32643);
      IDC_SIZEWE      = Pointer(32644);
      IDC_SIZENS      = Pointer(32645);
      IDC_SIZEALL     = Pointer(32646);
      IDC_NO          = Pointer(32648);
      IDC_APPSTARTING = Pointer(32650);
      IDC_HELP        = Pointer(32651);

      IDOK     = 1;
      IDCANCEL = 2;
      IDABORT  = 3;
      IDRETRY  = 4;
      IDIGNORE = 5;
      IDYES    = 6;
      IDNO     = 7;
      IDCLOSE  = 8;
      IDHELP   = 9;

      { MessageBox buttons }
      MB_OK               = 0;
      MB_OKCANCEL         = 1;
      MB_ABORTRETRYIGNORE = 2;
      MB_YESNOCANCEL      = 3;
      MB_YESNO            = 4;
      MB_RETRYCANCEL      = 5;
      MB_SYSTEMMODAL      = $1000;
      MB_TASKMODAL        = $2000;
      MB_APPLMODAL        = 0;

      { Window styles }
      WS_OVERLAPPED  = $00000000;
      WS_POPUP       = $80000000;
      WS_CHILD       = $40000000;
      WS_MINIMIZE    = $20000000;
      WS_VISIBLE     = $10000000;
      WS_DISABLED    = $08000000;
      WS_CLIPSIBLINGS= $04000000;
      WS_CLIPCHILDREN= $02000000;
      WS_MAXIMIZE    = $01000000;
      WS_BORDER      = $00800000;
      WS_DLGFRAME    = $00400000;
      WS_VSCROLL     = $00200000;
      WS_HSCROLL     = $00100000;
      WS_SYSMENU     = $00080000;
      WS_THICKFRAME  = $00040000;
      WS_MINIMIZEBOX = $00020000;
      WS_MAXIMIZEBOX = $00010000;
      WS_CAPTION     = WS_BORDER or WS_DLGFRAME;
      WS_OVERLAPPEDWINDOW = WS_OVERLAPPED or WS_BORDER or WS_SYSMENU or WS_DLGFRAME or
                             WS_THICKFRAME or WS_MINIMIZEBOX or WS_MAXIMIZEBOX;
      WS_POPUPWINDOW = WS_POPUP or WS_BORDER or WS_SYSMENU;

      { Extended window styles }
      WS_EX_TOPMOST  = 8;

      CW_USEDEFAULT = $80000000;

      { Icon IDs }
      IDI_APPLICATION = Pointer(32512);
      IDI_HAND        = Pointer(32513);
      IDI_QUESTION    = Pointer(32514);
      IDI_EXCLAMATION = Pointer(32515);
      IDI_ASTERISK    = Pointer(32516);
      IDI_WINLOGO     = Pointer(32517);

      { System colors }
      COLOR_3DDKSHADOW          = 21;
      COLOR_3DFACE              = 15;
      COLOR_3DHILIGHT           = 20;
      COLOR_3DLIGHT             = 22;
      COLOR_BTNHILIGHT          = 20;
      COLOR_3DSHADOW            = 16;
      COLOR_ACTIVEBORDER        = 10;
      COLOR_ACTIVECAPTION       = 2;
      COLOR_APPWORKSPACE        = 12;
      COLOR_BACKGROUND          = 1;
      COLOR_DESKTOP             = 1;
      COLOR_BTNFACE             = 15;
      COLOR_BTNHIGHLIGHT        = 20;
      COLOR_BTNSHADOW           = 16;
      COLOR_BTNTEXT             = 18;
      COLOR_CAPTIONTEXT         = 9;
      COLOR_GRAYTEXT            = 17;
      COLOR_HIGHLIGHT           = 13;
      COLOR_HIGHLIGHTTEXT       = 14;
      COLOR_INACTIVEBORDER      = 11;
      COLOR_INACTIVECAPTION     = 3;
      COLOR_INACTIVECAPTIONTEXT = 19;
      COLOR_INFOBK              = 24;
      COLOR_INFOTEXT            = 23;
      COLOR_MENU                = 4;
      COLOR_MENUTEXT            = 7;
      COLOR_SCROLLBAR           = 0;
      COLOR_WINDOW              = 5;
      COLOR_WINDOWFRAME         = 6;
      COLOR_WINDOWTEXT          = 8;

      DIB_PAL_COLORS = 1;
      DIB_RGB_COLORS = 0;
      
      BI_RGB       = 0;
      BI_RLE8      = 1;
      BI_RLE4      = 2;
      BI_BITFIELDS = 3;

      { Background modes }
      TRANSPARENT = 1;
      OPAQUE      = 2;

      { Raster operation codes }
      BLACKNESS   = $42;
      NOTSRCERASE = $1100A6;
      NOTSRCCOPY  = $330008;
      SRCERASE    = $440328;
      DSTINVERT   = $550009;
      PATINVERT   = $5A0049;
      SRCINVERT   = $660046;
      SRCAND      = $8800C6;
      MERGEPAINT  = $BB0226;
      MERGECOPY   = $C000CA;
      SRCCOPY     = $CC0020;
      SRCPAINT    = $EE0086;
      PATCOPY     = $F00021;
      PATPAINT    = $FB0A09;
      WHITENESS   = $FF0062;

      { Virtual keys codes }
      VK_LBUTTON  = 1;
      VK_RBUTTON  = 2;
      VK_CANCEL   = 3;
      VK_MBUTTON  = 4;
      VK_BACK     = 8;
      VK_TAB      = 9;
      VK_CLEAR    = 12;
      VK_RETURN   = 13;
      VK_SHIFT    = 16;
      VK_CONTROL  = 17;
      VK_MENU     = 18;
      VK_PAUSE    = 19;
      VK_PRINT    = 42;
      VK_CAPITAL  = 20;
      VK_ESCAPE   = 27;
      VK_SPACE    = 32;
      VK_PRIOR    = 33;
      VK_NEXT     = 34;
      VK_END      = 35;
      VK_HOME     = 36;
      VK_LEFT     = 37;
      VK_UP       = 38;
      VK_RIGHT    = 39;
      VK_DOWN     = 40;
      VK_SELECT   = 41;
      VK_EXECUTE  = 43;
      VK_SNAPSHOT = 44;
      VK_INSERT   = 45;
      VK_DELETE   = 46;
      VK_HELP     = 47;

      { Scroll bars flags }
      SB_BOTH = 3;
      SB_CTL  = 2;
      SB_HORZ = 0;
      SB_VERT = 1;

      { Scroll codes }
      SB_LINEUP        = 0;
      SB_LINEDOWN      = 1;
      SB_LINELEFT      = 0;
      SB_LINERIGHT     = 1;
      SB_PAGEUP        = 2;
      SB_PAGEDOWN      = 3;
      SB_PAGELEFT      = 2;
      SB_PAGERIGHT     = 3;
      SB_THUMBPOSITION = 4;
      SB_THUMBTRACK    = 5;
      SB_ENDSCROLL     = 8;
      SB_LEFT          = 6;
      SB_RIGHT         = 7;
      SB_BOTTOM        = 7;
      SB_TOP           = 6;

      { System metrics parameters }
      SM_CYMIN             = 29;
      SM_CXMIN             = 28;
      SM_ARRANGE           = 56;
      SM_CLEANBOOT         = 67;
      SM_CMETRICS          = 75;
      SM_CMOUSEBUTTONS     = 43;
      SM_CXBORDER          = 5;
      SM_CYBORDER          = 6;
      SM_CXCURSOR          = 13;
      SM_CYCURSOR          = 14;
      SM_CXDLGFRAME        = 7;
      SM_CYDLGFRAME        = 8;
      SM_CXDOUBLECLK       = 36;
      SM_CYDOUBLECLK       = 37;
      SM_CXDRAG            = 32;
      SM_CYDRAG            = 33;
      SM_CXEDGE            = 32;
      SM_CYEDGE            = 33;
      SM_CXFIXEDFRAME      = 32;
      SM_CYFIXEDFRAME      = 33;
      SM_CXFRAME           = 32;
      SM_CYFRAME           = 33;
      SM_CXFULLSCREEN      = 16;
      SM_CYFULLSCREEN      = 17;
      SM_CXHSCROLL         = 21;
      SM_CYHSCROLL         = 3;
      SM_CXHTHUMB          = 10;
      SM_CXICON            = 11;
      SM_CYICON            = 12;
      SM_CXICONSPACING     = 38;
      SM_CYICONSPACING     = 39;
      SM_CXMAXIMIZED       = 61;
      SM_CYMAXIMIZED       = 62;
      SM_CXMAXTRACK        = 59;
      SM_CYMAXTRACK        = 60;
      SM_CXMENUCHECK       = 71;
      SM_CYMENUCHECK       = 72;
      SM_CXMENUSIZE        = 54;
      SM_CYMENUSIZE        = 55;
      SM_CXMINIMIZED       = 57;
      SM_CYMINIMIZED       = 58;
      SM_CXMINSPACING      = 47;
      SM_CYMINSPACING      = 48;
      SM_CXMINTRACK        = 34;
      SM_CYMINTRACK        = 35;
      SM_CXSCREEN          = 0;
      SM_CYSCREEN          = 1;
      SM_CXSIZE            = 30;
      SM_CYSIZE            = 31;
      SM_CXSIZEFRAME       = 32;
      SM_CYSIZEFRAME       = 33;
      SM_CXSMICON          = 49;
      SM_CYSMICON          = 50;
      SM_CXSMSIZE          = 52;
      SM_CYSMSIZE          = 53;
      SM_CXVSCROLL         = 2;
      SM_CYVSCROLL         = 20;
      SM_CYVTHUMB          = 9;
      SM_CYCAPTION         = 4;
      SM_CYKANJIWINDOW     = 18;
      SM_CYMENU            = 15;
      SM_CYSMCAPTION       = 51;
      SM_DBCSENABLED       = 42;
      SM_DEBUG             = 22;
      SM_MENUDROPALIGNMENT = 40;
      SM_MIDEASTENABLED    = 74;
      SM_MOUSEPRESENT      = 19;
      SM_NETWORK           = 63;
      SM_PENWINDOWS        = 41;
      SM_SECURE            = 44;
      SM_SHOWSOUNDS        = 70;
      SM_SLOWMACHINE       = 73;
      SM_SWAPBUTTON        = 23;
      SM_RESERVED1         = 24;
      SM_RESERVED2         = 25;
      SM_RESERVED3         = 26;
      SM_RESERVED4         = 27;

      { Stock objects }
      BLACK_BRUSH         = 4;
      DKGRAY_BRUSH        = 3;
      GRAY_BRUSH          = 2;
      HOLLOW_BRUSH        = 5;
      LTGRAY_BRUSH        = 1;
      NULL_BRUSH          = 5;
      WHITE_BRUSH         = 0;
      BLACK_PEN           = 7;
      NULL_PEN            = 8;
      WHITE_PEN           = 6;
      ANSI_FIXED_FONT     = 11;
      ANSI_VAR_FONT       = 12;
      DEVICE_DEFAULT_FONT = 14;
      DEFAULT_GUI_FONT    = 17;
      OEM_FIXED_FONT      = 10;
      SYSTEM_FONT         = 13;
      SYSTEM_FIXED_FONT   = 16;
      DEFAULT_PALETTE     = 15;

      { Open file name Flags }
      OFN_ALLOWMULTISELECT     = 512;
      OFN_CREATEPROMPT         = $2000;
      OFN_ENABLEHOOK           = 32;
      OFN_ENABLETEMPLATE       = 64;
      OFN_ENABLETEMPLATEHANDLE = 128;
      OFN_EXPLORER             = $80000;
      OFN_EXTENSIONDIFFERENT   = $400;
      OFN_FILEMUSTEXIST        = $1000;
      OFN_HIDEREADONLY         = 4;
      OFN_LONGNAMES            = $200000;
      OFN_NOCHANGEDIR          = 8;
      OFN_NODEREFERENCELINKS   = $100000;
      OFN_NOLONGNAMES          = $40000;
      OFN_NONETWORKBUTTON      = $20000;
      OFN_NOREADONLYRETURN     = $8000;
      OFN_NOTESTFILECREATE     = $10000;
      OFN_NOVALIDATE           = 256;
      OFN_OVERWRITEPROMPT      = 2;
      OFN_PATHMUSTEXIST        = $800;
      OFN_READONLY             = 1;
      OFN_SHAREAWARE           = $4000;
      OFN_SHOWHELP             = 16;
      OFN_SHAREFALLTHROUGH     = 2;
      OFN_SHARENOWARN          = 1;
      OFN_SHAREWARN            = 0;
 
      { Scroll info masks }
      SIF_RANGE           = 1;
      SIF_PAGE            = 2;
      SIF_POS             = 4;
      SIF_DISABLENOSCROLL = 8;
      SIF_TRACKPOS        = 16;
      SIF_ALL             = SIF_RANGE or SIF_PAGE or SIF_POS or SIF_TRACKPOS;
 
{ ---------- Win32 APIs ---------- }

{ --- Process and Thread Functions --- }
procedure Sleep(dwMilliseconds: DWORD);

{ --- Console Functions --- }
function FillConsoleOutputCharacter(hConsoleOutput: Handle; cCharacter: Char;
  nLength: DWORD; dwWriteCoord: Coord; var lpNumberOfCharsWritten: DWORD): BOOL;
function FillConsoleOutputAttribute(hConsoleOutput: Handle; wAttribute: Word;
  nLength: DWORD; dwWriteCoord: Coord; var lpNumberOfAttrsWritten: DWORD): BOOL;
function GetNumberOfConsoleInputEvents(hConsoleInput: HANDLE; lpcNumberOfEvents: LPDWORD): BOOL; 
function GetStdHandle(nStdHandle: DWORD): HANDLE; 
function GetConsoleMode(hConsoleHandle: HANDLE; lpMode: LPDWORD): BOOL; 
function GetConsoleScreenBufferInfo(hConsoleOutput: HANDLE; lpConsoleScreenBufferInfo: PCONSOLE_SCREEN_BUFFER_INFO): BOOL; 
function PeekConsoleInputA(hConsoleInput: HANDLE; lpBuffer: PINPUT_RECORD; nLength: DWORD; 
  lpNumberOfEventsRead: LPDWORD): BOOL; 
function ReadConsoleInputA(hConsoleInput: HANDLE; lpBuffer: PINPUT_RECORD; nLength: DWORD;
  lpNumberOfEventsRead: LPDWORD): BOOL; 
function ReadConsoleA(hConsoleInput: HANDLE; lpBuffer: LPVOID; nNumberOfCharsToRead: DWORD; lpNumberOfCharsRead: LPDWORD;
  lpReserved: LPVOID): BOOL; 
function ScrollConsoleScreenBufferA(hConsoleOutput: HANDLE; var ScrollRectangle, ClipRectangle: SMALL_RECT;
  dwDestinationOrigin: COORD; var Fill: CHAR_INFO): BOOL; 
function SetConsoleMode(hConsoleHandle: HANDLE; dwMode: DWORD): BOOL; 
function SetConsoleCursorPosition(hConsoleOutput: HANDLE; coordCursor: LongInt{COORD}): BOOL; 
function SetConsoleTextAttribute(hConsoleOutput: HANDLE; wAttr: word): BOOL; 
function WriteConsoleA(hConsoleOutput: HANDLE; lpBuffer: LPVOID; nNumberOfBytesToWrite: DWORD;
              var NumberOfBytesWritten: DWORD; lpReserved: LPVOID): BOOL; 

{ --- Window Class Functions --- }
function RegisterClassA(var lpwc : WNDCLASS): ATOM;

{ --- Window Functions --- }
function CloseWindow(hWindow: HWND): BOOL;
function CreateWindowExA(dwExStyle: DWORD; lpClassName: LPCTSTR; lpWindowName: LPCTSTR; dwStyle: DWORD; x, y, nWidth, nHeight: LongInt;
  hWndParent: HWND; hMenu: HMENU; hInstance: HANDLE; lpParam: LPVOID): HWND;
function DestroyWindow(hWindow: HWND):BOOL;
function GetClientRect(hWindow: HWND; ptRect: LPRECT): BOOL;
function GetForegroundWindow: HWND;
function GetTopWindow(hWindow: HWND): HWND;
function MoveWindow(hWindow: HWND; X, Y, nWidth, nHeight: LongInt; bRepaint: BOOL): BOOL;
function OpenIcon(hWindow: HWND): BOOL;
function ShowWindow(hWindow: HWND; nCmdShow: LongInt): BOOL;

{ --- Painting and Drawing Functions --- }
function BeginPaint(hWindow: HWND; var lpPaint: PAINTSTRUCT): HDC;
function EndPaint(hWindow: HWND; var lpPaint: PAINTSTRUCT): BOOL;
function GdiFlush: BOOL;
function InvalidateRect(hWindow: HWND; var lpRect: RECT; bErase: BOOL): BOOL;
function SetBkMode(hDvC: HDC; iBkMode: LongInt): LongInt; 
function UpdateWindow(hWindow: HWND): BOOL;	
 
{ --- Font and Text Functions --- }
function GetTextMetricsA(hDvC: HDC; var lptm: TEXTMETRIC): BOOL;
function SetTextColor(hDvC: HDC; crColor: COLORREF): COLORREF;
function TextOutA(hDvC: HDC; nXStart, nYStart: LongInt; lpString: LPCTSTR; cbString: LongInt): BOOL;

{ --- Dialog Box Functions --- }
function DialogBoxParamA(hInstance: HANDLE; lpTemplate: LPCTSTR; hWndParent: HWND; lpDialogFunc: DLGPROC; dwInitParam: LPARAM): LongInt;
function EndDialog(hDlg: HWND; nResult: LongInt): BOOL; 
function MessageBoxA(hWindow: HWND; lpText, lpCaption: LPCTSTR; uType: UINT): LongInt;

{--- Common Dialog Box Functions ---}
function GetOpenFileNameA(var lpofn: OPENFILENAME): BOOL;
function GetSaveFileNameA(var lpofn: OPENFILENAME): BOOL;

{ --- Message and Message Queue Functions --- }
function DefWindowProcA(hWindow: HWND; Msg: UINT; wPrm: WPARAM; lPrm: LPARAM): LRESULT;
function DispatchMessageA(var lpmsg: MSG): LongInt;
function GetMessageA(var lpMsg: MSG; hWindow: HWND; wMsgFilterMin, wMsgFilterMax: UINT): BOOL;
function SendMessageA(hWindow: HWND; Msg: UINT; wPrm: WPARAM; lPrm: LPARAM): LRESULT;
function PeekMessageA(var lpMsg: MSG; hWindow: HWND; wMsgFilterMin, wMsgFilterMax, wRemoveMsg: UINT): BOOL; 
function PostMessageA(hWindow: HWND; Msg: UINT; wPrm: WPARAM; lPrm: LPARAM): BOOL;
procedure PostQuitMessage(nExitCode: LongInt);
function TranslateMessage(var lpMsg: MSG): BOOL; 

{ --- Cursor Functions --- }
function LoadCursorA(hInstance: HANDLE; lpCursorName: LPCTSTR): HCURSOR;
function GetCursorPos(var lpPoint: POINT): BOOL;

{ --- Icon Functions --- }
function LoadIconA(hInstance: HANDLE; lpIconName: LPCTSTR): HICON; 

{ --- Dynamic-Link Library Functions --- }
function FreeLibrary(hLibModule: HMODULE): BOOL;	
function GetModuleHandleA(lpModuleName: LPCTSTR): HMODULE;
function LoadLibraryA(lpLibFileName: LPCTSTR): HINSTANCE;
function GetProcAddress(hModule: HMODULE; lpProcName: LPCSTR): Pointer; 

{ --- Bitmap Functions --- }
function BitBlt(hdcDest: HDC; nXDest, nYDest, nWidth, nHeight: LongInt; hdcSrc: HDC;
  nXSrc, nYSrc: LongInt; dwRop: DWORD): BOOL;
function CreateDIBSection(hDvC: HDC; pbmi: PBITMAPINFO; iUsage: UINT; var ppvBits: Pointer; hSection: HANDLE;
  dwOffset: DWORD): HBITMAP;
function SetPixel(hDvC: HDC; X, Y: LongInt; crColor: COLORREF): COLORREF;
function StretchBlt(hdcDest: HDC; nXOriginDest, nYOriginDest, nWidthDest, nHeightDest: LongInt;
  hdcSrc: HDC; nXOriginSrc, nYOriginSrc, nWidthSrc, nHeightSrc: LongInt; dwRop: DWORD): BOOL;

{ --- Timer Functions --- }
function KillTimer(hWindow: HWND; uIDEvent: UINT): BOOL; 
function SetTimer(hWindow: HWND; nIDEvent, uElapse: UINT; lpTimerFunc: Pointer): UINT;

{ --- Device Context Functions --- }
function CreateCompatibleDC(hDvC: HDC): HDC;
function DeleteDC(hDvC: HDC): BOOL;
function DeleteObject(hObject: HANDLE): BOOL;	
function GetDC(hWindow: HWND): HDC;
function GetStockObject(fnObject: LongInt): HGDIOBJ;
function ReleaseDC(hWindow: HWND; hDvC: HDC): LongInt; 
function SelectObject(hDvC: HDC; hobj: HGDIOBJ): HANDLE;

{ --- System Information Functions --- }
function GetSysColor(nIndex: LongInt): DWORD;
function GetSystemMetrics(nIndex: LongInt): LongInt;
function SetSysColors(cElements: LongInt; var lpaElements: LongInt; var lpaRgbValues: COLORREF): BOOL;

{ --- Scroll Bar Functions --- }
function GetScrollPos(hWindow: HWND; nBar: LongInt): LongInt;
function GetScrollInfo(hWindow: HWND; fnBar: LongInt; var lpsi:SCROLLINFO): BOOL;
function SetScrollRange(hWindow: HWND; nBar, nMinPos, nMaxPos: LongInt; bRedraw: BOOL): BOOL;
function SetScrollPos(hWindow:HWND; nBar, nPos: LongInt; bRedraw: BOOL): LongInt;
{ ------ End of Win32 APIs ------ }
(* ********************** END of Win32 stuff ******************************* *)

implementation
{ ---------- Win32 APIs ---------- }

{ --- Process and Thread functions --- }
procedure Sleep(dwMilliseconds: DWORD); win32api;

{ --- Console functions --- }
function GetNumberOfConsoleInputEvents(hConsoleInput: HANDLE; lpcNumberOfEvents: LPDWORD): BOOL; win32api;
function GetStdHandle(nStdHandle: DWORD): HANDLE; win32api;
function GetConsoleMode(hConsoleHandle: HANDLE; lpMode: LPDWORD): BOOL; win32api;
function GetConsoleScreenBufferInfo(hConsoleOutput: HANDLE; lpConsoleScreenBufferInfo: PCONSOLE_SCREEN_BUFFER_INFO): BOOL; win32api;
function FillConsoleOutputCharacter(hConsoleOutput: Handle; cCharacter: Char;
  nLength: DWORD; dwWriteCoord: Coord; var lpNumberOfCharsWritten: DWORD): BOOL; win32api;
function FillConsoleOutputAttribute(hConsoleOutput: Handle; wAttribute: Word;
  nLength: DWORD; dwWriteCoord: Coord; var lpNumberOfAttrsWritten: DWORD): BOOL; win32api;
function PeekConsoleInputA(hConsoleInput: HANDLE; lpBuffer: PINPUT_RECORD; nLength: DWORD;
  lpNumberOfEventsRead: LPDWORD): BOOL; win32api;
function ReadConsoleInputA(hConsoleInput: HANDLE; lpBuffer: PINPUT_RECORD; nLength: DWORD;
  lpNumberOfEventsRead: LPDWORD): BOOL; win32api;
function ReadConsoleA(hConsoleInput: HANDLE; lpBuffer: LPVOID; nNumberOfCharsToRead: DWORD; lpNumberOfCharsRead: LPDWORD;
  lpReserved: LPVOID): BOOL; win32api;
function ScrollConsoleScreenBufferA(hConsoleOutput: HANDLE; var ScrollRectangle, ClipRectangle: SMALL_RECT;
  dwDestinationOrigin: COORD; var Fill: CHAR_INFO): BOOL; win32api;
function SetConsoleMode(hConsoleHandle: HANDLE; dwMode: DWORD): BOOL; win32api;
function SetConsoleCursorPosition(hConsoleOutput: HANDLE; coordCursor: LongInt {COORD}): BOOL; win32api;
function SetConsoleTextAttribute(hConsoleOutput: HANDLE; wAttr: word): BOOL; win32api;
function WriteConsoleA(hConsoleOutput: HANDLE; lpBuffer: LPVOID; nNumberOfBytesToWrite: DWORD;
              var NumberOfBytesWritten: DWORD; lpReserved: LPVOID): BOOL; win32api;

{ --- Window class functions --- }
function RegisterClassA(var lpwc : WNDCLASS): ATOM; win32api;

{ --- Window functions ---}
function CloseWindow(hWindow: HWND): BOOL; win32api;
function CreateWindowExA(dwExStyle: DWORD; lpClassName: LPCTSTR; lpWindowName: LPCTSTR; dwStyle: DWORD; x, y, nWidth, nHeight: LongInt;
  hWndParent: HWND; hMenu: HMENU; hInstance: HANDLE; lpParam: LPVOID): HWND; win32api;
function DestroyWindow(hWindow: HWND):BOOL; win32api;
function GetClientRect(hWindow: HWND; ptRect: LPRECT): BOOL; win32api;
function GetForegroundWindow: HWND; win32api;
function GetTopWindow(hWindow: HWND): HWND; win32api;
function MoveWindow(hWindow: HWND; X, Y, nWidth, nHeight: LongInt; bRepaint: BOOL): BOOL; win32api;
function OpenIcon(hWindow: HWND): BOOL; win32api;
function ShowWindow(hWindow: HWND; nCmdShow: LongInt): BOOL; win32api;

{ --- Painting and Drawing Functions --- }
function BeginPaint(hWindow: HWND; var lpPaint: PAINTSTRUCT): HDC; win32api;
function EndPaint(hWindow: HWND; var lpPaint: PAINTSTRUCT): BOOL; win32api;
function GdiFlush: BOOL; win32api;
function InvalidateRect(hWindow: HWND; var lpRect: RECT; bErase: BOOL): BOOL;	win32api;
function SetBkMode(hDvC: HDC; iBkMode: LongInt): LongInt; win32api;
function UpdateWindow(hWindow: HWND): BOOL; win32api;

{ --- Font and Text Functions --- }
function GetTextMetricsA(hDvC: HDC; var lptm: TEXTMETRIC): BOOL; win32api;
function SetTextColor(hDvC: HDC; crColor: COLORREF): COLORREF; win32api;
function TextOutA(hDvC: HDC; nXStart, nYStart: LongInt; lpString: LPCTSTR; cbString: LongInt): BOOL; win32api;

{--- Dialog Box Functions ---}
function DialogBoxParamA(hInstance: HANDLE; lpTemplate: LPCTSTR; hWndParent: HWND; lpDialogFunc: DLGPROC; dwInitParam: LPARAM): LongInt; win32api; 
function EndDialog(hDlg: HWND; nResult: LongInt): BOOL; win32api;
function MessageBoxA(hWindow: HWND; lpText, lpCaption: LPCTSTR; uType: UINT): LongInt; win32api;

{--- Common Dialog Box Functions ---}
function GetOpenFileNameA(var lpofn: OPENFILENAME): BOOL; win32api;
function GetSaveFileNameA(var lpofn: OPENFILENAME): BOOL; win32api;

{ --- Message and Message Queue Functions --- }
function DefWindowProcA(hWindow: HWND; Msg: UINT; wPrm: WPARAM; lPrm: LPARAM): LRESULT; win32api;
function DispatchMessageA(var lpmsg: MSG): LongInt; win32api;
function GetMessageA(var lpMsg: MSG; hWindow: HWND; wMsgFilterMin, wMsgFilterMax: UINT): BOOL; win32api;
function SendMessageA(hWindow: HWND; Msg: UINT; wPrm: WPARAM; lPrm: LPARAM): LRESULT; win32api;
function PeekMessageA(var lpMsg: MSG; hWindow: HWND; wMsgFilterMin, wMsgFilterMax, wRemoveMsg: UINT): BOOL; win32api;
function PostMessageA(hWindow: HWND; Msg: UINT; wPrm: WPARAM; lPrm: LPARAM): BOOL; win32api;
procedure PostQuitMessage(nExitCode: LongInt); win32api;
function TranslateMessage(var lpMsg: MSG): BOOL; win32api;

{ --- Cursor Functions --- }
function LoadCursorA(hInstance: HANDLE; lpCursorName: LPCTSTR): HCURSOR; win32api;
function GetCursorPos(var lpPoint: POINT): BOOL; win32api;

{ --- Icon Functions --- }
function LoadIconA(hInstance: HANDLE; lpIconName: LPCTSTR): HICON; win32api;

{ --- Dynamic-Link Library Functions --- }
function FreeLibrary(hLibModule: HMODULE): BOOL; win32api;
function GetModuleHandleA(lpModuleName: LPCTSTR): HMODULE; win32api;
function LoadLibraryA(lpLibFileName: LPCTSTR): HINSTANCE; win32api;
function GetProcAddress(hModule: HMODULE; lpProcName: LPCSTR): Pointer; win32api;

{ --- Bitmap Functions --- }
function BitBlt(hdcDest: HDC; nXDest, nYDest, nWidth, nHeight: LongInt; hdcSrc: HDC;
  nXSrc, nYSrc: LongInt; dwRop: DWORD): BOOL; win32api;
function CreateDIBSection(hDvC: HDC; pbmi: PBITMAPINFO; iUsage: UINT; var ppvBits: Pointer; hSection: HANDLE;
  dwOffset: DWORD): HBITMAP; win32api;
function SetPixel(hDvC: HDC; X, Y: LongInt; crColor: COLORREF): COLORREF; win32api;
function StretchBlt(hdcDest: HDC; nXOriginDest, nYOriginDest, nWidthDest, nHeightDest: LongInt;
  hdcSrc: HDC; nXOriginSrc, nYOriginSrc, nWidthSrc, nHeightSrc: LongInt; dwRop: DWORD): BOOL; win32api;

{ --- Timer Functions --- }
function KillTimer(hWindow: HWND; uIDEvent: UINT): BOOL; win32api;
function SetTimer(hWindow: HWND; nIDEvent, uElapse: UINT; lpTimerFunc: Pointer): UINT; win32api;

{ --- Device Context Functions --- }
function CreateCompatibleDC(hDvC: HDC): HDC; win32api;
function DeleteDC(hDvC: HDC): BOOL; win32api;
function DeleteObject(hObject: HANDLE): BOOL; win32api;
function GetDC(hWindow: HWND): HDC; win32api;
function GetStockObject(fnObject: LongInt): HGDIOBJ; win32api;
function ReleaseDC(hWindow: HWND; hDvC: HDC): LongInt; win32api;
function SelectObject(hDvC: HDC; hobj: HGDIOBJ): HANDLE; win32api;

{ --- System Information Functions --- }
function GetSysColor(nIndex: LongInt): DWORD; win32api;
function GetSystemMetrics(nIndex: LongInt): LongInt; win32api;
function SetSysColors(cElements: LongInt; var lpaElements: LongInt; var lpaRgbValues: COLORREF): BOOL; win32api;

{ --- Scroll Bar Functions --- }
function GetScrollPos(hWindow: HWND; nBar: LongInt): LongInt; win32api;
function GetScrollInfo(hWindow: HWND; fnBar: LongInt; var lpsi:SCROLLINFO): BOOL; win32api;
function SetScrollRange(hWindow: HWND; nBar, nMinPos, nMaxPos: LongInt; bRedraw: BOOL): BOOL; win32api;
function SetScrollPos(hWindow:HWND; nBar, nPos: LongInt; bRedraw: BOOL): LongInt; win32api;
{ ------ End of Win32 APIs ------ }

begin
end.

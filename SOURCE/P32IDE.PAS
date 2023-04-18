(****************************************************************************

               P32IDE - 32bit Pascal Compiler with IDE

 ---------------------------------------------------------------------------
                   Michael Goddard - magnesium@hehe.com (IDE)
                       Johan Prins - jprins@knoware.nl (P32)
 ==========================================================================
 Main-program for IDE version                                 P32IDE (c)'99
 http://surf.to/p32
 --------------------------------------------------------------------------

 Email: magnesium@hehe.com (no attachments)
        cgoddard@ozemail.com.au (for attachments)
        jprins@knoware.nl (To do with the compiler)

  P32IDE is now part of P32, an IDE attachment for this 32 bit Pascal
 compiler. And your reading the sources right now. All I and Johan ask
 is that you learn from this, help us in this, and write good programs
 in this. The compiler is a later version so is neater.
 Plus it generates pretty tight code compared with other compilers.
 The IDE uses Object's, see P32IDEU.PAS for a better view. Ok, enough
 typing, just read the sources and rulez on changing.

 Rulez: (Some rulez when adding to the code)
  1. Mark your code like so
     {** <Your Name, and an email if you wish> }
     This is so I (& others) can find the changes. (via Find '**')
  2. Only comment the previous code if changed.
     After we all make sure it works the old stuff can be removed
  3. Email the files you change to Johan if it's part of the
     compiler, or me (cgoddard@ozemail.com.au/magnesium@hehe.com)
     if it's MMOUSE.PAS, P32IDE.PAS or P32IDEU.PAS.
     If you don't get a reply within a week ask the other one of us.
  4. Remember! The code must be compilable in either the Command
     Line version or the IDE by changing the compiler directive
     only. (and using P32.PAS not P32IDE.PAS)
  5. If your not sure you should do something just ask, there is
     a reason or some things but most of the IDE welcomes
     improvements, all you need to do is ask :)
  6. Your name goes in the contributors (unless you don't want it in)
     if you write a sizable part, ie. don't expect much for two lines
     of code apart from a thankyou. (unless it's a _really_ big bug)

 TODO:
  - Bracket Highlighting, incl () & [] separately
     Rewrite Highlighting to store some info like
       CP_Long (Where Cursor is)
       ??       If it's a (/[/)/] IsHighlight
                & the Position of the matching one
       ??       Same as above for BEGIN/END as word
                position's
  - Allow nested comments when it's set in the compiler
  - Add a GREP and FC Command
  - Ctrl-Enter opens ???.PAS at cursor pos.
  - Fix File window to use the scroll Bar
  - Fix the SourceWindow to -Xs/Ys from the Scroll size to scroll properly
    from the fix to get end of scroller = end of text, not page below

 Bugs:
  - When changing ScreenSize the Mouse isn't re-inited always to fit in
    new screen size, DOIT.
  - On a highlighted word like BEGIN/END/CASE/RECORD the end will not be
    highlighted if the initial BEGIN.. is above the top displayed line
    This is fixable, scanning backwards through the file if an END is
    found but it's just not done yet.
  - Something strange is occuring during highlighting the first word if
    comments preceed it, only on some words sometimes, strange.
  - On Errors, if there is no semicolon, the error appears on the wrong
    line, a new variable in the compiler is needed to store pre-parsing
    position, I think.


FIXES:

Changes by Johan:

- Fixed reading of P32.INI (finding correct path)
- Replaced UCASE procedure by ToUpper (in P32_SCAN.PAS)
- Added support for '--' comments, Note! NextLevel isn't updated...
- Changed homepage reference in about box
- DOS Shell is working again
- Submenu can 'cycle' now
- Text files are loaded as linked lists now. This means that filesize is only
  limited by the available memory!
- Added preliminary Cut/Copy/Paste functions.
- Fixed bug in menu displaying
- Added CheckBox object
- Added compiler options and editor options dialogs
- Moved syntax and block highlighting to editor dialog
- Re-implemented mouse support
- Added MessageBox object
- AboutBox works without memory leaks!
- Re-implemented ErrorBox, Information dialog, ASCII table.
- Added CPU info to the information dialog
- Re-implemented scrollbars, they're completely OO now, _very_ easy to use

****************************************************************************)

{$M 16384, 0, 655250}
Uses P32IDEU, P32_cfg, P32_scan, P32_err, Dos;

{-
  Function to convert ANY number string to a Real number.
   ie. Decimal     2, 4k, 8Mb, 4.2kb
       Binary      0110b, %100k, %1001.101
       Hex         0xA0, $B4, 0Dhk
       Octal       73o, 3.5oMb
       Ternary     1021t
       Multipliers k/Kb = *1024, m/Mb = * 1024*1024 . . .
-}
Var BCP_StrToNum_LastError: Integer;

Function BCP_StrToNumR(St: String): Real;

Const HexTable: String = ('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ');

Label BCP_NumberProcessed;
Var nType: (None, Dec, Hex, Bin, Oct, Chr, Ter); NewNum: Real;
    i: byte;Mult: Longint;dp, nchmul: Longint;

begin
 BCP_StrToNumR := 0;NewNum := 0;St := ToUpper(St); Mult := 1;
 nchmul := 10; BCP_StrToNum_LastError := 0; dp := 0;

 {- Find Multipliers -}
 If (St[Length(St)] = 'K') then begin;Delete(St, Length(St), 1);Mult := 1024;end;
 If (St[Length(St)] = 'M') then begin;Delete(St, Length(St), 1);Mult := 1024 * 1024;end;
 If (St[Length(St)] = 'G') then begin;Delete(St, Length(St), 1);Mult := 1024 * 1024 * 1024;end;
 If (St[Length(St)-1] = 'K') and (St[Length(St)] = 'B') and (Length(St) > 2) then
     begin;Delete(St, Length(St)-1, 2);Mult := 1024;end;
 If (St[Length(St)-1] = 'M') and (St[Length(St)] = 'B') and (Length(St) > 2) then
     begin;Delete(St, Length(St)-1, 2);Mult := 1024 * 1024;end;
 If (St[Length(St)-1] = 'G') and (St[Length(St)] = 'B') and (Length(St) > 2) then
     begin;Delete(St, Length(St)-1, 2);Mult := 1024 * 1024 * 1024;end;

 {- Decimals have no signature so we check for non-decimal chars -}
 nType := Dec;
 For i:=1 to length(St) do
  if not (St[i] in ['0'..'9','.']) then nType := None;
 {- Check for FirstChar Number types first - like Pascal -}
 if (nType = none) then
 Case St[1] of
   '0': if St[2] = 'x' then begin;nType := Hex;Delete(St, 1, 2);end;
   '$': begin;nType := Hex;Delete(St, 1, 1);end;
   '%': begin;nType := Bin;Delete(St, 1, 1);end;
 end;
 {- Now check Assembler style number -}
 if (nType = none) then
 Case St[Length(St)] of
   'H': begin;nType := Hex;Delete(St, Length(St), 1);end;
   'B': begin;nType := Bin;Delete(St, Length(St), 1);end;
   'O': begin;nType := Oct;Delete(St, Length(St), 1);end;
   'T': begin;nType := Ter;Delete(St, Length(St), 1);end;
 end;

 {- Get the Base of the number -}
 Case nType of
  Dec: nchmul := 10;
  Hex: nchmul := 16;
  Oct: nchmul := 8;
  Ter: nchmul := 3;
  Bin: nchmul := 2;
 end;

 {- Convert the chars to a Real, upto Base36, INCLUDING FRACTIONAL! -}
 for i:=1 to Length(St) do
 begin
  Case St[i] of
   '.': dp := nchmul; {- You can even use 1011.101b -}
  else
   if (dp = 0) then
    NewNum := NewNum * nchmul + (Pos(St[i], HexTable)-1)
   else
    begin
     NewNum := NewNum + ((Pos(St[i], HexTable)-1) / dp);
     dp := dp * nchmul;
    end;
  end;

  {- Process errors - like a 2 in a binary string or G in Hex -}
  if ((Pos(St[i], HexTable)-1) > nchmul) then
  begin
   BCP_StrToNum_LastError := i;
   BCP_StrToNumR := 0;
   exit;
  end;

 end;
 {- Use multiplies to output in correct units (Kb/Mb/Gb...) -}
 BCP_StrToNumR := NewNum * Mult;
end;

function IsTrueST(St: String): Boolean;
begin
  St := ToUpper(St);
  if (St = 'YES') then IsTrueST := True else
  if (St = 'TRUE') then IsTrueST := True else
  if (St = 'ON') then IsTrueST := True else
  if (St = 'NO') then IsTrueST := False else
  if (St = 'FALSE') then IsTrueST := False else
  if (St = 'OFF') then IsTrueST := False else
  Writeln('Error parsing INI-file');
end;

function Trim(St: string): string;
begin;
  While (St[1] in [#0,#32,#255]) and (St[0]<>#0) do Delete(St, 1, 1);
  While (St[Length(St)] in [#0,#32,#255]) and (St[0]<>#0) do Delete(St, Length(St), 1);
  Trim := St;
end;

procedure SetValB(var b: integer; St: string);
var BNum: Longint;

begin
  St := Trim(St);
  BNum := Round(BCP_StrToNumR(St));
  if BCP_StrToNum_LastError = 0 then b := bnum;
end;

procedure ReadINI(St: String);

var cSt, ParST: string;
    Th        : Text;
    cSEC      : (_none, _Colour, _IDE, _P32);

begin
  assign(Th, St);
  reset(Th);
  repeat
    Readln(Th, cSt);
    While (cSt[1] in [#0,#32,#255]) and (cSt[0]<>#0) do
      Delete(cSt, 1, 1);
    if Pos(';', cSt)>0 then
      cSt[0] := Chr(Pos(';', cSt)-1);
    ParST := '';
    if Pos('=', cSt)>0 then
      begin
       ParST := cSt;
       cSt[0] := Chr(Pos('=', cSt)-1);
       Delete(ParSt, 1, Length(cSt)+1);
       cSt := Trim(cSt);
       ParST := Trim(ParSt);
      end;

    cSt := ToUpper(cSt);
    case cSt[1] of
    '[': begin
           cSEC := _none;
           if (cSt = '[IDE]') then cSEC := _IDE;
           {- COLOR for the Americans who spell it wrong -}
           if (cSt = '[COLOR]') then cSEC := _Colour;
           if (cSt = '[COLOUR]') then cSEC := _Colour;
         end;
    else begin
           if ParST <> '' then
             Case cSEC of
             _IDE:    begin
                        if cSt = 'NONAME' then IDE.P32.NoName := ParST;
                        if cSt = 'EXT' then IDE.P32.Ext := ParST;
                        if cSt = 'WIDTH' then SetValB(IDE.Width, ParST);
                        if cSt = 'HEIGHT' then SetValB(IDE.Height, ParST);
                        if Copy(cSt,1,9) = 'NESTEDCOM' then IDE.NestComment := IsTrueST(ParST);
                        if Copy(cSt,1,7) = 'NESTCOM' then IDE.NestComment := IsTrueST(ParST);
                      end;
             _Colour: begin {- Saves time in typing SYNTAX all the time -}
                        if Copy(cSt, 1, 2) = 'S.' then Insert('YNTAX', cSt, 2);
                        {- Least amount of chars required to ID the string -}
                        if Copy(cSt,1,9) = 'SYNTAX.CO' then SetValB(IDE.c.Syntax.Comment    , ParST);
                        if cSt = 'SYNTAX.RESERVED'     then SetValB(IDE.c.Syntax.Reserved   , ParST);
                        if cSt = 'SYNTAX.RES'          then SetValB(IDE.c.Syntax.Reserved   , ParST);
                        if cSt = 'SYNTAX.RESERVED2'    then SetValB(IDE.c.Syntax.Reserved2  , ParST);
                        if cSt = 'SYNTAX.RES2'         then SetValB(IDE.c.Syntax.Reserved2  , ParST);
                        if Copy(cSt,1,9) = 'SYNTAX.ID' then SetValB(IDE.c.Syntax.Identifiers, ParST);
                        if Copy(cSt,1,9) = 'SYNTAX.SY' then SetValB(IDE.c.Syntax.Symbols    , ParST);
                        if Copy(cSt,1,9) = 'SYNTAX.ST' then SetValB(IDE.c.Syntax.Strings    , ParST);
                        if Copy(cSt,1,8) = 'SYNTAX.N'  then SetValB(IDE.c.Syntax.Numbers    , ParST);
                        if Copy(cSt,1,8) = 'SYNTAX.A'  then SetValB(IDE.c.Syntax.AsmSrc     , ParST);
                        if cSt = 'SYNTAX.NONE'         then SetValB(IDE.c.Syntax.None       , ParST);

                        if cSt = 'ERROR'               then SetValB(IDE.c.Error             , ParST);
                        if cSt = 'BUTTON'              then SetValB(IDE.c.Button            , ParST);
                        if Copy(cSt,1,7) = 'BUTTONH'   then SetValB(IDE.c.ButtonH           , ParST);
                      end;
             end;
         end;
   end;
  until Eof(Th);
  close(Th);
end;

{- Reads the command line checking for valid filenames and loads them -}
Procedure ReadParams;
var i  : word;
    s  : string;
   _D  : DirStr;
   _N  : NameStr;
   _E  : ExtStr;

begin
 for i:=1 to ParamCount do
 begin
   s:=ToUpper(ParamStr(i));
   if FileExists(s) then
     begin {file with no extension, that exists}
       FileString := s;
       cmSend(cm_LoadEdit);
     end
   else    {file with no extension, ADD .pas}
     begin
       fsplit(s, _D, _N, _E);
       if _E='' then _E:='.PAS';
       s:=_D+_N+_E;
       if FileExists(s) then
         begin {file with added .pas extension, that exists}
           FileString := s;
           cmSend(cm_LoadEdit);
         end;
     end;
 end;
end;

var inipath: string;

begin
  writeln('P32 ' + P32_version + ' by Johan Prins, jprins@knoware.nl    [' + compiledate+']');
  writeln('P32IDE '+ P32IDE_Ver + ' by Michael Goddard, cgoddard@ozemail.com.au');

  inipath:=FSearch('P32.INI','.\;'+GetEnv('P32')+';'+GetEnv('P32')+'\BIN\;'+GetEnv('PATH'));
  if inipath='' then Error('P32.INI not found');

  ReadINI(inipath);

  SetVideoMode(IDE.Width, IDE.Height);

  IDE_Init;

  ReadParams;

  IDE.Quit := False;

  repeat {main program loop}
    ProcessEvents;
  until IDE.Quit;

 IDE_Done;
end.

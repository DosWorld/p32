{                         P32 - 32bit Pascal Compiler                        }
{ -------------------------------------------------------------------------- }
{                       Johan Prins - jprins@knoware.nl                      }
{ ========================================================================== }
{ Error reporting unit                                                       }
{                                                   (c) Copyright 1996-1999  }
{                                                                            }
{ -------------------------------------------------------------------------- }
{ $DEFINE P32IDE}

unit P32_err;

interface

var LineCount:longint;

procedure LineError(Line:longint; s:string);
{Reports an error with the linenumber}
procedure Hint(Line: longint; s:string);
{Reports a hint with the linenumber, compilation continues...}
procedure Abort(s:string);
{Reports an error and compilation is stopped, exit with errorcode 100}
procedure Expected(s:string);
{Reports an error when something is expected, like a ';', stops compilation}
procedure Error(s:string);
{Reports an generic error}

{$IFDEF VER70}
procedure RunTimeExitProc;
{Reports an error when there is a runtime-error, exit with errorcode 255}
{$ENDIF}

{$IFDEF P32IDE}
procedure CompileFileMessage(St: String);
{Sends a message to display the new file name}
procedure ShowLineNum;
{Shows the current line no. in a window}
{$ENDIF}
procedure SetRuntimeErrorHandler;

implementation

uses P32_prep, P32_scan, dos
{$IFDEF P32IDE}
  , P32IDEU
{$ENDIF}
  ;

var OldExit:pointer;

{$IFDEF P32IDE}
Procedure CompileFileMessage(St: String);
begin
 { Add IDE stuff HERE }
 CompileStatus_NewFile(St);
end;
{$ENDIF}

procedure LineError(Line:longint; s:string);
var a:string;
    i:integer;
begin
{$IFDEF P32IDE}
  {- Insert disposal info here -}
  ShowERROR(Line, s);
{$IFNDEF DPMI}
  Release(HeapOrg);
{$ENDIF}
{$ELSE}
  a:=TextRec(source^).Name;
  i:=0;
  repeat
    inc(i);
  until (a[i]=#0) or (i>255);
  a[0]:=char(i-1);
  writeln;
  writeln(a, ' (Line: ', Line , ') - Error: ', s, '.');
{$IFNDEF DPMI}
  Release(HeapOrg);
{$ENDIF}
  Halt(75);
{$ENDIF}
end;

procedure Hint(Line: longint; s:string);
var a:string;
    i:integer;

begin
  if not Options.Hints then exit;
  a:=TextRec(source^).Name;
  i:=0;
  repeat
    inc(i);
  until (a[i]=#0) or (i>255);
  a[0]:=char(i-1);
  writeln;
  write(a, '(Line: ', Line , ') - Hint: ', s, '.', #13);
  writeln;
end;


procedure Abort(s:string);
begin
   if dest   <> NIL then close(dest^);
   if incl   <> NIL then close(incl^);
   if source <> NIL then close(source^);
   LineError(LineCount, s);
{$IFNDEF DPMI}
  Release(HeapOrg);
{$ENDIF}
{$IFNDEF P32IDE}
   halt(100);
{$ENDIF}
end;

procedure Expected(s:string);
begin
   Abort(s + ' expected');
end;

procedure Error(s:string);
begin
{** mag - looks nices this way}
{$IFDEF P32IDE}
   Asm;Mov Ah, 0Fh;Int 10h;Mov Ah, 0;Int 10h;end;
{$ELSE}
   writeln;
{$ENDIF}
   writeln('þ Error: '+s);
{$IFNDEF DPMI}
  Release(HeapOrg);
{$ENDIF}
   Halt;
end;

{$IFDEF P32IDE}
var ShowLineNum_LastT: Longint;
procedure ShowLineNum;
var w1, w2, w3, w4: word; l: longint;
begin
{  GetTime(w1, w2, w3, w4);
  l := longint(w4) + longint(w3) * 100 + longint(w2) * 6000 + longint(w1) * 360000;
  if l > ShowLineNum_LastT + 100 then
  begin
}   CompileStatus_cLineSet(LineCount);
{   ShowLineNum_LastT := l;
  end;
}
end;
{$ENDIF}

{$IFDEF VER70}
{$F+}
Procedure RunTimeExitProc;
{F-}

var Message : string;

begin
  if ErrorAddr<>Nil then { If error occurs }
    begin
        case ExitCode of { Pick the appropriate message }
            2:Message:='File not found ';
            3:Message:='Path not found ';
            4:Message:='Too many open files ';
            5:Message:='File access denied ';
            6:Message:='Invalid file handle ';
            8:Message:='Insufficient memory ';
           12:Message:='Invalid file access code ';
           15:Message:='Invalid drive number ';
           16:Message:='Cannot remove current directory ';
           17:Message:='Cannot rename across drives ';
          100:Message:='Disk read error ';
          100:Message:='Disk write error ';
          102:Message:='File not assigned ';
          103:Message:='File not open ';
          104:Message:='File not open for input ';
          105:Message:='File not open for output ';
          106:Message:='Invalid numeric format ';
          150:Message:='Disk is write-protected ';
          151:Message:='Unknown unit ';
          152:Message:='Drive not ready ';
          153:Message:='Unknown command ';
          154:Message:='CRC error in data ';
          155:Message:='Bad drive request structure length ';
          156:Message:='Disk seek error ';
          157:Message:='Unknown media type ';
          158:Message:='Sector not found ';
          159:Message:='Printer out of paper ';
          160:Message:='Device write fault ';
          161:Message:='Device read fault ';
          162:Message:='Hardware failure ';
          200:Message:='Division by zero ';
          201:Message:='Range check error ';
          202:Message:='Stack overflow error ';
          203:Message:='Heap overflow error ';
          204:Message:='Invalid pointer operation ';
          205:Message:='Floating-point overflow ';
          206:Message:='Floating-point underflow ';
          207:Message:='Invalid floating-point operation ';
          208:Message:='Overlay manager not installed ';
          209:Message:='Overlay file read error ';
          210:Message:='Object not initialized ';
          211:Message:='Call to abstract method ';
          212:Message:='Stream register error ';
          213:Message:='Collection index out of range ';
          214:Message:='Collection overflow error ';
          216:Message:='!! GPF !! Contact author ';
        end;
        writeln;
        writeln('þ Runtime error: #',ExitCode,' ',Message, '(',linecount,')');
{$IFNDEF DPMI}
        Release(HeapOrg);
{$ENDIF}
        ErrorAddr:=nil;
        ExitCode:=255;   { End program with errorlevel 255}
    end;
  ExitProc:=OldExit; { Restore the original exit procedure }
end;
{$ENDIF}

procedure SetRuntimeErrorHandler;
begin
{$IFDEF VER70}
  OldExit:=ExitProc;          { Save the original exit procedure }
  ExitProc:=@RunTimeExitProc; { Insert the RunTime exit procedure }
{$ENDIF}
end;

end.

{                         P32 - 32bit Pascal Compiler                        }
{ -------------------------------------------------------------------------- }
{                       Johan Prins - jprins@knoware.nl                      }
{ ========================================================================== }
{                                                                            }
{ Strings unit                                                               }
{                                                    (c) Copyright 1998-1999 }
{                                                                            }
{ -------------------------------------------------------------------------- }
{              STRINGS UNIT for P32 - 32 bit Pascal compiler                 }
{         Copyright(C) 1998 Pasquale Morvillo pamorv@freenet.hut.fi          }
{ -------------------------------------------------------------------------- }

unit strings;

Interface

function StrLen(Str: pchar): longint;
function StrEnd(Str: PChar): PChar;
function StrMove(Dest,Source : Pchar;l : Longint) : pchar;
function StrCopy(Dest, Source: PChar): PChar;
function StrECopy(Dest, Source: PChar): PChar;
function StrLCopy(Dest, Source: PChar; MaxLen: Longint): PChar;
function StrPCopy(Dest: PChar; Source: String): PChar;
function StrCat(Dest, Source: PChar): PChar;
function strLcat(dest,source : pchar;l : Longint) : pchar;
function StrComp(str1, str2: PChar): Integer;
function StrIComp(Str1, Str2 : PChar): Integer;
function StrLComp(Str1, Str2: PChar; MaxLen: Longint): Integer;
function StrLIComp(Str1, Str2: PChar; MaxLen: Longint): Integer;
function StrScan(Str: PChar; Ch: Char): PChar;
function StrRScan(Str: PChar; Ch: Char): PChar;
function StrPos(Str1, Str2: PChar): PChar;
function StrUpper(Str: PChar): PChar;
function StrLower(Str: PChar): PChar;
function StrPas(Str: PChar): String;
function StrNew(Str: PChar): PChar;
procedure StrDispose(Str: PChar);

Implementation

function StrLen(Str : pchar) : Longint;
var
   count : pchar;
Begin
     count := Str;
     while Str^ <> #0 do Str:=Str+1;
     strlen := Str-count;
end;

Function StrEnd(Str: PChar): PChar;
begin
     while Str^ <> #0 do Str:=Str+1;
     StrEnd := Str;
end;

function StrMove(dest,source : pchar;l : Longint) : pchar;
begin
     move(source^,dest^,l);
     strmove:=dest;
end;

Function StrCopy(Dest, Source: PChar): PChar;
Begin
     StrCopy := Dest;
     while Source^ <> #0 do
     begin
          Dest^ := Source^;
          Dest:=Dest+1; Source:=Source+1;
     end;
     Dest^ := #0;
end;

Function StrECopy(Dest, Source: PChar): PChar;
begin
     while Source^ <> #0 do
     begin
          Dest^ := Source^;
          Dest:=Dest+1; Source:=Source+1;
     end;
     Dest^ := #0;
     StrECopy:=Dest;
end;

Function StrLCopy(Dest,Source: PChar; MaxLen: Longint): PChar;
Begin
    If Source^ = #0 then
    Begin
         Dest^:=Source^; Dest:=Dest+1;
    end
    else
    while (Source^ <> #0)  and (MaxLen>0) do
    Begin
          Dest^ := Source^;   dec(MaxLen);
          Dest:=Dest+1; Source:=Source+1;
    end;
    Dest^ := #0;
    StrLCopy := Dest;
end;

Function StrPCopy(Dest: PChar; Source: String):PChar;
var
    count : byte;
Begin
     if Source <> '' then
     for count:=1 to length(Source) do
     begin
          Dest^ := Source[count];
          Dest:=Dest+1;
     end;
     Dest^ := #0;
     StrPCopy:=Dest;
end;

function StrCat(Dest,Source: PChar): PChar;
var
   PEnd: PChar;
begin
     StrCat := Dest;
     Dest:=StrEnd(Dest);
     while Source^ <> #0 do
     begin
          Dest^ := Source^;
          Dest:=Dest+1; Source:=Source+1;
     end;
     PEnd^ := #0;
end;

function StrLCat(dest,source : pchar;l : Longint) : pchar;
var
   destend : pchar;
begin
    strlcat:=dest;
    destend:=strend(dest);
    l:=l-(destend-dest);
    strlcopy(destend,source,l);
end;

function StrComp(str1, str2 : PChar): Integer;
Begin
     While ord(str1^) = ord(str2^) do {str1^=str2^ doesn't work!!}
     Begin
          if (str2^ = #0) or (str1^ = #0) then break;
          str1:=str1+1; str2:=str2+1;
     end;
     StrComp := ord(str1^) - ord(str2^);
end;

function StrIComp(Str1, Str2 : PChar): Integer;
Begin
     While ord(upcase(str1^)) = ord(upcase(str2^)) do
     Begin
          if (str1^ = #0) or (str2^ = #0) then break;
          str1:=str1+1; str2:=str2+1;
     end;
     StrIComp := ord(upcase(str1^)) - ord(upcase(str2^));
end;

function StrLComp(Str1, Str2 : PChar; MaxLen: Longint): Integer;
begin
     if MaxLen = 0 then StrLComp := 0
     else
     Repeat
           if (str1^ = #0) or (str2^ = #0) then break;
           str1:=str1+1; str2:=str2+1; dec(MaxLen);
     Until (ord(str1^) <> ord(str2^)) or (MaxLen=0);
     StrLComp := ord(str1^) - ord(str2^);
end;

function StrLIComp(Str1, Str2 : PChar; MaxLen: Longint): Integer;
Begin
     if MaxLen = 0 then StrLIComp := 0
     else
     Repeat
           if (str1^ = #0) or (str2^ = #0) then break;
           str1:=str1+1; str2:=str2+1; dec(MaxLen);
     Until (ord(upcase(str1^)) <> ord(upcase(str2^))) or (MaxLen=0);
     StrLIComp := ord(upcase(str1^)) - ord(upcase(str2^));
end;

function StrScan(Str: PChar; Ch: Char): PChar;
Begin
     while Str^ <> #0 do
     begin
          if ord(Ch) = ord(Str^) then
          begin
               StrScan := Str;
               exit;
          end;
          Str:=Str+1;
     end;
     if ch=#0 then StrScan:=Str
     else StrScan := nil;
end;

function StrRScan(Str: PChar; Ch: Char): PChar;
Var
   count: Longint;
   index: Longint;
Begin
     count := Strlen(Str); Str:=Str+count;
     if ch = #0 then
     begin
          StrRScan := Str;
          exit;
     end;
     for index := count downto 1 do
     begin
          Str:=Str-1;
          if ord(Ch) = ord(Str^) then
          begin
               StrRScan := Str;
               exit;
          end;
     end;
     StrRScan := nil;
end;

function StrPos(Str1,Str2: PChar): PChar;
var
   count: Longint;
   oldindex: Longint;
   found: boolean;
   Str1Length: Longint;
   Str2Length: Longint;
   ll: Longint;
   AStr1, AStr2: pchar;
Begin
     Str1Length := StrLen(Str1);
     Str2Length := StrLen(Str2);
     found := true;
     oldindex := 0;

     if (Str2Length > Str1Length) or (Str2^ = #0) then
     begin
          StrPos := nil;
          exit;
     end;

     Repeat
           AStr1:=Str1+oldindex;
           for count:= oldindex to Str1Length-1 do
           begin
                if ord(Str2^) = ord(AStr1^) then
                begin
                     oldindex := count;
                     break;
                end;
                if count = Str1Length-1 then
                begin
                     StrPos := nil;
                     exit;
                end;
                AStr1:=Astr1+1;
           end;

           found := true;
           AStr2:=Str2;
           for ll := 0 to Str2Length-1 do
           begin
                if ord(AStr2^) <> ord(AStr1^) then
                begin
                     found := false;
                     break;
                end;
                AStr2:=AStr2+1;  AStr1:=AStr1+1;
           end;
           if found then
           begin
                StrPos := Str1+oldindex;
                exit;
           end
           else inc(oldindex);
     Until (Str1Length-oldindex) <= 0;
     StrPos := nil;
end;

function StrUpper(Str: PChar): PChar;
begin
     StrUpper:=Str;
     while Str^ <> #0 do
     begin
          if (Str^>='a') and (Str^<='z') then Str^:=char(ord(Str^)-32);
          Str:=Str+1;
     end;
end;

function StrLower(Str: PChar): PChar;
begin
     StrLower:=Str;
     while Str^ <> #0 do
     begin
          if (Str^>='A') and (Str^<='Z') then Str^:=char(ord(Str^)+32);
          Str:=Str+1;
     end;
end;

function strpas(Str: pchar): string;
var
   Tmpstr: string;
Begin
     TmpStr[0]:=char(strlen(Str));
     move(Str^,Tmpstr[1],ord(TmpStr[0]));
     strpas := Tmpstr;
end;

function StrNew(Str: PChar): PChar;
var
   L: longint;
   P: PChar;
begin
     StrNew := nil;
     if (Str <> nil) and (Str^ <> #0) then
     begin
          L := StrLen(Str) + 1;
          GetMem(P, L);
          if P <> nil then StrNew := StrMove(P, Str, L);
     end;
end;

procedure StrDispose(Str: PChar);
begin
     if Str <> nil then FreeMem(Str, StrLen(Str) + 1);
end;

begin
end.

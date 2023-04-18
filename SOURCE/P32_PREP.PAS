{                         P32 - 32bit Pascal Compiler                        }
{ -------------------------------------------------------------------------- }
{                       Johan Prins - jprins@knoware.nl                      }
{ ========================================================================== }
{ Preprocessor                                                               }
{                                                   (c) Copyright 1997-1999  }
{                                                                            }
{ -------------------------------------------------------------------------- }

unit P32_prep;

interface

uses P32_err;

type

    pstring     = ^string;
    pbool       = ^boolean;

    stringlist  = ^_str;

    _str        = record
                    name: pstring;
                    next: stringlist;
                  end;

type tOptions = record
                  NestedComments       : boolean;
                  CstyleComments       : boolean;
                  AdaStyleComments     : boolean;
                  OptimizeLevel        : integer;
                  OptimizeInlineCode   : boolean;
                  OptimizeCSE          : boolean;
                  CompileSystemUnit    : boolean;
                  ShuffleRegisters     : boolean;
                  AllowRegisterCalling : boolean;
                  AddLineNumbers       : boolean;
                  CreateBatch          : boolean;
                  ExecuteBatch         : boolean;
                  AlignData            : integer;
                  AlignStackFrame      : boolean;
                  AlignStrings         : boolean;
                  DirectAsm            : boolean;
                  Parentheses          : boolean;
                  OpenParameters       : boolean;
                  IoChecking           : boolean;
                  Build                : boolean;
                  Hints                : boolean;
                  DecimalNumbers       : boolean;
                  HeapSize             : longint;
                end;

var
   directive_names       : stringlist;
   SkippingFalseIf       : boolean;
   IfNestingLevel        : integer;
   TargetNestingLevel    : integer; { the nesting level at which ENDIF }
                                    { and ELSE must take some action }

   {global variables that control the compiler options}

const
   Options : tOptions = (NestedComments       : FALSE;
                         CstyleComments       : FALSE;
                         AdaStyleComments     : TRUE;
                         OptimizeLevel        : 1;
                         OptimizeInlineCode   : FALSE;
                         OptimizeCSE          : FALSE;
                         CompileSystemUnit    : FALSE;
                         ShuffleRegisters     : FALSE;
                         AllowRegisterCalling : TRUE;
                         AddLineNumbers       : FALSE;
                         CreateBatch          : FALSE;
                         ExecuteBatch         : FALSE;
                         AlignData            : 4;
                         AlignStackFrame      : FALSE;
                         AlignStrings         : FALSE;
                         DirectAsm            : FALSE;
                         Parentheses          : FALSE;
                         OpenParameters       : TRUE;
                         IoChecking           : TRUE;
                         Build                : FALSE;
                         Hints                : FALSE;
                         DecimalNumbers       : FALSE;
                         HeapSize             : 4 * 1024 * 1024 {4 Mb}
                        );

procedure InitPreProcessor;
procedure DoDirectives;
procedure AddString(p: stringlist; s: string);

procedure CreateStringList(var p: stringlist);
procedure DestroyStringList(var p: stringlist);
procedure NewStringListEntry(var p: stringlist);

function getmemstring(const s: string):pstring;
procedure freememstring(var p:pstring);

implementation

uses P32_scan;

procedure CreateStringList(var p: stringlist);
begin
   new(p);
   p^.next:=NIL;
   p^.name:=NIL;
end;

{ String list handling functions }

procedure NewStringListEntry(var p: stringlist);
begin
   new(p^.next); {create new one}
   p:=p^.next;   {assign to given entry}
   p^.name:=NIL;  {empty new entry}
   p^.next:=NIL;
end;

procedure DestroyStringList(var p: stringlist);
var start: stringlist;

begin
  start:=p;
  while start<>NIL do
    begin
      p:=start^.next;
      freememstring(start^.name);
      dispose(start);
      start:=p;
    end;
  p:=NIL;
end;

function getmemstring(const s: string):pstring;
var p:pstring;
begin
  if s='' then
    p:=NIL
  else
    begin
      GetMem(p, length(s)+1);
      p^:=s;
    end;
  getmemstring:=p;
end;

procedure freememstring(var p:pstring);

begin
  if p<>NIL then FreeMem(p, length(p^)+1);
  p:=NIL;
end;

procedure AddString(p: stringlist; s:string);

begin
  while p^.next<>NIL do p:=p^.next; {get latest entry}
  new(p^.next);  {create new one}
  p:=p^.next;
  p^.next:=NIL;  {only one entry added}
  p^.name:=getmemstring(s);    {add name}
end;

procedure DeleteString(p: stringlist; s:string);
var
  q: stringlist;

begin
  q := p;
  p:=p^.next;
  if p<>NIL then
    begin
      while (p^.next <> NIL) and (p^.name<>NIL) and (p^.name^<>s) do
      begin
        q := p;
        p := p^.next;
      end;
      if (p^.name<>NIL) and (p^.name^=s) then
      begin
        q^.next := p^.next;
        freememstring(p^.name);
        Dispose(p);
      end;
    end
end;

function FindString(p: stringlist; s:string):boolean;

begin
  FindString:=FALSE;
  p:=p^.next;
  if p<>NIL then
    begin
      while (p^.next <> NIL) and (p^.name<>NIL) and (p^.name^<>s) do
        p := p^.next;
      if (p^.name<>NIL) and (p^.name^=s) then FindString:=TRUE;
    end
end;

procedure EatCode;

label restart;

begin
restart:
  GetChar;
  case Look of
  '{'  :    begin
              GetChar;
              if look='$' then
                DoDirectives
              else goto restart;
            end;
  else
  goto restart;
  end;
end;

procedure DoDirectives;

label
  MoreDirectives;

type
     directive =
      ( _none, _ifdef, _ifndef, _ifopt, _else, _endif, _define, _undef,
        _ad, _c, _cc, _i, _p, _m, _o, _oi, _ac);

const
     directive_name: array[directive] of string[7] =
      ('','IFDEF','IFNDEF','IFOPT','ELSE','ENDIF','DEFINE', 'UNDEF',
        'AD', 'C', 'CC', 'I', 'P', 'M', 'O', 'OI', 'AC');

var
   b:boolean;
   P: PBool;
   current_directive: directive;
   code : integer;
   sFilename:string;

   function BoolDirective(d: Directive): PBool;
   begin
     case d of
     _ad: BoolDirective := @Options.DirectAsm;
     _p : BoolDirective := @Options.OpenParameters;
     _c : BoolDirective := @Options.NestedComments;
     _cc: BoolDirective := @Options.CstyleComments;
     _ac: BoolDirective := @Options.AdaStyleComments;
     _i : BoolDirective := @Options.IoChecking;
     else BoolDirective := nil;
     end;
   end;


   function LookupDirective: Directive;

   var
     i: directive;

   begin
     LookupDirective :=_none;
     for i := low(directive) to high(directive) do
       if upcase_string = directive_name[i] then
         LookupDirective := i;
   end;


begin
  GetChar; { eat the '$' }
MoreDirectives:
  current_string:='';
  {get directive}
  GetIdentifier;

  current_directive := LookupDirective;

  case current_directive of
  _ifdef, _ifndef, _ifopt :
           begin
             GetIdentifier;
             case current_directive of
               _ifdef:
                  b := FindString(directive_names, upcase_string);
               _ifndef:
                  b := not FindString(directive_names, upcase_string);
               _ifopt:
                  begin
                    P := BoolDirective(LookupDirective);
                    If (P <> nil) and ((look = '+') or (look = '-')) then
                    begin
                      b := P^ xor (look = '-');
                    end else begin
                      LineError(LineCount, 'Invalid directive');
                    end;
                  end;
             end;
             Inc(IfNestingLevel);
             if not SkippingFalseIf and not b then
             begin
               TargetNestingLevel := IfNestingLevel;
               SkippingFalseIf := True;
             end;
             exit;
           end;
  _endif : begin
             if IfNestingLevel = 0 then
               LineError(LineCount, 'Error with $ENDIF')
             else begin
                    if SkippingFalseIf and (IfNestingLevel = TargetNestingLevel) then
                      SkippingFalseIf := False;
                    dec(IfNestingLevel);
                   end;
             exit;
           end;
  _else  : begin
             if IfNestingLevel = 0 then
               LineError(LineCount, 'Error with $ELSE')
             else if (not SkippingFalseIf) or (IfNestingLevel = TargetNestingLevel) then
             begin
               SkippingFalseIf := not SkippingFalseIf;
               If SkippingFalseIf then
                 TargetNestingLevel := IfNestingLevel;
             end;
             exit;
           end;
  end;

  if SkippingFalseIf then
    exit;

  P := BoolDirective(current_directive);

  If (P <> nil) and ((look = '+') or (look = '-')) then
  begin
    P^ := look = '+';
    GetChar;
  end else begin
    case current_directive of
    _define: begin
               {get the symbol}
               GetIdentifier;
               AddString(directive_names, upcase_string);
               exit;
             end;
    _undef : begin
               GetIdentifier;
               DeleteString(directive_names, upcase_string);
               exit;
             end;
    _o:     begin
              case upcase(look) of
              '0', '-' : Options.OptimizeLevel:=0;
              '1', '+' : Options.OptimizeLevel:=1;
              '2'      : Options.OptimizeLevel:=2;
              '3'      : Options.OptimizeLevel:=3;
              else LineError(LineCount, 'Compiler directive requires ''+/-'' or a numeric value');
              end
            end;
    _oi:    Options.OptimizeInlineCode:=TRUE;
    _i:     begin
              GetIdentifier;
              sFilename := current_string;
              if look = '.' then
              begin
                { get the dot }
                GetChar;
                sFilename := sFilename + '.';
                { get the extension }
                GetIdentifier;
                sFilename := concat (sFilename, current_string);
              end
              else
                sFilename := concat (sFilename, '.pas');
            end;
    _m:     begin
              GetChar;
              current_string:='';
              while (look<>' ') and (look<>'}') do
              begin
                current_string:=current_string+upcase(look);
                GetChar;
              end;
              val(current_string, Options.HeapSize, code);
              if code<>0 then LineError(LineCount, 'Compiler directive requires integer constant');
            end;
    else    {;}
            LineError(LineCount, 'Unsupported directive'); { debug }
    end;
  end;

  if look = ',' then
  begin
    GetChar;
    goto MoreDirectives;
  end;
end;

procedure InitPreProcessor;
begin
  IfNestingLevel := 0;
  SkippingFalseIf := False;
  CreateStringList(directive_names);
  AddString(directive_names,'P32');
  AddString(directive_names,'P32V050');
end;

end.

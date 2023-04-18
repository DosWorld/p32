{ -------------------------------------------------------------------------- }
{                                                                            }
{                         P32 - 32 bit Pascal Compiler                       }
{                                                                            }
{ -------------------------------------------------------------------------- }
{                       Johan Prins - jprins@knoware.nl                      }
{ ========================================================================== }
{ Main-program and parser                                                    }
{                                                   (c) Copyright 1996-1999  }
{                                                                            }
{ http://surf.to/p32                                                         }
{                                                                            }
{ -------------------------------------------------------------------------- }

{$IFDEF DPMI}
{P32 requires a _big_ stack...}
{$M 65355}
{$ENDIF}


{ $DEFINE debug  -  for debugging purposes}

{$IFDEF debug}
{$R+} {range checking on}
{$S+} {stack checking on}
{$Q+} {overflow checking on}
{$ENDIF}

{$IFDEF VER70}
{P32 requires a _big_ stack...}
{$M 65355, 0, 653560}
{$ENDIF}

{$F+}

{ $DEFINE P32IDE}

{$IFDEF P32IDE} {turn p32.pas into a unit}


unit P32;

interface

{$ELSE}

program P32;

{$ENDIF}

uses
     Dos,
     P32_cpuf,
     P32_err,    {error reporting}
     P32_prep,   {preprocessor}
     P32_scan,   {scanner, lexical analyser}
     P32_opt,    {high-level optimizer}
     P32_code,   {code generation and low-level optimizer}
     P32_symb,   {symboltable routines}
     P32_tree,   {parsetree routines}
     P32_asm,    {routines for the assembler}
     P32_asml,
     P32_unit,   {unit loading and saving routines}
     P32_cfg;    {configuration routines}

const
     TAB = ^I;
var
   makesymbolspublic: boolean;
   current_method   : pSymbolRecord;

{ forward definitions}

{$IFDEF P32IDE}
procedure init;
function Main:pTree;
function Statement:pTree;
function Expression:pTree;
function GetTypeDef(const name:string):pTypeRecord;
procedure Compile(var s:string);
procedure ResetCompiler;

implementation

{$ELSE}

function Main:pTree; forward;
function Statement:pTree; forward;
function Expression:pTree; forward;
function GetTypeDef(const name:string):pTypeRecord; forward;
procedure Compile(var s:string); forward;
{$ENDIF}

function GetStringList: stringlist;
{ Reads comma-separated strings and creates a linked list that contains
  strings with identifiers, for use in variable and type declarations. }

var
   start, str : stringlist;

begin
   CreateStringList(str);
   start:=str; {first entry}

   str^.next := NIL;     {reset pointer to next record}
   str^.name := getmemstring(GetName); {store name of identifier}
   while current_token = _comma do
     begin
       Match(_comma);
       NewStringListEntry(str);
       str^.name := getmemstring(GetName); {store name of identifier}
     end;
   GetStringList:=start;   {return pointer to first entry}
end;

function GetLabelList:stringlist;   {LB, new function got goto and labels}
{ Based on GetStringList, reads comma-separated labels, be they strings or
  integer constants, and creates a linked list that contains
  strings with identifiers, for use in label declarations. }

var
   start, str : stringlist;

begin
   CreateStringList(str);

   start:=str; {first entry}
   repeat
     str^.next := NIL;     {reset pointer to next record}
     str^.name := getmemstring(GetLabel); {store name of identifier}
     if (Current_Token = _comma) then
       begin
         Match(_comma);
         NewStringListEntry(str); {create new record}
       end;
   until current_token=_separator;
   GetLabelList:=start;   {return pointer to first entry}
end;

function DoParametersOnCall:pTree;
{ Processes the parameters of a procedure/function when it's called.
  It also takes care of expression like 'WriteLn(a:3);'.            }

var p1, p2     : pTree;

begin
  if current_token=_rparen then {no parameters left}
    begin
      DoParametersOnCall:=NIL;
      exit;
    end;
  p2:=nil;

  repeat
    p1:=Expression;          {get expression}
    p2:=GenParamNode(p1,p2);
    p2^.colon:=false;
    if current_token=_colon then {do we have a ':' ? }
      begin
        Match(_colon);
        p1:=expression;      {get expression after ':'}
        p2:=GenParamNode(p1,p2);
        p2^.colon:=true;
        if current_token=_colon then
          begin
            Match(_colon);
            p1:=expression;
            p2:=GenParamNode(p1,p2);
            p2^.colon:=true;
          end;
      end;
    if current_token=_comma then Match(_comma)
                            else break;
  until false;
  DoParametersOnCall:=p2; {return tree containing parameters}
end;

function DoParametersNewDispose:pTree;

var p1, p2     : pTree;
    ObjectList : pSymbolList;

begin
  p2:=NIL;
  p1:=Expression;
  p2:=GenParamNode(p1, p2);
  ObjectList:=p1^.return^.PointerTo^.typedef^.RecordTable;
  AddList(ObjectList);
  if current_token<>_rparen then
    begin
      Match(_comma);
      p1:=Expression;
      p2:=GenParamNode(p1, p2);
      RemoveList(ObjectList);
    end;
  DoParametersNewDispose:=p2;
end;

function factor:pTree;

var p1, p2           : pTree;
    typ              : pTypeRecord;
    sym_method,
    sym_field, sym   : pSymbolRecord;
    fieldname, name  : string;
    setconst         : pset;  {defined in P32_tree}
    i, s1, s2        : byte;

    procedure AddElement(var s: pset; n: byte);
    var i: integer;
    begin
      if (n < 0) or (n > 255) then
        LineError(linecount, 'Set base type out of range');
      i := n div 8;
      s^[i]:=s^[i] or (1 shl (n mod 8));
    end;

    procedure DoQualifiers;
    { This nested procedure analyses a qualifier following an identifier,
      like: '[',']', '^', '.' (array, pointer, record)}
    begin
      case current_token of
      _ptr        : begin { ^ }
                      Match(_ptr);
                      p1:=GenLeftNode(__ptr, p1);
                      if typ^.PointerTo<>NIL then typ:=typ^.PointerTo^.typedef
                                             else typ:=NIL;
                    end;
      _lbracket   : begin { [ }
                      Match(_lbracket);
                      repeat
                        case typ^.typedef of
                        _StringDef  : begin
                                        p2:=expression;
                                        OptimizeTree(p2);
                                        p1:=GenExpNode(__index, p1, p2);
                                        typ^.definition:=NewType;
                                        typ^.range:=typ^.definition;
                                        typ:=typ^.definition;
                                        typ^.typedef:=_SubRangeDef;
                                        typ^.subrangetyp:={u8bit}uchar;
                                        typ^.lowerlimit:=0;
                                        typ^.upperlimit:=255;
                                      end;
                        _ArrayDef   : begin
                                        p2:=expression;
                                        OptimizeTree(p2);
                                        p1:=GenExpNode(__index, p1, p2);
                                        typ:=typ^.definition;
                                      end;
                        _PointerDef : begin
                                        p2:=expression;
                                        p1:=GenExpNode(__index, p1, p2);
                                        typ:=typ^.PointerTo^.typedef;
                                      end;
                        else          LineError(LineCount, 'Invalid qualifier');
                        end;
                        if current_token=_comma then Match(_comma)
                                                else break;
                      until false;
                      Match(_rbracket); { ] }
                    end;
      _period     : begin { . }
                      Match(_period);
                      case typ^.typedef of
                      _RecordDef : begin
                                     fieldname:=GetName;
                                     sym:=GetSymbol({field}name); {get symbol entry}
                                     if sym^.typedef=nil then Error('Record doesn''t have fields')
                                     else begin
                                            sym_field:=GetSymbolFromList(typ^.RecordTable, fieldname);{Table of vars in record}
                                            if sym_field=NIL then LineError(LineCount,'Field expected'); {no entries}
                                            p1:=GenFieldNode(sym, sym_field, p1);
                                          end;
                                     typ:=sym_field^.typedef;
                                   end;
                      _Objectdef : begin
                                     fieldname:=GetName;
                                     sym:=GetSymbol(name); {get symbol entry}
                                     if sym^.typedef=nil then
                                       Error('Empty object')
                                     else
                                       begin
                                         sym_field:=GetSymbolFromList(typ^.RecordTable, fieldname);
                                         if sym_field=NIL then LineError(LineCount,'Field expected');
                                         case sym_field^.symbol of
                                         _variable: begin
                                                      p1:=GenFieldNode(sym, sym_field, p1);
                                                      typ:=sym_field^.typedef;
                                                    end;
                                         _func,
                                         _proc    : begin
                                                      p1:=GenMethodCallNode(sym, sym_field, p1);
                                                      if (current_token=_lparen) or
                                                         (Options.Parentheses=TRUE) then {if there are parameters, parse them}
                                                        begin
                                                          Match(_lparen);
                                                          p1^.left:=DoParametersOnCall;
                                                          Match(_rparen);
                                                        end
                                                      else p1^.left:=nil;
                                                    end;
                                         end;
                                       end;
                                   end;
                      end;
                    end;

      else
        if (p1<>NIL) and (p1^.op=__var) and (p1^.sym^.typedef^.typedef=_ProcedureDef) then
          begin
            {replace __var with a __call}
            p1^.op:=__call;
            if (current_token=_lparen) or
               (Options.Parentheses=TRUE) then {if there are parameters, parse them}
              begin
                Match(_lparen);
                p1^.left:=DoParametersOnCall;
                Match(_rparen);
              end
            else
              p1^.left:=nil;
          end
        else
          exit;
      end;
      DoQualifiers;
    end; { end of procedure DoQualifiers}

begin
  case current_token of
   _name             : begin {identifier}
                        name := GetName;
                        sym := GetSymbol(name);
                        {if (sym=NIL) and (ProcName<>'') then
                         { sym := GetPointer(GlobalTable, ProcName+name); {nested procedure}
                        if (sym<>NIL) and (sym^.symbol=_unit) then
                          begin
                            Match(_period);
                            name:=GetName;
                            sym:=GetSymbolFromList(sym^.symlist, name);
                          end;
                        if sym=NIL then LineError(LineCount, 'Unknown identifier ('+name+')');
                        typ:=sym^.typedef;
                        case sym^.symbol of
                        _variable  : begin {it's a variable}
                                       p1:=GenVarNode(sym);
                                     end;
                        _type      : begin  {typeconversion}
                                       if current_token=_lparen then
                                         begin
                                           Match(_lparen);
                                           p1:=Expression;
                                           Match(_rparen);
                                           p1:=GenTypeConvNode(p1, typ, true);
                                         end
                                       else
                                         p1:=GenTypeConvNode(NIL, typ, true);
                                     end;
                        _constant   : begin {constant, declared with 'CONST'}
                                        case sym^.c of
                                        _IntegerConst,
                                        _OrdinalConst : p1:=GenOrdConstNode(sym^.n, sym^.consttyp);   { 4 }
                                        _CharConst    : p1:=GenCharConstNode(sym^.x);      { 'a' }
                                        _StringConst  : p1:=GenStrConstNode(sym^.s);      { 'test' }
                                        _RealConst    : p1:=GenRealConstNode(sym^.d);     { 3.0E10 }
                                        end;
                                        p1^.sym:=sym;
                                      end;
                        _proc,
                        _func       : begin {procedure/function call...}
                                        p1:=GenCallNode(sym);
                                        if (current_token=_lparen) or
                                           (Options.Parentheses=TRUE) then {if there are parameters, parse them}
                                          begin
                                            Match(_lparen);
                                            if (sym^.internal=in_new) or (sym^.internal=in_dispose) then
                                              p1^.left:=DoParametersNewDispose
                                            else
                                              p1^.left:=DoParametersOnCall;
                                            Match(_rparen);
                                          end
                                        else p1^.left:=nil;
                                      end;
                        else          begin
                                        LineError(LineCount, 'Error in expression');
                                      end;
                        end;
                        DoQualifiers; {'[',']','.','^'}
                      end;
  _inherited:         begin
                        Match(_inherited);
                        name := GetName;
                        sym := GetSymbol(name);
                        if (current_method<>NIL) then
                          begin
                            typ:=current_method^.typedef;
                            if typ^.childof<>NIL then
                              begin
                                typ:=typ^.childof^.typedef;
                                while (typ<>NIL) do
                                  begin
                                    sym_method:=GetSymbolFromList(typ^.RecordTable, name);
                                    if sym_method<>NIL then
                                      begin
                                        p1:=GenMethodCallNode(sym, sym_method, NIL);
                                        if (current_token=_lparen) or
                                           (Options.Parentheses=TRUE) then {if there are parameters, parse them}
                                          begin
                                            Match(_lparen);
                                            p1^.left:=DoParametersOnCall;
                                            Match(_rparen);
                                          end
                                        else p1^.left:=nil;
                                        break;
                                      end;
                                  end;
                              end;
                          end;
                    end;
  _integer_constant : p1:=GenOrdConstNode(GetNumber, NIL);
  _real_constant    : p1:=GenRealConstNode(GetFloat);
  _string           : begin
                        Match(_lbracket);
                        p1:=Expression;
                        OptimizeTree(p1);
                        Match(_rbracket);
                      end;
  _string_constant  : begin
                        p1:=GenStrConstNode(current_string);
                        Match(_string_constant);
                      end;
  _char_constant  : begin
                      p1:=GenCharConstnode(current_string[1]);
                      Match(_char_constant);
                    end;
  _at             : begin { @ }
                      Match(_at);
                      p1:=factor;
                      p1:=GenLeftNode(__address,p1);
                    end;
  _lparen         : begin { ( }
                      Match(_lparen);
                      p1:=Expression;
                      Match(_rparen);
                    end;
  _lbracket       : begin { [ }
                      Match(_lbracket);
                      new(setconst);
                      fillchar(setconst^, sizeof(setconst^), 0);
                      if current_token <> _rbracket then
                        repeat
                          p2:=NIL;
                          p1:=Expression;
                          OptimizeTree(p1);
                          typ:=p1^.return;
                          case p1^.op of
                          __charconst : begin
                                          AddElement(setconst, ord(p1^.c));
                                          DestroyTree(p1);
                                        end;
                          __ordconst  : begin
                                          AddElement(setconst, p1^.n);
                                          DestroyTree(p1);
                                        end;
                          __subrange  : begin
                                          if p1^.left^.op  = __charconst then s1:=ord(p1^.left^.c)
                                                                         else s1:=p1^.left^.n;
                                          if p1^.right^.op = __charconst then s1:=ord(p1^.left^.c)
                                                                         else s1:=p1^.left^.n;
                                          for i:=s1 to s2 do AddElement(setconst, i);
                                          DestroyTree(p1);
                                         end;
                          else           begin
                                         end;
                          end;
                          if current_token=_comma then Match(_comma)
                                                  else break;
                        until false;
                        Match(_rbracket);
                      p1:=GenLeftNode(__setconst, p2);
                      p1^.cset:=setconst;
                      new(p1^.return);
                      p1^.return^.typedef:=_SetDef;
                      p1^.return^.setof:=typ;
                    end;
  _plus           : begin { + }
                      Match(_plus);
                      p1:=factor;
                    end;
  _minus          : begin { - }
                      Match(_minus);
                      p1:=factor;
                      p1:=GenLeftNode(__minus, p1);
                    end;
  _not            : begin { not }
                      Match(_not);
                      p1:=factor;
                      p1:=GenLeftNode(__not, p1);
                    end;
  _nil            : begin { nil }
                      Match(_nil);
                      p1:=GenNilNode;
                    end;
  else
                    LineError(LineCount, 'Error in expression');
  end;
  factor:=p1;
end;

function term:pTree;

var p1, p2 : pTree;

begin
  p1:=factor;
  repeat
    case current_token of
    _mul        : begin { * }
                    Match(_mul);
                    p2:=factor;
                    p1:=GenExpNode(__mul,p1,p2);
                  end;
    _slash      : begin { / }
                    Match(_slash);
                    p2:=factor;
                    p1:=GenExpNode(__slash,p1,p2);
                  end;
    _div        : begin { div }
                    Match(_div);
                    p2:=factor;
                    p1:=GenExpNode(__div,p1,p2);
                  end;
    _mod        : begin { mod }
                    Match(_mod);
                    p2:=factor;
                    p1:=GenExpNode(__mod,p1,p2);
                  end;
    _and        : begin { and }
                    Match(_and);
                    p2:=factor;
                    p1:=GenExpNode(__and,p1,p2);
                  end;
    _shl        : begin { shl }
                    Match(_shl);
                    p2:=factor;
                    p1:=GenExpNode(__shl,p1,p2);
                  end;
    _shr        : begin { shr }
                    Match(_shr);
                    p2:=factor;
                    p1:=GenExpNode(__shr,p1,p2);
                  end;
    else          break;
    end;
  until false;
  term:=p1;
end;

function simple_expression:pTree;

var p1,p2: pTree;

begin
  p1:=term;
  repeat
    case current_token of
    _plus    : begin { + }
                 Match(_plus);
                 p2:=term;
                 p1:=GenExpNode(__add,p1,p2);
               end;
    _minus   : begin { - }
                 Match(_minus);
                 p2:=term;
                 p1:=GenExpNode(__sub,p1,p2);
               end;
    _or      : begin { or }
                 Match(_or);
                 p2:=term;
                 p1:=GenExpNode(__or,p1,p2);
               end;
    _xor     : begin { xor }
                 Match(_xor);
                 p2:=term;
                 p1:=GenExpNode(__xor,p1,p2);
               end;
    else       break;
    end;
  until false;
  simple_expression:=p1;
end;

function boolean_expression:pTree;

var p1, p2 : pTree;

begin
  p1:=simple_expression;
  repeat
    case current_token of
    _less        : begin { < }
                     Match(_less);
                     p2:=simple_expression;
                     p1:=GenExpNode(__less,p1,p2);
                   end;
    _less_eq     : begin { <= }
                     Match(_less_eq);
                     p2:=simple_expression;
                     p1:=GenExpNode(__less_eq,p1,p2);
                   end;
    _greater     : begin { > }
                     Match(_greater);
                     p2:=simple_expression;
                     p1:=GenExpNode(__greater,p1,p2);
                   end;
    _greater_eq  : begin { >= }
                     Match(_greater_eq);
                     p2:=simple_expression;
                     p1:=GenExpNode(__greater_eq,p1,p2);
                   end;
    _equal       : begin { = }
                     Match(_equal);
                     p2:=simple_expression;
                     p1:=GenExpNode(__equal,p1,p2);
                   end;
    _not_eq      : begin { <> }
                     Match(_not_eq);
                     p2:=simple_expression;
                     p1:=GenExpNode(__not_eq,p1,p2);
                   end;
    _in          : begin { IN }
                     Match(_in);
                     p2:=simple_expression;
                     p1:=GenExpNode(__in,p1,p2);
                   end;
    else           break;
    end;
  until false;
  boolean_expression:=p1;
end;

function Expression:pTree;

var
    p1, p2 : pTree;

begin
  p1:=boolean_expression;
  OptimizeTree(p1);
  case current_token of
  _period2     : begin { .. }
                  Match(_period2);
                  p2:=boolean_expression;
                  OptimizeTree(p2);
                  if ((p1^.op=__ordconst) and (p2^.op=__ordconst)) or
                     ((p1^.op=__charconst) and (p2^.op=__charconst)) then
                    p1:=GenExpNode(__subrange,p1,p2)
                  else
                    p1:=GenExpNode(__float,p1,p2);
                end;
  _assign     : begin { := }
                  Match(_assign);
                  p2:=expression;
                  p1:=GenExpNode(__assign, p1, p2);
                end;
  end;
  Expression:=p1;
end;

function For_Statement:pTree;

var fromvalue, tovalue, block: pTree;
    down_to                  : boolean;
    s, sym                   : pSymbolRecord;
    typ                      : pTypeRecord;

begin
   Match(_for);
   fromvalue:=Expression;
   if fromvalue^.op<>__assign then Expected('assignment');
   if current_token=_downto then
     begin
       Match(_downto);
       down_to:=true;
     end
   else
     begin
       Match(_to);
       down_to:=false;
     end;
   tovalue:=simple_expression;
   OptimizeTree(tovalue);
   Match(_do);
   if current_token<>_separator then block:=statement
   else block:=NIL;
   For_Statement:=GenForNode(fromvalue,tovalue,block,down_to);
end;

function While_Statement:pTree;

var block, eval: pTree;

begin
   Match(_while);
   eval:=Expression;
   Match(_do);
   if current_token<>_separator then block:=statement
   else block:=NIL;
   While_Statement:=GenWhileNode(eval,block);
end;

function Repeat_Statement: pTree;

var p1, p2, block, eval: pTree;

begin
   p1:=nil;
   Match (_repeat);
   while current_token <> _until do
   begin
     if p1=NIL then
       begin
         p2:=GenExpNode(__statement, NIL, statement);
         p1:=p2;
       end
     else
       begin
         p2^.left:=GenExpNode(__statement, NIL, statement);
         p2:=p2^.left;
       end;
     if current_token = _until then break;
     if current_token = _separator then Match(_separator)
   end;
   block:=GenLeftNode(__block, p1);
   Match (_Until);
   eval:=Expression;
   Repeat_Statement:=GenRepeatNode(eval, block);
end;

function If_Statement: pTree;

var eval, if_true, if_false: pTree;

begin
   Match(_if);
   eval:=Expression;
   Match(_then);
   if current_token=_else then if_true:=NIL
   else if_true:=statement;
   if current_token=_else then
     begin
       Match(_else);
       if_false:=statement;
     end
   else if_false:=NIL;
   if_statement:=GenIfNode(eval, if_true, if_false);
end;

function Break_Statement:pTree;

begin
   Match(_break);
   Break_Statement:=GenBreakNode;
end;


function Continue_Statement:pTree;

begin
   Match(_continue);
   Continue_Statement:=GenContinueNode;
end;


function Exit_Statement:pTree;

begin
   Match(_exit);
   Exit_Statement:=GenExitNode;
end;

function Goto_Statement:pTree;

var sym : pSymbolRecord;

begin
  Match(_goto);
  If not MaybeLabel(Current_Token) then
    LineError(LineCount,'label identifier expected')
  else
    begin {we have a label, check it is in symboltable}
      if ProcName<>'' then
        sym := GetSymbol(ProcName+'_'+upcase_string)
      else
        sym := GetSymbol('_'+upcase_string);
      if sym=NIL then
        LineError(LineCount,'unknown label')
      else
        goto_statement:=GenGotoNode(sym);
      Match(current_token);
    end;
end;

function Case_Statement: pTree;

var
   typ : pTypeRecord; {type of case expression}
   p1,case_expr, case_eval, case_block, case_else: pTree;

begin
  Match(_case);
  case_expr:=expression;
  OptimizeTree(case_expr);
  Match(_of);
  case_block:=NIL;
  repeat
    repeat
      case_eval:=expression;
      OptimizeTree(case_eval);
      if current_token=_comma then Match(_comma)
                              else break;
      case_block:=GenCaseBlockNode(case_block, case_eval, NIL);
    until false;
    Match(_colon);
    case_block:=GenCaseBlockNode(case_block, case_eval, statement);
    if (current_token<>_else) or (current_token<>_end) then Match(_separator);
  until (current_token=_else) or (current_token=_end);

  if (current_token=_else) then
    begin
      if current_token=_else then Match(_else);
      case_else:=statement;
      if current_token=_separator then Match(_separator);
    end
  else
    case_else:=nil;
  Match(_end);
  Case_Statement:=GenCaseNode(case_expr, case_block, case_else);
end;

function With_Statement: pTree;

var
   block, p  : pTree;
   WithTable : pSymbolList;
   save1, save2,
   tmp, sym  : pSymbolRecord;
   i,j       : integer;

begin
  Match(_with);
  p:=Expression;
  OptimizeTree(p);
  if p^.return^.typedef <> _RecordDef then
    LineError(LineCount, 'Error in WITH expression')
  else
    WithTable:=p^.return^.RecordTable;

  AddList(WithTable);

  {repeat this for all expressions, separated by comma's}
  Match(_do);
  block:=NIL;
  if current_token <> _separator then
    block:=statement;

  RemoveList(WithTable);
  With_Statement:=GenWithNode(p, block);
end;

function AsmStatement:pTree;

var
    p: pTree;
    s:string;
    str, start    : stringlist;
    old: vartype;
    matchtoken: boolean;
    i, code:integer;
    hexnum:longint;
    asmtype: asmop;

    asmlistold: tasmlist;

begin
  Match(_asm);
  if current_token<>_end then
    while (current_token <> _end) do
      begin
        if Options.DirectAsm=TRUE then
          begin
            s:=current_string;
            repeat
              s:=s+look;
              GetChar;
            until look=#13;
            GetChar;
            if look=#10 then GetChar;
            GetToken;
          end
        else
          begin
            CreateAsmList;
            ReadAsmBlock;
          end;
      end;
  Match(_end);
  AsmStatement:=GenAsmNode(AsmList);
end;

function Block_Statement:pTree;

var p1,p2:pTree;

begin
  p1:=nil;
  if (current_token <> _begin) {and (bIncludeFile)} then
  begin
    Block_Statement := nil;
    exit;
  end
  else
    GetToken;
  while (current_token <> _end) do
    begin
      if p1=NIL then
        begin
          p2:=GenExpNode(__statement, NIL, statement);
          p1:=p2;
        end
      else
        begin
          p2^.left:=GenExpNode(__statement, NIL, statement);
          p2:=p2^.left;
        end;
      if current_token = _end then break;
      if current_token = _separator then Match(_separator)
   end;
   Match (_End);
   p1:=GenLeftNode(__block, p1);
   Block_Statement:=p1;
end;

procedure DoUnit;

var oldname, unitpath1, unitpath2, unitname: string;
    p,p1: pointer;
    sym: pSymbolRecord;
    lines:longint;
    s, u : text;

begin
  Match(_uses);
  repeat
    unitname:=upcase_string;
    Match(_name);
    sym:=GetSymbol('_'+unitname);
    if sym=NIL then
      begin
        unitpath1:=FSearch(unitname+'.P32','.\;'+GetEnv('P32')+';'+GetEnv('P32')+'\RTL\'+';'+GetEnv('PATH'));
        unitpath2:=FSearch(unitname+'.PAS','.\;'+GetEnv('P32')+';'+GetEnv('P32')+'\RTL\'+';'+GetEnv('PATH'));
        oldname:=__filename;
        __filename:=unitpath2;
        if unitpath1<>'' then
          begin
            assign(u, unitpath1);
            {$I-} reset(u); {$I+}
          end;
        if unitpath2<>'' then
          begin
            assign(s, unitpath2);
            {$I-} reset(s); {$I+}
          end;
        if (unitpath1 = '') and (unitpath2= '') then Error(unitname +'.P32 not found');
        if (Recompile(s, u)=FALSE) and (Options.Build=FALSE) and (unitpath1 <> '') then
          begin
            if unitpath2<>'' then close(s);
            if unitpath1<>'' then close(u);
            LoadUnit(unitpath1, unitname);
          end
        else
          begin
            if unitpath2<>'' then close(s);
            if unitpath1<>'' then close(u);
            compile(unitpath2);
            sym:=GetSymbol('_'+unitname);
            if sym<>NIL then sym^.loaded:=FALSE;
          end;
        __filename:=oldname;
      end;
    sym:=GetSymbol('_'+unitname);
    if sym<>NIL then sym^.overloadedname:=unitpath2;
    if current_token=_comma then Match(_comma)
                            else break;
  until false;
  Match(_separator);
end;

function GetStringType: pTypeRecord;

var p: pTree;
    typ : pTypeRecord;
    n: longint;

begin
  Match(_string);
  n:=255;
  if current_token = _lbracket then
  begin
    Match(_lbracket);
    p:=Expression;
    OptimizeTree(p);
    if (p^.op<>__OrdConst)    then Expected('ordinal constant');
    if (p^.n<1) or (p^.n>255) then LineError(LineCount, 'string too long');
    n:=p^.n;
    DestroyTree(p);
    Match(_rbracket);
  end;
  typ:=NewType;{create entry for string}
  typ^.TypeDef:= _StringDef;
  typ^.length := n;
  GetStringType:=typ;
end;

procedure DoRecordField(var rectyp:pTypeRecord; var recordoffset:longint; isobject: boolean);

var
   start, str   : stringlist;
   recoffset,
   variantstart,
   variantsize  : longint;
   typ          : pTypeRecord;
   sym          : pSymbolRecord;
   typename     : string;
   p1           : pTree;

begin
  while (current_token=_name) and
        not (isobject and ((upcase_string=_public) or (upcase_string=_private))) do
    begin
      str:=GetStringList;
      start:=str;
      Match(_colon);
      typ:=GetTypeDef('');
      repeat
        sym:=NewSymbol;
        sym^.name:=Str^.name^;
        sym^.symbol:=_variable;
        sym^.typedef:=typ;
        sym^.offset:=recordoffset;
        sym^.vartype:=vt;
        sym^.typedconst:=FALSE;
        sym^.attr:=s_none;
        AddSymbol(rectyp^.recordtable, sym);
        inc(recordoffset, GetSize(sym^.typedef));
        str:=str^.next;
      until str=NIL;
      DestroyStringList(start);
      if current_token=_separator then Match(_separator)
                                  else break;
  end;
  rectyp^.recordsize:=recordoffset;
  if (current_token=_case) and not isobject then {variant record}
    begin
      Match(_case);
      variantsize:=0;
      typename:='_'+upcase_string;
      sym:=GetSymbol(typename);
      if (sym<>NIL) then
        begin
          if (sym^.symbol<>_type) and
             (sym^.typedef^.typedef<>_EnumeratedDef) and
             (sym^.typedef^.typedef<>_SubRangeDef) then
            LineError(LineCount,'Ordinal type expected');
          Match(_name);
        end
      else
        begin
          if current_token<>_name then LineError(LineCount,'field identifier expected');
          sym:=NewSymbol;
          sym^.name:=GetName;
          Match(_colon);
          sym^.symbol:=_variable;
          sym^.typedef:=GetTypeDef(current_string);
          sym^.offset:=recordoffset;
          sym^.vartype:=vt;
          sym^.typedconst:=FALSE;
          sym^.attr:=s_none;
          AddSymbol(rectyp^.recordtable, sym);
          inc(recordoffset, GetSize(sym^.typedef));
        end;
      Match(_of);
      rectyp^.recordsize:=recordoffset;
      variantstart:=rectyp^.recordsize;
      repeat
        repeat
          p1:=expression;
          OptimizeTree(p1);
          if (p1^.op<>__ordconst) and (p1^.op<>__charconst) then
            LineError(LineCount,'Ordinal constant expected');
            if current_token=_comma then Match(_comma)
                                    else break;
        until false;
        Match(_colon);
        Match(_lparen);
        recoffset:=variantstart;
        if current_token<>_rparen then DoRecordField(rectyp, recoffset, isobject);
        if variantsize<rectyp^.recordsize then variantsize:=rectyp^.recordsize;
        rectyp^.recordsize:=variantstart;
        Match(_rparen);
        if current_token=_separator then Match(_separator)
                                    else break
      until (current_token=_end) or (current_token=_rparen);
      rectyp^.recordsize:=variantsize;
     end;
end;

procedure CreateVMT(o: pTypeRecord; objname: string);
{
  Format of VMT (virtual method table)

  ObjectSize         dd   Summary size of all fields plus 4 bytes for VMT pointer
  NegSize            dd   -ObjectSize
  DMTPointer         dd   Pointer to DMT ( dynamic methods tabel ) [NOT used!!]
  VM         Count * dd   Pointers to virtual methods
}
var vmindex,
    size   : longint;
    vmtname: string;
    vm     : pSymbolRecord;
begin
  size:=GetSize(o);
  vmtname:=VMTPrefix+objname;
  AddIntegerConst(ConstantTable, vmtname,  size, 4);
  AddIntegerConst(ConstantTable, vmtname, -size, 4);
  AddIntegerConst(ConstantTable, vmtname, 0, 4); {not used at the moment}
  {dump virtual methods}
  if o^.recordtable<>NIL then
    begin
      vmindex:=12;
      vm:=o^.recordtable^.first;
      while vm<>nil do
        begin
          if (vm^.symbol=_func) or (vm^.symbol=_proc) and
             ((vm^.prop and p_virtual) <> 0) then
            begin
              AddVirtualProcConst(ConstantTable, vmtname, objname+vm^.overloadedname);
              vm^.virtualindex:=vmindex;
              inc(vmindex, 4);
            end;
          vm:=vm^.next;
        end;
    end;
end;


function DoParameterList(var sym:pSymbolRecord; ParmOffset:longint):longint; forward;
function DoProcedure(parseheader:boolean):pSymbolRecord; forward;

function DoProcVar: pTypeRecord;
var
  typ : pTypeRecord;
  start, pStr: stringlist;
  v:vartype;
  sym: pSymbolRecord;

begin
  typ:=NewType;
  typ^.typedef:=_ProcedureDef;
  sym:=NewSymbol;
  DoParameterList(sym, 8);
  typ^.parameter:=sym^.parameter;
  dispose(sym);
  DoProcVar:=typ;
end;


function Object_Declaration(objname:string): pTypeRecord;

var typ: pTypeRecord;
    sym: pSymbolRecord;
    OldList: pSymbolList;
    old_vt : vartype;
    i : longint;
    parentname: string;
    parent: pSymbolRecord;

begin
  Match(_object_);
  oldlist := currentlist;
  parent := NIL;
  if current_token=_lparen then
    begin
      Match(_lparen);
      parentname:=GetName;
      parent:=GetSymbol(parentname);
      if (parent=NIL) or (parent^.symbol<>_type) and
         (parent^.typedef^.typedef<>_ObjectDef) then
        Expected('Object type');
      Match(_rparen);
    end;
  typ:=NewType;
  typ^.typedef:= _ObjectDef;
  typ^.childof:= parent;
  CreateSymbolList(typ^.recordtable);
  currentlist:=typ^.recordtable;
  old_vt  := vt;
  vt:=_ObjField;
  if parent = NIL then i:=4                         { skip first four bytes -> address of self }
                  else i:=GetSize(parent^.typedef); { inherit size from parent object          }
  repeat
    case current_token of
    _name       : begin
                    if upcase_string=_public then
                      begin
                        Match(_name);
                        {ignore it, it's the default...}
                      end
                    else
                    if upcase_string=_private then
                      begin
                        Match(_name);
                        {ignore it, it's the default...}
                      end
                    else
                      DoRecordField(typ, i, TRUE);
                  end;
    _constructor,
    _destructor,
    _function,
    _procedure  : begin
                    sym:=DoProcedure(TRUE);
                    sym^.typedef:=typ;
                    if current_token=_virtual then
                      begin
                        sym^.prop := sym^.prop or p_virtual;
                        Match(_virtual);
                        Match(_separator);
                      end;
                  end;
    _end        : break;
    end;
  until false;
  Match(_end);
  vt := old_vt;
  currentlist:=oldlist;

  CreateVMT(typ, objname);

  Object_Declaration:=typ;
end;


function GetTypeDef(const name : string):pTypeRecord;

label constfound;

var
   p1         : pTree;
   recsize,
   n, n1,n2   : longint;
   d1,d2      : double;
   start, typ : pTypeRecord;
   sym        : pSymbolRecord;

begin
  case current_token of
  _name       : begin {previously defined type}
                  typ:=NIL;
                  sym:=GetSymbol('_'+upcase_string);
                  if (sym<>NIL) and (sym^.symbol=_constant) then
                    goto constfound
                  else
                    if (sym<>NIL) and (sym^.symbol=_unit) then
                      begin
                        Match(_name);
                        Match(_period);
                        sym:=GetSymbolFromList(sym^.symlist, '_'+upcase_string);
                     end;
                  if (sym=NIL) or ((sym<>NIL) and (sym^.symbol<>_type)) then
                    Expected('type');
                  Match(_name);
                  typ:=sym^.typedef;
                end;
  _lparen     : begin {enumerated type}
                  Match(_lparen);
                  typ:=NewType;
                  typ^.TypeDef:=_EnumeratedDef;
                  start:=typ;
                  n:=0;
                  repeat
                    {typ^.name   := GetName;}
                    typ^.number := n;
                    sym:=NewSymbol; {add symbols as constants}
                    sym^.name   := GetName{typ^.name};
                    sym^.symbol := _Constant;
                    sym^.c      := _IntegerConst;
                    sym^.n      := n;
                    if makesymbolspublic then sym^.attr:= sym^.attr or s_public;
                    AddSymbol(CurrentList,sym);
                    if current_token<>_rparen then Match(_comma)
                                              else break; {stop reading constants}
                    inc(n);
                    typ^.definition:=NewType;
                    typ:=typ^.definition;
                  until false; {endless loop}
                  Match(_rparen);
                  typ:=start;
                 end;
  _string     : begin {string type}
                  typ:=GetStringType;
                end;
  _array      : begin {array type, multidimensional}
                  Match(_array);
                  Match(_lbracket);
                  typ:=NewType;
                  typ^.TypeDef := _ArrayDef;
                  start:=typ;
                  repeat
                    typ^.range:=GetTypeDef('');
                    if not IsOrdinal(typ^.range) then Expected('ordinal type');
                    if current_token=_comma then Match(_comma)
                                            else break;
                    typ^.definition:=NewType;
                    typ:=typ^.definition;
                    typ^.typedef:=_ArrayDef;
                  until false; {endless loop}
                  Match(_rbracket);
                  Match(_of);
                  typ^.definition:=GetTypeDef('');
                  typ:=start;
                end;
  _file       : begin
                  Match(_file);
                  typ:=NewType;
                  typ^.TypeDef := _FileDef;
                  if current_token=_of then
                    begin
                      Match(_of);
                      typ^.filetyperec:=NewType;
                      typ^.filetyperec:=GetTypeDef('');
                      typ^.filetyp:=_typed;
                    end
                  else
                    typ^.filetyp:=_untyped;
                end;
  _ptr        : begin
                  Match(_ptr);
                  typ:=NewType;
                  typ^.typedef:=_PointerDef;
                  typ^.PointerTo:=NewSymbol;
                  sym:=GetSymbol('_'+upcase_string);
                  if (sym<>NIL) and (sym^.symbol=_unit) then
                    begin
                      Match(_name);
                      Match(_period);
                      sym:=GetSymbolFromList(sym^.symlist, '_'+upcase_string);
                    end;
                  if (sym=NIL) then
                    begin
                      case current_token of
                      _name: begin {new identifier}
                               sym:=NewSymbol;
                               sym^.name:=GetName;
                               sym^.symbol:=_type;
                               sym^.vartype:=vt;
                               sym^.typedef:=NIL;
                               sym^.forwardtype:=TRUE;
                               AddSymbol(CurrentList, sym);
                               typ^.PointerTo:=sym;
                             end
                      else   begin
                               sym:=NewSymbol;
                               sym^.name:='P'+name; {this is a dummy variable, for internal use only!!}
                               sym^.symbol:=_type;
                               sym^.vartype:=vt;
                               sym^.typedef:=GetTypeDef('');
                               sym^.forwardtype:=FALSE; { don't check this, it's internal!}
                               AddSymbol(CurrentList, sym);
                               typ^.PointerTo:=sym;
                             end
                      end
                    end
                  else
                    begin
                      Match(_name); {eat the identifier}
                      typ^.PointerTo:=sym;
                    end;
                end;
  _set        : begin
                  Match(_set);
                  Match(_of);
                  typ:=NewType;
                  typ^.typedef:=_SetDef;
                  typ^.SetOf:=GetTypeDef('');
                  case typ^.setof^.typedef of
                  _BooleanDef   : ;
                  _EnumeratedDef: ;
                  _SubRangeDef  : begin
                                    n1:=typ^.setof^.LowerLimit;
                                    n2:=typ^.setof^.UpperLimit;
                                    if (n1 >= 0) and (n2 <= 255) then
                                      typ^.setsize:=1+(n2-n1) div 8
                                    else
                                      LineError(LineCount, 'Set base type out of range');
                                  end;
                  end;
                end;
  _record     : begin
                  typ:=NewType;
                  typ^.typedef:=_RecordDef;
                  CreateSymbolList(typ^.recordtable);
                  Match(_record);
                  recsize:=0;
                  DoRecordField(typ, recsize, FALSE);
                  if GetSize(typ)=0 then LineError(LineCount, 'Empty records not allowed');
                  Match(_end);
                end;
  _object_    : typ:=Object_Declaration(name);
  _procedure  : begin
                  Match(_procedure);
                  typ:=DoProcVar;
                end;
  _function   : begin
                  Match(_function);
                  typ:=DoProcVar;
                  Match(_colon);
                  sym^.ReturnType:=GetTypeDef('');
                  if sym^.returntype^.typedef=_StringDef then
                    inc(sym^.ParamSize, 4) {reserve dword for pointer to return space}
                end;
  else          begin {subrange type}
constfound:
                  p1:=Expression;
                  OptimizeTree(p1);
                  if (p1^.op=__subrange) then
                  begin
                    typ:=NewType;
                    typ^.typedef:=_SubRangeDef;
                    typ^.LowerLimit:=p1^.left^.n;
                    typ^.UpperLimit:=p1^.right^.n;
                    n1:=typ^.LowerLimit;
                    n2:=typ^.UpperLimit;
                    if n1>n2 then LineError(LineCount, 'Lower bound greater than upper bound');
                    if (p1^.left^.op=__charconst) and (p1^.right^.op=__charconst) then
                      begin
                        typ^.SubRangeTyp:=uchar;
                        typ^.LowerLimit:=ord(p1^.left^.c);
                        typ^.UpperLimit:=ord(p1^.right^.c);
                      end
                    else
                      begin
                        if (n1>=0) and (n2<=255) then
                          typ^.SubRangeTyp:=u8bit
                        else
                          if (n1>=-128) and (n2<=127) then
                            typ^.SubRangeTyp:=s8bit
                          else
                            if (n1>=0) and (n2<=65535) then
                              typ^.SubRangeTyp:=u16bit
                            else
                              if (n1>=-32768) and (n2<=32767) then
                                typ^.SubRangeTyp:=s16bit
                              else
                                if (n1>=0) and (n2<=$FFFFFFFF) then
                                  typ^.SubRangeTyp:=u32bit
                                else
                                  typ^.SubRangeTyp:=s32bit;
                      end;
                  end;
                  if (p1^.op=__float) then
                    begin
                      typ:=NewType;
                      typ^.typedef:=_RealDef;
                      d1:=p1^.left^.d;
                      d2:=p1^.right^.d;
                      if (d1>=1.5E-45) and (d2<=3.4E38) then
                        typ^.FP_Type:=f32bit
                      else
                        if (d1>=5.0E-324) and (d2<=1.7E308) then
                          typ^.FP_Type:=f64bit
                         else
                            typ^.FP_Type:=f80bit;

                      typ^.FP_LowerLimit:=d1;
                      typ^.FP_UpperLimit:=d2;
                    end;
                    if ((p1^.op<>__float) and (p1^.op<>__subrange)) then
                       LineError(LineCount, 'Error in expression');
                end;

  end;
  GetTypeDef:=typ;
end;

procedure Type_Declaration;

var
   name : string;
   fsym,
   sym  : pSymbolRecord;
   typ  : pTypeRecord;

begin
   Match(_type_);
   repeat
     name:=GetName;
     Match(_equal);
     sym:=NewSymbol;
     sym^.name   := name;
     if makesymbolspublic then sym^.attr:= sym^.attr or s_public;
     sym^.symbol := _type;
     sym^.typedef:= GetTypeDef(name);
     fsym:=GetSymbol(sym^.name);
     if (fsym<>NIL) and (fsym^.forwardtype=TRUE) then
       begin {it's a forward type... let's update the typedef}
         fsym^.typedef:=sym^.typedef;
         fsym^.forwardtype:=FALSE;
         dispose(sym); {destroy the found symbol}
       end
     else
       AddSymbol(CurrentList, sym);
     Match(_separator);
   until current_token <> _name;

   fsym:=CurrentList^.first;
   repeat
     if (fsym^.symbol=_type) then
       if fsym^.forwardtype=TRUE then LineError(LineCount, 'Undefined type in pointer definition ('+fsym^.name+')');
     fsym:=fsym^.next
   until fsym=NIL;
end;

procedure Var_Declaration;

var
   start, pStr      : stringlist;
   sym       : pSymbolRecord;
   typ       : pTypeRecord;
   size, a   : longint;
   abswhere      : longint;
   absolute_var  : pSymbolRecord;
   absolute_type : (none, mem_constant, var_overlay);
   p1            : pTree;
   s:string;
   external_var  : boolean;

begin
  Match(_var);
  repeat
    pStr:=GetStringList;
    start:=pStr;
    Match(_colon);
    typ:=GetTypeDef(pStr^.name^);
    {handle absolute keyword}
    absolute_type := none;
    if current_token = _absolute then
      begin
        Match(_absolute); { gobble token... now handle expression or var reference }
        case current_token of { syntax checking }
        _name             : begin
                              absolute_type := var_overlay; {used for later reference}
                              absolute_var := GetSymbol(ProcName+GetName);
                              {get identifier symbol entry}
                              if (absolute_var<>NIL) and (absolute_var^.symbol=_unit) then
                                begin
                                  Match(_name);
                                  Match(_period);
                                  absolute_var:=GetSymbolFromList(sym^.symlist, '_'+upcase_string);
                                end;
                              if absolute_var = NIL then
                                LineError(LineCount, 'Unknown identifier referenced');
                            end;
        _integer_constant : begin
                              absolute_type := mem_constant;
                              p1:=Expression; { This proc must gobble _ordconst token!! }
                              OptimizeTree(p1);
                              if p1^.op = __OrdConst then
                                abswhere := p1^.n {the memory address}
                              else
                                LineError(LineCount, 'Integer constant expected');
                              DestroyTree(p1);
                            end;
        else                LineError(LineCount, 'Variable or memory address expected');
        end;
      end;

    Match(_separator);
    external_var:=FALSE;
    if upcase_string = _external then
      begin
        external_var:=TRUE;
        Match(_name);
        Match(_separator);
      end;
    repeat
      sym:=NewSymbol;
      sym^.name:=pStr^.name^;
      if current_unit<>'' then sym^.overloadedname:=current_unit+'$'+sym^.name
                          else sym^.overloadedname:=sym^.name;
      if makesymbolspublic and not external_var then
        sym^.attr:= sym^.attr or s_public;
      if external_var then sym^.attr:= sym^.attr or s_varext;
      sym^.symbol:=_variable;
      sym^.typedef:=typ;
      sym^.vlevel := LexLevel;
      sym^.vartype:=vt;
      sym^.alias  := NIL;
      sym^.absreference := FALSE;
      sym^.typedconst:=FALSE;
      size:=GetSize(sym^.typedef);
      {alignment}
      if absolute_type = none then {do not align absolute variables}
        begin
          a:=size and (Options.AlignData-1);
          if a<>0 then
            inc(stacksize, Options.AlignData-a + size)
          else
            inc(stacksize, size);
        end;
      sym^.offset:=stacksize;
      case absolute_type of
      var_overlay : begin { Copy address info only... types may vary ;) }
                      sym^.vlevel := absolute_var^.vlevel;
                      sym^.offset := absolute_var^.offset;
                      sym^.attr   := sym^.attr or s_vardmp;
                      sym^.alias  := absolute_var; { Set alias variable }
                    end;
      mem_constant: begin
                      sym^.offset       := abswhere; { get machine address }
                      sym^.absreference := TRUE;     { Set as absolute reference }
                    end;
      end;
      AddSymbol(CurrentList, sym);
      pStr:=pStr^.next;
    until pStr=NIL;
  until current_token<>_name;
  DestroyStringList(start);
end;

procedure Label_Declaration;

var
   start, pStr      : stringlist;
   sym       : pSymbolRecord;
   typ       : pTypeRecord;
   size, a   : longint;

begin
  Match(_label_);
  repeat
    pStr:=GetLabelList;
    start:=pStr;
    repeat
      sym:=NewSymbol;
      sym^.name:=ProcName+pStr^.name^;
      if makesymbolspublic then sym^.attr:= sym^.attr or s_public;
      sym^.symbol:=_label;
      AddSymbol(CurrentList, sym);
      pStr:=pStr^.next;
    until pStr=NIL;
    Match(_separator);
  until not MaybeLabel(current_token);
  DestroyStringList(start);
end;

procedure TypedConst_Declaration(var typ:pTypeRecord; s:string);

var
   p1   : ptree;
   i    : longint;
   sym  : pSymbolRecord;
   con  : pConstantRecord;
   enum,
   field: string;

begin
  case typ^.typedef of
  _BooleanDef,
  _PointerDef,
  _EnumeratedDef,
  _SubRangeDef  : begin
                    p1:=expression;
                    OptimizeTree(p1);
                    con:=NewConstant;
                    con^.c:=_IntegerConst;
                    con^.size:=GetSize(typ);
                    con^.n:=p1^.n;
                    con^.id := getmemstring(s);
                    con^.dumped:=FALSE;
                    AddConstant(ConstantTable, con, FALSE); {add name to list of constants}
                    DestroyTree(p1);
                  end;
  _RealDef      : begin
                    p1:=expression;
                    OptimizeTree(p1);
                    con:=NewConstant;
                    con^.c:=_RealConst;
                    con^.size:=GetSize(typ);
                    if p1^.op = __realconst then
                      con^.d:=p1^.d
                    else
                      if p1^.op = __ordconst then con^.d:=p1^.n
                      else Expected('floating point constant');
                    con^.id := getmemstring(s);
                    con^.dumped:=FALSE;
                    AddConstant(ConstantTable, con, FALSE); {add name to list of constants}
                    DestroyTree(p1);
                  end;
  _StringDef    : begin
                    p1:=expression;
                    OptimizeTree(p1);
                    con:=NewConstant;
                    con^.c:=_StringConst;
                    con^.size:=typ^.length;
                    con^.s:=getmemstring(p1^.s^);
                    con^.id := getmemstring(s);
                    con^.dumped:=FALSE;
                    AddConstant(ConstantTable, con, FALSE); {add name to list of constants}
                    DestroyTree(p1);
                  end;
  _ArrayDef     : begin
                    Match(_lparen);
                    for i:=typ^.range^.lowerlimit to typ^.range^.upperlimit-1 do
                       begin
                         TypedConst_Declaration(typ^.definition, s);
                         Match(_comma);
                       end;
                    TypedConst_Declaration(typ^.definition, s); {read the last one also}
                    Match(_rparen);
                  end;
  _RecordDef    : begin
                    Match(_lparen);
                    while current_token<>_rparen do
                      begin
                        field:=GetName;
                        Match(_colon);
                        sym:=GetSymbolFromList(typ^.RecordTable, field);
                        if sym=nil then LineError(LineCount, 'Record field not found');
                        TypedConst_Declaration(sym^.typedef, s);
                        if current_token=_separator then Match(_separator)
                                                    else break;
                      end;
                    Match(_rparen);
                  end;
  else            LineError(LineCount, 'Invalid typed constant');
         end;
      end;

procedure Const_Declaration;

label again;

var
   old, p1   : pTree;
   name : string;
   typ  : pTypeRecord;
   sym  : pSymbolRecord;
{   table: SymbolList;}
   i:integer;

begin
  Match(_const);
  repeat
    name:=GetName;
    sym:=NewSymbol;
    sym^.name := name;
    if makesymbolspublic then sym^.attr:= sym^.attr or s_public;
    sym^.vartype:= vt;
    case current_token of
    _equal      : begin
                    sym^.symbol:= _constant;
                    sym^.consttyp:=NIL; {by default constants don't have a type definition}
                    Match(_equal);
                    p1:=Expression;
                    OptimizeTree(p1);
AGAIN:
                    case p1^.op of
                    __OrdConst   : begin {Ordinal constant: 4}
                                     sym^.n:=p1^.n;
                                     sym^.c:=_OrdinalConst;
                                     AddSymbol(CurrentList,sym);
                                   end;
                    __StringConst: begin {String constants: 'test'}
                                     sym^.s:=p1^.s^;
                                     sym^.c:=_StringConst;
                                     AddSymbol(CurrentList,sym);
                                   end;
                    __CharConst :  begin
                                     sym^.n:=p1^.n;
                                     sym^.c:=_OrdinalConst;
                                     AddSymbol(CurrentList,sym);
                                   end;
                    __RealConst  : begin {Real constants: 3.0E10}
                                     sym^.d:=p1^.d;
                                     sym^.c:=_RealConst;
                                     AddSymbol(CurrentList,sym);
                                   end;
                    __Type       : begin
                                     sym^.consttyp:=p1^.convtype;
                                     old:=p1;
                                     {final typecast determines type of constant}
                                     while p1^.op=__type do
                                       p1:=p1^.left;
                                     goto AGAIN;
                                   end;
                    else LineError(LineCount, 'Error in expression');
                    end;
                    DestroyTree(p1);
                    Match(_separator);
                  end;
    _colon      : begin
                    sym^.symbol := _Variable;
                    sym^.vlevel := LexLevel;
                    sym^.vartype:= vt;
                    sym^.absreference := FALSE;
                    sym^.alias        := NIL;
                    Match(_colon);
                    typ:=GetTypeDef('');
                    Match(_equal);
                    if current_unit<>'' then sym^.overloadedname:=current_unit+ProcName+'$'+sym^.name
                                        else sym^.overloadedname:=ProcName+'$'+sym^.name;
                    TypedConst_Declaration(typ, TCPrefix + sym^.overloadedname);
                    sym^.typedef:=typ;
                    sym^.typedconst:=TRUE;
                    {sym^.attr:= sym^.attr and s_vardmp;}
                    AddSymbol(CurrentList, sym);
                    Match(_separator);
                  end;
    else Match(_equal);
    end;
  until current_token <> _name;
end;

function DoParameterList(var sym:pSymbolRecord; ParmOffset:longint):longint;
{ processes parameters of procedure when it's declared }

var
   parm           : pSymbolRecord;
   typ            : pTypeRecord;
   {ParmOffset     : longint;}
   v              : VarType;
   start, pStr    : stringlist;
   typename,
   overloadedname : string;

begin
  overloadedname:=current_unit+'$' + sym^.name+'$';
  CreateSymbolList(sym^.parameter);
  Match (_lparen);
  inc(ParmOffset, 8); {4 bytes for stackframe and 4 bytes to save EBP}
  if LexLevel >= 2 then { if procedure is nested then... }
    inc(ParmOffset, 4); { allow for lexical parent link above return addr }
  {Note: the lexical parent link is an implicit parameter to nested
  procedures, and thus will be popped with other parameters. }
  repeat
    case current_token of
    _var     : begin
                 Match(_var);
                 v:=_ParmVar;
               end;
    _const   : begin
                 Match(_const);
                 v:=_ParmConst;
               end;
    else       v:=_ParmValue;
    end;
    pStr:=GetStringList;
    start:=pStr;
    if current_token=_colon then
      begin
        Match(_colon);
        typename:='$'+upcase_string;
        typ:=GetTypeDef('');
      end
    else
      begin
        if Options.OpenParameters=TRUE then
          begin
            typ:=NewType;
            typename:='$';
            typ^.typedef:=_EmptyDef;
          end
        else
          Expected('type definition');
      end;

      repeat
        parm:=NewSymbol;
        parm^.name   := pStr^.name^;
        parm^.symbol := _variable;
        parm^.vlevel := LexLevel;
        parm^.vartype:= v;
        parm^.absreference := FALSE;
        parm^.alias        := NIL;
        parm^.offset := ParmOffset;
        parm^.typedef:= typ;
        parm^.typedconst:=FALSE;
        if makesymbolspublic then parm^.attr:= parm^.attr or s_public;
        AddSymbol(sym^.parameter, parm); {for later use to define check correct calling}

        if (v=_ParmVar) or (v=_ParmConst) then
          ParmOffset := ParmOffset+4  {pointer (offset) is always 4}
        else
          begin
            if (parm^.typedef^.typedef=_SubRangeDef) and (GetSize(parm^.typedef)<4) then
              ParmOffset := ParmOffset+4
            else
              ParmOffset := ParmOffset+GetSize(parm^.typedef);
          end;
        pStr:=pStr^.next;
        overloadedname:=overloadedname+typename;
      until pStr=NIL;
    DestroyStringList(start); {strings aren't needed anymore}
    {read declaration until we've _not_ found a ';'}
    if current_token=_separator then Match(_separator)
                                else break;
  until false;

  AddList(sym^.parameter); {add the parameters to the symbollist}

  Match(_rparen);
  DoParameterList:=ParmOffset-8; {total size of parameters, needed for return}
  sym^.overloadedname:=overloadedname;
end;

function DoProcedure(parseheader:boolean):pSymbolRecord;
var
    parent         : pSymbolRecord;
    ObjectList     : pSymbolList;

function CheckForMethod(objname: string): pSymbolRecord;
var sym,
    sym_method: pSymbolRecord;
    method         : string;

begin
  sym_method:=NIL;
  if (current_token=_period) and not parseheader then
    begin
      Match(_period);
      sym:=GetSymbol(objname);
      if (sym^.typedef=NIL) or (sym^.typedef^.typedef<>_ObjectDef) then
        LineError(LineCount, 'Object type expected');
      ObjectList:=sym^.typedef^.RecordTable;
      parent:=sym^.typedef^.childof;
      while parent<>NIL do
        begin
          AddList(parent^.typedef^.RecordTable);
          parent:=parent^.typedef^.childof;
        end;
      method:=GetName;
      sym_method:=GetSymbolFromList(ObjectList, method);
      if sym_method=NIL then LineError(LineCount,'Method identifier expected');
      sym_method^.overloadedname:=objname+sym_method^.overloadedname;
      AddList(ObjectList);
    end;
  CheckForMethod:=sym_method;
end;

var
   OldObjName,
   NormalCaseName,
   Delname, OldName        :string;
   regcount       : integer;
   parm,
   method,
   OldSymbolTable   : pSymbolRecord;
   StackOffset,
   LocalSize      : longint; {Size of local variables}
   ParamSize      : longint; {Size of parameters}
   del, search, sym    : pSymbolRecord;
   typ:pTypeRecord;
   p1, block      : pTree;   {Parse tree}
   old_vt         : vartype;
   OldList,
   LocalList      : pSymbolList;
   startmem: longint;

begin
  method:=NIL;
  inc(LexLevel);
  startmem:=maxavail;
  old_vt:=vt;
  sym:=NewSymbol;
  sym^.prop:=0;
  if makesymbolspublic then sym^.attr:= sym^.attr or s_public;
  sym^.plevel := LexLevel;
  stacksize:=0;
  case current_token of
  _function    : begin
                   Match(_function);
                   sym^.symbol:=_func;
                 end;
  _procedure   : begin
                   Match(_procedure);
                   sym^.symbol:=_proc;
                 end;
  _constructor : begin
                   Match(_constructor);
                   sym^.symbol:=_proc;
                   sym^.prop:=sym^.prop or p_constructor;
                 end;
  _destructor  : begin
                   Match(_destructor);
                   sym^.symbol:=_proc;
                   sym^.prop:=sym^.prop or p_destructor;
                 end;
  end;

  OldName  := ProcName;
  NormalCaseName:=current_string; {this contains the procname as read by the scanner}
  ProcName := ProcName + GetName;
  method:=CheckForMethod(ProcName);
  sym^.name:= ProcName;
  if method<>NIL then StackOffset:=4
                 else StackOffset:=0;
  if current_token=_lparen then
    sym^.ParamSize:=DoParameterList(sym, StackOffset)
  else
    begin
      sym^.ParamSize:=StackOffset;
      if LexLevel >= 2 then inc(sym^.ParamSize, 4);
      sym^.parameter:=NIL;
      sym^.overloadedname:=current_unit+'$'+ ProcName+'$';
    end;
  if sym^.symbol=_func then
    begin
      Match(_colon);
      sym^.ReturnType:=GetTypeDef('');
      if sym^.returntype^.typedef=_StringDef then
        inc(sym^.ParamSize, 4) {reserve dword for pointer to return space}
      else
        sym^.LocalSize:=GetSize(sym^.ReturnType);
    end
  else
    begin
      sym^.ReturnType:=NIL; {no returntype}
      sym^.LocalSize:=0;
    end;

  {$IFDEF debug}
  writeln('Proc: ', procname, '...');
  {$ENDIF}
  Match(_separator);

  {let's see if there is already a procedure/function with the same name, if YES
   then we need to overload it}
  search:=GetSymbol(ProcName);
  if search=NIL then begin
                       sym^.nextoverloaded:=NIL;
                       AddSymbol(CurrentList, sym)
                     end
  else {already one with the same name}
    case search^.symbol of
    _Type         : if (search^.typedef<>NIL) and (search^.typedef^.typedef<>_ObjectDef) then
                      LineError(LineCount, 'Duplicate identifier (' +search^.name+ ')');
    _Proc, _Func  : begin
                      while (search^.overloadedname<>sym^.overloadedname) and
                            (search^.nextoverloaded<>NIL) do
                       search:=search^.nextoverloaded;
                      if search^.overloadedname=sym^.overloadedname then
                        begin
                          RemoveList(sym^.parameter);
                          DestroySymbolList(sym^.parameter); {remove parameters of the read parameters}
                          sym:=search; {update sym-record to forward declarated one}
                          if sym^.parameter<>NIL then
                            AddList(sym^.parameter); {restore the previously declared parameters}
                        end
                      else
                        begin
                          search^.nextoverloaded:=sym;
                          sym^.nextoverloaded:=NIL;
                        end;
             end;
    else     LineError(LineCount, 'Duplicate identifier');
    end;

  if parseheader then sym^.prop:=sym^.prop or p_forward       {enable bit}
                 else sym^.prop:=sym^.prop and not p_forward; {disable bit}

  current_method:=method;
  {parse code block of the procedure}
  if (sym^.prop and p_forward) = 0 then
    begin
      OldList:=CurrentList;
      CreateSymbolList(LocalList);
      AddList(LocalList);
      CurrentList:=LocalList;
      repeat
      case current_token of
      _name : begin
                if (upcase_string = _far) or
                   (upcase_string = _near) or
                   (upcase_string = _interrupt) then
                  LineError(LineCount, 'Procedure directive ''' + upcase_string + ''' not supported')
                else
                if (upcase_string = _inline) or
                   (upcase_string = _assembler) then
                  begin
                    if (upcase_string = _inline)    then sym^.prop:=sym^.prop or (p_register + p_inline);
                    {if (upcase_string = _register)  then sym^.prop:=sym^.prop or p_register;}
                    if (upcase_string = _assembler) then sym^.prop:=sym^.prop or p_assembler;
                    Match(_name);
                    Match(_separator);

                    { check for 'special name' }
                    if current_token=_string_constant then
                      begin
                        sym^.overloadedname:=current_string;
                        Match(_string_constant);
                        Match(_separator);
                      end;
                    inc(sym^.LocalSize, stacksize);

                    block:=AsmStatement;
                    typ:=sym^.returntype;
                    sym^.returntype:=NIL;
                    if (sym^.prop and p_inline)<>0 then
                      begin
                         sym^.inlinefirst:=block^.asmblock.first;
                         sym^.inlinerear :=block^.asmblock.rear;
                      end
                    else
                      GenCodeProc(sym, block);
                    sym^.returntype:=typ;
                    DestroyTree(block);
                    Match(_separator);
                    break;
                  end
                else
                if (upcase_string = _external) then
                  begin
                    Match(_name);
                    Match(_separator);
                    sym^.prop:=sym^.prop or p_underscore;
                    if current_token=_string_constant then
                      begin
                        sym^.prop:=sym^.prop and not p_underscore;
                        sym^.overloadedname:=current_string;
                        Match(_string_constant);
                        Match(_separator);
                      end;
                    break;
                  end
                else
                if (upcase_string = _win32api) then
                  begin
                    Match(_name);
                    Match(_separator);
                    sym^.overloadedname:='_'+NormalCaseName+'@'+Numb(sym^.paramsize);
                    sym^.attr:=s_extern+s_used;
                    break;
                  end{;}
                else
                if (upcase_string = _register) and Options.AllowRegisterCalling then
                  begin
                    Match(_name);
                    Match(_separator);
                    regcount:=integer(eax);
                    if sym^.parameter<>NIL then
                      begin
                        parm:=sym^.parameter^.first;
                        while parm<>NIL do
                          begin
                            if regcount=integer(ebx) then LineError(LineCount, 'Only three parameters allowed!');
                            parm^.vartype:=_RegVar;
                            dec(sym^.ParamSize, 4);
                            parm^.r:=regs(regcount);
                            sym^.usedregs:=sym^.usedregs + [parm^.r];
                            inc(regcount);
                            parm:=parm^.next;
                          end;
                      end;
                  end
                else
                  LineError(LineCount,'Unknown procedure directive')
              end;
      else    begin
                if current_token=_string_constant then
                  begin
                    sym^.overloadedname:=current_string;
                    Match(_string_constant);
                    Match(_separator);
                  end;
                vt:=_Local;                {all new symbols will be local}
                block:=main;               {parse procedure}
                inc(sym^.LocalSize, stacksize);
                OptimizeTree(block);       {optimize}

                OldObjName:=sym^.overloadedname;
                if method<>NIL then sym^.overloadedname:=method^.overloadedname;
                GenCodeProc(sym, block);  {generate code}
                sym^.overloadedname:=OldObjName;
                DestroyTree(block);
                Match(_separator);         { ; }
                break;
              end;
      end;
      until false;
      {delete local symbols}
      RemoveList(LocalList);
      DestroySymbolList(LocalList);
      CurrentList:=OldList;
    end
  else
    begin
      sym^.attr:= sym^.attr or s_public;
    end;

  RemoveList(sym^.parameter); {remove the parameters from the symbollist}

  ProcName := OldName;
  dec(LexLevel);
  vt:=old_vt;

  if (method<>NIL) and not parseheader then {remove symbols of current object and it's ancestors}
    begin
      RemoveList(ObjectList);
      parent:=method^.typedef^.childof;
      while parent<>NIL do
        begin
          RemoveList(parent^.typedef^.RecordTable);
          parent:=parent^.typedef^.childof;
        end;
    end;
  {$IFDEF debug}
  write('memory used: ', startmem - maxavail, ' byte, left: ',maxavail,' bytes');
  if sym^._forward then writeln(' -> FORWARD')
                   else writeln;
  writeln;
  {$ENDIF}
  DoProcedure:=sym;
end;

function Statement : pTree;

label labeldone;

var p1, p2 : pTree;
    sym    : pSymbolRecord;

begin
  case current_token of
  _begin    : p1:=block_statement;
  _if       : p1:=if_statement;
  _case     : p1:=case_statement;
  _repeat   : p1:=repeat_statement;
  _while    : p1:=while_statement;
  _for      : p1:=for_statement;
  _asm      : p1:=asmstatement;
  _break    : p1:=break_statement;
  _continue : p1:=continue_statement;
  _exit     : p1:=exit_statement;
  _goto     : p1:=goto_statement;
  _with     : p1:=with_statement;
  _separator: p1:=NIL;
  else        begin
                if MaybeLabel(current_token) then
                  begin   {check for label}
                    if ProcName<>'' then
                      sym := GetSymbol(ProcName+'_'+upcase_string)
                    else
                      sym := GetSymbol('_'+upcase_string);
                    if sym<>NIL then
                      begin
                        if sym^.symbol=_label then
                          begin
                            Match(current_token);
                            Match(_colon);
                            if (sym^.attr and s_vardmp) <> 0 then
                              LineError(LineCount, 'Label already defined');
                            p1 := GenlabelNode(sym);
                            sym^.attr := sym^.attr or s_vardmp;
                            goto labeldone; {skip the expression routine}
                         end;
                    end;
                  end;
                  p2:=Expression;
                  if (p2<>NIL) and (p2^.op<>__assign) and (p2^.op<>__call) and (p2^.op<>__asm) then
                    LineError(p2^.line, 'Error in expression');
                  p1:=p2; {returned from expression}
               end;
         end;
labeldone:
  statement:=p1;
end;

function Main: pTree;

begin
  if current_token=_uses then DoUnit;
  repeat
    case current_token of
    _const       : Const_Declaration;
    _var         :   Var_Declaration;
    _type_       :  Type_Declaration;
    _label_      : Label_Declaration;
    _constructor,
    _destructor,
    _procedure,
    _function    : DoProcedure(FALSE);
    else           break;
    end;
  until false;

  main:=block_statement;
end;

procedure CompileUnit(name: string);

var
    p         : pTree;
    localsym  : longint;
    OldList,
    LocalList : pSymbolList;

begin
  p:=NIL;
  Match(_name);
  Match(_separator);
  Match(_interface);
  makesymbolspublic:=TRUE;

  if current_token=_uses then DoUnit;

  repeat
    case current_token of
    _const       : Const_Declaration;
    _var         :   Var_Declaration;
    _type_       :  Type_Declaration;
    _label_      : Label_Declaration;
    _constructor,
    _destructor,
    _procedure,
    _function    : DoProcedure(TRUE);
    else           break;
    end;
  until false;

  makesymbolspublic:=FALSE;
  Match(_implementation);

  if current_token=_uses then DoUnit;

  OldList:=CurrentList;
  CreateSymbolList(LocalList);
  AddList(LocalList);
  CurrentList:=LocalList;

  repeat
    case current_token of
    _const       : Const_Declaration;
    _var         :   Var_Declaration;
    _type_       :  Type_Declaration;
    _label_      : Label_Declaration;
    _constructor,
    _destructor,
    _procedure,
    _function    : DoProcedure(FALSE);
    else           break;
    end;
  until false;

  if current_token=_begin then
    begin
      p:=Block_Statement;
    end
  else
    Match(_end);

  stacksize:=0;
  OptimizeTree(p);
  GenerateCodeUnit(Name, p);
  DestroyTree(p);

  {remove the local symbols}
  RemoveList(LocalList);
  DestroySymbolList(LocalList);
  CurrentList:=OldList;
end;

procedure AddDefaultSymbols; forward;

procedure DoProgram;
var
   _P        : PathStr;
   _D        : DirStr;
   _N        : NameStr;
   _E        : ExtStr;
   tmp : string;
   lib : text;
   name, buf : string;
   done: boolean;
   sym : psymbolrecord;
   p   : pTree;
   oldlist: pSymbolList;
   oldunit: string;

begin
  makesymbolspublic:=FALSE;
  LexLevel := 0;
  vt:=_Global;
  case Current_Token of
  _program: begin
              Match(_Program);
              ProgramName := GetName;
              {create a new symbollist for the program}
              oldlist := currentlist;

              sym:=NewSymbol;
              sym^.name:=ProgramName;
              sym^.symbol:=_unit;
              CreateSymbolList(sym^.symlist);
              currentlist:=sym^.symlist;

              AddSymbol(CurrentList, sym); {the unitname will be the first entry..}

              AddList(sym^.symlist);
              if current_token=_lparen then
                begin
                  Match(_lparen);
                  Match(_name);
                  repeat
                    Match(_comma);
                    Match(_name);
                    until current_token=_rparen;
                  Match(_rparen);
                end;
              Match(_separator);
              GenerateHeader;
              p:=Main;
              stacksize:=0;
              OptimizeTree(p);
              GenCodeMain(p);
              DestroyTree(p);
              currentlist:=oldlist;
            end;
  __unit  : begin
              Match(__unit);
              name:=upcase_string;
              ProgramName:=name; {for correct name in sourcefile}

              oldunit:=current_unit;
              current_unit:=upcase_string;

              sym:=NewSymbol;
              sym^.name:='_'+name;
              sym^.symbol:=_unit;

              {create a new symbollist for the unit}
              oldlist := currentlist;
              CreateSymbolList(sym^.symlist);
              currentlist:=sym^.symlist;

              AddSymbol(CurrentList, sym); {the unitname will be the first entry..}

              AddList(sym^.symlist);

              if Options.CompileSystemUnit then
                begin
                  AddDefaultSymbols;
                  InitOptimizer;
                end;

              GenerateHeader;
              stacksize:=0;
              CompileUnit(name);

              fsplit(__filename, _D, _N, _E);
              name := ToUpper(_D + _N);
              SaveUnit(name, sym^.symlist);
              current_unit:=oldunit;
              currentlist:=oldlist;
            end;
  else      begin
              GenerateHeader;
              p:=Main;
              stacksize:=0;
              OptimizeTree(p);
              GenCodeMain(p);
              DestroyTree(p);
            end;
  end;
end;

procedure go;

begin
   LineCount := 1;
   GetChar;
   GetChar;
   GetToken;
   DoProgram;
end;

procedure Compile(var s:string);

var
   _P  : PathStr;
   _D  : DirStr;
   _N  : NameStr;
   _E  : ExtStr;
   t   : string;
   temp_dest,
   temp_source,
   temp_incl: ^text;
   temp_token:token;
   temp_ahead,
   temp_look:char;
   temp_lines:longint;

   f : File;  {needed for progress counter}

begin
  {save old properties of the text files}
  temp_source:=@source^;
  temp_dest:=@dest^;
  temp_incl:=@incl^;
  temp_ahead:=ahead;
  temp_look:=look;
  temp_token:=current_token;
  temp_lines:=linecount;
  {get the filename}
  fsplit(s, _D, _N, _E);
  if _E='' then _E:='.PAS';
  s := ToUpper(_D + _N + _E); {source file}
  t := ToUpper(_D + _N); {path + name (without extension!)}

  new(source); {create file-pointers}
  new(dest);
  new(incl);

  OpenFileRead(source^, s);

  {********* Get filesize, needed for progress counter}
  oldFInf := FInf;
  new(FInf);
  Assign(f,s);
  Reset(f,1);
  FInf^.Size     := FileSize(f);
  FInf^.WhereNow := 0;
  FInf^.Divisor  := FInf^.Size div 100+1;
  Close(f);
  {*********}


  OpenFileWrite(incl^, t+'.ASI');
  OpenFileWrite(dest^, t+'.ASM');

  {$IFDEF P32IDE}
  CompileFileMessage(s);
  {$ENDIF}
  go; {let's compile it!}

  CloseFile(source^);
  dispose(source);
  source:=NIL;
  CloseFile(dest^);
  dispose(dest);
  dest:=NIL;
  CloseFile(incl^);
  dispose(incl);
  incl:=NIL;

  {********* Needed for progress counter}
  Dispose(FInf);
  FInf := OldFInf;
  {$IFNDEF P32IDE}
  WriteLn(s,'  100%');
  {$ENDIF}
  {*********}

  {restore old properties of the text files}
  dest:=@temp_dest^;
  source:=@temp_source^;
  incl:=@temp_incl^;
  current_token:=temp_token;
  look:=temp_look;
  ahead:=temp_ahead;
  linecount:=temp_lines;
end;

procedure AddDefaultSymbols;

var
    sym : pSymbolRecord;
    dword, typ : pTypeRecord;

begin
   sym:=NewSymbol;
   sym^.name:='_POINTER';       {name}
   sym^.symbol:=_type;          {it's a type}
   typ:=NewType;                {typedefinition}
   sym^.typedef:=typ;           {assign it}
   typ^.typedef:=_PointerDef;   {it's a pointer}
   typ^.PointerTo:=NIL;         {points to nothing}
   AddSymbol(CurrentList, sym);

   sym:=NewSymbol;
   sym^.name:='_BOOLEAN';       {name}
   sym^.symbol:=_type;          {it's a type}
   typ:=NewType;                {typedefinition}
   sym^.typedef:=typ;           {assign it}
   typ^.typedef:=_BooleanDef;   {it's a boolean}
   typ^.SubRangeTyp:=u8bit;
   typ^.lowerlimit:= 0;
   typ^.upperlimit:= 1;
   AddSymbol(CurrentList, sym);

   sym:=NewSymbol;
   sym^.name:='_DWORD';         {name}
   sym^.symbol:=_type;          {it's a type}
   typ:=NewType;                {typedefinition}
   sym^.typedef:=typ;           {assign it}
   typ^.typedef:=_SubRangeDef;  {it's a subrange}
   typ^.SubRangeTyp:=u32bit;
   typ^.lowerlimit:= -MaxLongInt - 1;
   typ^.upperlimit:= MaxLongInt;
   dword:=typ; {needed for the other functions}
   AddSymbol(CurrentList, sym);

   sym:=NewSymbol;
   sym^.name:='_DOUBLE';        {name}
   sym^.symbol:=_type;          {it's a type}
   typ:=NewType;                {typedefinition}
   sym^.typedef:=typ;           {assign it}
   typ^.typedef:=_RealDef;
   typ^.fp_type:=f64bit;
   AddSymbol(CurrentList, sym);

   sym:=NewSymbol;
   sym^.name:='_TEXT';          {name}
   sym^.symbol:=_type;          {it's a type}
   typ:=NewType;                {typedefinition}
   sym^.typedef:=typ;           {assign it}
   typ^.typedef:=_FileDef;
   typ^.filetyp:=_text;         {points to nothing}
   AddSymbol(CurrentList, sym);

   sym:=NewSymbol;
   sym^.name:='_WRITELN';
   sym^.symbol:=_Proc;
   sym^.internal:=in_writeln;
   AddSymbol(CurrentList, sym);

   sym:=NewSymbol;
   sym^.name:='_WRITE';
   sym^.symbol:=_Proc;
   sym^.internal:=in_write;
   AddSymbol(CurrentList, sym);

   sym:=NewSymbol;
   sym^.name:='_READLN';
   sym^.symbol:=_Proc;
   sym^.internal:=in_readln;
   AddSymbol(CurrentList, sym);

   sym:=NewSymbol;
   sym^.name:='_READ';
   sym^.symbol:=_Proc;
   sym^.internal:=in_read;
   AddSymbol(CurrentList, sym);

   sym:=NewSymbol;
   sym^.name:='_INC';
   sym^.symbol:=_Proc;
   sym^.internal:=in_inc;
   AddSymbol(CurrentList, sym);

   sym:=NewSymbol;
   sym^.name:='_DEC';
   sym^.symbol:=_Proc;
   sym^.internal:=in_dec;
   AddSymbol(CurrentList, sym);

   sym:=NewSymbol;
   sym^.name:='_SUCC';
   sym^.symbol:=_Func;
   sym^.internal:=in_succ;
   AddSymbol(CurrentList, sym);

   sym:=NewSymbol;
   sym^.name:='_PRED';
   sym^.symbol:=_Func;
   sym^.internal:=in_pred;
   AddSymbol(CurrentList, sym);

   sym:=NewSymbol;
   sym^.name:='_ORD';
   sym^.symbol:=_Func;
   sym^.internal:=in_ord;
   AddSymbol(CurrentList, sym);

   sym:=NewSymbol;
   sym^.name:='_CHR';
   sym^.symbol:=_Func;
   sym^.internal:=in_chr;
   AddSymbol(CurrentList, sym);

   sym:=NewSymbol;
   sym^.name:='_SIZEOF';
   sym^.symbol:=_Func;
   sym^.internal:=in_sizeof;
   AddSymbol(CurrentList, sym);

   sym:=NewSymbol;
   sym^.name:='_NEW';
   sym^.symbol:=_Proc;
   sym^.internal:=in_new;
   AddSymbol(CurrentList, sym);

   sym:=NewSymbol;
   sym^.name:='_DISPOSE';
   sym^.symbol:=_Proc;
   sym^.internal:=in_dispose;
   AddSymbol(CurrentList, sym);

   sym:=NewSymbol;
   sym^.name:='_LENGTH';
   sym^.symbol:=_Func;
   sym^.internal:=in_length;
   AddSymbol(CurrentList, sym);

   sym:=NewSymbol;
   sym^.name:='_ASSIGNED';
   sym^.symbol:=_Func;
   sym^.internal:=in_assigned;
   AddSymbol(CurrentList, sym);
end;


procedure Init;

var p   : pTree;
    s, u   : text;
    io  : longint;
    oldname,
    syspath,
    sysunit : string;
   _P  : PathStr;
   _D  : DirStr;
   _N  : NameStr;
   _E  : ExtStr;

var sym:pSymbolrecord;

begin
   ProcName:='';

   CreateSymbolList(GlobalList); {contains symbols}
   AddList(GlobalList);
   CurrentList:=GlobalList;

   CreateConstantList(ConstantTable); {contains constants}

   InitTree; {parse tree}

   LineCount   := 1;
   LabelCount  := 0;


   {***************** compile system unit ********************}

   {get the system unit path+filename}
   oldname:=__filename;
   syspath:=FSearch(config.systemunit,'.\;'+GetEnv('P32')+';'+GetEnv('PATH'));
   __filename:=syspath;
   fsplit(syspath, _D, _N, _E);
   sysunit := ToUpper(_D + _N)+'.P32';

   assign(u, sysunit);
   {$I-} reset(u); {$I+}
   io:=ioresult;

   assign(s, syspath);
   {$I-} reset(s); {$I+}
   if ioresult <> 0 then Error(config.systemunit+' not found');

   if (Recompile(s, u)=FALSE) and
      (Options.CompileSystemUnit=FALSE) and
      (io=0) then
     begin
       close(s);
       close(u); {close it because loadunit reopens the file)}
       LoadUnit(sysunit, 'SYSTEM');
       InitOptimizer;
     end
   else
     begin
       close(s);
       Options.CompileSystemUnit:=TRUE; {set this to true, to ensure correct compilation}
       compile(syspath);
     end;

   sym:=GetSymbol('_SYSTEM');
   if sym<>NIL then sym^.overloadedname:=syspath;

   __filename:=oldname;
   LineCount := 1;
end;

procedure ResetCompiler;

begin
  SetCompilerDir;
  CPU := Pentium;
  InitPreProcessor; {activate preprocessor}
  CreateMainList;   {set symbol tables}
end;

var s: string;

begin
  SetCBreak(TRUE);
  ResetCompiler;
{$IFNDEF P32IDE}
  {lowlevel, TP7 specific stuff}
  SetRuntimeErrorHandler;

  writeln('P32 ' + P32_version + ' - Free 32 bit Pascal Compiler  [' + compiledate+']');
  writeln('(C) 1996-1999 by Johan Prins, jprins@knoware.nl - http://surf.to/p32');
  CheckUpCPU;
  writeln('CPU: ', CPUType, ', FPU: ', YesNo[FPUSupport], ', MMX: ', YesNo[MMXSupport], ', 3DNow!: ',
   YesNo[S3DNow], ', CMOV: ', YesNo[CMOVSupport]);

  ReadConfig;

  s:=FSearch(config.asmdef,'.\;'+GetEnv('P32')+';'+GetEnv('PATH'));
  if s='' then Error('Assembler definition file ('+config.asmdef+') not found');
  ReadDefinition(s);

  writeln('Target: ',  config.comment);

  __filename:=GetOptions;

  { set procedure pointer to compile procedure }

  if (__filename='') and not Options.CompileSystemUnit then Error('missing filename');

  writeln('Compiling...');

  Init; {Reads system unit}

  if not Options.CompileSystemUnit then compile(__filename); {compile it!}

  if Options.CreateBatch=TRUE then CreateBatchFile(__filename);
  if Options.ExecuteBatch=TRUE then ExecuteBatchFile(__filename);

  DestroyConstantList(ConstantTable);
  DestroySymbolList(GlobalList);
{$ENDIF}
end.

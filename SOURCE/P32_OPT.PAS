{                         P32 - 32bit Pascal Compiler                        }
{ -------------------------------------------------------------------------- }
{                       Johan Prins - jprins@knoware.nl                      }
{ ========================================================================== }
{ First pass, high-level optimizer                                           }
{                                                   (c) Copyright 1996-1999  }
{                                                                            }
{ -------------------------------------------------------------------------- }

unit P32_opt;

interface

uses P32_err, P32_prep, P32_asm, P32_asml, P32_scan, P32_symb, P32_tree;

procedure OptimizeTree(var p: pTree);
procedure InitOptimizer;

implementation

var
   current_proc : pSymbolRecord;
   realtyp,
   stringtyp,
   booleantyp,
   s32bit_typ   : pTypeRecord;

{Common subexpression elimination}
type
  pCSElist   = ^cserecord;

   cserecord = record
                node: pTree;
                next: pCSElist;
              end;
var
   cse      : pCSEList;

procedure CreateCSEList(var p: pCSElist);
begin
   new(p);
   p^.next:=NIL;
   p^.node:=NIL;
end;

procedure DestroyCSEList(var p: pCSElist);
var start: pCSElist;

begin
  start:=p;
  while start<>NIL do
    begin
      p:=start^.next;
      dispose(start);
      start:=p;
    end;
  p:=NIL;
end;

function CompareTreeNodes(p1, p2: pTree): boolean;
begin
  if  (p1^.op = p2^.op) and
      (p1^.sym = p2^.sym) and
     {when dealing with a variable, check last access }
     ((p2^.op=__var) and (p2^.sym^.lastaccess = p1^.CSElastaccess)) or
     {when dealing with a constant, check value }
     ((p2^.op=__ordconst) and (p2^.n = p1^.n)) then
    begin
      CompareTreeNodes:=TRUE;
    end
  else
    CompareTreeNodes:=FALSE;
end;

procedure AddCSEListEntry(p1: pCSEList; var p2: pTree);
var sym: pSymbolRecord;

begin
  if (p2^.left^.op in [__var, __ordconst]) and
     (p2^.right^.op in [__var, __ordconst]) then
    begin
      if p1<>NIL then
        begin
          repeat
            if (p1^.node<>NIL) and
               (p1^.node<>p2) and {NEVER replace the original one}
               CompareTreeNodes(p1^.node^.left, p2^.left) and
               CompareTreeNodes(p1^.node^.right, p2^.right) then
              begin
                writeln('CSE!');
                sym:=NewSymbol;
                sym^.symbol:=_variable;
                sym^.name:='csevar';
                sym^.vartype:=_RegVar;
                sym^.orgnode:=p1^.node;

                p1^.node^.cse := true;

                sym^.r:=none;
                sym^.typedef:=s32bit_typ;
                p2:=GenVarNode(sym);
                OptimizeTree(p2);
                exit;
              end;
            if p1^.next = NIL then break;
            p1 := p1^.next;
          until false
        end;
    if (p1^.next=NIL) then
      begin
        new(p1^.next);
        p1:=p1^.next;
        p1^.next:=NIL;
        p1^.node:=p2;
        if p2^.left^.op=__var then p1^.node^.left^.CSElastaccess:=p2^.left;
        if p2^.right^.op=__var then p1^.node^.right^.CSElastaccess:=p2^.right;
      end;
    end
end;

(*function FindString(p: stringlist; s:string):boolean;

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
*)

function CalculateConstants(var p: pTree):boolean;

var sym:pSymbolRecord;

begin
  CalculateConstants:=FALSE;
  if (p^.left^.op=__ordconst) and (p^.right^.op=__ordconst) then
    begin
      p^.return:=NIL;
      if (p^.op=__slash) then
        begin
          p^.d := p^.left^.n / p^.right^.n;
          DestroyTree(p^.left);
          DestroyTree(p^.right);
          p^.op:=__realconst;
          CalculateConstants:=TRUE;
          exit; {not a good solution but it works...}
        end;
      case p^.op of
      __add : p^.n := p^.left^.n + p^.right^.n;
      __sub : p^.n := p^.left^.n - p^.right^.n;
      __mul : p^.n := p^.left^.n * p^.right^.n;
      __div : p^.n := p^.left^.n div p^.right^.n;
      __mod : p^.n := p^.left^.n mod p^.right^.n;
      __shl : p^.n := p^.left^.n shl p^.right^.n;
      __shr : p^.n := p^.left^.n shr p^.right^.n;
      __and : p^.n := p^.left^.n and p^.right^.n;
      __xor : p^.n := p^.left^.n xor p^.right^.n;
      __or  : p^.n := p^.left^.n or p^.right^.n;
      else  begin
              case p^.op of
              __equal      : p^.n := ord(p^.left^.n = p^.right^.n);
              __not_eq     : p^.n := ord(p^.left^.n <> p^.right^.n);
              __greater    : p^.n := ord(p^.left^.n > p^.right^.n);
              __less       : p^.n := ord(p^.left^.n < p^.right^.n);
              __greater_eq : p^.n := ord(p^.left^.n >= p^.right^.n);
              __less_eq    : p^.n := ord(p^.left^.n <= p^.right^.n);
              end;
              p^.return:=booleantyp;
            end;
      end;
      if p^.return=NIL then p^.return:=s32bit_typ;
      p^.op:=__ordconst;
      DestroyTree(p^.left);
      DestroyTree(p^.right);
      CalculateConstants:=TRUE;
      exit;
    end
    else
     if (p^.left^.op=__realconst) and (p^.right^.op=__realconst) then
    begin
      p^.return:=NIL;
      case p^.op of
      __add :  p^.d := p^.left^.d + p^.right^.d;
      __sub :  p^.d := p^.left^.d - p^.right^.d;
      __mul :  p^.d := p^.left^.d * p^.right^.d;
      __slash: p^.d := p^.left^.d / p^.right^.d;
      else  begin
              case p^.op of
              __equal      : p^.n := ord(p^.left^.d = p^.right^.d);
              __not_eq     : p^.n := ord(p^.left^.d <> p^.right^.d);
              __greater    : p^.n := ord(p^.left^.d > p^.right^.d);
              __less       : p^.n := ord(p^.left^.d < p^.right^.d);
              __greater_eq : p^.n := ord(p^.left^.d >= p^.right^.d);
              __less_eq    : p^.n := ord(p^.left^.d <= p^.right^.d);
              end;
              p^.return:=booleantyp;
            end;
      end;
      p^.op:=__realconst;
      DestroyTree(p^.left);
      DestroyTree(p^.right);
      CalculateConstants:=TRUE;
      exit;
    end;
  if (p^.left^.op=__realconst) and (p^.right^.op=__ordconst) then
    begin
      p^.return:=NIL;
      case p^.op of
      __add :  p^.d := p^.left^.d + p^.right^.n;
      __sub :  p^.d := p^.left^.d - p^.right^.n;
      __mul :  p^.d := p^.left^.d * p^.right^.n;
      __slash: p^.d := p^.left^.d / p^.right^.n;
      else  begin
              case p^.op of
              __equal      : p^.n := ord(p^.left^.d = p^.right^.n);
              __not_eq     : p^.n := ord(p^.left^.d <> p^.right^.n);
              __greater    : p^.n := ord(p^.left^.d > p^.right^.n);
              __less       : p^.n := ord(p^.left^.d < p^.right^.n);
              __greater_eq : p^.n := ord(p^.left^.d >= p^.right^.n);
              __less_eq    : p^.n := ord(p^.left^.d <= p^.right^.n);
              end;
              p^.return:=booleantyp;
            end;
      end;
      p^.op:=__realconst;
      DestroyTree(p^.left);
      DestroyTree(p^.right);
      CalculateConstants:=TRUE;
      exit;
    end;
  if (p^.left^.op=__ordconst) and (p^.right^.op=__realconst) then
    begin
      p^.return:=NIL;
      case p^.op of
      __add :  p^.d := p^.left^.n + p^.right^.d;
      __sub :  p^.d := p^.left^.n - p^.right^.d;
      __mul :  p^.d := p^.left^.n * p^.right^.d;
      __slash: p^.d := p^.left^.n / p^.right^.d;
      else  begin
              case p^.op of
              __equal      : p^.n := ord(p^.left^.n = p^.right^.d);
              __not_eq     : p^.n := ord(p^.left^.n <> p^.right^.d);
              __greater    : p^.n := ord(p^.left^.n > p^.right^.d);
              __less       : p^.n := ord(p^.left^.n < p^.right^.d);
              __greater_eq : p^.n := ord(p^.left^.n >= p^.right^.d);
              __less_eq    : p^.n := ord(p^.left^.n <= p^.right^.d);
              end;
              p^.return:=booleantyp;
            end;
      end;
      DestroyTree(p^.left);
      DestroyTree(p^.right);
      p^.op:=__realconst;
      CalculateConstants:=TRUE;
      exit;
    end;
end;

function IsBoolean(t: TreeType):boolean;
begin
  IsBoolean:=FALSE;
  if (t=__equal) or
     (t=__not_eq) or
     (t=__greater) or
     (t=__less) or
     (t=__greater_eq) or
     (t=__less_eq) then
    IsBoolean:=TRUE;
end;

procedure MaybeTypeConversion(var left, right: pTree);

begin
  if (left^.return<>NIL) and (right^.return<>NIL) and
     (left^.return<>right^.return) then
  if not IsBoolean(left^.op) and
     not IsBoolean(right^.op) and

     (left^.op<>__charconst) and
     (left^.op<>__stringconst) and
     (right^.op<>__charconst) and
     (right^.op<>__stringconst) then
    begin
      if (left^.return^.typedef=_SubRangeDef) and
         (right^.return^.typedef=_SubRangeDef) then
        begin
          if GetSize(left^.return)<4 then left:=GenTypeConvNode(left, s32bit_typ, false);
          if GetSize(right^.return)<4 then right:=GenTypeConvNode(right, s32bit_typ, false);
          if left^.left <>NIL then left^.line:=left^.left^.line;
          if right^.left<>NIL then right^.line:=right^.left^.line;
          OptimizeTree(left); {optimize the type conversion}
          OptimizeTree(right); {optimize the type conversion}
        end;
{        else}
          if (left^.return^.typedef<>right^.return^.typedef) or
             (GetSize(left^.return)<>GetSize(right^.return)) then
            begin
              if (left^.return^.typedef=_RealDef) or
                 (left^.op=__realconst) {or
                 {(left^.op=__ordconst) {or
                 (right^.op=__realconst)} then
                begin
                  right:=GenTypeConvNode(right, left^.return, false);
                  right^.line:=right^.left^.line;
                  OptimizeTree(right); {Optimize the conversion}
                end
              else
                begin
                  left:=GenTypeConvNode(left, right^.return, false);
                  left^.line:=left^.left^.line;
                  OptimizeTree(left); {Optimize the conversion}
                end
            end;
          end;
end;

procedure DoNothing(var p : pTree);

begin
end;

procedure DoStrConst(var p: pTree);

begin
  p^.loc.l:=memref;
  p^.return:=stringtyp;
end;

procedure DoOrdConst(var p: pTree);

begin
  p^.loc.l:=ordconst;
  p^.loc.value:=p^.n;
  if p^.return=NIL then p^.return:=s32bit_typ;
end;

procedure DoCharConst(var p: pTree);

begin
  p^.loc.l:=ordconst;
  p^.loc.value:=ord(p^.c);
  if p^.return=NIL then
    begin
      new(p^.return); {new type-record}
      p^.return^.typedef:=_SubRangeDef;
      p^.return^.subrangetyp:=uchar;
    end;
end;

procedure DoSetConst(var p: pTree);
var t: pTree;
begin
  p^.loc.l:=memref;
  t:=p^.left;
  while t<>nil do
    begin
      OptimizeTree(t^.left);
      t:=t^.right;
    end;
  {p^.return is assigned in the parser}
end;

procedure DoRealConst(var p: pTree);


begin
  p^.loc.l:=fpu;
  if p^.return=NIL then p^.return:=realtyp;
end;

procedure DoTypeConv(var p: pTree);

begin
  OptimizeTree(p^.left); {officially, only needed for typecasted variables}
  if p^.left<>NIL then
    begin
      p^.loc:=p^.left^.loc; {copy location of variable}
    end;
  p^.return:=p^.convtype; {type to convert to}
end;



procedure DoVar(var p : pTree);

begin
  if (p^.sym^.symbol=_variable) and (p^.sym^.absreference) then
    p^.loc.l:=directmem
  else
    begin
      if (p^.sym^.name='_PORT')  or (p^.sym^.name='_PORTW') or (p^.sym^.name='_PORTL') then
        p^.loc.l:=port
     else
        p^.loc.l:=memref; {always in memory}
    end;

  if p^.sym^.symbol = _variable then
    p^.sym^.lastaccess:=p; {update the lastaccess record with current treenode}

  ClearLoc(p^.loc); {clear contents of the location}
  if ((p^.sym^.symbol=_variable) or (p^.sym^.symbol=_type)) and
     (p^.sym^.typedef<>NIL) and
     (p^.sym^.typedef^.typedef=_ArrayDef) and
     (p^.sym^.typedef^.range<>NIL) and
     (p^.sym^.typedef^.range^.lowerlimit=0) and
     (GetSize(p^.sym^.typedef)=8) then
    p^.sym^.mmxable:=TRUE;
  p^.return:=p^.sym^.typedef;
end;

procedure DoAddress(var p : pTree);

var tmp, sym:pSymbolRecord;

begin
  if p^.left^.op=__call then p^.left^.op:=__var; {load address instead of calling procedure}
  OptimizeTree(p^.left);
  if p^.return=NIL then
    begin
      sym:=GetSymbol('_POINTER');
      p^.return:=sym^.typedef;
    end;
  if p^.left^.loc.l<>memref then LineError(p^.line, 'Error while loading address of variable');
end;

procedure DoPtr(var p : pTree);
var sym:pSymbolRecord;
begin
  OptimizeTree(p^.left);
  p^.loc.l:=memref; {always reference to memory location}
  p^.left^.loc.l:=memref;
  p^.return:=NIL;
  if (p^.left<>NIL) and (p^.left^.return<>NIL) and (p^.left^.return^.pointerto<>NIL) then
    p^.return:=p^.left^.return^.pointerto^.typedef
end;

procedure DoField(var p : pTree);

begin
  OptimizeTree(p^.left);

  p^.loc:=p^.left^.loc;

  if (p^.left^.loc.l<>memref) and
     (p^.left^.loc.l<>directmem) then LineError(p^.line, 'invalid record'); {should be a memory reference}
  p^.return:=p^.sym_field^.typedef;
  {  p^.return:=p^.left^.return;}
end;

procedure DoIndex(var p : pTree);

begin
  OptimizeTree(p^.left);

  p^.loc:=p^.left^.loc;

  OptimizeTree(p^.right);

  if ((p^.left<>NIL) and (p^.left^.return<>NIL)) and
      (p^.left^.return^.typedef<>_StringDef) then
    p^.right:=GenTypeConvNode(p^.right, s32bit_typ, false);

  if (p^.right^.left<>NIL) then p^.right^.line:=p^.right^.left^.line;
  OptimizeTree(p^.right);
  p^.return:=p^.left^.return^.definition;
end;


procedure DoAdd(var p: ptree);

var dummy:pointer;

begin
  if Options.OptimizeCSE then
    if cse<>NIL then AddCSEListEntry(cse, p);
  if p^.op=__var then exit;

  OptimizeTree(p^.left);
  OptimizeTree(p^.right);
  if CalculateConstants(p)=FALSE then
  begin
    if (p^.left^.op=__charconst) and (p^.right^.op=__stringconst) then
      begin
        p^.op    :=__stringconst;
        p^.s     :=getmemstring(p^.left^.c + p^.right^.s^);
        DestroyTree(p^.left);
        DestroyTree(p^.right);
      end
    else
      if (p^.left^.op=__stringconst) and (p^.right^.op=__charconst) then
        begin
          p^.op    :=__stringconst;
          p^.s     :=getmemstring(p^.left^.s^ + p^.right^.c);
          DestroyTree(p^.left);
          DestroyTree(p^.right);
        end
      else
        if (p^.left^.op=__stringconst) and (p^.right^.op=__stringconst) then
          begin
            p^.op    :=__stringconst;
            p^.s     :=getmemstring(p^.left^.s^ + p^.right^.s^);
            DestroyTree(p^.left);
            DestroyTree(p^.right);
          end
        else
  begin
    if (p^.left^.op=__ordconst) then
      begin {swap left and right tree to allow better code generation}
        dummy:=p^.left;
        p^.left:=p^.right;
        p^.right:=dummy;
      end;
    if (p^.left^.op=__var) and (p^.right^.op=__var) then
      begin
        if (p^.left^.sym<>NIL) and (p^.right^.sym<>NIL) then {skip when there are no symbols}
          if (p^.right^.sym=p^.left^.sym) and
             (p^.right^.sym^.typedef^.typedef=_SubRangeDef) and
             (p^.left^.sym^.typedef^.typedef=_SubRangeDef) and
             (p^.right^.sym^.symbol<>_Func) and
             (p^.left^.sym^.symbol<>_Func) then {don't try this with array, 'coz index-variable can be different}
            begin { X + X = 2 * X (better code-generation) }
              p^.op    :=__mul;
              p^.right^.op:=__ordconst;
              p^.right^.n := 2;
              exit; {done}
            end;
      end;
        if (p^.left^.return<>NIL) and
           (p^.left^.return^.typedef=_SubRangeDef) and
           (p^.left^.return^.subrangetyp=uchar) and
           (p^.right^.return<>NIL) and
           (p^.right^.return^.typedef=_StringDef) then
          begin
            p^.return:=p^.right^.return;
            exit;
          end;
        if (p^.right^.return<>NIL) and
           (p^.right^.return^.typedef=_SubRangeDef) and
           (p^.right^.return^.subrangetyp=uchar) and
           (p^.left^.return<>NIL) and
           (p^.left^.return^.typedef=_StringDef) then
          begin
            p^.return:=p^.left^.return;
            exit;
          end;
    MaybeTypeConversion(p^.left, p^.right);
    if (p^.return=NIL) and not asmmode then
    if (p^.left^.op=__ordconst) or
       (p^.left^.op=__realconst) then p^.return:=p^.right^.return
    else
      begin
        if (p^.left^.return<>NIL) and (p^.right^.return<>NIL) and
           (p^.left^.return^.typedef=_SubRangeDef) and
           (p^.right^.return^.typedef=_SubRangeDef) then
          p^.return:=s32bit_typ
        else
          p^.return:=p^.left^.return;
      end;
    end;
  end;
end;

procedure DoComparison(var p: ptree);

var dummy:pointer;

begin
  OptimizeTree(p^.left);
  OptimizeTree(p^.right);
  if CalculateConstants(p)=FALSE then
  begin
    if (p^.left^.return^.typedef=_SubRangeDef) then
      case p^.left^.return^.subrangetyp of
      s8bit, s16bit, s32bit : p^.signed:=TRUE;
      else                    p^.signed:=FALSE;
      end;
    if p^.return=NIL then
      begin
        MaybeTypeConversion(p^.left, p^.right);
        p^.return:=booleantyp;
      end;
  end;
end;

procedure DoWith(var p: pTree);

begin
  if p^.left<>NIL then OptimizeTree(p^.left);   {expression}
  if p^.right<>NIL then OptimizeTree(p^.right); {block}
end;



procedure DoAnd(var p: ptree);

var dummy: ptree;

begin
  OptimizeTree(p^.left);
  OptimizeTree(p^.right);
  if CalculateConstants(p)=FALSE then
  begin
    if p^.left^.op=__ordconst then
      begin {swap left and right tree to allow better code generation}
        dummy:=p^.left;
        p^.left:=p^.right;
        p^.right:=dummy;
      end;
    if p^.return=NIL then
      begin
        MaybeTypeConversion(p^.left, p^.right);
        p^.return:=p^.left^.return;
      end;
  end;
end;

procedure DoOr(var p: ptree);

var dummy: ptree;

begin
  OptimizeTree(p^.left);
  OptimizeTree(p^.right);
  if CalculateConstants(p)=FALSE then
  begin
    if p^.left^.op=__ordconst then
      begin {swap left and right tree to allow better code generation}
        dummy:=p^.left;
        p^.left:=p^.right;
        p^.right:=dummy;
      end;
    MaybeTypeConversion(p^.left, p^.right);
    if p^.return=NIL then p^.return:=p^.left^.return;
  end;
end;

procedure DoXor(var p: ptree);

var dummy: ptree;

begin
  OptimizeTree(p^.left);
  OptimizeTree(p^.right);
  if CalculateConstants(p)=FALSE then
  begin
    if p^.left^.op=__ordconst then
      begin {swap left and right tree to allow better code generation}
        dummy:=p^.left;
        p^.left:=p^.right;
        p^.right:=dummy;
      end;
    if p^.return=NIL then
      begin
        MaybeTypeConversion(p^.left, p^.right);
        p^.return:=p^.left^.return;
      end;
  end;
end;

procedure DoShl(var p: ptree);
begin
  OptimizeTree(p^.left);
  OptimizeTree(p^.right);
  if CalculateConstants(p)=FALSE then
  begin
    if p^.return=NIL then
      begin
        MaybeTypeConversion(p^.left, p^.right);
        p^.return:=p^.left^.return;
      end;
  end;
end;

procedure DoShr(var p: ptree);
begin
  OptimizeTree(p^.left);
  OptimizeTree(p^.right);
  if CalculateConstants(p)=FALSE then
  begin
    if p^.return=NIL then
      begin
        MaybeTypeConversion(p^.left, p^.right);
        p^.return:=p^.left^.return;
      end;
  end;
end;

procedure DoMul(var p: ptree);

var dummy:pointer;

begin
  if Options.OptimizeCSE then
    if cse<>NIL then AddCSEListEntry(cse, p);
  if p^.op=__var then exit;

  OptimizeTree(p^.left);
  OptimizeTree(p^.right);
  if CalculateConstants(p)=FALSE then
  begin
    if p^.left^.op=__ordconst then
      begin {swap left and right tree to allow fast code generation}
        dummy:=p^.left;
        p^.left:=p^.right;
        p^.right:=dummy;
      end;
    if p^.return=NIL then
      begin
        MaybeTypeConversion(p^.left, p^.right);
        p^.return:=p^.left^.return;
      end;
  end;
end;

procedure DoSlash(var p: ptree);
var d: double;
begin
  OptimizeTree(p^.left);
  OptimizeTree(p^.right);
  if CalculateConstants(p)=FALSE then
    begin
      if p^.right^.op = __ordconst then
        begin
          p^.op:= __mul;
          d:=1/p^.right^.n;
          DestroyTree(p^.right);
          p^.right := GenRealConstNode(d);
        end
      else
        if p^.right^.op = __realconst then
          begin
            p^.op:= __mul;
            d:=1/p^.right^.d;
            DestroyTree(p^.right);
            p^.right := GenRealConstNode(d);
          end
      else

      if p^.return=NIL then
        begin
          MaybeTypeConversion(p^.left, p^.right);
          p^.return:=realtyp;
          if p^.left^.return^.typedef<>_RealDef then
            p^.left:=GenTypeConvNode(p^.left, realtyp, false);
          if (p^.left<>NIL) and (p^.left^.left<>NIL) then
          p^.left^.line:=p^.left^.left^.line;
          OptimizeTree(p^.left);
          if p^.right^.return^.typedef<>_RealDef then
            p^.right:=GenTypeConvNode(p^.right, realtyp, false);
          if p^.right^.left<>NIL then
            p^.right^.line:=p^.right^.left^.line;
          OptimizeTree(p^.right);
        end;
    end;
end;

procedure DoDiv(var p: ptree);
begin
  OptimizeTree(p^.left);
  OptimizeTree(p^.right);
  if CalculateConstants(p)=FALSE then
  begin
    if p^.return=NIL then
      begin
        MaybeTypeConversion(p^.left, p^.right);
        p^.return:=p^.left^.return
      end;
  end;
end;

procedure DoMod(var p: ptree);
begin
  OptimizeTree(p^.left);
  OptimizeTree(p^.right);
  if CalculateConstants(p)=FALSE then
  begin
    if p^.return=NIL then
      begin
        MaybeTypeConversion(p^.left, p^.right);
        p^.return:=p^.left^.return;
      end;
  end;
end;

procedure DoSub(var p: ptree);
begin
  OptimizeTree(p^.left);
  OptimizeTree(p^.right);
  if CalculateConstants(p)=FALSE then
  begin
    if p^.return=NIL then
      begin
        MaybeTypeConversion(p^.left, p^.right);
        p^.return:=p^.left^.return;
      end;
  end;
end;

procedure DoMinus(var p: ptree);
begin
  OptimizeTree(p^.left);
  p^.return:=p^.left^.return;
  case p^.left^.op of
  __ordconst:  begin
                 p^.n     := 0 - p^.left^.n;
                 p^.op    := __ordconst;
                 DestroyTree(p^.left)
               end;
  __realconst: begin
                 p^.d     := 0 - p^.left^.d;
                 p^.op    := __realconst;
                 DestroyTree(p^.left)
               end;
  end;
end;

procedure DoNot(var p: ptree);

var oldnode: pTree;

begin
  OptimizeTree(p^.left);

  case p^.left^.op of
  __equal      : begin
                   oldnode:=p^.left;
                   p^.op:=__not_eq;
                   p^.return:=p^.left^.return;
                   p^.left:=p^.left^.left;
                   p^.right:=p^.left^.right;
                   dispose(oldnode);
                 end;
  __not_eq     : begin
                   oldnode:=p^.left;
                   p^.op:=__equal;
                   p^.return:=p^.left^.return;
                   p^.left:=p^.left^.left;
                   p^.right:=p^.left^.right;
                   dispose(oldnode);
                 end;
  __greater    : begin
                   oldnode:=p^.left;
                   p^.op:=__less_eq;
                   p^.return:=oldnode^.return;
                   p^.left:=oldnode^.left;
                   p^.right:=oldnode^.right;
                   dispose(oldnode);
                 end;
  __less       : begin
                   oldnode:=p^.left;
                   p^.op:=__greater_eq;
                   p^.return:=oldnode^.return;
                   p^.left:=oldnode^.left;
                   p^.right:=oldnode^.right;
                   dispose(oldnode);
                 end;
  __greater_eq : begin
                   oldnode:=p^.left;
                   p^.op:=__less;
                   p^.return:=oldnode^.return;
                   p^.left:=oldnode^.left;
                   p^.right:=oldnode^.right;
                   dispose(oldnode);
                 end;
  __less_eq    : begin
                   oldnode:=p^.left;
                   p^.op:=__greater;
                   p^.return:=oldnode^.return;
                   p^.left:=oldnode^.left;
                   p^.right:=oldnode^.right;
                   dispose(oldnode);
                 end;
  end;

  if (p^.left^.return<>NIL) and (p^.left^.return^.typedef=_BooleanDef) then
    begin
      if (p^.left^.op=__ordconst) then
        begin
          p^.op    :=__ordconst;
          p^.n := p^.left^.n xor 1;
          DestroyTree(p^.left);
        end;
    end
  else
    if (p^.left^.op=__ordconst)
      then begin
             p^.op    :=__ordconst;
             p^.n     := not p^.left^.n;
             DestroyTree(p^.left);
          end;
  if p^.return=NIL then p^.return:=p^.left^.return;
end;

procedure DoSubrange(var p : ptree);

begin
  OptimizeTree(p^.left);
  OptimizeTree(p^.right);
end;

procedure DoParam(var p : ptree; sym: pSymbolRecord);

begin
  OptimizeTree(p^.left);
  if sym<>NIL then
    begin
      if (p^.left^.return<>NIL) and (sym^.typedef<>NIL) and
         ((p^.left^.return^.typedef<>sym^.typedef^.typedef) or
          (GetSize(p^.left^.return)<>GetSize(sym^.typedef))) then
        begin
          p^.left:=GenTypeConvNode(p^.left, sym^.typedef, false);
        end
      else
        p^.left^.return:=sym^.typedef
    end;

  if sym=NIL then
    begin
      if p^.right<>NIL then DoParam(p^.right, sym)
    end
  else
    begin
      if (sym^.prev<>NIL) then
        begin
          sym:=sym^.prev;
          if p^.right<>NIL then DoParam(p^.right, sym{^.prev{next});
          OptimizeTree(p^.left);
        end;
    end;
end;

procedure DoInternalProcs(var p:pTree);
var para: pTree;
begin
  case p^.sym^.internal of
  in_read,
  in_readln,
  in_write,
  in_writeln : begin
                 if (p^.left<>NIL) {and (p^.sym^.parameter<>NIL)} then
                   begin
                     if p^.sym^.parameter<>NIL then
                       DoParam(p^.left, p^.sym^.parameter^.first) {there are parameters}
                   end;
               end;
  in_succ,
  in_pred    : begin
                 OptimizeTree(p^.left^.left); {don't optimize __param but the tree within it}
                 p^.return:=p^.left^.left^.return;
                 if p^.left^.left^.op=__ordconst then
                   begin
                     p^.op:=__ordconst;
                     p^.loc.l:=ordconst;
                     if p^.sym^.internal= in_succ then
                       p^.loc.value:=succ(p^.left^.left^.n)
                     else
                       p^.loc.value:=pred(p^.left^.left^.n);
                     p^.n:=p^.loc.value;
                     DestroyTree(p^.left);
                   end;
               end;
  in_ord     : begin
                 OptimizeTree(p^.left^.left);
                 if p^.left^.left^.op=__ordconst then
                   begin
                     p^.op:=__ordconst;
                     p^.loc.l:=ordconst;
                     p^.loc.value:=p^.left^.left^.n;
                     p^.n:=p^.loc.value;
                     DestroyTree(p^.left);
                   end
                 else
                   begin
                     new(p^.return); {new type-record}
                     p:=GenTypeConvNode(p^.left^.left, s32bit_typ, true);
                     p^.line:=p^.left^.line;
                     OptimizeTree(p); {optimize the type conversion}
                   end;
               end;
  in_chr     : begin
                 para:=p^.left^.left;
                 OptimizeTree(para);
                 if para^.op=__ordconst then
                   begin
                     p^.op:=__charconst;
                     p^.loc.l:=ordconst;
                     p^.loc.value:=para^.n;
                     p^.n:=p^.loc.value;
                     DestroyTree(p^.left);
                   end
                 else
                   begin
                     new(p^.return); {new type-record}
                     p^.return^.typedef:=_SubRangeDef;
                     p^.return^.subrangetyp:=uchar;
                     p:=GenTypeConvNode(para, p^.return, true);
                     p^.line:=p^.left^.line;
                     OptimizeTree(p); {optimize the type conversion}
                   end;
               end;
  in_sizeof  : begin
                 p^.op:=__ordconst;
                 p^.loc.l:=ordconst;
                 p^.loc.value:=GetSize(p^.left^.left^.return);
                 p^.n:=p^.loc.value;
                 DestroyTree(p^.left);
               end;
  in_length  : begin
                 para:=p^.left^.left;
                 OptimizeTree(para);
                 p^.sym^.returntype:=s32bit_typ;
                 p^.return:=s32bit_typ;
                 if para^.op=__stringconst then
                   begin
                     p^.op:=__ordconst;
                     p^.loc.l:=ordconst;
                     if para^.s<>NIL then p^.loc.value:=length(para^.s^)
                                     else p^.loc.value:=0;
                     p^.n:=p^.loc.value;
                     DestroyTree(p^.left);
                   end
                 else
                   if para^.op=__charconst then
                     begin
                       p^.op:=__ordconst;
                       p^.loc.l:=ordconst;
                       p^.loc.value:=1;
                       p^.n:=p^.loc.value;
                       DestroyTree(p^.left);
                     end;
               end;
  in_assigned: begin
                 OptimizeTree(p^.left^.left);
                 p^.sym^.returntype:=booleantyp;
                 p^.return:=s32bit_typ;
               end;
  end;
end;

procedure DoCall(var p: pTree);

var sym:pSymbolRecord;

begin
  if p^.right<>NIL then
    OptimizeTree(p^.right);

  if p^.sym_method<>NIL then sym:=p^.sym_method
                        else sym:=p^.sym;

  if sym^.nextoverloaded=NIL then {!!!!!!!!!!!! QUICK FIX!!}
  begin

  if (sym<>NIL) and (sym^.symbol=_variable) and (sym^.typedef<>NIL) and
     (sym^.typedef^.typedef=_ProcedureDef) then
    begin
      if (p^.left<>NIL) and (sym^.typedef^.parameter<>NIL) then
        DoParam(p^.left, sym^.typedef^.parameter^.rear);
      p^.return:=p^.sym^.typedef;
    end
  else
    begin
      if (p^.left<>NIL) and (sym<>NIL) and (sym^.parameter<>NIL)  then
        DoParam(p^.left, sym^.parameter^.rear);
    end;
  end;

  if sym^.internal<>no then
    DoInternalProcs(p)
  else
    begin
      if p^.return=NIL then
        p^.return:=sym^.ReturnType;
      if sym^.symbol=_func then
        begin
          case p^.return^.typedef of
          _BooleanDef,
          _PointerDef,
          _SubrangeDef: begin
                          p^.loc.l:=register;
                          p^.loc.reg:=eax;
                        end;
          _RealDef    : p^.loc.l:=fpu;
          else          p^.loc.l:=memref;
          end;
        end;
    end;
end;

procedure DoAssignment(var p : ptree);

begin
  OptimizeTree(p^.left);
  if p^.left^.op in [__ordconst, __realconst, __charconst, __stringconst] then
    Expected('Variable');
  OptimizeTree(p^.right);

  if (p^.left^.op=__call) and
     (p^.right^.op=__call) and
     (p^.left^.return<>NIL) and
     (p^.left^.return^.typedef=_ProcedureDef) then {assignment to procedural variable}
    begin
      {!!!check parameters!!!}
      p^.left^.op:=__var; {change it to a variable, to allow correct code generation}
      p^.right:=GenLeftNode(__address, p^.right);
      OptimizeTree(p^.right);
      p^.right^.return:=p^.left^.return;
    end
  else
    if (p^.left^.op=__call) then
      begin   {assignment to call -> function result}
        p^.left^.op:=__result;
        p^.left^.return:=p^.left^.sym^.ReturnType;
        p^.left^.loc.l:=memref
      end;

   if ((p^.right^.op = __stringconst) or (p^.right^.op = __charconst)) and
      (p^.left^.return<>NIL) and
      (p^.left^.return^.typedef=_PointerDef) and
      (p^.left^.return^.PointerTo<>NIL) and
      (p^.left^.return^.PointerTo^.typedef^.typedef=_SubRangeDef) and
      (p^.left^.return^.PointerTo^.typedef^.subrangetyp=uchar) then
     begin
       {change stringconst to pcharconst, types are compatible}
       p^.right^.op :=__pcharconst;
     end;

   if (p^.right^.op<>__charconst) and
      (p^.right^.op<>__stringconst) and
      ((p^.left^.return<>NIL) and (p^.right^.return<>NIL)) and
      ((p^.left^.return^.subrangetyp<>p^.right^.return^.subrangetyp) or
      (p^.left^.return^.typedef<>p^.right^.return^.typedef) or {and}
      (GetSize(p^.left^.return)<>GetSize(p^.right^.return))) then
     begin
       p^.right:=GenTypeConvNode(p^.right, p^.left^.return, false);
       p^.right^.line:=p^.right^.left^.line;
       OptimizeTree(p^.right); {Optimize the conversion}
     end;
  if p^.left^.return=NIL then
    p^.return:=p^.left^.return;
end;

procedure DoBlock(var p: pTree);

var
   p1  : ptree;
   tempcse :boolean;
begin
{  tempcse:=Options.OptimizeCSE;
  Options.OptimizeCSE:=FALSE;}

  p1:=p^.left;
  CreateCSEList(cse);
  while p1<>NIL do
  begin
    if (p1^.right<>NIL) then {ignore statement}
      begin
        OptimizeTree(p1^.right);
      end;
    p1:=p1^.left;
  end;
  DestroyCSEList(cse);
(*
  {*************************************************************}
  Options.OptimizeCSE:=tempcse;
  {Do an extra pass for CSE}
  if Options.OptimizeCSE then
    begin
      p1:=p^.left;
      CreateCSEList(cse);
      while p1<>NIL do
      begin
        if (p1^.right<>NIL) then {ignore statement}
          begin
            OptimizeTree(p1^.right);
          end;
        p1:=p1^.left;
      end;
      DestroyCSEList(cse);
    end;
  {*************************************************************}
*)
end;

procedure DoFor(var p : pTree);
var tmp:pTree;

begin
  OptimizeTree(p^.left);   {from}
  if (p^.left^.return<>NIL) and
     (p^.left^.return^.typedef<>_SubRangeDef) and
     (p^.left^.return^.typedef<>_EnumeratedDef) then LineError(p^.line, 'Invalid FOR control variable');

  tmp:=CopyTree(p^.left);  {copy assignment}
  DestroyTree(tmp^.right); {delete the right part ( a := 1 )
                                                        ~ -> this one}
  tmp^.right:=p^.right;    {assign to-value to right part of copied assignment}
  if p^.down_to=TRUE then tmp^.op:=__greater else tmp^.op:=__less;

  p^.right:=tmp;           {tmp-tree contains assignment}

  OptimizeTree(p^.right);  {to}

  OptimizeTree(p^.block);  {block to be executed to - from times}

  {if (p^.block = NIL) or (p^.block^.left=NIL) then
    begin
      p^.op:=__assign;
      tmp:=p^.left;       {holds old __assign-tree}
{      p^.left^:=p^.left^.left^;{contains a __assign, left=var, right=value}
{      DestroyTree(tmp);   {remove it}
{[    end;}
  if p^.left^.return=NIL then
    p^.return:=p^.left^.return;
end;

procedure DoRepeat(var p : ptree);

begin
  OptimizeTree(p^.left);
  if (p^.left^.return^.typedef=_BooleanDef) or
     (p^.left^.op=__ordconst) then
    begin
      OptimizeTree(p^.right);
    end
  else LineError(p^.line, 'Boolean expression expected');
end;

procedure DoWhile(var p : ptree);

begin
  OptimizeTree(p^.left);
  if (p^.left^.return^.typedef=_BooleanDef) or
     (p^.left^.op=__ordconst) then
    begin
      OptimizeTree(p^.right);
    end
  else LineError(p^.line, 'Boolean expression expected');
end;

procedure DoIf(var p : ptree);

var t:ptree;
begin
  OptimizeTree(p^.left);
  if (p^.left^.return^.typedef=_BooleanDef) or
     (p^.left^.op=__ordconst) then
    begin
      if p^.right<>NIL then OptimizeTree(p^.right);
    end
  else
    LineError(p^.line, 'Boolean expression expected');
  if p^.elsetree<>NIL then OptimizeTree(p^.elsetree);
end;

procedure DoCase(var p : ptree);

var t:ptree;
begin
  OptimizeTree(p^.left);
  OptimizeTree(p^.right);
  if p^.elsetree<>NIL then OptimizeTree(p^.elsetree);
end;

procedure DoCaseBlock(var p : ptree);

var t:ptree;
begin
  if (p^.left<>NIL) and (p^.left^.op=__caseblock) then OptimizeTree(p^.left); {value to evaluate}
  if p^.right<>NIL then OptimizeTree(p^.right);
  if p^.elsetree<>NIL then OptimizeTree(p^.elsetree); {block to execute when true}
end;

procedure OptimizeTree(var p: pTree);


begin
if p<>NIL then
  case p^.op of
  __block      : DoBlock(p);
  __index      : DoIndex(p);
  __field      : DoField(p);
  __assign     : DoAssignment(p);
  __float,
  __subrange   : DoSubRange(p);
  __type       : DoTypeConv(p);
  __ordconst   : DoOrdConst(p);
  __charconst  : DoCharConst(p);
  __stringconst: DoStrConst(p);
  __realconst  : DoRealConst(p);
  __var        : DoVar(p);
  __for        : DoFor(p);
  __if         : DoIf(p);
  __case       : DoCase(p);
  __caseblock  : DoCaseBlock(p);
  __while      : DoWhile(p);
  __repeat     : DoRepeat(p);
  __address    : DoAddress(p);
  __ptr        : DoPtr(p);
  __setconst   : DoSetConst(p);
  __call       : DoCall(p);
  __shl        : DoShl(p);
  __shr        : DoShr(p);
  __and        : DoAnd(p);
  __or         : DoOr(p);
  __xor        : DoXor(p);
  __not        : DoNot(p);
  __add        : DoAdd(p);
  __sub        : DoSub(p);
  __mod        : DoMod(p);
  __slash      : DoSlash(p);
  __div        : DoDiv(p);
  __mul        : DoMul(p);
  __minus      : DoMinus(p);
  __equal,
  __not_eq,
  __greater,
  __less,
  __greater_eq,
  __less_eq    : DoComparison(p);
  __with       : DoWith(p);
  __result     : {DoNothing(p)};
  __break      : {DoNothing(p)};
  __continue   : {DoNothing(p)};
  __exit       : {DoNothing(p)};
  __asm        : {DoNothing(p)};
  __nil        : {DoNothing(p)};
  __empty      : {DoNothing(p)};
  __goto       : {DoNothing(p)};
  __label      : {DoNothing(p)};
  else           begin
                   linecount:=p^.line; {update variable to allow error with (almost) correct linenr.}
                   Abort('Optimizer: '+Numb(Ord(p^.op)));
                 end;
  end;
end;

procedure InitOptimizer;

var s  : pSymbolRecord;
begin
  s:=GetSymbol('_DOUBLE');
  realtyp:=s^.typedef;
  s:=GetSymbol('_DWORD');
  s32bit_typ:=s^.typedef;
  s:=GetSymbol('_BOOLEAN');
  booleantyp:=s^.typedef;
  new(stringtyp);
  stringtyp^.typedef:=_StringDef;
end;

end.

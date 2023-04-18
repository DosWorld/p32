{                         P32 - 32bit Pascal Compiler                        }
{ -------------------------------------------------------------------------- }
{                       Johan Prins - jprins@knoware.nl                      }
{ ========================================================================== }
{ Routines for parse tree                                                    }
{                                                   (c) Copyright 1996-1999  }
{ http://www.cryogen.com/p32                                                 }
{                                                                            }
{ -------------------------------------------------------------------------- }

unit P32_tree;

interface

uses P32_symb, P32_asml, P32_asm, P32_scan, P32_err, P32_prep;

type

    TreeType = ( __subrange, __assign,
                 __less, __less_eq, __greater, __greater_eq, __equal, __not_eq,
                 __add, __sub, __or, __xor, __in,
                 __mul, __slash, __div, __mod, __and, __shl, __shr, __minus, __not,
                 __nil, __float,

                 __for, __while, __repeat, __if, __asm,  __with,
                 __break, __continue, __exit,
                 __block, __statement, __var, __type,
                 __label, __goto,
                 __proc, __call, __result, __param, __index, __ptr,
                 __case, __caseblock, __caseval,
                 __address, __field,
                 __ordconst, __charconst, __stringconst, __realconst, __setconst, __pcharconst,
                 __empty);

    s     = array[0..31] of byte;
    pset  = ^s;

    pTree = ^tree_record;

    tree_record = record
                   left, right  : pTree;   {pointers to left and right branch}
                   line         : longint; {for error reporting}
                   sym          : pSymbolRecord;
                   return       : pTypeRecord;
                   loc          : location;
                   cse          : boolean;
                   CSEreg:regs; {symbol    : pSymbolRecord;}
                   case op      : TreeType of
                   __less,
                   __less_eq,
                   __greater,
                   __greater_eq,
                   __equal,
                   __not_eq     : (signed:boolean);
                   __ordconst   : (n:longint);   {n = value of constant     }
                   __charconst  : (c:char);      {s = character             }
                   __pcharconst,
                   __stringconst: (s:pstring);   {s = pointer to string constant}
                   __realconst  : (d:double);    {d = value of real constant}
                   __setconst   : (cset: pset);  {cset = pointer to set constant}
                   __call       : (sym_method: pSymbolRecord);
                   __var        : (CSElastaccess: pTree);
                   __type       : (convtype: pTypeRecord;
                                   forced  : boolean);
                   __field      : (sym_field: pSymbolRecord);
                   __param      : (colon:boolean);    {true when the parameters contains a colon}
                   __index      : (index_reg:regs);      {true when EDI is needed as indexing register}
                   __caseblock,
                   __case, __if : (lab:integer;
                                   elsetree:pTree);           {block to be executed for else-tree}
                   __for        : (block:pTree;
                                   down_to:boolean); {block to be executed/up or downto}
                   __asm        : (asmblock: tAsmList);
                                   {asmblock: stringlist);}
                   __goto,
                   __label      : (glab:string[10]); {LB GOTO label}
              end;

procedure InitTree;
function GenExpNode(t : TreeType; l, r : pTree):pTree;
function GenLeftNode(t: TreeType; l : pTree):pTree;
function GenVarNode(sym: pSymbolRecord):pTree;
function GenTypeConvNode(p1: pTree; typ: pTypeRecord; forced:boolean):pTree;
function GenIndexNode(sym: pSymbolRecord; l:pTree):pTree;
function GenFieldNode(sym,sym_field:pSymbolRecord;l:pTree):pTree;
function GenCallNode(sym: pSymbolRecord):pTree;
function GenMethodCallNode(sym, sym_method: pSymbolRecord; r: pTree):pTree;
function GenOrdConstNode(n:longint;typ:pTypeRecord):pTree;
function GenCharConstNode(c:char):pTree;
function GenRealConstNode(d:double):pTree;
function GenStrConstNode(s:string):pTree;
function GenNilNode:pTree;
function GenAsmNode(s: tAsmlist):pTree;
function GenIfNode(l, r, elsetree : pTree) : ptree;
function GenCaseNode(l, r, elsetree : pTree) : ptree;
function GenCaseBlockNode(l, r, elsetree : pTree) : ptree;
function GenCaseValNode(l, r, elsetree : pTree) : ptree;
function GenRepeatNode(l, r : pTree) : ptree;
function GenWhileNode(l, r : pTree) : ptree;
function GenBreakNode : pTree;
function GenContinueNode : pTree;
function GenExitNode : ptree;
function GenGotoNode(sym:pSymbolRecord): pTree;
function GenLabelNode(sym: pSymbolRecord):pTree;
function GenForNode(l, r, block : pTree; down_to:boolean):ptree;
function GenParamNode(expr,next: pTree):pTree;
function GenWithNode(expr, block: pTree): pTree;

procedure DestroyTree(var p: pTree);
function CopyTree(p: pTree): pTree;
function ReverseTree(p:pTree):pTree;

implementation

var
   tree: pTree;

procedure InitTree;
begin
  tree:=NIL;
end;

function NewNode:pTree;

var
   p : pTree;

begin
  if tree=nil then new(p)
  else begin
         p:=tree;
         tree:=tree^.left;
       end;
  FillChar(p^, sizeof(p^), 0);
  p^.line:=LineCount;
  p^.loc.factor:=1;
  NewNode:=p;
end;

function GenExpNode(t : TreeType; l, r : pTree):pTree;

var p:pTree;

begin
  p:=NewNode;
  p^.op:= t;
  p^.left:=l;
  p^.right:=r;
  GenExpNode:=p;
end;

function GenLeftNode(t : TreeType; l : pTree):pTree;

var p:pTree;

begin
  p:=NewNode;
  p^.op:= t;
  p^.left:=l;
  GenLeftNode:=p;
end;

function GenVarNode(sym: pSymbolRecord):pTree;

var p:pTree;

begin
  p:=NewNode;
  p^.op:= __var;
  p^.sym:=sym;
  GenVarNode:=p;
end;


function GenTypeConvNode(p1: pTree; typ: pTypeRecord; forced:boolean):pTree;

var p:pTree;

begin
  p:=NewNode;
  p^.op:= __type;
  p^.left:=p1;
  p^.convtype:=typ;
  p^.forced:=forced;
  GenTypeConvNode:=p;
end;

function GenIndexNode(sym: pSymbolRecord; l:pTree):pTree;

var p:pTree;

begin
  p:=NewNode;
  p^.op:= __index;
  p^.sym:=sym;
  p^.left:=l;
  GenIndexNode:=p;
end;

function GenFieldNode(sym, sym_field:pSymbolRecord;l:pTree):pTree;

var p:pTree;

begin
  p:=NewNode;
  p^.op:=__field;
  p^.sym:=sym;
  p^.sym_field:=sym_field;
  p^.left:=l;
  GenFieldNode:=p;
end;

function GenCallNode(sym: pSymbolRecord):pTree;

var p:pTree;

begin
  p:=NewNode;
  p^.op:= __call;
  p^.sym:=sym;
  GenCallNode:=p;
end;

function GenMethodCallNode(sym, sym_method: pSymbolRecord; r: pTree):pTree;

var p:pTree;

begin
  p:=NewNode;
  p^.op:= __call;
  p^.sym:=sym;
  p^.sym_method:=sym_method;
  p^.right:=r;
  GenMethodCallNode:=p;
end;

function GenOrdConstNode(n:longint;typ:pTypeRecord):pTree;

var p:pTree;

begin
  p:=NewNode;
  p^.op:= __OrdConst;
  p^.n:=n;
  p^.return:=typ;
  GenOrdConstNode:=p;
end;

function GenCharConstNode(c:char):pTree;

var p:pTree;

begin
  p:=NewNode;
  p^.op:= __CharConst;
  p^.c:=c;
  GenCharConstNode:=p;
end;

function GenRealConstNode(d:double):pTree;

var p:pTree;

begin
  p:=NewNode;
  p^.op:= __RealConst;
  p^.d:=d;
  GenRealConstNode:=p;
end;

function GenNilNode:pTree;

var p:pTree;

begin
  p:=NewNode;
  p^.op:= __ordconst;
  p^.n:=0;
  GenNilNode:=p;
end;

function GenStrConstNode(s:string):pTree;

var p:pTree;

begin
  p:=NewNode;
  p^.op:= __StringConst;
  p^.s:=getmemstring(s);
  GenStrConstNode:=p;
end;

function GenAsmNode(s: tAsmlist):pTree;

var p:pTree;

begin
  p:=NewNode;
  p^.op:= __asm;
  p^.asmblock:= s;
  GenAsmNode:=p;
end;

function GenIfNode(l, r, elsetree : pTree) : ptree;

var
   p : pTree;

begin
  p:=NewNode;
  p^.op:=__if;
  p^.left:=l;
  p^.right:=r;
  p^.elsetree:=elsetree;
  GenIfNode:=p;
end;

function GenCaseNode(l, r, elsetree : pTree) : ptree;

var
   p : pTree;

begin
  p:=NewNode;
  p^.op:=__case;
  p^.left:=l;
  p^.right:=r;
  p^.elsetree:=elsetree;
  GenCaseNode:=p;
end;

function GenCaseBlockNode(l, r, elsetree : pTree) : ptree;

var
   p : pTree;

begin
  p:=NewNode;
  p^.op:=__caseblock;
  p^.left:=l;
  p^.right:=r;
  p^.elsetree:=elsetree;
  GenCaseBlockNode:=p;
end;

function GenCaseValNode(l, r, elsetree : pTree) : ptree;

var
   p : pTree;

begin
  p:=NewNode;
  p^.op:=__caseval;
  p^.left:=l;
  p^.right:=r;
  p^.elsetree:=elsetree;
  GenCaseValNode:=p;
end;

function GenRepeatNode(l, r : pTree) : ptree;

var
   p : pTree;

begin
  p:=NewNode;
  p^.op:=__repeat;
  p^.left:=l;
  p^.right:=r;
  GenRepeatNode:=p;
end;

function GenWhileNode(l, r : pTree) : ptree;

var
   p : pTree;

begin
  p:=NewNode;
  p^.op:=__while;
  p^.left:=l;
  p^.right:=r;
  GenWhileNode:=p;
end;

function GenBreakNode: pTree;

var
   p : pTree;

begin
  p:=NewNode;
  p^.op:=__break;
  GenBreakNode:=p;
end;


function GenContinueNode: pTree;

var
   p : pTree;

begin
  p:=NewNode;
  p^.op:=__continue;
  GenContinueNode:=p;
end;

function GenExitNode: pTree;

var
   p : pTree;

begin
  p:=NewNode;
  p^.op:=__exit;
  GenExitNode:=p;
end;

function GenGotoNode(sym:pSymbolRecord): pTree;   {LB for goto & labels}
var
   p : pTree;
begin
  p:=NewNode;
  p^.op      := __goto;
  p^.glab    := sym^.name;
  GenGotoNode:= p;
end;

function GenLabelNode(sym: pSymbolRecord):pTree;
var
  p:pTree;
begin
  p:=NewNode;
  p^.op   := __label;
  p^.sym  := sym;
  P^.glab := sym^.name;
  GenLabelNode:=p;
end;

function GenForNode(l, r, block : pTree; down_to:boolean):pTree;

var
   p : pTree;

begin
  p:=NewNode;
  p^.op:=__for;
  p^.left:=l;
  p^.right:=r;
  p^.block:=block;
  p^.down_to:=down_to;
  GenForNode:=p;
end;

function GenWithNode(expr, block: pTree): pTree;

var
   p: pTree;

begin
  p:=NewNode;
  p^.op:=__with;
  p^.left:=expr;
  p^.right:=block;
  GenWithNode:=p;
end;

function GenParamNode(expr,next: pTree):pTree;

var
   p : ptree;

begin
  p:=NewNode;
  p^.op:=__param;
  p^.left:=expr;
  p^.right:=next;
  p^.colon:=false;
  GenParamNode:=p;
end;

function ReverseTree(p:pTree):pTree;

var
    t1, t2 : pTree;

begin
  t1:=NIL;
  while p<>NIL do begin
                    t2:=p;
                    p:=p^.right;
                    t2^.right:=t1;
                    t1:=t2;
                  end;
  ReverseTree:=t1;
end;

procedure DestroyTree(var p: pTree);

begin
  if p<>NIL then
    begin
      if p^.left<>NIL then DestroyTree(p^.left);
      if p^.right<>NIL then DestroyTree(p^.right);
      case p^.op of
      __stringconst : freememstring(p^.s);
      __caseblock,
      __case,
      __if  : if p^.elsetree<>NIL then DestroyTree(p^.elsetree);
      __for : if p^.block<>NIL then DestroyTree(p^.block);
      __asm : {begin
                AsmList:=p^.asmblock;
                DestroyAsmList;
              end; {DestroyStringList(p^.asmblock);}
      end;
      {if p^.loc.name<>NIL then freememstring(p^.loc.name);}
      dispose(p);
      p:=NIL;
    end;
end;

function CopyTree(p: pTree): pTree;

var
   tmp : ptree;

begin
  tmp:=NewNode;
  tmp^:=p^;
  if p^.left<>NIL then tmp^.left:=CopyTree(p^.left);
  if p^.right<>NIL then tmp^.right:=CopyTree(p^.right);
  case p^.op of
  __case, __if : if p^.elsetree<>NIL then tmp^.elsetree:=CopyTree(p^.elsetree);
  __for        : if p^.block<>NIL then tmp^.block:=CopyTree(p^.block);
  end;
  CopyTree:=tmp;
end;

end.
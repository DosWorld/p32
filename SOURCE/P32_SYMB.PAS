{                         P32 - 32bit Pascal Compiler                        }
{ -------------------------------------------------------------------------- }
{                       Johan Prins - jprins@knoware.nl                      }
{ ========================================================================== }
{ Routines for symboltable                                                   }
{                                                   (c) Copyright 1996-1999  }
{                                                                            }
{ -------------------------------------------------------------------------- }
{ Main structure:                                                            }
{                                                                            }
{     Root                                                                   }
{      +---> List of global symbols defined in main file                     }
{      |                                                                     }
{      +---> List of exported symbols for every unit                         }
{      |                                                                     }
{      +---> List of procedure parameters (optional)                         }
{      |                                                                     }
{      +---> List of local symbols        (optional)                         }
{      |                                                                     }
{      +---> etc...                                                          }
{      |                                                                     }
{                                                                            }
{ -------------------------------------------------------------------------- }

unit P32_symb;

interface

uses P32_prep, P32_scan, P32_err;

const
   ConstantCount: integer=0;

   {symbol attributes}
   s_none        = $00; {00000000}
   s_public      = $01; {00000001}
   s_extern      = $02; {00000010}
   s_vardmp      = $04; {00000100}
   s_varext      = $08; {00001000}
   s_used        = $10; {00010000}
   s_win32       = $20; {00100000}

   {procedure attributes}
   p_none        = $00; {00000000}
   p_assembler   = $01; {00000001}
   p_register    = $02; {00000010}
   p_forward     = $04; {00000100}
   p_inline      = $08; {00001000}
   p_underscore  = $10; {00010000}
   p_constructor = $20; {00100000}
   p_destructor  = $40; {01000000}
   p_virtual     = $80; {10000000}

type
   regs = (none, ah, al, ax, bh, bl, bp, bx, ch, cl, cs, cx, dh, di, dl, ds, dx,
           eax, edx, ecx, ebx, esi, edi, esp, ebp, es, fs, gs, si, sp, ss);


   int_proc =  (          no,
                    in_write,
                  in_writeln,
                     in_read,
                   in_readln,
                   in_sizeof,
                      in_dec,
                      in_inc,
                     in_succ,
                     in_pred,
                      in_ord,
                      in_chr,
                      in_new,
                  in_dispose,
                   in_length,
                 in_assigned);

   StandardType =( s8bit,             {signed  8bit}
                  s16bit,             {signed 16bit}
                  s32bit,             {signed 32bit}
                   u8bit,             {unsigned  8bit}
                  u16bit,             {unsigned 16bit}
                  u32bit,             {unsigned 32bit}
                   uchar,             {char 8bit}

                   f32bit,            {floating-point 32 bit}
                   f64bit,            {floating-point 64 bit}
                   f80bit);           {floating-point 80 bit}


                  {u64bit,            {unsigned 64 bit integer}
                  {s64bit,            {signed   64 bit integer}


   StringType = (_ShortString, _LongString);


   SymbolType = (   _Label,
                 _Constant,
                 _Variable,
                     _Type,
                     _Proc,
                     _Func,
                   _Object,
                     _Unit,
                     __Reg);

   ConstType  = ( _IntegerConst,
                     _CharConst,
                  _OrdinalConst,
                   _StringConst,
                    _PCharConst,
                     _RealConst,
                      _VMTConst);

   VarType    = (  _Global,
                    _Local,
                  _ParmVar,
                _ParmConst,
                _ParmValue,
                 _ObjField,
                   _RegVar);

   FileType   = ( _Text,
                  _Untyped,
                  _Typed  );

   TypeDefinition = (_EmptyDef,
                     _EnumeratedDef,
                     _BooleanDef,
                     _SubRangeDef,
                     _ArrayDef,
                     _RecordDef,
                     _StringDef,
                     _FileDef,
                     _PointerDef,
                     _SetDef,
                     _ProcedureDef,
                     _ObjectDef,
                     _RealDef);

   pTypeRecord   =  ^TypeRecord;
   pSymbolRecord =  ^SymbolRecord;


   pSymbolList   = ^SymbolList;

     SymbolList  = record
                     First : pSymbolRecord;
                     Rear  : pSymbolRecord;
                   end;

   TypeRecord = record
                  case TypeDef: TypeDefinition of
                   _BooleanDef,
                   _SubRangeDef  : ( LowerLimit,
                                     UpperLimit  : Longint;
                                     SubRangeTyp : StandardType);
                   _StringDef,
                   _ArrayDef     : ( Length      : byte;          {strings only!}
                                     Range,
                                     Definition  : pTypeRecord);
                   _ObjectDef,
                   _RecordDef    : ( RecordSize  : longint;
                                     RecordTable : pSymbolList;
                                     ChildOf     : pSymbolRecord);  {objects only!}
                   _EnumeratedDef: ( Number      : word);
                   _FileDef      : ( FileTyp     : FileType;
                                     FileTypeRec : pTypeRecord);
                   _PointerDef   : ( PointerTo   : pSymbolRecord);
                   _SetDef       : ( SetOf       : pTypeRecord;
                                     SetSize     : byte);
                   _RealDef      : ( FP_LowerLimit,
                                     FP_UpperLimit  : double;
                                     FP_Type        : StandardType);
                   _ProcedureDef : ( Parameter   : pSymbolList;
                                     ReturnType  : pTypeRecord);
                end;



SymbolRecord=   record
                   name           : string[127];         {should be pstring}
                   overloadedname : string[127]; {should be pChar}
                   next, prev : pSymbolRecord;
                   attr       : word;
                   case Symbol: SymbolType of
                   _Label     : ();
                   _Constant  : (ConstTyp       : pTypeRecord;
                                 case c:ConstType of
                                 _IntegerConst,
                                 _OrdinalConst  : (n:longint);
                                 _CharConst     : (x:char);
                                 _StringConst   : (s:string[127]);
                                 _RealConst     : (d:double));
                   __Reg,
                   _Type,
                   _Variable  : (TypeDef      : pTypeRecord;
                                 Offset       : longint;
                                 vLevel       : longint;
                                 VarType      : VarType;
                                 AbsReference : boolean;
                                 Alias        : pSymbolRecord;
                                 TypedConst   : boolean;
                                 forwardtype  : boolean;
                                 mmxable      : boolean;
                                 lastaccess   : pointer;        {pointer to a treenode}
                                 orgnode      : pointer;
                   {!!!!! THIS ENTRY ONLY USED IN THE ASSEMBLY PARSER,
                          ALSO FOR VARIABLES IN REGISTERS!!!}
                                 r            : regs);
                   _Func,
                   _Proc      : (
                                 NextOverloaded: pSymbolRecord;
                                 Parameter     : pSymbolList;
                                 LocalSize,
                                 ParamSize     : longint;
                                 ReturnType    : pTypeRecord;
                                 pLevel        : byte;
                                 prop          : byte;
                                 inlinefirst   : pointer;
                                 inlinerear    : pointer;
                                 internal      : int_proc;
                                 virtualindex  : integer;
                                 usedregs      : set of regs);
                   _Unit       : (symlist      : pSymbolList;
                                  loaded       : boolean;
                                  unitname     : string[8]);
                 end;


     pConstantRecord    = ^ConstantRecord;

     ConstantList    = record
                         first : pConstantRecord;
                         rear  : pConstantRecord;
                       end;

     ConstantRecord = record
                        prev,
                        next           : pConstantRecord;
                        dumped         : boolean;
                        size           : longint;
                        id             : pstring;
                        case c         : ConstType of
                        _IntegerConst,
                        _OrdinalConst  : (n:longint);
                        _CharConst     : (x:char);
                        _VMTConst,
                        _StringConst   : (s:pstring);
                        _RealConst     : (d:double);
                      end;

     pSymbols = ^tSymbols;

     tSymbols = record
                  prev,
                  next  : pSymbols;
                  list  : pSymbolList;
                end;

var
   FirstList,
   LastList      : pSymbols;

   CurrentList,
   GlobalList    : pSymbolList;

   ConstantTable : ConstantList;

   LabelCount    : integer;
   vt            : vartype;
   StackSize,               {contains the stacksize that a procedure needs}
   LexLevel      : longint; {contains the lexlevel for nested procedures}

procedure CreateMainList;
function  NewSymbol: pSymbolRecord;
function  NewType: pTypeRecord;
procedure CreateSymbolList(var l: pSymbolList);
procedure DestroySymbolList(var l: pSymbolList);

procedure AddSymbol(var l: pSymbolList; sym: pSymbolRecord);
procedure DeleteSymbol(var l: pSymbolList; var sym : pSymbolRecord);
procedure RemoveLastSymbol(var l: pSymbolList);
function  GetSymbol(const name: string): pSymbolRecord;
function  GetSymbolFromList(l: pSymbolList; const name: string): pSymbolRecord;

procedure AttachList(var l1, l2: pSymbolList);
function  GetSize(typ:pTypeRecord): longint;
function  GetType(typ:pTypeRecord): TypeDefinition;
function GetOverloadedProc(start:pSymbolRecord; name:string):pSymbolRecord;

function  NewConstant:pConstantRecord;
procedure CreateConstantList(var l:ConstantList);

function  GetConstant(l :ConstantList; name: string): pConstantRecord;
function  AddConstant(var l: ConstantList; con: pConstantRecord; dup:boolean): pstring;

procedure AddIntegerConst(var L: ConstantList; const id: string; n, size: integer);
procedure AddVirtualProcConst(var L: ConstantList; const id: string; procname: string);

procedure RemoveLastConstant(var l: ConstantList);
procedure DestroyConstantList(var l: ConstantList);

procedure AddList(s: pSymbolList);
procedure RemoveList(s: pSymbolList);

implementation

procedure AddList(s: pSymbolList);
var temp : pSymbols;

begin
  new(temp);
  temp^.list := s;
  temp^.next := nil;
  temp^.prev := LastList;
  If (LastList = NIL) then
    begin
      FirstList := temp;
      LastList  := temp;
    end
  else
    begin
      LastList^.Next := temp;
      LastList       := temp;
    end;
end;

function GetList(s: pSymbolList): pSymbols;
var temp : pSymbols;

begin
  GetList:=NIL;
  temp:=firstlist;
  if (firstlist<>NIL) then
    while temp<>NIL do
      begin
        GetList:=temp;
        if (temp^.list <>NIL) and (temp^.list = s) then exit;
        temp:=temp^.next;
      end;
end;

procedure RemoveList(s: pSymbolList);
var temp : pSymbols;

begin
  if s=NIL then exit;

  temp:=GetList(s);
  if temp^.next=NIL then
    begin
      if firstlist^.next=NIL then
        begin
          firstlist := NIL;
          lastlist  := NIL;
        end
      else
        begin
          LastList := LastList^.prev;
          LastList^.next := NIL;
        end
    end
  else
    begin
      if (firstlist^.list^.first = s^.first) and
         (firstlist^.list^.rear  = s^.rear) then
        begin
          firstlist := firstlist^.next;
          firstlist^.prev := NIL;
        end
      else
        begin
          temp^.prev^.next := temp^.next;
          temp^.next^.prev := temp^.prev;
        end;
    end;
end;


procedure CreateSymbolList(var l: pSymbolList);
begin
  new(l);
  l^.first:=NIL;
  l^.rear :=NIL;
end;

function NewSymbol:pSymbolRecord;
var sym: pSymbolRecord;

begin
  new(sym);
  FillChar(sym^, sizeof(sym^), 0);
  NewSymbol:=sym;
end;

function NewType:pTypeRecord;
var typ: pTypeRecord;

begin
  new(typ);
  FillChar(typ^, sizeof(typ^), 0);
  NewType:=typ;
end;

procedure AddSymbol(var l: pSymbolList; sym: pSymbolRecord);

var dummy, temp    : pSymbolRecord;
    lev: longint;
begin
  dummy:=GetSymbolFromList(l, sym^.name);
  if (dummy<>NIL) and
     (dummy^.vartype=vt) and
     (dummy^.vlevel=LexLevel) then LineError(LineCount, 'Duplicate identifier ('+sym^.name+')')
  else
   begin
     temp := sym;                {Update pointer to data}
     temp^.next := nil;
     temp^.prev := L^.Rear;
     If (L^.Rear = NIL) then      {If empty list...}
       begin
         L^.First := temp;       {Add as first node}
         L^.Rear := temp;
       end
     else                    {else add at end}
       begin
         L^.Rear^.Next := temp;  {Make old rear of list point to new}
         L^.Rear := temp;        {Make rear point to new node}
       end;
   end;
end;

procedure DeleteSymbol(var L : pSymbolList;var sym : pSymbolRecord);
begin
  if (sym^.Next = nil) then       {If we're dealing with}
    RemoveLastSymbol(L)            {last node then that's easy}
  else                            {otherwise...}
    begin
      if (sym = L^.First) then              {if we're deleting the first node}
        begin
          L^.First := L^.First^.Next;    {Start list from second node}
          L^.First^.Prev := NIL;        {Set new starts previous link}
          Dispose(sym);                {Dispose of old first}
          sym:=NIL;
        end
      else
        begin
          sym^.prev^.next := sym^.next;     {Move pointers...}
          sym^.next^.prev := sym^.prev;
          Dispose(sym);          {Dispose of node}
          sym:=NIL;
        end;
    end;
end;

procedure RemoveLastSymbol(var L : pSymbolList);

begin
  if (L^.First <>NIL) and (L^.Rear<>NIL) then     {If nodes in list}
    if L^.First^.next = nil then
      begin
        Dispose(L^.First);             {Dispose of first node}
        L^.First := nil;
        L^.Rear := nil;                  {Set rear to nil}
      end
    else
      begin                            {If more than one node}
        L^.Rear := L^.Rear^.prev;       {Set rear to second last}
        Dispose(L^.Rear^.next);        {Remove last node}
        L^.Rear^.next:=Nil;
      end;
end;

procedure DestroySymbolList(var l : pSymbolList);
begin
  if l<>NIL then
    begin
      while l^.First <> NIL do
        RemoveLastSymbol(l);
      l^.first:=NIL;
      l^.rear:=NIL;
      dispose(l);
      l:=NIL;
    end;
end;

function GetSymbolFromList(l: pSymbolList;const name:string):pSymbolRecord;
{searches backwards}
var nxt,
    sym: pSymbolRecord;

begin
  if l=NIL then
    begin
      GetSymbolFromList:=NIL;
      exit;
    end;
  sym  := l^.rear;
  GetSymbolFromList:=sym;
  if sym<>NIL then
    begin
      while (sym <> NIL) and (name<>sym^.name) and (sym<>l^.first) do
      sym := sym^.prev;
      if sym^.name=name then
        begin
          sym^.attr:=sym^.attr or s_used; {This symbol is used!}
          if (sym^.symbol=_proc) or (sym^.symbol=_func) then
            begin
              nxt:=sym^.nextoverloaded;
              while nxt<>NIL do
                begin
                  nxt^.attr:=nxt^.attr or s_used; {This symbol is used!}
                  nxt:=nxt^.nextoverloaded;
                end;
            end;
          GetSymbolFromList:=sym
        end
      else
        GetSymbolFromList:=NIL;
    end;
end;

function GetSymbol(const name:string):pSymbolRecord;
{travels all lists, while searching the symbol, searches backward!}
var list: pSymbols;
     sym: pSymbolRecord;

begin
  {list:=firstlist;}
  list:=lastlist;
  sym:=NIL;
  while list<>nil do
    begin
      sym:=GetSymbolFromList(list^.list, name);
      if sym<>NIL then break;
      list:=list^.prev;
    end;
  GetSymbol:=sym;
end;

procedure AttachList(var l1, l2: pSymbolList);
begin
  if l1^.first<>NIL then
    begin
      l1^.rear^.next:=l2^.first;
      l2^.first^.prev:=l1^.rear;
      l1^.rear:=l2^.rear;
    end
  else
    l1:=l2;
end;

function GetSize(typ:pTypeRecord):longint;

var
   size:longint;

begin
  size:=0;
  case typ^.typedef of
  _BooleanDef : size:=1;
  _EmptyDef,
  _EnumeratedDef,
  _ProcedureDef,
  _PointerDef : size:=4;
  _SubRangeDef: case typ^.SubRangeTyp of
                uchar,
                s8bit,u8bit  : size:=1;
                s16bit,u16bit: size:=2;
                s32bit,u32bit: size:=4;
                end;
  _StringDef  : size:=1+typ^.length;
  _ArrayDef   : if typ^.range^.typedef=_SubRangeDef then
                  size:=(typ^.range^.UpperLimit-typ^.range^.LowerLimit+1)*GetSize(typ^.definition);
  _ObjectDef  : begin
                  size:=typ^.recordsize;
                end;
  _RecordDef  : size:=typ^.recordsize;
  _RealDef    : case typ^.FP_Type of
                f32bit: size:=4;
                f64bit: size:=8;
                f80bit: size:=10;
                end;
  _FileDef    : case typ^.filetyp of
                _text   : size:=512; {more logical value}
                _untyped: size:=256;
                end;
  _SetDef     : {size:=32;}
                size:=typ^.setsize;
  else          LineError(LineCount, 'GetSize: error determining type');
  end;
  GetSize:=size;
end;

function GetOverloadedProc(start:pSymbolRecord; name:string):pSymbolRecord;
{ find an overloaded procedure }

var lsym: pSymbolRecord;

begin
  lsym  := start;
  GetOverloadedProc:=lsym;
  while (lsym <> NIL) and (name<>lsym^.overloadedname) do
   lsym:=lsym^.nextoverloaded;
  if lsym^.overloadedname=name then
    GetOverloadedProc:=lsym
  else
    GetOverloadedProc:=NIL;
end;


function GetType(typ:pTypeRecord): TypeDefinition;

begin
   case typ^.typedef of
   _SubRangeDef  : GetType:=_SubRangeDef;
   _EnumeratedDef: GetType:=_EnumeratedDef;
   _ArrayDef     : GetType:=GetType(typ^.definition);
   _RealDef      : GetType:=_RealDef;
   _FileDef      : GetType:=_FileDef;
   _StringDef    : GetType:=_StringDef;
   _PointerDef   : GetType:=_PointerDef;
   _RecordDef    : GetType:=_RecordDef;
   else begin
          Error('[GetType] -> Cannot determine variable type');
        end;
   end;
end;

procedure CreateConstantList(var l:ConstantList);
begin
  l.first:=NIL;
  l.rear :=NIL;
end;

function NewConstant:pConstantRecord;
var con: pConstantRecord;

begin
  new(con);
  FillChar(con^, sizeof(con^), 0);
  NewConstant:=con;
end;


function GetConstant(l :ConstantList; name: string):pConstantRecord;
{searches backwards}

{!!!! only for stringconstants!!!!}
var con: pConstantRecord;

begin
  con := l.rear;
  GetConstant:=con;
  while (con<>l.first) and (con <> NIL) do
    begin
      if (con^.c=_StringConst) and (con^.s<>NIL) and (name=con^.s^) then break;
      con := con^.prev;
    end;
  if (con<>NIL) and (con^.c=_StringConst) and (con^.s<>NIL) then
    begin
      if (con^.s^=name) then
        GetConstant:=con
      else
        GetConstant:=NIL;
    end
  else
        GetConstant:=NIL;
end;

function AddConstant(var l:ConstantList;con: pConstantRecord; dup:boolean): pstring;
var
   dummy : pConstantRecord;
   temp  : pConstantRecord;
   found : Boolean;

begin
  dummy:=NIL;
  temp := nil;
  found := false;

  if con^.c=_StringConst then dummy:=GetConstant(l, con^.s^);

  if (dup=TRUE) and (dummy<>NIL) and (dummy^.id<>NIL) then
     AddConstant:=dummy^.id
  else
    begin
      temp := l.first;
      while ( temp <> nil ) do begin
        case con^.c of
        _RealConst:    found := ( temp^.d = con^.d );
        _IntegerConst: found := ( temp^.n = con^.n );
        _OrdinalConst: found := ( temp^.n = con^.n );
        _CharConst:    found := ( temp^.x = con^.x );
        end;
      if found then
        begin
          if ( temp^.id^[1] <> 'C' ) then
            begin
              found := false; {it's a predefined var, not a const !!!}
              temp  := temp^.next;
            end
          else
            begin
              AddConstant := temp^.id;
              temp  := nil;
            end;
        end
      else
        temp := temp^.next;
     end;

     if not found then
       begin
         temp := con;                {Update pointer to data}
         temp^.next := nil;
         temp^.prev := L.Rear;
         if (L.Rear = NIL) then
           begin                    {If empty list...}
             L.First := temp;       {Add as first node}
             L.Rear := temp;
           end
         else
           begin              {else add at end}
             L.Rear^.Next := temp;  {Make old rear of list point to new}
             L.Rear := temp;        {Make rear point to new node}
           end;

        if temp^.id=NIL then
          begin
            inc(ConstantCount);
            temp^.id:=getmemstring('C'+Numb(ConstantCount));
          end;
        AddConstant:=temp^.id;
     end;
  end;
end;

procedure RemoveLastConstant(var L: ConstantList);

begin
  if (L.First <>NIL) and (L.Rear<>NIL) then
    if L.First^.next = nil then
      begin
        if L.First^.id<>NIL then freememstring(L.First^.id);
        if (L.First^.c=_StringConst) and
           (L.First^.s<>NIL) then freememstring(L.First^.s);
        Dispose(L.First);
        L.First := nil;
        L.Rear := nil;
      end
    else
      begin
        L.Rear := L.Rear^.prev;
        if L.Rear^.next^.id<>NIL then freememstring(L.Rear^.next^.id);
        if (L.Rear^.next^.c=_StringConst) and
           (L.Rear^.next^.s<>NIL) then freememstring(L.Rear^.next^.s);
        Dispose(L.Rear^.next);
        L.Rear^.next:=Nil;
      end;
end;

procedure AddIntegerConst(var L: ConstantList; const id: string; n, size: integer);
var con: pConstantRecord;
begin
  con        := NewConstant;
  con^.c     := _IntegerConst;
  con^.size  := size;
  con^.n     := n;
  con^.id    := getmemstring(id);
  con^.dumped:= FALSE;
  AddConstant(ConstantTable, con, FALSE); {add name to list of constants}
end;

procedure AddVirtualProcConst(var L: ConstantList; const id: string; procname: string);
var con: pConstantRecord;
begin
  con        := NewConstant;
  con^.c     := _VMTConst;
  con^.size  := 4;
  con^.s     := getmemstring(procname);
  con^.id    := getmemstring(id);
  con^.dumped:= FALSE;
  AddConstant(ConstantTable, con, FALSE); {add name to list of constants}
end;


procedure DestroyConstantList(var L: ConstantList);
begin
  while L.First <> nil do  {While still nodes left}
    RemoveLastConstant(L); {Remove last node}

  l.first:=NIL;            {Reset values}
  l.rear:=NIL;
end;

procedure CreateMainList;
begin
  FirstList:=NIL;
  LastList :=NIL;
end;

end.
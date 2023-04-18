{                         P32 - 32bit Pascal Compiler                        }
{ -------------------------------------------------------------------------- }
{                       Johan Prins - jprins@knoware.nl                      }
{ ========================================================================== }
{ Unit loading and saving routines                                           }
{                                                    (c) Copyright 1997-1999 }
{                                                                            }
{ Written by: Daniel D. Bennett                                              }
{             Michael A. Goddard (cgoddard@ozemail.com.au) - RLE Compression }
{             Thomas Steen (TNSe@hotmail.com) - Rewrite RLE compression      }
{ -------------------------------------------------------------------------- }

{$DEFINE UseRLE}     {- Turn's ON RLE Compression (I don't know why anyone
                        would want to turn it off though) -}

unit P32_unit;

interface

uses P32_asml, P32_err, P32_scan, P32_symb, Dos;

procedure SaveUnit(unitname:string; list: pSymbolList);
procedure LoadUnit(const unitname, current_unit:string);
function Recompile(var source, unitfile:text):boolean;

implementation


const UNITVERSION = 13;

procedure SortList(list : pSymbolList); forward;

var
   USymTable : Array[0..1023] of Pointer;
   UTypTable : Array[0..1023] of Pointer;

   USymCount : longint;
   UTypCount : longint;

   unitstart : record
                 id       : array[1..3] of char;        { P32 }
                 brk      : Char;                       { #26 (EOF)}
                 version  : integer;
                 code     : longint;
                 symbols  : word;
                 types    : word;
                 comp     : boolean;                    { compression enabled? }
                 comptype : byte;                       { compression type }
                 reserved : array[1..16] of char;       { Futile expansion :) }
               end;
   unitfile  : file;

Type
 RLEHeader = Record
              packs    : word;          { Number of packs }
              packsize : word;          { Size of each pack }
              reserved : array[1..4] of char;  { for futile abuse }
             end;
 RLEDatas  = Record
              datatype : word;          { type of data }
              datacode : byte;
              datasize : word;
              reserved : array[1..3] of char;
             end;
 RLEBuffers= Array[1..65535] of byte;


Const
 RLEPackSize = 8192;   { Size of each RLE Pack }

 RLE8        = 1;
 NONE        = 0;

Var
 RLEHead      : RLEHeader;
 RLEData      : RLEDatas;

 RLEInBuffer  : ^RLEBuffers;
 RLEOutBuffer : ^RLEBuffers;
 RLEInCount   : Word;
 RLEOutCount  : Word;

 DATASeg      : Word;
 Magic        : Byte;   { the magic byte! }

 MagicTable   : Array[0..255] of Word;    { a table over chars used! }

{------------START OF RLE-STUFF------------}

Function FindMagic:Byte;
var
 x,y:Word;
begin
 FillChar(MagicTable,SizeOf(MagicTable),#00);

 For x := 1 to RLEInCount do
  Inc(MagicTable[RLEInBuffer^[x]]);

 y := 0;

 For x := 1 to 255 do   { find the least used byte }
  If (MagicTable[y] > MagicTable[x]) then y := x;

 FindMagic := y;    { this is the least used value }

end;

Procedure RLECompressBuffer;
var
 x,y,z,k:Word;
begin
   x := 1;
   While (RLEOutCount <> RLEInCount) AND (x <> RLEInCount) do
    begin
     y := RLEInBuffer^[x];
     inc(x);

     If (RLEOutCount = RLEInCount) AND (y = RLEData.datacode) then
      begin
       RLEOutBuffer^[RLEOutCount] := RLEData.datacode;
       Inc(RLEOutCount);
       { This is incase there is only place for 1 more byte...
         in that case, just don't store the 0 !!possible bug!!}
      end;

     z := 0;
     While (y = RLEInBuffer^[x+z]) AND (z <> 254) AND (x+z < RLEInCount) do
      Inc(z);   { possible bug fix }
     Inc(x,z);

     If (y = RLEData.datacode) AND (z < 2) then     { Store magic }
      begin
       For k := 0 to z do
        begin
         RLEOutBuffer^[RLEOutCount] := RLEData.datacode;
         Inc(RLEOutCount);
         RLEOutBuffer^[RLEOutCount] := $00;       { Make sure it is stored }
         Inc(RLEOutCount);
        end;
       Continue;        { do the next byte }
      end;

     If (z < 2) then
      begin
       for k := 0 to z do
        begin
         { 3 following alike bytes are best stored this way }
         RLEOutBuffer^[RLEOutCount] := y;
         Inc(RLEOutCount);
        end;
       continue;
      end;

     { RLE in use }
     RLEOutBuffer^[RLEOutCount] := RLEData.datacode;
     Inc(RLEOutCount);
     RLEOutBuffer^[RLEOutCount] := z+1;
     Inc(RLEOutCount);
     RLEOutBuffer^[RLEOutCount] := y;   { val }
     Inc(RLEOutCount);          { Anyone missing RLEOutCount++? }
    end;

end;

Procedure BlockWriteRLE(var What; HowMany:LongInt);
var
 DATABuffer:^RLEBuffers;
 DATACount:Word;
 x:Word;
begin

 DATABuffer := @What;
 DATACount := 1;

 x := RLEHead.packsize - RLEInCount;
 If (x > HowMany) then x := HowMany;
 Move(DATABuffer^[DATACount],RLEInBuffer^[RLEInCount],x);
 { Copy the data into the buffer }
 Inc(RLEInCount,x);
 Inc(DATACount,x);
 Dec(HowMany,x);
 { Make the counters correct }


 While (RLEInCount = RLEHead.packsize) do
  begin
   RLEData.datacode := FindMagic;
   RLEData.reserved := #0#0#0;

   RLECompressBuffer;     { compress the file }

   If (RLEOutCount >= RLEInCount) then   { No compression possible }
    begin
     RLEData.datatype := None;
     RLEData.datacode := 0;
     RLEData.datasize := RLEInCount;
     Move(RLEInBuffer^,RLEOutBuffer^,RLEData.datasize);
    end
   else
    begin
     RLEData.datatype := RLE8;
     RLEData.datasize := RLEOutCount;
    end;

   BlockWrite(unitfile,RLEData,SizeOf(RLEDatas));
   BlockWrite(unitfile,RLEOutBuffer^,RLEData.datasize);
   Inc(RLEHead.packs);
   RLEInCount := 1;
   RLEOutCount := 1;

   x := RLEHead.packsize - RLEInCount;
   If (x > HowMany) then x := HowMany;
   Move(DATABuffer^[DATACount],RLEInBuffer^[RLEInCount],x);
   { Copy the data into the buffer }
   Inc(RLEInCount,x);
   Inc(DATACount,x);
   Dec(HowMany,x);
   { Make the counters correct }
  end;
end;

Procedure BlockReadRLE(var What; HowMany:LongInt);
var
 DATABuffer:^RLEBuffers;
 DATACount:Word;
 x,y,z,k:Word;
begin
{ IN: RLEInBuffer, Temp: RLEOutBuffer, Dest: DATABuffer }
 DATABuffer := @What;
 DATACount := 1;
 If (RLEOutCount <> 1) then     { There were things left in buffer }
  begin
   x := RLEHead.packsize - RLEOutCount;
   If (x > HowMany) then x := HowMany;
   Move(RLEOutBuffer^[RLEOutCount],DATABuffer^[DATACount],x);
   Inc(RLEOutCount,x);
   Inc(DATACount,x);
   Dec(HowMany,x);
  end;
 While (HowMany <> 0) do
  begin
   RLEOutCount := 1;
   RLEInCount  := 1;

   BlockRead(unitfile,RLEData,SizeOf(RLEDatas));
   BlockRead(unitfile,RLEInBuffer^,RLEData.datasize);

   If (RLEData.datatype = None) then
    begin
     Move(RLEInBuffer^,RLEOutBuffer^,RLEHead.packsize);
    end;

   If (RLEData.datatype = RLE8) then
    begin
     y := RLEData.datacode;
     While (RLEInCount <> RLEData.datasize) do
      begin
       x := RLEInBuffer^[RLEInCount];
       Inc(RLEInCount);
       If (x = y) then  { Special on its way }
        begin
         x := RLEInBuffer^[RLEInCount];
         Inc(RLEInCount);
         If (x = 0) then
          begin
           RLEOutBuffer^[RLEOutCount] := y; { esc 0 }
           Inc(RLEOutCount);
           Continue;
          end;
         k := RLEInBuffer^[RLEInCount];
         Inc(RLEInCount);
         For z := 1 to x do
          begin
           RLEOutBuffer^[RLEOutCount] := k;
           Inc(RLEOutCount);
          end;
         Continue;
        end;
       RLEOutBuffer^[RLEOutCount] := x; { Just a normal out }
       Inc(RLEOutCount);
      end;
    end;

   RLEOutCount := 1;
   x := HowMany;
   If (x > RLEHead.packsize) then x := RLEHead.packsize;
   Move(RLEOutBuffer^[RLEOutCount],DATABuffer^[DATACount],x);
   Inc(RLEOutCount,x);
   Inc(DATACount,x);
   Dec(HowMany,x);
  end;
end;

Procedure RLEInit(Mode:Boolean);
begin
 If (Mode) then
  begin
   RLEHead.packs    := 0;
   RLEHead.packsize := RLEPackSize;
   RLEHead.reserved := #0#0#0#0;
   BlockWrite(Unitfile,RLEHead,SizeOf(RLEHeader));
  end
 else
  begin
   BlockRead(Unitfile,RLEHead,SizeOf(RLEHeader));
  end;

 GetMem(RLEInBuffer, RLEHead.packsize);
 GetMem(RLEOutBuffer,RLEHead.packsize);
 If (RLEInBuffer = nil) OR (RLEOutBuffer = nil) then Error('RLE Unit Engine out of memory!');
 RLEInCount  := 1;
 RLEOutCount := 1;
end;

Procedure RLEDone(Mode:Boolean);
begin
 If (Mode) then
  begin
   RLEData.datacode := FindMagic;
   RLEData.reserved := #0#0#0;

   RLECompressBuffer;

   If (RLEOutCount >= RLEInCount) then   { No compression possible }
    begin
     RLEData.datatype := None;
     RLEData.datacode := 0;
     RLEData.datasize := RLEInCount;
     Move(RLEInBuffer^,RLEOutBuffer^,RLEData.datasize);
    end
   else
    begin
     RLEData.datatype := RLE8;
     RLEData.datasize := RLEOutCount;
    end;

   If (RLEData.datasize <> 0) then
    begin
     BlockWrite(unitfile,RLEData,SizeOf(RLEDatas));
     BlockWrite(unitfile,RLEOutBuffer^,RLEData.datasize);
     Inc(RLEHead.packs);
    end;

   Seek(unitfile,32);
   BlockWrite(unitfile,RLEHead,SizeOf(RLEHeader));
  end;

 FreeMem(RLEOutBuffer,RLEHead.packsize);
 FreeMem(RLEInBuffer, RLEHead.packsize);
end;

{------------END OF RLE-STUFF------------}

procedure SaveAsmList(var list: tasmlist);
var a: pAsmRecord;
    l: integer;
begin
  a:=list.first;
  l:=0;
  while a<>NIL do
    begin
      inc(l);
      a:=a^.next;
    end;
  a:=list.first;
{$IFDEF UseRLE}
  BlockWriteRLE(l, sizeof(l)); {# of records}
{$ELSE}
  BlockWrite(unitfile, l, sizeof(l)); {# of records}
{$ENDIF}
  while a<>NIL do
    begin
{$IFDEF UseRLE}
      BlockWriteRLE(a^, sizeof(a^));
{$ELSE}
      BlockWrite(unitfile, a^, sizeof(a^));
{$ENDIF}
      a:=a^.next;
    end;
end;

procedure LoadAsmList(var list: tasmlist);
var a: pAsmRecord;
    i, l: integer;
    oldlist: tasmlist;
begin
  oldlist:=AsmList;
  CreateAsmList;
{$IFDEF UseRLE}
  BlockReadRLE(l, sizeof(l));
{$ELSE}
  BlockRead(unitfile, l, sizeof(l));
{$ENDIF}
  for i:=1 to l do
    begin
      a:=NewAsmEntry;
{$IFDEF UseRLE}
      BlockReadRLE(a^, sizeof(a^));
{$ELSE}
      BlockRead(unitfile, a^, sizeof(a^));
{$ENDIF}
      a^.next:=NIL;
      a^.prev:=NIL;
      AddAsmEntry(a);
    end;
  list:=asmlist;
  AsmList:=oldlist;
end;

function GetTypNumber(typ : pTypeRecord): word;
{Finds the type number for a pTypeRecord }

var
   i : word;

begin
  if typ=NIL then GetTypNumber:=0
  else
    for i := 1 to UTypCount do
       if UTypTable[i]=Pointer(typ) then
         begin
           GetTypNumber:=i;
           break;
         end;
end;

function GetSymNumber(sym: pSymbolRecord): word;
{Finds the sym number for a pSymbolRecord }

var
   i : word;

begin
  if sym=NIL then GetSymNumber:=0
  else
    for i := 1 to USymCount do
       if USymTable[i]=Pointer(sym) then
         begin
           GetSymNumber:=i;
           break;
         end;
end;

function GetListNumber(l: pSymbolList): word;
{Returns the sym number for the first entry in a list }
begin
  GetListNumber:=GetSymNumber(l^.first);
end;


procedure SaveTyp(typnum : word);
{   Saves a type making all necessary conversions from pointers to
    reference numbers }

var
   i   : Word;
   typ : pTypeRecord;
   unittyp: TypeRecord;

begin
  typ:=UTypTable[typnum];
  unittyp:=typ^;
  case typ^.TypeDef of
  _SubRangeDef  : ;
  _ArrayDef     : begin
                    longint(unittyp.Range):=GetTypNumber(typ^.Range);
                    longint(unittyp.Definition):=GetTypNumber(typ^.Definition);
                   end;
  _RecordDef    : longint(unittyp.RecordTable):=GetListNumber(typ^.RecordTable);
  _StringDef    : ;
  _EnumeratedDef: ;
  _FileDef      : begin
                    longint(unittyp.FileTypeRec):=GetTypNumber(typ^.FileTypeRec);
                  end;
  _PointerDef   : longint(unittyp.PointerTo):=GetSymNumber(typ^.PointerTo);
  _SetDef       : ;
  _RealDef      : ;
  end;
{$IFDEF UseRLE}
  BlockWriteRLE(unittyp, SizeOf(unittyp));
{$ELSE}
  BlockWrite(unitfile, unittyp, SizeOf(unittyp));
{$ENDIF}
end;

procedure SaveSym(symnum : word);
{   Saves a symbol making all necessary conversions from pointers to
    reference numbers }
var
   unitsym : SymbolRecord;
   i       : Word;
   sym     : pSymbolRecord;
   list    : tasmlist;
begin
  sym := USymTable[symnum];
  unitsym:=sym^;

  if unitsym.next<>NIL then longint(unitsym.next):=GetSymNumber(sym^.next)
                       else longint(unitsym.next):=0;
  if unitsym.prev<>NIL then longint(unitsym.prev):=GetSymNumber(sym^.prev)
                       else longint(unitsym.prev):=0;

  case sym^.Symbol of
  _Label     : ;
  _Constant  : longint(unitsym.typedef):=GetTypNumber(sym^.consttyp);
  _Type,
  _Variable  : longint(unitsym.typedef):=GetTypNumber(sym^.typedef);
  _Func,
  _Proc      : begin
                 if sym^.parameter<>NIL then
                   longint(unitsym.parameter):=GetListNumber(sym^.parameter)
                 else
                   longint(unitsym.parameter):=0;
                 if unitsym.nextoverloaded<>NIL then
                   longint(unitsym.nextoverloaded):=GetSymNumber(sym^.nextoverloaded)
                 else
                   longint(unitsym.nextoverloaded):=0;
                 longint(unitsym.ReturnType):=GetTypNumber(sym^.ReturnType);
               end;
  _Unit      : ;
  end;

{$IFDEF UseRLE}
  BlockWriteRLE(unitsym, SizeOf(unitsym));
{$ELSE}
  BlockWrite(unitfile, unitsym, SizeOf(unitsym));
{$ENDIF}
  if ((unitsym.symbol=_func) or (unitsym.symbol=_proc)) and
      ((unitsym.prop and p_inline)<>0) then
    begin
      list.first:=unitsym.inlinefirst;
      list.rear:=unitsym.inlinerear;
      SaveAsmList(list);
    end;
end;

procedure SaveStuff;
{   Traverses the type and symbol lists and calls the save procedures }
var
   SymCount : Word;

begin
   for SymCount:=1 to USymCount do
      SaveSym(SymCount);
   for SymCount:=1 to UTypCount do
      SaveTyp(SymCount);
end;

procedure SortSym(sym : pSymbolRecord); forward;

procedure SortTyp( typ : pTypeRecord);
{  Adds the type to the type list and recursively calls the Sym, Typ and
   list handlers }
var
   i : word;
begin
  if typ=NIL then exit;

  for i := 1 to UTypCount do
     if UTypTable[i]=Pointer(Typ) then
     begin
        Exit;
     end;
  inc(UTypCount);
  UTypTable[UTypCount]:=Typ;

  case typ^.TypeDef of
      _SubRangeDef  : ;
      _ArrayDef     : begin
                         SortTyp(typ^.Range);
                         SortTyp(typ^.Definition);
                      end;
      _RecordDef    : SortList(typ^.RecordTable);
      _StringDef    : ;
      _EnumeratedDef: ;
      _FileDef      : SortTyp(typ^.FileTypeRec);
      _PointerDef   : SortSym(typ^.PointerTo);
      _SetDef       : ;
      _RealDef      : ;
  end;
end;


procedure SortSym(sym : pSymbolRecord);
{  Adds the symbol to the sym list and recursively calls the Sym, Typ and
   list handlers }
var
   i : word;
begin
  if (sym=NIL) then Exit;

  for i := 1 to USymCount do
     if USymTable[i]=Pointer(Sym) then
     begin
        Exit;
     end;
  inc(USymCount);
  USymTable[USymCount]:=Sym;
  case sym^.Symbol of
     _Label     : ;
     _Constant  : SortTyp(sym^.ConstTyp);
     _Type,
     _Variable  : SortTyp(sym^.TypeDef);
     _Func,
     _Proc      : begin
                     if sym^.parameter<>NIL then
                        SortList(sym^.Parameter);
                     SortSym(sym^.NextOverloaded);
                     SortTyp(sym^.ReturnType);
                  end;
     _Unit      : ;
     end;
end;

procedure SortList(list : pSymbolList);
{  Goes through a list and calls the symbol handler }
var
   sym  : pSymbolRecord;
   old  : pSymbolRecord;

begin
   if (list^.first <> NIL) then
     begin
       sym:=list^.first;
       repeat
         SortSym(sym);
         old:=sym;
         sym:=sym^.next;
       until (old=list^.rear);
     end;
end;


procedure SaveUnit(unitname:string; list: pSymbolList);
begin
  USymCount:=0;
  UTypCount:=0;

  SortList(list);

  unitstart.id:='P32';
  unitstart.brk:=#26;
  unitstart.version:=UNITVERSION;
  unitstart.code:=0;
  unitstart.symbols:=USymCount;
  unitstart.types:=UTypCount;
  unitstart.comp:=FALSE;
  unitstart.comptype:=0;
  unitstart.reserved:=#0+#0+#0+#0+#0+#0+#0+#0+#0+#0+#0+#0+#0+#0+#0+#0;
  assign(unitfile,unitname+'.P32');
  rewrite(unitfile,1);
  blockwrite(unitfile, unitstart, sizeof(unitstart));
{$IFDEF UseRLE}
 RLEInit(TRUE);
{$ENDIF}
  SaveStuff;
{$IFDEF UseRLE}
 RLEDone(TRUE);
{$ENDIF}
  close(unitfile);
end;


procedure BuildList(var l : pSymbolList);
var
   sym : pSymbolRecord;

begin
   sym:=l^.first;
   while (sym^.next<>NIL) do begin
      sym:=sym^.next;
   end;
   l^.rear:=sym;
end;



procedure BuildTyp(typnum : word);
var
   typ : pTypeRecord;

begin
     typ:=UTypTable[typnum];

     case typ^.TypeDef of
         _SubRangeDef  : ;
         _ArrayDef     : ;
         _RecordDef    : BuildList(typ^.RecordTable);
         _StringDef    : ;
         _EnumeratedDef: ;
         _FileDef      : ;
         _PointerDef   : ;
         _SetDef       : ;
         _RealDef      : ;
     end;
end;


function LoadTyp(typnum : word) : Word;
var
   unittyp : TypeRecord;
   i   : Word;
   typ : pTypeRecord;

begin
{$IFDEF UseRLE}
  BlockReadRLE(unittyp, SizeOf(unittyp));
{$ELSE}
  BlockRead(unitfile, unittyp, SizeOf(unittyp));
{$ENDIF}
  typ:=UTypTable[typnum]; {get address}
  typ^:=unittyp;          {copy contents}
  {if (unitTyp.Class<>0) then Error('.P32 Corrupt');}

  case typ^.TypeDef of
  _SubRangeDef  : ;
  _ArrayDef     : begin
                    typ^.Range:=UTypTable[longint(unittyp.Range)];
                    typ^.Definition:=UTypTable[longint(unittyp.Definition)];
                  end;
  _RecordDef    : begin
                    CreateSymbolList(typ^.RecordTable);
                    typ^.RecordTable^.first:=USymTable[longint(unittyp.RecordTable)];
                  end;
  _StringDef    : ;
  _EnumeratedDef: ;
  _FileDef      : typ^.FileTypeRec:=UTypTable[longint(unittyp.FileTypeRec)];
  _PointerDef   : typ^.PointerTo:=USymTable[longint(unitTyp.PointerTo)];
  _SetDef       : ;
  _RealDef      : ;
  end;
end;



procedure BuildSym(symnum : word);
var
   i       : Word;
   sym     : pSymbolRecord;

begin
     sym:=USymTable[symnum];
     case sym^.Symbol of
        _Label     : ;
        _Constant  : ;
        _Type,
        _Variable  : ;
        _Func,
        _Proc      : if sym^.parameter<>NIL then BuildList(sym^.Parameter);
        _Unit      : ;
     end;
end;


function LoadSym(symnum : word):word;
var
   unitsym : SymbolRecord;
   i       : Word;
   sym     : pSymbolRecord;
   list    : tasmlist;
begin
{$IFDEF UseRLE}
  BlockReadRLE(unitsym, SizeOf(unitsym));
{$ELSE}
  BlockRead(unitfile, unitsym, SizeOf(unitsym));
{$ENDIF}
  if ((unitsym.symbol=_func) or (unitsym.symbol=_proc)) and
      ((unitsym.prop and p_inline)<>0) then
    begin
      LoadAsmList(list);
      unitsym.inlinefirst:=list.first;
      unitsym.inlinerear:=list.rear;
    end;

  sym:=USymTable[symnum]; {get address}
  sym^:=unitsym;           {copy contents}

  if longint(unitsym.next)<>0 then sym^.next:=USymTable[longint(unitSym.next)]
                              else sym^.next:=NIL;
  if longint(unitsym.prev)<>0 then sym^.prev:=USymTable[longint(unitSym.prev)]
                              else sym^.prev:=NIL;

  case sym^.Symbol of
  _Label     : ;
  _Constant  : sym^.consttyp:=UTypTable[longint(unitsym.consttyp)];
  _Type,
  _Variable  : sym^.typedef:=UTypTable[longint(unitsym.typedef)];
  _Func,
  _Proc      : begin
                 if unitsym.parameter<>NIL then
                   begin
                     CreateSymbolList(sym^.parameter);
                     sym^.parameter^.first:=USymTable[longint(unitsym.parameter)]
                   end
                 else
                   sym^.parameter:=NIL;
                 if sym^.nextoverloaded<>NIL then
                   sym^.nextoverloaded:=USymTable[longint(unitsym.nextoverloaded)]
                 else
                   sym^.nextoverloaded:=NIL;
                 sym^.ReturnType:=UTypTable[longint(unitsym.ReturnType)];
               end;
  _Unit      : ;
  end;
  sym^.attr:=sym^.attr and not s_used; {when loaded symbols are unused!}
end;



procedure LoadStuff;
var
   SymCount : Word;

begin
   for SymCount:=1 to USymCount do
      USymTable[SymCount]:=NewSymbol;
   for SymCount:=1 to UTypCount do
      UTypTable[SymCount]:=NewType;
   for SymCount:=1 to USymCount do
      LoadSym(SymCount);
   for SymCount:=1 to UTypCount do
      LoadTyp(SymCount);
   for SymCount:=1 to USymCount do
      BuildSym(SymCount);
   for SymCount:=1 to UTypCount do
      BuildTyp(SymCount);
end;



procedure LoadUnit(const unitname, current_unit:string);
var
   List : pSymbolList;
   sym  : pSymbolRecord;

begin
  CreateSymbolList(List);
  USymTable[0]:=NIL;
  UTypTable[0]:=NIL;

  assign(unitfile,unitname);
  {$I-}reset(unitfile,1);{$I+}

  if IOResult<>0 then Error('Couldn''t open '+unitname);

  blockread(unitfile, unitstart, sizeof(unitstart));


  if (unitstart.id<>'P32') or (unitstart.version<>UNITVERSION) then
     Error('Not a P32 unit or incorrect unit version');

  USymCount:=unitstart.symbols;
  UTypCount:=unitstart.types;

{$IFDEF UseRLE}
  RLEInit(FALSE);
{$ENDIF}
  LoadStuff;
{$IFDEF UseRLE}
  RLEDone(FALSE);
{$ENDIF}

  close(unitfile);

  list^.first:=USymTable[1];
  BuildList(list);

  sym:=GetSymbolFromList(list, '_'+current_unit);
  if sym<>NIL then
    begin
      sym^.symlist:=list;
      sym^.loaded:=TRUE;
    end;

  AddList(list);
end;

function Recompile(var source, unitfile:text):boolean;

var unittime,
    sourcetime : longint;

begin
  sourcetime:=0;
  unittime:=0;
  GetFTime(unitfile, unittime);
  GetFTime(source, sourcetime);
  if sourcetime < unittime then
    Recompile:=FALSE
  else
    Recompile:=TRUE;
end;
end.


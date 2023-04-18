{                         P32 - 32bit Pascal Compiler                        }
{ -------------------------------------------------------------------------- }
{                       Johan Prins - jprins@knoware.nl                      }
{ ========================================================================== }
{ Code generator for Intel 386 or compatible processors                      }
{                                                   (c) Copyright 1996-1999  }
{                                                                            }
{ -------------------------------------------------------------------------- }

unit P32_code;

interface

uses P32_opt, P32_lopt, P32_scan, P32_symb, P32_asml, P32_tree, P32_asm, P32_prep, P32_err;

type
   cpus = (i386, i486, Pentium, PMMX, PPro, PII, PIII, K6, K7, M2);

const
   exit_label     : integer = 0;

var
   CPU : cpus;

procedure GenerateCode(var p: pTree);
procedure GenCodeMain(var p: pTree);
procedure GenerateCodeUnit(const unitname:string;var p: pTree);
procedure GenCodeProc(sym:pSymbolRecord; var p: pTree);
procedure GenerateHeader;
procedure InitRegisters;
function GetRegisterNormal:regs;

function IsOrdinal(var typ: pTypeRecord): boolean;

implementation

uses DOS;

const
   true_label     : integer = 0;
   false_label    : integer = 0;
   current_label  : integer = 0;
   continue_label : integer = 0;
   break_label    : integer = 0;
   lastreg        : regs = none;

var
   CurrentLevel: longint;

   factor, offset:longint;

   freereg : set of regs;
   protreg : set of regs;

   ordconsttype: pTypeRecord;

   debugline : longint;

   withloc   : location;
   withtable : pSymbolList;

{-------------------------------------------}
{ Register management                       }
{-------------------------------------------}

procedure InitRegisters;

begin
  freereg:=[eax, edx, ecx, ebx, esi, edi];
  protreg:=[];
end;

function GetRegisterNormal:regs;
{returns a free register}
var x : regs;

begin
  if (eax in freereg) and not (eax in protreg) then x:=eax
  else
    if (edx in freereg) and not (edx in protreg) then x:=edx
    else
      if (ecx in freereg) and not (ecx in protreg) then x:=ecx
      else
        if (ebx in freereg) and not (ebx in protreg) then x:=ebx
        else LineError(LineCount, 'Out of registers!');
  freereg:=freereg - [x];
  GetRegisterNormal:=x;
end;

function GetRegisterShuffled:regs;
var x : regs;

begin
  if (eax in freereg) and not (eax in protreg) and ((lastreg=none) or (lastreg=ebx)) then x:=eax
  else
    if (edx in freereg) and not (edx in protreg) and (lastreg=eax) then x:=edx
    else
      if (ecx in freereg) and not (ecx in protreg) and (lastreg=edx) then x:=ecx
      else
        if (ebx in freereg) and not (ebx in protreg) and (lastreg=ecx) then x:=ebx
        else x:=GetRegisterNormal;
  lastreg:=x;
  freereg:=freereg - [x];
  GetRegisterShuffled:=x;
end;

function GetRegister:regs;
begin
  if Options.ShuffleRegisters then
    GetRegister:=GetRegisterShuffled
  else
    GetRegister:=GetRegisterNormal;
end;

function GetRegister32: regs;
{return a 32 bit register}
var i: regs;
begin
  if (eax in freereg) or
     (edx in freereg) or
     (ecx in freereg) or
     (ebx in freereg) then
    i:=GetRegister
  else
    if (edi in freereg) then
      begin
        i:=edi;
        freereg:=freereg - [edi];
      end
    else
      if (esi in freereg) then
        begin
          i:=edi;
          freereg:=freereg - [edi];
        end;
  GetRegister32:=i;
end;

procedure ReleaseRegister(i: regs);
{release the given register so it's available to other variables}
begin
  if not (i in protreg) then
    begin
      if (i in [eax,ebx,ecx,edx,edi,esi]) then
        freereg:=freereg + [i];
    end;
end;

procedure ReleaseLocRegs(var l:location);
{ Release all allocated register in the location-record }
begin
  case l.l of
  register : ReleaseRegister(l.reg);
  port,
  directmem,
  memref   : begin
               ReleaseRegister(l.base);
               ReleaseRegister(l.index);
             end;
  {ordconst -> ignored}
  end;
end;

procedure SetLoc(var l: location; base, idx: regs; offset, factor:longint);
{ Fill the location record with the given values, takes also care of stack
  and local variables.   }
{ ONLY for memref loc's! }

begin
  l.l     := memref;
  ClearLoc(l);
  l.base  := base;
  l.index := idx;
  l.offset:= offset;
  l.factor:= factor;
end;

procedure CheckLevel(var p: pTree);
{
  This procedure is for access to local vars and parameters at a lower lex
  level than the currently executing nested procedure. Lexical levels
  increase the more nested a procedure is.
}
var
  x: regs;
  i, LevelDiff: longint;
  loc: location;

begin
  LevelDiff := CurrentLevel - p^.sym^.vLevel;
  if LevelDiff > 0 then
  {
    Yes, this is an interlevel access.  We cannot just index off our ebp,
    we need to index off the stack frame of that procedure.  To do that,
    we travel up the level levels through the lexical parent link, just
    above the return address (EBP+8)...
  }
  begin
    {
      Basically, to access intermediate variables we must make sure we are
      using the right stack frame.  Each procedure needs EBP for its own
      vars, so we now get the desired stack frame in a different register,
      which becomes the new base for variables from that lex level.
    }
    SetLoc(loc, ebp, none, 8, 0);
    case p^.sym^.VarType of
      _Local    : begin
                    x := GetRegister32;
                    emit_reg_loc(_mov_, _dword, x, _dword, loc); { get parent stack frame }
                    if LevelDiff > 1 then
                      for i := 2 to LevelDiff do
                         begin
                           loc.base:=x;
                           emit_reg_loc(_mov_, _dword, x, _dword, loc);
                         end;
                    p^.loc.base := x;
                  end;
      _ParmValue: begin
                    x := GetRegister32;
                    emit_reg_loc(_mov_, _dword, x, _dword, loc); { get parent stack frame }
                    if LevelDiff > 1 then
                      for i := 2 to LevelDiff do
                         begin
                           loc.base:=x;
                           emit_reg_loc(_mov_, _dword, x, _dword, loc);
                         end;
                    p^.loc.base := x;
                  end;
      _ParmConst,
      _ParmVar  : begin
                    x:=GetRegister32;
                    emit_reg_loc(_mov_, _dword, x, _dword, loc); { get parent stack frame }
                    if LevelDiff > 1 then
                      for i := 2 to LevelDiff do
                         begin
                           loc.base:=x;
                           emit_reg_loc(_mov_, _dword, x, _dword, loc);
                         end;
                    SetLoc(loc, x, none, p^.sym^.offset, 0);
                    emit_reg_loc(_mov_, _dword, x, _dword, loc);
                    p^.loc.base := x;
                  end
    else
      begin
        { eg. Global variables; Do nothing }
      end;
    end;
  end;
end;

procedure Fill_Loc(var l: location;var sym:pSymbolrecord; base, idx: regs; offset, factor:longint);
{ Fill the location record with the given values, takes also care of stack
  and local variables.}

var x: regs;

begin
  case sym^.VarType of
  _Global    : begin
                 l.base  := base;
                 l.index := idx;
                 l.offset:= offset;
                 l.factor:= factor;
               end;
   _Local    : begin
                 l.base  := ebp; {always the stackpointer}
                 l.index := idx;
                 l.offset:= offset - sym^.offset;
                 l.factor:= factor;
               end;
   _ParmValue: begin
                 l.base  := ebp; {always the stackpointer}
                 l.index := idx;
                 l.offset:= offset + sym^.offset;
                 l.factor:= factor;
               end;
   _ParmConst,
   _ParmVar  : begin
                 if asmmode then
                   begin
                     l.base  := ebp;
                     l.index := idx;
                     l.offset:= offset + sym^.offset;
                     l.factor:= factor;
                   end
                 else
                   begin
                     x:=GetRegister32;
                     l.base:=ebp;
                     l.offset:=sym^.offset;
                     emit_reg_loc(_mov_, _dword, x, _dword, l);
                     l.base  := x;
                     l.index := idx;
                     l.offset:= offset;
                     l.factor:= factor;
                   end;
               end;
   _ObjField : begin
                 l.base  := esi; {always the stackpointer}
                 l.index := idx;
                 l.offset:= offset + sym^.offset;
                 l.factor:= factor;
               end;
   _RegVar   : begin
                 l.l:=register;
                 l.reg:=regs(sym^.r);
                 if sym^.name='csevar' then
                   begin
                     l.reg:=pTree(sym^.orgnode)^.csereg
                   end;
                 protreg := protreg + [l.reg];
                 freereg := freereg - [l.reg];
               end;
   else        Error('[fill_loc] -> invalid identifier');
   end;
end;

procedure EmitPublic(const s: string);

begin
  WriteLn(Incl^, asdef.global + ' '+ s);
end;

procedure EmitExtern(const s: string);

begin
  WriteLn(Incl^, asdef.extern + s + asdef.extern2)
end;

function DivByTwo(n:longint):integer;
var tmp:longint;
      i:integer;

begin
  DivByTwo:=0;
  for i:=30 downto 1 do { 30 due to bit 31 being signed bit }
    begin
      tmp := 1 shl longint(i);
      if (n mod tmp = 0) then { No rest means that it is possible to divide! (split) }
        begin
          DivByTwo:=i;
          exit;
        end;
    end;
end;

function PowerOfTwo(n:longint):integer;
var tmp:longint;
      i:integer;
begin
  PowerOfTwo:=0;
  tmp:=1;
  for i:=30 downto 1 do { 30 due to bit 31 being signed bit }
    begin
      if tmp=n then
        begin
          PowerOfTwo:=30-i;
          exit;
        end;
      tmp := tmp shl 1;
    end;
end;


procedure EmitConstMultiply(i:regs; n:longint);

Type
 MulCodes = (____shl,____mov,____lea,____add,____sub,____imulmin,____imulmax);
{ __add was already taken, so I took an extra two __'s in front.. anyone mind? }

Const
 Timing:Array[i386..K6, MulCodes] of word = (
      { i386, i486, Pentium }
      { shl } { mov } { lea } { add } { sub } { imulmin } { imulmax }
{386} (  3,      2,      2,      2,      2,        9,         38 ),
{486} (  2,      1,      2,      1,      1,       11,         48 ),
{Pent}(  1,      1,      1,      1,      1,       10,         10 ),
{PMMX}(  1,      1,      1,      1,      1,       10,         10 ),
{PPro}(  1,      1,      1,      1,      1,        1,          2 ),
{PII} (  1,      1,      1,      1,      1,        1,          2 ),
{PIII}(  1,      1,      1,      1,      1,        1,          2 ),
{K6}  (  1,      1,      1,      1,      1,        2,          2 ));

var x, o    : longint;
    maxcycles,
    cycles  : integer;
    loc     : location;
    push_edi: boolean;

begin
  if not (edi in freereg) then
    begin
      push_edi := TRUE;
      emit_reg(_push_, _dword, edi); { push edi }
    end
  else
    push_edi := FALSE;

  {this routine calculates the total amount of cycles that's needed when
   using the optimized multiplies, doesn't emit _any_ code.
   Calculations based on multiply-routines, below }
  MaxCycles := (Timing[CPU][____imulmin] +
                Timing[CPU][____imulmax]) shr 1;
  o := n;
  cycles := 0;                       { counter for cpu-cycles }

  while (o > 1) do        { if o is negative, keep away from optimizing }
    begin
      x := DivByTwo(o);
      case x of
      0 :  begin
             if (o mod 13 = 0) then
               begin
                 o := o div 13;
                 If (CPU = Pentium) then
                  { All goes down U pipe... }
                  Cycles := Cycles + Timing[CPU][____mov] +
                                     Timing[CPU][____shl] +
                                     Timing[CPU][____lea] +
                                     Timing[CPU][____add];
               end
             else
               if (o mod 11 = 0) then
                 begin
                   { All goes down U pipe... }
                   Cycles := Cycles + Timing[CPU][____mov] +
                                      Timing[CPU][____shl] +
                                      Timing[CPU][____lea] +
                                      Timing[CPU][____add];
                   o := o div 11;
                 end
               else
                 if (o mod 9 = 0) then
                   begin
                     Cycles := Cycles + Timing[CPU][____lea]; { U Pipe }
                     o := o div 9;
                   end
                 else
                   if (o mod 7 = 0) then
                     begin
                       { All goes down U pipe... }
                       Cycles := Cycles + Timing[CPU][____mov] +
                                          Timing[CPU][____shl] +
                                          Timing[CPU][____sub];

                       o := o div 7;
                     end
                   else
                     if (o mod 5 = 0) then
                       begin
                         Cycles := Cycles + Timing[CPU][____lea]; { U Pipe }
                         o := o div 5;
                       end
                     else
                       if (o mod 3 = 0) then
                         begin
                           Cycles := Cycles + Timing[CPU][____lea]; { U Pipe }
                           o := o div 3;
                         end
                       else
                         begin
                          Cycles := MaxCycles;
                          break;    { No more optimizing possible }
                         end;

           end;
      1 :  begin
             o := o div 2;          { *2 }
             Cycles := Cycles + Timing[CPU][____add]; { U Pipe }
           end;
      else begin
             Cycles := Cycles + Timing[CPU][____shl]; { U Pipe }
             o := o div (1 shl x);  { *2^x }
           end;
      end;
    end;

{ Ok, now we are going to take a look at this optimized code...
  if (Cycles > imulmax) then no_optimize;
  Pentium uses 10 Cycles, AMD K6 seems to use the 486 mul speed ...
  Dunno why... but it seems so ... If this is right, then this
  optimization engine will ROCK on a K6!
}

  if (o = 1) and (cycles < MaxCycles) then
    while (n > 1) do        { Don't optimize if n is negative }
      begin                  { Ignore if n is 1 }
        x := DivByTwo(n);
        case x of
        0  : begin
               if (n mod 13 = 0) then
                 begin
                   emit_reg_reg(_mov_, _dword, edi, _dword, i);
                   emit_reg_ord(_shl_, _dword, i, 2); { *4}
                   SetLoc(loc, i, i, 0, 2);
                   emit_reg_loc(_lea_, _dword, i, _nothing, loc);
                   emit_reg_reg(_add_, _dword, i, _dword, edi);
                   n := n div 13;
                 end
               else
                 if (n mod 11 = 0) then
                   begin
                     emit_reg_reg(_mov_, _dword, edi, _dword, i);
                     emit_reg_ord(_shl_, _dword, i, 1);
                     SetLoc(loc, i, i, 0, 4);
                     emit_reg_loc(_lea_, _dword, i, _nothing, loc);
                     emit_reg_reg(_add_, _dword, i, _dword, edi);
                     n := n div 11;
                   end
                 else
                   if (n mod 9 = 0) then
                     begin
                       SetLoc(loc, i, i, 0, 8);
                       emit_reg_loc(_lea_, _dword, i, _nothing, loc);
                       n := n div 9;
                     end
                   else
                     if (n mod 7 = 0) then
                       begin
                         emit_reg_reg(_mov_, _dword, edi, _dword, i);
                         emit_reg_ord(_shl_, _dword, i, 3);           { * 8 }
                         emit_reg_reg(_sub_, _dword, i, _dword, edi); { - 1 = 7 }
                         n := n div 7;
                       end
                     else
                       if (n mod 5 = 0) then
                         begin
                           SetLoc(loc, i, i, 0, 4);
                           emit_reg_loc(_lea_, _dword, i, _nothing, loc);
                           n := n div 5;
                         end
                       else
                         if (n mod 3 = 0) then
                           begin
                             SetLoc(loc, i, i, 0, 2);
                             emit_reg_loc(_lea_, _dword, i, _nothing, loc);
                             n := n div 3;
                           end
                         else
                           begin
                             emit_reg_ord(_imul_, _dword, i, n);
                             n := 1;              { Can't optimize it more! }
                           end;
             end;
        1 :  begin
               emit_reg_reg(_add_, _dword, i, _dword, i); { *2 }
               n := n div 2;
             end;
        else begin
               emit_reg_ord(_shl_, _dword, i, x);         { *2^x }
               n := n div (1 shl x);
             end;
        end;
      end
  else
    emit_reg_ord(_imul_, _dword, i, n);        { Cant be opimized a tad! }

  if push_edi then
    emit_reg(_pop_, _dword, edi); {restore edi}

{$IFDEF DEBUG}
 WriteLn('MUL Optimization engine, Cycles = ',Cycles,' Saved = ',MaxCycles-Cycles);
{$ENDIF}
end;

procedure EmitPortIn(i:regs; typ:pTypeRecord; l: location);
var
  eax_pushed,
  edx_pushed: boolean;

begin
  eax_pushed:=FALSE;
  edx_pushed:=FALSE;

  {AL/AX needed for input}
  if (i<>eax) then 
    begin
      if not (eax in freereg) then 
        begin
          emit_reg(_push_, _dword, eax);
          eax_pushed := TRUE;
        end;
    end;

  {DL/DX needed to store port number}

  if not (edx in freereg) and (i<>edx) then
    begin
      emit_reg(_push_, _dword, edx);
      edx_pushed := TRUE;
    end;

  if (l.offset<256) and (l.base=none) and (l.index=none) then
    emit_reg_ord(_in_, GetSize(typ), eax, l.offset)
  else
    begin
      if (l.base<>none) and (l.index<>none) then
        emit_reg_loc(_mov_, _dword, edx, _dword, l)
      else
        begin
          if (l.index<>none) then 
            emit_reg_reg(_mov_, _dword, edx, _dword, l.index)
          else 
            emit_reg_ord(_mov_, _dword, edx, l.offset);
        end;
        emit_reg_reg(_in_, GetSize(typ), eax, _word, edx)
    end;

  case typ^.subrangetyp of
  u8bit : emit_reg_ord(_and_, _dword, eax, $FF);
  u16bit: emit_reg_ord(_and_, _dword, eax, $FFFF);
  s8bit,
  s16bit: emit_reg_reg(_movsx_, _dword, eax, GetSize(typ), i)
  end;
  if (i<>eax) then emit_reg_reg(_mov_, _dword, i, _dword, eax);
  if edx_pushed then emit_reg(_pop_, _dword, edx);
  if eax_pushed then emit_reg(_pop_, _dword, eax);
end;

procedure EmitIntegerLoad(i:regs; typ:pTypeRecord; l:location);
begin
  if l.l = port then
    EmitPortIn(i, typ, l)
  else
    case typ^.typedef of
    _BooleanDef,
    _SubRangeDef  : case typ^.subrangetyp of
                    uchar,
                    u8bit,
                    u16bit: {begin
                              emit_reg_reg(_xor_, _dword, i, _dword, i);
                              emit_reg_loc(_mov_, GetSize(typ), i, GetSize(typ), l);
                            end;}
                            emit_reg_loc(_movzx_, _dword, i, GetSize(typ), l);
                    s8bit,
                    s16bit: emit_reg_loc(_movsx_, _dword, i, GetSize(typ), l);
                    u32bit,
                    s32bit: emit_reg_loc(_mov_, _dword, i, _dword, l);
                    end;
    _EnumeratedDef,
    _PointerDef   : emit_reg_loc(_mov_, _dword, i, _dword, l);
    else            Error('EmitIntegerLoad: cannot load variable ('+Numb(LineCount)+')');
    end;
end;

procedure EmitIntegerAdd(var left, right:location; typ:pTypeRecord);
var size: integer;
       i: regs;
begin
  size:=GetSize(typ);
  case right.l of
  port     : begin
               i:=GetRegister;
               EmitPortIn(i, typ, right);
               emit_reg_reg(_add_, size, left.reg, size, i);
               ReleaseRegister(i);
               ReleaseLocRegs(right);
             end;
  ordconst : begin
               if right.value=1 then
                 emit_reg(_inc_, size, left.reg)
               else
                 emit_reg_ord(_add_, _dword, left.reg, right.value);
             end;
  register : begin
               emit_reg_reg(_add_, size, left.reg, size, right.reg);
               ReleaseLocRegs(right);
             end;
  else
             begin
               if size<>4 then
                 begin
                   ReleaseLocRegs(right);
                   i:=GetRegister32;
                   EmitIntegerLoad(i, typ, right);
                   emit_reg_reg(_add_, _dword, left.reg, _dword, i);
                   ReleaseRegister(i);
                 end
               else
                 begin
                   emit_reg_loc(_add_, size, left.reg, size, right);
                   ReleaseLocRegs(right);
                 end;
             end;
  end;
end;

procedure EmitPushAddress(var l:location);
var i: regs;
begin
  if (l.base=none) and (l.index=none) then
    emit_loc(_push_, _offset, l)
  else
    if (l.base=none) and (l.index<>none) and (l.offset=0) and (l.factor=1) and {(l.name=NIL)}(l.name='') then
      emit_reg(_push_, _dword, l.index)
    else
      if (l.base<>none) and (l.index=none) and (l.offset=0)  and (l.factor=1) and {(l.name=NIL)}(l.name='') then
        emit_reg(_push_, _dword, l.base)
      else
        begin
          i:=GetRegister32;
          emit_reg_loc(_lea_, _dword, i, _nothing, l);
          emit_reg(_push_, _dword, i);
          ReleaseRegister(i);
        end;
end;

procedure EmitPushRegister(var typ: pTypeRecord; var l:location);
var size: integer;
begin
  size:=GetSize(typ);
  case typ^.typedef of
  _SubRangeDef   : case size of
                   1,2,4: emit_reg(_push_, _dword{size}, l.reg);
                   else Error('invalid register size');
                   end;
  _PointerDef,
  _EnumeratedDef : emit_reg(_push_, size, l.reg);
  else Error('EmitPushRegister: unsupported type');
  end;
end;

procedure EmitPushMemory(var typ: pTypeRecord; l:location);
var size: integer;
       i: regs;
begin
  size:=GetSize(typ);
  i:=GetRegister32;
  case typ^.typedef of
  _BooleanDef,
  _SubRangeDef   : case size of
                   1, 2: begin
                           EmitIntegerLoad(i, typ, l);
                           emit_reg(_push_, _dword, i);
                         end;
                   4   : emit_loc(_push_, size, l);
                   else Error('invalid immediate');
                   end;
  _RealDef       : begin
                     if size<>8 then
                       begin
                         emit_loc(_fld_, size, l);
                         emit_reg_ord(_sub_, _dword, esp, 8);
                         SetLoc(l, esp, none, 0,0);
                         emit_loc(_fstp_, _qword, l);
                         inc(l.offset, 4);
                         emit_loc(_push_, _dword, l);
                         emit_loc(_push_, _dword, l);
                       end
                     else
                       begin
                         inc(l.offset,4);
                         emit_loc(_push_, _dword, l);
                         dec(l.offset,4);
                         emit_loc(_push_, _dword, l);
                       end;
                   end;
  _PointerDef,
  _EnumeratedDef : emit_loc(_push_, _dword, l);
  else Error('EmitPushMemory: unsupported type');
  end;
  ReleaseRegister(i);
end;


procedure EmitPushImmediate(n:longint);

begin
  emit_ord(_push_, _dword, n);
end;

procedure EmitStringCopy(var dest, src:location; length:longint);

begin
  emit_ord(_push_, _dword, length);
  EmitPushAddress(src);
  EmitPushAddress(dest);
  GetSymbol('_SYS_STRCOPY'); {check to set used bit}
  emit_lab(_call_, _nothing, 'strcopy');
end;

procedure EmitStringCompare(var left, right:location);

begin
  EmitPushAddress(right);
  EmitPushAddress(left);
  GetSymbol('_SYS_STRCMP'); {check to set used bit}
  emit_lab(_call_, _nothing,'strcmp');
end;

procedure EmitStringAdd(var left, right:location);

begin
  EmitPushAddress(right);
  EmitPushAddress(left);
  GetSymbol('_SYS_STRCAT'); {check to set used bit}
  emit_lab(_call_, _nothing,'strcat');
end;

procedure EmitMemMem(size:longint; loc_left, loc_right: location);
{copy value in memory to other memory location}

var
   i: regs;
   push_ecx: boolean;

begin
  if size <= 4 then
    begin
{!!!} ReleaseLocRegs(loc_right); {these can be released...can be useful as target (i) register}
      i:=GetRegister;
      repeat
        emit_reg_loc(_mov_, size, i, size, loc_right);
        emit_loc_reg(_mov_, size, loc_left, size, i);
        inc(loc_left.offset, 4);
        inc(loc_right.offset, 4);
        dec(size, 4);
      until size<=0;
      ReleaseLocRegs(loc_left);  {release them...not needed anymore!}
      ReleaseRegister(i);
    end
  else
    begin
      if not (edi in freereg) then emit_reg(_push_, _dword, edi);
      if not (esi in freereg) then emit_reg(_push_, _dword, esi);
      emit_reg_loc(_lea_, _dword, esi, _nothing, loc_right);
      emit_reg_loc(_lea_, _dword, edi, _nothing, loc_left);
      if ecx in freereg then push_ecx:=false  {ecx needed for counter}
                        else begin
                               emit_reg(_push_, _dword, ecx);
                               push_ecx:=true;
                             end;
      emit_non(_cld_);
      emit_reg_ord(_mov_, _dword, ecx, size);
      emit_lab(_rep_, _nothing,'movsb'); {hack to allow an instruction as option}
      if push_ecx then emit_reg(_pop_, _dword, ecx);
      if not (esi in freereg) then emit_reg(_push_, _dword, edi);
      if not (edi in freereg) then emit_reg(_push_, _dword, esi);
    end;
end;

{-------------------------------------------}
{ Writing symbols                           }
{-------------------------------------------}

procedure DumpSymbols;
var
   p   : pTypeRecord;
   old, sym : pSymbolRecord;
   i : integer;
   name:string;
   xsize,
   size:longint;
   attr: integer;
   list: pSymbols;

begin
   writeln(Dest^, ';--- Global variables, uninitialized');
   writeln(Dest^);
   WriteLn(Dest^, asdef.udataseg);
   WriteLn(Dest^, asdef.align);
   writeln(Dest^);
   list:=firstlist;
   while list<>nil do
   begin
   sym:=NIL;
   if list^.list<>NIL then sym:=list^.list^.first;
   {if sym=NIL then break;}
   while (sym <> NIL) do
   begin
     case sym^.Symbol of
     _Proc,
     _Func    : begin
                  old:=sym;
                  while sym<>NIL do
                  begin
                    name:=sym^.overloadedname;
                    if (sym^.internal=no) and
                       ((sym^.prop and p_inline)=0) and
                       ((sym^.attr and s_used)<>0) then
                      begin
                        attr:=sym^.attr and (s_public+s_extern);
                        case attr of
                        s_extern: EmitExtern(name);
                        s_public: begin
                                    EmitPublic(name);
                                    attr := (attr and not s_public) or s_extern;
                                  end;
                        end;
                        sym^.attr:=attr;
                      end;
                    sym:=sym^.nextoverloaded;
                  end;
                  sym:=old;
                end;
     _Constant,
     _Type:     attr := attr and not s_public;
     _Variable: begin
                  if sym^.typedconst then name:=TCPrefix+sym^.overloadedname
                                     else name:=sym^.overloadedname;
                  if (sym^.alias = NIL) and
                     (not sym^.absreference) {and
                     (sym^.typedconst=FALSE)} then
                    begin
                      attr:=sym^.attr;
                      if (attr and (s_vardmp+s_varext) = 0) then
                        begin
                          if (sym^.attr and s_used)=0 then Hint(LineCount, 'variable ('+name+') not used');
                          p:=sym^.typedef;
                          if (p<>NIL) and not sym^.typedconst then
                            begin
                              size:=GetSize(p);
                              if (p^.typedef=_StringDef) and Options.AlignStrings then
                                begin
                                  writeln(Dest^,'PRE'+name, TAB, asdef.valdata1, TAB, Options.AlignData-1, TAB,asdef.valdata2);
                                  xsize:=size+Options.AlignData-1;
                                end
                              else
                                xsize:=size;
                              Writeln(Dest^, name, TAB, asdef.valdata1, TAB, size, TAB, asdef.valdata2);
                              xsize:=xsize and (Options.AlignData-1);
                              if xsize<>0 then
                                xsize:=Options.AlignData - xsize;
                              if xsize<>0 then
                                Writeln(Dest^,'ALIGN'+name,TAB, asdef.valdata1,TAB, xsize,TAB,asdef.valdata2);
                            end;
                          attr:=attr or s_vardmp;
                        end;
                      case (sym^.attr and (s_public+s_extern+s_vardmp+s_varext)) of
                      s_varext : if (sym^.attr and s_used)<>0 then EmitExtern(name);
                      s_vardmp +
                      s_extern : if (sym^.attr and s_used)<>0 then EmitExtern(name);
                      s_public : begin
                                   EmitPublic(name);
                                   attr := (attr and not s_public) or s_extern;
                                 end;
                      s_public +
                      s_extern +
                      s_vardmp : begin
                                   if (sym^.attr and s_used)<>0 then EmitExtern(name);
                                   attr := attr xor s_public;
                                 end;
                      end;
                      sym^.attr:=attr;
                    end;
                end;
     end;
     sym:=sym^.next;
    end;
    list:=list^.next;
    end;
end;

procedure DumpConstants;

var

    size, i, j: integer;
    con: pConstantRecord;
    tmp, encodednr:string;
    r :record {simulated longint}
           hi, lo:word;
         end;
begin
   writeln(Dest^, ';--- Global variables, initialized');
   writeln(Dest^);
   WriteLn(Dest^, asdef.dataseg);
   WriteLn(Dest^, asdef.align);
   writeln(Dest^);
   con:=ConstantTable.first;
   while con <> NIL do
   begin
     if con^.dumped=FALSE then
     case con^.c of
     _VMTConst:     begin
                      tmp:=con^.s^;
                        write(dest^, TAB, 'DD', TAB + asdef.offset + TAB, tmp);
                      writeln(dest^);
                    end;
     _StringConst:  begin
                      tmp:=con^.s^;
                      j:=length(tmp);
                      if (con^.prev<>NIL) and (con^.prev^.id^=con^.id^) then {don't emit the constant-name}
                        write(dest^, TAB, asdef.decldata, TAB, j)
                      else
                        begin

                          if Options.AlignStrings then
                            begin
                              write(dest^, 'PRE'+con^.id^, TAB, asdef.decldata, TAB);
                              for i:=1 to Options.AlignData-2 do write(dest^, '0, ');
                              writeln(dest^, '0');
                            end;
                          write(dest^, con^.id^, TAB, asdef.decldata, TAB, j);
                        end;
                      for i := 1 to j do
                        write(dest^, ', '+Numb(byte(tmp[i])));

                      for i := (j+1) to con^.size do
                        write(dest^, ', 0');
                      writeln(dest^);
                    end;
     _PCharConst:   begin
                      tmp:=con^.s^;
                      j:=length(tmp);
                      if (con^.prev<>NIL) and (con^.prev^.id^=con^.id^) then {don't emit the constant-name}
                        write(dest^, TAB, asdef.decldata, TAB, Numb(byte(tmp[j])))
                      else
                        write(dest^, con^.id^, TAB, asdef.decldata, TAB, Numb(byte(tmp[j])));

                      for i := 2 to j do
                        write(dest^, ', '+Numb(byte(tmp[i])));

                      for i := (j+1) to con^.size do
                        write(dest^, ', 0');

                      write(dest^, ', 0');
                      writeln(dest^);
                    end;
     _OrdinalConst,
     _IntegerConst: begin
                      case con^.size of
                      1: encodednr:=Numb(con^.n);
                      2: encodednr:=Numb(lo(con^.n))+', '+Numb(hi(con^.n));
                      4: begin
                           longint(r):=longint(con^.n);
                           encodednr:=Numb(lo(r.hi))+', '+Numb(hi(r.hi))+', '+Numb(lo(r.lo))+', '+Numb(hi(r.lo));
                         end;
                      end;
                      if (con^.prev<>NIL) and (con^.prev^.id^=con^.id^) then {don't emit the constant-name}
                        write(dest^, TAB, asdef.decldata, TAB, encodednr)
                      else
                        write(dest^, con^.id^, TAB, asdef.decldata, TAB, encodednr);
                      WriteLn(dest^);
                    end;
     _RealConst: begin
                   str(con^.d, encodednr);
                   if (con^.prev<>NIL) and (con^.prev^.id^=con^.id^) then {don't emit the constant-name}
                     write(dest^, TAB, asdef.floatdata, TAB, encodednr)
                   else
                     write(dest^, con^.id^, TAB, asdef.floatdata, TAB, encodednr);
                   WriteLn(dest^);
                 end;
     end;
     {alignment}
     if con^.dumped=FALSE then
       begin
         if (con<>NIL) and (con^.next<>NIL) then
         if con^.id^<>con^.next^.id^ then {don't emit alignments when constant is an array}
           begin
             if con^.c = _StringConst then size:=(con^.size+1) and (Options.AlignData-1)
                                      else size:=con^.size and (Options.AlignData-1);
             if size<>0 then size:=Options.AlignData - size;
             if size <> 0 then
               Writeln(Dest^, 'ALIGN_'+con^.id^, TAB, asdef.valdata1, TAB, size,TAB, asdef.valdata2);
           end;
       end;
     con^.dumped:=TRUE;
     con:=con^.next;
   end;
   Writeln(Dest^);
end;

function LabelString(s: integer):string;
begin
  LabelString:='L'+Numb(s);
end;

procedure PutLabel(l: integer);
begin
  emit_label(LabelString(l));
end;

function  NewLabel: integer;

begin
  inc(LabelCount);
  NewLabel:=LabelCount;
end;

function DoCheck(var p:pTree):TypeDefinition;

begin
  case p^.op of {if we have a constant then set the types manually}
  __ordconst,
  __charconst  : DoCheck:=_SubRangeDef;
  __stringconst: DoCheck:=_StringDef;
  __realconst  : DoCheck:=_RealDef;
  __var        : DoCheck:=GetType(p^.sym^.typedef);
  __field      : DoCheck:=GetType(p^.sym_field^.typedef);
  __index      : DoCheck:=GetType(p^.left^.sym^.typedef);
  __call       : DoCheck:=GetType(p^.sym^.returntype);
  __ptr        : DoCheck:=GetType(p^.left^.sym^.typedef^.PointerTo^.typedef);
  __address    : DoCheck:=_PointerDef;
  else           DoCheck:=_EmptyDef;
  end;
end;


{---------------------------------------------------------------------------}

procedure DoLoadOrdConst(var p : ptree);

begin
  p^.loc.l:=ordconst;
  p^.loc.value:=p^.n;
end;

procedure DoLoadCharConst(var p : ptree);

begin
  p^.loc.l:=ordconst;
  p^.loc.value:=ord(p^.c);
end;

procedure DoLoadStrConst(var p : ptree);

var con: pConstantRecord;

begin
  if p^.s<>NIL then
    begin
      con:=NewConstant;
      con^.size:=length(p^.s^);
      con^.c:=_StringConst;
      con^.s:=getmemstring(p^.s^);
      con^.id := NIL;
      con^.dumped:=FALSE;
      con^.id := AddConstant(ConstantTable, con, TRUE); {add name to list of constants}
      p^.loc.name:={getmemstring(}con^.id^{)}; {store name in location record}
    end;
end;

procedure DoLoadPCharConst(var p : ptree);

var con: pConstantRecord;
      i: regs;
begin
  if p^.s<>NIL then
    begin
      con:=NewConstant;
      con^.size:=length(p^.s^);
      con^.c:=_PCharConst;
      con^.s:=getmemstring(p^.s^);
      con^.id := NIL;
      con^.dumped:=FALSE;
      con^.id := AddConstant(ConstantTable, con, TRUE); {add name to list of constants}
    end;
  p^.loc.name:={getmemstring(}con^.id^{)}; {store name in location record}
  i:=GetRegister32;
  emit_reg_loc(_mov_, _dword, i, _offset, p^.loc);
  p^.loc.l:=register;
  p^.loc.reg:=i;
end;


function AddRealConstant(d: double):string;

var con: pConstantRecord;

begin
  con:=NewConstant;
  con^.c:=_RealConst;
  con^.size:=8{length(con^.s)};
  con^.d:=d;
  con^.id := NIL;
  con^.dumped:=FALSE;
  con^.id := AddConstant(ConstantTable, con, TRUE); {add name to list of constants}
  AddRealConstant:=con^.id^; {store name in location record}
end;

procedure DoLoadRealConst(var p : ptree);

begin
  emit_lab(_fld_, _qword, '['+AddRealConstant(p^.d)+']');
  p^.loc.l:=fpu;
end;

procedure DoNil(var p : ptree);

begin
  p^.loc.l:=ordconst;
  p^.loc.value:=0;
end;

procedure DoLoadSetConst(var p : ptree);

var
   i   :integer;
   loc1, loc2: location;
   typ : pTypeRecord;
   c   : pConstantRecord;
   s   : string;
   t   : pTree;

begin
  s:=LabelString(NewLabel);
  for i:=0 to 31 do
    begin;
      c:=NewConstant;
      c^.c     := _OrdinalConst;
      c^.size  := 1;
      c^.n     := p^.cset^[i];
      c^.id    := getmemstring(s);
      c^.dumped:= FALSE;
      AddConstant(ConstantTable, c, TRUE);
    end;
  t:=p^.left;
  if t <> NIL then
    begin
      inc(stacksize, 32);
      SetLoc(loc1, ebp, none, -stacksize, 0);
    end;
end;


procedure DoIndex(var p: pTree); {arrays}

var
   i      : regs;
   factor : longint;

begin
  GenerateCode(p^.left);

  p^.loc:=p^.left^.loc;

  if (p^.left^.return^.typedef=_ArrayDef) then
    dec(p^.loc.offset, GetSize(p^.left^.return^.definition)* p^.left^.return^.range^.lowerlimit);


  case p^.right^.op of
  {this code could also be integrated in the else-block, it's here however
   and it's not doing any harm here, actually it's working code! -JP      }
  __ordconst : begin
                 if (p^.left^.return^.range^.lowerlimit<>0) or
                    (p^.left^.return^.range^.upperlimit<>0) then
                   begin
                     if (p^.right^.n < p^.left^.return^.range^.lowerlimit) or
                        (p^.right^.n > p^.left^.return^.range^.upperlimit) then LineError(p^.line, 'Constant out of range');
                     inc(p^.loc.offset, p^.right^.n * GetSize(p^.return));
                   end
                 else {hack to allow mem-array to increment by 1}
                   inc(p^.loc.offset, p^.right^.n);
                 p^.left^.return:=p^.return; {change the return type}
               end
  else
               begin
                 if not (p^.loc.l in [port, memref, directmem]) then
                   LineError(p^.line, 'Error in expression (array)');

                 GenerateCode(p^.right); {generate code for index}
                 i:=none;
                 case p^.right^.loc.l of
                 ordconst : begin
                              if (p^.left^.return^.range^.lowerlimit<>0) or
                                 (p^.left^.return^.range^.upperlimit<>0) then
                                begin
                                  if (p^.right^.loc.value < p^.left^.return^.range^.lowerlimit) or
                                     (p^.right^.loc.value > p^.left^.return^.range^.upperlimit) then
                                    LineError(p^.line, 'Constant out of range')
                                  else
                                    inc(p^.loc.offset, p^.right^.loc.value * GetSize(p^.return));
                                end
                              else
                                inc(p^.loc.offset, p^.right^.loc.value);
                            end;
                 register : i := p^.right^.loc.reg;
                 else       begin
                              ReleaseLocRegs(p^.right^.loc);
                              i:=GetRegister;
                              EmitIntegerLoad(i, p^.right^.return, p^.right^.loc);
                             end;
                 end;
                 if i<>none then
                 if (p^.loc.index=none) then {we can use a index register, if it's empty}
                   begin
                     p^.loc.index:=i;
                     factor:=GetSize(p^.return);
                     case factor of
                     1,2,4,8: p^.loc.factor:=factor;
                     else     EmitConstMultiply(i, factor);
                     end;
                   end
                 else
                   begin
                     if p^.loc.base=none then {we can use the base register, if it's empty}
                       begin
                         factor:=GetSize(p^.return);
                         case factor of
                         1,2,4,8: p^.loc.factor:=factor;
                         else     EmitConstMultiply(i, factor);
                         end;
                         p^.loc.base:=p^.loc.index;
                         p^.loc.index:=i;
                       end
                   else
                     begin
                       emit_reg_loc(_lea_, _dword, p^.loc.index, _nothing, p^.loc);
                       ReleaseRegister(p^.loc.base);
                       {p^.loc.name:=NIL;}
                       p^.loc.name:='';
                       p^.loc.offset:=0;
                       factor:=GetSize(p^.return);
                       case factor of
                       1,2,4,8: p^.loc.factor:=factor;
                       else     EmitConstMultiply(i, factor);
                       end;
                       p^.loc.base:=p^.loc.index;
                       p^.loc.index:=i;
                     end;
                   end;
                   {hack to allow mem-array to increment by 1}
                   if (p^.left^.return^.range^.lowerlimit=0) and
                      (p^.left^.return^.range^.upperlimit=0) and
                      (p^.loc.l=directmem) then p^.loc.factor:=1;
           end;
  end;
end;

procedure DoAddress(var p: pTree);
var i: regs;
begin
  GenerateCode(p^.left);
  i:=GetRegister32;
  if (p^.left^.loc.base=none) and (p^.left^.loc.index=none) then
    emit_reg_loc(_mov_, _dword, i, _offset, p^.left^.loc)
  else
    emit_reg_loc(_lea_, _dword, i, _nothing, p^.left^.loc);
  ReleaseLocRegs(p^.left^.loc);
  p^.loc.l:=register;
  p^.loc.reg:=i;
end;

procedure DoPtr(var p: pTree);

begin
  GenerateCode(p^.left);
  ClearLoc(p^.loc);    {clear the location of the variable}
  case p^.left^.loc.l of
  register     : p^.loc.base:=p^.left^.loc.reg; {it's already in a register, use it!}
  else           begin
                   ReleaseLocRegs(p^.left^.loc); {put pointer in a variable}
                   p^.loc.base:=GetRegister32;
                   emit_reg_loc(_mov_, _dword, p^.loc.base, _dword, p^.left^.loc); {always 32 bit}
                end;
  end;
end;

procedure DoField(var p: pTree);

begin
  GenerateCode(p^.left);

  p^.loc:=p^.left^.loc;

  inc(p^.loc.offset, p^.sym_field^.offset); {add to offset of previous variable}

end;

procedure DoTypeConversion(var p : ptree);

type
   convtype=
      (      invalid,         equal,  s8bit_s16bit,  s8bit_s32bit,
        s8bit_u16bit,  s8bit_u32bit,  s16bit_s8bit, s16bit_s32bit,
        s16bit_u8bit, s16bit_u32bit,  s32bit_s8bit, s32bit_s16bit,
        s32bit_u8bit, s32bit_u16bit,  u8bit_s16bit,  u8bit_s32bit,
        u8bit_u16bit,  u8bit_u32bit,  u16bit_s8bit, u16bit_s32bit,
        u16bit_u8bit, u16bit_u32bit,  u32bit_s8bit, u32bit_s16bit,
        u32bit_u8bit, u32bit_u16bit,   s8bit_uchar,  s16bit_uchar,
        s32bit_uchar,   u8bit_uchar,  u16bit_uchar,  u32bit_uchar,
         uchar_s8bit,  uchar_s16bit,  uchar_s32bit,   uchar_u8bit,
        uchar_u16bit,  uchar_u32bit
      );

const
   convmatrix : array[s8bit..uchar, s8bit..uchar] of convtype =

     ((equal, s8bit_s16bit, s8bit_s32bit, equal, s8bit_u16bit, s8bit_u32bit, s8bit_uchar),
      (s16bit_s8bit, equal, s16bit_s32bit, s16bit_u8bit, equal, s16bit_u32bit, s16bit_uchar),
      (s32bit_s8bit, s32bit_s16bit, equal, s32bit_u8bit, s32bit_u16bit, equal, s32bit_uchar),
      (equal, u8bit_s16bit, u8bit_s32bit, equal, u8bit_u16bit, u8bit_u32bit, u8bit_uchar),
      (u16bit_s8bit, equal, u16bit_s32bit, u16bit_u8bit, equal, u16bit_u32bit, u16bit_uchar),
      (u32bit_s8bit, u32bit_s16bit, equal, u32bit_u8bit, u32bit_u16bit, equal, u32bit_uchar),
      ( uchar_s8bit, uchar_s16bit, uchar_s32bit, uchar_u8bit, uchar_u16bit, uchar_u32bit, equal));

var inreg:boolean;
    i: regs;
    size, v:longint;
    loc : location;
begin
  if p^.left=NIL then exit;
  GenerateCode(p^.left);
  p^.loc:=p^.left^.loc;
  if asmmode then exit; {ignore the autotypeconversions}
  {automatic type conversions}
  case p^.return^.typedef of
  _BooleanDef,
  _SubRangeDef: begin
                  if p^.left^.return=NIL then
                    begin
                      ReleaseLocRegs(p^.loc);
                      i:=GetRegister;
                      EmitIntegerLoad(i, p^.return, p^.loc);
                      p^.loc.l:=register;
                      p^.loc.reg:=i;
                    end
                  else
                  if (p^.left^.return^.typedef=_SubRangeDef) or
                     (p^.left^.return^.typedef=_BooleanDef) then
                    begin
                      if convmatrix[p^.left^.return^.SubRangeTyp, p^.return^.SubRangeTyp]<>equal then
                begin
                  if (p^.left^.loc.l=port) then
                    begin
                      p^.return:=p^.left^.return {undo typeconversion to allow correct codegeneration}
                    end
                  else
                  if (p^.left^.loc.l<>ordconst) then
                  begin
                  if p^.left^.loc.l=register then
                    begin
                      i:=p^.left^.loc.reg;
                      inreg:=TRUE;
                    end
                  else
                    begin
                      ReleaseLocRegs(p^.loc);
                      i:=GetRegister;
                      inreg:=FALSE;
                    end;
                    size:=GetSize(p^.left^.return);
                  case convmatrix[p^.left^.return^.SubRangeTyp, p^.return^.SubRangeTyp]  of
                  u8bit_u32bit,
                  u8bit_s32bit:  if inreg=TRUE then emit_reg_ord(_and_, _dword, i, $FF)
                                               else emit_reg_loc(_movzx_, _dword, i, size, p^.loc);
                  u16bit_u32bit,
                  u16bit_s32bit: if inreg=TRUE then emit_reg_ord(_and_, _dword, i, $FFFF)
                                               else emit_reg_loc(_movzx_, _dword, i, size, p^.loc);
                  s8bit_u32bit,
                  s16bit_u32bit,
                  s8bit_s32bit,
                  s16bit_s32bit: if inreg=TRUE then emit_reg_reg(_movsx_, _dword, i, size, i)
                                               else emit_reg_loc(_movsx_, _dword, i, size, p^.loc);

                  s8bit_s16bit,
                  s8bit_u16bit,
                  u8bit_s16bit,
                  u8bit_u16bit:  if inreg=TRUE then emit_reg_reg(_movzx_, GetSize(p^.return), i, size, i)
                                               else emit_reg_loc(_movzx_, GetSize(p^.return), i, size, p^.loc);
                  u16bit_u8bit,
                  s16bit_u8bit,
                  u32bit_u16bit,
                  u32bit_s16bit,
                  s32bit_s16bit,
                  s32bit_u16bit,
                  u32bit_u8bit,
                  s32bit_s8bit,
                  s32bit_u8bit:  if inreg<>TRUE then EmitIntegerLoad(i, p^.left^.return, p^.loc);

                  uchar_s8bit,
                  uchar_s16bit,
                  uchar_s32bit,
                  uchar_u8bit,
                  uchar_u16bit,
                  uchar_u32bit : begin
                                   if p^.forced<>TRUE then LineError(p^.line, 'Invalid type conversion');
                                   if inreg=TRUE then emit_reg_reg(_movzx_, GetSize(p^.return), i, size, i)
                                                 else emit_reg_loc(_movzx_, GetSize(p^.return), i, size, p^.loc);
                                 end;
                  s8bit_uchar,
                  s16bit_uchar,
                  s32bit_uchar,
                  u8bit_uchar,
                  u16bit_uchar,
                  u32bit_uchar: begin
                                  if p^.forced<>TRUE then LineError(p^.line, 'Invalid type conversion');
                                  if inreg<>TRUE then EmitIntegerLoad(i, p^.left^.return, p^.loc);
                                end;
                  invalid     :  LineError(p^.line, 'Invalid type conversion');
                  else           LineError(p^.line, 'Invalid type conversion');
                  end;
                  p^.loc.l:=register;
                  p^.loc.reg:=i;
                  end;
                end;
                end
                else
                  if (p^.left^.return^.typedef=_PointerDef) and
                     (GetSize(p^.return)=4) then
                    begin
                      {donothing}
                    end
                  else
                    LineError(p^.line, 'type mismatch');
                end;
  _StringDef:   begin
                  if (p^.left^.return^.typedef=_SubRangeDef) and
                     (p^.left^.return^.SubRangeTyp=uchar) then
                    begin
                      p^.return:=p^.left^.return;
                      p^.loc:=p^.left^.loc;
                    end;
                end;
  _RealDef:     begin
                  if p^.left^.return^.typedef=_SubRangeDef then
                    case p^.loc.l of
                    ordconst : begin
                                 v:=p^.loc.value;
                                 p^.loc.l:=memref;
                                 ClearLoc(p^.loc);
                                 p^.loc.name:={getmemstring(}AddRealConstant(v){)};
                                 size:=GetSize(p^.return);
                                 if size<>8 then
                                   begin
                                     emit_loc(_fld_, _qword, p^.loc);
                                     p^.loc.l:=fpu;
                                   end;
                               end;
                    register:  begin
                                 emit_reg(_push_, _dword, p^.loc.reg);
                                 SetLoc(loc, esp, none, 0, 0);
                                 emit_loc(_fild_, _dword, loc);
                                 emit_reg(_pop_, _dword, p^.loc.reg);
                               end;
                    directmem,
                    memref:    begin
                                 size := GetSize(p^.left^.return);
                                 if (size in [2,4,8]) then
                                   begin
                                     {we can load mem var directly}
                                     {FPU can operate on 64bit integers too}
                                     emit_loc(_fild_, size, p^.loc);
                                     p^.loc.l:=fpu;
                                   end
                                 else
                                   begin
                                     EmitIntegerLoad(edi, p^.left^.return, p^.loc);
                                     emit_reg(_push_, _dword, p^.loc.reg);
                                     SetLoc(loc, esp, none, 0, 0);
                                     emit_loc(_fild_, _dword, loc);
                                     emit_reg(_pop_, _dword, p^.loc.reg);
                                   end;
                               end;
                    else
                               LineError(p^.line, 'Cannot convert variable to real');
                    end
                  else
                    if p^.left^.return^.typedef=_RealDef then
                      begin
                        size:=GetSize(p^.left^.return);
                        if size<>GetSize(p^.return) then
                          begin
                            if p^.loc.l<>fpu then
                              begin
                                emit_loc(_fld_, size, p^.loc);
                                p^.loc.l:=fpu;
                              end
                          end;
                      end;
                end;
  end;
end;

procedure DoVar(var p : ptree);

var sym : pSymbolRecord;
    typ : pTypeRecord;

begin
  sym:=p^.sym;
  typ:=sym^.typedef;

  case sym^.symbol of
  _variable: begin
               if (sym^.vartype=_Global) then
                 begin
                   if sym^.typedconst then
                     p^.loc.name:=TCPrefix+sym^.overloadedname
                   else
                     p^.loc.name:={getmemstring(}sym^.overloadedname{)};
                 end
               else
                 begin
                   if sym^.typedconst then
                     p^.loc.name:=TCPrefix+sym^.overloadedname
                   else
                     begin
                       p^.loc.name:='';
                       {p^.loc.name:=NIL;}
                       {freememstring(p^.loc.name);}
                       Fill_Loc(p^.loc, sym, none, none, 0, 0);
                       CheckLevel(p);
                       if (p^.sym^.vartype=_RegVar) and (p^.sym^.lastaccess = p) then
                         begin
                           protreg:=protreg - [p^.sym^.r]; {unprotect register}
                           ReleaseRegister(p^.sym^.r);     {release it}
                         end;
                     end;
                 end;
               if p^.sym^.alias <> NIL then
                 p^.loc.name := {getmemstring(}p^.sym^.alias^.name{)}; { point to overlayed var}
               if p^.sym^.absreference then
                 p^.loc.offset := p^.sym^.offset; { assign machine address }

               if (WithTable<>NIL) and (WithTable^.first<>NIL) then
                 begin
                   if GetSymbolFromList(WithTable, p^.sym^.name)<>NIL then
                     begin
                       if withloc.l<>undef then
                         begin
                           p^.loc := withloc;
                           inc(p^.loc.offset, p^.sym^.offset); {add offset}
                         end;
                     end;
                 end;
             end;
  _func,
  _proc : begin
            p^.loc.name:={getmemstring(}sym^.overloadedname{)};
          end;
  {!!!!! THIS LINE ONLY USED BY THE ASSEMBLY PARSER!!!}
  __reg : begin
            p^.loc.l:=register;
            p^.loc.reg:=regs(sym^.r);
            dispose(sym);
          end;
  end;
end;


{-------------------------------------------}
{ Arithmetic code generation procedures     }
{-------------------------------------------}
procedure SwapLoc(var l1, l2:location);

var tmp:location;

begin
  tmp:=l1;
  l1:=l2;
  l2:=tmp;
end;

procedure DoAdd(var p: ptree);

var i,i1: regs;
    loc : location;
    lab : integer;

begin
  case p^.return^.typedef of
  _RealDef  : begin
                GenerateCode(p^.left);
                GenerateCode(p^.right);
                if (p^.left^.loc.l<>fpu) then
                  emit_loc(_fld_, GetSize(p^.left^.return), p^.left^.loc);
                if (p^.right^.loc.l<>fpu) then
                  emit_loc(_fld_, GetSize(p^.right^.return), p^.right^.loc);
                emit_fpu_fpu(_faddp_, 1, 0);
                ReleaseLocRegs(p^.left^.loc);
                ReleaseLocRegs(p^.right^.loc);
                p^.loc.l:=fpu;
              end;
  _StringDef: begin
                GenerateCode(p^.left);
                if p^.left^.op<>__add then
                  if (p^.left^.return^.typedef=_SubRangeDef) and
                     (p^.left^.return^.subrangetyp=uchar) then
                      begin
                        inc(stacksize, 2);
                        SetLoc(loc, ebp, none, -stacksize, 0);
                        emit_loc_ord(_mov_, _byte, loc, 1);
                        inc(loc.offset);
                        case p^.left^.loc.l of
                        ordconst : emit_loc_ord(_mov_, _byte, loc, p^.left^.loc.value);
                        register : emit_loc_reg(_mov_, _byte, loc, _byte, p^.left^.loc.reg);
                        memref   : begin
                                     i:=GetRegister;
                                     EmitIntegerLoad(i, p^.left^.return, p^.left^.loc);
                                     emit_loc_reg(_mov_, _byte, loc, _byte, i);
                                     ReleaseRegister(i);
                                     p^.left^.loc:=loc;
                                   end
                        end;
                        dec(loc.offset);
                        ReleaseLocRegs(p^.left^.loc);
                        p^.left^.loc:=loc;
                      end
                    else
                      begin
                        inc(stacksize, 256); {stacksize for procedure OR main-program}
                        SetLoc(loc, ebp, none, -stacksize, 0);
                        EmitStringCopy(loc, p^.left^.loc, 255);
                        ReleaseLocRegs(p^.left^.loc);
                        p^.left^.loc:=loc;
                      end;
                GenerateCode(p^.right);
                if (p^.right^.return^.typedef=_SubRangeDef) and
                   (p^.right^.return^.subrangetyp=uchar) then
                  begin
                    i:=GetRegister;
                    lab:=NewLabel;
                    emit_loc_ord(_cmp_, _byte, p^.left^.loc, 255);
                    emit_lab(_jz_, _nothing, LabelString(lab));
                    emit_loc(_inc_, _byte, p^.left^.loc);
                    emit_reg_loc(_lea_, _dword, edi, _nothing, p^.left^.loc);
                    emit_reg_loc(_movzx_, _dword, i, _byte, p^.left^.loc);
                    emit_reg_reg(_add_, _dword, edi, _dword, i);
                    SetLoc(loc, edi, none, 0, 0);
                    case p^.right^.loc.l of
                    ordconst : emit_loc_ord(_mov_, _byte, loc, p^.right^.loc.value);
                    memref   : begin
                                 emit_reg_loc(_mov_, _byte, i, _byte, p^.right^.loc);
                                 emit_loc_reg(_mov_, _byte, loc, _byte, i);
                               end;
                    register : emit_loc_reg(_mov_, _byte, loc, _byte, p^.right^.loc.reg);
                    end;
                    PutLabel(lab);
                    ReleaseRegister(i);
                  end
                else
                  begin
                    ReleaseLocRegs(p^.right^.loc);
                    EmitStringAdd(p^.left^.loc, p^.right^.loc);
                  end;
                p^.loc:=p^.left^.loc;
              end;
  else        begin
                GenerateCode(p^.left);
                p^.loc:=p^.left^.loc; { save location of the variable}
                GenerateCode(p^.right);
                if (p^.loc.l<>register) and (p^.right^.loc.l<>register) then
                  begin                     { no variable is in a register}
                    ReleaseLocRegs(p^.loc); { release the allocated registers}
                    i:=GetRegister32;       { get new one}
                    EmitIntegerLoad(i, p^.left^.return, p^.loc); {load variable}
                    p^.loc.l:=register;     { variable is now in a register}
                    p^.loc.reg:=i;
                  end
                else
                  if (p^.right^.loc.l=register) and not (p^.right^.loc.reg in protreg) then
                    SwapLoc(p^.loc,p^.right^.loc);

                if (p^.loc.l=register) and
                   (p^.loc.reg in protreg) then
                  begin
                    i:=GetRegister32;       { get new one}
                    case p^.right^.loc.l of
                    directmem,
                    memref    : begin
                                  i1:=GetRegister32;
                                  EmitIntegerLoad(i1, p^.right^.return, p^.right^.loc);
                                  p^.right^.loc.l:=register;
                                  p^.right^.loc.reg:=i1;
                                end;
                    register  : ;
                    else        LineError(p^.line, 'Error in add optimizer, contact author!');
                    end;
                    loc.l:=memref;
                    ClearLoc(loc);
                    loc.base :=p^.loc.reg;
                    loc.index:=p^.right^.loc.reg;
                    emit_reg_loc(_lea_, _dword, i, _nothing, loc);
                    p^.loc.l:=register;     { variable is now in a register}
                    p^.loc.reg:=i;
                  end
                else
                  EmitIntegerAdd(p^.loc, p^.right^.loc, p^.right^.return); {emits the assembler code for add}
              end;
  end;
  if p^.cse then
    begin
      i:=GetRegister32;
      emit_reg_reg(_mov_, _dword, i, _dword, p^.loc.reg);
      p^.csereg := i;
    end;
end;

procedure DoSub(var p: ptree);

var i   : regs;
    tmp : location;
    size: longint;
begin
  case p^.return^.typedef of
  _RealDef  : begin
                GenerateCode(p^.left);
                GenerateCode(p^.right);
                p^.loc:=p^.left^.loc;
                if (p^.left^.loc.l<>fpu) then
                  emit_loc(_fld_, GetSize(p^.left^.return), p^.left^.loc);
                if (p^.right^.loc.l<>fpu) then
                  emit_loc(_fld_, GetSize(p^.right^.return), p^.right^.loc);
                if p^.right^.op=__sub then
                  emit_fpu_fpu(_fsubrp_, 1, 0)
                else
                  emit_fpu_fpu(_fsubp_, 1, 0);
                ReleaseLocRegs(p^.left^.loc);
                ReleaseLocRegs(p^.right^.loc);
                p^.loc.l:=fpu;
              end;
  else        begin
                GenerateCode(p^.left);
                p^.loc:=p^.left^.loc;
                GenerateCode(p^.right);
                if (p^.loc.l<>register) {and (p^.right^.loc.l<>register)} then
                  begin {no variable is in a register, so load one}
                    ReleaseLocRegs(p^.loc); {release the allocated registers}
                    if freereg=[] then i:=edi;
                    i:=GetRegister32;         {get new one}
                    if p^.left^.op=__ordconst then
                      emit_reg_ord(_mov_, GetSize(p^.return), i, p^.left^.n)
                    else
                      EmitIntegerLoad(i, p^.return, p^.loc);
                    p^.loc.l:=register;     {variable is now in a register}
                    p^.loc.reg:=i;
                    if i=edi then emit_reg_reg(_mov_, _dword, p^.right^.loc.reg, _dword, edi);
                  end;
                if (p^.loc.l<>register) then
                  begin
                    emit_reg_loc(_mov_, _dword, edi, _dword, p^.loc);
                    emit_reg_reg(_sub_, _dword, edi, _dword, p^.right^.loc.reg);
                    emit_reg_reg(_mov_, _dword, p^.right^.loc.reg, _dword, edi);
                    ReleaseLocRegs(p^.loc);
                    p^.loc:=p^.right^.loc;
                  end
                else
                  if p^.right^.loc.l<>register then
                    begin
                      if p^.right^.loc.l = ordconst then
                        begin
                          if p^.right^.loc.value=1 then
                            emit_reg(_dec_, GetSize(p^.return), p^.loc.reg) {faster}
                          else
                            emit_reg_ord(_sub_, GetSize(p^.return), p^.loc.reg, p^.right^.loc.value);
                        end
                      else
                        begin
                          size:=GetSize(p^.return);
                          if p^.right^.loc.l=port then
                            begin
                              i:=GetRegister;
                              EmitPortIn(i, p^.return, p^.right^.loc);
                              emit_reg_reg(_sub_, size, p^.loc.reg, size, i);
                              ReleaseRegister(i);
                            end
                          else
                            emit_reg_loc(_sub_, size, p^.loc.reg, size, p^.right^.loc);
                          ReleaseLocRegs(p^.right^.loc);
                        end
                    end
                  else
                    begin
                      if (p^.loc.reg in protreg) then
                        begin
                          i:=GetRegister32;       { get new one}
                          emit_reg_reg(_mov_, _dword, i, _dword, p^.loc.reg);
                          p^.loc.l:=register;     { variable is now in a register}
                          p^.loc.reg:=i;
                        end;
                      emit_reg_reg(_sub_, _dword, p^.loc.reg, _dword, p^.right^.loc.reg);
                      ReleaseLocRegs(p^.right^.loc);
                    end;
              end;
  end;
end;

procedure DoMul(var p: ptree);

var i   : regs;
    s   : opcode_num;
    size: integer;

begin
  case p^.return^.typedef of
  _RealDef  : begin
                GenerateCode(p^.left);
                GenerateCode(p^.right);
                p^.loc:=p^.left^.loc; {save location of the variable}
                if (p^.left^.loc.l<>fpu) then
                  emit_loc(_fld_, GetSize(p^.left^.return), p^.left^.loc);
                if (p^.right^.loc.l<>fpu) then
                  emit_loc(_fld_, GetSize(p^.right^.return), p^.right^.loc);
                emit_fpu_fpu(_fmulp_, 1, 0);
                ReleaseLocRegs(p^.left^.loc);
                ReleaseLocRegs(p^.right^.loc);

                p^.loc.l:=fpu;
              end
  else        begin
                GenerateCode(p^.left);
                p^.loc:=p^.left^.loc; {save location of the variable}
                GenerateCode(p^.right);
                if (p^.left^.loc.l<>register) and (p^.right^.loc.l<>register) then
                  begin {no variable is in a register}
                    ReleaseLocRegs(p^.loc); {release the allocated registers}
                    i:=GetRegister;         {get new one}
                    EmitIntegerLoad(i, p^.return, p^.loc);
                    p^.loc.l:=register;     {variable is now in a register}
                    p^.loc.reg:=i;
                  end
                else
                  if (p^.right^.loc.l=register) then
                    SwapLoc(p^.loc,p^.right^.loc);

                if p^.right^.loc.l<>register then {variable is in left register}
                  begin
                    if p^.right^.loc.l=ordconst then {direct multiply}
                      EmitConstMultiply(p^.loc.reg, p^.right^.loc.value)
                    else
                      begin
                        s := _imul_;
                        size:=GetSize(p^.return);
                        if p^.right^.loc.l=port then
                          begin
                            i:=GetRegister;
                            EmitPortIn(i, p^.return, p^.right^.loc);
                            emit_reg_reg(s, size, p^.loc.reg, size, i);
                            ReleaseRegister(i);
                          end
                        else
                          emit_reg_loc(s, size, p^.loc.reg, size, p^.right^.loc);
                        ReleaseLocRegs(p^.right^.loc);
                      end;
                  end
                else
                  begin
                    size:=GetSize(p^.return);
                    emit_reg_reg(_imul_, size, p^.loc.reg, size, p^.right^.loc.reg);
                    ReleaseLocRegs(p^.right^.loc);
                  end;
              end;
  end;
  if p^.cse then
    begin
      i:=GetRegister32;
      emit_reg_reg(_mov_, _dword, i, _dword, p^.loc.reg);
      p^.csereg := i;
    end;
end;

procedure DoSlash(var p: pTree);

begin
  case p^.return^.typedef of
  _RealDef  : begin
                GenerateCode(p^.left);
                GenerateCode(p^.right);
                p^.loc:=p^.left^.loc; {save location of the variable}
                if (p^.left^.loc.l<>fpu) then
                  emit_loc(_fld_, GetSize(p^.left^.return), p^.left^.loc);
                if (p^.right^.loc.l<>fpu) then
                  emit_loc(_fld_, GetSize(p^.right^.return), p^.right^.loc);
                if p^.right^.op=__slash then
                  emit_fpu_fpu(_fdivrp_, 1, 0)
                else
                  emit_fpu_fpu(_fdivp_, 1, 0);
                ReleaseLocRegs(p^.left^.loc);
                ReleaseLocRegs(p^.right^.loc);

                p^.loc.l:=fpu;
              end
  else        LineError(p^.line, 'floating point number expected');
  end;
end;


Function GetMagicNumber(Divisor:LongInt):LongInt; assembler;
asm
{ On stack now:
  Word Ptr [bp+00] => Old BP
  Word Ptr [bp+02] => Return address
  Word Ptr [bp+04] => Lower half of LongInt Or: DWord Ptr [bp+4] = LongInt
  Word Ptr [bp+06] => Higher half of LongInt

  Now .. lets make the Magic Number guys!
  Magic = 2/Divisor (2 because of rounding, If I would be using 1
                     I would get an answer between two wholes, but
 		     with 2, I get ?.0 and ?.5, which makes it
 		     possible for me to round off correctly when the
 		     magic number is used later (It works ;))

  Bear with me, I hate translating 32bit opcodes to inline
  Pascal using db $66 and db $67 .. ARGH .. kills me very efficiently
}

 db $66; mov cx,[bp+4]  {mov ecx,[bp+4]         Load ecx with the Divisor}
 db $66; mov bx,cx      {mov ebx,ecx            Put it here too }
 db $66; xor ax,ax	{xor eax,eax            clean out eax}
 db $66; mov dx,2; dw 0 {mov edx,2              2/Divisor later
                                                edx:eax = $0000000200000000
                                                (Big numbah ;) }
 db $66; idiv cx        {idiv ecx		And divide, result in eax...}
 db $66; mov bx,ax	{mov ebx,eax		Save eax for rest addon }
 db $66; mov ax,cx	{mov eax,ecx		Divisor in eax }
 db $66; mov cx,dx	{mov ecx,edx		Rest in ecx }
 db $66; xor dx,dx	{xor edx,edx		edx:eax = Divisor }
 db $66; idiv cx	{idiv ecx		Divisor/Rest }
 db $66; add ax,bx	{add eax,ebx		If Divisor/Rest>0, add it on }

 db $66; mov dx,ax      {mov edx,eax            move all bits to edx}
 db $66; shr dx,16	{shr edx,16             and shift them down to
                                                the lower 16 bits,}
			{Which results in the answer being returned in dx:ax}
end;

procedure DoDiv(var p: pTree);

var i   : regs;
    x   : longint;
    tmp : location;
    domagicdiv,
    push_eax, push_edx:boolean;


begin
  GenerateCode(p^.left);

  p^.loc:=p^.left^.loc;

  GenerateCode(p^.right);

  push_edx:=FALSE;
  push_eax:=FALSE;
  domagicdiv:=FALSE;

  if p^.left^.loc.l<>register then {load left part (counter into register}
    begin
      ReleaseLocRegs(p^.left^.loc);
      i:=GetRegister32;
      if p^.left^.op=__ordconst then emit_reg_ord(_mov_, _dword, i, p^.left^.n)
                                else EmitIntegerLoad(i, p^.left^.return, p^.left^.loc);
      p^.left^.loc.l:=register;
      p^.left^.loc.reg:=i;
    end
  else
    i:=p^.left^.loc.reg; {get the register}

  if (p^.right^.loc.l = ordconst) and not (p^.op=__mod) and
     (PowerOfTwo(p^.right^.loc.value) <> 0) then
    begin
      x:=PowerOfTwo(p^.right^.n); {do we have a power of two?}
      emit_reg_ord(_sar_, _dword, i, x);
    end
  else
    begin
      if (p^.right^.loc.l = ordconst) and
         (p^.right^.loc.value >= 5) and
         (Options.OptimizeLevel>0) and not (p^.op=__mod) then
        domagicdiv:=true
      else
        begin { load denominator in edi (is always free)}
          if p^.right^.loc.l<>register then
            begin
              ReleaseLocRegs(p^.right^.loc);
              p^.left^.loc.l:=register;
              if p^.right^.loc.l = ordconst then
                emit_reg_ord(_mov_, _dword, edi, p^.right^.loc.value)
              else
                EmitIntegerLoad(edi, p^.right^.return, p^.right^.loc);
            end
          else
            begin
              emit_reg_reg(_mov_, _dword, edi, _dword, p^.right^.loc.reg);
              ReleaseLocRegs(p^.right^.loc);
            end;
        end;
      if domagicdiv then
        begin
          if i=edx then
            begin
              if not(eax in freereg) then
                begin
                  emit_reg(_push_, _dword, eax);
                  push_eax:=TRUE;
                end;
            end
          else
            begin
              if not(edx in freereg) then
                begin
                  emit_reg(_push_, _dword, edx);
                  push_edx:=TRUE;
                end;
              if i<>eax then
                begin
                  if not(eax in freereg) then
                    begin
                      emit_reg(_push_, _dword, eax);
                      push_eax:=TRUE;
                    end;
               end;
            end;
          emit_reg_reg(_mov_, _dword, edi, _dword, i);
          x:=GetMagicNumber(p^.right^.loc.value);
          emit_reg_ord(_mov_, _dword, eax, x);
          emit_reg(_imul_, _dword, edi);
          emit_reg_ord(_sar_, _dword, edx, 1);
          if i<>edx then
            emit_reg_reg(_mov_, _dword, i, _dword, edx);
        end
      else
        begin
          if i=edx then
            begin
              if not(eax in freereg) then
                begin
                  emit_reg(_push_, _dword, eax);
                  push_eax:=TRUE;
                end;
              emit_reg_reg(_mov_, _dword, eax, _dword, edx);
            end
          else
            begin
              if not(edx in freereg) then
                begin
                  emit_reg(_push_, _dword, edx);
                  push_edx:=TRUE;
                end;
              if i<>eax then
                begin
                  if not(eax in freereg) then
                    begin
                      emit_reg(_push_, _dword, eax);
                      push_eax:=TRUE;
                    end;
                 emit_reg_reg(_mov_, _dword, eax, _dword, i);
               end;
            end;
          if (CPU=Pentium) or (CPU=i486) or (CPU=K6) then
            begin
              emit_reg_reg(_mov_, _dword, edx, _dword, eax);
              emit_reg_ord(_sar_, _dword, edx, 31);
            end
          else
            emit_non(_cdq_);

          emit_reg(_idiv_, _dword, edi);
        end;

      if not domagicdiv then
      begin
      if (p^.op=__div) then
        begin
          if push_eax=TRUE then
            begin
              emit_reg_reg(_mov_, _dword, i, _dword, eax);
            end
          else if i<>eax then {'i' could also be changed}
                 emit_reg_reg(_mov_, _dword, i, _dword, eax);
        end
      else
        begin
          if push_edx=TRUE then
            begin
              emit_reg_reg(_mov_, _dword, i, _dword, edx);
            end
          else
            if i<>edx then
              emit_reg_reg(_mov_, _dword, i, _dword, edx);
        end;
     end;
     if push_eax=TRUE then emit_reg(_pop_, _dword, eax);
     if push_edx=TRUE then emit_reg(_pop_, _dword, edx);
   end;
   p^.loc.l:=register;
   p^.loc.reg:=i;
end;

procedure CheckShortBoolean(var p: pTree);
var size: integer;
begin
  if (p^.return^.typedef<>_BooleanDef) or
     ((p^.op=__ordconst) or (p^.op=__var) or (p^.op=__type) or (p^.op=__index) or
     ((p^.op=__call) and (p^.sym^.symbol=_Func))) then
    begin
      GenerateCode(p);
      size:=GetSize(p^.return);
      case p^.loc.l of
      register: begin
                  emit_reg_reg(_test_, size, p^.loc.reg, size, p^.loc.reg);
                  emit_lab(_jz_, _near_, LabelString(Current_Label));
                end;
      ordconst: begin
                  if p^.n=0 then emit_lab(_jmp_, _nothing, LabelString(Current_Label));
                end;
      else      begin
                  emit_loc_ord(_cmp_, size, p^.loc, 0);
                  emit_lab(_jz_, _near_, LabelString(Current_Label));
                end;
      end;
      DestroyTree(p);
      p:=NIL;
    end
end;

procedure DoAnd(var p: ptree);

var i       : regs;
    size, oldlabel: integer;

begin
  size:=GetSize(p^.return);
  case p^.return^.typedef of
  _BooleanDef: begin
                 oldlabel:=current_label;

                 CheckShortBoolean(p^.left);
                 CheckShortBoolean(p^.right);
                 GenerateCode(p^.left);
                 current_label:=oldlabel;
                 GenerateCode(p^.right);

                 if (current_label=0) then {result is not in flags but in a variable}
                   begin
                     p^.loc:=p^.left^.loc;
                     emit_reg_reg(_and_, size, p^.loc.reg, size, p^.right^.loc.reg);
                     ReleaseRegister(p^.right^.loc.reg);
                   end;
               end
  else begin {bitwise AND}
         GenerateCode(p^.left);

         p^.loc:=p^.left^.loc; {save location of the variable}

         GenerateCode(p^.right);

         if (p^.left^.loc.l<>register) and (p^.right^.loc.l<>register) then
           begin {no variable is in a register}
             ReleaseLocRegs(p^.loc); {release the allocated registers}
             i:=GetRegister;         {get new one}
             EmitIntegerLoad(i, p^.return, p^.loc);
             p^.loc.l:=register;     {variable is now in a register}
             p^.loc.reg:=i;
           end
         else
           if (p^.right^.loc.l=register) then SwapLoc(p^.loc,p^.right^.loc);

         if p^.right^.loc.l<>register then {if right isn't a register then do direct and}
           case p^.right^.loc.l of
           ordconst : emit_reg_ord(_and_, size, p^.loc.reg, p^.right^.loc.value);
           else       begin
                        emit_reg_loc(_and_, size, p^.loc.reg, size, p^.right^.loc);
                        ReleaseLocRegs(p^.right^.loc);
                      end;
           end
         else
           begin
             emit_reg_reg(_and_, size, p^.loc.reg, size, p^.right^.loc.reg);
             ReleaseLocRegs(p^.right^.loc);
           end;
       end;
  end;
end;

procedure DoOr(var p: ptree);

var size, old,
    oldlabel  : integer;
    i         : regs;

begin
  {invert comparisons for smarter code-generation}
  case p^.left^.op of
  __equal      : p^.left^.op:=__not_eq;
  __not_eq     : p^.left^.op:=__equal;
  __greater    : p^.left^.op:=__less_eq;
  __less       : p^.left^.op:=__greater_eq;
  __greater_eq : p^.left^.op:=__less;
  __less_eq    : p^.left^.op:=__greater;
  end;
  case p^.right^.op of
  __equal      : p^.right^.op:=__not_eq;
  __not_eq     : p^.right^.op:=__equal;
  __greater    : p^.right^.op:=__less_eq;
  __less       : p^.right^.op:=__greater_eq;
  __greater_eq : p^.right^.op:=__less;
  __less_eq    : p^.right^.op:=__greater;
  end;
  size:=GetSize(p^.return);
  case p^.return^.typedef of
  _BooleanDef: begin
                 oldlabel:=current_label; {jump to when false...}

                 current_label:=false_label;

                 old:=True_Label;
                 True_label:=NewLabel;
                 {current_label:=old;}

                 CheckShortBoolean(p^.left);
                 CheckShortBoolean(p^.right);
                 GenerateCode(p^.left);

                 PutLabel(True_Label);

                 True_Label:=old;

                 GenerateCode(p^.right);
                 current_label:=oldlabel; {old;}

                 if (current_label=0) then {result is not in flags but in a variable}
                   begin
                     p^.loc:=p^.left^.loc;
                     emit_reg_reg(_or_, size, p^.loc.reg, size, p^.right^.loc.reg);
                     ReleaseRegister(p^.right^.loc.reg);
                   end
                 else
                   emit_lab(_jmp_, _nothing, LabelString(True_Label));
               end
  else begin {bitwise OR}
         GenerateCode(p^.left);
         p^.loc:=p^.left^.loc; {save location of the variable}
         GenerateCode(p^.right);
         if (p^.loc.l<>register) and (p^.right^.loc.l<>register) then
           begin {no variable is in a register}
             ReleaseLocRegs(p^.loc); {release the allocated registers}
             i:=GetRegister;         {get new one}
             EmitIntegerLoad(i, p^.return, p^.loc);
             p^.loc.l:=register;     {variable is now in a register}
             p^.loc.reg:=i;
           end
         else
           if (p^.right^.loc.l=register) then SwapLoc(p^.loc,p^.right^.loc);

         if p^.right^.loc.l<>register then {if right isn't a register then do direct and}
           case p^.right^.loc.l of
           ordconst : emit_reg_ord(_or_, size, p^.loc.reg, p^.right^.loc.value);
           else       begin
                        emit_reg_loc(_or_, size, p^.loc.reg, size, p^.right^.loc);
                        ReleaseLocRegs(p^.right^.loc);
                      end;
           end
         else
           begin
             emit_reg_reg(_or_, size, p^.loc.reg, size, p^.right^.loc.reg);
             ReleaseLocRegs(p^.right^.loc);
           end;
       end;
  end;
end;

procedure DoXor(var p: ptree);

var i   : regs;
    size, old,
    oldlabel  : integer;

begin
  case p^.return^.typedef of
  _BooleanDef: begin
                 CheckShortBoolean(p^.left);
                 CheckShortBoolean(p^.right);
                 oldlabel:=current_label;
                 current_label:=0;
                 GenerateCode(p^.left);
                 GenerateCode(p^.right);
                 emit_reg_reg(_xor_, _byte, p^.left^.loc.reg, _byte, p^.right^.loc.reg);
                 current_label:=oldlabel;
                 if current_label<>0 then
                   emit_lab(_jz_, _near_, LabelString(oldlabel))
                 else
                   begin
                     p^.loc:=p^.left^.loc;
                     ReleaseRegister(p^.right^.loc.reg);
                   end;
               end
  else begin {bitwise XOR}
         GenerateCode(p^.left);

         p^.loc:=p^.left^.loc; {save location of the variable}

         GenerateCode(p^.right);

         if (p^.loc.l<>register) and (p^.right^.loc.l<>register) then
           begin {no variable is in a register}
             ReleaseLocRegs(p^.loc); {release the allocated registers}
             i:=GetRegister;         {get new one}
             EmitIntegerLoad(i, p^.return, p^.loc);
             p^.loc.l:=register;     {variable is now in a register}
             p^.loc.reg:=i;
           end
         else
           if (p^.right^.loc.l=register) then SwapLoc(p^.loc,p^.right^.loc);

         size:=GetSize(p^.return);
         if p^.right^.loc.l<>register then {if right isn't a register then do direct and}
           case p^.right^.loc.l of
           ordconst : emit_reg_ord(_xor_, size, p^.loc.reg, p^.right^.loc.value);
           else       begin
                        emit_reg_loc(_xor_, size, p^.loc.reg, size, p^.right^.loc);
                        ReleaseLocRegs(p^.right^.loc);
                      end;
           end
         else
           begin
             emit_reg_reg(_xor_, size, p^.loc.reg, size, p^.right^.loc.reg);
             ReleaseLocRegs(p^.right^.loc);
           end;
       end;
  end;
end;

procedure DoShlShr(var p: ptree); {bitwise SHL, SHR}

var i1, i2 : regs;
    {s_i1, s_i2, s : string[3];}
    s : opcode_num;
    size: integer;

begin
  GenerateCode(p^.left);

  GenerateCode(p^.right);

  if p^.op=__shl then s:=_shl_ else s:=_shr_;
  size:=GetSize(p^.return);

  if p^.left^.loc.l<>register then
    begin
      ReleaseLocRegs(p^.left^.loc);
      i1:=GetRegister;
      if p^.left^.op = __ordconst then
        begin
          if p^.left^.n<>0 then emit_reg_ord(_mov_, size, i1, p^.left^.n);
        end
      else emit_reg_loc(_mov_, size, i1, size, p^.left^.loc);
    end
  else
    i1:=p^.left^.loc.reg;

    case p^.right^.loc.l of
    ordconst : begin
                   if p^.right^.loc.value<>0 then emit_reg_ord(s, size, i1, p^.right^.loc.value);
                   p^.loc.l:=register;
                   p^.loc.reg:=i1;
                 end
    else         begin
                   if p^.right^.loc.l<>register then
                     begin {load right variable in a register}
                        ReleaseLocRegs(p^.right^.loc);
                        i2:=GetRegister;
                        emit_reg_loc(_mov_, size, i2, size, p^.right^.loc);
                     end
                   else i2:=p^.right^.loc.reg;
{if we have two variable, one _must_ be loaded into CL, so here the code to solve that}
                   case p^.return^.subrangetyp of
                   u8bit  : emit_reg_ord(_and_, _dword, i2, $FF);
                   u16bit : emit_reg_ord(_and_, _dword, i2, $FFFF);
                   s8bit,
                   s16bit : emit_reg_reg(_movsx_, _dword, i2, size, i2);
                   end;
                   if i1=ecx then
                     begin {exchange with right variable/register}
                       emit_reg_reg(_xchg_, size, i1, size, i2);
                       {faster on a pentium than xchg, but awful lot of code}
                       {     EmitLn('push',r[i1],'');
                             EmitLn('push',r[i2],'');
                             EmitLn('pop',r[i1],'');
                             EmitLn('pop',r[i2],'');}
                     end
                   else
                     if i2<>ecx then
                       begin
                         if ecx in freereg then
                           begin
                             emit_reg_reg(_mov_, _dword, ecx, _dword, i2);
                             ReleaseRegister(i2);
                             emit_reg_reg(s , _dword, i1, _byte, ecx);
                           end
                         else
                           begin
                             emit_reg(_push_, _dword, ecx);
                             emit_reg_reg(_mov_, _dword, ecx, _dword, i2);
                             ReleaseRegister(i2);
                             emit_reg_reg(s , _dword, i1, _byte, ecx);
                             emit_reg(_pop_, _dword, ecx);
                           end;
                       end
                     else
                       emit_reg_reg(s , _dword, i1, _byte, ecx);
                   p^.loc.l:=register;
                   p^.loc.reg:=i1;
                 end;
  end;
end;

procedure DoMinus(var p : pTree);
var
  i: regs;

begin
  GenerateCode(p^.left);
  p^.loc := p^.left^.loc;
  case p^.return^.typedef of
  _RealDef    : case p^.loc.l of
                memref  : begin
                            emit_loc(_fld_, GetSize(p^.return), p^.loc);
                            emit_non(_fchs_);
                            p^.loc.l := fpu;
                            ReleaseLocRegs(p^.loc);
                          end;
                ordconst: p^.d := -p^.d;
                fpu     : emit_non(_fchs_);
                else      LineError(p^.line, 'Can''t negate real');
                end;
  _SubRangeDef: begin
                  if p^.loc.l <> register then
                    begin
                      ReleaseLocRegs(p^.loc);
                      i := GetRegister32;
                      EmitIntegerLoad(i, p^.return, p^.loc);
                      p^.loc.l   := register;
                      p^.loc.reg := i;
                    end;
                  emit_reg(_neg_, _dword, p^.loc.reg);
                end;
  end;
end;

procedure DoNot(var p : pTree);
var
  i: regs;

begin
  case p^.return^.typedef of
  _BooleanDef : begin
                  GenerateCode(p^.left);
                  p^.loc := p^.left^.loc;
                  if p^.loc.l <> register then
                    begin
                      ReleaseLocRegs(p^.loc);
                      i := GetRegister;
                      EmitIntegerLoad(i, p^.return, p^.loc);
                      p^.loc.l   := register;
                      p^.loc.reg := i;
                    end;
                  emit_reg_ord(_xor_, GetSize(p^.return), p^.loc.reg, 1);
                  if current_label<>0 then
                    begin
                      ReleaseLocRegs(p^.loc);
                      emit_lab(_jz_, _near_, LabelString(current_label));
                    end;
                end;
  _SubRangeDef: begin
                  GenerateCode(p^.left);
                  p^.loc := p^.left^.loc;
                  if p^.loc.l <> register then
                    begin
                      ReleaseLocRegs(p^.loc);
                      i := GetRegister;
                      EmitIntegerLoad(i, p^.return, p^.loc);
                      p^.loc.l   := register;
                      p^.loc.reg := i;
                    end;
                  emit_reg(_not_, _dword, p^.loc.reg);
                end;
  _SetDef     : begin
                  GenerateCode(p^.left);
                  p^.loc := p^.left^.loc;
                end;
  end;
end;

procedure DoComparison(var p : pTree);

label jumps;

var i : regs;
    size:integer;
begin
  if (p^.left^.return^.typedef=_RealDef) or (p^.right^.return^.typedef=_RealDef) then
    begin {floating point comparison}
      {the loading of the variables is reserved because we use inverted jumps}
      GenerateCode(p^.right);
      if (p^.right^.loc.l<>fpu) then
        emit_loc(_fld_, GetSize(p^.right^.return), p^.right^.loc);
      GenerateCode(p^.left);
      p^.loc:=p^.left^.loc;
      if (p^.left^.loc.l<>fpu) then
        emit_loc(_fld_, GetSize(p^.left^.return), p^.left^.loc);
      emit_non(_fcompp_);
      if not (eax in freereg) then
        emit_reg_reg(_mov_, _dword, edi, _dword, eax);  {edi is always free}
        emit_reg(_fstsw_, _word, eax); {load status word, flags}
        emit_non(_sahf_);              {save it to the flags}
      if not (eax in freereg) then
        emit_reg_reg(_mov_, _dword, eax, _dword, edi);
    end
  else
  if (p^.left^.return^.typedef=_StringDef) or (p^.right^.return^.typedef=_StringDef) then
    begin
      GenerateCode(p^.left);
      GenerateCode(p^.right);
      if (p^.right^.return^.typedef=_SubRangeDef) and
         (p^.right^.return^.subrangetyp=uchar) then
        begin
          case p^.right^.loc.l of
          ordconst : emit_loc_ord(_cmp_, _word, p^.left^.loc, 256*ord(p^.right^.loc.value)+1);
          directmem,
          memref   : begin
                       i:=GetRegister;
                       emit_reg_loc(_mov_, _byte, i, _byte, p^.right^.loc);
                       emit_reg_ord(_shl_, _dword, i, 8); {shift upperbits to the left}
                       emit_reg_ord(_mov_, _byte, i, 1);  {set length byte}
                       emit_loc_reg(_cmp_, _word, p^.left^.loc, _word, i);
                       ReleaseRegister(i);
                     end;
          fpu,
          register : LineError(p^.line, 'invalid string comparison');
          end;
        end
      else
        if (p^.left^.return^.typedef=_SubRangeDef) and
           (p^.left^.return^.subrangetyp=uchar) then
          begin
            case p^.left^.loc.l of
            ordconst : begin
                         i:=GetRegister;
                         emit_reg_ord(_mov_, _dword, i, 256*ord(p^.left^.loc.value)+1);
                         emit_reg_loc(_mov_, _word, i, _word, p^.right^.loc);
                         ReleaseRegister(i);
                       end;
            directmem,
            memref   : begin
                         i:=GetRegister;
                         emit_reg_loc(_mov_, _byte, i, _byte, p^.left^.loc);
                         emit_reg_ord(_shl_, _dword, i, 8); {shift upperbits to the left}
                         emit_reg_ord(_mov_, _byte, i, 1);  {set length byte}
                         emit_reg_loc(_cmp_, _word, i, _word, p^.right^.loc);
                         ReleaseRegister(i);
                       end;
            fpu,
            register : LineError(p^.line, 'invalid string comparison');
            end;
          end
        else
          begin
            EmitStringCompare(p^.left^.loc, p^.right^.loc);
            p^.loc.l:=register;
            p^.loc.reg:=GetRegister;
          end;
      ReleaseLocRegs(p^.left^.loc);
      ReleaseLocRegs(p^.right^.loc);
    end
  else
  {_BooleanDef,
  _EnumeratedDef,
  _SubRangeDef: }
    begin
      GenerateCode(p^.left);
      p^.loc:=p^.left^.loc; {save location of the variable}
      GenerateCode(p^.right);
      if (p^.loc.l<>register) then
        begin {no variable is in a register, so load one}
          ReleaseLocRegs(p^.loc); {release the allocated registers}
          i:=GetRegister32;         {get new one}
          if p^.left^.loc.l=ordconst then
            begin
              emit_reg_ord(_mov_, _dword, i, p^.left^.loc.value);
              p^.loc.l:=register;
              p^.loc.reg:=i;
            end
          else
            begin
              if (p^.right^.loc.l=ordconst) and (p^.loc.l<>port) and (Current_Label<>0) then
                begin {special case, memref and ordconst can be combined in one compare}
                  emit_loc_ord(_cmp_, GetSize(p^.left^.return), p^.loc, p^.right^.loc.value);
                  goto jumps; {horrible programming, but it works}
                end;
              EmitIntegerLoad(i, p^.left^.return, p^.loc);
              p^.loc.l:=register;     {variable is now in a register}
              p^.loc.reg:=i;
            end;
        end;
        if p^.right^.loc.l<>register then
          begin
            size:=GetSize(p^.right^.return);
            case p^.right^.loc.l of
            ordconst : begin {direct compare}
                         if p^.right^.loc.value=0 then
                           emit_reg_reg(_test_, size, p^.loc.reg, size, p^.loc.reg) {faster}
                         else
                           emit_reg_ord(_cmp_, size, p^.loc.reg, p^.right^.loc.value);
                         ReleaseLocRegs(p^.loc);
                       end;
            else       begin
                         emit_reg_loc(_cmp_, size, p^.loc.reg, size, p^.right^.loc);
                         ReleaseLocRegs(p^.right^.loc);
                       end;
            end
          end
        else
          begin
            emit_reg_reg(_cmp_, _dword, p^.loc.reg, _dword, p^.right^.loc.reg);
            ReleaseLocRegs(p^.loc);
            ReleaseLocRegs(p^.right^.loc);
          end;
        end;
jumps:
  size:=GetSize(p^.return);
  if Current_Label=0 then
    case p^.op of
    __equal      :   emit_reg(_setz_, size, p^.loc.reg);
    __not_eq     :   emit_reg(_setnz_, size, p^.loc.reg);
    __greater    :   if p^.signed=TRUE then emit_reg(_setg_, size, p^.loc.reg)
                                       else emit_reg(_seta_, size, p^.loc.reg);
    __less       :   if p^.signed=TRUE then emit_reg(_setl_, size, p^.loc.reg)
                                       else emit_reg(_setb_, size, p^.loc.reg);
    __greater_eq :   if p^.signed=TRUE then emit_reg(_setge_, size, p^.loc.reg)
                                       else emit_reg(_setae_, size, p^.loc.reg);
    __less_eq    :   if p^.signed=TRUE then emit_reg(_setle_, size, p^.loc.reg)
                                       else emit_reg(_setbe_, size, p^.loc.reg);
    end
  else
  case p^.op of
    __equal      :   emit_lab(_jnz_, _near_, LabelString(Current_Label));
    __not_eq     :   emit_lab(_jz_, _near_, LabelString(Current_Label));
    __greater    :   if p^.signed=TRUE then emit_lab(_jle_, _near_, LabelString(Current_Label))
                                       else emit_lab(_jbe_, _near_, LabelString(Current_Label));
    __less       :   if p^.signed=TRUE then emit_lab(_jge_, _near_, LabelString(Current_Label))
                                       else emit_lab(_jae_, _near_, LabelString(Current_Label));
    __greater_eq :   if p^.signed=TRUE then emit_lab(_jl_, _near_, LabelString(Current_Label))
                                       else emit_lab(_jb_, _near_, LabelString(Current_Label));
    __less_eq    :   if p^.signed=TRUE then emit_lab(_jg_, _near_, LabelString(Current_Label))
                                       else emit_lab(_ja_, _near_, LabelString(Current_Label));
  end;
  if current_label<>0 then ReleaseRegister(i);
end;

procedure EmitPortOut({var} left, right: pTree);
var
  eax_pushed,
  edx_pushed: boolean;

begin
  eax_pushed:=FALSE;
  edx_pushed:=FALSE;
  left^.loc.name:=''; {left location record contains index (or port number)}

   if (right^.loc.l=register) and (right^.loc.reg<>eax) then
     begin
       if not(eax in freereg) then
         begin
           emit_reg(_push_, _dword, eax);
           eax_pushed:=TRUE;
         end;
       if right^.loc.reg<>eax then
         emit_reg_reg(_mov_, _dword, eax, _dword, right^.loc.reg);
     end
   else
     if not (edx in freereg) then
       begin
         emit_reg(_push_, _dword, edx);
         edx_pushed := true;
       end;
  if (left^.loc.base=none) and (left^.loc.index=none) then
    emit_reg_ord(_mov_, _dword, edx, left^.loc.offset)
  else
    emit_reg_loc(_mov_, _dword, edx, GetSize(left^.return), left^.loc);
  ReleaseLocRegs(left^.loc);

  case right^.loc.l of
  ordconst : emit_reg_ord(_mov_, _dword, eax, right^.loc.value);
  register : ;
  else       EmitIntegerLoad(eax, right^.return, right^.loc);
  end;

  ReleaseLocRegs(right^.loc);
  emit_reg_reg(_out_, _word, edx, GetSize(left^.return), eax);

  if edx_pushed then emit_reg(_pop_, _dword, edx);
  if eax_pushed then emit_reg(_pop_, _dword, eax);
end;

procedure DoAssignment(var p : pTree);

var OldLabel: integer;
    {load    : string;}
    inreg   : boolean;
    i       : regs;
    x, size : longint;

begin
  inreg:=FALSE;
  OldLabel:=Current_Label;{save label}
  Current_Label:=0;      {label empty, no jumps emitted}
  GenerateCode(p^.right);
  Current_Label:=OldLabel;{restore label}
  GenerateCode(p^.left);

  case p^.left^.loc.l of
  port      : begin
                EmitPortOut(p^.left, p^.right);
                Exit;
              end;
  register  : inreg:=TRUE;
  end;
  size:=GetSize(p^.left^.return);
  if (p^.right^.sym<>NIL) and (p^.left^.sym<>NIL) and
     (p^.left^.sym^.symbol=_variable) and (p^.right^.sym^.symbol=_variable) and
     (p^.left^.sym^.mmxable and p^.right^.sym^.mmxable) then
    begin
      emit_mmx_loc(_movq_, 0, _qword, p^.right^.loc);
      emit_loc_mmx(_movq_, _qword, p^.left^.loc, 0);
    end
  else
  if p^.left^.return^.typedef=_StringDef then
    begin {generate code for: s:=''; }
      if (p^.right^.op=__stringconst) and (p^.right^.s=NIL{^[0]=#0}) then
        if inreg then emit_reg_ord(_mov_, _byte, p^.left^.loc.reg, 0)
                 else emit_loc_ord(_mov_, _byte, p^.left^.loc, 0)
      else
        begin
          if (p^.right^.return^.typedef=_SubRangeDef) and
             (p^.right^.return^.subrangetyp=uchar) then {we have a char to assign}
            begin
              if p^.right^.loc.l=ordconst then
                emit_loc_ord(_mov_, _word, p^.left^.loc, 256*ord(p^.right^.loc.value)+1)
              else
                begin
                  case p^.right^.loc.l of
                  directmem,
                  memref    : begin
                                i:=GetRegister;
                                emit_reg_loc(_mov_, _byte, i, _byte, p^.right^.loc);
                              end;
                  register  : begin
                                i:=p^.right^.loc.reg;
                              end;
                  end;
                  emit_loc_ord(_mov_, _byte, p^.left^.loc, 1);
                  inc(p^.left^.loc.offset);
                  emit_loc_reg(_mov_, _byte, p^.left^.loc, _byte, i);
                  ReleaseRegister(i);
                end
            end
          else
            begin
              if (p^.right^.s=NIL) or (p^.left^.return^.length > ord(p^.right^.s^[0])) then
                x:=p^.left^.return^.length
              else
                x:=length(p^.right^.s^);
              EmitStringCopy(p^.left^.loc, p^.right^.loc, x);
              ReleaseLocRegs(p^.left^.loc);
            end;
        end;
    end
  else
  case p^.right^.loc.l of
  port      : begin
                i:=GetRegister;
                EmitPortIn(i, p^.right^.return, p^.right^.loc);
                emit_loc_reg(_mov_, size, p^.left^.loc, size, i);
                ReleaseRegister(i);
              end;
  directmem,
  memref    : if ( p^.left^.return^.typedef = _RealDef ) then
                begin
                  emit_loc(_fld_, size, p^.right^.loc);
                  emit_loc(_fstp_, size, p^.left^.loc);
                end
              else
                EmitMemMem(size, p^.left^.loc, p^.right^.loc);
  ordconst  : if inreg then emit_reg_ord(_mov_, size, p^.left^.loc.reg, p^.right^.loc.value)
                       else emit_loc_ord(_mov_, size, p^.left^.loc, p^.right^.loc.value);
  register  : if inreg then
                begin
                  if p^.left^.loc.reg<>p^.right^.loc.reg then
                    emit_reg_reg(_mov_, size, p^.left^.loc.reg, size, p^.right^.loc.reg)
                end
              else
                emit_loc_reg(_mov_, size, p^.left^.loc, size, p^.right^.loc.reg);
  fpu       : emit_loc(_fstp_, size, p^.left^.loc);
  end;
  ReleaseLocRegs(p^.left^.loc);
  ReleaseLocRegs(p^.right^.loc);
end;

procedure DoBlock(var p: pTree);

var
   p1 : ptree;

begin
  p1:=p^.left;
  while p1<>NIL do
  begin
    if (p1^.right<>NIL) then {ignore statement}
      begin
        if not Options.AllowRegisterCalling then InitRegisters;
        GenerateCode(p1^.right);
      end;
    p1:=p1^.left;
  end;
end;

procedure DoFunctionResult(var p: pTree);

var i:regs;
    a, size: longint;
begin
  ClearLoc(p^.loc);
  case p^.sym^.ReturnType^.typedef of
  _PointerDef,
  _RealDef,
  _BooleanDef,
  _EnumeratedDef,
  _SubRangeDef: begin
                  p^.loc.base:=ebp; {stackframe register}
                  {p^.loc.offset:= - p^.sym^.LocalSize;}
                  size:= p^.sym^.LocalSize;
                  a:=size and (Options.AlignData-1);
                  if a<>0 then
                    stacksize:=Options.AlignData-a + size;
                  p^.sym^.LocalSize := stacksize;
                  p^.loc.offset:= - stacksize; {stack is aligned now!}
                end;
  _ArrayDef,
  _RecordDef,
  _StringDef : begin
                 p^.loc.base:=ebp; {stackframe register}
                 p^.loc.offset:= p^.sym^.ParamSize + 4; {result on top of the parameters}
                 i:=GetRegister;
                 emit_reg_loc(_mov_, _dword, i, _dword, p^.loc);
                 p^.loc.offset:=0; {no offset}
                 p^.loc.base:=i; {address of variable in register 'i'}
               end
  else         LineError(p^.line, 'Type not supported as function return');
  end;
end;

procedure DoParam(var p : ptree; sym: pSymbolRecord; loadinreg:boolean);

var t : boolean;
    i: regs;
    varsize: longint;
    loc :location;
    push_eax,
    push_edx,
    push_ecx: boolean;


begin
  if (loadinreg=TRUE) then
    begin
      if (p^.right<>NIL) then DoParam(p^.right, sym^.prev, loadinreg);
      GenerateCode(p^.left);
      ReleaseLocRegs(p^.left^.loc); {register can be modified for new load}
      case sym^.vartype of
      _ParmConst,
      _ParmVar:   begin
                    if not (p^.left^.loc.l in [memref, directmem]) then
                      LineError(p^.line,'Variable identifier expected')
                    else
                      begin
                        i:=GetRegisterNormal;
                        emit_reg_loc(_mov_, _dword, i, _offset, p^.left^.loc);
                      end;
                  end;
      _ParmValue: case p^.left^.return^.typedef of
                  _RealDef  : case p^.left^.loc.l of
                              register,
                              ordconst: LineError(p^.line, 'DoParam(real), Not yet supported');
                              fpu     : ; {do nothing, it's already there}
                              memref  : begin
                                          emit_loc(_fld_, GetSize(p^.left^.return), p^.left^.loc);
                                          ReleaseLocRegs(p^.left^.loc);
                                        end;
                              end;
                  _StringDef,
                  _RecordDef,
                  _ArrayDef : LineError(p^.line, 'Not supported when passing parameters through registers, use VAR');
                  else
                    case p^.left^.loc.l of
                     ordconst: begin
                                 i:=GetRegisterNormal;
                                 emit_reg_ord(_mov_, _dword, i, p^.left^.loc.value);
                               end;
                     register: begin
                                 i:=GetRegister32;
                                 emit_reg_reg(_mov_, _dword, i, _dword, p^.left^.loc.reg);
                               end;
                     fpu     : begin
                                 emit_reg_ord(_mov_, _dword, esp, 8);
                                 SetLoc(loc, esp, none, 0,0);
                                 emit_loc(_fstp_, GetSize(p^.left^.return), loc);
                               end;
                     memref  : begin
                                 i:=GetRegisterNormal;
                                 EmitIntegerLoad(i, p^.left^.return, p^.left^.loc);
                               end;
                    end;
                  end;
      else        LineError(p^.line, 'DoParam: vartype not defined');
      end;
    end
  else
    begin
      GenerateCode(p^.left);
      case sym^.vartype of
      _RegVar :   begin
                    i:=sym^.r;
                    case p^.left^.loc.l of
                    ordconst: emit_reg_ord(_mov_, _dword, i, p^.left^.loc.value);
                    register: emit_reg_reg(_mov_, _dword, i, _dword, p^.left^.loc.reg);
                    memref  : EmitIntegerLoad(i, p^.left^.return, p^.left^.loc);
                    end;
                    ReleaseLocRegs(p^.left^.loc);
                  end;
      _ParmVar:   begin
                    if (p^.left^.loc.l<>memref) and (p^.left^.loc.l<>directmem) then
                      LineError(p^.line,'Variable identifier expected');
                    EmitPushAddress(p^.left^.loc);
                    ReleaseLocRegs(p^.left^.loc);
                  end;
      _ParmConst: case DoCheck(p^.left) of
                  _FileDef  : LineError(p^.line,'File variable expected');
                  _StringDef,
                  _RecordDef,
                  _ArrayDef : begin
                                EmitPushAddress(p^.left^.loc);
                                ReleaseLocRegs(p^.left^.loc);
                              end
                  end;
      _ParmValue: case p^.left^.loc.l of
                  ordconst: begin
                              EmitPushImmediate(p^.left^.loc.value);
                              ReleaseLocRegs(p^.left^.loc);
                            end;
                  register: begin
                              EmitPushRegister(p^.left^.return{sym^.typedef}, p^.left^.loc);
                              ReleaseLocRegs(p^.left^.loc);
                            end;
                  fpu     : begin
                              emit_reg_ord(_sub_, _dword, esp, 8);
                              SetLoc(loc, esp, none, 0, 0);
                              emit_loc(_fstp_, GetSize(p^.left^.return), loc);
                            end;
                  memref  : begin
                              case sym^.typedef^.typedef of
                              _ArrayDef,
                              _RecordDef,
                              _StringDef : begin
                                             varsize:=GetSize(sym^.typedef);
                                             emit_reg_ord(_sub_, _dword, esp, varsize);
                                             SetLoc(loc, esp, none, 8, 0);
                                             if sym^.typedef^.typedef=_StringDef then
                                               EmitStringCopy(loc, p^.left^.loc, {p^.left^.return^.length} 255)
                                             else
                                               begin
                                                 SetLoc(loc, esp, none, 0, 0);
                                                 if varsize in [1, 2, 4] then
                                                   begin
                                                     i:=GetRegister;
                                                     emit_reg_loc(_mov_, varsize, i, varsize, p^.left^.loc); {source}
                                                     emit_loc_reg(_mov_, varsize, loc, varsize, i);    {dest}
                                                     ReleaseRegister(i);
                                                   end
                                                 else
                                                   begin
                                                     emit_reg_loc(_lea_, _dword, esi, _nothing, p^.left^.loc);
                                                     emit_reg_loc(_lea_, _dword, edi, _nothing, loc);
                                                     if ecx in freereg then
                                                       push_ecx:=false  {ecx needed for counter}
                                                     else
                                                       begin
                                                         emit_reg(_push_, _dword, ecx);
                                                         push_ecx:=true;
                                                       end;
                                                     emit_non(_cld_);
                                                     emit_reg_ord(_mov_, _dword, ecx, varsize);
                                                     emit_lab(_rep_, _nothing, 'movsb'); {hack to allow an instruction as opt}
                                                     if push_ecx then emit_reg(_pop_, _dword, ecx);
                                                   end;
                                               end;
                                               {LineError(p^.line, 'DoParam: not yet supported');}
                                           end
                              else         EmitPushMemory(p^.left^.return{sym^.typedef}, p^.left^.loc);
                              end;
                              ReleaseLocRegs(p^.left^.loc);
                            end;
                  else      LineError(p^.line, 'Error in processing parameters');
                  end
      else        LineError(p^.line, 'DoParam: vartype not defined');
      end;
      sym:=sym^.prev;
      if (p^.right)<>NIL then DoParam(p^.right, sym, loadinreg);
    end;
end;

function IsOrdinal(var typ: pTypeRecord): boolean;

begin
  if (typ^.typedef=_BooleanDef) or
     (typ^.typedef=_SubRangeDef) or
     (typ^.typedef=_EnumeratedDef) or
     (typ^.typedef=_PointerDef) then IsOrdinal:=TRUE
  else
     IsOrdinal:=FALSE;
end;

procedure DoWriteSubRange(typ: pTypeRecord);

begin
  if (typ<>NIL) and (typ^.typedef=_SubRangeDef) then
    case typ^.subrangetyp of
    uchar   : begin
                GetSymbol('_WRITECHAR'); {check to set used bit}
                emit_lab(_call_, _nothing, 'writechar');
              end;
    s8bit,
    s16bit,
    s32bit  : begin
                GetSymbol('_WRITESINT'); {check to set used bit}
                emit_lab(_call_, _nothing, 'writesint');
              end;
    u8bit,
    u16bit,
    u32bit  : begin
                GetSymbol('_WRITEUINT'); {check to set used bit}
                emit_lab(_call_, _nothing, 'writeuint');
              end;
    end;
end;

procedure DoInternalProcs(var p:pTree);

var temp: pTree;
    i: regs;
    t: boolean;
    loc, colonloc, fileloc: location;
    {addstring, filevariable: string;}
    op:opcode_num;
    tmp:location;
    emitflush: boolean;
    size: integer;
    return: pTypeRecord;
    ObjectList: pSymbolList;
    sym: pSymbolRecord;

begin
  case p^.sym^.internal of
  in_write,
  in_writeln : begin
                 temp:=ReverseTree(p^.left);
                 emitflush:=TRUE; {causes direct printing of the writeln's}
                 {check for file variable...}
                 if (temp<>NIL) and
                    (temp^.left<>NIL) and
                    (temp^.left^.sym<>NIL) and
                    (temp^.left^.sym^.symbol=_variable) and
                    (temp^.left^.sym^.typedef<>NIL) and
                    (temp^.left^.sym^.typedef^.typedef=_FileDef) and
                    (p^.left<>NIL) then
                   begin
                     GenerateCode(temp^.left); {compose the name, in case of records, arrays}
                     fileloc:=temp^.left^.loc;
                     temp:=temp^.right; {advance to next writeln-parameter}
                     emitflush:=FALSE; {flush is handled in RTL}
                   end
                 else
                   begin
                     fileloc.l:=memref;
                     ClearLoc(fileloc);
                     sym:=GetSymbol('_OUTPUT'); {check to set used bit}
                     fileloc.name:=sym^.overloadedname;
                   end;
                  if (p^.left<>NIL) then
                   begin
                     repeat
                       {check for colon}
                       if (temp^.right<>NIL) and
                          (temp^.right^.op=__param) and
                          (temp^.right^.colon=TRUE) then
                         begin
                           GenerateCode(temp^.right^.left);
                           colonloc:=temp^.right^.left^.loc;
                           return:=temp^.right^.left^.return;
                         end
                       else
                         begin
                           colonloc.l:=ordconst;
                           ClearLoc(colonloc);
                           colonloc.value:=0;
                         end;
                       case colonloc.l of
                       directmem,
                       memref    : EmitPushMemory(return, colonloc);
                       register  : EmitPushRegister(return, colonloc);
                       ordconst  : EmitPushImmediate(colonloc.value);
                       fpu       : LineError(temp^.line, 'Integer expected');
                       end;
                       case temp^.left^.op of
                       __charconst  : begin
                                        EmitPushImmediate(ord(temp^.left^.c));
                                        emit_loc(_push_, _offset, fileloc);
                                        GetSymbol('_WRITECHAR'); {check to set used bit}
                                        emit_lab(_call_, _nothing, 'writechar');
                                      end;
                       __stringconst: begin
                                        GenerateCode(temp^.left);
                                        EmitPushAddress(temp^.left^.loc);
                                        emit_loc(_push_, _offset, fileloc);
                                        GetSymbol('_WRITESTRING'); {check to set used bit}
                                        emit_lab(_call_, _nothing, 'writestring');
                                      end
                       else begin
                              GenerateCode(temp^.left);
                              if (temp^.left^.loc.l<>memref) and
                                 (temp^.left^.loc.l<>directmem) then
                                begin
                                  case temp^.left^.loc.l of
                                  register : begin
                                               if (temp^.left^.return^.typedef=_SubRangeDef) or
                                                  (temp^.left^.return^.typedef=_BooleanDef) then
                                                 case temp^.left^.return^.subrangetyp of
                                                 u8bit : emit_reg_ord(_and_, _dword, temp^.left^.loc.reg, $FF);
                                                 u16bit: emit_reg_ord(_and_, _dword, temp^.left^.loc.reg, $FFFF);
                                                 s8bit,
                                                 s16bit: emit_reg_reg(_movsx_, _dword, temp^.left^.loc.reg,
                                                         GetSize(temp^.left^.return), temp^.left^.loc.reg)
                                                 end;

                                               emit_reg(_push_, _dword, temp^.left^.loc.reg);
                                               emit_loc(_push_, _offset, fileloc);

                                               if temp^.left^.return^.typedef=_BooleanDef then
                                                 begin
                                                   GetSymbol('_WRITEBOOLEAN'); {check to set used bit}
                                                   emit_lab(_call_, _nothing, 'writeboolean')
                                                 end
                                               else
                                                 if temp^.left^.return^.typedef=_PointerDef then
                                                   begin
                                                     GetSymbol('_WRITEPOINTER'); {check to set used bit}
                                                     emit_lab(_call_, _nothing, 'writepointer');
                                                   end
                                                 else
                                                   DoWriteSubRange(temp^.left^.return);
                                             end;
                                  ordconst : begin
                                               EmitPushImmediate(temp^.left^.loc.value);
                                               emit_loc(_push_, _offset, fileloc);
                                               if temp^.left^.return^.typedef=_BooleanDef then
                                                 begin
                                                   GetSymbol('_WRITEBOOLEAN'); {check to set used bit}
                                                   emit_lab(_call_, _nothing, 'writeboolean')
                                                 end
                                               else
                                                 DoWriteSubRange(temp^.left^.return);
                                             end;
                                  fpu      : begin
                                               emit_reg_ord(_sub_, _dword, esp, 8);
                                               SetLoc(loc, esp, none, 0,0);
                                               emit_loc(_fstp_, _qword, loc);
                                               emit_loc(_push_, _offset, fileloc);
                                               GetSymbol('_WRITEREAL'); {check to set used bit}
                                               emit_lab(_call_, _nothing, 'writereal');
                                             end;
                                  end;
                                end
                              else
                                case temp^.left^.return^.typedef of
                                _SubRangeDef: begin
                                                EmitPushMemory(temp^.left^.return, temp^.left^.loc);
                                                emit_loc(_push_, _offset, fileloc);
                                                DoWriteSubRange(temp^.left^.return);
                                              end;
                                _PointerDef:  begin
                                                EmitPushMemory(temp^.left^.return, temp^.left^.loc);
                                                emit_loc(_push_, _offset, fileloc);
                                                GetSymbol('_WRITEPOINTER'); {check to set used bit}
                                                emit_lab(_call_, _nothing, 'writepointer');
                                              end;
                                _BooleanDef:  begin
                                                EmitPushMemory(temp^.left^.return, temp^.left^.loc);
                                                emit_loc(_push_, _offset, fileloc);
                                                GetSymbol('_WRITEBOOLEAN'); {check to set used bit}
                                                emit_lab(_call_, _nothing, 'writeboolean');
                                              end;
                                _StringDef  : begin
                                                EmitPushAddress(temp^.left^.loc);
                                                emit_loc(_push_, _offset, fileloc);
                                                GetSymbol('_WRITESTRING'); {check to set used bit}
                                                emit_lab(_call_, _nothing, 'writestring');
                                              end;
                                _RealDef    : begin
                                                EmitPushMemory(temp^.left^.return, temp^.left^.loc);
                                                emit_loc(_push_, _offset, fileloc);
                                                GetSymbol('_WRITEREAL'); {check to set used bit}
                                                emit_lab(_call_, _nothing, 'writereal');
                                              end;
                                else LineError(p^.line,'Cannot write this variable');
                                end;
                            end;
                        end;
                        { skip the colon node, it's processed above!}
                        if (temp^.right<>NIL) and (temp^.right^.colon=TRUE) then temp:=temp^.right;
                        temp:=temp^.right;
                      until temp=NIL;
                 end;
                 if p^.sym^.internal=in_writeln then
                   begin
                     emit_loc(_push_, _offset, fileloc);
                     GetSymbol('_WRITELINE'); {check to set used bit}
                     emit_lab(_call_, _nothing, 'writeline');
                   end;
                 if emitflush=TRUE then
                   begin
                     GetSymbol('_FLUSHOUTPUT'); {check to set used bit}
                     emit_lab(_call_, _nothing, 'flushoutput');
                   end;
                 p^.left:=ReverseTree(temp); {restore original tree}
               end;
  in_read,
  in_readln : begin
                 temp:=ReverseTree(p^.left);
                 if (temp<>NIL) and
                    (temp^.left<>NIL) and
                    (temp^.left^.sym<>NIL) and
                    (temp^.left^.sym^.typedef<>NIL) and
                    (temp^.left^.sym^.typedef^.typedef=_FileDef) and
                    (p^.left<>NIL) then
                   begin
                     GenerateCode(temp^.left); {compose the name, in case of records, arrays}
                     {filevariable:=asdef.offset + CreateName(temp^.left^.loc); {create filevariable-string}
                     fileloc:=temp^.left^.loc;
                     temp:=temp^.right; {advance to next writeln-parameter}
                   end
                 else
                   begin
                     fileloc.l:=memref;
                     ClearLoc(fileloc);
                     sym:=GetSymbol('_INPUT'); {check to set used bit}
                     fileloc.name:=sym^.overloadedname;
                   end;

                 if (p^.left<>NIL) then
                   repeat
                     GenerateCode(temp^.left);
                     case temp^.left^.return^.typedef of
                     _SubRangeDef: begin
                                     EmitPushAddress(temp^.left^.loc);
                                     emit_loc(_push_, _offset, fileloc);
                                     GetSymbol('_READINT'); {check to set used bit}
                                     emit_lab(_call_, _nothing, 'readint');
                                   end;
                     _StringDef  : begin
                                     EmitPushImmediate(temp^.left^.return^.length);
                                     EmitPushAddress(temp^.left^.loc);
                                     emit_loc(_push_, _offset, fileloc);
                                     GetSymbol('_READSTRING'); {check to set used bit}
                                     emit_lab(_call_, _nothing, 'readstring');
                                   end;
                     _RealDef    : begin
                                     EmitPushAddress(temp^.left^.loc);
                                     emit_loc(_push_, _offset, fileloc);
                                     GetSymbol('_READREAL'); {check to set used bit}
                                     emit_lab(_call_, _nothing, 'readreal');
                                   end;
                     end;
                     temp:=temp^.right;
                   until temp=NIL;
                 if p^.sym^.internal=in_readln then
                   begin
                     emit_loc(_push_, _offset, fileloc);
                     GetSymbol('_READLINE'); {check to set used bit}
                     emit_lab(_call_, _nothing, 'readline');
                   end;
                 p^.left:=ReverseTree(temp); {restore original tree}
              end;
  in_dec,
  in_inc    : begin
                temp:=ReverseTree(p^.left);
                GenerateCode(temp^.left);
                if temp^.left^.loc.l=ordconst then LineError(temp^.line, 'Variable expected');
                if not IsOrdinal(temp^.left^.return) then LineError(temp^.line, 'Ordinal variable expected');
                if p^.sym^.internal=in_dec then op:=_dec_ else op:=_inc_;
                if temp^.right=NIL then
                  case temp^.left^.loc.l of
                  directmem,
                  memref    : emit_loc(op, GetSize(temp^.left^.return), temp^.left^.loc);
                  register  : emit_reg(op, GetSize(temp^.left^.return), temp^.left^.loc.reg);
                  else        LineError(p^.line, 'error in inc/dec');
                  end
                else
                  begin
                    loc:=temp^.left^.loc;
                    if p^.sym^.internal=in_dec then op:=_sub_ else op:=_add_;
                    while temp^.right<>NIL do
                    begin
                      temp:=temp^.right;
                      if not IsOrdinal(temp^.left^.return) then LineError(temp^.line, 'Ordinal variable expected');
                      GenerateCode(temp^.left); {fill the loc record;}
                      size:=GetSize(temp^.left^.return);
                      case temp^.left^.loc.l of
                      directmem,
                      memref    : begin
                                    i:=GetRegister;
                                    EmitIntegerLoad(i, temp^.left^.return, temp^.left^.loc);
                                    emit_loc_reg(op, size, loc, size, i);
                                    ReleaseRegister(i);
                                  end;
                      ordconst  : emit_loc_ord(op, size, loc, temp^.left^.loc.value);
                      register  : emit_loc_reg(op, size, loc, size, temp^.left^.loc.reg);
                      end;
                    end;
                  end;
                temp:=ReverseTree(p^.left);
              end;
  in_succ,
  in_pred   : begin
                temp:=ReverseTree(p^.left);
                GenerateCode(temp^.left);
                if not IsOrdinal(temp^.left^.return) then LineError(temp^.line, 'Ordinal expected');
                if p^.sym^.internal=in_pred then op:=_dec_ else op:=_inc_;
                case temp^.left^.loc.l of
                directmem,
                memref    : begin
                              i:=GetRegister;
                              EmitIntegerLoad(i, temp^.left^.return, temp^.left^.loc);
                            end;
                register  : i:=temp^.left^.loc.reg;
                else        LineError(p^.line, 'error in succ/pred');
                end;
                emit_reg(op, _dword, i);
                ReleaseLocRegs(p^.loc);
                p^.loc.l:=register;
                p^.loc.reg:=i;
                temp:=ReverseTree(p^.left);
              end;
  in_dispose,
  in_new:     begin
                temp:=ReverseTree(p^.left);
                GenerateCode(temp^.left);
                if (temp^.left^.op<>__var) and
                   (temp^.left^.return<>NIL) and
                   (temp^.left^.return^.typedef=_PointerDef) and
                   (temp^.left^.return^.PointerTo^.typedef^.typedef=_ObjectDef) then
                  begin {Extended new: x:=new(p: pointer, init: constructor}
                    if p^.sym^.internal=in_new then
                      begin
                        loc.l:=memref;
                        ClearLoc(loc);
                        loc.name:=VMTPrefix+temp^.left^.return^.PointerTo^.name;
                        emit_reg_loc(_mov_, _dword, esi, _offset, loc);
                        GetSymbol('_CREATEOBJECT'); {check to set used bit}
                        emit_lab(_call_, _nothing, 'createobject');
                        ObjectList:=temp^.left^.return^.PointerTo^.typedef^.RecordTable;
                        AddList(ObjectList);
                        temp:=temp^.right;
                        if (temp<>NIL) then {call constructor}
                          begin
                            emit_reg(_push_, _dword, edi);
                            if (temp^.left^.sym^.prop and p_constructor) = 0 then Expected('constructor');
                            GenerateCode(temp^.left);
                            emit_reg(_pop_, _dword, edi);
                          end
                        else

                        RemoveList(ObjectList);
                        p^.loc.l:=register;
                        p^.loc.reg:=edi;
                      end
                    else
                      begin {in_dispose}
                        emit_reg_loc(_mov_, _dword, esi, _offset, temp^.left^.loc);
                        GetSymbol('_DESTROYOBJECT'); {check to set used bit}
                        emit_lab(_call_, _nothing, 'destroyobject');
                        ObjectList:=temp^.left^.return^.PointerTo^.typedef^.RecordTable;
                        AddList(ObjectList);
                        temp:=temp^.right;
                        if (temp<>NIL) then {call constructor}
                          begin
                            if (temp^.left^.sym^.prop and p_destructor) = 0 then Expected('destructor');
                            GenerateCode(temp^.left);
                          end;
                        RemoveList(ObjectList);
                      end
                  end
                else
                  begin
                    if (temp^.left^.return<>NIL) and
                       (temp^.left^.return^.typedef<>_PointerDef) then
                         LineError(temp^.line, 'Pointer variable expected');
                      EmitPushImmediate(GetSize(temp^.left^.sym^.typedef^.PointerTo^.typedef));
                    case temp^.left^.loc.l of
                    directmem,
                    memref    : begin
                                  EmitPushAddress(temp^.left^.loc);
                                  ReleaseLocRegs(temp^.left^.loc);
                                end;
                    else        LineError(p^.line, 'error in new/dispose');
                    end;
                    if p^.sym^.internal=in_dispose then
                      begin
                        GetSymbol('_FREEMEM'); {check to set used bit}
                        emit_lab(_call_, _nothing, 'freemem')
                      end
                    else
                      begin
                        GetSymbol('_GETMEM'); {check to set used bit}
                        emit_lab(_call_, _nothing, 'getmem')
                      end;
                  end;
              end;
  in_length : begin
                temp:=ReverseTree(p^.left);
                GenerateCode(temp^.left);
                if (temp^.left^.return<>NIL) and
                   (temp^.left^.return^.typedef<>_StringDef) and
                   ((temp^.left^.return^.typedef<>_SubRangeDef) and
                    (temp^.left^.return^.subrangetyp<>uchar)) then LineError(temp^.line, 'String type expected');
                case temp^.left^.loc.l of
                directmem,
                memref    : begin
                              ReleaseLocRegs(temp^.left^.loc);
                              i:=GetRegister32;
                              emit_reg_loc(_movzx_, _dword, i, _byte, temp^.left^.loc);
                            end;
                register  : i:=temp^.left^.loc.reg;
                else        LineError(p^.line, 'error in length');
                end;
                p^.loc.l:=register;
                p^.loc.reg:=i;
                temp:=ReverseTree(p^.left);
              end;
  in_assigned:begin
                temp:=ReverseTree(p^.left);
                GenerateCode(temp^.left);
                if (temp^.left^.return<>NIL) and
                   (temp^.left^.return^.typedef<>_PointerDef) then LineError(temp^.line, 'Pointer expected');
                case temp^.left^.loc.l of
                directmem,
                memref    : begin
                              i:=GetRegister32;
                              emit_reg_loc(_mov_, _dword, i, _dword, temp^.left^.loc);
                            end;
                register  : begin
                              i:=temp^.left^.loc.reg;
                            end;
                else        LineError(p^.line, 'error in length');
                end;
                p^.loc.l:=register;
                p^.loc.reg:=i;
                temp:=ReverseTree(p^.left);
              end;
  in_sizeof : ; {completely handled in P32_OPT.PAS}
  in_ord    : ; {completely handled in P32_OPT.PAS}
  in_chr    : ; {completely handled in P32_OPT.PAS}
  end;
end;

function ProcessParameters(var sym:pSymbolRecord;var p: pTree):string;
var
    t_call, t_param: pTypeRecord;
    found: boolean;
    s: string;
    {para:pSymbolRecord;}
    overl_sym : pSymbolRecord;
    param_proc  :pTree;
    param_caller: pSymbolRecord;
    temp: pTree;
begin
  s:='';
  if sym^.nextoverloaded<>NIL then {there are more procedure with the same name}
    begin
      if p^.left=NIL then {simple, no parameters}
        begin
          sym:=GetOverloadedProc(sym, sym^.overloadedname);
          if sym=NIL then LineError(p^.line, 'Cannot find overloaded procedure');
          s:=sym^.overloadedname;
        end
      else
        begin {ok, there are parameters, they need to be checked for type differences}
          temp:=ReverseTree(p^.left); {reverse the parameter list}
          s:=''; {reset proc-call string}
          overl_sym:=sym;
          repeat
            if overl_sym^.parameter<>NIL then param_caller:=overl_sym^.parameter^.first
                                         else param_caller:=NIL;
            param_proc:=temp;
            found:=true; {make sure it enters the loop}
            while (((param_proc<>NIL) and (param_proc^.op=__param)) or (param_caller<>NIL)) and
                   found do {there are more parameters}
              begin
                t_param:=NIL;
                t_call:=NIL;
                if param_caller<>NIL then t_param:=param_caller^.typedef;
                if param_proc<>NIL then t_call :=param_proc^.left^.return;
                found:=false;
                if ((t_param<>NIL) and (t_param^.typedef=_EmptyDef)) or
                    ((t_call<>NIL) and (t_call^.typedef=_EmptyDef)) then found:=true;
                    if (((t_param<>NIL) and (t_call<>NIL)) and (t_param^.typedef=t_call^.typedef)) then
                      begin
                        case t_call^.typedef of
                        _FileDef: begin  {filetypes are incompatible...so double check them}
                                    if t_param^.filetyp=t_call^.filetyp then found:=true;
                                  end;
                        else      found:=true;
                        end;
                      end;
                {set symbols / tree for next type check}
                if param_caller<>NIL then param_caller:=param_caller^.next;
                if param_proc<>NIL then param_proc  :=param_proc^.right;
              end;
            if found then
              begin
                s:=overl_sym^.overloadedname;
                break
              end;
            overl_sym:=overl_sym^.nextoverloaded;
          until overl_sym=NIL;
          if sym^.usedregs=[] then p^.left:=ReverseTree(temp);
          sym:=GetOverloadedProc({overl_}sym, s); {Is this procedure availabl in the list of overloaded proc's?}
          if sym=NIL then LineError(p^.line, 'Cannot find overloaded procedure');
          DoParam(p^.left, {p^.}sym^.parameter^.rear, ((sym^.prop and p_register)<>0));
        end;
    end
  else
    begin {there are parameters}
      if p^.left<>NIL then
        DoParam(p^.left, sym^.parameter^.rear, ((sym^.prop and p_register)<>0)); {there are parameters}
      s:=sym^.overloadedname;
    end;
  ProcessParameters:=s;
end;

procedure DoCall(var p : pTree);

var overloadedname, s:string;
    procvar, sym:pSymbolRecord;
    push_ecx,
    push_edx,
    push_eax: boolean;
    i, i1:regs;
    LevelDiff: longint; { for pushing the PROPER lexical parent link in nested procs... }
    loc, tmp:location;
    a1, a2 : pAsmRecord;

begin
  procvar:=NIL;
  s:=p^.sym^.name;

  push_eax:=FALSE;
  push_edx:=FALSE;
  push_ecx:=FALSE;

  if p^.sym^.internal<>no then
    begin
      DoInternalProcs(p);
      sym:=p^.sym;
    end
  else
  begin
    if (p^.sym^.symbol=_variable) and
       (p^.sym^.typedef^.typedef=_ProcedureDef) then {procedural variable}
      begin
        sym:=NewSymbol;
        procvar:=sym;
        sym^.returntype:=p^.sym^.typedef^.returntype;
        sym^.parameter :=p^.sym^.typedef^.parameter;
      end
    else
      sym:=GetSymbol(s);

    if sym=NIL then LineError(p^.line, 'Lost procedure or function');

    if (eax in sym^.usedregs) and (eax in protreg) then
      begin
        emit_reg(_push_, _dword, eax);
        push_eax:=TRUE;
      end;
    if (edx in sym^.usedregs) and (edx in protreg) then
      begin
        emit_reg(_push_, _dword, edx);
        push_edx:=TRUE;
      end;
    if (ecx in sym^.usedregs) and (ecx in protreg) then
      begin
        emit_reg(_push_, _dword, ecx);
        push_ecx:=TRUE;
      end;

    if (sym^.symbol=_Func) then
      if ((sym^.returntype^.typedef=_PointerDef) or
          (sym^.returntype^.typedef=_SubRangeDef) or
          (sym^.returntype^.typedef=_BooleanDef)) then
        begin
          if not(eax in freereg) then
            begin {there is something loaded in EAX so save value of it, function will modify EAX}
              if not (eax in sym^.usedregs) then emit_reg(_push_, _dword, eax); {already pushed}
              ReleaseRegister(eax);
              push_eax:=TRUE;
            end
        end
      else
        if (sym^.returntype^.typedef=_StringDef) or
           (sym^.returntype^.typedef=_RecordDef) or
           (sym^.returntype^.typedef=_ArrayDef) then
          begin
            p^.loc.l:=memref;
            ClearLoc(p^.loc);
            p^.loc.base:=ebp; {stackframe register}
            {?????????}
            inc(stacksize, GetSize(p^.sym^.returntype));
            p^.loc.offset:= -stacksize;
            EmitPushAddress(p^.loc);
          end;

     if p^.sym_method<>NIL then {this is a call to a method! cannot be overloaded!}
       begin
         s:=ProcessParameters(p^.sym_method, p);
         sym:=p^.sym_method;
       end
     else
       s:=ProcessParameters(sym, p);

    if (sym^.prop and p_inline) = 0 then
      begin
        if sym^.plevel >= 2 then    {DB} { if procedure is nested then... }
          begin
            LevelDiff := sym^.plevel - CurrentLevel;
            if LevelDiff < 0 then
              Error('[DoCall] - proc can only call itself or its nested procs!');
            case LevelDiff of
              0: begin { eg. recursive call }
                   SetLoc(loc, ebp, none, 8, 0);
                   emit_loc(_push_, _dword, loc);
                 end;
              1: begin { eg. just the next nested procedure }
                   emit_reg(_push_, _dword, ebp);
                 end;
            else
              begin
                { for now, only handle procedures nested up to 1 level in. }
              end;
            end;
          end;
        if p^.sym_method<>NIL then {this is a call to a method!}
          begin
            if p^.right<>NIL then
              begin
                {only load ESI when method is called explicitely, like: myobject^.init,
                 otherwise current Self - pointer                                       }
                GenerateCode(p^.right);
                emit_reg_loc(_lea_, _dword, esi, _dword, p^.right^.loc);
              end;

            emit_reg(_push_, _dword, esi);
            if (p^.sym_method^.prop and p_virtual) <> 0 then
              begin
                loc.l:=memref;
                ClearLoc(loc);
                loc.base:=esi;
                emit_reg_loc(_mov_, _dword, edi, _dword, loc);
                ClearLoc(loc);
                loc.base:=edi;
                loc.offset:=p^.sym_method^.virtualindex;
                emit_loc(_call_, _dword, loc);
              end
            else
              emit_lab(_call_, _nothing, p^.sym_method^.overloadedname);
          end
        else
          begin
            if procvar<>NIL then
              begin
                loc.l:=memref;
                ClearLoc(loc);
                if s='' then loc.name:=p^.sym^.name
                        else loc.name:=s;
                emit_reg_loc(_lea_, _dword, edi, _nothing, loc);
                ClearLoc(loc);
                loc.base:=edi;
                emit_loc(_call_, _dword, loc);
              end
            else
              emit_lab(_call_, _nothing, s);
          end
      end
    else
      begin
        a1:=sym^.inlinefirst;
        while a1<>NIL do
          begin
            a2:=NewAsmEntry;
            a2^:=a1^;
            AddAsmEntry(a2);
            a1:=a1^.next;
          end;
      end;
  end;

  if (sym^.prop and p_register) <> 0 then InitRegisters; {release all register (used for parameters)}
  p^.return:=sym^.returntype; {return type, needed for type checking}
  if (p^.return<>NIL) and (p^.sym^.internal=no) then
  case p^.return^.typedef of
  _StringDef : ; {already defined earlier}
  _RealDef   : p^.loc.l:=fpu;
  else         begin
                 p^.loc.l:=register;
                 if push_eax=TRUE then
                   begin
                     i1:=GetRegister32;
                     if i1=eax then
                       begin
                         i:=GetRegister32;
                         ReleaseRegister(i1);
                       end
                     else
                       i:=i1;
                     emit_reg_reg(_mov_, _dword, i, _dword, eax);
                     if not (eax in sym^.usedregs) then emit_reg(_pop_, _dword, eax);
                     p^.loc.reg:=i;
                   end
                 else
                   begin
                     freereg:=freereg - [eax];
                     p^.loc.reg:=eax;
                   end;
               end;
  end;

  if push_ecx then emit_reg(_pop_, _dword, ecx);
  if push_edx then emit_reg(_pop_, _dword, edx);
  if push_eax then emit_reg(_pop_, _dword, eax);

  if procvar<>NIL then dispose(procvar);
end;

procedure DoIf(var p: pTree);

var
    OldLabel,
    IfTrueLabel, IfFalseLabel, LastLabel: integer;
    sym : pSymbolRecord;

begin
   IfTrueLabel := NewLabel;
   IfFalseLabel := NewLabel;
   LastLabel := NewLabel;

   OldLabel:=Current_Label;
   Current_Label:=IfFalseLabel;

   True_Label:=IfFalseLabel;
   False_Label:=IfTrueLabel;


   CheckShortBoolean(p^.left);
   GenerateCode(p^.left); {evaluation}

   Current_Label:=OldLabel;

   if p^.right<>NIL then
     begin
       PutLabel(IfTrueLabel);
       GenerateCode(p^.right); {Codeblock when true}
     end;
   if p^.elsetree<>NIL then
     begin
       if p^.right<>NIL then emit_lab(_jmp_, _nothing, LabelString(LastLabel));
       PutLabel(IfFalseLabel);
       GenerateCode(p^.elsetree); {Codeblock when false}
     end
   else PutLabel(IfFalseLabel);
   PutLabel(LastLabel);
end;

procedure DoCase(var p: pTree);

var compare_reg: regs;
    blocklabel,
    CaseTrueLabel, CaseFalseLabel, LastLabel:integer;
    sym : pSymbolRecord;


procedure DoCaseBlock(var p:pTree);

var nextlabel:integer;

begin
  NextLabel:=NewLabel;
  if (p^.elsetree<>NIL) then if (p^.left<>NIL) then
                               begin
                                 p^.left^.lab:=NewLabel;
                                 blocklabel:=p^.left^.lab;
                               end
                        else if (p^.left<>NIL) then
                               begin
                                 p^.left^.lab:=p^.lab;
                                 blocklabel:=p^.lab;
                               end;
  if (p^.left<>NIL) and (p^.left^.op=__caseblock) then
    begin
      DoCaseBlock(p^.left);
    end;
  case p^.right^.op of
  __subrange : LineError(p^.line, 'subranges not yet supported');
  __charconst,
  __ordconst : begin
                 emit_reg_ord(_cmp_, _dword, compare_reg, p^.right^.n);
                 emit_lab(_jnz_, _near_, LabelString(NextLabel));
               end;
  else         LineError(p^.line, 'constants or subrange expected');
  end;
  if p^.elsetree<>NIL then
    begin
      InitRegisters; {release all register, before the code generation of a case-block}
      if p^.left<>NIL then PutLabel(p^.left^.lab);
      GenerateCode(p^.elsetree); {contains block to be executed when evaluation is true}
      emit_lab(_jmp_, _nothing, LabelString(LastLabel));
    end
  else
    if {p^.left<>NIL} blocklabel<>-1 then
      emit_lab(_jmp_, _nothing, LabelString(blocklabel{p^.left^.lab}));
  PutLabel(NextLabel);
end;

begin
   blocklabel:=-1;
   CaseFalseLabel := NewLabel;
   LastLabel := NewLabel;

   GenerateCode(p^.left);
   if p^.left^.loc.l=register then
     compare_reg := p^.left^.loc.reg
   else
     begin
       ReleaseLocRegs(p^.left^.loc);
       compare_reg:=GetRegister;
       EmitIntegerLoad(compare_reg, p^.left^.return, p^.left^.loc);
       ReleaseRegister(compare_reg);
     end;
   if p^.right<>NIL then DoCaseBlock(p^.right); {Codeblock when true}

   if p^.elsetree<>NIL then
     begin
       PutLabel(CaseFalseLabel);
       GenerateCode(p^.elsetree); {Codeblock when false}
     end
   else
     PutLabel(CaseFalseLabel);

   PutLabel(LastLabel);
end;

procedure DoFor(var p: pTree);

var OldLabel2, OldLabel, TestLabel, DoneLabel : integer;
    SaveBreak, SaveContinue,LContinue_Label: integer;
    temp, count: location;
    extracompare : boolean;
    i: regs;
    counter,
    endvalue: pTree;
    cnt_size,
    end_size:longint;
    jump: opcode_num;

begin
  TestLabel := NewLabel;
  DoneLabel := NewLabel;

  SaveBreak := Break_Label;
  SaveContinue := Continue_label;

  Break_label:=DoneLabel;
  Continue_label := TestLabel;{NewLabel;}

  counter:=p^.left^.left;
  endvalue:=p^.right^.right;
  cnt_size:=GetSize(counter^.return);
  end_size:=GetSize(endvalue^.return);

  if endvalue^.op<>__ordconst then
    begin
      GenerateCode(endvalue);
      {load end value to temporary stack variable}
      inc(stacksize, 4);
      SetLoc(temp, ebp, none, -stacksize, 0);
      if endvalue^.loc.l=register then
        begin
          emit_loc_reg(_mov_, end_size, temp, end_size, endvalue^.loc.reg);
          ReleaseRegister(endvalue^.loc.reg);
        end
      else
        EmitMemMem(end_size, temp, endvalue^.loc);
    end;

  GenerateCode(p^.left); {load start value}

  if p^.down_to then emit_loc(_inc_, cnt_size, counter^.loc)
                else emit_loc(_dec_, cnt_size, counter^.loc);

  PutLabel(TestLabel);

  if p^.down_to=FALSE then emit_loc(_inc_, cnt_size, counter^.loc)
                      else emit_loc(_dec_, cnt_size, counter^.loc);

  if p^.block<>NIL then GenerateCode(p^.block); {Code to be repeated}

  OldLabel:=Current_Label;
  Current_Label:=DoneLabel;

  GenerateCode(counter);
  if endvalue^.op<>__ordconst then
    begin
      if counter^.loc.l=register then
        emit_reg_loc(_cmp_, cnt_size, counter^.loc.reg, cnt_size, temp)
      else
        begin
          i:=GetRegister;
          emit_reg_loc(_mov_, cnt_size, i, cnt_size, counter^.loc);
          emit_reg_loc(_cmp_, cnt_size, i, cnt_size, temp);
          ReleaseRegister(i);
        end;
    end
  else
    emit_loc_ord(_cmp_, cnt_size, counter^.loc, endvalue^.loc.value);

  if (p^.down_to=FALSE) then
    if (p^.right^.signed=TRUE)  then jump:=_jl_
                                else jump:=_jb_
  else
    if (p^.right^.signed=FALSE) then jump:=_jg_
                                else jump:=_ja_;

  emit_lab(jump, _near_, LabelString(TestLabel));

  Current_Label:=OldLabel;
  PutLabel(DoneLabel);

  Break_label := SaveBreak;
  Continue_label := SaveContinue;
end;

procedure DoWhile(var p: pTree);

var OldLabel,
    StartLabel, TestLabel, DoneLabel,
    SaveBreak, SaveContinue : integer;

    sym : pSymbolRecord;

begin
  TestLabel := NewLabel;
  DoneLabel := NewLabel;
  StartLabel:= NewLabel;

  SaveBreak    := Break_Label;
  SaveContinue := Continue_label;
  Break_label    := DoneLabel;
  Continue_label := TestLabel;

  PutLabel(TestLabel);

  OldLabel:=Current_Label;
  Current_Label:=DoneLabel;

  True_Label:=DoneLabel;{DoneLabel;}
  False_Label:=StartLabel;{TestLabel;}

  CheckShortBoolean(p^.left);
  GenerateCode(p^.left); {evaluation}

  Current_Label:=OldLabel;

  if p^.right<>NIL then
    begin
      PutLabel(StartLabel);
      GenerateCode(p^.right); {Codeblock to be repeated}
    end;
  emit_lab(_jmp_, _nothing, LabelString(TestLabel));
  PutLabel(DoneLabel);
  Break_label := SaveBreak;
  Continue_label := SaveContinue;
end;

procedure DoRepeat(var p: pTree);

var OldLabel,
    TestLabel, DoneLabel,
    SaveBreak, SaveContinue, LContinueLabel: integer;
    sym : pSymbolRecord;


begin
   TestLabel := NewLabel;
   DoneLabel := NewLabel;

   LContinueLabel := NewLabel;
   SaveBreak := Break_Label;
   SaveContinue := Continue_label;
   Break_label:=DoneLabel;
   Continue_label := LContinueLabel;

   PutLabel(TestLabel);


   if p^.right<>NIL then GenerateCode(p^.right); {Codeblock to be repeated}

   OldLabel:=Current_Label;
   Current_Label:=TestLabel;

   True_Label:=TestLabel;
   False_Label:=DoneLabel;

   PutLabel(Continue_Label);
   CheckShortBoolean(p^.left);
   GenerateCode(p^.left); {evaluation}

   Current_Label:=OldLabel;
   PutLabel(DoneLabel);
   Break_label := SaveBreak;
   Continue_label := SaveContinue;
end;

procedure DoBreak(var p: pTree);

begin
  if break_label= 0 then
    lineerror(p^.line,' No enclosing FOR, WHILE, or REPEAT statement');

  emit_lab(_jmp_, _nothing, LabelString(Break_Label));
end;

procedure DoContinue(var p: pTree);

begin
  if continue_label= 0 then
    lineerror(p^.line,' No enclosing FOR, WHILE, or REPEAT statement');
  emit_lab(_jmp_, _nothing, LabelString(Continue_Label));
end;

procedure DoExit(var p: pTree);

begin
   If exit_label= 0 then
     lineerror(p^.line,' Internal error in assigning correct exit label');
  emit_lab(_jmp_, _nothing, LabelString(Exit_Label));
end;

procedure DoGoto(var p: pTree);

begin
  emit_lab(_jmp_, _nothing, p^.glab);
end;

procedure DoLabel(var p: pTree);

begin
  emit_label(p^.glab);
end;

procedure DoWith(var p: pTree);
var l: location;
    w: pSymbolList;

begin
  l:=withloc;
  w:=WithTable;
  GenerateCode(p^.left);  {expression}

  withloc:=p^.left^.loc;

  if (withloc.l=memref) and ((withloc.base<>none) or (withloc.index<>none)) then
    begin
      ReleaseLocRegs(p^.left^.loc);
      emit_reg_loc(_lea_, _dword, esi, _nothing, p^.left^.loc);
      ClearLoc(withloc);
      withloc.base:=esi;
    end;

  withtable:=p^.left^.return^.RecordTable;
  GenerateCode(p^.right); {block}
  withloc:=l;
  WithTable:=w;
end;

procedure DoAsm(var p: pTree);

var
   start,str : stringlist;

begin
  if p^.asmblock.first<>NIL then
    begin
      AttachAsmList(p^.asmblock);
{     start:=p^.asmblock;
      repeat
        emit_string(start^.name^);
        start:=start^.next;
      until start=NIL;}
    end;
end;

procedure GenerateCode(var p: pTree);
var typ:pTypeRecord;
    n:longint;

begin
if p<>NIL then
 begin
   if Options.AddLineNumbers and (p^.line<>debugline) then
     begin
       debugline:=p^.line;
       emit_string('; line: ' + Numb(debugline));
     end;
  case p^.op of
  __block      : DoBlock(p);
  __assign     : DoAssignment(p);
  __type       : DoTypeConversion(p);
  __var        : DoVar(p);
  __field      : DoField(p);
  __index      : DoIndex(p);
  __nil        : DoNil(p);
  __ordconst   : DoLoadOrdConst(p);
  __charconst  : DoLoadCharConst(p);
  __pcharconst : DoLoadPCharConst(p);
  __stringconst: DoLoadStrConst(p);
  __realconst  : DoLoadRealConst(p);
  __setconst   : DoLoadSetConst(p);
  __result     : DoFunctionResult(p);
  __call       : DoCall(p);
  __if         : DoIf(p);
  __case       : DoCase(p);
  __for        : DoFor(p);
  __while      : DoWhile(p);
  __repeat     : DoRepeat(p);
  __address    : DoAddress(p);
  __ptr        : DoPtr(p);
  __and        : DoAnd(p);
  __or         : DoOr(p);
  __xor         : DoXor(p);
  __shl,
  __shr        : DoShlShr(p);
  __minus      : DoMinus(p);
  __not        : DoNot(p);
  __add        : DoAdd(p);
  __sub        : DoSub(p);
  __slash      : DoSlash(p);
  __mod,
  __div        : DoDiv(p);
  __mul        : DoMul(p);
  __equal,
  __not_eq,
  __greater,
  __less,
  __greater_eq,
  __less_eq    : DoComparison(p);
  __asm        : DoAsm(p);
  __break      : DoBreak(p);
  __continue   : DoContinue(p);
  __exit       : DoExit(p);
  __goto       : DoGoto(p);
  __label      : DoLabel(p);
  __with       : DoWith(p);
  else           begin
                   linecount:=p^.line; {update variable to allow error with (almost) correct linenr.}
                   Abort('Code-generator: '+Numb(Ord(p^.op)));
                 end;
  end;
    end;
end;

procedure GenCodeProc(sym:pSymbolRecord; var p: pTree);

var a, size, Lexit_label : integer;   {local label to allow for nested exits}

begin
  withloc.l:=undef;
  withtable:=NIL;
  CreateAsmList;
  currentLevel := sym^.plevel;
  Lexit_Label := Exit_label;
  Exit_label := NewLabel;


  stacksize:=sym^.localsize;

  InitRegisters;
  protreg := sym^.usedregs;
  freereg := freereg - protreg;
  GenerateCode(p);
  if (stacksize<>0) or
     (sym^.returntype<>NIL) and ((sym^.returntype^.typedef=_RecordDef) or
     (sym^.returntype^.typedef=_ArrayDef) or
     (sym^.returntype^.typedef=_StringDef)) or
     (sym^.ParamSize<>0) and
     ((sym^.prop and p_register) = 0) then
    begin
      PutLabel(Exit_label);
      if sym^.ReturnType<>NIL then
        begin
          {stack alignment}
          size:= sym^.LocalSize;
          a:=size and (Options.AlignData-1);
          if a<>0 then
            stacksize:=Options.AlignData-a + size;
          sym^.LocalSize := stacksize;

          case sym^.returntype^.typedef of
          _BooleanDef,
          _PointerDef,
          _EnumeratedDef,
          _SubRangeDef: begin
                          p^.loc.l:=memref;
                          SetLoc(p^.loc, ebp, none, - sym^.localsize, 0);
                          emit_reg_loc(_mov_, GetSize(sym^.ReturnType), eax, GetSize(sym^.ReturnType), p^.loc);
                        end;
          _RealDef    : begin
                          p^.loc.l:=memref;
                          SetLoc(p^.loc, ebp, none, - sym^.localsize, 0);
                          emit_loc(_fld_, GetSize(sym^.ReturnType), p^.loc);
                        end
          end;
        end;
       if ((sym^.prop and p_assembler)=0) or ((sym^.prop and p_register)=0) then
         begin
           if Options.AlignStackFrame then
             emit_reg_ord(_add_, _dword, esp, 4 + stacksize) {restore ESP}
           else
             emit_reg_reg(_mov_, _dword, esp, _dword, ebp); {move EBP into ESP stackpointer}
         end;
       emit_reg(_pop_, _dword, ebp);  {restore EBP}
       if (sym^.ParamSize<>0) and ((sym^.prop and p_register)=0) then
         emit_ord(_ret_, _nothing, sym^.ParamSize)
       else
         emit_non(_ret_);

       {in reverse order! (we're inserting these lines...)}
       {-------- setup stack frame}
       if ((sym^.prop and p_assembler)=0) or ((sym^.prop and p_register)=0) then
         if stacksize<>0 then
           begin
             if Options.AlignStackFrame then
               begin
                 iemit_reg_ord(_sub_, _dword, esp, 4 + stacksize);
                 iemit_reg_ord(_and_, _dword, ebp, -8); {align stack, 8 byte boundary}
               end
             else
               iemit_reg_ord(_sub_, _dword, esp, stacksize);
           end;
       iemit_reg_reg(_mov_, _dword, ebp, _dword, esp);
       iemit_reg(_push_, _dword, ebp);
       iemit_label(sym^.overloadedname);
       iemit_string(asdef.align);
       {--------}
    end
  else
    begin
      WriteLn(Dest^, asdef.align);
      WriteLn(Dest^, sym^.overloadedname+':');
      PutLabel(Exit_label);
      if (sym^.ParamSize<>0) and ((sym^.prop and p_register)=0) then
        emit_ord(_ret_, _nothing, sym^.ParamSize)
      else
        if sym^.plevel >= 2 then {DB} { watch for stack errors! }
          emit_ord(_ret_, _nothing, 4)
        else
          emit_non(_ret_);
    end;

  LowLevelOptimize(asmlist);
  Exit_Label := Lexit_label; {LB, allows nested exits}
  DumpAsmList;
  DestroyAsmList;
end;

procedure GenerateHeader;
var s:string;
    i:integer;

begin
  WriteLn(Dest^, '; Program: ', ProgramName);
  WriteLn(Dest^, '; Assembler: '+asdef.desc);
  WriteLn(Dest^, '; Generated by P32 '+P32_version+' (c) 1996-1999 Johan Prins');
  WriteLn(Dest^, asdef.header1);
  WriteLn(Dest^, asdef.header2);
  WriteLn(Dest^, asdef.model);
  {$IFDEF VER70}
  s:=TextRec(incl^).Name;
  i:=0;
  repeat
    inc(i);
  until (s[i]=#0) or (i>255);
  s[0]:=char(i-1);
  {$ELSE}
  s:='';
  {$ENDIF}
  WriteLn(Dest^, asdef.codeseg);
  WriteLn(Dest^, asdef.include+' '+asdef.inc_char+ s+asdef.inc_char);
end;

procedure GenerateCodeUnit(const unitname:string;var p: pTree);
begin
  withloc.l:=undef;
  withtable:=NIL;
  CreateAsmList;
  WriteLn(Dest^);
  if p<>NIL then
    begin
      iemit_label('_'+unitname+'$MAIN');
      iemit_string(asdef.align);
      EmitPublic('_'+unitname+'$MAIN');
      InitRegisters;
      GenerateCode(p);
      if stacksize<>0 then
        begin
          iemit_reg_ord(_sub_, _dword, esp, stacksize);
          iemit_reg_reg(_mov_, _dword, ebp, _dword, esp);
          iemit_reg(_push_, _dword, ebp);
        end;

      if stacksize<>0 then emit_ord(_ret_, _nothing, stacksize)
                      else emit_non(_ret_);
      LowLevelOptimize(asmlist);
      DumpAsmList;
      DestroyAsmList;
    end;
  DumpConstants;
  DumpSymbols;
  WriteLn(Dest^);
  WriteLn(Dest^, asdef.ends);
end;

procedure GenCodeMain(var p: pTree);

var sym: pSymbolRecord;
    con: pConstantRecord;
    list: pSymbols;

begin
  withloc.l:=undef;
  withtable:=NIL;
  CreateAsmList;
  Exit_label := NewLabel;
  WriteLn(Dest^);
  WriteLn(Dest^, asdef.align);
  EmitPublic(asdef.start);
  WriteLn(Dest^, asdef.start+':');
  InitRegisters;
  GenerateCode(p);

  if stacksize<>0 then
    begin
      iemit_reg_ord(_sub_, _dword, esp, stacksize);
      iemit_reg_reg(_mov_, _dword, ebp, _dword, esp);
      iemit_reg(_push_, _dword, ebp);
    end;


  {little routine that gets all unit entries from the symbollist}
  list:=lastlist;
  while list<>nil do
    begin
      sym:=list^.list^.first;
      if sym<>NIL then
        while sym<>NIL do
          begin
            if (sym^.symbol=_unit) and
               (sym^.name<>ProgramName) then
              begin
                iemit_lab(_call_, _nothing, sym^.name+'$MAIN');
                EmitExtern(sym^.name+'$MAIN');
              end;
            sym:=sym^.next;
          end;
        list:=list^.prev;
    end;

  PutLabel(Exit_label);
  GetSymbol('_PROGRAMEXIT'); {check to set used bit}
  emit_lab(_call_, _nothing, 'programexit');

  LowLevelOptimize(asmlist);
  DumpAsmList;
  DestroyAsmList;

  sym:=GetSymbol('_HEAPSIZE');
  con:=NewConstant;
  con^.c:=_IntegerConst;
  con^.size:=4;
  con^.n:=Options.HeapSize;
  con^.id := getmemstring(sym^.overloadedname);
  con^.dumped:=FALSE;
  AddConstant(ConstantTable, con, TRUE);
  EmitPublic(sym^.overloadedname); {make heapsize variable public}
  if sym<>NIL then sym^.attr:=(sym^.attr and not s_varext) or s_vardmp;
  DumpConstants;
  DumpSymbols;

  WriteLn(Dest^, asdef.stackseg);
  WriteLn(Dest^);
  WriteLn(Dest^, asdef.ends+' MAIN');
end;

end.


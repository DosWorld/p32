{                         P32 - 32bit Pascal Compiler                        }
{ -------------------------------------------------------------------------- }
{                       Johan Prins - jprins@knoware.nl                      }
{ ========================================================================== }
{ Lowlevel optimizer                                                         }
{                                                                            }
{                                                   (c) Copyright 1996-1999  }
{                                                                            }
{ -------------------------------------------------------------------------- }

{ Implemented optimizations:

  Optimize level 1
  ----------------

  Original:                 Changed to:                    Comments:
  ------------------        ------------------------------
  mov   reg1, [mem1]        mov   reg1, [mem1]
  mov   reg1, [mem1]
  ------------------        ------------------------------
  mov   reg1, [mem1]        mov   reg1, [mem1]
  mov   reg2, [mem1]        mov   reg2, reg1
  ------------------        ------------------------------
  mov   [mem1], reg1        mov   [mem1], reg1
  mov   reg1, [mem1]
  ------------------        ------------------------------
  mov   reg1, [mem1]        xxx   [mem1], imm              xxx - add, sub, shl, shr, inc, dec, or, xor, and
  xxx   reg1, imm
  mov   [mem1], reg1
  ------------------        ------------------------------
  jmp   label               label:
  label:
  ------------------        ------------------------------
  mov   [mem1], reg1        mov   [mem1], reg1
  cmp   [mem1], imm         cmp   reg1, imm
  ------------------        ------------------------------
  cmp   reg1, 0             test  reg1, reg1
  ------------------        ------------------------------
  shl   reg1, imm1          lea   reg1, [reg1*(imm1^2) + imm2]
  add   reg1, imm2
  ------------------        ------------------------------
  shl   reg1, imm1          lea   reg1, [reg1*(imm1^2) - imm2]
  sub   reg1, imm2
  ------------------        ------------------------------
  xxx   reg1, ...           xxx   reg1, ...                 xxx - add, sub, shl, shr, inc, dec, or, xor, and
  test  reg1, reg1          jz    label                     ... - can be register, immediate or memory value
  jz    label
  ------------------        ------------------------------
  xxx   reg1, ...           xxx   reg1, ...
  test  reg1, reg1          jnz    label
  jnz    label
  ------------------        ------------------------------
  xxx   reg1, 0	            <remove>		            xxx - add, sub, shr, shl
  ------------------        ------------------------------
  xxx   reg1, 0		    xor   reg1, reg1	            xxx - and, mov, imul
  ------------------        ------------------------------
  lea   reg1, [reg2]        mov   reg1, reg2
  ------------------        ------------------------------
  fld   [mem]               fadd  [mem]                     32bit, 64bit reals only!
  faddp
  ------------------        ------------------------------
  fld   [mem]               fsub  [mem]
  fsubp
  ------------------        ------------------------------
  fld   [mem]               fmul  [mem]
  fmulp
  ------------------        ------------------------------
  fld   [mem]               fdiv  [mem]
  fdivp
  ------------------        ------------------------------
  fld   [mem]               fsubr [mem]
  fsubrp
  ------------------        ------------------------------
  fld   [mem]               fdivr [mem]
  fdivrp


  Not implemented (yet):
  ------------------        ------------------------------
  push   reg1                <remove both>
  pop    reg1
  ------------------        ------------------------------
  push   mem1                <remove both>
  pop    mem1
  ------------------        ------------------------------
  push   xxx1               mov   xxx1, xxx2               xxx = imm/reg/mem
  pop    xxx2                                                    (not for segment registers!)
  ------------------        ------------------------------
  shl   reg1, imm1          lea   reg1, [reg1*imm1 + reg2]
  add   reg1, reg2
  ------------------        ------------------------------

  see also the end of this file..

  Optimize level 3
  ----------------
  Branch remover, replace branches with cmov's (K7, PPro, P2 only)

  ------------------        ------------------------------
  jmp   lab1
  .                         <delete until label found>
  labx:
  ------------------        ------------------------------
  jcc   lab1                <deleted>
  mov   dst, src            cmovncc   dst, src
  lab1:                     lab1:
  ------------------        ------------------------------
  jcc   lab1                <deleted>                      only one jump to lab1 may occur
  mov   dst1, src1          cmovncc   dst1, src1
  jmp   lab2                <deleted>
  lab1:                     lab1:
  mov   dst, src2           cmovcc    dst2, src2
  lab2:                     lab2:
  ------------------        ------------------------------
  jcc   lab1                <deleted>
  mov   dst, src            cmovncc   dst, src
  jmp   lab2                jncc      lab2
  lab1:                     lab1:
  ------------------        ------------------------------
  jmp  Lab1                 <deleted>
  lab1:                     lab1:
  ------------------        ------------------------------
  jcc   lab1                <deleted>
  jmp   lab2                jncc  lab2
  lab1:                     lab1:
  ------------------        ------------------------------
  jcc   lab1                <deleted>
  lab1:                     lab1:
  ------------------        ------------------------------
  jcc   lab1                <deleted>                      [mem] is a ref to BYTE
  mov   [mem], c1           setcc [mem]                    (c1=0 and c2=1) or
  jmp   lab2                <deleted>                      (c1=1 and c2=0)
  lab1:                     <deleted>
  mov   [mem], c2           <deleted>
  lab2:                     lab2:
  ------------------        ------------------------------
  cmp   a, b                cmp   a, b                     must set CF flag
  Jcc   Lab1                -- deleted --
  mov   [mem], c1           sbb   xreg, xreg
  jmp   lab2                vary on C1,C2 val
  lab1:                     vary on C1,C2 val
  mov   [mem], c2           mov   [mem], reg.xx
  lab2:                     lab2:
  ------------------        ------------------------------
                            xor   reg, reg
  cmp   a, b                cmp   a, b
  jcc   lab1                setcc reg.lo
  mov   [mem], c1           dec   reg
  jmp   lab2                and   reg, c2-c1
  lab1:                     add   reg, c1
  mov   [mem], c2           mov   [mem], reg.xx
  lab2:                     lab2:
  ------------------        ------------------------------
                            mov   dst1, src1
  jcc   lab1                jcc   lab1
  mov   dst1, src1          .
  .                         .
  .                         jmp   lab2
  jmp   lab2                lab1:
  lab1:                     .
  mov   dst1, src           .
  .                         lab2:
  .
  lab2:
}


{ $DEFINE debug}
unit P32_lopt;

interface

uses P32_tree, P32_asm, P32_asml, P32_prep, P32_scan, P32_err;

procedure LowLevelOptimize(var a: tAsmList);

implementation

uses P32_symb, P32_code, P32_ors3;

type
   contents = record
                changed: boolean;
                size   : byte;
                loc    : location;
              end;

    varlist    = ^varrecord;
    varrecord  = record
                   next    : varlist;
                   priority: integer;
                   size    : byte;
                   loc     : location;
                 end;


var
   inreg : array[eax..edi] of contents;
   unused: set of eax..edi;

   finished: boolean;
   CMOVAllowed: boolean;



function equal_loc(var loc1, loc2: location): boolean;
begin
  equal_loc:=false;
  case loc1.l of
  undef        : exit;
  register     : if loc1.reg=loc2.reg then equal_loc:=true;
  port,
  directmem,
  memref       : if (loc1.base   = loc2.base) and
                    (loc1.index  = loc2.index) and
                    (loc1.factor = loc2.factor) and
                    (loc1.offset = loc2.offset) and
                    (loc1.name   = loc2.name) then equal_loc:=true;
  ordconst     : if loc1.value=loc2.value then equal_loc:=true;
  fpu          : if loc1.nr=loc2.nr then equal_loc:=true;
  end;
end;

procedure CreateVarList(var p: varlist);
begin
   new(p);
   fillchar(p^, sizeof(p^), 0);
end;

procedure DestroyVarList(var p: varlist);
var start: varlist;

begin
  start:=p;
  while start<>NIL do
    begin
      {$IFDEF debug}
      writeln(CreateName(p^.loc),', priority: ', start^.priority);
      {$ENDIF}
      p:=start^.next;
      dispose(start);
      start:=p;
    end;
  p:=NIL;
end;

procedure AddVarName(p: varlist; size: integer; var l:location);

begin
  while (p^.next<>NIL) and not equal_loc(p^.loc, l) do
    p:=p^.next;

  if not equal_loc(p^.loc, l) then
    begin
      new(p^.next);  {create new one}
      p:=p^.next;
      p^.next:=NIL;  {only one entry added}
      p^.priority:=1;
      p^.size:=size;
      p^.loc:=l;
    end
  else
    inc(p^.priority);
end;

function FindHighest(p:varlist): varlist; {pointer to highest entry}
var pr: integer;
     t: varlist;
begin
  pr:=0;
  t:=NIL;
  while (p<>NIL) do
    begin
      if pr<p^.priority then
        begin
          pr:=p^.priority;
          t:=p;
        end;
      p:=p^.next;
    end;
  if t<>NIL then t^.priority:=0; {set to zero, so it isn't found again...}
  FindHighest:=t;
end;

procedure ReplaceVarWithRegister(var a: tAsmList;{size: byte;}var l:location; i: regs);
var p: pAsmRecord;

begin
  p:=a.first;
  while p<>NIL do
    begin
      if (p^.o1.o=_mem) and equal_loc(p^.o1.loc, l) then
        begin
          p^.o1.o:=_reg;
          p^.o1.reg:=i;
        end;
      if (p^.o2.o=_mem) and equal_loc(p^.o2.loc, l) then
        begin
          p^.o2.o:=_reg;
          p^.o2.reg:=i;
        end;
      p:=p^.next;
    end;
end;


function FindRegister(var l:location): regs;
var
   i : regs;
begin
   FindRegister:=none;
   for i:=eax to edi do
      if equal_loc(inreg[i].loc, l) then begin
         FindRegister:=i;
         {$IFDEF debug}
         write('; Found: ', r[i],' = ',CreateName(l));
         {$ENDIF}
         break;
      end;
end;

procedure ReplaceVariables(var a:tAsmList; v: varlist);

label
   l1;
var
   entry: varlist;

begin
  repeat
    entry:=FindHighest(v);
    if entry<>NIL then
    if entry^.size=_dword then
      begin
        if edi in unused then
          begin
            ReplaceVarWithRegister(a, entry^.loc, edi);
            unused:=unused - [edi]
          end
        else
        if esi in unused then
          begin
            ReplaceVarWithRegister(a, entry^.loc, esi);
            unused:=unused - [esi]
          end;
        goto l1;
      end
    else
l1:
      begin
        if eax in unused then
          begin
            ReplaceVarWithRegister(a, entry^.loc, eax);
            unused:=unused - [eax]
          end
        else
        if edx in unused then
          begin
            ReplaceVarWithRegister(a, entry^.loc, edx);
            unused:=unused - [edx]
          end
        else
        if ecx in unused then
          begin
            ReplaceVarWithRegister(a, entry^.loc, ecx);
            unused:=unused - [ecx]
          end
        else
        if ebx in unused then
          begin
            ReplaceVarWithRegister(a, entry^.loc, ebx);
            unused:=unused - [ebx]
          end;
      end;
  until (entry=NIL) or (unused=[]);
end;

procedure AnalyzeRegisterUsage(var a: tAsmList);

var p  : pAsmRecord;
    p1 : pAsmRecord;
    i: regs;
    v1, v: varlist;

begin
   fillchar(inreg, sizeof(inreg), 0);
   unused:=[]; {clear the unused registers set}
   CreateVarList(v);

   p:=a.first;
   while p<>NIL do
     begin
       if (p^.o1.o=_mem) and (p^.o1.loc.name='') and (p^.o1.loc.offset<0) then
         AddVarName(v, p^.o1.size, p^.o1.loc);
       if (p^.o2.o=_mem) and (p^.o2.loc.name='') and (p^.o2.loc.offset<0) then
         AddVarName(v, p^.o2.size, p^.o2.loc);
       p:=p^.next;
     end;
   {$IFDEF debug}
   v1:=v;
   while v1<>NIL do
     begin
       writeln(v1^.priority, 'x - [', CreateName(v1^.loc),']');
       v1:=v1^.next;
     end;
  {$ENDIF}
  {ReplaceVariables(a, v);}
  DestroyVarList(v);
end;

{********************************************************************}
{ One line peephole optimizer                                        }
{********************************************************************}

procedure LowLevelOptimize1(var a: tAsmList);
var p1: pAsmRecord;
    l: location;

begin
  finished:=FALSE;
  while not finished do
  begin
  p1:=a.first;
  finished:=TRUE;
  while (p1<>NIL) do
    begin
      if (p1^.a=_opcode) and not p1^._inline then
        case p1^.op of
        _add_,
        _sub_,
        _shr_,
        _shl_  : begin
                   if (p1^.o2.o=_ord) and (p1^.o2.n=0) then
                     begin
                       DeleteAsmEntry(p1);
                       finished:=FALSE;
                       continue;
                     end;
                 end;
        _imul_,
        _and_  : begin
                   if (p1^.o1.o=_reg) and
                      (p1^.o2.o=_ord) and (p1^.o2.n=0) then
                     begin
                       p1^.op:=_xor_;
                       p1^.o2.o:=_reg;
                       p1^.o2.reg:=p1^.o1.reg;
                       finished:=FALSE;
                     end;
                 end;
        _mov_  : begin
                   if (p1^.o1.o=_reg) and
                      (p1^.o2.o=_ord) and (p1^.o2.n=0) and
                      (CPU <> K6) then
                     begin
                       p1^.op:=_xor_;
                       p1^.o2.o:=_reg;
                       p1^.o2.reg:=p1^.o1.reg;
                       finished:=FALSE;
                     end;
                 end;
        _lea_  : begin
                   if (p1^.o1.o=_reg) and (p1^.o2.o=_mem) then
                     begin
                       l:=p1^.o2.loc;
                       if (l.offset=0) and (l.factor=1) and (l.name='') and
                          ((l.base=none) or (l.index=none)) then
                         begin
                           p1^.op:=_mov_;
                           p1^.o2.o:=_reg;
                           if l.base<>none then p1^.o2.reg:=l.base
                                           else p1^.o2.reg:=l.index;
                           finished:=FALSE;
                         end;
                     end;
                 end;
        _cmp_  : begin
                   if (p1^.o1.o=_reg) and (p1^.o2.o=_ord) then
                     if p1^.o2.n=0 then
                         begin
                           p1^.op:=_test_;
                           p1^.o2.o:=_reg;
                           p1^.o2.reg:=p1^.o1.reg;
                           finished:=FALSE;
                         end;
                 end;
        end;
      p1:=p1^.next;
    end;
  end;
end;

{********************************************************************}
{ Two line peephole optimizer                                        }
{********************************************************************}

procedure LowLevelOptimize2(var a: tAsmList);
{Optimizes _only_ two-line expressions}
var p1, p2: pAsmRecord;
    l: location;
    DeleteP2: boolean;

begin
  finished:=FALSE;
  while not finished do
  begin
  p1:=a.first;
  finished:=TRUE;
  while (p1<>NIL) do
    begin
      p2:=p1^.next;
      if p2=NIL then break;
      if (p1^.a=_opcode) and not p1^._inline and not p2^._inline then
        case p1^.op of
        _fld_  : begin
                   if (p1^.o1.o = _mem) and (p1^.o1.size <> 10) and
                      (((p2^.o1.o = _non) and (p2^.o2.o = _non)) or
                      ( (p2^.o1.o = _fpu) and (p2^.o2.o = _fpu) and
                      (p2^.o1.f = 1) and (p2^.o2.f = 0) )) then
                      begin
                        DeleteP2 := true;
                        case ( p2^.op ) of
                        _faddp_  : p1^.op := _fadd_;
                        _fsubp_  : p1^.op := _fsub_;
                        _fmulp_  : p1^.op := _fmul_;
                        _fdivp_  : p1^.op := _fdiv_;
                        _fsubrp_ : p1^.op := _fsubr_;
                        _fdivrp_ : p1^.op := _fdivr_;
                        else
                          DeleteP2 := false;
                        end;
                        if DeleteP2 then
                          begin
                            DeleteAsmEntry(p2);
                            finished:=FALSE;
                            continue;
                          end;
                       end;
                 end;
        _mov_,
        _movsx_,
        _movzx_: begin {duplicate load}
                   if ((p2^.op=_mov_) or (p2^.op=_movsx_) or (p2^.op=_movzx_)) and
                      (p1^.o1.o=_mem) and (p1^.o2.o=_reg) and
                      (p2^.o1.o=_mem) and (p2^.o2.o=_reg) then
                     begin
                       if equal_loc(p1^.o1.loc, p2^.o1.loc) then
                         begin
                           if p1^.o1.reg=p2^.o1.reg then
                             begin
                               {completely remove the first load}
                               DeleteAsmEntry(p1);
                               finished:=FALSE;
                               continue;
                             end
                           else
                             begin
                               {change the load into a 'mov'}
                               p2^.o2.o:=_reg;
                               p2^.o2.reg:=p1^.o2.reg;
                               finished:=FALSE;
                             end;
                         end;
                     end;
                   if ((p2^.op=_mov_) or (p2^.op=_movsx_) or (p2^.op=_movzx_)) and
                      ((p1^.o1.o=_reg) and (p1^.o2.o=_mem) and
                       (p2^.o1.o=_reg) and (p2^.o2.o=_mem)) then
                     begin
                       if equal_loc(p1^.o2.loc, p2^.o2.loc) then
                         begin
                           if p1^.o1.reg=p2^.o1.reg then
                             begin {completely remove the load/store}
                               DeleteAsmEntry(p2);
                               finished:=FALSE;
                               continue;
                             end
                           else
                             begin
                               {change the load into a 'mov'}
                               if p2^.o1.size=p1^.o1.size then
                                 begin
                                   p2^.op:=_mov_;
                                   p2^.o2.o:=_reg;
                                   p2^.o2.reg:=p1^.o1.reg;
                                   p2^.o2.size:=p1^.o1.size;
                                   finished:=FALSE;
                                   continue;
                                 end;
                             end;
                         end;
                     end;
                   if (p2^.op=_cmp_) and
                      (p1^.o1.o=_mem) and (p1^.o2.o=_reg) and
                      (p2^.o1.o=_mem) and (p2^.o2.o=_ord) then
                     begin
                       if equal_loc(p1^.o1.loc, p2^.o1.loc) then
                         begin {change 2nd memref into register}
                           p2^.o1.o:=_reg;
                           p2^.o1.reg:=p1^.o2.reg;
                           finished:=FALSE;
                           continue;
                         end;
                     end;
                 end;
        _shl_  : begin
                   if ((p2^.op=_add_) or (p2^.op=_sub_)) and
                      (p1^.o1.o=_reg) and (p1^.o2.o=_ord) and
                      (p2^.o1.o=_reg) and (p2^.o2.o=_ord) then
                     begin
                       if (p1^.o2.n in [1, 2, 3]) and
                          (p1^.o1.reg=p2^.o1.reg) then
                         begin
                           l.l:=memref;
                           ClearLoc(l);
                           l.index:=p1^.o1.reg;
                           case p1^.o2.n of
                           1 : l.factor:=2;
                           2 : l.factor:=4;
                           3 : l.factor:=8;
                           end;
                           if p2^.op=_sub_ then l.offset:= - p2^.o2.n
                                           else l.offset:= p2^.o2.n;
                           p1^.op:=_lea_;
                           p1^.o1.o:=_reg;
                           p1^.o1.reg:=l.index;
                           p1^.o2.o:=_mem;
                           p1^.o2.loc:=l;
                           p1^.o2.size:=_nothing;
                           DeleteAsmEntry(p2); {only delete the jump!}
                           finished:=FALSE;
                           continue;
                         end;
                     end;
                 end;
        _add_  : begin
                   if (p2^.op=_add_) and
                      (p1^.o1.o=_reg) and (p1^.o2.o=_ord) and
                      (p2^.o1.o=_reg) and (p2^.o2.o=_ord) then
                     begin
                       if p1^.o1.reg=p2^.o1.reg then
                         begin
                           p1^.op:=_add_;
                           p1^.o2.n:=p1^.o2.n + p2^.o2.n;
                           p1^.o2.size:=_nothing;
                           DeleteAsmEntry(p2); {only delete the jump!}
                           finished:=FALSE;
                           continue;
                         end;
                     end;
                 end;
        _sub_  : begin
                   if (p2^.op=_sub_) and
                      (p1^.o1.o=_reg) and (p1^.o2.o=_ord) and
                      (p2^.o1.o=_reg) and (p2^.o2.o=_ord) then
                     begin
                       if p1^.o1.reg=p2^.o1.reg then
                         begin
                           p1^.op:=_sub_;
                           p1^.o2.n:= p1^.o2.n + p2^.o2.n; {Yes, this is ok! ;) }
                           p1^.o2.size:=_nothing;
                           DeleteAsmEntry(p2); {only delete the jump!}
                           finished:=FALSE;
                           continue;
                         end;
                     end;
                 end;
        _jmp_  : begin
                   if (p1^.o1.o=_lab) and (p2^.a=_labels) then
                     begin
                       if p1^.o1.lab=p2^.lab then
                         begin
                           DeleteAsmEntry(p1); {only delete the jump!}
                           finished:=FALSE;
                           continue;
                         end;
                     end;
                 end;
        end;
      p1:=p1^.next;
    end;
  end;
end;

{********************************************************************}
{ Three line peephole optimizer                                      }
{********************************************************************}

procedure LowLevelOptimize3(var a: tAsmList);
{Optimizes _only_ three line expressions}
var p1, p2, p3: pAsmRecord;

begin
  finished:=FALSE;
  while not finished do
  begin
  p1:=a.first;
  finished:=TRUE;
  while p1<>NIL do
    begin
      p2:=p1^.next;
      if p2=NIL then break;
      p3:=p2^.next;
      if p3=NIL then break;

      if (p1^.a=_opcode) and not p1^._inline and not p2^._inline and not p3^._inline then
        begin
          if  (p2^.op=_test_) and ((p3^.op=_jz_) or (p3^.op=_jnz_)) and
             ((p1^.op=_shl_) or
              (p1^.op=_shr_) or
              (p1^.op=_add_) or
              (p1^.op=_sub_) or
              (p1^.op=_or_) or
              (p1^.op=_and_) or
              (p1^.op=_xor_) or
              (p1^.op=_neg_) or
              (p1^.op=_inc_) or
              (p1^.op=_dec_)) then
            begin
              if (p1^.o1.o=_reg) and (p1^.o1.reg=p2^.o1.reg) then
                begin
                  DeleteAsmEntry(p2);
                  finished:=FALSE;
                  continue;
                end;
            end;
          if (p1^.op=_mov_) and
             (
              (p2^.op=_shl_) or
              (p2^.op=_shr_) or
              (p2^.op=_add_) or
              (p2^.op=_sub_) or
              (p2^.op=_inc_) or
              (p2^.op=_dec_) or
              (p2^.op=_or_) or
              (p2^.op=_and_) or
              (p2^.op=_xor_)
             ) and
             (p3^.op=_mov_) then
            begin
              if (p1^.o1.o=_reg) and (p1^.o2.o=_mem) and
                 (p2^.o1.o=_reg) and (p2^.o2.o=_ord) and
                 (p3^.o1.o=_mem) and (p3^.o2.o=_reg) then
                begin
                  if equal_loc(p1^.o2.loc, p3^.o1.loc) and
                     (p1^.o1.reg=p2^.o1.reg) and
                     (p2^.o1.reg=p3^.o2.reg) then
                    begin
                      {replace with direct add/sub}
                      p1^.op:=p2^.op;
                      p1^.o1.o:=_mem;
                      p1^.o1.loc:=p1^.o2.loc;
                      p1^.o2.o:=_ord;
                      p1^.o2.n:=p2^.o2.n;
                      DeleteAsmEntry(p2);
                      DeleteAsmEntry(p3);
                      finished:=FALSE;
                      continue; {jump to evaluation}
                    end;
                end;
              if ((p2^.op=_inc_) or (p2^.op=_dec_)) and
                 (p1^.o1.o=_reg) and (p1^.o2.o=_mem) and
                 (p2^.o1.o=_reg) and
                 (p3^.o1.o=_mem) and (p3^.o2.o=_reg) then
                begin
                  if equal_loc(p1^.o2.loc, p3^.o1.loc) and
                     (p1^.o1.reg=p2^.o1.reg) and
                     (p2^.o1.reg=p3^.o2.reg) then
                    begin
                      p1^.op:=p2^.op;
                      p1^.o1.o:=_mem;
                      p1^.o1.loc:=p1^.o2.loc;
                      p1^.o2.o:=_non;
                      DeleteAsmEntry(p2);
                      DeleteAsmEntry(p3);
                      finished:=FALSE;
                      continue; {jump to evaluation}
                    end;
                end;
             end;
        end;
      p1:=p1^.next;
    end;
  end;
end;

{*********************************************************
*            BranchRemover begins here                   *
*********************************************************}
type
   TLabel = string[64];

   PLabelList = ^TLabelList;
   TLabelList = record
      AStr : TLabel;
      BStr : TLabel;
      Next : PLabelList;
   end;


const
   BLabelPrefix = 'B';
   LLabelPrefix = 'L';
   BRLabelCount : Longint = 1;

   UsedLabels  : PLabelList = nil;
   AliasLabels : PLabelList = nil;



function UsedLabel(const l : String): Boolean;
var
   Node : PLabelList;
begin
   UsedLabel := false;
   Node := UsedLabels;
   while ( Node <> nil ) do begin
      if ( Node^.AStr = l ) then begin
         UsedLabel := true;
         Exit;
      end;
      Node := Node^.Next;
   end;
end {UsedLabel};



function GetAlias(const l : String): String;
var
   Node : PLabelList;
begin
   Node := AliasLabels;
   repeat
      if ( Node^.AStr = l ) then begin
         GetAlias := Node^.BStr;
         Exit;
      end;
      Node := Node^.Next;
   until ( Node = nil );

   Error('Jump to nowhere ['+l+']');
end {GetAlias};



function LocalLabel(L : TLabel): Boolean;
begin
   LocalLabel := (L[1] = LLabelPrefix) or
                 (L[1] = BLabelPrefix);
end {LocalLabel};



function LabelString(s: integer):string;
begin
  LabelString:='L'+Numb(s);
end;



procedure CleanLabels(var a : tAsmList);
var
   p1,p2     : pAsmRecord;
   Duplicate : Boolean;
   DeleteP2  : Boolean;
   Alias     : TLabel;
   Node      : PLabelList;
   Temp      : PLabelList;
begin
   { 1'st pass - scan for duplicate labels }
   p1 := a.first;
   Duplicate := false;
   Alias := '';

   New(Node);
   Node^.Next  := AliasLabels;
   AliasLabels := Node;
   Node^.AStr  := LabelString(Exit_Label);
   Node^.BStr  := LabelString(Exit_Label);

   while ( p1 <> nil ) do begin
      if ( p1^.a = _labels ) then begin
         if LocalLabel(p1^.lab) then begin
            New(Node);
            Node^.Next  := AliasLabels;
            AliasLabels := Node;
            Node^.AStr  := p1^.lab;
            if not Duplicate then Alias := p1^.lab;
            Node^.BStr := Alias;
            Duplicate  := true;
         end;
      end else begin
         Duplicate := false;
      end;
      p1 := p1^.next;
   end;

   { 2'nd pass - replace all used labels with aliases }
   p1 := a.first;
   while ( p1 <> nil ) do begin
      if ( p1^.o1.o = _lab ) then
         if LocalLabel(p1^.o1.lab) then p1^.o1.lab := GetAlias(p1^.o1.lab);
      p1 := p1^.next;
   end;
   { 3'rd pass - scan for used labels }
   p1 := a.first;
   while ( p1 <> nil ) do begin
      if ( p1^.o1.o = _lab ) then begin
         if LocalLabel(p1^.o1.lab) then begin
            New(Node);
            Node^.Next := UsedLabels;
            UsedLabels := Node;
            Node^.AStr := p1^.o1.lab;
         end;
      end;
      p1 := p1^.next;
   end;
   { 4'th pass - remove unused labels }
   p1 := a.first;
   DeleteP2 := false;
   while ( p1 <> nil ) do begin
      if ( p1^.a = _labels ) then begin
         if LocalLabel(p1^.lab) then begin
            if not UsedLabel(p1^.lab) then begin
               p2 := p1;
               DeleteP2 := true;
            end;
         end;
      end;
      p1 := p1^.next;
      if DeleteP2 then begin
         DeleteP2 := false;
         DeleteAsmEntry(p2);
      end;
   end;
   { 5'th - delete lists }
   Node := AliasLabels;
   while ( Node <> nil ) do begin
      Temp := Node;
      Node := Node^.Next;
      Dispose(Temp);
   end;
   AliasLabels := nil;
   Node := UsedLabels;
   while ( Node <> nil ) do begin
      Temp := Node;
      Node := Node^.Next;
      Dispose(Temp);
   end;
   UsedLabels := nil;
end {CleanLabels};


type
   ConvRecord = record
      PJump : opcode_num;
      PMove : opcode_num;
      PCSet : opcode_num;
      NJump : opcode_num;
      NMove : opcode_num;
      NCSet : opcode_num;
   end;

const
   ConvArray : array [0..29] of ConvRecord = (


(PJump:_ja_  ;PMove:_cmova_  ;PCSet:_seta_
;NJump:_jna_ ;NMove:_cmovna_ ;NCSet:_setna_ ),
(PJump:_jae_ ;PMove:_cmovae_ ;PCSet:_setae_
;NJump:_jnae_;NMove:_cmovnae_;NCSet:_setnae_),
(PJump:_jb_  ;PMove:_cmovb_  ;PCSet:_setb_
;NJump:_jnb_ ;NMove:_cmovnb_ ;NCSet:_setnb_ ),
(PJump:_jbe_ ;PMove:_cmovbe_ ;PCSet:_setbe_
;NJump:_jnbe_;NMove:_cmovnbe_;NCSet:_setnbe_),
(PJump:_jc_  ;PMove:_cmovc_  ;PCSet:_setc_
;NJump:_jnc_ ;NMove:_cmovnc_ ;NCSet:_setnc_ ),
(PJump:_je_  ;PMove:_cmove_  ;PCSet:_sete_
;NJump:_jne_ ;NMove:_cmovne_ ;NCSet:_setne_ ),
(PJump:_jg_  ;PMove:_cmovg_  ;PCSet:_setg_
;NJump:_jng_ ;NMove:_cmovng_ ;NCSet:_setng_ ),
(PJump:_jge_ ;PMove:_cmovge_ ;PCSet:_setge_
;NJump:_jnge_;NMove:_cmovnge_;NCSet:_setnge_),
(PJump:_jl_  ;PMove:_cmovl_  ;PCSet:_setl_
;NJump:_jnl_ ;NMove:_cmovnl_ ;NCSet:_setnl_ ),
(PJump:_jle_ ;PMove:_cmovle_ ;PCSet:_setle_
;NJump:_jnle_;NMove:_cmovnle_;NCSet:_setnle_),
(PJump:_jna_ ;PMove:_cmovna_ ;PCSet:_setna_
;NJump:_ja_  ;NMove:_cmova_  ;NCSet:_seta_  ),
(PJump:_jnae_;PMove:_cmovnae_;PCSet:_setnae_
;NJump:_jae_ ;NMove:_cmovae_ ;NCSet:_setae_ ),
(PJump:_jnb_ ;PMove:_cmovnb_ ;PCSet:_setnb_
;NJump:_jb_  ;NMove:_cmovb_  ;NCSet:_setb_  ),
(PJump:_jnbe_;PMove:_cmovnbe_;PCSet:_setnbe_
;NJump:_jbe_ ;NMove:_cmovbe_ ;NCSet:_setbe_ ),
(PJump:_jnc_ ;PMove:_cmovnc_ ;PCSet:_setnc_
;NJump:_jc_  ;NMove:_cmovc_  ;NCSet:_setc_  ),
(PJump:_jne_ ;PMove:_cmovne_ ;PCSet:_setne_
;NJump:_je_  ;NMove:_cmove_  ;NCSet:_sete_  ),
(PJump:_jng_ ;PMove:_cmovng_ ;PCSet:_setng_
;NJump:_jg_  ;NMove:_cmovg_  ;NCSet:_setg_  ),
(PJump:_jnge_;PMove:_cmovnge_;PCSet:_setnge_
;NJump:_jge_ ;NMove:_cmovge_ ;NCSet:_setge_ ),
(PJump:_jnl_ ;PMove:_cmovnl_ ;PCSet:_setnl_
;NJump:_jl_  ;NMove:_cmovl_  ;NCSet:_setl_  ),
(PJump:_jnle_;PMove:_cmovnle_;PCSet:_setnle_
;NJump:_jle_ ;NMove:_cmovle_ ;NCSet:_setle_ ),
(PJump:_jno_ ;PMove:_cmovno_ ;PCSet:_setno_
;NJump:_jo_  ;NMove:_cmovo_  ;NCSet:_seto_  ),
(PJump:_jnp_ ;PMove:_cmovnp_ ;PCSet:_setnp_
;NJump:_jp_  ;NMove:_cmovp_  ;NCSet:_setp_  ),
(PJump:_jns_ ;PMove:_cmovns_ ;PCSet:_setns_
;NJump:_js_  ;NMove:_cmovs_  ;NCSet:_sets_  ),
(PJump:_jnz_ ;PMove:_cmovnz_ ;PCSet:_setnz_
;NJump:_jz_  ;NMove:_cmovz_  ;NCSet:_setz_  ),
(PJump:_jo_  ;PMove:_cmovo_  ;PCSet:_seto_
;NJump:_jno_ ;NMove:_cmovno_ ;NCSet:_setno_ ),
(PJump:_jp_  ;PMove:_cmovp_  ;PCSet:_setp_
;NJump:_jnp_ ;NMove:_cmovnp_ ;NCSet:_setnp_ ),
(PJump:_jpe_ ;PMove:_cmovpe_ ;PCSet:_setpe_
;NJump:_jpo_ ;NMove:_cmovpo_ ;NCSet:_setpo_ ),
(PJump:_jpo_ ;PMove:_cmovpo_ ;PCSet:_setpo_
;NJump:_jpe_ ;NMove:_cmovpe_ ;NCSet:_setpe_ ),
(PJump:_js_  ;PMove:_cmovs_  ;PCSet:_sets_
;NJump:_jns_ ;NMove:_cmovns_ ;NCSet:_setns_ ),
(PJump:_jz_  ;PMove:_cmovz_  ;PCSet:_setz_
;NJump:_jnz_ ;NMove:_cmovnz_ ;NCSet:_setnz_ ));



function ConditionIndex(X : pAsmRecord): Byte;
var
   i : Byte;
begin
   i := 0;
   if (X = nil) or (X^.a <> _opcode) then begin
      ConditionIndex := $FF;
      Exit;
   end;
   while ( ConvArray[i].PJump <> X^.op ) and ( i <= 29 ) do inc(i);
   if ( ConvArray[i].PJump <> X^.op ) then i := $FF;
   ConditionIndex := i;
end {ConditionIndex};



function BRNewLabel: TLabel;
var
   S : String;
begin
   Str(BRLabelCount, S);
   Inc(BRLabelCount);
   BRNewLabel := BLabelPrefix + S;
end {BRNewLabel};



function FindLabel(L : TLabel; var Start : pAsmRecord): pAsmRecord;
var
   Node  : pAsmRecord;
   Found : Boolean;
begin
   Node  := Start;
   Found := false;
   while (not Found) and ( Node <> nil ) do begin
      Found := ( Node^.a = _labels ) and ( Node^.lab = L );
      if ( not Found ) then Node := Node^.next;
   end;
   FindLabel := Node;
end {FindLabel};



function GetNextOp(a : pAsmRecord): pAsmRecord;
begin
   if ( a <> nil ) then
      GetNextOp := a^.next
   else
      GetNextOp := nil;
end {GetNextOp};



function InlineCode(depth : Byte; P : array of pAsmRecord): Boolean;
var
   i : Byte;
   B : Boolean;
begin
   B := false;
   for i := 0 to depth-1 do B := B or P[i]^._inline;
   InlineCode := B;
end {InlineCode};



function MatchPattern(ID: Byte; P : array of pAsmRecord): Boolean;
var
   B     : Boolean;
   Temp1 : pAsmRecord;
   Temp2 : pAsmRecord;
begin
   { allways check: p[0]^.o1.o = _lab }

   B := false;
   case ID of
   1:
{
      if not InlineCode(3, P) then begin
         if (p[0]^.a = _opcode) and
            (p[1]^.a = _opcode) and
            (p[2]^.a = _labels) then begin
            if (p[1]^.op = _mov_) and
               (p[1]^.o1.size <> 1) then begin
               if (p[0]^.o1.o = _lab) and
                  (p[0]^.o1.lab = p[2]^.lab) then begin
                  B := true;
               end;
            end;
         end;
      end;
}
      if not InlineCode(3, P) then begin
         if (p[0]^.a = _opcode) and
            (p[1]^.a = _opcode) and
            (p[2]^.a = _labels) then begin
            if (p[1]^.op = _mov_) and
               (p[1]^.o1.size <> 1) and
               (p[1]^.o1.o = _reg ) and
              ((p[1]^.o2.o = _reg ) or
               (p[1]^.o2.o = _mem )) then begin
               if (p[0]^.o1.o = _lab) and
                  (p[0]^.o1.lab = p[2]^.lab) then begin
                  B := true;
               end;
            end;
         end;
      end;

   2:
{
      if not InlineCode(6, P) then begin
         if (p[0]^.a = _opcode) and
            (p[1]^.a = _opcode) and
            (p[2]^.a = _opcode) and
            (p[3]^.a = _labels) and
            (p[4]^.a = _opcode) and
            (p[5]^.a = _labels) then begin
            if (p[0]^.o1.o = _lab) and
               (p[2]^.o1.o = _lab) then begin
               if (p[0]^.o1.lab = p[3]^.lab) and
                  (p[2]^.o1.lab = p[5]^.lab) then begin
                  if (p[1]^.op = _mov_) and
                     (p[4]^.op = _mov_) and
                     (p[2]^.op = _jmp_) then begin
                     if (p[1]^.o1.size <> 1) and
                        (p[4]^.o1.size <> 1) then begin
                        B := true;
                     end;
                  end;
               end;
            end;
         end;
      end;
}
      if not InlineCode(6, P) then begin
         if (p[0]^.a = _opcode) and
            (p[1]^.a = _opcode) and
            (p[2]^.a = _opcode) and
            (p[3]^.a = _labels) and
            (p[4]^.a = _opcode) and
            (p[5]^.a = _labels) then begin
            if (p[0]^.o1.o = _lab) and
               (p[2]^.o1.o = _lab) then begin
               if (p[0]^.o1.lab = p[3]^.lab) and
                  (p[2]^.o1.lab = p[5]^.lab) then begin
                  if (p[1]^.op = _mov_) and
                     (p[4]^.op = _mov_) and
                     (p[2]^.op = _jmp_) then  begin
                     if (p[1]^.o1.size <> 1)  and
                        (p[4]^.o1.size <> 1)  and
                        (p[1]^.o1.o = _reg )  and
                        (p[4]^.o1.o = _reg )  and
                       ((p[1]^.o2.o = _reg )  or
                        (p[1]^.o2.o = _mem )) and
                       ((p[4]^.o2.o = _reg )  or
                        (p[4]^.o2.o = _mem )) then begin
                        B := true; {uff}
                     end;
                  end;
               end;
            end;
         end;
      end;

   3:
{
      if not InlineCode(4, P) then begin
         if (p[0]^.a = _opcode) and
            (p[1]^.a = _opcode) and
            (p[2]^.a = _opcode) and
            (p[3]^.a = _labels) then begin
            if (p[0]^.o1.o = _lab) and
               (p[0]^.o1.lab = p[3]^.lab) then begin
               if (p[1]^.op = _mov_) and
                  (p[1]^.o1.size <> 1) then begin
                  if (p[2]^.op = _jmp_) then begin
                     B := true;
                  end;
               end;
            end;
         end;
      end;
}
      if not InlineCode(4, P) then begin
         if (p[0]^.a = _opcode) and
            (p[1]^.a = _opcode) and
            (p[2]^.a = _opcode) and
            (p[3]^.a = _labels) then begin
            if (p[0]^.o1.o = _lab) and
               (p[0]^.o1.lab = p[3]^.lab) then begin
               if (p[1]^.op = _mov_)   and
                  (p[1]^.o1.size <> 1) and
                  (p[1]^.o1.o = _reg)  and
                 ((p[1]^.o2.o = _reg)  or
                  (p[1]^.o2.o = _mem)) then begin
                  if (p[2]^.op = _jmp_) then begin
                     B := true;
                  end;
               end;
            end;
         end;
      end;


   4:
      if not InlineCode(3, P) then begin
         if (p[0]^.a = _opcode) and
            (p[1]^.a = _opcode) and
            (p[2]^.a = _labels) then begin
            if (p[0]^.o1.o = _lab) and
               (p[1]^.o1.o = _lab) then begin
               if (p[0]^.o1.lab = p[2]^.lab) and
                  (p[1]^.o1.lab = p[2]^.lab) then begin
                  B := true;
               end;
            end;
         end;
      end;

   5:
      if not InlineCode(2, P) then begin
         if (p[0]^.a = _opcode) and
            (p[1]^.a = _labels) then begin
            if (p[0]^.o1.o = _lab) and
               (p[0]^.o1.lab = p[1]^.lab ) then begin
               B := true;
            end;
         end;
      end;

   6:
      if not InlineCode(3, P) then begin
         if (p[0]^.a = _opcode) and
            (p[1]^.a = _opcode) and
            (p[2]^.a = _labels) then begin
            if (p[0]^.o1.o = _lab) and
               (p[1]^.o1.o = _lab) then begin
               if (p[1]^.op = _jmp_) and
                  (p[0]^.o1.lab = p[2]^.lab) then begin
                  B := true;
               end;
            end;
         end;
      end;

   7:
      if not InlineCode(6, P) then begin
         if (P[0]^.a = _opcode) and
            (P[1]^.a = _opcode) and
            (P[2]^.a = _opcode) and
            (P[3]^.a = _labels) and
            (P[4]^.a = _opcode) and
            (P[5]^.a = _labels) then begin
            if (P[0]^.o1.o = _lab) and
               (P[1]^.o2.o = _ord) and
               (P[2]^.o1.o = _lab) and
               (P[4]^.o2.o = _ord) then begin
               if (P[1]^.op = _mov_) and
                  (P[2]^.op = _jmp_) and
                  (P[4]^.op = _mov_) then begin
                  if (P[0]^.o1.lab = P[3]^.lab) and
                     (P[2]^.o1.lab = P[5]^.lab) then begin
                     if equal_loc(P[1]^.o1.loc, P[4]^.o1.loc) then
                        B := true;
                  end;
               end;
            end;
         end;
      end;

   8:
      if not InlineCode(2, P) then begin
         if (P[0]^.a =  _opcode) and
            (P[1]^.a <> _labels) then begin
            if (P[0]^.op = _jmp_) then begin
               B := true;
            end;
         end;
      end;

   9:
      if not InlineCode(2, P) then begin
         if (P[0]^.a = _opcode) and
            (P[1]^.a = _labels) then begin
            if (P[0]^.op = _jmp_) then begin
               if (P[0]^.o1.lab = P[1]^.lab) then begin
                  B := true;
               end;
            end;
         end;
      end;

   10:
      if not InlineCode(6, P) then begin
         if (P[0]^.a = _opcode) and (P[0]^.o1.o = _lab) then begin
            Temp1 := FindLabel(P[0]^.o1.lab, P[0]);
            if (Temp1 <> nil) and (Temp1^.prev <> nil) then begin
               if (Temp1 <> P[1]) and (P[1]^.a <> _labels) then begin
                  Temp2 := Temp1^.prev;
                  if (Temp2^.a = _opcode) and (Temp2^.op = _jmp_) then begin
                     if (Temp2^.o1.lab <> Temp1^.lab) then begin
                        Temp2 := FindLabel(Temp2^.o1.lab, Temp1);
                        if (Temp2 <> nil) and (Temp1 <> Temp2) then begin
                           B := true;
                        end;
                     end;
                  end;
               end;
            end;
         end;
      end;

   end;
   MatchPattern := B;
end {MatchPattern};



function FindFreeReg(a,b : pAsmRecord): regs;
var
   FreeRegs : set of Regs;
   R        : Regs;

procedure ExcludeRegs(X : Operand);
begin
   case X.o of
      _reg : FreeRegs := FreeRegs - [X.reg];
      _mem : case X.loc.l of
         register:
            begin
               FreeRegs := FreeRegs - [X.loc.reg];
            end;
         port,directmem,memref:
            begin
               FreeRegs := FreeRegs - [X.loc.index];
               FreeRegs := FreeRegs - [X.loc.base];
            end;
      end;
   end;
end {ExcludeRegs};


begin
   FreeRegs := [eax..ebx];
   if (a <> nil ) then begin
      ExcludeRegs(a^.o1);
      ExcludeRegs(a^.o2);
      ExcludeRegs(a^.o3);
   end;
   if (b <> nil) then begin
      ExcludeRegs(b^.o1);
      ExcludeRegs(b^.o2);
      ExcludeRegs(b^.o3);
   end;
   if (eax in FreeRegs) then
      R := eax
   else if (edx in FreeRegs) then
      R := edx
   else if (ecx in FreeRegs) then
      R := ecx
   else if (ebx in FreeRegs) then
      R := ebx
   else
      R := none;
   FindFreeReg := R;
end {FindFreeReg};



function JumpsTo(var a : tAsmList; Lab : TLabel): Word;
var
   Node : pAsmRecord;
   N    : Word;
begin
   N := 0;
   Node := a.first;
   while ( Node <> nil ) do begin
      if (Node^.a = _opcode) and
         (Node^.o1.o = _lab) and
         (Node^.o1.lab = lab) then begin
         Inc(N);
      end;
      Node := Node^.next;
   end;
   JumpsTo := N;
end {JumpsTo};



function QueueEmpty(depth : Byte; P : array of pAsmRecord): Boolean;
var
   i : Byte;
   B : Boolean;
begin
   B := false;
   for i := 0 to depth-1 do B := B or (P[i] = nil);
   QueueEmpty := B;
end {QueueEmpty};



procedure FetchQueue(var P : array of pAsmRecord; Start : pAsmRecord);
var
   i : Byte;
begin
   P[0] := Start;
   for i := 1 to high(P) do P[i] := GetNextOp(P[i-1]);
end {FetchQueue};



function EqualOperands(X,Y : operand): Boolean;
var
   B : Boolean;
begin
   B := false;
   if (X.size = Y.size) and (X.o = Y.o) then begin
      case X.o of
         _reg : B := (X.reg = Y.reg);
         _mem : B := equal_loc(X.loc, Y.loc);
         _ord : B := (X.n = Y.n);
      end;
   end;
   EqualOperands := B;
end {EqualOperands};



function BothMove(X,Y : pAsmRecord): Boolean;
var
   B : Boolean;
begin
   B := false;
   if not (X^._inline or Y^._inline) then begin
      if (X^.a = _opcode) and (X^.op = _mov_) and
         (Y^.a = _opcode) and (Y^.op = _mov_) then begin
         B := true;
      end;
   end;
   BothMove := B;
end {BothMove};



function EqualMove(X,Y : pAsmRecord): Boolean;
var
   B : Boolean;
begin
   B := false;
   if BothMove(X, Y) then begin
      if EqualOperands(X^.o1, Y^.o1) and
         EqualOperands(X^.o2, Y^.o2) then begin
         B := true;
      end;
   end;
   EqualMove := B;
end {EqualMove};


const
   CMOVRequired : Boolean = false;

function CanProcess(U,V : array of pAsmRecord): Boolean;
var
   B : Boolean;
begin
   B := EqualMove(U[0], V[0]);
   if CMOVAllowed and (not B) then begin
      if BothMove(U[0], V[0]) and EqualMove(U[1], V[1]) then begin
         if (U[0]^.o1.size <> 1) and
            (V[0]^.o1.size <> 1) then begin
            B := true;
         end;
      end;
   end;
   CanProcess := B;
end {CanProcess};



procedure BranchRemover(var a : tAsmList);
var
   i		: Byte;
   P		: array [0..9] of pAsmRecord;
   U		: array [0..9] of pAsmRecord;
   V		: array [0..9] of pAsmRecord;
   xcmp		: pAsmRecord;
   xxor		: pAsmRecord;
   xmov		: pAsmRecord;
   xreg		: regs;
   C1		: Longint;
   C2		: Longint;
   loc		: location;
   jump		: opcode_num;
   Alias	: TLabel;
   Label1	: TLabel;
   Label2	: TLabel;
   Label3	: TLabel;
   Label4	: TLabel;
   Changed	: Boolean;
   Made		: Boolean;

begin
   CleanLabels(a);

   FetchQueue(P, a.first);
   while not QueueEmpty(2, P) do begin
      if MatchPattern(8, P) then begin
         while (P[1]^.a <> _labels) do begin
            DeleteAsmEntry(P[1]);
            FetchQueue(P, P[0]);
         end;
      end;
      FetchQueue(P, GetNextOp(P[1]));
   end;

   FetchQueue(P, a.first);
   while not QueueEmpty(6, P) do begin

      if MatchPattern(10, P) then begin
         i := ConditionIndex(P[0]);
         if (i = $FF) then Error('Internal error in BranchRemover, #0001');
         Label1 := P[0]^.o1.lab;
         Label2 := FindLabel(Label1, P[0])^.prev^.o1.lab;
         if (JumpsTo(a, Label1) = 1) then begin
            FetchQueue(V, P[1]);
            FetchQueue(U, FindLabel(Label1, P[0])^.next);
            while CanProcess(U, V) do begin
               if EqualMove(U[0], V[0]) then begin
                  xmov := NewAsmEntry;
                  xmov^ := V[0]^;
                  InsertAsmAbove(P[0], xmov);
               {
                  Add a new branch, which can be
                  optimized later.
                  Only if CMOV available.

                  Jcc  Label3
                  MOV  Dest1, Srce1
                  JMP  Label4
                  Label3:
                  MOV  Dest2, Srce2
                  Label4:
               }
               end else begin
                  Label3 := BRNewLabel;
                  Label4 := BRNewLabel;
                  xmov := NewAsmEntry;
                  set_lab_non(xmov, ConvArray[i].PJump, _nothing, Label3);
                  InsertAsmAbove(P[0], xmov);
                  xmov := NewAsmEntry;
                  xmov^ := V[0]^;
                  InsertAsmAbove(P[0], xmov);
                  xmov := NewAsmEntry;
                  set_lab_non(xmov, _jmp_, _nothing, Label4);
                  InsertAsmAbove(P[0], xmov);
                  xmov := NewAsmEntry;
                  set_label(xmov, Label3);
                  InsertAsmAbove(P[0], xmov);
                  xmov := NewAsmEntry;
                  xmov^ := U[0]^;
                  InsertAsmAbove(P[0], xmov);
                  xmov := NewAsmEntry;
                  set_label(xmov, Label4);
                  InsertAsmAbove(P[0], xmov);
               end;
               DeleteAsmEntry(U[0]);
               DeleteAsmEntry(V[0]);
               FetchQueue(V, V[1]);
               FetchQueue(U, U[1]);
            end;
         end;
         {FetchQueue(P, (FindLabel(Label2, P[0])));}
         FetchQueue(P, P[1]);
      end else begin
         FetchQueue(P, P[1]);
      end;
   end;

   if CMOVAllowed then begin
      FetchQueue(P, a.first);
      while not QueueEmpty(1, P) do begin
         Made := false;

         if (not QueueEmpty(3, P)) and MatchPattern(1, P) then begin
            i := ConditionIndex(P[0]);
            if ( i <> $FF ) then begin
               P[1]^.op := ConvArray[i].NMove;
               DeleteAsmEntry(P[0]);
               FetchQueue(P, GetNextOp(P[2]));
               Made := true;
            end;
         end;

         if (not QueueEmpty(6, P)) and MatchPattern(2, P) then begin
            i := ConditionIndex(P[0]);
            if ( i <> $FF ) and (JumpsTo(a, P[3]^.lab) = 1) then begin
               if not EqualOperands(P[1]^.o1, P[4]^.o1) then
                  P[1]^.op := ConvArray[i].NMove;
               P[4]^.op := ConvArray[i].PMove;
               DeleteAsmEntry(P[0]);
               DeleteAsmEntry(P[2]);
               FetchQueue(P, GetNextOp(P[5]));
               Made := true;
            end;
         end;

         if (not QueueEmpty(4, P)) and MatchPattern(3, P) then begin
            i := ConditionIndex(P[0]);
            if ( i <> $FF ) then begin
               P[1]^.op := ConvArray[i].NMove;
               P[2]^.op := ConvArray[i].NJump;
               DeleteAsmEntry(P[0]);
               FetchQueue(P, GetNextOp(P[3]));
               Made := true;
            end;
         end;

         if not Made then
            FetchQueue(P, P[1])
         else
            CMOVRequired := true; { for TNSe RTL }
      end;
   end;


   CleanLabels(a); { yes, it should be here }

   { common part - without CMOV }

   FetchQueue(P, a.first);
   while not QueueEmpty(1, P) do begin

      Made := false;

      if (not QueueEmpty(2, P)) and MatchPattern(9, P) then begin
         DeleteAsmEntry(P[0]);
         FetchQueue(P, GetNextOp(P[1]));
         Made := true;
      end;

      if (not QueueEmpty(3, P)) and MatchPattern(4, P) then begin
         i := ConditionIndex(P[0]);
         if ( i <> $FF ) then begin
            DeleteAsmEntry(P[0]);
            DeleteAsmEntry(P[1]);
            FetchQueue(P, GetNextOp(P[2]));
            Made := true;
         end;
      end;

      if (not QueueEmpty(3, P)) and MatchPattern(6, P) then begin
         i := ConditionIndex(P[0]);
         if ( i <> $FF ) then begin
            DeleteAsmEntry(P[0]);
            P[1]^.op := ConvArray[i].NJump;
            FetchQueue(P, GetNextOp(P[2]));
            Made := true;
         end;
      end;

      if (not QueueEmpty(2, P)) and MatchPattern(5, P) then begin
         DeleteAsmEntry(P[0]);
         FetchQueue(P, GetNextOp(P[1]));
         Made := true;
      end;

      if (not QueueEmpty(6, P)) and MatchPattern(7, P) then begin
         i := ConditionIndex(P[0]);
         if ( i <> $FF ) then begin
            if (JumpsTo(a, P[3]^.lab) = 1) and (P[1]^.o1.size = 1) then begin
               C1 := P[1]^.o2.n;
               C2 := P[4]^.o2.n;
               Changed := true;
               if (C1 = 0) and (C2 = 1) then begin
                  P[1]^.op := ConvArray[i].PCSet;
                  DeleteAsmEntry(P[4]);
               end else if (C1 = 1) and (C2 = 0) then begin
                  P[1]^.op := ConvArray[i].NCSet;
                  DeleteAsmEntry(P[4]);
               end else if (C2-C1 = 1) then begin
                  P[1]^.op := ConvArray[i].PCSet;
                  set_loc_ord(P[4], _add_, P[4]^.o1.size, P[4]^.o1.loc, C1);
               end else if (C1-C2 = 1) then begin
                  P[1]^.op := ConvArray[i].NCSet;
                  set_loc_ord(P[4], _add_, P[4]^.o1.size, P[4]^.o1.loc, C2);
               end else begin
                  Changed := false;
               end;
               if Changed then begin
                  P[1]^.o2.o := _non;
                  DeleteAsmEntry(P[0]);
                  DeleteAsmEntry(P[2]);
                  DeleteAsmEntry(P[3]);
                  FetchQueue(P, GetNextOp(P[5]));
                  Made := true;
               end;
            end;
         end;
      end;

{      if CPU in [???] then begin}

         if ( ConditionIndex(P[0]) <> $FF ) then begin

            if not QueueEmpty(6, P) and MatchPattern(7, P) then begin
               if (JumpsTo(a, P[3]^.lab) = 1) then begin
                  C1 := P[1]^.o2.n;
                  C2 := P[4]^.o2.n;
                  Changed := true;
                  jump := P[0]^.op;
                  xcmp := P[0]^.prev;
                  xreg := FindFreeReg(xcmp, P[1]);
                  if (xcmp <> nil) and (xreg <> none) and
                     (xcmp^.a = _opcode) and (xcmp^.op = _cmp_) then begin
                     if (jump in [_jae_,_jnb_,_jnc_]) then begin
                        {xreg = $FFFFFFFF if true,  var := C1}
                        {xreg = $00000000 if false, var := C2}
                        if (C1 = 0) and (C2 = 1) then begin
                           set_reg_non(P[2], _inc_, _dword, xreg);
                           DeleteAsmEntry(P[3]);
                        end else if (C2 = 0) then begin
                           set_reg_ord(P[2], _and_, _dword, xreg, C1);
                           DeleteAsmEntry(P[3]);
                        end else if (C2-C1 = 1) then begin
                           set_reg_ord(P[2], _add_, _dword, xreg, C2);
                           DeleteAsmEntry(P[3]);
                        end else begin
                           set_reg_ord(P[2], _and_, _dword, xreg, C1-C2);
                           set_reg_ord(P[3], _add_, _dword, xreg, C2);
                        end;
                     end else if (jump in [_jnae_,_jb_,_jc_]) then begin
                        {xreg = $00000000 if true,  var := C1}
                        {xreg = $FFFFFFFF if false, var := C2}
                        if (C1 = 1) and (C2 = 0) then begin
                           set_reg_non(P[2], _inc_, _dword, xreg);
                           DeleteAsmEntry(P[3]);
                        end else if (C1 = 0) then begin
                           set_reg_ord(P[2], _and_, _dword, xreg, C2);
                           DeleteAsmEntry(P[3]);
                        end else if (C1-C2 = 1) then begin
                           set_reg_ord(P[2], _add_, _dword, xreg, C1);
                           DeleteAsmEntry(P[3]);
                        end else begin
                           set_reg_ord(P[2], _and_, _dword, xreg, C2-C1);
                           set_reg_ord(P[3], _add_, _dword, xreg, C1);
                        end;
                     end else begin
                        Changed := false;
                     end;
                     if Changed then begin
                        DeleteAsmEntry(P[0]);
                        set_reg_reg(P[1], _sbb_, _dword, xreg, _dword, xreg);
                        set_loc_reg(P[4], _mov_, P[4]^.o1.size, P[4]^.o1.loc, P[4]^.o1.size, xreg);
                        FetchQueue(P, GetNextOp(P[5]));
                        Made := true;
                     end;
                  end;
               end;
            end;
         end;
{      end;}


{      if CPU in [???] then begin}

         i := ConditionIndex(P[0]);
         if ( i <> $FF ) then begin

            if not QueueEmpty(6, P) and MatchPattern(7, P) then begin
               if (JumpsTo(a, P[3]^.lab) = 1) then begin
                  C1 := P[1]^.o2.n;
                  C2 := P[4]^.o2.n;
                  xcmp := P[0]^.prev;
                  xreg := FindFreeReg(xcmp, P[1]);
                  if (xcmp <> nil) and (xreg <> none) and
                     (xcmp^.a = _opcode) and (xcmp^.op = _cmp_) then begin
                     {let's assume that xcmp sets flags}
                     {if not -> crash}
                     xxor := NewAsmEntry;
                     InsertAsmAbove(xcmp, xxor);
                     set_reg_reg(xxor, _xor_, _dword, xreg, _dword, xreg);
                     {1. C1 = 0, C2 = 1, true/false}
                     if (C1 = 0) and (C2 = 1) then begin
                        set_reg_non(P[0], ConvArray[i].PCSet, _byte, xreg);
                        set_loc_reg(P[1], _mov_, P[1]^.o1.size, P[1]^.o1.loc, P[1]^.o1.size, xreg);
                        DeleteAsmEntry(P[2]);
                        DeleteAsmEntry(P[3]);
                        DeleteAsmEntry(P[4]);
                     {2. C1 = 1, C2 = 0, true/false}
                     end else if (C1 = 1) and (C2 = 0) then begin
                        set_reg_non(P[0], ConvArray[i].NCSet, _byte, xreg);
                        set_loc_reg(P[1], _mov_, P[1]^.o1.size, P[1]^.o1.loc, P[1]^.o1.size, xreg);
                        DeleteAsmEntry(P[2]);
                        DeleteAsmEntry(P[3]);
                        DeleteAsmEntry(P[4]);
                     {3. C1-C2 in [2,3,5,9]}
                     end else if (C1-C2 in [2,3,5,9]) then begin
                        set_loc(loc, xreg, xreg, C1-C2-1, C2);
                        set_reg_non(P[0], ConvArray[i].NCSet, _byte, xreg);
                        set_reg_loc(P[1], _lea_, _dword, xreg, _nothing, loc);
                        set_loc_reg(P[4], _mov_, P[4]^.o1.size, P[4]^.o1.loc, P[4]^.o1.size, xreg);
                        DeleteAsmEntry(P[2]);
                        DeleteAsmEntry(P[3]);
                     {4. C2-C1 in [2,3,5,9]}
                     end else if (C2-C1 in [2,3,5,9]) then begin
                        set_loc(loc, xreg, xreg, C2-C1-1, C1);
                        set_reg_non(P[0], ConvArray[i].PCSet, _byte, xreg);
                        set_reg_loc(P[1], _lea_, _dword, xreg, _nothing, loc);
                        set_loc_reg(P[4], _mov_, P[4]^.o1.size, P[4]^.o1.loc, P[4]^.o1.size, xreg);
                        DeleteAsmEntry(P[2]);
                        DeleteAsmEntry(P[3]);
                     {5. C1 = 0, C2 <> 0}
                     end else if (C1 = 0) and (C2 <> 0) then begin
                        set_reg_non(P[0], ConvArray[i].NCSet, _byte, xreg);
                        set_reg_non(P[1], _dec_, _dword, xreg);
                        set_reg_ord(P[2], _and_, _dword, xreg, C2);
                        set_loc_reg(P[4], _mov_, P[4]^.o1.size, P[4]^.o1.loc, P[4]^.o1.size, xreg);
                        DeleteAsmEntry(P[3]);
                     {6. C1 <> 0, C2 = 0}
                     end else if (C1 <> 0) and (C2 = 0) then begin
                        set_reg_non(P[0], ConvArray[i].PCSet, _byte, xreg);
                        set_reg_non(P[1], _dec_, _dword, xreg);
                        set_reg_ord(P[2], _and_, _dword, xreg, C1);
                        set_loc_reg(P[4], _mov_, P[4]^.o1.size, P[4]^.o1.loc, P[4]^.o1.size, xreg);
                        DeleteAsmEntry(P[3]);
                     {7. C1 = C2 - stupid code}
                     end else if (C1 = C2) then begin
                        DeleteAsmEntry(xxor);
                        DeleteAsmEntry(P[0]);
                        DeleteAsmEntry(P[2]);
                        DeleteAsmEntry(P[3]);
                        DeleteAsmEntry(P[4]);
                     {8. none of the above}
                     end else begin
                        set_reg_non(P[0], ConvArray[i].PCSet, _byte, xreg);
                        set_reg_non(P[1], _dec_, _dword, xreg);
                        set_reg_ord(P[2], _and_, _dword, xreg, C2-C1);
                        set_reg_ord(P[3], _add_, _dword, xreg, C1);
                        set_loc_reg(P[4], _mov_, P[4]^.o1.size, P[4]^.o1.loc, P[4]^.o1.size, xreg);
                     end;
                  end;
                  FetchQueue(P, GetNextOp(P[5]));
                  Made := true;
               end;
            end;
         end;
{      end;}
      if not Made then FetchQueue(P, P[1]);
   end;

   { TNSes pass - check for labels with jmps only }
   { IE:                                          }
   {            - and look for other jumps to L10 }
   { l10:       - if any, replace with L11        }
   {  jmp l11                               PT    }

   p[1] := a.first;
   While (p[1] <> nil) do begin
      If (p[1]^.a = _labels) then begin
         p[2] := p[1]^.next;
         If (p[2] = nil) then begin
            Break;
         end;
         If (p[2]^.a = _opcode) AND (p[2]^.op = _jmp_) then begin
            Alias := p[2]^.o1.lab;
            p[2] := a.first;
            While (p[2] <> nil) do begin
               If (p[2]^.o1.o = _lab) then begin { This is a jump of some kind }
                  If (p[2]^.o1.lab = p[1]^.lab) then p[2]^.o1.lab := Alias;
               end;
               p[2] := p[2]^.next;
            end;
            p[1] := p[1]^.next;
            Continue;
         end;
      end;
      p[1] := p[1]^.next;
   end;

   CleanLabels(a);

end {BranchRemover};

procedure LowLevelOptimize(var a: tAsmList);
begin
  if Options.OptimizeLevel >= 1 then
    begin
      LowLevelOptimize3(a); {optimisations, _three_ lines}
      LowLevelOptimize2(a); {optimisations, _two_ lines}
      LowLevelOptimize1(a); {optimisations, _one_ line}
      CleanLabels(a);       {removes duplicate labels}
    end;

  if Options.OptimizeLevel >= 2 then OptimizeRegisterUsageMK3(a);
  if Options.OptimizeLevel >= 3 then OptimizeMemoryLoads(a);
  CMOVAllowed:=(CPU=PPro) or (CPU=PII) or (CPU=PIII) or (CPU=K7);
  if Options.OptimizeLevel >= 4 then BranchRemover(a);
  if Options.OptimizeLevel >= 4 then AnalyzeRegisterUsage(a);
end;

end.

{
* mov reg1,imm			lea reg1,[reg2+imm]
* add reg1,reg2

* mov reg1,reg2			lea reg1,[reg2+imm]
* add reg1,imm

* mov reg1,reg2			lea reg1,[reg2-imm]
* sub reg1,imm

* mov reg1,reg2			lea reg1,[reg2*2]
* add reg1,reg1	

* add reg1,reg2			lea reg1,[reg1+reg2*2]
* add reg1,reg2

* mov reg1,reg2			lea reg1,[reg2+reg3]
* add reg1,reg3

* mov reg1,reg2			lea reg1,[reg2-reg3]
* sub reg1,reg3

* mov reg1,reg2			lea reg1,[reg2*(2^imm1)+reg3]
* shl reg1,imm1
* add reg1,reg3

* mov reg1,reg2			lea reg1,[reg2*(2^imm1)-reg3]
* shl reg1,imm1
* sub reg1,reg3

* lea reg1,[reg2*imm1+imm2]	lea reg1,[reg2*imm1+reg3+imm2]
* add reg1,reg3			(ouch? It gets WORSE BWAHAHAHA)

* lea reg1,[reg2*imm1+imm2]	lea reg1,[reg2*imm1+(imm2+imm3)]
* add reg1,imm3

* lea reg1,[reg2*imm1+imm2]	lea reg1,[reg2*imm1+(imm2-imm3)]
* sub reg1,imm3			(double ouch wahahahaa)

* lea reg1,[reg2+reg3+imm1]	lea reg1,[reg2+reg1*2+(imm1+imm2)]
* lea reg1,[reg3+imm2]		(Triple ouch? Mwahahah)

* lea reg1,[reg2*imm1-imm2]	lea reg1,[reg2*imm1+(imm3-imm2)]
* lea reg1,[reg1+imm3]		lea reg1,[reg1] 		(removed)

* lea reg1,[reg2*imm1-imm2]	lea reg1,[reg2*imm1]
* lea reg1,[reg1+imm2]		lea reg1,[reg1]			(removed)
(How can you implement these things??!???)

* lea reg1,[reg1+reg2+imm1]	lea reg1,[reg1+reg2+(imm1+imm2]
* lea reg1,[reg1+reg3+imm2]	lea reg1,[reg1+reg3]
(Okok, saves 1 byte, who cares???? (me/you: nahh))

We should have an engine using the combination of
add, mov, sub, lea to make LEA's.
It should be triggered when it encounters a mov/lea followed by
add/sub(/shl/shr/lea), where none of these have a memory reference,
and start calculating out a replacement lea.
Ok, so I might try making one, can't guarantee success though.... ;)



--- Some small AAGIs (Anti - AGI's ;) ---

* mov reg1,reg2			mov reg1,reg2
* mov [reg1],imm1		mov [reg2],imm1		(kills an AGI)

* mov reg1,reg2			mov reg1,reg2
* mov [reg1+imm1+reg3],imm2	mov [reg2+imm1+reg3],imm2

* lea reg1,[reg2+reg3*imm1]	lea reg1,[reg2+reg3*imm1]
* mov [reg1+imm2],whatever	mov [reg2+reg3*imm1+imm2],whatever
(Hnnnggg... I'ts EVIL)

* lea reg1,[reg2+reg3*imm1+imm2] 
* mov [reg1+reg3*imm3+imm4],whatever
(Whoa ... becomes:)
- lea reg1,[reg2+reg3*imm1+imm2]
- mov [reg2+reg3*(imm1*imm3)+(imm2+imm4)],whatever
(OVERKILL!!!!! OK ... so THIS is the limit for impossibility!)

General rule for these:
#1:  xxx LEFT SIDE,RIGHT SIDE
#2:  xxx [LEFT SIDE],RIGHT SIDE

Check if LEFT SIDE of #1 exists in the []'s of #2
in that case, replace #2 [LEFT SIDE] with #1 RIGHT SIDE

Remember that #2 can be:
mov, add, or, xor, and, cmp, test, sub, rol, ror, rcl, rcr, shr, shl
you name it.............



Hope you still can get some sleep after reading this.
I will not be able to sleep, knowing I completely killed you
with this info???? ;)


Some of the above SHOULD be ignored, for sanity's sake <g>


Thomas Steen; More SANE Peepholes come as I fall through them.
TNSe@hotmail.com
}

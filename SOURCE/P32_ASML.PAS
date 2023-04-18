{                         P32 - 32bit Pascal Compiler                       }
{ ------------------------------------------------------------------------- }
{                       Johan Prins - jprins@knoware.nl                     }
{ ========================================================================= }
{ Routines for the assembler writing routines                               }
{                                                  (c) Copyright 1996-1999  }
{                                                                           }
{ ------------------------------------------------------------------------- }

unit P32_asml;

interface

uses P32_symb, P32_asm, P32_prep, P32_scan, P32_err;

const
   AsmLine: longint=0;

   _offset  = -1;
   _nothing = 0;
   _byte    = 1;
   _word    = 2;
   _dword   = 4;
   _qword   = 8;
   _tbyte   = 10;
   _near_    = 16;

   Tab    = ^I;

type
   asmnodetype = ( _empty, _labels, _str, _opcode);

   operandtype = ( _non, _reg, _mem, _ord, _lab, _fpu, _mmx);

   pAsmRecord =  ^AsmRecord;

   tAsmList    = record
                   First : pAsmRecord;
                   Rear  : pAsmRecord;
                 end;

   Operand    = record
                  size : shortint;            {contains operand size of 8, 16, 32 bits}
                  case o: operandtype of
                  _non : ();
                  _reg : (reg: regs);
                  _mem : (loc: location);
                  _ord : (  n: longint);
                  _lab : (lab: string[127]);
                  _mmx,
                  _fpu : (  f: integer);
                end;

   AsmRecord  = record
                  prev,
                  next  : pAsmRecord; {pointers to other records}
                  _inline: boolean;
                  case a: AsmNodeType of
                   _empty: ();
                  _labels: (lab: string[127]);
                  _string: (  s: string[127]);
                  _opcode: ( op: opcode_num;  {index # of in opcode table}
                             o1,
                             o2,
                             o3: operand);
                end;
var AsmList: tAsmList;

procedure CreateAsmList;
function  NewAsmEntry: pAsmRecord;
procedure AddAsmEntry(var a: pAsmRecord);
procedure InsertAsmEntry(var a: pAsmRecord);
procedure DeleteAsmEntry(var a: pAsmRecord);
procedure RemoveLastAsmEntry;
procedure DestroyAsmList;
procedure DumpAsmList;
procedure AttachAsmList(list: tAsmList);

procedure emit_label(const lab:string);
procedure emit_string(const s:string);
procedure iemit_label(const lab:string);
procedure iemit_string(const s:string);

procedure emit_non(op: opcode_num);
procedure emit_reg(op: opcode_num; s: integer; r: regs);
procedure emit_loc(op: opcode_num; s: integer;var loc: location);
procedure emit_ord(op: opcode_num; s: integer; n:longint);
procedure emit_lab(op: opcode_num; s: integer; const lab:string);
procedure emit_fpu(op: opcode_num; f: integer);
procedure emit_mmx(op: opcode_num; f: integer);

procedure iemit_reg(op: opcode_num; s: integer; r: regs);
procedure iemit_lab(op: opcode_num; s: integer; const lab:string);

procedure emit_reg_reg(op: opcode_num; s1: integer; r1: regs; s2:integer; r2: regs);
procedure emit_reg_loc(op: opcode_num; s1: integer; r: regs; s2: integer;var loc:location);
procedure emit_reg_ord(op: opcode_num; s1: integer; r: regs; n:longint);
procedure emit_reg_lab(op: opcode_num; s1: integer; r: regs; s2: integer; const lab:string);

procedure emit_reg_reg_reg(op: opcode_num; s1: integer; r1: regs; s2:integer; r2: regs; s3:integer; r3: regs);
procedure emit_reg_reg_ord(op: opcode_num; s1: integer; r1: regs; s2:integer; r2: regs; n:longint);

procedure iemit_reg_reg(op: opcode_num; s1: integer; r1: regs; s2:integer; r2: regs);
procedure iemit_reg_ord(op: opcode_num; s1: integer; r: regs; n:longint);

procedure emit_loc_reg(op: opcode_num; s1: integer;var loc:location;s2: integer; r: regs);
procedure emit_loc_loc(op: opcode_num; s1: integer;var loc1: location; s2: integer;var loc2: location);
procedure emit_loc_ord(op: opcode_num; s: integer;var loc: location; n: longint);
procedure emit_loc_mmx(op: opcode_num; s: integer;var loc: location; f: integer);

procedure emit_ord_reg(op: opcode_num; n:longint; s1: integer; r: regs);
procedure emit_mmx_reg(op: opcode_num; f1: integer; s2: integer; r: regs);
procedure emit_mmx_loc(op: opcode_num; f: integer; s: integer; var loc: location);

procedure emit_fpu_fpu(op: opcode_num; f1, f2: integer);
procedure emit_mmx_mmx(op: opcode_num; f1, f2: integer);

procedure InsertAsmAbove(var a,b : pAsmRecord);
procedure set_lab_non(var a: pAsmRecord; op: opcode_num; s: integer; const lab:string);
procedure set_label(var a: pAsmRecord; const lab:string);
procedure set_reg_non(var a: pAsmRecord; op: opcode_num; s: integer;  r: regs);
procedure set_reg_ord(var a: pAsmRecord; op: opcode_num; s1: integer; r: regs; n:longint);
procedure set_reg_loc(var a: pAsmRecord; op: opcode_num; s1: integer; r: regs; s2: integer; var loc:location);
procedure set_reg_reg(var a: pAsmRecord; op: opcode_num; s1: integer; r1: regs; s2:integer; r2: regs);

procedure set_loc(var loc : location; i,b : regs; f: Byte; o : Longint);
procedure set_loc_reg(var a: pAsmRecord; op: opcode_num; s1: integer; var loc:location;s2: integer; r: regs);
procedure set_loc_ord(var a: pAsmRecord; op: opcode_num; s1: integer;var loc:location; n: integer);

procedure ClearLoc(var l:location);
function CreateName(var l : location) : string;

implementation

procedure ClearLoc(var l:location);
{ Clear the location-record }

begin
  l.prefix:=none;
  case l.l of
  register : l.reg:=none;
  port,
  directmem,
  memref   : begin
               l.base:=none;
               l.index:=none;
               l.factor:=1;
               l.offset:=0;
               {l.name:=NIL}
               l.name:='';
             end;
  end;
end;


function CreateName(var l : location) : string;
{ Composes a name of the data that's in the location record }
var s : string;

begin
  if l.l=directmem then
    begin
      l.name:='';
      l.prefix:=fs;
    end;

  s:=l.name;
  if l.base<>none then if s='' then s:=r[l.base]
                               else s:=s + ' + ' + r[l.base];
  if l.index<>none then begin
                          if s='' then s:=r[l.index]
                                  else s:=s + ' + ' + r[l.index];
                          if l.factor>1 then s:=s + ' * ' + Numb(l.factor);
                        end;

  if (l.base=none) and (l.index=none) and (l.name='') then s:=Numb(l.offset)
    else if l.offset<0 then s:=s + ' - ' + Numb(-l.offset)
                       else if l.offset>0 then s:=s + ' + ' + Numb(l.offset);

  if l.prefix<>none then s:=r[l.prefix]+':'+s;
  CreateName:=s;
end;

procedure CreateAsmList;
begin
{  if (AsmList.first<>NIL) then Error('asmlist not empty');}
  AsmList.first:=NIL;
  AsmList.rear :=NIL;
end;

function NewAsmEntry: pAsmRecord;
var a: pAsmRecord;
begin
  new(a);
  fillchar(a^, sizeof(a^), 0);
  if Options.OptimizeInlineCode then a^._inline:=FALSE
                                else a^._inline:=asmmode;
  NewAsmEntry:= a;
end;

procedure AddAsmEntry(var a: pAsmRecord);
var dummy, temp : pAsmRecord;

begin
  temp := a;
  temp^.next := nil;
  temp^.prev := AsmList.Rear;
  If (AsmList.Rear = NIL) then
    begin
      AsmList.First := temp;
      AsmList.Rear := temp;
    end
  else
    begin
      AsmList.Rear^.Next := temp;
      AsmList.Rear := temp;
    end;
end;

procedure InsertAsmEntry(var a: pAsmRecord);

var dummy, temp    : pAsmRecord;

begin
  if AsmList.First = NIL then
    AddAsmEntry(a)
  else
    begin
      a^.prev := NIL;
      a^.next := AsmList.First;
      AsmList.First^.prev:=a;
      AsmList.First:=a;
    end;
end;

procedure DeleteAsmEntry(var a: pAsmRecord);
begin
  if (a^.Next = nil) then
    begin
      RemoveLastAsmEntry;
      a:=NIL;
    end
  else
    begin
      if (a = AsmList.First) then              {if we're deleting the first node}
        begin
          AsmList.First := AsmList.First^.Next;    {Start list from second node}
          AsmList.First^.Prev := NIL;        {Set new starts previous link}
          Dispose(a);                {Dispose of old first}
          a:=NIL;
        end
      else
        begin
          a^.prev^.next := a^.next;     {Move pointers...}
          a^.next^.prev := a^.prev;
          Dispose(a);          {Dispose of node}
          a:=NIL;
        end;
    end;
end;

procedure RemoveLastAsmEntry;

begin
  if (AsmList.First <>NIL) and (AsmList.Rear<>NIL) then
    if AsmList.First^.next = nil then
      begin
        Dispose(AsmList.First);
        AsmList.First := nil;
        AsmList.Rear := nil;
      end
    else
      begin
        AsmList.Rear := AsmList.Rear^.prev;
        Dispose(AsmList.Rear^.next);
        AsmList.Rear^.next:=Nil;
      end;
end;

procedure DestroyAsmList;
begin
  while AsmList.First <> nil do    {While still nodes left}
    RemoveLastAsmEntry;            {Remove last node}

  AsmList.first:=NIL;              {Reset values}
  AsmList.rear:=NIL;
end;

procedure AttachAsmList(list: tAsmList);
begin
  if AsmList.first<>NIL then
    begin
      AsmList.rear^.next:=List.first;
      List.first^.prev:=Asmlist.rear;
      Asmlist.rear:=List.rear;
    end
  else
    Asmlist:=List;
end;

procedure WriteOperand(var o:operand);
var s: string[21];
    p: integer;
begin
  case o.o of
  _reg: begin
          if o.size=1 then
            begin
              if o.reg=eax then o.reg:=al;
              if o.reg=edx then o.reg:=dl;
              if o.reg=ecx then o.reg:=cl;
              if o.reg=ebx then o.reg:=bl;
            end
          else
            if o.size=2 then
              begin
                if o.reg=eax then o.reg:=ax;
                if o.reg=edx then o.reg:=dx;
                if o.reg=ecx then o.reg:=cx;
                if o.reg=ebx then o.reg:=bx;
              end;
          write(dest^, r[o.reg]);
        end;
  _fpu: begin
          s:=asdef.fpstack;
          p:=pos('#', s);
          if p<>0 then
            begin
              delete(s, p, 1);
              insert(Numb(o.f), s, p);
            end;
          write(dest^, s);
        end;
  _mmx: begin
          s:='mm'+Numb(o.f);
          write(dest^, s);
        end;
  _mem,
  _ord,
  _lab: begin
          if (o.o=_mem) and (o.size=_offset) then
            write(dest^, asdef.offset + CreateName(o.loc))
          else
            begin
              case o.size of
              _nothing : ;
              _offset  : write(dest^, asdef.offset);
              _byte    : write(dest^, asdef.byteptr);
              _word    : write(dest^, asdef.wordptr);
              _dword   : write(dest^, asdef.dwordptr);
              _qword   : write(dest^, asdef.qwordptr);
              _tbyte   : write(dest^, asdef.tbyteptr);
              _near_   : write(dest^, asdef.jump_prefix+' ');
              end;
              case o.o of
              _mem : write(dest^, '['+CreateName(o.loc)+']');
              _ord : if Options.DecimalNumbers then write(dest^, Numb(o.n))
                                               else write(dest^, LongToHex(o.n));
              _lab : write(dest^, o.lab);
              end;
            end;
        end;
  end;
end;

procedure DumpAsmList;
var a: pAsmRecord;
begin
  a:=AsmList.first;
  while a<>NIL do
    begin
      case a^.a of
      _labels: WriteLn(dest^, a^.lab,':');
      _str   : WriteLn(dest^,'      ', a^.s);
      _opcode: begin
                 Write(dest^,'      ', opcodes[a^.op], TAB);
                 if a^.o1.o<>_non then
                   WriteOperand(a^.o1);
                 if a^.o2.o<>_non then
                   begin
                     Write(dest^,', ');
                     WriteOperand(a^.o2);
                   end;
                 if a^.o3.o<>_non then
                   begin
                     Write(dest^,', ');
                     WriteOperand(a^.o3);
                   end;
                 WriteLn(dest^);
               end;
      end;
      a:=a^.next;
    end;
end;

procedure emit_label(const lab:string);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _labels;
  a^.lab:=lab;
  AddAsmEntry(a);
end;

procedure emit_string(const s:string);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _str;
  a^.s:=s;
  AddAsmEntry(a);
end;

procedure iemit_label(const lab:string);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _labels;
  a^.lab:=lab;
  InsertAsmEntry(a);
end;

procedure iemit_string(const s:string);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _str;
  a^.s:=s;
  InsertAsmEntry(a);
end;

procedure emit_non(op: opcode_num);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_non;
  a^.o2.o:=_non;
  a^.o3.o:=_non;
  AddAsmEntry(a);
end;

procedure emit_reg(op: opcode_num; s: integer;  r: regs);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_reg;
  a^.o1.reg:= r;
  a^.o1.size:=s;
  a^.o2.o:=_non;
  a^.o3.o:=_non;
  AddAsmEntry(a);
end;

procedure emit_loc(op: opcode_num; s: integer;var loc: location);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_mem;
  a^.o1.loc:= loc;
  a^.o1.size:=s;
  a^.o2.o:=_non;
  a^.o3.o:=_non;
  AddAsmEntry(a);
end;

procedure emit_ord(op: opcode_num; s: integer; n:longint);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_ord;
  a^.o1.n:= n;
  a^.o1.size:=s;
  a^.o2.o:=_non;
  a^.o3.o:=_non;
  AddAsmEntry(a);
end;

procedure emit_lab(op: opcode_num; s: integer; const lab:string);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_lab;
  a^.o1.lab:=lab;
  a^.o1.size:=s;
  a^.o2.o:=_non;
  a^.o3.o:=_non;
  AddAsmEntry(a);
end;

procedure emit_fpu(op: opcode_num; f: integer);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_fpu;
  a^.o1.f:=f;
  a^.o2.o:=_non;
  a^.o3.o:=_non;
  AddAsmEntry(a);
end;

procedure emit_mmx(op: opcode_num; f: integer);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_mmx;
  a^.o1.f:=f;
  a^.o2.o:=_non;
  a^.o3.o:=_non;
  AddAsmEntry(a);
end;

procedure iemit_reg(op: opcode_num; s: integer;  r: regs);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_reg;
  a^.o1.reg:= r;
  a^.o1.size:=s;
  a^.o2.o:=_non;
  a^.o3.o:=_non;
  InsertAsmEntry(a);
end;

procedure iemit_lab(op: opcode_num; s: integer; const lab:string);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_lab;
  a^.o1.lab:=lab;
  a^.o1.size:=s;
  a^.o2.o:=_non;
  a^.o3.o:=_non;
  InsertAsmEntry(a);
end;


procedure emit_reg_reg(op: opcode_num; s1: integer; r1: regs; s2:integer; r2: regs);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_reg;
  a^.o1.reg:=r1;
  a^.o1.size:=s1;
  a^.o2.o:=_reg;
  a^.o2.reg:=r2;
  a^.o2.size:=s2;
  a^.o3.o:=_non;
  AddAsmEntry(a);
end;

procedure emit_reg_loc(op: opcode_num; s1: integer; r: regs; s2: integer;var loc:location);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_reg;
  a^.o1.reg:= r;
  a^.o1.size:=s1;
  a^.o2.o:=_mem;
  a^.o2.loc:= loc;
  a^.o2.size:=s2;
  a^.o3.o:=_non;
  AddAsmEntry(a);
end;

procedure emit_reg_lab(op: opcode_num; s1: integer; r: regs; s2: integer; const lab:string);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_reg;
  a^.o1.reg:= r;
  a^.o1.size:=s1;
  a^.o2.o:=_lab;
  a^.o2.lab:= lab;
  a^.o2.size:=s2;
  a^.o3.o:=_non;
  AddAsmEntry(a);
end;


procedure emit_reg_ord(op: opcode_num; s1: integer; r: regs; n:longint);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_reg;
  a^.o1.reg:= r;
  a^.o1.size:=s1;
  a^.o2.o:=_ord;
  a^.o2.n:=n;
  a^.o2.size:=0;
  a^.o3.o:=_non;
  AddAsmEntry(a);
end;

procedure iemit_reg_reg(op: opcode_num; s1: integer; r1: regs; s2:integer; r2: regs);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_reg;
  a^.o1.reg:=r1;
  a^.o1.size:=s1;
  a^.o2.o:=_reg;
  a^.o2.reg:=r2;
  a^.o2.size:=s2;
  a^.o3.o:=_non;
  InsertAsmEntry(a);
end;

procedure iemit_reg_ord(op: opcode_num; s1: integer; r: regs; n:longint);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_reg;
  a^.o1.reg:= r;
  a^.o1.size:=s1;
  a^.o2.o:=_ord;
  a^.o2.n:=n;
  a^.o2.size:=0;
  a^.o3.o:=_non;
  InsertAsmEntry(a);
end;

procedure emit_ord_reg(op: opcode_num; n:longint; s1: integer; r: regs);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_ord;
  a^.o1.n:= n;
  a^.o1.size:=s1;
  a^.o2.o:=_reg;
  a^.o2.reg:=r;
  a^.o3.o:=_non;
  AddAsmEntry(a);
end;


procedure emit_reg_reg_reg(op: opcode_num; s1: integer; r1: regs; s2:integer; r2: regs; s3:integer; r3: regs);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_reg;
  a^.o1.reg:=r1;
  a^.o1.size:=s1;
  a^.o2.o:=_reg;
  a^.o2.reg:=r2;
  a^.o2.size:=s2;
  a^.o3.o:=_reg;
  a^.o3.reg:=r3;
  a^.o3.size:=s3;
  AddAsmEntry(a);
end;

procedure emit_reg_reg_ord(op: opcode_num; s1: integer; r1: regs; s2: integer; r2: regs; n:longint);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_reg;
  a^.o1.reg:= r1;
  a^.o1.size:=s1;
  a^.o2.o:=_reg;
  a^.o2.reg:= r2;
  a^.o2.size:=s2;
  a^.o3.o:=_ord;
  a^.o3.n:=n;
  a^.o3.size:=0;
  AddAsmEntry(a);
end;



procedure emit_loc_reg(op: opcode_num; s1: integer;var loc:location;s2: integer; r: regs);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_mem;
  a^.o1.loc:= loc;
  a^.o1.size:=s1;
  a^.o2.o:=_reg;
  a^.o2.reg:= r;
  a^.o2.size:=s2;
  a^.o3.o:=_non;
  AddAsmEntry(a);
end;

procedure emit_loc_loc(op: opcode_num; s1: integer;var loc1: location; s2: integer;var loc2: location);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_mem;
  a^.o1.loc:= loc1;
  a^.o1.size:=s1;
  a^.o2.o:=_mem;
  a^.o2.loc:= loc2;
  a^.o2.size:=s2;
  a^.o3.o:=_non;
  AddAsmEntry(a);
end;

procedure emit_loc_ord(op: opcode_num; s: integer;var loc: location; n: longint);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_mem;
  a^.o1.loc:=loc;
  a^.o1.size:=s;
  a^.o2.o:=_ord;
  a^.o2.n:= n;
  a^.o3.o:=_non;
  AddAsmEntry(a);
end;

procedure emit_loc_mmx(op: opcode_num; s: integer;var loc: location; f: integer);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_mem;
  a^.o1.loc:=loc;
  a^.o1.size:=s;
  a^.o2.o:=_mmx;
  a^.o2.f:= f;
  a^.o2.size:=0;
  a^.o3.o:=_non;
  AddAsmEntry(a);
end;

procedure emit_fpu_fpu(op: opcode_num; f1, f2: integer);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_fpu;
  a^.o1.f:=f1;
  a^.o2.o:=_fpu;
  a^.o2.f:=f2;
  a^.o3.o:=_non;
  AddAsmEntry(a);
end;

procedure emit_mmx_reg(op: opcode_num; f1: integer; s2: integer; r: regs);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_mmx;
  a^.o1.f:=f1;
  a^.o2.o:=_reg;
  a^.o2.size:=s2;
  a^.o2.reg:= r;
  a^.o3.o:=_non;
  AddAsmEntry(a);
end;

procedure emit_mmx_mmx(op: opcode_num; f1, f2: integer);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_mmx;
  a^.o1.f:=f1;
  a^.o2.o:=_mmx;
  a^.o2.f:=f2;
  a^.o3.o:=_non;
  AddAsmEntry(a);
end;

procedure emit_mmx_loc(op: opcode_num; f: integer; s: integer; var loc: location);
var a: pAsmRecord;
begin
  a:=NewAsmEntry;
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_mmx;
  a^.o1.f:= f;
  a^.o1.size:=0;
  a^.o2.o:=_mem;
  a^.o2.loc:=loc;
  a^.o2.size:=s;
  a^.o3.o:=_non;
  AddAsmEntry(a);
end;

procedure InsertAsmAbove(var a,b : pAsmRecord);
var
   c : pAsmRecord;
begin
   c := a^.prev;
   b^.prev := c;
   b^.next := a;
   a^.prev := b;
   if ( c <> nil ) then c^.next := b;
   if ( a = AsmList.First ) then AsmList.First := b;
end;

procedure set_lab_non(var a : pAsmRecord; op: opcode_num; s: integer; const lab:string);
begin
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_lab;
  a^.o1.lab:=lab;
  a^.o1.size:=s;
  a^.o2.o:=_non;
  a^.o3.o:=_non;
end;

procedure set_label(var a : pAsmRecord; const lab:string);
begin
  a^.a:= _labels;
  a^.lab:=lab;
end;


procedure set_reg_non(var a: pAsmRecord; op: opcode_num; s: integer;  r: regs);
begin
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_reg;
  a^.o1.reg:= r;
  a^.o1.size:=s;
  a^.o2.o:=_non;
  a^.o3.o:=_non;
end;

procedure set_reg_ord(var a: pAsmRecord; op: opcode_num; s1: integer; r: regs; n:longint);
begin
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_reg;
  a^.o1.reg:= r;
  a^.o1.size:=s1;
  a^.o2.o:=_ord;
  a^.o2.n:=n;
  a^.o2.size:=0;
  a^.o3.o:=_non;
end;

procedure set_reg_reg(var a: pAsmRecord; op: opcode_num; s1: integer; r1: regs; s2:integer; r2: regs);
begin
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_reg;
  a^.o1.reg:=r1;
  a^.o1.size:=s1;
  a^.o2.o:=_reg;
  a^.o2.reg:=r2;
  a^.o2.size:=s2;
  a^.o3.o:=_non;
end;

procedure set_reg_loc(var a: pAsmRecord; op: opcode_num; s1: integer; r: regs; s2: integer; var loc:location);
begin
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_reg;
  a^.o1.reg:= r;
  a^.o1.size:=s1;
  a^.o2.o:=_mem;
  a^.o2.loc:= loc;
  a^.o2.size:=s2;
  a^.o3.o:=_non;
end;

procedure set_loc(var loc : location; i,b : regs; f: Byte; o : Longint);
begin
  loc.l      := memref;
  loc.prefix := none;
  loc.index  := i;
  loc.base   := b;
  loc.factor := f;
  loc.offset := o;
  loc.name   := '';
end;

procedure set_loc_reg(var a: pAsmRecord; op: opcode_num; s1: integer;var loc:location;s2: integer; r: regs);
begin
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_mem;
  a^.o1.loc:= loc;
  a^.o1.size:=s1;
  a^.o2.o:=_reg;
  a^.o2.reg:= r;
  a^.o2.size:=s2;
  a^.o3.o:=_non;
end;

procedure set_loc_ord(var a: pAsmRecord; op: opcode_num; s1: integer;var loc:location; n: integer);
begin
  a^.a:= _opcode;
  a^.op:= op;
  a^.o1.o:=_mem;
  a^.o1.loc:= loc;
  a^.o1.size:=s1;
  a^.o2.o:=_ord;
  a^.o2.n:= n;
  a^.o3.o:=_non;
end;



end.

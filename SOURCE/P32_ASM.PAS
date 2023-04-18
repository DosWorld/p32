{                         P32 - 32bit Pascal Compiler                       }
{ ------------------------------------------------------------------------- }
{                       Johan Prins - jprins@knoware.nl                     }
{ ========================================================================= }
{ Routines for the assembler                                                }
{                                                  (c) Copyright 1996-1999  }
{                                                                           }
{ ------------------------------------------------------------------------- }

unit P32_asm;

interface

uses P32_symb, P32_cfg, P32_prep, P32_scan, P32_err;

type
  assemblerdef = record
                   desc    :string[40];
                   header1,
                   header2,
                   model,
                   stackseg,
                   codeseg,
                   dataseg,
                   udataseg,
                   start,
                   ends,
                   proc,
                   endp,
                   macro,
                   endm,
                   align,
                   include,
                   inc_char,
                   byteptr,
                   wordptr,
                   dwordptr,
                   qwordptr,
                   tbyteptr,
                   jump_prefix,
                   offset,
                   decldata,
                   floatdata,
                   valdata1,
                   valdata2,
                   extern,
                   extern2,
                   global,
                   fpstack
                   : string[20];
                 end;
  asmop = (_unknown, _opcode, _reg, _prefix);

var asdef:assemblerdef;
    asmmode: boolean;

type
opcode_num =
{ The following instructions neither uses nor sets flags }
   (_none_, _lea_, _mov_, _movsx_, _movzx_, _nop_, _not_,

{ Pushes & Pops }
    _pop_, _popa_, _popad_, _popaw_, _popf_, _popfd_, _popfw_,
    _push_, _pusha_, _pushad_, _pushaw_, _pushf_, _pushfd_, _pushfw_,

{ The following instructions does not use flags, but sets them }
    _add_, _and_,  _clc_, _cld_, _cli_, _cmc_, _cmp_, _dec_, _div_,
    _idiv_, _imul_, _inc_, _mul_, _neg_, _or_, _rol_, _ror_, _sahf_,
    _sal_, _sar_, _shl_, _shld_, _shr_, _shrd_, _stc_, _std_, _sti_,
    _sub_, _test_, _xor_,

{ Then, these again, both use and set flags }
    _aaa_, _aad_, _aam_, _aas_, _adc_, _daa_, _das_, _rcl_, _rcr_,
    _sbb_,  { Dont like them aaa's  or daa's, never used them ... Unsure here }

{ At last, the ones that only use flags, but does not set them }
    _lahf_, _seta_, _setae_, _setb_, _setbe_, _setc_, _sete_, _setg_, _setge_, _setl_,
    _setle_, _setna_, _setnae_, _setnb_, _setnbe_, _setnc_, _setne_, _setng_, _setnge_,
    _setnl_, _setnle_, _setno_, _setnp_, _setns_, _setnz_, _seto_, _setp_, _setpe_,
    _setpo_, _sets_, _setz_, _cmova_, _cmovae_, _cmovb_, _cmovbe_, _cmovc_, _cmove_,
    _cmovg_, _cmovge_, _cmovl_, _cmovle_, _cmovna_, _cmovnae_, _cmovnb_, _cmovnbe_,
    _cmovnc_, _cmovne_, _cmovng_, _cmovnge_, _cmovnl_, _cmovnle_, _cmovno_, _cmovnp_,
    _cmovns_, _cmovnz_, _cmovo_, _cmovp_, _cmovpe_, _cmovpo_, _cmovs_, _cmovz_,

{ Now, the jumps, first the conditional, the ones that use flags }
    _ja_, _jae_, _jb_, _jbe_, _jc_, _je_, _jg_, _jge_, _jl_, _jle_, _jna_, _jnae_,
    _jnb_, _jnbe_, _jnc_, _jne_, _jng_, _jnge_, _jnl_, _jnle_, _jno_, _jnp_,
    _jns_, _jnz_, _jo_, _jp_, _jpe_, _jpo_, _js_, _jz_,

{ Then the jumps that do not use flags }
    _call_, _int_, _int01_, _int1_, _int3_, _into_, _iret_, _iretd_, _iretw_,
    _jcxz_, _jecxz_, _jmp_, _loop_, _loope_, _loopne_, _loopnz_, _loopz_,
    _rep_, _repne_, _repe_, _ret_, _retf_, _retn_,

{ String Opcodes }
    _cmpsb_, _cmpsd_, _cmpsw_, _insb_, _insd_, _insw_, _lodsb_, _lodsd_, _lodsw_,
    _movsb_, _movsd_, _movsw_, _outsb_, _outsd_, _outsw_, _scasb_, _scasd_,
    _scasw_, _stosb_, _stosd_, _stosw_,

{ Rarely used & Special opcodes (For gaining some speed ..  (And not optimize ;) }
    _align_, _arpl_, _bound_, _bsf_, _bsr_, _bswap_, _bt_, _btc_, _btr_, _bts_,
    _cbw_, _clts_, _cdq_, _cmpxchg_, _cmpxchg486_, _cmpxchg8b_, _cpuid_, _cwd_,
    _cwde_, _db_, _dd_, _dq_, _dt_, _dw_, _enter_, _equ_, _hlt_, _ibts_, _icebp_,
    _in_, _incbin_, _invd_, _invlpg_, _lar_, _lds_, _leave_, _les_, _lfs_, _lgdt_, _lgs_,
    _lidt_, _lldt_, _lmsw_, _loadall_, _loadall286_, _lsl_, _lss_, _ltr_, _out_, _rdmsr_,
    _rdpmc_, _rdtsc_, _resb_, _resd_, _resq_, _rest_, _resw_, _rsm_, _salc_, _sgdt_,
    _sidt_, _sldt_, _smi_, _smsw_, _str_, _umov_, _verr_, _verw_, _wait_, _wbinvd_,
    _wrmsr_, _xadd_, _xbts_, _xchg_, _xlatb_,

{ FPU Opcodes }
    _f2xm1_, _fabs_, _fadd_, _faddp_, _fbld_, _fbstp_, _fchs_, _fclex_,
    _fcmovb_, _fcmovbe_, _fcmove_, _fcmovnb_, _fcmovnbe_, _fcmovne_, _fcmovnu_,
    _fcmovu_, _fcom_, _fcomi_, _fcomip_, _fcomp_,_fcompp_, _fcos_, _fdecstp_,
    _fdisi_, _fdiv_, _fdivp_, _fdivr_,_fdivrp_, _feni_, _ffree_, _fiadd_, _ficom_, 
    _ficomp_, _fidiv_, _fidivr_, _fild_, _fimul_, _fincstp_, _finit_, _fist_, 
    _fistp_, _fisub_, _fisubr_, _fld_, _fld1_, _fldcw_, _fldenv_, _fldl2e_,
    _fldl2t_, _fldlg2_, _fldln2_, _fldpi_, _fldz_, _fmul_, _fmulp_,
    _fnclex_, _fndisi_, _fneni_, _fninit_, _fnop_, _fnsave_,
    _fnstcw_, _fnstenv_, _fnstsw_, _fpatan_, _fprem_, _fprem1_,
    _fptan_, _frndint_, _frstor_, _fsave_, _fscale_, _fsetpm_,
    _fsin_, _fsincos_, _fsqrt_, _fst_, _fstcw_, _fstenv_, _fstp_,
    _fstsw_, _fsub_, _fsubp_, _fsubr_, _fsubrp_, _ftst_, _fucom_,
    _fucomi_, _fucomip_, _fucomp_, _fucompp_, _fxam_, _fxch_,
    _fxtract_, _fyl2x_, _fyl2xp1_,

{ MMX Opcodes }
    _emms_, _femms_, _movd_, _movq_, _packssdw_, _packsswb_, _packuswb_,
    _paddb_, _paddd_, _paddsb_, _paddsiw_, _paddsw_, _paddusb_,
    _paddusw_, _paddw_, _pand_, _pandn_, _paveb_, _pavgusb_, _pcmpeqb_,
    _pcmpeqd_, _pcmpeqw_, _pcmpgtb_, _pcmpgtd_, _pcmpgtw_,
    _pdistib_, _pf2id_, _pfacc_, _pfadd_, _pfcmpeq_, _pfcmpge_, _pfcmpgt_,
    _pfmax_, _pfmin_, _pfmul_, _pfrcp_, _pfrcpit1_, _pfrcpit2_,
    _pfrsqit1_, _pfrsqrt_, _pfsub_, _pfsubr_, _pi2fd_,
    _pmachriw_, _pmaddwd_, _pmagw_, _pmulhriw_, _pmulhrwa_, _pmulhrwc_,
    _pmulhw_, _pmullw_, _pmvgezb_, _pmvlzb_, _pmvnzb_,
    _pmvzb_, _por_, _prefetch_, _prefetchw_, _pslld_, _psllq_, _psllw_,
    _psrad_, _psraw_, _psrld_, _psrlq_, _psrlw_, _psubb_, _psubd_, _psubsb_,
    _psubsiw_, _psubsw_, _psubusb_, _psubusw_, _psubw_, _punpckhbw_,
    _punpckhdq_, _punpckhwd_, _punpcklbw_, _punpckldq_, _punpcklwd_, _pxor_);

    loc_type = (undef, register, memref, ordconst, fpu, port, directmem, lab, mmx);

    location = record
                 prefix       : regs;
                 case l:loc_type of
                 undef        : ( );
                 register     : ( reg         : regs);
                 port,
                 directmem,
                 memref       : ( base, index : regs;
                                  factor      : byte;
                                  offset      : longint;

                                  name        : {pstring}
                                                string[79]);
                 ordconst     : ( value       : longint);
                 mmx,
                 fpu          : ( nr          : byte);
                 lab          : ( lname       : string[79]);
               end;

const
opcodes: array[opcode_num] of string[15]=
{ The following instructions neither uses nor sets flags }
   ('', 'lea', 'mov', 'movsx', 'movzx', 'nop', 'not',

{ Pushes & Pops }
    'pop', 'popa', 'popad', 'popaw', 'popf', 'popfd', 'popfw',
    'push', 'pusha', 'pushad', 'pushaw', 'pushf', 'pushfd', 'pushfw',

{ The following instructions does not use flags, but sets them }
    'add', 'and',  'clc', 'cld', 'cli', 'cmc', 'cmp', 'dec', 'div',
    'idiv', 'imul', 'inc', 'mul', 'neg', 'or', 'rol', 'ror', 'sahf',
    'sal', 'sar', 'shl', 'shld', 'shr', 'shrd', 'stc', 'std', 'sti',
    'sub', 'test', 'xor',

{ Then, these again, both use and set flags }
    'aaa', 'aad', 'aam', 'aas', 'adc', 'daa', 'das', 'rcl', 'rcr',
    'sbb',  { Dont like them aaa's  or daa's, never used them ... Unsure here }

{ At last, the ones that only use flags, but does not set them }
    'lahf', 'seta', 'setae', 'setb', 'setbe', 'setc', 'sete', 'setg', 'setge', 'setl',
    'setle', 'setna', 'setnae', 'setnb', 'setnbe', 'setnc', 'setne', 'setng', 'setnge',
    'setnl', 'setnle', 'setno', 'setnp', 'setns', 'setnz', 'seto', 'setp', 'setpe',
    'setpo', 'sets', 'setz', 'cmova', 'cmovae', 'cmovb', 'cmovbe', 'cmovc', 'cmove',
    'cmovg', 'cmovge', 'cmovl', 'cmovle', 'cmovna', 'cmovnae', 'cmovnb', 'cmovnbe',
    'cmovnc', 'cmovne', 'cmovng', 'cmovnge', 'cmovnl', 'cmovnle', 'cmovno', 'cmovnp',
    'cmovns', 'cmovnz', 'cmovo', 'cmovp', 'cmovpe', 'cmovpo', 'cmovs', 'cmovz',

{ Now, the jumps, first the conditional, the ones that use flags }
    'ja', 'jae', 'jb', 'jbe', 'jc', 'je', 'jg', 'jge', 'jl', 'jle', 'jna', 'jnae',
    'jnb', 'jnbe', 'jnc', 'jne', 'jng', 'jnge', 'jnl', 'jnle', 'jno', 'jnp',
    'jns', 'jnz', 'jo', 'jp', 'jpe', 'jpo', 'js', 'jz',

{ Then the jumps that do not use flags }
    'call', 'int', 'int01', 'int1', 'int3', 'into', 'iret', 'iretd', 'iretw',
    'jcxz', 'jecxz', 'jmp', 'loop', 'loope', 'loopne', 'loopnz', 'loopz',
    'rep', 'repne', 'repe', 'ret', 'retf', 'retn',

{ String Opcodes }
    'cmpsb', 'cmpsd', 'cmpsw', 'insb', 'insd', 'insw', 'lodsb', 'lodsd', 'lodsw',
    'movsb', 'movsd', 'movsw', 'outsb', 'outsd', 'outsw', 'scasb', 'scasd',
    'scasw', 'stosb', 'stosd', 'stosw',

{ Rarely used & Special opcodes (For gaining some speed ..  (And not optimize ;) }
    'align', 'arpl', 'bound', 'bsf', 'bsr', 'bswap', 'bt', 'btc', 'btr', 'bts',
    'cbw', 'clts', 'cdq', 'cmpxchg', 'cmpxchg486', 'cmpxchg8b', 'cpuid', 'cwd',
    'cwde', 'db', 'dd', 'dq', 'dt', 'dw', 'enter', 'equ', 'hlt', 'ibts', 'icebp',
    'in', 'incbin', 'invd', 'invlpg', 'lar', 'lds', 'leave', 'les', 'lfs', 'lgdt', 'lgs',
    'lidt', 'lldt', 'lmsw', 'loadall', 'loadall286', 'lsl', 'lss', 'ltr', 'out', 'rdmsr',
    'rdpmc', 'rdtsc', 'resb', 'resd', 'resq', 'rest', 'resw', 'rsm', 'salc', 'sgdt',
    'sidt', 'sldt', 'smi', 'smsw', 'str', 'umov', 'verr', 'verw', 'wait', 'wbinvd',
    'wrmsr', 'xadd', 'xbts', 'xchg', 'xlatb',

{ FPU Opcodes }
    'f2xm1', 'fabs', 'fadd', 'faddp', 'fbld', 'fbstp', 'fchs', 'fclex',
    'fcmovb', 'fcmovbe', 'fcmove', 'fcmovnb', 'fcmovnbe', 'fcmovne', 'fcmovnu',
    'fcmovu', 'fcom', 'fcomi', 'fcomip', 'fcomp','fcompp', 'fcos', 'fdecstp',
    'fdisi', 'fdiv', 'fdivp', 'fdivr','fdivrp', 'feni', 'ffree', 'fiadd', 'ficom',
    'ficomp', 'fidiv', 'fidivr', 'fild', 'fimul', 'fincstp', 'finit', 'fist',
    'fistp', 'fisub', 'fisubr', 'fld', 'fld1', 'fldcw', 'fldenv', 'fldl2e',
    'fldl2t', 'fldlg2', 'fldln2', 'fldpi', 'fldz', 'fmul', 'fmulp',
    'fnclex', 'fndisi', 'fneni', 'fninit', 'fnop', 'fnsave',
    'fnstcw', 'fnstenv', 'fnstsw', 'fpatan', 'fprem', 'fprem1',
    'fptan', 'frndint', 'frstor', 'fsave', 'fscale', 'fsetpm',
    'fsin', 'fsincos', 'fsqrt', 'fst', 'fstcw', 'fstenv', 'fstp',
    'fstsw', 'fsub', 'fsubp', 'fsubr', 'fsubrp', 'ftst', 'fucom',
    'fucomi', 'fucomip', 'fucomp', 'fucompp', 'fxam', 'fxch',
    'fxtract', 'fyl2x', 'fyl2xp1',

{ MMX Opcodes }
    'emms', 'femms', 'movd', 'movq', 'packssdw', 'packsswb', 'packuswb',
    'paddb', 'paddd', 'paddsb', 'paddsiw', 'paddsw', 'paddusb',
    'paddusw', 'paddw', 'pand', 'pandn', 'paveb', 'pavgusb', 'pcmpeqb',
    'pcmpeqd', 'pcmpeqw', 'pcmpgtb', 'pcmpgtd', 'pcmpgtw',
    'pdistib', 'pf2id', 'pfacc', 'pfadd', 'pfcmpeq', 'pfcmpge', 'pfcmpgt',
    'pfmax', 'pfmin', 'pfmul', 'pfrcp', 'pfrcpit1', 'pfrcpit2',
    'pfrsqit1', 'pfrsqrt', 'pfsub', 'pfsubr', 'pi2fd',
    'pmachriw', 'pmaddwd', 'pmagw', 'pmulhriw', 'pmulhrwa', 'pmulhrwc',
    'pmulhw', 'pmullw', 'pmvgezb', 'pmvlzb', 'pmvnzb',
    'pmvzb', 'por', 'prefetch', 'prefetchw', 'pslld', 'psllq', 'psllw',
    'psrad', 'psraw', 'psrld', 'psrlq', 'psrlw', 'psubb', 'psubd', 'psubsb',
    'psubsiw', 'psubsw', 'psubusb', 'psubusw', 'psubw', 'punpckhbw',
    'punpckhdq', 'punpckhwd', 'punpcklbw', 'punpckldq', 'punpcklwd', 'pxor');


  r: array[regs] of string[3]=
    ('', 'ah', 'al', 'ax', 'bh', 'bl', 'bp', 'bx', 'ch', 'cl',
     'cs', 'cx', 'dh', 'di', 'dl', 'ds', 'dx',
     'eax', 'edx', 'ecx', 'ebx', 'esi', 'edi',
     'esp', 'ebp',  'es', 'fs', 'gs', 'si', 'sp',
     'ss');

prefix: array[0..17] of string[6]=
    ('', 'byte', 'dword', 'far', 'long', 'near', 'qword', 'short',
     'tbyte', 'word','ptr','offset','st', 'db','dw','dd','dq','dt');

procedure ReadDefinition(s:string);
function IsOpcode(s:string):opcode_num;
function IsReg(s:string):regs;
function IsPrefix(s:string):integer;
procedure ReadAsmBlock;

implementation

uses P32_code, P32_asml, P32_opt, P32_tree;

function simple_expression:pTree; forward;

procedure ReadDefinition(s:string);

var def:file;

begin
  if FileExists(s) then
    begin
      assign(def, s);
      reset(def,1);
      blockread(def, asdef, sizeof(asdef));
      close(def);
    end
  else
    Error('Assembler definition file ('+s+') not found');
end;


function IsOpcode(s:string):opcode_num;

var i:opcode_num;
label stop;
begin
  IsOpCode:=_none_;
  i:=low(opcode_num);
  s:=ToLower(s);
  if s[0]>#1 then
    repeat
      if s = opcodes[i] then
        begin
         IsOpCode:=i{TRUE};
         exit
        end;
      inc(i);
    until (i=high(opcode_num));
end;

function IsReg(s:string):regs;

var i: regs;

begin
  IsReg:=none;
  i:=low(regs);
  s:=ToLower(s);
  repeat
    if s = r[i] then
      begin
        IsReg:=i;
        exit;
      end;
    inc(i);
  until (i=high(regs));
end;

function IsPrefix(s:string):integer;

var i: integer;

begin
  IsPrefix:=0;
  i:=1;
  s:=ToLower(s);
  repeat
    if s = prefix[i] then
      begin
        IsPrefix:=i;
        exit;
      end;
    inc(i);
  until (i=17);
end;

function CheckRegSize(i: regs): integer;
begin
  CheckRegSize:=_nothing;
  case i of
  ah, al, bh, bl, ch, cl, dh, dl : CheckRegSize:=_byte;
  ax, bp, bx, cs, cx, di, ds, dx, es, fs, gs, si, sp, ss : CheckRegSize:=_word;
  eax, edx, ecx, ebx, esi, edi, esp, ebp : CheckRegSize:=_dword;
  end;
end;

function StringToNumber(s: string): longint;
var x: longint;
begin
  x:=0;
  if length(s)=4 then
    asm
       mov al, byte ptr [s+4]
       mov byte ptr [x], al
       mov al, byte ptr [s+3]
       mov byte ptr [x+1], al
       mov al, byte ptr [s+2]
       mov byte ptr [x+2], al
       mov al, byte ptr [s+1]
       mov byte ptr [x+3], al
    end
  else
  if length(s)=2 then
    asm
       mov al, byte ptr [s+2]
       mov byte ptr [x], al
       mov al, byte ptr [s+1]
       mov byte ptr [x+1], al
    end;
  StringToNumber:=x;
end;

function CheckPtrSize(s: string): integer;
begin
  CheckPtrSize:=0;
  s:=ToUpper(s);
  if s= 'BYTE' then CheckPtrSize:=_byte
  else
    if s= 'WORD' then CheckPtrSize:=_word
    else
      if s= 'DWORD' then CheckPtrSize:=_dword
      else
        if s= 'QWORD' then CheckPtrSize:=_qword
        else
          if s= 'TBYTE' then CheckPtrSize:=_tbyte
          else
            if s= 'OFFSET' then CheckPtrSize:=_offset
            else
              if s= 'NEAR' then CheckPtrSize:=_near_;
end;

function GetLabel: string;
var s:string;
begin
  s:=current_string;
  while Look in ['@','_', '0'..'9','A'..'Z','a'..'z' ] do
   begin
     s := s + look;
     GetChar;
   end;
  GetToken;
  GetLabel:=ProcName+s;
end;


procedure LocVar(var l:location; p: pTree);
begin
  if p^.loc.l = memref then
    begin
      l.name:=p^.loc.name;
      l.base:=p^.loc.base;
      l.index:=p^.loc.index;
      inc(l.offset, p^.loc.offset);
    end
  else
    if p^.loc.l = register then
      begin
        l.l:=memref;
        {ClearLoc(l);}
        l.base:=p^.loc.reg;
      end
end;

procedure LocOffset(var l:location; n: longint);
begin
  inc(l.offset, n)
end;

procedure LocFactor(var l:location; n: longint);
begin
  l.factor:=n;
end;

procedure ProcessMul(var l:location; var p: pTree);
begin
  GenerateCode(p^.left);
  GenerateCode(p^.right);
  if (p^.left^.op=__var) and
     (p^.left^.loc.l=register) and
     (p^.right^.op=__ordconst) then
    begin
      LocFactor(l, p^.right^.n);
      DestroyTree(p^.right);
      p:=p^.left;
    end
  else
    if (p^.right^.op=__var) and
       (p^.right^.loc.l=register) and
       (p^.left^.op=__ordconst) then
      begin
        LocFactor(l, p^.left^.n);
        DestroyTree(p^.left);
        p:=p^.right;
      end
    else
      LineError(p^.line, 'Only muliply by constant allowed');
end;

procedure ProcessAdd(var l:location; var p: pTree);
var idx: (left, right, middle);

begin
  idx:=middle;
  if (p^.op=__add) or (p^.op=__sub) then { dword ptr [test + 10] }
    begin
      if p^.left^.op=__mul then begin
                                  ProcessMul(l, p^.left);
                                  idx:=left;
                                end
                           else GenerateCode(p^.left);
      if p^.right^.op=__mul then begin
                                   ProcessMul(l, p^.right);
                                   idx:=right;
                                end
                            else GenerateCode(p^.right);
      if (p^.left^.loc.l=memref) or (p^.left^.loc.l=register) then
        begin
          LocVar(l, p^.left);
          if idx=left then l.index:=l.base;
          if p^.right^.loc.l=ordconst then
            begin
              if p^.op=__add then LocOffset(l, p^.right^.loc.value)
                             else LocOffset(l, -p^.right^.loc.value)
            end
          else
            if (p^.right^.loc.l=register) then
              begin
                if idx=left then l.base:=p^.right^.loc.reg
                            else l.index:=p^.right^.loc.reg
              end
        end
      else
        if (p^.right^.loc.l=memref) or (p^.right^.loc.l=register) then
          begin
            if p^.right^.op=__mul then ProcessMul(l, p^.right)
                                  else GenerateCode(p^.right);
            if p^.left^.op=__mul then ProcessMul(l, p^.left)
                                 else GenerateCode(p^.left);
            if p^.right^.loc.l=memref then
              begin
                LocVar(l, p^.right);
                if p^.left^.loc.l=ordconst then
                  begin
                    if p^.op=__add then LocOffset(l, p^.left^.n)
                                   else LocOffset(l, -p^.left^.n)
                  end
                else
                  if (p^.right^.loc.l=register) then
                    l.index:=p^.right^.loc.reg;
              end;
          end
        else
          LineError(LineCount, 'Error in expression');
    end;
end;

procedure CheckExpression(var l: location; var size: integer);
var p: pTree;
    i: integer;
    r: regs;
    x: longint;
    c: char;
begin
  if current_token=_lbracket then
    begin
      size:=0;
    end
  else
    begin
      size:=CheckPtrSize(current_string);
      if size<>0 then GetToken;
      if ToUpper(current_string)='PTR' then GetToken; {just ignore it}
    end;

   r:=IsReg(current_string);
   if r in [cs, ds, es, fs, gs, ss] then
     begin
       Match(current_token);
       Match(_colon);
     end
   else
     r:=none;
  if current_token=_at then
    begin
      l.l:=lab;
      l.lname:=ToUpper(GetLabel);
    end
  else
  if current_token=_lbracket then
    begin
      Match(_lbracket);
      p:=simple_expression;
      InitRegisters; {needed for the call to generatecode}
      OptimizeTree(p);
      if (p^.op=__var) or (p^.op=__field) then
        begin
          l.l:=memref;
          ClearLoc(l);
          GenerateCode(p);
          LocVar(l, p);
        end
      else
      if p^.op=__ordconst then
        begin
          l.l:=memref;
          ClearLoc(l);
          l.offset:=p^.n;
        end
      else
        if (p^.op=__add) or (p^.op=__sub) then
          begin
            if (p^.left^.op=__add) or (p^.left^.op=__sub) then
              begin
                l.l:=memref;
                ClearLoc(l);
                ProcessAdd(l, p^.left);
                GenerateCode(p^.right);
                case p^.right^.loc.l of
                register : l.index:=p^.right^.loc.reg;
                memref   : LocVar(l, p^.right);
                ordconst : if p^.op=__add then LocOffset(l, p^.right^.loc.value)
                                          else LocOffset(l, -p^.right^.loc.value)
                else       LineError(p^.line, 'error! assembly parser');
                end
              end
            else

              begin
                l.l:=memref;
                ClearLoc(l);
                ProcessAdd(l, p);
              end;
          end
        else
          LineError(p^.line, 'Error in expression');
      DestroyTree(p);
      Match(_rbracket);
    end
  else
    begin
      p:=simple_expression;
      InitRegisters; {needed for the call to generatecode}
      OptimizeTree(p);
      if p^.op=__ordconst then
        begin
          l.l:=ordconst;
          l.value:=p^.n;
        end
      else
      if p^.op=__charconst then
        begin
          l.l:=ordconst;
          l.value:=ord(p^.c);
        end
      else
      if p^.op=__stringconst then
        begin
          l.l:=ordconst;
          if (p^.s<>NIL) and (length(p^.s^) in [2, 4]) then
            begin
              l.value:=StringToNumber(p^.s^);
            end;
        end
      else
      if p^.loc.l=memref then
        begin
          l.l:=lab; {forces not to use brackets}
          ClearLoc(l);
          GenerateCode(p);
          l.lname:=p^.loc.name;
        end
      else
      if p^.loc.l=mmx then
        begin
          l.l :=mmx;
          l.nr:=p^.sym^.n;
        end
      else
    end;
  l.prefix:=r;
end;

function CheckFPU(var s: string): integer;

const fpureg: array[1..16] of string[3]=
   ('st0', 'st1', 'st2', 'st3', 'st4', 'st5', 'st6', 'st7',
    'mm0', 'mm1', 'mm2', 'mm3', 'mm4', 'mm5', 'mm6', 'mm7');
var i: integer;
begin
  CheckFPU:=0;
  i:=1;
  s:=ToLower(s);
  repeat
    if s = fpureg[i] then
      begin
        CheckFPU:=i;
        exit;
      end;
    inc(i);
  until (i=17);
end;

procedure ParseOperand(o: opcode_num; var size:integer; var l: location);
var r: regs;
    f: integer;
begin
  size:=_nothing;
  r:=IsReg(current_string);
  if r <> none then {it's a register}
    begin
      r:=IsReg(current_string);
      Match(current_token);
      l.l:=register;
      l.reg:=r;
    end
  else
    if current_token=_at then
      begin
        l.l:=lab;
        l.lname:=ToUpper(GetLabel);
      end
    else
      begin
      f:=CheckFPU(current_string);
      if f<>0 then
        begin
          GetToken;
          if f>8 then
            begin
              l.l:=mmx;
              l.nr:=f-9;
            end
          else
            begin
              l.l:=fpu;
              l.nr:=f-1;
            end;
        end
      else
        if (ToUpper(current_string)='ST') and (Opcodes[o][1]='f') then {it's a FPU register}
          begin
            GetToken;
            f:=0;
            if current_token=_lparen then
              begin
                Match(_lparen);
                f:=GetNumber;
                Match(_rparen);
              end;
            l.l:=fpu;
            l.nr:=f;
          end
        else
          CheckExpression(l, size);
      end
end;


procedure ReadAsmBlock;

var s: string;
    o, o1: opcode_num;
    r1, r2, r3: regs;
    loc1, loc2, loc3: location;
    f1, f2, size1, size2, size3: integer;
    t: pTree;
    sym:pSymbolRecord;
    l: longint;
    err: boolean;

begin
  asmmode:=TRUE;
  err:=FALSE;
  while current_token<>_end do
  begin
    ClearLoc(loc1);
    ClearLoc(loc2);
    ClearLoc(loc3);
    if current_token=_at then {label found}
      begin
        s:=ToUpper(GetLabel);
        Match(_colon);
        emit_label(s); {add the label to asm-list}
      end;

    o:=IsOpcode(current_string);
    if o <> _none_ then
      begin
        Match(current_token); {eat the opcode, first!}
        SkipSpace;
        if (current_string<>#13) then
          begin
            if current_token=_end then
              begin
                emit_non(o);
                continue;
              end
            else
            if current_token=_separator then
              begin
                emit_non(o);
                Match(_separator);
                continue;
              end;
            {rep, repne, repe, sUpEr special case... }
            if o in [_rep_, _repne_, _repe_] then
              begin
                o1:=IsOpcode(current_string);
                if o1 in [_cmpsb_, _cmpsd_, _cmpsw_, _insb_, _insd_, _insw_, _lodsb_, _lodsd_, _lodsw_,
                          _movsb_, _movsd_, _movsw_, _outsb_, _outsd_, _outsw_, _scasb_, _scasd_,
                          _scasw_, _stosb_, _stosd_, _stosw_] then
                  begin
                    Match(current_token);
                    emit_non(o);
                    emit_non(o1);
                  end
                else
                  ParseOperand(o, size1, loc1)
              end
            else
              ParseOperand(o, size1, loc1)
          end
        else
          begin
            emit_non(o);
            Match(current_token);
            continue;
          end;
        if current_token=_comma then
          begin
            Match(_comma);
            ParseOperand(o, size2, loc2);
            if current_token=_comma then
              begin
                Match(_comma);
                ParseOperand(o, size3, loc3);
                case loc1.l of
                register : case loc2.l of
                           register : case loc3.l of
                                      register : emit_reg_reg_reg(o, CheckRegSize(loc1.reg), loc1.reg, CheckRegSize(loc2.reg),
                                                                  loc2.reg, CheckRegSize(loc3.reg), loc3.reg);
                                      ordconst : emit_reg_reg_ord(o, CheckRegSize(loc1.reg), loc1.reg, CheckRegSize(loc2.reg),
                                                                  loc2.reg, loc3.value);
                                      memref   : err:=TRUE; {impossible}
                                      fpu      : err:=TRUE; {impossible}
                                      mmx      : err:=TRUE; {impossible}
                                      lab      : err:=TRUE; {impossible}
                                      end;
                           ordconst : err:=TRUE; {impossible}
                           memref   : err:=TRUE; {not implemented}
                           fpu      : err:=TRUE; {impossible}
                           mmx      : err:=TRUE; {impossible}
                           lab      : err:=TRUE; {impossible}
                           end;
                ordconst : err:=TRUE; {impossible}
                memref   : case loc3.l of
                           register : err:=TRUE; {not implemented}
                           ordconst : err:=TRUE; {not implemented}
                           memref   : err:=TRUE; {impossible}
                           fpu      : err:=TRUE; {impossible}
                           mmx      : err:=TRUE; {impossible}
                           lab      : err:=TRUE; {impossible}
                           end;
                fpu      : err:=TRUE; {impossible}
                mmx      : err:=TRUE; {impossible}
                lab      : err:=TRUE; {impossible}
                end;
              end
            else
            case loc1.l of
            register : case loc2.l of
                       register : emit_reg_reg(o, CheckRegSize(loc1.reg), loc1.reg, CheckRegSize(loc2.reg), loc2.reg);
                       ordconst : emit_reg_ord(o, CheckRegSize(loc1.reg), loc1.reg, loc2.value);
                       memref   : emit_reg_loc(o, CheckRegSize(loc1.reg), loc1.reg, size2, loc2);
                       fpu      : err:=TRUE; {impossible}
                       mmx      : err:=TRUE; {impossible}
                       lab      : emit_reg_lab(o, CheckRegSize(loc1.reg), loc1.reg, size2, loc2.lname);
                       end;
            ordconst : case loc2.l of
                       register : emit_ord_reg(o, loc1.value, CheckRegSize(loc2.reg), loc2.reg);
                       ordconst : err:=TRUE; {impossible}
                       memref   : err:=TRUE; {impossible}
                       fpu      : err:=TRUE; {impossible}
                       mmx      : err:=TRUE; {impossible}
                       lab      : err:=TRUE; {impossible}
                       end;
            memref   : case loc2.l of
                       register : emit_loc_reg(o, size1, loc1, CheckRegSize(loc2.reg), loc2.reg);
                       ordconst : emit_loc_ord(o, size1, loc1, loc2.value);
                       memref   : err:=TRUE; {impossible}
                       fpu      : err:=TRUE; {impossible}
                       mmx      : emit_loc_mmx(o, size1, loc1, loc2.nr);
                       lab      : err:=TRUE;
                       end;
            fpu      : case loc2.l of
                       register : err:=TRUE;
                       ordconst : err:=TRUE;
                       memref   : err:=TRUE;
                       fpu      : emit_fpu_fpu(o, loc1.nr, loc2.nr);
                       mmx      : err:=TRUE;
                       lab      : err:=TRUE;
                       end;
            mmx      : case loc2.l of
                       register : emit_mmx_reg(o, loc1.nr, _dword, loc2.reg);
                       ordconst : err:=TRUE;
                       memref   : emit_mmx_loc(o, loc1.nr, size2, loc2);
                       mmx      : emit_mmx_mmx(o, loc1.nr, loc2.nr);
                       fpu      : err:=TRUE;
                       lab      : err:=TRUE;
                       end;
            lab      : err:=TRUE;
            end;
          end
        else
          case loc1.l of
          register : emit_reg(o, CheckRegSize(loc1.reg), loc1.reg);
          ordconst : emit_ord(o, size1, loc1.value);
          memref   : emit_loc(o, size1, loc1);
          fpu      : emit_fpu(o, loc1.nr);
          mmx      : emit_mmx(o, loc1.nr);
          lab      : emit_lab(o, size1, loc1.lname);
          end;
      end;

    if err then
      LineError(LineCount, 'Syntax error');
    if current_token=_separator then Match(_separator);

    if current_string=#13 then
      GetToken
    else
      if current_string=#10 then
        GetToken
      else
        if (current_token<>_end) and (IsOpcode(current_string)=_none_) then
          LineError(LineCount, 'Unknown identifier');
  end;
  asmmode:=FALSE;
end;



{ ------------------------------------------------------------------------- }
{ These routines are copied from P32.PAS. They are modified for use in the  }
{ inline assembly parser.                                                   }
{ ------------------------------------------------------------------------- }

function factor: pTree;

var p1,p2            : pTree;
    typ              : pTypeRecord;
    sym_field, sym   : pSymbolRecord;
    fieldname, name  : string;
    setconst         : pset;  {defined in P32_tree}
    i, s1, s2        : byte;

    r                : regs;


    procedure DoQualifiers;
    { This nested procedure analyses a qualifier following an identifier,
      like: '[',']', '^', '.' (array, pointer, record)}
    begin
      case current_token of
      _period     : begin { . }
                      Match(_period);
                      case typ^.typedef of
                      _RecordDef : begin
                                     fieldname:=GetName;
                                     {sym:=GetPointer(GlobalTable, '_' + name); {get symbol entry}
                                     if sym^.typedef=nil then Error('Record doesn''t have fields')
                                     else begin
                                            sym_field:=GetSymbolFromList(typ^.RecordTable, fieldname);{Table of vars in record}
                                            if sym_field=NIL then LineError(LineCount,'Field expected'); {no entries}
                                            p1:=GenFieldNode(sym, sym_field, p1);
                                          end;
                                     typ:=sym_field^.typedef;
                                   end;
                      else         LineError(LineCount,'Invalid qualifier');
                      end
                    end;
      else Exit;
      end;
      DoQualifiers;
    end; { end of procedure DoQualifiers}

begin
  case current_token of
   _name             : begin {identifier}
                        name := current_string;{GetName;}
                        sym := GetSymbol(GetName);
                        {still not found, check for a register name}
                        r:=IsReg(name);
                        if r<>none then
                          begin
                            new(sym);
                            sym^.symbol:=__reg;
                            sym^.r := r;
                            sym^.typedef:=NIL;
                            p1:=GenVarNode(sym);
                          end
                        else
                          begin
                        if sym=NIL then
                          LineError(LineCount, 'Unknown identifier');
                        typ:=sym^.typedef;
                        case sym^.symbol of
                        _proc,
                        _func,
                        _variable  : p1:=GenVarNode(sym);
                        _type      : begin  {typeconversion}
                                       Match(_lparen);
                                       p1:=simple_expression;
                                       Match(_rparen);
                                       p1:=GenTypeConvNode(p1, typ, true);
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
                        else          begin
                                        LineError(LineCount, 'Error in expression');
                                      end;
                            end;
                        end;
                        DoQualifiers; {'[',']','.','^'}
                      end;
  _integer_constant : p1:=GenOrdConstNode(GetNumber, NIL);
  _real_constant    : {not allowed} {p1:=GenRealConstNode(GetFloat)};
  _string           : begin
                        Match(_lbracket);
                        p1:=simple_expression;
                        {OptimizeTree(p1);}
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
                      {LABEL!!!!}
                      Match(_at);
                      {p1:=factor;
                      p1:=GenLeftNode(__address,p1);}
                    end;
  _lparen         : begin { ( }
                      Match(_lparen);
                      p1:=simple_expression;
                      Match(_rparen);
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
  else
                    LineError(LineCount, 'Assembly parser: Error in expression');
  end;
  factor:=p1;
end;

function term:pTree;

var p1, p2 : pTree;
    l: longint;
begin
  l:=linecount;
  p1:=factor;
  if l=linecount then
  repeat
    case current_token of
    _mul        : begin { * }
                    Match(_mul);
                    p2:=factor;
                    p1:=GenExpNode(__mul,p1,p2);
                  end;
    _div,
    _slash:       begin { div }
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
    l: longint;

begin
  l:=linecount;
  p1:=term;
  if l=linecount then
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

end.

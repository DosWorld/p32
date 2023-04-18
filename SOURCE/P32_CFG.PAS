{                         P32 - 32bit Pascal Compiler                        }
{ -------------------------------------------------------------------------- }
{                       Johan Prins - jprins@knoware.nl                      }
{ ========================================================================== }
{                                                                            }
{                                                   (c) Copyright 1996-1999  }
{                                                                            }
{ -------------------------------------------------------------------------- }

unit P32_cfg;

interface

type
   configrec = record
              target     : string[15];
              comment,
              systemunit,
              assembler,
              linker     : string[63];
              tool       : array[1..1] of string[63];
              asmdef     : string[31]
            end;

var config     : configrec;
    compilerdir: string;
   __filename  : string;

procedure Usage;
procedure ReadConfig;
procedure CreateBatchFile(s:string);
procedure ExecuteBatchFile(s:string);
procedure SetCompilerDir;
function GetOptions:string;
function FileExists(filename: string): boolean;
function Execute(const prog, param:string):integer;

implementation

uses P32_code, P32_symb, P32_prep, P32_scan, P32_err, Dos;

type
   KeyWords = ( _unknown,
                _equal,
                _lbracket,
                _rbracket,
                _target,
                _comment,
                _systemunit,
                _assembler,
                _linker,
                _asmdef,
                _tool,
                _define,
                _compiler,
                _options
                );

const
    KeyNames : array [KeyWords] of string[11] =
    ('',
     '=',
     '[',
     ']',
     'TARGET',
     'COMMENT',
     'SYSTEMUNIT',
     'ASSEMBLER',
     'LINKER',
     'ASMDEF',
     'TOOL',
     'DEFINE',
     'COMPILER',
     'OPTIONS'
     );

   Cr  = #13;
   Lf  = #10;
   Tab = ^I;
   nr  = ord(_options);

var
   targets: array [1..16] of configrec;
   linecount,
   targetcounter: integer;
   look : char;
   ini  : text;
   s    : string;
   current: keywords;

procedure Usage;
begin
  writeln('Usage : P32 <options> <source> [.PAS]');
  writeln;
  writeln('Options:');
  writeln;
  writeln('-A<#>        Align data, # = 1, 2, 4, 8, F (16)  [default=4]');
  writeln('-As          Align stackframe');
  writeln('-Ap          Smart align strings');
  writeln;
  writeln('-B           Rebuild all files');
  writeln('-Ba          Create batch file for assembling and linking');
  writeln('-Bx          Create and execute batch file for assembling and linking');
  writeln;
  writeln('-Cs          Compile system unit');
  writeln('-Cr          Shuffle registers');
  writeln('-Cc-         Don''t allow register calling');
  writeln;
  writeln('-Dl          Add commented line numbers to output file');
  writeln('-Dh          Enable hints reporting');
  writeln('-Dd          Output decimal numbers');
  writeln;
  writeln('-I           Display compiler info');
  writeln;
  writeln('-M<#>        Set heapsize, # = 0..2147483647 bytes');
  writeln;
  writeln('-O-          Disable optimizing');
  writeln('-O<#>        Set lowlevel optimizing level, # = 1..9');
  writeln('-Ox          Maximum lowlevel optimizing');
  writeln('-OpPent      Optimize for Pentium processor');
  writeln('-OpPII       Optimize for Pentium II processor');
  writeln;
  writeln('-Sc          Enable nested comments');
  writeln('-Sz          Enable C-style comments');
  writeln('-Sp          Parentheses required for procedures and functions');
  writeln;
  halt(0);
end;

procedure CompilerInfo;
begin
  WriteLn;
  WriteLn('P32 is created by:');
  WriteLn('ù Johan Prins: Main program, scanner, parser, code-generator');
  WriteLn('ù Jose A.Vericat: Some floating point routines');
  WriteLn('ù Daniel D. Bennett: Unit saving routines');
  WriteLn('ù David Boshell: floating point routines, heap routines, absolute keyword');
  WriteLn('ù Laurie Boshell: break, continue, exit statements');
  WriteLn('ù Michael Goddard: IDE, RLE compression');
  WriteLn('ù Thomas Steen: Rewrite RLE compression, several code generation enhancements');
  WriteLn;
  WriteLn('P32 is completely free and comes with full sources, you may use it to produce');
  WriteLn('commercial programs.');
  WriteLn('When distributing this software package you may not charge more than US $5.');
  WriteLn;
  Usage;
end;

function ReplaceMacro(var source:string; const token, new: string):boolean;
var i, p : integer;
    ext:string;

begin
  ReplaceMacro:=FALSE;
  p := pos(token, source);
  if p<>0 then
    begin
      i:=p+length(token);
      if (length(token)+p-1=length(source)) or
         (source[i]  = '.') or
         (source[i]  = ' ') then
        begin
          delete(source, p, length(token));
          insert(new, source, p);
          ReplaceMacro:=TRUE;
        end
    end;
end;

function GetOptions:string;

var filename, tmp, s: string;
    code, i: integer;

begin
  if paramcount = 0 then Usage;
  i:=1;
  s:=paramstr(i);
  while i <> (ParamCount+1) do
  begin
    if (s[1]='-') or (s[1]='/') then
    begin
      s:=ToUpper(s);
      case s[2] of
      '?': Usage;
      'I': CompilerInfo;
      'A': case s[3] of
           '1' : Options.AlignData:=1;
           '2' : Options.AlignData:=2;
           '4' : Options.AlignData:=4;
           '8' : Options.AlignData:=8;
           'F' : Options.AlignData:=16;
           'S' : Options.AlignStackFrame:=TRUE;
           'P' : Options.AlignStrings:=TRUE;
           else  Options.AlignData:=4;
           end;
      'B': if length(s)=2 then
             Options.Build:=TRUE
           else
             case s[3] of
             'A': Options.CreateBatch:=TRUE;
             'X': Options.ExecuteBatch:=TRUE;
             end;
      'C': case s[3] of
           'S': begin
                  Options.CompileSystemUnit:=TRUE;
                  Options.OptimizeLevel:=0;
                end;
           'R': Options.ShuffleRegisters:=TRUE;
           'C': if s[4]='-' then Options.AllowRegisterCalling:=FALSE;
                            else Options.AllowRegisterCalling:=TRUE;
           end;
      'D': case s[3] of
           'L': Options.AddLineNumbers:=TRUE;
           'H': Options.Hints:=TRUE;
           'D': Options.DecimalNumbers:=TRUE;
           end;
      'M': begin {stack/heap memory-settings}
             s:=Copy(s, 3, Length(s));
             Val(s, Options.HeapSize, code);
             if code<>0 then Error('Invalid heapsize');
           end;
      'O': case s[3] of {optimize settings}
           '-'     : Options.OptimizeLevel:=0;
           '1'..'9': Options.OptimizeLevel:=ord(s[3])-ord('0');
           'C'     : Options.OptimizeCSE:=TRUE;
           'X'     : Options.OptimizeLevel:=255;
           'P'     : begin
                       tmp:=Copy(s, 4, length(s)-3);
                       if tmp='I386' then CPU:=i386
                       else
                         if tmp='I486' then CPU:=i486
                         else
                           if tmp='PENT' then CPU:=Pentium
                            else
                              if tmp='PMMX' then CPU:=PMMX
                              else
                                if tmp='PPro' then CPU:=PPro
                                else
                                  if tmp='PII' then CPU:=PII
                                  else
                                    if tmp='K6' then CPU:=K6
                                    else
                                      if tmp='K7' then CPU:=K7;
                     end;
           else      Error('-O1..9, D, P, X required');
           end;
      'S': case s[3] of
           'C': Options.NestedComments:=TRUE;
           'Z': Options.CstyleComments:=TRUE;
           'P': Options.Parentheses:=TRUE;
           end;
      else Error('Invalid commandline switch');
      end
    end
    else
    begin
      filename:=s;
    end;
    inc(i);
    s:=paramstr(i);
  end;
  GetOptions := filename;
end;

procedure GetChar;
begin
  if not eof(ini) then read(ini, look);
  if Look = #13 then Inc(LineCount);
end;

procedure SkipSpace;
begin
  while (look in [Cr, Lf, Tab, ' '] ) and (not eof(ini)) do
    GetChar;
end;

procedure GetToken;

label
   restart;

var
   i: integer;
   k: keywords;

begin
RESTART:
   s:='';
   k:=_unknown;
   SkipSpace;
   case Look of
   ';'  : begin
            repeat
              getchar;
            until Look = Lf;
            goto RESTART;
          end;
   '=',
   ']',
   '['  : begin
            s:=look;
            getchar;
                    for i := 0 to nr do
                      if s = KeyNames[KeyWords(i)] then
                        begin
                          k := KeyWords(i);
                          break;
                        end;
          end;
  ''''  : begin {string constant}
                    getchar;
                    {X := false;}
                    repeat
                      case look of
                      cr    : abort('String exceeds line');
                      ''''  : begin
                                getchar;
                                if look <> '''' then break
                                else begin
                                       s := s + look;
                                       getchar;
                                     end;
                              end;
                      else
                              s := s + look;
                              getchar;
                      end;
                    until false;
                  end;
   else         begin {identifier}
                  while not (Look in [Cr, Lf, '=', ' ',']','[']) do
                  begin
                    s := s + upcase(Look);
                    GetChar;
                  end;
                    for i := 0 to nr do
                      if s = KeyNames[KeyWords(i)] then
                        begin
                          k := KeyWords(i);
                          break;
                        end;
                end;
   end;
   current:=k;
end;

procedure Match(x: keywords);
begin
  if Current <> X then
    begin
      if ord (X) <= nr then Error('P32.INI ('+ Numb(linecount)+') '+KeyNames[x]+'  expected');
    end
  else
  GetToken;
end;

procedure SetCompilerDir;
var
   _P  : PathStr;
   _D  : DirStr;
   _N  : NameStr;
   _E  : ExtStr;

begin
  fsplit(paramstr(0), _D, _N, _E);
  compilerdir := ToUpper(_D);
end;

procedure ReadConfig;
var t:KeyWords;
    i:integer;
    temp,
    inipath:string;
    p : pstring;

begin
  inipath:=FSearch('P32.INI','.\;'+GetEnv('P32')+';'+GetEnv('P32')+'\BIN\;'+GetEnv('PATH'));
  if inipath='' then Error('P32.INI not found');
  assign(ini, inipath);
  {$I-} reset(ini); {$I+}
  if ioresult <> 0 then Error('P32.INI not found');
  LineCount:=1;
  targetcounter:=0;
  GetChar;
  repeat
    GetToken;
    if current=_lbracket then Match(_lbracket);
    case current of
    _target : begin
                GetToken; {'s' contains string now}
                inc(targetcounter);
                targets[targetcounter].target:=s;
                GetToken; {advance to next token}
                Match(_rbracket);
                while (current<>_lbracket) and not eof(ini) do
                begin
                  case current of
                  _comment   : begin
                                 Match(_comment);
                                 Match(_equal);
                                 if current<>_unknown then continue;
                                 targets[targetcounter].comment:=s;
                                 GetToken;
                               end;
                  _systemunit: begin
                                 Match(_systemunit);
                                 Match(_equal);
                                 if current<>_unknown then continue;
                                 targets[targetcounter].systemunit:=s;
                                 GetToken;
                               end;
                  _assembler : begin
                                 Match(_assembler);
                                 Match(_equal);
                                 if current<>_unknown then continue; {fix to allow no parameters}
                                 targets[targetcounter].assembler:=s;
                                 GetToken;
                               end;
                  _linker    : begin
                                 Match(_linker);
                                 Match(_equal);
                                 if current<>_unknown then continue;
                                 targets[targetcounter].linker:=s;
                                 GetToken;
                               end;
                  _asmdef    : begin
                                 Match(_asmdef);
                                 Match(_equal);
                                 if current<>_unknown then continue;
                                 targets[targetcounter].asmdef:=s;
                                 GetToken;
                               end;
                  _tool      : begin
                                 Match(_tool);
                                 Match(_equal);
                                 if current<>_unknown then continue;
                                 targets[targetcounter].tool[1]:=s;
                                 GetToken;
                               end;
                  _unknown   : Error('P32.INI ('+ Numb(linecount)+') Entry expected');
                  end;
                end;
              end;
    _compiler:begin
                Match(_compiler);
                Match(_rbracket);
                repeat
                case current of
                _options: begin
                            Match(_options);
                            Match(_equal);
                            if current=_unknown then
                              begin
                                asm
                                  mov  es, PrefixSeg
                                  mov  di, offset 080h
                                  mov  word ptr [p+2], es
                                  mov  word ptr [p], di
                                end;
                                p^:=s + ' '+ p^;
                                GetToken;
                              end
                            else
                              continue;
                          end;
                _target : begin
                            Match(_target);
                            Match(_equal);
                            i:=0;
                            repeat
                              inc(i);
                              if s=targets[i].target then break
                            until i=targetcounter;
                            config:=targets[i];
                            GetToken;
                          end;
                end;
                until (current <> _target) and (current <> _options)
              end;
    end;
  until eof(ini);
  AddString(directive_names,config.target);
end;


procedure CreateBatchFile(s:string);
var batch: text;
    asmstring,
    linkstring,
    toolstring,
    unitlist,
    env,
    tmp  : string;
    list: pSymbols;
    sym  : pSymbolRecord;

   _D  : DirStr;
   _N  : NameStr;
   _E  : ExtStr;

begin
  assign(batch, 'C.BAT');
  rewrite(batch);
  writeln(batch, '@ECHO OFF');
  writeln(batch, 'REM  Batch file to compile: ', programname);
  writeln(batch, 'REM  Target: ', config.comment, ' (',config.target,')');
  asmstring:=config.assembler;
  linkstring:=config.linker;
  toolstring:=config.tool[1];

  fsplit(s, _D, _N, _E);
  s:=_D+_N; {rip off the extension}

  ReplaceMacro(asmstring, '$NAME', s+'.ASM');
  writeln(batch, asmstring);

  unitlist:=s+'.OBJ'; {filename}

  env:=GetEnv('P32');
  list:=lastlist;
  while list<>nil do
    begin
      sym:=list^.list^.first;
      if sym<>NIL then
        while sym<>NIL do
          begin
            if (sym^.symbol=_unit) then
              begin
                tmp:=sym^.overloadedname;
                fsplit(tmp, _D, _N, _E);
                tmp:=' '+_D+_N; {rip off the extension}
                if not sym^.loaded then
                  begin
                    asmstring:=config.assembler;
                    if tmp<>'' then
                    if ReplaceMacro(asmstring, '$NAME', tmp+'.ASM') then
                      writeln(batch, asmstring);
                  end;
                unitlist:=unitlist+tmp+'.OBJ';
              end;
            sym:=sym^.next;
          end;
        list:=list^.prev;
    end;

    if ReplaceMacro(linkstring, '$LIST', unitlist) then
      writeln(batch, linkstring);
    if ReplaceMacro(toolstring, '$NAME', s+'.EXE') then
      writeln(batch, toolstring);
  close(batch);
end;

procedure ExecuteBatchFile(s:string);
var result: word;
begin
  CreateBatchFile(s);
  Result:=Execute(GetEnv('COMSPEC'), '/C C.BAT');
  if doserror<>0 then Error('Executing batchfile, error: '+ Numb(doserror));
end;

function FileExists(filename: string): boolean;
var f:file;
begin;
 {$I-}
 assign(f, filename);
 filemode:=0;
 reset(f);
 close(f);
 {$I+}
 FileExists:=(IOResult=0) and (FileName<>'');
 filemode:=2;
end;

function Execute(const prog, param:string):integer;
var
   OldHeapEnd: pointer;
   result: word;

begin
  SwapVectors;
  Exec(prog, param);
  SwapVectors;
  {$IFDEF debug}
  WriteLn('Returned from the swap.. Results:  High byte = ',Hi(Result),' Low byte = ',Lo(Result));
  {$ENDIF}
  Execute:=Result;
end;

end.

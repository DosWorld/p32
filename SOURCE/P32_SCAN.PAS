{                         P32 - 32bit Pascal Compiler                        }
{ -------------------------------------------------------------------------- }
{                       Johan Prins - jprins@knoware.nl                      }
{ ========================================================================== }
{ Scanner and token-recognition  ( a.k.a. lexical analyser)                  }
{                                                   (c) Copyright 1996-1999  }
{                                                                            }
{ -------------------------------------------------------------------------- }
{ $DEFINE P32IDE}

unit P32_scan;

interface

uses P32_err, P32_prep, P32_cfg, Dos;

type
   PSourceRec = ^TSourceRec;
   TSourceRec = record
                  F: Text;
                  Next: PSourceRec;
                end;

  string10     = string[10];

const
   P32_version = 'v0.5á2';
   {$I date.inc}                              {...compilation date...}
   TextBufferSize = 8*1024; {8 Kb}
   VMTPrefix = 'VMT';
   TCPrefix  = '_';

   SourceStack: PSourceRec = nil;
   IncludeFileName: String = '';
   WasInclude: Boolean = False;

{
* and
* asm
* array
* begin
* case
* const
* constructor
* destructor
* div
* do
* downto
* else
* end
exports
* file
* for
* function
* goto
* if
* implementation
* in
* inherited
inline !! -> standard directive in P32
* interface
* label
library
* mod
* nil
* not
* object
* of
* or
packed
* procedure
* program
* record
* repeat
* set
* shl
* shr
* string
* then
* to
* type
* unit
* until
* uses
* var
* while
* with
* xor
}
{ Standard directives and procedure directives

  Unlike reserved words, these words can be redefined; however, this is not
  advised.

  absolute
  index
* interrupt
  resident

* private
* public

* far        (procedure directive)
* near       (procedure directive)
  virtual    (procedure directive)
* assembler  (procedure directive)
  export     (procedure directive)
* external   (procedure directive)
  forward    (procedure directive)

}

{ Tokens... reserved words and special symbols have fixed meanings in P32,
  these cannot be redefined! }
const
   _public    = 'PUBLIC';
   _private   = 'PRIVATE';
   _far       = 'FAR';
   _near      = 'NEAR';
   _interrupt = 'INTERRUPT';
   _external  = 'EXTERNAL';
   _assembler = 'ASSEMBLER';
   _register  = 'REGISTER';
   _win32api  = 'WIN32API';
   _inline    = 'INLINE';

type

   Str14      = string[14];

   Token      =

   (   _null,
    _program,             _var,            _const,
      _type_,           _begin,            _while,
     _downto,              _do,           _repeat,
      _until,             _asm,              _end,

     _period,           _comma,             _plus,
      _minus,             _mul,              _div,
        _mod,              _at,              _ptr,
        _shl,             _shr,            _slash,
     _lparen,          _rparen,        _separator,
     _assign,           _equal,          _greater,
       _less,         _less_eq,       _greater_eq,
     _not_eq,           _colon,               _in,

         _if,            _then,             _else,
        _for,              _to,              _set,
  _procedure,        _function,          _object_,

_constructor,      _destructor,

{!} _virtual,
{!} _dynamic,

  _inherited,
   _lbracket,        _rbracket,          _period2,
         _of,             _and,               _or,
        _xor,             _nil,
        _not,           _array,           _record,
     _string,
       _file,
       _goto,            _case,             _with,

      __unit,  _implementation,        _interface,
       _uses,

{ change these to inline procedures }
{!}    _break,
{!}    _continue,
{!}    _exit,

       _label_,

{!}    _absolute,

       _unknown,
       _string_constant, _integer_constant, _char_constant,
       _real_constant, _name);

const

   MaxToken  = high(token);

   TokenName : array[token] of Str14 =
   (       '',
    'PROGRAM',            'VAR',
      'CONST',           'TYPE',
      'BEGIN',          'WHILE',          'DOWNTO',
         'DO',         'REPEAT',           'UNTIL',
        'ASM',            'END',
          '.',              ',',               '+',
          '-',              '*',             'DIV',
        'MOD',              '@',               '^',
        'SHL',            'SHR',               '/',
          '(',              ')',               ';',
         ':=',              '=',               '>',
          '<',             '<=',              '>=',
         '<>',              ':',               'IN',
         'IF',
       'THEN',           'ELSE',              'FOR',
         'TO',            'SET',
  'PROCEDURE',       'FUNCTION',           'OBJECT',
'CONSTRUCTOR',     'DESTRUCTOR',          'VIRTUAL',
    'DYNAMIC',      'INHERITED',

          '[',              ']',               '..',
         'OF',            'AND',               'OR',
        'XOR',            'NIL',
        'NOT',          'ARRAY',           'RECORD',
     'STRING',
       'FILE',
       'GOTO',           'CASE',             'WITH',
       'UNIT', 'IMPLEMENTATION',        'INTERFACE',
       'USES',          'BREAK',         'CONTINUE',
       'EXIT',          'LABEL',         'ABSOLUTE',
           '',               '',                 '',
           '',               '',                 '');

   current_unit: string='';

Type
 FileInfo = record {record for progress counter}
             Size:LongInt;
             WhereNow:LongInt;
             Divisor:LongInt;
            end;
 PFileInfo = ^FileInfo;

 TNumbStr = string[11];

var
   OldFInf               :PFileInfo;
   FInf                  :PFileInfo;

   Look,Ahead            : char;                   {last read char}
   CommentTerminator     : char;
   source, dest, incl    : ^text;                  {file-pointers}
   ProcName              : string;                 {current procedure}
   ProgramName           : string;                 {program name }
   NewLine               : boolean;

   upcase_string         : string;
   current_string        : string;
   current_token         : token;
   current_number        : longint;
   current_float         : double;
   previous_token        : token;

procedure OpenFileRead(var t: text; const s:string);
procedure OpenFileWrite(var t: text; const s:string);
procedure CloseFile(var t: text);

function numb(i : longint): TNumbStr;
{converts a number to a string}
procedure GetChar;
{gets a char from sourcefile}
procedure SkipSpace;
{removes unwanted spaces}
function  ToUpper(const s : string): string;
{converts a string to uppercase}
function  ToLower(const s : string): string;
{converts a string to lowercase}
function LongToHex(AnyLong : LongInt): string10;
{convert longint to hex string}
procedure GetToken;
{gets a string from a file and analyses it...returns a token/name/number}
procedure GetIdentifier;
{gets an identifier from the sourcefile}
function  GetName: string;
{gets a variable name from the sourcefile}
function  GetNumber: longint;
{gets a number from the sourcefile}
function GetLabel: string;   {LB for goto and labels}
{gets a label from the source file}
function GetFloat: double;
{gets a number from the sourcefile}
procedure Match(x: Token);
{'Eats' the current token and processes the next token}
function MaybeLabel(x:Token):boolean;
{Returns true if x is a pascal label (identifier or integer constant) }

{ should be here because it's the only unit p32_prep and p32 use }

implementation

uses P32_asm, P32_symb;

const
   Cr  = #13;
   Lf  = #10;
   EofC= #26;
   Tab = ^I;
   HexCode   = '0123456789ABCDEF';

var
   WithinString: boolean;
   StringLine  : longint;

procedure OpenFileRead(var t: text; const s:string);
var
   buf         : pointer;
   l           : longint;
   PrevFileMode: integer;

begin
  if s <> '' then
    begin
      assign(t, s);
      Getmem(buf, TextBufferSize);
      settextbuf(t, buf^, TextBufferSize);
      PrevFileMode := FileMode;
      FileMode := 0; { read-only; allows opening read-only files }
      {$I-} reset(t); {$I+}
      FileMode := PrevFileMode;
      WasInclude := False;
      WithinString := False;
      if IOResult <> 0 then Error(s+' not found');
    end
  else
    if IOResult <> 0 then Error('Error assigning file');
end;

procedure OpenFileWrite(var t: text; const s:string);
var
   buf: pointer;

begin
  if s <> '' then
    begin
      assign(t, s);
      Getmem(buf, TextBufferSize);
      settextbuf(t, buf^, TextBufferSize);
      {$I-} rewrite(t); {$I+}
      if IOResult <> 0 then Error(s+' not found');
    end
  else
    if IOResult <> 0 then Error('Error assigning file');
end;

procedure CloseFile(var t: text);
begin
  close(t);
  Freemem(TextRec(t).BufPtr, TextBufferSize);
end;

function numb(i : longint): TNumbStr;
{converts number to string}
var
   s : TNumbStr;
begin
   str(i, s);
   numb:=s;
end;

procedure GetChar;
var l:longint;
begin
   Look:=Ahead;
   if not eof(source^) then
     begin
       read(Source^, Ahead);
       {$IFNDEF P32IDE}
       Inc(FInf^.WhereNow);
       If (FInf^.WhereNow mod FInf^.divisor = 0) then
         { Only update when another percent is done }
       Write(__filename,'  ',FInf^.WhereNow div FInf^.divisor,'%',#13);
       {$ENDIF}
     end
   else
     Look := EofC;
   if Look = Cr then begin
                        inc(LineCount);
                        NewLine:=TRUE;
                        {$IFDEF P32IDE}
                        ShowLineNum;
                        {$ENDIF}
                      end;
end;

procedure SkipSpace;
begin
  if asmmode then
    begin
      while (look in [Tab, ' '] ) and (not eof(source^)) do
        GetChar;
    end
  else
    begin
      while (look in [Cr, Lf, Tab, ' '] ) and (not eof(source^)) do
        GetChar;
    end
end;

procedure ProcessInclude;

var
  P: Pointer;
  F: Text;

begin
  P := SourceStack;
  New(SourceStack);
  SourceStack^.Next := P;
  OpenFileRead(SourceStack^.F, IncludeFileName);
  Source := Addr(SourceStack^.F);
end;

procedure DoComments;

var
   EndComment: Boolean;

begin
  GetChar; { read the first character in the comment }
  if look = '$' then DoDirectives;

  EndComment := False;
  repeat
    case look of
    '}' : if CommentTerminator = '}' then
            EndComment := True;
    '*' : if Ahead = CommentTerminator then
          begin
            GetChar; { eat the '*' }
            EndComment := True;
          end;
    '{' : if Options.NestedComments and (CommentTerminator = '}') then
            DoComments;
    '/' : if (Ahead = '*') and Options.NestedComments and (CommentTerminator = '/') then
          begin
            GetChar;
            DoComments;
          end;
    '(' : if (Ahead = '*') and Options.NestedComments and (CommentTerminator = ')') then
          begin
            GetChar;
            DoComments;
          end;
    EofC: Exit;
    end;

    if WasInclude then ProcessInclude;

    GetChar; { read the next character / eat the last terminator }
  until EndComment;
end;


procedure GetIdentifier;
begin
  current_string := '';
  upcase_string := '';
  SkipSpace;
  if Look in ['_','A'..'Z','a'..'z'] then
  begin
    repeat
      current_string := current_string + Look;
      upcase_string := upcase_string + upcase(Look);
      GetChar;
    until not (Look in ['_','A'..'Z','a'..'z', '0'..'9']);
  end else
    Expected('compiler directive');
end;

procedure GetToken;

label
   restart;
var
   tmp:string;
   code:integer;
   i    : token;
   j    : word;
   o    : longint;
   open, X   : boolean;
   tmpchar, last: char;

begin
RESTART:
        SkipSpace;
        if not WithinString then
        case look of
        '{'  :    begin {normal comments}
                    CommentTerminator := '}';
                    DoComments;
                    goto RESTART;
                  end;
        '('  :    if Ahead = '*' then
                  begin
                    GetChar;
                    CommentTerminator := ')';
                    DoComments;
                    goto RESTART;
                  end;
        '/'  :    begin
                    if Options.CStyleComments and (Ahead = '*') then
                    begin
                      GetChar;
                      CommentTerminator := '/';
                      DoComments;
                      goto RESTART;
                    end;
                    if Ahead = '/' then
                    begin
                      o:=LineCount;
                      while (LineCount = o) and not eof(source^) do getchar;
                      goto Restart;
                    end;
                  end;
        '-'  :    begin  {ADA-style, one line comment}
                    if Options.AdaStyleComments and (Ahead = '-') then
                    begin
                      o:=LineCount;
                      while (LineCount = o) and not eof(source^) do getchar;
                      goto Restart;
                    end;
                  end;
        '''' :    if SkippingFalseIf then
                  begin
                    WithinString := True;
                    { StringLine holds the line where a string is initiated }
                    { (needed since strings can't extend beyond EOL) }
                    StringLine := LineCount;
                  end;
        EofC :    if SkippingFalseIf then
                    Error('$ENDIF directive missing')
                  else
                    exit;
        end
        else 
          if (look = '''') or (LineCount <> StringLine) then
            WithinString := False;

        if SkippingFalseIf then
        begin
          GetChar;
          goto RESTART;
        end;

        code:=0;
        previous_token := current_token;
        Current_String := '';
        Current_Token  := _Unknown;
        Current_Number := 0;

        case Look of
        '#',
        ''''    : begin {string constant}
                    current_string := '';
                    X := false;
                    open:=false;
                    repeat
                      case look of
                      cr    : abort('String exceeds line');
                      '#'   : begin
                                getchar;
                                tmp:='';
                                while (upcase(Look) in ['$','0'..'9', 'A'..'F'] ) do
                                begin
                                  tmp:=tmp+look;
                                  GetChar;
                                end;
                                val(tmp, current_number, code);
                                current_string:=current_string+chr(current_number);
                                open:=false;
                              end;
                      ''''  : begin
                                getchar;
                                repeat
                                  case look of
                                  cr    : abort('String exceeds line');
                                  ''''  : begin
                                            getchar;
                                            if look<>'''' then
                                              begin
                                                open:=false;
                                                break;
                                              end
                                            else begin
                                                   current_string := current_string + look;
                                                   getchar;
                                                   open:=true;
                                                 end;
                                          end;
                                  else begin
                                         current_string := current_string + look;
                                         getchar;
                                         open:=true;
                                       end;
                                  end;
                                until false;
                              end;
                      else
                      current_string := current_string + look;
                      getchar;
                      open:=true;
                      end;
                    until (not open) and not (look in ['#','''']);
                    current_token := _string_constant;
                    if length(current_string)=1 then current_token:=_char_constant;
                  end;
        '$'     : begin {hex-number}
                    current_string:=look;
                    getchar;
                    while (upcase(Look) in ['$','0'..'9', 'A'..'F'] ) do
                    begin
                      current_string:=current_string+look;
                      GetChar;
                    end;
                    val(current_string, current_number, code);
                    Current_Token := _integer_constant;
                 end;
       '0'..'9': begin {number}
                  while Look in ['0'..'9'] do
                  begin
                    current_string:=current_string+look;
                    GetChar;
                  end;
                  if (Look='.') or (upcase(Look)='E') then
                    begin
                     if (Ahead='.') then begin {subrange, like: 1..100}
                                           val(current_string, current_Number, code);
                                           current_token := _integer_constant;
                                         end
                     else                begin
                                           if (upcase(Look) in ['.','0'..'9','E'{,'-'}]) then
                                           begin {real constant: 3. or 2.0}
                                             current_string:=current_string+look;
                                             GetChar;
                                             while (upcase(Look) in ['0'..'9']) do
                                               begin
                                                 current_string:=current_string+look;
                                                 GetChar;
                                              end;
                                             if (upcase(look) = 'E') then
                                               begin
                                                 current_string:=current_string+look;
                                                 GetChar;
                                                 while (upcase(Look) in ['0'..'9','-']) do
                                                   begin
                                                     current_string:=current_string+look;
                                                     GetChar;
                                                   end;
                                               end;
                                             if (look='h') or (look='h') then
                                               begin
                                                 {delete(current_string,length(current_string),1);}
                                                 GetChar; {eat the 'h'}
                                                 val('$'+numb(current_number)+current_string, current_number, code);
                                                 current_token := _integer_constant;
                                               end
                                             else
                                               begin
                                                 val(current_string, current_float, code);
                                                 current_token := _real_constant;
                                               end;
                                           end;
                                         end
                     end
                  else begin
                         val(current_string,Current_Number,code);
                         current_token := _integer_constant;
                       end;
                end;
    '_',
    'A'..'Z',
    'a'..'z'  : begin {identifier}
                  while Look in ['_', '0'..'9','A'..'Z','a'..'z' ] do
                  begin
                    Current_String := current_string + look;
                    GetChar;
                  end;
                    for i := low(i) to MaxToken do
                      if ToUpper(Current_String) = TokenName[i] then
                      begin
                        Current_Token := i;
                        {goto done}
                      end;
                  if Current_Token = _unknown then Current_Token := _name;
                end;
    else        Current_String := Look;
                GetChar;
                repeat
                  J := 0;
                  for i := low(i) to MaxToken do
                    if ToUpper(Current_string + Look) = TokenName[i] then J := word(i);
                    if J <> 0 then begin
                                     Current_String := Current_String + Look;
                                     GetChar;
                                   end;
                until J = 0;
                for i := low(i) to MaxToken do
                  if ToUpper(Current_String) = TokenName[i] then  J := word(i);
                  Current_Token := Token(j);
    end;
    upcase_string:=ToUpper(current_string);
if code<>0 then Error('Invalid number');
end;

function ToLower(const s:string):string; assembler;
asm
    push ds
    lds  si,s
    les  di,@result
    lodsb            { load and store length of string }
    stosb
    xor  ch,ch
    mov  cl,al
    jcxz @empty      { FIX for null string }
  @LowerLoop:
    lodsb
    cmp  al,'A'
    jb   @cont
    cmp  al,'Z'
    ja   @cont
    add  al,' '
  @cont:
    stosb
    loop @LowerLoop
  @empty:
    pop  ds
end;

function ToUpper(const s:string):string; assembler;
asm
    push ds
    lds  si,s
    les  di,@result
    lodsb            { load and store length of string }
    stosb
    xor  ch,ch
    mov  cl,al
    jcxz @empty      { FIX for null length string }
  @upperLoop:
    lodsb
    cmp  al,'a'
    jb   @cont
    cmp  al,'z'
    ja   @cont
    sub  al,' '
  @cont:
    stosb
    loop @UpperLoop
  @empty:
    pop  ds
end;

function LongToHex(AnyLong : LongInt): string10;
var
  ch       : Char;
  Index    : Byte;
  HexString: string10;

begin
  HexString := '00000000';                  { default to zero   }
  Index := Length(HexString);              { String length     }
  While AnyLong <> 0 do
  begin                                     { loop 'til done    }
    ch := Chr(48 + Byte(AnyLong) and $0F);  { 0..9 -> '0'..'9'  }
    if ch > '9' then
      Inc(ch, 7);                           { 10..15 -> 'A'..'F'}
    HexString[Index] := ch;                 { insert Char       }
    Dec(Index);                             { adjust chr Index  }
    AnyLong := AnyLong SHR 4;               { For next nibble   }
  end;
  LongToHex:='0'+Copy(HexString, Index+1, 8-Index)+'h';
end;

function GetName: string;
begin
  if Current_Token = _Name then GetName := '_' + ToUpper (Current_String)
   else
    Expected ('identifier');
   GetToken;
 end;

function GetNumber: longint;
var code:integer;
begin
  current_string:='';
  if upcase(look) in ['A'..'F','H'] then
  begin
    while (upcase(Look) in ['$','0'..'9', 'A'..'F'] ) do
      begin
        current_string:=current_string+look;
        GetChar;
      end;
    if upcase(look)='H' then GetChar;
    val('$'+numb(current_number)+current_string, current_number, code);
  end;
  {Current_Token := _integer_constant;}
  GetNumber := Current_Number;
  GetToken;
end;

function GetFloat: double;
begin
  GetFloat:=Current_Float;
  GetToken;
end;

function GetLabel: string;   {LB for goto and labels}
var s:string;    {?reduce this to string[20]}
begin
  if Current_Token = _Name then GetLabel := GetName
   else
  if Current_Token = _integer_constant then
    begin {convert integer label to string}
    {str(current_number:0,s);}
    GetLabel := '_' + Numb(GetNumber);
    end
   else
    Expected ('identifier or integer constant');
{   GetToken;}
 end;

procedure Match(x: Token);
{'Eats' the current token and processes the next token}
begin
  NewLine:=FALSE;
  if Current_Token <> X then
    begin
      if X <= MaxToken then Expected(TokenName[X])
                             else Abort('Unknown token, compiler error!');
    end
  else
    GetToken;
end;

function MaybeLabel(x:Token):boolean;
{Returns true if x is a pascal label (identifier or integer constant) }
{Standard pascal only allows an integer constant, BP extends this to  }
{allow identifiers as well, both followed by a colon. x=current_token }

Begin
  MaybeLabel := (x=_integer_constant) or (x=_name);
end;

end.
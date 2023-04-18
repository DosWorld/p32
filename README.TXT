
                                                   P32, 32 bit pascal compiler

                                                                by Johan Prins

                                                            http://surf.to/p32

1. Introduction

1.1. Requirements
To use to compiler you need to following equipment:
. PC with at least a 386 processor
. Some free harddisk space

The compiler produces files containing assembly code. This code can be 
processed by an assembler. Good examples are TASM or NASM. See section 1.4 for 
more information on the tools. The next step is 'linking' the generated 
object files. You need a linker for this, several linkers are described in 
section 1.4.

Short summary of the process:

pascal file -> P32 -> assembly file -> ASM -> object file -> LINK -> executable
   
Because there are a lot of good assemblers and linkers I didn't bother about 
writing my own ones. Maybe I will add them in the very far future.

1.1. History
P32 is a free 32 bit Pascal compiler. The history of P32 started in 1996 when 
I downloaded PowerPascal. This little 'compiler', which produced code for 
OS/2, was the first compiler that had understandable source code. The first 
version of P32 was a simple conversion to the DOS protected mode (DOS32) 
platform. I realized the potential of the compiler and started adding a lot of 
new functions, like: support for procedures/functions, more data types, 
support for floating point numbers, etc. When I wanted to add more advanced 
functions like strong type checking, support for units, type conversios I 
discovered that the structure of the compiler wasn't strong enough. To come 
around this I completely rewrote the compiler so that it used symboltables and 
a parse tree. All identifiers were stored in symboltables and the parse tree 
stored the parsed pascal program. From the parse tree the compiler generated 
the assembly code. Up to now this structure is still sufficient and will 
remain the same for a long time, I hope.

1.2. Freeware
P32 is being released as freeware/sourceware. This means that you don't need 
to pay anything for the program, besides that also all the sources to create 
the executables are included. Some people

2. User manual

2.1.

2.2.

2.3. Procedures and functions
One of the main aspects of the Pascal programming language is the use of 
procedures and functions. These can greatly enhance the structure of your 
program. P32 adds several powerful features to procedures which make them 
more versatile. This is accomplished by adding some, optional,  keywords. 
These keywords will be described later. First the syntax of the procedure 
(and function) is described:

procedure <name> ( <parameters> ); <keyword> ; <string constant> ;

<block statement>

function <name> ( <parameters> ): <type> ; <keyword> ; <string constant> ;

<block statement>

As you might now everything behind the <name> is optional and can be combined
in different ways. 

2.3.1. String constant
The <string constant> _needs_ to be the last element on the declaration line. 
The string constant can contain the actual name that P32 uses for the 
procedure/function when creating the assembly file. This can become very handy 
when linking with external object files.

e.g:     procedure modplay(var s: string); external; 'mxmplay';

         This will create a procedure called 'modplay' but that procedure 
         is actually a function in an third party library called 'mxmplay'.

2.3.2. Keywords.

far, near, interrupt
Added for compatibility with other compilers. The're ignored by P32, for 
clearity a warning message is outputted.

assembler
This forces you to use an asm-statement (asm..end) for the whole procedure or
function. This helps you to write fast procedures in assembly language. The
function result is returned on various places depending on the data type.

. Integers, pointers, booleans and enumerated types return the result in the
  CPU register: EAX.
. Floating point numbers need to be returned on the first FPU stack position, 
  called: ST(0).
. Other structures, such as string are not fully supported yet, so don't use 
  the assembler keyword for these.

register

inline
external
win32api

2.4. Inline assembler

The inline assembler can be invoked by using the ASM..END keywords. All 
statements between these two keywords are seen as assembler statements. The
assembler parser isn't very sophisticated. This means that a lot of syntax
errors aren't catched by the parser, the external assembler will than
complain about them.
There are a few rules you should keep in mind when using the inline assembler. 

When accessing variables always prefix the variable with one of the strings
in the table, also you're forced to use brackets ('[',']') around the
variables.

Examples:

   mov eax, dword ptr [myvar]    {correct}
   mov eax, myvar                {incorrect}
   mov eax, dword ptr fs:[myvar] {correct}
   mov eax, dword ptr fs:eax     {incorrect}
   mov eax, dword ptr fs:[eax]   {correct}

| Prefix    | Size of variable |
|-----------|------------------|
| BYTE PTR  |       1          |
| WORD PTR  |       2          |
| DWORD PTR |       4          |
| QWORD PTR |       8          |
| TBYTE PTR |       10         |

It's possible to let the compiler calculate certain values. This means that
you can include a formula (_only_ containing constants of course) which will
be optimized to a normal integer number. You can use numbers in decimal and
hexadecimal format.

Example:

   mov eax, (256*100)+080h

Known incompatibilities
- @RESULT isn't recognized




3. P32 Internals

3.1. Structure of P32

This chapter will explain the structure of P32. The structure of P32 is not 
derived from any book or whatever. Most of the theories and code are designed
by myself or inspired by other compilers.

The compiler consist of several parts that can be characterized by the 
following names:

Program-parts:

scanner
parser
optimizer
code generator

Data-structures:

symbol-table
constant-table
parse-tree

The heart of the compiler can be found in the combination of the scanner, 
parser, code-generator, symboltable and parse-tree. The following paragraphs 
will describe the functions of these parts.

3.2. Scanner

3.2.1. General
The scanner, some may call it a lexical analyser, takes care of the reading of
the source. The source is a normal textfile containing regular Pascal code. 
The scanner will recognize keywords, identifiers, operators and numbers. The 
operators (e.g. +, -, /, *) and keywords (e.g. BEGIN, END) are converted to 
so-called tokens. These tokens are easier (and faster) to handle for the 
compiler as strings. The identifiers are returned as strings and numbers are 
returned as either integers or floating points, depending on their type. The 
scanner is called by the parser. P32 uses a parser-driven scanner techniques. 
This means that when the parser needs more information the scanner is called. 
The scanner returns the requested information and the parser will process it.

3.2.2. Tokens
The compiler use token to simplify the source code analyzing. The following 
structure is a simplified structure of the one used in P32. It's printed here 
as an example.

Example token structure:

   Token      = 
   (_unknown, _string_constant, _integer_constant,
                _char_constant,    _real_constant,
       _name,         _program,             _var,            
      _const,           _type_,           _begin,            
      _while,          _repeat,     	  _until,
     _lparen,          _rparen,       _separator,
     _assign,           _equal,         _greater,
       _less,         _less_eq,      _greater_eq,
     _not_eq,           _colon);

The token strings are stored in typed constant array. The actual reading and 
analysing is done by the GetToken procedure. This procedure looks like this:

procedure GetToken;

begin
  case Look of {skip comments}
  '{'  :    begin
              getchar;
              if look='$' then DoDirectives;
              repeat
                getchar;
              until Look = '}';
              getchar;
            end;
  '0'..'9': begin {number, integer/floating point}
              while Look in ['0'..'9'] do
              begin
                current_string:=current_string+look;
                GetChar;
              end;
              if (Look='.') or (upcase(Look)='E') then
                if (Ahead='.') then 
                  begin {subrange, like: 1..100}
                    val(current_string, current_Number, code);
                    current_token := _integer_constant;
                  end
                else                
                  begin
                    if (upcase(Look) in ['.','0'..'9','E','-']) then
                      begin {real constant: 3. or 2.0}
	                  current_string:=current_string+look;
                        GetChar;
                        while (upcase(Look) in ['0'..'9','E','-']) do
                        begin
                          current_string:=current_string+look;
                          GetChar;
                        end;
                        val(current_string, current_float, code);
                        current_token := _real_constant;
                      end;
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
                    Current_String := Current_String + upcase(Look);
                    GetChar;
                  end;
                for i := 0 to MaxToken do
                   if Current_String = TokenName[token(i)] then
                     begin
                       Current_Token := Token(i);
                     end;
                if Current_Token=_unknown then Current_Token:=_name;
              end;
  else        Current_String := upcase(Look);
              GetChar;
              repeat
                J := 0;
                for i := 0 to MaxToken do
                   if (Current_string + upcase(Look)) =
	                 TokenName[token(i)] then J := i;
                    if J <> 0 then 
                      begin
                        Current_String := Current_String + upcase(Look);
                        GetChar;
                      end;
              until J = 0;
              for i := 0 to MaxToken do
                 if Current_String = TokenName[token(i)] then J := i;
              Current_Token := Token(j);
    end;
end;

This is a simplified example but it should give you an idea of the working of 
the scanner. It's the easiest part of the compiler, but very important. 
Because without it the compiler won't work...

Reference: P32_SCAN.PAS

3.2.3. Pre-processor
The compiler is equipped with a simple pre-processor. Most compiler have a 
pre-processor that analyse the source code before it's scanned. P32 has 
combines the scanner and pre-processor. The pre-processor is in this compiler 
uses for analysing compiler directives. This can be a compiler specific 
option, like $A+ to turn on data alignment or a directive for conditional 
compiling.
For conditional compiling the following directives are supported:
$ifdef, $else, $endif. In the following example you can see that the strings 
that control the compilation of source code are pushed on a virtual stack.

case current_directive of
  _ifdef: begin
            GetToken;
            b:=FindStringName(directive_names, current_string);
            IfPush(b);
            if b=FALSE then EatCode;
          end;
  _else : if IfInverted then LineError(LineCount, 'Error with $ELSE')
          else IfInvert;
  _endif: if IfEmpty then LineError(LineCount, 'Error with $ENDIF')
          else IfPop;
end;

This small routine controls the conditional compiling. See the source code for 
more information.

Reference: P32_PREP.PAS

3.3. Parser

3.4. Optimizer

3.5. Code generator

<more to come>


Appendix A. P32 unit format

The unit header is 32 bytes long, it uses the following structure:

unitstart : record
              id       : array[1..3] of char;	{ P32 }
              brk      : char;			{ #26 }
              version  : word;			{ version number }
              code     : longint;
              symbols  : word;                  { # of symbols }
              types    : word;                  { # of types }
              comp     : boolean;               { is compression enabled? }
              comptype : byte;                  { cur: 0 = none, 1 = rle }
              reserved : array[1..16] of char;
            end;

The unit saving routines use RLE compression to minimize diskspace usage. The
RLE compression is built up like this:

? = Value set as needed.

 Part         Size       Offset       Value
----------------------------------------------
 Header        32          0            ?
  * id          3          0          'P32'
  * brk         1          3           #26
  * version     2          4            6
  * code        4          6            ?
  * symbols     2         10            ?
  * types       2         12            ?
  * comp        1         14          TRUE (or FALSE)
  * comptype    1         15      Current: 0 = none, 1 = rle
  * reserved   16         16      Current: #0#0#0#0...#0#0
 RLEHeader      8         32            ?
  * packs       2         32            ?
  * packsize    2         34            ?
  * reserved    4         36      Current: #0#0#0#0
 RLEDatas       8         40            ?
  * datatype    2         40            ?
  * datacode    1         42            ?
  * datasize    2         43            ?
  * reserved    3         45      Current: #0
    * Data      ?         48            ?
 RLEData        8          ?            ?
  ... x packs


With this RLE compression method, maximum size of an unit file, is 2^32 (4 GB).
Though version 6 uses a packsize of 8192, which limits the size of an unitfile 
to 536870912 bytes. (512 MB)

RLEData.datatype is a word describing the RLE compression method
used. Current implemented:
  0 - Store (no compression at all, just read next RLEPackSize bytes)
  1 - RLE   (usual RLE 8 bit compression)

RLEData.datacode is the escape sequence to signal that something
                 special is coming

DATA Decompression examples:

Magic byte is $ff

Byte in:
 $55 $66 $77 $88
Byte out:
 $55 $66 $77 $88

Byte in:
 $55 $ff $06 $88 $99   (magic,count,value)
Byte out:
 $55 $88 $88 $88 $88 $88 $88 $99

Byte in:
 $ff $00 $66    (magic, count = 0, means store magic)
Byte out:
 $ff $66

Byte in:
 ... (pos RLEPAckSize-1) $ff
Byte out:
 $ff


Appendix B. Assemblers and DOS extenders

The following table shows that assembler and
DOS-extender combinations that are supported
by P32 v0.4.

              -----------------------
             | DOS32 | WDOSX | PRO32 |
    |--------------------------------|
    | TASM   |   x   |   x   |   -   |
    |--------------------------------|
    | NASM   |   ?   |   ?   |   -   |
    |--------------------------------|
    | PASS32 |   -   |   x   |   ?   |
    |--------------------------------|

x supported
- not supported
o under development
? not sure or partially supported

   Note: NASM is not fully supported because it contains some bugs that 
         prevends P32 from using it.

Target: TASM/DOS32
------------------
Required files:
TASM    .EXE  (v3.1 or better)
DLINK   .EXE  (v1.3 or better)
DOS32   .EXE  (v3.3 or better)

TASM.EXE /m3 /t /uT310 <name>

   Note: Repeat this for all units.

DLINK.EXE -t -p <name> <units>

   Note: The executable requires DOS32.EXE to run.

Where to get it:
TASM.EXE from Borland (e.g. BP7 package)
DLINK.EXE and DOS32.EXE from the DOS32V33.ZIP

Debugging:
Use DEBUG.LIB from DOS32V33.ZIP to debug DOS32 executables, you need to add
a line 'call debug' to the main source and you need to add ',,,debug.lib' to
the linker commandline.

Target: TASM/WDOSX
------------------
Required files:
TASM    .EXE  (v3.1 or better)
TLINK32 .EXE
STUBIT  .EXE  (v0.94 or better)

TASM.EXE /m3 /t /uT310 <name>

   Note: Repeat this for all units.

TLINK32.EXE <name> <units>

STUBIT.EXE <result.exe>

Where to get it:
TASM.EXE from Borland (e.g. BP7 package)
TLINK32.EXE from Borland (e.g. TASM 4.0 package)
STUBIT.EXE from WDOSX094.ZIP

Debugging:
Use WUDEBUG.EXE from WDOSX094.ZIP to debug WDOSX executables. you can start
it with WUDEBUG <result.exe>

Target: PASS32/WDOSX
--------------------
Required files:
PASS32  .EXE (v2.1 or better)
WDOSX   .DX  (v0.94 or better)

PASS32.EXE <name> -o -im:<unit>

   Note: PASS32 supports 'smart-linking'!

Where to get it:
PASS32.EXE from PASS32V2.ZIP
WDOSX.DX from STUBIT.EXE (WDOSX094.ZIP), use -extract options to get it.
(you can also download PASSWDX.ZIP from the P32 homepage)

Debugging:
Use WUDEBUG.EXE from WDOSX094.ZIP to debug WDOSX executables. you can start
it with WUDEBUG <result.exe>


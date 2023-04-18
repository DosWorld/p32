{ -------------------------------------------------------------------------- }
{                         P32 - 32bit Pascal Compiler                        }
{ -------------------------------------------------------------------------- }
{                       Johan Prins - p32@cryogen.com                        }
{ ========================================================================== }
{                                                                            }
{                                                         (c) Copyright 1997 }
{                                                                            }
{ -------------------------------------------------------------------------- }
{ MMX unit v0.1, adds MMX and 3DNow! support to the compiler                 }
{ -------------------------------------------------------------------------- }

unit mmx;

interface

type
    {unsigned MMX types}
    mmxbyte     = array[0..7] of byte;
    mmxword     = array[0..3] of word;
    mmxdword    = array[0..1] of dword;
    {signed MMX types}
    mmxshortint = array[0..7] of byte;
    mmxinteger  = array[0..3] of word;
    mmxlongint  = array[0..1] of dword;
    {floating point 3DNow! types}
    {mmxsingle   = array[0..1] of single;}

{ MMX functions without saturation }
procedure mmx_paddb(var m1, m2: mmxbyte);
procedure mmx_paddw(var m1, m2: mmxword);
procedure mmx_paddd(var m1, m2: mmxdword);
procedure mmx_psubb(var m1, m2: mmxbyte);
procedure mmx_psubw(var m1, m2: mmxword);
procedure mmx_psubd(var m1, m2: mmxdword);
procedure mmx_pmulhw(var m1, m2: mmxinteger);
procedure mmx_pmullw(var m1, m2: mmxinteger);
procedure mmx_pmaddwd(var m1, m2: mmxinteger);
procedure mmx_psllw(var m1: mmxword; x: longint);
procedure mmx_pslld(var m1: mmxdword; x: longint);
procedure mmx_psllq(var m1; x: longint);
procedure mmx_psrad(var m1: mmxlongint; x: longint);
procedure mmx_psraw(var m1: mmxlongint; x: longint);

procedure mmx_pand(var m1, m2);
procedure mmx_pandn(var m1, m2);

implementation

{ -------------------------------------------------------------------------- }
{ MMX functions without saturation                                           }
{ -------------------------------------------------------------------------- }

procedure mmx_paddb(var m1, m2: mmxbyte); inline;
{ add unsigned packed 8-bit values }
asm
  movq     mm7, qword ptr[eax]
  paddb    mm7, qword ptr[edx]
  movq     qword ptr[eax], mm7
end;

procedure mmx_paddw(var m1, m2: mmxword); inline;
{ add unsigned packed 16-bit values }
asm
  movq     mm7, qword ptr[eax]
  paddw    mm7, qword ptr[edx]
  movq     qword ptr[eax], mm7
end;

procedure mmx_paddd(var m1, m2: mmxdword); inline;
{ add unsigned packed 32-bit values }
asm
  movq     mm7, qword ptr[eax]
  paddd    mm7, qword ptr[edx]
  movq     qword ptr[eax], mm7
end;

procedure mmx_psubb(var m1, m2: mmxbyte); inline;
{ subtract unsigned packed 8-bit values with wraparound }
asm
  movq     mm7, qword ptr[eax]
  psubb    mm7, qword ptr[edx]
  movq     qword ptr[eax], mm7
end;

procedure mmx_psubw(var m1, m2: mmxword); inline;
{ subtract unsigned packed 16-bit values with wraparound }
asm
  movq     mm7, qword ptr[eax]
  psubw    mm7, qword ptr[edx]
  movq     qword ptr[eax], mm7
end;

procedure mmx_psubd(var m1, m2: mmxdword); inline;
{ subtract unsigned packed 32-bit values with wraparound }
asm
  movq     mm7, qword ptr[eax]
  psubd    mm7, qword ptr[edx]
  movq     qword ptr[eax], mm7
end;

procedure mmx_pmulhw(var m1, m2: mmxinteger); inline;
{ multiply signed packed 16-bit values and store the high 16 bits }
asm
  movq     mm7, qword ptr[eax]
  pmulhw    mm7, qword ptr[edx]
  movq     qword ptr[eax], mm7
end;

procedure mmx_pmullw(var m1, m2: mmxinteger); inline;
{ multiply signed packed 16-bit values and store the low 16 bits }
asm
  movq     mm7, qword ptr[eax]
  pmullw   mm7, qword ptr[edx]
  movq     qword ptr[eax], mm7
end;

procedure mmx_pmaddwd(var m1, m2: mmxinteger); inline;
{ multiply signed packed 16-bit values and add the 32-bit results }
asm
  movq     mm7, qword ptr[eax]
  pmaddwd  mm7, qword ptr[edx]
  movq     qword ptr[eax], mm7
end;

procedure mmx_psllw(var m1: mmxword; x: longint); inline;
{ shift logical left packed 16-bit values, with zero fill from right }
asm
  movq     mm7, qword ptr[eax]
  movd     mm6, edx
  psllw    mm7, mm6
  movq     qword ptr[eax], mm7
end;

procedure mmx_pslld(var m1: mmxdword; x: longint); inline;
{ shift logical left packed 32-bit values, with zero fill from right }
asm
  movq     mm7, qword ptr[eax]
  movd     mm6, edx
  pslld    mm7, mm6
  movq     qword ptr[eax], mm7
end;

procedure mmx_psllq(var m1; x: longint); inline;
{ shift logical left packed 64-bit values, with zero fill from right }
asm
  movq     mm7, qword ptr[eax]
  movd     mm6, edx
  psllq    mm7, mm6
  movq     qword ptr[eax], mm7
end;

procedure mmx_psrad(var m1: mmxlongint; x: longint); inline;
{ shift arithmetic right packed 32-bit values, with sign fill from left }
asm
  movq     mm7, qword ptr[eax]
  movd     mm6, edx
  psrad    mm7, mm6
  movq     qword ptr[eax], mm7
end;

procedure mmx_psraw(var m1: mmxlongint; x: longint); inline;
{ shift arithmetic right packed 32-bit values, with sign fill from left }
asm
  movq     mm7, qword ptr[eax]
  movd     mm6, edx
  psraw    mm7, mm6
  movq     qword ptr[eax], mm7
end;

procedure mmx_pand(var m1, m2); inline;
{ logical AND 64-bit values }
asm
  movq     mm7, qword ptr[eax]
  pand     mm7, qword ptr[edx]
  movq     qword ptr[eax], mm7
end;

procedure mmx_pandn(var m1, m2); inline;
{ invert a 64-bit value, then logical AND 64-bit values in m2 }
asm
  movq     mm7, qword ptr[eax]
  pandn    mm7, qword ptr[edx]
  movq     qword ptr[eax], mm7
end;

procedure mmx_por(var m1, m2); inline;
{ logical OR 64-bit values }
asm
  movq     mm7, qword ptr[eax]
  por      mm7, qword ptr[edx]
  movq     qword ptr[eax], mm7
end;


{ -------------------------------------------------------------------------- }
{ MMX functions with saturation                                              }
{ -------------------------------------------------------------------------- }

end.

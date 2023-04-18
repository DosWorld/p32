unit tinline;

interface

function iSqr(r: double): double;
function iPi: double;
function iArcTan(r: double): double;

implementation

function iSqr(r: double): double; inline;
asm
  fld   st
  fmul
end;

function iPi: double; inline;
asm
  fldpi
end;

function iArcTan(r: double): double; inline;
asm
  fpatan
end;

begin
end.

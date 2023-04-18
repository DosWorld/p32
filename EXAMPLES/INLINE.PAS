program inlineexample;

const MAX=70;

var a : longint;
    b : real;

function pi:double; inline;
asm
  fldpi
end;

procedure inc(var l:longint); inline;
asm
  inc   dword ptr [eax]
end;

begin
  a:=1000
  inc(a);
  writeln(a);

  b:=pi;
  writeln(b);
end;

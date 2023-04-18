program QSort; {Quicksortdemo}

const max=100000;

var
  a: array[0..max] of longint;
  k: longint;

procedure Sort(l, r: longint);
var
  u,i, j, x, y: longint;

begin
  i := l; 
  j := r; 
  x := a[(l+r) div 2];
  repeat
    while a[i] < x do i := i + 1;
    while x < a[j] do j := j - 1;
    if i <= j then
    begin
      y    := a[i];
      a[i] := a[j];
      a[j] := y;
      i := i + 1;
      j := j - 1;
    end;
  until i > j;
  if l < j then Sort(l, j);
  if i < r then Sort(i, r);
end;

begin {QSort}
  Randomize;
  for k := 0 to max do a[k] := Random(100000);
  Write('Sorting longints...');
  Sort(0, max);
  Writeln('done.');
end.

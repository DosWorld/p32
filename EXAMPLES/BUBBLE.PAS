program bubblesortdemo;

const
  MAX = 50;

var
  k,l,i,j:longint;
  a : array[0..MAX] of longint;
  temp : longint;

begin
  k:=0;
  randomize;
  for i:=0 to MAX do a[i] := random(MAX);
  for i:=0 to MAX do write(a[i],' ');writeln;
  writeln('Sorting...');
  for i := 0 to MAX do
    for j := 0 to MAX do
      if a[i]<a[j] then begin
                          temp:=a[i];
                          a[i]:=a[j];
                          a[j]:=temp;
                          k:=k+1;
                        end;
 for i:=0 to MAX do write(a[i],' ');writeln; 
end.

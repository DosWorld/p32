program LittleCrtTest;

uses Crt;

var i, j, inc_i, inc_j : integer;
    ch : char;

procedure Init;
begin
  While KeyPressed do ReadKey;
  ClrScr;
  TextBackground(Blue);
  TextColor(White);
  Randomize;                       
end;

procedure RandomWindows;
var x, y, width, height, clrback, clrfore : byte;
    i : integer;
begin
  for i := 1 to 20 do begin
    width := Random(62)+17;
    height := Random(23)+2;
    x := Random(80-width)+1; 
    y := Random(25-height)+1;
    Inc(width,x);
    Inc(height,y);
    Window(x, y, width, height);
    clrback := Random(White);
    clrfore := Random(White);
    TextBackground(clrback);
    TextColor(clrfore);
    ClrScr;
    Write('Press any key...');
    repeat until KeyPressed;
    while KeyPressed do ReadKey;
  end;
end;

procedure Animate;
begin
  GotoXY(i,j);
  Write('Welcome to P32 Console Apps!!!');
  Delay(50);
  GotoXY(i,j);
  Write('                              ');
  if i >= 50 then inc_i := -1;
  if i <= 1 then inc_i := +1;
  if j >= 25 then inc_j := -1;
  if j <= 1 then inc_j := +1;
  Inc(i,inc_i);
  Inc(j,inc_j);
end;

begin 
  Init;
  RandomWindows;
  Window(1,1,80,25);
  TextBackground(Blue);
  TextColor(White);
  ClrScr;
  i := 1;
  j := 1;
  inc_i := +1;
  inc_j := +1;
  Repeat Animate Until KeyPressed;
end.

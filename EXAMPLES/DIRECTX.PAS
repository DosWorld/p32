program DirectX; { ;) }

var i:longint;

begin
  mem[$B8000]:=65;   {display an 'A'}

  i:=2;
  mem[$B8000+i]:=66; {display a 'B'}

  port[$20]:=$20;    {reset interrupt controller}
  
  i:=100+port[$20];  {read value from interrupt controller and add 100}
end.

{
BRIAN PAPE

>   Go to the library and look up the Sieve of Eratosthenes; it's a very
>interesting and easy method For "finding" prime numbers in a certain
>range - and kinda fun to Program in Pascal, I might add...
}

Program aristophenses_net;
{
 LCCC Computer Bowl November 1992 Team members:
 Brian Pape, Mike Lazar, Brian Grammer, Kristy Reed - total time: 5:31
}

{ 
 Made some changes to compile with P32 
 Johan Prins - jprins@knoware.nl
}

Const
  size = 5000;

Var
  b           : Array [1..size] of Boolean;
  i, j, count : Longint;

begin
  count := 0;
  For i := 1 to size do b[i]:=True;

  For i := 2 to size do
    if b[i]=True then
      begin
        Write(i:10);
        For j := i + 1 to size do
           if j mod i = 0 then
             b[j] := False;
      end;  { For }

  Writeln;

  For i := 1 to size do
    if b[i]=True then
      begin
        Write(i:10);
        count:=count+1;
      end;

  Writeln;
  Write('The number of primes from 1 to ', size, ' is ', count, '.');
end.


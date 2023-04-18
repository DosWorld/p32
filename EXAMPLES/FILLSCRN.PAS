{ writing to video screen, simple but slow}
{ example for BP7 and P32 }

var y, x: longint;

begin
  asm                     {set graphics mode}
     mov ax, $13
     int $10
  end;

  for y:=0 to 199 do      {fill screen}
     for x:=0 to 320 do
        {$IFDEF tp}
        mem[$A000:(y*320)+x]:=random(255);
        {$ELSE}
        mem[$A0000+(y*320)+x]:=random(255);
        {$ENDIF}
  asm                     {wait for keypress}
     mov ax, 1
     int $16
     mov ax, 3            {set text mode}
     int $10
  end;
end.

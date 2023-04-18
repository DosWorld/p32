{ ----------------------------------------------------- }
{ Example for P32 v0.4+ compiler                        }
{ ----------------------------------------------------- }
{ this exaple demonstrate direct access to video memory }
{ and I/O port                                          }
{ ----------------------------------------------------- }

var c, x, y, z : longint;

procedure setrgb( c, r, g, b : byte );
begin
  port[$3c8] := c;   { g'day, this is a probably the most simple version   }
  port[$3c9] := r;   { of fire that you will ever see in pascal. i wrote   }
  port[$3c9] := g;   { the code in pascal so it's slow and choppy, i have  }
  port[$3c9] := b;   { another version in asm. and it's faster. anyways if }
end;                 { you have any critics or question on this code, just }
                     { e-mail me at ekd0840@bosoleil.ci.umoncton.ca. or    }
begin                {              9323767@info.umoncton.ca               }
  randomize;         {  note : I have code for all kinds of stuff (that I  }
  asm   mov ax, $13  {         wrote of course), if you want something     }
        int $10      {         e-mail me (i never get mail), maybe i have  }
  end;               {         what you want.                              }
  for x := 1 to 32 do{                               keith degrÅce         }
  begin              {                               moncton, n.-b. canada }
    setrgb(x,   x*2-1, 0,     0    );
    setrgb(x+32, 63,   x*2-1, 0    );
    setrgb(x+64, 63,   63,    x*2-1);
    setrgb(x+96, 63,   63,    63   );
  end;
  repeat
   x := 0;
   repeat
     y := 60;
     repeat
       {$IFDEF tp}
       c := mem[$A000:(y * 320 + x)] + mem[$A000:(y * 320 + x + 2)];
       c := c + mem[$A000:(y * 320 + x - 2)] + mem[$A000:((y+2) * 320 + x + 2)];
       c := c div 4;
       {$ELSE}
       c := mem[$A0000+(y * 320 + x)] + mem[$A0000+(y * 320 + x + 2)];
       c := c + mem[$A0000+(y * 320 + x - 2)] + mem[$A0000+((y+2) * 320 + x + 2)];
       c := c div 4;
       {$ENDIF}
       if c <> 0 then c:=c-1;
       {$IFDEF tp}
       memw[$A000:((y-2) * 320 + x)] := (c shl 8) + c;
       memw[$A000:((y-1) * 320 + x)] := (c shl 8) + c;
       {$ELSE}
       memw[$A0000+((y-2) * 320 + x)] := (c shl 8) + c;
       memw[$A0000+((y-1) * 320 + x)] := (c shl 8) + c;
       {$ENDIF}
       y:=y+2;
     until y > 202;
     y:=y-2;
     {$IFDEF tp}
     mem[$A000:(y * 320 + x)] := random(160);
     {$ELSE}
     mem[$A0000+(y * 320 + x)] := random(160);
     {$ENDIF}
     x:=x+2;
    until x >= 320;
  until port[$60] < $80;
  asm  mov ax, $3
       int $10
  end;
end.

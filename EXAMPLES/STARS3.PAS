
{ Original STARS.PAS by Daniel D. Bennett }

{ Optimized:
  1. all data types are 32 bit now 
  2. PSet is an inline procedure
  3. XLAT is an inline procedure
}

const 
   numStars = 1200;
 
var
   bufpos  : longint;
   i       : longint;
   starx   : Array[1..numStars] of longint;
   stary   : Array[1..numStars] of longint;
   starz   : Array[1..numStars] of longint;
   staru   : Array[1..numStars] of longint;
   starv   : Array[1..numStars] of longint;
 
 
procedure PSet(x, y : longint; c :longint); inline;
asm  
   lea edx, [edx*4+edx]
   shl edx, 6
   add edx, eax
   add edx, 655360 
   mov byte ptr fs:[edx], cl
end;
 
 
function Xlat( XPos, Distance : longint): longint; inline;
asm
   shl  eax, 8
   mov  edi, edx
   cdq  
   idiv edi
end;
 
function GetBuf : word; assembler;
asm
   mov ax, word ptr fs:[$41C]
end;
 
procedure NewStar(starnum: longint);
begin
   starx[starnum]:=random(200)-100;
   stary[starnum]:=random(200)-100;
   starz[starnum]:=-255;
   staru[starnum]:=0;
   starv[starnum]:=0;
end;
 
 
begin
   bufpos:=GetBuf;
   randomize; 
   for i:=1 to numStars do begin
      NewStar(i);
   end;
   asm  
      mov ax, $13
      int $10
   end;
   for i:=0 to 127 do begin   
      asm
         mov al, i
         mov dx, $3C8
         out dx, al
         inc dx
         shr al, 1
         out dx, al
         out dx, al
         out dx, al
      end;
   end;
   repeat 
      for i:=1 to numStars do begin
         PSet(staru[i],starv[i],0);
         starz[i]:=starz[i]+1;
         if starz[i]=0 then NewStar(i);
         staru[i]:=Xlat(starx[i],starz[i])+160;
         starv[i]:=Xlat(stary[i],starz[i])+100;
         if (staru[i]<0) then NewStar(i);
         if (staru[i]>319) then NewStar(i);
         if (starv[i]<0) then NewStar(i);
         if (starv[i]>199) then NewStar(i);
         PSet(staru[i],starv[i],(starz[i]+255) div 2);
      end;
   until GetBuf<>bufpos;
  
   asm  
      mov ax, $3
      int $10
   end;
end.


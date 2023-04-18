
{ Original STARS.PAS by Daniel D. Bennett }

const 
   numStars = 1200;
 
var
   bufpos : word;
   i       : word;
   starx   : Array[1..numStars] of Integer;
   stary   : Array[1..numStars] of Integer;
   starz   : Array[1..numStars] of Integer;
   staru   : Array[1..numStars] of Word;
   starv   : Array[1..numStars] of Word;
 
 
procedure PSet(x, y : Word; c : Byte); assembler;
asm  
   xor eax, eax
   mov ax, [y]
   lea eax, [eax*4+eax]
   shl eax, 6
   add ax, [x]
   mov bl, [c]
   add eax, 655360 
   mov byte ptr fs:[eax], bl
end;
 
 
function Xlat( XPos, Distance : Integer) : Integer;
begin
   Xlat:=(XPos*256) div Distance;
end;
 
function GetBuf : word; assembler;
asm
   mov ax, word ptr fs:[$41C]
end;
 
procedure NewStar(starnum : word);
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


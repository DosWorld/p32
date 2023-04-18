procedure WriteString(var t: TextRec; var s: string; l: longint); 'writestring';

var left, todo, cnt :longint;
    temp: string;

begin
  l:=l-ord(s[0]);
  if l>0 then 
    begin  
      spaces(l, temp);
      s:=temp + s;
    end

  if t.Mode=fmOutput then
    begin
      todo:=ord(s[0]);
      left:=t.BufSize-t.BufPos;
      cnt:=1;
      if left=0 then
        asm
           mov   eax, dword ptr [t]
           lea   edi, [eax]
           push  edi
           call  [eax+32] {FlushFunc}
        end;
      while todo>left do
        begin
          move(s[cnt], t.BufPtr^[t.BufPos], left);
          t.BufPos:=t.BufPos + left;
          dec(todo, left);
          inc(cnt, left);
          asm {call output function}
             mov   eax, dword ptr [t]
             lea   edi, [eax]
             push  edi
             call  [eax+28] {InOutFunc}
          end;
          left:=t.BufSize-t.BufPos;
        end;
      move(s[cnt], t.BufPtr^[t.BufPos], todo);
      t.BufPos:=t.BufPos+todo;
    end;
end;

program src2def;

uses p32_asm;

var asdef : assemblerdef;

      def : text;
        f : file;

begin
  if paramcount=0 then begin writeln('src2def <name>'); halt(1); end;
  assign(def, paramstr(1)+'.src');
  {$I-}
  reset(def);
  {$I+}
  if ioresult<>0 then begin writeln('Error opening: '+paramstr(1)+'.src'); halt(2); end;
  readln(def, asdef.desc);
  readln(def, asdef.header1);
  readln(def, asdef.header2);
  readln(def, asdef.model);
  readln(def, asdef.stackseg);
  readln(def, asdef.codeseg);
  readln(def, asdef.dataseg);
  readln(def, asdef.udataseg);
  readln(def, asdef.start);
  readln(def, asdef.ends);
  readln(def, asdef.proc);
  readln(def, asdef.endp);
  readln(def, asdef.macro);
  readln(def, asdef.endm);
  readln(def, asdef.align);
  readln(def, asdef.include);
  readln(def, asdef.inc_char);
  readln(def, asdef.byteptr);
  readln(def, asdef.wordptr);
  readln(def, asdef.dwordptr);
  readln(def, asdef.qwordptr);
  readln(def, asdef.tbyteptr);
  readln(def, asdef.jump_prefix);
  readln(def, asdef.offset);
  readln(def, asdef.data1);
  readln(def, asdef.data2);
  readln(def, asdef.data4);
  readln(def, asdef.data8);
  readln(def, asdef.data10);
  readln(def, asdef.valdata1);
  readln(def, asdef.valdata2);
  readln(def, asdef.extern);
  readln(def, asdef.extern2);
  readln(def, asdef.global);
  readln(def, asdef.fpstack);
  close(def);

  assign(f, paramstr(1)+'.def');
  rewrite(f,1);
  blockwrite(f,asdef,sizeof(asdef));
  close(f);
end.

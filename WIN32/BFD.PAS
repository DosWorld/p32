(* BFD.PAS - Public Domain 1998 by Leonardo Humberto Liporati *)

const SCREEN_LINES   = 23;
      BYTES_PER_LINE = 16;
      SIZE_BUFFER    = SCREEN_LINES*BYTES_PER_LINE;
      HexDigits: String[16] = '0123456789ABCDEF';

var FileBuffer: Array [0..SIZE_BUFFER-1] of Byte;
    BinFile: File;
    BytesReaden, IBuf: LongInt;
    CurrentByte: Byte;
    Finished: Boolean;
    AsciiText: String[16];

begin
  Finished:= FALSE;
  If ParamCount <> 1 Then Begin
    Write('Usage: BFD <file path>');
    Halt(1);
  End;
  Assign(BinFile, ParamStr(1));
  Reset(BinFile,1);
  If IOResult <> 0 Then Begin
    Write('Cannot open ',ParamStr(1));
    Halt(2);
  End;
  Repeat
    Write(' 0  1  2  3  4  5  6  7  8  9  ');
    Writeln('A  B  C  D  E  F  -    A S C I I');
    AsciiText:= '                '; { Sixteen spaces }
    BlockRead(BinFile, FileBuffer, SIZE_BUFFER, BytesReaden);
    If BytesReaden < SIZE_BUFFER Then Finished := TRUE;
    For IBuf:= 0 To BytesReaden-1 Do Begin
      CurrentByte:= FileBuffer[IBuf];
      If (IBuf <> 0) and ((IBuf and 15) = 0) Then Begin
        Writeln('- ',AsciiText);
        AsciiText:= '                '; { Sixteen spaces }
      End;
      If CurrentByte < 32 Then 
        AsciiText[(IBuf and 15)+1]:= '.'
      Else AsciiText[(IBuf and 15)+1]:= Char(CurrentByte);
      Write(HexDigits[(CurrentByte shr 4)+1],HexDigits[(CurrentByte and $0F)+1],' '); 
    End;
    Writeln('- ',AsciiText);
    If Finished = FALSE Then Begin
      Write('Strike ENTER to continue...');
      Readln;
    End;
  Until Finished;
  Close(BinFile);
  Writeln;
  Write('BFD - Binary File Dumper - ');
  Write('Public Domain 1998 by Leonardo Humberto Liporati');
end.

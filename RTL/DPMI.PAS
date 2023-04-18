{                         P32 - 32bit Pascal Compiler                        }
{ -------------------------------------------------------------------------- }
{                       Johan Prins - jprins@knoware.nl                      }
{ ========================================================================== }
{                                                                            }
{ DPMI-unit v0.1                                                             }
{                                                    (c) Copyright 1998-1999 }
{                                                                            }
{ -------------------------------------------------------------------------- }
{ Unit written by Thomas A.O. Steen, TNSe@hotmail.com                        }
{ -------------------------------------------------------------------------- }


Unit DPMI;

Interface

Type
 DosMem = Record
           Segment :Word;
           Offset  :Word;
           Selector:Word;
           Size    :Word;
          end;

{ Functions in this unit;
}

Function  GetDosMem(var DM:DosMem; Size:DWord):Boolean;
-- GetDosMem(DM,Size)
--        Gets SIZE BYTES(!) of memory in REAL mode for transfers
--        Returns TRUE if successfull, FALSE if it fails.

Procedure FreeDosMem(var DM:DosMem);
-- FreeDosMem(DM)
--        Frees up previously allocated memroy in REAL mode.

Function  MapPhysicalToLinear(Where,Size:DWord):DWord;
-- MapPhysicalToLinear(Where,Size);
--        Maps Physical memory (aka: Video card's LFB, Weitek CPU's and
--        other devices with memory outside the usual 1M REAL memory)
--        to a LINEAR 32bit Address, for use with the MEM, MEMW or MEMD
--        commands. SIZE is the size of the adressable memory.
--        WARNING! It should NOT be used to map ANYTHING INSIDE the
--        1M REAL MODE MEMORY! (You was warned!)

Procedure UnMapLinearAddress(Where:DWord);
-- UnMapPhysicalAddress(Where)
--        Undoes a MapPhysicalToLinear. WHERE is the LINEAR address
--        returned by MapPhysicalToLinear.


Procedure MoveToDos(var Source; var DM:DosMem; HowMuch:DWord);
-- MoveToDos(Source,DM,HowMuch)
--        Moves the specified amount of BYTES from PROTECTED mode to
--        REAL mode, so that INTERRUPTS or other CALLS can access
--        the data transferred. If the Selector is 0, it will use
--        FS as selector, and SEGMENT:OFFSET in DosMem as transfer area.

Procedure MoveFromDos(var DM:DosMem; var Dest; HowMuch:DWord);
-- MoveFromDos(DM,Dest,HowMuch)
--        Moves the specified amount of BYTES back from REAL mode to
--        PROTECTED mode, so that your program can manage it without
--        using selectors. If the Selector is 0, it will use FS as
--        selector, and use SEGMENT:OFFSET in DosMem as transfer area.


Implementation

Uses Dos;       -- Registers

var
 RMRegs:Registers;

Function  GetDosMem(var DM:DosMem; Size:DWord):Boolean;
begin
 DM.Segment  := 0;
 DM.Offset   := 0;
 DM.Selector := 0;
 DM.Size     := 0;      -- zero out all the stuff
 asm
  mov ecx,DWord Ptr [DM]

  mov eax,$100          -- Get DOS Real memory
  mov ebx,DWord Ptr [Size]
  add ebx,15            -- round it off to nearest whole
  shr ebx,4             -- Size/16, since DOS memory is alloc'd in Paras
  mov Word Ptr [ecx+6],bx -- save the size of this block
  int $31               -- execute it
  jc @Error

  mov Word Ptr [ecx+0],ax       -- save the real mode segment of alloc'd block
  mov Word Ptr [ecx+4],dx       -- also save the selector
 @Error:
 end;

 If (DM.Selector = 0) OR (DM.Segment = 0) then
  GetDosMem := FALSE     -- failed
 else
  GetDosMem := TRUE;     -- success

end;

Procedure FreeDosMem(var DM:DosMem);
begin
 If (DM.Selector = 0) OR (DM.Segment = 0) OR (DM.Size = 0)
  then exit;    -- error! not allocated! (could be manually made)

 asm
  mov ecx,DWord Ptr [DM]

  mov eax,$101              -- Free DOS real memory
  mov dx,Word Ptr [ecx+4]   -- the selector
  int $31
 end;
end;

Function  MapPhysicalToLinear(Where,Size:DWord):DWord; assembler;
asm
 mov ebx,DWord Ptr [Where]
 mov ecx,ebx
 shr ebx,16                     -- now bx:cx Points to the Physical address

 mov esi,DWord Ptr [Size]
 mov edi,esi
 shr esi,16                     -- now si:di is the Region Size

 mov ax,$800
 int $31
 jc @Damnit                     -- Ok... so it fucked again

 shl ebx,16
 mov bx,cx
 mov eax,ebx                    -- now eax contains the Linear memory
 jmp @DoneHere

@Damnit:
 xor eax,eax                    -- Return with nil
@DoneHere:
end;

Procedure UnMapLinearAddress(Where:DWord); assembler;
asm
 mov ebx,DWord Ptr [Where]
 mov ecx,ebx
 shr ebx,16                     -- now bx:cx Points to the Linear address

 mov ax,$801
 int $31                        -- free it, don't care if it errors really
end;


Procedure MoveToDos(var Source; var DM:DosMem; HowMuch:DWord); assembler;
asm
 mov esi,DWord Ptr [Source]
 mov ecx,DWord Ptr [HowMuch]
 mov edx,ecx
 mov eax,DWord Ptr [DM]
 cld				-- clear direction flag
 shr ecx,2
 xor edi,edi
 xor ebx,ebx
 push es

 mov di,Word Ptr [eax+2]        -- The DOS offset
 mov bx,Word Ptr [eax+4]        -- Get the selector
 or ebx,ebx                     -- is the selector 0?
 jnz @CopyToDos

 mov bx,Word Ptr [eax]          -- Get real mem segment
 shl ebx,4                      -- *16
 add edi,ebx                    -- now edi points to a linear dos area
 mov bx,fs                      -- use fs as selector

@CopyToDos:
 mov es,bx                      -- Use the selector
 rep
 movsd                          -- Copy 'em bytes
 and edx,3
 jz @Finished
 mov ecx,edx
 rep
 movsb                          -- move the 1-3 last bytes
@Finished:
 pop es
end;

Procedure MoveFromDos(var DM:DosMem; var Dest; HowMuch:DWord); assembler;
asm
 mov edi,DWord Ptr [Dest]
 mov ecx,DWord Ptr [HowMuch]
 mov edx,ecx
 mov eax,DWord Ptr [DM]
 cld				-- clear direction flag
 shr ecx,2
 xor esi,esi
 xor ebx,ebx
 push ds


 mov si,Word Ptr [eax+2]        -- The DOS Real mode offset
 mov bx,Word Ptr [eax+4]        -- Get the Selector
 or ebx,ebx                     -- is the selector 0?
 jnz @CopyFromDos               -- no, then do the copy

 mov bx,Word Ptr [eax]          -- Get the real segment
 shl ebx,4                      -- *16
 add esi,ebx                    -- now esi points to the linear dos area
 mov bx,fs                      -- and use fs as selector

@CopyFromDos:
 mov ds,bx                      -- Use the correct selector
 rep
 movsd
 and edx,3
 jz @Finished
 mov ecx,edx
 rep
 movsb
@Finished:
 pop ds
end;

begin
end.
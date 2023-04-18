{                         P32 - 32bit Pascal Compiler                       }
{ ------------------------------------------------------------------------- }
{                       Johan Prins - jprins@knoware.nl                     }
{ ========================================================================= }
{ CPU Checker                                                               }
{                                                  (c) Copyright 1996-1999  }
{ V1.15 by TNSe@hotmail.com                                                 }
{                                                                           }
{Changes since version 1.00                                                 }
{ V1.10 1999/01/06                                                          }
{  FPU detection bug (Thanx to paweltanski@hotmail.com)                     }
{  Small bugs fix, Some CPU names revised (K6-2 3dnow+ = K6-3 ;)            }
{ V1.11 1999/01/09                                                          }
{  I'm worse than M$ (Thanx again to paweltanski@hotmail.com)               }
{  Moved some code and variables, revised CPU names                         }
{ V1.12 1999/01/09                                                          }
{  Added CPU timing for CPUs with RDTSC                                     }
{ V1.13 1999/02/21                                                          }
{  Revised some CPU names (K6-3 = K6-III)                                   }
{ V1.14 1999/03/07                                                          }
{  Fixed yet another annoying bug, thanx to tanski@polbox.com               }
{ V1.15 1999/03/08                                                          }
{  Some more revisions                                                      }
{ V1.16 1999/03/16                                                          }
{  And yet some more revisions. Added support for detecting SSE (The new    }
{  Intel opcodes, IA MMX-2                                                  }
{ V1.17 1999/03/30                                                          }
{  Added support for detection of the Rise mP6!                             }
{  Added support for detection of the PSN (Processor Serial Number)         }
{  Added support for detection the P-III series of CPUs                     }
{  Added support for detection of the AMD K6-III                            }
{ ------------------------------------------------------------------------- }


{
 --- CPU Finder by Thomas Steen, TNSe@hotmail.com ---


If you can verify the detection of the CPUs
listed as Uncertain or not tested, !PLEASE! contact me.
If you see any Bugs ------------------/ OK?
If one doesn't work -----------------/


     CPU           Detection
----------------------------------
  086           : not implemented
  186           : not implemented
  286           : Uncertain
  386           : Uncertain (Does anyone have one of these still?)
  486           : Tested, Works

  Pentium       : Tested, Works
  Pentium MMX   : Tested, Works (btw; will detect Pen2 as PenMMX?)
  Pentium PRO   : Tested, Works
  Pentium 2     : Tested, Works
  Pentium 2 Cel : Uncertain
  Pentium 2 CelA: Tested, Works
  Pentium 2 Xeon: Uncertain
  Pentium III   : Uncertain
  Pen III Xeon  : Uncertain
  Pentium 2+++  : Prolly detected as either MMX or Pen2.

  am486 Enhanced: Tested, Works
  AMD K5        : not tested
  AMD K6        : Tested, Works
  AMD K6-2      : Tested, Works
  AMD K6-2 XT   : Tested, Works
  AMD K6-III    : Not Tested, but should work...

--- Cyrix detection is in general uncertain... Since they need CPUID to
    be turned on .. (dang..)
  Cyrix 5x86    : Uncertain
  Cyrix MediaGX : Uncertain
  Cyrix 6x86    : Uncertain
  Cyrix 6x86 MX : Works...
  Cyrix MGX MMX : Uncertain
  Cyrix EMMX    : Uncertain (=MediaGX MMX????)

  UMC           : not tested

  WinChip       : Tested, Works
  WinChip 3DNOW : Tested, Works

  NexGen 5x86   : not tested

  Rise mP6      : not tested

To be added:
  Pentium 2 Klamath  : Pentium 2 233-333Mhz (2.8v core)
  Pentium 2 Deschutes: Pentium 2 350-450Mhz (2.0v core)
  Pentium 2 Mendocino: The Mobile PII
  Pentium Cel. Socket: The socket 370 version of the Celeron
  Pentium 2 Xena     : The BIG server CPU
---
   Ok, so Intel hit the big one, and renamed something that was
   recognized. They renamed KNI to Streaming SIMD and did a lot of other
   strange things. Never trust Intel Inside. They won't do what you expect.

  Pentium III Klamath: KNI. The Win98 killer. DO NOT BUY ONE!
  Pentium Coppermine : KNI, 0.18my & Made of Copper! Geez.
  Intel Merced       : 64bit x86. Wow. Can't wait!

  K7                 : (And K7-2, K7-3 ? ;)

  Cyrix Cayenne      : Hot!
  Cyrix Jalape¤o     : Also Hot... But only because of their names!
  Cyrix Jedi         : Now what? Try getting the AMD hint! (Not so damn many names)

  Rise mP4           : Interesting chip from Rise.

Please e-mail me if you can verify that these works (or verify that they
 do NOT work :)  ...

}

{$G+,E-,N+}

Unit P32_CPUF;

Interface

Procedure CheckUpCPU;
Function  CPUMhz:Word; { Oh no... This program will mess up when CPU's are
                         faster than 64Ghz!!!! }

Type
 CPUs = (IllegalCPU,
         i086,
         i186,
         i286,
         i386,
         i486,
         i586,
         i586mmx,
         i686,
         i786,
         i886,
         i986,
         pentium,
         pentiumpro,
         pentiummmx,
         pentium2,              { Hmm.. think I gotta look at the cache info }
         pentium2celeron,       { with these two ... Detection uncertain }
         pentium2celeronA,
         pentium2Xeon,          { WtF? another from Intel? }
         pentiumiii,            { Argh.. Intel does it again }
         pentiumiiiceleronA,    { Hasn't come yet. prolly will }
         pentiumiiixeon,        { Boring boring Intel }
         pentiumUnknown,
         am486,
         amdk5,
         amdk6,
         amdk6_2,
         amdk6_2xt,
         amdk6_III,
         cyrix5x86,     { should be detected :) }
         cyrixmediagx,  { actually Cyrix Gx86 }
         cyrix6x86,     { actually Cyrix M1 }
         cyrix6x86mx,   { actually Cyrix M2 }
         cyrixmediagxmmx, { actually Cyrix EMMX????????? }
         cyrixemmx,       { why is Cyrix using different names all the time?? }
         umc,
         centaur,               {?????}
         centaur3dnow,
         nexgen,
         risemp6,
         risemp4);

Const
 CPUCompatability:Array[CPUs] of CPUs = (
  IllegalCPU,
  i086,
  i186,
  i286,   { Use this list to see what CPUs the found CPU is }
  i386,   { compatible with ... Some oddities may be found }
  i486,
  i586,
  i586mmx,
  i686,   { 'K6', 'PII', '6x86' is really an i686, Thank Intel for this mess }
  i786,   { 'Klamath' + 'K7' ? }
  i886,   { 'Merced'(I will guess ;) }
  i986, { Called "future expansion" slots :) }
  i586,
  i686,
  i586mmx,
  i586mmx,
  i586mmx,
  i586mmx,
  i686,   { pen2 Xeon }
  i586mmx,
  i586mmx,
  i586mmx,
  i586mmx,
  i486,
  i486,
  i586mmx, { The happy K6 family: }
  i586mmx,
  i586mmx,
  i586mmx,
  i486,
  i486, { or is it a 586? }
  i586,
  i586mmx,
  i586mmx,
  i586mmx,
  i586,
  i586mmx,
  i586mmx,
  i586,
  i586mmx,
  i586mmx);



 CPUTypes:Array[CPUs] of String[60] =
            ('ERROR!',
             '086',
             '186',
             '286',
             '386',
             '486',
             'Unknown 586',
             'Unknown 586',
             'Unknown 686',
             'Unknown 786',
             'Unknown 886',
             'Unknown 986',
             'Intel Pentium',
             'Intel Pentium Pro',
             'Intel Pentium MMX',
             'Intel Pentium 2',
             'Intel Celeron',
             'Intel Celeron A',
             'Intel Pentium Xeon',
             'Intel Pentium III',
             'Intel Pentium III Celeron A',
             'Intel Pentium III Xeon',
             'Intel Unknown (MMX Support)',
             'am486 Enhanced or Am5x86',
             'AMD K5',
             'AMD K6',          { These aren't really needed, as the K6's }
             'AMD K6-2 3DNOW!', { have their own CPUID, which returns the name }
             'AMD K6-2 XT 3DNOW!',
             'AMD K6-III 3DNOW!',
             'Cyrix 5x86',   { will be detected as a 486 }
             'Cyrix MediaGX',
             'Cyrix 6x86',
             'Cyrix 6x86MX',
             'Cyrix MediaGX MMX Enhanced',
             'Cyrix EMMX',  { not detected yet }
             'UMC 586 (if you have one... E-mail me at TNSe@hotmail.com :)',
             'Centaur WinChip MMX',
             'Centaur WinChip 3DNOW!',
             'NexGen 586 (if you have one... E-mail me at TNSe@hotmail.com :)',
             'Rise mP6',
             'Rise mP4');


Type
 ByteArray = Array[1..16] of Byte;

var
 SSESupport, MMXSupport, FPUSupport,S3DNOW,CMOVSupport,RDTSCSupport:Boolean;
 PSNSupport:Boolean;
 ExtendedCapabilities,Capabilities:LongInt;
 MoreCapabilities:ByteArray;

 CPUType:String;
 CPUt:CPUs;


Const
 YESNO:Array[Boolean] of String[3] = ('No','Yes');

Implementation

Procedure CheckUpCPU;

var
 LocalCPUt:CPUs;
 id:String[12];
 cpuinfo,compat,extcompat:LongInt;
 moreinfo:ByteArray;
 LocalFPUSupport:Boolean;
 model,stepping,family,res:Byte;
 ExtName:Array[1..48] of Char;
 X:Word;

label
 CPUFound;

begin
 FillChar(ExtName,SizeOf(ExtName),#00); { clear it out, just in case }
 model := 0;
 stepping := 0;
 family := 0;
 res := 0;
 For x := 1 to 4 do
  begin
   moreinfo[x] := 0;
   MoreCapabilities[x] := 0;
  end;

 extcompat := 0;
 compat := 0;
 cpuinfo := 0;
 LocalFPUSupport := FALSE;
 LocalCPUt := IllegalCPU;

 asm
  push ds
  push ss
  pop ds                { make ds = ss, or lotsa strange things will hap }
  mov dx,$22
  mov al,$e8
  out dx,al             {This enables the CPUID flag of Cyrixes}
  in al,dx              {Should have no effect on other CPUs}
  in al,dx
  in al,dx
  in al,dx
  in al,dx
  in al,dx              {wait for 5 or 6 clock cycles}
  inc dx
  in al,dx
  or al,128             {bit 7 on}
  out dx,al             {put bit 7 on, CPUID on Cyrixes enabled }

  mov ax,5657h
  fninit                {initialize FPU}
  fnstsw ax             {store status word, does nothing if FPU isn't present}
  cmp ax,5657h          {Lack of FPU will result in ax being unchanged}
  je @No_FPU

  mov LocalFPUSupport,TRUE   {got the FPU support...}

@No_FPU:
  pushf
  pop ax
  test ax,ax
  jns @286orBetter      { 286 Check, to avoid a "Crash", sorta... }

  mov LocalCPUt,i286
  jmp @Processor_Found

@286orBetter:
  db $66; pushf         {pushaf}
  db $66; pop ax        {pop eax}
  db $66; or ax,0; dw 32 {or eax,bit 21 = CPUID Support}
  db $66; push ax       {push eax}
  db $66; popf          {popaf}
  db $66; pushf         {pushaf}
  db $66; pop ax        {pop eax}
  db $66; test ax,0; dw 32 {test eax,bit 21}
  jnz @CPUIdSupport

  mov LocalCPUt,i386    {It is atleast a 386}

  db $66; pushf         {pushaf}
  db $66; or ax,0; dw 4 {or eax,bit 18 (Align Flag), exists only on 486's+}
  db $66; push ax       {push eax}
  db $66; popf          {popaf}
  db $66; pushf         {pushaf}
  db $66; pop ax        {pop eax}
  db $66; popf          {popaf}
  db $66; test ax,0; dw 4 {test eax,bit 18}
  jz @is386
{ This code was actually NOT ripped! Think of my surprise
  when finding it on Cyrix's and AMD's Homepage :}

  mov LocalCPUt,i486    {It is atleast a 486, checking stops here,
                         since rest support CPU id!}
@is386:
  mov ax,5              { wooow .. .standard 16 bit code :) }
  mov bx,2
  sahf                  { clear flags }
  div bl                { do the 5 div 2 check  ??? = See Cyrix ... :)}
  lahf
  cmp ah,2
  jne @Processor_Found  { Well. .. it wasn't a Cyrix5x86! }

  mov CPUt,cyrix5x86

@Processor_Found:
  pop ds
  jmp CPUFound          {It doesn't support CPUID }

@CPUIdSupport:
  db $66; xor ax,ax     {xor eax,eax}
  db $0f,$a2            {cpuid, get VendorInfo}
  lea si,id
  mov byte ptr[si],12
  inc si
  db $66; mov [si+0],bx {mov [si+0],ebx}
  db $66; mov [si+4],dx {mov [si+4],edx}
  db $66; mov [si+8],cx {mov [si+8],ecx}
  push ax

  db $66; mov ax,1; dw $0000 {mov eax,1}
  db $0f,$a2                 {cpuid}
  lea si,cpuinfo
  db $66; mov [si],ax        {mov [si],eax}
  lea si,compat
  db $66; mov [si],dx        {mov [si],edx}

  pop ax
  cmp ax,1
  jbe @No0000_0002Support

  db $66; mov ax,2; dw $0000;      { mov eax, $0000_0002 }
  db $0f,$a2
  lea si,moreinfo
  db $66; mov [si+$00],ax              { mov [si+00],eax }
  db $66; mov [si+$04],bx              { mov [si+04],ebx }
  db $66; mov [si+$08],cx              { mov [si+08],ecx }
  db $66; mov [si+$0c],dx              { mov [si+0c],edx }

@No0000_0002Support:
  db $66; mov ax,0; dw $8000;      { mov eax, $8000_0000 }
  db $0f,$a2                       { cpuid }
  db $66; cmp ax,4; dw $8000;      { cmp eax, $8000_0004 }
  jb @Ejectme


  db $66; mov ax,1; dw $8000;      { mov eax, $8000_0001 }
  db $0f,$a2                       { cpuid }
  lea si,extcompat
  db $66; mov [si],dx              { mov [si],edx }

  lea si,ExtName
  db $66; mov ax,2; dw $8000;      { mov eax, $8000_0002 }
  db $0f,$a2
  db $66; mov [si+00],ax           { mov [si+00],eax }
  db $66; mov [si+04],bx           { mov [si+04],ebx }
  db $66; mov [si+08],cx           { mov [si+08],ecx }
  db $66; mov [si+12],dx           { mov [si+12],edx }
  add si,16
  db $66; mov ax,3; dw $8000;      { mov eax, $8000_0003 }
  db $0f,$a2
  db $66; mov [si+00],ax           { mov [si+00],eax }
  db $66; mov [si+04],bx           { mov [si+04],ebx }
  db $66; mov [si+08],cx           { mov [si+08],ecx }
  db $66; mov [si+12],dx           { mov [si+12],edx }
  add si,16
  db $66; mov ax,4; dw $8000;      { mov eax, $8000_0004 }
  db $0f,$a2
  db $66; mov [si+00],ax           { mov [si+00],eax }
  db $66; mov [si+04],bx           { mov [si+04],ebx }
  db $66; mov [si+08],cx           { mov [si+08],ecx }
  db $66; mov [si+12],dx           { mov [si+12],edx }

@Ejectme:
  pop ds

 end;

 ExtendedCapabilities := ExtCompat;
 Capabilities := Compat;
 MoreCapabilities := Moreinfo;

 Stepping := cpuinfo AND $0f;
 model    := (cpuinfo shr 4) AND $0f;
 family   := (cpuinfo shr 8) AND $0f;
 res      := (cpuinfo shr 12) AND $0f;

 CPUt := CPUs(family);

 FPUSupport   := (   compat AND (1 shl 00) <> 0);
 MMXSupport   := (   compat AND (1 shl 23) <> 0);
 SSESupport   := (   compat AND (1 shl 25) <> 0);
 CMOVSupport  := (   compat AND (1 shl 15) <> 0);
 RDTSCSupport := (   compat AND (1 shl 04) <> 0);
 PSNSupport   := (   compat AND (1 shl 18) <> 0);
 S3DNOW       := (extcompat AND (1 shl 31) <> 0);

  If (id = 'GenuineIntel') then
   begin
    If (MMXSupport) then
     CPUt := pentiummmx
    else
     CPUt := pentium;

    If (moreinfo[1] = $01) then
     begin
      For x := 2 to 16 do
       Case moreinfo[x] of
        $00:;
        $01:; { Could be used to show additional info }
        $02:; { Coming laters ... }
        $03:;
        $04:;
        $06:;
        $0A:;
        $40:CPUt := pentium2Celeron; { No cache on this kid }
        $41:CPUt := pentium2CeleronA; { CeleronA has 128k L2 cache }
        $42:CPUt := pentiumPro;   { Only PenPro with 256kb L2 cache. }
                                  { Might we see a Pen3 with 256k L2 cache? }
        $43:CPUt := pentium2;     { 512mb L2 cache, "normal" pen2 }
        $44:CPUt := pentium2Xeon; { 1Mb L2 cache, XEON }
        $45:CPUt := pentium2Xeon; { 2Mb L2 cache XEON (Xena?) }
       end;
      If (SSESupport) AND (CPUt = pentium2) then CPUt := pentiumIII;
      If (SSESupport) AND (CPUt = pentium2CeleronA) then CPUt := pentiumIIICeleronA;
      If (SSESupport) AND (CPUt = pentium2Xeon) then CPUt := pentiumIIIXeon;
     end;
   end;

  If (id = 'AuthenticAMD') then
   begin
    If (MMXSupport) then
     Case model of
      6,7:CPUt := amdk6;
      8  :Case Stepping of
           12:CPUt := amdk6_2xt;
           else CPUt := amdk6_2;
          end;
      9  :CPUt := amdk6_iii;
      else CPUt := amdk6;
     end
    else
     begin
      If (Family = 4) then CPUt := am486 else CPUt := amdk5;
      { hrrm... confusius }
     end;
   end;

  If (id = 'CyrixInstead') then
   begin
    If (MMXSupport) then
     If (family = 5) then CPUt := cyrixmediagxmmx
     else CPUt := cyrix6x86mx   { family = 6 }
    else If (family = 4) then CPUt := cyrixmediagx
         else CPUt := cyrix6x86;
   end;

  If (id = 'UMC UMC UMC ') then
   begin
    CPUt := umc;        { Are they alive? }
   end;

  If (id = 'NexGenDriven') then
   begin
    CPUt := nexgen;     { Couldn't find their Homepage!!!! }
   end;                 { Duhh.. no wonder, AMD K6 = NexGen 6x86!!!! }

  If (id = 'CentaurHauls') then
   begin
    If (S3DNOW) then CPUt := centaur3dnow
    else CPUt := centaur;
   end;

  If (id = 'RiseRiseRise') then
   begin
    CPUt := RisemP6;
   end;

CPUFound: ;

 If (LocalCPUt <> IllegalCPU) then CPUt := LocalCPUt;
 If (LocalFPUSupport) then FPUSupport := TRUE;

 CPUType := CPUTypes[CPUt];
 If (CPUt in [i586..i986]) then CPUType := CPUType + '"' + id + '"';
 { the unknown CPUs }

 If (ExtName[1] <> #00) then
  begin
   CPUType := ExtName;
   For x := 1 to 48 do
    If (ExtName[x] = #00) then break;
   CPUType[0] := Chr(x);
  end;

 If ((res AND 1) = 1) then CPUType := CPUType+' Overdrive';
 If ((res AND 2) = 2) then CPUType := 'Dual '+CPUType;
   { Hmm.. Does it exist Dual Pentium Overdrive??? I guess no.. damn ;}
   { Though, I would like to see Dual AMD K6-2 XT 3DNOW! Overdrive ;}

end;

Function GetMhz:Word;
var
 x:Word;
 l:LongInt;
begin
   x := Seg0040;
  asm
   push ds
   mov ds,word ptr [x]

   db $66; mov di,word ptr [$6c]   { mov edi,dword ptr ds:[$6c] }
   db $66; inc di                  { inc edi }
  @Wait_Eq:
   db $66; cmp di,word ptr [$6c]   { cmp edi,dword ptr ds:[$6c] }
   ja @Wait_Eq

   db $66; inc di                  { inc edi }
   db $0f,$31                      { RDTSC }
   db $66; push ax                 { push eax }
   db $66; push dx                 { push edx }
  @Second_Wait:
   db $66; cmp di,word ptr [$6c]   { cmp edi,dword ptr ds:[$6c] }
   ja @Second_Wait { hehe }

   db $0f,$31                      { RDTSC }
   db $66; pop bx                  { pop ebx }
   db $66; pop cx                  { pop ecx }
   db $66; sub ax,cx               { sub eax,ecx }
   db $66; sbb dx,bx               { sbb edx,ebx }
   pop ds
   db $66; mov word ptr [l],ax     { mov dword ptr [l],eax }
  end;

  GetMhz := Trunc((l * 18.2)/ 1000000);

end;

Function CPUMhz:Word;
var
 Cur:Word;
begin
 Repeat
  Cur := GetMhz;
 Until (Cur = GetMhz);
CPUMhz := Cur;
end;


begin
end.
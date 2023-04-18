{                         P32 - 32bit Pascal Compiler                       }
{ ------------------------------------------------------------------------- }
{                       Johan Prins - jprins@knoware.nl                     }
{ ========================================================================= }
{ Optimize Register Usage MK3. (Virtual Machine/Optimizer)                  }
{                                                  (c) Copyright 1996-1999  }
{ V0.11 by TNSe@hotmail.com                                                 }
{                                                                           }
{Changes since version 0.00                                                 }
{ V0.01 - 1999-02-21                                                        }
{   Work started. I know this can be hard to pull off. But noone will say   }
{   that I did not try. If this unit comes through (true ;), P32 will       }
{   produce code so optimized that I will stop hand-optimizing.             }
{   Just will not be worth hand-optimizing the code that isn't optimized.   }
{   Hopefully, by version 1.00, no bugs will be left. (P32v05 final)        }
{                                                                           }
{ V0.02 - 1999-02-22                                                        }
{   The Dependency checker project started. The function that checks for    }
{   dependencies using the table made yesterday has been created. Hope it   }
{   works as hoped (The _big_ table).                                       }
{                                                                           }
{ V0.03 - 1999-03-09                                                        }
{   Big pause... Trying to sort out my mind of what I might need            }
{   to pull this off... Getting closer to solution... So what did I add in  }
{   this version? Got it working, but no smart jump optimizer tree yet      }
{                                                                           }
{ V0.04 - 1999-03-10                                                        }
{   Killed some bugs, modified the _big_ table... Nahh.. nothing else ...   }
{                                                                           }
{ V0.05 - 1999-03-16                                                        }
{   Killed buggis majoris. I forgot to set the _Branch flag on JMP....      }
{   Added check for Inline code...                                          }
{                                                                           }
{ V0.06 - 1999-03-18                                                        }
{   Rewrote the implied replacer a tad. a bit more easy to understand now ..}
{                                                                           }
{ V0.07 - 1999-03-22                                                        }
{   Whacked some nasty bugs. Where _do_ they come from??? I dunno???        }
{                                                                           }
{ V0.10 - 1999-03-23                                                        }
{   Added the MemoryLoadOptimizerMk1, very pre-beta-test-version            }
{                                                                           }
{ V0.11 - 1999-03-26                                                        }
{   Whacked some nasty bugs. Where _do_ they come from??? I dunno???        }
{                                                                           }
{ V0.12 - 1999-03-27,28 and 29.                                             }
{   Went looking for a bug that wasnt located in this file. The problem     }
{   was my though... Incorrect optimizing order. The LowLevels should be    }
{   run BEFORE this optimizer ;)                                            }
{   Also made the OptimizeMemoryLoads a couple of megabits better           }
{                                                                           }
{ V0.13 - 1999-03-30.                                                       }
{   Well.... Lets see.... the memload optimizer is working!                 }
{ ------------------------------------------------------------------------- }

Unit P32_ORS3;

{ $DEFINE debug}
{ $DEFINE chatty}
{ $DEFINE littlechat}
{ $DEFINE chattype3}

Interface

Uses P32_asm, P32_asml;

Procedure OptimizeRegisterUsageMK3(var a:tAsmList);

(* This works, but has no effect yet. Will it ever? uuhh... seems so ;*)
Procedure OptimizeMemoryLoads(var a:tAsmList);


Implementation

Uses P32_code, P32_symb, P32_cpuf, P32_scan;

{ ------------------------------------------------------------------------- }
{ Here are the look up tables for opcodes                                   }
{ By modifying/adding a table, you can optimize/generate rules for a        }
{ certain CPU. The tables included should be Pentium (MMX) & AMD K6.        }
{ Hopefully I will be able to implement Pentium2 (&3) later. Hope guys!     }
{ Also implemented should be a 486 table, but since no RegisterOptimizing   }
{ is possible with those cuties, why bother?                                }
{ ------------------------------------------------------------------------- }

Type
{ Define flags, use bitfields for ease }
 _Flags = Set Of (_Carry, _Parity, _Adjust, _Zero, _Sign, _Trap, _Interrupt, _Direction, _Overflow);

Const
 _AllFlags = [_Carry, _Parity, _Adjust, _Zero, _Sign, _Trap, _Interrupt, _Direction, _Overflow];
 _FlACOPSZ = _AllFlags - [_Trap, _Interrupt, _Direction];
 _FlAOPSZ  = _AllFlags - [_Trap, _Interrupt, _Direction, _Carry];

Type
{ Define Registers, also use bitfields here. WAY smarter huh? }
 _Regs = Set of (eax_, ebx_, ecx_, edx_, esi_, edi_, ebp_, esp_,
                 cs_, ds_, es_, fs_, gs_, ss_, impl_, impr_, impm_);

Const
 _AllRegs = [eax_, ebx_, ecx_, edx_, esi_, edi_, ebp_, esp_];

Type
 _UVPipe = Set of (_NP, _PU, _PV, _UV, _FPUP, _pairFPUP, _noMMXP, _MMXPU, _MMXPV);
 _XYPipe = Set of (_noXY, _X, _Y, _XY, _FPUA, _noMMXA, _MMX1A, _MMX2A);
 _Pen2Pipe = Set of (_noPen2, _p1, _p2, _p3, _pA, _FPUP2, _pairFPUP2, _noMMXP2, _MMXP2U, _MMXP2V);
              { The horardrim P2 (and PPro) has 3 pipelines,
                p1 = the 4 cycle executor.
                p2 = the 1st 1 cycle executor
                p3 = the 2nd 1 cycle executor
                pA = Who carez, just drop it down one of them }

 _Specials = Set of (_Branch, _Push, _Pop, _Multiply, _Rep, _FPUOp, _JustSpecial);

 _OpCod  = Record
            _RegUse:_Regs;      { The regs that are used in this opcode }
            _RegSet:_Regs;      { The regs that are set in this opcode }
            _FlUse:_Flags;      { The flags that are used in this opcode }
            _FlSet:_Flags;      { The flags that are set in this opcode }

            _Cycles:Byte;       { Cycles that this opcode uses }
            _Special:_Specials; { CPUID, RDTSC and other special opcodes come
                                  under this, PUSH/POPs/Branches too }
            Case CPUs of
              Pentium          :(_PipePen  :_UVPipe);
              AMDK6            :(_PipeK6   :_XYPipe);
              Pentium2         :(_PipePen2 :_Pen2Pipe);
          End;


{ ------------------------------------------------------------------------- }
{ First, the Very Good Ol' Intel Pentium, with dual pipeline. Can't love    }
{ these guys too much huh?                                                  }
{ ------------------------------------------------------------------------- }

Const
 PentTable:Array[_none_.._xlatb_] of _OpCod  = (
({_none_}   _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_JustSpecial]           ;
            _PipePen:[]),

({_lea_}    _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[]                       ;
            _PipePen:[_UV]), { lea does not set/use flags, pipes down both }

({_mov_}    _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[]                       ;
            _PipePen:[_UV]),

({_movsx_}  _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 3              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_movzx_}  _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 3              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_nop_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[]                       ;
            _PipePen:[_UV]),

({_not_}    _RegUse :[impl_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 3              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_pop_}    _RegUse :[esp_]          ; _RegSet:[esp_,impl_]              ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[_POP]                   ;
            _PipePen:[_UV]),  { 3 cycles for Segment/Memory, also Non-pipe }

({_popa_}   _RegUse :[esp_]          ; _RegSet:_AllRegs;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 5              ; _Special:[_POP]                   ;
            _PipePen:[_NP]),

({_popad_}  _RegUse :[esp_]          ; _RegSet:_AllRegs;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 5              ; _Special:[_POP]                   ;
            _PipePen:[_NP]),

({_popaw_}  _RegUse :[esp_]          ; _RegSet:_AllRegs;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 5              ; _Special:[_POP]                   ;
            _PipePen:[_NP]),

({_popf_}   _RegUse :[esp_]          ; _RegSet:[esp_]                    ;
            _FlUse  :[]              ; _FlSet :_AllFlags                 ;
            _Cycles : 6              ; _Special:[_POP]                   ;
            _PipePen:[_NP]),

({_popfd_}  _RegUse :[esp_]          ; _RegSet:[esp_]                    ;
            _FlUse  :[]              ; _FlSet :_AllFlags                 ;
            _Cycles : 6              ; _Special:[_POP]                   ;
            _PipePen:[_NP]),

({_popfw_}  _RegUse :[esp_]          ; _RegSet:[esp_]                    ;
            _FlUse  :[]              ; _FlSet :_AllFlags                 ;
            _Cycles : 6              ; _Special:[_POP]                   ;
            _PipePen:[_NP]),

({_push_}   _RegUse :[esp_,impl_]    ; _RegSet:[esp_]                    ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[_PUSH]                  ;
            _PipePen:[_UV]),

({_pusha_}  _RegUse :_AllRegs        ; _RegSet:[esp_]                    ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 5              ; _Special:[_PUSH]                  ;
            _PipePen:[_NP]),

({_pushad_} _RegUse :_AllRegs        ; _RegSet:[esp_]                    ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 5              ; _Special:[_PUSH]                  ;
            _PipePen:[_NP]),

({_pushaw_} _RegUse :_AllRegs        ; _RegSet:[esp_]                    ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 5              ; _Special:[_PUSH]                  ;
            _PipePen:[_NP]),

({_pushf_}  _RegUse :[esp_]          ; _RegSet:[esp_]                    ;
            _FlUse  :_AllFlags       ; _FlSet :[]                        ;
            _Cycles : 9              ; _Special:[_PUSH]                  ;
            _PipePen:[_NP]),

({_pushfd_} _RegUse :[esp_]          ; _RegSet:[esp_]                    ;
            _FlUse  :_AllFlags       ; _FlSet :[]                        ;
            _Cycles : 9              ; _Special:[_PUSH]                  ;
            _PipePen:[_NP]),

({_pushfw_} _RegUse :[esp_]          ; _RegSet:[esp_]                    ;
            _FlUse  :_AllFlags       ; _FlSet :[]                        ;
            _Cycles : 9              ; _Special:[_PUSH]                  ;
            _PipePen:[_NP]),

({_add_}    _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 1              ; _Special:[]                       ;
            _PipePen:[_UV]),

({_and_}    _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 1              ; _Special:[]                       ;
            _PipePen:[_UV]),

({_clc_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[_Carry]                  ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cld_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[_Direction]              ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cli_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[_Interrupt]              ;
            _Cycles : 7              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_cmc_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Carry]        ; _FlSet :[_Carry]                  ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmp_}    _RegUse :[impr_,impl_]   ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 1              ; _Special:[]                       ;
            _PipePen:[_UV]),

({_dec_}    _RegUse :[impl_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :_FlAOPSZ                  ;
            _Cycles : 1              ; _Special:[]                       ;
            _PipePen:[_UV]),  { Note! Dec does not change CARRY flag! }

({_div_}    _RegUse :[impl_]         ; _RegSet:[eax_,edx_]               ;
            _FlUse  :[]              ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 41             ; _Special:[]                       ;
            _PipePen:[_NP]),

({_idiv_}   _RegUse :[impl_]        ; _RegSet:[eax_,edx_]                ;
            _FlUse  :[]              ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 46             ; _Special:[]                       ;
            _PipePen:[_NP]),

({_imul_}   _RegUse :[impl_,impr_,impm_] ; _RegSet:[eax_,edx_,impl_]     ;
            _FlUse  :[]              ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 11             ; _Special:[_Multiply]              ;
            _PipePen:[_NP]),

({_inc_}    _RegUse :[impl_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :_FlAOPSZ                  ;
            _Cycles : 1              ; _Special:[]                       ;
            _PipePen:[_UV]),  { Note! Inc does not change CARRY flag! }

({_mul_}    _RegUse :[impl_]         ; _RegSet:[eax_,edx_]               ;
            _FlUse  :[]              ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 11             ; _Special:[]                       ;
            _PipePen:[_NP]),

({_neg_}    _RegUse :[impl_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 1              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_or_}     _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 1              ; _Special:[]                       ;
            _PipePen:[_UV]),

({_rol_}    _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :[_Carry,_Overflow]        ;
            _Cycles : 1              ; _Special:[]                       ;
            _PipePen:[_PU]),

({_ror_}    _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :[_Carry,_Overflow]        ;
            _Cycles : 1              ; _Special:[]                       ;
            _PipePen:[_PU]),

({_sahf_}   _RegUse :[eax_]         ; _RegSet:[]                         ;
            _FlUse  :[]              ; _FlSet :_FlACOPSZ - [_Overflow]   ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_sal_}    _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 1              ; _Special:[]                       ;
            _PipePen:[_PU]),

({_sar_}    _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 1              ; _Special:[]                       ;
            _PipePen:[_PU]),

({_shl_}    _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 1              ; _Special:[]                       ;
            _PipePen:[_PU]),

({_shld_}   _RegUse :[impr_, impm_]  ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 4              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_shr_}    _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 1              ; _Special:[]                       ;
            _PipePen:[_PU]),

({_shrd_}   _RegUse :[impr_, impm_]  ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 4              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_stc_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[_Carry]                  ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_std_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[_Direction]              ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_sti_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[_Interrupt]              ;
            _Cycles : 7              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_sub_}    _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 1              ; _Special:[]                       ;
            _PipePen:[_UV]),

({_test_}   _RegUse :[impr_,impl_]   ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 1              ; _Special:[]                       ;
            _PipePen:[_UV]),

({_xor_}    _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 1              ; _Special:[]                       ;
            _PipePen:[_UV]),

({_aaa_}    _RegUse :[]              ; _RegSet:[eax_]                    ;
            _FlUse  :[_Adjust]       ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 3              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_aad_}    _RegUse :[]              ; _RegSet:[eax_]                    ;
            _FlUse  :[]              ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 10             ; _Special:[]                       ;
            _PipePen:[_NP]),

({_aam_}    _RegUse :[]              ; _RegSet:[eax_]                    ;
            _FlUse  :[]              ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 18             ; _Special:[]                       ;
            _PipePen:[_NP]),

({_aas_}    _RegUse :[]              ; _RegSet:[eax_]                    ;
            _FlUse  :[_Adjust]       ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 3              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_adc_}    _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Carry]        ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 1              ; _Special:[]                       ;
            _PipePen:[_PU]),

({_daa_}    _RegUse :[]              ; _RegSet:[eax_]                    ;
            _FlUse  :[_Adjust,_Carry]; _FlSet :_FlACOPSZ                 ;
            _Cycles : 3              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_das_}    _RegUse :[]              ; _RegSet:[eax_]                    ;
            _FlUse  :[_Adjust,_Carry]; _FlSet :_FlACOPSZ                 ;
            _Cycles : 3              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_rcl_}    _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Carry]        ; _FlSet :[_Carry,_Overflow]        ;
            _Cycles : 1              ; _Special:[]                       ;
            _PipePen:[_PU]),

({_rcr_}    _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Carry]        ; _FlSet :[_Carry,_Overflow]        ;
            _Cycles : 1              ; _Special:[]                       ;
            _PipePen:[_PU]),

({_sbb_}    _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Carry]        ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 1              ; _Special:[]                       ;
            _PipePen:[_PU]),

({_lahf_}   _RegUse :[impl_]         ; _RegSet:[eax_]                    ;
            _FlUse  :_FlACOPSZ-[_Overflow]; _FlSet :[]                   ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_seta_}   _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Carry, _Zero] ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_setae_}  _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Carry]        ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_setb_}   _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Carry]        ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_setbe_}  _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Carry, _Zero] ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_setc_}   _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Carry]        ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_sete_}   _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Zero]         ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_setg_}   _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Zero,_Sign,_Overflow] ; _FlSet :[]                ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_setge_}  _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Sign, _Overflow] ; _FlSet :[]                     ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_setl_}   _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Sign, _Overflow] ; _FlSet :[]                     ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_setle_}  _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Zero,_Sign,_Overflow] ; _FlSet :[]                ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_setna_}  _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Carry, _Zero] ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_setnae_} _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Carry]        ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_setnb_}  _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Carry]        ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_setnbe_} _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Carry, _Zero] ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_setnc_}  _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Carry]        ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_setne_}  _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Zero]         ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_setng_}  _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Sign,_Zero,_Overflow] ; _FlSet :[]                ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_setnge_} _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Sign,_Overflow] ; _FlSet :[]                      ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_setnl_}  _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Sign,_Overflow] ; _FlSet :[]                      ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_setnle_} _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Zero,_Overflow,_Sign] ; _FlSet :[]                ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_setno_}  _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Overflow]     ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_setnp_}  _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Parity]       ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_setns_}  _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Sign]         ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_setnz_}  _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Zero]         ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_seto_}   _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Overflow]     ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_setp_}   _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Parity]       ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_setpe_}  _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Parity]       ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_setpo_}  _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Parity]       ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_sets_}   _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Sign]         ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_setz_}   _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[_Zero]         ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmova_}  _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Carry, _Zero] ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovae_} _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Carry]        ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovb_}  _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Carry]        ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovbe_} _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Carry, _Zero] ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovc_}  _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Carry]        ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmove_}  _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Zero]         ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovg_}  _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Zero,_Sign,_Overflow] ; _FlSet :[]                ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovge_} _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Sign, _Overflow] ; _FlSet :[]                     ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovl_}  _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Sign, _Overflow] ; _FlSet :[]                     ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovle_} _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Zero,_Sign,_Overflow] ; _FlSet :[]                ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovna_} _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Carry, _Zero] ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovnae_}_RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Carry]        ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovnb_} _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Carry]        ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovnbe_}_RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Carry, _Zero] ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovnc_} _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Carry]        ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovne_} _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Zero]         ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovng_} _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Sign,_Zero,_Overflow] ; _FlSet :[]                ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovnge_}_RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Sign,_Overflow] ; _FlSet :[]                      ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovnl_} _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Sign,_Overflow] ; _FlSet :[]                      ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovnle_}_RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Zero,_Overflow,_Sign] ; _FlSet :[]                ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovno_} _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Overflow]     ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovnp_} _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Parity]       ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovns_} _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Sign]         ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovnz_} _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Zero]         ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovo_}  _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Overflow]     ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovp_}  _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Parity]       ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovpe_} _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Parity]       ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovpo_} _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Parity]       ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovs_}  _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Sign]         ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmovz_}  _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[_Zero]         ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_ja_}     _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Carry, _Zero] ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_jae_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Carry]        ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_jb_}     _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Carry]        ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_jbe_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Carry, _Zero] ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_jc_}     _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Carry]        ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_je_}     _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Zero]         ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_jg_}     _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Zero,_Sign,_Overflow] ; _FlSet :[]                ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_jge_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Sign, _Overflow] ; _FlSet :[]                     ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_jl_}     _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Sign, _Overflow] ; _FlSet :[]                     ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_jle_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Zero,_Sign,_Overflow] ; _FlSet :[]                ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_jna_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Carry, _Zero] ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_jnae_}   _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Carry]        ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_jnb_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Carry]        ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_jnbe_}   _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Carry, _Zero] ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_jnc_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Carry]        ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_jne_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Zero]         ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_jng_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Sign,_Zero,_Overflow] ; _FlSet :[]                ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_jnge_}   _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Sign,_Overflow] ; _FlSet :[]                      ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_jnl_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Sign,_Overflow] ; _FlSet :[]                      ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_jnle_}   _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Zero,_Overflow,_Sign] ; _FlSet :[]                ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_jno_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Overflow]     ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_jnp_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Parity]       ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_jns_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Sign]         ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_jnz_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Zero]         ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_jo_}     _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Overflow]     ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_jp_}     _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Parity]       ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_jpe_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Parity]       ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_jpo_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Parity]       ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_js_}     _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Sign]         ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_jz_}     _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Zero]         ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_call_}   _RegUse :[impl_]         ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 4              ; _Special:[_Branch]                ;
            _PipePen:[_NP]),

({_int_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 16             ; _Special:[_Branch]                ;
            _PipePen:[_NP]),

({_int01_}  _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 16             ; _Special:[_Branch]                ;
            _PipePen:[_NP]),

({_int1_}   _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 16             ; _Special:[_Branch]                ;
            _PipePen:[_NP]),

({_int3_}   _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 13             ; _Special:[_Branch]                ;
            _PipePen:[_NP]),

({_into_}   _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[_Overflow]     ; _FlSet :[]                        ;
            _Cycles : 13             ; _Special:[_Branch]                ;
            _PipePen:[_NP]),  { Overflow flag is "sorta" used though ;) }

({_iret_}   _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 10             ; _Special:[_Branch]                ;
            _PipePen:[_NP]),

({_iretd_}  _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 10             ; _Special:[_Branch]                ;
            _PipePen:[_NP]),

({_iretw_}  _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 10             ; _Special:[_Branch]                ;
            _PipePen:[_NP]),

({_jcxz_}   _RegUse :[ecx_]          ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 6              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_jecxz_}  _RegUse :[ecx_]          ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 6              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_jmp_}    _RegUse :[impl_]         ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[_Branch]                ;
            _PipePen:[_PV]),

({_loop_}   _RegUse :[ecx_]          ; _RegSet:[ecx_]                    ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 6              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_loope_}  _RegUse :[ecx_]          ; _RegSet:[ecx_]                    ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 7              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_loopne_} _RegUse :[ecx_]          ; _RegSet:[ecx_]                    ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 7              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_loopnz_} _RegUse :[ecx_]          ; _RegSet:[ecx_]                    ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 6              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_loopz_}  _RegUse :[ecx_]          ; _RegSet:[ecx_]                    ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 6              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_rep_}    _RegUse :[ecx_]          ; _RegSet:[ecx_]                    ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_Rep]                   ;
            _PipePen:[_NP]),

({_repne_}  _RegUse :[ecx_]          ; _RegSet:[ecx_]                    ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_Rep]                   ;
            _PipePen:[_NP]),

({_repe_}   _RegUse :[ecx_]          ; _RegSet:[ecx_]                    ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_Rep]                   ;
            _PipePen:[_NP]),

({_ret_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 10             ; _Special:[_Branch]                ;
            _PipePen:[_NP]),

({_retf_}   _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 10             ; _Special:[_Branch]                ;
            _PipePen:[_NP]),

({_retn_}   _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 10             ; _Special:[_Branch]                ;
            _PipePen:[_NP]),

({_cmpsb_}  _RegUse :[]              ; _RegSet:[esi_,edi_]               ;
            _FlUse  :[_Direction]    ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 5              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmpsd_}  _RegUse :[]              ; _RegSet:[esi_,edi_]               ;
            _FlUse  :[_Direction]    ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 5              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmpsw_}  _RegUse :[]              ; _RegSet:[esi_,edi_]               ;
            _FlUse  :[_Direction]    ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 5              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_insb_}   _RegUse :[edx_]          ; _RegSet:[edi_]                    ;
            _FlUse  :[_Direction]    ; _FlSet :[]                        ;
            _Cycles : 22             ; _Special:[]                       ;
            _PipePen:[_NP]),

({_insd_}   _RegUse :[edx_]          ; _RegSet:[edi_]                    ;
            _FlUse  :[_Direction]    ; _FlSet :[]                        ;
            _Cycles : 22             ; _Special:[]                       ;
            _PipePen:[_NP]),

({_insw_}   _RegUse :[edx_]          ; _RegSet:[edi_]                    ;
            _FlUse  :[_Direction]    ; _FlSet :[]                        ;
            _Cycles : 22             ; _Special:[]                       ;
            _PipePen:[_NP]),

({_lodsb_}  _RegUse :[]              ; _RegSet:[esi_,eax_]               ;
            _FlUse  :[_Direction]    ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_lodsd_}  _RegUse :[]              ; _RegSet:[esi_,eax_]               ;
            _FlUse  :[_Direction]    ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_lodsw_}  _RegUse :[]              ; _RegSet:[esi_,eax_]               ;
            _FlUse  :[_Direction]    ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_movsb_}  _RegUse :[]              ; _RegSet:[esi_,edi_]               ;
            _FlUse  :[_Direction]    ; _FlSet :[]                        ;
            _Cycles : 4              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_movsd_}  _RegUse :[]              ; _RegSet:[esi_,edi_]               ;
            _FlUse  :[_Direction]    ; _FlSet :[]                        ;
            _Cycles : 4              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_movsw_}  _RegUse :[]              ; _RegSet:[esi_,edi_]               ;
            _FlUse  :[_Direction]    ; _FlSet :[]                        ;
            _Cycles : 4              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_outsb_}  _RegUse :[edx_]          ; _RegSet:[esi_]                    ;
            _FlUse  :[_Direction]    ; _FlSet :[]                        ;
            _Cycles : 25             ; _Special:[]                       ;
            _PipePen:[_NP]),

({_outsd_}  _RegUse :[edx_]          ; _RegSet:[esi_]                    ;
            _FlUse  :[_Direction]    ; _FlSet :[]                        ;
            _Cycles : 25             ; _Special:[]                       ;
            _PipePen:[_NP]),

({_outsw_}  _RegUse :[edx_]          ; _RegSet:[esi_]                    ;
            _FlUse  :[_Direction]    ; _FlSet :[]                        ;
            _Cycles : 25             ; _Special:[]                       ;
            _PipePen:[_NP]),

({_scasb_}  _RegUse :[eax_]          ; _RegSet:[edi_]                    ;
            _FlUse  :[_Direction]    ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 4              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_scasd_}  _RegUse :[eax_]          ; _RegSet:[edi_]                    ;
            _FlUse  :[_Direction]    ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 4              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_scasw_}  _RegUse :[eax_]          ; _RegSet:[edi_]                    ;
            _FlUse  :[_Direction]    ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 4              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_stosb_}  _RegUse :[eax_]          ; _RegSet:[edi_]                    ;
            _FlUse  :[_Direction]    ; _FlSet :[]                        ;
            _Cycles : 3              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_stosd_}  _RegUse :[eax_]          ; _RegSet:[edi_]                    ;
            _FlUse  :[_Direction]    ; _FlSet :[]                        ;
            _Cycles : 3              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_stosw_}  _RegUse :[eax_]          ; _RegSet:[edi_]                    ;
            _FlUse  :[_Direction]    ; _FlSet :[]                        ;
            _Cycles : 3              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_align_}  _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_arpl_}   _RegUse :[impl_,impr_]   ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[_Zero]                   ;
            _Cycles : 7              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_bound_}  _RegUse :[impl_,impr_]   ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 8              ; _Special:[_Branch]                  ;
            _PipePen:[_NP]),

({_bsf_}    _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 6              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_bsr_}    _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 6              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_bswap_}  _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_bt_}     _RegUse :[impr_,impl_]   ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[_Carry]                  ;
            _Cycles : 4              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_btc_}    _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :[_Carry]                  ;
            _Cycles : 7              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_btr_}    _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :[_Carry]                  ;
            _Cycles : 7              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_bts_}    _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :[_Carry]                  ;
            _Cycles : 7              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cbw_}    _RegUse :[]              ; _RegSet:[eax_]                    ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 3              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_clts_}   _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 10             ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_cdq_}    _RegUse :[eax_]          ; _RegSet:[edx_]                    ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmpxchg_}_RegUse :[impr_]         ; _RegSet:[eax_,impl_]              ;
            _FlUse  :[]              ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 5              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmpxchg486_}_RegUse :[impr_]      ; _RegSet:[eax_,impl_]              ;
            _FlUse  :[]              ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 5              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cmpxchg8b_}_RegUse :[ecx_,ebx_]   ; _RegSet:[eax_,edx_]               ;
            _FlUse  :[]              ; _FlSet :[_Zero]                   ;
            _Cycles : 10             ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cpuid_}  _RegUse :[]              ; _RegSet:[eax_,ebx_,ecx_,edx_]     ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 14             ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_cwd_}    _RegUse :[eax_]          ; _RegSet:[edx_]                    ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_cwde_}   _RegUse :[]              ; _RegSet:[eax_]                    ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 3              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_db_}     _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_dd_}     _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_dq_}     _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_dt_}     _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_dw_}     _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_enter_}  _RegUse :[]              ; _RegSet:[esp_,ebp_]               ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 15             ; _Special:[_Push]                  ;
            _PipePen:[_NP]),

({_equ_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_hlt_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 4              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_ibts_}   _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_icebp_}  _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_in_}     _RegUse :[edx_]          ; _RegSet:[eax_]                    ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 19             ; _Special:[]                       ;
            _PipePen:[_NP]),

({_incbin_} _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_invd_}   _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_invlpg_} _RegUse :[impl_]         ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_lar_}    _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :[_Zero]                   ;
            _Cycles : 8              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_lds_}    _RegUse :[impr_]         ; _RegSet:[impl_,ds_]               ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 4              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_leave_}  _RegUse :[]              ; _RegSet:[esp_,ebp_]               ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 3              ; _Special:[_Pop]                   ;
            _PipePen:[_NP]),

({_les_}    _RegUse :[impr_]         ; _RegSet:[impl_,es_]               ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 4              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_lfs_}    _RegUse :[impr_]         ; _RegSet:[impl_,fs_]               ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 4              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_lgdt_}   _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 6              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_lgs_}    _RegUse :[impr_]         ; _RegSet:[impl_,gs_]               ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 4              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_lidt_}   _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 6              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_lldt_}   _RegUse :[impl_]         ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 9              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_lmsw_}   _RegUse :[impl_]         ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 8              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_loadall_}_RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_loadall286_}_RegUse :[]           ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_lsl_}    _RegUse :[impr_]         ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :[_Zero]                   ;
            _Cycles : 8              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_lss_}    _RegUse :[impr_]         ; _RegSet:[impl_,ss_]               ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 4              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_ltr_}    _RegUse :[impr_]         ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 10             ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_out_}    _RegUse :[edx_,eax_]     ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 24             ; _Special:[]                       ;
            _PipePen:[_NP]),

({_rdmsr_}  _RegUse :[ecx_]          ; _RegSet:[eax_,edx_]               ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_rdpmc_}  _RegUse :[ecx_]          ; _RegSet:[eax_,edx_]               ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_rdtsc_}  _RegUse :[]              ; _RegSet:[eax_,edx_]               ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_resb_}   _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_resd_}   _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_resq_}   _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_rest_}   _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_resw_}   _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_rsm_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_salc_}   _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_sgdt_}   _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 4              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_sidt_}   _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 4              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_sldt_}   _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_smi_}    _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_smsw_}   _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 4              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_str_}    _RegUse :[]              ; _RegSet:[impl_]                   ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 2              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_umov_}   _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_verr_}   _RegUse :[impl_]         ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[_Zero]                   ;
            _Cycles : 7              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_verw_}   _RegUse :[impl_]         ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[_Zero]                   ;
            _Cycles : 7              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_wait_}   _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 1              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_wbinvd_} _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_wrmsr_}  _RegUse :[ecx_,eax_,edx_]; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_xadd_}   _RegUse :[]              ; _RegSet:[impl_,impr_]             ;
            _FlUse  :[]              ; _FlSet :_FlACOPSZ                 ;
            _Cycles : 3              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_xbts_}   _RegUse :[]              ; _RegSet:[]                        ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 0              ; _Special:[_JustSpecial]           ;
            _PipePen:[_NP]),

({_xchg_}   _RegUse :[]              ; _RegSet:[impl_,impr_]             ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 3              ; _Special:[]                       ;
            _PipePen:[_NP]),

({_xlatb_}  _RegUse :[ebx_]          ; _RegSet:[eax_]                    ;
            _FlUse  :[]              ; _FlSet :[]                        ;
            _Cycles : 4              ; _Special:[]                       ;
            _PipePen:[_NP]));


Function GetOperand(var o:operand):String;
var
 s:string[79];
 p:LongInt;
begin
  FillChar(s,80,#00);
  case o.o of
  _reg: begin
          if o.size=1 then
            begin
              if o.reg=eax then o.reg:=al;
              if o.reg=edx then o.reg:=dl;
              if o.reg=ecx then o.reg:=cl;
              if o.reg=ebx then o.reg:=bl;
            end
          else
            if o.size=2 then
              begin
                if o.reg=eax then o.reg:=ax;
                if o.reg=edx then o.reg:=dx;
                if o.reg=ecx then o.reg:=cx;
                if o.reg=ebx then o.reg:=bx;
              end;
          s := r[o.reg];
        end;
  _fpu: begin
          s:=asdef.fpstack;
          p:=pos('#', s);
          if p<>0 then
            begin
              delete(s, p, 1);
              insert(Numb(o.f), s, p);
            end;
        end;
  _mmx: begin
          s:='mm'+Numb(o.f);
        end;
  _mem,
  _ord,
  _lab: begin
          if (o.o=_mem) and (o.size=_offset) then
            s := asdef.offset + CreateName(o.loc)
          else
            begin
              case o.size of
              _nothing : ;
              _offset  : s := asdef.offset;
              _byte    : s := asdef.byteptr;
              _word    : s := asdef.wordptr;
              _dword   : s := asdef.dwordptr;
              _qword   : s := asdef.qwordptr;
              _tbyte   : s := asdef.tbyteptr;
              _near_   : s := asdef.jump_prefix+' ';
              end;
              case o.o of
              _mem : s := s + '['+CreateName(o.loc)+']';
              _ord : s := Numb(o.n);
              _lab : s := o.lab;
              end;
            end;
        end;
  end;

GetOperand := s;
end;

function GetAsm(a:pAsmRecord):String;
var
 s:string[79];  { one output line RARELY exceeds this, rigth Johan? }
begin
 If (a = nil) then
  begin
   GetAsm := '------------';
   exit;
  end;

 FillChar(s[1],79,' ');

 case byte(a^.a) of                { AsmNodeType, just .. fucks }
  1 : s := a^.lab+':';             { _label }
  2 : s := '      '+ a^.s;         { _string }
  3 : begin                        { _opcode }
       s := '      '+opcodes[a^.op];
       s[0] := #17;                { make a "tab" }
       if a^.o1.o<>_non then s := s + GetOperand(a^.o1);
       if a^.o2.o<>_non then s := s + ', '+GetOperand(a^.o2);
       if a^.o3.o<>_non then s := s + ', '+GetOperand(a^.o3);
      end;
 end;

GetAsm := s;

end;

Const
 RegDepTab:Array[regs] of _regs = { Translation tables for registers }
  ([], [eax_], [eax_], [eax_], [ebx_], [ebx_], [ebp_], [ebx_], [ecx_], [ecx_],
   [cs_], [ecx_], [edx_], [edi_], [edx_], [ds_], [edx_], [eax_], [edx_], [ecx_],
   [ebx_], [esi_], [edi_], [esp_], [ebp_], [es_], [fs_], [gs_], [esi_], [esp_], [ss_]);

{regs =
    (none, ah, al, ax, bh, bl, bp, bx, ch, cl, cs, cx, dh, di, dl, ds, dx,
     eax, edx, ecx, ebx, esi, edi, esp, ebp, es, fs, gs, si, sp, ss);
}


Function WriteUseRegs(k:_Regs):String;
var
 s:String;
begin
  s := '';
  If (eax_ in k) then s := s + 'eax ';
  If (ebx_ in k) then s := s + 'ebx ';
  If (ecx_ in k) then s := s + 'ecx ';
  If (edx_ in k) then s := s + 'edx ';
  If (ebp_ in k) then s := s + 'ebp ';
  If (esi_ in k) then s := s + 'esi ';
  If (edi_ in k) then s := s + 'edi ';
  If (esp_ in k) then s := s + 'esp ';
  If (cs_ in k) then s := s + 'cs ';
  If (ds_ in k) then s := s + 'ds ';
  If (es_ in k) then s := s + 'es ';
  If (fs_ in k) then s := s + 'fs ';
  If (gs_ in k) then s := s + 'gs ';
  If (ss_ in k) then s := s + 'ss ';
  If (impl_ in k) then s := s + 'impl ';
  If (impr_ in k) then s := s + 'impr ';
  If (impm_ in k) then s := s + 'impm ';
 WriteUseRegs := s;
end;

Function WriteUseFlags(k:_Flags):String;
var
 s:String;
begin
 s := '';
 If (_Adjust in k)    then s := s + 'A' else s := s + ' ';
 If (_Carry in k)     then s := s + 'C' else s := s + ' ';
 If (_Direction in k) then s := s + 'D' else s := s + ' ';
 If (_Interrupt in k) then s := s + 'I' else s := s + ' ';
 If (_Overflow in k)  then s := s + 'O' else s := s + ' ';
 If (_Parity in k)    then s := s + 'P' else s := s + ' ';
 If (_Sign in k)      then s := s + 'S' else s := s + ' ';
 If (_Trap in k)      then s := s + 'T' else s := s + ' ';
 If (_Zero in k)      then s := s + 'Z' else s := s + ' ';

 WriteUseFlags := s;
end;

Procedure TranslateImplied(var Reggie:_Regs; p:pAsmRecord; MemToo:Boolean);

Procedure FindRemoveImplied(which:_regs; o:operand);
begin
 If (Reggie - which <> Reggie) then
  begin
   If (o.o = _reg) then Reggie := Reggie + RegDepTab[o.reg];
   If (o.o = _mem) AND (MemToo) then Reggie := Reggie + RegDepTab[o.loc.base] + RegDepTab[o.loc.index];
  end;

 Reggie := Reggie - which;

end;

begin
 FindRemoveImplied([impl_],p^.o1); { Replace all impl_ with regs from o1 }
 FindRemoveImplied([impr_],p^.o2);
 FindRemoveImplied([impm_],p^.o3); { blah blah }
end;


Function RegDep(p1,p2:pAsmRecord):Boolean;
var
 p1RUSE,p2RUSE,p1RSET,p2RSET:_Regs;
begin

 RegDep := FALSE;

 If (p1 = nil) OR (p2 = nil) then exit;

 {JPFIX}
 if (p1^.a = _labels) or (p2^.a = _labels) then exit;
 {JPFIX}

{     My coding seems to follow the following scheme:
      Coding Quality := (TiredNess^Coca-Cola)/2. (Where higher is better)
      Coding understandability := TiredNess^HoursInFrontOfPuter/Cola
                                 (Where lower is more understandable)
                                 (I must have some cola before coding??? or div0 ;)
                                  ARGH ;)
      So where do the Quality/Understandability cross eachother?

 --- Anyone brave enough to try to understand the below, please
      tell me if you survived it. I wrote it during a Coca-Cola
      shock. It seems to work well. That is very good. Hmm...

 --- Ok .. I rewrote the whole crap... have fun reading though...


}

 p1RSET := PentTable[p1^.op]._RegSet;
 p1RUSE := PentTable[p1^.op]._RegUse + p1RSET;

 p2RSET := PentTable[p2^.op]._RegSet;
 p2RUSE := PentTable[p2^.op]._RegUse + p2RSET;

 TranslateImplied(p1RSET,p1,FALSE);
 TranslateImplied(p1RUSE,p1,TRUE);

 TranslateImplied(p2RSET,p2,FALSE);
 TranslateImplied(p2RUSE,p2,TRUE);

{$IFDEF chatty}
 WriteLn('------ START ------');
 WriteLn('p1 USES ',WriteUseRegs(p1RUSE):15,GetAsm(p1));
 WriteLn('p1 SETS ',WriteUseRegs(p1RSET):15,GetAsm(p1));
 WriteLn('p2 USES ',WriteUseRegs(p2RUSE):15,GetAsm(p2));
 WriteLn('p2 SETS ',WriteUseRegs(p2RSET):15,GetAsm(p2));
 If (p1RSET - p2RUSE <> p1RSET) then WriteLn('* p2 is RegDep on p1!'); ;
 WriteLn('------- END -------');
{$ENDIF}

 RegDep := (p1RSET - p2RUSE <> p1RSET);

end;

Function  FlagDep(p1,p2:pAsmRecord):Boolean;
var
 p1FUSE,p2FUSE,p1FSET,p2FSET:_Flags;
begin

 FlagDep := FALSE;

 If (p1 = nil) OR (p2 = nil) then exit;

 p1FSET := PentTable[p1^.op]._FlSet;
 p1FUSE := PentTable[p1^.op]._FlUse + p1FSET;

 p2FSET := PentTable[p2^.op]._FlSet;
 p2FUSE := PentTable[p2^.op]._FlUse + p2FSET;

{$IFDEF chatty}
 WriteLn('------ START ------');
 WriteLn('p1 USES ',WriteUseFlags(p1FUSE):15,GetAsm(p1));
 WriteLn('p1 SETS ',WriteUseFlags(p1FSET):15,GetAsm(p1));
 WriteLn('p2 USES ',WriteUseFlags(p2FUSE):15,GetAsm(p2));
 WriteLn('p2 SETS ',WriteUseFlags(p2FSET):15,GetAsm(p2));
 If (p1FSET - p2FUSE <> p1FSET) then WriteLn('* p2 is FlagDep on p1!'); ;
 WriteLn('------- END -------');
{$ENDIF}

 FlagDep := (p1FSET - p2FUSE <> p1FSET);

end;

Function  MemDep(p1,p2:pAsmRecord):Boolean;
begin

 MemDep := FALSE;

 If (p1 = nil) OR (p2 = nil) then exit;

 If (p1^.o1.o = _mem) then
  begin
   If (p2^.o1.o = _mem) then
    MemDep := (p1^.o1.loc.offset = p2^.o1.loc.offset) AND
              (p1^.o1.loc.name   = p2^.o1.loc.name  ) AND
              (p1^.o1.loc.index  = p2^.o1.loc.index ) AND
              (p1^.o1.loc.base   = p2^.o1.loc.base  );
   If (p2^.o2.o = _mem) then
    MemDep := (p1^.o1.loc.offset = p2^.o2.loc.offset) AND
              (p1^.o1.loc.name   = p2^.o2.loc.name  ) AND
              (p1^.o1.loc.index  = p2^.o2.loc.index ) AND
              (p1^.o1.loc.base   = p2^.o2.loc.base  );
  end;

end;

Function  IsDep(p1,p2:pAsmRecord):Boolean;
begin
 IsDep := MemDep(p1,p2) OR RegDep(p1,p2);
end;

Function  PushPopNoGo(p1,p2:pAsmRecord):Boolean;
begin
 PushPopNoGo := FALSE;
 If (p1 = nil) OR (p2 = nil) then exit;
 PushPopNoGo := NOT
  ((PentTable[p1^.op]._Special = [_Push]) AND (PentTable[p2^.op]._Special = [_Push]) OR
   (PentTable[p1^.op]._Special = [_Pop])  AND (PentTable[p2^.op]._Special = [_Pop]));
end;

Procedure DoOptimizeRegisterUsageMK3(var a:tAsmList);
var
 CurAsm,ScanDown,ScanUp:pAsmRecord;
begin
 CurAsm := a.First;
 While (CurAsm <> Nil) do
  begin
   If (IsDep(CurAsm,CurAsm^.next)) AND (CurAsm^._Inline = FALSE) AND
      (CurAsm^.Op <= _xlatb_) then  { Warning! Dependency detected! }
    begin
    {$ifdef debug}
     WriteLn('Dependancy :');
     WriteLn('1: ',GetAsm(CurAsm));
     WriteLn('2: ',GetAsm(CurAsm^.Next));
    {$endif}

(*   If ([_Push,_Pop] in PentTable[CurAsm^.Op]_Special) AND
      (PentTable[CurAsm^.Op]._Special = PentTable[CurAsm^.Next^.Op]._Special) Then
   If ([_Push,_Pop] - PentTable[CurAsm^.Op]._Special <> [_Push,_Pop]) AND
      ([_Push,_Pop] - PentTable[CurAsm^.Next^.Op]._Special <> [_Push,_Pop]) Then
    begin
     {$ifdef debug}
     WriteLn('Ignoring PUSH/PUSH''s & POP/POPs');
     {$endif}
     CurAsm := CurAsm^.Next;
     Continue; { Come on.. go on! }
    end;
*)
  {
    What happens now is that a search is started downwards in code for
    a substitute between these two opcodes that does not create a
    dependency. The opcode that is ripped from below MAY make a dep between
    the two opcodes it was ripped from... }
     ScanDown := CurAsm^.Next;  { If CurAsm^.Next is nil, would never get here }
     ScanDown := ScanDown^.Next;{ We are starting from the opcode below the troubler}
     While (ScanDown <> Nil) do
      begin
       {$ifdef littlechat}
       WriteLn('(ScanDown) Going Down. Evaluating ',GetAsm(ScanDown));
       {$endif}
       If (IsDep(CurAsm,ScanDown)) then
        begin
         ScanDown := ScanDown^.Next;
         Continue;  { Not good, this one also creates dependancy, don't bother }
        end; { if }

       If (IsDep(ScanDown,CurAsm^.Next)) then { Geez, wrote wrong order first time ;) }
        begin
         ScanDown := ScanDown^.Next;
         Continue;  { This would have created a dep. do not bother }
        end; { if }

       If (ScanDown^.a <> _opcode) OR (ScanDown^.op > _xlatb_) then
        begin
         {$ifdef debug}
          WriteLn('(ScanDown) Non-Opcode Break due to ',GetAsm(ScanDown));
         {$endif}
         BREAK;     { The opcode stream is broken. Hopefully get this better later }
        end;

       If (PentTable[ScanDown^.op]._Special = [_JustSpecial]) OR
          (PentTable[ScanDown^.op]._Special = [_Branch]) OR
          (ScanDown^._inline) then
        begin
         {$ifdef debug}
          WriteLn('(ScanDown) Stay away from those Just special and Branch thingies');
         {$endif}
         BREAK;
        end;

       { The opcode removed CANNOT make a dependency between the two left
         back }

       If (IsDep(ScanDown^.Prev,ScanDown^.Next) AND
           PushPopNoGo(ScanDown^.Prev,ScanDown^.Next)) then
        begin
         {$ifdef debug}
          WriteLn('(ScanDown) Cannot create dependencies DOWN');
         {$endif}
         ScanDown := ScanDown^.Next;
         Continue; { Nothing else to do but try again... }
        end;


       { Ok, so far, it does not create a dependency, let's try to scan
         upwards and see what happens (See if it is dep upwards.) }

       ScanUp := ScanDown^.Prev;
       While (ScanUp <> CurAsm) do{ Until the one below current }
        begin
         {$ifdef littlechat}
         WriteLn('(ScanDown) Going Up Again');
         {$endif}

         If (IsDep(ScanDown,ScanUp) OR IsDep(ScanUp,ScanDown)) then
          begin
           {$ifdef debug}
            WriteLn('(ScanDown) Dang!!õ!"õ"õ ',GetAsm(ScanDown),' is dep of ',GetAsm(ScanUp));
           {$endif}
           ScanUp := Nil;
           break;
          end;
         If (FlagDep(ScanDown,ScanUp) OR IsDep(ScanUp,ScanDown)) then
          begin
           {$ifdef debug}
            WriteLn('(ScanDown) AND THE FLAGS MESSES IT UP AGAIN!!!!!!!');
           {$endif}
           ScanUp := Nil;
           break;
          end;
         ScanUp := ScanUp^.Prev;
        end; { of While ScanUp }

       If (ScanUp = CurAsm) then
        begin
         {$ifdef debug}
          WriteLn('(ScanDown) Incrediblus!!!!!!!!!!');
          WriteLn('1: ',GetAsm(CurAsm));
          WriteLn('2: ',GetAsm(ScanDown));
          WriteLn('3: ',GetAsm(CurAsm^.Next));
         {$endif}
         {$ifdef chattype3}
          WriteLn('(ScanDown) Taken From : ');
          WriteLn('1: ',GetAsm(ScanDown^.Prev));
          WriteLn('2: ',GetAsm(ScanDown));
          WriteLn('3: ',GetAsm(ScanDown^.Next));
         {$endif}

         { Cut out of chain here }
          If (ScanDown^.Next <> nil) then
           begin
            ScanDown^.Prev^.Next := ScanDown^.Next;
            ScanDown^.Next^.Prev := ScanDown^.Prev; { ScanDown Op removed out of link }
           end
          else
           begin
            A.Rear := ScanDown^.Prev;
            ScanDown^.Prev^.Next := ScanDown^.Next;
           end;
         { Paste in between here }
          ScanDown^.Prev := CurAsm;
          ScanDown^.Next := CurAsm^.Next;  { ScanDown op pasted between }
          CurAsm^.Next   := ScanDown;      { Start link fixed }
          ScanDown^.Next^.Prev := ScanDown;{ Pure logic, ain't it? }
         {$ifdef debug}
          WriteLn('(ScanDown) PATCHIN'' Done!');
         {$endif}
          Break;                           { This problem solved }
        end;

       {$ifdef littlechat}
       WriteLn('Scanning more DOWN');
       {$endif}
       ScanDown := ScanDown^.Next;
      end; { of While ScanDown }

     If (CurAsm^.Next = ScanDown) then
      begin
       {$ifdef debug}
       WriteLn('Ok, order fixed in ScanDown, going onto next pair');
       {$endif}
       CurAsm := CurAsm^.Next;
       Continue; { Go on with the next in chain }
      end;

  { Ok, that was _THAT_ part Now, since the scanning down failed, I have
    to scan UPWARDS instead. Have to find an opcode that does not create a
    dep. The opcode that is taken from above CAN NOT make a dependenancy
    for the two opcodes it is between }
     ScanUp   := CurAsm^.Prev;  { Hmm.. we must check if this chain is nil }
     While (ScanUp <> Nil) do   { ahhh.. checked here ;) }
      begin
       {$ifdef littlechat}
       WriteLn('(ScanUp) Going Up. Evaluating ',GetAsm(ScanUp));
       {$endif}

       If (IsDep(CurAsm,ScanUp)) OR {???} (IsDep(ScanUp,CurAsm)) then
        begin
         ScanUp := ScanUp^.Prev;
         Continue;  { Not good, this one also creates dependancy, don't bother }
        end; { if }

       If (IsDep(ScanUp,CurAsm^.Next)) then { Geez, wrote wrong order first time ;) }
        begin
         ScanUp := ScanUp^.Prev;
         Continue;  { This would have created a dep. do not bother }
        end; { if }

       If (ScanUp^.a <> _opcode) OR (ScanUp^.op > _xlatb_) then
        begin
         {$ifdef debug}
          WriteLn('(ScanUp) Non-Opcode Break due to ',GetAsm(ScanUp));
         {$endif}
         BREAK;     { The opcode stream is broken. Hopefully get this better later }
        end;

       If (PentTable[ScanUp^.op]._Special = [_JustSpecial]) OR
          (PentTable[ScanUp^.op]._Special = [_Branch]) OR
          (ScanUp^._Inline) then
        begin
         {$ifdef debug}
          WriteLn('(ScanDown) Stay away from those Just special and branch thingies');
         {$endif}
         BREAK;
        end;


       { The opcode removed CANNOT make a dependency between the two left
         back }

       If (IsDep(ScanUp^.Prev,ScanUp^.Next) AND
           PushPopNoGo(ScanUp^.Prev,ScanUp^.Next)) then
        begin
         {$ifdef debug}
          WriteLn('(ScanUp) Cannot create dependencies UP');
         {$endif}
         ScanUp := ScanUp^.Prev;
         Continue; { Nothing else to do but try again... }
        end;

       { Ok, so far, it does not create a dependency, let's try to scan
         down again and see what happens (See if it is dep downwards.) }

       ScanDown := ScanUp^.Next;
       While (ScanDown <> CurAsm) do { Until the one below current }
        begin
         {$ifdef littlechat}
         WriteLn('(ScanUp) Going Down Again');
         {$endif}

         If (IsDep(ScanUp,ScanDown) OR IsDep(ScanDown,ScanUp)) then { Or reverse???}
          begin
           {$ifdef debug}
            WriteLn('(ScanUp) Dang!!õ!"õ"õ ',GetAsm(ScanDown),' is dep of ',GetAsm(ScanUp));
           {$endif}
           break;
          end;
         If (FlagDep(ScanUp,ScanDown) OR FlagDep(ScanDown,ScanUp)) then { Or reverse???}
          begin
           {$ifdef debug}
            WriteLn('(ScanUp) AND THE FLAGS MESSES IT UP AGAIN!!!!!!!');
           {$endif}
           break;
          end;
         ScanDown := ScanDown^.Next;
        end; { of While ScanDown }

       If (ScanDown = CurAsm) then
        begin
         {$ifdef debug}
          WriteLn('(ScanUp) Incrediblus!!!!!!!!!!');
          WriteLn('1: ',GetAsm(CurAsm));
          WriteLn('2: ',GetAsm(ScanUp));
          WriteLn('3: ',GetAsm(CurAsm^.Next));
         {$endif}
         {$ifdef chattype3}
          WriteLn('(ScanUp) Taken From : ');
          WriteLn('1: ',GetAsm(ScanUp^.Prev));
          WriteLn('2: ',GetAsm(ScanUp));
          WriteLn('3: ',GetAsm(ScanUp^.Next));
         {$endif}
         { Cut out of chain here }
          If (ScanUp^.Prev <> nil) then
           Begin
            ScanUp^.Prev^.Next := ScanUp^.Next;
            ScanUp^.Next^.Prev := ScanUp^.Prev; { ScanDown Op removed out of link }
           end
          else
           begin
            A.First := ScanUp^.Next;
            ScanUp^.Next^.Prev := ScanUp^.Prev;
           end;
         { Paste in between here }
          ScanUp^.Prev := CurAsm;
          ScanUp^.Next := CurAsm^.Next;  { ScanDown op pasted between }
          CurAsm^.Next := ScanUp;        { Start link fixed }
          ScanUp^.Next^.Prev := ScanUp;  { Pure logic, ain't it? }
         {$ifdef debug}
          WriteLn('(ScanUp) PATCHIN'' Done!');
         {$endif}
          Break;
        end;

       {$ifdef littlechat}
       WriteLn('Scanning more UP');
       {$endif}
       ScanUp := ScanUp^.Prev;
      end; { of While ScanUp }

    end; { of If IsDep }

   {$ifdef littlechat}
   WriteLn('Going onto next!');
   {$endif}
   CurAsm := CurAsm^.next;
  end;



end;

Procedure OptimizeRegisterUsageMk3(var a:tAsmList);
var
 x:word;
begin
 For x := 1 to 1 do
  DoOptimizeRegisterUsageMk3(a);
end;


(* The following below is _VERY_ under construction...
  (Okok.. so it does work, but isn't useful ;)
*)
Const
 RegDepTab2:Array[regs] of regs = { Translation tables for registers }
  (none, eax, eax, eax, ebx, ebx, ebp, ebx, ecx, ecx, cs, ecx, edx, edi, edx, ds, edx,
   eax, edx, ecx ,ebx, esi, edi, esp, ebp, es, fs, gs, esi, esp, ss);


Procedure DoOptimizeMemoryLoads(var a:tAsmList);
Type
 Contents = Record
             WhichRef:pAsmRecord;
             number:longint;
             name:String[79];
             Loaded:Boolean;
            end;

var
 CurAsm,ScanDown,ScanUp:pAsmRecord;
 TestOut:AsmRecord;
 ole:Operand;
 Regis:Array[eax..ebp] of Contents;
 rSET,rPrevSet:_Regs;
 r:Regs;
 rS:Regs;

Procedure EmptyRegs(f,t:Regs);
var
 r:Regs;
begin
 For r := f to t do
  begin
   Regis[r].WhichRef := nil;
   Regis[r].number   := -1;
   Regis[r].name     := '';
   Regis[r].Loaded   := FALSE;
  end;
end;

Function  GetWhatReg(LookHere:_Regs):Regs;
begin
 GetWhatReg := none;
 If (eax_ in LookHere) then GetWhatReg := eax;
 If (ebx_ in LookHere) then GetWhatReg := ebx;
 If (ecx_ in LookHere) then GetWhatReg := ecx;
 If (edx_ in LookHere) then GetWhatReg := edx;
 If (esi_ in LookHere) then GetWhatReg := esi;
 If (edi_ in LookHere) then GetWhatReg := edi;
 If (esp_ in LookHere) then GetWhatReg := esp;
 If (ebp_ in LookHere) then GetWhatReg := ebp;
end;

Function  HowManyRegs(LookHere:_Regs):Word;
var
 x:Word;
begin
 x := 0;
 If (eax_ in LookHere) then Inc(x);
 If (ebx_ in LookHere) then Inc(x);
 If (ecx_ in LookHere) then Inc(x);
 If (edx_ in LookHere) then Inc(x);
 If (esi_ in LookHere) then Inc(x);
 If (edi_ in LookHere) then Inc(x);
 If (esp_ in LookHere) then Inc(x);
 If (ebp_ in LookHere) then Inc(x);
 HowManyRegs := x;
end;

Procedure EmptyTheseRegs(LookHere:_Regs);
begin
 If (eax_ in LookHere) then EmptyRegs(eax,eax);
 If (ebx_ in LookHere) then EmptyRegs(ebx,ebx);
 If (ecx_ in LookHere) then EmptyRegs(ecx,ecx);
 If (edx_ in LookHere) then EmptyRegs(edx,edx);
 If (esi_ in LookHere) then EmptyRegs(esi,esi);
 If (edi_ in LookHere) then EmptyRegs(edi,edi);
 If (esp_ in LookHere) then EmptyRegs(esp,esp);
 If (ebp_ in LookHere) then EmptyRegs(ebp,ebp);
end;

Function  GetRegName(AReg:Regs):String;
var
 s:String;
begin
 s := 'none!';
 If (AReg = eax) then s := 'eax';
 If (AReg = ebx) then s := 'ebx';
 If (AReg = ecx) then s := 'ecx';
 If (AReg = edx) then s := 'edx';
 If (AReg = esi) then s := 'esi';
 If (AReg = edi) then s := 'edi';
 If (AReg = ebp) then s := 'ebp';
 If (AReg = esp) then s := 'esp';
 GetRegName := s;
end;

Function GetRegNames(LookHere:_Regs):String;
var
 s:String;
begin
 s := '';
 If (eax_ in LookHere) then s := s+'eax ';
 If (ebx_ in LookHere) then s := s+'ebx ';
 If (ecx_ in LookHere) then s := s+'ecx ';
 If (edx_ in LookHere) then s := s+'edx ';
 If (esi_ in LookHere) then s := s+'esi ';
 If (edi_ in LookHere) then s := s+'edi ';
 If (esp_ in LookHere) then s := s+'esp ';
 If (ebp_ in LookHere) then s := s+'ebp ';
 If (s = '') then s := 'None!';
 GetRegNames := s;
end;

begin
 EmptyRegs(eax,ebp);

 CurAsm := a.first;

 While (CurAsm <> nil) do
  begin

   If (CurAsm^.a <> _opcode) OR (CurAsm^._inline) OR
      ([_JustSpecial,_Branch] - PentTable[CurAsm^.op]._Special <> [_JustSpecial,_Branch]) then
    begin
     {$ifdef debug}
      WriteLn('(MemLoadOptMk1) Dropping contents of ALL registers due to ',GetAsm(CurAsm));
     {$endif}
      EmptyRegs(eax,ebp);
      CurAsm := CurAsm^.Next;
      Continue;
    end;

   rSET := PentTable[CurAsm^.op]._RegSet;
   If (CurAsm^.Prev <> Nil) then rPrevSET := PentTable[CurAsm^.Prev^.op]._RegSet;

   TranslateImplied(rSET,CurAsm,FALSE);
   If (CurAsm^.Prev <> Nil) then TranslateImplied(rPrevSET,CurAsm^.Prev,FALSE)
    else rPrevSET := [];

   If (HowManyRegs(rSET) > 1) then
    begin
     {$ifdef chatty}
      WriteLn('OOpps... Not messing with ops that set many regs!');
     {$endif}
     {$ifdef debug}
      WriteLn('(MemLoadOptMk1) Dropping contents of registers : ',GetRegNames(rSET),' due to ',GetAsm(CurAsm));
     {$endif}
     EmptyTheseRegs(rSET);
     CurAsm := CurAsm^.Next;
     Continue;
    end;

   rS := GetWhatReg(rSET);

   For r := eax to ebp do
    begin
     If (Regis[r].Loaded = FALSE) then continue; { Nothing to get here }
     If (Pos(GetRegName(r),GetRegNames(rPrevSet)) <> 0) then { Hard way to do it? Yes, I hope so}
      begin
      {$ifdef debug}
       WriteLn('(MemLoadOptMk1) Cannot create dependencies!');
      {$endif}
       Continue;
      end;
     If (CurAsm^.o2.o = _mem) then
      begin
      {$ifdef debug}
       WriteLn('Right is Memory!');
      {$endif}
       If (CurAsm^.o2.loc.index = none) AND (CurAsm^.o2.loc.base = none) AND
          (CurAsm^.o2.loc.name  = Regis[r].name) AND (CurAsm^.o2.loc.offset = Regis[r].number) then
        begin
         {$ifdef debug}
          WriteLn('(MemLoadOptMk1) Memory load avoided!');
          WriteLn('            Old: ',GetAsm(CurAsm));
         {$endif}
          CurAsm^.o2.o   := _reg;
          CurAsm^.o2.reg := r;
         {$ifdef debug}
          WriteLn('            New: ',GetAsm(CurAsm));
         {$endif}
          If (CurAsm^.op = _mov_) AND (CurAsm^.o1.o = _reg) AND
             (CurAsm^.o1.reg = CurAsm^.o2.reg) then
           begin
            {$ifdef debug}
             WriteLn('(MemLoadOptMk1) Deleting : ',GetAsm(CurAsm));
            {$endif}
             CurAsm^.Prev^.Next := CurAsm^.Next;
             CurAsm^.Next^.Prev := CurAsm^.Prev;
             ScanDown := CurAsm;
             CurAsm := CurAsm^.Next;
             Dispose(ScanDown);
           end;
        end;
      end;

     If (CurAsm^.o1.o = _mem) AND (CurAsm^.op in [_cmp_,_test_]) then
      begin
       WriteLn('Left is Memory with cmp or test');
       If (CurAsm^.o1.loc.index = none) AND (CurAsm^.o1.loc.base = none) AND
          (CurAsm^.o1.loc.name  = Regis[r].name) AND (CurAsm^.o1.loc.offset = Regis[r].number) then
        begin
         {$ifdef debug}
          WriteLn('(MemLoadOptMk1) Memory can be replaced with register!');
          WriteLn('            Old: ',GetAsm(CurAsm));
         {$endif}
          CurAsm^.o1.o   := _reg;
          CurAsm^.o1.reg := r;
         {$ifdef debug}
          WriteLn('            New: ',GetAsm(CurAsm));
         {$endif}
        end;
      end;

(*     If (CurAsm^.o1.o = _mem) then
      begin
       If (CurAsm^.o1.loc.name = Regis[r].name) AND
          (CurAsm^.o1.loc.offset = Regis[r].number) AND
          (Regis[r].name <> '') then
        begin
         {$ifdef debug}
          WriteLn('(MemLoadOptMk1) FAB! Memory Left Loc alike!');
          WriteLn('!!1: ',GetAsm(CurAsm));
          WriteLn('!!2: ',GetAsm(Regis[r].WhichRef));
         {$endif}

         If (CurAsm^.op = _cmp_) then
          begin
           CurAsm^.o1.o := _reg;
           CurAsm^.o2.reg := r;
           {$ifdef debug}
            WriteLn('(MemLoadOptMk1) CMP optimize!');
           {$endif}
          end;
        end;
      end;
     If (CurAsm^.o2.o = _mem) then
      begin
       If (CurAsm^.o2.loc.name = Regis[r].name) AND
          (CurAsm^.o2.loc.offset = Regis[r].number) AND
          (Regis[r].name <> '') then
        begin
        {$ifdef debug}
         WriteLn('FABOLOUS!!!! Memory locs alike!');
         WriteLn('!!1: ',GetAsm(CurAsm));
         WriteLn('!!2: ',GetAsm(Regis[r].WhichRef));
        {$endif}

         CurAsm^.o2.o := _reg;
         CurAsm^.o2.reg := r;
        {$ifdef chattype3}
         WriteLn('(MemLoadOptMk1) Opcodes ->');
         WriteLn('1: ',GetAsm(CurAsm^.Prev));
         WriteLn('2: ',GetAsm(CurAsm));
         WriteLn('3: ',GetAsm(CurAsm^.Next));
        {$endif}

         If (CurAsm^.op = _mov_) then
          begin
           If (r = rS) then
            begin
             {$ifdef debug}
              WriteLn('Deleting : ',GetAsm(CurAsm));
             {$endif}
             CurAsm^.Prev^.Next := CurAsm^.Next;
             CurAsm^.Next^.Prev := CurAsm^.Prev;
             ScanDown := CurAsm;
             CurAsm := CurAsm^.Next;
             Dispose(ScanDown);
            end;
          end;
        end;
      end;
*)
    end;


{ The following part looks for Mov's, and sets up references if
  the load/store is done correctly.
  The load/store HAS to be done with either OFFSET and/or by a NAME
  If the load/store uses index and/or base register, it cannot be used.

  Still missing check for register size (assumes 32bit)
}

   If (CurAsm^.op = _mov_) then
    begin
     If (CurAsm^.o1.o = _reg) AND (CurAsm^.o2.o = _mem) then
      If (CurAsm^.o2.loc.index = none) AND (CurAsm^.o2.loc.base = none) then
       begin
        r := CurAsm^.o1.reg;
        {$ifdef debug}
         WriteLn('(MemLoadOptMk1) Remembering load to ',GetRegName(r),' : ',GetAsm(CurAsm));
        {$endif}
        Regis[r].WhichRef := CurAsm;
        Regis[r].Number   := CurAsm^.o2.loc.offset;
        Regis[r].Name     := CurAsm^.o2.loc.name;
        Regis[r].Loaded   := TRUE;
       end
     else
     If (CurAsm^.o1.o = _mem) AND (CurAsm^.o2.o = _reg) then
      If (CurAsm^.o1.loc.index = none) AND (CurAsm^.o1.loc.base = none) then
       begin
        r := CurAsm^.o2.reg;
        {$ifdef debug}
         WriteLn('(MemLoadOptMk1) Remembering store from ',GetRegName(r),' : ',GetAsm(CurAsm));
        {$endif}
        Regis[r].WhichRef := CurAsm;
        Regis[r].Number   := CurAsm^.o1.loc.offset;
        Regis[r].Name     := CurAsm^.o1.loc.name;
        Regis[r].Loaded   := TRUE;
       end
     else
     If (CurAsm^.o1.o = _reg) AND (CurAsm^.o2.o = _reg) then
      begin
       {$ifdef debug}
        WriteLn('(MemLoadOptMk1) Remembering register transfer from ',
                GetRegName(CurAsm^.o2.reg),' to ',GetRegName(CurAsm^.o1.reg),
                ' : ',GetAsm(CurAsm));
       {$endif}
       Regis[CurAsm^.o1.reg] := Regis[CurAsm^.o2.reg];
      end
     else
      begin
       {$ifdef debug}
        WriteLn('(MemLoadOptMk1) Dumping register ',GetRegName(rS),'''s contents due to ',GetAsm(CurAsm));
       {$endif}
       EmptyRegs(rS,rS);
      end
    else
     begin
      {$ifdef debug}
       WriteLn('(MemLoadOptMk1) Dumping register ',GetRegName(rS),'''s contents due to ',GetAsm(CurAsm));
      {$endif}
      EmptyRegs(rS,rS);
     end
    else
     begin
     {$ifdef debug}
      WriteLn('(MemLoadOptMk1) Dumping register ',GetRegName(rS),'''s contents due to ',GetAsm(CurAsm));
     {$endif}
     EmptyRegs(rS,rS);
     end;
    end
   else
    begin
     {$ifdef debug}
      WriteLn('(MemLoadOptMk1) Dumping register ',GetRegName(rS),'''s contents due to ',GetAsm(CurAsm));
     {$endif}
     EmptyRegs(rS,rS);
    end;

   CurAsm := CurAsm^.Next;
  end;

end;


Procedure OptimizeMemoryLoads(var a:tAsmList);
begin
 DoOptimizeMemoryLoads(a);
end;

End.
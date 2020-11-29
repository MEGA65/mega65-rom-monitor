*******************************
* BSM = Bit Shifter's Monitor *
* for The MEGA65  28-Nov_2020 *
*******************************

.CPU 45GS02

.STORE $6000,$2000,"bsmon.rom"

*************
* Constants *
*************

WHITE  = $05
YELLOW = $9e
LRED   = $96

CR     = $0d
REV    = $12
CRIGHT = $1d
QUOTE  = $22
APOSTR = $27

************************************************
* Register storage for JMPFAR and JSRFAR calls *
************************************************

Bank       =  2
PCH        =  3
PCL        =  4
SR         =  5
AC         =  6
XR         =  7
YR         =  8
ZR         =  9

*************************************
* Used direct (zero) page addresses *
*************************************

BP         = 10
SPH        = 11
SPL        = 12

; following variables overlap with the BASIC floating point area

; $59 - $5d : temporary floating point accumulator
; $5e - $62 : temporary floating point accumulator
; $63 - $69 : primary   floating point accumulator
; $6a - $6f : secondary floating point accumulator

; A set of 32 bit variables also used as 32 bit pointer

& = $59

Long_AC    .BSS 4  ; 32 bit accumulator
Long_CT    .BSS 4  ; 32 bit counter
Long_PC    .BSS 4  ; 32 bit program counter
Long_DA    .BSS 4  ; 32 bit data pointer

; Flags used in BBR BBS instructions

Adr_Flags  .BSS 1
Mode_Flags .BSS 1
Op_Code    .BSS 1
Op_Flag    .BSS 1
COL        .BSS 1
Buf_Index  .BSS 1

; operating system variables


STATUS     = $90
VERCK      = $93
FNLEN      = $b7
SA         = $b9
FA         = $ba
FNADR      = $bb
BA         = $bd
FNBANK     = $be

NDX        = $d0        ; length of keyboard buffer
MODE_80    = $d7        ; 80 column / 40 volumn flag

B_Margin   = $e4        ; SCBOT  default = 24
T_Margin   = $e5        ; SCTOP  default =  0
L_Margin   = $e6        ; SCLF   default =  0
R_Margin   = $e7        ; SCRT   default = 39 or 79

QTSW       = $f4        ; Quote switch

Buffer     = $0200      ; input buffer

IIRQ       = $0314
IBRK       = $0316
EXMON      = $032e


Mon_Data   = $0400      ; 32 byte bufer for hunt and filename
X_Vector   = $0420      ; exit vector (ROM version dependent)

Op_Size    = $042c
Op_Mne     = $042d

Op_Bits    = $0434
Op_Ix      = $0435
Ix_Mne     = $0437
Op_Len     = $0439

Unit       = $1106
EXIT_OLD   = $cf2e      ; exit address for ROM 910110
EXIT       = $cfa4      ; exit address for ROM 911001

SETBNK     = $ff6b
JSRFAR     = $ff6e
JMPFAR     = $ff71
LDA_FAR    = $ff74
STA_FAR    = $ff77
PRIMM      = $ff7d
SETMSG     = $ff90
SETLFS     = $ffba
SETNAM     = $ffbd
OPEN       = $ffc0
CLOSE      = $ffc3
CHKIN      = $ffc6
CHKOUT     = $ffc9
CLRCHN     = $ffcc
CHRIN      = $ffcf
CHROUT     = $ffd2
LOAD       = $ffd5
SAVE       = $ffd8
SETTIM     = $ffdb
GETTIM     = $ffde
STOP       = $ffe1
GETIN      = $ffe4
CLALL      = $ffe7
SCAN       = $ffea
SCRORG     = $ffed
PLOT       = $fff0

* = $1fff
        .STORE $1fff,$0101,"bsm.prg"

*************
Module header
*************

        .WORD $2001             ; load address
        .WORD Link              ; line link
        .WORD 2020              ; line number
        .BYTE $fe,$02           ; BANK token
        .BYTE "0:"              ; BANK argument
        .BYTE $9e               ; SYS  token
        .BYTE "(8235):"         ; $202d
        .BYTE $8f               ; REM  token
        .BYTE " BIT SHIFTER 28-NOV-20",0
Link    .WORD 0                 ; BASIC end marker

        ; copy image to $030000

        SEI

; map memory to monitor configuration

        LDA  #$a0
        LDX  #$82
        LDY  #$00
        LDZ  #$83
        MAP
        EOM

; VIC IV registers visible

        LDA  #$47
        STA  $d02f
        LDA  #$53
        STA  $d02f

; toggle write protection

        LDA  #$70
        STA  $D640
        NOP

        LDZ  #0
        STZ  Long_AC
        LDA  #$21
        STA  Long_AC+1
        STZ  Long_CT
        STZ  Long_CT+1
        LDA  #3
        STA  Long_CT+2
        STZ  Long_CT+3
        LDX  #$20

_loop   LDA  (Long_AC),Z
        STA  [Long_CT],Z
        INZ
        BNE  _loop
        INC  Long_AC+1
        INC  Long_CT+1
        DEX
        BNE  _loop

        LDA  #$70
        STA  $D640              ; toggle write protection
        NOP

        RTS
EndMod

        .FILL $2100-* (0)

* = $6000

********************
Monitor_Call ; $6000
********************

         JMP  Mon_Call

*********************
Monitor_Break ; $6003
*********************

         JMP  Mon_Break

**********************
Monitor_Switch ; $6009
**********************

         JMP  Mon_Switch

****************
Module Mon_Break
****************

         JSR  PRIMM
         .BYTE "\rBREAK\a",0
         JSR  Print_Commands

; pull BP, Z, Y, X, A,SR,PCL,PCH
;       7  6  5  4  3  2  1  0

         LDX  #7
         BIT  EXIT      ; version
         BPL  _loop
         DEX
_loop    PLA
         STA  PCH,X
         DEX
         BPL  _loop

; decrement PC to point after BRK

         LDA  PCL
         BNE  _nopage
         DEC  PCH
_nopage  DEC  PCL

         LDA  $011d
         BBR7 Bank,_bank
         LDA  $011f
_bank    AND  #15
         STA  Bank
         BRA  Mon_Start
EndMod

***************
Module Mon_Call
***************

         JSR  Print_Commands

;        clear register for monitor call

         LDA  #0
         LDX  #6
_loop    STA  AC,X
         DEX
         BPL  _loop

;        set default PC to "exit to BASIC"

         LDA  #<EXIT     ; ROM 911110
         LDX  #>EXIT
         BIT  EXIT       ; $20 (JSR) or $ff ?
         BPL  _store
         LDA  #<EXIT_OLD ; ROM 910111
         LDX  #>EXIT_OLD
_store   STA  PCL
         STA  X_Vector
         STX  PCH
         STX  X_Vector+1
EndMod

****************
Module Mon_Start
****************

         CLD
         TSY
         STY  SPH
         TSX
         STX  SPL
         LDA  #$c0
         JSR  SETMSG
         CLI
         NOP
EndMod

***************************
Module Mon_Register ; $6042
***************************

         JSR  Reg_Text

; print Bank,PCH

         LDY  #0
_loopa   LDA  Bank,Y
         JSR  Print_Hex
         INY
         CPY  #2
         BCC  _loopa

; print SR,PCL,A,X,Y,Z,BP

_loopb   LDA  Bank,Y
         JSR  Print_Hex_Blank
         INY
         CPY  #9
         BCC  _loopb

; print 16 bit stack pointer

         LDA  SPH
         JSR  Print_Hex
         LDA  SPL
         JSR  Print_Hex_Blank

; print flags

         LDY  #8
         LDA  SR
_loopc   ASL  A
         PHA
         LDA  #'-'
         BCC  _flag
         LDA  #'1'
_flag    JSR  CHROUT
         PLA
         DEY
         BNE  _loopc
EndMod

***********
Module Main
***********

         JSR  Print_CR
         LDX  #0

; read one line into buffer

******
Main_A
******

_loop    JSR  CHRIN
         STA  Buffer,X
         INX
         CPX  #80
         BCS  Mon_Error         ; input too long
         CMP  #CR
         BNE  _loop

         LDA  #0
         STA  Buf_Index
         STA  Buffer-1,X        ; terminate buffer
_getcomm JSR  Get_Char
         BEQ  Main
         CMP  #' '
         BEQ  _getcomm
EndMod

*****************
Module Mon_Switch
*****************

         LDX  #24
_loop    CMP  Command_Char,X
         BEQ  Mon_Select
         DEX
         BPL  _loop

;        fall through to error routine if not found

****************
Module Mon_Error
****************

; put a question mark at the end of the text

         JSR  PRIMM
         .BYTE "\eO",CRIGHT,'?',0
         LDX  #$f8              ; reset stack pointer
         TXS
         BRA  Main

*****************
Module Mon_Select
*****************

         STA  VERCK
         CPX  #22
         LBCS  Load_Save
         TXA
         ASL  A
         TAX
         JSR  Got_LAC           ; get 1st. parameter
         JMP  (Jump_Table,X)
EndMod

**************
Print_Commands
**************

         JSR  PRIMM
         .BYTE CR,YELLOW,REV,"BS MONITOR COMMANDS:"

************
Command_Char
************

         ;      0123456789abcdef
         .BYTE "ABCDFGHJMRTX@.>;?"

***********
Cons_Prefix
***********

         .BYTE "$+&%'"

****************
Load_Save_Verify
****************

         .BYTE "LSV",WHITE,0
         RTS

**********
Jump_Table
**********

         .WORD Mon_Assemble     ; A
         .WORD Mon_Bits         ; B
         .WORD Mon_Compare      ; C
         .WORD Mon_Disassemble  ; D
         .WORD Mon_Fill         ; F
         .WORD Mon_Go           ; G
         .WORD Mon_Hunt         ; H
         .WORD Mon_JSR          ; J
         .WORD Mon_Memory       ; M
         .WORD Mon_Register     ; R
         .WORD Mon_Transfer     ; T
         .WORD Mon_Exit         ; X
         .WORD Mon_DOS          ; @
         .WORD Mon_Assemble     ; .
         .WORD Mon_Set_Memory   ; >
         .WORD Mon_Set_Register ; ;
         .WORD Mon_Help         ; ?
         .WORD Converter        ; $
         .WORD Converter        ; +
         .WORD Converter        ; &
         .WORD Converter        ; %


***************
Module Mon_Exit
***************

         JMP  (X_Vector)

****************
Module LAC_To_PC
****************

; called from Mon_Set_Register, Mon_Go and Mon_JSR
; as the first instruction. The carry flag was set from
; the routine Get_LAC if an error occured.
; Notice that the Bank, PCH and PCL values are stored
; high to low, reverse to the standard order.

; Bank, PCH and PCL are part of a list, that is used by
; the routines FAR_JMP and FAR_JSR of the operating system

         BCS  _error
         LDA  Long_AC
         STA  Bank+2
         LDA  Long_AC+1
         STA  Bank+1
         LDA  Long_AC+2
         STA  Bank
_error   RTS
EndMod

*****************
Module LAC_To_LPC
*****************

; copy long accumulator to long program counter

         LDA  Long_AC
         STA  Long_PC
         LDA  Long_AC+1
         STA  Long_PC+1
         LDA  Long_AC+2
         STA  Long_PC+2
         LDA  Long_AC+3
         STA  Long_PC+3
         RTS
EndMod

*****************
Module LAC_To_LCT
*****************

; copy long accumulator to long counter

         LDA  Long_AC
         STA  Long_CT
         LDA  Long_AC+1
         STA  Long_CT+1
         LDA  Long_AC+2
         STA  Long_CT+2
         LDA  Long_AC+3
         STA  Long_CT+3
         RTS
EndMod

*****************
Module LAC_To_LDA
*****************

; copy long accumulator to long data

         LDA  Long_AC
         STA  Long_DA
         LDA  Long_AC+1
         STA  Long_DA+1
         LDA  Long_AC+2
         STA  Long_DA+2
         LDA  Long_AC+3
         STA  Long_DA+3
         RTS
EndMod

*******************
Module LAC_Plus_LCT
*******************

         CLC
         LDA  Long_AC
         ADC  Long_CT
         STA  Long_AC
         LDA  Long_AC+1
         ADC  Long_CT+1
         STA  Long_AC+1
         LDA  Long_AC+2
         ADC  Long_CT+2
         STA  Long_AC+2
         LDA  Long_AC+3
         ADC  Long_CT+3
         STA  Long_AC+3
         RTS
EndMod

********************
Module LAC_Minus_LPC
********************

         SEC
         LDA  Long_AC
         SBC  Long_PC
         STA  Long_AC
         LDA  Long_AC+1
         SBC  Long_PC+1
         STA  Long_AC+1
         LDA  Long_AC+2
         SBC  Long_PC+2
         STA  Long_AC+2
         LDA  Long_AC+3
         SBC  Long_PC+3
         STA  Long_AC+3
         RTS
EndMod

**********************
Module LAC_Compare_LPC
**********************

         LDA  Long_AC
         CMP  Long_PC
         LDA  Long_AC+1
         SBC  Long_PC+1
         LDA  Long_AC+2
         SBC  Long_PC+2
         LDA  Long_AC+3
         SBC  Long_PC+3
         RTS
EndMod

**************
Module Inc_LAC
**************

         INW  Long_AC
         BNE  _return
         INW  Long_AC+2
_return  RTS
EndMod

**************
Module Dec_LAC
**************

         LDA  Long_AC
         ORA  Long_AC+1
         BNE  _skip
         DEW  Long_AC+2
_skip    DEW  Long_AC
         RTS
EndMod

**************
Module Inc_LPC
**************

         INW  Long_PC
         BNE  _return
         INW  Long_PC+2
_return  RTS
EndMod

************
Module Fetch
************

         PHZ
         TYA
         TAZ
         BBS7 Long_PC+3,_banked ; trigger banked access
         NOP                    ; use LDA  [Long_PC],Z
_banked  LDA  (Long_PC),Z
         PLZ
         AND  #$ff
         RTS
EndMod

*****************
Module Mon_Memory
*****************

         LDZ  #16               ; default row count
         BCC  _param
         BRA  _row

_param   JSR  LAC_To_LPC        ; Long_PC = start address
         JSR  Got_LAC           ; Long_AC = end address
         BCS  _row              ; not given

         JSR  LAC_Minus_LPC     ; Long_AC = range
         LBCC Mon_Error         ; negative range -> error
         LDX  #4                ; 16 bytes / line
         BBR7 MODE_80,_shift
         DEX                    ;  8 bytes / line
_shift   LSR  Long_AC+1
         ROR  Long_AC
         DEX
         BNE  _shift
         LDZ  Long_AC           ; row count
         INZ

_row     JSR  STOP
         BEQ  _exit
         JSR  Dump_Row
         DEZ
         BNE  _row
_exit    JMP  Main
EndMod

*****************
Module Print_Bits
*****************

         PHZ
         STA  Long_DA
         LDY  #8
_loop    LDA  #'*'
         BBS7 Long_DA,_set
         LDA  #'.'
_set     JSR  CHROUT
         ASL  Long_DA
         DEY
         BNE  _loop
         PLZ
         RTS
EndMod

***************
Module Mon_Bits
***************

         LBCS Mon_Error
         JSR  LAC_To_LPC        ; Long_PC = start address
         JSR  Print_CR
         LDA  #WHITE
         STA  Long_DA+1

         LDX  #8
_row     PHX
         JSR  Hex_LPC
         LDZ  #0
_col     SEC
         LDA  #WHITE+LRED       ; toggle colour
         SBC  Long_DA+1
         STA  Long_DA+1
         JSR  CHROUT
         LDA  [Long_PC],Z
         JSR  Print_Bits
         CLC
         TZA
         ADC  #8
         TAZ
         CMP  #64
         BCC  _col
         JSR  Print_CR
         JSR  Inc_LPC
         PLX
         DEX
         BNE  _row
         JMP  Main
EndMod

***********************
Module Mon_Set_Register
***********************

         JSR  LAC_To_PC
         LDY  #3
_loop    JSR  Got_LAC
         BCS  _exit
         LDA  Long_AC
         STA  Bank,Y
         INY
         CPY  #9
         BCC  _loop
_exit    JMP  Main
EndMod

*********************
Module Mon_Set_Memory
*********************

         BCS  _exit
         JSR  LAC_To_LPC        ; Long_PC = row address
         LDZ  #0
_loop    JSR  Got_LAC
         BCC  _valid
         CMP  #APOSTR           ; flag for character entry
         BNE  _exit
_valid   LDA  Long_AC
         BBS7 Long_PC+3,_banked ; trigger banked access
         NOP                    ; use STA  [Long_PC],Z
_banked  STA  (Long_PC),Z
         INZ
         CPZ  #16
         BBR7 MODE_80,_next
         CPZ  #8
_next    BCC  _loop

_exit    JSR  PRIMM
         .BYTE "\eO"
         .BYTE $91,$00
         JSR  Dump_Row
         JMP  Main
EndMod

*************
Module Mon_Go
*************

         JSR  LAC_To_PC
         LDX  SPL
         TXS
         JMP  JMPFAR
EndMod

**************
Module Mon_JSR
**************

         JSR  LAC_To_PC
         LDX  SPL
         TXS
         JSR  JSRFAR
         TSX
         STX  SPL
         JMP  Main
EndMod

*******************
Module Dump_4_Bytes
*******************

         JSR  CHROUT            ; colour
_loop    BBS7 Long_PC+3,_banked ; trigger banked access
         NOP                    ; use LDA  [Long_PC],Z
_banked  LDA  (Long_PC),Z
         JSR  Print_Hex_Blank
         INZ
         TZA
         AND  #3
         BNE  _loop
         RTS
EndMod

*******************
Module Dump_4_Chars
*******************

         LDY  #0
         STY  QTSW              ; disable quote mode
         JSR  CHROUT            ; colour
_loop    BBS7 Long_PC+3,_banked ; trigger banked access
         NOP                    ; use LDA  [Long_PC],Z
_banked  LDA  (Long_PC),Z
         TAY
         AND  #%0110 0000
         BNE  _laba
         LDY  #'.'
_laba    TYA
         JSR  CHROUT
         INZ
         TZA
         AND  #3
         BNE  _loop
         RTS
EndMod

***************
Module Dump_Row
***************

         PHZ
         JSR  Print_CR
         LDA  #'>'
         JSR  CHROUT
         JSR  Hex_LPC

         LDZ  #0
         LDX  #2                ; 2 blocks in 80 columns
         BBR7 MODE_80,_loop
         DEX                    ; 1 block  in 40 columns
_loop    LDA  #LRED
         JSR  Dump_4_Bytes
         LDA  #WHITE
         JSR  Dump_4_Bytes
         DEX
         BNE  _loop

         JSR  PRIMM
         .BYTE $3a,$12,$00      ; : reverse on

         LDZ  #0
         LDX  #2                ; 4 blocks in 80 columns
         BBR7 MODE_80,_lchr
         DEX                    ; 2 blocks in 40 columns
_lchr    LDA  #LRED
         JSR  Dump_4_Chars
         LDA  #WHITE
         JSR  Dump_4_Chars
         DEX
         BNE  _lchr
         TZA
         JSR  Add_LPC
         PLZ
         RTS
EndMod

*******************
Module Mon_Transfer
*******************

         JSR  Param_Range       ; Long_PC = source
         LBCS Mon_Error         ; Long_CT = count
         JSR  Got_LAC           ; Long_AC = target
         LBCS Mon_Error

         LDZ  #0
         JSR  LAC_Compare_LPC   ; target - source
         BCC  _forward

;        source < target: backward transfer

         JSR  LAC_Plus_LCT      ; Long_AC = end of target

_lpback  LDA  [Long_DA],Z       ; backward copy
         STA  [Long_AC],Z
         JSR  Dec_LDA
         JSR  Dec_LAC
         JSR  Dec_LCT
         BPL  _lpback
         JMP  Main

_forward LDA  [Long_PC],Z       ; forward copy
         STA  [Long_AC],Z
         JSR  Inc_LPC
         JSR  Inc_LAC
         JSR  Dec_LCT
         BPL  _forward
         JMP  Main
EndMod

******************
Module Mon_Compare
******************

         JSR  Param_Range       ; Long_PC = source
         LBCS Mon_Error         ; Long_CT = count
         JSR  Got_LAC           ; Long_AC = target
         LBCS Mon_Error
         JSR  Print_CR
         LDZ  #0
_loop    LDA  [Long_PC],Z
         CMP  [Long_AC],Z
         BEQ  _laba
         JSR  Hex_LPC
_laba    JSR  Inc_LAC
         JSR  Inc_LPC
         JSR  Dec_LCT
         BPL  _loop
         JMP  Main
EndMod

***************
Module Mon_Hunt
***************

         JSR  Param_Range       ; Long_PC = start
         LBCS Mon_Error         ; Long_CT = count
         LDY  #0
         JSR  Get_Char
         CMP  #APOSTR
         BNE  _bin
         JSR  Get_Char          ; string hunt
         CMP  #0
         LBEQ Mon_Error         ; null string

_lpstr   STA  Mon_Data,Y
         INY
         JSR  Get_Char
         BEQ  _hunt
         CPY  #32               ;max. string length
         BNE  _lpstr
         BRA  _hunt

_bin     JSR  Get_LAC
_lpbin   LDA  Long_AC
         STA  Mon_Data,Y
         INY
         JSR  Got_LAC
         BCS  _hunt
         CPY  #32               ;max. data length
         BNE  _lpbin

_hunt    STY  Long_DA           ; hunt length
         JSR  Print_CR

_lpstart LDY  #0
_lpins   JSR  Fetch
         CMP  Mon_Data,Y
         BNE  _next
         INY
         CPY  Long_DA
         BNE  _lpins
         JSR  Hex_LPC           ; match
_next    JSR  STOP
         LBEQ Main
         JSR  Inc_LPC
         JSR  Dec_LCT
         BPL  _lpstart
         JMP  Main
EndMod

****************
Module Load_Save
****************

         LDY  Unit
         STY  FA
         LDY  #8
         STY  SA
         LDY  #0
         STY  BA
         STY  FNLEN
         STY  FNBANK
         STY  STATUS
         LDA  #>Mon_Data
         STA  FNADR+1
         LDA  #<Mon_Data
         STA  FNADR
_skip    JSR  Get_Char          ; skip blanks
         LBEQ Mon_Error
         CMP  #' '
         BEQ  _skip
         CMP  #QUOTE            ; must be quote
         LBNE Mon_Error

         LDX  Buf_Index
_copyfn  LDA  Buffer,X          ; copy filename
         BEQ  _do               ; no more input
         INX
         CMP  #QUOTE
         BEQ  _unit             ; end of filename
         STA  (FNADR),Y         ; store to filename
         INC  FNLEN
         INY
         CPY  #19               ; max = 16 plus prefix "@0:"
         BCC  _copyfn
         JMP  Mon_Error         ; filename too long

_unit    STX  Buf_Index         ; update read position
         JSR  Get_Char
         BEQ  _do               ; no more parameter
         JSR  Got_LAC
         BCS  _do
         LDA  Long_AC           ; unit #
         STA  FA
         JSR  Got_LAC
         BCS  _do
         JSR  LAC_To_LPC        ; Long_PC = start address
         STA  BA                ; Bank
         JSR  Got_LAC           ; Long_AC = end address + 1
         BCS  _load             ; no end address -> load/verify
         JSR  Print_CR
         LDX  Long_AC           ; X/Y = end address
         LDY  Long_AC+1
         LDA  VERCK             ; A = load/verify/save
         CMP  #'S'
         LBNE Mon_Error         ; must be Save
         LDA  #0
         STA  SA                ; set SA for PRG
         LDA  #Long_PC          ; Long_PC = start address
         JSR  SAVE
_exit    JMP  Main

_do      LDA  VERCK
         CMP  #'V'              ; Verify
         BEQ  _exec
         CMP  #'L'              ; Load
         LBNE Mon_Error
         LDA  #0                ; 0 = LOAD
_exec    JSR  LOAD              ; A == 0 : LOAD else VERIFY
         BBR4 STATUS,_exit
         LDA  VERCK
         LBEQ Mon_Error
         LBCS Main
         JSR  PRIMM
         .BYTE " ERROR",0
         JMP  Main

_load    LDX  Long_PC
         LDY  Long_PC+1
         LDA  #0                ; 0 = use X/Y as load address
         STA  SA                ; and ignore load address from file
         BRA  _do
EndMod

***************
Module Mon_Fill
***************

         JSR  Param_Range       ; Long_PC = target
         LBCS Mon_Error         ; Long_CT = count
         JSR  Got_LAC           ; Long_AC = fill byte
         LBCS Mon_Error
         JSR  Print_CR
         LDZ  #0
_loop    LDA  Long_AC
         STA  [Long_PC],Z
         JSR  Inc_LPC
         JSR  Dec_LCT
         BPL  _loop
         JMP  Main
EndMod

*******************
Module Mon_Assemble
*******************

         LBCS Mon_Error
         JSR  LAC_To_LPC        ; Long_PC = PC

_start   LDX  #0                ; mne letter counter
         STX  Long_DA+1         ; clear encoded MNE
         STX  Op_Flag           ; 6:long branch 5:32 bit
         STX  Op_Ix             ; operand byte index
         STX  Op_Len            ; operand length
_getin   JSR  Get_Char
         BNE  _laba
         CPX  #0
         LBEQ Main

_laba    CMP  #' '
         BEQ  _start            ; restart after blank

;        check for long branches

         CPX  #1
         BNE  _labb             ; -> not 2nd. char
         CMP  #'B'
         BNE  _labb             ; 2nd. char != 'B'
         LDZ  Op_Mne
         CPZ  #'L'
         BNE  _labb             ; 1st. Char != 'L'
         SMB6 Op_Flag           ; flag long branch
         DEX                    ; skip 'L'

_labb    STA  Op_Mne,X          ; next mne character
         INX
         CPX  #3
         BNE  _getin

;        encode 3 letter mnemonic

_lpenc   LDA  Op_Mne-1,X
         SEC
         SBC  #$3f              ; offset
         LDY  #5                ; 5 bit code
_lpbit   LSR  A
         ROR  Long_DA
         ROR  Long_DA+1
         DEY
         BNE  _lpbit
         DEX
         BNE  _lpenc

;        find packed MNE code in table

         LDX  #90               ; # of mnemonics
         LDA  Long_DA
_lpfind  CMP  MNE_L,X           ; compare left MNE
         BNE  _nxfind
         LDY  MNE_R,X
         CPY  Long_DA+1         ; compare right MNE
         BEQ  _found
_nxfind  DEX
         BPL  _lpfind
         JMP  Mon_Error

_found   STX  Ix_Mne

;        find 1st. opcode for this mnemonic

         TXA
         LDX  #0
_lpopc   CMP  MNE_Index,X
         BEQ  _exopc
         INX
         BNE  _lpopc
_exopc   STX  Op_Code

;        check for BBR BBS RMB SMB

         TXA
         AND  #7
         CMP  #7
         BNE  _labc

         JSR  Get_Char
         CMP  #'0'
         LBCC Mon_Error
         CMP  #'8'
         LBCS Mon_Error
         ASL  A
         ASL  A
         ASL  A
         ASL  A
         ORA  Op_Code
         STA  Op_Code

         JSR  Get_Char
         CMP  #' '
         LBNE Mon_Error

;        read operand

_labc    LDA  #0
_labd    STA  Mode_Flags
         JSR  Read_Number
         LBCS Mon_Error
         BEQ  _labg             ; no operand
         LDA  Long_AC+2
         LBNE Mon_Error         ; -> overflow
         LDY  #2                ; Y=2 word operand
         LDA  Op_Bits
         CMP  #8
         BCC  _labe             ; -> binary: no 4 digit check
         LDA  COL
         CMP  #4                ; 4 digits force word operand
         BEQ  _labf
_labe    LDA  Long_AC+1
         BNE  _labf             ; high byte not zero
         DEY                    ; Y=1 byte operand
_labf    LDX  Op_Ix             ; X = operand value #
         TYA                    ; A = 1:byte or 2:word
         STA  Op_Len,X          ; store operand length
         INC  Op_Ix             ; ++index to operand value
         TXA                    ; A = current index
         BNE  _labg             ; -> at 2nd. byte
         JSR  LAC_To_LCT        ; Long_CT = 1st. operand
_labg    DEC  Buf_Index         ; back to delimiter

_lpnop   JSR  Get_Char          ; get delimiter
         LBEQ _adjust           ; end of operand
         CMP  #' '
         BEQ  _lpnop

;        immediate

         CMP  #'#'
         BNE  _lbra
         LDA  Mode_Flags
         BNE  _error
         LDA  #$80              ; immediate mode
         BRA  _labd

;        left bracket

_lbra    CMP  #'['
         BNE  _indir
         LDA  Mode_Flags
         BNE  _error
         SMB5 Op_Flag           ; 32 bit mode
         LDA  #$40              ; ( flag
         BRA  _labd

;        left parenthesis

_indir   CMP  #'('
         BNE  _comma
         LDA  Mode_Flags
         BNE  _error
         LDA  #$40              ; ( flag
         BRA  _labd

;        comma

_comma   CMP  #','
         BNE  _stack
         LDA  Op_Ix             ; operand value #
         BEQ  _error
         LDX  #4                ; outside comma
         LDA  Mode_Flags
         BEQ  _comma1           ; no flags yet
         CMP  #$78              ; ($nn,SP)
         BEQ  _comma1
         CMP  #$48              ; ($nn)
         BEQ  _comma1
         LDX  #$20              ; , inside comma
         CMP  #$40              ; (
         BNE  _error
_comma1  TXA
         ORA  Mode_Flags
         JMP  _labd

;        stack relative

_stack   CMP  #'S'
         BNE  _rbra
         JSR  Get_Char
         CMP  #'P'
         BNE  _error
         LDA  Mode_Flags
         CMP  #$60              ; ($nn,
         BNE  _error
         ORA  #%0001 0000       ; SP flag
         JMP  _labd

;        right bracket

_rbra    CMP  #']'
         BNE  _right
         BBR5 Op_Flag,_error
         LDA  Op_Ix
         LBEQ Mon_Error         ; no value
         LDA  Mode_Flags
         CMP  #$40              ; (
         LBNE Mon_Error
         ORA  #%0000 1000       ; )
         JMP  _labd

_error   JMP  Mon_Error

;        right parenthesis

_right   CMP  #')'
         BNE  _X
         LDA  Op_Ix
         LBEQ Mon_Error         ; no value
         LDA  Mode_Flags
         CMP  #$40              ; (
         BEQ  _right1
         CMP  #$61              ; ($nn,X
         BEQ  _right1
         CMP  #$70              ; ($nn,SP
         LBNE Mon_Error
_right1  ORA  #%0000 1000       ; )
         JMP  _labd

_X       CMP  #'X'
         BNE  _Y
         LDA  Op_Ix
         LBEQ Mon_Error
         LDA  Mode_Flags
         CMP  #$60
         BEQ  _X1
         CMP  #4
         LBNE Mon_Error
_X1      ORA  #%0000 0001
         JMP  _labd

;        Y

_Y       CMP  #'Y'
         BNE  _Z
         LDA  Op_Ix
         LBEQ Mon_Error
         LDA  Mode_Flags
         CMP  #$4c             ; ($nn),
         BEQ  _Y1
         CMP  #4               ; $nn,
         BEQ  _Y1
         CMP  #$7c             ; ($nn,SP),
         LBNE Mon_Error
_Y1      ORA  #%0000 0010      ; Y
         JMP  _labd

;        Z

_Z       CMP  #'Z'
         LBNE Mon_Error
         LDA  Op_Ix
         LBEQ Mon_Error
         LDA  Mode_Flags
         CMP  #$4c              ; $nn,
         LBNE Mon_Error
         ORA  #%0000 0011       ; Z
         JMP  _labd

;        BBR BBS RMB SMB  two operands

_adjust  LDA  Ix_Mne
         LDX  Op_Ix             ; # if values
         BEQ  _match            ; -> no operand
         DEX
         BEQ  _one             ; ->  one operand
         DEX
         LBNE Mon_Error         ; -> error if more than 2
         CMP  #5                ; BBR
         BEQ  _BB
         CMP  #6                ; BBS
         LBNE Mon_Error
_BB      LDA  Long_CT+1
         LBNE Mon_Error
         LDA  #3                ; offset
         JSR  Branch_Target
         LDA  Op_Code
         LDY  Long_AC
         LDX  Long_CT
         STX  Long_AC
         STY  Long_AC+1
         LDY  #2
         BRA  _store

;        one operand in Long_CT

_one     LDX  Long_CT
         LDY  Long_CT+1
         STX  Long_AC
         STY  Long_AC+1            ; Aval = operand
         LDX  #10
_lpbrain CMP  BRAIN-1,X
         BEQ  _branch
         DEX
         BNE  _lpbrain
         BRA  _match

;        branch instruction

_branch  LDA  Mode_Flags
         LBNE Mon_Error         ; only value
         LDA  #2                ; branch offset
         JSR  Branch_Target
         LDA  Op_Code
         LDY  #1                ; short branch
         BBR6 Op_Flag,_bran1
         INY                    ; long branch
         ORA  #3
_bran1   BRA  _store

;        find opcode matching mnemonic and address mode

_match   JSR  Mode_Index
_lpmatch JSR  Match_Mode
         BEQ  _okmat
         LDA  Op_Len
         LBEQ Mon_Error
         LDA  Mode_Flags
         LBMI Mon_Error
         AND  #%0011 1111
         STA  Mode_Flags
         INC  Op_Len
         JSR  Size_To_Mode
         BRA  _lpmatch
_okmat   LDY  Op_Len
         TXA

;        store instruction bytes
;        -----------------------
;        A    = opcode
;        Y    = operand length
;        Long_AC = operand value

_store   STA  Op_Code
         STY  Op_Size
         INC  Op_Size
         BBR5 Op_Flag,_storen
         LDA  #$ea              ; 32 bit prefix
         LDZ  #0
         STA  [Long_PC],Z       ; store prefix
         INZ
         LDA  Op_Code
         STA  [Long_PC],Z       ; store opcode
         INZ
         LDA  Long_AC
         STA  [Long_PC],Z       ; store address
         INC  Op_Size
         BRA  _print

_storen  PHY
         PLZ                    ; Z = Y
         BEQ  _store1

_lpsto   LDA  Long_AC-1,Y
         STA  [Long_PC],Z
         DEZ
         DEY
         BNE  _lpsto

_store1  LDA  Op_Code
         STA  [Long_PC],Z

_print   JSR  PRIMM
         .BYTE 13,$91,"A \eQ",0
         JSR  Print_Code
         INC  Op_Size
         LDA  Op_Size
         JSR  Add_LPC

; print out command 'A' together with next address
; and put it into buffer too,
; for easy entry of next assembler instruction

         JSR  PRIMM
         .BYTE CR,"A ",0

         LDA  #'A'
         STA  Buffer
         LDA  #' '
         STA  Buffer+1
         LDY  #2
         LDX  #2                ; 6 digits
         LDA  Long_PC,X
         BNE  _auto
         DEX                    ; 4 digits
_auto    PHX
         LDA  Long_PC,X
         JSR  A_To_Hex
         STA  Buffer,Y
         JSR  CHROUT
         INY
         TXA
         STA  Buffer,Y
         JSR  CHROUT
         INY
         PLX
         DEX
         BPL  _auto

         LDA  #' '
         STA  Buffer,Y
         JSR  CHROUT
         INY
         TYA
         TAX
         JMP  Main_A
EndMod

********************
Module Branch_Target
********************

         DEW  Long_AC
         DEC  A
         BNE  Branch_Target

;        Target - PC

         SEC
         LDA  Long_AC
         SBC  Long_PC
         STA  Long_AC
         LDA  Long_AC+1
         SBC  Long_PC+1
         STA  Long_AC+1
         RTS
EndMod

*****************
Module Match_Mode
*****************

;        find matching mnemonic and address mode

         LDX  Op_Code           ; try this opcode
         LDA  Mode_Flags         ; size and address mode
_loop    CMP  LEN_ADM,X
         BEQ  _return           ; success  ZF=1

;        search for next opcode with same mnemonic

_next    INX                    ; next opcode
         BEQ _error
         LDY  MNE_Index,X
         CPY  Ix_Mne            ; same mnemonic ?
         BEQ  _loop             ; -> compare again
         BRA  _next

_error   DEX                    ; X = $ff ZF=0
_return  RTS
EndMod

*****************
Module Mode_Index
*****************

         LDA  Mode_Flags
         LDX  #0
_loop    CMP  ADMODE,X
         BEQ  _found
         INX
         CPX  #16
         BCC  _loop
         TXA
         RTS
_found   STX  Mode_Flags
EndMod

*******************
Module Size_To_Mode
*******************

         LDA  Op_Len
         LSR  A
         ROR  A
         ROR  A
         ORA  Mode_Flags
         STA  Mode_Flags
         LDX  #0
         RTS
EndMod

**********************
Module Mon_Disassemble
**********************

         BCS  _nopar
         JSR  LAC_To_LPC        ; Long_PC = start address
         JSR  Got_LAC           ; Long_AC = end address
         BCC  range
_nopar   LDA  #32               ; disassemble 32 bytes
         STA  Long_AC
         BRA  _loop
range    JSR  LAC_Minus_LPC     ; Long_AC = range
         LBCC Mon_Error         ; -> negative

_loop    JSR  CR_Erase          ; prepare empty line
         JSR  STOP
         LBEQ Main
         JSR  Dis_Code          ; disassemble one line
         INC  Op_Size
         LDA  Op_Size
         JSR  Add_LPC           ; advance address
         LDA  Long_AC
         SEC
         SBC  Op_Size
         STA  Long_AC
         BCS  _loop
         JMP  Main
EndMod

***************
Module Dis_Code
***************

         JSR  PRIMM
         .BYTE ". ",0
EndMod

*****************
Module Print_Code
*****************

;        print 24 bit address of instruction

         JSR  Hex_LPC          ; 24 bit address
         JSR  Print_Blank

;        read opcode and calculate length and address mode

         LDY  #0
         STY  Op_Flag           ; clear flags
         JSR  Fetch             ; fetch from (banked) address
         STA  Op_Code           ; store it
         TAX                    ; save in X

;        check for 32 bit address mode

         CMP  #$ea              ; prefix ?
         BNE  _normal
         INY
         JSR  Fetch             ; opcode after prefix
         AND  #%0001 1111       ; identify ($nn),Z codes
         CMP  #%0001 0010
         BNE  _normal
         SMB5 Op_Flag           ; set extended flag
         JSR  Fetch
         STA  Op_Code           ; code after prefix
         TAX

_normal  LDY  LEN_ADM,X         ; Y = length and address mode
         TYA                    ; A = length and address mode
         AND  #15               ; A = address mode
         TAX                    ; X = address mode
         LDA  ADMODE,X          ; A = mode flags
         STA  Adr_Flags         ; store
         TYA                    ; A = length and address mode
         AND  #%1100 0000       ; mask instruction length
         ASL  A                 ; rotate into lower two bits
         ROL  A
         ROL  A
         STA  Op_Size           ; store
         BBR5 Op_Flag,_norm1
         INC  Op_Size
_norm1

;        print instruction and operand bytes

         LDY  #0
_lphex   JSR  Fetch
         JSR  Print_Hex_Blank
         CPY  #2
         BEQ  _long             ; stop after 3 bytes
         CPY  Op_Size
         INY
         BCC  _lphex

;        fill up with blanks

_lpfill  CPY  #3
         BCS  _long
         JSR  PRIMM
         .BYTE "   ",0
         INY
         BRA  _lpfill

;        detect long branches

_long    LDA  #YELLOW
         JSR  CHROUT
         LDX  Op_Code
         LDA  LEN_ADM,X
         CMP  #%1010 0000        ; long branch mode
         BNE  _locate
         SMB6 Op_Flag            ; set long branch flag
         LDA  #'L'
         JSR  CHROUT

;        locate mnemonic text

_locate  LDX  Op_Code           ; X = opcode
         LDY  MNE_Index,X       ; Y = index to mnemonic text
         LDA  MNE_L,Y           ; A = packed left part
         STA  Long_CT+1
         LDA  MNE_R,Y           ; A = packed right part
         STA  Long_CT

;        unpack and print mnemonic text

         LDX  #3                ; 3 letters
_lpmne   LDA  #0
         LDY  #5                ; 5 bits per letter
_lplet   ASL  Long_CT
         ROL  Long_CT+1
         ROL  A                 ; rotate letter into A
         DEY
         BNE  _lplet            ; next bit

         ADC  #$3f              ; add offset (C = 0)
         JSR  CHROUT            ; and print it
         DEX
         BNE  _lpmne            ; next letter

         BBS6 Op_Flag,_mne5     ; long branch

;        check for 4-letter bit instructions

         LDA  Op_Code
         AND  #15
         CMP  #7                ; RMB & SMB
         BEQ  _biti
         CMP  #15               ; BBR & BBS
         BNE  _mne4
         SMB7 Op_Flag           ; flag two operands
_biti    LDA  Op_Code
         AND  #%0111 0000
         ASL  A
         ROL  A
         ROL  A
         ROL  A
         ROL  A
         ORA  #'0'
         JSR  CHROUT
         BRA  _mne5

_mne4    JSR  Print_Blank
_mne5    JSR  Print_Blank
         LDA  #WHITE
         JSR  CHROUT

;        check for accumulator operand

         LDA  Op_Code
         LDX  #8
_lpaccu  DEX
         BMI  _oper
         CMP  ACCUMODE,X
         BNE  _lpaccu

         LDA  #'A'
         JSR  CHROUT
         JMP  _return

;        fetch and decode operand

_oper    LDX  Op_Size
         LBEQ _return           ; -> no operand

         BBR7 Adr_Flags,_laba   ; bit 7: immediate
         LDA  #'#'
         BRA  _labb
_laba    BBR6 Adr_Flags,_labc   ; bit 6: left (
         LDA  #'('
         BBR5 Op_Flag,_labb
         LDA  #'['
_labb    JSR  CHROUT
_labc    LDA  #'$'
         JSR  CHROUT

;        fetch operand to Long_CT

         LDY  #0
         STY  Long_CT+1
_lpfop   INY
         JSR  Fetch
         STA  Long_CT-1,Y
         CPY  Op_Size
         BCC  _lpfop

;        interpret address modes

         LDX  Op_Code
         LDA  LEN_ADM,X
         AND  #%0010 0000       ; branches
         BNE  _rel

;        print 16 bit operand hi/lo or 8 bit operand

         BBR5 Op_Flag,_proper
         LDA  Long_CT+1
         JSR  Print_Hex         ; [$nn],Z
         LDA  #']'
         JSR  CHROUT
         BRA  _labf

_proper  LDY  Op_Size
         BBR7 Op_Flag,_lpoper
         LDY  #1
_lpoper  LDA  Long_CT-1,Y
         JSR  Print_Hex
         DEY
         BNE  _lpoper

         BBR5 Adr_Flags,_labe   ; comma flag
         LDA  #','
         JSR  CHROUT

         BBR4 Adr_Flags,_labd   ; SP flag
         LDA  #'S'
         JSR  CHROUT
         LDA  #'P'
         JSR  CHROUT

_labd    BBR0 Adr_Flags,_labe   ; X flag
         LDA  #'X'
         JSR  CHROUT

_labe    BBR3 Adr_Flags,_labf   ; ) flag
         LDA  #')'
         JSR  CHROUT

_labf    BBR2 Adr_Flags,_labg   ; , flag
         LDA  #','
         JSR  CHROUT

         LDA  Adr_Flags
         AND  #%0000 0011 ; $03
         BEQ  _labg
         TAY
         LDA  Index_Char-1,Y
         JSR  CHROUT

;        fetch 2nd. operand for BBR and BBS

_labg    BBR7 Op_Flag,_return
         LDA  #','
         JSR  CHROUT
         LDA  #'$'
         JSR  CHROUT
         LDY  #2
         JSR  Fetch
         STA  Long_CT
         LDA  #0
         STA  Long_CT+1
         DEY
         STY  Op_Size           ; Op_Size = 1
         LDA  #3                ; offset for relative address
         BRA  _rela

_rel     LDA  #2                ; offset for relative address
_rela    PHA
         LDA  Op_Size           ; 1:short   2:long
         LSR  A
         ROR  A
         AND  Long_CT
         BPL  _labh
         LDA  #$ff              ; backward branch
         STA  Long_CT+1

_labh    PLX                    ; offset 2 or 3
_lpinw   INW  Long_CT
         DEX
         BNE  _lpinw

         CLC
         LDA  Long_CT
         ADC  Long_PC
         PHA
         LDA  Long_CT+1
         ADC  Long_PC+1
         TAX
         PLA
         JSR  Print_XA_Hex
         BBR7 Op_Flag,_return
         INC  Op_Size
_return  RTS
EndMod

**************
Module Get_LAC
**************

         DEC  Buf_Index
EndMod

**************
Module Got_LAC
**************

         PHY                    ; save Y
         PHZ                    ; save Z
         JSR  Read_Number
         BCS  _error
         LDA  COL
         CMP  #39
         BEQ  _noval
         JSR  Got_Char
         BNE  _delim
         DEC  Buf_Index
         LDA  COL
         BEQ  _noval
         BRA  _ok

_delim   CMP  #' '
         BEQ  _ok
         CMP  #','
         BEQ  _ok
_error   JMP  Mon_Error         ; stack is reset in Mon_Error

_noval   SEC
         BRA  _return
_ok      CLC
_return  PLZ
         PLY
         LDA  COL
         RTS
EndMod

******************
Module Read_Number
******************

         PHX
         PHY
         LDA  #0
         STA  COL               ; count columns read

         LDX  #3                ; clear result Long_AC
_clear   STA  Long_AC,X
         DEX
         BPL  _clear

_next    JSR  Get_Char          ; get 1st. character
         LBEQ _exit             ; -> empty input (COL = 0)
         CMP  #' '
         BEQ  _next             ; skip leading blanks

         LDY  #3                ; $ + % %
_prefix  CMP  Cons_Prefix,Y     ; Y = base index
         BEQ  _base             ; -> valid prefix
         DEY
         BPL  _prefix

         CMP  #$27              ; check for apostrophe
         BNE  _defhex           ; -> no prefix
         STA  COL               ; remember ' input
         LDX  Buf_Index
         LDA  Buffer,X
         BNE  _char
         LDA  #' '              ; default
         DEC  Buf_Index
_char    INC  Buf_Index
         INC  Buf_Index
         STA  Long_AC
         LDY  #2
         STY  Op_Bits
         JMP  _exit

_defhex  INY                    ; Y = 0
         DEC  Buf_Index
_base    LDA  Num_Bits,Y
         STA  Op_Bits

_digit   JSR  Get_Char
         BEQ  _exit             ; ? : ; and zero terminate
         CMP  #'0'
         BCC  _exit             ; NaN
         CMP  #':'
         BCC  _valid            ; 0-9
         CMP  #'A'
         BCC  _exit
         CMP  #'G'
         BCS  _exit
         SBC  #7                ; hex conversion
_valid   SBC  #'0'-1
         CMP  Num_Base,Y
         BCS  _error
         TAZ                    ; binary digit
         INC  COL
         CPY  #1                ; decimal
         BNE  _laba

         JSR  LAC_To_LDA
_laba    LDX  Op_Bits
_shift   ASL  Long_AC
         ROL  Long_AC+1
         ROW  Long_AC+2
         BCS  _error            ; overflow
         DEX
         BNE  _shift

         CPY  #1                ; decimal adjustment
         BNE  _labc
         CLC
         ROW  Long_DA
         ROW  Long_DA+2
         BCS  _error
         LDA  Long_DA              ; Long_AC = digit * 8
         ADC  Long_AC              ; Long_DA = digit * 2
         STA  Long_AC
         LDA  Long_DA+1
         ADC  Long_AC+1
         STA  Long_AC+1
         LDA  Long_DA+2
         ADC  Long_AC+2
         STA  Long_AC+2
         LDA  Long_DA+3
         ADC  Long_AC+3
         STA  Long_AC+3
         BCS  _error

_labc    CLC
         TZA                    ; digit
         ADC  Long_AC
         STA  Long_AC
         TXA                    ; X = 0
         ADC  Long_AC+1
         STA  Long_AC+1
         TXA
         ADC  Long_AC+2
         STA  Long_AC+2
         TXA
         ADC  Long_AC+3
         STA  Long_AC+3
         BCC  _digit
_error   SEC
         BRA  _return
_exit    CLC
_return  PLY
         PLX
         LDA  COL               ; # of digits
         RTS
EndMod

**************
Module Hex_LPC
**************

         LDX  Long_PC+3
         BEQ  _laba
         LDA  #YELLOW
         JSR  CHROUT
         TXA
         JSR  Print_Hex
         LDA  Long_PC+2
         JSR  Print_Hex
         LDA  #WHITE
         JSR  CHROUT
         BRA  _labb
_laba    LDA  Long_PC+2
         BEQ  _labb
         JSR  Print_Hex
_labb    LDX  Long_PC+1
         LDA  Long_PC
EndMod

*******************
Module Print_XA_Hex
*******************

         PHA
         TXA
         JSR  Print_Hex
         PLA
EndMod

**********************
Module Print_Hex_Blank
**********************

         JSR  Print_Hex
EndMod

******************
Module Print_Blank
******************

         LDA  #' '
         JMP  CHROUT
EndMod

***************
Module Print_CR
***************

         LDA  #13
         JMP  CHROUT
EndMod

***************
Module CR_Erase
***************

         JSR  PRIMM
         .BYTE "\r\eQ",0
         RTS
EndMod

****************
Module Print_Hex
****************

         PHX
         JSR  A_To_Hex
         JSR  CHROUT
         TXA
         PLX
         JMP  CHROUT
EndMod

***************
Module A_To_Hex
***************

         PHA
         JSR  _nibble
         TAX
         PLA
         LSR  A
         LSR  A
         LSR  A
         LSR  A

_nibble  AND  #15
         CMP  #10
         BCC  _lab
         ADC  #6
_lab     ADC  #'0'
         RTS
EndMod

***************
Module Got_Char
***************

         DEC  Buf_Index
EndMod

***************
Module Get_Char
***************

         PHX
         LDX  Buf_Index
         INC  Buf_Index
         LDA  Buffer,X
         CPX  #1
         PLX
         BCC  _regc
         CMP  #';'            ; register
         BEQ  _return
         CMP  #'?'            ; help
         BEQ  _return
_regc    CMP  #0
         BEQ  _return
         CMP  #':'
_return  RTS
EndMod

**************
Module Dec_LDA
**************

         LDA  Long_DA
         ORA  Long_DA+1
         BNE  _skip
         DEW  Long_DA+2
_skip    DEW  Long_DA
         RTS
EndMod

**************
Module Dec_LCT
**************

         LDA  Long_CT
         ORA  Long_CT+1
         BNE  _skip
         DEW  Long_CT+2
_skip    DEW  Long_CT
         LDA  Long_CT+3         ; set N flag
         RTS
EndMod

**************
Module Add_LPC
**************

         CLC
         ADC  Long_PC
         STA  Long_PC
         BCC  _return
         INC  Long_PC+1
         BNE  _return
         INW  Long_PC+2
_return  RTS

******************
Module Param_Range
******************

; read two (address) parameters

; Long_CT = difference (2nd. minus 1st.)
; Long_PC = 1st. parameter
; Long_DA = 2nd. parameter

; carry on exit flags error

         BCS  _error
         JSR  LAC_To_LPC
         JSR  Got_LAC
         BCS  _error
         JSR  LAC_To_LDA
         JSR  LAC_Minus_LPC
         JSR  LAC_To_LCT
         BCC  _error
         CLC
         RTS
_error   SEC
         RTS
EndMod

****************
Module Converter
****************

         LDX  #0
         STX  Buf_Index
         JSR  Got_LAC
         LDX  #0
_loop    PHX
         JSR  CR_Erase
         LDA  Cons_Prefix,X
         JSR  CHROUT
         TXA
         ASL  A
         TAX
         JSR  (Conv_Tab,X)
         PLX
         INX
         CPX  #4
         BCC  _loop
         JMP  Main

Conv_Tab .WORD Print_Hexval
         .WORD Print_Decimal
         .WORD Print_Octal
         .WORD Print_Dual
EndMod

*****************
Module Print_Dual
*****************

         LDX  #24               ; digits
         LDY  #1                ; bits per digit
         BRA  _entry

***********
Print_Octal
***********

         LDX  #8                ; digits
         LDY  #3                ; bits per digit

_entry   JSR  LAC_To_LCT
         LDZ  #0
         STZ  Long_PC
         LDZ  #'0'
         PHY                    ; save start value
_loopa   PLY                    ; reinitialise
         PHY
         LDA  #0
_loopb   ASL  Long_CT
         ROW  Long_CT+1
         ROL  A
         DEY
         BNE  _loopb
         CPX  #1                ; print last character
         BEQ  _skip
         ORA  Long_PC
         BEQ  _next
_skip    ORA  #'0'
         STZ  Long_PC
         JSR  CHROUT
_next    DEX
         BNE  _loopa
         PLY                    ; cleanup stack
         RTS
EndMod

*******************
Module Print_Hexval
*******************

        JSR  LAC_To_LPC
        LDA  #0
        STA  Long_PC+3
        BRA  Print_BCD
EndMod

********************
Module Print_Decimal
********************

; max $ffffff = 16777215 (8 digits)

         JSR  LAC_To_LCT
         LDX  #3                ; 4 BCD bytes = 8 digits
         LDA  #0
_clear   STA  Long_PC,X
         DEX
         BPL  _clear

         LDX  #32               ; source bits
         SED
_loop    ASL  Long_CT
         ROL  Long_CT+1
         ROW  Long_CT+2
         LDA  Long_PC
         ADC  Long_PC
         STA  Long_PC
         LDA  Long_PC+1
         ADC  Long_PC+1
         STA  Long_PC+1
         LDA  Long_PC+2
         ADC  Long_PC+2
         STA  Long_PC+2
         LDA  Long_PC+3
         ADC  Long_PC+3
         STA  Long_PC+3
         DEX
         BNE  _loop
         CLD
EndMod

****************
Module Print_BCD
****************

         LDA  #0
         STA  Long_CT
         LDZ  #'0'
         LDY  #8                ; max. digits
_loopa   LDX  #3                ; 4 bytes
         LDA  #0
_loopb   ASL  Long_PC
         ROL  Long_PC+1
         ROW  Long_PC+2
         ROL  A
         DEX
         BPL  _loopb

         CPY  #1                ; print last character
         BEQ  _skip
         ORA  Long_CT
         BEQ  _next
_skip    ORA  #'0'
         STZ  Long_CT
         CMP  #$3a
         BCC  _print
         ADC  #6                ; + carry
_print   JSR  CHROUT
_next    DEY
         BNE  _loopa
         RTS
EndMod


***************
Module Mon_Disk
***************

         LDX  #1
         LDA  Buffer,X
         CMP  #'$'
         BEQ  _laba

; calculate length of string

         LDX  Buf_Index
         LDA  Buffer,X
_laba    STA  Long_CT
         PHX
         LDA  #-1

_loopa   INC  A
         INX
         LDY  Buffer-1,X
         BNE  _loopa

         PLX                    ; address low
         LDY  #>Buffer          ; address high
         JSR  SETNAM

         LDY  #15               ; SA = command
         LDA  Long_CT
         CMP  #'$'
         BNE  _nodir
         LDY  #$60              ; SA = directory
_nodir   LDA  #0                ; lfn for PRG reading
         LDX  Long_AC              ; device
         JSR  SETLFS
         JSR  OPEN
         BCS  _return
         JSR  CLRCHN
         JSR  Print_CR
         LDX  #0
         JSR  CHKIN
         BCS  _return
         LDA  Long_CT
         CMP  #'$'
         CLC
_return  RTS
EndMod

**************
Module Mon_DOS
**************

         BNE  _device
         LDX  #8                ; default device
         STX  Long_AC
_device  LDX  Long_AC              ; device

         CPX  #4
         LBCC Mon_Error
         CPX  #31
         LBCS Mon_Error

         JSR  Mon_Disk
         BCS  DOS_Exit
         BEQ  Directory

_loop    JSR  CHRIN
         JSR  CHROUT
         LDX  STATUS
         BNE  DOS_Exit
         CMP  #' '
         BCS  _loop
EndMod

***************
Module DOS_Exit
***************

         JSR  CLRCHN
         LDA  #0                ; lfn
         SEC                    ; special CLOSE
         JSR  CLOSE
         JMP  Main
EndMod

****************
Module Directory
****************

         LDZ  #6                ; load address, pseudo link, pseudo number
_loopb   TAX                    ; X = previous byte
         JSR  CHRIN             ; A = current  byte
         LDY  STATUS
         BNE  DOS_Exit
         DEZ
         BNE  _loopb            ; X/A = last read word

         STX  Long_AC
         STA  Long_AC+1
         JSR  Print_Decimal     ; file size
         JSR  Print_Blank

_loopc   JSR  CHRIN             ; print file entry
         BEQ  _cr
         LDY  STATUS
         BNE  DOS_Exit
         JSR  CHROUT
         BCC  _loopc

_cr      JSR  Print_CR
         JSR  STOP
         BEQ  DOS_Exit
         LDZ  #4
         BRA  _loopb            ; next file
EndMod

; The 3 letter mnemonics are encoded as three 5-bit values
; and stored in a left byte MNE_L and a right byte MNE_R
; The 5 bit value is computed by subtracting $3f from the
; ASCII value, so '?'-> 0, '@'->1, 'A'->2, 'B'->3,'Z'->27
; For example "ADC" is encoded as 2, 5, 4
; ----------------
; 7654321076543210
; 00010
;      00101
;           00100
;                0
;
; The operator >" stores the right byte of the packed value
; The operator <" stores the left  byte of the packed value

*****
MNE_L
*****

         .BYTE >"ADC"
         .BYTE >"AND"
         .BYTE >"ASL"
         .BYTE >"ASR"
         .BYTE >"ASW"
         .BYTE >"BBR"
         .BYTE >"BBS"
         .BYTE >"BCC"
         .BYTE >"BCS"
         .BYTE >"BEQ"
         .BYTE >"BIT"
         .BYTE >"BMI"
         .BYTE >"BNE"
         .BYTE >"BPL"
         .BYTE >"BRA"
         .BYTE >"BRK"
         .BYTE >"BSR"
         .BYTE >"BVC"
         .BYTE >"BVS"
         .BYTE >"CLC"
         .BYTE >"CLD"
         .BYTE >"CLE"
         .BYTE >"CLI"
         .BYTE >"CLV"
         .BYTE >"CMP"
         .BYTE >"CPX"
         .BYTE >"CPY"
         .BYTE >"CPZ"
         .BYTE >"DEC"
         .BYTE >"DEW"
         .BYTE >"DEX"
         .BYTE >"DEY"
         .BYTE >"DEZ"
         .BYTE >"EOR"
         .BYTE >"INC"
         .BYTE >"INW"
         .BYTE >"INX"
         .BYTE >"INY"
         .BYTE >"INZ"
         .BYTE >"JMP"
         .BYTE >"JSR"
         .BYTE >"LDA"
         .BYTE >"LDX"
         .BYTE >"LDY"
         .BYTE >"LDZ"
         .BYTE >"LSR"
         .BYTE >"MAP"
         .BYTE >"NEG"
         .BYTE >"NOP"
         .BYTE >"ORA"
         .BYTE >"PHA"
         .BYTE >"PHP"
         .BYTE >"PHW"
         .BYTE >"PHX"
         .BYTE >"PHY"
         .BYTE >"PHZ"
         .BYTE >"PLA"
         .BYTE >"PLP"
         .BYTE >"PLX"
         .BYTE >"PLY"
         .BYTE >"PLZ"
         .BYTE >"RMB"
         .BYTE >"ROL"
         .BYTE >"ROR"
         .BYTE >"ROW"
         .BYTE >"RTI"
         .BYTE >"RTS"
         .BYTE >"SBC"
         .BYTE >"SEC"
         .BYTE >"SED"
         .BYTE >"SEE"
         .BYTE >"SEI"
         .BYTE >"SMB"
         .BYTE >"STA"
         .BYTE >"STX"
         .BYTE >"STY"
         .BYTE >"STZ"
         .BYTE >"TAB"
         .BYTE >"TAX"
         .BYTE >"TAY"
         .BYTE >"TAZ"
         .BYTE >"TBA"
         .BYTE >"TRB"
         .BYTE >"TSB"
         .BYTE >"TSX"
         .BYTE >"TSY"
         .BYTE >"TXA"
         .BYTE >"TXS"
         .BYTE >"TYA"
         .BYTE >"TYS"
         .BYTE >"TZA"

*****
MNE_R
*****

         .BYTE <"ADC" ; 00
         .BYTE <"AND" ; 01
         .BYTE <"ASL" ; 02
         .BYTE <"ASR" ; 03
         .BYTE <"ASW" ; 04
         .BYTE <"BBR" ; 05
         .BYTE <"BBS" ; 06
         .BYTE <"BCC" ; 07
         .BYTE <"BCS" ; 08
         .BYTE <"BEQ" ; 09
         .BYTE <"BIT" ; 0a
         .BYTE <"BMI" ; 0b
         .BYTE <"BNE" ; 0c
         .BYTE <"BPL" ; 0d
         .BYTE <"BRA" ; 0e
         .BYTE <"BRK" ; 0f
         .BYTE <"BSR" ; 10
         .BYTE <"BVC" ; 11
         .BYTE <"BVS" ; 12
         .BYTE <"CLC" ; 13
         .BYTE <"CLD" ; 14
         .BYTE <"CLE" ; 15
         .BYTE <"CLI" ; 16
         .BYTE <"CLV" ; 17
         .BYTE <"CMP" ; 18
         .BYTE <"CPX" ; 19
         .BYTE <"CPY" ; 1a
         .BYTE <"CPZ" ; 1b
         .BYTE <"DEC" ; 1c
         .BYTE <"DEW" ; 1d
         .BYTE <"DEX" ; 1e
         .BYTE <"DEY" ; 1f
         .BYTE <"DEZ"
         .BYTE <"EOR"
         .BYTE <"INC"
         .BYTE <"INW"
         .BYTE <"INX"
         .BYTE <"INY"
         .BYTE <"INZ"
         .BYTE <"JMP"
         .BYTE <"JSR"
         .BYTE <"LDA"
         .BYTE <"LDX"
         .BYTE <"LDY"
         .BYTE <"LDZ"
         .BYTE <"LSR"
         .BYTE <"MAP"
         .BYTE <"NEG"
         .BYTE <"NOP"
         .BYTE <"ORA"
         .BYTE <"PHA"
         .BYTE <"PHP"
         .BYTE <"PHW"
         .BYTE <"PHX"
         .BYTE <"PHY"
         .BYTE <"PHZ"
         .BYTE <"PLA"
         .BYTE <"PLP"
         .BYTE <"PLX"
         .BYTE <"PLY"
         .BYTE <"PLZ"
         .BYTE <"RMB"
         .BYTE <"ROL"
         .BYTE <"ROR"
         .BYTE <"ROW"
         .BYTE <"RTI"
         .BYTE <"RTS"
         .BYTE <"SBC"
         .BYTE <"SEC"
         .BYTE <"SED"
         .BYTE <"SEE"
         .BYTE <"SEI"
         .BYTE <"SMB"
         .BYTE <"STA"
         .BYTE <"STX"
         .BYTE <"STY"
         .BYTE <"STZ"
         .BYTE <"TAB"
         .BYTE <"TAX"
         .BYTE <"TAY"
         .BYTE <"TAZ"
         .BYTE <"TBA"
         .BYTE <"TRB"
         .BYTE <"TSB"
         .BYTE <"TSX"
         .BYTE <"TSY"
         .BYTE <"TXA"
         .BYTE <"TXS"
         .BYTE <"TYA"
         .BYTE <"TYS"
         .BYTE <"TZA"

*********
MNE_Index
*********

; an index for all 256 opcodes, describing
; where to find the 3-letter mnemonic

         .BYTE $0f,$31,$15,$46,$53,$31,$02,$3d
         .BYTE $33,$31,$02,$55,$53,$31,$02,$05
         .BYTE $0d,$31,$31,$0d,$52,$31,$02,$3d
         .BYTE $13,$31,$22,$26,$52,$31,$02,$05
         .BYTE $28,$01,$28,$28,$0a,$01,$3e,$3d
         .BYTE $39,$01,$3e,$59,$0a,$01,$3e,$05
         .BYTE $0b,$01,$01,$0b,$0a,$01,$3e,$3d
         .BYTE $44,$01,$1c,$20,$0a,$01,$3e,$05
         .BYTE $41,$21,$2f,$03,$03,$21,$2d,$3d
         .BYTE $32,$21,$2d,$50,$27,$21,$2d,$05
         .BYTE $11,$21,$21,$11,$03,$21,$2d,$3d
         .BYTE $16,$21,$36,$4d,$2e,$21,$2d,$05
         .BYTE $42,$00,$42,$10,$4c,$00,$3f,$3d
         .BYTE $38,$00,$3f,$5a,$27,$00,$3f,$05
         .BYTE $12,$00,$00,$12,$4c,$00,$3f,$3d
         .BYTE $47,$00,$3b,$51,$27,$00,$3f,$05
         .BYTE $0e,$49,$49,$0e,$4b,$49,$4a,$48
         .BYTE $1f,$0a,$56,$4b,$4b,$49,$4a,$06
         .BYTE $07,$49,$49,$07,$4b,$49,$4a,$48
         .BYTE $58,$49,$57,$4a,$4c,$49,$4c,$06
         .BYTE $2b,$29,$2a,$2c,$2b,$29,$2a,$48
         .BYTE $4f,$29,$4e,$2c,$2b,$29,$2a,$06
         .BYTE $08,$29,$29,$08,$2b,$29,$2a,$48
         .BYTE $17,$29,$54,$2c,$2b,$29,$2a,$06
         .BYTE $1a,$18,$1b,$1d,$1a,$18,$1c,$48
         .BYTE $25,$18,$1e,$04,$1a,$18,$1c,$06
         .BYTE $0c,$18,$18,$0c,$1b,$18,$1c,$48
         .BYTE $14,$18,$35,$37,$1b,$18,$1c,$06
         .BYTE $19,$43,$29,$23,$19,$43,$22,$48
         .BYTE $24,$43,$30,$40,$19,$43,$22,$06
         .BYTE $09,$43,$43,$09,$34,$43,$22,$48
         .BYTE $45,$43,$3a,$3c,$34,$43,$22,$06

*****
BRAIN
*****

;              index values for branch mnemonics

;              BCC BCS BEQ BMI BNE BPL BRA BSR BVC BVS
         .BYTE $07,$08,$09,$0b,$0c,$0d,$0e,$10,$11,$12

*******
LEN_ADM
*******

; a table of instruction length, flags
; and address mode for all 256 opcodes

; 7-6: operand length %00.. 0: implied
;                     %01.. 1: direct page, indirect
;                     %10.. 2: absolute, etc.
;                     %11.. 3: BBR and BBS

;   5: relative       %0110 0000 $60 short branch
;                     %1010 0000 $a0 long  branch

;   4:

; 3-0: index of address mode

 ( %11...... BBR BBS)

         .BYTE $00,$44,$00,$00,$40,$40,$40,$40 ; $00
         .BYTE $00,$41,$00,$00,$80,$80,$80,$c0 ; $08
         .BYTE $60,$45,$46,$a0,$40,$47,$47,$40 ; $10
         .BYTE $00,$88,$00,$00,$80,$87,$87,$c0 ; $18
         .BYTE $80,$44,$8b,$84,$40,$40,$40,$40 ; $20
         .BYTE $00,$41,$00,$00,$80,$80,$80,$c0 ; $28
         .BYTE $60,$45,$46,$a0,$47,$47,$47,$40 ; $30
         .BYTE $00,$88,$00,$00,$87,$87,$87,$c0 ; $38
         .BYTE $00,$44,$00,$00,$40,$40,$40,$40 ; $40
         .BYTE $00,$41,$00,$00,$80,$80,$80,$c0 ; $48
         .BYTE $60,$45,$46,$a0,$47,$47,$47,$40 ; $50
         .BYTE $00,$88,$00,$00,$00,$87,$87,$c0 ; $58
         .BYTE $00,$44,$41,$a0,$40,$40,$40,$40 ; $60
         .BYTE $00,$41,$00,$00,$8b,$80,$80,$c0 ; $68
         .BYTE $60,$45,$46,$a0,$47,$47,$47,$40 ; $70
         .BYTE $00,$88,$00,$00,$84,$87,$87,$c0 ; $78
         .BYTE $60,$44,$4d,$a0,$40,$40,$40,$40 ; $80
         .BYTE $00,$41,$00,$87,$80,$80,$80,$c0 ; $88
         .BYTE $60,$45,$46,$a0,$47,$47,$48,$40 ; $90
         .BYTE $00,$88,$00,$88,$80,$87,$87,$c0 ; $98
         .BYTE $41,$44,$41,$41,$40,$40,$40,$40 ; $a0
         .BYTE $00,$41,$00,$80,$80,$80,$80,$c0 ; $a8
         .BYTE $60,$45,$46,$a0,$47,$47,$48,$40 ; $b0
         .BYTE $00,$88,$00,$87,$87,$87,$88,$c0 ; $b8
         .BYTE $41,$44,$41,$40,$40,$40,$40,$40 ; $c0
         .BYTE $00,$41,$00,$80,$80,$80,$80,$c0 ; $c8
         .BYTE $60,$45,$46,$a0,$40,$47,$47,$40 ; $d0
         .BYTE $00,$88,$00,$00,$80,$87,$87,$c0 ; $d8
         .BYTE $41,$44,$4d,$40,$40,$40,$40,$40 ; $e0
         .BYTE $00,$41,$00,$80,$80,$80,$80,$c0 ; $e8
         .BYTE $60,$45,$46,$a0,$81,$47,$47,$40 ; $f0
         .BYTE $00,$88,$00,$00,$80,$87,$87,$c0 ; $f8

******
ADMODE
******

; printout flags for 16 address modes
;               76543210
;               --------
;            7  x         #
;            6   x        (
;            5    x       ,
;            4     x      SP
;            3      x     )
;            2       x    ,
;            1/0      xx  01:X  10:Y  11:Z

         .BYTE %00000000 ; 0             implicit/direct
         .BYTE %10000000 ; 1 #$nn        immediate
         .BYTE %00000000 ; 2             ----------
         .BYTE %00000000 ; 3             ----------
         .BYTE %01101001 ; 4 ($nn,X)     indirect X
         .BYTE %01001110 ; 5 ($nn),Y     indirect Y
         .BYTE %01001111 ; 6 ($nn),Z     indirect Z
         .BYTE %00000101 ; 7 $nn,X       indexed  X
         .BYTE %00000110 ; 8 $nn,Y       indexed  Y
         .BYTE %00000101 ; 9 $nn,X       indexed  X
         .BYTE %00000110 ; a $nn,Y       ----------
         .BYTE %01001000 ; b ($nnnn,X)   JMP & JSR
         .BYTE %01101001 ; c ($nn,X)     ----------
         .BYTE %01111110 ; d ($nn,SP),Y  LDA & STA
         .BYTE %00000000 ; e
         .BYTE %00000100 ; f

;              ASL INC ROL DEC LSR ROR NEG ASR
ACCUMODE .BYTE $0a,$1a,$2a,$3a,$4a,$6a,$42,$43

Num_Base .BYTE 16,10, 8, 2 ; hex, dec, oct, bin
Num_Bits .BYTE  4, 3, 3, 1 ; hex, dec, oct, bin

Index_Char .BYTE "XYZ"

***************
Module Reg_Text
***************
         JSR  PRIMM
         .BYTE "\r    PC   SR AC XR YR ZR BP  SP  NVEBDIZC\r; \eQ",0
         RTS
EndMod

***************
Module Mon_Help
***************
   JSR PRIMM

   .BYTE LRED,"A",WHITE,"SSEMBLE     - A ADDRESS MNEMONIC OPERAND",CR
   .BYTE LRED,"C",WHITE,"OMPARE      - C FROM TO WITH",CR
   .BYTE LRED,"D",WHITE,"ISASSEMBLE  - D [FROM [TO]]",CR
   .BYTE LRED,"F",WHITE,"ILL         - F FROM TO FILLBYTE",CR
   .BYTE LRED,"G",WHITE,"O           - G [ADDRESS]",CR
   .BYTE LRED,"H",WHITE,"UNT         - H FROM TO (STRING OR BYTES)",CR
   .BYTE LRED,"J",WHITE,"SR          - J ADDRESS",CR
   .BYTE LRED,"L",WHITE,"OAD         - L FILENAME [UNIT [ADDRESS]]",CR
   .BYTE LRED,"M",WHITE,"EMORY       - M [FROM [TO]]",CR
   .BYTE LRED,"R",WHITE,"EGISTERS    - R",CR
   .BYTE LRED,"S",WHITE,"AVE         - S FILENAME UNIT FROM TO",CR
   .BYTE LRED,"T",WHITE,"RANSFER     - T FROM TO TARGET",CR
   .BYTE LRED,"V",WHITE,"ERIFY       - V FILENAME [UNIT [ADDRESS]]",CR
   .BYTE "E",LRED,"X",WHITE,"IT         - X",CR
   .BYTE LRED,".",WHITE,"<DOT>       - . ADDRESS MNEMONIC OPERAND",CR
   .BYTE LRED,">",WHITE,"<GREATER>   - > ADDRESS BYTE SEQUENCE",CR
   .BYTE LRED,";",WHITE,"<SEMICOLON> - ; REGISTER CONTENTS",CR
   .BYTE LRED,"@",WHITE,"DOS         - @ [DOS COMMAND]",CR
   .BYTE LRED,"?",WHITE,"HELP        - ?",CR
   .BYTE 0
   JMP Main
End_Mod

         .FILL $8000-* ($ff) ; 3749 bytes

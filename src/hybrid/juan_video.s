; Taken from AmiGameBoy 1.0 by Juan Antonio Gomez Galvez (1996-97), sent to the
; AmiGameBoy project 13 Oct 2026 with "use them as you want". Changes for the hybrid
; (C) 2026, GPL-2 with the rest of the hybrid; see git history.
; Source: src/AmiGameBoy_Main.asm, the line ranges named below.

; ==== AmiGameBoy_Main.asm 130-331: InitSistema and the table builders (OBJ, sprite bases, copper lines)
InitSistema:			; hybrid: no Z80 opcode table (ArrTabInst)

	LEA	Regs,A3
	BSR	CreaTabOBJ
	BSR	CreaDirBaseGFX
	BSR	CreaCoppLine
	BSR	CreaDirGFX

	BSR	InitCoorSpr
	RTS

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
	CNOP	0,8
CreaDirGFX:
	LEA	SprGfx0,A0
	LEA	TablaDirGFX,A1
	MOVEQ	#0,D1
	MOVE.W	#(256)-1,D0
CrDiGFBuc:
	MOVE.L	A0,A2

	BTST	#3,D1
	BEQ.S	CrDiGFCon0
	ADD.L	#SIGSPR,A2
CrDiGFCon0:
	BTST	#4,D1
	BEQ.S	CrDiGFCon1
	ADD.L	#OTRSPR,A2
CrDiGFCon1:
	MOVE.L	A2,(A1)+

	MOVE.L	A0,A2

	BTST	#6,D1
	BEQ.S	CrDiGFCon2
	ADD.L	#SIGSPR,A2
CrDiGFCon2:
	BTST	#4,D1
	BEQ.S	CrDiGFCon3
	ADD.L	#OTRSPR,A2
CrDiGFCon3:
	MOVE.L	A2,(A1)+

	ADDQ.B	#1,D1
	DBF	D0,CrDiGFBuc
	RTS
; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
CoppLineSize=$18
	CNOP	0,8
CreaCoppLine:
	MOVE.L	#$4771FFFE,D1
	LEA	CopperLine,A0
	MOVE.L	#CopperRet,D3
;;	MOVE.L	A0,D2
;;	ADD.L	#(CoppLineSize),D2
	MOVE.W	#(145)-1,D0
CrCoLiBuc:
	MOVE.L	D1,(A0)+		; $00 - Wait

;;	MOVE.W	#$0080,(A0)+		; $¿? - CoppNext
;;	SWAP	D2
;;	MOVE.W	D2,(A0)+
;;	MOVE.W	#$0082,(A0)+
;;	SWAP	D2
;;	MOVE.W	D2,(A0)+

	MOVE.W	#$0084,(A0)+		; $04 - CoppJump
	SWAP	D3
	MOVE.W	D3,(A0)+
	MOVE.W	#$0086,(A0)+
	SWAP	D3
	MOVE.W	D3,(A0)+

	MOVE.L	#$009C0000,(A0)+	; $0C - Inter Off
	MOVE.L	#$009C8000,(A0)+	; $10 - Inter On

	MOVE.L	#$01A00000,(A0)+	; $14 - ExeCoppJump
	ADD.L	#$01000000,D1
;;	ADD.L	#(CoppLineSize),D2
	DBF	D0,CrCoLiBuc
	RTS

;	DC.W	$47C1,$FFFE	; $00
;	DC.W	$0084,$0000	; $04
;	DC.W	$0086,$8000	; $08
;	DC.W	$009C,$0003	; $0C
;	DC.W	$009C,$8000	; $10
;	DC.W	$008A,$0000	; $14

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
	CNOP	0,8
CreaTabOBJ:
	LEA	TablaOBJFlip0,A0
	LEA	TablaOBJFlip1,A1

	MOVEQ	#0,D1
	MOVEQ	#0,D3
	MOVE.W	#($100)-1,D0
CrTaOBJBuc:
	MOVE.W	D1,D2
	MOVE.W	D2,(A0)+
	REPT	8
	LSR.B	#1,D2
	ADDX.B	D3,D3
	ENDR
	MOVE.W	D3,(A1)+
	ADDQ.B	#1,D1
	DBF	D0,CrTaOBJBuc
	RTS
; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
CreaDirBaseGFX:
	LEA	DirBaseGFX,A1
	LEA	VRAM,A0
	MOVE.W	#($100)-1,D0
CrDiBaBuc:
	MOVE.L	A0,(A1)+
	ADD.W	#16,A0
	DBF	D0,CrDiBaBuc
	LEA	VRAM+$1000,A0
	MOVE.W	#($80)-1,D0
CrDiBaBuc0:
	MOVE.L	A0,(A1)+
	ADD.W	#16,A0
	DBF	D0,CrDiBaBuc0
	LEA	VRAM+$800,A0
	MOVE.W	#($80)-1,D0
CrDiBaBuc1:
	MOVE.L	A0,(A1)+
	ADD.W	#16,A0
	DBF	D0,CrDiBaBuc1
	LEA	VRAM,A0
	MOVE.W	#($80)-1,D0
CrDiBaBuc2:
	MOVE.L	A0,(A1)+
	MOVE.L	A0,(A1)+
	ADD.W	#32,A0
	DBF	D0,CrDiBaBuc2
	RTS
; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
INISPR=$48
FINSPR=$48+$90
	CNOP	0,4
InitCoorSpr:
	MOVE.W	#INISPR*$100+$50,SpritM
	MOVE.W	#FINSPR*$100+$80,SpritM+8


	LEA	TabSprCoor,A0
	MOVE.W	#$B0+$00,D4		; Coordenada X Base.
	MOVE.W	#$B0+$40,D5
	MOVE.W	#$B0+$80,D6
	MOVE.W	#$B0+$C0,D7

	MOVE.W	#(256)-1,D0
InCorBuc:

	MOVE.W	D4,D2
	BSR.S	InCorRut
	MOVE.W	D2,D4
	MOVE.W	D5,D2
	BSR.S	InCorRut
	MOVE.W	D2,D5
	MOVE.W	D6,D2
	BSR.S	InCorRut
	MOVE.W	D2,D6
	MOVE.W	D7,D2
	BSR.S	InCorRut
	MOVE.W	D2,D7

	DBF	D0,InCorBuc
	RTS

InCorRut:
	CMP.W	#$A0-64,D2
	BCC.S	InCorCon0
	ADD.W	#$100,D2
	BRA.S	InCorRut
InCorCon0:

	MOVE.W	D2,D1
	LSR.W	#1,D1
	AND.W	#$00FF,D1
	OR.W	#INISPR*$100,D1
	MOVE.W	D1,(A0)+

	MOVE.W	D2,D1
	AND.W	#$0001,D1
	OR.W	#FINSPR*$100+$00,D1
	MOVE.W	D1,(A0)+
	SUBQ.W	#1,D2
	RTS

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-


; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
; -=--------------------------------------------------=-
; -=--------------------------------------------------=-
; -=--------------------------------------------------=-
; -=--------------------------------------------------=-


; ==== AmiGameBoy_Main.asm 334-370: offsets into Regs
IFF=1
EstadoJoy=2
MapROMBase=6
SalirMenu=$A
ModoTraza=$B
EstadoKeys=$C
MaskROM=$10
MaskRAM=$12
PetIntGB=$14
RasterInt=$15
DirIntGB=$16
ExeIntGB=$18

D40=$20
Contador1=-$CC

;;ScrResAnt=-$C8
IntGB1Ant=-$C4

UltCopLin=-$CA
UltCoorY=-$C9

PagRead=-$40
PagWrite=-$20
Restas=-$80
Desbor=-$C0-Restas

TabRedef=$1000

; -=-

TAB_Flags=$7C
Flags_Par=$7C
Flags_Push=$7D
Flags_Pop=$7E
Flags_DAA=$7F


; ==== AmiGameBoy_Main.asm 379-385: BorraMem
; ------------------------------------> Borra memoria. (A0=Dir.MEM) D0.w=(x/4)-1
	CNOP	0,4
BorraMem:
	CLR.L	(A0)+
	DBF	D0,BorraMem
	RTS
; ------------------------------------<

; ==== AmiGameBoy_Main.asm 2948-2954: per-line register log (TabRasDATA/REST/CMDS)

		CNOP	0,8
TabRasDATA:	DS.L	148*2
		DC.W	0,0	<=- No Quitar.
TabRasREST:	DS.L	148
TabRasCMDS:	DS.B	148
	CNOP	0,8

; ==== AmiGameBoy_Main.asm 3554-3705: CongelaAMIGA / DescongelaAMIGA (system take-over)
;;	-=-=-=-==-=-=-=-=-=-=-
	CNOP	0,8
DameVBR:MOVEC	VBR,A0
	MOVE.L	A0,VBRPun
	NOP
	RTE
	CNOP	0,8
CongelaAMIGA:
;;	-=-=-=-==-=-=-=-=-=-=-
	LEA	DameVBR(PC),A5
	MOVE.L	$4.W,A6
	JSR	-$1E(A6)
;;	-=-=-=-==-=-=-=-=-=-=-
	MOVE.L	$4.W,A5
	MOVE.L	$9C(A5),A5
	MOVE.L	$26(A5),WBCopp
;;	-=-=-=-==-=-=-=-=-=-=-
	LEA	$DFF000,A6
	MOVE.W	#$7FFF,D7
	MOVE.W	$1C(A6),INTENA
	MOVE.W	D7,$9A(A6)
	MOVE.W	$1E(A6),INTREQ
	MOVE.W	D7,$9C(A6)
	MOVE.W	$02(A6),DMACON
	BTST	#6,DMACON+1
	BEQ.S	NoBliOn
EspBli:	NOP
	NOP
	BTST	#6,2(A6)
	BNE.S	EspBli
	NOP
	NOP
NoBliOn:MOVE.W	D7,$96(A6)
	NOP
	NOP
;;	-=-=-=-==-=-=-=-=-=-=-
	MOVE.L	#MasterCopper,$80(A6)
	NOP
	MOVE.L	#MasterCopper,$84(A6)
	NOP
	MOVE.W	#0,$88(A6)
	NOP
	NOP
	MOVE.W	#$0020,$09C(A6)
EspIntV:NOP
	NOP
	NOP
	NOP
	BTST	#$05,$01F(A6)
	BEQ.S	EspIntV
	NOP
	MOVE.W	#$83A0,$096(A6)	; ---,BLTPriDMA,BPL;COP,BLT,SPR,DSK;AUD3-0
;;	-=-=-=-==-=-=-=-=-=-=-
	SF	$BFEC01
;;	-=-=-=-==-=-=-=-=-=-=-
	MOVE.L	VBRPun,A0
	MOVE.L	$24(A0),Traza
	MOVE.L	$6C(A0),VBlank
;;	-=-=-=-==-=-=-=-=-=-=-
	MOVE.L	#HyVBL,$6C(A0)		; hybrid: VBL counter (hybrid.asm)
;;	-=-=-=-==-=-=-=-=-=-=-
	LEA	DirPlanos,A0
	BSR	CreaPlanos
	LEA	DirColores,A0
	BSR	CreaColores
	LEA	DirSprites,A0
	BSR	CreaSprites
	LEA	DirSaltos,A0
	BSR	CreaSaltos
;;	-=-=-=-==-=-=-=-=-=-=-
	LEA	$BFE001,A6
	BFEXTU	(A6){6:1},D7		; Filtro.
	MOVE.B	D7,Filtro
	BSET	#1,$BFE001		; Filtro OFF
;;	-=-=-=-==-=-=-=-=-=-=-
	RTS

; ------------------------------------------------ ;
; ------------------------------------------------ ;
; ------------------------------------------------ ;
Salir:
	MOVEM.L	D0-D7/A0-A7,Debug

	MOVE.L	PILA,SP

DescongelaAMIGA:
;;	-=-=-=-==-=-=-=-=-=-=-
	MOVE.B	Filtro,D7
	LEA	$BFE001,A6
	BFINS	D7,(A6){6:1}		; Filtro.
;;	-=-=-=-==-=-=-=-=-=-=-
	MOVE.L	VBRPun,A0
	MOVE.L	Traza,$24(A0)
	MOVE.L	VBlank,$6C(A0)
;;	-=-=-=-==-=-=-=-=-=-=-
	LEA	$DFF000,A6
	MOVE.W	#$7FFF,D7
	MOVE.W	D7,$09A(A6)
	MOVE.W	#$8000,D6
	OR.W	D6,DMACON
	MOVE.W	D7,$096(A6)
	OR.W	D6,INTENA
	OR.W	D6,INTREQ
	MOVE.W	D7,$09C(A6)
	NOP
;;	-=-=-=-==-=-=-=-=-=-=-
	CLR.W	$180(A6)
	MOVE.L	WBCopp,$80(A6)
	NOP
	MOVE.L	WBCopp,$84(A6)
	NOP
	MOVE.W	#0,$88(A6)
	NOP
;;	-=-=-=-==-=-=-=-=-=-=-
	MOVE.W	#$8280,$096(A6)
	NOP
	NOP
	MOVE.W	#$0020,$09C(A6)
EspIntV0:NOP
	NOP
	NOP
	NOP
	BTST	#$05,$01F(A6)
	BEQ.S	EspIntV0
	NOP
	NOP
	NOP
	NOP
	MOVE.W	#$0020,$09C(A6)
EspIntV1:NOP
	NOP
	NOP
	NOP
	BTST	#$05,$01F(A6)
	BEQ.S	EspIntV1
	NOP
	MOVE.W	D7,$09C(A6)
	NOP
;;	-=-=-=-==-=-=-=-=-=-=-
	MOVE.W	DMACON,$096(A6)
	NOP
	NOP
	MOVE.W	INTREQ,$09C(A6)
	NOP
	NOP
	MOVE.W	INTENA,$09A(A6)
	NOP
	NOP
;;	-=-=-=-==-=-=-=-=-=-=-
	RTS
; ------------------------------------------------ ;

; ==== AmiGameBoy_Main.asm 3725-4199: EsActVDP frame tick, ActCopperLine copper compile
	CNOP	0,8
JoyControlRut:	DC.L	LeeJoyStick	; hybrid: from AmiGameBoy_Main.asm 108 (pad reader)
	CNOP	0,8
HyBuild:			; hybrid: Juan's EsActVDP as a subroutine (no sound, no RTE)
	MOVEM.L	D0-D7/A0-A6,-(SP)



	BSR	ActCopperLine



	BSR	ActualizaGFX

	BSR	PoneScrollBG
;;	BSR	PoneScrollWin

	BSR	GFXPrint

	BSR	OBJPrint
	IFND	NO_OBJMASK
	JSR	HyObjMask		; hybrid: sprites off on some lines
	ENDC


	BSR	PonePaleta


	MOVEM.L	(SP)+,D0-D7/A0-A6
	RTS

; hybrid: the pad and keyboard part of EsActVDP, every Game Boy frame (drawn or skipped)
	CNOP	0,8
HyPads:
	MOVEM.L	D0-D7/A0-A6,-(SP)
	JSR	([JoyControlRut.w,PC])
	BSR	MiraTeclado

	LEA	Regs(PC),A3
	MOVE.B	EstadoKeys(A3),D1	; Joypad
	AND.B	D1,EstadoJoy+2(A3)
	MOVE.B	EstadoKeys+1(A3),D1	; Botones
	AND.B	D1,EstadoJoy+1(A3)
	MOVE.B	EstadoKeys+2(A3),D1	; Botones
	AND.B	D1,EstadoJoy+1(A3)
	MOVEM.L	(SP)+,D0-D7/A0-A6
	RTS



; -========================================

ActCopperLine:

; ----------------------------------=> Pone ultima linea de desbordamiento de BG.
	MOVEQ	#0,D2
	SUB.B	RRAM+$1F42,D2
	CMP.B	#$90,D2
	BCC.S	AcCoCon1

	CMP.B	Regs+UltCopLin,D2		; Linea Anterior.
	BCS.S	AcCoCon1
	OR.B	#$01,(TabRasCMDS.L,D2.W)
AcCoCon1:
; ----------------------------------<=

; ----------------------------------=> Pone ultima linea de inicio de Win.
	BTST	#5,RRAM+$1F40	; ¿Win ON?
	BEQ.S	AcCoCon3
	MOVEQ	#0,D1
	MOVE.B	RRAM+$1F4A,D1
	CMP.B	#$91,D1
	BCC.S	AcCoCon3
	OR.B	#$02,(TabRasCMDS.L,D1.W)
	MOVE.L	TabRasDATA+0,(TabRasDATA.L,D1.W*8)
	IFND	NO_BGXWY		; hybrid: window Y for the BG clip on this line too
	MOVE.B	RRAM+$1F4A,(TabRasDATA+4.L,D1.W*8)
	ENDC
AcCoCon3:
; ----------------------------------<=

; ----------------------------------=> Borra CopperLine de frame anterior.
	LEA	TabRasREST-2,A0
	MOVE.W	(A0),D0
	BMI.S	AcCoCon0
	MOVE.W	#-1,(A0)+
AcCoBuc0:
	MOVE.W	#$01A0,([A0])
	ADDQ.W	#4,A0
	DBF	D0,AcCoBuc0
AcCoCon0:
; ----------------------------------<=

; ----------------------------------=> Pone el estado de Win Off/On
	BTST	#5,TabRasDATA+1		; Control
	SNE	UltWinOn
; ----------------------------------<=

	LEA	TabRasREST,A2
	LEA	CopperOpts,A3

	LEA	TabRasCMDS,A6
	MOVE.W	#(144)-1,D6
	MOVEQ	#0,D7
AcCoBuc:
	TST.B	(A6)+
	BNE	AcCoRut
AcCoRet:
	ADDQ.B	#1,D7
	DBF	D6,AcCoBuc

	RTS

; hybrid: called at the start of LY 0 (hybrid_line0), after the vertical blank, so the
; top of the picture gets the registers the game set in its VBlank handler
ActCopperLine0:
; ----------------------------------=> Pone refresco de 1ª linea de CopperLine.
	MOVE.B	#$0F,TabRasCMDS
	MOVE.B	RRAM+$1F42,TabRasDATA+0	; BG Y
	MOVE.B	RRAM+$1F43,TabRasDATA+2	; BG X
	MOVE.B	RRAM+$1F40,TabRasDATA+1	; Control
	MOVE.B	RRAM+$1F4B,TabRasDATA+3	; Win X
	MOVE.B	RRAM+$1F4A,TabRasDATA+4	; Win Y
; ----------------------------------<=


; ----------------------------------=> Pone datos de posible desbordamiento de GB.
	MOVEQ	#0,D1
	SUB.B	RRAM+$1F42,D1

	CMP.B	#$90,D1
	BCS.S	AcCoCon2
	MOVE.B	#$91,D1
AcCoCon2:
	MOVE.B	D1,Regs+UltCoorY
	SF	Regs+UltCopLin		; Linea Anterior.
	MOVE.W	TabRasDATA+0,(TabRasDATA.L,D1.W*8)
; ----------------------------------<=


	RTS


	CNOP	0,8
AcCoRut:
	MOVE.B	-(A6),D5
	SF	(A6)+

	MOVE.W	D7,D1

	MULU	#(CoppLineSize),D1
	LEA	(CopperLine+$0A.L,D1.W),A4

	MOVE.L	A3,D3
	MOVE.W	D3,(A4)+
	SWAP	D3
	MOVE.W	D3,-6(A4)

	LEA	(CopperLine+(CoppLineSize).L,D1.W),A4
	MOVE.L	A4,-(SP)

	SUBQ.W	#4,A4
	MOVE.W	#$008A,(A4)

	MOVE.L	A4,(A2)+
	ADDQ.W	#1,TabRasREST-2

	IFEQ	ColorDebug			;*;
	MOVE.L	#$01800A00,(A3)+		;*;
	ENDC					;*;

	LSR.B	#1,D5
	BCS	AcCoRutBGY
AcCoRet0:
	LSR.B	#1,D5
	BCS	AcCoRutBGX
AcCoRet1:
	LSR.B	#1,D5
	BCS	AcCoRutWinY
AcCoRet2:
	LSR.B	#1,D5
	BCS	AcCoRutWinX
AcCoRet3:
	LSR.B	#1,D5
	BCS	AcCoRutColorBG
AcCoRet4:

	IFEQ	ColorDebug			;*;
	MOVE.W	#$0180,(A3)+			;*;
	MOVE.W	COLOR0+2,(A3)+			;*;
	ENDC					;*;


	IFND	NO_LINEPAL		; hybrid: sprite palettes on this line, then the
	JSR	HyCoObj			; two instructions below (same 6 bytes; linepal.s)
	ELSE
	MOVE.L	(SP)+,D3

	MOVE.W	#$0086,(A3)+
	ENDC
	MOVE.W	D3,(A3)+
	MOVE.W	#$0084,(A3)+		; Retorno Copper 
	SWAP	D3
	MOVE.W	D3,(A3)+

	MOVE.L	#$008A0000,(A3)+

	BRA	AcCoRet


; ----------------------------------=> Actualiza Scroll X en BG.
	CNOP	0,8
AcCoRutBGX:
	LEA	(TabRasDATA.L,D7.W*8),A0


	LEA	TabSprCoorOff(PC),A4
	BTST	#0,1(A0)
	BEQ.S	AcCoXCon0

	MOVEQ	#0,D1
	MOVE.B	2(A0),D1
	LSL.W	#1,D1
	LEA	(TabSprCoor.L,D1.W*8),A4
AcCoXCon0:


	IFND	NO_WINOFFBG		; hybrid: WinX on this line too (window switched on
	BTST	#1,D5			; or off here): take its on/off before clipping the BG
	BEQ.S	.hywin
	BTST	#5,1(A0)
	SNE	UltWinOn
.hywin:
	ENDC
	TST.B	UltWinOn(PC)	; ¿Win ON?
;;;	BTST	#5,1(A0)	; ¿Win ON?	<=- Este es incorrecto.
	BEQ.S	AcCoXCon3
	CMP.B	4(A0),D7	; Win Y
	BCS.S	AcCoXCon3

	MOVE.B	3(A0),D0	; Win X
	LSR.B	#1,D0
	ADD.B	#($B0/2)-7,D0
	BCC.S	AcCoXCon2
AcCoXCon3:
	MOVEQ	#-1,D0
AcCoXCon2:


AcCoXM0:MACRO
	MOVE.W	\1,(A3)+
	MOVE.W	(A4)+,D1
	CMP.B	D0,D1
	BCS.S	\@AcM
	MOVE.B	#$D8,D1
\@AcM:
	MOVE.W	D1,(A3)+
	MOVE.W	\1+2,(A3)+
	MOVE.W	(A4)+,(A3)+
	ENDM

	AcCoXM0	#$0160
	AcCoXM0	#$0168
	AcCoXM0	#$0170
	AcCoXM0	#$0178


	BRA	AcCoRet1

	CNOP	0,8
TabSprCoorOff:
	DC.W	INISPR*$100+$C0,FINSPR*$100+$02
	DC.W	INISPR*$100+$C0,FINSPR*$100+$02
	DC.W	INISPR*$100+$C0,FINSPR*$100+$02
	DC.W	INISPR*$100+$C0,FINSPR*$100+$02
; ----------------------------------<=

; ----------------------------------=> Actualiza Scroll X en Win.
	CNOP	0,8
AcCoRutWinX:
	LEA	(TabRasDATA.L,D7.W*8),A0


	LEA	TabSprCoorOff(PC),A4
	BTST	#5,1(A0)
	SNE	UltWinOn
	BEQ.S	AcCoXCon1

	MOVEQ	#0,D1
	MOVE.B	3(A0),D1
	SUBQ.B	#$07,D1
	NEG.B	D1
	LSL.W	#1,D1
	LEA	(TabSprCoor.L,D1.W*8),A4
AcCoXCon1:

	MOVE.W	(A4)+,D0
	MOVE.W	(A4)+,D1

	MOVE.W	#$0140,(A3)+
	MOVE.W	D0,(A3)+
	MOVE.W	#$0142,(A3)+
	MOVE.W	D1,(A3)+

	MOVE.W	#$0148,(A3)+
	MOVE.W	D0,(A3)+
	MOVE.W	#$014A,(A3)+
	MOVE.W	D1,D2
	OR.B	#$80,D2
	MOVE.W	D2,(A3)+
	ADD.B	#$20,D0

	MOVE.W	#$0150,(A3)+
	MOVE.W	D0,(A3)+
	MOVE.W	#$0152,(A3)+
	MOVE.W	D1,(A3)+
	ADD.B	#$20,D0

	MOVE.W	#$0158,(A3)+
	MOVE.W	D0,(A3)+
	MOVE.W	#$015A,(A3)+
	MOVE.W	D1,(A3)+

	BRA	AcCoRet3

UltWinOn:	DC.B	0,0
	IFND	NO_WINTRIG
HyWinTrig:	DC.B	0,0		; hybrid: line the window starts on this frame ($90 none)
	ENDC

; ----------------------------------<=

; ----------------------------------=> Actualiza Scroll Y en BG.

	CNOP	0,8
AcCoRutBGY:
	LEA	(TabRasDATA.L,D7.W*8),A0

	MOVEQ	#0,D2
	MOVE.B	(A0),D2
	ADD.B	D7,D2

	MOVE.L	D2,D1
	LSL.W	#4,D1

	MOVE.B	1(A0),D2
	ADD.L	(TablaDirGFX.L,D2.W*8),D1

	MOVE.W	#$0132,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$0130,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	ADD.L	#NEXSPR,D1
	MOVE.W	#$0136,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$0134,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	ADD.L	#NEXSPR,D1
	MOVE.W	#$013A,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$0138,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	ADD.L	#NEXSPR,D1
	MOVE.W	#$013E,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$013C,(A3)+
	MOVE.W	D1,(A3)+

	BRA	AcCoRet0

; ----------------------------------<=

; ----------------------------------=> Actualiza Scroll Y en Win.

	CNOP	0,8
AcCoRutWinY:
	LEA	(TabRasDATA.L,D7.W*8),A0


	MOVEQ	#0,D2
	MOVE.B	1(A0),D2
	MOVE.L	(TablaDirGFX+4.L,D2.W*8),D1

	MOVE.B	4(A0),D2
	CMP.B	#$90,D2
	BCS.S	GfxWinOff
	MOVE.B	#$90,D2
GfxWinOff:

	IFND	NO_WINTRIG		; hybrid: as the DMG, the window starts on the first line
	CMP.B	HyWinTrig(PC),D7	; with LY = WY and then counts its own lines. A WY
	BHI.S	.go			; written later moves a start still to come, not one
	CMP.B	D7,D2			; already passed (Super Mario Land 2 writes WY=$88
	BCC.S	.trig			; at LY 8 each frame), and a WY above this line
	MOVE.B	#$90,D2			; means no window for the rest of the frame. The
.trig:	MOVE.B	D2,HyWinTrig		; sprite pointers are set on line D7, so they
.go:	MOVEQ	#0,D2			; point (start - D7) lines before the window's
	MOVE.B	HyWinTrig(PC),D2	; row 0 (Juan: start lines, right on line 0 only)
	SUB.W	D7,D2
	LSL.W	#4,D2
	EXT.L	D2
	ELSE
	LSL.W	#4,D2
	ENDC
	SUB.L	D2,D1


	MOVE.W	#$0122,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$0120,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	ADD.L	#NEXSPR,D1
	MOVE.W	#$012A,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$0128,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	ADD.L	#NEXSPR,D1
	MOVE.W	#$012E,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$012C,(A3)+
	MOVE.W	D1,(A3)+

	MOVE.L	#SprGfxM,D1
	SUB.L	D2,D1

	MOVE.W	#$0126,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$0124,(A3)+
	MOVE.W	D1,(A3)+

	BRA	AcCoRet2

; ----------------------------------<=

; ----------------------------------=> Actualiza Paleta en BG.

AcCoRutColorBG:
	LEA	(TabRasDATA.L,D7.W*8),A0

	LEA	GBPaleta,A1

	MOVE.B	5(A0),D0
	BFEXTU	D0{24:2},D1

	MOVE.W	#$1BE,(A3)+
	MOVE.W	(A1,D1.W*2),(A3)+
	MOVE.W	#$1B6,(A3)+
	MOVE.W	(A1,D1.W*2),(A3)+
	MOVE.W	#$1AE,(A3)+
	MOVE.W	(A1,D1.W*2),(A3)+
	MOVE.W	#$1A6,(A3)+
	MOVE.W	(A1,D1.W*2),(A3)+

	BFEXTU	D0{26:2},D1
	MOVE.W	#$1BC,(A3)+
	MOVE.W	(A1,D1.W*2),(A3)+
	MOVE.W	#$1B4,(A3)+
	MOVE.W	(A1,D1.W*2),(A3)+
	MOVE.W	#$1AC,(A3)+
	MOVE.W	(A1,D1.W*2),(A3)+
	MOVE.W	#$1A4,(A3)+
	MOVE.W	(A1,D1.W*2),(A3)+

	BFEXTU	D0{28:2},D1
	MOVE.W	#$1BA,(A3)+
	MOVE.W	(A1,D1.W*2),(A3)+
	MOVE.W	#$1B2,(A3)+
	MOVE.W	(A1,D1.W*2),(A3)+
	MOVE.W	#$1AA,(A3)+
	MOVE.W	(A1,D1.W*2),(A3)+
	MOVE.W	#$1A2,(A3)+
	MOVE.W	(A1,D1.W*2),(A3)+

	BFEXTU	D0{30:2},D1
	MOVE.W	#$1B8,(A3)+
	MOVE.W	(A1,D1.W*2),(A3)+
	MOVE.W	#$1B0,(A3)+
	MOVE.W	(A1,D1.W*2),(A3)+
	MOVE.W	#$1A8,(A3)+
	MOVE.W	(A1,D1.W*2),(A3)+
	MOVE.W	#$180,(A3)+
	MOVE.W	(A1,D1.W*2),(A3)+

	BRA	AcCoRet4

; ----------------------------------<=





; -========================================


; ------------------------------------------------ ;
; ------------------------------------------------ ;

; ==== AmiGameBoy_Main.asm 4356-5260: ActualizaGFX, scroll, OBJPrint, keyboard, GFXPrint, palettes, pads
	CNOP	0,8
ActualizaGFX:
; -----------------------------
	LEA	VRAM+$1800,A0
	LEA	PantAnt0(PC),A1
	BSR	ActGfxRutMinus
; -----------------------------
	LEA	VRAM+$1800,A0
	LEA	PantAnt4(PC),A1
	BSR	ActGfxRutPlus
; -----------------------------
	LEA	VRAM+$1C00,A0
	LEA	PantAnt8(PC),A1
	BSR	ActGfxRutMinus
; -----------------------------
	LEA	VRAM+$1C00,A0
	LEA	PantAntC(PC),A1
	BSR	ActGfxRutPlus
; -----------------------------
	LEA	Regs+TabRedef+$180(PC),A6
	MOVEM.L	Ceros(PC),D0-D7/A0-A5
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A3,-(A6)

; -------------------------------------> Contador de tiempo 2. (proteccion anti-hackers)
;	LEA	Regs(PC),A3
;	LEA	DirPrefs+$15-$4326,A0
;	MOVEQ	#0,D1
;	MOVE.B	$4326(A0),D1
;	LSR.B	#5,D1
;	ADD.W	D1,Contador1(A3)
;	BCC.S	Conta2Fin
;	MOVE.L	$1C3*8(A3),$1CD*8(A3)
;Conta2Fin:
; -------------------------------------<
	RTS

	CNOP	0,8
AntBaseGfxBG:	DC.B	-1,0,0,0
Ceros:		DS.L	16

; -----------------------------
	CNOP	0,8
ActGfxRutMinus:
	LEA	Regs+TabRedef+$100(PC),A2
	MOVE.W	#((32*32)/4)-1,D0
ActGfxBuc:
	MOVE.B	(A0)+,D1
	EXT.W	D1
	TST.B	(A2,D1.W)
	BEQ.S	NoRedef0
	NOT.B	D1
	MOVE.B	D1,(A1)
NoRedef0:
	MOVE.B	(A0)+,D1
	EXT.W	D1
	TST.B	(A2,D1.W)
	BEQ.S	NoRedef1
	NOT.B	D1
	MOVE.B	D1,1(A1)
NoRedef1:
	MOVE.B	(A0)+,D1
	EXT.W	D1
	TST.B	(A2,D1.W)
	BEQ.S	NoRedef2
	NOT.B	D1
	MOVE.B	D1,2(A1)
NoRedef2:
	MOVE.B	(A0)+,D1
	EXT.W	D1
	TST.B	(A2,D1.W)
	BEQ.S	NoRedef3
	NOT.B	D1
	MOVE.B	D1,3(A1)
NoRedef3:
	ADDQ	#4,A1
	DBF	D0,ActGfxBuc
	RTS
; -----------------------------
	CNOP	0,8	
ActGfxRutPlus:
	LEA	Regs+TabRedef(PC),A2
	MOVE.W	#((32*32)/4)-1,D0
	MOVEQ	#0,D1
ActGfxBuc0:
	MOVE.B	(A0)+,D1
	TST.B	(A2,D1.W)
	BEQ.S	NoRedef4
	NOT.B	D1
	MOVE.B	D1,(A1)
NoRedef4:
	MOVE.B	(A0)+,D1
	TST.B	(A2,D1.W)
	BEQ.S	NoRedef5
	NOT.B	D1
	MOVE.B	D1,1(A1)
NoRedef5:
	MOVE.B	(A0)+,D1
	TST.B	(A2,D1.W)
	BEQ.S	NoRedef6
	NOT.B	D1
	MOVE.B	D1,2(A1)
NoRedef6:
	MOVE.B	(A0)+,D1
	TST.B	(A2,D1.W)
	BEQ.S	NoRedef7
	NOT.B	D1
	MOVE.B	D1,3(A1)
NoRedef7:
	ADDQ	#4,A1
	DBF	D0,ActGfxBuc0
	RTS

; ------------------------------------------------ ;

;	CNOP	0,4
;PoneScrollWin:
;	MOVE.W	#$90,D0
;	BTST	#5,RRAM+$1F40
;	BEQ.S	GfxWinOff
;
;	MOVE.B	RRAM+$1F4A,D0
;	CMP.B	#$90,D0
;	BCS.S	GfxWinOff
;	MOVE.W	#$90,D0
;GfxWinOff:
;	MOVE.W	D0,D1
;	ADD.B	#INISPR,D1
;	MOVE.B	D1,ScrSpr4+$A
;	MOVE.B	D1,ScrSpr5+$A
;	MOVE.B	D1,ScrSpr6+$A
;	MOVE.B	D1,ScrSpr7+$A
;
;
;	MOVE.B	RRAM+$1F4B,D0
;	SUB.B	#$07,D0
;
;	MOVE.B	#$03,D1
;	LSR.B	#1,D0
;	BCS.S	PonScrCon
;	MOVE.B	#$02,D1
;PonScrCon:
;	MOVE.B	D1,ScrSpr4+$F
;	MOVE.B	D1,ScrSpr6+$F
;	MOVE.B	D1,ScrSpr7+$F
;	OR.B	#$80,D1
;	MOVE.B	D1,ScrSpr5+$F
;
;	ADD.B	#$50,D0
;	MOVE.B	D0,ScrSpr4+$B
;	MOVE.B	D0,ScrSpr5+$B
;	ADD.B	#$20,D0
;	MOVE.B	D0,ScrSpr6+$B
;	ADD.B	#$20,D0
;	MOVE.B	D0,ScrSpr7+$B
;
;
;	MOVEQ	#0,D2
;	MOVE.B	RRAM+$1F40,D2
;	MOVE.L	(TablaDirGFX+4.L,D2.W*8),D1
;
;	MOVE.W	D1,ScrSpr4+6
;	SWAP	D1
;	MOVE.W	D1,ScrSpr4+2
;	SWAP	D1
;	ADD.L	#NEXSPR,D1
;	MOVE.W	D1,ScrSpr6+6
;	SWAP	D1
;	MOVE.W	D1,ScrSpr6+2
;	SWAP	D1
;	ADD.L	#NEXSPR,D1
;	MOVE.W	D1,ScrSpr7+6
;	SWAP	D1
;	MOVE.W	D1,ScrSpr7+2
;
;	MOVE.L	#SprGfxM,D1
;	MOVE.W	D1,ScrSpr5+6
;	SWAP	D1
;	MOVE.W	D1,ScrSpr5+2
;
;	RTS

; ------------------------------------------------ ;

	CNOP	0,4
PoneScrollBG:

;	LEA	TabSprCoor,A0
;	MOVEQ	#0,D0
;	MOVE.B	RRAM+$1F43,D0
;	LSL.W	#1,D0
;	LEA	(A0,D0.W*8),A0
;
;	MOVE.W	(A0)+,ScrSpr0+$A
;	MOVE.W	(A0)+,ScrSpr0+$E
;	MOVE.W	(A0)+,ScrSpr1+$A
;	MOVE.W	(A0)+,ScrSpr1+$E
;	MOVE.W	(A0)+,ScrSpr2+$A
;	MOVE.W	(A0)+,ScrSpr2+$E
;	MOVE.W	(A0)+,ScrSpr3+$A
;	MOVE.W	(A0)+,ScrSpr3+$E
;
;
;	MOVEQ	#0,D2
;	MOVE.B	RRAM+$1F42,D2
;
;	MOVE.W	#$D7,D1
;	CMP.W	#$70,D2
;	BLT.S	PonScrConBG
;	MOVE.B	D2,D3
;	SUB.B	#$70,D3
;	SUB.B	D3,D1
;PonScrConBG:
;
;	SUB.B	#$48,D1
;	MULU	#(CoppLineSize),D1
;	MOVE.W	#$01A0,([Regs+ScrResAnt])
;	LEA	(CopperLine+$14+(CoppLineSize).L,D1.W),A4
;	MOVE.W	#$008A,(A4)
;	MOVE.L	A4,Regs+ScrResAnt
;
;
;	MOVEQ	#0,D1
;	MOVE.B	D2,D1
;	LSL.W	#4,D1
;
;	MOVE.B	RRAM+$1F40,D2
;	ADD.L	(TablaDirGFX.L,D2.W*8),D1
;
;	MOVE.W	D1,ScrSpr0+6
;	SWAP	D1
;	MOVE.W	D1,ScrSpr0+2
;	SWAP	D1
;	ADD.L	#NEXSPR,D1
;	MOVE.W	D1,ScrSpr1+6
;	SWAP	D1
;	MOVE.W	D1,ScrSpr1+2
;	SWAP	D1
;	ADD.L	#NEXSPR,D1
;	MOVE.W	D1,ScrSpr2+6
;	SWAP	D1
;	MOVE.W	D1,ScrSpr2+2
;	SWAP	D1
;	ADD.L	#NEXSPR,D1
;	MOVE.W	D1,ScrSpr3+6
;	SWAP	D1
;	MOVE.W	D1,ScrSpr3+2

	RTS

; ------------------------------------------------ ;

	CNOP	0,4
OBJPrint:
	LEA	DirGfxOBJ,A1
	MOVE.W	OBJNUM,D0
	SUBQ.W	#1,D0
	BCS	NOHAYOBJ
BorraOBJBuc:
	MOVE.L	(A1)+,A0
	CLR.W	(A0)
	CLR.W	(32*1)(A0)
	CLR.W	(32*2)(A0)
	CLR.W	(32*3)(A0)
	CLR.W	(32*4)(A0)
	CLR.W	(32*5)(A0)
	CLR.W	(32*6)(A0)
	CLR.W	(32*7)(A0)
	CLR.W	(32*8)(A0)
	CLR.W	(32*9)(A0)
	CLR.W	(32*10)(A0)
	CLR.W	(32*11)(A0)
	CLR.W	(32*12)(A0)
	CLR.W	(32*13)(A0)
	CLR.W	(32*14)(A0)
	CLR.W	(32*15)(A0)
	LEA	(32*(144+32))(A0),A0
	CLR.W	(A0)
	CLR.W	(32*1)(A0)
	CLR.W	(32*2)(A0)
	CLR.W	(32*3)(A0)
	CLR.W	(32*4)(A0)
	CLR.W	(32*5)(A0)
	CLR.W	(32*6)(A0)
	CLR.W	(32*7)(A0)
	CLR.W	(32*8)(A0)
	CLR.W	(32*9)(A0)
	CLR.W	(32*10)(A0)
	CLR.W	(32*11)(A0)
	CLR.W	(32*12)(A0)
	CLR.W	(32*13)(A0)
	CLR.W	(32*14)(A0)
	CLR.W	(32*15)(A0)
	DBF	D0,BorraOBJBuc
NOHAYOBJ:
	CLR.W	OBJNUM

; -=-

	LEA	GBSpr0+(15),A5

	MOVE.W	#$200,D2
	MOVEQ	#(16)-1,D5
	BTST	#2,RRAM+$1F40
	BNE.S	Sengunda3
	MOVEQ	#0,D2
	MOVEQ	#(8)-1,D5
Sengunda3:

	LEA	RRAM+$1E00,A0		; Datos Sprites.

	MOVEQ	#0,D7
	LEA	DirGfxOBJ,A4
	MOVEQ	#(40)-1,D4
PoneOBJBuc:

	MOVEQ	#0,D0
	MOVE.B	(A0)+,D0		; Coordenada Y
	BEQ	SESALEY

	CMP.B	#144+16,D0
	BCC	SESALEY

	MULU	#32,D0

	MOVEQ	#0,D1
	MOVE.B	(A0)+,D1		; Coordenada X
	BEQ	SESALEX

	CMP.B	#160+8,D1
	BCC	SESALEX

	MOVE.B	D1,D3
	NOT.B	D3
	AND.W	#$7,D3
	ADDQ.B	#1,D3
	LSR.B	#3,D1
	ADD.L	D1,D0
	LEA	(A5,D0.L),A1

	TST.B	1(A0)			; ¿Prioridad?
	BMI.S	NoEsPriory
	ADD.W	#(GBSprBuc),A1
NoEsPriory:

	BTST.B	#4,1(A0)		; ¿Segunda paleta?
	BEQ.S	NoEsPalet2
	ADD.W	#(GBSprNex),A1
NoEsPalet2:

	LEA	(32*(144+32))(A1),A2
	MOVE.L	A1,(A4)+
	ADDQ.W	#1,OBJNUM

	MOVE.B	(A0)+,D2		; Patrón.  (Tile)
	MOVE.L	(DirBaseGFX.W,PC,D2.W*4),A3

	LEA	TablaOBJFlip0,A6
	BTST	#5,(A0)
	BEQ.S	NoEsFlipX
	LEA	TablaOBJFlip1,A6
NoEsFlipX:

	BTST	#6,(A0)
	BNE.S	EsFlipY

	MOVE.W	D5,D6
PoneOBJBuc0:
	MOVE.B	(A3)+,D7
	BEQ.S	Estodo0a
	MOVE.W	(A6,D7.W*2),D0
	LSL.W	D3,D0
	OR.W	D0,(A1)
Estodo0a:
	MOVE.B	(A3)+,D7
	BEQ.S	Estodo0b
	MOVE.W	(A6,D7.W*2),D0
	LSL.W	D3,D0
	OR.W	D0,(A2)
Estodo0b:
	ADD.W	#32,A1
	ADD.W	#32,A2
	DBF	D6,PoneOBJBuc0
ContiOBJ:
	ADDQ	#1,A0			; Datos del Sprite

	DBF	D4,PoneOBJBuc
	RTS


SESALEX:
	ADDQ	#1,A0
	BRA.S	ContiOBJ

SESALEY:
	ADDQ	#2,A0
	BRA.S	ContiOBJ


EsFlipY:
	ADDQ	#2,A3
	ADD.W	D5,A3
	ADD.W	D5,A3

	MOVE.W	D5,D6
PoneOBJBuc0y:
	MOVE.B	-(A3),D7
	BEQ.S	Estodo0ay
	MOVE.W	(A6,D7.W*2),D0
	LSL.W	D3,D0
	OR.W	D0,(A2)
Estodo0ay:
	MOVE.B	-(A3),D7
	BEQ.S	Estodo0by
	MOVE.W	(A6,D7.W*2),D0
	LSL.W	D3,D0
	OR.W	D0,(A1)
Estodo0by:
	ADD.W	#32,A1
	ADD.W	#32,A2
	DBF	D6,PoneOBJBuc0y
ContiOBJy:
	ADDQ	#1,A0			; Datos del Sprite

	DBF	D4,PoneOBJBuc
	RTS



	CNOP	0,4
OBJNUM:	DC.L	0
DirGfxOBJ:
	REPT	42
	DC.L	GBSpr0
	ENDR

; ------------------------------------------------ ;
; ------------------------------------------------ ;

LeeTecla:MACRO
	CMP.B	#\2,D0
	BNE.S	Lete\@
	BSET	#\1,EstadoKeys+\3(A3)
Lete\@:
	ENDM

PonTecla:MACRO
	CMP.B	#\2,D0
	BNE.S	PoTe\@
	BCLR	#\1,EstadoKeys+\3(A3)
PoTe\@:
	ENDM

	CNOP	0,8
MiraTeclado:
	MOVEQ	#0,D0
	MOVE.B	$BFEC01,D0
	BNE.S	Pulsacion
	RTS
Pulsacion:
	NOP
	SF	$BFEC01
	NOP
	NOP
	MOVE.W	#4,D2
	OR.B	#$40,$BFEE01		; CIAA Libre
TRETARDO:
	MOVE.B	$DFF006,D1
TRETARDOB:
	CMP.B	$DFF006,D1
	BEQ.S	TRETARDOB
	DBF	D2,TRETARDO
	AND.B	#$BF,$BFEE01		; CIAA Libre

	LEA	Regs,A3

	NOT.B	D0
	LSR.B	#$1,D0
	BCS	TeclaSoltada

	PonTecla 0,$4E,0		; Derecha
	PonTecla 1,$4F,0		; Izquierda
	PonTecla 2,$4C,0		; Arriba
	PonTecla 3,$4D,0		; Abajo

	PonTecla 0,$66,1		; Botón A
	PonTecla 1,$64,1		; Botón B
	PonTecla 2,$46,1		; Select
	PonTecla 3,$5F,1		; Start

	PonTecla 0,$60,2		; Botón A
	PonTecla 1,$40,2		; Botón B

	CMP.B	#$45,D0
	BNE.S	NoEsESC
	ST	SalirMenu(A3)
NoEsESC:
	RTS
	CNOP	0,4
TeclaSoltada:
	LeeTecla 0,$4E,0		; Derecha
	LeeTecla 1,$4F,0		; Izquierda
	LeeTecla 2,$4C,0		; Arriba
	LeeTecla 3,$4D,0		; Abajo

	LeeTecla 0,$66,1		; Botón A
	LeeTecla 1,$64,1		; Botón B
	LeeTecla 2,$46,1		; Select
	LeeTecla 3,$5F,1		; Start

	LeeTecla 0,$60,2		; Botón A
	LeeTecla 1,$40,2		; Botón B

	RTS

; ------------------------------------------------ ;
; ------------------------------------------------ ;

	CNOP	0,4
GFXPrint:
	MOVE.L	#(NEXSPR-8),D6
	MOVE.L	#(NEXSPR*4)-(16*8),D7

	LEA	PantAnt0,A5
	LEA	SprGfx0Fast,A0
	LEA	SprGfx0,A6
	LEA	VRAM+$1800,A3
	LEA	DirBaseGFX+$400(PC),A2
	BSR	GFXImp

	LEA	PantAnt4,A5
	LEA	SprGfx4Fast,A0
	LEA	SprGfx4,A6
	LEA	VRAM+$1800,A3
	LEA	DirBaseGFX(PC),A2
	BSR	GFXImp

	LEA	PantAnt8,A5
	LEA	SprGfx8Fast,A0
	LEA	SprGfx8,A6
	LEA	VRAM+$1C00,A3
	LEA	DirBaseGFX+$400(PC),A2
	BSR	GFXImp

	LEA	PantAntC,A5
	LEA	SprGfxCFast,A0
	LEA	SprGfxC,A6
	LEA	VRAM+$1C00,A3
	LEA	DirBaseGFX(PC),A2
	BSR	GFXImp
	RTS

	CNOP	0,8
GFXImp:
	MOVEQ	#0,D2
	MOVE.W	#(32)-1,D0
GFXPrBuc:
	MOVE.W	#(32/8)-1,D1
GFXPrBuc0:
	MOVE.W	#(8/4)-1,D3
GFXPrBuc1:
	CMP.L	(A3)+,(A5)+

	BNE.S	GFXPrCon
	ADDQ	#4,A0
	ADDQ	#4,A6
	DBF	D3,GFXPrBuc1
	ADD.L	D6,A0
	ADD.L	D6,A6
	DBF	D1,GFXPrBuc0
	SUB.L	D7,A0
	SUB.L	D7,A6
	DBF	D0,GFXPrBuc
	RTS

	CNOP	0,8
GFXPrCon:

GFXPrt:	MACRO
	MOVE.B	-(A3),D2
	CMP.B	-(A5),D2
	BEQ.S	\@ImYaEsta

	MOVE.L	(A2,D2.W*4),A4

	MOVE.B	(A4)+,(16*0)+\1(A0)
	MOVE.B	(A4)+,8+(16*0)+\1(A0)
	MOVE.B	(A4)+,(16*1)+\1(A0)
	MOVE.B	(A4)+,8+(16*1)+\1(A0)
	MOVE.B	(A4)+,(16*2)+\1(A0)
	MOVE.B	(A4)+,8+(16*2)+\1(A0)
	MOVE.B	(A4)+,(16*3)+\1(A0)
	MOVE.B	(A4)+,8+(16*3)+\1(A0)
	MOVE.B	(A4)+,(16*4)+\1(A0)
	MOVE.B	(A4)+,8+(16*4)+\1(A0)
	MOVE.B	(A4)+,(16*5)+\1(A0)
	MOVE.B	(A4)+,8+(16*5)+\1(A0)
	MOVE.B	(A4)+,(16*6)+\1(A0)
	MOVE.B	(A4)+,8+(16*6)+\1(A0)
	MOVE.B	(A4)+,(16*7)+\1(A0)
	MOVE.B	(A4)+,8+(16*7)+\1(A0)
\@ImYaEsta:
	ENDM

	GFXPrt	3
	GFXPrt	2
	GFXPrt	1
	GFXPrt	0

;	Copia Gráfico de Fast a Chip.

	MOVE.L	(A3)+,(A5)+

	MOVE.L	(A0)+,(A6)+
	MOVE.L	8-4(A0),8-4(A6)
	MOVE.L	(16*1)-4(A0),(16*1)-4(A6)
	MOVE.L	8+(16*1)-4(A0),8+(16*1)-4(A6)
	MOVE.L	(16*2)-4(A0),(16*2)-4(A6)
	MOVE.L	8+(16*2)-4(A0),8+(16*2)-4(A6)
	MOVE.L	(16*3)-4(A0),(16*3)-4(A6)
	MOVE.L	8+(16*3)-4(A0),8+(16*3)-4(A6)
	MOVE.L	(16*4)-4(A0),(16*4)-4(A6)
	MOVE.L	8+(16*4)-4(A0),8+(16*4)-4(A6)
	MOVE.L	(16*5)-4(A0),(16*5)-4(A6)
	MOVE.L	8+(16*5)-4(A0),8+(16*5)-4(A6)
	MOVE.L	(16*6)-4(A0),(16*6)-4(A6)
	MOVE.L	8+(16*6)-4(A0),8+(16*6)-4(A6)
	MOVE.L	(16*7)-4(A0),(16*7)-4(A6)
	MOVE.L	8+(16*7)-4(A0),8+(16*7)-4(A6)

	DBF	D3,GFXPrBuc1
	ADD.L	D6,A0
	ADD.L	D6,A6
	DBF	D1,GFXPrBuc0
	SUB.L	D7,A0
	SUB.L	D7,A6
	DBF	D0,GFXPrBuc
	RTS

	CNOP	0,8
PantAnt0:	DCB.B	32*32,47
PantAnt4:	DCB.B	32*32,47
PantAnt8:	DCB.B	32*32,47
PantAntC:	DCB.B	32*32,47
DirBaseGFX:	DS.L	$100*3

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-



	CNOP	0,8
PonePaleta:
	LEA	GBPaleta,A0
; -============================================-> Paleta de BG en SPR0->3
	IFND	NO_LINEPAL		; hybrid: as at line 0 (linepal.s)
	MOVE.B	HyPal0,D0
	ELSE
	MOVE.B	RRAM+$1F47,D0
	ENDC
	BFEXTU	D0{24:2},D1
	MOVE.W	(A0,D1.W*2),COLOR2+($3*4)+2
	MOVE.W	(A0,D1.W*2),COLOR2+($7*4)+2
	MOVE.W	(A0,D1.W*2),COLOR2+($B*4)+2
	MOVE.W	(A0,D1.W*2),COLOR2+($F*4)+2
	BFEXTU	D0{26:2},D1
	MOVE.W	(A0,D1.W*2),COLOR2+($2*4)+2
	MOVE.W	(A0,D1.W*2),COLOR2+($6*4)+2
	MOVE.W	(A0,D1.W*2),COLOR2+($A*4)+2
	MOVE.W	(A0,D1.W*2),COLOR2+($E*4)+2
	BFEXTU	D0{28:2},D1
	MOVE.W	(A0,D1.W*2),COLOR2+($1*4)+2
	MOVE.W	(A0,D1.W*2),COLOR2+($5*4)+2
	MOVE.W	(A0,D1.W*2),COLOR2+($9*4)+2
	MOVE.W	(A0,D1.W*2),COLOR2+($D*4)+2
	BFEXTU	D0{30:2},D1
	MOVE.W	(A0,D1.W*2),COLOR0+($0*4)+2
	MOVE.W	(A0,D1.W*2),COLOR2+($4*4)+2
	MOVE.W	(A0,D1.W*2),COLOR2+($8*4)+2
	MOVE.W	(A0,D1.W*2),COLOR2+($C*4)+2
; -============================================-> Paleta de OBJ0 en BPL0
	IFND	NO_LINEPAL		; hybrid: as at line 0 (linepal.s)
	MOVE.B	HyPal0+1,D0
	ELSE
	MOVE.B	RRAM+$1F48,D0
	ENDC
	BFEXTU	D0{24:2},D1
	MOVE.W	(A0,D1.W*2),COLOR0+($3*4)+2
	BFEXTU	D0{26:2},D1
	MOVE.W	(A0,D1.W*2),COLOR0+($2*4)+2
	BFEXTU	D0{28:2},D1
	MOVE.W	(A0,D1.W*2),COLOR0+($1*4)+2
; -============================================-> Paleta de OBJ1 en BPL0
	IFND	NO_LINEPAL		; hybrid: as at line 0 (linepal.s)
	MOVE.B	HyPal0+2,D0
	ELSE
	MOVE.B	RRAM+$1F49,D0
	ENDC
	BFEXTU	D0{24:2},D1
	MOVE.W	(A0,D1.W*2),COLOR0+($C*4)+2
	MOVE.W	(A0,D1.W*2),COLOR0+($D*4)+2
	MOVE.W	(A0,D1.W*2),COLOR0+($E*4)+2
	MOVE.W	(A0,D1.W*2),COLOR0+($F*4)+2
	BFEXTU	D0{26:2},D1
	MOVE.W	(A0,D1.W*2),COLOR0+($8*4)+2
	MOVE.W	(A0,D1.W*2),COLOR0+($9*4)+2
	MOVE.W	(A0,D1.W*2),COLOR0+($A*4)+2
	MOVE.W	(A0,D1.W*2),COLOR0+($B*4)+2
	BFEXTU	D0{28:2},D1
	MOVE.W	(A0,D1.W*2),COLOR0+($4*4)+2
	MOVE.W	(A0,D1.W*2),COLOR0+($5*4)+2
	MOVE.W	(A0,D1.W*2),COLOR0+($6*4)+2
	MOVE.W	(A0,D1.W*2),COLOR0+($7*4)+2

; -============================================<-
	RTS

	CNOP	0,8
GBPaleta:	DC.W	$0FFF,$0999,$0555,$0000

PaletaGrey:	DC.W	$0FFF,$0999,$0555,$0000
PaletaBlue:	DC.W	$000F,$0009,$0005,$0000
PaletaRed:	DC.W	$0F00,$0900,$0500,$0000
PaletaGreen:	DC.W	$00F0,$0090,$0050,$0000
PaletaOrange:	DC.W	$0C93,$0862,$0431,$0000


PaletaYellow:	DC.W	$0FA0,$0940,$0520,$0000
;PaletaOrange:	DC.W	$0FD4,$0973,$0542,$0000


; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-



; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

;	 ---------------------------
;	- Lee puerto 0 del JoyStick -
;	 ---------------------------

	CNOP	0,8
LeeJoyStick:
LeeJoypad:
	LEA	Regs,A3
	MOVE.W	$DFF00C,D0		; Puerto B.
	BSR	LEEJOY
	NOT.B	D2
	MOVE.B	D2,EstadoJoy+2(A3)

	MOVEQ	#0,D1

	BTST	#7,$BFE001		; Botón A
	BNE.S	NOB1_E
	BSET	#0,D1
NOB1_E:
	MOVE.W	#$FF00,$DFF034		; Start
	NOP
	NOP
	BTST	#2,$DFF016
	BNE.S	NOB2C_E
	BSET	#3,D1
NOB2C_E:
	MOVE.W	#$FF00,$DFF034		; Botón B
	NOP
	NOP
	BTST	#6,$DFF016
	BNE.S	NOB2_E
	BSET	#1,D1
NOB2_E:
	BTST	#6,$BFE001		; Select
	BNE.S	NOB3_E
	BSET	#2,D1
NOB3_E:
	NOT.B	D1
	MOVE.B	D1,EstadoJoy+1(A3)
	RTS
; -------------------------------
;	Lectura del Joystick.

;	Resultado en D2.b de la siguiente forma:
;	Bit 0=Derecha.
;	Bit 1=Izquierda.
;	Bit 2=Arriba.
;	Bit 3=Abajo.

	CNOP	0,8
LEEJOY:
	MOVE.W	D0,D1
	LSR.B	#1,D1
	AND.B	#$01,D1
	MOVE.B	D1,D2		; Derecha.

	LSR.W	#8,D1
	AND.B	#$02,D1
	OR.B	D1,D2		; Izquierda.

	MOVE.W	D0,D1
	LSR.W	#1,D1
	EOR.W	D1,D0

	MOVE.W	D0,D1
	LSL.B	#3,D1
	AND.B	#$08,D1
	OR.B	D1,D2		; Abajo.

	LSR.W	#6,D0
	AND.B	#$04,D0
	OR.B	D0,D2		; Arriba.
	RTS

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

	CNOP	0,8
LeeTeclado:
	LEA	Regs,A3
	MOVE.W	#-1,EstadoJoy+1(A3)
	RTS

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

CD32M:	MACRO
	LSR.B	#1,D0
	BCC.S	\@NoPuldat
	BCLR	#\1,D1
\@NoPuldat:
	ENDM

	CNOP	0,8
LeeCD32Joypad:
	LEA	Regs,A3
	MOVE.W	$DFF00C,D0		; Puerto B.
	BSR	LEEJOY
	NOT.B	D2
	MOVE.B	D2,EstadoJoy+2(A3)

	BSR	ReadCD32
	LSR.B	#1,D0
	MOVEQ	#-1,D1

	LSR.B	#1,D0
	SCS	SalirMenu(A3)

	CD32M	1	; Boton B
	CD32M	0	; Boton A
	CD32M	2	; Select
	CD32M	3	; Start
	CD32M	1	; Boton B
	CD32M	0	; Boton A

	MOVE.B	D1,EstadoJoy+1(A3)

	RTS

;***********************************************************************
;Reads CD 32 Controller
;You must read joystick positions or button in normal way
;BEFORE you call this.
;One VBL MUST have elapsed before repeating this!

; D0=:
CD_PLAY	EQU 1
CD_RWD	EQU 2
CD_FFW	EQU 3
CD_G	EQU 4
CD_Y	EQU 5
CD_R	EQU 6
CD_B	EQU 7

		CNOP	0,8
ReadCD32:
		bset	#7,$bfe201
		bclr	#7,$bfe001
		move.w	#$6f00,$dff034
		moveq.l	#0,d0
		moveq.l	#7,d1
		bra.b	.gamecont4		
.gamecont3:
		tst.b	$bfe001
		tst.b	$bfe001
		tst.b	$bfe001
.gamecont4:
		tst.b	$bfe001
		tst.b	$bfe001
		tst.b	$bfe001
		tst.b	$bfe001
		tst.b	$bfe001
		move.w	$dff016,d2
		bset	#7,$bfe001
		bclr	#7,$bfe001
		btst	#14,d2
		bne.b	.gamecont5
		bset	d1,d0
.gamecont5:
		dbf	d1,.gamecont3
		
		bclr	#7,$bfe201
		move.w	#$ffff,$dff034
		rts
;***********************************************************************
; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-









; ==== AmiGameBoy_Main.asm 5452-5635: chip RAM builders (007 routines) and system save area

; -------------------------------------
; **  Rutinas Básicas de 007  v2.27  **
; -------------------------------------

	CNOP	0,4

DP0=$8000	; 00(A0): Direccion Copper.   08(A0): Bytes de 1 Plano.
DP1=$C000	; 04(A0): Direccion Pant.     0C(A0): Bit-Planos. (DP0,1)
CreaPlanos:

	MOVE.W	#$E0,D3
CRPBUC00:
	TST.L	(A0)
	BEQ	CRPRET
	MOVE.L	(A0)+,A1
	MOVEM.L	(A0)+,D0-D2
	TST.W	D2
	SUB.W	#1,D2
	BPL.S	CRPCON00
	BTST	#$E,D2
	BEQ.S	CRPCON01
	ADD.W	#4,D3
CRPCON01:
	AND.W	#$3FFF,D2
	BSR	HACEPLANOS2
	BRA.S	CreaPlanos
CRPCON00:
	BSR	HACEPLANOS
	BRA.S	CreaPlanos
HACEPLANOS:			; A1=COPPER.   D0=Direccion. D1=PLANOSIZE.
	SWAP	D0		; D2=Planos-1. D3=DIRBPLH/L
	MOVE.W	D3,(A1)+
	MOVE.W	D0,(A1)+
	ADD.W	#2,D3
	SWAP	D0
	MOVE.W	D3,(A1)+
	MOVE.W	D0,(A1)+
	ADD.W	#2,D3
	ADD.L	D1,D0
	DBF	D2,HACEPLANOS
	RTS
HACEPLANOS2:			; Igual que antes pero Dual Playfield.
	SWAP	D0
	MOVE.W	D3,(A1)+
	MOVE.W	D0,(A1)+
	ADD.W	#2,D3
	SWAP	D0
	MOVE.W	D3,(A1)+
	MOVE.W	D0,(A1)+
	ADD.W	#2,D3
	ADD.L	D1,D0
	ADD.W	#4,D3
	DBF	D2,HACEPLANOS2
	RTS


CREASALTO:			; A0=COPPER-List.   D0=Direccion
	MOVE.W	D0,$6(A0)
	SWAP	D0
	MOVE.W	D0,$2(A0)
	RTS
;	00(A0): Direccion de Copper.	08(A0): Numero Colores. (DP0,1)
;	04(A0): Direccion de Colores.	(Todos en x.L)
CreaColores:
	MOVE.W	#$180,D1
CRCBUC00:
	TST.L	(A0)
	BEQ	CRPRET
	MOVEM.L	(A0)+,A1-A2
	MOVE.L	(A0)+,D0
	SUB.W	#1,D0
	TST.W	D0
	BPL.S	CRCBUC01
	MOVE.W	#$190,D1
	BTST	#$E,D0
	BEQ.S	CRCBUC01A
	MOVE.W	#$1A0,D1
CRCBUC01A:
	AND.W	#$3FFF,D0
CRCBUC01:
	MOVE.W	D1,(A1)+
	MOVE.W	(A2)+,(A1)+
	ADD.W	#$02,D1
	DBF	D0,CRCBUC01
	BRA.S	CreaColores	

;	00(A0): Direccion del Copper.	08(A0): Numero Sprit (0-7)
;	04(A0): Direccion GFX Sprit.	(Todos en x.L)

CreaSprites:
	TST.L	(A0)
	BEQ	CRPRET
	MOVE.W	#$120,D2
	MOVE.L	(A0)+,A1
	MOVEM.L	(A0)+,D0-D1
	LSL.W	#2,D1
	ADD.L	D1,D2	
	MOVE.W	D2,(A1)+
	SWAP	D0
	MOVE.W	D0,(A1)+
	ADD.L	#2,D2
	MOVE.W	D2,(A1)+
	SWAP	D0
	MOVE.W	D0,(A1)+
	BRA.S	CreaSprites

;	00(A0): Direccion del Copper.	08(A0): Dir. Salto.
CreaSaltos:
	TST.L	(A0)
	BEQ	CRPRET
	MOVE.L	(A0)+,A1
	MOVE.L	(A0)+,D0
	MOVE.W	D0,$6(A1)
	SWAP	D0
	MOVE.W	D0,$2(A1)
	BRA.S	CreaSaltos	
RETARDO:			; D0=Retardo.
	MOVE.W	D0,-(SP)
	MOVE.B	$DFF006,D0
RETARDOB:
	CMP.B	$DFF006,D0
	BEQ.S	RETARDOB
	MOVE.W	(SP)+,D0
	DBF	D0,RETARDO
CRPRET:	RTS
; -----**************()**************-----

	CNOP	0,4
DirPlanos:
	DC.L	PLANO0,GBSpr0+(32*16)+16,(32*(144+32)),4+DP0
	DC.L	PLANO1,GBSpr1+(32*16)+16,(32*(144+32)),4+DP1
	DC.L	0
DirColores:
	DC.L	COLOR0,GBPaleta,16
	DC.L	COLOR2,GBPaleta,16+DP1
	DC.L	0
DirSprites:
	DC.L	DirSprit0,SpritM,4
	DC.L	DirSprit1,SpritM,5
	DC.L	DirSprit2,SpritM,6
	DC.L	DirSprit3,SpritM,7
	DC.L	DirSprit4,SpritM,0
	DC.L	DirSprit5,SpritM,1
	DC.L	DirSprit6,SpritM,2
	DC.L	DirSprit7,SpritM,3
	DC.L	0
DirSaltos:
;	DC.L	ScrSpr0,SprGfx0
;	DC.L	ScrSpr1,SprGfx1
;	DC.L	ScrSpr2,SprGfx2
;	DC.L	ScrSpr3,SprGfx3
;	DC.L	ScrSpr4,SprGfx4
;	DC.L	ScrSpr5,SprGfx5
;	DC.L	ScrSpr6,SprGfx6
;	DC.L	ScrSpr7,SprGfx7
;	DC.L	ScrSpr0R,SprGfx0
;	DC.L	ScrSpr1R,SprGfx1
;	DC.L	ScrSpr2R,SprGfx2
;	DC.L	ScrSpr3R,SprGfx3
;	DC.L	ScrSpr4R,SprGfx4
;	DC.L	ScrSpr5R,SprGfx5
;	DC.L	ScrSpr6R,SprGfx6
;	DC.L	ScrSpr7R,SprGfx7

	DC.L	SaltoM,MasterCopper
;	DC.L	SaltoR,CopperScrRes0
	DC.L	0

	CNOP	0,8
VBlank:		DC.L	0
Traza:		DC.L	0
WBCopp:		DC.L	0
VBRPun:		DC.L	0
Debug:		DS.L	16
DMACON:		DC.W	0
INTENA:		DC.W	0
INTREQ:		DC.W	0
Filtro:		DC.B	0,0
DirContinua:	DC.L	0		; hybrid: was BUCLE (Juan's Z80 loop)
DirFlags:	DC.W	0
INTERDAT:	DC.W	0
PILA:		DC.L	0


; ==== AmiGameBoy_Main.asm 5740-6104: tables (fast BSS), screens and copper (chip DATA), sprite buffers (chip BSS)

;	------------------------
	SECTION	Tablas,BSS
;	------------------------


; =----------------------------------------=> Tablas de conversión OBJ "Flip X"
	CNOP	0,8
TablaOBJFlip0:	DS.W	$100
TablaOBJFlip1:	DS.W	$100
TablaDirGFX:	DS.L	$100*2
; =----------------------------------------<=

; =----------------------------------------=> Copias de pantallas en Fast!
	CNOP	0,8
		DS.L	4
SprGfx0Fast:	DS.B	((8*(256+$90)*2)+(8*4))*4	; =OTRSPR
SprGfx4Fast:	DS.B	((8*(256+$90)*2)+(8*4))*4	; =OTRSPR
SprGfx8Fast:	DS.B	((8*(256+$90)*2)+(8*4))*4	; =OTRSPR
SprGfxCFast:	DS.B	((8*(256+$90)*2)+(8*4))*4	; =OTRSPR
		DS.L	4
; =----------------------------------------<=

; =----------------------------------------=> Tablas de coordenadas Spr.
	CNOP	0,8
TabSprCoor:	DS.L	(256*4)
; =----------------------------------------<=

	DS.B	32	; Seguridad



; -------------------------------------------------- ;
; -------------------------------------------------- ;
; -------------************************------------- ;
; -------------------------------------------------- ;
; -------------------------------------------------- ;


;	------------------------
	SECTION	Pantallas,DATA_C
;	------------------------

	CNOP	0,8
MasterCopper:
	DC.W	$01FC,$000F
DirSprit0:	DS.W	4
DirSprit1:	DS.W	4
DirSprit2:	DS.W	4
DirSprit3:	DS.W	4
DirSprit4:	DS.W	4
DirSprit5:	DS.W	4
DirSprit6:	DS.W	4
DirSprit7:	DS.W	4


Copper:
	DC.W	$008E,$48B1
	DC.W	$0090,$D851

	DC.W	$0092,$0040
	DC.W	$0094,$00B8

	DC.W	$0108,0-8
	DC.W	$010A,0-8

PLANO0:	DS.W	4*4
PLANO1:	DS.W	4*4

COLOR0:	DS.W	8*2
	DS.W	8*2
COLOR2:	DS.W	8*2
	DS.W	8*2
	IFND	NO_BEZEL		; hybrid: the bezel's blocks, copper no-ops until
BezCopT:	DCB.L	37,$01FE0000	; HyBezOn fills them (bezel.s). T: frame top
	ENDC



	DC.W	$4001,$FFFE		; Timer.
	DC.W	$009C,$0000
	DC.W	$009C,$8013



ScrBits:DC.W	$0102,$CC00
	DC.W	$0104,$0007
BpCon3:	DC.W	$0106,$0020
	DC.W	$010C,$0011
	IFND	NO_BEZEL		; R: Juan's display back (line $47)
BezCopR:	DCB.L	27,$01FE0000
	ENDC
	DC.W	$4769,$FFFE
	DC.W	$0100,$0411


CopperLine:	DCB.L	(CoppLineSize/4)*146,$01A00000
	IFND	NO_BEZEL		; B: bottom band (line $D8 on)
BezCopB:	DCB.L	20,$01FE0000
	ENDC



	DC.W	$E301,$FFFE	; Actualiza VDP.
	DC.W	$009C,$0003
	DC.W	$009C,$8010

	DC.L	$FFFFFFFE
	DC.L	$FFFFFFFE


SaltoR:	DC.W	$0084,0,$0086,0
SaltoM:	DC.W	$0080,0,$0082,0


	CNOP	0,8
CopperRet:			; Retorna a Copperline Base.
	DC.W	$0088,0
	DC.L	$FFFFFFFE




;	DC.W	$C001,$FFFE	; Line.
;	DC.W	$009C,$0002
;	DC.W	$009C,$8011

;	DC.W	$1A01,$FFFE
;ScrSpr0:DC.W	$0130,0,$0132,0
;	DC.W	$0160,INISPR*$100+$50
;	DC.W	$0162,FINSPR*$100+$02
;ScrSpr1:DC.W	$0134,0,$0136,0
;	DC.W	$0168,INISPR*$100+$70
;	DC.W	$016A,FINSPR*$100+$02
;ScrSpr2:DC.W	$0138,0,$013A,0
;	DC.W	$0170,INISPR*$100+$90
;	DC.W	$0172,FINSPR*$100+$02
;ScrSpr3:DC.W	$013C,0,$013E,0
;	DC.W	$0178,INISPR*$100+$B0
;	DC.W	$017A,FINSPR*$100+$02
;
;ScrSpr4:DC.W	$0120,0,$0122,0
;	DC.W	$0140,INISPR*$100+$D0
;	DC.W	$0142,FINSPR*$100+$02
;ScrSpr5:DC.W	$0124,0,$0126,0
;	DC.W	$0148,INISPR*$100+$D0
;	DC.W	$014A,FINSPR*$100+$02
;ScrSpr6:DC.W	$0128,0,$012A,0
;	DC.W	$0150,INISPR*$100+$D0
;	DC.W	$0152,FINSPR*$100+$02
;ScrSpr7:DC.W	$012C,0,$012E,0
;	DC.W	$0158,INISPR*$100+$D0
;	DC.W	$015A,FINSPR*$100+$02



; ------------------------------------------------ ;
	CNOP	0,8
NOSPRIT:DC.L	$FE00FF00,0,0,0,0
; ------------------------------------------------ ;

	CNOP	0,8
TV3Logo:;INCBIN	"data/TV3_Logo.raw"

; ------------------------------------------------ ;
	CNOP	0,8
GBLogo:	INCBIN	"data/AmiGameBoy_Logo.raw"
	CNOP	0,8
GBTeclado:INCBIN	"data/Teclado.raw"
	CNOP	0,8
GBJoyStick:INCBIN	"data/JoyStick.raw"
	CNOP	0,8
GBJoypad:INCBIN	"data/Joypad.raw"
	CNOP	0,8
GBCD32:	INCBIN	"data/CD32.raw"
		CNOP	0,8
MSX2Pub:	;INCBIN	"data/AmiMSX2_Pub.raw"


	CNOP	0,8
Perill:	INCBIN	"data/Perill.raw"	; 0
Cart:	INCBIN	"data/Cart.raw"		; 1
CartB:	INCBIN	"data/CartB.raw"	; 2
CartR:	INCBIN	"data/CartR.raw"	; 3
CartX:	INCBIN	"data/CartX.raw"	; 4
Enfadat:INCBIN	"data/Enfadat.raw"	; 5
Llibre:	INCBIN	"data/Llibre.raw"	; 6
Ram:	INCBIN	"data/Ram.raw"		; 7


	CNOP	0,8
BUSYGFX:
	dc.w	$0000,$0000
	dc.w	$0400,$07C0
	dc.w	$0000,$07C0
	dc.w	$0100,$0380
	dc.w	$0000,$07E0
	dc.w	$07C0,$1FF8
	dc.w	$1FF0,$3FEC
	dc.w	$3FF8,$7FDE
	dc.w	$3FF8,$7FBE
	dc.w	$7FFC,$FF7F
	dc.w	$7EFC,$FFFF
	dc.w	$7FFC,$FFFF
	dc.w	$3FF8,$7FFE
	dc.w	$3FF8,$7FFE
	dc.w	$1FF0,$3FFC
	dc.w	$07C0,$1FF8
	dc.w	$0000,$07E0
	dc.w	$0000,$0000
	dc.w	$0000,$0000
	dc.w	$0000,$0000
; ------------------------------------------------ ;


; =----------------------------------------=> Ondas para sonido.
	CNOP	0,8
Onda3:
	DC.B	$80,$91,$A2,$B3,$C4,$D5,$E6,$F7
	DC.B	$08,$19,$2A,$3B,$4C,$5D,$6E,$7F

	CNOP	0,8
Onda2:
	DC.B	$80,$80,$A4,$A4,$C9,$C9,$ED,$ED
	DC.B	$12,$12,$36,$36,$58,$58,$7F,$7F

	CNOP	0,8
Onda1:
	DC.B	$80,$80,$80,$80,$D5,$D5,$D5,$D5
	DC.B	$2A,$2A,$2A,$2A,$7F,$7F,$7F,$7F

	CNOP	0,8
Onda0:
	DC.B	$80,$80,$80,$80,$80,$80,$80,$80
	DC.B	$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F

	CNOP	0,8
OndaS:	DS.W	$10
; =----------------------------------------<=


; =----------------------------------------=> Sprite de mask.
SpritM:	DS.W	4
	DS.W	4
	DS.L	($90*2*2)
SprGfxM:DCB.L	($90*2*2),$FFFFFFFF
	DS.W	4
; =----------------------------------------<=


	DS.B	32	; Seguridad


; -------------------------------------------------- ;
; -------------------------------------------------- ;
; -------------************************------------- ;
; -------------------------------------------------- ;
; -------------------------------------------------- ;


;	------------------------
	SECTION	Graficos,BSS_C
;	------------------------

; =----------------------------------------=> GameBoy Sprites.
	CNOP	0,8
GBSpr0:	DS.B	32*(144+32)*4
	CNOP	0,8
GBSpr1:	DS.B	32*(144+32)*4

GBSprNex=(32*(144+32)*2)
GBSprBuc=(GBSpr1-GBSpr0)
; =----------------------------------------<=

; =----------------------------------------=> Copper Optiones de Linea.
CopperOpts:	DS.B	1024*8
; =----------------------------------------<=

; =----------------------------------------<=
	DS.B	40*32*2		; Seguridad!
; =----------------------------------------=> Pantallas BackGround/Window
	CNOP	0,8
Sprit0:	DS.W	4
	DS.W	4
	DS.L	($90*2*2)
SprGfx0:DS.B	8*256*2
	DS.W	4
Sprit1:	DS.W	4
	DS.W	4
	DS.L	($90*2*2)
SprGfx1:DS.B	8*256*2
	DS.W	4
Sprit2:	DS.W	4
	DS.W	4
	DS.L	($90*2*2)
SprGfx2:DS.B	8*256*2
	DS.W	4
Sprit3:	DS.W	4
	DS.W	4
	DS.L	($90*2*2)
SprGfx3:DS.B	8*256*2
	DS.W	4
;	---------
Sprit4:	DS.W	4
	DS.W	4
	DS.L	($90*2*2)
SprGfx4:DS.B	8*256*2
	DS.W	4
Sprit5:	DS.W	4
	DS.W	4
	DS.L	($90*2*2)
SprGfx5:DS.B	8*256*2
	DS.W	4
Sprit6:	DS.W	4
	DS.W	4
	DS.L	($90*2*2)
SprGfx6:DS.B	8*256*2
	DS.W	4
Sprit7:	DS.W	4
	DS.W	4
	DS.L	($90*2*2)
SprGfx7:DS.B	8*256*2
	DS.W	4
;	---------
Sprit8:	DS.W	4
	DS.W	4
	DS.L	($90*2*2)
SprGfx8:DS.B	8*256*2
	DS.W	4
Sprit9:	DS.W	4
	DS.W	4
	DS.L	($90*2*2)
SprGfx9:DS.B	8*256*2
	DS.W	4
SpritA:	DS.W	4
	DS.W	4
	DS.L	($90*2*2)
SprGfxA:DS.B	8*256*2
	DS.W	4
SpritB:	DS.W	4
	DS.W	4
	DS.L	($90*2*2)
SprGfxB:DS.B	8*256*2
	DS.W	4
;	---------
SpritC:	DS.W	4
	DS.W	4
	DS.L	($90*2*2)
SprGfxC:DS.B	8*256*2
	DS.W	4
SpritD:	DS.W	4
	DS.W	4
	DS.L	($90*2*2)
SprGfxD:DS.B	8*256*2
	DS.W	4
SpritE:	DS.W	4
	DS.W	4
	DS.L	($90*2*2)
SprGfxE:DS.B	8*256*2
	DS.W	4
SpritF:	DS.W	4
	DS.W	4
	DS.L	($90*2*2)
SprGfxF:DS.B	8*256*2
	DS.W	4
;	---------
NEXSPR=Sprit1-Sprit0
OTRSPR=Sprit4-Sprit0
SIGSPR=Sprit8-Sprit0
; =----------------------------------------<=

; =----------------------------------------<=
	DS.L	20	; Seguridad
; =----------------------------------------<=

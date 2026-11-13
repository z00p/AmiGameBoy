
;	-------------------
;	AmiGameBoy Emulator	(Diseño Basado en AmiMSX2 Emulator)
;	-------------------

;	Diseñado y Programado por: Juan Antonio Gómez Gálvez
;	1997 © RED Soft S.L.  Barcelona, Spain
;	(Jueves 28 de Noviembre de 1996) => (Domingo 19 de Enero 1997)


;	------------------------
	SECTION	GameBoy,CODE
;	------------------------

ColorDebug=1

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

;;	MOVEM.L	Debug,D0-D7/A0-A6
;;	JMP	BUCLE

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

	BRA.S	Vamos
	DC.B	"AmiGameBoy Emulator v1.0 (10.4.09)",0,0
	DC.B	"By: Juan Antonio Gómez Gálvez.",0,0
	CNOP	0,8
Vamos:
	JSR	InitSistema

	IFND	AutoExit	; test builds: leave the game after this many frames (EsActVDP calls)
AutoExit=0
	ENDC
	IFD	EMBED
	JMP	EmbedStart	; EMBED build (build_embed.sh): no menu, run the ROM inside
	ENDC

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
GB_Menu:INCLUDE	"AmiGameBoy_Menu.asm"

	LEA	KeyBase(PC),A6
	ADDQ.L	#8,A4
	MOVE.L	A4,(A6)

	TST.L	D7
	BMI.S	EsContinuar
	MOVE.L	#BUCLE,DirContinua
	CLR.W	DirFlags
EsContinuar:

; -=-=-
	LEA	DirPrefs,A5
	MOVE.B	$08(A5),D0
	AND.W	#$0003,D0
	MOVE.L	(JoyControlPrg.W,PC,D0.W*4),JoyControlRut
; -=-=-
	MOVE.B	$09(A5),D0
	BFINS	D0,BpCon3{$1A:1}
; -=-=-
	MOVE.B	$11(A5),D0
	AND.W	#$0007,D0
	MOVE.L	(Paletas.W,PC,D0.W*4),A0
	MOVE.L	(A0)+,GBPaleta
	MOVE.L	(A0)+,GBPaleta+4
; -=-=-

	LEA	Regs,A3
	BSR	CreaTablas


; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

; ---------------------------------------=> Clear Caches.
	MOVE.L	$4.W,A6
	JSR	-$27C(A6)	; ClearCacheU
; ---------------------------------------<=

; ---------------------------------------=> Parche para MC68060.
	TST.B	EsUn060
	BEQ.S	NoMC060
	MOVE.B	#$80,Mtr0+3
	MOVE.L	#NOP060,Regs+$800
	MOVE.L	#NOP060,Regs+$804
NoMC060:
; ---------------------------------------<=

	JSR	CongelaAMIGA


	LEA	Instr,A0
	MOVE.W	#256-1,D0
BucRelen0:
	MOVE.L	4(A0,D0.W*8),(A0,D0.W*8)
	DBF	D0,BucRelen0


	BSR	InitSonido

	MOVE.L	SP,PILA

	BRA	Z80

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

	CNOP	0,8
JoyControlRut:	DC.L	LeeJoyStick
JoyControlPrg:
	DC.L	LeeJoyStick
	DC.L	LeeTeclado
	DC.L	LeeCD32Joypad
	DC.L	LeeJoypad

	CNOP	0,8
Paletas:DC.L	PaletaGrey
	DC.L	PaletaGreen
	DC.L	PaletaBlue
	DC.L	PaletaRed
	DC.L	PaletaOrange
	DC.L	PaletaOrange
	DC.L	PaletaOrange
	DC.L	PaletaOrange

	CNOP	0,8
MascaraRAM:	DC.W	$0,$0,$0,$3
MascaraROM:	DC.W	$1,$3,$7,$F,$1F,$1F,$1F,$1F

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
InitSistema:
	BSR	ArrTabInst

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

; -=-



; -----------------------------------------------------------------------

; ------------------------------------<

; ------------------------------------> Borra memoria. (A0=Dir.MEM) D0.w=(x/4)-1
	CNOP	0,4
BorraMem:
	CLR.L	(A0)+
	DBF	D0,BorraMem
	RTS
; ------------------------------------<

; ------------------------------------> Crea Tablas de Paginación.
	CNOP	0,4
CreaTabPag:
	LEA	PagRead(A3),A0
	LEA	Restas(A3),A1
	LEA	Desbor(A1),A2	; (CUIDADO: Según Puntero "Restas")
	MOVEQ	#0,D1
	MOVEQ	#(8-1),D0
CreaTabPagBuc:
	MOVE.L	(A0)+,D2	; Punteros de Restas.
	MOVE.W	D2,(A1)+
	ADDQ	#$6,A1

;;;	MOVE.L	(A0)+,D2	; Punteros de Desbordamiento.
	ADD.L	D1,D2
	ADDQ.L	#$1,D2
	MOVE.L	D2,(A2)+
	ADD.L	#$1FFF,D2
	MOVE.L	D2,(A2)+

	ADD.L	#$2000,D1
	DBF	D0,CreaTabPagBuc
	RTS
; ------------------------------------<


; ------------------------------------> Arregla Tabla de Instrucciones Z-80.
	CNOP	0,4
ArrTabInst:
	LEA	Instr,A0
	MOVE.W	#256-1,D0
INSTBUC:
	MOVE.L	(A0,D0.W*4),(A0,D0.W*8)
	MOVE.L	(A0,D0.W*4),4(A0,D0.W*8)
	DBF	D0,INSTBUC
	RTS
; ------------------------------------<

; ------------------------------------> Crea Tablas para Flags.

CreaTablas:

PONP:	MACRO
	MOVEQ	#8-1,D1
	MOVE.B	#9,D2
\@:
	ROR.B	#1,D7
	DBCS	D2,\@2
\@2:	DBF	D1,\@
	BFINS	D2,D3{30:1}
	ENDM

	LEA	TAB_Flags(A3),A0
	MOVE.W	#256-1,D6
	MOVEQ	#0,D0
FLAGSBUC:
	MOVEQ	#0,D7
	OR.B	D0,D7
	MOVE.W	CCR,D3
	PONP
	MOVE.B	D3,(A0)+
;	----
	MOVE.B	D0,D1
	MOVEQ	#0,D2
	BFINS	D1,D2{31:1}	; C	(Ami-b0 => MSX-b0)
	LSR.B	#1,D1
	BFINS	D1,D2{29:1}	; P/V	(Ami-b1 => MSX-b2)
	LSR.B	#1,D1
	BFINS	D1,D2{25:1}	; Z	(Ami-b2 => MSX-b6)
	LSR.B	#1,D1
	BFINS	D1,D2{24:1}	; S	(Ami-b3 => MSX-b7)
;	---
	LSR.B	#1,D1
	BFINS	D1,D2{30:1}	; 	(Ami-b4 => MSX-b1)
	LSR.B	#1,D1
	BFINS	D1,D2{28:1}	; 	(Ami-b5 => MSX-b3)
	LSR.B	#1,D1
	BFINS	D1,D2{27:1}	; 	(Ami-b6 => MSX-b4)
	LSR.B	#1,D1
	BFINS	D1,D2{26:1}	; 	(Ami-b7 => MSX-b5)
;	---
	MOVE.B	D2,(A0)+
;	----
	MOVE.B	D0,D1
	MOVEQ	#0,D2
	BFEXTU	D1{24:1},D3	; S	(MSX-b7 => Ami-b3)
	BFINS	D3,D2{28:1}
	BFEXTU	D1{25:1},D3	; Z	(MSX-b6 => Ami-b2)
	BFINS	D3,D2{29:1}
	BFEXTU	D1{29:1},D3	; P/V	(MSX-b2 => Ami-b1)
	BFINS	D3,D2{30:1}
	BFINS	D1,D2{31:1}	; C	(MSX-b0 => Ami-b0)
;	---
	BFEXTU	D1{26:1},D3	; 	(MSX-b5 => Ami-b7)
	BFINS	D3,D2{24:1}
	BFEXTU	D1{27:1},D3	; 	(MSX-b4 => Ami-b6)
	BFINS	D3,D2{25:1}
	BFEXTU	D1{28:1},D3	; 	(MSX-b3 => Ami-b5)
	BFINS	D3,D2{26:1}
	BFEXTU	D1{30:1},D3	; 	(MSX-b1 => Ami-b4)
	BFINS	D3,D2{27:1}
;	---
	MOVE.B	D2,(A0)+
;	----
	MOVE.B	D0,(A0)+
;	----
	ADDQ.B	#1,D0
	DBF	D6,FLAGSBUC
	RTS
; ------------------------------------<

; ------------------------------------> Inicializa música.
	CNOP	0,8
InitSonido:
	LEA	$DFF000,A6
	BSET	#1,$BFE001		; Datos Musica.

	MOVE.L	#Onda0,$A0(A6)	; wave
	MOVE.L	#Onda0,$B0(A6)
	MOVE.L	#OndaS,$C0(A6)
	MOVE.L	#OndaS,$D0(A6)

	MOVE.W	#$8,$A4(A6)	; Size
	MOVE.W	#$8,$B4(A6)
	MOVE.W	#$10,$C4(A6)
	MOVE.W	#$10,$D4(A6)

	MOVE.W	#0,$A8(A6)	; Volumen
	MOVE.W	#0,$B8(A6)
	MOVE.W	#0,$C8(A6)
	MOVE.W	#0,$D8(A6)

	MOVE.W	#$800F,$96(A6)
	RTS
; ------------------------------------<

; ---------------------------------------=> Power ON  Zilog Z-80 Processor.
	CNOP	0,8
Z80:
	LEA	Regs,A3
	MOVE.L	#-1,EstadoKeys(A3)

	LEA	Debug,A0
	MOVEM.L	(A0),D0-D7/A0-A6

	CMP.L	#BUCLE,DirContinua
	BNE	EsContinue

	LEA	Regs,A3
;	-=-=-=-=-=-=-=-=-=-=-=-		; Borra tabla base de datos.
	MOVE.L	A3,A0
	MOVE.W	#($7C/4)-1,D0
	BSR	BorraMem
;	-=-=-=-=-=-=-=-=-=-=-=-
;	-=-=-=-=-=-=-=-=-=-=-=-		; Inicializa Datos en tabla base.
	MOVE.L	#-1,EstadoJoy(A3)
	MOVE.L	#-1,EstadoKeys(A3)

	CLR.L	SounVol1
	CLR.L	SounVol3
	CLR.L	SounEnv1

	CLR.W	(-4.W,[IntGB1Ant.W,A3])	; Borra Petición de LineInterrupt
	MOVE.W	#$8000,([IntGB1Ant.W,A3])
	LEA	(CopperLine+$12.L),A4	; Pone Petición de LineInterrupt
	MOVE.W	#$0003,-4(A4)
	MOVE.W	#$8011,(A4)
;	-=-=-=-=-=-=-=-=-=-=-=-
;	-=-=-=-=-=-=-=-=-=-=-=-		; Inicializa Sistema de Paginación
	MOVE.L	DirCart,A0
	ADD.W	#$0080,A0
	MOVE.L	A0,PagRead+$0(A3)
	MOVE.L	A0,PagRead+$4(A3)
	ADD.W	#$0080,A0
	MOVE.L	A0,PagRead+$8(A3)
	MOVE.L	A0,PagRead+$C(A3)
	SUB.W	#$4080,A0
	MOVE.L	A0,MapROMBase(A3)

	MOVE.L	#VRAM-$8000,PagRead+$10(A3)
	MOVE.L	#VRAM-$8000,PagWrite+$10(A3)
	MOVE.L	#ERAM0-$A000,PagRead+$14(A3)
	MOVE.L	#ERAM0-$A000,PagWrite+$14(A3)
	MOVE.L	#IRAM-$C000,PagRead+$18(A3)
	MOVE.L	#IRAM-$C000,PagWrite+$18(A3)
	MOVE.L	#RRAM-$E000,PagRead+$1C(A3)
	MOVE.L	#RRAM-$E000,PagWrite+$1C(A3)
;	-=-=-=-=-=-=-=-=-=-=-=-
;	-=-=-=-=-=-=-=-=-=-=-=-		; Inicializa Datos en tabla base.
	BSR	CreaTabPag
;	-=-=-=-=-=-=-=-=-=-=-=-		; Inicializa Mascaras de ROM y RAM.
	MOVE.L	DirCart,A0
	MOVE.B	$80+$149(A0),D0
	AND.W	#$0003,D0
	MOVE.W	(MascaraRAM.w,PC,D0.W*2),MaskRAM(A3)

	MOVE.B	$80+$148(A0),D0
	AND.W	#$0007,D0
	MOVE.W	(MascaraROM.w,PC,D0.W*2),D0
	CMP.W	PagCart,D0
	BLE.S	MascCon
	MOVE.W	PagCart,D0
	SUBQ.W	#$1,D0
	AND.W	#$001F,D0
MascCon:MOVE.W	D0,MaskROM(A3)
;	-=-=-=-=-=-=-=-=-=-=-=-

;	-=-=-=-=-=-=-=-=-=-=-=-
;	-=-=-=-=-=-=-=-=-=-=-=-		; Borra Todas las RAMs.
	LEA	VRAM,A0
	MOVE.W	#($2080/4)-1,D0
	BSR	BorraMem
	LEA	IRAM,A0
	MOVE.W	#($2080/4)-1,D0
	BSR	BorraMem
	LEA	RRAM,A0
	MOVE.W	#($2080/4)-1,D0
	BSR	BorraMem

;;	LEA	ERAM0,A0
;;	MOVE.W	#($2080*4/4)-1,D0
;;	BSR	BorraMem

	LEA	Sprit0,A0
	MOVE.W	#(OTRSPR*4/4)-1,D0
	BSR	BorraMem
	LEA	SprGfx0Fast,A0
	MOVE.W	#(OTRSPR*4/4)-1,D0
	BSR	BorraMem
;	-=-=-=-=-=-=-=-=-=-=-=-

	LEA	Regs,A3 	;  Tabla de datos y Punteros instrucciones Z-80A. 

	LEA	Restas(A3),A2
	MOVE.L	PagRead(A3),A5	;  PC=0100 (Slot 0)
	ADD.W	#$100,A5
	LEA	ESROM,A6	;  SP=0000
	MOVEQ	#0,D0		;  SP Pila
	MOVEQ	#0,D1		;  (Usar solo en .w)
	MOVE.L	#$0100,D2	;  (Truco para DEC/DJNZ) (Usar solo en .b)
	MOVEQ	#0,D3		;  F=00   (Flags/CCR)
	MOVEQ	#0,D4		;  HL=0000
	MOVEQ	#0,D5		;  BC=0000
	MOVEQ	#0,D6		;  DE=0000
	MOVEQ	#0,D7		;  A=00   (Acumulador)
	LEA	RRAM+$1F00,A0	;  Registros de puertos de entrada y Salida
	LEA	VRAM,A1		;  Dirección base de VRAM.
	SUB.L	A4,A4		;  (Uso libre)
EsContinue:
; ----------------------------------
	MOVE.W	#$7FFF,$DFF09C
	NOP
	NOP
EsperaInt0:
	BTST	#$05,$DFF01F
	BEQ.S	EsperaInt0
	NOP
	MOVE.W	#$7FFF,$DFF09C
	NOP
	NOP
EsperaInt1:
	BTST	#$05,$DFF01F
	BEQ.S	EsperaInt1
	NOP
	MOVE.W	#$7FFF,$DFF09C
	NOP
	NOP
EsperaInt2:
	BTST	#$05,$DFF01F
	BEQ.S	EsperaInt2
	NOP
	NOP
	MOVE.W	#$7FFF,$DFF09C
	NOP
	NOP
; ----------------------------------

	MOVEM.L	D1/D2,-(SP)

	MOVE.W	#4,D1
	OR.B	#$40,$BFEE01		; CIAA Libre
TRETARDO0:
	MOVE.B	$DFF006,D2
TRETARDOB0:
	CMP.B	$DFF006,D2
	BEQ.S	TRETARDOB0
	DBF	D1,TRETARDO0
	AND.B	#$BF,$BFEE01		; CIAA Libre

	MOVEM.L	(SP)+,D1/D2

	NOP
	NOP
	SF	$BFEC01
	NOP
	NOP

; ----------------------------------

	MOVE.W	#$C030,$DFF09A		; EI
BUC:	BRA.S	BUC			; JR $FE  (je,je,je)

; ----------------------------------
; ----------------------------------

; ---------------------------------------=>
KeyBase:	DC.L	0
; ---------------------------------------<=


	CNOP	0,8
	DC.B	"RAFY"
BUCLE:
	MOVE.B	(A5)+,D2
	JMP	([A3,D2.W*8])

	CNOP	0,8
	DC.B	"RAFY"
NADA:
;	JMP	SALIR
;	MOVE.W	#$0F0,$DFF180
	MOVE.B	(A5)+,D2
	JMP	([A3,D2.W*8])

	CNOP	0,8
	DC.B	"JAGG"
NOCOD:
	MOVE.B	(A5)+,D2
	JMP	([A3,D2.W*8])

; -----------------------------------------





;	/------------------------------------------------------\
;	|  Z-80 (GameBoy) Macros v5.0  Por Juan Antonio Gómez  |
;	\------------------------------------------------------/

;	D0 = MSX SP (Pila)		A0 = ?
;	D1 = Uso libre en .l/.w		A1 = ?
;	D2 = $01xx.w (Usar en .b)	A2 = Punteros Paginación
;	D3 = F (.b) (CCF de Amiga)	A3 = Datos y Punteros. (Regs)
;	D4 = HL	(.w)			A4 = Uso libre.
;	D5 = BC	(.w)			A5 = PC (Actual)
;	D6 = DE	(.w)			A6 = SP (Actual)
;	D7 = A (.b)			A7 = 

;	Truco para DAA en (A3) (.b)
	
NoInt:	MACRO
	MOVE.W	#$0030,$DFF09A
	ENDM

SiInt:	MACRO
	TST.B	ModoTraza(A3)
	BNE.S	\@
	MOVE.W	#$8030,$DFF09A
\@:
	ENDM


NoInt2:	MACRO
	MOVE.W	#$0034,$DFF09A
	ENDM

SiInt2:	MACRO
	TST.B	ModoTraza(A3)
	BNE.S	\@
	MOVE.W	#$8034,$DFF09A
\@:
	ENDM


CogePag:MACRO
	MOVE.L	\1,\2
	IFC	"D1","\1"
	LSR.W	#8,D1
	LSR.B	#5,D1
	ELSEIF
	BFEXTU	\1{16:3},D1
	ENDC
	ADD.L	PagRead(A3,D1.W*4),\2
	ENDM


CogePagE:MACRO
	MOVE.L	\1,\2
	IFC	"D1","\1"
	LSR.W	#8,D1
	LSR.B	#5,D1
	ELSEIF
	BFEXTU	\1{16:3},D1
	ENDC
	ADD.L	PagWrite(A3,D1.W*4),\2
	ENDM


SaltaPagE:MACRO
	JMP	([PagRuts.W,PC,\1.W*4])
	ENDM


SaltaReg:MACRO
	CMP.W	#$FF00,\1
	BCS.S	\@
	MOVE.B	\1,D2
	CogePag	\1,\2
	JSR	([RegsIN-$400.W,PC,D2.W*4])	; Salta a puntero de emulación.
	BRA.S	\@2
\@:
	CogePag	\1,\2
\@2:
	ENDM

RegistE:MACRO
	CMP.W	#$FF00,\1
	BCS.S	\@
	MOVE.B	\1,D2
	JMP	([RegsOUT-$400.W,PC,D2.W*4])	; Salta a puntero de emulación.
	CNOP	0,4
\@:
	ENDM


NULO:	MACRO
	CNOP	0,8
	DC.B	"RAFY"
	ENDM

IDEN:	MACRO
	CNOP	0,8
	DC.B	"GG"
\@ID:
	ENDM


PARDAAS:MACRO
	MOVE.B	D7,(A3)
	ENDM

PARDAAR:MACRO
	MOVE.B	D7,(A3)
	ENDM


Otra:	MACRO
	MOVE.B	(A5)+,D2
	JMP	([A3,D2.W*8])
	CNOP	0,8
;	NOP
;	NOP
;	NOP
;	NOP
;	NOP
;	NOP
;	BRA.S	\@
	DC.B	"GG"
;\@:
	ENDM

Otra2:	MACRO
	MOVE.B	(A5)+,D2
	JMP	([A3,D2.W*8])
	CNOP	0,8
	ENDM

OtraEI:	MACRO
	MOVE.B	(A5)+,D2
	MOVE.W	D2,D1
	JMP	([A3,D2.W*8])
	CNOP	0,8
	ENDM

OtraT:	MACRO
	MOVE.W	CCR,D3
	Otra	\1
	ENDM

OtraC:	MACRO
	ROXL.B	#1,D3
	Otra
	ENDM

OtraC2:	MACRO
	BCC.S	\@
	OR.B	#$01,D3
	Otra2
\@:
	AND.B	#$FE,D3
	Otra
	ENDM

OtraP:	MACRO
	MOVE.B	Flags_Par(A3,D7.W*4),D3
	Otra
	ENDM

OtraV:	MACRO
	BNE.S	\@
	AND.B	#$FD,D3
	Otra2
\@:
	OR.B	#$02,D3
	Otra2
	ENDM

OtraZ:	MACRO
	BEQ.S	\@
	AND.B	#$FB,D3
	Otra2
\@:
	OR.B	#$04,D3
	Otra
	ENDM

PONF:	MACRO
	IFC	"S","\1"
	MOVE.B	D3,D1
	ELSEIF
	IFC	"X","\2"
	LSR.B	#1,D3
	OR.B	#$04,CCR
	ELSEIF
	IFC	"C","\1"
	LSR.B	#1,D3
	ENDC
	ENDC
	ENDC
	ENDM

PONS:	MACRO
	BFINS	D1,D3{31:1}
	ENDM

OtraS:	MACRO
	MOVE.W	CCR,D3
	PONS
	Otra
	ENDM


PonCCR:	MACRO
	IFC	"N","\1"
	Otra			; NO guarda flags.
	ENDC
	IFC	"T","\1"
	OtraT			; Guarda todos los flags.
	ENDC
	IFC	"S","\1"
	OtraS			; Guarda flags SZV.
	ENDC
	IFC	"C","\1"
	OtraC			; Guarda flag C.
	ENDC
	IFC	"Z","\1"
	OtraZ			; Guarda flag Z.
	ENDC
	IFC	"P","\1"
	OtraP			; Guarda flag P y demás.
	ENDC
	ENDM


CheckB:	MACRO
	CMP.L	Desbor+4(A2),A5
	BLE.S	\@NO
	SUBQ.W	#1,A5
	MOVE.W	A5,D1
	SUB.W	(A2),D1
	CogePag	D1,A5
	LEA	Restas(A3,D1.W*8),A2
	MOVE.B	(A5)+,\1
\@NO:
	ENDM


CheckW:	MACRO
	CMP.L	Desbor+4(A2),A5
	BLE.S	\@NO
	ROR.W	#8,\1
	MOVE.B	\1,D2
	SUBQ.W	#1,A5
	MOVE.W	A5,D1
	SUB.W	(A2),D1
	TST.B	D1
	BEQ.S	\@M2
	SUBQ.W	#1,D1
	CogePag	D1,A5
	LEA	Restas(A3,D1.W*8),A2
	MOVE.W	(A5)+,\1
	BRA.S	\@NO
	CNOP	0,8
\@M2:
	CogePag	D1,A5
	LEA	Restas(A3,D1.W*8),A2
	MOVE.B	D2,\1
	LSL.W	#8,\1
	MOVE.B	(A5)+,\1
\@NO:
	ENDM



; ---------------------------------------------------------------------
; *********************************************************************
; ---------------------------------------------------------------------

;;		  \1    \2      \3    \4   \5     \6
;;	MINS	Instr,Destino,Origen,Modo,Flags,Ini.Flags

MINS:	MACRO

	IFC	"0","\4"		; Todo con registro bajos.
	PONF	\5,\6
	\1	\3,\2
	PonCCR	\5,\7			; Recoge Flags.
	ENDC

	IFC	"0B","\4"		; Todo con registro bajos.
	PONF	\5,\6
	\1	\3,\2
	PonCCR	\5,\7			; Recoge Flags.
	NULO
	ENDC

	IFC	"1","\4"		; Registro alto con registro bajo.
	MOVE.W	\3,D1
	LSR.W	#8,D1
	PONF	\5,\6
	\1	D1,\2
	PonCCR	\5,\7			; Recoge Flags.
	ENDC

	IFC	"2","\4"		; Todo con registros (HL,DE,BC)
	PONF	\5,\6
	\1	\3,\2
	PonCCR	\5,\7			; Recoge Flags.
	ENDC


	IFC	"3","\4"		; Registro (HL) con registro A.
	SaltaReg \3,A4
;*	CogePag	\3,A4
	\1	(A4),\2
	PonCCR	\5,\7			; Recoge Flags.
	ENDC


	IFC	"7","\4"		; Ins. DEC. registros Altos.
	MOVE.B	D3,D1
	MOVE.B	\2,D2
	\1	D2,\2
	MOVE.W	CCR,D3
	BFINS	D1,D3{31:1}
	MOVE.B	D2,\2
	Otra
 	ENDC

	IFC	"7B","\4"		; Ins. INC registros Altos.
	MOVE.B	D3,D1
	\1	#$100,\2
	MOVE.W	CCR,D3
	BFINS	D3,D3{29:1}
	BFINS	D1,D3{31:1}
	Otra
 	ENDC

	IFC	"8","\4"		; Para Ins. destino (HL)
	CogePagE \2,A4
	PONF	\5,\6
	\1	\3,(A4)
	PonCCR	\5,\7			; Recoge Flags.
	ENDC

	IFC	"8I","\4"		; Para Ins. destino (HL)
	CogePagE \2,A4
	PONF	\5,\6
	\1	\3,(A4)
	SaltaPagE D1
	PonCCR	\5,\7			; Recoge Flags.
	NULO
	ENDC

	IFC	"8Y","\4"		; Para Ins. destino (HL) Leer
	SaltaReg \2,A4
;*	CogePag \2,A4
	PONF	\5,\6
	\1	\3,(A4)
	PonCCR	\5,\7			; Recoge Flags.
	NULO
	ENDC

	IFC	"10","\4"		; Operación de (N) en registro A.
	MOVE.B	(A5)+,D2
	BEQ.S	\@M
	PONF	\5,\6
	\1	D2,\2
	PonCCR	\5,\7			; Recoge Flags.
	NULO
\@M:	CheckB	D2
	PONF	\5,\6
	\1	D2,\2
	PonCCR	\5,\7			; Recoge Flags.
	ENDC

	IFC	"11","\4"		; (Modo no soportado de "3")
	CogePag	\3,A4			; Registro (HL) con registro A.
	MOVE.B	(A4),D2
	PONF	\5,\6
	\1	D2,\2
	PonCCR	\5,\7			; Recoge Flags.
	ENDC

	ENDM


; ---------------------------------------------------------------------
; *********************************************************************
; ---------------------------------------------------------------------


MROT:	MACRO
	IFC	"2","\4"		; Rotación con (HL)
	CogePagE \2,A4
	MOVE.B	(A4),D2
	IFC	"S","\3"
	OR.B	#$10,CCR
	ENDC
	IFC	"X","\3"
	LSR.B	#1,D3
	ENDC
	\1	#1,D2
	MOVE.W	CCR,D3
	MOVE.B	D2,(A4)
	ENDC


	IFC	"0","\4"		; Rotación en registros bajos.
	IFC	"S","\3"
	OR.B	#$10,CCR
	ENDC
	IFC	"X","\3"
	LSR.B	#1,D3
	ENDC
	\1	#1,\2
	MOVE.W	CCR,D3
	ENDC

	IFC	"1","\4"		; Rotación en registros altos.
	ROR.W	#8,\2
	IFC	"S","\3"
	OR.B	#$10,CCR
	ENDC
	IFC	"X","\3"
	LSR.B	#1,D3
	ENDC
	\1	#1,\2
	MOVE.W	CCR,D3
	ROR.W	#8,\2
	ENDC
; ---------------------------
	Otra2				; Recoge Flags.
; ---------------------------
	ENDM


; ---------------------------------------------------------------------
; *********************************************************************
; ---------------------------------------------------------------------


MLDRR:	MACRO

	IFC	"0","\3"	; Mover registros bajos.
	MOVE.B	\2,\1
	Otra
	ENDC


	IFC	"0A","\3"	; Mover de (N) a registro bajo.
	SaltaReg \2,A4
;*	CogePag	\2,A4
	MOVE.B	(A4),\1
	Otra
	ENDC


	IFC	"0B","\3"	; Mover de (N) a registro alto.
	SaltaReg \2,A4
;*	CogePag	\2,A4
	MOVE.B	\1,D2
	MOVE.W	(A4),\1
	MOVE.B	D2,\1
	Otra
	ENDC


	IFC	"1","\3"	; Mover registros altos.
	MOVE.W	\2,D1
	MOVE.B	\1,D1
	MOVE.W	D1,\1
	Otra
	ENDC


	IFC	"2","\3"	; Mover registro bajo a alto de reg. de 16bits.
	MOVE.B	\1,D1
	LSL.W	#8,\2
	MOVE.B	D1,\1
	Otra
	ENDC


	IFC	"3","\3"	; Mover registro alto a bajo de reg. de 16bits.
	MOVE.W	\2,D1
	LSR.W	#8,D1
	MOVE.B	D1,\1
	Otra
	ENDC


	IFC	"4","\3"	; Mover registro bajo a alto.
	BFINS	\2,\1{16:8}
	Otra
	ENDC


	IFC	"5","\3"	; Mover registro alto a bajo.
	MOVE.W	\2,D1
	LSR.W	#8,D1
	MOVE.B	D1,\1
	Otra
	ENDC


	IFC	"7","\3"	; Mover registro alto a registro A.
	MOVE.W	\2,\1
	LSR.W	#8,\1
	Otra
	ENDC


	IFC	"9","\3"	; Mover de HL,BC,DE,IX,IY,SP a (NN)
	MOVE.W	(A5)+,D1
	TST.B	D1
	BEQ.S	\@M
	ROR.W	#8,D1
	CogePagE D1,A4
	MOVE.W	\1,D1
	ROR.W	#8,D1
	MOVE.W	D1,(A4)
	Otra2
\@M:	CheckW	D1
	ROR.W	#8,D1
	CogePagE D1,A4
	MOVE.W	\1,D1
	ROR.W	#8,D1
	MOVE.W	D1,(A4)
	Otra
	ENDC


	IFC	"10","\3"	; Mover registros bajos a (HL,DE,BC)
	CogePagE \1,A4
	MOVE.B	\2,(A4)
	SaltaPagE D1
	Otra
	ENDC


	IFC	"11","\3"	; Mover registros altos a (HL,DE,BC)
	MOVE.W	\2,D1
	LSR.W	#8,D1
	MOVE.B	D1,D2
	CogePagE \1,A4
	MOVE.B	D2,(A4)
	SaltaPagE D1
	Otra
	ENDC


	IFC	"14","\3"		; LD.b \1,N  Altos
	MOVE.B	\1,D2
	MOVE.B	(A5)+,\1
	BEQ.S	\@M
	LSL.W	#8,\1
	MOVE.B	D2,\1
	Otra2
\@M:	CheckB	\1
	LSL.W	#8,\1
	MOVE.B	D2,\1
	Otra
	ENDC


	IFC	"15","\3"		; LD.b \1,N  Bajos
	MOVE.B	(A5)+,\1
	BEQ.S	\@M
	Otra2
\@M:	CheckB	\1
	Otra
	ENDC


	IFC	"16","\3"		; LD.w \1,NN
	MOVE.W	(A5)+,\1
	TST.B	\1
	BEQ.S	\@M
	ROR.W	#8,\1
	Otra2
\@M:	CheckW	\1
	ROR.W	#8,\1
	Otra
	ENDC


	IFC	"17S","\3"		; LD.w \1,NN  SP
	MOVE.W	(A5)+,D0
	TST.B	D0
	BEQ.S	\@M
	ROR.W	#8,D0
	MOVE.W	D0,D1
	CogePagE D1,\1
	Otra2
\@M:	CheckW	D0
	ROR.W	#8,D0
	MOVE.W	D0,D1
	CogePag	D1,\1
	Otra
	ENDC

; -=-=-

	IFC	"10I","\3"	; Mover registros bajos a (N+)
	CogePagE \1,A4
	MOVE.B	\2,(A4)
	ADDQ.W	#1,\1
	SaltaPagE D1
	Otra
	ENDC

	IFC	"10D","\3"	; Mover registros bajos a (N-)
	CogePagE \1,A4
	MOVE.B	\2,(A4)
	SUBQ.W	#1,\1
	SaltaPagE D1
	Otra
	ENDC


	IFC	"0AI","\3"	; Mover de (N+) a registro bajo.
	SaltaReg \2,A4
;*	CogePag	\2,A4
	MOVE.B	(A4),\1
	ADDQ.W	#1,\2
	Otra
	ENDC

	IFC	"0AD","\3"	; Mover de (N-) a registro bajo.
	SaltaReg \2,A4
;*	CogePag	\2,A4
	MOVE.B	(A4),\1
	SUBQ.W	#1,\2
	Otra
	ENDC

	ENDM

; ---------------------------------------------------------------------
; *********************************************************************
; ---------------------------------------------------------------------


MJR:	MACRO
	MOVE.B	(A5)+,D1
	BEQ.S	\@M
	EXT.W	D1
	ADD.W	D1,A5
	Otra2
\@M:	CheckB	D1
	EXT.W	D1
	ADD.W	D1,A5
	Otra
	ENDM

MJRC:	MACRO
	MOVE.W	D3,CCR
	B\1.S	\@
	ADDQ.W	#1,A5
	Otra2
\@:	MJR
	ENDM

; ---------------------------------------------------------------------
; *********************************************************************
; ---------------------------------------------------------------------

MJP:	MACRO
	MOVE.W	(A5)+,D1
	TST.B	D1
	BEQ.S	\@M
	ROR.W	#8,D1
	CogePag	D1,A5
	LEA	Restas(A3,D1.W*8),A2
	Otra2
\@M:	CheckW	D1
	ROR.W	#8,D1
	CogePag	D1,A5
	LEA	Restas(A3,D1.W*8),A2
	Otra
	ENDM

MJPC:	MACRO
	MOVE.W	D3,CCR
	B\1.S	\@
	ADDQ.W	#2,A5
	Otra2
\@:	MJP
	ENDM

; ---------------------------------------------------------------------
; *********************************************************************
; ---------------------------------------------------------------------

MCALL:	MACRO
	MOVE.W	(A5)+,D1
	TST.B	D1
	BEQ.S	\@M
	ROR.W	#8,D1
	MOVE.L	A5,A4
	SUB.W	(A2),A4
	CogePag	D1,A5
	LEA	Restas(A3,D1.W*8),A2
	SUBQ.B	#2,D0
	BCS.S	\@D
	MOVE.W	A4,D1
	ROR.W	#8,D1
	MOVE.W	D1,-(A6)
	Otra2
\@M:	CheckW	D1
	ROR.W	#8,D1
	MOVE.L	A5,A4
	SUB.W	(A2),A4
	CogePag	D1,A5
	LEA	Restas(A3,D1.W*8),A2
	SUBQ.B	#2,D0
	BCS.S	\@D
	MOVE.W	A4,D1
	ROR.W	#8,D1
	MOVE.W	D1,-(A6)
	Otra2
\@D:
	SUB.W	#$100,D0
	MOVE.W	D0,D1
	ADDQ.W	#1,D1
	CogePagE D1,A6
	MOVE.W	A4,D1
	MOVE.B	D1,D2
	LSR.W	#8,D1
	MOVE.B	D1,(A6)
	MOVE.W	D0,D1
	CogePagE D1,A6
	MOVE.B	D2,(A6)
	Otra
	ENDM

MCALLC:	MACRO
	MOVE.W	D3,CCR
	B\1.S	\@
	ADDQ.W	#2,A5
	Otra2
\@:	MCALL
	ENDM

; ---------------------------------------------------------------------
; *********************************************************************
; ---------------------------------------------------------------------

MRST:	MACRO
	MOVE.W	A5,D1
	SUB.W	(A2),D1
	LEA	Restas(A3),A2
	MOVE.L	PagRead(A3),A4
	LEA	\1(A4),A5
	SUBQ.B	#2,D0
	BCS.S	\@D
	ROR.W	#8,D1
	MOVE.W	D1,-(A6)
	Otra2
\@D:
	MOVE.W	D1,A4
	SUB.W	#$100,D0
	MOVE.W	D0,D1
	ADDQ.W	#1,D1
	CogePagE D1,A6
	MOVE.W	A4,D1
	MOVE.B	D1,D2
	LSR.W	#8,D1
	MOVE.B	D1,(A6)
	MOVE.W	D0,D1
	CogePagE D1,A6
	MOVE.B	D2,(A6)
	Otra
	ENDM

; ---------------------------------------------------------------------
; *********************************************************************
; ---------------------------------------------------------------------

MPUSH:	MACRO
	IFC	"AF","\1"
	BFEXTU	D0{23:8},D1
	MOVE.B	(A3),Flags_DAA(A3,D1.W*4)
	ENDC

	SUBQ.B	#2,D0
	BCS.S	\@D
	IFNC	"AF","\1"
	MOVE.W	\1,D1
	ROR.W	#8,D1
	MOVE.W	D1,-(A6)
	Otra2
\@D:
	SUB.W	#$100,D0
	MOVE.W	D0,D1
	ADDQ.W	#1,D1
	CogePagE D1,A6
	MOVE.W	\1,D1
	MOVE.B	D1,D2
	LSR.W	#8,D1
	MOVE.B	D1,(A6)
	MOVE.W	D0,D1
	CogePagE D1,A6
	MOVE.B	D2,(A6)
	Otra

	ELSEIF
	MOVE.B	D7,-(A6)
	MOVE.B	Flags_Push(A3,D3.W*4),-(A6)
	Otra2
\@D:
	SUB.W	#$100,D0
	MOVE.W	D0,D1
	ADDQ.W	#1,D1
	CogePagE D1,A6
	MOVE.B	D7,(A6)
	MOVE.W	D0,D1
	CogePagE D1,A6
	MOVE.B	Flags_Push(A3,D3.W*4),(A6)
	Otra
	ENDC
	ENDM


MPOP:	MACRO
	ADDQ.B	#2,D0
	BCS.S	\@D
	IFC	"0","\2"
	MOVE.W	(A6)+,\1
	ROR.W	#8,\1
	Otra2
\@D:	ADD.W	#$100,D0
	MOVE.W	D0,D1
	SUBQ.W	#1,D1
	CogePagE D1,A4
	MOVE.W	(A4),\1
	MOVE.B	(A6),\1
	MOVE.W	D0,D1
	CogePagE D1,A6
	Otra

	ELSEIF
	IFNC	"AF","\1"
	MOVE.W	(A6)+,D1
	ROR.W	#8,D1
	MOVE.L	D1,\1
	Otra2
\@D:
	ADD.W	#$100,D0
	MOVE.W	D0,D1
	SUBQ.W	#1,D1
	CogePagE D1,A4
	MOVE.W	(A4),D1
	MOVE.B	(A6),D1
	MOVE.L	D1,\1
	MOVE.W	D0,D1
	CogePagE D1,A6
	Otra

	ELSEIF
	MOVE.B	(A6)+,D3
	MOVE.B	(A6)+,D7
	MOVE.B	Flags_Pop(A3,D3.W*4),D3
	BFEXTU	D0{23:8},D1
	MOVE.B	Flags_DAA(A3,D1.W*4),(A3)
	Otra2
\@D:	ADD.W	#$100,D0
	MOVE.W	D0,D1
	SUBQ.W	#1,D1
	MOVE.B	(A6),D3
	CogePagE D1,A6
	MOVE.B	(A6),D7
	MOVE.B	Flags_Pop(A3,D3.W*4),D3
	MOVE.W	D0,D1
	CogePagE D1,A6
	BFEXTU	D0{23:8},D1
	MOVE.B	Flags_DAA(A3,D1.W*4),(A3)
	Otra
	ENDC
	ENDC
	ENDM

; ---------------------------------------------------------------------
; *********************************************************************
; ---------------------------------------------------------------------

MRET:	MACRO
	ADDQ.B	#2,D0
	BCS.S	\@D
	MOVE.W	(A6)+,D1
\@2:	ROR.W	#8,D1
\@3:	CogePag	D1,A5
	LEA	Restas(A3,D1.W*8),A2
	Otra2
\@D:
	ADD.W	#$100,D0
	MOVE.W	D0,D1
	SUBQ.W	#1,D1
	CogePagE D1,A4
	MOVE.W	(A4),D1
	MOVE.B	(A6),D1
	MOVE.W	D1,A4
	MOVE.W	D0,D1
	CogePagE D1,A6
	MOVE.W	A4,D1
	BRA.S	\@3
	IDEN
	ENDM

MRETC:	MACRO
	MOVE.W	D3,CCR
	B\1.S	\@
	Otra2
\@:	MRET	\2
	ENDM

; ---------------------------------------------------------------------
; *********************************************************************
; ---------------------------------------------------------------------

; -----------------------  ADD / SUB  ---------------
	IDEN
ADCAA:	PARDAAS
	MINS	ADDX.B,D7,D7,0,T,X,1
ADDAA:	PARDAAS
	MINS	ADD.B,D7,D7,0,T,N,1
ADCAB:	PARDAAS
	MINS	ADDX.B,D7,D5,1,T,X,1
ADDAB:	PARDAAS
	MINS	ADD.B,D7,D5,1,T,N,1
ADCAC:	PARDAAS
	MINS	ADDX.B,D7,D5,0,T,X,1
ADDAC:	PARDAAS
	MINS	ADD.B,D7,D5,0,T,N,1
ADCAD:	PARDAAS
	MINS	ADDX.B,D7,D6,1,T,X,1
ADDAD:	PARDAAS
	MINS	ADD.B,D7,D6,1,T,N,1
ADCAE:	PARDAAS
	MINS	ADDX.B,D7,D6,0,T,X,1
ADDAE:	PARDAAS
	MINS	ADD.B,D7,D6,0,T,N,1
ADCAH:	PARDAAS
	MINS	ADDX.B,D7,D4,1,T,X,1
ADDAH:	PARDAAS
	MINS	ADD.B,D7,D4,1,T,N,1
ADCAL:	PARDAAS
	MINS	ADDX.B,D7,D4,0,T,X,1
ADDAL:	PARDAAS
	MINS	ADD.B,D7,D4,0,T,N,1
ADCAN:	PARDAAS
	MINS	ADDX.B,D7,N,10,T,X,2
ADDAN:	PARDAAS
	MINS	ADD.B,D7,N,10,T,N,2
ADCAHL:	PARDAAS
	MINS	ADDX.B,D7,D4,11,T,X,1
ADDAHL:	PARDAAS
	MINS	ADD.B,D7,D4,3,T,N,1

	NULO
ADCHLHL:MINS	ADDX.W,D4,D4,2,T,X,2
ADDHLHL:MINS	ADD.W,D4,D4,2,C,N,1
	NULO
ADCHLBC:MINS	ADDX.W,D4,D5,2,T,X,2
ADDHLBC:MINS	ADD.W,D4,D5,2,C,N,1
	NULO
ADCHLDE:MINS	ADDX.W,D4,D6,2,T,X,2
ADDHLDE:MINS	ADD.W,D4,D6,2,C,N,1
	NULO
ADCHLSP:MINS	ADDX.W,D4,D0,2,T,X,2
ADDHLSP:MINS	ADD.W,D4,D0,2,C,N,1

	IDEN
SBCA:	PARDAAR
	MINS	SUBX.B,D7,D7,0,T,X,1
SUBA:	PARDAAR
	MINS	SUB.B,D7,D7,0,T,N,1
SBCB:	PARDAAR
	MINS	SUBX.B,D7,D5,1,T,X,1
SUBB:	PARDAAR
	MINS	SUB.B,D7,D5,1,T,N,1
SBCC:	PARDAAR
	MINS	SUBX.B,D7,D5,0,T,X,1
SUBC:	PARDAAR
	MINS	SUB.B,D7,D5,0,T,N,1
SBCD:	PARDAAR
	MINS	SUBX.B,D7,D6,1,T,X,1
SUBD:	PARDAAR
	MINS	SUB.B,D7,D6,1,T,N,1
SBCE:	PARDAAR
	MINS	SUBX.B,D7,D6,0,T,X,1
SUBE:	PARDAAR
	MINS	SUB.B,D7,D6,0,T,N,1
SBCH:	PARDAAR
	MINS	SUBX.B,D7,D4,1,T,X,1
SUBH:	PARDAAR
	MINS	SUB.B,D7,D4,1,T,N,1
SBCL:	PARDAAR
	MINS	SUBX.B,D7,D4,0,T,X,1
SUBL:	PARDAAR
	MINS	SUB.B,D7,D4,0,T,N,1
SBCN:	PARDAAR
	MINS	SUBX.B,D7,N,10,T,X,2
SUBN:	PARDAAR
	MINS	SUB.B,D7,N,10,T,N,2
SBCHL:	PARDAAR
	MINS	SUBX.B,D7,D4,11,T,X,2
SUBHL:	PARDAAR
	MINS	SUB.B,D7,D4,3,T,N,2


	NULO
SBCHLHL:MINS	SUBX.W,D4,D4,2,T,X,2
	NULO
SBCHLBC:MINS	SUBX.W,D4,D5,2,T,X,2
	NULO
SBCHLDE:MINS	SUBX.W,D4,D6,2,T,X,2
	NULO
SBCHLSP:MINS	SUBX.W,D4,D0,2,T,X,2

; -------------------  INC / DEC  ---------------

	IDEN
INCA:	PARDAAS
	MINS	ADDQ.B,D7,#1,0,S,N,1
INCH:	MINS	ADDI.W,D4,#0,7B,S,N,1
INCL:	MINS	ADDQ.B,D4,#1,0,S,N,1
INCB:	MINS	ADDI.W,D5,#0,7B,S,N,1
INCC:	MINS	ADDQ.B,D5,#1,0,S,N,1
INCD:	MINS	ADDI.W,D6,#0,7B,S,N,1
INCE:	MINS	ADDQ.B,D6,#1,0,S,N,1

INCHLM:	MINS	ADDQ.B,D4,#1,8,S,N,1

INCHL:	MINS	ADDQ.W,D4,#1,2,N,N,1
INCBC:	MINS	ADDQ.W,D5,#1,2,N,N,1
INCDE:	MINS	ADDQ.W,D6,#1,2,N,N,1

INCSP:
	ADDQ.W	#1,D0
	MOVE.W	D0,D1
	CogePagE D1,A6
	Otra	


DECA:	PARDAAR
	MINS	SUBQ.B,D7,#1,0,S,N,1
DECH:	MINS	SUB.W,D4,#0,7,S,N,1
DECL:	MINS	SUBQ.B,D4,#1,0,S,N,1
DECB:	MINS	SUB.W,D5,#0,7,S,N,1
DECC:	MINS	SUBQ.B,D5,#1,0,S,N,1
DECD:	MINS	SUB.W,D6,#0,7,S,N,1
DECE:	MINS	SUBQ.B,D6,#1,0,S,N,1

DECHLM:	MINS	SUBQ.B,D4,#1,8,S,N,1

DECHL:	MINS	SUBQ.W,D4,#1,2,N,N,1
DECBC:	MINS	SUBQ.W,D5,#1,2,N,N,1
DECDE:	MINS	SUBQ.W,D6,#1,2,N,N,1

DECSP:
	SUBQ.W	#1,D0
	MOVE.W	D0,D1
	CogePagE D1,A6
	Otra	

; -----------------------  AND  ---------------

ANDA:	MINS	AND.B,D7,D7,0,P,N,1
ANDH:	MINS	AND.B,D7,D4,1,P,N,1
ANDL:	MINS	AND.B,D7,D4,0,P,N,1
ANDB:	MINS	AND.B,D7,D5,1,P,N,1
ANDC:	MINS	AND.B,D7,D5,0,P,N,1
ANDD:	MINS	AND.B,D7,D6,1,P,N,1
ANDE:	MINS	AND.B,D7,D6,0,P,N,1
ANDN:	MINS	AND.B,D7,N,10,P,N,2

ANDHL:	MINS	AND.B,D7,D4,3,P,N,1

; -----------------------  OR  ---------------

ORA:	MINS	OR.B,D7,D7,0,P,N,1
ORH:	MINS	OR.B,D7,D4,1,P,N,1
ORL:	MINS	OR.B,D7,D4,0,P,N,1
ORB:	MINS	OR.B,D7,D5,1,P,N,1
ORC:	MINS	OR.B,D7,D5,0,P,N,1
ORD:	MINS	OR.B,D7,D6,1,P,N,1
ORE:	MINS	OR.B,D7,D6,0,P,N,1
ORN:	MINS	OR.B,D7,N,10,P,N,2

ORHL:	MINS	OR.B,D7,D4,3,P,N,1

; -----------------------  CP  ---------------

CPA:	MINS	CMP.B,D7,D7,0,T,N,1
CPH:	MINS	CMP.B,D7,D4,1,T,N,1
CPL:	MINS	CMP.B,D7,D4,0,T,N,1
CPB:	MINS	CMP.B,D7,D5,1,T,N,1
CPC:	MINS	CMP.B,D7,D5,0,T,N,1
CPD:	MINS	CMP.B,D7,D6,1,T,N,1
CPE:	MINS	CMP.B,D7,D6,0,T,N,1
CPN:	MINS	CMP.B,D7,N,10,T,N,2

CPHL:	MINS	CMP.B,D7,D4,3,T,N,1

; -----------------------  XOR  ---------------

XORA:	MINS	EOR.B,D7,D7,0,P,N,1
XORH:	MINS	EOR.B,D7,D4,1,P,N,1
XORL:	MINS	EOR.B,D7,D4,0,P,N,1
XORB:	MINS	EOR.B,D7,D5,1,P,N,1
XORC:	MINS	EOR.B,D7,D5,0,P,N,1
XORD:	MINS	EOR.B,D7,D6,1,P,N,1
XORE:	MINS	EOR.B,D7,D6,0,P,N,1
XORN:	MINS	EOR.B,D7,N,10,P,N,2

XORHL:	MINS	EOR.B,D7,D4,11,P,N,1

; -----------------------  BIT  ---------------

	NULO
BIT0A:	MINS	BTST,D7,#0,0B,Z,N,2
BIT0H:	MINS	BTST,D4,#8,0B,Z,N,2
BIT0L:	MINS	BTST,D4,#0,0B,Z,N,2
BIT0B:	MINS	BTST,D5,#8,0B,Z,N,2
BIT0C:	MINS	BTST,D5,#0,0B,Z,N,2
BIT0D:	MINS	BTST,D6,#8,0B,Z,N,2
BIT0E:	MINS	BTST,D6,#0,0B,Z,N,2

BIT0HL:	MINS	BTST,D4,#0,8Y,Z,N,2


BIT1A:	MINS	BTST,D7,#1,0B,Z,N,2
BIT1H:	MINS	BTST,D4,#9,0B,Z,N,2
BIT1L:	MINS	BTST,D4,#1,0B,Z,N,2
BIT1B:	MINS	BTST,D5,#9,0B,Z,N,2
BIT1C:	MINS	BTST,D5,#1,0B,Z,N,2
BIT1D:	MINS	BTST,D6,#9,0B,Z,N,2
BIT1E:	MINS	BTST,D6,#1,0B,Z,N,2

BIT1HL:	MINS	BTST,D4,#1,8Y,Z,N,2


BIT2A:	MINS	BTST,D7,#2,0B,Z,N,2
BIT2H:	MINS	BTST,D4,#10,0B,Z,N,2
BIT2L:	MINS	BTST,D4,#2,0B,Z,N,2
BIT2B:	MINS	BTST,D5,#10,0B,Z,N,2
BIT2C:	MINS	BTST,D5,#2,0B,Z,N,2
BIT2D:	MINS	BTST,D6,#10,0B,Z,N,2
BIT2E:	MINS	BTST,D6,#2,0B,Z,N,2

BIT2HL:	MINS	BTST,D4,#2,8Y,Z,N,2


BIT3A:	MINS	BTST,D7,#3,0B,Z,N,2
BIT3H:	MINS	BTST,D4,#11,0B,Z,N,2
BIT3L:	MINS	BTST,D4,#3,0B,Z,N,2
BIT3B:	MINS	BTST,D5,#11,0B,Z,N,2
BIT3C:	MINS	BTST,D5,#3,0B,Z,N,2
BIT3D:	MINS	BTST,D6,#11,0B,Z,N,2
BIT3E:	MINS	BTST,D6,#3,0B,Z,N,2

BIT3HL:	MINS	BTST,D4,#3,8Y,Z,N,2


BIT4A:	MINS	BTST,D7,#4,0B,Z,N,2
BIT4H:	MINS	BTST,D4,#12,0B,Z,N,2
BIT4L:	MINS	BTST,D4,#4,0B,Z,N,2
BIT4B:	MINS	BTST,D5,#12,0B,Z,N,2
BIT4C:	MINS	BTST,D5,#4,0B,Z,N,2
BIT4D:	MINS	BTST,D6,#12,0B,Z,N,2
BIT4E:	MINS	BTST,D6,#4,0B,Z,N,2

BIT4HL:	MINS	BTST,D4,#4,8Y,Z,N,2


BIT5A:	MINS	BTST,D7,#5,0B,Z,N,2
BIT5H:	MINS	BTST,D4,#13,0B,Z,N,2
BIT5L:	MINS	BTST,D4,#5,0B,Z,N,2
BIT5B:	MINS	BTST,D5,#13,0B,Z,N,2
BIT5C:	MINS	BTST,D5,#5,0B,Z,N,2
BIT5D:	MINS	BTST,D6,#13,0B,Z,N,2
BIT5E:	MINS	BTST,D6,#5,0B,Z,N,2

BIT5HL:	MINS	BTST,D4,#5,8Y,Z,N,2


BIT6A:	MINS	BTST,D7,#6,0B,Z,N,2
BIT6H:	MINS	BTST,D4,#14,0B,Z,N,2
BIT6L:	MINS	BTST,D4,#6,0B,Z,N,2
BIT6B:	MINS	BTST,D5,#14,0B,Z,N,2
BIT6C:	MINS	BTST,D5,#6,0B,Z,N,2
BIT6D:	MINS	BTST,D6,#14,0B,Z,N,2
BIT6E:	MINS	BTST,D6,#6,0B,Z,N,2

BIT6HL:	MINS	BTST,D4,#6,8Y,Z,N,2


BIT7A:	MINS	BTST,D7,#7,0B,Z,N,2
BIT7H:	MINS	BTST,D4,#15,0B,Z,N,2
BIT7L:	MINS	BTST,D4,#7,0B,Z,N,2
BIT7B:	MINS	BTST,D5,#15,0B,Z,N,2
BIT7C:	MINS	BTST,D5,#7,0B,Z,N,2
BIT7D:	MINS	BTST,D6,#15,0B,Z,N,2
BIT7E:	MINS	BTST,D6,#7,0B,Z,N,2

BIT7HL:	MINS	BTST,D4,#7,8Y,Z,N,2

; -----------------------  RES  ---------------

RES0A:	MINS	BCLR,D7,#0,0B,N,N,2
RES0H:	MINS	BCLR,D4,#8,0B,N,N,2
RES0L:	MINS	BCLR,D4,#0,0B,N,N,2
RES0B:	MINS	BCLR,D5,#8,0B,N,N,2
RES0C:	MINS	BCLR,D5,#0,0B,N,N,2
RES0D:	MINS	BCLR,D6,#8,0B,N,N,2
RES0E:	MINS	BCLR,D6,#0,0B,N,N,2

RES0HL:	MINS	BCLR,D4,#0,8I,N,N,2


RES1A:	MINS	BCLR,D7,#1,0B,N,N,2
RES1H:	MINS	BCLR,D4,#9,0B,N,N,2
RES1L:	MINS	BCLR,D4,#1,0B,N,N,2
RES1B:	MINS	BCLR,D5,#9,0B,N,N,2
RES1C:	MINS	BCLR,D5,#1,0B,N,N,2
RES1D:	MINS	BCLR,D6,#9,0B,N,N,2
RES1E:	MINS	BCLR,D6,#1,0B,N,N,2

RES1HL:	MINS	BCLR,D4,#1,8I,N,N,2


RES2A:	MINS	BCLR,D7,#2,0B,N,N,2
RES2H:	MINS	BCLR,D4,#10,0B,N,N,2
RES2L:	MINS	BCLR,D4,#2,0B,N,N,2
RES2B:	MINS	BCLR,D5,#10,0B,N,N,2
RES2C:	MINS	BCLR,D5,#2,0B,N,N,2
RES2D:	MINS	BCLR,D6,#10,0B,N,N,2
RES2E:	MINS	BCLR,D6,#2,0B,N,N,2

RES2HL:	MINS	BCLR,D4,#2,8I,N,N,2


RES3A:	MINS	BCLR,D7,#3,0B,N,N,2
RES3H:	MINS	BCLR,D4,#11,0B,N,N,2
RES3L:	MINS	BCLR,D4,#3,0B,N,N,2
RES3B:	MINS	BCLR,D5,#11,0B,N,N,2
RES3C:	MINS	BCLR,D5,#3,0B,N,N,2
RES3D:	MINS	BCLR,D6,#11,0B,N,N,2
RES3E:	MINS	BCLR,D6,#3,0B,N,N,2

RES3HL:	MINS	BCLR,D4,#3,8I,N,N,2


RES4A:	MINS	BCLR,D7,#4,0B,N,N,2
RES4H:	MINS	BCLR,D4,#12,0B,N,N,2
RES4L:	MINS	BCLR,D4,#4,0B,N,N,2
RES4B:	MINS	BCLR,D5,#12,0B,N,N,2
RES4C:	MINS	BCLR,D5,#4,0B,N,N,2
RES4D:	MINS	BCLR,D6,#12,0B,N,N,2
RES4E:	MINS	BCLR,D6,#4,0B,N,N,2

RES4HL:	MINS	BCLR,D4,#4,8I,N,N,2


RES5A:	MINS	BCLR,D7,#5,0B,N,N,2
RES5H:	MINS	BCLR,D4,#13,0B,N,N,2
RES5L:	MINS	BCLR,D4,#5,0B,N,N,2
RES5B:	MINS	BCLR,D5,#13,0B,N,N,2
RES5C:	MINS	BCLR,D5,#5,0B,N,N,2
RES5D:	MINS	BCLR,D6,#13,0B,N,N,2
RES5E:	MINS	BCLR,D6,#5,0B,N,N,2

RES5HL:	MINS	BCLR,D4,#5,8I,N,N,2


RES6A:	MINS	BCLR,D7,#6,0B,N,N,2
RES6H:	MINS	BCLR,D4,#14,0B,N,N,2
RES6L:	MINS	BCLR,D4,#6,0B,N,N,2
RES6B:	MINS	BCLR,D5,#14,0B,N,N,2
RES6C:	MINS	BCLR,D5,#6,0B,N,N,2
RES6D:	MINS	BCLR,D6,#14,0B,N,N,2
RES6E:	MINS	BCLR,D6,#6,0B,N,N,2

RES6HL:	MINS	BCLR,D4,#6,8I,N,N,2


RES7A:	MINS	BCLR,D7,#7,0B,N,N,2
RES7H:	MINS	BCLR,D4,#15,0B,N,N,2
RES7L:	MINS	BCLR,D4,#7,0B,N,N,2
RES7B:	MINS	BCLR,D5,#15,0B,N,N,2
RES7C:	MINS	BCLR,D5,#7,0B,N,N,2
RES7D:	MINS	BCLR,D6,#15,0B,N,N,2
RES7E:	MINS	BCLR,D6,#7,0B,N,N,2

RES7HL:	MINS	BCLR,D4,#7,8I,N,N,2

; -----------------------  SET  ---------------

SET0A:	MINS	BSET,D7,#0,0B,N,N,2
SET0H:	MINS	BSET,D4,#8,0B,N,N,2
SET0L:	MINS	BSET,D4,#0,0B,N,N,2
SET0B:	MINS	BSET,D5,#8,0B,N,N,2
SET0C:	MINS	BSET,D5,#0,0B,N,N,2
SET0D:	MINS	BSET,D6,#8,0B,N,N,2
SET0E:	MINS	BSET,D6,#0,0B,N,N,2

SET0HL:	MINS	BSET,D4,#0,8I,N,N,2


SET1A:	MINS	BSET,D7,#1,0B,N,N,2
SET1H:	MINS	BSET,D4,#9,0B,N,N,2
SET1L:	MINS	BSET,D4,#1,0B,N,N,2
SET1B:	MINS	BSET,D5,#9,0B,N,N,2
SET1C:	MINS	BSET,D5,#1,0B,N,N,2
SET1D:	MINS	BSET,D6,#9,0B,N,N,2
SET1E:	MINS	BSET,D6,#1,0B,N,N,2

SET1HL:	MINS	BSET,D4,#1,8I,N,N,2


SET2A:	MINS	BSET,D7,#2,0B,N,N,2
SET2H:	MINS	BSET,D4,#10,0B,N,N,2
SET2L:	MINS	BSET,D4,#2,0B,N,N,2
SET2B:	MINS	BSET,D5,#10,0B,N,N,2
SET2C:	MINS	BSET,D5,#2,0B,N,N,2
SET2D:	MINS	BSET,D6,#10,0B,N,N,2
SET2E:	MINS	BSET,D6,#2,0B,N,N,2

SET2HL:	MINS	BSET,D4,#2,8I,N,N,2


SET3A:	MINS	BSET,D7,#3,0B,N,N,2
SET3H:	MINS	BSET,D4,#11,0B,N,N,2
SET3L:	MINS	BSET,D4,#3,0B,N,N,2
SET3B:	MINS	BSET,D5,#11,0B,N,N,2
SET3C:	MINS	BSET,D5,#3,0B,N,N,2
SET3D:	MINS	BSET,D6,#11,0B,N,N,2
SET3E:	MINS	BSET,D6,#3,0B,N,N,2

SET3HL:	MINS	BSET,D4,#3,8I,N,N,2


SET4A:	MINS	BSET,D7,#4,0B,N,N,2
SET4H:	MINS	BSET,D4,#12,0B,N,N,2
SET4L:	MINS	BSET,D4,#4,0B,N,N,2
SET4B:	MINS	BSET,D5,#12,0B,N,N,2
SET4C:	MINS	BSET,D5,#4,0B,N,N,2
SET4D:	MINS	BSET,D6,#12,0B,N,N,2
SET4E:	MINS	BSET,D6,#4,0B,N,N,2

SET4HL:	MINS	BSET,D4,#4,8I,N,N,2


SET5A:	MINS	BSET,D7,#5,0B,N,N,2
SET5H:	MINS	BSET,D4,#13,0B,N,N,2
SET5L:	MINS	BSET,D4,#5,0B,N,N,2
SET5B:	MINS	BSET,D5,#13,0B,N,N,2
SET5C:	MINS	BSET,D5,#5,0B,N,N,2
SET5D:	MINS	BSET,D6,#13,0B,N,N,2
SET5E:	MINS	BSET,D6,#5,0B,N,N,2

SET5HL:	MINS	BSET,D4,#5,8I,N,N,2


SET6A:	MINS	BSET,D7,#6,0B,N,N,2
SET6H:	MINS	BSET,D4,#14,0B,N,N,2
SET6L:	MINS	BSET,D4,#6,0B,N,N,2
SET6B:	MINS	BSET,D5,#14,0B,N,N,2
SET6C:	MINS	BSET,D5,#6,0B,N,N,2
SET6D:	MINS	BSET,D6,#14,0B,N,N,2
SET6E:	MINS	BSET,D6,#6,0B,N,N,2

SET6HL:	MINS	BSET,D4,#6,8I,N,N,2


SET7A:	MINS	BSET,D7,#7,0B,N,N,2
SET7H:	MINS	BSET,D4,#15,0B,N,N,2
SET7L:	MINS	BSET,D4,#7,0B,N,N,2
SET7B:	MINS	BSET,D5,#15,0B,N,N,2
SET7C:	MINS	BSET,D5,#7,0B,N,N,2
SET7D:	MINS	BSET,D6,#15,0B,N,N,2
SET7E:	MINS	BSET,D6,#7,0B,N,N,2

SET7HL:	MINS	BSET,D4,#7,8I,N,N,2


; ---------------------  LD  ---------------------

	IDEN
LDBB:	Otra	1
LDBC:	MLDRR	D5,D5,2,1
LDBD:	MLDRR	D5,D6,1,1
LDBE:	MLDRR	D5,D6,4,1
LDBH:	MLDRR	D5,D4,1,1
LDBL:	MLDRR	D5,D4,4,1
LDBHL:	MLDRR	D5,D4,0B,1
LDBA:	MLDRR	D5,D7,4,1
; ---------------------	; $48 ; ---------------- ;
LDCB:	MLDRR	D5,D5,3,1
LDCC:	Otra	1
LDCD:	MLDRR	D5,D6,5,1
LDCE:	MLDRR	D5,D6,0,1
LDCH:	MLDRR	D5,D4,5,1
LDCL:	MLDRR	D5,D4,0,1
LDCHL:	MLDRR	D5,D4,0A,1
LDCA:	MLDRR	D5,D7,0,1
; ---------------------	; $50 ; ---------------- ;
LDDB:	MLDRR	D6,D5,1,1
LDDC:	MLDRR	D6,D5,4,1
LDDD:	Otra	1
LDDE:	MLDRR	D6,D6,2,1
LDDH:	MLDRR	D6,D4,1,1
LDDL:	MLDRR	D6,D4,4,1
LDDHL:	MLDRR	D6,D4,0B,1
LDDA:	MLDRR	D6,D7,4,1
; ---------------------	; $58 ; ---------------- ;
LDEB:	MLDRR	D6,D5,5,1
LDEC:	MLDRR	D6,D5,0,1
LDED:	MLDRR	D6,D6,3,1
LDEE:	Otra	1
LDEH:	MLDRR	D6,D4,5,1
LDEL:	MLDRR	D6,D4,0,1
LDEHL:	MLDRR	D6,D4,0A,1
LDEA:	MLDRR	D6,D7,0,1
; ---------------------	; $60 ; ---------------- ;
LDHB:	MLDRR	D4,D5,1,1
LDHC:	MLDRR	D4,D5,4,1
LDHD:	MLDRR	D4,D6,1,1
LDHE:	MLDRR	D4,D6,4,1
LDHH:	Otra	1
LDHL:	MLDRR	D4,D4,2,1
LDHHL:	MLDRR	D4,D4,0B,1
LDHA:	MLDRR	D4,D7,4,1
; ---------------------	; $68 ; ---------------- ;
LDLB:	MLDRR	D4,D5,5,1
LDLC:	MLDRR	D4,D5,0,1
LDLD:	MLDRR	D4,D6,5,1
LDLE:	MLDRR	D4,D6,0,1
LDLH:	MLDRR	D4,D4,3,1
LDLL:	Otra	1
LDLHL:	MLDRR	D4,D4,0A,1
LDLA:	MLDRR	D4,D7,0,1
; ---------------------	; $70 ; ---------------- ;

LDHLB:	MLDRR	D4,D5,11,1
LDHLC:	MLDRR	D4,D5,10,1
LDHLD:	MLDRR	D4,D6,11,1
LDHLE:	MLDRR	D4,D6,10,1
LDHLH:	MLDRR	D4,D4,11,1
LDHLL:	MLDRR	D4,D4,10,1


STOP:
HALT:	NOP			; <=- No Quitar.
HALTBUC:TST.B	ModoTraza(A3)
	BEQ.S	HALTBUC
	Otra


LDHLA:	MLDRR	D4,D7,10,1

LDHLMN:	CogePagE D4,A4
	MOVE.B	(A5)+,(A4)
	BEQ.S	LDHLMN0
	SaltaPagE D1
	Otra2
LDHLMN0:CheckB	(A4)
	SaltaPagE D1
	Otra

LDBCA:	MLDRR	D5,D7,10,1
LDDEA:	MLDRR	D6,D7,10,1

; ---------------------	; $78 ; ---------------- ;
LDSPHL:	MOVE.L	D4,D0
	CogePagE D0,A6
	Otra
; ---------------------	; $78 ; ---------------- ;
LDAB:	MLDRR	D7,D5,7,1
LDAC:	MLDRR	D7,D5,0,1
LDAD:	MLDRR	D7,D6,7,1
LDAE:	MLDRR	D7,D6,0,1
LDAH:	MLDRR	D7,D4,7,1
LDAL:	MLDRR	D7,D4,0,1
LDAHL:	MLDRR	D7,D4,0A,1
LDABC:	MLDRR	D7,D5,0A,1
LDADE:	MLDRR	D7,D6,0A,1
LDAA:	Otra	1

LDAHLI:	MLDRR	D7,D4,0AI,1
LDHLIA:	MLDRR	D4,D7,10I,1
LDAHLD:	MLDRR	D7,D4,0AD,1
LDHLDA:	MLDRR	D4,D7,10D,1

LDAM:	MOVE.W	(A5)+,D1
	TST.B	D1
	BEQ.S	LDAMM
	ROR.W	#8,D1
	SaltaReg D1,A4
;*	CogePag	D1,A4
	MOVE.B	(A4),D7
	Otra2
LDAMM:	CheckW	D1
	ROR.W	#8,D1
	SaltaReg D1,A4
;*	CogePag	D1,A4
	MOVE.B	(A4),D7
	Otra

; ---------------------	; $78 ; ---------------- ;

;	NULO
;LDSPM:	MLDRR	A6,M,8S,4



LDMA:	MOVE.W	(A5)+,D1
	TST.B	D1
	BEQ.S	LDMAM
	ROR.W	#8,D1
	CogePagE D1,A4
	MOVE.B	D7,(A4)
	SaltaPagE D1
	Otra2
LDMAM:	CheckW	D1
	ROR.W	#8,D1
	CogePagE D1,A4
	MOVE.B	D7,(A4)
	SaltaPagE D1
	Otra



;LDMHL:	MLDRR	D4,M,9,3
;	NULO
;LDMBC:	MLDRR	D5,M,9,4
;	NULO
;LDMDE:	MLDRR	D6,M,9,4

LDAN:	MLDRR	D7,N,15,2
LDHN:	MLDRR	D4,N,14,2
LDLN:	MLDRR	D4,N,15,2
LDBN:	MLDRR	D5,N,14,2
LDCN:	MLDRR	D5,N,15,2
LDDN:	MLDRR	D6,N,14,2
LDEN:	MLDRR	D6,N,15,2

LDHLN:	MLDRR	D4,N,16,3
LDBCN:	MLDRR	D5,N,16,3
LDDEN:	MLDRR	D6,N,16,3
LDSPN:	MLDRR	A6,N,17S,3


; --------------  ROTACIONES  ----------------


; ---------------------	; $00 ; ---------------- ;
	NULO
RLCB:
	CMP.L	Desbor+4(A2),A5
	BLE.S	RLCB2
	MOVE.B	D1,D2
	SUBQ.W	#1,A5
	MOVE.W	A5,D1
	SUB.W	(A2),D1
	CogePag	D1,A5
	LEA	Restas(A3,D1.W*8),A2
	MOVE.B	(A5)+,D2
	JMP	([InsCB-$400.W,PC,D2.W*4])	; Salta a puntero de emulación.
	NULO
RLCB2:	MROT	ROL.B,D5,N,1,2
RLCC:	MROT	ROL.B,D5,N,0,2
RLCD:	MROT	ROL.B,D6,N,1,2
RLCE:	MROT	ROL.B,D6,N,0,2
RLCH:	MROT	ROL.B,D4,N,1,2
RLCL:	MROT	ROL.B,D4,N,0,2
RLCHL:	MROT	ROL.B,D4,N,2,2
RLCA:	MROT	ROL.B,D7,N,0,2
; ---------------------	; $08 ; ---------------- ;
RRCB:	MROT	ROR.B,D5,N,1,2
RRCC:	MROT	ROR.B,D5,N,0,2
RRCD:	MROT	ROR.B,D6,N,1,2
RRCE:	MROT	ROR.B,D6,N,0,2
RRCH:	MROT	ROR.B,D4,N,1,2
RRCL:	MROT	ROR.B,D4,N,0,2
RRCHL:	MROT	ROR.B,D4,N,2,2
RRCA:	MROT	ROR.B,D7,N,0,2
; ---------------------	; $10 ; ---------------- ;
RLB:	MROT	ROXL.B,D5,X,1,2
RLC:	MROT	ROXL.B,D5,X,0,2
RLD:	MROT	ROXL.B,D6,X,1,2
RLE:	MROT	ROXL.B,D6,X,0,2
RLH:	MROT	ROXL.B,D4,X,1,2
RLL:	MROT	ROXL.B,D4,X,0,2
RLHL:	MROT	ROXL.B,D4,X,2,2
RLA:	MROT	ROXL.B,D7,X,0,2
; ---------------------	; $18 ; ---------------- ;
RRB:	MROT	ROXR.B,D5,X,1,2
RRC:	MROT	ROXR.B,D5,X,0,2
RRD:	MROT	ROXR.B,D6,X,1,2
RRE:	MROT	ROXR.B,D6,X,0,2
RRH:	MROT	ROXR.B,D4,X,1,2
RRL:	MROT	ROXR.B,D4,X,0,2
RRHL:	MROT	ROXR.B,D4,X,2,2
RRA:	MROT	ROXR.B,D7,X,0,2
; ---------------------	; $20 ; ---------------- ;
SLAB:	MROT	ASL.B,D5,N,1,2
SLAC:	MROT	ASL.B,D5,N,0,2
SLAD:	MROT	ASL.B,D6,N,1,2
SLAE:	MROT	ASL.B,D6,N,0,2
SLAH:	MROT	ASL.B,D4,N,1,2
SLAL:	MROT	ASL.B,D4,N,0,2
SLAHL:	MROT	ASL.B,D4,N,2,2
SLAA:	MROT	ASL.B,D7,N,0,2
; ---------------------	; $28 ; ---------------- ;
SRAB:	MROT	ASR.B,D5,N,1,2
SRAC:	MROT	ASR.B,D5,N,0,2
SRAD:	MROT	ASR.B,D6,N,1,2
SRAE:	MROT	ASR.B,D6,N,0,2
SRAH:	MROT	ASR.B,D4,N,1,2
SRAL:	MROT	ASR.B,D4,N,0,2
SRAHL:	MROT	ASR.B,D4,N,2,2
SRAA:	MROT	ASR.B,D7,N,0,2
; ---------------------	; $38 ; ---------------- ;
SRLB:	MROT	LSR.B,D5,N,1,2
SRLC:	MROT	LSR.B,D5,N,0,2
SRLD:	MROT	LSR.B,D6,N,1,2
SRLE:	MROT	LSR.B,D6,N,0,2
SRLH:	MROT	LSR.B,D4,N,1,2
SRLL:	MROT	LSR.B,D4,N,0,2
SRLHL:	MROT	LSR.B,D4,N,2,2
SRLA:	MROT	LSR.B,D7,N,0,2
; ---------------------	; $38 ; ---------------- ;
SWPB:	ROR.W	#8,D5
	ROR.B	#4,D5
	ROR.W	#8,D5
	Otra2

SWPC:	ROR.B	#4,D5
	Otra2

SWPD:	ROR.W	#8,D6
	ROR.B	#4,D6
	ROR.W	#8,D6
	Otra2

SWPE:	ROR.B	#4,D6
	Otra2

SWPH:	ROR.W	#8,D4
	ROR.B	#4,D4
	ROR.W	#8,D4
	Otra2

SWPL:	ROR.B	#4,D4
	Otra2

SWPHL:	CogePagE D4,A4
	MOVE.B	(A4),D1
	ROR.B	#4,D1
	MOVE.B	D1,(A4)
	Otra2

SWPA:	ROR.B	#4,D7
	Otra2
; -----------------------  FIN  ---------------

	IDEN
NOP:
	CMP2.L	Desbor(A2),A5
	BCS.S	DESNOP
	Otra2
DESNOP:
	SUBQ.W	#1,A5
	MOVE.W	A5,D1
	SUB.W	(A2),D1
	CogePag	D1,A5
	LEA	Restas(A3,D1.W*8),A2
	Otra
NOP060:
	CMP.L	Desbor+4(A2),A5
	BGT.S	DESNOP
	CMP.L	Desbor(A2),A5
	BLT.S	DESNOP
	Otra2

DAA:
	MOVE.B	(A3),D2
	BEQ	MIRAC
	SF	(A3)
CONTD:
	SUB.B	D2,D7
	BCS.S	RESTA
	MOVE.W	D3,CCR
	BCS.S	RESTAB
SUMA:
	MOVE.W	#04,CCR
	ABCD.B	D2,D7
	OtraT	1
	NULO
RESTA:
	MOVE.W	D3,CCR
	BCS.S	SUMA
RESTAB:
	NEG.B	D7
	MOVE.B	D2,D1
	MOVE.B	D7,D2
	MOVE.B	D1,D7
	MOVE.W	#04,CCR
	SBCD.B	D2,D7
	OtraT	1
	NULO
MIRAC:
	MOVE.W	D3,CCR
	BCC	CONTD
	MOVE.B	D7,D2
	NEG.B	D2
	SF	D7
	MOVE.W	#04,CCR
	SBCD.B	D2,D7
	OtraT	1

SCF:	BSET	#0,D3
	Otra	1
CCF:	BCHG	#0,D3
	Otra	1

ICPL:	NOT.B	D7
	Otra	1

	NULO
NEG:	NEG.B	D7
	BEQ.S	ERA0
	MOVE.W	CCR,D3
	AND.B	#$7E,D3
	OR.B	#$02,D3
	Otra2
ERA0:	MOVE.W	CCR,D3
	AND.B	#$7D,D3
	OR.B	#$01,D3
	Otra

IRLA:	LSR.B	#1,D3
	ROXL.B	#1,D7
	ROXL.B	#1,D3
	Otra
IRRA:	LSR.B	#1,D3
	ROXR.B	#1,D7
	ROXL.B	#1,D3
	Otra
IRLCA:	ROL.B	#1,D7
	OtraC2
IRRCA:	ROR.B	#1,D7
	OtraC2


DI:	SF	IFF(A3)
	Otra	1

EI:
	ST	IFF(A3)

	MOVE.B	RasterInt(A3),D1
	CMP.B	$DFF006,D1
	BCS.S	EICon

	TST.B	PetIntGB(A3)
	BMI.S	PetInterGB0
	BNE.S	PetInterGB1
EICon:
	OtraEI

PetInterGB0:
	SF	PetIntGB(A3)
	MOVE.W	#$8020,$DFF09C
	OtraEI

PetInterGB1:
	SF	PetIntGB(A3)
	MOVE.W	#$0003,$DFF09C
	MOVE.W	#$8011,$DFF09C
	OtraEI


	IDEN
JR:	MJR
JRNZ:	MJRC	NE
JRZ:	MJRC	EQ
JRNC:	MJRC	CC
JRC:	MJRC	CS

JP:	MJP
JPNZ:	MJPC	NE
JPZ:	MJPC	EQ
JPNC:	MJPC	CC
JPC:	MJPC	CS

JPHL:	MOVE.W	D4,D1
	CogePag	D1,A5
	LEA	Restas(A3,D1.W*8),A2
	Otra

CALL:	MCALL
CALLNZ:	MCALLC	NE
CALLZ:	MCALLC	EQ
CALLNC:	MCALLC	CC
CALLC:	MCALLC	CS

IRET:	MRET
RETNZ:	MRETC	NE,1
RETZ:	MRETC	EQ,1
RETNC:	MRETC	CC,1
RETC:	MRETC	CS,1


	NULO
PetInterGB0b:
	SF	PetIntGB(A3)
	MOVE.W	#$8020,$DFF09C
	MRET

RETI:
	ST	IFF(A3)

	MOVE.B	RasterInt(A3),D1
	CMP.B	$DFF006,D1
	BCS.S	RetiCon

	TST.B	PetIntGB(A3)
	BMI.S	PetInterGB0b
	BNE.S	PetInterGB1b
RetiCon:
	MRET

	NULO
PetInterGB1b:
	SF	PetIntGB(A3)
	MOVE.W	#$0003,$DFF09C
	MOVE.W	#$8011,$DFF09C
	MRET


	IDEN
RST0:	MRST	0
RST8:	MRST	$8
RST10:	MRST	$10
RST18:	MRST	$18
RST20:	MRST	$20
RST28:	MRST	$28
RST30:	MRST	$30
RST38:	MRST	$38


PUSHAF:	MPUSH	AF,1
PUSHHL:	MPUSH	D4,1
PUSHBC:	MPUSH	D5,1
PUSHDE:	MPUSH	D6,1


POPAF:	MPOP	AF,1,1
POPHL:	MPOP	D4,0,1
POPBC:	MPOP	D5,0,1
POPDE:	MPOP	D6,0,1

EXSPHL:	MOVE.W	(A6),D1
	ROR.W	#8,D1
	EXG.L	D4,D1
	ROR.W	#8,D1
	MOVE.W	D1,(A6)
	Otra	1


LDAFF:	MOVE.W	#$FF00,D1
	MOVE.B	(A5)+,D1
	BEQ.S	LDAFFM

;**	SaltaReg D1,A4

	MOVE.B	D1,D2
	CogePag	D1,A4
	JSR	([RegsIN-$400.W,PC,D2.W*4])	; Salta a puntero de emulación.

;*	CogePag	D1,A4

	MOVE.B	(A4),D7
	Otra2
LDAFFM:	CheckB	D1
	OR.W	#$FF00,D1

;**	SaltaReg D1,A4

	MOVE.B	D1,D2
	CogePag	D1,A4
	JSR	([RegsIN-$400.W,PC,D2.W*4])	; Salta a puntero de emulación.

;*	CogePag	D1,A4
	MOVE.B	(A4),D7
	Otra


LDFFA:	MOVE.W	#$FF00,D1
	MOVE.B	(A5)+,D1
	BEQ.S	LDFFAM
	CogePagE D1,A4
	MOVE.B	D7,(A4)
	SaltaPagE D1
	Otra2
LDFFAM:	CheckW	D1
	OR.W	#$FF00,D1
	CogePagE D1,A4
	MOVE.B	D7,(A4)
	SaltaPagE D1
	Otra


LDACM:	MOVE.W	#$FF00,D1
	MOVE.B	D5,D1

;**	SaltaReg D1,A4

	MOVE.B	D1,D2
	CogePag	D1,A4
	JSR	([RegsIN-$400.W,PC,D2.W*4])	; Salta a puntero de emulación.

;*	CogePag	D1,A4
	MOVE.B	(A4),D7
	Otra


LDCMA:	MOVE.W	#$FF00,D1
	MOVE.B	D5,D1
	CogePagE D1,A4
	MOVE.B	D7,(A4)
	SaltaPagE D1
	Otra


ADDSPN:
	MOVE.B	(A5)+,D1
	BEQ.S	ADDSPNM
	EXT.W	D1
	ADD.W	D1,D0
	MOVE.W	D0,D1
	CogePagE D1,A6
	Otra2
ADDSPNM:CheckB	D1
	EXT.W	D1
	ADD.W	D1,D0
	MOVE.W	D0,D1
	CogePagE D1,A6
	Otra


LDMSP:	MLDRR	D0,M,9,4


LDHLSPN:
	MOVE.W	D0,D4
	MOVE.B	(A5)+,D1
	BEQ.S	LDHLSPNM
	EXT.W	D1
	ADD.W	D1,D4
	Otra2
LDHLSPNM:CheckB	D1
	EXT.W	D1
	ADD.W	D1,D4
	Otra


; --------------------------------------------------------------



;	-------------------
;	Registros Hardware.
;	-------------------


	NULO
; ------------------------------ ;
NADIN:
	RTS
; -=-=-
NAOUT:
	Otra2
; ------------------------------ ;

INS44:
	BFEXTU	$DFF004{15:9},D1
	SUB.W	#$48,D1
	CMP.W	#$9A,D1
	BCS.S	INS44Con
	MOVEQ	#0,D1
INS44Con:
	MOVE.B	D1,(A4)
	RTS
; -=-=-

; ------------------------------ ;
INS00:
	MOVE.B	BarraJoy,D1
	LSR.B	#4,D1
	AND.W	#$0003,D1
	MOVE.B	EstadoJoy(A3,D1.W),(A4)
	RTS
BarraJoy:	dc.l	0
; -=-=-
OUT00:
	MOVE.B	D2,BarraJoy
	Otra2
; ------------------------------ ;

; ------------------------------ ;
INS41:
	BFEXTU	$DFF004{15:9},D1
	SUB.W	#$48,D1
	CMP.W	#$9A,D1
	BCS.S	INS41Con
	MOVEQ	#0,D1
INS41Con:
	AND.B	#$F8,(A4)
	CMP.B	$45(A0),D1
	BNE.S	INS41Con1
	OR.B	#$04,(A4)
INS41Con1:
	MOVE.B	$DFF007,D2
	MOVE.B	(TabIn41-$100.w,PC,D2.W),D2
	OR.B	D2,(A4)
INS41Con0:
	CMP.W	#144,D1
	BCS.S	INS41Fin
	AND.B	#$FD,(A4)
	OR.B	#$01,(A4)
INS41Fin:
	RTS

	CNOP	0,8
TabIn41:
	DCB.B	$30,$2
	DCB.B	$50,$3
	DCB.B	$80,$0
	CNOP	0,8

; -=-=-
OUT41:
	Otra2
; ------------------------------ ;

	CNOP	0,8
OUT46:
	MOVE.B	D2,D1
	LSL.W	#8,D1
	CogePag	D1,A4
	LEA	-$100(A0),A0
	MOVE.W	#(40/4)-1,D1
OUT46Buc:
	MOVE.L	(A4)+,(A0)+
	MOVE.L	(A4)+,(A0)+
	MOVE.L	(A4)+,(A0)+
	MOVE.L	(A4)+,(A0)+
	DBF	D1,OUT46Buc
	LEA	$100-$A0(A0),A0
	Otra2
; ------------------------------ ;

OUT45:
	MOVEQ	#0,D1
	MOVE.B	D2,D1
	CMP.B	#145,D1
	BCS.S	OUT45Con
	MOVE.W	#145,D1		; (Como un OFF)
OUT45Con:
	MULU	#(CoppLineSize),D1
	MOVE.W	#$8000,([IntGB1Ant.W,A3])
	CLR.W	(-4.W,[IntGB1Ant.W,A3])
	LEA	(CopperLine+$12.L,D1.W),A4
	MOVE.W	#$0003,-4(A4)
	MOVE.W	#$8011,(A4)
	MOVE.L	A4,IntGB1Ant(A3)
	Otra2

; ------------------------------ ;

OUT40:
	NoInt

	MOVE.B	D40(A3),D1
	MOVE.B	D2,D40(A3)
	EOR.B	D1,D2
; -----------------------------------------------
	MOVEQ	#0,D1
	MOVE.B	$DFF006,D1
	SUB.B	#$48,D1
	BCC.S	Ou40Con1
	MOVEQ	#0,D1
Ou40Con1:
	CMP.B	#$90,D1			; ActVDP Line.
	BCS.S	Ou40Con0
	MOVE.W	#$90,D1
Ou40Con0:
; -----------------------------------------------
	BTST	#0,D2		; BG On/Off
	BEQ.S	Ou40NoBGX
Ou40SiBGX:
	OR.B	#$02,(TabRasCMDS.L,D1.W)
	LEA	(TabRasDATA.W,PC,D1.W*8),A4
	MOVE.B	$43(A0),2(A4)	; BG X
	MOVE.B	$40(A0),1(A4)	; Control
	MOVE.B	$4B(A0),3(A4)	; Win X
Ou40NoBGX:
; -----------------------------------------------
	BTST	#5,D2		; Win On/Off
	BEQ.S	Ou40NoWinX
Ou40SiWinX:
	OR.B	#$08+$02,(TabRasCMDS.L,D1.W)
	LEA	(TabRasDATA.W,PC,D1.W*8),A4
	MOVE.B	$4B(A0),3(A4)	; Win X
	MOVE.B	$40(A0),1(A4)	; Control
	MOVE.B	$43(A0),2(A4)	; BG X
Ou40NoWinX:
; -----------------------------------------------
	BTST	#6,D2		; Win Pantalla
	BNE.S	Ou40SiWinY
	BTST	#4,D2		; BG Gfx
	BEQ.S	Ou40NoWinY
Ou40SiWinY:
	OR.B	#$04,(TabRasCMDS.L,D1.W)
	LEA	(TabRasDATA.W,PC,D1.W*8),A4
	MOVE.B	$4A(A0),4(A4)	; Win Y
	MOVE.B	$40(A0),1(A4)	; Control
Ou40NoWinY:
; -----------------------------------------------
	BTST	#3,D2		; BG Pantalla
	BNE.S	Ou40SiBGY
	BTST	#4,D2		; BG Gfx
	BEQ.S	Ou40NoBGY
Ou40SiBGY:
;	MOVE.W	D2,-(SP)

	CMP.B	UltCoorY(A3),D1
	BCS.S	Ou402Con3
	MOVE.B	UltCoorY(A3),D2
	OR.B	#$01,(TabRasCMDS-$100.L,D2.W)
Ou402Con3:

	MOVE.B	D1,UltCopLin(A3)

	OR.B	#$01,(TabRasCMDS.L,D1.W)
	LEA	(TabRasDATA.W,PC,D1.W*8),A4
	MOVE.B	$42(A0),(A4)
	MOVE.B	$40(A0),1(A4)	; Control


	SF	D2
	SUB.B	$42(A0),D2

	CMP.B	#$90,D2
	BCS.S	Ou402Con4
	MOVE.B	#$91,D2
Ou402Con4:

	CMP.B	D1,D2
	BCC.S	Ou402Con5
	MOVE.B	#$91,D2
Ou402Con5:

	MOVE.B	D2,UltCoorY(A3)

	MOVE.W	(A4),(TabRasDATA-$800.L,D2.W*8)

;	MOVE.W	(SP)+,D2
Ou40NoBGY:
; -----------------------------------------------

	SiInt
	Otra2

; ------------------------------ ;

OUT42:
	NoInt

	MOVEQ	#0,D1
	MOVE.B	$DFF006,D1
	SUB.B	#$48,D1
	BCC.S	Ou42Con1
	MOVEQ	#0,D1
Ou42Con1:

	CMP.B	#$90,D1			; ActVDP Line.
	BCS.S	Ou42Con0
	MOVE.W	#$90,D1
Ou42Con0:

	CMP.B	UltCoorY(A3),D1
	BCS.S	Ou42Con3
	MOVE.B	UltCoorY(A3),D2
	OR.B	#$01,(TabRasCMDS-$100.L,D2.W)
Ou42Con3:

	MOVE.B	D1,UltCopLin(A3)

	OR.B	#$01,(TabRasCMDS.L,D1.W)
	LEA	(TabRasDATA.W,PC,D1.W*8),A4
	MOVE.B	$42(A0),(A4)
	MOVE.B	$40(A0),1(A4)


	SF	D2
	SUB.B	$42(A0),D2

	CMP.B	#$90,D2
	BCS.S	Ou42Con4
	MOVE.B	#$91,D2
Ou42Con4:

	CMP.B	D1,D2
	BCC.S	Ou42Con5
	MOVE.B	#$91,D2
Ou42Con5:

	MOVE.B	D2,UltCoorY(A3)

	MOVE.W	(A4),(TabRasDATA-$800.L,D2.W*8)

	SiInt
	Otra2


		CNOP	0,8
TabRasDATA:	DS.L	148*2
		DC.W	0,0	<=- No Quitar.
TabRasREST:	DS.L	148
TabRasCMDS:	DS.B	148
	CNOP	0,8

; ------------------------------ ;

OUT43:
	NoInt

	MOVEQ	#0,D1
	MOVE.B	$DFF006,D1
	SUB.B	#$48,D1
	BCC.S	Ou43Con1
	MOVEQ	#0,D1
Ou43Con1:

	CMP.B	#$90,D1			; ActVDP Line.
	BCS.S	Ou43Con0
	MOVE.W	#$90,D1
Ou43Con0:

	OR.B	#$02,(TabRasCMDS.L,D1.W)
	LEA	(TabRasDATA.W,PC,D1.W*8),A4
	MOVE.B	$43(A0),2(A4)	; BG X
	MOVE.B	$40(A0),1(A4)	; Control
	MOVE.B	$4B(A0),3(A4)	; Win X

	SiInt
	Otra2

; ------------------------------ ;

OUT4A:
	NoInt

	MOVEQ	#0,D1
	MOVE.B	$DFF006,D1
	SUB.B	#$48,D1
	BCC.S	Ou4ACon1
	MOVEQ	#0,D1
Ou4ACon1:

	CMP.B	#$90,D1			; ActVDP Line.
	BCS.S	Ou4ACon0
	MOVE.W	#$90,D1
Ou4ACon0:

	OR.B	#$04,(TabRasCMDS.L,D1.W)
	LEA	(TabRasDATA.W,PC,D1.W*8),A4
	MOVE.B	$4A(A0),4(A4)
	MOVE.B	$40(A0),1(A4)

	SiInt
	Otra2

; ------------------------------ ;

OUT4B:
	NoInt

	MOVEQ	#0,D1
	MOVE.B	$DFF006,D1
	SUB.B	#$48,D1
	BCC.S	Ou4BCon1
	MOVEQ	#0,D1
Ou4BCon1:

	CMP.B	#$90,D1			; ActVDP Line.
	BCS.S	Ou4BCon0
	MOVE.W	#$90,D1
Ou4BCon0:

	OR.B	#$08+$02,(TabRasCMDS.L,D1.W)
	LEA	(TabRasDATA.W,PC,D1.W*8),A4
	MOVE.B	$4B(A0),3(A4)	; Win X
	MOVE.B	$40(A0),1(A4)	; Control
	MOVE.B	$43(A0),2(A4)	; BG X

	SiInt
	Otra2

; ------------------------------ ;

OUT47:
	NoInt

	MOVEQ	#0,D1
	MOVE.B	$DFF006,D1
	SUB.B	#$48,D1
	BCC.S	Ou47Con1
	MOVEQ	#0,D1
Ou47Con1:

	CMP.B	#$90,D1			; ActVDP Line.
	BCS.S	Ou47Con0
	MOVE.W	#$90,D1
Ou47Con0:

	OR.B	#$10,(TabRasCMDS.L,D1.W)
	LEA	(TabRasDATA.W,PC,D1.W*8),A4
	MOVE.B	$47(A0),5(A4)

	SiInt
	Otra2

; ------------------------------ ;


; ------------------------------ ;


; -=-=-
	CNOP	0,8
INS04:
	MOVE.B	$DFF007,(A4)
	RTS
; -=-=-




; Puertos E/S para sonido
; -----------------------

	CNOP	0,8
OUT12:
	MOVE.B	D2,D1
	AND.B	#$07,D1
	MOVE.B	D1,SounEnv1

	LSR.B	#4,D2
	MOVE.B	D2,D1
	LSL.B	#1,D2
	ADD.B	D1,D2
	MOVE.B	D2,SounVol1+1
	Otra2

OUT13:
	MOVE.W	$13(A0),D1		; Frequencia Canal 1.
	NOT.W	D1
	ROR.W	#8,D1
	AND.W	#$07FF,D1
	LSL.W	#1,D1
	BNE.S	OU13Con
	MOVEQ	#1,D1
OU13Con:MOVE.W	D1,$DFF0A6		; Freq
	Otra2


	CNOP	0,8
OUT17:
	MOVE.B	D2,D1
	AND.B	#$07,D1
	MOVE.B	D1,SounEnv2

	LSR.B	#4,D2
	MOVE.B	D2,D1
	LSL.B	#1,D2
	ADD.B	D1,D2
	MOVE.B	D2,SounVol2+1
	Otra2

OUT18:
	MOVE.W	$18(A0),D1		; Frequencia Canal 2.
	NOT.W	D1
	ROR.W	#8,D1
	AND.W	#$07FF,D1
	LSL.W	#1,D1
	BNE.S	OU18Con
	MOVEQ	#1,D1
OU18Con:MOVE.W	D1,$DFF0B6		; Freq
	Otra2


OUT1D:
	MOVE.W	$1D(A0),D1		; Frequencia Canal 3.
	NOT.W	D1
	ROR.W	#8,D1
	AND.W	#$07FF,D1
	LSL.W	#1,D1
	BNE.S	OU1DCon
	MOVEQ	#1,D1
OU1DCon:MOVE.W	D1,$DFF0C6		; Freq
	MOVE.W	D1,$DFF0D6		; Freq
	Otra2


	CNOP	0,8
OUT21:
	MOVE.B	D2,D1
	AND.B	#$07,D1
	MOVE.B	D1,SounEnv4

	LSR.B	#4,D2
	MOVE.B	D2,D1
	LSL.B	#1,D2
	ADD.B	D1,D2
	MOVE.B	D2,SounVol4+1
	Otra2

OUT22:
	Otra2
;	MOVE.W	$21(A0),D1		; Frequencia Canal 4.
;	NOT.W	D1
;	ROR.W	#8,D1
;	AND.W	#$07FF,D1
;	LSL.W	#1,D1
;	BNE.S	OU22Con
;	MOVEQ	#1,D1
;OU22Con:MOVE.W	D1,$DFF0A6		; Freq

	MOVE.W	#$345,$DFF0A6		; Freq

	Otra2



	CNOP	0,8
SounVol1:	DC.W	0
SounVol2:	DC.W	0
SounVol3:	DC.W	0
SounVol4:	DC.W	0

SounEnv1:	DC.B	0
SounEnv2:	DC.B	0
SounEnv3:	DC.B	0
SounEnv4:	DC.B	0
; ------------------------------ ;





; <=--------------------------------------------------------------------=>

	CNOP	0,8
	DS.L	16

; <=--------------------------------------------------------------------=>

	IDEN
RInsCB:	MOVE.B	(A5)+,D2
	JMP	([InsCB-$400.W,PC,D2.W*4])	; Salta a puntero de emulación.
	Otra2
; -=-
	CNOP	0,8
InsCB:
	DC.L	RLCB,RLCC,RLCD,RLCE,RLCH,RLCL,RLCHL,RLCA	; 00
	DC.L	RRCB,RRCC,RRCD,RRCE,RRCH,RRCL,RRCHL,RRCA	; 08
	DC.L	RLB,RLC,RLD,RLE,RLH,RLL,RLHL,RLA		; 10
	DC.L	RRB,RRC,RRD,RRE,RRH,RRL,RRHL,RRA		; 18
	DC.L	SLAB,SLAC,SLAD,SLAE,SLAH,SLAL,SLAHL,SLAA	; 20
	DC.L	SRAB,SRAC,SRAD,SRAE,SRAH,SRAL,SRAHL,SRAA	; 28
	DC.L	SWPB,SWPC,SWPD,SWPE,SWPH,SWPL,SWPHL,SWPA	; 30
	DC.L	SRLB,SRLC,SRLD,SRLE,SRLH,SRLL,SRLHL,SRLA	; 38
	DC.L	BIT0B,BIT0C,BIT0D,BIT0E,BIT0H,BIT0L,BIT0HL,BIT0A; 40
	DC.L	BIT1B,BIT1C,BIT1D,BIT1E,BIT1H,BIT1L,BIT1HL,BIT1A; 48
	DC.L	BIT2B,BIT2C,BIT2D,BIT2E,BIT2H,BIT2L,BIT2HL,BIT2A; 50
	DC.L	BIT3B,BIT3C,BIT3D,BIT3E,BIT3H,BIT3L,BIT3HL,BIT3A; 58
	DC.L	BIT4B,BIT4C,BIT4D,BIT4E,BIT4H,BIT4L,BIT4HL,BIT4A; 60
	DC.L	BIT5B,BIT5C,BIT5D,BIT5E,BIT5H,BIT5L,BIT5HL,BIT5A; 68
	DC.L	BIT6B,BIT6C,BIT6D,BIT6E,BIT6H,BIT6L,BIT6HL,BIT6A; 70
	DC.L	BIT7B,BIT7C,BIT7D,BIT7E,BIT7H,BIT7L,BIT7HL,BIT7A; 78
	DC.L	RES0B,RES0C,RES0D,RES0E,RES0H,RES0L,RES0HL,RES0A; 80
	DC.L	RES1B,RES1C,RES1D,RES1E,RES1H,RES1L,RES1HL,RES1A; 88
	DC.L	RES2B,RES2C,RES2D,RES2E,RES2H,RES2L,RES2HL,RES2A; 90
	DC.L	RES3B,RES3C,RES3D,RES3E,RES3H,RES3L,RES3HL,RES3A; 98
	DC.L	RES4B,RES4C,RES4D,RES4E,RES4H,RES4L,RES4HL,RES4A; A0
	DC.L	RES5B,RES5C,RES5D,RES5E,RES5H,RES5L,RES5HL,RES5A; A8
	DC.L	RES6B,RES6C,RES6D,RES6E,RES6H,RES6L,RES6HL,RES6A; B0
	DC.L	RES7B,RES7C,RES7D,RES7E,RES7H,RES7L,RES7HL,RES7A; B8
	DC.L	SET0B,SET0C,SET0D,SET0E,SET0H,SET0L,SET0HL,SET0A; C0
	DC.L	SET1B,SET1C,SET1D,SET1E,SET1H,SET1L,SET1HL,SET1A; C8
	DC.L	SET2B,SET2C,SET2D,SET2E,SET2H,SET2L,SET2HL,SET2A; D0
	DC.L	SET3B,SET3C,SET3D,SET3E,SET3H,SET3L,SET3HL,SET3A; D8
	DC.L	SET4B,SET4C,SET4D,SET4E,SET4H,SET4L,SET4HL,SET4A; E0
	DC.L	SET5B,SET5C,SET5D,SET5E,SET5H,SET5L,SET5HL,SET5A; E8
	DC.L	SET6B,SET6C,SET6D,SET6E,SET6H,SET6L,SET6HL,SET6A; F0
	DC.L	SET7B,SET7C,SET7D,SET7E,SET7H,SET7L,SET7HL,SET7A; F8

; <=--------------------------------------------------------------------=>

	CNOP	0,8
RegsIN:
	DC.L	INS00,NADIN,NADIN,NADIN,INS04,NADIN,NADIN,NADIN	; 00
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; 08
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; 10
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; 18
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; 20
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; 28
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; 30
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; 38
	DC.L	NADIN,INS41,NADIN,NADIN,INS44,NADIN,NADIN,NADIN	; 40
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; 48
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; 50
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; 58
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; 60
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; 68
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; 70
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; 78
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; 80
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; 88
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; 90
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; 98
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; A0
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; A8
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; B0
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; B8
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; C0
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; C8
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; D0
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; D8
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; E0
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; E8
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; F0
	DC.L	NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN,NADIN	; F8

	CNOP	0,8
RegsOUT:
	DC.L	OUT00,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; 00
	DC.L	NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; 08
	DC.L	NAOUT,NAOUT,OUT12,OUT13,OUT13,NAOUT,NAOUT,OUT17	; 10
	DC.L	OUT18,OUT18,NAOUT,NAOUT,NAOUT,OUT1D,OUT1D,NAOUT	; 18
	DC.L	NAOUT,OUT21,OUT22,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; 20
	DC.L	NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; 28
	DC.L	NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; 30
	DC.L	NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; 38
	DC.L	OUT40,OUT41,OUT42,OUT43,NAOUT,OUT45,OUT46,OUT47	; 40
	DC.L	NAOUT,NAOUT,OUT4A,OUT4B,NAOUT,NAOUT,NAOUT,NAOUT	; 48
	DC.L	NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; 50
	DC.L	NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; 58
	DC.L	NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; 60
	DC.L	NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; 68
	DC.L	NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; 70
	DC.L	NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; 78
	DC.L	NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; 80
	DC.L	NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; 88
	DC.L	NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; 90
	DC.L	NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; 98
	DC.L	NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; A0
	DC.L	NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; A8
	DC.L	NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; B0
	DC.L	NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; B8
	DC.L	NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; C0
	DC.L	NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; C8
	DC.L	NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; D0
	DC.L	NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; D8
	DC.L	NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; E0
	DC.L	NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; E8
	DC.L	NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; F0
	DC.L	NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT,NAOUT	; F8


; <=--------------------------------------------------------------------=>

	CNOP	0,8
PagRuts:
	DC.L	OtraInst
	DC.L	MapperROM
	DC.L	MapperRAM
	DC.L	OtraInst
	DC.L	EscrVRAM
	DC.L	EscrERAM
	DC.L	EscrIRAM
	DC.L	EscrReg


	NULO
OtraInst:
	Otra2

; -=-=-

	NULO
MapperROM:
	SUB.W	(A2),A5

	MOVE.B	(A4),D1
	AND.W	MaskROM(A3),D1
	BNE.S	MappROMCon
	MOVEQ	#1,D1
MappROMCon:
	MULU	#$4080,D1
	ADD.L	MapROMBase(A3),D1
	MOVE.L	D1,PagRead+$8(A3)
	MOVE.L	D1,PagRead+$C(A3)

	MOVE.W	D1,Restas+($8*2)(A3)
	MOVE.W	D1,Restas+($C*2)(A3)

	ADD.L	#$4001,D1
	MOVE.L	D1,Restas+Desbor+($10)(A3)
	ADD.L	#$1FFF,D1
	MOVE.L	D1,Restas+Desbor+($14)(A3)
	ADDQ.L	#$0001,D1
	MOVE.L	D1,Restas+Desbor+($18)(A3)
	ADD.L	#$1FFF,D1
	MOVE.L	D1,Restas+Desbor+($1C)(A3)

	MOVEQ	#0,D1
	MOVE.W	A5,D1
	CogePag	D1,A5

	Otra2
; -=-=-
	NULO
MapperRAM:
	SUB.W	(A2),A5

	MOVE.B	(A4),D1
	AND.W	MaskRAM(A3),D1
	MULU	#$2000+$80,D1
	ADD.L	#ERAM0-$A000,D1
	MOVE.L	D1,PagRead+$14(A3)
	MOVE.L	D1,PagWrite+$14(A3)

	MOVE.W	D1,Restas+($14*2)(A3)

	ADD.L	#$A001,D1
	MOVE.L	D1,Restas+Desbor+($28)(A3)
	ADD.L	#$1FFF,D1
	MOVE.L	D1,Restas+Desbor+($2C)(A3)

	MOVEQ	#0,D1
	MOVE.W	A5,D1
	CogePag	D1,A5

	MOVE.W	D0,D1
	CogePagE D1,A6

	Otra2

; -=-=-

EscrVRAM:
	SUB.L	A1,A4
	MOVE.W	A4,D1
	LSR.W	#4,D1
	ST	(TabRedef.W,A3,D1.W)
	Otra2

EscrERAM:
	Otra2

EscrIRAM:
	Otra2

EscrRRAM:
	Otra2

EscrReg:
	MOVE.B	(A4),D2				; NO modificar NADA.
	SUB.L	A0,A4
	TST.L	A4
	BMI.S	EscrRRAM
	JMP	([RegsOUT.W,PC,A4.W*4])		; Salta a puntero de emulación.


; <=--------------------------------------------------------------------=>


	CNOP	0,8

	DC.W	0		; -$CC		Contador1
	DC.B	0		; -$CA		UltCopLin
	DC.B	0		; -$C9		UltCoorY

	DC.L	0 ;CopperLine+$14+(CoppLineSize)	; -$C8(A3)	ScrResAnt
	DC.L	CopperLine+$12			; -$C4(A3)	IntGB1Ant

	DS.L	2		; -$C0(A3)	Desbor  [-$40(Restas)]
	DS.L	2		; -$B8(A3)
	DS.L	2		; -$B0(A3)
	DS.L	2		; -$A8(A3)
	DS.L	2		; -$A0(A3)
	DS.L	2		; -$98(A3)
	DS.L	2		; -$90(A3)
	DS.L	2		; -$88(A3)

	DS.L	2		; -$80(A3)	Restas
	DS.L	2		; -$78(A3)
	DS.L	2		; -$70(A3)
	DS.L	2		; -$68(A3)
	DS.L	2		; -$60(A3)
	DS.L	2		; -$58(A3)
	DS.L	2		; -$50(A3)
	DS.L	2		; -$48(A3)


	DC.L	0		; -$40(A3)	PagRead
	DC.L	0		; -$3C(A3)
	DC.L	$80		; -$38(A3)
	DC.L	$80		; -$34(A3)
	DC.L	VRAM-$8000	; -$30(A3)
	DC.L	ERAM0-$A000	; -$2C(A3)
	DC.L	IRAM-$C000	; -$28(A3)
	DC.L	RRAM-$E000	; -$24(A3)

	DC.L	ESROM		; -$20(A3)	PagWrite
	DC.L	ESROM-$2000	; -$1C(A3)
	DC.L	ESROM-$4000	; -$18(A3)
	DC.L	ESROM-$6000	; -$14(A3)
	DC.L	VRAM-$8000	; -$10(A3)
	DC.L	ERAM0-$A000	; -$0C(A3)
	DC.L	IRAM-$C000	; -$08(A3)
	DC.L	RRAM-$E000	; -$04(A3)
Regs:
	DC.B	0	;     (A3)	ANA
	DC.B	0	;   $1(A3)	IFF

	DC.L	0	;   $2(A3)	EstadoJoy

	DC.L	0	;   $6(A3)	MapROMBase

	DC.B	0	;   $A(A3)	SalirMenu
	DC.B	0	;   $B(A3)	ModoTraza

	DC.L	0	;   $C(A3)	EstadoKeys

	DC.W	0	;  $10(A3)	MaskROM
	DC.W	0	;  $12(A3)	MaskRAM

	DC.B	0	;  $14(A3)	PetIntGB
	DC.B	0	;  $15(A3)	RasterInt

	DC.W	0	;  $16(A3)	DirIntGB
	DC.L	0	;  $18(A3)	ExeIntGB

	DC.L	0	;  $1C(A3)

	DC.B	0	;  $20(A3)	D40


FRegs:	DS.B	$7C-(FRegs-Regs)

	DS.B	$400	;  $7C(A3)	TAB_Flags
	DC.L	0	; $47C(A3)
	DS.B	$380	; $480(A3)
;	 -----------------------------------------------------------
;	**  Tablas de instrucciones del Z-80 Simulado por MC68020  **
;	 -----------------------------------------------------------
Instr:			; $800(A3)

	DC.L	NOP,LDBCN,LDBCA,INCBC,INCB,DECB,LDBN,IRLCA	; 00
	DC.L	LDMSP,ADDHLBC,LDABC,DECBC,INCC,DECC,LDCN,IRRCA	; 08
	DC.L	STOP,LDDEN,LDDEA,INCDE,INCD,DECD,LDDN,IRLA	; 10
	DC.L	JR,ADDHLDE,LDADE,DECDE,INCE,DECE,LDEN,IRRA	; 18
	DC.L	JRNZ,LDHLN,LDHLIA,INCHL,INCH,DECH,LDHN,DAA	; 20
	DC.L	JRZ,ADDHLHL,LDAHLI,DECHL,INCL,DECL,LDLN,ICPL	; 28
	DC.L	JRNC,LDSPN,LDHLDA,INCSP,INCHLM,DECHLM,LDHLMN,SCF; 30
	DC.L	JRC,ADDHLSP,LDAHLD,DECSP,INCA,DECA,LDAN,CCF	; 38

	DC.L	LDBB,LDBC,LDBD,LDBE,LDBH,LDBL,LDBHL,LDBA	; 40
	DC.L	LDCB,LDCC,LDCD,LDCE,LDCH,LDCL,LDCHL,LDCA	; 48
	DC.L	LDDB,LDDC,LDDD,LDDE,LDDH,LDDL,LDDHL,LDDA	; 50
	DC.L	LDEB,LDEC,LDED,LDEE,LDEH,LDEL,LDEHL,LDEA	; 58
	DC.L	LDHB,LDHC,LDHD,LDHE,LDHH,LDHL,LDHHL,LDHA	; 60
	DC.L	LDLB,LDLC,LDLD,LDLE,LDLH,LDLL,LDLHL,LDLA	; 68
	DC.L	LDHLB,LDHLC,LDHLD,LDHLE,LDHLH,LDHLL,HALT,LDHLA	; 70
	DC.L	LDAB,LDAC,LDAD,LDAE,LDAH,LDAL,LDAHL,LDAA	; 78

	DC.L	ADDAB,ADDAC,ADDAD,ADDAE,ADDAH,ADDAL,ADDAHL,ADDAA; 80
	DC.L	ADCAB,ADCAC,ADCAD,ADCAE,ADCAH,ADCAL,ADCAHL,ADCAA; 88
	DC.L	SUBB,SUBC,SUBD,SUBE,SUBH,SUBL,SUBHL,SUBA	; 90
	DC.L	SBCB,SBCC,SBCD,SBCE,SBCH,SBCL,SBCHL,SBCA	; 98
	DC.L	ANDB,ANDC,ANDD,ANDE,ANDH,ANDL,ANDHL,ANDA	; A0
	DC.L	XORB,XORC,XORD,XORE,XORH,XORL,XORHL,XORA	; A8
	DC.L	ORB,ORC,ORD,ORE,ORH,ORL,ORHL,ORA		; B0
	DC.L	CPB,CPC,CPD,CPE,CPH,CPL,CPHL,CPA		; B8

	DC.L	RETNZ,POPBC,JPNZ,JP,CALLNZ,PUSHBC,ADDAN,RST0	; C0
	DC.L	RETZ,IRET,JPZ,RInsCB,CALLZ,CALL,ADCAN,RST8	; C8
	DC.L	RETNC,POPDE,JPNC,NOCOD,CALLNC,PUSHDE,SUBN,RST10	; D0
	DC.L	RETC,RETI,JPC,NOCOD,CALLC,NOCOD,SBCN,RST18	; D8
	DC.L	LDFFA,POPHL,LDCMA,EXSPHL,NOCOD,PUSHHL,ANDN,RST20; E0
	DC.L	ADDSPN,JPHL,LDMA,NOCOD,NOCOD,NOCOD,XORN,RST28	; E8
	DC.L	LDAFF,POPAF,LDACM,DI,NOCOD,PUSHAF,ORN,RST30	; F0
	DC.L	LDHLSPN,LDSPHL,LDAM,EI,NOCOD,NOCOD,CPN,RST38	; F8

	DS.L	256



	DS.L	128	; $1000(A3)	TabRedef



; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

	DS.L	20	; Seguridad

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-



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
	MOVE.L	#DirTraza,$24(A0)
	MOVE.L	#InInter,$6C(A0)
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
; ------------------------------------------------ ;
; ------------------------------------------------ ;
; ------------------------------------------------ ;
; ------------------------------------------------ ;
; ------------------------------------------------ ;
; ------------------------------------------------ ;
; ------------------------------------------------ ;


; -------------------------------------> Interrupción de Vblank la 1ª vez.
	CNOP	0,8
InInter:
	MOVE.L	DirContinua,2(SP)
	MOVE.B	DirFlags+1,1(SP)
	MOVE.L	#Inter,([VBRPun],$6C.W)
	BRA	Inter
; -------------------------------------<


	CNOP	0,8
EsActVDP:
	MOVEM.L	D0-D7/A0-A6,-(SP)



	BSR	ActCopperLine



	BSR	ActualizaGFX

	BSR	PoneScrollBG
;;	BSR	PoneScrollWin

	BSR	GFXPrint

	BSR	OBJPrint


	JSR	([JoyControlRut.w,PC])
	BSR	MiraTeclado

	LEA	Regs(PC),A3
	MOVE.B	EstadoKeys(A3),D1	; Joypad
	AND.B	D1,EstadoJoy+2(A3)
	MOVE.B	EstadoKeys+1(A3),D1	; Botones
	AND.B	D1,EstadoJoy+1(A3)
	MOVE.B	EstadoKeys+2(A3),D1	; Botones
	AND.B	D1,EstadoJoy+1(A3)


	BSR	PonePaleta


	BSR	TocaSonido

	IFNE	AutoExit
	ADDQ.L	#1,AutoFrames
	CMP.L	#AutoExit,AutoFrames
	BCS.S	.noAutoExit
	ST	Regs+SalirMenu		; as Esc: back to the caller of GameBoyEmul
.noAutoExit:
	ENDC

	MOVEM.L	(SP)+,D0-D7/A0-A6
	MOVE.W	#$0010,$DFF09C
	NOP
	RTE



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


	MOVE.L	(SP)+,D3

	MOVE.W	#$0086,(A3)+
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

	LSL.W	#4,D2
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
; ------------------------------------------------ ;


	CNOP	0,8
Inter:
	MOVE.L	#GBInter0,ExeIntGB(A3)
	BTST	#5,$DFF01F			; ¿Vblank?
	BNE.S	ExeTraza

;;	MOVE.L	#EsActVDP,ExeIntGB(A3)
	BTST	#0,$DFF01F			; 00 ¿ActVDP?
	BEQ	EsActVDP
;;	BEQ.S	ExeTraza

	MOVE.L	#GBInter1,ExeIntGB(A3)
	BTST	#1,$DFF01F			; 01 ¿Line inter?
	BEQ.S	ExeTraza

	MOVE.L	#GBInter2,ExeIntGB(A3)		; 11 Timer.
	BRA.s	ExeTraza


; ------------------------------------------------ ;
; ------------------------------------------------ ;
; ------------------------------------------------ ;

	CNOP	0,8
ExeTraza:

	MOVE.W	#$0070,$DFF09C

; -------------------------------------> Espera final de instrucción de Z-80A
	MOVE.W	#$0030,$DFF09A		; Todo OFF
	ST	ModoTraza(A3)
	AND.B	#$3F,(SP)		; <=-- MODO TRAZA ON. (Cuidado) ****
Mtr0:	OR.B	#$40,(SP)		; <=-- MODO TRAZA ON. (Cuidado) ****
	BRA.S	DirTraza
;	---------------
	CNOP	0,8
DirTraza:
	CMP.W	#"GG",([2.W,SP],-2.W)
	BEQ.S	FinIns2
	NOP
	RTE
;	----------------
	CNOP	0,8
FinIns2:
	CMP.W	D1,D2		; Excepción de EI.
	BNE.S	FinIns
	NOP
	RTE
;	----------------
	CNOP	0,8
FinIns:
;;;	MOVE.W	#$2700,SR
	SF	ModoTraza(A3)
	AND.B	#$3F,(SP)		; <=-- MODO TRAZA OFF. (Cuidado) ****
; -------------------------------------<
	JMP	([ExeIntGB.w,A3])


; ----------------------------------------
	CNOP	0,8
SiSalir:
	SF	SalirMenu(A3)
	MOVE.L	2(SP),DirContinua
	MOVE.W	(SP),DirFlags
	MOVE.L	#Salir,2(SP)
	CLR.W	(SP)
	MOVE.W	#$0070,$DFF09C
	NOP
	RTE
; ----------------------------------------

	CNOP	0,8
GBInter0:
	TST.B	SalirMenu(A3)
	BNE.S	SiSalir

	BTST	#$0,RRAM+$1FFF
	BEQ	NoInter
	BSET	#$0,RRAM+$1F0F
	MOVE.W	#$40,DirIntGB(A3)

	ST	PetIntGB(A3)

	BRA	GBInter

GBInter1:
	BTST	#$1,RRAM+$1FFF
	BEQ	NoInter
	BSET	#$1,RRAM+$1F0F
	MOVE.W	#$48,DirIntGB(A3)

	OR.B	#$7F,PetIntGB(A3)

	BRA.S	GBInter

GBInter2:
	BTST	#$2,RRAM+$1FFF
	BEQ.S	NoInter
	BSET	#$2,RRAM+$1F0F
	MOVE.W	#$50,DirIntGB(A3)
	BRA	GBInter


	CNOP	0,4
GBInter:

	MOVE.B	$DFF006,D1
	ADDQ.B	#$4,D1
	MOVE.B	D1,RasterInt(A3)

	TST.B	IFF(A3)			; ¿Modo DI?
	BEQ.S	NoInter

	SF	PetIntGB(A3)

	SF	IFF(A3)			; ( DI ) Interrupciones OFF.
; -------------------------------------> Arranca Interrupción de MSX (cont.)
	MOVE.L	#RetuInter,2(SP)
	SUBQ.W	#1,A5
	SUB.W	(A2),A5
	MOVE.W	A5,D2
;	----------------
	MOVEQ	#0,D1
	SUBQ.W	#2,D0
	MOVE.W	D0,D1
	CogePagE D1,A6
	move.b	d2,(a6)
	MOVE.W	D0,D1
	ADDQ.W	#1,D1
	CogePagE D1,A4
	lsr.w	#8,d2
	move.b	d2,(a4)
	MOVE.W	#$0100,D2
	MOVE.L	PagRead(A3),A5
	ADD.W	DirIntGB(A3),A5
	LEA	Restas(A3),A2
;	----------------
NoInter:
	MOVE.W	#$8030,$DFF09A		; Todo ON
	NOP
	RTE
;	----------------
	CNOP	0,8
RetuInter:
	Otra2
; ---


; ------------------------------------------------ ;
; ------------------------------------------------ ;
; ------------------------------------------------ ;


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
	MOVE.B	RRAM+$1F47,D0
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
	MOVE.B	RRAM+$1F48,D0
	BFEXTU	D0{24:2},D1
	MOVE.W	(A0,D1.W*2),COLOR0+($3*4)+2
	BFEXTU	D0{26:2},D1
	MOVE.W	(A0,D1.W*2),COLOR0+($2*4)+2
	BFEXTU	D0{28:2},D1
	MOVE.W	(A0,D1.W*2),COLOR0+($1*4)+2
; -============================================-> Paleta de OBJ1 en BPL0
	MOVE.B	RRAM+$1F49,D0
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








; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
TocaSonido:
	LEA	$DFF000,A6

	MOVEQ	#0,D1
	BTST	#7,RRAM+$1F26		; All Sound
	BEQ.S	TSVolCero1
	BTST	#0,RRAM+$1F25		; Out 1 to SO1
	BNE.S	TSSich1
	BTST	#4,RRAM+$1F25		; Out 1 to SO2
	BEQ.S	TSVolCero1
TSSich1:
	MOVE.W	SounVol1,D1
	BEQ.S	TSVolCero1

	BFEXTU	RRAM+$1F12{5:3},D0
	BEQ.S	TSVolCero1

	BTST	#3,RRAM+$1F12
	BEQ.S	TSVolRes1

	ADDQ.W	#4,SounVol1
	CMP.W	#41,SounVol1
	BCS.S	TSVolCero1
	BCLR	#3,RRAM+$1F12
	BRA.S	TSVolCero1

TSVolRes1:
	SUBQ.B	#1,SounEnv1
	BNE.S	TSVolCero1
	MOVE.B	D0,SounEnv1

	SUBQ.W	#4,SounVol1
	BCC.S	TSVolCero1
	CLR.W	SounVol1
TSVolCero1:
	MOVE.W	D1,$A8(A6)	; Vol

	MOVEQ	#0,D0
	MOVE.B	RRAM+$1F11,D0
	LSR.B	#6,D0
	MOVE.L	(DirSample.w,PC,D0.w*4),$A0(A6)


	MOVEQ	#0,D1
	BTST	#7,RRAM+$1F26		; All Sound
	BEQ.S	TSVolCero2
	BTST	#1,RRAM+$1F25		; Out 2 to SO1
	BNE.S	TSSich2
	BTST	#5,RRAM+$1F25		; Out 2 to SO2
	BEQ.S	TSVolCero2
TSSich2:
	MOVE.W	SounVol2,D1
	BEQ.S	TSVolCero2

	BFEXTU	RRAM+$1F17{5:3},D0
	BEQ.S	TSVolCero2

	SUBQ.B	#1,SounEnv2
	BNE.S	TSVolCero2
	MOVE.B	D0,SounEnv2

	BTST	#3,RRAM+$1F17
	BEQ.S	TSVolRes2

	ADDQ.W	#4,SounVol2
	CMP.W	#41,SounVol2
	BCS.S	TSVolCero2
	BCLR	#3,RRAM+$1F17
	BRA.S	TSVolCero2

TSVolRes2:
	SUBQ.W	#4,SounVol2
	BCC.S	TSVolCero2
	CLR.W	SounVol2
TSVolCero2:
	MOVE.W	D1,$B8(A6)	; Vol

	MOVEQ	#0,D0
	MOVE.B	RRAM+$1F16,D0
	LSR.B	#6,D0
	MOVE.L	(DirSample.w,PC,D0.w*4),$B0(A6)



	LEA	RRAM+$1F30,A0
	LEA	OndaS,A1
	BFEXTU	RRAM+$1F1C{1:2},D2
	SUBQ.B	#1,D2
	BCS	TSNoRotar
	REPT	$10
	MOVE.B	(A0)+,D0
	MOVE.B	D0,D1
	AND.B	#$F0,D0
	SUB.B	#$80,D0
	ASR.B	D2,D0
	MOVE.B	D0,(A1)+
	LSL.B	#4,D1
	SUB.B	#$80,D1
	ASR.B	D2,D1
	MOVE.B	D1,(A1)+
	ENDR
TSNoRotar:


	MOVEQ	#0,D1
	MOVEQ	#0,D2
	BFTST	RRAM+$1F1C{1:2}
	BEQ.S	TSNoch3
	BTST	#7,RRAM+$1F26		; All Sound
	BEQ.S	TSNoch3
	BTST	#7,RRAM+$1F1A		; Sound 3 ON real
	BEQ.S	TSNoch3

	BTST	#2,RRAM+$1F25		; Out 3 to SO1
	BEQ.S	TSNoch3b
	MOVE.B	RRAM+$1F24,D1
	AND.W	#$0007,D1
	LSL.B	#2,D1
TSNoch3b:
	BTST	#6,RRAM+$1F25		; Out 3 to SO2
	BEQ.S	TSNoch3
	MOVE.B	RRAM+$1F24,D2
	AND.W	#$0070,D2
	LSR.B	#2,D2
TSNoch3:
	MOVE.W	D1,$C8(A6)	; Vol
	MOVE.W	D2,$D8(A6)	; Vol


	RTS


	MOVEQ	#0,D1
	BTST	#7,RRAM+$1F26		; All Sound
	BEQ.S	TSVolCero4
	BTST	#3,RRAM+$1F25		; Out 4 to SO1
	BNE.S	TSSich4
	BTST	#7,RRAM+$1F25		; Out 4 to SO2
	BEQ.S	TSVolCero4
TSSich4:
	MOVE.W	SounVol4,D1
	BEQ.S	TSVolCero4

	BFEXTU	RRAM+$1F21{5:3},D0
	BEQ.S	TSVolCero4

	BTST	#3,RRAM+$1F21
	BEQ.S	TSVolRes4

	ADDQ.W	#4,SounVol4
	CMP.W	#41,SounVol4
	BCS.S	TSVolCero4
	BCLR	#3,RRAM+$1F21
	BRA.S	TSVolCero4

TSVolRes4:
	SUBQ.B	#1,SounEnv4
	BNE.S	TSVolCero4
	MOVE.B	D0,SounEnv4

	SUBQ.W	#4,SounVol4
	BCC.S	TSVolCero4
	CLR.W	SounVol4
TSVolCero4:
	MOVE.W	D1,$D8(A6)	; Vol


	RTS


	CNOP	0,8
DirSample:	DC.L	Onda0,Onda1,Onda2,Onda3

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-










; ------------------------------------------------ ;
; ------------------------------------------------ ;
; ------------------------------------------------ ;
; ------------------------------------------------ ;
; ------------------------------------------------ ;


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
DirContinua:	DC.L	BUCLE
DirFlags:	DC.W	0
INTERDAT:	DC.W	0
PILA:		DC.L	0

; -------------------------------------------------------------
; -------------------------------------------------------------
; -------------------------------------------------------------
; -------------------------------------------------------------
; -------------------------------------------------------------




	IFD	EMBED
; EMBED test build: run the ROM inside without the menu, as Power On does with the
; default prefs (PAL screen). AutoExit builds write "frames=$x" to RAM:AmiGB.result.
	CNOP	0,8
EmbedStart:
	MOVE.L	#EmbedCart,DirCart
	MOVE.W	#(EmbedCartEnd-EmbedCart-$80)/$4080,PagCart
	MOVE.W	#$20,$DFF1DC		; PAL, as the menu does with Screen mode 0
	MOVEQ	#0,D7			; Power On
	JSR	GameBoyEmul
	IFNE	AutoExit
	MOVE.L	$4.W,A6
	LEA	EmbDosName(PC),A1
	MOVEQ	#0,D0
	JSR	-$228(A6)		; OpenLibrary
	TST.L	D0
	BEQ.S	.nodos
	MOVE.L	D0,A6
	LEA	EmbResText+7(PC),A0	; "frames=" then 8 hex digits
	MOVE.L	AutoFrames(PC),D0
	MOVEQ	#8-1,D1
.hex:	ROL.L	#4,D0
	MOVE.B	D0,D2
	AND.B	#$0F,D2
	ADD.B	#"0",D2
	CMP.B	#"9",D2
	BLS.S	.dig
	ADDQ.B	#"A"-"9"-1,D2
.dig:	MOVE.B	D2,(A0)+
	DBF	D1,.hex
	MOVE.L	#EmbResName,D1
	MOVE.L	#1006,D2		; MODE_NEWFILE
	JSR	-$1E(A6)		; Open
	MOVE.L	D0,D4
	BEQ.S	.noopen
	MOVE.L	D4,D1
	MOVE.L	#EmbResText,D2
	MOVEQ	#EmbResEnd-EmbResText,D3
	JSR	-$30(A6)		; Write
	MOVE.L	D4,D1
	JSR	-$24(A6)		; Close
.noopen:
	MOVE.L	A6,A1
	MOVE.L	$4.W,A6
	JSR	-$19E(A6)		; CloseLibrary
.nodos:
	ENDC
	MOVEQ	#0,D0
	RTS

	IFNE	AutoExit
AutoFrames:	DC.L	0
EmbDosName:	DC.B	"dos.library",0
EmbResName:	DC.B	"RAM:AmiGB.result",0
EmbResText:	DC.B	"frames=00000000",10
EmbResEnd:
	EVEN
	ENDC

;	------------------------
	SECTION	EmbedRom,DATA
;	------------------------
	CNOP	0,8
EmbedCart:
	INCLUDE	"embed.i"	; written by build_embed.sh: INCBIN of the ROM in the menu's $4080 layout
EmbedCartEnd:
	ENDC

;	------------------------
	SECTION	Memoria,BSS
;	------------------------


; =----------------------------------------=> GameBoy RAM.
	CNOP	0,8
	DS.B	$80
VRAM:	DS.B	8*1024
	DS.B	$80
ERAM0:	DS.B	8*1024
	DS.B	$80
ERAM1:	DS.B	8*1024
	DS.B	$80
ERAM2:	DS.B	8*1024
	DS.B	$80
ERAM3:	DS.B	8*1024
	DS.B	$80
IRAM:	DS.B	8*1024
	DS.B	$80
RRAM:	DS.B	8*1024
	DS.B	$80
ESROM:	DS.B	8*1024
	DS.B	$80
; =----------------------------------------<=



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



	DC.W	$4001,$FFFE		; Timer.
	DC.W	$009C,$0000
	DC.W	$009C,$8013



ScrBits:DC.W	$0102,$CC00
	DC.W	$0104,$0007
BpCon3:	DC.W	$0106,$0020
	DC.W	$010C,$0011
	DC.W	$4769,$FFFE
	DC.W	$0100,$0411


CopperLine:	DCB.L	(CoppLineSize/4)*146,$01A00000



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

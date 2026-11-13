
;	Menu para AmiGameBoy Emulator.
;	Por: Juan Antonio Gómez Gálvez

;    DC.L    $80000093,1			; En MainMenuWIN
;    DC.L    $80080032,6,$00000000		; En MTags0

_SysBase=4

MenuLaunch:
; <=----------------------------------=>
	MOVEQ	#0,D0
	LEA	GadNom(PC),A1
	MOVE.L	$4.W,A6
	JSR	-$228(A6)
	MOVE.L	D0,_GadToolsBase
	BEQ	LibsError
; <=----------------------------------=>
	MOVEQ	#0,D0
	LEA	IntNom(PC),A1
	MOVE.L	$4.W,A6
	JSR	-$228(A6)
	MOVE.L	D0,_IntuitionBase
	BEQ	LibsError
; <=----------------------------------=>
	MOVEQ	#0,D0
	LEA	DosNom(PC),A1
	MOVE.L	$4.W,A6
	JSR	-$228(A6)
	MOVE.L	D0,_DosBase
	BEQ	LibsError
; <=----------------------------------=>
	MOVEQ	#0,D0
	LEA	AslNom(PC),A1
	MOVE.L	4.W,A6
	JSR	-$228(A6)
	MOVE.L	D0,_AslBase
; <=----------------------------------=>
	MOVEQ	#0,D0
	LEA	XpkNom(PC),A1
	MOVE.L	4.W,A6
	JSR	-$228(A6)
	MOVE.L	D0,_XpkBase
; <=----------------------------------=>
	MOVEQ	#3,D0
	LEA	StcNom(PC),A1
	MOVE.L	4.W,A6
	JSR	-$228(A6)
	MOVE.L	D0,_StcBase
	BNE.S	YaStc20
	MOVEQ	#3,D0
	LEA	Stc2Nom(PC),A1
	MOVE.L	4.W,A6
	JSR	-$228(A6)
	MOVE.L	D0,_StcBase
YaStc20:
; <=-----------------------=>

; <=----------------------------------=>
	CLR.L	MENSWB
	MOVE.L	$4.W,A6
	SUB.L	A1,A1
	JSR	-$126(A6)
	MOVE.L	D0,A2
	TST.L	$AC(A2)
	BNE.S	CLI
	LEA	$5C(A2),A0
	JSR	-$180(A6)
	LEA	$5C(A2),A0
	JSR	-$174(A6)
	MOVE.L	D0,MENSWB
	MOVE.L	D0,A2
	MOVE.L	$24(A2),D0
	BEQ.S	CLI
	MOVE.L	_DosBase,A6
	MOVE.L	D0,A0
	MOVE.L	(A0),D1
	JSR	-$7E(A6)
CLI:
; <=----------------------------------=>

	LEA	DirInfoText(PC),A0
	BSR	Centrar

; <=-----------------------=>

	BSR	CreaDissasemTab

	BSR	Programa

; <=-----------------------=>
	MOVE.L	BucCart(PC),D0
	BEQ.S	NoHayCart2
	MOVE.L	DirCart(PC),A1
	MOVE.L	$4.W,A6
	JSR	-$D2(A6)		; Libera memoria.
	CLR.L	BucCart
NoHayCart2:
; <=-----------------------=>
	TST.L	_AslBase(PC)
	BEQ.S	NoHayAsl2

	MOVE.L	InsReqBase,A0
	MOVE.L	_AslBase,A6
	JSR	-$36(A6)	; FreeAslRequest.
NoHayAsl2:
; <=-----------------------=>
	MOVE.L	$4.W,A6
	TST.L	MENSWB(PC)
	BEQ.S	MENSWBRET
	JSR	-$84(A6)
	MOVE.L	MENSWB(PC),A1
	JSR	-$17A(A6)
MENSWBRET:
; <=-----------------------=>

; <=-----------------------=>
LiberaLib:MACRO
	MOVE.L	\1,A1
	TST.L	A1
	BEQ.S	\@LibLib
	MOVE.L	$4.W,A6
	JSR	-$19E(A6)	; Libera Librería.
\@LibLib:
	ENDM

LibsError:
	LiberaLib _DosBase
	LiberaLib _IntuitionBase
	LiberaLib _GadToolsBase
	LiberaLib _AslBase
	LiberaLib _XpkBase
	LiberaLib _StcBase
MenuRET:
	RTS
; <=-----------------------=>

; <=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=>

;*;	DC.L	$80080001,Texto Ventana
;*;	DC.L	$80080002,Screen WND donde aparece el requester.
;*;	DC.L	$80080003,Coor X
;*;	DC.L	$80080004,Coor Y
;*;	DC.L	$80080005,Size X
;*;	DC.L	$80080006,Size Y
;*;	DC.L	$80080009,Directorio
;*;	DC.L	$8008000A,PatrÓn
;*;	DC.L	$80080012,Texto Ok
;*;	DC.L	$80080013,Texto Cancel
;*;	DC.L	$80080014,Patron On=1/Off=0
;*;	DC.L	$8008002F,1	; 1=Modo Directorios.
;*;	DC.L	$8008003C,1	; 1=No muestra los "#?.info"

	CNOP	0,4
InsTags:
	DC.L	$80080002,0
	DC.L	$80080012,tInsert
	DC.L	$80080003,165
	DC.L	$80080004,11
	DC.L	$80080006,196
	DC.L	$8008003C,11		; No muestra los "#?.info"
	DC.L	$80080009,DirPrefs+$20
	DC.L	0,0

	CNOP	0,4
InsLoadTags:
	DC.L	$80080012,tInsert
	DC.L	$80080001,tInsLoad
	DC.L	$8008002C,0		; 0=Modo Load.
	DC.L	0,0

; ---

	EVEN
tInsert:DC.B	"Insert",0,0
tInsLoad:DC.B	"Select Cartridge file.",0,0

; <=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=>

; <=-----------------------=>
	CNOP	0,8
DirInfoText:
	DC.L	AboutText0,0,324
	DC.L	AboutText1,0,324
	DC.L	AboutText2,0,324
	DC.L	AboutText3,0,324
	DC.L	AboutText4,0,324
	DC.L	AboutText5,0,324
	DC.L	AboutText6,0,324
	DC.L	AboutText7,0,324
	DC.L	AboutText8,0,324
	DC.L	AboutText9,0,324
	DC.L	AboutText10,0,324
	DC.L	0,0,0,0
; <=-----------------------=>

; -=-=-=-==-=-=-=-==-=-=-=-=-=-=-=-=-=-=-=-=-=-
		CNOP	0,4
DisBase:	DC.L	0
BucFile:	DC.L	0
InsReqBase:	DC.L	0
XpkFibBase:	DC.L	0
; -=-=-=-==-=-=-=-==-=-=-=-=-=-=-=-=-=-=-=-=-=-
DirCart:	DC.L	0
BucCart:	DC.L	0
PagCart:	DC.W	0
Comprimido:	DC.B	0
RawCartSize:	DC.B	0
CheatDir:	DC.W	0
BucPunto:	DC.W	0
CheckId:	DC.L	0
EsUn060:	DC.B	0
GoDat:		DC.B	0
DisCheaDat:	DC.B	0
BattKbs:	DC.B	0
DirMonitor:	DC.W	0
DirDissasem:	DC.W	0
; -=-=-=-==-=-=-=-==-=-=-=-=-=-=-=-=-=-=-=-=-=-
_GadToolsBase:	DC.L	0
_IntuitionBase:	DC.L	0
_DosBase:	DC.L	0
_AslBase:	DC.L	0
_XpkBase:	DC.L	0
_StcBase:	DC.L	0
; -=-=-=-==-=-=-=-==-=-=-=-=-=-=-=-=-=-=-=-=-=-
		CNOP	0,8
GadNom:		DC.B	"gadtools.library",0
IntNom:		DC.B	"intuition.library",0
DosNom:		DC.B	"dos.library",0
AslNom:		DC.B	"asl.library",0
XpkNom:		DC.B	"xpkmaster.library",0
StcNom:		DC.B	"stc.library",0
Stc2Nom:	DC.B	"stc020.library",0
; -=-=-=-==-=-=-=-==-=-=-=-=-=-=-=-=-=-=-=-=-=-
		CNOP	0,8
MENSWB:		DC.L	0
ControlKeys:	DC.W	0
; -=-=-=-==-=-=-=-==-=-=-=-=-=-=-=-=-=-=-=-=-=-
		CNOP	0,4
FileNom:	DS.B	$208
FileNomSav:	DS.B	$208
FileNomFro:	DS.B	$208
FileNomSav2:	DS.B	$108
FileNomFro2:	DS.B	$108
		CNOP	0,4
BuferDsk:	DS.L	8
		CNOP	0,4
Examine:	DS.B	520
; -=-=-=-==-=-=-=-==-=-=-=-=-=-=-=-=-=-=-=-=-=-
; -=-=-=-==-=-=-=-==-=-=-=-=-=-=-=-=-=-=-=-=-=-
		DS.L	25	; Seguriad

tErNoAsl:
	DC.B	6,"asl.library not found"
	DC.B	0,"I can't open ASL request",0
tErNoStc:
	DC.B	6,"stc.library not found"
	DC.B	0,"I can't unpack this file",0
tErNoCartucho:
	DC.B	1,"GameBoy Cartridge required"
	DC.B	0,"Insert a Cartridge...",0
tErOpenFile:
	DC.B	0,"Open file failed"
	DC.B	0,"I can't open this file",0
tErReadFile:
	DC.B	0,"Error while loading file"
	DC.B	0,"Cartridge not inserted",0
tErNoGBCart:
	DC.B	4,"Not a GameBoy Cartridge!"
	DC.B	0,"Bad cartridge size!",0
tErOutOfMem:
	DC.B	7,"-=>  Out of memory!  <=-"
	DC.B	0,"Memory is gold!",0
tErChecksum:
	DC.B	3,"***  C A U T I O N  ***"
	DC.B	0,"Checksum is wrong!",0
tErSavePrefs:
	DC.B	0,"***  C A U T I O N  ***"
	DC.B	0,"Preferences not saved!",0
tErIDNoCorrecto:
	DC.B	2,"***  C A U T I O N  ***"
	DC.B	0,"Bad GameBoy ID '00C3'",0

; -=-=-=-==-=-=-=-==-=-=-=-=-=-=-=-=-=-=-=-=-=-
		DS.L	10	; Seguriad
; -=-=-=-==-=-=-=-==-=-=-=-=-=-=-=-=-=-=-=-=-=-

	CNOP	0,8
CabFileBuf:	DS.L	4
*************************************************************
		DS.L	25	; Seguriad
*************************************************************
*************************************************************

; ------------------------------------------
; ******************************************
; ------------------------------------------

	CNOP	0,8
Programa:
; ------------------------------------------
	BSR	LoadPrefs
	BSR	PonPrefs
; ------------------------------------------
	BSR	SetupScreen
; ------------------------------------------

	BSR	MiraAGA
	TST.L	D0
	BEQ	Quitar

	BSR	MC68020
	TST.L	D0
	BEQ	Quitar

;;	BSR	CheckAGA

; ------------------------------------------

; ------------------------------------------
	MOVEM.L	MCeros,D0-D7/A0-A6
	BSR	OpenMainMenuWindow
; ------------------------------------------
	MOVEQ	#0,D0
	MOVEQ	#0,D1
	move.l  Scr,a0
	move.l  40(a0),a1
	move.w  4(a1),D1
	MOVE.L	MainMenuWnd,A0
	MOVE.L	50(A0),A0
	LEA	DatsGameBoyPic,A1
	MOVE.L	_IntuitionBase,A6
	JSR	-114(A6)
; ------------------------------------------
	BSR	ImpJoyType
; ------------------------------------------
; <=-----------------------=>
	TST.L	_AslBase(PC)
	BEQ.S	NoHayAsl

	MOVEQ	#0,D0
	LEA	InsTags(PC),A0
	MOVE.L	MainMenuWnd,4(A0)
	MOVE.L	_AslBase,A6
	JSR	-$30(A6)	; AllocAslRequest.
	MOVE.L	D0,InsReqBase
NoHayAsl:
; <=-----------------------=>
	IFD	HY_MENU
	IFD	HY_PADCFG
	JSR	HyPadCfg		; hybrid: the pad settings file, then HyAutoStart (hybrid/padcfg.s)
	ELSE
	JSR	HyAutoStart		; hybrid: a ROM named at start (hybrid/menu.s)
	ENDC
	ENDC
BucleMenu:
; ------------------------------------------
	LEA	MainMenuPunts,A1
	BSR	Control
; ------------------------------------------
	BSR	ActuPrefs
	TST.B	DirPrefs+$0C(PC)
	BNE.S	SiSaveBatt
	BSR	AskSaveBatt
	BMI.S	BucleMenu
	BRA.S	NoSaveBatt
SiSaveBatt:
	BSR	SaveBatt
NoSaveBatt:
; ------------------------------------------
	BSR	DisMouse
	MOVEM.L	MCeros,D0-D7/A0-A6
	JSR	OpenQuitWindow
	LEA	QuitPunts,A1
	BSR	Control
	JSR	CloseQuitWindow
	BSR	EnaMouse
; ------------------------------------------
	BSR	CloseMainMenuWindow
; ------------------------------------------
; --------------------------		; Screen mode on Exit.
	MOVE.B	DirPrefs+$18(PC),D0
	LSR.B	#1,D0
	BEQ.S	NoChangeCon
	MOVEQ	#0,D1
	LSR.B	#1,D0
	BNE.S	EsNTSC2
	MOVE.W	#$20,D1
EsNTSC2:MOVE.W	D1,$DFF1DC
NoChangeCon:
; ------------------------------------------
Quitar:	JSR	CloseDownScreen
; ------------------------------------------=> Quit
	MOVEQ	#0,D0	; Salir Sín Errores
	RTS
; ------------------------------------------
; ------------------------------------------
NoQuit:
	ADD.W	#16+4,SP
	JSR	CloseQuitWindow
	BSR	EnaMouse
	BRA	BucleMenu
; ------------------------------------------

; <=-----------------------=>
	CNOP	0,8
NeedASL:
	LEA	tErNoAsl(PC),A0
	JMP	ImpError
; <=-----------------------=>

; ------------------------------------------
; ******************************************
; ------------------------------------------

About:
	BSR	DisMouse
	MOVEM.L	MCeros,D0-D7/A0-A6
	BSR	OpenAboutWindow

; TEMPORAL:
	LEA	AboutGadgets+(GD_Aboutmore*4),A0
	MOVE.L	AboutWnd,A1
	MOVEQ	#1,D0
	BSR	GadsOnOff


	LEA	AboutPunts,A1
	BSR	Control

	JSR	CloseAboutWindow
	BSR	EnaMouse
	RTS

; ------------------------------------------
; ******************************************
; ------------------------------------------

HelpPage:
	BSR	DisMouse
	MOVEM.L	MCeros,D0-D7/A0-A6
	BSR	OpenHelpPageWindow

	MOVEQ	#20,D0
	MOVEQ	#16,D1
	MOVE.L	#GBTeclado,DirJoyTypePic
	BSR	ImprHelpJoy

	MOVE.L	#264,D0
	MOVEQ	#16,D1
	MOVE.L	#GBCD32,DirJoyTypePic
	BSR	ImprHelpJoy

	MOVEQ	#20,D0
	MOVE.L	#110,D1
	MOVE.L	#GBJoyStick,DirJoyTypePic
	BSR	ImprHelpJoy

	MOVE.L	#264,D0
	MOVE.L	#110,D1
	MOVE.L	#GBJoypad,DirJoyTypePic
	BSR	ImprHelpJoy

	LEA	HelpPagePunts,A1
	BSR	Control

	BSR	CloseHelpPageWindow
	BSR	EnaMouse
	RTS

ImprHelpJoy:
	move.l  Scr,a0
	move.l  40(a0),a1
	ADD.w	4(a1),D1
	MOVE.L	HelpPageWnd,A0
	MOVE.L	50(A0),A0
	LEA	DatsJoyTypePic,A1
	MOVE.L	_IntuitionBase,A6
	JMP	-114(A6)

; ------------------------------------------
; ******************************************
; ------------------------------------------

ImpError:
	MOVE.B	(A0)+,D0
	AND.W	#$0007,D0
	MOVE.L	(DirErrorGfx.w,PC,D0.W*4),-(SP)

	MOVE.L	A0,ImpErrorText0+$C
ImpErrorBuc:
	TST.B	(A0)+
	BNE.S	ImpErrorBuc
	MOVE.L	A0,ImpErrorText1+$C

	LEA	DirErrorText(PC),A0
	BSR	Centrar

	BSR	DisMouse

	MOVEM.L	MCeros,D0-D7/A0-A6
	BSR	OpenImpErrorWindow

	MOVE.L	#15,D0
	MOVE.L	#8,D1
	MOVE.L	(SP)+,A2

	move.l  Scr,a0
	move.l  40(a0),a1
	ADD.w	4(a1),D1
	MOVE.L	ImpErrorWnd,A0
	MOVE.L	50(A0),A0
	LEA	DatsErrorPic,A1
	MOVE.L	A2,10(A1)
	MOVE.L	_IntuitionBase,A6
	JSR	-114(A6)

	LEA	ImpErrorPunts,A1
	BSR	Control

	BSR	CloseImpErrorWindow
	BSR	EnaMouse
	RTS

	CNOP	0,8
DirErrorText:
	DC.L	ImpErrorText0,74,212
	DC.L	ImpErrorText1,74,212
	DC.L	0,0,0

DirErrorGfx:
	DC.L	Perill		; 0
	DC.L	Cart		; 1
	DC.L	CartB		; 2
	DC.L	CartR		; 3
	DC.L	CartX		; 4
	DC.L	Enfadat		; 5
	DC.L	Llibre		; 6
	DC.L	Ram		; 7

; ------------------------------------------
; ******************************************
; ------------------------------------------

CheatMode:
	BSR	DisMouse

	MOVEM.L	MCeros(PC),D0-D7/A0-A6
	JSR	OpenCheatWindow
	LEA	CheatPunts,A1
	BSR	Control

	JSR	CloseCheatWindow
	BSR	EnaMouse
	RTS

CalculPok:
	TST.B	(A0)
	BNE.S	PokBien
	MOVE.W	#$3000,(A0)
PokBien:
	MOVEQ	#0,D0
PokBuc1:
	TST.B	(A0)
	BEQ.S	PokCon1
	ADDQ	#1,A0
	ADDQ.W	#1,D0
	BRA.S	PokBuc1
PokCon1:
	LEA	BufTxt(PC),A1
	MOVE.L	#"0000",(A1)+
	MOVE.L	#"0000",(A1)+
	MOVE.W	#"00",(A1)+

PokBuc0:
	TST.B	(A0)
	BEQ.S	PokCon0
	CMP.B	#" ",(A0)
	BEQ.S	PokCon0
	MOVE.B	(A0),-(A1)
PokCon0:
	SUBQ	#1,A0
	DBF	D0,PokBuc0

	CMP.B	#"$",(A1)
	BEQ.S	EsHexade

	LEA	BufTxt(PC),A0
	BSR	PASHEX
	BRA	EsDecimal

	CNOP	0,4
EsHexade:
	MOVE.B	#"0",(A1)
	LEA	BufTxt+5(PC),A0

	MOVEQ	#0,D0
	MOVE.B	1(A0),D7
	BSR	Calcul
	MOVE.B	D7,D0
	MOVE.B	2(A0),D7
	BSR	Calcul
	MOVE.B	D7,D1
	MOVE.B	3(A0),D7
	BSR	Calcul
	MOVE.B	D7,D2
	MOVE.B	4(A0),D7
	BSR	Calcul
	MOVE.B	D7,D3
	BFINS	D0,D0{16:4}
	BFINS	D1,D0{20:4}
	BFINS	D2,D0{24:4}
	BFINS	D3,D0{28:4}
EsDecimal:
	RTS

Calcul:
	SUB.B	#"0",D7
	CMP.B	#10,D7
	BLT.S	CalcURet
	SUB.B	#"A"-"9"-1,D7
	CMP.B	#16,D7
	BLT.S	CalcURet
	SUB.B	#"a"-"F"-11,D7
CalcURet:RTS

Calcul2:
	CMP.B	#$A,D2
	BCS.S	NoEsNum
	ADD.B	#"A"-"9"-1,D2
NoEsNum:ADD.B	#"0",D2
	RTS

Calcul3:
	BFEXTU	D1{16:4},D2
	BSR	Calcul2
	MOVE.B	D2,(A2)+
	BFEXTU	D1{20:4},D2
	BSR	Calcul2
	MOVE.B	D2,(A2)+
	BFEXTU	D1{24:4},D2
	BSR	Calcul2
	MOVE.B	D2,(A2)+
	BFEXTU	D1{28:4},D2
	BSR	Calcul2
	MOVE.B	D2,(A2)+
	RTS

Calcul3b:
	BFEXTU	D1{24:4},D2
	BSR	Calcul2
	MOVE.B	D2,(A2)+
	BFEXTU	D1{28:4},D2
	BSR	Calcul2
	MOVE.B	D2,(A2)+
	RTS

BufTxt:	DS.B	14

; ------------------------------------------
; ******************************************
; ------------------------------------------

AskSaveBatt:
	TST.B	BattKbs(PC)
	BEQ.S	AskSaveBattRet

	TST.L	BucCart(PC)		; ¿Hay cartucho insertado?
	BEQ.S	AskSaveBattRet

	TST.B	DirPrefs+$0D(PC)
	BEQ.S	AskSaveBattRet

	BSR	CalChecksum
	CMP.L	CheckId,D2
	BEQ.S	AskSaveBattRet

	BSR	DisMouse
	MOVEM.L	MCeros(PC),D0-D7/A0-A6
	JSR	OpenAskSaveBattWindow

	LEA	AskSaveBattPunts,A1
	BSR	Control

	JSR	CloseAskSaveBattWindow
	BSR	EnaMouse
AskSaveBattRet:
	MOVEQ	#1,D0
	RTS

AskSaveBattSave:
	ADD.W	#16+4,SP
	JSR	CloseAskSaveBattWindow
	BSR	EnaMouse

	BSR	SaveBatt

	MOVEQ	#0,D0
	RTS

AskSaveBattCancel:
	ADD.W	#16+4,SP
	JSR	CloseAskSaveBattWindow
	BSR	EnaMouse
	MOVEQ	#-1,D0
	RTS

; ------------------------------------------
; ******************************************
; ------------------------------------------

AskSureReset:
	MOVE.L	#"Rese",ClearIText0+16
	MOVE.B	#"t",ClearIText0+20
	BRA.S	AskSure
AskSureEject:
	MOVE.L	#"Ejec",ClearIText0+16
	MOVE.B	#"t",ClearIText0+20
	BRA.S	AskSure
AskSureClear:
	MOVE.L	#"Clea",ClearIText0+16
	MOVE.B	#"r",ClearIText0+20
AskSure:
	BSR	DisMouse
	MOVEM.L	MCeros(PC),D0-D7/A0-A6
	JSR	OpenClearWindow

	LEA	ClearPunts,A1
	BSR	Control

	CLR.L	-(SP)		; Yes
	BRA.S	AskSureCon
AskSureNo:
	ADD.W	#16+4,SP
	MOVEQ	#-1,D0
	MOVE.L	D0,-(SP)	; No
AskSureCon:
	JSR	CloseClearWindow
	BSR	EnaMouse
	MOVE.L	(SP)+,D0
	RTS

; ------------------------------------------
; ******************************************
; ------------------------------------------


; ------------------------------------------
; ------------------------------------------
; ------------------------------------------


; ------------------------------------------
; ******************************************
; ------------------------------------------

	CNOP	0,8
Continue:
	MOVEQ	#-1,D7
	BRA.S	ContinueCon
	CNOP	0,8
PowerON:
	MOVEQ	#00,D7
ContinueCon:
	LEA	tErNoCartucho(PC),A0
	TST.L	BucCart(PC)
	BEQ	ImpError

	MOVEM.L	D0-D7/A0-A6,-(SP)
	BSR	ActuPrefs
	MOVEM.L	(SP)+,D0-D7/A0-A6

	TST.L	D7			; ¿Es Power ON?
	BNE.S	NoLoRefres
	MOVE.B	DirPrefs+$0E(PC),DisCheaDat	; Refresca Disable Cheats.
NoLoRefres:
; -=-=-
	LEA	DirPrefs(PC),A5
; -=-=-
	TST.B	GoDat(PC)		; ¿Encendido por primera vez?
	BEQ.S	NoReset
	TST.L	D7			; ¿Es Power ON?
	BNE.S	NoReset
	TST.B	$0A(A5)			; ¿Hacer Reset?
	BEQ.S	NoReset
	MOVEM.L	D7/A5,-(SP)
	BSR	AskSureReset
	MOVEM.L	(SP)+,D7/A5
	TST.L	D0
	BEQ.S	NoReset
	RTS
NoReset:
; -=-=-
	MOVEQ	#0,D1
	TST.B	$0F(A5)			; Frecuencia pantalla.
	BNE.S	NoEsNTSC
	MOVE.W	#$20,D1
NoEsNTSC:MOVE.W	D1,$DFF1DC
; -=-=-
	ST	GoDat
; -=-=-
	IFD	GB_Menu
	JSR	GameBoyEmul
	ENDC
; -=-=-
	BSR	RefrescaReloj
; -=-=-
	LEA	MainMenuGadgets+(GD_Continue*4),A0
	MOVE.L	MainMenuWnd,A1
	MOVEQ	#0,D0
	BSR	GadsOnOff

	RTS

; ------------------------------------------
; ******************************************
; ------------------------------------------

	CNOP	0,8
Eject:
	TST.L	BucCart(PC)
	BEQ	EjNoHayCart

	BSR	AskSureEject
	BEQ.S	EjectSi
	RTS
EjectSi:
	MOVE.L	BucCart(PC),D0
	MOVE.L	DirCart(PC),A1
	MOVE.L	$4.W,A6
	JSR	-$D2(A6)		; Libera memoria.
	CLR.L	BucCart
	CLR.L	DirCart


	MOVE.L	#MainMenuIText12,MainMenuText12+$C	; No Cart Inserted.
	MOVE.L	#tTipoVer,MainMenuText14+$C
	MOVE.L	#tTipoCart,MainMenuText15+$C
	MOVE.L	#tTipoROM,MainMenuText16+$C
	MOVE.L	#tTipoRAM,MainMenuText17+$C
	MOVE.L	#MainMenuIText18,MainMenuText18+$C

	LEA	tManufNoID(PC),A0
	LEA	MainMenuIText13,A1
	BSR	PONOM

	MOVE.L	InsReqBase,A2
	MOVE.L	4(A2),A0
	LEA	tNomFileCart,A1
	BSR	PONOM
	move.l  _IntuitionBase,a6
	move.l  MainMenuWnd,a0
	move.b  54(a0),d0
	ext.w   d0
	move.b  55(a0),d1
	ext.w   d1
	move.l  50(a0),a0
	lea	MainMenuText12,a1
	jsr     PrintIText(a6)
EjNoHayCart:

	LEA	MainMenuGadgets+(GD_Continue*4),A0
	MOVE.L	MainMenuWnd,A1
	MOVEQ	#1,D0
	BSR	GadsOnOff

	RTS

; ------------------------------------------

	CNOP	0,8
Insert:
	TST.L	_AslBase(PC)
	BEQ	NeedASL

	BSR	ActuPrefs

	TST.B	DirPrefs+$0C(PC)
	BNE.S	SiSaveBatt2
	BSR	AskSaveBatt
	BMI	MenuRET
	BRA.S	NoSaveBatt2
SiSaveBatt2:
	BSR	SaveBatt
NoSaveBatt2:

	BSR	DisMouse

	MOVE.L	InsReqBase,A0
	IFD	HY_ASLPAT
	LEA	HyInsTags,A1		; hybrid: cartridges and drawers only (hybrid/menu.s)
	ELSE
	LEA	InsLoadTags,A1
	ENDC
	MOVE.L	_AslBase,A6
	IFD	HY_MENU
	MOVE.L	HyAutoReq,D0		; hybrid: file named at start, no requester
	BNE.S	HyAutoIns
	ENDC
	JSR	-$3C(A6)	; RequestFile.
	IFD	HY_MENU
HyAutoIns:
	ENDC

	TST.L	D0
	BEQ	ReqCancel


	MOVE.L	InsReqBase,A2
	BSR	ArreglaNom


;	--------------------
	TST.L	_XpkBase(PC)		; Mira si es un xpk.
	BEQ.S	NoXpkFile

	LEA	XpkFibBase,A0		; ¿Fichero xpk?
	LEA	xpkTags0(PC),A1
	MOVE.L	_XpkBase,A6
	JSR	-54(A6)		; xpkOpen
	BNE.S	NoXpkFile

	MOVE.L	XpkFibBase,A0		; ¿Comprimido con xpk?
	CMP.L	#1,(A0)
	BNE.S	NoXpkFile

	MOVE.L	4(A0),-(SP)

	MOVE.L	XpkFibBase,A0
	MOVE.L	_XpkBase,A6
	JSR	-78(A6)		; xpkClose

	MOVE.L	(SP)+,D0
	MOVE.L	D0,BucFile
	BSR	MiraCartSize
	BEQ.S	NoXpkFile

	MOVE.B	#$7F,Comprimido
	BRA.S	EsXpkFile
NoXpkFile:

;	--------------------
	MOVE.L	#FileNom,D1		; Open File
	MOVE.L	#$3ED,D2
	BSR	OpenFile
	BEQ	OpenError

	BSR	LongFile		; Mira Size.
	MOVE.L	D0,BucFile
	BEQ	ReadError

	MOVE.L	#(4*4),D3
	MOVE.L	#CabFileBuf,D2
	BSR	ReadFile
	BNE	ReadError

	CMP.W	#"S4",CabFileBuf
	BNE.S	NoStcComp
	MOVE.L	CabFileBuf+$08(PC),D0
	BSR	MiraCartSize
	BEQ.S	NoStcComp

	TST.L	_StcBase(PC)
	BEQ	ErNoStc

	ST	Comprimido
	BRA.S	SiStcComp
NoStcComp:

;	--------------------
	MOVE.L	BucFile(PC),D0
	BSR	MiraCartSize
	BEQ	NoGBCart
	SF	Comprimido
SiStcComp:
EsXpkFile:
	MOVE.W	D0,PagCart
	MULU	#$4080,D0
	ADD.L	#$80,D0
	MOVE.L	D0,-(SP)

	MOVE.L	BucCart(PC),D0
	BEQ.S	NoHayCart
	MOVE.L	DirCart(PC),A1
	MOVE.L	$4.W,A6
	JSR	-$D2(A6)		; Libera memoria.
	CLR.L	BucCart
NoHayCart:
	MOVE.L	(SP)+,BucCart

	MOVE.L	#$00010001,D1
	MOVE.L	BucCart,D0
	MOVE.L	4.W,A6
	JSR	-$C6(A6)		; Requiere memoria.
	MOVE.L	D0,DirCart
	BEQ	OutOfMem

;	--------------------

	CMP.B	#$7F,Comprimido
	BNE.S	NoDescomXpk

	LEA	xpkTags1(PC),A0
	MOVE.L	DirCart(PC),$0C(A0)
	ADD.L	#$80,$0C(A0)
	MOVE.L	BucCart(PC),$14(A0)	; tendria que ser BucFile
	MOVE.L	_XpkBase,A6
	JSR	-48(A6)		; xpkUnPack
;;	B??  error

	BRA.S	NoCompri0
NoDescomXpk:

;	--------------------
	LEA	CabFileBuf(PC),A1
	MOVE.L	DirCart,A0
	TST.B	Comprimido(PC)
	BNE.S	SiCompri0
	ADD.W	#$80,A0
SiCompri0:
	MOVE.L	(A1)+,(A0)+
	MOVE.L	(A1)+,(A0)+
	MOVE.L	(A1)+,(A0)+
	MOVE.L	(A1)+,(A0)+
	MOVE.L	A0,D2
	MOVE.L	BucFile(PC),D3
	SUB.L	#(4*4),D3
	BSR	ReadFile
	BNE	ReadError

	BSR	CloseFile
; -=-=-

	TST.B	Comprimido(PC)
	BEQ.S	NoCompri0

;	--------------------
	MOVE.L	DirCart,A1
	LEA	$80(A1),A0
	MOVE.L	_StcBase,A6
	JSR	-$24(A6)
	MOVE.L	DirCart,A0
	MOVE.W	#($80/4)-1,D0
DesStcBuc:
	CLR.L	(A0)+
	DBF	D0,DesStcBuc
	MOVE.L	CabFileBuf+$08,BucFile
NoCompri0:
; -=-=-
	TST.B	RawCartSize(PC)		; Para soportar el skip 512 bytes.
	BEQ.S	SiRawCartSize
	MOVE.L	DirCart,A0
	ADD.W	#$80,A0
	MOVE.L	BucFile,D0
	SUB.L	#$200,D0
BucRawCartSize:
	MOVE.B	$200(A0),(A0)+
	SUBQ.L	#1,D0
	BNE.S	BucRawCartSize
SiRawCartSize:
; -=-=-
	IFND	HY_MENU		; hybrid: carts start with any jump (JR, DI: JP, JP)
	MOVE.L	DirCart,A0		;;	Mirar ID
	CMP.W	#$00C3,$80+$100(A0)
	BEQ.S	IDCorrecta
	LEA	tErIDNoCorrecto,A0
	BSR	ImpError
IDCorrecta:
	ENDC
; -=-=-
	MOVE.L	DirCart,A0
	ADD.W	#$80,A0
	MOVE.W	PagCart,D0
	MULU	#$4000,D0
	MOVE.W	$14E(A0),D3
	CLR.W	$14E(A0)
	MOVEQ	#0,D1
	MOVEQ	#0,D2
ChecksumBuc:
	MOVE.B	(A0)+,D1
	ADD.W	D1,D2
	SUBQ.L	#1,D0
	BNE.S	ChecksumBuc
	MOVE.W	D3,$14E(A0)
	IFD	HY_MENU		; hybrid: a wrong global checksum ($14E) no longer stops the
	IFND	NO_CKWARN	; cartridge with a requester (a Game Boy never checks it;
HY_CKQUIET	SET	1	; homebrew often leaves it wrong). NO_CKWARN = Juan's requester.
	ENDC
	ENDC
	IFND	HY_CKQUIET
	CMP.W	D2,D3
	BEQ.S	ChecksumBien
	LEA	tErChecksum,A0
	BSR	ImpError
ChecksumBien:
	ENDC
; -=-=-
	MOVE.L	DirCart,A0
	ADD.W	#$80,A0
	MOVE.W	PagCart,D0
	MOVE.W	D0,D1
	MULU	#$4080,D1
	LEA	(A0,D1.L),A1
	MOVE.W	D0,D1
	MULU	#$4000,D1
	LEA	(A0,D1.L),A0
	SUBQ.W	#1,D0
ArrROMPagBuc0:
	MOVEQ	#($80/4)-1,D1
ArrROMPagBuc1:
	CLR.L	-(A1)
	DBF	D1,ArrROMPagBuc1
	MOVE.W	#($4000/4)-1,D1
ArrROMPagBuc2:
	MOVE.L	-(A0),-(A1)
	DBF	D1,ArrROMPagBuc2
	DBF	D0,ArrROMPagBuc0

; -=-=-=-

	MOVE.L	DirCart(PC),A0
	LEA	$80+$134(A0),A1
	LEA	tNomCart,A2
	MOVEQ	#(16)-1,D0
InsBucNom:
	MOVE.B	(A1)+,(A2)+
	BNE.S	InsConNom
	MOVE.B	#" ",-1(A2)
InsConNom:
	DBF	D0,InsBucNom

	MOVE.W	$80+$14B(A0),D1
	ROR.W	#8,D1
	LEA	tManufNoID(PC),A0
	LEA	Manufact(PC),A1
ManufBuc0:
	MOVE.W	(A1)+,D0
	BEQ.S	ManufFin
	CMP.B	D0,D1				; *-*-*-* Es en .W *-*-*-*-*
	BNE.S	ManufBuc
	MOVE.L	A1,A0
	BRA.S	ManufFin
ManufBuc:
	TST.B	(A1)+
	BNE.S	ManufBuc
	BRA.S	ManufBuc0
ManufFin:
	LEA	MainMenuIText13,A1
	BSR	PONOM

	MOVE.L	DirCart(PC),A0
	MOVE.L	$80+$146(A0),D0
	AND.L	#$00070703,D0
	MOVEQ	#0,D1
	MOVE.B	D0,D1
	MOVE.B	D1,BattKbs
	IFD	HY_MENU
	IFND	NO_MBC2SAVE
	JSR	HyBattKbs		; hybrid: MBC2 keeps its RAM in the mapper ($149 = 0)
	ENDC
	ENDC
	MOVE.L	(TipoRAM.W,PC,D1.W*4),MainMenuText17+$C
	LSR.L	#8,D0
	MOVE.B	D0,D1
	MOVE.L	(TipoROM.W,PC,D1.W*4),MainMenuText16+$C
	LSR.W	#8,D0
	MOVE.B	D0,D1
	MOVE.L	(TipoCart.W,PC,D1.W*4),MainMenuText15+$C

	MOVE.B	$80+$14A(A0),D0
	AND.B	#$0F,D0
	ADD.B	#"0",D0
	MOVE.B	D0,tTipoVer0+1
	MOVE.L	#tTipoVer0,MainMenuText14+$C

	MOVE.L	#tNomCart,MainMenuText12+$C
	MOVE.L	#tNomFileCart,MainMenuText18+$C

; -=-=-=-

	BSR	MiraTipoCart

; -=-=-
	LEA	ERAM0,A0
	MOVE.W	#(((1024*32)+$200)/4)-1,D0
BorraSRAM:CLR.L	(A0)+
	DBF	D0,BorraSRAM
; -=-=-=-
	TST.B	DirPrefs+$0B(PC)
	BEQ.S	NoLeeBatt
	BSR	ReadBatt
NoLeeBatt:

	BSR	CalChecksum
	MOVE.L	D2,CheckId		; Guarda Check-Sum.

; -=-=-=-

	MOVE.L	InsReqBase,A2
	MOVE.L	4(A2),A0
	LEA	tNomFileCart,A1
	BSR	PONOM

	move.l  _IntuitionBase,a6
	move.l  MainMenuWnd,a0
	move.b  54(a0),d0
	ext.w   d0
	move.b  55(a0),d1
	ext.w   d1
	move.l  50(a0),a0
	lea	MainMenuText12,a1
	jsr     PrintIText(a6)

	LEA	MainMenuGadgets+(GD_Continue*4),A0
	MOVE.L	MainMenuWnd,A1
	MOVEQ	#1,D0
	BSR	GadsOnOff

	BSR	EnaMouse
	RTS

; ------------------------------------------

MiraTipoCart:
	MOVE.L	InsReqBase,A0
	MOVE.L	4(A0),A0
	BSR	BuscaExt

	LEA	FileNom(PC),A0
	LEA	FileNomSav(PC),A1
	LEA	FileNomFro(PC),A2
	MOVE.W	#$200,D0
SavBuc0:
	MOVE.B	(A0),(A1)+
	MOVE.B	(A0)+,(A2)+
	BEQ.S	SavCon0
	DBF	D0,SavBuc0
	MOVE.L	#"Mal"*256,FileNomSav
	MOVE.L	#"Mal"*256,FileNomFro
	RTS
SavCon0:
	MOVE.W	BucPunto,D0
	SUB.W	D0,A1
	MOVE.L	#".sav",(A1)+
	CLR.B	(A1)
	SUB.W	D0,A2
	MOVE.L	#".Fro",(A2)+
	MOVE.L	#"zen"*256,(A2)+
	SUBQ	#1,A2

	MOVE.W	#40-1,D0
SavBuc1:
	TST.B	-1(A1)
	BEQ.S	SavCon1
	CMP.B	#"/",-1(A1)
	BEQ.S	SavCon1
	CMP.B	#":",-1(A1)
	BEQ.S	SavCon1
	SUBQ	#1,A1
	DBF	D0,SavBuc1
	RTS
SavCon1:
	MOVE.L	A1,A0
	LEA	FileNomSav2,A1
	MOVE.W	#50-1,D0
	BSR	CopyNom

	MOVE.W	#40-1,D0
SavBuc2:
	TST.B	-1(A2)
	BEQ.S	SavCon2
	CMP.B	#"/",-1(A2)
	BEQ.S	SavCon2
	CMP.B	#":",-1(A2)
	BEQ.S	SavCon2
	SUBQ	#1,A2
	DBF	D0,SavBuc2
	RTS
SavCon2:
	MOVE.L	A2,A0
	LEA	FileNomFro2,A1
	MOVE.W	#50-1,D0
	BSR	CopyNom

	RTS

; -----------------------------------

BuscaExt:
	LEA	MiTiNom+8(PC),A1
	MOVEQ	#0,D0
MiTiBuc0:
	TST.B	(A0)+
	BEQ.S	MiTiCon0
	ADDQ.W	#1,D0
	BRA.S	MiTiBuc0
MiTiCon0:
	MOVEQ	#0,D3
	MOVE.W	#1,BucPunto
	LEA	(A1,D0.W),A1
MiTiBuc1:
	ADDQ.W	#1,D3
	MOVE.B	-(A0),-(A1)
	CMP.B	#".",(A1)
	BEQ.S	MiTiPunto
	CMP.B	#$60,(A1)
	BCS.S	MiTiCon1
	SUB.B	#$20,(A1)
MiTiCon1:
	DBF	D0,MiTiBuc1
	MOVEQ	#-1,D0
	RTS
MiTiPunto:
	MOVE.L	(A1),D1
	AND.L	#$FFFFFF00,D1
	CMP.L	#".GB"*256,D1		; Game Boy
	BEQ.S	MiTiFin
	DBF	D0,MiTiBuc1
	MOVEQ	#-1,D0
	RTS
MiTiFin:
	MOVE.W	D3,BucPunto
	MOVEQ	#0,D0
	RTS

	CNOP	0,4
MiTiNom:DS.B	8+64
	CNOP	0,4

; -----------------------------------

MiraCartSize:
	SF	RawCartSize
	BFTST	D0{17:15}		; mira mínimo 32Kb
	BEQ.S	SiOkCartCon
	SUB.L	#$200,D0
	ST	RawCartSize
	BFTST	D0{17:15}		; mira mínimo 32Kb
	BNE.S	NoOkCartCon
SiOkCartCon:
	LSR.L	#8,D0
	LSR.L	#6,D0
	IFD	HY_MENU
	CMP.L	#$80,D0			; hybrid: up to 2 MB (Pokemon, Wario Land II)
	ELSE
	CMP.L	#$20,D0			; mira máximo 2Mb
	ENDC
	BGT.S	NoOkCartCon
	MOVEQ	#-1,D1
	RTS
NoOkCartCon:
	MOVEQ	#0,D1
	RTS

ReqCancel:
	BSR	EnaMouse
	RTS

ErNoStc:
	BSR	CloseFile
	LEA	tErNoStc,A0
	BRA	ImpError
OpenError:
	LEA	tErOpenFile,A0
	BRA	ImpError
ReadError:
	BSR	CloseFile
	LEA	tErReadFile,A0
	BRA	ImpError
NoGBCart:
	BSR	CloseFile
	LEA	tErNoGBCart,A0
	BRA	ImpError
OutOfMem:
	CLR.L	BucCart
	BSR	CloseFile
	LEA	tErOutOfMem,A0
	BRA	ImpError


	CNOP	0,8
xpkTags0:
	DC.L	$80005851,FileNom	; Nombre del Fichero a abrir.
	DC.L	0

xpkTags1:
	DC.L	$80005851,FileNom	; Nombre del Fichero a abrir.
	DC.L	$80005862,0
	DC.L	$80005871,0
	DC.L	0

;	DC.L	$80005851,Nombre del Fichero a abrir.
;	DC.L	$80005852,FileHandle (retorno del dosOpen) lectura.
;	DC.L	$80005853,Bloque de memoría donde leer.
;	DC.L	$80005860,Nombre del Fichero a crear/reescribir.
;	DC.L	$80005861,FileHandle (retorno del dosOpen) escritura.
;	DC.L	$80005862,Bloque de memoría donde escribir.
;	DC.L	$80005870,Size del bufer donde leer.
;	DC.L	$80005871,Size del bufer donde escribir.
;	DC.L	$80005877,=1 Soportar leer ficheros no xpkeados!

; ------------------------------------------

	CNOP	0,8
TipoROM:
	DC.L	tTipoROM0
	DC.L	tTipoROM1
	DC.L	tTipoROM2
	DC.L	tTipoROM3
	DC.L	tTipoROM4
	DC.L	tTipoROM5
	DC.L	tTipoROM5
	DC.L	tTipoROM5
TipoRAM:
	DC.L	tTipoRAM0
	DC.L	tTipoRAM1
	DC.L	tTipoRAM2
	DC.L	tTipoRAM3
TipoCart:
	DC.L	tTipoCart0
	DC.L	tTipoCart1
	DC.L	tTipoCart2
	DC.L	tTipoCart3
	DC.L	tTipoCart4
	DC.L	tTipoCart5
	DC.L	tTipoCart6
	DC.L	tTipoCart7

tTipoVer:	DC.B	"--",0
tTipoVer0:	DC.B	"v0",0

tTipoROM:	DC.B	"-----",0
tTipoROM0:	DC.B	" 32Kb",0
tTipoROM1:	DC.B	" 64Kb",0
tTipoROM2:	DC.B	"128Kb",0
tTipoROM3:	DC.B	"256Kb",0
tTipoROM4:	DC.B	"512Kb",0
tTipoROM5:	DC.B	"?????",0

tTipoRAM:	DC.B	"----",0,0
tTipoRAM0:	DC.B	"None",0,0
tTipoRAM1:	DC.B	" 2Kb",0,0
tTipoRAM2:	DC.B	" 8Kb",0,0
tTipoRAM3:	DC.B	"32Kb",0,0

tTipoCart:	DC.B	"---------------",0
tTipoCart0:	DC.B	"ROM Only.      ",0
tTipoCart1:	DC.B	"ROM+MBC1.      ",0
tTipoCart2:	DC.B	"ROM+MBC1+RAM.  ",0
tTipoCart3:	DC.B	"MBC1+RAM+Batt. ",0
tTipoCart4:	DC.B	" ¡¡¡Unknown!!! ",0
tTipoCart5:	DC.B	"ROM+MBC2.      ",0
tTipoCart6:	DC.B	"ROM+MBC2+Batt. ",0
tTipoCart7:	DC.B	"???????????????",0

tNomCart:	DC.B	"----------------",0
tManufNoID:	DC.B	"---------------",0
tNomFileCart:	DC.B    'No Cartridge Inserted!           ',0,0,0

	CNOP	0,4

; ------------------------------------------
; ****************************************** Batt
; ------------------------------------------

ReadBatt:
	TST.B	BattKbs(PC)
	BNE.S	ReadBattRut0
	RTS
ReadBattRut0:
	TST.L	BucCart(PC)
	BNE.S	ReadBattRut
	RTS
ReadBattRut:
	MOVE.L	#FileNomSav,D1
	MOVE.L	#$3ED,D2
	BSR	OpenFile
	BEQ	OpenBattError

	MOVE.L	#ERAM0,D2
	MOVE.L	#(2*1024),D3
	BSR	ReadFile

	CMP.B	#1,BattKbs
	BEQ.S	ReadBattCon

	MOVE.L	#ERAM0+(2*1024),D2
	MOVE.L	#(6*1024),D3
	BSR	ReadFile

	CMP.B	#2,BattKbs
	BEQ.S	ReadBattCon

	MOVE.L	#ERAM1,D2
	MOVE.L	#(8*1024),D3
	BSR	ReadFile

	MOVE.L	#ERAM2,D2
	MOVE.L	#(8*1024),D3
	BSR	ReadFile

	MOVE.L	#ERAM3,D2
	MOVE.L	#(8*1024),D3
	BSR	ReadFile
ReadBattCon:
	BSR	CloseFile
OpenBattError:

	BSR	CalChecksum
	MOVE.L	D2,CheckId		; Guarda Check-Sum.
	RTS

; ------------------------------------------

SaveBatt:
	TST.B	BattKbs(PC)
	BNE.S	SaveBattRut1
	RTS
SaveBattRut1:
	TST.L	BucCart(PC)		; ¿Hay cartucho insertado?
	BNE.S	SaveBattRut
	RTS
SaveBattRut:
	MOVE.L	CheckId,D7		; ¿Ha cambiado el Checksum?
	BSR	CalChecksum
	MOVE.L	D2,CheckId		; Guarda Check-Sum.
	CMP.L	D2,D7
	BNE.S	SaveBattRut0
	RTS
SaveBattRut0:
	MOVE.L	#FileNomSav,D1
	MOVE.L	#$3EE,D2
	BSR	OpenFile
	BEQ	OpenBattError

	MOVE.L	#ERAM0,D2
	MOVE.L	#(2*1024),D3
	BSR	WriteFile

	CMP.B	#1,BattKbs
	BEQ.S	SaveBattCon

	MOVE.L	#ERAM0+(2*1024),D2
	MOVE.L	#(6*1024),D3
	BSR	WriteFile

	CMP.B	#2,BattKbs
	BEQ.S	SaveBattCon

	MOVE.L	#ERAM1,D2
	MOVE.L	#(8*1024),D3
	BSR	WriteFile

	MOVE.L	#ERAM2,D2
	MOVE.L	#(8*1024),D3
	BSR	WriteFile

	MOVE.L	#ERAM3,D2
	MOVE.L	#(8*1024),D3
	BSR	WriteFile
SaveBattCon:
	BSR	CloseFile
	RTS

; ------------------------------------------

ClearBatt:
	TST.L	BucCart(PC)		; ¿Hay cartucho insertado?
	BEQ.S	NoClearBatt

	BSR	AskSureClear
	BNE.S	NoClearBatt

	LEA	ERAM0,A0
	MOVE.W	#($8180/8)-1,D0
ClrBatBuc:
	CLR.L	(A0)+
	CLR.L	(A0)+
	DBF	D0,ClrBatBuc

	BSR	CalChecksum
	MOVE.L	D2,CheckId		; Guarda Check-Sum.

NoClearBatt:
	RTS

; ------------------------------------------

CalChecksum:				; Resultado: Check-Sum en D2
	LEA	ERAM0,A0
	MOVE.W	#($8180/2)-1,D0
	MOVEQ	#0,D1
	MOVEQ	#0,D2
CaChCaBuc:
	MOVE.W	(A0)+,D1
	ADD.L	D1,D2
	DBF	D0,CaChCaBuc
	RTS

; ------------------------------------------
; ******************************************
; ------------------------------------------

	CNOP	0,8
ImpJoyType:
	MOVE.B	([MainMenuGadgets+(GD_JoyType*4)],$57.w),D0	; JoyType
	AND.W	#$0003,D0
	MOVE.L	(TabGfxJoyType.w,PC,D0.w*4),DirJoyTypePic

	MOVE.L	#552,D0
	MOVE.L	#143,D1
	move.l  Scr,a0
	move.l  40(a0),a1
	ADD.w  4(a1),D1
	MOVE.L	MainMenuWnd,A0
	MOVE.L	50(A0),A0
	LEA	DatsJoyTypePic,A1
	MOVE.L	_IntuitionBase,A6
	JMP	-114(A6)
	CNOP	0,4
TabGfxJoyType:
	DC.L	GBJoyStick
	DC.L	GBTeclado
	DC.L	GBCD32
	DC.L	GBJoypad

; ------------------------------------------
; ******************************************
; ------------------------------------------

NoChange:
	MOVEQ	#$01,D3
	MOVE.B	D3,DirPrefs+$18
	BRA.S	SetScrExit
ForcePAL:
	MOVEQ	#$02,D3
	MOVE.B	D3,DirPrefs+$18
	BRA.S	SetScrExit
ForceNTSC:
	MOVEQ	#$04,D3
	MOVE.B	D3,DirPrefs+$18
SetScrExit:
	MOVE.L	#(0*$40)+12,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#2,D1			; Nº menu.
	MOVEQ	#3-1,D4

	BRA.S	PoneOptMenus
	
; -----------------------------------

SoundMode:
	BSR	DisMouse
	MOVEM.L	MCeros,D0-D7/A0-A6
	JSR	OpenEditSoundWindow

	LEA	SoundPunts,A1
	BSR	Control

	JSR	CloseEditSoundWindow
	BSR	EnaMouse
	RTS

; -----------------------------------

EditJoyMode:
	BSR	DisMouse
	MOVEM.L	MCeros,D0-D7/A0-A6
	JSR	OpenEditJoyWindow

	LEA	EditJoyPunts,A1
	BSR	Control

	JSR	CloseEditJoyWindow
	BSR	EnaMouse
	RTS

; -----------------------------------

PoneOptMenus:
;;	MOVEQ	#$40,D3			; D3 = Bits a 0 = OFF, bit a 1 = ON
;;	MOVE.L	#(0*$40)+1,D0		; D0 = Nº Línea. (Sub-Item+Item)
;;	MOVEQ	#3,D1			; D1 = Nº menu.
;;	MOVEQ	#7-1,D4			; D4 = Nº de Líneas en Menú
PoOpMeBuc:
	MOVEM.L	D0-D4,-(SP)
	BSR	CogeCheck
	MOVEM.L	(SP)+,D0-D4

	BCLR	#0,$C(A0)
	LSR.B	#1,D3
	BCC.S	PoOpMeCon
	BSET	#0,$C(A0)
PoOpMeCon:
	ADD.W	#(1*$40),D0
	DBF	D4,PoOpMeBuc
	RTS

; ------------------------------------------
; ******************************************
; ------------------------------------------

ActuPrefs:
	LEA	DirPrefs(PC),A5

	LEA	MainMenuPunts,A0

	MOVE.W	#GD_JoyType,D1
	MOVEQ	#0,D0
	BSR	GetGadgetValue
	MOVE.B	D0,$08(A5)	; JoyType

	MOVE.W	#GD_LCDFade,D1
	MOVEQ	#0,D0
	BSR	GetGadgetValue
	MOVE.B	D0,$11(A5)	; LCD Fade

	MOVE.W	#GD_ScrMode,D1
	MOVEQ	#0,D0
	BSR	GetGadgetValue
	MOVE.B	D0,$0F(A5)	; Screen


	MOVE.L	InsReqBase(PC),A0
	MOVE.L	8(A0),A0
	LEA	$20(A5),A1
	MOVE.W	#($100/8)-1,D0
ActPreBuc0:
	MOVE.L	(A0)+,(A1)+
	MOVE.L	(A0)+,(A1)+
	DBF	D0,ActPreBuc0

	MOVEQ	#2,D1		; Nº menu.
	MOVEQ	#0,D0		; Nº Línea.
	BSR	CogeCheck
	SNE	$09(A5)				; Black Border

	MOVEQ	#2,D1		; Nº menu.
	MOVEQ	#1,D0		; Nº Línea.
	BSR	CogeCheck
	SNE	$14(A5)				; No illogical moves

	MOVEQ	#2,D1		; Nº menu.
	MOVEQ	#3,D0		; Nº Línea.
	BSR	CogeCheck
	SNE	$0B(A5)				; Auto Load Batt.

	MOVEQ	#2,D1		; Nº menu.
	MOVEQ	#4,D0		; Nº Línea.
	BSR	CogeCheck
	SNE	$0C(A5)				; Auto Save Batt.

	MOVEQ	#2,D1		; Nº menu.
	MOVEQ	#5,D0		; Nº Línea.
	BSR	CogeCheck
	SNE	$0D(A5)				; Ask for Save Battery

	MOVEQ	#2,D1		; Nº menu.
	MOVEQ	#14,D0		; Nº Línea.
	BSR	CogeCheck
	SNE	$0E(A5)				; Disable Cheats

	MOVEQ	#2,D1		; Nº menu.
	MOVEQ	#15,D0		; Nº Línea.
	BSR	CogeCheck
	SNE	$0A(A5)				; Ask for Reset

	RTS



; -----------------------------------

CogeCheck:
	MOVE.L	MainMenuMenus,A0
	MOVE.L	_IntuitionBase(PC),A6
	LSL.W	#5,D0	
	OR.W	D1,D0
	JSR	-$90(A6)		; ItemAdress (A0,d0)
	MOVE.L	D0,A0
	BTST	#0,$C(A0)
	RTS

; -----------------------------------

PonPrefs:
	LEA	DirPrefs(PC),A5

	LEA	MainMenuPunts,A0
	LEA	MainMenuGTags,A1
	MOVE.W	#GD_JoyType,D0
	MOVE.L	#$8008000F,D1
	MOVEQ	#0,D2
	MOVE.B	$08(A5),D2
	BSR	OverrideTag

	LEA	MainMenuPunts,A0
	LEA	MainMenuGTags,A1
	MOVE.W	#GD_LCDFade,D0
	MOVE.L	#$8008000F,D1
	MOVEQ	#0,D2
	MOVE.B	$11(A5),D2
	BSR	OverrideTag

	LEA	MainMenuPunts,A0
	LEA	MainMenuGTags,A1
	MOVE.W	#GD_ScrMode,D0
	MOVE.L	#$8008000F,D1
	MOVEQ	#0,D2
	MOVE.B	$0F(A5),D2
	BSR	OverrideTag

	MOVE.B	$09(A5),D0
	BFINS	D0,MainMenuNewMenu35+10{7:1}	; Black Border.

	MOVE.B	$14(A5),D0
	BFINS	D0,MainMenuNewMenu36+10{7:1}	; No illogical moves

	MOVE.B	$0B(A5),D0
	BFINS	D0,MainMenuNewMenu38+10{7:1}	; Auto Load Batt

	MOVE.B	$0C(A5),D0
	BFINS	D0,MainMenuNewMenu39+10{7:1}	; Auto Save Batt

	MOVE.B	$0D(A5),D0
	BFINS	D0,MainMenuNewMenu40+10{7:1}	; Ask for Save Battery

	MOVE.B	$0E(A5),D0
	BFINS	D0,MainMenuNewMenu62+10{7:1}	; Disable Cheats

	MOVE.B	$0A(A5),D0
	BFINS	D0,MainMenuNewMenu63+10{7:1}	; Ask for Reset

; -=-
	MOVE.B	$18(A5),D0
	BFINS	D0,MainMenuNewMenu58+10{7:1}	; Set Screen on Exit 'No Change'
	LSR.B	#1,D0
	BFINS	D0,MainMenuNewMenu59+10{7:1}	; Set Screen on Exit 'Force PAL'
	LSR.B	#1,D0
	BFINS	D0,MainMenuNewMenu60+10{7:1}	; Set Screen on Exit 'Force NTSC'
; -=-
	RTS

; -----------------------------------

LoadPrefs:
	MOVE.L	#NOMPREFS,D1
	MOVE.L	#1005,D2
	BSR	OpenFile
	BEQ.S	PREFSRET

	MOVE.L	#BufPrefs,D2
	MOVE.L	#BucPrefs,D3
	BSR	ReadFile
;	BNE	CloseFile

	BSR	CloseFile
	LEA	BufPrefs,A0
	CMP.L	#"AmiG",(A0)
	BNE.S	PREFSRET
	CMP.L	#"Bv09",4(A0)
	BEQ.S	PREFSOK
PREFSRET:
	RTS

	CNOP	0,4
PREFSOK:
	MOVE.L	#"Bv09",4(A0)
	LEA	DirPrefs,A1
	MOVE.W	#BucPrefs-1,D0
COPIPREFS:
	MOVE.B	(A0)+,(A1)+
	DBF	D0,COPIPREFS
	RTS


SavePrefs:
	BSR	ActuPrefs

	MOVE.L	#NOMPREFS,D1
	MOVE.L	#1006,D2
	BSR	OpenFile
	BEQ.S	ERDEVICE2

	MOVE.L	#DirPrefs,D2
	MOVE.L	#BucPrefs,D3
	BSR	WriteFile
	BNE.S	ERDEVICE2

	BSR	CloseFile
	RTS

	CNOP	0,4
ERDEVICE2:
	BSR	CloseFile
	LEA	tErSavePrefs(PC),A0
	BRA	ImpError
	RTS

	CNOP	0,8
NOMPREFS:
	DC.B	"S:AmiGameBoy.prefs",0,0,0,0

; -=-=-=-==-=-=-=-==-=-=-=-=-=-=-=-=-=-=-=-=-=-
	CNOP	0,8
DirPrefs:
	DC.B	"AmiGBv09"	; $00 - ID
	DC.B	$01		; $08 - JoyType
	DC.B	$FF		; $09 - Black Border
	DC.B	$00		; $0A - Ask for Reset
	DC.B	$FF		; $0B - Auto-load Battery
	DC.B	$00		; $0C - Auto-save Battery
	DC.B	$FF		; $0D - Ask for Save Battery
	DC.B	$00		; $0E - Disable Cheats
	DC.B	$00		; $0F - Screen mode
	DC.B	$00		; $10 - Inter
	DC.B	$00		; $11 - LCD Fade
	DC.W	$00		; $12 - Emulation Speed
	DC.B	$00		; $14 - No illogical moves

	DC.B	$00		; $15 - Modo AntiCrack 2.

	DC.B	$00		; $16 - 

	DC.B	$00		; $17
	DC.B	1		; $18 - Screen on Exit.
	DC.B	0		; $19
	DC.B	0		; $1A
	DC.B	0		; $1B
	DC.L	$00		; $1C

	DC.B	"Cartridges"	; $20
	DS.B	$100-10

	DC.L	1234		; $120 - Usuario Registrado Codificado #1.
	DC.L	5678		; $124 - Usuario Registrado Codificado #2.

;;;	DC.B	$00		; $128

	CNOP	0,4
	DC.B	" -> AmiGameBoy preferences file <- ",0
	CNOP	0,4
FinPrefs:
BucPrefs=FinPrefs-DirPrefs
; -=-=-=-==-=-=-=-==-=-=-=-=-=-=-=-=-=-=-=-=-=-
	DS.L	6
	CNOP	0,8
BufPrefs:
	DS.B	BucPrefs
	DS.L	6
; -=-=-=-==-=-=-=-==-=-=-=-=-=-=-=-=-=-=-=-=-=-


; ------------------------------------------
; ******************************************
; ------------------------------------------




; ------------------------------------------
; ******************************************
; ------------------------------------------



DebugMode:
	BSR	DisMouse

	LEA	Regs,A3

	LEA	DebugIText4,A2
	MOVE.W	Debug+30,D1	; A
	LSL.W	#8,D1
	MOVE.W	Debug+14,D3	; F
	MOVE.B	Flags_Push(A3,D3.W*4),D1
	BSR	Calcul3
	ADDQ	#6,A2
	MOVE.W	Debug+22,D1	; BC
	BSR	Calcul3
	ADDQ	#5,A2
	MOVE.W	Debug+54,D1	; PC
	SUB.W	([Debug+40]),D1		; (Según A2)
;;;	SUB.W	([Debug+60]),D1		; (Según A7)
	SUBQ.W	#1,D1
	BSR	Calcul3

	LEA	DebugIText5,A2
	MOVE.W	Debug+18,D1	; HL
	BSR	Calcul3
	ADDQ	#6,A2
	MOVE.W	Debug+26,D1	; DE
	BSR	Calcul3
	ADDQ	#5,A2
	MOVE.W	Debug+2,D1	; SP
	BSR	Calcul3

	MOVE.W	#"DI",3(A2)
	TST.B	IFF(A3)
	BEQ.S	DebugEsDi
	MOVE.W	#"EI",3(A2)
DebugEsDi:

	LEA	DebugIText5+25,A2
	MOVE.W	Debug+14,D3	; F
	MOVE.L	#"    ",(A2)
	LSR.B	#1,D3
	BCC.S	NoFlagC
	MOVE.B	#"C",3(A2)
NoFlagC:LSR.B	#1,D3
	BCC.S	NoFlagZ
	MOVE.B	#"Z",2(A2)
NoFlagZ:LSR.B	#1,D3
	BCC.S	NoFlagV
	MOVE.B	#"V",1(A2)
NoFlagV:LSR.B	#1,D3
	BCC.S	NoFlagS
	MOVE.B	#"S",(A2)
NoFlagS:


	MOVEQ	#0,D5
	MOVE.W	Debug+2,D5	; SP
	LEA	DebugIText9,A2
	MOVEQ	#(7)-1,D6
BufPilaBuc:
	MOVE.L	D5,A4
	BFEXTU	D5{16:3},D1
	ADD.L	PagRead(A3,D1.W*4),A4
	MOVE.W	(A4),D1
	ROR.W	#8,D1
	BSR	Calcul3
	ADDQ	#1,A2
	ADDQ.W	#2,D5
	DBF	D6,BufPilaBuc


	MOVE.W	DirDissasem,D3			; Dir Address.
	BSR	Dissasem


	MOVE.W	DirMonitor,D3			; Dir Address.
	BSR	PreparaPokes



	MOVEM.L	MCeros,D0-D7/A0-A6
	JSR	OpenDebugWindow

	LEA	DebugPunts,A1
	BSR	Control

	JSR	CloseDebugWindow
	BSR	EnaMouse
	RTS



; -=-=-
	CNOP	0,4
DebugMonScroll:
	MOVE.W	DirMonitor,D3			; Dir Address.
	AND.W	#$0007,D3
	MOVE.W	([DebugGadgets+(GD_MonScroll*4)],$50.w),D0
	LSL.W	#3,D0
	OR.B	D3,D0
	BRA.S	DebugScrollCon
; -=-=-
	CNOP	0,4
DebugDisScroll:
	MOVE.W	DirDissasem,D3			; Dir Address.
	AND.W	#$0003,D3
	MOVE.W	([DebugGadgets+(GD_DisScroll*4)],$50.w),D0
	LSL.W	#2,D0
	OR.B	D3,D0
	BRA	DisaScrollCon
; -=-=-

; -=-
DissAddrArr:
	SUBQ.W	#1,DirDissasem
	MOVE.W	DirDissasem,D0			; Dir Address.
	BRA	DisaScrollCon
; -=-
DissAddrDeb:
	ADDQ.W	#1,DirDissasem
	MOVE.W	DirDissasem,D0			; Dir Address.
	BRA	DisaScrollCon
; -=-

; -=-=-
DebugAddress:
	MOVE.L	([DebugGadgets+(GD_MiniMon*4)],$50.w),A0
	BSR	CalculPok
DebugScrollCon:
	AND.L	#$FFFF,D0
	MOVE.W	D0,DirMonitor
	MOVE.L	D0,D3				; Dir Address.
	BSR.S	PreparaPokes
; ---
	LEA	DebugPunts,A0
	MOVE.L	#GD_MonScroll,D2
	MOVE.L	#$80080015,D0
	MOVEQ	#0,D1
	MOVE.W	DirMonitor,D1
	LSR.W	#3,D1
	BSR	UpdateTag
; ---
	move.l	_IntuitionBase,a6
	move.l	DebugWnd,a0
	move.b	54(a0),D0
	move.b	55(a0),D1
	extb.l	D0
	extb.l	D1
	move.l	50(a0),a0
	LEA	DebugText92,a1
	jsr     PrintIText(a6)
	RTS
; -=-=-
	CNOP	0,4
PreparaPokes:
	LEA	DebugIText92,A2
;
	MOVE.W	#(12)-1,D4
PreDEBuc1:
	MOVE.W	#(8)-1,D0
	MOVE.W	D3,D1			; Imp. Address
	BSR	Calcul3
	ADDQ	#2,A2
	LEA	25(A2),A4
PreDEBuc0:
	MOVE.W	D3,D2
	LSR.W	#8,D2
	LSR.B	#5,D2
	MOVE.L	D3,A0
;;;	ADD.L	(PunterosPage.W,PC,D2.W*4),A0
	ADD.L	(Regs+PagRead.l,D2.W*4),A0
	MOVE.B	(A0),D1
	BSR	Calcul3b
	TST.B	D1
	BNE.S	PreDECon0
	ADDQ.B	#1,D1
PreDECon0:
	MOVE.B	D1,(A4)+
	ADDQ.W	#1,D3
	ADDQ	#1,A2
	DBF	D0,PreDEBuc0
	ADD.W	#10,A2
	DBF	D4,PreDEBuc1
	RTS
; -=-=-




; -=-=-
DebugDissaAdr:
	MOVE.L	([DebugGadgets+(GD_Disassem*4)],$50.w),A0
	BSR	CalculPok
DisaScrollCon:
	AND.L	#$FFFF,D0
	MOVE.W	D0,DirDissasem
	MOVE.L	D0,D3				; Dir Address.
	BSR.S	Dissasem
; ---
	LEA	DebugPunts,A0
	MOVE.L	#GD_DisScroll,D2
	MOVE.L	#$80080015,D0
	MOVEQ	#0,D1
	MOVE.W	DirDissasem,D1
	LSR.W	#2,D1
	BSR	UpdateTag
; ---
	move.l	_IntuitionBase,a6
	move.l	DebugWnd,a0
	move.b	54(a0),D0
	move.b	55(a0),D1
	extb.l	D0
	extb.l	D1
	move.l	50(a0),a0
	LEA	DebugText16,a1
	jsr     PrintIText(a6)
	RTS
; -=-=-
; -=-=-
Dissasem:
	BSR	BorraDissa
	LEA	DebugIText16,A2

	MOVE.W	#(19)-1,D0
DissasemBuc:
	LEA	6(A2),A3
	LEA	21(A2),A4
	LEA	28(A2),A5

	MOVE.W	D3,D1			; Imp. Address
	BSR	Calcul3
	BSR	DissasemRut

	CMP.B	#$CB,D1
	BNE.S	DisAsCon4
	BSR	DissasemRut
	MOVE.B	D1,D2
	LSR.B	#3,D2
	AND.W	#$001F,D2
	MOVE.L	(DissasemTabCB.W,PC,D2.W*4),A1
	BRA.S	DisAsBuc0
DisAsCon4:
	AND.W	#$00FF,D1
	MOVE.L	(DissasemTab.W,PC,D1.W*4),A1
DisAsBuc0:
	MOVE.B	(A1)+,D2
	BEQ.S	DisAsCon0

	CMP.B	#"a",D2
	BEQ.S	DisAsCon2

	CMP.B	#"b",D2
	BEQ.S	DisAsCon3

	CMP.B	#"c",D2
	BNE.S	DisAsCon5
	MOVE.B	D1,D2
	AND.W	#$07,D2
	MOVE.L	(DissasemTabCB2.W,PC,D2.W*4),A1
	BRA.S	DisAsBuc0
DisAsCon5:

	MOVE.B	D2,(A3)+
	BRA.S	DisAsBuc0

DisAsCon2:
	BSR	DissasemRut
	EXG.L	A2,A3
	BSR	Calcul3b
	EXG.L	A2,A3
	BRA.S	DisAsBuc0

DisAsCon3:
	BSR	DissasemRut
	MOVE.B	D1,D4
	BSR	DissasemRut
	LSL.W	#8,D1
	MOVE.B	D4,D1
	EXG.L	A2,A3
	BSR	Calcul3
	EXG.L	A2,A3

	BRA.S	DisAsBuc0

DisAsCon0:
	ADD.W	#28,A2

	DBF	D0,DissasemBuc
	RTS
; -=-=-
DissasemRut:
	MOVE.W	D3,D2
	LSR.W	#8,D2
	LSR.B	#5,D2
	MOVE.L	D3,A0
;;;	ADD.L	(PunterosPage.W,PC,D2.W*4),A0
	ADD.L	(Regs+PagRead.L,D2.W*4),A0
	MOVE.B	(A0)+,D1
	EXG.L	A2,A4
	BSR	Calcul3b
	EXG.L	A2,A4

	MOVE.B	D1,D2
	BNE.S	DisAsCon1
	ADDQ.B	#1,D2
DisAsCon1:
	MOVE.B	D2,(A5)+
	ADDQ.W	#1,D3
	RTS
; -=-=-
BorraDissa:
	LEA	DebugIText16,A2
	MOVE.W	#(19*4)-1,D0
BorraDissaBuc:
	TST.B	(A2)+
	BEQ.S	BorraDissaCon
	MOVE.B	#" ",-1(A2)
	BRA.S	BorraDissaBuc
BorraDissaCon:
	DBF	D0,BorraDissaBuc
	RTS
; -=-=-


; ------------------------------------------
; ******************************************
; ------------------------------------------

CreaDissasemTab:
	LEA	Dissasembler(PC),A0
	LEA	DissasemTab(PC),A1
	MOVE.W	#(256+32+8)-1,D0
CreaDisTabBuc:
	MOVE.L	A0,(A1)+
CreaDisTabBuc0:
	TST.B	(A0)+
	BNE.S	CreaDisTabBuc0
	DBF	D0,CreaDisTabBuc
	RTS

	CNOP	0,8
DissasemTab:	DS.L	256
DissasemTabCB:	DS.L	32
DissasemTabCB2:	DS.L	8
	DS.L	4


; ------------------------------------------
; ******************************************
; ------------------------------------------

; ------------------------------------------
; ******************************************
; ------------------------------------------
; ------------------------------------------
; ------------------------------------------
; ------------------------------------------


; -----------------------------------
; -----------------------------------
	CNOP	0,4
SETPAL:
	MOVE.W	#$20,$DFF1DC
	RTS
; -----------------------------------
	CNOP	0,4
SETNTSC:
	MOVE.W	#0,$DFF1DC
	RTS
; -----------------------------------
	CNOP	0,4
MC68020:
	MOVE.L	$4.w,A0
	MOVE.B	$129(A0),D0
	SMI	EsUn060

	AND.B	#$8E,D0
	BNE.S	MC68020RET

NoAGA2:
	MOVEM.L	MCeros(PC),D0-D7/A0-A6
	JSR	OpenMC68020Window
	LEA	MC68020PUNTS,A1
	BSR	Control
	JSR	CloseMC68020Window
MC68020RET:
	MOVEQ	#-1,D0
	RTS
MC68020SALIR:
	ADD.W	#16+4,SP
	JSR	CloseMC68020Window
	MOVEQ	#0,D0
	RTS

; -----------------------------------
	CNOP	0,4
MiraAGA:
	LEA	$DFF000,A6
	MOVE.W	$7C(A6),D1
	MOVE.W	#30-1,D3
BucAGA2:
	MOVE.W	$7C(A6),D2
	CMP.B	D2,D1
	BNE	NoAGA2
	DBF	D3,BucAGA2
	ORI.B	#$F0,D1
	CMPI.B	#$F8,D1
	BNE	NoAGA2
	MOVEQ	#-1,D0
	RTS

; ------------------------------------------
; ******************************************
; ------------------------------------------

;	--------------------------
;	Refresca el Relog interno.
;	--------------------------

	CNOP	0,8
RefrescaReloj:
	LEA	battclockreso(PC),A1
	MOVE.L	$4.w,A6
	JSR	-$1F2(A6)		; Open Resource.
	MOVE.L	D0,A2
	MOVE.L	A2,D0
	BEQ.S	RefRelFin

	LEA	TimeBuffer(PC),A1
	LEA	timerdevice(PC),A0
	MOVEQ	#0,D0
	MOVE.L	D0,D1
	JSR	-$1BC(A6)		; Open Device.
	MOVE.L	D0,D6
	BNE.S	RefRelFin


	MOVEQ	#0,D7
	MOVEQ	#0,D0
	LEA	TimeBuffer(PC),A0
	MOVE.W	D0,$8(A0)
	SUB.L	A1,A1
	MOVE.L	A1,$A(A0)
	MOVE.L	A1,$E(A0)
	CLR.L	$24(A0)

	MOVE.L	A2,A6
	JSR	-$C(A6)
	LEA	TimeBuffer(PC),A0
	MOVE.L	D0,$20(A0)
	MOVE.W	#$B,$1C(A0)
	MOVE.L	A0,A1
	MOVE.L	$4.w,A6
	JSR	-$1C8(A6)		; DoIO.

	LEA	TimeBuffer(PC),A1
;	MOVE.L	$4.w,A6
	JSR	-$1C2(A6)		; Close Device.
RefRelFin:
	RTS

	CNOP	0,8
battclockreso:	DC.B	'battclock.resource',0,0
timerdevice:	DC.B	'timer.device',0,0

	CNOP	0,8
TimeBuffer:	DS.B	$30
	CNOP	0,4

; ------------------------------------------
; ******************************************
; ------------------------------------------

LongFile:
	MOVE.L	#FileNom,D1
	MOVEQ	#-2,D2
	MOVE.L	_DosBase,A6
	JSR	-$54(A6)		; Lock
	TST.L	D0
	BEQ.S	LONGFILER
	MOVE.L	D0,-(SP)

	MOVE.L	D0,D1
	move.L	#Examine,d2
	MOVE.L	_DosBase,A6
	JSR	-$66(A6)		; Examine

	MOVE.L	(SP)+,D1
	JSR	-$5A(A6)		; UnLock

	MOVE.L	Examine+$7C,D0
LONGFILER:
	RTS

; -----------------------------------

OpenFile:
	MOVE.L	_DosBase,A6
	JSR	-30(A6)			; OPEN
	MOVE.L	D0,DisBase
	RTS
CloseFile:
	MOVE.L	_DosBase,A6
	MOVE.L	DisBase,D1
	BEQ.S	NoCloseFile
	JSR	-36(A6)			; CLOSE
	CLR.L	DisBase
NoCloseFile:
	RTS
WriteFile:
	MOVE.L	_DosBase,A6
	MOVE.L	DisBase,D1
	MOVE.L	D3,-(SP)
	JSR	-48(A6)			; WRITE
	MOVE.L	(SP)+,D3
	CMP.L	D0,D3
	RTS
ReadFile:
	MOVE.L	_DosBase,A6
	MOVE.L	DisBase,D1
	MOVE.L	D3,-(SP)
	JSR	-42(A6)			; READ
	MOVE.L	(SP)+,D3
	CMP.L	D0,D3
	RTS

; -----------------------------------
	CNOP	0,4
PONOM:
	MOVE.L	A1,A2
NTXTYA0:
	TST.B	(A2)
	BEQ.S	COPYNOM2
	MOVE.B	#" ",(A2)+
	BRA.S	NTXTYA0
	CNOP	0,4
COPYNOM2:
	MOVE.B	(A0)+,D0
	BEQ.S	PONOMS
	TST.B	(A1)
	BEQ.S	PONOMS
	MOVE.B	D0,(A1)+
	BRA.S	COPYNOM2
PONOMS:	RTS
; -----------------------------------
	CNOP	0,4
CopyNom:
	MOVE.B	(A0)+,(A1)+
	DBEQ	D0,CopyNom
	RTS
; -----------------------------------
	CNOP	0,4
ArreglaNom:
	LEA	FileNom(PC),A1
	MOVE.W	#$100-1,D0
	MOVE.L	8(A2),A0
	TST.B	(A0)
	BEQ.S	ArrglNom
	BSR	CopyNom
	SUBQ	#1,A1
	CMP.B	#":",-1(A1)
	BEQ.S	ArrglNom
	MOVE.B	#"/",(A1)+
ArrglNom:
	MOVE.W	#$100-1,D0
	MOVE.L	4(A2),A0
	BSR	CopyNom
	RTS
; -----------------------------------



; -----------------------------------
;	Pasa Decimal  &  Pasa Hexa v1.0
;	(PD)  Juan Antonio Gomez Galvez
;	(Codigo texto para DEVPAC II),(3-X-92)

;	- D0=Numero que se va a pasar a decimal.
;	- Resultado: D0 y A0 tienen el puntero del buffer
;	  de los numeros en ASCII en decimal.  (10 bytes)

PASDEC:
	LEA	DSUMA(PC),A0
	CLR.L	(A0)+
	CLR.L	(A0)+
	CLR.W	(A0)+

	MOVE.W	#$08-1,D1
	LEA	DATOSSUMA(PC),A0
SUMBUC01:
	MOVEM.L	D0-D1/A0,-(SP)
	AND.L	#$000F,D0
	TST.B	D0
	BEQ	SUMCON00
SUMBUC02:
	MOVEM.L	D0/A0,-(SP)
	LEA	DSUMA(PC),A1
	BSR	SUMDEC
	MOVEM.L	(SP)+,D0/A0
	SUBQ.B	#$01,D0
	BNE.S	SUMBUC02
SUMCON00:
	MOVEM.L	(SP)+,D0-D1/A0
	LSR.L	#$04,D0
	ADD.L	#$0A,A0
	DBF	D1,SUMBUC01

	LEA	DSUMA(PC),A0
	ADD.L	#$30303030,(A0)+
	ADD.L	#$30303030,(A0)+
	ADD.W	#$3030,(A0)+

	LEA	DSUMA(PC),A0
SUMBUC03:
	TST.B	(A0)
	BEQ	SUMCON01
	MOVE.B	(A0),D0
	CMP.B	#$30,D0
	BNE.S	FINRET
	MOVE.B	#$20,(A0)+
	BRA	SUMBUC03
SUMCON01:
	MOVE.B	#"0",-(A0)
	BRA.S	FINRET
SUMDEC:
	MOVEQ.L	#$0A-1,D1
	ADD.L	#$0A,A0
	ADD.L	#$0A,A1
SUMBUC00:
	MOVE.B	-(A0),D3
	ADD.B	D3,-(A1)
	MOVE.B	(A1),D0
	SUB.B	#$0A,D0
	BCS.S	SUMBIEN00
	MOVE.B	D0,(A1)
	ADD.B	#$01,-1(A1)
	DBF	D1,SUMBUC00
	RTS
SUMBIEN00:
	CLR.L	D0
	DBF	D1,SUMBUC00
	RTS
FINRET:
	LEA	DSUMA(PC),A0
	MOVE.L	A0,D0
	RTS


;	- A0 el puntero del buffer de los
;	  numeros en ASCII en decimal. (10 bytes)
;	- Resultado: D0=Numero en hexadecimal.

PASHEX:
	CLR.L	D5
	LEA	PUNTERO(PC),A1
	MOVE.L	A0,(A1)
	MOVEQ.L	#$0A-1,D0
PASBUC02:
	SUB.B	#$30,(A0)+
	BCC.S	PASCON00
	CLR.B	-$01(A0)
PASCON00:
	CMP.B	#$0A,-$01(A0)
	BLT.S	PASCON01
	CLR.B	-$01(A0)
PASCON01:
	DBF	D0,PASBUC02
	MOVE.L	PUNTERO(PC),A0
	LEA	FDATOSSUMA(PC),A1
	MOVEQ.L	#$08-1,D4
	MOVE.L	#$10000000,D3
PHEBUC01:
	MOVEQ.L	#-1,D7
PHEBUC00:
	ADD.L	#$01,D7
	BSR	COPY1
	BSR	RESTAD
	CMP.B	#$09,D0
	BNE.S	PHEBUC00
	BSR	COPY2
	CLR.L	D6
	TST.L	D7
	BEQ.S	PHECON00
PHEBUC02:
	ADD.L	D3,D6
	SUB.L	#$01,D7
	BNE.S	PHEBUC02
	ADD.L	D6,D5
PHECON00:
	LSR.L	#$04,D3
	SUB.L	#$0A,A1
	DBF	D4,PHEBUC01
	MOVE.L	D5,D0
	RTS
COPY1:
	MOVE.L	PUNTERO(PC),A6
	LEA	DSUMA2(PC),A5
COPCON00:
	MOVE.L	(A6)+,(A5)+
	MOVE.L	(A6)+,(A5)+
	MOVE.W	(A6)+,(A5)+
	RTS
COPY2:
	MOVE.L	PUNTERO(PC),A5
	LEA	DSUMA2(PC),A6
	BRA.S	COPCON00
RESTAD:
	MOVEM.L	A0-A1,-(SP)
	ADD.L	#$0A,A0
	ADD.L	#$0A,A1
	CLR.L	D0
	ROXR.L	#$1,D0		; FLAG X=0
	MOVE.L	#$0A-1,D0
RESBUC00:
	SBCD.B	-(A1),-(A0)
	AND.B	#$0F,(A0)
	DBF	D0,RESBUC00
	MOVE.B	(A0),D0
	MOVEM.L	(SP)+,A0-A1
	RTS

	DC.L	0
DSUMA:
	DS.B	$0A
	DC.L	0
DSUMA2:
	DS.B	$0A
	DC.L	0
DATOSSUMA:
	DC.B	0,0,0,0,0,0,0,0,0,1
	DC.B	0,0,0,0,0,0,0,0,1,6
	DC.B	0,0,0,0,0,0,0,2,5,6
	DC.B	0,0,0,0,0,0,4,0,9,6
	DC.B	0,0,0,0,0,6,5,5,3,6
	DC.B	0,0,0,1,0,4,8,5,7,6
	DC.B	0,0,1,6,7,7,7,2,1,6
FDATOSSUMA:
	DC.B	0,2,6,8,4,3,5,4,5,6
	DC.L	0
PUNTERO:
	DC.L	0

;	Fin del codigo texto.

; -----------------------------------

DisMouse:
	TST.L	MainMenuWnd(PC)
	BEQ.S	NoDisMouse
	TST.L	WREQBASE
	BEQ.S	SiDisMouse
NoDisMouse:
	RTS
SiDisMouse:
	MOVEQ	#$70,D0
	MOVE.L	#$10001,D1
	MOVE.L	$4.W,A6
	JSR	-$2AC(A6)		; AllocVec
	MOVE.L	D0,VECBASE
	BEQ.S	ERVEC
	MOVE.L	D0,A0
	MOVE.L	MainMenuWnd(PC),A1
	MOVE.L	_IntuitionBase(PC),A6
	JSR	-$F0(A6)		; Request
ERVEC:
	MOVE.L	D0,WREQBASE
PBUSY:
	MOVE.L	MainMenuWnd(PC),A0
	LEA	BUSYGFX,A1
	MOVE.L	#16,D0
	MOVE.L	#16,D1
	MOVEQ	#0,D2
	MOVEQ	#0,D3
	MOVE.L	_IntuitionBase,A6
	JMP	-$10E(A6)
; --------------------------------------------------------
EnaMouse:
	TST.L	WREQBASE
	BEQ.S	ERVEC3
	MOVE.L	VECBASE(PC),A0
	MOVE.L	MainMenuWnd(PC),A1
	MOVE.L	_IntuitionBase,A6
	JSR	-$78(A6)		; EndRequest
ERVEC3:
	MOVE.L	VECBASE(PC),D0
	BEQ.S	ERVEC2
	MOVE.L	D0,A1
	MOVE.L	$4.W,A6
	JSR	-$2B2(A6)		; FreeVec

	CLR.L	VECBASE
	CLR.L	WREQBASE
	BRA.S	PNORM
ERVEC2:
	CLR.L	VECBASE
	CLR.L	WREQBASE
	RTS
PNORM:
	MOVE.L	MainMenuWnd(PC),A0
	MOVE.L	_IntuitionBase,A6
	JMP	-$3C(A6)

	CNOP	0,4
VECBASE:DC.L	0
WREQBASE:DC.L	0
; -----------------------------------

; -----------------------------------


; -----------------------------------
TxtPrint:
	move.b  54(a0),d0
	ext.w   d0
	move.b  55(a0),d1
	ext.w   d1
	move.l  50(a0),a0
	move.l  _IntuitionBase,a6
	jsr     PrintIText(a6)
	RTS
; -----------------------------------	; D0.l = 0 On
	CNOP	0,4			; D0.l = 1 Off
GadsOnOff:
	MOVE.L	D0,OnOffTAGS+4
	MOVE.L	(A0),A0
	SUB.L	A2,A2
	LEA	OnOffTAGS(PC),A3
	MOVE.L	_GadToolsBase(PC),A6
	JSR	-$2A(A6)
	RTS
	CNOP	0,4
OnOffTAGS:
	DC.L    $8003000E,1
	DC.L	0,0
; -----------------------------------
UpdateTag:
	MOVEM.L	D0-D1/A0,-(SP)
	MOVE.W	D1,D0
	MOVE.W	D2,D1
	BSR	SetGadgetValue
	MOVEM.L	(SP)+,D0-D1/A0

	MOVE.L	([iWnd.w,A0]),A1
	LEA	([iGadgets.w,A0],D2.w*4),A0

	MOVE.L	D0,.tagData
	MOVE.L	D1,.tagData+4
	MOVE.L	(A0),A0
	SUB.L	A2,A2
	LEA	.tagData(PC),A3
	MOVE.L	_GadToolsBase,A6
	JSR	-$2A(A6)
	RTS
	CNOP	0,4
.tagData:
	DC.L    0,0
	DC.L	0,0
; -----------------------------------

; <=-----------------------=>

; A0:xxxPunts
; A1:Dir TagListBase
; D0=Número de gadget
; D1=Número de Tag a modificar
; D2=Dato a modificar.
	CNOP	0,4
OverrideTag:
	CMP.L	#$8008000F,D1
	BNE.S	.noGadgetValue

	MOVEM.L	D0/D1,-(SP)
	MOVE.W	D0,D1
	MOVE.W	D2,D0
	BSR	SetGadgetValue
	MOVEM.L	(SP)+,D0/D1
.noGadgetValue:
.loop1:
	TST.W	D0
	BEQ.S	.skip
.loop2:
	TST.L	(A1)+
	DBNE	D0,.loop1
	ADDQ	#4,A1
	BRA.S	.loop2
.skip:
	TST.L	(A1)
	BEQ.S	.ret
	CMP.L	(A1)+,D1
	BEQ.S	.over
	ADDQ	#4,A1
	BRA.S	.skip
.over:
	MOVE.L	D2,(A1)+
.ret:
	RTS

; <=-----------------------=>
	CNOP	0,4
Centrar:
	TST.L	(A0)
	BNE.S	MIRACERO
	RTS
MIRACERO:
	MOVE.L	(A0)+,A2
	MOVE.L	(A0)+,D2
	MOVE.L	(A0)+,D1
	MOVE.L	$C(A2),A1
	MOVEQ	#0,D0
MIRACEROB:
	ADDQ.W	#1,D0
	TST.B	(A1)+
	BNE.S	MIRACEROB
	SUBQ.W	#1,D0
	LSL.W	#3,D0
	SUB.W	D0,D1
	LSR.W	#1,D1
	ADD.W	D2,D1
	MOVE.W	D1,4(A2)
	BRA.S	Centrar
; <=-----------------------=>

; <=-------------------------------------------------------=>
;	 Rutina de control de lectura de Gadgets.
;	<= -------------------------------------=>
;	    A1 = SaltosGadgets.	; Para salir hacer:  ADD.L  #16+4,SP
;	-12(A1)= Window Handle.
;	 -8(A1)= Punteros Gadgets.
;	 -4(A1)= Nº de Gadgets-1
	CNOP	0,8
Control:
	CLR.W	ControlKeys
	MOVE.L	-8(A1),-(SP)
	MOVE.L	A1,-(SP)
	MOVE.L	-12(A1),A0
	MOVE.L	(A0),-(SP)
ControlLoop:
	MOVE.L	(SP),A0
	MOVE.L	$56(A0),A0
	MOVE.L	$4,A6
	JSR	-$180(A6)	; Wait Port. (iport)(A0)

	MOVE.L	(SP),A0
	MOVE.L	$56(A0),A0
	MOVE.L	_GadToolsBase,A6
	JSR	-$48(A6)	; (D0)IntuiMessage = GT_GetIMsg(iport)(A0)
	TST.L	D0
	BEQ.S	ControlLoop

	MOVE.L	D0,A1
	MOVE.L	A1,-(SP)	; STRUCTURE IntuiMessage
	MOVE.L	$1C(A1),-(SP)	; APTR im_IAddress (the pointer to the Gadget or the Screen)
	MOVE.L	$14(A1),-(SP)	; LONG im_Class (the Class bits correspond directly with the IDCMP Flags)
	MOVE.W	$18(A1),-(SP)	; WORD im_Code (the Code field is for special values like MENU number)

	MOVE.L	_GadToolsBase,A6
	JSR	-$4E(A6)	; GT_ReplyIMsg(imsg)(A1)

	MOVE.W	(SP)+,D2
	MOVEM.L	(SP)+,D0-D1/A1

	CMP.W	#$200,D0	; IDCMP_CLOSEWINDOW
	BEQ	ControlCloseWindow

	CMP.W	#$100,D0	; IDCMP_MENUPICK
	BEQ	ControlMenuPick

;	CMP.W	#$010,D0	; IDCMP_MOUSEMOVE
;	BEQ	ControlMouseMove

	CMP.W	#$020,D0	; IDCMP_GADGETDOWN
	BEQ	ControlGadgetDown

	CMP.W	#$040,D0	; IDCMP_GADGETUP
	BEQ	ControlGadgetUp

	CMP.W	#$400,D0	; IDCMP_RAWKEY
	BEQ.S	ControlRawKey

	BRA.S	ControlLoop

; -----------------------------------=> Vuelta al Control.
ControlRET:
	RTS
; -----------------------------------=> Salir del Control.
ControlSalir:
	ADD.W	#16,SP
	RTS
; -----------------------------------=> Usado por Subrutina Control-Gadgets
ControlCloseWindow:
	ADD.W	#12,SP
	RTS
; -----------------------------------

ControlRawKey:
	MOVEQ	#0,D1
	MOVE.W	ControlKeys,D1
	MOVE.B	$19(A1),D1	; Tecla.
	MOVE.L	4(SP),A1
	MOVE.L	-16(A1),D0
	BEQ	ControlLoop	

	CMP.B	#$60,D1		; Shift Izquierdo Pulsado.
	BEQ.S	ShiftPul
	CMP.B	#$61,D1		; Shift Derecho Pulsado.
	BEQ.S	ShiftPul
	CMP.B	#$E0,D1		; Shift Izquierdo Soltado.
	BEQ.S	ShiftSol
	CMP.B	#$E1,D1		; Shift Derecho Soltado.
	BEQ.S	ShiftSol

	MOVE.L	D0,A1
EsTeclaBuc:
	CMP.L	#$100,(A1)
	BEQ.S	EsFullTecla
	TST.L	(A1)
	BMI	ControlLoop
	CMP.L	(A1)+,D1
	ADDQ	#4,A1
	BNE.S	EsTeclaBuc

	MOVE.L	-4(A1),A1
	JSR	(A1)
	BRA	ControlLoop

EsFullTecla:
	MOVE.L	4(A1),A1
	JSR	(A1)
	BRA	ControlLoop

ShiftPul:
	BSET	#0,ControlKeys
	BRA	ControlLoop

ShiftSol:
	BCLR	#0,ControlKeys
	BRA	ControlLoop

; -----------------------------------

ControlGadgetDown:
	MOVE.L	4(SP),A1	; ***Punts
	MOVE.L	8(SP),A0	; ***Wnd

	SUBQ.L	#4,A1
	MOVE.L	(A1),D0
	BMI	ControlCloseWindow

	MOVE.L	#$FFFF,D3
.loop1:
	ADDQ.W	#1,D3
	CMP.L	(A0)+,D1
	DBEQ	D0,.loop1
	TST.W	D0
	BMI	ControlLoop

;	CMP.W	#GD_JoyPort,D3
;	BEQ.S	ControlGadgetUp

	BRA	ControlLoop

ControlGadgetUp:
	MOVE.L	4(SP),A1	; ***Punts
	MOVE.L	8(SP),A0	; ***Wnd

	SUBQ.L	#4,A1
	MOVE.L	(A1),D0
	BMI	ControlCloseWindow

	MOVE.L	#$FFFF,D3
.loop1:
	ADDQ.W	#1,D3
	CMP.L	(A0)+,D1
	DBEQ	D0,.loop1
	TST.W	D0
	BMI	ControlLoop


	MOVE.L	4(SP),A0	; ***Punts
	MOVE.W	D2,D0
	MOVE.W	D3,D1
	BSR	SetGadgetValue


	MOVE.L	(A1),D0
.loop2:
	ADDQ.L	#4,A1
	TST.L	4(A1)
	BEQ	ControlLoop
	CMP.L	(A1)+,D3
	DBEQ	D0,.loop2
	TST.W	D0
	BMI	ControlLoop

	MOVE.L	(A1),A1
	JSR	(A1)
	BRA	ControlLoop

; -----------------------------------

ControlMenuPick:
	MOVE.L	$14(A1),D0
	MOVE.W	$18(A1),D1
	MOVE.L	$1C(A1),A0

	BFEXTU	D1{27:5},D2
	BFEXTU	D1{21:6},D3
	BFEXTU	D1{16:5},D4

	CMP.W	#$1F,D2
	BEQ	ControlLoop
	MOVE.L	(PunterosMenu.W,PC,D2.W*4),A0
	CMP.W	#$2F,D3
	BEQ	ControlLoop
	CMP.W	#$1F,D4
	BEQ.S	EJECMENU
	MOVE.L	(A0,D3.W*4),A0
	MOVE.W	D4,D3
EJECMENU:
	JSR	([A0,D3.W*4])
	BRA	ControlLoop

; -----------------------------------

; A0:WindowPunts
; D0:Value
; D1:GadgetKey
SetGadgetValue:
	MOVE.L	iValues(A0),A0
	TST.L	A0
	BEQ.S	.ret
.loop:
	TST.W	(A0)
	BMI.S	.ret

	ADDQ	#4,A0

	CMP.W	-4(A0),D1
	BNE.S	.loop

	MOVE.W	D0,-(A0)
.ret:
	RTS

; A0:WindowPunts
; D0:DefaultValue
; D1:GadgetKey
; D0=Value
GetGadgetValue:
	MOVE.L	A0,-(SP)
	MOVE.L	iValues(A0),A0
	TST.L	A0
	BEQ.S	.ret
.loop:
	TST.W	(A0)
	BMI.S	.ret

	ADDQ	#4,A0

	CMP.W	-4(A0),D1
	BNE.S	.loop

	MOVEQ	#0,D0
	MOVE.W	-(A0),D0
.ret:
	MOVE.L	(SP)+,A0
	RTS





; <=-------------------------------------------------------=>
; <=-------------------------------------------------------=>
; <=-------------------------------------------------------=>


	CNOP	0,4
PunterosMenu:
	DC.L	MenuProject
	DC.L	MenuCartridges
	DC.L	MenuOptions
	DC.L	0,0

MenuProject:
	DC.L	About			; About
	DC.L	HelpPage		; Help Page
	DC.L	ControlRET		; -----
	DC.L	SubMenuScreen		; Menu Screen
	DC.L	CheatMode		; Cheat Mode
	DC.L	DebugMode		; Debug Mode
	DC.L	ControlRET		; -----
	DC.L	SoundMode		; Edit Sound
	DC.L	ControlRET		; Edit Palette
	DC.L	EditJoyMode		; Edit Joy-Control
	DC.L	ControlRET		; -----
	DC.L	SubMenuVRAM		; Save VRAM
	DC.L	SavePrefs		; Save Prefs
	DC.L	ControlRET		; -----
	DC.L	ControlSalir		; Quit
	DC.L	ControlRET		; -----
SubMenuVRAM:
	DC.L	ControlRET		; BackGround
	DC.L	ControlRET		; Window
	DC.L	ControlRET		; Strites
	DC.L	ControlRET		; -----
SubMenuScreen:
	DC.L	SETPAL			; Set PAL
	DC.L	SETNTSC			; Set NTSC
	DC.L	ControlRET		; -----
MenuCartridges:
	DC.L	Insert			; Insert Cartridge
	DC.L	Eject			; Eject  Cartridge
	DC.L	ControlRET		; -----
	DC.L	ControlRET		; Inject Patch
	DC.L	ControlRET		; -----
	DC.L	ControlRET		; Load Frozen
	DC.L	ControlRET		; Save Frozen
	DC.L	ControlRET		; -----
	DC.L	ReadBatt		; Load RAM-Battery
	DC.L	SaveBatt		; Save RAM-Battery
	DC.L	ControlRET		; -----
	DC.L	ClearBatt		; Clear RAM-Battery
	DC.L	ControlRET		; -----
MenuOptions:
	DC.L	ControlRET		; Black Border
	DC.L	ControlRET		; No illogical moves
	DC.L	ControlRET		; -----
	DC.L	ControlRET		; Auto-Load Battery
	DC.L	ControlRET		; Auto-Save Battery
	DC.L	ControlRET		; Ask for save Battery
	DC.L	ControlRET		; -----
	DC.L	SubMenuCPU		; CPU Emulation
	DC.L	SubMenuVideo		; Video Emulation
	DC.L	SubMenuSound		; Sound Emulation
	DC.L	ControlRET		; -----
	DC.L	SubMenuXpk		; xpk for save
	DC.L	SubMenuExitmode		; Screen mode on exit
	DC.L	ControlRET		; -----
	DC.L	ControlRET		; Disable Cheats
	DC.L	ControlRET		; Ask for Reset
	DC.L	ControlRET		; -----

SubMenuCPU:
	DC.L	ControlRET		; Syncronized
	DC.L	ControlRET		; Unsyncronized

SubMenuVideo:
	DC.L	ControlRET		; Sprites priorities
	DC.L	ControlRET		; Realtime Palette Refresh

SubMenuSound:
	DC.L	ControlRET		; 3 Channels
	DC.L	ControlRET		; 4 Channels

SubMenuXpk:
	DC.L	ControlRET		; Select Packer
	DC.L	ControlRET		; -----
	DC.L	ControlRET		; Frozen games
	DC.L	ControlRET		; Battery-RAM

SubMenuExitmode:
	DC.L	NoChange		; No Change.
	DC.L	ForcePAL		; Force to PAL
	DC.L	ForceNTSC		; Force to NTSC


; <=-------------------------------------------------------=>
; <=-------------------------------------------------------=>
; <=-------------------------------------------------------=>

	CNOP	0,8
MCeros:	DS.L	16

; <=-------------------------------------------------------=>

; =------------------------------------------=> Datos de Ventanas:

	CNOP	0,4

iValues=-20
iKeys=-16
iWnd=-12
iGadgets=-8
iCNT=-4

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

	DC.L	MainMenuValues
	DC.L	0
	DC.L	MainMenuWnd
	DC.L	MainMenuGadgets
	DC.L	MainMenu_CNT-1
MainMenuPunts:
	DC.L	GD_Insert,Insert
	DC.L	GD_PowerON,PowerON
	DC.L	GD_Continue,Continue
	DC.L	GD_Exit,ControlSalir
	DC.L	GD_JoyType,ImpJoyType
	DC.L	GD_HelpPage,HelpPage
	DC.L	0,0
MainMenuValues:
	DC.W	GD_JoyType,0
;	DC.W	GD_JoyPort,0
	DC.W	GD_LCDFade,0
	DC.W	GD_ScrMode,0
;	DC.W	GD_GfxRefresh,0
;	DC.W	GD_SprRefresh,0
;	DC.W	GD_CPUspd,0
	DC.W	-1,-1


; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

	DC.L	0
	DC.L	QuitKeys
	DC.L	QuitWnd
	DC.L	QuitGadgets
	DC.L	Quit_CNT-1
QuitPunts:
	DC.L	GD_QuitYes,ControlSalir
	DC.L	GD_QuitNo,NoQuit
	DC.L	0,0
QuitKeys:
	DC.L	$40,ControlSalir
	DC.L	-1,-1

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

	DC.L	0
	DC.L	ImpErrorKeys
	DC.L	ImpErrorWnd
	DC.L	ImpErrorGadgets
	DC.L	ImpError_CNT-1
ImpErrorPunts:
	DC.L	GD_Econtinue,ControlSalir
	DC.L	0,0
ImpErrorKeys:
	DC.L	$40,ControlSalir
	DC.L	-1,-1

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

	DC.L	0
	DC.L	HelpPageKeys
	DC.L	HelpPageWnd
	DC.L	HelpPageGadgets
	DC.L	HelpPage_CNT-1
HelpPagePunts:
	DC.L	GD_HPcontinue,ControlSalir
	DC.L	0,0
HelpPageKeys:
	DC.L	$40,ControlSalir
	DC.L	-1,-1

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

	DC.L	0
	DC.L	CheatKeys
	DC.L	CheatWnd
	DC.L	CheatGadgets
	DC.L	Cheat_CNT-1
CheatPunts:
;	DC.L	GD_PokeAddress,ControlRET
;	DC.L	GD_PokeValue,ControlRET
;	DC.L	GD_Poke,DoPoke
;	DC.L	GD_CheatSeaVal,CheatSearch
;	DC.L	GD_CheatComVal,CheatCompare
;	DC.L	GD_CheatMore,CheatMore
;	DC.L	GD_PokeExit,ControlSalir
	DC.L	0,0
CheatKeys:
	DC.L	-1,-1

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

	DC.L	0
	DC.L	AboutKeys
	DC.L	AboutWnd
	DC.L	AboutGadgets
	DC.L	About_CNT-1
AboutPunts:
	DC.L	GD_Aboutmore,ControlSalir
	DC.L	GD_AboutExit,ControlSalir
	DC.L	0,0
AboutKeys:
	DC.L	$40,ControlSalir
	DC.L	$44,ControlSalir
	DC.L	-1,-1

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

	DC.L	0
	DC.L	0
	DC.L	MC68020Wnd
	DC.L	MC68020Gadgets
	DC.L	MC68020_CNT-1
MC68020PUNTS:
	DC.L	GD_magacontinue,ControlSalir
	DC.L	GD_magaExitWB,MC68020SALIR
	DC.L	0,0

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

	DC.L	0
	DC.L	0
	DC.L	AskSaveBattWnd
	DC.L	AskSaveBattGadgets
	DC.L	AskSaveBatt_CNT-1
AskSaveBattPunts:
	DC.L	GD_ModiNO,ControlSalir
	DC.L	GD_ModiCancel,AskSaveBattCancel
	DC.L	GD_ModiSave,AskSaveBattSave
	DC.L	0,0

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

	DC.L	0
	DC.L	0
	DC.L	ClearWnd
	DC.L	ClearGadgets
	DC.L	Clear_CNT-1
ClearPunts:
	DC.L	GD_ClearYes,ControlSalir
	DC.L	GD_ClearNo,AskSureNo
	DC.L	0,0

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

	DC.L	0
	DC.L	0
	DC.L	EditSoundWnd
	DC.L	EditSoundGadgets
	DC.L	EditSound_CNT-1
SoundPunts:
	DC.L	0,0

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

	DC.L	0
	DC.L	0
	DC.L	EditJoyWnd
	DC.L	EditJoyGadgets
	DC.L	EditJoy_CNT-1
EditJoyPunts:
	DC.L	0,0

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

	DC.L	0
	DC.L	BebugKeys
	DC.L	DebugWnd
	DC.L	DebugGadgets
	DC.L	Debug_CNT-1
DebugPunts:
	DC.L	GD_MiniMon,DebugAddress
	DC.L	GD_Disassem,DebugDissaAdr
	DC.L	GD_MonScroll,DebugMonScroll
	DC.L	GD_DisScroll,DebugDisScroll
	DC.L	0,0
BebugKeys:
	DC.L	$004C,DissAddrArr
	DC.L	$004D,DissAddrDeb
;	DC.L	$004F,DebugAddressIzq
;	DC.L	$004E,DebugAddressDer
;	DC.L	$014C,DebugAddressArr2
;	DC.L	$014D,DebugAddressDeb2
;	DC.L	$014F,DebugAddressIzq
;	DC.L	$014E,DebugAddressDer
	DC.L	-1,-1

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

; =------------------------------------------<=

	CNOP	0,8
DatsGameBoyPic:
	DC.W	28,9
	DC.W	325,51
	DC.W	3
	DC.L	GBLogo
	DC.B	7,0
	DC.L	0

	CNOP	0,8
DatsJoyTypePic:
	DC.W	0,0
	DC.W	47,16
	DC.W	3
DirJoyTypePic:	DC.L	GBTeclado
	DC.B	7,0
	DC.L	0

	CNOP	0,8
DatsErrorPic:
	DC.W	0,0
	DC.W	64,30
	DC.W	3
	DC.L	Perill
	DC.B	7,0
	DC.L	0

; -----------------------------------

; =------------------------------------------=> Include de Dissasembler
	CNOP	0,8
	INCLUDE	"Dissasembler.asm"
; =------------------------------------------<=

; =------------------------------------------=> Include de Manufacturers
	CNOP	0,8
	INCLUDE	"Manufacturers.asm"
; =------------------------------------------<=

; =------------------------------------------=> Include de GadToolsBox
	CNOP	0,8
	INCLUDE	"GadToolsBox/AmiGameBoy.s"
; =------------------------------------------<=

; =------------------------------------------=> ¡Comienza la Acción!
	CNOP	0,8
GameBoyEmul:
; =------------------------------------------<=

; =------------------------------------------=> Sección gráfica de prueba.
	IFND	GB_Menu
	SECTION	Gfx,data_c

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

Regs:
Debug:
Flags_Push=0
PagRead=0
IFF=0

ERAM0:	DS.B	(8*1024)+$80
ERAM1:	DS.B	(8*1024)+$80
ERAM2:	DS.B	(8*1024)+$80
ERAM3:	DS.B	(8*1024)+$80

	ENDC
; =------------------------------------------<=

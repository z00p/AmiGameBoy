; lupa.s - the shared launch contract for game launchers such as Lupa, scripts and the Shell
; (C:\AMD\lupa-integration\for-pancho\gamelist-spec.md section 1, framework.md 2.2-2.6),
; behind HY_LUPA (menu builds only; without it the builds are byte-identical). Modelled on
; AmiPCEngine's Lupa.asm.
;
;   <program> [ROM] [AGA|RTG] [ONEGAME] [MENU] [PROFILE=030|FAST|AUTO] [RTGMODE=..] [PREFS=..|P=..]
;
; Words in any case, in any order; KEY=value and KEY value both work; a word may be "quoted",
; a value too (KEY="a b"). An unquoted word with = that is no keyword is passed over.
; ROM: the first word that is not a keyword, or any "quoted" word: a file name holding AGA or
;   RTG switches nothing on. It is inserted and powered on at once, as before.
; AGA / RTG: the display. Each program has one (AGA, AGA 030: Amiga display; RTG: Picasso96).
;   Asked for the other one, the program runs on its own and the return code is 5. Both
;   words: bad arguments, 10.
; ONEGAME: leaving the game (Esc, or a CD32 shoulder + Play) quits the program: the menu's
;   battery save prompt first, as Quit has it (Cancel there keeps the menu), then no Quit
;   requester. A ROM that can't be loaded (no file, unreadable, not a cartridge, a Colour-only
;   cart in a build without colour) is shown in an EasyRequest on the Workbench screen once
;   the menu's screen is closed, then the program quits with 10. The RTG program with no RTG
;   screen does the same with 20. Without ONEGAME such errors are shown in the menu, as before.
; MENU: the ROM is loaded, the menu stays.
; PROFILE=, RTGMODE=, PREFS= / P=: accepted and not used yet.
; Workbench: a project icon whose default tool is the program (sm_ArgList[1]) is the ROM, as
;   before; the ToolTypes of the last WBArg's icon (the project's, or the program's own) may
;   hold AGA, RTG, ONEGAME and MENU.
; Return codes: 0; 5 ran with a display fallback; 10 not loaded (ONEGAME) or bad arguments;
;   20 no AGA or no 68020 (the menu's existing check, when the user quits there), or the RTG
;   program with no RTG screen (ONEGAME).
; Before each takeover (CongelaAMIGA) and after each return from the game, LupaSettle waits
;   (1 s at most) until no key, mouse button or fire button is held, so a key released while
;   the OS is off can't stay held in input.device.
; Test switch: HY_LUPAREQ=n: the EasyRequest goes away by itself after n ticks (WinUAE jobs).
; With HY_PAUSEAT=n (hybrid.asm) a game is left at frame n as Esc would leave it.

LupaMax		=256
LupaLineMax	=512

	SECTION	hybrid,CODE
	cnop	0,4
; ---- Shell arguments (menu.s Start, for HyArgs): a0 = the line, d0 = its length
LupaArgs:
	movem.l	d0-d7/a0-a6,-(sp)
	lea	LupaLine,a1
	move.w	#LupaLineMax-1,d1
.cp:	subq.l	#1,d0
	bmi.s	.cpe
	move.b	(a0)+,d2
	beq.s	.cpe
	cmp.b	#10,d2
	beq.s	.cpe
	move.b	d2,(a1)+
	subq.w	#1,d1
	bne.s	.cp
.cpe:	clr.b	(a1)
	lea	LupaLine,a2
.next:	bsr.w	LupaWord		; -> LupaW; d0 = -1 at the end, d2 = 1 if "quoted"
	tst.l	d0
	bmi.w	.x
	tst.b	d2
	bne.s	.rom			; "quoted": a file name
	bsr.w	LupaKey			; d0 = the keyword's number or -1, a1 = the value after = or 0
	tst.l	d0
	bmi.s	.word
	cmp.w	#4,d0			; AGA, RTG, ONEGAME, MENU: the whole word only
	bcc.s	.kw			; (RTG=x is no switch: passed over)
	move.l	a1,d1
	bne.s	.word
.kw:	add.w	d0,d0
	move.w	.tab(pc,d0.w),d0
	jmp	.tab(pc,d0.w)
.tab:	dc.w	.aga-.tab,.rtg-.tab,.one-.tab,.menu-.tab
	dc.w	.val-.tab,.val-.tab,.val-.tab,.val-.tab
.aga:	or.b	#1,LupaDisp
	bra.s	.next
.rtg:	or.b	#2,LupaDisp
	bra.s	.next
.one:	st	LupaOne
	bra.s	.next
.menu:	st	LupaMenu
	bra.s	.next
.val:	move.l	a1,d0			; PROFILE, RTGMODE, PREFS, P (not used): KEY value passes
	bne.s	.next			; the value over
	bsr.w	LupaWord
	tst.l	d0
	bmi.s	.x
	bra.s	.next
.word:	lea	LupaW,a0		; KEY=value of another kind: not a file name
.eq:	move.b	(a0)+,d0
	beq.s	.rom
	cmp.b	#'=',d0
	beq.s	.next
	bra.s	.eq
.rom:	lea	HyArgPath,a1		; the first file name only
	tst.b	(a1)
	beq.s	.cpr
	IFEQ	HY_MENUTEST-2
	lea	HyArgPath2,a1		; (test) the second cartridge
	tst.b	(a1)
	beq.s	.cpr
	ENDC
	bra.w	.next
.cpr:	lea	LupaW,a0
.c2:	move.b	(a0)+,(a1)+
	bne.s	.c2
	bra.w	.next
.x:	movem.l	(sp)+,d0-d7/a0-a6
	rts

; ---- LupaWord: a2 = the line -> the next word in LupaW (at most LupaMax-1 characters), a2 past
; it. d0 = its length, -1 at the end of the line; d2 = 1 if it was "quoted". Quotes inside a
; word (KEY="a b") keep its blanks, the quotes left out.
LupaWord:
	lea	LupaW,a1
	moveq	#0,d2
	move.w	#LupaMax-1,d1
.sp:	move.b	(a2)+,d0
	beq.s	.end
	cmp.b	#' ',d0
	bls.s	.sp
	cmp.b	#'"',d0
	bne.s	.put
	moveq	#1,d2
.q:	move.b	(a2)+,d0		; inside quotes
	beq.s	.we			; (the line ends inside the quotes)
	cmp.b	#'"',d0
	beq.s	.qx
	bsr.s	.st
	bra.s	.q
.qx:	tst.b	d2			; a "quoted" word ends at its quote; KEY="a b" goes on
	bne.s	.done
	bra.s	.w
.put:	bsr.s	.st
.w:	move.b	(a2)+,d0
	beq.s	.we
	cmp.b	#'"',d0
	beq.s	.q
	cmp.b	#' ',d0
	bhi.s	.put
	bra.s	.done
.st:	subq.w	#1,d1			; one character, LupaMax-1 at most
	bmi.s	.sx
	move.b	d0,(a1)+
.sx:	rts
.we:	subq.l	#1,a2
.done:	clr.b	(a1)
	move.l	a1,d0
	sub.l	#LupaW,d0
	rts
.end:	subq.l	#1,a2
	moveq	#-1,d0
	rts

; ---- LupaKey: LupaW against LupaKeys (any case, the whole word or up to '=') -> d0 = its
; number or -1, a1 = the value after '=' or 0
LupaKey:
	lea	LupaKeys(pc),a1
	moveq	#0,d0
.k:	tst.b	(a1)
	beq.s	.no
	lea	LupaW,a0
.c:	move.b	(a0)+,d1
	cmp.b	#'a',d1
	bcs.s	.u
	cmp.b	#'z',d1
	bhi.s	.u
	sub.b	#32,d1
.u:	move.b	(a1)+,d2
	beq.s	.ke			; the key ends: so must the word, or go on with '='
	cmp.b	d2,d1
	beq.s	.c
.sk:	tst.b	(a1)+			; the next key
	bne.s	.sk
	addq.l	#1,d0
	bra.s	.k
.ke:	tst.b	d1			; (a1 is at the next key now)
	beq.s	.y0
	cmp.b	#'=',d1
	bne.s	.nx
	move.l	a0,a1			; KEY=value
	rts
.y0:	sub.l	a1,a1
	rts
.nx:	addq.l	#1,d0
	bra.s	.k
.no:	moveq	#-1,d0
	rts

; ---- HyAutoStart, first: the ToolTypes (Workbench), the display word. Z clear: no start, the
; program quits (bad arguments).
LupaPrep:
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	MENSWB,d0
	beq.s	.disp
	move.l	d0,a2
	bsr.w	LupaWB
.disp:	move.b	LupaDisp,d0
	cmp.b	#3,d0
	beq.s	.bad
	IFD	GBC_RTG
	cmp.b	#1,d0			; AGA asked of the RTG program: RTG
	ELSE
	cmp.b	#2,d0			; RTG asked of an AGA program: AGA
	ENDC
	bne.s	.ok
	moveq	#5,d0
	bsr.w	LupaSetRC
.ok:	moveq	#0,d0
	bra.s	.x
.bad:	move.l	#tLupaBad,LupaErrText
	move.l	#tLupaArgs,LupaEArgs
	moveq	#10,d0
	bsr.w	LupaSetRC
	st	LupaQuit
	moveq	#1,d0
.x:	movem.l	(sp)+,d0-d7/a0-a6	; (the flags stay)
	rts

; ---- Workbench (a2 = the start-up message): the ToolTypes of the last WBArg's icon
LupaWB:
	move.l	$1c(a2),d2		; sm_NumArgs
	beq.w	.x
	move.l	$24(a2),a3		; sm_ArgList
	subq.l	#1,d2
	lsl.l	#3,d2
	add.l	d2,a3			; the last WBArg
	move.l	4.w,a6
	lea	LupaIconNom(pc),a1
	moveq	#36,d0
	jsr	-552(a6)		; OpenLibrary
	move.l	d0,d5
	beq.w	.x
	move.l	(a3),d1			; wa_Lock
	move.l	HyDosBase,a6
	jsr	-126(a6)		; CurrentDir
	move.l	d0,d3
	move.l	4(a3),a0		; wa_Name
	move.l	d5,a6
	jsr	-78(a6)			; GetDiskObject
	move.l	d0,d4
	move.l	d3,d1
	move.l	HyDosBase,a6
	jsr	-126(a6)		; CurrentDir back
	tst.l	d4
	beq.s	.cl
	move.l	d5,a6
	move.l	d4,a0
	tst.l	$36(a0)			; do_ToolTypes
	beq.s	.fr
	lea	LupaKAga(pc),a1
	bsr.s	.find
	beq.s	.t1
	or.b	#1,LupaDisp
.t1:	lea	LupaKRtg(pc),a1
	bsr.s	.find
	beq.s	.t2
	or.b	#2,LupaDisp
.t2:	lea	LupaKOne(pc),a1
	bsr.s	.find
	beq.s	.t3
	st	LupaOne
.t3:	lea	LupaKMenu(pc),a1
	bsr.s	.find
	beq.s	.fr
	st	LupaMenu
.fr:	move.l	d4,a0
	jsr	-90(a6)			; FreeDiskObject
.cl:	move.l	d5,a1
	move.l	4.w,a6
	jsr	-414(a6)		; CloseLibrary
.x:	rts
.find:	move.l	d4,a0			; a1 = the name -> d0 = its value or 0 (Z)
	move.l	$36(a0),a0
	jsr	-96(a6)			; FindToolType
	tst.l	d0
	rts

; ---- HyAutoStart, for HyAutoInsert: the ROM in HyArgPath -> Z clear: Power On now
LupaInsert:
	movem.l	d1-d7/a0-a6,-(sp)
	lea	HyArgPath,a0		; the name for the requester (HyAutoInsert clears it)
	lea	LupaName,a1
	move.w	#LupaMax-2,d0
.c:	move.b	(a0)+,(a1)+
	dbeq	d0,.c
	clr.b	(a1)
	move.b	LupaOne,LupaCatch	; ONEGAME: ImpError's message is kept for Workbench
	sf	LupaErr
	jsr	HyAutoInsert
	tst.b	LupaErr
	bne.s	.err
	tst.l	BucCart
	beq.s	.err
	tst.b	LupaMenu
	bne.s	.no
	moveq	#1,d0
	bra.s	.x
.err:	tst.b	LupaOne
	beq.s	.no			; (the error was in the menu, as before)
	tst.l	LupaErrText
	bne.s	.e10
	move.l	#tLupaNoLoad,LupaErrText
.e10:	moveq	#10,d0
	bsr.s	LupaSetRC
	st	LupaQuit
.no:	sf	LupaCatch
	moveq	#0,d0
.x:	movem.l	(sp)+,d1-d7/a0-a6
	rts

; ---- HyAutoStart, after Power On (the game was left, or Power On met an error)
LupaAfter:
	move.l	d0,-(sp)
	sf	LupaCatch
	tst.b	LupaErr
	bne.s	.err
	tst.b	LupaOne
	beq.s	.x
	st	LupaQuit		; ONEGAME: the program quits
	bra.s	.x
.err:	moveq	#10,d0			; a Colour-only cart without colour, an unknown type,
	IFD	GBC_RTG			; out of memory; no RTG screen: 20
	cmp.l	#tHyErrRtg,LupaErrText
	bne.s	.rc
	moveq	#20,d0
.rc:
	ENDC
	bsr.s	LupaSetRC
	st	LupaQuit
.x:	move.l	(sp)+,d0
	rts

; ---- d0 = a return code: kept if it is higher than the one so far
LupaSetRC:
	cmp.l	LupaRC,d0
	bls.s	.x
	move.l	d0,LupaRC
.x:	rts

; ---- Juan's ImpError, while LupaCatch is set: a0 = the message (icon, line, 0, line, 0);
; kept for LupaShowErr, nothing shown in the menu
LupaCaught:
	tst.l	LupaErrText
	bne.s	.x
	move.l	a0,LupaErrText
.x:	st	LupaErr
	rts

; ---- Juan's Programa after MiraAGA / MC68020: d0 = 0 (the user quits there) -> return code 20.
; d0 and Z kept.
LupaRun20:
	tst.l	d0
	bne.s	.x
	move.l	#20,LupaRC
.x:	tst.l	d0
	rts

; ---- Juan's BucleMenu: ONEGAME after the game: the battery save prompt as Quit has it -> Z clear:
; the program quits now (no Quit requester); Z set: the menu (Cancel, or nothing to do)
LupaLeave:
	movem.l	d0-d7/a0-a6,-(sp)
	tst.b	LupaQuit
	beq.s	.no
	sf	LupaQuit
	tst.l	LupaErrText		; nothing ran: no prompt
	bne.s	.yes
	jsr	ActuPrefs
	tst.b	DirPrefs+$0C		; save the battery file without asking
	bne.s	.save
	jsr	AskSaveBatt
	tst.l	d0
	bmi.s	.no			; Cancel: the menu stays
	bra.s	.yes
.save:	jsr	SaveBatt
.yes:	moveq	#1,d0
	bra.s	.x
.no:	moveq	#0,d0
.x:	movem.l	(sp)+,d0-d7/a0-a6	; (the flags stay)
	rts

; ---- Juan's Quitar, after CloseDownScreen: a kept load error on the Workbench screen
LupaShowErr:
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	LupaErrText,d0
	beq.w	.x
	move.l	_IntuitionBase,d1
	beq.w	.x
	move.l	d0,a0
	addq.l	#1,a0			; past the icon number
	move.l	a0,LupaEArgs+4
.n:	tst.b	(a0)+
	bne.s	.n
	move.l	a0,LupaEArgs+8
	move.l	d1,a6
	sub.l	a0,a0
	lea	LupaEasy(pc),a1
	sub.l	a2,a2
	lea	LupaEArgs,a3
	IFND	HY_LUPAREQ
	jsr	-588(a6)		; EasyRequestArgs
	ELSE
	moveq	#0,d0			; test: the requester goes after HY_LUPAREQ ticks
	jsr	-594(a6)		; BuildEasyRequestArgs
	move.l	d0,d7
	cmp.l	#1,d7
	bls.s	.x
	move.l	#HY_LUPAREQ,d6
.w:	move.l	d7,a0
	sub.l	a1,a1
	moveq	#0,d0
	move.l	_IntuitionBase,a6
	jsr	-600(a6)		; SysReqHandler, no waiting
	cmp.l	#-2,d0
	bne.s	.f
	move.l	HyDosBase,a6
	moveq	#1,d1
	jsr	-198(a6)		; Delay
	subq.l	#1,d6
	bne.s	.w
.f:	move.l	d7,a0
	move.l	_IntuitionBase,a6
	jsr	-372(a6)		; FreeSysRequest
	ENDC
.x:	movem.l	(sp)+,d0-d7/a0-a6
	rts

; ---- OS alive: wait until no key, mouse button or fire button is held, 1 s at most
; (keyboard.device's matrix; CIA-A PRA bits 6/7, POTINP bits 10/14). Caps Lock is left out
; (its LED keeps it down). Every register kept.
LupaSettle:
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	4.w,a6
	jsr	-666(a6)		; CreateMsgPort
	move.l	d0,d6
	beq.w	.x
	move.l	d0,a0
	moveq	#48,d0			; IOStdReq
	jsr	-654(a6)		; CreateIORequest
	move.l	d0,d5
	beq.w	.nio
	lea	LupaKbdNom(pc),a0
	moveq	#0,d0
	move.l	d5,a1
	moveq	#0,d1
	jsr	-444(a6)		; OpenDevice
	tst.l	d0
	bne.w	.ndev
	moveq	#50,d4			; 50 ticks
.poll:	lea	LupaMatrix,a0
	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)
	move.l	d5,a1
	move.w	#10,28(a1)		; KBD_READMATRIX
	move.l	#16,36(a1)		; io_Length
	move.l	#LupaMatrix,40(a1)	; io_Data
	move.l	4.w,a6
	jsr	-456(a6)		; DoIO
	lea	LupaMatrix,a0
	and.b	#$fb,12(a0)		; Caps Lock ($62)
	move.l	(a0)+,d0
	or.l	(a0)+,d0
	or.l	(a0)+,d0
	or.l	(a0),d0
	bne.s	.held
	move.b	$bfe001,d0
	not.b	d0
	and.b	#$c0,d0			; left mouse button, port 2 fire
	bne.s	.held
	move.w	$dff016,d0
	not.w	d0
	and.w	#$4400,d0		; right mouse button, port 2 second button
	beq.s	.up
.held:	move.l	HyDosBase,d0
	beq.s	.up
	move.l	d0,a6
	moveq	#1,d1
	jsr	-198(a6)		; Delay
	subq.l	#1,d4
	bne.s	.poll
.up:	move.l	4.w,a6
	move.l	d5,a1
	jsr	-450(a6)		; CloseDevice
.ndev:	move.l	d5,a0
	jsr	-660(a6)		; DeleteIORequest
.nio:	move.l	d6,a0
	jsr	-672(a6)		; DeleteMsgPort
.x:	movem.l	(sp)+,d0-d7/a0-a6
	rts

LupaKeys:	dc.b	"AGA",0,"RTG",0,"ONEGAME",0,"MENU",0
		dc.b	"PROFILE",0,"RTGMODE",0,"PREFS",0,"P",0,0
LupaKAga:	dc.b	"AGA",0
LupaKRtg:	dc.b	"RTG",0
LupaKOne:	dc.b	"ONEGAME",0
LupaKMenu:	dc.b	"MENU",0
LupaIconNom:	dc.b	"icon.library",0
LupaKbdNom:	dc.b	"keyboard.device",0
LupaETitle:	dc.b	"AmiGameBoy",0
LupaEFormat:	dc.b	"%s",10,10,"%s",10,"%s",0
LupaEGad:	dc.b	"OK",0
	cnop	0,4
LupaEasy:	dc.l	20,0,LupaETitle,LupaEFormat,LupaEGad

	SECTION	hybriddata,DATA
tLupaBad:	dc.b	4,"AGA and RTG both given",0,"Give one of them, or neither",0
tLupaNoLoad:	dc.b	0,"The cartridge was not loaded",0,"",0
tLupaArgs:	dc.b	"Arguments",0
LupaDisp:	dc.b	0		; 1 AGA, 2 RTG, 3 both (bad)
LupaOne:	dc.b	0		; ONEGAME
LupaMenu:	dc.b	0		; MENU
LupaCatch:	dc.b	0		; ImpError's message goes to LupaCaught
LupaErr:	dc.b	0		; LupaCaught had one
LupaQuit:	dc.b	0		; BucleMenu: the program quits (ONEGAME)
	cnop	0,4
LupaRC:		dc.l	0		; the program's return code
LupaErrText:	dc.l	0		; the kept message (Juan's form)
LupaEArgs:	dc.l	LupaName,0,0	; the requester's name, line, line
	SECTION	hybridbss,BSS
LupaName:	ds.b	LupaMax
LupaW:		ds.b	LupaMax
LupaLine:	ds.b	LupaLineMax
LupaMatrix:	ds.b	16
	SECTION	hybrid,CODE

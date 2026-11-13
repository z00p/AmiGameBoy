; AmiGameBoy hybrid: CD32 pad button mapping and its settings file.
; Copyright (C) 2026 AmiGameBoy contributors. GPL-2 (see src/engine/COPYING).
;
; HyPadApply  every Game Boy frame (hybrid_frame): the pad's buttons through HyPadMap.
; HyPadCfg    menu build, once, when the menu's window first opens (the OS is alive):
;             PROGDIR:AmiGameBoy.config read into HyPadMap, or written with the
;             defaults when there is none. Not earlier: started from Workbench, the
;             start-up message must be off the process port (Juan's menu takes it)
;             before any dos.library call, whose replies come to the same port.
;             The cartridge-inside test builds have the defaults and no file.
;
; The file, one button a line, upper or lower case, ; starts a comment:
;   Red = A        buttons: Red Blue Green Yellow L R Play
;                  choices: A B Select Start Up Down Left Right Nothing
; A line that does not parse leaves that button as it was (the default).
; A shoulder button held with Play goes back to the menu whatever the file says.
;
; All of it sits in sections of its own: nothing in the engine's section moves (the
; 68030's instruction cache, see NO_IDLEPAD). NO_PADMAP leaves this file out.

	SECTION	hypad,CODE

; d0.b = pad buttons from ReadCD32Pads (blue red yellow green R L play), a3 = Regs.
; d0-d2/a0 used.
HyPadApply:
	btst	#1,d0			; a pad's red and blue are also the joystick's two
	beq.s	.nored			; fire lines, which the joystick read took for A and
	bset	#0,EstadoJoy+1(a3)	; B: take those back, the table decides
.nored:	btst	#0,d0
	beq.s	.noblu
	bset	#1,EstadoJoy+1(a3)
.noblu:	move.b	EstadoKeys+1(a3),d1	; (the keyboard's buttons again, as HyPads)
	and.b	EstadoKeys+2(a3),d1
	and.b	d1,EstadoJoy+1(a3)
	moveq	#0,d1
	lea	HyPadMap,a0
	moveq	#7-1,d2
.bit:	lsr.b	#1,d0
	bcc.s	.up
	or.w	(a0),d1
.up:	addq.l	#2,a0
	dbra	d2,.bit
	not.w	d1			; low active, on top of the joystick and keys
	and.b	d1,EstadoJoy+1(a3)	; A B Select Start
	lsr.w	#8,d1
	and.b	d1,EstadoJoy+2(a3)	; Right Left Up Down
	rts

	IFD	HY_MENU
PADBUF		=2048			; the file is read up to here
pr_WindowPtr	=$b8

; everything preserved; ends in HyAutoStart (whose call in Juan's menu this one replaces)
HyPadCfg:
	tas	HyPadRead
	beq.s	.first
	jmp	HyAutoStart
.first:	movem.l	d0-d7/a0-a6,-(sp)
	move.l	4.w,a6
	sub.l	a1,a1
	jsr	-294(a6)		; FindTask
	move.l	d0,a5
	move.l	pr_WindowPtr(a5),d7	; no "volume is write protected" requesters
	moveq	#-1,d0
	move.l	d0,pr_WindowPtr(a5)
	move.l	HyDosBase,a6
	move.l	#HyPadCfgName,d1
	move.l	#1005,d2		; MODE_OLDFILE
	jsr	-30(a6)			; Open
	move.l	d0,d4
	beq.s	.new
	lea	-PADBUF(sp),sp
	move.l	d4,d1
	move.l	sp,d2
	move.l	#PADBUF,d3
	jsr	-42(a6)			; Read
	move.l	d0,d5
	move.l	d4,d1
	jsr	-36(a6)			; Close
	move.l	sp,a0
	tst.l	d5
	ble.s	.read
	lea	(a0,d5.l),a1
	bsr.s	HyPadParse
	IFD	HY_BEZHOOK		; the other settings in the same text (bezel.s)
	move.l	sp,a0
	jsr	HyCfgExtra
	ENDC
.read:	lea	PADBUF(sp),sp
	bra.s	.done
.new:	move.l	#HyPadCfgName,d1	; none: write the defaults, to be edited
	move.l	#1006,d2		; MODE_NEWFILE
	jsr	-30(a6)
	move.l	d0,d4
	beq.s	.done			; (a read-only drawer: defaults, no file)
	move.l	d4,d1
	move.l	#HyPadCfgText,d2
	move.l	#HyPadCfgEnd-HyPadCfgText,d3
	jsr	-48(a6)			; Write
	move.l	d4,d1
	jsr	-36(a6)
.done:
	IFD	HY_PADTEST		; test: the table as read -> PROGDIR:AmiGameBoy.padmap
	move.l	#HyPadTestName,d1
	move.l	#1006,d2
	jsr	-30(a6)
	move.l	d0,d4
	beq.s	.notest
	move.l	d4,d1
	move.l	#HyPadMap,d2
	moveq	#14,d3
	jsr	-48(a6)
	move.l	d4,d1
	jsr	-36(a6)
.notest:
	ENDC
	move.l	d7,pr_WindowPtr(a5)
	movem.l	(sp)+,d0-d7/a0-a6
	jmp	HyAutoStart

; a0 = text, a1 = its end
HyPadParse:
.line:	bsr.s	.blank
	cmp.l	a1,a0
	bcc.s	.x
	lea	HyPadKeys(pc),a2
	bsr.s	.match			; the button -> its place in HyPadMap
	beq.s	.skip
	move.w	d0,d6
	bsr.s	.blank
	cmp.l	a1,a0
	bcc.s	.x
	cmp.b	#"=",(a0)
	bne.s	.skip
	addq.l	#1,a0
	bsr.s	.blank
	lea	HyPadVals(pc),a2
	bsr.s	.match			; the choice -> its bits
	beq.s	.skip
	lea	HyPadMap,a2
	move.w	d0,(a2,d6.w*2)
.skip:	cmp.l	a1,a0			; to the end of the line
	bcc.s	.x
	cmp.b	#10,(a0)+
	bne.s	.skip
	bra.s	.line
.x:	rts

; over spaces, tabs and CRs
.blank:	cmp.l	a1,a0
	bcc.s	.bx
	move.b	(a0),d0
	cmp.b	#" ",d0
	beq.s	.b1
	cmp.b	#9,d0
	beq.s	.b1
	cmp.b	#13,d0
	bne.s	.bx
.b1:	addq.l	#1,a0
	bra.s	.blank
.bx:	rts

; the word at a0 in the list at a2 (NAME,0, even, value.w; ends with a 0), any case, a
; whole word only -> Z clear, d0.w = value, a0 behind the word; Z set: not there
.match:
.m0:	tst.b	(a2)
	beq.s	.mfail
	move.l	a0,a4
.m1:	move.b	(a2)+,d1
	beq.s	.mend
	cmp.l	a1,a4
	bcc.s	.mno
	move.b	(a4)+,d0
	cmp.b	#"a",d0
	bcs.s	.mu
	cmp.b	#"z",d0
	bhi.s	.mu
	sub.b	#32,d0
.mu:	cmp.b	d0,d1
	beq.s	.m1
.mno:	tst.b	(a2)+			; the rest of the name
	bne.s	.mno
	bra.s	.mnext
.mend:	cmp.l	a1,a4			; the text's word must end here too
	bcc.s	.mok
	move.b	(a4),d0
	and.b	#$df,d0
	cmp.b	#"A",d0
	bcs.s	.mok
	cmp.b	#"Z",d0
	bhi.s	.mok
.mnext:	move.l	a2,d0			; over the value
	addq.l	#1,d0
	and.w	#$fffe,d0
	move.l	d0,a2
	addq.l	#2,a2
	bra.s	.m0
.mok:	move.l	a2,d0
	addq.l	#1,d0
	and.w	#$fffe,d0
	move.l	d0,a2
	move.w	(a2),d0
	move.l	a4,a0
	moveq	#1,d1			; Z clear
	rts
.mfail:	moveq	#0,d1			; Z set
	rts

; places in HyPadMap = ReadCD32Pads' bit numbers
HyPadKeys:
	dc.b	"RED",0
	dc.w	1
	dc.b	"BLUE",0
	even
	dc.w	0
	dc.b	"GREEN",0
	dc.w	3
	dc.b	"YELLOW",0
	even
	dc.w	2
	dc.b	"L",0
	dc.w	5
	dc.b	"R",0
	dc.w	4
	dc.b	"PLAY",0
	even
	dc.w	6
	dc.b	0
	even
	ENDC

PAD_A		=$0001			; low byte: buttons_byte's bits
PAD_B		=$0002
PAD_SELECT	=$0004
PAD_START	=$0008
PAD_RIGHT	=$0100			; high byte: directions_byte's bits
PAD_LEFT	=$0200
PAD_UP		=$0400
PAD_DOWN	=$0800

	IFD	HY_MENU
HyPadVals:
	dc.b	"A",0
	dc.w	PAD_A
	dc.b	"B",0
	dc.w	PAD_B
	dc.b	"SELECT",0
	even
	dc.w	PAD_SELECT
	dc.b	"START",0
	dc.w	PAD_START
	dc.b	"UP",0
	even
	dc.w	PAD_UP
	dc.b	"DOWN",0
	even
	dc.w	PAD_DOWN
	dc.b	"LEFT",0
	even
	dc.w	PAD_LEFT
	dc.b	"RIGHT",0
	dc.w	PAD_RIGHT
	dc.b	"NOTHING",0
	dc.w	0
	dc.b	0
	even
	ENDC

	SECTION	hypaddata,DATA
HyPadMap:				; blue red yellow green R L play
	dc.w	PAD_B,PAD_A,PAD_SELECT,PAD_B,0,0,PAD_START
	IFD	HY_MENU
HyPadRead:	dc.b	0,0
HyPadCfgName:	dc.b	"PROGDIR:AmiGameBoy.config",0
	IFD	HY_PADTEST
HyPadTestName:	dc.b	"PROGDIR:AmiGameBoy.padmap",0
	ENDC
HyPadCfgText:
	dc.b	"; AmiGameBoy: what the CD32 pad's buttons do. Read when AmiGameBoy starts.",10
	dc.b	"; Edit and save; delete this file to get the defaults back.",10
	dc.b	"; Choices: A, B, Select, Start, Up, Down, Left, Right, Nothing",10
	dc.b	"; A shoulder button held with Play always goes back to the menu.",10
	dc.b	"Red = A",10
	dc.b	"Blue = B",10
	dc.b	"Green = B",10
	dc.b	"Yellow = Select",10
	dc.b	"L = Nothing",10
	dc.b	"R = Nothing",10
	dc.b	"Play = Start",10
	IFND	NO_BEZEL
	dc.b	"; Bezel = On draws a handheld around the picture.",10
	dc.b	"Bezel = Off",10
	ENDC
	IFND	NO_TINT
	dc.b	"; Tint: Grey (the palette chosen in the menu), Green or Yellow.",10
	dc.b	"Tint = Grey",10
	ENDC
HyPadCfgEnd:
	even
	ENDC

	SECTION	hybrid,CODE

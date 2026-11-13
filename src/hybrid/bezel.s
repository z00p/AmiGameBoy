; AmiGameBoy hybrid: the optional bezel and the LCD tint.
; Copyright (C) 2026 AmiGameBoy contributors. GPL-2 (see src/engine/COPYING).
;
; Bezel. Juan's renderer has all 8 bitplanes (two 16-colour playfields of sprites) and
; all 8 hardware sprites (background and window) busy on the 144 picture lines, and its
; display window is the picture alone. So the bezel is not in its planes: the copper
; switches in an own 320-pixel, 16-colour lowres display above and below the picture
; (art from tools/bezel_art.py, data/bezel.raw, colours 224-239 through BPLCON4's
; XOR), and the picture lines stay as they are with a black border, a lens band across
; the whole width. Nothing is drawn or copied per frame: HyBezPrefs fills three blocks
; reserved in Juan's copper list once per start (and again after the menu). Off: the
; blocks stay copper no-ops and the list does what it did.
;
;   lines $2C-$46  top band       T block (frame top): the window is lines $2C-$46
;   line  $47      black          R block: Juan's window ($48-$D8), fetch, planes, BPLCONs
;   lines $48-$D7  the picture    Juan's list, as ever
;   line  $D8      black          B block: the window opens again for lines $D9-$12B
;   lines $D9-$12B bottom band    (NTSC game speed/60 Hz modes show less of it)
; On the two black lines the window is shut (no fetch, border). The art has no colour
; 0: every band pixel is opaque and in front of the sprites, whose data streams go on
; below the picture (leftovers that Juan's window used to hide).
;
; Tint. Grey leaves the palette the menu chose; Green and Yellow replace it with LCD
; shades. GBPaleta is the only place the renderer takes its four shades from (line 0,
; BGP per line, OBP per line in linepal.s), so that is all there is to it.
;
; Settings: PROGDIR:AmiGameBoy.config, "Bezel = On|Off", "Tint = Grey|Green|Yellow"
; (HyCfgExtra, called by padcfg.s on the text it read; a line that does not parse
; leaves the default). Test builds without the menu: HY_BEZEL=1, HY_TINT=1|2.
;
; All in sections of their own (the 68030's instruction cache, see NO_IDLEPAD): the
; two call sites replace instructions of the same size. NO_BEZEL and NO_TINT leave
; each half out; both set, this file is not included.

	SECTION	hybez,CODE

; a0 = the palette's four words (Juan's table). Does the instruction it replaced
; (move.l (a0)+,GBPaleta); the caller's move.l (a0),GBPaleta+4 follows. All kept.
HyBezPrefs:
	move.l	(a0)+,GBPaleta
	IFND	NO_TINT
	move.l	d0,-(sp)
	move.w	HyTint,d0
	beq.s	.grey
	lea	HyTintPal-8,a0
	lea	(a0,d0.w*8),a0
	move.l	(a0)+,GBPaleta
.grey:	move.l	(sp)+,d0
	ENDC
	IFND	NO_BEZEL
	tst.w	HyBezel
	beq.s	.x
	movem.l	d0-d7/a0-a6,-(sp)
	bsr.s	HyBezOn
	movem.l	(sp)+,d0-d7/a0-a6
.x:
	ENDC
	rts

	IFND	NO_BEZEL
BEZ_TOP		=27			; rows of the top band (lines $2C-$46)
BEZ_BOT		=83			; rows of the bottom band (lines $D9-$12B)
BEZ_BPR		=40			; bytes a row

HyBezOn:
	lea	DirPlanos,a0		; Juan's plane pointers into PLANO0/1 (CongelaAMIGA
	jsr	CreaPlanos		; does the same later; we copy them now)
; T: frame top. Colours 224-239, the band's window, fetch and planes.
	lea	BezCopT,a1
	move.l	#$0106E020,(a1)+	; colour bank 7
	lea	BezRaw,a2
	move.w	#$0180,d0
	moveq	#16-1,d1
.col:	move.w	d0,(a1)+
	move.w	(a2)+,(a1)+
	addq.w	#2,d0
	dbra	d1,.col
	move.l	#$01060020,(a1)+	; bank 0, black border
	move.l	#$008E2C81,(a1)+	; window $81-$1C1, lines $2C-$46
	move.l	#$009047C1,(a1)+
	move.l	#$01E42000,(a1)+	; (DIWHIGH: the stop is line $47, not $147)
	move.l	#BezTop,d0
	move.l	#BEZ_TOP*BEZ_BPR,d1
	bsr.w	.band
	move.l	#$01004201,(a1)+	; 4 planes
; R: after the timer wait at line $40. Planes 5-8 at once (the band has four), the
; rest on line $47, done before his BPLCON0 move at $69 and his first line's set-up.
	lea	BezCopR,a1
	lea	PLANO0,a2
	move.l	16(a2),(a1)+
	move.l	20(a2),(a1)+
	move.l	24(a2),(a1)+
	move.l	28(a2),(a1)+
	move.l	48(a2),(a1)+		; (PLANO1 follows PLANO0)
	move.l	52(a2),(a1)+
	move.l	56(a2),(a1)+
	move.l	60(a2),(a1)+
	move.l	#$4701FFFE,(a1)+
	move.l	#$008E48B1,(a1)+	; his window, fetch and modulos (Copper:)
	move.l	#$0090D851,(a1)+
	move.l	#$00920040,(a1)+
	move.l	#$009400B8,(a1)+
	move.l	#$0108FFF8,(a1)+
	move.l	#$010AFFF8,(a1)+
	move.l	(a2)+,(a1)+
	move.l	(a2)+,(a1)+
	move.l	(a2)+,(a1)+
	move.l	(a2)+,(a1)+
	lea	16(a2),a2
	move.l	(a2)+,(a1)+
	move.l	(a2)+,(a1)+
	move.l	(a2)+,(a1)+
	move.l	(a2)+,(a1)+
	move.w	#$0102,(a1)+		; his four moves of line $40, taken out below
	move.w	ScrBits+2,(a1)+
	move.l	#$01040007,(a1)+
	move.w	#$0106,(a1)+
	move.w	BpCon3+2,d0
	or.w	#$0020,d0		; black border whatever the menu says: the lens
	move.w	d0,(a1)+
	move.l	#$010C0011,(a1)+
	move.w	#$01FE,d0		; copper no-op
	move.w	d0,ScrBits
	move.w	d0,ScrBits+4
	move.w	d0,BpCon3
	move.w	d0,BpCon3+4
; B: his window has closed at line $D8; ours opens again at $D9.
	lea	BezCopB,a1
	move.l	#$D7DFFFFE,(a1)+
	move.l	#$008ED981,(a1)+	; window $81-$1C1, lines $D9-$12B
	move.l	#$00902CC1,(a1)+
	move.l	#BezBot,d0
	move.l	#BEZ_BOT*BEZ_BPR,d1
	bsr.s	.band
	move.l	#$01060020,(a1)+
	move.l	#$01004201,(a1)+
	rts

; a band's display: d0 = its first plane, d1 = bytes a plane
.band:	move.l	#$010CE011,(a1)+	; pixels XOR $E0 (sprite banks as Juan's)
	move.l	#$01040000,(a1)+	; planes in front of the sprites (see below)
	move.l	#$00920028,(a1)+	; 64-bit fetch: five units, 320 pixels from $81
	move.l	#$009400A0,(a1)+
	move.l	#$01080000,(a1)+
	move.l	#$010A0000,(a1)+
	move.w	#$00E0,d2
	moveq	#4-1,d3
.bp:	move.w	d2,(a1)+
	swap	d0
	move.w	d0,(a1)+
	addq.w	#2,d2
	move.w	d2,(a1)+
	swap	d0
	move.w	d0,(a1)+
	addq.w	#2,d2
	add.l	d1,d0
	dbra	d3,.bp
	move.l	#$01020000,(a1)+	; no scroll
	rts
	ENDC

	IFD	HY_PADCFG
; The settings in the config text: a0 = text, a1 = its end. d0-d5/a0/a2-a4 used.
HyCfgExtra:
.line:	move.l	a0,a4
	bsr.s	.blank
	move.l	a4,a0
	cmp.l	a1,a0
	bcc.s	.x
	lea	HyCfgTab(pc),a2
.ent:	tst.b	(a2)
	beq.s	.skip
	move.l	a0,a4
	bsr.s	.word			; the setting
	move.b	d2,d3
	bsr.s	.blank
	cmp.l	a1,a4
	bcc.s	.noeq
	cmp.b	#"=",(a4)+
	beq.s	.eq
.noeq:	moveq	#0,d3
.eq:	bsr.s	.blank
	bsr.s	.word			; its value
	and.b	d2,d3
	move.l	a2,d0
	addq.l	#1,d0
	and.w	#$fffe,d0
	move.l	d0,a2
	move.w	(a2)+,d4		; where
	move.w	(a2)+,d5		; what
	tst.b	d3
	beq.s	.ent
	lea	HyBezel,a3
	move.w	d5,(a3,d4.w)
.skip:	cmp.l	a1,a0			; to the end of the line
	bcc.s	.x
	cmp.b	#10,(a0)+
	bne.s	.skip
	bra.s	.line
.x:	rts

; a4 over spaces, tabs and CRs
.blank:	cmp.l	a1,a4
	bcc.s	.bx
	move.b	(a4),d0
	cmp.b	#" ",d0
	beq.s	.b1
	cmp.b	#9,d0
	beq.s	.b1
	cmp.b	#13,d0
	bne.s	.bx
.b1:	addq.l	#1,a4
	bra.s	.blank
.bx:	rts

; the upper-case word at a2 (ends with 0) against the text at a4, any case, a whole
; word only: d2 = 1 and a4 behind it, or d2 = 0. a2 always ends behind the 0.
.word:	moveq	#1,d2
.w1:	move.b	(a2)+,d1
	beq.s	.wend
	tst.b	d2
	beq.s	.w1
	cmp.l	a1,a4
	bcc.s	.wf
	move.b	(a4)+,d0
	cmp.b	#"a",d0
	bcs.s	.wu
	cmp.b	#"z",d0
	bhi.s	.wu
	sub.b	#32,d0
.wu:	cmp.b	d0,d1
	beq.s	.w1
.wf:	moveq	#0,d2
	bra.s	.w1
.wend:	tst.b	d2
	beq.s	.wx
	cmp.l	a1,a4
	bcc.s	.wx
	move.b	(a4),d0
	and.b	#$df,d0
	cmp.b	#"A",d0
	bcs.s	.wx
	cmp.b	#"Z",d0
	bhi.s	.wx
	moveq	#0,d2
.wx:	rts

; setting,0,value,0, even, where.w (from HyBezel), what.w; ends with a 0
HyCfgTab:
	IFND	NO_BEZEL
	dc.b	"BEZEL",0,"ON",0
	even
	dc.w	0,1
	dc.b	"BEZEL",0,"OFF",0
	even
	dc.w	0,0
	ENDC
	IFND	NO_TINT
	dc.b	"TINT",0,"GREY",0
	even
	dc.w	2,0
	dc.b	"TINT",0,"GRAY",0
	even
	dc.w	2,0
	dc.b	"TINT",0,"GREEN",0
	even
	dc.w	2,1
	dc.b	"TINT",0,"YELLOW",0
	even
	dc.w	2,2
	ENDC
	dc.b	0
	even
	ENDC

	SECTION	hybezdata,DATA
	IFND	HY_BEZEL
HY_BEZEL	=0
	ENDC
	IFND	HY_TINT
HY_TINT		=0
	ENDC
HyBezel:	dc.w	HY_BEZEL	; 0 off, 1 on
HyTint:		dc.w	HY_TINT		; 0 grey (the menu's palette), 1 green, 2 yellow
	IFND	NO_TINT
HyTintPal:
	dc.w	$0CCA,$08A1,$0363,$0131	; green: the pea-green LCD of the icon art
	dc.w	$0EE8,$0BA4,$0763,$0221	; yellow
	ENDC

	IFND	NO_BEZEL
	SECTION	hybezchip,DATA_C
BezRaw:	INCBIN	"data/bezel.raw"	; tools/bezel_art.py
BezTop	=BezRaw+32
BezBot	=BezTop+4*BEZ_TOP*BEZ_BPR
	ENDC

	SECTION	hybrid,CODE

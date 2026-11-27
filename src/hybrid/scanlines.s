; AmiGameBoy hybrid: Arnold's seven scanline settings on the RTG game screen (GBC_RSTYLE; 2.6).
; Copyright (C) 2026 AmiGameBoy contributors. GPL-2 (see src/engine/COPYING).
;
; The same settings as Arnold, AmiMasterGear, AmiPCEngine and AmiMSX, in Arnold's order: Off,
; Hard 25%, Hard 50%, Hard 75%, Blended light, Blended, Blended strong. Two controls: Scanlines
; Off / On (gbc_rscanon, gbc_rtg.s, as before) and the style (gbc_rstyle: 0-2 Hard 25/50/75%,
; 3-5 Blended light / Blended / Blended strong; default Hard 50%, kept while Scanlines is Off).
; Config (PROGDIR:AmiGameBoy.config, gbc_rcfg in gbc_rtg.s): "Scanlines = On | Off" and
; "ScanlineStyle = 25 | 50 | 75 | blendlight | blend | blendstrong" (also hard25 .. hard75);
; Arnold's single words in Scanlines too ("Scanlines = blend" = On + Blended; "0" = Off).
; The old "Scanlines = On" (2.1-2.5: the last screen row of each picture line at half
; brightness) is On + Hard 50%: the same picture at 2x and 3x (the scales of 960x540 and
; 640x480); at 4x Hard 50% darkens two rows of four where the old On darkened one.
;
; The maths is Arnold's rtgfw (rtgfw.h), per channel in the screen's own bits (5-6-5 or
; 5-5-5), integer division rounded down (decided 27 Nov 2026):
;   Hard n%:  the line, each channel c x (100 - n) / 100
;   Blended:  h(the line) + h(the line below), h(c) = c x (100 - n) / 200 (n = 25, 50, 75 for
;             light, normal, strong); the last line with itself. The halves never carry.
; Of a picture line's s screen rows (s = 2..4) the lower s / 2 are the scanline (one row of
; three at 3x). 1x: no room, the plain picture (as before). Only the Game Boy picture: the bezel
; and the Super Game Boy border are drawn plain, as before.
;
; gbc_rsprep (each copy; works only when the style or the screen format changed) makes
; gbc_rstab: 64K words, one per screen pixel value (signed index from the middle): Hard: the
; scanline pixel in the screen's byte order; Blended: h(pixel) in the CPU's order (the sum is
; swapped back for PC formats). gbc_rscopy replaces gbc_rtg_show's copy loop when Scanlines is
; On at 2x and up: the lines that changed against this buffer's copy get all their rows; with
; Blended a line whose next line changed gets its scanline rows again (found one line ahead,
; so each line is compared once). Rows are built in gbc_rrow / gbc_rrowd (fast RAM) when they
; are copied more than once, else written straight to the screen.
;
; Menus: the Options menu's "Scanline style" sub-menu (RTG, GBC_RMENU; six items, one ticked)
; and, in the big menu's layout (GBC_BIGLAYOUT), a Style selector in Screen Options in place of
; Juan's Refresh selector (never active: always "1 frame"), the rows reordered Screen, LCD fade,
; Surround, Scanlines, Style: an OS 3.2 chooser.gadget pop-up list in the GadTools window
; (AmiPCEngine's and AmiMasterGear's way: the chooser takes the cycle gadget's box, GadTools
; draws only the label), a cycle gadget of the six without chooser.gadget. The Style control
; and the Scanlines one both write both config lines.
;
; GBC_RSDUMP = n (test): from show GBC_RSDUMPAT (default 300) the setting steps through all
; seven every n pictures shown (Off, Hard 25 .. Blended strong); the last picture of each step
; is kept (the buffer's frame copy and its screen rows) and written to GB:AmiGB.scan at
; AutoExit (tools/scancheck.py checks it against a model of the formulas above).

	IFND	GBC_RSCAN
	FAIL	"GBC_RSTYLE needs GBC_RSCAN"
	ENDC

	SECTION	gbcrscode,CODE

; ---- the table for the style and the screen format (if either changed). OS frozen or alive.
; Keeps every register.
gbc_rsprep:
	movem.l	d0-d7/a0-a3,-(sp)
	move.b	gbc_rstyle,d0
	cmp.b	#5,d0
	bls.s	.st
	moveq	#1,d0			; (not a style: Hard 50%)
	move.b	d0,gbc_rstyle
.st:	lsl.w	#8,d0
	move.b	gbc_pixfmt,d0
	cmp.w	gbc_rskey,d0
	beq	.x
	move.w	d0,gbc_rskey
	moveq	#0,d1
	move.b	gbc_rstyle,d1
	moveq	#100,d2
	sub.b	.pct(pc,d1.w),d2	; d2 = 100 - n
	move.w	#100,d3			; the divisor: Hard 100, Blended 200
	cmp.b	#3,d1
	bcs.s	.dv
	move.w	#200,d3
.dv:	lea	gbc_rsch,a0		; channel value c (0-63) -> c * (100 - n) / d
	moveq	#0,d4
.ch:	move.w	d4,d5
	mulu.w	d2,d5
	divu.w	d3,d5
	move.w	d5,(a0)+
	addq.w	#1,d4
	cmp.w	#64,d4
	bne.s	.ch
	lea	gbc_rsch,a0
	lea	gbc_rstab+65536,a1	; the middle
	moveq	#0,d7			; d7.w = the index (the screen's pixel), 65536 of them
	moveq	#0,d6
	move.b	gbc_pixfmt,d6		; bit 0 PC byte order, bit 1 5-5-5
.px:	move.w	d7,d0			; the pixel in the CPU's order
	btst	#0,d6
	beq.s	.n
	ror.w	#8,d0
.n:	btst	#1,d6
	bne.s	.f555
	move.w	d0,d1			; 5-6-5: R 11-15, G 5-10, B 0-4
	lsr.w	#8,d1
	lsr.w	#3,d1
	move.w	(a0,d1.w*2),d4
	lsl.w	#8,d4
	lsl.w	#3,d4
	move.w	d0,d1
	lsr.w	#5,d1
	and.w	#63,d1
	move.w	(a0,d1.w*2),d5
	lsl.w	#5,d5
	or.w	d5,d4
	bra.s	.b
.f555:	move.w	d0,d1			; 5-5-5: R 10-14, G 5-9, B 0-4 (bit 15 0 in the result)
	lsr.w	#8,d1
	lsr.w	#2,d1
	and.w	#31,d1
	move.w	(a0,d1.w*2),d4
	lsl.w	#8,d4
	lsl.w	#2,d4
	move.w	d0,d1
	lsr.w	#5,d1
	and.w	#31,d1
	move.w	(a0,d1.w*2),d5
	lsl.w	#5,d5
	or.w	d5,d4
.b:	move.w	d0,d1
	and.w	#31,d1
	or.w	(a0,d1.w*2),d4
	btst	#0,d6			; Hard in the screen's order; Blended stays in the CPU's
	beq.s	.w
	cmp.b	#2,gbc_rstyle
	bhi.s	.w
	ror.w	#8,d4
.w:	move.w	d4,(a1,d7.w*2)
	addq.w	#1,d7
	bne.s	.px
.x:	movem.l	(sp)+,d0-d7/a0-a3
	rts
.pct:	dc.b	25,50,75,25,50,75
	even

; ---- the copy with scanlines (from gbc_rtg_show, Scanlines On at 2x and up): a0 = the frame,
; a1 = the buffer's picture top left, a4 = the frame as this buffer last got it, a6 = its "every
; line" flag, d5.w = s (2-4), d6.l = bytes per screen row. OS frozen. Changes d0-d7/a0-a5
; (gbc_rtg_show keeps them); a6 kept.
; d3: bit 0 every line, 1 Blended, 2 this line changed, 3 the next line changed (Blended),
; 4 PC byte order. d7 = the line.
gbc_rscopy:
	move.l	a6,-(sp)
	bsr.w	gbc_rsprep
	moveq	#0,d3
	tst.b	(a6)
	beq.s	.f
	bset	#0,d3
.f:	cmp.b	#3,gbc_rstyle
	bcs.s	.h
	bset	#1,d3
.h:	btst	#0,gbc_pixfmt
	beq.s	.p
	bset	#4,d3
.p:	move.w	d5,d0			; rows: s - s/2 plain, s/2 scanline
	lsr.w	#1,d0
	move.w	d0,gbc_rsnd
	move.w	d5,d1
	sub.w	d0,d1
	move.w	d1,gbc_rsnrm
	move.l	d6,d0
	mulu.w	d1,d0
	move.l	d0,gbc_rsoff		; the first scanline row
	move.l	d6,d0
	mulu.w	d5,d0
	move.l	d0,gbc_rsstep		; one picture line down
	move.w	d5,d0
	mulu.w	#160/2,d0
	subq.w	#1,d0
	move.w	d0,gbc_rslongs		; longs in a screen row of the picture, - 1
	lea	gbc_rstab+65536,a6
	moveq	#0,d7
	bsr.w	.cur			; line 0
.ln:	bclr	#3,d3			; Blended: did the next line change?
	btst	#1,d3
	beq.s	.nl
	cmp.w	#143,d7
	beq.s	.nl
	btst	#0,d3
	bne.s	.nx
	lea	160*2(a0),a2
	lea	160*2(a4),a3
	bsr.w	.diff
	beq.s	.nl
.nx:	bset	#3,d3
.nl:	btst	#2,d3
	beq.s	.nc
	move.l	a0,a2			; changed: keep it, all its rows
	move.l	a4,a3
	moveq	#160/2-1,d0
.cp:	move.l	(a2)+,(a3)+
	dbra	d0,.cp
	bsr.w	.plain
	bsr.w	.scan
	bra.s	.adv
.nc:	btst	#3,d3			; the line below changed: its scanline rows again
	beq.s	.adv
	bsr.w	.scan
.adv:	lea	160*2(a0),a0
	lea	160*2(a4),a4
	add.l	gbc_rsstep,a1
	addq.w	#1,d7
	cmp.w	#144,d7
	beq.s	.done
	btst	#1,d3
	beq.s	.hc
	bclr	#2,d3			; Blended: found one line ahead
	btst	#3,d3
	beq.s	.ln
	bset	#2,d3
	bra.s	.ln
.hc:	bsr.s	.cur
	bra.s	.ln
.done:	move.l	(sp)+,a6
	rts
; d3 bit 2 = line (a0) changed against (a4), or every line
.cur:	bclr	#2,d3
	btst	#0,d3
	bne.s	.c1
	move.l	a0,a2
	move.l	a4,a3
	bsr.s	.diff
	beq.s	.c0
.c1:	bset	#2,d3
.c0:	rts
; NE: the line at a2 differs from the one at a3
.diff:	moveq	#160/2-1,d0
.dl:	cmp.l	(a2)+,(a3)+
	dbne	d0,.dl
	rts
; the plain rows of line a0 (s - s/2 of them) from a1
.plain:	move.l	a1,a3
	cmp.w	#1,gbc_rsnrm
	beq.s	.p1
	lea	gbc_rrow,a3		; more than one: built once, then copied
.p1:	move.l	a0,a2
	move.w	#160-1,d0
	cmp.w	#2,d5
	bne.s	.pn
.p2:	move.w	(a2)+,d1		; 2x: each pixel as a long
	move.w	d1,d2
	swap	d1
	move.w	d2,d1
	move.l	d1,(a3)+
	dbra	d0,.p2
	bra.s	.pc
.pn:	move.w	(a2)+,d1		; 3x, 4x
	move.w	d5,d2
	subq.w	#1,d2
.pw:	move.w	d1,(a3)+
	dbra	d2,.pw
	dbra	d0,.pn
.pc:	move.w	gbc_rsnrm,d2
	cmp.w	#1,d2
	beq.s	.px
	move.l	a1,a5
	subq.w	#1,d2
.pr:	lea	gbc_rrow,a2
	move.l	a5,a3
	move.w	gbc_rslongs,d0
.pl:	move.l	(a2)+,(a3)+
	dbra	d0,.pl
	add.l	d6,a5
	dbra	d2,.pr
.px:	rts
; the scanline rows of line a0 (s/2 of them) below its plain rows
.scan:	move.l	a1,a3
	add.l	gbc_rsoff,a3
	move.l	a3,-(sp)
	cmp.w	#1,gbc_rsnd
	beq.s	.s1
	lea	gbc_rrowd,a3		; more than one: built once, then copied
.s1:	move.l	a0,a2
	move.w	#160-1,d0
	btst	#1,d3
	bne.s	.bl
	cmp.w	#2,d5			; Hard: the table's pixel
	bne.s	.hn
.h2:	move.w	(a2)+,d1
	move.w	(a6,d1.w*2),d1
	move.w	d1,d2
	swap	d1
	move.w	d2,d1
	move.l	d1,(a3)+
	dbra	d0,.h2
	bra.w	.sc
.hn:	move.w	(a2)+,d1
	move.w	(a6,d1.w*2),d1
	move.w	d5,d2
	subq.w	#1,d2
.hw:	move.w	d1,(a3)+
	dbra	d2,.hw
	dbra	d0,.hn
	bra.w	.sc
.bl:	lea	160*2(a0),a5		; Blended: the line below (the last line: itself)
	cmp.w	#143,d7
	bne.s	.b0
	move.l	a0,a5
.b0:	btst	#4,d3
	bne.s	.bp
	cmp.w	#2,d5
	bne.s	.bn
.b2:	move.w	(a2)+,d1		; h(this) + h(below)
	move.w	(a5)+,d4
	move.w	(a6,d1.w*2),d1
	add.w	(a6,d4.w*2),d1
	move.w	d1,d2
	swap	d1
	move.w	d2,d1
	move.l	d1,(a3)+
	dbra	d0,.b2
	bra.w	.sc
.bn:	move.w	(a2)+,d1
	move.w	(a5)+,d4
	move.w	(a6,d1.w*2),d1
	add.w	(a6,d4.w*2),d1
	move.w	d5,d2
	subq.w	#1,d2
.bw:	move.w	d1,(a3)+
	dbra	d2,.bw
	dbra	d0,.bn
	bra.w	.sc
.bp:	cmp.w	#2,d5			; PC byte order: the sum swapped back
	bne.s	.bpn
.bp2:	move.w	(a2)+,d1
	move.w	(a5)+,d4
	move.w	(a6,d1.w*2),d1
	add.w	(a6,d4.w*2),d1
	ror.w	#8,d1
	move.w	d1,d2
	swap	d1
	move.w	d2,d1
	move.l	d1,(a3)+
	dbra	d0,.bp2
	bra.w	.sc
.bpn:	move.w	(a2)+,d1
	move.w	(a5)+,d4
	move.w	(a6,d1.w*2),d1
	add.w	(a6,d4.w*2),d1
	ror.w	#8,d1
	move.w	d5,d2
	subq.w	#1,d2
.bpw:	move.w	d1,(a3)+
	dbra	d2,.bpw
	dbra	d0,.bpn
.sc:	move.l	(sp)+,a5		; the first scanline row
	move.w	gbc_rsnd,d2
	cmp.w	#1,d2
	beq.s	.sx
	subq.w	#1,d2
.sr:	lea	gbc_rrowd,a2
	move.l	a5,a3
	move.w	gbc_rslongs,d0
.sl:	move.l	(a2)+,(a3)+
	dbra	d0,.sl
	add.l	d6,a5
	dbra	d2,.sr
.sx:	rts

	IFD	GBC_RMENU
; ---- the Options menu's "Scanline style" sub-menu (Juan's MenuOptions table): D3.w = the
; sub-item (0-5). Intuition has ticked it (mutual exclude). The style, both config lines, the
; big menu's Style selector.
gbc_rmsty:
	movem.l	d0-d7/a0-a6,-(sp)
	cmp.w	#5,d3
	bhi.s	.x
	move.b	d3,gbc_rstyle
	jsr	gbc_rssave
	jsr	gbc_rmsync
.x:	movem.l	(sp)+,d0-d7/a0-a6
	rts

; ---- "Scanlines = On|Off" and "ScanlineStyle = <word>" into the config (rmenu.s gbc_rmsave).
; OS alive. Keeps every register.
gbc_rssave:
	movem.l	d0-d7/a0-a6,-(sp)
	lea	gbc_rmname1,a3		; "Scanlines"
	move.b	gbc_rscanon,d7
	jsr	gbc_rmsave
	bsr.s	gbc_rssavesty
	movem.l	(sp)+,d0-d7/a0-a6
	rts
; "ScanlineStyle = <word>" only. Keeps every register.
gbc_rssavesty:
	movem.l	d0-d7/a0-a6,-(sp)
	lea	gbc_rkstyw,a3		; "ScanlineStyle"
	moveq	#16,d7			; codes 16-21: the style words (gbc_rmsave)
	add.b	gbc_rstyle,d7
	jsr	gbc_rmsave
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; ---- the sub-menu's ticks as the style is (rmenu.s gbc_rmsync, between its ClearMenuStrip and
; ResetMenuStrip): A6 = intuition. Keeps every register.
gbc_rsmsync:
	movem.l	d0-d2/a0-a1,-(sp)
	moveq	#0,d2
.i:	move.w	d2,d0			; Options, item RM_STYITEM, sub-item d2
	lsl.w	#8,d0
	lsl.w	#3,d0
	or.w	#(RM_STYITEM<<5)|RM_OPTIONS,d0
	move.l	MainMenuMenus,a0
	jsr	-$90(a6)		; ItemAddress
	tst.l	d0
	beq.s	.n
	move.l	d0,a0
	bclr	#0,12(a0)		; mi_Flags: CHECKED ($0100)
	cmp.b	gbc_rstyle,d2
	bne.s	.n
	bset	#0,12(a0)
.n:	addq.w	#1,d2
	cmp.w	#6,d2
	bne.s	.i
	IFD	GBC_BIGLAYOUT
	bsr.w	bm_stysync		; the big menu's Style selector
	ENDC
	movem.l	(sp)+,d0-d2/a0-a1
	rts
	ENDC

	IFD	GBC_BIGLAYOUT
; ---- the big menu's layout (bigmenu.s bm_layout, Juan's 640x212 numbers before they are
; scaled): Juan's Refresh selector (disabled, "1 frame") becomes the Style selector, at the
; foot of Screen Options; LCD fade, Surround and Scanlines move up a row. Juan's numbers are
; checked first; anything unexpected: no Style selector (the Options menu still has it).
; A0 = MainMenuNGads. Keeps every register.
bm_stylay:
	movem.l	d0/a0-a1,-(sp)
	cmp.l	#(481<<16)|96,30*GD_Refresh(a0)
	bne.s	.x
	cmp.l	#(489<<16)|112,30*GD_LCDFade(a0)
	bne.s	.x
	cmp.w	#7,MainMenuGTypes+2*GD_Refresh	; CYCLE_KIND
	bne.s	.x
	lea	MainMenuGTags,a1	; Refresh's tags: after GD_Refresh lists
	moveq	#GD_Refresh-1,d0
.t:	tst.l	(a1)
	beq.s	.t1
	addq.l	#8,a1
	bra.s	.t
.t1:	addq.l	#4,a1
	dbf	d0,.t
	cmp.l	#$8008000E,(a1)		; GTCY_Labels
	bne.s	.x
	cmp.l	#RefreshLabels,4(a1)
	bne.s	.x
	move.l	#2,(a1)			; TAG_MORE: the Style list's tags
	move.l	#bm_stytags,4(a1)
	move.l	#(457<<16)|144,30*GD_Refresh(a0)	; Style, the last row
	move.l	#(140<<16)|13,30*GD_Refresh+4(a0)
	move.l	#bm_stytext,30*GD_Refresh+8(a0)
	move.w	#96,30*GD_LCDFade+2(a0)		; LCD fade, Surround, Scanlines a row up
	move.w	#112,30*GD_Veloz+2(a0)
	move.w	#128,30*GD_Scan+2(a0)
	st	bm_sty
.x:	movem.l	(sp)+,d0/a0-a1
	rts

; ---- the Style selector picked (Juan's gadget table): D2.w = the entry (the message's code;
; else the chooser's CHOOSER_Selected). The style, both config lines, the sub-menu's ticks.
bm_gsty:
	movem.l	d0-d7/a0-a6,-(sp)
	IFD	BM_STYTEST
	addq.b	#1,bm_atgeo+12		; (test: calls, D2, the chooser's answer)
	move.b	d2,bm_atgeo+13
	ENDC
	tst.b	bm_sty
	beq.s	.x
	moveq	#0,d0			; the message's code: the entry picked (cycle and chooser
	move.w	d2,d0			; alike; the chooser's CHOOSER_Selected still says the
	cmp.l	#5,d0			; old one here: WinUAE, OS 3.2, 27 Nov)
	bls.s	.cy
	move.l	bm_chobj,d1
	beq.s	.x
	move.l	d1,a0
	lea	bm_chsel,a1
	move.l	#$85001005,d0		; CHOOSER_Selected
	move.l	_IntuitionBase,a6
	jsr	-654(a6)		; GetAttr
	move.l	bm_chsel,d0
	IFD	BM_STYTEST
	move.b	d0,bm_atgeo+14
	ENDC
.cy:	cmp.l	#5,d0
	bhi.s	.x
	cmp.b	gbc_rstyle,d0
	beq.s	.x
	move.b	d0,gbc_rstyle
	jsr	gbc_rssave
	jsr	gbc_rmsync
.x:	movem.l	(sp)+,d0-d7/a0-a6
	rts

; ---- the Style selector as the style is, if the window is open (gbc_rsmsync): set with no
; window, then drawn (as bm_lsync does: with the window it locked up in WinUAE). Keeps every
; register.
bm_stysync:
	movem.l	d0-d1/a0-a3/a6,-(sp)
	tst.b	bm_sty
	beq.s	.x
	moveq	#0,d0
	move.b	gbc_rstyle,d0
	move.l	d0,bm_stytags+12	; GTCY_Active (the cycle gadget, the next window)
	move.l	MainMenuWnd,d1
	beq.s	.x
	move.l	MainMenuGadgets+4*GD_Refresh,d1
	beq.s	.x
	move.l	d1,a0
	move.l	bm_chobj,d1
	beq.s	.gt
	move.l	d0,bm_chstags+4		; the chooser: SetGadgetAttrsA with no window
	sub.l	a1,a1
	sub.l	a2,a2
	lea	bm_chstags,a3
	move.l	_IntuitionBase,a6
	jsr	-660(a6)		; SetGadgetAttrsA
	bra.s	.dr
.gt:	lea	bm_stytags+8,a3		; the cycle gadget
	sub.l	a1,a1
	sub.l	a2,a2
	move.l	_GadToolsBase,a6
	jsr	-42(a6)			; GT_SetGadgetAttrsA
.dr:	move.l	MainMenuGadgets+4*GD_Refresh,a0
	move.l	MainMenuWnd,a1
	sub.l	a2,a2
	moveq	#1,d0
	move.l	_IntuitionBase,a6
	jsr	-432(a6)		; RefreshGList
.x:	movem.l	(sp)+,d0-d1/a0-a3/a6
	rts

; ---- the Style list as an OS 3.2 chooser.gadget pop-up (GadToolsBox/AmiGameBoy.s calls these
; while it makes, opens, closes and frees the main window). MainMenuGadgets holds the chooser,
; so Juan's GADGETUP lookup finds it (bm_gsty). No chooser.gadget (OS 3.1) or no object: the
; 6-entry cycle gadget.
; D0 = the gadget's kind, D3 = its number, BufNewGad = its box -> D0 = the kind GadTools makes
; (TEXT_KIND, the label only, when a chooser was made). Keeps the other registers.
bm_chpre:
	cmp.w	#GD_Refresh,d3
	bne	.r
	tst.b	bm_sty
	beq	.r
	movem.l	d1-d4/a0-a2/a6,-(sp)
	moveq	#0,d0			; the cycle gadget's setting (also without a chooser)
	move.b	gbc_rstyle,d0
	move.l	d0,bm_stytags+12
	move.l	bm_chbase,d1
	bne.s	.lib
	move.l	4.w,a6
	lea	bm_chn(pc),a1
	moveq	#44,d0
	jsr	-552(a6)		; OpenLibrary
	move.l	d0,bm_chbase
	beq	.no
.lib:	lea	bm_chlist,a0		; the list of chooser nodes
	lea	4(a0),a1		; NewList
	move.l	a1,(a0)
	clr.l	4(a0)
	move.l	a0,8(a0)
	move.l	a0,bm_chtags+44		; CHOOSER_Labels
	lea	bm_stylab,a2
.n:	move.l	(a2)+,d0
	beq.s	.nd
	move.l	d0,bm_cnatags+4
	lea	bm_cnatags,a0
	move.l	bm_chbase,a6
	jsr	-36(a6)			; AllocChooserNodeA
	tst.l	d0
	beq.s	.nd
	lea	bm_chlist,a0
	move.l	d0,a1
	move.l	4.w,a6
	jsr	-246(a6)		; AddTail
	bra.s	.n
.nd:	lea	BufNewGad,a1
	move.w	(a1),d0
	ext.l	d0
	move.l	d0,bm_chtags+4		; GA_Left
	move.w	2(a1),d0
	ext.l	d0
	move.l	d0,bm_chtags+12		; GA_Top
	move.w	4(a1),d0
	ext.l	d0
	move.l	d0,bm_chtags+20		; GA_Width
	move.w	6(a1),d0
	ext.l	d0
	move.l	d0,bm_chtags+28		; GA_Height
	moveq	#0,d0
	move.w	16(a1),d0
	move.l	d0,bm_chtags+36		; GA_ID
	moveq	#0,d0
	move.b	gbc_rstyle,d0
	move.l	d0,bm_chtags+52		; CHOOSER_Selected
	move.l	bm_chbase,a6
	jsr	-30(a6)			; CHOOSER_GetClass
	move.l	d0,a0
	sub.l	a1,a1
	lea	bm_chtags,a2
	move.l	_IntuitionBase,a6
	jsr	-636(a6)		; NewObjectA
	move.l	d0,bm_chobj
	beq.s	.no			; none: the cycle gadget
	move.w	#1,BufNewGad+4		; the GadTools gadget: the label only
	movem.l	(sp)+,d1-d4/a0-a2/a6
	moveq	#13,d0			; TEXT_KIND
	rts
.no:	movem.l	(sp)+,d1-d4/a0-a2/a6
	moveq	#7,d0			; CYCLE_KIND
.r:	rts

; A0 = MainMenuGadgets' entry for gadget D3: the chooser there when there is one. Keeps every
; register but D0.
bm_chpost:
	cmp.w	#GD_Refresh,d3
	bne.s	.x
	move.l	bm_chobj,d0
	beq.s	.x
	move.l	d0,(a0)
.x:	rts

; the chooser into the open main window, drawn. Keeps every register.
bm_chadd:
	movem.l	d0-d1/a0-a2/a6,-(sp)
	move.l	bm_chobj,d0
	beq.s	.x
	move.l	MainMenuWnd,d1
	beq.s	.x
	move.l	_IntuitionBase,a6
	move.l	d1,a0
	move.l	d0,a1
	moveq	#-1,d0
	jsr	-42(a6)			; AddGadget
	move.l	bm_chobj,a0
	move.l	MainMenuWnd,a1
	sub.l	a2,a2
	moveq	#1,d0
	jsr	-432(a6)		; RefreshGList
.x:	movem.l	(sp)+,d0-d1/a0-a2/a6
	rts

; the chooser out of the window before it closes. Keeps every register.
bm_chrem:
	movem.l	d0-d1/a0-a1/a6,-(sp)
	move.l	bm_chobj,d0
	beq.s	.x
	move.l	MainMenuWnd,d1
	beq.s	.x
	move.l	_IntuitionBase,a6
	move.l	d1,a0
	move.l	d0,a1
	jsr	-228(a6)		; RemoveGadget
.x:	movem.l	(sp)+,d0-d1/a0-a1/a6
	rts

; the chooser and its list freed (after the window and the GadTools gadgets). Keeps every register.
bm_chfree:
	movem.l	d0-d1/a0-a1/a6,-(sp)
	move.l	bm_chobj,d0
	beq.s	.l
	clr.l	bm_chobj
	move.l	d0,a0
	move.l	_IntuitionBase,a6
	jsr	-642(a6)		; DisposeObject
.l:	tst.l	bm_chlist		; never made: nothing in it
	beq.s	.x
.f:	lea	bm_chlist,a0
	move.l	4.w,a6
	jsr	-258(a6)		; RemHead
	tst.l	d0
	beq.s	.x
	move.l	d0,a0
	move.l	bm_chbase,a6
	jsr	-42(a6)			; FreeChooserNode
	bra.s	.f
.x:	movem.l	(sp)+,d0-d1/a0-a1/a6
	rts

; chooser.gadget closed (bigmenu.s bm_exit). Keeps every register.
bm_chclose:
	movem.l	d0-d1/a0-a1/a6,-(sp)
	move.l	bm_chbase,d0
	beq.s	.x
	clr.l	bm_chbase
	move.l	d0,a1
	move.l	4.w,a6
	jsr	-414(a6)		; CloseLibrary
.x:	movem.l	(sp)+,d0-d1/a0-a1/a6
	rts
bm_chn:	dc.b	"gadgets/chooser.gadget",0
	even

	IFD	BM_STYTEST
; test (WinUAE): the menu's two selectors used with real mouse events (input.device), Juan's
; Control loop taking the messages as in play: a click on Scanlines (it turns over), a press on
; Style (its list opens), the release on the list's BM_STYTEST-th entry (1-6), a click on Exit.
; Then GB:AmiGB.stytest = "@S <Scanlines> <style> <chooser made> <its list found>". Called once,
; from rmenu.s gbc_rmsync once the config has been read with the window open.
bm_stytest:
	movem.l	d0-d7/a0-a6,-(sp)
	tst.b	bm_stdone
	bne	.x
	st	bm_stdone
	tst.b	bm_sty
	beq	.x
	bsr	bm_inopen
	beq	.x
	moveq	#50,d1
	bsr	bm_delay
	move.l	MainMenuGadgets+GD_Scan*4,a0
	bsr	bm_gmid
	bsr	bm_inmove
	bsr	bm_indown
	bsr	bm_inup
	moveq	#25,d1
	bsr	bm_delay
	move.l	MainMenuGadgets+GD_Refresh*4,a0
	bsr	bm_gmid
	bsr	bm_inmove
	bsr	bm_indown
	moveq	#50,d1
	bsr	bm_delay
	move.l	Scr,a0			; the list: a window on the menu's screen, not Juan's
	move.l	4(a0),d0		; sc_FirstWindow
.w:	tst.l	d0
	beq.s	.up
	move.l	d0,a0
	cmp.l	MainMenuWnd,d0
	bne.s	.lw
	move.l	(a0),d0			; NextWindow
	bra.s	.w
.lw:	move.b	#"1",bm_attxt+9	; found
	move.w	4(a0),d0		; x: the middle
	move.w	8(a0),d2
	lsr.w	#1,d2
	add.w	d2,d0
	moveq	#0,d2			; y: the middle of entry BM_STYTEST of six
	move.w	10(a0),d2
	moveq	#0,d3
	move.b	55(a0),d3		; BorderTop
	sub.w	d3,d2
	moveq	#0,d4
	move.b	57(a0),d4		; BorderBottom
	sub.w	d4,d2
	mulu	#BM_STYTEST*2-1,d2
	divu	#12,d2
	add.w	d3,d2
	add.w	6(a0),d2
	move.w	d2,d1
	movem.w	4(a0),d2-d5		; (the list's box and the point, for the test's file)
	movem.w	d0-d5,bm_atgeo
	bsr	bm_inmove
	IFD	BM_STYHOLD
	move.l	#BM_STYHOLD,d1		; the list held open for a grab
	ELSE
	moveq	#10,d1
	ENDC
	bsr	bm_delay
.up:	bsr	bm_inup
	moveq	#50,d1
	bsr	bm_delay
	move.l	MainMenuGadgets+GD_Exit*4,a0
	bsr	bm_gmid
	bsr	bm_inmove
	bsr	bm_indown
	bsr	bm_inup
	bsr	bm_inclose
	lea	MainMenuPunts,a1	; Juan's loop: the GADGETUPs, Exit returns
	jsr	Control
	lea	bm_attxt+3,a1
	move.b	gbc_rscanon,d0
	add.b	#"0",d0
	move.b	d0,(a1)+
	addq.l	#1,a1
	move.b	gbc_rstyle,d0
	add.b	#"0",d0
	move.b	d0,(a1)
	tst.l	bm_chobj
	beq.s	.nc
	move.b	#"1",bm_attxt+7
.nc:	move.l	HyDosBase,a6
	move.l	#bm_atname,d1
	move.l	#1006,d2
	jsr	-30(a6)			; Open
	move.l	d0,d4
	beq.s	.x
	move.l	d4,d1
	move.l	#bm_attxt,d2
	moveq	#11,d3
	jsr	-48(a6)			; Write
	move.l	d4,d1
	move.l	#bm_atgeo,d2
	moveq	#16,d3
	jsr	-48(a6)
	move.l	d4,d1
	jsr	-36(a6)			; Close
.x:	movem.l	(sp)+,d0-d7/a0-a6
	rts

; A0 = a gadget of the main window -> D0/D1 = its middle on the screen
bm_gmid:
	move.l	MainMenuWnd,a1
	move.w	4(a1),d0
	add.w	4(a0),d0
	move.w	8(a0),d2
	lsr.w	#1,d2
	add.w	d2,d0
	move.w	6(a1),d1
	add.w	6(a0),d1
	move.w	10(a0),d2
	lsr.w	#1,d2
	add.w	d2,d1
	rts
; input.device for the test's mouse events -> NE: open
bm_inopen:
	movem.l	d1/a0-a1/a6,-(sp)
	move.l	4.w,a6
	jsr	-666(a6)		; CreateMsgPort
	move.l	d0,bm_inport
	beq.s	.x
	move.l	d0,a0
	moveq	#48,d0
	jsr	-654(a6)		; CreateIORequest
	move.l	d0,bm_inreq
	beq.s	.x
	lea	bm_inname(pc),a0
	moveq	#0,d0
	move.l	bm_inreq,a1
	moveq	#0,d1
	jsr	-444(a6)		; OpenDevice
	tst.l	d0
	seq	d0
	ext.w	d0
	ext.l	d0
.x:	movem.l	(sp)+,d1/a0-a1/a6
	tst.l	d0
	rts
bm_inclose:
	movem.l	d0-d1/a0-a1/a6,-(sp)
	move.l	4.w,a6
	move.l	bm_inreq,a1
	jsr	-450(a6)		; CloseDevice
	move.l	bm_inreq,a0
	jsr	-660(a6)		; DeleteIORequest
	move.l	bm_inport,a0
	jsr	-672(a6)		; DeleteMsgPort
	movem.l	(sp)+,d0-d1/a0-a1/a6
	rts
; the pointer to D0/D1 on the menu's screen (IECLASS_NEWPOINTERPOS, IESUBCLASS_PIXEL)
bm_inmove:
	movem.l	d0-d2/a0-a1,-(sp)
	move.l	Scr,bm_inpix
	move.w	d0,bm_inpix+4
	move.w	d1,bm_inpix+6
	move.l	#$13010000,d0		; class, subclass, code 0
	moveq	#0,d1			; qualifier
	move.l	#bm_inpix,d2
	bsr.s	bm_inev
	moveq	#2,d1
	bsr	bm_delay
	movem.l	(sp)+,d0-d2/a0-a1
	rts
bm_indown:
	movem.l	d0-d2/a0-a1,-(sp)
	move.l	#$02000068,d0		; IECLASS_RAWMOUSE, IECODE_LBUTTON
	move.l	#$C000,d1		; IEQUALIFIER_RELATIVEMOUSE | LEFTBUTTON
	bra.s	bm_inbut
bm_inup:
	movem.l	d0-d2/a0-a1,-(sp)
	move.l	#$020000E8,d0		; the button up
	move.l	#$8000,d1
bm_inbut:
	moveq	#0,d2
	bsr.s	bm_inev
	moveq	#5,d1
	bsr	bm_delay
	movem.l	(sp)+,d0-d2/a0-a1
	rts
; D0 = class.b subclass.b code.w, D1.w = qualifier, D2 = ie_EventAddress (or X/Y) -> written
bm_inev:
	movem.l	d0-d1/a0-a1/a6,-(sp)
	lea	bm_inevt,a0
	clr.l	(a0)			; ie_NextEvent
	move.l	d0,4(a0)
	move.w	d1,8(a0)
	move.l	d2,10(a0)
	clr.l	14(a0)
	clr.l	18(a0)
	move.l	bm_inreq,a1
	move.w	#11,28(a1)		; IND_WRITEEVENT
	move.l	#22,36(a1)
	move.l	a0,40(a1)
	move.l	4.w,a6
	jsr	-456(a6)		; DoIO
	movem.l	(sp)+,d0-d1/a0-a1/a6
	rts
; D1 = ticks
bm_delay:
	movem.l	d0-d1/a0-a1/a6,-(sp)
	move.l	HyDosBase,a6
	jsr	-198(a6)		; Delay
	movem.l	(sp)+,d0-d1/a0-a1/a6
	rts
bm_inname:	dc.b	"input.device",0
bm_atname:	dc.b	"GB:AmiGB.stytest",0
	even
	ENDC
	ENDC

	IFD	GBC_RSDUMP
; ---- test: the setting stepped and the pictures kept (see the top). After gbc_rtg_show's copy
; (OS frozen; gbc_rhid = the buffer just drawn). Keeps every register.
	IFND	GBC_RSDUMPAT
GBC_RSDUMPAT	=300
	ENDC
RSD_SLOT	=16+160*144*2+GBC_RMAXS*160*GBC_RMAXS*144*2
gbc_rsdump:
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	gbc_rsdn,d0		; pictures shown
	addq.l	#1,gbc_rsdn
	sub.l	#GBC_RSDUMPAT,d0
	bcs	.x
	bne.s	.go
	sf	gbc_rscanon		; the first step: Off, every line again
	st	gbc_rfull
	st	gbc_rfull+1
.go:	divul.l	#GBC_RSDUMP,d1:d0	; d0 = the step, d1 = the picture in it
	cmp.l	#7,d0
	bcc	.x
	cmp.l	#GBC_RSDUMP-1,d1
	bne	.x
	move.l	d0,d7			; the last of the step: keep it
	move.l	d0,d1
	mulu.l	#RSD_SLOT,d1
	lea	gbc_rsdbuf,a3
	add.l	d1,a3
	move.b	gbc_rscanon,(a3)	; the setting as drawn: on, style, scale, format, buffer
	move.b	gbc_rstyle,1(a3)
	move.b	gbc_rscale+1,2(a3)
	move.b	gbc_pixfmt,3(a3)
	move.b	gbc_rhid,4(a3)
	move.l	gbc_rsdn,8(a3)
	lea	16(a3),a3
	lea	gbc_fbold,a0		; the frame as this buffer got it
	tst.b	gbc_rhid
	beq.s	.b0
	lea	gbc_fbold1,a0
.b0:	move.w	#160*144/2-1,d0
.cf:	move.l	(a0)+,(a3)+
	dbra	d0,.cf
	moveq	#0,d0			; its screen rows
	move.b	gbc_rhid,d0
	lea	gbc_rorgs,a0
	move.l	(a0,d0.w*4),a0
	move.w	gbc_rscale,d5
	move.w	d5,d4
	mulu.w	#144,d4
	subq.w	#1,d4
.r:	move.l	a0,a1
	move.w	d5,d0
	mulu.w	#160/2,d0
	subq.w	#1,d0
.rl:	move.l	(a1)+,(a3)+
	dbra	d0,.rl
	add.l	gbc_rbpr,a0
	dbra	d4,.r
	addq.l	#1,d7			; the next step's setting: 0 Off, 1-6 On + style 0-5
	cmp.l	#7,d7
	bcc.s	.x
	sf	gbc_rscanon
	tst.l	d7
	beq.s	.f
	move.b	#1,gbc_rscanon
	subq.b	#1,d7
	move.b	d7,gbc_rstyle
.f:	st	gbc_rfull		; every line again, both buffers
	st	gbc_rfull+1
.x:	movem.l	(sp)+,d0-d7/a0-a6
	rts
; GB:AmiGB.scan: "SCN1", slots kept (long), slot size (long), then the slots (16-byte head,
; the frame, s*144 rows of s*160 words). OS alive (AutoExit, after the screen closed).
gbc_rsdsave:
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	HyDosBase,a6
	move.l	#.name,d1
	move.l	#1006,d2
	jsr	-30(a6)			; Open
	move.l	d0,d4
	beq.s	.x
	move.l	d4,d1
	move.l	#.head,d2
	moveq	#12,d3
	jsr	-48(a6)			; Write
	move.l	d4,d1
	move.l	#gbc_rsdbuf,d2
	move.l	#RSD_SLOT*7,d3
	jsr	-48(a6)
	move.l	d4,d1
	jsr	-36(a6)			; Close
.x:	movem.l	(sp)+,d0-d7/a0-a6
	rts
.head:	dc.b	"SCN1"
	dc.l	7,RSD_SLOT
.name:	dc.b	"GB:AmiGB.scan",0
	even
	SECTION	gbcrsdbss,BSS
gbc_rsdn:	ds.l	1
gbc_rsdbuf:	ds.b	RSD_SLOT*7
	ENDC

	SECTION	gbcrsdata,DATA
gbc_rskey:	dc.w	-1		; the table's style and format (-1: none yet)
gbc_rstyle:	dc.b	1		; "ScanlineStyle": 0-2 Hard 25/50/75%, 3-5 Blended light/-/strong
	IFD	GBC_BIGLAYOUT
bm_sty:		dc.b	0		; the big menu's Style selector is made
	IFD	BM_STYTEST
bm_stdone:	dc.b	0
	ENDC
	ENDC
gbc_rkstyw:	dc.b	"ScanlineStyle",0	; the config's words (gbc_rmsave; gbc_rcfg upper case)
gbc_rksty:	dc.b	"SCANLINESTYLE",0
gbc_rkw0:	dc.b	"0",0
gbc_rkw25:	dc.b	"25",0
gbc_rkw50:	dc.b	"50",0
gbc_rkw75:	dc.b	"75",0
gbc_rkh25:	dc.b	"HARD25",0
gbc_rkh50:	dc.b	"HARD50",0
gbc_rkh75:	dc.b	"HARD75",0
gbc_rkbl:	dc.b	"BLENDLIGHT",0
gbc_rkbn:	dc.b	"BLEND",0
gbc_rkbs:	dc.b	"BLENDSTRONG",0
gbc_rsv25:	dc.b	" 25",0		; written (gbc_rmsave codes 16-21)
gbc_rsv50:	dc.b	" 50",0
gbc_rsv75:	dc.b	" 75",0
gbc_rsvbl:	dc.b	" blendlight",0
gbc_rsvbn:	dc.b	" blend",0
gbc_rsvbs:	dc.b	" blendstrong",0
gbc_rmstyn:	dc.b	"Scanline style",0	; the Options menu (GadToolsBox/AmiGameBoy.s)
gbc_rmsty0:	dc.b	"Hard 25%",0	; and the Style list: Arnold's settings bar Off, his order
gbc_rmsty1:	dc.b	"Hard 50%",0
gbc_rmsty2:	dc.b	"Hard 75%",0
gbc_rmsty3:	dc.b	"Blended light",0
gbc_rmsty4:	dc.b	"Blended",0
gbc_rmsty5:	dc.b	"Blended strong",0
	even
gbc_rsvals:	dc.l	gbc_rsv25,gbc_rsv50,gbc_rsv75,gbc_rsvbl,gbc_rsvbn,gbc_rsvbs
	IFD	GBC_BIGLAYOUT
	cnop	0,4
bm_stytags:	dc.l	$8008000E,bm_stylab	; GTCY_Labels (the cycle gadget without chooser.gadget)
	dc.l	$8008000F,1		; GTCY_Active (bm_chpre, bm_stysync)
	dc.l	0
bm_stylab:	dc.l	gbc_rmsty0,gbc_rmsty1,gbc_rmsty2,gbc_rmsty3,gbc_rmsty4,gbc_rmsty5,0
bm_chtags:	dc.l	$80030001,0		; GA_Left (bm_chpre)
	dc.l	$80030003,0		; GA_Top
	dc.l	$80030005,0		; GA_Width
	dc.l	$80030007,0		; GA_Height
	dc.l	$80030010,0		; GA_ID
	dc.l	$85001004,0		; CHOOSER_Labels
	dc.l	$85001005,0		; CHOOSER_Selected
	dc.l	$80030016,1		; GA_RelVerify
	dc.l	$80030028,topaz8	; GA_TextAttr (the menu's font)
	dc.l	$85001001,1		; CHOOSER_PopUp
	dc.l	$8500100D,1		; CHOOSER_Justification: centred, as the cycle gadgets
	dc.l	0
bm_chstags:	dc.l	$85001005,0		; CHOOSER_Selected (bm_stysync)
	dc.l	0
bm_cnatags:	dc.l	$85001501,0,0		; CNA_Text
bm_chbase:	dc.l	0		; chooser.gadget (bm_chclose)
bm_chobj:	dc.l	0		; the chooser while the main window is up
bm_chsel:	dc.l	0
bm_chlist:	dc.l	0,0,0		; its nodes (a List header)
	IFD	BM_STYTEST
bm_inport:	dc.l	0
bm_inreq:	dc.l	0
bm_inpix:	dc.l	0,0		; IEPointerPixel: screen, x, y
bm_inevt:	ds.b	22		; an InputEvent
bm_attxt:	dc.b	"@S 0 0 0 0",10,0
	even
bm_atgeo:	ds.w	8		; x, y clicked; the list's left, top, width, height
	even
	ENDC
bm_stytext:	dc.b	"Style:",0	; the selector's label
	even
	ENDC

	SECTION	gbcrsbss2,BSS
gbc_rsch:	ds.w	64		; channel value -> scanline value (gbc_rsprep)
gbc_rsnd:	ds.w	1		; scanline rows a picture line (s / 2)
gbc_rsnrm:	ds.w	1		; plain rows (s - s / 2)
gbc_rslongs:	ds.w	1		; longs in a screen row of the picture, - 1
gbc_rsoff:	ds.l	1		; bytes to the first scanline row
gbc_rsstep:	ds.l	1		; bytes a picture line
gbc_rstab:	ds.w	65536		; the table (gbc_rsprep)

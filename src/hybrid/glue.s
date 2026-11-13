; AmiGameBoy hybrid: write handlers that feed Juan's renderer from Wzonka's engine.
; Copyright (C) 2026 AmiGameBoy contributors. GPL-2. The logging logic is Juan's (OUT40,
; OUT42, OUT43, OUT47, OUT4A, OUT4B and EscrVRAM in AmiGameBoy_Main.asm); the line comes
; from the engine's gb_scanlines instead of the Amiga beam ($DFF006 - $48).
;
; Called through Wzonka's write table: d6.b = value, d7.l = address ($0000-$FFFF),
; a2 = Game Boy memory. Must keep d7 (the opcode fetch needs its upper word clear) and
; every register but d6 and a6.

HY_SAVE	reg	d1-d2/a0/a3-a4

; line for the per-line log -> d1.w (0-$90; $90 = vertical blank)
	cnop	0,4
hy_line:
	move.l	gb_scanlines,d1
	IFND	NO_HBLINE		; written once the line is drawn (horizontal blank, STAT
	btst	#1,RRAM+$1f41		; mode 0): it shows from the next line, as on the
	bne.s	.cap			; DMG (IndestructoTank's SCX in the horizontal
	btst	#0,RRAM+$1f41		; blank). Mode 3 stays on the line: the engine's
	bne.s	.cap			; sweeps are coarse and a write the game makes in
	addq.l	#1,d1			; mode 0 can land in the next line's mode 3
.cap:					; (Quartet's LCDC at 103). Only d1 is free here.
	ENDC
	cmp.l	#$90,d1
	bcs.s	.x
	move.w	#$90,d1
.x:	rts

; ---- $8000-$97FF tile data: store, mark the tile for redrawing
	cnop	0,4
hy_wvram:
	move.b	d6,(a2,d7.l)
	move.w	d7,d6
	and.w	#$1fff,d6
	lsr.w	#4,d6
	lea	Regs+TabRedef,a6
	st	(a6,d6.w)
	rts

; ---- $FF40 LCDC: Wzonka's handler (LCD on/off), then log what changed
	cnop	0,4
hy_w40:
	movem.l	HY_SAVE,-(sp)
	lea	Regs,a3
	move.b	D40(a3),d1
	move.b	d6,d2
	move.b	d6,D40(a3)
	eor.b	d1,d2			; d2 = bits that changed
	bsr.w	lcd_mode_write
	lea	RRAM+$1f00,a0
	bsr.s	hy_line
	IFND	NO_OBJMASK		; sprites on/off inside the picture: log the line
	btst	#1,d2
	beq.s	.noobj
	cmp.w	#$90,d1
	bcc.s	.noobj
	cmp.w	#HY_OBJEVS*2,HyObjN
	bcc.s	.noobj
	lea	HyObjEv,a4
	add.w	HyObjN,a4
	move.b	d1,(a4)+		; line
	move.b	d6,(a4)			; new LCDC (bit 1 = sprites on)
	addq.w	#2,HyObjN
.noobj:
	ENDC
	btst	#0,d2			; BG on/off
	beq.s	.nobgx
	or.b	#$02,(TabRasCMDS.l,d1.w)
	lea	(TabRasDATA.l,d1.w*8),a4
	move.b	$43(a0),2(a4)		; BG X
	move.b	$40(a0),1(a4)		; control
	move.b	$4b(a0),3(a4)		; window X
	IFND	NO_BGXWY		; window Y as of this line: AcCoRutBGX clips the BG
	move.b	$4a(a0),4(a4)		; by it (stale or 0 cut scrolled bands short)
	ENDC
.nobgx:	btst	#5,d2			; window on/off
	beq.s	.nowinx
	or.b	#$08+$02,(TabRasCMDS.l,d1.w)
	lea	(TabRasDATA.l,d1.w*8),a4
	move.b	$4b(a0),3(a4)
	move.b	$40(a0),1(a4)
	move.b	$43(a0),2(a4)
	IFND	NO_BGXWY		; window Y as of this line: AcCoRutBGX clips the BG
	move.b	$4a(a0),4(a4)		; by it (stale or 0 cut scrolled bands short)
	ENDC
.nowinx:
	btst	#6,d2			; window map
	bne.s	.winy
	btst	#4,d2			; tile data
	beq.s	.nowiny
.winy:	or.b	#$04,(TabRasCMDS.l,d1.w)
	lea	(TabRasDATA.l,d1.w*8),a4
	move.b	$4a(a0),4(a4)		; window Y
	move.b	$40(a0),1(a4)
.nowiny:
	btst	#3,d2			; BG map
	bne.s	.bgy
	btst	#4,d2			; tile data
	beq.s	.x
.bgy:	bsr.s	hy_log_bgy
.x:	movem.l	(sp)+,HY_SAVE
	rts

; BG Y (and the line where the BG wraps) for line d1; a0 = $FF00, a3 = Regs
hy_log_bgy:
	cmp.b	UltCoorY(a3),d1
	bcs.s	.c3
	moveq	#0,d2
	move.b	UltCoorY(a3),d2
	or.b	#$01,(TabRasCMDS.l,d2.w)
.c3:	move.b	d1,UltCopLin(a3)
	or.b	#$01,(TabRasCMDS.l,d1.w)
	lea	(TabRasDATA.l,d1.w*8),a4
	move.b	$42(a0),(a4)		; BG Y
	move.b	$40(a0),1(a4)		; control
	moveq	#0,d2
	sub.b	$42(a0),d2		; line where the BG map wraps
	cmp.b	#$90,d2
	bcs.s	.c4
	move.b	#$91,d2
.c4:	cmp.b	d1,d2
	bcc.s	.c5
	move.b	#$91,d2
.c5:	move.b	d2,UltCoorY(a3)
	move.w	(a4),(TabRasDATA.l,d2.w*8)
	rts

; ---- $FF42 SCY
	cnop	0,4
hy_w42:
	move.b	d6,(a2,d7.l)
	movem.l	HY_SAVE,-(sp)
	lea	Regs,a3
	lea	RRAM+$1f00,a0
	bsr.w	hy_line
	bsr.s	hy_log_bgy
	movem.l	(sp)+,HY_SAVE
	rts

; ---- $FF43 SCX
	cnop	0,4
hy_w43:
	move.b	d6,(a2,d7.l)
	movem.l	HY_SAVE,-(sp)
	lea	RRAM+$1f00,a0
	bsr.w	hy_line
	or.b	#$02,(TabRasCMDS.l,d1.w)
	lea	(TabRasDATA.l,d1.w*8),a4
	move.b	$43(a0),2(a4)		; BG X
	move.b	$40(a0),1(a4)		; control
	move.b	$4b(a0),3(a4)		; window X
	IFND	NO_BGXWY		; window Y as of this line: AcCoRutBGX clips the BG
	move.b	$4a(a0),4(a4)		; by it (stale or 0 cut scrolled bands short)
	ENDC
	movem.l	(sp)+,HY_SAVE
	rts

; ---- $FF4A WY
	cnop	0,4
hy_w4a:
	move.b	d6,(a2,d7.l)
	movem.l	HY_SAVE,-(sp)
	lea	RRAM+$1f00,a0
	bsr.w	hy_line
	or.b	#$04,(TabRasCMDS.l,d1.w)
	lea	(TabRasDATA.l,d1.w*8),a4
	move.b	$4a(a0),4(a4)
	move.b	$40(a0),1(a4)
	movem.l	(sp)+,HY_SAVE
	rts

; ---- $FF4B WX
	cnop	0,4
hy_w4b:
	move.b	d6,(a2,d7.l)
	movem.l	HY_SAVE,-(sp)
	lea	RRAM+$1f00,a0
	bsr.w	hy_line
	or.b	#$08+$02,(TabRasCMDS.l,d1.w)
	lea	(TabRasDATA.l,d1.w*8),a4
	move.b	$4b(a0),3(a4)		; window X
	move.b	$40(a0),1(a4)		; control
	move.b	$43(a0),2(a4)		; BG X
	IFND	NO_BGXWY		; window Y as of this line: AcCoRutBGX clips the BG
	move.b	$4a(a0),4(a4)		; by it (stale or 0 cut scrolled bands short)
	ENDC
	movem.l	(sp)+,HY_SAVE
	rts

; ---- $FF47 BGP
	cnop	0,4
hy_w47:
	move.b	d6,(a2,d7.l)
	movem.l	HY_SAVE,-(sp)
	lea	RRAM+$1f00,a0
	bsr.w	hy_line
	or.b	#$10,(TabRasCMDS.l,d1.w)
	lea	(TabRasDATA.l,d1.w*8),a4
	move.b	$47(a0),5(a4)
	movem.l	(sp)+,HY_SAVE
	rts

	IFND	NO_OBJMASK
; After OBJPrint: blank the sprite rows of the lines where LCDC bit 1 had the sprites
; off (Genesis II turns them off for its HUD, lines 0-14). Juan's OBJPrint draws every
; sprite for the whole frame. Called from HyBuild; d0-d7/a0-a2 free.
HY_OBJEVS = 16				; sprite on/off switches kept per frame
HyObjMask:
	lea	HyObjEv,a0
	move.w	HyObjN,d7
	lsr.w	#1,d7			; switches this frame
	moveq	#0,d0			; first line of the stretch
	move.b	HyObj0,d2		; LCDC at line 0
	bra.s	.next
.ev:	moveq	#0,d1
	move.b	(a0)+,d1		; line of the switch
	btst	#1,d2
	bne.s	.on
	bsr.s	.clear			; sprites were off: lines d0 to d1-1
.on:	cmp.w	d0,d1
	bls.s	.same
	move.w	d1,d0
.same:	move.b	(a0)+,d2
.next:	dbra	d7,.ev
	btst	#1,d2
	bne.s	.x
	move.w	#144,d1
	bsr.s	.clear
.x:	rts

; lines d0 to d1-1 in all eight sprite planes (two priorities x two palettes x two
; planes, 32*(144+32) bytes each); screen line L starts at byte 16 of row L+16
.clear:	move.w	d1,d3
	sub.w	d0,d3
	ble.s	.cx
	lsl.w	#3,d3			; 32 bytes a line = 8 longs
	subq.w	#1,d3
	move.w	d0,d4
	lsl.w	#5,d4
	lea	GBSpr0+32*16+16,a1
	bsr.s	.four
	lea	GBSpr1+32*16+16,a1
.four:	add.w	d4,a1
	moveq	#4-1,d5
.pl:	move.l	a1,a2
	move.w	d3,d6
.cl:	clr.l	(a2)+
	dbra	d6,.cl
	lea	32*(144+32)(a1),a1
	dbra	d5,.pl
.cx:	rts
	ENDC

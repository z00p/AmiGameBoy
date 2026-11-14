; AmiGameBoy: Game Boy Color line renderer, chunky (HY_GBC + GBC_RENDER builds).
; Copyright (C) 2026 AmiGameBoy contributors. GPL-2 (see COPYING).
;
; gbc_line draws the line LY into gbc_fb (160 x 144 words, the screen's 16-bit format) from the
; registers as they are when the line ends (called from gbc_hblank at sweep 3 of lines 0-143,
; LCD on), VRAM banks 0/1 (gbc_vram) and palette RAM (gbc_bgpal, gbc_obpal):
; - BG and window tiles with the bank-1 attributes: palette (bits 0-2), tile bank (3), X flip
;   (5), Y flip (6), BG-over-OBJ priority (7);
; - the window from the first line where LY = WY with its own line counter, X from WX-7;
; - objects in OAM order (the first ten on the line; a lower OAM index wins over a higher one
;   even where the BG then covers it), 8x8 or 8x16, bank, flips, palette (bits 0-2), OBJ
;   behind BG colours 1-3 (bit 7); LCDC bit 0 off = BG and window lose every priority.
; Each pixel is first a byte: palette*4 + colour (BG 0-31, OBJ 32-63), bit 6 = the BG
; attribute's priority bit; then a word from gbc_rgb (rebuilt when palette RAM was written).

GBC_LB	=8			; margin before pixel 0 in the line buffer (SCX fine scroll, WX < 7)

	SECTION	gbclcode,CODE

; ---- build the decode tables (once, at start). Keeps every register.
gbc_line_init:
	movem.l	d0-d3/a0-a2,-(sp)
	lea	gbc_sp1,a0		; byte -> 8 bytes of its bits (bit 7 first), as 0/1
	lea	gbc_sp2,a1		; ... as 0/2
	moveq	#0,d0
.b:	moveq	#7,d1
.p:	moveq	#0,d2
	btst	d1,d0
	beq.s	.z
	moveq	#1,d2
.z:	move.b	d2,(a0)+
	add.b	d2,d2
	move.b	d2,(a1)+
	dbra	d1,.p
	addq.w	#1,d0
	cmp.w	#256,d0
	bne.s	.b
	lea	gbc_rev,a0		; bit-reversed bytes (X flip)
	moveq	#0,d0
.r:	moveq	#0,d2
	moveq	#7,d1
	move.b	d0,d3
.rb:	lsr.b	#1,d3
	addx.b	d2,d2
	dbra	d1,.rb
	move.b	d2,(a0)+
	addq.w	#1,d0
	cmp.w	#256,d0
	bne.s	.r
	st	gbc_paldirty
	movem.l	(sp)+,d0-d3/a0-a2
	rts

; ---- palette RAM (15-bit BGR, little-endian pairs) -> gbc_rgb, 64 words in the screen's format:
; gbc_pixfmt bit 0 = bytes swapped (the PC formats), bit 1 = 5-5-5, bit 2 = BGR order;
; 0 = R5G6B5 big-endian. A 6-bit green is g5 << 1 | g5 >> 4.
gbc_mkrgb:
	movem.l	d0-d5/a0-a1,-(sp)
	clr.b	gbc_paldirty
	move.b	gbc_pixfmt,d5
	lea	gbc_bgpal,a0		; gbc_obpal follows: 64 colours
	lea	gbc_rgb,a1
	moveq	#64-1,d4
.c:	moveq	#0,d0
	move.b	1(a0),d0
	lsl.w	#8,d0
	move.b	(a0),d0			; d0 = 0bbbbbgggggrrrrr
	addq.l	#2,a0
	moveq	#$1f,d1
	and.w	d0,d1			; r
	move.w	d0,d2
	lsr.w	#5,d2
	and.w	#$1f,d2			; g5
	lsr.w	#8,d0
	lsr.w	#2,d0
	and.w	#$1f,d0			; b
	btst	#2,d5
	beq.s	.rgb
	exg	d0,d1			; BGR: blue in the top field
.rgb:	btst	#1,d5
	bne.s	.555
	lsl.w	#8,d1
	lsl.w	#3,d1			; top << 11
	move.w	d2,d3
	add.w	d3,d3
	lsr.w	#4,d2
	or.w	d2,d3
	lsl.w	#5,d3			; g6 << 5
	bra.s	.or
.555:	lsl.w	#8,d1
	lsl.w	#2,d1			; top << 10
	move.w	d2,d3
	lsl.w	#5,d3			; g5 << 5
.or:	or.w	d3,d1
	or.w	d0,d1
	btst	#0,d5
	beq.s	.be
	rol.w	#8,d1
.be:	move.w	d1,(a1)+
	dbra	d4,.c
	movem.l	(sp)+,d0-d5/a0-a1
	rts

; ---- one 8-pixel tile row into the line buffer.
; In: d0.w = row in the tile (0-7), d3.w = tile number, d4.b = attribute, d7.b = LCDC,
; a4 = where its pixel 0 goes (advanced by 8). Uses d1/d3/d5/a1-a3.
gbc_tile:
	btst	#4,d7
	bne.s	.u
	ext.w	d3			; $8800 mode: signed, from $9000
	add.w	#$100,d3
.u:	lsl.w	#4,d3
	move.w	d0,d5
	btst	#6,d4
	beq.s	.ny
	eor.w	#7,d5
.ny:	add.w	d5,d5
	add.w	d5,d3
	lea	gbc_vram,a1
	btst	#3,d4
	beq.s	.b0
	lea	$2000(a1),a1
.b0:	moveq	#0,d5
	move.b	(a1,d3.w),d5		; low bits
	moveq	#0,d1
	move.b	1(a1,d3.w),d1		; high bits
	btst	#5,d4
	beq.s	.nf
	lea	gbc_rev,a1
	move.b	(a1,d5.w),d5
	move.b	(a1,d1.w),d1
.nf:	lea	gbc_sp1,a2
	lea	(a2,d5.w*8),a2
	lea	gbc_sp2,a3
	lea	(a3,d1.w*8),a3
	moveq	#7,d1			; palette * 4, priority in bit 6, in all four bytes
	and.b	d4,d1
	lsl.b	#2,d1
	tst.b	d4
	bpl.s	.np
	or.b	#$40,d1
.np:	move.b	d1,d5
	lsl.w	#8,d1
	move.b	d5,d1
	move.w	d1,d5
	swap	d1
	move.w	d5,d1
	move.l	(a2)+,d5
	or.l	(a3)+,d5
	or.l	d1,d5
	move.l	d5,(a4)+
	move.l	(a2)+,d5
	or.l	(a3)+,d5
	or.l	d1,d5
	move.l	d5,(a4)+
	rts

; ---- frame end (hybrid_frame): with no line drawn since the last one (the LCD off all through
; the frame) the picture is white, as Mesen 2 shows it; with the LCD switched off part-way the
; lines drawn stay. Keeps every register.
gbc_frame_end:
	tst.b	gbc_drawn
	bne.s	.x
	movem.l	d0-d1/a0,-(sp)
	move.l	#$ffffffff,d0		; white: 5-6-5 all ones
	btst	#1,gbc_pixfmt
	beq.s	.w
	move.l	#$7fff7fff,d0		; 5-5-5
	btst	#0,gbc_pixfmt
	beq.s	.w
	move.l	#$ff7fff7f,d0		; 5-5-5, PC byte order
.w:	lea	gbc_fb,a0
	move.w	#160*144/2-1,d1
.f:	move.l	d0,(a0)+
	dbra	d1,.f
	movem.l	(sp)+,d0-d1/a0
.x:	sf	gbc_drawn
	rts

; ---- the line LY. Keeps every register.
gbc_line:
	movem.l	d0-d7/a0-a6,-(sp)
	st	gbc_drawn
	move.l	gb_memory,a6
	add.l	#$ff00,a6
	move.l	gb_scanlines,d6
	bne.s	.n0
	clr.w	gbc_winline		; a new frame
	clr.b	gbc_wintrig
.n0:	tst.b	gbc_paldirty
	beq.s	.pk
	bsr.w	gbc_mkrgb
.pk:	move.b	$40(a6),d7		; LCDC
; background (always fetched; LCDC bit 0 only takes priority away in CGB mode)
	moveq	#0,d0
	move.b	$42(a6),d0
	add.w	d6,d0
	and.w	#255,d0			; BG line
	move.w	d0,d2
	lsr.w	#3,d2
	lsl.w	#5,d2
	lea	gbc_vram+$1800,a0	; map $9800 (bank 0 tiles, bank 1 attributes)
	btst	#3,d7
	beq.s	.m0
	lea	$400(a0),a0
.m0:	add.w	d2,a0
	and.w	#7,d0
	moveq	#0,d2
	move.b	$43(a6),d2		; SCX
	lea	gbc_lbuf+GBC_LB,a4
	moveq	#7,d1
	and.w	d2,d1
	sub.w	d1,a4
	lsr.w	#3,d2
	moveq	#21-1,d6
.bt:	moveq	#0,d3
	move.b	(a0,d2.w),d3
	move.b	$2000(a0,d2.w),d4
	bsr.w	gbc_tile
	addq.w	#1,d2
	and.w	#31,d2
	dbra	d6,.bt
; window
	move.l	gb_scanlines,d6
	tst.b	gbc_wintrig
	bne.s	.wt
	cmp.b	$4a(a6),d6		; the window starts on the first line where LY = WY
	bne.s	.nowin
	st	gbc_wintrig
.wt:	btst	#5,d7
	beq.s	.nowin
	moveq	#0,d1
	move.b	$4b(a6),d1
	cmp.w	#166,d1
	bhi.s	.nowin
	move.w	gbc_winline,d0
	addq.w	#1,gbc_winline
	move.w	d0,d2
	lsr.w	#3,d2
	lsl.w	#5,d2
	lea	gbc_vram+$1800,a0
	btst	#6,d7
	beq.s	.wm
	lea	$400(a0),a0
.wm:	add.w	d2,a0
	and.w	#7,d0
	lea	gbc_lbuf+GBC_LB-7,a4
	add.w	d1,a4			; pixel WX-7
	moveq	#0,d2
	moveq	#21-1,d6
.wl:	moveq	#0,d3
	move.b	(a0,d2.w),d3
	move.b	$2000(a0,d2.w),d4
	bsr.w	gbc_tile
	addq.w	#1,d2
	dbra	d6,.wl
.nowin:
; objects
	btst	#1,d7
	beq.w	.noobj
	move.l	gb_scanlines,d6
	moveq	#8,d5			; height
	btst	#2,d7
	beq.s	.h8
	moveq	#16,d5
.h8:	move.l	gb_memory,a0
	add.l	#$fe00,a0
	lea	gbc_osel,a1
	moveq	#0,d4			; found
	moveq	#40-1,d2
.sc:	moveq	#0,d0
	move.b	(a0),d0
	sub.w	#16,d0			; top line
	move.w	d6,d1
	sub.w	d0,d1			; line in the object
	bmi.s	.sn
	cmp.w	d5,d1
	bcc.s	.sn
	move.l	a0,(a1)+
	addq.w	#1,d4
	cmp.w	#10,d4
	beq.s	.sd
.sn:	addq.l	#4,a0
	dbra	d2,.sc
.sd:	tst.w	d4
	beq.w	.noobj
	lea	gbc_otk,a2		; pixels already taken by an object
	moveq	#160/4-1,d0
.ct:	clr.l	(a2)+
	dbra	d0,.ct
	lea	gbc_osel,a5
	subq.w	#1,d4
.ob:	move.l	(a5)+,a0		; OAM entry
	moveq	#8,d5			; height
	btst	#2,d7
	beq.s	.oh8
	moveq	#16,d5
.oh8:
	moveq	#0,d1
	move.b	(a0),d1
	sub.w	#16,d1
	move.w	d6,d0
	sub.w	d1,d0			; row 0..h-1
	move.b	3(a0),d3		; attribute
	btst	#6,d3
	beq.s	.oy
	move.w	d5,d1
	subq.w	#1,d1
	sub.w	d0,d1
	move.w	d1,d0
.oy:	moveq	#0,d1
	move.b	2(a0),d1		; tile
	cmp.w	#16,d5
	bne.s	.o8
	and.b	#$fe,d1
.o8:	lsl.w	#4,d1
	add.w	d0,d0
	add.w	d0,d1
	lea	gbc_vram,a1
	btst	#3,d3
	beq.s	.ob0
	lea	$2000(a1),a1
.ob0:	moveq	#0,d0
	move.b	(a1,d1.w),d0
	moveq	#0,d2
	move.b	1(a1,d1.w),d2
	btst	#5,d3
	beq.s	.onf
	lea	gbc_rev,a1
	move.b	(a1,d0.w),d0
	move.b	(a1,d2.w),d2
.onf:	lea	gbc_sp1,a2
	lea	(a2,d0.w*8),a2
	lea	gbc_sp2,a3
	lea	(a3,d2.w*8),a3
	moveq	#7,d2
	and.b	d3,d2
	lsl.b	#2,d2
	or.b	#32,d2			; OBJ colours 32-63
	moveq	#0,d1
	move.b	1(a0),d1
	subq.w	#8,d1			; screen X of pixel 0
	moveq	#8-1,d0
.op:	move.b	(a2)+,d6
	or.b	(a3)+,d6		; colour 0-3
	beq.s	.on			; 0: transparent
	cmp.w	#160,d1
	bcc.s	.on			; off screen (also negative)
	lea	gbc_otk,a1
	tst.b	(a1,d1.w)
	bne.s	.on			; a lower OAM index has it
	st	(a1,d1.w)
	lea	gbc_lbuf+GBC_LB,a1
	btst	#0,d7
	beq.s	.ow			; LCDC bit 0 off: objects on top
	move.b	(a1,d1.w),d5
	btst	#0,d5
	bne.s	.c13
	btst	#1,d5
	beq.s	.ow			; BG colour 0: the object
.c13:	btst	#6,d5
	bne.s	.on			; BG attribute priority over colours 1-3
	tst.b	d3
	bmi.s	.on			; object behind BG colours 1-3
.ow:	or.b	d2,d6
	move.b	d6,(a1,d1.w)
.on:	addq.w	#1,d1
	dbra	d0,.op
	move.l	gb_scanlines,d6
	dbra	d4,.ob
.noobj:
; bytes -> RGB565 words into the frame
	move.l	gb_scanlines,d0
	mulu.w	#160*2,d0
	lea	gbc_fb,a1
	add.l	d0,a1
	lea	gbc_lbuf+GBC_LB,a0
	lea	gbc_rgb,a2
	move.w	#160-1,d1
	moveq	#0,d0
.cv:	move.b	(a0)+,d0
	and.b	#$3f,d0
	move.w	(a2,d0.w*2),(a1)+
	dbra	d1,.cv
	movem.l	(sp)+,d0-d7/a0-a6
	rts

	SECTION	gbclbss,BSS
gbc_fb:		ds.w	160*144		; the picture, in the screen's format (gbc_pixfmt)
gbc_rgb:	ds.w	64		; palette RAM as RGB565
gbc_lbuf:	ds.b	GBC_LB+160+176	; one line, palette*4+colour bytes
gbc_otk:	ds.b	160		; object already drawn there
gbc_osel:	ds.l	10		; the line's objects (OAM addresses)
gbc_sp1:	ds.b	256*8
gbc_sp2:	ds.b	256*8
gbc_rev:	ds.b	256
gbc_winline:	ds.w	1
gbc_wintrig:	ds.b	1
gbc_drawn:	ds.b	1		; a line drawn since the last frame end
gbc_pixfmt:	ds.b	1		; gbc_mkrgb's format flags (gbc_rtg_open)
	even

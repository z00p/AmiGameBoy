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
	lea	gbc_attl,a0		; attribute -> palette*4 (+ $40 priority) in all 4 bytes
	moveq	#0,d0
.a:	moveq	#7,d1
	and.b	d0,d1
	lsl.b	#2,d1
	tst.b	d0
	bpl.s	.ap
	or.b	#$40,d1
.ap:	move.b	d1,d2
	lsl.w	#8,d1
	move.b	d2,d1
	move.w	d1,d2
	swap	d1
	move.w	d2,d1
	move.l	d1,(a0)+
	addq.w	#1,d0
	cmp.w	#256,d0
	bne.s	.a
	lea	gbc_toff,a0		; tile number -> offset in the bank: $8000 mode, then $8800
	moveq	#0,d0
.o1:	move.w	d0,d1
	lsl.w	#4,d1
	move.w	d1,(a0)+
	addq.w	#1,d0
	cmp.w	#256,d0
	bne.s	.o1
	moveq	#0,d0
.o2:	move.w	d0,d1
	eor.w	#$80,d1			; signed from $9000: (n ^ $80) * 16 + $800
	lsl.w	#4,d1
	add.w	#$800,d1
	move.w	d1,(a0)+
	addq.w	#1,d0
	cmp.w	#256,d0
	bne.s	.o2
	bsr.w	gbc_tdall
	st	gbc_paldirty
	movem.l	(sp)+,d0-d3/a0-a2
	rts

; ---- every tile row needs decoding again (gbc_tdirty all set). Keeps every register.
gbc_tdall:
	movem.l	d0/a0,-(sp)
	lea	gbc_tdirty,a0
	move.w	#$3000/4-1,d0
.d:	move.l	#-1,(a0)+
	dbra	d0,.d
	movem.l	(sp)+,d0/a0
	rts

; ---- decode one tile row into the row cache. In: d3.w = row index (bank * $1800 + offset of
; the row's first byte in the bank, even), a3 = gbc_tdirty. gbc_tc + d3 * 4: the 8 pixels
; (colour 0-3, a byte each, pixel 0 first), gbc_tcf + d3 * 4: X-flipped. Keeps every register.
gbc_rowdec:
	movem.l	d1-d2/d5/a2/a6,-(sp)
	clr.w	(a3,d3.w)
	move.w	d3,d1
	cmp.w	#$1800,d1
	bcs.s	.v0
	add.w	#$800,d1		; bank 1 is at gbc_vram + $2000
.v0:	lea	gbc_vram,a6
	moveq	#0,d5
	move.b	(a6,d1.w),d5		; low bits
	moveq	#0,d2
	move.b	1(a6,d1.w),d2		; high bits
	lea	gbc_tc,a2
	lea	(a2,d3.w*4),a2
	lea	gbc_sp1,a6		; gbc_sp2 follows at +2048
	move.l	(a6,d5.w*8),d1
	or.l	2048(a6,d2.w*8),d1
	move.l	d1,(a2)
	move.l	4(a6,d5.w*8),d1
	or.l	2048+4(a6,d2.w*8),d1
	move.l	d1,4(a2)
	lea	gbc_rev,a6
	move.b	(a6,d5.w),d5
	move.b	(a6,d2.w),d2
	add.l	#gbc_tcf-gbc_tc,a2
	lea	gbc_sp1,a6
	move.l	(a6,d5.w*8),d1
	or.l	2048(a6,d2.w*8),d1
	move.l	d1,(a2)
	move.l	4(a6,d5.w*8),d1
	or.l	2048+4(a6,d2.w*8),d1
	move.l	d1,4(a2)
	movem.l	(sp)+,d1-d2/d5/a2/a6
	rts

; ---- palette RAM (15-bit BGR, little-endian pairs) -> gbc_rgb, 64 words in the screen's format,
; looked up in gbc_ctab (built by gbc_mktab the first time, and again if gbc_pixfmt changed).
gbc_mkrgb:
	movem.l	d0/d4/a0-a2,-(sp)
	clr.b	gbc_paldirty
	move.b	gbc_pixfmt,d0
	or.b	#$80,d0			; $80 = built
	cmp.b	gbc_ctabfmt,d0
	beq.s	.ok
	bsr.w	gbc_mktab
.ok:	lea	gbc_bgpal,a0		; gbc_obpal follows: 64 colours
	lea	gbc_rgb,a1
	lea	gbc_ctab,a2
	moveq	#64-1,d4
.c:	moveq	#0,d0
	move.b	1(a0),d0
	lsl.w	#8,d0
	move.b	(a0),d0			; d0 = xbbbbbgggggrrrrr
	addq.l	#2,a0
	and.w	#$7fff,d0
	move.w	(a2,d0.l*2),(a1)+
	dbra	d4,.c
	lea	gbc_rgb,a0		; entries 64-127 = 0-63 (line bytes with the BG priority
	lea	64*2(a0),a1		; bit 6 need no masking)
	moveq	#64/2-1,d4
.m:	move.l	(a0)+,(a1)+
	dbra	d4,.m
	movem.l	(sp)+,d0/d4/a0-a2
	rts

; ---- gbc_ctab: every 15-bit colour as a screen word. In: d0.b = gbc_pixfmt | $80 (bit 0 =
; bytes swapped (the PC formats), bit 1 = 5-5-5, bit 2 = BGR order; 0 = R5G6B5 big-endian).
; Each channel first as 8 bits: raw = c << 3 | c >> 2; GBC_CC = colour correction with the
; weights of Mesen 2's GbcAdjustColors (the usual CGB LCD model): r' = (26r + 4g + 2b) / 4,
; g' = (24g + 8b) / 4, b' = (6r + 4g + 22b) / 4, each at most 240. Then 5 bits = v >> 3, a
; 6-bit green = v >> 2. Keeps every register.
gbc_mktab:
	movem.l	d0-d7/a0,-(sp)
	move.b	d0,gbc_ctabfmt
	move.b	d0,d7			; the format flags
	lea	gbc_ctab,a0
	moveq	#0,d6			; the colour
.n:	moveq	#$1f,d0
	and.w	d6,d0			; r
	move.w	d6,d1
	lsr.w	#5,d1
	and.w	#$1f,d1			; g
	move.w	d6,d2
	lsr.w	#8,d2
	lsr.w	#2,d2			; b
	IFD	GBC_CC
	move.w	d0,d3			; r' (d3)
	mulu.w	#26,d3
	move.w	d1,d4
	lsl.w	#2,d4
	add.w	d4,d3
	move.w	d2,d4
	add.w	d4,d4
	add.w	d4,d3
	lsr.w	#2,d3
	move.w	d0,d5			; b' (d5)
	mulu.w	#6,d5
	move.w	d1,d4
	lsl.w	#2,d4
	add.w	d4,d5
	move.w	d2,d4
	mulu.w	#22,d4
	add.w	d4,d5
	lsr.w	#2,d5
	move.w	d1,d4			; g' (d4)
	mulu.w	#24,d4
	lsl.w	#3,d2
	add.w	d2,d4
	lsr.w	#2,d4
	move.w	#240,d0
	cmp.w	d0,d3
	bls.s	.c1
	move.w	d0,d3
.c1:	cmp.w	d0,d4
	bls.s	.c2
	move.w	d0,d4
.c2:	cmp.w	d0,d5
	bls.s	.c3
	move.w	d0,d5
.c3:
	ELSE
	move.w	d0,d3			; v = c << 3 | c >> 2
	lsl.w	#3,d3
	lsr.w	#2,d0
	or.w	d0,d3
	move.w	d1,d4
	lsl.w	#3,d4
	lsr.w	#2,d1
	or.w	d1,d4
	move.w	d2,d5
	lsl.w	#3,d5
	lsr.w	#2,d2
	or.w	d2,d5
	ENDC
	btst	#2,d7
	beq.s	.rgb
	exg	d3,d5			; BGR: blue in the top field
.rgb:	lsr.w	#3,d3
	lsr.w	#3,d5
	btst	#1,d7
	bne.s	.555
	lsr.w	#2,d4			; g6 << 5
	lsl.w	#5,d4
	moveq	#11,d0
	lsl.w	d0,d3			; top << 11
	bra.s	.or
.555:	lsr.w	#3,d4			; g5 << 5
	lsl.w	#5,d4
	moveq	#10,d0
	lsl.w	d0,d3			; top << 10
.or:	or.w	d4,d3
	or.w	d5,d3
	btst	#0,d7
	beq.s	.be
	rol.w	#8,d3
.be:	move.w	d3,(a0)+
	addq.w	#1,d6
	cmp.w	#$8000,d6
	bcs.w	.n
	movem.l	(sp)+,d0-d7/a0
	rts

; ---- one BG or window tile into the line buffer (a macro in the two tile loops). In: map byte
; at (a0,d2.w), its attribute at $2000(a0,d2.w), d0.w = row * 2, d7.w = (7 - row) * 2,
; a1 = gbc_attl, a3 = gbc_tdirty, a4 = where its pixel 0 goes (advanced by 8), a5 = gbc_toff
; for LCDC bit 4. Uses d1/d3-d5/a2. The 8 pixels come from the row cache (gbc_tc, X-flipped
; gbc_tcf), decoded again when a VRAM write marked the row (gbc_tdirty).
GBC_BGT:	MACRO
	moveq	#0,d3
	move.b	(a0,d2.w),d3
	move.w	(a5,d3.w*2),d3		; the tile's offset in its bank
	moveq	#0,d4
	move.b	$2000(a0,d2.w),d4	; attribute
	btst	#6,d4
	bne.s	.yf\@
	add.w	d0,d3
	bra.s	.yd\@
.yf\@:	add.w	d7,d3			; Y flip
.yd\@:	btst	#3,d4
	beq.s	.k0\@
	add.w	#$1800,d3		; bank 1
.k0\@:	tst.w	(a3,d3.w)
	beq.s	.cl\@
	bsr.w	gbc_rowdec
.cl\@:	move.l	(a1,d4.w*4),d1		; palette * 4 (+ $40) in each byte
	lea	gbc_tc,a2
	btst	#5,d4
	beq.s	.nx\@
	lea	gbc_tcf,a2		; X flip
.nx\@:	lea	(a2,d3.w*4),a2
	move.l	(a2)+,d5
	or.l	d1,d5
	move.l	d5,(a4)+
	move.l	(a2),d5
	or.l	d1,d5
	move.l	d5,(a4)+
	ENDM

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
	lea	gbc_toff,a5		; tile offsets for LCDC bit 4
	btst	#4,d7
	bne.s	.t8
	lea	256*2(a5),a5
.t8:	lea	gbc_attl,a1
	lea	gbc_tdirty,a3
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
	moveq	#7,d7
	sub.w	d0,d7
	add.w	d7,d7			; (7 - row) * 2
	add.w	d0,d0			; row * 2
	moveq	#0,d2
	move.b	$43(a6),d2		; SCX
	lea	gbc_lbuf+GBC_LB,a4
	moveq	#7,d1
	and.w	d2,d1
	sub.w	d1,a4
	lsr.w	#3,d2
	moveq	#21-1,d6
.bt:	GBC_BGT
	addq.w	#1,d2
	and.w	#31,d2
	dbra	d6,.bt
	move.b	$40(a6),d7		; LCDC
; window
	move.l	gb_scanlines,d6
	tst.b	gbc_wintrig
	bne.s	.wt
	cmp.b	$4a(a6),d6		; the window starts on the first line where LY = WY
	bne.w	.nowin
	st	gbc_wintrig
.wt:	btst	#5,d7
	beq.w	.nowin
	moveq	#0,d1
	move.b	$4b(a6),d1
	cmp.w	#166,d1
	bhi.w	.nowin
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
	move.w	#167,d6			; tiles from WX-7 to the right edge: (167 - WX) / 8 + 1
	sub.w	d1,d6
	lsr.w	#3,d6
	moveq	#7,d7
	sub.w	d0,d7
	add.w	d7,d7
	add.w	d0,d0
	moveq	#0,d2
.wl:	GBC_BGT
	addq.w	#1,d2
	dbra	d6,.wl
	move.b	$40(a6),d7		; LCDC
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
	move.w	d6,d3
	add.w	#16,d3			; LY + 16
	moveq	#40-1,d2
.sc:	moveq	#0,d0
	move.b	(a0),d0
	move.w	d3,d1
	sub.w	d0,d1			; the line in the object: below the height (unsigned)
	cmp.w	d5,d1
	bcs.s	.hit
.sn:	addq.l	#4,a0
	dbra	d2,.sc
	bra.s	.sd
.hit:	move.l	a0,(a1)+
	addq.w	#1,d4
	cmp.w	#10,d4
	bne.s	.sn
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
; bytes -> screen words into the frame (gbc_rgb has 128 entries: bit 6 needs no mask)
	move.l	gb_scanlines,d0
	mulu.w	#160*2,d0
	lea	gbc_fb,a1
	add.l	d0,a1
	lea	gbc_lbuf+GBC_LB,a0
	lea	gbc_rgb,a2
	moveq	#160/8-1,d1
	moveq	#0,d0
.cv:	REPT	8
	move.b	(a0)+,d0
	move.w	(a2,d0.w*2),(a1)+
	ENDR
	dbra	d1,.cv
	movem.l	(sp)+,d0-d7/a0-a6
	rts

	SECTION	gbclbss,BSS
gbc_fb:		ds.w	160*144		; the picture, in the screen's format (gbc_pixfmt)
gbc_rgb:	ds.w	128		; palette RAM as screen words, twice (bit 6 = BG priority)
gbc_attl:	ds.l	256		; attribute -> palette * 4 (+ $40 priority), 4 bytes
gbc_toff:	ds.w	512		; tile number -> offset in its bank ($8000 mode, $8800 mode)
gbc_tdirty:	ds.b	$3000		; per VRAM tile byte (bank 0, bank 1): the row needs decoding
gbc_tc:		ds.b	$1800*8		; row cache: 8 pixel bytes (colour 0-3) per 2-byte row
gbc_tcf:	ds.b	$1800*8		; the same, X-flipped
gbc_ctab:	ds.w	32768		; 15-bit colour -> screen word (gbc_mktab)
gbc_lbuf:	ds.b	GBC_LB+160+176	; one line, palette*4+colour bytes
gbc_otk:	ds.b	160		; object already drawn there
gbc_osel:	ds.l	10		; the line's objects (OAM addresses)
gbc_sp1:	ds.b	256*8
gbc_sp2:	ds.b	256*8
gbc_rev:	ds.b	256
gbc_winline:	ds.w	1
gbc_wintrig:	ds.b	1
gbc_drawn:	ds.b	1		; a line drawn since the last frame end
gbc_lineoff:	ds.b	1		; draw no lines this frame (its picture is skipped)
gbc_pixfmt:	ds.b	1		; gbc_mkrgb's format flags (gbc_rtg_open)
gbc_ctabfmt:	ds.b	1		; gbc_pixfmt | $80 that gbc_ctab was built for
	even

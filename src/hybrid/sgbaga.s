; AmiGameBoy: the Super Game Boy on the AGA display (SGB_AGA, the AGA program; 27 Nov 2026).
; Copyright (C) 2026 AmiGameBoy contributors. GPL-2 (see src/engine/COPYING).
;
; The RTG program's Super Game Boy (sgb.s: packets, MLT_REQ, the block palettes, MASK_EN, VRAM
; transfers, the border) on the AGA program's native display. A cart with the Super Game Boy
; header flags (option Auto, "Super Game Boy = Auto|Off" in AmiGameBoy.config, the Options tick)
; is drawn as a colour cart is: the line renderer's DMG path (gbc_line.s) into gbc_ck, then the
; c2p into the 8 planes of gbc_aga.s. Every other mono cart keeps Juan's planar display, as in
; 2.6; with Off an SGB cart does too. The AGA 030 program has none of this (mono Game Boy only).
; - Screen: lowres, the Super Game Boy's 256 x 224 picture, centred: PAL lines $3C-$11B, NTSC
;   $20-$FF (the NTSC overscan: 224 of its lines), H $A1-$1A0; the game at border pixel (48, 40).
;   Planes of 40 x 224 bytes (GBC_APL), row pixel 0 at H $91 (BPLCON1 16-pixel delay), the
;   border from row pixel 16, the game from row pixel 64 (gbc_aorg: an 8-byte origin, so the
;   c2p's longs stay aligned). Colour carts keep their 160 x 144 place in the same planes.
; - Fixed pens: 1 black (MASK_EN 2), 16-31 the four game palettes (palette * 4 + shade, through
;   BGP / OBP0 / OBP1: sgb_plut), 32-79 the border (32 + sgb_bpix: 0 the backdrop, then palettes
;   4-6 colours 1-15). A palette change is new colour moves in the copper lists, nothing redrawn.
; - The border: into both buffers' planes by the c2p when it arrives (sgb_frame), the game's
;   groups left alone. Raw colours (a television), as the RTG program.
; - Cost: as a colour cart (line renderer, c2p of the changed groups). Off, or any other cart:
;   a test per line in gbc_hblank, per frame in sgb_frame (docs/sgb-aga-log.md).

	IFD	GBC_AEDGE
	FAIL	"SGB_AGA: no GBC_AEDGE (sgb_ageo puts the window back to Juan's)"
	ENDC
	IFD	GBC_NODBUF
	FAIL	"SGB_AGA needs the double buffer (sgb_acols writes the copper lists only)"
	ENDC

	SECTION	sgbacode,CODE

; ---- gbc_install, a mono cart (d0-d1/a1 on the stack, a1 = the ROM): a Super Game Boy cart
; with the option Auto goes through the line renderer (as sgb_install will take it), else
; Juan's display as before.
gbc_sgbmono:
	tst.b	sgb_opt
	beq.s	.no
	cmp.b	#3,$146(a1)
	bne.s	.no
	cmp.b	#$33,$14b(a1)
	bne.s	.no
	jmp	gbc_dmginst
.no:	movem.l	(sp)+,d0-d1/a1
	rts

; ---- gbc_start, a mono cart: the renderer's start for a Super Game Boy cart only.
gbc_sgbstart:
	tst.b	sgb_on
	beq.s	.x
	jmp	gbc_dmgstart
.x:	rts

; ---- sgb_mklut (d0-d7/a0-a3 free, sgb_pal made): the pens per block palette through BGP,
; OBP0, OBP1 (gbc_dmgreg), 64 bytes a palette indexed by the line byte (BG 0-3, OBJ 32-35,
; 36-39); the colours again if sgb_pal changed.
sgb_amklut:
	lea	sgb_plut,a1
	moveq	#16,d6			; pen of palette 0, shade 0
.p:	move.l	a1,a3
	move.b	gbc_dmgreg,d3
	bsr.s	.four
	lea	32(a1),a3
	move.b	gbc_dmgreg+1,d3
	bsr.s	.four
	move.b	gbc_dmgreg+2,d3
	bsr.s	.four
	lea	64(a1),a1
	addq.b	#4,d6
	cmp.b	#32,d6
	bne.s	.p
	lea	sgb_pal,a0		; 16 colours, as last time?
	lea	sgb_apalc,a1
	moveq	#8-1,d0
	moveq	#0,d1
.c:	move.l	(a0)+,d2
	cmp.l	(a1),d2
	beq.s	.cs
	moveq	#1,d1
	move.l	d2,(a1)
.cs:	addq.l	#4,a1
	dbra	d0,.c
	tst.b	d1
	beq.s	.x
	bsr.s	sgb_acalc
.x:	rts
.four:	moveq	#4-1,d4			; colours 0-3 of the register in d3
.f:	moveq	#3,d5
	and.b	d3,d5
	add.b	d6,d5
	move.b	d5,(a3)+
	lsr.b	#2,d3
	dbra	d4,.f
	rts

; ---- the fixed pens' colours (sgb_acw: per pen the high and the low nibbles) from sgb_pal and
; the border's palettes; the copper lists take them at their next picture. Keeps every register.
sgb_acalc:
	movem.l	d0-d4/a0-a2,-(sp)
	lea	sgb_acw,a1
	clr.l	1*4(a1)			; pen 1: black
	lea	sgb_pal,a0
	lea	16*4(a1),a2
	moveq	#16-1,d4
.g:	move.w	(a0)+,d0
	bsr.s	sgb_a24
	move.w	d0,(a2)+
	move.w	d1,(a2)+
	dbra	d4,.g
	lea	32*4(a1),a2		; the border: 32 + n
	lea	sgb_pct+$800,a0		; palettes 4-6, little-endian
	moveq	#0,d4
.b:	moveq	#15,d2
	and.w	d4,d2
	bne.s	.bp
	move.w	sgb_pal,d0		; a palette's colour 0: the backdrop
	bra.s	.bc
.bp:	move.b	1(a0,d4.w*2),d0
	lsl.w	#8,d0
	move.b	(a0,d4.w*2),d0
.bc:	bsr.s	sgb_a24
	move.w	d0,(a2)+
	move.w	d1,(a2)+
	addq.w	#1,d4
	cmp.w	#48,d4
	bne.s	.b
	addq.w	#1,sgb_agen
	movem.l	(sp)+,d0-d4/a0-a2
	rts

; d0.w = a 15-bit colour (xbbbbbgggggrrrrr) -> d0.w its high nibbles ($0RGB), d1.w the low ones
; (LOCT), each channel c << 3 | c >> 2. Keeps the rest.
sgb_a24:
	movem.l	d2-d5,-(sp)
	moveq	#0,d1
	moveq	#0,d2
	moveq	#3-1,d4			; r, g, b
	move.w	d0,d5
.c:	moveq	#$1f,d3
	and.w	d5,d3
	lsr.w	#5,d5
	move.w	d3,d0
	lsr.w	#2,d0
	lsl.w	#3,d3
	or.w	d0,d3			; 8 bits
	move.w	d3,d0
	lsr.w	#4,d0
	and.w	#15,d3
	lsl.w	#4,d1			; r ends in bits 8-11, g 4-7, b 0-3
	or.w	d0,d1
	lsl.w	#4,d2
	or.w	d3,d2
	dbra	d4,.c
	exg	d0,d1
	move.w	d2,d1
	movem.l	(sp)+,d2-d5
	rts

; ---- gbc_adraw (a5 = buffer d0's copper list): the fixed pens' colours into it when they changed
; since it had them. Keeps every register.
sgb_acols:
	tst.b	sgb_on
	beq.s	.x
	movem.l	d0-d3/a0,-(sp)
	and.w	#1,d0
	lea	sgb_agenb,a0
	move.w	sgb_agen,d1
	cmp.w	(a0,d0.w*2),d1
	beq.s	.same
	move.w	d1,(a0,d0.w*2)
	lea	sgb_acw,a0
	moveq	#1,d1
	bsr.s	.pen
	moveq	#16,d1
.l:	bsr.s	.pen
	addq.w	#1,d1
	cmp.w	#80,d1
	bne.s	.l
.same:	movem.l	(sp)+,d0-d3/a0
.x:	rts
; pen d1: its moves at bank * 264 + 4 + (pen & 31) * 4, the low nibbles 33 moves on
.pen:	move.w	d1,d2
	lsr.w	#5,d2
	mulu.w	#66*4,d2
	moveq	#31,d3
	and.w	d1,d3
	lsl.w	#2,d3
	add.w	d3,d2
	move.w	(a0,d1.w*4),4+2(a5,d2.w)
	move.w	2(a0,d1.w*4),33*4+4+2(a5,d2.w)
	rts

; ---- gbc_line (AGA, a Super Game Boy cart): the line's bytes (a0, 160) -> pens (a1, in gbc_ck)
; through the blocks' palettes, or the mask. d0-d3/a0-a3 used.
sgb_aconv:
	move.b	sgb_mask,d0
	bne.s	.mask
	move.l	gb_scanlines,d0
	lsr.w	#3,d0
	mulu.w	#20,d0
	lea	sgb_attr,a3
	add.l	d0,a3
	moveq	#20-1,d1
	moveq	#0,d0
.blk:	moveq	#0,d2
	move.b	(a3)+,d2
	lsl.w	#6,d2			; 64 bytes a palette
	lea	sgb_plut,a2
	add.w	d2,a2
	REPT	8
	move.b	(a0)+,d0
	move.b	(a2,d0.w),(a1)+
	ENDR
	dbra	d1,.blk
	rts
.mask:	cmp.b	#1,d0			; 1 freeze: the line stays as it was
	beq.s	.x
	move.l	#$01010101,d2		; 2 black (pen 1)
	cmp.b	#3,d0
	bne.s	.fill
	move.l	#$10101010,d2		; 3 colour 0 (pen 16)
.fill:	moveq	#160/4-1,d1
.f:	move.l	d2,(a1)+
	dbra	d1,.f
.x:	rts

; ---- gbc_aga_on (the display taken, a colour or a Super Game Boy cart): both copper lists'
; window, DIWHIGH and BPLCON1, and the picture's origin, for this cart. Keeps every register.
sgb_ageo:
	movem.l	d0/a0/a2,-(sp)
	lea	.norm(pc),a2
	moveq	#0,d0
	tst.b	sgb_on
	beq.s	.set
	lea	.pal(pc),a2
	IFD	HY_PACEOPT		; Screen 1 (60 Hz) is NTSC, 0 and 2 (Smooth) PAL (pacing.s)
	cmp.b	#1,DirPrefs+$0f
	bne.s	.p
	ELSE
	tst.b	DirPrefs+$0f		; screen mode: 0 = PAL (the menu sets BEAMCON0)
	beq.s	.p
	ENDC
.n:	lea	.ntsc(pc),a2
.p:	move.l	#40*40+8,d0		; row 40, row pixel 64
	movem.l	d0-d2/a0-a1,-(sp)
	lea	sgb_pal,a0		; the colours afresh
	lea	sgb_apalc,a1
	moveq	#8-1,d0
.cp:	move.l	(a0)+,(a1)+
	dbra	d0,.cp
	movem.l	(sp)+,d0-d2/a0-a1
	bsr.w	sgb_acalc
.set:	move.l	d0,gbc_aorg
	lea	gbc_acop0,a0
	bsr.s	.one
	lea	gbc_acop1,a0
	bsr.s	.one
	movem.l	(sp)+,d0/a0/a2
	rts
.one:	add.w	sgb_adiwo,a0
	move.w	(a2),2(a0)		; DIWSTRT
	move.w	2(a2),6(a0)		; DIWSTOP
	move.w	4(a2),10(a0)		; DIWHIGH
	move.w	6(a2),30(a0)		; BPLCON1
	rts
.norm:	dc.w	$48B1,$D851,$2000,$CC00	; Juan's window (gbc_aga_init)
.pal:	dc.w	$3CA1,$1CA1,$2100,$4400	; 256 x 224: lines $3C-$11B, H $A1-$1A0
.ntsc:	dc.w	$20A1,$00A1,$2100,$4400	; lines $20-$FF

; ---- sgb_frame (OS frozen, the display ours): the border picture (sgb_bpix) into both
; buffers' planes, 32 pixels at a time through the c2p; the game's groups are left alone.
; Keeps every register.
sgb_abdraw:
	movem.l	d0-d7/a0-a6,-(sp)
	clr.b	sgb_bdirty
	bsr.w	sgb_acalc		; the border's colours (palettes 4-6 come with it)
	lea	gbc_apl0,a6
	bsr.s	.buf
	lea	gbc_apl1,a6
	bsr.s	.buf
	movem.l	(sp)+,d0-d7/a0-a6
	rts
; planes at a6
.buf:	lea	sgb_bpix,a4
	sub.l	a5,a5			; row
.row:	lea	sgb_arow,a0		; the row as pens: 16 x 0, 32 + the border's 256, 48 x 0
	moveq	#16/4-1,d0
.z0:	clr.l	(a0)+
	dbra	d0,.z0
	move.w	#256-1,d0
.bp:	move.b	(a4)+,d1
	add.b	#32,d1
	move.b	d1,(a0)+
	dbra	d0,.bp
	moveq	#48/4-1,d0
.z1:	clr.l	(a0)+
	dbra	d0,.z1
	move.l	a5,d0
	mulu.w	#40,d0
	lea	(a6,d0.l),a1
	add.l	#GBC_AP3,a1		; as gbc_adraw: the c2p writes around it
	lea	sgb_arow,a0
	sub.l	a2,a2			; group
.g:	cmpa.w	#40,a5			; the game's 20 bytes of rows 40-183 (groups 2-6)
	bcs.s	.cv
	cmpa.w	#184,a5
	bcc.s	.cv
	cmpa.w	#2,a2
	bcs.s	.cv
	cmpa.w	#7,a2
	bcc.s	.cv
	lea	32(a0),a0
	bra.w	.nx
.cv:	movem.l	(a0)+,d0-d7
	include	"gbc_c2p.i"
	move.l	a3,0*GBC_APL-GBC_AP3(a1)	; planes 0-7
	move.l	d5,1*GBC_APL-GBC_AP3(a1)
	move.l	d3,2*GBC_APL-GBC_AP3(a1)
	move.l	d1,3*GBC_APL-GBC_AP3(a1)
	move.l	d6,4*GBC_APL-GBC_AP3(a1)
	move.l	d4,5*GBC_APL-GBC_AP3(a1)
	move.l	d2,6*GBC_APL-GBC_AP3(a1)
	move.l	d0,7*GBC_APL-GBC_AP3(a1)
.nx:	addq.l	#4,a1
	addq.w	#1,a2
	cmpa.w	#10,a2
	bne.w	.g
	addq.w	#1,a5
	cmpa.w	#224,a5
	bne.w	.row
	rts

; ---- "Super Game Boy = Auto|Off" in the config text (padcfg.s calls this on what it read):
; a0 = text, a1 = its end. Any case, blanks around the "="; a line that does not parse changes
; nothing. Keeps every register.
sgb_acfg:
	movem.l	d0-d1/a0/a2-a4,-(sp)
.line:	bsr.s	.blank
	move.l	a0,a3			; the line, after its blanks
	lea	sgb_kname,a2
	bsr.s	.word
	beq.s	.skip
	bsr.s	.blank
	cmp.l	a1,a0
	bcc.s	.skip
	cmp.b	#"=",(a0)+
	bne.s	.skip
	bsr.s	.blank
	move.l	a0,a4
	lea	sgb_kauto,a2
	bsr.s	.word
	beq.s	.v2
	move.b	#1,sgb_opt
	bra.s	.skip
.v2:	move.l	a4,a0
	lea	sgb_akoff,a2
	bsr.s	.word
	beq.s	.skip
	clr.b	sgb_opt
.skip:	move.l	a3,a0			; to the next line
.sk:	cmp.l	a1,a0
	bcc.s	.x
	cmp.b	#10,(a0)+
	bne.s	.sk
	bra.s	.line
.x:	movem.l	(sp)+,d0-d1/a0/a2-a4
	rts
; a0 over spaces, tabs and CRs
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
; the upper-case word at a2 (ends with 0) at a0, any case, a whole word: NE and a0 behind it, or EQ
.word:	move.b	(a2)+,d1
	beq.s	.wend
	cmp.l	a1,a0
	bcc.s	.wf
	move.b	(a0)+,d0
	cmp.b	#"a",d0
	bcs.s	.wu
	cmp.b	#"z",d0
	bhi.s	.wu
	sub.b	#32,d0
.wu:	cmp.b	d0,d1
	beq.s	.word
.wf:	moveq	#0,d0			; EQ
	rts
.wend:	cmp.l	a1,a0
	bcc.s	.wok
	move.b	(a0),d0
	and.b	#$df,d0
	cmp.b	#"A",d0
	bcs.s	.wok
	cmp.b	#"Z",d0
	bls.s	.wf
.wok:	moveq	#1,d0			; NE
	rts

	IFD	SGB_SNAP
; ---- test (sgb_snap): the picture in gbc_ck (pens) -> gbc_fb as 5-5-5 words through the pens'
; colours (c >> 3 of each 8-bit channel undoes sgb_a24), for tools/sgb_check.py. Keeps every
; register.
sgb_afb:
	movem.l	d0-d3/a0-a2,-(sp)
	lea	sgb_acw,a0
	lea	sgb_a15,a1
	moveq	#80-1,d3
.t:	addq.l	#4,a0			; (high nibbles at -4, low at -2)
	move.w	-4(a0),d0		; r

	lsr.w	#8,d0
	and.w	#15,d0
	lsl.w	#4,d0
	move.w	-2(a0),d1
	lsr.w	#8,d1
	and.w	#15,d1
	or.w	d1,d0
	lsr.w	#3,d0
	moveq	#10,d2
	lsl.w	d2,d0
	move.w	d0,d2			; r5 in the top field (gbc_fb's 5-5-5: 0rrrrrgggggbbbbb)
	move.w	-4(a0),d0		; g
	lsr.w	#4,d0
	and.w	#15,d0
	lsl.w	#4,d0
	move.w	-2(a0),d1
	lsr.w	#4,d1
	and.w	#15,d1
	or.w	d1,d0
	lsr.w	#3,d0
	lsl.w	#5,d0
	or.w	d0,d2
	move.w	-4(a0),d0		; b
	and.w	#15,d0
	lsl.w	#4,d0
	move.w	-2(a0),d1
	and.w	#15,d1
	or.w	d1,d0
	lsr.w	#3,d0
	or.w	d0,d2			; b5
	move.w	d2,(a1)+
	dbra	d3,.t
	lea	gbc_ck,a0
	lea	gbc_fb,a2
	lea	sgb_a15,a1
	move.w	#160*144-1,d3
	moveq	#0,d0
.p:	move.b	(a0)+,d0
	cmp.b	#80,d0
	bcs.s	.ok
	moveq	#0,d0
.ok:	move.w	(a1,d0.w*2),(a2)+
	dbra	d3,.p
	movem.l	(sp)+,d0-d3/a0-a2
	rts
	SECTION	sgbasbss,BSS
sgb_a15:	ds.w	80
	ENDC

	SECTION	sgbadata,DATA
gbc_aorg:	dc.l	0		; the picture's place in the planes (sgb_ageo)
sgb_agen:	dc.w	1		; sgb_acw's generation
sgb_agenb:	dc.w	0,0		; ... per buffer: the one its copper list has
sgb_adiwo:	dc.w	0		; DIWSTRT's move in a copper list (gbc_aga_init)
sgb_akoff:	dc.b	"OFF",0
	even

	SECTION	sgbabss,BSS
sgb_plut:	ds.b	4*64		; per block palette: line byte -> pen
sgb_acw:	ds.l	80		; per pen: high nibbles, low nibbles
sgb_apalc:	ds.w	16		; sgb_pal as sgb_acw was made from
sgb_arow:	ds.b	320		; sgb_abdraw: one row of pens

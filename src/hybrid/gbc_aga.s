; AmiGameBoy: Game Boy Color picture on the native AGA display (GBC_AGA builds).
; Copyright (C) 2026 AmiGameBoy contributors. GPL-2 (see COPYING).
;
; Colour carts only (gbc_mode set); mono carts keep Juan's planar display (1.0's path).
; The line renderer (gbc_line.s) writes each line as pen bytes into gbc_ck (160 x 144 chunky);
; at the frame's show the picture is converted (c2p) into 8 bitplanes, lowres, 160 x 144 in
; Juan's display window ($48B1-$D851, so the same place and size as the mono picture).
; - Pens: every 15-bit colour the frame uses gets an AGA colour register (pen 1-255; pen 0 is
;   the border). gbc_mkpen maps palette RAM's 64 entries to pens when palette RAM changed, so a
;   palette written between lines (raster effects) keeps its colour on the lines drawn before:
;   the change becomes other pens, not a copper split. Pens stay from frame to frame (a still
;   palette costs nothing); a new set starts when they ran out in a frame, or more than
;   GBC_APKEEP are in use and the frame added some. Limit: more than 255 colours in one frame
;   (after a new set) -> an entry that changes keeps its old pen for the rest of that frame
;   (gbc_pover, counted in the profile rows).
; - Display: per buffer a copper list (all 256 colours, 24-bit through LOCT, the plane pointers,
;   fetch, window) and 8 planes of 40 bytes a row (FMODE 3: five 64-bit fetches from DDFSTRT
;   $40 with BPLCON1 $CC00, as Juan's display: pixel 0 on H $B1, where the window opens. Seen in
;   WinUAE: DDFSTRT counts in 64-pixel units ($28 acts as $20: pixel 64 at $B1), and with no
;   delay pixel 0 is at H $C1, so the 48-pixel delay acts as -16, wrapping at 64).
; - c2p: 32-pixel groups (gbc_c2p.i, merge network after Mikael Kalms), each compared with what
;   that buffer already holds (gbc_ckold0/1), so only changed groups are converted and written.
; - Double buffer (unless GBC_NODBUF): the frame goes to the hidden buffer, then the vertical
;   blank interrupt (HyVBL) points the copper at its list and restarts it (gbc_apend). A show
;   while a flip is still pending waits for it. GBC_NODBUF: one buffer, drawn while shown (new
;   pens are also poked into the colour registers at once).
; - GBC_APROF (test): two rows of hex numbers above the picture, per 50 vertical blanks, times in
;   lines from the CIA-B TOD counter (see the legend at gbc_qend).

GBC_APL		=40*144			; bytes a plane
GBC_ABUF	=8*GBC_APL		; a buffer's planes
GBC_APKEEP	=192			; see above
	IFD	GBC_APROF
GBC_APMAX	=254			; pens 254/255: the panel's black and white
	ELSE
GBC_APMAX	=256
	ENDC
GBC_ACOLS	=8*66*4			; the colour block of a copper list (8 banks x (2 + 64) moves)

	SECTION	gbcacode,CODE

; ---- Power On (or the cartridge-inside Start): OS alive. Copper lists built, planes cleared,
; a new pen set. Keeps every register.
gbc_aga_init:
	movem.l	d0-d7/a0-a6,-(sp)
	move.b	#8,gbc_pixfmt		; gbc_mktab: AGA colour words
	lea	gbc_acop0,a0
	lea	gbc_apl0,a1
	bsr.w	.list
	lea	gbc_acop1,a0
	lea	gbc_apl1,a1
	bsr.w	.list
	lea	gbc_apl0,a0
	move.w	#2*GBC_ABUF/16-1,d0
.cl:	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)+
	dbra	d0,.cl
	clr.b	gbc_ashown
	sf	gbc_apend
	bsr.w	gbc_pnew
	IFD	GBC_APROF
	lea	gbc_qpanel,a0
	move.w	#GBC_QPANEL/4-1,d0
.cp:	clr.l	(a0)+
	dbra	d0,.cp
	ENDC
	movem.l	(sp)+,d0-d7/a0-a6
	rts
; a0 = copper list, a1 = its planes
.list:	moveq	#0,d1			; colour bank
.bk:	move.w	d1,d2
	ror.w	#3,d2			; BPLCON3 bank bits 15-13 (the border bit: gbc_aga_on)
	move.w	#$0106,(a0)+
	move.w	d2,(a0)+
	move.w	#$0180,d3
	moveq	#32-1,d4
.c0:	move.w	d3,(a0)+
	clr.w	(a0)+
	addq.w	#2,d3
	dbra	d4,.c0
	or.w	#$0200,d2		; LOCT: the low nibbles
	move.w	#$0106,(a0)+
	move.w	d2,(a0)+
	move.w	#$0180,d3
	moveq	#32-1,d4
.c1:	move.w	d3,(a0)+
	clr.w	(a0)+
	addq.w	#2,d3
	dbra	d4,.c1
	addq.w	#1,d1
	cmp.w	#8,d1
	bne.s	.bk
	move.l	#$01060000,(a0)+	; bank 0, LOCT 0 (+ the border bit)
	move.l	#$01FC0003,(a0)+	; FMODE: 64-bit plane fetch
	move.w	#$0142,d3		; sprites: none (DMA off), SPRxCTL disarms them
	moveq	#8-1,d4
.sp:	move.w	d3,(a0)+
	clr.w	(a0)+
	addq.w	#8,d3
	dbra	d4,.sp
	IFD	GBC_APROF		; the panel: lines $30-$40, 320 pixels from H $81, 1 plane,
	move.l	#$2F01FFFE,(a0)+	; colours 0/1 XOR $FE = pens 254/255
	move.l	#$008E3081,(a0)+
	move.l	#$009041C1,(a0)+
	move.l	#$01E42000,(a0)+	; DIWHIGH: the stop is line $41, H $1C1
	move.l	#$00920020,(a0)+	; one 64-bit unit before the picture's: with
	move.l	#$00940098,(a0)+	; no delay the first pixel at H $81 (WinUAE)
	move.l	#$01080000,(a0)+
	move.l	#$010A0000,(a0)+
	move.l	#$01020000,(a0)+
	move.l	#$010CFE00,(a0)+
	move.l	#gbc_qpanel,d0
	move.w	#$00E0,(a0)+
	swap	d0
	move.w	d0,(a0)+
	move.w	#$00E2,(a0)+
	swap	d0
	move.w	d0,(a0)+
	move.l	#$01001001,(a0)+
	move.l	#$4601FFFE,(a0)+	; then the picture's set-up
	ENDC
	IFD	GBC_AEDGE		; test: the A1200's light line left of pixel 0
	move.l	#$008E48B2,(a0)+	; 1: the window opens a pixel later, 2: the whole window
	IFEQ	GBC_AEDGE-2		; a pixel to the right
	move.l	#$0090D852,(a0)+
	ELSE
	move.l	#$0090D851,(a0)+
	ENDC
	ELSE
	move.l	#$008E48B1,(a0)+	; Juan's window: lines $48-$D7, H $B1-$150
	move.l	#$0090D851,(a0)+
	ENDC
	move.l	#$00920040,(a0)+	; Juan's fetch: five 64-bit units, pixel 0 at
	move.l	#$009400B8,(a0)+	; H $B1 with the delay below
	move.l	#$01080000,(a0)+
	move.l	#$010A0000,(a0)+
	move.l	#$0102CC00,(a0)+	; Juan's delay, both playfields: pixel 0 at H $B1
	move.l	#$01040000,(a0)+
	move.l	#$010C0000,(a0)+
	move.l	a1,d0
	move.w	#$00E0,d3
	moveq	#8-1,d4
.pt:	move.w	d3,(a0)+
	swap	d0
	move.w	d0,(a0)+
	addq.w	#2,d3
	move.w	d3,(a0)+
	swap	d0
	move.w	d0,(a0)+
	addq.w	#2,d3
	add.l	#GBC_APL,d0
	dbra	d4,.pt
	move.l	#$01000011,(a0)+	; 8 planes
	move.l	#$FFFFFFFE,(a0)+
	rts

; ---- after CongelaAMIGA (Power On, Continue, the cartridge-inside Start): a colour cart gets
; this display (gbc_aga_on set), a mono cart keeps Juan's. Keeps every register.
gbc_aga_on:
	sf	gbc_aga_onf
	tst.b	gbc_mode
	beq.w	.x
	movem.l	d0-d3/a0-a1,-(sp)
	st	gbc_aga_onf
	move.w	BpCon3+2,d0		; the menu's black border (Juan's BPLCON3 bit 5)
	and.w	#$0020,d0
	lea	gbc_acop0,a0
	bsr.s	.fix
	lea	gbc_acop1,a0
	bsr.s	.fix
	move.w	#$0020,$dff096		; sprite DMA off
	st	gbc_afull		; both buffers drawn whole next
	st	gbc_afull+1
	sf	gbc_apend
	lea	gbc_acop0,a0		; the shown buffer's list now (CongelaAMIGA has just
	tst.b	gbc_ashown		; waited for a vertical blank); twice, in case Juan's
	beq.s	.s0			; list moved COP1LC between the two writes
	lea	gbc_acop1,a0
.s0:	move.l	a0,$dff080
	move.w	d0,$dff088
	move.l	a0,$dff080
	move.w	d0,$dff088
	IFD	GBC_APROF
	bsr.w	gbc_qreset
	ENDC
	movem.l	(sp)+,d0-d3/a0-a1
.x:	rts
; a0 = list, d0 = border bit: every BPLCON3 move gets it; pen 0 = the menu palette's shade 0
.fix:	move.l	a0,a1
	moveq	#8*2-1,d1
.b:	move.w	2(a1),d2
	and.w	#$E200,d2
	or.w	d0,d2
	move.w	d2,2(a1)
	lea	33*4(a1),a1
	dbra	d1,.b
	move.w	d0,2(a1)		; the last one: bank 0
	IFD	GBC_APEN0		; pen 0 (only ever the border) in this 12-bit colour. 2.1: 0, black:
	move.w	#GBC_APEN0,d2		; on the A1200 pen 0 shows in the window's first pixel (a light
					; sliver left of the picture; magenta with $F0F, gone with 0)
	ELSE
	move.w	GBPaleta,d2		; 12-bit: high nibbles = low nibbles
	ENDC
	move.w	d2,4+2(a0)
	move.w	d2,33*4+4+2(a0)
	IFD	GBC_APROF
	moveq	#0,d2			; pen 254 black, 255 white
	move.w	d2,7*66*4+4+30*4+2(a0)
	move.w	d2,7*66*4+33*4+4+30*4+2(a0)
	move.w	#$0fff,d2
	move.w	d2,7*66*4+4+31*4+2(a0)
	move.w	d2,7*66*4+33*4+4+31*4+2(a0)
	ENDC
	rts

; ---- the frame to the screen (hybrid_frame, OS frozen). Keeps every register.
gbc_aga_show:
	movem.l	d0-d7/a0-a6,-(sp)
	IFD	GBC_APROF
	lea	gbc_qoth,a0
	bsr.w	gbc_qlap
	ENDC
	IFND	GBC_NODBUF
.wp:	tst.b	gbc_apend		; the last picture still waits for its vertical blank
	bne.s	.wp
	IFD	GBC_APROF
	lea	gbc_qflw,a0
	bsr.w	gbc_qlap
	ENDC
	moveq	#0,d0
	move.b	gbc_ashown,d0
	eor.b	#1,d0			; the hidden buffer
	ELSE
	moveq	#0,d0
	move.b	gbc_ashown,d0
	ENDC
	bsr.w	gbc_adraw
	IFND	GBC_NODBUF
	lea	gbc_acop0,a0
	tst.b	d0
	beq.s	.c0
	lea	gbc_acop1,a0
.c0:	move.l	a0,gbc_apcop
	move.b	d0,gbc_ashown		; (drawn into next: the other one, after the flip)
	st	gbc_apend		; HyVBL flips
	ENDC
	bsr.w	gbc_pframe
	IFD	GBC_APROF
	addq.w	#1,gbc_qdrawn
	lea	gbc_qc2p,a0
	bsr.w	gbc_qlap
	ENDC
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; ---- the picture (gbc_ck) into buffer d0.b (0/1): new pens into its copper list, then the
; changed 32-pixel groups (all of them when gbc_afull is set for it) through the c2p.
; Keeps d0; the rest is used.
gbc_adraw:
	move.l	d0,-(sp)
	and.w	#1,d0
	lea	gbc_acopn,a4
	lea	(a4,d0.w*2),a4		; pens its list has
	lea	gbc_acop0,a5
	tst.w	d0
	beq.s	.l0
	lea	gbc_acop1,a5
.l0:	move.w	(a4),d1
	move.w	gbc_pused,d2
	move.w	d2,(a4)
	cmp.w	d2,d1
	bcc.s	.pd
	lea	gbc_pcol,a0
	lea	gbc_ctab,a1
	lea	gbc_ctab2,a2
	IFD	GBC_NODBUF
	move.w	BpCon3+2,d6
	and.w	#$0020,d6
	ENDC
.pn:	moveq	#0,d3
	move.w	(a0,d1.w*2),d3		; the pen's 15-bit colour
	move.w	d1,d4			; its moves: bank * 264 + 4 + (pen & 31) * 4
	lsr.w	#5,d4
	mulu.w	#66*4,d4
	moveq	#31,d5
	and.w	d1,d5
	lsl.w	#2,d5
	add.w	d5,d4
	move.w	(a1,d3.l*2),4+2(a5,d4.w)	; high nibbles
	move.w	(a2,d3.l*2),33*4+4+2(a5,d4.w)	; low nibbles (LOCT)
	IFD	GBC_NODBUF		; one buffer: into the registers at once too
	move.w	d1,d4
	lsr.w	#5,d4
	ror.w	#3,d4
	or.w	d6,d4
	move.w	d4,$dff106
	lsr.w	#1,d5
	lea	$dff180,a3
	move.w	(a1,d3.l*2),(a3,d5.w)
	or.w	#$0200,d4
	move.w	d4,$dff106
	move.w	(a2,d3.l*2),(a3,d5.w)
	move.w	d6,$dff106
	ENDC
	addq.w	#1,d1
	cmp.w	d2,d1
	bcs.s	.pn
.pd:
; c2p: a0 chunky, a2 what the buffer holds, a1 plane 3 at the group, a5 line end, a6 picture end
	move.l	(sp),d0
	and.w	#1,d0
	lea	gbc_afull,a0
	move.b	(a0,d0.w),gbc_aflag
	sf	(a0,d0.w)
	IFD	GBC_AFULL		; test: every group every frame (the c2p's worst case)
	st	gbc_aflag
	ENDC
	lea	gbc_ckold0,a2
	lea	gbc_apl0+3*GBC_APL,a1
	tst.w	d0
	beq.s	.b0
	lea	gbc_ckold1,a2
	lea	gbc_apl1+3*GBC_APL,a1
.b0:	lea	gbc_ck,a0
	lea	160(a0),a5
	lea	160*144(a0),a6
.grp:	tst.b	gbc_aflag
	bne.s	.cv
	move.l	a0,a3
	move.l	a2,a4
	REPT	8
	cmpm.l	(a3)+,(a4)+
	bne.s	.cv
	ENDR
	lea	32(a0),a0		; the same: nothing to write
	lea	32(a2),a2
	addq.l	#4,a1
	bra.w	.nx
.cv:	movem.l	(a0)+,d0-d7
	movem.l	d0-d7,(a2)
	lea	32(a2),a2
	include	"gbc_c2p.i"
	move.l	a3,-3*GBC_APL(a1)	; planes 0-7
	move.l	d5,-2*GBC_APL(a1)
	move.l	d3,-1*GBC_APL(a1)
	move.l	d1,(a1)
	move.l	d6,1*GBC_APL(a1)
	move.l	d4,2*GBC_APL(a1)
	move.l	d2,3*GBC_APL(a1)
	move.l	d0,4*GBC_APL(a1)
	addq.l	#4,a1
	IFD	GBC_APROF
	addq.w	#1,gbc_qgrps
	ENDC
.nx:	cmp.l	a5,a0
	bne.w	.grp
	cmp.l	a6,a0
	beq.s	.done
	lea	40-20(a1),a1		; the next plane row
	lea	160(a5),a5
	bra.w	.grp
.done:	move.l	(sp)+,d0
	rts

; ---- palette RAM -> gbc_pen (the line renderer, when gbc_paldirty): a pen for each of the 64
; entries (BG 0-31, OBJ 32-63), entries 64-127 the same (line bytes with the priority bit).
; Keeps every register.
gbc_mkpen:
	movem.l	d0-d4/a0-a3,-(sp)
	clr.b	gbc_paldirty
	move.b	gbc_pixfmt,d0
	or.b	#$80,d0
	cmp.b	gbc_ctabfmt,d0
	beq.s	.ok
	jsr	gbc_mktab
.ok:	lea	gbc_bgpal,a0		; gbc_obpal follows
	lea	gbc_pen,a1
	lea	gbc_pmap,a2
	lea	gbc_pcol,a3
	move.w	gbc_pgen,d2
	moveq	#64-1,d4
.c:	moveq	#0,d0
	move.b	1(a0),d0
	lsl.w	#8,d0
	move.b	(a0),d0
	addq.l	#2,a0
	and.w	#$7fff,d0
	move.w	(a2,d0.l*2),d1		; generation << 8 | pen
	move.w	d1,d3
	clr.b	d3
	cmp.w	d2,d3
	beq.s	.put
	move.w	gbc_pused,d1		; a new pen
	cmp.w	#GBC_APMAX,d1
	bcc.s	.full
	addq.w	#1,gbc_pused
	move.w	d0,(a3,d1.w*2)
	or.w	d2,d1
	move.w	d1,(a2,d0.l*2)
.put:	move.b	d1,(a1)+
	dbra	d4,.c
	lea	gbc_pen,a0
	lea	64(a0),a1
	moveq	#64/4-1,d4
.m:	move.l	(a0)+,(a1)+
	dbra	d4,.m
	movem.l	(sp)+,d0-d4/a0-a3
	rts
.full:	st	gbc_pover		; none left: the entry keeps its pen
	move.b	(a1),d1
	bra.s	.put

; ---- d0.w = 15-bit colour -> d0.w = its pen (one made if need be). Keeps the rest.
gbc_penof:
	movem.l	d1-d2/a0,-(sp)
	and.w	#$7fff,d0
	lea	gbc_pmap,a0
	move.w	(a0,d0.w*2),d1
	move.w	d1,d2
	clr.b	d2
	cmp.w	gbc_pgen,d2
	beq.s	.y
	move.w	gbc_pused,d1
	cmp.w	#GBC_APMAX,d1
	bcc.s	.full
	addq.w	#1,gbc_pused
	lea	gbc_pcol,a0
	move.w	d0,(a0,d1.w*2)
	lea	gbc_pmap,a0
	or.w	gbc_pgen,d1
	move.w	d1,(a0,d0.w*2)
.y:	moveq	#0,d0
	move.b	d1,d0
	movem.l	(sp)+,d1-d2/a0
	rts
.full:	st	gbc_pover
	moveq	#1,d1
	bra.s	.y

; ---- a new pen set: next generation (the map cleared when it wraps), pen 0 only, both
; buffers drawn whole, the line renderer maps palette RAM again. Keeps every register.
gbc_pnew:
	movem.l	d0/a0,-(sp)
	add.w	#$100,gbc_pgen
	bne.s	.g
	move.w	#$100,gbc_pgen		; generation 0 never matches (the map's clear value)
	lea	gbc_pmap,a0
	move.w	#32768*2/16-1,d0
.cl:	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)+
	dbra	d0,.cl
.g:	move.w	#1,gbc_pused
	move.w	#1,gbc_pstart
	move.l	#$00010001,gbc_acopn
	st	gbc_afull
	st	gbc_afull+1
	sf	gbc_pover
	st	gbc_pfresh
	st	gbc_paldirty
	movem.l	(sp)+,d0/a0
	rts

; ---- after each show: a new pen set if they ran out, or if many are in use and this frame
; added some (not on the first frame of a set). Keeps every register.
gbc_pframe:
	move.l	d0,-(sp)
	tst.b	gbc_pover
	IFD	GBC_APROF
	beq.s	.nov
	addq.w	#1,gbc_qpovr
	bra.s	.new
.nov:
	ELSE
	bne.s	.new
	ENDC
	move.w	gbc_pused,d0
	cmp.w	#GBC_APKEEP,d0
	bls.s	.keep
	cmp.w	gbc_pstart,d0
	beq.s	.keep
	tst.b	gbc_pfresh
	bne.s	.keep
.new:	bsr.w	gbc_pnew
	move.l	(sp)+,d0
	rts
.keep:	sf	gbc_pfresh
	move.w	gbc_pused,gbc_pstart
	move.l	(sp)+,d0
	rts

	IFD	GBC_RENDER
	IFNE	AutoExit
; ---- test: GB:AmiGB.prof = "AGA1", the frame count (long), pens in use (word), gbc_pover (byte),
; 0, then the last picture as the display path makes it (gbc_adraw into the other buffer, every
; group): its 8 planes (GBC_ABUF bytes), its copper colour block (GBC_ACOLS bytes), the chunky
; picture (gbc_ck, 23040 bytes), palette RAM (BG 64 + OBJ 64). Mono carts: nothing.
; OS alive (HyExit / HyMenuLeave). tools/gbc_pic.py reads it.
gbc_asave:
	tst.b	gbc_mode
	beq.w	.x
	moveq	#0,d0
	move.b	gbc_ashown,d0
	IFND	GBC_NODBUF
	eor.b	#1,d0
	ENDC
	lea	gbc_afull,a0
	st	(a0,d0.w)
	move.l	d0,-(sp)
	bsr.w	gbc_adraw
	move.l	HyDosBase,a6
	move.l	#GbcFbName,d1
	move.l	#MODE_NEWFILE,d2
	jsr	dosOpen(a6)
	move.l	d0,d4
	beq.w	.xx
	move.l	HyFrames,.head+4
	move.w	gbc_pused,.head+8
	move.b	gbc_pover,.head+10
	move.l	d4,d1
	move.l	#.head,d2
	moveq	#12,d3
	jsr	dosWrite(a6)
	move.l	(sp),d0
	move.l	#gbc_apl0,d2
	move.l	#gbc_acop0,d5
	tst.b	d0
	beq.s	.w0
	move.l	#gbc_apl1,d2
	move.l	#gbc_acop1,d5
.w0:	move.l	d4,d1
	move.l	#GBC_ABUF,d3
	jsr	dosWrite(a6)
	move.l	d4,d1
	move.l	d5,d2
	move.l	#GBC_ACOLS,d3
	jsr	dosWrite(a6)
	move.l	d4,d1
	move.l	#gbc_ck,d2
	move.l	#160*144,d3
	jsr	dosWrite(a6)
	move.l	d4,d1
	move.l	#gbc_bgpal,d2
	moveq	#64,d3
	jsr	dosWrite(a6)
	move.l	d4,d1
	move.l	#gbc_obpal,d2
	moveq	#64,d3
	jsr	dosWrite(a6)
	move.l	d4,d1
	jsr	dosClose(a6)
.xx:	addq.l	#4,sp
.x:	rts
.head:	dc.b	"AGA1"
	dc.l	0,0
	ENDC
	ENDC

	IFD	GBC_APROF
; ---- test rows (GBC_APROF). Two rows of 8 hex words above the picture, redrawn every 50
; vertical blanks (a window). Times are lines (64 us) from the CIA-B TOD counter, summed over
; the window (a PAL window is 50 x 313 = $3D22 lines).
; Row 1: FRMS Game Boy frames run   VBLS vertical blanks ($0032)   DRWN pictures shown
;        SKIP pictures skipped      TOTL all the lines below added up   PENS pens in use now
;        POVR frames that ran out of pens   GRPS 32-pixel groups converted (720 = a whole picture)
; Row 2: EMU  the engine (Game Boy CPU, sound, everything but the renderer)
;        REND the line renderer (gbc_line, 144 calls a drawn frame)
;        C2P  colours + c2p into the planes   WAIT waiting for the vertical blank to draw (spare)
;        FLPW waiting for the last flip       OTHR the rest of the frame end (pads, menu checks)
;        WRST the longest Game Boy frame, lines   LATE Game Boy frames longer than 313 lines
; Laps are 16-bit differences (TOD counts horizontal syncs; bits 15-0 wrap harmlessly). A lap
; that runs backwards (not expected on real hardware) adds nothing and is counted (negl= in
; the AutoExit result): WinUAE's TOD gave per-window sums 3-4.5 times too large with the
; earlier "add 313" rule.

; d0.w = TOD bits 15-0 (middle byte read again: a carry in between reads again)
gbc_qtod:
	move.l	d1,-(sp)
.r:	move.b	$bfd900,d1
	move.b	$bfd800,d0
	cmp.b	$bfd900,d1
	bne.s	.r
	lsl.w	#8,d1
	move.b	d0,d1
	move.w	d1,d0
	move.l	(sp)+,d1
	rts

; lines since the last lap -> the word at a0 and to this Game Boy frame's total. Keeps all.
gbc_qlap:
	movem.l	d0-d1,-(sp)
	bsr.w	gbc_qtod
	move.w	d0,d1
	sub.w	gbc_qlast,d0
	move.w	d1,gbc_qlast
	bpl.s	.p
	addq.l	#1,gbc_qnegt
	moveq	#0,d0
.p:	add.w	d0,(a0)
	add.w	d0,gbc_qframe
	movem.l	(sp)+,d0-d1
	rts

; start again (gbc_aga_on: after the menu)
gbc_qreset:
	movem.l	d0/a0,-(sp)
	bsr.w	gbc_qtod
	move.w	d0,gbc_qlast
	lea	gbc_qsums,a0
	moveq	#GBC_QSUMS/2-1,d0
.c:	clr.w	(a0)+
	dbra	d0,.c
	move.l	HyVblN,gbc_qvbl0
	move.l	HySkipped,gbc_qskip0
	movem.l	(sp)+,d0/a0
	rts

; hybrid_frame: at its start (the engine's lap) and at its end. Keep every register.
gbc_qeng:
	move.l	a0,-(sp)
	lea	gbc_qemu,a0
	bsr.w	gbc_qlap
	move.l	(sp)+,a0
	rts
gbc_qwt0:
	move.l	a0,-(sp)
	lea	gbc_qoth,a0
	bsr.w	gbc_qlap
	move.l	(sp)+,a0
	rts
gbc_qwt1:
	move.l	a0,-(sp)
	lea	gbc_qwait,a0
	bsr.w	gbc_qlap
	move.l	(sp)+,a0
	rts
gbc_qend:
	tst.b	gbc_aga_onf
	beq.w	.x
	movem.l	d0-d7/a0-a6,-(sp)
	lea	gbc_qoth,a0
	bsr.w	gbc_qlap
	addq.w	#1,gbc_qfrms
	move.w	gbc_qframe,d0
	clr.w	gbc_qframe
	cmp.w	gbc_qwrst,d0
	bls.s	.nw
	move.w	d0,gbc_qwrst
.nw:	cmp.w	#313,d0
	bls.s	.nl
	addq.w	#1,gbc_qlate
.nl:	move.l	HyVblN,d0
	sub.l	gbc_qvbl0,d0
	cmp.l	#50,d0
	bcs.w	.xx
	lea	gbc_qrow,a0		; the window's values
	move.w	gbc_qfrms,(a0)+
	move.w	d0,(a0)+
	move.w	gbc_qdrawn,(a0)+
	move.l	HySkipped,d1
	sub.l	gbc_qskip0,d1
	move.w	d1,(a0)+
	move.w	gbc_qemu,d1
	add.w	gbc_qc2p,d1
	add.w	gbc_qwait,d1
	add.w	gbc_qflw,d1
	add.w	gbc_qoth,d1
	move.w	d1,(a0)+
	move.w	gbc_pused,(a0)+
	move.w	gbc_qpovr,(a0)+
	move.w	gbc_qgrps,(a0)+
	move.w	gbc_qemu,d1
	sub.w	gbc_qrend,d1
	move.w	d1,(a0)+
	move.w	gbc_qrend,(a0)+
	move.w	gbc_qc2p,(a0)+
	move.w	gbc_qwait,(a0)+
	move.w	gbc_qflw,(a0)+
	move.w	gbc_qoth,(a0)+
	move.w	gbc_qwrst,(a0)+
	move.w	gbc_qlate,(a0)+
	lea	gbc_qtot,a1		; run totals (the AutoExit result): EMU REND C2P WAIT
	lea	gbc_qrow+8*2,a0		; FLPW OTHR, then DRWN, GRPS
	moveq	#6-1,d2
.t:	moveq	#0,d1
	move.w	(a0)+,d1
	add.l	d1,(a1)+
	dbra	d2,.t
	moveq	#0,d1
	move.w	gbc_qrow+2*2,d1
	add.l	d1,(a1)+
	move.w	gbc_qrow+7*2,d1
	add.l	d1,(a1)+
	bsr.w	gbc_qdraw
	lea	gbc_qsums,a0		; the next window
	moveq	#GBC_QSUMS/2-1,d0
.c:	clr.w	(a0)+
	dbra	d0,.c
	move.l	HyVblN,gbc_qvbl0
	move.l	HySkipped,gbc_qskip0
.xx:	movem.l	(sp)+,d0-d7/a0-a6
.x:	rts

; the 16 values of gbc_qrow as hex into the panel (rows at panel lines 0 and 9)
gbc_qdraw:
	lea	gbc_qrow,a0
	lea	gbc_qpanel,a1
	moveq	#2-1,d6
.row:	moveq	#8-1,d5
.fld:	move.w	(a0)+,d0
	moveq	#4-1,d4
.dig:	rol.w	#4,d0
	moveq	#15,d1
	and.w	d0,d1
	lea	gbc_qfont,a2
	lea	(a2,d1.w*8),a2
	moveq	#8-1,d3
	move.l	a1,a3
.gl:	move.b	(a2)+,(a3)
	lea	40(a3),a3
	dbra	d3,.gl
	addq.l	#1,a1
	dbra	d4,.dig
	addq.l	#1,a1			; a space between fields
	dbra	d5,.fld
	lea	9*40-40(a1),a1		; the second row 9 lines down
	dbra	d6,.row
	rts

gbc_qfont:
	dc.b	$3C,$66,$6E,$76,$66,$66,$3C,0	; 0
	dc.b	$18,$38,$18,$18,$18,$18,$7E,0	; 1
	dc.b	$3C,$66,$06,$0C,$30,$60,$7E,0	; 2
	dc.b	$3C,$66,$06,$1C,$06,$66,$3C,0	; 3
	dc.b	$0C,$1C,$3C,$6C,$7E,$0C,$0C,0	; 4
	dc.b	$7E,$60,$7C,$06,$06,$66,$3C,0	; 5
	dc.b	$3C,$66,$60,$7C,$66,$66,$3C,0	; 6
	dc.b	$7E,$66,$0C,$18,$18,$18,$18,0	; 7
	dc.b	$3C,$66,$66,$3C,$66,$66,$3C,0	; 8
	dc.b	$3C,$66,$66,$3E,$06,$66,$3C,0	; 9
	dc.b	$18,$3C,$66,$7E,$66,$66,$66,0	; A
	dc.b	$7C,$66,$66,$7C,$66,$66,$7C,0	; B
	dc.b	$3C,$66,$60,$60,$60,$66,$3C,0	; C
	dc.b	$78,$6C,$66,$66,$66,$6C,$78,0	; D
	dc.b	$7E,$60,$60,$78,$60,$60,$7E,0	; E
	dc.b	$7E,$60,$60,$78,$60,$60,$60,0	; F
	ENDC

	SECTION	gbcadata,DATA
gbc_pgen:	dc.w	0		; pen generation << 8 (gbc_pmap entries of another are free)
gbc_pused:	dc.w	1		; pens in use (pen 0 = the border)
gbc_pstart:	dc.w	1		; ... at the start of this frame
gbc_acopn:	dc.w	1,1		; per buffer: pens its copper list holds
gbc_apcop:	dc.l	0		; the list HyVBL starts (gbc_apend)
gbc_afull:	dc.b	0,0		; per buffer: draw every group next time
gbc_aflag:	dc.b	0
gbc_ashown:	dc.b	0		; the buffer shown (or, with a flip pending, about to be)
gbc_apend:	dc.b	0		; a flip for HyVBL
gbc_aga_onf:	dc.b	0		; the colour display is in use (a colour cart)
gbc_pover:	dc.b	0		; pens ran out this frame
gbc_pfresh:	dc.b	0		; the first frame of a pen set
	even
	IFD	GBC_APROF
gbc_qlast:	dc.w	0
gbc_qvbl0:	dc.l	0
gbc_qskip0:	dc.l	0
gbc_qframe:	dc.w	0
gbc_qsums:				; cleared every window
gbc_qemu:	dc.w	0		; the engine's laps (the renderer inside; EMU = this - REND)
gbc_qrend:	dc.w	0
gbc_qc2p:	dc.w	0
gbc_qwait:	dc.w	0
gbc_qflw:	dc.w	0
gbc_qoth:	dc.w	0
gbc_qfrms:	dc.w	0
gbc_qdrawn:	dc.w	0
gbc_qgrps:	dc.w	0
gbc_qpovr:	dc.w	0
gbc_qwrst:	dc.w	0
gbc_qlate:	dc.w	0
GBC_QSUMS	=*-gbc_qsums
gbc_qrow:	ds.w	16		; the values shown
gbc_qtot:	ds.l	8		; run totals: EMU REND C2P WAIT FLPW OTHR DRWN GRPS
gbc_qnegt:	ds.l	1		; laps that ran backwards (see gbc_qlap)
gbc_qt0:	dc.b	0		; (gbc_hblank: TOD low byte before gbc_line)
	even
	ENDC

	SECTION	gbcabss,BSS
gbc_ck:		ds.b	160*144		; the picture as pens (gbc_line)
gbc_ckold0:	ds.b	160*144		; what buffer 0 holds
gbc_ckold1:	ds.b	160*144		; ... buffer 1
gbc_pmap:	ds.w	32768		; 15-bit colour -> generation << 8 | pen
gbc_pcol:	ds.w	256		; pen -> 15-bit colour
gbc_pen:	ds.b	128		; palette RAM entry (twice) -> pen
gbc_ctab2:	ds.w	32768		; 15-bit colour -> AGA low nibbles (gbc_mktab; gbc_ctab: high)

	SECTION	gbcachip,BSS_C
	cnop	0,8
gbc_apl0:	ds.b	GBC_ABUF	; buffer 0 planes
gbc_apl1:	ds.b	GBC_ABUF	; buffer 1
gbc_acop0:	ds.b	GBC_ACOLS+512	; copper lists
gbc_acop1:	ds.b	GBC_ACOLS+512
	IFD	GBC_APROF
GBC_QPANEL	=40*17
gbc_qpanel:	ds.b	GBC_QPANEL	; the panel: 320 x 17, 1 plane
	ENDC

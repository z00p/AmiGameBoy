; AmiGameBoy: Game Boy Color picture on a 16-bit Picasso96 screen (GBC_RTG test builds).
; Copyright (C) 2026 AmiGameBoy contributors. GPL-2 (see COPYING).
; After AmiPCEngine's RTG.asm (RtgFind, RtgPlayOpen, RtgCopy): the screen is opened and its
; bitmap address read with the OS alive, then written directly with the OS frozen.
; Mode: a 16-bit format of gbc_rfmts, 960x540 first, then 640x480, then the smallest mode of
; at least 320x288, else of at least 160x144. The picture at the largest integer scale that
; fits (at most 4), centred. gbc_line draws in the screen's own format (gbc_pixfmt); only
; the lines that changed since the last copy go to the screen.

GBC_RMAXS	=4

	SECTION	gbcrcode,CODE

; ---- open: OS alive. Out: gbc_rtg_on set when the screen is up. Keeps every register.
gbc_rtg_open:
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	4.w,a6
	lea	.gfx(pc),a1
	moveq	#39,d0
	jsr	-552(a6)		; OpenLibrary
	move.l	d0,gbc_rgfx
	beq.w	.x
	lea	.int(pc),a1
	moveq	#39,d0
	jsr	-552(a6)
	move.l	d0,gbc_rint
	beq.w	.x
	lea	.p96(pc),a1
	moveq	#2,d0
	jsr	-552(a6)
	move.l	d0,gbc_rp96
	beq.w	.x
; the whole display list: d6 = best rank (lower is better), d5 = its ModeID
	moveq	#-1,d6
	moveq	#-1,d5
	moveq	#-1,d4
.next:	move.l	d4,d0
	move.l	gbc_rgfx,a6
	jsr	-732(a6)		; NextDisplayInfo
	move.l	d0,d4
	cmp.l	#-1,d4
	beq.w	.done
	moveq	#6,d1			; P96IDA_ISP96
	bsr.w	.attr
	tst.l	d0
	beq.s	.next
	moveq	#5,d1			; P96IDA_RGBFORMAT
	bsr.w	.attr
	bsr.w	gbc_rfmtflags
	tst.w	d0
	bmi.s	.next
	moveq	#0,d1			; width
	bsr.w	.attr
	move.l	d0,d2
	moveq	#1,d1			; height
	bsr.w	.attr
	move.l	d0,d3
	cmp.l	#160,d2
	bcs.s	.next
	cmp.l	#144,d3
	bcs.s	.next
	moveq	#0,d0			; rank 0: 960x540
	cmp.l	#960,d2
	bne.s	.r1
	cmp.l	#540,d3
	beq.s	.rk
.r1:	moveq	#1,d0			; rank 1: 640x480
	cmp.l	#640,d2
	bne.s	.r2
	cmp.l	#480,d3
	beq.s	.rk
.r2:	move.l	d2,d0			; then by area, 2x first
	mulu.w	d3,d0
	add.l	#$100,d0
	cmp.l	#320,d2
	bcs.s	.r3
	cmp.l	#288,d3
	bcc.s	.rk
.r3:	add.l	#$1000000,d0
.rk:	cmp.l	d6,d0
	bcc.w	.next
	move.l	d0,d6
	move.l	d4,d5
	bra.w	.next
.done:	cmp.l	#-1,d5
	beq.w	.x
	move.l	d5,gbc_rmode
	move.l	d5,d4
	moveq	#0,d1
	bsr.w	.attr
	move.l	d0,gbc_rstw+4
	move.w	d0,gbc_rw
	moveq	#1,d1
	bsr.w	.attr
	move.l	d0,gbc_rsth+4
	move.w	d0,gbc_rh
	moveq	#2,d1			; depth
	bsr.w	.attr
	move.l	d0,gbc_rstd+4
	move.l	d5,gbc_rstm+4
	sub.l	a0,a0
	lea	gbc_rtags,a1
	move.l	gbc_rint,a6
	jsr	-612(a6)		; OpenScreenTagList
	move.l	d0,gbc_rscr
	beq.w	.x
	move.l	gbc_rgfx,a6
	jsr	-270(a6)		; WaitTOF
	jsr	-270(a6)
	move.l	gbc_rscr,a0
	move.l	$58(a0),a0		; sc_RastPort.rp_BitMap
	move.l	a0,gbc_rbm
	lea	gbc_rri,a1
	moveq	#12,d0
	move.l	gbc_rp96,a6
	jsr	-48(a6)			; p96LockBitMap
	move.l	d0,d7
	beq.w	.x
	move.l	gbc_rri,gbc_rmem
	moveq	#0,d0
	move.w	gbc_rri+4,d0
	move.l	d0,gbc_rbpr
	move.l	gbc_rri+8,gbc_rfmt
	move.l	gbc_rbm,a0
	move.l	d7,d0
	jsr	-54(a6)			; p96UnlockBitMap (not held across OS calls)
	move.l	gbc_rfmt,d0
	bsr.w	gbc_rfmtflags
	tst.w	d0
	bmi.w	.x
	move.b	d0,gbc_pixfmt
	st	gbc_paldirty		; the colours again, in this format
; scale: the largest s <= GBC_RMAXS with 160s x 144s inside the mode
	moveq	#0,d0
	move.w	gbc_rw,d0
	divu.w	#160,d0
	moveq	#0,d1
	move.w	gbc_rh,d1
	divu.w	#144,d1
	cmp.w	d0,d1
	bcc.s	.sc1
	move.w	d1,d0
.sc1:	cmp.w	#GBC_RMAXS,d0
	bls.s	.sc2
	moveq	#GBC_RMAXS,d0
.sc2:	move.w	d0,gbc_rscale
	move.w	d0,d3
	mulu.w	#160,d0
	move.w	gbc_rw,d1
	sub.w	d0,d1
	lsr.w	#1,d1			; left
	move.w	d3,d0
	mulu.w	#144,d0
	move.w	gbc_rh,d2
	sub.w	d0,d2
	lsr.w	#1,d2			; top
	move.l	gbc_rbpr,d0
	mulu.w	d2,d0
	and.l	#$ffff,d1
	add.l	d1,d1
	add.l	d1,d0
	add.l	gbc_rmem,d0
	move.l	d0,gbc_rorg
	move.l	gbc_rmem,a0		; clear the screen
	move.l	gbc_rbpr,d0
	mulu.w	gbc_rh,d0
	lsr.l	#2,d0
	bra.s	.cle
.cl:	clr.l	(a0)+
.cle:	subq.l	#1,d0
	bpl.s	.cl
	st	gbc_rfull		; the first copy: every line
	st	gbc_rtg_on
.x:	movem.l	(sp)+,d0-d7/a0-a6
	rts
.attr:	move.l	d4,d0			; P96 GetModeIDAttr(d4, d1)
	move.l	a6,-(sp)
	move.l	gbc_rp96,a6
	jsr	-84(a6)
	move.l	(sp)+,a6
	rts
.gfx:	dc.b	"graphics.library",0
.int:	dc.b	"intuition.library",0
.p96:	dc.b	"Picasso96API.library",0
	even

; d0.l = P96 RGBFormat -> d0.w = gbc_pixfmt flags, or -1 when not one of ours
gbc_rfmtflags:
	move.l	a0,-(sp)
	lea	gbc_rfmts,a0
.f:	tst.b	(a0)
	bmi.s	.no
	cmp.b	(a0),d0
	beq.s	.y
	addq.l	#2,a0
	bra.s	.f
.y:	moveq	#0,d0
	move.b	1(a0),d0
	move.l	(sp)+,a0
	rts
.no:	moveq	#-1,d0
	move.l	(sp)+,a0
	rts

; ---- the frame (gbc_fb) to the screen: the lines that differ from the last copy (gbc_fbold).
; OS frozen. Keeps every register.
gbc_rtg_show:
	tst.b	gbc_rtg_on
	beq.w	.x
	movem.l	d0-d7/a0-a5,-(sp)
	lea	gbc_fb,a0
	lea	gbc_fbold,a4
	move.l	gbc_rorg,a1
	move.l	gbc_rbpr,d6
	move.w	gbc_rscale,d5
	moveq	#0,d7			; line
.ln:	tst.b	gbc_rfull
	bne.s	.chg
	move.l	a0,a2			; changed since the last copy?
	move.l	a4,a3
	moveq	#160/2-1,d0
.cmp:	cmp.l	(a2)+,(a3)+
	dbne	d0,.cmp
	beq.w	.same
.chg:	move.l	a0,a2			; keep it
	move.l	a4,a3
	moveq	#160/2-1,d0
.cp:	move.l	(a2)+,(a3)+
	dbra	d0,.cp
	cmp.w	#1,d5
	bne.s	.s2
	move.l	a0,a2			; 1x
	move.l	a1,a3
	moveq	#160/2-1,d0
.c1:	move.l	(a2)+,(a3)+
	dbra	d0,.c1
	bra.s	.same
.s2:	cmp.w	#2,d5
	bne.s	.sn
	move.l	a0,a2			; 2x: each pixel as a long, the row twice
	move.l	a1,a3
	lea	(a1,d6.l),a5
	move.w	#160-1,d0
.c2:	move.w	(a2)+,d1
	move.w	d1,d2
	swap	d1
	move.w	d2,d1
	move.l	d1,(a3)+
	move.l	d1,(a5)+
	dbra	d0,.c2
	bra.s	.same
.sn:	move.l	a0,a2			; 3x, 4x: the row built in gbc_rrow, then copied s times
	lea	gbc_rrow,a3
	move.w	#160-1,d0
.cn:	move.w	(a2)+,d1
	move.w	d5,d2
	subq.w	#1,d2
.cw:	move.w	d1,(a3)+
	dbra	d2,.cw
	dbra	d0,.cn
	move.l	a1,a5
	move.w	d5,d2
	subq.w	#1,d2
.cr:	lea	gbc_rrow,a2
	move.l	a5,a3
	move.w	d5,d0
	mulu.w	#160/2,d0
	subq.w	#1,d0
.cl:	move.l	(a2)+,(a3)+
	dbra	d0,.cl
	add.l	d6,a5
	dbra	d2,.cr
.same:	lea	160*2(a0),a0
	lea	160*2(a4),a4
	move.w	d5,d0
.adv:	add.l	d6,a1
	subq.w	#1,d0
	bne.s	.adv
	addq.w	#1,d7
	cmp.w	#144,d7
	bne.w	.ln
	sf	gbc_rfull
	movem.l	(sp)+,d0-d7/a0-a5
.x:	rts

; ---- close: OS alive. Keeps every register.
gbc_rtg_close:
	movem.l	d0-d1/a0-a1/a6,-(sp)
	sf	gbc_rtg_on
	move.l	gbc_rscr,d0
	beq.s	.ns
	move.l	d0,a0
	move.l	gbc_rint,a6
	jsr	-66(a6)			; CloseScreen
	clr.l	gbc_rscr
.ns:	move.l	4.w,a6
	lea	gbc_rgfx,a0
	moveq	#3-1,d1
.cl:	move.l	(a0),d0
	beq.s	.n
	clr.l	(a0)
	move.l	d0,a1
	move.l	a0,-(sp)
	jsr	-414(a6)		; CloseLibrary
	move.l	(sp)+,a0
.n:	addq.l	#4,a0
	dbra	d1,.cl
	movem.l	(sp)+,d0-d1/a0-a1/a6
	rts

	SECTION	gbcrdata,DATA
gbc_rtags:
gbc_rstw:	dc.l	$80000023,0	; SA_Width
gbc_rsth:	dc.l	$80000024,0	; SA_Height
gbc_rstd:	dc.l	$80000025,0	; SA_Depth
gbc_rstm:	dc.l	$80000032,0	; SA_DisplayID
		dc.l	$80000038,1	; SA_Quiet
		dc.l	$80000036,0	; SA_ShowTitle
		dc.l	$8000002D,$000F	; SA_Type: CUSTOMSCREEN
		dc.l	$8000003E,0	; SA_Draggable
		dc.l	$8000003F,1	; SA_Exclusive
		dc.l	0
gbc_rgfx:	dc.l	0		; (gbc_rtg_close closes these three)
gbc_rint:	dc.l	0
gbc_rp96:	dc.l	0
gbc_rscr:	dc.l	0
gbc_rbm:	dc.l	0
gbc_rmode:	dc.l	0
gbc_rmem:	dc.l	0
gbc_rbpr:	dc.l	0
gbc_rfmt:	dc.l	0
gbc_rorg:	dc.l	0
gbc_rri:	dc.l	0,0,0		; RenderInfo: Memory, BytesPerRow (word) + pad, RGBFormat
gbc_rw:		dc.w	0
gbc_rh:		dc.w	0
gbc_rscale:	dc.w	1
gbc_rtg_on:	dc.b	0
gbc_rfull:	dc.b	0
; P96 RGBFormat, gbc_pixfmt flags (bit 0 PC byte order, bit 1 5-5-5, bit 2 BGR)
gbc_rfmts:	dc.b	10,0		; R5G6B5
		dc.b	4,1		; R5G6B5PC (uaegfx)
		dc.b	11,2		; R5G5B5
		dc.b	5,3		; R5G5B5PC
		dc.b	12,5		; B5G6R5PC
		dc.b	13,7		; B5G5R5PC
		dc.b	-1,-1
	even

	SECTION	gbcrbss,BSS
gbc_fbold:	ds.w	160*144		; the frame as last copied
gbc_rrow:	ds.w	160*GBC_RMAXS	; one scaled row (3x, 4x)

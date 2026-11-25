; AmiGameBoy: Game Boy Color picture on a 16-bit Picasso96 screen (GBC_RTG test builds).
; Copyright (C) 2026 AmiGameBoy contributors. GPL-2 (see COPYING).
; After AmiPCEngine's RTG.asm (RtgFind, RtgPlayOpen, RtgCopy): the screen is opened and its
; bitmap address read with the OS alive, then written directly with the OS frozen.
; Mode: a 16-bit format of gbc_rfmts, 960x540 first, then 640x480, then the smallest mode of
; at least 320x288, else of at least 160x144. The picture at the largest integer scale that
; fits (at most 4), centred. gbc_line draws in the screen's own format (gbc_pixfmt); only
; the lines that changed since the last copy go to the screen.
; Double buffer (unless GBC_NODBUF): the screen is opened twice the mode's height; the frame
; goes to the hidden half (the lines that differ from what that half holds), then the halves
; swap: RasInfo RyOffset and graphics ScrollVPort (P96 pans the board; most boards take a new
; start address at their vertical blank). If the tall screen does not open: one buffer.
; GBC_PACELOG = n (test): per picture shown, the Amiga VBL count, the Game Boy frame and the
; beam at the start and end of the copy, saved after the AutoExit picture (tools/gbc_pace.py).

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
	IFND	GBC_NODBUF
	move.l	gbc_rsth+4,d0		; double buffer: twice the height
	add.l	d0,d0
	move.l	d0,gbc_rsth+4
	sub.l	a0,a0
	lea	gbc_rtags,a1
	move.l	gbc_rint,a6
	jsr	-612(a6)		; OpenScreenTagList
	move.l	d0,gbc_rscr
	bne.s	.db
	move.l	gbc_rsth+4,d0		; no: one buffer
	lsr.l	#1,d0
	move.l	d0,gbc_rsth+4
	ENDC
	sub.l	a0,a0
	lea	gbc_rtags,a1
	move.l	gbc_rint,a6
	jsr	-612(a6)		; OpenScreenTagList
	move.l	d0,gbc_rscr
	beq.w	.x
	IFND	GBC_NODBUF
	bra.s	.sb
.db:	st	gbc_rdbuf
.sb:
	ENDC
	IFD	GBC_RPTR
	bsr.w	gbc_rptr_on		; no mouse pointer on the game screen
	ENDC
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
.sc2:
	IFD	SGB_BFIT		; a Super Game Boy border up: the scale at which all of it fits (sgb.s)
	jsr	sgb_bfitsc
	ENDC
	move.w	d0,gbc_rscale
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
	move.l	d0,gbc_rorgs		; buffer 0 (shown)
	move.l	gbc_rbpr,d1
	mulu.w	gbc_rh,d1
	add.l	d1,d0
	move.l	d0,gbc_rorgs+4		; buffer 1 (hidden): the lower half
	move.l	gbc_rmem,a0		; clear the screen (both halves)
	move.l	gbc_rsth+4,d0
	mulu.w	gbc_rbpr+2,d0
	lsr.l	#2,d0
	bra.s	.cle
.cl:	clr.l	(a0)+
.cle:	subq.l	#1,d0
	bpl.s	.cl
	IFD	SGB_BORD		; a Super Game Boy border instead, when the cart sent one (sgb.s)
	jsr	sgb_bopen
	bne.s	.sbd
	ENDC
	IFD	GBC_RBEZ
	jsr	gbc_rbez		; "Bezel = On": the handheld round the picture
	ENDC
	IFD	SGB_BORD
.sbd:
	ENDC
	st	gbc_rfull		; the first copy to each buffer: every line
	IFD	GBC_BLEND
	st	gbc_bfirst		; no last frame yet
	ENDC
	st	gbc_rfull+1
	move.b	#1,gbc_rhid		; draw into buffer 1 first (single buffer: buffer 0)
	tst.b	gbc_rdbuf
	bne.s	.hd
	clr.b	gbc_rhid
.hd:	st	gbc_rtg_on
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
	movem.l	d0-d7/a0-a6,-(sp)
	IFD	GBC_PACELOG
	bsr.w	gbc_rpace0
	ENDC
	moveq	#0,d0
	move.b	gbc_rhid,d0		; the buffer drawn now
	lea	gbc_rfull,a6
	add.l	d0,a6			; its "every line" flag
	lea	gbc_fbold,a4		; what it holds
	tst.b	d0
	beq.s	.b0
	lea	gbc_fbold1,a4
.b0:	lea	gbc_rorgs,a1
	move.l	(a1,d0.w*4),a1
	IFD	GBC_BLEND
	lea	gbc_fb,a0
	tst.b	gbc_blendon		; "Blend = Off" in AmiGameBoy.config: the frame as it is
	beq.s	.nobl
	jsr	gbc_rblend		; LCD blend: this frame and the last, averaged
	lea	gbc_fbb,a0
.nobl:
	ELSE
	lea	gbc_fb,a0
	ENDC
	move.l	gbc_rbpr,d6
	move.w	gbc_rscale,d5
	moveq	#0,d7			; line
.ln:	tst.b	(a6)
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
	IFD	GBC_RSCAN
	bra.w	.same
	ELSE
	bra.s	.same
	ENDC
.s2:
	IFD	GBC_RSCAN
	tst.b	gbc_rscanon		; "Scanlines = On": the general path, any scale
	bne.s	.sn
	ENDC
	cmp.w	#2,d5
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
	IFD	GBC_RSCAN
	tst.b	gbc_rscanon
	beq.s	.nsc
	jsr	gbc_rdark		; the same row at half brightness: the last of the s
.nsc:
	ENDC
	move.l	a1,a5
	move.w	d5,d2
	subq.w	#1,d2
.cr:	lea	gbc_rrow,a2
	IFD	GBC_RSCAN
	tst.w	d2
	bne.s	.crn
	tst.b	gbc_rscanon
	beq.s	.crn
	lea	gbc_rrowd,a2
.crn:
	ENDC
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
	sf	(a6)
	tst.b	gbc_rdbuf
	beq.s	.nf
	move.l	gbc_rscr,a0		; show it: RyOffset = its half, ScrollVPort
	lea	$2c(a0),a0		; sc_ViewPort
	move.l	36(a0),a1		; vp_RasInfo
	moveq	#0,d0
	tst.b	gbc_rhid
	beq.s	.f0
	move.w	gbc_rh,d0
.f0:	move.w	d0,10(a1)		; ri_RyOffset
	move.l	gbc_rgfx,a6
	jsr	-588(a6)		; ScrollVPort
	eor.b	#1,gbc_rhid		; the other one next
.nf:
	IFD	GBC_PACELOG
	bsr.w	gbc_rpace1
	ENDC
	movem.l	(sp)+,d0-d7/a0-a6
.x:	rts

	IFD	GBC_PACELOG
gbc_rpace0:				; the entry: VBL count, Game Boy frame, beam now
	move.l	gbc_rpn,d0
	cmp.l	#GBC_PACELOG,d0
	bcc.s	.x
	mulu.w	#12,d0
	lea	gbc_rplog,a0
	add.l	d0,a0
	move.l	HyVblN,(a0)+
	move.w	HyFrames+2,(a0)+
	move.l	$dff004,d0
	lsr.l	#8,d0
	and.w	#$1ff,d0
	move.w	d0,(a0)+
.x:	rts
gbc_rpace1:				; the beam at the end, the VBL count again
	move.l	gbc_rpn,d0
	cmp.l	#GBC_PACELOG,d0
	bcc.s	.x
	mulu.w	#12,d0
	lea	gbc_rplog+8,a0
	add.l	d0,a0
	move.l	$dff004,d0
	lsr.l	#8,d0
	and.w	#$1ff,d0
	move.w	d0,(a0)+
	move.w	HyVblN+2,(a0)+
	addq.l	#1,gbc_rpn
.x:	rts
	ENDC

; ---- close: OS alive. Keeps every register.
gbc_rtg_close:
	movem.l	d0-d1/a0-a1/a6,-(sp)
	sf	gbc_rtg_on
	move.l	gbc_rscr,d0
	beq.s	.ns
	IFD	GBC_RPTR
	bsr.w	gbc_rptr_off
	move.l	gbc_rscr,d0
	ENDC
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

	IFD	GBC_RPTR
; ---- no mouse pointer on the game screen (15 Nov tests: a block or a dash above the
; picture). The pointer stayed on our screen while the OS is frozen; with a software sprite
; (Emu68 Videocore SOFTSPRITE=Yes, WinUAE uaegfx) it is drawn into our bitmap. A borderless
; backdrop window on our screen, active, with a blank 16x1 pointer; before our clear, so what
; P96 draws or restores while the pointer changes is cleared too. The window that was active
; gets activated again at the close. OS alive. Keeps every register.
gbc_rptr_on:
	movem.l	d0-d3/a0-a1/a6,-(sp)
	move.l	gbc_rint,a6
	move.l	$34(a6),gbc_rprevw	; IntuitionBase->ActiveWindow
	move.l	gbc_rscr,gbc_rwscr+4
	moveq	#0,d0
	move.w	gbc_rw,d0
	move.l	d0,gbc_rwtw+4
	move.w	gbc_rh,d0
	move.l	d0,gbc_rwth+4
	sub.l	a0,a0
	lea	gbc_rwtags,a1
	jsr	-606(a6)		; OpenWindowTagList
	move.l	d0,gbc_rwin
	beq.s	.x
	move.l	d0,a0
	lea	gbc_rblank,a1
	moveq	#1,d0			; height
	moveq	#16,d1			; width
	moveq	#0,d2
	moveq	#0,d3
	jsr	-270(a6)		; SetPointer
.x:	movem.l	(sp)+,d0-d3/a0-a1/a6
	rts
gbc_rptr_off:
	movem.l	d0-d1/a0-a1/a6,-(sp)
	move.l	gbc_rwin,d0
	beq.s	.x
	clr.l	gbc_rwin
	move.l	d0,a0
	move.l	gbc_rint,a6
	jsr	-72(a6)			; CloseWindow (its pointer goes with it)
	move.l	gbc_rprevw,d0		; the window that was active (the menu's), if it is still open
	beq.s	.x
	clr.l	gbc_rprevw
	move.l	d0,a0
	jsr	-450(a6)		; ActivateWindow
.x:	movem.l	(sp)+,d0-d1/a0-a1/a6
	rts
	SECTION	gbcrpdata,DATA
gbc_rwtags:
gbc_rwscr:	dc.l	$80000070,0	; WA_CustomScreen
		dc.l	$80000064,0	; WA_Left
		dc.l	$80000065,0	; WA_Top
gbc_rwtw:	dc.l	$80000066,0	; WA_Width
gbc_rwth:	dc.l	$80000067,0	; WA_Height
		dc.l	$80000085,1	; WA_Backdrop
		dc.l	$80000088,1	; WA_Borderless
		dc.l	$8000008C,1	; WA_SimpleRefresh
		dc.l	$80000087,1	; WA_NoCareRefresh
		dc.l	$8000008A,1	; WA_RMBTrap
		dc.l	$80000089,1	; WA_Activate
		dc.l	0
gbc_rwin:	dc.l	0
gbc_rprevw:	dc.l	0
	SECTION	gbcrpchip,DATA_C
gbc_rblank:	dc.w	0,0,0,0,0,0	; a blank sprite: control, one line, end
	ENDC

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
gbc_rorgs:	dc.l	0,0		; buffer 0, buffer 1: the picture's top left
gbc_rtg_on:	dc.b	0
gbc_rfull:	dc.b	0,0		; per buffer: copy every line next time
gbc_rdbuf:	dc.b	0		; double-height screen open
gbc_rhid:	dc.b	0		; the buffer to draw into
; P96 RGBFormat, gbc_pixfmt flags (bit 0 PC byte order, bit 1 5-5-5, bit 2 BGR)
gbc_rfmts:	dc.b	10,0		; R5G6B5
		dc.b	4,1		; R5G6B5PC (uaegfx)
		dc.b	11,2		; R5G5B5
		dc.b	5,3		; R5G5B5PC
		dc.b	12,5		; B5G6R5PC
		dc.b	13,7		; B5G5R5PC
		dc.b	-1,-1
	even

	IFD	GBC_BLEND
; ---- LCD blend (15 Nov, Bubble Bobble's per-frame sprite flicker): gbc_fbb = the average of
; this frame (gbc_fb) and the last one shown (gbc_fbprev), per channel, two pixels a long:
; (a & b) + ((a ^ b) & ~lsb) >> 1. PC byte order: bytes swapped around it. A real Game Boy LCD
; is slow enough to do much the same. OS frozen. Keeps every register.
	SECTION	gbcrbcode,CODE
gbc_rblend:
	movem.l	d0-d4/a0-a2,-(sp)
	lea	gbc_fb,a0
	lea	gbc_fbprev,a1
	lea	gbc_fbb,a2
	tst.b	gbc_bfirst
	beq.s	.go
	sf	gbc_bfirst		; first frame on this screen: no blend
	move.w	#160*144/2-1,d0
.f:	move.l	(a0)+,(a1)+
	dbra	d0,.f
	lea	gbc_fb,a0
	lea	gbc_fbprev,a1
.go:	move.l	#$f7def7de,d3		; 5-6-5: lsb of each channel cleared
	btst	#1,gbc_pixfmt
	beq.s	.m
	move.l	#$7bde7bde,d3		; 5-5-5 (and the spare top bit)
.m:	move.w	#160*144/2-1,d4
	btst	#0,gbc_pixfmt
	bne.s	.pc
.l:	move.l	(a0)+,d0
	move.l	(a1),d1
	move.l	d0,(a1)+
	move.l	d0,d2
	and.l	d1,d2
	eor.l	d1,d0
	and.l	d3,d0
	lsr.l	#1,d0
	add.l	d2,d0
	move.l	d0,(a2)+
	dbra	d4,.l
	bra.s	.x
.pc:	move.l	(a0)+,d0
	move.l	(a1),d1
	move.l	d0,(a1)+
	ror.w	#8,d0
	swap	d0
	ror.w	#8,d0
	swap	d0
	ror.w	#8,d1
	swap	d1
	ror.w	#8,d1
	swap	d1
	move.l	d0,d2
	and.l	d1,d2
	eor.l	d1,d0
	and.l	d3,d0
	lsr.l	#1,d0
	add.l	d2,d0
	ror.w	#8,d0
	swap	d0
	ror.w	#8,d0
	swap	d0
	move.l	d0,(a2)+
	dbra	d4,.pc
.x:	movem.l	(sp)+,d0-d4/a0-a2
	rts

; "Blend = On|Off" in the config text (padcfg.s calls this on what it read): a0 = text,
; a1 = its end. Any case, blanks around the "="; a line that does not parse changes
; nothing. OS alive (start-up). Keeps every register.
gbc_blendcfg:
	movem.l	d0-d2/a0/a2-a3,-(sp)
.line:	bsr.s	.blank
	lea	gbc_bkey,a2
	bsr.s	.word
	beq.s	.skip
	bsr.s	.blank
	cmp.l	a1,a0
	bcc.s	.skip
	cmp.b	#"=",(a0)+
	bne.s	.skip
	bsr.s	.blank
	lea	gbc_bon,a2
	moveq	#1,d2
	move.l	a0,a3
	bsr.s	.word
	bne.s	.set
	move.l	a3,a0
	lea	gbc_boff,a2
	moveq	#0,d2
	bsr.s	.word
	beq.s	.skip
.set:	move.b	d2,gbc_blendon
.skip:	cmp.l	a1,a0			; to the next line
	bcc.s	.x
	cmp.b	#10,(a0)+
	bne.s	.skip
	bra.s	.line
.x:	movem.l	(sp)+,d0-d2/a0/a2-a3
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
; the upper-case word at a2 (ends with 0) at a0, any case, a whole word: NE and a0
; behind it, or EQ (a0 somewhere in it)
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

	SECTION	gbcrbdata,DATA
	IFND	GBC_BLENDDEF
GBC_BLENDDEF	=1			; on unless the config says Off
	ENDC
gbc_blendon:	dc.b	GBC_BLENDDEF
gbc_bfirst:	dc.b	1
gbc_bkey:	dc.b	"BLEND",0
gbc_bon:	dc.b	"ON",0
gbc_boff:	dc.b	"OFF",0
	even
	SECTION	gbcrbbss,BSS
gbc_fbprev:	ds.w	160*144		; the last frame shown
gbc_fbb:	ds.w	160*144		; the blended frame
	ENDC

	SECTION	gbcrbss,BSS
gbc_fbold:	ds.w	160*144		; the frame as last copied to buffer 0
gbc_fbold1:	ds.w	160*144		; ... to buffer 1
	IFD	GBC_PACELOG
gbc_rpn:	ds.l	1
gbc_rplog:	ds.b	12*GBC_PACELOG
	ENDC
gbc_rrow:	ds.w	160*GBC_RMAXS	; one scaled row (3x, 4x)

	IFD	GBC_RTGMENU
; ---- the menu on the RTG board too (15 Nov 2026): once, before Juan's SetupScreen.
; Juan's ScreenTags ask for PAL hires ($29000, the 9th tag); this puts a Picasso96 ModeID
; there instead: 640xGBC_RTGMH (256) first, else the smallest P96 mode of at least 640x212. Juan's
; 640x212 screen opens on it (depth 3 = an 8-bit CLUT screen). No P96 or no such mode: the
; tags stay as they are (the PAL screen, as before). OS alive. Keeps every register.
	IFND	GBC_RTGMH
GBC_RTGMH	equ	256		; 640x256 = the PAL hires shape: the scaler stretches it, 15 Nov: looks much better than 640x480
	ENDC
	SECTION	gbcrmcode,CODE
gbc_rtg_menumode:
	movem.l	d0-d7/a0-a6,-(sp)
	cmp.l	#$80000032,ScreenTags+64	; SA_DisplayID where expected?
	bne.w	.x
	sub.l	a5,a5			; graphics
	sub.l	a4,a4			; P96
	move.l	4.w,a6
	lea	.gfx(pc),a1
	moveq	#39,d0
	jsr	-552(a6)		; OpenLibrary
	move.l	d0,a5
	tst.l	d0
	beq.w	.close
	lea	.p96(pc),a1
	moveq	#2,d0
	jsr	-552(a6)
	move.l	d0,a4
	tst.l	d0
	beq.w	.close
	moveq	#-1,d6			; best rank (lower is better)
	moveq	#-1,d5			; its ModeID
	moveq	#-1,d4
.next:	move.l	d4,d0
	move.l	a5,a6
	jsr	-732(a6)		; NextDisplayInfo
	move.l	d0,d4
	cmp.l	#-1,d4
	beq.s	.done
	moveq	#6,d1			; P96IDA_ISP96
	bsr.s	.attr
	tst.l	d0
	beq.s	.next
	moveq	#0,d1			; width
	bsr.s	.attr
	move.l	d0,d2
	moveq	#1,d1			; height
	bsr.s	.attr
	move.l	d0,d3
	cmp.l	#640,d2
	bcs.s	.next
	cmp.l	#212,d3
	bcs.s	.next
	moveq	#0,d0			; rank 0: 640xGBC_RTGMH
	cmp.l	#640,d2
	bne.s	.area
	IFD	GBC_RTGMH
	cmp.l	#GBC_RTGMH,d3		; e.g. 256: the PAL hires size, so the scaler keeps Juan's tall pixels (15 Nov)
	ELSE
	cmp.l	#480,d3
	ENDC
	beq.s	.rk
.area:	move.l	d2,d0			; then the smallest area
	mulu.w	d3,d0
.rk:	cmp.l	d6,d0
	bcc.s	.next
	move.l	d0,d6
	move.l	d4,d5
	bra.s	.next
.done:	cmp.l	#-1,d5
	beq.s	.close
	move.l	d5,ScreenTags+68
.close:	move.l	4.w,a6
	move.l	a4,d0
	beq.s	.c1
	move.l	a4,a1
	jsr	-414(a6)		; CloseLibrary
.c1:	move.l	a5,d0
	beq.s	.x
	move.l	a5,a1
	jsr	-414(a6)
.x:	movem.l	(sp)+,d0-d7/a0-a6
	rts
.attr:	move.l	d4,d0			; P96 GetModeIDAttr(d4, d1)
	move.l	a4,a6
	jmp	-84(a6)
.gfx:	dc.b	"graphics.library",0
.p96:	dc.b	"Picasso96API.library",0
	even
	ENDC

	IFD	GBC_RBEZ
; ---- the bezel (15 Nov: "Bezel = On" in AmiGameBoy.config, gbc_rcfg; RTG only): the
; screen surround of tools/bezel_rtg_art.py, 320 x 180 Game Boy pixels with the picture at
; (80, 18), drawn once into each buffer when the screen opens, at the picture's scale and
; lined up with it; what falls outside the mode is left out. Scale 1: no room, none drawn.
; OS alive (gbc_rtg_open, after the clear). Keeps every register.
	SECTION	gbcrzcode,CODE
gbc_rbez:
	tst.b	gbc_rbezon
	beq.w	.x
	cmp.w	#2,gbc_rscale
	bcs.w	.x
	movem.l	d0-d7/a0-a6,-(sp)
	lea	gbc_rzart,a0		; the 16 colours in the screen's format
	lea	gbc_rzcol,a1
	moveq	#16-1,d7
.col:	moveq	#0,d0
	move.b	(a0)+,d0		; r
	moveq	#0,d1
	move.b	(a0)+,d1		; g
	moveq	#0,d2
	move.b	(a0)+,d2		; b
	btst	#2,gbc_pixfmt		; BGR: blue in the top bits
	beq.s	.rgb
	exg	d0,d2
.rgb:	lsr.w	#3,d0
	lsr.w	#3,d2
	btst	#1,gbc_pixfmt
	bne.s	.c555
	lsr.w	#2,d1			; 5-6-5
	lsl.w	#5,d1
	moveq	#11,d3
	lsl.w	d3,d0
	bra.s	.cm
.c555:	lsr.w	#3,d1			; 5-5-5
	lsl.w	#5,d1
	moveq	#10,d3
	lsl.w	d3,d0
.cm:	or.w	d1,d0
	or.w	d2,d0
	btst	#0,gbc_pixfmt		; PC byte order
	beq.s	.be
	ror.w	#8,d0
.be:	move.w	d0,(a1)+
	dbra	d7,.col
	move.w	gbc_rscale,d5		; d5 = s
	move.w	d5,d0			; ox = the picture's left - 80s
	mulu.w	#160,d0
	move.w	gbc_rw,d1
	sub.w	d0,d1
	lsr.w	#1,d1
	move.w	d5,d0
	mulu.w	#80,d0
	sub.w	d0,d1
	move.w	d1,gbc_rzox
	move.w	d5,d0			; oy = the picture's top - 18s
	mulu.w	#144,d0
	move.w	gbc_rh,d1
	sub.w	d0,d1
	lsr.w	#1,d1
	move.w	d5,d0
	mulu.w	#18,d0
	sub.w	d0,d1
	move.w	d1,gbc_rzoy
	lea	gbc_rzcol,a1
	move.l	gbc_rmem,a6		; buffer 0
	bsr.s	.buf
	tst.b	gbc_rdbuf
	beq.s	.done
	move.l	gbc_rbpr,d0		; buffer 1: the lower half
	mulu.w	gbc_rh,d0
	add.l	d0,a6
	bsr.s	.buf
.done:	movem.l	(sp)+,d0-d7/a0-a6
.x:	rts
; one buffer at a6. d3 = art row, d2 = its screen row within s
.buf:	moveq	#0,d3
.ay:	moveq	#0,d2
.sy:	move.w	d3,d0
	mulu.w	d5,d0
	add.w	gbc_rzoy,d0
	add.w	d2,d0			; the screen row
	bmi.s	.nsy
	cmp.w	gbc_rh,d0
	bge.s	.nsy
	mulu.w	gbc_rbpr+2,d0
	lea	(a6,d0.l),a3
	move.w	d3,d0
	mulu.w	#160,d0
	lea	gbc_rzart+48,a0
	add.l	d0,a0
	move.w	gbc_rzox,d1		; x
	move.w	#160-1,d7
.px:	moveq	#0,d0
	move.b	(a0)+,d0
	move.w	d0,d6
	lsr.w	#4,d0
	bsr.s	.put
	moveq	#15,d0
	and.w	d6,d0
	bsr.s	.put
	dbra	d7,.px
.nsy:	addq.w	#1,d2
	cmp.w	d5,d2
	bne.s	.sy
	addq.w	#1,d3
	cmp.w	#180,d3
	bne.s	.ay
	rts
; colour d0 at x = d1 (s pixels, those inside the mode), d1 moves on
.put:	move.w	(a1,d0.w*2),d0
	move.w	d5,d4
	subq.w	#1,d4
.sx:	tst.w	d1
	bmi.s	.nx
	cmp.w	gbc_rw,d1
	bge.s	.nx
	move.w	d0,(a3,d1.w*2)
.nx:	addq.w	#1,d1
	dbra	d4,.sx
	rts

	SECTION	gbcrzdata,DATA
gbc_rzart:	INCBIN	"data/bezel_rtg.raw"	; tools/bezel_rtg_art.py
	even
	SECTION	gbcrzbss,BSS
gbc_rzcol:	ds.w	16		; the art's colours, screen format
gbc_rzox:	ds.w	1		; the art's top left on the screen
gbc_rzoy:	ds.w	1
	ENDC

	IFD	GBC_RSCAN
; ---- scanlines (15 Nov, "Scanlines = On" in AmiGameBoy.config, gbc_rcfg): at scale 2 and up the last
; of each picture row's s screen rows at half brightness. gbc_rrow (d5 = s, words s x 160) ->
; gbc_rrowd, per channel >> 1, two pixels a long; PC byte order: bytes swapped around it.
; OS frozen (gbc_rtg_show). Keeps every register.
	SECTION	gbcrscode,CODE
gbc_rdark:
	movem.l	d0-d3/a0-a1,-(sp)
	lea	gbc_rrow,a0
	lea	gbc_rrowd,a1
	move.l	#$7bef7bef,d3		; 5-6-5: the bit each channel shifts into its neighbour
	btst	#1,gbc_pixfmt
	beq.s	.m
	move.l	#$3def3def,d3		; 5-5-5
.m:	move.w	d5,d2
	mulu.w	#160/2,d2
	subq.w	#1,d2
	btst	#0,gbc_pixfmt
	bne.s	.pc
.l:	move.l	(a0)+,d0
	lsr.l	#1,d0
	and.l	d3,d0
	move.l	d0,(a1)+
	dbra	d2,.l
	bra.s	.x
.pc:	move.l	(a0)+,d0
	ror.w	#8,d0
	swap	d0
	ror.w	#8,d0
	swap	d0
	lsr.l	#1,d0
	and.l	d3,d0
	ror.w	#8,d0
	swap	d0
	ror.w	#8,d0
	swap	d0
	move.l	d0,(a1)+
	dbra	d2,.pc
.x:	movem.l	(sp)+,d0-d3/a0-a1
	rts
	SECTION	gbcrsbss,BSS
gbc_rrowd:	ds.w	160*GBC_RMAXS	; gbc_rrow at half brightness
	ENDC

	IFD	GBC_RBEZ
GBC_RCFG	SET	1
	ENDC
	IFD	GBC_RSCAN
GBC_RCFG	SET	1
	ENDC
	IFD	GBC_RCFG
; ---- "Bezel = On|Off", "Scanlines = On|Off" in the config text (padcfg.s calls this on what it
; read): a0 = text, a1 = its end. Any case, blanks around the "="; a line that does not parse
; changes nothing. OS alive (start-up). Keeps every register.
	SECTION	gbcrccode,CODE
gbc_rcfg:
	movem.l	d0-d1/a0/a2-a4,-(sp)
.line:	bsr.s	.blank
	move.l	a0,a3			; the line, after its blanks
	lea	gbc_rcfgtab,a4
.ent:	tst.l	(a4)
	beq.s	.skip
	move.l	a3,a0
	move.l	4(a4),a2		; the setting
	bsr.s	.word
	beq.s	.nx
	bsr.s	.blank
	cmp.l	a1,a0
	bcc.s	.nx
	cmp.b	#"=",(a0)+
	bne.s	.nx
	bsr.s	.blank
	move.l	8(a4),a2		; the value
	bsr.s	.word
	beq.s	.nx
	move.l	(a4),a2
	move.b	13(a4),(a2)
	bra.s	.skip
.nx:	lea	14(a4),a4
	bra.s	.ent
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
; the upper-case word at a2 (ends with 0) at a0, any case, a whole word: NE and a0
; behind it, or EQ
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

	SECTION	gbcrcdata,DATA
; where (byte), the setting, the value, what (word: its low byte)
gbc_rcfgtab:
	IFD	GBC_RBEZ
	dc.l	gbc_rbezon,gbc_rkbez,gbc_rkon
	dc.w	1
	dc.l	gbc_rbezon,gbc_rkbez,gbc_rkoff
	dc.w	0
	ENDC
	IFD	GBC_RSCAN
	dc.l	gbc_rscanon,gbc_rkscan,gbc_rkon
	dc.w	1
	dc.l	gbc_rscanon,gbc_rkscan,gbc_rkoff
	dc.w	0
	ENDC
	IFD	SGB_OPT			; "Super Game Boy = Auto|Off" (sgb.s)
	dc.l	sgb_opt,sgb_kname,sgb_kauto
	dc.w	1
	dc.l	sgb_opt,sgb_kname,gbc_rkoff
	dc.w	0
	ENDC
	dc.l	0
	IFD	GBC_RBEZON		; release default (16 Nov): on unless the config says Off
gbc_rbezon:	dc.b	1		; "Bezel = On"
	ELSE
gbc_rbezon:	dc.b	0		; "Bezel = On"
	ENDC
gbc_rscanon:	dc.b	0		; "Scanlines = On"
gbc_rkbez:	dc.b	"BEZEL",0
gbc_rkscan:	dc.b	"SCANLINES",0
gbc_rkon:	dc.b	"ON",0
gbc_rkoff:	dc.b	"OFF",0
	even
	ENDC

	IFD	GBC_BIGMENU
	include	"bigmenu.s"		; the big RTG menu (prototype, 24 Nov 2026)
	ENDC

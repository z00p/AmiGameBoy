; AmiGameBoy hybrid: the window's start line as the Game Boy finds it (HY_WYLINE).
; Copyright (C) 2026 AmiGameBoy contributors. GPL-2 (see src/engine/COPYING).
;
; The DMG starts the window on the first line where LY = WY, with WY as it is on that line;
; a WY written inside the picture counts from its line on. Juan's renderer follows that for
; the window itself (AcCoRutWinY, HyWinTrig), but the line where it cuts the BG for the
; window (ActCopperLine) came from WY as it stood when the picture was built, at LY 144.
; Mega Man V's weapon panel slides up by writing next frame's WY at LY 128: the BG ended
; 8 lines above the window and the lines between were black.
;
;   HyLine0Wy    start of LY 0: HyWyTrig = WY (the window starts there unless a later
;                write moves it), then the palettes / ActCopperLine0 as before
;   hy_w4a_wy    a WY write at a line the window has not started above: the start
;                moves to the new WY, or none this frame if that is above the line
;                (the same rule as AcCoRutWinY); then glue.s hy_w4a
;
; ActCopperLine reads HyWyTrig (juan_video.s). Everything sits in sections of its own and
; the two changed places in hybrid.asm keep their size: no routine moves (68030 I-cache).

	SECTION	hywyl,CODE

HyLine0Wy:
	move.b	RRAM+$1f4a,HyWyTrig
	cmp.b	#$90,HyWyTrig
	bcs.s	.c
	move.b	#$90,HyWyTrig		; below the picture: no window this frame
.c:
	IFND	NO_LINEPAL
	jmp	HyLine0Pal
	ELSE
	jmp	ActCopperLine0
	ENDC

; ---- $FF4A WY (as glue.s: d6 = value, d7 = address, a2 = memory; keeps all but d6, a6)
	cnop	0,4
hy_w4a_wy:
	movem.l	d0-d1,-(sp)
	jsr	hy_line			; d1 = the line the write counts from
	cmp.b	HyWyTrig,d1
	bhi.s	.x			; the window started above this line: it stays
	move.b	d6,d0
	cmp.b	#$90,d0
	bcs.s	.c
	move.b	#$90,d0
.c:	cmp.b	d1,d0
	bcc.s	.t			; WY on or below this line: the window starts there
	move.b	#$90,d0			; above it: no window for the rest of this frame
.t:	move.b	d0,HyWyTrig
.x:	movem.l	(sp)+,d0-d1
	jmp	hy_w4a

	IFD	HY_WYSTAT		; test: drawn frames whose window start line differs
HyWyStat:				; from WY at LY 144 (window on): where HY_WYLINE
	btst	#5,RRAM+$1f40		; changes the picture at all (HyResult "wyd=")
	beq.s	.x
	move.l	d0,-(sp)
	move.b	RRAM+$1f4a,d0
	cmp.b	#$90,d0
	bcs.s	.c
	move.b	#$90,d0
.c:	cmp.b	HyWyTrig,d0
	beq.s	.s
	tst.l	HyWyDiff
	bne.s	.n
	move.l	HyFrames,HyWyF1		; the first such frame, WY and the start line there
	move.b	d0,HyWyV1+2
	move.b	HyWyTrig,HyWyV1+3
.n:	addq.l	#1,HyWyDiff
.s:	move.l	(sp)+,d0
.x:	rts
	ENDC

	SECTION	hywyd,DATA
HyWyTrig:	dc.b	$90,0
	IFD	HY_WYSTAT
HyWyDiff:	dc.l	0
HyWyF1:	dc.l	0
HyWyV1:	dc.l	0
	ENDC

	SECTION	hybrid,CODE		; back where hybrid.asm goes on (as linepal.s)

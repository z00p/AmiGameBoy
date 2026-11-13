; AmiGameBoy hybrid: palettes that change inside the picture.
; Copyright (C) 2026 AmiGameBoy contributors. GPL-2 (see src/engine/COPYING).
;
; Juan's renderer already changes the BG colours on the line of a BGP write (copper,
; AcCoRutColorBG). But it took the colours for the top of the picture from the registers
; as they stood when the picture was built (LY 144), which is the palette of the bottom:
; a game with one BGP above its text box and another in it (Last Crown Warriors, Super
; Jetpak DX's choice page) got the box's palette on the whole screen. And the sprite
; palettes were not followed at all.
;
;   HyLine0Pal   start of LY 0: BGP, OBP0, OBP1 for the top of the picture (PonePaleta
;                reads them here)
;   hy_w48/w49   OBP0 and OBP1 writes logged with their line, as Juan's log has BGP
;                (TabRasCMDS bits 5 and 6, TabRasDATA bytes 6 and 7)
;   HyCoObj      the line's copper routine: the sprite colours (3 moves for OBP0, 12
;                for OBP1), behind Juan's BG ones
;
; Cost: nothing on a line without a palette write. Everything sits in sections of its
; own and the four changed places keep their size: no routine of the engine or the
; renderer moves (68030 instruction cache, as NO_IDLEPAD). NO_LINEPAL leaves it out.

	SECTION	hylpal,CODE

; ---- hybrid_line0, in front of ActCopperLine0
HyLine0Pal:
	move.b	RRAM+$1f47,HyPal0
	move.b	RRAM+$1f48,HyPal0+1
	move.b	RRAM+$1f49,HyPal0+2
	jmp	ActCopperLine0

; ---- HyPatchWrites: a1 = the write table at $FF40
HyPalPatch:
	move.l	#hy_w47,$7*4(a1)
	move.l	#hy_w48,$8*4(a1)
	move.l	#hy_w49,$9*4(a1)
	rts

; ---- $FF48 OBP0, $FF49 OBP1 (as glue.s: d6 = value, d7 = address, a2 = memory)
	cnop	0,4
hy_w48:	move.b	d6,(a2,d7.l)
	move.l	d1,-(sp)
	jsr	hy_line
	or.b	#$20,(TabRasCMDS.l,d1.w)
	move.b	d6,(TabRasDATA+6.l,d1.w*8)
	move.l	(sp)+,d1
	rts
	cnop	0,4
hy_w49:	move.b	d6,(a2,d7.l)
	move.l	d1,-(sp)
	jsr	hy_line
	or.b	#$40,(TabRasCMDS.l,d1.w)
	move.b	d6,(TabRasDATA+7.l,d1.w*8)
	move.l	(sp)+,d1
	rts

; ---- Juan's AcCoRut at AcCoRet4, in place of its "MOVE.L (SP)+,D3" and
; "MOVE.W #$0086,(A3)+": d5 = the line's commands shifted down to bits 5 and 6,
; d7 = line, a3 = copper routine being written; d0-d1/a0-a1 free
HyCoObj:
	lea	GBPaleta,a1
	lsr.b	#1,d5
	bcc.s	.no0
	cmp.l	#CopperOpts+1024*8-256,a3	; (room left in the copper space)
	bcc.s	.no0
	move.b	(TabRasDATA+6.l,d7.w*8),d0
	bfextu	d0{24:2},d1
	move.w	#$186,(a3)+
	move.w	(a1,d1.w*2),(a3)+
	bfextu	d0{26:2},d1
	move.w	#$184,(a3)+
	move.w	(a1,d1.w*2),(a3)+
	bfextu	d0{28:2},d1
	move.w	#$182,(a3)+
	move.w	(a1,d1.w*2),(a3)+
.no0:	lsr.b	#1,d5
	bcc.s	.no1
	cmp.l	#CopperOpts+1024*8-256,a3
	bcc.s	.no1
	move.b	(TabRasDATA+7.l,d7.w*8),d0
	bfextu	d0{24:2},d1
	move.w	(a1,d1.w*2),d1
	move.w	#$198,d0
	bsr.s	.four
	move.b	(TabRasDATA+7.l,d7.w*8),d0
	bfextu	d0{26:2},d1
	move.w	(a1,d1.w*2),d1
	move.w	#$190,d0
	bsr.s	.four
	move.b	(TabRasDATA+7.l,d7.w*8),d0
	bfextu	d0{28:2},d1
	move.w	(a1,d1.w*2),d1
	move.w	#$188,d0
	bsr.s	.four
.no1:	move.l	(sp)+,a0		; back into AcCoRut with what we replaced done
	move.l	(sp)+,d3
	move.w	#$0086,(a3)+
	jmp	(a0)
.four:	move.w	d0,(a3)+		; four colour registers from d0, colour d1
	move.w	d1,(a3)+
	addq.w	#2,d0
	move.w	d0,(a3)+
	move.w	d1,(a3)+
	addq.w	#2,d0
	move.w	d0,(a3)+
	move.w	d1,(a3)+
	addq.w	#2,d0
	move.w	d0,(a3)+
	move.w	d1,(a3)+
	rts

	SECTION	hylpaldata,DATA
HyPal0:	dc.b	$fc,$ff,$ff,0		; BGP, OBP0, OBP1 at line 0

	SECTION	hybrid,CODE

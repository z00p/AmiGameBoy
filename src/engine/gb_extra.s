; AmiGameBoy engine additions (not from Wzonka-Lad).
; Copyright (C) 2026 AmiGameBoy contributors. GPL-2 (see COPYING).

; ---- boot_vram: what the DMG boot ROM leaves in VRAM (switch NO_BOOTVRAM)
; The cartridge's logo ($0104-$0133) as tiles 1-24 at $8010, each nibble scaled to
; 8 pixels and written as two rows (bitplane 1 zero); the (R) mark as tile $19 at $8190;
; map $9904-$990F = 1-12, $9910 = $19, $9924-$992F = 13-24. Checked against Mesen 2's
; post-boot state (no boot ROM), 10 Nov 2026.
	IFND	NO_BOOTVRAM
boot_vram:
	movem.l	d0-d3/a0-a2,-(sp)
	move.l	cartridge,a0
	lea	$104(a0),a0
	move.l	gb_memory,a1
	lea	$8010(a1),a2
	moveq	#48-1,d0
.byte:	move.b	(a0)+,d1
	moveq	#2-1,d3
.nib:	rol.b	#4,d1			; next nibble to the bottom
	move.b	d1,d2
	and.w	#15,d2
	move.b	.scale(pc,d2.w),d2
	move.b	d2,(a2)+
	clr.b	(a2)+
	move.b	d2,(a2)+
	clr.b	(a2)+
	dbra	d3,.nib
	dbra	d0,.byte
	lea	.regd(pc),a0		; (R) tile at $8190
	moveq	#8-1,d0
.reg:	move.b	(a0)+,(a2)+
	clr.b	(a2)+
	dbra	d0,.reg
	lea	$9904(a1),a2		; map
	moveq	#1,d1
	moveq	#12-1,d0
.m1:	move.b	d1,(a2)+
	addq.b	#1,d1
	dbra	d0,.m1
	move.b	#$19,(a2)
	lea	$9924(a1),a2
	moveq	#12-1,d0
.m2:	move.b	d1,(a2)+
	addq.b	#1,d1
	dbra	d0,.m2
	movem.l	(sp)+,d0-d3/a0-a2
	rts
.scale:	dc.b	$00,$03,$0c,$0f,$30,$33,$3c,$3f,$c0,$c3,$cc,$cf,$f0,$f3,$fc,$ff
.regd:	dc.b	$3c,$42,$b9,$a5,$b9,$a5,$42,$3c
	even
	ENDC

; ---- snd_reg_store: sound registers without a sound back end (NO_SOUND hybrid builds and
; the spike; switch NO_SNDREGS). Wzonka's table ignored writes to $FF10-$FF3F unless AHI
; sound ran, so reads gave the post-boot values: Dangan GB fades NR50 down in a loop and
; never got to 0 (black screen). Now stored with the DMG's read-back bits (NR52: power bit
; only, no channel status), wave RAM plain.
	IFND	NO_SNDREGS
	IFD	SPIKE
SNDREGS_ON	=1
	ENDC
	IFD	NO_SOUND
SNDREGS_ON	=1
	ENDC
	ENDC
	IFD	SNDREGS_ON
snd_reg_store:
	lea	snd_rd_and-$ff10,a6
	and.b	(a6,d7.l),d6
	or.b	32(a6,d7.l),d6
	move.b	d6,(a2,d7.l)
	rts
; a0 = gb_mem_jumps
snd_regs_install:
	movem.l	d0-d1/a1,-(sp)
	lea	$ff10*4(a0),a1
	move.l	#snd_reg_store,d0
	moveq	#$30-$10-1,d1
.r:	move.l	d0,(a1)+
	dbra	d1,.r
	move.l	#gb_mem_wr,d0		; wave RAM $FF30-$FF3F
	moveq	#16-1,d1
.w:	move.l	d0,(a1)+
	dbra	d1,.w
	movem.l	(sp)+,d0-d1/a1
	rts
snd_rd_and:	; $FF10-$FF2F: bits kept from the write
	dc.b	$ff,$ff,$ff,$ff,$ff,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00
	dc.b	$ff,$ff,$ff,$ff,$ff,$ff,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00
snd_rd_or:	; bits that read as 1
	dc.b	$80,$3f,$00,$ff,$bf,$ff,$3f,$00,$ff,$bf,$7f,$ff,$9f,$ff,$bf,$ff
	dc.b	$ff,$00,$00,$bf,$00,$00,$70,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	even
	ENDC

; AmiGameBoy hybrid: battery saves for MBC5 carts with 64 or 128 KB of cartridge RAM
; ($149 = 5 or 4; Last Crown Warriors has 128 KB). HY_SAVE128 builds only.
; Copyright (C) 2026 AmiGameBoy contributors. GPL-2 (see src/engine/COPYING).
;
; Before (1.0): Juan's menu takes the save size from $149 & 3 (BattKbs: 1 = 2 KB, 2 = 8 KB,
; 3 = 32 KB), so $04 gave 0 (no save at all) and $05 gave 2 KB; his .sav buffer (ERAM0-3)
; holds 32 KB. The engine's compute_jmp_lst did the same ($149 & 3): $04 took the "no RAM"
; mapper list, so MBC5 RAM bank writes were ignored and the game only ever saw bank 0.
; Now, for MBC5 carts (types $19-$1E) only:
;  - hy_ramidx (engine, compute_jmp_lst): $04 and $05 take Wzonka's 128 KB MBC5 list (RAM
;    bank switching, ram_banks_mask 15 from the hybrid's header code);
;  - BattKbs = 4 (128 KB) or 5 (64 KB) (HySaveKbs, from menu.s HyBattKbs);
;  - the banks after the first four live in ERAMX (12 x 8 KB, no gaps): the .sav is Juan's
;    32 KB (ERAM0-3) followed by 96 KB (or 32 KB) more, the cart RAM in bank order, the
;    same layout as other emulators' .sav/.srm files. Hooks in Juan's ReadBatt/SaveBatt
;    (the rest of the file), CalChecksum (the extra banks count, so a change there is
;    saved), ClearBatt and Insert (cleared); menu.s HyBattIn/HyBattOut copy them to and
;    from the engine's memory_banks 4-15.
; Every other cart (BattKbs 0-3) goes exactly the old way: the new code returns at once.
; Needs menu.s's HyBattKbs (not with NO_MBC2SAVE: then 64/128 KB carts save as before).
; All of it in sections of its own; the engine's patch keeps its 8 bytes.

	SECTION	hysave,CODE

; ---- engine (compute_jmp_lst, in place of "move.b $149(a0),d0 / and.b #%11,d0"):
; a0 = the cartridge header base, d0.l = the cart type ($147, upper bytes 0)
; -> d0.l = the mapper list's RAM index: 4 for MBC5 with $149 = 4 or 5, else $149 & 3
hy_ramidx:
	cmp.b	#$19,d0
	bcs.s	.std
	cmp.b	#$1e,d0
	bhi.s	.std
	move.b	$149(a0),d0
	cmp.b	#4,d0
	beq.s	.x
	cmp.b	#5,d0
	bne.s	.and
	moveq	#4,d0
.x:	rts
.std:	move.b	$149(a0),d0
.and:	and.b	#%11,d0
	rts

	IFD	HY_MENU
; ---- menu.s HyBattKbs (Insert): d0.b = $147, a0 = DirCart (page 0 at $80). MBC5 with
; $149 = 4 -> BattKbs 4 (128 KB), 5 -> 5 (64 KB). All registers kept.
HySaveKbs:
	cmp.b	#$19,d0
	bcs.s	.x
	cmp.b	#$1e,d0
	bhi.s	.x
	cmp.b	#4,$80+$149(a0)
	bne.s	.n5
	move.b	#4,BattKbs
	rts
.n5:	cmp.b	#5,$80+$149(a0)
	bne.s	.x
	move.b	#5,BattKbs
.x:	rts

; d3.l = the bytes held in ERAMX for this cart (0: none, Z set). Only d3 changes.
HyXLen:	moveq	#0,d3
	cmp.b	#4,BattKbs
	beq.s	.128
	cmp.b	#5,BattKbs
	bne.s	.x
	move.l	#4*8192,d3		; 64 KB: banks 4-7
	rts
.128:	move.l	#12*8192,d3		; 128 KB: banks 4-15
.x:	tst.l	d3
	rts

; ---- Juan's ReadBatt / SaveBatt, after ERAM3 (file open, DisBase): the rest of the file
HyBattRdX:
	movem.l	d0-d3/a0-a1/a6,-(sp)
	bsr.w	HyXLen
	beq.s	.x
	move.l	#ERAMX,d2
	jsr	ReadFile
.x:	movem.l	(sp)+,d0-d3/a0-a1/a6
	rts
HyBattWrX:
	movem.l	d0-d3/a0-a1/a6,-(sp)
	bsr.w	HyXLen
	beq.s	.x
	move.l	#ERAMX,d2
	jsr	WriteFile
.x:	movem.l	(sp)+,d0-d3/a0-a1/a6
	rts

; ---- Juan's CalChecksum, at its end: d2 = his sum; the extra banks' words added
HyChkX:	movem.l	d0-d1/d3/a0,-(sp)
	bsr.w	HyXLen
	beq.s	.x
	lea	ERAMX,a0
	lsr.l	#1,d3
	subq.l	#1,d3			; words - 1 (up to 49151: one dbf word)
	moveq	#0,d1
.l:	move.w	(a0)+,d1
	add.l	d1,d2
	dbf	d3,.l
.x:	movem.l	(sp)+,d0-d1/d3/a0
	rts

; ---- Juan's ClearBatt and Insert: ERAMX cleared (whatever the cart). All registers kept.
HyClrX:	movem.l	d0/a0,-(sp)
	lea	ERAMX,a0
	move.w	#12*8192/16-1,d0
.l:	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)+
	dbf	d0,.l
	movem.l	(sp)+,d0/a0
	rts

; ---- menu.s HyBattIn, after ERAM0-3: a1 = memory_banks bank 4 -> ERAMX copied there
HySaveIn:
	movem.l	d0/d3/a0-a1,-(sp)
	bsr.w	HyXLen
	beq.s	.x
	lea	ERAMX,a0
	lsr.l	#4,d3
	subq.l	#1,d3
.l:	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	dbf	d3,.l
.x:	movem.l	(sp)+,d0/d3/a0-a1
	rts
; ---- menu.s HyBattOut, after ERAM0-3: a0 = memory_banks bank 4 -> ERAMX
HySaveOut:
	movem.l	d0/d3/a0-a1,-(sp)
	bsr.w	HyXLen
	beq.s	.x
	lea	ERAMX,a1
	lsr.l	#4,d3
	subq.l	#1,d3
.l:	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	dbf	d3,.l
.x:	movem.l	(sp)+,d0/d3/a0-a1
	rts

	SECTION	hysavebss,BSS
	cnop	0,4
ERAMX:	ds.b	12*8192			; cart RAM banks 4-15
	ENDC

	SECTION	hybrid,CODE

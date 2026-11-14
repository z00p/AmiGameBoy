; AmiGameBoy: Game Boy Color parts of the engine (HY_GBC builds only).
; Copyright (C) 2026 AmiGameBoy contributors. GPL-2 (see COPYING).
;
; CGB mode is taken when the cartridge header says so ($143 bit 7: $80 both models, $C0
; Colour only). Then:
; - VRAM bank 1 (VBK, $FF4F). gbc_vram keeps both banks; the flat $8000-$9FFF is always
;   bank 0 (a bank 0 write goes to both places and on to the old handler, a bank 1 write
;   only to gbc_vram). CPU byte reads of $8000-$9FFF go through gbc_vrd (z80_misc.s GBC_RD,
;   GBC_BTST): the selected bank, or $FF while the LCD draws a line (STAT mode 3). Not
;   hooked: POP/RET and code run from VRAM, OAM DMA from VRAM (bank 0), the idle skip's
;   polled byte. The renderer reads gbc_vram.
; - WRAM banks 1-7 (SVBK, $FF70): the flat $D000-$DFFF holds the selected bank, the others
;   live in gbc_wram (bank n at n*$1000); a switch stores the old bank, loads the new one and
;   refreshes the echo at $F000-$FDFF.
; - Palette RAM (BCPS/BCPD $FF68/69, OCPS/OCPD $FF6A/6B) with auto-increment; the flat bytes
;   at $FF68-$FF6B always hold what a read returns.
; - KEY1 ($FF4D) + STOP: double speed. The CPU gets twice the M-cycles a line (sweeps of
;   46,46,46,46,44), DIV and the timer count twice as fast. The switch stalls the CPU for
;   GBC_STALL lines (measured against Mesen 2, see docs/gbc-log.md) and leaves DIV at 0.
; - HDMA ($FF51-$FF55): general purpose (all at once, CPU charged 8 M-cycles a block, 16 in
;   double speed) and HBlank (a block at the start of each horizontal blank, lines 0-143,
;   LCD on; one block at once when started in a horizontal blank or with the LCD off).
; - The CGB hand-over state of Mesen 2's boot ROM (registers, I/O, palettes, LY 146).
;
; Entry points: gbc_install (after the write table is built), gbc_start (from run_cartridge
; after z80_start), gbc_hblank (each line at sweep 3), gbc_stop (STOP), gbc_dbl* (DIV/timer).

	IFND	GBC_STALL
GBC_STALL	=299			; lines the CPU stands still in a speed switch: Mesen 2 resumes
				; 136,020 T-cycles (298.3 lines) after the STOP (Infinity, 13 Nov 2026)
	ENDC

	SECTION	gbccode,CODE

; ---- gbc_install: a0 = gb_mem_jumps, cartridge = the ROM. All registers kept.
gbc_install:
	movem.l	d0-d1/a1,-(sp)
	clr.b	gbc_mode
	move.l	cartridge,a1
	IFND	GBC_FORCEDMG
	btst	#7,$143(a1)
	beq.w	.x
	ENDC
	st	gbc_mode
	move.l	a0,a1
	add.l	#$8000*4,a1
	move.l	(a1),gbc_orig8000	; whatever stores tiles and maps now (plain store or
	move.l	$1800*4(a1),gbc_orig9800 ; the hybrid's dirty mark): called after ours
	move.l	#gbc_wvram_t,d0
	move.w	#$1800-1,d1
.t:	move.l	d0,(a1)+
	dbra	d1,.t
	move.l	#gbc_wvram_m,d0
	move.w	#$800-1,d1
.m:	move.l	d0,(a1)+
	dbra	d1,.m
	move.l	a0,a1
	add.l	#$ff00*4,a1
	move.l	#gbc_w4d,$4d*4(a1)
	move.l	#gbc_w4f,$4f*4(a1)
	move.l	#gbc_w51,$51*4(a1)
	move.l	#gbc_w52,$52*4(a1)
	move.l	#gbc_w53,$53*4(a1)
	move.l	#gbc_w54,$54*4(a1)
	move.l	#gbc_w55,$55*4(a1)
	move.l	#gbc_w68,$68*4(a1)
	move.l	#gbc_w69,$69*4(a1)
	move.l	#gbc_w6a,$6a*4(a1)
	move.l	#gbc_w6b,$6b*4(a1)
	move.l	#gbc_w70,$70*4(a1)
	move.l	#gb_mem_wr,$72*4(a1)	; $FF72-$FF74: plain registers on the CGB
	move.l	#gb_mem_wr,$73*4(a1)
	move.l	#gb_mem_wr,$74*4(a1)
	move.l	#gbc_w75,$75*4(a1)
.x:	movem.l	(sp)+,d0-d1/a1
	rts

; ---- gbc_start: after z80_start (CPU registers in d0-d5), before push_z80.
gbc_start:
	tst.b	gbc_mode
	beq.s	.x
	bsr.w	gbc_reset
	move.l	#$ff56,d0		; DE
	moveq	#0,d1			; BC
	moveq	#$0d,d2			; HL
	moveq	#$11,d3			; A = $11 (a CGB), F: N = 0
	moveq	#%100,d4		; Z = 1, C = 0
	clr.b	h_the_flag		; H = 0
.x:	rts

; the state Mesen 2's CGB boot ROM hands over (checked 13 Nov 2026, the same for every
; Colour cartridge tried): VRAM bank 0 = the DMG logo tiles without the map, bank 1 and
; WRAM clear, BG palettes as gbc_bootpal, OBJ palettes 0, I/O as below, LY 146.
gbc_reset:
	movem.l	d0-d7/a0-a6,-(sp)
	lea	gbc_vram,a0
	move.w	#($4000+$8000)/4-1,d0	; gbc_vram and gbc_wram (adjacent)
.c:	clr.l	(a0)+
	dbra	d0,.c
	move.l	gb_memory,a1
	move.l	a1,a0
	add.l	#$9904,a0
	moveq	#$9930-$9904-1,d0	; no logo map in CGB mode
.cm:	clr.b	(a0)+
	dbra	d0,.cm
	move.l	a1,a0
	add.l	#$8000,a0
	lea	gbc_vram,a2
	move.w	#$2000/4-1,d0
.cv:	move.l	(a0)+,(a2)+
	dbra	d0,.cv
	lea	gbc_bootpal,a0
	lea	gbc_bgpal,a2
	moveq	#64/4-1,d0
.cp:	move.l	(a0)+,(a2)+
	dbra	d0,.cp
	moveq	#64/4-1,d0
.co:	clr.l	(a2)+
	dbra	d0,.co
	move.l	a1,a0
	add.l	#$ff00,a0
	move.b	#$f1,$0f(a0)		; IF: VBlank and joypad pending, as Mesen
	move.b	#$d4,$04(a0)		; DIV at the start of line 146
	IFND	NO_DIVRATE
	move.b	#$2b,div_frac
	ENDC
	lea	$30(a0),a2		; wave RAM
	moveq	#8-1,d0
.wv:	move.w	#$00ff,(a2)+
	dbra	d0,.wv
	lea	gbc_bootio,a2		; $FF4C-$FF7F, HRAM $FF80-$FFFE
	lea	$4c(a0),a3
	move.w	#$ff-$4c-1,d0
.io:	move.b	(a2)+,(a3)+
	dbra	d0,.io
	clr.b	gbc_vbk
	move.b	#1,gbc_svbk
	clr.b	gbc_double
	clr.b	gbc_prep
	clr.b	gbc_hact
	move.b	#$7f,gbc_hlen
	clr.w	gbc_hsrc
	clr.w	gbc_hdst
	clr.w	gbc_stall
	move.b	#$80,gbc_bcps		; reads $C0: index 0, auto-increment
	clr.b	gbc_ocps		; reads $40
	bsr.w	gbc_speed
	IFD	GBC_RENDER
	jsr	gbc_tdall		; VRAM set here: the row cache from scratch
	ENDC
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; ---- speed-dependent values from gbc_double ($00 or $80); keeps every register but d6.
gbc_speed:
	move.l	#22,z80_cycles
	move.l	#1,gbc_ext
	move.l	#8,gbc_blkcost
	tst.b	gbc_double
	beq.s	.k
	move.l	#44,z80_cycles		; 2 x 114 M-cycles a line: 46,46,46,46,44
	move.l	#2,gbc_ext
	move.l	#16,gbc_blkcost
.k:	move.l	a6,-(sp)
	move.l	gb_memory,a6
	add.l	#$ff00,a6
	move.b	gbc_double,d6		; KEY1 reads speed, 1111110, prepare
	or.b	gbc_prep,d6
	or.b	#$7e,d6
	move.b	d6,$4d(a6)
	move.l	(sp)+,a6
	rts

; ---- write handlers: d6.b = value, d7.l = address, a2 = memory; only d6/a6 free.

; tile data $8000-$97FF / maps $9800-$9FFF: bank 0 = its copy, then the old handler (the
; flat block); bank 1 = its copy only
	cnop	0,4
gbc_wvram_t:
	tst.b	gbc_vbk
	bne.s	.t1
	IFD	GBC_RENDER
	lea	gbc_tdirty-$8000,a6	; the renderer's row cache: decode this row again
	st	(a6,d7.l)
	ENDC
	lea	gbc_vram-$8000,a6
	move.b	d6,(a6,d7.l)
	move.l	gbc_orig8000,a6
	jmp	(a6)
.t1:
	IFD	GBC_RENDER
	lea	gbc_tdirty+$1800-$8000,a6
	st	(a6,d7.l)
	ENDC
	bra.s	gbc_wvram_1
	cnop	0,4
gbc_wvram_m:
	tst.b	gbc_vbk
	bne.s	gbc_wvram_1
	lea	gbc_vram-$8000,a6
	move.b	d6,(a6,d7.l)
	move.l	gbc_orig9800,a6
	jmp	(a6)
gbc_wvram_1:
	lea	gbc_vram+$2000-$8000,a6
	move.b	d6,(a6,d7.l)
	rts

; VBK: only the number (reads go through gbc_vrd)
	cnop	0,4
gbc_w4f:
	and.b	#1,d6
	IFD	GBC_COUNT
	cmp.b	gbc_vbk,d6
	beq.s	.same
	addq.l	#1,gbc_nvbk
.same:
	ENDC
	move.b	d6,gbc_vbk
	or.b	#$fe,d6
	move.b	d6,(a2,d7.l)
	rts

; ---- CPU byte reads of VRAM (GBC_RD / GBC_BTST in z80_misc.s). In: the address ($8000-$9FFF,
; upper word 0) in the register the entry names. Out: d6.b = the selected bank's byte, or $FF
; while the LCD draws (mode 3, LCD on). Mode 3 is line M-cycles 20-63 at its shortest (172
; dots); our sweeps are 0-23 (STAT 2), 23-46 and 46-69 (STAT 3, h_values), so with a5 = the
; M-cycles left in the sweep: locked in sweep 0 when a5 < GBC_M3S, all of sweep 1, sweep 2
; while a5 > GBC_M3E (twice these in double speed). STAT itself still says 3 for sweep 2.
; From the hardware alone GBC_M3S would be 3 and GBC_M3E 6; against Mesen 2 (Dawn Will Come's
; copy of VRAM into OBJ palette RAM across mode 3, 14 Nov 2026) our CPU sits about 4 M-cycles
; early in the line, so 0 and 2: Mesen gets $FF for 12 bytes, we for those and the one
; before (sweep 1 starts at M-cycle 23). DMG mode: the flat block as before. Keeps every other register; not the CCR.
	IFND	GBC_M3S
GBC_M3S	=0
	ENDC
	IFND	GBC_M3E
GBC_M3E	=2
	ENDC
	cnop	0,4
gbc_vrd_d0:
	move.l	d0,d6
	bra.s	gbc_vrd
gbc_vrd_d1:
	move.l	d1,d6
	bra.s	gbc_vrd
gbc_vrd_d7:
	move.l	d7,d6
	bra.s	gbc_vrd
gbc_vrd_d2:
	move.l	d2,d6
gbc_vrd:
	tst.b	gbc_mode
	beq.s	.flat
	movem.l	d5/a6,-(sp)
	move.l	a2,a6
	add.l	#$ff40,a6
	btst	#7,(a6)			; LCD off: free
	beq.s	.rd
	moveq	#3,d5
	and.b	1(a6),d5		; STAT mode
	cmp.b	#3,d5
	beq.s	.m3
	cmp.b	#2,d5
	bne.s	.rd
	moveq	#GBC_M3S,d5		; sweep 0: its last GBC_M3S
	mulu.w	gbc_ext+2,d5
	cmp.l	a5,d5
	bgt.s	.lock
	bra.s	.rd
.m3:	move.l	h_values_indexed,a6	; the next sweep's mode: 0 = this is sweep 2
	tst.b	(a6)
	bne.s	.lock
	moveq	#GBC_M3E,d5
	mulu.w	gbc_ext+2,d5
	cmp.l	a5,d5
	bge.s	.rd
.lock:	movem.l	(sp)+,d5/a6
	st	d6
	IFD	GBC_COUNT
	addq.l	#1,gbc_nvlock
	ENDC
	rts
.rd:	lea	gbc_vram-$8000,a6
	tst.b	gbc_vbk
	beq.s	.b0
	lea	$2000(a6),a6
.b0:	move.b	(a6,d6.l),d6
	movem.l	(sp)+,d5/a6
	rts
.flat:	move.b	(a2,d6.l),d6
	rts

; SVBK: bank 0 selects 1; reads $F8 + the bits written
	cnop	0,4
gbc_w70:
	move.b	d6,(a2,d7.l)
	or.b	#$f8,(a2,d7.l)
	and.w	#7,d6
	bne.s	.n0
	moveq	#1,d6
.n0:	cmp.b	gbc_svbk,d6
	beq.w	.x
	movem.l	d0/a0-a1,-(sp)
	moveq	#0,d0
	move.b	gbc_svbk,d0
	lsl.w	#8,d0
	lsl.w	#4,d0
	lea	gbc_wram,a0
	add.l	d0,a0
	move.l	a2,a1
	add.l	#$d000,a1
	move.w	#$1000/16-1,d0
.s:	move.l	(a1)+,(a0)+
	move.l	(a1)+,(a0)+
	move.l	(a1)+,(a0)+
	move.l	(a1)+,(a0)+
	dbra	d0,.s
	move.b	d6,gbc_svbk
	moveq	#0,d0
	move.b	d6,d0
	lsl.w	#8,d0
	lsl.w	#4,d0
	lea	gbc_wram,a0
	add.l	d0,a0
	move.l	a2,a1
	add.l	#$d000,a1
	move.w	#$1000/16-1,d0
.l:	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	dbra	d0,.l
	move.l	a2,a0			; echo $F000-$FDFF = $D000-$DDFF
	add.l	#$d000,a0
	move.l	a2,a1
	add.l	#$f000,a1
	move.w	#$e00/16-1,d0
.e:	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	dbra	d0,.e
	movem.l	(sp)+,d0/a0-a1
	IFD	GBC_COUNT
	addq.l	#1,gbc_nsvbk
	ENDC
.x:	rts

; KEY1: the prepare bit
	cnop	0,4
gbc_w4d:
	and.b	#1,d6
	move.b	d6,gbc_prep
	bra.w	gbc_speed

; $FF75: bits 4-6
	cnop	0,4
gbc_w75:
	or.b	#$8f,d6
	move.b	d6,(a2,d7.l)
	rts

; BCPS / OCPS: index (bit 7 auto-increment); the data register shows the byte
	cnop	0,4
gbc_w68:
	lea	gbc_bgpal,a6
	move.b	d6,gbc_bcps
	bra.s	gbc_wps
	cnop	0,4
gbc_w6a:
	lea	gbc_obpal,a6
	move.b	d6,gbc_ocps
gbc_wps:
	or.b	#$40,d6
	move.b	d6,(a2,d7.l)
	and.w	#$3f,d6
	move.b	(a6,d6.w),d6
	move.b	d6,1(a2,d7.l)
	rts

; BCPD / OCPD: store at the index, step it when auto-increment is on
	cnop	0,4
gbc_w69:
	move.l	d0,-(sp)
	lea	gbc_bgpal,a6
	moveq	#$3f,d0
	and.b	gbc_bcps,d0
	move.b	d6,(a6,d0.w)
	tst.b	gbc_bcps
	bpl.s	gbc_wpd
	addq.b	#1,d0
	and.b	#$3f,d0
	move.b	gbc_bcps,d6
	and.b	#$80,d6
	or.b	d0,d6
	move.b	d6,gbc_bcps
	or.b	#$40,d6
	move.b	d6,-1(a2,d7.l)
	bra.s	gbc_wpd
	cnop	0,4
gbc_w6b:
	move.l	d0,-(sp)
	lea	gbc_obpal,a6
	moveq	#$3f,d0
	and.b	gbc_ocps,d0
	move.b	d6,(a6,d0.w)
	tst.b	gbc_ocps
	bpl.s	gbc_wpd
	addq.b	#1,d0
	and.b	#$3f,d0
	move.b	gbc_ocps,d6
	and.b	#$80,d6
	or.b	d0,d6
	move.b	d6,gbc_ocps
	or.b	#$40,d6
	move.b	d6,-1(a2,d7.l)
gbc_wpd:	; the data register shows the byte at the (new) index
	move.b	(a6,d0.w),d6
	move.b	d6,(a2,d7.l)
	st	gbc_paldirty
	IFD	GBC_COUNT
	addq.l	#1,gbc_npal
	ENDC
	move.l	(sp)+,d0
	rts

; HDMA1-4: source (16-byte steps), destination (13 bits, 16-byte steps); they read $FF
	cnop	0,4
gbc_w51:
	move.b	d6,gbc_hsrc
	rts
	cnop	0,4
gbc_w52:
	and.b	#$f0,d6
	move.b	d6,gbc_hsrc+1
	rts
	cnop	0,4
gbc_w53:
	and.b	#$1f,d6
	move.b	d6,gbc_hdst
	rts
	cnop	0,4
gbc_w54:
	and.b	#$f0,d6
	move.b	d6,gbc_hdst+1
	rts

; HDMA5: bit 7 = 0 general purpose now (or stop a running HBlank DMA), 1 = HBlank DMA
	cnop	0,4
gbc_w55:
	tst.b	d6
	bmi.s	.hdma
	tst.b	gbc_hact
	beq.s	.gdma
	clr.b	gbc_hact		; stop: reads the blocks left, bit 7 set
	move.b	gbc_hlen,d6
	or.b	#$80,d6
	move.b	d6,(a2,d7.l)
	rts
.gdma:	and.b	#$7f,d6
	move.b	d6,gbc_hlen
	IFD	GBC_COUNT
	addq.l	#1,gbc_ngdma
	ENDC
	subq.l	#1,a5			; set-up
.g:	bsr.w	gbc_block
	sub.l	gbc_blkcost,a5
	tst.b	d6
	bne.s	.g
	rts
.hdma:	and.b	#$7f,d6
	move.b	d6,gbc_hlen
	move.b	d6,(a2,d7.l)		; blocks left - 1, bit 7 = 0: running
	st	gbc_hact
	IFD	GBC_COUNT
	addq.l	#1,gbc_nhdma
	ENDC
	move.l	a2,a6
	add.l	#$ff00,a6
	btst	#7,$40(a6)		; LCD off or in a horizontal blank: a block now
	beq.s	.now
	move.b	$41(a6),d6
	and.b	#3,d6
	bne.s	.x
.now:	bsr.w	gbc_block
	sub.l	gbc_blkcost,a5
.x:	rts

; one 16-byte block from the source to VRAM (through the write table, so both copies and
; any dirty marks follow). Out: d6.b = 0 when the transfer is over ($FF55 = $FF), else 1.
; Keeps every other register; a2 = memory, a3 = ROM image as in the CPU.
gbc_block:
	movem.l	d0-d2/d7/a0-a1/a6,-(sp)
	move.l	gb_mem_jumps,a1
	moveq	#0,d0
	move.w	gbc_hsrc,d0
	moveq	#0,d1
	move.w	gbc_hdst,d1
	moveq	#16-1,d2
.b:	cmp.w	#$8000,d0
	bcs.s	.rom
	cmp.w	#$a000,d0
	bcs.s	.ff			; VRAM as a source: $FF
	cmp.w	#$e000,d0
	bcc.s	.ff
	move.b	(a2,d0.l),d6
	bra.s	.w
.rom:	move.b	(a3,d0.l),d6
	bra.s	.w
.ff:	st	d6
.w:	move.l	d1,d7
	and.w	#$1fff,d7
	or.w	#$8000,d7
	move.l	(a1,d7.l*4),a6
	jsr	(a6)
	addq.w	#1,d0
	addq.w	#1,d1
	dbra	d2,.b
	move.w	d0,gbc_hsrc
	and.w	#$1ff0,d1
	move.w	d1,gbc_hdst
	move.l	a2,a0
	add.l	#$ff55,a0
	move.b	gbc_hlen,d0
	subq.b	#1,d0
	and.b	#$7f,d0
	move.b	d0,gbc_hlen
	cmp.b	#$7f,d0
	beq.s	.done
	tst.w	d1			; destination wrapped past $9FFF: over
	beq.s	.done
	move.b	d0,(a0)
	moveq	#1,d6
	movem.l	(sp)+,d0-d2/d7/a0-a1/a6
	rts
.done:	clr.b	gbc_hact
	st	(a0)
	moveq	#0,d6
	movem.l	(sp)+,d0-d2/d7/a0-a1/a6
	rts

; ---- each line at sweep 3 (horizontal blank of lines 0-143), a6 = $FF00. Keeps all.
gbc_hblank:
	tst.b	gbc_mode
	beq.s	.x
	IFD	GBC_RENDER
	cmp.l	#144,gb_scanlines	; GBC_RENDER: the line, as the registers are now
	bcc.s	.nr
	btst	#7,$40(a6)
	beq.s	.nr
	tst.b	gbc_lineoff		; this frame's picture will be skipped: no lines
	bne.s	.lo
	jsr	gbc_line
	IFD	GBC_LINE2		; test: twice (its cost = the time difference)
	jsr	gbc_line
	ENDC
	bra.s	.nr
.lo:	st	gbc_drawn		; (not an LCD-off frame)
.nr:
	ENDC
	tst.w	gbc_stall
	bne.s	.stall
.st:	tst.b	gbc_hact
	beq.s	.x
	cmp.l	#144,gb_scanlines
	bcc.s	.x
	btst	#7,$40(a6)
	beq.s	.x
	movem.l	d6/a6,-(sp)
	bsr.w	gbc_block
	move.l	gbc_blkcost,d6
	sub.l	d6,sweep_extra
	movem.l	(sp)+,d6/a6
.x:	rts
.stall:	subq.w	#1,gbc_stall		; speed switch: the CPU stands still
	bne.s	.st
	clr.b	z80_halt		; over: DIV starts from 0
	clr.b	$04(a6)
	IFND	NO_DIVRATE
	clr.b	div_frac
	ENDC
	bra.s	.st

; ---- STOP ($10 $00). With KEY1's prepare bit in CGB mode: the speed switch.
	cnop	0,4
gbc_stop:
	tst.b	gbc_mode
	beq.s	.dmg
	tst.b	gbc_prep
	beq.s	.dmg
	clr.b	gbc_prep
	eor.b	#$80,gbc_double
	bsr.w	gbc_speed
	subq.l	#1,a5
	addq.l	#1,a0			; the operand byte
	move.w	#GBC_STALL,gbc_stall
	move.b	#1,z80_halt
	IFD	GBC_COUNT
	addq.l	#1,gbc_nstop
	ENDC
	rts
.dmg:	move.b	#1,z80_halt		; as Wzonka
	rts

	SECTION	gbcdata,DATA
gbc_bootpal:	; BG palette RAM at the hand-over (Mesen 2's CGB boot ROM)
	dc.b	$ff,$ff,$ff,$7f,$00,$00,$ff,$7f,$ff,$ff,$b7,$7b,$00,$00,$4f,$77
	dc.b	$ff,$ff,$73,$53,$00,$00,$c7,$22,$ff,$ff,$df,$43,$00,$00,$9f,$03
	dc.b	$ff,$ff,$be,$42,$00,$00,$7d,$01,$ff,$ff,$1e,$52,$00,$00,$1d,$24
	dc.b	$ff,$ff,$9c,$76,$00,$00,$38,$6d,$ff,$ff,$90,$6a,$00,$00,$00,$55
gbc_bootio:	; $FF4C-$FF7F and HRAM $FF80-$FFFE at the hand-over
	dc.b	$ff,$7e,$ff,$fe
	dc.b	$ff,$ff,$ff,$ff,$ff,$ff,$3e,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	dc.b	$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$c0,$ff,$40,$00,$ff,$ff,$ff,$ff
	dc.b	$f8,$ff,$00,$00,$00,$8f,$0e,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	dc.b	$00,$ff,$ff,$ff,$7f,$00,$00,$ff,$7f,$ff,$ff,$b7,$7b,$00,$00,$4f
	dc.b	$77,$ff,$ff,$73,$53,$00,$00,$c7,$22,$ff,$ff,$df,$43,$00,$00,$9f
	dc.b	$03,$ff,$ff,$be,$42,$00,$00,$7d,$01,$ff,$ff,$1e,$52,$00,$00,$1d
	dc.b	$24,$ff,$ff,$9c,$76,$00,$00,$38,$6d,$ff,$ff,$90,$6a,$00,$00,$00
	dc.b	$55,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$d5,$05,$8c,$00,$94,$07,$9a,$06,$8a,$00,$00
	even
gbc_orig8000:	dc.l	0
gbc_orig9800:	dc.l	0
gbc_ext:	dc.l	1		; added to sweeps 0-3 (2 in double speed)
gbc_blkcost:	dc.l	8		; M-cycles for a 16-byte DMA block
gbc_hsrc:	dc.w	0
gbc_hdst:	dc.w	0
gbc_stall:	dc.w	0
gbc_mode:	dc.b	0		; $FF = CGB mode
gbc_vbk:	dc.b	0
gbc_svbk:	dc.b	1
gbc_double:	dc.b	0		; $80 in double speed
gbc_prep:	dc.b	0
gbc_hact:	dc.b	0		; HBlank DMA running
gbc_hlen:	dc.b	$7f
gbc_paldirty:	dc.b	0
gbc_vbl_late:	dc.b	0		; VBlank IF due at sweep 1 of line 144
gbc_bcps:	dc.b	0
gbc_ocps:	dc.b	0
	even
	IFD	GBC_COUNT
gbc_nvbk:	dc.l	0
gbc_nvlock:	dc.l	0		; VRAM reads that got $FF (mode 3)
gbc_nsvbk:	dc.l	0
gbc_npal:	dc.l	0
gbc_ngdma:	dc.l	0
gbc_nhdma:	dc.l	0
gbc_nstop:	dc.l	0
	ENDC

	SECTION	gbcbss,BSS
gbc_bgpal:	ds.b	64		; BG palette RAM
gbc_obpal:	ds.b	64		; OBJ palette RAM
gbc_vram:	ds.b	$4000		; VRAM banks 0 and 1 as they are
gbc_wram:	ds.b	$8000		; WRAM banks (1-7 used; the selected one is in the flat block)

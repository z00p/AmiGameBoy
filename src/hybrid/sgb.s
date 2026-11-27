; AmiGameBoy: Super Game Boy support (RTG program only; 2.3 candidate, docs/sgb-plan.md).
; Copyright (C) 2026 AmiGameBoy contributors. GPL-2 (see src/engine/COPYING).
;
; A cartridge whose header asks for the Super Game Boy ($146 = 3, $14B = $33) gets it when the
; option is Auto (the default; "Super Game Boy = Auto|Off" in AmiGameBoy.config, the Options
; menu tick). Taken at Power On; nothing of it exists for other carts or with Off. Reference:
; Pan Docs, "Super Game Boy" chapters (packets, palettes, attributes, VRAM transfers, borders).
;
; SGB_PKT  sgb_install hooks the P1 ($FF00) write: command packets (a reset pulse, then 16 bytes
;          a packet, LSB first, P14 low = 0, P15 low = 1, a 0 stop bit; up to 7 packets),
;          MLT_REQ with the joypad ID in P1's low bits while both lines are high (the next pad
;          when P15 goes low to high), C = $14 at the hand-over (a Super Game Boy), PAL01/23/03/12,
;          ATTR_BLK/LIN/DIV/CHR, ATTR_SET, PAL_SET, MASK_EN, ICON_EN (bit 2: no more packets),
;          PAL_TRN and ATTR_TRN (4 KB from the screen: the 256 tiles the BG map shows from its
;          top left, through BGP, at the end of the second frame after the command with the LCD
;          on). SOUND, SOU_TRN, DATA_SND, DATA_TRN, JUMP, OBJ_TRN, PAL_PRI, ATRC_EN, TEST_EN are
;          taken and ignored (no SNES sound or code).
; SGB_COL  mono carts: each 8x8 block of the screen through one of four palettes of four
;          colours (sgb_attr, 20 x 18), objects too; colour 0 is one colour for all (the
;          backdrop). Until the game sends colours the four palettes are the menu's shades.
;          MASK_EN: 1 freeze, 2 black, 3 colour 0. The LCD off freezes the picture (as the SGB
;          does) instead of the white of a Game Boy. Carts that run as Game Boy Color (.gbc,
;          header $80/$C0) get no Super Game Boy at all: a GBC answers no MLT_REQ, and a dual
;          cart told otherwise can hang (GB Corp: a white screen).
; SGB_BORD CHR_TRN (tiles $00-$7F / $80-$FF, 4bpp) and PCT_TRN (32 x 28 map, palettes 4-6): the
;          256 x 224 border, the game in the middle at its own scale, drawn into both buffers
;          when it arrives (in the bezel's place, cut to the screen) and at each screen open;
;          again when the backdrop colour changes. Colour 0 of the border is the backdrop.
; SGB_BFIT with a border, the picture at the scale at which the whole border fits the screen
;          (2x on 640x480 and 960x540) instead of the game's own (the border cut to the screen).
; SGB_OPT  the option (config line); SGB_MENU the Options menu tick (rmenu.s).
; SGB_DUMP (test) the state to GB:AmiGB.sgb at AutoExit (tools/sgb_check.py).
; HY_FIX251 (26 Nov 2026, after 2.5) VRAM transfers read each tile row with LCDC, SCX, SCY and
;          BGP as its top line was shown (sgb_hline from gbc_hblank), not as they are at LY 144:
;          Arcade Classic No. 1 has LCDC bit 4 off by LY 144 (an LYC interrupt at line 72), so
;          its second PAL_TRN (the title) was read from the $8800 tiles: black palettes, a black
;          screen from the title on (2.4 too).
; SGB_TLOG (test, with SGB_DUMP) the packets and transfer reads, and the VRAM at the last
;          PAL_TRN read, at the end of GB:AmiGB.sgb (26 Nov 2026).

	SECTION	sgbcode,CODE

; ---- Power On (after gbc_install): a0 = gb_mem_jumps, cartridge = the ROM. Keeps every register.
sgb_install:
	movem.l	d0-d1/a0-a1,-(sp)
	lea	sgb_dstart,a1
	move.w	#sgb_dend-sgb_dstart-1,d0
.c:	clr.b	(a1)+
	dbra	d0,.c
	lea	sgb_cnt,a1
	moveq	#32-1,d0
.cc:	clr.l	(a1)+
	dbra	d0,.cc
	lea	sgb_pal,a1		; a grey ramp until the game or the menu's shades set them
	moveq	#4-1,d0
.gp:	move.l	#$7fff5294,(a1)+
	move.l	#$294a0000,(a1)+
	dbra	d0,.gp
	move.b	#$30,sgb_p1		; the lines start high: the first reset pulse counts
	st	sgb_rdy
	tst.b	sgb_opt			; "Super Game Boy = Off": nothing
	beq.s	.x
	move.l	cartridge,a1
	cmp.b	#3,$146(a1)		; the header asks for it
	bne.s	.x
	cmp.b	#$33,$14b(a1)
	bne.s	.x
	tst.b	gbc_mode		; running as Game Boy Color: no Super Game Boy (a GBC never has
	bne.s	.x			; one; GB Corp, told it has, stays white, 23 Nov 2026)
	st	sgb_on
	IFD	SGB_COL
	st	sgb_col			; mono: the block palettes
	ENDC
	add.l	#$ff00*4,a0		; P1 writes come here first
	move.l	#sgb_w00,(a0)
	st	gbc_paldirty
.x:	movem.l	(sp)+,d0-d1/a0-a1
	rts

; ---- P1 write: d6.b = value, d7.l = address, a2 = memory; only d6/a6 free (write handler).
	cnop	0,4
sgb_w00:
	IFD	SGB_P1LOG		; test: every P1 write from frame SGB_P1LOG on, a ring
	jsr	sgb_p1lw
	ENDC
	movem.l	d0-d2/a0,-(sp)
	move.b	d6,d0
	move.b	sgb_p1,d1		; the last value written
	move.b	d0,sgb_p1
	tst.b	sgb_mlt			; more than one pad: P15 low -> high selects the next
	beq.s	.nomlt
	btst	#5,d1
	bne.s	.nomlt
	btst	#5,d0
	beq.s	.nomlt
	move.b	sgb_player,d2
	addq.b	#1,d2
	and.b	sgb_mlt,d2
	move.b	d2,sgb_player
.nomlt:	tst.b	sgb_dis			; ICON_EN bit 2: no more packets
	bne.w	.done
	lsr.b	#4,d0
	and.w	#3,d0
	beq.w	.reset			; P14 and P15 low: reset pulse
	cmp.b	#3,d0
	beq.w	.high			; both high: ready for the next pulse
	tst.b	sgb_rdy
	beq.w	.done
	tst.b	sgb_inpk
	beq.w	.done
	clr.b	sgb_rdy
	tst.b	sgb_stopw
	bne.s	.stop
	move.w	sgb_bitn,d1		; a data bit: 1 = P15 low (d0 = 1), 0 = P14 low (d0 = 2)
	cmp.b	#1,d0
	bne.s	.zero
	move.w	d1,d2
	lsr.w	#3,d2
	lea	sgb_buf,a0
	moveq	#7,d0
	and.w	d1,d0
	bset	d0,(a0,d2.w)
.zero:	addq.w	#1,d1
	move.w	d1,sgb_bitn
	and.w	#127,d1
	bne.s	.done
	st	sgb_stopw		; 128 bits in: the stop bit next
	bra.s	.done
.stop:	clr.b	sgb_stopw
	cmp.b	#2,d0			; the stop bit is a 0
	bne.s	.abort
	clr.b	sgb_inpk
	moveq	#7,d1			; packets in the command (header bits 0-2, 0 = 1)
	and.b	sgb_buf,d1
	IFD	SGB_LEN0		; 2.6: length 0 is not a command and is dropped (as SameBoy does: a
	beq.s	.abort			; "malformed" command); Castlevania Legends' sound driver writes $08 to P1 (a reset
	ELSE				; pulse), its pad reads then clock in 128 zero bits = a black PAL01
	bne.s	.len
	moveq	#1,d1
	ENDC
.len:	move.w	sgb_bitn,d2
	lsr.w	#7,d2
	cmp.w	d1,d2
	bcs.s	.done			; more packets to come
	bsr.w	sgb_cmd
.abort:	clr.b	sgb_inpk
	bsr.w	sgb_clrbuf
	bra.s	.done
.high:	st	sgb_rdy
	bra.s	.done
.reset:	tst.b	sgb_rdy
	beq.s	.done
	clr.b	sgb_rdy
	st	sgb_inpk
	move.w	sgb_bitn,d1		; between two packets of a command: go on with it
	beq.s	.done
	and.w	#127,d1
	bne.s	.new
	tst.b	sgb_stopw
	beq.s	.done
.new:	bsr.w	sgb_clrbuf		; else a new command
.done:	movem.l	(sp)+,d0-d2/a0
	jsr	do_joystick		; P1 as ever (z80_misc.s)
	tst.b	sgb_mlt
	beq.s	.x
	move.b	sgb_p1,d6
	and.b	#$30,d6
	cmp.b	#$30,d6
	bne.s	.pad
	move.b	sgb_player,d6		; both lines high: the pad's ID, $F player 1 .. $C player 4
	sub.b	d6,(a2,d7.l)
.x:	rts
.pad:	tst.b	sgb_player		; the other players' pads: nothing pressed
	beq.s	.x
	IFD	SGB_2P			; player 2: port 1's pad (sgb_pads), as do_joystick does player 1
	cmp.b	#1,sgb_player
	bne.s	.none
	moveq	#$0f,d6
	btst	#4,sgb_p1		; P14 low: the directions
	bne.s	.nd
	and.b	sgb_p2d,d6
.nd:	btst	#5,sgb_p1		; P15 low: the buttons
	bne.s	.nb
	and.b	sgb_p2b,d6
.nb:	and.b	#$f0,(a2,d7.l)
	or.b	d6,(a2,d7.l)
	rts
.none:
	ENDC
	or.b	#$0f,(a2,d7.l)
	rts

sgb_clrbuf:
	move.l	a0,-(sp)
	lea	sgb_buf,a0
	REPT	112/4
	clr.l	(a0)+
	ENDR
	clr.w	sgb_bitn
	clr.b	sgb_stopw
	move.l	(sp)+,a0
	rts

; ---- a whole command in sgb_buf. Keeps every register.
sgb_cmd:
	movem.l	d0-d7/a0-a4,-(sp)
	IFD	SGB_TLOG
	lea	sgb_buf,a0
	moveq	#0,d0
	jsr	sgb_tlogw
	ENDC
	moveq	#0,d1
	move.b	sgb_buf,d1
	lsr.b	#3,d1			; the command
	lea	sgb_cnt,a0
	addq.l	#1,(a0,d1.w*4)
	lea	sgb_buf,a0
	cmp.w	#3,d1
	bls.w	sgb_c_pal
	cmp.w	#4,d1
	beq.w	sgb_c_blk
	cmp.w	#5,d1
	beq.w	sgb_c_lin
	cmp.w	#6,d1
	beq.w	sgb_c_div
	cmp.w	#7,d1
	beq.w	sgb_c_chr
	cmp.w	#$0a,d1
	beq.w	sgb_c_pset
	cmp.w	#$0e,d1
	beq.s	sgb_cicon
	cmp.w	#$11,d1
	beq.s	sgb_cmlt
	cmp.w	#$16,d1
	beq.s	sgb_caset
	cmp.w	#$17,d1
	beq.s	sgb_cmask
	cmp.w	#$0b,d1			; PAL_TRN
	beq.s	sgb_ctrn
	cmp.w	#$15,d1			; ATTR_TRN
	beq.s	sgb_ctrn
	IFD	SGB_BORD
	cmp.w	#$13,d1			; CHR_TRN
	beq.s	sgb_ctrn
	cmp.w	#$14,d1			; PCT_TRN
	beq.s	sgb_ctrn
	ENDC
sgb_cmdx:
	movem.l	(sp)+,d0-d7/a0-a4
	rts
sgb_ctrn:	move.b	d1,sgb_trn		; from the screen, two frames on (sgb_frame)
	move.b	1(a0),sgb_trnarg
	move.b	#2,sgb_trnw
	bra.s	sgb_cmdx
sgb_cicon:	btst	#2,1(a0)
	beq.s	sgb_cmdx
	st	sgb_dis
	bra.s	sgb_cmdx
sgb_cmlt:	moveq	#3,d0			; 0 one pad, 1 two, 3 four (2: one)
	and.b	1(a0),d0
	cmp.b	#2,d0
	bne.s	.m1
	moveq	#0,d0
.m1:	move.b	d0,sgb_mlt
	and.b	d0,sgb_player
	bra.s	sgb_cmdx
sgb_caset:	moveq	#$3f,d0
	and.b	1(a0),d0
	bsr.w	sgb_atfset
	btst	#6,1(a0)
	beq.s	sgb_cmdx
	clr.b	sgb_mask
	bra.s	sgb_cmdx
sgb_cmask:	moveq	#3,d0
	and.b	1(a0),d0
	move.b	d0,sgb_mask
	bra.s	sgb_cmdx

; little-endian word at \1(a0) -> d0.w
SGB_RW	MACRO
	move.b	\1+1(a0),d0
	lsl.w	#8,d0
	move.b	\1(a0),d0
	and.w	#$7fff,d0
	ENDM

; PAL01, PAL23, PAL03, PAL12 (d1 = 0-3): colour 0 for all four, colours 1-3 of two palettes
sgb_c_pal:
	lea	.pairs(pc),a1
	moveq	#0,d2
	move.b	(a1,d1.w*2),d2
	moveq	#0,d3
	move.b	1(a1,d1.w*2),d3
	lea	sgb_pal,a1
	SGB_RW	1
	move.w	d0,(a1)
	move.w	d0,8(a1)
	move.w	d0,16(a1)
	move.w	d0,24(a1)
	lsl.w	#3,d2
	lea	2(a1,d2.w),a2
	SGB_RW	3
	move.w	d0,(a2)+
	SGB_RW	5
	move.w	d0,(a2)+
	SGB_RW	7
	move.w	d0,(a2)+
	lsl.w	#3,d3
	lea	2(a1,d3.w),a2
	SGB_RW	9
	move.w	d0,(a2)+
	SGB_RW	11
	move.w	d0,(a2)+
	SGB_RW	13
	move.w	d0,(a2)+
	bsr.w	sgb_newpal
	bra.w	sgb_cmdx
.pairs:	dc.b	0,1,2,3,0,3,1,2

; PAL_SET: four system palettes (PAL_TRN) by number, then maybe an ATF and the mask cancelled
sgb_c_pset:
	lea	sgb_pal,a1
	moveq	#1,d2			; offset of the first number
	moveq	#4-1,d3
.p:	move.b	1(a0,d2.w),d0
	lsl.w	#8,d0
	move.b	(a0,d2.w),d0
	and.w	#$1ff,d0
	lea	sgb_sys,a2
	lsl.w	#3,d0
	add.w	d0,a2
	moveq	#4-1,d4
.w:	move.b	1(a2),d0
	lsl.w	#8,d0
	move.b	(a2),d0
	and.w	#$7fff,d0
	move.w	d0,(a1)+
	addq.l	#2,a2
	dbra	d4,.w
	addq.w	#2,d2
	dbra	d3,.p
	lea	sgb_pal,a1		; colour 0: palette 0's, for all
	move.w	(a1),d0
	move.w	d0,8(a1)
	move.w	d0,16(a1)
	move.w	d0,24(a1)
	bsr.w	sgb_newpal
	move.b	9(a0),d1
	bpl.s	.na
	moveq	#$3f,d0
	and.b	d1,d0
	bsr.w	sgb_atfset
.na:	btst	#6,d1
	beq.w	sgb_cmdx
	clr.b	sgb_mask
	bra.w	sgb_cmdx

; ATTR_BLK: up to 18 rectangles, each with inside / surrounding line / outside palettes
sgb_c_blk:
	moveq	#0,d7
	move.b	1(a0),d7
	beq.w	sgb_cmdx
	cmp.w	#18,d7
	bls.s	.n
	moveq	#18,d7
.n:	addq.l	#2,a0
	subq.w	#1,d7
.set:	moveq	#7,d0
	and.b	(a0),d0			; d0 = which parts
	move.b	1(a0),d1
	moveq	#3,d4
	and.b	d1,d4			; inside
	move.b	d1,d5
	lsr.b	#2,d5
	and.b	#3,d5			; line
	move.b	d1,d6
	lsr.b	#4,d6
	and.b	#3,d6			; outside
	cmp.b	#1,d0			; only inside or only outside: the line goes with it
	bne.s	.o1
	moveq	#3,d0
	move.b	d4,d5
.o1:	cmp.b	#4,d0
	bne.s	.o2
	moveq	#6,d0
	move.b	d6,d5
.o2:	lea	sgb_attr,a1
	moveq	#0,d3			; y
.y:	moveq	#0,d2			; x
.x:	cmp.b	3(a0),d3
	bcs.s	.out
	cmp.b	5(a0),d3
	bhi.s	.out
	cmp.b	2(a0),d2
	bcs.s	.out
	cmp.b	4(a0),d2
	bhi.s	.out
	cmp.b	3(a0),d3		; inside the rectangle: its inside or its line
	bls.s	.line
	cmp.b	5(a0),d3
	bcc.s	.line
	cmp.b	2(a0),d2
	bls.s	.line
	cmp.b	4(a0),d2
	bcc.s	.line
	btst	#0,d0
	beq.s	.nx
	move.b	d4,(a1)
	bra.s	.nx
.line:	btst	#1,d0
	beq.s	.nx
	move.b	d5,(a1)
	bra.s	.nx
.out:	btst	#2,d0
	beq.s	.nx
	move.b	d6,(a1)
.nx:	addq.l	#1,a1
	addq.b	#1,d2
	cmp.b	#20,d2
	bne.s	.x
	addq.b	#1,d3
	cmp.b	#18,d3
	bne.s	.y
	addq.l	#6,a0
	dbra	d7,.set
	bra.w	sgb_cmdx

; ATTR_LIN: whole rows (bit 7 set) or columns, one byte each
sgb_c_lin:
	moveq	#0,d7
	move.b	1(a0),d7
	beq.w	sgb_cmdx
	cmp.w	#110,d7
	bls.s	.n
	moveq	#110,d7
.n:	addq.l	#2,a0
	subq.w	#1,d7
.l:	move.b	(a0)+,d0
	moveq	#31,d1
	and.b	d0,d1			; the line
	move.b	d0,d2
	lsr.b	#5,d2
	and.b	#3,d2			; its palette
	lea	sgb_attr,a1
	tst.b	d0
	bpl.s	.v
	cmp.w	#18,d1			; a row
	bcc.s	.nx
	mulu.w	#20,d1
	add.w	d1,a1
	moveq	#20-1,d3
.h:	move.b	d2,(a1)+
	dbra	d3,.h
	bra.s	.nx
.v:	cmp.w	#20,d1			; a column
	bcc.s	.nx
	add.w	d1,a1
	moveq	#18-1,d3
.vc:	move.b	d2,(a1)
	lea	20(a1),a1
	dbra	d3,.vc
.nx:	dbra	d7,.l
	bra.w	sgb_cmdx

; ATTR_DIV: two halves and the line between, across (bit 6 set: by Y) or down (by X)
sgb_c_div:
	move.b	1(a0),d0
	moveq	#3,d4
	and.b	d0,d4			; below / right
	move.b	d0,d5
	lsr.b	#2,d5
	and.b	#3,d5			; above / left
	move.b	d0,d6
	lsr.b	#4,d6
	and.b	#3,d6			; the line
	move.b	2(a0),d7		; where
	lea	sgb_attr,a1
	moveq	#0,d3			; y
.y:	moveq	#0,d2			; x
.x:	move.b	d2,d1
	btst	#6,d0
	beq.s	.byx
	move.b	d3,d1
.byx:	cmp.b	d7,d1
	bcs.s	.a
	beq.s	.l
	move.b	d4,(a1)+
	bra.s	.nx
.a:	move.b	d5,(a1)+
	bra.s	.nx
.l:	move.b	d6,(a1)+
.nx:	addq.b	#1,d2
	cmp.b	#20,d2
	bne.s	.x
	addq.b	#1,d3
	cmp.b	#18,d3
	bne.s	.y
	bra.w	sgb_cmdx

; ATTR_CHR: from (X, Y), n blocks of 2 bits (first in the top bits), left to right or top to bottom
sgb_c_chr:
	moveq	#0,d2
	move.b	1(a0),d2		; x
	moveq	#0,d3
	move.b	2(a0),d3		; y
	move.b	4(a0),d7
	lsl.w	#8,d7
	move.b	3(a0),d7		; n
	cmp.w	#360,d7
	bls.s	.n
	move.w	#360,d7
.n:	move.b	5(a0),d6		; style
	lea	6(a0),a2
	moveq	#0,d5			; bits left in d4
	bra.s	.go
.l:	cmp.w	#20,d2
	bcc.w	sgb_cmdx
	cmp.w	#18,d3
	bcc.w	sgb_cmdx
	tst.w	d5
	bne.s	.have
	move.b	(a2)+,d4
	moveq	#4,d5
.have:	rol.b	#2,d4
	moveq	#3,d0
	and.b	d4,d0
	subq.w	#1,d5
	move.w	d3,d1
	mulu.w	#20,d1
	add.w	d2,d1
	lea	sgb_attr,a1
	move.b	d0,(a1,d1.w)
	tst.b	d6
	bne.s	.tb
	addq.w	#1,d2			; left to right, then the next row
	cmp.w	#20,d2
	bne.s	.go
	moveq	#0,d2
	addq.w	#1,d3
	bra.s	.go
.tb:	addq.w	#1,d3			; top to bottom, then the next column
	cmp.w	#18,d3
	bne.s	.go
	moveq	#0,d3
	addq.w	#1,d2
.go:	dbra	d7,.l
	bra.w	sgb_cmdx

; ---- ATF d0.b (0-$2C) into sgb_attr: 90 bytes, 5 a row, 4 blocks a byte, the first in the top
; bits. Keeps every register.
sgb_atfset:
	cmp.b	#$2c,d0
	bhi.s	.x
	movem.l	d0-d3/a0-a1,-(sp)
	and.w	#$3f,d0
	mulu.w	#90,d0
	lea	sgb_atf,a0
	add.w	d0,a0
	lea	sgb_attr,a1
	move.w	#90-1,d2
.b:	move.b	(a0)+,d1
	moveq	#4-1,d3
.p:	rol.b	#2,d1
	moveq	#3,d0
	and.b	d1,d0
	move.b	d0,(a1)+
	dbra	d3,.p
	dbra	d2,.b
	movem.l	(sp)+,d0-d3/a0-a1
.x:	rts

; new colours: made again before the next line is drawn (gbc_dmgrgb -> sgb_mklut)
sgb_newpal:
	st	sgb_gotpal
	st	gbc_paldirty
	rts

; ---- each Game Boy frame (hybrid_frame, LY 144): a pending VRAM transfer, the border.
sgb_frame:
	IFD	SGB_SNAP		; test: the state every SGB_SNAP frames, kept for the exit
	jsr	sgb_snap
	ENDC
	tst.b	sgb_on
	beq.w	.x
	movem.l	d0-d7/a0-a6,-(sp)
	tst.b	sgb_trn
	beq.s	.bd
	move.l	gb_memory,a0
	add.l	#$ff40,a0
	tst.b	(a0)			; the LCD on: a frame the Super Game Boy sees
	bpl.s	.bd
	subq.b	#1,sgb_trnw
	bne.s	.bd
	bsr.w	sgb_vget
	move.b	sgb_trn,d0
	clr.b	sgb_trn
	lea	sgb_sys,a1
	cmp.b	#$0b,d0			; PAL_TRN: 512 system palettes
	beq.s	.cp
	lea	sgb_atf,a1
	cmp.b	#$15,d0			; ATTR_TRN: 45 attribute files
	beq.w	.cp			; (.w: .cp may be next)
	IFD	SGB_BORD
	lea	sgb_pct,a1
	cmp.b	#$14,d0			; PCT_TRN: map and palettes 4-6
	beq.s	.pct
	lea	sgb_chr,a1		; CHR_TRN: 128 tiles, the low or high half
	btst	#0,sgb_trnarg
	beq.s	.chr
	add.w	#$1000,a1
.chr:	bsr.s	.copy
	tst.b	sgb_bvalid		; a border up already: new tiles in it
	beq.s	.bd
	bsr.w	sgb_bmake
	bra.s	.bd
.pct:	bsr.s	.copy
	bsr.w	sgb_bmake
	bra.s	.bd
	ENDC
.cp:	bsr.s	.copy
.bd:
	IFD	SGB_BORD
	IFD	SGB_AGA			; AGA: into the planes (fixed pens: a new backdrop is only
	tst.b	sgb_bdirty		; colours, sgb_amklut)
	beq.s	.y
	tst.b	gbc_aga_onf
	beq.s	.y
	jsr	sgb_abdraw
	ELSE
	tst.b	sgb_bvalid
	beq.s	.y
	move.w	sgb_pal,d0		; the backdrop is the border's colour 0 too
	cmp.w	sgb_bc0,d0
	beq.s	.same
	st	sgb_bdirty
.same:	tst.b	sgb_bdirty
	beq.s	.y
	tst.b	gbc_rtg_on
	beq.s	.y
	IFD	SGB_BFIT
	bsr.w	sgb_bfit		; the whole border on the screen: maybe a smaller scale now
	ENDC
	bsr.w	sgb_bdraw
	ENDC
.y:
	ENDC
	movem.l	(sp)+,d0-d7/a0-a6
.x:	rts
.copy:	lea	sgb_tbuf,a0		; 4 KB sgb_tbuf -> a1
	move.w	#4096/16-1,d0
.c:	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	dbra	d0,.c
	rts

	IFD	HY_FIX251
; ---- sgb_vget: tile row d2's registers as the line at its top was shown since the command
; (sgb_trow, sgb_hline), else as they are now (a2 = $FF00): d7 LCDC, d6 BGP, d5 SCX and d4 SCY
; in tiles, a3 the BG map (a1 = memory). Keeps the rest.
sgb_vrreg:
	move.l	a2,a3
	move.w	sgb_trowm,d0
	btst	d2,d0
	beq.s	.now
	move.w	d2,d0
	lsl.w	#2,d0
	lea	sgb_trow,a3
	add.w	d0,a3
	move.b	(a3)+,d7		; LCDC
	moveq	#0,d5
	move.b	(a3)+,d5		; SCX
	moveq	#0,d4
	move.b	(a3)+,d4		; SCY
	move.b	(a3),d6			; BGP
	bra.s	.t
.now:	move.b	$40(a3),d7
	moveq	#0,d5
	move.b	$43(a3),d5
	moveq	#0,d4
	move.b	$42(a3),d4
	move.b	$47(a3),d6
.t:	lsr.w	#3,d5			; in tiles
	lsr.w	#3,d4
	tst.b	gbc_mode
	beq.s	.dmg
	move.b	#$e4,d6
.dmg:	move.l	a1,a3
	add.l	#$9800,a3
	btst	#3,d7
	beq.s	.m0
	add.w	#$400,a3
.m0:	rts
	ENDC

; ---- the 4 KB a VRAM transfer carries -> sgb_tbuf: the tiles the BG map shows on the screen,
; 20 a row from the top left (coarse SCX/SCY), as the Super Game Boy reads them from the
; picture: bit planes through BGP (none in CGB mode). Window and objects are not looked at.
; HY_FIX251: each tile row with LCDC, SCX, SCY and BGP as its top line was shown (sgb_hline).
sgb_vget:
	move.l	gb_memory,a1
	move.l	a1,a2
	add.l	#$ff00,a2
	move.b	$40(a2),d7		; LCDC
	move.b	$47(a2),d6		; BGP
	tst.b	gbc_mode
	beq.s	.dmg
	move.b	#$e4,d6
.dmg:	moveq	#0,d4
	move.b	$42(a2),d4
	lsr.w	#3,d4			; SCY in tiles
	moveq	#0,d5
	move.b	$43(a2),d5
	lsr.w	#3,d5			; SCX in tiles
	move.l	a1,a3
	add.l	#$9800,a3
	btst	#3,d7
	beq.s	.m0
	add.w	#$400,a3
.m0:	lea	sgb_tbuf,a0
	moveq	#0,d3			; tiles done
	moveq	#0,d2			; row
.row:
	IFD	HY_FIX251
	bsr.w	sgb_vrreg		; this tile row's registers, as it was shown
	ENDC
	move.w	d2,d0
	add.w	d4,d0
	and.w	#31,d0
	lsl.w	#5,d0
	lea	(a3,d0.w),a5		; the map row
	moveq	#0,d1			; column
.col:	move.w	d1,d0
	add.w	d5,d0
	and.w	#31,d0
	move.b	(a5,d0.w),d0		; tile number
	btst	#4,d7
	beq.s	.sg
	and.l	#$ff,d0			; $8000 + n * 16
	lsl.l	#4,d0
	add.l	#$8000,d0
	bra.s	.ta
.sg:	ext.w	d0			; $9000 + signed n * 16
	ext.l	d0
	lsl.l	#4,d0
	add.l	#$9000,d0
.ta:	lea	(a1,d0.l),a4
	cmp.b	#$e4,d6
	bne.s	.remap
	move.l	(a4)+,(a0)+
	move.l	(a4)+,(a0)+
	move.l	(a4)+,(a0)+
	move.l	(a4)+,(a0)+
	bra.s	.next
.remap:	bsr.s	sgb_bgprow
.next:	addq.w	#1,d3
	cmp.w	#256,d3
	beq.s	.done
	addq.w	#1,d1
	cmp.w	#20,d1
	bne.s	.col
	addq.w	#1,d2
	bra.s	.row
.done:
	IFD	SGB_TLOG
	jsr	sgb_tlogv
	ENDC
	IFD	HY_FIX251
	clr.w	sgb_trowm		; the next transfer's rows from its own frames
	ENDC
	rts

	IFD	HY_FIX251
; ---- each line the picture shows (gbc_hblank: LY 0-143, LCD on; a6 = $FF00) while a VRAM
; transfer waits (sgb_trn): at the top line of each tile row the transfer uses (LY 0, 8 .. 96)
; LCDC, SCX, SCY and BGP into sgb_trow. The Super Game Boy takes the transfer from the picture
; as it was shown; a game may change these further down (Arcade Classic No. 1: LCDC bit 4 off
; by LY 144, an LYC interrupt at line 72), so at LY 144 they need not be the ones the transfer
; was shown with (26 Nov 2026). Keeps every register.
sgb_hline:
	movem.l	d0-d1/a0,-(sp)
	move.l	gb_scanlines,d0
	cmp.l	#13*8,d0
	bcc.s	.x
	moveq	#7,d1
	and.w	d0,d1
	bne.s	.x
	lsr.w	#3,d0			; the tile row
	move.w	sgb_trowm,d1		; taken from the picture (sgb_vrreg)
	bset	d0,d1
	move.w	d1,sgb_trowm
	lsl.w	#2,d0
	lea	sgb_trow,a0
	add.w	d0,a0
	bsr.s	sgb_trowput
.x:	movem.l	(sp)+,d0-d1/a0
	rts
; a0 = a row of sgb_trow, a6 = $FF00: the registers now. a0 advanced.
sgb_trowput:
	move.b	$40(a6),(a0)+
	move.b	$43(a6),(a0)+
	move.b	$42(a6),(a0)+
	move.b	$47(a6),(a0)+
	rts
	ENDC

; one tile (16 bytes a4 -> a0, both advanced) through BGP (d6): colour c becomes shade
; BGP >> 2c; plane by plane, from masks of the pixels of each colour. Keeps the rest.
sgb_bgprow:
	movem.l	d0-d7/a6,-(sp)
	lea	sgb_shtab,a6		; the shade of each colour
	move.b	d6,d0
	moveq	#4-1,d1
.t:	moveq	#3,d2
	and.b	d0,d2
	move.b	d2,(a6)+
	lsr.b	#2,d0
	dbra	d1,.t
	lea	sgb_shtab,a6
	moveq	#8-1,d5
.r:	move.b	(a4)+,d0		; low plane
	move.b	(a4)+,d1		; high plane
	moveq	#0,d2			; new low
	moveq	#0,d3			; new high
	moveq	#4-1,d4			; colour 3..0
.c:	move.b	d0,d7
	btst	#0,d4
	bne.s	.l1
	not.b	d7
.l1:	move.b	d1,d6
	btst	#1,d4
	bne.s	.h1
	not.b	d6
.h1:	and.b	d6,d7			; the pixels of colour d4
	move.b	(a6,d4.w),d6		; its shade
	btst	#0,d6
	beq.s	.n0
	or.b	d7,d2
.n0:	btst	#1,d6
	beq.s	.n1
	or.b	d7,d3
.n1:	dbra	d4,.c
	move.b	d2,(a0)+
	move.b	d3,(a0)+
	dbra	d5,.r
	movem.l	(sp)+,d0-d7/a6
	rts

; ---- d0.w = a 15-bit colour (xbbbbbgggggrrrrr) -> d0.w in the screen's format (gbc_pixfmt),
; as it is (a television, no LCD correction). Keeps the rest.
sgb_rgbw:
	movem.l	d1-d3,-(sp)
	moveq	#$1f,d1
	and.w	d0,d1			; r
	move.w	d0,d2
	lsr.w	#5,d2
	and.w	#$1f,d2			; g
	lsr.w	#8,d0
	lsr.w	#2,d0
	and.w	#$1f,d0			; b
	btst	#2,gbc_pixfmt		; d1 = the top field, d0 = the bottom one
	beq.s	.rgb
	exg	d0,d1			; BGR: blue on top
.rgb:	btst	#1,gbc_pixfmt
	bne.s	.555
	move.w	d2,d3			; 5-6-5: green c << 1 | c >> 4
	add.w	d2,d2
	lsr.w	#4,d3
	or.w	d3,d2
	lsl.w	#5,d2
	moveq	#11,d3
	lsl.w	d3,d1
	bra.s	.or
.555:	lsl.w	#5,d2
	moveq	#10,d3
	lsl.w	d3,d1
.or:	or.w	d2,d0
	or.w	d1,d0
	btst	#0,gbc_pixfmt		; PC byte order
	beq.s	.x
	rol.w	#8,d0
.x:	movem.l	(sp)+,d1-d3
	rts

	IFD	SGB_COL
; ---- the four palettes through BGP, OBP0, OBP1 (gbc_dmgreg) -> sgb_lut: per palette 64 words
; indexed by the line byte (BG 0-3, OBJ 32-35 / 36-39), as gbc_rgb is. Called at the end of
; gbc_dmgrgb (a mono cart's palettes changed). Keeps every register.
sgb_mklut:
	tst.b	sgb_col
	beq.w	.x
	movem.l	d0-d7/a0-a3,-(sp)
	tst.b	sgb_gotpal
	bne.s	.have
	lea	GBPaleta,a0		; no colours from the game yet: the menu's four shades
	lea	sgb_pal,a1
	moveq	#4-1,d7
.g:	move.w	(a0)+,d0		; $0RGB, 4 bits a channel -> 5: c << 1 | c >> 3
	move.w	d0,d1
	lsr.w	#8,d1
	and.w	#15,d1
	move.w	d1,d3
	add.w	d1,d1
	lsr.w	#3,d3
	or.w	d3,d1			; r
	move.w	d0,d2
	lsr.w	#4,d2
	and.w	#15,d2
	move.w	d2,d3
	add.w	d2,d2
	lsr.w	#3,d3
	or.w	d3,d2			; g
	and.w	#15,d0
	move.w	d0,d3
	add.w	d0,d0
	lsr.w	#3,d3
	or.w	d3,d0			; b
	lsl.w	#5,d2
	or.w	d2,d1
	lsl.w	#8,d0
	lsl.w	#2,d0
	or.w	d0,d1
	move.w	d1,(a1)
	move.w	d1,8(a1)
	move.w	d1,16(a1)
	move.w	d1,24(a1)
	addq.l	#2,a1
	dbra	d7,.g
	IFD	SGB_AGA			; AGA: pens and copper colours (sgbaga.s)
.have:	jsr	sgb_amklut
	movem.l	(sp)+,d0-d7/a0-a3
	rts
	ELSE
.have:
	ENDC
	lea	sgb_pal,a0		; the 16 colours in the screen's format
	lea	sgb_sw,a1
	moveq	#16-1,d7
.s:	move.w	(a0)+,d0
	bsr.w	sgb_rgbw
	move.w	d0,(a1)+
	dbra	d7,.s
	move.w	sgb_sw,sgb_c0w
	lea	sgb_lut,a1
	lea	sgb_sw,a2
	moveq	#4-1,d6
.p:	move.l	a1,a3
	move.b	gbc_dmgreg,d3		; BG: 0-3
	bsr.s	.four
	lea	32*2(a1),a3
	move.b	gbc_dmgreg+1,d3		; OBJ: 32-35, 36-39
	bsr.s	.four
	move.b	gbc_dmgreg+2,d3
	bsr.s	.four
	lea	64*2(a1),a1
	addq.l	#8,a2
	dbra	d6,.p
	movem.l	(sp)+,d0-d7/a0-a3
.x:	rts
.four:	moveq	#4-1,d4			; colours 0-3 of the register in d3
.f:	moveq	#3,d5
	and.b	d3,d5
	move.w	(a2,d5.w*2),(a3)+
	lsr.b	#2,d3
	dbra	d4,.f
	rts

; ---- the line's bytes (a0, 160) -> screen words (a1) for gbc_line when sgb_on: the mask, the
; block palettes (mono) or gbc_rgb (colour carts). d0-d3/a0-a3 used.
sgb_conv:
	move.b	sgb_mask,d0
	bne.w	.mask
	tst.b	sgb_col
	beq.s	.plain
	move.l	gb_scanlines,d0
	lsr.w	#3,d0
	mulu.w	#20,d0
	lea	sgb_attr,a3
	add.l	d0,a3
	moveq	#20-1,d1
	moveq	#0,d0
.blk:	moveq	#0,d2
	move.b	(a3)+,d2
	lsl.w	#7,d2			; 64 words a palette
	lea	sgb_lut,a2
	add.w	d2,a2
	REPT	8
	move.b	(a0)+,d0
	move.w	(a2,d0.w*2),(a1)+
	ENDR
	dbra	d1,.blk
	rts
.plain:	lea	gbc_rgb,a2
	moveq	#160/8-1,d1
	moveq	#0,d0
.cv:	REPT	8
	move.b	(a0)+,d0
	move.w	(a2,d0.w*2),(a1)+
	ENDR
	dbra	d1,.cv
	rts
.mask:	cmp.b	#1,d0			; 1 freeze: the line stays as it was
	beq.s	.x
	moveq	#0,d2			; 2 black
	cmp.b	#3,d0
	bne.s	.fill
	move.w	sgb_c0w,d2		; 3 colour 0
.fill:	move.w	d2,d3
	swap	d2
	move.w	d3,d2
	moveq	#160/2-1,d1
.f:	move.l	d2,(a1)+
	dbra	d1,.f
.x:	rts
	ENDC

	IFD	SGB_BORD
SGB_ROWMAX	=2048			; widest screen row the border is drawn into
; ---- the border picture from sgb_chr and sgb_pct -> sgb_bpix (256 x 224 bytes: 0 = colour 0,
; the backdrop; else palette (4-6 as 0-2) * 16 + colour 1-15). Keeps every register.
sgb_bmake:
	movem.l	d0-d7/a0-a6,-(sp)
	lea	sgb_pct,a0		; the map: 32 x 28 little-endian words VH0P PP00 NNNN NNNN
	lea	sgb_bpix,a1
	sub.l	a5,a5			; map row
.my:	sub.l	a6,a6			; map column
.mx:	move.b	1(a0),d0
	lsl.w	#8,d0
	move.b	(a0),d0
	addq.l	#2,a0
	moveq	#0,d1
	move.b	d0,d1			; the tile
	lsl.w	#5,d1
	lea	sgb_chr,a2
	add.l	d1,a2
	move.w	d0,d2			; the palette, 4-6 -> 0-2 (others 0)
	lsr.w	#8,d2
	lsr.w	#2,d2
	and.w	#7,d2
	subq.w	#4,d2
	cmp.w	#2,d2
	bls.s	.pok
	moveq	#0,d2
.pok:	lsl.w	#4,d2
	move.l	a5,d1			; where the tile goes
	lsl.l	#8,d1
	lsl.l	#3,d1
	move.l	a6,d3
	lsl.l	#3,d3
	add.l	d3,d1
	lea	(a1,d1.l),a3
	moveq	#0,d5			; pixel row
.r:	move.w	d5,d1
	btst	#15,d0			; Y flip
	beq.s	.ny
	moveq	#7,d1
	sub.w	d5,d1
.ny:	add.w	d1,d1			; planes 0/1 at 2r, 2/3 at 16 + 2r
	move.b	1(a2,d1.w),d3
	lsl.w	#8,d3
	move.b	(a2,d1.w),d3		; d3 = plane 1 : plane 0
	move.b	17(a2,d1.w),d4
	lsl.w	#8,d4
	move.b	16(a2,d1.w),d4		; d4 = plane 3 : plane 2
	moveq	#7,d1			; the bit of the first pixel (X flip: bit 0)
	btst	#14,d0
	beq.s	.nf
	moveq	#0,d1
.nf:	moveq	#8-1,d7
.p:	moveq	#0,d6
	btst	d1,d3
	beq.s	.b1
	addq.b	#1,d6
.b1:	addq.w	#8,d1
	btst	d1,d3
	beq.s	.b2
	addq.b	#2,d6
.b2:	subq.w	#8,d1
	btst	d1,d4
	beq.s	.b3
	addq.b	#4,d6
.b3:	addq.w	#8,d1
	btst	d1,d4
	beq.s	.b4
	addq.b	#8,d6
.b4:	subq.w	#8,d1
	tst.b	d6
	beq.s	.c0
	add.b	d2,d6
.c0:	move.b	d6,(a3)+
	btst	#14,d0
	bne.s	.xf
	subq.w	#1,d1
	bra.s	.pn
.xf:	addq.w	#1,d1
.pn:	dbra	d7,.p
	lea	256-8(a3),a3
	addq.w	#1,d5
	cmp.w	#8,d5
	bne.w	.r
	addq.w	#1,a6
	cmpa.w	#32,a6
	bne.w	.mx
	addq.w	#1,a5
	cmpa.w	#28,a5
	bne.w	.my
	st	sgb_bvalid
	st	sgb_bdirty
	IFD	HY_CRASHLOG		; test: the crash log's steps (crashlog.s)
	HYSTEP	26,gbc_rscale
	ENDC
	movem.l	(sp)+,d0-d7/a0-a6
	rts

	IFD	SGB_BFIT
; ---- SGB_BFIT: with a border up, the picture at the largest scale at which the whole 256 x 224
; border fits the screen (the game in its middle), not the game's own; a Super Game Boy on a
; television shows all of it. gbc_rtg_open: d0.w = the game's scale -> d0.w = the scale to use.
; Keeps the rest.
sgb_bfitsc:
	tst.b	sgb_bvalid
	beq.s	.x
	move.l	d1,-(sp)
	move.w	d0,d1
	bsr.s	sgb_bscale
	cmp.w	d1,d0
	bls.s	.s
	move.w	d1,d0
.s:	move.l	(sp)+,d1
.x:	rts
; d0.w = the largest s <= GBC_RMAXS (at least 1) with 256s x 224s inside the mode. Keeps the rest.
sgb_bscale:
	move.l	d1,-(sp)
	moveq	#0,d0
	move.w	gbc_rw,d0
	divu.w	#256,d0
	moveq	#0,d1
	move.w	gbc_rh,d1
	divu.w	#224,d1
	cmp.w	d0,d1
	bcc.s	.a
	move.w	d1,d0
.a:	cmp.w	#GBC_RMAXS,d0
	bls.s	.b
	moveq	#GBC_RMAXS,d0
.b:	tst.w	d0
	bne.s	.c
	moveq	#1,d0
.c:	move.l	(sp)+,d1
	rts
; sgb_frame, a new border with the screen open: when the whole border needs a smaller scale than
; the picture has, the picture moves to it (origins of both buffers as gbc_rtg_open sets them,
; every line copied again); sgb_bdraw then covers the rest. OS frozen. Keeps every register.
sgb_bfit:
	movem.l	d0-d3,-(sp)
	bsr.s	sgb_bscale
	cmp.w	gbc_rscale,d0
	IFD	HY_CRASHLOG		; test: the crash log's steps (crashlog.s)
	bcc.w	.x
	move.w	d0,gbc_rscale
	HYSTEP	27,gbc_rscale
	ELSE
	bcc.s	.x
	move.w	d0,gbc_rscale
	ENDC
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
	move.l	d0,gbc_rorgs
	move.l	gbc_rbpr,d1
	mulu.w	gbc_rh,d1
	add.l	d1,d0
	move.l	d0,gbc_rorgs+4
	st	gbc_rfull
	st	gbc_rfull+1
	IFD	GBC_BLEND
	st	gbc_bfirst
	ENDC
.x:	movem.l	(sp)+,d0-d3
	rts
	ENDC

	IFND	SGB_AGA			; (AGA: sgb_abdraw, sgbaga.s)
; ---- the border onto the RTG screen, both buffers: every pixel but the picture's, at the
; picture's scale around it (the game at border pixel 48, 40), black where the border is not,
; cut to the screen. OS alive (gbc_rtg_open) or frozen (sgb_frame). Keeps every register.
sgb_bdraw:
	movem.l	d0-d7/a0-a6,-(sp)
	clr.b	sgb_bdirty
	move.w	sgb_pal,d0		; colour 0: the backdrop
	move.w	d0,sgb_bc0
	bsr.w	sgb_rgbw
	lea	sgb_bcolw,a1
	move.w	d0,(a1)+
	lea	sgb_pct+$800,a0		; palettes 4-6, little-endian
	moveq	#1,d6
.c:	move.b	1(a0,d6.w*2),d0
	lsl.w	#8,d0
	move.b	(a0,d6.w*2),d0
	and.w	#$7fff,d0
	bsr.w	sgb_rgbw
	move.w	d0,(a1)+
	addq.w	#1,d6
	cmp.w	#48,d6
	bne.s	.c
	move.w	gbc_rscale,d5		; s
	move.w	d5,d0
	mulu.w	#160,d0
	move.w	d0,sgb_gpw
	move.w	gbc_rw,d1
	sub.w	d0,d1
	asr.w	#1,d1
	move.w	d1,sgb_gl		; the picture's left
	move.w	d5,d0
	mulu.w	#48,d0
	sub.w	d0,d1
	move.w	d1,sgb_gox		; the border's
	move.w	d5,d0
	mulu.w	#144,d0
	move.w	d0,sgb_gph
	move.w	gbc_rh,d1
	sub.w	d0,d1
	asr.w	#1,d1
	move.w	d1,sgb_gt		; the picture's top
	move.w	d5,d0
	mulu.w	#40,d0
	sub.w	d0,d1
	move.w	d1,sgb_goy		; the border's
	move.w	gbc_rw,d0
	cmp.w	#SGB_ROWMAX,d0
	bls.s	.wok
	move.w	#SGB_ROWMAX,d0
.wok:	move.w	d0,sgb_gw
	move.l	gbc_rmem,a6		; buffer 0
	bsr.s	.buf
	tst.b	gbc_rdbuf
	beq.s	.done
	move.l	gbc_rbpr,d0		; buffer 1: the lower half
	mulu.w	gbc_rh,d0
	add.l	d0,a6
	bsr.s	.buf
.done:	movem.l	(sp)+,d0-d7/a0-a6
	rts
; one buffer at a6; d5 = s
.buf:	moveq	#0,d7			; screen row
	moveq	#-1,d6			; the border row sgb_brow holds (-2: black)
	move.l	a6,a4
.y:	move.w	d7,d0
	sub.w	sgb_goy,d0
	bmi.s	.blk
	ext.l	d0
	divu.w	d5,d0
	cmp.w	#224,d0
	bcc.s	.blk
	cmp.w	d6,d0
	beq.s	.put
	move.w	d0,d6
	bsr.w	.mkrow
	bra.s	.put
.blk:	cmp.w	#-2,d6
	beq.s	.put
	moveq	#-2,d6
	lea	sgb_brow,a0
	move.w	sgb_gw,d0
	subq.w	#1,d0
.bz:	clr.w	(a0)+
	dbra	d0,.bz
.put:	lea	sgb_brow,a0
	move.l	a4,a1
	move.w	d7,d0			; a picture row: the picture's part left alone
	sub.w	sgb_gt,d0
	bmi.s	.whole
	cmp.w	sgb_gph,d0
	bcc.s	.whole
	move.w	sgb_gl,d0
	bsr.s	.cpy
	move.w	sgb_gpw,d0
	add.w	d0,a0
	add.w	d0,a0
	add.w	d0,a1
	add.w	d0,a1
	move.w	sgb_gw,d0
	sub.w	sgb_gl,d0
	sub.w	sgb_gpw,d0
	bsr.s	.cpy
	bra.s	.ny
.whole:	move.w	sgb_gw,d0
	bsr.s	.cpy
.ny:	add.l	gbc_rbpr,a4
	addq.w	#1,d7
	cmp.w	gbc_rh,d7
	bne.w	.y
	rts
.cpy:	subq.w	#1,d0			; d0 words a0 -> a1
	bmi.s	.cx
.cl:	move.w	(a0)+,(a1)+
	dbra	d0,.cl
.cx:	rts
; border row d6 -> sgb_brow (screen width, s pixels each, black outside)
.mkrow:	lea	sgb_brow,a0
	move.w	sgb_gw,d0
	subq.w	#1,d0
.mz:	clr.w	(a0)+
	dbra	d0,.mz
	lea	sgb_brow,a0
	lea	sgb_bpix,a2
	moveq	#0,d0
	move.w	d6,d0
	lsl.l	#8,d0
	add.l	d0,a2
	lea	sgb_bcolw,a3
	move.w	sgb_gox,d1		; x
	move.w	#256-1,d2
.mb:	moveq	#0,d0
	move.b	(a2)+,d0
	move.w	(a3,d0.w*2),d0
	move.w	d5,d3
	subq.w	#1,d3
.mk:	tst.w	d1
	bmi.s	.mn
	cmp.w	sgb_gw,d1
	bge.s	.mn
	move.w	d0,(a0,d1.w*2)
.mn:	addq.w	#1,d1
	dbra	d3,.mk
	dbra	d2,.mb
	rts

; ---- gbc_rtg_open: the border if there is one, in the bezel's place. NE: drawn (no bezel).
; Keeps every register.
sgb_bopen:
	tst.b	sgb_bvalid
	beq.s	.x
	bsr.w	sgb_bdraw
	tst.b	sgb_bvalid
.x:	rts
	ENDC
	ENDC

	IFD	SGB_DUMP
; ---- test: GB:AmiGB.sgb at AutoExit: "SGB1", on, col, mask, mlt, player, bvalid, gotpal, then the
; cart's $C000-$C010 (17 bytes), palettes (32), attributes (360), command counts (32 longs),
; with SGB_BORD the border pixels (57344) and palettes 4-6 (96). tools/sgb_check.py.
sgb_dump:
	movem.l	d0-d7/a0-a6,-(sp)
	bsr.s	sgb_dfill
	bra.s	sgb_dwr
; the header block: flags and the cart's $C000-$C010
sgb_dfill:
	movem.l	d0/a0-a1,-(sp)
	lea	sgb_dhead+4,a0
	move.b	sgb_on,(a0)+
	move.b	sgb_col,(a0)+
	move.b	sgb_mask,(a0)+
	move.b	sgb_mlt,(a0)+
	move.b	sgb_player,(a0)+
	move.b	sgb_bvalid,(a0)+
	move.b	sgb_gotpal,(a0)+
	move.l	gb_memory,a1
	add.l	#$c000,a1
	moveq	#17-1,d0
.m:	move.b	(a1)+,(a0)+
	dbra	d0,.m
	movem.l	(sp)+,d0/a0-a1
	rts
sgb_dwr:
	IFD	SGB_SNAP
	move.l	sgb_snapn,d0
	move.l	d0,sgb_snhead+4
	mulu.l	#SGB_SNAPSZ,d0
	move.l	d0,.list+12
	ENDC
	move.l	HyDosBase,a6
	move.l	#sgb_dname,d1
	move.l	#MODE_NEWFILE,d2
	jsr	dosOpen(a6)
	move.l	d0,d4
	beq.s	.x
	lea	.list(pc),a2
.w:	move.l	(a2)+,d2
	beq.s	.c
	move.l	(a2)+,d3
	move.l	d4,d1
	jsr	dosWrite(a6)
	bra.s	.w
.c:	move.l	d4,d1
	jsr	dosClose(a6)
.x:	movem.l	(sp)+,d0-d7/a0-a6
	rts
.list:
	IFD	SGB_SNAP
	dc.l	sgb_snhead,8,sgb_snaps,0
	ELSE
	dc.l	sgb_dhead,28,sgb_pal,32,sgb_attr,360,sgb_cnt,128
	IFD	SGB_BORD
	dc.l	sgb_bpix,256*224,sgb_pct+$800,96
	ENDC
	IFD	SGB_TLOG
	dc.l	sgb_tlogn,4+16*SGB_TLOGN,sgb_tlvram,$2000+256+4096
	ENDC
	IFD	SGB_P1LOG
	dc.l	sgb_p1n,4+16*2048
	ENDC
	ENDC
	dc.l	0
	ENDC

	IFD	SGB_P1LOG
; ---- test (27 Nov, Castlevania Legends): P1 writes, 16 bytes each in a ring of 2048 (sgb_p1n
; counts all): HyFrames, the value, sgb_inpk, sgb_rdy, sgb_stopw, a0 - a2 (the Game Boy code
; pointer against memory), d7 (the address). d6/a6 only (write handler).
	SECTION	sgbp1code,CODE
sgb_p1lw:
	cmp.l	#SGB_P1LOG,HyFrames
	bcs.s	.x
	movem.l	d0/a1,-(sp)
	move.l	sgb_p1n,d0
	addq.l	#1,sgb_p1n
	and.l	#2047,d0
	lsl.l	#4,d0
	lea	sgb_p1buf,a1
	add.l	d0,a1
	move.l	HyFrames,(a1)+
	move.b	d6,(a1)+
	move.b	sgb_inpk,(a1)+
	move.b	sgb_rdy,(a1)+
	move.b	sgb_stopw,(a1)+
	move.w	d4,(a1)+		; the Game Boy's HL and BC
	move.w	d5,(a1)+
	move.l	d7,(a1)+		; the address written
	movem.l	(sp)+,d0/a1
.x:	rts
	SECTION	sgbp1bss,BSS
sgb_p1n:	ds.l	1
sgb_p1buf:	ds.b	16*2048
	ENDC

	IFD	SGB_TLOG
; ---- test (26 Nov, Arcade Classic No. 1): a log of the packets and the VRAM transfers, 16 bytes
; each, SGB_TLOGN at most, written by sgb_dump: packets: HyFrames, sgb_dis, 11 bytes of the
; command; transfers: HyFrames | $80000000, the command, LCDC, BGP, SCX, SCY, LY, the sum of
; the 4 KB (long), its first 2 bytes. Keeps every register.
SGB_TLOGN	=256
	SECTION	sgbtlcode,CODE
sgb_tlogw:				; a0 = the command
	movem.l	d0/a0-a1,-(sp)
	bsr.s	sgb_tlslot
	beq.s	.x
	move.l	HyFrames,(a1)+
	move.b	sgb_dis,(a1)+
	moveq	#11-1,d0
.c:	move.b	(a0)+,(a1)+
	dbra	d0,.c
.x:	movem.l	(sp)+,d0/a0-a1
	rts
sgb_tlslot:
	move.l	sgb_tlogn,d0
	cmp.l	#SGB_TLOGN,d0
	bcc.s	.tno
	addq.l	#1,sgb_tlogn
	lsl.l	#4,d0
	lea	sgb_tlog,a1
	add.l	d0,a1
	moveq	#1,d0
	rts
.tno:	moveq	#0,d0
	rts
sgb_tlogv:
	movem.l	d0-d1/a0-a2,-(sp)
	bsr.s	sgb_tlslot
	beq.w	.x
	move.l	HyFrames,d0
	bset	#31,d0
	move.l	d0,(a1)+
	move.b	sgb_trn,(a1)+
	move.l	gb_memory,a2
	add.l	#$ff00,a2
	move.b	$40(a2),(a1)+
	move.b	$47(a2),(a1)+
	move.b	$43(a2),(a1)+
	move.b	$42(a2),(a1)+
	move.b	$44(a2),(a1)+
	lea	sgb_tbuf,a0
	moveq	#0,d0
	moveq	#0,d1
	move.w	#4096-1,d1
.s:	add.b	(a0)+,d0
	rol.l	#1,d0
	dbra	d1,.s
	move.l	d0,(a1)+
	move.b	sgb_tbuf,(a1)+
	move.b	sgb_tbuf+1,(a1)+
	cmp.b	#$0b,sgb_trn		; PAL_TRN: VRAM, the registers and the 4 KB kept (the last)
	bne.s	.x
	move.l	gb_memory,a0
	add.l	#$8000,a0
	lea	sgb_tlvram,a1
	move.w	#$2000/4-1,d1
.v:	move.l	(a0)+,(a1)+
	dbra	d1,.v
	move.l	gb_memory,a0
	add.l	#$ff00,a0
	moveq	#256/4-1,d1
.r:	move.l	(a0)+,(a1)+
	dbra	d1,.r
	lea	sgb_tbuf,a0
	move.w	#4096/4-1,d1
.t:	move.l	(a0)+,(a1)+
	dbra	d1,.t
.x:	movem.l	(sp)+,d0-d1/a0-a2
	rts
	SECTION	sgbtlbss,BSS
sgb_tlogn:	ds.l	1
sgb_tlog:	ds.b	16*SGB_TLOGN
sgb_tlvram:	ds.b	$2000+256+4096
	ENDC

	IFD	SGB_SNAP
	IFND	SGB_SNAPMAX
SGB_SNAPMAX	=24
	ENDC
SGB_SNAPSZ	=4+28+32+360+128+256*224+96+4+160*144*2
; ---- test: every SGB_SNAP Game Boy frames (up to SGB_SNAPMAX) the frame number, the dump block,
; the border, gbc_pixfmt and the picture (gbc_fb) into memory; sgb_dump writes them all at the
; exit to GB:AmiGB.sgb ("SGBS", count, the snapshots). Needs SGB_BORD and SGB_DUMP. Keeps every
; register.
	SECTION	sgbscode,CODE
sgb_snap:
	movem.l	d0-d1/a0-a1,-(sp)
	move.l	HyFrames,d0
	bmi.w	.x			; (-1 in the menu)
	sub.l	sgb_snapl,d0
	cmp.l	#SGB_SNAP,d0
	bcs.w	.x
	move.l	sgb_snapn,d0
	cmp.l	#SGB_SNAPMAX,d0
	bcc.w	.x
	move.l	HyFrames,sgb_snapl
	addq.l	#1,sgb_snapn
	mulu.l	#SGB_SNAPSZ,d0
	lea	sgb_snaps,a1
	add.l	d0,a1
	move.l	HyFrames,(a1)+
	jsr	sgb_dfill
	lea	sgb_dhead,a0
	moveq	#28-1,d0
.h:	move.b	(a0)+,(a1)+
	dbra	d0,.h
	lea	sgb_pal,a0
	moveq	#32-1,d0
.p:	move.b	(a0)+,(a1)+
	dbra	d0,.p
	lea	sgb_attr,a0
	move.w	#360-1,d0
.a:	move.b	(a0)+,(a1)+
	dbra	d0,.a
	lea	sgb_cnt,a0
	moveq	#32-1,d0
.n:	move.l	(a0)+,(a1)+
	dbra	d0,.n
	lea	sgb_bpix,a0
	move.w	#256*224/4-1,d0
.b:	move.l	(a0)+,(a1)+
	dbra	d0,.b
	lea	sgb_pct+$800,a0
	moveq	#96-1,d0
.c:	move.b	(a0)+,(a1)+
	dbra	d0,.c
	IFD	SGB_AGA			; AGA: the pens' picture as 5-5-5 words (sgbaga.s)
	jsr	sgb_afb
	moveq	#2,d0
	ELSE
	moveq	#0,d0
	move.b	gbc_pixfmt,d0
	ENDC
	move.l	d0,(a1)+
	lea	gbc_fb,a0
	move.w	#160*144/2-1,d0
.f:	move.l	(a0)+,(a1)+
	dbra	d0,.f
.x:	movem.l	(sp)+,d0-d1/a0-a1
	rts
	SECTION	sgbsbss,BSS
sgb_snapl:	ds.l	1
sgb_snapn:	ds.l	1
sgb_snaps:	ds.b	SGB_SNAPSZ*SGB_SNAPMAX
	ENDC

	IFD	SGB_2P
; ---- the pads, each Game Boy frame (hybrid_frame, in place of HyPads). One player: HyPads as
; ever (then ReadCD32Pads reads port 2). Once the game has asked for more (MLT_REQ), port 1
; (the mouse port) is player 2: both ports' CD32 reads come first, port 2 then port 1 straight
; after, before any plain read of either port (emu-dev-docs ch05: a plain read of the other port
; just before a CD32 read can leave a pad in its joystick mode); ReadCD32Pads then takes port 2's
; answer from here (one read a frame). Player 1's plain read is then port 2's lines only (Juan's
; LeeJoyStick also takes port 1's two buttons as Select and Start), player 2's is port 1's:
; directions (JOY0DAT), fire = A, pin 9 = B, the CD32 buttons through the same table as
; player 1 (HyPadApply, "Red = A" etc.). Port 1's clock: "Pad 2 = CD32 pad | KTRL CD32+" in
; AmiGameBoy.config (sgb_padcfg; default CD32 pad). Keeps every register.
	SECTION	sgbpcode,CODE
sgb_pads:
	tst.b	sgb_mlt
	bne.s	.two
	jmp	HyPads
.two:	movem.l	d0-d2/a0/a3,-(sp)
	moveq	#2,d0			; port 2 (player 1) first, as ever
	move.b	HyCD32Low,d1
	and.b	d0,d1
	jsr	cd32read
	move.w	d0,sgb_cd2
	moveq	#1,d0			; port 1 (player 2) straight after
	move.b	HyCD32Low,d1
	and.b	d0,d1
	jsr	cd32read
	IFD	SGB_P2STAT		; test: port 1's nine bits ORed, reads, reads with a CD32 pad's ID,
	or.l	d1,sgb_p2st		; HyCD32Low (AmiGB.result " p2=")
	addq.l	#1,sgb_p2st+4
	move.w	d1,d2
	and.w	#$180,d2
	cmp.w	#$100,d2
	bne.s	.noid
	addq.l	#1,sgb_p2st+8
.noid:	move.b	HyCD32Low,sgb_p2st+15	; and the clocks (bit 0: port 1 low)
	ENDC
	IFD	SGB_P2FAKE		; test: these port 1 buttons for 6 frames in every 100, from frame 50
	move.l	HyFrames,d2
	divu.w	#100,d2
	swap	d2
	sub.w	#50,d2
	cmp.w	#6,d2
	bcc.s	.nofk
	or.w	#SGB_P2FAKE,d1
.nofk:
	ENDC
	move.w	d1,sgb_cd1
	st	sgb_cdpre		; ReadCD32Pads: port 2's answer from sgb_cd2 this frame
	move.l	JoyControlRut,-(sp)	; player 1's plain read: port 2's lines only
	move.l	#sgb_joy1,JoyControlRut
	jsr	HyPads
	move.l	(sp)+,JoyControlRut
	lea	sgb_r2,a3		; player 2: a Regs stand-in (EstadoJoy, EstadoKeys = none)
	move.w	$dff00a,d0		; port 1's directions (JOY0DAT)
	jsr	LEEJOY
	not.b	d2
	move.b	d2,EstadoJoy+2(a3)
	moveq	#-1,d1
	btst	#6,$bfe001		; port 1's fire (pin 6): A
	bne.s	.f1
	bclr	#0,d1
.f1:	btst	#2,$dff016		; port 1's pin 9 (POTGO is $FF00 after the reads): B
	bne.s	.f2
	bclr	#1,d1
.f2:	move.b	d1,EstadoJoy+1(a3)
	moveq	#0,d0
	move.w	sgb_cd1,d0
	bsr.s	sgb_cdok
	jsr	HyPadApply		; the CD32 buttons through the table, over the plain read
	move.b	EstadoJoy+1(a3),sgb_p2b
	move.b	EstadoJoy+2(a3),sgb_p2d
	movem.l	(sp)+,d0-d2/a0/a3
	rts

; d0.l = a port's nine bits from cd32read -> its seven buttons, 0 for no pad (as HyCD32Kit)
sgb_cdok:
	IFD	HY_JOYPAD2		; "Standard Joypad": only a read with a CD32 pad's ID counts
	IFD	HY_MENU
	cmp.b	#3,DirPrefs+$08
	bne.s	.any
	move.w	d0,d1
	and.w	#$180,d1
	cmp.w	#$100,d1
	beq.s	.any
	moveq	#0,d0
.any:
	ENDC
	ENDC
	and.l	#$7f,d0
	cmp.b	#$7f,d0			; all seven: a plain joystick
	bne.s	.ok
	moveq	#0,d0
.ok:	rts

; player 1's plain read with two players: LeeJoyStick without port 1's lines (d0-d2 used)
sgb_joy1:
	lea	Regs,a3
	move.w	$dff00c,d0		; port 2: JOY1DAT
	jsr	LEEJOY
	not.b	d2
	move.b	d2,EstadoJoy+2(a3)
	moveq	#0,d1
	btst	#7,$bfe001		; port 2's fire: A
	bne.s	.a
	bset	#0,d1
.a:	move.w	#$ff00,$dff034
	nop
	nop
	btst	#6,$dff016		; port 2's pin 9: B
	bne.s	.b
	bset	#1,d1
.b:	not.b	d1
	move.b	d1,EstadoJoy+1(a3)
	rts

	IFD	HY_MENU
; "Pad 2 = CD32 pad" / "Pad 2 = KTRL CD32+" in the config text (padcfg.s, after HyCD32Cfg):
; a0 = text, a1 = its end; any case, blanks around; port 1 on the low clock or not (HyCD32Low
; bit 0). A line that does not parse changes nothing. Keeps every register.
sgb_padcfg:
	movem.l	d0-d1/a0/a2,-(sp)
.line:	bsr.s	.blank
	lea	sgb_kpad2,a2
	bsr.s	.word
	beq.s	.skip
	bsr.s	.blank
	cmp.l	a1,a0
	bcc.s	.skip
	cmp.b	#"=",(a0)+
	bne.s	.skip
	bsr.s	.blank
	lea	sgb_kktrl,a2
	move.l	a0,-(sp)
	bsr.s	.word
	beq.s	.notk
	addq.l	#4,sp
	bset	#0,HyCD32Low
	bra.s	.skip
.notk:	move.l	(sp)+,a0
	lea	sgb_kcd32,a2
	bsr.s	.word
	beq.s	.skip
	bclr	#0,HyCD32Low
.skip:	cmp.l	a1,a0			; to the next line
	bcc.s	.x
	cmp.b	#10,(a0)+
	bne.s	.skip
	bra.s	.line
.x:	movem.l	(sp)+,d0-d1/a0/a2
	rts
.blank:	cmp.l	a1,a0			; a0 over spaces, tabs and CRs
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
; the upper-case text at a2 (ends with 0; a space in it matches any blanks) at a0, any case,
; then not a letter: NE and a0 behind it, or EQ
.word:	move.b	(a2)+,d1
	beq.s	.wend
	cmp.b	#" ",d1
	bne.s	.wc
	bsr.s	.blank
	bra.s	.word
.wc:	cmp.l	a1,a0
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
	ENDC

	SECTION	sgbpdata,DATA
sgb_p2b:	dc.b	$ff		; player 2's buttons (A B Select Start) and directions
sgb_p2d:	dc.b	$ff		; (Right Left Up Down), low active, as buttons_byte
sgb_cdpre:	dc.b	0		; sgb_cd2 holds this frame's port 2 read
	even
sgb_cd2:	dc.w	0		; the CD32 reads (nine bits), port 2 and port 1
sgb_cd1:	dc.w	0
sgb_r2:		dcb.b	16,$ff		; player 2's Regs stand-in (EstadoJoy, EstadoKeys)
	IFD	SGB_P2STAT
sgb_p2st:	dc.l	0,0,0,0
	ENDC
	IFD	HY_MENU
sgb_kpad2:	dc.b	"PAD 2",0
sgb_kktrl:	dc.b	"KTRL",0
sgb_kcd32:	dc.b	"CD32",0
	even
	ENDC
	ENDC

	SECTION	sgbdata,DATA
sgb_opt:	dc.b	1		; "Super Game Boy = Auto" (1, the default) or Off (0)
	IFD	SGB_OPT
sgb_kname:	dc.b	"SUPER GAME BOY",0	; the config line (gbc_rcfg)
sgb_kauto:	dc.b	"AUTO",0
	ENDC
	IFD	SGB_DUMP
sgb_dname:	dc.b	"GB:AmiGB.sgb",0
	even
sgb_dhead:	dc.b	"SGB1"
	ds.b	24
	IFD	SGB_SNAP
sgb_snhead:	dc.b	"SGBS"
	dc.l	0
	ENDC
	ENDC
	even

	SECTION	sgbbss,BSS
sgb_dstart:				; cleared at each Power On
sgb_on:		ds.b	1		; the cart has the Super Game Boy (packets)
sgb_col:	ds.b	1		; ... and is mono: the block palettes
sgb_p1:		ds.b	1		; the last P1 write
sgb_rdy:	ds.b	1		; both lines were high since the last pulse
sgb_inpk:	ds.b	1		; a packet is coming in
sgb_stopw:	ds.b	1		; 128 bits in: the stop bit next
sgb_mlt:	ds.b	1		; pads - 1 (0, 1, 3)
sgb_player:	ds.b	1		; the pad P1 shows (0-3)
sgb_dis:	ds.b	1		; ICON_EN: no more packets
sgb_mask:	ds.b	1		; MASK_EN 0-3
sgb_trn:	ds.b	1		; a VRAM transfer waiting (its command)
sgb_trnw:	ds.b	1		; frames until it is taken
sgb_trnarg:	ds.b	1		; its byte 1 (CHR_TRN: low or high tiles)
sgb_gotpal:	ds.b	1		; the game has set colours
sgb_bvalid:	ds.b	1		; a border is there
sgb_bdirty:	ds.b	1		; ... to be drawn
sgb_bitn:	ds.w	1		; bits of the command in sgb_buf
sgb_c0w:	ds.w	1		; colour 0 in the screen's format
sgb_bc0:	ds.w	1		; the backdrop the border was drawn with
sgb_pal:	ds.w	16		; palettes 0-3, colours 0-3, 15-bit
sgb_buf:	ds.b	112		; the command, up to 7 packets
sgb_attr:	ds.b	360		; the 20 x 18 blocks' palettes
sgb_sys:	ds.b	4096		; PAL_TRN: 512 palettes of 4 (little-endian)
sgb_atf:	ds.b	4096		; ATTR_TRN: 45 attribute files of 90 bytes
	IFD	HY_FIX251
sgb_trow:	ds.b	13*4		; per tile row of a transfer: LCDC, SCX, SCY, BGP (sgb_hline)
sgb_trowm:	ds.w	1		; ... the rows set since the last transfer was taken
	ENDC
sgb_dend:
sgb_cnt:	ds.l	32		; commands taken, per number (test dump)
sgb_sw:		ds.w	16		; sgb_pal in the screen's format
sgb_lut:	ds.w	4*64		; per palette: line byte -> screen word
sgb_shtab:	ds.b	4
sgb_tbuf:	ds.b	4096		; the last VRAM transfer
	IFD	SGB_BORD
sgb_gl:		ds.w	1		; sgb_bdraw: the picture's left, top, width, height on the
sgb_gt:		ds.w	1		; screen, the border's left and top, the row width
sgb_gpw:	ds.w	1
sgb_gph:	ds.w	1
sgb_gox:	ds.w	1
sgb_goy:	ds.w	1
sgb_gw:		ds.w	1
sgb_bcolw:	ds.w	48		; border colours in the screen's format (0 = backdrop)
sgb_chr:	ds.b	8192		; CHR_TRN: 256 tiles, 4 bits a pixel
sgb_pct:	ds.b	4096		; PCT_TRN: map, palettes 4-6 at $800
sgb_bpix:	ds.b	256*224		; the border picture
sgb_brow:	ds.w	SGB_ROWMAX	; one screen row of it
	ENDC

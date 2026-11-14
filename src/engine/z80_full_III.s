; Taken from Wzonka-Lad 1.03 (Aminet misc/emu/Wzonka-Lad), GPL-2.
; Wzonka-Lad (C) Ville Helin 1996-1999; GPL release and changes by
; Ventzislav Tzvetkov 2003-2004. Changes for AmiGameBoy (C) 2026, same licence;
; see git history. Original file: z80_full_III.s

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		z80 processor emulator, gameboy edition
;		INPUT:
;		d0	= 0.W, d.B, e.B.
;		d1	= 0.W, b.B, c.B.
;		d2	= 0.W, h.B, l.B.
;		d3	= 0.W, f.B, a.B.
;		d4	= 0.W, ccr.W.
;		d5	= 0.W, sp.W.
;		a0	= pointer to z80 code.
;		a1	= base pointer to the z80 jump table.
;		a2	= base pointer to gameboy memory.
;		a3	= base pointer to rom switched area.
;		a4	= base pointer to the z80 $cb jump table.
;		a5	= the amount of cycles to do.
;		NOTE:
;		f	is emulated through amiga's own status register,
;			so it is not stored as z80's status register, but
;			a conversion is always executed when needed (rarely).
;		h	= half carry   flag.
;		n	= substraction     .
;		z	= zero             .
;		c	= carry            .
;		f	= 000xnzvc (680x0)  .
;			= znhc0000 (z80)(gb).
;		680x0	flags = xnzvc--.
;		z80(gb)	flags = --z-cnh.
;		f	= 0nhxnzvc (680x0 + emulated xx.B n.6 & h.5).
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

compute_h:	MACRO

		move.b	h_other_I,d6
		move.b	h_other_II,d7

		btst	#8,d3					;0 = add / 1 = sub.
		beq.s	daa_add_x\@
daa_sub_x\@:	tst.b	h_with_carry				;0 = no / 1 = yes.
		bne.s	daa_sbc\@
daa_sub\@:	swap	d0
		move.b	d6,d0
		sub.b	d7,d6
		eor.b	d0,d6
		eor.b	d7,d6
		and.b	#$10,d6					;d6 = h!
		bra.w	daa_flags\@
daa_sbc\@:	swap	d0
		move.b	d6,d0
		or.b	#$14,CCR				;x = 1!
		subx.b	d7,d6
		eor.b	d0,d6
		eor.b	d7,d6
		and.b	#$10,d6					;d6 = h!
		bra.s	daa_flags\@

daa_add_x\@:	tst.b	h_with_carry				;0 = no / 1 = yes.
		bne.s	daa_adc\@
daa_add\@:	swap	d0
		move.b	d6,d0
		add.b	d7,d6
		eor.b	d0,d6
		eor.b	d7,d6
		and.b	#$10,d6					;d6 = h!
		bra.s	daa_flags\@
daa_adc\@:	swap	d0
		move.b	d6,d0
		or.b	#$14,CCR				;x = 1!
		addx.b	d7,d6
		eor.b	d0,d6
		eor.b	d7,d6
		and.b	#$10,d6					;d6 = h!

daa_flags\@:	clr.w	d0
		swap	d0
		ENDM

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		calculate h for the PUSH AF command
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

calculate_h:	move.l	d6,-(SP)

		compute_h					;find the flag.

		and.w	#$ff,d6
		move.l	(SP)+,d7
		lsl.b	#1,d6					;d6 =     (00h00000).
		or.w	d7,d6					;d6 =     (znhc0000).
		bra.w	write_d6_stack

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		execute the DAA command from optcodes
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

daa_execute:	clr.l	d6
		tst.b	h_the_flag				;h = 0?
		beq.w	daa_flags_x				;yes. flags only.

		move.b	h_the_flag,d6
		and.b	#1,d6					;d6 = h!
		lsl.b	#4,d6					;h = h ($10/0).
		bne.w	daa_flags_x				;h = 1!

daa_execute_nor:compute_h

;---------------------------------------------------------------------------------------
;		DAA FLAG OUTPUTTER AND VALUE ADJUSTER
;		INPUT:
;		d6	= h ($10/0).
;---------------------------------------------------------------------------------------

daa_flags_x:	lsr.b	#2,d6					;h00.
		move.b	d4,d7
		lsl.b	#1,d7
		and.b	#%10,d7
		clr.l	h_other_I				;h = 0!
		or.b	d7,d6					;hc0.
		ror.w	#8,d3
		lea	daa_jumps(pc),a6
		or.b	d3,d6					;hcn.
		rol.w	#8,d3
		jmp	([a6,d6.l*4])

		cnop	0,16
daa_jumps:	dc.l	daa_000
		dc.l	daa_0n0
		dc.l	daa_00c
		dc.l	daa_0nc
		dc.l	daa_h00
		dc.l	daa_hn0
		dc.l	daa_h0c
		dc.l	daa_hnc

;---------------------------------------------------------------------------------------

daa_hnc:	move.b	d3,d6
		move.b	d3,d7
		lsr.b	#4,d6					;d6 = h.B.
		and.b	#$f,d7					;d7 = l.B.

		cmp.b	#6,d6					;h.
		blt.s	daa_exit_000
		cmp.b	#6,d7					;l.
		blt.s	daa_exit_000

		add.b	#$9a,d3
		or.b	#%1,d4					;c = 1!

daa_exit_000:	fetch_next_i

;---------------------------------------------------------------------------------------

daa_000:	move.b	d3,d6
		move.b	d3,d7
		lsr.b	#4,d6					;d6 = h.B.
		and.b	#$f,d7					;d7 = l.B.

		cmp.b	#9,d6					;h.
		bgt.s	daa_000_2
		cmp.b	#9,d7					;l.
		bgt.s	daa_000_2

;		add.b	#$00,d3
		and.b	#%11111110,d4				;c = 0!

		fetch_next_i

daa_000_2:	cmp.b	#8,d6					;h.
		bgt.s	daa_000_3
		cmp.b	#$A,d7					;l.
		blt.s	daa_000_3

		add.b	#$06,d3
		and.b	#%11111110,d4				;c = 0!

		fetch_next_i

daa_000_3:	cmp.b	#$A,d6					;h.
		blt.s	daa_000_4
		cmp.b	#9,d7					;l.
		bgt.s	daa_000_4

		add.b	#$60,d3
		or.b	#%1,d4					;c = 1!

		fetch_next_i

daa_000_4:	cmp.b	#9,d6					;h.
		blt.s	daa_exit_001
		cmp.b	#$A,d7					;l.
		blt.s	daa_exit_001

		add.b	#$66,d3
		or.b	#%1,d4					;c = 1!

daa_exit_001:	fetch_next_i

;---------------------------------------------------------------------------------------

daa_00c:	move.b	d3,d6
		move.b	d3,d7
		lsr.b	#4,d6					;d6 = h.B.
		and.b	#$f,d7					;d7 = l.B.

		cmp.b	#2,d6					;h.
		bgt.s	daa_00c_2
		cmp.b	#9,d7					;l.
		bgt.s	daa_00c_2

		add.b	#$60,d3
		or.b	#%1,d4					;c = 1!

		fetch_next_i

daa_00c_2:	cmp.b	#2,d6					;h.
		bgt.s	daa_exit_002
		cmp.b	#$A,d7					;l.
		blt.s	daa_exit_002

		add.b	#$66,d3
		or.b	#%1,d4					;c = 1!

daa_exit_002:	fetch_next_i

;---------------------------------------------------------------------------------------

daa_0n0:	move.b	d3,d6
		move.b	d3,d7
		lsr.b	#4,d6					;d6 = h.B.
		and.b	#$f,d7					;d7 = l.B.

		cmp.b	#9,d6					;h.
		bgt.s	daa_exit_003
		cmp.b	#9,d7					;l.
		bgt.s	daa_exit_003

;		add.b	#$00,d3
		and.b	#%11111110,d4				;c = 0!

daa_exit_003:	fetch_next_i

;---------------------------------------------------------------------------------------

daa_0nc:	move.b	d3,d6
		move.b	d3,d7
		lsr.b	#4,d6					;d6 = h.B.
		and.b	#$f,d7					;d7 = l.B.

		cmp.b	#7,d6					;h.
		blt.s	daa_exit_004
		cmp.b	#9,d7					;l.
		bgt.s	daa_exit_004

		add.b	#$a0,d3
		or.b	#%1,d4					;c = 1!

daa_exit_004:	fetch_next_i

;---------------------------------------------------------------------------------------

daa_h00:	move.b	d3,d6
		move.b	d3,d7
		lsr.b	#4,d6					;d6 = h.B.
		and.b	#$f,d7					;d7 = l.B.

		cmp.b	#9,d6					;h.
		bgt.s	daa_h00_2
		cmp.b	#3,d7					;l.
		bgt.s	daa_h00_2

		add.b	#$06,d3
		and.b	#%11111110,d4				;c = 0!

		fetch_next_i

daa_h00_2:	cmp.b	#$A,d6					;h.
		blt.s	daa_exit_005
		cmp.b	#3,d7					;l.
		bgt.s	daa_exit_005

		add.b	#$66,d3
		or.b	#%1,d4					;c = 1!

daa_exit_005:	fetch_next_i

;---------------------------------------------------------------------------------------

daa_h0c:	move.b	d3,d6
		move.b	d3,d7
		lsr.b	#4,d6					;d6 = h.B.
		and.b	#$f,d7					;d7 = l.B.

		cmp.b	#3,d6					;h.
		bgt.s	daa_exit_006
		cmp.b	#3,d7					;l.
		bgt.s	daa_exit_006

		add.b	#$66,d3
		or.b	#%1,d4					;c = 1!

daa_exit_006:	fetch_next_i

;---------------------------------------------------------------------------------------

daa_hn0:	move.b	d3,d6
		move.b	d3,d7
		lsr.b	#4,d6					;d6 = h.B.
		and.b	#$f,d7					;d7 = l.B.

		cmp.b	#8,d6					;h.
		bgt.s	daa_exit_007
		cmp.b	#6,d7					;l.
		blt.s	daa_exit_007

		add.b	#$fa,d3
		and.b	#%11111110,d4				;c = 0!

daa_exit_007:	fetch_next_i

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		trash the oam ram according to the hardware bug
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

trash_oam_ram:
		IFD	HY_GBC				;AmiGameBoy GBC: the CGB has no OAM bug.
		tst.b	gbc_mode
		bne.s	trash_oam_ram_x
		ENDC
		move.l	a2,a6
		add.l	#$FE08,a6
		moveq.l	#38/2-1,d7

trash_oam_ram_loop:
		clr.l	(a6)+
		clr.l	(a6)+
		dbra	d7,trash_oam_ram_loop
trash_oam_ram_x:
		rts

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		a normal cpu sweep begins here
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

		cnop	0,4
z80_cpu_sweep:	move.l	z80_cycles,a5				;a5 = cycles to do.
		moveq.l	#0,d7
		fetch_next_i

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		the z80 instruction jump table
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

		cnop	0,128
		IFND	NO_IDLESKIP
		IFND	SPIKE_TRACE
		dcb.b	114,0					;AmiGameBoy: JR offsets that may close a
		dc.b	1,1,1,1,1,1,1,1,1,1,0,1,0,0		;poll loop: -14..-5 and -3 (idle_jr).
		dcb.b	128,0
		ENDC
		ENDC
z80_jump_table:

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		00 - NOP
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_00:	subq.l	#1,a5					;less cycles.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		the z80 extended instruction jump table
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_jump_tbl_cb:

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB00 - RLC B - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB00:	ror.w	#8,d1
		subq.l	#2,a5					;less cycles.
		rol.b	#1,d1
		move.w	CCR,d4
		rol.w	#8,d1

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		01 - LD BC, xx
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_01:	move.w	(a0)+,d1
		subq.l	#3,a5
		ror.w	#8,d1

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB01 - RLC C - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB01:	subq.l	#2,a5					;less cycles.
		rol.b	#1,d1
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		02 - LD (BC), A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_02:	move.b	d3,d6
		move.w	d1,d7
		move.l	gb_mem_jumps,a6
        	subq.l	#2,a5
		jsr	([a6,d1.l*4])

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB02 - RLC D - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB02:	ror.w	#8,d0					;d down.
		subq.l	#2,a5					;less cycles.
		rol.b	#1,d0
		move.w	CCR,d4					;status updated.
		rol.w	#8,d0					;d back to up.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		03 - INC BC
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_03:	subq.l	#2,a5
		cmp.l	#$FE00,d1
		blt.s	z80_optcode_03_ok
		cmp.l	#$FEFF,d1
		bgt.s	z80_optcode_03_ok

		bsr.w	trash_oam_ram

z80_optcode_03_ok:
		addq.w	#1,d1

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB03 - RLC E - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB03:	subq.l	#2,a5					;less cycles.
		rol.b	#1,d0
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		04 - INC B - [n = 0, h = x, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_04:	move.l	#$00010002,h_other_I
		ror.w	#8,d1
		subq.l	#1,a5
		move.b	d1,h_other_I
		and.b	#%1,d4

		addq.b	#1,d1
		move.w	CCR,d7
		rol.w	#8,d1
		and.b	#%11111110,d7
		and.w	#$ff,d3
		or.b	d7,d4

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB04 - RLC H - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB04:	ror.w	#8,d2					;h down.
		subq.l	#2,a5					;less cycles.
		rol.b	#1,d2
		move.w	CCR,d4					;status updated.
		rol.w	#8,d2					;h back to up.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		05 - DEC B - [n = 1, h = x, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_05:	move.l	#$00010002,h_other_I
		ror.w	#8,d1					;b down.
		subq.l	#1,a5					;less cycles.
		move.b	d1,h_other_I
		and.b	#%1,d4					;save carry.

		subq.b	#1,d1					;b = b - 1.
		move.w	CCR,d7					;status updated.
		rol.w	#8,d1
		and.b	#%11111110,d7				;c = 0.
		or.w	#$100,d3				;n = 1!
		or.b	d7,d4					;return carry.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB05 - RLC L - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB05:	subq.l	#2,a5					;less cycles.
		rol.b	#1,d2
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		06 - LD B, x
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_06:	ror.w	#8,d1					;b down.
		subq.l	#2,a5					;less cycles.
		move.b	(a0)+,d1
		rol.w	#8,d1					;b back to up.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB06 - RLC (HL) - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB06:	subq.l	#4,a5
		READ_D2_TO_D6
		rol.b	#1,d6
		move.w	CCR,d4					;status updated.
		move.w	d2,d7					;d7 = a (hl) - write.

		move.l	gb_mem_jumps,a6
		jsr	([a6,d2.l*4])				;memory write.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		07 - RLCA - [n = 0, h = 0, c = x, z = 0]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_07:	subq.l	#1,a5					;less cycles.
		rol.b	#1,d3					;rotate left c. acc.
		move.w	CCR,d4					;status updated.
		clr.l	h_other_I				;h = 0! no carry!
		and.b	#%1,d4
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB07 - RLC A - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB07:	subq.l	#2,a5					;less cycles.
		rol.b	#1,d3
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		08 - LD (xx), SP
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_08:	move.w	(a0)+,d7
		ror.w	#8,d7
		subq.l	#5,a5
		move.l	d7,-(SP)
		move.b	d5,d6

		move.l	gb_mem_jumps,a6
		jsr	([a6,d7.l*4])				;memory write.

		move.l	(SP)+,d7
		move.w	d5,d6
		addq.w	#1,d7					;next byte.
		lsr.w	#8,d6					;high byte last.

		move.l	gb_mem_jumps,a6
		jsr	([a6,d7.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB08 - RRC B - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB08:	ror.w	#8,d1					;b down.
		subq.l	#2,a5					;less cycles.
		ror.b	#1,d1
		move.w	CCR,d4					;status updated.
		rol.w	#8,d1					;b back to up.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		09 - ADD HL, BC - [n = 0, h = ?, c = x, z = z]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_09:	and.b	#%11111110,d4				;c = 0.
		subq.l	#2,a5					;less cycles.

		move.w	d1,d6
		move.w	d2,d7
		and.w	#%100000000000,d6
		and.w	#%100000000000,d7
		and.w	d6,d7
		lsr.w	#8,d7
		lsr.b	#2,d7
		move.b	d7,h_the_flag				;h from bits 11.

		add.w	d1,d2					;add hl, bc.
		move.w	CCR,d7					;status updated.
		and.w	#$ff,d3					;n = 0!
		and.b	#%1,d7					;save carry.
		or.b	d7,d4					;return the rest (z).

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB09 - RRC C - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB09:	subq.l	#2,a5					;less cycles.
		ror.b	#1,d1
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		0A - LD A, (BC)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_0A:	subq.l	#2,a5					;less cycles.

		tst.w	d1					;rom read?
		blt.s	read_d1_to_d3ax				;nope. from ram!
		move.b	(a3,d1.l),d3

		fetch_next_i
		cnop	0,4

read_d1_to_d3ax:	GBC_RD	d1,d3				;ram read.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB0A - RRC D - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB0A:	ror.w	#8,d0					;d down.
		subq.l	#2,a5					;less cycles.
		ror.b	#1,d0
		move.w	CCR,d4					;status updated.
		rol.w	#8,d0					;d back to up.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		0B - DEC BC
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_0B:	subq.l	#2,a5					;less cycles.
		cmp.l	#$FE00,d1
		blt.s	z80_optcode_0B_ok
		cmp.l	#$FEFF,d1
		bgt.s	z80_optcode_0B_ok

		bsr.w	trash_oam_ram

z80_optcode_0B_ok:
		subq.w	#1,d1					;bc = bc - 1.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB0B - RRC E - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB0B:	subq.l	#2,a5					;less cycles.
		ror.b	#1,d0
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		0C - INC C - [n = 0, h = x, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_0C:	move.l	#$00010002,h_other_I
		subq.l	#1,a5					;less cycles.
		move.b	d1,h_other_I
		and.b	#%1,d4					;save carry.

		addq.b	#1,d1					;c = c + 1.
		move.w	CCR,d7					;status updated.
		and.b	#%11111110,d7				;c = 0.
		and.w	#$ff,d3					;n = 0!
		or.b	d7,d4					;return carry.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB0C - RRC H - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB0C:	ror.w	#8,d2					;h down.
		subq.l	#2,a5					;less cycles.
		ror.b	#1,d2
		move.w	CCR,d4					;status updated.
		rol.w	#8,d2					;h back to up.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		0D - DEC C - [n = 1, h = x, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_0D:	move.l	#$00010002,h_other_I
		subq.l	#1,a5					;less cycles.
		move.b	d1,h_other_I
		and.b	#%1,d4					;save carry.

		subq.b	#1,d1					;c = c - 1.
		move.w	CCR,d7					;status updated.
		and.b	#%11111110,d7				;c = 0.
		or.w	#$100,d3				;n = 1!
		or.b	d7,d4					;return carry.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB0D - RRC L - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB0D:	subq.l	#2,a5					;less cycles.
		ror.b	#1,d2
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		0E - LD C, x
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_0E:	subq.l	#2,a5					;less cycles.
		move.b	(a0)+,d1

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB0E - RRC (HL) - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB0E:	subq.l	#4,a5
		READ_D2_TO_D6
		ror.b	#1,d6
		move.w	CCR,d4					;status updated.
		move.w	d2,d7					;d7 = a (hl) - write.

		move.l	gb_mem_jumps,a6
		jsr	([a6,d2.l*4])				;memory write.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		0F - RRCA - [n = 0, h = 0, c = x, z = 0]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_0F:	subq.l	#1,a5					;less cycles.
		ror.b	#1,d3					;rotate right c. acc.
		move.w	CCR,d4					;status updated.
		and.w	#$ff,d3					;n = 0!
		and.b	#%1,d4
		clr.l	h_other_I				;h = 0! no carry!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB0F - RRC A - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB0F:	subq.l	#2,a5					;less cycles.
		ror.b	#1,d3
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		10 - STOP (+ 00.B?)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_10:
		IFD	HY_GBC
		jmp	gbc_stop				;AmiGameBoy GBC: speed switch.
		ELSE
		move.b	#1,z80_halt				;z80 stopped!
		rts
		ENDC
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB10 - RL B - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB10:	subq.l	#2,a5					;less cycles.
		lsl.b	#4,d4					;c = mc680x0's x!
		ror.w	#8,d1

		move.w	d4,CCR
		roxl.b	#1,d1
		move.w	CCR,d4

		rol.w	#8,d1
		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		11 - LD DE, xx
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_11:	move.w	(a0)+,d0
		subq.l	#3,a5
		ror.w	#8,d0

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB11 - RL C - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB11:	lsl.b	#4,d4					;c = mc680x0's x!
		subq.l	#2,a5

		move.w	d4,CCR
		roxl.b	#1,d1
		move.w	CCR,d4

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		12 - LD (DE), A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_12:	subq.l	#2,a5					;less cycles.
		move.w	d0,d7					;d7 = a (de) - write.
		move.b	d3,d6					;d6 = a.

		move.l	gb_mem_jumps,a6
		jsr	([a6,d0.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB12 - RL D - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB12:	subq.l	#2,a5					;less cycles.
		lsl.b	#4,d4					;c = mc680x0's x!
		ror.w	#8,d0

		move.w	d4,CCR
		roxl.b	#1,d0
		move.w	CCR,d4

		rol.w	#8,d0
		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		13 - INC DE
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_13:	subq.l	#2,a5					;less cycles.
		cmp.l	#$FE00,d0
		blt.s	z80_optcode_13_ok
		cmp.l	#$FEFF,d0
		bgt.s	z80_optcode_13_ok

		bsr.w	trash_oam_ram

z80_optcode_13_ok:
		addq.w	#1,d0					;de = de + 1.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB13 - RL E - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB13:	lsl.b	#4,d4					;c = mc680x0's x!
		subq.l	#2,a5					;less cycles.

		move.w	d4,CCR
		roxl.b	#1,d0
		move.w	CCR,d4

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		14 - INC D - [n = 0, h = x, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_14:	move.l	#$00010002,h_other_I
		ror.w	#8,d0					;d down.
		subq.l	#1,a5					;less cycles.
		move.b	d0,h_other_I
		and.b	#%1,d4					;save carry.

		addq.b	#1,d0					;d = d + 1.
		move.w	CCR,d7					;status updated.
		rol.w	#8,d0					;d back to up.
		and.b	#%11111110,d7				;c = 0.
		and.w	#$ff,d3					;n = 0!
		or.b	d7,d4					;return carrry.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB14 - RL H - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB14:	subq.l	#2,a5					;less cycles.
		lsl.b	#4,d4					;c = mc680x0's x!
		ror.w	#8,d2					;h down.

		move.w	d4,CCR
		roxl.b	#1,d2
		move.w	CCR,d4

		rol.w	#8,d2					;h back to up.
		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		15 - DEC D - [n = 1, h = x, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_15:	move.l	#$00010002,h_other_I
		ror.w	#8,d0					;d down.
		subq.l	#1,a5					;less cycles.
		move.b	d0,h_other_I
		and.b	#%1,d4					;save carry.

		subq.b	#1,d0					;d = d - 1.
		move.w	CCR,d7					;status updated.
		rol.w	#8,d0					;d back to up.
		and.b	#%11111110,d7				;c = 0.
		or.w	#$100,d3				;n = 1!
		or.b	d7,d4					;return carry.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB15 - RL L - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB15:	lsl.b	#4,d4					;c = mc680x0's x!
		subq.l	#2,a5					;less cycles.

		move.w	d4,CCR
		roxl.b	#1,d2
		move.w	CCR,d4

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		16 - LD D, x
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_16:	ror.w	#8,d0					;d down.
		subq.l	#2,a5					;less cycles.
		move.b	(a0)+,d0
		rol.w	#8,d0					;d back to up.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB16 - RL (HL) - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB16:	subq.l	#4,a5
		lsl.b	#4,d4					;c = mc680x0's x!
		READ_D2_TO_D6

		move.w	d4,CCR
		roxl.b	#1,d6
		move.w	CCR,d4

		move.l	gb_mem_jumps,a6
		move.w	d2,d7
		jsr	([a6,d2.l*4])				;memory write.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		17 - RLA - [n = 0, h = 0, c = x, z = 0]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_17:	lsl.b	#4,d4					;c = mc680x0's x!
		subq.l	#1,a5					;less cycles.

		move.w	d4,CCR
		roxl.b	#1,d3
		move.w	CCR,d4

		and.w	#$ff,d3					;n = 0!
		and.b	#%1,d4					;z = 0!
		clr.l	h_other_I				;h = 0! no carry!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB17 - RL A - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB17:	lsl.b	#4,d4					;c = mc680x0's x!
		subq.l	#2,a5					;less cycles.

		move.w	d4,CCR
		roxl.b	#1,d3
		move.w	CCR,d4

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		18 - JR x
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_18:	move.b	(a0)+,d7
		ext.w	d7
		subq.l	#2,a5
		IFND	NO_CYCLES
		subq.l	#1,a5					;AmiGameBoy: JR is 3 M-cycles.
		ENDC
		adda.w	d7,a0
		IFND	NO_JRWRAP
		cmpa.l	a3,a0					;AmiGameBoy: jr wrapped below $0000?
		bcs.l	jr_wrap
		ENDC

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB18 - RR B - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB18:	subq.l	#2,a5					;less cycles.
		lsl.b	#4,d4					;c = mc680x0's x!
		ror.w	#8,d1					;b down.

		move.w	d4,CCR
		roxr.b	#1,d1
		move.w	CCR,d4

		rol.w	#8,d1					;b back to up.
		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		19 - ADD HL, DE - [n = 0, h = ?, c = x, z = z]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_19:	subq.l	#2,a5					;less cycles.
		and.b	#%11111110,d4				;save z.

		move.w	d0,d6
		move.w	d2,d7
		and.w	#%100000000000,d6
		and.w	#%100000000000,d7
		and.w	d6,d7
		lsr.w	#8,d7
		lsr.b	#2,d7
		move.b	d7,h_the_flag				;h from bits 11.

		add.w	d0,d2					;hl = hl + de.
		move.w	CCR,d7					;status updated.
		and.w	#$ff,d3					;n = 0!
		and.b	#%1,d7					;save c.
		or.b	d7,d4					;return z.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB19 - RR C - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB19:	subq.l	#2,a5					;less cycles.
		lsl.b	#4,d4					;c = mc680x0's x!

		move.w	d4,CCR
		roxr.b	#1,d1
		move.w	CCR,d4

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		1A - LD A, (DE)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_1A:	subq.l	#2,a5					;less cycles.

		tst.w	d0
		blt.s	read_d0x_to_d3a				;nope. from ram!
		move.b	(a3,d0.l),d3

		fetch_next_i
		cnop	0,4

read_d0x_to_d3a:	GBC_RD	d0,d3				;ram read.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB1A - RR D - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB1A:	subq.l	#2,a5					;less cycles.
		lsl.b	#4,d4					;c = mc680x0's x!
		ror.w	#8,d0					;d down.

		move.w	d4,CCR
		roxr.b	#1,d0
		move.w	CCR,d4

		rol.w	#8,d0					;d back to up.
		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		1B - DEC DE
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_1B:	subq.l	#2,a5					;less cycles.
		cmp.l	#$FE00,d0
		blt.s	z80_optcode_1B_ok
		cmp.l	#$FEFF,d0
		bgt.s	z80_optcode_1B_ok

		bsr.w	trash_oam_ram

z80_optcode_1B_ok:
		subq.w	#1,d0					;de = de - 1.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB1B - RR E - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB1B:	lsl.b	#4,d4					;c = mc680x0's x!
		subq.l	#2,a5					;less cycles.

		move.w	d4,CCR
		roxr.b	#1,d0
		move.w	CCR,d4

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		1C - INC E - [n = 0, h = x, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_1C:	move.l	#$00010002,h_other_I
		subq.l	#1,a5					;less cycles.
		move.b	d0,h_other_I
		and.b	#%1,d4					;save carry.

		addq.b	#1,d0					;e = e + 1.
		move.w	CCR,d7					;status updated.
		and.b	#%11111110,d7				;c = 0.
		and.w	#$ff,d3					;n = 0!
		or.b	d7,d4					;return carry.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB1C - RR H - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB1C:	subq.l	#2,a5					;less cycles.
		lsl.b	#4,d4					;c = mc680x0's x!
		ror.w	#8,d2					;h down.

		move.w	d4,CCR
		roxr.b	#1,d2
		move.w	CCR,d4

		rol.w	#8,d2					;h back to up.
		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		1D - DEC E - [n = 1, h = x, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_1D:	move.l	#$00010002,h_other_I
		subq.l	#1,a5					;less cycles.
		move.b	d0,h_other_I
		and.b	#%1,d4					;save carry.

		subq.b	#1,d0					;e = e - 1.
		move.w	CCR,d7					;status updated.
		and.b	#%11111110,d7				;c = 0.
		or.w	#$100,d3				;n = 1!
		or.b	d7,d4					;return carry.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB1D - RR L - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB1D:	lsl.b	#4,d4					;c = mc680x0's x!
		subq.l	#2,a5					;less cycles.

		move.w	d4,CCR
		roxr.b	#1,d2
		move.w	CCR,d4

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		1E - LD E, x
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_1E:	subq.l	#2,a5					;less cycles.
		move.b	(a0)+,d0

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB1E - RR (HL) - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB1E:	subq.l	#4,a5
		lsl.b	#4,d4					;c = mc680x0's x!
		READ_D2_TO_D6

		move.w	d4,CCR
		roxr.b	#1,d6
		move.w	CCR,d4

		move.w	d2,d7					;d7 = a (hl) - write.

		move.l	gb_mem_jumps,a6
		jsr	([a6,d2.l*4])				;memory write.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		1F - RRA - [n = 0, h = 0, c = x, z = 0]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_1F:	lsl.b	#4,d4					;c = mc680x0's x!
		subq.l	#1,a5					;less cycles.

		move.w	d4,CCR
		roxr.b	#1,d3
		move.w	CCR,d4

		and.w	#$ff,d3					;n = 0!
		and.b	#%1,d4
		clr.l	h_other_I				;h = 0! no carry!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB1F - RR A - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB1F:	lsl.b	#4,d4					;c = mc680x0's x!
		subq.l	#2,a5					;less cycles.

		move.w	d4,CCR
		roxr.b	#1,d3
		move.w	CCR,d4

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		20 - JR NZ, x
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_20:	subq.l	#2,a5

		btst	#2,d4					;z - flag set?
		bne.s	z80_optcode_20x				;yes. it's zero.

		move.b	(a0)+,d7
		ext.w	d7
		adda.w	d7,a0
		IFND	NO_CYCLES
		subq.l	#1,a5					;AmiGameBoy: JR cc taken is 3.
		ENDC
		IFD	IDL_QUICK
		bpl.s	jrq0f					;AmiGameBoy: forward (N from the ext.w; adda and
		IFND	NO_JRWRAP				;subq on a5 leave it): no wrap, no loop.
		cmpa.l	a3,a0					;jr wrapped below $0000?
		bcs.l	jr_wrap
		ENDC
		cmp.b	#$be,(a0)				;a poll loop starts $F0, $FA or $BE: any target
		bcc.s	jrq0c					;under $BE (copy and count loops) goes straight
jrq0f:	fetch_next_i					;on. (With a record live the only JR taken is
		ELSE						;the loop's own: see idle_jr.)
		IFND	NO_JRWRAP
		cmpa.l	a3,a0					;AmiGameBoy: jr wrapped below $0000?
		bcs.l	jr_wrap
		ENDC
		IFND	NO_IDLESKIP
		IFND	SPIKE_TRACE
		tst.b	-128(a1,d7.w)				;AmiGameBoy: 3 or 5-14 bytes back (table
		bne.l	idle_jr					;under the handlers): a poll loop?
		ENDC
		ENDC

		fetch_next_i
		ENDC
		cnop	0,4

z80_optcode_20x:addq.l	#1,a0					;no jump.

		fetch_next_i
		IFD	IDL_QUICK
jrq0c:	tst.b	-128(a1,d7.w)				;AmiGameBoy: 3 or 5-14 bytes back (table
		bne.l	idle_jr					;under the handlers): a poll loop?
		fetch_next_i
		ENDC
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB20 - SLA B - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB20:	ror.w	#8,d1
		subq.l	#2,a5					;less cycles.
		asl.b	#1,d1
		move.w	CCR,d4					;status updated.
		rol.w	#8,d1

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		21 - LD HL, xx
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_21:	move.w	(a0)+,d2
		subq.l	#3,a5
		ror.w	#8,d2

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB21 - SLA C - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB21:	subq.l	#2,a5					;less cycles.
		asl.b	#1,d1
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		22 - LDI (HL), A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_22:	subq.l	#2,a5					;less cycles.
		move.w	d2,d7					;d7 = a (hl) - write.
		move.b	d3,d6					;d6 = a.

		move.l	gb_mem_jumps,a6
		jsr	([a6,d2.l*4])				;memory write.

		cmp.l	#$FE00,d2
		blt.s	z80_optcode_22_ok
		cmp.l	#$FEFF,d2
		bgt.s	z80_optcode_22_ok

		bsr.w	trash_oam_ram

z80_optcode_22_ok:
		addq.w	#1,d2					;ldi to hl.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB22 - SLA D - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB22:	ror.w	#8,d0					;d down.
		subq.l	#2,a5					;less cycles.
		asl.b	#1,d0
		move.w	CCR,d4					;status updated.
		rol.w	#8,d0					;d back to up.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		23 - INC HL
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_23:	subq.l	#2,a5					;less cycles.
		cmp.l	#$FE00,d2
		blt.s	z80_optcode_23_ok
		cmp.l	#$FEFF,d2
		bgt.s	z80_optcode_23_ok

		bsr.w	trash_oam_ram

z80_optcode_23_ok:
		addq.w	#1,d2					;hl = hl + 1.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB23 - SLA E - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB23:	subq.l	#2,a5					;less cycles.
		asl.b	#1,d0
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		24 - INC H - [n = 0, h = x, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_24:	move.l	#$00010002,h_other_I
		ror.w	#8,d2					;h down.
		subq.l	#1,a5					;less cycles.
		move.b	d2,h_other_I
		and.b	#%1,d4					;save carry.

		addq.b	#1,d2					;h = h + 1.
		move.w	CCR,d7					;status updated.
		rol.w	#8,d2					;h back to up.
		and.b	#%11111110,d7				;c = 0.
		and.w	#$ff,d3					;n = 0!
		or.b	d7,d4					;return carry.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB24 - SLA H - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB24:	ror.w	#8,d2
		subq.l	#2,a5					;less cycles.
		asl.b	#1,d2
		move.w	CCR,d4					;status updated.
		rol.w	#8,d2

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		25 - DEC H - [n = 1, h = x, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_25:	move.l	#$00010002,h_other_I
		ror.w	#8,d2					;h down.
		subq.l	#1,a5					;less cycles.
		move.b	d2,h_other_I
		and.b	#%1,d4					;save carry.

		subq.b	#1,d2					;h = h - 1.
		move.w	CCR,d7					;status updated.
		rol.w	#8,d2					;h back to up.
		and.b	#%11111110,d7				;c = 0.
		or.w	#$100,d3				;n = 1!
		or.b	d7,d4					;return carry.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB25 - SLA L - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB25:	subq.l	#2,a5					;less cycles.
		asl.b	#1,d2
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		26 - LD H, x
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_26:	ror.w	#8,d2					;h down
		subq.l	#2,a5					;less cycles.
		move.b	(a0)+,d2
		rol.w	#8,d2					;h back to up.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB26 - SLA (HL) - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB26:	subq.l	#4,a5
		READ_D2_TO_D6
		asl.b	#1,d6
		move.w	CCR,d4					;status updated.
		move.w	d2,d7					;d7 = a (hl) - write.

		move.l	gb_mem_jumps,a6
		jsr	([a6,d2.l*4])				;memory write.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		27 - DAA - [n = n, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_27:	subq.l	#1,a5					;less cycles.
		bra.w	daa_execute				;more space there.
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB27 - SLA A - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB27:	subq.l	#2,a5					;less cycles.
		asl.b	#1,d3
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		28 - JR Z, x
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_28:	subq.l	#2,a5

		btst	#2,d4					;z - flag set?
		beq.s	z80_optcode_28x				;nope. it's non-zero.

		move.b	(a0)+,d7
		ext.w	d7
		adda.w	d7,a0
		IFND	NO_CYCLES
		subq.l	#1,a5					;AmiGameBoy: JR cc taken is 3.
		ENDC
		IFD	IDL_QUICK
		bpl.s	jrq1f					;AmiGameBoy: forward (N from the ext.w; adda and
		IFND	NO_JRWRAP				;subq on a5 leave it): no wrap, no loop.
		cmpa.l	a3,a0					;jr wrapped below $0000?
		bcs.l	jr_wrap
		ENDC
		cmp.b	#$be,(a0)				;a poll loop starts $F0, $FA or $BE: any target
		bcc.s	jrq1c					;under $BE (copy and count loops) goes straight
jrq1f:	fetch_next_i					;on. (With a record live the only JR taken is
		ELSE						;the loop's own: see idle_jr.)
		IFND	NO_JRWRAP
		cmpa.l	a3,a0					;AmiGameBoy: jr wrapped below $0000?
		bcs.l	jr_wrap
		ENDC
		IFND	NO_IDLESKIP
		IFND	SPIKE_TRACE
		tst.b	-128(a1,d7.w)				;AmiGameBoy: 3 or 5-14 bytes back (table
		bne.l	idle_jr					;under the handlers): a poll loop?
		ENDC
		ENDC

		fetch_next_i
		ENDC
		cnop	0,4

z80_optcode_28x:addq.l	#1,a0					;no jump.

		fetch_next_i
		IFD	IDL_QUICK
jrq1c:	tst.b	-128(a1,d7.w)				;AmiGameBoy: 3 or 5-14 bytes back (table
		bne.l	idle_jr					;under the handlers): a poll loop?
		fetch_next_i
		ENDC
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB28 - SRA B - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB28:	ror.w	#8,d1
		subq.l	#2,a5					;less cycles.
		asr.b	#1,d1
		move.w	CCR,d4					;status updated.
		rol.w	#8,d1

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		29 - ADD HL, HL - [n = 0, h = ?, c = x, z = z]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_29:	subq.l	#2,a5					;less cycles.
		and.b	#%11111110,d4				;save z.

		move.w	d2,d7
		and.w	#%100000000000,d7
		lsr.w	#8,d7
		lsr.b	#2,d7
		move.b	d7,h_the_flag				;h from bit 11.

		add.w	d2,d2					;hl = hl + hl.
		move.w	CCR,d7					;status updated.
		and.w	#$ff,d3					;n = 0!
		and.b	#%1,d7					;save c.
		or.b	d7,d4					;return z.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB29 - SRA C - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB29:	subq.l	#2,a5					;less cycles.
		asr.b	#1,d1
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		2A - LDI A, (HL)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_2A:	subq.l	#2,a5					;less cycles.

		cmp.l	#$FE00,d2
		blt.s	z80_optcode_2A_ok
		cmp.l	#$FEFF,d2
		bgt.s	z80_optcode_2A_ok

		bsr.w	trash_oam_ram

z80_optcode_2A_ok:
		tst.w	d2					;rom read?
		blt.s	read_d2_to_d3a1				;nope. from ram!

		move.b	(a3,d2.l),d3
		addq.w	#1,d2					;ldi a, (hl).

		fetch_next_i
		cnop	0,4

read_d2_to_d3a1:	GBC_RD	d2,d3				;ram read.
		addq.w	#1,d2					;ldi a, (hl).

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB2A - SRA D - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB2A:	ror.w	#8,d0
		subq.l	#2,a5					;less cycles.
		asr.b	#1,d0
		move.w	CCR,d4					;status updated.
		rol.w	#8,d0

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		2B - DEC HL
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_2B:	subq.l	#2,a5					;less cycles.
		cmp.l	#$FE00,d2
		blt.s	z80_optcode_2B_ok
		cmp.l	#$FEFF,d2
		bgt.s	z80_optcode_2B_ok

		bsr.w	trash_oam_ram

z80_optcode_2B_ok:
		subq.w	#1,d2					;hl = hl - 1.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB2B - SRA E - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB2B:	subq.l	#2,a5					;less cycles.
		asr.b	#1,d0
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		2C - INC L - [n = 0, h = x, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_2C:	move.l	#$00010002,h_other_I
		subq.l	#1,a5					;less cycles.
		move.b	d2,h_other_I
		and.b	#%1,d4					;save carry.

		addq.b	#1,d2					;l = l + 1.
		move.w	CCR,d7					;status updated.
		and.b	#%11111110,d7				;c = 0.
		and.w	#$ff,d3					;n = 0!
		or.b	d7,d4					;return carry.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB2C - SRA H - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB2C:	ror.w	#8,d2					;h down.
		subq.l	#2,a5					;less cycles.
		asr.b	#1,d2
		move.w	CCR,d4					;status updated.
		rol.w	#8,d2					;h back to up.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		2D - DEC L - [n = 1, h = x, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_2D:	move.l	#$00010002,h_other_I
		subq.l	#1,a5					;less cycles.
		move.b	d2,h_other_I
		and.b	#%1,d4					;save carry.

		subq.b	#1,d2					;l = l - 1.
		move.w	CCR,d7					;status updated.
		and.b	#%11111110,d7				;c = 0.
		or.w	#$100,d3				;n = 1!
		or.b	d7,d4					;return carry.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB2D - SRA L - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB2D:	subq.l	#2,a5					;less cycles.
		asr.b	#1,d2
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		2E - LD L, x
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_2E:	subq.l	#2,a5					;less cycles.
		move.b	(a0)+,d2

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB2E - SRA (HL) - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB2E:	
		READ_D2_TO_D6

		move.w	d2,d7
		asr.b	#1,d6
		move.w	CCR,d4					;status updated.

		move.l	gb_mem_jumps,a6
		subq.l	#4,a5
		jsr	([a6,d2.l*4])				;memory write.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		2F - CPL - [n = 1, h = 1, c = c, z = z]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_2F:	subq.l	#1,a5					;less cycles.
		eor.b	#$ff,d3					;cpl a.
		move.b	#1,h_the_flag				;h = 1!
		or.w	#$100,d3				;n = 1!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB2F - SRA A - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB2F:	subq.l	#2,a5					;less cycles.
		asr.b	#1,d3
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		30 - JR NC, x
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_30:	subq.l	#2,a5

		btst	#0,d4					;c - flag set?
		bne.s	z80_optcode_30x				;yes. no jump.

		move.b	(a0)+,d7
		ext.w	d7
		adda.w	d7,a0
		IFND	NO_CYCLES
		subq.l	#1,a5					;AmiGameBoy: JR cc taken is 3.
		ENDC
		IFD	IDL_QUICK
		bpl.s	jrq2f					;AmiGameBoy: forward (N from the ext.w; adda and
		IFND	NO_JRWRAP				;subq on a5 leave it): no wrap, no loop.
		cmpa.l	a3,a0					;jr wrapped below $0000?
		bcs.l	jr_wrap
		ENDC
		cmp.b	#$be,(a0)				;a poll loop starts $F0, $FA or $BE: any target
		bcc.s	jrq2c					;under $BE (copy and count loops) goes straight
jrq2f:	fetch_next_i					;on. (With a record live the only JR taken is
		ELSE						;the loop's own: see idle_jr.)
		IFND	NO_JRWRAP
		cmpa.l	a3,a0					;AmiGameBoy: jr wrapped below $0000?
		bcs.l	jr_wrap
		ENDC
		IFND	NO_IDLESKIP
		IFND	SPIKE_TRACE
		tst.b	-128(a1,d7.w)				;AmiGameBoy: 3 or 5-14 bytes back (table
		bne.l	idle_jr					;under the handlers): a poll loop?
		ENDC
		ENDC

		fetch_next_i
		ENDC
		cnop	0,4

z80_optcode_30x:addq.l	#1,a0					;skip jump.

		fetch_next_i
		IFD	IDL_QUICK
jrq2c:	tst.b	-128(a1,d7.w)				;AmiGameBoy: 3 or 5-14 bytes back (table
		bne.l	idle_jr					;under the handlers): a poll loop?
		fetch_next_i
		ENDC
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB30 - SWAP B - [n = 0, h = 0, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB30:	subq.l	#2,a5					;less cycles.
		ror.w	#8,d1					;b down.
		ror.b	#4,d1					;swap nibbles.
		move.w	CCR,d4
		rol.w	#8,d1					;b back up.
		and.b	#%100,d4
		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		31 - LD SP, xx
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_31:	move.w	(a0)+,d5
		subq.l	#3,a5
		ror.w	#8,d5

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB31 - SWAP C - [n = 0, h = 0, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB31:	subq.l	#2,a5					;less cycles.
		ror.b	#4,d1					;swap nibbles.
		move.w	CCR,d4
		and.b	#%100,d4
		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		32 - LDD (HL), A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_32:	subq.l	#2,a5					;less cycles.
		move.w	d2,d7					;d7 = a (hl) - write.
		move.b	d3,d6					;d6 = a.

		move.l	gb_mem_jumps,a6
		jsr	([a6,d2.l*4])				;memory write.

		cmp.l	#$FE00,d2
		blt.s	z80_optcode_32_ok
		cmp.l	#$FEFF,d2
		bgt.s	z80_optcode_32_ok

		bsr.w	trash_oam_ram

z80_optcode_32_ok:
		subq.w	#1,d2					;ldd to hl.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB32 - SWAP D - [n = 0, h = 0, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB32:	subq.l	#2,a5					;less cycles.
		ror.w	#8,d0					;d down.
		ror.b	#4,d0					;swap nibbles.
		move.w	CCR,d4
		rol.w	#8,d0					;d back up.
		and.b	#%100,d4
		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		33 - INC SP
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_33:	subq.l	#2,a5					;less cycles.
		addq.w	#1,d5					;sp = sp + 1.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB33 - SWAP E - [n = 0, h = 0, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB33:	subq.l	#2,a5					;less cycles.
		ror.b	#4,d0					;swap nibbles.
		move.w	CCR,d4
		and.b	#%100,d4
		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		34 - INC (HL) - [n = 0, h = x, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_34:	move.l	#$00010002,h_other_I
		READ_D2_TO_D6
		subq.l	#3,a5
		move.b	d6,h_other_I
		and.b	#%1,d4					;save carry.

		addq.b	#1,d6					;(hl) = (hl) + 1.
		move.w	CCR,d7					;status updated.
		and.b	#%11111110,d7				;c = 0.
		and.w	#$ff,d3					;n = 0!
		or.b	d7,d4					;return carry.
		move.w	d2,d7					;d7 = a (hl) - write.

		move.l	gb_mem_jumps,a6
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB34 - SWAP H - [n = 0, h = 0, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB34:	subq.l	#2,a5					;less cycles.
		ror.w	#8,d2					;h down.
		ror.b	#4,d2					;swap nibbles.
		move.w	CCR,d4
		rol.w	#8,d2					;h back up.
		and.b	#%100,d4
		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		35 - DEC (HL) - [n = 1, h = x, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_35:	move.l	#$00010002,h_other_I
		READ_D2_TO_D6
		subq.l	#3,a5
		move.b	d6,h_other_I
		and.b	#%1,d4					;save carry.

		subq.b	#1,d6					;(hl) = (hl) - 1.
		move.w	CCR,d7					;status updated.
		and.b	#%11111110,d7				;c = 0.
		or.w	#$100,d3				;n = 1!
		or.b	d7,d4					;return carry.
		move.w	d2,d7					;d7 = a (hl) - write.

		move.l	gb_mem_jumps,a6
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB35 - SWAP L - [n = 0, h = 0, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB35:	subq.l	#2,a5					;less cycles.
		ror.b	#4,d2					;swap nibbles.
		move.w	CCR,d4
		and.b	#%100,d4
		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		36 - LD (HL), x
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_36:	move.b	(a0)+,d6
		subq.l	#3,a5
		move.l	gb_mem_jumps,a6
		move.w	d2,d7
		jsr	([a6,d2.l*4])

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB36 - SWAP (HL) - [n = 0, h = 0, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB36:
		READ_D2_TO_D6
		subq.l	#4,a5
		ror.b	#4,d6					;swap nibbles.
		move.w	CCR,d4
		move.w	d2,d7					;d7 = a (hl) - write.
		and.b	#%100,d4

		move.l	gb_mem_jumps,a6
		jsr	([a6,d2.l*4])				;memory write.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		37 - SCF - [n = 0, h = 0, c = 1, z = z]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_37:	subq.l	#1,a5					;less cycles.
		bset	#0,d4					;set carry flag.
		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB37 - SWAP A - [n = 0, h = 0, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB37:	subq.l	#2,a5					;less cycles.
		ror.b	#4,d3					;swap nibbles.
		move.w	CCR,d4
		and.b	#%100,d4
		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		38 - JR C, x
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_38:	subq.l	#2,a5

		btst	#0,d4					;c - flag set?
		beq.s	z80_optcode_38x				;no. no jump.

		move.b	(a0)+,d7
		ext.w	d7
		adda.w	d7,a0
		IFND	NO_CYCLES
		subq.l	#1,a5					;AmiGameBoy: JR cc taken is 3.
		ENDC
		IFD	IDL_QUICK
		bpl.s	jrq3f					;AmiGameBoy: forward (N from the ext.w; adda and
		IFND	NO_JRWRAP				;subq on a5 leave it): no wrap, no loop.
		cmpa.l	a3,a0					;jr wrapped below $0000?
		bcs.l	jr_wrap
		ENDC
		cmp.b	#$be,(a0)				;a poll loop starts $F0, $FA or $BE: any target
		bcc.s	jrq3c					;under $BE (copy and count loops) goes straight
jrq3f:	fetch_next_i					;on. (With a record live the only JR taken is
		ELSE						;the loop's own: see idle_jr.)
		IFND	NO_JRWRAP
		cmpa.l	a3,a0					;AmiGameBoy: jr wrapped below $0000?
		bcs.l	jr_wrap
		ENDC
		IFND	NO_IDLESKIP
		IFND	SPIKE_TRACE
		tst.b	-128(a1,d7.w)				;AmiGameBoy: 3 or 5-14 bytes back (table
		bne.l	idle_jr					;under the handlers): a poll loop?
		ENDC
		ENDC

		fetch_next_i
		ENDC
		cnop	0,4

z80_optcode_38x:addq.l	#1,a0					;skip jump.

		fetch_next_i
		IFD	IDL_QUICK
jrq3c:	tst.b	-128(a1,d7.w)				;AmiGameBoy: 3 or 5-14 bytes back (table
		bne.l	idle_jr					;under the handlers): a poll loop?
		fetch_next_i
		ENDC
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB38 - SRL B - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB38:	ror.w	#8,d1
		subq.l	#2,a5					;less cycles.
		lsr.b	#1,d1
		move.w	CCR,d4					;status updated.
		rol.w	#8,d1

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		39 - ADD HL, SP - [n = 0, h = ?, c = x, z = z]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_39:	subq.l	#2,a5					;less cycles.
		and.b	#%11111110,d4				;save z.

		move.w	d5,d6
		move.w	d2,d7
		and.w	#%100000000000,d6
		and.w	#%100000000000,d7
		and.w	d6,d7
		lsr.w	#8,d7
		lsr.b	#2,d7
		move.b	d7,h_the_flag				;h from bits 11.

		add.w	d5,d2					;hl = hl + sp.
		move.w	CCR,d7					;status updated.
		and.b	#%1,d7					;save carry.
		and.w	#$ff,d3					;n = 0!
		or.b	d7,d4					;return z.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB39 - SRL C - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB39:	subq.l	#2,a5					;less cycles.
		lsr.b	#1,d1
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		3A - LDD A, (HL)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_3A:	subq.l	#2,a5					;less cycles.

		cmp.l	#$FE00,d2
		blt.s	z80_optcode_3A_ok
		cmp.l	#$FEFF,d2
		bgt.s	z80_optcode_3A_ok

		bsr.w	trash_oam_ram

z80_optcode_3A_ok:
		tst.w	d2					;rom read?
		blt.s	read_d2_to_d3a2				;nope. from ram!

		move.b	(a3,d2.l),d3
		subq.w	#1,d2					;ldd a, (hl).

		fetch_next_i
		cnop	0,4

read_d2_to_d3a2:	GBC_RD	d2,d3				;ram read.
		subq.w	#1,d2					;ldd a, (hl).

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB3A - SRL D - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB3A:	ror.w	#8,d0					;d down.
		subq.l	#2,a5					;less cycles.
		lsr.b	#1,d0
		move.w	CCR,d4					;status updated.
		rol.w	#8,d0					;d back to up.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		3B - DEC SP
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_3B:	subq.l	#2,a5					;less cycles.
		subq.w	#1,d5					;sp = sp - 1.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB3B - SRL E - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB3B:	subq.l	#2,a5					;less cycles.
		lsr.b	#1,d0
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		3C - INC A - [n = 0, h = x, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_3C:	move.l	#$00010002,h_other_I
		subq.l	#1,a5					;less cycles.
		move.b	d3,h_other_I
		and.b	#%1,d4					;save carry.

		addq.b	#1,d3					;a = a + 1.
		move.w	CCR,d7					;status updated.
		and.b	#%11111110,d7				;c = 0.
		and.w	#$ff,d3					;n = 0!
		or.b	d7,d4					;return carry.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB3C - SRL H - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB3C:	ror.w	#8,d2					;h down.
		subq.l	#2,a5					;less cycles.
		lsr.b	#1,d2
		move.w	CCR,d4					;status updated.
		rol.w	#8,d2					;h back to up.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		3D - DEC A - [n = 1, h = x, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_3D:	move.l	#$00010002,h_other_I
		subq.l	#1,a5					;less cycles.
		move.b	d3,h_other_I
		and.b	#%1,d4					;save carry.

		subq.b	#1,d3					;a = a - 1.
		move.w	CCR,d7					;status updated.
		and.b	#%11111110,d7				;c = 0.
		or.w	#$100,d3				;n = 1!
		or.b	d7,d4					;return carry.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB3D - SRL L - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB3D:	subq.l	#2,a5					;less cycles.
		lsr.b	#1,d2
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		3E - LD A, x
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_3E:	subq.l	#2,a5					;less cycles.
		move.b	(a0)+,d3

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB3E - SRL (HL) - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB3E:	subq.l	#4,a5
		READ_D2_TO_D6
		lsr.b	#1,d6
		move.w	CCR,d4					;status updated.
		move.w	d2,d7					;d7 = a (hl) - write.

		move.l	gb_mem_jumps,a6
		jsr	([a6,d2.l*4])				;memory write.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		3F - CCF - [n = 0, h = ?, c = x, z = z]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_3F:	subq.l	#1,a5					;less cycles.
		bchg	#0,d4					;complement carry flag.
		move.b	d3,d7
		and.b	#%1,d7
		move.b	d7,h_the_flag				;h = 0/1 (~random).

		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB3F - SRL A - [n = 0, h = 0, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB3F:	subq.l	#2,a5					;less cycles.
		lsr.b	#1,d3
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		40 - LD B, B
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_40:	subq.l	#1,a5					;less cycles.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB40 - BIT 0, B - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB40:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#8,d1
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		41 - LD B, C
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_41:	move.b	d1,d7
		subq.l	#1,a5					;less cycles.
		lsl.w	#8,d1
		move.b	d7,d1

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB41 - BIT 0, C - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB41:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#0,d1
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		42 - LD B, D
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_42:	move.b	d1,d7
		subq.l	#1,a5					;less cycles.
		move.w	d0,d1
		move.b	d7,d1

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB42 - BIT 0, D - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB42:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#8,d0
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		43 - LD B, E
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_43:	ror.w	#8,d1
		subq.l	#1,a5					;less cycles.
		move.b	d0,d1
		rol.w	#8,d1

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB43 - BIT 0, E - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB43:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#0,d0
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		44 - LD B, H
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_44:	move.b	d1,d7
		subq.l	#1,a5					;less cycles.
		move.w	d2,d1
		move.b	d7,d1

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB44 - BIT 0, H - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB44:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#8,d2
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		45 - LD B, L
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_45:	rol.w	#8,d1
		subq.l	#1,a5					;less cycles.
		move.b	d2,d1
		ror.w	#8,d1

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB45 - BIT 0, L - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB45:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#0,d2
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		46 - LD B, (HL)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_46:	ror.w	#8,d1
		subq.l	#2,a5					;less cycles.

		tst.w	d2					;rom read?
		blt.s	aread_d2_to_d1a				;nope. from ram!
		move.b	(a3,d2.l),d1
		rol.w	#8,d1

		fetch_next_i
		cnop	0,4

aread_d2_to_d1a:	GBC_RD	d2,d1				;ram read.
		rol.w	#8,d1

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB46 - BIT 0, (HL) - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB46:	subq.l	#4,a5
		IFND	NO_CYCLES
		addq.l	#1,a5					;AmiGameBoy: BIT n,(HL) is 3.
		ENDC
		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		tst.w	d2					;rom read?
		blt.s	read_d2a_to_d7a				;nope. from ram!

		move.w	d4,CCR					;the status register.
		btst.b	#0,(a3,d2.l)
		move.w	CCR,d4					;status updated.

		fetch_next_i
		cnop	0,4

read_d2a_to_d7a:		GBC_BTST	0				;ram read.
		move.w	CCR,d4					;status updated.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		47 - LD B, A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_47:	ror.w	#8,d1
		subq.l	#1,a5					;less cycles.
		move.b	d3,d1
		rol.w	#8,d1

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB47 - BIT 0, A - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB47:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#0,d3
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		48 - LD C, B
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_48:	move.w	d1,d7
		subq.l	#1,a5					;less cycles.
		lsr.w	#8,d7
		move.b	d7,d1

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB48 - BIT 1, B - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB48:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#9,d1
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		49 - LD C, C
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_49:	subq.l	#1,a5					;less cycles.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB49 - BIT 1, C - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB49:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#1,d1
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		4A - LD C, D
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_4A:	move.w	d0,d7
		subq.l	#1,a5					;less cycles.
		lsr.w	#8,d7
		move.b	d7,d1

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB4A - BIT 1, D - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB4A:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#9,d0
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		4B - LD C, E
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_4B:	subq.l	#1,a5					;less cycles.
		move.b	d0,d1

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB4B - BIT 1, E - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB4B:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#1,d0
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		4C - LD C, H
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_4C:	move.w	d2,d7
		subq.l	#1,a5					;less cycles.
		lsr.w	#8,d7
		move.b	d7,d1

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB4C - BIT 1, H - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB4C:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#9,d2
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		4D - LD C, L
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_4D:	subq.l	#1,a5					;less cycles.
		move.b	d2,d1

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB4D - BIT 1, L - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB4D:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#1,d2
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		4E - LD C, (HL)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_4E:	subq.l	#2,a5					;less cycles.

		tst.w	d2					;rom read?
		blt.s	bread_d2_to_d1a				;nope. from ram!
		move.b	(a3,d2.l),d1

		fetch_next_i
		cnop	0,4

bread_d2_to_d1a:	GBC_RD	d2,d1				;ram read.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB4E - BIT 1, (HL) - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB4E:	subq.l	#4,a5
		IFND	NO_CYCLES
		addq.l	#1,a5					;AmiGameBoy: BIT n,(HL) is 3.
		ENDC
		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		tst.w	d2					;rom read?
		blt.s	read_d2b_to_d7a				;nope. from ram!

		move.w	d4,CCR					;the status register.
		btst.b	#1,(a3,d2.l)
		move.w	CCR,d4					;status updated.

		fetch_next_i
		cnop	0,4

read_d2b_to_d7a:		GBC_BTST	1				;ram read.
		move.w	CCR,d4					;status updated.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		4F - LD C, A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_4F:	subq.l	#1,a5					;less cycles.
		move.b	d3,d1

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB4F - BIT 1, A - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB4F:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#1,d3
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		50 - LD D, B
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_50:	move.b	d0,d7
		subq.l	#1,a5					;less cycles.
		move.w	d1,d0
		move.b	d7,d0

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB50 - BIT 2, B - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB50:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#10,d1
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		51 - LD D, C
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_51:	ror.w	#8,d0
		subq.l	#1,a5					;less cycles.
		move.b	d1,d0
		rol.w	#8,d0

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB51 - BIT 2, C - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB51:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#2,d1
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		52 - LD D, D
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_52:	subq.l	#1,a5					;less cycles.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB52 - BIT 2, D - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB52:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#10,d0
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		53 - LD D, E
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_53:	move.b	d0,d7
		subq.l	#1,a5					;less cycles.
		lsl.w	#8,d0
		move.b	d7,d0

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB53 - BIT 2, E - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB53:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#2,d0
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		54 - LD D, H
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_54:	move.b	d0,d7
		subq.l	#1,a5					;less cycles.
		move.w	d2,d0
		move.b	d7,d0

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB54 - BIT 2, H - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB54:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#10,d2
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		55 - LD D, L
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_55:	ror.w	#8,d0
		subq.l	#1,a5					;less cycles.
		move.b	d2,d0
		rol.w	#8,d0

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB55 - BIT 2, L - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB55:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#2,d2
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		56 - LD D, (HL)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_56:	ror.w	#8,d0					;d down.
		subq.l	#2,a5					;less cycles.

		tst.w	d2					;rom read?
		blt.s	cread_d2_to_d0a				;nope. from ram!
		move.b	(a3,d2.l),d0
		rol.w	#8,d0					;d back to up.
	
		fetch_next_i
		cnop	0,4

cread_d2_to_d0a:	GBC_RD	d2,d0				;ram read.
		rol.w	#8,d0					;d back to up.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB56 - BIT 2, (HL) - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB56:	subq.l	#4,a5
		IFND	NO_CYCLES
		addq.l	#1,a5					;AmiGameBoy: BIT n,(HL) is 3.
		ENDC
		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		tst.w	d2					;rom read?
		blt.s	read_d2c_to_d7a				;nope. from ram!

		move.w	d4,CCR					;the status register.
		btst.b	#2,(a3,d2.l)
		move.w	CCR,d4					;status updated.

		fetch_next_i
		cnop	0,4

read_d2c_to_d7a:		GBC_BTST	2				;ram read.
		move.w	CCR,d4					;status updated.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		57 - LD D, A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_57:	ror.w	#8,d0
		subq.l	#1,a5					;less cycles.
		move.b	d3,d0
		rol.w	#8,d0

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB57 - BIT 2, A - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB57:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#2,d3
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		58 - LD E, B
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_58:	move.w	d1,d7
		subq.l	#1,a5					;less cycles.
		lsr.w	#8,d7
		move.b	d7,d0

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB58 - BIT 3, B - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB58:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#11,d1
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		59 - LD E, C
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_59:	move.b	d1,d0
		subq.l	#1,a5					;less cycles.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB59 - BIT 3, C - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB59:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#3,d1
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		5A - LD E, D
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_5A:	move.w	d0,d7
		subq.l	#1,a5					;less cycles.
		lsr.w	#8,d7
		move.b	d7,d0

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB5A - BIT 3, D - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB5A:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#11,d0
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		5B - LD E, E
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_5B:	subq.l	#1,a5					;less cycles.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB5B - BIT 3, E - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB5B:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#3,d0
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		5C - LD E, H
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_5C:	move.w	d2,d7
		subq.l	#1,a5					;less cycles.
		lsr.w	#8,d7
		move.b	d7,d0

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB5C - BIT 3, H - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB5C:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#11,d2
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		5D - LD E, L
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_5D:	subq.l	#1,a5					;less cycles.
		move.b	d2,d0

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB5D - BIT 3, L - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB5D:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#3,d2
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		5E - LD E, (HL)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_5E:	subq.l	#2,a5					;less cycles.

		tst.w	d2					;rom read?
		blt.s	dread_d2_to_d0a				;nope. from ram!
		move.b	(a3,d2.l),d0

		fetch_next_i
		cnop	0,4

dread_d2_to_d0a:	GBC_RD	d2,d0				;ram read.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB5E - BIT 3, (HL) - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB5E:	subq.l	#4,a5
		IFND	NO_CYCLES
		addq.l	#1,a5					;AmiGameBoy: BIT n,(HL) is 3.
		ENDC
		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		tst.w	d2					;rom read?
		blt.s	read_d2d_to_d7a				;nope. from ram!

		move.w	d4,CCR					;the status register.
		btst.b	#3,(a3,d2.l)
		move.w	CCR,d4					;status updated.

		fetch_next_i
		cnop	0,4

read_d2d_to_d7a:		GBC_BTST	3				;ram read.
		move.w	CCR,d4					;status updated.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		5F - LD E, A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_5F:	subq.l	#1,a5					;less cycles.
		move.b	d3,d0					;e = a.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB5F - BIT 3, A - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB5F:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#3,d3
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		60 - LD H, B
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_60:	move.b	d2,d7
		subq.l	#1,a5					;less cycles.
		move.w	d1,d2
		move.b	d7,d2

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB60 - BIT 4, B - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB60:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#12,d1
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		61 - LD H, C
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_61:	ror.w	#8,d2
		subq.l	#1,a5					;less cycles.
		move.b	d1,d2
		rol.w	#8,d2

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB61 - BIT 4, C - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB61:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#4,d1
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		62 - LD H, D
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_62:	move.b	d2,d7
		subq.l	#1,a5					;less cycles.
		move.w	d0,d2
		move.b	d7,d2

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB62 - BIT 4, D - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB62:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#12,d0
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		63 - LD H, E
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_63:	ror.w	#8,d2					;h down.
		subq.l	#1,a5					;less cycles.
		move.b	d0,d2					;h = e.
		rol.w	#8,d2					;h back to up.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB63 - BIT 4, E - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB63:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#4,d0
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		64 - LD H, H
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_64:	subq.l	#1,a5					;less cycles.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB64 - BIT 4, H - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB64:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#12,d2
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		65 - LD H, L
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_65:	move.b	d2,d7
		subq.l	#1,a5					;less cycles.
		lsl.w	#8,d2
		move.b	d7,d2

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB65 - BIT 4, L - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB65:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#4,d2
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		66 - LD H, (HL)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_66:	move.w	d2,d7					;d7 = h.B, l.B.
		subq.l	#2,a5					;less cycles.
		ror.w	#8,d2					;h down.

		tst.w	d7
		blt.s	read_d7_to_d2a				;nope. from ram!
		move.b	(a3,d7.l),d2
		rol.w	#8,d2					;h back to up.

		fetch_next_i
		cnop	0,4

read_d7_to_d2a:	GBC_RD	d7,d2				;ram read.
		rol.w	#8,d2					;h back to up.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB66 - BIT 4, (HL) - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB66:	subq.l	#4,a5
		IFND	NO_CYCLES
		addq.l	#1,a5					;AmiGameBoy: BIT n,(HL) is 3.
		ENDC
		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		tst.w	d2					;rom read?
		blt.s	read_d2e_to_d7a				;nope. from ram!

		move.w	d4,CCR					;the status register.
		btst.b	#4,(a3,d2.l)
		move.w	CCR,d4					;status updated.

		fetch_next_i
		cnop	0,4

read_d2e_to_d7a:		GBC_BTST	4				;ram read.
		move.w	CCR,d4					;status updated.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		67 - LD H, A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_67:	ror.w	#8,d2
		subq.l	#1,a5					;less cycles.
		move.b	d3,d2
		rol.w	#8,d2

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB67 - BIT 4, A - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB67:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#4,d3
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		68 - LD L, B
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_68:	move.w	d1,d7
		subq.l	#1,a5					;less cycles.
		lsr.w	#8,d7
		move.b	d7,d2

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB68 - BIT 5, B - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB68:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#13,d1
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		69 - LD L, C
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_69:	subq.l	#1,a5					;less cycles.
		move.b	d1,d2

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB69 - BIT 5, C - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB69:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#5,d1
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		6A - LD L, D
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_6A:	move.w	d0,d7
		subq.l	#1,a5					;less cycles.
		lsr.w	#8,d7
		move.b	d7,d2

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB6A - BIT 5, D - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB6A:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#13,d0
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		6B - LD L, E
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_6B:	subq.l	#1,a5					;less cycles.
		move.b	d0,d2

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB6B - BIT 5, E - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB6B:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#5,d0
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		6C - LD L, H
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_6C:	move.w	d2,d7
		subq.l	#1,a5					;less cycles.
		lsr.w	#8,d7
		move.b	d7,d2

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB6C - BIT 5, H - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB6C:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#13,d2
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		6D - LD L, L
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_6D:	subq.l	#1,a5					;less cycles.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB6D - BIT 5, L - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB6D:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#5,d2
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		6E - LD L, (HL)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_6E:	subq.l	#2,a5					;less cycles.

		tst.w	d2					;rom read?
		blt.s	read_d2_to_d2a				;nope. from ram!
		move.b	(a3,d2.l),d2

		fetch_next_i
		cnop	0,4

read_d2_to_d2a:	GBC_RD	d2,d2				;ram read.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB6E - BIT 5, (HL) - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB6E:	subq.l	#4,a5
		IFND	NO_CYCLES
		addq.l	#1,a5					;AmiGameBoy: BIT n,(HL) is 3.
		ENDC
		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		tst.w	d2					;rom read?
		blt.s	read_d2f_to_d7a				;nope. from ram!

		move.w	d4,CCR					;the status register.
		btst.b	#5,(a3,d2.l)
		move.w	CCR,d4					;status updated.

		fetch_next_i
		cnop	0,4

read_d2f_to_d7a:		GBC_BTST	5				;ram read.
		move.w	CCR,d4					;status updated.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		6F - LD L, A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_6F:	subq.l	#1,a5					;less cycles.
		move.b	d3,d2					;l = a.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB6F - BIT 5, A - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB6F:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#5,d3
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		70 - LD (HL), B
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_70:	move.w	d1,d6
		move.w	d2,d7
		lsr.w	#8,d6
		move.l	gb_mem_jumps,a6
		subq.l	#2,a5
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB70 - BIT 6, B - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB70:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#14,d1
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		71 - LD (HL), C
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_71:	move.b	d1,d6
		move.w	d2,d7
		move.l	gb_mem_jumps,a6
		subq.l	#2,a5
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB71 - BIT 6, C - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB71:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#6,d1
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		72 - LD (HL), D
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_72:	move.w	d0,d6
		move.w	d2,d7
		lsr.w	#8,d6
		move.l	gb_mem_jumps,a6
		subq.l	#2,a5
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB72 - BIT 6, D - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB72:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#14,d0
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		73 - LD (HL), E
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_73:	move.w	d2,d7
		move.b	d0,d6
		move.l	gb_mem_jumps,a6
		subq.l	#2,a5
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB73 - BIT 6, E - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB73:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#6,d0
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		74 - LD (HL), H
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_74:	move.w	d2,d6
		move.w	d2,d7
		lsr.w	#8,d6
		move.l	gb_mem_jumps,a6
		subq.l	#2,a5
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB74 - BIT 6, H - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB74:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#14,d2
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		75 - LD (HL), L
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_75:	move.w	d2,d7
		move.b	d2,d6
		move.l	gb_mem_jumps,a6
		subq.l	#2,a5
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB75 - BIT 6, L - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB75:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#6,d2
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		76 - HALT
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_76:	subq.l	#1,a5
		tst.b	i_flag
		bne.s	z80_optcode_76_skip

		IFND	NO_HALTPEND
		move.l	a2,a6					;AmiGameBoy: an interrupt
		add.l	#$ff00,a6				;already pending (IF&IE):
		move.b	$0f(a6),d6				;no halt, dispatch now
		and.b	$ff(a6),d6				;(Wzonka halted to the next
		and.b	#%11111,d6				;sweep boundary).
		beq.s	z80_optcode_76_halt
		bra.l	reti_back
z80_optcode_76_halt:
		ENDC
		move.b	#2,z80_halt				;z80 stopped!
		rts

		cnop	0,4
z80_optcode_76_skip:
		IFND	NO_HALTWAIT
		move.l	a2,a6					;AmiGameBoy: IME=0 and no
		add.l	#$ff00,a6				;interrupt pending (IF&IE):
		move.b	$0f(a6),d6				;the CPU halts until one is
		and.b	$ff(a6),d6				;(the main loop wakes it, no
		and.b	#%11111,d6				;dispatch). Pending already:
		bne.s	z80_optcode_76_bug			;the halt bug.
		move.b	#2,z80_halt
		rts
z80_optcode_76_bug:
		ENDC
		move.l	a5,d6					;test cycles left.
		ble.s	f_xit_xit

		IFGT	GAMEBOY_DEBUG
		jmp	debug_output
		ELSE
		move.b	(a0),d7
		lsl.w	#8,d7					;d0 = d0*256.
		IFD	SPIKE_TRACE
		jmp	spike_trace				;AmiGameBoy: stage 0 trace.
		ELSE
		jmp	(a1,d7.l)				;jump and emulate.
		ENDC
		ENDIF

		cnop	0,4
f_xit_xit:	rts

		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB76 - BIT 6, (HL) - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB76:	subq.l	#4,a5
		IFND	NO_CYCLES
		addq.l	#1,a5					;AmiGameBoy: BIT n,(HL) is 3.
		ENDC
		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		tst.w	d2					;rom read?
		blt.s	read_d2g_to_d7a				;nope. from ram!

		move.w	d4,CCR					;the status register.
		btst.b	#6,(a3,d2.l)
		move.w	CCR,d4					;status updated.

		fetch_next_i
		cnop	0,4

read_d2g_to_d7a:		GBC_BTST	6				;ram read.
		move.w	CCR,d4					;status updated.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		77 - LD (HL), A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_77:	move.w	d2,d7
		move.b	d3,d6
		move.l	gb_mem_jumps,a6
		subq.l	#2,a5
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB77 - BIT 6, A - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB77:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#6,d3
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		78 - LD A, B
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_78:	move.w	d1,d7
		subq.l	#1,a5					;less cycles.
		lsr.w	#8,d7
		move.b	d7,d3

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB78 - BIT 7, B - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB78:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#15,d1
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		79 - LD A, C
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_79:	subq.l	#1,a5					;less cycles.
		move.b	d1,d3

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB79 - BIT 7, C - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB79:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#7,d1
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		7A - LD A, D
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_7A:	move.w	d0,d7
		subq.l	#1,a5					;less cycles.
		lsr.w	#8,d7
		move.b	d7,d3

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB7A - BIT 7, D - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB7A:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#15,d0
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		7B - LD A, E
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_7B:	subq.l	#1,a5					;less cycles.
		move.b	d0,d3

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB7B - BIT 7, E - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB7B:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#7,d0
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		7C - LD A, H
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_7C:	move.w	d2,d7
		subq.l	#1,a5					;less cycles.
		lsr.w	#8,d7
		move.b	d7,d3

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB7C - BIT 7, H - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB7C:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#15,d2
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		7D - LD A, L
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_7D:	subq.l	#1,a5					;less cycles.
		move.b	d2,d3

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB7D - BIT 7, L - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB7D:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#7,d2
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		7E - LD A, (HL)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_7E:	subq.l	#2,a5					;less cycles.

		tst.w	d2					;rom read?
		blt.s	read_d2_to_d3a3				;nope. from ram!

		move.b	(a3,d2.l),d3

		fetch_next_i
		cnop	0,4

read_d2_to_d3a3:	GBC_RD	d2,d3				;ram read.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB7E - BIT 7, (HL) - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB7E:	subq.l	#4,a5
		IFND	NO_CYCLES
		addq.l	#1,a5					;AmiGameBoy: BIT n,(HL) is 3.
		ENDC
		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		tst.w	d2					;rom read?
		blt.s	read_d2h_to_d7a				;nope. from ram!

		move.w	d4,CCR					;the status register.
		btst.b	#7,(a3,d2.l)
		move.w	CCR,d4					;status updated.

		fetch_next_i
		cnop	0,4

read_d2h_to_d7a:		GBC_BTST	7				;ram read.
		move.w	CCR,d4					;status updated.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		7F - LD A, A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_7F:	subq.l	#1,a5					;less cycles.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB7F - BIT 7, A - [n = 0, h = 1, c = c, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB7F:	subq.l	#2,a5					;less cycles.
		move.w	d4,CCR					;the status register.
		btst	#7,d3
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		80 - ADD B - [n = 0, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_80:	ror.w	#8,d1
		move.b	d3,h_other_I
		subq.l	#1,a5
		move.b	d1,h_other_II

		add.b	d1,d3
		move.w	CCR,d4
		rol.w	#8,d1

		move.w	#$0002,h_with_carry			;no carry! h = x!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB80 - RES 0, B
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB80:	subq.l	#2,a5					;less cycles.
		and.w	#%1111111011111111,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		81 - ADD C - [n = 0, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_81:	move.b	d1,h_other_II
		subq.l	#1,a5					;less cycles.
		move.b	d3,h_other_I

		add.b	d1,d3					;a = a + c.
		move.w	CCR,d4					;status updated.

		move.w	#$0002,h_with_carry			;no carry! h = x!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB81 - RES 0, C
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB81:	subq.l	#2,a5					;less cycles.
		and.b	#%11111110,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		82 - ADD D - [n = 0, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_82:	ror.w	#8,d0					;d down.
		move.b	d3,h_other_I
		subq.l	#1,a5					;less cycles.
		move.b	d0,h_other_II

		add.b	d0,d3					;a = a + d.
		move.w	CCR,d4					;status updated.
		rol.w	#8,d0					;d back to up.

		move.w	#$0002,h_with_carry			;no carry! h = x!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB82 - RES 0, D
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB82:	subq.l	#2,a5					;less cycles.
		and.w	#%1111111011111111,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		83 - ADD E - [n = 0, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_83:	move.b	d0,h_other_II
		subq.l	#1,a5					;less cycles.
		move.b	d3,h_other_I

		add.b	d0,d3					;a = a + e.
		move.w	CCR,d4					;status updated.

		move.w	#$0002,h_with_carry			;no carry! h = x!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB83 - RES 0, E
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB83:	subq.l	#2,a5					;less cycles.
		and.b	#%11111110,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		84 - ADD H - [n = 0, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_84:	ror.w	#8,d2					;h down.
		move.b	d3,h_other_I
		subq.l	#1,a5					;less cycles.
		move.b	d2,h_other_II

		add.b	d2,d3					;a = a + h.
		move.w	CCR,d4					;status updated.
		rol.w	#8,d2					;h back to up.

		move.w	#$0002,h_with_carry			;no carry! h = x!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB84 - RES 0, H
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB84:	subq.l	#2,a5					;less cycles.
		and.w	#%1111111011111111,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		85 - ADD L - [n = 0, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_85:	move.b	d2,h_other_II
		subq.l	#1,a5					;less cycles.
		move.b	d3,h_other_I

		add.b	d2,d3					;a = a + l.
		move.w	CCR,d4					;status updated.

		move.w	#$0002,h_with_carry			;no carry! h = x!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB85 - RES 0, L
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB85:	subq.l	#2,a5					;less cycles.
		and.b	#%11111110,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		86 - ADD (HL) - [n = 0, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_86:	
		READ_D2_TO_D6

		move.b	d3,h_other_I
		subq.l	#2,a5					;less cycles.
		move.b	d6,h_other_II

		add.b	d6,d3					;a = a + (hl).
		move.w	CCR,d4					;status updated.

		move.w	#$0002,h_with_carry			;no carry! h = x!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB86 - RES 0, (HL)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB86:	subq.l	#4,a5
		READ_D2_TO_D6
		and.b	#%11111110,d6
		move.w	d2,d7					;d7 = a (hl) - write.

		move.l	gb_mem_jumps,a6
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		87 - ADD A - [n = 0, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_87:	move.b	d3,h_other_II
		subq.l	#1,a5					;less cycles.
		move.b	d3,h_other_I

		add.b	d3,d3					;a = a + a.
		move.w	CCR,d4					;status updated.

		move.w	#$0002,h_with_carry			;no carry! h = x!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB87 - RES 0, A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB87:	subq.l	#2,a5					;less cycles.
		and.b	#%11111110,d3
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		88 - ADC B - [n = 0, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_88:	btst	#0,d4					;carry?
		beq.w	z80_optcode_80				;normal add.

		move.b	d3,h_other_I
		ror.w	#8,d1					;b down.
		subq.l	#1,a5					;less cycles.
		move.b	d1,h_other_II

		move.w	#%10000,CCR				;x = 1!
		addx.b	d1,d3					;a = a + b + c.
		move.w	CCR,d4					;status updated.

		rol.w	#8,d1					;b back to up.
		move.w	#$0102,h_with_carry			;yes carry! h = x!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB88 - RES 1, B
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB88:	subq.l	#2,a5					;less cycles.
		and.w	#%1111110111111111,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		89 - ADC C - [n = 0, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_89:	btst	#0,d4					;carry?
		beq.w	z80_optcode_81				;normal add.

		move.b	d3,h_other_I
		subq.l	#1,a5					;less cycles.
		move.b	d1,h_other_II

		move.w	#%10000,CCR				;x = 1!
		addx.b	d1,d3					;a = a + c + c.
		move.w	CCR,d4					;status updated.

		move.w	#$0102,h_with_carry			;yes carry! h = x!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB89 - RES 1, C
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB89:	subq.l	#2,a5					;less cycles.
		and.b	#%11111101,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		8A - ADC D - [n = 0, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_8A:	btst	#0,d4					;carry?
		beq.w	z80_optcode_82				;normal add.

		move.b	d3,h_other_I
		ror.w	#8,d0					;d down.
		subq.l	#1,a5					;less cycles.
		move.b	d0,h_other_II

		move.w	#%10000,CCR				;x = 1!
		addx.b	d0,d3					;a = a + d + c.
		move.w	CCR,d4					;status updated.

		rol.w	#8,d0					;d back to up.
		move.w	#$0102,h_with_carry			;yes carry! h = x!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB8A - RES 1, D
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB8A:	subq.l	#2,a5					;less cycles.
		and.w	#%1111110111111111,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		8B - ADC E - [n = 0, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_8B:	btst	#0,d4					;carry?
		beq.w	z80_optcode_83				;normal add.

		move.b	d3,h_other_I
		subq.l	#1,a5					;less cycles.
		move.b	d0,h_other_II

		move.w	#%10000,CCR				;x = 1!
		addx.b	d0,d3					;a = a + e + c.
		move.w	CCR,d4					;status updated.

		move.w	#$0102,h_with_carry			;yes carry! h = x!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB8B - RES 1, E
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB8B:	subq.l	#2,a5					;less cycles.
		and.b	#%11111101,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		8C - ADC H - [n = 0, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_8C:	btst	#0,d4					;carry?
		beq.w	z80_optcode_84				;normal add.

		move.b	d3,h_other_I
		ror.w	#8,d2					;h down.
		subq.l	#1,a5					;less cycles.
		move.b	d2,h_other_II

		move.w	#%10000,CCR				;x = 1!
		addx.b	d2,d3					;a = a + h + c.
		move.w	CCR,d4					;status updated.

		rol.w	#8,d2					;h back to up.
		move.w	#$0102,h_with_carry			;yes carry! h = x!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB8C - RES 1, H
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB8C:	subq.l	#2,a5					;less cycles.
		and.w	#%1111110111111111,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		8D - ADC L - [n = 0, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_8D:	btst	#0,d4					;carry?
		beq.w	z80_optcode_85				;normal add.

		move.b	d3,h_other_I
		subq.l	#1,a5					;less cycles.
		move.b	d2,h_other_II

		move.w	#%10000,CCR				;x = 1!
		addx.b	d2,d3					;a = a + l + c.
		move.w	CCR,d4					;status updated.

		move.w	#$0102,h_with_carry			;yes carry! h = x!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB8D - RES 1, L
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB8D:	subq.l	#2,a5					;less cycles.
		and.b	#%11111101,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		8E - ADC (HL) - [n = 0, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_8E:	btst	#0,d4					;carry?
		beq.w	z80_optcode_86				;normal add.

		READ_D2_TO_D6

		move.b	d3,h_other_I
		subq.l	#2,a5					;less cycles.
		move.b	d6,h_other_II

		move.w	#%10000,CCR				;x = 1!
		addx.b	d6,d3					;a = a + d + c.
		move.w	CCR,d4					;status updated.

		move.w	#$0102,h_with_carry			;yes carry! h = x!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB8E - RES 1, (HL)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB8E:	subq.l	#4,a5
		READ_D2_TO_D6
		and.b	#%11111101,d6
		move.w	d2,d7					;d7 = a (hl) - write.

		move.l	gb_mem_jumps,a6
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		8F - ADC A - [n = 0, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_8F:	btst	#0,d4					;carry?
		beq.w	z80_optcode_87				;normal add.

		move.b	d3,h_other_I
		subq.l	#1,a5					;less cycles.
		move.b	d3,h_other_II

		move.w	#%10000,CCR				;x = 1!
		addx.b	d3,d3					;a = a + d + c.
		move.w	CCR,d4					;status updated.

		move.w	#$0102,h_with_carry			;yes carry! h = x!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB8F - RES 1, A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB8F:	subq.l	#2,a5					;less cycles.
		and.b	#%11111101,d3
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		90 - SUB B - [n = 1, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_90:	move.b	d3,h_other_I
		ror.w	#8,d1					;b down.
		subq.l	#1,a5					;less cycles.
		move.b	d1,h_other_II

		sub.b	d1,d3					;a = a - b.
		move.w	CCR,d4					;status updated.
		rol.w	#8,d1					;b back to up.

		move.w	#$0002,h_with_carry			;no carry! h = x!
		or.w	#$100,d3				;n = 1!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB90 - RES 2, B
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB90:	subq.l	#2,a5					;less cycles.
		and.w	#%1111101111111111,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		91 - SUB C - [n = 1, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_91:	move.b	d1,h_other_II
		or.w	#$100,d3				;n = 1!
		subq.l	#1,a5					;less cycles.
		move.b	d3,h_other_I

		sub.b	d1,d3					;a = a - c.
		move.w	CCR,d4					;status updated.

		move.w	#$0002,h_with_carry			;no carry! h = x!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB91 - RES 2, C
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB91:	subq.l	#2,a5					;less cycles.
		and.b	#%11111011,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		92 - SUB D - [n = 1, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_92:	move.b	d3,h_other_I
		ror.w	#8,d0					;d down.
		subq.l	#1,a5					;less cycles.
		move.b	d0,h_other_II

		sub.b	d0,d3					;a = a - d.
		move.w	CCR,d4					;status updated.

		rol.w	#8,d0					;d back to up.
		move.w	#$0002,h_with_carry			;no carry! h = x!
		or.w	#$100,d3				;n = 1!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB92 - RES 2, D
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB92:	subq.l	#2,a5					;less cycles.
		and.w	#%1111101111111111,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		93 - SUB E - [n = 1, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_93:	move.b	d3,h_other_I
		subq.l	#1,a5					;less cycles.
		or.w	#$100,d3				;n = 1!
		move.b	d0,h_other_II

		sub.b	d0,d3					;a = a - e.
		move.w	CCR,d4					;status updated.

		move.w	#$0002,h_with_carry			;no carry! h = x!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB93 - RES 2, E
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB93:	subq.l	#2,a5					;less cycles.
		and.b	#%11111011,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		94 - SUB H - [n = 1, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_94:	move.b	d3,h_other_I
		ror.w	#8,d2					;h down.
		subq.l	#1,a5					;less cycles.
		move.b	d2,h_other_II

		sub.b	d2,d3					;a = a - h.
		move.w	CCR,d4					;status updated.

		rol.w	#8,d2					;h back to up.
		move.w	#$0002,h_with_carry			;no carry! h = x!
		or.w	#$100,d3				;n = 1!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB94 - RES 2, H
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB94:	subq.l	#2,a5					;less cycles.
		and.w	#%1111101111111111,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		95 - SUB L - [n = 1, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_95:	move.b	d3,h_other_I
		subq.l	#1,a5					;less cycles.
		or.w	#$100,d3				;n = 1!
		move.b	d2,h_other_II

		sub.b	d2,d3					;a = a - l.
		move.w	CCR,d4					;status updated.

		move.w	#$0002,h_with_carry			;no carry! h = x!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB95 - RES 2, L
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB95:	subq.l	#2,a5					;less cycles.
		and.b	#%11111011,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		96 - SUB (HL) - [n = 1, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_96:
		READ_D2_TO_D6

		move.b	d3,h_other_I
		subq.l	#2,a5
		or.w	#$100,d3				;n = 1!
		move.b	d6,h_other_II

		sub.b	d6,d3					;a = a - (hl).
		move.w	CCR,d4					;status updated.

		move.w	#$0002,h_with_carry			;no carry! h = x!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB96 - RES 2, (HL)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB96:	subq.l	#4,a5
		READ_D2_TO_D6
		and.b	#%11111011,d6
		move.w	d2,d7					;d7 = a (hl) - write.

		move.l	gb_mem_jumps,a6
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		97 - SUB A - [n = 1, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_97:	move.b	d3,h_other_I
		subq.l	#1,a5					;less cycles.
		move.b	d3,h_other_II

		sub.b	d3,d3					;a = a - a (=0).
		move.w	CCR,d4					;status updated.

		move.w	#$0002,h_with_carry			;no carry! h = x!
		or.w	#$100,d3				;n = 1!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB97 - RES 2, A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB97:	subq.l	#2,a5					;less cycles.
		and.b	#%11111011,d3
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		98 - SBC B - [n = 1, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_98:	btst	#0,d4					;c = 0?
		beq.w	z80_optcode_90				;yes. normal sub.

		move.b	d3,h_other_I
		ror.w	#8,d1					;b down.
		subq.l	#1,a5					;less cycles.
		move.b	d1,h_other_II

		move.w	#%10000,CCR				;x = 1!
		subx.b	d1,d3					;a = a - b - c.
		move.w	CCR,d4					;status updated.

		rol.w	#8,d1					;b back to up.
		move.w	#$0102,h_with_carry			;yes carry! h = x!
		or.w	#$100,d3				;n = 1!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB98 - RES 3, B
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB98:	subq.l	#2,a5					;less cycles.
		and.w	#%1111011111111111,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		99 - SBC C - [n = 1, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_99:	btst	#0,d4					;c = 0?
		beq.w	z80_optcode_91				;yes. normal sub.

		move.b	d3,h_other_I
		subq.l	#1,a5					;less cycles.
		move.b	d1,h_other_II

		move.w	#%10000,CCR				;x = 1!
		subx.b	d1,d3					;a = a - c - c.
		move.w	CCR,d4					;status updated.

		move.w	#$0102,h_with_carry			;yes carry! h = x!
		or.w	#$100,d3				;n = 1!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB99 - RES 3, C
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB99:	subq.l	#2,a5					;less cycles.
		and.b	#%11110111,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		9A - SBC D - [n = 1, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_9A:	btst	#0,d4					;c = 0?
		beq.w	z80_optcode_92				;yes. normal sub.

		move.b	d3,h_other_I
		ror.w	#8,d0					;d down.
		subq.l	#1,a5					;less cycles.
		move.b	d0,h_other_II

		move.w	#%10000,CCR				;x = 1!
		subx.b	d0,d3					;a = a - d - c.
		move.w	CCR,d4					;status updated.

		rol.w	#8,d0					;d back to up.
		move.w	#$0102,h_with_carry			;yes carry! h = x!
		or.w	#$100,d3				;n = 1!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB9A - RES 3, D
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB9A:	subq.l	#2,a5					;less cycles.
		and.w	#%1111011111111111,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		9B - SBC E - [n = 1, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_9B:	btst	#0,d4					;c = 0?
		beq.w	z80_optcode_93				;yes. normal sub.

		move.b	d3,h_other_I
		subq.l	#1,a5					;less cycles.
		move.b	d0,h_other_II

		move.w	#%10000,CCR				;x = 1!
		subx.b	d0,d3					;a = a - e - c.
		move.w	CCR,d4					;status updated.

		move.w	#$0102,h_with_carry			;yes carry! h = x!
		or.w	#$100,d3				;n = 1!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB9B - RES 3, E
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB9B:	subq.l	#2,a5					;less cycles.
		and.b	#%11110111,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		9C - SBC H - [n = 1, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_9C:	btst	#0,d4					;c = 0?
		beq.w	z80_optcode_94				;yes. normal sub.

		move.b	d3,h_other_I
		ror.w	#8,d2					;h down.
		subq.l	#1,a5					;less cycles.
		move.b	d2,h_other_II

		move.w	#%10000,CCR				;x = 1!
		subx.b	d2,d3					;a = a - h - c.
		move.w	CCR,d4					;status updated.

		rol.w	#8,d2					;h back to up.
		move.w	#$0102,h_with_carry			;yes carry! h = x!
		or.w	#$100,d3				;n = 1!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB9C - RES 3, H
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB9C:	subq.l	#2,a5					;less cycles.
		and.w	#%1111011111111111,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		9D - SBC L - [n = 1, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_9D:	btst	#0,d4					;c = 0?
		beq.w	z80_optcode_95				;yes. normal sub.

		move.b	d3,h_other_I
		subq.l	#1,a5					;less cycles.
		move.b	d2,h_other_II

		move.w	#%10000,CCR				;x = 1!
		subx.b	d2,d3					;a = a - l - c.
		move.w	CCR,d4					;status updated.

		move.w	#$0102,h_with_carry			;yes carry! h = x!
		or.w	#$100,d3				;n = 1!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB9D - RES 3, L
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB9D:	subq.l	#2,a5					;less cycles.
		and.b	#%11110111,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		9E - SBC (HL) - [n = 1, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_9E:	btst	#0,d4					;c = 0?
		beq.w	z80_optcode_96				;yes. normal sub.

		READ_D2_TO_D6

		move.b	d3,h_other_I
		subq.l	#2,a5					;less cycles.
		move.b	d6,h_other_II

		move.w	#%10000,CCR				;x = 1!
		subx.b	d6,d3					;a = a - (hl) - c.
		move.w	CCR,d4					;status updated.

		move.w	#$0102,h_with_carry			;yes carry! h = x!
		or.w	#$100,d3				;n = 1!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB9E - RES 3, (HL)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB9E:	subq.l	#4,a5
		READ_D2_TO_D6
		and.b	#%11110111,d6
		move.w	d2,d7					;d7 = a (hl) - write.

		move.l	gb_mem_jumps,a6
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		9F - SBC A - [n = 1, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_9F:	btst	#0,d4					;c = 0?
		beq.w	z80_optcode_97				;yes. normal sub.

		move.b	d3,h_other_I
		subq.l	#1,a5					;less cycles.
		move.b	d3,h_other_II

		move.w	#%10000,CCR				;x = 1!
		subx.b	d3,d3					;a = a - a - c.
		move.w	CCR,d4					;status updated.

		move.w	#$0102,h_with_carry			;yes carry! h = x!
		or.w	#$100,d3				;n = 1!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB9F - RES 3, A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CB9F:	subq.l	#2,a5					;less cycles.
		and.b	#%11110111,d3
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		A0 - AND B - [n = 0, h = 1, c = 0, z = x]
;		MC680x0 CLEARS THE CARRY FLAG ITSELF!
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_A0:	ror.w	#8,d1					;b down.
		subq.l	#1,a5					;less cycles.
		and.b	d1,d3
		move.w	CCR,d4					;status updated.
		rol.w	#8,d1					;b back to up.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBA0 - RES 4, B
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBA0:	subq.l	#2,a5					;less cycles.
		and.w	#%1110111111111111,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		A1 - AND C - [n = 0, h = 1, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_A1:	subq.l	#1,a5					;less cycles.
		and.b	d1,d3
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBA1 - RES 4, C
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBA1:	subq.l	#2,a5					;less cycles.
		and.b	#%11101111,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		A2 - AND D - [n = 0, h = 1, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_A2:	ror.w	#8,d0					;d down.
		subq.l	#1,a5					;less cycles.
		and.b	d0,d3
		move.w	CCR,d4					;status updated.
		rol.w	#8,d0					;d back to up.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBA2 - RES 4, D
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBA2:	subq.l	#2,a5					;less cycles.
		and.w	#%1110111111111111,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		A3 - AND E - [n = 0, h = 1, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_A3:	subq.l	#1,a5					;less cycles.
		and.b	d0,d3
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBA3 - RES 4, E
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBA3:	subq.l	#2,a5					;less cycles.
		and.b	#%11101111,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		A4 - AND H - [n = 0, h = 1, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_A4:	ror.w	#8,d2					;h down.
		subq.l	#1,a5					;less cycles.
		and.b	d2,d3
		move.w	CCR,d4					;status updated.
		rol.w	#8,d2					;h back to up.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBA4 - RES 4, H
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBA4:	subq.l	#2,a5					;less cycles.
		and.w	#%1110111111111111,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		A5 - AND L - [n = 0, h = 1, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_A5:	subq.l	#1,a5					;less cycles.
		and.b	d2,d3
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBA5 - RES 4, L
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBA5:	subq.l	#2,a5					;less cycles.
		and.b	#%11101111,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		A6 - AND (HL) - [n = 0, h = 1, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_A6:
		READ_D2_TO_D6
		subq.l	#2,a5					;less cycles.
		and.b	d6,d3
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBA6 - RES 4, (HL)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBA6:	subq.l	#4,a5
		READ_D2_TO_D6
		and.b	#%11101111,d6
		move.w	d2,d7					;d7 = a (hl) - write.

		move.l	gb_mem_jumps,a6
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		A7 - AND A - [n = 0, h = 1, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_A7:	subq.l	#1,a5					;less cycles.
		and.b	d3,d3
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBA7 - RES 4, A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBA7:	subq.l	#2,a5					;less cycles.
		and.b	#%11101111,d3
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		A8 - XOR B - [n = 0, h = 0, c = 0, z = x]
;		MC680x0 CLEARS THE CARRY FLAG ITSELF!
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_A8:	ror.w	#8,d1					;b down.
		subq.l	#1,a5					;less cycles.
		eor.b	d1,d3
		move.w	CCR,d4					;status updated.
		rol.w	#8,d1					;b back to up.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBA8 - RES 5, B
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBA8:	subq.l	#2,a5					;less cycles.
		and.w	#%1101111111111111,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		A9 - XOR C - [n = 0, h = 0, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_A9:	subq.l	#1,a5					;less cycles.
		eor.b	d1,d3
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBA9 - RES 5, C
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBA9:	subq.l	#2,a5					;less cycles.
		and.b	#%11011111,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		AA - XOR D - [n = 0, h = 0, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_AA:	ror.w	#8,d0					;d down.
		subq.l	#1,a5					;less cycles.
		eor.b	d0,d3
		move.w	CCR,d4					;status updated.
		rol.w	#8,d0					;d back to up.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBAA - RES 5, D
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBAA:	subq.l	#2,a5					;less cycles.
		and.w	#%1101111111111111,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		AB - XOR E - [n = 0, h = 0, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_AB:	subq.l	#1,a5					;less cycles.
		eor.b	d0,d3
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBAB - RES 5, E
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBAB:	subq.l	#2,a5					;less cycles.
		and.b	#%11011111,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		AC - XOR H - [n = 0, h = 0, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_AC:	ror.w	#8,d2					;h down.
		subq.l	#1,a5					;less cycles.
		eor.b	d2,d3
		move.w	CCR,d4					;status updated.
		rol.w	#8,d2					;h back to up.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBAC - RES 5, H
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBAC:	subq.l	#2,a5					;less cycles.
		and.w	#%1101111111111111,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		AD - XOR L - [n = 0, h = 0, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_AD:	subq.l	#1,a5					;less cycles.
		eor.b	d2,d3
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBAD - RES 5, L
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBAD:	subq.l	#2,a5					;less cycles.
		and.b	#%11011111,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		AE - XOR (HL) - [n = 0, h = 0, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_AE:
		READ_D2_TO_D6
		subq.l	#2,a5					;less cycles.
		eor.b	d6,d3
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBAE - RES 5, (HL)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBAE:	subq.l	#4,a5
		READ_D2_TO_D6
		and.b	#%11011111,d6
		move.w	d2,d7					;d7 = a (hl) - write.

		move.l	gb_mem_jumps,a6
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		AF - XOR A - [n = 0, h = 0, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_AF:	subq.l	#1,a5					;less cycles.
		eor.b	d3,d3
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBAF - RES 5, A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBAF:	subq.l	#2,a5					;less cycles.
		and.b	#%11011111,d3
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		B0 - OR B - [n = 0, h = 0, c = 0, z = x]
;		MC680x0 CLEARS THE CARRY FLAG ITSELF!
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_B0:	ror.w	#8,d1					;b down.
		subq.l	#1,a5					;less cycles.
		or.b	d1,d3
		move.w	CCR,d4					;status updated.
		rol.w	#8,d1					;b back to up.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBB0 - RES 6, B
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBB0:	subq.l	#2,a5					;less cycles.
		and.w	#%1011111111111111,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		B1 - OR C - [n = 0, h = 0, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_B1:	subq.l	#1,a5					;less cycles.
		or.b	d1,d3
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBB1 - RES 6, C
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBB1:	subq.l	#2,a5					;less cycles.
		and.b	#%10111111,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		B2 - OR D - [n = 0, h = 0, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_B2:	ror.w	#8,d0					;d down.
		subq.l	#1,a5					;less cycles.
		or.b	d0,d3
		move.w	CCR,d4					;status updated.
		rol.w	#8,d0					;d back to up.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBB2 - RES 6, D
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBB2:	subq.l	#2,a5					;less cycles.
		and.w	#%1011111111111111,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		B3 - OR E - [n = 0, h = 0, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_B3:	subq.l	#1,a5					;less cycles.
		or.b	d0,d3
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBB3 - RES 6, E
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBB3:	subq.l	#2,a5					;less cycles.
		and.b	#%10111111,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		B4 - OR H - [n = 0, h = 0, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_B4:	ror.w	#8,d2					;h down.
		subq.l	#1,a5
		or.b	d2,d3
		move.w	CCR,d4					;status updated.
		rol.w	#8,d2					;h back to up.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBB4 - RES 6, H
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBB4:	subq.l	#2,a5					;less cycles.
		and.w	#%1011111111111111,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		B5 - OR L - [n = 0, h = 0, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_B5:	subq.l	#1,a5
		or.b	d2,d3
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBB5 - RES 6, L
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBB5:	subq.l	#2,a5					;less cycles.
		and.b	#%10111111,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		B6 - OR (HL) - [n = 0, h = 0, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_B6:
		READ_D2_TO_D6
		subq.l	#2,a5
		or.b	d6,d3
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBB6 - RES 6, (HL)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBB6:	subq.l	#4,a5
		READ_D2_TO_D6
		and.b	#%10111111,d6
		move.w	d2,d7					;d7 = a (hl) - write.

		move.l	gb_mem_jumps,a6
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		B7 - OR A - [n = 0, h = 0, c = 0, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_B7:	subq.l	#1,a5
		or.b	d3,d3
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBB7 - RES 6, A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBB7:	subq.l	#2,a5					;less cycles.
		and.b	#%10111111,d3
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		B8 - CP B - [n = 1, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_B8:	move.b	d3,h_other_I
		ror.w	#8,d1					;b down.
		move.b	d1,h_other_II
		subq.l	#1,a5

		cmp.b	d1,d3
		move.w	CCR,d4					;status updated.

		rol.w	#8,d1					;b back to up.
		move.w	#$0002,h_with_carry			;no carry! h = x!
		or.w	#$100,d3				;n = 1!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBB8 - RES 7, B
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBB8:	subq.l	#2,a5					;less cycles.
		and.w	#%0111111111111111,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		B9 - CP C - [n = 1, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_B9:	move.b	d3,h_other_I
		subq.l	#1,a5
		move.b	d1,h_other_II
		or.w	#$100,d3				;n = 1!

		cmp.b	d1,d3
		move.w	CCR,d4					;status updated.

		move.w	#$0002,h_with_carry			;no carry! h = x!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBB9 - RES 7, C
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBB9:	subq.l	#2,a5					;less cycles.
		and.b	#%01111111,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		BA - CP D - [n = 1, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_BA:	move.b	d3,h_other_I
		ror.w	#8,d0					;d down.
		move.b	d0,h_other_II
		subq.l	#1,a5

		cmp.b	d0,d3
		move.w	CCR,d4					;status updated.

		rol.w	#8,d0					;d back to up.
		move.w	#$0002,h_with_carry			;no carry! h = x!
		or.w	#$100,d3				;n = 1!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBBA - RES 7, D
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBBA:	subq.l	#2,a5					;less cycles.
		and.w	#%0111111111111111,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		BB - CP E - [n = 1, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_BB:	move.b	d0,h_other_II
		subq.l	#1,a5
		move.b	d3,h_other_I

		cmp.b	d0,d3
		move.w	CCR,d4					;status updated.

		move.w	#$0002,h_with_carry			;no carry! h = x!
		or.w	#$100,d3				;n = 1!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBBB - RES 7, E
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBBB:	subq.l	#2,a5					;less cycles.
		and.b	#%01111111,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		BC - CP H - [n = 1, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_BC:	move.b	d3,h_other_I
		ror.w	#8,d2					;h down.
		move.b	d2,h_other_II
		subq.l	#1,a5

		cmp.b	d2,d3
		move.w	CCR,d4					;status updated.

		rol.w	#8,d2					;h back to up.
		move.w	#$0002,h_with_carry			;no carry! h = x!
		or.w	#$100,d3				;n = 1!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBBC - RES 7, H
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBBC:	subq.l	#2,a5					;less cycles.
		and.w	#%0111111111111111,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		BD - CP L - [n = 1, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_BD:	move.b	d2,h_other_II
		subq.l	#1,a5
		move.b	d3,h_other_I

		cmp.b	d2,d3
		move.w	CCR,d4					;status updated.

		move.w	#$0002,h_with_carry			;no carry! h = x!
		or.w	#$100,d3				;n = 1!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBBD - RES 7, L
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBBD:	subq.l	#2,a5					;less cycles.
		and.b	#%01111111,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		BE - CP (HL) - [n = 1, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_BE:	move.b	d3,h_other_I
		READ_D2_TO_D6
		move.b	d6,h_other_II
		subq.l	#2,a5

		cmp.b	d6,d3
		move.w	CCR,d4					;status updated.

		move.w	#$0002,h_with_carry			;no carry! h = x!
		or.w	#$100,d3				;n = 1!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBBE - RES 7, (HL)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBBE:	subq.l	#4,a5
		READ_D2_TO_D6
		and.b	#%01111111,d6
		move.w	d2,d7					;d7 = a (hl) - write.

		move.l	gb_mem_jumps,a6
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		BF - CP A - [n = 1, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_BF:	move.b	d3,h_other_I
		subq.l	#1,a5
		move.b	d3,h_other_II

		cmp.b	d3,d3
		move.w	CCR,d4					;status updated.

		move.w	#$0002,h_with_carry			;no carry! h = x!
		or.w	#$100,d3				;n = 1!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBBF - RES 7, A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBBF:	subq.l	#2,a5					;less cycles.
		and.b	#%01111111,d3
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		C0 - RET NZ
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_C0:	subq.l	#2,a5

		btst	#2,d4					;z - flag set?
		bne.s	z80_cpu_loop_c0				;yes. it's zero.

		READW_D5_TO_D7
		IFND	NO_CYCLES
		subq.l	#3,a5					;AmiGameBoy: RET cc taken is 5.
		ENDC
		addq.w	#2,d5
		ror.w	#8,d7
		blt.s	pc_in_ram_xi
		move.l	a3,z80_pc_base				;rom base.
		lea	(a3,d7.l),a0

z80_cpu_loop_c0:
		fetch_next_i
		cnop	0,4

pc_in_ram_xi:	move.l	a2,z80_pc_base				;ram base.
		lea	(a2,d7.l),a0

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBC0 - SET 0, B
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBC0:	subq.l	#2,a5					;less cycles.
		or.w	#%0000000100000000,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		C1 - POP BC
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_C1:	subq.l	#3,a5

		tst.w	d5					;rom read?
		blt.s	readw_d5_to_d1a				;nope. from ram!
		move.w	(a3,d5.l),d1
		addq.w	#2,d5					;sp = sp + 2.
		ror.w	#8,d1					;order correction.

		fetch_next_i
		cnop	0,4

readw_d5_to_d1a:move.w	(a2,d5.l),d1				;ram read.
		addq.w	#2,d5					;sp = sp + 2.
		ror.w	#8,d1					;order correction.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBC1 - SET 0, C
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBC1:	subq.l	#2,a5					;less cycles.
		or.b	#%1,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		C2 - JP NZ, xx
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_C2:	btst	#2,d4					;z - flag set?
		bne.s	z80_optcode_C2x				;yes. it's zero.

		move.w	(a0),d7
		subq.l	#3,a5
		IFND	NO_CYCLES
		subq.l	#1,a5					;AmiGameBoy: JP cc taken is 4.
		ENDC
		ror.w	#8,d7					;pc updated.
		blt.s	pc_in_ram_i
		move.l	a3,z80_pc_base				;rom base.
		lea	(a3,d7.l),a0

		fetch_next_i
		cnop	0,4

pc_in_ram_i:	move.l	a2,z80_pc_base				;ram base.
		lea	(a2,d7.l),a0

		fetch_next_i
		cnop	0,4

z80_optcode_C2x:addq.l	#2,a0					;no jump.
		subq.l	#3,a5

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBC2 - SET 0, D
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBC2:	subq.l	#2,a5					;less cycles.
		or.w	#%0000000100000000,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		C3 - JP xx
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_C3:	move.w	(a0),d7
		subq.l	#3,a5
		IFND	NO_CYCLES
		subq.l	#1,a5					;AmiGameBoy: JP is 4.
		ENDC
		ror.w	#8,d7					;pc updated.
		blt.s	pc_in_ram_ii
		move.l	a3,z80_pc_base				;rom base.
		lea	(a3,d7.l),a0

		fetch_next_i
		cnop	0,4

pc_in_ram_ii:	move.l	a2,z80_pc_base				;ram base.
		lea	(a2,d7.l),a0

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBC3 - SET 0, E
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBC3:	subq.l	#2,a5					;less cycles.
		or.b	#%1,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		C4 - CALL NZ, xx
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_C4:	btst	#2,d4					;z - flag set?
		bne.s	z80_optcode_C4x				;yes. it's zero.

		move.l	a0,d6
		sub.l	z80_pc_base,d6
		addq.w	#2,d6
                bsr.l   write_d6_stackx

		move.w	(a0),d7					;00BB.
		subq.l	#3,a5
		IFND	NO_CYCLES
		subq.l	#3,a5					;AmiGameBoy: CALL cc taken is 6.
		ENDC
		ror.w	#8,d7
		blt.s	pc_in_ram_vi
		move.l	a3,z80_pc_base				;rom base.
		lea	(a3,d7.l),a0

		fetch_next_i
		cnop	0,4

pc_in_ram_vi:	move.l	a2,z80_pc_base				;ram base.
		lea	(a2,d7.l),a0

		fetch_next_i
		cnop	0,4

z80_optcode_C4x:addq.l	#2,a0					;no jump.
		subq.l	#3,a5

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBC4 - SET 0, H
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBC4:	subq.l	#2,a5					;less cycles.
		or.w	#%0000000100000000,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		C5 - PUSH BC
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_C5:	subq.l	#4,a5
		move.w	d1,d6

		subq.w	#1,d5
		move.l	d6,-(SP)
		move.l	d5,d7
		move.l	gb_mem_jumps,a6
		lsr.w	#8,d6					;d1 = upper data (h.B).
		jsr	([a6,d5.l*4])				;memory write.

		move.l	(SP)+,d6
		subq.w	#1,d5
		move.l	gb_mem_jumps,a6
		move.l	d5,d7
		jsr	([a6,d5.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBC5 - SET 0, L
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBC5:	subq.l	#2,a5					;less cycles.
		or.b	#%1,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		C6 - ADD x - [n = 0, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_C6:	move.b	d3,h_other_I
		subq.l	#2,a5
		move.b	(a0)+,d7
		and.w	#$ff,d3					;n = 0!
		move.b	d7,h_other_II

		add.b	d7,d3					;a = a + x.
		move.w	CCR,d4					;status updated.

		move.w	#$0002,h_with_carry			;no carry! h = x!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBC6 - SET 0, (HL)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBC6:	subq.l	#4,a5
		move.l	gb_mem_jumps,a6

		move.w	d2,d7					;d7 = a (hl) - write.
		blt.s	pead_d2_to_d6a

		move.b	(a3,d2.l),d6				;rom.
		or.b	#%1,d6
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,4

pead_d2_to_d6a:	GBC_RD	d2,d6				;ram.
		or.b	#%1,d6
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		C7 - RST 0
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_C7:	move.l	a0,d6
		sub.l	z80_pc_base,d6
		bsr.l	write_d6_stackx

		move.l	a3,a0
		subq.l	#8,a5
		IFND	NO_CYCLES
		addq.l	#4,a5					;AmiGameBoy: RST is 4.
		ENDC
		move.l	a3,z80_pc_base

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBC7 - SET 0, A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBC7:	subq.l	#2,a5					;less cycles.
		or.b	#%1,d3
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		C8 - RET Z
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_C8:	subq.l	#2,a5

		btst	#2,d4					;z - flag set?
		beq.s	z80_cpu_loop_c8				;nope. it's non-zero.

		READW_D5_TO_D7
		IFND	NO_CYCLES
		subq.l	#3,a5					;AmiGameBoy: RET cc taken is 5.
		ENDC
		addq.w	#2,d5
		ror.w	#8,d7
		blt.s	pc_in_ram_xii
		move.l	a3,z80_pc_base				;rom base.
		lea	(a3,d7.l),a0

z80_cpu_loop_c8:
		fetch_next_i
		cnop	0,4

pc_in_ram_xii:	move.l	a2,z80_pc_base				;ram base.
		lea	(a2,d7.l),a0

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBC8 - SET 1, B
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBC8:	subq.l	#2,a5					;less cycles.
		or.w	#%0000001000000000,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		C9 - RET
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_C9:
		READW_D5_TO_D7
		subq.l	#2,a5					;less cycles.
		IFND	NO_CYCLES
		subq.l	#2,a5					;AmiGameBoy: RET is 4.
		ENDC
		addq.w	#2,d5
		ror.w	#8,d7
		blt.s	pc_in_ram_xvi
		move.l	a3,z80_pc_base				;rom base.
		lea	(a3,d7.l),a0

		fetch_next_i
		cnop	0,4

pc_in_ram_xvi:	move.l	a2,z80_pc_base				;ram base.
		lea	(a2,d7.l),a0

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBC9 - SET 1, C
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBC9:	subq.l	#2,a5					;less cycles.
		or.b	#%10,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CA - JP Z, xx
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_CA:	btst	#2,d4					;z - flag set?
		beq.s	z80_optcode_CAx				;nope. it's non-zero.

		move.w	(a0),d7
		subq.l	#3,a5
		IFND	NO_CYCLES
		subq.l	#1,a5					;AmiGameBoy: JP cc taken is 4.
		ENDC
		ror.w	#8,d7
		blt.s	pc_in_ram_iii
		move.l	a3,z80_pc_base				;rom base.
		lea	(a3,d7.l),a0

		fetch_next_i
		cnop	0,4

pc_in_ram_iii:	move.l	a2,z80_pc_base				;ram base.
		lea	(a2,d7.l),a0

		fetch_next_i
		cnop	0,4

z80_optcode_CAx:addq.l	#2,a0
		subq.l	#3,a5

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBCA - SET 1, D
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBCA:	subq.l	#2,a5					;less cycles.
		or.w	#%0000001000000000,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CB - RLC, RL, SLA, SRL, BIT, RES and SET
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_CB:	move.b	(a0)+,d7
		lsl.w	#8,d7
		jmp	(a4,d7.l)
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBCB - SET 1, E
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBCB:	subq.l	#2,a5					;less cycles.
		or.b	#%10,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CC - CALL Z, xx
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_CC:	btst	#2,d4					;z - flag set?
		beq.s	z80_optcode_CCx				;nope. it's non-zero.

		move.l	a0,d6
		sub.l	z80_pc_base,d6
		addq.w	#2,d6
                bsr.l   write_d6_stackx

		move.w	(a0),d7					;00BB.
		subq.l	#3,a5
		IFND	NO_CYCLES
		subq.l	#3,a5					;AmiGameBoy: CALL cc taken is 6.
		ENDC
		ror.w	#8,d7					;pc updated.
		blt.s	pc_in_ram_vii
		move.l	a3,z80_pc_base				;rom base.
		lea	(a3,d7.l),a0

		fetch_next_i
		cnop	0,4

pc_in_ram_vii:	move.l	a2,z80_pc_base				;ram base.
		lea	(a2,d7.l),a0

		fetch_next_i
		cnop	0,4

z80_optcode_CCx:addq.l	#2,a0					;no jump.
		subq.l	#3,a5

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBCC - SET 1, H
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBCC:	subq.l	#2,a5					;less cycles.
		or.w	#%0000001000000000,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CD - CALL xx
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_CD:	move.l	a0,d6
		sub.l	z80_pc_base,d6
		addq.w	#2,d6
                bsr.l   write_d6_stackx

		move.w	(a0),d7					;00BB.
		subq.l	#3,a5
		IFND	NO_CYCLES
		subq.l	#3,a5					;AmiGameBoy: CALL is 6.
		ENDC
		ror.w	#8,d7
		blt.s	pc_in_ram_viii
		move.l	a3,z80_pc_base				;rom base.
		lea	(a3,d7.l),a0

		fetch_next_i
		cnop	0,4

pc_in_ram_viii:	move.l	a2,z80_pc_base				;ram base.
		lea	(a2,d7.l),a0

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBCD - SET 1, L
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBCD:	subq.l	#2,a5					;less cycles.
		or.b	#%10,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CE - ADC x - [n = 0, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_CE:	btst	#0,d4					;c = 0?
		beq.w	z80_optcode_C6				;yes. normal add.

		move.b	(a0)+,d6
		move.b	d3,h_other_I
		subq.l	#2,a5					;less cycles.
		and.w	#$ff,d3					;n = 0!
		move.b	d6,h_other_II

		move.w	#%10000,CCR				;x = 1!
		addx.b	d6,d3					;a = a + c + c.
		move.w	CCR,d4					;status updated.

		move.w	#$0102,h_with_carry			;yes carry! h = x!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBCE - SET 1, (HL)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBCE:	subq.l	#4,a5
		move.l	gb_mem_jumps,a6

		move.w	d2,d7					;d7 = a (hl) - write.
		blt.s	lead_d2_to_d6a

		move.b	(a3,d2.l),d6
		or.b	#%10,d6
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,4

lead_d2_to_d6a:	GBC_RD	d2,d6				;ram.
		or.b	#%10,d6
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CF - RST 8
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_CF:	move.l	a0,d6
		sub.l	z80_pc_base,d6
		bsr.l	write_d6_stackx

		lea	$8(a3),a0
		subq.l	#8,a5
		IFND	NO_CYCLES
		addq.l	#4,a5					;AmiGameBoy: RST is 4.
		ENDC
		move.l	a3,z80_pc_base

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBCF - SET 1, A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBCF:	subq.l	#2,a5					;less cycles.
		or.b	#%10,d3
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		D0 - RET NC
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_D0:	subq.l	#2,a5

		btst	#0,d4					;c - flag set?
		bne.s	z80_cpu_loop_d0				;yes. no jump.

		READW_D5_TO_D7
		IFND	NO_CYCLES
		subq.l	#3,a5					;AmiGameBoy: RET cc taken is 5.
		ENDC
		addq.w	#2,d5
		ror.w	#8,d7
		blt.s	pc_in_ram_xiii
		move.l	a3,z80_pc_base				;rom base.
		lea	(a3,d7.l),a0

z80_cpu_loop_d0:
		fetch_next_i
		cnop	0,4

pc_in_ram_xiii:	move.l	a2,z80_pc_base				;ram base.
		lea	(a2,d7.l),a0

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBD0 - SET 2, B
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBD0:	subq.l	#2,a5					;less cycles.
		or.w	#%0000010000000000,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		D1 - POP DE
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_D1:	subq.l	#3,a5

		tst.w	d5					;rom read?
		blt.s	readw_d5_to_d0a				;nope. from ram!
		move.w	(a3,d5.l),d0
		addq.w	#2,d5					;sp = sp + 2.
		ror.w	#8,d0					;order correction.

		fetch_next_i
		cnop	0,4

readw_d5_to_d0a:move.w	(a2,d5.l),d0				;ram read.
		addq.w	#2,d5					;sp = sp + 2.
		ror.w	#8,d0					;order correction.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBD1 - SET 2, C
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBD1:	subq.l	#2,a5					;less cycles.
		or.b	#%100,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		D2 - JP NC, xx
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_D2:	btst	#0,d4					;c - flag set?
		bne.s	z80_optcode_D2x				;yes. no jump.

		move.w	(a0),d7
		subq.l	#3,a5
		IFND	NO_CYCLES
		subq.l	#1,a5					;AmiGameBoy: JP cc taken is 4.
		ENDC
		ror.w	#8,d7
		blt.s	pc_in_ram_iv
		move.l	a3,z80_pc_base				;rom base.
		lea	(a3,d7.l),a0

		fetch_next_i
		cnop	0,4

pc_in_ram_iv:	move.l	a2,z80_pc_base				;ram base.
		lea	(a2,d7.l),a0

		fetch_next_i
		cnop	0,4

z80_optcode_D2x:addq.l	#2,a0					;no jump.
		subq.l	#3,a5

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBD2 - SET 2, D
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBD2:	subq.l	#2,a5					;less cycles.
		or.w	#%0000010000000000,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		D3 - DB $D3 ???
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_D3:	fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBD3 - SET 2, E
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBD3:	subq.l	#2,a5					;less cycles.
		or.b	#%100,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		D4 - CALL NC, xx
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_D4:	btst	#0,d4					;c - flag set?
		bne.s	z80_optcode_D4x				;yes. no jump.

		move.l	a0,d6
		sub.l	z80_pc_base,d6
		addq.w	#2,d6
		bsr.l	write_d6_stackx

		move.w	(a0),d7					;00BB.
		subq.l	#3,a5
		IFND	NO_CYCLES
		subq.l	#3,a5					;AmiGameBoy: CALL cc taken is 6.
		ENDC
		ror.w	#8,d7
		blt.s	pc_in_ram_ix
		move.l	a3,z80_pc_base				;rom base.
		lea	(a3,d7.l),a0

		fetch_next_i
		cnop	0,4

pc_in_ram_ix:	move.l	a2,z80_pc_base				;ram base.
		lea	(a2,d7.l),a0

		fetch_next_i
		cnop	0,4

z80_optcode_D4x:addq.l	#2,a0					;no jump.
		subq.l	#3,a5

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBD4 - SET 2, H
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBD4:	subq.l	#2,a5					;less cycles.
		or.w	#%0000010000000000,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		D5 - PUSH DE
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_D5:	move.w	d0,d6
		subq.l	#4,a5

		subq.w	#1,d5
		move.l	d6,-(SP)
		lsr.w	#8,d6					;d6 = upper data (h.B).
		move.l	gb_mem_jumps,a6
		move.l	d5,d7
		jsr	([a6,d5.l*4])				;memory write.

		move.l	(SP)+,d6
		subq.w	#1,d5
		move.l	gb_mem_jumps,a6
		move.l	d5,d7
		jsr	([a6,d5.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBD5 - SET 2, L
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBD5:	subq.l	#2,a5					;less cycles.
		or.b	#%100,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		D6 - SUB x - [n = 1, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_D6:	move.b	(a0)+,d7

		move.b	d3,h_other_I
		subq.l	#2,a5					;less cycles.
		or.w	#$100,d3				;n = 1!
		move.b	d7,h_other_II

		sub.b	d7,d3					;a = a - x.
		move.w	CCR,d4					;status updated.

		move.w	#$0002,h_with_carry			;no carry! h = x!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBD6 - SET 2, (HL)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBD6:	subq.l	#4,a5
		move.l	gb_mem_jumps,a6

		move.w	d2,d7					;d7 = a (hl) - write.
		blt.s	aead_d2_to_d6a

		move.b	(a3,d2.l),d6
		or.b	#%100,d6
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,4

aead_d2_to_d6a:	GBC_RD	d2,d6				;ram.
		or.b	#%100,d6
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		D7 - RST 10h
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_D7:	move.l	a0,d6
		sub.l	z80_pc_base,d6
		bsr.l	write_d6_stackx

		lea	$10(a3),a0
		subq.l	#8,a5
		IFND	NO_CYCLES
		addq.l	#4,a5					;AmiGameBoy: RST is 4.
		ENDC
		move.l	a3,z80_pc_base

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBD7 - SET 2, A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBD7:	subq.l	#2,a5					;less cycles.
		or.b	#%100,d3
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		D8 - RET C
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_D8:	subq.l	#2,a5

		btst	#0,d4					;c - flag set?
		beq.s	z80_cpu_loop_d8				;no. no return.

		READW_D5_TO_D7
		IFND	NO_CYCLES
		subq.l	#3,a5					;AmiGameBoy: RET cc taken is 5.
		ENDC
		addq.w	#2,d5
		ror.w	#8,d7
		blt.s	pc_in_ram_xiv
		move.l	a3,z80_pc_base				;rom base.
		lea	(a3,d7.l),a0

z80_cpu_loop_d8:
		fetch_next_i
		cnop	0,4

pc_in_ram_xiv:	move.l	a2,z80_pc_base				;ram base.
		lea	(a2,d7.l),a0

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBD8 - SET 3, B
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBD8:	subq.l	#2,a5					;less cycles.
		or.w	#%0000100000000000,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		D9 - RETI
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_D9:	subq.l	#2,a5					;less cycles.
		IFND	NO_CYCLES
		subq.l	#2,a5					;AmiGameBoy: RETI is 4.
		ENDC
		clr.b	i_flag					;enable interrupts.

		READW_D5_TO_D7
		addq.w	#2,d5
		ror.w	#8,d7
		blt.s	pc_in_ram_xv
		move.l	a3,z80_pc_base				;rom base.
		lea	(a3,d7.l),a0

		bra.l	reti_back
		cnop	0,4

pc_in_ram_xv:	move.l	a2,z80_pc_base				;ram base.
		lea	(a2,d7.l),a0

		bra.l	reti_back
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBD9 - SET 3, C
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBD9:	subq.l	#2,a5					;less cycles.
		or.b	#%1000,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		DA - JP C, xx
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_DA:	btst	#0,d4					;c - flag set?
		beq.s	z80_optcode_DAx				;no. no jump.

		move.w	(a0),d7
		subq.l	#3,a5
		IFND	NO_CYCLES
		subq.l	#1,a5					;AmiGameBoy: JP cc taken is 4.
		ENDC
		ror.w	#8,d7					;pc updated.
		blt.s	pc_in_ram_v
		move.l	a3,z80_pc_base				;rom base.
		lea	(a3,d7.l),a0

		fetch_next_i
		cnop	0,4

pc_in_ram_v:	move.l	a2,z80_pc_base				;ram base.
		lea	(a2,d7.l),a0

		fetch_next_i
		cnop	0,4

z80_optcode_DAx:addq.l	#2,a0					;no jump.
		subq.l	#3,a5

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBDA - SET 3, D
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBDA:	subq.l	#2,a5					;less cycles.
		or.w	#%0000100000000000,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		DB - DB $DB ???
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_DB:	fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBDB - SET 3, E
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBDB:	subq.l	#2,a5					;less cycles.
		or.b	#%1000,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		DC - CALL C, xx
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_DC:	btst	#0,d4					;c - flag set?
		beq.s	z80_optcode_DCx				;no. no jump.

		move.l	a0,d6
		sub.l	z80_pc_base,d6
		addq.w	#2,d6
		bsr.l	write_d6_stackx

		move.w	(a0),d7					;00BB.
		subq.l	#3,a5
		IFND	NO_CYCLES
		subq.l	#3,a5					;AmiGameBoy: CALL cc taken is 6.
		ENDC
		ror.w	#8,d7
		blt.s	pc_in_ram_x
		move.l	a3,z80_pc_base				;rom base.
		lea	(a3,d7.l),a0

		fetch_next_i
		cnop	0,4

pc_in_ram_x:	move.l	a2,z80_pc_base				;ram base.
		lea	(a2,d7.l),a0

		fetch_next_i
		cnop	0,4

z80_optcode_DCx:addq.l	#2,a0					;no jump.
		subq.l	#3,a5

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBDC - SET 3, H
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBDC:	subq.l	#2,a5					;less cycles.
		or.w	#%0000100000000000,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		DD - DB $DD
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_DD:	fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBDD - SET 3, L
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBDD:	subq.l	#2,a5					;less cycles.
		or.b	#%1000,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		DE - SBC x - [n = 1, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_DE:	btst	#0,d4					;c = 0?
		beq.w	z80_optcode_D6				;yes. normal sub.

		move.b	(a0)+,d6
		move.b	d3,h_other_I
		subq.l	#2,a5					;less cycles.
		or.w	#$100,d3				;n = 1!
		move.b	d6,h_other_II

		move.w	#%10000,CCR				;x = 1!
		subx.b	d6,d3					;a = a - d - c.
		move.w	CCR,d4					;status updated.

		move.w	#$0102,h_with_carry			;yes carry! h = x!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBDE - SET 3, (HL)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBDE:	subq.l	#4,a5
		move.l	gb_mem_jumps,a6

		move.w	d2,d7					;d7 = a (hl) - write.
		blt.s	qead_d2_to_d6a

		move.b	(a3,d2.l),d6
		or.b	#%1000,d6
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,4

qead_d2_to_d6a:	GBC_RD	d2,d6				;ram read.
		or.b	#%1000,d6
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		DF - RST 18h
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_DF:	move.l	a0,d6
		sub.l	z80_pc_base,d6
		bsr.l	write_d6_stackx

		lea	$18(a3),a0
		subq.l	#8,a5
		IFND	NO_CYCLES
		addq.l	#4,a5					;AmiGameBoy: RST is 4.
		ENDC
		move.l	a3,z80_pc_base

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBDF - SET 3, A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBDF:	subq.l	#2,a5					;less cycles.
		or.b	#%1000,d3
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		E0 - LD ($FF00+x), A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_E0:	move.w	#$ff00,d7				;custom registers.
		subq.l	#3,a5
		move.b	(a0)+,d7
		move.b	d3,d6					;d6 = a.

		move.l	gb_mem_jumps,a6
		jsr	([a6,d7.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBE0 - SET 4, B
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBE0:	subq.l	#2,a5					;less cycles.
		or.w	#%0001000000000000,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		E1 - POP HL
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_E1:	subq.l	#3,a5

		tst.w	d5					;rom read?
		blt.s	readw_d5_to_d2a				;nope. from ram!
		move.w	(a3,d5.l),d2
		ror.w	#8,d2					;order correction.
		addq.w	#2,d5					;sp = sp + 2.

		fetch_next_i
		cnop	0,4

readw_d5_to_d2a:move.w	(a2,d5.l),d2				;ram read.
		ror.w	#8,d2					;order correction.
		addq.w	#2,d5					;sp = sp + 2.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBE1 - SET 4, C
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBE1:	subq.l	#2,a5					;less cycles.
		or.b	#%10000,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		E2 - LD ($FF00+C), A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_E2:	move.w	#$ff00,d7				;custom registers.
		subq.l	#2,a5					;less cycles.
		move.b	d1,d7					;offset.
		move.b	d3,d6					;d6 = a.

		move.l	gb_mem_jumps,a6
		jsr	([a6,d7.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBE2 - SET 4, D
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBE2:	subq.l	#2,a5					;less cycles.
		or.w	#%0001000000000000,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		E3 - EX HL, (SP) ???
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_E3:
		READW_D5_TO_D7

		move.l	d7,-(SP)
		move.w	d5,d7					;d7 = stack address.
		move.b	d2,d6					;d6 = l.B.

		move.l	gb_mem_jumps,a6
		jsr	([a6,d7.l*4])				;memory write.

		lsr.w	#8,d2					;d2 = h.B.
		move.w	d5,d7					;d7 = stack address +1.
		move.b	d2,d6
		addq.w	#1,d7

		move.l	gb_mem_jumps,a6
		jsr	([a6,d7.l*4])				;memory write.

		move.l	(SP)+,d7

		move.w	d7,d2
		ror.w	#8,d2

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBE3 - SET 4, E
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBE3:	subq.l	#2,a5					;less cycles.
		or.b	#%10000,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		E4 - DB $E4 ???
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_E4:	fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBE4 - SET 4, H
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBE4:	subq.l	#2,a5					;less cycles.
		or.w	#%0001000000000000,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		E5 - PUSH HL
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_E5:	move.w	d2,d6
		subq.l	#4,a5

		subq.w	#1,d5
		move.l	d6,-(SP)
		lsr.w	#8,d6					;d6 = upper data (h.B).
		move.l	gb_mem_jumps,a6
		move.l	d5,d7
		jsr	([a6,d5.l*4])				;memory write.

		move.l	(SP)+,d6
		subq.w	#1,d5
		move.l	gb_mem_jumps,a6
		move.l	d5,d7
		jsr	([a6,d5.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBE5 - SET 4, L
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBE5:	subq.l	#2,a5					;less cycles.
		or.b	#%10000,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		E6 - AND x - [n = 0, h = 1, c = 0, z = x]
;		MC680x0 CLEARS THE CARRY FLAG ITSELF!
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_E6:	move.b	(a0)+,d7
		subq.l	#2,a5					;less cycles.
		and.b	d7,d3
		move.w	CCR,d4					;status updated.

		move.l	#$00000001,h_other_I			;h = 1! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBE6 - SET 4, (HL)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBE6:	subq.l	#4,a5
		move.l	gb_mem_jumps,a6

		move.w	d2,d7					;d7 = a (hl) - write.
		blt.s	wead_d2_to_d6a

		move.b	(a3,d2.l),d6
		or.b	#%10000,d6
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,4

wead_d2_to_d6a:	GBC_RD	d2,d6				;ram read.
		or.b	#%10000,d6
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		E7 - RST 20h
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_E7:	move.l	a0,d6
		sub.l	z80_pc_base,d6
		bsr.l	write_d6_stackx

		lea	$20(a3),a0
		subq.l	#8,a5
		IFND	NO_CYCLES
		addq.l	#4,a5					;AmiGameBoy: RST is 4.
		ENDC
		move.l	a3,z80_pc_base

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBE7 - SET 4, A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBE7:	subq.l	#2,a5					;less cycles.
		or.b	#%10000,d3
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		E8 - ADD SP, x - [n = 0, h = x, c = x, z = 0]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_E8:	move.b	(a0)+,d7				;no h emulation
		ext.w	d7					;for this optcode.
		subq.l	#4,a5
		add.w	d7,d5
		move.w	CCR,d4
		and.w	#$ff,d3					;n = 0.
		and.b	#%1,d4

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBE8 - SET 5, B
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBE8:	subq.l	#2,a5					;less cycles.
		or.w	#%0010000000000000,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		E9 - LD PC, HL
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_E9:	subq.l	#1,a5					;less cycles.

		tst.w	d2
		blt.s	pc_in_ram_xvii
		move.l	a3,z80_pc_base				;rom base.
		lea	(a3,d2.l),a0

		fetch_next_i
		cnop	0,4

pc_in_ram_xvii:	move.l	a2,z80_pc_base				;ram base.
		lea	(a2,d2.l),a0

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBE9 - SET 5, C
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBE9:	subq.l	#2,a5					;less cycles.
		or.b	#%100000,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		EA - LD (xx), A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_EA:	move.w	(a0)+,d7
		subq.l	#4,a5
		ror.w	#8,d7
		move.b	d3,d6					;d6 = a.

		move.l	gb_mem_jumps,a6
		jsr	([a6,d7.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBEA - SET 5, D
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBEA:	subq.l	#2,a5					;less cycles.
		or.w	#%0010000000000000,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		EB - DB $EB ???
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_EB:	fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBEB - SET 5, E
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBEB:	subq.l	#2,a5					;less cycles.
		or.b	#%100000,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		EC - DB $EC ???
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_EC:	fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBEC - SET 5, H
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBEC:	subq.l	#2,a5					;less cycles.
		or.w	#%0010000000000000,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		ED - PREFIX $ED ???
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_ED:	bchg.b	#1,$bfe001
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBED - SET 5, L
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBED:	subq.l	#2,a5					;less cycles.
		or.b	#%100000,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		EE - XOR x - [n = 0, h = 0, c = 0, z = x]
;		MC680x0 CLEARS THE CARRY FLAG ITSELF!
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_EE:	move.b	(a0)+,d7
		subq.l	#2,a5					;less cycles.
		eor.b	d7,d3
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBEE - SET 5, (HL)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBEE:	subq.l	#4,a5
		move.l	gb_mem_jumps,a6

		move.w	d2,d7					;d7 = a (hl) - write.
		blt.s	fead_d2_to_d6a

		move.b	(a3,d2.l),d6
		or.b	#%100000,d6
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,4

fead_d2_to_d6a:	GBC_RD	d2,d6				;ram read.
		or.b	#%100000,d6
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		EF - RST 28h
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_EF:	move.l	a0,d6
		sub.l	z80_pc_base,d6
		bsr.l	write_d6_stackx

		lea	$28(a3),a0
		subq.l	#8,a5
		IFND	NO_CYCLES
		addq.l	#4,a5					;AmiGameBoy: RST is 4.
		ENDC
		move.l	a3,z80_pc_base

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBEF - SET 5, A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBEF:	subq.l	#2,a5					;less cycles.
		or.b	#%100000,d3
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		F0 - LD A, ($FF00+x)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_F0:	move.w	#$ff00,d7				;custom registers.
		subq.l	#3,a5
		move.b	(a0)+,d7
		move.b	(a2,d7.l),d3				;ld a, ($ff00+x).
		IFD	IDLESKIP
		cmpa.l	idle_pc,a0				;AmiGameBoy: same LDH again?
		beq.l	idle_seen
		move.l	a0,idle_pc
		ENDC

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBF0 - SET 6, B
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBF0:	subq.l	#2,a5					;less cycles.
		or.w	#%0100000000000000,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		F1 - POP AF
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_F1:
		READW_D5_TO_D7
		subq.l	#3,a5
		move.b	d7,d3					;a returned.
		addq.w	#2,d5

		lsr.w	#8,d7					;d7 = f.B (znhc0000).
		move.b	d7,d6
		lsr.b	#4,d7					;d7 = f.B (0000znhc).
		move.b	d7,d4
		and.b	#1,d4					;d4 = 0000000c.
		lsr.b	#1,d7					;d7 = 00000znh.
		and.b	#%100,d7
		or.b	d7,d4					;d4 = mc680x0 flags.

		move.b	d6,d7
		and.b	#%00100000,d7				;d7 = 00h00000.
		lsr.b	#5,d7
		move.b	d7,h_the_flag				;new h!
		and.w	#%01000000,d6				;d6 = 0n000000.
		lsl.w	#2,d6
		and.w	#$ff,d3
		or.w	d6,d3					;new n!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBF1 - SET 6, C
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBF1:	subq.l	#2,a5					;less cycles.
		or.b	#%1000000,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		F2 - LD A, ($FF00+C)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_F2:	move.w	#$ff00,d7				;custom registers.
		subq.l	#2,a5					;less cycles.
		move.b	d1,d7					;offset.
		move.b	(a2,d7.l),d3				;ld a, ($ff00+c).

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBF2 - SET 6, D
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBF2:	subq.l	#2,a5					;less cycles.
		or.w	#%0100000000000000,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		F3 - DI (disable interrupts)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_F3:	subq.l	#1,a5					;less cycles.
		move.b	#1,i_flag				;no interrupts.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBF3 - SET 6, E
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBF3:	subq.l	#2,a5					;less cycles.
		or.b	#%1000000,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		F4 - DB $F4 ???
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_F4:	fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBF4 - SET 6, H
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBF4:	subq.l	#2,a5					;less cycles.
		or.w	#%0100000000000000,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		F5 - PUSH AF
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_F5:	move.b	d3,d6
		lsl.w	#8,d6

		move.b	d4,d6					;d6 = f.B (000xnzvc).
		lsl.b	#4,d6					;d6 =     (nzvc0000).
		move.b	d6,d7
		and.b	#%00010000,d7				;d7 =     (000c0000).
		lsl.b	#1,d6					;d6 =     (zvc00000).
		and.b	#%10000000,d6				;d6 =     (z0000000).
		or.b	d7,d6					;d6 =     (z00c0000).
								;d6 = af.
		subq.l	#4,a5

		move.w	d3,d7
		lsr.w	#2,d7					;d7 = n.
		and.b	#%01000000,d7
		or.b	d7,d6					;d6 =     (zn0c0000).

		move.b	h_the_flag,d7				;h = 0?
		beq.l	write_d6_stack				;yes.

		and.b	#1,d7					;d7 = h!
		beq.l	calculate_h				;h = x!
		or.b	#%00100000,d6				;d6 =     (znhc0000).

		bra.l	write_d6_stack
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBF5 - SET 6, L
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBF5:	subq.l	#2,a5					;less cycles.
		or.b	#%1000000,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		F6 - OR x - [n = 0, h = 0, c = 0, z = x]
;		MC680x0 CLEARS THE CARRY FLAG ITSELF!
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_F6:	move.b	(a0)+,d7
		subq.l	#2,a5					;less cycles.
		or.b	d7,d3
		move.w	CCR,d4					;status updated.

		clr.l	h_other_I				;h = 0! no carry!
		and.w	#$ff,d3					;n = 0!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBF6 - SET 6, (HL)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBF6:	subq.l	#4,a5
		move.l	gb_mem_jumps,a6

		move.w	d2,d7					;d7 = a (hl) - write.
		blt.s	tead_d2_to_d6a

		move.b	(a3,d2.l),d6
		or.b	#%1000000,d6
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,4

tead_d2_to_d6a:	GBC_RD	d2,d6				;ram read.
		or.b	#%1000000,d6
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		F7 - RST 30h
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_F7:	move.l	a0,d6
		sub.l	z80_pc_base,d6
		bsr.l	write_d6_stackx

		lea	$30(a3),a0
		subq.l	#8,a5
		IFND	NO_CYCLES
		addq.l	#4,a5					;AmiGameBoy: RST is 4.
		ENDC
		move.l	a3,z80_pc_base

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBF7 - SET 6, A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBF7:	subq.l	#2,a5					;less cycles.
		or.b	#%1000000,d3
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		F8 - LD HL, SP+x - [n = 0, h = x, c = x, z = 0]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_F8:	move.w	d5,d2					;no h emulation
		move.b	(a0)+,d7				;for this optcode. ;(
		ext.w	d7
		add.w	d7,d2
		move.w	CCR,d4
		subq.l	#3,a5					;?
		and.b	#%1,d4

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBF8 - SET 7, B
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBF8:	subq.l	#2,a5					;less cycles.
		or.w	#%1000000000000000,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		F9 - LD SP, HL
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_F9:	move.w	d2,d5					;sp = hl.
		subq.l	#2,a5					;less cycles.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBF9 - SET 7, C
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBF9:	subq.l	#2,a5					;less cycles.
		or.b	#%10000000,d1
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		FA - LD A, (xx)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_FA:	move.w	(a0)+,d7
		subq.l	#4,a5
		ror.w	#8,d7
		blt.s	read_d7_to_d3a				;nope. from ram!
		move.b	(a3,d7.l),d3

		fetch_next_i
		cnop	0,4

read_d7_to_d3a:	GBC_RD	d7,d3				;ram read.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBFA - SET 7, D
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBFA:	subq.l	#2,a5					;less cycles.
		or.w	#%1000000000000000,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		FB - EI (enable interrupts)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_FB:	subq.l	#1,a5
		tst.b	i_flag
		beq.s	z80_optcode_FB_exit
		clr.b	i_flag					;interrupts enabled.

		move.l	a5,z80_cycles_left
		move.l	#1,a5
		move.b	#1,z80_ei_return

z80_optcode_FB_exit:
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBFB - SET 7, E
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBFB:	subq.l	#2,a5					;less cycles.
		or.b	#%10000000,d0
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		FC - DB $FC ???
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_FC:	fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBFC - SET 7, H
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBFC:	subq.l	#2,a5					;less cycles.
		or.w	#%1000000000000000,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		FD - DB $FD ???
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_FD:	fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBFD - SET 7, L
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBFD:	subq.l	#2,a5					;less cycles.
		or.b	#%10000000,d2
		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		FE - CP x - [n = 1, h = x, c = x, z = x]
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_FE:	move.b	(a0)+,d6
		move.b	d3,h_other_I
		subq.l	#2,a5
		move.b	d6,h_other_II

		cmp.b	d6,d3
		move.w	CCR,d4					;status updated.

		move.w	#$0002,h_with_carry			;no carry! h = x!
		or.w	#$100,d3				;n = 1!

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBFE - SET 7, (HL)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBFE:	subq.l	#4,a5
		move.l	gb_mem_jumps,a6

		move.w	d2,d7					;d7 = a (hl) - write.
		blt.s	uead_d2_to_d6a

		move.b	(a3,d2.l),d6
		or.b	#%10000000,d6
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,4

uead_d2_to_d6a:	GBC_RD	d2,d6				;ram read.
		or.b	#%10000000,d6
		jsr	([a6,d2.l*4])				;memory write.

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		FF - RST 38h
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optcode_FF:	move.l	a0,d6
		sub.l	z80_pc_base,d6
		bsr.l	write_d6_stackx

		lea	$38(a3),a0
		subq.l	#8,a5
		IFND	NO_CYCLES
		addq.l	#4,a5					;AmiGameBoy: RST is 4.
		ENDC
		move.l	a3,z80_pc_base

		fetch_next_i
		cnop	0,128

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		CBFF - SET 7, A
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_optc_CBFF:	subq.l	#2,a5					;less cycles.
		or.b	#%10000000,d3
		fetch_next_i
		cnop	0,128

; AmiGameBoy: the poll-loop skip's code, behind the handlers (see z80_misc.s).
		IFD	IDL_PAIR
idl_tail:
		include	"idle_skip.s"
idl_tend:	dcb.b	(256-((idl_tend-idl_tail)&255))&255,0	;a multiple of 256: what follows keeps its place too.
		ENDC

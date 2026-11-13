; AmiGameBoy: the exact poll-loop skip (idle_jr, idl_sweep); the long comment is in z80_misc.s.
; Included there with NO_IDLEPAD (where the code was first), else at the end of z80_full_III.s.
	IFND	NO_IDLESKIP
	IFND	SPIKE_TRACE
	IFND	NO_CYCLES
IDLE_JRT	equ	3				;JR cc taken: 3 cycles,
	ELSE
IDLE_JRT	equ	2				;2 in Wzonka's count.
	ENDC
idle_no:	fetch_next_i

; sweep start with a loop on record (from z80_cpu_next_sweep: a5 = the sweep's cycles, d7 = 0)
idl_sweep:	move.b	idl_state,d6
		subq.b	#2,d6
		bne.s	idl_s13
		cmpa.l	idl_pc,a0			;2 (the PC cannot have moved; checked
		bne.w	idl_drop			;all the same)
		move.l	idl_vp,a6
		move.b	(a6),d6
		cmp.b	idl_v,d6
		bne.w	idl_chg				;the polled byte changed.
; the whole sweep (or the rest of it) by arithmetic. One instruction always runs, as the
; handlers do; then on until the cycles are used up.
idl_run:	move.l	a5,d6
		moveq	#0,d7
		move.b	idl_L,d7
idl_red:	cmp.l	d7,d6				;whole passes first.
		ble.s	idl_part
		sub.l	d7,d6
		bra.s	idl_red
idl_part:	lea	idl_cost,a6
		move.b	idl_pos,d7
		adda.l	d7,a6
idl_step:	move.b	(a6)+,d7			;(the costs are there twice: no wrap.)
		sub.l	d7,d6
		bgt.s	idl_step
		move.l	d6,a5
		move.l	a6,d7
		sub.l	#idl_cost,d7
		cmp.b	idl_n,d7
		bcs.s	idl_pos3
		sub.b	idl_n,d7
idl_pos3:	move.b	d7,idl_pos
		lea	idl_adr,a6
		move.l	(a6,d7.w*4),a0
		move.l	a0,idl_pc
		moveq	#0,d7
		rts
idl_s13:	move.l	idl_vp,a6			;1 or 3: the bytes as recorded?
		move.b	(a6),d6
		cmp.b	idl_v,d6
		bne.w	idl_drop
		move.l	idl_vp2,a6
		move.b	(a6),d6
		cmp.b	idl_v2,d6
		bne.w	idl_drop
		cmp.b	#1,idl_state
		beq.w	idl_goon			;1: the pass on record is under way.
		move.l	a5,d6				;3: whole passes off, the handlers do
		moveq	#0,d7				;the rest.
		move.b	idl_L,d7
idl_lred:	cmp.l	d7,d6
		ble.s	idl_lgo
		sub.l	d7,d6
		bra.s	idl_lred
idl_lgo:	move.l	d6,a5
		bra.w	idl_goon
; state 2 and the polled byte has changed. The CPU first finishes the pass it is in, still on
; the old byte (A and the flags are the old ones up to the load at the top): arithmetic as
; before. At the top the recorded test is worked out on the new byte. Taken again: the
; handlers run this one pass (it sets A and the flags for the new byte) and its JR comes
; back to idle_jr in state 1, which makes it state 2 again. Not taken: the handlers run on
; out of the loop, no record.
idl_chg:	moveq	#0,d7
		move.b	idl_pos,d7
		beq.s	idl_top				;at the top already.
		lea	idl_cost,a6
		adda.l	d7,a6
idl_cstep:	move.b	(a6)+,d7
		suba.l	d7,a5
		addq.b	#1,idl_pos
		move.b	idl_pos,d7
		cmp.b	idl_n,d7
		beq.s	idl_ctop
		move.l	a5,d6
		bgt.s	idl_cstep
		lea	idl_adr,a6			;the sweep ends inside the old pass.
		move.l	(a6,d7.w*4),a0
		move.l	a0,idl_pc
		moveq	#0,d7
		rts
idl_ctop:	clr.b	idl_pos
		move.l	idl_adr,a0
		move.l	a0,idl_pc
		move.l	a5,d6
		bgt.s	idl_top
		moveq	#0,d7				;the sweep ends at the top: next time.
		rts
idl_top:	move.l	idl_vp,a6
		move.b	(a6),d6				;d6 = the new byte.
		tst.b	idl_tk
		bmi.s	idl_drop			;CP A: no short cut.
		bsr.s	idl_qeval
		bne.s	idl_drop			;not taken: out of the loop.
		move.b	d6,idl_v
		move.b	d6,idl_v2
		move.b	#1,idl_state
		bra.s	idl_goon
idl_drop:	clr.b	idl_state
idl_goon:	moveq	#0,d7
		bra.l	idl_sweep_run

; the recorded test and JR on the byte in d6: Z set = the JR is taken. (d7 used.)
idl_qeval:	move.b	idl_tk,d7
		beq.s	idl_qtst
		subq.b	#1,d7
		beq.s	idl_qcmp
		subq.b	#1,d7
		bne.s	idl_qhl
		moveq	#0,d7				;BIT b,A (always a Z jump)
		move.b	idl_cv,d7
		btst	d7,d6
		seq	d7
		bra.s	idl_qhave
idl_qhl:	move.b	idl_cv,d7			;CP (HL): A - the byte
		tst.b	idl_fl
		bne.s	idl_qhlc
		cmp.b	d6,d7
		seq	d7
		bra.s	idl_qhave
idl_qhlc:	cmp.b	d6,d7
		scs	d7
		bra.s	idl_qhave
idl_qcmp:	tst.b	idl_fl				;CP r / CP n
		bne.s	idl_qcmpc
		cmp.b	idl_cv,d6
		seq	d7
		bra.s	idl_qhave
idl_qcmpc:	cmp.b	idl_cv,d6
		scs	d7
		bra.s	idl_qhave
idl_qtst:	sf	d7				;AND A / OR A: carry clear,
		tst.b	idl_fl
		bne.s	idl_qhave
		tst.b	d6
		seq	d7
idl_qhave:	cmp.b	idl_want,d7			;d7 = the flag the JR looks at.
		rts

; taken JR cc, 3 or 5-14 bytes back (d7 = the offset)
idle_jr:
		IFD	IDL_STAT
		addq.l	#1,idl_cnt+0
		ENDC
		move.b	idl_state,d6
		bne.w	idle_st
		IFD	IDL_QUICK
		move.b	(a0),d6				;no record: only a target that starts $F0, $FA
		cmp.b	#$be,d6				;or $BE (CP (HL)) can be a poll loop. Any other
		beq.s	idle_q				;(copy and count loops: most taken JRs that
		or.b	#$0a,d6				;come here) leaves at once, as idle_slow would
		cmp.b	#$fa,d6				;after more tests. ($F2, $F8 pass too and are
		beq.s	idle_q				;turned away there.)
		fetch_next_i
idle_q:
		ENDC
		tst.b	idl_known			;no record. The loop of the last record
		beq.w	idle_slow			;(an interrupt or a new byte ended it)?
		cmpa.l	idl_adr,a0
		bne.w	idle_slow
		move.l	a5,d6
		ble.w	idle_no
		move.l	(a0),d6				;the same code (a one-group loop is at
		cmp.l	idl_sig,d6			;most 7 bytes),
		bne.w	idle_slow
		move.l	4(a0),d6
		cmp.l	idl_sig+4,d6
		bne.w	idle_slow
		cmp.l	idl_regs,d0			;the same registers (CP r),
		bne.w	idle_slow
		cmp.l	idl_regs+4,d1
		bne.w	idle_slow
		cmp.l	idl_regs+8,d2
		bne.w	idle_slow
		move.b	idl_tk,d6
		bmi.w	idle_slow
		subq.b	#3,d6
		bne.s	idle_kn
		move.b	d3,idl_cv			;(CP (HL): A as it is now.)
idle_kn:
		IFD	IDL_STAT
		addq.l	#1,idl_cnt+12
		ENDC
		move.l	idl_vp,a6			;so only the test on today's byte is
		move.b	(a6),d6				;left to do.
		bsr.w	idl_qeval
		bne.w	idle_no				;the next pass leaves the loop.
		move.b	d6,idl_v			;on record again (state 1), the handlers
		move.b	d6,idl_v2			;run the next pass.
		move.b	#1,idl_state
		bra.w	idle_no
idle_st:	cmpa.l	idl_adr,a0
		bne.s	idle_fresh			;some other loop.
		subq.b	#1,d6
		bne.s	idle_on3
		move.l	idl_vp,a6			;state 1: the pass on record has been run
		move.b	(a6),d6				;in full by the handlers. Bytes unchanged?
		cmp.b	idl_v,d6
		bne.s	idle_fresh
		move.l	idl_vp2,a6
		move.b	(a6),d6
		cmp.b	idl_v2,d6
		bne.s	idle_fresh
		tst.b	z80_ei_return
		bne.s	idle_fresh
		tst.b	idl_tmp
		bne.s	idle_to3
		move.b	#2,idl_state			;arithmetic from here.
		clr.b	idl_pos
		move.l	a0,idl_pc
		move.l	a5,d6
		bgt.w	idl_run				;cycles left: the rest of this sweep too.
		rts
idle_to3:	move.b	#3,idl_state
		move.l	a5,d6
		moveq	#0,d7
		move.b	idl_L,d7
idle_3red:	cmp.l	d7,d6
		ble.s	idle_3go
		sub.l	d7,d6
		bra.s	idle_3red
idle_3go:	move.l	d6,a5
		bra.w	idle_no
idle_on3:	subq.b	#2,d6				;state 3: under a pass left in this
		beq.w	idle_no				;sweep, nothing to drop. (2: not here.)
idle_fresh:	clr.b	idl_state
idle_slow:	move.l	a5,d6
		ble.w	idle_no				;sweep over: leave as usual.
		cmp.w	#-3,d7
		beq.w	idle_hl
		move.b	(a0),d6
		cmp.b	#$fa,d6
		beq.s	idle_go
		cmp.b	#$f0,d6
		bne.w	idle_no
		cmp.b	#$41,1(a0)			;STAT: nothing to gain (and the last
		beq.w	idle_no				;record stays).
idle_go:
		IFD	IDL_QUICK
		move.w	a0,d6				;a look that makes no record (a shape not taken,
		and.w	#7,d6				;a pass that leaves) costs more than the loop's
		lea	idl_bad,a6			;pass: Super R.C. Pro-Am had 87 a frame. The
		lea	(a6,d6.w*8),a6			;target is marked (8 places, by its address) and
		cmpa.l	(a6),a0				;not looked at again for 255 visits. Skipping a
		bne.s	idle_look			;look changes nothing but the time.
		subq.b	#1,4(a6)
		bne.w	idle_no
idle_look:	move.l	a0,(a6)
		clr.b	4(a6)
		move.l	a6,idl_badp			;(a record takes the mark off again.)
		ENDC
idle_go2:
		IFD	IDL_STAT
		addq.l	#1,idl_cnt+4
		ENDC
		IFD	IDL_STAT
		move.l	a0,d6
		sub.l	z80_pc_base,d6
		cmp.l	idl_cnt+20,d6
		beq.s	idl_stsame
		addq.l	#1,idl_cnt+28
		move.l	idl_cnt+20,idl_cnt+24
idl_stsame:	move.l	d6,idl_cnt+20
		ENDC
		clr.b	idl_known			;the record is overwritten from here.
		movem.l	d0-d2/a1/a4,-(sp)
		neg.w	d7
		subq.w	#2,d7				;3-12 bytes from the top to our JR.
		lea	(a0,d7.w),a1			;a1 = our JR.
		move.l	a0,a6				;a6 = the instruction looked at.
		moveq	#0,d0				;d0 = cycles a pass.
		clr.b	idl_tmp				;0 state 2 will do, 1 state 3, -1 no record.
		clr.b	idl_nld				;loads seen.
idle_grp:	moveq	#0,d2				;d6 = A all through.
		move.b	(a6)+,d7
		cmp.b	#$f0,d7
		bne.s	idle_nn
		move.w	#$ff00,d2			;LDH A,(n), as z80_optcode_F0.
		move.b	(a6)+,d2
		cmp.b	#$41,d2				;STAT: nothing to gain.
		beq.w	idle_no0
		lea	(a2,d2.l),a4
		addq.w	#3,d0
		bra.s	idle_ld
idle_nn:	cmp.b	#$fa,d7
		bne.s	idle_op1			;no load: a test of the same A.
		move.w	(a6)+,d2			;LD A,(nn), as z80_optcode_FA.
		addq.w	#4,d0
		ror.w	#8,d2
		bpl.w	idle_no0			;a poll of ROM: not taken.
		lea	(a2,d2.l),a4
idle_ld:	move.b	(a4),d6				;a4 = the polled byte.
		addq.b	#1,idl_nld
		cmp.b	#2,idl_nld
		beq.s	idle_ld2
		bhi.s	idle_ld3
		move.l	a4,idl_vp			;(no record is live here: state 0.)
		move.b	d6,idl_v
idle_ld2:	move.l	a4,idl_vp2
		move.b	d6,idl_v2
		bra.s	idle_op
idle_ld3:	st	idl_tmp				;three polled bytes: no record.
idle_op:	move.b	(a6)+,d7
idle_op1:	addq.w	#1,d0				;one-byte tests: 1 cycle.
		cmp.b	#$a7,d7				;AND A
		beq.w	idle_tst
		cmp.b	#$b7,d7				;OR A
		beq.w	idle_tst
		addq.w	#1,d0				;two-byte tests: 2 cycles.
		cmp.b	#$fe,d7				;CP n
		beq.w	idle_cpn
		cmp.b	#$e6,d7				;AND n
		beq.w	idle_and
		cmp.b	#$cb,d7				;BIT b,A = CB 47+8b
		beq.w	idle_bit
		subq.w	#1,d0
		sub.b	#$b8,d7				;CP B,C,D,E,H,L,(HL),A
		cmp.b	#7,d7
		bhi.w	idle_no0
		beq.s	idle_cpa
		cmp.b	#6,d7				;CP (HL): not handled.
		beq.w	idle_no0
		move.b	idle_roff(pc,d7.w),d7
		move.b	(sp,d7.w),d7			;the register, from the saved copy.
		bra.s	idle_cmp
idle_cpa:	cmp.b	d6,d6
		move.w	CCR,d1
		st	idl_tk				;(CP A: no short cut on a new byte.)
		bra.s	idle_cc
idle_bit:	move.b	(a6)+,d7
		move.b	d7,d2
		and.b	#$c7,d2
		cmp.b	#$47,d2
		bne.w	idle_no0
		lsr.b	#3,d7
		and.w	#7,d7
		move.b	d7,idl_cv			;(for idl_chg)
		move.b	#2,idl_tk
		btst	d7,d6
		move.w	CCR,d1
		bset	#8,d1				;carry not worked out.
		bra.s	idle_cc
idle_and:	and.b	(a6)+,d6			;(A changes too: state 3.)
		or.b	#1,idl_tmp
idle_tst:	clr.b	idl_tk
		tst.b	d6
		move.w	CCR,d1
		bra.s	idle_cc
idle_cpn:	move.b	(a6)+,d7
idle_cmp:	move.b	d7,idl_cv
		move.b	#1,idl_tk
		cmp.b	d7,d6
		move.w	CCR,d1
idle_cc:	move.b	(a6)+,d7			;JR cc: $20 NZ, $28 Z, $30 NC, $38 C.
		move.b	d7,d2
		and.b	#$e7,d2
		cmp.b	#$20,d2
		bne.w	idle_no0
		btst	#3,d7
		sne	idl_want			;(for idl_chg: jump when the flag is set,
		btst	#4,d7
		sne	idl_fl				;and the flag is carry.)
		bne.s	idle_c
		lsr.b	#2,d1				;Z down to bit 0
		bra.s	idle_z
idle_c:		btst	#8,d1				;(C is bit 0; not after BIT).
		bne.w	idle_no0
idle_z:		lsr.b	#3,d7				;bit 0: jump when the flag is set.
		eor.b	d7,d1				;d1 bit 0 clear: taken.
		lea	-1(a6),a6
		cmpa.l	a1,a6
		beq.s	idle_last
		bhi.w	idle_no0			;ran past our JR: not this shape.
		btst	#0,d1
		beq.w	idle_no0			;taken: the pass leaves the loop.
		addq.w	#2,d0				;JR cc not taken: 2 cycles.
		addq.l	#2,a6
		or.b	#1,idl_tmp			;more than one group: state 3.
		bra.w	idle_grp
idle_last:	btst	#0,d1
		bne.w	idle_no0			;the next pass falls out of the loop.
		addq.w	#IDLE_JRT,d0
		move.l	a5,d6
		subq.l	#1,d6
		divu.w	d0,d6
		bvs.w	idle_no0
		clr.w	d6
		swap	d6				;(a5-1) mod L
		addq.l	#1,d6
		move.l	d6,a5
		tst.b	idl_tmp
		bmi.w	idle_no0
		move.l	a0,idl_adr			;on record: top, test, JR,
		move.l	a1,idl_adr+8
		lea	2(a0),a6
		moveq	#3,d6
		cmp.b	#$f0,(a0)
		beq.s	idle_rec
		addq.l	#1,a6
		moveq	#4,d6
idle_rec:	move.l	a6,idl_adr+4
		move.b	d0,idl_L			;the cycles: a pass, load, test, JR
		sub.b	d6,d0				;(test and JR as such only for state 2).
		subq.b	#IDLE_JRT,d0
		lea	idl_cost,a6
		move.b	d6,(a6)+
		move.b	d0,(a6)+
		move.b	#IDLE_JRT,(a6)+
		move.b	d6,(a6)+
		move.b	d0,(a6)+
		move.b	#IDLE_JRT,(a6)
		IFD	IDL_QUICK
		move.l	idl_badp,a6
		clr.l	(a6)
		ENDC
		IFD	IDL_STAT
		addq.l	#1,idl_cnt+8
		ENDC
		move.b	#3,idl_n
		move.b	#1,idl_state
		tst.b	idl_tmp
		bne.w	idle_no0
		move.l	(a0),idl_sig			;a state 2 loop: its code and the
		move.l	4(a0),idl_sig+4			;registers, to know it again cheaply
		move.l	(sp),idl_regs			;after an interrupt (idl_known).
		move.l	4(sp),idl_regs+4
		move.l	8(sp),idl_regs+8
		st	idl_known
idle_no0:	movem.l	(sp)+,d0-d2/a1/a4
		fetch_next_i
idle_roff:	dc.b	6,7,2,3,10,11			;B,C,D,E,H,L in the saved d0-d2.
		cnop	0,4

; CP (HL); JR cc,-3 (Donkey Kong Land $208C waits like this, 54 % of its instructions): the
; polled byte is (HL), A is what it is compared with; two instructions, 2 + 3 cycles. A
; one-group loop for state 2 as above; HL in ROM is not taken.
idle_hl:	cmp.b	#$be,(a0)
		bne.w	idle_no
		tst.w	d2
		bpl.w	idle_no
		IFD	IDL_STAT
		addq.l	#1,idl_cnt+16
		ENDC
		clr.b	idl_known			;the record is overwritten from here.
		lea	(a2,d2.l),a6			;the byte, as READ_D2_TO_D6.
		move.b	1(a0),d7			;our JR
		btst	#3,d7
		sne	idl_want
		btst	#4,d7
		sne	idl_fl
		move.b	d3,idl_cv
		move.b	#3,idl_tk
		move.b	(a6),d6
		bsr.w	idl_qeval
		bne.w	idle_no				;the next pass leaves the loop.
		move.l	a6,idl_vp
		move.l	a6,idl_vp2
		move.b	d6,idl_v
		move.b	d6,idl_v2
		move.l	a0,idl_adr
		lea	1(a0),a6
		move.l	a6,idl_adr+4
		lea	idl_cost,a6
		move.b	#2,(a6)+
		move.b	#IDLE_JRT,(a6)+
		move.b	#2,(a6)+
		move.b	#IDLE_JRT,(a6)
		move.b	#2+IDLE_JRT,idl_L
		move.b	#2,idl_n
		clr.b	idl_tmp
		move.l	(a0),idl_sig
		move.l	4(a0),idl_sig+4
		move.l	d0,idl_regs
		move.l	d1,idl_regs+4
		move.l	d2,idl_regs+8
		st	idl_known
		move.b	#1,idl_state
		move.l	a5,d6				;whole passes off this sweep.
		moveq	#2+IDLE_JRT,d7
idle_hred:	cmp.l	d7,d6
		ble.s	idle_hgo
		sub.l	d7,d6
		bra.s	idle_hred
idle_hgo:	move.l	d6,a5
		bra.w	idle_no
	ENDC
	ENDC

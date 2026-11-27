; wz112.s - Wzonka-Lad 1.12 accuracy fixes in the AmiGameBoy engine.
;
; The logic of Ville Helin's Wzonka-Lad 1.12 timer, interrupt, joypad and I/O changes (GPL-2,
; see COPYING), written again for this engine's sweep loop. Each part has its own WZ112_
; switch; wz_engine.s has WZ_SYNC112, docs/wz112-log.md the list and the tests. Included only
; when one of the switches is on, so the release programs without them stay as they were.

		SECTION	wz112code,CODE

; ---- start of a cartridge (gb_memory_at_start, Power On): a0 = the $FF00 image
wz_start:	clr.l	freq_storage			;(what the jsr here replaced)
		IFD	WZ112_UNUSEDIO
; $FF27-$FF2F are not there: they read $FF (the write table drops writes).
		st	$27(a0)
		st	$28(a0)
		st	$29(a0)
		st	$2a(a0)
		st	$2b(a0)
		st	$2c(a0)
		st	$2d(a0)
		st	$2e(a0)
		st	$2f(a0)
		ENDC
		IFD	WZ112_TIMER
		move.l	d6,-(sp)			;the divider from DIV and its fraction
		move.b	$04(a0),d6			;(gbc.s sets the CGB ones later: wz_ts1)
		lsl.w	#8,d6
		move.b	div_frac,d6
		move.w	d6,wz_div
		move.b	$07(a0),d6
		bsr.w	wz_tcfg
		clr.b	wz_tphase
		move.l	z80_cycles,d6
		addq.l	#1,d6
		move.l	d6,wz_tlen
		move.l	wz_tend,wz_tlast
		move.l	a6,-(sp)
		move.l	a0,a6
		bsr.w	wz_tplan
		move.l	(sp)+,a6
		move.l	(sp)+,d6
		ENDC
		IFD	WZ112_JOYIRQ
		move.b	#$0f,wz_p1vis
		ENDC
		rts

		IFD	WZ112_TIMER
; ---- the timer from a 16-bit divider (WZ112_TIMER)
; wz_tend is the M-cycle count at which the running sweep's budget runs out. In the CPU
; (a5 = cycles left) the time now is wz_tend - a5; while an EI window is open the real
; budget is a5 + z80_cycles_left - 1 (as ei_loop adds it back). The divider moves 4 a
; M-cycle in both speeds; TIMA counts its falling edges at the TAC bit (Wzonka-Lad 1.12).

; d6.l = now: the CPU's time, or the last one seen outside the CPU (the main loop keeps a
; pointer in a5).
wz_now:		move.l	a5,d6
		tst.b	z80_ei_return
		beq.s	.n
		add.l	z80_cycles_left,d6
		subq.l	#1,d6
.n:		cmp.l	#4096,d6
		bgt.s	.o
		cmp.l	#-256,d6
		blt.s	.o
		neg.l	d6
		add.l	wz_tend,d6
		rts
.o:		move.l	wz_tlast,d6
		rts

; From the CPU: bring DIV, TIMA and IF up to now. Keeps every register.
wz_tsyncc:	movem.l	d6-d7/a6,-(sp)
		bsr.s	wz_now
		move.l	gb_memory,a6
		add.l	#$ff00,a6
		bsr.s	wz_tsync
		movem.l	(sp)+,d6-d7/a6
		rts

; d6.l = now, a6 = the $FF00 image. Uses d6, d7.
wz_tsync:	sub.l	wz_tlast,d6
		ble.s	.x
		add.l	d6,wz_tlast
		lsl.l	#2,d6				;T-cycles
		move.w	wz_div,d7			;d7 = the divider before
		add.w	d6,wz_div
		move.b	wz_div,$04(a6)			;DIV: its upper byte
		IFD	WZ112_APUSEQ
		IFND	SPIKE
		bsr.w	wz_apuedge			;WZ112_APUSEQ: the frame sequencer
		ENDC
		ENDC
		tst.w	wz_tshift			;(timer on, or a reload to come)
		IFD	WZ112_APUDUE
		beq.s	.t				;(WZ112_APUSEQ: an edge plans again too)
		ELSE
		beq.s	.x
		ENDC
		bsr.s	wz_tadv
.t:		tst.b	wz_tre				;an overflow or reload: the next one
		bne.s	.p				;(counting alone leaves wz_tdue as it is)
.x:		rts
.p:		clr.b	wz_tre
		bra.w	wz_tplan

; From the CPU: up to now only if the timer's next interrupt is due (IF reads and writes,
; HALT). Keeps every register.
wz_tsyncd:	movem.l	d6-d7/a6,-(sp)
		bsr.w	wz_now
		move.l	d6,d7
		sub.l	wz_tdue,d7
		bmi.s	.x
		move.l	gb_memory,a6
		add.l	#$ff00,a6
		bsr.s	wz_tsync
.x:		movem.l	(sp)+,d6-d7/a6
		rts

; d6.l = T-cycles gone, d7.w = the divider before. Counts the falling edges in one go, stopping
; at an overflow: TIMA reads 0 for one M-cycle, then TMA is loaded and IF bit 2 set (in that
; reload cycle TIMA writes are dropped and TMA writes go through). Wzonka-Lad 1.12.
wz_tadv:	movem.l	d0-d1/d6-d7,-(sp)
		cmp.b	#1,wz_tphase
		bne.s	.clr
		st	wz_tre
		move.b	$06(a6),$05(a6)			;the overflow one M-cycle ago: reload
		bset.b	#2,$0f(a6)
		cmp.l	#4,d6
		bne.s	.clr
		move.b	#2,wz_tphase			;now in the reload cycle
		bra.s	.edg
.clr:		clr.b	wz_tphase
.edg:		moveq	#0,d1
		move.b	wz_tshift,d1
		beq.s	.pop
		and.l	#$ffff,d7
		and.w	wz_tmask,d7
		add.l	d7,d6
		move.w	d6,d7
		and.w	wz_tmask,d7			;d7 = T-cycles since the last edge
		lsr.l	d1,d6				;d6 = edges
		beq.s	.pop
.tk:		moveq	#0,d0
		move.b	$05(a6),d0
		move.w	#256,d1
		sub.w	d0,d1				;d1 = edges to the overflow
		sub.w	d1,d6
		blo.s	.add
		bne.s	.rld
		tst.w	d7
		beq.s	.pend				;overflow on the last edge, just now
		cmp.w	#4,d7
		bne.s	.rld
		move.b	#2,wz_tphase
.rld:		st	wz_tre
		move.b	$06(a6),$05(a6)
		bset.b	#2,$0f(a6)
		tst.w	d6
		bne.s	.tk
		bra.s	.pop
.add:		add.w	d1,d6
		add.b	d6,$05(a6)
		bra.s	.pop
.pend:		st	wz_tre
		clr.b	$05(a6)
		move.b	#1,wz_tphase
.pop:		movem.l	(sp)+,d0-d1/d6-d7
		rts

; d6.b = TAC: the divider bit TIMA follows (0: stopped), its mask and shift.
wz_tcfg:	btst	#2,d6
		bne.s	.on
		clr.b	wz_tshift
		clr.w	wz_tbit
		rts
.on:		movem.l	d0-d1,-(sp)
		moveq	#3,d0
		and.b	d6,d0
		bne.s	.s
		moveq	#4,d0				;TAC 0: 4096 Hz, bit 9
.s:		add.w	d0,d0
		addq.w	#2,d0				;shift 4, 6, 8, 10
		move.b	d0,wz_tshift
		subq.w	#1,d0
		moveq	#1,d1
		lsl.w	d0,d1
		move.w	d1,wz_tbit
		add.w	d1,d1
		subq.w	#1,d1
		move.w	d1,wz_tmask
		movem.l	(sp)+,d0-d1
		rts

; one more TIMA tick (a DIV reset or a TAC change pulling the selected bit low)
wz_ttick:	cmp.b	#2,wz_tphase
		beq.s	.x
		addq.b	#1,$05(a6)
		bne.s	.x
		move.b	#1,wz_tphase
.x:		rts

; WZ112_APUSEQ: wz_tdue is also no later than the next DIV-APU edge (wz_apudue)
WZ_TDUE		MACRO
		IFD	WZ112_APUDUE
		bsr.w	wz_apudue
		ELSE
		move.l	d0,wz_tdue
		ENDC
		ENDM

; wz_tdue = the M-cycle by which IF bit 2 can be set next (a little early is fine: the sync
; then finds nothing). Timer off: far away. a6 = the $FF00 image. Keeps every register.
wz_tplan:	movem.l	d0-d1,-(sp)
		move.l	wz_tlast,d0
		cmp.b	#1,wz_tphase
		beq.s	.n				;the reload one M-cycle on
		moveq	#0,d1
		move.b	wz_tshift,d1
		beq.s	.f
		moveq	#0,d0
		move.b	$05(a6),d0
		neg.w	d0
		add.w	#256,d0				;edges to the overflow
		lsl.l	d1,d0				;T-cycles from the last edge
		moveq	#0,d1
		move.w	wz_div,d1
		and.w	wz_tmask,d1
		sub.l	d1,d0				;from now
		lsr.l	#2,d0				;M-cycles, rounded down
		add.l	wz_tlast,d0
		WZ_TDUE
		movem.l	(sp)+,d0-d1
		rts
.n:		addq.l	#1,d0
		WZ_TDUE
		movem.l	(sp)+,d0-d1
		rts
.f:		add.l	#$40000000,d0
		WZ_TDUE
		movem.l	(sp)+,d0-d1
		rts

; ---- sweep tops (wz_engine.s, in place of irq_timer): a6 = the $FF00 image. Open this sweep:
; z80_cycles, +1 for sweeps 0-3 (gbc_ext in GBC builds: 2 in double speed), as NO_LINE114
; gives the CPU. The divider is brought up to the end of the last sweep here only while the
; timer's next interrupt is due (wz_tdue) and once a line at sweep 1 (DIV for plain reads);
; the timed reads and writes bring it up to their own cycle. Uses d6, d7.
; (A GBC line 144 with the VBlank
; late gives sweep 0 only 1 M-cycle and sweep 1 the rest: the divider then stands still for
; one sweep's worth there, once a frame, and catches up; nothing is lost.)
wz_ts4:		move.l	z80_cycles,d6
		bra.s	wz_tsx
wz_ts03:	move.l	z80_cycles,d6
		IFD	HY_GBC
		add.l	gbc_ext,d6
		ELSE
		addq.l	#1,d6
		ENDC
wz_tsx:		move.l	wz_tend,d7			;the end of the last sweep
		add.l	d6,wz_tend
		move.l	d7,d6
		sub.l	wz_tdue,d7
		bpl.w	wz_tsync			;the timer's interrupt due: up to there
		rts
wz_ts1:
		IFD	HY_GBC				;gbc.s sets DIV and its fraction itself
		move.b	wz_div,d6			;(the CGB start, the speed switch's end):
		cmp.b	$04(a6),d6			;the divider follows. (Only wz_tsync
		beq.s	.d				;writes DIV otherwise.)
		move.b	$04(a6),d6
		lsl.w	#8,d6
		move.b	div_frac,d6
		move.w	d6,wz_div
.d:
		ENDC
		move.l	wz_tend,d6
		bsr.w	wz_tsync
		move.l	z80_cycles,d6
		IFD	HY_GBC
		add.l	gbc_ext,d6
		ELSE
		addq.l	#1,d6
		ENDC
		move.l	d6,wz_tlen			;(sweeps 0, 2, 3; a speed switch reaches
		add.l	d6,wz_tend			;them from the next sweep 1)
		rts

; ---- timed reads (LDH A,(n), LD A,(C) of $FF04-$FF0F): d7.l = the address in the image.
; Out: d3 = the byte. Keeps d7 (its upper word is the fetch's).
wz_tread:
		IFD	WZ112_APURD
		cmp.b	#$10,d7
		bcc.s	wz_treada
		ENDC
		cmp.b	#$05,d7
		beq.s	.s				;TIMA: up to now
		bcs.s	.d				;DIV: worked out, nothing moved
		cmp.b	#$0f,d7
		beq.s	.i
		move.b	(a2,d7.l),d3			;TMA, TAC: only writes change them
		rts
.i:		bsr.w	wz_tsyncd			;IF: up to now if the timer's is due
		move.b	(a2,d7.l),d3
		rts
.s:		bsr.w	wz_tsyncc
		move.b	(a2,d7.l),d3
		rts
.d:		bsr.w	wz_now				;(d6 is free here)
		sub.l	wz_tlast,d6
		bpl.s	.p
		moveq	#0,d6
.p:		lsl.l	#2,d6
		add.w	wz_div,d6
		lsr.w	#8,d6
		move.b	d6,d3
		rts

		IFD	WZ112_APURD
; $FF10-$FF3F (WZ112_APURD): NR52 with the divider brought up to now first (WZ112_APUSEQ: the
; length steps due by now), wave RAM through channel 3 (WZ112_WAVE, wz112snd.s), the rest as
; stored.
wz_treada:
		IFND	SPIKE
		IFD	WZ112_APUSEQ
		cmp.b	#$26,d7
		bne.s	.w
		bsr.w	wz_tsyncc
		IFD	WZ112_ELOG
		move.l	d0,-(sp)
		move.w	#$200,d0
		move.b	(a2,d7.l),d0
		jsr	hy_elog
		move.l	(sp)+,d0
		ENDC
		IFD	WZ112_WAVE
		bra.s	.r
		ENDC
.w:
		ENDC
		IFD	WZ112_WAVE
		cmp.b	#$30,d7
		bcs.s	.r
		jmp	hy_waver
		ENDC
		ENDC
.r:		move.b	(a2,d7.l),d3
		rts
		ENDC

		IFD	WZ112_APUSEQ
		IFND	SPIKE
; NR52 read from (HL) and the like (z80_misc.s GBC_RD): the divider up to now first, so a poll
; such as blargg's sync_apu (LD A,2 / AND (HL)) sees a length step at its cycle. -> d6.b;
; keeps every other register.
wz_rd26:	bsr.w	wz_tsyncc
		move.l	d7,-(sp)
		move.l	#$ff26,d7
		move.b	(a2,d7.l),d6
		move.l	(sp)+,d7
		rts
		ENDC
		ENDC

		IFD	WZ112_APUSEQ
		IFND	SPIKE
; ---- WZ112_APUSEQ: d6.l = T-cycles gone, d7.w = the divider before (wz_tsync): one frame
; sequencer step (sound.s HySndEdge) for each falling edge of bit 12 (DIV bit 4; bit 13 in
; double speed), Wzonka-Lad 1.12's DIV-APU. Keeps every register.
wz_apuedge:	movem.l	d0/d6-d7,-(sp)
		and.l	#$ffff,d7
		add.l	d7,d6
		moveq	#13,d0
		IFD	HY_GBC
		tst.b	gbc_double
		beq.s	.s
		moveq	#14,d0
.s:
		ENDC
		lsr.l	d0,d6
		lsr.l	d0,d7
		sub.l	d7,d6				;edges
		beq.s	.x
.e:		jsr	HySndEdge
		subq.l	#1,d6
		bne.s	.e
		st	wz_tre				;(wz_tsync plans the next edge)
.x:		movem.l	(sp)+,d0/d6-d7
		rts

; d0.l = the timer's due time (M): wz_tdue = the earlier of it and the next DIV-APU edge, so
; the sweep tops bring the divider up for the edge and plain reads (CP (HL), AND (HL) of NR52)
; see its steps at most a sweep late. Uses d1.
wz_apudue:	move.l	d2,-(sp)
		moveq	#0,d1
		move.w	wz_div,d1
		move.l	#8192,d2			;bit 12 (bit 13 in double speed)
		IFD	HY_GBC
		tst.b	gbc_double
		beq.s	.s
		add.l	d2,d2
.s:
		ENDC
		subq.l	#1,d2
		and.l	d2,d1
		addq.l	#1,d2
		sub.l	d1,d2				;T-cycles to the edge
		lsr.l	#2,d2				;M-cycles, rounded down
		add.l	wz_tlast,d2
		move.l	d2,d1
		sub.l	d0,d1
		bpl.s	.t
		move.l	d2,d0
.t:		move.l	d0,wz_tdue
		move.l	(sp)+,d2
		rts

; DIV written (wz_w04, the divider up to now): with the DIV-APU bit 1, the reset is its falling
; edge. Keeps every register.
wz_apudiv:	move.l	d6,-(sp)
		move.w	wz_div,d6
		IFD	HY_GBC
		tst.b	gbc_double
		beq.s	.s
		lsr.w	#1,d6
.s:
		ENDC
		btst	#12,d6
		beq.s	.x
		jsr	HySndEdge
.x:		move.l	(sp)+,d6
		rts
		ENDC
		ENDC

; ---- writes: d6.b = the byte, d7.l = the address in the image. Keep d7 and a6.
WZ_WSYNC	MACRO
		movem.l	d6-d7/a6,-(sp)
		bsr.w	wz_now
		move.l	a2,a6
		add.l	#$ff00,a6
		bsr.w	wz_tsync
		move.l	(sp),d6
		ENDM

; DIV: the whole divider resets. A selected bit that was 1 falls: one more tick.
wz_w04:		WZ_WSYNC
		IFD	WZ112_APUSEQ
		IFND	SPIKE
		bsr.w	wz_apudiv			;WZ112_APUSEQ: DIV-APU 1 -> 0 steps
		ENDC
		ENDC
		move.w	wz_tbit,d6
		and.w	wz_div,d6
		beq.s	.n
		bsr.w	wz_ttick
.n:		clr.w	wz_div
		clr.b	$04(a6)
		bsr.w	wz_tplan
		movem.l	(sp)+,d6-d7/a6
		rts

; TIMA: dropped in the reload cycle; in the overflow cycle it stops the reload.
wz_w05:		WZ_WSYNC
		cmp.b	#2,wz_tphase
		beq.s	.x
		clr.b	wz_tphase
		move.b	d6,$05(a6)
		bsr.w	wz_tplan
.x:		movem.l	(sp)+,d6-d7/a6
		rts

; TMA: in the reload cycle TIMA takes it too.
wz_w06:		WZ_WSYNC
		move.b	d6,$06(a6)
		cmp.b	#2,wz_tphase
		bne.s	.x
		move.b	d6,$05(a6)
		bsr.w	wz_tplan
.x:		movem.l	(sp)+,d6-d7/a6
		rts

; TAC: a new bit (or the timer off) that pulls the selected one from 1 to 0 ticks once.
wz_w07:		WZ_WSYNC
		move.w	wz_tbit,d7			;the bit before
		bsr.w	wz_tcfg
		or.b	#%11111000,d6
		move.b	d6,$07(a6)
		and.w	wz_div,d7
		beq.s	.x
		move.w	wz_tbit,d6
		and.w	wz_div,d6
		bne.s	.x
		bsr.w	wz_ttick
.x:		bsr.w	wz_tplan
		movem.l	(sp)+,d6-d7/a6
		rts

; ---- poll-loop skip (idle_skip.s): no record for a loop that polls DIV-TAC ($FF04-$FF0E),
; whose bytes move inside a sweep now. IF polls are kept (IF bit 2 is then seen up to a
; sweep late, as before WZ112_TIMER) unless WZ112_IFPOLL: exact, but costly on the 030.
; idle_ld (d2.w = the address, a4 = its byte); in place of addq.b #1,idl_nld.
wz_ild:		cmp.w	#$ff04,d2
		bcs.s	.k
		cmp.w	#$ff0f,d2
		bcs.s	.n
		IFD	WZ112_IFPOLL
		bne.s	.a
		btst.b	#2,-8(a4)			;TAC on
		bne.s	.n
		bra.s	.k
.a:
		ENDC
		IFD	WZ112_APURD			;NR52 and wave RAM: timed reads now
		bsr.s	wz_iapu
		beq.s	.n
		ENDC
.k:		addq.b	#1,idl_nld
		rts
.n:		addq.l	#4,sp
		jmp	idle_no0
; idle_hl (CP (HL), d2.w = HL); in place of clr.b idl_known.
wz_ihl:		cmp.w	#$ff04,d2
		bcs.s	.k
		cmp.w	#$ff0f,d2
		bcs.s	.n
		IFD	WZ112_APURD
		bsr.s	wz_iapu
		beq.s	.n
		ENDC
.k:		clr.b	idl_known
		rts
.n:		addq.l	#4,sp
		jmp	idle_no
		IFD	WZ112_APURD
; d2.w = the address: Z set for NR52 (WZ112_APUSEQ) and wave RAM (WZ112_WAVE)
wz_iapu:
		IFD	WZ112_APUSEQ
		cmp.w	#$ff26,d2
		beq.s	.x
		ENDC
		IFD	WZ112_WAVE
		cmp.w	#$ff30,d2
		bcs.s	.no
		cmp.w	#$ff40,d2
		bcc.s	.no
		cmp.w	d2,d2				;Z
		rts
		ENDC
.no:		cmp.w	#1,d2				;(never: Z clear)
.x:		rts
		ENDC
		ENDC					;WZ112_TIMER

		IFD	WZ112_IFW
; ---- IF ($FF0F) and IE ($FFFF) writes: d6.b = the byte, d7.l = the address in the image.
; WZ112_TIMER: the timer first (IF bit 2). WZ112_IFWRITE: with IME on and an interrupt now
; pending, it is taken after this instruction, before the next fetch (blargg cpu_instrs 02):
; the EI window's way out of the sweep (ei_loop) with the rest of the budget kept.
wz_w0f:
wz_wff:
		IFD	WZ112_TIMER
		bsr.w	wz_tsyncd
		ENDC
		or.b	#%11100000,d6
		move.b	d6,(a2,d7.l)
		IFD	WZ112_IFWRITE
		tst.b	i_flag
		bne.s	.x
		tst.b	z80_ei_return
		bne.s	.x
		move.l	a5,d6				;from the CPU only (the main loop's
		cmp.l	#4096,d6			;dispatch pushes have a pointer in a5)
		bgt.s	.x
		cmp.l	#-256,d6
		blt.s	.x
		move.l	a6,-(sp)
		move.l	a2,a6
		add.l	#$ff00,a6
		move.b	$0f(a6),d6
		and.b	$ff(a6),d6
		move.l	(sp)+,a6
		and.b	#%11111,d6
		beq.s	.x
		move.l	a5,d6
		addq.l	#1,d6
		move.l	d6,z80_cycles_left
		sub.l	a5,a5
		move.b	#1,z80_ei_return
		ENDC
.x:		rts
		ENDC

		IFD	WZ112_JOYIRQ
; ---- joypad (WZ112_JOYIRQ): the interrupt on a falling edge of a selected line only (a line
; going low: a press on a selected group, or selecting a group with a key held), as Wzonka-Lad
; 1.12. The lines seen last are kept here: the P1 image may hold a Super Game Boy pad.
; P1 write (do_joystick): d6.b = the byte, d7.l = the address in the image. Keeps d7.
wz_p1w:		movem.l	d5/a6,-(sp)
		lea	(a2,d7.l),a6
		cmp.b	#$03,d6				;type probe: both groups, $F0 + lines
		bne.s	.w
		move.b	#$c0,d6
		bsr.s	wz_p1lines
		or.b	#$30,d6
		bra.s	.s
.w:		bsr.s	wz_p1lines
.s:
		IFND	NO_P1HIGH
		or.b	#%11000000,d6			;bits 7-6 read as 1
		ENDC
		move.b	d6,(a6)
		bsr.s	wz_p1edge
		movem.l	(sp)+,d5/a6
		rts

; d6.b = P1 (select bits 5-4) -> low nibble = the lines, 0 = pressed. Uses d5.
wz_p1lines:	or.b	#$0f,d6
		btst	#5,d6
		bne.s	.d
		move.b	buttons_byte,d5
		or.b	#$f0,d5
		and.b	d5,d6
.d:		btst	#4,d6
		bne.s	.x
		move.b	directions_byte,d5
		or.b	#$f0,d5
		and.b	d5,d6
.x:		rts

; d6.b low nibble = the lines now, a6 = the $FF00 image: IF bit 4 on a 1 -> 0. Uses d5, d6.
wz_p1edge:	move.b	wz_p1vis,d5
		move.b	d6,wz_p1vis
		not.b	d6
		and.b	d5,d6
		and.b	#$0f,d6
		beq.s	.x
		bset.b	#4,$0f(a6)
.x:		rts

; the main loop's look (input_irq, lines 40/80/120 and after a pad read): a6 = the $FF00 image.
wz_joyirq:	move.l	d5,-(sp)
		move.b	(a6),d6
		bsr.s	wz_p1lines
		bsr.s	wz_p1edge
		move.l	(sp)+,d5
		rts
		ENDC

		SECTION	wz112data,DATA
		cnop	0,4
		IFD	WZ112_TIMER
wz_tend:	dc.l	0			;M-cycles: the end of the running sweep
wz_tlast:	dc.l	0			;M-cycles: the divider's time
wz_tlen:	dc.l	23			;M-cycles: sweeps 0-3 (z80_cycles + 1 or gbc_ext)
wz_tdue:	dc.l	0			;M-cycles: the timer's next interrupt, or later
wz_div:		dc.w	0			;the 16-bit divider (DIV = its upper byte)
wz_tbit:	dc.w	0
wz_tmask:	dc.w	0
wz_tshift:	dc.b	0			;(even: tst.w takes it with wz_tphase)
wz_tphase:	dc.b	0			;0 counting, 1 overflow (TIMA 0), 2 reload cycle
wz_tre:		dc.b	0			;wz_tadv: the next overflow to plan
		ENDC
		IFD	WZ112_JOYIRQ
wz_p1vis:	dc.b	$0f
		ENDC
		even

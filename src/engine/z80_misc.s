; Taken from Wzonka-Lad 1.03 (Aminet misc/emu/Wzonka-Lad), GPL-2.
; Wzonka-Lad (C) Ville Helin 1996-1999; GPL release and changes by
; Ventzislav Tzvetkov 2003-2004. Changes for AmiGameBoy (C) 2026, same licence;
; see git history. Original file: z80_misc.s

output_d0_to_a1:MACRO

		and.w	#$ff,d0
		move.w	d0,d1
		lsr.b	#4,d0
		cmp.w	#$A,d0
		blt.s	too_a\@
		add.b	#'A'-$a,d0
		bra.s	joo_a\@
too_a\@:	add.b	#'0',d0
joo_a\@:	move.b	d0,(a1)+

		and.b	#%1111,d1
		cmp.w	#$A,d1
		blt.s	too_b\@
		add.b	#'A'-$a,d1
		bra.s	joo_b\@
too_b\@:	add.b	#'0',d1
joo_b\@:	move.b	d1,(a1)+

		ENDM

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		output debug data
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

		IFGT	GAMEBOY_DEBUG

debug_output:	;btst.b	#6,$bfe001
		;bne.s	debug_output_no_output

		bra.s	debug_output_ok

		movem.l	d0-d7/a0-a6,-(SP)

		move.l	gb_memory,a6
		add.l	#$fe00,a6
		lea	debug_message,a1
		move.w	#$A0-1,d7

debug_output_oam:
		move.b	(a6)+,d0
		output_d0_to_a1
		dbra	d7,debug_output_oam

		move.b	#$A,(a1)+
		move.b	#0,(a1)+
		move.l	#$a2,d3

		bra.w	debug_output_output_size

debug_output_no_output:
		move.b	(a0)+,d7
		lsl.w	#8,d7					;d7 = d7*256.
		jmp	(a1,d7.l)				;jump and emulate.

debug_output_ok:movem.l	d0-d7/a0-a6,-(SP)

		move.w	d0,gbz80_de
		move.w	d1,gbz80_bc
		move.w	d2,gbz80_hl
		move.w	d3,gbz80_fa

		lea	debug_flags,a1

		move.l	#"----",(a1)
		move.b	#"-",4(a1)
		btst	#0,d4
		beq.s	debug_output_c
		move.b	#"C",3(a1)
debug_output_c:	btst	#2,d4
		beq.s	debug_output_z
		move.b	#"Z",(a1)
debug_output_z:	btst	#8,d3
		beq.s	debug_output_n
		move.b	#"N",1(a1)
debug_output_n:	tst.b	h_the_flag
		beq.s	debug_output_h
		move.b	#"H",2(a1)
debug_output_h:	tst.b	i_flag
		bne.s	debug_output_i
		move.b	#"I",4(a1)
debug_output_i:	

		lea	debug_oc,a1
		move.b	(a0),d7
		move.b	d7,d0
		output_d0_to_a1

		lea	debug_cycles,a1
		move.l	a5,d0
		lsr.w	#8,d0
		output_d0_to_a1
		move.l	a5,d0
		output_d0_to_a1

		lea	debug_list,a1
		cmp.b	#$cb,d7
		bne.s	debug_output_no_cb

		lea	debug_list_cb,a1
		addq.l	#1,a0

debug_output_no_cb:
		moveq.l	#0,d7
		move.b	(a0),d7
		lsl.l	#4,d7
		add.l	d7,a1
		lea	debug_command,a2
		move.l	(a1)+,(a2)+
		move.l	(a1)+,(a2)+
		move.l	(a1)+,(a2)+
		move.l	(a1)+,(a2)+

		lea	debug_pc,a1				;pc.
		move.l	a0,d0
		sub.l	z80_pc_base,d0
		lsr.w	#8,d0
		output_d0_to_a1
		move.l	a0,d0
		sub.l	z80_pc_base,d0
		output_d0_to_a1

		lea	debug_next_1,a1				;x.
		move.b	1(a0),d0
		output_d0_to_a1

		lea	debug_next_2,a1				;xx.
		move.b	2(a0),d0
		output_d0_to_a1
		move.b	1(a0),d0
		output_d0_to_a1

		lea	debug_rom_bank,a1			;rom bank.
		move.b	rom_bank_activated,d0
		output_d0_to_a1

		lea	debug_ram_bank,a1			;ram bank.
		move.l	ram_bank_no,d0
		output_d0_to_a1

		lea	debug_de,a1				;de.
		move.w	gbz80_de,d0
		lsr.w	#8,d0
		output_d0_to_a1
		move.w	gbz80_de,d0
		output_d0_to_a1

		lea	debug_bc,a1				;bc.
		move.w	gbz80_bc,d0
		lsr.w	#8,d0
		output_d0_to_a1
		move.w	gbz80_bc,d0
		output_d0_to_a1

		lea	debug_hl,a1				;hl.
		move.w	gbz80_hl,d0
		lsr.w	#8,d0
		output_d0_to_a1
		move.w	gbz80_hl,d0
		output_d0_to_a1

		lea	debug_af,a1				;af.
		move.w	gbz80_fa,d0
		output_d0_to_a1
		move.w	gbz80_fa,d0
		lsr.w	#8,d0
		output_d0_to_a1

		lea	debug_sp,a1				;sp.
		move.w	d5,d0
		lsr.w	#8,d0
		output_d0_to_a1
		move.w	d5,d0
		output_d0_to_a1

debug_output_output:
		move.l	#debug_message_end-debug_message,d3
debug_output_output_size:
		move.l	#debug_message,d2
		move.l	dos_base,a6
		move.l	debug_con_handle,d1
		jsr	Write(a6)

		move.b	$bfec01,d6
		not.b	d6
		ror.b	#1,d6
		cmp.b	#$45,d6
		bne.s	debug_output_exit

		movem.l	(SP)+,d0-d7/a0-a6

		sub.l	a5,a5
		move.b	#1,debug_exit

		move.b	(a0)+,d7
		lsl.w	#8,d7					;d7 = d7*256.
		jmp	(a1,d7.l)				;jump and emulate.

debug_output_exit:
		movem.l	(SP)+,d0-d7/a0-a6

		move.b	(a0)+,d7
		lsl.w	#8,d7					;d7 = d7*256.
		jmp	(a1,d7.l)				;jump and emulate.

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		memory write debug routines
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

debug_joypad_wanted:
		movem.l	d0-d7/a0-a6,-(SP)

		lea	debug_joy,a1
		move.b	d6,d0
		output_d0_to_a1

		move.l	#debug_joy_txt,d2
		move.l	#debug_joy_txt_end-debug_joy_txt,d3
		move.l	dos_base,a6
		move.l	debug_con_handle,d1
		jsr	Write(a6)

		movem.l	(SP)+,d0-d7/a0-a6
		rts

		ENDIF

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		fetch the next z80 optcode
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

fetch_next_i:	MACRO
;		jmp	jesus
		move.l	a5,d6					;test cycles left.
		ble.s	f_xit\@
		IFGT	GAMEBOY_DEBUG
		jmp	debug_output
		ELSE
		move.b	(a0)+,d7
		lsl.w	#8,d7					;d7 = d7*256.
		IFD	SPIKE_TRACE
		jmp	spike_trace				;AmiGameBoy: stage 0 trace.
		ELSE
		jmp	(a1,d7.l)				;jump and emulate.
		ENDC
		ENDIF
f_xit\@:	rts
		ENDM

; ---- AmiGameBoy: JR that wraps below $0000 (Quartet: jr -79 at $0040 into an HRAM stub at
; $FFF3). Wzonka adds the offset to the host pointer, which then points before the ROM
; image. Reached when a0 < a3 after a taken JR; from RAM that is only allocation order.
	IFND	NO_JRWRAP
jr_wrap:	cmpa.l	z80_pc_base,a3
		bne.s	jr_wrap_ram			;running from RAM: nothing wrapped.
		move.l	a0,d6
		sub.l	a3,d6				;negative: below $0000.
		and.l	#$ffff,d6
		lea	(a2,d6.l),a0
		move.l	a2,z80_pc_base
jr_wrap_ram:	fetch_next_i
	ENDC

; ---- AmiGameBoy: exact poll-loop skip (NO_IDLESKIP = previous binary). Tetris spends 87 % of
; its instructions in LDH A,($85); AND A; JR Z, Donkey Kong Land 2 53 % in LDH A,($44); CP B;
; JR NZ: on a 68030/50 that is most of a frame.
; idle_jr is reached from the taken path of JR NZ/Z/NC/C when the jump goes 3 or 5-14 bytes
; back (one tst.b in the handler, on a table of the 256 JR offsets that sits just under
; z80_optcode_00; d7 = the offset, a0 = the target). A poll loop is one or more groups, from
; the target up to the JR that got us here:
;	LDH A,(n)  or  LD A,(nn)	(the first group must have it, later ones may test A again)
;	AND A / OR A / CP r / CP A / CP n / AND n / BIT b,A
;	JR cc		(not taken, any target; the last one is ours, taken, back to the top)
; Kid Icarus $01B3 LD A,($C2DB); OR A; JR NZ,+6; LD A,($C010); AND A; JR Z,-12.
; Kirby's Dream Land $01F7 LDH A,($8C); BIT 5,A; JR NZ,-6; BIT 6,A; JR NZ,-10.
; or the two instructions CP (HL); JR cc,-3 (idle_hl at the end).
; Nothing in such a loop writes memory or changes a register but A and the flags, and the
; engine changes Game Boy memory (LY, STAT, DIV, TIMA, IF, the pad, flags set by interrupt
; handlers) only between CPU sweeps: every read here is a plain byte from the memory image,
; the same read the handlers do. So the polled bytes hold until this sweep ends, and each
; further pass does exactly what the one before did.
; 1. First visit (idle_slow, idl_state 0). The pass just run may have been entered half way,
;    so the next pass is worked out here from the bytes themselves (every JR in it follows a
;    test that sets its flag; no JR C/NC after BIT, which leaves carry alone). If it comes
;    round to our JR again, whole passes of L cycles each are dropped from the sweep's cycle
;    count: (a5-1)/L of them, so 1 <= a5 <= L is left and the handlers run the rest: the
;    sweep ends on the same instruction with the same overshoot as without the skip. The
;    loop goes on record (idl_state 1: top, cycles a pass, the one or two polled bytes and
;    their values) and the handlers run the next pass from the top.
; 2. When that pass comes round to our JR with the polled bytes unchanged, the CPU has run
;    one whole pass on these values, and every later pass leaves it in exactly this state
;    again at this place. From here:
;    - idl_state 2, one-group loops whose test leaves A alone (not AND n) and CP (HL) loops:
;      A, the flags and the half-carry scratch are the same at every instruction of the
;      loop, so nothing but the PC and the cycle count moves. Each sweep is arithmetic
;      (idl_run): walk the instruction costs from the place the last sweep stopped until the
;      cycles run out. No handler runs.
;    - idl_state 3, the other loops: each sweep drops its whole passes from the cycle count
;      (wherever in the loop it starts) and the handlers run what is left, under a pass.
; 3. Every sweep start checks the record first (idl_sweep): the polled bytes as recorded.
;    An interrupt dispatch clears it (the five dehalting_z80_n and reti_back): nothing else
;    moves the PC or a register between sweeps. A changed byte or a dispatch: no record, the
;    handlers carry on as ever from where the PC is. One short cut: in state 2 a changed
;    byte does not drop the record at once, see idl_chg (a loop waiting for LY sees a new
;    byte every line). And a state 2 loop stays known after its record ends (idl_known:
;    its first 8 bytes and BC/DE/HL as they were): the next time its JR comes here with the
;    same code and registers, only the test on the byte as it is then is worked out, and the
;    loop is on record again (state 1) without the full look (games whose interrupts cut the
;    wait every line or two).
;    The record is only made with cycles left (so never in the one-instruction window after
;    EI), and states 2/3 only start when the main loop has no EI return pending. The
;    registers a test reads (CP r) cannot change while only the loop runs.
; Not taken: STAT ($FF41; its mode bits move every sweep or two, there is nothing to skip),
; polls of ROM (LD A,(nn) or HL below $8000), CP (HL) as a test after a load.
; Off under SPIKE_TRACE (the trace counts instructions).
; The code is in idle_skip.s. It is included here only with NO_IDLEPAD (the first layout). As
; it is, it sits behind the handlers (its data behind the engine's); the dispatch hooks take no room (z80_halt
; lives beside idl_state there and the dispatch's clr.b z80_halt is a clr.w on both: IDL_PAIR)
; and the sweep hook is padded to 256 bytes. Every routine then sits where it sat without the
; skip, modulo 256. The 68030's instruction cache is 256 bytes, direct mapped, and the handlers
; are 256 apart: which other routines share their cache lines moves the speed on a 68030/50 by
; several per cent (12 Nov 2026: Final Fantasy Legend II 7 % slower with the hook compiled in
; but never taken).
	IFD	NO_IDLEPAD
	include	"idle_skip.s"
	ENDC

; ---- AmiGameBoy idle skip, OFF by default (IDLESKIP=1 builds it). Measured 10 Nov 2026 on the
; WinUAE 030: 2-9% slower on most titles (the bookkeeping on every LDH and RAM write
; outweighs the few idle sweeps; the busy titles do real work between short STAT waits)
; and Escape 2042 diverged. Kept for reference. Wzonka runs the CPU in sweeps
; of a fixed cycle budget (overshoot dropped) and changes I/O, LY, STAT and IF only
; between sweeps, so a loop that reads the same $FF00+n at the same PC with the same
; registers and gets the same value does the same thing until that byte changes or an
; interrupt moves the PC. Then park the PC on the LDH and skip whole sweeps until one
; of the two happens. Guards: the two visits are at most one sweep apart, no interrupt
; was taken and no RAM was written in between (a loop counting in memory, or calling a
; routine that returns at once, is not idle).
	IFD	IDLESKIP
idle_seen:	cmpa.l	idle_snap,a0			;(absolute compares: the write
		bne.s	idle_take			;table pointer is live here)
		cmp.l	idle_snap+4,d0
		bne.s	idle_take
		cmp.l	idle_snap+8,d1
		bne.s	idle_take
		cmp.l	idle_snap+12,d2
		bne.s	idle_take
		cmp.l	idle_snap+16,d5
		bne.s	idle_take
		cmp.b	idle_snapval,d3
		bne.s	idle_take
		move.l	idle_sweeps,d6			;same or the previous sweep only: a
		sub.l	idle_snap+20,d6			;poll loop is a few instructions long
		cmp.l	#1,d6
		bhi.s	idle_take
		move.l	idle_writes,d6			;and no RAM written since: the
		cmp.l	idle_snap+24,d6			;loop may count in memory
		bne.s	idle_take
		subq.l	#2,a0				;back to the LDH opcode.
		move.l	a0,idle_park
		move.w	d7,idle_addr
		move.b	d3,idle_val
		st	idle_on
		suba.l	a5,a5				;end this sweep.
		fetch_next_i
idle_take:	move.l	a0,idle_snap
		move.l	d0,idle_snap+4
		move.l	d1,idle_snap+8
		move.l	d2,idle_snap+12
		move.l	d5,idle_snap+16
		move.l	idle_sweeps,idle_snap+20
		move.l	idle_writes,idle_snap+24
		move.b	d3,idle_snapval
		fetch_next_i

idle_sweep:	cmpa.l	idle_park,a0			;an interrupt moved the PC?
		bne.s	idle_wake
		move.w	idle_addr,d7
		move.b	(a2,d7.l),d7
		cmp.b	idle_val,d7			;the polled byte changed?
		bne.s	idle_wake
		rts					;no: skip this sweep.
idle_wake:	clr.b	idle_on
		moveq.l	#0,d7
		bra.w	idle_sweep_run
	ENDC



jesus:		move.l	a5,d6					;test cycles left.
		ble.s	f_xita

		IFGT	GAMEBOY_DEBUG
		jmp	debug_output
		ELSE
		move.b	(a0)+,d7
		lsl.w	#8,d7					;d7 = d7*256.
		IFD	SPIKE_TRACE
		jmp	spike_trace				;AmiGameBoy: stage 0 trace.
		ELSE
		jmp	(a1,d7.l)				;jump and emulate.
		ENDC
		ENDIF

f_xita:		rts

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		z80 emulator, %1011 = znhc
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

z80_start:	move.l	bank_address,a0				;the rom area.
		lea	z80_optcode_00,a1			;xx optcodes.
		move.l	gb_memory,a2				;pointer to pseudo ram.
		move.l	a0,a3					;a3 = base pointer.
		move.l	a0,z80_pc_base
		lea	z80_optc_CB00,a4			;cbxx optcodes.
		add.l	#$100,a0				;the beginning.

		move.l	#$00D8,d0
		move.l	#$0013,d1
		move.l	#$014D,d2
		move.l	#$0101,d3				;n = 1!
		move.l	#%00000101,d4
		move.l	#$fffe,d5				;the stack pointer.
		moveq.l	#0,d7

		move.b	#1,h_the_flag				;h = 1!

		move.b	#%0,mbc1_status
		IFND	NO_MBC1HI
		move.b	#1,mbc1_bank1
		clr.b	mbc1_bank2
		ENDC
		move.l	#1,mbc5_rom_bank			;b0, b1.
		rts						;exit init.

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		x/5 sweep
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

		cnop	0,4
z80_cpu_next_sweep:
		moveq.l	#0,d7
		IFND	NO_LINE114
		move.l	sweep_extra,a5				;AmiGameBoy: budget + carry.
		adda.l	z80_cycles,a5
		ELSE
		move.l	z80_cycles,a5
		ENDC
		IFD	IDLESKIP
		addq.l	#1,idle_sweeps
		tst.b	idle_on					;AmiGameBoy: parked in a poll loop?
		bne.w	idle_sweep
idle_sweep_run:
		ENDC
		IFND	NO_IDLESKIP
		IFND	SPIKE_TRACE
		tst.b	idl_state				;AmiGameBoy: a poll loop on record?
		bne.l	idl_sweep				;(exact skip, see idle_jr)
idl_sweep_run:
		ENDC
		ENDC

		IFGT	GAMEBOY_DEBUG
		jmp	debug_output
		ELSE

		move.b	(a0)+,d7
		lsl.w	#8,d7					;d7 = d7*256.
		IFD	SPIKE_TRACE
		jmp	spike_trace				;AmiGameBoy: stage 0 trace.
		ELSE
		jmp	(a1,d7.l)				;jump and emulate.
		ENDC
		ENDIF
		IFD	IDL_PAIR
		dcb.b	244,0					;AmiGameBoy: the hook above is 12 bytes.
		ENDC

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		push - command memory supervisor
;		INPUT:
;		d6	= h.B, l.B (a 16-bit value to be pushed).
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

		cnop	0,4
write_d6_stack:	subq.w	#1,d5
		move.l	d6,-(SP)
		lsr.w	#8,d6					;d6 = upper data (h.B).
		move.l	d5,d7

		move.l	gb_mem_jumps,a6
		jsr	([a6,d5.l*4])				;memory write.

		subq.w	#1,d5
		move.l	(SP)+,d6
		move.l	d5,d7					;d7 = 00BB, because
								;d5 = 00BB.
		move.l	gb_mem_jumps,a6
		jsr	([a6,d5.l*4])				;memory write.

		fetch_next_i

		cnop	0,4
write_d6_stackx:subq.w	#1,d5
		move.l	d6,-(SP)
		move.l	d5,d7
		lsr.w	#8,d6					;d6 = upper data (h.B).

		move.l	gb_mem_jumps,a6
		jsr	([a6,d5.l*4])				;memory write.

		subq.w	#1,d5
		move.l	(SP)+,d6
		move.l	d5,d7					;d7 = 00BB, because
								;d5 = 00BB.
		move.l	gb_mem_jumps,a6
		jsr	([a6,d5.l*4])				;memory write.
		rts

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		memory related subroutines and checks
;		INPUT:
;		d6	= the data (.B).
;		d7	= address for the write.
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

		cnop	0,4
echo_down:
		IFD	IDLESKIP
		addq.l	#1,idle_writes			;AmiGameBoy: RAM written (idle skip).
		ENDC
		lea	(a2,d7.l),a6
		move.b	d6,(a6)
		sub.l	#$2000,a6
		move.b	d6,(a6)
		rts

		cnop	0,4
echo_up:
		IFD	IDLESKIP
		addq.l	#1,idle_writes			;AmiGameBoy: RAM written (idle skip).
		ENDC
		lea	(a2,d7.l),a6
		move.b	d6,(a6)
		add.l	#$2000,a6
		move.b	d6,(a6)
		rts

		cnop	0,4
gb_mem_wr:
		IFD	IDLESKIP
		addq.l	#1,idle_writes			;AmiGameBoy: RAM written (idle skip).
		ENDC
		move.b	d6,(a2,d7.l)
		rts

		cnop	0,4
gb_mem_wr_denied:
		rts						;no write.

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		misc memory protection writes
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

		cnop	0,4
lcd_mode_write:	;btst	#7,d6
		;bne.s	lcd_mode_write_done

		;cmp.l	#144,gb_scanlines
		;blt.s	lcd_mode_write_done

		;or.b	#%10000000,d6

lcd_mode_write_done:
		IFND	NO_LCDONOFF			;AmiGameBoy: LCD on/off as hardware.
		lea	(a2,d7.l),a6			;a6 = $FF40.
		btst	#7,d6
		beq.s	lcd_mode_off
		btst	#7,(a6)
		bne.s	lcd_mode_store			;stays on.
		clr.b	4(a6)				;off -> on: LY = 0 at once, the
		st	lcd_restart			;picture restarts at line 0 from
		bclr	#2,1(a6)			;the next line boundary.
		tst.b	5(a6)				;LYC = 0: coincidence now.
		bne.s	lcd_mode_store
		bset	#2,1(a6)
		btst	#6,1(a6)
		beq.s	lcd_mode_store
		bset	#1,-$31(a6)			;IF bit 1 ($FF0F).
		bra.s	lcd_mode_store
lcd_mode_off:	btst	#7,(a6)
		beq.s	lcd_mode_store
		clr.b	4(a6)				;on -> off: LY 0, mode 0.
		and.b	#%11111100,1(a6)
lcd_mode_store:
		ENDC
		move.b	d6,(a2,d7.l)
		rts

		cnop	0,4
lcd_protect:	lea	(a2,d7.l),a6
		and.b	#%01111000,d6
		and.b	#%10000111,(a6)
		or.b	d6,(a6)
		IFND	NO_LCDOFFSTAT
		btst.b	#7,-1(a6)			;AmiGameBoy: no STAT write interrupt
		beq.s	lcd_write_no_irq		;with the LCD off.
		ENDC

		move.b	(a6),d6
		and.b	#%11,d6
		beq.s	lcd_write_irq
		cmp.b	#1,d6
		bne.s	lcd_write_no_irq

lcd_write_irq:	move.l	a2,a6			;bug in hardware.
		add.l	#$ff0f,a6
		bset.b	#1,(a6)			;lcd irq is about to happen.

lcd_write_no_irq:
		rts

		cnop	0,4
irq_protect_0f:	or.b	#%11100000,d6
;		cmp.b	(a2,d7.l),d6
;		beq.s	irq_protect_0f_exit
		move.b	d6,(a2,d7.l)
;		tst.b	i_flag
;		beq.s	irq_protect_ff_wowza
irq_protect_0f_exit:
		rts

		cnop	0,4
irq_protect_ff:	or.b	#%11100000,d6
;		cmp.b	(a2,d7.l),d6
;		beq.s	irq_protect_ff_exit
		move.b	d6,(a2,d7.l)
;		tst.b	i_flag
;		beq.s	irq_protect_ff_wowza
irq_protect_ff_exit:
		rts

		cnop	0,4
irq_protect_ff_wowza:
		move.l	a5,z80_cycles_left		;CHECK THIS ONE OUT WITH
		move.b	#1,z80_ei_return		;KIRBY 2!!!
		move.l	#1,a5
;		bchg.b	#1,$bfe001
		rts

		IFND	NO_TIMAWRITE
		cnop	0,4
tima_write:	move.b	d6,(a2,d7.l)			;AmiGameBoy: the counter lives in
		and.l	#$ff,d6				;freq_storage (x 4096); a write
		lsl.l	#8,d6				;to TIMA was overwritten at the
		lsl.l	#4,d6				;next sweep.
		move.l	d6,freq_storage
		rts
		ENDC

		cnop	0,4
timc_protect:	or.b	#%11111000,d6
		move.b	d6,(a2,d7.l)
		rts

		cnop	0,4
clear_divider:	move.b	#0,(a2,d7.l)
		IFND	NO_DIVRATE
		clr.b	div_frac				;AmiGameBoy: the whole counter resets.
		ENDC
		rts

		cnop	0,4
sio_register:	move.b	d6,(a2,d7.l)
		rts

		cnop	0,4
sio_control:	move.b	d6,(a2,d7.l)
		IFND	NO_SCBITS				;AmiGameBoy: SC bits 1-6 do not exist on a
		or.b	#$7e,(a2,d7.l)				;mono Game Boy and read 1 (a game's
		ENDC						;emulator check writes 0, wants $7C back).
		btst	#7,d6
		bne.s	sio_control_start
		rts

		cnop	0,4
sio_control_start:
		btst	#0,d6
		beq.s	sio_control_start_external

;		move.b	#$ff,-1(a2,d7.l)			;serial off!
		move.b	#8,transfer_counter
		rts

sio_control_start_external:
		rts

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		a rom write has occurred! 8O
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

		cnop	0,4
no_write:
rom_write:	rts					;exit the rom write.

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		memory related routines
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

		cnop	0,4
dma_execute:	move.l	a5,-(SP)
		IFND	NO_DMAREG
		move.b	d6,(a2,d7.l)			;AmiGameBoy: $FF46 reads back.
		ENDC
		and.l	#$ff,d6				;d6 = the address (.B).
		cmp.w	#$f1,d6
		ble.s	dma_start_ok
		sub.b	#$f1,d6

dma_start_ok:
;		bchg.b	#1,$bfe001

		tst.b	d6
		bge.s	dma_rom
dma_ram:	move.l	a2,a5				;do a ram read.
		bra.s	dma_move
dma_rom:	move.l	a3,a5				;do a rom read.

dma_move:	lsl.l	#8,d6				;input fixed.
		add.l	d6,a5				;a5 = input.
		move.l	a2,a6				;output is in ram.
		add.l	#$fe00,a6			;a6 = output (oam).
		moveq.l	#40-1,d7
dma_execute_mv:
		IFND	NO_DMAFULL
		move.l	(a5)+,(a6)+			;AmiGameBoy: plain copy (CGB uses the low attribute bits).
		ELSE
		move.l	(a5)+,d6
		and.l	#$fffffff0,d6
		and.l	#$0000000f,(a6)
		or.l	d6,(a6)
		addq.l	#4,a6
		ENDC
		dbra	d7,dma_execute_mv		;execute dma move.
		move.l	(SP)+,a5
		rts

		cnop	0,4
do_joystick:
		IFGT	GAMEBOY_DEBUG
		bsr.w	debug_joypad_wanted
		ENDIF

		cmp.b	#$03,d6				;type request?
		beq.s	do_joystick_type_request	;yes.

		btst	#5,d6
		beq.s	do_joystick_but
		btst	#4,d6
		beq.s	do_joystick_dir

		or.b	#%00001111,d6			;both keylines are disabled.
		IFND	NO_P1HIGH
		or.b	#%11000000,d6			;AmiGameBoy: bits 7-6 read as 1.
		ENDC
		move.b	d6,(a2,d7.l)
		rts

		cnop	0,4
do_joystick_but:btst	#4,d6
		beq.s	do_joystick_both

		move.l	d5,-(SP)
		move.b	buttons_byte,d5
		and.b	#%11110000,d6
		and.b	#%00001111,d5
		or.b	d6,d5
		IFND	NO_P1HIGH
		or.b	#%11000000,d5
		ENDC
		move.b	d5,(a2,d7.l)
		move.l	(SP)+,d5
		rts

		cnop	0,4
do_joystick_type_request:
		move.b	#$f0,d6				;normal gameboy.

do_joystick_both:
		movem.l	d5/d4,-(SP)
		move.b	directions_byte,d4
		move.b	buttons_byte,d5
		eor.b	#%11111111,d4
		eor.b	#%11111111,d5
		and.b	#%11110000,d6
		or.b	d4,d5
		or.b	d6,d5
		eor.b	#%00001111,d5
		IFND	NO_P1HIGH
		or.b	#%11000000,d5
		ENDC
		move.b	d5,(a2,d7.l)
		movem.l	(SP)+,d5/d4
		rts

		cnop	0,4
do_joystick_dir:btst	#5,d6
		beq.s	do_joystick_both

		move.l	d5,-(SP)
		move.b	directions_byte,d5
		and.b	#%11110000,d6
		and.b	#%00001111,d5
		or.b	d6,d5
		IFND	NO_P1HIGH
		or.b	#%11000000,d5
		ENDC
		move.b	d5,(a2,d7.l)
		move.l	(SP)+,d5
		rts

		cnop	0,4
ly_write:	move.b	#0,(a2,d7.l)
		rts

		cnop	0,4
lyc_write:	move.b	d6,(a2,d7.l)

		move.l	a2,a6
		add.l	#$ff00,a6

		btst.b	#7,$40(a6)			;lcd enabled?
		beq.s	kcmp_up				;no.

		btst.b	#1,irq_status_flags		;vbr effect?
		beq.s	kcmp_blank_no_filtering
		move.l	gb_scanlines,d7
;		beq.s	kcmp_up				;$00 is off limits.
		cmp.l	#$91,d7
		bge.s	kcmp_up				;$91-$99 are off limits, too.

kcmp_blank_no_filtering:
		move.b	$45(a6),d7			;d7 = ly compare / lyc.
		cmp.b	$44(a6),d7
		bne.s	klyc_clear			;not the same.
		bset.b	#2,$41(a6)			;coincidence occurred.

		btst.b	#6,$41(a6)			;interrupt?
		beq.s	kcmp_up				;nope. disabled.

		IFD	NO_IFIE				;AmiGameBoy: IF is set whatever IE says.
		btst.b	#1,$ff(a6)			;lcd controller irq enabled?
		beq.s	kcmp_up				;no.
		ENDC

kcmp_starts:
		IFGT	GAMEBOY_DEBUG
		bsr.w	debug_blank
		ENDIF

		bset.b	#1,$0f(a6)			;lcd occurred.
		bset.b	#2,irq_status_flags		;lyc occurred.
		bra.s	kcmp_up				;skip vbr.

klyc_clear:	bclr.b	#2,$41(a6)			;no coincidence.
kcmp_up:	rts

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		mappers
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

		cnop	0,4
mbc1_rom_switch:
;		tst.b	mbc1_status
;		bne.s	mbc1_in_4_32

		IFND	NO_MBC1HI				;AmiGameBoy: the MBC1 has a 5-bit bank
		move.l	cartridge,a6				;register (0 selects 1) and two upper
		cmp.b	#$ff,$147(a6)				;lines from the $4000 register: banks
		beq.s	mbc1_plain				;$20 and up of 1 MB and 2 MB cartridges
		and.l	#$1f,d6					;were out of reach. (HuC1, which shares
		bne.s	mbc1_bank1_ok				;these handlers, keeps its one register.)
		moveq.l	#1,d6
mbc1_bank1_ok:	move.b	d6,mbc1_bank1
mbc1_rom_set:	moveq.l	#0,d7
		move.b	mbc1_bank2,d7
		lsl.w	#5,d7
		or.l	d7,d6
		and.l	rom_banks_mask,d6
		cmp.w	#1,d6					;bank 1 is in pair 0 (the only pair of a
		bhi.s	mbc1_rom_switch_in_limit			;32 KB cartridge).
		moveq.l	#0,d6
		bra.s	mbc1_rom_switch_in_limit
mbc1_plain:
		ENDC
		and.l	#$ff,d6
mbc1_in_16_8:	cmp.l	rom_banks_mask,d6
		ble.s	mbc1_rom_switch_in_limit
		sub.l	rom_banks_mask,d6
		bra.s	mbc1_in_16_8

mbc1_rom_switch_in_limit:

		IFGT	GAMEBOY_DEBUG
		move.b	d6,rom_bank_activated
		ENDIF

		lsl.l	#8,d6
		lsl.l	#7,d6					;d6 = d6 * $8000.
		add.l	rom_32k,d6				;rom pointer.
		move.l	d6,bank_address
		move.l	d6,a3					;update rom pointer.

		sub.l	z80_pc_base,a0
		move.w	a0,d7
		blt.s	pc_in_ram_mbc1
		add.l	d6,a0					;new rom address base.
		move.l	d6,z80_pc_base
		rts

		cnop	0,4
pc_in_ram_mbc1:	add.l	a2,a0					;old ram address base.
		rts

		cnop	0,4
mbc1_in_4_32:	rts

		cnop	0,4
mbc1_rom_mode_select:
		and.b	#%1,d6
		move.b	d6,mbc1_status
		rts

		cnop	0,4
mbc1_rom_switch_two_address_lines:
		IFND	NO_MBC1HI				;AmiGameBoy: the two upper ROM bank lines.
		move.l	cartridge,a6				;(Mode 1's remap of $0000-$3FFF to bank
		cmp.b	#$ff,$147(a6)				;$20/$40/$60 is not done.)
		beq.s	mbc1_bank2_none
		and.b	#%11,d6
		move.b	d6,mbc1_bank2
		moveq.l	#0,d6
		move.b	mbc1_bank1,d6
		bra.w	mbc1_rom_set
mbc1_bank2_none:
		rts
		ELSE
		tst.b	mbc1_status
		bne.s	mbc1_rom_switch_two_address_lines_4_32

								;support for 1 & 2
								;MB cartridges!!!
		rts						;not here. ;)
		ENDC

		cnop	0,4
mbc1_rom_switch_two_address_lines_4_32:
		rts

		cnop	0,4
mbc1_ram_protection:
		tst.b	mbc1_status
		beq.s	mbc1_ram_protection_no_changes

		and.b	#%00001111,d6
		move.b	d6,mbc1_ram_protection_status
		rts

		cnop	0,4
mbc1_ram_protection_no_changes:
		rts

		cnop	0,4
mbc1_ram_switch_with_two_rom_address_lines:
;		tst.b	mbc1_status
;		bne.s	mbc1_ram_switch_with_two_rom_address_lines_change_ram_bank
;								;support for 1 & 2
;								;MB cartridges!!!
;		rts						;not here. ;)

		IFND	NO_MBC1HI				;AmiGameBoy: more than 32 ROM banks: the
		cmp.l	#31,rom_banks_mask			;register is the upper ROM bank lines
		bgt.w	mbc1_rom_switch_two_address_lines	;(HuC1 is turned back there).
		ENDC
mbc1_ram_switch_with_two_rom_address_lines_change_ram_bank:
		and.l	ram_banks_mask,d6

		move.l	ram_bank_no,d7
		cmp.b	d6,d7
		beq.s	mbc1_exit

		lsl.l	#8,d7
		lsl.l	#5,d7					;8kb banks.
		add.l	memory_banks,d7				;base address.
		move.l	d6,ram_bank_no				;new bank number.

		move.l	d7,a6					;a6 = output.
		move.l	a5,-(SP)
		move.l	a2,a5
		add.l	#$A000,a5				;a5 = input.
		move.w	#$2000/4/4/2-1,d7
backup_ram:	move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		dbra	d7,backup_ram

		move.l	a2,a6
		add.l	#$A000,a6				;a6 = output.
		lsl.l	#8,d6
		lsl.l	#5,d6					;8kb banks.
		add.l	memory_banks,d6
		move.l	d6,a5					;a5 = input.

		move.w	#$2000/4/4/2-1,d7
restore_ram:	move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		dbra	d7,restore_ram

		moveq.l	#0,d7
		move.l	(SP)+,a5
mbc1_exit:	rts

		cnop	0,4
mbc2_ram_protection:
		and.b	#%1,d6
		move.b	d6,mbc2_ram_protection_status
		rts

		cnop	0,4
mbc2_rom_switch:and.l	#$ff,d6
		cmp.l	rom_banks_mask,d6
		ble.s	mbc2_rom_switch_in_limit
		sub.l	rom_banks_mask,d6
		bra.s	mbc2_rom_switch

mbc2_rom_switch_in_limit:

		IFGT	GAMEBOY_DEBUG
		move.b	d6,rom_bank_activated
		ENDIF

		lsl.l	#8,d6
		lsl.l	#7,d6					;d6 = d6 * $8000.
		add.l	rom_32k,d6				;rom pointer.
		move.l	d6,bank_address
		move.l	d6,a3					;update rom pointer.

		sub.l	z80_pc_base,a0
		move.w	a0,d7
		blt.s	pc_in_ram_mbc2
		add.l	d6,a0					;new rom address base.
		move.l	d6,z80_pc_base
		rts

		cnop	0,4
pc_in_ram_mbc2:	add.l	a2,a0					;old ram address base.
		rts

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		MBC5
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

		cnop	0,4
mbc5_ramg:	rts						;external ram on/off.

		cnop	0,4
mbc5_romb0:	move.b	d6,mbc5_rom_bank0
		move.l	mbc5_rom_bank,d6

mbc5_romb0_switch:
		cmp.l	rom_banks_mask,d6
		ble.s	mbc5_romb0_switch_in_limit
		sub.l	rom_banks_mask,d6
		bra.s	mbc5_romb0_switch

mbc5_romb0_switch_in_limit:

		IFGT	GAMEBOY_DEBUG
		move.b	d6,rom_bank_activated
		ENDIF

		lsl.l	#8,d6
		lsl.l	#7,d6					;d6 = d6 * $8000.
		add.l	rom_32k,d6				;rom pointer.
		move.l	d6,bank_address
		move.l	d6,a3

		sub.l	z80_pc_base,a0
		move.w	a0,d7
		blt.s	pc_in_ram_mbc5_0
		add.l	d6,a0
		move.l	d6,z80_pc_base
		rts

		cnop	0,4
pc_in_ram_mbc5_0:
		add.l	a2,a0
		rts

		cnop	0,4
mbc5_romb1:	move.b	d6,mbc5_rom_bank1
		move.l	mbc5_rom_bank,d6

mbc5_romb1_switch:
		cmp.l	rom_banks_mask,d6
		ble.s	mbc5_romb1_switch_in_limit
		sub.l	rom_banks_mask,d6
		bra.s	mbc5_romb1_switch

mbc5_romb1_switch_in_limit:

		IFGT	GAMEBOY_DEBUG
		move.b	d6,rom_bank_activated
		ENDIF

		lsl.l	#8,d6
		lsl.l	#7,d6					;d6 = d6 * $8000.
		add.l	rom_32k,d6				;rom pointer.
		move.l	d6,bank_address
		move.l	d6,a3

		sub.l	z80_pc_base,a0
		move.w	a0,d7
		blt.s	pc_in_ram_mbc5_1
		add.l	d6,a0
		move.l	d6,z80_pc_base
		rts

		cnop	0,4
pc_in_ram_mbc5_1:
		add.l	a2,a0
		rts

		cnop	0,4
mbc5_ramb:	and.l	ram_banks_mask,d6
		move.l	ram_bank_no,d7
		cmp.b	d6,d7
		beq.s	mbc5_exit

		lsl.l	#8,d7
		lsl.l	#5,d7					;8kb banks.
		add.l	memory_banks,d7				;base address.
		move.l	d6,ram_bank_no				;new bank number.

		move.l	d7,a6					;a6 = output.
		move.l	a5,-(SP)
		move.l	a2,a5
		add.l	#$A000,a5				;a5 = input.
		move.w	#$2000/4/4/2-1,d7
backup_ram_x:	move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		dbra	d7,backup_ram_x

		move.l	a2,a6
		add.l	#$A000,a6				;a6 = output.
		lsl.l	#8,d6
		lsl.l	#5,d6					;8kb banks.
		add.l	memory_banks,d6
		move.l	d6,a5					;a5 = input.

		move.w	#$2000/4/4/2-1,d7
restore_ram_x:	move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		dbra	d7,restore_ram_x

		moveq.l	#0,d7
		move.l	(SP)+,a5
mbc5_exit:	rts

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		MBC3
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

		cnop	0,4
mbc3_rom_switch:and.l	#$ff,d6
		cmp.l	rom_banks_mask,d6
		ble.s	mbc3_rom_switch_in_limit
		sub.l	rom_banks_mask,d6
		bra.s	mbc3_rom_switch

mbc3_rom_switch_in_limit:

		IFGT	GAMEBOY_DEBUG
		move.b	d6,rom_bank_activated
		ENDIF

		lsl.l	#8,d6
		lsl.l	#7,d6					;d6 = d6 * $8000.
		add.l	rom_32k,d6				;rom pointer.
		move.l	d6,bank_address
		move.l	d6,a3					;update rom pointer.

		sub.l	z80_pc_base,a0
		move.w	a0,d7
		blt.s	pc_in_ram_mbc3
		add.l	d6,a0					;new rom address base.
		move.l	d6,z80_pc_base
		rts

		cnop	0,4
pc_in_ram_mbc3:	add.l	a2,a0					;old ram address base.
		rts

		cnop	0,4
mbc3_ram_protection:
		move.b	d6,mbc3_ram_protection_status
mbc3_exit:	rts

		cnop	0,4
mbc3_ram_switch_change_ram_bank:
		and.l	ram_banks_mask,d6
		move.l	ram_bank_no,d7
		cmp.b	d7,d6
		beq.s	mbc3_exit

		lsl.l	#8,d7
		lsl.l	#5,d7					;8kb banks.
		add.l	memory_banks,d7				;base address.
		move.l	d6,ram_bank_no				;new bank number.

		move.l	d7,a6					;a6 = output.
		move.l	a5,-(SP)
		move.l	a2,a5
		add.l	#$A000,a5				;a5 = input.
		move.w	#$2000/4/4/2-1,d7
backup_ram_n:	move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		dbra	d7,backup_ram_n

		move.l	a2,a6
		add.l	#$A000,a6				;a6 = output.
		lsl.l	#8,d6
		lsl.l	#5,d6					;8kb banks.
		add.l	memory_banks,d6
		move.l	d6,a5					;a5 = input.

		move.w	#$2000/4/4/2-1,d7
restore_ram_n:	move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		move.l	(a5)+,(a6)+
		dbra	d7,restore_ram_n

		moveq.l	#0,d7
		move.l	(SP)+,a5
		rts

		cnop	0,4
mbc3_no_ram_switch:
		cmp.w	#$8,d6
		blt.s	mbc3_no_ram_switch_exit
		cmp.w	#$c,d6
		bgt.s	mbc3_no_ram_switch_exit

		sub.b	#$8,d6
		lea	mbc3_latched_sec,a6
		move.b	(a6,d6.w),d7
		move.w	#$2000-1,d6
		move.l	a2,a6
		add.l	#$a000,a6

mbc3_output_clock_data:
		move.b	d7,(a6)+
		dbra	d6,mbc3_output_clock_data

mbc3_no_ram_switch_exit:
		rts

		cnop	0,4
mbc3_latch_clock_counter_data:
		move.b	mbc3_latch_b,mbc3_latch_a
		move.b	d6,mbc3_latch_b

		tst.b	mbc3_latch_a
		bne.s	mbc3_latch_clock_counter_data_exit
		cmp.b	#1,d6
		bne.s	mbc3_latch_clock_counter_data_exit

mbc3_latch_clock_counter_data_execute_latch:
		move.b	mbc3_sec,mbc3_latched_sec
		move.b	mbc3_min,mbc3_latched_min
		move.b	mbc3_hrs,mbc3_latched_hrs
		move.b	mbc3_dayl,mbc3_latched_dayl
		move.b	mbc3_dayh,mbc3_latched_dayh

mbc3_latch_clock_counter_data_exit:
		rts

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		RETI back
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

		cnop	0,4
reti_back:	move.l	a2,a6
		add.l	#$ff0f,a6				;(interrupt flags).
		move.b	(a6),d7
		and.b	#%11111,d7
		IFND	NO_IFIE
		and.b	$f0(a6),d7			;AmiGameBoy: IE ($FFFF) mask.
		ENDC
		IFND	NO_EIHALT
		bne.s	reti_back_irq
		tst.b	z80_halt			;AmiGameBoy: EI;HALT, nothing pending:
		beq.s	no_more_irqs			;stay halted (Wzonka ran on past the
		rts					;HALT to the end of the sweep).
reti_back_irq:
		IFD	IDL_PAIR
		clr.w	z80_halt			;(with idl_state)
		ELSE
		clr.b	z80_halt			;Pending: the HALT ends at once (the
		ENDC
		ELSE					;CPU halted again after the RETI).
		beq.s	no_more_irqs
		ENDC

		IFD	IDL_PAIR
		IFD	NO_EIHALT
		clr.b	idl_state			;AmiGameBoy: a dispatch ends the poll-loop record.
		ENDC
		ELSE
		IFND	NO_IDLESKIP
		IFND	SPIKE_TRACE
		clr.b	idl_state			;AmiGameBoy: a dispatch ends the poll-loop record.
		ENDC
		ENDC
		ENDC
		move.l	a0,d6					;stack the pc.
		sub.l	z80_pc_base,d6
		move.b	#1,i_flag				;disable interrupts.
		IFND	NO_IRQ5
		subq.l	#5,a5					;AmiGameBoy: dispatch takes 5 M-cycles.
		ENDC

		btst	#0,d7
		bne.s	irq_i
		btst	#1,d7
		bne.s	irq_ii
		btst	#2,d7
		bne.s	irq_iii
		btst	#3,d7
		bne.w	irq_iv

irq_v:		bclr.b	#4,(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		subq.w	#2,d5
		ror.w	#8,d6
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$60(a3),a0
		move.l	a3,z80_pc_base				;rom base.

no_more_irqs:
		fetch_next_i

		cnop	0,4
irq_i:		bclr.b	#0,(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		subq.w	#2,d5
		ror.w	#8,d6
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$40(a3),a0
		move.l	a3,z80_pc_base				;rom base.

		fetch_next_i

		cnop	0,4
irq_ii:		bclr.b	#1,(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		subq.w	#2,d5
		ror.w	#8,d6
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$48(a3),a0
		move.l	a3,z80_pc_base				;rom base.

		fetch_next_i

		cnop	0,4
irq_iii:	bclr.b	#2,(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		subq.w	#2,d5
		ror.w	#8,d6
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$50(a3),a0
		move.l	a3,z80_pc_base				;rom base.

		fetch_next_i

		cnop	0,4
irq_iv:		bclr.b	#3,(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		subq.w	#2,d5
		ror.w	#8,d6
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$58(a3),a0
		move.l	a3,z80_pc_base				;rom base.

		fetch_next_i

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		misc memory reads
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

READ_D2_TO_D6:	MACRO
		tst.w	d2
		blt.s	read_to_\@
		move.b	(a3,d2.l),d6
		bra.s	read_to_exit_\@
		cnop	0,4
read_to_\@:	GBC_RD	d2,d6
read_to_exit_\@:	
		ENDM

READW_D5_TO_D7:	MACRO
		tst.w	d5
		blt.s	readw_to_\@
		move.w	(a3,d5.l),d7
		bra.s	readw_to_exit_\@
		cnop	0,4
readw_to_\@:	move.w	(a2,d5.l),d7
readw_to_exit_\@:	
		ENDM

; AmiGameBoy GBC: a CPU byte read from RAM ($8000-$FFFF). In HY_GBC builds VRAM ($8000-$9FFF)
; goes through gbc_vrd (gbc.s: the selected bank, $FF while the LCD draws a line); without
; HY_GBC these are Wzonka's own instructions.
GBC_RD:		MACRO				; \1 = address register (upper word 0), \2 = destination
		IFD	HY_GBC
		cmp.w	#$a000,\1
		bcc.s	gbc_rdram\@
		jsr	gbc_vrd_\1
		move.b	d6,\2
		bra.s	gbc_rdx\@
gbc_rdram\@:
		ENDC
		move.b	(a2,\1.l),\2
gbc_rdx\@:
		ENDM

GBC_BTST:	MACRO				; BIT \1,(HL) from RAM: Z into d4 as Wzonka
		IFD	HY_GBC
		cmp.w	#$a000,d2
		bcc.s	gbc_btram\@
		jsr	gbc_vrd_d2
		move.w	d4,CCR
		btst	#\1,d6
		bra.s	gbc_btx\@
gbc_btram\@:
		ENDC
		move.w	d4,CCR
		btst.b	#\1,(a2,d2.l)
gbc_btx\@:
		ENDM

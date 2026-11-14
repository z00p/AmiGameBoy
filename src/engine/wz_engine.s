; Taken from Wzonka-Lad 1.03 (Aminet misc/emu/Wzonka-Lad), GPL-2.
; Wzonka-Lad (C) Ville Helin 1996-1999; GPL release and changes by
; Ventzislav Tzvetkov 2003-2004. Changes for AmiGameBoy (C) 2026, same licence;
; see git history. Original file: wz.s (extract, line ranges noted below)

		IFND	NO_IDLESKIP			;AmiGameBoy: the poll-loop skip's cheaper hook
		IFND	SPIKE_TRACE			;(idle_jr, idle_go; z80_full_III.s JR cc).
		IFND	NO_IDLEQUICK
IDL_QUICK	equ	1
		ENDC
		ENDC
		ENDC

		IFND	NO_IDLESKIP			;AmiGameBoy: the poll-loop skip in the layout that
		IFND	SPIKE_TRACE			;keeps the engine's (z80_misc.s, idle_jr).
		IFND	NO_IDLEPAD
IDL_PAIR	equ	1
		ENDC
		ENDC
		ENDC

; ---- wz.s 7867-7927: ROM image builder (32 KB bank pairs)
gg_patch_apply:	clr.b	rom_type
		move.l	cartridge_data,a0

		move.l	file_length,d7
		divu.w	#16384,d7

		move.l	d7,d0
		swap	d0
		tst.w	d0
		beq.s	rom_size_okay

		sub.w	#512,d0
		bne.w	load_error_unknown_size

		move.b	#1,rom_type
		add.l	#512,a0

rom_size_okay:	and.l	#$ffff,d7
		move.l	a0,cartridge
		move.l	a0,a1
		move.l	rom_32k,a2

		IFND	NO_MBC5IMG				;AmiGameBoy: every MBC5 type ($19-$1E), not
		move.b	$147(a0),d1				;only $19, gets bank 0 twice as pair 0: the
		sub.b	#$19,d1					;MBC5 can select bank 0. ($1A-$1E gave bank 1
		cmp.b	#$1e-$19,d1				;for it.)
		bhi.s	rom_mbc_is_not_5
		ELSE
		cmp.b	#$19,$147(a0)
		bne.s	rom_mbc_is_not_5
		ENDC

		move.w	#$4000/4-1,d1
rom_mbc5_32k_0:	move.l	(a1)+,(a2)+
		dbra	d1,rom_mbc5_32k_0
		move.l	a0,a1
		move.w	#$4000/4-1,d1
rom_mbc5_32k_1:	move.l	(a1)+,(a2)+
		dbra	d1,rom_mbc5_32k_1

		IFND	NO_MBC5IMG				;AmiGameBoy: a1 is at bank 1 here: pairs
		subq.l	#1,d7					;(0,1)..(0,n-1) follow, so bank n is pair n.
		bgt.s	rom_32k_n_more				;(Through rom_bank_0_done a1 went back to
		bra.s	rom_32k_created				;bank 0 and every bank of a type $19
		ELSE						;cartridge sat one pair too high, the last
		bra.s	rom_bank_0_done				;one missing.)
		ENDC

rom_mbc_is_not_5:
		move.w	#$8000/4-1,d1
rom_32k_0:	move.l	(a1)+,(a2)+
		dbra	d1,rom_32k_0

rom_bank_0_done:subq.l	#2,d7
		beq.s	rom_32k_created

		sub.l	#$4000,a1
		addq.l	#1,d7

rom_32k_n_more:	move.w	#$4000/4-1,d1
		move.l	a0,a3
rom_32k_n_0:	move.l	(a3)+,(a2)+
		dbra	d1,rom_32k_n_0

		move.w	#$4000/4-1,d1
rom_32k_n:	move.l	(a1)+,(a2)+
		dbra	d1,rom_32k_n

		subq.l	#1,d7
		bne.s	rom_32k_n_more

rom_32k_created:move.l	rom_32k,bank_address		;use area b0, b1.
		IFND	NO_MBC5IMG				;AmiGameBoy: an MBC5 starts with bank 1
		move.b	$147(a0),d1				;at $4000 (pair 1; pair 0 is bank 0 twice).
		sub.b	#$19,d1
		cmp.b	#$1e-$19,d1
		bhi.s	rom_32k_not_5
		add.l	#$8000,bank_address
rom_32k_not_5:
		ENDC
		moveq.l	#0,d0				;no errors.
		rts

; ---- wz.s 8046-8119: compute_jmp_lst: write table from the mapper lists
compute_jmp_lst:move.l	a0,d0
		beq.w	no_jmp_list

		lea	mapper_list,a2
		moveq.l	#0,d0

		move.b	$147(a0),d0			;d0 = cartridge type.
		cmp.b	#$ff,d0
		bne.s	no_huc1

		move.l	#mapper_huc1_ram_battery,a2
		bra.s	mapper_ok_n

no_huc1:	move.l	(a2,d0.l*4),a2			;mapper selected.

mapper_ok_n:	move.b	$149(a0),d0			;d0 = amount of ram.
		and.b	#%11,d0				;max values.
		move.l	(a2,d0.l*4),a2			;list selected.

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		INPUT:
;		a2	= cartridge memory structure
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

		move.l	gb_mem_jumps,a1			;a1 = output table.
		move.l	#gb_mem_wr,d0
		move.l	#$10000,d1
gb_mem_init:	move.l	d0,(a1)+
		subq.l	#1,d1
		bne.s	gb_mem_init

		move.l	gb_mem_jumps,a1
		move.l	(a2)+,d0			;dbra amount of sections.
		move.l	(a2)+,d1			;dbra size of a section.
create_banking:	move.l	d1,d2
		move.l	(a2)+,d3

create_banking_move_data:
		move.l	d3,(a1)+
		dbra	d2,create_banking_move_data
		dbra	d0,create_banking

		move.l	gb_mem_jumps,a1
		add.l	#$c000*4,a1
		move.w	#$de00-$c000-1,d0
		move.l	#echo_up,d1
gb_mem_up:	move.l	d1,(a1)+
		dbra	d0,gb_mem_up

		move.l	gb_mem_jumps,a1
		add.l	#$e000*4,a1
		move.w	#$fe00-$e000-1,d0
		move.l	#echo_down,d1
gb_mem_down:	move.l	d1,(a1)+
		dbra	d0,gb_mem_down

		move.l	gb_mem_jumps,a1
		add.l	#$ff00*4,a1
		lea	ffxx_jmp_table,a2
		move.w	#$100-1,d0
gb_mem_ffxx:	move.l	(a2)+,(a1)+
		dbra	d0,gb_mem_ffxx

		move.l	gb_mem_jumps,a1
		add.l	#$fea0*4,a1
		move.l	#no_write,d1
		move.w	#$ff00-$fea0-1,d0
gb_mem_no_write:move.l	d1,(a1)+
		dbra	d0,gb_mem_no_write

		move.l	exec_base,a6
		jsr	CacheClearU(a6)			;clear the caches.

no_jmp_list:	rts

; ---- wz.s 8260-8938: run_cartridge, frame loop (154 lines x 5 sweeps), input_irq
run_cartridge:

use_loaded_battery_ram_x:
		move.l	memory_banks,a0
		move.l	gb_memory,a1
		add.l	#$A000,a1
		move.w	#$2000/4-1,d0
copy_ram_banks_x:
		move.l	(a0)+,(a1)+
		dbra	d0,copy_ram_banks_x

ram_banks_done:
		IFD	NO_RAMKEEP			;AmiGameBoy: a0 is memory_banks+$2000
		move.l	cartridge,a1			;a0 = $c000.
		add.l	#$100,a1			;here (meant: $C000), so this wrote
		move.w	#$2000/4-1,d0			;cartridge bytes over battery banks
randomize_ram_1:move.l	(a1)+,(a0)+			;1-2. Work RAM stays clear.
		dbra	d0,randomize_ram_1

		move.w	#($fe00-$e000)/4-1,d0		;a0 = $e000.
randomize_ram_2:move.l	(a1)+,(a0)+
		dbra	d0,randomize_ram_2
		ENDC

		move.l	gb_memory,a0
		add.l	#$ff4c,a0
		moveq.l	#$34-1,d0
clear_misc_registers:
		IFD	NO_IOFF
		clr.b	(a0)+
		ELSE					;AmiGameBoy: $FF4C-$FF7F do not exist on a
		st	(a0)+				;mono Game Boy and read $FF (writes are
		ENDC					;already dropped). Games made for both
		dbra	d0,clear_misc_registers	;models poll them: a wait on HDMA5 bit 7
							;($FF55) never ended while it read 0.

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		move on with the inits
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

		bsr.w	gb_memory_at_start

		move.b	#$cf,buttons_byte
		move.b	#$cf,directions_byte
		move.b	#$cf,buttons_byte_o
		move.b	#$cf,directions_byte_o

		clr.b	transfer_counter

		move.b	#1,i_flag			;disable interrupts.
		clr.b	z80_halt			;CPU is not halted.

		move.l	exec_base,a6
		jsr	CacheClearU(a6)			;any help?

		bsr.w	z80_start			;do the inits.
		IFD	HY_GBC
		jsr	gbc_start			;AmiGameBoy GBC: CGB hand-over state.
		ENDC
		bsr.w	push_z80			;push all the registers.

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		the gameboy loop
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

cartridge_loop:	
		IFGT	GAMEBOY_DEBUG
		clr.b	debug_exit
		ENDIF

		move.l	#h_values,h_values_indexed
		bsr.w	pull_z80			;pull all the registers.

		move.l	a2,a6
		add.l	#$ff00,a6
		clr.l	gb_scanlines			;start from scanline zero.
		clr.b	$44(a6)				;scanline zero.
		IFND	NO_START144			;AmiGameBoy: the boot ROM hands over in
		tst.b	start144_done			;VBlank at LY 144, so the first frame
		bne.s	start144_skip			;starts there.
		st	start144_done
		move.l	#144,gb_scanlines
		move.b	#144,$44(a6)
		move.l	#h_values+144*5,h_values_indexed
		IFD	HY_GBC
		tst.b	gbc_mode			;AmiGameBoy GBC: the CGB boot ROM hands
		beq.s	start144_skip			;over at LY 146.
		move.l	#146,gb_scanlines
		move.b	#146,$44(a6)
		move.l	#h_values+146*5,h_values_indexed
		ENDC
start144_skip:
		ENDC
		IFND	NO_LCDONOFF			;AmiGameBoy: LCD switched on during
		tst.b	lcd_restart			;the last frame: this line 0 is the
		beq.s	lcd_restart_none_f		;restart.
		clr.b	lcd_restart
		st	skip_lyc_once
lcd_restart_none_f:
		ENDC

next_sline:
		IFD	HYBRID
		tst.l	gb_scanlines			;AmiGameBoy hybrid: top-of-picture
		bne.s	hy_not_line0			;registers at LY 0.
		bsr.w	hybrid_line0
hy_not_line0:
		ENDC
		IFGT	GAMEBOY_DEBUG
		bsr.w	debug_scanline_out
		ENDIF

		IFLE	Z80_MODE

		cmp.l	#1,gb_scanlines
		bne.s	cmp_blank
		bclr.b	#1,irq_status_flags		;past $00, no vbr effect.

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		execute a line comparison irq if enabled
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

cmp_blank:	btst.b	#7,$40(a6)			;lcd enabled?
		beq.s	cmp_up				;no.
		IFND	NO_LCDONOFF			;AmiGameBoy: LY=LYC was checked when
		tst.b	skip_lyc_once			;the LCD came on; no new edge on the
		beq.s	cmp_lyc_normal			;restarted line 0.
		clr.b	skip_lyc_once
		bra.w	cmp_up
cmp_lyc_normal:
		ENDC

		btst.b	#1,irq_status_flags		;vbr effect?
		beq.s	cmp_blank_no_filtering

;		move.l	gb_scanlines,d7
;;		beq.s	cmp_up				;$00 is off limits.
;		cmp.l	#$91,d7
                cmp.l   #$91,gb_scanlines
		bge.s	cmp_up				;$91-$99 are off limits, too.

cmp_blank_no_filtering:
		move.b	$45(a6),d7			;d7 = ly compare / lyc.
		cmp.b	$44(a6),d7
		bne.s	lyc_clear			;not the same.
		bset.b	#2,$41(a6)			;coincidence occurred.

		btst.b	#6,$41(a6)			;interrupt?
		beq.s	cmp_up				;nope. disabled.

		IFD	NO_IFIE				;AmiGameBoy: IF is set whatever IE says.
		btst.b	#1,$ff(a6)			;lcd controller irq enabled?
		beq.s	cmp_up				;no.
		ENDC

cmp_starts:
		IFGT	GAMEBOY_DEBUG
		bsr.w	debug_blank
		ENDIF

		bset.b	#1,$0f(a6)			;lcd occurred.
		bset.b	#2,irq_status_flags		;lyc occurred.
		bra.s	cmp_up				;skip vbr.

lyc_clear:	bclr.b	#2,$41(a6)			;no coincidence.
cmp_up:

		ENDIF

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		0/4
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

		move.l	gb_scanlines,d7
		cmp.b	#40,d7
		beq.s	input_time
		cmp.b	#80,d7
		beq.s	input_time
		IFLE	Z80_MODE
		cmp.b	#120,d7
		beq.s	input_time
		ENDIF
		bra.s	no_input_this_time

input_time:	movem.l	d0-d6/a0-a6,-(SP)
		bsr.w	inputs_read			;do the joystick input.
		movem.l	(SP)+,d0-d6/a0-a6
		bsr.w	input_irq

no_input_this_time:
		IFLE	Z80_MODE
		move.b	$07(a6),d7			;d7 = timer control byte.
		btst	#2,d7				;0 = stopped / 1 = counting.
		beq.s	no_timer_update_0		;0! no update.
		bsr.w	irq_timer
no_timer_update_0:
		ENDIF

		and.b	#%11111100,$41(a6)

		move.l	h_values_indexed,a5
		move.b	(a5),d6
		IFND	NO_LCDOFFSTAT
		btst.b	#7,$40(a6)			;AmiGameBoy: LCD off: STAT mode stays 0
		bne.s	lcdoff_stat_0			;(Tobu Tobu Girl's VRAM copy waits on
		moveq	#0,d6				;STAT bit 1 with the LCD off too).
lcdoff_stat_0:
		ENDC
		or.b	d6,$41(a6)

		IFLE	Z80_MODE

		cmp.l	#143,gb_scanlines
		bne.s	no_vbr_lcd
		btst.b	#2,irq_status_flags		;lyc occurred?
		bne.s	no_lcd_irq_emulation_0		;mask vbr lcd irq out.

no_vbr_lcd:	cmp.l	#144,gb_scanlines
		bgt.s	no_lcd_irq_emulation_0
;		tst.b	i_flag
;		bne.s	no_lcd_irq_emulation_0
;		btst.b	#1,$ff(a6)			;lcd controller irq?
;		beq.s	no_lcd_irq_emulation_0		;no. quit.

		bsr.w	lcd_irq_eh

no_lcd_irq_emulation_0:
		ENDIF

		cmp.l	#144,gb_scanlines
		bne.s	no_vbr_blank			;no vbr interrupt.

		IFD	HYBRID
		bsr.w	hybrid_frame			;AmiGameBoy hybrid: display build, pads.
		ENDC
		IFD	SPIKE
		IFND	SPIKE_AT153
		bsr.w	spike_frame			;AmiGameBoy stage 0 hook: frame ends
		ENDC					;at LY 144, as Mesen's endFrame.
		ENDC
vbr_blank:	btst.b	#7,$40(a6)			;lcd operation?
		beq.s	no_vbr_blank			;no. quit.

		IFD	NO_IFIE				;AmiGameBoy: IF is set whatever IE says.
		btst.b	#0,$ff(a6)			;vbr irq?
		beq.s	no_vbr_blank			;no. quit.
		ENDC

		bset.b	#1,irq_status_flags
		IFD	HY_GBC
		IFND	NO_VBLLATE			;AmiGameBoy GBC: a running CPU sees LY 144
		tst.b	z80_halt			;before the VBlank IF (set at sweep 1,
		bne.s	gbc_vbn				;after a short sweep 0).
		st	gbc_vbl_late
		bra.s	gbc_vbx
gbc_vbn:
		ENDC
		ENDC
		bset.b	#0,$0f(a6)			;vbr occurred.
gbc_vbx:

		IFGT	GAMEBOY_DEBUG
		bsr.w	debug_vbr
		ENDIF

no_vbr_blank:	move.b	$0f(a6),d7
		addq.l	#1,h_values_indexed
		and.b	#%11111,d7
		IFND	NO_IFIE
		and.b	$ff(a6),d7			;AmiGameBoy: only IF bits enabled in IE.
		ENDC
		beq.s	no_interrupts_0

		tst.b	i_flag
		bne.s	no_interrupts_0

dehalting_z80_0:
		IFD	HY_GBC
		IFND	NO_VBLLATE
		tst.b	gbc_vbl_late			;AmiGameBoy GBC: another interrupt dispatches
		beq.s	gbc_vld0			;now: VBlank joins it at once, as before.
		sf	gbc_vbl_late
		bset.b	#0,$0f(a6)
		btst.b	#0,$ff(a6)
		beq.s	gbc_vld0
		bset	#0,d7
gbc_vld0:
		ENDC
		ENDC
		IFND	NO_IRQ5
		subq.l	#5,sweep_extra			;AmiGameBoy: dispatch takes 5 M-cycles.
		ENDC
		IFD	IDLESKIP
		clr.l	idle_snap			;AmiGameBoy: an interrupt ends any idle match.
		ENDC
		IFND	IDL_PAIR
		IFND	NO_IDLESKIP
		IFND	SPIKE_TRACE
		clr.b	idl_state			;AmiGameBoy: a dispatch ends the poll-loop record.
		ENDC
		ENDC
		ENDC
		move.l	a0,d6				;stack the pc.
		sub.l	z80_pc_base,d6
		IFD	IDL_PAIR
		clr.w	z80_halt			;AmiGameBoy: with idl_state, a dispatch ends the poll-loop record.
		ELSE
		clr.b	z80_halt
		ENDC

		btst	#0,d7
		bne.w	prior_i_0

		IFLE	Z80_MODE
		btst	#1,d7
		bne.w	prior_ii_0
		btst	#2,d7
		bne.w	prior_iii_0
		ENDIF

		btst	#3,d7
		bne.w	prior_iv_0

		bra.w	prior_v_0

no_interrupts_0:tst.b	z80_halt
		IFND	NO_HALTWAIT
		beq.s	halt_wake_0			;AmiGameBoy: a HALT with IME=0 ends
		tst.b	d7				;when IF&IE != 0 (d7 here: only with
		beq.w	cpu_halt_is_on_0		;IME=0), without a dispatch.
		cmp.b	#2,z80_halt
		bne.w	cpu_halt_is_on_0
		clr.b	z80_halt
halt_wake_0:
		ELSE
		bne.w	cpu_halt_is_on_0
		ENDC

		IFND	NO_LINE114
		IFD	HY_GBC
		move.l	gbc_ext,d7			;AmiGameBoy GBC: 2 in double speed (46,46,46,46,44).
		add.l	d7,sweep_extra
		ELSE
		addq.l	#1,sweep_extra			;AmiGameBoy: sweeps 23,23,23,23,22 = 114.
		ENDC
		ENDC
		IFD	HY_GBC
		IFND	NO_VBLLATE
		tst.b	gbc_vbl_late			;AmiGameBoy GBC: line 144 with VBlank to come:
		beq.s	gbc_vls0			;this sweep is 1 M-cycle (2 in double speed),
		move.l	z80_cycles,d7			;its other cycles go to sweep 1.
		sub.l	d7,sweep_extra
gbc_vls0:
		ENDC
		ENDC
		bsr.w	z80_cpu_next_sweep

ei_loop_0:	tst.b	z80_ei_return
		beq.s	no_ei_return_0
		clr.b	z80_ei_return
		IFND	NO_LINE114
		subq.l	#1,a5				;AmiGameBoy: charge the instruction
		adda.l	z80_cycles_left,a5		;run after EI to the sweep.
		ELSE
		move.l	z80_cycles_left,a5
		ENDC
		bsr.l	reti_back
		bra.s	ei_loop_0

no_ei_return_0:
		IFND	NO_LINE114
		move.l	a5,d7				;AmiGameBoy: carry the overshoot into
		ble.s	ln114_0				;the next sweep (a HALT leaves
		moveq	#0,d7				;cycles over: nothing to carry).
ln114_0:	move.l	d7,sweep_extra
		IFD	HY_GBC
		IFND	NO_VBLLATE
		tst.b	gbc_vbl_late
		beq.s	gbc_vle0
		move.l	z80_cycles,d7
		add.l	d7,sweep_extra
gbc_vle0:
		ENDC
		ENDC
		ENDC
		IFGT	GAMEBOY_DEBUG
		tst.b	debug_exit
		bne.w	z80_halted
		ENDIF

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		1/4
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

cpu_halt_is_on_0:
		move.l	a2,a6
		add.l	#$ff00,a6
		IFD	HY_GBC
		IFND	NO_VBLLATE
		tst.b	gbc_vbl_late			;AmiGameBoy GBC: the VBlank IF, 1 M-cycle into
		beq.s	gbc_vli1			;line 144.
		sf	gbc_vbl_late
		bset.b	#0,$0f(a6)
gbc_vli1:
		ENDC
		ENDC

		IFLE	Z80_MODE
		move.b	$07(a6),d7			;d7 = timer control byte.
		btst	#2,d7				;0 = stopped / 1 = counting.
		beq.w	no_timer_update_1		;0! no update.
		bsr.w	irq_timer
no_timer_update_1:
		ENDIF

		cmp.l	#$99,gb_scanlines
		bne.s	no_ly_fix
		clr.b	$44(a6)				;scanline zero (short last ly).

no_ly_fix:	subq.b	#1,transfer_counter
		bhi.w	no_transfer
		blt.w	no_transfer_reset

		bclr.b	#7,$2(a6)

		IFD	NO_IFIE				;AmiGameBoy: IF is set whatever IE says.
		btst.b	#3,$ff(a6)
		beq.w	no_transfer
		ENDC

		bset.b	#3,$f(a6)
		move.b	#$ff,$1(a6)

		IFGT	GAMEBOY_SERIAL

		movem.l	d0-d7/a0-a6,-(SP)

		move.l	a6,a5
		move.l	io_buffer_out,a0
		move.b	$1(a5),(a0)

		move.l	exec_base,a6
		move.l	io_request_out,a1
		move.l	#1,IO_LENGTH(a1)
		move.l	io_buffer_out,IO_DATA(a1)
		move.w	#CMD_WRITE,IO_COMMAND(a1)
		jsr	DoIO(a6)
		tst.l	d0
		bne.s	quit_gb_io

		move.l	io_request_in,a1
		move.l	#1,IO_LENGTH(a1)
		move.l	io_buffer_in,IO_DATA(a1)
		move.w	#CMD_READ,IO_COMMAND(a1)
		jsr	DoIO(a6)
		tst.l	d0
		bne.s	quit_gb_io

		move.l	io_request_in,a1
		jsr	WaitIO(a6)

quit_gb_io:	move.l	io_buffer_in,a0
		move.b	(a0),$1(a5)

		movem.l	(SP)+,d0-d7/a0-a6

		ENDIF

no_transfer_reset:
		clr.b	transfer_counter

no_transfer:
		IFND	NO_DIVRATE
		add.b	#200,div_frac			;AmiGameBoy: a line is 456 T-cycles and
		scs	d7				;DIV ticks every 256: +1 a line, +2
		sub.b	d7,$04(a6)			;when the fraction carries.
		ENDC
		add.b	#1,$04(a6)			;DIVIDER register.
		IFD	HY_GBC
		IFND	NO_DIVRATE
		tst.b	gbc_double			;AmiGameBoy GBC: DIV twice as fast in
		beq.s	gbc_div_single			;double speed.
		add.b	#200,div_frac
		scs	d7
		sub.b	d7,$04(a6)
		add.b	#1,$04(a6)
gbc_div_single:
		ENDC
		ENDC
		and.b	#%11111100,$41(a6)

		move.l	h_values_indexed,a5
		move.b	(a5),d6
		IFND	NO_LCDOFFSTAT
		btst.b	#7,$40(a6)			;AmiGameBoy: LCD off: STAT mode stays 0
		bne.s	lcdoff_stat_1			;(Tobu Tobu Girl's VRAM copy waits on
		moveq	#0,d6				;STAT bit 1 with the LCD off too).
lcdoff_stat_1:
		ENDC
		or.b	d6,$41(a6)

		IFLE	Z80_MODE
		cmp.l	#144,gb_scanlines
		bge.s	no_lcd_irq_emulation_1
;		tst.b	i_flag
;		bne.s	no_lcd_irq_emulation_1
;		btst.b	#1,$ff(a6)			;lcd controller irq?
;		beq.s	no_lcd_irq_emulation_1		;no. quit.

		bsr.w	lcd_irq_eh

no_lcd_irq_emulation_1:
		ENDIF

		move.b	$0f(a6),d7
		addq.l	#1,h_values_indexed
		and.b	#%11111,d7
		IFND	NO_IFIE
		and.b	$ff(a6),d7			;AmiGameBoy: only IF bits enabled in IE.
		ENDC
		beq.s	no_interrupts_1

		tst.b	i_flag
		bne.s	no_interrupts_1

dehalting_z80_1:
		IFND	NO_IRQ5
		subq.l	#5,sweep_extra			;AmiGameBoy: dispatch takes 5 M-cycles.
		ENDC
		IFD	IDLESKIP
		clr.l	idle_snap			;AmiGameBoy: an interrupt ends any idle match.
		ENDC
		IFND	IDL_PAIR
		IFND	NO_IDLESKIP
		IFND	SPIKE_TRACE
		clr.b	idl_state			;AmiGameBoy: a dispatch ends the poll-loop record.
		ENDC
		ENDC
		ENDC
		move.l	a0,d6				;stack the pc.
		sub.l	z80_pc_base,d6
		IFD	IDL_PAIR
		clr.w	z80_halt			;AmiGameBoy: with idl_state, a dispatch ends the poll-loop record.
		ELSE
		clr.b	z80_halt
		ENDC

		btst	#0,d7
		bne.w	prior_i_1

		IFLE	Z80_MODE
		btst	#1,d7
		bne.w	prior_ii_1
		btst	#2,d7
		bne.w	prior_iii_1
		ENDIF

		btst	#3,d7
		bne.w	prior_iv_1

		bra.w	prior_v_1

no_interrupts_1:tst.b	z80_halt
		IFND	NO_HALTWAIT
		beq.s	halt_wake_1			;AmiGameBoy: a HALT with IME=0 ends
		tst.b	d7				;when IF&IE != 0 (d7 here: only with
		beq.w	cpu_halt_is_on_1		;IME=0), without a dispatch.
		cmp.b	#2,z80_halt
		bne.w	cpu_halt_is_on_1
		clr.b	z80_halt
halt_wake_1:
		ELSE
		bne.w	cpu_halt_is_on_1
		ENDC

		IFND	NO_LINE114
		IFD	HY_GBC
		move.l	gbc_ext,d7			;AmiGameBoy GBC: 2 in double speed (46,46,46,46,44).
		add.l	d7,sweep_extra
		ELSE
		addq.l	#1,sweep_extra			;AmiGameBoy: sweeps 23,23,23,23,22 = 114.
		ENDC
		ENDC
		bsr.w	z80_cpu_next_sweep

ei_loop_1:	tst.b	z80_ei_return
		beq.s	no_ei_return_1
		clr.b	z80_ei_return
		IFND	NO_LINE114
		subq.l	#1,a5				;AmiGameBoy: charge the instruction
		adda.l	z80_cycles_left,a5		;run after EI to the sweep.
		ELSE
		move.l	z80_cycles_left,a5
		ENDC
		bsr.l	reti_back
		bra.s	ei_loop_1

no_ei_return_1:
		IFND	NO_LINE114
		move.l	a5,d7				;AmiGameBoy: carry the overshoot into
		ble.s	ln114_1				;the next sweep (a HALT leaves
		moveq	#0,d7				;cycles over: nothing to carry).
ln114_1:	move.l	d7,sweep_extra
		ENDC
		IFGT	GAMEBOY_DEBUG
		tst.b	debug_exit
		bne.w	z80_halted
		ENDIF

cpu_halt_is_on_1:

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		2/4
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

		move.l	a2,a6
		add.l	#$ff00,a6

		IFLE	Z80_MODE
		move.b	$07(a6),d7			;d7 = timer control byte.
		btst	#2,d7				;0 = stopped / 1 = counting.
		beq.w	no_timer_update_2		;0! no update.
		bsr.w	irq_timer
no_timer_update_2:
		ENDIF

		and.b	#%11111100,$41(a6)
		move.l	h_values_indexed,a5
		move.b	(a5),d6
		IFND	NO_LCDOFFSTAT
		btst.b	#7,$40(a6)			;AmiGameBoy: LCD off: STAT mode stays 0
		bne.s	lcdoff_stat_2			;(Tobu Tobu Girl's VRAM copy waits on
		moveq	#0,d6				;STAT bit 1 with the LCD off too).
lcdoff_stat_2:
		ENDC
		or.b	d6,$41(a6)

		move.b	$0f(a6),d7
		addq.l	#1,h_values_indexed
		and.b	#%11111,d7
		IFND	NO_IFIE
		and.b	$ff(a6),d7			;AmiGameBoy: only IF bits enabled in IE.
		ENDC
		beq.s	no_interrupts_2

		tst.b	i_flag
		bne.s	no_interrupts_2

dehalting_z80_2:
		IFND	NO_IRQ5
		subq.l	#5,sweep_extra			;AmiGameBoy: dispatch takes 5 M-cycles.
		ENDC
		IFD	IDLESKIP
		clr.l	idle_snap			;AmiGameBoy: an interrupt ends any idle match.
		ENDC
		IFND	IDL_PAIR
		IFND	NO_IDLESKIP
		IFND	SPIKE_TRACE
		clr.b	idl_state			;AmiGameBoy: a dispatch ends the poll-loop record.
		ENDC
		ENDC
		ENDC
		move.l	a0,d6				;stack the pc.
		sub.l	z80_pc_base,d6
		IFD	IDL_PAIR
		clr.w	z80_halt			;AmiGameBoy: with idl_state, a dispatch ends the poll-loop record.
		ELSE
		clr.b	z80_halt
		ENDC

		btst	#0,d7
		bne.w	prior_i_2

		IFLE	Z80_MODE
		btst	#1,d7
		bne.w	prior_ii_2
		btst	#2,d7
		bne.w	prior_iii_2
		ENDIF

		btst	#3,d7
		bne.w	prior_iv_2

		bra.w	prior_v_2

no_interrupts_2:tst.b	z80_halt
		IFND	NO_HALTWAIT
		beq.s	halt_wake_2			;AmiGameBoy: a HALT with IME=0 ends
		tst.b	d7				;when IF&IE != 0 (d7 here: only with
		beq.w	cpu_halt_is_on_2		;IME=0), without a dispatch.
		cmp.b	#2,z80_halt
		bne.w	cpu_halt_is_on_2
		clr.b	z80_halt
halt_wake_2:
		ELSE
		bne.w	cpu_halt_is_on_2
		ENDC

		IFND	NO_LINE114
		IFD	HY_GBC
		move.l	gbc_ext,d7			;AmiGameBoy GBC: 2 in double speed (46,46,46,46,44).
		add.l	d7,sweep_extra
		ELSE
		addq.l	#1,sweep_extra			;AmiGameBoy: sweeps 23,23,23,23,22 = 114.
		ENDC
		ENDC
		bsr.w	z80_cpu_next_sweep

ei_loop_2:	tst.b	z80_ei_return
		beq.s	no_ei_return_2
		clr.b	z80_ei_return
		IFND	NO_LINE114
		subq.l	#1,a5				;AmiGameBoy: charge the instruction
		adda.l	z80_cycles_left,a5		;run after EI to the sweep.
		ELSE
		move.l	z80_cycles_left,a5
		ENDC
		bsr.l	reti_back
		bra.s	ei_loop_2

no_ei_return_2:
		IFND	NO_LINE114
		move.l	a5,d7				;AmiGameBoy: carry the overshoot into
		ble.s	ln114_2				;the next sweep (a HALT leaves
		moveq	#0,d7				;cycles over: nothing to carry).
ln114_2:	move.l	d7,sweep_extra
		ENDC
		IFGT	GAMEBOY_DEBUG
		tst.b	debug_exit
		bne.w	z80_halted
		ENDIF

cpu_halt_is_on_2:

		tst.b	old_refresh			;144/144 mode?
		bne.s	no_144_144_2			;no.
		bsr.w	scanline_draw			;yes. draw a scanline.
		bra.s	xan_drawed_2

no_144_144_2:	move.l	gb_scanlines,d7
		cmp.b	refresh_scanline,d7
		bne.s	xan_drawed_2

		move.b	output_bit,d7
		cmp.b	frame_update,d7
		bne.s	xan_drawed_2

		bsr.w	screen_draw			;update the gameboy's screen.

xan_drawed_2:

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		3/4
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

		move.l	a2,a6
		add.l	#$ff00,a6

		IFLE	Z80_MODE
		move.b	$07(a6),d7			;d7 = timer control byte.
		btst	#2,d7				;0 = stopped / 1 = counting.
		beq.w	no_timer_update_3		;0! no update.
		bsr.w	irq_timer
no_timer_update_3:
		ENDIF

		IFD	NO_DIVRATE			;AmiGameBoy: once a line (sweep 1).
		addq.b	#1,$04(a6)			;DIVIDER register.
		ENDC
		and.b	#%11111100,$41(a6)

		move.l	h_values_indexed,a5
		move.b	(a5),d6
		IFND	NO_LCDOFFSTAT
		btst.b	#7,$40(a6)			;AmiGameBoy: LCD off: STAT mode stays 0
		bne.s	lcdoff_stat_3			;(Tobu Tobu Girl's VRAM copy waits on
		moveq	#0,d6				;STAT bit 1 with the LCD off too).
lcdoff_stat_3:
		ENDC
		or.b	d6,$41(a6)
		IFD	HY_GBC
		jsr	gbc_hblank			;AmiGameBoy GBC: HBlank DMA, speed switch.
		ENDC

		IFLE	Z80_MODE
		cmp.l	#144,gb_scanlines
		bge.s	no_lcd_irq_emulation_3
;		tst.b	i_flag
;		bne.s	no_lcd_irq_emulation_3
;		btst.b	#1,$ff(a6)			;lcd controller irq?
;		beq.s	no_lcd_irq_emulation_3		;no. quit.

		bsr.w	lcd_irq_eh

no_lcd_irq_emulation_3:
		ENDIF

		move.b	$0f(a6),d7
		addq.l	#1,h_values_indexed
		and.b	#%11111,d7
		IFND	NO_IFIE
		and.b	$ff(a6),d7			;AmiGameBoy: only IF bits enabled in IE.
		ENDC
		beq.s	no_interrupts_3

		tst.b	i_flag
		bne.s	no_interrupts_3

dehalting_z80_3:
		IFND	NO_IRQ5
		subq.l	#5,sweep_extra			;AmiGameBoy: dispatch takes 5 M-cycles.
		ENDC
		IFD	IDLESKIP
		clr.l	idle_snap			;AmiGameBoy: an interrupt ends any idle match.
		ENDC
		IFND	IDL_PAIR
		IFND	NO_IDLESKIP
		IFND	SPIKE_TRACE
		clr.b	idl_state			;AmiGameBoy: a dispatch ends the poll-loop record.
		ENDC
		ENDC
		ENDC
		move.l	a0,d6				;stack the pc.
		sub.l	z80_pc_base,d6
		IFD	IDL_PAIR
		clr.w	z80_halt			;AmiGameBoy: with idl_state, a dispatch ends the poll-loop record.
		ELSE
		clr.b	z80_halt
		ENDC

		btst	#0,d7
		bne.w	prior_i_3

		IFLE	Z80_MODE
		btst	#1,d7
		bne.w	prior_ii_3
		btst	#2,d7
		bne.w	prior_iii_3
		ENDIF

		btst	#3,d7
		bne.w	prior_iv_3

		bra.w	prior_v_3

no_interrupts_3:tst.b	z80_halt
		IFND	NO_HALTWAIT
		beq.s	halt_wake_3			;AmiGameBoy: a HALT with IME=0 ends
		tst.b	d7				;when IF&IE != 0 (d7 here: only with
		beq.w	cpu_halt_is_on_3		;IME=0), without a dispatch.
		cmp.b	#2,z80_halt
		bne.w	cpu_halt_is_on_3
		clr.b	z80_halt
halt_wake_3:
		ELSE
		bne.w	cpu_halt_is_on_3
		ENDC

		IFND	NO_LINE114
		IFD	HY_GBC
		move.l	gbc_ext,d7			;AmiGameBoy GBC: 2 in double speed (46,46,46,46,44).
		add.l	d7,sweep_extra
		ELSE
		addq.l	#1,sweep_extra			;AmiGameBoy: sweeps 23,23,23,23,22 = 114.
		ENDC
		ENDC
		bsr.w	z80_cpu_next_sweep

ei_loop_3:	tst.b	z80_ei_return
		beq.s	no_ei_return_3
		clr.b	z80_ei_return
		IFND	NO_LINE114
		subq.l	#1,a5				;AmiGameBoy: charge the instruction
		adda.l	z80_cycles_left,a5		;run after EI to the sweep.
		ELSE
		move.l	z80_cycles_left,a5
		ENDC
		bsr.l	reti_back
		bra.s	ei_loop_3

no_ei_return_3:
		IFND	NO_LINE114
		move.l	a5,d7				;AmiGameBoy: carry the overshoot into
		ble.s	ln114_3				;the next sweep (a HALT leaves
		moveq	#0,d7				;cycles over: nothing to carry).
ln114_3:	move.l	d7,sweep_extra
		ENDC
		IFGT	GAMEBOY_DEBUG
		tst.b	debug_exit
		bne.w	z80_halted
		ENDIF

cpu_halt_is_on_3:

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		4/4
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

		move.l	a2,a6
		add.l	#$ff00,a6

		IFLE	Z80_MODE
		move.b	$07(a6),d7			;d7 = timer control byte.
		btst	#2,d7				;0 = stopped / 1 = counting.
		beq.w	no_timer_update_4		;0! no update.
		bsr.w	irq_timer
no_timer_update_4:
		ENDIF

		and.b	#%11111100,$41(a6)

		move.l	h_values_indexed,a5
		move.b	(a5),d6
		IFND	NO_LCDOFFSTAT
		btst.b	#7,$40(a6)			;AmiGameBoy: LCD off: STAT mode stays 0
		bne.s	lcdoff_stat_4			;(Tobu Tobu Girl's VRAM copy waits on
		moveq	#0,d6				;STAT bit 1 with the LCD off too).
lcdoff_stat_4:
		ENDC
		or.b	d6,$41(a6)

		move.b	$0f(a6),d7
		addq.l	#1,h_values_indexed
		and.b	#%11111,d7
		IFND	NO_IFIE
		and.b	$ff(a6),d7			;AmiGameBoy: only IF bits enabled in IE.
		ENDC
		beq.s	no_interrupts_4

		tst.b	i_flag
		bne.s	no_interrupts_4

dehalting_z80_4:
		IFND	NO_IRQ5
		subq.l	#5,sweep_extra			;AmiGameBoy: dispatch takes 5 M-cycles.
		ENDC
		IFD	IDLESKIP
		clr.l	idle_snap			;AmiGameBoy: an interrupt ends any idle match.
		ENDC
		IFND	IDL_PAIR
		IFND	NO_IDLESKIP
		IFND	SPIKE_TRACE
		clr.b	idl_state			;AmiGameBoy: a dispatch ends the poll-loop record.
		ENDC
		ENDC
		ENDC
		move.l	a0,d6				;stack the pc.
		sub.l	z80_pc_base,d6
		IFD	IDL_PAIR
		clr.w	z80_halt			;AmiGameBoy: with idl_state, a dispatch ends the poll-loop record.
		ELSE
		clr.b	z80_halt
		ENDC

		btst	#0,d7
		bne.w	prior_i_4

		IFLE	Z80_MODE
		btst	#1,d7
		bne.w	prior_ii_4
		btst	#2,d7
		bne.w	prior_iii_4
		ENDIF

		btst	#3,d7
		bne.w	prior_iv_4

		bra.w	prior_v_4

no_interrupts_4:tst.b	z80_halt
		IFND	NO_HALTWAIT
		beq.s	halt_wake_4			;AmiGameBoy: a HALT with IME=0 ends
		tst.b	d7				;when IF&IE != 0 (d7 here: only with
		beq.w	cpu_halt_is_on_4		;IME=0), without a dispatch.
		cmp.b	#2,z80_halt
		bne.w	cpu_halt_is_on_4
		clr.b	z80_halt
halt_wake_4:
		ELSE
		bne.w	cpu_halt_is_on_4
		ENDC

		bsr.w	z80_cpu_next_sweep

ei_loop_4:	tst.b	z80_ei_return
		beq.s	no_ei_return_4
		clr.b	z80_ei_return
		IFND	NO_LINE114
		subq.l	#1,a5				;AmiGameBoy: charge the instruction
		adda.l	z80_cycles_left,a5		;run after EI to the sweep.
		ELSE
		move.l	z80_cycles_left,a5
		ENDC
		bsr.l	reti_back
		bra.s	ei_loop_4

no_ei_return_4:
		IFND	NO_LINE114
		move.l	a5,d7				;AmiGameBoy: carry the overshoot into
		ble.s	ln114_4				;the next sweep (a HALT leaves
		moveq	#0,d7				;cycles over: nothing to carry).
ln114_4:	move.l	d7,sweep_extra
		ENDC
		IFGT	GAMEBOY_DEBUG
		tst.b	debug_exit
		bne.w	z80_halted
		ENDIF

cpu_halt_is_on_4:

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		do envelope sweeps if selected
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

		tst.b	snd_quality
		beq.w	snd_high_do

snd_high_back:	cmp.l	#153,gb_scanlines		;end of lines?
		beq.w	next_frame			;next frame.

		addq.l	#1,gb_scanlines			;next scanline.

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		next scanline, update registers
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

next_scanline:	move.l	a2,a6
		move.l	gb_scanlines,d7
		add.l	#$ff00,a6
		IFND	NO_LCDONOFF			;AmiGameBoy: the LCD came on during the
		tst.b	lcd_restart			;last line: the picture restarts at
		beq.s	lcd_restart_none		;line 0.
		clr.b	lcd_restart
		st	skip_lyc_once
		moveq	#0,d7
		move.l	d7,gb_scanlines
		move.l	#h_values,h_values_indexed
lcd_restart_none:
		btst.b	#7,$40(a6)			;LCD off: LY reads 0.
		bne.s	lcd_ly_on
		moveq	#0,d7
lcd_ly_on:
		ENDC

		and.b	#%10,irq_status_flags		;clear oam and lyc flag.
		move.b	d7,$44(a6)			;next scanline (address).
		bra.w	next_sline			;next horizontal line.

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		input
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

input_irq:	move.b	(a6),d6
		btst	#5,d6
		beq.s	key_irq_buttons
		btst	#4,d6
		beq.s	key_irq_cross
		bra.s	input_irq_exit

key_irq_cross:	lea	directions_byte_o,a5
		move.b	directions_byte,d7
		cmp.b	(a5),d7
		beq.s	input_irq_exit

		IFD	NO_IFIE				;AmiGameBoy: IF is set whatever IE says.
		btst.b	#4,$ff(a6)			;keypad irq?
		beq.s	input_irq_exit			;no. quit.
		ENDC

		bset.b	#4,$0f(a6)			;transition occurred.
		move.b	d7,(a5)

		IFGT	GAMEBOY_DEBUG
		bsr.w	debug_p10
		ENDIF

		bra.s	input_irq_exit

key_irq_buttons:lea	buttons_byte_o,a5
		move.b	buttons_byte,d7
		cmp.b	(a5),d7
		beq.s	input_irq_exit

		IFD	NO_IFIE				;AmiGameBoy: IF is set whatever IE says.
		btst.b	#4,$ff(a6)			;keypad irq?
		beq.s	input_irq_exit			;no. quit.
		ENDC

		bset.b	#4,$0f(a6)			;transition occurred.
		move.b	d7,(a5)

		IFGT	GAMEBOY_DEBUG
		bsr.w	debug_p10
		ENDIF

input_irq_exit:	rts

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		do audio sweeps
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»


; ---- wz.s 9312-9426: gb_memory_at_start: post-boot I/O values
gb_memory_at_start:
		move.l	gb_memory,a0
		add.l	#$ff00,a0

		move.b	#$CF,$00(a0)
		move.b	#$00,$01(a0)
		move.b	#$7E,$02(a0)
		move.b	#$FF,$03(a0)
		move.b	#$AB,$04(a0)
		move.b	#$00,$05(a0)
		move.b	#$00,$06(a0)
		move.b	#%11111000,$07(a0)

		move.b	#$FF,$08(a0)
		move.b	#$FF,$09(a0)
		move.b	#$FF,$0A(a0)
		move.b	#$FF,$0B(a0)
		move.b	#$FF,$0C(a0)
		move.b	#$FF,$0D(a0)
		move.b	#$FF,$0E(a0)

		move.b	#$E1,$0F(a0)
		move.b	#$80,$10(a0)
		move.b	#$BF,$11(a0)
		move.b	#$F3,$12(a0)
		move.b	#$FF,$13(a0)
		move.b	#$BF,$14(a0)
		move.b	#$FF,$15(a0)
		move.b	#$3F,$16(a0)
		move.b	#$00,$17(a0)
		move.b	#$FF,$18(a0)
		move.b	#$BF,$19(a0)
		move.b	#$7F,$1A(a0)
		move.b	#$FF,$1B(a0)
		move.b	#$9F,$1C(a0)
		move.b	#$FF,$1D(a0)
		move.b	#$BF,$1E(a0)
		move.b	#$FF,$1F(a0)
		move.b	#$FF,$20(a0)
		move.b	#$00,$21(a0)
		move.b	#$00,$22(a0)
		move.b	#$BF,$23(a0)
		move.b	#$77,$24(a0)
		move.b	#$F3,$25(a0)
		move.b	#$F1,$26(a0)

		move.b	#$00,$27(a0)
		move.b	#$00,$28(a0)
		move.b	#$00,$29(a0)
		move.b	#$00,$2A(a0)
		move.b	#$00,$2B(a0)
		move.b	#$00,$2C(a0)
		move.b	#$00,$2D(a0)
		move.b	#$00,$2E(a0)
		move.b	#$00,$2F(a0)

		move.b	#$06,$30(a0)		;cgb like wave ram init.
		move.b	#$FE,$31(a0)
		move.b	#$0E,$32(a0)
		move.b	#$7F,$33(a0)
		move.b	#$00,$34(a0)
		move.b	#$FF,$35(a0)
		move.b	#$58,$36(a0)
		move.b	#$DF,$37(a0)
		move.b	#$00,$38(a0)
		move.b	#$EC,$39(a0)
		move.b	#$00,$3A(a0)
		move.b	#$BF,$3B(a0)
		move.b	#$0C,$3C(a0)
		move.b	#$ED,$3D(a0)
		move.b	#$03,$3E(a0)
		move.b	#$F7,$3F(a0)

		move.b	#$91,$40(a0)
		move.b	#%10000000,$41(a0)
		move.b	#$00,$42(a0)
		move.b	#$00,$43(a0)
		move.b	#$00,$45(a0)
		move.b	#$FF,$46(a0)
		move.b	#$FC,$47(a0)
		move.b	#$FF,$48(a0)
		move.b	#$FF,$49(a0)
		move.b	#$00,$4A(a0)
		move.b	#$00,$4B(a0)
		move.b	#$00,$FF(a0)

		clr.b	sound_I_onf_master
		clr.b	sound_II_onf_master
		clr.b	sound_III_onf_master
		clr.b	sound_IV_onf_master

		clr.b	irq_status_flags

		clr.b	mbc1_ram_protection_status
		clr.b	mbc2_ram_protection_status
		clr.b	mbc3_ram_protection_status
		clr.b	mbc3_latched_sec
		clr.b	mbc3_latched_min
		clr.b	mbc3_latched_hrs
		clr.b	mbc3_latched_dayl
		clr.b	mbc3_latched_dayh
		clr.b	mbc3_sec
		clr.b	mbc3_min
		clr.b	mbc3_hrs
		clr.b	mbc3_dayl
		clr.b	mbc3_dayh
		clr.b	mbc3_latch_a
		clr.b	mbc3_latch_b
		clr.b	mbc5_rom_bank
		clr.b	mbc5_rom_bank1
		clr.b	mbc5_rom_bank0

		clr.l	freq_storage
		IFND	NO_BOOTVRAM
		bsr.w	boot_vram			;AmiGameBoy: logo left by the boot ROM.
		ENDC
		rts


; ---- wz.s 9964-10562: interrupt dispatch, lcd_irq_eh, next_frame, irq_timer
prior_i_0:
		IFD	NO_PRIOLCD			;AmiGameBoy: dispatched with the LCD
		btst.b	#7,$40(a6)			;off too (skipping it blocked the
		beq.w	no_interrupts_0			;lower ones and woke HALT).
		ENDC

		bclr.b	#0,$0f(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		ror.w	#8,d6
		subq.w	#2,d5
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$40(a3),a0
		move.l	a3,z80_pc_base
		move.b	#1,i_flag
		clr.b	z80_halt
		bra.w	no_interrupts_0

		IFLE	Z80_MODE
prior_ii_0:
		IFD	NO_PRIOLCD			;AmiGameBoy: dispatched with the LCD
		btst.b	#7,$40(a6)			;off too (skipping it blocked the
		beq.w	no_interrupts_0			;lower ones and woke HALT).
		ENDC

		bclr.b	#1,$0f(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		ror.w	#8,d6
		subq.w	#2,d5
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$48(a3),a0
		move.l	a3,z80_pc_base
		move.b	#1,i_flag
		clr.b	z80_halt
		bra.w	no_interrupts_0

prior_iii_0:	bclr.b	#2,$0f(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		ror.w	#8,d6
		subq.w	#2,d5
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$50(a3),a0
		move.l	a3,z80_pc_base
		move.b	#1,i_flag
		clr.b	z80_halt
		bra.w	no_interrupts_0
		ENDIF

prior_iv_0:	bclr.b	#3,$0f(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		ror.w	#8,d6
		subq.w	#2,d5
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$58(a3),a0
		move.l	a3,z80_pc_base
		move.b	#1,i_flag
		clr.b	z80_halt
		bra.w	no_interrupts_0

prior_v_0:	bclr.b	#4,$0f(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		ror.w	#8,d6
		subq.w	#2,d5
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$60(a3),a0
		move.l	a3,z80_pc_base
		move.b	#1,i_flag
		clr.b	z80_halt
		bra.w	no_interrupts_0

prior_i_1:
		IFD	NO_PRIOLCD			;AmiGameBoy: dispatched with the LCD
		btst.b	#7,$40(a6)			;off too (skipping it blocked the
		beq.w	no_interrupts_1			;lower ones and woke HALT).
		ENDC

		bclr.b	#0,$0f(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		ror.w	#8,d6
		subq.w	#2,d5
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$40(a3),a0
		move.l	a3,z80_pc_base
		move.b	#1,i_flag
		clr.b	z80_halt
		bra.w	no_interrupts_1

		IFLE	Z80_MODE
prior_ii_1:
		IFD	NO_PRIOLCD			;AmiGameBoy: dispatched with the LCD
		btst.b	#7,$40(a6)			;off too (skipping it blocked the
		beq.w	no_interrupts_1			;lower ones and woke HALT).
		ENDC

		bclr.b	#1,$0f(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		ror.w	#8,d6
		subq.w	#2,d5
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$48(a3),a0
		move.l	a3,z80_pc_base
		move.b	#1,i_flag
		clr.b	z80_halt
		bra.w	no_interrupts_1

prior_iii_1:	bclr.b	#2,$0f(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		ror.w	#8,d6
		subq.w	#2,d5
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$50(a3),a0
		move.l	a3,z80_pc_base
		move.b	#1,i_flag
		clr.b	z80_halt
		bra.w	no_interrupts_1
		ENDIF

prior_iv_1:	bclr.b	#3,$0f(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		ror.w	#8,d6
		subq.w	#2,d5
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$58(a3),a0
		move.l	a3,z80_pc_base
		move.b	#1,i_flag
		clr.b	z80_halt
		bra.w	no_interrupts_1

prior_v_1:	bclr.b	#4,$0f(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		ror.w	#8,d6
		subq.w	#2,d5
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$60(a3),a0
		move.l	a3,z80_pc_base
		move.b	#1,i_flag
		clr.b	z80_halt
		bra.w	no_interrupts_1

prior_i_2:
		IFD	NO_PRIOLCD			;AmiGameBoy: dispatched with the LCD
		btst.b	#7,$40(a6)			;off too (skipping it blocked the
		beq.w	no_interrupts_2			;lower ones and woke HALT).
		ENDC

		bclr.b	#0,$0f(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		ror.w	#8,d6
		subq.w	#2,d5
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$40(a3),a0
		move.l	a3,z80_pc_base
		move.b	#1,i_flag
		clr.b	z80_halt
		bra.w	no_interrupts_2

		IFLE	Z80_MODE
prior_ii_2:
		IFD	NO_PRIOLCD			;AmiGameBoy: dispatched with the LCD
		btst.b	#7,$40(a6)			;off too (skipping it blocked the
		beq.w	no_interrupts_2			;lower ones and woke HALT).
		ENDC

		bclr.b	#1,$0f(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		ror.w	#8,d6
		subq.w	#2,d5
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$48(a3),a0
		move.l	a3,z80_pc_base
		move.b	#1,i_flag
		clr.b	z80_halt
		bra.w	no_interrupts_2

prior_iii_2:	bclr.b	#2,$0f(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		ror.w	#8,d6
		subq.w	#2,d5
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$50(a3),a0
		move.l	a3,z80_pc_base
		move.b	#1,i_flag
		clr.b	z80_halt
		bra.w	no_interrupts_2
		ENDIF

prior_iv_2:	bclr.b	#3,$0f(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		ror.w	#8,d6
		subq.w	#2,d5
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$58(a3),a0
		move.l	a3,z80_pc_base
		move.b	#1,i_flag
		clr.b	z80_halt
		bra.w	no_interrupts_2

prior_v_2:	bclr.b	#4,$0f(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		ror.w	#8,d6
		subq.w	#2,d5
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$60(a3),a0
		move.l	a3,z80_pc_base
		move.b	#1,i_flag
		clr.b	z80_halt
		bra.w	no_interrupts_2

prior_i_3:
		IFD	NO_PRIOLCD			;AmiGameBoy: dispatched with the LCD
		btst.b	#7,$40(a6)			;off too (skipping it blocked the
		beq.w	no_interrupts_3			;lower ones and woke HALT).
		ENDC

		bclr.b	#0,$0f(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		ror.w	#8,d6
		subq.w	#2,d5
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$40(a3),a0
		move.l	a3,z80_pc_base
		move.b	#1,i_flag
		clr.b	z80_halt
		bra.w	no_interrupts_3

		IFLE	Z80_MODE
prior_ii_3:
		IFD	NO_PRIOLCD			;AmiGameBoy: dispatched with the LCD
		btst.b	#7,$40(a6)			;off too (skipping it blocked the
		beq.w	no_interrupts_3			;lower ones and woke HALT).
		ENDC

		bclr.b	#1,$0f(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		ror.w	#8,d6
		subq.w	#2,d5
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$48(a3),a0
		move.l	a3,z80_pc_base
		move.b	#1,i_flag
		clr.b	z80_halt
		bra.w	no_interrupts_3

prior_iii_3:	bclr.b	#2,$0f(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		ror.w	#8,d6
		subq.w	#2,d5
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$50(a3),a0
		move.l	a3,z80_pc_base
		move.b	#1,i_flag
		clr.b	z80_halt
		bra.w	no_interrupts_3
		ENDIF

prior_iv_3:	bclr.b	#3,$0f(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		ror.w	#8,d6
		subq.w	#2,d5
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$58(a3),a0
		move.l	a3,z80_pc_base
		move.b	#1,i_flag
		clr.b	z80_halt
		bra.w	no_interrupts_3

prior_v_3:	bclr.b	#4,$0f(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		ror.w	#8,d6
		subq.w	#2,d5
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$60(a3),a0
		move.l	a3,z80_pc_base
		move.b	#1,i_flag
		clr.b	z80_halt
		bra.w	no_interrupts_3

prior_i_4:
		IFD	NO_PRIOLCD			;AmiGameBoy: dispatched with the LCD
		btst.b	#7,$40(a6)			;off too (skipping it blocked the
		beq.w	no_interrupts_4			;lower ones and woke HALT).
		ENDC

		bclr.b	#0,$0f(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		ror.w	#8,d6
		subq.w	#2,d5
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$40(a3),a0
		move.l	a3,z80_pc_base
		move.b	#1,i_flag
		clr.b	z80_halt
		bra.w	no_interrupts_4

		IFLE	Z80_MODE
prior_ii_4:
		IFD	NO_PRIOLCD			;AmiGameBoy: dispatched with the LCD
		btst.b	#7,$40(a6)			;off too (skipping it blocked the
		beq.w	no_interrupts_4			;lower ones and woke HALT).
		ENDC

		bclr.b	#1,$0f(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		ror.w	#8,d6
		subq.w	#2,d5
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$48(a3),a0
		move.l	a3,z80_pc_base
		move.b	#1,i_flag
		clr.b	z80_halt
		bra.w	no_interrupts_4

prior_iii_4:	bclr.b	#2,$0f(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		ror.w	#8,d6
		subq.w	#2,d5
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$50(a3),a0
		move.l	a3,z80_pc_base
		move.b	#1,i_flag
		clr.b	z80_halt
		bra.w	no_interrupts_4
		ENDIF

prior_iv_4:	bclr.b	#3,$0f(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		ror.w	#8,d6
		subq.w	#2,d5
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$58(a3),a0
		move.l	a3,z80_pc_base
		move.b	#1,i_flag
		clr.b	z80_halt
		bra.w	no_interrupts_4

prior_v_4:	bclr.b	#4,$0f(a6)

		IFEQ	Z80_MODE
		bsr.w	write_d6_stackx
		ELSE
		ror.w	#8,d6
		subq.w	#2,d5
		move.w	d6,(a2,d5.l)
		ENDIF

		lea	$60(a3),a0
		move.l	a3,z80_pc_base
		move.b	#1,i_flag
		clr.b	z80_halt
		bra.w	no_interrupts_4

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		lcd interrupt
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

lcd_irq_eh:
		IFND	NO_LCDONOFF
		btst.b	#7,$40(a6)			;AmiGameBoy: no STAT mode interrupts
		beq.s	lcd_irq_quit			;with the LCD off.
		ENDC
		tst.b	d6
		beq.s	lcd_h_blank
		cmp.b	#1,d6
		beq.s	lcd_v_blank
		cmp.b	#2,d6
		beq.s	lcd_oam
		rts

;lcd_3_blank:	bset.b	#1,$0f(a6)			;lcd occurred.
;		rts

lcd_h_blank:	btst.b	#3,$41(a6)
		beq.s	lcd_irq_quit
		btst.b	#2,irq_status_flags		;after lyc?
		IFND	NO_HBLYC			;AmiGameBoy: only while the LYC interrupt
		beq.s	lcd_hb_edge			;is still on (the STAT line stays high);
		btst.b	#6,$41(a6)			;switched off since, hblank is a new edge
		ENDC					;(Quartet: LYC handler sets STAT to $08).
		bne.s	lcd_irq_quit
lcd_hb_edge:

		IFGT	GAMEBOY_DEBUG
		bsr.w	debug_lcd
		ENDIF

		bset.b	#0,irq_status_flags		;hblank occurred.
		bset.b	#1,$0f(a6)			;lcd occurred.
lcd_irq_quit:	rts

lcd_v_blank:	btst.b	#4,$41(a6)
		beq.s	lcd_irq_quit

		IFGT	GAMEBOY_DEBUG
		bsr.w	debug_lcd
		ENDIF

		bset.b	#1,$0f(a6)			;lcd occurred.
		rts

lcd_oam:	btst.b	#5,$41(a6)
		beq.s	lcd_irq_quit
		btst.b	#0,irq_status_flags
		bne.s	lcd_irq_quit
		btst.b	#2,irq_status_flags		;after lyc?
		bne.s	lcd_irq_quit
		btst.b	#1,irq_status_flags		;vbr effect?
		beq.s	lcd_oam_no_vbr_filtering
		tst.l	gb_scanlines
		beq.s	lcd_irq_quit			;yes, $00 is off limits.

lcd_oam_no_vbr_filtering:

		IFGT	GAMEBOY_DEBUG
		bsr.w	debug_lcd
		ENDIF

		bset.b	#1,$0f(a6)			;lcd occurred.
		rts

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		next frame - check the buttons and loop
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

next_frame:	bsr.w	push_z80

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		MBC3 clock emulation
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

		tst.b	mbc3_existence
		beq.s	no_mbc3_clock

		add.b	#1,mbc3_sec
		cmp.b	#60,mbc3_sec
		bne.s	mbc3_clock_done

		clr.b	mbc3_sec
		add.b	#1,mbc3_min
		cmp.b	#60,mbc3_min
		bne.s	mbc3_clock_done

		clr.b	mbc3_min
		add.b	#1,mbc3_hrs
		cmp.b	#60,mbc3_hrs
		bne.s	mbc3_clock_done

		clr.b	mbc3_hrs
		move.w	mbc3_day,d7
		addq.w	#1,d7
		btst	#9,d7
		beq.s	mbc3_clock_no_day_carry
		or.w	#%1000000000000000,d7
mbc3_clock_no_day_carry:
		and.w	#%1100000111111111,d7
		move.w	d7,mbc3_day		

mbc3_clock_done:
no_mbc3_clock:	and.b	#%10,irq_status_flags		;clear oam and lyc flag.
		IFD	SPIKE_AT153
		bsr.w	spike_frame			;AmiGameBoy stage 0 hook (old point).
		ENDC

		move.b	output_bit,d7
		cmp.b	frame_update,d7
		bne.s	no_empty
		clr.b	output_bit			;reset the counter.

no_empty:	addq.b	#1,output_bit			;one frame done.

		cmp.b	#2,snd_quality
		beq.w	sfx_update_all			;use y value to update
							;audio data.
sfx_back:	cmp.b	#INPUT_OK,input_status
		beq.w	cartridge_loop
		cmp.b	#INPUT_HALT,input_status
		beq.w	z80_halted
		cmp.b	#INPUT_GBS_LOAD,input_status
		beq.s	input_gbs_load

input_gbs_save:	bsr.w	runtime_gbs_save
		clr.b	input_status
		bra.w	cartridge_loop

input_gbs_load:	bsr.w	runtime_gbs_load
		clr.b	input_status
		bra.w	cartridge_loop

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		execute a timer interrupt if needed
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

irq_timer:	and.l	#%11,d7				;save the frequency value.
		lea	freq_table,a5			;a5 = the value table.
		move.l	(a5,d7.w*4),d6			;d6 = the freq*4096/60/154/5.
		IFD	HY_GBC
		tst.b	gbc_double			;AmiGameBoy GBC: the timer twice as
		beq.s	gbc_tim_single			;fast in double speed.
		add.l	d6,d6
gbc_tim_single:
		ENDC
		add.l	freq_storage,d6			;add the old value.
		move.l	d6,d7				;store the value.
		lsr.l	#8,d6
		lsr.l	#4,d6				;d6 = updated timer register.
		cmp.l	#$ff,d6
		ble.s	write_timer			;no overflow.

		IFND	NO_TIMACARRY			;AmiGameBoy: counts past the overflow
timer_carry:	sub.l	#$100000,d7			;go on from TMA (at 262144 Hz a sweep
		moveq	#0,d6				;is ~5.7 counts: dropping them made
		move.b	$06(a6),d6			;fast timers slow).
		lsl.l	#8,d6
		lsl.l	#4,d6
		add.l	d6,d7
		cmp.l	#$100000,d7
		bcc.s	timer_carry
		move.l	d7,d6
		lsr.l	#8,d6
		lsr.l	#4,d6
		ELSE
		moveq.l	#0,d7
		move.b	$06(a6),d6			;d6 = timemod (timer modulo).
		move.b	d6,d7
		lsl.l	#8,d7
		lsl.l	#4,d7
		ENDC

		IFD	NO_IFIE				;AmiGameBoy: IF is set whatever IE says.
		btst.b	#2,$ff(a6)			;timer overflow?
		beq.s	write_timer			;no. it's disabled. ;(
		ENDC

		IFGT	GAMEBOY_DEBUG
		bsr.w	debug_timer
		ENDIF

timer_starts:	bset.b	#2,$0f(a6)			;timer occurred.
write_timer:	move.b	d6,$05(a6)			;update timecnt.
		move.l	d7,freq_storage			;update fixed storage.
no_timer_update:rts

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		the aga h/w mode vbr interrupt
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»


; ---- wz.s 11258-11288: push_z80 / pull_z80

		cnop	0,4
push_z80:	lea	z80_registers,a6
		move.l	a0,(a6)+
		move.l	a1,(a6)+
		move.l	a2,(a6)+
		move.l	a3,(a6)+
		move.l	a4,(a6)+
		move.l	d0,(a6)+
		move.l	d1,(a6)+
		move.l	d2,(a6)+
		move.l	d3,(a6)+
		move.l	d4,(a6)+
		move.l	d5,(a6)
		rts

		cnop	0,4
pull_z80:	lea	z80_registers,a6
		move.l	(a6)+,a0
		move.l	(a6)+,a1
		move.l	(a6)+,a2
		move.l	(a6)+,a3
		move.l	(a6)+,a4
		move.l	(a6)+,d0
		move.l	(a6)+,d1
		move.l	(a6)+,d2
		move.l	(a6)+,d3
		move.l	(a6)+,d4
		move.l	(a6),d5
		rts


	SECTION	wzdata,DATA

; ---- wz.s 11537-11597: CPU and mapper variables
z80_cycles:	dc.l	22;92;456/5

gb_memory:	dc.l	0
bank_address:	dc.l	0
ram_bank_no:	dc.l	0
ram_banks:	dc.l	0
ram_banks_mask:	dc.l	0
rom_banks_mask:	dc.l	0

memory_banks:	dc.l	0
z80_pc_base:	dc.l	0

		IFD	IDL_PAIR
		dc.b	0,0				;(i_flag and z80_halt are beside idl_state.)
		ELSE
i_flag:		dc.b	0				;interrupt flag.
z80_halt:	dc.b	0				;halted cpu flag.
		ENDC
		even

h_other_I:	dc.b	0
h_other_II:	dc.b	0
h_with_carry:	dc.b	0
h_the_flag:	dc.b	0

mbc1_status:	dc.b	0
		IFND	NO_MBC1HI
mbc1_bank1:	dc.b	1				;AmiGameBoy: $2000 register (5 bits, never 0)
mbc1_bank2:	dc.b	0				;and $4000 register (2 bits).
		ENDC
mbc1_ram_protection_status:
		dc.b	0
mbc2_ram_protection_status:
		dc.b	0
mbc3_ram_protection_status:
		dc.b	0
		even

mbc3_latched_sec:
		dc.b	0
mbc3_latched_min:
		dc.b	0
mbc3_latched_hrs:
		dc.b	0
mbc3_latched_dayl:
		dc.b	0
mbc3_latched_dayh:
		dc.b	0

mbc3_sec:	dc.b	0
mbc3_min:	dc.b	0
mbc3_hrs:	dc.b	0
mbc3_day:
mbc3_dayh:	dc.b	0				;order is important.
mbc3_dayl:	dc.b	0

mbc3_latch_a:	dc.b	0
mbc3_latch_b:	dc.b	0
mbc3_existence:	dc.b	0
		even

mbc5_rom_bank:	dc.w	0
mbc5_rom_bank1:	dc.b	0
mbc5_rom_bank0:	dc.b	0

z80_registers:	ds.l	6+5				;d0-d5/a0-a4.

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		emulator variables

; ---- wz.s 11600-11772: h_values (STAT mode per sweep), h_values_indexed
h_values:	dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0

		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0

		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0

		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0

		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0

		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0

		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0

		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0

		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0

		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0

		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0

		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0

		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0

		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0

		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	2,3,3,0,0
		dc.b	1,1,1,1,1
		dc.b	1,1,1,1,1
		dc.b	1,1,1,1,1
		dc.b	1,1,1,1,1
		dc.b	1,1,1,1,1
		dc.b	1,1,1,1,1

		dc.b	1,1,1,1,1
		dc.b	1,1,1,1,1
		dc.b	1,1,1,1,1
		dc.b	1,1,0,0,0
		even

h_values_indexed:
		dc.l	0

; ---- wz.s 11780-11782: gb_scanlines, cartridge, cartridge_data
gb_scanlines:	dc.l	0
cartridge:	dc.l	0				;pointer to a cartridge.
cartridge_data:	dc.l	0

; ---- wz.s 11789-11789: rom_32k
rom_32k:	dc.l	0

; ---- wz.s 13371-13371: gb_mem_jumps
gb_mem_jumps:	dc.l	0

; ---- wz.s 13505-13513: ROM/RAM bank lists
rom_banks_list:	dc.l	2-1,4-1,8-1,16-1,32-1,64-1,128-1,256-1,512-1
		dc.l	0,9-1,10-1,12-1
		even

ram_banks_list:	dc.b	0,1,1,4,16
		even
ram_banks_mask_list:
		dc.b	0,0,0,3,15
		even

; ---- wz.s 13707-14333: pad bytes, RAM sizes, mapper write lists
buttons_byte:	dc.b	$cf
directions_byte:dc.b	$cf
buttons_byte_o:	dc.b	$cf
directions_byte_o:
		dc.b	$cf
		even

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		ram lists
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

ram_size_list:	dc.l	8192				;actually 0kb.
		dc.l	8192				;         2  .
		dc.l	8192
		dc.l	32768
		dc.l	131072
		dc.l	131072
		dc.l	131072
		dc.l	131072

mapper_list:	dc.l	mapper_na
		dc.l	mapper_mbc1
		dc.l	mapper_mbc1_ram
		dc.l	mapper_mbc1_ram_battery
		dc.l	mapper_na			;invalid entry.
		dc.l	mapper_mbc2
		dc.l	mapper_mbc2_battery
		dc.l	mapper_na			;invalid entry.
		dc.l	mapper_ram
		dc.l	mapper_ram_battery

		dc.l	mapper_na			;a.
		dc.l	mapper_na
		dc.l	mapper_na
		dc.l	mapper_na
		dc.l	mapper_na
		dc.l	mapper_mbc3_timer_battery	;f.

		dc.l	mapper_mbc3_timer_ram_battery	;10.
		dc.l	mapper_mbc3			;11.
		dc.l	mapper_mbc3_ram			;12.
		dc.l	mapper_mbc3_ram_battery		;13.
		dc.l	mapper_na
		dc.l	mapper_na			;15.
		dc.l	mapper_na			;16.
		dc.l	mapper_na			;17.
		dc.l	mapper_na

		dc.l	mapper_mbc5			;19.
		dc.l	mapper_mbc5_ram			;1a.
		dc.l	mapper_mbc5_ram_battery		;1b.
		dc.l	mapper_mbc5_rumble		;1c.
		dc.l	mapper_mbc5_rumble_sram		;1d.
		dc.l	mapper_mbc5_rumble_sram_battery	;1e.

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		ROM+HUC1+RAM (+BATTERY)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

mapper_huc1_ram:
mapper_huc1_ram_battery:
		dc.l	mapper_huc1_0kb_ram
		dc.l	mapper_huc1_2kb_ram
		dc.l	mapper_huc1_8kb_ram
		dc.l	mapper_huc1_32kb_ram

mapper_huc1_0kb_ram:
		dc.l	6-1,$2000-1
		dc.l	rom_write
		dc.l	mbc1_rom_switch
		dc.l	mbc1_rom_switch_two_address_lines
		dc.l	mbc1_rom_mode_select
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
;		dc.l	gb_mem_wr_denied

mapper_huc1_2kb_ram:
		dc.l	24-1,$800-1

		dc.l	mbc1_ram_protection
		dc.l	mbc1_ram_protection
		dc.l	mbc1_ram_protection
		dc.l	mbc1_ram_protection		;$2000.

		dc.l	mbc1_rom_switch
		dc.l	mbc1_rom_switch
		dc.l	mbc1_rom_switch
		dc.l	mbc1_rom_switch			;$4000.

		dc.l	mbc1_rom_switch_two_address_lines
		dc.l	mbc1_rom_switch_two_address_lines
		dc.l	mbc1_rom_switch_two_address_lines
		dc.l	mbc1_rom_switch_two_address_lines
							;$6000.
		dc.l	mbc1_rom_mode_select
		dc.l	mbc1_rom_mode_select
		dc.l	mbc1_rom_mode_select
		dc.l	mbc1_rom_mode_select		;$8000.

		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr			;$a000.

		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr			;$c000.

;		dc.l	gb_mem_wr
;		dc.l	gb_mem_wr_denied
;		dc.l	gb_mem_wr_denied
;		dc.l	gb_mem_wr_denied		;$c000.

mapper_huc1_8kb_ram:
		dc.l	4-1,$2000-1
		dc.l	mbc1_ram_protection
		dc.l	mbc1_rom_switch
		dc.l	mbc1_rom_switch_two_address_lines
		dc.l	mbc1_rom_mode_select

mapper_huc1_32kb_ram:
		dc.l	4-1,$2000-1
		dc.l	mbc1_ram_protection
		dc.l	mbc1_rom_switch
		dc.l	mbc1_ram_switch_with_two_rom_address_lines
		dc.l	mbc1_rom_mode_select

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		ROM+MBC5+RAM (+BATTERY)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

mapper_mbc5_ram:
mapper_mbc5_ram_battery:
mapper_mbc5_rumble_sram:
mapper_mbc5_rumble_sram_battery:
		dc.l	mapper_mbc5_0kb_ram
		dc.l	mapper_mbc5_2kb_ram
		dc.l	mapper_mbc5_8kb_ram
		dc.l	mapper_mbc5_32kb_ram
		dc.l	mapper_mbc5_128kb_ram

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		ROM+MBC5
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

mapper_mbc5:
mapper_mbc5_rumble:
		dc.l	mapper_mbc5_0kb_ram
		dc.l	mapper_mbc5_0kb_ram
		dc.l	mapper_mbc5_0kb_ram
		dc.l	mapper_mbc5_0kb_ram
		dc.l	mapper_mbc5_0kb_ram

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		MBC5
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

mapper_mbc5_0kb_ram:
		dc.l	8-1,$1000-1
		dc.l	rom_write
		dc.l	rom_write
		dc.l	mbc5_romb0			;$3000.
		dc.l	mbc5_romb1			;$4000.
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write			;$8000.

mapper_mbc5_2kb_ram:
		dc.l	8-1,$1000-1
		dc.l	rom_write
		dc.l	rom_write
		dc.l	mbc5_romb0			;$3000.
		dc.l	mbc5_romb1			;$4000.
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write			;$8000.

mapper_mbc5_8kb_ram:
		dc.l	8-1,$1000-1
		dc.l	rom_write
		dc.l	rom_write
		dc.l	mbc5_romb0			;$3000.
		dc.l	mbc5_romb1			;$4000.
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write			;$8000.

mapper_mbc5_32kb_ram:
		dc.l	8-1,$1000-1
		dc.l	mbc5_ramg
		dc.l	mbc5_ramg			;$2000.
		dc.l	mbc5_romb0			;$3000.
		dc.l	mbc5_romb1			;$4000.
		dc.l	mbc5_ramb
		dc.l	mbc5_ramb			;$6000.
		dc.l	rom_write
		dc.l	rom_write			;$8000.

mapper_mbc5_128kb_ram:
		dc.l	8-1,$1000-1
		dc.l	mbc5_ramg
		dc.l	mbc5_ramg			;$2000.
		dc.l	mbc5_romb0			;$3000.
		dc.l	mbc5_romb1			;$4000.
		dc.l	mbc5_ramb
		dc.l	mbc5_ramb			;$6000.
		dc.l	rom_write
		dc.l	rom_write			;$8000.

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		ROM+MBC3+RAM (+BATTERY)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

mapper_mbc3_timer_ram_battery:
mapper_mbc3_timer_battery:
mapper_mbc3:
mapper_mbc3_ram:
mapper_mbc3_ram_battery:
		dc.l	mapper_mbc3_0kb_ram
		dc.l	mapper_mbc3_2kb_ram
		dc.l	mapper_mbc3_8kb_ram
		dc.l	mapper_mbc3_32kb_ram

mapper_mbc3_0kb_ram:
		dc.l	4-1,$2000-1
		dc.l	mbc3_ram_protection
		dc.l	mbc3_rom_switch
		dc.l	rom_write
		dc.l	mbc3_latch_clock_counter_data

mapper_mbc3_2kb_ram:
		dc.l	4-1,$2000-1
		dc.l	mbc3_ram_protection
		dc.l	mbc3_rom_switch
		dc.l	rom_write
		dc.l	mbc3_latch_clock_counter_data

mapper_mbc3_8kb_ram:
		dc.l	4-1,$2000-1
		dc.l	mbc3_ram_protection
		dc.l	mbc3_rom_switch
		dc.l	rom_write
		dc.l	mbc3_latch_clock_counter_data

mapper_mbc3_32kb_ram:
		dc.l	4-1,$2000-1
		dc.l	mbc3_ram_protection
		dc.l	mbc3_rom_switch
		dc.l	mbc3_ram_switch_change_ram_bank
		dc.l	mbc3_latch_clock_counter_data

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		ROM ONLY
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

mapper_na:	dc.l	mapper_pure_rom
		dc.l	mapper_pure_rom
		dc.l	mapper_pure_rom
		dc.l	mapper_pure_rom

mapper_pure_rom:dc.l	6-1,$2000-1
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		ROM+MBC1
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

mapper_mbc1:	dc.l	mapper_mbc1_no_ram
		dc.l	mapper_mbc1_no_ram
		dc.l	mapper_mbc1_no_ram
		dc.l	mapper_mbc1_no_ram

mapper_mbc1_no_ram:
		dc.l	6-1,$2000-1
		dc.l	rom_write
		dc.l	mbc1_rom_switch
		dc.l	mbc1_rom_switch_two_address_lines
		dc.l	mbc1_rom_mode_select
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		ROM+MBC1+RAM (+BATTERY)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

mapper_mbc1_ram:
mapper_mbc1_ram_battery:
		dc.l	mapper_mbc1_0kb_ram
		dc.l	mapper_mbc1_2kb_ram
		dc.l	mapper_mbc1_8kb_ram
		dc.l	mapper_mbc1_32kb_ram

mapper_mbc1_0kb_ram:
		dc.l	6-1,$2000-1
		dc.l	rom_write
		dc.l	mbc1_rom_switch
		dc.l	mbc1_rom_switch_two_address_lines
		dc.l	mbc1_rom_mode_select
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr

mapper_mbc1_2kb_ram:
		dc.l	24-1,$800-1

		dc.l	mbc1_ram_protection
		dc.l	mbc1_ram_protection
		dc.l	mbc1_ram_protection
		dc.l	mbc1_ram_protection		;$2000.

		dc.l	mbc1_rom_switch
		dc.l	mbc1_rom_switch
		dc.l	mbc1_rom_switch
		dc.l	mbc1_rom_switch			;$4000.

		dc.l	mbc1_rom_switch_two_address_lines
		dc.l	mbc1_rom_switch_two_address_lines
		dc.l	mbc1_rom_switch_two_address_lines
		dc.l	mbc1_rom_switch_two_address_lines
							;$6000.
		dc.l	mbc1_rom_mode_select
		dc.l	mbc1_rom_mode_select
		dc.l	mbc1_rom_mode_select
		dc.l	mbc1_rom_mode_select		;$8000.

		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr			;$a000.

		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr			;$c000.

mapper_mbc1_8kb_ram:
		dc.l	4-1,$2000-1
		dc.l	mbc1_ram_protection
		dc.l	mbc1_rom_switch
		dc.l	mbc1_rom_switch_two_address_lines
		dc.l	mbc1_rom_mode_select

mapper_mbc1_32kb_ram:
		dc.l	4-1,$2000-1
		dc.l	mbc1_ram_protection
		dc.l	mbc1_rom_switch
		dc.l	mbc1_ram_switch_with_two_rom_address_lines
		dc.l	mbc1_rom_mode_select

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		ROM+MBC2 (+BATTERY)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

mapper_mbc2:
mapper_mbc2_battery:
		dc.l	mapper_mbc2_256b_ram
		dc.l	mapper_mbc2_256b_ram
		dc.l	mapper_mbc2_256b_ram
		dc.l	mapper_mbc2_256b_ram

mapper_mbc2_256b_ram:
		dc.l	192-1,$100-1
		dc.l	mbc2_ram_protection
		dc.l	rom_write
		dc.l	mbc2_ram_protection
		dc.l	rom_write
		dc.l	mbc2_ram_protection
		dc.l	rom_write
		dc.l	mbc2_ram_protection
		dc.l	rom_write
		dc.l	mbc2_ram_protection
		dc.l	rom_write
		dc.l	mbc2_ram_protection
		dc.l	rom_write
		dc.l	mbc2_ram_protection
		dc.l	rom_write
		dc.l	mbc2_ram_protection
		dc.l	rom_write
		dc.l	mbc2_ram_protection
		dc.l	rom_write
		dc.l	mbc2_ram_protection
		dc.l	rom_write
		dc.l	mbc2_ram_protection
		dc.l	rom_write
		dc.l	mbc2_ram_protection
		dc.l	rom_write
		dc.l	mbc2_ram_protection
		dc.l	rom_write
		dc.l	mbc2_ram_protection
		dc.l	rom_write
		dc.l	mbc2_ram_protection
		dc.l	rom_write
		dc.l	mbc2_ram_protection
		dc.l	rom_write			;$2000.

		dc.l	rom_write
		dc.l	mbc2_rom_switch
		dc.l	rom_write
		dc.l	mbc2_rom_switch
		dc.l	rom_write
		dc.l	mbc2_rom_switch
		dc.l	rom_write
		dc.l	mbc2_rom_switch
		dc.l	rom_write
		dc.l	mbc2_rom_switch
		dc.l	rom_write
		dc.l	mbc2_rom_switch
		dc.l	rom_write
		dc.l	mbc2_rom_switch
		dc.l	rom_write
		dc.l	mbc2_rom_switch
		dc.l	rom_write
		dc.l	mbc2_rom_switch
		dc.l	rom_write
		dc.l	mbc2_rom_switch
		dc.l	rom_write
		dc.l	mbc2_rom_switch
		dc.l	rom_write
		dc.l	mbc2_rom_switch
		dc.l	rom_write
		dc.l	mbc2_rom_switch
		dc.l	rom_write
		dc.l	mbc2_rom_switch
		dc.l	rom_write
		dc.l	mbc2_rom_switch
		dc.l	rom_write
		dc.l	mbc2_rom_switch			;$4000.

		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write			;$6000.

		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write			;$8000.

		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr			;a000.

		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr			;$c000.

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		ROM+RAM (+BATTERY)
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

mapper_ram:
mapper_ram_battery:
		dc.l	mapper_ram_0kb_ram
		dc.l	mapper_ram_2kb_ram
		dc.l	mapper_ram_8kb_ram
		dc.l	mapper_ram_8kb_ram		;illegal?

mapper_ram_0kb_ram:
		dc.l	6-1,$2000-1
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr

mapper_ram_2kb_ram:
		dc.l	24-1,$800-1

		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write			;$2000.

		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write			;$4000.

		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write			;$6000.

		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write			;$8000.

		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr			;$a000.

		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr			;$c000.

mapper_ram_8kb_ram:
		dc.l	4-1,$2000-1
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write

; ---- wz.s 14442-14447: timer rate table
freq_storage:	dc.l	0

		IFD	NO_TIMERRATE
freq_table:	dc.l	363				;(4096*4096)/(60*154*5).
		dc.l	23241				;(262144*4096)/(60*154*5).
		dc.l	5810				;(65536*4096)/(60*154*5).
		dc.l	1452				;(16384*4096)/(60*154*5).
		ELSE					;AmiGameBoy: a sweep is 456/5 T-cycles
freq_table:	dc.l	365				;(4096*4096*456)/(4194304*5) = 364.8
		dc.l	23347				;23347.2 (262144 Hz)
		dc.l	5837				;5836.8 (65536 Hz)
		dc.l	1459				;1459.2 (16384 Hz); Wzonka's assumed 60 Hz
		ENDC					;frames, 0.45 % slow.

; ---- wz.s 14822-15096: ffxx_jmp_table: $FF00-$FFFF write handlers
ffxx_jmp_table:	dc.l	do_joystick
		dc.l	sio_register
		dc.l	sio_control
		dc.l	gb_mem_wr
		dc.l	clear_divider
		IFD	NO_TIMAWRITE
		dc.l	gb_mem_wr
		ELSE
		dc.l	tima_write			;AmiGameBoy: TIMA writes kept.
		ENDC
		dc.l	gb_mem_wr
		dc.l	timc_protect
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	irq_protect_0f				;$0f.

		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	gb_mem_wr
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	gb_mem_wr				;$1f.

		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr				;$2f.

		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write
		dc.l	rom_write				;$3f.

		dc.l	lcd_mode_write
		dc.l	lcd_protect
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	ly_write
		dc.l	lyc_write
		dc.l	dma_execute
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write				;$4f.

		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write				;$5f.

		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write				;$6f.

		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write
		dc.l	no_write				;$7f.

		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr				;$8f.

		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr				;$9f.

		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr				;$af.

		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr				;$bf.

		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr				;$cf.

		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr				;$df.

		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr				;$ef.

		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	gb_mem_wr
		dc.l	irq_protect_ff				;$ff.

;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
;		memory lists
;««««««««««««««««««««««««««««««««««««««««««««««»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»

; ---- wz.s 15448-15451: irq_status_flags, transfer_counter
irq_status_flags:
		dc.b	0
transfer_counter:
		dc.b	0

; ---- wz.s 15592-15594: z80_cycles_left, z80_ei_return
z80_cycles_left:dc.l	0
start144_done:	dc.b	0				;AmiGameBoy.
lcd_restart:	dc.b	0				;AmiGameBoy: LCD switched on.
skip_lyc_once:	dc.b	0				;AmiGameBoy.
		IFND	NO_DIVRATE
div_frac:	dc.b	0				;AmiGameBoy: DIV fraction.
		ENDC
		even
SWEEPX		set	0
		IFND	NO_LINE114
SWEEPX		set	1
		ENDC
		IFND	NO_IRQ5
SWEEPX		set	1
		ENDC
		IFNE	SWEEPX
sweep_extra:	dc.l	0				;AmiGameBoy: overshoot carry + extra cycle.
		ENDC
idle_pc:	dc.l	0				;AmiGameBoy idle skip: last LDH A,(n).
idle_snap:	dc.l	0,0,0,0,0,0,0			;pc, de, bc, hl, sp, sweep no., RAM writes.
idle_writes:	dc.l	0				;RAM writes so far (idle skip).
idle_sweeps:	dc.l	0				;sweeps run (snapshot age).
idle_park:	dc.l	0				;parked host PC (the LDH opcode).
idle_addr:	dc.w	0				;$ff00+n of the parked read.
idle_snapval:	dc.b	0				;A read at the snapshot.
idle_val:	dc.b	0				;value the parked loop is waiting on.
idle_on:	dc.b	0				;parked: skip sweeps.
		even
		IFD	NO_IDLEPAD
		IFND	NO_IDLESKIP
		IFND	SPIKE_TRACE
		cnop	0,4
		IFD	IDL_QUICK
idl_bad:	dcb.l	16,0				;8 targets whose look made no record: address, visits left.
idl_badp:	dc.l	idl_bad
		ENDC
		IFD	IDL_STAT
idl_cnt:	dcb.l	8,0				;test: idle_jr, looks, records, known, CP (HL), last look at, the one before, changes.
		ENDC
idl_adr:	dc.l	0,0,0				;AmiGameBoy poll-loop skip: top, test, JR.
idl_pc:		dc.l	0				;where the last arithmetic sweep stopped.
idl_vp:		dc.l	0				;the polled byte,
idl_vp2:	dc.l	0				;the second one (or the first again).
idl_sig:	dc.l	0,0				;a state 2 loop known again: its first 8 bytes,
idl_regs:	dc.l	0,0,0				;DE, BC, HL.
idl_cost:	dc.b	0,0,0,0,0,0			;cycles: load, test, JR (twice).
idl_L:		dc.b	0				;cycles a pass.
idl_v:		dc.b	0				;the polled values.
idl_v2:		dc.b	0
idl_pos:	dc.b	0				;0-2: next instruction of the loop.
idl_state:	dc.b	0				;0 none, 1 on record, 2 arithmetic, 3 passes dropped.
idl_tmp:	dc.b	0				;0 state 2 will do, 1 state 3, -1 no record.
idl_known:	dc.b	0				;idl_sig and the rest of the record are a loop's.
idl_nld:	dc.b	0
idl_n:		dc.b	0				;instructions in the loop (state 2): 3, or 2 for CP (HL).
idl_tk:		dc.b	0				;the test: 0 AND A/OR A, 1 CP, 2 BIT, -1 CP A.
idl_cv:		dc.b	0				;CP: the value compared with; BIT: the bit.
idl_fl:		dc.b	0				;the JR looks at carry (else zero),
idl_want:	dc.b	0				;and jumps when it is set.
		even
		ENDC
		ENDC
		ENDC
		even
z80_ei_return:	dc.b	0
		even

; AmiGameBoy: the poll-loop skip's data in the layout that keeps the engine's (IDL_PAIR): the
; data in front stays where it was.
		IFD	IDL_PAIR
		cnop	0,4
z80_halt:	dc.b	0				;halted cpu flag: here, so that a dispatch clears it
idl_state:	dc.b	0				;and this with one clr.w. 0 none, 1 on record, 2 arithmetic, 3 passes dropped.
i_flag:		dc.b	0				;interrupt flag: with them (the main loop tests all
		dc.b	0				;three every sweep: one cache line).
		IFD	IDL_QUICK
idl_bad:	dcb.l	16,0				;8 targets whose look made no record: address, visits left.
idl_badp:	dc.l	idl_bad
		ENDC
		IFD	IDL_STAT
idl_cnt:	dcb.l	8,0				;test: idle_jr, looks, records, known, CP (HL), last look at, the one before, changes.
		ENDC
idl_adr:	dc.l	0,0,0				;AmiGameBoy poll-loop skip: top, test, JR.
idl_pc:		dc.l	0				;where the last arithmetic sweep stopped.
idl_vp:		dc.l	0				;the polled byte,
idl_vp2:	dc.l	0				;the second one (or the first again).
idl_sig:	dc.l	0,0				;a state 2 loop known again: its first 8 bytes,
idl_regs:	dc.l	0,0,0				;DE, BC, HL.
idl_cost:	dc.b	0,0,0,0,0,0			;cycles: load, test, JR (twice).
idl_L:		dc.b	0				;cycles a pass.
idl_v:		dc.b	0				;the polled values.
idl_v2:		dc.b	0
idl_pos:	dc.b	0				;0-2: next instruction of the loop.
idl_tmp:	dc.b	0				;0 state 2 will do, 1 state 3, -1 no record.
idl_known:	dc.b	0				;idl_sig and the rest of the record are a loop's.
idl_nld:	dc.b	0
idl_n:		dc.b	0				;instructions in the loop (state 2): 3, or 2 for CP (HL).
idl_tk:		dc.b	0				;the test: 0 AND A/OR A, 1 CP, 2 BIT, -1 CP A.
idl_cv:		dc.b	0				;CP: the value compared with; BIT: the bit.
idl_fl:		dc.b	0				;the JR looks at carry (else zero),
idl_want:	dc.b	0				;and jumps when it is set.
		even
		ENDC

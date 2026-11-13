; AmiGameBoy stage 0: engine spike (no display, no sound).
; Copyright (C) 2026 AmiGameBoy contributors. GPL-2 (see COPYING); the engine files it
; includes come from Wzonka-Lad 1.03 by Ville Helin and Ventzislav Tzvetkov.
;
; Runs Wzonka-Lad's CPU, frame loop, timer and mappers on a cartridge built into the
; executable, for SPIKE_FRAMES frames, under a running OS (nothing is taken over). Per
; frame it records the CIA-B TOD (horizontal lines) at the frame end before and after its
; own bookkeeping, a checksum of VRAM+OAM+$FF40-$FF4B (STAT, LY masked), the Game Boy PC, halt flag and
; LCDC. At the frames in DumpList it copies $8000-$FFFF. At the end it writes
;   GB:AmiGB.prof    binary, see WriteProf (read by tools/spike_read.py)
;   RAM:AmiGB.result "frames=xxxxxxxx" (the test Workbench copies it to GB:)
;
; Build: sh build.sh spike ROM    (VASMDEFS="-DSPIKE_FRAMES=600" to change the length)

GAMEBOY_DEBUG	=0
GAMEBOY_SERIAL	=0
Z80_MODE	=0
SPIKE		=1
INPUT_OK	=0
INPUT_GBS_LOAD	=1
INPUT_GBS_SAVE	=2
INPUT_HALT	=3

	IFND	SPIKE_FRAMES
SPIKE_FRAMES	=1800
	ENDC
NDUMPS		=3

; exec / dos offsets
AllocMem	=-198
FreeMem		=-210
OpenLibrary	=-552
CloseLibrary	=-414
CacheClearU	=-636
FindName	=-276
FindTask	=-294
SetTaskPri	=-300
ReadEClock	=-60
dosOpen		=-30
dosClose	=-36
dosWrite	=-48
MEMF_PUBLIC	=1
MEMF_CLEAR	=$10000
MODE_NEWFILE	=1006

REC_SIZE	=16		; per-frame record

	SECTION	spike,CODE

Start:	movem.l	d2-d7/a2-a6,-(sp)
	move.l	sp,SpikeSP
	move.l	4.w,a6
	move.l	a6,exec_base
	lea	DosName,a1
	moveq	#36,d0
	jsr	OpenLibrary(a6)
	move.l	d0,DosBase
	beq.w	.fail
	lea	$15e(a6),a0		; ExecBase->DeviceList
	lea	TimerName,a1
	jsr	FindName(a6)
	move.l	d0,TimerBase		; for ReadEClock (frame timing)
	beq.w	.fail
	IFND	SPIKE_PRI0
	sub.l	a1,a1			; run above Workbench and the shell so frame
	jsr	FindTask(a6)		; times are the engine's (SPIKE_PRI0: normal)
	move.l	d0,a1
	moveq	#10,d0
	jsr	SetTaskPri(a6)
	ENDC

; memory: Game Boy space, write table, battery banks, ROM images
	move.l	#$10000,d0
	bsr.w	Alloc
	move.l	d0,gb_memory
	beq.w	.fail
	move.l	#$40000,d0
	bsr.w	Alloc
	move.l	d0,gb_mem_jumps
	beq.w	.fail
	move.l	#131072+$2000,d0
	bsr.w	Alloc
	move.l	d0,memory_banks
	beq.w	.fail
	move.l	#EmbedCartEnd-EmbedCart,d0
	move.l	d0,file_length
	add.l	d0,d0
	bsr.w	Alloc
	move.l	d0,rom_32k
	beq.w	.fail
	move.l	#EmbedCart,cartridge_data

; header: bank masks and MBC3 flag (from Wzonka's do_info)
	lea	EmbedCart,a0
	moveq	#0,d0
	move.b	$148(a0),d0
	cmp.w	#9,d0
	bcs.s	.romok
	moveq	#8,d0
.romok:	lea	rom_banks_list,a1
	move.l	(a1,d0.w*4),rom_banks_mask
	moveq	#0,d0
	move.b	$149(a0),d0
	cmp.w	#5,d0
	bcs.s	.ramok
	moveq	#4,d0
.ramok:	moveq	#0,d1
	lea	ram_banks_list,a1
	move.b	(a1,d0.w),d1
	move.l	d1,ram_banks
	lea	ram_banks_mask_list,a1
	move.b	(a1,d0.w),d1
	move.l	d1,ram_banks_mask
	clr.b	mbc3_existence
	move.b	$147(a0),d0
	cmp.b	#$f,d0
	bcs.s	.nomb3
	cmp.b	#$13,d0
	bhi.s	.nomb3
	move.b	#1,mbc3_existence
.nomb3:
	bsr.w	gg_patch_apply		; ROM images (Wzonka)
	tst.l	d0
	bne.w	.fail
	move.l	cartridge,a0
	bsr.w	compute_jmp_lst		; write table (Wzonka)
	IFND	NO_SNDREGS
	move.l	gb_mem_jumps,a0		; sound registers stored (gb_extra.s)
	bsr.w	snd_regs_install
	ENDC
	IFD	SPIKE_IOLOG
	move.l	gb_mem_jumps,a0		; log LCDC and BGP writes
	adda.l	#$ff40*4,a0
	move.l	(a0),IoOrig40
	move.l	#spike_w40,(a0)
	move.l	7*4(a0),IoOrig47
	move.l	#spike_w47,7*4(a0)
	ENDC

	move.b	#1,snd_quality		; no AHI envelope sweeps
	move.b	#1,old_refresh		; no 144/144 drawing
	move.b	#$ff,refresh_scanline	; never draw
	clr.b	input_status
	clr.l	FrameNo
	bsr.w	ReadTOD
	move.l	d0,StartTOD
	bra.w	run_cartridge		; never returns; next_frame calls spike_frame

.fail:	moveq	#20,d0
	bra.w	Finish

; ---- called from next_frame (all registers preserved)
spike_frame:
	IFD	SPIKE_PRESS
	bsr.w	spike_press
	ENDC
	IFND	SPIKE_AT153
	IFND	NO_START144
	tst.b	SpikeStarted		; the loop starts at LY 144 (hand-over): not a frame end
	bne.s	.go
	st	SpikeStarted
	rts
.go:
	ENDC
	ENDC
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	a0,d0			; live host PC (at LY 144 the saved copy is stale)
	sub.l	z80_pc_base,d0
	move.w	d0,SpikePC
	bsr.w	ReadTOD
	move.l	FrameNo,d7
	lea	Records,a5
	lsl.l	#4,d7
	add.l	d7,a5
	move.l	d0,(a5)+		; entry time
	addq.l	#4,a5			; exit time later
; checksum VRAM, OAM, LCD registers
	move.l	gb_memory,a0
	lea	$8000(a0),a1
	moveq	#0,d0
	move.w	#$2000/4-1,d1
.ck1:	rol.l	#1,d0
	add.l	(a1)+,d0
	dbra	d1,.ck1
	lea	$fe00(a0),a1
	moveq	#$a0/4-1,d1
.ck2:	rol.l	#1,d0
	add.l	(a1)+,d0
	dbra	d1,.ck2
	lea	$ff40(a0),a1		; LCD registers less STAT and LY (frame-end timing)
	move.l	(a1)+,d1
	and.l	#$ff00ffff,d1
	rol.l	#1,d0
	add.l	d1,d0
	move.l	(a1)+,d1
	and.l	#$00ffffff,d1
	rol.l	#1,d0
	add.l	d1,d0
	rol.l	#1,d0
	add.l	(a1)+,d0
	move.l	d0,(a5)+
	move.w	SpikePC,(a5)+
	move.b	z80_halt,(a5)+
	move.b	$ff40(a0),(a5)+
	IFD	SPIKE_OPCOST
	move.l	OcIns,-16(a5)		; instructions this frame in place of the entry time
	clr.l	OcIns
	ENDC
; memory dump?
	move.l	FrameNo,d0
	addq.l	#1,d0
	move.l	d0,FrameNo
	IFD	SPIKE_TRACE_FROM
	cmp.l	#SPIKE_TRACE_FROM,d0
	bne.s	.notr
	st	TraceOn
.notr:
	ENDC
	lea	DumpList,a1
	lea	Dumps,a2
	moveq	#NDUMPS-1,d1
.dl:	cmp.l	(a1)+,d0
	beq.s	.dump
	add.l	#$8000,a2
	dbra	d1,.dl
	bra.s	.nodump
.dump:	lea	$8000(a0),a1
	move.w	#$8000/16-1,d1
.dc:	move.l	(a1)+,(a2)+
	move.l	(a1)+,(a2)+
	move.l	(a1)+,(a2)+
	move.l	(a1)+,(a2)+
	dbra	d1,.dc
.nodump:
	cmp.l	#SPIKE_FRAMES,d0
	bcc.s	SpikeExit
	bsr.w	ReadTOD
	move.l	FrameNo,d7
	subq.l	#1,d7
	lsl.l	#4,d7
	lea	Records+4,a5
	move.l	d0,(a5,d7.l)		; exit time
	movem.l	(sp)+,d0-d7/a0-a6
	rts

SpikeExit:
z80_halted:
	bsr.w	ReadTOD
	move.l	d0,EndTOD
	move.l	SpikeSP,sp
	bsr.w	WriteProf
	bsr.w	WriteResult
	moveq	#0,d0
Finish:	move.l	d0,-(sp)
	move.l	4.w,a6
	move.l	gb_memory,d0
	move.l	#$10000,d1
	bsr.w	Free
	move.l	gb_mem_jumps,d0
	move.l	#$40000,d1
	bsr.w	Free
	move.l	memory_banks,d0
	move.l	#131072+$2000,d1
	bsr.w	Free
	move.l	rom_32k,d0
	move.l	file_length,d1
	add.l	d1,d1
	bsr.w	Free
	move.l	DosBase,d0
	beq.s	.nodos
	move.l	d0,a1
	jsr	CloseLibrary(a6)
.nodos:	move.l	(sp)+,d0
	move.l	SpikeSP,sp
	movem.l	(sp)+,d2-d7/a2-a6
	rts

; d0 = size -> d0 = cleared public memory or 0
Alloc:	move.l	#MEMF_PUBLIC!MEMF_CLEAR,d1
	move.l	4.w,a6
	jmp	AllocMem(a6)

; d0 = pointer (or 0), d1 = size
Free:	tst.l	d0
	beq.s	.x
	move.l	d0,a1
	move.l	d1,d0
	move.l	4.w,a6
	jsr	FreeMem(a6)
.x:	rts

; CIA-B TOD (horizontal lines), 24 bits -> d0. Reading the high byte latches.
ReadTOD:				; E-clock ticks (709379 Hz PAL), low 32 bits: timer.device
	movem.l	d1/a0-a1/a6,-(sp)	; ReadEClock (CIA TODs glitch around vsync)
	move.l	TimerBase,a6
	lea	EClk,a0
	jsr	ReadEClock(a6)
	move.l	EClk+4,d0
	movem.l	(sp)+,d1/a0-a1/a6
	rts

; GB:AmiGB.prof: "AGB0", frames, start TOD, end TOD, NDUMPS, dump frame numbers,
; frames x 16-byte records, NDUMPS x 32 KB ($8000-$FFFF)
WriteProf:
	lea	ProfHead,a0
	move.l	#"AGB1",(a0)+		; AGB1: times in E-clock ticks
	move.l	FrameNo,(a0)+
	move.l	StartTOD,(a0)+
	move.l	EndTOD,(a0)+
	move.l	#NDUMPS,(a0)+
	lea	DumpList,a1
	moveq	#NDUMPS-1,d0
.c:	move.l	(a1)+,(a0)+
	dbra	d0,.c
	move.l	#ProfName,d1
	bsr.w	OpenNew
	beq.s	.x
	lea	ProfHead,a0
	move.l	#ProfHeadEnd-ProfHead,d0
	bsr.w	WriteBlk
	lea	Records,a0
	move.l	FrameNo,d0
	lsl.l	#4,d0
	bsr.w	WriteBlk
	lea	Dumps,a0
	move.l	#NDUMPS*$8000,d0
	bsr.w	WriteBlk
	IFD	SPIKE_TRACE
	lea	TraceCount,a0		; then: count, count x 12 bytes
	moveq	#4,d0
	bsr.w	WriteBlk
	lea	TraceBuf,a0
	move.l	TraceCount,d0
	mulu.l	#12,d0
	bsr.w	WriteBlk
	ENDC
	IFD	SPIKE_OPCOST
	lea	OcTab,a0		; then: 512 x (count, sum, min, max) longs
	move.l	#512*16,d0
	bsr.w	WriteBlk
	ENDC
	IFD	SPIKE_IOLOG
	lea	IoCount,a0		; then: count, count x 8 bytes
	moveq	#4,d0
	bsr.w	WriteBlk
	lea	IoBuf,a0
	move.l	IoCount,d0
	lsl.l	#3,d0
	bsr.w	WriteBlk
	ENDC
	bsr.w	CloseFile
.x:	rts

WriteResult:
	lea	ResultNum,a0
	move.l	FrameNo,d0
	moveq	#7,d1
.h:	rol.l	#4,d0
	move.b	d0,d2
	and.w	#15,d2
	move.b	HexDigits(pc,d2.w),(a0)+
	dbra	d1,.h
	move.l	#ResultName,d1
	bsr.w	OpenNew
	beq.s	.x
	lea	ResultText,a0
	move.l	#ResultEnd-ResultText,d0
	bsr.w	WriteBlk
	bsr.w	CloseFile
.x:	rts
HexDigits:	dc.b	"0123456789abcdef"

; d1 = name -> FileHandle (Z set on failure)
OpenNew:
	move.l	#MODE_NEWFILE,d2
	move.l	DosBase,a6
	jsr	dosOpen(a6)
	move.l	d0,FileHandle
	rts
; a0 = data, d0 = length
WriteBlk:
	move.l	FileHandle,d1
	move.l	a0,d2
	move.l	d0,d3
	move.l	DosBase,a6
	jmp	dosWrite(a6)
CloseFile:
	move.l	FileHandle,d1
	move.l	DosBase,a6
	jmp	dosClose(a6)

; ---- SPIKE_TRACE=n: PC, A, BC, DE, HL, SP (6 words) at each of the first n instruction
; dispatches (the PC is the opcode's address; a halt-bug refetch is off by one);
; SPIKE_TRACE_FROM=f: start at the beginning of frame f+1 (after f frames)
	IFD	SPIKE_TRACE
spike_trace:
	IFD	SPIKE_OPCOST
	bsr.w	spike_opcost
	ENDC
	IFD	SPIKE_TRACE_FROM
	tst.b	TraceOn
	beq.s	.go
	ENDC
	move.l	TraceCount,d6
	cmp.l	#SPIKE_TRACE,d6
	bcc.s	.go
	addq.l	#1,d6
	move.l	d6,TraceCount
	move.l	TracePtr,a6
	move.l	a0,d6
	subq.l	#1,d6
	sub.l	z80_pc_base,d6
	move.w	d6,(a6)+
	move.w	d3,(a6)+
	move.w	d1,(a6)+
	move.w	d0,(a6)+
	move.w	d2,(a6)+
	IFD	SPIKE_TRACE_LY		; SP replaced by the sweep: line x 5 + sweep
	move.l	h_values_indexed,d6
	sub.l	#h_values+1,d6
	move.w	d6,(a6)+
	ELSE
	move.w	d5,(a6)+
	ENDC
	move.l	a6,TracePtr
.go:	jmp	(a1,d7.l)
	ENDC

; ---- SPIKE_OPCOST (with SPIKE_TRACE=1): M-cycles each instruction cost the engine, by
; opcode ($100+n for CB n), from the drop in a5 between two dispatches in one sweep (an
; instruction that ends a sweep is not counted). SPIKE_OPCOST=2: only while the LCD is off.
; Also counts instructions per frame (stored in the frame record's entry-time field).
	IFD	SPIKE_OPCOST
spike_opcost:
	movem.l	d0/d6/a6,-(sp)
	addq.l	#1,OcIns
	move.l	OcPrevA5,d6
	sub.l	a5,d6			; cost of the previous instruction
	ble.s	.new			; a5 went up: a new sweep
	move.l	OcPrevIdx,d0
	bmi.s	.new
	lea	OcTab,a6
	lsl.l	#4,d0
	add.l	d0,a6
	addq.l	#1,(a6)+
	add.l	d6,(a6)+
	cmp.l	#1,-8(a6)
	bne.s	.notfirst
	move.l	d6,(a6)
	move.l	d6,4(a6)
	bra.s	.new
.notfirst:
	cmp.l	(a6),d6
	bcc.s	.nmin
	move.l	d6,(a6)
.nmin:	cmp.l	4(a6),d6
	bls.s	.new
	move.l	d6,4(a6)
.new:	moveq	#0,d0
	move.b	-1(a0),d0
	cmp.b	#$cb,d0
	bne.s	.idx
	move.b	(a0),d0
	add.w	#$100,d0
.idx:
	IFEQ	SPIKE_OPCOST-2
	move.l	gb_memory,a6
	adda.l	#$ff40,a6
	btst.b	#7,(a6)
	beq.s	.off
	moveq	#-1,d0
.off:
	ENDC
	move.l	d0,OcPrevIdx
	move.l	a5,OcPrevA5
	movem.l	(sp)+,d0/d6/a6
	rts
	ENDC

; ---- SPIKE_PRESS=2: the hybrid's HY_PRESS=2 presses (Start and A for 6 frames in every
; 100 up to 2400, counted as HyFrames: 0 at the hand-over's LY 144, then FrameNo+1)
	IFD	SPIKE_PRESS
spike_press:
	movem.l	d0-d1,-(sp)
	moveq	#0,d0
	tst.b	SpikeStarted
	beq.s	.n
	move.l	FrameNo,d0
	addq.l	#1,d0
.n:	moveq	#-1,d1
	IFEQ	SPIKE_PRESS-1			; =1: HY_PRESS=1 (Start, 6 in every 200 up to 1200)
	cmp.l	#1200,d0
	bcc.s	.set
	divu.w	#200,d0
	ELSE
	cmp.l	#2400,d0
	bcc.s	.set
	divu.w	#100,d0
	ENDC
	swap	d0
	cmp.w	#6,d0
	bcc.s	.set
	bclr	#3,d1
	IFNE	SPIKE_PRESS-1
	bclr	#0,d1
	ENDC
.set:	move.b	d1,buttons_byte
	movem.l	(sp)+,d0-d1
	rts
	ENDC

; ---- SPIKE_IOLOG: LCDC/BGP writes as (frame.w, LY.b, register.b, value.b, sweep line.b,
; 2 spare) into IoBuf, written after everything else in the prof (count.l first)
	IFD	SPIKE_IOLOG
spike_w40:
	move.l	a6,-(sp)
	move.l	#$40,a6
	bsr.s	spike_iolog
	move.l	(sp)+,a6
	move.l	IoOrig40,-(sp)
	rts
spike_w47:
	move.l	a6,-(sp)
	move.l	#$47,a6
	bsr.s	spike_iolog
	move.l	(sp)+,a6
	move.l	IoOrig47,-(sp)
	rts
spike_iolog:
	movem.l	d0/a0,-(sp)
	move.l	IoCount,d0
	cmp.l	#IOLOGN,d0
	bcc.s	.x
	addq.l	#1,IoCount
	lsl.l	#3,d0
	lea	IoBuf,a0
	add.l	d0,a0
	move.w	FrameNo+2,(a0)+
	move.l	a1,-(sp)
	move.l	a2,a1
	adda.l	#$ff44,a1
	move.b	(a1),(a0)+
	move.l	(sp)+,a1
	move.l	a6,d0
	move.b	d0,(a0)+
	move.b	d6,(a0)+
	move.b	gb_scanlines+3,(a0)+
	clr.w	(a0)
.x:	movem.l	(sp)+,d0/a0
	rts
	ENDC

; ---- stubs for Wzonka parts the spike leaves out
inputs_read:
runtime_gbs_save:
runtime_gbs_load:
screen_draw:
scanline_draw:
	rts
snd_high_do:	bra.w	snd_high_back
sfx_update_all:	bra.w	sfx_back
load_error_unknown_size:
	moveq	#2,d0
	rts

	include	"wz_engine.s"
	SECTION	spike,CODE		; wz_engine.s ends in its data section
	include	"gb_extra.s"
	include	"z80_misc.s"
	include	"z80_full_III.s"

	SECTION	spikedata,DATA
exec_base:	dc.l	0
DosBase:	dc.l	0
SpikeSP:	dc.l	0
FileHandle:	dc.l	0
FrameNo:	dc.l	0
TraceCount:	dc.l	0
TraceOn:	dc.b	0
SpikeStarted:	dc.b	0
	even
SpikePC:	dc.w	0
	even
	IFD	SPIKE_TRACE
TracePtr:	dc.l	TraceBuf
	ENDC
	IFD	SPIKE_IOLOG
IOLOGN		=30000
IoOrig40:	dc.l	0
IoOrig47:	dc.l	0
IoCount:	dc.l	0
	ENDC
	IFD	SPIKE_OPCOST
OcPrevA5:	dc.l	0
OcPrevIdx:	dc.l	-1
OcIns:		dc.l	0
	ENDC
StartTOD:	dc.l	0
TimerBase:	dc.l	0
EClk:		dc.l	0,0
EndTOD:		dc.l	0
file_length:	dc.l	0
	IFND	DUMP1
DUMP1	=300
	ENDC
	IFND	DUMP2
DUMP2	=900
	ENDC
DumpList:	dc.l	DUMP1,DUMP2,SPIKE_FRAMES
DosName:	dc.b	"dos.library",0
TimerName:	dc.b	"timer.device",0
ProfName:	dc.b	"GB:AmiGB.prof",0
ResultName:	dc.b	"RAM:AmiGB.result",0
ResultText:	dc.b	"frames="
ResultNum:	dc.b	"00000000",10
ResultEnd:
; Wzonka variables that lived in its front end
snd_quality:	dc.b	1
snd_chnlI:	dc.b	0
old_refresh:	dc.b	1
refresh_scanline: dc.b	$ff
output_bit:	dc.b	0
frame_update:	dc.b	0
input_status:	dc.b	0
old_render:	dc.b	0
rom_type:	dc.b	0
sound_I_onf_master:	dc.b	0
sound_II_onf_master:	dc.b	0
sound_III_onf_master:	dc.b	0
sound_IV_onf_master:	dc.b	0
	even

	SECTION	spikebss,BSS
ProfHead:	ds.l	5+NDUMPS
ProfHeadEnd:
Records:	ds.b	REC_SIZE*(SPIKE_FRAMES+1)
Dumps:		ds.b	NDUMPS*$8000
	IFD	SPIKE_TRACE
TraceBuf:	ds.b	12*SPIKE_TRACE
	ENDC
	IFD	SPIKE_IOLOG
IoBuf:		ds.b	8*IOLOGN
	ENDC
	IFD	SPIKE_OPCOST
OcTab:		ds.b	512*16
	ENDC

	SECTION	EmbedRom,DATA
	cnop	0,4
EmbedCart:	INCBIN	"../../build/spike_rom.bin"
EmbedCartEnd:

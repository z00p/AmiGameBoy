; AmiGameBoy hybrid: Game Boy sound on Paula (docs/design-hybrid.md 7, stage 3 first pass).
; Copyright (C) 2026 AmiGameBoy contributors. GPL-2 (see src/engine/COPYING).
;
; Each Game Boy channel plays on its own Paula voice as a looping sample:
;   ch1, ch2  squares: an 8-byte duty cycle (HyDuty), period from the 11-bit frequency;
;             above 3.5 kHz 4 samples a cycle, above 7.1 kHz 2 (HyDuty4, HyDuty2), to
;             14.3 kHz (NO_SQHIGH: silent above 3.5 kHz). Above that the square is too
;             fast to hear and what is left is its mean level, which the volume moves
;             (the Game Boy's volume-driven samples and clicks): a constant sample, its
;             level in AUDxVOL (HyDutyDC; NO_SQDC: silent)
;   ch3       wave: wave RAM as 32 signed samples (16, 8, 4 or 2 of them for high notes,
;             to 13 kHz; NO_SQHIGH: 16 or 8, to 3.4 kHz)
;   ch4       noise: an LFSR sequence (15-bit: 8 KB of it; 7-bit: two periods) at the NR43
;             clock rate. Clocks beyond Paula's top rate (period 124, 28.6 kHz): 15-bit at
;             the top rate with the level turned down by the clock (C_GAIN); 7-bit from
;             tables of the buzz at its true pitch (HyNoise7T, noise7.bin)
;             (NO_NOISERATE: both at the top rate as they are)
; The voices loop all the time; a silent channel has volume 0, so triggers need no DMA
; restart (only a noise width change does, see HySndNoise). Volume = envelope (or NR32)
; x NR50 side volume, from HyVolTab, in AUDxVOL.
; Register writes come through Wzonka's write table (HyPatchWrites -> HySndTab); the
; frame sequencer (length 256 Hz, sweep 128 Hz, envelope 64 Hz) steps every 8192 T-cycles
; of emulated time from the engine's per-line hook (snd_high_do, wz_engine.s), so it keeps
; going on frames whose picture is skipped.
; Voices: ch1 -> 0 (left), ch2 -> 1 (right), ch3 -> 2 (right), ch4 -> 3 (left). NR51 can't
; move a channel to the other side (fixed voices): a channel routed to neither side is
; silent; otherwise it plays at the NR50 volume of its voice's side if routed there, else
; at the other side's.
; Not done (first pass): DMG quirks (the extra length clock, sweep
; negate quirk), wave RAM reads while playing, NR51 panning as voice choice.
;
; Write handlers are called with d6.b = value, d7.l = address, a2 = Game Boy memory; they
; keep every register but d6 and a6 (glue.s).

; channel block
C_VOICE	=0		; l Paula voice ($DFF0A0 + 16 x voice)
C_ON	=4		; b on (NR52 status)
C_VOL	=5		; b volume 0-15
C_ENVP	=6		; b envelope period, 0 = none
C_ENVT	=7		; b envelope timer
C_ENVUP	=8		; b bit 3: envelope goes up; bit 7: it has stopped at 0 or 15 (NO_ZOMBIE: 0/8)
C_LENEN	=9		; b length counter enabled (NRx4 bit 6)
C_LEN	=10		; w length counter
C_FREQ	=12		; w 11-bit frequency
C_MUTE	=14		; b pitch beyond Paula: silent
C_SHIFT	=15		; b volume shift (ch3, NR32), 8 = silent
C_BIT	=16		; b channel number 0-3 (NR51, NR52 bits)
C_SIDE	=17		; b voice side: 0 = left, 1 = right
C_DAC	=18		; b DAC on
C_GAIN	=19		; b level x/256, 0 = full (ch4: 15-bit noise clocked beyond Paula's rate)
C_SIZE	=20

HY_SND	reg	d0-d3/a0-a1

	IFD	NO_SQHIGH
	IFD	NO_SQDC
HY_SQ8	=1			; squares: the 8-sample loop only, as before
	ENDC
	ENDC

NR10	=RRAM+$1f10
NR52	=RRAM+$1f26

; ignore a register write while the APU is off (NR52 bit 7 clear)
SND_POWERED	MACRO
	btst	#7,NR52
	bne.w	.pw\@
	rts
.pw\@:
	ENDM

; ---- set-up, after CongelaAMIGA: samples, voices on (silent)
HySndInit:
	movem.l	d0-d3/a0-a1,-(sp)
	lea	HyNoise15,a0		; 15-bit LFSR, output = NOT bit 0
	move.w	#$7fff,d1
	move.w	#HY_N15LEN-1,d3
	bsr.w	.lfsr
	lea	HyNoise7,a0		; 7-bit: two periods of 127
	move.w	#$7f,d1
	move.w	#2*127-1,d3
	bsr.w	.lfsr7
	lea	HyCh1,a0		; channel blocks
	move.l	#$dff0a0,d0
	moveq	#0,d1
.ch:	move.l	d0,C_VOICE(a0)
	clr.l	C_ON(a0)
	clr.l	C_ENVUP(a0)
	clr.l	C_FREQ(a0)
	move.b	d1,C_BIT(a0)
	move.b	.side(pc,d1.w),C_SIDE(a0)
	clr.b	C_DAC(a0)
	IFND	NO_NOISERATE
	clr.b	C_GAIN(a0)
	ENDC
	add.l	#16,d0
	lea	C_SIZE(a0),a0
	addq.w	#1,d1
	cmp.w	#4,d1
	bne.w	.ch
	move.b	#8,HyCh3+C_SHIFT
	move.b	#15,HyCh3+C_VOL		; wave: full scale, NR32 shifts it
	move.w	#$00ff,$dff09e		; ADKCON: no attach/modulation
	lea	$dff0a0,a0
	lea	HyDuty,a1		; ch1, ch2: 12.5 % duty
	bsr.w	.voice
	lea	HyDuty,a1
	bsr.w	.voice
	lea	HyWave32,a1
	move.l	a1,(a0)
	move.w	#16,4(a0)
	move.w	#400,6(a0)
	clr.w	8(a0)
	lea	16(a0),a0
	lea	HyNoise15,a1
	move.l	a1,(a0)
	move.w	#HY_N15LEN/2,4(a0)
	move.w	#400,6(a0)
	clr.w	8(a0)
	clr.b	HyNoiseW
	clr.b	HySndPend
	move.w	#400,HyNoiseP
	clr.b	HySndStepN
	sf	HyWaveDirty
	IFND	HY_SQ8
	clr.w	HySqTier
	ENDC
	move.w	#8192,HySndSeq
	move.w	#$800f,$dff096		; audio DMA on
	movem.l	(sp)+,d0-d3/a0-a1
	rts
.side:	dc.b	0,1,1,0
.voice:	move.l	a1,(a0)
	move.w	#4,4(a0)
	move.w	#400,6(a0)
	clr.w	8(a0)
	lea	16(a0),a0
	rts
; d1 = LFSR, d3 = samples - 1, a0 = out
.lfsr:	moveq	#120,d0
	btst	#0,d1
	beq.w	.l1
	moveq	#-120,d0
.l1:	move.b	d0,(a0)+
	move.w	d1,d0
	lsr.w	#1,d0
	eor.w	d1,d0			; bit 0 = bit 0 xor bit 1
	lsr.w	#1,d1
	and.w	#1,d0
	ror.w	#2,d0			; -> bit 14
	or.w	d0,d1
	dbra	d3,.lfsr
	rts
.lfsr7:	moveq	#120,d0
	btst	#0,d1
	beq.w	.l2
	moveq	#-120,d0
.l2:	move.b	d0,(a0)+
	move.w	d1,d0
	lsr.w	#1,d0
	eor.w	d1,d0
	lsr.w	#1,d1
	and.w	#1,d0
	lsl.w	#6,d0			; -> bit 6
	or.w	d0,d1
	dbra	d3,.lfsr7
	rts

; ---- leaving: voices silent, audio DMA off
HySndStop:
	moveq	#0,d0
	move.w	d0,$dff0a8
	move.w	d0,$dff0b8
	move.w	d0,$dff0c8
	move.w	d0,$dff0d8
	move.w	#$000f,$dff096
	rts

; ---- AUDxVOL for channel a0 (d0-d2/a1 used)
HySndVol:
	moveq	#0,d0
	tst.b	C_ON(a0)
	beq.w	.w
	tst.b	C_MUTE(a0)
	bne.w	.w
	move.b	RRAM+$1f25,d1		; NR51: bits 0-3 right (SO1), 4-7 left (SO2)
	move.b	C_BIT(a0),d2
	tst.b	C_SIDE(a0)
	bne.w	.r
	addq.b	#4,d2			; left voice: routed left?
	btst	d2,d1
	bne.w	.ml
	subq.b	#4,d2
	btst	d2,d1
	beq.w	.w			; routed nowhere
	bra.w	.mr
.r:	btst	d2,d1			; right voice: routed right?
	bne.w	.mr
	addq.b	#4,d2
	btst	d2,d1
	beq.w	.w
.ml:	move.b	RRAM+$1f24,d1		; NR50 left volume (bits 6-4)
	lsr.b	#4,d1
	bra.w	.m
.mr:	move.b	RRAM+$1f24,d1		; NR50 right volume (bits 2-0)
.m:	and.w	#7,d1
	move.b	C_VOL(a0),d0
	lsl.w	#3,d0
	or.w	d1,d0
	move.b	HyVolTab(pc,d0.w),d0
	move.b	C_SHIFT(a0),d1
	lsr.w	d1,d0
	IFND	NO_NOISERATE
	move.b	C_GAIN(a0),d1		; noise clocked beyond Paula's rate: level x/256
	beq.w	.w
	and.w	#$ff,d1
	mulu.w	d1,d0
	add.w	#128,d0
	lsr.w	#8,d0
	ENDC
.w:	move.l	C_VOICE(a0),a1
	move.w	d0,8(a1)
	rts

; Paula volume for Game Boy volume v (0-15) x NR50 side m (0-7): v*(m+1)*64/120
HyVolTab:
	dc.b	0,0,0,0,0,0,0,0,1,1,2,2,3,3,4,4,1,2,3,4,5,6,7,9,2,3,5,6,8,10,11,13
	dc.b	2,4,6,9,11,13,15,17,3,5,8,11,13,16,19,21,3,6,10,13,16,19,22,26
	dc.b	4,7,11,15,19,22,26,30,4,9,13,17,21,26,30,34,5,10,14,19,24,29,34,38
	dc.b	5,11,16,21,27,32,37,43,6,12,18,23,29,35,41,47,6,13,19,26,32,38,45,51
	dc.b	7,14,21,28,35,42,49,55,7,15,22,30,37,45,52,60,8,16,24,32,40,48,56,64
	even

; ---- all four volumes (NR50, NR51 changed)
HySndAllVol:
	lea	HyCh1,a0
	bsr.w	HySndVol
	lea	HyCh2,a0
	bsr.w	HySndVol
	lea	HyCh3,a0
	bsr.w	HySndVol
	lea	HyCh4,a0
	bra.w	HySndVol

; ---- channel a0 off (length, sweep overflow, DAC off)
HySndOff:
	clr.b	C_ON(a0)
	bsr.w	HySndVol
;	fall through
; ---- NR52 from the channel states (d0 used)
HySndStatus:
	moveq	#0,d0
	tst.b	HyCh1+C_ON
	beq.w	.1
	bset	#0,d0
.1:	tst.b	HyCh2+C_ON
	beq.w	.2
	bset	#1,d0
.2:	tst.b	HyCh3+C_ON
	beq.w	.3
	bset	#2,d0
.3:	tst.b	HyCh4+C_ON
	beq.w	.4
	bset	#3,d0
.4:	or.b	#$70,d0
	btst	#7,NR52
	beq.w	.5
	or.b	#$80,d0
.5:	move.b	d0,NR52
	rts

; ---- square period (ch1, ch2): Paula plays 8 samples a cycle:
; period = 3546895 * (2048-f) / (8 * 131072) = (2048-f) * 55420.2 / 16384
	IFD	HY_SQ8
HySndPerSq:
	move.w	#2048,d0
	sub.w	C_FREQ(a0),d0
	mulu.w	#55420,d0
	add.l	#1<<13,d0		; round
	moveq	#14,d1
	lsr.l	d1,d0
	move.l	C_VOICE(a0),a1
	cmp.w	#124,d0
	bcs.w	HySndHigh
	move.w	d0,6(a1)
	ELSE
; above 3.5 kHz the 8-sample period would be under Paula's 124: 4 samples a cycle, then 2
HySndPerSq:
	move.w	#2048,d0
	sub.w	C_FREQ(a0),d0
	mulu.w	#55420,d0
	move.l	d0,d2
	add.l	#1<<13,d0		; round
	moveq	#14,d1
	lsr.l	d1,d0
	moveq	#0,d1			; 8 samples a cycle
	cmp.w	#124,d0
	bcc.w	.ok
	move.l	d2,d0
	add.l	#1<<12,d0
	moveq	#13,d1
	lsr.l	d1,d0
	moveq	#1,d1			; 4 samples: to 7.1 kHz
	cmp.w	#124,d0
	bcc.w	.hi
	move.l	d2,d0
	add.l	#1<<11,d0
	moveq	#12,d1
	lsr.l	d1,d0
	moveq	#2,d1			; 2 samples: to 14.3 kHz
	cmp.w	#124,d0
	bcc.w	.hi
	IFD	NO_SQDC
	bra.w	HySndHigh		; above: silent
	ELSE
	moveq	#124,d0			; above: a constant level
	moveq	#3,d1
	bra.w	.ok
	ENDC
.hi:
	IFD	NO_SQHIGH
	bra.w	HySndHigh
	ENDC
.ok:	move.l	C_VOICE(a0),a1
	move.w	d0,6(a1)
	moveq	#0,d2
	move.b	C_BIT(a0),d2
	lea	HySqTier,a1
	add.w	d2,a1
	cmp.b	(a1),d1			; samples a cycle as before: the loop stays
	beq.w	HySndInRange
	move.b	d1,(a1)
	lea	RRAM+$1f11,a1		; duty from NR11 / NR21
	tst.b	d2
	beq.w	.d
	addq.l	#5,a1
.d:	move.b	(a1),d2
	lsr.b	#6,d2
	bsr.w	HySqSmp
	ENDC
HySndInRange:
	tst.b	C_MUTE(a0)
	bne.w	.un
	rts
.un:	clr.b	C_MUTE(a0)
	bra.w	HySndVol
HySndHigh:				; above Paula's rate: silent
	tst.b	C_MUTE(a0)
	bne.w	.x
	st	C_MUTE(a0)
	bra.w	HySndVol
.x:	rts

	IFND	HY_SQ8
; ---- AUDxLC/LEN of square a0: duty d2.l (0-3) in the loop d1.w (0 = 8 samples a cycle,
; 1 = 4, 2 = 2, 3 = constant); Paula takes it at the end of the loop playing now. d0-d2/a1 used
HySqSmp:
	lea	HySqT(pc),a1
	lea	(a1,d1.w*4),a1
	move.b	(a1)+,d0		; bytes a duty, as a shift
	lsl.w	d0,d2
	moveq	#0,d0
	move.b	(a1)+,d0		; words
	add.b	(a1),d2			; + where the loops start in HyDuty
	add.l	#HyDuty,d2
	move.l	C_VOICE(a0),a1
	move.w	d0,4(a1)
	move.l	d2,(a1)
	rts
HySqT:	dc.b	3,4,0,0, 2,2,HyDuty4-HyDuty,0, 1,1,HyDuty2-HyDuty,0
	IFND	NO_SQDC
	dc.b	1,1,HyDutyDC-HyDuty,0
	ENDC
	even
	ENDC

; ---- wave period (ch3): 32 samples a cycle at 65536/(2048-f) Hz, so
; period = (2048-f) * 55420.2 / 32768; 16 or 8 samples (from HySndWave) for high notes
HySndPerWave:
	move.w	#2048,d0
	sub.w	C_FREQ(a0),d0
	mulu.w	#55420,d0
	move.l	d0,d2
	add.l	#1<<14,d0
	moveq	#15,d1
	lsr.l	d1,d0
	lea	HyWave32,a1
	moveq	#16,d1
	cmp.w	#124,d0
	bcc.w	.ok
	move.l	d2,d0			; 16 samples
	add.l	#1<<13,d0
	moveq	#14,d1
	lsr.l	d1,d0
	lea	HyWave16,a1
	moveq	#8,d1
	cmp.w	#124,d0
	bcc.w	.ok
	move.l	d2,d0			; 8 samples
	add.l	#1<<12,d0
	moveq	#13,d1
	lsr.l	d1,d0
	lea	HyWave8,a1
	moveq	#4,d1
	cmp.w	#124,d0
	IFD	NO_SQHIGH
	bcs.w	HySndHigh
	ELSE
	bcc.w	.ok
	move.l	d2,d0			; 4 samples
	add.l	#1<<11,d0
	moveq	#12,d1
	lsr.l	d1,d0
	lea	HyWave4,a1
	moveq	#2,d1
	cmp.w	#124,d0
	bcc.w	.ok
	move.l	d2,d0			; 2 samples
	add.l	#1<<10,d0
	moveq	#11,d1
	lsr.l	d1,d0
	lea	HyWave2,a1
	moveq	#1,d1
	cmp.w	#124,d0
	bcs.w	HySndHigh
	ENDC
.ok:	move.l	a1,d2
	move.l	C_VOICE(a0),a1
	move.l	d2,(a1)			; taken at the end of the loop playing now
	move.w	d1,4(a1)
	move.w	d0,6(a1)
	bra.w	HySndInRange

; ---- noise (ch4) from NR43: clock 524288 / r / 2^(s+1) (r = 0: 0.5), sample width
	IFD	NO_NOISERATE
HySndNoise:
	lea	HyCh4,a0
	moveq	#0,d0
	move.b	RRAM+$1f22,d0
	move.w	d0,d1
	and.w	#7,d1
	lsr.w	#4,d0
	lsl.w	#3,d0
	or.w	d1,d0
	move.w	HyNoisePer(pc,d0.w*2),d0
	beq.w	HySndHigh		; s = 14, 15: no clock
	move.l	C_VOICE(a0),a1
	move.w	HyNoiseP,d3		; period Paula is playing now
	move.w	d0,HyNoiseP
	move.w	d0,6(a1)
	moveq	#0,d1			; width: bit 3 = 7-bit
	btst	#3,RRAM+$1f22
	sne	d1
	cmp.b	HyNoiseW,d1
	beq.w	HySndInRange
	move.b	d1,HyNoiseW		; width changed: the new sample must start now, not
	move.w	#$0008,$dff096		; at the end of an 8 KB loop. Voice 3 DMA off, new
	lea	HyNoise15,a1		; sample, back on once Paula has finished the sample
	move.w	#HY_N15LEN/2,d2		; it is playing (one old period): wait for that here
	tst.b	d1			; up to 7000 (~2 ms), else from the next VBL but one
	beq.w	.w			; (HyVBL)
	lea	HyNoise7,a1
	move.w	#127,d2
.w:	move.l	C_VOICE(a0),a6
	move.l	a1,(a6)
	move.w	d2,4(a6)
	cmp.w	#7000,d3
	bhi.w	.later
	ext.l	d3
	divu.w	#227,d3			; beam lines (227 colour clocks each) + 2
	addq.w	#2,d3
.l:	move.b	$dff006,d1
.l2:	cmp.b	$dff006,d1
	beq.w	.l2
	dbra	d3,.l
	move.w	#$8008,$dff096
	bra.w	HySndInRange
.later:	move.b	#2,HySndPend
	bra.w	HySndInRange
	ELSE
HySndNoise:
	lea	HyCh4,a0
	moveq	#0,d0
	move.b	RRAM+$1f22,d0
	move.w	d0,d1
	and.w	#7,d1
	lsr.w	#4,d0
	lsl.w	#3,d0
	or.w	d1,d0
	moveq	#0,d2			; clock class: 0 = Paula reaches it, 1-9 = faster
	cmp.w	#40,d0
	bcc.w	.cl
	lea	HyNoiseCls(pc),a1
	move.b	(a1,d0.w),d2
.cl:	move.w	HyNoisePer(pc,d0.w*2),d0
	beq.w	HySndHigh		; s = 14, 15: no clock
	moveq	#0,d1			; sample: 0 = 15-bit, $FF = 7-bit, 1-9 = 7-bit for
	btst	#3,RRAM+$1f22		; that clock class; d2 = level
	bne.w	.n7
	lea	HyNoiseGain(pc),a1
	move.b	(a1,d2.w),d2		; 15-bit beyond Paula: top rate, level by the clock
	bra.w	.set
.n7:	st	d1
	tst.w	d2
	beq.w	.set
	move.b	d2,d1			; 7-bit beyond Paula: top rate, the table for the clock
	moveq	#0,d2
.set:	move.l	C_VOICE(a0),a1
	move.w	HyNoiseP,d3		; period Paula is playing now
	move.w	d0,HyNoiseP
	move.w	d0,6(a1)
	cmp.b	C_GAIN(a0),d2
	beq.w	.g
	move.b	d2,C_GAIN(a0)		; level changed: AUDxVOL again
	movem.w	d1/d3,-(sp)
	bsr.w	HySndVol
	movem.w	(sp)+,d1/d3
.g:	cmp.b	HyNoiseW,d1
	beq.w	HySndInRange
	move.b	d1,HyNoiseW		; sample changed: the new one must start now, not at
	move.w	#$0008,$dff096		; the end of the loop. Voice 3 DMA off, new sample,
					; back on after one old period: waited for here up
					; to 7000 (~2 ms), else from the next VBL but one
	lea	HyNoise15,a1
	move.w	#HY_N15LEN/2,d2
	tst.b	d1
	beq.w	.w
	lea	HyNoise7,a1
	move.w	#127,d2
	tst.b	d1
	bmi.w	.w
	moveq	#0,d0
	move.b	d1,d0
	lea	HyN7Tab-4(pc),a1
	lea	(a1,d0.w*4),a1
	move.w	2(a1),d2
	moveq	#0,d0
	move.w	(a1),d0
	lea	HyNoise7T,a1
	add.l	d0,a1
.w:	move.l	C_VOICE(a0),a6
	move.l	a1,(a6)
	move.w	d2,4(a6)
	cmp.w	#7000,d3
	bhi.w	.later
	ext.l	d3
	divu.w	#227,d3
	addq.w	#2,d3
.l:	move.b	$dff006,d1
.l2:	cmp.b	$dff006,d1
	beq.w	.l2
	dbra	d3,.l
	move.w	#$8008,$dff096
	bra.w	HySndInRange
.later:	move.b	#2,HySndPend
	bra.w	HySndInRange
	ENDC

; Paula periods for NR43 (s x 8 + r), clamped to 124-65535; 0 = no clock
HyNoisePer:
	dc.w	124,124,124,124,124,124,124,124,124,124,124,124,124,135,162,189
	dc.w	124,124,124,162,216,271,325,379,124,124,216,325,433,541,649,758
	dc.w	124,216,433,649,866,1082,1299,1515,216,433,866,1299,1732,2165,2598,3031
	dc.w	433,866,1732,2598,3464,4330,5196,6062,866,1732,3464,5196,6928,8659,10391,12123
	dc.w	1732,3464,6928,10391,13855,17319,20783,24246,3464,6928,13855,20783,27710,34638,41565,48493
	dc.w	6928,13855,27710,41565,55420,65535,65535,65535,13855,27710,55420,65535,65535,65535,65535,65535
	dc.w	27710,55420,65535,65535,65535,65535,65535,65535,55420,65535,65535,65535,65535,65535,65535,65535
	dc.w	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

	IFND	NO_NOISERATE
; NR43 clocks beyond Paula's rate, s x 8 + r for s = 0-4: class 1-9 = 524, 262, 131, 87,
; 65.5, 52, 43.7, 37.4, 32.8 kHz; 0 = within reach
HyNoiseCls:
	dc.b	1,2,3,4,5,6,7,8, 2,3,5,7,9,0,0,0, 3,5,9,0,0,0,0,0, 5,9,0,0,0,0,0,0
	dc.b	9,0,0,0,0,0,0,0
; 15-bit, per class: level x/256 (0 = full).
; White noise clocked at c has its power spread up to c/2, so less of it falls in
; the audio band the faster the clock (3 dB an octave). Played at Paula's top rate at full
; level it came out 1.4, 3.8, 6.5 and 9.4 dB over Mesen 2 at 65.5, 131, 262 and 524 kHz
; (docs/sound-baseline.md 1.1; 0.3 dB at 32.8 kHz, left alone with 37.4 and 43.7). The
; levels here are those figures and 0.5 dB more (52 and 87 kHz by the same slope): Paula
; has no noise above 14 kHz to give, so at Mesen's overall level the bands under 8 kHz
; would sit 3 dB over Mesen's; a pure power-per-hertz match would be 3 dB under overall.
HyNoiseGain:
	dc.b	0,82,114,156,183,206,214,0,0,0	; -9.9, -7.0, -4.3, -2.9, -1.9, -1.55 dB
	even
; 7-bit, per class 1-9: where its table starts in HyNoise7T, words. Each holds a whole
; number of periods of the buzz as Paula's top rate carries it (tools/snd_noise7.py)
HyN7Tab:
	dc.w	0,97		; 524.3 kHz: 28 periods, 4128.4 Hz for 4128.3 (+0.1 c), 0 clipped
	dc.w	194,97		; 262.1 kHz: 14 periods, 2064.2 Hz for 2064.1 (+0.1 c), 0 clipped
	dc.w	388,97		; 131.1 kHz: 7 periods, 1032.1 Hz for 1032.1 (+0.1 c), 0 clipped
	dc.w	582,291		; 87.4 kHz: 14 periods, 688.1 Hz for 688.0 (+0.1 c), 8 clipped
	dc.w	1164,194		; 65.5 kHz: 7 periods, 516.1 Hz for 516.0 (+0.1 c), 7 clipped
	dc.w	1552,485		; 52.4 kHz: 14 periods, 412.8 Hz for 412.8 (+0.1 c), 34 clipped
	dc.w	2522,291		; 43.7 kHz: 7 periods, 344.0 Hz for 344.0 (+0.1 c), 30 clipped
	dc.w	3104,97		; 37.4 kHz: 2 periods, 294.9 Hz for 294.9 (+0.1 c), 14 clipped
	dc.w	3298,388		; 32.8 kHz: 7 periods, 258.0 Hz for 258.0 (+0.1 c), 59 clipped
	even
	ENDC

; ---- wave RAM -> HyWave32/16/8 (signed, 4-bit sample s -> 16s-120); d0-d2/a0-a1 used
HySndWave:
	sf	HyWaveDirty
	lea	RRAM+$1f30,a0
	lea	HyWave32,a1
	moveq	#16-1,d2
.l:	move.b	(a0)+,d0
	move.b	d0,d1
	and.b	#$f0,d0
	sub.b	#120,d0
	move.b	d0,(a1)+
	lsl.b	#4,d1
	sub.b	#120,d1
	move.b	d1,(a1)+
	dbra	d2,.l
	lea	HyWave32,a0
	lea	HyWave16,a1
	moveq	#8-1,d2
.h:	move.b	(a0),(a1)+
	move.b	2(a0),(a1)+
	addq.l	#4,a0
	dbra	d2,.h
	lea	HyWave32,a0
	lea	HyWave8,a1
	moveq	#8-1,d2
.e:	move.b	(a0),(a1)+
	addq.l	#4,a0
	dbra	d2,.e
	IFND	NO_SQHIGH
	lea	HyWave32,a0
	lea	HyWave4,a1
	move.b	(a0),(a1)+
	move.b	8(a0),(a1)+
	move.b	16(a0),(a1)+
	move.b	24(a0),(a1)+
	lea	HyWave2,a1
	move.b	(a0),(a1)+
	move.b	16(a0),(a1)+
	ENDC
	rts

; ---- envelope from NRx2 (d0) at a trigger; DAC = upper 5 bits
HySndEnv:
	move.b	d0,d1
	lsr.b	#4,d1
	move.b	d1,C_VOL(a0)
	move.b	d0,d1
	and.b	#7,d1
	move.b	d1,C_ENVP(a0)
	move.b	d1,C_ENVT(a0)
	move.b	d0,d1
	and.b	#8,d1
	move.b	d1,C_ENVUP(a0)
	and.b	#$f8,d0
	sne	C_DAC(a0)
	rts

; ---- trigger channel a0 (d1 = full length): length, on if the DAC is
HySndTrig:
	tst.w	C_LEN(a0)
	bne.w	.l
	move.w	d1,C_LEN(a0)
.l:	tst.b	C_DAC(a0)
	sne	C_ON(a0)
	bsr.w	HySndVol
	bra.w	HySndStatus

; ---- sweep (ch1): next frequency from the shadow -> d0; channel off if over 2047
HySwCalc:
	move.w	HySwShadow,d0
	move.w	d0,d1
	moveq	#7,d2
	and.b	NR10,d2
	lsr.w	d2,d1
	btst	#3,NR10
	beq.w	.add
	sub.w	d1,d0
	bra.w	.chk
.add:	add.w	d1,d0
.chk:	cmp.w	#2047,d0
	bls.w	.x
	move.w	d0,-(sp)
	lea	HyCh1,a0
	bsr.w	HySndOff
	move.w	(sp)+,d0
.x:	rts

; ---- frame sequencer step (every 8192 T-cycles, from snd_high_do)
HySndStep:
	movem.l	HY_SND,-(sp)
	moveq	#0,d3
	move.b	HySndStepN,d3
	addq.b	#1,HySndStepN
	and.b	#7,HySndStepN
	btst	#0,d3
	bne.w	.odd
	lea	HyCh1,a0		; 0, 2, 4, 6: length
	bsr.w	.len
	lea	HyCh2,a0
	bsr.w	.len
	lea	HyCh3,a0
	bsr.w	.len
	lea	HyCh4,a0
	bsr.w	.len
	and.b	#3,d3			; 2, 6: sweep
	cmp.b	#2,d3
	bne.w	.wave
	bsr.w	.sweep
	bra.w	.wave
.odd:	cmp.b	#7,d3			; 7: envelope
	bne.w	.wave
	lea	HyCh1,a0
	bsr.w	.env
	lea	HyCh2,a0
	bsr.w	.env
	lea	HyCh4,a0
	bsr.w	.env
.wave:	tst.b	HyWaveDirty		; wave RAM written: new samples
	beq.w	.x
	bsr.w	HySndWave
.x:	movem.l	(sp)+,HY_SND
	rts

.len:	tst.b	C_LENEN(a0)
	beq.w	.lx
	move.w	C_LEN(a0),d0
	beq.w	.lx
	subq.w	#1,d0
	move.w	d0,C_LEN(a0)
	beq.w	HySndOff
.lx:	rts

.sweep:	subq.b	#1,HySwT
	bgt.w	.sx
	move.b	NR10,d0			; reload the timer (period 0 counts as 8)
	lsr.b	#4,d0
	and.b	#7,d0
	bne.w	.sp
	moveq	#8,d0
.sp:	move.b	d0,HySwT
	tst.b	HySwEn
	beq.w	.sx
	tst.b	HyCh1+C_ON
	beq.w	.sx
	move.b	NR10,d0
	and.b	#$70,d0			; period 0: no update
	beq.w	.sx
	bsr.w	HySwCalc
	cmp.w	#2047,d0
	bhi.w	.sx
	moveq	#7,d1
	and.b	NR10,d1			; shift 0: no write back
	beq.w	.sx
	move.w	d0,HySwShadow
	lea	HyCh1,a0
	move.w	d0,C_FREQ(a0)
	bsr.w	HySndPerSq
	bsr.w	HySwCalc		; overflow check with the new value
.sx:	rts

	IFD	NO_ZOMBIE
.env:	tst.b	C_ENVP(a0)
	beq.w	.ex
	subq.b	#1,C_ENVT(a0)
	bne.w	.ex
	move.b	C_ENVP(a0),C_ENVT(a0)
	move.b	C_VOL(a0),d0
	tst.b	C_ENVUP(a0)
	beq.w	.dn
	cmp.b	#15,d0
	bcc.w	.ex
	addq.b	#1,d0
	bra.w	.set
.dn:	tst.b	d0
	beq.w	.ex
	subq.b	#1,d0
.set:	move.b	d0,C_VOL(a0)
	bra.w	HySndVol
.ex:	rts
	ELSE
; the period and direction can change under a running envelope (HySndZombie): the timer
; runs out with the old period and reloads with the new one; a timer at 0 stays there;
; an envelope that has met its limit stays stopped until the next trigger
.env:	tst.b	C_ENVT(a0)
	beq.w	.ex
	tst.b	C_ENVUP(a0)
	bmi.w	.ex
	subq.b	#1,C_ENVT(a0)
	bne.w	.ex
	move.b	C_ENVP(a0),C_ENVT(a0)
	move.b	C_VOL(a0),d0
	btst	#3,C_ENVUP(a0)
	beq.w	.dn
	cmp.b	#15,d0
	bcc.w	.stop
	addq.b	#1,d0
	bra.w	.set
.dn:	tst.b	d0
	beq.w	.stop
	subq.b	#1,d0
.set:	move.b	d0,C_VOL(a0)
	bra.w	HySndVol
.stop:	bset	#7,C_ENVUP(a0)
.ex:	rts
	ENDC

; ==== register write handlers ($FF10-$FF26, $FF30-$FF3F); stored values read back
; with the DMG's unused bits set

; NR10 sweep
	cnop	0,4
hy_nr10:
	SND_POWERED
	or.b	#$80,d6
	move.b	d6,NR10
	rts

; NRx1 duty, length (ch1, ch2)
	cnop	0,4
hy_nr11:
	SND_POWERED
	movem.l	HY_SND,-(sp)
	lea	HyCh1,a0
	bra.w	hy_sqlen
	cnop	0,4
hy_nr21:
	SND_POWERED
	movem.l	HY_SND,-(sp)
	lea	HyCh2,a0
hy_sqlen:
	move.b	d6,d0
	or.b	#$3f,d0
	move.b	d0,(a2,d7.l)
	moveq	#63,d0
	and.b	d6,d0
	moveq	#64,d1
	sub.w	d0,d1
	move.w	d1,C_LEN(a0)
	moveq	#0,d0
	move.b	d6,d0
	lsr.b	#6,d0
	IFD	HY_SQ8
	lsl.w	#3,d0
	lea	HyDuty,a1
	add.w	d0,a1
	move.l	C_VOICE(a0),a6
	move.l	a1,(a6)			; taken at the end of the loop playing now
	ELSE
	move.l	d0,d2			; the duty in the loop the pitch has now
	moveq	#0,d1
	move.b	C_BIT(a0),d1
	lea	HySqTier,a1
	move.b	(a1,d1.w),d1
	bsr.w	HySqSmp
	ENDC
	movem.l	(sp)+,HY_SND
	rts

; NRx2 envelope (ch1, ch2, ch4): stored; a DAC switched off stops the channel
	cnop	0,4
hy_nr12:
	SND_POWERED
	movem.l	HY_SND,-(sp)
	lea	HyCh1,a0
	bra.w	hy_env
	cnop	0,4
hy_nr22:
	SND_POWERED
	movem.l	HY_SND,-(sp)
	lea	HyCh2,a0
	bra.w	hy_env
	cnop	0,4
hy_nr42:
	SND_POWERED
	movem.l	HY_SND,-(sp)
	lea	HyCh4,a0
hy_env:
	IFND	NO_ZOMBIE
	bsr.w	HySndZombie
	ENDC
	move.b	d6,(a2,d7.l)
	move.b	d6,d0
	and.b	#$f8,d0
	sne	C_DAC(a0)
	IFD	NO_ZOMBIE
	bne.w	.x
	ELSE
	bne.w	.z
	ENDC
	tst.b	C_ON(a0)
	beq.w	.x
	bsr.w	HySndOff
	IFND	NO_ZOMBIE
	bra.w	.x
.z:	tst.b	C_ON(a0)		; playing: the changed volume
	beq.w	.x
	bsr.w	HySndVol
	ENDC
.x:	movem.l	(sp)+,HY_SND
	rts
	IFND	NO_ZOMBIE
; NRx2 written (d6) without a trigger, "zombie mode": the DMG's volume counter moves, and
; the new period and direction count from now. As Mesen 2 has it: +1 if the old period
; was 0 and the envelope hasn't stopped, else +2 if the old direction was down; then
; 16 - volume if the direction changes; 4 bits kept. d0-d2 used
HySndZombie:
	move.b	C_VOL(a0),d0
	move.b	C_ENVUP(a0),d1
	bmi.w	.p
	tst.b	C_ENVP(a0)
	bne.w	.p
	addq.b	#1,d0
	bra.w	.m
.p:	btst	#3,d1
	bne.w	.m
	addq.b	#2,d0
.m:	move.b	d6,d2
	eor.b	d1,d2
	btst	#3,d2
	beq.w	.k
	neg.b	d0
	add.b	#16,d0
.k:	and.b	#15,d0
	move.b	d0,C_VOL(a0)
	and.b	#$80,d1
	moveq	#8,d2
	and.b	d6,d2
	or.b	d2,d1
	move.b	d1,C_ENVUP(a0)
	moveq	#7,d2
	and.b	d6,d2
	move.b	d2,C_ENVP(a0)
	rts
	ENDC

; NRx3 frequency low (ch1, ch2, ch3)
	cnop	0,4
hy_nr13:
	SND_POWERED
	movem.l	HY_SND,-(sp)
	lea	HyCh1,a0
	move.b	d6,C_FREQ+1(a0)
	bsr.w	HySndPerSq
	bra.w	hy_ff
	cnop	0,4
hy_nr23:
	SND_POWERED
	movem.l	HY_SND,-(sp)
	lea	HyCh2,a0
	move.b	d6,C_FREQ+1(a0)
	bsr.w	HySndPerSq
	bra.w	hy_ff
	cnop	0,4
hy_nr33:
	SND_POWERED
	movem.l	HY_SND,-(sp)
	lea	HyCh3,a0
	move.b	d6,C_FREQ+1(a0)
	bsr.w	HySndPerWave
hy_ff:	st	(a2,d7.l)		; write-only: reads $FF
	movem.l	(sp)+,HY_SND
	rts

; NRx4 frequency high, length enable, trigger
	cnop	0,4
hy_nr14:
	SND_POWERED
	movem.l	HY_SND,-(sp)
	lea	HyCh1,a0
	bsr.w	hy_freqhi
	bsr.w	HySndPerSq
	tst.b	d6
	bpl.w	hy_x4
	move.b	RRAM+$1f12,d0		; trigger: envelope, length, sweep
	bsr.w	HySndEnv
	moveq	#64,d1
	bsr.w	HySndTrig
	move.w	C_FREQ(a0),HySwShadow
	move.b	NR10,d0
	lsr.b	#4,d0
	and.b	#7,d0
	bne.w	.p
	moveq	#8,d0
.p:	move.b	d0,HySwT
	move.b	NR10,d0
	and.b	#$77,d0			; period or shift set: sweep on
	sne	HySwEn
	and.b	#7,d0
	beq.w	hy_x4
	bsr.w	HySwCalc		; shift set: overflow check now
	bra.w	hy_x4
	cnop	0,4
hy_nr24:
	SND_POWERED
	movem.l	HY_SND,-(sp)
	lea	HyCh2,a0
	bsr.w	hy_freqhi
	bsr.w	HySndPerSq
	tst.b	d6
	bpl.w	hy_x4
	move.b	RRAM+$1f17,d0
	bsr.w	HySndEnv
	moveq	#64,d1
	bsr.w	HySndTrig
hy_x4:	movem.l	(sp)+,HY_SND
	rts
	cnop	0,4
hy_nr34:
	SND_POWERED
	movem.l	HY_SND,-(sp)
	lea	HyCh3,a0
	bsr.w	hy_freqhi
	bsr.w	HySndPerWave
	tst.b	d6
	bpl.w	hy_x4
	tst.b	HyWaveDirty		; trigger: the latest wave RAM
	beq.w	.w
	bsr.w	HySndWave
	lea	HyCh3,a0		; (HySndWave uses a0)
.w:	move.w	#256,d1
	bsr.w	HySndTrig
	bra.w	hy_x4
; store (bit 6 reads back), frequency bits 8-10, length enable; d6 kept
hy_freqhi:
	move.b	d6,d0
	or.b	#$bf,d0
	move.b	d0,(a2,d7.l)
	moveq	#7,d0
	and.b	d6,d0
	move.b	d0,C_FREQ(a0)
	btst	#6,d6
	sne	C_LENEN(a0)
	rts

; NR30 wave DAC
	cnop	0,4
hy_nr30:
	SND_POWERED
	movem.l	HY_SND,-(sp)
	move.b	d6,d0
	or.b	#$7f,d0
	move.b	d0,(a2,d7.l)
	lea	HyCh3,a0
	tst.b	d6
	smi	C_DAC(a0)
	bmi.w	.x
	tst.b	C_ON(a0)
	beq.w	.x
	bsr.w	HySndOff
.x:	movem.l	(sp)+,HY_SND
	rts

; NR31 wave length
	cnop	0,4
hy_nr31:
	SND_POWERED
	move.w	#256,HyCh3+C_LEN
	move.l	d0,-(sp)
	moveq	#0,d0
	move.b	d6,d0
	sub.w	d0,HyCh3+C_LEN
	move.l	(sp)+,d0
	st	(a2,d7.l)
	rts

; NR32 wave volume: 0 silent, 1 100 %, 2 50 %, 3 25 %
	cnop	0,4
hy_nr32:
	SND_POWERED
	movem.l	HY_SND,-(sp)
	move.b	d6,d0
	or.b	#$9f,d0
	move.b	d0,(a2,d7.l)
	moveq	#0,d0
	move.b	d6,d0
	lsr.b	#5,d0
	and.w	#3,d0
	lea	HyCh3,a0
	move.b	.sh(pc,d0.w),C_SHIFT(a0)
	bsr.w	HySndVol
	movem.l	(sp)+,HY_SND
	rts
.sh:	dc.b	8,0,1,2

; NR41 noise length
	cnop	0,4
hy_nr41:
	SND_POWERED
	move.l	d0,-(sp)
	moveq	#63,d0
	and.b	d6,d0
	neg.w	d0
	add.w	#64,d0
	move.w	d0,HyCh4+C_LEN
	move.l	(sp)+,d0
	st	(a2,d7.l)
	rts

; NR43 noise clock and width
	cnop	0,4
hy_nr43:
	SND_POWERED
	movem.l	HY_SND,-(sp)
	move.b	d6,(a2,d7.l)
	bsr.w	HySndNoise
	movem.l	(sp)+,HY_SND
	rts

; NR44 noise length enable, trigger
	cnop	0,4
hy_nr44:
	SND_POWERED
	movem.l	HY_SND,-(sp)
	move.b	d6,d0
	or.b	#$bf,d0
	move.b	d0,(a2,d7.l)
	lea	HyCh4,a0
	btst	#6,d6
	sne	C_LENEN(a0)
	tst.b	d6
	bpl.w	.x
	move.b	RRAM+$1f21,d0
	bsr.w	HySndEnv
	moveq	#64,d1
	bsr.w	HySndTrig
.x:	movem.l	(sp)+,HY_SND
	rts

; NR50 master volume, NR51 routing
	cnop	0,4
hy_nr50:
	SND_POWERED
	movem.l	HY_SND,-(sp)
	move.b	d6,(a2,d7.l)
	bsr.w	HySndAllVol
	movem.l	(sp)+,HY_SND
	rts

; NR52: bit 7 powers the APU; off clears NR10-NR51 and stops every channel
	cnop	0,4
hy_nr52:
	movem.l	HY_SND,-(sp)
	tst.b	d6
	bmi.w	.on
	btst	#7,NR52
	beq.w	.x
	lea	NR10,a0
	lea	HySndOffRegs(pc),a1
	moveq	#$26-$10-1,d0
.c:	move.b	(a1)+,(a0)+
	dbra	d0,.c
	lea	HyCh1,a0
	moveq	#4-1,d3
.ch:	clr.b	C_ON(a0)
	clr.b	C_DAC(a0)
	clr.b	C_LENEN(a0)
	clr.w	C_FREQ(a0)
	clr.b	C_ENVP(a0)
	lea	C_SIZE(a0),a0
	dbra	d3,.ch
	move.b	#8,HyCh3+C_SHIFT
	lea	HyDuty,a1		; duty 0 again
	move.l	a1,$dff0a0
	move.l	a1,$dff0b0
	IFND	HY_SQ8
	move.w	#4,$dff0a4
	move.w	#4,$dff0b4
	clr.w	HySqTier
	ENDC
	clr.b	HySwEn
	bclr	#7,NR52
	bsr.w	HySndAllVol
	bsr.w	HySndStatus
	bra.w	.x
.on:	btst	#7,NR52
	bne.w	.x
	bset	#7,NR52
	clr.b	HySndStepN		; the frame sequencer starts again at step 0
	bsr.w	HySndStatus
.x:	movem.l	(sp)+,HY_SND
	rts
HySndOffRegs:				; $FF10-$FF25 as read after power off
	dc.b	$80,$3f,$00,$ff,$bf,$ff,$3f,$00,$ff,$bf,$7f,$ff,$9f,$ff,$bf,$ff
	dc.b	$ff,$00,$00,$bf,$00,$00
	even

; wave RAM: stored; the samples are rebuilt at the next step or trigger
	cnop	0,4
hy_wave:
	move.b	d6,(a2,d7.l)
	st	HyWaveDirty
	rts

; write table entries for $FF10-$FF26 (0 = keep Wzonka's)
HySndTab:
	dc.l	hy_nr10,hy_nr11,hy_nr12,hy_nr13,hy_nr14,0
	dc.l	hy_nr21,hy_nr22,hy_nr23,hy_nr24
	dc.l	hy_nr30,hy_nr31,hy_nr32,hy_nr33,hy_nr34,0
	dc.l	hy_nr41,hy_nr42,hy_nr43,hy_nr44
	dc.l	hy_nr50,hy_nr50,hy_nr52

HY_N15LEN	=8192			; bytes of the 15-bit noise sequence used

	SECTION	hysnddata,DATA
	cnop	0,4
HyCh1:		ds.b	C_SIZE
HyCh2:		ds.b	C_SIZE
HyCh3:		ds.b	C_SIZE
HyCh4:		ds.b	C_SIZE
HySwShadow:	dc.w	0		; sweep shadow frequency
HySndSeq:	dc.w	8192		; T-cycles to the next frame sequencer step
HySwT:		dc.b	0		; sweep timer
HySwEn:		dc.b	0		; sweep on
HySndStepN:	dc.b	0		; frame sequencer step 0-7
HyWaveDirty:	dc.b	0		; wave RAM written since the samples were built
HyNoiseW:	dc.b	0		; noise sample on voice 3: 0 = 15-bit, $FF = 7-bit
HySndPend:	dc.b	0		; VBLs to go before voice 3 DMA goes back on
	even
HyNoiseP:	dc.w	400		; voice 3 period
	IFND	HY_SQ8
HySqTier:	dc.b	0,0		; ch1, ch2: loop on the voice, 0 = 8 samples a cycle, 1 = 4, 2 = 2,
					; 3 = constant
	ENDC
	even

	SECTION	hysndchip,DATA_C
HyDuty:		dc.b	-120,-120,-120,-120,-120,-120,-120,120	; 12.5 %
		dc.b	120,-120,-120,-120,-120,-120,-120,120	; 25 %
		dc.b	120,-120,-120,-120,-120,120,120,120	; 50 %
		dc.b	-120,120,120,120,120,120,120,-120	; 75 %
	IFND	HY_SQ8
; high notes. 4 samples can't hold 12.5 %, 2 samples only 50 %: the nearest duty, scaled
; so that the fundamental keeps its level (sin(pi x duty))
HyDuty4:	dc.b	-65,-65,-65,65			; 12.5 % as 25 % x 0.54
		dc.b	-120,-120,-120,120		; 25 %
		dc.b	120,-120,-120,120		; 50 %
		dc.b	-120,120,120,120		; 75 %
HyDuty2:	dc.b	-46,46				; 12.5 % as 50 % x 0.38
		dc.b	-85,85				; 25 % as 50 % x 0.71
		dc.b	-120,120			; 50 %
		dc.b	85,-85				; 75 % as 50 % x 0.71
	IFND	NO_SQDC
; a square too fast to hear: its mean above the low level, duty x 240 (75 %: 180, held
; at 127). The Game Boy's channels rest at their low level, so the volume moves this
HyDutyDC:	dc.b	30,30,60,60,120,120,127,127
	ENDC
		dc.b	0,0,0,0,0,0,0,0			; (a loop changed between the two writes)
	ENDC

	IFND	NO_NOISERATE
HyNoise7T:	incbin	"noise7.bin"	; 7-bit noise for the clocks beyond Paula (HyN7Tab)
	even
	ENDC

	SECTION	hysndchipbss,BSS_C
HyWave32:	ds.b	32
HyWave16:	ds.b	16
HyWave8:	ds.b	8
	IFND	NO_SQHIGH
HyWave4:	ds.b	4
HyWave2:	ds.b	2
	ds.b	2
	ENDC
HyNoise7:	ds.b	2*127
HyNoise15:	ds.b	HY_N15LEN

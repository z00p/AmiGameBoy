; wz112snd.s - Wzonka-Lad 1.12 sound register fixes for the AmiGameBoy hybrid (sound.s).
;
; The register and state logic of Ville Helin's Wzonka-Lad 1.12 audio changes (GPL-2, see
; src/engine/COPYING; his sound_routines.s and wz.s, commits 52805f7 and feaf166), written
; again for sound.s. Only the Game Boy side: what the registers read and when channels go on
; and off. The output stays our Paula back end. Each part has its own WZ112_ switch
; (src/engine/wz112.i); sound.s jumps here from the places the switches name, keeping the
; size of what it replaced. Included last, after wz112.s (its own hunks).
;
; Sound write handlers: d6.b = the byte, d7.l = the address, a2 = Game Boy memory; they keep
; every register but d6 and a6 (glue.s).

		SECTION	wz112snd,CODE

; CGB mode: no DMG quirk (the label in CGB mode)
WZ_DMGONLY	MACRO
		IFD	HY_GBC
		tst.b	gbc_mode
		bne.w	\1
		ENDC
		ENDM

		IFD	WZ112_APUSEQ
; ---- WZ112_APUSEQ: the frame sequencer steps on the falling edges of the divider's DIV-APU
; bit (bit 12, DIV bit 4; bit 13 in double speed), as Wzonka-Lad 1.12's sound_div_sync, so
; lengths, sweep and envelope keep the time of DIV (DIV writes included). wz112.s finds the
; edges when it brings the divider up to date (wz_tsync); sound writes and NR52 reads bring it
; up to their own cycle first.

; sound.s SND_POWERED: the divider up to now, then the APU's power in N.
hy_sndsync:	jsr	wz_tsyncc
		IFD	WZ112_ELOG
		move.l	d0,-(sp)
		move.w	#$300,d0
		move.b	d7,d0
		bsr.w	hy_elog
		move.l	(sp)+,d0
		ENDC
		tst.b	NR52
		rts

; NR52 (in place of movem.l HY_SND,-(sp) / tst.b d6): the same, the divider up to now first.
hy_nr52x:	move.l	(sp)+,a6
		movem.l	HY_SND,-(sp)
		jsr	wz_tsyncc
		tst.b	d6
		jmp	(a6)

; NR52 power on (in place of clr.b HySndStepN): the sequencer from step 0; with the DIV-APU
; bit already 1, the first edge is skipped (Wzonka-Lad 1.12: "skip the first edge if powered
; on with DIV high"). d0 is free.
hy_pwon:	clr.b	HySndStepN
		clr.b	HySndSkip
		move.w	wz_div,d0
		IFD	HY_GBC
		tst.b	gbc_double
		beq.s	.s
		lsr.w	#1,d0
.s:
		ENDC
		btst	#12,d0
		sne	HySndSkip
		rts

; one falling edge of the DIV-APU bit (from wz112.s): a step, unless the APU is off or the
; edge is the one skipped after power-on. Keeps every register (HySndStep saves its own).
HySndEdge:	tst.b	NR52
		bpl.s	.x
		tst.b	HySndSkip
		bne.s	.s
		IFD	WZ112_ELOG
		jsr	HySndStep
		move.l	d0,-(sp)
		move.w	#$100,d0
		move.b	NR52,d0
		bsr.w	hy_elog
		move.l	(sp)+,d0
		rts
		ELSE
		jmp	HySndStep
		ENDC
.s:		clr.b	HySndSkip
.x:		rts
		ENDC					;WZ112_APUSEQ

		IFD	WZ112_APUOFF
; ---- WZ112_APUOFF: NRx1, NR31 and NR41 written while the APU is off. On the DMG the length
; counters take the length (the duty bits are not written; the register reads as after power
; off); on the CGB nothing (Wzonka-Lad 1.12, blargg dmg_sound 08 and 11).
hy_off11:	move.l	a0,-(sp)
		lea	HyCh1,a0
		bra.s	hy_off64
hy_off21:	move.l	a0,-(sp)
		lea	HyCh2,a0
		bra.s	hy_off64
hy_off41:	move.l	a0,-(sp)
		lea	HyCh4,a0
hy_off64:	WZ_DMGONLY .x
		move.l	d0,-(sp)
		moveq	#63,d0
		and.b	d6,d0
		neg.w	d0
		add.w	#64,d0
		move.w	d0,C_LEN(a0)
		move.l	(sp)+,d0
.x:		move.l	(sp)+,a0
		rts
hy_off31:	WZ_DMGONLY .x
		move.l	d0,-(sp)
		moveq	#0,d0
		move.b	d6,d0
		neg.w	d0
		add.w	#256,d0
		move.w	d0,HyCh3+C_LEN
		move.l	(sp)+,d0
.x:		rts
		ENDC					;WZ112_APUOFF

		IFD	WZ112_PWOFF
; ---- NR52 power off (in place of clr.b HySwEn): WZ112_SWEEP: no negate seen; WZ112_APUOFF:
; in CGB mode the length counters are cleared too (the DMG keeps them). d0-d3/a0-a1 free.
hy_pwoff:	clr.b	HySwEn
		IFD	WZ112_SWEEP
		clr.b	HySwNeg
		ENDC
		IFD	WZ112_APUOFF
		IFD	HY_GBC
		tst.b	gbc_mode
		beq.s	.x
		clr.w	HyCh1+C_LEN
		clr.w	HyCh2+C_LEN
		clr.w	HyCh3+C_LEN
		clr.w	HyCh4+C_LEN
.x:
		ENDC
		ENDC
		rts
		ENDC

		IFD	WZ112_APULEN
; ---- WZ112_APULEN: NRx4 written (a0 = the channel; hy_lenx44: channel 4), before it is
; stored. Wzonka-Lad 1.12 (sound_length_write): when the next frame sequencer step does not
; clock length (an odd step next, or the skipped first edge after power-on), enabling the
; length counter (bit 6, 0 -> 1) clocks it once: down to 0 without a trigger, the channel
; goes off. A trigger with the counter at 0 loads the full length, one less when the length
; is enabled in that same half. Ends as the two instructions it replaces (d0 = the byte
; with $BF). d1-d3/a1 are free (the handlers saved them).
hy_lenx44:	lea	HyCh4,a0
hy_lenx:	moveq	#64,d1
		cmp.b	#2,C_BIT(a0)
		bne.s	.m
		move.w	#256,d1
.m:		btst	#0,HySndStepN			;d2: the next step clocks no length
		sne	d2
		IFD	WZ112_APUSEQ
		or.b	HySndSkip,d2
		ENDC
		tst.b	d2
		beq.s	.rl
		btst	#6,d6
		beq.s	.rl
		tst.b	C_LENEN(a0)
		bne.s	.rl
		tst.w	C_LEN(a0)
		beq.s	.rl
		subq.w	#1,C_LEN(a0)
		bne.s	.rl
		tst.b	d6
		bmi.s	.rl
		movem.l	d1-d2,-(sp)
		jsr	HySndOff			;(d0-d2/a1)
		movem.l	(sp)+,d1-d2
		bra.s	.x
.rl:		tst.b	d6				;trigger with the counter at 0
		bpl.s	.x
		tst.w	C_LEN(a0)
		bne.s	.x
		move.w	d1,C_LEN(a0)
		tst.b	d2
		beq.s	.x
		btst	#6,d6
		beq.s	.x
		subq.w	#1,C_LEN(a0)
.x:		move.b	d6,d0
		or.b	#$bf,d0
		rts
		ENDC					;WZ112_APULEN

		IFD	WZ112_SWEEP
; ---- WZ112_SWEEP: a sweep calculation in negate mode since the last trigger, then NR10's
; negate bit cleared: channel 1 goes off (Wzonka-Lad 1.12 sound_sweep_negated; blargg
; dmg_sound 05).
; HySwCalc (in place of btst #3,NR10 / beq.w .add): Z clear = negate, noted.
hy_swdir:	btst	#3,NR10
		beq.s	.x
		st	HySwNeg				;(st keeps the flags)
.x:		rts

; NR10 (in place of or.b #$80,d6 / move.b d6,NR10; returns to the rts there)
hy_nr10x:	or.b	#$80,d6
		move.b	d6,NR10
		btst	#3,d6
		bne.s	.x
		tst.b	HySwNeg
		beq.s	.x
		clr.b	HySwNeg
		movem.l	HY_SND,-(sp)
		lea	HyCh1,a0
		jsr	HySndOff
		movem.l	(sp)+,HY_SND
.x:		rts

; NR14 trigger (in place of move.w C_FREQ(a0),HySwShadow): no negate seen yet
hy_swtrig:	move.w	C_FREQ(a0),HySwShadow
		clr.b	HySwNeg
		rts
		ENDC					;WZ112_SWEEP

		IFD	WZ112_WAVE
; ---- WZ112_WAVE: DMG wave RAM while channel 3 plays (Wzonka-Lad 1.12: sound_wave_project,
; _access, _corrupt; blargg dmg_sound 09, 10, 12). Channel 3 fetches a sample every
; (2048 - f) x 2 T-cycles; HyWvNext is the T-cycle of the fetch of sample HyWvIdx, the later
; ones are worked out when asked for (nothing is clocked per sample). Times are wz_now x 4
; (T-cycles, 32 bits, differences signed). While it plays, the CPU reaches wave RAM only in
; the cycle of a fetch, and then the byte being fetched (reads elsewhere $FF, writes lost);
; a trigger 2 T-cycles before a fetch copies the bytes being fetched to the start. CGB mode:
; as before (wave RAM plain), as is everything with the channel off. Paula plays the wave
; RAM as written (HyWaveDirty).

; d0.l = now (T-cycles); uses d6
hy_wvnow:	move.l	d6,-(sp)
		jsr	wz_now
		move.l	d6,d0
		move.l	(sp)+,d6
		lsl.l	#2,d0
		rts

; d0.l = a time (T) -> d0.l = the sample fetched last (0-31), d1.l = T-cycles since then
; (negative: before the first one, the next is HyWvIdx), d2.l = the period
hy_wvproj:	move.w	#2048,d2
		sub.w	HyCh3+C_FREQ,d2
		add.w	d2,d2
		and.l	#$ffff,d2
		sub.l	HyWvNext,d0
		move.l	d0,d1
		moveq	#0,d0
		tst.l	d1
		bmi.s	.i
		cmp.l	d2,d1
		bcs.s	.i
		move.l	d1,d0
		divul.l	d2,d1:d0
.i:		add.b	HyWvIdx,d0
		and.l	#31,d0
		rts

; before a new period (NR33, NR34 without a trigger): the countdown already loaded runs out
; with the old one. Uses d0-d2.
hy_wvre:	tst.b	HyCh3+C_ON
		beq.s	.x
		WZ_DMGONLY .x
		bsr.w	hy_wvnow
		move.l	d0,-(sp)
		bsr.w	hy_wvproj
		tst.l	d1
		bmi.s	.p
		addq.b	#1,d0
		and.b	#31,d0
		move.b	d0,HyWvIdx
		sub.l	d1,d2
		add.l	(sp),d2
		move.l	d2,HyWvNext
.p:		addq.l	#4,sp
.x:		rts

; NR33 (in place of lea HyCh3,a0)
hy_w33:		bsr.w	hy_wvre
		lea	HyCh3,a0
		rts

; NR34 (in place of lea HyCh3,a0): a trigger while playing may corrupt, else as NR33
hy_w34:		tst.b	d6
		bmi.s	.t
		bsr.w	hy_wvre
		bra.s	.x
.t:		bsr.w	hy_wvcor
.x:		lea	HyCh3,a0
		rts

; NR34 trigger (in place of move.w #256,d1 / bsr.w HySndTrig): sample 1 is fetched first,
; a period and 6 T-cycles on (Wzonka-Lad 1.12 sound_wave_start)
hy_w34t:	bsr.w	hy_wvnow
		move.w	#2048,d1
		sub.w	HyCh3+C_FREQ,d1
		add.w	d1,d1
		and.l	#$ffff,d1
		add.l	d1,d0
		addq.l	#6,d0
		move.l	d0,HyWvNext
		move.b	#1,HyWvIdx
		move.w	#256,d1
		jmp	HySndTrig

; a trigger while playing, 2 T-cycles before a fetch: the byte being fetched goes to byte 0
; (bytes 0-3), or its block of four to bytes 0-3. Uses d0-d2/a1.
hy_wvcor:	tst.b	HyCh3+C_ON
		beq.s	.x
		WZ_DMGONLY .x
		bsr.w	hy_wvnow
		bsr.w	hy_wvproj
		tst.l	d1
		bmi.s	.d
		sub.l	d2,d1				;to the next fetch
		addq.b	#1,d0
.d:		cmp.l	#-2,d1
		bne.s	.x
		and.w	#31,d0
		lsr.w	#1,d0
		lea	RRAM+$1f30,a1
		cmp.w	#4,d0
		bcc.s	.b
		move.b	(a1,d0.w),(a1)
		bra.s	.w
.b:		and.w	#$c,d0
		move.l	(a1,d0.w),(a1)
.w:		st	HyWaveDirty
.x:		rts

; wave RAM write (hy_wave, in place of its store; returns to the rts there)
hy_wavew:	tst.b	HyCh3+C_ON
		beq.s	.w
		WZ_DMGONLY .w
		movem.l	d0-d2,-(sp)
		bsr.w	hy_wvnow
		bsr.w	hy_wvproj
		tst.l	d1
		bne.s	.n				;not in a fetch: lost
		lsr.b	#1,d0
		move.l	d7,d1
		move.b	d0,d1
		or.b	#$30,d1
		move.b	d6,(a2,d1.l)
		st	HyWaveDirty
.n:		movem.l	(sp)+,d0-d2
		rts
.w:		move.b	d6,(a2,d7.l)
		st	HyWaveDirty
		rts

; wave RAM read (wz112.s wz_tread: LDH A,(n), LD A,(C)): d7.l = the address. Out: d3.b.
hy_waver:	tst.b	HyCh3+C_ON
		beq.s	.r
		WZ_DMGONLY .r
		movem.l	d0-d2,-(sp)
		bsr.w	hy_wvnow
		bsr.w	hy_wvproj
		st	d3
		tst.l	d1
		bne.s	.n				;not in a fetch: $FF
		lsr.b	#1,d0
		move.l	d7,d1
		move.b	d0,d1
		or.b	#$30,d1
		move.b	(a2,d1.l),d3
.n:		movem.l	(sp)+,d0-d2
		rts
.r:		move.b	(a2,d7.l),d3
		rts

; HySndStep (in place of tst.b HyWaveDirty): the anchor moved up to the last fetch, so the
; 32-bit times never drift apart (Wzonka-Lad 1.12 sound_wave_rebase_time). d0-d3 free.
hy_stepw:	tst.b	HyCh3+C_ON
		beq.s	.x
		WZ_DMGONLY .x
		move.l	wz_tlast,d0
		lsl.l	#2,d0
		move.l	d0,d3
		bsr.w	hy_wvproj
		tst.l	d1
		bmi.s	.x
		move.b	d0,HyWvIdx
		sub.l	d1,d3
		move.l	d3,HyWvNext
.x:		tst.b	HyWaveDirty
		rts
		ENDC					;WZ112_WAVE

		IFD	WZ112_ELOG
; ---- test (WZ112_ELOG): a ring of 8-byte events, appended to HY_PCLOG's GB:AmiGB.pcl:
; wz_tlast (M-cycles), tag, byte, the next step, 0. Tags: 1 DIV-APU edge (byte = NR52 after
; it), 2 NR52 timed read (the value), 3 sound write (address low byte).
; d0.w = tag x 256 + byte. Keeps every register.
hy_elog:	movem.l	d0/a6,-(sp)
		lea	hy_elogbuf,a6
		move.l	hy_elogn,d0
		addq.l	#1,hy_elogn
		and.l	#4095,d0
		lsl.l	#3,d0
		add.l	d0,a6
		move.l	wz_tlast,(a6)+
		move.w	2(sp),(a6)+
		move.b	HySndStepN,(a6)+
		clr.b	(a6)
		movem.l	(sp)+,d0/a6
		rts
		SECTION	wz112elog,BSS
hy_elogn:	ds.l	1
hy_elogbuf:	ds.b	4096*8
		ENDC

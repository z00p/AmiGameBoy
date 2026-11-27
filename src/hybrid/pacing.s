; AmiGameBoy: picture pacing options and the sync log (27 Nov 2026; docs/scroll-log.md).
; Copyright (C) 2026 AmiGameBoy contributors. GPL-2 (see src/engine/COPYING).
;
; HY_PACEOPT (2.6, all three programs): the Pacing choice. It is Juan's Screen setting (the menu's
; "Screen" cycle, DirPrefs+$0F, which already ran the game in NTSC or PAL timing) with a third entry,
; so there is one control, not two that fight:
;   1 60 Hz   NTSC timing (BEAMCON0 0, Juan's PowerON) while the game runs: full speed, every
;             picture shown (about 59.5 Hz on a PAL Amiga's crystal, the game 0.4 % slow). The
;             default. Back to PAL timing for the menu at Esc (the menu's screen is PAL hires).
;             RTG: the chipset is only the pacing clock (pictures paced at ~60 Hz for a 60 Hz RTG
;             display; the RTG display's own refresh is the board's, see docs/pacing-26.md).
;   0 50 Hz   PAL timing: for screens that cannot take 60 Hz (a PAL CRT). Full speed, so one
;             picture in about five is skipped (motion steps 1, 1, 1, 1, 2 frames).
;   2 Smooth  PAL timing and one Game Boy frame per screen frame: even motion, the game (music
;             too) at 50/59.73 = 84 % speed.
; Kept as "Pacing = 60 Hz | 50 Hz | Smooth" in PROGDIR:AmiGameBoy.config ("Normal", the 27 Nov test
; word, reads as 50 Hz), written at once when the cycle changes (rmenu.s gbc_rmsave), as the Joy
; type is. At start that line (or 60 Hz when there is none) wins over the Screen byte in Juan's
; S:AmiGameBoy.prefs; Save Prefs still stores 0/1/2 there (an older AmiGameBoy reads 2 as NTSC).
; Hooks: Juan's PowerON (BEAMCON0 NTSC only for 1), his gadget table (hy_pgad), the label list in
; GadToolsBox/AmiGameBoy.s, HyPadCfg (hy_pacecfg, hy_pacesync), HyMenuPace/HyMenuLeave.
; HY_SYNCLOG = n (test): a ring of n events (beam time = VBL count * 512 + beam line, type,
;   info) written to PROGDIR:SyncLog<k>.bin at every Esc / AutoExit (k = 1, 2, ...);
;   tools/hy_synclog.py reads it. Events: 1 frame end (LY 144), 2 draw start, 3 draw end,
;   4 picture skipped, 6 play (re)started.

; (the SYNCEV macro is in hybrid.asm, before its first use)

	SECTION	pacecode,CODE

	IFD	HY_PACEOPT
HY_P50		=0			; DirPrefs+$0F: Juan's PAL
HY_P60		=1			; Juan's NTSC
HY_PSMOOTH	=2
; ---- play starts (HyMenuPace: Power On or Continue; Juan's ContinueCon has set BEAMCON0 and
; HyMenuPrefs the PAL or NTSC rate from DirPrefs+$0F): Smooth one Game Boy frame of time per VBL;
; 60 Hz noted for Esc. Keeps every register.
hy_paceon:
	sf	hy_60on
	cmp.b	#HY_PSMOOTH,DirPrefs+$0f
	bne.s	.n60
	move.l	#$10000,HyVblRate	; Smooth: one Game Boy frame of time per VBL
	bra.s	.x
.n60:	cmp.b	#HY_P60,DirPrefs+$0f
	bne.s	.x
	st	hy_60on			; (Juan's PowerON has set NTSC timing)
.x:
	IFD	HY_SYNCLOG
	SYNCEV	6,#0
	ENDC
	rts
; ---- back to the menu (HyMenuLeave, before DescongelaAMIGA): PAL timing again after 60 Hz, as
; the menu's screen is PAL. Keeps every register.
hy_paceoff:
	tst.b	hy_60on
	beq.s	.x
	sf	hy_60on
	move.w	#$0020,$dff1dc		; BEAMCON0: PAL
.x:	rts

; ---- after AmiGameBoy.config was read (HyPadCfg, the menu's window open, OS alive): the Pacing
; line (or 60 Hz) into Juan's Screen byte and his Screen cycle. Set with no window, then drawn
; (bigmenu.s bm_lsync: GT_SetGadgetAttrs on the open window hung Intuition in WinUAE). Keeps
; every register.
hy_pacesync:
	movem.l	d0-d2/a0-a3/a6,-(sp)
	moveq	#0,d2
	move.b	hy_pcfg,d2
	move.b	d2,DirPrefs+$0f
	move.l	d2,hy_pctags+4
	lea	MainMenuPunts,a0	; Juan's value table and his gadget's tags (as PonPrefs)
	lea	MainMenuGTags,a1
	move.w	#GD_ScrMode,d0
	move.l	#$8008000F,d1		; GTCY_Active
	jsr	OverrideTag
	tst.l	MainMenuWnd
	beq.s	.x
	move.l	MainMenuGadgets+4*GD_ScrMode,a0
	move.l	a0,-(sp)
	sub.l	a1,a1
	sub.l	a2,a2
	lea	hy_pctags,a3
	move.l	_GadToolsBase,a6
	jsr	-42(a6)			; GT_SetGadgetAttrsA
	move.l	(sp)+,a0
	move.l	MainMenuWnd,a1
	sub.l	a2,a2
	moveq	#1,d0
	move.l	_IntuitionBase,a6
	jsr	-432(a6)		; RefreshGList
.x:	movem.l	(sp)+,d0-d2/a0-a3/a6
	rts

; ---- the Screen cycle (Juan's gadget table; his Control has stored the value): d2.w = the entry.
; The line "Pacing = ..." written at once (rmenu.s gbc_rmsave, codes 12-14). Keeps every register.
hy_pgad:
	movem.l	d0-d7/a0-a6,-(sp)
	cmp.w	#3,d2
	bcc.s	.x
	move.b	d2,hy_pcfg
	move.b	d2,DirPrefs+$0f		; (his ActuPrefs takes it again at Power On)
	moveq	#12,d7
	add.b	d2,d7
	lea	hy_kpacew,a3
	jsr	gbc_rmsave
.x:	movem.l	(sp)+,d0-d7/a0-a6
	rts

; ---- "Pacing = 60 Hz | 50 Hz | Smooth" (or Normal = 50 Hz) in the config text (padcfg.s calls
; this on what it read): a0 = text, a1 = its end. Any case, blanks around the "=", "60 Hz" or
; "60Hz"; a line that does not parse changes nothing. Keeps every register.
hy_pacecfg:
	movem.l	d0-d2/a0/a2-a5,-(sp)
.line:	bsr.w	.blank
	move.l	a0,a3			; the line, after its blanks
	lea	hy_kpace,a2
	bsr.w	.word
	beq.s	.skip
	bsr.w	.blank
	cmp.l	a1,a0
	bcc.s	.skip
	cmp.b	#"=",(a0)+
	bne.s	.skip
	bsr.w	.blank
	move.l	a0,a4
	lea	hy_kvals,a5		; word, value; 0 ends
.v:	move.l	(a5)+,d2
	beq.s	.skip
	move.l	d2,a2
	move.l	a4,a0
	bsr.w	.word
	bne.s	.got
	addq.l	#2,a5
	bra.s	.v
.got:	move.b	1(a5),hy_pcfg
.skip:	move.l	a3,a0			; to the next line
.sk:	cmp.l	a1,a0
	bcc.s	.x
	cmp.b	#10,(a0)+
	bne.s	.sk
	bra.s	.line
.x:	movem.l	(sp)+,d0-d2/a0/a2-a5
	rts
; a0 over spaces, tabs and CRs
.blank:	cmp.l	a1,a0
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
; the upper-case word at a2 (ends with 0) at a0, any case, a whole word: NE and a0 behind it, or
; EQ ("60 HZ": the blank inside is matched as one blank)
.word:	move.b	(a2)+,d1
	beq.s	.wend
	cmp.l	a1,a0
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

	IFD	HY_SYNCLOG
; ---- an event: d0.b = type, 4(sp) the info word (SYNCEV). d0/a0 free (the macro keeps them).
hy_slev:
	movem.l	d1-d2,-(sp)
.t:	move.l	HyVblN,d1		; the time: VBLs * 512 + the beam line, read as one
	move.l	$dff004,d2
	cmp.l	HyVblN,d1
	bne.s	.t
	lsr.l	#8,d2
	and.l	#$1ff,d2
	lsl.l	#8,d1
	add.l	d1,d1
	or.l	d2,d1
	move.l	hy_sln,d2
	addq.l	#1,hy_sln
	and.l	#HY_SYNCLOG-1,d2
	lsl.l	#3,d2
	lea	hy_slbuf,a0
	add.l	d2,a0
	move.l	d1,(a0)+
	and.w	#$ff,d0
	move.w	d0,(a0)+
	move.w	12(sp),(a0)		; (d1-d2, the return, then the info)
	movem.l	(sp)+,d1-d2
	rts

; ---- at Esc / AutoExit (OS alive, HyMenuLeave): PROGDIR:SyncLog<k>.bin, the header then the
; ring oldest first; the ring starts again. Keeps every register.
hy_slsave:
	movem.l	d0-d7/a0-a6,-(sp)
	move.b	hy_slk,d0
	addq.b	#1,d0
	cmp.b	#"9"+1,d0
	bcs.s	.k
	move.b	#"1",d0
.k:	move.b	d0,hy_slk
	move.b	d0,hy_slname+15
	lea	hy_slhead,a0
	move.l	#HY_SYNCLOG,8(a0)
	move.l	hy_sln,12(a0)
	move.l	HyFrames,16(a0)
	move.l	HySkipped,20(a0)
	move.l	HyVblRate,24(a0)
	clr.l	28(a0)
	IFD	GBC_AGA
	move.b	gbc_aga_onf,28(a0)	; the colour display (double buffer: a flip at the next VBL)
	ENDC
	IFD	GBC_RTG
	move.b	#2,28(a0)		; RTG
	ENDC
	move.b	DirPrefs+$0f,29(a0)	; the menu's screen mode (0 PAL)
	IFD	HY_PACEOPT
	move.b	DirPrefs+$0f,30(a0)
	move.b	hy_60on,31(a0)
	ENDC
	move.l	HyDosBase,a6
	move.l	#hy_slname,d1
	move.l	#1006,d2		; MODE_NEWFILE
	jsr	-30(a6)
	move.l	d0,d7
	beq.s	.x
	move.l	d7,d1
	move.l	#hy_slhead,d2
	moveq	#32,d3
	jsr	-48(a6)
	move.l	hy_sln,d4		; events kept
	moveq	#0,d5			; the first
	cmp.l	#HY_SYNCLOG,d4
	bls.s	.n
	move.l	d4,d5
	and.l	#HY_SYNCLOG-1,d5
	move.l	#HY_SYNCLOG,d4
.n:	move.l	#HY_SYNCLOG,d6		; the part from d5 to the ring's end, then its start
	sub.l	d5,d6
	cmp.l	d4,d6
	bls.s	.a
	move.l	d4,d6
.a:	move.l	d7,d1
	move.l	d5,d2
	lsl.l	#3,d2
	add.l	#hy_slbuf,d2
	move.l	d6,d3
	lsl.l	#3,d3
	jsr	-48(a6)
	sub.l	d6,d4
	beq.s	.c
	move.l	d7,d1
	move.l	#hy_slbuf,d2
	move.l	d4,d3
	lsl.l	#3,d3
	jsr	-48(a6)
.c:	move.l	d7,d1
	jsr	-36(a6)
.x:	clr.l	hy_sln
	movem.l	(sp)+,d0-d7/a0-a6
	rts
	ENDC

	SECTION	pacedata,DATA
	IFD	HY_PACEOPT
hy_pctags:	dc.l	$8008000F,0,0	; GTCY_Active (hy_pacesync)
hy_kvals:	dc.l	hy_k60		; config words, upper case, and their DirPrefs+$0F
		dc.b	0,HY_P60
		dc.l	hy_k60b
		dc.b	0,HY_P60
		dc.l	hy_k50
		dc.b	0,HY_P50
		dc.l	hy_k50b
		dc.b	0,HY_P50
		dc.l	hy_ksmooth
		dc.b	0,HY_PSMOOTH
		dc.l	hy_knorm
		dc.b	0,HY_P50
		dc.l	0
hy_pvals:	dc.l	hy_v50,hy_v60,hy_vsmooth	; gbc_rmsave's words, by DirPrefs+$0F
hy_pcfg:	dc.b	HY_P60		; the config's choice; no line: 60 Hz
hy_60on:	dc.b	0		; NTSC timing set for play (hy_paceon)
hy_kpace:	dc.b	"PACING",0
hy_k60:		dc.b	"60 HZ",0
hy_k60b:	dc.b	"60HZ",0
hy_k50:		dc.b	"50 HZ",0
hy_k50b:	dc.b	"50HZ",0
hy_ksmooth:	dc.b	"SMOOTH",0
hy_knorm:	dc.b	"NORMAL",0
hy_kpacew:	dc.b	"Pacing",0	; gbc_rmsave: the line's word and values
hy_v60:		dc.b	" 60 Hz",0
hy_v50:		dc.b	" 50 Hz",0
hy_vsmooth:	dc.b	" Smooth",0
hy_pacecmt:	dc.b	"; Pacing: 60 Hz (a screen that takes 60 Hz), 50 Hz (a PAL-only CRT) or",10
		dc.b	"; Smooth (50 Hz, every picture, the game at 84 % speed). The menu's Screen.",10,0
	even
	ENDC
	IFD	HY_SYNCLOG
hy_slk:		dc.b	"0"
hy_slname:	dc.b	"PROGDIR:SyncLog1.bin",0
	even
hy_slhead:	dc.b	"AGBS"
	IFD	HY_PACEOPT
	dc.l	2			; version 2: pacing byte = the Screen setting (0 50 Hz, 1 60 Hz, 2 Smooth)
	ELSE
	dc.l	1			; version; then ring, events, frames, skipped, rate, kind
	ENDC
	ds.l	6
	SECTION	pacebss,BSS
hy_sln:		ds.l	1
hy_slbuf:	ds.b	8*HY_SYNCLOG
	ENDC

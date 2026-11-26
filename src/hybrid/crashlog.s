; AmiGameBoy hybrid: crash catcher (HY_CRASHLOG, test build "RTG Fix Crash Log", 26 Nov 2026).
; Copyright (C) 2026 AmiGameBoy contributors. GPL-2 (see src/engine/COPYING).
;
; An A1200 stopped with "Program failed (error #80000004)" on the Insert after a cart switch.
; This build catches any CPU exception of our task (tc_TrapCode), writes PROGDIR:crash.log and
; asks Reboot / Suspend:
;   the exception, PC, SR, the frame word, D0-D7/A0-A7 (A7 = the user stack), 16 bytes at the PC
;   when it is in the program, 24 longs of the stack (those that point into the program again as
;   "ret"), every hunk's start and size (tools/hunkmap.py --resolve maps PC and ret to hunk,
;   offset and symbol), a few settings, and the last CR_RING steps (HYSTEP in menu.s, Juan's
;   Insert / Power On / Eject, gbc_rtg_open, sgb.s): what was done, with a value (address or
;   flags), and the VBL count when it was done.
; The trap code runs in supervisor mode: it keeps the registers and the frame, drops the frame
; and returns into cr_user (user mode, a stack of its own), which gives the hardware back to the
; OS if the engine had it (DescongelaAMIGA), closes the game screen, writes the file (Close
; flushes it) and shows the requester. A second exception while that runs goes to the old trap
; code (the usual Software Failure).

CR_RING		=64			; steps kept (a power of 2)
CR_STK		=4096			; cr_user's own stack
CR_HUNKS	=96			; hunks listed at most

	SECTION	crcode,CODE

; ---- at start (menu.s, DOS open): our trap code, the hunk list. Keeps every register.
cr_install:
	movem.l	d0-d1/a0-a1/a6,-(sp)
	move.l	4.w,a6
	sub.l	a1,a1
	jsr	-294(a6)		; FindTask
	move.l	d0,a0
	move.l	d0,cr_task
	move.l	$32(a0),cr_oldtrap	; tc_TrapCode
	move.l	#cr_trap,$32(a0)
	lea	Start-4,a0		; hunk 0 (Start is its first byte): the segment list
	lea	cr_hunks,a1
	moveq	#0,d1
.h:	move.l	a0,d0
	beq.s	.hx
	cmp.w	#CR_HUNKS,d1
	bcc.s	.hx
	lea	4(a0),a6
	move.l	a6,(a1)+		; the hunk's first byte
	move.l	-4(a0),d0		; its allocation (size + 8)
	subq.l	#8,d0
	move.l	d0,(a1)+
	addq.w	#1,d1
	move.l	(a0),d0			; BPTR to the next
	lsl.l	#2,d0
	move.l	d0,a0
	bra.s	.h
.hx:	move.w	d1,cr_nhunks
	movem.l	(sp)+,d0-d1/a0-a1/a6
	HYSTEP	1,Start
	rts

; ---- at the end (menu.s): the old trap code back. Keeps every register.
cr_remove:
	movem.l	d0/a0,-(sp)
	move.l	cr_task,d0
	beq.s	.x
	move.l	d0,a0
	move.l	cr_oldtrap,$32(a0)
	clr.l	cr_task
.x:	movem.l	(sp)+,d0/a0
	rts

; ---- HYSTEP: 4(sp) = the step (word), 6(sp) = its value (long). Keeps every register (the
; macro keeps the flags).
cr_step:
	movem.l	d0/a0,-(sp)
	move.l	cr_n,d0
	addq.l	#1,cr_n
	and.w	#CR_RING-1,d0
	lsl.w	#3,d0
	lea	cr_ring,a0
	add.w	d0,a0
	move.w	8+4(sp),(a0)+
	move.w	HyVblN+2,(a0)+
	move.l	8+6(sp),(a0)
	movem.l	(sp)+,d0/a0
	rts

; ---- Juan's MiraTipoCart, before BuscaExt: a0 = the file name (ASL's fr_File). Its length:
; BuscaExt copies the name's end into MiTiNom (8 + 64 bytes). Keeps every register.
cr_name:
	movem.l	d0/a0,-(sp)
	moveq	#0,d0
.l:	tst.b	(a0)+
	beq.s	.x
	addq.l	#1,d0
	bra.s	.l
.x:	HYSTEP	7,d0
	movem.l	(sp)+,d0/a0
	rts

; ---- Juan's Insert after the header is read: a0 = DirCart. $143, $146, $147, $14B. Keeps every
; register.
cr_hdr:
	movem.l	d0,-(sp)
	move.b	$80+$143(a0),d0
	lsl.l	#8,d0
	move.b	$80+$146(a0),d0
	lsl.l	#8,d0
	move.b	$80+$147(a0),d0
	lsl.l	#8,d0
	move.b	$80+$14b(a0),d0
	HYSTEP	8,d0
	movem.l	(sp)+,d0
	rts

; ---- in place of the engine's jsr CongelaAMIGA (menu.s): Continue (24) and Power On (18)
cr_cong24:
	HYSTEP	24,HyEngSP
	bra.s	cr_cong
cr_cong18:
	HYSTEP	18,HyFlat
cr_cong:
	st	cr_frozen		; the engine has the hardware from here
	jmp	CongelaAMIGA

; ---- the trap code (supervisor): (sp) = the exception number, then the CPU's frame.
cr_trap:
	bset	#7,cr_busy		; the second time (in cr_user): the old trap code
	beq.s	.first
	move.l	cr_oldtrap,-(sp)
	rts
.first:	movem.l	d0-d7/a0-a6,cr_regs
	move.l	(sp)+,cr_num
	move.l	usp,a0
	move.l	a0,cr_regs+60
	move.l	sp,a0			; the frame's first 32 bytes
	lea	cr_frame,a1
	moveq	#8-1,d0
.f:	move.l	(a0)+,(a1)+
	dbra	d0,.f
	move.w	(sp),cr_sr
	move.l	2(sp),cr_pc
	move.w	6(sp),d0		; format / vector offset
	move.w	d0,cr_fv
	lsr.w	#8,d0
	lsr.w	#4,d0
	moveq	#0,d1
	move.b	.fsz(pc,d0.w),d1
	add.l	d1,sp			; the frame gone: a format 0 frame into cr_user
	clr.w	-(sp)			; format 0
	pea	cr_user
	clr.w	-(sp)			; SR: user mode, IPL 0
	rte
.fsz:	dc.b	8,8,12,12,16,8,8,60,58,20,32,92,24,8,8,8	; frame sizes by format

; ---- user mode, our own stack: the OS back, the log, the requester.
cr_user:
	lea	cr_stack+CR_STK,sp
	tst.b	cr_frozen		; the engine had the hardware
	beq.s	.os
	sf	cr_frozen
	IFND	NO_SOUND
	jsr	HySndStop
	ENDC
	jsr	DescongelaAMIGA
.os:
	IFD	GBC_RTG
	jsr	gbc_rtg_close		; the game screen (if open)
	ENDC
	bsr.w	cr_text
	bsr.w	cr_write
	bsr.w	cr_req
	tst.l	d0
	beq.s	.susp
	move.l	4.w,a6
	jsr	-726(a6)		; ColdReboot
.susp:	moveq	#0,d0
	move.l	4.w,a6
	jsr	-318(a6)		; Wait(0): suspended
	bra.s	.susp

; ---- the log text into cr_txt; cr_tlen its length
cr_text:
	lea	cr_txt,a0
	lea	.t0(pc),a1
	bsr.w	cr_s
	move.l	cr_num,d0
	or.l	#$80000000,d0
	bsr.w	cr_h8
	lea	.t1(pc),a1
	bsr.w	cr_s
	move.l	cr_num,d0
	cmp.l	#11,d0
	bhi.s	.nn
	lea	.names(pc),a1
	move.l	(a1,d0.w*4),a1
	bra.s	.nm
.nn:	lea	.tunk(pc),a1
.nm:	bsr.w	cr_s
	bsr.w	cr_nl
	lea	.tpc(pc),a1		; PC $........  SR $....  frame $....
	bsr.w	cr_s
	move.l	cr_pc,d0
	bsr.w	cr_h8
	lea	.tsr(pc),a1
	bsr.w	cr_s
	move.w	cr_sr,d0
	bsr.w	cr_h4
	lea	.tfv(pc),a1
	bsr.w	cr_s
	move.w	cr_fv,d0
	bsr.w	cr_h4
	bsr.w	cr_nl
	lea	cr_regs,a2		; D0 $........ ... A7 $........
	moveq	#0,d2
.r:	move.b	#"D",d0
	cmp.w	#8,d2
	bcs.s	.r1
	move.b	#"A",d0
.r1:	move.b	d0,(a0)+
	moveq	#7,d0
	and.w	d2,d0
	add.b	#"0",d0
	move.b	d0,(a0)+
	move.b	#" ",(a0)+
	move.b	#"$",(a0)+
	move.l	(a2)+,d0
	bsr.w	cr_h8
	bsr.w	cr_nl
	addq.w	#1,d2
	cmp.w	#16,d2
	bne.s	.r
	move.l	cr_pc,d0		; 16 bytes at the PC, when it is in the program
	moveq	#16,d1
	bsr.w	cr_inprog
	beq.s	.nopc
	lea	.tbytes(pc),a1
	bsr.w	cr_s
	move.l	cr_pc,a2
	moveq	#8-1,d2
.pb:	move.b	#" ",(a0)+
	move.w	(a2)+,d0
	bsr.w	cr_h4
	dbra	d2,.pb
	bsr.w	cr_nl
.nopc:	move.l	cr_regs+60,d0		; the stack: 24 longs
	btst	#0,d0
	bne.w	.nost
	tst.l	d0
	beq.w	.nost
	cmp.l	#$00a00000,d0		; not the custom chips, CIAs or the ROM
	bcs.s	.st
	cmp.l	#$01000000,d0
	bcs.w	.nost
.st:	lea	.tstack(pc),a1
	bsr.w	cr_s
	move.l	cr_regs+60,a2
	moveq	#0,d2
.sl:	move.b	#" ",(a0)+
	move.l	(a2,d2.w*4),d0
	bsr.w	cr_h8
	addq.w	#1,d2
	moveq	#7,d0
	and.w	d2,d0
	bne.s	.sn
	bsr.w	cr_nl
.sn:	cmp.w	#24,d2
	bne.s	.sl
	move.l	cr_regs+60,a2		; those into the program: return addresses?
	moveq	#0,d2
.rl:	move.l	(a2,d2.w*4),d0
	moveq	#2,d1
	bsr.w	cr_inprog
	beq.s	.rn
	lea	.tret(pc),a1
	bsr.w	cr_s
	move.w	d2,d0
	bsr.w	cr_h2
	lea	.tsp(pc),a1
	bsr.w	cr_s
	move.l	(a2,d2.w*4),d0
	bsr.w	cr_h8
	bsr.w	cr_nl
.rn:	addq.w	#1,d2
	cmp.w	#24,d2
	bne.s	.rl
.nost:	lea	.tset(pc),a1		; settings and state
	bsr.w	cr_s
	lea	.vars(pc),a3
.v:	move.l	(a3)+,d0
	beq.s	.vx
	move.l	d0,a1
	bsr.w	cr_s
	move.l	(a3)+,a1
	move.l	(a1),d0
	bsr.w	cr_h8
	bsr.w	cr_nl
	bra.s	.v
.vx:	lea	.tname(pc),a1		; the cart and the last file picked
	bsr.w	cr_s
	lea	tNomCart,a1
	bsr.w	cr_s
	bsr.w	cr_nl
	lea	.tfile(pc),a1
	bsr.w	cr_s
	lea	FileNom,a1
	bsr.w	cr_s
	bsr.w	cr_nl
	lea	.thunk(pc),a1		; hunks
	bsr.w	cr_s
	lea	cr_hunks,a2
	moveq	#0,d2
.hl:	cmp.w	cr_nhunks,d2
	bcc.s	.hx
	lea	.thk(pc),a1
	bsr.w	cr_s
	move.w	d2,d0
	bsr.w	cr_h2
	lea	.tsp(pc),a1
	bsr.w	cr_s
	move.l	(a2)+,d0
	bsr.w	cr_h8
	lea	.tsz(pc),a1
	bsr.w	cr_s
	move.l	(a2)+,d0
	bsr.w	cr_h8
	bsr.w	cr_nl
	addq.w	#1,d2
	bra.s	.hl
.hx:	lea	.tsteps(pc),a1		; the steps, oldest first
	bsr.w	cr_s
	move.l	cr_n,d3
	move.l	d3,d2
	sub.l	#CR_RING,d2
	bpl.s	.s0
	moveq	#0,d2
.s0:	cmp.l	d3,d2
	bcc.s	.sx
	move.l	d2,d0
	bsr.w	cr_h8			; its number
	move.b	#" ",(a0)+
	move.l	d2,d0
	and.w	#CR_RING-1,d0
	lea	cr_ring,a2
	lea	(a2,d0.w*8),a2
	move.w	2(a2),d0		; VBL
	bsr.w	cr_h4
	move.b	#" ",(a0)+
	moveq	#0,d0
	move.w	(a2),d0
	cmp.w	#CR_NSTEP,d0
	bcc.s	.su
	lea	cr_stepn,a1
	move.l	(a1,d0.w*4),a1
	bra.s	.sm
.su:	lea	.tunk(pc),a1
.sm:	bsr.w	cr_s
	move.b	#" ",(a0)+
	move.b	#"$",(a0)+
	move.l	4(a2),d0
	bsr.w	cr_h8
	bsr.w	cr_nl
	addq.l	#1,d2
	bra.s	.s0
.sx:	move.l	a0,d0
	sub.l	#cr_txt,d0
	move.l	d0,cr_tlen
	rts
.t0:	dc.b	"AmiGameBoy crash log (RTG Fix Crash Log, 26 Nov 2026)",10
	dc.b	"error #",0
.t1:	dc.b	"  ",0
.tpc:	dc.b	"PC $",0
.tsr:	dc.b	"  SR $",0
.tfv:	dc.b	"  frame $",0
.tbytes: dc.b	"at PC:",0
.tstack: dc.b	"stack:",10,0
.tret:	dc.b	"ret ",0
.tsp:	dc.b	" $",0
.tsz:	dc.b	" size $",0
.thk:	dc.b	"hunk ",0
.tset:	dc.b	"state:",10,0
.tname:	dc.b	"cart name: ",0
.tfile:	dc.b	"last file: ",0
.thunk:	dc.b	"hunks:",10,0
.tsteps: dc.b	"steps (number, VBL, step, value), oldest first:",10,0
.tunk:	dc.b	"?",0
.e2:	dc.b	"bus error",0
.e3:	dc.b	"address error",0
.e4:	dc.b	"illegal instruction",0
.e5:	dc.b	"divide by zero",0
.e6:	dc.b	"CHK",0
.e7:	dc.b	"TRAPV",0
.e8:	dc.b	"privilege violation",0
.e9:	dc.b	"trace",0
.e10:	dc.b	"line A",0
.e11:	dc.b	"line F",0
.v0:	dc.b	"MiraCartSize bytes 0-3 (51F9xxxx when sound) $",0
.v0b:	dc.b	"MiraCartSize bytes 4-7 (xxxxE8C0 when sound) $",0
.v1:	dc.b	"DirCart $",0
.v2:	dc.b	"BucCart $",0
.v3:	dc.b	"HyFlat $",0
.v4:	dc.b	"HyEngSP $",0
.v5:	dc.b	"sgb_on, col, p1, rdy $",0
.v6:	dc.b	"bezel, scanlines (first two bytes) $",0
.v7:	dc.b	"sgb_opt (first byte) $",0
.v8:	dc.b	"RTG mode $",0
.v9:	dc.b	"RTG width, height $",0
.v10:	dc.b	"RTG scale (high word) $",0
.v11:	dc.b	"sgb_bvalid, bdirty (first two bytes) $",0
.v12:	dc.b	"engine frozen (first byte) $",0
	even
.names:	dc.l	.tunk,.tunk,.e2,.e3,.e4,.e5,.e6,.e7,.e8,.e9,.e10,.e11
.vars:	dc.l	.v0,MiraCartSize,.v0b,MiraCartSize+4,.v1,DirCart,.v2,BucCart,.v3,HyFlat,.v4,HyEngSP
	dc.l	.v5,sgb_on,.v6,gbc_rbezon,.v7,sgb_opt,.v8,gbc_rmode,.v9,gbc_rw
	dc.l	.v10,gbc_rscale,.v11,sgb_bvalid,.v12,cr_frozen,0

; d0 = address, d1 = bytes -> NE when d0 .. d0+d1 is inside one of our hunks. Keeps the rest.
cr_inprog:
	movem.l	d1-d3/a1,-(sp)
	lea	cr_hunks,a1
	move.w	cr_nhunks,d3
	subq.w	#1,d3
	bmi.s	.no
.l:	move.l	d0,d2
	sub.l	(a1)+,d2		; offset in this hunk
	bcs.s	.n
	add.l	d1,d2
	cmp.l	(a1),d2
	bhi.s	.n
	moveq	#1,d0
	bra.s	.x
.n:	addq.l	#4,a1
	dbra	d3,.l
.no:	moveq	#0,d0
.x:	movem.l	(sp)+,d1-d3/a1
	tst.l	d0
	rts

; text helpers: a0 = the output (moves on)
cr_s:	move.b	(a1)+,(a0)+		; the string at a1
	bne.s	cr_s
	subq.l	#1,a0
	rts
cr_nl:	move.b	#10,(a0)+
	rts
cr_h8:	swap	d0			; d0.l as 8 hex digits
	bsr.s	cr_h4
	swap	d0
cr_h4:	ror.w	#8,d0			; d0.w as 4
	bsr.s	cr_h2
	rol.w	#8,d0
cr_h2:	move.l	d0,-(sp)		; d0.b as 2
	lsr.b	#4,d0
	bsr.s	.d
	move.l	(sp),d0
	bsr.s	.d
	move.l	(sp)+,d0
	rts
.d:	and.w	#15,d0
	move.b	.hex(pc,d0.w),(a0)+
	rts
.hex:	dc.b	"0123456789ABCDEF"

; ---- PROGDIR:crash.log (cr_txt), closed at once
cr_write:
	move.l	HyDosBase,d0
	beq.s	.x
	move.l	d0,a6
	move.l	#cr_fname,d1
	move.l	#MODE_NEWFILE,d2
	jsr	dosOpen(a6)
	move.l	d0,d4
	beq.s	.x
	move.l	d4,d1
	move.l	#cr_txt,d2
	move.l	cr_tlen,d3
	jsr	dosWrite(a6)
	move.l	d4,d1
	jsr	dosClose(a6)
	st	cr_wrote
.x:	rts

; ---- the requester: d0 = 1 Reboot, 0 Suspend
cr_req:
	move.l	4.w,a6
	lea	.int(pc),a1
	moveq	#36,d0
	jsr	-552(a6)		; OpenLibrary
	tst.l	d0
	beq.s	.none
	move.l	d0,a6
	move.l	cr_num,d0
	or.l	#$80000000,d0
	move.l	d0,cr_args
	move.l	cr_pc,cr_args+4
	move.l	#.ok,cr_args+8
	tst.b	cr_wrote
	bne.s	.w
	move.l	#.nok,cr_args+8
.w:	sub.l	a0,a0
	move.l	MainMenuWnd,d0		; on the menu's screen, which is in front
	beq.s	.nw
	move.l	d0,a0
.nw:	lea	cr_easy,a1
	sub.l	a2,a2
	lea	cr_args,a3
	jsr	-588(a6)		; EasyRequestArgs
	rts
.none:	moveq	#0,d0
	rts
.int:	dc.b	"intuition.library",0
.ok:	dc.b	"crash.log is in AmiGameBoy's drawer:",10
	dc.b	"please send it, with a photo of this box.",0
.nok:	dc.b	"crash.log could not be written.",10
	dc.b	"Please send a photo of this box.",0
	even

	SECTION	crdata,DATA
cr_easy:	dc.l	20,0,cr_title,cr_body,cr_gads
cr_title:	dc.b	"AmiGameBoy RTG Fix Crash Log",0
cr_body:	dc.b	"AmiGameBoy stopped:",10
		dc.b	"error #%08lx at $%08lx",10,10
		dc.b	"%s",0
cr_gads:	dc.b	"Reboot|Suspend",0
cr_fname:	dc.b	"PROGDIR:crash.log",0
	even
; step names (HYSTEP numbers)
cr_stepn:
	dc.l	.s0,.s1,.s2,.s3,.s4,.s5,.s6,.s7,.s8,.s9
	dc.l	.s10,.s11,.s12,.s13,.s14,.s15,.s16,.s17,.s18,.s19
	dc.l	.s20,.s21,.s22,.s23,.s24,.s25,.s26,.s27,.s28
CR_NSTEP	=(*-cr_stepn)/4
.s0:	dc.b	"-",0
.s1:	dc.b	"start (Start)",0
.s2:	dc.b	"Insert (BucCart)",0
.s3:	dc.b	"file picked (MiraCartSize 1st long)",0
.s4:	dc.b	"old cart freed (DirCart)",0
.s5:	dc.b	"new cart allocated (DirCart)",0
.s6:	dc.b	"cart read (BucFile)",0
.s7:	dc.b	"file name length",0
.s8:	dc.b	"header $143 $146 $147 $14B",0
.s9:	dc.b	"Insert done (DirCart)",0
.s10:	dc.b	"Power On 0 / Continue -1",0
.s11:	dc.b	"Power On in the engine (DirCart)",0
.s12:	dc.b	"flat copy (HyFlat)",0
.s13:	dc.b	"ROM images (HyRom32)",0
.s14:	dc.b	"sgb_install (on col p1 rdy)",0
.s15:	dc.b	"screen open (mode)",0
.s16:	dc.b	"screen (width, height)",0
.s17:	dc.b	"screen (scale, -)",0
.s18:	dc.b	"engine starts (frozen)",0
.s19:	dc.b	"Esc: pause (HyEngSP)",0
.s20:	dc.b	"engine stopped",0
.s21:	dc.b	"screen closed",0
.s22:	dc.b	"cart copy freed (HyFlat)",0
.s23:	dc.b	"Eject (DirCart)",0
.s24:	dc.b	"Continue: engine resumes (HyEngSP)",0
.s25:	dc.b	"screen open: SGB border? (bvalid bdirty ..)",0
.s26:	dc.b	"SGB border arrived (scale)",0
.s27:	dc.b	"SGB border: scale now (scale)",0
.s28:	dc.b	"settings: bezel scan .. / sgb_opt ...",0
	even
cr_busy:	dc.b	0
cr_frozen:	dc.b	0
cr_wrote:	dc.b	0
	even

	SECTION	crbss,BSS
cr_task:	ds.l	1
cr_oldtrap:	ds.l	1
cr_n:		ds.l	1
cr_ring:	ds.l	2*CR_RING
cr_num:		ds.l	1
cr_pc:		ds.l	1
cr_sr:		ds.w	1
cr_fv:		ds.w	1
cr_regs:	ds.l	16
cr_frame:	ds.l	8
cr_args:	ds.l	4
cr_tlen:	ds.l	1
cr_nhunks:	ds.w	1
		ds.w	1
cr_hunks:	ds.l	2*CR_HUNKS
cr_stack:	ds.b	CR_STK
cr_txt:		ds.b	16384
	SECTION	hybrid,CODE

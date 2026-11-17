; cd32read.s - the CD32 pad read of the emu-dev-docs CD32 kit 2 (kits/cd32pad/cd32read.s),
; HY_CD32KIT builds only (in place of cd32pad.s).
; The reader below (cd32read) is FAmiga's, by Afrotechmods: z00p's ReadCD32Pads (cd32pad.s,
; MIT licence, see cd32pad.LICENSE) with FAmiga's changes, instruction for instruction as the
; kit has it. Credit: "CD32 pad read: Afrotechmods / FAmiga". FAmiga's changes come with no
; conditions; the routine they change is under the kit's MIT licence. Only the equates, the
; section names and the caller (HyCD32Kit, in place of the kit's cd32pads) are ours.
; Devpac / vasm (-devpac) syntax, 68000 code.
;
; Two clocks, one per port, chosen in AmiGameBoy.config (only port 2 is read here):
;   "Pad = CD32 pad"    the kit's reader (default): pin 6 idles high, each pulse low then high
;   "Pad = KTRL CD32+"  the low clock: pin 6 idles low, each pulse high then low
; FAmiga's tests (kit README): the first KTRL CD32 right with the first; the KTRL CD32+ and the
; Mega Multi adapter in CD32 mode right with the low clock.
; Changes from cd32pad.s on both clocks (the kit's [CHANGE n] notes): pin 6 written from a copy
; of the port byte (the image clock), a 35-read latch wait (cd32pad.s: 200), 3 + 3 CIA reads a
; pulse, nine bits read (the seven buttons, then the pad's two ID bits, not used here).
;
; The hybrid calls ReadCD32Pads once a Game Boy frame with the OS frozen (no Disable needed).
; ReadCD32Pads keeps cd32pad.s's place and size in the hybrid section (nothing behind it moves,
; the 68030 instruction cache as NO_IDLEPAD); the code sits in sections of its own.
;
; Test switches: HY_CD32LOWDEF=2 starts on the low clock (builds without a config file);
; HY_CD32STAT (AutoExit builds): " cd32=" in AmiGB.result, the raw nine bits ORed over every
; read, the reads, the reads with red, the reads with the pad's ID bits (hybrid.asm HyResult).

	IFND	HY_CD32LOWDEF
HY_CD32LOWDEF	=0			; bit 1 set: port 2 on the low clock
	ENDC

CUSTOM		equ	$dff000
POTINP		equ	$016			; POTGOR: the pot pins as read
POTGO		equ	$034
CIAAPRA		equ	$bfe001			; bit 7: port 2's pin 6, bit 6: port 1's
CIAADDRA	equ	$bfe201			; the same bits as outputs (1) while a pad is clocked

; cd32pad.s's entry, the same size (234 bytes): d0.b = 2 (port 2) -> d0.b = port 2's buttons,
; 1 = pressed (bit 0 blue, 1 red, 2 yellow, 3 green, 4 R, 5 L, 6 play; all seven = a plain
; joystick -> $00), d1.b = 0 (port 1, not read). Everything else preserved.
ReadCD32Pads:
	jmp	HyCD32Kit
	ds.b	234-6

	SECTION	hycd32,CODE
HyCD32Kit:
	move.b	HyCD32Low,d1
	and.b	d0,d1			; the ports asked for on the low clock
	bsr.s	cd32read
	IFD	HY_CD32STAT		; test: the raw nine bits ORed, reads, reads with red,
	or.l	d0,HyCD32St		; reads with the pad's ID (bit 7 = 0, bit 8 = 1)
	addq.l	#1,HyCD32St+4		; (AmiGB.result " cd32=")
	btst	#1,d0
	beq.s	.nored
	addq.l	#1,HyCD32St+8
.nored:	move.w	d0,d1
	and.w	#$180,d1
	cmp.w	#$100,d1
	bne.s	.noid
	addq.l	#1,HyCD32St+12
.noid:
	ENDC
	and.l	#$7f,d0			; the seven buttons (the ID bits dropped)
	cmp.b	#$7f,d0			; all seven at once: a plain joystick
	bne.s	.ok
	moveq	#0,d0
.ok:	moveq	#0,d1
	rts

; -----------------------------------------------------------------------------
; cd32read - z00p's ReadCD32Pads, with FAmiga's changes (Afrotechmods). The kit's file
; explains each [CHANGE n]; the instructions are the kit's.
;   in:  d0.b = ports to read: bit 1 = port 2 (joystick port), bit 0 = port 1
;               (mouse port).  A port left out is never driven.
;        d1.b = the ports among them read with the LOW CLOCK.
;   out: d0.l = port 2's answer, d1.l = port 1's.  Nine bits, 1 = pin 9 low (pressed):
;        bit 0 blue, 1 red, 2 yellow, 3 green, 4 right shoulder, 5 left shoulder,
;        6 play, 7 and 8 the pad's two ID bits.  0 for a port not read.
;   Everything else preserved.  Call with interrupts off: it owns POTGO and
;   CIA-A DDRA bits 6/7 while it runs.
; -----------------------------------------------------------------------------
cd32read:
	movem.l	d2-d6,-(sp)
	moveq	#0,d3			; d3 = the CIA-A PRA bits to clock (pin 6 of each port read)
	moveq	#0,d6			; d6 = those among them on the low clock
	move.w	#$ff00,d4		; d4 = POTGO: pin 5 low on each port read
	btst	#1,d0
	beq.s	.no2
	move.b	#$80,d3			; port 2's clock: PRA bit 7
	and.w	#$6fff,d4		; port 2: DATRX = 0 (pin 5 low), OUTRY = 0 (pin 9 an input)
	btst	#1,d1			; port 2 on the low clock?
	beq.s	.no2
	move.b	#$80,d6
.no2:	btst	#0,d0
	beq.s	.no1
	or.b	#$40,d3			; port 1's clock: PRA bit 6
	and.w	#$f6ff,d4		; port 1: DATLX = 0, OUTLY = 0
	btst	#0,d1			; port 1 on the low clock?
	beq.s	.no1
	or.b	#$40,d6
.no1:	moveq	#0,d0
	moveq	#0,d1
	tst.b	d3
	beq	.done			; no port asked: nothing is driven
	move.b	CIAAPRA,d2		; the port's byte as it is: the image
	or.b	d3,d2			; every clocked pin 6 high (the kit reader's idle level) ...
	eor.b	d6,d2			; ... and the low clock's back to LOW (d6 is within d3)
	move.b	d2,CIAAPRA		; pin 6 at its idle level, then an output, held there
	or.b	d3,CIAADDRA		; while pin 5 falls (no clock edge)
	move.b	d2,CIAAPRA		; written once more now the pin is an output (UAE's edge
					; detector takes its first level from such a write)
	move.w	d4,CUSTOM+POTGO		; pin 5 low: the pad latches its buttons
	move.b	d2,d4			; d4 = the image from here on
	move.w	_cd32_latch,d2		; the latch wait: _cd32_latch CIA reads (35, ~50 us)
	subq.w	#1,d2
.latch:	tst.b	CIAAPRA
	dbf	d2,.latch
	moveq	#9-1,d2			; nine bits: the seven buttons and the two ID bits
.bit:	lsr.w	#1,d0			; the first out ends in bit 0
	btst	#6,CUSTOM+POTINP	; port 2's pin 9 (DATRY, bit 14): 1 = released
	beq.s	.lo2
	bset	#8,d0
.lo2:	lsr.w	#1,d1
	btst	#2,CUSTOM+POTINP	; port 1's pin 9 (DATLY, bit 10)
	beq.s	.lo1
	bset	#8,d1
.lo1:	eor.b	d3,d4			; the pulse's first half, written from the image
	move.b	d4,CIAAPRA
	move.w	_cd32_clock,d5		; _cd32_clock CIA reads (3)
	subq.w	#1,d5
.wlo:	tst.b	CIAAPRA
	dbf	d5,.wlo
	eor.b	d3,d4			; ... and back to idle: the next bit
	move.b	d4,CIAAPRA
	move.w	_cd32_clock,d5		; the wait before the next bit's read
	subq.w	#1,d5
.whi:	tst.b	CIAAPRA
	dbf	d5,.whi
	dbf	d2,.bit
	move.w	#$ff00,CUSTOM+POTGO	; pin 5 high: plain joystick mode again
	not.b	d3
	and.b	d3,CIAADDRA		; pin 6 an input again
	not.w	d0			; 1 = pressed (low)
	and.l	#$1ff,d0		; nine bits kept
	not.w	d1
	and.l	#$1ff,d1
	not.b	d3			; ports not asked for: 0
	btst	#7,d3
	bne.s	.r2
	moveq	#0,d0
.r2:	btst	#6,d3
	bne.s	.done
	moveq	#0,d1
.done:	movem.l	(sp)+,d2-d6
	rts

	IFD	HY_MENU
; "Pad = CD32 pad" / "Pad = KTRL CD32+" in the config text (padcfg.s calls this on what it
; read): a0 = text, a1 = its end. Any case, blanks around the "="; the word after it decides:
; KTRL -> the low clock, CD32 -> the kit's reader; a line that does not parse changes nothing.
; OS alive (start-up). Keeps every register.
HyCD32Cfg:
	movem.l	d0-d2/a0/a2-a3,-(sp)
.line:	bsr.s	.blank
	lea	HyCD32Key(pc),a2
	bsr.s	.word
	beq.s	.skip
	bsr.s	.blank
	cmp.l	a1,a0
	bcc.s	.skip
	cmp.b	#"=",(a0)+
	bne.s	.skip
	bsr.s	.blank
	move.l	a0,a3
	lea	HyCD32Ktrl(pc),a2
	moveq	#2,d2			; port 2 on the low clock
	bsr.s	.word
	bne.s	.set
	move.l	a3,a0
	lea	HyCD32Std(pc),a2
	moveq	#0,d2
	bsr.s	.word
	beq.s	.skip
.set:	move.b	d2,HyCD32Low
.skip:	cmp.l	a1,a0			; to the next line
	bcc.s	.x
	cmp.b	#10,(a0)+
	bne.s	.skip
	bra.s	.line
.x:	movem.l	(sp)+,d0-d2/a0/a2-a3
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
; the upper-case word at a2 (ends with 0) at a0, any case, a whole word: NE and a0
; behind it, or EQ (a0 somewhere in it)
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
HyCD32Key:	dc.b	"PAD",0
HyCD32Ktrl:	dc.b	"KTRL",0
HyCD32Std:	dc.b	"CD32",0
	even
	ENDC

	SECTION	hycd32data,DATA
; the two waits, in CIA reads (~1.4 us each on any CPU), as the kit (FAmiga 1.02: 35 and 3)
	IFND	HY_CD32LATCH
HY_CD32LATCH	=35			; test switch: the latch wait in CIA reads (cd32pad.s 1.0: 200)
	ENDC
_cd32_latch:	dc.w	HY_CD32LATCH
_cd32_clock:	dc.w	3
HyCD32Low:	dc.b	HY_CD32LOWDEF		; bit 1: port 2 on the low clock (the config's Pad line)
	even
	IFD	HY_CD32STAT
HyCD32St:	dc.l	0,0,0,0
	ENDC

	SECTION	hybrid,CODE

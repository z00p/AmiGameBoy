; AmiGameBoy hybrid (stage 1): Wzonka-Lad's engine driving Juan's AGA renderer.
; Copyright (C) 2026 AmiGameBoy contributors. GPL-2 (see src/engine/COPYING). The engine
; files come from Wzonka-Lad 1.03 by Ville Helin and Ventzislav Tzvetkov; the renderer
; (juan_video.s) from AmiGameBoy 1.0 by Juan Antonio Gomez Galvez.
;
; Test build with the cartridge inside, no menu yet (docs/design-hybrid.md 3.3, 11):
;   sh build.sh hybrid ROM [out]      VASMDEFS="-DAutoExit=600" to leave after 600 frames
;
; The engine is the main loop. At LY 144 (hybrid_frame) we wait for the Amiga VBL, build
; the display from VRAM, OAM and the per-line register log (Juan's frame tick), read the
; pads and go back to the engine, which runs lines 144-153 and 0-143. At the start of
; LY 0 (hybrid_line0) the register state for the top of the next picture is taken.
; Register writes that Juan's renderer logs per line ($FF40/42/43/47/4A/4B) and tile data
; writes ($8000-$97FF, dirty marks) go through our handlers in Wzonka's write table.

GAMEBOY_DEBUG	=0
GAMEBOY_SERIAL	=0
Z80_MODE	=0
HYBRID		=1
ColorDebug	=1		; Juan: 0 colours the copper-compiled lines
	IFND	HY_WITH_BEZEL		; 1.0 ships without the bezel and the tint (left for
	IFND	NO_BEZEL		; 1.1, screen surround only); -DHY_WITH_BEZEL builds them
NO_BEZEL	SET	1
	ENDC
	IFND	NO_TINT
NO_TINT		SET	1
	ENDC
	ENDC
	IFND	NO_BEZEL		; the optional bezel and the LCD tint (bezel.s): the
HY_BEZHOOK	SET	1		; call in the palette set-up is there for either
	ENDC
	IFND	NO_TINT
HY_BEZHOOK	SET	1
	ENDC
INPUT_OK	=0
INPUT_GBS_LOAD	=1
INPUT_GBS_SAVE	=2
INPUT_HALT	=3

	IFND	AutoExit
AutoExit	=0
	ENDC
	IFND	HY_VBLFRAMES
HY_VBLFRAMES	=78411		; Game Boy frames per PAL VBL, 16.16 (59.7275 / 49.92)
	ENDC
	IFND	HY_MAXSKIP
HY_MAXSKIP	=3		; pictures skipped in a row at most
	ENDC
	IFND	HY_PACELINE
HY_PACELINE	=190		; NO_SNDPACE off: earliest beam line for a skipped frame
	ENDC

	IFD	HY_MENU
NO_WBSTART	=1		; Juan's menu takes the Workbench message
	ENDC
; exec / dos offsets
AllocMem	=-198
FreeMem		=-210
OpenLibrary	=-552
CloseLibrary	=-414
CacheClearU	=-636
	IFND	NO_WBSTART
Forbid		=-132
FindTask	=-294
GetMsg		=-372
ReplyMsg	=-378
WaitPort	=-384
	ENDC
dosOpen		=-30
dosClose	=-36
dosWrite	=-48
MEMF_PUBLIC	=1
MEMF_CLEAR	=$10000
MODE_NEWFILE	=1006

	SECTION	hybrid,CODE

	IFD	HY_MENU			; one program: Juan's menu, the engine behind Power On
	include	"menu.s"
	ELSE
Start:	movem.l	d2-d7/a2-a6,-(sp)
	move.l	sp,HySP
	move.l	4.w,a6
	move.l	a6,exec_base
	IFND	NO_WBSTART		; started from an icon: take Workbench's message
	sub.l	a1,a1
	jsr	FindTask(a6)
	move.l	d0,a2
	tst.l	$ac(a2)			; pr_CLI
	bne.s	.cli
	lea	$5c(a2),a0		; pr_MsgPort
	jsr	WaitPort(a6)
	lea	$5c(a2),a0
	jsr	GetMsg(a6)
	move.l	d0,HyWBMsg
.cli:
	ENDC
	lea	HyDosName,a1
	moveq	#36,d0
	jsr	OpenLibrary(a6)
	move.l	d0,HyDosBase
	beq.w	.fail

; memory: Game Boy space is our static block (Juan's renderer addresses VRAM and the
; registers absolutely); write table, battery banks and ROM images are allocated
	move.l	#GBMEM,gb_memory
	move.l	#$40000,d0
	bsr.w	HyAlloc
	move.l	d0,gb_mem_jumps
	beq.w	.fail
	move.l	#131072+$2000,d0
	bsr.w	HyAlloc
	move.l	d0,memory_banks
	beq.w	.fail
	move.l	#EmbedCartEnd-EmbedCart,d0
	move.l	d0,file_length
	add.l	d0,d0
	bsr.w	HyAlloc
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
	bsr.w	HyPatchWrites		; our handlers for the renderer
	IFD	HY_GBC			; Game Boy Color: CGB registers (gbc.s), the line renderer
	move.l	gb_mem_jumps,a0
	jsr	gbc_install
	IFD	GBC_RENDER
	jsr	gbc_line_init
	ENDC
	ENDC

	IFND	NO_SOUND
	clr.b	snd_quality		; per-line hook on: Paula sound (sound.s)
	ELSE
	move.b	#1,snd_quality		; no AHI envelope sweeps
	ENDC
	move.b	#1,old_refresh		; Wzonka draws nothing
	move.b	#$ff,refresh_scanline
	clr.b	input_status

; Juan's set-up, as GameBoyEmul and Z80 do with the default prefs (joystick, grey)
	jsr	InitSistema
	move.l	#LeeJoyStick,JoyControlRut
	IFD	HY_BEZHOOK		; (the same 20 bytes) grey, then tint and bezel (bezel.s)
	lea	PaletaGrey,a0
	jsr	HyBezPrefs
	move.l	(a0),GBPaleta+4
	nop
	ELSE
	move.l	PaletaGrey,GBPaleta
	move.l	PaletaGrey+4,GBPaleta+4
	ENDC
	IFD	HY_TESTPAL		; test: shades 0-3 red, green, blue, black (hue survives display gain)
	move.l	#$0f0000f0,GBPaleta
	move.l	#$000f0000,GBPaleta+4
	ENDC
	lea	Regs,a3
	move.l	#-1,EstadoJoy(a3)
	move.l	#-1,EstadoKeys(a3)
	lea	Sprit0,a0
	move.w	#(OTRSPR*4/4)-1,d0
	jsr	BorraMem
	lea	SprGfx0Fast,a0
	move.w	#(OTRSPR*4/4)-1,d0
	jsr	BorraMem
	move.w	#$20,$dff1dc		; PAL, as the menu's screen mode 0

	move.l	4.w,a6
	jsr	CacheClearU(a6)
	IFD	GBC_RTG			; test: the 16-bit Picasso96 screen, OS alive (gbc_rtg.s)
	jsr	gbc_rtg_open
	ENDC
	jsr	CongelaAMIGA		; take the machine (VBL vector -> HyVBL)
	IFD	GBC_RTG
	tst.b	gbc_rtg_on		; RTG: nothing of the display from chip RAM
	beq.s	.nortg
	move.w	#$01a0,$dff096		; BPLEN, COPEN, SPREN off
	move.w	#$0000,$dff180
	move.w	#$0200,$dff100
.nortg:
	ENDC
	IFND	NO_SOUND
	bsr.w	HySndInit		; Paula voices on, silent
	ENDC
	move.w	#$7fff,$dff09c
	move.w	#$c020,$dff09a		; VBL only
	bra.w	run_cartridge		; never returns; leaves through HyExit

.fail:	moveq	#20,d0
	bra.w	HyFinish
	ENDC

	IFD	HY_HOLD
HyHoldMsg:	dc.b	"HOLD",13,10,0
	even
	ENDC

; ---- level 3: count Amiga frames
	cnop	0,4
HyVBL:	btst	#5,$dff01f
	beq.s	.x
	addq.l	#1,HyVblN
	IFND	NO_SOUND
	tst.b	HySndPend		; noise sample switch: voice 3 DMA back on
	beq.s	.x
	subq.b	#1,HySndPend
	bne.s	.x
	move.w	#$8008,$dff096
	ENDC
.x:	move.w	#$0070,$dff09c
	move.w	#$0070,$dff09c
	nop
	rte

; ---- engine hook at the start of LY 144 (all registers preserved)
; Pacing (docs/design-hybrid.md 3.3, frame skipping): the game clock runs off the Amiga
; VBL count, each VBL earning HY_VBLFRAMES/65536 Game Boy frames of time (credit). At
; each frame end one frame is spent. A frame is drawn right after a VBL (Juan's copper
; list is single-buffered); when the credit says we are a frame or more behind, the
; picture is skipped instead, at most HY_MAXSKIP in a row (then the game slows down).
; NO_FRAMESKIP: draw every frame after a VBL (the game runs at the screen rate).
hybrid_frame:
	movem.l	d0-d7/a0-a6,-(sp)
	IFD	GBC_RENDER
	jsr	gbc_frame_end		; LCD off all frame: white
	ENDC
	IFD	HY_FRAMELOG
	bsr.w	HyFLogAdd
	ENDC
	IFND	NO_SOUND
	tst.l	HyFrames		; first frame: NR52 channel bits from our channels
	bpl.s	.snd1			; (the post-boot values say channel 1 is on)
	bsr.w	HySndStatus
.snd1:
	ENDC
	IFD	HY_HOLD			; test grabs: no pacing, draw every frame at once
	bra.w	.now
	ENDC
	IFD	NO_FRAMESKIP
.wait:	move.l	HyVblN,d0
	cmp.l	HyVblSeen,d0
	beq.s	.wait
	move.l	d0,HyVblSeen
	ELSE
	bsr.w	HyCredit
	sub.l	#$10000,HyCreditF	; this frame's time
	cmp.l	#$10000,HyCreditF	; still a frame or more behind?
	blt.s	.draw
	cmp.b	#HY_MAXSKIP,HySkipRun
	bcc.s	.draw
	addq.b	#1,HySkipRun		; skip the picture
	addq.l	#1,HySkipped
	lea	TabRasCMDS,a0		; drop this frame's register log
	moveq	#144/4-1,d0
.clr:	clr.l	(a0)+
	dbra	d0,.clr
	IFND	NO_SOUND
	IFND	NO_SNDPACE		; sound: a skipped frame in the same Amiga frame as the
	cmp.l	#$20000,HyCreditF	; last drawn one would run right behind it, two Game
	bge.s	.nopace			; Boy frames of sound writes in a millisecond on a
.pace:	move.l	HyVblN,d0		; fast machine. Unless behind, start it from line
	cmp.l	HyVblDrawn,d0		; HY_PACELINE (between this and the next drawn
	bne.s	.nopace			; frame) or the next VBL, whichever comes first.
	move.l	$dff004,d0
	lsr.l	#8,d0
	and.w	#$1ff,d0
	cmp.w	#HY_PACELINE,d0
	bcs.s	.pace
.nopace:
	ENDC
	ENDC
	bra.w	.drawn
.draw:	sf	HySkipRun
	IFD	HY_IDLE			; test: beam lines spent waiting to draw (spare time)
	move.l	$dff004,d0
	lsr.l	#8,d0
	and.l	#$1ff,d0
	move.l	d0,HyIdle0
	ENDC
	IFND	NO_BEAMDRAW		; behind (skip cap reached): no VBL wait, draw as soon
	cmp.l	#$10000,HyCreditF	; as the beam is out of the Game Boy picture
	blt.s	.vbl			; (lines $48-$D7) with time to finish before it
.beam:	move.l	$dff004,d0		; (a build is ~35 lines; a full redraw tears once)
	lsr.l	#8,d0
	and.w	#$1ff,d0
	cmp.w	#FINSPR,d0
	bcc.s	.go
	cmp.w	#$10,d0
	bcs.s	.go
	bra.s	.beam
.vbl:
	ENDC
	move.l	HyVblN,d0		; draw just after a VBL
.wait:	cmp.l	HyVblN,d0
	beq.s	.wait
.go:
	IFD	HY_IDLE
	move.l	$dff004,d0
	lsr.l	#8,d0
	and.l	#$1ff,d0
	sub.l	HyIdle0,d0
	bpl.s	.ipos
	add.l	#313,d0
.ipos:	add.l	d0,HyIdleSum
	ENDC
	bsr.w	HyCredit
	cmp.l	#$30000,HyCreditF	; slower than the game: do not run
	ble.s	.ok			; ahead later to catch up
	move.l	#$30000,HyCreditF
.ok:
	IFND	NO_SOUND
	IFND	NO_SNDPACE
	move.l	HyVblN,HyVblDrawn	; Amiga frame of this picture
	ENDC
	ENDC
	ENDC
.now:
	IFD	HY_PROF			; test: beam lines spent in the build (max, total)
	bsr.w	HyBeam
	move.l	d0,-(sp)
	ENDC
	IFD	GBC_RTG
	jsr	gbc_rtg_show		; test: the GBC frame to the RTG screen
	ELSE
	jsr	HyBuild			; Juan's frame tick: copper, tiles, OBJs, palette
	ENDC
	IFD	HY_PROF
	bsr.w	HyBeam
	sub.l	(sp)+,d0
	bpl.s	.pos
	add.l	#313,d0
.pos:	add.l	d0,HyBuildSum
	cmp.l	HyBuildMax,d0
	bls.s	.nomax
	move.l	d0,HyBuildMax
.nomax:
	ENDC
.drawn:	jsr	HyPads
	lea	Regs,a3
	IFND	NO_CD32			; CD32 pad in port 2 (a plain joystick reads as no pad)
	moveq	#2,d0
	bsr.w	ReadCD32Pads		; d0: 1 = pressed: blue red yellow green R L play
	IFD	HY_PADFAKE		; test: these pad buttons for 6 frames in every 100
	move.l	HyFrames,d1
	divu.w	#100,d1
	swap	d1
	cmp.w	#6,d1
	bcc.s	.nofake
	moveq	#HY_PADFAKE,d0
.nofake:
	ENDC
	move.b	d0,d1
	and.b	#$30,d1			; a shoulder held with Play: quit
	beq.s	.cdnoq
	btst	#6,d0
	beq.s	.cdnoq
	st	SalirMenu(a3)
.cdnoq:
	IFND	NO_PADMAP		; buttons through the table (padcfg.s). Filled to the
	jsr	HyPadApply		; old code's 50 bytes: the engine behind keeps its
	bra.s	.cd4			; place (68030 instruction cache, as NO_IDLEPAD)
	ds.b	50-8
.cd4:
	ELSE
	moveq	#0,d1
	btst	#1,d0			; red = A
	beq.s	.cd1
	bset	#0,d1
.cd1:	btst	#0,d0			; blue = B
	beq.s	.cd2
	bset	#1,d1
.cd2:	move.b	d0,d2			; green or yellow = Select
	and.b	#$0c,d2
	beq.s	.cd3
	bset	#2,d1
.cd3:	btst	#6,d0			; play = Start
	beq.s	.cd4
	bset	#3,d1
.cd4:	not.b	d1
	and.b	d1,EstadoJoy+1(a3)	; low active, on top of the joystick and keys
	ENDC
	ENDC
	move.b	EstadoJoy+1(a3),d0	; buttons, low active: A B Select Start
	or.b	#$f0,d0
	move.b	d0,buttons_byte
	IFD	HY_PRESS		; test: Start for 6 frames in every 200 up to frame 1200
	move.l	HyFrames,d0		; (gets past title screens for grabs); HY_PRESS=2:
	IFEQ	HY_PRESS-2		; Start and A for 6 in every 100 up to 2400
	cmp.l	#2400,d0
	bcc.s	.nopr
	divu.w	#100,d0
	ELSE
	cmp.l	#1200,d0
	bcc.s	.nopr
	divu.w	#200,d0
	ENDC
	swap	d0
	cmp.w	#6,d0
	bcc.s	.nopr
	bclr	#3,buttons_byte
	IFEQ	HY_PRESS-2
	bclr	#0,buttons_byte
	ENDC
.nopr:
	ENDC
	move.b	EstadoJoy+2(a3),d0	; directions: Right Left Up Down
	or.b	#$f0,d0
	move.b	d0,directions_byte
	addq.l	#1,HyFrames
	IFD	HY_HOLD			; test: show frame HY_HOLD and stop there (grabs)
	cmp.l	#HY_HOLD+1,HyFrames	; +1: the spike's frame 0 ends at the second LY 144 (as Mesen)
	bcs.s	.run
.hold:	lea	HyHoldMsg(pc),a0	; tell uaerun --serial-until HOLD
	move.w	#372,$dff032		; SERPER: 9600 baud (PAL)
.ser:	move.b	(a0)+,d0
	beq.s	.idle
.tbe:	btst	#13-8,$dff018		; SERDATR TBE
	beq.s	.tbe
	and.w	#$ff,d0
	or.w	#$100,d0		; stop bit
	move.w	d0,$dff030
	bra.s	.ser
.idle:	bra.s	.idle
.run:
	ENDC
	IFNE	AutoExit
	cmp.l	#AutoExit,HyFrames
	bcc.s	HyExit
	ENDC
	IFD	HY_PAUSEAT		; test: pause at frame HY_PAUSEAT, as Esc
	cmp.l	#HY_PAUSEAT,HyFrames
	bne.s	.nopause
	st	SalirMenu(a3)
.nopause:
	ENDC
	tst.b	SalirMenu(a3)		; Esc
	IFD	HY_MENU
	bne.w	HyMenuPause		; back to the menu, Continue comes back here
	ELSE
	bne.s	HyExit
	ENDC
	movem.l	(sp)+,d0-d7/a0-a6
	rts

	IFD	HY_PROF
; beam line (0-312) -> d0
HyBeam:	move.l	$dff004,d0
	lsr.l	#8,d0
	and.l	#$1ff,d0
	rts
	ENDC

	IFND	NO_FRAMESKIP
; add the time of the VBLs since the last call to the credit
HyCredit:
	move.l	HyVblN,d0
	move.l	d0,d1
	sub.l	HyVblSeen,d0
	move.l	d1,HyVblSeen
	IFD	HY_MENU
	mulu.l	HyVblRate,d0		; PAL or NTSC, from the menu
	ELSE
	mulu.l	#HY_VBLFRAMES,d0
	ENDC
	add.l	d0,HyCreditF
	rts
	ENDC

; ---- engine hook at the start of LY 0
hybrid_line0:
	movem.l	d0-d7/a0-a6,-(sp)
	IFND	NO_LINEPAL
	jsr	HyLine0Pal		; the palettes at the top of the picture, then
	ELSE				; ActCopperLine0 (linepal.s)
	jsr	ActCopperLine0
	ENDC
	IFND	NO_OBJMASK
	move.b	RRAM+$1f40,HyObj0	; sprites on/off at the top of the picture
	clr.w	HyObjN
	ENDC
	movem.l	(sp)+,d0-d7/a0-a6
	rts

z80_halted:
HyExit:
	IFD	HY_MENU
	bra.w	HyMenuExit
	ENDC
	move.l	HySP,sp
	IFND	NO_SOUND
	bsr.w	HySndStop
	ENDC
	jsr	DescongelaAMIGA
	IFD	GBC_RTG
	jsr	gbc_rtg_close
	ENDC
	IFNE	AutoExit
	bsr.w	HyResult
	IFD	GBC_RENDER
	bsr.w	GbcFbSave
	ENDC
	ENDC
	IFD	HY_FRAMELOG
	bsr.w	HyFLogSave
	ENDC
	moveq	#0,d0
HyFinish:
	move.l	d0,-(sp)
	move.l	gb_mem_jumps,d0
	move.l	#$40000,d1
	bsr.w	HyFree
	move.l	memory_banks,d0
	move.l	#131072+$2000,d1
	bsr.w	HyFree
	move.l	rom_32k,d0
	move.l	file_length,d1
	add.l	d1,d1
	bsr.w	HyFree
	move.l	4.w,a6
	move.l	HyDosBase,d0
	beq.s	.nodos
	move.l	d0,a1
	jsr	CloseLibrary(a6)
.nodos:
	IFND	NO_WBSTART
	move.l	HyWBMsg,d0		; reply under Forbid: Workbench unloads us after
	beq.s	.nowb
	jsr	Forbid(a6)
	move.l	d0,a1
	jsr	ReplyMsg(a6)
.nowb:
	ENDC
	move.l	(sp)+,d0
	move.l	HySP,sp
	movem.l	(sp)+,d2-d7/a2-a6
	rts

; d0 = size -> d0 = cleared public memory or 0
HyAlloc:
	move.l	#MEMF_PUBLIC!MEMF_CLEAR,d1
	move.l	4.w,a6
	jmp	AllocMem(a6)

; d0 = pointer (or 0), d1 = size
HyFree:	tst.l	d0
	beq.s	.x
	move.l	d0,a1
	move.l	d1,d0
	move.l	4.w,a6
	jsr	FreeMem(a6)
.x:	rts

	IFD	HY_FRAMELOG
; test: when each Game Boy frame ends (LY 144), in beam lines (VBLs x 313 + line), first
; HY_FRAMELOG frames; saved to RAM:AmiGB.prof at the exit
HyFLogAdd:
	move.l	HyFLogN,d1
	cmp.l	#HY_FRAMELOG,d1
	bcc.s	.x
	move.l	HyVblN,d0
	mulu.l	#313,d0
	move.l	$dff004,d2
	lsr.l	#8,d2
	and.l	#$1ff,d2
	add.l	d2,d0
	lea	HyFLog,a0
	move.l	d0,(a0,d1.l*4)
	addq.l	#1,HyFLogN
.x:	rts
HyFLogSave:
	move.l	HyDosBase,a6
	move.l	#HyFLogName,d1
	move.l	#MODE_NEWFILE,d2
	jsr	dosOpen(a6)
	move.l	d0,d4
	beq.s	.x
	move.l	d4,d1
	move.l	#HyFLog,d2
	move.l	HyFLogN,d3
	lsl.l	#2,d3
	jsr	dosWrite(a6)
	move.l	d4,d1
	jsr	dosClose(a6)
.x:	rts
	ENDC

	IFD	GBC_RENDER
	IFNE	AutoExit
; test: GB:AmiGB.prof = "RTG2", the frame number, gbc_pixfmt (long), the last frame (gbc_fb,
; 160 x 144 words in that format),
; palette RAM (BG 64 + OBJ 64 bytes) for tools/gbc_pic.py
GbcFbSave:
	move.l	HyDosBase,a6
	move.l	#GbcFbName,d1
	move.l	#MODE_NEWFILE,d2
	jsr	dosOpen(a6)
	move.l	d0,d4
	beq.s	.x
	move.l	HyFrames,GbcFbHead+4
	move.b	gbc_pixfmt,GbcFbHead+11
	move.l	d4,d1
	move.l	#GbcFbHead,d2
	moveq	#12,d3
	jsr	dosWrite(a6)
	move.l	d4,d1
	move.l	#gbc_fb,d2
	move.l	#160*144*2,d3
	jsr	dosWrite(a6)
	move.l	d4,d1
	move.l	#gbc_bgpal,d2
	moveq	#64,d3
	jsr	dosWrite(a6)
	move.l	d4,d1
	move.l	#gbc_obpal,d2
	moveq	#64,d3
	jsr	dosWrite(a6)
	move.l	d4,d1
	jsr	dosClose(a6)
.x:	rts
GbcFbHead:	dc.b	"RTG2"
	dc.l	0,0
GbcFbName:	dc.b	"GB:AmiGB.prof",0
	even
	ENDC
	ENDC

	IFNE	AutoExit
; RAM:AmiGB.result "frames=xxxxxxxx" (the test Workbench copies it to GB:)
HyResult:
	IFD	IDL_STAT
	bsr.w	HyStatOut
	ENDC
	lea	HyResNum,a0
	move.l	HyFrames,d0
	bsr.s	.hex8
	lea	HyResSkip,a0
	move.l	HySkipped,d0
	bsr.s	.hex8
	lea	HyResVbl,a0
	move.l	HyVblN,d0
	bsr.s	.hex8
	IFD	HY_PROF
	lea	HyResBMax,a0
	move.l	HyBuildMax,d0
	bsr.s	.hex8
	lea	HyResBSum,a0
	move.l	HyBuildSum,d0
	bsr.s	.hex8
	ENDC
	IFD	HY_IDLE
	lea	HyResIdle,a0
	move.l	HyIdleSum,d0
	bsr.s	.hex8
	ENDC
	move.l	HyDosBase,a6
	move.l	#HyResName,d1
	move.l	#MODE_NEWFILE,d2
	jsr	dosOpen(a6)
	move.l	d0,d4
	beq.s	.x
	move.l	d4,d1
	move.l	#HyResText,d2
	IFD	IDL_STAT
	move.l	#HyResEnd-HyResText,d3
	ELSE
	moveq	#HyResEnd-HyResText,d3
	ENDC
	jsr	dosWrite(a6)
	move.l	d4,d1
	jsr	dosClose(a6)
.x:	rts
.hex8:	moveq	#7,d1
.h:	rol.l	#4,d0
	move.b	d0,d2
	and.w	#15,d2
	move.b	.hex(pc,d2.w),(a0)+
	dbra	d1,.h
	rts
.hex:	dc.b	"0123456789abcdef"
	ENDC

	IFD	IDL_STAT		; test: the poll-loop skip's counters (idl_cnt) for the result file
HyStatOut:
	lea	HyResStat,a0
	lea	idl_cnt,a1
	moveq	#7,d3
.st:	move.l	(a1)+,d0
	moveq	#7,d1
.h:	rol.l	#4,d0
	move.b	d0,d2
	and.w	#15,d2
	cmp.b	#10,d2
	bcs.s	.d
	addq.b	#7,d2
.d:	add.b	#"0",d2
	move.b	d2,(a0)+
	dbra	d1,.h
	addq.l	#1,a0
	dbra	d3,.st
	rts
	ENDC

; ---- point Wzonka's write table at our handlers
HyPatchWrites:
	move.l	gb_mem_jumps,a0
	lea	$8000*4(a0),a1		; tile data $8000-$97FF: dirty marks
	move.l	#hy_wvram,d0
	move.w	#$1800-1,d1
.v:	move.l	d0,(a1)+
	dbra	d1,.v
	lea	$ff40*4(a0),a1
	move.l	#hy_w40,(a1)
	move.l	#hy_w42,$2*4(a1)
	move.l	#hy_w43,$3*4(a1)
	IFND	NO_LINEPAL
	jsr	HyPalPatch		; hy_w47 and the sprite palettes (linepal.s); the
	nop				; same 8 bytes
	ELSE
	move.l	#hy_w47,$7*4(a1)
	ENDC
	move.l	#hy_w4a,$a*4(a1)
	move.l	#hy_w4b,$b*4(a1)
	IFND	NO_SOUND		; sound registers $FF10-$FF26, wave RAM $FF30-$FF3F
	lea	$ff10*4(a0),a1
	lea	HySndTab,a2
	moveq	#$27-$10-1,d1
.s:	move.l	(a2)+,d0
	beq.s	.k
	move.l	d0,(a1)
.k:	addq.l	#4,a1
	dbra	d1,.s
	lea	$ff30*4(a0),a1
	move.l	#hy_wave,d0
	moveq	#16-1,d1
.w:	move.l	d0,(a1)+
	dbra	d1,.w
	ENDC
	IFD	NO_SOUND
	IFND	NO_SNDREGS
	bsr.w	snd_regs_install	; no sound: registers stored all the same (gb_extra.s)
	ENDC
	ENDC
	rts

	include	"glue.s"
	IFND	NO_CD32
	include	"cd32pad.s"
	IFND	NO_PADMAP
	include	"padcfg.s"
	ENDC
	ENDC
	IFND	NO_LINEPAL
	include	"linepal.s"
	ENDC
	IFD	HY_BEZHOOK
	include	"bezel.s"
	ENDC
	IFND	NO_SOUND
	include	"sound.s"
	IFD	HY_MENU
	SECTION	hysnddata,DATA
	cnop	0,4
HySndEnd:				; end of the sound state (menu.s keeps a copy)
	ENDC
	SECTION	hybrid,CODE
	ENDC

; ---- stubs for Wzonka parts the hybrid leaves out (front end, drawing, sound)
inputs_read:
runtime_gbs_save:
runtime_gbs_load:
screen_draw:
scanline_draw:
	rts
	IFND	NO_SOUND
snd_high_do:				; per line: frame sequencer step every 8192 T-cycles
	sub.w	#456,HySndSeq
	bpl.w	snd_high_back
	add.w	#8192,HySndSeq
	bsr.w	HySndStep
	bra.w	snd_high_back
	ELSE
snd_high_do:	bra.w	snd_high_back
	ENDC
sfx_update_all:	bra.w	sfx_back
load_error_unknown_size:
	moveq	#2,d0
	rts

	include	"wz_engine.s"
	IFD	HY_MENU
	SECTION	wzdata,DATA
	cnop	0,4
HyWzEnd:				; end of the engine state (menu.s keeps a copy)
	ENDC
	SECTION	hybrid,CODE		; wz_engine.s ends in its data section
	include	"gb_extra.s"
	include	"z80_misc.s"
	include	"z80_full_III.s"
	IFD	HY_GBC
	include	"gbc.s"
	ENDC
	IFD	GBC_RENDER
	include	"gbc_line.s"
	ENDC
	IFD	GBC_RTG
	include	"gbc_rtg.s"
	ENDC

	SECTION	hybrid,CODE
; Juan's data block: offsets from Regs (A3), some negative (UltCopLin, IntGB1Ant)
	cnop	0,8
	ds.b	$100
Regs:	ds.b	$1000+$200
	include	"juan_video.s"

	SECTION	hybriddata,DATA
exec_base:	dc.l	0
HyDosBase:	dc.l	0
HySP:		dc.l	0
	IFND	NO_WBSTART
HyWBMsg:	dc.l	0			; Workbench start-up message (0 from the Shell)
	ENDC
HyFrames:	dc.l	-1			; Game Boy frames shown (the first build is at the hand-over)
file_length:	dc.l	0
HyVblN:		dc.l	0			; Amiga VBLs
HyVblSeen:	dc.l	0
HyCreditF:	dc.l	0			; Game Boy frames of time in hand, 16.16
HySkipped:	dc.l	0			; pictures skipped
HySkipRun:	dc.b	0
	even
	IFND	NO_SOUND
	IFND	NO_SNDPACE
HyVblDrawn:	dc.l	0			; HyVblN when the last picture was drawn
	ENDC
	ENDC
HyBuildMax:	dc.l	0
HyBuildSum:	dc.l	0
	IFD	HY_IDLE
HyIdle0:	dc.l	0
HyIdleSum:	dc.l	0			; beam lines waited before drawing
	ENDC
	even
	IFND	NO_OBJMASK
HyObjN:		dc.w	0			; bytes used in HyObjEv
HyObjEv:	ds.b	HY_OBJEVS*2		; line, LCDC for each sprite on/off switch
HyObj0:		dc.b	0			; LCDC at line 0
	even
	ENDC
HyDosName:	dc.b	"dos.library",0
	IFD	HY_FRAMELOG
HyFLogName:	dc.b	"RAM:AmiGB.prof",0
	even
HyFLogN:	dc.l	0
	SECTION	hybridbss,BSS
HyFLog:		ds.l	HY_FRAMELOG
	SECTION	hybriddata,DATA
	ENDC
HyResName:	dc.b	"RAM:AmiGB.result",0
HyResText:	dc.b	"frames="
HyResNum:	dc.b	"00000000 skipped="
HyResSkip:	dc.b	"00000000 vbls="
HyResVbl:	dc.b	"00000000"
	IFD	HY_PROF
	dc.b	" buildmax="
HyResBMax:	dc.b	"00000000 buildsum="
HyResBSum:	dc.b	"00000000"
	ENDC
	IFD	HY_IDLE
	dc.b	" idle="
HyResIdle:	dc.b	"00000000"
	ENDC
	IFD	IDL_STAT
	dc.b	" idl="
HyResStat:	dc.b	"00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000"
	ENDC
	dc.b	10
HyResEnd:
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

	SECTION	hybridbss,BSS
	cnop	0,8
GBMEM:	ds.b	$10000			; Game Boy address space (Wzonka's gb_memory)
VRAM	=GBMEM+$8000			; Juan's names for parts of it
RRAM	=GBMEM+$E000

	IFD	HY_MENU
	SECTION	hybridbss,BSS
	cnop	0,4
HySnapWz:	ds.b	HyWzEnd-z80_cycles	; state as at start (menu.s)
	IFND	NO_SOUND
HySnapSnd:	ds.b	HySndEnd-HyCh1
	ENDC
HySnapRegs:	ds.b	$1300
	ELSE
	SECTION	EmbedRom,DATA
	cnop	0,4
EmbedCart:	INCBIN	"../../build/hybrid_rom.bin"
EmbedCartEnd:
	ENDC

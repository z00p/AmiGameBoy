; AmiGameBoy hybrid: Juan's menu in front of Wzonka's engine (docs/design-hybrid.md 8).
; Copyright (C) 2026 AmiGameBoy contributors. GPL-2 (see src/engine/COPYING). The menu
; itself (AmiGameBoy_Menu.asm, GadToolsBox/) is Juan's, unchanged but for two IFD HY_MENU
; hooks (HyAutoStart, the requester skip in Insert).
;
;   sh build.sh hymenu [out]          one program, no cartridge inside
;   AmiGameBoy [ROM]                  from the Shell; or a ROM project icon with
;                                     AmiGameBoy as its default tool
;
; Juan's menu loads the cartridge (ASL requester, xpk/StoneCracker, the .sav battery
; file, prefs). Power On and Continue call GameBoyEmul, which here starts the engine on a
; stack of its own or picks it up where it was. Esc (or a CD32 shoulder + Play) pauses:
; the engine's place is kept on that stack and the menu comes back; Continue carries on.
; Juan's cartridge buffer keeps pages of $80 + $4000 bytes; the engine gets a flat copy.
; Battery RAM: Juan's ERAM0-3 (4 x 8 KB, the .sav file) <-> the engine's memory_banks,
; on each start and pause. HY_SAVE128: MBC5 carts with 64/128 KB, banks 4-15 in ERAMX
; (save128.s).
; Not wired yet: monitor/debugger, cheats, frozen games (Juan's Z80 state), the joystick
; type gadget (joystick + CD32 pad + keyboard always), Game Boy Color-only carts.
; Colour build (HY_GBC GBC_RENDER GBC_RTG, GBC_DMG implied): every cart on the RTG screen through
; the chunky renderer, Colour carts in CGB mode, mono ones with the DMG rules; the colour state
; (gbcdata, gbc_install, gbc_line_init) and the screen are set up again at each Power On; the
; screen is closed at each pause and opened again by Continue. No screen: an error box.
; GBC_AGA instead of GBC_RTG (no GBC_DMG): Colour carts in colour on the native AGA display (the
; chunky renderer + c2p, gbc_aga.s), set up at each Power On and Continue; mono carts on Juan's
; display as in 1.0.
;
; Test switches (WinUAE): HY_PAUSEAT=n pauses at frame n as Esc would; HY_MENUTEST=1
; Continues after the first pause; HY_MENUTEST=2: AmiGameBoy ROM1 ROM2 powers ROM1 on,
; at the pause inserts ROM2, powers it on, Continues after its pause. With HY_HOLD the
; grabs compare with the cartridge-inside build. HY_MENUTEST=3: as 1, saving the battery
; file (ROM name .sav) at the pause; HY_MENUTEST=4: as 3, the file written even when the
; battery RAM did not change (Juan's SaveBatt skips that). HY_MENUPIC (with AutoExit,
; GBC_RENDER): the last picture to GB:AmiGB.prof and the result to GB:AmiGB.result when
; AutoExit stops the engine.
; HY_LUPA: the launch words and return codes of the shared launch contract (lupa.s).

	IFND	HY_MENUTEST
HY_MENUTEST	=0
	ENDC
HY_ENGSTACK	=16384			; the engine's own stack
	IFND	NO_CD32
	IFND	NO_PADMAP
HY_PADCFG	=1			; the pad settings file (padcfg.s)
	ENDC
	ENDC
	IFND	NO_ASLPAT
HY_ASLPAT	=1			; the Insert requester lists cartridges and drawers only
	ENDC
	IFND	NO_CARTINFO
HY_CARTINFO	=1			; the info panel's mapper/ROM/RAM from the header (cartinfo.s)
	ENDC
HY_VBLNTSC	=65428			; Game Boy frames per NTSC VBL, 16.16 (59.7275 / 59.826)
NameFromLock	=-402
AddPart		=-882

Start:	movem.l	d2-d7/a2-a6,-(sp)
	move.l	sp,HySP
	move.l	a0,a2
	move.l	d0,d2
	move.l	4.w,a6
	sub.l	a1,a1
	jsr	-294(a6)		; FindTask
	move.l	d0,a1
	tst.l	$ac(a1)			; pr_CLI: from the Shell, a0/d0 are the arguments
	beq.s	.wb
	move.l	a2,a0
	move.l	d2,d0
	IFD	HY_LUPA
	jsr	LupaArgs		; -> HyArgPath, the launch words (lupa.s)
	ELSE
	bsr.w	HyArgs			; -> HyArgPath
	ENDC
.wb:
	move.l	4.w,a6
	move.l	a6,exec_base
	lea	HyDosName,a1
	moveq	#36,d0
	jsr	OpenLibrary(a6)
	move.l	d0,HyDosBase
	beq.w	.nomem
	move.l	#GBMEM,gb_memory
	move.l	#$40000,d0
	jsr	HyAlloc
	move.l	d0,gb_mem_jumps
	beq.w	.nomem
	move.l	#131072+$2000,d0
	jsr	HyAlloc
	move.l	d0,memory_banks
	beq.w	.nomem
	jsr	InitSistema
	jsr	HyMenuSnap		; engine, sound, renderer state as at start
	jsr	HyMenuTitles		; the 1.0 titles, then HyMenuAbout
	IFD	GBC_RTGMENU
	jsr	gbc_rtg_menumode	; the menu screen on the RTG board (gbc_rtg.s)
	ENDC
.menu:	bsr.w	GB_Menu			; Juan's menu, until Quit
	IFD	HY_LUPA
	move.l	LupaRC,d0		; the return code (lupa.s)
	ELSE
	moveq	#0,d0
	ENDC
	move.l	d0,-(sp)
	jsr	HyCartFree
	move.l	gb_mem_jumps,d0
	move.l	#$40000,d1
	jsr	HyFree
	move.l	memory_banks,d0
	move.l	#131072+$2000,d1
	jsr	HyFree
	move.l	4.w,a6
	move.l	HyDosBase,d0
	beq.s	.nodos
	move.l	d0,a1
	jsr	CloseLibrary(a6)
.nodos:	move.l	(sp)+,d0
	move.l	HySP,sp
	movem.l	(sp)+,d2-d7/a2-a6
	rts
.nomem:	moveq	#0,d0			; out of memory before the menu: the menu still
	move.l	d0,gb_mem_jumps		; runs (it takes the Workbench message) and Power
	bra.s	.menu			; On says so

; Shell arguments (a0, d0 characters): first -> HyArgPath, second (HY_MENUTEST=2)
; -> HyArgPath2; a word or "quoted", at most 255 characters
HyArgs:	lea	HyArgPath,a1
	bsr.s	.word
	IFEQ	HY_MENUTEST-2
	lea	HyArgPath2,a1
	bsr.s	.word
	ENDC
	rts
.word:	move.w	#255,d3
.sp:	subq.l	#1,d0
	bmi.s	.end
	move.b	(a0)+,d1
	cmp.b	#" ",d1
	bls.s	.sp
	moveq	#" ",d2			; end character
	cmp.b	#'"',d1
	bne.s	.put
	move.b	d1,d2
.c:	subq.l	#1,d0
	bmi.s	.end
	move.b	(a0)+,d1
	cmp.b	d2,d1
	beq.s	.end
	cmp.b	#" ",d1
	bcs.s	.end			; LF at the end of the line
.put:	move.b	d1,(a1)+
	subq.w	#1,d3
	bne.s	.c
.end:	clr.b	(a1)
	rts

; ---- About: the engine's authors beside Juan (his IntuiTexts, re-pointed; the menu
; centres them at start)
HyMenuAbout:
	lea	.list(pc),a0
.n:	move.l	(a0)+,d0
	beq.s	.x
	move.l	d0,a1
	move.l	(a0)+,12(a1)		; it_IText
	bra.s	.n
.x:	rts
.list:	dc.l	AboutText0,HyAb0,AboutText1,HyAb1,AboutText2,HyAb2
	dc.l	AboutText4,HyAb4,AboutText5,HyAb5,AboutText6,HyAb6
	dc.l	AboutText7,HyAb7,AboutText8,HyAb8,0

; ---- after the main window opens (hook in Juan's Programa): a ROM named on the
; command line or by a project icon is inserted and powered on
HyAutoStart:
	movem.l	d0-d7/a0-a6,-(sp)
	IFD	HY_ASLTEST		; test: the Insert requester at once (grabs)
	jsr	Insert
	ENDC
	IFD	HY_LUPA
	jsr	LupaPrep		; ToolTypes, the display word; Z clear: no start (lupa.s)
	bne.w	.x
	ENDC
	tst.b	HyArgPath
	bne.s	.have
	move.l	MENSWB,d0		; Workbench start-up message
	beq.w	.x
	move.l	d0,a2
	cmp.l	#2,$1c(a2)		; sm_NumArgs: the tool and a project
	bcs.w	.x
	move.l	$24(a2),a2		; sm_ArgList
	addq.l	#8,a2			; the project: wa_Lock, wa_Name
	move.l	(a2),d1
	beq.w	.x
	move.l	#HyArgPath,d2
	move.l	#256,d3
	move.l	HyDosBase,a6
	jsr	NameFromLock(a6)
	tst.l	d0
	beq.w	.x
	move.l	#HyArgPath,d1
	move.l	4(a2),d2
	move.l	#256,d3
	jsr	AddPart(a6)
	tst.l	d0
	beq.w	.x
.have:
	IFD	HY_LUPA
	jsr	LupaInsert		; Z set: no Power On (MENU, a load error)
	ELSE
	bsr.s	HyAutoInsert
	ENDC
	beq.w	.x
	jsr	PowerON
	IFD	HY_LUPA
	jsr	LupaAfter		; ONEGAME: the program quits now
	ENDC
	IFNE	HY_MENUTEST
	IFEQ	HY_MENUTEST-2
	lea	HyArgPath2,a0		; test: a second cartridge after the pause
	lea	HyArgPath,a1
.cp:	move.b	(a0)+,(a1)+
	bne.s	.cp
	bsr.s	HyAutoInsert
	beq.w	.x
	jsr	PowerON
	ENDC
	IFEQ	HY_MENUTEST-3
	jsr	SaveBatt		; test: battery file at the pause
	ENDC
	IFEQ	HY_MENUTEST-4
	jsr	CalChecksum		; test: battery file at the pause, written even unchanged
	not.l	d2			; (SaveBatt writes when the sum differs from CheckId)
	move.l	d2,CheckId
	jsr	SaveBatt
	ENDC
	jsr	Continue
	ENDC
.x:	movem.l	(sp)+,d0-d7/a0-a6
	rts

; Juan's Insert with HyArgPath for the requester's answer -> Z clear if a cartridge is in
HyAutoInsert:
	move.l	InsReqBase,-(sp)
	move.l	#HyFakeReq,InsReqBase
	move.l	#HyFakeReq,HyAutoReq	; Insert skips RequestFile
	jsr	Insert
	clr.l	HyAutoReq
	move.l	(sp)+,InsReqBase
	clr.b	HyArgPath
	tst.l	BucCart
	rts

GB_Menu:
	include	"AmiGameBoy_Menu.asm"
; Juan's GameBoyEmul (end of the menu) falls through here: d7 = 0 Power On, -1 Continue

; ---- start or resume the engine; back here (rts) on Esc or when it stops
HyMenuEmul:
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	sp,HyMenuSP
	tst.l	d7
	bpl.s	.power
	tst.l	HyEngSP			; Continue: only the same cartridge, if it ran
	beq.s	.power
	move.l	DirCart,d0
	cmp.l	HyCartSrc,d0
	bne.s	.power
	bsr.w	HyMenuPrefs
	bsr.w	HyBattIn
	lea	Regs,a3
	move.l	#-1,EstadoKeys(a3)
	IFD	GBC_RTG			; the RTG screen again (closed at the pause)
	bsr.w	HyRtgOpen
	beq.w	.rtgerr			; none: back to the menu, Continue can be tried again
	ENDC
	IFD	HY_LUPA
	jsr	LupaSettle		; no key or button held at the takeover (lupa.s)
	ENDC
	jsr	CongelaAMIGA
	IFD	GBC_RTG
	bsr.w	HyRtgDma
	ENDC
	IFD	GBC_AGA			; a colour cart: the AGA colour display (gbc_aga.s)
	jsr	gbc_aga_on
	ENDC
	IFND	NO_SOUND
	move.w	#$800f,$dff096		; voices on again (Paula kept their samples and
	bsr.w	HySndAllVol		; periods), volumes back
	ENDC
	bsr.w	HyMenuPace
	move.w	#$7fff,$dff09c
	move.w	#$c020,$dff09a
	move.l	HyEngSP,sp
	movem.l	(sp)+,d0-d7/a0-a6
	rts				; back into the engine (hybrid_frame)

.power:	clr.l	HyEngSP
	tst.l	gb_mem_jumps
	beq.w	.nomem
	tst.l	memory_banks
	beq.w	.nomem
	move.l	DirCart,a0
	lea	$80(a0),a0		; page 0
	IFND	HY_GBC			; (HY_GBC: Colour-only carts run in CGB mode)
	lea	tHyErrCGB,a1
	cmp.b	#$c0,$143(a0)		; Game Boy Color only
	beq.w	.err
	ENDC
	lea	tHyErrType,a1
	move.b	$147(a0),d0		; Wzonka's mapper list has types 0-$1E and $FF
	cmp.b	#$ff,d0
	beq.s	.typeok
	cmp.b	#$1e,d0
	bhi.w	.err
.typeok:
	bsr.w	HyMenuRestore		; engine, sound, renderer state as at start
	bsr.w	HyCartLoad		; flat copy + ROM image space
	beq.w	.nomem

; header: bank masks and MBC3 flag (as the cartridge-inside Start)
	move.l	HyFlat,a0
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
.nomb3:	move.l	HyFlatLen,file_length
	move.l	HyFlat,cartridge_data
	move.l	HyRom32,rom_32k
	bsr.w	gg_patch_apply		; ROM images (Wzonka)
	tst.l	d0
	bne.w	.nomem
	move.l	cartridge,a0
	bsr.w	compute_jmp_lst		; write table (Wzonka)
	bsr.w	HyPatchWrites		; our handlers for the renderer and sound
	IFD	HY_GBC			; Game Boy Color: CGB registers (gbc.s; its state was put
	move.l	gb_mem_jumps,a0		; back by HyMenuRestore), the line renderer, for each
	jsr	gbc_install		; Power On
	IFD	GBC_RENDER
	jsr	gbc_line_init
	sf	gbc_lineoff
	ENDC
	IFD	GBC_AGA			; the colour display's lists, planes and pens afresh
	jsr	gbc_aga_init
	ENDC
	ENDC
	IFD	SGB_PKT			; Super Game Boy carts (sgb.s), as the option is now
	move.l	gb_mem_jumps,a0
	jsr	sgb_install
	ENDC
	IFND	NO_SOUND
	clr.b	snd_quality
	ELSE
	move.b	#1,snd_quality
	ENDC
	move.b	#1,old_refresh
	move.b	#$ff,refresh_scanline
	clr.b	input_status

	lea	GBMEM,a0		; Game Boy memory clear, then the battery banks
	move.w	#$10000/16-1,d0
.clr:	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)+
	dbra	d0,.clr
	bsr.w	HyBattIn

; Juan's set-up with the menu's prefs
	bsr.w	HyMenuPrefs
	lea	Regs,a3
	move.l	#-1,EstadoJoy(a3)
	move.l	#-1,EstadoKeys(a3)
	lea	Regs+TabRedef,a0	; every tile redrawn (the last cartridge's are cached)
	move.w	#$180/4-1,d0
.dirty:	move.l	#-1,(a0)+
	dbra	d0,.dirty
	lea	Sprit0,a0
	move.w	#(OTRSPR*4/4)-1,d0
	jsr	BorraMem
	lea	SprGfx0Fast,a0
	move.w	#(OTRSPR*4/4)-1,d0
	jsr	BorraMem
	move.l	#-1,HyFrames
	clr.l	HySkipped
	IFND	NO_OBJMASK
	clr.w	HyObjN
	ENDC
	move.l	DirCart,HyCartSrc

	move.l	4.w,a6
	jsr	CacheClearU(a6)
	IFD	GBC_RTG			; the 16-bit Picasso96 screen (gbc_rtg.s), OS alive
	bsr.w	HyRtgOpen
	beq.w	.nortg
	ENDC
	IFD	HY_LUPA
	jsr	LupaSettle		; no key or button held at the takeover (lupa.s)
	ENDC
	jsr	CongelaAMIGA
	IFD	GBC_RTG
	bsr.w	HyRtgDma
	ENDC
	IFD	GBC_AGA			; a colour cart: the AGA colour display (gbc_aga.s)
	jsr	gbc_aga_on
	ENDC
	IFND	NO_SOUND
	bsr.w	HySndInit
	ENDC
	bsr.w	HyMenuPace
	move.w	#$7fff,$dff09c
	move.w	#$c020,$dff09a		; VBL only
	lea	HyEngStack+HY_ENGSTACK,sp
	bra.w	run_cartridge		; Esc -> HyMenuPause, stop -> HyMenuExit

	IFD	GBC_RTG
.nortg:	clr.l	HyEngSP
.rtgerr:
	lea	tHyErrRtg,a1
	bra.s	.err
	ENDC
.nomem:	lea	tErOutOfMem,a1
.err:	move.l	a1,a0
	jsr	ImpError
	bra.s	HyMenuBack

; ---- Esc in hybrid_frame (its registers on the engine stack, then the way back in)
HyMenuPause:
	sf	SalirMenu(a3)
	move.l	sp,HyEngSP
	bra.s	HyMenuLeave
; ---- the engine stopped (z80_halted, AutoExit): no Continue
HyMenuExit:
	clr.l	HyEngSP
HyMenuLeave:
	move.l	HyMenuSP,sp
	IFND	NO_SOUND
	bsr.w	HySndStop
	ENDC
	jsr	DescongelaAMIGA
	IFD	GBC_RTG
	jsr	gbc_rtg_close		; the menu's screen back
	ENDC
	IFD	HY_LUPA
	jsr	LupaSettle		; and the keys up again before the OS reads them (lupa.s)
	ENDC
	IFD	HY_MENUPIC		; test: at AutoExit the last picture to GB:AmiGB.prof,
	IFNE	AutoExit		; then GB:AmiGB.result (uaerun --until)
	tst.l	HyEngSP
	bne.s	.nopic
	IFD	GBC_RENDER
	jsr	GbcFbSave
	ENDC
	IFD	SGB_DUMP
	jsr	sgb_dump
	ENDC
	jsr	HyResult
.nopic:
	ENDC
	ENDC
	IFD	HY_SAVE128		; (HyBattIn grew)
	bsr.w	HyBattOut
	ELSE
	bsr.s	HyBattOut
	ENDC
HyMenuBack:
	move.l	HyMenuSP,sp
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; ---- pacing from now: no catching up on the time spent in the menu; PAL or NTSC rate
HyMenuPace:
	move.l	HyVblN,HyVblSeen
	clr.l	HyCreditF
	sf	HySkipRun
	rts

; ---- battery RAM: Juan's ERAM0-3 -> memory_banks 0-3, the live bank -> $A000
HyBattIn:
	movem.l	d0/a0-a1,-(sp)
	move.l	memory_banks,a1
	lea	ERAM0,a0
	bsr.s	HyBank
	lea	ERAM1,a0
	bsr.s	HyBank
	lea	ERAM2,a0
	bsr.s	HyBank
	lea	ERAM3,a0
	bsr.s	HyBank
	IFD	HY_SAVE128		; 64/128 KB carts: ERAMX -> banks 4-15 (save128.s)
	jsr	HySaveIn
	ENDC
	move.l	ram_bank_no,d0
	mulu.l	#$2000,d0
	move.l	memory_banks,a0
	add.l	d0,a0
	lea	GBMEM+$a000,a1
	bsr.s	HyBank
	movem.l	(sp)+,d0/a0-a1
	rts
HyBank:	move.w	#$2000/4-1,d0		; 8 KB a0 -> a1
.c:	move.l	(a0)+,(a1)+
	dbra	d0,.c
	rts

; ---- and back: $A000 -> its bank, memory_banks 0-3 -> ERAM0-3 (the menu saves them)
HyBattOut:
	movem.l	d0/a0-a1,-(sp)
	move.l	ram_bank_no,d0
	mulu.l	#$2000,d0
	move.l	memory_banks,a1
	add.l	d0,a1
	lea	GBMEM+$a000,a0
	bsr.s	HyBank
	move.l	memory_banks,a0
	lea	ERAM0,a1
	bsr.s	HyBank
	lea	ERAM1,a1
	bsr.s	HyBank
	lea	ERAM2,a1
	bsr.s	HyBank
	lea	ERAM3,a1
	bsr.s	HyBank
	IFD	HY_SAVE128		; 64/128 KB carts: banks 4-15 -> ERAMX (save128.s)
	jsr	HySaveOut
	ENDC
	movem.l	(sp)+,d0/a0-a1
	rts

; ---- battery size, from Juan's Insert (a0 = DirCart): MBC2 carts (types 5, 6) say no RAM
; in $149 (512 x 4 bits sit in the mapper, at $A000-$A1FF), so Juan's menu saved nothing;
; take the 2 KB size (ERAM0 start). All registers kept.
	IFND	NO_MBC2SAVE
HyBattKbs:
	move.l	d0,-(sp)
	move.b	$80+$147(a0),d0
	IFD	HY_SAVE128		; MBC5 with 64/128 KB: BattKbs 5/4 (save128.s)
	jsr	HySaveKbs
	ENDC
	cmp.b	#5,d0
	beq.s	.mbc2
	cmp.b	#6,d0
	bne.s	.x
.mbc2:	tst.b	BattKbs
	bne.s	.x
	move.b	#1,BattKbs
.x:	move.l	(sp)+,d0
	rts
	ENDC

; ---- prefs from the menu: palette, black border, PAL/NTSC game speed
HyMenuPrefs:
	lea	DirPrefs,a5
	move.l	#LeeJoyStick,JoyControlRut	; joystick (+ CD32 pad, keyboard)
	move.b	$09(a5),d0
	bfins	d0,BpCon3{$1a:1}	; black border
	move.b	$11(a5),d0
	and.w	#7,d0
	move.l	.pal(pc,d0.w*4),a0
	IFD	HY_BEZHOOK		; (the same 6 bytes) that move, then tint and bezel
	jsr	HyBezPrefs		; (bezel.s)
	ELSE
	move.l	(a0)+,GBPaleta
	ENDC
	move.l	(a0),GBPaleta+4
	IFD	HY_TESTPAL
	move.l	#$0f0000f0,GBPaleta
	move.l	#$000f0000,GBPaleta+4
	ENDC
	move.l	#HY_VBLFRAMES,HyVblRate
	tst.b	$0f(a5)			; screen mode: 0 = PAL (the menu sets BEAMCON0)
	beq.s	.x
	move.l	#HY_VBLNTSC,HyVblRate
.x:	rts
.pal:	dc.l	PaletaGrey,PaletaGreen,PaletaBlue,PaletaRed
	dc.l	PaletaOrange,PaletaOrange,PaletaOrange,PaletaOrange

; ---- Juan's cartridge buffer -> flat copy (HyFlat) and ROM image space (HyRom32);
; Z set if out of memory. Carts under 32 KB are padded to 32 KB (gg_patch_apply).
HyCartLoad:
	bsr.s	HyCartFree
	moveq	#0,d0
	move.w	PagCart,d0
	cmp.w	#2,d0
	bcc.s	.sz
	moveq	#2,d0
.sz:	moveq	#14,d1
	lsl.l	d1,d0			; x $4000
	move.l	d0,HyFlatLen
	jsr	HyAlloc
	move.l	d0,HyFlat
	beq.s	.x
	move.l	HyFlatLen,d0
	add.l	d0,d0
	jsr	HyAlloc
	move.l	d0,HyRom32
	beq.s	.x
	move.l	DirCart,a0
	lea	$80(a0),a0
	move.l	HyFlat,a1
	move.w	PagCart,d1
	subq.w	#1,d1
.page:	move.w	#$4000/4-1,d0
.c:	move.l	(a0)+,(a1)+
	dbra	d0,.c
	lea	$80(a0),a0
	dbra	d1,.page
	moveq	#1,d0			; Z clear
.x:	rts

HyCartFree:
	move.l	HyFlat,d0
	move.l	HyFlatLen,d1
	jsr	HyFree
	move.l	HyRom32,d0
	move.l	HyFlatLen,d1
	add.l	d1,d1
	jsr	HyFree
	clr.l	HyFlat
	clr.l	HyRom32
	rts

	IFD	GBC_RTG
; ---- the RTG screen, OS alive (Power On and Continue; closed again at each pause, so the
; menu is in front). Z set: no 16-bit Picasso96 screen.
HyRtgOpen:
	sf	gbc_rdbuf		; (gbc_rtg_open only ever sets it)
	jsr	gbc_rtg_open
	tst.b	gbc_rtg_on
	rts
; ---- after CongelaAMIGA: nothing of the display from chip RAM (as the cartridge-inside Start)
HyRtgDma:
	move.w	#$01a0,$dff096		; BPLEN, COPEN, SPREN off
	move.w	#$0000,$dff180
	move.w	#$0200,$dff100
	rts
	ENDC

; ---- engine (wzdata), sound and renderer (Regs) state: kept at start, put back at
; each Power On
HyMenuSnap:
	lea	HySnapList(pc),a2
.n:	move.l	(a2)+,d0
	beq.s	.x
	move.l	d0,a0
	move.l	(a2)+,a1
	move.l	(a2)+,d0
	lsr.l	#2,d0
	subq.l	#1,d0
.c:	move.l	(a0)+,(a1)+
	subq.l	#1,d0
	bpl.s	.c
	bra.s	.n
.x:	rts
HyMenuRestore:
	lea	HySnapList(pc),a2
.n:	move.l	(a2)+,d0
	beq.s	.x
	move.l	d0,a1
	move.l	(a2)+,a0
	move.l	(a2)+,d0
	lsr.l	#2,d0
	subq.l	#1,d0
.c:	move.l	(a0)+,(a1)+
	subq.l	#1,d0
	bpl.s	.c
	bra.s	.n
.x:	rts
HySnapList:
	dc.l	z80_cycles,HySnapWz,HyWzEnd-z80_cycles
	IFND	NO_SOUND
	dc.l	HyCh1,HySnapSnd,HySndEnd-HyCh1
	ENDC
	dc.l	Regs-$100,HySnapRegs,$1300
	IFD	HY_GBC			; the colour engine's variables (gbc.s)
	dc.l	gbc_dstart,HySnapGbc,(gbc_dend-gbc_dstart+3)&-4
	ENDC
	dc.l	0

	SECTION	hybriddata,DATA
HyMenuSP:	dc.l	0			; the menu's stack in GameBoyEmul
HyEngSP:	dc.l	0			; the engine's, paused (0: nothing to continue)
HyCartSrc:	dc.l	0			; DirCart of the running cartridge
HyFlat:		dc.l	0
HyFlatLen:	dc.l	0
HyRom32:	dc.l	0
HyAutoReq:	dc.l	0
HyVblRate:	dc.l	HY_VBLFRAMES
HyFakeReq:	dc.l	0,HyArgPath,HyNoDir	; fr_File, fr_Drawer for Juan's ArreglaNom
HyNoDir:	dc.b	0
tHyErrCGB:	dc.b	4,"Game Boy Color only",0,"Not supported yet",0
tHyErrType:	dc.b	4,"Unknown cartridge type",0,"Not supported yet",0
	IFD	GBC_RTG
tHyErrRtg:	dc.b	4,"No RTG screen",0,"Needs a 16-bit Picasso96 mode",0
	ENDC
	IFD	HY_REL23		; the 2.3 release (with HY_REL20 to HY_REL22)
HyAb0:		dc.b	"AmiGameBoy 2.3 community version",0
HyAb1:		dc.b	"(24 November 2026)",0
	ELSE
	IFD	HY_REL22		; the 2.2 release (with HY_REL20 and HY_REL21)
HyAb0:		dc.b	"AmiGameBoy 2.2 community version",0
HyAb1:		dc.b	"(19 November 2026)",0
	ELSE
	IFD	HY_REL21		; the 2.1 release (with HY_REL20 for the 2.0 text fixes)
HyAb0:		dc.b	"AmiGameBoy 2.1 community version",0
HyAb1:		dc.b	"(18 November 2026)",0
	ELSE
	IFD	HY_REL20		; the 2.0 release
HyAb0:		dc.b	"AmiGameBoy 2.0 community version",0
HyAb1:		dc.b	"(17 November 2026)",0
	ELSE
HyAb0:		dc.b	"AmiGameBoy 1.0 community version",0
HyAb1:		dc.b	"(14 November 2026)",0
	ENDC
	ENDC
	ENDC
	ENDC
HyAb2:		dc.b	"Menu and display:",0
HyAb4:		dc.b	"Game Boy engine (Wzonka-Lad):",0
	IFD	HY_CREDVH		; Wzonka-Lad is Ville Helin's (GitHub issue #7)
HyAb5:		dc.b	"Ville Helin",0
	ELSE
HyAb5:		dc.b	"Ville Helin, Ventzislav Tzvetkov",0
	ENDC
HyAb6:		dc.b	"Icons and Graphics: Multivac",0
HyAb7:		dc.b	"Community version: z00p",0
HyAb8:		dc.b	"GNU GPL v2, no warranty",0
	IFD	HY_REL23
HyWTitle:	dc.b	"AmiGameBoy 2.3",0
HySTitle:	dc.b	"AmiGameBoy 2.3"
	IFND	HY_CREDZ		; (the three authors need the room)
		dc.b	" community version"
	ENDC
	ELSE
	IFD	HY_REL22
HyWTitle:	dc.b	"AmiGameBoy 2.2",0
HySTitle:	dc.b	"AmiGameBoy 2.2"
	IFND	HY_CREDZ		; (the three authors need the room)
		dc.b	" community version"
	ENDC
	ELSE
	IFD	HY_REL21
HyWTitle:	dc.b	"AmiGameBoy 2.1",0
HySTitle:	dc.b	"AmiGameBoy 2.1"
	IFND	HY_CREDZ		; (the three authors need the room)
		dc.b	" community version"
	ENDC
	ELSE
	IFD	HY_REL20		; the 2.0 release
HyWTitle:	dc.b	"AmiGameBoy 2.0",0
HySTitle:	dc.b	"AmiGameBoy 2.0 community version"
	ELSE
HyWTitle:	dc.b	"AmiGameBoy 1.0",0
HySTitle:	dc.b	"AmiGameBoy 1.0 community version"
	ENDC
	ENDC
	ENDC
	ENDC
	IFD	HY_CREDZ		; Juan, Ville Helin and z00p credited alike
		dc.b	" ",$a9," 1997-2026 "
	ELSE
		dc.b	". ",$a9," 1997-2026 "
	ENDC
		dc.b	"Juan Antonio G",$f3,"mez G",$e1,"lvez"
	IFD	HY_CREDZ
		dc.b	", Ville Helin, z00p"
	ENDC
		dc.b	0
	even
	IFD	HY_ASLPAT
; Insert's RequestFile tags: a pattern gadget set to the cartridge names, so launcher
; scripts, saves and the rest are not listed (drawers always are; icons are rejected by
; Juan's AllocAslRequest tags). The pattern can be widened in the requester (a packed
; cartridge under another name); it is set again at each Insert. Then Juan's tags.
	SECTION	hyasldata,DATA
HyInsTags:
	IFD	HY_ASLWIDE		; (15 Nov: the size column was cut off) nearly the screen's width
	dc.l	$80080003,20		; ASLFR_InitialLeftEdge (Juan: 165)
	dc.l	$80080005,600		; ASLFR_InitialWidth (Juan: ASL's default)
	ENDC
		dc.l	$8008000a,HyInsPat	; ASLFR_InitialPattern
		dc.l	$8008002e,1		; ASLFR_DoPatterns
		dc.l	2,InsLoadTags		; TAG_MORE
HyInsPat:	dc.b	"#?.(gb|gbc|cgb)",0
	ENDC

; ---- 1.0: the main window's title and screen title (Juan's tags, re-pointed), then the
; About box. In a section of its own: nothing in the engine's section moves.
	SECTION	hytitle,CODE
HyMenuTitles:
	move.l	#HyWTitle,MainMenuWG+12
	move.l	#HySTitle,MainMenuWG+20
	jmp	HyMenuAbout
	SECTION	hybridbss,BSS
HyArgPath:	ds.b	256
	IFEQ	HY_MENUTEST-2
HyArgPath2:	ds.b	256
	ENDC
	cnop	0,4
HyEngStack:	ds.b	HY_ENGSTACK
	cnop	0,8			; Juan's battery RAM, laid out as in his program
	ds.b	$80
ERAM0:	ds.b	8*1024
	ds.b	$80
ERAM1:	ds.b	8*1024
	ds.b	$80
ERAM2:	ds.b	8*1024
	ds.b	$80
ERAM3:	ds.b	8*1024
	ds.b	$80
	SECTION	hybrid,CODE
	IFD	HY_SAVE128		; its hooks here and in Juan's menu add 52 bytes: 12 more make
	ds.b	12			; it 64, so the engine behind moves by whole cache lines
	ENDC
	IFD	HY_CARTINFO
	include	"cartinfo.s"
	ENDC
	IFD	HY_LUPA
	include	"lupa.s"
	ENDC

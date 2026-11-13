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
; on each start and pause.
; Not wired yet: monitor/debugger, cheats, frozen games (Juan's Z80 state), the joystick
; type gadget (joystick + CD32 pad + keyboard always), Game Boy Color-only carts.
;
; Test switches (WinUAE): HY_PAUSEAT=n pauses at frame n as Esc would; HY_MENUTEST=1
; Continues after the first pause; HY_MENUTEST=2: AmiGameBoy ROM1 ROM2 powers ROM1 on,
; at the pause inserts ROM2, powers it on, Continues after its pause. With HY_HOLD the
; grabs compare with the cartridge-inside build. HY_MENUTEST=3: as 1, saving the battery
; file (ROM name .sav) at the pause.

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
	bsr.w	HyArgs			; -> HyArgPath
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
.menu:	bsr.w	GB_Menu			; Juan's menu, until Quit
	moveq	#0,d0
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
.have:	bsr.s	HyAutoInsert
	beq.w	.x
	jsr	PowerON
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
	jsr	CongelaAMIGA
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
	lea	tHyErrCGB,a1
	cmp.b	#$c0,$143(a0)		; Game Boy Color only
	beq.w	.err
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
	jsr	CongelaAMIGA
	IFND	NO_SOUND
	bsr.w	HySndInit
	ENDC
	bsr.w	HyMenuPace
	move.w	#$7fff,$dff09c
	move.w	#$c020,$dff09a		; VBL only
	lea	HyEngStack+HY_ENGSTACK,sp
	bra.w	run_cartridge		; Esc -> HyMenuPause, stop -> HyMenuExit

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
	bsr.s	HyBattOut
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
	movem.l	(sp)+,d0/a0-a1
	rts

; ---- battery size, from Juan's Insert (a0 = DirCart): MBC2 carts (types 5, 6) say no RAM
; in $149 (512 x 4 bits sit in the mapper, at $A000-$A1FF), so Juan's menu saved nothing;
; take the 2 KB size (ERAM0 start). All registers kept.
	IFND	NO_MBC2SAVE
HyBattKbs:
	move.l	d0,-(sp)
	move.b	$80+$147(a0),d0
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
HyAb0:		dc.b	"AmiGameBoy 1.0 community version",0
HyAb1:		dc.b	"(14 November 2026)",0
HyAb2:		dc.b	"Menu and display:",0
HyAb4:		dc.b	"Game Boy engine (Wzonka-Lad):",0
HyAb5:		dc.b	"Ville Helin, Ventzislav Tzvetkov",0
HyAb6:		dc.b	"Icons and Graphics: Multivac",0
HyAb7:		dc.b	"Community version: z00p",0
HyAb8:		dc.b	"GNU GPL v2, no warranty",0
HyWTitle:	dc.b	"AmiGameBoy 1.0",0
HySTitle:	dc.b	"AmiGameBoy 1.0 community version. ",$a9," 1997-2026 "
		dc.b	"Juan Antonio G",$f3,"mez G",$e1,"lvez",0
	even
	IFD	HY_ASLPAT
; Insert's RequestFile tags: a pattern gadget set to the cartridge names, so launcher
; scripts, saves and the rest are not listed (drawers always are; icons are rejected by
; Juan's AllocAslRequest tags). The pattern can be widened in the requester (a packed
; cartridge under another name); it is set again at each Insert. Then Juan's tags.
	SECTION	hyasldata,DATA
HyInsTags:	dc.l	$8008000a,HyInsPat	; ASLFR_InitialPattern
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

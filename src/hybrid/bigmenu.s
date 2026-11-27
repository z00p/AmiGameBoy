; AmiGameBoy hybrid: the big RTG menu (GBC_BIGMENU; prototype, 24-25 Nov 2026).
; Copyright (C) 2026 AmiGameBoy contributors. GPL-2 (see src/engine/COPYING).
;
; Juan's menu opened in the output-sized P96 mode (1920x1080 or 1280x720) with rtgmenu.s
; (rtg-framework, MIT, branch menu; design: its docs/menu/DESIGN.md). Two shapes:
;   GBC_BIG43 (25 Nov): his 640x212 layout in a centred 4:3 area (1440x1080 / 960x720, plain dark
;	side borders), positions and sizes scaled by X 9/4, Y 9/2 at 1080 (X 3/2, Y 3 at 720);
;	frames, bevels and text drawn at the screen's own size, in a real font of that size:
;	GBC_BIGFONT = 1 our Pixel font (rmfont_18x36 / rmfont_12x24, tools/menufont.py in
;	rtg-framework, built in), 2 Smooth: LetterGothic from FONTS: through diskfont, else Pixel;
;	the logo and the icons as 2x4 (1x2 at 720) blocks centred in their scaled place.
;   whole numbers (24 Nov): X3/Y5 at 1080 (X3/Y4 with GBC_BIGFLAT), X2/Y3 at 720, a 24x40 (or
;	16x24) topaz built from the ROM's topaz 8 (agbbig.font), chunky bevels.
; Intuition and GadTools still draw and run everything; before Juan's SetupScreen this file makes
; his numbers and his font bigger: the screen tags (mode, size, depth), the 15 window tables, the
; 15 NewGadget tables, the IntuiText chains, the Centrar tables, the Insert requester's place and
; size, the font, scaled copies of the logo and the icons; the 74 GadToolsBox bevels go through
; RmnBevel (RmnPatchBevels).
; Hooks (AmiGameBoy_Menu.asm, under IFD GBC_BIGMENU): bm_init right after Juan's start-up code has
; taken the Workbench start-up message (label CLI:), Juan's four DrawImage calls go through
; bm_drawimage (which also draws the 4:3 side borders), Centrar takes bm_chw pixels a character,
; Quitar calls bm_exit.
; bm_init uses DOS (the config, the GBC_BIGDBG log, diskfont), so it must not run before that
; message is taken: started from an icon, the message waits on pr_MsgPort, DOS takes it for its
; packet reply and stops with alert 87000004 (AN_AsyncPkt). (24 Nov: the first prototype called
; bm_init from gbc_rtg_menumode, before GB_Menu; it crashed like this on the A1200 started from
; Workbench.)
; "Menu = Classic" in PROGDIR:AmiGameBoy.config, or no 1920x1080 / 1280x720 P96 mode, or a screen
; of it that cannot open: today's menu (the mode gbc_rtg_menumode found, which runs first), untouched.
; Switches: GBC_BIGSIZE = 0 (automatic: the Workbench's size if it is one of the two, else 1080,
; then 720), 1080 (then 720 when 1080 has no mode or its screen does not open: 2.5) or 720; GBC_BIG43 the 4:3 area (GBC_BIGFONT 1 Pixel, 2 Smooth), else whole numbers
; (GBC_BIGFLAT: Y one less, X3/Y4 at 1080).
; GBC_BIGLAYOUT (with GBC_BIG43; 25 Nov): the main window's layout changed when the menu is big
; (classic: Juan's): the Emulation Speed box gone (its slider, disabled in Juan's menu, becomes the
; Surround cycle), Control moved left to the Cartridge box's width, Screen Options two rows longer
; with Surround (Off / Bezel / Auto) and Scanlines (Off / On) cycles. Surround sets the two settings
; behind the Options menu's ticks: Off = no bezel, no Super Game Boy; Bezel = the bezel, Super Game
; Boy off; Auto = both (Super Game Boy games their own border and colours, the rest the bezel). The
; ticks follow (Super Game Boy on puts the bezel on; the bezel off puts Super Game Boy off), the
; config keeps its "Bezel" and "Super Game Boy" lines, and Super Game Boy without the bezel (an old
; config) reads as Auto. Hooks: GadToolsBox (an 11th gadget, bm_mmcnt), Juan's gadget and Options
; tables (AmiGameBoy_Menu.asm), gbc_rmsync (rmenu.s).
; GBC_JOYCFG (with GBC_BIGLAYOUT): Joy type remembered in AmiGameBoy.config as soon as it is picked
; ("Joy type = Amiga JoyStick | Keyboard Only | CD32 Joypad | Standard Joypad", written by rmenu.s
; gbc_rmsave with a comment above it the first time); at start that line wins over Juan's prefs
; byte (S:AmiGameBoy.prefs, Save Prefs unchanged). Big and classic menu alike. Hooks: Programa
; after LoadPrefs (bm_joyload), Juan's gadget table (bm_gjoy).
; GBC_BIGHIRES (with GBC_BIG43): the logo and the four Joy type pictures redrawn at the screen's
; resolution (rtg-framework tools/agbart, planar.py) instead of Juan's pixels in blocks.
; OS alive (start of the menu). Keeps every register.

; GBC_BIGDBG (test): PROGDIR:bigmenu.log rewritten (opened, written, closed) at every step, so the
; last step reached survives a crash. One line, hex: step, ModeID, width, height, depth, X scale
; (SXn << 16 | SXd), Y scale, font (high word: 0 topaz, 1 Pixel, 2 Smooth) and bevels found (low
; word), the Smooth font's tries (its width at height 50, the height asked; the width and height
; got). Steps: 0 bm_init entered, 1 config read, 2 libraries open, 3 mode found, 4 scales, 5 test
; screen opened and closed, 6 bevels counted, 7 font made, 8 tables scaled (the screen opens next),
; 10 the menu's first picture drawn (screen and window open), 20 Quit (screen closed); GBC_BIGLAYOUT:
; 30, 31, 32 the Surround and Scanlines gadgets being set (bm_lsync).
BMSTEP	MACRO
	IFD	GBC_BIGDBG
	move.l	#\1,bm_dbg
	jsr	bm_dbgw
	ENDC
	ENDM
	IFND	GBC_BIGSIZE
GBC_BIGSIZE	=0
	ENDC
	IFND	GBC_BIGFONT
GBC_BIGFONT	=1
	ENDC
	IFD	GBC_BIGLAYOUT
	IFND	GBC_BIG43
	FAIL	"GBC_BIGLAYOUT needs GBC_BIG43"
	ENDC
	IFND	SGB_MENU
	FAIL	"GBC_BIGLAYOUT needs SGB_MENU (and GBC_RMENU)"
	ENDC
	ENDC
	IFD	GBC_BIGHIRES
	IFND	GBC_BIG43
	FAIL	"GBC_BIGHIRES needs GBC_BIG43"
	ENDC
	ENDC
	IFD	GBC_JOYCFG
	IFND	GBC_BIGLAYOUT
	FAIL	"GBC_JOYCFG needs GBC_BIGLAYOUT"
	ENDC
	ENDC
BM_JOYDX	=217			; GBC_BIGLAYOUT: the Joy type picture's move left (Juan's pixels)
BM_DBGN		=10			; GBC_BIGDBG: longs in the log line
BM_BEVELS	=74			; GadToolsBox bevels in MainMenuRender .. PrefsRender
BM_WINS		=(PrefsHeight+2-MainMenuLeft)/8	; window Left/Top/Width/Height, contiguous
	IFNE	(PrefsHeight+2-MainMenuLeft)-BM_WINS*8
	FAIL	"window table not contiguous"
	ENDC

	SECTION	bigmcode,CODE
bm_init:
	movem.l	d0-d7/a0-a6,-(sp)
	sf	bm_on
	move.w	#8,bm_chw
	BMSTEP	0
	bsr	bm_config		; "Menu = Classic"?
	BMSTEP	1
	tst.b	bm_classic
	bne	.x
	move.l	4.w,a6
	lea	bm_gfxn(pc),a1
	moveq	#39,d0
	jsr	-552(a6)		; OpenLibrary
	move.l	d0,RmnGfx
	beq	.close
	lea	bm_intn(pc),a1
	moveq	#39,d0
	jsr	-552(a6)
	move.l	d0,RmnInt
	beq	.close
	lea	bm_p96n(pc),a1
	moveq	#2,d0
	jsr	-552(a6)
	move.l	d0,RmnP96
	beq	.close
	IFEQ	GBC_BIGFONT-2
	lea	bm_dfn(pc),a1		; diskfont: none is fine (the Pixel font then)
	moveq	#36,d0
	jsr	-552(a6)
	move.l	d0,RmnDisk
	ENDC
	BMSTEP	2
	move.l	#GBC_BIGSIZE,d0
	IFEQ	GBC_BIGSIZE-1080
.trysz:	move.l	d0,bm_want		; 1080, then 720 when 1080 has no mode or no screen
	ENDC
	jsr	RmnFind			; d0 ModeID, d1/d2 size, d3 depth
	movem.l	d0-d3,bm_mode
	tst.l	d0
	beq	.nosize
	BMSTEP	3
	move.w	#640,d4
	move.w	#212,d5
	IFD	GBC_BIG43
	moveq	#2,d6
	ELSE
	IFD	GBC_BIGFLAT
	moveq	#1,d6
	ELSE
	moveq	#0,d6
	ENDC
	ENDC
	jsr	RmnSetup
	tst.l	d0
	beq	.nosize
	BMSTEP	4
	movem.l	bm_mode,d0-d3
	jsr	RmnTryOpen		; enough board memory?
	tst.l	d0
	bne	.nosize
	BMSTEP	5
	lea	MainMenuRender,a0	; Juan's bevels where we expect them?
	lea	OpenPrefsWindow,a1
	move.l	#BM_BEVELS,d0
	moveq	#0,d1			; count only
	jsr	RmnPatchBevels
	IFD	GBC_BIGDBG
	move.w	d0,bm_dbg+4*7+2
	ENDC
	cmp.l	#BM_BEVELS,d0
	bne	.close
	BMSTEP	6
	bsr	bm_font			; the font: every topaz 8 of the menu is the big one
	tst.l	d0
	beq	.close
	BMSTEP	7
; from here on the menu is big
	st	bm_on
	IFD	GBC_BIG43
	bsr	bm_marks		; the menu's tick and Amiga key at the font's size
	ENDC
	IFD	GBC_BIGLAYOUT
	bsr	bm_layout		; Juan's numbers for the new layout (scaled below)
	ENDC
	moveq	#8,d0
	jsr	RmnScX
	move.w	d0,bm_chw		; Centrar's character width (the cell)
	move.w	RmnFontH,d0
	move.w	d0,bm_fy		; the font's height
	addq.w	#3,d0
	move.w	d0,RmnBar1		; window tops: under the big screen title bar
	move.w	#11,RmnBar0
	move.w	DriPens+6,RmnShine	; SHINEPEN, SHADOWPEN
	move.w	DriPens+8,RmnShadow
	movem.l	bm_mode,d0-d3		; the screen
	move.l	d1,ScreenTags+20	; SA_Width
	move.l	d2,ScreenTags+28	; SA_Height
	move.l	d3,ScreenTags+36	; SA_Depth
	move.l	d0,ScreenTags+68	; SA_DisplayID
	lea	MainMenuLeft,a0		; the windows
	moveq	#BM_WINS,d0
	moveq	#8,d1
	moveq	#1,d2
	jsr	RmnRects
	lea	bm_ngads(pc),a2		; the gadgets
	moveq	#30,d1
	moveq	#0,d2
.ng:	move.l	(a2)+,d0
	beq.s	.ngx
	move.l	d0,a0
	move.l	(a2)+,d0
	jsr	RmnRects
	bra.s	.ng
.ngx:	lea	bm_itexts(pc),a0	; the texts
	jsr	RmnITexts
	lea	DirInfoText,a0		; Centrar's x and width
	bsr	bm_centab
	lea	DirErrorText,a0
	bsr	bm_centab
	lea	InsTags,a0		; the Insert requester (Juan's tags)
	move.l	20(a0),d0		; ASLFR_InitialLeftEdge
	jsr	RmnScX
	add.w	RmnOX,d0
	move.l	d0,20(a0)
	move.l	28(a0),d0		; ASLFR_InitialTopEdge: under the bar as the windows
	sub.w	RmnBar0,d0
	jsr	RmnScY
	add.w	RmnBar1,d0
	add.w	RmnOY,d0
	move.l	d0,28(a0)
	move.l	36(a0),d0		; ASLFR_InitialHeight
	jsr	RmnScY
	move.l	d0,36(a0)
	IFD	HY_ASLPAT
	IFD	HY_ASLWIDE
	lea	HyInsTags,a0		; the hybrid's left and width
	move.l	4(a0),d0
	jsr	RmnScX
	add.w	RmnOX,d0
	move.l	d0,4(a0)
	move.l	12(a0),d0
	jsr	RmnScX
	move.l	d0,12(a0)
	ENDC
	ENDC
	lea	bm_imgs(pc),a2		; the pictures
.im:	move.l	(a2)+,d0
	beq.s	.imx
	move.l	d0,a0
	movem.w	(a2)+,d0-d2
	IFD	GBC_BIGHIRES
	bsr	bm_hires		; a redrawn copy for this size?
	bne.s	.im
	ENDC
	jsr	RmnImage
	bra.s	.im
.imx:	lea	MainMenuRender,a0	; the bevels
	lea	OpenPrefsWindow,a1
	move.l	#BM_BEVELS,d0
	moveq	#1,d1
	jsr	RmnPatchBevels
	BMSTEP	8
	bra.s	.x
.nosize:
	IFEQ	GBC_BIGSIZE-1080
	cmp.l	#1080,bm_want
	bne.s	.close
	move.l	#720,d0
	bra	.trysz
	ENDC
.close:	bsr	bm_libs			; classic: nothing changed
.x:
	IFD	GBC_BIGDBG
	bsr	bm_dbgw
	ENDC
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; ---- the menu's font (Juan's topaz8 TextAttr pointed at it) -> D0 = 1 done, 0 none (classic)
bm_font:
	movem.l	d1/a0-a2,-(sp)
	IFD	GBC_BIG43
	IFEQ	GBC_BIGFONT-2
	moveq	#8,d0			; Smooth: the cell, through diskfont
	jsr	RmnScX
	move.l	d0,-(sp)
	moveq	#8,d0
	jsr	RmnScY
	move.l	d0,d1
	move.l	(sp)+,d0
	lea	topaz8,a0
	lea	bm_smoothn(pc),a1
	jsr	RmnFontDisk
	IFD	GBC_BIGDBG
	move.w	#2,bm_dbg+4*7
	ENDC
	tst.l	d0
	bne.s	.x
	ENDC
	moveq	#8,d0			; Pixel: the one made for this cell
	jsr	RmnScY
	lea	bm_pix24,a2
	cmp.w	#36,d0
	bcs.s	.p
	lea	bm_pix36,a2
.p:	lea	topaz8,a0
	lea	bm_pixn(pc),a1
	jsr	RmnFontBlob
	IFD	GBC_BIGDBG
	move.w	#1,bm_dbg+4*7
	ENDC
	ELSE
	lea	topaz8,a0		; whole numbers: topaz 8 blown up
	lea	bm_fontn(pc),a1
	jsr	RmnFont
	IFD	GBC_BIGDBG
	clr.w	bm_dbg+4*7
	ENDC
	ENDC
.x:	movem.l	(sp)+,d1/a0-a2
	rts

	IFD	GBC_BIG43
; ---- the menu's checkmark and Amiga-key images for the font's cell (RmnMarks), given to the
; main window (WA_Checkmark, WA_AmigaKey) and to LayoutMenus (GTMN_Checkmark, GTMN_AmigaKey, so
; CHECKWIDTH and COMMWIDTH follow them) by a TAG_MORE in Juan's two tag lists. Ink BARDETAILPEN,
; paper BARBLOCKPEN (Juan's DriPens), as the system's own. Anything unexpected: the system's.
bm_marks:
	movem.l	d0-d2/a0-a1,-(sp)
	cmp.l	#$80080031,MTags1	; GTMN_TextAttr, Juan's LayoutMenus tags as built
	bne	.x
	cmp.l	#$80000093,MainMenuSC+8	; WA_NewLookMenus, the main window's last tag
	bne	.x
	moveq	#8,d0
	jsr	RmnScY
	lea	bm_mk24,a0
	cmp.w	#36,d0
	bcs.s	.s
	lea	bm_mk36,a0
.s:	move.w	DriPens+18,d0		; BARDETAILPEN
	move.w	DriPens+20,d1		; BARBLOCKPEN
	lea	bm_mkbuf,a1
	move.w	#BM_MKBUF,d2
	jsr	RmnMarks
	tst.l	d0
	beq	.x
	move.l	MTags1+4,bm_mtags+4
	move.l	#2,MTags1		; TAG_MORE
	move.l	#bm_mtags,MTags1+4
	move.l	MainMenuSC+12,bm_wtags+4
	move.l	#2,MainMenuSC+8
	move.l	#bm_wtags,MainMenuSC+12
.x:	movem.l	(sp)+,d0-d2/a0-a1
	rts
	ENDC

	IFD	GBC_BIGLAYOUT
; ---- the new layout, in Juan's 640x212 numbers before they are scaled: all of his numbers it
; changes are checked first (anything unexpected: his layout, bm_lay clear).
bm_layout:
	movem.l	d0-d2/a0-a1,-(sp)
	moveq	#0,d1
	bsr	bm_bevs			; the bevels where we expect them?
	bne	.x
	lea	MainMenuNGads,a0
	cmp.l	#(34<<16)|143,30*GD_Veloz(a0)	; Emulation Speed's slider
	bne	.x
	cmp.l	#(384<<16)|143,30*GD_JoyType(a0)
	bne	.x
	cmp.w	#11,MainMenuGTypes+2*GD_Veloz	; SLIDER_KIND
	bne	.x
	cmp.w	#309,MainMenuText6+4	; " Control "
	bne	.x
	cmp.l	#MainMenuText7,MainMenuText6+16	; then " Emulation Speed "
	bne	.x
	lea	MainMenuGTags,a1	; the slider's tags: after GD_Veloz lists
	moveq	#GD_Veloz-1,d0
.t:	tst.l	(a1)
	beq.s	.t1
	addq.l	#8,a1
	bra.s	.t
.t1:	addq.l	#4,a1
	dbf	d0,.t
	cmp.l	#$80080027,(a1)		; GTSL_Max
	bne	.x
; as expected: change it
	moveq	#1,d1
	bsr	bm_bevs
	move.l	#2,(a1)			; TAG_MORE: the Surround cycle's tags
	move.l	#bm_surtags,4(a1)
	move.w	#7,MainMenuGTypes+2*GD_Veloz	; CYCLE_KIND
	lea	30*GD_Veloz(a0),a1	; Surround, under LCD fade
	move.l	#(489<<16)|128,(a1)
	move.l	#(108<<16)|13,4(a1)
	move.l	#bm_surtext,8(a1)
	move.l	#$21,18(a1)		; PLACETEXT_LEFT|NG_HIGHLABEL, as Juan's
	lea	30*GD_JoyType(a0),a1	; Joy type: to the picture's frame
	move.w	#384-272,(a1)
	move.w	#329-8-(384-272),4(a1)
	move.w	#309-272,MainMenuText6+4	; " Control " over its box
	move.l	#MainMenuText8,MainMenuText6+16	; no " Emulation Speed "
	move.w	#MainMenu_CNT,bm_mmcnt	; the Scanlines cycle made too
	IFD	GBC_RSTYLE		; 2.6: Refresh becomes the Scanline style (scanlines.s)
	lea	MainMenuNGads,a0
	jsr	bm_stylay
	ENDC
	st	bm_lay
	bsr	bm_lsync		; the lists as the settings are
.x:	movem.l	(sp)+,d0-d2/a0-a1
	rts

; Juan's bevels in MainMenuRender: D1 = 0 check, 1 rewrite x, y, w, h -> EQ all as expected
bm_bevs:
	movem.l	d0-d3/a0/a3,-(sp)
	lea	bm_bevtab,a3
.e:	move.w	(a3)+,d0		; the bevel's number in MainMenuRender
	bmi.s	.ok
	lea	MainMenuRender,a0
	moveq	#-1,d2
.s:	cmp.l	#OpenMainMenuWindow-24,a0
	bhi.s	.bad
	cmp.w	#$303C,(a0)		; move.w #x,d0 / add.w d4,d0 / move.w #y,d1 ...
	bne.s	.n
	cmp.l	#$D044323C,4(a0)
	bne.s	.n
	cmp.l	#$D245343C,10(a0)
	bne.s	.n
	addq.w	#1,d2
	cmp.w	d0,d2
	beq.s	.f
	lea	24(a0),a0
	bra.s	.s
.n:	addq.l	#2,a0
	bra.s	.s
.f:	movem.w	(a3)+,d0/d3		; Juan's x, y
	cmp.w	2(a0),d0
	bne.s	.bad
	cmp.w	8(a0),d3
	bne.s	.bad
	tst.w	d1
	beq.s	.sk
	move.w	(a3)+,2(a0)		; x, y, w, h (RmnPatchBevels runs after)
	move.w	(a3)+,8(a0)
	move.w	(a3)+,14(a0)
	move.w	(a3)+,18(a0)
	bra.s	.e
.sk:	addq.l	#8,a3
	bra.s	.e
.ok:	moveq	#0,d0
	bra.s	.x
.bad:	moveq	#1,d0
.x:	movem.l	(sp)+,d0-d3/a0/a3	; (the flags kept)
	rts

; the Surround entry the two settings make -> D0: 0 Off, 1 Bezel, 2 Auto
bm_surnow:
	moveq	#2,d0
	tst.b	sgb_opt
	bne.s	.x
	moveq	#0,d0
	tst.b	gbc_rbezon
	beq.s	.x
	moveq	#1,d0
.x:	rts

; ---- the two lists as the settings are (their tags for the next window, the gadgets if it is
; open); Super Game Boy without the bezel (an old config, a tick) is Auto. Keeps every register.
; The gadgets: GT_SetGadgetAttrs with no window (nothing drawn), then RefreshGList. With the
; window it never came back (WinUAE, OS 3.2; Intuition locked: 25 Nov).
bm_lsync:
	movem.l	d0-d1/a0-a3/a6,-(sp)
	tst.b	bm_lay
	beq	.x
	tst.b	sgb_opt
	beq.s	.n
	move.b	#1,gbc_rbezon
.n:	bsr.s	bm_surnow
	move.l	d0,bm_surtags+12	; GTCY_Active
	moveq	#0,d0
	move.b	gbc_rscanon,d0
	move.l	d0,bm_scantags+12
	move.l	MainMenuWnd,d0
	beq	.x
	BMSTEP	$30
	move.l	MainMenuGadgets+4*GD_Veloz,a0
	lea	bm_surtags+8,a3
	bsr.s	.set
	BMSTEP	$31
	move.l	MainMenuGadgets+4*GD_Scan,a0
	lea	bm_scantags+8,a3
	bsr.s	.set
	BMSTEP	$32
.x:	movem.l	(sp)+,d0-d1/a0-a3/a6
	rts
; A0 = the gadget, A3 = its tags: set with no window (GadTools draws nothing), then drawn
.set:	move.l	a0,-(sp)
	sub.l	a1,a1
	sub.l	a2,a2
	move.l	_GadToolsBase,a6
	jsr	-42(a6)			; GT_SetGadgetAttrsA
	move.l	(sp)+,a0
	move.l	MainMenuWnd,a1
	sub.l	a2,a2
	moveq	#1,d0
	move.l	_IntuitionBase,a6
	jmp	-432(a6)		; RefreshGList

; ---- the Surround cycle (Juan's gadget table): D2.w = the entry. The two settings, their config
; lines (rmenu.s), the ticks.
bm_gsur:
	movem.l	d0-d7/a0-a6,-(sp)
	tst.b	bm_lay
	beq.s	.x
	moveq	#0,d6			; d6 = the bezel, d5 = Super Game Boy
	moveq	#0,d5
	tst.w	d2
	beq.s	.set
	moveq	#1,d6
	cmp.w	#2,d2
	bcs.s	.set
	moveq	#1,d5
.set:	move.w	d5,-(sp)
	cmp.b	gbc_rbezon,d6
	beq.s	.s2
	move.b	d6,gbc_rbezon
	lea	gbc_rmname0,a3
	move.b	d6,d7			; "On" / "Off"
	jsr	gbc_rmsave
.s2:	move.w	(sp)+,d5
	cmp.b	sgb_opt,d5
	beq.s	.s3
	move.b	d5,sgb_opt
	lea	sgb_rmname,a3
	move.b	d5,d7
	addq.b	#4,d7			; "Auto" / "Off"
	jsr	gbc_rmsave
.s3:	jsr	gbc_rmsync		; the ticks (and the lists)
.x:	movem.l	(sp)+,d0-d7/a0-a6
	rts

; ---- the Scanlines cycle: D2.w = 0 Off, 1 On
bm_gscan:
	movem.l	d0-d7/a0-a6,-(sp)
	tst.b	bm_lay
	beq.s	.x
	tst.w	d2
	sne	d7
	neg.b	d7
	cmp.b	gbc_rscanon,d7
	beq.s	.x
	move.b	d7,gbc_rscanon
	lea	gbc_rmname1,a3
	jsr	gbc_rmsave
	IFD	GBC_RSTYLE		; the style's line too (scanlines.s)
	jsr	gbc_rssavesty
	ENDC
	jsr	gbc_rmsync
.x:	movem.l	(sp)+,d0-d7/a0-a6
	rts

; ---- the Options menu's ticks (Juan's Options table): rmenu.s takes the tick, then the other
; tick follows so that the pair is one of the list's entries, and the lists follow.
bm_mbez:
	jsr	gbc_rmbez
	tst.b	bm_lay
	beq.s	.x
	movem.l	d0-d7/a0-a6,-(sp)
	tst.b	gbc_rbezon		; the bezel off: Super Game Boy off too (Off)
	bne.s	.s
	tst.b	sgb_opt
	beq.s	.s
	clr.b	sgb_opt
	lea	sgb_rmname,a3
	moveq	#4,d7			; "Off"
	jsr	gbc_rmsave
.s:	jsr	gbc_rmsync
	movem.l	(sp)+,d0-d7/a0-a6
.x:	rts
bm_msgb:
	jsr	gbc_rmsgb
	tst.b	bm_lay
	beq.s	.x
	movem.l	d0-d7/a0-a6,-(sp)
	tst.b	sgb_opt			; Super Game Boy on: the bezel on too (Auto)
	beq.s	.s
	tst.b	gbc_rbezon
	bne.s	.s
	move.b	#1,gbc_rbezon
	lea	gbc_rmname0,a3
	moveq	#1,d7			; "On"
	jsr	gbc_rmsave
.s:	jsr	gbc_rmsync
	movem.l	(sp)+,d0-d7/a0-a6
.x:	rts
bm_mscan:
	jsr	gbc_rmscan
	jmp	bm_lsync
	ENDC

	IFD	GBC_JOYCFG
; ---- "Joy type" in PROGDIR:AmiGameBoy.config (read by bm_config) wins over Juan's prefs
; (S:AmiGameBoy.prefs): after his LoadPrefs, before PonPrefs sets the gadget (hook in Programa).
bm_joyload:
	move.l	d0,-(sp)
	move.b	bm_joycfg,d0
	cmp.b	#4,d0
	bcc.s	.x			; no line: his prefs
	move.b	d0,DirPrefs+$08
.x:	move.l	(sp)+,d0
	rts

; ---- the Joy type cycle (Juan's gadget table): his picture, then the line "Joy type = ..."
; written at once (rmenu.s gbc_rmsave, codes 8-11). Save Prefs is untouched.
bm_gjoy:
	move.w	d2,-(sp)
	jsr	ImpJoyType
	move.w	(sp)+,d2
	movem.l	d0-d7/a0-a6,-(sp)
	moveq	#3,d7
	and.b	d2,d7
	addq.b	#8,d7
	lea	bm_joyname,a3
	jsr	gbc_rmsave
	movem.l	(sp)+,d0-d7/a0-a6
	rts
	ENDC

	IFD	GBC_BIGHIRES
; ---- A0 = one of Juan's pictures (planar data) -> NE: its redrawn copy for this size is
; RmnDrawImage's (RmnImageUse); EQ: none (RmnImage then). Keeps every register.
bm_hires:
	movem.l	d0-d1/a0-a2,-(sp)
	moveq	#4,d1			; 1080: 2 x 4 blocks
	cmp.l	#$00020004,RmnBX	; RmnBX, RmnBY
	beq.s	.sz
	moveq	#8,d1			; 720: 1 x 2
	cmp.l	#$00010002,RmnBX
	bne.s	.no
.sz:	lea	bm_hrtab,a2
.f:	move.l	(a2),d0
	beq.s	.no
	cmp.l	a0,d0
	beq.s	.use
	lea	12(a2),a2
	bra.s	.f
.use:	move.l	(a2,d1.w),a1
	jsr	RmnImageUse
	tst.l	d0
	bra.s	.x
.no:	moveq	#0,d0
.x:	movem.l	(sp)+,d0-d1/a0-a2
	rts
	ENDC

; close the libraries (classic menu, or at the end)
bm_libs:
	movem.l	d0-d1/a0-a1/a6,-(sp)
	move.l	4.w,a6
	lea	RmnGfx,a0
	moveq	#4-1,d1			; RmnGfx, RmnInt, RmnP96, RmnDisk
.l:	move.l	(a0),d0
	beq.s	.n
	clr.l	(a0)
	move.l	a0,-(sp)
	move.l	d0,a1
	jsr	-414(a6)		; CloseLibrary
	move.l	(sp)+,a0
.n:	addq.l	#4,a0
	dbf	d1,.l
	movem.l	(sp)+,d0-d1/a0-a1/a6
	rts

; a Centrar table (A0): entries IntuiText, x, width (longs), ended by a 0 IntuiText: x, width scaled
bm_centab:
	move.l	(a0),d0
	beq.s	.x
	move.l	4(a0),d1		; x, width
	move.l	8(a0),d2
	move.w	d1,d0
	exg	d1,d2
	jsr	RmnSpX			; d1 = the width
	jsr	RmnScX
	move.l	d0,4(a0)
	move.l	d1,8(a0)
	lea	12(a0),a0
	bra.s	bm_centab
.x:	rts

; ---- Juan's DrawImage calls (hooks for JSR/JMP -114(A6), A6 = Intuition): A0 = RastPort, A1 =
; Image, D0 = x in the window, D1 = y in the window + the screen font's height (his convention).
; Big: the picture's scaled copy at the scaled place inside the window's border; the 4:3 side
; borders drawn again (the screen may have been opened again).
bm_drawimage:
	tst.b	bm_on
	bne.s	.big
	jmp	-114(a6)		; DrawImage
.big:	movem.l	d0-d3/a0-a1,-(sp)
	IFD	GBC_BIG43
	move.l	MainMenuWnd,d0		; the menu strip's text in one column (RmnMenuAlign)
	beq.s	.na
	move.l	d0,a0
	move.l	MainMenuMenus,d0
	beq.s	.na
	move.l	d0,a1
	jsr	RmnMenuAlign
.na:	movem.l	(sp),d0-d3/a0-a1	; Juan's arguments again
	ENDC
	IFD	GBC_BIGLAYOUT
	tst.b	bm_lay			; the Joy type picture in the main window: Control moved left
	beq.s	.nj
	cmp.l	#DatsJoyTypePic,a1
	bne.s	.nj
	move.l	a0,d3
	move.l	MainMenuWnd,d2
	beq.s	.nj
	exg	d2,a0
	cmp.l	50(a0),d3		; wd_RPort
	exg	d2,a0
	bne.s	.nj
	sub.w	#BM_JOYDX,d0
.nj:
	ENDC
	IFD	GBC_BIGDBG
	cmp.l	#$10,bm_dbg
	bcc.s	.logd
	BMSTEP	$10
.logd:
	ENDC
	move.l	Scr,a0
	jsr	RmnBorders
	moveq	#0,d2
	move.b	36(a0),d2		; sc_WBorLeft = the window's BorderLeft
	moveq	#0,d3
	move.b	35(a0),d3		; sc_WBorTop
	add.w	bm_fy,d3
	addq.w	#1,d3			; the window's BorderTop (title bar)
	sub.w	d2,d0			; x inside the border
	sub.w	d3,d1			; y inside it: y + font = y + 8 at 1x, so y - 1 - WBorTop
	move.l	16(sp),a0		; the RastPort
	jsr	RmnDrawImage
	movem.l	(sp)+,d0-d3/a0-a1
	rts

	IFD	GBC_BIGDBG
; test: PROGDIR:bigmenu.log = step, ModeID, width, height, depth, X, Y, font/bevels (hex)
bm_dbgw:
	movem.l	d0-d7/a0-a6,-(sp)
	movem.l	bm_mode,d0-d3
	movem.l	d0-d3,bm_dbg+4
	move.l	RmnSXn,bm_dbg+4*5	; SXn, SXd
	move.l	RmnSYn,bm_dbg+4*6	; SYn, SYd
	move.l	RmnDiskInf,bm_dbg+4*8	; the Smooth font: width at 50, height asked,
	move.l	RmnDiskInf+4,bm_dbg+4*9	; the width and height got
	lea	bm_dbg,a0
	lea	bm_dbgt,a1
	moveq	#BM_DBGN-1,d2
.l:	move.l	(a0)+,d0
	moveq	#8-1,d1
.h:	rol.l	#4,d0
	move.b	d0,d3
	and.b	#15,d3
	add.b	#"0",d3
	cmp.b	#"9",d3
	bls.s	.d
	addq.b	#7,d3
.d:	move.b	d3,(a1)+
	dbf	d1,.h
	move.b	#" ",(a1)+
	dbf	d2,.l
	move.b	#10,-1(a1)
	move.l	HyDosBase,a6
	move.l	#bm_dbgn,d1
	move.l	#1006,d2		; MODE_NEWFILE
	jsr	-30(a6)
	move.l	d0,d4
	beq.s	.x
	move.l	d4,d1
	move.l	#bm_dbgt,d2
	moveq	#BM_DBGN*9,d3
	jsr	-48(a6)			; Write
	move.l	d4,d1
	jsr	-36(a6)
.x:	movem.l	(sp)+,d0-d7/a0-a6
	rts
bm_dbgn:	dc.b	"PROGDIR:bigmenu.log",0
	even
	ENDC

; ---- after Juan's CloseDownScreen (hook in Quitar): the pictures, the fonts, the libraries
bm_exit:
	tst.b	bm_on
	beq.s	.x
	BMSTEP	$20
	jsr	RmnFreeAll
	bsr	bm_libs
	IFD	GBC_RSTYLE
	IFD	GBC_BIGLAYOUT
	jsr	bm_chclose		; chooser.gadget (scanlines.s)
	ENDC
	ENDC
	sf	bm_on
.x:	rts

; ---- "Menu = Large | Classic" in PROGDIR:AmiGameBoy.config -> bm_classic (no file or no line: Large)
bm_config:
	movem.l	d0-d4/a0-a2/a6,-(sp)
	sf	bm_classic
	move.l	HyDosBase,d0
	beq	.x
	move.l	d0,a6
	move.l	#bm_cfgn,d1
	move.l	#1005,d2		; MODE_OLDFILE
	jsr	-30(a6)			; Open
	move.l	d0,d4
	beq	.x
	move.l	d4,d1
	move.l	#bm_buf,d2
	move.l	#BM_BUFSZ-1,d3
	jsr	-42(a6)			; Read
	move.l	d0,d3
	move.l	d4,d1
	jsr	-36(a6)			; Close
	tst.l	d3
	ble	.x
	lea	bm_buf,a0
	clr.b	(a0,d3.l)		; the end
.line:	move.b	(a0),d0			; a line: blanks, "Menu", blanks, "=", blanks, the value
	beq	.x
	cmp.b	#" ",d0
	beq.s	.sk
	cmp.b	#9,d0
	bne.s	.key
.sk:	addq.l	#1,a0
	bra.s	.line
.key:	move.l	a0,a2
	lea	bm_key(pc),a1
	bsr.s	.word
	bne.s	.menu
	IFD	GBC_JOYCFG
	move.l	a2,a0			; "Joy type = Amiga JoyStick | Keyboard Only | CD32 Joypad |
	lea	bm_joykey(pc),a1	; Standard Joypad": the first letter tells
	bsr.s	.word
	beq.s	.next
	move.b	(a0),d0
	or.b	#$20,d0
	lea	bm_joyini(pc),a1
	moveq	#0,d1
.j:	cmp.b	(a1,d1.w),d0
	beq.s	.jf
	addq.w	#1,d1
	cmp.w	#4,d1
	bcs.s	.j
	bra.s	.next
.jf:	move.b	d1,bm_joycfg
	ENDC
	bra.s	.next
.menu:	move.b	(a0),d0
	or.b	#$20,d0
	cmp.b	#"c",d0			; Classic
	bne.s	.next
	st	bm_classic
.next:	move.b	(a0)+,d0		; to the next line
	beq	.x
	cmp.b	#10,d0
	bne.s	.next
	bra.s	.line
.x:	movem.l	(sp)+,d0-d4/a0-a2/a6
	rts
; A0 at a line's first word, A1 = a key (lower case) -> NE: it is the key, A0 after "=" and blanks
.word:	move.b	(a1)+,d1
	beq.s	.wend
	move.b	(a0),d0
	or.b	#$20,d0
	cmp.b	d1,d0
	bne.s	.wno
	addq.l	#1,a0
	bra.s	.word
.wend:	bsr.s	.blank
	cmp.b	#"=",(a0)
	bne.s	.wno
	addq.l	#1,a0
	bsr.s	.blank
	moveq	#1,d0
	rts
.wno:	moveq	#0,d0
	rts
.blank:	cmp.b	#" ",(a0)
	beq.s	.b1
	cmp.b	#9,(a0)
	bne.s	.b2
.b1:	addq.l	#1,a0
	bra.s	.blank
.b2:	rts

bm_ngads:
	dc.l	MainMenuNGads,MainMenu_CNT,ImpErrorNGads,ImpError_CNT
	dc.l	HelpPageNGads,HelpPage_CNT,AboutNGads,About_CNT
	dc.l	MC68020NGads,MC68020_CNT,OverwriteNGads,Overwrite_CNT
	dc.l	QuitNGads,Quit_CNT,DebugNGads,Debug_CNT
	dc.l	CheatNGads,Cheat_CNT,EditJoyNGads,EditJoy_CNT
	dc.l	EditSoundNGads,EditSound_CNT,RequestNGads,Request_CNT
	dc.l	ClearNGads,Clear_CNT,AskSaveBattNGads,AskSaveBatt_CNT
	dc.l	PrefsNGads,Prefs_CNT,0
bm_itexts:
	dc.l	MainMenuText0,ImpErrorText0,HelpPageText0,AboutText0,MC68020Text0
	dc.l	OverwriteText0,QuitText0,DebugText0,CheatText0,EditJoyText0
	dc.l	EditSoundText0,RequestText0,ClearText0,AskSaveBattText0,PrefsText0,0
bm_imgs:				; planar data, width, height, depth
	dc.l	GBLogo
	dc.w	325,51,3
	dc.l	GBTeclado
	dc.w	47,16,3
	dc.l	GBJoyStick
	dc.w	47,16,3
	dc.l	GBJoypad
	dc.w	47,16,3
	dc.l	GBCD32
	dc.w	47,16,3
	dc.l	Perill
	dc.w	64,30,3
	dc.l	Cart
	dc.w	64,30,3
	dc.l	CartB
	dc.w	64,30,3
	dc.l	CartR
	dc.w	64,30,3
	dc.l	CartX
	dc.w	64,30,3
	dc.l	Enfadat
	dc.w	64,30,3
	dc.l	Llibre
	dc.w	64,30,3
	dc.l	Ram
	dc.w	64,30,3
	dc.l	0
bm_gfxn:	dc.b	"graphics.library",0
bm_intn:	dc.b	"intuition.library",0
bm_p96n:	dc.b	"Picasso96API.library",0
bm_dfn:		dc.b	"diskfont.library",0
bm_fontn:	dc.b	"agbbig.font",0
bm_pixn:	dc.b	"rmpixel.font",0	; the Pixel font, made at run time (never on disk)
bm_smoothn:	dc.b	"LetterGothic.font",0
bm_cfgn:	dc.b	"PROGDIR:AmiGameBoy.config",0
bm_key:		dc.b	"menu",0
	IFD	GBC_JOYCFG
bm_joykey:	dc.b	"joy type",0
bm_joyini:	dc.b	"akcs"		; Juan's order: 0 Amiga JoyStick .. 3 Standard Joypad
	ENDC
	even
	include	"rtgmenu.s"

	SECTION	bigmdata,DATA
bm_on:		dc.b	0		; the menu is big
bm_classic:	dc.b	0		; "Menu = Classic"
bm_chw:		dc.w	8		; Centrar's pixels a character
bm_fy:		dc.w	8		; the menu font's height
	cnop	0,4
bm_mode:	dc.l	0,0,0,0		; ModeID, width, height, depth
bm_want:	dc.l	0		; the height asked (GBC_BIGSIZE 1080: 1080, then 720)
	include	"rtgmenu_data.s"
	IFD	GBC_BIG43
	cnop	0,4
bm_pix36:	incbin	"data/rmfont_18x36.bin"	; rtg-framework tools/menufont.py (z00p)
	cnop	0,4
bm_pix24:	incbin	"data/rmfont_12x24.bin"
	cnop	0,4
bm_mk36:	incbin	"data/rmmark_18x36.bin"	; the menu's tick and Amiga key (menufont.py)
	cnop	0,4
bm_mk24:	incbin	"data/rmmark_12x24.bin"
bm_mtags:	dc.l	$80080031,0		; GTMN_TextAttr (Juan's)
	dc.l	$80080041,RmnChkImg	; GTMN_Checkmark
	dc.l	$80080042,RmnKeyImg	; GTMN_AmigaKey
	dc.l	0
bm_wtags:	dc.l	$80000093,0		; WA_NewLookMenus (Juan's)
	dc.l	$8000006D,RmnChkImg	; WA_Checkmark
	dc.l	$80000094,RmnKeyImg	; WA_AmigaKey
	dc.l	0
	ENDC
	IFD	GBC_BIGLAYOUT
bm_mmcnt:	dc.w	MainMenu_CNT-1	; the main window's gadgets made (GadToolsBox)
bm_lay:		dc.b	0		; the new layout is on
	even
; Juan's bevels changed: number in MainMenuRender, his x, y, then the new x, y, w, h
bm_bevtab:
	dc.w	3,546,139,329,139,51,18		; the Joy type picture's frame
	dc.w	8,298,136,26,136,362,24		; Control: the Cartridge box's x and width
	dc.w	9,296,135,24,135,366,26
	dc.w	10,26,136,26,136,362,24		; Emulation Speed: drawn as Control's
	dc.w	11,24,135,24,135,366,26
	dc.w	12,402,73,402,73,203,87		; Screen Options: down to Control's foot
	dc.w	13,400,72,400,72,207,89
	dc.w	-1
	cnop	0,4
bm_surtags:	dc.l	$8008000E,bm_surlab	; GTCY_Labels
	dc.l	$8008000F,2		; GTCY_Active (bm_lsync)
	dc.l	0
bm_scantags:	dc.l	$8008000E,bm_scanlab
	dc.l	$8008000F,0
	dc.l	0
bm_surlab:	dc.l	bm_toff,bm_tbez,bm_tauto,0
bm_scanlab:	dc.l	bm_toff,bm_ton,0
bm_surtext:	dc.b	"Surround:",0
bm_scantext:	dc.b	"Scanlines:",0
bm_toff:	dc.b	"Off",0
bm_ton:		dc.b	"On",0
bm_tbez:	dc.b	"Bezel",0
bm_tauto:	dc.b	"Auto",0
	even
	ENDC
	IFD	GBC_JOYCFG
bm_joycfg:	dc.b	$ff		; "Joy type" in the config: 0-3, $ff none
bm_joyname:	dc.b	"Joy type",0	; the config's words (gbc_rmsave)
bm_joycmt:	dc.b	"; Joy type: remembered when you pick it in the menu (Save Prefs also",10
		dc.b	"; stores it with Juan's settings). Amiga JoyStick, Keyboard Only,",10
		dc.b	"; CD32 Joypad or Standard Joypad.",10,0
bm_joyv0:	dc.b	" Amiga JoyStick",0
bm_joyv1:	dc.b	" Keyboard Only",0
bm_joyv2:	dc.b	" CD32 Joypad",0
bm_joyv3:	dc.b	" Standard Joypad",0
	cnop	0,4
bm_joyvals:	dc.l	bm_joyv0,bm_joyv1,bm_joyv2,bm_joyv3
	ENDC
	IFD	GBC_BIGHIRES
	cnop	0,4
bm_hrtab:				; Juan's picture, its redraw at 1080, at 720
	dc.l	GBLogo,bm_hlogo1,bm_hlogo7
	dc.l	GBTeclado,bm_hkey1,bm_hkey7
	dc.l	GBJoyStick,bm_hstick1,bm_hstick7
	dc.l	GBJoypad,bm_hpad1,bm_hpad7
	dc.l	GBCD32,bm_hcd1,bm_hcd7
	dc.l	0
	cnop	0,4			; rtg-framework tools/agbart/planar.py (z00p)
bm_hlogo1:	incbin	"data/hires_logo_1080.bin"
bm_hkey1:	incbin	"data/hires_teclado_1080.bin"
bm_hstick1:	incbin	"data/hires_joystick_1080.bin"
bm_hpad1:	incbin	"data/hires_joypad_1080.bin"
bm_hcd1:	incbin	"data/hires_cd32_1080.bin"
bm_hlogo7:	incbin	"data/hires_logo_720.bin"
bm_hkey7:	incbin	"data/hires_teclado_720.bin"
bm_hstick7:	incbin	"data/hires_joystick_720.bin"
bm_hpad7:	incbin	"data/hires_joypad_720.bin"
bm_hcd7:	incbin	"data/hires_cd32_720.bin"
	ENDC
	SECTION	bigmbss,BSS
	IFD	GBC_BIGDBG
bm_dbg:		ds.l	BM_DBGN
bm_dbgt:	ds.b	BM_DBGN*9
	ENDC
BM_BUFSZ	=2048
bm_buf:		ds.b	BM_BUFSZ
	IFD	GBC_BIG43
	SECTION	bigmchip,BSS_C
BM_MKBUF	=1024			; the tick and Amiga key, 2 planes each (720 bytes at 1080)
bm_mkbuf:	ds.b	BM_MKBUF
	ENDC

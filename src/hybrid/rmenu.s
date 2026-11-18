; AmiGameBoy hybrid: Bezel and Scanlines in the menu (RTG, GBC_RMENU; 2.1).
; Copyright (C) 2026 AmiGameBoy contributors. GPL-2 (see src/engine/COPYING).
;
; Two tick items at the end of Juan's Options menu (GadToolsBox/AmiGameBoy.s, a line and
; items 17, 18; their entries in MenuOptions, AmiGameBoy_Menu.asm). The settings are
; gbc_rbezon and gbc_rscanon (gbc_rtg.s), as "Bezel = On|Off" and "Scanlines = On|Off" in
; AmiGameBoy.config set them:
;   gbc_rmsync  (padcfg.s, after the file is read, once) ticks the two items as the settings are
;   gbc_rmbez, gbc_rmscan  (the menu picks) take the item's tick into the setting and write
;               that line of PROGDIR:AmiGameBoy.config: the line changed in place (the rest of
;               the file as it was), or added at the end when the file has none. No file, a
;               file over RMBUF bytes or a write-protected drawer: the setting holds for this
;               run only.
; The bezel is drawn when the picture's screen opens, so a change shows at the next Continue
; or Power On; scanlines show at once. OS alive (Juan's menu). Keeps every register.
;
; GBC_CCMENU (AGA and RTG, with GBC_CCOPT): an LCD Colours tick after them (item 19; 17 after
; a line of its own without GBC_RMENU), gbc_ccon (gbc_line.s) as "Colours = LCD|Raw" sets it.
; gbc_rmcc: the tick into gbc_ccon, the colour table made again at the next picture, the line
; "Colours = LCD|Raw" written as above. (A file that spells it "Colors" gets a Colours line.)

RMBUF		=2048			; as padcfg.s reads
RM_ITEM		=17			; Bezel; Scanlines is the next
RM_OPTIONS	=2			; Juan's Options menu
	IFD	GBC_CCMENU
	IFD	GBC_RMENU
RM_CCITEM	=RM_ITEM+2		; LCD Colours, after Scanlines
	ELSE
RM_CCITEM	=RM_ITEM		; LCD Colours, after its line
	ENDC
	ENDC
ResetMenuStrip	=-702
ClearMenuStripI	=-54

	SECTION	gbcrmcode,CODE
gbc_rmsync:
	movem.l	d0-d3/a0-a2/a6,-(sp)
	move.l	MainMenuWnd,d2
	beq.s	.x
	move.l	_IntuitionBase,a6
	move.l	d2,a0
	jsr	ClearMenuStripI(a6)
	IFD	GBC_RMENU
	moveq	#RM_ITEM,d0
	move.b	gbc_rbezon,d3
	bsr.s	.tick
	moveq	#RM_ITEM+1,d0
	move.b	gbc_rscanon,d3
	bsr.s	.tick
	ENDC
	IFD	GBC_CCMENU
	moveq	#RM_CCITEM,d0
	move.b	gbc_ccon,d3
	bsr.s	.tick
	ENDC
	move.l	d2,a0
	move.l	MainMenuMenus,a1
	jsr	ResetMenuStrip(a6)
	IFD	HY_RMTEST
	jsr	gbc_rmtest
	ENDC
.x:	movem.l	(sp)+,d0-d3/a0-a2/a6
	rts
.tick:	bsr.s	gbc_rmitem
	beq.s	.tx
	bclr	#0,12(a0)		; mi_Flags: CHECKED ($0100)
	tst.b	d3
	beq.s	.tx
	bset	#0,12(a0)
.tx:	rts

; d0 = item in Options, a6 = intuition -> a0 = the MenuItem, NE; EQ: none
gbc_rmitem:
	lsl.w	#5,d0
	or.w	#$f800|RM_OPTIONS,d0	; no sub-item
	move.l	MainMenuMenus,a0
	jsr	-$90(a6)		; ItemAddress
	move.l	d0,a0
	tst.l	d0
	rts

	IFD	GBC_RMENU
gbc_rmbez:
	movem.l	d0-d7/a0-a6,-(sp)
	lea	gbc_rbezon,a2
	lea	gbc_rmname0,a3
	moveq	#RM_ITEM,d0
	bra.s	gbc_rmpick
gbc_rmscan:
	movem.l	d0-d7/a0-a6,-(sp)
	lea	gbc_rscanon,a2
	lea	gbc_rmname1,a3
	moveq	#RM_ITEM+1,d0
gbc_rmpick:
	move.l	_IntuitionBase,a6
	bsr.s	gbc_rmitem		; (MENUTOGGLE has turned its tick over)
	beq.s	.x
	btst	#0,12(a0)
	sne	d7
	neg.b	d7			; 1 on, 0 off
	move.b	d7,(a2)
	bsr.s	gbc_rmsave
.x:	movem.l	(sp)+,d0-d7/a0-a6
	rts
	ENDC

	IFD	GBC_CCMENU
gbc_rmcc:
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	_IntuitionBase,a6
	moveq	#RM_CCITEM,d0
	bsr.w	gbc_rmitem		; (MENUTOGGLE has turned its tick over)
	beq.s	.x
	btst	#0,12(a0)
	sne	d7
	neg.b	d7			; 1 LCD, 0 Raw
	cmp.b	gbc_ccon,d7
	beq.s	.x
	jsr	gbc_ccset		; (gbc_line.s)
	lea	gbc_rmname2,a3
	addq.b	#2,d7			; "LCD" / "Raw"
	bsr.w	gbc_rmsave
.x:	movem.l	(sp)+,d0-d7/a0-a6
	rts
	ENDC

; the line "<a3> = On|Off" (d7.b 1|0; GBC_CCMENU: 3|2 = LCD|Raw) into PROGDIR:AmiGameBoy.config
gbc_rmsave:
	sub.l	a1,a1
	move.l	4.w,a6
	jsr	-294(a6)		; FindTask
	move.l	d0,a5
	move.l	$b8(a5),-(sp)		; pr_WindowPtr: no requesters
	moveq	#-1,d0
	move.l	d0,$b8(a5)
	move.l	HyDosBase,a6
	move.l	#HyPadCfgName,d1
	move.l	#1005,d2		; MODE_OLDFILE
	jsr	-30(a6)			; Open
	move.l	d0,d4
	beq.w	.x
	move.l	d4,d1
	move.l	#gbc_rmin,d2
	move.l	#RMBUF,d3
	jsr	-42(a6)			; Read
	move.l	d0,d5
	move.l	d4,d1
	jsr	-36(a6)			; Close
	tst.l	d5
	bmi.w	.x
	cmp.l	#RMBUF,d5		; (too big to hold: leave it)
	bcc.w	.x
; copy, line by line; a0 in, a1 its end, a4 out, d6 = found
	lea	gbc_rmin,a0
	lea	(a0,d5.l),a1
	lea	gbc_rmout,a4
	moveq	#0,d6
.line:	cmp.l	a1,a0
	bcc.s	.end
	move.l	a0,a2			; the line
.bl:	cmp.l	a1,a2			; over blanks
	bcc.s	.copy
	cmp.b	#" ",(a2)
	beq.s	.bl1
	cmp.b	#9,(a2)
	bne.s	.key
.bl1:	addq.l	#1,a2
	bra.s	.bl
.key:	move.l	a3,a5			; the name, any case, a whole word
.k1:	move.b	(a5)+,d0
	beq.s	.kend
	cmp.l	a1,a2
	bcc.s	.copy
	move.b	(a2)+,d1
	eor.b	d0,d1
	and.b	#$df,d1
	bne.s	.copy
	bra.s	.k1
.kend:	cmp.l	a1,a2			; then blanks and "="
	bcc.s	.copy
	move.b	(a2)+,d0
	cmp.b	#" ",d0
	beq.s	.kend
	cmp.b	#9,d0
	beq.s	.kend
	cmp.b	#"=",d0
	bne.s	.copy
.eq:	move.b	(a0)+,(a4)+		; the line up to its "=", then the value
	cmp.l	a2,a0
	bcs.s	.eq
	bsr.w	.value
	moveq	#1,d6
.rest:	cmp.l	a1,a0			; the old value: to the end of the line
	bcc.s	.end
	cmp.b	#13,(a0)
	beq.s	.copy
	cmp.b	#10,(a0)
	beq.s	.copy
	addq.l	#1,a0
	bra.s	.rest
.copy:	cmp.l	a1,a0			; the rest of the line as it is, with its LF
	bcc.s	.end
	move.b	(a0)+,d0
	move.b	d0,(a4)+
	cmp.b	#10,d0
	bne.s	.copy
	bra.s	.line
.end:	tst.b	d6
	bne.s	.write
	lea	gbc_rmout,a0		; none: add the line, after an LF if the file lacks one
	cmp.l	a0,a4
	beq.s	.add
	cmp.b	#10,-1(a4)
	beq.s	.add
	move.b	#10,(a4)+
.add:	move.l	a3,a0
.a1:	move.b	(a0)+,(a4)+
	bne.s	.a1
	subq.l	#1,a4
	move.b	#" ",(a4)+
	move.b	#"=",(a4)+
	bsr.w	.value
	move.b	#10,(a4)+
.write:	move.l	#HyPadCfgName,d1
	move.l	#1006,d2		; MODE_NEWFILE
	jsr	-30(a6)
	move.l	d0,d4
	beq.s	.x
	move.l	d4,d1
	move.l	#gbc_rmout,d2
	move.l	a4,d3
	sub.l	d2,d3
	jsr	-48(a6)			; Write
	move.l	d4,d1
	jsr	-36(a6)			; Close
.x:	sub.l	a1,a1
	move.l	4.w,a6
	jsr	-294(a6)
	move.l	d0,a5
	move.l	(sp)+,$b8(a5)
	rts
.value:
	IFD	GBC_CCMENU
	cmp.b	#2,d7
	bcs.s	.v0
	lea	gbc_rmlcd,a5
	cmp.b	#3,d7
	beq.s	.v1
	lea	gbc_rmraw,a5
	bra.s	.v1
.v0:
	ENDC
	lea	gbc_rmon,a5		; " On" or " Off"
	tst.b	d7
	bne.s	.v1
	lea	gbc_rmoff,a5
.v1:	move.b	(a5)+,(a4)+
	bne.s	.v1
	subq.l	#1,a4
	rts

	IFD	HY_RMTEST
; test (WinUAE, no mouse): HY_RMTEST=1 turns the Scanlines tick over, then the Bezel one, as two
; picks would, and runs their picks; =2 only looks. Then PROGDIR:AmiGameBoy.rmtest = the two
; ticks and the two settings (4 bytes).
gbc_rmtest:
	movem.l	d0-d7/a0-a6,-(sp)
	IFEQ	HY_RMTEST-1
	move.l	_IntuitionBase,a6
	moveq	#RM_ITEM+1,d0
	bsr.w	gbc_rmitem
	bchg	#0,12(a0)
	jsr	gbc_rmscan
	moveq	#RM_ITEM,d0
	bsr.w	gbc_rmitem
	bchg	#0,12(a0)
	jsr	gbc_rmbez
	ENDC
	move.l	_IntuitionBase,a6
	lea	gbc_rmtbuf,a2
	moveq	#RM_ITEM,d0
	bsr.w	gbc_rmitem
	btst	#0,12(a0)
	sne	(a2)+
	moveq	#RM_ITEM+1,d0
	bsr.w	gbc_rmitem
	btst	#0,12(a0)
	sne	(a2)+
	move.b	gbc_rbezon,(a2)+
	move.b	gbc_rscanon,(a2)+
	move.l	HyDosBase,a6
	move.l	#gbc_rmtname,d1
	move.l	#1006,d2
	jsr	-30(a6)
	move.l	d0,d4
	beq.s	.x
	move.l	d4,d1
	move.l	#gbc_rmtbuf,d2
	moveq	#4,d3
	jsr	-48(a6)
	move.l	d4,d1
	jsr	-36(a6)
.x:	movem.l	(sp)+,d0-d7/a0-a6
	rts
	ENDC

	SECTION	gbcrmdata,DATA
	IFD	HY_RMTEST
gbc_rmtname:	dc.b	"PROGDIR:AmiGameBoy.rmtest",0
gbc_rmtbuf:	dc.b	0,0,0,0
	ENDC
	IFD	GBC_RMENU
gbc_rmname0:	dc.b	"Bezel",0	; the menu items and the config's words
gbc_rmname1:	dc.b	"Scanlines",0
	ENDC
	IFD	GBC_CCMENU
gbc_rmtext2:	dc.b	"LCD Colours",0	; the menu item
gbc_rmname2:	dc.b	"Colours",0	; the config's word
gbc_rmlcd:	dc.b	" LCD",0
gbc_rmraw:	dc.b	" Raw",0
	ENDC
gbc_rmon:	dc.b	" On",0
gbc_rmoff:	dc.b	" Off",0
	even
	SECTION	gbcrmbss,BSS
gbc_rmin:	ds.b	RMBUF
gbc_rmout:	ds.b	RMBUF*2+32		; (each changed line grows by 4 at most)
	even

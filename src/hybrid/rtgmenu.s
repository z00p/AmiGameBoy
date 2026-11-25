; rtgmenu.s - a crisp 720p / 1080p RTG menu, 68k asm (vasm, Devpac syntax). MIT, see ../LICENSE.
;
; Opens a Juan-style GadToolsBox menu (640x212 laid out for PAL hires) in the output-sized P96 mode
; (1920x1080 or 1280x720). Two ways (RmnSetup):
;   4:3 area (25 Nov 2026): the layout fills a centred 4:3 area (1440x1080 / 960x720) with plain dark
;	side borders; positions and sizes are scaled by fractions (X 9/4, Y 9/2 at 1080; X 3/2, Y 3
;	at 720), Intuition and GadTools draw every frame and bevel at the screen's own size, the text
;	is a real font of that size (RmnFontBlob: our Pixel font; RmnFontDisk: an outline font
;	through diskfont), the pictures are whole-number blocks (2x4 at 1080, 1x2 at 720) centred
;	in their scaled place.
;   whole numbers (the 24 Nov prototype): X3/Y5 (or X3/Y4 "flat") at 1080, X2/Y3 at 720, topaz
;	blown up (RmnFont), the bevels drawn as chunky blocks.
; Intuition and GadTools still do everything; the kit only makes the numbers and the font bigger
; before the screen opens, and draws the few things the menu code draws with numbers in its code.
; Design: docs/menu/DESIGN.md. First user: AmiGameBoy (src/hybrid/bigmenu.s).
;
; The caller fills in before the first call: RmnGfx, RmnInt, RmnP96 (library bases), RmnDisk
; (diskfont.library, only for RmnFontDisk).
; Order of use:
;	RmnFind		the output-sized mode
;	RmnSetup	the scales for that mode and the layout's size
;	RmnTryOpen	can a screen of that mode open (memory)?
;	RmnFontBlob / RmnFontDisk / RmnFont	the font
;	RmnRects, RmnITexts, RmnImage, RmnPatchBevels	scale the menu's tables
;	... the menu runs; its DrawImage calls go through RmnDrawImage, its bevels through RmnBevel;
;	RmnBorders draws the side borders (4:3)
;	RmnFreeAll	after the menu screen has closed
; RmnScX / RmnScY / RmnSpX / RmnSpY scale single numbers for the caller's own tables.
; Every routine keeps all registers except the results named.
; INCLUDE "rtgmenu.s" in a code section and "rtgmenu_data.s" in a data section.

RMN_IMGMAX	= 24		; scaled images remembered
RMN_SEENMAX	= 600		; IntuiText structs scaled (each once)
RMN_ROWMAX	= 1024		; bytes of one expanded row (image or font)

; ---- RmnFind: D0 = the output height wanted (1080, 720, 0 = automatic) -> D0 = ModeID (0: none),
; D1 = width, D2 = height, D3 = the depth to open it with (24 for a 32-bit mode). Automatic: the
; Workbench's size when it is on a 1920x1080 or 1280x720 P96 mode, else 1920x1080, then 1280x720.
; Among the modes of that exact size: 32-bit, 24-bit, 16-bit, 15-bit, then 8-bit (25 Nov: true
; colour first, at both sizes. The A1200's 1080 has only 32-bit modes and its big menu worked; at
; 720 the 16-bit mode was taken and that run hung in the Insert requester.)
RmnFind:
	movem.l	d4-d7/a0-a1/a6,-(sp)
	tst.l	d0
	bne.s	.one
	bsr	RmnWBHeight
	tst.l	d0
	beq.s	.both
.one:	bsr.s	RmnFindH
	bra.s	.x
.both:	move.l	#1080,d0
	bsr.s	RmnFindH
	tst.l	d0
	bne.s	.x
	move.l	#720,d0
	bsr.s	RmnFindH
.x:	movem.l	(sp)+,d4-d7/a0-a1/a6
	rts

; D0 = height (width = 16/9 of it) -> D0 = ModeID or 0, D1 = w, D2 = h, D3 = depth
RmnFindH:
	move.l	d0,d7			; d7 = height
	move.l	d0,d6
	mulu.w	#16,d6
	divu.w	#9,d6
	and.l	#$ffff,d6		; d6 = width
	moveq	#0,d3			; best ModeID
	moveq	#-1,d4			; its rank (lower is better)
	moveq	#0,d5			; its depth
	moveq	#-1,d2			; the mode list
.next:	move.l	d2,d0
	move.l	RmnGfx,a6
	jsr	-732(a6)		; NextDisplayInfo
	move.l	d0,d2
	cmp.l	#-1,d0
	beq.s	.done
	jsr	-798(a6)		; ModeNotAvailable (d0 = 0: it is)
	tst.l	d0
	bne.s	.next
	moveq	#6,d1			; P96IDA_ISP96
	bsr.s	.attr
	tst.l	d0
	beq.s	.next
	moveq	#0,d1			; P96IDA_WIDTH
	bsr.s	.attr
	cmp.l	d6,d0
	bne.s	.next
	moveq	#1,d1			; P96IDA_HEIGHT
	bsr.s	.attr
	cmp.l	d7,d0
	bne.s	.next
	moveq	#2,d1			; P96IDA_DEPTH
	bsr.s	.attr
	move.l	d0,d1
	moveq	#0,d0			; the rank of this depth
	cmp.l	#32,d1
	beq.s	.rk
	moveq	#1,d0
	cmp.l	#24,d1
	beq.s	.rk
	moveq	#2,d0
	cmp.l	#16,d1
	beq.s	.rk
	moveq	#3,d0
	cmp.l	#15,d1
	beq.s	.rk
	moveq	#4,d0
.rk:	cmp.l	d4,d0
	bcc.s	.next			; (d4 = -1 at first: any rank is lower)
	move.l	d0,d4
	move.l	d2,d3
	move.l	d1,d5
	bra.s	.next
.done:	move.l	d3,d0
	move.l	d6,d1
	move.l	d7,d2
	move.l	d5,d3
	cmp.l	#24,d3			; a 32-bit (alpha) mode opens with SA_Depth 24: OpenScreen
	bls.s	.dok			; refuses 32 (WinUAE uaegfx, 24 Nov)
	moveq	#24,d3
.dok:	rts
.attr:	move.l	d2,d0			; p96GetModeIDAttr(d2, d1) -> d0
	move.l	RmnP96,a6
	jmp	-84(a6)

; RmnWBHeight -> D0 = 1080 or 720 when the Workbench screen is on a P96 mode of 1920x1080 or 1280x720,
; else 0. Keeps the other registers.
RmnWBHeight:
	movem.l	d1-d4/a0-a2/a6,-(sp)
	moveq	#0,d3
	move.l	RmnInt,a6
	sub.l	a0,a0
	jsr	-510(a6)		; LockPubScreen(NULL): the default public screen
	tst.l	d0
	beq.s	.x
	move.l	d0,a2
	lea	44(a2),a0		; sc_ViewPort
	move.l	RmnGfx,a6
	jsr	-792(a6)		; GetVPModeID
	move.l	d0,d2
	cmp.l	#-1,d0
	beq.s	.un
	moveq	#6,d1			; P96IDA_ISP96
	move.l	RmnP96,a6
	jsr	-84(a6)
	tst.l	d0
	beq.s	.un
	move.l	d2,d0
	moveq	#1,d1			; height
	jsr	-84(a6)
	move.l	d0,d4
	move.l	d2,d0
	moveq	#0,d1			; width
	jsr	-84(a6)
	cmp.l	#1920,d0
	bne.s	.w2
	cmp.l	#1080,d4
	bne.s	.un
	move.l	d4,d3
	bra.s	.un
.w2:	cmp.l	#1280,d0
	bne.s	.un
	cmp.l	#720,d4
	bne.s	.un
	move.l	d4,d3
.un:	move.l	RmnInt,a6
	sub.l	a0,a0
	move.l	a2,a1
	jsr	-516(a6)		; UnlockPubScreen
.x:	move.l	d3,d0
	movem.l	(sp)+,d1-d4/a0-a2/a6
	rts

; ---- RmnSetup: D1/D2 = the mode's width and height, D4/D5 = the layout's width and height (640, 212),
; D6 = 0 whole numbers, 1 whole numbers flat (SY - 1), 2 the 4:3 area. Sets RmnW, RmnH, the scales
; RmnSXn/RmnSXd, RmnSYn/RmnSYd, the picture blocks RmnBX/RmnBY, RmnOX/RmnOY (the layout block
; centred; 4:3: centred across, at the top as Juan's menu, the spare height below) and RmnNative (4:3: frames, bevels and text at the screen's own size). D0 = 0 when no
; scale of at least 1 fits.
; 4:3: the area is H x 4/3 wide (1440 / 960), X = that / the layout's width, Y = twice X (Juan's PAL
; hires pixels are about twice as tall as wide) or less when that does not fit. Blocks: X whole,
; Y twice that (at most Y's whole part).
RmnSetup:
	movem.l	d1-d7,-(sp)
	move.w	d1,RmnW
	move.w	d2,RmnH
	move.w	d4,RmnLW
	move.w	d5,RmnLH
	sf	RmnNative
	cmp.w	#2,d6
	beq.s	.r43
	moveq	#0,d0
	move.w	d1,d0
	divu.w	d4,d0			; SX
	moveq	#0,d3
	move.w	d2,d3
	divu.w	d5,d3			; SY
	tst.w	d6
	beq.s	.nf
	cmp.w	#1,d3
	bls.s	.nf
	subq.w	#1,d3
.nf:	tst.w	d0
	beq	.bad
	tst.w	d3
	beq	.bad
	move.w	d0,RmnSXn
	move.w	#1,RmnSXd
	move.w	d3,RmnSYn
	move.w	#1,RmnSYd
	move.w	d0,RmnBX
	move.w	d3,RmnBY
	bra	.off
.r43:	moveq	#0,d0
	move.w	d2,d0
	lsl.l	#2,d0
	divu.w	#3,d0			; the area's width
	cmp.w	d1,d0
	bls.s	.aw
	move.w	d1,d0
.aw:	cmp.w	d4,d0
	bcs	.bad			; smaller than the layout
	move.w	d0,RmnSXn
	move.w	d4,RmnSXd
	add.w	d0,d0
	move.w	d0,RmnSYn
	move.w	d4,RmnSYd
	moveq	#0,d3
	move.w	d5,d3
	mulu.w	d0,d3
	divu.w	d4,d3			; the layout's height at Y = 2X
	cmp.w	d2,d3
	bls.s	.hf
	move.w	d2,RmnSYn		; too tall: Y = H / the layout's height
	move.w	d5,RmnSYd
.hf:	moveq	#0,d0
	move.w	RmnSXn,d0
	divu.w	RmnSXd,d0
	move.w	d0,RmnBX		; >= 1 (the area is at least the layout's width)
	add.w	d0,d0
	moveq	#0,d3
	move.w	RmnSYn,d3
	divu.w	RmnSYd,d3
	cmp.w	d3,d0
	bls.s	.b1
	move.w	d3,d0
.b1:	tst.w	d0
	bne.s	.b2
	moveq	#1,d0
.b2:	move.w	d0,RmnBY
	st	RmnNative
.off:	move.w	d4,d0			; the block's place: centred
	bsr	RmnScX
	sub.w	d0,d1
	asr.w	#1,d1
	move.w	d1,RmnOX
	moveq	#0,d2			; 4:3: at the top, straight under the title bar
	tst.b	RmnNative
	bne.s	.oy
	move.w	RmnH,d2
	move.w	d5,d0
	bsr	RmnScY
	sub.w	d0,d2
	bpl.s	.oy
	moveq	#0,d2
.oy:	asr.w	#1,d2
	move.w	d2,RmnOY
	moveq	#1,d0
	bra.s	.x
.bad:	moveq	#0,d0
.x:	movem.l	(sp)+,d1-d7
	rts

; ---- RmnScX / RmnScY: D0.w = a layout x (y) -> D0.l = it scaled (x SXn / SXd, rounded down for
; x >= 0). RmnSpX / RmnSpY: D0.w = x (y), D1.w = a width (height) from there -> D1.l = the scaled
; width: scaled(x + w) - scaled(x), so neighbours meet. Keep every other register.
RmnScX:	muls.w	RmnSXn,d0
	divs.w	RmnSXd,d0
	ext.l	d0
	rts
RmnScY:	muls.w	RmnSYn,d0
	divs.w	RmnSYd,d0
	ext.l	d0
	rts
RmnSpX:	move.l	d0,-(sp)
	add.w	d1,d0
	bsr.s	RmnScX
	move.l	d0,d1
	move.l	(sp),d0
	bsr.s	RmnScX
	sub.l	d0,d1
	move.l	(sp)+,d0
	rts
RmnSpY:	move.l	d0,-(sp)
	add.w	d1,d0
	bsr.s	RmnScY
	move.l	d0,d1
	move.l	(sp),d0
	bsr.s	RmnScY
	sub.l	d0,d1
	move.l	(sp)+,d0
	rts

; ---- RmnTryOpen: D0 = ModeID, D1/D2 = size, D3 = depth -> D0 = 0 when a screen of that mode opened
; (behind, quiet; closed again at once), else -1.
RmnTryOpen:
	movem.l	d1/a0-a1/a6,-(sp)
	lea	RmnTryTags,a0
	move.l	d0,4(a0)
	move.l	d1,12(a0)
	move.l	d2,20(a0)
	move.l	d3,28(a0)
	move.l	a0,a1
	sub.l	a0,a0
	move.l	RmnInt,a6
	jsr	-612(a6)		; OpenScreenTagList
	tst.l	d0
	beq.s	.no
	move.l	d0,a0
	jsr	-66(a6)			; CloseScreen
	moveq	#0,d0
	bra.s	.x
.no:	moveq	#-1,d0
.x:	movem.l	(sp)+,d1/a0-a1/a6
	rts

; ---- RmnFontBlob: A0 = the menu's TextAttr (topaz 8), A1 = the font's name (the caller's, kept),
; A2 = an RMF1 font (tools/menufont.py: "RMF1", ysize.w, xsize.w, baseline.w, lochar.b, hichar.b,
; modulo.w, CharLoc longs, rows). Builds a TextFont of it in memory of its own (chip when there is
; some; it stays valid when the program has gone), adds it to the system list (AddFont) and points
; the TextAttr at it. If a font of that name and size is in the list already (an earlier run), uses
; that. D0 = 1 done, 0 failed (the TextAttr is then unchanged). RmnFontH = its height.
RmnFontBlob:
	movem.l	d1-d7/a0-a6,-(sp)
	move.l	a0,a4			; a4 = the TextAttr
	move.l	a1,a5			; a5 = the name
	cmp.l	#$524D4631,(a2)	; "RMF1"
	bne	.fail
	lea	RmnTA,a0
	move.l	a5,(a0)
	move.w	4(a2),4(a0)
	move.w	#$0040,6(a0)		; style 0, FPF_DESIGNED
	move.l	RmnGfx,a6
	jsr	-72(a6)			; OpenFont: there from an earlier run?
	tst.l	d0
	beq.s	.build
	move.l	d0,a1
	moveq	#0,d2
	move.w	4(a2),d1
	cmp.w	20(a1),d1		; tf_YSize
	bne.s	.old
	move.w	6(a2),d1
	cmp.w	24(a1),d1		; tf_XSize
	bne.s	.old
	move.l	10(a1),a0		; ln_Name
	move.l	a5,a3
.cmp:	move.b	(a0)+,d1
	cmp.b	(a3)+,d1
	bne.s	.old
	tst.b	d1
	bne.s	.cmp
	moveq	#1,d2
.old:	jsr	-78(a6)			; CloseFont
	tst.w	d2
	bne	.use
.build:	moveq	#0,d5
	move.b	11(a2),d5		; hichar
	moveq	#0,d0
	move.b	10(a2),d0		; lochar
	sub.w	d0,d5
	addq.w	#2,d5			; d5 = glyphs (+ the one for missing characters)
	move.l	d5,d6
	lsl.l	#2,d6			; d6 = CharLoc bytes
	moveq	#0,d3
	move.w	12(a2),d3		; modulo
	mulu.w	4(a2),d3		; d3 = glyph data bytes
	move.l	d6,d7
	add.l	#52+32,d7		; d7 = where the glyph data goes
	move.l	d7,d4
	add.l	d3,d4			; d4 = the size
	move.l	d4,d0
	move.l	#$10003,d1		; MEMF_PUBLIC|MEMF_CHIP|MEMF_CLEAR
	move.l	4.w,a6
	jsr	-198(a6)		; AllocMem
	tst.l	d0
	bne.s	.got
	move.l	d4,d0
	move.l	#$10001,d1		; MEMF_PUBLIC|MEMF_CLEAR
	jsr	-198(a6)
	tst.l	d0
	beq	.fail
.got:	move.l	d0,a3			; a3 = the new font
	move.l	d0,RmnFontMem
	move.l	d4,RmnFontSize
	move.l	a5,a0			; the name (31 characters at most)
	lea	52(a3),a1
	moveq	#31-1,d1
.nm:	move.b	(a0)+,(a1)+
	dbeq	d1,.nm
	move.w	#$0C00,8(a3)		; NT_FONT, pri 0
	lea	52(a3),a0
	move.l	a0,10(a3)		; ln_Name
	move.w	#52,18(a3)		; mn_Length
	move.w	4(a2),20(a3)		; tf_YSize
	move.w	#$0040,22(a3)		; tf_Style 0, tf_Flags FPF_DESIGNED
	move.w	6(a2),24(a3)		; tf_XSize
	move.w	8(a2),26(a3)		; tf_Baseline
	move.w	#1,28(a3)		; tf_BoldSmear
	move.b	10(a2),32(a3)		; tf_LoChar
	move.b	11(a2),33(a3)		; tf_HiChar
	move.w	12(a2),38(a3)		; tf_Modulo
	lea	52+32(a3),a1
	move.l	a1,40(a3)		; tf_CharLoc
	lea	14(a2),a0
	move.w	d5,d1
	subq.w	#1,d1
.loc:	move.l	(a0)+,(a1)+
	dbf	d1,.loc
	lea	(a3,d7.l),a1
	move.l	a1,34(a3)		; tf_CharData
	lsr.l	#1,d3			; words (the modulo is even)
	subq.l	#1,d3
.dat:	move.w	(a0)+,(a1)+
	dbf	d3,.dat
	move.l	a3,a1
	move.l	RmnGfx,a6
	jsr	-480(a6)		; AddFont
	st	RmnFontOwn
	move.l	a3,RmnFontTF
.use:	move.l	a5,(a4)			; the TextAttr: the big font
	move.w	4(a2),4(a4)
	move.b	#$40,7(a4)
	move.w	4(a2),RmnFontH
	moveq	#1,d0
	bra.s	.x
.fail:	moveq	#0,d0
.x:	movem.l	(sp)+,d1-d7/a0-a6
	rts

; ---- RmnFontDisk: A0 = the menu's TextAttr, A1 = a disk font's name ("LetterGothic.font"), D0/D1 =
; the character cell (w, h). Opens it through diskfont (RmnDisk) at the height that makes a character
; w wide (outline fonts come in any size; a first look at height 50 gives its width there; 25 Nov:
; diskfont made the same width whatever X DPI was asked, so the height is what sets the width), keeps
; it open (RmnFreeAll closes it) and points the TextAttr at it. Taken when a character is w wide (+-1)
; and the font at most h x 5/4 tall. D0 = 1 done, 0 no such font or none that fits (TextAttr
; unchanged). RmnFontH = its height. Widths are measured (TextLength of "0" in a RastPort of our own).
RMN_PROBEH	= 50
RmnFontDisk:
	movem.l	d1-d7/a0-a6,-(sp)
	move.l	a0,a4			; a4 = the TextAttr
	move.w	d0,d6			; d6 = w
	move.w	d1,d7			; d7 = h
	tst.l	RmnDisk
	beq	.fail
	lea	RmnTTA,a0		; the look: height 50
	move.l	a1,(a0)
	move.w	#RMN_PROBEH,4(a0)
	clr.w	6(a0)
	move.l	RmnDisk,a6
	jsr	-30(a6)			; OpenDiskFont
	tst.l	d0
	beq	.fail
	move.l	d0,a1
	bsr	.adv			; d5 = its width at height 50
	move.w	d5,RmnDiskInf		; (for a test log: width at 50, height asked, width and height got)
	move.l	RmnGfx,a6
	jsr	-78(a6)			; CloseFont
	tst.w	d5
	beq	.fail
	moveq	#0,d0			; the height: 50 w / its width, rounded
	move.w	d6,d0
	mulu.w	#RMN_PROBEH*2,d0
	divu.w	d5,d0
	addq.w	#1,d0
	lsr.w	#1,d0
	move.w	d0,RmnDiskInf+2
	move.w	d7,d1			; at most h x 5/4
	lsr.w	#2,d1
	add.w	d7,d1
	cmp.w	d1,d0
	bhi	.fail
	lea	RmnTTA,a0
	move.w	d0,4(a0)
	move.l	RmnDisk,a6
	jsr	-30(a6)			; OpenDiskFont: the one for the menu
	tst.l	d0
	beq	.fail
	move.l	d0,a1
	bsr	.adv
	move.w	d5,RmnDiskInf+4
	move.w	20(a1),RmnDiskInf+6
	move.w	d5,d1			; a character w wide?
	sub.w	d6,d1
	bpl.s	.w1
	neg.w	d1
.w1:	cmp.w	#1,d1
	bhi.s	.no
	move.l	a1,RmnDiskTF
	move.l	RmnTTA,(a4)		; the TextAttr: this font
	move.w	20(a1),4(a4)
	move.w	20(a1),RmnFontH
	clr.b	7(a4)
	moveq	#1,d0
	bra.s	.x
.no:	move.l	RmnGfx,a6
	jsr	-78(a6)			; CloseFont
.fail:	moveq	#0,d0
.x:	movem.l	(sp)+,d1-d7/a0-a6
	rts
.adv:	movem.l	d0-d1/a0-a1/a6,-(sp)	; a1 = a font -> d5 = the width of "0"
	move.l	a1,-(sp)
	lea	RmnRP,a1
	move.l	RmnGfx,a6
	jsr	-198(a6)		; InitRastPort
	lea	RmnRP,a1
	move.l	(sp)+,a0
	jsr	-66(a6)			; SetFont
	lea	RmnRP,a1
	lea	.zero(pc),a0
	moveq	#1,d0
	jsr	-54(a6)			; TextLength
	move.w	d0,d5
	movem.l	(sp)+,d0-d1/a0-a1/a6
	rts
.zero:	dc.b	"0",0
	even

; ---- RmnFont (whole-number scales): A0 = the menu's TextAttr (topaz 8), A1 = the big font's name
; (the caller's, kept). Builds the font RmnBX x RmnBY times as big from the one the TextAttr opens
; (each glyph bit BX across, each row BY down), adds it to the system list (AddFont) and points the
; TextAttr at it. If a font of that name and size is in the list already (an earlier run), uses
; it. D0 = 1 done, 0 failed (the TextAttr is then unchanged). RmnFontH = its height.
RmnFont:
	movem.l	d1-d7/a0-a6,-(sp)
	move.l	a0,a4			; a4 = the TextAttr
	move.l	a1,a5			; a5 = the name
	moveq	#0,d0
	move.w	4(a4),d0
	mulu.w	RmnBY,d0
	lea	RmnTA,a0
	move.l	a5,(a0)
	move.w	d0,4(a0)
	move.w	#$0040,6(a0)		; style 0, FPF_DESIGNED
	move.l	RmnGfx,a6
	jsr	-72(a6)			; OpenFont: there from an earlier run?
	tst.l	d0
	beq.s	.build
	move.l	d0,a1
	moveq	#0,d2
	move.w	RmnTA+4,d1
	cmp.w	20(a1),d1		; tf_YSize
	bne.s	.old
	move.l	10(a1),a0		; ln_Name
	move.l	a5,a2
.cmp:	move.b	(a0)+,d1
	cmp.b	(a2)+,d1
	bne.s	.old
	tst.b	d1
	bne.s	.cmp
	moveq	#1,d2
.old:	jsr	-78(a6)			; CloseFont
	tst.w	d2
	bne	.use
.build:	move.l	a4,a0
	jsr	-72(a6)			; OpenFont: the menu's own font
	tst.l	d0
	beq	.fail
	move.l	d0,a3			; a3 = the source font
	moveq	#0,d3
	move.w	38(a3),d3		; tf_Modulo
	mulu.w	RmnBX,d3		; d3 = the new modulo
	cmp.l	#RMN_ROWMAX,d3
	bhi	.close
	moveq	#0,d4
	move.w	20(a3),d4
	mulu.w	RmnBY,d4		; d4 = the new height
	moveq	#0,d5
	move.b	33(a3),d5		; tf_HiChar
	moveq	#0,d0
	move.b	32(a3),d0		; tf_LoChar
	sub.w	d0,d5
	addq.w	#2,d5			; d5 = glyphs (+ the one for missing characters)
	move.l	d5,d6
	lsl.l	#2,d6			; CharLoc
	tst.l	44(a3)
	beq.s	.nsp
	add.l	d5,d6
	add.l	d5,d6			; CharSpace
.nsp:	tst.l	48(a3)
	beq.s	.nkr
	add.l	d5,d6
	add.l	d5,d6			; CharKern
.nkr:	add.l	#52+32,d6		; the TextFont and the name
	move.l	d6,d7			; d7 = where the glyph data starts
	move.l	d3,d0
	mulu.w	d4,d0
	add.l	d0,d6			; d6 = the size
	move.l	d6,d0
	move.l	#$10003,d1		; MEMF_PUBLIC|MEMF_CHIP|MEMF_CLEAR (the font may be blitted)
	move.l	4.w,a6
	jsr	-198(a6)		; AllocMem
	tst.l	d0
	bne.s	.got
	move.l	d6,d0
	move.l	#$10001,d1		; MEMF_PUBLIC|MEMF_CLEAR
	jsr	-198(a6)
	tst.l	d0
	beq	.close
.got:	move.l	d0,a2			; a2 = the new font
	move.l	d0,RmnFontMem
	move.l	d6,RmnFontSize
	move.l	a3,a0			; the TextFont, then the changes
	move.l	a2,a1
	moveq	#52/4-1,d1
.cpy:	move.l	(a0)+,(a1)+
	dbf	d1,.cpy
	move.l	a5,a0			; the name (31 characters at most)
	lea	52(a2),a1
	moveq	#31-1,d1
.nm:	move.b	(a0)+,(a1)+
	dbeq	d1,.nm
	clr.l	(a2)			; ln_Succ, ln_Pred
	clr.l	4(a2)
	move.w	#$0C00,8(a2)		; NT_FONT, pri 0
	lea	52(a2),a0
	move.l	a0,10(a2)		; ln_Name
	clr.l	14(a2)			; mn_ReplyPort
	move.w	#52,18(a2)		; mn_Length
	move.w	d4,20(a2)		; tf_YSize
	and.b	#$BF,22(a2)		; tf_Style: no FSF_TAGGED (no extension)
	move.b	23(a3),d0
	and.b	#$FC,d0			; tf_Flags: not ROM, not disk,
	or.b	#$40,d0			; designed
	move.b	d0,23(a2)
	move.w	24(a3),d0
	mulu.w	RmnBX,d0
	move.w	d0,24(a2)		; tf_XSize
	move.w	26(a3),d0
	addq.w	#1,d0
	mulu.w	RmnBY,d0
	subq.w	#1,d0
	move.w	d0,26(a2)		; tf_Baseline: the same row of the glyph
	move.w	28(a3),d0
	mulu.w	RmnBX,d0
	move.w	d0,28(a2)		; tf_BoldSmear
	clr.w	30(a2)			; tf_Accessors
	move.w	d3,38(a2)		; tf_Modulo
	lea	52+32(a2),a1		; the tables after the name
	move.l	a1,40(a2)		; tf_CharLoc: offset and width in bits, both x BX
	move.l	40(a3),a0
	move.w	d5,d1
	add.w	d1,d1
	subq.w	#1,d1
.loc:	move.w	(a0)+,d0
	mulu.w	RmnBX,d0
	move.w	d0,(a1)+
	dbf	d1,.loc
	move.l	44(a3),d0		; tf_CharSpace (proportional fonts)
	beq.s	.nsp2
	move.l	d0,a0
	move.l	a1,44(a2)
	bsr	.words
.nsp2:	move.l	48(a3),d0		; tf_CharKern
	beq.s	.nkr2
	move.l	d0,a0
	move.l	a1,48(a2)
	bsr	.words
.nkr2:	lea	(a2,d7.l),a1
	move.l	a1,34(a2)		; tf_CharData
	move.l	34(a3),a0
	move.w	20(a3),d6		; the source rows
	subq.w	#1,d6
	moveq	#0,d2
	move.w	38(a3),d2		; the source modulo
.row:	move.l	a1,-(sp)
	bsr	RmnExpand		; a0 row (d2 bytes) -> a1, BX times as wide
	move.l	(sp)+,a1
	add.l	d2,a0
	bsr	.dup			; the row BY times
	dbf	d6,.row
	move.l	a2,a1
	move.l	RmnGfx,a6
	jsr	-480(a6)		; AddFont
	st	RmnFontOwn
	move.l	a2,RmnFontTF
	move.l	a3,a1
	jsr	-78(a6)			; CloseFont (the source)
.use:	move.l	a5,(a4)			; the TextAttr: the big font
	move.w	RmnTA+4,4(a4)
	move.b	#$40,7(a4)
	move.w	RmnTA+4,RmnFontH
	moveq	#1,d0
	bra.s	.x
.close:	move.l	a3,a1
	move.l	RmnGfx,a6
	jsr	-78(a6)
.fail:	moveq	#0,d0
.x:	movem.l	(sp)+,d1-d7/a0-a6
	rts
.words:	move.w	d5,d1			; d5 words from a0 to a1, x BX (signed)
	subq.w	#1,d1
.w1:	move.w	(a0)+,d0
	muls.w	RmnBX,d0
	move.w	d0,(a1)+
	dbf	d1,.w1
	rts
.dup:	move.w	RmnBY,d1		; a1 = the expanded row (d3 bytes): copy it below BY-1 times,
	subq.w	#1,d1			; a1 -> after the last copy
	move.l	a1,a6
	add.l	d3,a1
	bra.s	.d3
.d1:	move.l	a6,a5
	move.w	d3,d0
	subq.w	#1,d0
.d2:	move.b	(a5)+,(a1)+
	dbf	d0,.d2
.d3:	dbf	d1,.d1
	move.l	RmnTA,a5		; (a5 was the name: put it back)
	rts

; RmnExpand: A0 = a row of D2 bytes -> A1: each bit RmnBX times (D2 x BX bytes, BX 1..4). Keeps all.
RmnExpand:
	movem.l	d0-d6/a0-a1,-(sp)
	move.w	RmnBX,d5
	moveq	#32,d4
	move.w	d5,d0
	lsl.w	#3,d0
	sub.w	d0,d4			; d4 = 32 - 8 BX
	moveq	#1,d3
	lsl.l	d5,d3
	subq.l	#1,d3			; d3 = BX one bits
	tst.w	d2
	beq.s	.x
	subq.w	#1,d2
.b:	move.b	(a0)+,d0
	moveq	#0,d1
	moveq	#8-1,d6
.bit:	lsl.l	d5,d1
	add.b	d0,d0
	bcc.s	.z
	or.l	d3,d1
.z:	dbf	d6,.bit
	lsl.l	d4,d1
	move.w	d5,d6
	subq.w	#1,d6
.o:	rol.l	#8,d1
	move.b	d1,(a1)+
	dbf	d6,.o
	dbf	d2,.b
.x:	movem.l	(sp)+,d0-d6/a0-a1
	rts

; ---- RmnRects: A0 = the first rectangle (x, y, w, h words), D0 = how many, D1 = the stride in bytes,
; D2 = 0: x, y, w, h scaled (gadgets); 1: windows, also moved into the centred block and the top
; kept under the screen's title bar: y' = scaled(y - RmnBar0) + RmnBar1 + RmnOY (y >= RmnBar0),
; x' = scaled(x) + RmnOX. Widths and heights: RmnSpX / RmnSpY from x and y.
RmnRects:
	movem.l	d0-d6/a0,-(sp)
	move.w	d1,d4			; d4 = stride
	move.w	d0,d6
	subq.w	#1,d6
	bmi.s	.x
.r:	move.w	(a0),d0			; x, w
	move.w	4(a0),d1
	bsr	RmnSpX
	move.w	d1,4(a0)
	bsr	RmnScX
	move.w	d0,d3			; d3 = x'
	move.w	2(a0),d0		; y, h
	move.w	6(a0),d1
	bsr	RmnSpY
	move.w	d1,6(a0)
	tst.w	d2
	beq.s	.g
	add.w	RmnOX,d3
	sub.w	RmnBar0,d0
	bmi.s	.top
	bsr	RmnScY
	add.w	RmnBar1,d0
	bra.s	.oy
.top:	move.w	2(a0),d0
	bsr	RmnScY
.oy:	add.w	RmnOY,d0
	bra.s	.put
.g:	bsr	RmnScY
.put:	move.w	d3,(a0)
	move.w	d0,2(a0)
	add.w	d4,a0
	dbf	d6,.r
.x:	movem.l	(sp)+,d0-d6/a0
	rts

; ---- RmnITexts: A0 = a list of IntuiText chain heads (longs, ended by 0). Every struct reachable
; through it_NextText gets LeftEdge and TopEdge scaled, once (structs shared by chains are seen once).
RmnITexts:
	movem.l	d0-d2/a0-a2,-(sp)
.h:	move.l	(a0)+,d0
	beq.s	.x
.s:	move.l	d0,a1
	lea	RmnSeen,a2		; seen before?
	move.w	RmnSeenN,d1
	bra.s	.c2
.c1:	cmp.l	(a2)+,d0
	beq.s	.nx
.c2:	dbf	d1,.c1
	move.w	RmnSeenN,d1
	cmp.w	#RMN_SEENMAX,d1
	bcc.s	.nx
	addq.w	#1,RmnSeenN
	move.l	d0,(a2)
	move.w	4(a1),d0
	bsr	RmnScX
	move.w	d0,4(a1)
	move.w	6(a1),d0
	bsr	RmnScY
	move.w	d0,6(a1)
.nx:	move.l	16(a1),d0		; it_NextText
	bne.s	.s
	bra.s	.h
.x:	movem.l	(sp)+,d0-d2/a0-a2
	rts

; ---- RmnImage: A0 = planar image data, D0 = width, D1 = height, D2 = depth (planes one after the
; other, rows of whole words, as an Image's ImageData) -> D0 = a copy BX x BY times as big (each bit
; BX across, each row BY down), remembered for RmnDrawImage; 0 = no memory (drawn small).
RmnImage:
	movem.l	d1-d7/a0-a6,-(sp)
	move.l	a0,a4			; a4 = the source
	move.w	d0,d6			; d6 = width
	move.w	d1,d7			; d7 = height
	move.w	d2,d5			; d5 = planes
	moveq	#0,d4
	move.w	RmnImgN,d4
	cmp.w	#RMN_IMGMAX,d4
	bcc	.no
	moveq	#0,d2
	move.w	d6,d2
	add.w	#15,d2
	lsr.w	#4,d2
	add.w	d2,d2			; d2 = source bytes a row
	move.w	d2,d0
	mulu.w	RmnBX,d0
	cmp.l	#RMN_ROWMAX,d0
	bhi	.no
	moveq	#0,d3
	move.w	d6,d3
	mulu.w	RmnBX,d3
	add.l	#15,d3
	lsr.l	#4,d3
	add.l	d3,d3			; d3 = copy bytes a row
	move.l	d3,d0
	mulu.w	d7,d0
	mulu.w	RmnBY,d0
	mulu.w	d5,d0			; the copy's size
	move.l	d0,d1
	mulu.w	#12,d4
	lea	RmnImgTab,a5
	add.l	d4,a5			; a5 = the table entry
	move.l	d1,8(a5)
	move.l	#$10001,d1		; MEMF_PUBLIC|MEMF_CLEAR (drawn on RTG screens only: any memory)
	move.l	4.w,a6
	jsr	-198(a6)		; AllocMem
	tst.l	d0
	beq.s	.no
	move.l	a4,(a5)
	move.l	d0,4(a5)
	addq.w	#1,RmnImgN
	move.l	d0,a3			; a3 = where the copy's rows go
	move.l	a4,a0
	mulu.w	d5,d7			; rows of all planes
	subq.w	#1,d7
.row:	lea	RmnRow,a1
	bsr	RmnExpand		; the row, BX times as wide, in RmnRow
	add.l	d2,a0
	move.w	RmnBY,d4
	subq.w	#1,d4
.dup:	lea	RmnRow,a1		; BY copies of its first d3 bytes
	move.w	d3,d1
	subq.w	#1,d1
.cp:	move.b	(a1)+,(a3)+
	dbf	d1,.cp
	dbf	d4,.dup
	dbf	d7,.row
	move.l	4(a5),d0
	bra.s	.x
.no:	moveq	#0,d0
.x:	movem.l	(sp)+,d1-d7/a0-a6
	rts

; ---- RmnImageUse: A0 = planar image data (the key RmnDrawImage looks for), A1 = a ready drawn copy
; of it, BX x BY times as big, in RmnImage's layout (planes one after the other, rows of whole
; words) -> D0 = A1, remembered for RmnDrawImage (never freed: the caller's), or 0 = no room.
RmnImageUse:
	movem.l	d1/a2,-(sp)
	moveq	#0,d0
	move.w	RmnImgN,d1
	cmp.w	#RMN_IMGMAX,d1
	bcc.s	.x
	mulu.w	#12,d1
	lea	RmnImgTab,a2
	add.l	d1,a2
	move.l	a0,(a2)+
	move.l	a1,(a2)+
	clr.l	(a2)			; size 0: not ours to free
	addq.w	#1,RmnImgN
	move.l	a1,d0
.x:	movem.l	(sp)+,d1/a2
	rts

; ---- RmnDrawImage: A0 = RastPort, A1 = the menu's Image (small), D0/D1 = where, in layout pixels,
; inside the window's border (the Image's LeftEdge/TopEdge are added to it), D2/D3 = the window's
; real BorderLeft/BorderTop. Draws its RmnImage copy centred in the picture's scaled place (the
; scaled x, y, width and height, plus the border), or the small picture at the scaled x, y when
; there is no copy.
RmnDrawImage:
	movem.l	d0-d7/a0-a2/a6,-(sp)
	add.w	(a1),d0
	add.w	2(a1),d1
	move.w	d2,d4			; d4/d5 = the border
	move.w	d3,d5
	move.w	d1,d6			; d6 = y
	lea	RmnTmpImg,a2		; a copy of the Image at 0,0
	move.l	(a1),(a2)
	move.l	4(a1),4(a2)
	move.l	8(a1),8(a2)
	move.l	12(a1),12(a2)
	move.l	16(a1),16(a2)
	clr.l	(a2)
	move.l	10(a1),d2		; ImageData: is there a big copy?
	lea	RmnImgTab,a1
	move.w	RmnImgN,d3
	bra.s	.f2
.f1:	cmp.l	(a1),d2
	beq.s	.big
	lea	12(a1),a1
.f2:	dbf	d3,.f1
	bsr	RmnScX			; none: the small one at the scaled place
	add.w	d4,d0
	move.w	d0,d7
	move.w	d6,d0
	bsr	RmnScY
	add.w	d5,d0
	move.w	d0,d1
	move.w	d7,d0
	bra.s	.draw
.big:	move.l	4(a1),10(a2)
	move.w	4(a2),d1		; x: the place's width less the copy's, halved
	bsr	RmnSpX
	move.w	4(a2),d2
	mulu.w	RmnBX,d2
	move.w	d2,4(a2)
	sub.w	d2,d1
	asr.w	#1,d1
	bsr	RmnScX
	add.w	d1,d0
	add.w	d4,d0
	move.w	d0,d7			; d7 = x'
	move.w	d6,d0			; y likewise
	move.w	6(a2),d1
	bsr	RmnSpY
	move.w	6(a2),d2
	mulu.w	RmnBY,d2
	move.w	d2,6(a2)
	sub.w	d2,d1
	asr.w	#1,d1
	bsr	RmnScY
	add.w	d1,d0
	add.w	d5,d0
	move.w	d0,d1
	move.w	d7,d0
.draw:	move.l	a2,a1
	ext.l	d0
	ext.l	d1
	move.l	RmnInt,a6
	jsr	-114(a6)		; DrawImage
	movem.l	(sp)+,d0-d7/a0-a2/a6
	rts

; ---- RmnBorders: A0 = the menu's screen. 4:3: fills the screen left and right of the layout block,
; under the screen's title bar, with a dark grey (a pen obtained for it and let go again: on a hi- or
; true-colour screen the pixels keep their colour). The menu's windows are all inside the block, so
; nothing draws over the borders later. Call after the screen is open and again whenever it may have
; been cleared (cheap). Keeps every register.
RmnBorders:
	movem.l	d0-d7/a0-a3/a6,-(sp)
	tst.b	RmnNative
	beq	.x
	move.w	RmnOX,d6		; d6 = the left border's width
	beq	.x
	move.l	a0,a2			; a2 = the screen
	move.l	48(a2),a0		; sc_ViewPort.vp_ColorMap
	move.l	#$1c1c1c1c,d1
	move.l	d1,d2
	move.l	d1,d3
	sub.l	a1,a1
	move.l	RmnGfx,a6
	jsr	-840(a6)		; ObtainBestPenA
	move.l	d0,d7			; d7 = the pen
	bmi	.x
	lea	84(a2),a3		; sc_RastPort
	move.l	a3,a1
	jsr	-342(a6)		; SetAPen
	move.l	a3,a1
	moveq	#0,d0
	bsr.s	.top
	move.w	d6,d2
	subq.w	#1,d2
	move.w	RmnH,d3
	subq.w	#1,d3
	jsr	-306(a6)		; RectFill: left
	move.w	RmnLW,d0
	bsr	RmnScX
	add.w	RmnOX,d0
	move.w	RmnW,d2
	subq.w	#1,d2
	cmp.w	d0,d2
	blt.s	.rel
	bsr.s	.top
	move.w	RmnH,d3
	subq.w	#1,d3
	move.l	a3,a1
	jsr	-306(a6)		; RectFill: right
.rel:	move.l	48(a2),a0
	move.l	d7,d0
	jsr	-948(a6)		; ReleasePen
.x:	movem.l	(sp)+,d0-d7/a0-a3/a6
	rts
.top:	moveq	#0,d1			; the first row under the title bar
	move.b	30(a2),d1		; sc_BarHeight
	addq.w	#1,d1
	rts

; ---- RmnPatchBevels: A0/A1 = the code range of a GadToolsBox source's Render routines, D0 = how
; many bevels the emulator expects there, D1 = 0: only count, 1: rewrite -> D0 = how many were found.
; Rewrites only when that is the number expected: each bevel call
;	303C xxxx D044 323C yyyy D245 343C wwww 363C hhhh 4EAE FF88
;	(move.w #x,d0 / add.w d4,d0 / move.w #y,d1 / add.w d5,d1 / move.w #w,d2 / move.w #h,d3 /
;	jsr DrawBevelBoxA(a6))
; gets its last 8 bytes rewritten as "jsr RmnBevel / dc.w h", then the caches are cleared.
RmnPatchBevels:
	movem.l	d1-d3/a0-a2/a6,-(sp)
	move.l	d0,d3
	move.l	d1,-(sp)
	moveq	#0,d2			; pass 0: count, pass 1: write
	bsr.s	.scan
	tst.l	(sp)+
	beq.s	.x
	cmp.l	d3,d0
	bne.s	.x
	moveq	#1,d2
	bsr.s	.scan
	move.l	d0,-(sp)
	move.l	4.w,a6
	jsr	-636(a6)		; CacheClearU
	move.l	(sp)+,d0
.x:	movem.l	(sp)+,d1-d3/a0-a2/a6
	rts
.scan:	moveq	#0,d0
	move.l	a0,a2
.s:	lea	24(a2),a6
	cmp.l	a1,a6
	bhi.s	.e
	cmp.w	#$303C,(a2)
	bne.s	.nx
	cmp.l	#$D044323C,4(a2)
	bne.s	.nx
	cmp.l	#$D245343C,10(a2)
	bne.s	.nx
	cmp.w	#$363C,16(a2)
	bne.s	.nx
	cmp.l	#$4EAEFF88,20(a2)
	bne.s	.nx
	addq.l	#1,d0
	tst.w	d2
	beq.s	.cnt
	move.w	18(a2),d1		; h
	move.w	#$4EB9,16(a2)		; jsr RmnBevel.l
	move.l	#RmnBevel,18(a2)
	move.w	d1,22(a2)		; dc.w h
.cnt:	lea	24(a2),a2
	bra.s	.s
.nx:	addq.l	#2,a2
	bra.s	.s
.e:	rts

; ---- RmnBevel: a patched GadToolsBox bevel (RmnPatchBevels). A0 = RastPort, A1 = DrawBevelBoxA's
; tags (GTBB_Recessed), A6 = GadToolsBase, D0/D1 = layout x, y + the window border D4/D5, D2 =
; layout w, the word after the call = layout h.
; 4:3 (RmnNative): GadTools draws it, at the scaled place and size (thin lines, the screen's own).
; Whole numbers: Juan's PAL hires bevel (1-pixel rows, 2-pixel columns) with every pixel a BX x BY
; block: top/left in the shine pen, bottom/right in the shadow pen (swapped when recessed). Pens:
; RmnShine, RmnShadow. Keeps every register.
RmnBevel:
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	60(sp),a2		; the return address: h, then go on after it
	move.w	(a2)+,d7		; d7 = h
	move.l	a2,60(sp)
	move.w	d4,RmnBl		; the window's border
	move.w	d5,RmnBt
	tst.b	RmnNative
	beq.s	.chunky
	sub.w	d4,d0			; d0 = x
	sub.w	d5,d1
	move.w	d1,d5			; d5 = y
	move.w	d2,d1
	bsr	RmnSpX
	move.w	d1,d2			; d2 = w'
	bsr	RmnScX
	add.w	RmnBl,d0
	move.w	d0,d4			; d4 = x'
	move.w	d5,d0
	move.w	d7,d1
	bsr	RmnSpY
	move.w	d1,d3			; d3 = h'
	bsr	RmnScY
	add.w	RmnBt,d0
	move.w	d0,d1			; d1 = y'
	move.w	d4,d0
	ext.l	d0
	ext.l	d1
	ext.l	d2
	ext.l	d3
	jsr	-120(a6)		; DrawBevelBoxA (a0 RastPort, a1 tags, a6 GadTools: as called)
	movem.l	(sp)+,d0-d7/a0-a6
	rts
.chunky:
	move.w	d0,d4
	sub.w	RmnBl,d4		; d4 = x
	move.w	d1,d5
	sub.w	RmnBt,d5		; d5 = y
	move.w	d2,d6			; d6 = w
	move.w	RmnShine,RmnPenTL
	move.w	RmnShadow,RmnPenBR
.tg:	move.l	(a1)+,d0		; GTBB_Recessed in the tags?
	beq.s	.tx
	move.l	(a1)+,d1
	cmp.l	#$80080033,d0
	bne.s	.tg
	tst.l	d1
	beq.s	.tg
	move.w	RmnShadow,RmnPenTL
	move.w	RmnShine,RmnPenBR
.tx:	move.l	a0,a3			; a3 = RastPort
	move.l	RmnGfx,a6
	move.l	a3,a1
	moveq	#0,d0			; JAM1
	jsr	-354(a6)		; SetDrMd
	move.l	a3,a1
	move.w	RmnPenTL,d0
	jsr	-342(a6)		; SetAPen
	move.w	d4,d0			; top row: x .. x+w-2
	move.w	d5,d1
	move.w	d4,d2
	add.w	d6,d2
	subq.w	#2,d2
	move.w	d5,d3
	bsr.s	.fill
	move.w	d4,d0			; left column: y .. y+h-1
	move.w	d5,d1
	move.w	d4,d2
	move.w	d5,d3
	add.w	d7,d3
	subq.w	#1,d3
	bsr.s	.fill
	move.w	d4,d0			; second column: y+1 .. y+h-2
	addq.w	#1,d0
	move.w	d5,d1
	addq.w	#1,d1
	move.w	d0,d2
	move.w	d5,d3
	add.w	d7,d3
	subq.w	#2,d3
	bsr.s	.fill
	move.l	a3,a1
	move.w	RmnPenBR,d0
	jsr	-342(a6)		; SetAPen
	move.w	d4,d0			; bottom row: x+1 .. x+w-1
	addq.w	#1,d0
	move.w	d5,d1
	add.w	d7,d1
	subq.w	#1,d1
	move.w	d4,d2
	add.w	d6,d2
	subq.w	#1,d2
	move.w	d1,d3
	bsr.s	.fill
	move.w	d4,d0			; right column: y .. y+h-1
	add.w	d6,d0
	subq.w	#1,d0
	move.w	d5,d1
	move.w	d0,d2
	move.w	d5,d3
	add.w	d7,d3
	subq.w	#1,d3
	bsr.s	.fill
	move.w	d4,d0			; second right column: y+1 .. y+h-2
	add.w	d6,d0
	subq.w	#2,d0
	move.w	d5,d1
	addq.w	#1,d1
	move.w	d0,d2
	move.w	d5,d3
	add.w	d7,d3
	subq.w	#2,d3
	bsr.s	.fill
	movem.l	(sp)+,d0-d7/a0-a6
	rts
; d0..d3 = x1, y1, x2, y2 in layout pixels (inclusive) -> RectFill of their BX x BY blocks
.fill:	cmp.w	d0,d2
	blt.s	.fx
	cmp.w	d1,d3
	blt.s	.fx
	addq.w	#1,d2
	addq.w	#1,d3
	muls.w	RmnBX,d0
	muls.w	RmnBY,d1
	muls.w	RmnBX,d2
	muls.w	RmnBY,d3
	subq.w	#1,d2
	subq.w	#1,d3
	add.w	RmnBl,d0
	add.w	RmnBl,d2
	add.w	RmnBt,d1
	add.w	RmnBt,d3
	move.l	a3,a1
	jmp	-306(a6)		; RectFill
.fx:	rts

; ---- RmnFreeAll: after the menu screen has closed: the scaled images, the disk font (closed), and
; the big font if it is ours and nobody has it open.
RmnFreeAll:
	movem.l	d0-d1/a0-a1/a6,-(sp)
	move.l	RmnDiskTF,d0
	beq.s	.nd
	clr.l	RmnDiskTF
	move.l	d0,a1
	move.l	RmnGfx,a6
	jsr	-78(a6)			; CloseFont
.nd:	move.l	4.w,a6
	lea	RmnImgTab,a0
.i:	tst.w	RmnImgN
	beq.s	.f
	subq.w	#1,RmnImgN
	move.l	a0,-(sp)
	move.l	4(a0),a1
	move.l	8(a0),d0
	beq.s	.nf			; RmnImageUse's: the caller's
	jsr	-210(a6)		; FreeMem
.nf:	move.l	(sp)+,a0
	lea	12(a0),a0
	bra.s	.i
.f:	tst.b	RmnFontOwn
	beq.s	.x
	jsr	-132(a6)		; Forbid
	move.l	RmnFontTF,a1
	tst.w	30(a1)			; tf_Accessors
	bne.s	.keep
	move.l	RmnGfx,a6
	jsr	-486(a6)		; RemFont
	move.l	4.w,a6
	move.l	RmnFontMem,a1
	move.l	RmnFontSize,d0
	jsr	-210(a6)		; FreeMem
	sf	RmnFontOwn
.keep:	jsr	-138(a6)		; Permit
.x:	movem.l	(sp)+,d0-d1/a0-a1/a6
	rts

; ---- RmnMarks: the menu's checkmark and Amiga-key images, sized to the font (tools/menufont.py
; rmmark_<w>x<h>.bin). A0 = the RMM1 blob, A1 = a chip buffer, D2 = its size, D0 = the ink pen,
; D1 = the paper pen (both 0-3: the images are 2 planes) -> D0 = 1: RmnChkImg and RmnKeyImg are
; Images (the window's WA_Checkmark / WA_AmigaKey and GadTools' GTMN_Checkmark / GTMN_AmigaKey);
; 0: not made (bad blob, pens, no room), keep the system's.
RmnMarks:
	movem.l	d1-d7/a0-a3,-(sp)
	cmp.l	#'RMM1',(a0)+
	bne.s	.no
	cmp.w	#3,d0
	bhi.s	.no
	cmp.w	#3,d1
	bhi.s	.no
	moveq	#0,d6
	move.w	d0,d6			; ink
	moveq	#0,d7
	move.w	d1,d7			; paper
	ext.l	d2
	add.l	a1,d2			; the buffer's end
	move.l	a1,a2
	lea	RmnChkImg,a1
	bsr.s	.one
	bmi.s	.no
	lea	RmnKeyImg,a1
	bsr.s	.one
	bmi.s	.no
	moveq	#1,d0
	bra.s	.x
.no:	moveq	#0,d0
.x:	movem.l	(sp)+,d1-d7/a0-a3
	rts
; A0 = width, height, modulo, rows; A1 = the Image; A2 = the buffer (advanced), D2 = its end -> MI
; when it does not fit
.one:	clr.l	(a1)			; ig_LeftEdge, ig_TopEdge
	move.w	(a0)+,4(a1)		; ig_Width
	move.w	(a0)+,d0
	move.w	d0,6(a1)		; ig_Height
	move.w	#2,8(a1)		; ig_Depth
	move.l	a2,10(a1)		; ig_ImageData
	move.b	#3,14(a1)		; ig_PlanePick
	clr.b	15(a1)			; ig_PlaneOnOff
	clr.l	16(a1)			; ig_NextImage
	move.w	(a0)+,d3
	mulu.w	d0,d3			; bytes a plane
	move.l	d3,d0
	add.l	d0,d0
	add.l	a2,d0
	cmp.l	d2,d0
	bhi.s	.full
	move.l	d2,-(sp)
	moveq	#0,d4			; the plane
.pl:	moveq	#0,d1			; paper's bits in this plane: $ff / 0
	btst	d4,d7
	beq.s	.p0
	moveq	#-1,d1
.p0:	moveq	#0,d5			; ink's bits, eor paper's
	btst	d4,d6
	beq.s	.i0
	moveq	#-1,d5
.i0:	eor.b	d1,d5
	move.l	a0,a3
	move.l	d3,d0
	subq.w	#1,d0
.by:	move.b	(a3)+,d2		; 1 = ink: paper eor (ink eor paper)
	and.b	d5,d2
	eor.b	d1,d2
	move.b	d2,(a2)+
	dbf	d0,.by
	addq.w	#1,d4
	cmp.w	#2,d4
	bne.s	.pl
	add.l	d3,a0			; the next image
	move.l	(sp)+,d2
	moveq	#0,d0
	rts
.full:	moveq	#-1,d0
	rts

; ---- RmnMenuAlign: A0 = the window, A1 = its menu strip (GadTools-made), A6 = intuition.
; GadTools starts the text of a CHECKIT item after the checkmark and every other item's text at
; the item's left edge. In a menu (or submenu) that has CHECKIT items this puts the text of the
; others to the left of the ticked ones' text; this moves it to the same column (the CHECKIT
; items' own text start, so it follows the checkmark's width) when it still fits the item
; (before its next text, as a submenu arrow, or its width). Changes only what is not in the
; column already, between ClearMenuStrip and ResetMenuStrip; safe to call again (nothing to do).
RmnMenuAlign:
	movem.l	d0-d4/a0-a5,-(sp)
	move.l	a0,a4
	move.l	a1,a5
	moveq	#0,d3			; look only
	bsr	.strip
	tst.w	d2
	beq.s	.x
	move.l	a4,a0
	jsr	-54(a6)			; ClearMenuStrip
	moveq	#1,d3			; change
	bsr	.strip
	move.l	a4,a0
	move.l	a5,a1
	jsr	-702(a6)		; ResetMenuStrip
.x:	movem.l	(sp)+,d0-d4/a0-a5
	rts
.strip:	moveq	#0,d2			; items to move
	move.l	a5,a2
.m:	move.l	a2,d0
	beq.s	.mx
	move.l	18(a2),a3		; mu_FirstItem
	bsr	.items
	move.l	(a2),a2			; mu_NextMenu
	bra.s	.m
.mx:	rts
; A3 = the first item of a menu or submenu
.items:	move.l	a3,a0			; the column: the first CHECKIT text item's text start
	moveq	#-1,d1
.f:	move.l	a0,d0
	beq.s	.fd
	move.w	12(a0),d0		; mi_Flags
	and.w	#3,d0			; CHECKIT | ITEMTEXT
	cmp.w	#3,d0
	bne.s	.fn
	move.l	18(a0),a1		; mi_ItemFill: the IntuiText
	move.w	4(a1),d1		; it_LeftEdge
	bra.s	.fd
.fn:	move.l	(a0),a0
	bra.s	.f
.fd:	move.l	a3,a0
.s:	move.l	a0,d0
	beq.s	.sx
	tst.w	d1
	bmi.s	.sub
	move.w	12(a0),d0
	and.w	#3,d0
	cmp.w	#2,d0			; text, no CHECKIT
	bne.s	.sub
	move.l	18(a0),a1
	cmp.w	4(a1),d1
	ble.s	.sub			; in the column (or right of it) already
	movem.l	d1/a0-a1,-(sp)
	move.l	a1,a0
	jsr	-330(a6)		; IntuiTextLength (this text only)
	movem.l	(sp)+,d1/a0-a1
	add.w	d1,d0			; its end in the column
	move.l	16(a1),d4		; it_NextText (the submenu arrow, a command)?
	beq.s	.w
	move.l	d4,a1
	move.w	4(a1),d4		; up to it
	bra.s	.c
.w:	move.w	8(a0),d4
	tst.l	28(a0)			; mi_SubItem: room for the arrow
	beq.s	.c
	sub.w	d1,d4
.c:	cmp.w	d4,d0
	bgt.s	.sub			; does not fit: leave it
	addq.w	#1,d2
	tst.w	d3
	beq.s	.sub
	move.l	18(a0),a1
	move.w	d1,4(a1)
.sub:	move.l	28(a0),d0		; mi_SubItem
	beq.s	.nx
	movem.l	d1/a0/a3,-(sp)
	move.l	d0,a3
	bsr	.items
	movem.l	(sp)+,d1/a0/a3
.nx:	move.l	(a0),a0			; mi_NextItem
	bra.s	.s
.sx:	rts

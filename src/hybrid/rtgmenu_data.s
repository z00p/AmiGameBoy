; rtgmenu_data.s - the variables of rtgmenu.s (MIT, see ../LICENSE). INCLUDE in a data section.
	CNOP	0,4
RmnGfx:		DC.L	0		; graphics.library (caller)
RmnInt:		DC.L	0		; intuition.library (caller)
RmnP96:		DC.L	0		; Picasso96API.library (caller)
RmnDisk:	DC.L	0		; diskfont.library (caller, RmnFontDisk only)
RmnW:		DC.W	0		; the mode's size (RmnSetup)
RmnH:		DC.W	0
RmnLW:		DC.W	640		; the layout's size
RmnLH:		DC.W	212
RmnSXn:		DC.W	1		; the scales: X = SXn / SXd, Y = SYn / SYd
RmnSXd:		DC.W	1
RmnSYn:		DC.W	1
RmnSYd:		DC.W	1
RmnBX:		DC.W	1		; the pictures' whole-number blocks
RmnBY:		DC.W	1
RmnFontH:	DC.W	8		; the menu font's height (RmnFont*)
RmnOX:		DC.W	0		; the layout block's place on the screen
RmnOY:		DC.W	0
RmnBar0:	DC.W	11		; window tops: the small screen title bar (caller) ...
RmnBar1:	DC.W	11		; ... and the big one (caller, after RmnFont: font height + 3)
RmnShine:	DC.W	2		; bevel pens (caller: the screen's SHINEPEN, SHADOWPEN)
RmnShadow:	DC.W	1
RmnPenTL:	DC.W	0		; (RmnBevel)
RmnPenBR:	DC.W	0
RmnBl:		DC.W	0
RmnBt:		DC.W	0
RmnBx:		DC.W	0,0,0,0
RmnSeenN:	DC.W	0
RmnImgN:	DC.W	0
RmnFontOwn:	DC.B	0
RmnNative:	DC.B	0		; 4:3: frames, bevels and text at the screen's own size
		EVEN
	CNOP	0,4
RmnFontTF:	DC.L	0
RmnFontMem:	DC.L	0
RmnFontSize:	DC.L	0
RmnDiskTF:	DC.L	0		; the disk font (RmnFontDisk), open
RmnTTA:		DC.L	0		; its TextAttr (name, size, style, flags) and a spare long
		DC.W	0,0
		DC.L	0
RmnDiskInf:	DC.W	0,0,0,0		; RmnFontDisk: width at 50, height asked, width, height got
RmnRP:		DS.B	100		; RmnFontDisk: a RastPort to measure in
RmnTA:		DC.L	0		; the big font's TextAttr (name, size, style, flags)
		DC.W	0,0
RmnTryTags:	DC.L	$80000032,0	; SA_DisplayID
		DC.L	$80000023,0	; SA_Width
		DC.L	$80000024,0	; SA_Height
		DC.L	$80000025,0	; SA_Depth
		DC.L	$80000037,1	; SA_Behind
		DC.L	$80000038,1	; SA_Quiet
		DC.L	$80000036,0	; SA_ShowTitle
		DC.L	0,0
RmnTmpImg:	DS.B	20
RmnChkImg:	DS.B	20		; RmnMarks: the checkmark Image
RmnKeyImg:	DS.B	20		; ... and the Amiga-key Image
	CNOP	0,4
RmnImgTab:	DS.B	12*RMN_IMGMAX	; source data, copy, copy size
RmnSeen:	DS.L	RMN_SEENMAX
RmnRow:		DS.B	RMN_ROWMAX
	CNOP	0,4

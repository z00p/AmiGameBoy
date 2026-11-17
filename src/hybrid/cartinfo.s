; AmiGameBoy hybrid: the menu's cartridge info panel from the header (1.0.1).
; Juan's table (AmiGameBoy_Menu.asm, Insert) masks $147 with 7, $148 with 7 and $149 with
; 3, so an MBC5 cartridge ($19) showed as MBC1, a 1 MB ROM as "?????" and 128 KB of RAM
; ($04) as None. HyCartInfo runs after his three lines and sets the same three IntuiText
; strings from the whole header bytes: mapper and extras ($147), ROM size ($148, 32 KB to
; 8 MB and the 1.1/1.2/1.5 MB codes), RAM size ($149, None to 128 KB; MBC2 has its 512 x 4
; bits in the mapper). Display only: BattKbs (the .sav size) is still Juan's.
; In: a0 = DirCart (the cartridge's header at $80+$100). All registers kept.
; Off with NO_CARTINFO (= the previous binary).

	SECTION	hycartinfo,CODE
HyCartInfo:
	movem.l	d0-d1/a1,-(sp)
	moveq	#0,d0
	move.b	$80+$147(a0),d0		; cartridge type
	lea	HyCtTab(pc),a1
.type:	move.w	(a1)+,d1
	bmi.s	.tnone
	cmp.w	d1,d0
	beq.s	.tfound
	addq.l	#4,a1
	bra.s	.type
.tnone:	lea	HyCtUnk(pc),a1
.tfound:
	move.l	(a1),MainMenuText15+$C

	moveq	#0,d0
	move.b	$80+$148(a0),d0		; ROM size: 32 KB << n, $52-$54
	cmp.w	#8,d0
	bls.s	.rom
	sub.w	#$52-9,d0
	cmp.w	#9,d0
	blo.s	.rbad
	cmp.w	#11,d0
	bls.s	.rom
.rbad:	moveq	#12,d0
.rom:	move.l	HyRomTab(pc,d0.w*4),MainMenuText16+$C

	moveq	#0,d0
	move.b	$80+$149(a0),d0		; RAM size
	bne.s	.ram
	move.b	$80+$147(a0),d1		; MBC2: RAM in the mapper, $149 = 0
	cmp.b	#5,d1
	beq.s	.mbc2
	cmp.b	#6,d1
	bne.s	.ram
.mbc2:	moveq	#7,d0
	bra.s	.ram2
.ram:	cmp.w	#5,d0
	bls.s	.ram2
	moveq	#6,d0
.ram2:	move.l	HyRamTab(pc,d0.w*4),MainMenuText17+$C
	movem.l	(sp)+,d0-d1/a1
	rts

HyRomTab:
	dc.l	tTipoROM0,tTipoROM1,tTipoROM2,tTipoROM3,tTipoROM4	; 32-512 KB (Juan's)
	dc.l	HyRom1M,HyRom2M,HyRom4M,HyRom8M
	dc.l	HyRom11,HyRom12,HyRom15
	dc.l	tTipoROM5				; "?????"
HyRamTab:
	dc.l	tTipoRAM0,tTipoRAM1,tTipoRAM2,tTipoRAM3	; None, 2, 8, 32 KB (Juan's)
	dc.l	HyRam128,HyRam64,HyRamUnk,HyRamMBC2

; type, string (15 characters, as Juan's)
HyCtTab:
	dc.w	$00
	dc.l	tTipoCart0		; ROM Only.
	dc.w	$01
	dc.l	tTipoCart1		; ROM+MBC1.
	dc.w	$02
	dc.l	tTipoCart2		; ROM+MBC1+RAM.
	dc.w	$03
	dc.l	tTipoCart3		; MBC1+RAM+Batt.
	dc.w	$05
	dc.l	tTipoCart5		; ROM+MBC2.
	dc.w	$06
	dc.l	tTipoCart6		; ROM+MBC2+Batt.
	dc.w	$08
	dc.l	HyCt08
	dc.w	$09
	dc.l	HyCt09
	dc.w	$0B
	dc.l	HyCt0B
	dc.w	$0C
	dc.l	HyCt0C
	dc.w	$0D
	dc.l	HyCt0D
	dc.w	$0F
	dc.l	HyCt0F
	dc.w	$10
	dc.l	HyCt10
	dc.w	$11
	dc.l	HyCt11
	dc.w	$12
	dc.l	HyCt12
	dc.w	$13
	dc.l	HyCt13
	dc.w	$19
	dc.l	HyCt19
	dc.w	$1A
	dc.l	HyCt1A
	dc.w	$1B
	dc.l	HyCt1B
	dc.w	$1C
	dc.l	HyCt1C
	dc.w	$1D
	dc.l	HyCt1D
	dc.w	$1E
	dc.l	HyCt1E
	dc.w	$20
	dc.l	HyCt20
	dc.w	$22
	dc.l	HyCt22
	dc.w	$FC
	dc.l	HyCtFC
	dc.w	$FD
	dc.l	HyCtFD
	dc.w	$FE
	dc.l	HyCtFE
	dc.w	$FF
	dc.l	HyCtFF
	dc.w	-1
HyCtUnk:
	dc.l	tTipoCart7		; ???????????????

HyCt08:	dc.b	"ROM+RAM.       ",0
HyCt09:	dc.b	"ROM+RAM+Batt.  ",0
HyCt0B:	dc.b	"ROM+MMM01.     ",0
HyCt0C:	dc.b	"MMM01+RAM.     ",0
HyCt0D:	dc.b	"MMM01+RAM+Batt.",0
HyCt0F:	dc.b	"MBC3+Clock+Batt",0
HyCt10:	dc.b	"MBC3+Clk+RAM+Bt",0
HyCt11:	dc.b	"ROM+MBC3.      ",0
HyCt12:	dc.b	"ROM+MBC3+RAM.  ",0
HyCt13:	dc.b	"MBC3+RAM+Batt. ",0
HyCt19:	dc.b	"ROM+MBC5.      ",0
HyCt1A:	dc.b	"ROM+MBC5+RAM.  ",0
HyCt1B:	dc.b	"MBC5+RAM+Batt. ",0
HyCt1C:	dc.b	"MBC5+Rumble.   ",0
HyCt1D:	dc.b	"MBC5+Rumb+RAM. ",0
HyCt1E:	dc.b	"MBC5+Rmb+RAM+Bt",0
HyCt20:	dc.b	"MBC6.          ",0
HyCt22:	dc.b	"MBC7+Sensor.   ",0
HyCtFC:	dc.b	"Pocket Camera. ",0
HyCtFD:	dc.b	"Bandai TAMA5.  ",0
HyCtFE:	dc.b	"HuC3.          ",0
HyCtFF:	dc.b	"HuC1+RAM+Batt. ",0

HyRom1M:	dc.b	"  1Mb",0
HyRom2M:	dc.b	"  2Mb",0
HyRom4M:	dc.b	"  4Mb",0
HyRom8M:	dc.b	"  8Mb",0
HyRom11:	dc.b	"1.1Mb",0
HyRom12:	dc.b	"1.2Mb",0
HyRom15:	dc.b	"1.5Mb",0

HyRam128:	dc.b	"128K",0
HyRam64:	dc.b	"64Kb",0
HyRamUnk:	dc.b	"????",0
HyRamMBC2:	dc.b	" ",$bd,"Kb",0		; 512 x 4 bits in the mapper
	even
	SECTION	hybrid,CODE

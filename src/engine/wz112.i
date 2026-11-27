; wz112.i - the Wzonka-Lad 1.12 switches (Ville Helin's wzonka-lad, Nov 2026).
; Included by wz_engine.s, and by hybrid.asm before sound.s (which comes before the engine);
; only the first include counts. Each fix is behind its own WZ112_ switch, in wz112.s and
; wz112snd.s (their own hunks) and in the engine and sound.s, where every change keeps the size
; of what it replaces (68030 I-cache layout). WZ_SYNC112 turns on the ones listed here;
; WZ112_NOTIMER keeps WZ112_TIMER (and what needs it) out (the AGA 030 program).
; docs/wz112-log.md has the list and the tests. Off: the build is byte-identical to the one before.
		IFND	WZ112_I
WZ112_I		equ	1
		IFD	WZ_SYNC112
		IFND	WZ112_UNUSEDIO
WZ112_UNUSEDIO	equ	1			;$FF27-$FF2F read $FF; unused I/O writes dropped
		ENDC
		IFND	WZ112_IFWRITE
WZ112_IFWRITE	equ	1			;IF/IE writes: a pending interrupt before the next fetch
		ENDC
		IFND	WZ112_JOYIRQ
WZ112_JOYIRQ	equ	1			;joypad IF on falling edges of the selected lines
		ENDC
		IFND	WZ112_TIMER
		IFND	WZ112_NOTIMER			;(WZ112_NOTIMER: the AGA 030 program)
WZ112_TIMER	equ	1			;DIV/TIMA from a 16-bit divider at the CPU's cycle
		ENDC
		ENDC
		IFND	WZ112_APUOFF
WZ112_APUOFF	equ	1			;DMG: length writes while the APU is off; CGB: cleared
		ENDC
		IFND	WZ112_APULEN
WZ112_APULEN	equ	1			;the extra length clock on NRx4 enable and trigger
		ENDC
		IFND	WZ112_SWEEP
WZ112_SWEEP	equ	1			;sweep: negate then add disables channel 1
		ENDC
		IFD	WZ112_TIMER
		IFND	WZ112_APUSEQ
WZ112_APUSEQ	equ	1			;frame sequencer from the divider (DIV-APU)
		ENDC
		IFND	WZ112_WAVE
WZ112_WAVE	equ	1			;DMG wave RAM while channel 3 plays, retrigger
		ENDC
		ENDC
		ENDC
		IFD	WZ112_TIMER
		IFD	NO_DIVRATE
		FAIL	"WZ112_TIMER needs the DIV rate (no NO_DIVRATE)"
		ENDC
		IFD	NO_LINE114
		FAIL	"WZ112_TIMER needs NO_LINE114 off"
		ENDC
WZ112_IFW	equ	1			;(the IF/IE write handlers)
		ELSE
		IFD	WZ112_IFWRITE
WZ112_IFW	equ	1
		ENDC
		IFD	WZ112_APUSEQ
		FAIL	"WZ112_APUSEQ needs WZ112_TIMER (the divider)"
		ENDC
		IFD	WZ112_WAVE
		FAIL	"WZ112_WAVE needs WZ112_TIMER (its clock)"
		ENDC
		ENDC
		IFD	WZ112_APUOFF			;WZ112_SND: one of the sound ones (sound.s,
WZ112_SND	equ	1			;wz112snd.s)
		ELSE
		IFD	WZ112_APULEN
WZ112_SND	equ	1
		ELSE
		IFD	WZ112_SWEEP
WZ112_SND	equ	1
		ELSE
		IFD	WZ112_APUSEQ
WZ112_SND	equ	1
		ELSE
		IFD	WZ112_WAVE
WZ112_SND	equ	1
		ENDC
		ENDC
		ENDC
		ENDC
		ENDC
		IFD	WZ112_APUSEQ			;WZ112_APUDUE: the DIV-APU edges planned
		IFND	SPIKE				;(hybrid only)
WZ112_APUDUE	equ	1
		ENDC
		ENDC
		IFD	WZ112_APUSEQ			;WZ112_APURD: LDH A,(n) / LD A,(C) of
WZ112_APURD	equ	1			;$FF10-$FF3F through wz_tread (NR52, wave)
		ELSE
		IFD	WZ112_WAVE
WZ112_APURD	equ	1
		ENDC
		ENDC
		IFD	WZ112_IFW
WZ112_ANY	equ	1
		ELSE
		IFD	WZ112_UNUSEDIO
WZ112_ANY	equ	1
		ELSE
		IFD	WZ112_JOYIRQ
WZ112_ANY	equ	1
		ELSE
		IFD	WZ112_SND
WZ112_ANY	equ	1
		ENDC
		ENDC
		ENDC
		ENDC
		ENDC					;WZ112_I

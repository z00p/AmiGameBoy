
Dissasembler:
	DC.B	'NOP',0			; 00
	DC.B	'LD   BC,$a',0
	DC.B	'LD   (BC),A',0
	DC.B	'INC  BC',0
	DC.B	'INC  B',0
	DC.B	'DEC  B',0
	DC.B	'LD   B,$a',0
	DC.B	'RLCA',0

	DC.B	'LD ($b),SP',0		; 08
	DC.B	'ADD  HL,BC',0
	DC.B	'LD   A,(BC)',0
	DC.B	'DEC  BC',0
	DC.B	'INC  C',0
	DC.B	'DEC  C',0
	DC.B	'LD   C,$a',0
	DC.B	'RRCA',0

	DC.B	'STOP',0 		; 10
	DC.B	'LD   DE,$b',0
	DC.B	'LD   (DE),A',0
	DC.B	'INC  DE',0
	DC.B	'INC  D',0
	DC.B	'DEC  D',0
	DC.B	'LD   D,$a',0
	DC.B	'RLA',0

	DC.B	'JR   $a',0		; 18
	DC.B	'ADD  HL,DE',0
	DC.B	'LD   A,(DE)',0
	DC.B	'DEC  DE',0
	DC.B	'INC  E',0
	DC.B	'DEC  E',0
	DC.B	'LD   E,$a',0
	DC.B	'RRA',0

	DC.B	'JR   NZ,$a',0		; 20
	DC.B	'LD   HL,$b',0
	DC.B	'LD   (HL)+,A',0
	DC.B	'INC  HL',0
	DC.B	'INC  H',0
	DC.B	'DEC  H',0
	DC.B	'LD   H,$a',0
	DC.B	'DAA',0

	DC.B	'JR   Z,$a',0		; 28
	DC.B	'ADD  HL,HL',0
	DC.B	'LD   A,(HL)+',0
	DC.B	'DEC  HL',0
	DC.B	'INC  L',0
	DC.B	'DEC  L',0
	DC.B	'LD   L,$a',0
	DC.B	'CPL',0

	DC.B	'JR   NC,$a',0		; 30
	DC.B	'LD   SP,$b',0
	DC.B	'LD   (HL)-,A',0
	DC.B	'INC  SP',0
	DC.B	'INC  (HL)',0
	DC.B	'DEC  (HL)',0
	DC.B	'LD   (HL),$a',0
	DC.B	'SCF',0

	DC.B	'JR   C,$a',0		; 38
	DC.B	'ADD  HL,SP',0
	DC.B	'LD   A,(HL)-',0
	DC.B	'DEC  SP',0
	DC.B	'INC  A',0
	DC.B	'DEC  A',0
	DC.B	'LD   A,$a',0
	DC.B	'CCF',0

	DC.B	'LD   B,B',0		; 40
	DC.B	'LD   B,C',0
	DC.B	'LD   B,D',0
	DC.B	'LD   B,E',0
	DC.B	'LD   B,H',0
	DC.B	'LD   B,L',0
	DC.B	'LD   B,(HL)',0
	DC.B	'LD   B,A',0

	DC.B	'LD   C,B',0		; 48
	DC.B	'LD   C,C',0
	DC.B	'LD   C,D',0
	DC.B	'LD   C,E',0
	DC.B	'LD   C,H',0
	DC.B	'LD   C,L',0
	DC.B	'LD   C,(HL)',0
	DC.B	'LD   C,A',0

	DC.B	'LD   D,B',0		; 50
	DC.B	'LD   D,C',0
	DC.B	'LD   D,D',0
	DC.B	'LD   D,E',0
	DC.B	'LD   D,H',0
	DC.B	'LD   D,L',0
	DC.B	'LD   D,(HL)',0
	DC.B	'LD   D,A',0

	DC.B	'LD   E,B',0		; 58
	DC.B	'LD   E,C',0
	DC.B	'LD   E,D',0
	DC.B	'LD   E,E',0
	DC.B	'LD   E,H',0
	DC.B	'LD   E,L',0
	DC.B	'LD   E,(HL)',0
	DC.B	'LD   E,A',0

	DC.B	'LD   H,B',0		; 60
	DC.B	'LD   H,C',0
	DC.B	'LD   H,D',0
	DC.B	'LD   H,E',0
	DC.B	'LD   H,H',0
	DC.B	'LD   H,L',0
	DC.B	'LD   H,(HL)',0
	DC.B	'LD   H,A',0

	DC.B	'LD   L,B',0		; 68
	DC.B	'LD   L,C',0
	DC.B	'LD   L,D',0
	DC.B	'LD   L,E',0
	DC.B	'LD   L,H',0
	DC.B	'LD   L,L',0
	DC.B	'LD   L,(HL)',0
	DC.B	'LD   L,A',0

	DC.B	'LD   (HL),B',0		; 70
	DC.B	'LD   (HL),C',0
	DC.B	'LD   (HL),D',0
	DC.B	'LD   (HL),E',0
	DC.B	'LD   (HL),H',0
	DC.B	'LD   (HL),L',0
	DC.B	'HALT',0
	DC.B	'LD   (HL),A',0

	DC.B	'LD   A,B',0		; 78
	DC.B	'LD   A,C',0
	DC.B	'LD   A,D',0
	DC.B	'LD   A,E',0
	DC.B	'LD   A,H',0
	DC.B	'LD   A,L',0
	DC.B	'LD   A,(HL)',0
	DC.B	'LD   A,A',0

	DC.B	'ADD  A,B',0		; 80
	DC.B	'ADD  A,C',0
	DC.B	'ADD  A,D',0
	DC.B	'ADD  A,E',0
	DC.B	'ADD  A,H',0
	DC.B	'ADD  A,L',0
	DC.B	'ADD  A,(HL)',0
	DC.B	'ADD  A,A',0

	DC.B	'ADC  A,B',0		; 88
	DC.B	'ADC  A,C',0
	DC.B	'ADC  A,D',0
	DC.B	'ADC  A,E',0
	DC.B	'ADC  A,H',0
	DC.B	'ADC  A,L',0
	DC.B	'ADC  A,(HL)',0
	DC.B	'ADC  A,A',0

	DC.B	'SUB  B',0		; 90
	DC.B	'SUB  C',0
	DC.B	'SUB  D',0
	DC.B	'SUB  E',0
	DC.B	'SUB  H',0
	DC.B	'SUB  L',0
	DC.B	'SUB  (HL)',0
	DC.B	'SUB  A',0

	DC.B	'SBC  A,B',0		; 98
	DC.B	'SBC  A,C',0
	DC.B	'SBC  A,D',0
	DC.B	'SBC  A,E',0
	DC.B	'SBC  A,H',0
	DC.B	'SBC  A,L',0
	DC.B	'SBC  A,(HL)',0
	DC.B	'SBC  A,A',0

	DC.B	'AND  B',0		; A0
	DC.B	'AND  C',0
	DC.B	'AND  D',0
	DC.B	'AND  E',0
	DC.B	'AND  H',0
	DC.B	'AND  L',0
	DC.B	'AND  (HL)',0
	DC.B	'AND  A',0

	DC.B	'XOR  B',0		; A8
	DC.B	'XOR  C',0
	DC.B	'XOR  D',0
	DC.B	'XOR  E',0
	DC.B	'XOR  H',0
	DC.B	'XOR  L',0
	DC.B	'XOR  (HL)',0
	DC.B	'XOR  A',0

	DC.B	'OR   B',0		; B0
	DC.B	'OR   C',0
	DC.B	'OR   D',0
	DC.B	'OR   E',0
	DC.B	'OR   H',0
	DC.B	'OR   L',0
	DC.B	'OR   (HL)',0
	DC.B	'OR   A',0

	DC.B	'CP   B',0		; B8
	DC.B	'CP   C',0
	DC.B	'CP   D',0
	DC.B	'CP   E',0
	DC.B	'CP   H',0
	DC.B	'CP   L',0
	DC.B	'CP   (HL)',0
	DC.B	'CP   A',0

	DC.B	'RET  NZ',0		; C0
	DC.B	'POP  BC',0
	DC.B	'JP   NZ,$b',0
	DC.B	'JP   $b',0
	DC.B	'CALL NZ,$b',0
	DC.B	'PUSH BC',0
	DC.B	'ADD  A,$a',0
	DC.B	'RST  $00',0

	DC.B	'RET  Z',0		; C8
	DC.B	'RET',0
	DC.B	'JP   Z,$b',0
	DC.B	'Ins CB',0 	------ ; CB
	DC.B	'CALL Z,$b',0
	DC.B	'CALL $b',0
	DC.B	'ADC  A,$a',0
	DC.B	'RST  $08',0

	DC.B	'RET  NC',0		; D0
	DC.B	'POP  DE',0
	DC.B	'JP   NC,$b',0
	DC.B	'Ins D3',0 	------ ; D3
	DC.B	'CALL NC,$b',0
	DC.B	'PUSH DE',0
	DC.B	'SUB  $a',0
	DC.B	'RST  $10',0

	DC.B	'RET  C',0		; D8
	DC.B	'RETI',0
	DC.B	'JP   C,$b',0
	DC.B	'Ins DB',0 	------ ; DB
	DC.B	'CALL C,$b',0
	DC.B	'Ins DD',0 	------ ; DD
	DC.B	'SBC  $a',0
	DC.B	'RST  $18',0

	DC.B	'LD   ($FFa),A',0	; E0
	DC.B	'POP  HL',0
	DC.B	'LD   (FF+C),A',0
	DC.B	'Ins E3',0 	------ ; E3
	DC.B	'Ins E4',0 	------ ; E4
	DC.B	'PUSH HL',0
	DC.B	'AND  $a',0
	DC.B	'RST  $20',0

	DC.B	'ADD  SP,$a',0	; E8
	DC.B	'JP   (HL)',0
	DC.B	'LD   ($b),A',0
	DC.B	'Ins EB',0 	------ ; EB
	DC.B	'Ins EC',0 	------ ; EC
	DC.B	'Ins ED',0 	------ ; ED
	DC.B	'XOR  $a',0
	DC.B	'RST  $28',0

	DC.B	'LD   A,($FFa)',0	; F0
	DC.B	'POP  AF',0
	DC.B	'LD   A,(FF+C)',0
	DC.B	'DI',0
	DC.B	'Ins F4',0 	------ ; F4
	DC.B	'PUSH AF',0
	DC.B	'OR   $a',0
	DC.B	'RST  $30',0

	DC.B	'LD   HL,SP+$a',0	; F8
	DC.B	'LD   SP,HL',0
	DC.B	'LD   A,(b)',0
	DC.B	'EI',0
	DC.B	'Ins FC',0 	------ ; FC
	DC.B	'Ins FD',0 	------ ; FD
	DC.B	'CP   $a',0
	DC.B	'RST  $38',0		; FF

DissasemblerCB:
	DC.B	"RLC  c",0	; 00x
	DC.B	"RRC  c",0	; 01x
	DC.B	"RL   c",0	; 10x
	DC.B	"RR   c",0	; 11x
	DC.B	"SLA  c",0	; 20x
	DC.B	"SRA  c",0	; 21x
	DC.B	"SWAP c",0	; 30x
	DC.B	"SRL  c",0	; 31x
	DC.B	"BIT  0,c",0	; 40x
	DC.B	"BIT  1,c",0	; 41x
	DC.B	"BIT  2,c",0	; 50x
	DC.B	"BIT  3,c",0	; 51x
	DC.B	"BIT  4,c",0	; 60x
	DC.B	"BIT  5,c",0	; 61x
	DC.B	"BIT  6,c",0	; 70x
	DC.B	"BIT  7,c",0	; 71x
	DC.B	"RES  0,c",0	; 80x
	DC.B	"RES  1,c",0	; 81x
	DC.B	"RES  2,c",0	; 90x
	DC.B	"RES  3,c",0	; 91x
	DC.B	"RES  4,c",0	; A0x
	DC.B	"RES  5,c",0	; A1x
	DC.B	"RES  6,c",0	; B0x
	DC.B	"RES  7,c",0	; B1x
	DC.B	"SET  0,c",0	; C0x
	DC.B	"SET  1,c",0	; C1x
	DC.B	"SET  2,c",0	; D0x
	DC.B	"SET  3,c",0	; D1x
	DC.B	"SET  4,c",0	; E0x
	DC.B	"SET  5,c",0	; E1x
	DC.B	"SET  6,c",0	; F0x
	DC.B	"SET  7,c",0	; F1x

DissasemblerCD2:
	DC.B	"B",0		; x0
	DC.B	"C",0		; x1
	DC.B	"D",0		; x2
	DC.B	"E",0		; x3
	DC.B	"H",0		; x4
	DC.B	"L",0		; x5
	DC.B	"(HL)",0	; x6
	DC.B	"A",0		; x7

	DS.L	18

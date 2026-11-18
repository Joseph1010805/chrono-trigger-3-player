; generated: CT+ video triggers (see ctp_fmv.asm)
ctpv_table:
	dw $01B1, $0067, $0180 : db $02, 1 : db $04,$02,$33,$16 : dw ctpv_seq0, ctpv_fix0   ; title: the opening
	dw $00E2, $0CAA, $1150 : db $19, 12 : db $71,$08,$71,$07 : dw ctpv_seq1, ctpv_fix1
	dw $0111, $08D0, $0AB4 : db $12, 12 : db $04,$0C,$14,$04 : dw ctpv_seq2, ctpv_fix2
	dw $00A3, $059B, $0909 : db $1D, 12 : db $AD,$30,$AA,$05 : dw ctpv_seq3, ctpv_fix3
	dw $00AC, $08B9, $0935 : db $0E, 12 : db $E8,$94,$E5,$08 : dw ctpv_seq4, ctpv_fix4
	dw $0127, $03A5, $0685 : db $12, 5 : db $E0,$F3,$03,$3F : dw ctpv_seq5, ctpv_fix5
	dw $00F3, $07A1, $0873 : db $11, 14 : db $ED,$01,$E1,$B0 : dw ctpv_seq6, ctpv_fix6
	dw $01A7, $1049, $1382 : db $1C, 12 : db $04,$2C,$43,$11 : dw ctpv_seq7, ctpv_fix7
	dw $FFFF
ctpv_seq0: db $01
ctpv_fix0: dw $0054,$0066,$0103,$FFFF
ctpv_seq1: db $56,$81,$4F,$00,$01,$16,$4F,$00,$01,$03,$C8,$92
ctpv_fix1: dw $FFFF
ctpv_seq2: db $56,$82,$4F,$00,$01,$16,$4F,$00,$01,$03,$C8,$92
ctpv_fix2: dw $FFFF
ctpv_seq3: db $56,$83,$4F,$00,$01,$16,$4F,$00,$01,$03,$C8,$92
ctpv_fix3: dw $FFFF
ctpv_seq4: db $56,$84,$4F,$00,$01,$16,$4F,$00,$01,$03,$C8,$92
ctpv_fix4: dw $08AD,$08B2,$0923,$FFFF
ctpv_seq5: db $56,$05,$4F,$00,$01
ctpv_fix5: dw $FFFF
ctpv_seq6: db $ED,$01,$56,$06,$4F,$00,$01,$16,$4F,$00,$01,$05,$56,$00
ctpv_fix6: dw $0797,$FFFF
ctpv_seq7: db $56,$87,$4F,$00,$01,$16,$4F,$00,$01,$03,$C8,$92
ctpv_fix7: dw $1020,$1025,$102A,$102F,$104D,$FFFF

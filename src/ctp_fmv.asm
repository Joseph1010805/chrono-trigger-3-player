; =====================================================================
; CT+ CUTSCENES.  Chrono Trigger Plus carries the MSU-1 video player but
; never calls it.  The FMV beta this mod's base comes from called video n
; from 7 scene scripts ("56 nn 4F 00" = video number to 7F:004F, "01" =
; play, then "if it played: C8 92" - see fmv notes).  CT+ has the same
; scenes at other offsets, so when one of those scripts is decompressed
; (C0:56FF) we insert the same bytes at the same command, then fix the
; script's function table and the relative jumps that cross the insertion.
; Each entry is checked (object count + 4 signature bytes) first: a
; different CT+ version is simply left alone.
; =====================================================================
!CVP   = $7F1E8B      ; word: insertion offset
!CVLEN = $7F1E8D      ; word: script length
!CVL   = $7F1E8F      ; word: bytes inserted
!CVSEQ = $7F1E91      ; word: the bytes (address in this bank)
!CVFIX = $7F1E93      ; word: jump fix list
!CVREC = $7F1E95      ; word: table record
!CVT   = $7F1E97      ; word: temp

org $C056FF                     ; the field's event script load: "JSL $C30002"
	JSL ctpv_load
org $C05F6E                     ; the "play video" command (CT+: JSL $CEDD00 = data)
	JSL ctpv_play

org !DB2|$1000
ctpv_load:
	JSL $C30002             ; decompress, as before
	PHP
	REP #$30
	PHA
	PHX
	PHY
	PHB
	PHK
	PLB
	LDX #$0000
.find:
	LDA ctpv_table,x
	CMP #$FFFF
	BNE +
	JMP .out
+	CMP.l $7E0100           ; (the map being loaded)
	BEQ .map
	TXA
	CLC
	ADC #$0010
	TAX
	BRA .find
.map:

	TXA
	STA.l !CVREC
	LDA ctpv_table+2,x
	STA.l !CVP
	LDA ctpv_table+4,x
	STA.l !CVLEN
	LDA ctpv_table+7,x
	AND #$00FF
	STA.l !CVL
	LDA ctpv_table+12,x
	STA.l !CVSEQ
	LDA ctpv_table+14,x
	STA.l !CVFIX
	SEP #$20                ; same script?  object count ...
	LDA.l $7F2000
	CMP ctpv_table+6,x
	REP #$20
	BEQ +
	JMP .out
+	LDY #$0000              ; ... and the 4 bytes at the insertion point
.sig:
	TYA
	CLC
	ADC.l !CVP
	TAX
	SEP #$20
	LDA.l $7F2000,x
	STA.l !CVT
	REP #$20
	TYA
	CLC
	ADC.l !CVREC
	TAX
	SEP #$20
	LDA ctpv_table+8,x
	CMP.l !CVT
	REP #$20
	BEQ +
	JMP .out
+	INY
	CPY #$0004
	BNE .sig
	; make room: bytes P..len-1 move up by L (from the top down)
	LDA.l !CVLEN
	DEC
	TAX
.mv:
	SEP #$20
	LDA.l $7F2000,x
	PHX
	REP #$20
	PHA
	TXA
	CLC
	ADC.l !CVL
	TAX
	PLA
	SEP #$20
	STA.l $7F2000,x
	REP #$20
	PLX
	TXA
	CMP.l !CVP
	BEQ +
	DEX
	BRA .mv
+	; the inserted bytes
	LDA.l !CVSEQ
	TAY
	LDA.l !CVP
	TAX
	LDA.l !CVL
	STA.l !CVT
.cp:
	SEP #$20
	LDA $0000,y
	STA.l $7F2000,x
	REP #$20
	INX
	INY
	LDA.l !CVT
	DEC
	STA.l !CVT
	BNE .cp
	; function table: byte 0 = objects, then 16 offsets each; offsets past
	; the insertion point move up
	SEP #$20
	LDA.l $7F2000
	REP #$20
	AND #$00FF
	ASL
	ASL
	ASL
	ASL
	STA.l !CVT
	LDX #$0001
.hd:
	LDA.l $7F2000,x
	CMP.l !CVP
	BEQ .hn
	BCC .hn
	CLC
	ADC.l !CVL
	STA.l $7F2000,x
.hn:
	INX
	INX
	LDA.l !CVT
	DEC
	STA.l !CVT
	BNE .hd
	; relative jumps that cross the insertion point
	LDA.l !CVFIX
	TAY
.fx:
	LDA $0000,y
	CMP #$FFFF
	BEQ .out
	CMP.l !CVP
	BCC +
	CLC
	ADC.l !CVL
+	TAX
	SEP #$20
	LDA.l $7F2000,x
	CLC
	ADC.l !CVL
	STA.l $7F2000,x
	REP #$20
	INY
	INY
	BRA .fx
.out:
	PLB
	PLY
	PLX
	PLA
	PLP
	RTL

; the "play video" command (Y = script position; returns X = next command)
ctpv_play:
	PHP
	PHB
	PHD
	REP #$30
	PHA
	PHX
	PHY
	SEP #$20
	SEI
	LDA.l $7F004F
	STA.l !CVT              ; the number the script asked for (bit 7 kept)
	AND #$7F
	JSL $CDFA00             ; CT+'s player: video number in A
	BCC .played
	LDA #$00                ; no video (no MSU-1 / no data): the script's
	STA.l $7F004F           ; check skips its after-video step
	CLI
	BRA .ret
.played:
	LDA.l !CVT              ; the opening (video 0, from the title): its
	AND #$7F                ; pictures overwrote the title's, so start over
	BNE +                   ; from reset - what the base ROM's player does
	LDA #$80
	STA.l $002100
	LDA #$00
	STA.l $004200
	STA.l $00420C
	JML $C0FF00
+	LDA.l !CVT              ; (CT+'s player clears it; the script reads it)
	STA.l $7F004F
	LDA.l $004210
	CLI
	LDA #$80
	STA.l $002100
	LDA #$FF
	STA.l $00210E
	STA.l $00210E
	LDA #$A1
	STA.l $004200
.ret:
	REP #$30
	PLY
	PLX
	PLA
	PLD
	PLB
	PLP
	TYX
	INX
	CLC
	RTL

incsrc "ctp_vtable.asm"
warnpc !DB2|$2000

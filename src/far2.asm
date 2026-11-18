; =====================================================================
; Bank !DB2 free gap ($E100-$E3FF): a combo proposed to a player.  Their
; whole box becomes the question - who proposes (blinking), the combo,
; "A:Yes B:No" - and A / B answer it from anywhere in the box.
; =====================================================================
str_yesno:	db $A0,$E3,$B8,$BE,$CC,$FF,$A1,$E3,$AD,$C8   ; A:Yes B:No

; after the command view of slot !S (mode 0): a proposal waiting for it
; replaces the box with the question
cm_cell_l:
	LDA.l !S
	%tax8()
	LDA.l !MODE,x
	BEQ +
	RTL
+	JSR cm_pending
	BPL +
	RTL
+	STA.l !CMQ              ; the proposer
	JSR cm_boxx
	LDY #$0006              ; blank the box: 6 tile rows x 10 columns
-	PHX
	LDA #$0A
	STA.l !CMK
--	REP #$20
	LDA #$29FF
	STA.l !BOXBUF,x
	SEP #$20
	INX
	INX
	LDA.l !CMK
	DEC
	STA.l !CMK
	BNE --
	PLX
	REP #$20
	TXA
	CLC
	ADC #$0040
	TAX
	SEP #$20
	DEY
	BNE -
	; line 0: the proposer's name (steady: only the target hands blink)
	LDA.l !BLINK
	AND #$00
	BNE +
	LDA.l !CMQ
	JSL txt_name_l
	JSR cm_boxx
	LDY #$0000
-	PHX
	TYX
	LDA.l !TXT,x
	PLX
	XBA
	LDA #!WHITE
	XBA
	REP #$20
	STA.l !BOXBUF+$40,x
	SEP #$20
	INX
	INX
	INY
	CPY #$0005
	BNE -
+	; line 1: the combo (as much of its name as fits)
	LDA.l !S
	PHA
	LDA.l !CMQ
	STA.l !S
	%tax8()
	LDA.l !CHOICE,x
	STA.l !CMT
	JSR cm_rowid
	STA.l !DI
	PLA
	STA.l !S
	LDA #$01
	STA.l !DT
	JSL name_fetch_l
	JSR cm_boxx
	LDY #$0000
-	TYA
	CMP.l !NL
	BCS +
	CPY #$000A
	BCS +
	PHX
	TYX
	LDA.l !NM,x
	PLX
	XBA
	LDA #!WHITE
	XBA
	REP #$20
	STA.l !BOXBUF+$C0,x
	SEP #$20
	INX
	INX
	INY
	BRA -
+	; line 2: what the buttons do
	JSR cm_boxx
	LDY #$0000
-	PHX
	TYX
	LDA.l str_yesno,x
	PLX
	XBA
	LDA #!WHITE
	XBA
	REP #$20
	STA.l !BOXBUF+$140,x
	SEP #$20
	INX
	INX
	INY
	CPY #$000A
	BNE -
	RTL

; !S's row !CMT -> A = tech id at that row of slot !S's list
cm_rowid:
	LDA.l !S
	REP #$20
	AND #$00FF
	STA.l !TMP
	ASL
	ASL
	CLC
	ADC.l !TMP
	ASL
	ASL
	STA.l !TMP
	LDA.l !CMT
	AND #$00FF
	CLC
	ADC.l !TMP
	TAX
	SEP #$20
	LDA.l !TECHLIST,x
	RTS

; box input of slot !S (mode 0): a proposal waits -> A accepts, B declines,
; and nothing else happens (carry set); else carry clear
cm_askin_l:
	JSR cm_pending
	BPL +
	CLC
	RTL
+	PHA
	LDA.l !T0
	AND #$80
	BEQ +
	PLA
	ORA #$E0
	JSL join_prop_l
	SEC
	RTL
+	LDA.l !T0
	AND #$0A
	BEQ +
	PLA
	JSL combo_cancel_l
	SEC
	RTL
+	PLA
	SEC
	RTL

; ---------------------------------------------------------------------
; THE MOVE'S DESCRIPTION in a player's box while they aim a single tech
; (mode 4) or confirm one that needs no target (mode 9: A = go, B = back).
; The game's description (CC:3A09 + id*2 -> a string in bank CC) is packed
; with a dictionary (bytes $21-$9F -> DE:FA00 table -> length-prefixed
; chunk in bank DE); unpacked into !DBUF, word-wrapped over the 3 lines.

; draw_box: carry set = this box shows the description (drawn)
desc_box_l:
	LDA.l !S
	%tax8()
	LDA.l !MODE,x
	CMP #$09
	BEQ .go
	CMP #$04
	BNE .no
	LDA.l !PROW,x
	CMP #$01
	BNE .no
	LDA.l !PMASK,x
	BNE .no
.go:
	LDA.l !CHOICE,x         ; the tech's id
	STA.l !CMT
	JSR cm_rowid
	CMP #$75                ; (only techs have descriptions)
	BCS .no
	JSR desc_unpack
	JSR desc_wrap
	SEC
	RTL
.no:
	CLC
	RTL

; A = tech id -> !DBUF = its description (letters), !CMK = length
desc_unpack:
	REP #$20
	AND #$00FF
	ASL
	TAX
	LDA.l $CC3A09,x
	TAX                     ; X = the packed string (bank CC)
	SEP #$20
	LDA #$00
	STA.l !CMK
.next:
	LDA.l $CC0000,x
	BEQ .end
	INX
	CMP #$21
	BCC .put
	CMP #$A0
	BCS .put
	PHX                     ; a dictionary chunk
	REP #$20
	AND #$00FF
	SEC
	SBC #$0021
	ASL
	TAX
	LDA.l $DEFA00,x
	TAX
	SEP #$20
	LDA.l $DE0000,x         ; its length
	STA.l !CMI
.chunk:
	INX
	LDA.l $DE0000,x
	JSR desc_put
	LDA.l !CMI
	DEC
	STA.l !CMI
	BNE .chunk
	PLX
	BRA .next
.put:
	JSR desc_put
	BRA .next
.end:
	RTS

; A = a letter -> appended to !DBUF (at most 48)
desc_put:
	PHX
	PHA
	LDA.l !CMK
	CMP #48
	BCS +
	%tax8()
	PLA
	STA.l !DBUF,x
	INX
	TXA
	STA.l !CMK
	PLX
	RTS
+	PLA
	PLX
	RTS

; !DBUF (length !CMK) -> box !S: blanked, then up to 3 lines of 10 letters,
; broken at spaces
desc_wrap:
	JSR cm_boxx
	LDY #$0006
.blrow:
	PHX
	LDA #$0A
	STA.l !CMR
.blcol:
	REP #$20
	LDA #$29FF
	STA.l !BOXBUF,x
	SEP #$20
	INX
	INX
	LDA.l !CMR
	DEC
	STA.l !CMR
	BNE .blcol
	PLX
	REP #$20
	TXA
	CLC
	ADC #$0040
	TAX
	SEP #$20
	DEY
	BNE .blrow
	LDA #$00
	STA.l !CMI              ; read position
	STA.l !CMV              ; line 0..2
.line:
	LDA.l !CMI              ; skip spaces at the line start
	CMP.l !CMK
	BCC +
	RTS
+	%tax8()
	LDA.l !DBUF,x
	CMP #$EF
	BNE +
	LDA.l !CMI
	INC
	STA.l !CMI
	BRA .line
+	LDA.l !CMK              ; n = what's left, at most 10
	SEC
	SBC.l !CMI
	CMP #$0A                ; (9 letters a line: one column of margin)
	BCC .n
	LDA.l !CMI              ; more than fits: break at the last space
	CLC                     ; within the 9 (or after them)
	ADC #$09
	%tax8()
	LDA.l !DBUF,x
	CMP #$EF
	BEQ .ten
-	DEX
	TXA
	CMP.l !CMI
	BEQ .ten                ; one long word: cut it
	LDA.l !DBUF,x
	CMP #$EF
	BNE -
	TXA
	SEC
	SBC.l !CMI
	BRA .n
.ten:
	LDA #$09
.n:
	STA.l !CMR              ; letters on this line
	JSR cm_boxx             ; X = box + line*$80 + $40
	LDA.l !CMV
	REP #$20
	AND #$00FF
	XBA
	LSR
	CLC
	ADC #$0042              ; (+1 column: the margin)
	STA.l !TMP
	TXA
	CLC
	ADC.l !TMP
	TAX
	SEP #$20
-	PHX
	LDA.l !CMI
	%tax8()
	LDA.l !DBUF,x
	PLX
	XBA
	LDA #!WHITE
	XBA
	REP #$20
	STA.l !BOXBUF,x
	SEP #$20
	INX
	INX
	LDA.l !CMI
	INC
	STA.l !CMI
	LDA.l !CMR
	DEC
	STA.l !CMR
	BNE -
	LDA.l !CMV
	INC
	STA.l !CMV
	CMP #$03
	BEQ +
	JMP .line
+	RTS

; pick_target found no target to pick: a single tech confirms first (mode 9,
; carry set); anything else commits at once (carry clear).  X = slot.
desc_gp_l:
	LDA.l !PROW,x
	CMP #$01
	BNE +
	LDA.l !PMASK,x
	BNE +
	LDA #$09
	STA.l !MODE,x
	SEC
	RTL
+	CLC
	RTL

; mode 9 input (slot !S): A = go, B = back to the list
desc_conf_l:
	LDA.l !S
	%tax8()
	LDA.l !T0
	AND #$80
	BEQ +
	JSL commit_l
	RTL
+	LDA.l !T0
	AND #$0A
	BEQ +
	LDA.l !PROW,x
	STA.l !MODE,x
+	RTL

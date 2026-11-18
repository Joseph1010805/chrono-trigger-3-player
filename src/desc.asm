; ---------------------------------------------------------------------
; HOLD X = DESCRIPTION.  While a player holds X with their Tech or Item list
; open, the top window shows "Name: <the game's description>" of the entry
; under their cursor.  The last player to press X wins; when they let go it
; passes to anyone still holding it.  The text goes through the game's own
; battle message code exactly as its own tech descriptions do (the same
; entry, CD:0310, only with our string): it never interrupts a battle
; message, and it steps aside for the target picker and the game's lists.

; battle_input, after each player's pad: X = player*2, !SCR = raw pad
rec_x:
	PHP
	SEP #$20
	PHX
	TXA
	LSR
	%tax8()
	LDA.l !SCR
	AND #$40
	BEQ +
	LDA.l bitmask,x
	ORA.l !XHELD
	BRA ++
+	LDA.l bitmask,x
	EOR #$FF
	AND.l !XHELD
++	STA.l !XHELD
	PLX
	PLP
	RTS

desc_tick:
	LDA.l !XPREV            ; a new press takes the description
	EOR #$FF
	AND.l !XHELD
	STA.l !DQ
	LDA.l !XHELD
	STA.l !XPREV
	LDA.l !DQ
	BEQ .keep
	LDX #$0000
-	LDA.l !DQ
	AND.l bitmask,x
	BEQ +
	TXA
	INC
	STA.l !DESCP
+	INX
	CPX #$0003
	BNE -
.keep:
	LDA.l !DESCP            ; its owner let go: anyone still holding X
	BEQ .anyone
	CMP #$04
	BCS .anyone
	DEC
	%tax8()
	LDA.l bitmask,x
	AND.l !XHELD
	BNE .have
.anyone:
	LDA #$00
	STA.l !DESCP
	LDX #$0000
-	LDA.l !XHELD
	AND.l bitmask,x
	BEQ +
	TXA
	INC
	STA.l !DESCP
	BRA .have
+	INX
	CPX #$0003
	BNE -
	JMP desc_hide
.have:
	LDA.l !SUBWIN           ; the game's own list or target picker has the window
	ORA.l !TARGET
	BEQ +
	RTS
+	LDA.l !DESCP
	STA.l !DSP
	JSR desc_entry
	BCC .got
	LDX #$0000              ; not in a list: another player holding X may be
-	LDA.l !XHELD
	AND.l bitmask,x
	BEQ +
	TXA
	INC
	CMP.l !DESCP
	BEQ +
	STA.l !DSP
	PHX
	JSR desc_entry
	PLX
	BCC .got
+	INX
	CPX #$0003
	BNE -
	JMP desc_hide           ; nobody holding X has a list open
.got:
	JSR desc_mine
	BCS .new
	LDA.l !DT
	CMP.l !DKEY
	BNE .new
	LDA.l !DI
	CMP.l !DKEY+1
	BNE .new
	LDA.l !DSP
	CMP.l !DKEY+2
	BNE .new
	LDA.l $7ECD05           ; same text: keep it up while X is held
	BNE +
	LDA #$40
	STA.l $7ECCEB
+	RTS
.new:
	JMP desc_show

; A = player+1 -> carry clear and !S, !DT, !DI = the entry under their cursor
desc_entry:
	DEC
	%tax8()
	LDA.l !SEL,x
	CMP #$03
	BCS .no
	STA.l !S
	%tax8()
	LDA.l !READY,x
	BMI .no
	LDA.l !MODE,x
	CMP #$01
	BEQ .tech
	CMP #$02
	BEQ .item
.no:
	SEC
	RTS
.item:
	LDA #$02
	STA.l !DT
	LDA.l !LPOS,x
	REP #$20
	AND #$00FF
	STA.l !TMP
	ASL
	ASL
	CLC
	ADC.l !TMP
	TAX
	SEP #$20
	LDA.l !ITEMLIST,x
	BEQ .no
	CMP #$F2                ; the description table has 242 entries
	BCS .no
	STA.l !DI
	CLC
	RTS
.tech:
	LDA #$01
	STA.l !DT
	LDA.l !LPOS,x
	JSR tl_scan
	CMP #$FF
	BEQ .no
	CMP #$E0
	BCC .own
	AND #$03                ; a combo proposed to this character
	STA.l !CY
	JSR choice_id
	BRA .id
.own:
	PHA
	JSR techbase
	PLA
	REP #$20
	AND #$00FF
	STA.l !TMP
	TXA
	CLC
	ADC.l !TMP
	TAX
	SEP #$20
	LDA.l !TECHLIST,x
.id:
	CMP #$75                ; past Grand Dream (116) the table holds system text
	BCS .no
	STA.l !DI
	CLC
	RTS

; carry clear = the text in the top window is still ours
desc_mine:
	LDA.l !DON
	BEQ .no
	LDA.l $7ECD1D           ; a battle message took over
	BNE .no
	LDA.l $7ECCEC           ; the window was closed
	BEQ .no
	LDA.l $7ECD06           ; the game put up its own text
	CMP #$FF
	BNE .no
	CLC
	RTS
.no:
	LDA #$00
	STA.l !DON
	SEC
	RTS

; close our text the way the game closes its own: its display timer runs out
desc_hide:
	JSR desc_mine
	BCS +
	LDA #$00
	STA.l $7ECD05           ; no more letters
	LDA.l $7ECCED
	BNE ++
	LDA #$01
	STA.l $7ECCED
++	LDA #$01
	STA.l $7ECCEB           ; the game's timer closes it on its next pass
	LDA #$00
	STA.l !DON
+	LDA #$FF
	STA.l !DKEY
	RTS

; put up "Name: description" for !S / !DT / !DI (player !DSP)
desc_show:
	LDA.l $7ECD1D           ; a battle message has the window: wait
	BEQ +
	RTS
+	LDA.l !S                ; the character's name
	JSR txt_name
	LDX #$0000
	LDY #$0000
-	PHX
	TYX
	LDA.l !TXT,x
	PLX
	CMP #$FF
	BEQ +
	CMP #$EF
	BEQ +
	STA.l !DSTR,x
	INX
	INY
	CPY #$0005
	BNE -
+	LDA #$E3                ; ':'
	STA.l !DSTR,x
	INX
	LDA #$EF                ; ' '
	STA.l !DSTR,x
	INX
	REP #$20
	TXA
	STA.l !TMP
	SEP #$20
	LDA.l !DI               ; the game's description (techs CC:3A09, items CC:2EB1)
	REP #$20
	AND #$00FF
	ASL
	TAX
	SEP #$20
	LDA.l !DT
	CMP #$02
	BEQ +
	REP #$20
	LDA.l $CC3A09,x         ; techs: the game's table, strings in bank CC
	TAY
	LDA.l !TMP
	TAX
	SEP #$20
-	PHX
	TYX
	LDA.l $CC0000,x
	PLX
	STA.l !DSTR,x
	CMP #$00
	BEQ .got
	INX
	INY
	CPX #$005E
	BCC -
	BRA .cut
+	REP #$20
	LDA.l !ITEMDESC,x       ; items: the field menu's table (moved in CT+)
	TAY
	LDA.l !TMP
	TAX
	SEP #$20
-	PHX
	TYX
	LDA.l !ITEMDESCBANK,x
	PLX
	STA.l !DSTR,x
	CMP #$00
	BEQ +
	INX
	INY
	CPX #$005E
	BCC -
.cut:
	LDA #$00
	STA.l !DSTR,x
.got:
+	; the game's CD:025E with our one-entry table at 7F:5C00
	REP #$20
	LDA.w #!DSTR&$FFFF
	STA.l !DTAB
	LDA.w #!DTAB&$FFFF
	STA.l $7E020D
	SEP #$20
	LDA.b #!DTAB>>16
	STA.l $7E020F
	LDA #$00
	STA.l $7E020C
	STA.l $7ECCED
	STA.l $7E02A1
	REP #$20
	LDA #$B400
	STA.l $7E0210
	SEP #$20
	LDA #$7E
	STA.l $7E0212
	LDA #$00
	STA.l $7E0214
	REP #$20                ; clear the letter buffer (CD:0239)
	LDA #$0000
	LDX #$03FE
-	STA.l $7EB400,x
	DEX
	DEX
	BPL -
	SEP #$20
	JSL $C20003
	LDA #$10                ; ... and the rest of CD:0310
	STA.l $7ECCEC
	LDA.l $7ECA24
	INC
	STA.l $7ECA24
	LDA #$01
	STA.l $7ECD05
	LDA #$FF                ; so the game's next text is never skipped as "already up"
	STA.l $7ECD06
	LDA #$01
	STA.l !DON
	LDA.l !DT
	STA.l !DKEY
	LDA.l !DI
	STA.l !DKEY+1
	LDA.l !DSP
	STA.l !DKEY+2
	RTS


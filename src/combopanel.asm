; =====================================================================
; COMB PANEL (battle).  A player's Comb opens a panel over all three boxes
; listing the combos they can use now (partners alive and free, everyone
; with the MP).  The proposer picks one and its targets, then it is
; proposed (combo.asm): partners see the proposer's name blink on their
; Comb, A there accepts (unleash), B declines.  A 8-bit, X 16-bit.
; Included from far.asm (bank !DB2); battle helpers via cmbridge.asm.
; =====================================================================

; slot A -> A = combos it can propose (flags set); stores their rows in
; !CML when !CMQ != 0
cm_scan:
	STA.l !CMK
	LDA #$00
	STA.l !CMI
	STA.l !CMV              ; 1 once past the singles
	STA.l !CMR              ; row 0..19
.row:
	LDA.l !CMR
	CMP #20
	BCC +
	JMP .done
+	LDA.l !CMK              ; TECHLIST[slot*20 + row]
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
	LDA.l !CMR
	AND #$00FF
	CLC
	ADC.l !TMP
	TAX
	SEP #$20
	LDA.l !TECHLIST,x
	CMP #$FF
	BNE +
	JMP .done
+	CMP #$FB
	BCC +
	LDA #$01                ; a marker: the combos follow
	STA.l !CMV
	JMP .next
+	PHA
	LDA.l !CMV
	BNE +
	PLA                     ; a single tech
	JMP .next
+	LDA.l !CMK
	STA.l !CY
	PLA
	JSL rec_find_l
	BCC +
	JMP .next
+	JSL mp_ok_l             ; everyone involved has the MP
	BCC +
	JMP .next
+	JSL combo_mask_l
	BNE +
	JMP .next
+	JSR cm_partners         ; partners alive and free
	BCC +
	JMP .next
+	LDA.l !CMQ
	BEQ +
	LDA.l !CMI
	REP #$20
	AND #$00FF
	TAX
	SEP #$20
	LDA.l !CMR
	STA.l !CML,x
+	LDA.l !CMI
	INC
	STA.l !CMI
	CMP #16
	BCS .done
.next:
	LDA.l !CMR
	INC
	STA.l !CMR
	JMP .row
.done:
	LDA.l !CMI
	RTS

; A = partner mask -> carry clear if each partner is in the battle, alive
; and not already committed to something else
cm_partners:
	STA.l !CZ
	LDX #$0000
-	LDA.l !CZ
	AND.l bitmask,x
	BEQ ++
	LDA.l $7E96F5,x         ; nobody in that slot
	BEQ .no
	JSR cm_hp               ; KO
	BEQ .no
	LDA.l !MODE,x
	JSL is_done_l
	BEQ .no
++	INX
	CPX #$0003
	BNE -
	CLC
	RTS
.no:
	SEC
	RTS

; X = slot -> Z set if its HP is 0 (X kept, A 8-bit)
cm_hp:
	PHX
	TXA
	ASL
	REP #$20
	AND #$00FF
	TAX
	LDA.l $CCF8ED,x         ; the character's battle record
	TAX
	LDA.l $7E5E30,x
	PLX
	CMP #$0000
	SEP #$20
	RTS

; X = slot -> carry set if KO (X kept)
cm_ko_l:
	JSR cm_hp
	BEQ +
	CLC
	RTL
+	SEC
	RTL

; slot !S -> A = proposer slot of a combo proposed to it (FF none), flags
cm_pending:
	LDA.l !S
	%tax8()
	LDA.l bitmask,x
	STA.l !CZ
	LDX #$0000
-	LDA.l !MODE,x
	CMP #$05
	BNE +
	LDA.l !PMASK,x
	AND.l !CZ
	BEQ +
	TXA
	RTS
+	INX
	CPX #$0003
	BNE -
	LDA #$FF
	RTS

; Comb label of slot !S: Z clear = usable (a proposal waits for it, or it
; has combos to propose)
cm_avail_l:
	JSR cm_pending
	BMI +
	LDA #$01
	RTL
+	LDA #$00
	STA.l !CMQ
	LDA.l !S
	JSR cm_scan
	RTL

; X = box offset of slot !S (S*20)
cm_boxx:
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
	TAX
	SEP #$20
	RTS

; A on Comb (slot !S): accept the proposal waiting for it, or open the panel
cm_comb_l:
	JSR cm_pending
	BMI +
	ORA #$E0
	JSL join_prop_l
	RTL
+	LDA #$01
	STA.l !CMQ
	LDA.l !S
	JSR cm_scan
	BNE +
	RTL                     ; nothing to propose
+	STA.l !CMN
	LDA.l !S
	%tax8()
	LDA #$08
	STA.l !MODE,x
	LDA.l !S
	INC
	STA.l !CMS
	LDA #$00
	STA.l !CMPOS
	STA.l !CMTOP
	RTL

; B on Comb: decline the proposal waiting for it
cm_decline_l:
	JSR cm_pending
	BMI +
	JSL combo_cancel_l
+	RTL

; the panel's slot still wants it (mode 8, or aiming its combo)?  carry set;
; clears !CMS when not
cm_live:
	LDA.l !CMS
	BEQ .no
	DEC
	%tax8()
	LDA.l !MODE,x
	CMP #$08
	BEQ .yes
	CMP #$04
	BNE .clr
	LDA.l !PMASK,x
	BNE .yes
.clr:
	LDA #$00
	STA.l !CMS
.no:
	CLC
	RTS
.yes:
	SEC
	RTS

; another player's slot has the panel open: carry set (this input waits)
cm_busy_l:
	JSR cm_live
	BCC +
	LDA.l !CMS
	DEC
	CMP.l !S
	BEQ +
	SEC
	RTL
+	CLC
	RTL

; mode 8 input for slot !S: !T0 buttons, !T1 d-pad
cm_input_l:
	LDA.l !S
	%tax8()
	LDA.l !T0
	AND #$0A                ; B: close
	BEQ +
	LDA #$00
	STA.l !MODE,x
	STA.l !CMS
	RTL
+	LDA #$01                ; the list may have changed (a partner fell)
	STA.l !CMQ
	LDA.l !S
	JSR cm_scan
	STA.l !CMN
	BNE +
	LDA.l !S
	%tax8()
	LDA #$00
	STA.l !MODE,x
	STA.l !CMS
	RTL
+	LDA.l !CMPOS
	CMP.l !CMN
	BCC +
	LDA.l !CMN
	DEC
	STA.l !CMPOS
+	LDA.l !T1
	AND #$01                ; right
	BEQ +
	LDA.l !CMPOS
	INC
	CMP.l !CMN
	BCS +
	STA.l !CMPOS
+	LDA.l !T1
	AND #$02                ; left
	BEQ +
	LDA.l !CMPOS
	BEQ +
	DEC
	STA.l !CMPOS
+	LDA.l !T1
	AND #$04                ; down: the next line
	BEQ +
	LDA.l !CMPOS
	CLC
	ADC #$02
	CMP.l !CMN
	BCS +
	STA.l !CMPOS
+	LDA.l !T1
	AND #$08                ; up
	BEQ +
	LDA.l !CMPOS
	SEC
	SBC #$02
	BMI +
	STA.l !CMPOS
+	LDA.l !CMPOS            ; scroll: the cursor's line stays in view
	JSR cm_div3
	CMP.l !CMTOP
	BCS +
	STA.l !CMTOP
+	DEC
	BMI +
	CMP.l !CMTOP
	BCC +
	BEQ +
	STA.l !CMTOP
+	LDA.l !T0
	AND #$80                ; A: this combo; aim it (combo.asm proposes it)
	BNE +
	RTL
+	LDA.l !CMPOS
	REP #$20
	AND #$00FF
	TAX
	SEP #$20
	LDA.l !CML,x
	PHA
	LDA.l !S
	%tax8()
	PLA
	STA.l !CHOICE,x
	LDA #$01                ; the game runs combos from its Tech list
	STA.l !PROW,x
	JSL pick_target_l
	RTL

; A -> its line (2 combos per line)
cm_div3:
	LSR
	RTS

; draw_boxes: the panel instead of the three boxes?  carry set = drawn
cm_panel_l:
	JSL ctlp_draw_l         ; paused: the controllers panel (ctlports.asm)
	BCC +
	RTL
+	JSR cm_live
	BCS +
	RTL
+	LDA.l !S
	PHA
	LDA.l !CMS
	DEC
	STA.l !S
	LDX #$0000              ; blank: 6 tile rows x 30 columns
-	REP #$20
	LDA #$29FF
	STA.l !BOXBUF,x
	SEP #$20
	INX
	INX
	CPX #$0180
	BNE -
	LDA #$00
	STA.l !CMV              ; visible entry 0..5
.ent:
	LDA.l !CMTOP            ; idx = top*2 + v
	ASL
	CLC
	ADC.l !CMV
	CMP.l !CMN
	BCC +
	JMP .entnext
+	STA.l !CMK              ; idx
	LDA.l !CMV              ; place: line v/2, column v%2
	LSR
	STA.l !CMR
	LDA.l !CMV
	AND #$01
	STA.l !CMI
	LDA.l !CMK
	CMP.l !CMPOS
	BNE .name
	LDA.l !S                ; the cursor (grey while aiming)
	%tax8()
	LDA.l !MODE,x
	CMP #$08
	BEQ +
	LDA #!GREY
	BRA ++
+	LDA #!WHITE
++	XBA
	LDA #!ARROW
	REP #$20
	PHA
	SEP #$20
	JSR cm_pos
	REP #$20
	PLA
	STA.l !BOXBUF,x
	SEP #$20
.name:
	LDA.l !CMK
	JSR cm_techid
	STA.l !DI
	LDA #$01
	STA.l !DT
	JSL name_fetch_l
	JSR cm_pos
	LDY #$0000              ; the full name (no abbreviations: the whole
-	TYA                     ; panel is ours)
	CMP.l !NL
	BCS .entnext
	PHX
	TYX
	LDA.l !NM,x
	PLX
	XBA
	LDA #!WHITE
	XBA
	REP #$20
	STA.l !BOXBUF+2,x
	SEP #$20
	INX
	INX
	INY
	BRA -
.entnext:
	LDA.l !CMV
	INC
	STA.l !CMV
	CMP #$04
	BEQ +
	JMP .ent
+	; the bottom line: what the highlighted combo costs each of them
	LDA.l !CMPOS
	JSR cm_techid
	PHA
	LDA.l !S
	STA.l !CY
	PLA
	JSL rec_find_l
	BCC +
	JMP .out
+	LDA.l $7E1A83,x
	STA.l !DQ
	LDA.l $7E1A85,x
	STA.l !DQ+1
	LDA.l $7E1A86,x
	STA.l !DQ+2
	LDA #$00
	STA.l !CMI              ; party slot
.cost:
	LDA.l !CMI
	%tax8()
	LDA.l !DQ,x
	CMP #$FF
	BNE +
	JMP .cnext
+	REP #$20
	AND #$00FF
	STA.l !NUM
	SEP #$20
	JSL digits3_l
	LDA.l !CMI
	JSL txt_name_l
	LDA.l !CMI              ; X = $140 + slot*20
	REP #$20
	AND #$00FF
	STA.l !TMP
	ASL
	ASL
	CLC
	ADC.l !TMP
	ASL
	ASL
	CLC
	ADC #$0140
	TAX
	SEP #$20
	LDY #$0000
-	PHX
	TYX
	LDA.l !TXT,x
	PLX
	XBA
	LDA #!WHITE
	XBA
	REP #$20
	STA.l !BOXBUF,x
	SEP #$20
	INX
	INX
	INY
	CPY #$0005
	BNE -
	INX                     ; one space, then the two digits
	INX
	LDA #!WHITE
	XBA
	LDA.l !DIG+1
	REP #$20
	STA.l !BOXBUF,x
	SEP #$20
	LDA.l !DIG+2
	REP #$20
	STA.l !BOXBUF+2,x
	SEP #$20
.cnext:
	LDA.l !CMI
	INC
	STA.l !CMI
	CMP #$03
	BEQ .out
	JMP .cost
.out:
	PLA
	STA.l !S
	SEC
	RTL

; line !CMR, column group !CMI -> X = that entry's cell
; (line*$80 + $40 + group*20)
cm_pos:
	LDA.l !CMR
	REP #$20
	AND #$00FF
	XBA
	LSR
	CLC
	ADC #$0040
	STA.l !TMP
	LDA.l !CMI              ; column group * 30 (15 columns)
	AND #$00FF
	STA.l !CMT
	ASL
	ASL
	ASL
	ASL
	SEC
	SBC.l !CMT              ; *15
	ASL                     ; *30
	CLC
	ADC.l !TMP
	TAX
	SEP #$20
	RTS

; A = list index -> A = its tech id (slot !S)
cm_techid:
	REP #$20
	AND #$00FF
	TAX
	SEP #$20
	LDA.l !CML,x
	STA.l !CMT            ; row
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

; =====================================================================
; Step 3: DUAL / TRIPLE TECHS by proposal  ("whoever proposes aims")
;   * a combo shows in the proposer's private Tech list while its partners
;     are ready (as in the original game)
;   * choosing it (and aiming, if it needs a target) PROPOSES it: mode 5
;   * each partner's box shows the proposer's name (blinking), the combo and
;     "Join": confirm = accept, B = decline (withdraws it), up/down = look at
;     another proposal when two players proposed to the same character
;   * partners driven by the proposer's own controller accept at once
;   * when every partner has accepted, the proposer is committed (mode 3) and
;     the partners wait in mode 6; the replay feeds the combo to the game,
;     which uses up all their turns
;
;  Game facts: battle tech list $94D0+slot*20 = singles, $FC, duals, $FD,
;  triples, $FF.  Records: 20 x 7 bytes per slot at $1A80+slotbase
;  (CC:F395); byte 0 = tech id, byte 1 = target type (bit 7 = combo),
;  byte 4 = partners ($Fp = dual with slot p, $ab = triple with slots a,b).
;  The game's list row = position in $94D0, marker rows included.
; =====================================================================

bitmask:
	db $01,$02,$04,$08,$10,$20,$40,$80

; mode A is "done" (committed / proposing / in a combo)?  Z set = yes
is_done:
	CMP #$03
	BEQ +
	CMP #$05
	BEQ +
	CMP #$07
	BEQ +
	CMP #$06
+	RTS

; slot !CY, A = tech id -> X = record offset (from $7E1A80); carry clear = found
rec_find:
	PHY
	STA.l !CX
	LDA.l !CY
	ASL
	%tax8()
	REP #$20
	LDA.l $CCF395,x
	TAX
	SEP #$20
	LDY #$0014
-	LDA.l $7E1A80,x
	CMP.l !CX
	BEQ +
	REP #$20
	TXA
	CLC
	ADC #$0007
	TAX
	SEP #$20
	DEY
	BNE -
	PLY
	SEC
	RTS
+	PLY
	CLC
	RTS

; slot !CY -> A = tech id at its CHOICE row
choice_id:
	LDA.l !CY
	%tax8()
	LDA.l !CHOICE,x
	STA.l !CX
	LDA.l !CY
	REP #$20
	AND #$00FF
	STA.l !CP
	ASL
	ASL
	CLC
	ADC.l !CP               ; *5
	ASL
	ASL                     ; *20
	STA.l !CP
	LDA.l !CX
	AND #$00FF
	CLC
	ADC.l !CP
	TAX
	SEP #$20
	LDA.l !TECHLIST,x
	RTS

; slot !CY -> X = record offset of its chosen tech (carry set = none)
choice_rec:
	JSR choice_id
	JMP rec_find

; X = record offset -> A = partner mask (0 = not a combo), flags set
combo_mask:
	LDA.l $7E1A84,x
	CMP #$FF
	BNE +
	LDA #$00
	RTS
+	STA.l !CX
	AND #$F0
	CMP #$F0
	BNE .triple
	LDA.l !CX
	AND #$03
	%tax8()
	LDA.l bitmask,x
	RTS
.triple:
	LDA.l !CX
	AND #$03
	%tax8()
	LDA.l bitmask,x
	STA.l !CZ
	LDA.l !CX
	LSR
	LSR
	LSR
	LSR
	AND #$03
	%tax8()
	LDA.l bitmask,x
	ORA.l !CZ
	RTS

; X = record offset -> carry clear if every participant has the MP
; (record bytes 3, 5, 6 = MP cost for party slots 0, 1, 2; FF = not involved)
mp_ok:
	LDA.l $7E1A83,x
	CMP #$FF
	BEQ +
	STA.l !CZ
	LDA.l $7E5E34
	CMP.l !CZ
	BCC .no
+	LDA.l $7E1A85,x
	CMP #$FF
	BEQ +
	STA.l !CZ
	LDA.l $7E5EB4
	CMP.l !CZ
	BCC .no
+	LDA.l $7E1A86,x
	CMP #$FF
	BEQ +
	STA.l !CZ
	LDA.l $7E5F34
	CMP.l !CZ
	BCC .no
+	CLC
	RTS
.no:
	SEC
	RTS

; A = partner mask -> carry clear if every partner is ready and free
mask_ok:
	STA.l !CZ
	LDX #$0000
-	LDA.l !CZ
	AND.l bitmask,x
	BEQ +
	LDA.l !READY,x
	BMI .no
	LDA.l !MODE,x
	JSR is_done             ; partners must still be choosing
	BEQ .no
+	INX
	CPX #$0003
	BNE -
	CLC
	RTS
.no:
	SEC
	RTS

; slot base offsets for slot !CY: !VB = slot*20 (tech list), !VS = record base
vl_bases:
	LDA.l !CY
	ASL
	%tax8()
	REP #$20
	LDA.l $CCF395,x
	STA.l !VS
	LDA.l !CY
	AND #$00FF
	STA.l !VB
	ASL
	ASL
	CLC
	ADC.l !VB
	ASL
	ASL
	STA.l !VB
	SEP #$20
	RTS

; A = record index (0..19), !CX = tech id, bases set -> X = record offset,
; carry clear if found (direct, else a full search)
rec_at:
	REP #$20
	AND #$00FF
	STA.l !VK
	ASL
	ASL
	ASL
	SEC
	SBC.l !VK               ; *7
	CLC
	ADC.l !VS
	TAX
	SEP #$20
	LDA.l $7E1A80,x
	CMP.l !CX
	BEQ +
	LDA.l !CX
	JMP rec_find
+	CLC
	RTS

; once per tick: the visible list of every slot that has its Tech list open
vl_build:
	; the lists only depend on who is ready and what everyone is doing:
	; rebuild only when that changed
	LDX #$0000
	LDA #$00
	STA.l !CN
-	LDA.l !READY,x
	CMP.l !SIG,x
	BEQ +
	STA.l !SIG,x
	LDA #$01
	STA.l !CN
+	LDA.l !MODE,x
	CMP.l !SIG+3,x
	BEQ +
	STA.l !SIG+3,x
	LDA #$01
	STA.l !CN
+	INX
	CPX #$0003
	BNE -
	LDA.l !CN
	BNE +
	RTS
+	LDA #$00
	STA.l !CY
-	LDA.l !CY
	%tax8()
	LDA.l !MODE,x
	CMP #$01
	BNE +
	JSR vl_slot
+	LDA.l !CY
	INC
	STA.l !CY
	CMP #$03
	BNE -
	RTS

; slot !CY's visible tech list (own techs, then the combos whose partners are
; ready and free) -> row mask !VMASK + slot*3, count !VN + slot
vl_slot:
	LDA.l !CY
	%tax8()
	LDA #$00
	STA.l !VN,x
	LDA.l !READY,x
	BPL +
	RTS
+	JSR vl_bases
	LDA.l !CY               ; clear its row mask
	STA.l !CN
	ASL
	CLC
	ADC.l !CN
	%tax8()
	LDA #$00
	STA.l !VMASK,x
	STA.l !VMASK+1,x
	STA.l !VMASK+2,x
	STA.l !CS               ; section: 0 own, 1 duals, 2 triples
	STA.l !CW               ; index within the section
	STA.l !CM               ; row 0..19
.loop:
	LDA.l !CM
	CMP #20
	BCC +
	RTS
+	REP #$20
	AND #$00FF
	CLC
	ADC.l !VB
	TAX
	SEP #$20
	LDA.l !TECHLIST,x
	CMP #$FF
	BNE +
	RTS
+	CMP #$FB
	BCC .tech
	CMP #$FD                ; $FC: duals (records 10+), $FD: triples (18+)
	BEQ +
	LDA #10
	BRA ++
+	LDA #18
++	STA.l !CS
	LDA #$00
	STA.l !CW
	JMP .next
.tech:
	STA.l !CX
	LDA.l !CS
	BNE .skip               ; combos are in the Comb panel now
	LDA.l !CM               ; own tech: record index = row
	JSR rec_at
	BCS .skip
	JSR mp_ok
	BCS .skip
	JMP .vis
+	CLC
	ADC.l !CW
	PHA
	LDA.l !CW
	INC
	STA.l !CW
	PLA
	JSR rec_at
	BCS .skip
	JSR mp_ok               ; everyone involved can pay
	BCS .skip
	JSR combo_mask
	BEQ .skip
	JSR mask_ok
	BCC .vis
.skip:
	JMP .next
.vis:
	LDA.l !CY               ; VMASK[slot*3 + row/8] |= bit(row%8)
	STA.l !CN
	ASL
	CLC
	ADC.l !CN
	STA.l !CN
	LDA.l !CM
	LSR
	LSR
	LSR
	CLC
	ADC.l !CN
	PHA
	LDA.l !CM
	AND #$07
	%tax8()
	LDA.l bitmask,x
	STA.l !CN
	PLA
	%tax8()
	LDA.l !VMASK,x
	ORA.l !CN
	STA.l !VMASK,x
	LDA.l !CY
	%tax8()
	LDA.l !VN,x
	INC
	STA.l !VN,x
.next:
	LDA.l !CM
	INC
	STA.l !CM
	JMP .loop

; slot !S's visible list: A = wanted index (FF = just count) -> !N = count,
; A = row in the game's list (FF none)
tl_scan:
	STA.l !CW
	LDA.l !S
	%tax8()
	LDA.l bitmask,x
	STA.l !CZ
	LDA.l !VN,x
	STA.l !N
	LDA #$FF
	STA.l !CX               ; the proposal entry asked for (FF none)
.noprop:
	LDA.l !S
	%tax8()
	LDA.l !CW
	CMP.l !VN,x
	BCC +
	LDA #$FF
	RTS
+	LDA.l !S                ; walk the row mask to the wanted visible entry
	STA.l !CN
	ASL
	CLC
	ADC.l !CN
	STA.l !CN               ; mask byte base
	LDA #$00
	STA.l !CM               ; row
-	LDA.l !CM
	LSR
	LSR
	LSR
	CLC
	ADC.l !CN
	%tax8()
	LDA.l !VMASK,x
	PHA
	LDA.l !CM
	AND #$07
	%tax8()
	PLA
	AND.l bitmask,x
	BEQ +
	LDA.l !CW
	BEQ ++
	DEC
	STA.l !CW
+	LDA.l !CM
	INC
	STA.l !CM
	CMP #20
	BCC -
	LDA #$FF
	RTS
++	LDA.l !CM
	RTS

; slot !S has chosen (and aimed) its command: commit it, or propose a combo
commit:
	LDA.l !S
	%tax8()
	LDA.l !PMASK,x
	BNE propose
	LDA #$03
	STA.l !MODE,x
	JMP advance_sel
propose:
	LDA #$05
	STA.l !MODE,x
	LDA.l !PMASK,x
	STA.l !CM
	LDA.l !S
	JSR owner
	STA.l !CZ               ; the proposer's player
	LDX #$0000
-	LDA.l !CM
	AND.l bitmask,x
	BEQ +
	TXA
	PHX
	JSR owner
	PLX
	CMP.l !CZ
	BNE +
	LDA.l !S                ; same controller: joined at once
	INC
	STA.l !ACPT,x
	STA.l !VIEW,x
	LDA #$07
	STA.l !MODE,x
+	INX
	CPX #$0003
	BNE -
	RTS

; A = proposer slot: withdraw its proposal (back to its list)
combo_cancel:                   ; declined or withdrawn: everyone in it goes
	STA.l !CX               ; back to their boxes
	%tax8()
	LDA #$00
	STA.l !MODE,x
	LDA.l !CX
	INC
	STA.l !CZ
	LDX #$0000
-	LDA.l !VIEW,x
	CMP.l !CZ
	BNE +
	LDA #$00
	STA.l !VIEW,x
	STA.l !ACPT,x
	LDA.l !MODE,x
	CMP #$06
	BCC +
	CMP #$08
	BCS +
	LDA #$00
	STA.l !MODE,x
+	INX
	CPX #$0003
	BNE -
	RTS

; slot !S -> A = combos proposed to it, flags set (X kept)
prop_count:
	PHX
	LDA.l !S
	%tax8()
	LDA.l bitmask,x
	STA.l !CZ
	LDA #$00
	STA.l !CX
	LDX #$0000
-	LDA.l !MODE,x
	CMP #$05
	BNE +
	LDA.l !PMASK,x
	AND.l !CZ
	BEQ +
	LDA.l !CX
	INC
	STA.l !CX
+	INX
	CPX #$0003
	BNE -
	PLX
	LDA.l !CX
	RTS

; command box of slot !S (X = box offset): "Tech" blinks while a combo
; proposed to this character waits in its Tech list
tech_blink:
	JSL cm_cell_l
	RTS

; list entry $E0+q confirmed by player !P: every character this player drives
; that is a partner of q's proposal joins it
join_prop:
	AND #$03
	STA.l !CY
	INC
	STA.l !CM
	LDA.l !CY
	%tax8()
	LDA.l !MODE,x
	CMP #$05
	BNE .gone
	LDA.l !PMASK,x
	STA.l !CN
	LDX #$0000
-	LDA.l !CN
	AND.l bitmask,x
	BEQ +
	TXA
	PHX
	JSR owner
	PLX
	CMP.l !P
	BNE +
	LDA.l !CM
	STA.l !ACPT,x
	STA.l !VIEW,x
	LDA #$07
	STA.l !MODE,x
+	INX
	CPX #$0003
	BNE -
	JMP advance_sel
.gone:
	RTS

; A = partner slot -> A = proposer+1 of the next proposal to it after the one
; it is viewing (cyclic), 0 = none
next_prop:
	STA.l !CX
	%tax8()
	LDA.l bitmask,x
	STA.l !CZ
	LDA.l !VIEW,x
	STA.l !CM               ; first candidate = the slot after the viewed one
	PHY
	LDY #$0003
-	LDA.l !CM
	CMP #$03
	BCC +
	LDA #$00
+	STA.l !CM
	%tax8()
	LDA.l !MODE,x
	CMP #$05
	BNE +
	LDA.l !PMASK,x
	AND.l !CZ
	BEQ +
	PLY
	LDA.l !CM
	INC
	RTS
+	LDA.l !CM
	INC
	STA.l !CM
	DEY
	BNE -
	PLY
	LDA #$00
	RTS

; !CX = slot p -> carry clear if a committed/proposing slot has p as partner
live_for:
	LDA.l !CX
	%tax8()
	LDA.l bitmask,x
	STA.l !CZ
	LDX #$0000
-	LDA.l !MODE,x
	CMP #$03
	BEQ +
	CMP #$05
	BNE ++
+	LDA.l !PMASK,x
	AND.l !CZ
	BEQ ++
	CLC
	RTS
++	INX
	CPX #$0003
	BNE -
	SEC
	RTS

; every menu tick, before players' input
combo_tick:
	JSR vl_build
	; partners: drop stale combo waits and joins
	LDA #$00
	STA.l !CY
.p:
	LDA.l !CY
	STA.l !CX
	%tax8()
	LDA.l !MODE,x
	CMP #$06
	BNE +
	JSR live_for
	BCC .pn
	LDA.l !CY
	%tax8()
	LDA #$00
	STA.l !MODE,x
	BRA .pn
+	CMP #$07
	BNE .drop
	LDA.l !VIEW,x           ; joined: is that proposal still open?
	BEQ .back
	DEC
	%tax8()
	LDA.l !MODE,x
	CMP #$05
	BNE .back
	LDA.l !PMASK,x
	STA.l !CZ
	LDA.l !CY
	%tax8()
	LDA.l bitmask,x
	AND.l !CZ
	BNE .pn
.back:
	LDA.l !CY
	%tax8()
	LDA #$00
	STA.l !MODE,x
.drop:
	LDA.l !CY
	%tax8()
	LDA #$00
	STA.l !VIEW,x
	STA.l !ACPT,x
.pn:
	LDA.l !CY
	INC
	STA.l !CY
	CMP #$03
	BEQ +
	JMP .p
+	; proposers: cancel if a partner is gone, fire when everyone accepted
	LDA #$00
	STA.l !CY
.s:
	LDA.l !CY
	%tax8()
	LDA.l !MODE,x
	CMP #$05
	BEQ +
	JMP .snext
+	LDA.l !PMASK,x
	STA.l !CM
	LDA #$01
	STA.l !CN               ; all accepted so far
	LDX #$0000
-	LDA.l !CM
	AND.l bitmask,x
	BEQ ++
	LDA.l !READY,x
	BPL +++
	JSL cm_ko_l             ; not ready yet: it waits for them (a KO cancels)
	BCS .cancel
	LDA #$00
	STA.l !CN
	BRA ++
+++	LDA.l !MODE,x
	CMP #$07
	BEQ .joined
	JSR is_done             ; partner chose something else: withdrawn
	BEQ .cancel
	LDA #$00                ; still choosing
	STA.l !CN
	BRA ++
.joined:
	LDA.l !CY
	INC
	CMP.l !ACPT,x
	BNE .cancel             ; joined another proposal
++	INX
	CPX #$0003
	BNE -
	LDA.l !CN
	BEQ .snext
	LDA.l !CY               ; fire: the proposer is committed, partners wait
	%tax8()
	LDA #$03
	STA.l !MODE,x
	LDX #$0000
-	LDA.l !CM
	AND.l bitmask,x
	BEQ +
	LDA #$06
	STA.l !MODE,x
	LDA #$00
	STA.l !ACPT,x
	STA.l !VIEW,x
+	INX
	CPX #$0003
	BNE -
	BRA .snext
.cancel:
	LDA.l !CY
	JSR combo_cancel
.snext:
	LDA.l !CY
	INC
	STA.l !CY
	CMP #$03
	BEQ +
	JMP .s
+	RTS

; a partner that joined a proposal (X = slot = !S): B leaves it again
ask_input:
	LDA.l !T0
	AND #$0A
	BEQ +
	LDA #$00
	STA.l !ACPT,x
	STA.l !VIEW,x
	STA.l !MODE,x
	RTS
+	JMP player_input_leftright

; ---------------------------------------------------------------------
; drawing.  One text row of box !S: row A, letters !TXT, tile high byte !PAL,
; column 0 = character !CM
put_row:
	REP #$20
	AND #$00FF
	XBA
	LSR                     ; row*$80
	STA.l !CP
	SEP #$20
	JSR box_x
	REP #$20
	TXA
	CLC
	ADC.l !CP
	TAX
	LDA #$29FF              ; the upper tile row stays blank (squeezed away)
	STA.l !BOXBUF+0,x
	STA.l !BOXBUF+2,x
	STA.l !BOXBUF+4,x
	STA.l !BOXBUF+6,x
	STA.l !BOXBUF+8,x
	STA.l !BOXBUF+10,x
	STA.l !BOXBUF+12,x
	STA.l !BOXBUF+14,x
	STA.l !BOXBUF+16,x
	STA.l !BOXBUF+18,x
	STA.l !BOXBUF+$4C,x     ; and columns 6-9 of the text row
	STA.l !BOXBUF+$4E,x
	STA.l !BOXBUF+$50,x
	STA.l !BOXBUF+$52,x
	SEP #$20
	LDA.l !PAL
	XBA
	LDA.l !CM
	REP #$20
	STA.l !BOXBUF+$40,x
	SEP #$20
	LDY #$0000
-	PHX
	TYX
	LDA.l !TXT,x
	PLX
	XBA
	LDA.l !PAL
	XBA
	REP #$20
	STA.l !BOXBUF+$42,x
	SEP #$20
	INX
	INX
	INY
	CPY #$0005
	BNE -
	RTS

; A = slot -> !TXT = that character's name
txt_name:
	%tax8()
	LDA.l $7E2980,x
	REP #$20
	AND #$00FF
	STA.l !CP
	ASL
	CLC
	ADC.l !CP
	ASL                     ; *6
	TAX
	SEP #$20
	LDY #$0000
-	LDA.l $7E2C23,x
	BNE +
	LDA #$FF
+	PHX
	TYX
	STA.l !TXT,x
	PLX
	INX
	INY
	CPY #$0005
	BNE -
	RTS

; A = tech id -> !TXT = its short name
txt_tech:
	REP #$20
	AND #$00FF
	STA.l !CP
	ASL
	ASL
	CLC
	ADC.l !CP
	TAX
	SEP #$20
	LDY #$0000
-	LDA.l tech_short,x
	PHX
	TYX
	STA.l !TXT,x
	PLX
	INX
	INY
	CPY #$0005
	BNE -
	RTS

; X = offset into strtab -> !TXT
txt_str:
	LDY #$0000
-	LDA.l strtab,x
	PHX
	TYX
	STA.l !TXT,x
	PLX
	INX
	INY
	CPY #$0005
	BNE -
	RTS

txt_blank:
	LDA #$FF
	STA.l !TXT
	STA.l !TXT+1
	STA.l !TXT+2
	STA.l !TXT+3
	STA.l !TXT+4
	RTS

strtab:
str_join:	db $A9,$C8,$C2,$C7,$FF   ; Join
str_ok:		db $AE,$AA,$FF,$FF,$FF   ; OK
str_wait:	db $B6,$BA,$C2,$CD,$FF   ; Wait

; partner box: who proposes what
draw_ask:
	LDA #$FF
	PHA
	LDA.l !S
	%tax8()
	LDA.l !VIEW,x
	DEC
	STA.l !CY
	JSR txt_name
	LDA.l !S
	%tax8()
	LDA.l !ACPT,x
	BNE +
	LDA.l !BLINK            ; (steady: only the target hands blink)
	AND #$00
	BEQ +
	JSR txt_blank
+	LDA #!WHITE
	STA.l !PAL
	PLA
	STA.l !CM
	LDA #$00
	JSR put_row
	JSR choice_id           ; row 1: the combo
	JSR txt_tech
	LDA #$FF
	STA.l !CM
	LDA #$01
	JSR put_row
	LDA.l !S                ; row 2: Join / OK
	%tax8()
	LDA.l !ACPT,x
	BEQ +
	LDX.w #str_ok-strtab
	JSR txt_str
	LDA #$FF
	BRA ++
+	LDX.w #str_join-strtab
	JSR txt_str
	LDA #!ARROW
++	STA.l !CM
	LDA #!WHITE
	STA.l !PAL
	LDA #$02
	JMP put_row

; proposer box: the combo, then each partner (blinking until they accept)
draw_prop:
	LDA.l !S
	STA.l !CY
	JSR choice_id
	JSR txt_tech
	LDA #!WHITE
	STA.l !PAL
	LDA #$FF
	STA.l !CM
	LDA #$00
	JSR put_row
	LDA.l !S
	%tax8()
	LDA.l !PMASK,x
	STA.l !CN
	LDA #$01
	STA.l !CW               ; next row
	LDA #$00
	STA.l !CS               ; partner slot
.pl:
	LDA.l !CS
	%tax8()
	LDA.l bitmask,x
	AND.l !CN
	BEQ .pn
	LDA.l !CS
	JSR txt_name
	LDA.l !CS
	%tax8()
	LDA.l !S
	INC
	CMP.l !ACPT,x
	BEQ +
	LDA.l !BLINK            ; (steady: only the target hands blink)
	AND #$00
	BEQ +
	JSR txt_blank
+	LDA #!WHITE
	STA.l !PAL
	LDA #$FF
	STA.l !CM
	LDA.l !CW
	JSR put_row
	LDA.l !CW
	INC
	STA.l !CW
.pn:
	LDA.l !CS
	INC
	STA.l !CS
	CMP #$03
	BNE .pl
	LDA.l !CW               ; a dual leaves row 2: "Wait"
	CMP #$03
	BCS +
	LDX.w #str_wait-strtab
	JSR txt_str
	LDA #!GREY
	STA.l !PAL
	LDA #$FF
	STA.l !CM
	LDA #$02
	JSR put_row
+	RTS

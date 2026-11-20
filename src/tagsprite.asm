; tagsprite.asm - the player tags drawn as SPRITES, and their glyph font.
; Lives in its own free region (!DB5) because the far.asm (bank DC/51) and
; ctlports (bank E4/53) regions are full.  draw_sprites is entered by JSL from
; menu_modes (far.asm); its helpers JSR within this bank.  Writing the tag into
; the panel made the game re-upload the panel and drop a stat line (the MP
; squash); sprites are a separate layer, so the panel is left untouched
; (vanilla "LV n") and never squashes.  Font at OBJ tiles $B0.. (font_load,
; ctlports.asm); colours per slot (white / light-blue / red) match the combat
; pointers.  OAM entries 90..107.  "P" at col 9 (x=72), rows 3/9/15
; (y=24/72/120), 8px per tile.
;   vars: $7F1EE9 SPY (y), $7F1EEA SPA (attr), $7F1EEB SPB (OAM offset, word),
;         $7F1EED tile scratch
draw_sprites:
	LDA #$00                ; our OAM entries (88..111) are small, X < 256
	STA.l $7E0918
	STA.l $7E0919
	STA.l $7E091A
	STA.l $7E091B
	STA.l $7E091C
	; ROUND-ROBIN: one slot per frame.  Drawing all three slots' tags in one
	; frame is too much work for the menu's main loop and stalls the fade-in;
	; one slot per frame is always safe, and the three tags refresh in 3 frames.
	LDA.l $7F1EE6
	INC
	CMP #$03
	BCC +
	LDA #$00
+	STA.l $7F1EE6
	STA.l !TSL
.ds_slot:
	REP #$30
	LDA.l !TSL
	AND.w #$00FF
	TAX                     ; X = slot
	SEP #$20
	LDA.l ds_ybase,x
	STA.l $7F1EE9
	LDA.l ds_attr,x
	STA.l $7F1EEA
	REP #$20                ; SPB = 360 + slot*24  (OAM byte offset of pos 0;
	TXA                     ; 65816 has no LDA long,Y, so compute it)
	AND.w #$00FF
	ASL
	ASL
	ASL                     ; slot*8
	STA.l $7F1EEB
	ASL                     ; slot*16
	CLC
	ADC.l $7F1EEB           ; slot*24
	CLC
	ADC.w #$0180            ; + 384 (base entry 96, past the game's OAM-clear range)
	STA.l $7F1EEB
	SEP #$20
	LDA.l $7E2980,x         ; nobody in that panel slot
	BPL +
	JMP .ds_hideall
+	; Only tag when we're on the MAIN character-list page.  The equip / status
	; pages rearrange the left panels; a single-panel name check can false-match
	; stale data, so require ALL THREE panels to show their own party member.
	LDA #$00
	STA.l $7F1EE7
	JSR panel_match
	BCC .ds_notmain
	LDA #$01
	STA.l $7F1EE7
	JSR panel_match
	BCC .ds_notmain
	LDA #$02
	STA.l $7F1EE7
	JSR panel_match
	BCS .ds_shown
.ds_notmain:
	JMP .ds_hideall
.ds_shown:
	REP #$30
	LDA.l !TSL
	AND.w #$00FF
	TAX                     ; X = slot again
	SEP #$20
	LDA.l !ROLE,x           ; "Pn" = the controller/port it reads
	JSL lport_l
	STA.l !TDIG
	LDA.l bitmask,x
	AND.l !PJOIN
	BNE .ds_play
	LDA.l !PST,x            ; not playing: only an Idle player shows a tag
	CMP #$02
	BEQ .ds_idle
	JMP .ds_hideall
.ds_play:
	LDA.l !PST,x
	BEQ +
	CMP #$02
	BEQ .ds_idle            ; PST 2: Idle
	JMP .ds_follow          ; PST 1: Follow
+	LDA.l !PJOIN            ; Ready and the only player: no tag (solo = vanilla)
	CMP #$01
	BEQ .ds_hideall
	CMP #$02
	BEQ .ds_hideall
	CMP #$04
	BEQ .ds_hideall
	JSR pn_head             ; multiplayer Ready: just "Pn" (level shows through)
	LDY.w #$0002
	JSR hide_from
	JMP .ds_adv
.ds_follow:
	JSR pn_head
	LDY.w #$0002
	LDA #$B6                ; F
	JSR put_spr
	LDY.w #$0003
	LDA #$B7                ; O
	JSR put_spr
	LDY.w #$0004
	LDA #$B8                ; L
	JSR put_spr
	LDY.w #$0005
	JSR hide_spr
	JMP .ds_adv
.ds_idle:
	JSR pn_head
	LDY.w #$0002
	LDA #$B9                ; I
	JSR put_spr
	LDY.w #$0003
	LDA #$BA                ; D
	JSR put_spr
	LDY.w #$0004
	LDA #$B8                ; L
	JSR put_spr
	LDY.w #$0005
	JSR hide_spr
	JMP .ds_adv
.ds_hideall:
	LDY.w #$0000
	JSR hide_from
.ds_adv:
	RTL

ds_ybase: db $18,$48,$78       ; y of panel rows 3 / 9 / 15
ds_attr:  db $3A,$3C,$3E       ; prio 3 + sprite palette 5 / 6 / 7

; P + controller digit at tile positions 0 and 1 (!TDIG 0-based)
pn_head:
	LDY.w #$0000
	LDA #$B0                ; P  ($B0)
	JSR put_spr
	LDY.w #$0001
	LDA.l !TDIG
	CLC
	ADC #$B1                ; '1'..'5' = tiles $B1..$B5
	JSR put_spr
	RTS

; write one sprite: A = tile, Y = position (0-5).  Long OAM writes (bank $7E).
put_spr:
	STA.l $7F1EED           ; stash tile
	REP #$20
	TYA
	ASL
	ASL
	CLC
	ADC.l $7F1EEB           ; SPB + pos*4 = OAM byte offset
	TAX
	SEP #$20
	TYA
	ASL
	ASL
	ASL                     ; pos*8
	CLC
	ADC #$48                ; x = 72 + pos*8
	STA.l $7E0700,x
	LDA.l $7F1EE9           ; y
	STA.l $7E0701,x
	LDA.l $7F1EED           ; tile
	STA.l $7E0702,x
	LDA.l $7F1EEA           ; attr
	STA.l $7E0703,x
	RTS

; hide positions Y..5
hide_from:
.hf:
	PHY
	JSR hide_spr
	PLY
	INY
	CPY.w #$0006
	BNE .hf
	RTS

; hide one sprite at position Y (Y-coord off-screen)
hide_spr:
	REP #$20
	TYA
	ASL
	ASL
	CLC
	ADC.l $7F1EEB
	TAX
	SEP #$20
	LDA #$F0
	STA.l $7E0701,x
	RTS

; panel_match: $7F1EE7 = slot.  Carry set if that panel is showing its own
; party member (or the slot is empty); clear on a mismatch.  The main page
; shows slot s's party member in panel s; the equip/status pages do not.
panel_match:
	REP #$30
	LDA.l $7F1EE7
	AND.w #$00FF
	TAX
	SEP #$20
	LDA.l $7E2980,x         ; the character in that slot
	BPL +
	SEC                     ; empty slot - not a mismatch
	RTS
+	STA.l !TQ
	ASL
	CLC
	ADC.l !TQ               ; char*3
	ASL                     ; char*6
	%tax8()
	LDA.l $7E2C23,x         ; the character's real first name tile
	STA.l !PSEAT
	REP #$20                ; panel tile index = slot*$180
	LDA.l $7F1EE7
	AND.w #$00FF
	XBA                     ; slot*256
	STA.l !TQ
	LSR                     ; slot*128
	CLC
	ADC.l !TQ               ; slot*384
	TAX
	SEP #$20
	LDA.l $7E2EC6,x         ; what the panel is really displaying
	CMP.l !PSEAT
	BEQ +
	CLC
	RTS
+	SEC
	RTS

font_data:
	; glyph font: P 1 2 3 4 5 F O L I D blank at OBJ tiles $B0..$BB.
	; plane0 = all opaque; glyph = colour 1 (text), bg = colour 15 (panel).
	db $FF,$FF,$FF,$87,$FF,$B7,$FF,$87,$FF,$BF,$FF,$BF,$FF,$BF,$FF,$FF  ; 'P'
	db $FF,$FF,$87,$87,$B7,$B7,$87,$87,$BF,$BF,$BF,$BF,$BF,$BF,$FF,$FF
	db $FF,$FF,$FF,$CF,$FF,$EF,$FF,$EF,$FF,$EF,$FF,$EF,$FF,$C7,$FF,$FF  ; '1'
	db $FF,$FF,$CF,$CF,$EF,$EF,$EF,$EF,$EF,$EF,$EF,$EF,$C7,$C7,$FF,$FF
	db $FF,$FF,$FF,$8F,$FF,$F7,$FF,$CF,$FF,$BF,$FF,$BF,$FF,$87,$FF,$FF  ; '2'
	db $FF,$FF,$8F,$8F,$F7,$F7,$CF,$CF,$BF,$BF,$BF,$BF,$87,$87,$FF,$FF
	db $FF,$FF,$FF,$8F,$FF,$F7,$FF,$CF,$FF,$F7,$FF,$F7,$FF,$8F,$FF,$FF  ; '3'
	db $FF,$FF,$8F,$8F,$F7,$F7,$CF,$CF,$F7,$F7,$F7,$F7,$8F,$8F,$FF,$FF
	db $FF,$FF,$FF,$E7,$FF,$D7,$FF,$B7,$FF,$87,$FF,$F7,$FF,$F7,$FF,$FF  ; '4'
	db $FF,$FF,$E7,$E7,$D7,$D7,$B7,$B7,$87,$87,$F7,$F7,$F7,$F7,$FF,$FF
	db $FF,$FF,$FF,$87,$FF,$BF,$FF,$8F,$FF,$F7,$FF,$F7,$FF,$8F,$FF,$FF  ; '5'
	db $FF,$FF,$87,$87,$BF,$BF,$8F,$8F,$F7,$F7,$F7,$F7,$8F,$8F,$FF,$FF
	db $FF,$FF,$FF,$87,$FF,$BF,$FF,$8F,$FF,$BF,$FF,$BF,$FF,$BF,$FF,$FF  ; 'F'
	db $FF,$FF,$87,$87,$BF,$BF,$8F,$8F,$BF,$BF,$BF,$BF,$BF,$BF,$FF,$FF
	db $FF,$FF,$FF,$CF,$FF,$B7,$FF,$B7,$FF,$B7,$FF,$B7,$FF,$CF,$FF,$FF  ; 'O'
	db $FF,$FF,$CF,$CF,$B7,$B7,$B7,$B7,$B7,$B7,$B7,$B7,$CF,$CF,$FF,$FF
	db $FF,$FF,$FF,$BF,$FF,$BF,$FF,$BF,$FF,$BF,$FF,$BF,$FF,$87,$FF,$FF  ; 'L'
	db $FF,$FF,$BF,$BF,$BF,$BF,$BF,$BF,$BF,$BF,$BF,$BF,$87,$87,$FF,$FF
	db $FF,$FF,$FF,$C7,$FF,$EF,$FF,$EF,$FF,$EF,$FF,$EF,$FF,$C7,$FF,$FF  ; 'I'
	db $FF,$FF,$C7,$C7,$EF,$EF,$EF,$EF,$EF,$EF,$EF,$EF,$C7,$C7,$FF,$FF
	db $FF,$FF,$FF,$8F,$FF,$B7,$FF,$B7,$FF,$B7,$FF,$B7,$FF,$8F,$FF,$FF  ; 'D'
	db $FF,$FF,$8F,$8F,$B7,$B7,$B7,$B7,$B7,$B7,$B7,$B7,$8F,$8F,$FF,$FF
	db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ; 'sp'
	db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
font_end:

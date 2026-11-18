; ---------------------------------------------------------------------
; AFTER A PLAYER'S SCENE: the followers walk back.  While a player leads a
; scene the game records THEIR footsteps in the follow trail ($7F0C00 dx /
; $7F0C80 dy, 128 entries, head $01AB; follower 1 replays from $01AC and
; settles 15 entries behind, follower 2 from $01AD, 30 behind).  Instead of
; putting the followers on the leader, write a fresh stretch of trail from
; each one's own spot to the leader: the game then walks them back itself.
; Carry set = too far for the trail (the caller puts them with the leader).
!TBF  = $7F1E9D         ; bit 0: position 1 follows, bit 1: position 2
!TBRX = $7F1E9E         ; word: still to go, x
!TBRY = $7F1EA0         ; word: still to go, y
!TBC  = $7F1EA2         ; trail cursor (written backwards from the head)
!TBT  = $7F1EA3         ; temp
!TBI1 = $7F1E3A         ; follower 1's new trail index
!TDX  = $7F1E3C         ; word: this entry's x step
!TSW  = $7F1E3E         ; word: the largest step (16 = walking pace)
!TDY  = $7F1E31         ; word: this entry's y step

trail_back_l:
	PHP
	SEP #$20
	REP #$10
	LDA #$00
	STA.l !TBF
	LDA #$01
	JSR tb_follows
	BCC +
	LDA #$01
	STA.l !TBF
+	LDA #$02
	JSR tb_follows
	BCC +
	LDA.l !TBF
	ORA #$02
	STA.l !TBF
+	LDA.l !TBF
	BNE +
	JMP .ok                 ; nobody follows: nothing to do
+	; the step: running pace (32), faster if the way is long (the trail has
	; 128 entries; keep the two stretches within 110)
	REP #$20
	LDA #$0000
	STA.l !TDX              ; (the longer axis of both stretches, summed)
	SEP #$20
	LDA.l !TBF
	AND #$01
	BEQ .m2
	LDA #$00                ; leader - follower 1
	LDY #$0002
	JSR tb_vec
	JSR tb_maxadd
.m2:
	LDA.l !TBF
	AND #$02
	BEQ .mdone
	LDA.l !TBF              ; follower 2 to follower 1 (or to the leader)
	AND #$01
	BEQ +
	LDA #$02
	BRA ++
+	LDA #$00
++	LDY #$0004
	JSR tb_vec
	JSR tb_maxadd
.mdone:
	REP #$20
	LDA.l !TDX
	LDX #$0020
	CMP #3520               ; 110 x 32
	BCC .step
	LDX #$0040
	CMP #7040               ; 110 x 64
	BCC .step
	LDX #$007F
	CMP #13970              ; 110 x 127
	BCC .step
	SEP #$20
	PLP
	SEC                     ; too far: the old way
	RTL
.step:
	TXA
	STA.l !TSW
	SEP #$20
	LDA.l $0001AB           ; write backwards from the head
	STA.l !TBC
	STA.l !TBI1
	LDA.l !TBF
	AND #$01
	BEQ .s2
	LDA #$00                ; the nearer stretch: follower 1 -> leader
	LDY #$0002
	JSR tb_vec
	JSR tb_seg
	LDA.l !TBC
	STA.l !TBI1
.s2:
	LDA.l !TBF
	AND #$02
	BEQ .no2
	LDA.l !TBF              ; then follower 2 -> follower 1 (or -> leader)
	AND #$01
	BEQ +
	LDA #$02
	BRA ++
+	LDA #$00
++	LDY #$0004
	JSR tb_vec
	JSR tb_seg
	LDA.l !TBC
	BRA .set2
.no2:
	LDA.l !TBI1
.set2:
	STA.l $0001AD
	LDA.l !TBI1
	STA.l $0001AC
.ok:
	PLP
	CLC
	RTL

; A = party position 1/2 -> carry set: it's there and only follows (nobody
; plays it, or its player is on Follow)
tb_follows:
	STA.l !TBT
	ASL
	%tax8()
	LDA.l $000197,x
	BMI .no
	LDA.l !TBT
	JSL owner_l
	CMP.l !TBT
	BNE .yes
	LDA.l !TBT
	DEC
	%tax8()
	LDA.l $7E05F8,x         ; (field.asm !FMODE: 0 = following)
	BEQ .yes
.no:
	CLC
	RTS
.yes:
	SEC
	RTS

; A = position "to" *2 (0 leader, 2 follower 1), Y = position "from" *2 ->
; !TBRX/!TBRY = to - from
tb_vec:
	%tax8()
	LDA.l $000197,x
	%tax8()                 ; X = the "to" object
	PHY
	REP #$20
	LDA.l $7E1800,x
	STA.l !TBRX
	LDA.l $7E1880,x
	STA.l !TBRY
	SEP #$20
	PLY
	TYX
	LDA.l $000197,x
	%tax8()                 ; X = the "from" object
	REP #$20
	LDA.l !TBRX
	SEC
	SBC.l $7E1800,x
	STA.l !TBRX
	LDA.l !TBRY
	SEC
	SBC.l $7E1880,x
	STA.l !TBRY
	SEP #$20
	RTS

; !TDX += the longer axis of !TBRX/!TBRY
tb_maxadd:
	REP #$20
	LDA.l !TBRX
	BPL +
	EOR #$FFFF
	INC
+	STA.l !TDY
	LDA.l !TBRY
	BPL +
	EOR #$FFFF
	INC
+	CMP.l !TDY
	BCS +
	LDA.l !TDY
+	CLC
	ADC.l !TDX
	STA.l !TDX
	SEP #$20
	RTS

; A (16-bit) -> clamped to +-!TSW
tb_clamp:
	BMI .neg
	CMP.l !TSW
	BCC +
	LDA.l !TSW
+	RTS
.neg:
	EOR #$FFFF
	INC
	CMP.l !TSW
	BCC +
	LDA.l !TSW
+	EOR #$FFFF
	INC
	RTS

; write !TBRX/!TBRY as steps backwards from !TBC (the last step lands on
; the newest entry); !TBC ends on the entry before the stretch
tb_seg:
	REP #$20
	LDA.l !TBRX
	ORA.l !TBRY
	BNE +
	SEP #$20
	RTS
+	LDA.l !TBRX
	JSR tb_clamp
	STA.l !TDX
	LDA.l !TBRX
	SEC
	SBC.l !TDX
	STA.l !TBRX
	LDA.l !TBRY
	JSR tb_clamp
	STA.l !TDY
	LDA.l !TBRY
	SEC
	SBC.l !TDY
	STA.l !TBRY
	SEP #$20
	LDA.l !TBC
	%tax8()
	LDA.l !TDX
	STA.l $7F0C00,x
	LDA.l !TDY
	STA.l $7F0C80,x
	LDA.l !TBC
	DEC
	AND #$7F
	STA.l !TBC
	BRA tb_seg


; ---------------------------------------------------------------------
; rp_check_l (Attack guard), X = slot: is the game's open picker really
; for this Tech / Item?  Carry clear = yes.  SUBWIN still set = yes.  But
; the game clears SUBWIN when its picker opens on ALLIES (a Tonic, Frog's
; heal...), and a plain Attack can never aim at an ally - so a move of
; target class 1 (pick one ally) is never the Attack leak.  (Before this,
; every one-ally item or tech was backed out 3 times and dropped: "it makes
; confirm sounds but never does it".)
ally_ok_l:
	LDA.l !SUBWIN
	BNE .yes
	PHX
	LDA.l $7E99C0           ; the game's hand is on an ally (battle ids 0-2):
	CMP #$03                ; an Attack's hand is always on an enemy (3+), so
	BCS .no                 ; this is never the Attack leak - whatever the move's
	PLX                     ; target type (one ally, one ally incl. KO'd, ...)
.yes:
	CLC
	RTL
.no:
	PLX
	SEC
	RTL


; ---------------------------------------------------------------------
; MENU SOUNDS FOLLOW THE PLAYERS.  With 2-3 players the game's own battle
; menu is hidden and fed by the replay, so its tick sound used to play for
; the replay's presses (late, and not for what the player pressed), while
; moving in a player's own box made no sound at all.
;
; C1:1B55 hook (the game's tick: "STZ $1E01 / LDA #$19", then STA $1E00 ...
; JSL C7:0004 / RTS at C1:1B66).  Silent while a replay drives the hidden
; menu - except step 7, where a player drives the game's own picker.
!PPF  = $7F1F8C         ; !BLINK of the frame prepos_l pressed (prepos_l)
!PPON = $7F1F8D         ; 1 = !PPF is valid
menu_snd_l:
	PHP
	SEP #$20
	LDA.l !JOINED
	BEQ .play               ; solo: the original game
	LDA.l !RSLOT
	BEQ .pp
	LDA.l !RSTEP
	CMP #$07
	BEQ .play
	BRA .skip
.pp:                            ; no replay: skip only prepos_l's own press
	LDA.l !PPON             ; (made this same frame)
	BEQ .play
	LDA.l !BLINK            ; the game plays it a frame or so after the press
	SEC                     ; (nothing else presses in the hidden menu then)
	SBC.l !PPF
	CMP #$04
	BCC .skip
	LDA #$00                ; (stale)
	STA.l !PPON
	BRA .play
.skip:
	PLP                     ; skip it: return to C1's RTS at 1B66 instead
	LDA #$65                ; (RTL lands on the pushed address + 1).  8-bit
	STA 1,s                 ; writes only: the code after this relies on A's
	LDA #$1B                ; hidden high byte (picker dispatch) - a 16-bit
	STA 2,s                 ; load here hung the replay
	LDA #$80                ; A as the original leaves it (its last LDA #$80)
	RTL
.play:
	PLP
	LDA #$00
	STA.l $001E01
	LDA #$19                ; (as replaced; the game stores it to $1E00 next)
	RTL

; menu.asm player_input, in place of "JSL cm_busy_l": the same answer
; (carry set = another player's Comb panel is up), and when this player's
; box takes the press, the menu tick - right as they press
box_snd_l:
	JSL cm_busy_l
	BCS .out
	PHP
	SEP #$20
	LDA.l !T0
	AND #$8A                ; A / B
	ORA.l !T1               ; or the d-pad
	AND #$8F
	BEQ +
	JSR box_tick
+	PLP
	CLC
.out:
	RTL

; the game's own menu tick (C1:1B55 does exactly this)
box_tick:
	PHP
	SEP #$20
	REP #$10
	PHX
	PHY
	PHB
	PHD
	LDA #$7E
	PHA
	PLB
	REP #$20
	LDA #$0000
	TCD
	SEP #$20
	STZ $1E01
	LDA #$19
	STA $1E00
	LDA #$80
	STA $1E02
	JSL $C70004
	PLD
	PLB
	PLY
	PLX
	PLP
	RTS


; ---------------------------------------------------------------------
; PRE-POSITION THE HIDDEN MENU.  The replay can only confirm a move with
; the game's (hidden) menu on that character; when it's on someone else it
; first presses right / left, one tick each.  While nothing is being
; replayed, do that early for the player closest to confirming (aiming, or
; confirming a no-target tech; else in a Tech / Item list), so the replay
; can confirm at once.  The presses are the replay's own (step 0) - the
; tick sound is skipped for them (menu_snd_l).
prepos_l:
	PHP
	SEP #$20
	REP #$10
	PHX
	PHY
	LDA.l !JOINED
	BEQ .out
	LDA #$04                ; aiming / confirming first, then lists
	JSR pp_find
	BPL .have
	LDA #$01
	JSR pp_find
	BMI .out
.have:
	CMP.l !F
	BEQ .out
	STA.l !CV               ; (K)
	LDA.l !F                ; next ready after F (as menu.asm next_ready)
	LDY #$0003
-	INC
	CMP #$03
	BNE +
	LDA #$00
+	%tax8()
	LDA.l !READY,x
	BPL .nr
	TXA
	DEY
	BNE -
	BRA .out                ; nobody else ready
.nr:
	TXA
	CMP.l !CV
	BNE +
	LDA #$01                ; right = next
	BRA ++
+	LDA #$02                ; left = previous
++	STA.l !HI
	LDA.l !BLINK
	STA.l !PPF
	LDA #$01
	STA.l !PPON
.out:
	PLY
	PLX
	PLP
	RTL

; A = mode group (4: aiming / confirming, 1: lists) -> A = the first ready
; slot in it (negative = none)
pp_find:
	STA.l !CV
	LDX #$0000
-	LDA.l !READY,x
	BMI .next
	LDA.l !CV               ; group 4: modes 4, 9 / group 1: modes 1, 2
	CMP #$04
	BNE .lists
	LDA.l !MODE,x
	CMP #$04
	BEQ .yes
	CMP #$09
	BEQ .yes
	BRA .next
.lists:
	LDA.l !MODE,x
	CMP #$01
	BEQ .yes
	CMP #$02
	BEQ .yes
.next:
	INX
	CPX #$0003
	BNE -
	LDA #$FF
	RTS
.yes:
	TXA
	RTS


; ---------------------------------------------------------------------
; FREE FOLLOWERS KEEP PACE WITH THE LEADER.  On busy frames the game updates
; the leader but sometimes not a party follower (measured in the forest:
; when both ran, player 2 got ~1 step in 5 fewer than the leader - 134 px vs
; 149).  A trailing follower doesn't care (it catches up along the trail);
; a free one just lost the step.  So: count the leader's updates, and when a
; free follower's turn comes after the leader has had 2 (it was skipped
; once), it takes 2 steps.  Bigger gaps (just freed, a cutscene) don't count.
!LCNT  = $7F1F8B        ; the leader's updates (lead_walk)
!FLAST = $7F1F8E        ; 2 (per position-1): !LCNT at that follower's last step
lead_tick_l:
	PHP
	SEP #$20
	PHA
	LDA.l !LCNT
	INC
	STA.l !LCNT
	PLA
	PLP
	RTL

; field.asm fol_free, before its step: carry set = take one extra step
catch_l:
	PHP
	SEP #$20
	REP #$10
	PHX
	LDA.l $7E05ED           ; !FI: position-1
	%tax8()
	LDA.l !LCNT
	SEC
	SBC.l !FLAST,x
	PHA
	LDA.l !LCNT
	STA.l !FLAST,x
	PLA
	CMP #$02
	BNE .no
	PLX
	PLP
	SEC
	RTL
.no:
	PLX
	PLP
	CLC
	RTL


; the missed frame's movement: this follower's place += its velocity
; ($1900/$1980,x signed bytes in 1/16 px; $1800/$1880,x place, 1/16 px)
fol_integ_l:
	PHP
	REP #$30
	PHX
	LDA.l $7E05EB           ; !FOBJ: object*2
	AND #$00FF
	TAX
	LDA.l $7E1900,x
	AND #$00FF
	BIT #$0080
	BEQ +
	ORA #$FF00
+	CLC
	ADC.l $7E1800,x
	STA.l $7E1800,x
	LDA.l $7E1980,x
	AND #$00FF
	BIT #$0080
	BEQ +
	ORA #$FF00
+	CLC
	ADC.l $7E1880,x
	STA.l $7E1880,x
	PLX
	PLP
	RTL


; ---------------------------------------------------------------------
; drain_fix (far.asm), right after the game's sprite-pose upload C0:CA76:
; the free followers' steps that fol_free marked this frame.  Same work,
; same order as before - only after the upload instead of in the object pass
; (there, their cost pushed the upload past the game's line limit and every
; few frames everyone lost a frame).  field.asm fol_late1 does each one.
fol_late_l:
	PHP
	REP #$30
	PHA
	PHX
	PHY
	PHB
	PHD
	LDA.l $00016D           ; the game's current-object index (the step's
	PHA                     ; animation and touch code use it)
	LDA #$0100              ; the object pass's context: D = $0100, DB = $00
	TCD
	SEP #$20
	LDA #$00
	PHA
	PLB
	LDA #$01
	JSR fol_late1
	LDA #$02
	JSR fol_late1
	SEP #$20                ; then the players' bookkeeping, if the NMI left
	LDA.l $7F1EDF           ; it for here (field.asm uj_pick) - and only with
	BEQ +                   ; time to spare: past line 170 it waits a frame
	JSR fl_line             ; (the frame must end before line 225, or
	CMP #$00AA              ; everyone loses a frame)
	SEP #$20
	BCS +
	REP #$20                ; (the joypad routine's context: D = 0, DB = 0)
	LDA #$0000
	TCD
	JSL uj_late_l
+	REP #$30
	PLA
	STA.l $00016D
	PLD
	PLB
	PLY
	PLX
	PLA
	PLP
	RTL

; A = party position (1, 2)
!FMODEY = $7E05F8       ; field.asm !FMODE
fol_late1:
	SEP #$20
	REP #$10
	STA.l $7E05EC           ; !FP
	DEC
	STA.l $7E05ED           ; !FI
	%tax8()
	LDA.l $7F1EDD,x         ; !FPEND
	BNE +
	RTS
+	LDA #$00
	STA.l $7F1EDD,x
	LDA.l !FMODEY,x         ; (still walking freely)
	BNE +
	RTS
+	LDA.l $7E05EC           ; its object, from the party list
	ASL
	%tax8()
	LDA.l $000197,x
	BPL +
	RTS
+	STA.l $7E05EB           ; !FOBJ
	STA.l $00016D
	LDA #$00
	STA.l $00016E
	JSR fol_pad_c           ; its player's pad, as fol_free read it this frame
	SEP #$20
	JSL catch_l             ; the game skipped this character last frame:
	BCC +                   ; one extra step, so it keeps pace with the
	JSL fol_once_l          ; leader - the missed frame's step, applied as
	JSL fol_integ_l         ; the game would (velocity -> place), then this
+	JSL fol_once_l          ; frame's, checked from there
	RTS

; A (16-bit) = the scanline now (lines past 240 count as early: vblank)
fl_line:
	SEP #$20
	LDA.l $00213F
	LDA.l $002137
	LDA.l $00213D
	XBA
	LDA.l $00213D
	AND #$01
	XBA
	REP #$20
	CMP #$00F0
	BCC +
	LDA #$0000
+	RTS



; ---------------------------------------------------------------------
; fieldmenu.asm pad_merge (field NMI): a message window or Yes/No choice is
; open -> anyone's A answers it, but only as a NEW press: an A held from
; before the window opened (the press that started it, e.g. P2 picking up a
; tab) used to reach the game as a fresh press and close it at once.
; Yes/No: d-pad as held.  (P1's own A comes through the game's own edge
; detection, unchanged.)
!APREV  = $7F1EE0       ; field only (battle's !EXN): anyone's A held last frame
!APNEW  = $7F1EE1       ; field only (battle's !EXS): A pressed this frame ($80)
win_merge_l:
	PHP
	SEP #$20
	LDA.l $004218
	ORA.l $00421A
	ORA.l $00421E
	ORA.l !P4RAW
	ORA.l !P5RAW
	AND #$80
	PHA
	LDA.l !APREV
	EOR #$FF
	AND 1,s
	STA.l !APNEW
	PLA
	STA.l !APREV
	REP #$20
	LDA.l $000134           ; a message window is open: anyone's new A
	BEQ +
	LDA.l !APNEW
	AND #$0080
	ORA.l $7E02FE           ; !MERGED
	STA.l $7E02FE
+	SEP #$20
	LDA.l $000162           ; a Yes/No choice is open: anyone can pick
	BEQ +
	REP #$20
	LDA.l $004218
	ORA.l $00421A
	ORA.l $00421E
	ORA.l !P4RAW
	ORA.l !P5RAW
	AND #$0F00
	ORA.l !APNEW
	AND #$0F80
	ORA.l $7E02FE
	STA.l $7E02FE
+	PLP
	RTL

; ---------------------------------------------------------------------
; battle boxes (aff.asm draw_due_l): -> A(8) = a checksum of everything the
; boxes show that can change without a button press - menu states, HP, MP,
; who is in the party, the hold-X description.  A change redraws all three
; at once; otherwise menu.asm redraws one box every other tick.
dd_sig_l:
	LDA #$00
	ASL : ADC.l !MODE
	ASL : ADC.l !MODE+1
	ASL : ADC.l !MODE+2
	ASL : ADC.l !SEL
	ASL : ADC.l !SEL+1
	ASL : ADC.l !SEL+2
	ASL : ADC.l $7ECD02     ; (paused: the controllers panel, ctlports.asm)
	ASL : ADC.l !PZCUR
	ASL : ADC.l !ROLE
	ASL : ADC.l !ROLE+1
	ASL : ADC.l !ROLE+2
	ASL : ADC.l !PPORT
	ASL : ADC.l !PPORT+1
	ASL : ADC.l !PPORT+2
	ASL : ADC.l !PROW
	ASL : ADC.l !PROW+1
	ASL : ADC.l !PROW+2
	ASL : ADC.l !ACPT
	ASL : ADC.l !ACPT+1
	ASL : ADC.l !ACPT+2
	ASL : ADC.l !F
	ASL : ADC.l !RSLOT
	ASL : ADC.l !READY
	ASL : ADC.l !READY+1
	ASL : ADC.l !READY+2
	ASL : ADC.l !TARGET
	ASL : ADC.l !SUBWIN
	ASL : ADC.l $7E5E30     ; HP of party slots 0-2 (draw_stats)
	ASL : ADC.l $7E5E31
	ASL : ADC.l $7E5EB0
	ASL : ADC.l $7E5EB1
	ASL : ADC.l $7E5F30
	ASL : ADC.l $7E5F31
	ASL : ADC.l $7E5E34     ; MP (low bytes)
	ASL : ADC.l $7E5EB4
	ASL : ADC.l $7E5F34
	ASL : ADC.l $7E96F5     ; who is in the party slots
	ASL : ADC.l $7E96F6
	ASL : ADC.l $7E96F7
	ASL : ADC.l !XHELD      ; hold-X description
	ASL : ADC.l !DESCP
	ASL : ADC.l !DON
	RTL

; battle boxes (menu.asm draw_rot): box !S was redrawn - copy just its 6 rows
; x 10 columns to what the screen gets (!SHOW), not the whole panel (the
; whole copy alone took ~20 lines).  !PUB: the screen reads the finished
; drawing while the copy runs, as in draw_boxes.
pub_box_l:
	PHP
	SEP #$20
	REP #$10
	LDA #$01
	STA.l !PUB
	LDA.l !S                ; X = S * 20 (box_x)
	REP #$20
	AND.w #$00FF
	ASL
	ASL
	STA.l !TMP
	ASL
	ASL
	CLC
	ADC.l !TMP
	TAX
	LDY.w #$0006
-	LDA.l !BOXBUF+0,x
	STA.l !SHOW+0,x
	LDA.l !BOXBUF+2,x
	STA.l !SHOW+2,x
	LDA.l !BOXBUF+4,x
	STA.l !SHOW+4,x
	LDA.l !BOXBUF+6,x
	STA.l !SHOW+6,x
	LDA.l !BOXBUF+8,x
	STA.l !SHOW+8,x
	LDA.l !BOXBUF+10,x
	STA.l !SHOW+10,x
	LDA.l !BOXBUF+12,x
	STA.l !SHOW+12,x
	LDA.l !BOXBUF+14,x
	STA.l !SHOW+14,x
	LDA.l !BOXBUF+16,x
	STA.l !SHOW+16,x
	LDA.l !BOXBUF+18,x
	STA.l !SHOW+18,x
	TXA
	CLC
	ADC.w #$0040
	TAX
	DEY
	BNE -
	SEP #$20
	LDA #$00
	STA.l !PUB
	LDA #$18
	STA.l !BOXON            ; shown for 24 frames unless redrawn
	PLP
	RTL

; ---------------------------------------------------------------------
; map_pad (ct3p.asm, a stub): raw auto-read word -> the game's mapped layout
; (like $F8/$F9), by the player's button settings ($7E:2993-299A).  Same
; result and scratch as before (!SCR: +0/+1 raw - desc.asm reads it - +2
; game lo, +3 mask, +4 out lo, +5 out hi), about half the time: with the
; bank set the eight tests are inline.  It runs several times a frame.
!SC = $02F8               ; !SCR's address in bank 7E
assert !SCR == $7E02F8
macro mp_bit(cfg)
	LDA.w !SC+2
	AND <cfg>
	CMP <cfg>
	ROR.w !SC+4
endmacro
map_pad_l:
	JSR mp_body
	RTL
mp_body:
	PHB
	STA.l !SCR
	SEP #$20
	LDA #$7E
	PHA
	PLB
	LDA.w !SC+1
	AND #$0F
	STA.w !SC+5
	LDA.w !SC+1
	LSR
	LSR
	LSR
	LSR
	STA.w !SC+2
	LDA.w !SC
	AND #$F0
	ORA.w !SC+2
	STA.w !SC+2
	STZ.w !SC+4
	%mp_bit($2998)
	%mp_bit($2996)
	%mp_bit($2997)
	%mp_bit($2994)
	%mp_bit($2999)
	%mp_bit($299A)
	%mp_bit($2995)
	%mp_bit($2993)
	LDA $2993
	STA.w !SC+3
	PLB
	REP #$20
	LDA.l !SCR+4
	RTS

; field.asm fol_free (A 16-bit = the follower's raw pad, also in !FRAW):
; map it -> !FPAD, and keep both for fol_late this frame (fol_pad_c)
!FPADS = !RAMB+$62      ; 2 words: by position-1
!FRAWS = !RAMB+$66      ; 2 words
fpad_l:
	JSR mp_body
	STA.l $7E05F0           ; field.asm !FPAD
	PHP
	REP #$30
	PHX
	LDA.l $7E05ED           ; !FI
	AND.w #$00FF
	ASL
	TAX
	LDA.l $7E05F0
	STA.l !FPADS,x
	LDA.l $7E05F6           ; !FRAW
	STA.l !FRAWS,x
	PLX
	PLP
	RTL

; fol_late1: the follower's pad as fol_free read and mapped it this frame
fol_pad_c:
	PHP
	REP #$30
	PHX
	LDA.l $7E05ED           ; !FI
	AND.w #$00FF
	ASL
	TAX
	LDA.l !FRAWS,x
	STA.l $7E05F6           ; !FRAW
	LDA.l !FPADS,x
	STA.l $7E05F0           ; !FPAD
	PLX
	PLP
	RTS

incsrc "ctlports.asm"

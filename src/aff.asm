; ---------------------------------------------------------------------
; WHO A MOVE WILL HIT.  While a player aims a tech (mode 4), confirms one
; that needs no target (mode 9) or proposes a combo (mode 5), every target
; the move will hit gets a blinking hand in that player's colour.
;
; The set is the game's own answer: its target picker runs one routine per
; target type (jump table C1:1FF8) that leaves the hit list in $A62D.  We run
; that same routine for the aiming player - only while the game's own picker
; and lists are idle, with everything it touches saved first and put back
; after, so the game never sees it happen.
;
; The extra hands are sprites 115..121 (the battle uses well under 100).

!SVD  = $7F1E00         ; 49: direct page the routines use, saved
!JPRV = $7F1E38         ; 1 once the shared menu has taken over this battle
!SVA  = $7F1EB8         ; 37: the game's target variables, saved
!EXN  = $7F1EE0         ; ext_build: count
!EXS  = $7F1EE1         ;   slot
!EXI  = $7F1EE2         ;   entry
!EXV  = $7F1EE3         ;   id
!EXQ  = $7F1EE4         ; ext_inject (NMI only): y offset
!EXR  = $7F1EE5         ;   attribute
!EXZ  = $7F1EE6         ;   x
!EXD  = $7F1F7D         ; 1: the hands must be rebuilt
!AFS  = $7F1F7E         ; aff_tick: slot
!AFC  = $7F1F7F         ;   the aimed target's battle id
!AFF  = $7F1FD0         ; 3 x 12: the targets each slot's move will hit
!AFKI = $7F1FF4         ; 3: the target index it was worked out for
!AFKT = $7F1FF7         ; 3: the target type
!AFKM = $7F1FFA         ; 3: the mode (FE = nothing worked out)

; target type -> 0 one target (nothing extra), 1 a whole side, 2 an area
; around the aimed enemy
aff_kind:
	db 0,1,0,0,1,0,0,0,1,1,1,2,2,2,0,2
	db 0,0,2,0,0,0,0,0,0,0,2,0,0,0,0,0
	db 0
aff_ofs:
	db 0,12,24

; menu tick (main loop, the game's menu code): A 8-bit, X 16-bit
aff_tick_l:
	PHP
	SEP #$20
	REP #$10
	LDA.l !TARGET           ; the game's own picker or list is busy: keep
	ORA.l !SUBWIN           ; what we have
	ORA.l !RSLOT
	BEQ +
	PLP
	RTL
+	JSR aff_world           ; enemies moved / fell: work every list out again
	LDA #$00
	STA.l !AFS
.slot:
	LDA.l !AFS
	%tax8()
	JSR aff_want
	BCS .want
	JSR aff_clear
	BRA .next
.want:
	LDA.l !AFS
	%tax8()
	LDA.l !TIDX,x
	CMP.l !AFKI,x
	BNE .calc
	LDA.l !TTYPE,x
	CMP.l !AFKT,x
	BNE .calc
	LDA.l !MODE,x
	CMP.l !AFKM,x
	BEQ .next
.calc:
	LDA.l !TIDX,x
	STA.l !AFKI,x
	LDA.l !TTYPE,x
	STA.l !AFKT,x
	LDA.l !MODE,x
	STA.l !AFKM,x
	JSR aff_calc
	LDA #$01
	STA.l !EXD
.next:
	LDA.l !AFS
	INC
	STA.l !AFS
	CMP #$03
	BNE .slot
	PLP
	RTL

; the battlefield changed (a position, or who can be targeted) since the
; lists were worked out: redo them - at most every 16 frames
!AWSIG = $7F1E37        ; word: positions + flags, summed
!AWCNT = $7F1E39        ; frames since the last redo
aff_world:
	LDA.l !AWCNT            ; only every 16 frames ...
	INC
	STA.l !AWCNT
	CMP #$10
	BCC .out
	LDA.l !AFKM             ; ... and only while someone has a list
	AND.l !AFKM+1
	AND.l !AFKM+2
	CMP #$FE
	BEQ .out
	LDA #$00
	STA.l !AWCNT
	REP #$20
	LDA #$0000
	LDX #$000A
-	CLC
	ADC.l $7E1D0C,x         ; (x, y and the targetable flags of all 11)
	ADC.l $7E1D23,x
	ADC.l $7E96F5,x
	ADC.l $7E9FF7,x
	ADC.l $7EA09B,x
	DEX
	BPL -
	CMP.l !AWSIG
	BEQ .same
	STA.l !AWSIG
	SEP #$20
	LDA #$FE                ; every list: worked out again
	STA.l !AFKM
	STA.l !AFKM+1
	STA.l !AFKM+2
.same:
	SEP #$20
.out:
	RTS

; X = slot -> carry set: its move hits more than one target
aff_want:
	LDA.l !READY,x
	BMI .no
	LDA.l !MODE,x
	CMP #$05
	BEQ .ok
	CMP #$09
	BEQ .ok
	CMP #$04
	BNE .no
	LDA.l !PROW,x           ; Attack: one target
	BEQ .no
.ok:
	LDA.l !TTYPE,x
	CMP #$21
	BCS .no
	%tax8()
	LDA.l aff_kind,x
	BEQ .no
	SEC
	RTS
.no:
	CLC
	RTS

; slot !AFS: nothing worked out
aff_clear:
	JSR aff_blank
	LDA.l !AFS
	%tax8()
	LDA #$FE
	STA.l !AFKM,x
	RTS

aff_blank:
	LDA.l !AFS
	%tax8()
	LDA.l aff_ofs,x
	%tax8()
	LDY #$000C
	LDA #$FF
-	STA.l !AFF,x
	INX
	DEY
	BNE -
	RTS

macro cp(src, dst, n)
	LDX.w #<n>-1
?l:
	LDA.l <src>,x
	STA.l <dst>,x
	DEX
	BPL ?l
endmacro

; slot !AFS: ask the game which targets its move will hit
aff_calc:
	JSR aff_blank
	LDA.l !AFS
	%tax8()
	LDA.l !TTYPE,x
	%tax8()
	LDA.l aff_kind,x
	CMP #$02
	BNE .save
	LDA.l !S                ; the aimed enemy (the shared menu's own order)
	PHA
	LDA.l !AFS
	STA.l !S
	%tax8()
	LDA.l !TIDX,x
	JSL cand_id_l
	STA.l !AFC
	PLA
	STA.l !S
	LDA.l !AFC
	CMP #$0B
	BCC .save
	RTS                     ; nothing aimed yet
.save:
	%cp($000080, !SVD, 21)
	%cp($0000A5, !SVD+21, 10)
	%cp($0000D3, !SVD+31, 16)
	%cp($0000EE, !SVD+47, 2)
	%cp($7E9604, !SVA, 12)
	%cp($7E9614, !SVA+12, 1)
	%cp($7E99C0, !SVA+13, 12)
	%cp($7EA62D, !SVA+25, 12)
	PHB
	PHD
	PEA $0000               ; the battle's direct page and data bank
	PLD
	PEA $7E7E
	PLB
	PLB
	STZ $EE                 ; no buttons: the routine never moves a cursor
	STZ $EF                 ; (or plays its sound)
	LDA.l !AFS
	STA.w $960F             ; the caster
	%tax8()
	LDA.l !TTYPE,x
	STA.w $960D             ; the target type
	%tax8()
	LDA.l aff_kind,x
	CMP #$02
	BNE .call
	LDX #$20A9              ; area: the game's enemy list (type 07), and the
	JSR c1call              ; aimed enemy's place in it
	LDX #$0000
-	LDA.w $99C0,x
	CMP.l !AFC
	BEQ +
	INX
	CPX #$000B
	BNE -
	BRA .done
+	TXA
	STA.w $9614
.call:
	LDA.w $960D
	REP #$20
	AND #$00FF
	ASL
	TAX
	LDA.l $C11FF8,x         ; the game's routine for this target type
	TAX
	SEP #$20
	JSR c1call
	LDA.l !AFS              ; its answer: $A62D
	%tax8()
	LDA.l aff_ofs,x
	%tax8()
	LDY #$0000
-	LDA.w $A62D,y
	STA.l !AFF,x
	INX
	INY
	CPY #$000B
	BNE -
.done:
	PLD
	PLB
	%cp(!SVD, $000080, 21)
	%cp(!SVD+21, $0000A5, 10)
	%cp(!SVD+31, $0000D3, 16)
	%cp(!SVD+47, $0000EE, 2)
	%cp(!SVA, $7E9604, 12)
	%cp(!SVA+12, $7E9614, 1)
	%cp(!SVA+13, $7E99C0, 12)
	%cp(!SVA+25, $7EA62D, 12)
	RTS

; X = a routine in bank C1 that ends in RTS: call it (A 8-bit, X 16-bit).
; Its RTS lands on an RTL in bank C1 (C1:8C71), which returns here.
c1call:
	PHP
	JSL .go
	PLP
	RTS
.go:
	PEA $8C70
	LDA #$C1
	PHA
	REP #$20
	TXA
	DEC
	PHA
	SEP #$20
	RTL

; ptr_update (main loop, every battle frame): the extra hands for this frame,
; built here as finished sprite entries so the NMI only copies them
!EXO  = $7F1F60         ; 28: sprites 115..121, ready to copy (4 bytes each)
!EXP  = $7F1F7C         ; extra hands shown last frame (the NMI copies while
                        ; any are shown, and once more after, to hide them)
ext_build_l:
	PHP
	SEP #$20
	REP #$10
	LDA.l !EXN
	BEQ .clean              ; nothing was shown: the entries are still hidden
	LDX #$0000              ; all hidden
-	LDA #$00
	STA.l !EXO,x
	LDA #$F0
	STA.l !EXO+1,x
	INX
	INX
	INX
	INX
	CPX #$001C
	BNE -
.clean:
	LDA #$00
	STA.l !EXN
	LDA.l !JOINED
	BNE +
	JMP .out
+	LDA #$00
	STA.l !EXS
.slot:
	LDA.l !EXS
	%tax8()
	LDA.l !READY,x
	BMI .skip
	LDA.l !MODE,x
	CMP.l !AFKM,x           ; worked out for the state it is in now
	BEQ +
.skip:
	JMP .snext
+	LDA #$00
	STA.l !EXI
.ent:
	LDA.l !EXS
	%tax8()
	LDA.l aff_ofs,x
	CLC
	ADC.l !EXI
	%tax8()
	LDA.l !AFF,x
	CMP #$0B
	BCC +
	JMP .snext              ; (the list ends at its first gap)
+	STA.l !EXV
	%tax8()                 ; still there to be hit? (fallen / hidden: no hand)
	LDA.l $7E96F5,x
	BEQ .gone
	LDA.l $7E9FF7,x
	BMI .gone
	LDA.l $7EA09B,x
	BEQ +
.gone:
	JMP .enext
+	LDA.l !EXS
	%tax8()
	LDA.l !EXV
	CMP.l !PID,x            ; its steady hand is already there
	BNE +
	JMP .enext
+	LDA.l !EXN
	CMP #$07
	BCC +
	JMP .out
+	LDA.l aff_ofs,x         ; the owner's y step and colour
	STA.l !EXQ
	LDA.l !PPAL,x
	STA.l !EXR
	LDA.l !EXV
	%tax8()                 ; X = the target
	LDA.l $7E1D0C,x         ; left of the target, as the main hands
	CLC
	ADC.l $7E9708,x
	SEC
	SBC #$14
	BCS +
	LDA #$00
+	STA.l !EXZ
	LDA.l $7E1D23,x
	CLC
	ADC.l $7E9713,x
	SEC
	SBC #$14
	CLC
	ADC.l !EXQ
	PHA
	LDA.l !EXN
	ASL
	ASL
	%tax8()                 ; X = its entry
	PLA
	STA.l !EXO+1,x
	LDA.l !EXZ
	STA.l !EXO,x
	LDA #$00
	STA.l !EXO+2,x
	LDA.l !EXR
	STA.l !EXO+3,x
	LDA.l !EXN
	INC
	STA.l !EXN
.enext:
	LDA.l !EXI
	INC
	STA.l !EXI
	CMP #$0B
	BEQ .snext
	JMP .ent
.snext:
	LDA.l !EXS
	INC
	STA.l !EXS
	CMP #$03
	BEQ .out
	JMP .slot
.out:
	PLP
	RTL

; menu tick: rebuild the hands only when something they show changed (a
; new hit list, a hand moved, a mode changed) - the game has little time to
; spare in a busy frame
!EXSIG = $7F1E33        ; 3: the hands' battle ids when last built
!EXMSG = $7F1FFD        ; 3: the modes when last built
ext_maybe_l:
	PHP
	SEP #$20
	REP #$10
	LDX #$0002
.cmp:
	LDA.l !PID,x
	CMP.l !EXSIG,x
	BNE .build
	LDA.l !MODE,x
	CMP.l !EXMSG,x
	BNE .build
	DEX
	BPL .cmp
	LDA.l !EXD
	BNE .build
	PLP
	RTL
.build:
	LDX #$0002
-	LDA.l !PID,x
	STA.l !EXSIG,x
	LDA.l !MODE,x
	STA.l !EXMSG,x
	DEX
	BPL -
	LDA #$00
	STA.l !EXD
	PLP
	JML ext_build_l

; NMI, oam_inject (A 8-bit, X 16-bit): copy the finished entries - short,
; and only while extra hands are (or were just) shown: the NMI's time is
; the game's
ext_inject_l:
	LDA.l !JOINED
	BNE +
	RTL
+	LDA.l !EXN
	BNE .some
	LDA.l !EXP              ; none now: hide them once, after showing some
	BNE .hide
	RTL
.some:
	STA.l !EXP
	LDA.l !BLINK            ; the blink's dark half
	AND #$08
	BNE .show
.hide:
	LDA.l !EXN
	STA.l !EXP
	LDA #$F0
	STA.l $7E0701+(115*4)
	STA.l $7E0701+(116*4)
	STA.l $7E0701+(117*4)
	STA.l $7E0701+(118*4)
	STA.l $7E0701+(119*4)
	STA.l $7E0701+(120*4)
	STA.l $7E0701+(121*4)
	RTL
.show:
	PHX
	REP #$20
	LDX #$001A
-	LDA.l !EXO,x
	STA.l $7E0700+(115*4),x
	DEX
	DEX
	BPL -
	SEP #$20
	LDA.l $7E0900+28        ; 115..121 large, x bit 8 clear
	AND #$3F
	ORA #$80
	STA.l $7E0900+28
	LDA #$AA
	STA.l $7E0900+29
	LDA.l $7E0900+30
	AND #$F0
	ORA #$0A
	STA.l $7E0900+30
	PLX
	RTL

; menu_pre, first thing: Z set = the original menu (solo, or the game's own
; window from solo play is still open); Z clear = the shared menu runs
join_edge_l:
	LDA.l !JOINED
	BNE .on
	REP #$20                ; solo: presses belong to the game's own menu -
	LDA #$0000              ; none may carry over into the shared one
	STA.l !ACC
	STA.l !ACC+2
	STA.l !ACC+4
	SEP #$20
	LDA #$00
	STA.l !JPRV
	RTL
.on:
	LDA.l !JPRV
	BNE .yes
	LDA.l !SUBWIN           ; a window opened in solo play: the player of
	ORA.l !TARGET           ; that character closes it first (their pad
	BEQ +                   ; drives the game's own window)
	LDA #$00
	RTL

+	LDA #$01
	STA.l !JPRV
	LDX #$0002              ; everyone starts on their boxes
-	LDA #$00
	STA.l !MODE,x
	STA.l !PROW,x
	DEX
	BPL -
	STA.l !RSLOT
	REP #$20
	LDA #$0000
	STA.l !ACC
	STA.l !ACC+2
	STA.l !ACC+4
	SEP #$20
.yes:
	LDA #$01
	RTL

!TGI  = $7F1EE7         ; tgt_set_l: the target's battle id
!RTRY = $7F1EE8         ; rp_check_l: tries so far
!RBK  = $7F1EE9         ; rp_back_l: ticks spent backing out

; replay, the game's picker is open.  A = the player's target index, X =
; slot.  The shared menu's list is the game's own (cand_far_l), so the index
; is the game's index.  (Never checked against $99C0: for an area move the
; game rewrites that every frame with who the move hits.)
tgt_set_l:
	CMP #$0B
	BCS .out
	PHX
	PHA
	LDA.l !S
	PHA
	TXA
	STA.l !S
	LDA 2,s
	JSL cand_far_l
	STA.l !TGI
	PLA
	STA.l !S
	PLA
	PLX
	PHA
	LDA.l !TGI
	CMP #$0B
	PLA
	BCS .out                ; that target is gone: the game's own default
	STA.l $7E9614
.out:
	RTL

; replay, X = slot: the game's picker opened.  A Tech / Item / Comb that
; the game took as an Attack (command 0, no list) is backed out of with B
; and replayed from the top; after 3 tries the move is dropped, never
; swapped.  Carry set = handled (the caller waits).
rp_check_l:
	LDA.l !TARGET
	BEQ .ok
	LDA.l !PROW,x
	BEQ .ok                 ; an Attack was wanted
	LDA.l $7E9615
	BEQ .bad
	JSL ally_ok_l           ; SUBWIN set, or a pick of one ally (trail.asm)
	BCC .ok
.bad:
	LDA #$08                ; back out first (rp_back_l)
	STA.l !RSTEP
	LDA #$00
	STA.l !RBK
	SEC
	RTL
.ok:
	LDA #$00
	STA.l !RTRY
	CLC
	RTL


; replay step 8, X = slot: out of the game's picker (B, every other tick so
; each is a fresh press), then out of its list (cleared, as after any
; cancelled pick); then replay the move from the top - or after 3 tries,
; drop it and give the player their boxes back
rp_back_l:
	LDA.l !TARGET
	BEQ .nopick
	LDA.l !RBK              ; (rp_pad_l presses B on the odd ticks)
	INC
	STA.l !RBK
	RTL
.nopick:
	LDA.l !SUBWIN
	BEQ .out
	LDA #$00
	STA.l !SUBWIN
	RTL
.out:
	LDA.l !RTRY
	INC
	STA.l !RTRY
	CMP #$03
	BCS .drop
	LDA #$00
	STA.l !RSTEP
	RTL
.drop:
	LDA #$00
	STA.l !MODE,x
	STA.l !RSLOT
	STA.l !RSTEP
	STA.l !RTRY
	RTL

; battle_input, the game's held buttons while a replay runs (A 16-bit):
; nothing - except B on every other tick while backing out (step 8)
rp_pad_l:
	SEP #$20
	LDA.l !RSTEP
	CMP #$08
	BNE .zero
	LDA.l !RBK
	AND #$01
	BEQ .zero
	REP #$20
	LDA #$000A              ; (the game's own button format: B = cancel)
	RTL
.zero:
	REP #$20
	LDA #$0000
	RTL

; battle_input: A (16-bit) = the menu owner's held buttons -> what the game's
; own menu may hear.  Solo: everything.  3 players: nothing while the shared
; boxes are up (a press there must never reach the game's hidden top menu -
; its cursor is on Attack); the replay talks to it instead.  Its own picker
; driven by the move's owner (step 7) or a window open outside the replay:
; the owner's buttons.  Backing out of a wrong pick (step 8): B.
pad_gate_l:
	PHA
	SEP #$20
	LDA.l !JOINED
	BEQ .keep
	LDA.l !RSLOT
	BEQ .norep
	LDA.l !RSTEP
	CMP #$07
	BEQ .keep
	CMP #$08
	BNE .zero
	REP #$20
	PLA
	JSL rp_pad_l
	RTL
.norep:
	LDA.l !TARGET
	ORA.l !SUBWIN
	BNE .keep
.zero:
	REP #$20
	PLA
	LDA #$0000
	RTL
.keep:
	REP #$20
	PLA
	RTL

!CQ   = $7F1EEA         ; cand_far_l: index wanted
!CR   = $7F1EEB         ;   its battle id
!CT   = $7F1EEC         ;   target type
!CV   = $7F1EED         ;   temp
!CX0  = $7F1EEE         ; aim_nav_l: where the hand is now
!CY0  = $7F1EEF
!CBST = $7F1EF0         ;   best so far (index)
!CK   = $7F1EF1         ;   its distance (word)
!CI   = $7F1EF3         ;   index
!CD   = $7F1EF4         ;   direction (d-pad bits)
!CANDL = $7F1EF5        ; 11: the candidates' battle ids, in the game's order

; slot !S, A = index wanted (FF none) -> A = that candidate's battle id (FF
; none), !N = how many, !CANDL = all of them.  The game's own list for the
; type (C1:2045 + C1:27C5): enemies 3..10 in order; allies the caster first,
; then the others in order; each present, not down, not untargetable (a KO'd
; ally only for type 04, revive)
cand_far_l:
	PHP
	SEP #$20
	REP #$10
	PHX
	STA.l !CQ
	LDA #$00
	STA.l !N
	LDA #$FF
	STA.l !CR
	LDA.l !S
	%tax8()
	LDA.l !TTYPE,x
	STA.l !CT
	AND #$7F
	CMP #$21
	BCS .done
	%tax8()
	LDA.l target_class,x
	CMP #$02
	BEQ .enemies
	LDA.l !S                ; allies: the caster first
	%tax8()
	JSR cand_try
	LDX #$0000
.al:
	TXA
	CMP.l !S
	BEQ +
	JSR cand_try
+	INX
	CPX #$0003
	BNE .al
	BRA .done
.enemies:
	LDX #$0003
.en:
	JSR cand_try
	INX
	CPX #$000B
	BNE .en
.done:
	PLX
	PLP
	LDA.l !CR
	RTL

; X = a battle id: listed if the game would list it
cand_try:
	LDA.l $7E96F5,x
	BEQ .no
	LDA.l $7E9FF7,x
	BMI .no
	LDA.l $7EA09B,x
	BNE .no
	LDA.l $7EA0A8,x
	BEQ .ok
	LDA.l !CT
	AND #$7F
	CMP #$04
	BNE .no
.ok:
	PHX
	TXA
	STA.l !CV
	LDA.l !N
	CMP.l !CQ
	BNE +
	LDA.l !CV
	STA.l !CR
+	LDA.l !N
	CMP #$0B
	BCS +
	%tax8()
	LDA.l !CV
	STA.l !CANDL,x
	INX
	TXA
	STA.l !N
+	PLX
.no:
	RTS

; aiming, slot !S, !T1 = d-pad: move the hand to the nearest candidate in
; that direction on screen (up / down by height, left / right by width); past
; the last one it wraps to the far side
aim_nav_l:
	PHP
	SEP #$20
	REP #$10
	LDA.l !T1
	AND #$0F
	BNE +
	JMP .out
+	STA.l !CD
	LDA #$FF
	JSL cand_far_l          ; !N, !CANDL
	LDA.l !N
	CMP #$02
	BCS +
	JMP .out
+	LDA.l !S
	%tax8()
	LDA.l !TIDX,x
	CMP.l !N
	BCC +
	LDA #$00
+	STA.l !CI               ; (the current one, for now)
	%tax8()
	LDA.l !CANDL,x
	%tax8()
	LDA.l $7E1D0C,x
	STA.l !CX0
	LDA.l $7E1D23,x
	STA.l !CY0
	JSR nav_pass            ; the nearest one that way
	LDA.l !CBST
	CMP #$FF
	BNE .set
	LDA.l !CD               ; none: wrap to the far side
	ORA #$80
	STA.l !CD
	JSR nav_pass
	LDA.l !CBST
	CMP #$FF
	BEQ .out
.set:
	PHA
	LDA.l !S
	%tax8()
	PLA
	STA.l !TIDX,x
.out:
	PLP
	RTL

; one pass over the candidates -> !CBST (FF none).  !CD: bit 3 up, 2 down,
; 1 left, 0 right; bit 7 = wrap (the farthest the other way)
nav_pass:
	LDA #$FF
	STA.l !CBST
	REP #$20
	LDA #$FFFF
	STA.l !CK
	SEP #$20
	LDY #$0000
.cand:
	TYA
	CMP.l !CI
	BNE +
	JMP .next
+	TYX
	LDA.l !CANDL,x
	%tax8()
	LDA.l !CD
	AND #$0C
	BEQ .horiz
	LDA.l $7E1D23,x         ; up / down: along the height
	STA.l !CV
	LDA.l $7E1D0C,x
	SEC
	SBC.l !CX0
	BCS +
	EOR #$FF
	INC
+	PHA                     ; the sideways distance
	LDA.l !CD
	AND #$04
	BNE .down
	LDA.l !CY0              ; up: it must be above
	SEC
	SBC.l !CV
	BRA .along
.down:
	LDA.l !CV
	SEC
	SBC.l !CY0
	BRA .along
.horiz:
	LDA.l $7E1D0C,x         ; left / right: along the width
	STA.l !CV
	LDA.l $7E1D23,x
	SEC
	SBC.l !CY0
	BCS +
	EOR #$FF
	INC
+	PHA
	LDA.l !CD
	AND #$01
	BNE .right
	LDA.l !CX0
	SEC
	SBC.l !CV
	BRA .along
.right:
	LDA.l !CV
	SEC
	SBC.l !CX0
.along:                         ; A = distance that way (carry clear: behind)
	PHP
	PHA
	LDA.l !CD
	BMI .wrap
	PLA
	PLP
	BCC .drop
	BEQ .drop               ; level with the hand: not "that way"
	BRA .key
.wrap:                          ; wrapping: the farthest the other way (behind
	PLA                     ; it, distance negative): smallest key = most
	PLP
	BCS .drop               ; negative = 256 - |d|
	EOR #$FF
	INC
	EOR #$FF                ; (key = 255 - |d|)
.key:
	REP #$20
	AND #$00FF
	ASL                     ; along counts double
	STA.l !CV-1             ; (scratch word, high byte is !CQ-free space)
	SEP #$20
	PLA                     ; + the sideways distance
	REP #$20
	AND #$00FF
	CLC
	ADC.l !CV-1
	CMP.l !CK
	SEP #$20
	BCS .next
	REP #$20
	STA.l !CK
	SEP #$20
	TYA
	STA.l !CBST
	BRA .next
.drop:
	PLA
.next:
	INY
	TYA
	CMP.l !N
	BCS +
	JMP .cand
+	RTS

; menu tick: carry set = redraw all three boxes now - when anyone pressed
; something (so a press always shows immediately), the replay is moving, or
; anyone's menu state, HP or MP changed.  Otherwise menu.asm redraws one box
; every other tick (all three every tick took the battle's spare time)
!DSIG = !RAMB+$FF       ; dd_sig at the last menu tick
draw_due_l:
	JSL dd_sig_l            ; (trail.asm)
	CMP.l !DSIG
	PHP
	STA.l !DSIG
	PLP
	BNE .yes
	LDA.l !RSLOT            ; (the replay moves the game's menu: keep up)
	BNE .yes
	REP #$20
	LDA.l !CUR
	ORA.l !CUR+2
	ORA.l !CUR+4
	SEP #$20
	BNE .yes
	CLC
	RTL
.yes:
	SEP #$20
	SEC
	RTL



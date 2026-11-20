; =====================================================================
; World map: FREE MOVEMENT for players 2 and 3
;   The world map is its own engine (bank C2).  Each party member is a
;   64-byte record ($0D70 + party slot * $40): +$00 routine, +$02 state,
;   +$12/+$14 X (frac/int), +$16/+$18 Y, +$1A/+$1C X speed, +$1E/+$20 Y
;   speed, +$22 terrain of the tile ahead, +$24 party slot, +$28 facing
;   (0 up 1 down 2 left 3 right, +$80 walking).  Followers run C2:3AE2,
;   which walks after the leader.
;   Hook: C2:3AE7 "LDA $7E2980,X" (X = party slot) in the follower routine.
;   When that slot's player has joined and walks freely, we move the record
;   the way the leader's routine (C2:3567..) does - one direction at a
;   time, 1 px a frame, the same tile check (C2:3A56/3A8F/39D5/39C3) - and
;   make the game's routine return at once.
;   * follow mode (start, after a regroup): the game's own following
;   * d-pad: free
;   * hold Select 1/2 s, or 1.5 s too far from the leader: regroup
;   * can't walk more than ~100 x 80 px away from the leader (the screen)
; =====================================================================

!OP    = $7E060C        ; party slot (1, 2)
!OI    = $7E060D        ; slot-1
!ORAW  = $7E060E        ; word: raw pad
!OMODE = $7E0610        ; 2: 0 follow, 1 free
!OSEL  = $7E0612        ; 2: frames Select held
!OFAR  = $7E0614        ; 2: frames too far away
!ODIR  = $7E0616        ; direction this frame (0-3, FF none)
!OREC  = $7E0618        ; word: this record
!OLEAD = $7E061A        ; word: the leader's record
!VOTE  = $7E061C        ; 3 words: the exit each player chose (FFFF none)
!OPREV = $7E0622        ; 2: followers' buttons last frame
!OT1   = $7E0624        ; word temps (the game's direct page is in use)
!OT2   = $7E0626
!OT3   = $7E0628
!LOWN  = $7E062A        ; whose place the name label shows (0 leader, 1/2 slot)
!OLEX  = $7E062B        ; word: the leader's exit last frame
!OEXIT = $7E062D        ; 2 words: each follower's exit last frame
!OSDIR = $7E0638        ; 2: direction of the step under way (FF none)
!OIDL  = $7F1E44        ; 2: follower idle pose: 1 = start it, 2 = playing
!OIDC  = $7F1E46        ; 2: frames each free follower has stood still
!LIDLE = $7F1E4A        ; 1: the leader pressed A off a place - his wait pose
!LFADE = $7F1E49        ; slot whose label is fading out (1/2; else none)

macro c2call(addr, ret)
	PHK
	PEA.w <ret>-1
	PEA.w $8008             ; C2:8009 is an RTL byte
	JML <addr>
<ret>:
endmacro

org $C23AE7
	JSL ow_fol

; idle poses only while waiting on a vote: the game's 4-second idle counters
; (leader $02B1, followers $02B2/$02B3: "INC $02B1 / LDA $02B1") count only
; while that character's vote stands, and stay at 0 otherwise
org $C235BD
	JSL idle_lead
	NOP
	NOP
org $C23C97
	JSL idle_f1
	NOP
	NOP
org $C23CB7
	JSL idle_f2
	NOP
	NOP

; the leader's routine, every world-map frame: "LDA $027C / CMP #$01"
org $C23567
	JSL ow_tick
	NOP

org $C299DE                     ; the main menu opens: "STZ $0411 / STZ $0412"
	JSL menu_init
	NOP
	NOP

; leader's A on a location: "LDA $1B32 / BMI no / SEP / LDA #3 / STA $027C /
; BRA" -> a vote (with partners joined, two players must pick the place)
org $C235E5
	JSL ow_leadA            ; N set: don't enter (yet)
	db $30,$91              ; BMI $C2357C  (asar mis-encodes long branch targets)
	db $80,$C6              ; BRA $C235B3

; the place-name label follows its owner: "LDA $0283 / STA $0014,X /
; LDA $0285 / STA $0018,X" (12 bytes, A 16-bit, X = label record)
org $C25734
	JSL ow_lblpos
	NOP #8

; the leader's "not on a place: clear the label" each frame (STZ $1B58 /
; LDX #$FFFF, 6 bytes, A 8-bit X 16-bit): keep a player's place showing
org $C232A6
	JSL ow_lblclr
	NOP
	NOP

; the leader's per-step place re-check starts "STZ $1B58 / STZ $00" (5 bytes,
; A 8-bit): leave a player's place name alone (no flicker / re-show)
org $C2334B
	JSL ow_lblclr2
	NOP

org !CB|$EB00
; A 8-bit, X 16-bit = party slot, D = 0, DB = $00, $4E = record
ow_fol:
	LDA #$00                ; (gameplay: not on the file screen)
	STA.l !FSFLAG
	LDA #$02                ; (the world map is running)
	STA.l !OWALIVE
	LDA.l $7E2980,x         ; the instruction we replaced
	BMI .ret                ; (not in the party)
	PHX                     ; (the record loop keeps state in X/Y)
	PHY
	PHA
	JSR ow_free             ; carry set: we moved it this frame
	PLA
	PLY
	PLX
	PHP
	REP #$20                ; the routine goes on to LDA/ASL/TAX with 8-bit A:
	AND #$00FF              ; A's hidden high byte must be 0 again
	SEP #$20
	PLP
	BCC .ret2
	LDA #$FF                ; -> the routine's "BPL" isn't taken: it returns
.ret:
	RTL
.ret2:
	CMP #$00                ; (flags for the routine's BPL)
	RTL

ow_tick:
	LDA #$08                ; (gameplay is running: see pad_merge)
	STA.l !GAMEON
	LDA #$00                ; (the X menu is closed)
	STA.l !MENUON
	STA.l !FSTEP            ; (no follower steps on the world map)
	JSL ctl_field_l         ; (RetroArch ports 4/5)
if !CTPLUS
	JSR ctp_appear
endif
	JSR p1_pad              ; the leader's d-pad: his A wait pose ends
	XBA
	AND #$0F
	BEQ +
	LDA #$00
	STA.l !LIDLE
+
	LDA.l $00027C
	CMP #$01
	RTL

; ---------------------------------------------------------------------
ow_free:
	PHP
	REP #$20
	LDA.l !VOTE             ; the leader's vote lasts while he's on that exit
	CMP.l $001B32
	BEQ +
	LDA #$FFFF
	STA.l !VOTE
+	SEP #$20
	REP #$10
	TXA
	STA.l !OP
	DEC
	STA.l !OI
	LDA.l !OP
	JSR owner               ; slot 1 -> P2, 2 -> P3 (when joined)
	CMP.l !OP
	BEQ +
	JSR ow_follow
	LDA.l !OP               ; nobody's: no vote
	ASL
	%tax8()
	REP #$20
	LDA #$FFFF
	STA.l !VOTE,x
	PLP
	CLC
	RTS
+	REP #$20
	LDA $4E
	STA.l !OREC
	LDA.l !OP
	AND #$00FF
	XBA
	LSR
	LSR                     ; slot * $40
	EOR #$FFFF
	SEC
	ADC $4E
	STA.l !OLEAD            ; $4E - slot*$40
	SEP #$20
	LDA.l !OP
	JSR seat_raw_mv         ; (Follow: only "Select held" - glued to the leader)
	STA.l !ORAW
	SEP #$20
	JSR ow_fvote            ; A on a location: this player's vote
	; hold Select 1/2 s: regroup
	LDA.l !OI
	%tax8()
	LDA.l !ORAW+1
	AND #$20
	BEQ .nosel
	LDA.l !OSEL,x
	CMP #$FF
	BEQ .seldone
	INC
	STA.l !OSEL,x
	CMP #30
	BNE .seldone
	JSR ow_regroup
	BRA .seldone
.nosel:
	LDA #$00
	STA.l !OSEL,x
.seldone:
	LDA.l !OI
	%tax8()
	LDA.l !OMODE,x
	BNE .free
	LDA.l !OSEL,x           ; following: the d-pad frees it
	BNE .follow
	LDA.l !ORAW+1
	AND #$0F
	BEQ .follow
	LDA #$01
	STA.l !OMODE,x
	LDA #$00
	STA.l !OFAR,x
	BRA .free
.follow:
	PLP
	CLC
	RTS
.free:
	JSR ow_far              ; too far from the leader for 1.5 s: regroup
	SEP #$20
	BCC .near
	LDA.l !OI
	%tax8()
	LDA.l !OFAR,x
	INC
	STA.l !OFAR,x
	CMP #90
	BCC .walk
	JSR ow_regroup
	PLP
	CLC
	RTS
.near:
	LDA.l !OI
	%tax8()
	LDA #$00
	STA.l !OFAR,x
.walk:
	JSR ow_step
	SEP #$20
	REP #$10
	%c2call($C20E1D, ow_r1) ; sprite
	PLP
	SEC
	RTS

; following again: clear the timers
ow_follow:
	PHP
	SEP #$20
	REP #$10
	LDA.l !OI
	%tax8()
	LDA #$00
	STA.l !OMODE,x
	STA.l !OFAR,x
	PLP
	RTS

; carry set when the record is more than ~100 x 80 px from the leader
ow_far:
	REP #$30
	LDX.w #116              ; (past the leash: only when the leader walked off)
	LDY.w #96
	JMP ow_dist

; X = x limit, Y = y limit (16-bit) -> carry set if this record is farther
; than that from the leader in either direction (the world wraps: $600 x $400)
ow_dist:
	PHX
	LDA.l !OREC
	TAX
	LDA $14,x
	PHA
	LDA.l !OLEAD
	TAX
	PLA
	SEC
	SBC $14,x
	BPL +
	EOR #$FFFF
	INC
+	CMP #$0300              ; across the wrap
	BCC +
	EOR #$FFFF
	SEC
	ADC #$0600
+	PLX
	STX $00                 ; (scratch the game also uses)
	CMP $00
	BCS .far
	LDA.l !OREC
	TAX
	LDA $18,x
	PHA
	LDA.l !OLEAD
	TAX
	PLA
	SEC
	SBC $18,x
	BPL +
	EOR #$FFFF
	INC
+	CMP #$0200
	BCC +
	EOR #$FFFF
	SEC
	ADC #$0400
+	STY $00
	CMP $00
	BCS .far
	CLC
	RTS
.far:
	SEC
	RTS

; one frame of walking for record !OREC (= $4E); D = 0 so "$1C,x" is the
; record's +$1C
ow_step:
	PHP
	REP #$30
	LDA.l !OREC
	TAX
	STZ $1A,x
	STZ $1C,x
	STZ $1E,x
	STZ $20,x
	; like the leader, walk in whole 8 px steps: the ground is checked when a
	; step starts, and a step under way is always finished
	SEP #$20
	PHX
	LDA.l !OI
	%tax8()
	LDA.l !OSDIR,x
	PLX
	CMP #$04
	BCS ows_grid            ; no step under way
	STA.l !ODIR
	CMP #$02                ; the axis it moves on: on the grid yet?
	REP #$20
	BCS +
	LDA $18,x               ; up / down: y
	BRA ++
+	LDA $14,x               ; left / right: x
++	AND #$0007
	SEP #$20
	BEQ ows_grid
	JSR ow_setvel           ; mid-step: finish it
	JMP ows_go
ows_grid:
	LDA.l !ORAW+1           ; the leader's order: up, down, left, right
	LDY.w #$0000
	BIT #$08
	BNE ows_dir
	INY
	BIT #$04
	BNE ows_dir
	INY
	BIT #$02
	BNE ows_dir
	INY
	BIT #$01
	BNE ows_dir
	JMP ows_idle
ows_dir:
	PHX                     ; walking again: no idle pose
	LDA.l !OI
	%tax8()
	LDA #$00
	STA.l !OIDL,x
	STA.l !OIDC,x
	PLX
	TYA
	STA.l !ODIR
	JSR ow_setvel
	; the leader's tile check: the tile 8 px ahead
	%c2call($C23A56, ow_r2)
	%c2call($C23A8F, ow_r3)
	REP #$30
	LDA.l !OREC
	TAX
	LDA $24,x               ; (the tile lookup writes +$22..+$25; on a
	PHA                     ; follower +$24 is its party slot)
	LDA $2A,x
	STA $08
	LDA $2C,x
	STA $0A
	%c2call($C239D5, ow_r4)
	%c2call($C239C3, ow_r5)
	REP #$30
	PLA
	PHP                     ; (keep the carry)
	LDX $4E
	STA $24,x
	PLP
	BCS ows_blocked
	REP #$30                ; not past the leash (unless stepping back)
	LDX.w #100
	LDY.w #80
	JSR ow_dist
	BCC ows_go
	JSR ow_closer
	BCC ows_go
ows_blocked:
	REP #$30
	LDA.l !OREC
	TAX
	STZ $1C,x
	STZ $20,x
	SEP #$20
	LDA.l !ODIR             ; face the way pressed, standing
	STA $28,x
	JMP ows_stand
ows_go:
	SEP #$20
	REP #$10
	LDA.l !OI               ; the step under way
	%tax8()
	LDA.l !ODIR
	STA.l !OSDIR,x
	REP #$30
	LDA.l !OREC
	TAX
	SEP #$20
	LDA.l !ODIR
	ORA #$80
	CMP $28,x
	BEQ +
	STA $28,x
	JSR ow_char
	SEP #$20
	REP #$10
	%c2call($C23953, ow_r6) ; walking animation
+	REP #$30
	%c2call($C20F38, ow_r7) ; move
	REP #$30
	%c2call($C21CB8, ow_r8) ; wrap around the world
	PLP
	RTS
ows_idle:
	SEP #$20
	REP #$10
	LDA.l !OI
	%tax8()
	LDA #$FF
	STA.l !OSDIR,x
	REP #$30
	LDA.l !OREC
	TAX
	SEP #$20
	LDA $28,x
	AND #$7F
	STA $28,x
ows_stand:
	JSR ow_char
	SEP #$20
	REP #$10
	PHX
	LDA.l !OI
	%tax8()
	LDA.l !OIDL,x           ; idle pose only while waiting on a vote
	BEQ ows_std
ows_idl:
	CMP #$02
	BEQ ows_keep            ; already in the idle pose: let it play
	LDA #$02
	STA.l !OIDL,x
	PLX
	LDA.l !OP               ; the idle animation of this party slot: $A2 /
	CLC                     ; $A3 / $A4 (each shows that slot's own idle frame,
	ADC #$A2                ; loaded at tile $160 / $162 / $164)
	%c2call($C21CDA, ow_r10)
	PLP
	RTS
ows_keep:
	PLX
	PLP
	RTS
ows_std:
	PLX
	%c2call($C23987, ow_r9) ; standing
	PLP
	RTS

; record X: speed from !ODIR (1 px a frame)
ow_setvel:
	PHP
	REP #$30
	PHX
	LDA.l !ODIR
	AND #$00FF
	ASL
	TAX
	LDA.l ow_dx,x
	TAY
	LDA.l ow_dy,x
	PLX
	STA $20,x
	TYA
	STA $1C,x
	PLP
	RTS

; $00 = this party member's character id (the animation routines want it)
ow_char:
	PHP
	SEP #$20
	REP #$10
	LDA.l !OP
	%tax8()
	LDA.l $7E2980,x
	STA $00
	PLP
	RTS

; carry clear if this step brings the record closer to the leader
ow_closer:
	REP #$30
	LDA.l !OREC
	TAX
	LDA.l !OLEAD
	TAY
	LDA $14,x
	SEC
	SBC $0014,y             ; record - leader (x)
	STA $00
	LDA $1C,x
	BEQ .y
	EOR $00                 ; moving against the sign of the gap: closer
	BMI .yes
	BRA .no
.y:
	LDA $18,x
	SEC
	SBC $0018,y
	STA $00
	LDA $20,x
	BEQ .no
	EOR $00
	BMI .yes
.no:
	SEC
	RTS
.yes:
	CLC
	RTS

; back to the leader, following
ow_regroup:
	PHP
	REP #$30
	LDA.l !OLEAD
	TAY
	LDA.l !OREC
	TAX
	LDA $0012,y
	STA $12,x
	LDA $0014,y
	STA $14,x
	LDA $0016,y
	STA $16,x
	LDA $0018,y
	STA $18,x
	STZ $1A,x
	STZ $1C,x
	STZ $1E,x
	STZ $20,x
	SEP #$20
	STZ $02,x               ; the follow routine starts over
	STZ $03,x
	STZ $04,x
	JSR ow_follow
	PLP
	RTS

ow_dx:	dw $0000, $0000, $FFFF, $0001
ow_dy:	dw $FFFF, $0001, $0000, $0000

; ---------------------------------------------------------------------
; voting for a location

; A(16) = record -> A(16) = offset of the exit under it in $7E7E00 (FFFF
; none): the game's own lookup (C2:32CD) for any position
ow_exit:
	PHX
	PHY
	TAX
	LDA $14,x               ; x / 16
	LSR
	LSR
	LSR
	LSR
	SEP #$20
	STA $00
	REP #$20
	LDA $18,x               ; y / 16
	LSR
	LSR
	LSR
	LSR
	SEP #$20
	STA $01
	LDA.l $001B38           ; number of exits
	REP #$20
	AND #$00FF
	BEQ .none
	TAY
	LDX #$0000
-	LDA.l $7E7E00,x
	BIT #$0080
	BEQ +
	AND #$3F7F
	CMP $00
	BEQ .found
+	TXA
	CLC
	ADC #$0007
	TAX
	DEY
	BNE -
.none:
	LDA #$FFFF
	PLY
	PLX
	RTS
.found:
	TXA
	PLY
	PLX
	RTS

; X = player*2, A(16) = exit (FFFF none): record the vote; carry set if
; enough players now chose that place (2, or 1 when nobody else joined)
ow_vote:
	STA.l !VOTE,x
	CMP #$FFFF
	BEQ .no
	STA.l !OT1
	JSR ow_voters           ; how many must agree
	PHA
	LDA #$0000              ; votes agree when they're for the same PLACE -
	STA.l !VCNT             ; any of its tiles (see same_place)
	LDX #$0000
-	LDA.l !VOTE,x
	CMP #$FFFF
	BEQ +
	PHX
	TAX
	LDA.l !OT1
	TAY
	SEP #$20
	JSR same_place
	REP #$20
	PLX                     ; (keeps the carry)
	BCC +
	LDA.l !VCNT
	INC
	STA.l !VCNT
+	INX
	INX
	CPX #$0006
	BNE -
	LDA.l !VCNT
	CMP 1,s
	PLA                     ; (keeps the carry)
	BCS .yes
.no:
	CLC
	RTS
.yes:
	LDA #$0000              ; nobody is waiting any more
	STA.l !OIDL
	LDA #$FFFF              ; everyone's vote is used up
	STA.l !VOTE
	STA.l !VOTE+2
	STA.l !VOTE+4
	SEC
	RTS

; A (16-bit) = players who must vote: the leader, plus each follower seat
; that a joined player drives on Ready (Follow / Idle agree with the leader)
; and that has a character in it
ow_voters:
	SEP #$20
	LDY.w #$0001
	LDA.l !JOINED           ; seat 1
	AND #$02
	BEQ +
	LDA #$01
	JSR pst_seat
	CMP #$00
	BNE +
	LDA.l $7E2981           ; (negative: nobody in that slot)
	BMI +
	INY
+	LDA.l !JOINED           ; seat 2
	AND #$04
	BEQ +
	LDA #$02
	JSR pst_seat
	CMP #$00
	BNE +
	LDA.l $7E2982
	BMI +
	INY
+	REP #$20
	TYA
	RTS

; the leader's A (A 16-bit, X = record): N clear = enter now
ow_leadA:
	PHX
	PHY
	PHD
	REP #$30
	LDA #$0000
	TCD
	LDA.l $001B32
	BMI .rest
	LDX #$0000
	JSR ow_vote
	BCS +
	SEP #$20                ; voted, waiting for the others: the game's own idle
	LDA #$F0                ; pose (it plays when the counter passes $F0)
	STA.l $0002B1
	BRA .no
+
	SEP #$20
	LDA #$03                ; (what the original does)
	STA.l $00027C
	REP #$30
	PLD
	PLY
	PLX
	LDA #$0000
	RTL
.rest:
	SEP #$20                ; A on no place: the wait pose, like the others'
	LDA #$01
	STA.l !LIDLE
	LDA #$F0
	STA.l $0002B1
.no:
	REP #$30
	PLD
	PLY
	PLX
	LDA #$FFFF
	RTL

; a follower's player (A 8-bit): their vote stays only while they stand on
; that exit; a new A press votes for the exit under them
ow_fvote:
	PHP
	REP #$30
	LDA.l !OREC
	JSR ow_exit
	STA.l !OT2
	JSR ow_label
	LDA.l !OP
	AND #$00FF
	ASL
	TAX
	LDA.l !VOTE,x
	CMP.l !OT2
	BEQ +
	LDA #$FFFF              ; stepped off it
	STA.l !VOTE,x
+	LDA.l !ORAW
	JSR map_pad
	SEP #$20
	PHA
	LDA.l !OI
	%tax8()
	LDA.l !OPREV,x
	EOR #$FF
	AND 1,s
	STA.l !OT3
	PLA
	STA.l !OPREV,x
	LDA.l !OT3
	AND #$80                ; confirm
	BEQ .done
	REP #$30
	LDA.l !OP
	AND #$00FF
	ASL
	TAX
	LDA.l !OT2
	JSR ow_vote
	BCS +
	SEP #$20                ; voted, waiting for a partner: the idle pose
	LDA.l !OI
	%tax8()
	LDA #$01
	STA.l !OIDL,x
	BRA .done
+
	REP #$30
	LDA.l !OT2                 ; enough votes: in we go
	STA.l $001B32
	SEP #$20
	LDA #$03
	STA.l $00027C
.done:
	PLP
	RTS

; ---------------------------------------------------------------------
; the place-name label: the place of whoever stepped onto one last
; (A/X 16-bit; !OT2 = exit under this follower)
ow_label:
	LDA.l !OT2              ; (a follower may still vote: keep its exit)
	PHA
	JSR ow_label_in
	PLA
	STA.l !OT2
	RTS
ow_label_in:
	LDA.l $001B32           ; the leader stepped onto a place: his label
	CMP.l !OLEX
	BEQ +
	STA.l !OLEX
	CMP #$FFFF
	BEQ +
	JSR ow_keep             ; the same place name a player shows: theirs it stays
	BCS +
	SEP #$20
	LDA.l !LOWN             ; (taken from a player: the game wrote his name
	BEQ ++                  ; without asking the label to redraw)
	LDA #$01
	STA.l $001B59
++	LDA #$00
	STA.l !LOWN
	REP #$20
+	LDA.l !OP
	AND #$00FF
	DEC
	TAX
	LDA.l !OMODE,x          ; only a player walking freely shows places (a
	AND #$00FF              ; follower trails the leader over the same ones)
	BNE +
	LDA #$FFFF
	STA.l !OT2
+	TXA
	ASL
	TAX
	LDA.l !OT2
	CMP.l !OEXIT,x
	BEQ .same
	STA.l !OEXIT,x
	CMP #$FFFF
	BEQ .off
	SEP #$20                ; stepped onto a place: show its name
	LDA.l !OP
	STA.l !LOWN
	REP #$20
	LDA.l !OT2
	JMP ow_show
.off:
	SEP #$20                ; stepped off our place: the leader's again
	LDA.l !LOWN
	CMP.l !OP
	REP #$20
	BNE .done
	SEP #$20
	LDA #$00
	STA.l !LOWN
	REP #$20
	LDA.l $001B32
	CMP #$FFFF
	BEQ .hide
	JMP ow_show
.hide:
	SEP #$20
	LDA.l !OP               ; (it fades out where it was, not over the leader)
	STA.l !LFADE
	LDA #$00
	STA.l $001B58
	REP #$20
.done:
	RTS
.same:
	CMP #$FFFF              ; still on our place: if the leader's walking
	BEQ .done               ; cleared the label, put it back
	SEP #$20
	LDA.l !LOWN
	BNE +
	REP #$20                ; nobody's label, the leader on no place: ours
	LDA.l $001B32
	CMP #$FFFF
	BNE .done
	SEP #$20
	LDA.l !OP
	STA.l !LOWN
	REP #$20
	LDA.l !OT2
	JMP ow_show
+	CMP.l !OP
	BNE .done8
	LDA.l $001B58
	BNE .done8
	REP #$20
	LDA.l !OT2
	JMP ow_show
.done8:
	REP #$20
	RTS

; A(16) = the leader's new exit -> carry set when a player's label is up with
; the same place name (stepping onto another tile of a place someone already
; shows must not redraw it; a redraw replays its animation)
ow_keep:
	PHY
	STA.l !SPE              ; the leader's new exit
	SEP #$20
	LDA.l !LOWN
	REP #$20
	AND #$00FF
	BEQ .noc
	DEC
	ASL
	TAX
	LDA.l !OEXIT,x          ; the place that player's label shows
	CMP #$FFFF
	BEQ .noc
	TAX
	LDA.l !SPE
	TAY
	SEP #$20
	JSR same_place
	REP #$20
	PLY
	RTS
.noc:
	PLY
	CLC
	RTS

; X, Y = two exit offsets (A 8-bit) -> carry set when they're the same place:
; the same name and within 2 tiles (a town is several neighbouring exits;
; two places can share a name, like 600 AD's two Residences).  X is lost.
; Exit records: 7 bytes at 7E:7E00, +0 x (bit 7 a flag), +1 y, +2 name.
same_place:
	LDA.l $7E7E02,x
	STA.l !SPN
	LDA.l $7E7E00,x
	AND #$7F
	STA.l !SPX
	LDA.l $7E7E01,x
	STA.l !SPY
	TYX
	LDA.l $7E7E02,x
	CMP.l !SPN
	BNE .no
	LDA.l $7E7E00,x
	AND #$7F
	SEC
	SBC.l !SPX
	BPL +
	EOR #$FF
	INC
+	CMP #$03
	BCS .no
	LDA.l $7E7E01,x
	SEC
	SBC.l !SPY
	BPL +
	EOR #$FF
	INC
+	CMP #$03
	BCS .no
	SEC
	RTS
.no:
	CLC
	RTS

; A(16) = exit offset: show that place's name
ow_show:
	TAX
	SEP #$20
	LDA #$00                ; (a new name: nothing fading any more)
	STA.l !LFADE
	LDA.l $7E7E02,x
	CMP.l $001B58           ; same name already up (another tile of the same
	BEQ +                   ; place): leave it, a redraw replays its animation
	PHA
	LDA.l $001B58           ; a name showing: ask the label to redraw; none
	BEQ ++                  ; (label idle): it draws by itself, and a
	LDA #$01                ; pending redraw would make it draw twice
	STA.l $001B59
++	PLA
	STA.l $001B58
+	REP #$20
	RTS

; label position: the label owner's record, else the leader's ($0283/$0285)
ow_lblpos:
	PHY
	PHX
	SEP #$20
	LDA.l !LOWN
	BNE .slot
	REP #$20                ; the leader's: unless he's on no place and a
	LDA.l $001B32           ; follower's label is fading out - it stays
	CMP #$FFFF              ; over that follower
	BNE .lead
	SEP #$20
	LDA.l !LFADE
	CMP #$01
	BEQ .slot
	CMP #$02
	BEQ .slot
	REP #$20
	BRA .lead
.slot:
	REP #$20
	AND #$00FF
	XBA
	LSR
	LSR                     ; slot * $40
	CLC
	ADC.l !OLEAD            ; + the leader's record (party slot 0): $0D70, or
	TAY                     ; $0DF0 in CT+ (two more world-map objects)
	PLX
	LDA $0014,y
	STA $0014,x
	LDA $0018,y
	STA $0018,x
	PLY
	RTL
.lead:
	PLX
	LDA $0283
	STA $0014,x
	LDA $0285
	STA $0018,x
	PLY
	RTL

ow_lblclr:
	PHA
	LDA.l !LOWN
	BNE +                   ; a player stands on a place: keep its name up
	LDA #$00
	STA.l $001B58
+	PLA
	LDX #$FFFF
	RTL

ow_lblclr2:
	LDA.l !LOWN
	BNE +
	LDA #$00
	STA.l $001B58
+	STZ $00
	RTL


; battle, no command menu open (the victory messages - exp, gold, items):
; players 2 and 3's A answer them too (the shared pad routine; A 8-bit)
btl_merge:
	LDA.l !MENUSLOT
	BPL +
	REP #$20
	JSR all_pads
	AND.w #$0080
	ORA.l !MERGED
	STA.l !MERGED
+	RTS

; Y = 0/4/8 (Att/Tech/Item row of slot !S) -> !CPAL: !LP, or grey for a Tech
; row with no techs learned / an Item row with no item usable in battle
row_pal:
	PHX
	LDA.l !LP
	STA.l !CPAL
	CMP #!GREY
	BEQ .done
	CPY #$0004
	BEQ .tech
	CPY #$0008
	BNE .done
	LDA.l !ITEMLIST         ; the battle item list: id 0 = empty
	BNE .done
	BRA .grey
.tech:
	LDA.l !S                ; this slot's battle tech list (20 bytes each)
	ASL
	ASL
	PHA
	ASL
	ASL
	CLC
	ADC 1,s
	STA 1,s
	PLA
	%tax8()
	LDA.l !TECHLIST,x
	CMP #$FB
	BCC .done
.grey:
	LDA #!GREY
	STA.l !CPAL
.done:
	PLX
	RTS


if !CTPLUS
; CT+ keeps each character's look (field / world map / battle sprites) in 5
; bytes per character at 7E:28A9 (save offset $4A9).  The original game leaves
; them 0, so a save carried over from it showed everyone as Crono.  Marle's and
; Lucca's both 0 never happens in CT+: put back CT+'s starting table.
ctp_appear:
	PHP
	SEP #$20
	REP #$10
	LDA.l $7E28AE
	ORA.l $7E28B3
	BNE .ok
	PHX
	LDX.w #$0000
-	LDA.l ctp_looks,x
	STA.l $7E28A9,x
	INX
	CPX.w #35
	BNE -
	PLX
.ok:
	PLP
	RTS
ctp_looks:
	db 0,0,0,0,0, 1,1,1,1,0, 2,2,2,2,0, 3,3,3,3,0, 4,4,4,4,0, 5,5,5,5,0, 6,6,$0B,6,0
endif


; =====================================================================
; READY / FOLLOW / IDLE and CLAIMS in the X menu (main page).
;   Select (any pad but the leader's): Ready -> Follow -> Idle -> Ready
;   Y (any pad): claim the character the menu shows
;   Start (anywhere): back to Ready
;   Follow: glued to the leader (the pad reads as "Select held" for the
;           field / world-map movement), no vote, still plays its battles.
;   Idle:   follow and sit out - the pad leaves !PJOIN, so the leader's
;           player drives that character in battle; only Start counts.
;   The menu's left panels: FOLLOW / IDLE, or "P1"-"P3" (the controller
;   driving that character) in place of "LV" when more than one plays.
; =====================================================================
; A(8) = seat -> A(16) = raw pad, or "Select held" for a pad on Follow
seat_raw_mv:
	SEP #$20
	STA.l !PSEAT
	JSR seat_raw
	PHA
	SEP #$20
	PHX
	LDA.l !PSEAT
	%tax8()
	LDA.l !ROLE,x
	%tax8()
	LDA.l !PST,x
	PLX
	CMP #$01
	REP #$20
	BNE +
	PLA
	LDA.w #$2000
	RTS
+	PLA
	RTS


; =====================================================================
; CONTROLLERS FOLLOW THEIR CHARACTERS.
;   Physical pads: 0 = port 1 ($4218), 1 = multitap A ($421A), 2 = multitap
;   B ($421E).  A SEAT is a party slot (0 leader, 1, 2); !ROLE maps each
;   seat to the pad that drives it.  Seat 0's pad does "player 1"'s jobs
;   (leading, the game's own reads of player 1).
;   * a pad joins on its first press and claims the character in its seat
;     (player 2 -> slot 2's character, as before)
;   * Y in the X menu's main page: that pad claims the character the menu
;     shows (swapping with whoever had them)
;   * every frame the seats are rebuilt from the claims, so a pad stays with
;     its character when the party order changes; the leader's pad is
;     always awake
;   !JOINED (bit per seat 1/2) is derived from !PJOIN (bit per pad).
;   Follow / Idle (!PST) belong to the pad - the person - too.
; =====================================================================

; A(8) = seat 0-2 -> A(16) = raw word of its pad
seat_raw:
	SEP #$20
	PHX
	%tax8()
	LDA.l !ROLE,x
	PLX
; A(8) = pad 0-2 -> A(16) raw
pad_raw:
	PHA                     ; (the world map runs during the auto-read)
-	LDA.l $004212
	AND #$01
	BNE -
	PLA
	JSL praw_l              ; the port this pad reads (ctlports.asm)
	RTS

; -> A(16) raw of the leader's pad (A width restored; in 8-bit the high
; byte is in B)
p1_pad:
	PHP
	SEP #$20
	LDA #$00
	JSR seat_raw
	PLP
	RTS

; (A 16-bit) -> every controller's buttons ORed
all_pads:
	LDA.l $004218
	ORA.l $00421A
	ORA.l $00421E
	ORA.l !P4RAW            ; (RetroArch ports 4/5: ctlports.asm)
	ORA.l !P5RAW
	RTS

; once a frame (from the joypad routine): silence timers, joins, seats
update_joined:
	PHP
	REP #$10
	PHX                     ; (called inside the game's joypad routine)
	PHY
	REP #$20
	LDA.l !SIG3P            ; first run since power-on: our RAM ($05EB-$0609)
	CMP #$5033              ; isn't cleared by the game, so clear it
	BEQ +
	SEP #$20
	LDX #$0050              ; $05EB-$063B
-	LDA #$00
	STA.l $7E05EB,x
	DEX
	BPL -
	LDX #$01FF              ; and ours at 7F:1E00-1FFF (7E:06xx is the stack;
-	STA.l $7F1E00,x         ; this tail is unused by both games)
	DEX
	BPL -
	LDA #$FF                ; no votes
	LDX #$0005
-	STA.l $7E061C,x
	DEX
	BPL -
	REP #$20
	LDA #$5033
	STA.l !SIG3P
	SEP #$20
	LDA #$00                ; (scene swap state, outside that block)
	STA.l !ESWAP
	STA.l !OWALIVE
+	JSL claims_init_l
	JSR sp_maybe            ; what event scripts see: every controller
				; (field.asm: not twice - the field runs it in the NMI)
	JSR scene_end
	JSR track_opener        ; whose X opens the main menu
	REP #$20
	LDA.l $000134           ; a message window open as the frame starts
	SEP #$20                ; (its A closes it; fol_act must not also act)
	BEQ +
	LDA #$01
+	STA.l !BOXW
	SEP #$20
	LDX #$0000              ; pad
.pad:
	TXA
	JSR pad_raw
	JSL pad_sane_l          ; stray / noise inputs count as silence
	STA.l !PRAW
	SEP #$20
	BNE .pressed
	CPX #$0000              ; (silence is timed for the multitap pads)
	BEQ .next
	LDA.l !PSIL-1,x
	CMP #$FF
	BEQ .next
	INC
	STA.l !PSIL-1,x
	BRA .next
.pressed:
	CPX #$0000
	BEQ +
	LDA #$00
	STA.l !PSIL-1,x
+	JSL pad_press_l
.next:
	INX
	CPX #$0003
	BNE .pad
	JSL claims_maybe_l      ; seats follow the characters (when something changed)
	JSL menu_modes_l        ; X menu: Select = Ready / Follow / Idle, Y = claim
	PLY
	PLX
	PLP
	RTS

; pad_merge, in vblank: just track whose X opens the menu.  The X menu's
; Select / Y / tags used to run here too, but that NMI work delayed the menu's
; screen-on (black bar) and raced its panel redraw (a stat line squashed) - it
; now runs from the menu's own main loop (ctl_menu2_l, ctlports.asm).
nmi_players:
	PHP
	SEP #$20
	REP #$10
	JSR track_opener        ; (whose X opens the menu: it opens this frame)
	PLP
	RTS

; battle_input, after pushing the buttons the game will hear (word at 4,s
; here): when the replay opens the game's own target picker (step 7), the
; buttons already held then (the press that confirmed the command / joined the
; combo) are ignored until let go - otherwise that press picked the default
; target at once
picker_fresh:
	PHP
	SEP #$20
	LDA.l !RSLOT
	BEQ .off
	LDA.l !RSTEP
	CMP #$07
	BNE .off
	LDA.l !S7ON
	BNE .on
	LDA #$01
	STA.l !S7ON
	REP #$20
	LDA 4,s
	STA.l !S7M
.on:
	REP #$20
	LDA.l !S7M
	AND 4,s                 ; (still held)
	STA.l !S7M
	EOR #$FFFF
	AND 4,s
	STA 4,s
	PLP
	RTS
.off:
	LDA #$00
	STA.l !S7ON
	PLP
	RTS

; pad_merge's exit: when the NMI arrived in the middle of a free follower's
; step (field.asm sets !FSTEP), the joypad routine must not run - it would put
; the leader's buttons into $F8 under the follower's movement code, and the
; step's end would then throw the fresh reading away (both characters' walk /
; run animation broke, worst when both ran).  Return to the routine's RTS
; (C2:8544) instead: the pads update next frame; presses are kept (their edge is
; taken against the last reading).
pad_hold:
	PHP
	SEP #$20
	LDA.l !FSTEP
	CMP #$A5
	BNE +
	REP #$20
	LDA.w #$8543
	STA 7,s                 ; (pad_merge's JSL return)
+	PLP
	RTS

; A(8) = seat -> A(8) = the Follow / Idle state of its pad (X kept)
pst_seat:
	PHX
	%tax8()
	LDA.l !ROLE,x
	%tax8()
	LDA.l !PST,x
	PLX
	RTS

; battle_input, after pushing the menu owner's held buttons (word at 4,s
; here): while the game's target picker is open for a dual / triple tech
; (replay step 7), OR in the held buttons of every partner's player
combo_pads:
	PHP
	SEP #$20
	REP #$10
	LDA.l !RSLOT
	BEQ .out
	LDA.l !RSTEP
	CMP #$07
	BNE .out
	LDA.l !RSLOT
	DEC
	%tax8()
	LDA.l !PMASK,x          ; partner slots, a bit each
	BEQ .out
	STA.l !CMASK
	LDA #$00
	STA.l !CMASK+1          ; slot
.s:
	LDA.l !CMASK+1
	%tax8()
	LDA.l bitmask,x
	AND.l !CMASK
	BEQ .n
	LDA.l !CMASK+1
	JSR owner
	ASL
	%tax8()
	REP #$20
	LDA.l !HELD,x
	ORA 4,s
	STA 4,s
	SEP #$20
.n:
	LDA.l !CMASK+1
	INC
	STA.l !CMASK+1
	CMP #$03
	BNE .s
.out:
	PLP
	RTS

; (moved here from ct3p.asm for room)
script_pads:
	REP #$20
	LDA.l $004218
	ORA.l $00421A
	ORA.l $00421E
	CMP.l !SPLAST           ; the same buttons as last frame: no new presses,
	BNE +                   ; the held copies stand (saves the mapping, the
	SEP #$20                ; costliest part of this routine)
	LDA #$00
	STA.l !MF0
	STA.l !MF6
	RTS
+	STA.l !SPLAST
	PHA
	JSR map_pad
	STA.l !MF8
	PLA
	SEP #$20
	XBA
	LSR
	LSR
	LSR
	LSR
	STA.l !MF2
	XBA
	AND #$F0
	ORA.l !MF2
	STA.l !MF2
	LDA.l !MF0+2            ; (last frame's $F2-layout held)
	EOR #$FF
	AND.l !MF2
	STA.l !MF0
	LDA.l !MF2
	STA.l !MF0+2
	LDA.l !MF6+2            ; (last frame's mapped held)
	EOR #$FF
	AND.l !MF8
	STA.l !MF6
	LDA.l !MF8
	STA.l !MF6+2
	RTS


; (A/X/Y 16-bit) this follower's private copy of the movement working bytes
; $1D2A-$1D35 and $1D50-$1D73 (48 bytes, at !FWORK + position*48) <-> the
; live ones.  Block moves between banks 7F and 7E.
fol_state_in:
	PHB
	JSR fol_state_ix        ; X = its block
	LDY.w #$1D2A
	LDA.w #11
	db $54,$7E,$7F          ; MVN 7F -> 7E
	LDY.w #$1D50
	LDA.w #35
	db $54,$7E,$7F
	PLB
	RTS
fol_state_out:
	PHB
	JSR fol_state_ix
	TXY                     ; Y = its block
	LDX.w #$1D2A
	LDA.w #11
	db $54,$7F,$7E          ; MVN 7E -> 7F
	LDX.w #$1D50
	LDA.w #35
	db $54,$7F,$7E
	PLB
	RTS
fol_state_seed:                 ; (any mode) going free: start from the leader's
	PHP
	REP #$30
	PHA
	PHX
	PHY
	JSR fol_state_out
	PLY
	PLX
	PLA
	PLP
	RTS
fol_state_ix:
	LDA.l !FI
	AND.w #$00FF
	ASL
	ASL
	ASL
	ASL                     ; *16
	STA.l !FWT
	ASL                     ; *32
	CLC
	ADC.l !FWT              ; *48
	CLC
	ADC.w #!FWORK&$FFFF
	TAX
	RTS

warnpc !CB|$F800

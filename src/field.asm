; =====================================================================
; Field: FREE MOVEMENT for players 2 and 3 (interior maps)
;   Each party member's map script runs the "walk as party member" op
;   (C0:3002).  It sends followers to the trail replays C0:A26B (party
;   position 1) and C0:A2CE (position 2).  We keep those calls (they keep
;   the trail chain going) and, when that position's player has joined and
;   is walking freely, replace the step with one computed by the LEADER's
;   own movement code (input, wall collision + sliding, map bounds) run for
;   the follower: $0197 (the leader's object) is pointed at the follower
;   for the call (swapped with the follower's entry in the party list
;   $0197/$0199/$019B, which the object collision skips) and the leader's
;   working bytes in $1D2A-$1D35 / $1D50-$1D73 are put back afterwards.
;   Cutscenes don't run the op, so they're unaffected.
;
;   Party position 1 = player 2, position 2 = player 3.
;   * follow mode (start, new map): trails the leader as in the original
;   * d-pad: free mode
;   * hold Select 1/2 s, or 1.5 s off screen: back on the trail (regroup)
;   * a free character can't walk off the screen edge
; =====================================================================

!FOBJ  = $7E05EB        ; follower's object*2
!FP    = $7E05EC        ; party position (1, 2)
!FPAD  = $7E05F0        ; word: that player's pad, game layout (like $F8)
!FRES  = $7E05F2        ; word: step computed ($1D32/$1D33)
!FDIR  = $7E05F4        ; word: direction pressed ($1D2C/$1D2D)
!FMODE = $7E05F8        ; 2 (per position-1): 0 follow, 1 free
!FOFF  = $7E05FA        ; 2: frames spent off screen 
!FSEL  = $7E05FC        ; 2: frames Select held
!FPX   = $7E0600        ; 2 words: X last frame
!FPY   = $7E0604        ; 2 words: Y last frame 
!FRAW  = $7E05F6        ; word: raw pad
!FI    = $7E05ED        ; position-1
!FK    = $7E05EE        ; trail index (regroup)
!FPREV = $7E05FE        ; 2: last frame's buttons 
!FPEND = $7F1EDD        ; 2 (per position-1): a step is due this frame (fol_late_l)
!UJDUE = $7F1EDF        ; 1: update_joined is due after the pose upload (uj_pick)

; call a near (JSR) routine in bank C0 from here: its RTS lands on an RTL
; byte in bank C0 (C0:9BD4), which returns to us
macro c0call(addr, ret)
	PHK
	PEA.w <ret>-1
	PEA.w $9BD3
	JML <addr>
<ret>:
endmacro

; --- hooks: "LDA #$01 / LDX $6D / STA $1A01,X / JSR $A2CE|$A26B" (10 bytes)
org $C03020
	JSL fol_2
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
org $C03030
	JSL fol_1
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP

; the leader's walk "LDA #$01 / LDX $6D / STA $1A01,X / JSR $9E29" (10 bytes):
; while a scene player 2/3 started is running, the leader stands still
org $C03040
	JSL lead_walk
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP

; object collision skips the party: "CPX $0197 / BEQ / CPX $0199 / BEQ /
; CPX $019B / BEQ" (C0:994A, 15 bytes, X 8-bit).  During a player's scene the
; list holds only that player, so the others are recognised by their party
; position ($1100 < 3) instead - otherwise they'd block the scene's moves
; the field's main loop, every frame: "JSL $C01F87"
org $C000AD
	JSL field_tick

org $C0994A
	JSL party_skip
	db $B0,$E8              ; BCS $C09938 (skip this object)
	NOP #9

; the field NMI's tail: "JSL $C28002" (the joypad routine, with our player
; code inside) ran BEFORE the screen registers were restored (brightness,
; HDMA, colour math).  On a slower emulator the joypad work could push the
; screen-on past the start of the next picture: black flashes.  nmi_tail
; (far.asm) restores them first, then reads the pads.
org $C0EC15
	JSL nmi_tail
warnpc $C0EC19

; the world map's NMI has the same order: C2:031B "JSL $C28002", then the
; screen on (C2:031F-032A).  wm_tail restores first, then reads the pads.
org $C2031B
	JSL wm_tail
warnpc $C2031F

; the sprite-frame queue drain: "JSR $CA76 / REP #$10" (5 bytes; the BRL
; right after must stay) -> JSL drain_fix + NOP; the REP is in the trampoline
org $C000D6
	JSL drain_fix
	NOP
warnpc $C000DB
org $C0FF07                     ; (free bytes FF07-FF0F, before the NMI JML)
	JSR $CA76
	REP #$10
	RTL
warnpc $C0FF10

org !CB|$F900
; entered with A/X 8-bit, D = $0100, DB = $00
fol_1:
	LDA #$01
	STA.l !FP
	BRA fol
fol_2:
	LDA #$02
	STA.l !FP
fol:
	LDA #$00                ; (back on the world map, everyone starts following
	STA.l $7E0610           ; and the place label is the leader's)
	STA.l $7E0611
	STA.l $7E062A
	LDA #$01                ; the instructions we replaced
	LDX $6D
	STA $1A01,X
	TXA
	STA.l !FOBJ
	LDA.l !ESWAP            ; keep the party list honest: this object is party
	BNE +                   ; member FP, so it belongs in that entry
	LDA.l !FP
	ASL
	%tax8()
	LDA.l !FOBJ
	STA.l $000197,x
	SEP #$10
+	JSR fol_free            ; carry set: it walked freely this frame
	BCS fol_book
	LDA.l !FP               ; otherwise the original trail replay
	CMP #$02
	BEQ fol_two
	%c0call($C0A26B, fol_r1)
	RTL
fol_two:
	%c0call($C0A2CE, fol_r2)
	RTL
; walking freely: keep its place in the trail moving as the replay would
; (position 1 trails the leader's index, position 2 trails position 1's)
fol_book:
	LDA.l !FP
	CMP #$01
	BNE fol_book2
	LDA.l $0001AB
	SEC
	SBC.l $0001AC
	AND #$7F
	CMP #$10
	BCC fol_bookx
	LDA.l $0001AC
	INC
	AND #$7F
	STA.l $0001AC
	RTL
fol_book2:
	LDA.l $0001AC
	SEC
	SBC.l $0001AD
	AND #$7F
	CMP #$10
	BCC fol_bookx
	LDA.l $0001AD
	INC
	AND #$7F
	STA.l $0001AD
fol_bookx:
	RTL

; ---------------------------------------------------------------------
fol_free:
	PHP
	SEP #$20
	REP #$10
	LDA.l !FP
	DEC
	STA.l !FI
	LDA.l !ESWAP            ; a player's scene: everyone holds still
	BEQ ++
	LDA.l !FOBJ             ; the scene's own character is back in the
	CMP.l !EOBJ             ; game's own walking control: scene_quiet_l
	BNE +                   ; says whether the scene is over (far.asm)
	JSL scene_quiet_l
	BCC +
	JSR scene_back
	BRA ++
+	JSR fol_jumped          ; (the scene moving it is no new map: keep its
	PLP                     ; last position current)
	SEC
	RTS
++
	REP #$10
	JSR fol_jumped          ; new map / cutscene teleport: back to following
	BCC +
	JSR fol_reset
+	LDA.l !FP
	JSR owner               ; position 1 -> P2, 2 -> P3 (when joined)
	CMP.l !FP
	BEQ +
	JSR fol_reset           ; nobody's: an ordinary follower
	PLP
	CLC
	RTS
+	LDA.l !FP
	JSR seat_raw_mv         ; this player's controller (A 16-bit; Follow: Select)
	STA.l !FRAW
	JSL fpad_l              ; -> !FPAD, the game's layout (lo buttons, hi
	NOP                     ; d-pad); trail.asm keeps a copy for fol_late
	NOP
	NOP
	SEP #$20
	JSR fol_act             ; A: talk / open / pick up what's in front
	; Select held half a second: regroup
	LDA.l !FI
	%tax8()
	LDA.l !FRAW+1
	AND #$20
	BEQ .nosel
	LDA.l !FSEL,x
	CMP #$FF
	BEQ .seldone
	INC
	STA.l !FSEL,x
	CMP #30
	BNE .seldone
	JSR fol_regroup
	BRA .seldone
.nosel:
	LDA #$00
	STA.l !FSEL,x
.seldone:
	LDA.l !FI
	%tax8()
	LDA.l !FMODE,x
	BNE .free
	LDA.l !FSEL,x           ; following: the d-pad frees it (not while Select is held)
	BNE .follow
	LDA.l !FRAW+1
	AND #$0F
	BEQ .follow
	LDA #$01
	STA.l !FMODE,x
	LDA #$00
	STA.l !FOFF,x
	BRA .free
.follow:
	PLP
	CLC
	RTS
.free:
	JSR fol_screen          ; off screen 1.5 s: regroup
	BCC .onscreen
	LDA.l !FI
	%tax8()
	LDA.l !FOFF,x
	INC
	STA.l !FOFF,x
	CMP #90
	BCC .step
	JSR fol_regroup
	PLP
	CLC
	RTS
.onscreen:
	LDA.l !FI
	%tax8()
	LDA #$00
	STA.l !FOFF,x
.step:
	; the step itself runs later this frame, after the sprite-pose upload
	; (fol_late_l): run here, its cost pushed that upload past the game's
	; line limit and every few frames everyone lost a frame
	LDA #$01                ; (X = !FI on both paths here)
	STA.l !FPEND,x
	PLP
	SEC
	RTS

; (far: trail.asm fol_late_l) near routines it needs
fol_pad_l:                      ; !FP's player -> !FRAW, !FPAD
	LDA.l !FP
	JSR seat_raw_mv
	STA.l !FRAW
	JSR map_pad
	STA.l !FPAD
	RTL
fol_once_l:
	JSR fol_once
	RTL
+	LDA #$00
	STA.l !FPEND,x
	LDA.l !FMODE,x          ; (still walking freely)
	BNE +
	RTS
+	LDA.l !FP               ; its object, from the party list
	ASL
	%tax8()
	LDA.l $000197,x
	BPL +
	RTS
+	STA.l !FOBJ
	STA.l $00016D
	LDA #$00
	STA.l $00016E
	LDA.l !FP               ; its player's pad, as fol_free read it
	JSR seat_raw_mv
	STA.l !FRAW
	JSR map_pad
	STA.l !FPAD
	SEP #$20
	JSL catch_l             ; the game skipped this character last frame
	BCC +                   ; (trail.asm): one extra step, so it keeps pace
	JSR fol_once            ; with the leader - the missed frame's step,
	JSL fol_integ_l         ; applied as the game would (velocity -> place),
+	JSR fol_once            ; then this frame's, checked from there
	RTS

; one free step for this follower (the leader's movement code)
fol_once:
	REP #$30
	PHD
	SEP #$20                ; (a vblank NMI during the step must not rewrite
	LDA #$A5                ; the pads: $F8 holds this follower's - see pad_hold)
	STA.l !FSTEP
	REP #$20
	LDA.l $000197           ; the leader's state we borrow
	PHA
	LDA.l $000199           ; party object list (the collision code skips these)
	PHA
	LDA.l $00019B
	PHA
	LDA.l $0000F8
	PHA
	LDA.l $0001EB           ; object the leader touched (the collision sets it)
	PHA
	LDX #$000A
-	LDA.l $7E1D2A,x
	PHA
	DEX
	DEX
	BPL -
	LDX #$0022
-	LDA.l $7E1D50,x
	PHA
	DEX
	DEX
	BPL -
	; run the leader's movement code for the follower
	LDA #$0080              ; touching nothing yet
	STA.l $0001EB
	LDA.l !FPAD
	STA.l $0000F8
	SEP #$20
	LDA.l !FP               ; swap leader and follower in the party list
	ASL
	%tax8()                 ; 2 or 4: $0197+X = the follower's entry
	LDA.l $000197
	STA.l $000197,x
	LDA.l !FOBJ
	STA.l $000197
	REP #$20
	LDA #$1D00
	TCD
	SEP #$20
	STZ $2C
	STZ $2D
	STZ $2E
	STZ $30
	STZ $32
	STZ $33
	LDA.l $000162
	BNE +
	LDA.l $00011F
	BEQ +
	%c0call($C088EE, fol_r3)
+	LDA.l $000120
	BEQ +
	SEP #$10
	%c0call($C08A6D, fol_r4)
	REP #$10
+	%c0call($C09175, fol_r5)
	REP #$20
	LDA $32
	STA.l !FRES
	LDA $2C
	STA.l !FDIR
	; walking animation for the follower (the leader's 9E84 with D = $0100)
	SEP #$20
	STZ $34
	REP #$20
	LDA #$0100
	TCD
	SEP #$30
	%c0call($C09E84, fol_r6)
	SEP #$30
	LDA.l $0001EB           ; walked into an object (enemy, trap, event):
	BMI +                   ; run its touch function, as the leader's step does
	JSL pc_lock_l           ; (never a party member's touch function)
	%c0call($C03154, fol_r8)
	JSL pc_unlock_l
	SEP #$30
+	JSR fol_clamp           ; not past the screen edge
	LDA.l !FOBJ
	TAX                     ; (8-bit X: no hidden byte)
	LDA.l !FRES
	STA.l $7E1900,x
	LDA.l !FRES+1
	STA.l $7E1980,x
	; put the leader's state back
	REP #$30
	LDX #$0000
-	PLA
	STA.l $7E1D50,x
	INX
	INX
	CPX #$0024
	BNE -
	LDX #$0000
-	PLA
	STA.l $7E1D2A,x
	INX
	INX
	CPX #$000C
	BNE -
	PLA
	STA.l $0001EB
	PLA
	STA.l $0000F8
	PLA
	STA.l $00019B
	PLA
	STA.l $000199
	PLA
	STA.l $000197
	SEP #$20
	LDA #$00
	STA.l !FSTEP
	PLD
	RTS

; ---------------------------------------------------------------------
; back to following, timers cleared
fol_reset:
	PHP
	SEP #$20
	REP #$10
	LDA.l !FI
	%tax8()
	LDA #$00
	STA.l !FMODE,x
	STA.l !FOFF,x
	PLP
	RTS

; carry set when the follower moved more than 32 px since last frame
; (a new map or a cutscene put it somewhere); remembers the position
fol_jumped:
	PHP
	REP #$30
	LDA.l !FOBJ
	AND #$00FF
	TAY
	LDA.l !FI
	AND #$00FF
	ASL
	TAX
	LDA #$0000
	STA.l !FRES             ; (temp) 0 = no jump
	LDA $1800,y
	SEC
	SBC.l !FPX,x
	BPL +
	EOR #$FFFF
	INC
+	CMP #$0200
	BCC +
	STA.l !FRES
+	LDA $1880,y
	SEC
	SBC.l !FPY,x
	BPL +
	EOR #$FFFF
	INC
+	CMP #$0200
	BCC +
	STA.l !FRES
+	LDA $1800,y
	STA.l !FPX,x
	LDA $1880,y
	STA.l !FPY,x
	LDA.l !FRES
	BEQ +
	PLP
	SEC
	RTS
+	PLP
	CLC
	RTS

; carry set when the follower is off the screen
fol_screen:
	PHP
	REP #$30
	LDA.l !FOBJ
	AND #$00FF
	TAX
	LDA.l $7E0A00,x
	CMP #$0100
	BCS .off
	LDA.l $7E0A80,x
	CMP #$00F0
	BCS .off
	PLP
	CLC
	RTS
.off:
	PLP
	SEC
	RTS

; keep the step from crossing the screen edge (A/X/Y 8-bit on entry)
fol_clamp:
	PHP
	REP #$30
	LDA.l !FOBJ
	AND #$00FF
	TAX
	SEP #$20
	LDA.l !FRES             ; x step
	BEQ .y
	BMI .left
	REP #$20
	LDA.l $7E0A00,x
	SEC
	SBC.w #246
	BMI .y8
	BRA .stopx
.left:
	REP #$20
	LDA.l $7E0A00,x
	SEC
	SBC.w #10
	BPL .y8
.stopx:
	SEP #$20
	LDA #$00
	STA.l !FRES
.y8:
	SEP #$20
.y:
	LDA.l !FRES+1           ; y step
	BEQ .done
	BMI .up
	REP #$20
	LDA.l $7E0A80,x
	SEC
	SBC.w #220
	BMI .done8
	BRA .stopy
.up:
	REP #$20
	LDA.l $7E0A80,x
	SEC
	SBC.w #32
	BPL .done8
.stopy:
	SEP #$20
	LDA #$00
	STA.l !FRES+1
.done8:
	SEP #$20
.done:
	PLP
	RTS

; put the follower back on the trail: where the trail says it would be now
; (leader position minus the steps it hasn't replayed yet), following
fol_regroup:
	PHP
	SEP #$20
	REP #$10
	LDA.l !FP
	CMP #$01
	BNE +
	LDA.l $0001AC
	BRA ++
+	LDA.l $0001AD
++	STA.l !FK
	REP #$20
	LDA #$0000
	STA.l !FRES             ; (temp) sum of x steps
	STA.l !FDIR             ; (temp) sum of y steps
.sum:
	SEP #$20
	LDA.l !FK
	CMP.l $0001AB
	BEQ .place
	INC
	AND #$7F
	STA.l !FK
	%tax8()
	LDA.l $7F0C00,x
	REP #$20
	AND #$00FF
	CMP #$0080
	BCC +
	ORA #$FF00
+	CLC
	ADC.l !FRES
	STA.l !FRES
	SEP #$20
	LDA.l $7F0C80,x
	REP #$20
	AND #$00FF
	CMP #$0080
	BCC +
	ORA #$FF00
+	CLC
	ADC.l !FDIR
	STA.l !FDIR
	BRA .sum
.place:
	REP #$30
	LDA.l $000197
	AND #$00FF
	TAX                     ; leader
	LDA.l !FOBJ
	AND #$00FF
	TAY                     ; follower
	LDA $1800,x
	SEC
	SBC.l !FRES
	STA $1800,y
	STA.l !FRES
	LDA $1880,x
	SEC
	SBC.l !FDIR
	STA $1880,y
	SEP #$20
	LDA #$00
	STA $1900,y
	STA $1980,y
	JSR fol_jumped          ; (remember the new position)
	JSR fol_reset
	PLP
	RTS

; ---------------------------------------------------------------------
; a new A press: run the game's own "A" handler (C0:1AB4: the object being
; touched or in front -> its script; else a search of the tile in front)
; as if this follower were the leader
fol_act:
	PHP
	SEP #$20
	REP #$10
	LDA.l !FI
	%tax8()
	LDA.l !FPREV,x
	EOR #$FF
	AND.l !FPAD
	PHA
	LDA.l !FPAD
	STA.l !FPREV,x
	PLA
	AND #$80                ; confirm (A)
	BEQ +
	LDA.l !ESWAP            ; (a player's scene is running)
	BNE +
	LDA.l $7E063A           ; (a message window takes A through the joypad)
	BNE +
	LDA.l $000162           ; (a Yes/No choice takes A through the joypad)
	BEQ ++
+	PLP
	RTS
++	REP #$30
	PHD
	LDA.l $000197
	PHA
	LDA.l $000199
	PHA
	LDA.l $00019B
	PHA
	LDA.l $0001EB
	PHA
	SEP #$20
	LDA.l !FP               ; swap leader and follower in the party list
	ASL
	%tax8()
	LDA.l $000197
	STA.l $000197,x
	LDA.l !FOBJ
	STA.l $000197
	REP #$20
	LDA #$0080              ; touching nothing: look in front
	STA.l $0001EB
	LDA #$0100
	TCD
	SEP #$20
	REP #$10
	%c0call($C01AB4, fol_r7)  ; (party members CAN be talked to: campfires)
	JSL eb_fix_l            ; (talking to a party member: no scene swap)
	REP #$30
	; Nov 16: "pretend player 1 triggered it".  The follower only picks WHAT
	; is in front of it; the event itself always runs with the real leader as
	; party member 0, exactly like the unmodded game.  (Swapping the follower
	; in broke scripted scenes: the 600 AD Cathedral organ walked Lucca off
	; the top of the screen and left her frozen with no run animation.)
	BRA fol_act_undo
	; (the old leader-swap path that followed here was removed Nov 16: dead
	; since the BRA above; see field_pre_late.asm.bak)
fol_act_undo:
	PLA
	STA.l $0001EB
	PLA
	STA.l $00019B
	PLA
	STA.l $000199
	PLA
	STA.l $000197
	PLD
	PLP
	RTS

; ---------------------------------------------------------------------
field_tick:
	PHP
	SEP #$20
	PHA
	LDA #$08                ; (gameplay is running: see pad_merge)
	STA.l !GAMEON
	LDA #$00                ; (the X menu is closed)
	STA.l !MENUON
	STA.l !FSTEP            ; (no follower step yet this frame)
	PLA
	PLP
	JSL ctl_field_l         ; (RetroArch ports 4/5)
if !CTPLUS
	JSR ctp_appear          ; (a save from the original game: CT+'s looks)
endif
	PHP
	SEP #$20
	PHA
	LDA.l !ESWAP            ; (no player scene: the world-map mark is stale -
	BNE +                   ; it would drop the next scene started here)
	STA.l !OWALIVE
+	JSL eb_fix_l            ; never "touching" a party member
	PLA
	PLP
	; (early_drain removed: on busy maps it made the game lag; drain_fix's
	; "stuck 3 frames" fallback alone keeps sprite frames from freezing)
	JML $C01F87             ; (its RTL returns to the main loop)

lead_walk:
	JSL lead_tick_l         ; (count the leader's updates: catch_l)
	LDA #$00                ; (gameplay: not on the file screen)
	STA.l !FSFLAG
	LDA #$01                ; the instructions we replaced
	LDX $6D
	STA $1A01,X
	; this object is the real leader (party position 0).  Keep the party list
	; honest: outside a player's scene it must be first in $0197
	LDA.l !ESWAP
	BEQ lead_fix
	LDA.l $000197           ; a scene is on, but the list was rebuilt (new
	CMP.l !EOBJ             ; map): that scene is gone
	BEQ lead_hold
	LDA #$00
	STA.l !ESWAP
lead_fix:
	TXA
	CMP.l $000197
	BEQ lead_ok
	CMP.l $000199
	BNE +
	LDA.l $000197
	STA.l $000199
	BRA ++
+	CMP.l $00019B
	BNE ++
	LDA.l $000197
	STA.l $00019B
++	TXA                     ; (not in the list at all: put it in)
	STA.l $000197
lead_ok:
	%c0call($C09E29, fol_r9)
	RTL
lead_hold:
	LDA #$00                ; (another player's scene: no step)
	STA $1900,X
	STA $1980,X
	RTL

; X (8-bit) = object -> carry set if it's one of the party
party_skip:
	TXA
	CMP.l $000197
	BEQ .yes
	CMP.l $000199
	BEQ .yes
	CMP.l $00019B
	BEQ .yes
	LDA.l !ESWAP
	BEQ .no
	LDA.l $7E1100,x
	CMP #$03
	BCC .yes
.no:
	CLC
	RTL
.yes:
	SEC
	RTL

; ---------------------------------------------------------------------
; pad_merge (the joypad routine, inside the NMI): on the field the players'
; bookkeeping (update_joined: ~6 of the NMI's lines) runs after the frame's
; sprite-pose upload instead (fol_late_l -> uj_late_l) - in the NMI it delayed
; the whole frame and pushed that upload past the game's line limit.  Only
; track_opener stays here: the X menu opens this frame, on the right person.
; World map, menus, title, battle: as before.
uj_pick:
	PHP
	SEP #$20
	LDA.l $000501           ; the NMI vector: JML $C0EA63 = the field
	CMP #$63
	BNE .all
	LDA.l $000502
	CMP #$EA
	BNE .all
	LDA.l $000503
	CMP #$C0
	BNE .all
	LDA #$01
	STA.l !UJDUE
	REP #$20                ; (stays here: a message window open as the
	LDA.l $000134           ; frame starts - its A closes it, fol_act must
	SEP #$20                ; not also act; late, a held A closed it at once)
	BEQ +
	LDA #$01
+	STA.l $7E063A           ; !BOXW
	PLP
	JSR script_pads         ; (what the event scripts read this frame)
	JMP nmi_players
.all:
	PLP
	JMP update_joined
uj_late_l:
	PHP
	SEP #$20
	LDA #$02                ; (2 = running late: sp_maybe skips script_pads)
	STA.l !UJDUE
	PLP
	JSR update_joined
	PHP
	SEP #$20
	LDA #$00
	STA.l !UJDUE
	PLP
	RTL
sp_maybe:
	PHP
	SEP #$20
	LDA.l !UJDUE
	CMP #$02
	BEQ +
	PLP
	JMP script_pads
+	PLP
	RTS


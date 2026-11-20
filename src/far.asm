; =====================================================================
; Bank !DB2 (DC / CT+ $51) from $F000: the bigger player routines, moved
; out of the full code bank.  Called with JSL through the *_l entries;
; inside, they call each other with JSR.
; =====================================================================
org !DB2|$F000
claims_init_l:
	JSR claims_init
	RTL
pad_press_l:
	JSR pad_press
	RTL
claims_update_l:
	JSR claims_update
	RTL
claims_maybe_l:
	JSR claims_maybe
	RTL

; rebuild the seats only when something changed: a join / wake / claim /
; mode change (!CDIRTY) or a new party order
claims_maybe:
	PHP
	SEP #$20
	LDA.l !CDIRTY
	BNE .go
	LDA.l $7E2980
	CMP.l !LPA0
	BNE .go
	LDA.l $7E2981
	CMP.l !LPA1
	BNE .go
	LDA.l $7E2982
	CMP.l !LPA2
	BNE .go
	PLP
	RTS
.go:
	LDA #$00
	STA.l !CDIRTY
	LDA.l $7E2980
	STA.l !LPA0
	LDA.l $7E2981
	STA.l !LPA1
	LDA.l $7E2982
	STA.l !LPA2
	JSR claims_update
	PLP
	RTS
menu_modes_l:
	JSR menu_modes
	RTL
claim_at_l:
	JSR claim_at
	RTL

; A(8) = pad 0-2 -> A(16) raw (a copy of pad_raw for this bank)
pad_raw_f:
	PHA
-	LDA.l $004212
	AND #$01
	BNE -
	PLA
	JSL praw_l              ; the port this pad reads (ctlports.asm)
	RTS

; C2:99DE "STZ $0411 / STZ $0412": the main menu opens
menu_init:
	STZ $0411
	STZ $0412
	PHP
	SEP #$20
	LDA #$01
	STA.l !MENUON
	LDA #$00
	STA.l !TAGF
	STA.l !TAGF+1
	STA.l !TAGF+2
	LDA #$FF                ; (buttons already down don't count)
	STA.l !PREVB
	STA.l !PREVB+1
	STA.l !PREVB+2
	PLP
	RTL

; once a frame (update_joined): Select / Y in the menu, and the tags
menu_modes:
	PHP
	SEP #$20
	REP #$10
	LDA.l !MENUON
	BEQ .out
	LDA.l $7E0411           ; the main page only
	BNE .out
	LDX.w #$0000
.pad:
	TXA
	JSR pad_raw_f           ; A(16) raw
	SEP #$20
	XBA                     ; B Y Select Start U D L R
	STA.l !PSEAT
	LDA.l !PREVB,x
	EOR #$FF
	AND.l !PSEAT
	PHA
	LDA.l !PSEAT
	STA.l !PREVB,x
	PLA
	STA.l !PSEAT            ; new presses
	AND #$40                ; Y: Ready / Follow / Idle
	BEQ +
	JSR cycle_pad
+	LDA.l !PSEAT
	AND #$20                ; Select: claim (Nov 17: was Y)
	BEQ +
	JSR claim_pad
+	INX
	CPX.w #$0003
	BNE .pad
	JSL ctl_menu_l          ; (Select from a port no pad reads: ctlports.asm)
	JSR claims_maybe
	JSR draw_tags
.out:
	PLP
	RTS

; Select (any pad): the player in the highlighted slot ($0412) goes
; Ready -> Follow -> Idle -> Ready (not the leader's pad).  X kept.
cycle_pad:
	PHX
	JSR cycle_slot
	PLX
	RTS
cycle_slot:
	LDA.l $7E0412
	CMP #$03
	BCS cycle_none
	%tax8()
	LDA.l $7E2980,x         ; an empty slot: nobody
	BMI cycle_none
	LDA.l !ROLE,x           ; that slot's controller
	%tax8()
	TXA
	CMP.l !ROLE
	BEQ .done
	LDA.l !PST,x
	CMP #$02
	BEQ .ready
	LDA.l bitmask,x
	AND.l !PJOIN
	BEQ .done               ; not playing
	LDA.l !PST,x
	BNE .idle
	LDA #$01                ; Follow
	STA.l !PST,x
	STA.l !CDIRTY
	RTS
.idle:
	LDA #$02
	STA.l !PST,x
	LDA.l bitmask,x
	EOR #$FF
	AND.l !PJOIN
	STA.l !PJOIN
	LDA #$01
	STA.l !CDIRTY
	RTS
.ready:
	LDA #$00
	STA.l !PST,x
	LDA.l bitmask,x
	ORA.l !PJOIN
	STA.l !PJOIN
	LDA #$01
	STA.l !CDIRTY
.done:
	RTS
cycle_none:
	RTS

; X = pad: claim the character the menu shows ($0412 = its slot); a pad
; that had them takes this pad's old character
claim_pad:
	LDA.l $7E0412
	STA.l !XSL
claim_at:                       ; (X = pad, !XSL = slot)
	LDA.l bitmask,x         ; Y joins this player on the spot (a first,
	AND.l !PJOIN            ; quick press, or back from Idle): the claim
	BNE +                   ; must work on the first press
	LDA #$00
	STA.l !PST,x
	LDA.l bitmask,x
	ORA.l !PJOIN
	STA.l !PJOIN
	LDA #$01
	STA.l !CDIRTY
+	PHX
	LDA.l !XSL
	CMP #$03
	BCS .no
	%tax8()
	LDA.l $7E2980,x
	BMI .no
	STA.l !RCC
	PLX
	LDA.l !PCHAR,x
	CMP.l !RCC
	BEQ .done
	STA.l !RCP               ; this pad's old character
	PHX
	LDX.w #$0000
-	LDA.l !PCHAR,x
	CMP.l !RCC
	BNE +
	LDA.l !RCP
	STA.l !PCHAR,x
+	INX
	CPX.w #$0003
	BNE -
	PLX
	LDA.l !RCC
	STA.l !PCHAR,x
	PHX
	JSR claims_update
.no:
	PLX
.done:
	RTS

; the menu's left panels: 7E:2EC6 + slot*$180 = the name, +12 = "LV n" (6
; tiles, 2 bytes each).  A tag replaces it; the tiles are kept and put back.
draw_tags:
	LDX.w #$0000
.slot:
	TXA
	STA.l !TSL
	LDA.l $7E2980,x         ; nobody in that slot
	BPL +
	JMP .next
+	STA.l !TQ               ; is the panel really showing this character
	ASL                     ; here?  (the equipment / status pages redraw
	CLC                     ; the left side differently): the first letter
	ADC.l !TQ               ; of its name (7E:2C23 + character*6)
	ASL
	%tax8()
	LDA.l $7E2C23,x
	STA.l !PSEAT
	LDA #$00
	STA.l !TI
	JSR tag_mx
	LDA.l $7E2EC6,x
	CMP.l !PSEAT
	BEQ .shown
	LDA.l !TSL              ; not now: leave it, and forget the kept "LV n"
	%tax8()                 ; (taken again once the panel is back)
	LDA #$00
	STA.l !TAGF,x
	JMP .next
.shown:
	LDA.l !TSL
	%tax8()
	LDA.l !ROLE,x
	PHA
	JSL lport_l             ; "Pn" = the RetroArch port it reads
	STA.l !TDIG
	PLA
	%tax8()
	LDA.l bitmask,x
	AND.l !PJOIN
	BNE .playing
	LDA.l !PST,x            ; an Idle player's character
	CMP #$02
	BEQ .tag
	BRA .to_ready
.playing:
	LDA.l !PST,x
	BNE .tag                ; Follow
	LDA.l !PJOIN            ; more than one playing: the controller number
	CMP #$01
	BEQ .to_ready
	CMP #$02
	BEQ .to_ready
	CMP #$04
	BEQ .to_ready
	LDA #$04
	BRA .tag
.to_ready:
	JMP .ready
.tag:                           ; (!TAGF = the tag kind drawn, 0 none)
	PHA
	LDA.l !TSL
	%tax8()
	LDA.l !TAGF,x
	BEQ .first
	CMP 1,s
	BNE .write              ; another tag: draw it
	LDA #$00                ; the same tag: still on screen?  (the game may
	STA.l !TI               ; have redrawn the panel)
	JSR tag_mx
	LDA #$AF                ; P
	CMP.l $7E2EC6+12,x
	BNE .gone
	LDA.l !TDIG             ; still the right number?
	CLC
	ADC #$D5
	CMP.l $7E2EC6+14,x
	BNE .write
	LDA 1,s                 ; FOL / IDL: still the right word?
	CMP #$04
	BEQ .keep
	CMP #$01
	BNE +
	LDA #$A5                ; F
	BRA ++
+	LDA #$A8                ; I
++	CMP.l $7E2EC6+18,x
	BNE .write
.keep:
	PLA
	JMP .next
.gone:
	LDA.l !TSL              ; redrawn: take "LV n" again next time
	%tax8()
	LDA #$00
	STA.l !TAGF,x
	PLA
	JMP .next
.first:                         ; keep "LV n" first (once the menu has drawn it)
	LDA #$00
	STA.l !TI
	JSR tag_mx
	LDA.l $7E2EC6+12,x
	CMP #$AB                ; L
	BEQ +
	PLA
	JMP .next
+	LDA #$00
	JSR tag_copy            ; 0: buffer -> backup
.write:
	LDA.l !TSL
	%tax8()
	LDA 1,s
	STA.l !TAGF,x
	PLA
	JSR tag_copy            ; 1 Follow / 2 Idle / 4 "Pn"
	JMP .next
.ready:
	LDA.l !TSL
	%tax8()
	LDA.l !TAGF,x
	BEQ .next
	LDA #$00
	STA.l !TAGF,x
	LDA #$03
	JSR tag_copy            ; 3: backup -> buffer
.next:
	LDA.l !TSL
	%tax8()
	INX
	CPX.w #$0003
	BEQ +
	JMP .slot
+	RTS

; A = 0 keep, 1 FOLLOW, 2 IDLE, 3 restore, 4 "P" + controller (!TDIG) and
; the kept level; slot in !TSL.  6 tiles.
tag_copy:
	STA.l !TST
	LDA #$00
	STA.l !TI
.t:
	LDA.l !TST
	BEQ .frombuf
	CMP #$03
	BEQ .frombak
	LDA.l !TI               ; every tag starts "Pn" (the controller)
	BEQ .pp
	CMP #$01
	BEQ .dig
	LDA.l !TST              ; then: the kept level (Ready) or FOL / IDL
	CMP #$04
	BEQ .frombak
	BRA .str
.dig:
	LDA.l !TDIG
	CLC
	ADC #$D5                ; '1' + controller
	BRA .put
.pp:
	LDA #$AF                ; P
	BRA .put
.str:
	JSR tag_ix              ; X = tile index
	LDA.l !TST
	CMP #$01
	BNE +
	LDA.l tag_follow,x
	BRA .put
+	LDA.l tag_idle,x
	BRA .put
.frombak:
	JSR tag_bx
	LDA.l !TAGB,x
	BRA .put
.frombuf:
	JSR tag_mx
	LDA.l $7E2EC6+12,x
	PHA
	JSR tag_bx
	PLA
	STA.l !TAGB,x
	BRA .adv
.put:
	PHA
	JSR tag_mx
	PLA
	STA.l $7E2EC6+12,x
.adv:
	LDA.l !TI
	INC
	STA.l !TI
	CMP #$06
	BNE .t
	RTS
tag_ix:                         ; X = i - 2 (the FOL / IDL strings)
	LDA.l !TI
	DEC
	DEC
	%tax8()
	RTS
tag_bx:                         ; X = slot*6 + i
	LDA.l !TSL
	ASL
	STA.l !TQ
	ASL
	CLC
	ADC.l !TQ
	CLC
	ADC.l !TI
	%tax8()
	RTS
tag_mx:                         ; X = slot*$180 + i*2 (panels are 6 rows apart)
	REP #$20
	LDA.l !TSL
	AND.w #$00FF
	XBA
	STA.l !TQ
	LSR
	CLC
	ADC.l !TQ
	STA.l !TQ
	LDA.l !TI
	AND.w #$00FF
	ASL
	CLC
	ADC.l !TQ
	TAX
	SEP #$20
	RTS
tag_follow: db $A5,$AE,$AB,$FF         ; "FOL" (ends at the level column; was " FOL", the L spilled past the panel border)
tag_idle:   db $A8,$A3,$AB,$FF         ; "IDL"
claims_init:
	SEP #$20
	LDA.l !RINIT
	CMP #$A5
	BEQ .ok
	LDA #$00
	STA.l !ROLE
	STA.l !PST
	STA.l !PST+1
	STA.l !PST+2
	LDA #$01
	STA.l !ROLE+1
	LDA #$02
	STA.l !ROLE+2
	LDA.l !JOINED           ; (seats = pads until now)
	AND #$06
	ORA #$01
	STA.l !PJOIN
	LDA #$FF
	STA.l !PCHAR
	STA.l !PCHAR+1
	STA.l !PCHAR+2
	LDA #$A5
	STA.l !RINIT
	STA.l !CDIRTY
.ok:
	RTS

; X = pad with a press this frame (raw in !PRAW)
pad_press:
	LDA.l bitmask,x
	AND.l !PJOIN
	BEQ .out
	LDA.l !PRAW+1           ; playing: Start = back to Ready (from Follow)
	AND #$10
	BEQ .r
	LDA.l !PST,x
	BEQ .r
	LDA #$00
	STA.l !PST,x
	LDA #$01
	STA.l !CDIRTY
.r:
	RTS
.out:
	LDA.l !PST,x
	CMP #$02
	BNE .fresh
	LDA.l !PRAW+1           ; Idle: only Start counts - back to Ready
	AND #$10
	BEQ .r
	LDA #$00
	STA.l !PST,x
	BRA .join
.fresh:
	LDA.l !JCNT,x           ; a join needs a real press, held 3 frames
	CMP #$03
	BCS +
	RTS
+	CPX #$0000
	BEQ .join
	; a multitap pad joining while the other one is joined but silent for
	; 4 s: it takes that player's place (RetroArch gives a reconnected
	; controller the free number)
	TXA
	EOR #$03
	PHX
	%tax8()                 ; X = the other pad
	LDA.l bitmask,x
	AND.l !PJOIN
	BEQ .nq
	LDA.l !PSIL-1,x
	CMP #240
	BCC .nq
	LDA.l !PRAW+1           ; taking a silent player's place needs START
	AND #$10                ; (a stray input must never steal a character)
	BEQ .nq
	LDA.l bitmask,x
	EOR #$FF
	AND.l !PJOIN
	STA.l !PJOIN
	LDA.l !PCHAR,x
	PHA
	LDA #$FF
	STA.l !PCHAR,x
	PLA
	PLX
	STA.l !PCHAR,x
	BRA .on
.nq:
	PLX
.join:
	LDA.l !PCHAR,x          ; (back from Idle: its claim stands)
	CMP #$FF
	BNE .on
	PHX                     ; a new player: the character in its seat
	LDA #$00
	STA.l !RCS
-	LDA.l !RCS
	%tax8()
	LDA.l !ROLE,x
	CMP 1,s
	BEQ +
	LDA.l !RCS
	INC
	STA.l !RCS
	CMP #$03
	BNE -
	PLX
	BRA .on
+	LDA.l $7E2980,x
	BPL +
	LDA #$FF                ; an empty party slot: no character to claim
+	PLX
	STA.l !PCHAR,x
.on:
	LDA.l bitmask,x
	ORA.l !PJOIN
	STA.l !PJOIN
	LDA #$01
	STA.l !CDIRTY
	RTS

; rebuild !ROLE from the claims, then !JOINED
claims_update:
	PHP
	SEP #$20
	REP #$10
	PHX
	LDA #$FF
	STA.l !RNR
	STA.l !RNR+1
	STA.l !RNR+2
	LDA #$00
	STA.l !RUSE
	STA.l !RCS
.seat:                          ; each seat: the joined pad claiming its character
	LDA.l !RCS
	%tax8()
	LDA.l $7E2980,x
	BMI .snext
	STA.l !RCC
	LDA #$00
	STA.l !RCP
.p:
	LDA.l !RCP
	%tax8()
	LDA.l bitmask,x
	AND.l !PJOIN
	BEQ .pn
	LDA.l bitmask,x
	AND.l !RUSE
	BNE .pn
	LDA.l !PCHAR,x
	CMP.l !RCC
	BNE .pn
	LDA.l bitmask,x
	ORA.l !RUSE
	STA.l !RUSE
	LDA.l !RCS
	%tax8()
	LDA.l !RCP
	STA.l !RNR,x
	BRA .snext
.pn:
	LDA.l !RCP
	INC
	STA.l !RCP
	CMP #$03
	BNE .p
.snext:
	LDA.l !RCS
	INC
	STA.l !RCS
	CMP #$03
	BEQ +
	JMP .seat
+	; nobody claims the leader: his pad stays (if it's free)
	LDA.l !RNR
	CMP #$FF
	BNE .fill
	LDA.l !ROLE
	CMP #$03
	BCS .fill
	%tax8()
	LDA.l bitmask,x
	AND.l !RUSE
	BNE .fill
	LDA.l bitmask,x
	ORA.l !RUSE
	STA.l !RUSE
	TXA
	STA.l !RNR
.fill:                          ; a free seat keeps the pad it had (so a claim
	LDX.w #$0000            ; changes only its own slot)...
.k:
	LDA.l !RNR,x
	CMP #$FF
	BNE .kn
	LDA.l !ROLE,x
	CMP #$03
	BCS .kn
	PHX
	%tax8()
	LDA.l bitmask,x
	AND.l !RUSE
	BNE .kx
	LDA.l bitmask,x
	ORA.l !RUSE
	STA.l !RUSE
	TXA
	PLX
	STA.l !RNR,x
	BRA .kn
.kx:
	PLX
.kn:
	INX
	CPX.w #$0003
	BNE .k
	LDX.w #$0000            ; ...then the rest: free pads in order
.f:
	LDA.l !RNR,x
	CMP #$FF
	BNE .fn
	PHX
	LDX.w #$0000
-	LDA.l bitmask,x
	AND.l !RUSE
	BEQ +
	INX
	BRA -
+	LDA.l bitmask,x
	ORA.l !RUSE
	STA.l !RUSE
	TXA
	PLX
	STA.l !RNR,x
.fn:
	INX
	CPX.w #$0003
	BNE .f
	LDA.l !RNR
	STA.l !ROLE
	LDA.l !RNR+1
	STA.l !ROLE+1
	LDA.l !RNR+2
	STA.l !ROLE+2
	; the leader's pad is always playing (and never on Follow / Idle)
	LDA.l !ROLE
	%tax8()
	LDA #$00
	STA.l !PST,x
	LDA.l bitmask,x
	ORA.l !PJOIN
	STA.l !PJOIN
	; claims follow the seats (empty slots leave a claim alone: that
	; character comes back to the same player)
	LDX.w #$0000
.c:
	LDA.l $7E2980,x
	BMI .cn
	STA.l !RCC
	LDA.l !ROLE,x
	PHX
	%tax8()
	LDA.l bitmask,x
	AND.l !PJOIN
	BEQ +
	LDA.l !RCC
	STA.l !PCHAR,x
+	PLX
.cn:
	INX
	CPX.w #$0003
	BNE .c
	; !JOINED: seats 1 and 2 whose pad is playing
	LDA #$00
	STA.l !RCC
	LDX.w #$0001
-	LDA.l !ROLE,x
	PHX
	%tax8()
	LDA.l bitmask,x
	PLX
	AND.l !PJOIN
	BEQ +
	LDA.l !RCC
	ORA.l bitmask,x
	STA.l !RCC
+	INX
	CPX.w #$0003
	BNE -
	LDA.l !RCC
	STA.l !JOINED
	PLX
	PLP
	RTS

; the title screen reads the pad on its own: C3:0A99 "LDA $4218 / STA $02"
; (A 16-bit) - every controller drives it
title_pad:
	LDA.l $004218
	ORA.l $00421A
	ORA.l $00421E
	STA $02
	RTL

macro idlectr(vote, ctr)
	LDA.l <vote>            ; (A 8-bit) this character's vote: FFFF = none
	BMI ?none
	LDA.l <ctr>
	INC
	STA.l <ctr>
	RTL
?none:
	LDA #$00
	STA.l <ctr>
	RTL
endmacro
idle_lead:
	LDA.l !VOTE+1           ; the leader: while his vote stands, or after A
	BPL .count              ; pressed anywhere else (until he walks)
	LDA.l !LIDLE
	CMP #$01
	BEQ .count
	LDA #$00
	STA.l $0002B1
	RTL
.count:
	LDA.l $0002B1
	INC
	STA.l $0002B1
	RTL
idle_f1:
	%idlectr(!VOTE+3, $0002B2)
idle_f2:
	%idlectr(!VOTE+5, $0002B3)

; ---------------------------------------------------------------------
; SPRITE FRAMES NEVER STARVE.  After the objects run, the field loads the
; sprite frames waiting in its queue (C0:CA76) - but only while the screen
; is above line $016B or in vblank; past that it gives up until next frame.
; Two free walkers cost enough time that, on a busy map, the loop is past
; that line every frame: the queue never drains and walk / run animations
; freeze (any character).  So: if the queue has waited 3 frames, wait for
; the drain's own window (as the game does when it runs long), then drain.
drain_fix:
	PHP
	SEP #$20
	LDA.l $000176           ; the queue head ($80+ = empty)
	BMI .clear
	LDA.l !DSTV
	INC A
	STA.l !DSTV
	CMP #$03
	BCC .go
.spin:
	LDA.l $00213F           ; (reset the latch order)
	LDA.l $002137           ; latch the counters
	LDA.l $00213D
	XBA
	LDA.l $00213D
	AND #$01
	XBA
	REP #$20
	CMP.w #$00F0
	BCS .open               ; vblank
	CMP.l $00016B
	BCC .open               ; above the line
	SEP #$20
	BRA .spin
.open:
	SEP #$20
.clear:
	LDA #$00
	STA.l !DSTV
.go:
	PLP
	JSL $C0FF07             ; JSR $CA76 / REP #$10 / RTL in bank C0
	JML fol_late_l          ; then the free followers' steps (field.asm)

; Early in the frame (field_tick, before the objects run): if frames are
; still queued from last frame, drain them now - the screen is near its top,
; so the drain's window is open and no frame is lost.
early_drain:
	PHP
	SEP #$20
	LDA.l $000176
	BMI .none
	LDA.l !DSTV             ; only when the queue is STUCK (waited 2+ frames:
	CMP #$02                ; two free walkers on a busy map) - a busy room
	BCC .none               ; drains fine and an extra drain made it lag
	REP #$30
	PHA
	PHX
	PHY
	LDA.l $00016D           ; (the drain borrows the object index)
	PHA
	SEP #$20
	JSL $C0FF07
	REP #$30
	PLA
	STA.l $00016D
	PLY
	PLX
	PLA
.none:
	PLP
	RTL

; A(16) = raw pad word, X = pad -> A(16) (0 if it can't be a person
; pressing buttons), flags from A.  Counts held frames in !JCNT.
pad_sane_l:
	PHA
	SEP #$20                ; (repair: an old build could claim an empty
	LDA.l !PCHAR,x          ; party slot, $80)
	BPL +
	CMP #$FF
	BEQ +
	LDA #$FF
	STA.l !PCHAR,x
	STA.l !CDIRTY
+	REP #$20
	PLA
	AND.w #$FFF0            ; (the low bits are a device signature)
	CMP.w #$FFF0            ; all lines high: nothing there
	BEQ .bad
	PHA
	AND.w #$0C00            ; up+down together: noise
	CMP.w #$0C00
	BEQ .bad2
	LDA 1,s
	AND.w #$0300            ; left+right together: noise
	CMP.w #$0300
	BEQ .bad2
	PLA
	BEQ .bad
	PHA
	SEP #$20
	LDA.l !JCNT,x
	CMP #$FF
	BEQ +
	INC
	STA.l !JCNT,x
+	REP #$20
	PLA                     ; (flags: not zero)
	RTL
.bad2:
	PLA
.bad:
	SEP #$20
	LDA #$00
	STA.l !JCNT,x
	REP #$20
	LDA.w #$0000
	RTL
; ---------------------------------------------------------------------
; PARTY MEMBERS ARE NOT NPCs.  The game only ever lets the leader talk to /
; touch objects, and its party is never in front of him.  A free player can
; face another party member: the game would start that character's
; "talked to" script and freeze it (both of them, once the leftover touch
; mark reached the leader).  Around our calls, the party's objects get
; $1000 bit 7 ("can't interact"; the activate C0:5AC5 and touch C0:3154
; skip those), then it is put back.
pc_lock_l:
	PHP
	REP #$30
	PHA
	PHX
	PHY
	SEP #$30
	LDY #$00
.l:	TYX
	LDA #$FF
	STA.l !PCO,x            ; none
	TYA
	ASL
	TAX
	LDA.l $000197,x
	BMI .n
	PHA
	TYX
	STA.l !PCO,x
	PLX
	LDA.l $7E1000,x
	PHA
	ORA #$80
	STA.l $7E1000,x
	PLA
	TYX
	STA.l !PCL,x
.n:	INY
	CPY #$03
	BNE .l
	REP #$30
	PLY
	PLX
	PLA
	PLP
	RTL

pc_unlock_l:
	PHP
	REP #$30
	PHA
	PHX
	PHY
	SEP #$30
	LDY #$00
.l:	TYX
	LDA.l !PCO,x
	BMI .n
	PHA
	LDA.l !PCL,x
	PLX
	STA.l $7E1000,x
.n:	INY
	CPY #$03
	BNE .l
	REP #$30
	PLY
	PLX
	PLA
	PLP
	RTL

; once a frame: a "touched object" mark that names a party member is
; dropped (and repairs a frozen party member from an older build)
eb_fix_l:
	PHP
	REP #$10
	PHX
	SEP #$30
	LDA.l $0001EB
	BMI .ok
	TAX
	LDA.l $7E1100,x
	CMP #$03
	BCS .ok
	LDA #$80
	STA.l $0001EB
.ok:
	REP #$10
	PLX
	PLP
	RTL
; carry set if the field's NMI (C0:EA63) or the world map's (C2:015E) is the
; one installed at $0500: that game mode runs, even in the frames after the X
; menu closes before its tick has re-armed !GAMEON (else P2's d-pad, held as
; the menu closes, would walk P1).  A kept.
game_nmi_l:
	PHP
	REP #$20
	PHA
	LDA.l $000502           ; bank + high byte
	CMP.w #$C0EA
	BNE +
	LDA.l $000501
	AND #$00FF
	CMP.w #$0063
	BEQ .yes
	BRA .no
+	CMP.w #$C201
	BNE .no
	LDA.l $000501
	AND #$00FF
	CMP.w #$005E
	BEQ .yes
.no:
	PLA
	PLP
	CLC
	RTL
.yes:
	PLA
	PLP
	SEC
	RTL
; C0:EC15 (field NMI, both the normal and the lag-frame path): the game's
; register writes C0:EC19-EC57, in the same order, THEN the joypad routine,
; then on to the NMI's exit at C0:EC58 (which pulls everything it saved).
nmi_tail:
	SEP #$20
	PLA                     ; drop our return (to C0:EC19)
	PLA
	PLA
	LDA.l $000BD9
	STA.l $002123
	LDA.l $000BDA
	STA.l $002124
	LDA.l $000BDB
	STA.l $002125
	LDA.l $000BDC
	STA.l $002128
	LDA.l $000BDD
	STA.l $002129
	LDA.l $000BDE
	STA.l $002130
	LDA #$E0
	STA.l $002132
	LDA.l $000121
	STA.l $002132
	LDA.l $000128
	STA.l $00420C
	LDA.l $000119
	BNE +
	LDA #$80
+	STA.l $002100
	JSL $C28002             ; the joypad routine (and our player code)
	JML $C0EC58
; C2:031B (world-map NMI): C2:031F "LDA $1C / ORA $1D / STA $2100 / LDA $4A
; / STA $420C" first (same direct page as the game), then the joypad routine,
; then on at C2:032B.
wm_tail:
	SEP #$20
	PLA                     ; drop our return (to C2:031F)
	PLA
	PLA
	LDA $1C
	ORA $1D
	STA.l $002100
	LDA $4A
	STA.l $00420C
	JSL $C28002
	JML $C2032B
; a player's scene: its character's party-walk op ran this frame (so the
; game, not a script, controls it).  Carry set = the scene is over:
;   * no text window ($0136 = a window is up, $0134 = waiting for a button)
;   * and its window came and went (an item / tab / chest message), or 1 s
;     with no window at all (a scene that never talks)
scene_quiet_l:
	PHP
	SEP #$20
	LDA #$01
	STA.l !EWLK             ; (scene_end: the character was free this frame)
	LDA.l $000136
	BNE .loud
	LDA.l $000134
	ORA.l $000135
	BNE .loud
	LDA.l !EQ
	CMP #$FF
	BEQ +
	INC
	STA.l !EQ
+	CMP #60                 ; a second of the game's own control: over
	BCS .over
	CMP #30                 ; (half a second: a window opening or turning a
	BCC .no                 ; page flickers its flags off for ~10 frames)
	LDA.l !ESEEN            ; its message came and went: over
	BNE .over
.no:
	PLP
	CLC
	RTL
.loud:
	LDA #$00
	STA.l !EQ
	BRA .no
.over:
	PLP
	SEC
	RTL

; A = the player's target index (FF = none): give it to the game's target
; picker ($9614) only if the game lists a target there ($99C0 + index,
; negative = empty); else the picker keeps its own default.  (An index the
; game doesn't have makes it cancel the pick.)  X kept.

incsrc "combopanel.asm"

warnpc !DB2|$FFFF

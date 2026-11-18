; =====================================================================
; Battle menu, milestone 3: PRIVATE MENUS
;   Every player drives their own character's box: Att/Tech/Item, and the
;   Tech/Item list opens INSIDE that box (3 rows x 5 letters, scrolling).
;   Confirming COMMITS the choice (grey hand).  A replay engine then feeds
;   committed choices into the game's one real menu, one at a time, as soon
;   as it is free: switch focus -> pick the command -> pick the list entry.
;   Only target picking is still the game's shared step (milestone 4 makes
;   brackets private).  Solo play (nobody joined) runs the original menu.
; =====================================================================

!MODE   = $7E02B4      ; 3 bytes per slot: 0 boxes, 1 tech list, 2 item list, 3 committed
!LPOS   = $7E02B7      ; 3: list cursor
!LTOP   = $7E02BA      ; 3: list scroll
!CHOICE = $7E02BD      ; 3: chosen list index
!SEL    = $7E02D2      ; 3 per PLAYER: the slot that player is driving (FF none)
!PROW   = $7E02E8      ; 3 per slot: the player's command row (0 Att, 1 Tech, 2 Item)
!RSLOT  = $7E02F1      ; replay: slot+1 being fed to the game (0 = idle)
!RSTEP  = $7E02F2
!P      = $7E02F3      ; player loop
!N      = $7E02F4      ; list length
!K      = $7E02F5
!FORCE  = $7E02F6      ; replay wants $EE/$EF written even with a window open
!T3     = $7E02F7
!TTYPE  = $7E02D5      ; 3 per slot: target type of the chosen command
!TIDX   = $7E02EC      ; 3 per slot: private target index (FF = no private target)
!BLINK  = $7E02EB      ; frame counter for the sprite pass
!PID    = $7E02DE      ; 3 per slot: battle id under each pointer (FF hidden)
; combo proposals (combo.asm).  RAM: the game reads $023D-$0244 and
; $0260-$027B in battle, so only $0245-$025F, $027C-$02A0, $02A2-$02B3 are used
!CUR   = $7E0245       ; 3 words: this tick's presses per player (snapshot of !ACC)
!SIG   = $7E024B       ; 6: READY and MODE of each slot when the lists were built
!VK    = $7E0251       ; word temp
!VB    = $7E0253       ; word: slot*20
!VS    = $7E0255       ; word: slot's record base
!VIEW  = $7E027C       ; 3 per partner slot: proposer+1 being shown (0 none)
!ACPT  = $7E027F       ; 3 per partner slot: proposer+1 accepted (0 none)
!PMASK = $7E0282       ; 3 per proposer slot: partner slots (bit per slot)
!CP    = $7E0285       ; word temp
!CS    = $7E0287
!CW    = $7E0288
!CN    = $7E0289
!CM    = $7E028A
!CX    = $7E028B
!CY    = $7E028C
!CZ    = $7E028D
!VN    = $7E028E       ; 3: visible tech list length per slot
!VMASK = $7E02A2       ; 3 bytes per slot: rows of the game's list that are visible
!TXT   = $7E02AB       ; 5 letters to draw

!TECHLIST = $7E94D0     ; + slot*20: battle tech list (values >= $FB end the singles)
!ITEMLIST = $7E1580     ; 5 bytes per entry, +0 item id (0 = end)
!TLSCROLL = $7E95EB     ; + slot: tech list scroll
!TLCUR    = $7E95DF     ; + slot: tech list cursor
!ILSCROLL = $7E95E6     ; item list scroll (shared)
!ILCUR    = $7E95E5     ; item list cursor (shared)

!WHITE = $29
!GREY  = $2D
!ARROW = $5C            ; font tile $15C, a right-pointing triangle

; work RAM for the boxes and the X description (7F:5480-6040 is unused by
; the game in battle and on the field: 7F:5C00-5CFF here, 7F:5D00-5E7F the
; boxes being drawn (!BOXBUF), 7F:5E80-5FFF the finished ones (!SHOW))
!DTAB  = !RAMB+$00        ; one-entry pointer table for the text engine
!DSTR  = !RAMB+$02        ; "Name: description" (up to 96 bytes)
!XHELD = !RAMB+$70        ; bit per player: X held this frame
!XPREV = !RAMB+$71        ; ... at the last menu tick
!DESCP = !RAMB+$72        ; player+1 whose description is wanted (0 none)
!DKEY  = !RAMB+$73        ; 3: type, id, player of the text that is up
!DON   = !RAMB+$76        ; 1 = our text was put up
!DT    = !RAMB+$78        ; entry type (1 tech, 2 item)
!DI    = !RAMB+$79        ; entry id
!LP    = !RAMB+$7A        ; label palette
!RP    = !RAMB+$7B        ; row palette
!CPAL  = !RAMB+$FD        ; command row colour (draw_cmds)
!DTICK = !RAMB+$FE        ; menu ticks (draw_rot: which box, and when)
!NUM   = !RAMB+$7E        ; word: number being converted
!DIG   = !RAMB+$80        ; 3: digit tiles
!FILL  = !RAMB+$83        ; gauge pixels left to draw
!DQ    = !RAMB+$84        ; 4 bytes scratch
!TMP   = !RAMB+$88        ; word scratch
!NL    = !RAMB+$8A        ; name length in the table
!DSP   = !RAMB+$8B        ; player+1 whose entry the description shows
!HP    = !RAMB+$8C        ; word
!MPV   = !RAMB+$8E        ; word
!NM    = !RAMB+$90        ; 11: a name from the table
!NM7   = !RAMB+$A0        ; 7: the name as drawn
!TXT7  = !RAMB+$A8        ; 7: a proposal line in a Tech list
!PUB   = $7F1E36        ; 1 while the finished boxes are being copied out
!BOXON = $7F1E8A        ; frames left that the screen shows our boxes (0 = the game's)
!SHOW  = !RAMB+$280        ; the finished boxes: what the screen's panel upload reads

menu_pre:
	JSL $CFFAE2             ; the instruction we replaced
	PHP
	REP #$30                ; keep the game's full A/X/Y: its code after this hook
	PHA                     ; relies on the hidden high byte of A (ASL / TAX
	PHX                     ; dispatches in the target picker)
	PHY
	SEP #$20
	REP #$10
	JSL join_edge_l         ; solo (or its window still open): the original
	BNE +                   ; menu, untouched
	JMP .off
+	PHP                     ; take this tick's presses (presses that arrive while
	SEI                     ; the tick runs are kept for the next one)
	REP #$20
	LDA.l !ACC
	STA.l !CUR
	LDA.l !ACC+2
	STA.l !CUR+2
	LDA.l !ACC+4
	STA.l !CUR+4
	LDA #$0000
	STA.l !ACC
	STA.l !ACC+2
	STA.l !ACC+4
	PLP
	LDA.l !MENUSLOT
	BPL +
	JMP .clear
+	STA.l !F

	; slots that stopped being ready lose their pending state
	LDX #$0000
-	LDA.l !READY,x
	BPL +
	LDA #$00
	STA.l !MODE,x
+	INX
	CPX #$0003
	BNE -
	; a replayed slot that vanished
	LDA.l !RSLOT
	BEQ +
	DEC
	%tax8()
	LDA.l !READY,x
	BPL +
	LDA #$00
	STA.l !RSLOT
+
	JSR combo_tick
	; ---- each player drives their own box
	LDA #$00
	STA.l !P
.ploop:
	JSR fix_sel
	BMI .pnext
	STA.l !S
	JSR player_input
.pnext:
	LDA.l !P
	INC
	STA.l !P
	CMP #$03
	BNE .ploop

	; ---- a cancelled target pick drops the game back into its (never shown)
	; list: put it straight back on the boxes instead
	LDA.l !RSLOT
	BNE +
	LDA.l !TARGET
	BNE +
	LDA.l !SUBWIN
	BEQ +
	LDA #$00
	STA.l !SUBWIN
+
	; ---- the game's real menu only hears the replay engine
	LDA #$00
	STA.l !LO
	STA.l !HI
	STA.l !FORCE
	JSR replay
	LDA.l !FORCE
	BNE .write
	LDA.l !SUBWIN
	ORA.l !TARGET
	BNE .draw               ; a real window is open: its owner's pad drives it
.write:
	LDA.l !LO
	STA.l $7E00EE
	LDA.l !HI
	STA.l $7E00EF
.draw:
	JSL aff_tick_l          ; who each aimed move will hit
	JSL ext_maybe_l         ; ... and their hands, when something changed
	JSR desc_tick           ; hold X = description
	JSL draw_due_l          ; a press / the replay: all three at once, so it
	BCC .rot                ; shows immediately; otherwise one box a frame
	JSR draw_boxes          ; 3 players: the shared panel stays up all battle
	BRA .out                ; (the game's own windows are never shown)
.clear:                         ; nobody's menu is up: the boxes still show (grey)
.rot:                           ; with live numbers
	JSR draw_rot
	BRA .out
.off:
	JSR box_off             ; the screen shows the game's own panel again
.out:
	REP #$30
	PLY
	PLX
	PLA
	PLP
	RTL

; ---------------------------------------------------------------------
; is slot A ready and owned by player !P?  (Z set = yes)
owned_ready:
	STA.l !T3
	%tax8()
	LDA.l !READY,x
	BMI .no
	LDA.l !T3
	JSR owner
	CMP.l !P
	RTS
.no:
	LDA #$01                ; Z clear
	RTS

; make SEL[P] a ready slot owned by P (keep the current one if still fine)
; returns A = slot or $FF (N set)
fix_sel:
	LDA.l !P
	%tax8()
	LDA.l !SEL,x
	CMP #$03
	BCS .search
	JSR owned_ready
	BNE .search
	BRA .ret
.search:
	; first owned ready slot that isn't committed, else any owned ready slot
	LDA #$00
	STA.l !K
-	LDA.l !K
	JSR owned_ready
	BNE +
	LDA.l !K
	%tax8()
	LDA.l !MODE,x
	JSR is_done
	BNE .found
+	LDA.l !K
	INC
	STA.l !K
	CMP #$03
	BNE -
	LDA #$00
	STA.l !K
-	LDA.l !K
	JSR owned_ready
	BEQ .found
	LDA.l !K
	INC
	STA.l !K
	CMP #$03
	BNE -
	LDA #$FF
	STA.l !K
.found:
	LDA.l !P
	%tax8()
	LDA.l !K
	STA.l !SEL,x
.ret:
	LDA.l !P
	%tax8()
	LDA.l !SEL,x
	RTS

; move SEL[P] to the next (A=1) or previous (A=2) owned ready slot
cycle_sel:
	STA.l !N                ; direction
	LDA.l !S
	STA.l !K
	LDY #$0003
.step:
	LDA.l !N
	CMP #$01
	BNE .back
	LDA.l !K
	INC
	CMP #$03
	BNE +
	LDA #$00
+	BRA .chk
.back:
	LDA.l !K
	DEC
	BPL .chk
	LDA #$02
.chk:
	STA.l !K
	JSR owned_ready
	BEQ .take
	DEY
	BNE .step
	RTS
.take:
	LDA.l !P
	%tax8()
	LDA.l !K
	STA.l !SEL,x
	RTS

; after a commit: hop to this player's next uncommitted slot (if any)
advance_sel:
	LDA #$01
	STA.l !N
	LDA.l !S
	STA.l !K
	LDY #$0002
-	LDA.l !K
	INC
	CMP #$03
	BNE +
	LDA #$00
+	STA.l !K
	JSR owned_ready
	BNE +
	LDA.l !K
	%tax8()
	LDA.l !MODE,x
	JSR is_done
	BEQ +
	LDA.l !P
	%tax8()
	LDA.l !K
	STA.l !SEL,x
	RTS
+	DEY
	BNE -
	RTS

; A = 1 tech / 2 item, slot !S -> !N = number of entries
count_list:
	CMP #$02
	BEQ .items
	LDA.l !S                ; opening the list: build it now
	%tax8()
	LDA.l !MODE,x
	CMP #$01
	BEQ +
	LDA.l !S
	STA.l !CY
	JSR vl_slot
+	LDA #$FF
	JMP tl_scan             ; own techs + usable combos
.done:
	RTS
.items:
	LDX #$0000
	LDA #$00
	STA.l !N
-	LDA.l !ITEMLIST,x
	BEQ .done
	INX
	INX
	INX
	INX
	INX
	LDA.l !N
	INC
	STA.l !N
	CMP #64
	BNE -
	RTS

; X = !S * 20
techbase:
	LDA.l !S
	REP #$20
	AND #$00FF
	STA.l !SCR+4
	ASL
	ASL
	CLC
	ADC.l !SCR+4            ; *5
	ASL
	ASL                     ; *20
	TAX
	SEP #$20
	RTS

; ---------------------------------------------------------------------
; this tick's presses of player !P, for their slot !S
player_input:
	LDA.l !P
	REP #$20
	AND #$00FF
	ASL
	TAX
	LDA.l !CUR,x
	SEP #$20
	STA.l !T0               ; buttons: $80 confirm, $0A cancel
	XBA
	STA.l !T1               ; d-pad:  $08 up, $04 down, $02 left, $01 right
	; busy?  this player is aiming in the game's real target picker
	LDA.l !TARGET
	ORA.l !SUBWIN
	BEQ +
	LDA.l !F
	JSR owner
	CMP.l !P
	BNE +
	RTS
+	LDA.l !RSLOT
	BEQ +
	DEC
	CMP.l !S
	BNE +
	RTS
+	JSL box_snd_l           ; another player has the Comb panel up (+ this
				; player's press makes the menu tick: trail.asm)
	BCC +
	RTS
+	LDA.l !S
	%tax8()
	LDA.l !MODE,x
	CMP #$08                ; this player's Comb panel
	BNE +
	JSL cm_input_l
	RTS
+	CMP #$09                ; confirming a tech that needs no target
	BNE .not9
	JSL desc_conf_l
	RTS
.not9:
	CMP #$05
	BNE +
	LDA.l !T0               ; proposing: B withdraws it
	AND #$0A
	BEQ ++
	LDA.l !S
	JMP combo_cancel
++	JMP .leftright
+	CMP #$06
	BNE +
	JMP .leftright          ; waiting to join a combo
+	CMP #$07
	BNE +
	JMP ask_input           ; joined someone's combo, waiting for the rest
+	LDA.l !MODE,x
	BNE +
	JMP .boxes
+	CMP #$04
	BNE +
	JMP .aim
+	CMP #$03
	BNE .list
	; committed: B takes it back, left/right picks another character
	LDA.l !T0
	AND #$0A
	BEQ +
	LDA #$00
	STA.l !MODE,x
	RTS
+	JMP .leftright

.list:
	JSR count_list          ; A = mode
	LDA.l !S
	%tax8()
	LDA.l !LPOS,x
	CMP.l !N
	BCC +
	LDA #$00
	STA.l !LPOS,x
	STA.l !LTOP,x
+
	LDA.l !T0
	AND #$0A
	BEQ +
	LDA #$00                ; B: back to the boxes
	STA.l !MODE,x
	RTS
+	LDA.l !T1
	AND #$08
	BEQ +
	LDA.l !LPOS,x
	BEQ +
	DEC
	STA.l !LPOS,x
	CMP.l !LTOP,x
	BCS +
	STA.l !LTOP,x
+	LDA.l !T1
	AND #$04
	BEQ +
	LDA.l !LPOS,x
	INC
	CMP.l !N
	BCS +
	STA.l !LPOS,x
	SEC
	SBC #$01                ; 2 visible lines (the strip is the 3rd)
	BMI +
	CMP.l !LTOP,x
	BCC +
	BEQ +
	STA.l !LTOP,x
+	LDA.l !T0
	AND #$80
	BEQ +
	LDA.l !MODE,x
	CMP #$01
	BNE ++
	LDA.l !LPOS,x           ; tech: the visible entry -> its row in the game's list
	JSR tl_scan
	PHA
	LDA.l !S
	%tax8()
	PLA
	CMP #$E0                ; a combo someone proposed: join it
	BCC .tl_own
	JMP join_prop
.tl_own:
	STA.l !CHOICE,x
	JMP pick_target
++	LDA.l !LPOS,x
	STA.l !CHOICE,x
	JMP pick_target
+	RTS

.boxes:                         ; the 2x2 grid: Att Tech / Item Comb
	JSL cm_askin_l          ; a combo proposed to it: A yes / B no, first
	BCC +
	RTS
+	LDA.l !S
	%tax8()
	LDA.l !T1
	AND #$0C                ; up / down: the other line
	BEQ +
	LDA.l !PROW,x
	EOR #$02
	STA.l !PROW,x
+	LDA.l !T1
	AND #$01                ; right: the right column, or past it the next box
	BEQ +
	LDA.l !PROW,x
	LSR
	BCC ++
	JMP .leftright
++	LDA.l !PROW,x
	ORA #$01
	STA.l !PROW,x
+	LDA.l !T1
	AND #$02                ; left: the left column, or past it the box before
	BEQ +
	LDA.l !PROW,x
	LSR
	BCS ++
	JMP .leftright
++	LDA.l !PROW,x
	AND #$02
	STA.l !PROW,x
+
	LDA.l !T0
	AND #$80
	BEQ .ret
	LDA.l !PROW,x
	BNE .notatt
	LDA #$00                ; Attack: choose a target
	STA.l !CHOICE,x
	JMP pick_target
.notatt:
	CMP #$03                ; Comb: accept the proposal / open the panel
	BNE +
	JSL cm_comb_l
	RTS
+
	STA.l !T3               ; row 1 -> mode 1 (tech), row 2 -> mode 2 (item)
	JSR count_list
	LDA.l !N
	BEQ .ret                ; nothing to show: stay put
	LDA.l !S
	%tax8()
	LDA.l !T3
	STA.l !MODE,x
	LDA #$00
	STA.l !LPOS,x
	STA.l !LTOP,x
.ret:
	RTS

.aim:
	; private target picking: the d-pad steps through the candidates
	JSR cand_count          ; N = candidates for this slot's target type
	LDA.l !S
	%tax8()
	LDA.l !T0
	AND #$0A
	BEQ .aimgo
	LDA.l !PMASK,x          ; B: a combo goes back to the Comb panel,
	BEQ .aimlist            ; anything else to its list (or the boxes)
	LDA #$08
	BRA .aimback
.aimlist:
	LDA.l !PROW,x
.aimback:
	STA.l !MODE,x
	RTS
.aimgo:
	LDA.l !N
	BNE +
	RTS                     ; nothing to aim at (all dead?)
+	JSL aim_nav_l           ; the d-pad: the nearest target that way on screen
	LDA.l !S
	%tax8()
	LDA.l !TIDX,x           ; keep it in range if a target died
	CMP.l !N
	BCC +
	LDA #$00
	STA.l !TIDX,x
+	LDA.l !T0
	AND #$80
	BEQ +
	JMP commit              ; confirm: command + target are committed (or proposed)
+	RTS

.leftright:
	LDA.l !T1
	AND #$01
	BEQ +
	LDA #$01
	JMP cycle_sel
+	LDA.l !T1
	AND #$02
	BEQ +
	LDA #$02
	JMP cycle_sel
+	RTS

; ---------------------------------------------------------------------
; feed committed choices into the game's real menu, one at a time
replay:
	LDA.l !RSLOT
	BNE .active
	LDA.l !SUBWIN
	ORA.l !TARGET
	BNE .r
	LDX #$0000
-	LDA.l !MODE,x
	CMP #$03
	BNE +
	LDA.l !READY,x
	BMI +
	LDA.l !VIEW,x           ; deciding on a combo proposal: hold it
	BNE +
	TXA
	INC
	STA.l !RSLOT
	LDA #$00
	STA.l !RSTEP
	BRA .active
+	INX
	CPX #$0003
	BNE -
	JSL prepos_l            ; idle: put the hidden menu on whoever confirms next
.r:
	RTS
.active:
	LDA.l !RSLOT
	DEC
	STA.l !K                ; K = slot being replayed
	%tax8()
	LDA.l !RSTEP
	BEQ .step0
	JMP .step3
.step0:
	LDA.l !SUBWIN
	ORA.l !TARGET
	BNE .r                  ; wait for the real menu to be free
	LDA.l !F
	CMP.l !K
	BEQ .confirm
	JSR next_ready          ; A = F -> next ready slot
	CMP.l !K
	BNE +
	LDA #$01                ; right = next
	BRA ++
+	LDA #$02                ; left = previous
++	STA.l !HI
	RTS
.confirm:
	LDA.l !PROW,x           ; the game may have copied another cursor over it
	STA.l !CURSOR,x
	BNE .direct
	LDA #$80                ; Attack: confirm on the real top menu -> target picker
	STA.l !LO
	LDA #$03
	STA.l !RSTEP
	RTS
.direct:
	; Tech/Item: skip the game's big list window.  Put the game straight into
	; "list open" with the chosen entry selected, then confirm.
	LDA #$FF
	STA.l $7EA0D7
	LDA #$00
	STA.l $7EA09A
	LDA.l !PROW,x
	STA.l $7E9615           ; command type: 1 tech, 2 item (as the open-list code sets)
	STA.l !SUBWIN
	CMP #$02
	BEQ .item
	LDA.l !CHOICE,x
	STA.l !TLSCROLL,x
	LDA #$00
	STA.l !TLCUR,x
	LDA #$01
	STA.l $7EA099           ; "list ready"
	; selected-tech record -> $9EE3..$9EE9
	LDA.l !K
	STA.l !CY
	JSR choice_rec
	LDY #$0000
-	LDA.l $7E1A80,x
	PHX
	TYX
	STA.l $7E9EE3,x
	PLX
	INX
	INY
	CPY #$0007
	BNE -
	BRA .go
.item:
	LDA.l !CHOICE,x
	STA.l !ILSCROLL
	LDA #$00
	STA.l !ILCUR
.go:
	LDA #$80
	STA.l !LO
	LDA #$01
	STA.l !FORCE
	LDA #$03
	STA.l !RSTEP
	RTS
.step1:
.step3:
	LDA.l !RSTEP
	CMP #$08                ; backing out of a wrong pick
	BNE .n8
	JSL rp_back_l
	RTS
.n8:
	CMP #$07
	BEQ .step7
	CMP #$04
	BEQ .step4
	CMP #$05
	BEQ .fin
	CMP #$06
	BEQ .step6
	; accepted -> target picker (or done); refused -> quietly back to the boxes
	LDA.l !TARGET
	BEQ +
	LDA #$06                ; let the picker build its target list for a tick first
	STA.l !RSTEP            ; (an index it doesn't have yet makes it cancel itself)
	RTS
.step6:
	JSL rp_check_l          ; a Tech the game took as an Attack: back out, retry
	BCC .s6ok
	RTS
.s6ok:
	LDA.l !TARGET
	BEQ .fin
	LDA.l !TIDX,x
	CMP #$FE                ; the game's own picker: its owner drives it
	BNE +++
	LDA #$07
	STA.l !RSTEP
	RTS
+++	BRA .step4              ; the player's own target, confirmed this same tick
	                        ; (the picker built its list last tick; was a
	                        ; separate tick that set it twice - 1 tick slower)
+
	LDA.l !SUBWIN
	BEQ .fin
	LDA #$00
	STA.l !SUBWIN
	BRA .fin
.step7:                         ; the owner confirms (or cancels) in the game's picker
	LDA.l !TARGET
	BEQ .fin
	RTS
.step4:
	LDA.l !TIDX,x
	JSL tgt_set_l
	LDA #$80
	STA.l !LO
	LDA #$01
	STA.l !FORCE
	LDA #$05
	STA.l !RSTEP
	RTS
.fin:
	LDA.l !K
	%tax8()
	LDA #$00
	STA.l !MODE,x
	STA.l !RSLOT
	RTS


; ---------------------------------------------------------------------
; after a command (and list entry) is chosen: work out its target type and
; either start private aiming (mode 4) or commit straight away (mode 3)
; in: X = slot (= !S)
pick_target:
	LDA #$00
	STA.l !PMASK,x
	LDA.l !PROW,x
	BNE .notatt
	LDA #$07                ; Attack = one enemy
	BRA .have
.notatt:
	CMP #$02
	BEQ .item
	; tech: its battle record (target type, combo partners)
	LDA.l !S
	STA.l !CY
	JSR choice_rec
	BCC +
	LDA #$01                ; not found (shouldn't happen): let the game handle it
	BRA .have
+	PHX
	JSR combo_mask
	PHA
	LDA.l !S
	%tax8()
	PLA
	STA.l !PMASK,x
	PLX
	LDA.l $7E1A81,x
	AND #$7F
	BRA .have
.item:
	LDA.l !CHOICE,x
	REP #$20
	AND #$00FF
	STA.l !SCR+4
	ASL
	ASL
	CLC
	ADC.l !SCR+4
	TAX
	SEP #$20
	LDA.l !ITEMLIST+1,x
	AND #$7F
.have:
	CMP #$21
	BCC +
	LDA #$20
+	PHA
	LDA.l !S
	%tax8()
	PLA
	STA.l !TTYPE,x
	%tax8()
	LDA.l target_class,x
	PHA
	LDA.l !S
	%tax8()
	PLA                     ; (a combo is aimed by its proposer, now)
	BEQ .nochoice
	CMP #$03
	BEQ .gamepick
	LDA #$00
	STA.l !TIDX,x
	LDA #$04
	STA.l !MODE,x
	RTS
.gamepick:                      ; all / self: nothing to pick (the game's own
	LDA #$FF                ; default at fire time).  A single tech confirms
	STA.l !TIDX,x           ; first, with its description (mode 9)
	JSL desc_gp_l
	BCC .gpgo
	RTS
.gpgo:
	JMP commit
.nochoice:
	LDA #$FF
	STA.l !TIDX,x
	JMP commit

; by target type 00..20: 1 = pick one ally, 2 = pick one enemy (privately,
; with the player's own pointer); 3 = everything else (areas, all enemies,
; all allies, self): the game's own target picker, which blinks a hand on
; every target the move will hit, driven by that player's controller
target_class:                   ; (from the game's own target list builders,
	db 1,3,3,3,3,3,3,2,3,3,3,2,2,2,1,2  ; C1:1FF8: 0B 0C 0D 0F 12 1A build the
	db 1,3,2,3,3,1,1,1,3,1,2,3,1,1,1,1  ; enemy list and let the player move the
	db 1                            ; centre of the area)

; slot !S -> !N = its candidates; with an index A -> A = that candidate's
; battle id (FF none).  Exactly the game's own list (aff.asm cand_far_l)
cand_count:
	LDA #$FF
cand_id:
	JSL cand_far_l
	RTS

; ---------------------------------------------------------------------
; every frame, from battle_input (main loop, not NMI): work out which battle id
; each player's pointer sits on (FF = hidden).  The NMI only copies positions.
ptr_update:
	LDA.l !S
	PHA
	LDA.l !N
	PHA
	LDA.l !T3
	PHA
	LDA.l !BLINK
	INC
	STA.l !BLINK
	LDA.l !JOINED
	BEQ +
	JSR ptr_colours
+	LDA #$00
	STA.l !S
.loop:
	LDA.l !S
	%tax8()
	LDA #$FF
	STA.l !PID,x
	LDA.l !JOINED
	BEQ .next
	LDA.l !READY,x
	BMI .next
	LDA.l !MODE,x
	CMP #$04
	BEQ .show
	CMP #$05
	BEQ +
	CMP #$03
	BNE .next
+	LDA.l !TIDX,x           ; committed / proposed with a target: blink it
	CMP #$FE                ; (FE: the game's picker shows it; FF: none)
	BCS .next
	LDA.l !BLINK
	AND #$08
	BEQ .next
.show:
	LDA.l !TIDX,x
	JSR cand_id
	PHA
	LDA.l !S
	%tax8()
	PLA
	STA.l !PID,x
.next:
	LDA.l !S
	INC
	STA.l !S
	CMP #$03
	BNE .loop
	PLA
	STA.l !T3
	PLA
	STA.l !N
	PLA
	STA.l !S
	RTS

; NMI, just before the battle uploads its sprite table: entries 112..114 = the
; three pointers (the game's hand sprite, tile 0, in the character's palette).
; Registers only, no shared temps: this must stay short (vblank time).
macro ptr(slot)
	LDA.l !PID+<slot>
	CMP #$FF
	BEQ ?hide
	%tax8()
	LDA.l $7E1D0C,x         ; left of the target, players stacked
	CLC
	ADC.l $7E9708,x
	SEC
	SBC #$14
	BCS ?xok
	LDA #$00
?xok:
	STA.l $7E0700+((112+<slot>)*4)
	LDA.l $7E1D23,x
	CLC
	ADC.l $7E9713,x
	SEC
	SBC #$14-(<slot>*12)     ; players stacked 12px apart, same column
	STA.l $7E0701+((112+<slot>)*4)
	LDA #$00
	STA.l $7E0702+((112+<slot>)*4)
	LDA.l !PPAL+<slot>      ; this slot's pointer palette (ptr_colours)
	STA.l $7E0703+((112+<slot>)*4)
	BRA ?done
?hide:
	LDA #$F0
	STA.l $7E0701+((112+<slot>)*4)
?done:
endmacro

; Pointer colours, by PLAYER: player 1 white, player 2 light blue, player 3
; red (whoever drives that party slot).  The hand sprite uses colours 13-15.
;   white:      sprite palette 4 (the game's hit-flash white) - its slots
;               13-15 get grey shading so the hand has a shape, except while
;               anything is flashing (palette 4 in use): then plain white
;   light blue: palette 3, red: palette 2 - their spare hand slots 13-15
;               (nothing visible uses them in battle)
; The palette buffer is re-uploaded every frame.  -> !PPAL: attribute per slot
!PPAL = $7E0291         ; 3 (battle only)
ptr_colours:
	PHP
	PHB                     ; anything flashing? (palette 4 in the sprite
	SEP #$20                ; table, entries 0-111).  Every frame: four
	REP #$10                ; entries per pass with the bank set, half the
	LDA #$7E                ; time of a plain loop
	PHA
	PLB
	LDX.w #$0000
-	LDA $0703,x
	AND #$0E
	CMP #$08
	BEQ .flash
	LDA $0707,x
	AND #$0E
	CMP #$08
	BEQ .flash
	LDA $070B,x
	AND #$0E
	CMP #$08
	BEQ .flash
	LDA $070F,x
	AND #$0E
	CMP #$08
	BEQ .flash
	REP #$21                ; (16-bit, carry clear)
	TXA
	ADC.w #$0010
	TAX
	SEP #$20
	CPX.w #112*4
	BNE -
	PLB
	REP #$30
	LDA #$7FFF              ; white hand, shaded
	STA.l $7E239A
	LDA #$5AD6
	STA.l $7E239C
	LDA #$294A
	STA.l $7E239E
	BRA +
.flash:
	PLB
	REP #$30
	LDA #$FFFF              ; the flash's own plain white
	STA.l $7E239A
	STA.l $7E239C
	STA.l $7E239E
+	LDA #$7F4E              ; palette 3: light blue
	STA.l $7E237A
	LDA #$6E06
	STA.l $7E237C
	LDA #$2882
	STA.l $7E237E
	LDA #$18DF              ; palette 2: red
	STA.l $7E235A
	LDA #$0854
	STA.l $7E235C
	LDA #$0006
	STA.l $7E235E
	SEP #$20
	LDA #$00
	STA.l !N
-	LDA.l !N
	JSR owner               ; slot -> seat 0/1/2
	%tax8()
	LDA.l !ROLE,x           ; -> its controller: the colour is the person's
	%tax8()
	LDA.l ptr_attr,x
	PHA
	LDA.l !N
	%tax8()
	PLA
	STA.l !PPAL,x
	LDA.l !N
	INC
	STA.l !N
	CMP #$03
	BNE -
	PLP
	RTS

ptr_attr:
	db (4<<1)|$30, (3<<1)|$30, (2<<1)|$30   ; player 1, 2, 3

oam_inject:
	PHP
	SEP #$20
	REP #$10
	PHX
	LDA.l !BTTL
	BNE +
	LDA #$FF                ; battle just started: nothing until the main loop has run
	STA.l !PID
	STA.l !PID+1
	STA.l !PID+2
+	LDA.l !JOINED           ; 3P: hide the game's own target hand (tile 0, OAM 0..7)
	BEQ .nohide             ; unless a player is really aiming in the game's picker
	LDA.l !RSLOT
	BEQ +
	LDA.l !RSTEP            ; a player driving the game's own picker: its
	CMP #$07                ; hands show every target the move will hit
	BEQ .nohide
	BRA .hide
+	LDA.l !TARGET
	BNE .nohide
.hide:
	LDX #$0000
-	LDA.l $7E0702,x
	BNE +
	LDA.l $7E0703,x
	AND #$01
	BNE +
	LDA #$F0
	STA.l $7E0701,x
+	INX
	INX
	INX
	INX
	CPX #$0020
	BNE -
.nohide:
	%ptr(0)
	%ptr(1)
	%ptr(2)
	JSL ext_inject_l
	LDA.l $7E0900+28        ; entries 112..114: large, x bit 8 clear
	AND #$C0
	ORA #$2A
	STA.l $7E0900+28
	PLX
	PLP
	TDC                     ; the instructions we replaced
	STA.l $004370
	RTL

; NMI, right after the sprite table DMA: OBJ priority rotation so entry 112
; is the highest-priority sprite (pointers in front of monsters, never
; dropped by the 32-sprites-per-line limit).  Field/menu code resets it.
oam_after:
	LDA #$80                ; the instructions we replaced: start the DMA
	STA.l $00420B
	LDA.l !JOINED
	BEQ +
	LDA.l !BTTL
	BEQ +
	LDA #$E0                ; OAM word address 112*2
	STA.l $002102
	LDA #$80
	STA.l $002103
+	LDA.l !BOXON            ; the boxes stop showing a moment after the
	BEQ +                   ; menu tick stops drawing them - once the battle
	LDA.l !BTTL             ; is over (a long animation keeps them up)
	BNE +
	LDA.l !BOXON
	DEC
	STA.l !BOXON
	BNE +
	LDA #$01
	STA.l $7E99E2           ; re-send the game's frame
+	RTL

; NMI, the panel upload (CF:E346): while the boxes are up, the panel the
; screen gets is our copy; the game's own panel buffer is left alone
panel_src:
	LDA.l !BOXON
	BEQ .game
	LDA.l $7E9EF6           ; only the game's panel upload: $00:0CC0, $180 bytes
	CMP #$C0
	BNE .game
	LDA.l $7E9EFC
	CMP #$0C
	BNE .game
	LDA.l $7E9F02
	BNE .game
	LDA.l $7E9F08
	CMP #$80
	BNE .game
	LDA.l $7E9F0E
	CMP #$01
	BNE .game
	LDA.l !PUB              ; the copy is mid-way: the finished drawing
	BNE .buf
	LDA.b #!SHOW&$FF
	STA.l $004372
	LDA.b #(!SHOW>>8)&$FF
	STA.l $004373
	LDA.b #!SHOW>>16
	STA.l $004374
	RTL
.buf:
	LDA.b #!BOXBUF&$FF
	STA.l $004372
	LDA.b #(!BOXBUF>>8)&$FF
	STA.l $004373
	LDA.b #!BOXBUF>>16
	STA.l $004374
	RTL
.game:
	LDA.l $7E9EF6           ; the instructions we replaced
	STA.l $004372
	LDA.l $7E9EFC
	STA.l $004373
	LDA.l $7E9F02
	STA.l $004374
	RTL

; NMI, the window frame upload (CF:E390): our frame (dividers at columns 10
; and 20, straight from ROM) while the boxes are up, else the game's $0B40
frame_src:
	LDA.l !BOXON
	BEQ .game
	LDA.b #frame_solid&$FF
	STA.l $004372
	LDA.b #(frame_solid>>8)&$FF
	STA.l $004373
	LDA.b #frame_solid>>16
	STA.l $004374
	RTL
.game:
	LDA #$40                ; the instructions we replaced
	STA.l $004372
	LDA #$0B
	STA.l $004373
	LDA #$00
	STA.l $004374
	RTL

; the boxes stop showing now
box_off:
	LDA.l !BOXON
	BEQ +
	LDA #$00
	STA.l !BOXON
	LDA #$01
	STA.l $7E99E2           ; re-send the game's frame
+	RTS

incsrc "combo.asm"

; ---------------------------------------------------------------------
; drawing.  Three boxes of 10 columns x 6 tile rows at BOXBUF + s*20.  The
; text lines are tile rows 1, 3, 5 (+$40, +$C0, +$140); rows 0, 2, 4 are
; squeezed away by the game.  The window frame gets dividers at columns 10
; and 20 to match.  The game keeps drawing its own panel into its own buffer;
; while the boxes are up, the screen's panel and frame uploads (NMI) simply
; read ours instead (panel_src / frame_src), so nothing the game draws can
; flash through, and the game's buffers are never touched.
;
; Box, command view:  hand | Att.  HP          List view:  > Name7  MP
;                     hand | Tech    MP                   > Name7  MP
;                     hand | Item gauge                   > Name7  qty


; a menu tick with no press and no change of anyone's menu state, HP or MP
; (aff.asm draw_due_l): one box every other tick, in turn - it keeps the
; gauges moving.  Redrawing all three every tick took the battle's spare
; time: it ran up to a quarter slower.  The first frame the boxes go up, and
; the Comb panel, are drawn whole as before.
draw_rot:
	LDA.l !BOXON
	BEQ draw_boxes
	LDA.l !DTICK            ; only every other menu tick
	INC
	STA.l !DTICK
	LSR
	BCC +
	RTS
+	PHA                     ; box = (tick / 2) mod 3
	JSL cm_panel_l          ; (carry set = the Comb panel, drawn whole)
	PLA
	BCS db_cols
-	CMP #$03
	BCC +
	SBC #$03
	BRA -
+	STA.l !S
	JSR draw_box
	JSL pub_box_l           ; (just this box to the screen: trail.asm)
	RTS

draw_boxes:
	JSL cm_panel_l          ; a player's Comb panel covers all three
	BCS db_cols
	LDA #$00
	STA.l !S
-	JSR draw_box
	LDA.l !S
	INC
	STA.l !S
	CMP #$03
	BNE -
	; columns 30-31 lie outside the boxes (the game's gauge cap was there)
db_cols:
	REP #$20
	LDA #$29FF
	STA.l !BOXBUF+$03C
	STA.l !BOXBUF+$07C
	STA.l !BOXBUF+$0BC
	STA.l !BOXBUF+$0FC
	STA.l !BOXBUF+$13C
	STA.l !BOXBUF+$17C
	LDA #$2900
	STA.l !BOXBUF+$03E
	STA.l !BOXBUF+$07E
	STA.l !BOXBUF+$0BE
	STA.l !BOXBUF+$0FE
	STA.l !BOXBUF+$13E
	STA.l !BOXBUF+$17E
	; publish: the boxes are built off-screen and copied to the copy the
	; screen gets.  While the copy runs (!PUB) the screen reads the finished
	; drawing itself, so it never gets half of each
	SEP #$20
	LDA #$01
	STA.l !PUB
	REP #$20
	LDX #$017E
-	LDA.l !BOXBUF,x
	STA.l !SHOW,x
	DEX
	DEX
	BPL -
	SEP #$20
	LDA #$00
	STA.l !PUB
	LDA.l !BOXON
	BNE +
	LDA #$01
	STA.l $7E99E2           ; send our frame
+	LDA #$18
	STA.l !BOXON            ; shown for 24 frames unless redrawn
	RTS

draw_box:
	LDA.l !S
	%tax8()
	LDA.l $7E96F5,x         ; nobody in this party slot: empty box
	BNE +
	JSR box_x
	JMP box_clear
+	LDA.l !READY,x
	BPL +
	LDA #!GREY              ; not ready yet: grey commands, live numbers
	STA.l !LP
	JMP draw_cmds
+	JSL desc_box_l          ; aiming / confirming a tech: its description
	BCC .nodesc
	RTS
.nodesc:
	LDA.l !MODE,x
	CMP #$05
	BNE +
	JMP draw_prop
+	CMP #$06
	BEQ .text
	CMP #$07
	BNE +
	JMP draw_ask
+	LDA.l !MODE,x
	BEQ .text
	CMP #$03
	BEQ .text
	CMP #$04
	BNE ++
	LDA.l !PROW,x           ; aiming: keep showing the list it came from
	BEQ .text
++	JMP draw_list
.text:
	LDA #!WHITE
	STA.l !LP
	JSR draw_cmds
	JSR box_x
	; hand: committed = grey; the slot a player is driving = white
	LDA.l !S
	%tax8()
	LDA.l !MODE,x
	JSR is_done
	BNE +
	LDA #!GREY
	BRA .hand
+	LDA.l !S
	JSR owner
	%tax8()
	LDA.l !SEL,x
	CMP.l !S
	BNE .nohand
	LDA.l !S                ; hidden while that slot is aiming in the real picker
	CMP.l !F
	BNE +
	LDA.l !TARGET
	BNE .nohand
+	LDA #!WHITE
.hand:
	STA.l !PAL
	LDA.l !S
	%tax8()
	LDA.l !PROW,x
	STA.l !T3
	JSR draw_arrow
.nohand:
	JMP tech_blink          ; (a proposal waiting: the question over the box)

; X = box offset: blank all 6 tile rows of the box (X kept)
box_clear:
	PHX
	LDY #$0006
-	REP #$20
	LDA #$2900
	STA.l !BOXBUF+0,x
	STA.l !BOXBUF+2,x
	LDA #$29FF
	STA.l !BOXBUF+4,x
	STA.l !BOXBUF+6,x
	STA.l !BOXBUF+8,x
	STA.l !BOXBUF+10,x
	STA.l !BOXBUF+12,x
	STA.l !BOXBUF+14,x
	STA.l !BOXBUF+16,x
	STA.l !BOXBUF+18,x
	TXA
	CLC
	ADC #$0040
	TAX
	SEP #$20
	DEY
	BNE -
	PLX
	RTS

cmd_lbl:                        ; 4 letters each
	db $A0,$CD,$CD,$FF      ; Att
	db $B3,$BE,$BC,$C1      ; Tech
	db $A8,$CD,$BE,$C6      ; Item
	db $A2,$C8,$C6,$BB      ; Comb
cmd_pos:                        ; where each label starts in the box (row*$40 +
	dw $0042,$004C,$00C2,$00CC  ; column*2): Att / Tech on text line 0,
cmd_arr:                        ; Item / Comb on line 1; the arrow cursor sits
	dw $0040,$004A,$00C0,$00CA  ; one column left of the label

; command view of slot !S: a 2x2 grid of commands (palette !LP; Tech / Item /
; Comb grey when there is nothing to use) and the status strip under it
draw_cmds:
	JSR box_x
	JSR box_clear
	LDA #$00
	STA.l !DQ               ; command 0..3
.cmd:
	LDA.l !DQ
	ASL
	ASL
	REP #$20
	AND #$00FF
	TAY                     ; row_pal wants command*4
	SEP #$20
	JSR row_pal
	LDA.l !DQ
	CMP #$03                ; Comb: grey unless a proposal waits or there
	BNE +                   ; are combos to propose
	LDA.l !CPAL
	CMP #!GREY
	BEQ +
	JSL cm_avail_l
	BNE +
	LDA #!GREY
	STA.l !CPAL
+	LDA.l !DQ               ; X = this label's place in the box
	ASL
	REP #$20
	AND #$00FF
	TAX
	LDA.l cmd_pos,x
	STA.l !TMP
	SEP #$20
	JSR box_x
	REP #$20
	TXA
	CLC
	ADC.l !TMP
	TAX
	LDA.l !DQ
	AND #$00FF
	ASL
	ASL
	TAY                     ; Y = command*4: its letters
	SEP #$20
	LDA #$04
	STA.l !DQ+1
-	PHX
	TYX
	LDA.l cmd_lbl,x
	PLX
	XBA
	LDA.l !CPAL
	XBA
	REP #$20
	STA.l !BOXBUF,x
	SEP #$20
	INX
	INX
	INY
	LDA.l !DQ+1
	DEC
	STA.l !DQ+1
	BNE -
	LDA.l !DQ
	INC
	STA.l !DQ
	CMP #$04
	BEQ +
	JMP .cmd
+	JMP draw_stats

; the arrow cursor at command !T3 of box !S, palette !PAL
draw_arrow:
	LDA.l !T3
	ASL
	REP #$20
	AND #$00FF
	TAX
	LDA.l cmd_arr,x
	STA.l !TMP
	SEP #$20
	JSR box_x
	REP #$20
	TXA
	CLC
	ADC.l !TMP
	TAX
	SEP #$20
	LDA.l !PAL
	XBA
	LDA #!ARROW
	REP #$20
	STA.l !BOXBUF,x
	SEP #$20
	RTS

; HP (row 1, columns 7-9), MP (row 3, columns 8-9) and the ATB gauge (row 5,
; columns 6-9) of slot !S, worked out the way the game draws its own
draw_stats:
	LDA.l !S
	ASL
	%tax8()
	REP #$20
	LDA.l $CCF8ED,x         ; the character's battle record
	TAX
	LDA.l $7E5E34,x
	STA.l !MPV
	LDA.l $7E5E30,x
	STA.l !HP
	BEQ .crit               ; KO: grey numbers
	LDA.l $7E5E32,x         ; at 1/8 HP or less they flash with the game's blink
	LSR
	LSR
	LSR
	CMP.l !HP
	BCC .ok
	LDA.l $7EA110
	BEQ .ok
.crit:
	SEP #$20
	LDA #$2D
	BRA .pal
.ok:
	SEP #$20
	LDA #$29
.pal:
	STA.l !RP
	; HP
	LDA.l !HP
	STA.l !NUM
	SEP #$20
	JSR digits3
	JSR box_x
	LDA.l !RP
	XBA
	LDA.l !DIG
	REP #$20
	STA.l !BOXBUF+$140,x
	SEP #$20
	LDA.l !DIG+1
	REP #$20
	STA.l !BOXBUF+$142,x
	SEP #$20
	LDA.l !DIG+2
	REP #$20
	STA.l !BOXBUF+$144,x
	; MP
	LDA.l !MPV
	STA.l !NUM
	SEP #$20
	JSR digits3
	JSR box_x
	LDA.l !RP
	XBA
	LDA.l !DIG
	REP #$20
	STA.l !BOXBUF+$14E,x
	SEP #$20
	LDA.l !DIG+1
	REP #$20
	STA.l !BOXBUF+$150,x
	SEP #$20
	LDA.l !DIG+2
	REP #$20
	STA.l !BOXBUF+$152,x
	SEP #$20
	; gauge: filled pixels = 32 - countdown*32/max, grey while charging
	LDA.l !S
	%tax8()
	LDA.l $7E99DD,x
	STA.l !DQ
	LDA.l $7E9F22,x
	STA.l !DQ+1
	LDA #$29
	STA.l !DQ+2
	LDA.l !DQ
	BEQ +
	LDA #$2D
	STA.l !DQ+2
+	REP #$20
	LDA.l !DQ+1
	AND #$00FF
	STA.l !TMP
	BEQ .full
	LDA.l !DQ
	AND #$00FF
	ASL
	ASL
	ASL
	ASL
	ASL
	LDX #$0000
-	CMP.l !TMP
	BCC +
	SBC.l !TMP
	INX
	CPX #$0020
	BCC -
+	TXA
	SEP #$20
	EOR #$FF
	SEC
	ADC #$20                ; 32 - quotient
	BRA .fill
.full:
	SEP #$20
	LDA #$20
.fill:
	STA.l !FILL
	JSR box_x
	LDA.l !DQ+2
	XBA
	LDY #$0000
-	LDA.l !FILL
	CMP #$08
	BCC +
	LDA #$08
+	PHA
	CLC
	ADC #$67                ; $167 empty .. $16F full
	REP #$20
	STA.l !BOXBUF+$146,x
	SEP #$20
	PLA
	EOR #$FF
	SEC
	ADC.l !FILL
	STA.l !FILL
	INX
	INX
	INY
	CPY #$0004
	BNE -
	RTS

; !NUM (word) -> !DIG = 3 digit tiles ($73+d), leading zeroes blank ($FF)
digits3:
	REP #$20
	LDA.l !NUM
	CMP #$03E8
	BCC +
	LDA #$03E7              ; 999 at most
+	LDX #$0000
-	CMP #$0064
	BCC +
	SBC #$0064
	INX
	BRA -
+	STA.l !NUM
	TXA
	SEP #$20
	STA.l !DIG
	REP #$20
	LDA.l !NUM
	LDX #$0000
-	CMP #$000A
	BCC +
	SBC #$000A
	INX
	BRA -
+	SEP #$20
	CLC
	ADC #$73
	STA.l !DIG+2
	TXA
	CLC
	ADC #$73
	STA.l !DIG+1
	LDA.l !DIG
	BEQ +
	CLC
	ADC #$73
	STA.l !DIG
	RTS
+	LDA #$FF
	STA.l !DIG
	LDA.l !DIG+1
	CMP #$73
	BNE +
	LDA #$FF
	STA.l !DIG+1
+	RTS

; hand at row !T3 of box !S, high byte !PAL
draw_hand_row:
	LDA.l !T3
	REP #$20
	AND #$00FF
	XBA
	LSR                     ; row * $80
	STA.l !T0
	SEP #$20
	JSR box_x
	REP #$20
	TXA
	CLC
	ADC.l !T0
	TAX
	SEP #$20
	LDA.l !PAL
	XBA
	LDA #$60
	REP #$20
	STA.l !BOXBUF+$000,x
	INC
	STA.l !BOXBUF+$002,x
	INC
	STA.l !BOXBUF+$040,x
	INC
	STA.l !BOXBUF+$042,x
	SEP #$20
	RTS

; !DT (1 tech, 2 item), !DI = id -> !NM7 = the name as 7 tiles: the full
; name when it fits, else its first 7 letters (first 6 + the digit when it
; ends in one, so Lightning / Lightning2 stay apart)
name_fetch:
	REP #$20
	LDA.l !DI
	AND #$00FF
	STA.l !NUM
	ASL
	ASL
	ASL
	CLC
	ADC.l !NUM
	CLC
	ADC.l !NUM
	CLC
	ADC.l !NUM              ; *11
	TAX
	SEP #$20
	LDA.l !DT
	CMP #$02
	BEQ .item
	LDA.l $CC15C4,x         ; techs: byte 0 is an icon, or already a letter
	CMP #$A0
	BCC .icon
	CMP #$EF
	BCS .icon
	REP #$21
	TXA
	ADC #$15C4
	TAX
	SEP #$20
	LDA #$0B
	BRA .copy
.icon:
	REP #$21
	TXA
	ADC #$15C5
	TAX
	SEP #$20
	LDA #$0A
	BRA .copy
.item:
	REP #$21                ; items: byte 0 is always the icon
	TXA
	ADC #$0B5F
	TAX
	SEP #$20
	LDA #$0A
.copy:
	STA.l !NL
	LDY #$0000
-	LDA.l $CC0000,x
	PHX
	TYX
	STA.l !NM,x
	PLX
	INX
	INY
	TYA
	CMP.l !NL
	BNE -
	LDX #$0000
-	LDA.l !NM,x
	STA.l !NM7,x
	INX
	CPX #$0007
	BNE -
	LDA.l !NL               ; last letter that isn't a space
	%tax8()
-	DEX
	BMI .done
	LDA.l !NM,x
	CMP #$EF
	BEQ -
	CMP #$FF
	BEQ -
	CPX #$0007
	BCC .done               ; fits
	CMP #$D4
	BCC .done
	CMP #$DE
	BCS .done
	STA.l !NM7+6            ; ends in a digit: keep it
.done:
	RTS

; slot !S, A = tech id -> A = that character's MP cost ($FF = unknown)
tech_cost:
	PHA
	LDA.l !S
	STA.l !CY
	PLA
	JSR rec_find
	BCS .none
	LDA.l !S
	BEQ .s0
	CMP #$01
	BEQ .s1
	LDA.l $7E1A86,x
	RTS
.s1:
	LDA.l $7E1A85,x
	RTS
.s0:
	LDA.l $7E1A83,x
	RTS
.none:
	LDA #$FF
	RTS

; the private Tech/Item list of slot !S (mode in A: 1 tech, 2 item):
; 3 lines of  arrow, 7-letter name, 2-digit MP cost / quantity
draw_list:
	STA.l !T3
	JSR count_list
	LDA #$00
	STA.l !K                ; line 0..2
.row:
	JSR box_x
	LDA.l !K
	REP #$20
	AND #$00FF
	XBA
	LSR                     ; line*$80
	STA.l !T0
	TXA
	CLC
	ADC.l !T0
	TAX
	LDA #$29FF              ; both tile rows of the line, all 10 columns
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
	STA.l !BOXBUF+$40,x
	STA.l !BOXBUF+$42,x
	STA.l !BOXBUF+$44,x
	STA.l !BOXBUF+$46,x
	STA.l !BOXBUF+$48,x
	STA.l !BOXBUF+$4A,x
	STA.l !BOXBUF+$4C,x
	STA.l !BOXBUF+$4E,x
	STA.l !BOXBUF+$50,x
	STA.l !BOXBUF+$52,x
	TXA
	CLC
	ADC #$0040
	STA.l !T0               ; T0/T1 = the line's text row
	SEP #$20
	; idx = LTOP + line
	LDA.l !S
	%tax8()
	LDA.l !LTOP,x
	CLC
	ADC.l !K
	STA.l !SCR+2            ; idx
	CMP.l !N
	BCC .entry
	JMP .nextrow            ; past the end: stays blank
.entry:
	; arrow or blank in column 0
	LDA.l !S
	%tax8()
	LDA.l !LPOS,x
	CMP.l !SCR+2
	BEQ +
	LDA #$FF
	BRA ++
+	LDA #!ARROW
++	XBA
	LDA #$29
	XBA
	REP #$20
	PHA
	LDA.l !T0
	TAX
	PLA
	STA.l !BOXBUF+0,x
	SEP #$20
	LDA #$29
	STA.l !RP
	LDA.l !T3
	CMP #$02
	BEQ .item
	LDA.l !SCR+2
	JSR tl_scan             ; visible entry -> row in the game's list
	CMP #$E0
	BCC .ownrow
	JMP .propentry
.ownrow:
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
	STA.l !DI
	JSR tech_cost
	STA.l !DQ+3
	CMP #$FF
	BEQ +
	LDA.l !S                ; not enough MP: grey line
	ASL
	%tax8()
	REP #$20
	LDA.l $CCF8ED,x
	TAX
	LDA.l $7E5E34,x
	STA.l !TMP
	LDA.l !DQ+3
	AND #$00FF
	CMP.l !TMP
	SEP #$20
	BCC +
	BEQ +
	LDA #!GREY
	STA.l !RP
+	LDA #$01
	STA.l !DT
	BRA .name
.item:
	LDA.l !SCR+2
	REP #$20
	AND #$00FF
	STA.l !TMP
	ASL
	ASL
	CLC
	ADC.l !TMP              ; idx*5
	TAX
	SEP #$20
	LDA.l !ITEMLIST,x
	STA.l !DI
	LDA.l !ITEMLIST+3,x     ; quantity
	STA.l !DQ+3
	LDA #$02
	STA.l !DT
.name:
	JSR name_fetch
	REP #$20
	LDA.l !T0
	TAX
	SEP #$20
	LDA.l !RP
	XBA
	LDY #$0000
-	PHX
	TYX
	LDA.l !NM7,x
	PLX
	REP #$20
	STA.l !BOXBUF+2,x
	SEP #$20
	INX
	INX
	INY
	CPY #$0007
	BNE -
	LDA.l !DQ+3             ; MP cost / quantity in columns 8-9
	CMP #$FF
	BNE +
	JMP .nextrow
+	REP #$20
	AND #$00FF
	STA.l !NUM
	SEP #$20
	JSR digits3
	REP #$20
	LDA.l !T0
	TAX
	SEP #$20
	LDA.l !RP
	XBA
	LDA.l !DIG+1
	REP #$20
	STA.l !BOXBUF+$10,x
	SEP #$20
	LDA.l !DIG+2
	REP #$20
	STA.l !BOXBUF+$12,x
	SEP #$20
	BRA .nextrow
.propentry:                     ; a proposal: the combo (steady)
	AND #$03
	STA.l !CY
	LDA.l !BLINK
	AND #$00
	BEQ +
	LDA.l !CY
	JSR txt_name
	BRA ++
+	JSR choice_id           ; the combo's full name (7 letters)
	STA.l !DI
	LDA #$01
	STA.l !DT
	JSR name_fetch
	LDX #$0000
-	LDA.l !NM7,x
	STA.l !TXT7,x
	INX
	CPX #$0007
	BNE -
	BRA +++
++	LDX #$0000              ; the proposer's name
-	LDA.l !TXT,x
	STA.l !TXT7,x
	INX
	CPX #$0005
	BNE -
	LDA #$FF
	STA.l !TXT7+5
	STA.l !TXT7+6
+++	REP #$20
	LDA.l !T0
	TAX
	SEP #$20
	LDY #$0000
-	PHX
	TYX
	LDA.l !TXT7,x
	PLX
	XBA
	LDA #$29
	XBA
	REP #$20
	STA.l !BOXBUF+2,x
	SEP #$20
	INX
	INX
	INY
	CPY #$0007
	BNE -
.nextrow:
	LDA.l !K
	INC
	STA.l !K
	CMP #$02
	BEQ +
	JMP .row
+	JSR box_x               ; line 2: the status strip (HP, gauge, MP)
	REP #$20
	LDA #$29FF
	STA.l !BOXBUF+$100,x
	STA.l !BOXBUF+$102,x
	STA.l !BOXBUF+$104,x
	STA.l !BOXBUF+$106,x
	STA.l !BOXBUF+$108,x
	STA.l !BOXBUF+$10A,x
	STA.l !BOXBUF+$10C,x
	STA.l !BOXBUF+$10E,x
	STA.l !BOXBUF+$110,x
	STA.l !BOXBUF+$112,x
	STA.l !BOXBUF+$140,x
	STA.l !BOXBUF+$142,x
	STA.l !BOXBUF+$144,x
	STA.l !BOXBUF+$146,x
	STA.l !BOXBUF+$148,x
	STA.l !BOXBUF+$14A,x
	STA.l !BOXBUF+$14C,x
	STA.l !BOXBUF+$14E,x
	STA.l !BOXBUF+$150,x
	STA.l !BOXBUF+$152,x
	SEP #$20
	JMP draw_stats

; X = box offset for slot !S (S*20)
box_x:
	LDA.l !S
	REP #$20
	AND #$00FF
	ASL
	ASL
	STA.l !SCR+4            ; *4
	ASL
	ASL                     ; *16
	CLC
	ADC.l !SCR+4            ; *20
	TAX
	SEP #$20
	RTS


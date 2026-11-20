; =====================================================================
;  Chrono Trigger 3-player patch  (base: US 1.0 + MSU-1 patch, headerless)
;
;  Battle, milestone 3 (see menu.asm).  Milestone 2 notes:
;   * every ready character's command box shows its own hand cursor,
;     moved by that character's player at any time
;   * any player can confirm whenever their character is ready; the game
;     switches the shared menu to them (native left/right switch) and
;     confirms on the next menu tick
;   * the Tech/Item list and target picking are a LOCK: while someone is in
;     one, other players can still move their hands; a confirm waits
;     (queued) until the lock frees
;
;  Controllers: pad 1 = port 1; pads 2/3 = multitap in port 2
;  ($421A / $421E auto-read).  Ownership: slot 0 -> P1, slot 1 -> P2,
;  slot 2 -> P3; a pad joins on its first button press; unjoined slots
;  fall back (slot 2 -> P2 -> P1, slot 1 -> P1).  Solo play is unchanged.
;
;  Game facts used (found with Mesen, see notes in README):
;   $95D5  party slot whose menu is open (FF none)
;   $95DB  sub-window: 0 boxes, 1 Tech list, 2 Item list
;   $95DC+slot  top-level cursor row per slot (0 Att, 1 Tech, 2 Item)
;   $9609  target selection active
;   $A6D9+slot  = slot if that character is ready, else FF
;   $A6DD  focused slot index
;   $EE/$EF  battle menu input (EE: $80 confirm, $40 X, $08/$02 cancel;
;            EF: $08 up, $04 down, $02 left/prev, $01 right/next)
;   $0CC0  BG3 window tilemap buffer (uploaded every menu tick while the
;          boxes are shown).  Box for slot s at +s*12, rows r at +r*$80,
;          hand = tiles $160-$163 (2x2), high byte $29 = palette 2.
; =====================================================================
; base ROM: the US game + MSU-1 patch (HiROM), or Chrono Trigger Plus (CTSE
; 3.0, 6 MB ExHiROM: same engine, so the same hooks; our code and tables move
; into its free banks)
if not(defined("CTPLUS"))
	!CTPLUS = 0
endif
if !CTPLUS
	exhirom
	!CB = $500000           ; our code bank (one bank: the routines JSR each other)
	!DB2 = $510000          ; gallery + read-only tables
	!DB3 = $520000          ; more far code (aff.asm)
	!DB4 = $530000          ; and more (trail.asm)
	!DB5 = $540000          ; tag sprites + font (tagsprite.asm): free expansion
	!FSLBL = $FF3D00        ; the New Game label (must be in bank FF)
	!ITEMDESC = $ED203C     ; item description pointers (CT+ moved them)
	!ITEMDESCBANK = $ED0000
	!RAMB = $7EF700         ; our work RAM (CT+ uses 7F:5480-603F on its world map)
else
	hirom
	!CB = $DB0000
	!DB2 = $DC0000
	!DB3 = $E1F600          ; more far code (aff.asm): the free end of bank E1
	!DB4 = $E4D000          ; and more (trail.asm): free zeros in bank E4
	!DB5 = $E4E000          ; tag sprites + font (tagsprite.asm): free zeros after DB4
	!FSLBL = $FF2060
	!ITEMDESC = $CC2EB1
	!ITEMDESCBANK = $CC0000
	!RAMB = $7F5C00         ; our work RAM (7F:5480-6040 is unused by this game)
endif

; which parts to build (tools/build.sh builds all three patches):
;   WITH_3P   the 3-player mod      WITH_FMV  the video gallery
if not(defined("WITH_3P"))
	!WITH_3P = 1
endif
if not(defined("WITH_FMV"))
	!WITH_FMV = 1
endif

!ESWAP   = $7E0257      ; party slot swapped into "party member 0" for its scene (0 none)
!EOBJ    = $7E0258      ; that character's object (now in $0197)
!EACT    = $7E0259      ; the object whose scene it is
!ESEEN   = $7E025B      ; a message window has appeared during that scene
!ELX     = $7E025C      ; word: the leader's X when a player's scene began
!ELY     = $7E025E      ; word: and Y
!EL1     = $7E0287      ; the party list's 2nd / 3rd entries, kept aside
!EL2     = $7E0288      ; during the scene
!OWALIVE = $7E025A      ; set by the world-map follower hook each frame
!BOXW    = $7E063A      ; a message window was open at the start of the frame
!JOINED  = $7E02F0      ; bit1 = P2 joined, bit2 = P3 joined
!BTTL    = $7E02EF      ; battle frames-to-live (see fieldmenu.asm)
!SCR     = $7E02F8      ; 6 bytes scratch for map_pad
!PREV    = $7E02C0      ; 3 words: previous held (mapped) per player
!TIMER   = $7E02C6      ; 3 words: auto-repeat timer per player
!ACC     = $7E02CC      ; 3 words: presses accumulated since last menu tick
!PEND    = $7E02D2      ; 3 bytes: queued confirm per slot
!SAVED   = $7E02D5      ; cursor row to restore after a focus switch
!RESTORE = $7E02D6      ; slot+1 to restore (0 = none)
!HELD    = $7E02D8      ; 3 words: held (mapped) this frame per player
!F       = $7E02E1      ; focused slot (this tick)   ($02DE-$02E0 = !PID)
!S       = $7E02E2      ; loop slot
!LO      = $7E02E3      ; EE being built
!HI      = $7E02E4      ; EF being built
!T0      = $7E02E5
!T1      = $7E02E6
!PAL     = $7E02E7      ; tile high byte for the hand being drawn
!SHADOW  = $7E02E8      ; 3 bytes: each slot's cursor row at the end of the last tick
!LASTF   = $7E02EB      ; focused slot at the end of the last tick
!CTRL    = $7E02EC      ; 3 bytes: the slot each player's hand controls this tick (FF none)

!MENUSLOT = $7E95D5
!SUBWIN   = $7E95DB
!CURSOR   = $7E95DC
!TARGET   = $7E9609
!READY    = $7EA6D9
!FSFLAG   = $7F1E40      ; 1 while the file screen (New Game / saves) is up
!FSPREV   = $7F1E41      ; its last pad-1 high byte (Y edge)
!GIDX     = $7F1E42      ; the gallery's video number
!GAMEON   = $7F1E43      ; >0 while the field / world map / battle runs
!ROLE  = $7F1E4B        ; 3: the pad (0 port 1, 1/2 multitap) driving seat 0/1/2
!PJOIN = $7F1E4E        ; bit per pad: playing
!RINIT = $7F1E4F        ; $A5 once the above are set up
!PST   = $7F1E50        ; 3 per pad: 0 Ready, 1 Follow, 2 Idle
!MENUON = $7F1E53       ; 1 while the X menu is open
!PREVB = $7F1E54        ; 3 per pad: buttons (high byte) last frame, in the menu
!PRAW  = $7F1E57        ; word: the raw pad update_joined just read
!TAGF  = $7F1E59        ; 3 per slot: a tag is on that panel ("LV n" kept)
!PSEAT = $7F1E5C
!TSL   = $7F1E5D        ; draw_tags: slot
!TST   = $7F1E5E        ;   kind
!TI    = $7F1E5F        ;   tile
!TQ    = $7F1E60        ;   word temp
!PCHAR = $7F1E62        ; 3 per pad: the character it plays (FF none)
;   (Nov 17) CONTROLLERS ON ANY RETROARCH PORT: each mod pad 0-2 reads the
;   physical port !PPORT names (0 = RetroArch P1 ... 4 = P5).  Ports 4/5 are
;   read by hand (multitap with IOBit low) into !P4RAW/!P5RAW.
!P4RAW = $7F1EC0        ; word: RetroArch port 4's buttons (raw, $4218 layout)
!P5RAW = $7F1EC2        ; word: port 5's
!PPORT = $7F1EC4        ; 3: the physical port each mod pad reads
!PPSIG = $7F1EC7        ; $5A once !PPORT is set up
!PTPREV = $7F1ECA       ; 5 words: each port's buttons last frame
!P45AGE = $7F1ED4       ; frames the port 4/5 copies stay good
!XSL   = $7F1ED5        ; claim_at: the party slot to claim
!XNEW  = $7F1ED8        ; word: new presses (temp)
!XT    = $7F1EDA        ; temp (word)
!R45F  = $7F1EDC        ; battle: ports 4/5 read every 4th frame (for Start)
!PZSIG = $7F1EB9        ; the pause panel's checksum when last drawn
!PZON  = $7F1EBA        ; 1 = the pause panel is on screen
!PZDP  = $7F1EBB        ; anyone's left/right last frame (the picker)
!PZCUR = $7F1EBC        ; the picker: party slot
!TDIG  = $7F1E65        ; draw_tags: controller number
!RNR   = $7F1E66        ; 3: claims_update's new seats (was the idle timer)
!RUSE  = $7F1E69        ;    pads taken
!RCS   = $7F1E6A        ;    seat
!RCP   = $7F1E6B        ;    pad
!RCC   = $7F1E6C        ;    character
!CDIRTY = $7F1E6D       ; 1: the seats must be rebuilt
!LPA0  = $7F1E6E        ; the party order they were built for
!LPA1  = $7F1E6F
!LPA2  = $7F1E70
!TAGB  = $7F1E78        ; 18: kept "LV n" tiles, 6 per slot
!CMASK = !RAMB+$C2        ; 2: combo_pads (partner mask, slot)
!FWORK = $7F1F00        ; 2 x 48: each free follower's own movement working bytes
!FWT   = $7F1EA4        ; word temp
!JCNT  = $7F1EAA        ; 3: frames each pad has held a real press
!PCO   = $7F1EAD        ; 3: party objects locked by pc_lock_l (FF none)
!PCL   = $7F1EB0        ; 3: their $1000 before
!EQ    = $7F1EB6        ; quiet frames: scene character free, no window
!EWLK  = $7F1EB7        ; its walk op ran since the last scene_end
!CMS   = $7F1F80        ; Comb panel: slot+1 that has it open (0 none)
!CMN   = $7F1F81        ;   combos listed
!CMPOS = $7F1F82        ;   cursor
!CMTOP = $7F1F83        ;   first line shown
!CMK   = $7F1F84        ;   temps
!CMI   = $7F1F85
!CMQ   = $7F1F86        ;   1 = store the list
!CMR   = $7F1F87
!CMV   = $7F1F88
!CMT   = $7F1F89        ;   word temp
!DBUF  = $7F1FA0        ; 48: a move description, unpacked (far2.asm)
!CML   = $7F1F90        ; 16: the listed combos' rows in the game's tech list
!ETIM  = $7F1EB4        ; word: quiet frames in a player scene after its window
!DSTV  = $7F1EA9        ; frames the sprite-frame queue has waited (far.asm)
!FSTEP = $7F1EA8        ; 1 while a free follower's step runs (field.asm)
!SPLAST = $7F1EA6       ; word: script_pads' buttons last frame
!FANIM = $7F1E9C        ; 2 x 4: each free follower's own animation timers ($0158, $06AF)
!S7ON  = $7F1E99        ; the game's target picker is open for a replay (step 7)
!S7M   = $7F1E9A        ; word: buttons held when it opened (ignored until let go)
!VCNT  = $7F1E71        ; word: ow_vote's count of agreeing votes
!SPE   = $7F1E73        ; word: ow_keep's leader exit
!SPN   = $7F1E75        ; same_place: name, x, y
!SPX   = $7F1E76
!SPY   = $7F1E77
!BOXBUF   = !RAMB+$100      ; the boxes are drawn here (same layout as the game's panel)

!HANDPAL_FOCUS = $29    ; palette 2 (white), as the game draws it
!HANDPAL_OTHER = $2D    ; palette 3 (grey)

macro tax8()
	REP #$20
	AND #$00FF
	TAX
	SEP #$20
endmacro

if !WITH_3P
; --- hook 1: battle input handler CD:0348 "LDA $F8 / STA $CC99" (5 bytes)
org $CD0348
	JSL battle_input
	NOP

; --- hook 2: battle menu tick C1:1153 "JSL $CFFAE2" (4 bytes)
org $C11153
	JSL menu_pre

; --- hook 2b: the battle menu's tick sound C1:1B55 "STZ $1E01 / LDA #$19" (5
; bytes): silent while the replay presses buttons in the hidden menu - the
; players hear their OWN presses instead (box_snd_l, trail.asm)
org $C11B55
	JSL menu_snd_l
	NOP
warnpc $C11B5A

; --- hook 3: battle NMI, just before the sprite table upload, CF:E300 "TDC / STA $004370" (5 bytes)
org $CFE300
	JSL oam_inject
	NOP

; --- hook 4: battle NMI, the sprite DMA start CF:E32E "LDA #$80 / STA $00420B" (6 bytes)
org $CFE32E
	JSL oam_after
	NOP
	NOP

; --- main menu: a tab switch keeps the main page's character (fieldmenu.asm)
org $C29A45
	JSL tab_set
	NOP
	NOP
org $C29A53
	JSL tab_cur
	NOP
	NOP

; --- the field menu's own main loop (STZ $0D01 / BRA, identical in CT and CT+):
; run the mod's menu input (claims, tags, ports 4/5) HERE, once a frame after
; the game drew, instead of in the NMI.  ctl_menu2_l does the replaced
; STZ $0D01 and loops back to $C281B9.
org $C281E3
	JML ctl_menu2_l
	NOP
warnpc $C281E8

; --- hook 5: battle NMI, the panel upload's source CF:E346 (21 bytes)
org $CFE346
	JSL panel_src
	NOP #17

; --- hook 7 (Nov 17): the battle pause (D1:E81E "LDA $4219 / AND #$10",
; port 1's Start only) -> any controller's Start, RetroArch ports 1-5
org $D1E81E
	JSL any_start_l         ; (ctlports.asm; Z from AND #$10, as before)
	NOP #2
warnpc $D1E824

; --- hook 6: battle NMI, the window frame upload's source CF:E390 (18 bytes)
org $CFE390
	JSL frame_src
	NOP #14

; ---------------------------------------------------------------------
org !CB|$C800
; =====================================================================
; every frame: read all pads, keep per-player presses, feed the game the
; focused player's held buttons
battle_input:
	PHP
	SEP #$20
	LDA #$00                ; (gameplay: not on the file screen)
	STA.l !FSFLAG
	LDA #$08
	STA.l !GAMEON
	LDA #$00                ; (no follower steps in battle)
	STA.l !FSTEP
	REP #$30
	PHX
	PHY
	JSR wait_autoread
	JSL ctl_battle_l        ; ports 4/5, Select = next character (ctlports.asm)
	JSR update_joined       ; (the shared joypad routine runs only now and then in battle)
	SEP #$20
	LDA #$02
	STA.l !BTTL             ; tell the shared joypad routine we're in battle
	REP #$20
	JSR p1_pad              ; the leader's pad, read directly like P2/P3 (the game's
	JSR map_pad             ; own copy at $F8 isn't refreshed every frame in battle)
	LDX #$0000
	JSR do_player
	JSR rec_x               ; X held (the description button)
	SEP #$20
	LDA #$01
	JSR seat_raw            ; player 2's controller
	JSR map_pad
	LDX #$0002
	JSR do_player
	JSR rec_x               ; X held (the description button)
	SEP #$20
	LDA #$02
	JSR seat_raw            ; player 3's controller
	JSR map_pad
	LDX #$0004
	JSR do_player
	JSR rec_x               ; X held (the description button)
	SEP #$20
	JSR ptr_update
	REP #$20
	; return the held buttons of whoever owns the open menu
	SEP #$20
	LDA.l !MENUSLOT
	BPL +
	LDA #$00
+	JSR owner
	REP #$20
	AND #$00FF
	ASL
	TAX
	LDA.l !HELD,x
	PHA
	JSR combo_pads          ; (a combo being aimed: its partners' buttons too)
	JSR picker_fresh        ; (the game's picker hears only fresh presses)
	PLA
	JSL pad_gate_l          ; what the game itself may hear (aff.asm)
	STA $CC99               ; same store as the original (DB unchanged)
	PLY
	PLX
	PLP
	RTL

; X = player*2, A(16) = mapped held.  Updates HELD, ACC (with auto-repeat), PREV.
do_player:
	STA.l !HELD,x
	LDA.l !PREV,x
	EOR #$FFFF
	AND.l !HELD,x
	STA.l !SCR+4            ; newly pressed
	LDA.l !PREV,x
	AND.l !HELD,x
	BEQ .reset
	LDA.l !TIMER,x
	DEC
	STA.l !TIMER,x
	BNE .acc
	LDA #$0001
	STA.l !TIMER,x
	LDA.l !HELD,x           ; auto-repeat: the d-pad only (a held confirm must
	AND.w #$0F00            ; not also pick the next step, e.g. the target)
	ORA.l !SCR+4
	STA.l !SCR+4
	BRA .acc
.reset:
	LDA #$000F
	STA.l !TIMER,x
.acc:
	LDA.l !SCR+4
	ORA.l !ACC,x
	STA.l !ACC,x
	LDA.l !HELD,x
	STA.l !PREV,x
	RTS


incsrc "menu.asm"

; ---------------------------------------------------------------------
; helpers (A 8-bit, X 16-bit)

; A = slot -> A = owning player (0..2)
owner:
	CMP #$00
	BEQ .p0
	CMP #$01
	BNE .s2
	LDA.l !JOINED
	AND #$02
	BEQ .p0
	LDA #$01
	RTS
.s2:
	LDA.l !JOINED
	AND #$04
	BEQ +
	LDA #$02
	RTS
+	LDA.l !JOINED
	AND #$02
	BEQ .p0
	LDA #$01
	RTS
.p0:
	LDA #$00
	RTS

; A = slot -> A = next ready slot after it (cyclic), or itself if none
next_ready:
	STA.l !T1
	LDY #$0003
-	INC
	CMP #$03
	BNE +
	LDA #$00
+	%tax8()
	PHA
	LDA.l !READY,x
	BMI +
	PLA
	RTS
+	PLA
	DEY
	BNE -
	LDA.l !T1
	RTS

; A = slot -> A = previous ready slot (cyclic), or itself if none
prev_ready:
	STA.l !T1
	LDY #$0003
-	DEC
	BPL +
	LDA #$02
+	%tax8()
	PHA
	LDA.l !READY,x
	BMI +
	PLA
	RTS
+	PLA
	DEY
	BNE -
	LDA.l !T1
	RTS


; =====================================================================
; pads 2/3 and button mapping (A 16-bit)
wait_autoread:
	SEP #$20
-	LDA.l $004212
	AND #$01
	BNE -
	REP #$20
	RTS

; ---------------------------------------------------------------------
; Seats.  Player 2 and player 3 each read one of the two multitap
; controllers ($421A = pad 0, $421E = pad 1); !PMAP = 1 swaps them.
; A controller that comes back as the other number after a disconnect
; (RetroArch hands a reconnected pad the free slot) takes its seat back:
; when a controller that isn't joined starts pressing while the other seat
; is joined and its controller has been silent for 4 s, the two swap.
!PMAP = $7E05EF         ; 0: P2 = pad 0, P3 = pad 1;  1: swapped
!PSIL = $7E0608         ; 2: frames each pad has been silent (max 255)
!SIG3P = $7E060A        ; word: "3P" once our RAM is initialised

; (seat_raw, pad_raw and update_joined: see the claims code in ow.asm)

; Event scripts test buttons (C0:66A5-6717: "if button held") through
; $F8/$F9 and $F2, which only hold pad 1.  Those reads now go to copies built
; here from all three pads, so minigames and "press a button" moments answer
; to every player.
!MF8 = $7E0631          ; word, like $F8/$F9 (mapped buttons / d-pad held)
!MF2 = $7E0633          ; like $F2 (A X L R B Y Select Start held)
!MF0 = $7E0634          ; new presses, $F2 layout   (the field latches these
!MF6 = $7E0635          ; new presses, $F8 layout    into $51 / $50 for scripts)
; a scene player 2/3 started runs with their character as "party member 0"
; (field.asm fol_act swaps the party list $0197/$0199/$019B).  It ends when
; the object is idle again ($1C00 >= 2) and no message window is open; then
; the list is swapped back - unless the map was rebuilt meanwhile.
scene_end:
	PHP
	SEP #$20
	REP #$10
	LDA.l !ESWAP
	BNE +
	STA.l !ETIM             ; (no scene: the quiet timers stay at 0)
	STA.l !ETIM+1
	STA.l !EQ
	JMP .done
+	LDA.l !EWLK             ; the scene's character wasn't free this frame
	BNE +                   ; (a script moves it): the quiet count restarts
	STA.l !EQ
+	LDA #$00
	STA.l !EWLK
	LDA.l !BTTL             ; in battle: wait
	BNE .done
	LDA.l !OWALIVE          ; on the world map: the map was rebuilt, drop it
	BEQ +
	DEC
	STA.l !OWALIVE
	BRA .drop
+	REP #$20
	LDA.l $000134           ; (remember that the scene showed a message:
	SEP #$20                ; a window waiting for a button)
	BEQ +
	LDA #$01
	STA.l !ESEEN
	LDA #$00                ; (a window is up: the quiet timer restarts)
	STA.l !ETIM
	STA.l !ETIM+1
	BRA ++
+	LDA.l !ESEEN            ; its window came and went: count the quiet
	BEQ ++                  ; frames since - 20 s with nothing = it's over
	REP #$20                ; (an object that never goes idle must not
	LDA.l !ETIM             ; freeze the party for good)
	INC
	STA.l !ETIM
	CMP.w #1200
	SEP #$20
	BCS .idle
++	LDA.l !EACT
	%tax8()
	LDA.l $7E1100,x         ; the object is gone (a picked-up tab...): it
	BMI .idle               ; will never be idle again - the scene is over
	LDA.l $7E1C00,x         ; the object still running that scene?
	CMP #$02
	BCC .done
.idle:
	REP #$20
	LDA.l $000134           ; a window still up?
	SEP #$20
	BNE .done
	JSR scene_back
	BRA .done
.drop:
	LDA #$00
	STA.l !ESWAP
.done:
	PLP
	RTS

; end a player's scene: swap the party list back (if it's still ours)
scene_back:
	PHP
	SEP #$20
	REP #$10
	LDA.l $000197
	CMP.l !EOBJ
	BEQ +
	JMP .end
+	JSR party_scan          ; the list rebuilt from the party itself
	LDA.l $000197
	BPL +
	JMP .end
+	; the scene regrouped everyone on its player: the leader (and whoever just
	; follows him) goes back where he stood
	%tax8()
	REP #$20
	LDA.l !ELX
	STA.l $7E1800,x
	LDA.l !ELY
	STA.l $7E1880,x
	SEP #$20
	LDA #$00
	STA.l $7E1900,x
	STA.l $7E1980,x
	LDA.l !ESWAP            ; the player who did the scene stays where it
	DEC                     ; left them, walking freely
	%tax8()
	LDA #$01
	STA.l $7E05F8,x         ; (field.asm !FMODE)
	LDA #$00
	STA.l $7E05FA,x         ; (!FOFF)
	TXA                     ; where the scene left them is where they are now
	ASL                     ; (not a "new map" jump): !FPX / !FPY
	TAY
	LDA.l !EOBJ
	%tax8()
	REP #$20
	LDA.l $7E1800,x
	TYX
	STA.l $7E0600,x
	LDA.l !EOBJ
	AND #$00FF
	TAX
	LDA.l $7E1880,x
	TYX
	STA.l $7E0604,x
	SEP #$20
	JSL trail_back_l        ; followers walk back to the leader (aff.asm)
	BCC .end
	LDA #$01                ; (too far for a trail: put them with him)
	JSR scene_fol
	LDA #$02
	JSR scene_fol
.end:
	LDA #$00
	STA.l !ESWAP
	PLP
	RTS

; rebuild the party list $0197/$0199/$019B from the objects' own party
; positions ($1100,obj: 0 leader, 1, 2; others aren't party members)
party_scan:
	PHP
	SEP #$20
	REP #$30
	SEP #$20
	LDA #$80
	STA.l $000197
	STA.l $000199
	STA.l $00019B
	LDX #$0000
-	LDA.l $7E1100,x
	CMP #$03
	BCS +
	ASL
	PHX
	REP #$20
	AND #$00FF
	TAY
	SEP #$20
	PLX
	TXA
	STA $0197,y             ; (DB = $00 here)
+	INX
	INX
	CPX #$0080
	BNE -
	PLP
	RTS

; A = party position: if that member just follows, put it with the leader
; again (and restart its trail there)
scene_fol:
	STA.l !CX
	ASL
	%tax8()
	LDA.l $000197,x
	BMI .no                 ; (nobody there)
	PHA
	LDA.l !CX
	JSR owner
	CMP.l !CX
	BNE .put                ; nobody plays it: a follower
	LDA.l !CX
	DEC
	%tax8()
	LDA.l $7E05F8,x         ; (field free-walk mode, field.asm !FMODE)
	BEQ .put
	PLA
.no:
	RTS
.put:
	PLA
	%tax8()
	REP #$20
	LDA.l !ELX
	STA.l $7E1800,x
	LDA.l !ELY
	STA.l $7E1880,x
	SEP #$20
	LDA #$00
	STA.l $7E1900,x
	STA.l $7E1980,x
	LDA.l $0001AB           ; its trail starts here
	STA.l $0001AC
	STA.l $0001AD
	RTS

; the main menu opens on the character of whoever pressed X: !OPENER = the
; party slot of the last player holding X (player 2 -> slot 1, player 3 ->
; slot 2; slot 0 when that slot is empty).  C2:99EA reads it (script.asm).
!OPENER = $7E063B
track_opener:
	SEP #$20
	LDA #$00                ; the leader's pad
	JSR seat_raw
	AND.w #$0040
	SEP #$20
	BEQ +
	LDA #$00
	BRA .set
+	LDA #$01
	JSR seat_raw
	AND #$0040
	SEP #$20
	BEQ +
	LDA #$01
	BRA .slot
+	LDA #$02
	JSR seat_raw
	AND #$0040
	SEP #$20
	BEQ .done
	LDA #$02
.slot:
	STA.l !OPENER
	PHX
	%tax8()
	LDA.l $7E2980,x         ; nobody in that slot: the leader's page
	PLX
	BPL .done
	LDA #$00
.set:
	STA.l !OPENER
.done:
	RTS

; A(8) = seat 1/2 -> A(8) = its JOINED bit (2 / 4)
seat_bit:
	ASL
	RTS

; raw auto-read word -> the game's mapped layout (like $F8/$F9)
;   scratch: +0/+1 raw, +2 game lo, +3 mask, +4 out lo, +5 out hi
map_pad:                        ; (the work: trail.asm mp_body)
	JSL map_pad_l
	RTS

warnpc !CB|$EB00           ; the battle code must end before the world-map code

; the hold-X description code sits in the free space just below (same bank)
org !CB|$C410
incsrc "desc.asm"
warnpc !CB|$C760
org !CB|$C760
incsrc "cmbridge.asm"
warnpc !CB|$C800
endif

; VIDEOS: the MSU1 patch this ROM is built on (qwertymodo's all-FMV beta)
; already plays the anime cutscenes from "Chrono Trigger 3P.msu": video n
; (sound: track 100+n) through its player at CD:FA00 - video 0 at the
; title, the others from the story scripts.  fmv/encode.py builds that file
; from the PlayStation videos.
;
; VIDEO GALLERY: hold L+R while the game starts (power on or reset) to watch
; every video in turn; Start (or B) skips one.  Then the game starts as usual.
if !WITH_FMV
!GALLERY_N = 10
org $C0FF03
	JML gallery_boot        ; (was JML $FDC000, the patch's start-up)
; the player's skip button: Start (original) / B (CT+) -> either one
if !CTPLUS
org $CDFD3C
	BIT #$90                ; (was BIT #$80, B)
else
org $CDFD58
	BIT #$90                ; (was BIT #$10, Start)
endif
org !DB2|$E000
gallery_boot:
	REP #$10                ; as FD:C000 sets up
	SEP #$20
	LDX #$06FF
	TXS
	LDA #$00
	PHA
	PLB
	LDA #$01                ; read the pads once
	STA $4200
-	LDA $4212               ; (wait for a vblank, for the read to start, and
	BPL -                   ; for it to finish)
-	LDA $4212
	AND #$01
	BEQ -
-	LDA $4212
	AND #$01
	BNE -
	LDA $4218
	AND #$30                ; L and R
	CMP #$30
	BNE gallery_boot_end
	LDA #$00
gallery_boot_next:
	STA.l !GIDX
	STA.l $7F004F           ; (the original player reads it here, CT+'s in A)
	JSL $CDFA00             ; play video n (carry set: none, or no data file)
	SEP #$20
	REP #$10
	LDA #$01                ; one Start press skips one video: wait for it
	STA $4200               ; to be let go before the next one starts
gallery_boot_rel:
-	LDA $4212
	BPL -
-	LDA $4212
	AND #$01
	BEQ -
-	LDA $4212
	AND #$01
	BNE -
	LDA $4219
	AND #$90                ; (Start or B)
	BNE gallery_boot_rel
	LDA.l !GIDX
	INC
	CMP #!GALLERY_N
	BNE gallery_boot_next
gallery_boot_end:
	STZ $4200
	SEP #$30
	JML $FDC000             ; the normal start-up

; the same from the file screen: Y plays every video, then back to the title
gallery_menu:
	SEI
	REP #$10
	SEP #$20
	LDA #$00
	PHA
	PLB
	STA.l !FSFLAG
	JMP gallery_boot_next   ; (from video 0)

; C2:EF52 "LDA $FFC457,X" - the file screen's strings (A/X 16-bit, X = id*2):
; "New Game" becomes "New Game (Y:FMV)" and marks the file screen as up
fs_str:
	CPX #$002A              ; New Game
	BEQ .ng
	CPX #$0024              ; ids $12..$17 are the rest of this screen
	BCC .other
	CPX #$0030
	BCS .other
	LDA.l $FFC457,x
	RTL
.ng:
	SEP #$20
	LDA #$01
	STA.l !FSFLAG
	REP #$20
	LDA.w #fs_label&$FFFF
	RTL
.other:
	SEP #$20                ; another screen's text: not the file screen
	LDA #$00
	STA.l !FSFLAG
	REP #$20
	LDA.l $FFC457,x
	RTL

; pad_merge (every pad read in menus): a new Y press on the file screen
fs_check:
	PHP
	SEP #$20
	LDA.l $004219           ; any controller's Y
	ORA.l $00421B
	ORA.l $00421F
	PHA
	LDA.l !FSPREV
	EOR #$FF
	AND 1,s
	AND #$40                ; Y, newly pressed
	STA 1,s
	LDA.l $004219
	ORA.l $00421B
	ORA.l $00421F
	STA.l !FSPREV
	PLA                     ; Y newly pressed?
	BEQ +
	LDA.l !FSFLAG
	BEQ +
	JML gallery_menu
+	PLP
	RTL
warnpc !DB2|$E600

org !FSLBL                     ; (free) the file screen's New Game label
fs_label:
	db $0A,$20,$AD,$BE,$D0,$FF,$A6,$BA,$C6,$BE   ; New Game
	db $FF,$E5,$B8,$E3,$A5,$AC,$B5,$E6,$00       ;  (Y:FMV)
org $C2EF52
	JSL fs_str
if !WITH_3P == 0
	incsrc "fmv_only.asm"
endif
if !CTPLUS
	incsrc "ctp_fmv.asm"    ; CT+: the cutscenes in the story too
endif
endif

; read-only tables (read with long addressing) live in the free end of bank DC
if !WITH_3P
org !DB2|$E600
incsrc "names.asm"
incsrc "frame10.asm"
warnpc !DB2|$F000
org !DB2|$E100             ; (free: after the gallery code, before the name tables)
incsrc "far2.asm"
warnpc !DB2|$E480
org !DB2|$E480
incsrc "frame_solid.asm"
warnpc !DB2|$E600
warnpc !DB2+$10000
org !DB3
incsrc "aff.asm"
warnpc !DB3+$A00
org !DB4
incsrc "trail.asm"
warnpc !DB4+$1000

incsrc "fieldmenu.asm"
incsrc "field.asm"
incsrc "ow.asm"
incsrc "script.asm"
incsrc "far.asm"
org !DB5
incsrc "tagsprite.asm"
warnpc !DB5+$800
endif


; =====================================================================
; CONTROLLERS ON ANY RETROARCH PORT + the battle CONTROLLERS PANEL (Nov 17)
;   RetroArch numbers controllers in the order they first press a button,
;   and gives one that Android re-registers (Bluetooth, the Odin's mapping
;   service) the next free number - so a player can land on port 4 or 5,
;   which the mod never read: their character went dead.
;   * ports 4/5 are read by hand each frame (multitap, IOBit low)
;   * each mod pad 0-2 reads the physical port in !PPORT (was fixed 1-3)
;   * battle: START on any controller opens the Controllers panel (the
;     battle waits): left/right = character, SELECT = "this one is mine",
;     B / START = close.  X menu main page: SELECT from any port claims
;     (Y now cycles Ready / Follow / Idle).
;   A port no mod pad reads takes over the pad that drives the character,
;   so claims, Follow/Idle and colours all carry over.
;   (included from trail.asm's bank)
; =====================================================================
assert !P4RAW == $7F1EC0
assert !P5RAW == $7F1EC2

; X(16) = port 0-4 -> A(16) = its buttons ($4218 layout).  m = 16.
port_raw:
	CPX.w #$0001
	BEQ .p1
	CPX.w #$0002
	BEQ .p2
	CPX.w #$0003
	BEQ .p3
	CPX.w #$0004
	BEQ .p4
	LDA.l $004218
	RTS
.p1:	LDA.l $00421A
	RTS
.p2:	LDA.l $00421E
	RTS
.p3:	LDA.l !P4RAW
	RTS
.p4:	LDA.l !P5RAW
	RTS

; (m = 8) !PPORT set up once: power-on, or a save state from before
pp_check:
	LDA.l !PPSIG
	CMP #$5A
	BEQ +
	LDA #$00
	STA.l !PPORT
	INC
	STA.l !PPORT+1
	INC
	STA.l !PPORT+2
	LDA #$5A
	STA.l !PPSIG
+	RTS

; ow.asm pad_raw / far.asm pad_raw_f: A(8) = mod pad 0-2 -> A(16) = the
; buttons of the port it reads.
; Leaves m = 16, flags from A, X kept.
praw_l:
	PHP
	REP #$10
	PHX
	SEP #$20
	PHA
	JSR pp_check
	PLA
	REP #$20
	AND.w #$0003
	TAX
	SEP #$20
	LDA.l !BTTL             ; a battle, paused: the controllers panel has
	BEQ +                   ; the buttons (the boxes underneath must not
	LDA.l $7ECD02           ; move or commit anything)
	AND #$01
	BEQ +
	REP #$20
	LDA.w #$0000
	BRA ++
+	LDA.l !PPORT,x
	REP #$20
	AND.w #$0007
	TAX
	JSR port_raw
++	PLX
	PLP
	REP #$20
	ORA.w #$0000
	RTL

; A(8) = mod pad -> A(8) = the port it reads (0-4).  X kept.
lport_l:
	PHX
	PHP
	REP #$30
	AND.w #$0003
	TAX
	SEP #$20
	JSR pp_check
	LDA.l !PPORT,x
	PLP
	PLX
	RTL

; read ports 4/5 now (after the auto-read).  Every register kept.
r45_now:
	PHP
	PHB
	REP #$30
	PHA
	PHX
	SEP #$20
	LDA #$7F
	PHA
	PLB
-	LDA.l $004212
	AND #$01
	BNE -
	LDA #$01                ; latch
	STA.l $004016
	DEC
	STA.l $004016
	LDA #$7F                ; IOBit low: the multitap answers with pads 4/5
	STA.l $004201
	REP #$20                ; 16 bits, B first: D0 = port 4, D1 = port 5
	!r45 = 0                ; (unrolled, 16-bit: the high byte read is $4018,
	while !r45 < 16         ; which has no side effect; all 16 shifts push
		LDA.l $004017   ; the old value out)
		LSR
		ROL.w $1EC0
		LSR
		ROL.w $1EC2
		!r45 #= !r45+1
	endwhile
	SEP #$20
	LDA #$FF                ; IOBit back high (the game's own value)
	STA.l $004201
	LDA #$05
	STA.l !P45AGE
	REP #$30
	PLX
	PLA
	PLB
	PLP
	RTS

; main loop: read only clear of the auto-read (it starts at line 225 and
; must never run while IOBit is low).  Every register kept.
r45_main:
	PHP
	REP #$20
	PHA
	SEP #$20
	LDA.l $00213F           ; (resets the counter read order)
	LDA.l $002137           ; latch the beam position
	LDA.l $00213D
	XBA
	LDA.l $00213D
	AND #$01
	XBA
	REP #$20
	CMP.w #200              ; lines 200-226 could run into the auto-read
	BCC .go                 ; (it starts early in line 225); from 227 on it
	CMP.w #227              ; has started or finished - r45_now waits for it
	BCC +
.go:
	JSR r45_now
+	PLA
	PLP
	RTS

; field_tick / ow_tick (main loop, top of frame)
ctl_field_l:
	PHP
	REP #$20
	PHA
	SEP #$20
	JSR pp_check
	JSR need45              ; someone plays on port 4/5: every frame;
	BCS .rd                 ; otherwise every 4th (their X opens the menu -
	LDA.l !R45F             ; a press lasts longer than that)
	INC
	STA.l !R45F
	AND #$03
	BNE +
.rd:
	JSR r45_main
+	REP #$20
	PLA
	PLP
	RTL

; carry set = a mod pad reads port 4 or 5 (m 8)
need45:
	LDA.l !PPORT
	CMP #$03
	BCS +
	LDA.l !PPORT+1
	CMP #$03
	BCS +
	LDA.l !PPORT+2
	CMP #$03
+	RTS

; the field menu's own main loop ($C281E3, identical in CT and CT+): once a
; frame, AFTER the game has drawn this frame's panels and BEFORE the next NMI
; uploads them.  Read ports 4/5 and run the claim/tag code here, not in the
; NMI: in the NMI it delayed the screen-on (black bar) and raced the game's
; panel draw (a stat line squashed on a click).
ctl_menu2_l:
	PHB
	PHD
	PHP
	REP #$30
	PEA $0000
	PLD                     ; DP = 0
	SEP #$20
	LDA #$7E
	PHA
	PLB                     ; DB = $7E
	JSR pp_check
	JSR r45_main            ; ports 4/5, main-loop safe (no vblank busy-wait)
	JSL menu_modes_l        ; Select = claim, Y = cycle, and the tags
	SEP #$20
	LDA #$00
	STA.l $7E0D01           ; the instruction we replaced (clear the vblank flag)
	PLP
	PLD
	PLB
	JML $C281B9             ; back into the menu's main loop

; fieldmenu.asm pad_merge (NMI, after the auto-read): the X menu reads
; ports 4/5 here; elsewhere the main-loop copies age out (never stale)
p45_nmi_l:
	PHP
	SEP #$20
	PHA
	LDA.l !MENUON
	BEQ +
	LDA.l $7E0D10           ; in the menu, the claim/tag/read work runs from the
	BEQ .out                ; menu's own main loop (ctl_menu2_l), NOT here.  All
	JSR font_load           ; (force-blank window: load the tag sprite font once)
	LDA.l $7E0D10
	STA.l $002100           ; that's left here is turning the screen on early
	BRA .out                ; (brightness $7E0D10): our pad-merge runs before the
				; game's own screen-on, so without this the top of the
				; menu renders black.  Safe now - no heavy work follows.
+	LDA.l !P45AGE
	BEQ .out
	DEC
	STA.l !P45AGE
	BNE .out
	LDA #$00
	STA.l !P4RAW
	STA.l !P4RAW+1
	STA.l !P5RAW
	STA.l !P5RAW+1
.out:
	PLA
	PLP
	RTL

; A(8) = physical port, !XSL = party slot: that controller plays the
; character there.  A port no mod pad reads takes over the pad driving
; that character.  (m 8, x 16)
assign:
	STA.l !XNEW
	LDX.w #$0000
-	LDA.l !PPORT,x
	CMP.l !XNEW
	BEQ .have
	INX
	CPX.w #$0003
	BNE -
	LDA.l !XSL
	REP #$20
	AND.w #$0003
	TAX
	SEP #$20
	LDA.l $7E2980,x
	BMI .no
	LDA.l !ROLE,x
	REP #$20
	AND.w #$0003
	TAX
	SEP #$20
	LDA.l !XNEW
	STA.l !PPORT,x
.have:
	JSL claim_at_l          ; (far.asm: join + claim, swapping with the old owner)
.no:
	RTS

; (m 8, x 16) -> A = the ports (bit n = port n) whose Select was
; newly pressed this frame, Z from A.  Held state kept in !PTPREV (a
; byte).  Nobody holding Select (nearly every frame): one quick test.
sel_edges:
	LDA.l $004219
	ORA.l $00421B
	ORA.l $00421F
	ORA.l !P4RAW+1
	ORA.l !P5RAW+1
	AND #$20
	BNE .some
	STA.l !PTPREV
	RTS
.some:
	LDA #$00                ; B collects "Select held", port 4 first
	XBA
	LDA.l !P5RAW+1
	AND #$20
	CMP #$20
	XBA
	ROL
	XBA
	LDA.l !P4RAW+1
	AND #$20
	CMP #$20
	XBA
	ROL
	XBA
	LDA.l $00421F
	AND #$20
	CMP #$20
	XBA
	ROL
	XBA
	LDA.l $00421B
	AND #$20
	CMP #$20
	XBA
	ROL
	XBA
	LDA.l $004219
	AND #$20
	CMP #$20
	XBA
	ROL                     ; A = held mask
	PHA
	LDA.l !PTPREV
	EOR #$FF
	AND 1,s
	STA.l !XNEW
	PLA
	STA.l !PTPREV
	LDA.l !XNEW
	RTS

; battle_input, every frame after the auto-read.  While the battle is
; PAUSED (RetroArch P1's Start - the game's own pause), SELECT on any
; controller = play the next character (nothing drawn: the hands' colours
; show who plays whom).  Ports 4/5 are read every frame only when someone
; plays on them, and during the pause (so a newcomer there can claim).
ctl_battle_l:
	PHP
	REP #$30
	PHA
	PHX
	PHY
	SEP #$20
	JSR pp_check
	LDA.l $7ECD02           ; the battle is paused (P1's Start): the
	AND #$01                ; controller menu
	BNE .menu
	JSR need45              ; someone plays on port 4/5: read them every
	BCS .rd                 ; frame; otherwise every 4th (anyone's Start
	LDA.l !R45F             ; pauses - a press lasts longer than that)
	INC
	STA.l !R45F
	AND #$03
	BNE +
.rd:
	JSR r45_main
+	LDA #$1F                ; (a Select held into the pause doesn't count)
	STA.l !PTPREV
	LDA #$00                ; (the next pause draws its panel afresh,
	STA.l !PZON             ; its picker on the leader)
	STA.l !PZCUR
	BRA .out
.menu:
	JSR pz_show             ; the controllers panel on screen (first: vblank)
	JSR r45_main
	JSR pz_pick             ; anyone's left/right moves the picker
	JSR sel_edges
	BEQ .out
	STA.l !XT+1
	LDA #$00
	STA.l !XT
.port:
	LDA.l !XT+1
	LSR
	STA.l !XT+1
	BCC +
	LDA.l !PZCUR            ; Select: this controller plays the picked one
	STA.l !XSL
	LDA.l !XT
	JSR assign
+	SEP #$20
	LDA.l !XT
	INC
	STA.l !XT
	CMP #$05
	BNE .port
.out:
	REP #$30
	PLY
	PLX
	PLA
	PLP
	RTL

; paused: the picker.  Any controller's left / right (new presses of
; them all combined, like the X menu) moves it to the next character.
; (m 8, x 16)
pz_pick:
	LDA.l $004219
	ORA.l $00421B
	ORA.l $00421F
	ORA.l !P4RAW+1
	ORA.l !P5RAW+1
	AND #$03                ; left / right held
	PHA
	LDA.l !PZDP
	EOR #$FF
	AND 1,s
	STA.l !XNEW             ; newly pressed
	PLA
	STA.l !PZDP
	LDA.l !XNEW
	AND #$02
	BEQ +
	LDA #$FF                ; left
	BRA .mv
+	LDA.l !XNEW
	AND #$01
	BEQ .fix
	LDA #$01                ; right
.mv:
	JSR pz_step
	RTS
.fix:
	LDA #$00                ; (stay put, but never on an empty slot)
; A(8) = -1 / 0 / +1: move the picker (0: only off an empty slot)
pz_step:
	PHA
	LDY.w #$0004
-	LDA.l !PZCUR
	CLC
	ADC 1,s
	BPL +
	LDA #$02
+	CMP #$03
	BCC +
	LDA #$00
+	STA.l !PZCUR
	REP #$20
	AND.w #$0003
	TAX
	SEP #$20
	LDA.l $7E2980,x
	BPL .ok
	LDA 1,s                 ; empty: keep going that way (right if staying)
	BNE +
	LDA #$01
	STA 1,s
+	DEY
	BNE -
.ok:
	PLA
	RTS

; far.asm menu_modes (X menu main page, NMI): SELECT from a port no mod
; pad reads claims the highlighted character (mod pads: menu_modes itself)
ctl_menu_l:
	PHP
	REP #$30
	PHA
	PHX
	PHY
	SEP #$20
	JSR pp_check
	JSR sel_edges
	BEQ .out
	STA.l !XT+1
	LDA #$00
	STA.l !XT
.port:
	LDA.l !XT+1
	LSR
	STA.l !XT+1
	BCC .next
	LDX.w #$0000            ; a port a mod pad reads: menu_modes did it
-	LDA.l !PPORT,x
	CMP.l !XT
	BEQ .next
	INX
	CPX.w #$0003
	BNE -
	LDA.l $7E0412
	CMP #$03
	BCS .next
	STA.l !XSL
	LDA.l !XT
	JSR assign
.next:
	SEP #$20
	LDA.l !XT
	INC
	STA.l !XT
	CMP #$05
	BNE .port
.out:
	REP #$30
	PLY
	PLX
	PLA
	PLP
	RTL

; D1:E81E (the battle's pause check, m 8): any controller's Start
any_start_l:
	LDA.l $004219
	ORA.l $00421B
	ORA.l $00421F
	ORA.l !P4RAW+1
	ORA.l !P5RAW+1
	AND #$10
	RTL

; combopanel.asm cm_panel_l: while the battle is PAUSED the three boxes show
; the controllers instead: each character's name and "Pn" (the RetroArch
; port playing them), and "Select:Switch Start:Resume".  carry set = drawn
ctlp_draw_l:
	PHP
	SEP #$20
	LDA.l $7ECD02
	AND #$01
	BNE .yes
	PLP
	CLC
	RTL
.yes:
	REP #$30
	PHX
	PHY
	LDX.w #$0000            ; blank: 6 tile rows x 32
	LDA.w #$29FF
-	STA.l !BOXBUF,x
	INX
	INX
	CPX.w #$0180
	BNE -
	SEP #$20
	LDA.l !XT
	PHA
	LDA #$00
	STA.l !XT
.slot:
	LDA.l !XT
	REP #$20
	AND.w #$00FF
	TAX
	SEP #$20
	LDA.l $7E2980,x
	BMI .next
	LDA.l !XT               ; the picker
	CMP.l !PZCUR
	BNE +
	JSR xd_col
	LDA #!ARROW
	JSR xd_put
+	LDA.l !XT
	JSL txt_name_l          ; -> !TXT, 5 letters
	JSR xd_col
	INX
	INX
	LDY.w #$0000
-	PHX
	TYX
	LDA.l !TXT,x
	PLX
	JSR xd_put
	INY
	CPY.w #$0005
	BNE -
	LDA.l !XT               ; line 2: "P" + the controller playing them
	REP #$20
	AND.w #$00FF
	TAX
	SEP #$20
	LDA.l !ROLE,x
	REP #$20
	AND.w #$0003
	TAX
	SEP #$20
	LDA.l bitmask,x         ; (nobody on that pad: leave it blank)
	AND.l !PJOIN
	BNE +
	LDA.l !XT
	BNE .next               ; (the leader always shows its controller)
+	LDA.l !PPORT,x
	CLC
	ADC #$D5                ; '1' + port
	PHA
	JSR xd_col
	REP #$20
	TXA
	CLC
	ADC.w #$0082
	TAX
	SEP #$20
	LDA #$AF                ; P
	JSR xd_put
	PLA
	JSR xd_put
.next:
	LDA.l !XT
	INC
	STA.l !XT
	CMP #$03
	BEQ +
	JMP .slot
+	PLA
	STA.l !XT
	LDY.w #$0000            ; bottom line
-	TYX
	LDA.l xd_help,x
	BEQ +
	PHA
	REP #$20
	TYA
	ASL
	CLC
	ADC.w #$0142
	TAX
	SEP #$20
	PLA
	JSR xd_put
	INY
	BRA -
+	REP #$30
	PLY
	PLX
	PLP
	SEC
	RTL
xd_help:	db $B2,$BE,$C5,$BE,$BC,$CD,$E3,$A2,$C1,$C8,$C8,$CC,$BE,$FF,$FF
		db $B2,$CD,$BA,$CB,$CD,$E3,$B1,$BE,$CC,$CE,$C6,$BE,$00
				; Select:Choose  Start:Resume

; X = $40 + slot(!XT)*20 (m 8 on exit)
xd_col:
	LDA.l !XT
	REP #$20
	AND.w #$00FF
	STA.l !XNEW
	ASL
	ASL
	CLC
	ADC.l !XNEW
	ASL
	ASL
	CLC
	ADC.w #$0040
	TAX
	SEP #$20
	RTS

; A(8) = tile -> !BOXBUF,x (white), X += 2
xd_put:
	XBA
	LDA #!WHITE
	XBA
	REP #$20
	STA.l !BOXBUF,x
	SEP #$20
	INX
	INX
	RTS

; paused: draw the controllers panel and put it on screen.  The game's
; menu tick (which draws the boxes) and its vblank uploads both stop during
; the pause, so this copies the panel to VRAM itself - only inside vblank
; (the paused battle runs this at line ~230), else it retries next frame.
; Redrawn only when something it shows changes.  (m 8, x 16)
pz_show:
	LDA.l !PZON             ; 1 = drawn last frame, not yet on screen: copy
	CMP #$01                ; it first, while still in vblank (drawing takes
	BNE +                   ; ~40 lines - it would run us out of vblank)
	JSR pz_dma
	BCC +
	LDA #$02                ; 2 = on screen
	STA.l !PZON
+	JSL dd_sig_l            ; (trail.asm: includes the pause, seats, ports)
	CMP.l !PZSIG
	BNE .draw
	LDA.l !PZON
	BNE .out                ; drawn (and shown, or about to be)
.draw:
	STA.l !PZSIG
	JSL ctlp_draw_l
	LDA #$01                ; publish (as menu.asm's draw_boxes does)
	STA.l !PUB
	REP #$20
	LDX.w #$017E
-	LDA.l !BOXBUF,x
	STA.l !SHOW,x
	DEX
	DEX
	BPL -
	SEP #$20
	LDA #$00
	STA.l !PUB
	LDA #$18
	STA.l !BOXON
	LDA #$01                ; next frame's vblank puts it on screen
	STA.l !PZON
.out:
	RTS

; the finished panel -> VRAM $7820 (the game's own panel transfer), only
; between lines 227 and 249.  carry set = done.  (m 8, x 16)
pz_dma:
	LDA.l $00213F
	LDA.l $002137
	LDA.l $00213D
	XBA
	LDA.l $00213D
	AND #$01
	XBA
	REP #$20
	CMP.w #227
	BCC .no
	CMP.w #250
	BCS .no
	LDA.w #$7820
	STA.l $002116
	SEP #$20
	LDA #$80
	STA.l $002115
	LDA #$01
	STA.l $004370
	LDA #$18
	STA.l $004371
	LDA.b #!SHOW&$FF
	STA.l $004372
	LDA.b #(!SHOW>>8)&$FF
	STA.l $004373
	LDA.b #!SHOW>>16
	STA.l $004374
	LDA #$80
	STA.l $004375
	LDA #$01
	STA.l $004376
	LDA #$80
	STA.l $00420B
	SEC
	RTS
.no:
	SEP #$20
	CLC
	RTS

; Load our player-tag sprite font into OBJ VRAM, once per menu open (flag
; $7F1EE8, cleared in menu_init).  Called from the menu NMI while the screen
; is still force-blanked, so the VRAM write is safe.  OBJ tiles start at VRAM
; word $4000; we use tile $B0 -> word $4B00.  (m 8, x 16)
font_load:
	PHP
	SEP #$20
	REP #$10
	; player-tag palettes (match the combat pointers): colour 1 = the text,
	; colour 15 = $14A5 (the panel's own bg, so the chip blends in).
	LDA #209               ; pal 5 (white, P1) colour 1 = $7FFF
	STA.l $002121
	LDA #$FF
	STA.l $002122
	LDA #$7F
	STA.l $002122
	LDA #223               ; pal 5 colour 15 = $14A5
	STA.l $002121
	LDA #$A5
	STA.l $002122
	LDA #$14
	STA.l $002122
	LDA #225               ; pal 6 (light blue, P2) colour 1 = $7EC8
	STA.l $002121
	LDA #$C8
	STA.l $002122
	LDA #$7E
	STA.l $002122
	LDA #239
	STA.l $002121
	LDA #$A5
	STA.l $002122
	LDA #$14
	STA.l $002122
	LDA #241               ; pal 7 (red, P3) colour 1 = $001F
	STA.l $002121
	LDA #$1F
	STA.l $002122
	LDA #$00
	STA.l $002122
	LDA #255
	STA.l $002121
	LDA #$A5
	STA.l $002122
	LDA #$14
	STA.l $002122
	LDA.l $7F1EE8
	BEQ +                   ; (BNE .fdone is out of range: the CGRAM block is long)
	JMP .fdone
+	LDA #$01
	STA.l $7F1EE8
	LDA #$80
	STA.l $002115          ; VRAM word increment
	LDA #$00
	STA.l $002116          ; VMADD = $4B00 (OBJ tile $B0)
	LDA #$4B
	STA.l $002117
	LDA #$01                ; DMA7: word, A->B, auto-inc
	STA.l $004370
	LDA #$18                ; B-bus $2118
	STA.l $004371
	LDA.b #font_data&$FF
	STA.l $004372
	LDA.b #(font_data>>8)&$FF
	STA.l $004373
	LDA.b #font_data>>16
	STA.l $004374
	LDA.b #(font_end-font_data)&$FF
	STA.l $004375
	LDA.b #((font_end-font_data)>>8)&$FF
	STA.l $004376
	LDA #$80
	STA.l $00420B          ; go, channel 7
.fdone:
	PLP
	RTS

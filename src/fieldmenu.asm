; =====================================================================
; Main menu for everyone.
;   The game's joypad routine (C2:84EC) reads $4218/$4219 for pad 1.  We
;   point those reads at a merged copy built right after the auto-read:
;     * main menu (called from C2:8487): pads 1+2+3 combined, so any
;       controller drives the menu
;     * field: pad 1, plus the X button (open menu) from pads 2/3
;     * battle: pad 1 only (battle has its own per-player routing)
; =====================================================================
!MERGED = $7E02FE       ; word

org $C284FE             ; "LDX $F2 / STX $FE"
	JSL pad_merge
org $C28502             ; LDA $4218 -> merged
	LDA.w !MERGED&$FFFF
org $C28509             ; LDA $4219 -> merged hi
	LDA.w (!MERGED&$FFFF)+1
org $C28510
	LDA.w (!MERGED&$FFFF)+1
org $C2851B             ; (16-bit) LDA $4218 for the reset combo
	LDA.w !MERGED&$FFFF

org !CB|$F800
pad_merge:
	LDX $F2                 ; the instructions we replaced (DP = 0, DB = 0)
	STX $FE
	PHP
	REP #$20
	PHA                     ; keep the game's full A (hidden high byte included)
	JSL p45_nmi_l           ; (RetroArch ports 4/5: ctlports.asm)
	JSR p1_pad              ; the leader's pad (any controller can lead)
	STA.l !MERGED
if !WITH_FMV
	JSL fs_check            ; Y on the file screen: the video gallery
endif
	SEP #$20
	LDA.l !BTTL             ; (in battle, battle_input does it every frame)
	BNE +
	JSR uj_pick             ; pads 2/3 join on their first press, anywhere
				; (field: after the frame's pose upload - field.asm)
	SEP #$20
	LDA #$00                ; out of battle: the next battle starts on the game's panel
	STA.l !BOXON
+	SEP #$20
	LDA.l !BTTL
	BEQ +
	DEC
	STA.l !BTTL
	JSR btl_merge           ; (the victory messages: anyone's A)
	JMP .done
+	REP #$20
	LDA 7,s                 ; return address of the JSR into the joypad routine
	CMP #$8489
	BNE .field
	JSR all_pads
	ORA.l !MERGED
	STA.l !MERGED
	BRA .done
.field:
	SEP #$20
	JSL game_nmi_l          ; field / world map NMI installed: the game runs
	BCS .infield            ; (even before field_tick / ow_tick, after the menu)
.gm:
	LDA.l !GAMEON           ; no field / world map / battle running: the title,
	BEQ .ui                 ; the save screen, new-game setup - every controller
	DEC                     ; drives them, like the menus
	STA.l !GAMEON
.infield:
	JSL win_merge_l         ; a window / Yes-No open: anyone's A and d-pad
	REP #$20                ; (trail.asm)
	JSR all_pads
	AND #$0040              ; X: open the menu
	ORA.l !MERGED
	STA.l !MERGED
	BRA .done
.ui:
	REP #$20
	JSR all_pads
	ORA.l !MERGED
	STA.l !MERGED
.done:
	JSR pad_hold            ; (inside a follower's step: no pad update now)
	REP #$20
	PLA
	PLP
	RTL

; ---------------------------------------------------------------------
; main menu tabs: switching tabs zeroes the cursor ($0412) for every tab, so
; coming back to the main page always showed character 0.  Remember the main
; page's character when leaving it and give it back on return.
!MAINC = $7F1E48        ; character the main page showed (FF none)

; C2:9A45 "STA $0411 / LDA $0D88" (A 8-bit = the new tab)
tab_set:
	PHA
	LDA.l $7E0411           ; leaving the main page: keep its character
	BNE +
	LDA.l $7E0412
	STA.l !MAINC
+	PLA
	STA.l $7E0411
	LDA.l $7E0D88           ; (the flags the game branches on)
	RTL

; C2:9A53 "STZ $0412 / STZ $0413"
tab_cur:
	PHA
	LDA #$00
	STA.l $7E0413
	LDA.l $7E0411
	BNE .zero
	LDA.l !MAINC            ; back on the main page: its character again
	CMP #$03
	BCC +
.zero:
	LDA #$00
+	STA.l $7E0412
	PLA
	RTL
warnpc !CB|$F900

org $C30A99
	JSL title_pad
	NOP

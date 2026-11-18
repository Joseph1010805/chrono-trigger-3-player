; =====================================================================
; FMV patch without the 3-player mod: the gallery's own hooks.
;   * the menus' joypad routine: Y on the file screen opens the gallery
;   * field / world map / battle: "playing now", never the file screen
; (with the 3-player mod these jobs are done by its own hooks)
; =====================================================================
macro fmvc0call(addr, ret)
	PHK
	PEA.w <ret>-1
	PEA.w $9BD3             ; C0:9BD4 is an RTL byte
	JML <addr>
<ret>:
endmacro

org $C284FE                     ; "LDX $F2 / STX $FE" (A is reloaded next)
	JSL fmv_pad
org $C03040                     ; the field leader: "LDA #$01 / LDX $6D / STA $1A01,X / JSR $9E29"
	JSL fmv_field
	NOP #6
org $C23AE7                     ; the world map's party routine: "LDA $7E2980,X"
	JSL fmv_ow
org $CD0348                     ; battle input: "LDA $F8 / STA $CC99"
	JSL fmv_btl
	NOP

org !DB2|$E300
fmv_pad:
	LDX $F2
	STX $FE
	JSL fs_check
	RTL

fmv_field:                      ; A/X 8-bit, D = $0100, DB = $00
	LDA #$00
	STA.l !FSFLAG
	LDA #$01
	LDX $6D
	STA $1A01,X
	%fmvc0call($C09E29, fmv_field_r)
	RTL

fmv_ow:
	PHA
	LDA #$00
	STA.l !FSFLAG
	PLA
	LDA.l $7E2980,x
	RTL

fmv_btl:
	PHP
	SEP #$20
	LDA #$00
	STA.l !FSFLAG
	PLP
	LDA $F8
	STA $CC99
	RTL
warnpc !DB2|$E600

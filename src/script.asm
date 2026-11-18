; event-script button tests read the combined copies (see script_pads)
org $C066A6 : LDA.w !MF8&$FFFF          ; was LDA $00F8
org $C066AB : LDA.w (!MF8&$FFFF)+1      ; was LDA $00F9
org $C066B3 : LDA.w !MF8&$FFFF
org $C066BD : LDA.w !MF8&$FFFF
org $C066C7 : LDA.w !MF2&$FFFF          ; was LDA $00F2
org $C066E6 : LDA.w !MF2&$FFFF
org $C066F0 : LDA.w !MF2&$FFFF
org $C066FA : LDA.w !MF2&$FFFF
org $C06706 : LDA.w !MF2&$FFFF
org $C06710 : LDA.w !MF2&$FFFF
; the field's main loop latches new presses for the "pressed since" tests
org $C00097 : LDA.w !MF0&$FFFF          ; was LDA $00F0  (-> TSB $51)
org $C0009C : LDA.w !MF6&$FFFF          ; was LDA $00F6  (-> TSB $50)
; the main menu starts on the opener's character (was LDA $0412, just zeroed)
org $C299EA : LDA.w !OPENER&$FFFF

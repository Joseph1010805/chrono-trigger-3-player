; =====================================================================
; Bridges for the Comb panel (far.asm, bank !DB2): long entries into the
; battle code's own helpers (same bank as them).  A 8-bit, X 16-bit.
; =====================================================================
name_fetch_l:   JSR name_fetch
	RTL
txt_name_l:     JSR txt_name
	RTL
digits3_l:      JSR digits3
	RTL
rec_find_l:     JSR rec_find
	RTL
combo_mask_l:   JSR combo_mask
	RTL
mp_ok_l:        JSR mp_ok
	RTL
is_done_l:      JSR is_done
	RTL
pick_target_l:  JSR pick_target
	RTL
join_prop_l:    JSR join_prop
	RTL
combo_cancel_l: JSR combo_cancel
	RTL
commit_l:       JSR commit
	RTL
cand_id_l:      JSR cand_id
	RTL
owner_l:        JSR owner
	RTL

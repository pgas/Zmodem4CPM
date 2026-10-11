;============================================================================
; scb_sysvar.inc - CP/M 3 System Control Block (SCB) Error Interception Layer
;============================================================================
; Shared between rz.asm and sz.asm (100% byte-for-byte binary parity).
;
; Routines:
;   - cpm3_sysvar_hook: Intercept CP/M 3 SCB error vectors via BDOS 49 (S_SYSVAR)
;   - cpm3_sysvar_unhook: Restore original CP/M 3 SCB error vectors upon exit
;   - scb_pb_*: System Control Block parameter blocks (offsets 28h, 24h, 22h)
;============================================================================

;============================================================================
; Function : cpm3_sysvar_hook
; Purpose  : Hook CP/M 3 system variables table via BDOS function 49 (S_SYSVAR)
; Inputs   : None
; Outputs  : HL = pointer to SCB / system variables
; Modifies : A, C, DE, HL
;============================================================================
cpm3_sysvar_hook:
		xor	a			; Clear A
		ld	(scb_pb_reserved), a	; Set parameter block mode byte to 0 (read word)
		ld	(scb_pb_reserved2), a	; Set parameter block mode byte to 0 (read word)
		ld	c, S_SYSVAR		; BDOS Function 49: Get/Set System Variable
		ld	de, scb_pb_offset	; DE points to SCB parameter block (offset 28h)
		call	bdos			; Query SCB variable; returns value in HL
		ld	a, h			; Invert HL to generate bitwise mask
		cpl
		ld	h, a
		ld	a, l
		cpl
		ld	l, a
		ld	(scb_ptr_sysvar), hl	; Store inverted mask word
		ld	c, S_SYSVAR		; BDOS Function 49: Get/Set System Variable
		ld	de, scb_pb_offset2	; DE points to SCB parameter block (offset 24h)
		call	bdos			; Query original error vector 1 into HL
		ld	(scb_hook_vector1), hl	; Save original SCB error vector 1
		ld	de, (scb_ptr_sysvar)	; Load inverted mask into DE
		ld	a, h			; Mask off system interception bits
		and	d
		ld	h, a
		ld	a, l
		and	e
		ld	l, a
		ld	(saved_scb_vector1), hl	; Save modified vector 1 to write back
		ld	c, S_SYSVAR		; BDOS Function 49: Get/Set System Variable
		ld	de, scb_pb_offset3	; DE points to SCB parameter block (offset 22h)
		call	bdos			; Query original break/error vector 2 into HL
		ld	(scb_hook_vector2), hl	; Save original SCB error vector 2
		ld	de, (scb_ptr_sysvar)	; Load inverted mask into DE
		ld	a, h			; Mask off system interception bits
		and	d
		ld	h, a
		ld	a, l
		and	e
		ld	l, a
		ld	(saved_scb_vector2), hl	; Save modified vector 2 to write back

cpm3_sysvar_set_vecs:
		ld	a, 0FEh			; 0FEh = Set word in SCB parameter block
		ld	(scb_pb_reserved2), a	; Set PB mode to write word
		ld	de, scb_pb_offset2	; DE points to SCB PB 2 (offset 24h)
		ld	c, S_SYSVAR		; BDOS Function 49: Get/Set System Variable
		call	bdos			; Write new error vector 1 into SCB
		ld	a, 0FEh			; 0FEh = Set word in SCB parameter block
		ld	(scb_pb_reserved3), a	; Set PB mode to write word
		ld	de, scb_pb_offset3	; DE points to SCB PB 3 (offset 22h)
		ld	c, S_SYSVAR		; BDOS Function 49: Get/Set System Variable
		jp	bdos			; Write new error vector 2 into SCB and return
; End of function cpm3_sysvar_hook

;----------------------------------------------------------------------------
; Function : cpm3_sysvar_unhook
; Purpose  : Restore CP/M 3 system variables on exit
; Inputs   : None
; Outputs  : System variables restored
; Modifies : A, HL
;----------------------------------------------------------------------------
cpm3_sysvar_unhook:
		ld	hl, (scb_hook_vector1)	; Load original saved SCB vector 1
		ld	(saved_scb_vector1), hl	; Place into PB write slot
		ld	hl, (scb_hook_vector2)	; Load original saved SCB vector 2
		ld	(saved_scb_vector2), hl	; Place into PB write slot
		jr	cpm3_sysvar_set_vecs	; Write original vectors back to SCB
; End of function cpm3_sysvar_unhook

;----------------------------------------------------------------------------
; SCB Parameter Blocks (BDOS Function 49)
;----------------------------------------------------------------------------
scb_pb_offset:		.db	28h
scb_pb_reserved:	.db	0
			.db	0
			.db	0
scb_pb_offset2:		.db	24h
scb_pb_reserved2:	.db	0
saved_scb_vector1:	.dw	0
scb_pb_offset3:		.db	22h
scb_pb_reserved3:	.db	0
saved_scb_vector2:	.dw	0
scb_hook_vector1:	.dw	0
scb_hook_vector2:	.dw	0
scb_ptr_sysvar:		.dw	0

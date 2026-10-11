;============================================================================
; Table-Driven Indirect Dispatch Helper (dispatch.inc)
; Shared between rz.asm and sz.asm for CP/M 3
;============================================================================

;============================================================================
; Function : dispatch_table_jump
; Purpose  : Dispatches execution to a jump vector found after a CPIR search.
; Inputs   : HL = End of character search table (after CPIR match)
;            BC = Remaining count returned by CPIR
; Outputs  : Jumps directly to target handler subroutine via JP (HL)
; Modifies : BC, HL
; Notes    : Calculates offset: HL + BC skips past characters to vector table,
;            then SLA C multiplies the index by 2 to index the 16-bit word address (.dw).
;============================================================================
dispatch_table_jump:
	add	hl, bc			; Advance HL past remaining switch characters
	sla	c			; Multiply remaining index count C by 2 (word offset)
	add	hl, bc			; HL = address of target 16-bit jump vector (.dw)
	ld	c, (hl)			; Load low byte of handler routine address
	inc	hl
	ld	h, (hl)			; Load high byte of handler routine address
	ld	l, c			; HL = target handler address
	jp	(hl)			; Jump indirectly to option switch handler

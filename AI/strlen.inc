;============================================================================
; strlen.inc - String Length and Case Normalization Subroutine
;============================================================================
; Shared between rz.asm and sz.asm (100% byte-for-byte binary parity).
;
; Routine:
;   - calc_strlen: Converts string at HL to uppercase in place and finds null terminator
;============================================================================

;============================================================================
; Function : calc_strlen
; Purpose  : Calculate string length and convert lowercase characters to uppercase
; Inputs   : HL = null-terminated string pointer
; Outputs  : String converted to uppercase in place, HL preserved
; Modifies : A, HL
;============================================================================
calc_strlen:
		push	af			; Preserve AF
		push	hl			; Preserve HL

calc_strlen_loop:
		ld	a, (hl)			; Fetch character
		or	a			; Check for null terminator
		jr	z, calc_strlen_lo_done_1 ; If null terminator, finish
		call	to_upper		; Convert character to uppercase
		ld	(hl), a			; Store converted character back
		inc	hl			; Advance string pointer
		jr	calc_strlen_loop	; Continue for all characters

calc_strlen_lo_done_1:
		pop	hl			; Restore original HL
		pop	af			; Restore AF
		ret				; Return
; End of function calc_strlen

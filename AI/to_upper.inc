;============================================================================
; to_upper.inc - ASCII Lowercase to Uppercase Conversion Subroutine
;============================================================================
; Shared between rz.asm and sz.asm (100% byte-for-byte binary parity).
;
; Routine:
;   - to_upper: Converts ASCII character in A from 'a'..'z' to 'A'..'Z'
;============================================================================

;============================================================================
; Function : to_upper
; Purpose  : Convert lowercase ASCII character in A ('a'..'z') to uppercase ('A'..'Z')
; Inputs   : A = character
; Outputs  : A = uppercase character
; Modifies : A, Flags
;============================================================================
to_upper:
		and	7Fh			; Mask 7-bit ASCII
		cp	'a'			; Less than 'a' (61h)?
		ret	c			; If < 'a', already uppercase or symbol
		cp	'z'+1			; Greater than 'z' (7Bh)?
		ret	nc			; If > 'z', symbol
		and	5Fh			; Convert lowercase to uppercase (clear bit 5)
		ret				; Return
; End of function to_upper

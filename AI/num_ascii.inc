;============================================================================
; num_ascii.inc - 8-Bit Decimal Number to ASCII String Conversion Subroutines
;============================================================================
; Shared between rz.asm and sz.asm (100% byte-for-byte binary parity).
;
; Routines:
;   - byte_to_dec_ascii: Convert 8-bit unsigned integer to 3-digit ASCII (spaces for leading zeroes)
;   - byte_to_dec_ascii_no_suppress / byte_to_signed_dec: Unsuppressed leading zeros
;   - byte_to_dec_calc: Core 3-stage division / digit extraction logic
;   - div_mod_8: Repeated-subtraction 8-bit division
;   - store_ascii_char / store_ascii_char_adv: Digit emitter to (DE)
;============================================================================

;============================================================================
; Function : byte_to_dec_ascii
; Purpose  : Convert 8-bit unsigned integer in A to 2-3 digit decimal ASCII string
; Inputs   : A = integer (0..255), DE = output buffer
; Outputs  : ASCII string written to DE (leading zeros suppressed with spaces)
; Modifies : All registers
;============================================================================
byte_to_dec_ascii:
		push	bc			; Preserve BC
		ld	b, 0			; B = 0: suppress leading zeros (use space)
		jp	byte_to_dec_calc	; Jump to calculation

;============================================================================
; Function : byte_to_dec_ascii_no_suppress / byte_to_signed_dec
; Purpose  : Convert 8-bit integer in A to decimal ASCII without suppressing zeros
; Inputs   : A = integer, DE = output buffer
; Outputs  : Decimal string written to DE
; Modifies : All registers
;============================================================================
byte_to_dec_ascii_no_suppress:
byte_to_signed_dec:
		push	bc			; Preserve BC
		ld	b, 0FFh			; B = 0FFh: do not suppress leading zeros

byte_to_dec_calc:
		push	hl			; Preserve HL
		push	af			; Preserve AF
		ld	h, 64h			; Divisor = 100 (hundreds digit)
		call	div_mod_8		; Divide by 100
		ld	h, 0Ah			; Divisor = 10 (tens digit)
		call	div_mod_8		; Divide remainder by 10
		call	store_ascii_char	; Store units digit
		pop	af			; Restore AF
		pop	hl			; Restore HL
		pop	bc			; Restore BC
		ret				; Return
; End of function byte_to_dec_ascii

;----------------------------------------------------------------------------
; Function : div_mod_8
; Purpose  : 8-bit integer division: divide A by H, output quotient and remainder
; Inputs   : A = dividend, H = divisor, B = suppression mode flag
; Outputs  : Quotient output to buffer (or space if suppressed), A = remainder
; Modifies : A, L
;----------------------------------------------------------------------------
div_mod_8:
		ld	l, 0FFh			; Initialize quotient = -1

div_mod_loop:
		sub	h			; Subtract divisor
		inc	l			; Increment quotient
		jr	nc, div_mod_loop	; Continue until underflow
		add	a, h			; Restore remainder
		ld	h, a			; Save remainder in H
		ld	a, l			; A = quotient
		or	a			; Is quotient zero?
		jr	nz, store_ascii_char	; If non-zero, output digit
		or	b			; Check suppression flag
		ld	a, h			; A = remainder
		ret	m			; If B negative, return
		ld	a, 20h			; Output space for suppressed zero (' ')
		jr	z, store_ascii_char_adv ; If zero, output space
		xor	a			; Fall into store_ascii_char
; End of function div_mod_8

;----------------------------------------------------------------------------
; Function : store_ascii_char
; Purpose  : Convert numeric digit in A (0..9) to ASCII and store at (DE)
; Inputs   : A = digit value, DE = output buffer pointer
; Outputs  : ASCII character stored, DE incremented, A = remainder
; Modifies : A, B, DE
;----------------------------------------------------------------------------
store_ascii_char:
		add	a, 30h			; Convert digit 0..9 to ASCII '0'..'9'
		ld	b, a			; B non-zero (ends suppression)

store_ascii_char_adv:
		ld	(de), a			; Store ASCII character into buffer
		inc	de			; Advance destination pointer
		ld	a, h			; Restore remainder in A
		ret				; Return
; End of function store_ascii_char

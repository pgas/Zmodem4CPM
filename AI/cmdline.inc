;============================================================================
; cmdline.inc - CP/M Command Tail Tokenizer and Whitespace Parser
;============================================================================
; Shared between rz.asm and sz.asm (100% byte-for-byte binary parity).
;
; Routines:
;   - tokenize_cmdline: Splits whitespace-delimited argument tail into token table
;   - skip_spaces: Advances string pointer past spaces and tabs
;   - check_delimiter: Tests if character at pointer is space, tab, or null
;============================================================================

;============================================================================
; Function : tokenize_cmdline
; Purpose  : Split CP/M command tail into whitespace-separated argument tokens
; Inputs   : HL = command line buffer, DE = token table buffer, A = delimiter mask
;            (In rz: DE = command line buffer, HL = token table buffer, A = mask)
; Outputs  : Token table populated, token count stored at table base + 1
; Modifies : All registers
;============================================================================
tokenize_cmdline:
		push	bc			; Preserve BC
		push	de			; Preserve token table / DE
		push	hl			; Preserve command line / HL
		ld	c, a			; C = delimiter mask flag
		ex	de, hl			; HL = token table, DE = command line
		ld	b, (hl)			; B = max token limit
		push	hl			; Preserve token table base
		inc	hl			; Advance past limit and count bytes (+2)
		inc	hl

tokenize_cmdli_call_1:
		call	skip_spaces		; Skip leading whitespace
		or	a			; End of command line?
		jr	z, tokenize_cmdli_step_1 ; If end of line, finish parsing
		ld	(hl), e			; Store token pointer low byte
		inc	hl
		ld	(hl), d			; Store token pointer high byte
		inc	hl
		dec	b			; Decrement token limit counter
		jr	z, tokenize_cmdli_call_2 ; If limit reached, parse final token
		call	check_delimiter		; Scan to end of token
		or	a			; End of command line?
		jr	z, tokenize_cmdli_step_1 ; If end of line, finish
		ld	a, c			; Delimiter replacement enabled?
		or	a
		jr	z, tokenize_cmdli_br_1
		xor	a			; Replace whitespace with null terminator
		ld	(de), a
		inc	de			; Advance past null

tokenize_cmdli_br_1:
tokenize_cmdli_call_2_rz:
		ld	a, b			; Any token slots remaining?
		or	a
		jr	nz, tokenize_cmdli_call_1 ; Loop for next token

tokenize_cmdli_call_2:
tokenize_cmdli_call_3:
		call	check_delimiter		; Scan to end of final token
		call	skip_spaces		; Skip trailing spaces
		or	a			; End of line?
		jr	z, tokenize_cmdli_step_1 ; If cleanly ended, finish
		or	0FFh			; Set NZ (too many tokens error)

tokenize_cmdli_step_1:
		pop	hl			; HL = token table base
		push	af			; Preserve status
		ld	a, (hl)			; Load max token limit
		sub	b			; A = limit - remaining = tokens parsed
		inc	hl			; Point to count byte (+1)
		ld	(hl), a			; Store parsed token count
		pop	af			; Restore status
		pop	hl			; Restore command line pointer
		pop	de			; Restore token table pointer
		pop	bc			; Restore BC
		ret				; Return
; End of function tokenize_cmdline

;----------------------------------------------------------------------------
; Function : skip_spaces
; Purpose  : Advance pointer DE past any spaces (20h) or tabs (09h)
; Inputs   : DE = string pointer
; Outputs  : DE points to first non-space character, A = character
; Modifies : A, DE
;----------------------------------------------------------------------------
skip_spaces:
		ld	a, (de)			; Fetch character
		and	7Fh			; Mask 7-bit ASCII
		inc	de			; Advance pointer
		cp	20h			; Space?
		jr	z, skip_spaces		; Skip space
		cp	9			; Tab?
		jr	z, skip_spaces		; Skip tab
		dec	de			; Back up to first non-space character
		ret				; Return
; End of function skip_spaces

;----------------------------------------------------------------------------
; Function : check_delimiter
; Purpose  : Advance pointer DE until whitespace or null delimiter is found
; Inputs   : DE = string pointer
; Outputs  : DE points to delimiter character, A = character
; Modifies : A, DE
;----------------------------------------------------------------------------
check_delimiter:
		ld	a, (de)			; Fetch character
		and	7Fh			; Mask 7-bit ASCII
		ret	z			; Null terminator found (Z flag set)
		cp	20h			; Space delimiter?
		ret	z			; Return if space
		cp	9			; Tab delimiter?
		ret	z			; Return if tab
		inc	de			; Advance to next character
		jr	check_delimiter		; Loop until delimiter
; End of function check_delimiter

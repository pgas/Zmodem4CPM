;============================================================================
; CP/M File Control Block Formatting Library (fcb_format.inc)
; Shared between rz.asm and sz.asm for CP/M 3
;============================================================================

;============================================================================
; Function : format_fcb_name
; Purpose  : Format 36-byte CP/M FCB into printable "FILENAME.EXT" string
; Inputs   : DE = FCB pointer, HL = destination text buffer
; Outputs  : Formatted ASCII string written to (HL) (dot inserted, spaces stripped)
; Modifies : All registers
;============================================================================
format_fcb_name:
	push	bc			; Preserve BC
	push	hl			; Preserve HL
	push	de			; Preserve DE
	push	af			; Preserve AF
	ld	b, 8			; 8 filename characters
	call	check_fcb_char		; Copy non-space filename characters
	ld	(hl), '.'		; Insert dot separator
	inc	hl			; Advance destination pointer
	ld	b, 3			; 3 extension characters
	call	check_fcb_char		; Copy non-space extension characters
	pop	af			; Restore AF
	pop	de			; Restore DE
	pop	hl			; Restore HL
	pop	bc			; Restore BC
	ret				; Return

;============================================================================
; Function : check_fcb_char
; Purpose  : Copy non-space characters from (DE) to (HL) for B count bytes
; Inputs   : DE = source pointer, HL = destination pointer, B = character count
; Outputs  : Characters copied to (HL), trailing spaces skipped
; Modifies : A, B, DE, HL
;============================================================================
check_fcb_char:
	ld	a, (de)			; Fetch character from FCB
	and	7Fh			; Strip CP/M attribute bit 7
	cp	' '			; Is character a space?
	jr	z, format_fcb_space_done ; If space, do not store
	ld	(hl), a			; Store printable character into output buffer
	inc	hl			; Advance output pointer
format_fcb_space_done:
	inc	de			; Advance source pointer
	djnz	check_fcb_char		; Loop for all B characters
	ret				; Return

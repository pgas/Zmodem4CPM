;============================================================================
; CP/M File Control Block Initialization Library (fcb_init.inc)
; Shared between rz.asm and sz.asm for CP/M 3
;============================================================================

;============================================================================
; Function : ascii_to_digit
; Purpose  : Convert ASCII decimal digit ('0'..'9') to binary numeric value in A
; Inputs   : A = ASCII character
; Outputs  : A = binary value (0..9), Carry set if not a valid digit
; Modifies : A, F
;============================================================================
ascii_to_digit:
	sub	30h			; Subtract ASCII '0' (30h)
	ret	c			; If < '0', Carry set (invalid)
	cp	0Ah			; Compare against 10
	ccf				; Invert Carry: CY=0 if 0..9, CY=1 if > 9
	ret				; Return

;============================================================================
; Function : init_empty_fcb
; Purpose  : Initialize 36-byte CP/M FCB with default drive and space padding
; Inputs   : DE = pointer to 36-byte FCB
; Outputs  : FCB drive set to 0, filename and extension padded with spaces
; Modifies : A, B, DE
;============================================================================
init_empty_fcb:
	xor	a			; Clear A (default drive 0)
	ld	(de), a			; Store into FCB drive byte
	inc	de			; Advance to filename field
	call	init_fcb_spaces		; Fill filename and extension with spaces

;============================================================================
; Function : init_fcb_spaces
; Purpose  : Fill FCB filename (8 bytes) and extension (3 bytes) with spaces
; Inputs   : DE = FCB filename pointer
; Outputs  : 11 bytes filled with spaces (20h), current extent & user set
; Modifies : A, B, DE
;============================================================================
init_fcb_spaces:
	ld	b, 0Bh			; 11 bytes (8 filename + 3 extension)
	ld	a, 20h			; Fill with spaces (' ')
	call	memset_de_spaces	; Fill memory
	xor	a			; Clear extent byte (00h)
	ld	(de), a
	inc	de
	call	get_cur_drive_user	; Get active user area
	ld	a, c			; C = current user area
	ld	(de), a			; Store into FCB extension user area
	inc	de
	ld	b, 3			; Clear remaining 3 extension bytes
	xor	a

;============================================================================
; Function : memset_de_spaces
; Purpose  : Fill memory at DE with byte in A for B count bytes
; Inputs   : DE = buffer, A = fill value, B = length
; Outputs  : Memory filled
; Modifies : B, DE
;============================================================================
memset_de_spaces:
	ld	(de), a			; Store fill byte into memory
	inc	de			; Advance buffer pointer
	djnz	memset_de_spaces	; Repeat for all B bytes
	ret				; Return

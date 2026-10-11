;============================================================================
; CP/M Filespec Parser & Wildcard Expansion Library (filespec.inc)
; Shared between rz.asm and sz.asm for CP/M 3
;============================================================================

;============================================================================
; Function : parse_cpm_filespec
; Purpose  : Parse CP/M file specification string into standard 36-byte FCB
; Inputs   : DE = FCB destination, HL = filename string
; Outputs  : FCB initialized
; Modifies : All registers
;============================================================================
parse_cpm_filespec:
		push	bc			; Preserve BC
		ld	(fcb_attr_mode), a	; Save FCB attribute mode flag
		call	calc_strlen		; Convert filename string to uppercase and find end
		push	de			; Preserve FCB pointer
		call	init_empty_fcb		; Initialize empty FCB filled with spaces
		ld	(de), a			; Store drive byte
		pop	de			; Restore FCB pointer
		push	de			; Preserve FCB pointer
		call	parse_fcb_drive_user	; Parse drive, user area, filename, and extension
		pop	de			; Restore FCB pointer
		pop	bc			; Restore BC
		jr	parse_cpm_filespec_done	; Check wildcard count and return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : parse_fcb_drive_user
; Purpose  : Extract drive letter and user area number from file path string
; Inputs   : DE = FCB, HL = string
; Outputs  : Drive and user parsed into FCB
; Modifies : All registers
;============================================================================
parse_fcb_drive_user:
		xor	a			; Clear A
		ld	(de), a			; Clear FCB drive field (0 = default drive)
		ld	(fcb_drive_specified), a ; Reset drive specified flag
		ld	(file_batch_index), a	; Reset wildcard character count
		call	get_cur_drive_user	; Get active CP/M drive and user area
		ld	a, c			; C = current user area (0..15)
		ld	(fcb_active_user), a	; Store active user
		push	de			; Preserve FCB pointer
		ld	a, (hl)			; Check first character of filespec
		cp	3Ah			; Is it a colon (':')?
		jr	nz, parse_fcb_no_colon	; If not colon, proceed to filename parsing
		inc	hl			; Skip leading colon
parse_fcb_no_colon:
		ld	b, 8			; Up to 8 characters for filename primary field
		call	validate_fcb_char	; Parse primary filename into FCB
		pop	de			; Restore FCB pointer
		ld	a, (hl)			; Check trailing delimiter character
		ld	(fcb_parse_state), a	; Save parse delimiter state
		cp	3Ah			; Was character a colon ':' (drive/user prefix)?
		jr	nz, parse_fcb_no_c_step_2 ; If not colon, primary field was filename
		inc	hl			; Advance past colon
		ld	a, (fcb_attr_mode)	; Check attribute mode
		or	a
		jr	z, parse_fcb_no_c_call_1
		call	fcb_check_wildcards	; Validate wildcard syntax in prefix
		jr	z, parse_fcb_no_c_step_1
parse_fcb_no_c_call_1:
		call	fcb_set_attributes	; Match drive / user specifier
		jr	z, parse_fcb_no_c_step_1
		ld	a, (fcb_attr_mode)
		or	a
		jr	nz, parse_fcb_no_c_step_1
		call	fcb_check_wildcards	; Check wildcard expansion
parse_fcb_no_c_step_1:
		ld	a, (fcb_drive_specified) ; Load parsed drive number (1=A, 2=B...)
		ld	(de), a			; Store drive into FCB drive byte
		push	de			; Preserve FCB pointer
		inc	de			; Advance past drive byte to filename
		call	init_fcb_spaces		; Fill filename and extension with spaces
		pop	de			; Restore FCB pointer
		xor	a			; Reset wildcard character count
		ld	(file_batch_index), a
		push	de			; Preserve FCB pointer
		ld	b, 8			; Parse actual 8-character filename following prefix
		call	validate_fcb_char
		pop	de			; Restore FCB pointer
		ld	a, (hl)			; Load delimiter character following filename
		ld	(fcb_parse_state), a
parse_fcb_no_c_step_2:
		ld	a, (fcb_parse_state)	; Check delimiter following filename
		ex	de, hl			; Swap pointers: HL = FCB, DE = string
		ld	bc, 8			; Advance HL past 8 filename bytes to extension
		add	hl, bc
		ex	de, hl			; Swap back: DE = extension in FCB, HL = string
		ld	b, 3			; Extension length = 3 characters
		cp	2Eh			; Is delimiter a dot '.'?
		jr	nz, parse_fcb_no_c_step_3 ; If no extension dot, skip
		inc	hl			; Advance past dot
		push	de			; Preserve extension pointer
		call	validate_fcb_char	; Parse 3-character extension into FCB
		pop	de			; Restore extension pointer
parse_fcb_no_c_step_3:
		ex	de, hl			; Advance DE to FCB user area extension field (+16)
		ld	bc, 5
		add	hl, bc
		ex	de, hl
		ld	a, (fcb_active_user)	; Load parsed user area number
		ld	(de), a			; Store user area into FCB extension
parse_cpm_filespec_done:
		ld	a, (file_batch_index)	; A = number of wildcard characters parsed
		or	a			; Set Z flag if no wildcards, NZ if wildcards present
		ret				; Return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : validate_fcb_char
; Purpose  : Validate ASCII character for CP/M FCB filename compatibility
; Inputs   : A = ASCII char
; Outputs  : Z if invalid/terminator, NZ if valid
; Modifies : A, F
;============================================================================
validate_fcb_char:
		call	valid_fnc		; Test if character is valid for filename
		ret	z			; Return if invalid or terminator
		inc	de			; Advance FCB destination pointer
		cp	2Ah			; Is character '*' (asterisk wildcard)?
		jr	nz, validate_fcb_c_call_1
		ld	a, 3Fh			; Replace '*' with '?' wildcard in FCB
		ld	(de), a
		call	inc_file_counter	; Count wildcard character
		jr	validate_fcb_c_loop_1
validate_fcb_c_call_1:
		ld	(de), a			; Store valid character into FCB
		inc	hl			; Advance input string pointer
		cp	3Fh			; Is character '?' (question mark wildcard)?
		call	z, inc_file_counter	; Count wildcard character
validate_fcb_c_loop_1:
		djnz	validate_fcb_char	; Repeat for all B characters in field
validate_fcb_c_call_2:
		call	valid_fnc		; Skip any extra characters beyond field width
		ret	z
		inc	hl
		jr	validate_fcb_c_call_2

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : inc_file_counter
; Purpose  : Increment processed files counter
; Inputs   : None
; Outputs  : file_batch_index incremented
; Modifies : HL
;============================================================================
inc_file_counter:
		push	hl			; Preserve HL
		ld	hl, file_batch_index	; HL points to wildcard count
		inc	(hl)			; Increment wildcard counter
		pop	hl			; Restore HL
		ret				; Return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : fcb_check_wildcards
; Purpose  : Check if FCB filename contains '?' or '*' wildcards
; Inputs   : HL = FCB pointer
; Outputs  : Flags set based on wildcards
; Modifies : DE, HL
;============================================================================
fcb_check_wildcards:
		push	hl			; Preserve HL
		push	de			; Preserve DE
		call	fcb_match_drive		; Check drive specifier matching
		pop	de			; Restore DE
		pop	hl			; Restore HL
		ret				; Return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : fcb_match_drive
; Purpose  : Match and verify FCB drive assignment against valid drives
; Inputs   : DE = FCB pointer
; Outputs  : Z if matches drive, NZ otherwise
; Modifies : A, B, DE, HL
;============================================================================
fcb_match_drive:
		call	get_fcb_ext_ptr		; Check extension pointer
		jr	z, fcb_expand_done
		ex	de, hl			; HL = FCB pointer
		inc	hl			; Advance to filename
		call	get_fcb_name_ptr	; Query filename length
		ld	b, a			; B = filename length
		inc	b
		ld	a, (hl)			; Check drive letter
		cp	41h			; Less than 'A'?
		jr	c, fcb_match_drive_fail
		sub	40h			; Convert 'A'..'P' to 1..16
		cp	b			; Compare with valid drive range
		jr	nc, fcb_expand_done
		ld	(fcb_drive_specified), a ; Store drive number
		inc	hl
		ld	a, (hl)
		cp	20h			; Space separator?
		ret	z
		call	ascii_to_digit		; Check user area digit
		ret	c
fcb_match_drive_fail:
		push	hl			; Preserve HL
		ld	b, 2			; Check up to 2 user number digits
fcb_match_driv_call_1:
		ld	a, (hl)
		cp	20h
		jr	z, fcb_match_driv_call_2
		call	ascii_to_digit		; Check if digit
		jr	c, fcb_match_driv_br_1
		inc	hl
		djnz	fcb_match_driv_call_1
		ld	a, (hl)
		cp	20h
		jr	nz, fcb_match_driv_br_1
fcb_match_driv_call_2:
		pop	hl			; Restore HL
		call	get_fcb_drive_ptr	; Query drive pointer
		ld	c, a
		inc	c
		call	parse_numeric_user	; Parse user number
		cp	c
		jr	nc, fcb_expand_done
		ld	(fcb_active_user), a	; Save user number
		xor	a			; Match success
		ret

fcb_match_driv_br_1:
		pop	hl			; Restore HL
		jr	fcb_expand_done

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : fcb_set_attributes
; Purpose  : Set CP/M 3 extended FCB file attributes
; Inputs   : DE = FCB pointer
; Outputs  : FCB attributes updated
; Modifies : DE, HL
;============================================================================
fcb_set_attributes:
		push	hl			; Preserve HL
		push	de			; Preserve DE
		call	fcb_expand_wildcards	; Expand wildcard templates
		pop	de			; Restore DE
		pop	hl			; Restore HL
		ret				; Return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : fcb_expand_wildcards
; Purpose  : Expand wildcard characters in FCB filename template
; Inputs   : DE = source pattern, HL = destination FCB
; Outputs  : FCB populated
; Modifies : All registers
;============================================================================
fcb_expand_wildcards:
		call	get_fcb_record_ptr	; Query record pointer
		jr	z, fcb_expand_done
		ex	de, hl			; HL = source, DE = destination
		inc	hl
fcb_expand_loop:
		ld	a, (de)			; Check template entry
		or	a
		jr	z, fcb_expand_done	; End of table
		inc	de
		inc	de
		push	hl			; Preserve pointers
		push	de
		ld	b, 8			; Compare 8 filename characters
fcb_expand_loo_br_1:
		ld	a, (de)
		cp	(hl)			; Character match?
		jr	nz, fcb_expand_loo_br_2
		inc	hl
		inc	de
		djnz	fcb_expand_loo_br_1
fcb_expand_loo_br_2:
		pop	de			; Restore pointers
		pop	hl
		jr	z, fcb_expand_don_step_1 ; If all matched, copy parameters
		ex	de, hl
		ld	bc, 10h			; Advance to next 16-byte template entry
		add	hl, bc
		ex	de, hl
		jr	fcb_expand_loop		; Continue scanning table

fcb_expand_done:
		or	0FFh			; Return NZ/CY (not matched)
		ret

fcb_expand_don_step_1:
		dec	de
		ld	a, (de)			; Load user number
		ld	(fcb_active_user), a	; Save active user
		dec	de
		ld	a, (de)			; Load drive number
		ld	(fcb_drive_specified), a ; Save specified drive
		xor	a			; Success (Z set)
		ret

;----------------------------------------------------------------------------
;		Validate character at hl is a valid filename character

valid_fnc:
		ld	a, (hl)			; Load character
		cp	'!'			; Below '!' is control char or space
		jr	c, valid_fnc_step_1
		cp	'='			; Invalid delimiter characters
		ret	z
		cp	'_'
		ret	z
		cp	'.'
		ret	z
		cp	':'
		ret	z
		cp	','
		ret	z
		cp	'<'
		ret	z
		cp	'>'
		ret	z
		or	a			; Null terminator
		ret	z
		cp	3Bh			; Semicolon ';'
		ret

valid_fnc_step_1:
		xor	a			; Invalid character: return Z
		ret

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : parse_numeric_user
; Purpose  : Parse decimal user number string (0..15) into numeric binary byte
; Inputs   : HL = string pointer
; Outputs  : A = numeric user area (0..15), CY on error
; Modifies : All registers
;============================================================================
parse_numeric_user:
		push	bc			; Preserve BC
		ld	bc, 1100h		; B = loop limit, C = accumulator (0)
parse_num_digit_loop:
		ld	a, (hl)			; Load next character
		call	valid_fnc		; Test if valid character
		jr	z, parse_num_done	; End of number string
		inc	hl			; Advance pointer
		call	ascii_to_digit		; Convert ASCII digit to binary (0..9)
		jr	c, parse_num_err	; Not a digit: error
		ld	d, a			; D = digit value
		ld	a, c			; Multiply accumulator C by 10 (C * 8 + C * 2)
		rlca
		jr	c, parse_num_err
		rlca
		jr	c, parse_num_err
		add	a, c
		jr	c, parse_num_err
		rlca
		jr	c, parse_num_err
		add	a, d			; Add new digit value
		jr	c, parse_num_err
		ld	c, a			; Update accumulator
		djnz	parse_num_digit_loop	; Repeat for subsequent digits
parse_num_done:
		ld	a, c			; A = parsed binary user number
		pop	bc			; Restore BC
		or	a			; Clear carry (success)
		ret

parse_num_err:
		pop	bc			; Restore BC
		scf				; Set carry (parse error)
		ret


check_delimiter_or_term: .equ valid_fnc
parse_fcb_driv_step_4: .equ parse_cpm_filespec_done

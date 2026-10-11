;============================================================================
; Serial Communication & Framing Helper Library (serial_comm.inc)
; Shared between rz.asm and sz.asm for CP/M 3
;============================================================================

; CAN abort sequence string: 10x CAN (18h), 10x BS (08h), null terminator
str_can_abort_seq:
abort_can_sequence:
	.db	18h, 18h, 18h, 18h, 18h, 18h, 18h, 18h, 18h, 18h
	.db	08h, 08h, 08h, 08h, 08h, 08h, 08h, 08h, 08h, 08h, 00h

;============================================================================
; Function : tx_can_sequence
; Purpose  : Send 10-byte CAN (cancel/abort) sequence to terminate transfer
; Inputs   : None
; Outputs  : CAN sequence transmitted to serial AUX port
; Modifies : A, HL
;============================================================================
tx_can_sequence:
	ld	hl, str_can_abort_seq	; HL points to 10x CAN + 10x BS abort sequence

;============================================================================
; Function : tx_raw_string
; Purpose  : Transmit null-terminated raw ASCII string to serial AUX port
; Inputs   : HL = pointer to null-terminated string
; Outputs  : Characters transmitted
; Modifies : A, HL
;============================================================================
tx_raw_string:
	ld	a, (hl)			; Load next string character
	inc	hl			; Advance string pointer
	or	a			; Test for null terminator (00h)
	ret	z			; Return when null terminator reached
	push	hl			; Preserve string pointer
	call	comm_tx_char_wait	; Transmit character to serial port
	pop	hl			; Restore string pointer
	jr	tx_raw_string		; Loop for next character

;============================================================================
; Function : comm_rx_char_filtered
; Purpose  : Receive character from AUX with escape, timeout, and CAN checks
; Inputs   : B = timeout retry count
; Outputs  : A = received character, Carry flag set on timeout/abort
; Modifies : A, BC
;============================================================================
comm_rx_char_filtered:
	push	bc			; Preserve timeout counter BC
	call	bdos_con_stat		; Check if console key pressed (BDOS Func 11)
	call	nz, bdos_con_read	; If key pressed, read console key (BDOS Func 1)
	cp	1Bh			; Was ESC pressed (1Bh)?
	ld	a, 18h			; A = CAN (18h)
	ld	c, 0Ah			; C = 10 CAN characters
	call	z, rx_buffer_init_ptrs	; If ESC pressed, inject CAN sequence to cancel
	pop	bc			; Restore timeout counter BC

comm_rx_retry:
	call	rx_byte_timeout		; Poll receive ring buffer with timer
	jr	nz, comm_rx_ok		; If byte received, return OK
	djnz	comm_rx_retry		; Decrement timeout counter and loop
	ld	a, 0FEh			; Timeout status code (0FEh)
	scf				; Set carry flag (timeout error)
	ret				; Return

comm_rx_ok:
	or	a			; Clear carry flag (character received successfully)
	ret				; Return with character in A

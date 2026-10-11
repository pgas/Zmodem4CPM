;============================================================================
; ZMODEM Character Escape & Serial Transmission Engine (tx_zdle.inc)
; Shared between rz.asm and sz.asm for CP/M 3
;============================================================================

;============================================================================
; Function : tx_zdle_escaped_char
; Purpose  : Transmit byte over serial, escaping control chars with ZDLE
; Inputs   : A = character byte to send
; Outputs  : Byte (or ZDLE + escaped byte) transmitted
; Modifies : A, BC, HL
;============================================================================
tx_zdle_escaped_char:
tx_hex_byte_loop_1:
; SMC WRITER: Patches immediate operand of ld a, imm at tx_char_direct (patch_tx_char_byte)
	ld	(patch_tx_char_byte), a	; Store byte into SMC direct transmission operand
	ld	bc, +(hex_byte_jump_vector-hex_byte_char_table) ; Table size
	ld	hl, hex_byte_char_table	; Search characters requiring escaping (CAN, CR, DLE, XON, XOFF)
	cpir				; Match character
	jp	z, dispatch_table_jump	; If in table, dispatch to escape handler
	and	60h			; Check if control character (bits 5-6 zero)
	jr	nz, tx_char_direct	; Not control character: transmit directly
	ld	a, (esc_ctrl_chars_flag) ; Check if receiver requested escaping control chars
	or	a
	jr	z, tx_char_direct	; If not requested, transmit directly

tx_zdle_escape_prefix:
tx_hex_byte_call_1:
; SMC WRITER: Modifies bit 6 of immediate operand at patch_tx_char_byte
	ld	hl, patch_tx_char_byte	; HL points to byte operand
	set	6, (hl)			; Invert/set bit 6 to escape control character
	ld	a, ZDLE			; Transmit ZDLE escape byte (18h)
	call	comm_tx_char_wait

; SMC TARGET: Patched by ld (patch_tx_char_byte), a and set 6, (hl) above
patch_tx_char_byte:	.equ	$+1	; SMC: direct character byte operand
tx_char_direct:
tx_hex_byte_call_2:
	ld	a, 0			; Byte to transmit
comm_tx_char_wait:
; SMC WRITER: Patches immediate operand of ld a, imm at line below (patch_tx_wait_flag)
	ld	(patch_tx_wait_flag), a	; Store into transmit wait operand
comm_tx_char_w_poll:
comm_tx_char_w_call_1:
	call	rx_buffer_poll		; Service background receive FIFO
	call	aux_tx_ready		; Check if AUX transmitter is ready
	jr	z, comm_tx_char_w_poll	; Wait until UART transmitter ready

; SMC TARGET: Patched by ld (patch_tx_wait_flag), a above
patch_tx_wait_flag:	.equ	$+1	; SMC: character to transmit operand
	ld	a, 0			; Load character
	jp	aux_tx_char		; Output character to AUX port

comm_tx_char_w_esc_test:
comm_tx_char_w_br_1:
	ld	a, (patch_tx_wait_flag)	; Load byte
	and	7Fh			; Mask bit 7
	cp	40h			; Compare with 40h ('@')
	jr	nz, tx_char_direct	; Transmit directly
	jr	tx_zdle_escape_prefix	; Escape character

hex_byte_char_table:
	.db	18h			; ZDLE (CAN)
	.db	0Dh			; CR
	.db	8Dh			; CR | 80h
	.db	10h			; DLE
	.db	90h			; DLE | 80h
	.db	11h			; XON
	.db	91h			; XON | 80h
	.db	13h			; XOFF
	.db	93h			; XOFF | 80h

hex_byte_jump_vector:
	.dw	tx_zdle_escape_prefix
	.dw	tx_zdle_escape_prefix
	.dw	tx_zdle_escape_prefix
	.dw	tx_zdle_escape_prefix
	.dw	tx_zdle_escape_prefix
	.dw	tx_zdle_escape_prefix
	.dw	comm_tx_char_w_esc_test
	.dw	comm_tx_char_w_esc_test
	.dw	tx_zdle_escape_prefix

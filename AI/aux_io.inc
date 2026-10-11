;============================================================================
; aux_io.inc - Serial Auxiliary Port Character I/O & Timeout Polling Layer
;============================================================================
; Shared between rz.asm and sz.asm (100% byte-for-byte binary parity).
;
; Routines:
;   - aux_tx_char: Transmit single byte to AUX port (BDOS 4 A_WRITE)
;   - aux_tx_ready: Check AUX port transmit status (BDOS 8 A_STATOUT)
;   - rx_byte_timeout: Receive character with retry loop and timeout
;   - delay / comm_tx_char_raw: Spin-loop delay slice (~a few ms)
;============================================================================

;============================================================================
; Function : aux_tx_char
; Purpose  : Send character in A to auxiliary output port (BDOS 4 A_WRITE)
; Inputs   : A = character to transmit
; Outputs  : Character sent to AUX port
; Modifies : C, DE
;============================================================================
aux_tx_char:
		ld	c, A_WRITE		; BDOS Function 4: Auxiliary output write
		ld	e, a			; E = character to transmit
		jp	bdos			; Transmit character and return

;----------------------------------------------------------------------------
; Function : aux_tx_ready
; Purpose  : Check AUX port output status (BDOS 8 A_STATOUT)
; Inputs   : None
; Outputs  : A = 0 if not ready, NZ if ready to transmit
; Modifies : A, C
;----------------------------------------------------------------------------
aux_tx_ready:
		ld	c, A_STATOUT		; BDOS Function 8: Auxiliary output status
		call	bdos			; Query serial hardware output ready status
		or	a			; Test status in A (0 = busy, FFh = ready)
		ret				; Return with Z flag set if busy, NZ if ready
; End of function aux_tx_ready

;----------------------------------------------------------------------------
; Function : rx_byte_timeout
; Purpose  : Receive character from AUX port with timeout and retries
; Inputs   : None
; Outputs  : A = character, NZ on success, Z on timeout
; Modifies : A, BC
;----------------------------------------------------------------------------
rx_byte_timeout:
		push	bc			; Preserve BC
		ld	b, 5Fh			; Set retry countdown loop counter (~95 iterations)

rx_byte_retry_loop:
		push	bc			; Preserve retry countdown
		call	rx_buffer_poll		; Poll AUX port and buffer any available bytes
		pop	bc			; Restore retry countdown
		jr	nz, rx_byte_have_char	; Character available, exit polling loop
		call	delay			; Spin-loop delay slice
		djnz	rx_byte_retry_loop	; Decrement retry counter and continue waiting
		call	rx_buffer_poll		; Final poll check after retry count exhausted

rx_byte_have_char:
		call	nz, rx_buffer_get_byte	; If byte ready (NZ), fetch it into A
		pop	bc			; Restore BC
		ret				; Return character in A (NZ=success, Z=timeout)
; End of function rx_byte_timeout

;----------------------------------------------------------------------------
; Function : delay / comm_tx_char_raw
; Purpose  : Busy-wait calibrated delay slice (4 * 256 * 13 T-states)
; Inputs   : None
; Outputs  : None
; Modifies : A, BC
;----------------------------------------------------------------------------
delay:
comm_tx_char_raw:
		push	bc			; Preserve BC
		ld	a, 4			; Outer delay loop count = 4
		ld	b, 0			; Inner loop count = 256 iterations

delay_loop:
tx_raw_delay_loop:
		djnz	delay_loop		; Inner loop: 256 * 13 T-states
		dec	a			; Decrement outer loop count
		jr	nz, delay_loop		; Loop until outer count reaches 0
		pop	bc			; Restore BC
		ret				; Return
; End of function delay

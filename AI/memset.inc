;============================================================================
; memset.inc - Byte Memory Fill Subroutines
;============================================================================
; Shared between rz.asm and sz.asm (100% byte-for-byte binary parity).
;
; Routines:
;   - memset_buffer / fill_bhla: Fill memory at HL for B bytes with byte in A (preserves HL)
;   - memset_loop / fill_1: Fill memory at HL for B bytes with byte in A (advances HL, modifies B)
;============================================================================

;============================================================================
; Function : memset_buffer / fill_bhla
; Purpose  : Fill memory buffer at HL for B bytes with byte in A (preserves HL)
; Inputs   : HL = buffer pointer, B = count, A = fill value
; Outputs  : Buffer filled, HL preserved
; Modifies : All registers except HL
;============================================================================
memset_buffer:
fill_bhla:
		push	hl			; Preserve HL
		call	memset_loop		; Fill memory
		pop	hl			; Restore HL
		ret				; Return
; End of function memset_buffer / fill_bhla

;----------------------------------------------------------------------------
; Function : memset_loop / fill_1
; Purpose  : Fill memory at HL for B bytes with byte in A
; Inputs   : HL = buffer pointer, B = count, A = fill value
; Outputs  : Memory filled, HL advanced past buffer, B = 0
; Modifies : B, HL
;----------------------------------------------------------------------------
memset_loop:
fill_1:
		push	bc			; Preserve BC

memset_loop_loop_1:
fill_1_loop_1:
		ld	(hl), a			; Store byte into buffer
		inc	hl			; Advance pointer
		djnz	memset_loop_loop_1	; Loop for all B bytes
		pop	bc			; Restore BC
		ret				; Return
; End of function memset_loop / fill_1

;============================================================================
; 32-Bit Arithmetic & Memory Utility Library (math32.inc)
; Shared between rz.asm and sz.asm for CP/M 3
;============================================================================

;============================================================================
; Function : clear_4bytes
; Purpose  : Zero out 4 consecutive bytes at address HL
; Inputs   : HL = pointer to 4-byte buffer
; Outputs  : 4 bytes set to 0
; Modifies : A, BC, DE, HL
;============================================================================
clear_4bytes:
	xor	a			; A = 00h (clear value)
	push	bc			; Preserve BC
	push	de			; Preserve DE
	push	hl			; Preserve HL
	ld	(hl), a			; Zero out first byte
	ld	d, h			; DE = HL + 1 (destination for block clear)
	ld	e, l
	inc	de
	jr	copy_4bytes_loop	; Propagate zero across remaining 3 bytes via LDI

;============================================================================
; Function : copy_4bytes
; Purpose  : Copy 4 consecutive bytes from HL to DE
; Inputs   : HL = source, DE = destination
; Outputs  : 4 bytes copied
; Modifies : BC, DE, HL
;============================================================================
copy_4bytes:
	push	bc			; Preserve BC
	push	de			; Preserve DE
	push	hl			; Preserve HL
	ldi				; Copy byte 1: (DE) = (HL), increment pointers, dec BC
copy_4bytes_loop:
	ldi				; Copy byte 2
	ldi				; Copy byte 3
	ldi				; Copy byte 4
	pop	hl			; Restore HL
	pop	de			; Restore DE
	pop	bc			; Restore BC
	ret				; Return

;============================================================================
; Function : cmp_pos32
; Purpose  : Signed/magnitude comparison of two 32-bit values at HL and DE
; Inputs   : HL = first 32-bit value, DE = second 32-bit value
; Outputs  : Flags set according to signed comparison
; Modifies : A, F, IX, IY
;============================================================================
cmp_pos32:
	push	hl			; Point IX to first 32-bit value
	pop	ix
	push	de			; Point IY to second 32-bit value
	pop	iy
	ld	a, (ix+3)		; Compare most significant bytes (signs)
	xor	(iy+3)
	jp	p, cmp_pos32_diff	; If signs are identical, do unsigned compare
	xor	(ix+3)			; Restore sign byte
cmp_pos32_exit:
	ret	m			; If negative, return with sign flag
	ccf				; Invert carry flag
	ret				; Return

cmp_pos32_diff:
	xor	(ix+3)			; Restore sign byte
	jp	p, cmp32		; If positive, perform standard 32-bit subtract compare
	call	cmp32			; Perform 32-bit compare
	scf				; Set carry flag
	jr	cmp_pos32_exit		; Exit compare

;============================================================================
; Function : cmp32
; Purpose  : 32-bit unsigned magnitude compare: (DE) - (HL)
; Inputs   : DE, HL = pointers to 32-bit integers (little-endian)
; Outputs  : Carry / Zero flags set based on comparison
; Modifies : A, B
;============================================================================
cmp32:
	push	bc			; Preserve BC
	push	de			; Preserve DE
	push	hl			; Preserve HL
	ex	de, hl			; Swap pointers so HL = minuend, DE = subtrahend
	or	a			; Clear carry flag
	ld	b, 4			; Compare 4 bytes
cmp32_loop:
	ld	a, (de)			; Load subtrahend byte
	sbc	a, (hl)			; Subtract with borrow minuend byte
	inc	de			; Advance subtrahend pointer
	inc	hl			; Advance minuend pointer
	djnz	cmp32_loop		; Repeat for all 4 bytes
	pop	hl			; Restore HL
	pop	de			; Restore DE
	pop	bc			; Restore BC
	ret				; Return with condition flags

;============================================================================
; Function : cmp_4bytes_eq
; Purpose  : Compare 4 bytes at HL and DE for equality
; Inputs   : HL, DE = pointers to 4-byte buffers
; Outputs  : Z set if equal, NZ if unequal
; Modifies : A, B, DE, HL
;============================================================================
cmp_4bytes_eq:
	push	bc			; Preserve BC
	push	de			; Preserve DE
	push	hl			; Preserve HL
	ld	b, 4			; Compare 4 bytes
cmp_4bytes_loop:
	ld	a, (de)			; Load byte from first buffer
	xor	(hl)			; Compare with byte from second buffer
	jr	nz, cmp_4bytes_done	; If mismatch found, exit with NZ
	inc	de			; Advance first pointer
	inc	hl			; Advance second pointer
	djnz	cmp_4bytes_loop		; Repeat for all 4 bytes
cmp_4bytes_done:
	pop	hl			; Restore HL
	pop	de			; Restore DE
	pop	bc			; Restore BC
	ret				; Return with Z set if identical, NZ if different

;============================================================================
; Function : add32
; Purpose  : 32-bit addition: (BC) = (HL) + (DE) with carry
; Inputs   : HL, DE = 32-bit addends, BC = destination pointer
; Outputs  : 32-bit sum stored at (BC)
; Modifies : A, BC, DE, HL
;============================================================================
add32:
	push	bc			; Preserve destination pointer BC
	push	de			; Preserve addend pointer DE
	push	hl			; Preserve addend pointer HL
	or	a			; Clear carry flag
	ex	af, af'			; Save cleared carry in alternate AF
	ld	a, 4			; 4 bytes to add (32 bits)
add32_loop:
	ex	af, af'			; Restore carry from previous byte addition
	ld	a, (de)			; Load addend byte from (DE)
	adc	a, (hl)			; Add with carry addend byte from (HL)
	ld	(bc), a			; Store sum byte to destination (BC)
	inc	bc			; Advance destination pointer
	inc	de			; Advance source pointer 1
	inc	hl			; Advance source pointer 2
	ex	af, af'			; Preserve carry in alternate AF
	dec	a			; Decrement loop byte count
	jr	nz, add32_loop		; Continue for all 4 bytes
	pop	hl			; Restore HL
	pop	de			; Restore DE
	pop	bc			; Restore BC
	ret				; Return

;============================================================================
; Function : sub32
; Purpose  : 32-bit subtraction: (BC) = (HL) - (DE) with borrow
; Inputs   : HL = minuend, DE = subtrahend, BC = destination
; Outputs  : 32-bit difference stored at (BC)
; Modifies : A, BC, DE, HL
;============================================================================
sub32:
	push	bc			; Preserve destination pointer BC
	push	de			; Preserve subtrahend pointer DE
	push	hl			; Preserve minuend pointer HL
	ex	de, hl			; Swap so DE = minuend, HL = subtrahend
	or	a			; Clear borrow / carry flag
	ex	af, af'			; Save cleared borrow in alternate AF
	ld	a, 4			; 4 bytes to subtract (32 bits)
sub32_loop:
	ex	af, af'			; Restore borrow from previous byte subtraction
	ld	a, (de)			; Load minuend byte from (DE)
	sbc	a, (hl)			; Subtract with borrow subtrahend byte from (HL)
	ld	(bc), a			; Store difference byte to destination (BC)
	inc	bc			; Advance destination pointer
	inc	hl			; Advance subtrahend pointer
	inc	de			; Advance minuend pointer
	ex	af, af'			; Preserve borrow in alternate AF
	dec	a			; Decrement loop byte count
	jr	nz, sub32_loop		; Continue for all 4 bytes
	ex	af, af'			; Restore final borrow flag
	pop	hl			; Restore HL
	pop	de			; Restore DE
	pop	bc			; Restore BC
	ret				; Return with borrow flag in carry

;============================================================================
; Function : inc32
; Purpose  : 32-bit increment: increment 32-bit integer at (HL)
; Inputs   : HL = pointer to 32-bit integer (little-endian)
; Outputs  : (HL) incremented by 1
; Modifies : A, BC
;============================================================================
inc32:
	push	bc			; Preserve BC
	push	hl			; Preserve HL
	ld	a, 1			; Add 1 to lowest byte
	add	a, (hl)
	ld	(hl), a			; Store updated low byte
	jr	nc, inc32_done		; If no overflow, increment complete
	ld	b, 3			; Ripple carry through remaining 3 bytes
inc32_ripple:
	inc	hl			; Advance to next higher byte
	ld	a, 0			; Add carry bit
	adc	a, (hl)
	ld	(hl), a			; Store updated byte
	djnz	inc32_ripple		; Repeat for remaining bytes
inc32_done:
	pop	hl			; Restore HL
	pop	bc			; Restore BC
	ret				; Return

;============================================================================
; Function : dec32_zero
; Purpose  : Clear 4 bytes and decrement 32-bit value at (HL)
; Inputs   : HL = pointer to 32-bit buffer
; Outputs  : Buffer initialized and decremented to -1 (0xFFFFFFFF)
; Modifies : A, B, HL
;============================================================================
dec32_zero:
	call	clear_4bytes		; Zero out 4 bytes at HL
;============================================================================
; Function : dec32
; Purpose  : 32-bit decrement: decrement 32-bit integer at (HL)
; Inputs   : HL = pointer to 32-bit integer
; Outputs  : (HL) decremented by 1
; Modifies : A, B, HL
;============================================================================
dec32:
	push	bc			; Preserve BC
	push	hl			; Preserve HL
	ld	a, (hl)			; Load low byte
	sub	1			; Subtract 1 from lowest byte
	ld	(hl), a			; Store updated low byte
	ld	b, 3			; Ripple borrow through upper 3 bytes
dec32_ripple:
	inc	hl			; Advance to next higher byte
	ld	a, (hl)			; Load byte
	sbc	a, 0			; Subtract borrow bit
	ld	(hl), a			; Store updated byte
	djnz	dec32_ripple		; Repeat for remaining bytes
	pop	hl			; Restore HL
	pop	bc			; Restore BC
	ret				; Return

;============================================================================
; Function : and32
; Purpose  : 32-bit bitwise AND: (BC) = (HL) AND (DE)
; Inputs   : HL, DE = 32-bit operands, BC = destination pointer
; Outputs  : Result stored at (BC)
; Modifies : A, BC, DE, HL
;============================================================================
and32:
	push	bc			; Preserve destination pointer BC
	push	de			; Preserve source pointer DE
	push	hl			; Preserve source pointer HL
	ex	de, hl			; DE = source 1, HL = source 2
	ld	a, 4			; Process 4 bytes (32 bits)
and32_loop:
	push	af			; Preserve byte counter
	ld	a, (de)			; Load byte from source 1
	and	(hl)			; Bitwise AND with byte from source 2
	ld	(bc), a			; Store result byte into destination
	inc	bc			; Advance destination pointer
	inc	de			; Advance source 1 pointer
	inc	hl			; Advance source 2 pointer
	pop	af			; Restore byte counter
	dec	a			; Decrement byte counter
	jr	nz, and32_loop		; Repeat for all 4 bytes
	pop	hl			; Restore HL
	pop	de			; Restore DE
	pop	bc			; Restore BC
	ret				; Return

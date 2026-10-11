;============================================================================
; Zmodem CRC-16 and CRC-32 Engine (crc.inc)
; Shared between rz.asm and sz.asm for CP/M 3
;============================================================================

;----------------------------------------------------------------------------
; CRC-32 Polynomial Tables (Reversed IEEE 802.3 0xEDB88320)
;----------------------------------------------------------------------------
crc32_poly_rev:	.db	20h, 83h, 0B8h, 0EDh	; Polynomial coefficients (reversed)
crc32_final_xor:.db	0E3h, 20h, 0BBh, 0DEh	; Final residue XOR mask

;============================================================================
; Function : crc32_acc_update / crc32_update
; Purpose  : Update 32-bit Zmodem CRC with byte in A using table lookup
; Inputs   : A = byte to process
; Outputs  : (crc32_acc) updated with new 32-bit CRC
; Modifies : A, BC, HL, IX, IY
;============================================================================
crc32_acc_update:
crc32_update:
		push	af			; Preserve input byte/flags on stack
crc32_table_base:	.equ	$+2		; SMC: 16-bit base address of generated CRC-32 table
patch_crc32_table_base:	.equ	crc32_table_base		; SMC: 16-bit base address of generated CRC-32 table
		ld	iy, crc32_table		; IY points to CRC-32 table in RAM
		ld	ix, crc32_acc		; IX points to 32-bit CRC accumulator
		xor	(ix+0)			; Index = input byte XOR lowest CRC byte
		ld	h, 0			; HL = table entry index * 4
		ld	l, a
		add	hl, hl			; Multiply index by 2
		add	hl, hl			; Multiply index by 4
		ld	b, h			; BC = index * 4
		ld	c, l
		add	iy, bc			; IY points to 4-byte CRC table entry
		ld	a, (iy+0)		; Byte 0: Table[0] XOR CRC[1]
		xor	(ix+1)
		ld	(ix+0), a		; Store updated CRC byte 0
		ld	a, (iy+1)		; Byte 1: Table[1] XOR CRC[2]
		xor	(ix+2)
		ld	(ix+1), a		; Store updated CRC byte 1
		ld	a, (iy+2)		; Byte 2: Table[2] XOR CRC[3]
		xor	(ix+3)
		ld	(ix+2), a		; Store updated CRC byte 2
		ld	a, (iy+3)		; Byte 3: Table[3]
		ld	(ix+3), a		; Store updated CRC byte 3
		pop	af			; Restore original AF
		ret				; Return

;----------------------------------------------------------------------------

;============================================================================
; Function : build_crc32_table
; Purpose  : Dynamically generate 1KB Zmodem CRC-32 lookup table
; Inputs   : None
; Outputs  : CRC-32 table generated in RAM at (crc32_table_base)
; Modifies : A, B, DE, HL, IX, IY
;
; C-Equivalent Algorithm:
;   void build_crc32_table(uint32_t *table) {
;       for (int i = 0; i < 256; i++) {
;           uint32_t c = i;
;           for (int b = 0; b < 8; b++) {
;               if (c & 1) c = 0xEDB88320L ^ (c >> 1);
;               else       c = c >> 1;
;           }
;           table[i] = ~c;
;       }
;   }
;============================================================================
build_crc32_table:
		push	de			; Preserve DE
		push	hl			; Preserve HL
		ld	hl, (crc32_table_base)	; HL = base address of 1024-byte CRC table buffer
		ld	bc, 3FFh		; 1023 (3FFh) bytes offset to end of table
		add	hl, bc			; HL points to last byte of CRC table buffer
		push	hl			; Transfer table top pointer into IY
		pop	iy
		ld	ix, crc32_poly_rev	; IX points to reversed CRC-32 polynomial
		xor	a			; Initialize table index loop (counts down from 255)

build_crc32_outer:
		push	af			; Preserve outer entry loop counter
		ld	hl, 0FFFFh		; Initialize seed registers
		ld	de, 0FFFFh
		xor	e			; Seed low byte with current entry index
		ld	e, a
		ld	b, 8			; 8 bits per byte

build_crc32_inner:
		scf				; Shift seed right by 1 bit with carry
		rr	h
		rr	l
		rr	d
		rr	e
		jr	nc, build_crc32_store	; If bit shifted out was 0, skip polynomial XOR
		ld	a, e			; XOR low byte with polynomial byte 0
		xor	(ix+0)
		ld	e, a
		ld	a, d			; XOR byte 1 with polynomial byte 1
		xor	(ix+1)
		ld	d, a
		ld	a, l			; XOR byte 2 with polynomial byte 2
		xor	(ix+2)
		ld	l, a
		ld	a, h			; XOR high byte with polynomial byte 3
		xor	(ix+3)
		ld	h, a

build_crc32_store:
		djnz	build_crc32_inner	; Process all 8 bits
		ld	a, h			; One's complement high byte
		cpl	
		ld	(iy+0), a		; Store high byte in table
		dec	iy			; Move down 1 byte
		ld	a, l			; One's complement byte 2
		cpl	
		ld	(iy+0), a		; Store byte 2 in table
		dec	iy			; Move down 1 byte
		ld	a, d			; One's complement byte 1
		cpl	
		ld	(iy+0), a		; Store byte 1 in table
		dec	iy			; Move down 1 byte
		ld	a, e			; One's complement low byte
		cpl	
		ld	(iy+0), a		; Store low byte in table
		dec	iy			; Move down 1 byte
		pop	af			; Restore outer loop counter
		inc	a			; Increment entry index
		jr	nz, build_crc32_outer	; Repeat for all 256 table entries (1024 bytes)
		pop	hl			; Restore HL
		pop	de			; Restore DE
		ret				; Return

;----------------------------------------------------------------------------

;============================================================================
; Function : crc16
; Purpose  : Update 16-bit CRC-CCITT accumulator with byte in A
; Inputs   : A = byte to process
; Outputs  : (crc_seed) / (crc16_seed+1) updated
; Modifies : A, B, DE, HL
; Notes    : Standard CCITT polynomial 1021h (x^16 + x^12 + x^5 + 1).
;            Uses self-modifying code operand at crc_seed / crc16_seed+1.
;============================================================================
crc16:
		push	af			; Preserve input byte/flags on stack
crc16_seed:
crc_seed:	.equ	$+1			; SMC patch point: running CRC in HL
		ld	hl, 0			; SMC: Running CRC-16 accumulator operand
		ld	de, 1021h		; CCITT CRC-16 polynomial generator (x^16 + x^12 + x^5 + 1)
		xor	h			; XOR input byte with current high byte of CRC
		ld	h, a			; Store XOR result into high byte of CRC
		ld	b, 8			; Process 8 bits

crc16_bit_loop:
		add	hl, hl			; Shift CRC left by 1 bit (HL << 1)
		jr	nc, crc16_next_bit	; If no carry shifted out, skip polynomial XOR
		ld	a, h			; XOR high byte with polynomial high byte (10h)
		xor	d
		ld	h, a
		ld	a, l			; XOR low byte with polynomial low byte (21h)
		xor	e
		ld	l, a

crc16_next_bit:
		djnz	crc16_bit_loop		; Process all 8 bits
		ld	(crc16_seed+1), hl	; Store updated CRC-16 back into SMC operand
		pop	af			; Restore AF
		ret				; Return

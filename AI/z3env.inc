;============================================================================
; ZCPR3 / Z-System Environment Descriptor Library (z3env.inc)
; Shared between rz.asm and sz.asm for CP/M 3
;============================================================================

;============================================================================
; Function : get_fcb_ext_ptr
; Purpose  : Read Wheel byte offset (+2Eh) from Z3ENV descriptor
; Inputs   : HL = FCB pointer
; Outputs  : A = Wheel byte (00h = normal user, FFh = privileged wheel)
; Modifies : A, DE, HL
;============================================================================
get_fcb_ext_ptr:
	push	hl			; Preserve HL
	push	de			; Preserve DE
	ld	de, 2Eh			; Offset 2Eh in Z3ENV (WHEEL byte)
	jp	fcb_field_get_offset	; Read byte from Z3ENV descriptor

;============================================================================
; Function : get_fcb_name_ptr
; Purpose  : Read Maximum Drive offset (+2Ch) from Z3ENV descriptor
; Inputs   : HL = FCB pointer
; Outputs  : A = Maximum drive number
; Modifies : A, DE, HL
;============================================================================
get_fcb_name_ptr:
	push	hl			; Preserve HL
	push	de			; Preserve DE
	ld	de, 2Ch			; Offset 2Ch in Z3ENV (MDRV = max drive)
	jp	fcb_field_get_offset	; Read byte from Z3ENV descriptor

;============================================================================
; Function : get_fcb_drive_ptr
; Purpose  : Read Maximum User offset (+2Dh) from Z3ENV descriptor
; Inputs   : HL = FCB pointer
; Outputs  : A = Maximum user area number
; Modifies : A, DE, HL
;============================================================================
get_fcb_drive_ptr:
	push	hl			; Preserve HL
	push	de			; Preserve DE
	ld	de, 2Dh			; Offset 2Dh in Z3ENV (MUSR = max user)
	jp	fcb_field_get_offset	; Read byte from Z3ENV descriptor

;============================================================================
; Function : get_fcb_record_ptr
; Purpose  : Read Named Directory Table pointer (+15h) from Z3ENV descriptor
; Inputs   : DE = FCB pointer
; Outputs  : HL = pointer to Named Directory Table, A = count byte
; Modifies : A, DE, HL
;============================================================================
get_fcb_record_ptr:
	push	de			; Preserve DE
	ld	de, 15h			; Offset 15h in Z3ENV (NDR = named dir table ptr)
	jp	fcb_rec_get_offset	; Read 16-bit word pointer from Z3ENV

;----------------------------------------------------------------------------

fcb_field_get_offset:
	ld	hl, (z3env_ptr)		; HL = pointer to Z3ENV descriptor
	ld	a, h			; Check if pointer is null (0000h)
	or	l
	jr	z, fcb_field_ret_val	; If null, return 0
	add	hl, de			; Add field offset to base
fcb_field_ret_val:
	ld	a, (hl)			; Fetch byte from descriptor
	pop	de			; Restore DE
	pop	hl			; Restore HL
	or	a			; Set condition flags
	ret				; Return

;----------------------------------------------------------------------------

fcb_rec_get_offset:
	ld	hl, (z3env_ptr)		; HL = pointer to Z3ENV descriptor
	add	hl, de			; Add offset (15h)
	ld	e, (hl)			; Load low byte of pointer
	inc	hl			; Advance pointer
	ld	d, (hl)			; Load high byte of pointer
	inc	hl			; Advance pointer
	ld	a, (hl)			; Load count byte
	ex	de, hl			; HL = target table address
	pop	de			; Restore DE
	or	a			; Set flags
	ret				; Return

;============================================================================
; Function : init_z3env_descriptor
; Purpose  : Save Z3ENV (Z-System environment descriptor) pointer
; Inputs   : HL = Z3ENV pointer
; Outputs  : z3env_ptr updated
; Modifies : None
;============================================================================
init_z3env_descriptor:
	ld	(z3env_ptr), hl		; Save Z-System environment descriptor address
	ret				; Return

;============================================================================
; drive_user.inc - CP/M Active Drive and User Number Management
;============================================================================
; Shared between rz.asm and sz.asm (100% byte-for-byte binary parity).
;
; Routines:
;   - get_init_drive_user: Reads initial drive and user from CP/M Page 0 IOBYTE
;   - set_drive_user: Selects active drive (BDOS 14) and user area (BDOS 32)
;============================================================================

;============================================================================
; Function : get_init_drive_user
; Purpose  : Read default drive and user area from CP/M IOBYTE (0004h)
; Inputs   : None
; Outputs  : saved_user_num=user (0..15), saved_drive_num=drive (1=A..)
; Modifies : A, B, HL
;============================================================================
get_init_drive_user:
		ld	a, (iobyte)		; Load default drive/user byte from 0004h
		ld	b, a			; Preserve original byte in B
		rlca				; Rotate high nibble (user number) into low nibble
		rlca
		rlca
		rlca
		and	0Fh			; Mask to 0..15 range
		ld	(saved_user_num), a	; Save initial user number
		ld	a, b			; Restore original I/O byte
		and	0Fh			; Mask low nibble (drive number: 0=A, 1=B...)
		inc	a			; Convert 0-based drive to 1-based (1=A, 2=B...)
		ld	(saved_drive_num), a	; Save initial drive number
		ld	hl, (saved_user_num)	; HL = packed initial (saved_user_num, saved_drive_num)
; SMC WRITER: Patches immediate operand of ld bc, imm at program exit (patch_exit_drive_user)
		ld	(patch_exit_drive_user), hl ; Patch SMC exit restore operand (ld bc, ...)
		ret				; Return
; End of function get_init_drive_user

;----------------------------------------------------------------------------
; Function : set_drive_user
; Purpose  : Set current CP/M drive (BDOS 14) and user number (BDOS 32)
; Inputs   : (DE) contains packed user/drive word
; Outputs  : Drive and user selected in CP/M BDOS
; Modifies : A, C, DE
;----------------------------------------------------------------------------
set_drive_user:
		ld	a, (de)			; Load drive number byte (1-based: 1=A, 2=B...)
		push	af			; Preserve drive number on stack
		dec	de			; Point back to user number byte
		ld	a, (de)			; Load user number (0..15)
		ld	e, a			; E = user number parameter for BDOS
		ld	c, F_USERNUM		; BDOS Function 32: Set/get user code
		call	bdos			; Set active user number
		pop	af			; Restore drive number
		dec	a			; Convert 1-based drive (1=A) to 0-based (0=A)
		ld	e, a			; E = drive number parameter for BDOS
		ld	c, DRV_SET		; BDOS Function 14: Select disk drive
		jp	bdos			; Select active drive and return
; End of function set_drive_user

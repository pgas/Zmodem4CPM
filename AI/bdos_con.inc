;============================================================================
; CP/M BDOS Console and Dispatcher Library (bdos_con.inc)
; Shared between rz.asm and sz.asm for CP/M 3
;============================================================================

;============================================================================
; Function : bdos_con_read
; Purpose  : Read character from console directly (BDOS 1 C_READ)
; Inputs   : None
; Outputs  : A = console character
; Modifies : A, BC, DE, HL
;============================================================================
bdos_con_read:
	ld	a, C_READ		; BDOS Function 1: Console input
	jp	bdos_sys_call		; Call BDOS and return

;============================================================================
; Function : bdos_con_stat
; Purpose  : Check console input status (BDOS 11 C_STAT)
; Inputs   : None
; Outputs  : A = 0 if no key ready, 0FFh if key available
; Modifies : A, BC, DE, HL
;============================================================================
bdos_con_stat:
	ld	a, C_STAT		; BDOS Function 11: Console status
	jp	bdos_sys_call		; Call BDOS and return

;============================================================================
; Function : bdos_con_write_char (also aliased as bdos_s2)
; Purpose  : Low-level BDOS wrapper invoking Function C with parameter E
; Inputs   : C = function code, E = parameter
; Outputs  : A = return value, Zero flag set accordingly
; Modifies : A, F
;============================================================================
bdos_con_write_char:
bdos_s2:
	push	de			; Preserve DE
	push	bc			; Preserve BC
	call	bdos			; Call BDOS function
	pop	bc			; Restore BC
	pop	de			; Restore DE
	or	a			; Test return code in A
	ret				; Return

;============================================================================
; Function : bdos_sys_call (also aliased as bdos_cs3)
; Purpose  : Generic BDOS system call dispatcher with function in A, parameter in DE
; Inputs   : A = function code, DE = parameter
; Outputs  : Return value in A, flags set
; Modifies : A, F
;============================================================================
bdos_sys_call:
bdos_cs3:
	push	hl			; Preserve HL
	push	de			; Preserve DE
	push	bc			; Preserve BC
	ld	c, a			; C = BDOS function number
	call	bdos			; Call BDOS
	or	a			; Test return code in A
	pop	bc			; Restore BC
	pop	de			; Restore DE
	pop	hl			; Restore HL
	ret				; Return

; rz (receive Zmodem) is a disassembly of CP/M 3 binaries by Wilfried Schmitten released in 1992.
; this file is an attempt to reconstruct the Z80 assembler source code which has been lost
; credit to Wilfried Schmitten for writing this program initially

;
; File Name			  C:\RZ.COM
; Format			  COM File
; Base Address:	0000h Range: 0100h - 1800h Loaded length: 1700h

; Processor:	    z80
; Target assembler: Table Driven Assembler (TASM) by Speech Technology Inc.

#include "cpm3.inc"
#include "zmodem.inc"

buf_len:	.equ	80h
rbuf_size	.equ	1000h

;----------------------------------------------------------------------------

		.org	100h

start:
		ld	sp, nstack		; Initialize local private stack pointer
		ld	c, S_BDOSVER		; BDOS Function 12: Query CP/M Version Number
		call	bdos			; Returns version in register A
		cp	30h			; Check if running on CP/M 3.0 or higher
		jp	c, err_vern		; Abort with error message if CP/M 2.2 or earlier

		ld	de, str_welc		; DE points to welcome greeting string
		ld	c, C_WRITESTR		; BDOS Function 9: Write string to console
		call	bdos

		call	get_init_drive_user	; Record initial drive and user area; patch exit handler
		ld	hl, (free_mem_base)	; HL points to base of free heap memory
		xor	a			; Zero out first 20 bytes of free memory
		ld	b, 20			; to ensure clean argument token table
		call	fill_bhla

		ld	a, (buf_len)		; Check character count in CP/M command tail buffer
		or	a			; Is command tail empty?
		jr	z, skip_cl		; If no command-line arguments, wait directly for transfer

; Parse command line arguments:
		ld	(hl), 2			; Set max argument token limit = 2
		ld	de, 82h			; DE points to command line text buffer (0082h)
		ex	de, hl			; HL = 0082h, DE = free memory token table
		ld	a, 0FFh			; Delimiter mask flag
		call	tokenize_cmdline	; Break command line into whitespace-separated tokens
		jp	nz, err_exit		; Syntax error parsing command line

		ld	hl, (free_mem_base)	; Retrieve token table base
		inc	hl			; Check token count byte
		ld	a, (hl)
		or	a
		jp	z, skip_cl		; No tokens found, proceed to transfer loop

		inc	hl			; First argument token entry
		ld	e, (hl)			; DE = pointer to first argument string
		inc	hl
		ld	d, (hl)
		inc	hl
		ld	a, (de)
		cp	'-'			; Does first argument begin with switch prefix?
		jr	nz, start_parse_file	; If not dash, treat argument as destination filespec

		call	parse_options_cmdline	; Parse option switches (?PBCXYZR)
		ld	e, (hl)			; Check for subsequent argument token
		inc	hl
		ld	d, (hl)
		ld	a, d
		or	e
		jr	z, skip_cl		; No second argument, proceed to transfer loop

start_parse_file:
		ld	hl, file_fcb		; Destination FCB structure
		ex	de, hl			; DE = file_fcb, HL = filespec string
		call	parse_cpm_filespec	; Parse filename string into standard CP/M FCB
		ld	hl, file_fcb
		xor	a
		or	(hl)			; Did filespec specify an explicit drive?
		jr	nz, start_have_drive	; If yes, drive is already set
		ld	a, (saved_drive_num)	; Otherwise, use saved default drive number
		ld	(hl), a

start_have_drive:
		ld	bc, 0Dh			; Point to user number field in FCB extension
		add	hl, bc
		dec	de
		ldi				; Store user number into FCB extension
		ld	de, file_fcb
		call	set_drive_user		; Select active drive and user area
		call	clo_c			; Apply option 'c' (clear/initialize receive settings)

;============================================================================
; Main Transfer Execution and Session Cleanup (skip_cl)
; Purpose:
;   1. Prompts the user to start the remote file transfer program.
;   2. Hooks into the CP/M 3 System Control Block (SCB) to intercept critical
;      system error vectors (preventing abrupt crashes on serial break or I/O errors).
;   3. Runs the multi-protocol receive state machine (Zmodem / Ymodem / Xmodem).
;   4. Unhooks CP/M 3 system variables upon session completion or abort.
;   5. Restores the user's initial disk drive and user area via an SMC patch.
;   6. Performs a clean exit back to the CP/M Console Command Processor (CCP).
;============================================================================
skip_cl:
		ld	de, str_sxfr		; DE points to prompt message
		ld	c, C_WRITESTR		; BDOS Function 9: Write string to console
		call	bdos

		call	cpm3_sysvar_hook	; Intercept CP/M 3 SCB error vectors (BDOS 49 S_SYSVAR)
		call	rx_batch_engine		; Execute core multi-protocol receiver engine
		call	cpm3_sysvar_unhook	; Restore original CP/M 3 SCB error vectors

; Self-Modifying Code (SMC) Exit Patch:
; At startup, get_init_drive_user dynamically patched the immediate 16-bit
; value of 'ld bc, 0' below with the caller's original drive and user values.
patch_exit_drive_user:	.equ	$+1		; Points to the immediate 16-bit operand below
start_exit_restore:
		ld	bc, 0			; BC loaded with saved drive and user
		ld	(transfer_state_vars), bc ; Copy to state block (FCB user/drive fields)
		ld	de, file_fcb		; DE points to file_fcb
		call	set_drive_user		; Restore original active disk drive and user area
		jp	cpm			; Warm Boot (0000h): Return control to CP/M CCP


;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

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
		ld	(patch_exit_drive_user), hl ; Patch SMC exit restore operand (ld bc, ...)
		ret				; Return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : set_drive_user
; Purpose  : Set current CP/M drive and user number via BDOS calls
; Inputs   : (DE) contains user/drive packed word
; Outputs  : Drive selected (BDOS 14), User set (BDOS 32)
; Modifies : A, C, DE
;============================================================================
set_drive_user:
		ld	a, (de)			; Load drive number byte (1-based: 1=A, 2=B...)
		push	af			; Preserve drive number on stack
		dec	de			; Point back to user number byte
		ld	a, (de)			; Load user number (0..15)
		ld	e, a			; E = user number parameter for BDOS
		ld	c, F_USERNUM		; BDOS Function 32: Set/get user code
		call	bdos			; Set current user number
		pop	af			; Restore drive number
		dec	a			; Convert 1-based drive (1=A) to 0-based (0=A)
		ld	e, a			; E = drive number parameter for BDOS
		ld	c, DRV_SET		; BDOS Function 14: Select disk drive
		jp	bdos			; Select active drive and return

;----------------------------------------------------------------------------

err_vern:
		ld	de, str_cpm3		; DE points to error message: 'sorry, CP/M 3 Tool\r\n$'
		ld	c, C_WRITESTR		; BDOS Function 9: Write string to console
		call	bdos			; Display version error string

err_exit:
		ld	de, str_info		; DE points to command-line usage summary string
		ld	c, C_WRITESTR		; BDOS Function 9: Write string to console
		call	bdos			; Display usage help string
		jp	cpm			; Warm Boot (0000h): Exit to CP/M CCP

;----------------------------------------------------------------------------

str_welc:	.text	"RZ for CP/M 3   V 1.04\r\n"
		.text	"(C) 92 wshbg\r\n\n$"
str_sxfr:	.text	"start your local X/Y/ZModem sending program\r\n\n$"
str_cpm3:	.text	"sorry, CP/M 3 Tool\r\n$"
str_info:	.text	"usage: rz [-?pbcrxyz] [du:fn]\r\n\n"
		.text	" options for ZModem:\r\n"
		.text	"            ?     this help\r\n"
		.text	"            p     protect File\r\n"
		.text	"            b     receive binary\r\n"
		.text	"            c     convert to local linefeed\r\n"
		.text	"            r     resume transmission\r\n"
		.text	"            x,y,z Protokoll\r\n"
		.text	"            du:fn defaults to XModem\r\n\n"
		.text	"these values override options from sender\r\n$"

;----------------------------------------------------------------------------
;		Search list of command line options

;============================================================================
; Function : parse_options_cmdline
; Purpose  : Parse command line option switches (?PBCXYZR)
; Inputs   : DE = pointer to command line arguments
; Outputs  : Flags set in memory (protocol_mode, etc.)
; Modifies : A, BC, DE, HL
;============================================================================
parse_options_cmdline:
		push	hl			; Preserve token list pointer HL
		push	de			; Preserve argument string pointer DE
parse_clo_loop:
		inc	de			; Advance to next character in argument string
		ld	a, (de)			; Load option switch character
		or	a			; Test for null terminator (end of string)
		jr	z, parse_clo_done	; Finished all characters in switch argument
		ld	hl, cmd_switch_chars	; HL points to search table of valid options
		ld	bc, cmd_switch_count	; BC = number of entries in option table
		cpir				; Search for match; decrements BC on each test
		call	z, dispatch_table_jump	; If match found (Z set), execute corresponding handler
		jr	parse_clo_loop		; Continue scanning next character

parse_clo_done:
		pop	de			; Restore argument string pointer DE
		pop	hl			; Restore token list pointer HL
		ret				; Return to caller

;----------------------------------------------------------------------------
; Command Line Option Switch Dispatch Table
;   cmd_switch_chars: Array of valid single-letter switch characters (?PBCXYZR).
;   cmd_switch_count: Count of characters in search table.
;   Followed by corresponding 16-bit subroutine jump vectors (.dw target).
;   When CPIR matches a character, dispatch_table_jump indexes into the
;   jump vector array using remaining count in BC to execute the option handler.
;----------------------------------------------------------------------------
cmd_switch_chars:	.text	"?PBCXYZR"
cmd_switch_count:	.equ	$-cmd_switch_chars

		.dw	clo_help	; ? -> display help usage text
		.dw	clo_p		; P -> protect file (do not overwrite)
		.dw	clo_b		; B -> receive binary file
		.dw	clo_c		; C -> convert to local CP/M CRLF linefeeds
		.dw	clo_x		; X -> force Xmodem protocol
		.dw	clo_y		; Y -> force Ymodem protocol
		.dw	clo_z		; Z -> force Zmodem protocol
		.dw	err_exit	; R -> resume transmission option / usage error

;----------------------------------------------------------------------------
;		Set flags and options from command line

;----------------------------------------------------------------------------
; Command-Line Option Switch Handlers:
;   clo_c    : Set text conversion mode (protocol_mode = 1)
;   clo_b    : Set binary file receive mode (protocol_mode = 3)
;   clo_p    : Set protect mode (protocol_mode = 4, do not overwrite existing)
;   clo_z    : Force Zmodem protocol (flg_zmdm = 0FFh)
;   clo_y    : Force Ymodem protocol (flg_ymdm = 0FFh)
;   clo_x    : Force Xmodem protocol (flg_xmdm = 0FFh)
;   clo_help : Display help screen flag (flg_help = 0FFh)
;----------------------------------------------------------------------------
clo_c:
		ld	a, 1			; Option 'c': text conversion mode (CRLF translation)
		jr	set_opt			; Store option into protocol_mode
clo_b:
		ld	a, 3			; Option 'b': binary receive mode (raw 8-bit bytes)
		jr	set_opt			; Store option into protocol_mode
clo_p:
		ld	a, 4			; Option 'p': protect mode (do not overwrite existing)
set_opt:
		ld	(protocol_mode), a	; Store selected file transfer mode flag
		ret				; Return

clo_z:
		ld	a, 0FFh			; Option 'z': force Zmodem protocol
		ld	(flg_zmdm), a		; Set Zmodem override flag
		ret				; Return
clo_y:
		ld	a, 0FFh			; Option 'y': force Ymodem protocol
		ld	(flg_ymdm), a		; Set Ymodem override flag
		ret				; Return
clo_x:
		ld	a, 0FFh			; Option 'x': force Xmodem protocol
		ld	(flg_xmdm), a		; Set Xmodem override flag
		ret				; Return
clo_help:
		ld	a, 0FFh			; Option '?': request usage help screen
		ld	(flg_help), a		; Set help display flag
		ret				; Return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : cpm3_sysvar_hook
; Purpose  : Hook CP/M 3 system variables table via BDOS function 49 (S_SYSVAR)
; Inputs   : DE = parameter block (scb_pb_offset)
; Outputs  : HL = pointer to SCB / system variables
; Modifies : A, C, DE, HL
;============================================================================
cpm3_sysvar_hook:
		xor	a			; Clear A
		ld	(scb_pb_reserved), a	; Set parameter block mode byte to 0 (read word)
		ld	(scb_pb_reserved2), a	; Set parameter block mode byte to 0 (read word)
		ld	c, S_SYSVAR		; BDOS Function 49: Get/Set System Variable
		ld	de, scb_pb_offset	; DE points to SCB parameter block (offset 28h)
		call	bdos			; Query SCB variable; returns value in HL
		ld	a, h			; Invert HL to generate bitwise mask
		cpl
		ld	h, a
		ld	a, l
		cpl
		ld	l, a
		ld	(scb_ptr_sysvar), hl	; Store inverted mask word
		ld	c, S_SYSVAR		; BDOS Function 49: Get/Set System Variable
		ld	de, scb_pb_offset2	; DE points to SCB parameter block (offset 24h)
		call	bdos			; Query original error vector 1 into HL
		ld	(scb_hook_vector1), hl	; Save original SCB error vector 1
		ld	de, (scb_ptr_sysvar)	; Load inverted mask into DE
		ld	a, h			; Mask off system interception bits
		and	d
		ld	h, a
		ld	a, l
		and	e
		ld	l, a
		ld	(saved_scb_vector1), hl	; Save modified vector 1 to write back
		ld	c, S_SYSVAR		; BDOS Function 49: Get/Set System Variable
		ld	de, scb_pb_offset3	; DE points to SCB parameter block (offset 22h)
		call	bdos			; Query original break/error vector 2 into HL
		ld	(scb_hook_vector2), hl	; Save original SCB error vector 2
		ld	de, (scb_ptr_sysvar)	; Load inverted mask into DE
		ld	a, h			; Mask off system interception bits
		and	d
		ld	h, a
		ld	a, l
		and	e
		ld	l, a
		ld	(saved_scb_vector2), hl	; Save modified vector 2 to write back
cpm3_sysvar_set_vecs:
		ld	a, 0FEh			; 0FEh = Set word in SCB parameter block
		ld	(scb_pb_reserved2), a	; Set PB mode to write word
		ld	de, scb_pb_offset2	; DE points to SCB PB 2 (offset 24h)
		ld	c, S_SYSVAR		; BDOS Function 49: Get/Set System Variable
		call	bdos			; Write new error vector 1 into SCB
		ld	a, 0FEh			; 0FEh = Set word in SCB parameter block
		ld	(scb_pb_reserved3), a	; Set PB mode to write word
		ld	de, scb_pb_offset3	; DE points to SCB PB 3 (offset 22h)
		ld	c, S_SYSVAR		; BDOS Function 49: Get/Set System Variable
		jp	bdos			; Write new error vector 2 into SCB and return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : cpm3_sysvar_unhook
; Purpose  : Restore CP/M 3 system variables on exit
; Inputs   : None
; Outputs  : System variables restored
; Modifies : A, HL
;============================================================================
cpm3_sysvar_unhook:
		ld	hl, (scb_hook_vector1)	; Load original saved SCB vector 1
		ld	(saved_scb_vector1), hl	; Place into PB write slot
		ld	hl, (scb_hook_vector2)	; Load original saved SCB vector 2
		ld	(saved_scb_vector2), hl	; Place into PB write slot
		jr	cpm3_sysvar_set_vecs	; Write original vectors back to SCB

;----------------------------------------------------------------------------

scb_pb_offset:	.db	28h
scb_pb_reserved:	.db	0
		.db	0
		.db	0
scb_pb_offset2:	.db	24h
scb_pb_reserved2:	.db	0
saved_scb_vector1:	.dw	0
scb_pb_offset3:	.db	22h
scb_pb_reserved3:	.db	0
saved_scb_vector2:	.dw	0
scb_hook_vector1:	.dw	0
scb_hook_vector2:	.dw	0
scb_ptr_sysvar:	.dw	0

;----------------------------------------------------------------------------
;		Call BDOS and set status flag

bdos_s:
		call	bdos			; Invoke BDOS service function in C
		or	a			; Test accumulator return code; set Z/NZ flags
		ret				; Return with condition flags set

;----------------------------------------------------------------------------
;		Search for 0 terminated string starting at HL

Search0:
		push	af			; Preserve AF
Search0_loop:
		push	bc			; Preserve loop counter B on stack
		xor	a			; Search target character = 00h (null terminator)
		ld	b, a			; BC = 0000h (search up to 65,536 bytes)
		ld	c, a
		cpir				; Search memory at HL until null byte found; HL points past null
		pop	bc			; Restore loop counter B
		djnz	Search0_loop		; Repeat search B times (skip past B null strings)
		pop	af			; Restore AF
		ret				; Return with HL pointing past final null terminator

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : print_error_count
; Purpose  : Format and print transfer error count message to console
; Inputs   : None
; Outputs  : Console message displayed
; Modifies : A, C, DE
;============================================================================
print_error_count:
		ld	a, (transfer_err_count)	; Load accumulated transfer error count
		ld	de, text495h		; Destination buffer for formatted number string
		call	byte_to_dec_ascii	; Convert error count byte to 3-digit decimal ASCII
		ld	de, text493h		; DE points to "\r\n" followed by count and " error(s)\r\n$"
		ld	c, C_WRITESTR		; BDOS Function 9: Write string to console
		jp	bdos			; Output error summary string and return

;----------------------------------------------------------------------------

text493h:	.text	"\r\n"
text495h:	.db	0,0,0
		.text	" error(s)\r\n$"

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : print_transfer_file_msg
; Purpose  : Print file transfer announcement header (drive, filename, user)
; Inputs   : DE = file FCB pointer
; Outputs  : Announcement string displayed on console
; Modifies : A, B, C, DE, HL
;============================================================================
print_transfer_file_msg:
		ld	de, file_fcb		; DE points to destination file FCB
		ld	hl, str_colon_colon	; HL points to filename colon separator buffer
		ld	(hl), ':'		; Place drive colon separator
		inc	hl			; Advance to filename buffer
		xor	a			; Fill byte = 00h
		ld	b, 0Dh			; Length = 13 bytes
		call	fill_bhla		; Clear display buffer area with zeroes
		inc	de			; Advance DE past drive byte to filename field (8+3)
		call	format_fcb_name		; Format 8.3 FCB name into display buffer
		dec	de			; Back up DE to drive byte
		ld	a, (de)			; Load 1-based drive number (1=A, 2=B...)
		add	a, 'A'-1		; Convert drive number to ASCII letter
		ld	(str_drive_letter), a	; Store drive letter into display string
		dec	de			; Back up DE to user number byte
		ld	a, (de)			; Load user number (0..15)
		ld	de, str_user_num_buf	; Destination buffer for user number ASCII
		call	byte_to_dec_ascii	; Convert user number to decimal ASCII string
		ld	a, '$'			; String terminator character
		ld	(term_fn), a		; Terminate filename display string
		ld	de, text4F2h		; DE points to formatted announcement header
		ld	c, C_WRITESTR		; BDOS Function 9: Write string to console
		call	bdos			; Print drive, user, and filename header
		ld	hl, (rx_file_info_ptr)	; HL points to remote ZFILE information string
		ld	a, h			; Test if pointer is null (0000h)
		or	l
		ret	z			; If no remote file info string, return
		ld	b, 1			; Skip past first null byte (skip filename)
		call	Search0			; Find file size and attributes sub-string
		dec	hl			; Point back to null byte separator
		ld	(hl), '$'		; Replace null with '$' terminator for BDOS output
		ld	de, (rx_file_info_ptr)	; DE points to remote file info payload
		ld	c, C_WRITESTR		; BDOS Function 9: Write string to console
		call	bdos			; Print remote file size and attributes
		ld	de, newline		; DE points to "\r\n$"
		ld	c, C_WRITESTR		; BDOS Function 9: Write string to console
		jp	bdos			; Print newline and return

;----------------------------------------------------------------------------

text4F2h:	.text	"\r\n"
str_drive_letter:	.db	0			
str_user_num_buf:	.db	0 ;
		.db	0 ;
		.db	0 ;
str_colon_colon:	.db	0 ;
		.db	0 ;
		.db	0 ;
		.db	0 ;
		.db	0 ;
		.db	0 ;
		.db	0 ;
		.db	0 ;
		.db	0 ;
		.db	0 ;
		.db	0 ;
		.db	0 ;
		.db	0 ;
		.db	0 ;
		.db	20h ;
term_fn:	.db	0			
newline:	.text	"\r\n$"

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : print_transfer_stats
; Purpose  : Print transfer statistics and byte count to console
; Inputs   : None
; Outputs  : Statistics string displayed
; Modifies : A, C, DE, HL
;============================================================================
print_transfer_stats:
		ld	hl, rx_char_saved_step_2 ; HL points to 32-bit received byte count
		ld	de, stats_str_buf	; DE points to output buffer for ASCII number
		call	conv_num_to_ascii	; Convert 32-bit count to formatted decimal ASCII
		ld	(hl), '$'		; Append '$' string terminator
		ld	de, text51Eh		; DE points to carriage return and buffer
		ld	c, C_WRITESTR		; BDOS Function 9: Write string to console
		jp	bdos			; Print updated byte count on current line and return

;----------------------------------------------------------------------------
text51Eh:
		.db  0Dh ;
stats_str_buf:	.db    0 ;
		.db    0 ;
		.db    0 ;
		.db    0 ;
		.db    0 ;
		.db    0 ;
		.db    0 ;
		.db    0 ;
		.db    0 ;
		.db    0 ;

disp_bsy:
		ld	hl, str_busy		; HL points to spinner character table: | / - \
patch_stats_digit:	.equ	$+1		; SMC: immediate operand holding current frame index
		ld	a, 0			; Load current spinner frame index (0..3)
		inc	a			; Advance to next frame
		and	3			; Wrap around modulo 4 (0..3)
		ld	(patch_stats_digit), a	; Save updated spinner frame index
		ld	e, a			; E = frame index offset
		ld	d, 0			; D = 0
		add	hl, de			; Index into spinner character array
		ld	a, (hl)			; Load spinner character
		ld	(str_sav), a		; Store character into backspace display string
		ld	de, str_rev		; DE points to spinner string: ' [char]\b\b$'
		ld	c, C_WRITESTR		; BDOS Function 9: Write string to console
		jp	bdos			; Output animated spinner frame and return

str_busy:	.db	7ch		; |
		.db	02fh		; /
		.db	2dh		; -
		.db	5ch 		; \
str_rev:	.db	20h		;
str_sav:	.db	7ch		; |
		.db	08h		; /b
		.db	08h		; /b
		.db	24h		; $

		ld	de, text569h		; String: "can't open any file\r\n$"
		jr	bdos_print_string	; Print string via BDOS Function 9

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : print_file_skipped
; Purpose  : Print 'File skipped' notification string
; Inputs   : None
; Outputs  : Console message displayed
; Modifies : C, DE
;============================================================================
print_file_skipped:
		ld	de, text55Ah		; DE points to 'File skipped\r\n$'
;============================================================================
; Function : bdos_print_string
; Purpose  : Print $-terminated string addressed by DE to console (BDOS 9)
; Inputs   : DE = pointer to $-terminated string
; Outputs  : None
; Modifies : C
;============================================================================
bdos_print_string:
		ld	c, C_WRITESTR		; BDOS Function 9: Write string to console
		jp	bdos			; Output string and return

;----------------------------------------------------------------------------

text55Ah:	.text	"File skipped\r\n$"
text569h:	.text	"can't open any file\r\n$"

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : rx_buffer_init_ptrs
; Purpose  : Initialize receive buffer head/tail pointers and counters
; Inputs   : A, C = initial buffer pointer offsets
; Outputs  : rx_buf_in_idx, rx_buf_count initialized
; Modifies : HL
;============================================================================
rx_buffer_init_ptrs:
		ld	hl, rx_buf_in_idx	; Point HL to buffer input index byte
		ld	(hl), a			; Initialize input index with value in A
		inc	hl			; Advance HL to buffer count byte
		ld	(hl), c			; Initialize buffer count with value in C
		ret				; Return

;----------------------------------------------------------------------------

rx_buf_in_idx:	.db	0
rx_buf_count:	.db	0

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : rx_buffer_poll
; Purpose  : Poll AUX input status (BDOS 7) and buffer received characters
; Inputs   : None
; Outputs  : Z flag set if empty, NZ if character available
; Modifies : A, C, DE, HL
;============================================================================
rx_buffer_poll:
		or	a			; Clear carry flag
		ld	hl, (rbuf_bfree)	; Load current free byte count in receive ring buffer
		ld	de, rbuf_size		; DE = maximum receive ring buffer capacity
		sbc	hl, de			; Test if buffer is full (rbuf_bfree == rbuf_size)
		jr	z, rx_buf_poll_check_cnt ; If buffer is full, do not read; check available count
		ld	c, A_STATIN		; BDOS Function 7: Auxiliary input status
		call	bdos			; Check if serial hardware has a byte waiting
		or	a			; 00h = no character ready, 0FFh = character ready
		jr	z, rx_buf_poll_check_cnt ; If no character ready, check buffered count
		ld	c, A_READ		; BDOS Function 3: Auxiliary input read
		call	bdos			; Read incoming character byte from serial port into A
		ld	c, a			; C = received character byte
		ld	hl, rbuf_bfree		; HL points to ring buffer control header
		call	rx_buffer_put_byte	; Store byte into circular receive buffer
		jr	rx_buffer_poll		; Loop to suck in all available characters from UART

;----------------------------------------------------------------------------

rx_buf_poll_check_cnt:
		ld	hl, rx_buf_count	; HL points to count of unread buffered bytes
		or	(hl)			; Test if single-byte buffer holds a character
		ret	nz			; Return NZ if character ready
		ld	hl, (rbuf_bfree)	; Load buffered count from rbuf_bfree
		ld	a, h			; Check if ring buffer has any queued bytes
		or	l
		ret				; Return Z if empty, NZ if data present

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : rx_buffer_get_byte
; Purpose  : Retrieve next buffered character from receive ring buffer
; Inputs   : None
; Outputs  : A = received character byte
; Modifies : A, HL
;============================================================================
rx_buffer_get_byte:
		ld	a, (rx_buf_count)	; Load unread byte count from single-byte buffer
		or	a			; Is single-byte buffer empty?
		ld	hl, rbuf_bfree		; HL points to ring buffer control block
		jp	z, delay_done		; If empty, read from circular ring buffer
		push	af			; Preserve AF
		ld	hl, rx_buf_count		; HL points to rx_buf_count
		dec	(hl)			; Decrement buffered byte count
		dec	hl			; Point back to rx_buf_in_idx
		pop	af			; Restore AF
		ld	a, (hl)			; Load single-byte buffered character into A
		ret				; Return character in A

;----------------------------------------------------------------------------

aux_tx_char:
		ld	c, A_WRITE		; BDOS Function 4: Auxiliary output write
		ld	e, a			; E = character to transmit
		jp	bdos			; Transmit byte to serial port and return

;----------------------------------------------------------------------------
;	Set I/O byte
;	E=I/O byte
;	S u b r	o u t i	n e

;============================================================================
; Function : aux_tx_ready
; Purpose  : Check AUX port output status (BDOS 8 A_STATOUT)
; Inputs   : None
; Outputs  : A = 0 if not ready, NZ if ready to transmit
; Modifies : A, C
;============================================================================
aux_tx_ready:
		ld	c, A_STAT_OUT		; BDOS Function 8: Auxiliary output status
		call	bdos			; Query serial hardware output ready status
		or	a			; Test status in A (0 = busy, FFh = ready)
		ret				; Return with Z flag set if busy, NZ if ready

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e	; Receive a byte into the receive buffer?

;============================================================================
; Function : rx_byte_timeout
; Purpose  : Receive character from AUX port with timeout and retries
; Inputs   : None
; Outputs  : A = character, NZ on success, Z on timeout
; Modifies : A, BC
;============================================================================
rx_byte_timeout:
		push	bc			; Preserve BC
		ld	b, 5Fh			; Set retry countdown loop counter (~95 iterations)
rx_byte_retry_loop:
		push	bc			; Preserve retry countdown
		call	rx_buffer_poll		; Poll AUX port and buffer any available bytes
		pop	bc			; Restore retry countdown
		jr	nz, rx_byte_have_char	; Character available, exit polling loop
		call	delay			; Spin-loop delay slice (~a few milliseconds)
		djnz	rx_byte_retry_loop	; Decrement retry counter and continue waiting
		call	rx_buffer_poll		; Final poll check after retry count exhausted
rx_byte_have_char:
		call	nz, rx_buffer_get_byte	; If byte ready (NZ), fetch it into A
		pop	bc			; Restore BC
		ret				; Return character in A (NZ=success, Z=timeout)

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

delay:
		push	bc			; Preserve BC
		ld	a, 4			; Outer delay loop count = 4
		ld	b, 0			; Inner loop count = 256 iterations
delay_loop:
		djnz	delay_loop		; Inner loop: 256 * 13 T-states
		dec	a			; Decrement outer loop count
		jr	nz, delay_loop		; Loop until outer count reaches 0
		pop	bc			; Restore BC
		ret				; Return

;----------------------------------------------------------------------------

delay_done:
		ld	e, (hl)			; Load low byte of queued byte count
		inc	hl
		ld	d, (hl)			; Load high byte of queued byte count (DE = count)
		ld	a, d			; Check if ring buffer is empty (count == 0)
		or	e
		ret	z			; If empty, return with Z flag set
		dec	de			; Decrement queued byte count
		ld	(hl), d			; Update high byte of queued count
		dec	hl
		ld	(hl), e			; Update low byte of queued count
		ld	de, 4			; Offset to read head pointer field in header
		add	hl, de			; HL points to read pointer word
		push	hl			; Save pointer address on stack
		ld	e, (hl)			; Load low byte of read pointer offset
		inc	hl
		ld	d, (hl)			; Load high byte of read pointer offset
		inc	hl			; Point past read pointer word to buffer data start
		add	hl, de			; HL = absolute address of next byte to read
		ex	(sp), hl		; Save buffer byte address; HL = read pointer address
		inc	de			; Increment read offset for next get operation
		ld	a, e			; Mask read offset to ring buffer modulo mask
		and	0FFh			; Low 8 bits of ring buffer offset
		ld	(hl), a			; Store updated low byte of read offset
		inc	hl
		ld	a, d			; High bits of ring buffer offset
		and	0Fh			; Mask to ring buffer size (e.g. 4KB / 0FFFh)
		ld	(hl), a			; Store updated high byte of read offset
		pop	hl			; Restore HL = address of fetched byte in buffer
		ld	a, 1			; Set A = 1 (NZ condition)
		or	a			; Clear Z flag to indicate character successfully read
		ld	a, (hl)			; Load fetched character byte into A
		ret				; Return character in A with NZ flag

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : rx_buffer_put_byte
; Purpose  : Store received character into circular receive buffer
; Inputs   : C = character, HL = buffer pointer
; Outputs  : Z if buffer full, NZ on success
; Modifies : DE, HL
;============================================================================
rx_buffer_put_byte:
		or	a			; Clear carry flag
		push	hl			; Preserve ring buffer header pointer
		ld	e, (hl)			; Load low byte of queued byte count
		inc	hl
		ld	d, (hl)			; Load high byte of queued byte count
		ld	hl, rbuf_size		; HL = maximum ring buffer capacity
		sbc	hl, de			; Test if buffer is full (count == capacity)
		pop	hl			; Restore ring buffer header pointer
		ret	z			; If full, return with Z flag set (cannot insert)
		inc	de			; Increment queued byte count
		ld	(hl), e			; Update low byte of queued count
		inc	hl
		ld	(hl), d			; Update high byte of queued count
		inc	hl			; Advance to write tail pointer field
		push	hl			; Save pointer address on stack
		ld	e, (hl)			; Load low byte of write pointer offset
		inc	hl
		ld	d, (hl)			; Load high byte of write pointer offset
		inc	hl			; Advance past write pointer
		inc	hl			; Skip read pointer field to buffer data start
		inc	hl
		add	hl, de			; HL = absolute address in ring buffer to write
		ex	(sp), hl		; Save target byte address; HL = write pointer address
		inc	de			; Increment write offset for next put operation
		ld	a, e			; Low byte of write offset
		and	0FFh			; Mask to ring buffer modulo boundary
		ld	(hl), a			; Store updated low byte of write offset
		inc	hl
		ld	a, d			; High byte of write offset
		and	0Fh			; Mask to ring buffer size
		ld	(hl), a			; Store updated high byte of write offset
		pop	hl			; Restore HL = target byte address in ring buffer
		ld	(hl), c			; Store received character byte C into ring buffer
		ret				; Return with character stored (NZ)

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : clear_transfer_state
; Purpose  : Zero out transfer state control variables (25h bytes)
; Inputs   : None
; Outputs  : Memory cleared
; Modifies : A, B, HL
;============================================================================
clear_transfer_state:
		ld	hl, transfer_state_vars	; HL points to transfer state control block in RAM
		ld	b, 25h			; Count = 37 (25h) bytes to clear
		jr	clear_bytes_zero_fill	; Zero out memory block and return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : clear_3_bytes
; Purpose  : Zero out 3 bytes at address HL
; Inputs   : HL = buffer pointer
; Outputs  : 3 bytes set to 0
; Modifies : A, B
;============================================================================
clear_3_bytes:
		ld	b, 3			; Count = 3 bytes to clear
		jr	clear_bytes_zero_fill	; Zero out memory and return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : clear_6_bytes
; Purpose  : Zero out 6 bytes at address HL
; Inputs   : HL = buffer pointer
; Outputs  : 6 bytes set to 0
; Modifies : A, B
;============================================================================
clear_6_bytes:
		ld	b, 6			; Count = 6 bytes to clear
clear_bytes_zero_fill:
		xor	a			; A = 00h (fill byte)
		jp	fill_bhla		; Fill B bytes at HL with zeroes and return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : aux_fifo_advance
; Purpose  : Advance AUX input FIFO read index
; Inputs   : HL = FIFO control block
; Outputs  : A = character, CY on wrap
; Modifies : A, DE, HL
;============================================================================
aux_fifo_advance:
		xor	a			; Clear A
		or	(hl)			; Test FIFO count byte at (HL)
		ret	z			; Return if FIFO is empty (count == 0)
		dec	(hl)			; Decrement queued count
		inc	hl			; Advance to read index field
		inc	hl
		ld	e, (hl)			; Load current read index into E
		ld	d, 0			; D = 0
		ld	a, e			; Advance read index
		inc	a
		and	7Fh			; Mask modulo 128 (7Fh)
		ld	(hl), a			; Store updated read index
		inc	hl			; Point past index to FIFO buffer base
		adc	hl, de			; HL = absolute address of next character
		ld	a, (hl)			; Load character from FIFO into A
		ret	nc			; If no carry, return with character in A
		ccf				; Complement carry flag
		ret				; Return

;----------------------------------------------------------------------------

;============================================================================
; Function : aux_fifo_push
; Purpose  : Push character into AUX FIFO buffer
; Inputs   : C = character, HL = FIFO control block
; Outputs  : Character queued, CY on full
; Modifies : A, DE, HL
;============================================================================
aux_fifo_push:
		ld	a, 80h			; FIFO maximum capacity = 128 (80h) bytes
		sub	(hl)			; Check if FIFO is full ((HL) == 80h)
		ret	z			; If full, return with Z flag set
		inc	(hl)			; Increment queued character count
		inc	hl			; Advance to write index field
		ld	e, (hl)			; Load current write index into E
		ld	d, 0			; D = 0
		ld	a, e			; Advance write index
		inc	a
		and	7Fh			; Mask modulo 128 (7Fh)
		ld	(hl), a			; Store updated write index
		inc	hl			; Point past index to FIFO buffer base
		inc	hl
		adc	hl, de			; HL = absolute address of write slot
		ld	(hl), c			; Store character C into FIFO
		ret	nc			; If no carry, return
		ccf				; Complement carry flag
		ret				; Return

;============================================================================
; Function : dispatch_table_jump
; Purpose  : Dispatches execution to a jump vector found after a CPIR search.
; Inputs   : HL = End of character search table (after CPIR match)
;            BC = Remaining count returned by CPIR
; Outputs  : Jumps directly to target handler subroutine via JP (HL)
; Modifies : BC, HL
; Notes    : Calculates offset: HL + BC skips past characters to vector table,
;            then SLA C multiplies the index by 2 to index the 16-bit word address (.dw).
;============================================================================
dispatch_table_jump:
		add	hl, bc			; Advance HL past remaining switch characters
		sla	c			; Multiply remaining index count C by 2 (word offset)
		add	hl, bc			; HL = address of target 16-bit jump vector (.dw)
		ld	c, (hl)			; Load low byte of handler routine address
		inc	hl
		ld	h, (hl)			; Load high byte of handler routine address
		ld	l, c			; HL = target handler address
		jp	(hl)			; Jump indirectly to option switch handler

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; 32-Bit Arithmetic & Memory Utility Library (math32.inc)
;============================================================================
#include "math32.inc"


;----------------------------------------------------------------------------

; Decimal power constants table for 32-bit number conversion (1,000,000,000 down to 10):
and32_loop_step_1:
		.db	0,	0CAh,	9Ah,	3Bh	; 1,000,000,000 (3B9ACA00h)
		.db	0,	0E1h,	0F5h,	5	;   100,000,000 (05F5E100h)
		.db	80h,	96h,	98h,	0	;    10,000,000 (00989680h)
		.db	40h,	42h,	0Fh,	0	;     1,000,000 (000F4240h)
		.db	0A0h,	86h,	1,	0	;       100,000 (000186A0h)
		.db	10h,	27h,	0,	0	;        10,000 (00002710h)
		.db	0E8h,	3,	0,	0	;         1,000 (000003E8h)
		.db	64h,	0,	0,	0	;           100 (00000064h)
		.db	0Ah,	0,	0,	0	;            10 (0000000Ah)

;============================================================================
; Function : conv_num_to_ascii
; Purpose  : Convert 32-bit unsigned binary integer to null-terminated ASCII string
; Inputs   : HL = pointer to 32-bit number, DE = destination string buffer
; Outputs  : Formatted ASCII decimal string written to buffer
; Modifies : A, BC, DE, HL
;============================================================================
conv_num_to_ascii:
		ld	(patch_num_conv_ptr), de ; Store destination string pointer into SMC operand
		ld	de, num_to_ascii_buf	; DE points to working 32-bit temporary buffer
		call	copy_4bytes		; Copy input 32-bit integer into work buffer
		ld	c, +(conv_num_to_ascii-and32_loop_step_1)/4 ; Number of power-of-10 divisor entries (9)
		ld	de, and32_loop_step_1-4	; Initialize power table pointer before first entry
		xor	a			; Clear leading zero suppression flag
		ld	(patch_num_conv_flags), a ; 0 = suppress leading zeroes, NZ = emit zeroes
conv_num_to_as_step_1:
		ld	a, 30h			; Initialize ASCII digit base ('0' = 30h)
		ld	(patch_num_conv_base), a ; Store into SMC digit accumulator
		inc	de			; Advance table pointer by 4 bytes to next power of 10
		inc	de
		inc	de
		inc	de
		ld	b, 0Ah			; Maximum 10 subtraction iterations per digit
conv_num_to_as_call_1:
		push	bc			; Preserve BC (digit countdown)
		ld	hl, num_to_ascii_buf	; Minuend: current remainder
		ld	bc, rbuf_bfree_step_2	; Destination: candidate remainder
		call	sub32			; Subtract power of 10 from current remainder
		pop	bc			; Restore BC
		jr	c, conv_num_to_as_br_1	; If borrow (underflow), divisor exceeded remainder
		push	de			; Preserve power table pointer
		ld	a, (patch_num_conv_base) ; Increment ASCII digit value
		inc	a
		ld	(patch_num_conv_base), a ; Update digit accumulator
		ld	de, num_to_ascii_buf	; Copy candidate remainder back to work buffer
		ld	hl, rbuf_bfree_step_2
		call	copy_4bytes
		pop	de			; Restore power table pointer
		djnz	conv_num_to_as_call_1	; Repeat subtraction loop
patch_num_conv_base:	.equ	$+1		; SMC: immediate byte operand holding computed digit
conv_num_to_as_br_1:
		ld	a, 30h			; Load computed ASCII digit
		cp	30h			; Is it a leading zero ('0')?
		jr	nz, conv_num_to_as_step_2 ; If non-zero digit, emit it unconditionally
patch_num_conv_flags:	.equ	$+1		; SMC: immediate flag indicating leading zero state
		ld	a, 0			; 0 = suppressing leading zeroes
		or	a
		jr	z, conv_num_to_as_br_2	; If zero suppression active, skip emitting digit
patch_num_conv_ptr:	.equ	$+1		; SMC: immediate word operand holding output pointer
conv_num_to_as_step_2:
		ld	hl, 0			; Load output string pointer
		ld	(hl), a			; Write ASCII digit character into output buffer
		inc	hl			; Advance output pointer
		ld	(patch_num_conv_ptr), hl ; Update SMC output pointer
		ld	a, 30h			; Enable emission of subsequent zeroes
		ld	(patch_num_conv_flags), a ; Set zero suppression flag inactive
conv_num_to_as_br_2:
		dec	c			; Decrement power-of-10 divisor entry count
		jr	nz, conv_num_to_as_step_1 ; Process next decimal position
		ld	a, (num_to_ascii_buf)	; Load remaining units digit (0..9)
		and	0Fh			; Mask low nibble
		add	a, 30h			; Convert to ASCII character ('0'..'9')
		ld	hl, (patch_num_conv_ptr) ; Load final output string pointer
		ld	(hl), a			; Store units digit into buffer
		inc	hl			; Advance pointer
		ld	(hl), 0			; Append null terminator
		ret				; Return

;============================================================================
; Function : checksum8_update
; Purpose  : Update 8-bit additive checksum accumulator with byte in A
; Inputs   : A = byte to add
; Outputs  : patch_checksum8_val updated
; Modifies : None
;============================================================================
checksum8_update:
		push	af			; Preserve AF
patch_checksum8_val:	.equ	$+1		; SMC: immediate byte operand holding running checksum
		add	a, 0			; Add byte to running 8-bit checksum accumulator
		ld	(patch_checksum8_val), a ; Store updated checksum back to SMC operand
		pop	af			; Restore original AF
		ret				; Return

crc32_poly_rev:	.db	20h
		.db	83h
		.db	0B8h
		.db	0EDh

crc32_final_xor:	.db	0E3h
		.db	20h
		.db	0BBh
		.db	0DEh

;============================================================================
; Function : crc32_update
; Purpose  : Update 32-bit Zmodem CRC with byte in A using table lookup
; Inputs   : A = byte to process
; Outputs  : rbuf_bfree_step_3 (CRC-32) updated
; Modifies : A, BC, HL, IX, IY
;============================================================================
crc32_update:
		push	af			; Preserve input byte/flags on stack
patch_crc32_table_base:	.equ	$+2	; SMC: 16-bit base address of generated CRC-32 table
		ld	iy, rbuf_bfree_step_4	; IY points to CRC-32 table in RAM
		ld	ix, rbuf_bfree_step_3	; IX points to 32-bit CRC accumulator
		xor	(ix+0)			; Index = input byte XOR lowest CRC byte
		ld	h, 0			; HL = table entry index * 4 (each entry is 4 bytes)
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
;		S u b r	o u t i	n e

;============================================================================
; Function : build_crc32_table
; Purpose  : Dynamically generate 1KB Zmodem CRC-32 lookup table
; Inputs   : None
; Outputs  : CRC-32 table generated in RAM
; Modifies : A, B, DE, HL, IX, IY
;============================================================================
build_crc32_table:
		push	de			; Preserve DE
		push	hl			; Preserve HL
		ld	hl, (patch_crc32_table_base) ; HL = base address of 1024-byte CRC table buffer
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
		xor	e			; XOR low byte with entry index
		ld	e, a
		ld	b, 8			; Shift 8 bits per entry
build_crc32_inner:
		scf				; Set carry flag
		rr	h			; Rotate 32-bit register (HL:DE) right through carry
		rr	l
		rr	d
		rr	e
		jr	nc, build_crc32_store	; If bit shifted out was 0, skip XOR with polynomial
		ld	a, e			; If bit shifted out was 1, XOR with polynomial
		xor	(ix+0)
		ld	e, a
		ld	a, d
		xor	(ix+1)
		ld	d, a
		ld	a, l
		xor	(ix+2)
		ld	l, a
		ld	a, h
		xor	(ix+3)
		ld	h, a
build_crc32_store:
		djnz	build_crc32_inner	; Loop for all 8 bits
		ld	a, h			; Invert byte 3
		cpl
		ld	(iy+0), a		; Store into table
		dec	iy
		ld	a, l			; Invert byte 2
		cpl
		ld	(iy+0), a		; Store into table
		dec	iy
		ld	a, d			; Invert byte 1
		cpl
		ld	(iy+0), a		; Store into table
		dec	iy
		ld	a, e			; Invert byte 0
		cpl
		ld	(iy+0), a		; Store into table
		dec	iy
		pop	af			; Restore outer loop counter
		inc	a			; Advance to next table entry
		jr	nz, build_crc32_outer	; Repeat for all 256 table entries (1024 bytes)
		pop	hl			; Restore HL
		pop	de			; Restore DE
		ret				; Return

;----------------------------------------------------------------------------

;============================================================================
; Function : crc16
; Purpose  : Updates running 16-bit CRC-CCITT accumulator with byte in A
; Inputs   : A  = byte to process
; Outputs  : (crc_seed) updated with new 16-bit CRC value
; Modifies : None (preserves AF via PUSH/POP)
; Notes    : Uses standard CCITT polynomial 1021h (x^16 + x^12 + x^5 + 1).
;            Uses self-modifying code patch at crc_seed to maintain running CRC.
;============================================================================
crc16:
		push	af			; Preserve input byte/flags
crc_seed:	.equ	$+1			; SMC patch point: running CRC in HL
		ld	hl, 0			; HL = current 16-bit CRC accumulator
		ld	de, 1021h		; DE = CRC16-CCITT polynomial (x^16 + x^12 + x^5 + 1)
		xor	h			; XOR input byte with CRC high byte
		ld	h, a
		ld	b, 8			; Process 8 bits
crc16_bit_loop:
		add	hl, hl			; Shift CRC left by 1 bit
		jr	nc, crc16_next_bit	; If bit shifted out was 0, skip XOR
		ld	a, h			; If bit shifted out was 1, XOR with polynomial
		xor	d
		ld	h, a
		ld	a, l
		xor	e
		ld	l, a
crc16_next_bit:
		djnz	crc16_bit_loop		; Loop for all 8 bits
		ld	(crc_seed), hl		; Store updated 16-bit CRC back to SMC immediate
		pop	af			; Restore original input byte/flags
		ret				; Return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : init_crc_acc
; Purpose  : Reset CRC-16, CRC-32, and 8-bit checksum accumulators to zero
; Inputs   : None
; Outputs  : Accumulators initialized to 0
; Modifies : A, HL
;============================================================================
init_crc_acc:
		xor	a			; Clear A
		ld	h, a			; HL = 0000h
		ld	l, a
		ld	(patch_checksum8_val), a ; Reset 8-bit checksum accumulator to 0
		ld	(crc_seed), hl		; Reset 16-bit CRC-CCITT accumulator to 0
		ld	hl, rbuf_bfree_step_3	; HL points to 32-bit CRC accumulator
		jp	dec32_zero		; Zero out 4 bytes (CRC-32) and return

;----------------------------------------------------------------------------

protocol_mode:	.db 	4
flg_zmdm:	.db 	0
flg_xmdm:	.db 	0
flg_ymdm:	.db 	0
flg_help:	.db 	0
rx_buffer_mask:	.dw 	0

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : calc_buffer_mask
; Purpose  : Calculate power-of-two buffer mask from available memory
; Inputs   : H = memory top page
; Outputs  : file_offset_hi, rx_buffer_mask configured
; Modifies : A, BC, HL
;============================================================================
calc_buffer_mask:
		xor	a			; Clear accumulator
		ld	c, a			; Initialize mask accumulator C = 00h
		ld	b, 8			; 8 bits to evaluate in page byte H
		ld	a, h			; A = memory top page high byte
calc_mask_shift:
		rlca				; Rotate highest bit into carry
		set	7, c			; Set highest bit of mask
		jr	c, calc_mask_done	; When highest set bit encountered, mask is complete
		rr	c			; Shift mask right
		djnz	calc_mask_shift		; Check next bit
calc_mask_done:
		ld	a, h			; A = top page byte
		and	c			; Align memory boundary to power-of-two mask
		ld	h, a			; HL = page-aligned memory buffer ceiling
		ld	l, 0
		ld	(file_offset_hi), hl	; Store file buffer address limit
		dec	hl			; Compute wrapping bitmask (size - 1)
		ld	(rx_buffer_mask), hl	; Store circular buffer address wrap mask
		ret				; Return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : rx_batch_engine
; Purpose  : Main protocol receiver engine (handles Zmodem, Ymodem, Xmodem)
; Inputs   : None
; Outputs  : Transfer completed or aborted
; Modifies : All registers
;============================================================================
rx_batch_engine:
		xor	a			; Clear accumulator
		ld	hl, esc_ctrl_chars_flag	; HL points to protocol control variables block
		ld	b, 61h			; Length = 97 (61h) bytes to clear
		call	fill_bhla		; Clear receiver protocol control variables
		ld	hl, rbuf_bfree		; HL points to circular buffer control header
		call	clear_6_bytes		; Clear 6 bytes of ring buffer tracking state
		call	build_crc32_table	; Generate dynamic 1024-byte CRC-32 table in RAM
		ld	hl, (free_mem_base)	; Load start of free memory (buffer bottom)
		ld	(file_offset_lo), hl	; Initialize receive memory buffer start address
		ld	de, (6)			; BDOS entry address at 0006h (top of available TPA)
		ex	de, hl			; Swap: HL = BDOS top, DE = free memory bottom
		or	a			; Clear carry
		sbc	hl, de			; HL = total available TPA buffer size
		call	calc_buffer_mask	; Compute power-of-two mask and top address
		ld	a, (flg_zmdm)		; Check if command-line forced Zmodem (-z)
		cp	0
		jr	z, rx_batch_set_flags	; If not forced, use default auto-detection
		ld	a, 7			; 7 = force Zmodem protocol mode
rx_batch_set_flags:
		ld	(flag_zmodem_active), a	; Set active Zmodem state flag
		ld	a, 10h			; Default CRC format = 16-bit CRC (10h)
		ld	(rx_hdr_crc_format), a	; Initialize receive header CRC format
		ld	a, (protocol_mode)	; Check selected protocol mode
		cp	3			; Mode < 3 implies Xmodem
		jr	c, rx_batch_xmodem	; If Xmodem requested, enter Xmodem receive
		ld	a, 1			; ZRINIT frame type = 1
		ld	(patch_zrinit_flags), a	; Set ZRINIT frame type in transmit header
		call	rx_wait_zrinit		; Send ZRINIT and wait for remote sender response
		jp	c, rx_batch_abort_can	; On timeout/error/abort, send CAN sequence
		or	a			; Test response status code
		jr	z, rx_batch_ymodem	; 0 = sender did not respond with Zmodem, try Ymodem
		cp	4			; 4 = ZFILE frame received
		jr	z, rx_batch_handle_zfile ; Process incoming ZFILE header
		cp	0Fh			; 0Fh = ZCOMPL (all files completed)
		jr	nz, rx_batch_handle_zfile ; Otherwise continue processing ZFILE frames
		jr	locret_953		; Clean exit

rx_batch_handle_zfile:
		call	rx_zfile_header		; Process incoming ZFILE frame and receive file
		jr	c, rx_batch_abort_can	; On receive error, send CAN cancel sequence
		jr	locret_953		; Clean return

;----------------------------------------------------------------------------

rx_batch_ymodem:
		ld	a, 3			; Mode 3 = binary receive mode for Ymodem
		ld	(protocol_mode), a	; Set mode
		xor	a			; Clear error count
		ld	(transfer_err_count), a
		call	tx_zrinit_frame		; Send initial polling handshake ('C' / NAK)
		jr	c, rx_batch_abort_can	; On failure, abort
		call	rx_file_transfer	; Receive Ymodem file block and payload
		jr	c, rx_batch_abort_can	; On error, abort
		jr	z, locret_953		; If batch complete (empty filename), exit
		call	tx_zrpos_frame		; Acknowledge and request next block/file
		jr	c, rx_batch_abort_can	; On error, abort
		jr	rx_batch_ymodem		; Loop for next file in Ymodem batch

;----------------------------------------------------------------------------

rx_batch_xmodem:
		call	rx_file_transfer	; Receive single Xmodem file
		jr	c, rx_batch_abort_can	; On error, abort
		jr	z, locret_953		; On success, exit
		call	tx_zrpos_frame		; Send acknowledgment/completion
		jr	c, rx_batch_abort_can	; On error, abort
locret_953:
		ret				; Return to main caller

;----------------------------------------------------------------------------

rx_batch_abort_can:
		call	tx_can_sequence		; Send CAN (08h/18h) cancel sequence to remote sender
		ld	a, (transfer_abort_flag) ; Check if file was open and needs cleanup
		cp	0FFh
		call	z, flush_sector_buffer	; If file open, flush sectors and close FCB
		jr	locret_953		; Exit

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : rx_file_transfer
; Purpose  : Receive single file payload, open FCB, and stream disk writes
; Inputs   : None
; Outputs  : CY on error, Z on end of batch
; Modifies : All registers
;============================================================================
rx_file_transfer:
		ld	a, (flg_xmdm)		; Check Xmodem command line override flag
		cpl				; Invert flag
		ld	hl, flg_ymdm		; HL points to Ymodem override flag
		or	(hl)			; Combine flags
		ld	(flag_ymodem_active), a	; Update Ymodem active state
		ld	a, (flag_zmodem_active)	; Check if Zmodem active
		or	a
		jr	z, rx_file_check_ymodem	; If not active, skip
		ld	(zmodem_flag_ca1), a	; Save active Zmodem state
rx_file_check_ymodem:
		ld	a, (flg_ymdm)		; Check Ymodem flag
		cp	0FFh
		jr	z, rx_file_init_done	; If forced Ymodem, keep active
		ld	a, (remote_proto_type)	; Check remote sender protocol type
		cp	2			; Type 2 = Xmodem-CRC
		jr	nz, rx_file_init_done
		ld	a, 0			; Clear Ymodem flag for pure Xmodem
		ld	(flag_ymodem_active), a
rx_file_init_done:
		ld	a, (remote_proto_type)	; Check remote protocol type
		cp	1			; Type 1 = standard Ymodem
		jr	nz, rx_file_init_d_br_1
		ld	a, 0FFh			; Activate Ymodem mode
		ld	(flag_ymodem_active), a
rx_file_init_d_br_1:
		ld	a, (zmodem_flag_ca1)	; Check Zmodem state
		cp	7			; Full Zmodem streaming?
		jr	z, rx_file_print_name
		ld	a, (zmodem_flag_ca1)
		cp	3			; Windowed Zmodem?
		jr	nz, rx_file_print_name
		ld	a, (flag_ymodem_active)
		cp	0FFh
		jr	nz, rx_file_print_name
		ld	a, 7			; Upgrade to full streaming
		ld	(zmodem_flag_ca1), a
rx_file_print_name:
		ld	a, (protocol_mode)	; Check protocol mode
		cp	3			; If mode < 3, single file already parsed
		jr	c, rx_file_print_call_1
		call	clear_transfer_state	; Clear transfer state variables
		ld	hl, (file_offset_lo)	; HL points to received file header buffer
		xor	a
		or	(hl)			; Is first byte null (empty filename in batch)?
		scf				; Set carry (indicates batch termination)
		ret	z			; Return Z + CY on empty filename (end of batch)
		push	hl			; Preserve buffer pointer
		ld	b, 1			; Find end of filename string
		call	Search0
		dec	hl			; Point back to null byte
		ld	(hl), 20h		; Replace null with space separator
		pop	hl			; Restore buffer pointer
		ld	de, rx_char_saved_step_4 ; Buffer for parsed tokens
		ld	a, 7			; Maximum tokens to parse
		ld	(de), a
		ld	a, 0FFh			; Whitespace delimiter mask
		call	tokenize_cmdline	; Tokenize received remote filename and metadata
		ld	hl, (rx_filename_ptr)	; HL = pointer to remote filename string
		ld	de, file_fcb		; DE = destination FCB
		call	parse_cpm_filespec	; Convert to CP/M 8.3 filename in FCB
		ld	hl, (saved_user_num)	; HL = packed (saved_user_num, saved_drive_num)
		ld	(transfer_state_vars), hl ; Save drive and user to transfer state
rx_file_print_call_1:
		call	print_transfer_file_msg	; Display filename, drive, user on console
		ld	de, file_fcb		; DE points to FCB
		call	bdos_search_first	; Check if file already exists on disk
		jr	nz, init_file_prog_call_1 ; File exists, handle overwrite/protect options
		ld	de, file_fcb		; File does not exist: create new file
		ld	c, F_MAKE		; BDOS Function 22: Create file
		call	bdos_s			; Create file entry in directory
		ret	c			; If directory full error, return with carry
		ld	a, 0FFh			; Mark file open and active
		ld	(transfer_abort_flag), a
		ld	hl, cpm_partial_record_bytes ; Clear partial record buffer tracking
		call	clear_3_bytes
		ld	a, (file_mgmt_option)	; Check file management option
		cp	2
		jr	c, init_file_progress_loop ; Proceed to transfer loop

;============================================================================
; Function : init_file_progress
; Purpose  : Initialize file transfer progress counters and timers
; Inputs   : None
; Outputs  : Counters reset
; Modifies : A
;============================================================================
init_file_progress:
		ld	de, (rx_file_info_ptr)	; DE points to remote file information string
init_file_progress_loop:
		ld	a, 1			; A = 1 (success condition)
		or	a			; Clear carry
		ret				; Return

;----------------------------------------------------------------------------

init_file_prog_call_1:
		call	init_file_progress	; Initialize progress state
		ld	a, (protocol_mode)	; Check file protection mode
		cp	4			; Mode 4 = Protect existing files (-p)
		jr	nz, init_file_prog_call_2 ; Not protect mode, delete and recreate
		ld	a, (zmodem_flag_ca1)	; Check Zmodem resume capability
		cp	7
		jr	nz, init_file_prog_br_1	; If not full streaming, check resume
		jr	init_file_prog_err_1	; Skip protected file

;----------------------------------------------------------------------------

init_file_prog_call_2:
		ld	de, file_fcb		; DE points to file FCB
		ld	c, F_DELETE		; BDOS Function 19: Delete file
		call	bdos_s			; Delete existing file to overwrite
		jr	nc, rx_file_print_call_1 ; Re-enter to create fresh file
init_file_prog_err_1:
		call	print_file_skipped	; Print 'File skipped' on console
		ld	a, 5			; 5 = ZSKIP frame code
		scf				; Set carry flag
		ret				; Return with skip status

;----------------------------------------------------------------------------

init_file_prog_br_1:
		ld	a, (zmodem_flag_ca1)	; Check file recovery mode
		cp	3			; Resume mode?
		jr	z, init_file_prog_call_3
		ld	a, (flg_help)		; Check resume flag
		cp	0FFh
		jr	nz, init_file_prog_call_2 ; Overwrite if resume not requested
init_file_prog_call_3:
		ld	de, rbuf_bfree_step_1	; DE points to temporary sector DMA buffer
		ld	c, F_DMAOFF		; BDOS Function 26: Set DMA address
		call	bdos
		ld	e, 1			; Multi-sector count = 1 record
		ld	c, F_MULTISEC		; BDOS Function 44: Set multi-sector count
		call	bdos
		ld	de, file_fcb		; DE points to file FCB
		ld	c, F_OPEN		; BDOS Function 15: Open existing file
		call	bdos_s			; Open file for append/resume
		ret	c			; If open failed, return carry
		ld	a, 0FFh			; Mark file active
		ld	(transfer_abort_flag), a
		ld	hl, cpm_partial_record_bytes ; Clear partial record state
		call	clear_3_bytes
		ld	de, file_fcb		; Query file size
		ld	c, F_SIZE		; BDOS Function 35: Compute file size
		call	bdos_s			; Size returned in FCB random record field (r0,r1,r2)
		ret	c			; Return if error
		ld	hl, fcb_record_count_ext ; Clear record count extension byte
		ld	(hl), 0
		ld	hl, file_fcb_step_1	; HL points to 32-bit record count from FCB
		call	dec32			; Decrement to point to last 128-byte record
		ld	de, rx_char_saved_step_2 ; Save last record index to position tracker
		call	copy_4bytes
		ex	de, hl			; Swap pointers
		ld	b, 7			; Multiply record count by 128 (shift left 7 bits)
init_file_prog_step_1:
		push	hl			; 32-bit shift left by 1 bit: SLA byte 0, RL bytes 1..3
		sla	(hl)
		inc	hl
		rl	(hl)
		inc	hl
		rl	(hl)
		inc	hl
		rl	(hl)
		pop	hl
		djnz	init_file_prog_step_1	; Repeat 7 times to convert records to byte offset
		ld	de, file_fcb		; DE points to FCB
		ld	c, F_READRAND		; BDOS Function 33: Read random record
		call	bdos_s			; Read last record into DMA buffer to find end of text
		ret	c			; Return if error
		ld	a, (zmodem_flag_ca1)	; Check resume mode
		cp	3
		jr	z, init_file_prog_call_4 ; Scan for CP/M EOF (Ctrl-Z = 1Ah)
		ld	a, 9			; 9 = ZRPOS resume response
		or	a
		ret				; Return

;----------------------------------------------------------------------------

init_file_prog_call_4:
		ld	a, 80h			; Record size = 128 (80h) bytes
		ld	(cpm_partial_record_bytes), a
init_file_prog_call_5:
		ld	hl, cpm_partial_record_bytes ; Scan record buffer backwards for EOF
		call	aux_fifo_advance	; Advance through buffered record bytes
		jr	z, init_file_prog_step_2 ; If no EOF found, resume at record boundary
		cp	1Ah			; Is byte CP/M EOF mark (Ctrl-Z)?
		jr	nz, init_file_prog_call_5 ; Continue scanning
		ld	a, (cpm_record_count)	; Decrement record count for partial record
		dec	a
		ld	(cpm_last_record_index), a
		ld	hl, cpm_partial_record_bytes ; Compute remaining valid bytes in record
		ld	a, 7Fh
		sub	(hl)
		jr	init_file_prog_step_3

;----------------------------------------------------------------------------

init_file_prog_step_2:
		ld	a, 80h			; Full 128 bytes valid
init_file_prog_step_3:
		ld	(cpm_partial_record_bytes), a ; Save partial record byte count
		ld	a, 1			; Set success condition
		or	a
		ret				; Return

;----------------------------------------------------------------------------

rx_wait_zrinit:
		xor	a			; Clear accumulator
		ld	(transfer_err_count), a	; Reset error count
		ld	a, 4			; Protocol mode 4 (Zmodem)
		ld	hl, protocol_mode
		cp	(hl)
		ld	a, 0
		ret	nz			; Return 0 if not Zmodem mode
		ld	hl, file_pos_backup_lo	; HL points to file position backup area
		ld	b, 11h			; Length = 17 (11h) bytes
		xor	a
		call	fill_bhla		; Clear position backup variables
		call	save_file_pos		; Save current file position snapshot
		ld	a, (rx_char_saved)	; Check saved receive character state
		cp	0FFh
		ld	b, 5			; Timeout retry counter = 5
		jr	z, rx_wait_zrinit_step_1
		ld	b, 0Ah			; Default retry counter = 10 (0Ah)

rx_wait_zrinit_step_1:
		push	bc			; Preserve retry counter
		ld	ix, rx_char_saved_step_5 ; Point IX to transmit header position payload
		ld	(ix+3), 20h		; Capabilities flag: CANFDX | CANOVIO (20h)
		ld	(ix+2), 0		; Flags byte 2 = 0
		ld	hl, (file_offset_hi)	; Receiver buffer size limit
		ld	(ix+0), l		; Buffer size low byte
		ld	(ix+1), h		; Buffer size high byte
patch_zrinit_flags:	.equ	$+1		; SMC: frame type byte to transmit
		ld	a, ZRINIT		; Immediate frame type operand (ZRINIT=1)
		call	tx_hex_header		; Transmit HEX header with receiver capabilities
		ld	a, (patch_zrinit_flags)	; Check if ZSKIP was previously requested
		cp	ZSKIP			; Frame type 5 = ZSKIP
		jr	nz, rx_wait_zrinit_loop_1
		ld	a, ZRINIT		; Reset back to ZRINIT
		ld	(patch_zrinit_flags), a
rx_wait_zrinit_loop_1:
		call	rx_header_search	; Wait for and decode incoming header frame
		ld	hl, rx_wait_zrinit_step_3 ; HL points to expected frame types table
		ld	bc, 0Ah			; BC = 10 entries to search
		cpir				; Search frame type in dispatch table
		jp	z, dispatch_table_jump	; Jump to matched frame type handler
rx_wait_zrinit_call_1:
		ld	hl, transfer_err_count	; Increment error count on invalid frame
		inc	(hl)
		call	print_error_count	; Display error count on console
rx_wait_zrinit_done_1:
		pop	bc			; Restore retry counter
		djnz	rx_wait_zrinit_step_1	; Retry ZRINIT transmission up to B times
		xor	a			; Return 0 (no Zmodem response)
		ret

rx_wait_zrinit_done_2:
		pop	bc			; Discard retry counter
		ld	a, 0FFh			; Return FFh with carry (abort/timeout)
		scf
		ret

rx_wait_zrinit_done_3:
		pop	bc			; Discard retry counter
		call	tx_zack_frame		; Transmit ZACK frame acknowledging remote sender
		ld	a, 0Fh			; Return 0Fh (ZCOMPL session finish)
		ret

rx_wait_zrinit_call_2:
		ld	hl, rx_char_saved_step_5 ; Clear transmit header position payload
		call	clear_4bytes
		jr	rx_wait_zrinit_call_3

rx_wait_zrinit_step_2:
		ld	ix, rx_char_saved_step_1 ; IX points to received header position payload
		ld	a, (ix+3)		; Check sender capability flags
		and	40h			; Check escape control characters flag
		ld	(esc_ctrl_chars_flag), a ; Set receiver escape control characters flag
		call	zdle_escape_tb_step_2	; Receive following subpacket data block
		cp	0EBh			; Did subpacket end with ZCRCW?
		ld	a, 6			; 6 = ZNAK frame type
		jr	nz, rx_wait_zrinit_call_4 ; If bad subpacket, send ZNAK
		ld	hl, (file_offset_lo)	; Free buffer containing filename payload
		ld	de, rx_char_saved_step_3 ; Save received filename
		ld	bc, 20h			; 32 bytes
		ldir
rx_wait_zrinit_call_3:
		ld	a, 3			; 3 = ZCRC header type
rx_wait_zrinit_call_4:
		push	af			; Preserve response frame type
		ld	hl, rx_char_saved_step_5 ; Clear transmit payload
		call	clear_4bytes
		pop	af			; Restore frame type
		call	tx_hex_header		; Send HEX response frame to remote sender
		call	sync_file_pos		; Synchronize file position
		jp	rx_wait_zrinit_call_1	; Re-enter receive loop

rx_wait_zrinit_call_5:
		ld	hl, rx_char_saved_step_1 ; Copy received frame payload
		ld	de, rbuf_bfree_step_5
		call	copy_4bytes
		ld	a, 1			; Reset ZRINIT flag
		ld	(patch_zrinit_flags), a
		call	zdle_escape_tb_step_2	; Receive following ZFILE subpacket
		cp	0EBh			; Check subpacket frame delimiter (ZCRCW)
		ld	a, 6			; ZNAK
		jr	nz, rx_wait_zrinit_call_4 ; Send ZNAK if CRC error
		pop	bc			; Restore stack
		ld	a, 4			; Return 4 (ZFILE received successfully)
		ret

rx_wait_zrinit_step_3:	.db	0
		.db	0Bh
		.db	0FEh
		.db	4
		.db	2
		.db	11h
		.db	12h
		.db	0Fh
		.db	8
		.db	10h

rx_wait_zrinit_step_4:	.dw	rx_wait_zrinit_done_2
		.dw	rx_wait_zrinit_done_3
		.dw	rx_wait_zrinit_loop_1
		.dw	rx_wait_zrinit_done_2
		.dw	rx_wait_zrinit_call_2
		.dw	rx_wait_zrinit_step_2
		.dw	rx_wait_zrinit_call_5
		.dw	rx_wait_zrinit_call_1
		.dw	rx_wait_zrinit_done_1
		.dw	rx_wait_zrinit_done_1

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : rx_zfile_header
; Purpose  : Process incoming ZFILE frame and open destination disk file
; Inputs   : None
; Outputs  : CY on error, NC on success
; Modifies : All registers
;============================================================================
rx_zfile_header:
		call	check_zfile_attr	; Process attributes and open file
		ret	c			; Return if aborted with error
		cp	0Bh			; Check frame response code (0Bh = ZFIN)
		jr	z, rx_zfile_heade_call_1
		cp	5			; 5 = ZSKIP (file skipped)
		jr	z, rx_zfile_heade_call_1
		or	a
		ret				; Return on clean completion

;----------------------------------------------------------------------------

rx_zfile_heade_call_1:
		call	rx_wait_zrinit		; Wait for next ZRINIT handshake / file
		ret	c			; Return if error
		cp	4			; Another ZFILE frame arrived?
		jr	z, rx_zfile_header	; Loop to process next file in batch
		cp	0Fh			; 0Fh = ZCOMPL (all files completed)
		ld	a, 0
		ret	z			; Return success on ZCOMPL
		ld	a, 0FFh			; Return error on unexpected response
		scf
		ret

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : check_zfile_attr
; Purpose  : Validate received ZFILE attributes, filename, and options
; Inputs   : None
; Outputs  : CY on reject, NC on accept
; Modifies : All registers
;============================================================================
check_zfile_attr:
		call	rx_file_transfer	; Open destination file and initialize FCB
		jr	nc, check_zfile_attr_ok	; If file opened successfully, receive data
		ld	a, 5			; 5 = ZSKIP frame code
		ld	(patch_zrinit_flags), a	; Set flag to request skipping this file
		or	a
		ret				; Return with skip status

check_zfile_attr_ok:
		cp	9			; Frame code 9 = ZRPOS resume
		jr	z, check_zfile_at_call_1
		ld	hl, rx_char_saved_step_2 ; Clear received byte counter (start from offset 0)
		call	clear_4bytes
check_zfile_at_call_1:
		xor	a			; Reset error count
		ld	(transfer_err_count), a
		call	save_file_pos		; Save initial file position
check_zfile_at_call_2:
		call	sync_file_pos		; Sync position tracking pointers
		call	disk_write_flush	; Commit any pending buffered sectors to disk
		ld	hl, rx_char_saved_step_2 ; Copy current file position to transmit payload
		ld	de, rx_char_saved_step_5
		call	copy_4bytes
		ld	hl, rbuf_bfree		; Clear receive buffer state
		call	clear_6_bytes
		ld	a, 9			; 9 = ZRPOS frame (request sender seek to position)
		call	tx_hex_header		; Transmit ZRPOS frame to sender
rx_data_loop:
		call	rx_header_search	; Wait for incoming sender data header
		ld	hl, zframe_type_table	; Search received frame type in dispatch table
		ld	bc, 7			; 7 table entries
		cpir
		jp	z, dispatch_table_jump	; Jump to matched frame handler
		ld	a, 0FFh			; Unrecognized header: return error
		scf
		ret

;----------------------------------------------------------------------------

rx_data_loop_call_1:
		ld	hl, transfer_err_count	; Increment transfer error count
		inc	(hl)
		call	print_error_count	; Display error count on console
		ld	hl, transfer_err_count	; Check if error count reached 10 (0Ah)
		ld	a, 0Ah
		cp	(hl)
		jp	nz, check_zfile_at_call_2 ; If < 10 errors, send ZRPOS resync
		ld	a, 0FFh			; Exceeded retry limit: abort transfer
		scf
		ret

rx_data_loop_call_2:
		call	zdle_escape_tb_step_2	; Receive subpacket data block
		jp	check_zfile_at_call_2	; Resync position

rx_data_loop_call_3:
		ld	de, rx_char_saved_step_1 ; Compare received position with current offset
		ld	hl, rx_char_saved_step_2
		call	cmp_4bytes_eq
		jp	nz, check_zfile_at_call_2 ; Mismatch: send ZRPOS resync
		call	flush_sector_buffer	; Match: flush buffered sectors to disk and close file
		jr	z, rx_data_loop_call_4	; Success: clear state
rx_data_loop_err_1:
		ld	a, 0Ch			; Disk write failure: send ZFERR frame (0Ch)
		ld	(patch_zrinit_flags), a
		ld	a, 0FFh			; Abort with carry
		scf
		ret

rx_data_loop_call_4:
		call	clear_transfer_state	; Clear transfer state variables
		ld	a, 0Bh			; 0Bh = ZFIN / file complete code
		or	a
		ret				; Return clean

rx_data_loop_call_5:
		ld	hl, transfer_err_count	; Increment error count
		inc	(hl)
		call	print_error_count	; Display error count
		ld	hl, transfer_err_count	; Check if retry count reached 10
		ld	a, 0Ah
		cp	(hl)
		jr	nz, rx_data_loop_call_6	; Send raw recovery sequence
		ld	a, 0FFh			; Abort
		scf
		ret

rx_data_loop_call_6:
		ld	hl, rx_char_saved_step_3 ; Send recovery string
		call	tx_raw_string
		jp	check_zfile_at_call_2	; Send ZRPOS resync

rx_data_loop_call_7:
		ld	de, rx_char_saved_step_1 ; Check if ZDATA position matches current position
		ld	hl, rx_char_saved_step_2
		call	cmp_4bytes_eq
		jp	nz, 0C57h		; If mismatch, resync to expected position
rx_data_loop_call_8:
		call	disp_bsy		; Update animated console spinner
		call	zdle_escape_tb_step_2	; Receive next incoming data subpacket
		ld	hl, zframe_term_table	; Search subpacket delimiter type in table
		ld	bc, 7			; 7 table entries
		cpir
		jp	z, dispatch_table_jump	; Jump to subpacket delimiter handler
		jp	rx_data_loop_call_1	; Delimiter mismatch: record error

rx_data_loop_err_2:
		ld	a, 0FFh			; Abort with error
		scf
		ret

;============================================================================
; Function : calc_pos_offset
; Purpose  : Calculate remaining file offset and synchronize resume position
; Inputs   : None
; Outputs  : File position updated
; Modifies : All registers
;============================================================================
calc_pos_offset:
		xor	a			; Reset transfer error count to 0
		ld	(transfer_err_count), a
		ld	de, pending_write_step_1 ; Add written subpacket byte count to position
		ld	hl, rx_char_saved_step_2
		ld	bc, rx_char_saved_step_2
		call	add32			; Update 32-bit received byte counter
		jp	restore_file_pos	; Restore and update position state and return

rx_data_resync:
		call	calc_pos_offset		; Update position
		jp	rx_data_loop		; Return to header search loop

rx_data_calc_pos:
		call	calc_pos_offset		; Update position
		jp	rx_data_loop_call_8	; Continue receiving next subpacket

rx_data_calc_p_call_1:
		call	calc_pos_offset		; Update position
		ld	hl, rx_char_saved_step_2 ; Copy current position to transmit payload
		ld	de, rx_char_saved_step_5
		call	copy_4bytes
		ld	a, 3			; 3 = ZACK frame type
		call	tx_hex_header		; Send ZACK frame acknowledging data subpacket
		jp	rx_data_loop_call_8	; Continue receiving streaming data

rx_data_calc_p_call_2:
		call	calc_pos_offset		; Update position
		call	disk_write_flush	; Commit buffer to disk
		jp	c, rx_data_loop_err_1	; If disk write failed, report error
		ld	hl, rx_char_saved_step_2 ; Copy position
		ld	de, rx_char_saved_step_5
		call	copy_4bytes
		ld	a, 3			; 3 = ZACK frame type
		call	tx_hex_header		; Send ZACK frame
		jp	rx_data_loop		; Return to header search loop

zframe_type_table:	.db	6
       		.db	0FEh
       		.db	4
       		.db	0Bh
       		.db	0FFh
       		.db	0Ah
       		.db	0FCh

       		.dw	rx_data_loop_call_1
       		.dw	rx_data_loop_call_7
       		.dw	rx_data_loop_call_5
       		.dw	rx_data_loop_call_3
       		.dw	rx_data_loop_call_2
       		.dw	rx_data_loop_call_1
       		.dw	rx_data_loop_call_1

zframe_term_table:	.db	0EBh
       		.db	0EAh
       		.db	0E9h
       		.db	0E8h
       		.db	0FFh
       		.db	0FEh
       		.db	010h

		.dw	rx_data_loop_err_2
 		.dw	rx_data_loop_call_1
		.dw	rx_data_loop_call_5
		.dw	rx_data_resync
		.dw	rx_data_calc_pos
		.dw	rx_data_calc_p_call_1
		.dw	rx_data_calc_p_call_2

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : flush_sector_buffer
; Purpose  : Flush buffered sectors to disk and update transfer status
; Inputs   : None
; Outputs  : Disk buffer written
; Modifies : All registers
;============================================================================
flush_sector_buffer:
		call	print_transfer_stats	; Display final transferred byte count
		call	disk_write_flush	; Flush any remaining buffered data to disk
		ret	c			; Return if disk write error
flush_sector_b_call_1:
		ld	a, 1Ah			; CP/M EOF marker (Ctrl-Z = 1Ah)
		call	disk_write_flu_step_2	; Pad last sector to 128 bytes with Ctrl-Z
		ret	c			; Return if disk error
		ld	hl, cpm_partial_record_bytes ; Check if sector is completely full
		ld	a, 1
		cp	(hl)
		jr	nz, flush_sector_b_call_1 ; Continue padding until 128-byte boundary reached
		ld	a, 0			; Clear active file abort flag
		ld	(transfer_abort_flag), a
		ld	c, F_CLOSE		; BDOS Function 16: Close file
		ld	de, file_fcb		; DE points to FCB
		jp	bdos_s			; Close file and return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : disk_write_flush
; Purpose  : Commit pending disk writes via CP/M BDOS write calls
; Inputs   : None
; Outputs  : CY on disk full/write error
; Modifies : All registers
;============================================================================
disk_write_flush:
		ld	bc, (pending_write_bytes) ; Load number of pending unwritten bytes in buffer
		ld	a, b			; Check if count is zero
		or	c
		ret	z			; Return immediately if buffer empty
		ld	hl, (file_offset_lo)	; HL points to base of receive memory buffer
disk_write_flu_br_1:
		ld	a, (flag_ymodem_active)	; Check if Ymodem/binary transfer mode
		cp	0FFh
		jr	z, disk_write_flu_step_1 ; If binary mode, bypass CRLF conversion
patch_rx_retry_count:	.equ	$+1		; SMC: stores previous byte to detect LF after CR
disk_write_flu_br_2:
		ld	a, 0			; Load previous character
		cp	0Dh			; Was previous character CR?
		jr	z, disk_write_flu_step_1 ; If CR already present, do not insert extra CR
		ld	a, (hl)			; Load current character
		cp	0Ah			; Is current character lone LF?
		jr	nz, disk_write_flu_step_1 ; If not LF, write character directly
		ld	a, 0Dh			; Insert CR (0Dh) before LF for CP/M text format
		call	disk_write_flu_step_2	; Write inserted CR to disk sector buffer
		ret	c			; Return on disk write error
disk_write_flu_step_1:
		ld	a, (hl)			; Load character from buffer
		ld	(patch_rx_retry_count), a ; Save character for next CRLF check
		inc	hl			; Advance memory buffer pointer
		dec	bc			; Decrement pending byte counter
		call	disk_write_flu_step_2	; Write character to disk sector buffer
		ret	c			; Return on disk write error
		ld	a, b			; Check if all pending bytes processed
		or	c
		jr	nz, disk_write_flu_br_1	; Loop until entire memory buffer flushed
		call	print_transfer_stats	; Update on-screen byte counter display
		call	save_file_pos		; Save synchronized file position
		xor	a			; Clear carry (success)
		ret				; Return

;----------------------------------------------------------------------------

disk_write_flu_step_2:
		ld	(smc_write_char_byte), a ; Save character byte into SMC operand
		push	bc			; Preserve BC
		push	de			; Preserve DE
		push	hl			; Preserve HL
smc_write_char_byte:	.equ	$+1		; SMC: immediate byte operand holding character to write
disk_write_flu_call_1:
		ld	c, 0			; Load character byte into C
		ld	hl, cpm_partial_record_bytes ; HL points to 128-byte sector FIFO buffer
		call	aux_fifo_push		; Push byte into sector buffer
		jr	nz, disk_write_flu_done_1 ; If buffer not yet full, continue buffering
		ld	hl, cpm_partial_record_bytes ; Sector buffer full (128 bytes): clear FIFO header
		call	clear_3_bytes
		ld	c, F_DMAOFF		; BDOS Function 26: Set DMA address
		ld	de, rbuf_bfree_step_1	; DMA address = 128-byte sector buffer
		call	bdos
		ld	c, F_MULTISEC		; BDOS Function 44: Set multi-sector count
		ld	e, 1			; Write 1 record
		call	bdos
		ld	c, F_WRITE		; BDOS Function 21: Write sequential record
		ld	de, file_fcb		; DE points to FCB
		call	bdos_s			; Write 128-byte record to disk
		jr	nc, disk_write_flu_call_1 ; If write succeeded, re-push any remaining bytes
disk_write_flu_done_1:
		pop	hl			; Restore HL
		pop	de			; Restore DE
		pop	bc			; Restore BC
		ret				; Return

;============================================================================
; Function : tx_zack_frame
; Purpose  : Send ZACK (acknowledge) frame with current file position
; Inputs   : None
; Outputs  : ZACK frame transmitted
; Modifies : All registers
;============================================================================
tx_zack_frame:
		ld	hl, rx_char_saved_step_5 ; Clear transmit position payload
		call	clear_4bytes
		ld	b, 4			; Transmit up to 4 ZACK retries
tx_zack_frame_call_1:
		push	bc			; Preserve retry countdown
		ld	a, 8			; 8 = ZACK frame type
		call	tx_hex_header		; Send HEX ZACK frame to remote sender
		ld	b, 64h			; Timeout = 100 (64h) ticks
		call	comm_rx_char_filtered	; Wait for sender acknowledgment
		jr	c, tx_zack_fail		; On timeout, retry
		cp	4Fh			; 'O' (part of "OO" completion sequence)
		jr	z, tx_zack_ok
		cp	0FDh			; Alternative ACK character
		jr	z, tx_zack_ok
tx_zack_fail:
		pop	bc			; Restore retry countdown
		djnz	tx_zack_frame_call_1	; Retry up to B times
		push	bc
tx_zack_ok:
		pop	bc			; Discard retry counter
		ld	b, 1			; Drain trailing byte
		call	comm_rx_char_filtered
		xor	a			; Success
		ret				; Return

abort_can_sequence:	.db  18h ;
		.db  18h ;
		.db  18h ;
		.db  18h ;
		.db  18h ;
		.db  18h ;
		.db  18h ;
		.db  18h ;
		.db  18h ;
		.db  18h ;
		.db    8 ;
		.db    8 ;
		.db    8 ;
		.db    8 ;
		.db    8 ;
		.db    8 ;
		.db    8 ;
		.db    8 ;
		.db    8 ;
		.db    8 ;
		.db    0 ;

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : tx_can_sequence
; Purpose  : Send 8-byte CAN (cancel/abort) sequence to terminate transfer
; Inputs   : None
; Outputs  : CAN sequence transmitted to AUX
; Modifies : A, HL
;============================================================================
tx_can_sequence:
		ld	hl, abort_can_sequence	; HL points to 8x CAN (18h) + 8x Backspace (08h) string
;============================================================================
; Function : tx_raw_string
; Purpose  : Transmit null-terminated raw string to AUX port
; Inputs   : HL = pointer to null-terminated string
; Outputs  : Characters transmitted
; Modifies : A, HL
;============================================================================
tx_raw_string:
		ld	a, (hl)			; Load character from string
		inc	hl			; Advance pointer
		or	a			; End of string (null terminator)?
		ret	z			; If null, finished transmitting string
		push	hl			; Preserve string pointer
		call	comm_tx_char_wait	; Transmit character to serial AUX port
		pop	hl			; Restore string pointer
		jr	tx_raw_string		; Repeat for next character

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : comm_rx_char_filtered
; Purpose  : Receive character from AUX with escape, timeout, and CAN checks
; Inputs   : B = timeout count
; Outputs  : A = character, CY on timeout/abort
; Modifies : A, BC
;============================================================================
comm_rx_char_filtered:
		push	bc			; Preserve timeout counter BC
		call	bdos_con_stat		; Check CP/M console input status (BDOS 11)
		call	nz, bdos_con_read	; If key pressed, read console character (BDOS 1)
		cp	1Bh			; Was ESC (1Bh) key pressed by user?
		ld	a, 18h			; Preload CAN (18h) character
		ld	c, 0Ah			; Count = 10 (0Ah)
		call	z, rx_buffer_init_ptrs	; If ESC pressed, inject cancel sequence into buffer
		pop	bc			; Restore timeout counter BC
comm_rx_retry:
		call	rx_byte_timeout		; Attempt to read byte from serial AUX port with timeout
		jr	nz, comm_rx_ok		; If byte received, return success
		djnz	comm_rx_retry		; Decrement retry countdown; repeat
		ld	a, 0FEh			; 0FEh = receive timeout status code
		scf				; Set carry flag (timeout error)
		ret				; Return

comm_rx_ok:
		or	a			; Clear carry flag (success)
		ret				; Return with received character in A

;----------------------------------------------------------------------------
comm_rx_char_raw:
		ld	b, 64h			; Timeout = 100 (64h) iterations
		call	comm_rx_char_filtered	; Read character from AUX port
		ret	c			; Return if error or timeout (CY set)
		and	7Fh			; Mask 7-bit ASCII
		ld	hl, comm_rx_char_r_step_2 ; Search for flow-control characters (DC1, DC3)
		ld	bc, 2			; 2 entries (DC1, DC3)
		cpir
		jr	z, comm_rx_char_raw	; If XON/XOFF flow control character, strip and re-read
		ld	bc, 3			; 3 entries (CR, LF, CAN)
		cpir
		ret	z			; If line control or CAN, return character
		ld	b, a			; Preserve character in B
		and	60h			; Check if control character (bits 5-6 zero)
		jr	nz, comm_rx_char_r_step_1 ; If printable character, accept
		ld	a, (esc_ctrl_chars_flag) ; Check if escaping control characters enabled
		or	a
		jr	nz, comm_rx_char_raw	; If escaping enabled, strip raw control character
comm_rx_char_r_step_1:
		ld	a, b			; Restore received character in A
		ret				; Return character

comm_rx_char_r_step_2:	.db	11h	; dc1
		.db	13h	; dc3
		.db	0dh	; cr
		.db	0ah	; lf
		.db	18h	; can

;============================================================================
; Function : rx_zdle_byte
; Purpose  : Receive ZDLE-escaped byte (decodes ZCRCE, ZCRCG, ZCRCQ, ZCRCW)
; Inputs   : None
; Outputs  : A = unescaped byte, CY on error/CAN
; Modifies : A, BC, DE, HL
;============================================================================
rx_zdle_byte:
		ld	b, 64h			; Timeout = 100 (64h) iterations
		call	comm_rx_char_filtered	; Read character from AUX port
		ret	c			; Return on timeout / error
		ld	e, a			; Preserve character in E
rx_zdle_check_ctl:
		and	60h			; Check if control character
		ld	a, e			; Restore character into A
		ret	nz			; Return immediately if printable (not a control char)
		cp	18h			; Is it ZDLE escape character (18h)?
		jr	z, rx_zdle_is_escape	; If ZDLE, process escaped character sequence
		ld	hl, zdle_escape_tbl	; Search table of stripped flow control characters
		ld	bc, 4
		cpir
		jr	z, rx_zdle_byte		; If flow control character, ignore and re-read
		ld	a, (esc_ctrl_chars_flag) ; Check if control characters escaped
		or	a
		jr	nz, rx_zdle_byte	; If escaping active, ignore unexpected control char
		ld	a, e			; Return unescaped control character
		ret

rx_zdle_is_escape:
		ld	b, 64h			; Timeout = 100 ticks
		call	comm_rx_char_filtered	; Read character following ZDLE
		ret	c			; Return on timeout
		cp	18h			; Check for repeated CAN/ZDLE abort sequence
		jr	nz, rx_zdle_is_esc_loop_1
		ld	b, 64h			; Check 2nd CAN
		call	comm_rx_char_filtered
		ret	c
		cp	18h
		jr	nz, rx_zdle_is_esc_loop_1
		ld	b, 64h			; Check 3rd CAN
		call	comm_rx_char_filtered
		ret	c
		cp	18h
		jr	nz, rx_zdle_is_esc_loop_1
		ld	b, 64h			; Check 4th CAN
		call	comm_rx_char_filtered
		ret	c
rx_zdle_is_esc_loop_1:
		ld	hl, zdle_escape_tb_step_1 ; Match escaped character against lookup table
		ld	bc, 0Bh			; 11 entries in table
		cpir
		jp	z, dispatch_table_jump	; Jump to escaped character handler
		ld	l, a			; Save character in L
		ld	a, (esc_ctrl_chars_flag) ; Check if control characters escaped
		or	a
		jr	z, rx_zdle_is_esc_br_1	; If not active, skip
		ld	a, l			; Check bits 5-6
		and	60h
		jr	z, rx_zdle_is_escape	; If control character, re-enter escape state
rx_zdle_is_esc_br_1:
		ld	a, l			; Load character
		and	60h			; Check if in range 40h-7Fh (escaped control char)
		cp	40h
		jr	nz, rx_zdle_is_esc_err_1 ; If not in range, framing error
		ld	a, l			; Unescape: invert bit 6 (XOR 40h) to restore control code
		xor	40h
		ret				; Return unescaped character

rx_zdle_is_esc_step_1:
		ld	a, 7Fh			; Escaped rubout / DEL (7Fh)
		ret

rx_zdle_is_esc_step_2:
		ld	a, 0FFh			; Escaped 0FFh byte
		ret

rx_zdle_is_esc_err_1:
		ld	a, 0FFh			; Framing error code
rx_zdle_is_esc_err_2:
		or	80h			; Set bit 7
		scf				; Set carry (error)
		ret				; Return

zdle_escape_tbl:	.db  11h ;
		.db  91h ; ?
		.db  13h ;
		.db  93h ; ?
zdle_escape_tb_step_1:	.db  11h ;
		.db  91h ; ?
		.db  13h ;
		.db  93h ; ?
		.db  18h ;
		.db  68h ; h
		.db  69h ; i
		.db  6Ah ; j
		.db  6Bh ; k
		.db  6Ch ; l
		.db  6Dh ; m

		.dw	rx_zdle_is_esc_step_2
		.dw	rx_zdle_is_esc_step_1
		.dw	rx_zdle_is_esc_err_2
		.dw	rx_zdle_is_esc_err_2
		.dw	rx_zdle_is_esc_err_2
		.dw	rx_zdle_is_esc_err_2
		.dw	rx_zdle_is_esc_err_2
		.dw	rx_zdle_is_escape
		.dw	rx_zdle_is_escape
		.dw	rx_zdle_is_escape
		.dw	rx_zdle_is_escape

zdle_escape_tb_step_2:
		or	a			; Clear carry
		ld	hl, (file_offset_hi)	; Memory buffer top limit
		ld	de, (file_pos_backup_hi) ; Current buffer write pointer
		sbc	hl, de			; Check if buffer has remaining space
		jp	c, handle_zcrce		; If buffer full, terminate subpacket with ZCRCE
		call	init_crc_acc		; Reset CRC accumulators (CRC-16 / CRC-32)
		ld	hl, 0			; Reset pending subpacket byte counter to 0
		ld	(pending_write_step_1), hl
zdle_escape_tb_call_1:
		call	rx_zdle_byte		; Read next unescaped byte from stream
		jp	c, rx_packet_crc_err	; If carry set, delimiter reached or CRC error
		call	check_rx_overrun	; Check if 32-bit CRC active (Z flag set)
		call	z, crc32_update		; Update 32-bit CRC
		call	nz, crc16		; Update 16-bit CRC
		ld	hl, (file_offset_hi)	; Check remaining memory buffer space
		ld	bc, (file_pos_backup_hi)
		sbc	hl, bc
		jp	z, handle_zcrce		; If buffer completely filled, treat as ZCRCE
		inc	bc			; Advance buffer write count
		ld	(file_pos_backup_hi), bc
		ld	hl, (pending_write_step_1) ; Increment pending subpacket byte counter
		inc	hl
		ld	(pending_write_step_1), hl
		ld	hl, (file_pos_backup_lo) ; Store received data byte into memory buffer
		ld	(hl), a
		inc	hl			; Advance memory pointer
		ld	(file_pos_backup_lo), hl
		jr	zdle_escape_tb_call_1	; Continue receiving subpacket payload bytes

;============================================================================
; Function : zdle_dispatch_tbl
; Purpose  : ZDLE packet terminator lookup table
; Inputs   : None
; Outputs  : Table structure
; Modifies : None
;============================================================================
zdle_dispatch_tbl:	.db 0E8h ; è
		.db 0E9h ; é
		.db 0EAh ; ê
		.db 0EBh ; ë
		.db  98h ; ?
		.db 0FFh ; ÿ
		.db 0FEh ; þ

		.dw	handle_zcrcg
		.dw	handle_zcrce
		.dw	handle_zcrcq
		.dw	rx_chk_crc16
		.dw	rx_chk_crc16
		.dw	rx_chk_crc16
		.dw	rx_chk_crc16

zcrc_term_table:	.db 0E8h ; è
		.db 0E9h ; é
		.db 0EAh ; ê
		.db 0EBh ; ë
		.db  98h ; ?
		.db 0FFh ; ÿ
		.db 0FEh ; þ

		.dw	handle_zcrcg
		.dw	handle_zcrce
		.dw	handle_zcrcq
		.dw	rx_chk_crc32
		.dw	rx_chk_crc32
		.dw	rx_chk_crc32
		.dw	rx_chk_crc32

rx_packet_crc_err:
		ld	hl, zcrc_term_table	; HL points to 32-bit CRC delimiter lookup table
		ld	bc, 7			; 7 table entries
		call	check_rx_overrun	; Check if 32-bit CRC mode active (Z set)
		jr	z, rx_packet_crc_loop_1	; If CRC-32 mode, use zcrc_term_table
		ld	hl, zdle_dispatch_tbl	; Otherwise use 16-bit CRC table
		ld	bc, 7
rx_packet_crc_loop_1:
		cpir				; Search delimiter in dispatch table
		jp	z, dispatch_table_jump	; Jump to matched delimiter handler
;============================================================================
; Function : handle_zcrce
; Purpose  : Handle ZCRCE frame terminator (CRC follows, header packet follows)
; Inputs   : None
; Outputs  : CY set, A = 0FFh
; Modifies : A, F
;============================================================================
handle_zcrce:
		ld	a, 0FFh			; ZCRCE: frame end, header packet follows
		scf				; Set carry
		ret				; Return

;============================================================================
; Function : handle_zcrcg
; Purpose  : Handle ZCRCG frame terminator (CRC follows, continue streaming)
; Inputs   : None
; Outputs  : CY set
; Modifies : F
;============================================================================
handle_zcrcg:
		scf				; ZCRCG: frame end, continue streaming without ACK
		ret				; Return with carry

;============================================================================
; Function : handle_zcrcq
; Purpose  : Handle ZCRCQ frame terminator (CRC follows, expect ZACK response)
; Inputs   : None
; Outputs  : CY set, A = 10h
; Modifies : A, F
;============================================================================
handle_zcrcq:
		ld	a, 10h			; ZCRCQ: frame end, request ZACK from receiver
		scf				; Set carry
		ret				; Return

;============================================================================
; Function : rx_chk_crc16
; Purpose  : Verify received packet 16-bit CRC against computed CRC-16
; Inputs   : None
; Outputs  : Z if CRC matches, NZ on CRC error
; Modifies : A, B, HL
;============================================================================
rx_chk_crc16:
		ld	(zdle_escape_flag), a	; Save delimiter frame byte
		and	7Fh			; Mask bit 7
		call	crc16			; Include delimiter in CRC-16 calculation
		ld	b, 2			; Read 2 incoming CRC-16 bytes
rx_chk_crc16_loop:
		push	bc			; Preserve byte counter
		call	rx_zdle_byte		; Read next unescaped CRC byte
		call	crc16			; Update CRC-16 accumulator
		pop	bc			; Restore byte counter
		jp	c, rx_packet_crc_err	; On escape/framing error, abort
		djnz	rx_chk_crc16_loop	; Loop for both CRC bytes
		ld	a, h			; Test computed CRC-16 (should be 0000h)
		or	l
		jr	z, rx_chk_crc16_l_step_1 ; If zero, CRC match verified!
rx_chk_crc16_l_err_1:
		ld	a, 0FFh			; CRC mismatch error code
		scf				; Set carry flag
		ret				; Return error

rx_chk_crc16_l_step_1:
		ld	a, (zdle_escape_flag)	; Restore original delimiter byte
		or	a			; Clear carry (success)
		ret				; Return delimiter code in A

;============================================================================
; Function : rx_chk_crc32
; Purpose  : Verify received packet 32-bit CRC against computed CRC-32
; Inputs   : None
; Outputs  : Z if CRC matches, NZ on CRC error
; Modifies : A, B, DE, HL
;============================================================================
rx_chk_crc32:
		ld	(zdle_escape_flag), a	; Save delimiter frame byte
		and	7Fh			; Mask bit 7
		call	crc32_update		; Include delimiter in CRC-32 calculation
		ld	b, 4			; Read 4 incoming CRC-32 bytes
rx_chk_crc32_loop:
		push	bc			; Preserve byte counter
		call	rx_zdle_byte		; Read next unescaped CRC byte
		call	crc32_update		; Update CRC-32 accumulator
		pop	bc			; Restore byte counter
		jp	c, rx_packet_crc_err	; On error, abort
		djnz	rx_chk_crc32_loop	; Loop for all 4 CRC bytes
		ld	hl, rbuf_bfree_step_3	; HL points to computed 32-bit CRC
		ld	de, crc32_final_xor	; DE points to expected CRC-32 residual constant
		call	cmp_4bytes_eq		; Compare computed CRC with residual
		jp	z, rx_chk_crc16_l_step_1 ; If match, return success!
		jp	rx_chk_crc16_l_err_1	; If mismatch, return CRC error

;============================================================================
; Function : check_rx_overrun
; Purpose  : Check for serial receive buffer overrun or frame framing errors
; Inputs   : None
; Outputs  : A preserved, flags set
; Modifies : A, F
;============================================================================
check_rx_overrun:
		ld	e, a			; Preserve A in E
		ld	a, (rx_hdr_crc_format)	; Check active CRC format flag (10h=CRC16, 20h=CRC32)
		cp	20h			; Compare with 20h (CRC-32)
		ld	a, e			; Restore A
		ret				; Return with Z flag set if CRC-32 active

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : save_file_pos
; Purpose  : Save current 32-bit file position into backup state register
; Inputs   : None
; Outputs  : file_pos_backup_lo updated
; Modifies : DE, HL
;============================================================================
save_file_pos:
		ld	hl, file_offset_lo	; HL points to memory buffer bottom
		ld	de, file_pos_backup_lo	; DE points to position backup low word
		ldi				; Copy low byte
		ldi				; Copy high byte
		ld	hl, 0			; Reset buffer offset high word to 0
		ld	(file_pos_backup_hi), hl
;============================================================================
; Function : restore_file_pos
; Purpose  : Restore 32-bit file position from backup state register
; Inputs   : None
; Outputs  : file_pos_backu_step_1 updated
; Modifies : DE, HL
;============================================================================
restore_file_pos:
		ld	hl, file_pos_backup_lo	; HL points to backup position block
		ld	de, file_pos_backu_step_1 ; DE points to active position block
file_pos_copy_4b:
		ldi				; Copy byte 0
		ldi				; Copy byte 1
		ldi				; Copy byte 2
		ldi				; Copy byte 3
		ret				; Return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : sync_file_pos
; Purpose  : Synchronize current file position with remote sender position
; Inputs   : None
; Outputs  : Position synchronized
; Modifies : DE, HL
;============================================================================
sync_file_pos:
		ld	hl, file_pos_backu_step_1 ; HL points to active position block
		ld	de, file_pos_backup_lo	; DE points to backup position block
		jr	file_pos_copy_4b	; Copy 4 bytes and return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : rx_header_search
; Purpose  : Search incoming stream for ZPAD/ZDLE frame header sequence
; Inputs   : None
; Outputs  : A = frame type, CY on error/timeout
; Modifies : All registers
;============================================================================
rx_header_search:
		xor	a			; Clear frame type
		ld	(rx_frame_type), a
		ld	hl, 400h		; Frame byte search limit = 1024 (400h) bytes
		ld	(rx_frame_len), hl
rx_header_search_init:
		ld	a, 5			; Retry search limit = 5
		ld	(rx_retry_limit), a
rx_header_search_loop:
		ld	b, 64h			; Timeout = 100 ticks
		call	comm_rx_char_filtered	; Read character from serial port
		jp	c, rx_header_search_fail ; Return on timeout
		ld	hl, zheader_search_tbl1	; Match header sync characters (*, :, etc.)
		ld	bc, 3
		cpir
		jp	z, dispatch_table_jump	; Jump to matched sync state
		jr	rx_header_sear_step_1

;----------------------------------------------------------------------------

		ld	hl, rx_retry_limit	; Decrement sync retry counter
		dec	(hl)
		ld	a, 10h			; Status code 10h
		jp	z, rx_header_search_fail ; Abort if retry limit exhausted
		ld	b, 0Ah			; Timeout = 10 ticks
		call	comm_rx_char_filtered	; Read next sync character
		jr	c, rx_header_search_loop
		ld	hl, zheader_search_tbl2	; Match second sync character
		ld	bc, 2
		cpir
		jp	z, dispatch_table_jump	; Jump to matched sync state
		jr	rx_header_sear_step_1

		ld	hl, rx_retry_limit	; Decrement sync retry counter
		dec	(hl)
		ld	a, 10h
		jp	z, rx_header_search_fail
		jr	rx_header_search_loop

		ld	b, 0Ah			; Timeout = 10 ticks
		call	comm_rx_char_filtered
		jr	c, rx_header_sear_br_1
rx_header_sear_step_1:
		ld	hl, (rx_frame_len)	; Decrement total search length counter
		dec	hl
		ld	(rx_frame_len), hl
		ld	a, h			; Check if search limit reached 0
		or	l
		ld	a, 0FCh			; 0FCh = frame search exhausted error code
		jp	z, rx_header_search_fail
		jp	rx_header_search_init	; Continue header search loop

;----------------------------------------------------------------------------

rx_header_sear_br_1:
		ld	a, 0FFh			; Abort code
		jp	rx_header_search_fail

		ld	a, 5			; Reset retry limit to 5
		ld	(rx_retry_limit), a
		call	comm_rx_char_raw	; Read raw character
		jr	c, rx_header_search_fail
		ld	hl, zheader_search_tbl3	; Match binary sync characters
		ld	bc, 2
		cpir
		jp	z, dispatch_table_jump	; Jump to matched sync state
		jr	rx_header_sear_step_1

		call	comm_rx_char_raw	; Read raw header type identifier
		jr	c, rx_header_search_fail
		ld	hl, zheader_search_tbl4	; Match header format: 'A'=ZBIN, 'B'=ZHEX, 'C'=ZBIN32
		ld	bc, 4
		cpir
		jp	z, dispatch_table_jump	; Jump to matched decoder routine
		jr	rx_header_sear_step_1

		ld	a, 10h			; CRC format = 16-bit CRC (10h)
		ld	(rx_hdr_crc_format), a
		call	rx_hex_header		; Decode ZHEX header (hex ASCII)
		jr	rx_header_sear_call_1

		ld	a, 10h			; CRC format = 16-bit CRC (10h)
		ld	(rx_hdr_crc_format), a
		call	rx_bin16_header		; Decode ZBIN header (binary 16-bit CRC)
		jr	rx_header_sear_call_1

		ld	a, 20h			; CRC format = 32-bit CRC (20h)
		ld	(rx_hdr_crc_format), a
		call	rx_bin32_header		; Decode ZBIN32 header (binary 32-bit CRC)
rx_header_sear_call_1:
		push	af			; Preserve return frame type
		ld	hl, rx_char_saved_step_1 ; Copy received header flags to backup register
		ld	de, rx_char_saved_step_6
		call	copy_4bytes
		pop	af			; Restore frame type
rx_header_search_fail:
		ld	hl, zheader_search_tbl5	; Match frame type against recognized errors/signals
		ld	bc, 6
		cpir
		jr	nz, rx_header_sear_step_2
		cp	98h			; Check special abort signal
		jr	nz, rx_header_sear_err_1
		ld	a, 10h
rx_header_sear_err_1:
		scf				; Set carry flag (error)
		ret				; Return

rx_header_sear_step_2:
		or	a			; Clear carry (success)
		ret				; Return frame type in A

;----------------------------------------------------------------------------

zheader_search_tbl1:	.db  18h ;
		.db 0AAh ; ª
		.db  2Ah ; *
		.db  3Ah ; :
		.db  10h ;
		.db  3Ah ; :
		.db  10h ;
		.db 0F5h ; õ
		.db  0Fh ;

zheader_search_tbl2: 	.db  6Bh ; k
		.db  18h ;
		.db  12h ;
		.db  10h ;
		.db  1Dh ;
		.db  10h ;

zheader_search_tbl3:	.db  2Ah ; *
		.db  18h ;
		.db  51h ; Q
		.db  10h ;
		.db  3Fh ; ?
		.db  10h ;

zheader_search_tbl4: 	.db  43h ; C
		.db  41h ; A
		.db  42h ; B
		.db  18h ;
		.db 0F5h ; õ
		.db  0Fh ;

		.db  63h ; c
		.db  10h ;
		.db  6Dh ; m
		.db  10h ;
		.db  77h ; w
		.db  10h ;

zheader_search_tbl5:	.db  98h ; ?
		.db    6 ;
		.db  10h ;
		.db 0FFh ; ÿ
		.db 0FEh ; þ
		.db 0FCh ; ü

;============================================================================
; Function : rx_bin32_header
; Purpose  : Receive 32-bit binary header (ZBIN32) with 4-byte CRC-32
; Inputs   : None
; Outputs  : rx_frame_type=type, rx_char_saved_step_1=flags, CY on error
; Modifies : All registers
;============================================================================
rx_bin32_header:
		call	init_crc_acc		; Reset CRC accumulators
		call	rx_zdle_byte		; Read frame type byte
		ret	c			; Return on error
		ld	(rx_frame_type), a	; Save frame type
		call	crc32_update		; Update CRC-32 with frame type byte
		ld	hl, rx_char_saved_step_1 ; HL points to 4 header flag bytes
		ld	b, 4			; Read 4 flag bytes
rx_bin32_heade_call_1:
		push	bc			; Preserve byte counter
		push	hl			; Preserve flag pointer
		call	rx_zdle_byte		; Read unescaped flag byte
		call	crc32_update		; Update CRC-32
		pop	hl			; Restore flag pointer
		pop	bc			; Restore byte counter
		ld	(hl), a			; Store flag byte
		inc	hl			; Advance pointer
		ret	c			; Return on read error
		djnz	rx_bin32_heade_call_1	; Loop for all 4 flag bytes
		ld	b, 4			; Read 4 CRC-32 bytes
rx_bin32_heade_call_2:
		push	bc			; Preserve byte counter
		call	rx_zdle_byte		; Read unescaped CRC byte
		call	crc32_update		; Update CRC-32
		pop	bc			; Restore byte counter
		ret	c			; Return on read error
		djnz	rx_bin32_heade_call_2	; Loop for all 4 CRC bytes
		ld	hl, rbuf_bfree_step_3	; HL points to computed CRC-32
		ld	de, crc32_final_xor	; DE points to expected CRC-32 residual constant
		call	cmp_4bytes_eq		; Compare computed CRC with residual
		jr	z, rx_bin16_heade_step_1 ; If match, frame is valid!
		jr	rx_bin16_heade_err_1	; If mismatch, report CRC error

;============================================================================
; Function : rx_bin16_header
; Purpose  : Receive 16-bit binary header (ZBIN) with 2-byte CRC-16
; Inputs   : None
; Outputs  : rx_frame_type=type, rx_char_saved_step_1=flags, CY on error
; Modifies : All registers
;============================================================================
rx_bin16_header:
		call	init_crc_acc		; Reset CRC accumulators
		call	rx_zdle_byte		; Read frame type byte
		ret	c			; Return on error
		ld	(rx_frame_type), a	; Save frame type
		call	crc16			; Update CRC-16 with frame type byte
		ld	hl, rx_char_saved_step_1 ; HL points to 4 header flag bytes
		ld	b, 4			; Read 4 flag bytes
rx_bin16_heade_call_1:
		push	bc			; Preserve byte counter
		push	hl			; Preserve flag pointer
		call	rx_zdle_byte		; Read unescaped flag byte
		call	crc16			; Update CRC-16
		pop	hl			; Restore flag pointer
		pop	bc			; Restore byte counter
		ld	(hl), a			; Store flag byte
		inc	hl			; Advance pointer
		ret	c			; Return on read error
		djnz	rx_bin16_heade_call_1	; Loop for all 4 flag bytes
		ld	b, 2			; Read 2 CRC-16 bytes
rx_bin16_heade_call_2:
		push	bc			; Preserve byte counter
		call	rx_zdle_byte		; Read unescaped CRC byte
		call	crc16			; Update CRC-16
		pop	bc			; Restore byte counter
		ret	c			; Return on read error
		djnz	rx_bin16_heade_call_2	; Loop for both CRC bytes
		ld	a, h			; Test computed CRC-16 (should be 0000h)
		or	l
		jr	nz, rx_bin16_heade_err_1 ; If non-zero, report CRC error
rx_bin16_heade_step_1:
		ld	a, 0FFh			; Mark valid header received
		ld	(rx_char_saved), a
		ld	a, (rx_frame_type)	; Return received frame type in A
		ret				; Return

rx_bin16_heade_err_1:
		ld	a, 0FFh			; CRC error code
		scf				; Set carry
		ret				; Return

;============================================================================
; Function : rx_hex_header
; Purpose  : Receive hexadecimal frame header (ZHEX) with ASCII hex nibbles
; Inputs   : None
; Outputs  : rx_frame_type=type, rx_char_saved_step_1=flags, CY on error
; Modifies : All registers
;============================================================================
rx_hex_header:
		call	init_crc_acc		; Reset CRC accumulators
		call	rx_hex_byte		; Read frame type byte from 2 hex ASCII digits
		ret	c			; Return on error
		ld	(rx_frame_type), a	; Save frame type
		call	crc16			; Update CRC-16 with frame type byte
		ld	hl, rx_char_saved_step_1 ; HL points to 4 header flag bytes
		ld	b, 4			; Read 4 flag bytes
rx_hex_nibble_loop:
		push	bc			; Preserve byte counter
		push	hl			; Preserve flag pointer
		call	rx_hex_byte		; Read next hex byte
		jr	nc, rx_hex_next_byte	; If byte received successfully, proceed
		pop	hl			; Restore flag pointer
		pop	bc			; Restore byte counter
		ret				; Return on error

rx_hex_next_byte:
		call	crc16			; Update CRC-16 with flag byte
		pop	hl			; Restore flag pointer
		pop	bc			; Restore byte counter
		ld	(hl), a			; Store flag byte
		inc	hl			; Advance pointer
		djnz	rx_hex_nibble_loop	; Loop for all 4 flag bytes
		ld	b, 2			; Read 2 CRC-16 hex bytes
rx_hex_next_by_call_1:
		push	bc			; Preserve byte counter
		call	rx_hex_byte		; Read next CRC hex byte
		jr	nc, rx_hex_next_by_loop_1
		pop	bc			; Restore byte counter
		ret				; Return on error

rx_hex_next_by_loop_1:
		call	crc16			; Update CRC-16 with CRC byte
		pop	bc			; Restore byte counter
		djnz	rx_hex_next_by_call_1	; Loop for both CRC bytes
		ld	a, h			; Test computed CRC-16 (should be 0000h)
		or	l
		jr	nz, rx_hex_next_by_err_1 ; If non-zero, report CRC error
		ld	b, 0Ah			; Timeout = 10 ticks
		call	comm_rx_char_filtered	; Read trailing CR
		cp	0Dh			; Check if CR received
		jr	nz, rx_hex_next_by_step_1
		ld	b, 0Ah			; Timeout = 10 ticks
		call	comm_rx_char_filtered	; Read trailing LF
rx_hex_next_by_step_1:
		or	a			; Clear carry (success)
		ld	a, 0FFh			; Mark valid header received
		ld	(rx_char_saved), a
		ld	a, (rx_frame_type)	; Return received frame type in A
		ret				; Return

rx_hex_next_by_err_1:
		ld	a, 0FFh			; CRC error code
		scf				; Set carry
		ret				; Return

;============================================================================
; Function : rx_hex_byte
; Purpose  : Receive two ASCII hex characters from AUX and decode into binary byte
; Inputs   : None
; Outputs  : A = decoded byte, CY on error
; Modifies : A, B
;============================================================================
rx_hex_byte:
		call	comm_rx_char_raw	; Read first ASCII hex character from AUX port
		ret	c			; Abort if timeout or serial error (CY set)
		call	ascii_hex_to_nibble	; Convert ASCII hex ('0'-'9', 'a'-'f') to 4-bit nibble
		jr	nz, hex_nibble_err	; Error if invalid hex character
		rlca				; Shift high nibble into bits 4-7
		rlca
		rlca
		rlca
		ld	b, a			; Save high nibble in B
		push	bc
		call	comm_rx_char_raw	; Read second ASCII hex character from AUX port
		pop	bc
		ret	c			; Abort if timeout or serial error (CY set)
		call	ascii_hex_to_nibble	; Convert second ASCII hex character to nibble
		jr	nz, hex_nibble_err	; Error if invalid hex character
		or	b			; Merge high nibble from B with low nibble in A
		ret

hex_nibble_err:
		ld	a, 0FFh			; Hex conversion error code
		scf				; Set carry
		ret				; Return

;============================================================================
; Function : ascii_hex_to_nibble
; Purpose  : Convert single ASCII hex char ('0'-'9','a'-'f') into 4-bit nibble
; Inputs   : A = ASCII char
; Outputs  : A = numeric value (0..15)
; Modifies : A, L
;============================================================================
ascii_hex_to_nibble:
		ld	l, a			; Save original character in L
		sub	30h			; Subtract ASCII '0' offset
		cp	0Ah			; In digit range '0'-'9'?
		jr	c, hex_nibble_done	; If < 10, conversion complete
		sub	27h			; Subtract offset for lowercase 'a'-'f'
hex_nibble_done:
		ld	l, a			; Save nibble value in L
		and	0F0h			; Check if upper nibble is clear
		ld	a, l			; Return nibble in A
		ret				; Return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : tx_zrinit_frame
; Purpose  : Send ZRINIT (Receiver Initialize) frame declaring capabilities
; Inputs   : None
; Outputs  : ZRINIT frame sent to sender
; Modifies : All registers
;============================================================================
tx_zrinit_frame:
		ld	a, 0FFh			; Preload EOF seen flag
		ld	(rx_eof_seen), a
		call	save_file_pos		; Save current file position snapshot
		ld	a, (rx_hdr_crc_format)	; Check CRC format (10h=CRC-16, 20h=CRC-32)
		cp	10h
		ld	a, 43h			; 'C' character for CRC mode handshake
		jr	z, tx_zrinit_send	; If CRC-16, send 'C'
		ld	a, 15h			; NAK (15h) character for checksum mode

tx_zrinit_send:
		call	comm_tx_char_wait	; Send handshake polling character to sender
		ld	b, 64h			; Timeout = 100 ticks
		call	rx_frame_dispatcher	; Wait for incoming sender frame
		or	a			; Test response status code
		jr	z, tx_zrinit_send_call_2 ; Frame received cleanly
		cp	0F6h			; Check if sender completed transfer (EOT)
		jr	z, tx_zrinit_send_call_1 ; If EOT, acknowledge with ACK
		ld	a, 0FFh			; Handshake timeout error code
		scf				; Set carry
		ret				; Return

;----------------------------------------------------------------------------

tx_zrinit_send_call_1:
		ld	a, 6			; ACK (06h) character
		call	comm_tx_char_wait	; Send ACK to remote sender
		ld	b, 0Ah			; Wait briefly for sender response
		call	comm_rx_char_filtered
		jr	tx_zrinit_frame		; Re-poll for subsequent files

;----------------------------------------------------------------------------

tx_zrinit_send_call_2:
		ld	a, 6			; ACK (06h) character
		call	comm_tx_char_wait	; Acknowledge received frame
		xor	a			; Return success (00h)
		ret				; Return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : tx_zrpos_frame
; Purpose  : Send ZRPOS frame requesting sender resume at file position
; Inputs   : None
; Outputs  : ZRPOS frame sent to sender
; Modifies : All registers
;============================================================================
tx_zrpos_frame:
		ld	a, 0FFh			; Set EOF seen flag
		ld	(rx_eof_seen), a
		ld	(flag_ymodem_active), a	; Set Ymodem active state
		xor	a			; Reset frame packet sequence tracker
		ld	(zmodem_flag_d07), a
		call	save_file_pos		; Save current file position snapshot
		ld	hl, rx_char_saved_step_2 ; Clear received byte counter
		call	clear_4bytes
		ld	a, (rx_hdr_crc_format)	; Check CRC format
		cp	10h
		ld	a, 43h			; 'C' character for CRC handshake
		jr	z, tx_zrpos_send
		ld	a, 15h			; NAK for checksum handshake
tx_zrpos_send:
		call	comm_tx_char_wait	; Transmit handshake polling character
tx_zrpos_send_br_1:
		ld	a, (zmodem_flag_d07)	; Check packet sequence tracker
		or	a
		ld	b, 82h			; Timeout = 130 ticks for initial packet
		jr	z, tx_zrpos_send_call_1
		ld	b, 32h			; Timeout = 50 ticks for subsequent packets
tx_zrpos_send_call_1:
		call	rx_frame_dispatcher	; Dispatch incoming sender frame
		jr	c, tx_zrpos_send_call_3	; On carry, handle completion or error
		push	af			; Preserve packet sequence number
		call	print_transfer_stats	; Update console byte counter display
		pop	af			; Restore sequence number
		ld	hl, zmodem_flag_d07	; Check expected sequence number
		cp	(hl)
		jr	z, tx_zrpos_send_call_2	; Duplicate sequence: re-ACK
		dec	a			; Next expected sequence number?
		cp	(hl)
		jr	nz, tx_zrpos_send_br_2	; Sequence mismatch: error
		inc	(hl)			; Advance expected sequence number
		ld	de, file_pos_backup_hi	; Add block size to received byte count
		ld	hl, rx_char_saved_step_2
		ld	bc, rx_char_saved_step_2
		call	add32			; Update 32-bit received byte counter
		call	restore_file_pos	; Restore position tracker
		call	disk_write_flush	; Commit received sector to disk
		jr	c, tx_zrpos_send_err_1	; Abort on disk write error

tx_zrpos_send_call_2:
		call	sync_file_pos		; Synchronize file position state
		ld	a, 6			; ACK (06h) character
		call	comm_tx_char_wait	; Send ACK acknowledging block
		jr	tx_zrpos_send_br_1	; Wait for next incoming data block

tx_zrpos_send_call_3:
		cp	0F6h			; Check if sender completed transfer (EOT)
		jr	nz, tx_zrpos_send_br_2
		call	flush_sector_buffer	; Flush remaining sectors and close FCB
		jr	c, tx_zrpos_send_err_1	; Abort on disk write error
		call	clear_transfer_state	; Clear transfer state variables
		ld	a, 6			; ACK (06h) character
		call	comm_tx_char_wait	; Acknowledge EOT to sender
		xor	a			; Success (00h)
		ret				; Return

;----------------------------------------------------------------------------

tx_zrpos_send_br_2:
		cp	0FFh			; Check for retry timeout
		jr	nz, tx_zrpos_send_err_1
		ld	a, (rx_eof_seen)	; Check EOF seen flag
		cp	0FFh
		jr	nz, tx_zrpos_send_err_1
		ld	a, (rx_hdr_crc_format)	; If CRC mode active, downgrade to checksum
		or	a
		jr	z, tx_zrpos_send_err_1	; If already checksum, abort
		xor	a			; Fallback to 8-bit checksum mode
		ld	(rx_hdr_crc_format), a
		jp	tx_zrpos_frame		; Re-initiate transfer in checksum mode

tx_zrpos_send_err_1:
		ld	a, 0FFh			; Transfer error code
		scf				; Set carry
		ret				; Return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : rx_frame_dispatcher
; Purpose  : Dispatch received frame by type (ZFILE, ZDATA, ZEOF, ZFIN)
; Inputs   : B = frame timeout
; Outputs  : Frame processed
; Modifies : All registers
;============================================================================
rx_frame_dispatcher:
		ld	a, b			; Save timeout counter
		ld	(rx_retry_counter), a
		xor	a			; Reset transfer error count to 0
		ld	(transfer_err_count), a
		ld	a, 0			; Reset CAN abort counter
		ld	(rx_flag_d09), a
rx_dispatcher_loop:
		ld	a, (rx_retry_counter)	; Load timeout countdown
		ld	b, a
		call	comm_rx_char_filtered	; Read frame start character (SOH, STX, EOT, CAN)
		ld	(rx_dispatcher_type), a	; Save received character
		ld	hl, rx_dispatcher_tbl	; Search character in frame dispatch table
		ld	bc, 4			; 4 table entries (STX, SOH, EOT, CAN)
		cpir
		jp	z, dispatch_table_jump	; Jump to matched frame type handler
		jp	rx_dispatcher_call_5	; Unrecognized character: report error

;----------------------------------------------------------------------------

rx_dispatcher_tbl:	.db    2 ;
		.db    1 ;
		.db    4 ;
		.db  18h ;

		.dw	rx_dispatcher_br_2
		.dw	rx_dispatcher_call_4
		.dw	rx_dispatcher_call_1
		.dw	rx_dispatcher_br_1

rx_dispatcher_br_1:
		ld	hl, 400h		; STX frame packet length = 1024 (400h) bytes
		jr	rx_dispatcher_call_2

rx_dispatcher_call_1:
		ld	hl, 80h			; SOH frame packet length = 128 (80h) bytes
rx_dispatcher_call_2:
		ld	(active_packet_len), hl	; Save active packet length
		ld	b, 0Ah			; Timeout = 10 ticks
		call	comm_rx_char_filtered	; Read packet sequence number
		ld	(patch_rx_frame_type), a ; Save sequence number
		jp	c, rx_dispatcher_call_5	; On timeout, record error
		ld	b, 0Ah			; Timeout = 10 ticks
		call	comm_rx_char_filtered	; Read inverted packet sequence number
		jp	c, rx_dispatcher_call_5	; On timeout, record error
patch_rx_frame_type:	.equ	$+1		; SMC: immediate operand holding packet sequence number
		add	a, 0			; Add sequence number to inverted sequence number
 		cp	0FFh			; Sum must equal 0FFh (valid 1's complement)
		jp	nz, rx_dispatcher_call_5 ; Mismatch: record error
		call	init_crc_acc		; Reset CRC and checksum accumulators
		ld	ix, (file_pos_backup_lo) ; IX points to memory buffer write pointer
rx_dispatcher_call_3:
		ld	b, 0Ah			; Timeout = 10 ticks
		push	ix			; Preserve buffer pointer
		call	comm_rx_char_filtered	; Read incoming payload data byte
		pop	ix			; Restore buffer pointer
		ld	(rx_dispatcher_type), a	; Save byte
		jp	c, rx_dispatcher_call_5	; On timeout, record error
		ld	(ix), a			; Store payload byte into memory buffer
		inc	ix			; Advance buffer pointer
		call	checksum8_update	; Update 8-bit additive checksum
		call	crc16			; Update 16-bit CRC-CCITT
		ld	bc, (file_pos_backup_hi) ; Advance packet byte counter
		inc	bc
		ld	(file_pos_backup_hi), bc
		ld	de, (active_packet_len)	; Decrement remaining packet length
		dec	de
		ld	(active_packet_len), de
		ld	a, d			; Check if entire packet received
		or	e
		jr	nz, rx_dispatcher_call_3 ; Loop until all packet payload bytes read
		ld	(file_pos_backup_lo), ix ; Save updated buffer pointer
		ld	b, 0Ah			; Timeout = 10 ticks
		call	comm_rx_char_filtered	; Read first check byte (CRC high or Checksum)
		ld	(rx_dispatcher_type), a	; Save check byte
		jp	c, rx_dispatcher_call_5	; On timeout, record error
		ld	a, (rx_hdr_crc_format)	; Check CRC format (10h=CRC-16, 0=Checksum)
		cp	10h
		jr	nz, rx_dispatcher_step_2 ; If checksum mode, verify additive checksum
		ld	a, (rx_dispatcher_type)	; CRC mode: include first CRC byte
		call	crc16
		ld	b, 0Ah			; Timeout = 10 ticks
		call	comm_rx_char_filtered	; Read second CRC byte
		ld	(rx_dispatcher_type), a
		jp	c, rx_dispatcher_call_5	; On timeout, record error
		call	crc16			; Include second CRC byte
		ld	a, h			; Test computed CRC-16 (should be 0000h)
		or	l
		jp	nz, rx_dispatcher_call_5 ; Mismatch: record error
rx_dispatcher_step_1:
		xor	a			; Reset transfer error count to 0
		ld	(transfer_err_count), a
		ld	a, 0			; Reset EOF seen flag
		ld	(rx_eof_seen), a
		ld	a, (patch_rx_frame_type) ; Return verified packet sequence number in A
		ret				; Return

rx_dispatcher_step_2:
		ld	a, (rx_dispatcher_type)	; Load received 8-bit checksum
		ld	l, a
		ld	a, (patch_checksum8_val) ; Compare with computed 8-bit checksum
		sub	l
		jr	z, rx_dispatcher_step_1	; If match, packet verified!
		jp	rx_dispatcher_call_5	; Mismatch: record error

rx_dispatcher_call_4:
		ld	b, 0Ah			; EOT received: drain trailing line characters
		call	comm_rx_char_filtered
		ld	a, 0F6h			; 0F6h = EOT frame status code
		ret	c			; Return if drained
		jp	rx_dispatcher_call_5	; Trailing garbage: record error

rx_dispatcher_br_2:
		ld	a, 0FFh			; CAN received: check repeated CAN abort
		ld	hl, rx_flag_d09
		cp	(hl)
		jr	nz, rx_dispatcher_br_3	; If first CAN, wait for second
		ld	a, 0FFh			; Two consecutive CANs: abort transfer
		scf				; Set carry
		ret				; Return

rx_dispatcher_br_3:
		ld	(hl), a			; Mark first CAN received
		jp	rx_dispatcher_call_9	; Resync position and record error

;----------------------------------------------------------------------------

rx_dispatcher_call_5:
		ld	a, 0			; Clear CAN flag
		ld	(rx_flag_d09), a
rx_dispatcher_call_6:
		ld	b, 0Ah			; Drain serial line buffer
		call	comm_rx_char_filtered
		jr	nc, rx_dispatcher_call_6 ; Continue draining until line is quiet
		ld	a, (rx_eof_seen)	; Check EOF seen flag
		cp	0FFh
		jr	nz, rx_dispatcher_call_7
		ld	a, (rx_hdr_crc_format)	; Send polling handshake character
		cp	10h
		ld	a, 43h			; 'C' for CRC mode
		jr	z, rx_dispatcher_call_8
		ld	a, 15h			; NAK for checksum mode
		jr	rx_dispatcher_call_8

rx_dispatcher_call_7:
		ld	a, 28h			; Timeout = 40 ticks
		ld	(rx_retry_counter), a
		ld	a, 15h			; NAK (15h) character
rx_dispatcher_call_8:
		call	comm_tx_char_wait	; Send NAK / poll character to sender
rx_dispatcher_call_9:
		call	sync_file_pos		; Resync file position
		ld	hl, transfer_err_count	; Increment error count
		inc	(hl)
		call	print_error_count	; Display error count on console
		ld	a, (transfer_err_count)	; Check if error count reached 5
		cp	5
		jp	nz, rx_dispatcher_loop	; Retry receiving packet
		ld	a, 0FFh			; Exceeded retry limit: abort
		scf				; Set carry
		ret				; Return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : tx_hex_header
; Purpose  : Transmit Zmodem hex frame header (ZHEX) with type and 4 flag bytes
; Inputs   : A = frame type
; Outputs  : Hex header frame transmitted
; Modifies : All registers
;============================================================================
tx_hex_header:
		ld	(tx_frame_type), a	; Save frame type byte
		ld	hl, str_zhex_prefix	; HL points to ZHEX prefix (**\x18B)
		call	tx_raw_string		; Transmit framing sequence
		call	init_crc_acc		; Reset CRC-16 accumulator to 0000h
		ld	a, (tx_frame_type)	; Load frame type
		call	crc16			; Update CRC-16 with frame type byte
		call	tx_hex_byte		; Transmit frame type as 2 hex digits
		ld	hl, rx_char_saved_step_5 ; Pointer to 4 header flag bytes
		ld	b, 4			; Loop counter = 4 bytes
tx_hex_byte_loop:
		push	bc
		ld	a, (hl)			; Load next flag byte
		inc	hl
		push	hl
		call	crc16			; Update CRC-16 accumulator
		call	tx_hex_byte		; Transmit flag byte as 2 hex digits
		pop	hl
		pop	bc
		djnz	tx_hex_byte_loop	; Repeat for all 4 flag bytes
		ld	a, (crc_seed+1)		; Load CRC-16 high byte
		call	tx_hex_byte		; Transmit CRC-16 high byte
		ld	a, (crc_seed)		; Load CRC-16 low byte
		call	tx_hex_byte		; Transmit CRC-16 low byte
		ld	a, 0Dh			; Transmit Carriage Return (CR)
		call	comm_tx_char_wait
		ld	a, 0Ah			; Transmit Line Feed (LF)
		call	comm_tx_char_wait
		ld	a, (tx_frame_type)
		cp	ZFIN			; Check if frame was ZFIN (type 8)
		ret	z			; If session finish, do not send XON
		ld	a, 11h			; Transmit XON (11h) to release remote transmitter
		jp	comm_tx_char_wait

;----------------------------------------------------------------------------

str_zhex_prefix:	.db	ZPAD		; Frame synchronization character ('*')
		.db	ZPAD		; Frame synchronization character ('*')
		.db	ZDLE		; Data Link Escape (0x18)
		.db	ZHEX		; Hexadecimal header indicator ('B')
		.db	0		; NUL string terminator

str_hex_chars:	.text	"0123456789abcdef"

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : tx_hex_byte
; Purpose  : Transmit binary byte as two ASCII hex characters to AUX port
; Inputs   : A = binary byte
; Outputs  : 2 hex ASCII characters transmitted
; Modifies : A, BC, HL
;============================================================================
tx_hex_byte:
		push	af			; Preserve original byte
		ld	hl, str_hex_chars	; HL points to ASCII hex digits table
		ld	b, 0			; BC = high nibble offset
		rra				; Shift high nibble into low 4 bits
		rra
		rra
		rra
		and	0Fh			; Mask 4 bits
		ld	c, a
		add	hl, bc			; Index into hex digits string
		ld	a, (hl)			; Load hex digit character
		call	comm_tx_char_wait	; Transmit high nibble character
		pop	af			; Restore original byte
		ld	hl, str_hex_chars	; HL points to ASCII hex digits table
		ld	b, 0			; BC = low nibble offset
		and	0Fh			; Mask low 4 bits
		ld	c, a
		add	hl, bc			; Index into hex digits string
		ld	a, (hl)			; Load hex digit character
		jp	comm_tx_char_wait	; Transmit low nibble character and return

;----------------------------------------------------------------------------

tx_hex_byte_loop_1:
		ld	(patch_tx_char_byte), a	; Save character into SMC operand
      		ld	bc, +(hex_byte_jump_vector-hex_byte_char_table) ; Table entry count
      		ld	hl, hex_byte_char_table	; HL points to escape character lookup table
      		cpir				; Search character in escape table
      		jp	z, dispatch_table_jump	; If match found, jump to handler
		and	60h			; Check if control character
      		jr	nz, tx_hex_byte_call_2	; If printable character, transmit directly
      		ld	a, (esc_ctrl_chars_flag) ; Check if escaping control characters active
      		or	a
      		jr	z, tx_hex_byte_call_2	; If escaping not active, transmit directly
tx_hex_byte_call_1:
		ld	hl, patch_tx_char_byte	; Set bit 6 to convert control char to printable
      		set	6, (hl)
      		ld	a, 18h			; Send ZDLE escape character (18h) prefix first
      		call	comm_tx_char_wait
patch_tx_char_byte:	.equ	$+1		; SMC: immediate byte operand holding escaped character
tx_hex_byte_call_2:
		ld	a, 0			; Load escaped or raw character
comm_tx_char_wait:
		ld	(patch_tx_wait_flag), a	; Save character to transmit
comm_tx_char_w_call_1:
		call	rx_buffer_poll		; Poll receive buffer while waiting for UART ready
		call	aux_tx_ready		; Check if AUX port output is ready for next byte
		jr	z, comm_tx_char_w_call_1 ; Loop until AUX transmitter ready
patch_tx_wait_flag:	.equ	$+1		; SMC: immediate byte operand holding character to transmit
		ld	a, 0			; Load character
      		jp	aux_tx_char		; Transmit character via BDOS AUX write and return

comm_tx_char_w_br_1:
		ld	a, (patch_tx_wait_flag)	; Load character
		and	7Fh			; Mask 7 bits
		cp	40h			; Check range
		jr	nz, tx_hex_byte_call_2	; Transmit directly
		jr	tx_hex_byte_call_1	; Escape character

hex_byte_char_table:	.db	18h
		.db	0Dh
		.db	8Dh
		.db	10h
		.db	90h
		.db	11h
		.db	91h
		.db	13h
		.db	93h

hex_byte_jump_vector:	.dw	tx_hex_byte_call_1
		.dw	tx_hex_byte_call_1
		.dw	tx_hex_byte_call_1
		.dw	tx_hex_byte_call_1
		.dw	tx_hex_byte_call_1
		.dw	tx_hex_byte_call_1
		.dw	comm_tx_char_w_br_1
		.dw	comm_tx_char_w_br_1
		.dw	tx_hex_byte_call_1

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

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

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; CP/M File Control Block Initialization Library (fcb_init.inc)
;============================================================================
#include "fcb_init.inc"


;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; ZCPR3 / Z-System Environment Descriptor Library (z3env.inc)
;============================================================================
#include "z3env.inc"


;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : get_cur_drive_user
; Purpose  : Get current CP/M drive (BDOS 25) and current user area (BDOS 32)
; Inputs   : None
; Outputs  : B = current drive (0=A..), C = current user (0..15)
; Modifies : A, B, C, DE, HL
;============================================================================
get_cur_drive_user:
		push	af			; Preserve AF
		push	de			; Preserve DE
		push	hl			; Preserve HL
		ld	c, DRV_GET		; BDOS Function 25: Get current disk drive
		call	bdos_s2
		push	af			; Save drive number
		ld	e, 0FFh			; 0FFh = query current user number
		ld	c, F_USERNUM		; BDOS Function 32: Get/set user number
		call	bdos_s2
		ld	c, a			; C = current user number (0..15)
		pop	af			; Restore drive number
		ld	b, a			; B = current drive number (0=A..)
		pop	hl			; Restore HL
		pop	de			; Restore DE
		pop	af			; Restore AF
		ret				; Return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : bdos_search_first
; Purpose  : Search for first matching directory entry (BDOS 17 F_SFIRST)
; Inputs   : DE = FCB template pointer
; Outputs  : A = directory index (0..3) or 0FFh if not found
; Modifies : A
;============================================================================
bdos_search_first:
		ld	a, F_SFIRST		; BDOS Function 17: Search for first
		call	bdos_cs3
		inc	a			; 0FFh -> 00h (Z flag set if not found)
		ret				; Return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; CP/M BDOS Console and Dispatcher Library (bdos_con.inc)
;============================================================================
#include "bdos_con.inc"


;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; CP/M File Control Block Formatting Library (fcb_format.inc)
;============================================================================
#include "fcb_format.inc"


;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : byte_to_dec_ascii
; Purpose  : Convert 8-bit unsigned integer in A to 2-3 digit decimal ASCII string
; Inputs   : A = integer, DE = output string buffer
; Outputs  : ASCII decimal string written to DE
; Modifies : All registers
;============================================================================
byte_to_dec_ascii:
		push	bc			; Preserve BC
		ld	b, 0			; Unsigned mode flag (B = 0)
		jp	byte_to_dec_calc	; Jump to division calculation
;============================================================================
; Function : byte_to_signed_dec
; Purpose  : Convert 8-bit signed integer in A to signed decimal ASCII string
; Inputs   : A = signed integer, DE = output buffer
; Outputs  : Signed decimal string written to DE
; Modifies : All registers
;============================================================================
byte_to_signed_dec:
		push	bc			; Preserve BC
		ld	b, 0FFh			; Signed mode flag (B = 0FFh)
byte_to_dec_calc:
		push	hl			; Preserve HL
		push	af			; Preserve AF
		ld	h, 64h			; Divisor = 100 (64h)
		call	div_mod_8		; Divide by 100, emit hundreds digit
		ld	h, 0Ah			; Divisor = 10 (0Ah)
		call	div_mod_8		; Divide remainder by 10, emit tens digit
		call	store_ascii_char	; Emit remaining units digit
		pop	af			; Restore AF
		pop	hl			; Restore HL
		pop	bc			; Restore BC
		ret				; Return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : div_mod_8
; Purpose  : 8-bit unsigned integer division and remainder calculation
; Inputs   : A = dividend, H = divisor
; Outputs  : L = quotient, A = remainder
; Modifies : A, L
;============================================================================
div_mod_8:
		ld	l, 0FFh			; Initialize quotient accumulator to -1
div_mod_loop:
		sub	h			; Subtract divisor from dividend
		inc	l			; Increment quotient
		jr	nc, div_mod_loop	; Repeat until borrow occurs
		add	a, h			; Restore dividend remainder
		ld	h, a			; H = remainder
		ld	a, l			; A = quotient
		or	a			; Is quotient non-zero?
		jr	nz, store_ascii_char	; If non-zero, store ASCII digit
		or	b			; Check leading zero suppression flag
		ld	a, h			; A = remainder
		ret	m			; If signed suppression, return
		ld	a, 20h			; Space padding (' ')
		jr	z, store_ascii_char_adv
		xor	a			; 0
;============================================================================
; Function : store_ascii_char
; Purpose  : Store ASCII character in output text buffer and advance pointer
; Inputs   : A = digit value (0..9), DE = output buffer
; Outputs  : Character stored at (DE), DE incremented
; Modifies : A, B, DE
;============================================================================
store_ascii_char:
		add	a, 30h			; Convert binary digit to ASCII ('0'..'9')
		ld	b, a			; Save digit character
store_ascii_char_adv:
		ld	(de), a			; Store ASCII character into output buffer
		inc	de			; Advance output pointer
		ld	a, h			; A = remainder for next division stage
		ret				; Return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : calc_strlen
; Purpose  : Calculate string length of null-terminated ASCII string at HL
; Inputs   : HL = string pointer
; Outputs  : BC = string length in bytes
; Modifies : A, BC, HL
;============================================================================
calc_strlen:
		push	af			; Preserve AF
		push	hl			; Preserve HL
calc_strlen_loop:
		ld	a, (hl)			; Load character from string
		or	a			; Null terminator?
		jr	z, calc_strlen_lo_done_1 ; If null, end of string reached
		call	to_upper		; Convert character to uppercase in place
		ld	(hl), a			; Store uppercase character back
		inc	hl			; Advance string pointer
		jr	calc_strlen_loop	; Repeat for all characters
calc_strlen_lo_done_1:
		pop	hl			; Restore HL
		pop	af			; Restore AF
		ret				; Return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : tokenize_cmdline
; Purpose  : Tokenize CP/M default command line tail buffer at address 0080h
; Inputs   : DE = command line buffer pointer
; Outputs  : Tokens parsed into argument list
; Modifies : All registers
;============================================================================
tokenize_cmdline:
		push	bc			; Preserve BC
		push	de			; Preserve DE
		push	hl			; Preserve HL
		ld	c, a			; C = delimiter mask mode
		ex	de, hl			; HL = token list, DE = string buffer
		ld	b, (hl)			; B = maximum token slots available
		push	hl			; Preserve token list pointer
		inc	hl			; Advance past slot count to token array
		inc	hl
tokenize_cmdli_call_1:
		call	skip_spaces		; Skip leading spaces in string
		or	a			; End of string (null)?
		jr	z, tokenize_cmdli_step_1 ; If end of string, finish tokenizing
		ld	(hl), e			; Store token string pointer (low byte)
		inc	hl
		ld	(hl), d			; Store token string pointer (high byte)
		inc	hl
		dec	b			; Decrement available token slot count
		jr	z, tokenize_cmdli_call_3 ; If slots exhausted, finish
		call	check_delimiter		; Scan to end of current argument token
		or	a			; End of string?
		jr	z, tokenize_cmdli_step_1
		ld	a, c			; Check delimiter termination mode
		or	a
		jr	z, tokenize_cmdli_call_2
		xor	a			; Null-terminate current token string
		ld	(de), a
		inc	de			; Advance past null terminator
tokenize_cmdli_call_2:
		ld	a, b			; Check remaining token slots
		or	a
		jr	nz, tokenize_cmdli_call_1 ; Parse next argument token
tokenize_cmdli_call_3:
		call	check_delimiter		; Skip to end of token
		call	skip_spaces		; Skip trailing spaces
		or	a
		jr	z, tokenize_cmdli_step_1
		or	0FFh			; More tokens existed than could fit
tokenize_cmdli_step_1:
		pop	hl			; Restore token list base pointer
		push	af			; Preserve status flags
		ld	a, (hl)			; Total slots
		sub	b			; Minus remaining slots = count of parsed tokens
		inc	hl
		ld	(hl), a			; Store parsed token count byte
		pop	af			; Restore status flags
		pop	hl			; Restore HL
		pop	de			; Restore DE
		pop	bc			; Restore BC
		ret				; Return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : skip_spaces
; Purpose  : Skip whitespace characters in string buffer
; Inputs   : DE = string buffer pointer
; Outputs  : DE points to first non-space character
; Modifies : A, DE
;============================================================================
skip_spaces:
		ld	a, (de)			; Load character
		and	7Fh			; Mask 7-bit ASCII
		inc	de			; Advance pointer
		cp	20h			; Space character?
		jr	z, skip_spaces		; Skip spaces
		cp	9			; Tab character?
		jr	z, skip_spaces		; Skip tabs
		dec	de			; Point back to first non-whitespace character
		ret				; Return with character in A

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : check_delimiter
; Purpose  : Check if character is a whitespace or null delimiter
; Inputs   : DE = string buffer pointer
; Outputs  : Z if space/tab/null, NZ otherwise
; Modifies : A
;============================================================================
check_delimiter:
		ld	a, (de)			; Load character
		and	7Fh			; Mask 7 bits
		ret	z			; Return Z if null terminator
		cp	20h			; Space?
		ret	z			; Return Z if space
		cp	9			; Tab?
		ret	z			; Return Z if tab
		inc	de			; Advance pointer to next character
		jr	check_delimiter		; Continue scanning until delimiter found

;----------------------------------------------------------------------------
;		Fill b locations starting at hl with value a

fill_bhla:
		push	hl			; Preserve HL
		call	fill_1			; Fill B bytes at HL with value in A
		pop	hl			; Restore HL
		ret				; Return

;----------------------------------------------------------------------------
;		Fill b locations starting at hl with value a

fill_1:
		push	bc			; Preserve BC
fill_1_loop_1:
		ld	(hl), a			; Store byte into memory
		inc	hl			; Advance pointer
		djnz	fill_1_loop_1		; Loop for all B bytes
		pop	bc			; Restore BC
		ret				; Return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : to_upper
; Purpose  : Convert lowercase ASCII character in A to uppercase
; Inputs   : A = character
; Outputs  : A = uppercase character
; Modifies : A, F
;============================================================================
to_upper:
		and	7Fh			; Mask 7-bit ASCII
		cp	61h			; Less than 'a'?
		ret	c			; If < 'a', already uppercase or symbol
		cp	7Bh			; Greater than 'z'?
		ret	nc			; If > 'z', symbol
		and	5Fh			; Convert lowercase ('a'..'z') to uppercase ('A'..'Z')
		ret				; Return

;----------------------------------------------------------------------------
free_mem_base:	.dw	heap_base
saved_user_num:	.db	0
saved_drive_num:	.db	0
transfer_state_vars:	.db	0
file_fcb:	.db	0
		.fill	$20,0		
file_fcb_step_1:	.db	0
		.db	0
		.db	0
fcb_record_count_ext:	.db	0
		.fill	$1800-$,0
		.ds	8
nstack:
rbuf_bfree:	.ds	2
		.ds	rbuf_size+4
cpm_partial_record_bytes:	.ds	1
cpm_last_record_index:	.ds	1
cpm_record_count:	.ds	1
rbuf_bfree_step_1:	.ds	80h
num_to_ascii_buf:	.ds	1
		.ds	3
rbuf_bfree_step_2:	.ds	4
rbuf_bfree_step_3:	.ds	4
rbuf_bfree_step_4:	.ds	400h
esc_ctrl_chars_flag:	.ds	1
rx_hdr_crc_format:	.ds	1
rbuf_bfree_step_5:	.ds	1
		.ds	1
zmodem_flag_ca1:	.ds	1
remote_proto_type:	.ds	1
flag_ymodem_active:	.ds	1
flag_zmodem_active:	.ds	1
transfer_abort_flag:	.ds	1
rx_char_saved:	.ds	1
rx_char_saved_step_1:	.ds	4
rx_char_saved_step_2:	.ds	4
rx_char_saved_step_3:	.ds	21h
rx_char_saved_step_4:	.ds	1
file_mgmt_option:	.ds	1
rx_filename_ptr:	.ds	2
rx_file_info_ptr:	.ds	1
		.ds	0Bh
rx_char_saved_step_5:	.ds	4
rx_char_saved_step_6:	.ds	4
tx_frame_type:	.ds	1
file_offset_lo:	.ds	2
file_offset_hi:	.ds	2
file_pos_backup_lo:	.ds	2
file_pos_backup_hi:	.ds	2
		.ds	2
file_pos_backu_step_1:	.ds	2
pending_write_bytes:	.ds	2
		.ds	2
pending_write_step_1:	.ds	4
zdle_escape_flag:	.ds	1
rx_frame_len:	.ds	2
rx_retry_limit:	.ds	1
rx_frame_type:	.ds	1
rx_eof_seen:	.ds	1
rx_retry_counter:	.ds	1
transfer_err_count:	.ds	1
active_packet_len:	.ds	2
zmodem_flag_d07:	.ds	1
rx_dispatcher_type:	.ds	1
rx_flag_d09:	.ds	1
fcb_attr_mode:	.ds	1
fcb_parse_state:	.ds	1
file_batch_index:	.ds	1
fcb_drive_specified:	.ds	1
fcb_active_user:	.ds	1
z3env_ptr:	.ds	2
heap_base	.equ	$
		.end	; start

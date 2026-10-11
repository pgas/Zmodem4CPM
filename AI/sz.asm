; sz (send Zmodem) is a disassembly of CP/M 3 binaries by Wilfried Schmitten released in 1992.
; this file is an attempt to reconstruct the Z80 assembler source code which has been lost
; credit to Wilfried Schmitten for writing this program initially

;



; File Name			  C:\SZ.COM
; Format			  COM File
; Base Address:	0000h Range: 0100h - 1F80h Loaded length: 1E80h

; Processor:	    z80
; Target assembler: Table Driven Assembler (TASM) by Speech Technology Inc.

#include "cpm3.inc"
#include "zmodem.inc"

; Program-specific BSS buffer equates
; Program-specific BSS buffer equates
saved_user_num	.equ	2000h
saved_drive_num	.equ	2001h
active_user_num	.equ	2002h
file_fcb	.equ	2003h
nstack		.equ	2067h
tx_file_user	.equ	226Dh		; Transmit file user area byte
tx_file_fcb	.equ	226Eh		; Transmit file CP/M FCB (36 bytes)
crc32_acc_bytes	.equ	229Bh		; 4-byte CRC-32 accumulator buffer
crc32_acc	.equ	crc32_acc_bytes	; Standard alias for CRC-32 accumulator buffer
crc32_table	.equ	229Fh		; 1024-byte dynamic CRC-32 lookup table
tx_progress_count	.equ	26A4h	; 32-bit transfer progress byte count (for display)
remote_can_flags	.equ	26A9h		; Receiver capability flags (CANFDX, CANFC32, etc.)
tx_hdr_flags	.equ	26AAh		; Outgoing frame header flag/position array (4 bytes)
file_pos_curr	.equ	26B7h		; 32-bit current file position
esc_ctrl_chars_flag	.equ	26D5h	; Non-zero if receiver requested escaping control chars (ESCCTL)
tx_buf_mask	.equ	26DAh		; 16-bit circular buffer wrap mask
tx_window_offset	.equ	26DCh		; 16-bit offset into transmit window buffer
tx_buf_base_addr	.equ	26EFh		; 16-bit base address of transmit data buffer
subpacket_framing_char	.equ	2706h	; Frame delimiter character (ZCRCE, ZCRCG, ZCRCQ, ZCRCW)
tx_frame_type	.equ	2707h		; Zmodem frame type byte (ZRINIT, ZFILE, ZDATA, ZFIN, etc.)
rx_hdr_crc_acc	.equ	2708h		; 16-bit accumulated CRC for incoming header
rx_hdr_type	.equ	270Ah		; Incoming header frame type
rx_hdr_encoding	.equ	270Bh		; Incoming header format encoding (ZBIN, ZHEX, etc.)
fcb_attr_mode	.equ	270Ch		; CP/M FCB attribute mode flag
fcb_parse_state	.equ	270Dh		; Parsing state delimiter character
file_batch_index	.equ	270Eh		; Batch file index / error counter
fcb_drive_specified	.equ	270Fh		; Non-zero if user specified explicit drive
fcb_active_user	.equ	2710h		; User area for parsed FCB
z3env_ptr	.equ	2711h		; Pointer to Z-System (ZCPR3) environment descriptor
fcb_dest_ptr	.equ	2711h		; Legacy alias for 2711h
dir_extent_merge_flag	.equ	2738h	; Non-zero if merging extent records
dir_table_base_saved	.equ	2739h	; Saved base of directory table
dir_match_count	.equ	273Bh		; Number of directory entries matched
dir_marked_count	.equ	273Dh		; Number of entries marked with bit 7
dir_curr_buf_ptr	.equ	273Fh		; Current pointer into directory buffer
dir_total_count		.equ	2741h		; Total entries parameter for sort
dir_entry_len		.equ	2743h		; Length of directory entry (16 bytes = 10h)
dir_cmp_callback	.equ	2745h		; Directory sort comparison callback
dir_sort_vector_ptr	.equ	2747h		; Directory sort pointer table base
dir_dpb_info		.equ	274Bh		; DPB parameter buffer
dir_dpb_max_alloc	.equ	274Eh		; DPB max allocation blocks + 1
dir_dpb_dir_max		.equ	2750h		; DPB max directory entries + 1
dir_user_filter		.equ	2752h		; User number filter / scan user area
sort_desc_caller_ptr	.equ	2753h	; Saved caller descriptor pointer
sort_desc_base		.equ	2755h		; 12-byte sort descriptor block
sort_table_base		.equ	2755h		; Array base address
sort_item_count		.equ	2757h		; Number of items to sort
sort_item_size		.equ	2759h		; Size of each item in bytes
sort_compare_func	.equ	275Bh		; Pointer to comparison function
sort_ptr_table		.equ	275Dh		; Pointer to indirect index array
sort_indirect_flag	.equ	275Fh		; 1 = sort pointers, 0 = sort items directly
sort_flags2		.equ	2760h		; Secondary sort flag
sort_gap		.equ	2761h		; Current Shell sort gap
sort_index		.equ	2763h		; Current item index during sort
cpm_ch1_control_block	.equ	2765h	; Channel 1 file buffer control block (168 bytes)
cpm_ch2_control_block	.equ	280Dh	; Channel 2 file buffer control block (168 bytes)
cpm_active_buf_ptr	.equ	28B5h	; Pointer to active channel buffer control block
cpm_io_last_byte	.equ	28B7h	; Last byte read/written during buffered I/O
cpm_io_scratch_fcb	.equ	28B8h	; Scratch FCB buffer for file size calculations
packet_seq_num	.equ	26E1h		; 8-bit packet sequence number (0-255)
rx_err_status	.equ	26E2h		; Last serial receive error status / break byte
rx_response_char	.equ	26E0h		; Last response byte received from remote receiver
retry_err_counter	.equ	269Fh		; Packet retry / error counter
tx_can_flag		.equ	26AEh		; Cancel / abort flag
zrinit_retry_counter	.equ	26F8h	; Retry counter for ZRINIT reception
rx_hdr_flags	.equ	26A0h		; 4-byte buffer for incoming frame header flags
remote_zf0_flags	.equ	26D4h	; Saved ZF0 capabilities byte from remote ZRINIT
remote_rx_buf_size	.equ	26CBh	; Remote receiver max window / buffer size (0=unlimited)
rx_hdr_pos		.equ	26B3h		; 32-bit received header position / flags
tx_pos_base		.equ	26AFh		; 32-bit transmit base position
file_pos_sent		.equ	26BBh		; 32-bit position of data transmitted
file_pos_acked		.equ	26BFh		; 32-bit position acknowledged by receiver
file_pos_buf		.equ	26C3h		; 32-bit position of data loaded in buffer
temp_pos_32		.equ	26C7h		; 32-bit temporary arithmetic buffer
rx_window_remaining	.equ	26CDh		; 16-bit remaining receiver window space
consecutive_errors	.equ	26D3h		; Consecutive error counter at same position
tx_eof_flag		.equ	26D6h		; Transmit EOF reached flag (0FFh = EOF)
file_read_eof_flag	.equ	26D7h		; File reader EOF reached flag (0FFh = EOF)
curr_framing_char	.equ	26D8h		; Current data subpacket delimiter (ZCRCE/ZCRCG/ZCRCW)
file_pos_align_base	.equ	26F3h		; 16-bit circular buffer alignment base
tx_window_packet_count	.equ	26F9h		; Count of packets sent in current window
rpos_target_pos		.equ	26FAh		; 32-bit target position from ZRPOS frame
tx_window_align_pos	.equ	26FEh		; 32-bit window aligned position
tx_curr_chunk_size	.equ	2702h		; 16-bit size of current data subpacket
file_read_byte_buffered	.equ	1BF9h		; Buffered file read routine
cmd_window_param	.equ	0853h	; Configured window size parameter
tx_subpacket_size	.equ	26CFh	; Active data subpacket length (128 or 1024)
checksum8_val	.equ	0789h		; 8-bit checksum value for Xmodem packets
;----------------------------------------------------------------------------

		.org 100h


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

start:
		jp	start_init		; Jump past ZCPR3 environment descriptor block

;----------------------------------------------------------------------------
; ZCPR3 / Z-System Environment Descriptor Identification Block:
;   Enables automated environment discovery if executed under Z-System / ZCPR3.
;   Identified by signature 'Z3ENV' followed by version 1 and 16-bit descriptor pointer.
;----------------------------------------------------------------------------
		.db  5Ah ; Z
		.db  33h ; 3
		.db  45h ; E
		.db  4Eh ; N
		.db  56h ; V
		.db    1 ; Version 1
z3env_desc_ptr:	.dw 0			; External pointer to Z3ENV descriptor in memory

;============================================================================
; Routine : start_init
; Purpose : Main entry point after initial vector.
;           1. Set up private stack.
;           2. Interrogate Z-System environment if present.
;           3. Verify CP/M 3.0+ host OS via BDOS version query.
;           4. Display welcome banner to console.
;           5. Save initial user area and drive number.
;           6. Parse command-line switches and target filespec.
;           7. Perform wildcard directory scan to locate matched files.
;           8. Calculate memory buffer thresholds based on BDOS top of RAM.
;           9. Hook CP/M 3 error interception vectors.
;          10. Launch protocol sender engine.
;============================================================================
start_init:
		ld	sp, nstack		; Initialize private stack top in BSS
		ld	hl, (z3env_desc_ptr)	; Load pointer to ZCPR3 environment descriptor
		call	init_z3env_descriptor	; Initialize Z-System environment integration

		ld	c, S_BDOSVER		; BDOS Function 12: Return CP/M version
		call	bdos			; Version returned in A (e.g. 30h = CP/M 3.0)
		cp	30h			; Verify running on CP/M 3.0 or higher
		jp	c, err_version_exit	; Abort with error message if earlier version

		ld	de, str_welc		; DE points to welcome banner string
		ld	c, C_WRITESTR		; BDOS Function 9: Write string to console
		call	bdos

		call	get_init_drive_user	; Record initial drive and user; patch exit code
		ld	a, (80h)		; Check length of CP/M command tail buffer
		or	a			; Are there any command-line arguments?
		jp	z, err_usage_exit	; If zero length, print usage help and exit

		ld	hl, (free_mem_base)	; Load pointer to start of free heap buffer
		ld	(hl), 2			; Initialize token parse parameter
		ld	de, 82h			; DE points to command tail text string (skip leading space)
		ex	de, hl			; Swap: HL = command tail, DE = free memory buffer
		ld	a, 0FFh			; Parse all tokens
		call	tokenize_cmdline	; Split command line into whitespace-separated arguments

		ld	hl, (free_mem_base)	; Check parsed tokens list
		inc	hl
		ld	a, (hl)			; A = number of parsed tokens
		or	a			; Were any tokens found?
		jp	z, err_usage_exit	; If no tokens, print usage help and exit

		inc	hl			; Point to first argument string pointer
		ld	e, (hl)
		inc	hl
		ld	d, (hl)			; DE = pointer to first argument string
		inc	hl
		ld	a, (de)
		cp	2Dh			; Does first argument begin with dash '-'?
		jr	nz, start_check_filename ; If not dash, argument is destination filespec

		call	parse_options_cmdline	; Parse option switches (?PABCXYZ)
		ld	e, (hl)			; Check for second argument (filename)
		inc	hl
		ld	d, (hl)			; DE = pointer to filename argument string

start_check_filename:
		ld	a, d
		or	e			; Was a target filespec supplied?
		jr	z, start_print_banner	; If not, proceed to banner display

		ld	hl, file_fcb		; HL = target FCB address in BSS
		ex	de, hl			; DE = FCB, HL = filespec string
		call	parse_cpm_filespec	; Parse CP/M filespec into 36-byte FCB
		ld	hl, file_fcb		; Check FCB drive field
		xor	a
		or	(hl)			; Did filespec specify an explicit drive?
		jr	nz, start_have_drive	; If non-zero, explicit drive already set
		ld	a, (saved_drive_num)		; Otherwise load saved default drive number
		ld	(hl), a			; Store into FCB drive field

start_have_drive:
; SMC WRITER: Patches immediate operand of ld a, imm at fetch_next_matched_file (default_drive_num)
		ld	(default_drive_num), a	; Save active default drive number
		ld	bc, 0Dh			; Offset 13: point to user number field in FCB
		add	hl, bc
		dec	de
		ldi				; Copy parsed user number into FCB extension
		ld	de, file_fcb		; DE points to target FCB
		call	set_drive_user		; Select active drive and user area
		or	a			; Check if drive and user selection succeeded
		jp	nz, start_exit_cleanup	; Exit if invalid drive or user

		ld	hl, (free_mem_base)	; HL = destination buffer for matching filenames
		ld	a, (active_user_num)		; A = active user number
		or	0C0h			; Set search attribute mask for directory scan
		ld	de, file_fcb		; DE = FCB search mask
		call	dir_search_wildcard	; Scan directory and collect all matching entries
; SMC WRITER: Patches immediate operand of ld hl, imm at fetch_next_matched_file (files_matched_list)
		ld	(files_matched_list), hl ; Save head pointer of matching files list
		ld	a, c
		ld	(26F7h), a		; Store count of matching files found

start_print_banner:
		push	af
		push	bc
		push	de
		push	hl
		ld	de, str_files_req	; Buffer for file count message
		call	byte_to_dec_ascii	; Format count of files into decimal ASCII
		ld	de, str_files_req	; Print 'N File(s) requested'
		ld	c, C_WRITESTR		; BDOS Function 9: Write string
		call	bdos
		pop	hl
		pop	de
		pop	bc
		pop	af
		or	a			; Were any files matched?
		jp	z, start_exit_cleanup	; If zero files found, abort transfer

		ex	de, hl			; Calculate memory requirements for transfer buffers
		ld	h, b
		ld	l, c
		add	hl, hl			; Scale file count to directory entry record size
		add	hl, hl
		add	hl, hl
		add	hl, hl
		ex	de, hl
		add	hl, de			; HL = top of directory structures in RAM
		ld	(26EFh), hl		; Save directory entries end pointer
		ld	de, (6)			; DE = BDOS base address (top of TPA)
		ex	de, hl
		or	a
		sbc	hl, de			; Calculate total free bytes available in TPA
		ld	(26F3h), hl		; Save free TPA byte count
		ld	hl, 0
		ld	(26F1h), hl		; Clear transfer statistics accumulators
		ld	(26F5h), hl
		ld	de, str_sxfr		; 'start your local X/Y/ZModem receive program'
		ld	c, C_WRITESTR		; BDOS Function 9: Write string
		call	bdos

		call	cpm3_sysvar_hook	; Intercept CP/M 3 SCB error and abort vectors
		call	calc_buffer_mask	; Compute transmission buffer sizing and run sender engine
		call	cpm3_sysvar_unhook	; Restore original CP/M 3 SCB vectors

;============================================================================
; Routine : start_exit_cleanup
; Purpose : Clean session exit:
;           1. Restore caller's original disk drive and user area.
;           2. Return control cleanly to CP/M Console Command Processor (CCP).
; Notes   : Uses self-modifying code (SMC) via patch_exit_drive_user.
;============================================================================
; SMC TARGET: Patched by ld (patch_exit_drive_user), hl at get_init_drive_user (line 315)
patch_exit_drive_user:	.equ	$+1		; Points to the immediate 16-bit operand below
start_exit_cleanup:
		ld	bc, 0			; BC dynamically patched with saved user and drive
		ld	(active_user_num), bc		; Update active drive and user area
		ld	de, file_fcb		; DE points to FCB
		call	set_drive_user		; Select original drive and user area
		jp	cpm			; Warm Boot (0000h): Return control to CP/M
; End of function start


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : get_init_drive_user
; Purpose  : Read default drive and user area from CP/M IOBYTE (0004h)
; Inputs   : None
; Outputs  : byte_0_2001=user, byte_0_2002=drive
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
; SMC WRITER: Patches immediate operand of ld bc, imm at start_exit_cleanup (patch_exit_drive_user)
		ld	(patch_exit_drive_user), hl ; Patch SMC exit restore operand (ld bc, ...)
		ret				; Return
; End of function get_init_drive_user


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : set_drive_user
; Purpose  : Set current CP/M drive (BDOS 14) and user number (BDOS 32)
; Inputs   : (DE) contains packed user/drive word
; Outputs  : Drive and user selected in CP/M BDOS
; Modifies : A, C, DE
;============================================================================
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

;----------------------------------------------------------------------------

err_version_exit:
		ld	de, str_cpm3		; DE points to error message: 'sorry, CP/M 3 Tool\r\n$'
		ld	c, C_WRITESTR		; BDOS Function 9: Write string to console
		call	bdos			; Display version error string

err_usage_exit:
		ld	de, str_info		; DE points to command-line usage summary string
		ld	c, C_WRITESTR		; BDOS Function 9: Write string to console
		call	bdos			; Display usage help string
		jp	0			; Warm Boot (0000h): Exit to CP/M CCP
;----------------------------------------------------------------------------
str_welc:	.text	"SZ for CP/M 3   V 1.11\r\n"
		.text	"(C) 92 wshbg\r\n\n$"
str_cpm3:	.text	"sorry, CP/M 3 Tool\r\n$"
str_info:	.text	"usage: sz [-?pabcxyz] [du:]fn\r\n\n"
		.text	" options:\r\n"
		.text	"            ?     this help\r\n"
		.text	"            p     protect File at destination\r\n"
		.text	"            a     append\r\n"
		.text	"            b     receive binary\r\n"
		.text	"            c     convert to local linefeed\r\n"
		.text	"            x,y,z Protokoll\r\n$"
str_files_req:	.text	"    File(s) requested\r\n\n$"
str_sxfr:	.text	"start your local X/Y/ZModem receive program\r\n$"
;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : parse_options_cmdline
; Purpose  : Parse command line option switches (?PBCXYZR)
; Inputs   : DE = command line arguments pointer
; Outputs  : Option flags updated in memory
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
		ld	bc, 8			; BC = number of options to scan (?PABCXYZ)
		cpir				; Search for match; decrements BC on each test
		call	z, dispatch_table_jump	; If match found (Z set), execute corresponding handler
		jr	parse_clo_loop		; Continue scanning next character

parse_clo_done:
		pop	de			; Restore argument string pointer DE
		pop	hl			; Restore token list pointer HL
		ret				; Return to caller
; End of function parse_options_cmdline

;----------------------------------------------------------------------------
; Command Line Option Switch Dispatch Table
;   cmd_switch_chars: Array of valid single-letter switch characters (?PABCXYZ).
;   cmd_switch_count: Count of characters in search table.
;   Followed by corresponding 16-bit subroutine jump vectors (.dw target).
;   When CPIR matches a character, dispatch_table_jump indexes into the
;   jump vector array using remaining count in BC to execute the option handler.
;----------------------------------------------------------------------------
cmd_switch_chars:
		.text	"?PABCXYZ"
cmd_switch_count:	.equ	$-cmd_switch_chars

		.dw	clo_a		; A -> append mode
		.dw	clo_b		; B -> receive binary mode
		.dw	clo_c		; C -> convert to local linefeed
		.dw	clo_p		; P -> protect file at destination
		.dw	clo_z		; Z -> force Zmodem protocol
		.dw	clo_y		; Y -> force Ymodem protocol
		.dw	clo_x		; X -> force Xmodem protocol
		.dw	err_usage_exit	; ? -> display usage help

clo_c:
		ld	a, 1			; Option 'c': text conversion mode (CRLF translation)
		jr	clo_set_opt		; Store option
clo_b:
		ld	a, 3			; Option 'b': binary transmit mode (raw 8-bit bytes)
		jr	clo_set_opt		; Store option
clo_a:
		ld	a, 4			; Option 'a': append mode
clo_set_opt:
		ld	(0852h), a		; Store file management option
		ret				; Return

clo_x:
		ld	a, 0FFh			; Option 'x': force Xmodem protocol flag
		ld	(26EBh), a		; Set Xmodem override flag
		ret				; Return
clo_y:
		ld	a, 0FFh			; Option 'y': force Ymodem protocol flag
		ld	(26ECh), a		; Set Ymodem override flag
		ret				; Return
clo_z:
		ld	a, 0FFh			; Option 'z': force Zmodem protocol flag
		ld	(26EEh), a		; Set Zmodem override flag
		ret				; Return
clo_p:
		ld	a, 0FFh			; Option 'p': protect destination file flag
		ld	(26EDh), a		; Set protect override flag
		ret				; Return
;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : cpm3_sysvar_hook
; Purpose  : Hook CP/M 3 system variables table via BDOS function 49 (S_SYSVAR)
; Inputs   : DE = parameter block (byte_0_478)
; Outputs  : HL = SCB / system variables pointer
; Modifies : A, C, DE, HL
;============================================================================
cpm3_sysvar_hook:
		xor	a			; Clear A
		ld	(scb_pb_reserved), a	; Set parameter block mode byte to 0 (read word)
		ld	(scb_pb_reserved2), a	; Set parameter block mode byte to 0 (read word)
		ld	c, 31h			; BDOS Function 49 (31h): Get/Set System Variable
		ld	de, 478h		; DE points to SCB parameter block (offset 28h)
		call	bdos			; Query SCB variable; returns value in HL
		ld	a, h			; Invert HL to generate bitwise mask
		cpl	
		ld	h, a
		ld	a, l
		cpl	
		ld	l, a
		ld	(scb_ptr_sysvar), hl	; Store inverted mask word
		ld	c, S_SYSVAR		; BDOS Function 49: Get/Set System Variable
		ld	de, 47Ch		; DE points to SCB parameter block (offset 24h)
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
		ld	c, 31h			; BDOS Function 49: Get/Set System Variable
		ld	de, 480h		; DE points to SCB parameter block (offset 22h)
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
		ld	de, 47Ch		; DE points to SCB PB 2 (offset 24h)
		ld	c, S_SYSVAR		; BDOS Function 49: Get/Set System Variable
		call	bdos			; Write new error vector 1 into SCB
		ld	a, 0FEh			; 0FEh = Set word in SCB parameter block
		ld	(scb_pb_reserved3), a	; Set PB mode to write word
		ld	de, 480h		; DE points to SCB PB 3 (offset 22h)
		ld	c, S_SYSVAR		; BDOS Function 49: Get/Set System Variable
		jp	bdos			; Write new error vector 2 into SCB and return
; End of function cpm3_sysvar_hook


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : cpm3_sysvar_unhook
; Purpose  : Restore CP/M 3 system variables on program exit
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
; End of function cpm3_sysvar_unhook

;----------------------------------------------------------------------------
		.db  28h ; (
scb_pb_reserved:	.db 0			; DATA XREF: cpm3_sysvar_hook+1 (write)
		.db    0 ;  
		.db    0 ;  
		.db  24h ; $
scb_pb_reserved2:	.db 0			; DATA XREF: cpm3_sysvar_hook+4 (write) cpm3_sysvar_hook+4A (write)
saved_scb_vector1:	.dw 0			; DATA XREF: cpm3_sysvar_hook+2D (write)
					; cpm3_sysvar_unhook+3 (write)
		.db  22h ; double-quote
scb_pb_reserved3:	.db 0			; DATA XREF: cpm3_sysvar_hook+57 (write)
saved_scb_vector2:	.dw 0			; DATA XREF: cpm3_sysvar_hook+45 (write)
					; cpm3_sysvar_unhook+9 (write)
scb_hook_vector1:	.dw 0			; DATA XREF: cpm3_sysvar_hook+20 (write)
					; cpm3_sysvar_unhook (read)
scb_hook_vector2:	.dw 0			; DATA XREF: cpm3_sysvar_hook+38 (write)
					; cpm3_sysvar_unhook+6 (read)
scb_ptr_sysvar:	.dw 0			; DATA XREF: cpm3_sysvar_hook+15 (write)
					; cpm3_sysvar_hook+23 (read) ...
;============================================================================
; Function : print_error_count
; Purpose  : Format and print transfer error count message to console
; Inputs   : None
; Outputs  : Error count string printed to console
; Modifies : A, C, DE
;============================================================================
print_error_count:
		ld	a, (269Fh)		; A = transfer error count
		ld	de, text_err_buf	; DE points to decimal ASCII output buffer
		call	byte_to_dec_ascii	; Convert error count byte to ASCII digits
		ld	de, text_err_crlf	; DE points to full message string
		ld	c, C_WRITESTR		; BDOS Function 9: Write string to console
		jp	bdos

text_err_crlf:	.text	"\r\n"
text_err_buf:	.db	0, 0, 0
		.text	" error(s)\r\n$"

;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : print_transfer_file_msg
; Purpose  : Print file transfer announcement header (drive, filename, user)
; Inputs   : DE = FCB pointer
; Outputs  : Announcement string printed to console
; Modifies : A, B, C, DE, HL
;============================================================================
print_transfer_file_msg:
		ld	de, tx_file_fcb		; DE points to current file FCB in BSS
		ld	hl, 4EDh		; HL points to display string colon buffer
		ld	(hl), 3Ah		; Store colon ':'
		inc	hl
		xor	a			; Clear accumulator
		ld	b, 0Dh			; Clear 13 bytes
		call	memset_buffer		; Clear filename buffer area
		inc	de			; Advance past drive byte to filename field (8+3)
		call	format_fcb_name		; Format 8.3 FCB name into display buffer
		dec	de			; Back up DE to drive byte
		ld	a, (de)			; Load 1-based drive number
		add	a, 40h			; Convert to ASCII letter ('A'..'P')
		ld	(str_colon_colon), a	; Store drive letter into display string
		dec	de			; Back up DE to user number byte
		ld	a, (de)			; Load user number (0..15)
		ld	de, 4EAh		; DE points to user number ASCII output buffer
		call	byte_to_dec_ascii	; Convert user number to decimal ASCII string
		ld	hl, 26E3h		; HL points to 32-bit file size in bytes
		ld	de, 4FCh		; DE points to file size ASCII output buffer
		call	conv_num_to_ascii	; Convert 32-bit size to formatted decimal string
		ld	(hl), 0Dh		; Append CR
		inc	hl
		ld	(hl), 0Ah		; Append LF
		inc	hl
		ld	(hl), 24h		; Append '$' terminator for BDOS output
		ld	de, 4E7h		; DE points to announcement string header
		ld	c, C_WRITESTR		; BDOS Function 9: Write string to console
		jp	bdos			; Print transfer announcement and return
; End of function print_transfer_file_msg

;----------------------------------------------------------------------------
		.db  0Dh ;  
		.db  0Ah ;  
str_colon_colon:	.db 0			; DATA XREF: print_transfer_file_msg+17 (write)
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db  20h ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  

;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : print_transfer_stats
; Purpose  : Print transfer statistics and byte count to console
; Inputs   : None
; Outputs  : Statistics string printed to console
; Modifies : A, C, DE, HL
;============================================================================
print_transfer_stats:
		ld	hl, 26A4h		; HL points to 32-bit transmitted byte counter
		ld	de, 51Ch		; DE points to ASCII string buffer
		call	conv_num_to_ascii	; Convert 32-bit count to decimal ASCII
		ld	(hl), 24h		; Append '$' string terminator
		ld	de, 51Bh		; DE points to carriage return and buffer
		ld	c, C_WRITESTR		; BDOS Function 9: Write string to console
		jp	bdos			; Output updated byte count on current line and return
; End of function print_transfer_stats

;----------------------------------------------------------------------------
		.db  0Dh ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  
		.db    0 ;  

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
		ld	de, text_cant_open	; DE points to "can't open any file" string
		jr	bdos_print_str_call	; Output string via BDOS Function 9

bdos_print_string:
		ld	de, text_file_skipped	; DE points to "File skipped" string

bdos_print_str_call:
		ld	c, C_WRITESTR		; BDOS Function 9: Write string to console
		jp	bdos			; Output string and return
; End of function bdos_print_string

;----------------------------------------------------------------------------
text_file_skipped:
		.text	"File skipped\r\n$"
text_cant_open:
		.text	"can't open any file\r\n$"


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : rx_buffer_init_ptrs
; Purpose  : Initialize receive buffer head/tail pointers and counters
; Inputs   : A = initial buffer offset
; Outputs  : byte_0_55F, rx_buf_count initialized
; Modifies : HL
;============================================================================
rx_buffer_init_ptrs:
		ld	hl, 55Fh		; Point HL to buffer input index byte
		ld	(hl), a			; Initialize input index with value in A
		inc	hl			; Advance HL to buffer count byte
		ld	(hl), c			; Initialize buffer count with value in C
		ret				; Return
; End of function rx_buffer_init_ptrs

;----------------------------------------------------------------------------
		.db    0 ;  
rx_buf_count:	.db 0			; DATA XREF: rx_buffer_get_byte (read)

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
		ld	hl, (2067h)		; Load current free byte count in receive buffer
		ld	de, 200h		; DE = maximum receive ring buffer capacity (512 bytes)
		sbc	hl, de			; Test if buffer is full
		jr	z, rx_buf_poll_check_cnt ; If buffer full, do not read; check available count
		ld	c, A_STATIN		; BDOS Function 7: Auxiliary input status
		call	bdos			; Check if serial hardware has a byte waiting
		or	a			; 00h = no character ready, 0FFh = character ready
		jr	z, rx_buf_poll_check_cnt ; If no character ready, check buffered count
		ld	c, A_READ		; BDOS Function 3: Auxiliary input read
		call	bdos			; Read incoming character byte from serial port into A
		ld	c, a			; C = received character byte
		ld	hl, 2067h		; HL points to ring buffer control header
		call	rx_buffer_put_byte	; Store byte into circular receive buffer
		jr	rx_buffer_poll		; Loop to suck in all available characters from UART

rx_buf_poll_check_cnt:
		ld	hl, 560h		; HL points to count of unread buffered bytes
		or	(hl)			; Test if single-byte buffer holds a character
		ret	nz			; Return NZ if character ready
		ld	hl, (2067h)		; Load buffered count from circular ring buffer
		ld	a, h			; Check if ring buffer has any queued bytes
		or	l
		ret				; Return Z if empty, NZ if data present
; End of function rx_buffer_poll


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
		ld	hl, 2067h		; HL points to ring buffer control block
		jp	z, tx_raw_next_byte	; If empty, read from circular ring buffer
		push	af			; Preserve AF
		ld	hl, 560h		; HL points to rx_buf_count
		dec	(hl)			; Decrement buffered byte count
		dec	hl			; Point back to input index
		pop	af			; Restore AF
		ld	a, (hl)			; Load single-byte buffered character into A
		ret				; Return character in A
; End of function rx_buffer_get_byte

;----------------------------------------------------------------------------
#include "aux_io.inc"

;----------------------------------------------------------------------------

tx_raw_next_byte:
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
		and	1			; Mask to ring buffer size (512 bytes / 1FFh)
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
		ld	hl, 200h		; HL = maximum ring buffer capacity (512 bytes)
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
		and	1			; Mask to ring buffer size (512 bytes)
		ld	(hl), a			; Store updated high byte of write offset
		pop	hl			; Restore HL = target byte address in ring buffer
		ld	(hl), c			; Store received character byte C into ring buffer
		ret				; Return with character stored (NZ)
; End of function rx_buffer_put_byte


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
		ld	hl, tx_file_user	; HL points to transfer state block (user + FCB)
		ld	b, FCB_SIZE + 1		; Count = 37 (25h) bytes to clear (user + 36-byte FCB)
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
		xor	a			; Fill byte = 00h
		jp	memset_buffer		; Fill memory with zeroes and return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : dispatch_table_jump
; Purpose  : Jump to indexed table address entry
; Inputs   : HL = table base, BC = index
; Outputs  : Jumps to target subroutine
; Modifies : A, BC, HL
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
; 32-Bit Decimal Powers Table (10^9 down to 10^1)
; Used by conv_num_to_ascii for repeated-subtraction decimal conversion.
;----------------------------------------------------------------------------
table_dec_powers_32:
		.db	0,   0CAh, 9Ah,  3Bh	; 1,000,000,000 (3B9ACA00h)
		.db	0,   0E1h, 0F5h, 5	;   100,000,000 (05F5E100h)
		.db	80h, 96h,  98h,  0	;    10,000,000 (00989680h)
		.db	40h, 42h,  0Fh,  0	;     1,000,000 (000F4240h)
		.db	0A0h,86h,  1,    0	;       100,000 (000186A0h)
		.db	10h, 27h,  0,    0	;        10,000 (00002710h)
		.db	0E8h,3,    0,    0	;         1,000 (000003E8h)
		.db	64h, 0,    0,    0	;           100 (00000064h)
		.db	0Ah, 0,    0,    0	;            10 (0000000Ah)

;============================================================================
; Function : conv_num_to_ascii
; Purpose  : Convert 32-bit binary number at (HL) into decimal ASCII string at (DE)
; Inputs   : HL = pointer to 32-bit integer, DE = output string buffer
; Outputs  : Output string filled with decimal digits (null-terminated)
; Modifies : All registers
;
; C-Equivalent Algorithm:
;   void conv_num_to_ascii(uint32_t val, char *buf) {
;       static const uint32_t p10[] = {
;           1000000000, 100000000, 10000000, 1000000,
;           100000, 10000, 1000, 100, 10
;       };
;       int emit = 0;
;       for (int i = 0; i < 9; i++) {
;           char d = '0';
;           while (val >= p10[i]) { val -= p10[i]; d++; }
;           if (d != '0' || emit) { *buf++ = d; emit = 1; }
;       }
;       *buf++ = '0' + (char)val; // remaining units digit
;       *buf = '\0';
;   }
;============================================================================
conv_num_to_ascii:
		ld	(patch_num_conv_ptr), de ; Store destination string pointer into SMC operand
		ld	de, 2293h		; DE points to working 32-bit temporary buffer
		call	copy_4bytes		; Copy input 32-bit integer into work buffer
		ld	c, +(conv_num_to_ascii-table_dec_powers_32)/4 ; Number of power-of-10 divisor entries (9)
		ld	de, table_dec_powers_32-4 ; Initialize power table pointer before first entry
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
		ld	hl, 2293h		; Minuend: current remainder
		ld	bc, 2297h		; Destination: candidate remainder
		call	sub32			; Subtract power of 10 from current remainder
		pop	bc			; Restore BC
		jr	c, conv_num_to_as_br_1 ; If borrow (underflow), divisor exceeded remainder
		push	de			; Preserve power table pointer
		ld	a, (patch_num_conv_base) ; Increment ASCII digit value
		inc	a
		ld	(patch_num_conv_base), a ; Update digit accumulator
		ld	de, 2293h		; Copy candidate remainder back to work buffer
		ld	hl, 2297h
		call	copy_4bytes
		pop	de			; Restore power table pointer
		djnz	conv_num_to_as_call_1 ; Repeat subtraction loop

patch_num_conv_base:	.equ	$+1		; SMC: immediate byte operand holding computed digit
conv_num_to_as_br_1:
		ld	a, 30h			; Load computed ASCII digit
		cp	30h			; Is it a leading zero ('0')?
		jr	nz, conv_num_to_as_step_2 ; If non-zero digit, emit it unconditionally
patch_num_conv_flags:	.equ	$+1		; SMC: immediate flag indicating leading zero state
		ld	a, 0			; 0 = suppressing leading zeroes
		or	a
		jr	z, conv_num_to_as_br_2 ; If zero suppression active, skip emitting digit
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
		ld	a, (2293h)		; Load remaining units digit (0..9)
		and	0Fh			; Mask low nibble
		add	a, 30h			; Convert to ASCII character ('0'..'9')
		ld	hl, (patch_num_conv_ptr) ; Load final output string pointer
		ld	(hl), a			; Store units digit into buffer
		inc	hl			; Advance pointer
		ld	(hl), 0			; Append null terminator
		ret				; Return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : checksum8_update
; Purpose  : Update 8-bit additive checksum accumulator with byte in A
; Inputs   : A = byte to add
; Outputs  : checksum8_acc updated
; Modifies : None
;============================================================================
checksum8_update:
		push	af			; Preserve AF
checksum8_acc:	add	a, 0		; SMC: Add byte to running 8-bit checksum accumulator
		ld	(checksum8_acc+1), a	; Store updated checksum back to SMC operand
		pop	af			; Restore AF
		ret				; Return

#include "crc.inc"


;----------------------------------------------------------------------------
; Transmission Configuration Parameters:
;   Block sizes, default protocol mode, and window parameters.
;----------------------------------------------------------------------------
		.db	0, 4			; Default subpacket length: 0400h (1024 bytes)
		.db	0, 0			; High word = 0
		.db	0, 0FCh, 0FFh, 0FFh	; 32-bit -1024 (FFFFFC00h) position decrement
protocol_mode:	.db	4			; Default protocol mode (4 = Zmodem-32, 3 = Zmodem-16)
		.db	20h			; Default transmit window size (32 blocks = 32KB)

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : calc_buffer_mask
; Purpose  : Configure transmission buffer sizing, initialize state, and run batch engine
; Inputs   : H = memory top page
; Outputs  : CY set on transfer error, NC on success
; Modifies : All registers
;============================================================================
calc_buffer_mask:
		ld	a, (protocol_mode)	; Load active protocol mode byte
		cp	4			; Is protocol mode 4 (Zmodem-32)?
		jr	nz, calc_mask_done	; If not, proceed with current mode
		ld	a, 3			; Fallback to protocol mode 3 (Zmodem-16)
		ld	(protocol_mode), a	; Store updated protocol mode

calc_mask_done:
		xor	a			; A = 0
		ld	hl, retry_err_counter	; HL points to transfer state block in RAM (269Fh)
		ld	b, 50h			; 80 (50h) bytes to clear
		call	memset_buffer		; Zero out transfer state memory
		call	clear_transfer_state	; Clear active file FCB (25h bytes at 226Dh)
		call	build_crc32_table	; Dynamically build 1KB CRC-32 table in RAM
		ld	hl, nstack		; HL points to transfer statistics block (2067h)
		call	clear_6_bytes		; Zero out 6 bytes
		ld	hl, (file_pos_align_base) ; Load available free TPA memory bytes (26F3h)
		call	init_crc_acc		; Compute power-of-two buffer size and wrap mask
		ld	hl, 400h		; Default subpacket length = 1024 (400h) bytes
		ld	(tx_subpacket_size), hl	; Store into tx_subpacket_size (26CFh)
		call	tx_batch_engine		; Execute main file transfer batch sender engine
		jr	c, calc_mask_done_err_1 ; If carry set, transfer failed
		or	a			; Clear carry flag (success)
		ret				; Return

calc_mask_done_err_1:
		scf				; Set carry flag (transfer aborted or error)
		ret				; Return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : init_crc_acc
; Purpose  : Compute largest power-of-two buffer size and address wrap mask from available RAM
; Inputs   : H = Available memory top page count
; Outputs  : (file_pos_align_base) = power-of-two buffer size, (tx_buf_mask) = wrap mask
; Modifies : A, BC, HL
;============================================================================
init_crc_acc:
		xor	a			; Clear accumulator
		ld	c, a			; Initialize bit mask register C = 0
		ld	b, 8			; Test up to 8 bits
		ld	a, h			; Load memory page high byte into A

init_crc_acc_br_1:
		rlca				; Shift highest bit into carry
		set	7, c			; Set bit 7 in mask register C
		jr	c, init_crc_acc_step_1 ; If highest bit set, mask is complete
		rr	c			; Shift mask bit right
		djnz	init_crc_acc_br_1	; Test next bit

init_crc_acc_step_1:
		ld	a, h			; A = high byte of available pages
		and	c			; Mask to largest power-of-two page boundary
		ld	h, a			; Set HL high byte to power-of-two page
		ld	l, 0			; Set HL low byte to 0 (page-aligned)
		ld	(file_pos_align_base), hl ; Store power-of-two buffer size (26F3h)
		dec	hl			; Subtract 1 to create circular address wrap mask
		ld	(tx_buf_mask), hl	; Store buffer mask (26DAh)
		ret				; Return

;----------------------------------------------------------------------------
;============================================================================
; Function : fetch_next_matched_file
; Purpose  : Extract next directory entry from matched files list into FCB
; Inputs   : None (uses self-modifying immediate pointer files_matched_list)
; Outputs  : Next file FCB copied to 226Dh, files_matched_list pointer advanced
; Modifies : A, BC, DE, HL
; Notes    : Uses self-modifying code (SMC) via files_matched_list and default_drive_num.
;============================================================================
fetch_next_matched_file:
; SMC TARGET: Patched by ld (files_matched_list), hl at main_tx_loop (line 225) and advanced below
files_matched_list:	.equ	$+1		; SMC pointer immediate operand
		ld	hl, 0			; Dynamically patched with matching files list
		ld	de, tx_file_user	; Destination buffer: user byte followed by FCB
		ldi				; Copy status/user byte
; SMC TARGET: Patched by ld (default_drive_num), a at main_tx_loop (line 210)
default_drive_num:	.equ	$+1		; SMC drive immediate operand
		ld	a, 0			; Dynamically patched default drive number
		ld	(de), a			; Store drive into FCB
		inc	de			; Advance FCB pointer
		ld	bc, 11			; 11 bytes: 8 filename + 3 extension
		ldir				; Copy 8.3 filename
		ld	hl, (files_matched_list)	; Load current directory entries pointer
		ld	bc, 16			; Directory entries are 16 bytes each
		add	hl, bc			; Advance to next directory record
		ld	(files_matched_list), hl	; Save updated pointer for next file
		ret				; Return
;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : tx_batch_engine
; Purpose  : Main protocol sender batch engine (manages file queue and protocol state)
; Inputs   : None
; Outputs  : Batch transfer completed or aborted
; Modifies : All registers
;============================================================================
tx_batch_engine:
		xor	a			; A = 0
		ld	(26A9h), a		; Clear remote capability flags (remote_can_flags)
		ld	a, 0FFh			; A = 0FFh
		ld	(26AEh), a		; Initialize abort flag (tx_can_flag)
		ld	a, (26F7h)		; Load count of matched files to transfer
		or	a			; Were any matching files found?
		jr	z, tx_batch_engin_call_2 ; If zero files, skip batch transfer
		ld	b, a			; B = file count loop counter

tx_batch_engin_call_1:
		push	bc			; Preserve remaining file count
		ld	a, b			; A = current file index
		call	fetch_next_matched_file	; Load next file FCB into cur_file_fcb
		ld	hl, 26DCh		; HL = tx_window_offset (26DCh)
		call	clear_4bytes		; Clear 4-byte transmit window offset
		call	tx_file_transfer	; Transmit current file
		push	af			; Preserve transfer exit code
		cp	5			; Exit code 5 = file skipped / not found
		call	z, bdos_print_string	; Print skip message if applicable
		call	cpm_bdos_open_file	; Close / reopen FCB cleanup
		pop	af			; Restore transfer exit code
		pop	bc			; Restore remaining file count
		jr	c, tx_batch_engin_err_1 ; If carry set, transfer aborted by error
		djnz	tx_batch_engin_call_1	; Repeat for all matched files
		ld	a, (26D9h)		; Check total files transferred count
		or	a			; Were any files transferred?
		jr	nz, tx_batch_engin_br_1 ; If at least one file transferred, complete batch session

tx_batch_engin_call_2:
		call	print_file_skipped	; Display file skipped message

tx_batch_engin_err_1:
		call	tx_can_sequence		; Transmit CAN CAN CAN CAN CAN abort sequence
		ld	a, 0FFh			; Return error status
		scf				; Set carry flag (error)
		ret				; Return

tx_batch_engin_br_1:
		ld	a, (protocol_mode)	; Load active protocol mode
		cp	3			; Ymodem or higher?
		jr	c, tx_batch_engin_step_1 ; If Xmodem (mode < 3), no batch trailer needed
		jr	nz, tx_batch_engin_call_3 ; If Zmodem (mode 4), finish via ZFIN frame
		xor	a			; Ymodem batch termination: transmit empty block 0
		ld	(26E1h), a		; Packet sequence number = 0 (26E1h)
		ld	hl, (26EFh)		; HL points to packet buffer base (26EFh)
		ld	b, 80h			; 128 bytes of zeroes
		call	memset_buffer		; Zero out packet payload (empty filename)
		ld	hl, 80h			; Packet length = 128 bytes
		ld	(26E7h), hl		; Set packet size
		call	tx_zmodem_file_step_1	; Transmit empty block 0 to signal end of batch
		xor	a			; Clear A

tx_batch_engin_call_3:
		call	nz, tx_zfin_session_finish ; If Zmodem, transmit ZFIN frame session finish

tx_batch_engin_step_1:
		xor	a			; Clear carry (success)
		ret				; Return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : tx_file_transfer
; Purpose  : Send single file via selected protocol (Zmodem / Ymodem / Xmodem)
; Inputs   : DE = FCB pointer
; Outputs  : File transmitted, CY on abort
; Modifies : All registers
;============================================================================
tx_file_transfer:
		ld	de, tx_file_fcb		; DE points to transmit file FCB
		call	bdos_compute_file_size	; BDOS Function 35: Compute file size in records
		ld	de, 0			; Convert 128-byte records to 32-bit byte count (* 128)
		srl	h			; DE:HL = records * 128
		rr	l
		rr	e
		ld	d, l
		ld	l, h
		ld	h, 0
		ld	(26E3h), de		; Save 32-bit file size low word (26E3h)
		ld	(26E5h), hl		; Save 32-bit file size high word (26E5h)
		ld	hl, 26C3h		; Clear 4-byte buffered position (26C3h)
		call	clear_4bytes
		ld	de, tx_file_fcb		; DE points to FCB
		call	cpm_bdos_read_record	; Open file via BDOS
		jr	z, tx_file_transf_step_1 ; If open successful, continue
		xor	a			; Return error / skip
		ret				; Return

tx_file_transf_step_1:
		xor	a			; Clear A
		ld	(269Fh), a		; Clear packet retry error counter (269Fh)
		ld	a, 0
		ld	(26D6h), a		; Clear transmit EOF flag (26D6h)
		ld	(26D7h), a		; Clear file reader EOF flag (26D7h)
		ld	de, tx_file_fcb		; DE points to FCB
		call	print_transfer_file_msg	; Print sending filename banner to console
		ld	hl, 26D9h		; Increment total files transferred count
		inc	(hl)
		call	tx_send_file_data	; Send file header info / initiate protocol transfer
		ret	c			; If carry set, transfer failed
		cp	5			; Was file skipped?
		ret	z			; If skipped, return
		ld	a, (protocol_mode)	; Load active protocol mode
		cp	4			; Is mode 4 (Zmodem)?
		call	nz, tx_zmodem_file_session ; If X/Ymodem (mode < 4), stream file data blocks
		ret				; Return

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : tx_send_file_data
; Purpose  : Stream file data payload sectors using Zmodem ZDATA frames
; Inputs   : None
; Outputs  : Payload transmitted, position updated
; Modifies : All registers
;============================================================================
tx_send_file_data:
		ld	hl, (26EFh)		; HL points to transmit packet buffer base (26EFh)
		xor	a			; A = 0
		ld	b, 80h			; 128 bytes
		call	memset_buffer		; Zero out 128 bytes in buffer
		ld	de, tx_file_fcb + FCB_NAME ; DE points to filename in FCB (skip drive)
		call	format_fcb_name		; Format 8.3 filename as string at HL
		ld	b, 0Ch			; 12 characters max
tx_send_file_d_call_1:
		ld	a, (hl)			; Load filename character
		call	is_alpha_char		; Test if character is alphabetic
		jr	nz, tx_send_file_d_loop_1
		or	20h			; Convert uppercase ASCII character to lowercase (+20h)
		ld	(hl), a			; Store lowercase character back to buffer
tx_send_file_d_loop_1:
		inc	hl			; Advance character pointer
		djnz	tx_send_file_d_call_1	; Repeat for all characters
		ld	hl, (26EFh)		; HL points to formatted filename
		call	print_inline_string	; Scan to null terminator at end of filename
		ld	(hl), 0			; Store null terminator
		inc	hl			; Advance past null terminator
		ld	de, 26E3h		; DE points to 32-bit file size in bytes
		ex	de, hl			; HL = file size, DE = buffer position after filename
		push	de			; Preserve buffer pointer
		call	conv_num_to_ascii	; Convert 32-bit file size to ASCII decimal string
		pop	de			; Restore buffer pointer
		ld	a, (protocol_mode)	; Check active protocol mode
		cp	3			; Ymodem (3) or Zmodem (4)?
		ccf				; Invert carry flag
		ret	nc			; If Xmodem (mode < 3), header block not sent
		ld	a, (26D8h)		; Check transfer framing flags (26D8h)
		cp	68h			; Protocol already negotiated ('h' = 68h)?
		call	nz, tx_dispatch_protocol ; Negotiate protocol handshake with receiver
		ret	c			; If carry set, handshake failed or aborted
		xor	a			; A = 0
		ld	(26E1h), a		; Packet sequence number = 0 (block 0 header, 26E1h)
		ld	a, (protocol_mode)	; Check active protocol mode
		cp	3			; Mode 3 = Ymodem
		ld	hl, 80h			; 128 bytes packet size
		ld	(26E7h), hl		; Set packet size
		jp	z, tx_zmodem_file_step_1 ; If Ymodem, transmit block 0 header
		ld	hl, (26EFh)		; If Zmodem: calculate ZFILE header payload length
		call	print_inline_string	; Skip filename
		inc	hl			; Skip null delimiter
		call	print_inline_string	; Skip file size
		ld	de, (26EFh)		; Calculate total payload string bytes
		or	a
		sbc	hl, de
		inc	hl			; Include trailing null byte
		ex	de, hl			; DE = header payload byte count
		jp	tx_data_subpac_call_1	; Transmit ZFILE frame data subpacket

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : tx_dispatch_protocol
; Purpose  : Dispatch file transmission based on protocol mode (Z/Y/Xmodem)
; Inputs   : None
; Outputs  : Protocol initialized
; Modifies : All registers
;
; Protocol State Machine:
;       +-------------------------------------------------------------+
;       |                    tx_dispatch_protocol                     |
;       +-------------------------------------------------------------+
;                                      |
;                             [mode >= 3 (Z/Y)]?
;                               /              \
;                            (No)             (Yes)
;                             /                  \
;                            v                    v
;                     Listen directly      Send ZRQINIT header
;                            \                    /
;                             v                  v
;                      Wait response char (comm_rx_char_filtered)
;                                      |
;                 +--------------------+--------------------+
;                 |           Match proto_negotiate_chars   |
;                 +--------------------+--------------------+
;                 |          |         |          |         |
;                '*'       0xFE       'C'        NAK       CAN
;                 |          |         |          |         |
;                 v          v         v          v         v
;               ZPAD       Error     CRC-16     Chksum   Wait 2nd CAN
;              (Zmodem)   (Abort)   (Y/Xmodem) (Xmodem)  (Cancel)
;============================================================================
tx_dispatch_protocol:
		ld	a, (protocol_mode)	; Check active protocol mode
		cp	3			; Mode 3 (Ymodem) or Mode 4 (Zmodem)?
		ld	a, 0			; Frame type 0 = ZRQINIT
		call	nc, tx_hex_header	; If Z/Ymodem, transmit ZRQINIT hex header
		xor	a			; Clear error / response status bytes
		ld	(26E2h), a		; Clear rx_err_status (26E2h)
		ld	(26E0h), a		; Clear rx_response_char (26E0h)

tx_dispatch_pr_call_1:
		ld	b, 0FFh			; Long timeout (~25 seconds)
		call	comm_rx_char_filtered	; Read response character from receiver
		ld	(26E0h), a		; Save received character
		ld	hl, proto_negotiate_chars ; Expected handshake characters: '*', 0xFE, 'C', NAK, CAN
		ld	bc, 5			; 5 characters in table
		cpir				; Search for match
		jp	z, dispatch_table_jump	; Dispatch to matching response handler
tx_dispatch_pr_save:
		ld	a, (26E0h)		; Save last character as error status
		ld	(26E2h), a		; rx_err_status (26E2h)
		jr	tx_dispatch_pr_call_1	; Wait for valid handshake response

;----------------------------------------------------------------------------
; Protocol Negotiation Response Handlers:
;   CAN (0x18) : Verify double-CAN cancellation sequence
;   'C' (0x43) : Configure CRC-16 mode for Ymodem/Xmodem
;   NAK (0x15) : Acknowledge negative response
;   0xFE       : Return transfer error
;   '*' (0x2A) : Handshake Zmodem protocol (ZPAD)
;----------------------------------------------------------------------------
proto_resp_can:
		ld	b, 14h			; Short timeout (20 ticks) for second CAN
		call	comm_rx_char_filtered	; Read next character
		ld	(26E0h), a		; Save received character
proto_resp_can_chk:
		cp	18h			; Is character CAN (0x18)?
		jr	nz, tx_dispatch_pr_save	; If not CAN, ignore and keep waiting
		ld	hl, 26E2h		; Compare against previous character (26E2h)
		cp	(hl)			; Was previous character also CAN?
		jr	nz, tx_dispatch_pr_save	; If not double CAN, keep waiting
		ld	a, 0FFh			; Double CAN verified: set abort code
		scf				; Set carry flag (transfer aborted)
		ret				; Return

proto_resp_crc_c:
		ld	a, 10h			; Set CRC-16 mode capability flag
		ld	(26A9h), a		; remote_can_flags (26A9h)
proto_resp_nak:
		xor	a			; Clear error flag (success)
		ret				; Return

proto_resp_err:
		ld	a, 0FFh			; Set abort error code
		scf				; Set carry flag (error)
		ret				; Return

proto_resp_zmodem:
		call	tx_wait_zrinit		; Wait for and process incoming ZRINIT frame
		ret	c			; If carry, ZRINIT negotiation failed
		ld	a, 4			; Protocol mode = 4 (Zmodem)
		ld	(protocol_mode), a	; Store updated protocol mode
		xor	a			; Clear carry (success)
		ret				; Return

;----------------------------------------------------------------------------
; Protocol Negotiation Dispatch Table
;   Handshake response characters: '*', 0xFE, 'C', NAK (0x15), CAN (0x18)
;   Followed by corresponding 16-bit handler jump vectors (.dw targets).
;----------------------------------------------------------------------------
proto_negotiate_chars:
		.db	'*', 0FEh, 'C', 15h, 18h
proto_negotiate_count:	.equ	$-proto_negotiate_chars

		.dw	proto_resp_can		; CAN (0x18) -> verify abort
		.dw	proto_resp_nak		; NAK (0x15) -> retry
		.dw	proto_resp_crc_c	; 'C' (0x43) -> CRC-16 mode
		.dw	proto_resp_err		; 0xFE -> error
		.dw	proto_resp_zmodem	; '*' (0x2A) -> Zmodem handshake

;----------------------------------------------------------------------------
; Session Character Search Table (for tx_zmodem_file_session)
;   Characters: NAK (0x15), 'C' (0x43), 0xFE, CAN (0x18)
;----------------------------------------------------------------------------
proto_session_chars:
		.db	15h, 'C', 0FEh, 18h
proto_session_count:	.equ	$-proto_session_chars

		.dw	session_resp_nak	; NAK handler (0A76h)
		.dw	session_resp_can	; CAN handler (0ADDh)
		.dw	session_resp_crc_c	; 'C' CRC mode handler (0A7Ah)
		.dw	session_resp_ready	; Ready handler (0A7Fh)

;----------------------------------------------------------------------------
;		S u b r	o u t i	n e

;============================================================================
; Function : tx_zmodem_file_session
; Purpose  : Execute Xmodem / Ymodem file streaming session
; Inputs   : None
; Outputs  : Session completed
; Modifies : All registers
;============================================================================
tx_zmodem_file_session:
		xor	a			; Clear A
		ld	(26A9h), a		; Clear remote_can_flags (26A9h)
		ld	a, 0FFh			; A = 0FFh
		ld	(26AEh), a		; Initialize tx_can_flag (26AEh)
		ld	hl, 26B7h		; HL = file_pos_curr (26B7h)
		call	clear_4bytes		; Clear 4-byte current file position
		ld	hl, 26DCh		; HL = tx_window_offset (26DCh)
		call	clear_4bytes		; Clear 4-byte window offset

tx_zmodem_file_call_1:
		ld	b, 0FFh			; Long timeout (~25 seconds)
		call	comm_rx_char_filtered	; Read receiver start character
		ld	(26E0h), a		; Save received character (26E0h)
		ld	hl, proto_session_chars	; Table: NAK, 'C', 0xFE, CAN
		ld	bc, 4			; 4 characters
		cpir				; Search table
		jr	nz, tx_zmodem_file_call_1 ; If no match, keep waiting
		jp	dispatch_table_jump	; Dispatch to matching handler

;----------------------------------------------------------------------------
;============================================================================
; Session Handlers for tx_zmodem_file_session
;============================================================================
session_resp_nak:
		ld	a, 0FFh			; Transfer error / abort
		scf				; Set carry flag (error)
		ret				; Return

session_resp_crc_c:
		ld	a, 10h			; Receiver requested CRC-16 mode ('C' = 43h)
		ld	(26A9h), a		; Set CRC-16 capability flag (26A9h)
session_resp_ready:
		xor	a			; Clear packet sequence number
		ld	(26E1h), a		; packet_seq_num (26E1h)
session_stream_loop:
		ld	hl, 26E3h		; HL = 32-bit total file size
		ld	de, 26B7h		; DE = 32-bit current file position (26B7h)
		ld	bc, 26C7h		; BC = destination temporary buffer (temp_pos_32)
		call	sub32			; Calculate remaining bytes: temp_pos_32 = size - pos
		ld	hl, 26C7h		; HL = remaining bytes
		ld	de, 084Ah		; DE = 1024 bytes (0400h constant at 084Ah)
		call	cmp_pos32		; Compare remaining bytes against 1024
		ld	hl, 400h		; 1024-byte subpacket size
		jr	nc, session_have_subsz	; If remaining >= 1024, use 1K packet
		ld	hl, 80h			; Otherwise, fallback to 128-byte packet size
session_have_subsz:
		ld	(26E7h), hl		; Save active subpacket length
		ld	bc, (26E7h)		; BC = byte count to read from file
		call	tx_fill_buf_from_file	; Read data from file into transmit buffer
		jr	c, session_resp_can	; If read error, abort transfer
		or	a			; Check bytes read status
		jr	z, session_chk_avail	; If data was read, transmit sector
		ld	a, d			; Check if remaining length is zero (EOF)
		or	e
		jr	z, session_poll_resp	; If EOF, poll for session completion
session_chk_avail:
		ld	hl, 26E1h		; Increment packet sequence number
		inc	(hl)			; packet_seq_num (26E1h)
		call	tx_zmodem_file_step_1	; Transmit X/Ymodem data packet
		ret	c			; If carry set, transmission failed
		ld	hl, 26B7h		; HL = current file position (26B7h)
		ld	de, 26E7h		; DE = packet size added
		ld	bc, 26B7h		; BC = destination: update file_pos_curr
		call	add32			; file_pos_curr += packet_size
		jr	session_stream_loop	; Stream next sector

session_poll_resp:
		ld	b, 5			; Send EOT up to 5 times
session_poll_loop:
		push	bc			; Preserve retry counter
		ld	a, 4			; EOT character (04h)
		call	comm_tx_char_wait	; Transmit EOT
		ld	b, 100			; Timeout ~10 seconds
		call	comm_rx_char_filtered	; Read receiver response
		cp	6			; Is response ACK (06h)?
		jr	z, session_resp_ack	; If ACK received, transfer successful
		pop	bc			; Restore retry counter
		djnz	session_poll_loop	; Retry sending EOT
session_resp_can:
		ld	a, 0FFh			; Abort code
		scf				; Set carry flag (error)
		ret				; Return

session_resp_ack:
		pop	bc			; Clean up stack
		xor	a			; Clear carry (success)
		ret				; Return

;----------------------------------------------------------------------------
tx_zmodem_file_step_1:
		xor	a			; Clear A
		ld	(26E0h), a		; Clear last response character (26E0h)
		ld	(269Fh), a		; Clear retry error counter (269Fh)
tx_zmodem_file_step_2:
		ld	a, (26E0h)		; Save response char into error status
		ld	(26E2h), a		; rx_err_status (26E2h)
		ld	hl, 26B7h		; HL = current file position (26B7h)
		ld	de, 26A4h		; DE = display progress count (26A4h)
		call	copy_4bytes		; Update progress counter for display
		call	print_transfer_stats	; Update console transfer progress display
		ld	hl, (26E7h)		; Load packet payload length (128 or 1024)
; SMC WRITER: Patches immediate operand of ld hl, imm at tx_packet_body_loop (patch_packet_len)
		ld	(patch_packet_len), hl	; Store into SMC loop counter
		ld	a, l			; Check low byte of length
		cp	80h			; Is length 128 bytes?
		ld	a, 1			; SOH (01h = 128-byte packet start)
		jr	z, tx_zmodem_file_call_2 ; If 128 bytes, send SOH
		ld	a, 2			; STX (02h = 1024-byte packet start)

tx_zmodem_file_call_2:
		call	comm_tx_char_wait	; Transmit SOH or STX packet header byte
		ld	a, (26E1h)		; Load packet sequence number (26E1h)
		call	comm_tx_char_wait	; Transmit packet sequence number
		ld	a, (26E1h)		; Load packet sequence number again
		cpl				; Invert sequence number (~seq)
		call	comm_tx_char_wait	; Transmit inverted sequence number
		call	reset_crc_checksum	; Reset CRC-16 and 8-bit checksum accumulators
		ld	ix, (26EFh)		; IX points to packet payload data buffer (26EFh)
tx_packet_byte_loop:
		ld	a, (ix+0)		; Fetch next payload byte from buffer
		call	checksum8_update	; Update running 8-bit checksum
		call	crc16			; Update running CRC-16
		push	ix			; Preserve buffer pointer
		call	comm_tx_char_wait	; Transmit payload byte to serial port
		pop	ix			; Restore buffer pointer

; SMC TARGET: Patched by ld (patch_packet_len), hl above and decremented below
patch_packet_len:	.equ	$+1		; SMC: packet payload byte counter
tx_packet_body_loop:
		ld	hl, 0000h		; Dynamically patched with remaining byte count
		dec	hl			; Decrement remaining byte count
; SMC WRITER: Updates immediate operand of ld hl, imm above (patch_packet_len)
		ld	(patch_packet_len), hl	; Update remaining count
		inc	ix			; Advance buffer pointer
		ld	a, h			; Test if all bytes sent
		or	l
		jr	nz, tx_packet_byte_loop	; Loop until entire packet payload is sent
		ld	a, (26A9h)		; Check if receiver requested CRC-16 mode (10h)
		cp	10h
		jr	z, tx_packet_send_crc16	; If CRC-16 mode, transmit 16-bit CRC
		ld	a, (checksum8_val)	; Otherwise, load 8-bit checksum byte
		jr	tx_packet_send_crc_byte ; Transmit single checksum byte

tx_packet_send_crc16:
		ld	a, (crc16_seed+2)	; Load CRC-16 high byte
		call	comm_tx_char_wait	; Transmit CRC-16 high byte
		ld	a, (crc16_seed+1)	; Load CRC-16 low byte
tx_packet_send_crc_byte:
		call	comm_tx_char_wait	; Transmit CRC-16 low byte or 8-bit checksum
		ld	b, 64h			; Timeout ~10 seconds
		call	comm_rx_char_filtered	; Read receiver response byte
		ld	(26E0h), a		; Save response character (26E0h)
tx_packet_eval_resp:
		ld	a, (26E0h)		; Load received response character
		ld	hl, rx_packet_resp_table ; Response search table: CAN, 0xFE, 'C', NAK, ACK, timeout
		ld	bc, 6			; 6 table entries
		cpir				; Search for matching response
		jp	z, dispatch_table_jump	; Dispatch to response handler
		jp	rx_packet_resp_nak	; Unrecognized response -> treat as NAK

rx_resp_timeout_check:
		ld	a, (26E2h)		; Check previous error status (26E2h)
		cp	18h			; Was previous character CAN (0x18)?
		jp	nz, rx_packet_resp_nak	; If not CAN, treat as NAK and retry
rx_resp_timeout_abort:
		ld	a, 0FFh			; Set abort error code
		scf				; Set carry flag (transfer aborted)
		ret				; Return

rx_resp_ack:
		jp	tx_packet_ack_next	; ACK received -> process packet completion

rx_resp_nak:
		ld	a, (26AEh)		; Check cancel flag (26AEh)
		cp	0FFh			; Is abort pending?
		jr	nz, rx_resp_crc_mode	; If not pending, continue
		ld	a, 10h			; Set CRC-16 mode flag
		ld	(26A9h), a		; remote_can_flags (26A9h)

rx_resp_crc_mode:
		jp	tx_packet_ack_next	; Proceed to retry handling

rx_resp_nak_step:
		ld	a, 0			; Clear cancel flag
		ld	(26AEh), a		; tx_can_flag (26AEh)
		xor	a			; A = 0
		ld	(269Fh), a		; Reset retry error counter on valid handshake
		ret				; Return

rx_resp_can:
		jp	rx_packet_resp_nak	; Single CAN -> poll for second CAN or NAK

rx_packet_resp_table:
		.db	18h			; CAN (0x18)
		.db	0FEh			; Framing error (0xFE)
		.db	43h			; 'C' (CRC mode request)
		.db	15h			; NAK (0x15)
		.db	06h			; ACK (0x06)
		.db	0FFh			; Timeout (0xFF)

rx_packet_resp_vectors:
		.dw	rx_resp_can		; CAN handler
		.dw	rx_resp_nak_step	; ACK/NAK step handler
		.dw	rx_resp_crc_mode	; CRC mode switch handler
		.dw	rx_resp_nak		; NAK handler
		.dw	rx_resp_ack		; ACK handler
		.dw	rx_resp_timeout_check	; Timeout / abort check handler

rx_packet_resp_table2:
		.db	0FEh			; Framing error (0xFE)
		.db	15h			; NAK (0x15)
		.db	43h			; 'C' (CRC mode request)
		.db	18h			; CAN (0x18)

rx_packet_resp_vectors2:
		.dw	rx_resp_tbl2_fe		; Framing error handler
		.dw	tx_packet_eval_resp	; Retry response evaluation
		.dw	tx_packet_eval_resp	; Retry response evaluation
		.dw	tx_packet_ack_next	; Next packet / error count handler

rx_packet_resp_nak:
		ld	a, (26E0h)		; Save last response character
		ld	(26E2h), a		; rx_err_status (26E2h)
rx_packet_resp_poll:
		ld	b, 64h			; Timeout ~10 seconds
		call	comm_rx_char_filtered	; Read next serial character
		ld	(26E0h), a		; Save response character
		ld	hl, rx_packet_resp_table2 ; Search secondary response table
		ld	bc, 4			; 4 table entries
		cpir				; Search for match
		jp	z, dispatch_table_jump	; Dispatch to matching handler

rx_resp_tbl2_fe:
		ld	a, (26E2h)		; Check previous error status (26E2h)
		cp	18h			; Was it CAN?
		jp	z, rx_resp_timeout_abort ; If double CAN, abort transfer
		jr	rx_packet_resp_nak	; Otherwise continue polling for response

tx_packet_ack_next:
		ld	hl, 269Fh		; HL points to retry error counter (269Fh)
		inc	(hl)			; Increment error count
		call	print_error_count	; Display error count on console
		ld	a, (269Fh)		; Load current retry error count
		cp	5			; Maximum 5 retries allowed
		jp	c, tx_zmodem_file_step_2 ; If < 5 retries, retransmit packet
		ld	a, 0FFh			; Retries exhausted: set error code
		scf				; Set carry flag (transfer failed)
		ret				; Return

;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : tx_wait_zrinit
; Purpose  : Wait for ZRINIT frame from receiver and negotiate protocol options
; Inputs   : None
; Outputs  : Receiver capabilities negotiated
; Modifies : All registers
;============================================================================
tx_wait_zrinit:
		ld	a, 11			; Maximum 11 retries for ZRINIT handshake
		ld	(zrinit_retry_counter), a ; Initialize retry counter (26F8h)
tx_wait_zrinit_loop:
		ld	hl, zrinit_retry_counter ; Decrement remaining retry attempts
		dec	(hl)
		ld	a, 0FFh			; Set abort error code
		scf				; Set carry flag (error)
		ret	z			; Retries exhausted, abort
		call	rx_header_search	; Wait for incoming Zmodem frame header
		ld	hl, zrinit_resp_table	; Response dispatch table (6 entries)
		ld	bc, 6			; 6 table entries
		cpir				; Search for matching frame type
		jp	z, dispatch_table_jump	; Dispatch to corresponding handler
zrinit_resp_ack_nak:
		ld	a, 6			; Frame type 6 = ZACK (or ACK response)
		call	tx_hex_header		; Transmit ZACK hex header
		jr	tx_wait_zrinit_loop	; Continue waiting for valid ZRINIT

zrinit_resp_zrqinit:
		ld	hl, rx_hdr_flags	; HL points to incoming header flags
		ld	de, tx_hdr_flags	; DE points to outgoing header flags
		call	copy_4bytes		; Echo back received flags
		ld	a, 3			; Frame type 3 = ZACK
		call	tx_hex_header		; Transmit ZACK hex header
		jr	tx_wait_zrinit_loop	; Continue waiting

zrinit_resp_fe:
		ld	hl, tx_hdr_flags	; HL points to outgoing header flags
		call	clear_4bytes		; Clear 4 flag bytes
		ld	a, 0			; Frame type 0 = ZRQINIT
		call	tx_hex_header		; Transmit ZRQINIT to prompt receiver
		jr	tx_wait_zrinit_loop	; Continue waiting

zrinit_resp_zrinit:
		ld	ix, rx_hdr_flags	; IX points to received ZRINIT header flags
		ld	a, (ix+3)		; ZF0: receiver capabilities byte
		ld	(remote_zf0_flags), a	; Save receiver capabilities byte (26D4h)
		and	CANFC32			; Test if receiver supports 32-bit CRC (CANFC32 = 20h)
		ld	(remote_can_flags), a	; Update 32-bit CRC capability flag (26A9h)
		ld	a, (remote_zf0_flags)	; Reload capabilities byte
		and	ESCCTL			; Test if receiver requested control char escape (ESCCTL = 40h)
		ld	(esc_ctrl_chars_flag), a ; Set escape control characters flag (26D5h)
		ld	l, (ix+0)		; Load receiver buffer/window size (low byte)
		ld	h, (ix+1)		; Load receiver buffer/window size (high byte)
		ld	(remote_rx_buf_size), hl ; Save remote window size (26CBh)
		ld	a, h			; Check if receiver specified window limit
		or	l
		jr	nz, zrinit_have_bufsize ; If non-zero, use receiver's window size
		ld	a, (cmd_window_param)	; Otherwise use command-line window parameter
		rla				; Scale to buffer byte count (* 1024)
		rla	
		ld	h, a			; High byte of window size
		ld	l, 0			; Low byte = 0
		ld	(remote_rx_buf_size), hl ; Store window size limit
zrinit_have_bufsize:
		ld	hl, 400h		; Default subpacket length = 1024 (400h) bytes
		ld	(tx_subpacket_size), hl	; Set tx_subpacket_size (26CFh)
		xor	a			; Clear carry (success)
		ret				; Return

zrinit_resp_can:
		ld	a, 0FFh			; Receiver sent CAN: abort session
		scf				; Set carry flag (error)
		ret				; Return

zrinit_resp_challenge:
		ld	ix, rx_hdr_flags	; IX points to received flags
		ld	a, (ix+3)		; Check challenge type byte
		cp	12h			; Compare with 12h
		jp	z, tx_wait_zrinit_loop	; If matched, wait for next header
		jp	zrinit_resp_ack_nak	; Otherwise send ACK/NAK response

zrinit_resp_table:
		.db	0Eh			; 14 (ZCHALLENGE)
		.db	12h			; 18 (ZCOMMAND)
		.db	1			; 1 (ZRINIT)
		.db	10h			; 16 (ZCAN)
		.db	0FEh			; Line error
		.db	0			; 0 (ZRQINIT)

zrinit_resp_vectors:
		.dw	zrinit_resp_challenge
		.dw	zrinit_resp_can
		.dw	zrinit_resp_can
		.dw	zrinit_resp_zrinit
		.dw	zrinit_resp_fe
		.dw	zrinit_resp_zrqinit
;----------------------------------------------------------------------------

tx_data_subpac_call_1:
; SMC WRITER: Patches immediate operand of ld bc, imm at tx_set_window_bc (tx_window_size)
		ld	(tx_window_size), de	; Save header payload byte count into SMC operand
		ld	hl, file_pos_curr	; HL = file_pos_curr (26B7h)
		call	clear_4bytes		; Clear initial 32-bit file position to 0
tx_data_subpac_loop:
		ld	ix, tx_hdr_flags	; IX points to outgoing frame header flags (26AAh)
		ld	a, (26EEh)		; Check command-line binary transfer switch
		cp	0FFh			; Is binary transfer active?
		ld	a, 1			; ZF0 = 1 (ZCBIN: binary transfer)
		jr	z, tx_data_subpac_step_1 ; If binary, set ZF0
		ld	a, (26EDh)		; Check command-line ASCII text conversion switch
		cp	0FFh			; Is text conversion active?
		ld	a, 2			; ZF0 = 2 (ZCNL: convert end-of-line)
		jr	z, tx_data_subpac_step_1 ; If text, set ZF0
		xor	a			; Default ZF0 = 0 (standard transfer)

tx_data_subpac_step_1:
		ld	(ix+3), a		; Store ZF0 into header flag byte 3
		ld	a, (26EBh)		; Check command-line crash recovery switch
		cp	0FFh			; Is crash recovery active?
		ld	a, 7			; ZF1 = 7 (ZCRECOV: recover interrupted transfer)
		jr	z, tx_data_subpac_step_2 ; If recover, set ZF1
		ld	a, (26ECh)		; Check command-line file overwrite switch
		cp	0FFh			; Is overwrite active?
		ld	a, 3			; ZF1 = 3 (ZCLOB: overwrite destination)
		jr	z, tx_data_subpac_step_2 ; If overwrite, set ZF1
		xor	a			; Default ZF1 = 0

tx_data_subpac_step_2:
		ld	(ix+2), a		; Store ZF1 into header flag byte 2
		xor	a			; Clear A
		ld	(ix+1), a		; ZF2 = 0
		ld	(ix+0), a		; ZF3 = 0
		ld	a, 4			; Frame type 4 = ZFILE
		call	tx_bin_header		; Transmit ZFILE binary header
;----------------------------------------------------------------------------

;============================================================================
; Region 2 : ZMODEM Streaming Engine & Protocol State Machine (0CD1h - 10C4h)
; Handles ZDATA packet streaming, dynamic window flow control, ACK polling,
; ZRPOS repositioning, buffer re-seeking, and file EOF processing.
;============================================================================

;----------------------------------------------------------------------------
; tx_set_window_bc
; Self-modifying immediate parameter loaded with window size from caller.
;----------------------------------------------------------------------------
tx_set_window_bc:
; SMC TARGET: Patched by ld (tx_window_size), de at tx_data_subpac_call_1 above
tx_window_size:	.equ	$+1		; SMC: payload length operand
		ld	bc, 0000h		; BC = payload byte count (dynamically patched)
		ld	a, ZCRCW		; Framing char ZCRCW (6Bh: wait for ACK)
		call	tx_data_subpacket	; Transmit ZFILE data subpacket with ZCRCW

tx_wait_data_ack:
		call	rx_header_search	; Wait for receiver response header
		ld	hl, tx_zrinit_resp_table ; Match response frame types
		ld	bc, 8			; 8 table entries
		cpir				; Search table
		jp	z, dispatch_table_jump	; Dispatch to response handler
		jr	tx_data_subpac_loop	; Retry ZFILE transmission

tx_drain_until_sync:
		ld	b, 32h			; Timeout = 50 character cycles
		call	comm_rx_char_filtered	; Read character
		jr	c, tx_data_subpac_loop	; On timeout, retry ZFILE transmission
		cp	'*'			; ZPAD frame synchronization character?
		jr	z, tx_wait_data_ack	; If sync found, read header frame
		jr	tx_drain_until_sync	; Drain until sync byte found

tx_resp_err_abort:
		ld	a, 0FFh			; Fatal error abort
		scf				; Set carry flag (error)
		ret				; Return

tx_resp_retry_ack:
		jp	tx_wait_data_ack	; Retry waiting for ACK

tx_resp_ret_cancel:
		ld	a, 5			; Return code 5 (receiver skipped / canceled)
		ret				; Return

tx_zrinit_reposition:
		ld	hl, rx_hdr_pos		; HL points to position received in ZRINIT/ZRPOS
		ld	de, rpos_target_pos	; DE points to rpos_target_pos (26FAh)
		call	copy_4bytes		; Store requested file position
		call	tx_seek_and_fill_window ; Seek file and reload transmit buffer
		ret	c			; If seek error, abort
		ld	hl, rx_hdr_pos		; Update all streaming position trackers
		ld	de, tx_pos_base		; tx_pos_base (26AFh)
		call	copy_4bytes
		ld	de, file_pos_curr	; file_pos_curr (26B7h)
		call	copy_4bytes
		ld	de, file_pos_sent	; file_pos_sent (26BBh)
		call	copy_4bytes
		ld	de, file_pos_acked	; file_pos_acked (26BFh)
		call	copy_4bytes
		ex	de, hl			; HL points to file_pos_acked
		call	dec32			; Decrement position to force initial window check
		jp	tx_stream_data_blocks	; Begin streaming file data blocks

;----------------------------------------------------------------------------
; Table 1: tx_zrinit_resp_table
; Matches incoming header types during initial data ACK wait.
;----------------------------------------------------------------------------
tx_zrinit_resp_table:
		.db	ZRINIT, ZCAN, 0FEh, ZABORT, ZFIN, ZCRC, ZSKIP, ZRPOS
		.dw	tx_zrinit_reposition	; ZRINIT (01h) -> seek and re-align
		.dw	tx_resp_ret_cancel	; ZCAN   (10h) -> cancel error
		.dw	tx_resp_retry_ack	; 0FEh   (timeout/framing err) -> retry
		.dw	tx_resp_err_abort	; ZABORT (07h) -> abort
		.dw	tx_resp_err_abort	; ZFIN   (08h) -> abort
		.dw	tx_resp_err_abort	; ZCRC    (0Dh) -> abort
		.dw	tx_resp_err_abort	; ZSKIP  (05h) -> abort
		.dw	tx_drain_until_sync	; ZRPOS  (09h) -> drain and re-sync

;----------------------------------------------------------------------------
; tx_stream_data_blocks
; Main streaming entry point: resets errors and starts sending ZDATA frames.
;----------------------------------------------------------------------------
tx_stream_data_blocks:
		xor	a			; Clear consecutive error counter
		ld	(consecutive_errors), a ; consecutive_errors (26D3h)
		ld	(retry_err_counter), a	; retry_err_counter (269Fh)

tx_stream_start_data:
		jp	tx_prepare_zdata	; Prepare ZDATA frame header and stream data

tx_stream_wait_ack:
		xor	a			; Reset window packet counter
		ld	(tx_window_packet_count), a ; tx_window_packet_count (26F9h)
		ld	a, 0FFh			; Wait for incoming header frame
		call	tx_wait_header_or_sync ; Poll for frame header

tx_check_stream_resp:
		ld	hl, tx_stream_resp_table ; Match stream response frame types
		ld	bc, 5			; 5 entries in table
		cpir				; Search response table
		jp	z, dispatch_table_jump	; Dispatch to handler

tx_stream_err_abort:
		ld	a, 0FFh			; Set error status
		scf				; Set carry flag (abort)
		ret				; Return

tx_stream_rpos_resp:
		ld	a, 5			; Return code 5 (receiver skip/reposition)
		ret				; Return

tx_stream_can_resp:
		xor	a			; Clear carry (normal completion)
		ret				; Return

;----------------------------------------------------------------------------
; Table 2: tx_stream_resp_table
; Matches responses received while streaming data packets.
;----------------------------------------------------------------------------
tx_stream_resp_table:
		.db	ZCAN, ZSKIP, ZACK, ZRPOS, ZRINIT
		.dw	tx_stream_can_resp	; ZCAN  (10h) -> normal exit
		.dw	tx_stream_drain_loop	; ZSKIP (05h) -> drain and retry
		.dw	tx_stream_nak_resp	; ZACK  (03h) -> clear errors
		.dw	tx_stream_rpos_resp	; ZRPOS (09h) -> reposition
		.dw	tx_stream_err_abort	; ZRINIT (01h) -> fatal error

tx_stream_nak_resp:
		xor	a			; Reset retry error counter on valid ACK
		ld	(retry_err_counter), a	; retry_err_counter (269Fh)

tx_stream_drain_loop:
		call	rx_buffer_poll		; Any bytes pending in serial receiver?
		jr	z, tx_prepare_zdata	; If receiver empty, continue sending data
		ld	b, 0Ah			; Short timeout for draining input
		call	comm_rx_char_filtered	; Read pending character

tx_stream_drain_dispatch:
		ld	hl, tx_drain_char_table ; Search drain character match table
		ld	bc, 5			; 5 entries
		cpir				; Search table
		jr	nz, tx_stream_drain_loop ; If not recognized, keep draining
		jp	dispatch_table_jump	; Dispatch to drain handler

tx_drain_resp_sync:
		ld	a, 000h			; Sync found, wait for full header
		call	tx_wait_header_or_sync
		jp	tx_check_stream_resp	; Check received header type

tx_drain_resp_drain:
		ld	b, 64h			; Drain 100 character cycles
		call	comm_rx_char_filtered	; Read character
		jr	tx_stream_drain_dispatch ; Re-dispatch on drained character

;----------------------------------------------------------------------------
; Table 3: tx_drain_char_table
; Character match table during serial drain polling.
;----------------------------------------------------------------------------
tx_drain_char_table:
		.db	0FEh, 18h, 2Ah, 13h, 93h
		.dw	tx_drain_resp_drain	; 0FEh (timeout) -> drain more
		.dw	tx_drain_resp_drain	; 18h  (CAN) -> drain
		.dw	tx_drain_resp_sync	; 2Ah  ('*') -> sync found
		.dw	tx_drain_resp_sync	; 13h  (DC3/XOFF) -> sync
		.dw	tx_stream_err_abort	; 93h  (XOFF|80h) -> error

;----------------------------------------------------------------------------
; tx_prepare_zdata
; Initiates ZDATA frame header transmission with current file position.
;----------------------------------------------------------------------------
tx_prepare_zdata:
		ld	hl, (remote_rx_buf_size) ; Load remote receiver window size
		ld	(rx_window_remaining), hl ; Initialize remaining window space (26CDh)
		ld	hl, file_pos_curr	; HL points to current file position (26B7h)
		ld	de, tx_hdr_flags	; DE points to outgoing header flags
		call	copy_4bytes		; Set frame position = current file position
		ld	a, ZDATA		; Frame type 10 = ZDATA (0Ah)
		call	tx_bin_header		; Transmit ZDATA binary header

tx_stream_next_chunk:
		call	tx_get_chunk_size	; Determine size of next data chunk to send
		ret	c			; Return on error
		ld	(tx_curr_chunk_size), hl ; Save current chunk size (2702h)
		ld	a, (tx_eof_flag)	; Has end of file been reached?
		cp	0FFh			; Check EOF flag (26D6h)
		jr	nz, tx_stream_check_window ; If not EOF, check window limits
		ld	a, ZCRCE		; Framing char ZCRCE (68h: frame end, no ACK)
		ld	(curr_framing_char), a	; Store delimiter character (26D8h)
		jp	tx_stream_send_subpacket ; Send final subpacket

tx_stream_check_window:
		ld	a, (tx_window_packet_count) ; Load packets sent in current window
		cp	4			; Maximum 4 consecutive packets without wait
		jr	c, tx_stream_check_pos	; If < 4, check window position limits

tx_stream_force_wait:
		ld	a, ZCRCW		; Framing char ZCRCW (6Bh: wait for ACK)
		ld	(curr_framing_char), a	; Force wait for receiver ACK
		jp	tx_stream_send_subpacket

tx_stream_check_pos:
		ld	hl, file_pos_sent	; Compare sent position against acknowledged
		ld	de, file_pos_acked
		call	cmp_4bytes_eq		; Are positions equal?
		jr	z, tx_stream_force_wait	; If unacked, force wait
		ld	hl, (remote_rx_buf_size) ; Load remote window size
		ld	a, h			; Check if window is unlimited (0)
		or	l
		jr	z, tx_stream_use_zcrcg	; Unlimited buffer: stream continuously (ZCRCG)
		ld	hl, (rx_window_remaining) ; Load remaining window space
		ld	de, (tx_curr_chunk_size) ; Deduct current chunk size
		sbc	hl, de
		ld	(rx_window_remaining), hl ; Update remaining window space
		jr	z, tx_stream_force_wait	; If window full, wait for ACK
		jr	c, tx_stream_force_wait	; If window exhausted, wait for ACK

tx_stream_use_zcrcg:
		ld	a, ZCRCG		; Framing char ZCRCG (69h: stream data, no wait)
		ld	(curr_framing_char), a	; Set delimiter character

tx_stream_send_subpacket:
		ld	a, (curr_framing_char)	; A = subpacket delimiter
		ld	bc, (tx_curr_chunk_size) ; BC = subpacket payload length
		call	tx_data_subpacket	; Stream data subpacket over serial line
		ld	de, tx_curr_chunk_size	; Advance file position by chunk size
		ld	hl, file_pos_curr
		ld	bc, file_pos_curr
		call	add32			; file_pos_curr += chunk_size
		ld	hl, file_pos_curr	; Update file_pos_sent
		ld	de, file_pos_sent
		call	copy_4bytes
		ld	a, (curr_framing_char)	; Check if delimiter was ZCRCW
		cp	ZCRCW
		jp	z, tx_stream_wait_ack	; If ZCRCW, wait for receiver ACK

tx_stream_poll_inbound:
		call	rx_buffer_poll		; Inbound bytes received during stream?
		jr	z, tx_stream_check_eof	; No bytes, check EOF condition
		ld	b, 0Ah			; Short timeout
		call	comm_rx_char_filtered	; Read received byte

tx_stream_poll_dispatch:
		ld	hl, tx_poll_resp_table	; Match inbound character table
		ld	bc, 5			; 5 entries
		cpir				; Search table
		jp	z, dispatch_table_jump	; Dispatch to handler
		ld	hl, tx_window_packet_count ; Increment window packet counter
		inc	(hl)
		jr	tx_stream_poll_inbound	; Poll next character

tx_poll_resp_sync:
		ld	a, 000h			; Read incoming header frame
		call	tx_wait_header_or_sync
		cp	3			; Is frame type ZACK (3)?
		jr	z, tx_stream_check_eof	; If ZACK, continue streaming
		push	af			; Preserve frame type

tx_poll_drain_rx_loop:
		ld	hl, nstack		; Clear statistics block
		call	clear_6_bytes
		call	rx_buffer_poll		; Check for remaining incoming bytes
		jr	nz, tx_poll_drain_rx_loop ; Drain until empty
		ld	a, ZCRCE		; Send empty ZCRCE subpacket
		ld	bc, 0000h
		call	tx_data_subpacket
		pop	af			; Restore frame type
		jp	tx_check_stream_resp	; Process response frame

tx_poll_resp_drain:
		ld	b, 64h			; Timeout = 100 character cycles
		call	comm_rx_char_filtered	; Read character
		ld	hl, tx_window_packet_count
		inc	(hl)
		jr	tx_stream_poll_dispatch

;----------------------------------------------------------------------------
; Table 4: tx_poll_resp_table
; Matches inbound serial characters during active packet streaming.
;----------------------------------------------------------------------------
tx_poll_resp_table:
		.db	0FEh, 18h, 2Ah, 13h, 93h
		.dw	tx_poll_resp_drain	; 0FEh -> drain
		.dw	tx_poll_resp_drain	; 18h  -> drain
		.dw	tx_poll_resp_sync	; 2Ah  -> sync
		.dw	tx_poll_resp_sync	; 13h  -> flow control XOFF
		.dw	tx_stream_err_abort	; 93h  -> fatal error

tx_stream_check_eof:
		ld	a, (tx_eof_flag)	; Check if end of file reached
		cp	0FFh
		jp	nz, tx_stream_next_chunk ; If not EOF, stream next chunk

tx_send_zeof_frame:
		ld	hl, file_pos_curr	; HL points to current file position
		ld	de, tx_hdr_flags	; DE points to outgoing header flags
		call	copy_4bytes		; Store final file size in header
		ld	a, ZEOF			; Frame type 11 = ZEOF (0Bh)
		call	tx_bin_header		; Transmit ZEOF binary header
		ld	a, 0FFh			; Wait for receiver response
		call	tx_wait_header_or_sync
		ld	hl, tx_eof_resp_table	; Match response frame types: ZACK, ZRPOS, ZRINIT, ZSKIP
		ld	bc, 4			; 4 entries
		cpir				; Search response table
		jp	z, dispatch_table_jump	; Dispatch to handler
		ld	a, 0FFh			; Unexpected response, abort
		scf				; Set carry flag (error)
		ret				; Return

tx_eof_resp_skip:
		jr	tx_send_zeof_frame	; Retry sending ZEOF frame

tx_eof_resp_zrinit:
		jp	tx_stream_start_data	; ZRINIT received, restart streaming

tx_eof_resp_rpos:
		xor	a			; Clear carry (success)
		ret				; Return

tx_eof_resp_nak:
		ret				; Return

;----------------------------------------------------------------------------
; Table 5: tx_eof_resp_table
; Matches receiver responses to ZEOF frame.
;----------------------------------------------------------------------------
tx_eof_resp_table:
		.db	ZACK, ZRPOS, ZRINIT, ZSKIP
		.dw	tx_eof_resp_nak		; ZACK   (03h)
		.dw	tx_eof_resp_rpos	; ZRPOS  (09h)
		.dw	tx_eof_resp_zrinit	; ZRINIT (01h)
		.dw	tx_eof_resp_skip	; ZSKIP  (05h)

;----------------------------------------------------------------------------
; tx_wait_header_or_sync
; Waits for incoming header frame, with self-modifying sync-check operand.
;----------------------------------------------------------------------------
tx_wait_header_or_sync:
; SMC WRITER: Patches immediate operand of ld a, imm at patch_sync_op below
		ld	(patch_sync_op), a	; Store mode into SMC operand

tx_search_header_loop:
		call	rx_header_search	; Search for incoming header frame
		ld	hl, tx_rpos_resp_table	; Response dispatch table (9 entries)
		ld	bc, 9			; 9 entries
		cpir				; Search table
		jp	z, dispatch_table_jump	; Dispatch to handler

tx_rpos_resp_can:
		ld	a, 6			; Frame type 6 = ZACK
		call	tx_bin_header		; Transmit ZACK response header
		jr	tx_search_header_loop	; Continue waiting for header

tx_rpos_resp_abort:
		ret				; Abort return

tx_rpos_resp_fin:
		push	af			; Preserve AF
		call	cpm_bdos_open_file	; Close active file
		pop	af			; Restore AF
		ret				; Return

tx_rpos_resp_timeout:
		ld	de, tx_pos_base		; DE points to tx_pos_base (26AFh)
		ld	hl, rx_hdr_pos		; HL points to rx_hdr_pos (26B3h)
		call	copy_4bytes		; Save received position
; SMC TARGET: Patched by ld (patch_sync_op), a at tx_wait_header_or_sync above
patch_sync_op:	.equ	$+1		; SMC: sync mode operand
		ld	a, 000h			; Dynamically patched sync mode
		cp	000h			; Compare with 0
		ld	a, 3			; Return code 3
		ret	z			; If mode 0, return code 3
		ld	de, file_pos_curr	; Compare received position against file_pos_curr
		ld	hl, rx_hdr_pos
		call	cmp_4bytes_eq		; Are positions identical?
		ld	a, 3
		ret	z			; If equal, return code 3
		jp	tx_search_header_loop	; Otherwise continue searching

tx_rpos_resp_rpos:
		ld	hl, rx_hdr_pos		; HL points to requested position from ZRPOS
		ld	de, rpos_target_pos	; DE points to rpos_target_pos (26FAh)
		call	copy_4bytes		; Save reposition target
		call	tx_seek_and_fill_window ; Seek file and re-align circular buffer
		ret	c			; If seek error, return
		ld	a, 000h			; Clear EOF flag
		ld	(tx_eof_flag), a	; tx_eof_flag (26D6h)
		ld	hl, retry_err_counter	; Increment retry error counter
		inc	(hl)
		call	print_error_count	; Display error count on console
		ld	hl, rx_hdr_pos		; Update current position trackers
		ld	de, file_pos_curr	; file_pos_curr (26B7h)
		call	copy_4bytes
		ld	de, tx_pos_base		; tx_pos_base (26AFh)
		call	copy_4bytes
		ld	de, file_pos_sent	; file_pos_sent (26BBh)
		call	copy_4bytes
		ld	de, file_pos_acked	; Compare against previously acked position
		call	cmp_4bytes_eq		; Did error occur at new position?
		jr	nz, tx_rpos_reduce_packet_size ; If new position, keep packet size
		ld	a, (consecutive_errors) ; Load consecutive errors at same position
		inc	a			; Increment consecutive error count
		ld	(consecutive_errors), a ; Update consecutive_errors (26D3h)
		cp	5			; 5 consecutive errors at same position?
		jr	c, tx_rpos_reduce_packet_size ; If < 5, keep packet size
		ld	hl, CANFC32		; Minimum packet size (32 bytes)
		ld	de, (tx_subpacket_size) ; Current packet size
		or	a
		sbc	hl, de			; Is current size already at minimum (32 bytes)?
		jr	nc, tx_rpos_reduce_packet_size ; If at minimum, cannot reduce
		srl	d			; Halve packet size (DE = DE / 2)
		rr	e
		ld	(tx_subpacket_size), de ; Store reduced subpacket size (26CFh)

tx_rpos_reduce_packet_size:
		ld	hl, rx_hdr_pos		; Update file_pos_acked
		ld	de, file_pos_acked
		call	copy_4bytes
		ld	a, 9			; Return code 9 (ZRPOS reposition handled)
		ret				; Return

tx_rpos_resp_error:
		ld	a, 0FFh			; Set error status
		scf				; Set carry flag (error)
		ret				; Return

;----------------------------------------------------------------------------
; Table 6: tx_rpos_resp_table
; Matches incoming frame header types in response to wait loop.
;----------------------------------------------------------------------------
tx_rpos_resp_table:
		.db	ZCAN, ZABORT, ZFIN, 0FEh, ZRPOS, ZACK, ZRINIT, ZSKIP, 0FFh
		.dw	tx_rpos_resp_can	; ZCAN   (10h)
		.dw	tx_rpos_resp_abort	; ZABORT (07h)
		.dw	tx_rpos_resp_fin	; ZFIN   (08h)
		.dw	tx_rpos_resp_timeout	; 0FEh   (timeout)
		.dw	tx_rpos_resp_rpos	; ZRPOS  (09h)
		.dw	tx_rpos_resp_error	; ZACK   (03h)
		.dw	tx_rpos_resp_error	; ZRINIT (01h)
		.dw	tx_rpos_resp_error	; ZSKIP  (05h)
		.dw	tx_rpos_resp_error	; 0FFh   (framing error)

;----------------------------------------------------------------------------
; tx_seek_and_fill_window
; Seeks to requested position in buffer or rewinds and re-reads file.
;----------------------------------------------------------------------------
tx_seek_and_fill_window:
		ld	hl, file_pos_buf	; HL = file_pos_buf (26C3h)
		ld	de, file_pos_align_base ; DE = file_pos_align_base (26F3h)
		ld	bc, temp_pos_32		; BC = temp_pos_32 (26C7h)
		call	sub32			; temp_pos_32 = file_pos_buf - buffer_size
		ld	hl, rpos_target_pos	; HL = target position
		ld	de, temp_pos_32		; DE = buffer lower boundary
		call	cmp_pos32		; Compare target against buffer lower boundary
		jp	nc, tx_seek_check_upper_window ; If target >= lower bound, check upper bound
		ld	a, 000h			; Target is before current buffer window: must rewind
		ld	(file_read_eof_flag), a ; Clear EOF flag (26D7h)
		ld	hl, rpos_target_pos	; HL = target position
		ld	de, 084Eh		; DE = window alignment mask address (084Eh)
		ld	bc, tx_window_align_pos ; BC = tx_window_align_pos (26FEh)
		call	and32			; Align target position to buffer boundary
		ld	hl, tx_window_align_pos ; HL = aligned target position
		call	tx_seek_rewind_read	; Rewind file and read forward to aligned position
		ret	c			; If error, return
		ld	hl, tx_window_align_pos ; Set window offset
		ld	de, tx_window_offset	; tx_window_offset (26DCh)
		call	copy_4bytes
		ld	bc, (file_pos_align_base) ; Read full buffer capacity from file
		call	tx_fill_buf_from_file	; Fill transmit buffer
		ret	c			; If error, return
		xor	a			; Clear carry (success)
		ret				; Return

tx_seek_check_upper_window:
		ld	hl, file_pos_buf	; HL = file_pos_buf (26C3h)
		ld	de, 084Ah		; DE = 1024 bytes (084Ah)
		ld	bc, temp_pos_32		; BC = temp_pos_32 (26C7h)
		call	sub32			; temp_pos_32 = file_pos_buf - 1024
		ld	hl, temp_pos_32		; HL = buffer upper limit
		ld	de, rpos_target_pos	; DE = target position
		call	cmp_pos32		; Is target within available loaded buffer?
		jp	nc, tx_seek_window_ok	; If target already in buffer, no disk read needed!
		ld	a, 000h			; Target lies beyond loaded buffer: seek forward
		ld	(file_read_eof_flag), a ; Clear EOF flag (26D7h)
		ld	hl, rpos_target_pos	; Align target position
		ld	de, 084Eh		; Window mask address
		ld	bc, tx_window_align_pos
		call	and32
		ld	hl, tx_window_align_pos ; Seek file forward to target
		call	tx_seek_read_forward
		ret	c
		ld	hl, tx_window_align_pos ; Update window offset
		ld	de, tx_window_offset
		call	copy_4bytes
		ld	bc, (file_pos_align_base) ; Refill circular transmit buffer
		call	tx_fill_buf_from_file
		ret	c
		xor	a			; Clear carry (success)
		ret				; Return

tx_seek_window_ok:
		xor	a			; Target position already resident in buffer: success
		ret				; Return

tx_seek_read_forward:
		ex	de, hl			; DE = target position
		ld	hl, file_pos_buf	; HL = current loaded file position
		jr	tx_seek_read_loop	; Read forward until target reached

tx_seek_rewind_read:
		call	cpm_bdos_open_file	; Close active file
		ld	de, tx_file_fcb		; DE points to FCB
		call	cpm_bdos_read_record	; Reopen file from record 0
		ex	de, hl			; DE = target position
		ld	hl, file_pos_buf	; Reset file_pos_buf to 0
		call	clear_4bytes

tx_seek_read_loop:
		call	cmp_4bytes_eq		; Have we reached the target position?
		ret	z			; If equal, seek complete!
		call	file_read_byte_buffered ; Read next byte from file
		jr	nz, tx_seek_read_err	; On read error or EOF, handle error
		call	inc32			; Increment current loaded position
		jr	tx_seek_read_loop	; Continue seeking

tx_seek_read_err:
		xor	004h			; Check for CP/M EOF (Ctrl-Z / status 4)
		ret	z			; If EOF, return
		ld	a, 0FFh			; Read error abort
		scf				; Set carry flag (error)
		ret				; Return

;----------------------------------------------------------------------------
; tx_get_chunk_size
; Determines length of next chunk to transmit from circular buffer.
;----------------------------------------------------------------------------
tx_get_chunk_size:
		ld	hl, tx_curr_chunk_size	; Clear current chunk size buffer (2702h)
		call	clear_4bytes
		ld	hl, file_pos_sent	; HL = file_pos_sent (26BBh)
		ld	de, tx_buf_mask		; DE = circular buffer wrap mask (26DAh)
		ld	bc, tx_window_offset	; BC = tx_window_offset (26DCh)
		call	and32			; tx_window_offset = file_pos_sent AND tx_buf_mask
		ld	hl, file_pos_sent	; Compare sent position against loaded position
		ld	de, file_pos_buf	; file_pos_buf (26C3h)
		call	cmp_pos32
		jp	c, tx_chunk_calc_remaining ; If sent < loaded, data already in buffer
		ld	bc, (tx_subpacket_size) ; Need more data: read subpacket size from disk
		call	tx_fill_buf_from_file	; Fill transmit buffer from file
		ret	c			; Return on disk error
		ld	a, (file_read_eof_flag) ; Copy file reader EOF flag to transmit EOF flag
		ld	(tx_eof_flag), a	; tx_eof_flag (26D6h)
		ex	de, hl			; Return with chunk size in HL
		ret				; Return

tx_chunk_calc_remaining:
		ld	hl, file_pos_sent	; HL = file_pos_sent
		ld	de, tx_subpacket_size	; DE = subpacket size (26CFh)
		ld	bc, temp_pos_32		; temp_pos_32 = file_pos_sent + subpacket_size
		call	add32
		ld	hl, file_pos_buf	; Compare loaded buffer against sent + size
		ld	de, temp_pos_32
		call	cmp_pos32
		jp	c, tx_chunk_use_subpacket_size ; If loaded < sent + size, partial chunk at EOF
		ld	hl, (tx_subpacket_size) ; Full subpacket size available
		ret				; Return

tx_chunk_use_subpacket_size:
		ld	a, (file_read_eof_flag) ; File reader reached EOF
		ld	(tx_eof_flag), a	; Set tx_eof_flag
		ld	hl, file_pos_buf	; Calculate remaining bytes: loaded - sent
		ld	de, file_pos_sent
		ld	bc, temp_pos_32
		call	sub32			; temp_pos_32 = file_pos_buf - file_pos_sent
		ld	hl, (temp_pos_32)	; Return remaining partial byte count in HL
		ret				; Return

;----------------------------------------------------------------------------
; tx_fill_buf_from_file
; Reads BC bytes from file into circular transmit buffer.
; Inputs: BC = byte count to read
;----------------------------------------------------------------------------
tx_fill_buf_from_file:
		ld	de, 0000h		; Initialize buffer write offset = 0

tx_fill_buf_loop:
		call	get_tx_buf_byte		; HL = pointer into circular buffer for offset DE
		call	file_read_byte_buffered ; Read next byte from buffered file stream
		jr	nz, tx_fill_buf_eof	; If error or EOF, handle EOF exit
		ld	(hl), a			; Store byte into circular transmit buffer
		ld	hl, file_pos_buf	; Increment 32-bit loaded position
		call	inc32			; file_pos_buf++
		inc	de			; Increment window write offset
		dec	bc			; Decrement requested read byte count
		ld	a, b			; Check if all bytes read
		or	c
		jr	nz, tx_fill_buf_loop	; Loop until entire block is loaded
		ret				; Return

tx_fill_buf_eof:
		cp	004h			; CP/M EOF status (Ctrl-Z / status 4)?
		ld	a, 0FFh			; A = 0FFh (EOF flag)
		ld	(file_read_eof_flag), a ; Set file_read_eof_flag (26D7h)
		ret	z			; If normal EOF, return with NC
		scf				; Set carry flag (disk read error)
		ret				; Return
;============================================================================
; Function : get_tx_buf_byte
; Purpose  : Calculate memory pointer in circular transmit buffer for offset DE
; Inputs   : DE = offset within current transmit window
; Outputs  : HL = pointer to buffer byte
; Modifies : A, HL
;============================================================================
get_tx_buf_byte:
		push	bc			; Preserve BC
		push	de			; Preserve DE
		ld	hl, (tx_window_offset)	; HL = current transmit window buffer offset (26DCh)
		add	hl, de			; Add offset DE
		ld	bc, (tx_buf_mask)	; BC = circular buffer wrap mask (26DAh)
		ld	a, h			; Apply mask high byte
		and	b
		ld	h, a
		ld	a, l			; Apply mask low byte
		and	c
		ld	l, a
		ld	de, (tx_buf_base_addr)	; DE = base address of transmit data buffer in RAM
		add	hl, de			; HL = absolute memory address of byte slot
		pop	de			; Restore DE
		pop	bc			; Restore BC
		ret				; Return

;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
;============================================================================
; Function : tx_zfin_session_finish
; Purpose  : Send ZFIN (finish) frame and await remote ZFIN response
; Inputs   : None
; Outputs  : Remote session terminated cleanly, 'OO' sent
; Modifies : All registers
;============================================================================
tx_zfin_session_finish:
		ld	hl, tx_hdr_flags	; Clear outgoing frame header flags (26AAh)
		call	clear_4bytes
		ld	a, 8			; Frame type 8 = ZFIN (finish session)
		call	tx_hex_header		; Transmit ZFIN hex header
		call	rx_header_search	; Await receiver response
		ret	c			; Return on timeout / error
		cp	10h			; Frame type 16 = ZCAN (abort)?
		ret	z			; If ZCAN, return
		cp	8			; Frame type 8 = ZFIN response?
		jr	nz, tx_zfin_session_finish ; If not ZFIN, re-send ZFIN
		ld	a, 'O'			; 'O' (4Fh)
		call	comm_tx_char_wait	; Transmit first 'O' over serial
		ld	a, 'O'			; 'O' (4Fh)
		jp	comm_tx_char_wait	; Transmit second 'O' ("OO" over and out)
; End of function tx_zack_frame

;----------------------------------------------------------------------------
;============================================================================
; Function : tx_data_subpacket
; Purpose  : Stream data subpacket with CRC calculation and ZDLE escaping
; Inputs   : A  = framing character (ZCRCE, ZCRCG, ZCRCQ, ZCRCW)
;            BC = byte count to transmit
;            DE = offset within circular buffer
; Outputs  : Data subpacket streamed over serial link
; Modifies : All registers
;============================================================================
tx_data_subpacket:
		ld	(subpacket_framing_char), a ; Save delimiter (ZCRCE, ZCRCG, ZCRCQ, ZCRCW)
		push	bc			; Preserve payload length
		ld	hl, file_pos_curr	; Update transfer progress display
		ld	de, tx_progress_count	; tx_progress_count (26A4h)
		call	copy_4bytes
		call	print_transfer_stats	; Update console progress count
		pop	bc			; Restore payload length
		call	reset_crc_checksum	; Reset CRC and checksum accumulators
		ld	de, 0000h		; DE = initial circular buffer offset
		ld	a, (remote_can_flags)	; Check receiver CRC capability (26A9h)
		and	CANFC32			; Does receiver support 32-bit CRC (CANFC32 = 20h)?
		jr	nz, tx_subpacket_crc32	; If 32-bit CRC supported, use CRC-32 loop

tx_subpacket_crc16_loop:
		ld	a, b			; Test if all payload bytes sent
		or	c
		jr	z, tx_subpacket_crc16_end ; If done, send frame delimiter and CRC
		push	bc			; Preserve remaining byte count
		push	de			; Preserve buffer offset
		call	get_tx_buf_byte		; HL = memory address of payload byte in buffer
		ld	a, (hl)			; Load data byte
		call	crc16			; Update CRC-16 accumulator
		call	tx_zdle_escaped_char	; Transmit with ZDLE escape encoding
		pop	de			; Restore buffer offset
		pop	bc			; Restore byte count
		inc	de			; Advance offset
		dec	bc			; Decrement remaining byte count
		jr	tx_subpacket_crc16_loop	; Continue sending payload bytes

tx_subpacket_crc16_end:
		ld	a, ZDLE			; ZDLE escape character (18h)
		call	comm_tx_char_wait	; Transmit ZDLE escape prefix
		ld	a, (subpacket_framing_char) ; Load subpacket framing delimiter
		call	crc16			; Accumulate delimiter into CRC-16
		call	comm_tx_char_wait	; Transmit framing delimiter byte
		ld	a, (crc16_seed+2)	; Load CRC-16 high byte
		call	tx_zdle_escaped_char	; Transmit escaped CRC high byte
		ld	a, (crc16_seed+1)	; Load CRC-16 low byte
		call	tx_zdle_escaped_char	; Transmit escaped CRC low byte
		ld	a, (subpacket_framing_char) ; Check delimiter type
		cp	ZCRCW			; Was delimiter ZCRCW (wait for ACK)?
		ret	z			; If ZCRCW, return to caller to await ACK
		ld	a, 11h			; Otherwise send XON (11h) to ensure receiver continues
		jp	comm_tx_char_wait	; Transmit XON and return

tx_subpacket_crc32:
		ld	a, b			; Test if all payload bytes sent
		or	c
		jr	z, tx_subpacket_crc32_end ; If done, send delimiter and CRC-32
		push	bc			; Preserve remaining byte count
		push	de			; Preserve buffer offset
		call	get_tx_buf_byte		; HL = memory address of payload byte in buffer
		ld	a, (hl)			; Load data byte
		call	crc32_acc_update	; Update CRC-32 accumulator
		call	tx_zdle_escaped_char	; Transmit with ZDLE escape encoding
		pop	de			; Restore buffer offset
		pop	bc			; Restore byte count
		inc	de			; Advance offset
		dec	bc			; Decrement remaining byte count
		jr	tx_subpacket_crc32	; Continue sending payload bytes

tx_subpacket_crc32_end:
		ld	a, ZDLE			; ZDLE escape character (18h)
		call	comm_tx_char_wait	; Transmit ZDLE escape prefix
		ld	a, (subpacket_framing_char) ; Load subpacket framing delimiter
		call	crc32_acc_update	; Accumulate delimiter into CRC-32
		call	comm_tx_char_wait	; Transmit framing delimiter byte
		ld	b, 4			; 4 CRC-32 bytes to transmit
		ld	hl, crc32_acc_bytes	; HL points to 32-bit CRC accumulator
tx_subpacket_crc32_tx:
		ld	a, (hl)			; Load CRC byte
		inc	hl			; Advance pointer
		push	bc			; Preserve counter
		push	hl			; Preserve pointer
		cpl				; Invert bits (ones complement of CRC)
		call	tx_zdle_escaped_char	; Transmit escaped inverted CRC byte
		pop	hl			; Restore pointer
		pop	bc			; Restore counter
		djnz	tx_subpacket_crc32_tx	; Repeat for all 4 CRC-32 bytes
		ret				; Return
;----------------------------------------------------------------------------

tx_bin_header:
		ld	(tx_frame_type), a	; Save frame type byte (2707h)
		ld	a, ZPAD			; ZPAD character ('*' = 2Ah)
		call	comm_tx_char_wait	; Transmit ZPAD
		ld	a, ZDLE			; ZDLE character (18h)
		call	comm_tx_char_wait	; Transmit ZDLE
		call	reset_crc_checksum	; Reset CRC and checksum accumulators
		ld	a, (remote_can_flags)	; Check receiver CRC capability
		and	CANFC32			; Does receiver support 32-bit CRC?
		jp	nz, tx_bin_header_call_1 ; If 32-bit CRC, transmit ZBIN32 header
		ld	a, ZBIN			; Header encoding format ZBIN ('A' = 41h)
		call	comm_tx_char_wait	; Transmit format identifier
		ld	a, (tx_frame_type)	; Load frame type
		call	crc16			; Update CRC-16
		call	tx_zdle_escaped_char	; Transmit escaped frame type
		ld	hl, tx_hdr_flags	; HL points to 4 frame flag/position bytes
		ld	b, 4			; 4 bytes to transmit

tx_bin_header_step_1:
		push	bc			; Preserve counter
		ld	a, (hl)			; Load header flag byte
		inc	hl			; Advance pointer
		push	hl			; Preserve pointer
		call	crc16			; Update CRC-16
		call	tx_zdle_escaped_char	; Transmit escaped flag byte
		pop	hl			; Restore pointer
		pop	bc			; Restore counter
		djnz	tx_bin_header_step_1	; Repeat for all 4 bytes
		ld	a, (crc16_seed+2)	; Load CRC-16 high byte
		call	tx_zdle_escaped_char	; Transmit escaped CRC high byte
		ld	a, (crc16_seed+1)	; Load CRC-16 low byte
		jp	tx_zdle_escaped_char	; Transmit escaped CRC low byte

tx_bin_header_call_1:
		ld	a, ZBIN32		; Header encoding format ZBIN32 ('C' = 43h)
		call	comm_tx_char_wait	; Transmit format identifier
		ld	a, (tx_frame_type)	; Load frame type
		call	crc32_acc_update	; Update CRC-32
		call	comm_tx_char_wait	; Transmit frame type byte
		ld	hl, tx_hdr_flags	; HL points to 4 header flag bytes
		ld	b, 4			; 4 bytes to transmit

tx_bin_header_step_2:
		push	bc			; Preserve counter
		ld	a, (hl)			; Load header flag byte
		inc	hl			; Advance pointer
		push	hl			; Preserve pointer
		call	crc32_acc_update	; Update CRC-32
		call	tx_zdle_escaped_char	; Transmit escaped flag byte
		pop	hl			; Restore pointer
		pop	bc			; Restore counter
		djnz	tx_bin_header_step_2	; Repeat for all 4 bytes
		ld	hl, crc32_acc_bytes	; HL points to 32-bit CRC accumulator
		ld	b, 4			; 4 CRC bytes to send

tx_bin_header_step_3:
		push	bc			; Preserve counter
		ld	a, (hl)			; Load CRC byte
		inc	hl			; Advance pointer
		push	hl			; Preserve pointer
		cpl				; Ones complement inversion
		call	tx_zdle_escaped_char	; Transmit escaped CRC byte
		pop	hl			; Restore pointer
		pop	bc			; Restore counter
		djnz	tx_bin_header_step_3	; Repeat for all 4 CRC bytes
		ret				; Return	
; End of function tx_bin_header


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : tx_hex_header
; Purpose  : Transmit hexadecimal frame header (ZHEX) with CRC-16
; Inputs   : A = frame type
; Outputs  : Hex header frame transmitted
; Modifies : All registers
;============================================================================
tx_hex_header:
		ld	(tx_frame_type), a	; Save frame type byte (2707h)
		ld	hl, str_zhex_prefix	; HL points to ZHEX prefix sequence ("**B")
		call	tx_raw_string		; Transmit prefix string
		call	reset_crc_checksum	; Reset CRC and checksum accumulators
		ld	a, (tx_frame_type)	; Load frame type
		call	crc16			; Update CRC-16
		call	tx_hex_byte		; Transmit 2 hex ASCII digits for frame type
		ld	hl, tx_hdr_flags	; HL points to 4 header flag bytes
		ld	b, 4			; 4 bytes to transmit

tx_hex_header_step_1:
		push	bc			; Preserve counter
		ld	a, (hl)			; Load header flag byte
		inc	hl			; Advance pointer
		push	hl			; Preserve pointer
		call	crc16			; Update CRC-16
		call	tx_hex_byte		; Transmit 2 hex ASCII digits for flag byte
		pop	hl			; Restore pointer
		pop	bc			; Restore counter
		djnz	tx_hex_header_step_1	; Repeat for all 4 bytes
		ld	a, (crc16_seed+2)	; Load CRC-16 high byte
		call	tx_hex_byte		; Transmit hex digits for CRC high byte
		ld	a, (crc16_seed+1)	; Load CRC-16 low byte
		call	tx_hex_byte		; Transmit hex digits for CRC low byte
		ld	a, 0Dh			; Carriage Return (0Dh)
		call	comm_tx_char_wait	; Transmit CR
		ld	a, 0Ah			; Line Feed (0Ah)
		call	comm_tx_char_wait	; Transmit LF
		ld	a, (tx_frame_type)	; Check frame type
		cp	ZFIN			; Was frame type ZFIN?
		ret	z			; If ZFIN, do not send XON
		ld	a, 11h			; Otherwise send XON (11h) to resume receiver
		jp	comm_tx_char_wait	; Transmit XON and return
; End of function tx_hex_header

;----------------------------------------------------------------------------
str_zhex_prefix:	.db  ZPAD
		.db  ZPAD
		.db  ZDLE
		.db  ZHEX
		.db  0
str_hex_chars:	.db  30h ; 0
		.db  31h ; 1
		.db  32h ; 2
		.db  33h ; 3
		.db  34h ; 4
		.db  35h ; 5
		.db  36h ; 6
		.db  37h ; 7
		.db  38h ; 8
		.db  39h ; 9
		.db  61h ; a
		.db  62h ; b
		.db  63h ; c
		.db  64h ; d
		.db  65h ; e
		.db  66h ; f

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
		push	af			; Preserve input byte
		ld	hl, str_hex_chars	; HL points to ASCII hex lookup table
		ld	b, 0			; BC = high nibble index
		rra				; Shift high nibble into low nibble (A >> 4)
		rra	
		rra	
		rra	
		and	0Fh			; Mask to 0..15 range
		ld	c, a			; Set offset
		add	hl, bc			; HL points to hex ASCII character
		ld	a, (hl)			; Load hex character
		call	comm_tx_char_wait	; Transmit high nibble character
		pop	af			; Restore original byte
		ld	hl, str_hex_chars	; HL points to ASCII hex lookup table
		ld	b, 0			; BC = low nibble index
		and	0Fh			; Mask low nibble (0..15)
		ld	c, a			; Set offset
		add	hl, bc			; HL points to hex ASCII character
		ld	a, (hl)			; Load hex character
		jp	comm_tx_char_wait	; Transmit low nibble character and return
; End of function tx_hex_byte

;----------------------------------------------------------------------------

;============================================================================
; Function : tx_zdle_escaped_char
; Purpose  : Transmit byte over serial, escaping control chars with ZDLE
; Inputs   : A = character byte to send
; Outputs  : Byte (or ZDLE + escaped byte) transmitted
; Modifies : A, BC, HL
;============================================================================
tx_zdle_escaped_char:
; SMC WRITER: Patches immediate operand of ld a, imm at tx_char_direct (patch_tx_char_byte)
		ld	(patch_tx_char_byte), a ; Store byte into SMC direct transmission operand
		ld	bc, +(hex_byte_jump_vector-hex_byte_char_table) ; Table size
		ld	hl, hex_byte_char_table ; Search characters requiring escaping (CAN, CR, DLE, XON, XOFF)
		cpir				; Match character
		jp	z, dispatch_table_jump	; If in table, dispatch to escape handler
		and	60h			; Check if control character (bits 5-6 zero)
		jr	nz, tx_char_direct	; Not control character: transmit directly
		ld	a, (esc_ctrl_chars_flag) ; Check if receiver requested escaping control chars
		or	a
		jr	z, tx_char_direct	; If not requested, transmit directly

tx_zdle_escape_prefix:
; SMC WRITER: Modifies bit 6 of immediate operand at patch_tx_char_byte
		ld	hl, patch_tx_char_byte ; HL points to byte operand
		set	6, (hl)			; Invert/set bit 6 to escape control character
		ld	a, ZDLE			; Transmit ZDLE escape byte (18h)
		call	comm_tx_char_wait

; SMC TARGET: Patched by ld (patch_tx_char_byte), a and set 6, (hl) above
patch_tx_char_byte:	.equ	$+1		; SMC: direct character byte operand
tx_char_direct:
		ld	a, 0			; Byte to transmit
comm_tx_char_wait:
; SMC WRITER: Patches immediate operand of ld a, imm at line below (patch_tx_wait_flag)
		ld	(patch_tx_wait_flag), a ; Store into transmit wait operand
comm_tx_char_w_poll:
		call	rx_buffer_poll		; Service background receive FIFO
		call	aux_tx_ready		; Check if AUX transmitter is ready
		jr	z, comm_tx_char_w_poll	; Wait until UART transmitter ready

; SMC TARGET: Patched by ld (patch_tx_wait_flag), a above
patch_tx_wait_flag:	.equ	$+1		; SMC: character to transmit operand
		ld	a, 0			; Load character
		jp	aux_tx_char		; Output character to AUX port

comm_tx_char_w_esc_test:
		ld	a, (patch_tx_wait_flag) ; Load byte
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
;----------------------------------------------------------------------------

reset_crc_checksum:
		xor	a			; A = 0
		ld	h, a			; HL = 0000h
		ld	l, a
		ld	(checksum8_acc+1), a	; Reset 8-bit additive checksum to 0
		ld	(crc16_seed+1), hl	; Reset CRC-16 seed to 0000h
		ld	hl, crc32_acc_bytes	; HL points to 32-bit CRC accumulator
		jp	dec32_zero		; Initialize CRC-32 to 0xFFFFFFFF and return
; End of function reset_crc_checksum


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : rx_header_search
; Purpose  : Search incoming stream for ZPAD/ZDLE frame header sequence
; Inputs   : None
; Outputs  : A = frame type, CY on error/timeout
; Modifies : All registers
;============================================================================

;============================================================================
; Function : rx_header_search
; Purpose  : Search incoming stream for ZPAD/ZDLE frame header sequence
; Inputs   : None
; Outputs  : A = frame type, CY on error/timeout
; Modifies : All registers
;============================================================================
rx_header_search:
		xor	a			; Clear header encoding format (270Bh)
		ld	(rx_hdr_encoding), a
		ld	hl, 400h		; 1024 search iterations limit
		ld	(rx_hdr_crc_acc), hl

rx_header_search_init:
		ld	a, 5			; Initialize consecutive CAN counter = 5
		ld	(rx_hdr_type), a

rx_header_search_poll:
		ld	b, 0FFh			; Long timeout (~25 seconds)
		call	comm_rx_char_filtered	; Read character
		jp	c, rx_header_check_error ; Return on error
		ld	hl, rx_sync_char_table	; Match initial sync chars: ZDLE, 0AAh, ZPAD ('*')
		ld	bc, 3			; 3 entries
		cpir				; Search table
		jp	z, dispatch_table_jump	; Dispatch to sync handler
		jr	rx_header_search_countdown ; Decrement countdown and retry

rx_header_found_zpad:
		ld	hl, rx_hdr_type	; Decrement CAN counter
		dec	(hl)
		ld	a, 10h			; Frame type 16 = ZCAN
		jp	z, rx_header_check_error ; If 5 CANs, abort with ZCAN
		ld	b, 0Ah			; Short timeout for second sync char
		call	comm_rx_char_filtered	; Read next character
		jr	c, rx_header_search_poll ; On timeout, retry poll
		ld	hl, rx_zpad_next_table	; Match 'k' or ZDLE
		ld	bc, 2			; 2 entries
		cpir				; Search table
		jp	z, dispatch_table_jump	; Dispatch
		jr	rx_header_search_countdown

rx_header_consecutive_zpad:
		ld	hl, rx_hdr_type	; Decrement CAN counter
		dec	(hl)
		ld	a, 10h			; ZCAN status
		jp	z, rx_header_check_error ; Abort if too many CANs
		jr	rx_header_search_poll	; Continue polling

rx_header_drain_after_can:
		ld	b, 0Ah			; Short timeout
		call	comm_rx_char_filtered	; Drain character after CAN
		jr	c, rx_header_timeout_abort ; On timeout, abort

rx_header_search_countdown:
		ld	hl, (rx_hdr_crc_acc)	; Decrement search attempt counter
		dec	hl
		ld	(rx_hdr_crc_acc), hl
		ld	a, h			; Have attempts expired?
		or	l
		ld	a, 0FCh			; Status 0FCh (search timeout)
		jp	z, rx_header_check_error ; Abort if attempts exhausted
		jp	rx_header_search_init	; Otherwise retry search

rx_header_timeout_abort:
		ld	a, 0FFh			; Timeout error status
		jp	rx_header_check_error

rx_header_found_zdle:
		ld	a, 5			; Reset CAN counter = 5
		ld	(rx_hdr_type), a
rx_header_zdle_read_next:
		call	rx_filtered_char_wait	; Read character after ZDLE
		jr	c, rx_header_check_error
		ld	hl, rx_zdle_next_table	; Match ZPAD or ZDLE
		ld	bc, 2
		cpir
		jp	z, dispatch_table_jump
		jr	rx_header_search_countdown

rx_header_found_zpad_zdle:
		call	rx_filtered_char_wait	; Read format character
		jr	c, rx_header_check_error
		ld	hl, rx_hdr_encoding_table ; Match ZBIN32, ZBIN, ZHEX, ZDLE
		ld	bc, 4
		cpir
		jp	z, dispatch_table_jump
		jr	rx_header_search_countdown

;----------------------------------------------------------------------------
; Handlers for header encoding types (ZHEX, ZBIN, ZBIN32)
;----------------------------------------------------------------------------
rx_header_is_hex:
		ld	a, 10h			; CRC format = 16-bit
		ld	(26A8h), a
		call	rx_hex_header		; Parse ZHEX frame header
		jr	rx_header_unpack_payload ; Unpack payload

rx_header_is_bin:
		ld	a, 10h			; CRC format = 16-bit
		ld	(26A8h), a
		call	rx_bin16_header		; Parse ZBIN frame header
		jr	rx_header_unpack_payload ; Unpack payload

rx_header_is_bin32:
		ld	a, 20h			; CRC format = 32-bit
		ld	(26A8h), a
		call	rx_bin32_header		; Parse ZBIN32 frame header

rx_header_unpack_payload:
		push	af			; Preserve frame type
		ld	hl, rx_hdr_flags	; HL points to incoming frame flags
		ld	de, rx_hdr_pos		; DE points to rx_hdr_pos (26B3h)
		call	copy_4bytes		; Copy flags/position to rx_hdr_pos
		pop	af			; Restore frame type

rx_header_check_error:
		ld	hl, rx_header_err_table ; Match error status codes
		ld	bc, 6			; 6 error codes
		cpir				; Search table
		jr	nz, rx_header_success	; If not in error table, header is valid
		cp	98h			; Special error status?
		jr	nz, rx_header_error_exit ; Exit with error
		ld	a, 10h			; Translate to CAN error (16)

rx_header_error_exit:
		scf				; Set carry flag (error)
		ret				; Return

rx_header_success:
		or	a			; Clear carry flag (success)
		ret				; Return

;----------------------------------------------------------------------------
; Header Search Tables
;----------------------------------------------------------------------------
rx_sync_char_table:
		.db	ZDLE, 0AAh, ZPAD
		.dw	rx_header_found_zdle		; 18h (ZDLE)
		.dw	rx_header_found_zdle		; 0AAh
		.dw	rx_header_found_zpad		; 2Ah (ZPAD)

rx_zpad_next_table:
		.db	'k', ZDLE
		.dw	rx_header_consecutive_zpad	; 6Bh ('k')
		.dw	rx_header_drain_after_can	; 18h (ZDLE)

rx_zdle_next_table:
		.db	ZPAD, ZDLE
		.dw	rx_header_found_zpad_zdle	; 2Ah (ZPAD)
		.dw	rx_header_zdle_read_next	; 18h (ZDLE)

rx_hdr_encoding_table:
		.db	ZBIN32, ZBIN, ZHEX, ZDLE
		.dw	rx_header_found_zpad		; 43h ('C' = ZBIN32)
		.dw	rx_header_is_hex		; 41h ('A' = ZBIN -> calls 1454h)
		.dw	rx_header_is_bin		; 42h ('B' = ZHEX -> calls 141Ah)
		.dw	rx_header_is_bin32		; 18h (CAN  -> calls 13DFh)

rx_header_err_table:
		.db	98h, 06h, 10h, 0FFh, 0FEh, 0FCh

;----------------------------------------------------------------------------
; rx_bin32_header
; Reads 1-byte frame type + 4-byte flag payload + 4-byte CRC-32 checksum.
;----------------------------------------------------------------------------
rx_bin32_header:
		call	reset_crc_checksum	; Reset CRC and checksum accumulators
		call	rx_zdle_unescaped_char	; Read unescaped frame type byte
		ret	c			; Return on timeout / error
		ld	(rx_hdr_encoding), a	; Save frame type
		call	crc32_acc_update	; Update CRC-32 with frame type
		ld	hl, rx_hdr_flags	; HL points to 4 flag bytes
		ld	b, 4			; 4 bytes to read

rx_bin32_flags_loop:
		push	bc			; Preserve counter
		push	hl			; Preserve pointer
		call	rx_zdle_unescaped_char	; Read unescaped flag byte
		call	crc32_acc_update	; Update CRC-32
		pop	hl			; Restore pointer
		pop	bc			; Restore counter
		ld	(hl), a			; Store flag byte
		inc	hl			; Advance pointer
		ret	c			; Return on error
		djnz	rx_bin32_flags_loop	; Repeat for all 4 flag bytes
		ld	b, 4			; 4 CRC-32 checksum bytes to read

rx_bin32_crc_loop:
		push	bc			; Preserve counter
		call	rx_zdle_unescaped_char	; Read unescaped CRC byte
		call	crc32_acc_update	; Update CRC-32
		pop	bc			; Restore counter
		ret	c			; Return on error
		djnz	rx_bin32_crc_loop	; Repeat for all 4 CRC bytes
		ld	hl, crc32_acc_bytes	; HL points to computed CRC-32
		ld	de, crc32_final_xor	; DE points to expected residue (DEBB20E3h)
		call	cmp_4bytes_eq		; Verify computed CRC against residue
		jr	z, rx_bin32_success	; If match, return success
		jr	rx_bin_crc_error	; If mismatch, return CRC error

;----------------------------------------------------------------------------
; rx_bin16_header
; Reads 1-byte frame type + 4-byte flag payload + 2-byte CRC-16 checksum.
;----------------------------------------------------------------------------
rx_bin16_header:
		call	reset_crc_checksum	; Reset CRC and checksum accumulators
		call	rx_zdle_unescaped_char	; Read unescaped frame type byte
		ret	c			; Return on error
		ld	(rx_hdr_encoding), a	; Save frame type
		call	crc16			; Update CRC-16
		ld	hl, rx_hdr_flags	; HL points to 4 flag bytes
		ld	b, 4			; 4 bytes to read

rx_bin16_flags_loop:
		push	bc			; Preserve counter
		push	hl			; Preserve pointer
		call	rx_zdle_unescaped_char	; Read unescaped flag byte
		call	crc16			; Update CRC-16
		pop	hl			; Restore pointer
		pop	bc			; Restore counter
		ld	(hl), a			; Store flag byte
		inc	hl			; Advance pointer
		ret	c			; Return on error
		djnz	rx_bin16_flags_loop	; Repeat for all 4 flag bytes
		ld	b, 2			; 2 CRC-16 bytes to read

rx_bin16_crc_loop:
		push	bc			; Preserve counter
		call	rx_zdle_unescaped_char	; Read unescaped CRC byte
		call	crc16			; Update CRC-16
		pop	bc			; Restore counter
		ret	c			; Return on error
		djnz	rx_bin16_crc_loop	; Repeat for both CRC bytes
		ld	a, h			; Computed CRC-16 should be 0000h
		or	l
		jr	nz, rx_bin_crc_error	; If non-zero, CRC mismatch!

rx_bin32_success:
		ld	a, (rx_hdr_encoding)	; Load verified frame type
		ret				; Return with success (NC)

rx_bin_crc_error:
		ld	a, 0FFh			; CRC error status code
		scf				; Set carry flag (error)
		ret				; Return

;----------------------------------------------------------------------------
; rx_hex_header
; Reads hexadecimal frame header (frame type + 4 flag bytes + 2-byte CRC-16).
;----------------------------------------------------------------------------
rx_hex_header:
		call	reset_crc_checksum	; Reset CRC and checksum accumulators
		call	rx_hex_byte		; Read 2 ASCII hex characters for frame type
		ret	c			; Return on error
		ld	(rx_hdr_encoding), a	; Save frame type
		call	crc16			; Update CRC-16
		ld	hl, rx_hdr_flags	; HL points to 4 flag bytes
		ld	b, 4			; 4 bytes to read

rx_hex_flags_loop:
		push	bc			; Preserve counter
		push	hl			; Preserve pointer
		call	rx_hex_byte		; Read next flag byte (2 hex chars)
		jr	nc, rx_hex_store_byte	; If valid hex, store byte
		pop	hl			; Restore pointer on error
		pop	bc			; Restore counter
		ret				; Return error

rx_hex_store_byte:
		call	crc16			; Update CRC-16
		pop	hl			; Restore pointer
		pop	bc			; Restore counter
		ld	(hl), a			; Store flag byte
		inc	hl			; Advance pointer
		djnz	rx_hex_flags_loop	; Repeat for all 4 flag bytes
		ld	b, 2			; 2 CRC-16 bytes (4 hex chars) to read

rx_hex_crc_loop:
		push	bc			; Preserve counter
		call	rx_hex_byte		; Read CRC byte (2 hex chars)
		jr	nc, rx_hex_check_crc_byte ; If valid hex, process
		pop	bc			; Restore counter on error
		ret				; Return error

rx_hex_check_crc_byte:
		call	crc16			; Update CRC-16
		pop	bc			; Restore counter
		djnz	rx_hex_crc_loop	; Repeat for both CRC bytes
		ld	a, h			; Verify computed CRC is 0000h
		or	l
		jr	nz, rx_hex_crc_error	; If non-zero, CRC mismatch!
		ld	b, 0Ah			; Read trailing CR character
		call	comm_rx_char_filtered
		cp	0Dh			; Was character Carriage Return?
		jr	nz, rx_hex_finish	; If not CR, finish
		ld	b, 0Ah			; Read trailing LF character
		call	comm_rx_char_filtered

rx_hex_finish:
		or	a			; Clear carry flag (success)
		ld	a, (rx_hdr_encoding)	; Load verified frame type
		ret				; Return

rx_hex_crc_error:
		ld	a, 0FFh			; CRC error code
		scf				; Set carry flag (error)
		ret				; Return

;----------------------------------------------------------------------------
; rx_hex_byte
; Reads two hexadecimal ASCII characters and converts them into a binary byte.
; Outputs: A = assembled byte, CY on invalid hex character or timeout
;----------------------------------------------------------------------------
rx_hex_byte:
		call	rx_filtered_char_wait	; Read first hex character (high nibble)
		ret	c			; Return on error
		call	hex_char_to_nibble	; Convert ASCII char to 4-bit nibble
		jr	nz, rx_hex_byte_err	; Invalid hex digit, abort
		rlca				; Shift low nibble to high nibble (A << 4)
		rlca	
		rlca	
		rlca	
		ld	b, a			; B = high nibble shifted
		push	bc			; Preserve high nibble
		call	rx_filtered_char_wait	; Read second hex character (low nibble)
		pop	bc			; Restore high nibble
		ret	c			; Return on error
		call	hex_char_to_nibble	; Convert ASCII char to 4-bit nibble
		jr	nz, rx_hex_byte_err	; Invalid hex digit, abort
		or	b			; Combine high and low nibbles (A = high | low)
		ret				; Return assembled byte

rx_hex_byte_err:
		ld	a, 0FFh			; Hex conversion error
		scf				; Set carry flag (error)
		ret				; Return

;----------------------------------------------------------------------------
; hex_char_to_nibble
; Converts ASCII character ('0'-'9', 'a'-'f') into 4-bit numeric nibble in A.
; Outputs: A = 0-15, NZ if character out of valid hex range
;----------------------------------------------------------------------------
hex_char_to_nibble:
		ld	l, a			; Preserve char in L
		sub	'0'			; Subtract '0' (30h)
		cp	0Ah			; Is it a decimal digit ('0'..'9')?
		jr	c, hex_nibble_done	; If '0'..'9', nibble conversion done
		sub	'a' - '0' - 10		; Subtract 27h (39) for lowercase hex letters ('a'..'f')

hex_nibble_done:
		ld	l, a			; Save result in L
		and	0F0h			; Test if value fits in 0..15 range (high nibble zero)
		ld	a, l			; A = nibble value (0..15)
		ret				; Return with Z flag set if valid nibble

;----------------------------------------------------------------------------
; rx_filtered_char_wait
; Receives next character, stripping XON/XOFF and control characters if requested.
;----------------------------------------------------------------------------
rx_filtered_char_wait:
		ld	b, 64h			; 100 receive cycles timeout (~10 seconds)
		call	comm_rx_char_filtered	; Read character from serial receiver
		ret	c			; Return on timeout / abort
		and	7Fh			; Strip parity bit (7-bit ASCII)
		ld	hl, rx_flow_ctrl_table	; Match XON (11h) or XOFF (13h)
		ld	bc, 2			; 2 flow control characters
		cpir				; Test if XON or XOFF
		jr	z, rx_filtered_char_wait ; Strip and ignore flow control characters
		ld	bc, 3			; Match CR (0Dh), LF (0Ah), CAN (18h)
		cpir				; Test for framing delimiters
		ret	z			; Return delimiter character directly
		ld	b, a			; Preserve character in B
		and	60h			; Test if printable ASCII character (bits 5-6 set)
		jr	nz, rx_filter_char_ok	; Printable character: return OK
		ld	a, (esc_ctrl_chars_flag) ; Check if control characters should be stripped
		or	a
		jr	nz, rx_filtered_char_wait ; If escaping active, skip bare control character

rx_filter_char_ok:
		ld	a, b			; Restore character in A
		ret				; Return

rx_flow_ctrl_table:
		.db	11h, 13h, 0Dh, 0Ah, 18h	; XON, XOFF, CR, LF, CAN

;----------------------------------------------------------------------------
; rx_zdle_unescaped_char
; Receives byte with ZDLE unescaping, flow control filtering, and CAN detection.
; Outputs: A = unescaped byte, CY on timeout or session abort
;----------------------------------------------------------------------------
rx_zdle_unescaped_char:
		ld	b, 64h			; Timeout = 100 cycles
		call	comm_rx_char_filtered	; Read character
		ret	c			; Return on error
		ld	e, a			; Preserve character in E

rx_zdle_check_escape:
		and	60h			; Is character printable ASCII (bits 5-6 set)?
		ld	a, e			; Restore character
		ret	nz			; If printable, return unescaped character
		cp	ZDLE			; Is character ZDLE escape prefix (18h)?
		jr	z, rx_zdle_handle_escape ; If ZDLE, process escaped sequence
		ld	hl, tx_zdle_strip_table ; Flow control strip table (XON, XOFF)
		ld	bc, 4			; 4 entries
		cpir				; Check if flow control
		jr	z, rx_zdle_unescaped_char ; Ignore flow control character
		ld	a, (esc_ctrl_chars_flag) ; Check if control characters escaped
		or	a
		jr	nz, rx_zdle_unescaped_char ; If escaping active, ignore bare control byte
		ld	a, e			; Otherwise return raw control byte
		ret				; Return

rx_zdle_handle_escape:
		ld	b, 64h			; Timeout
		call	comm_rx_char_filtered	; Read byte after ZDLE
		ret	c			; Return on error
		cp	18h			; Is second byte CAN (18h)?
		jr	nz, rx_zdle_check_table ; If not CAN, check escape translation table
		ld	b, 64h			; Read third CAN
		call	comm_rx_char_filtered
		ret	c
		cp	18h			; Is third byte CAN?
		jr	nz, rx_zdle_check_table
		ld	b, 64h			; Read fourth CAN
		call	comm_rx_char_filtered
		ret	c
		cp	18h			; Is fourth byte CAN?
		jr	nz, rx_zdle_check_table
		ld	b, 64h			; Read fifth CAN
		call	comm_rx_char_filtered
		ret	c			; 5 consecutive CANs: receiver aborted transfer!

rx_zdle_check_table:
		ld	hl, rx_zdle_table	; Match ZDLE special translation table
		ld	bc, 11			; 11 entries
		cpir				; Search table
		jp	z, dispatch_table_jump	; Dispatch to handler
		ld	l, a			; Save byte in L
		ld	a, (esc_ctrl_chars_flag) ; Check control escape mode
		or	a
		jr	z, rx_zdle_unescape_xor ; If not enabled, unescape via XOR
		ld	a, l			; Check if control character
		and	60h
		jr	z, rx_zdle_handle_escape ; Nested escape sequence

rx_zdle_unescape_xor:
		ld	a, l			; Load escaped byte
		and	60h			; Check bit 6
		cp	40h			; Escaped standard control character?
		jr	nz, rx_zdle_error	; If bit 6 not set, framing error
		ld	a, l			; Load byte
		xor	40h			; Invert bit 6 to restore original control byte
		ret				; Return unescaped byte

rx_zdle_ret_rubout:
		ld	a, 7Fh			; Unescape to Rubout / DEL (7Fh)
		ret				; Return

rx_zdle_ret_ff:
		ld	a, 0FFh			; Unescape to 0FFh (Rubout | 80h)
		ret				; Return

rx_zdle_error:
		ld	a, 0FFh			; Framing error status
rx_zdle_error_flags:
		or	80h			; Set bit 7
		scf				; Set carry flag (error)
		ret				; Return

; Strip table for flow control bytes
tx_zdle_strip_table:
		.db	11h, 91h, 13h, 93h

; ZDLE translation dispatch table (11 entries)
rx_zdle_table:
		.db	11h, 91h, 13h, 93h, 18h, 68h, 69h, 6Ah, 6Bh, 6Ch, 6Dh
		.dw	rx_zdle_ret_ff		; 11h
		.dw	rx_zdle_ret_rubout	; 91h
		.dw	rx_zdle_error_flags	; 13h
		.dw	rx_zdle_error_flags	; 93h
		.dw	rx_zdle_error_flags	; 18h
		.dw	rx_zdle_error_flags	; 68h
		.dw	rx_zdle_error_flags	; 69h
		.dw	rx_zdle_handle_escape	; 6Ah
		.dw	rx_zdle_handle_escape	; 6Bh
		.dw	rx_zdle_handle_escape	; 6Ch
		.dw	rx_zdle_handle_escape	; 6Dh

;============================================================================
; Serial Communication & Framing Helper Library (serial_comm.inc)
;============================================================================
#include "serial_comm.inc"



;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : parse_cpm_filespec
; Purpose  : Parse CP/M file specification string into standard 36-byte FCB
; Inputs   : DE = FCB destination, HL = filename string
; Outputs  : FCB initialized
; Modifies : All registers
;============================================================================
parse_cpm_filespec:				; CODE XREF: start+5F (call)
		push	bc			; Preserve BC
		ld	(fcb_attr_mode), a	; Save attribute mode flag
		call	calc_strlen		; Convert filespec string to uppercase and find length
		push	de			; Preserve FCB destination pointer
		call	init_empty_fcb		; Clear FCB and initialize with spaces
		ld	(de), a			; Set drive byte
		pop	de			; Restore FCB pointer
		push	de			; Preserve FCB pointer
		call	parse_fcb_drive_user	; Parse drive, user area, and filename
		pop	de			; Restore FCB pointer
		pop	bc			; Restore BC
		jr	parse_fcb_driv_step_4	; Return with wildcard presence flag in A
; End of function parse_cpm_filespec


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : parse_fcb_drive_user
; Purpose  : Extract drive letter and user area number from file path string
; Inputs   : DE = FCB, HL = string
; Outputs  : Drive and user parsed into FCB
; Modifies : All registers
;============================================================================
parse_fcb_drive_user:				; CODE XREF: parse_cpm_filespec+E (call)
		xor	a			; Clear A
		ld	(de), a			; Clear FCB drive field (0 = default drive)
		ld	(fcb_drive_specified), a ; Reset explicit drive flag
		ld	(file_batch_index), a	; Reset wildcard counter
		call	bdos_call_wrapper	; Get current drive and user area
		ld	a, c			; C = current user area (0..15)
		ld	(fcb_active_user), a	; Store active user area
		push	de			; Preserve FCB pointer
		ld	a, (hl)			; Fetch first character of filespec
		cp	3Ah			; Is it a colon ':'?
		jr	nz, parse_fcb_driv_call_1 ; If not colon, parse primary name
		inc	hl			; Skip leading colon

parse_fcb_driv_call_1:				; CODE XREF: parse_fcb_drive_user+13 (jump)
		ld	b, 8			; Up to 8 chars for filename
		call	validate_fcb_char	; Parse primary name into FCB
		pop	de			; Restore FCB pointer
		ld	a, (hl)			; Fetch terminating delimiter character
		ld	(fcb_parse_state), a	; Save parse delimiter state
		cp	3Ah			; Was delimiter a colon ':' (drive/user prefix)?
		jr	nz, parse_fcb_driv_step_2 ; If not, primary field was filename
		inc	hl			; Skip colon delimiter
		ld	a, (fcb_attr_mode)	; Check attribute mode
		or	a			; Attribute mode active?
		jr	z, parse_fcb_driv_call_2 ; If not, attempt attribute matching
		call	fcb_check_wildcards	; Validate wildcard syntax in prefix
		jr	z, parse_fcb_driv_step_1 ; If valid, continue

parse_fcb_driv_call_2:				; CODE XREF: parse_fcb_drive_user+29 (jump)
		call	fcb_set_attributes	; Match drive / user specifier
		jr	z, parse_fcb_driv_step_1 ; If matched, continue
		ld	a, (fcb_attr_mode)	; Check attribute mode again
		or	a			; Attribute mode active?
		jr	nz, parse_fcb_driv_step_1 ; If active, continue
		call	fcb_check_wildcards	; Check wildcard expansion

parse_fcb_driv_step_1:				; CODE XREF: parse_fcb_drive_user+2E (jump)
					; parse_fcb_drive_user+33 (jump) ...
		ld	a, (fcb_drive_specified) ; Load parsed drive number (1=A, 2=B...)
		ld	(de), a			; Store drive into FCB drive byte
		push	de			; Preserve FCB pointer
		inc	de			; Advance past drive byte to filename
		call	init_fcb_spaces		; Fill filename and extension with spaces
		pop	de			; Restore FCB pointer
		xor	a			; Reset wildcard counter
		ld	(file_batch_index), a	; Store 0 into wildcard count
		push	de			; Preserve FCB pointer
		ld	b, 8			; Parse actual 8-character filename
		call	validate_fcb_char	; Parse filename into FCB
		pop	de			; Restore FCB pointer
		ld	a, (hl)			; Fetch trailing delimiter character
		ld	(fcb_parse_state), a	; Save delimiter state

parse_fcb_driv_step_2:				; CODE XREF: parse_fcb_drive_user+22 (jump)
		ld	a, (fcb_parse_state)	; Check delimiter following filename
		ex	de, hl			; Swap pointers: HL = FCB, DE = string
		ld	bc, 8			; Advance HL past 8 filename bytes to extension
		add	hl, bc			; HL points to extension in FCB
		ex	de, hl			; Swap back: DE = extension in FCB, HL = string
		ld	b, 3			; Extension length = 3 characters
		cp	2Eh			; Is delimiter a dot '.'?
		jr	nz, parse_fcb_driv_step_3 ; If no extension dot, skip
		inc	hl			; Advance past dot
		push	de			; Preserve extension pointer
		call	validate_fcb_char	; Parse 3-character extension into FCB
		pop	de			; Restore extension pointer

parse_fcb_driv_step_3:				; CODE XREF: parse_fcb_drive_user+64 (jump)
		ex	de, hl			; Advance DE to FCB user area extension field (+16)
		ld	bc, 5			; Add 5 bytes offset
		add	hl, bc			; HL points to user field in FCB
		ex	de, hl			; Swap back
		ld	a, (fcb_active_user)	; Load parsed user area number
		ld	(de), a			; Store user area into FCB extension

parse_fcb_driv_step_4:				; CODE XREF: parse_cpm_filespec+13 (jump)
		ld	a, (file_batch_index)	; A = number of wildcard characters parsed
		or	a			; Set Z flag if no wildcards, NZ if wildcards present
		ret				; Return
; End of function parse_fcb_drive_user


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : validate_fcb_char
; Purpose  : Validate ASCII character for CP/M FCB filename compatibility
; Inputs   : A = ASCII char
; Outputs  : Z if invalid/terminator, NZ if valid
; Modifies : A, F
;============================================================================
validate_fcb_char:				; CODE XREF: parse_fcb_drive_user+18 (call)
					; parse_fcb_drive_user+4F (call) ...
		call	check_delimiter_or_term	; Test if character is valid for filename
		ret	z			; Return if invalid or delimiter
		inc	de			; Advance FCB destination pointer
		cp	2Ah			; Is character '*' (asterisk wildcard)?
		jr	nz, validate_fcb_c_step_1 ; If not asterisk, check single char
		ld	a, 3Fh			; Replace '*' with '?' wildcard in FCB
		ld	(de), a			; Store '?' into FCB
		call	inc_file_counter	; Count wildcard character
		jr	validate_fcb_c_loop_1	; Continue loop
;----------------------------------------------------------------------------

validate_fcb_c_step_1:				; CODE XREF: validate_fcb_char+7 (jump)
		ld	(de), a			; Store valid character into FCB
		inc	hl			; Advance input string pointer
		cp	3Fh			; Is character '?' (question mark wildcard)?
		call	z, inc_file_counter	; Count wildcard character

validate_fcb_c_loop_1:				; CODE XREF: validate_fcb_char+F (jump)
		djnz	validate_fcb_char	; Decrement character counter and loop

validate_fcb_c_call_1:				; CODE XREF: validate_fcb_char+1F (jump)
		call	check_delimiter_or_term	; Scan past any excess characters in field
		ret	z			; Return when delimiter or terminator found
		inc	hl			; Advance input pointer
		jr	validate_fcb_c_call_1	; Continue skipping excess characters
; End of function validate_fcb_char


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : inc_file_counter
; Purpose  : Increment processed files counter
; Inputs   : None
; Outputs  : byte_0_270E incremented
; Modifies : HL
;============================================================================
inc_file_counter:				; CODE XREF: validate_fcb_char+C (call)
					; validate_fcb_char+15 (call)
		push	hl			; Preserve HL
		ld	hl, file_batch_index	; HL points to wildcard count byte
		inc	(hl)			; Increment wildcard count
		pop	hl			; Restore HL
		ret				; Return
; End of function inc_file_counter


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : fcb_check_wildcards
; Purpose  : Check if FCB filename contains '?' or '*' wildcards
; Inputs   : HL = FCB pointer
; Outputs  : Flags set based on wildcards
; Modifies : DE, HL
;============================================================================
fcb_check_wildcards:				; CODE XREF: parse_fcb_drive_user+2B (call)
					; parse_fcb_drive_user+3B (call)
		push	hl			; Preserve HL
		push	de			; Preserve DE
		call	fcb_match_drive		; Verify drive / user specifier
		pop	de			; Restore DE
		pop	hl			; Restore HL
		ret				; Return
; End of function fcb_check_wildcards


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : fcb_match_drive
; Purpose  : Match and verify FCB drive assignment against valid drives
; Inputs   : DE = FCB pointer
; Outputs  : Z if matches drive, NZ otherwise
; Modifies : A, B, DE, HL
;============================================================================
fcb_match_drive:				; CODE XREF: fcb_check_wildcards+2 (call)
		call	get_fcb_ext_ptr		; HL = pointer to user area or drive in Z3ENV
		jr	z, fcb_expand_done	; If null, exit with failure
		ex	de, hl			; DE = Z3ENV field pointer, HL = FCB
		inc	hl			; Skip first character
		call	get_fcb_name_ptr	; Get max drive limit from Z3ENV
		ld	b, a			; B = max valid drive
		inc	b			; Increment for comparison
		ld	a, (hl)			; Check drive letter
		cp	41h			; Below 'A'?
		jr	c, fcb_match_driv_step_1 ; If not letter, check if numeric user
		sub	40h			; Convert 'A'..'P' to 1..16
		cp	b			; Compare against max drive
		jr	nc, fcb_expand_done	; If above max drive, error
		ld	(fcb_drive_specified), a ; Store parsed explicit drive number
		inc	hl			; Check following character
		ld	a, (hl)			; Fetch character
		cp	20h			; Is following character space?
		ret	z			; Return success (valid drive)
		call	ascii_to_digit		; Check if user area number follows drive
		ret	c			; If not digit, return error

fcb_match_driv_step_1:				; CODE XREF: fcb_match_drive+F (jump)
		push	hl			; Preserve string pointer
		ld	b, 2			; Parse up to 2 decimal digits for user number

fcb_match_driv_br_1:				; CODE XREF: fcb_match_drive+30 (jump)
		ld	a, (hl)			; Fetch character
		cp	20h			; Is it space?
		jr	z, fcb_match_driv_call_1 ; If space, finish user number
		call	ascii_to_digit		; Validate decimal digit
		jr	c, fcb_match_driv_br_2	; If non-digit, abort
		inc	hl			; Advance pointer
		djnz	fcb_match_driv_br_1	; Loop for second digit
		ld	a, (hl)			; Check character after digits
		cp	20h			; Must be followed by space
		jr	nz, fcb_match_driv_br_2	; If not space, abort

fcb_match_driv_call_1:				; CODE XREF: fcb_match_drive+28 (jump)
		pop	hl			; Restore string pointer
		call	get_fcb_drive_ptr	; Get max user limit from Z3ENV
		ld	c, a			; C = max user number
		inc	c			; Increment for comparison
		call	parse_numeric_user	; Parse user number digits
		cp	c			; Compare against max user
		jr	nc, fcb_expand_done	; If user number too large, error
		ld	(fcb_active_user), a	; Save valid user number
		xor	a			; Return success (Z flag set)
		ret				; Return
;----------------------------------------------------------------------------

fcb_match_driv_br_2:				; CODE XREF: fcb_match_drive+2D (jump)
					; fcb_match_drive+35 (jump)
		pop	hl			; Restore string pointer
		jr	fcb_expand_done		; Return error
; End of function fcb_match_drive


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : fcb_set_attributes
; Purpose  : Set CP/M 3 extended FCB file attributes
; Inputs   : DE = FCB pointer
; Outputs  : FCB attributes updated
; Modifies : DE, HL
;============================================================================
fcb_set_attributes:				; CODE XREF: parse_fcb_drive_user+30 (call)
		push	hl			; Preserve HL
		push	de			; Preserve DE
		call	fcb_expand_wildcards	; Expand named directory via Z-System NDR table
		pop	de			; Restore DE
		pop	hl			; Restore HL
		ret				; Return
; End of function fcb_set_attributes


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : fcb_expand_wildcards
; Purpose  : Expand wildcard characters in FCB filename template
; Inputs   : DE = source pattern, HL = destination FCB
; Outputs  : FCB populated
; Modifies : All registers
;============================================================================
fcb_expand_wildcards:				; CODE XREF: fcb_set_attributes+2 (call)
		call	get_fcb_record_ptr	; HL = Named Directory (NDR) table pointer from Z3ENV
		jr	z, fcb_expand_done	; If NDR table not available, exit failure
		ex	de, hl			; DE = NDR table, HL = name pattern
		inc	hl			; Skip first byte

fcb_expand_wil_br_1:				; CODE XREF: fcb_expand_wildcards+23 (jump)
		ld	a, (de)			; Check drive byte in NDR entry
		or	a			; End of NDR table (drive 0)?
		jr	z, fcb_expand_done	; If end of table, directory name not found
		inc	de			; Point to directory name in NDR entry
		inc	de
		push	hl			; Preserve search pattern pointer
		push	de			; Preserve NDR entry pointer
		ld	b, 8			; Match 8 characters of directory name

fcb_expand_wil_br_2:				; CODE XREF: fcb_expand_wildcards+17 (jump)
		ld	a, (de)			; Compare directory name character
		cp	(hl)			; Match pattern?
		jr	nz, fcb_expand_wil_br_3 ; If mismatch, advance to next NDR entry
		inc	hl			; Advance search pattern
		inc	de			; Advance NDR entry
		djnz	fcb_expand_wil_br_2	; Loop for all 8 characters

fcb_expand_wil_br_3:				; CODE XREF: fcb_expand_wildcards+13 (jump)
		pop	de			; Restore NDR entry pointer
		pop	hl			; Restore search pattern pointer
		jr	z, fcb_expand_don_step_1 ; If match found, extract drive and user
		ex	de, hl			; Advance DE by 16 bytes (size of NDR entry)
		ld	bc, 10h			; BC = 16 bytes
		add	hl, bc			; Add offset
		ex	de, hl			; Swap back
		jr	fcb_expand_wil_br_1	; Check next NDR entry
;----------------------------------------------------------------------------

fcb_expand_done:				; CODE XREF: fcb_match_drive+3 (jump)
					; fcb_match_drive+14 (jump) ...
		or	0FFh			; Return failure (NZ flag set)
		ret				; Return
;----------------------------------------------------------------------------

fcb_expand_don_step_1:				; CODE XREF: fcb_expand_wildcards+1B (jump)
		dec	de			; Back up to user number byte in NDR entry
		ld	a, (de)			; Load user number
		ld	(fcb_active_user), a	; Set active user
		dec	de			; Back up to drive number byte in NDR entry
		ld	a, (de)			; Load drive number
		ld	(fcb_drive_specified), a ; Set active drive
		xor	a			; Return success (Z flag set)
		ret				; Return
; End of function fcb_expand_wildcards


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : check_delimiter_or_term
; Purpose  : Check if character is a path delimiter or string terminator
; Inputs   : HL = string pointer
; Outputs  : Flags set
; Modifies : A
;============================================================================
check_delimiter_or_term:				; CODE XREF: validate_fcb_char (call) validate_fcb_char+1A (call)
					; ...
		ld	a, (hl)			; Fetch character at HL
		cp	21h			; Less than '!' (control chars, space)?
		jr	c, check_delimite_step_1 ; If control/space, return terminator
		cp	3Dh			; Equal '='?
		ret	z			; Return if match
		cp	5Fh			; Underscore '_'?
		ret	z			; Return if match
		cp	2Eh			; Period '.'?
		ret	z			; Return if match
		cp	3Ah			; Colon ':'?
		ret	z			; Return if match
		cp	2Ch			; Comma ','?
		ret	z			; Return if match
		cp	3Ch			; Less-than '<'?
		ret	z			; Return if match
		cp	3Eh			; Greater-than '>'?
		ret	z			; Return if match
		or	a			; Null terminator (00h)?
		ret	z			; Return if match
		cp	3Bh			; Semicolon ';'?
		ret				; Return with flags
;----------------------------------------------------------------------------

check_delimite_step_1:				; CODE XREF: check_delimiter_or_term+3 (jump)
		xor	a			; Set Z flag (is delimiter/terminator)
		ret				; Return
; End of function check_delimiter_or_term


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : parse_numeric_user
; Purpose  : Parse decimal user number string (0..15) into numeric binary byte
; Inputs   : HL = string pointer
; Outputs  : A = numeric user area (0..15), CY on error
; Modifies : All registers
;============================================================================
parse_numeric_user:				; CODE XREF: fcb_match_drive+3D (call)
		push	bc			; Preserve BC
		ld	bc, 1100h		; B = 17 (loop counter), C = 0 (accumulated value)

parse_num_digit_loop:				; CODE XREF: parse_numeric_user+22 (jump)
		ld	a, (hl)			; Fetch character
		call	check_delimiter_or_term	; Check if end of number
		jr	z, parse_num_done	; If delimiter, finish
		inc	hl			; Advance pointer
		call	ascii_to_digit		; Convert char to binary digit
		jr	c, parse_num_err	; If not digit, error
		ld	d, a			; D = digit value
		ld	a, c			; Multiply accumulated C by 10
		rlca				; * 2
		jr	c, parse_num_err	; Error on overflow
		rlca				; * 4
		jr	c, parse_num_err	; Error on overflow
		add	a, c			; * 5
		jr	c, parse_num_err	; Error on overflow
		rlca				; * 10
		jr	c, parse_num_err	; Error on overflow
		add	a, d			; Add new digit
		jr	c, parse_num_err	; Error on overflow
		ld	c, a			; Store new accumulated value
		djnz	parse_num_digit_loop	; Loop for next digit

parse_num_done:				; CODE XREF: parse_numeric_user+8 (jump)
		ld	a, c			; Return parsed value in A
		pop	bc			; Restore BC
		or	a			; Clear Carry flag (success)
		ret				; Return
;----------------------------------------------------------------------------

parse_num_err:				; CODE XREF: parse_numeric_user+E (jump)
					; parse_numeric_user+13 (jump) ...
		pop	bc			; Restore BC
		scf				; Set Carry flag (error)
		ret				; Return
; End of function parse_numeric_user


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
; Function : dir_search_wildcard
; Purpose  : Perform directory scan and collect files matching wildcard filespec
; Inputs   : DE = FCB wildcard template, A = user number
; Outputs  : Matching files queued in directory buffer
; Modifies : All registers
;============================================================================
dir_search_wildcard:				; CODE XREF: start+8C (call)
		push	de			; Preserve filespec template pointer
		ld	(dir_user_filter), a	; Save user area filter
		call	dir_alloc_entry_buffer	; Initialize directory entry buffer
		call	dir_sort_compare	; Scan directory and collect entries (or 0AFh)
		jp	dir_search_wil_done_1	; Jump to sort and finish
;----------------------------------------------------------------------------
dir_search_wil_next_entry:
		push	de			; Preserve filespec template pointer
		ld	(dir_user_filter), a	; Save user area filter
		call	dir_alloc_entry_buffer	; Initialize directory entry buffer
		call	dir_sort_compare_xor	; Scan directory (xor a mode)
;----------------------------------------------------------------------------

dir_search_wil_done_1:				; CODE XREF: dir_search_wildcard+A (jump)
		pop	de			; Restore filespec pointer
		ret	z			; Return if no files matched (Z flag set)
		push	af			; Preserve status flags
		ld	a, (dir_user_filter)	; Load user area filter
		call	dir_sort_table		; Mark matched wildcard files in directory list
		call	dir_format_entry	; Compress matched files to front of buffer
		xor	a			; A = 0 (sort order)
		call	dir_read_entry		; Sort matched file entries alphabetically
		pop	af			; Restore status flags
		ret				; Return
; End of function dir_search_wildcard


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : dir_read_entry
; Purpose  : Sort directory entries in buffer alphabetically
; Inputs   : A = sort key (0=filename, 1=extension), BC = count, HL = table
; Outputs  : Entries sorted in place
; Modifies : All registers
;============================================================================
dir_read_entry:				; CODE XREF: dir_search_wildcard+24 (call)
		push	bc			; Preserve BC
		push	de			; Preserve DE
		push	hl			; Preserve HL
		ld	(dir_curr_buf_ptr), hl	; Save directory buffer base pointer
		push	hl			; Preserve buffer base
		ld	(2713h), a		; Save sort key flag
		ld	de, dir_curr_buf_ptr	; DE points to sort parameter descriptor
		ld	(dir_total_count), bc	; Save entry count
		ld	hl, dir_compare_fcb_names ; HL = pointer to FCB comparison function
		ld	(dir_cmp_callback), hl	; Set comparison callback
		ld	hl, (dir_sort_vector_ptr) ; HL = pointer table buffer base
		call	dir_partition		; Sort pointer table via Shell sort
		pop	hl			; Restore buffer base
		ld	(dir_curr_buf_ptr), hl	; Reset current buffer pointer
		call	file_open_for_transmit	; Permute entries in place using sorted pointers
		pop	hl			; Restore HL
		pop	de			; Restore DE
		pop	bc			; Restore BC
		ret				; Return
; End of function dir_read_entry

;----------------------------------------------------------------------------
; Callback : dir_compare_fcb_names
; Purpose  : Compare two FCB names pointed to by HL and DE
; Outputs  : Flags set (Z if equal, CY/NZ as appropriate)
;----------------------------------------------------------------------------
dir_compare_fcb_names:
		push	bc			; Preserve BC
		push	hl			; Preserve first FCB pointer
		push	de			; Preserve second FCB pointer
		ld	a, (2713h)		; Check sort order preference
		or	a			; 0 = filename then ext; 1 = ext then filename
		jr	z, dir_cmp_next_field	; If 0, compare filename first
		ld	bc, 9			; Offset to extension (+9)
		add	hl, bc			; HL points to extension of first FCB
		ex	de, hl			; DE points to extension of first FCB
		add	hl, bc			; HL points to extension of second FCB
		ex	de, hl			; Restore: HL = first, DE = second
		ld	b, 3			; Compare 3-character extension
		call	get_next_token_char	; Compare strings (case-insensitive)
		pop	de			; Restore second pointer
		pop	hl			; Restore first pointer
		jr	nz, dir_cmp_mismatch	; If extensions differ, exit with result
		push	hl			; Preserve first pointer
		push	de			; Preserve second pointer
		inc	hl			; Point to filename (+1)
		inc	de
		ld	b, 8			; Compare 8-character filename
		call	get_next_token_char	; Compare filenames
		pop	de			; Restore second pointer
		pop	hl			; Restore first pointer
		jr	nz, dir_cmp_mismatch	; If filenames differ, exit with result
		push	hl			; Preserve first pointer
		push	de			; Preserve second pointer
		ld	bc, 12			; Offset to extent byte (+12)
		add	hl, bc			; HL points to extent
		ex	de, hl
		add	hl, bc			; DE points to extent
		ex	de, hl
		ld	a, (de)			; Compare extent bytes
		cp	(hl)

dir_cmp_check_final:
		pop	de			; Restore second pointer
		pop	hl			; Restore first pointer
		jr	nz, dir_cmp_mismatch	; If extents differ, exit with result
		ld	a, (de)			; Compare drive/user byte
		cp	(hl)

dir_cmp_mismatch:
		pop	bc			; Restore BC
		ret				; Return comparison flags

dir_cmp_next_field:
		inc	hl			; Advance past drive byte to filename (+1)
		inc	de
		ld	b, 12			; Compare 8 filename + 3 ext + 1 extent = 12 bytes
		call	get_next_token_char	; Compare names
		jr	dir_cmp_check_final	; Finish comparison with drive byte

;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : dir_sort_compare
; Purpose  : Scan CP/M directory via BDOS Search First/Next and insert entries
; Inputs   : DE = FCB pattern
; Outputs  : BC = count of matched entries, (dir_match_count) = count
; Modifies : All registers
;============================================================================
dir_sort_compare_xor:	.equ	$+1		; Entry point for xor a (opcode AFh)
dir_sort_compare:				; CODE XREF: dir_search_wildcard+7 (call)
		or	0AFh			; Opcode F6 AF (or 0AFh); at $+1 it executes xor a
		ld	(dir_extent_merge_flag), a ; Save extent merge mode flag
		push	hl			; Preserve HL
		push	de			; Preserve DE
		ld	(dir_curr_buf_ptr), hl	; Save buffer pointer
		ld	(dir_table_base_saved), hl ; Save table base pointer
		ld	hl, 2714h		; HL points to scratch FCB
		ld	a, '?'			; Fill drive and name with '?' (all files)
		ld	b, 0Ch			; 12 bytes
		call	memset_loop		; Fill with '?'
		xor	a			; Zero remaining 24 bytes of FCB
		ld	b, 18h			; 24 bytes
		call	memset_loop		; Zero out rest of FCB
		ld	hl, 0			; Initialize match count = 0
		ld	(dir_match_count), hl
		ld	de, 80h			; Default DMA buffer (0080h)
		ld	c, F_DMAOFF		; BDOS Function 26: Set DMA Address
		call	bdos
		ld	c, 11h			; BDOS Function 17: Search First
		jr	dir_sort_compa_call_2	; Start search

dir_sort_compa_call_1:				; CODE XREF: dir_sort_compare+3E (jump)
		call	dir_entry_insert	; Insert directory entry into buffer
		jr	z, dir_sort_compa_br_1	; If buffer full or aborted, stop
		ld	c, 12h			; BDOS Function 18: Search Next

dir_sort_compa_call_2:				; CODE XREF: dir_sort_compare+2D (jump)
		ld	de, 2714h		; DE points to wildcard FCB
		call	bdos			; Execute BDOS search
		cp	0FFh			; 0FFh = no more directory entries
		jr	nz, dir_sort_compa_call_1 ; If entry found, process it
		or	0FFh			; Set NZ flag (successful scan)

dir_sort_compa_step_1:				; CODE XREF: dir_sort_compare+4A (jump)
		ld	bc, (dir_match_count)	; BC = total matched directory entries
		pop	de			; Restore DE
		pop	hl			; Restore HL
		ret				; Return

dir_sort_compa_br_1:				; CODE XREF: dir_sort_compare+32 (jump)
		xor	a			; Clear A (error / abort)
		jr	dir_sort_compa_step_1	; Exit with count
; End of function dir_sort_compare


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : dir_entry_insert
; Purpose  : Insert matched directory entry from CP/M DMA buffer into table
; Inputs   : A = directory sector index (0..3) returned by BDOS Search
; Outputs  : Z if memory full / TPA limit reached, NZ on success
; Modifies : All registers
;============================================================================
dir_entry_insert:				; CODE XREF: dir_sort_compare+2F (call)
		push	bc			; Preserve BC
		push	de			; Preserve DE
		push	hl			; Preserve HL
		rrca				; Multiply directory index by 32 (size of entry)
		rrca				; Shift right 3 bits with rotate wraps to bits 5,6
		rrca	
		and	60h			; Mask offset: 0, 32, 64, or 96
		ld	de, 80h			; DE = base of CP/M default DMA buffer
		ld	l, a			; HL = offset within DMA sector
		ld	h, 0
		add	hl, de			; HL points to 32-byte directory entry in DMA buffer
		ld	a, (hl)			; Check user number / status byte
		cp	0E5h			; 0E5h = deleted / empty entry
		jr	z, dir_entry_inse_step_1+1 ; If deleted, skip entry
		cp	21h			; Greater than 32 (user 0..31)?
		jr	nc, dir_entry_inse_step_1+1 ; If user > 31, skip entry
		call	dir_filter_system_files	; Check for existing file entry (extent merge)
		jr	z, dir_entry_inse_step_1+1 ; If duplicate extent merged, do not add new entry
		push	hl			; Preserve directory entry pointer
		ld	hl, (dir_match_count)	; Increment matched file counter
		inc	hl
		ld	(dir_match_count), hl
		pop	hl			; Restore entry pointer
		ld	de, (dir_curr_buf_ptr)	; DE = current destination pointer in buffer
		ld	bc, 10h			; Copy 16 bytes (user + 8 name + 3 ext + extent info)
		ldir				; Copy directory entry into buffer
		ld	(dir_curr_buf_ptr), de	; Update buffer pointer
		call	get_top_of_tpa		; Check top of available TPA RAM
		ld	a, h			; High byte of TPA limit
		dec	a			; Safety margin of 256 bytes
		cp	d			; Compare against current buffer high byte
		jr	nz, dir_entry_inse_step_1+1 ; If memory remains, continue
		xor	a			; Set Z flag (buffer full error)

dir_entry_inse_step_1:				; CODE XREF: dir_entry_insert+12 (jump)
					; dir_entry_insert+16 (jump) ...
		ld	hl, 0FFF6h		; Dummy instruction (never executed directly)
		pop	hl			; Restore HL
		pop	de			; Restore DE
		pop	bc			; Restore BC
		ret				; Return
; End of function dir_entry_insert


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : dir_filter_system_files
; Purpose  : Check if file already exists in directory table and merge extents
; Inputs   : HL = new directory entry in DMA buffer
; Outputs  : Z if extent merged into existing entry, NZ if new unique file
; Modifies : All registers
;============================================================================
dir_filter_system_files:			; CODE XREF: dir_entry_insert+18 (call)
		push	hl			; Preserve DMA entry pointer
		ex	de, hl			; DE points to new directory entry
		ld	bc, (dir_match_count)	; BC = number of entries currently in table
		ld	a, b			; Any entries in table yet?
		or	c
		jr	z, dir_filter_sys_done_1 ; If table empty, file is unique (NZ)
		ld	hl, (dir_table_base_saved) ; HL = base of directory table

dir_filter_sys_step_1:				; CODE XREF: dir_filter_system_files+47 (jump)
		push	bc			; Preserve loop counter
		push	hl			; Preserve table entry pointer
		push	de			; Preserve new entry pointer
		ld	b, 0Ch			; Compare 12 bytes (user, filename, and extension)
		call	get_next_token_char	; Compare entry names
		pop	de			; Restore new entry pointer
		pop	hl			; Restore table entry pointer
		jr	nz, dir_filter_sys_step_4 ; If names mismatch, check next table entry
		push	hl			; Preserve table pointer
		push	de			; Preserve new entry pointer
		ld	bc, 0Ch			; Offset 12: extent counter byte
		add	hl, bc			; HL points to extent byte in table
		ex	de, hl
		add	hl, bc			; HL points to extent byte in new entry
		ld	a, (de)			; Compare extent values
		cp	(hl)
		pop	de			; Restore pointers
		pop	hl
		jr	nc, dir_filter_sys_br_1 ; If table extent >= new extent, skip update
		ld	a, (dir_extent_merge_flag) ; Check extent merge mode
		or	a
		jr	nz, dir_filter_sys_step_3

dir_filter_sys_step_2:				; CODE XREF: dir_filter_system_files+39 (jump)
		ex	de, hl			; Update table entry with higher extent info
		ld	bc, 10h			; 16 bytes
		ldir				; Overwrite table entry
		jr	dir_filter_sys_step_3

dir_filter_sys_br_1:				; CODE XREF: dir_filter_system_files+25 (jump)
		ld	a, (dir_extent_merge_flag)
		or	a
		jr	nz, dir_filter_sys_step_2

dir_filter_sys_step_3:				; CODE XREF: dir_filter_system_files+2B (jump)
					; dir_filter_system_files+33 (jump)
		pop	bc			; Restore BC
		xor	a			; Set Z flag (duplicate extent handled)
		pop	hl			; Restore HL
		ret				; Return

dir_filter_sys_step_4:				; CODE XREF: dir_filter_system_files+17 (jump)
		ld	bc, 10h			; Advance to next 16-byte table entry
		add	hl, bc
		pop	bc			; Restore loop counter
		dec	bc			; Decrement entries remaining
		ld	a, b
		or	c
		jr	nz, dir_filter_sys_step_1 ; Continue checking remaining entries

dir_filter_sys_done_1:				; CODE XREF: dir_filter_system_files+8 (jump)
		or	0FFh			; Set NZ flag (new unique file entry)
		pop	hl			; Restore HL
		ret				; Return
; End of function dir_filter_system_files


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : dir_format_entry
; Purpose  : Compact matched directory entries (marked with bit 7) to front
; Inputs   : HL = table base, BC = total entries
; Outputs  : BC = count of marked entries, table compacted
; Modifies : All registers
;============================================================================
dir_format_entry:				; CODE XREF: dir_search_wildcard+20 (call)
		push	hl			; Preserve HL
		push	de			; Preserve DE
		push	af			; Preserve AF
		push	hl			; Preserve table base
		ld	hl, 0			; Initialize marked counter = 0
		ld	(dir_marked_count), hl
		pop	hl			; HL = table base
		ld	(dir_curr_buf_ptr), hl	; Set destination pointer to table base
		push	bc			; Preserve entry count

dir_format_ent_step_1:				; CODE XREF: dir_format_entry+31 (jump)
					; dir_format_entry+37 (jump)
		pop	bc			; Restore loop counter
		ld	a, b			; Any entries remaining?
		or	c
		jr	z, dir_format_ent_step_2 ; If all processed, finish
		dec	bc			; Decrement loop counter
		push	bc			; Preserve loop counter
		bit	7, (hl)			; Check if entry was marked (bit 7 set)
		jr	z, dir_format_ent_br_1	; If not marked, skip entry
		res	7, (hl)			; Clear mark bit
		ex	de, hl			; Save source in DE
		ld	hl, (dir_marked_count)	; Increment marked entry count
		inc	hl
		ld	(dir_marked_count), hl
		ld	hl, (dir_curr_buf_ptr)	; HL = compact destination pointer
		ex	de, hl			; HL = source entry, DE = destination
		ld	bc, 10h			; 16 bytes per entry
		ldir				; Move entry to front of buffer
		ld	(dir_curr_buf_ptr), de	; Update destination pointer
		jr	dir_format_ent_step_1	; Loop for next entry

dir_format_ent_br_1:				; CODE XREF: dir_format_entry+18 (jump)
		ld	bc, 10h			; Advance past unmarked 16-byte entry
		add	hl, bc
		jr	dir_format_ent_step_1	; Loop for next entry

dir_format_ent_step_2:				; CODE XREF: dir_format_entry+12 (jump)
		ld	bc, (dir_marked_count)	; BC = total count of marked entries
		pop	af			; Restore AF
		pop	de			; Restore DE
		pop	hl			; Restore HL
		ret				; Return
; End of function dir_format_entry


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : dir_alloc_entry_buffer
; Purpose  : Allocate directory entry buffer and initialize sort vectors
; Inputs   : None
; Outputs  : Buffer pointers initialized
; Modifies : All registers
;============================================================================
dir_alloc_entry_buffer:			; CODE XREF: dir_search_wildcard+4 (call)
		push	de			; Preserve DE
		push	bc			; Preserve BC
		ex	de, hl			; HL = caller parameter
		call	dir_free_entry_buffer	; Read CP/M DPB disk parameters
		ld	hl, (dir_dpb_dir_max)	; HL = max directory entries limit
		ld	(dir_total_count), hl	; Set max count parameter
		ld	hl, 10h			; Entry size = 16 bytes (10h)
		ld	(dir_entry_len), hl	; Set entry size
		ld	hl, 0			; Clear callback
		ld	(dir_curr_buf_ptr), hl
		ld	hl, 0FFh			; Flag = 00FFh
		ld	(2749h), hl
		ex	de, hl			; DE = buffer base
		ld	de, dir_curr_buf_ptr	; DE points to descriptor
		call	dir_partition		; Initialize pointer table array
		pop	bc			; Restore BC
		pop	de			; Restore DE
		ret				; Return
; End of function dir_alloc_entry_buffer


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : dir_free_entry_buffer
; Purpose  : Read CP/M Disk Parameter Block (DPB) parameters via BDOS 31
; Inputs   : None
; Outputs  : (dir_dpb_info), (dir_dpb_max_alloc), (dir_dpb_dir_max) set
; Modifies : All registers
;============================================================================
dir_free_entry_buffer:			; CODE XREF: dir_alloc_entry_buffer+3 (call)
		push	bc			; Preserve BC
		push	de			; Preserve DE
		push	hl			; Preserve HL
		push	af			; Preserve AF
		ld	c, 1Fh			; BDOS Function 31: Get DPB Address
		call	bdos			; Returns DPB pointer in HL
		inc	hl			; Skip DPB sectors per track (SPT)
		inc	hl
		ld	de, dir_dpb_info	; Destination for DPB parameters
		ldi				; Copy BSH (block shift)
		ldi				; Copy BLM (block mask)
		ldi				; Copy EXM (extent mask)
		ld	e, (hl)			; Read DSM (max allocation block number)
		inc	hl
		ld	d, (hl)
		inc	de			; Total blocks = DSM + 1
		ld	(dir_dpb_max_alloc), de ; Save max allocation blocks
		inc	hl
		ld	e, (hl)			; Read DRM (max directory entry number)
		inc	hl
		ld	d, (hl)
		inc	de			; Total directory entries = DRM + 1
		ld	(dir_dpb_dir_max), de	; Save max directory entries
		pop	af			; Restore AF
		pop	hl			; Restore HL
		pop	de			; Restore DE
		pop	bc			; Restore BC
		ret				; Return
; End of function dir_free_entry_buffer


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : dir_sort_table
; Purpose  : Scan directory list and mark entries matching wildcard filespec
; Inputs   : HL = table base, DE = wildcard pattern, BC = count, A = user filter
; Outputs  : Matched entries have bit 7 set on first byte
; Modifies : All registers
;============================================================================
dir_sort_table:				; CODE XREF: dir_search_wildcard+1D (call)
		push	hl			; Preserve table pointer
		push	de			; Preserve pattern pointer
		push	bc			; Preserve count
		push	af			; Preserve user filter
		ld	(dir_user_filter), a	; Save user filter
		push	bc			; Preserve count for loop

dir_sort_table_step_1:				; CODE XREF: dir_sort_table+39 (jump)
		pop	bc			; Restore loop counter
		ld	a, b			; Any entries remaining?
		or	c
		jr	z, dir_sort_table_step_3 ; If done, exit
		dec	bc			; Decrement loop counter
		push	bc			; Preserve loop counter
		push	hl			; Preserve table entry pointer
		push	de			; Preserve wildcard pattern pointer
		inc	hl			; Advance past user byte to filename (+1)
		inc	de
		ld	b, 8			; Compare 8 filename characters
		ex	de, hl			; DE = table entry, HL = pattern
		call	check_wildcard_char	; Compare with '?' wildcard support
		pop	de			; Restore pattern pointer
		pop	hl			; Restore table entry pointer
		jr	nz, dir_sort_table_step_2 ; If filename does not match, skip
		push	hl			; Preserve table pointer
		push	de			; Preserve pattern pointer
		ld	bc, 9			; Offset to extension (+9)
		add	hl, bc			; HL points to extension in table
		ex	de, hl			; DE = table extension, HL = pattern
		add	hl, bc			; HL points to extension in pattern
		ld	b, 3			; Compare 3 extension characters
		call	check_wildcard_char	; Compare extension
		pop	de			; Restore pattern pointer
		pop	hl			; Restore table pointer
		jr	nz, dir_sort_table_step_2 ; If extension does not match, skip
		call	dir_swap_entries	; Check file attributes (system vs directory)
		jr	nz, dir_sort_table_step_2 ; If excluded by attributes, skip
		set	7, (hl)			; Mark entry as matched (set bit 7 of user byte)

dir_sort_table_step_2:				; CODE XREF: dir_sort_table+1B (jump)
					; dir_sort_table+2C (jump) ...
		ld	bc, 10h			; Advance to next 16-byte table entry
		add	hl, bc
		jr	dir_sort_table_step_1	; Loop for next entry

dir_sort_table_step_3:				; CODE XREF: dir_sort_table+B (jump)
		pop	af			; Restore user filter
		pop	bc			; Restore count
		pop	de			; Restore pattern pointer
		pop	hl			; Restore table pointer
		ret				; Return
; End of function dir_sort_table


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : dir_swap_entries
; Purpose  : Check file attributes and user area against filter options
; Inputs   : HL = directory entry pointer, A = user filter flags
; Outputs  : Z if entry is accepted, NZ if excluded
; Modifies : All registers
;============================================================================
dir_swap_entries:				; CODE XREF: dir_sort_table+2E (call)
		push	de			; Preserve DE
		push	hl			; Preserve HL
		ld	de, 0Ah			; Offset 10: F2' attribute byte (System file bit)
		add	hl, de			; HL points to F2' attribute
		bit	7, (hl)			; Bit 7 set = System file ($SYS)
		pop	hl			; Restore HL
		pop	de			; Restore DE
		ld	a, (dir_user_filter)	; Load filter flags
		jr	z, dir_swap_entri_br_1	; If DIR file (not SYS), branch
		bit	6, a			; Check include-system-files flag
		jr	nz, dir_swap_entri_br_2 ; If SYS allowed, check user area

dir_swap_entri_step_1:				; CODE XREF: dir_swap_entries+18 (jump)
					; dir_swap_entries+21 (jump)
		or	0FFh			; Reject file (set NZ flag)
		ret				; Return

dir_swap_entri_br_1:				; CODE XREF: dir_swap_entries+D (jump)
		bit	7, a			; Check include-dir-files flag
		jr	z, dir_swap_entri_step_1 ; If DIR files excluded, reject

dir_swap_entri_br_2:				; CODE XREF: dir_swap_entries+11 (jump)
		bit	5, a			; Check all-user-areas wildcard flag
		jr	nz, dir_swap_entri_step_2 ; If all users allowed, accept
		xor	(hl)			; Compare user area byte
		and	3Fh			; Mask user area (0..31)
		jr	nz, dir_swap_entri_step_1 ; If user number mismatch, reject

dir_swap_entri_step_2:				; CODE XREF: dir_swap_entries+1C (jump)
		xor	a			; Accept file (set Z flag)
		ret				; Return
; End of function dir_swap_entries


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : dir_partition
; Purpose  : Initialize indirect pointer array and sort entries via Shell sort
; Inputs   : DE = sort descriptor block, HL = destination pointer table
; Outputs  : Pointer array populated and sorted; A = status
; Modifies : All registers
;============================================================================
dir_partition:				; CODE XREF: dir_read_entry+1A (call)
					; dir_alloc_entry_buffer+22 (call)
		push	bc			; Preserve BC
		push	de			; Preserve DE
		push	hl			; Preserve HL
		call	file_stream_init	; Load 12-byte sort descriptor block
		pop	de			; DE = pointer table destination
		ld	(sort_ptr_table), de	; Save pointer table base address
		ld	hl, (sort_item_count)	; HL = item count N
		ld	a, h			; Is item count zero?
		or	l
		jr	z, dir_partition_step_3 ; If zero items, nothing to sort
		ld	b, h			; BC = item count N
		ld	c, l
		add	hl, hl			; HL = N * 2 (size of 16-bit pointer array)
		jr	c, dir_partition_step_3 ; Overflow check
		add	hl, de			; End of pointer array
		jr	c, dir_partition_step_3 ; Overflow check
		ex	de, hl			; DE = end of pointer array
		ld	hl, (6)			; BDOS top of memory vector (0006h)
		sbc	hl, de			; Ensure pointer array fits below BDOS top of RAM
		jr	c, dir_partition_step_3 ; If out of memory, abort
		ld	hl, (sort_table_base)	; HL = base address of items to sort
		ld	a, h			; Is base address zero?
		or	l
		jr	z, dir_partition_step_1 ; If zero, keep DE
		ex	de, hl			; DE = item base address

dir_partition_step_1:				; CODE XREF: dir_partition+27 (jump)
		push	de			; Preserve item base
		ld	hl, (sort_ptr_table)	; HL = pointer table array

dir_partition_step_2:				; CODE XREF: dir_partition+3C (jump)
		ld	(hl), e			; Store item pointer low byte into array
		inc	hl
		ld	(hl), d			; Store item pointer high byte into array
		inc	hl
		push	hl			; Preserve array pointer
		ld	hl, (sort_item_size)	; HL = size of each item
		add	hl, de			; Advance DE to next item
		ex	de, hl			; DE = next item pointer
		pop	hl			; Restore array pointer
		dec	bc			; Decrement item counter
		ld	a, b			; Any items remaining?
		or	c
		jr	nz, dir_partition_step_2 ; Loop until all pointers stored
		pop	hl			; Restore item base
		ld	(sort_table_base), hl	; Update table base
		push	hl			; Preserve base
		call	file_stream_read_next	; Restore caller descriptor
		pop	hl			; Restore base
		dec	a			; Decrement status

dir_partition_done_1:				; CODE XREF: dir_partition+4F (jump)
		pop	de			; Restore DE
		pop	bc			; Restore BC
		ret				; Return

dir_partition_step_3:				; CODE XREF: dir_partition+10 (jump)
					; dir_partition+15 (jump) ...
		xor	a			; Clear A (failure status)
		ld	hl, (sort_ptr_table)	; HL = pointer table
		jr	dir_partition_done_1	; Exit
; End of function dir_partition


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : file_open_for_transmit
; Purpose  : Permute array items in place according to sorted pointer array
; Inputs   : DE = sort descriptor block
; Outputs  : Items permuted in place into sorted order
; Modifies : All registers
;
; C-Equivalent Algorithm (Cycle Following Permutation):
;   void permute_in_place(void **ptrs, void *base, int count, int size) {
;       for (int i = 0; i < count - 1; i++) {
;           void *dest = ptrs[i];
;           void *src  = base + i * size;
;           if (dest > src) {
;               swap_bytes(src, dest, size);
;               // Update pointer table to trace displaced element
;               for (int k = i + 1; k < count; k++) {
;                   if (ptrs[k] == src) { ptrs[k] = dest; break; }
;               }
;           }
;       }
;   }
;============================================================================
file_open_for_transmit:			; CODE XREF: dir_read_entry+21 (call)
		ex	af, af'			; Preserve AF in alternate AF'
		push	af
		ex	af, af'
		push	hl			; Preserve HL
		push	de			; Preserve DE
		push	bc			; Preserve BC
		push	af			; Preserve AF
		call	file_stream_init	; Load 12-byte sort descriptor block
		call	file_stream_read_record ; Execute Shell sort on items
		ld	a, (sort_indirect_flag) ; Indirect pointer sort active?
		or	a
		jr	z, file_open_for_step_3 ; If direct sort, permutation not needed
		ld	a, (sort_flags2)	; Secondary flag active?
		or	a
		jr	nz, file_open_for_step_3
		ld	hl, (sort_item_count)	; Check item count
		ld	a, h
		or	l
		jr	z, file_open_for_step_3 ; If 0 items, nothing to permute
		ld	(sort_gap), hl		; Initialize outer loop index
		ld	hl, 0			; Initialize item index
		ld	(sort_index), hl

file_open_for_step_1:				; CODE XREF: file_open_for_transmit+4B (jump)
					; file_open_for_transmit+6E (jump)
		ld	hl, (sort_gap)		; Decrement outer loop index
		dec	hl
		ld	a, h
		or	l
		jr	z, file_open_for_step_3 ; All items permuted into place
		ld	(sort_gap), hl
		ld	hl, (sort_index)	; Increment item index
		inc	hl
		ld	(sort_index), hl
		ld	d, h			; DE = current item index
		ld	e, l
		call	file_advance_block	; HL = pointer in pointer table
		ld	a, (hl)			; Read target pointer
		inc	hl
		ld	h, (hl)
		ld	l, a			; HL = target item address
		ex	de, hl			; DE = target item address
		call	file_compute_block_offset ; HL = original item address
		sbc	hl, de			; Is item already in place?
		add	hl, de
		jr	nc, file_open_for_step_1 ; If already in place, continue
		push	de			; Preserve target item address
		push	hl			; Preserve original item address
		call	file_calc_record_count ; Swap the two items in memory
		ld	hl, (sort_index)	; Read current item index
		call	file_advance_block	; HL = pointer table address
		pop	de			; DE = original item address
		ld	(hl), e			; Update pointer in table
		inc	hl
		ld	(hl), d
		inc	hl

file_open_for_step_2:				; CODE XREF: file_open_for_transmit+61 (jump)
					; file_open_for_transmit+67 (jump)
		ld	a, (hl)			; Search for next item in permutation cycle
		inc	hl
		cp	e
		inc	hl
		jr	nz, file_open_for_step_2
		dec	hl
		ld	a, (hl)
		inc	hl
		cp	d
		jr	nz, file_open_for_step_2
		pop	de			; DE = target address
		dec	hl
		ld	(hl), d			; Update permutation link
		dec	hl
		ld	(hl), e
		jr	file_open_for_step_1	; Continue permutation cycle

file_open_for_step_3:				; CODE XREF: file_open_for_transmit+11 (jump)
					; file_open_for_transmit+17 (jump) ...
		pop	af			; Restore AF
		pop	bc			; Restore BC
		pop	de			; Restore DE
		pop	hl			; Restore HL
		ex	af, af'			; Restore AF from alternate
		pop	af
		ex	af, af'
		ret				; Return
; End of function file_open_for_transmit


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : file_read_header_info
; Purpose  : Swap two items during sort (tail-call exit through file_stream_exit)
; Inputs   : HL, DE = items to swap
; Outputs  : Items swapped in memory
; Modifies : All registers
;============================================================================
file_read_header_info:			; CODE XREF: file_stream_read_record+3C (call)
		push	hl			; Preserve HL
		push	de			; Preserve DE
		ld	bc, file_stream_exit	; Push return address (tail-call exit)
		push	bc
		ld	a, (sort_indirect_flag) ; Indirect sort active?
		or	a
		jr	nz, file_calc_reco_call_1 ; If indirect, swap pointers in table
		call	file_seek_record	; If direct, compute item memory addresses
; End of function file_read_header_info


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : file_calc_record_count
; Purpose  : Swap memory blocks of length (sort_item_size) pointed to by HL & DE
; Inputs   : HL = block 1, DE = block 2
; Outputs  : Memory blocks swapped
; Modifies : All registers
;============================================================================
file_calc_record_count:			; CODE XREF: file_open_for_transmit+4F (call)
		ld	bc, (sort_item_size)	; BC = length of item to swap
		jr	file_calc_reco_step_1	; Execute swap loop
;----------------------------------------------------------------------------

file_stream_exit:
		pop	de			; Restore DE
		pop	hl			; Restore HL
		ret				; Return
;----------------------------------------------------------------------------

file_calc_reco_call_1:				; CODE XREF: file_read_header_info+A (jump)
		call	file_advance_block	; HL = pointer 1 address in pointer table
		ex	de, hl			; DE = pointer 1 address
		dec	hl			; Offset adjustment
		add	hl, hl			; HL = (index 2 - 1) * 2
		add	hl, bc			; HL = pointer 2 address in pointer table
		ld	bc, 2			; Size of 16-bit word = 2 bytes

file_calc_reco_step_1:				; CODE XREF: file_calc_record_count+4 (jump)
					; file_calc_record_count+19 (jump)
		ld	a, (de)			; Swap bytes between (DE) and (HL)
		ldi				; Copy (HL) to (DE), increment both, decrement BC
		dec	hl			; Back up HL
		ld	(hl), a			; Store original (DE) byte into (HL)
		inc	hl			; Advance HL
		jp	pe, file_calc_reco_step_1 ; Loop until BC reaches 0 (parity even = PE)
		ret				; Return
; End of function file_calc_record_count


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : file_seek_record
; Purpose  : Compute direct memory addresses for two items
; Inputs   : HL = item 1 index, DE = item 2 index
; Outputs  : HL = item 1 address, DE = item 2 address
; Modifies : All registers
;============================================================================
file_seek_record:				; CODE XREF: file_read_header_info+C (call)
					; file_read_block_buffered+C (call)
		call	file_compute_block_offset ; HL = item 1 address
		ex	de, hl			; Swap: HL = item 2 index, DE = item 1 address
; End of function file_seek_record


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : file_compute_block_offset
; Purpose  : Compute direct memory address for item at index HL: base + (HL-1)*size
; Inputs   : HL = 1-based item index
; Outputs  : HL = item memory address
; Modifies : All registers
;============================================================================
file_compute_block_offset:			; CODE XREF: file_open_for_transmit+45 (call)
					; file_seek_record (call)
		push	de			; Preserve DE
		dec	hl			; HL = index - 1 (0-based)
		ld	d, h			; DE = index - 1
		ld	e, l
		ld	bc, (sort_item_size)	; BC = item size
		ld	hl, 0FFE5h		; Threshold check (-27)
		add	hl, bc
		ld	hl, 0			; Initialize product = 0
		jr	nc, file_compute_b_br_2	; If small size, use shift/add multiply
		ld	a, 10h			; 16-bit shift/add loop counter

file_compute_b_step_1:				; CODE XREF: file_compute_block_offset+1B (jump)
		add	hl, hl			; Shift product left
		ex	de, hl
		add	hl, hl			; Shift multiplier left
		ex	de, hl
		jr	nc, file_compute_b_br_1 ; If bit not set, skip add
		add	hl, bc			; Add multiplicand to product

file_compute_b_br_1:				; CODE XREF: file_compute_block_offset+17 (jump)
		dec	a			; Decrement bit counter
		jr	nz, file_compute_b_step_1 ; Loop for all 16 bits
		jr	file_compute_b_step_3	; Add base address

file_compute_b_step_2:				; CODE XREF: file_compute_block_offset+23 (jump)
		dec	bc			; Decrement multiplicand
		add	hl, de			; Repeated addition multiply

file_compute_b_br_2:				; CODE XREF: file_compute_block_offset+F (jump)
		ld	a, b			; Multiplicand reaches 0?
		or	c
		jr	nz, file_compute_b_step_2 ; Loop until multiplied

file_compute_b_step_3:				; CODE XREF: file_compute_block_offset+1D (jump)
		ld	de, (sort_table_base)	; DE = base address of items
		add	hl, de			; HL = base + (index - 1) * size
		pop	de			; Restore DE
		ret				; Return
; End of function file_compute_block_offset


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : file_read_block_buffered
; Purpose  : Compare two items via callback function (sort compare step)
; Inputs   : HL = item 1 index, DE = item 2 index
; Outputs  : Flags returned from comparison callback
; Modifies : All registers
;============================================================================
file_read_block_buffered:			; CODE XREF: file_stream_read_record+37 (call)
		push	hl			; Preserve HL
		push	de			; Preserve DE
		ld	bc, file_stream_exit	; Tail-call cleanup on stack
		push	bc
		ld	a, (sort_indirect_flag) ; Indirect sort active?
		or	a
		jr	nz, file_read_bloc_call_1 ; If indirect, resolve pointers from table
		call	file_seek_record	; If direct, compute item addresses
		jr	file_read_bloc_step_1	; Jump to callback invocation

file_read_bloc_call_1:				; CODE XREF: file_read_block_buffered+A (jump)
		call	file_advance_block	; HL = pointer 1 address in pointer table
		ex	de, hl			; DE = pointer 1 address
		dec	hl			; Offset adjustment
		add	hl, hl			; (index 2 - 1) * 2
		add	hl, bc			; HL = pointer 2 address in pointer table
		ld	c, (hl)			; BC = target pointer 2
		inc	hl
		ld	b, (hl)
		ex	de, hl			; HL = pointer 1 address
		ld	e, (hl)			; DE = target pointer 1
		inc	hl
		ld	d, (hl)
		ld	h, b			; HL = target pointer 2
		ld	l, c

file_read_bloc_step_1:				; CODE XREF: file_read_block_buffered+F (jump)
		push	hl			; Push item 2 address
		ld	hl, (sort_compare_func) ; HL = comparison callback function pointer
		ex	(sp), hl			; Push callback and restore HL = item 2 address
		ret				; Indirect call to comparison function via ret
; End of function file_read_block_buffered


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : file_advance_block
; Purpose  : Compute pointer table address for index HL: (sort_ptr_table) + (HL-1)*2
; Inputs   : HL = 1-based index
; Outputs  : HL = pointer table address
; Modifies : BC, HL
;============================================================================
file_advance_block:				; CODE XREF: file_open_for_transmit+3D (call)
					; file_open_for_transmit+55 (call) ...
		dec	hl			; HL = index - 1
		add	hl, hl			; HL = (index - 1) * 2
		ld	bc, (sort_ptr_table)	; BC = base of pointer table
		add	hl, bc			; HL = pointer table address
		ret				; Return
; End of function file_advance_block


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : file_stream_init
; Purpose  : Load 12-byte sort descriptor block into internal state variables
; Inputs   : DE = pointer to 12-byte sort descriptor
; Outputs  : Internal sort variables (2755h..2760h) populated
; Modifies : BC, DE, HL
;============================================================================
file_stream_init:				; CODE XREF: dir_partition+3 (call)
					; file_open_for_transmit+7 (call)
		ex	de, hl			; HL = descriptor pointer
		ld	(sort_desc_caller_ptr), hl ; Save caller descriptor pointer
		ld	de, sort_desc_base	; DE = internal descriptor buffer (2755h)

file_stream_in_step_1:				; CODE XREF: file_stream_read_next+7 (jump)
		ld	bc, 0Ch			; 12 bytes
		ldir				; Copy descriptor block
		ret				; Return
; End of function file_stream_init


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : file_stream_read_next
; Purpose  : Restore internal sort descriptor block back to caller structure
; Inputs   : None
; Outputs  : Caller descriptor updated from internal state
; Modifies : BC, DE, HL
;============================================================================
file_stream_read_next:				; CODE XREF: dir_partition+43 (call)
		ld	hl, sort_desc_base	; HL = internal descriptor (2755h)
		ld	de, (sort_desc_caller_ptr) ; DE = caller descriptor pointer
		jr	file_stream_in_step_1	; Copy 12 bytes back
; End of function file_stream_read_next


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : file_stream_read_record
; Purpose  : Shell sort implementation (gap = N/2, odd gap sequence)
; Inputs   : Internal sort descriptor initialized
; Outputs  : Items sorted in ascending order
; Modifies : All registers
;
; C-Equivalent Algorithm:
;   void shell_sort(int count) {
;       int gap = count;
;       while (1) {
;           gap = gap / 2;
;           if (gap == 0) break;
;           if ((gap & 1) == 0) gap--; // force odd gap sequence
;           for (int i = gap + 1; i <= count; i++) {
;               for (int j = i - gap; j > 0; j -= gap) {
;                   if (compare(j, j + gap) <= 0) break;
;                   swap(j, j + gap);
;               }
;           }
;       }
;   }
;============================================================================
file_stream_read_record:			; CODE XREF: file_open_for_transmit+A (call)
		ld	hl, (sort_item_count)	; HL = item count N
		ld	(sort_index), hl		; Initialize sort_index = N

file_stream_read_loop:				; CODE XREF: file_stream_read_record+29 (jump)
		ld	hl, (sort_index)		; Gap = sort_index / 2
		srl	h			; Shift right 1 bit
		rr	l
		ld	a, l			; Is gap == 0?
		or	h
		ret	z			; If gap == 0, sort is complete!
		bit	0, l			; Is gap odd?
		jr	nz, file_stream_re_step_1 ; If odd, keep it
		dec	hl			; If even, decrement to make odd (classic Shell sort optimization)

file_stream_re_step_1:				; CODE XREF: file_stream_read_record+12 (jump)
		ld	(sort_index), hl		; Save current gap
		ld	(sort_gap), hl		; Initialize outer loop index = gap

file_stream_re_step_2:				; CODE XREF: file_stream_read_record+31 (jump)
					; file_stream_read_record+33 (jump) ...
		ld	hl, (sort_gap)		; Increment outer loop index
		inc	hl
		ld	(sort_gap), hl
		ex	de, hl			; DE = outer loop index
		ld	hl, (sort_item_count)	; Compare against item count N
		or	a			; Clear Carry
		sbc	hl, de			; Count - index
		jr	c, file_stream_read_loop ; If index > count, reduce gap

file_stream_re_step_3:				; CODE XREF: file_stream_read_record+3F (jump)
		ld	hl, (sort_index)		; HL = current gap
		ex	de, hl			; DE = gap, HL = inner index
		sbc	hl, de			; Inner index -= gap
		jr	c, file_stream_re_step_2 ; If below start, advance outer index
		jr	z, file_stream_re_step_2
		ex	de, hl			; DE = adjusted inner index
		add	hl, de			; HL = inner index + gap
		call	file_read_block_buffered ; Compare item(inner) with item(inner + gap)
		jr	nc, file_stream_re_step_2 ; If in order, advance outer index
		call	file_read_header_info	; If out of order, swap item(inner) with item(inner + gap)
		jr	file_stream_re_step_3	; Bubble backward by gap
; End of function file_stream_read_record


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : cpm_bdos_read_record
; Purpose  : Execute BDOS function 20 (F_READ) / sequential disk record read
; Inputs   : DE = FCB pointer
; Outputs  : A = 0 on success, NZ on EOF/error
; Modifies : All registers
;============================================================================
cpm_bdos_read_record:				; CODE XREF: tx_file_transfer+23 (call)
		push	hl			; Preserve HL
		call	cpm_set_dma_buffer	; Set channel 1 buffer DMA address
		call	cpm_bdos_file_read_loop	; Read record via buffered channel 1
		pop	hl			; Restore HL
		ret	nz			; Return error if read failed
		cpl				; Invert status byte
		ld	(cpm_dma_sector_count), a ; Save updated sector count
		cpl				; Restore original A (0)
		ret				; Return
; End of function cpm_bdos_read_record

;----------------------------------------------------------------------------

;============================================================================
; Function : cpm_ch2_read_record
; Purpose  : Read multi-sector block on file channel 2
; Inputs   : DE = FCB pointer
; Outputs  : A = 0 on success, NZ on error
;============================================================================
cpm_ch2_read_record:
		push	hl			; Preserve HL
		call	cpm_ch2_set_dma		; Set channel 2 buffer DMA address
		call	cpm_ch2_read_block	; Read block via buffered channel 2
		pop	hl			; Restore HL
		ret	nz			; Return error if read failed
		cpl				; Invert status byte
		ld	(cpm_ch2_sector_count), a ; Save updated channel 2 sector count
		cpl				; Restore original A (0)
		ret				; Return

cpm_ch1_read_buffered_byte:
		push	hl			; Preserve HL
		call	cpm_set_dma_buffer	; Set channel 1 buffer DMA address
		jp	cpm_ch1_get_byte		; Fetch next byte from channel 1 buffer

cpm_ch2_write_buffered_byte:
		push	hl			; Preserve HL
		push	af			; Preserve byte to write
		call	cpm_ch2_set_dma		; Set channel 2 buffer DMA address
		pop	af			; Restore byte
		jp	cpm_ch2_put_byte_entry	; Write byte into channel 2 buffer

;============================================================================
; Function : cpm_bdos_open_file
; Purpose  : Execute BDOS function 15 (F_OPEN) with multi-sector mode setup
; Inputs   : DE = FCB pointer
; Outputs  : A = 0 on success, 0FFh on error
; Modifies : All registers
;============================================================================
cpm_bdos_open_file:				; CODE XREF: tx_batch_engine+24 (call)
		push	hl			; Preserve HL
		call	cpm_set_dma_buffer	; Initialize channel 1 DMA buffer
		call	nz, cpm_bdos_file_open_retry ; If previously open, close and reopen
		pop	hl			; Restore HL
		ret	nz			; Return error if open failed
		ld	(cpm_dma_sector_count), a ; Reset channel 1 sector count
		ret				; Return
; End of function cpm_bdos_open_file

;----------------------------------------------------------------------------

;============================================================================
; Function : cpm_ch2_open_file
; Purpose  : Open file on channel 2 with flush and retry
; Inputs   : DE = FCB pointer
; Outputs  : A = 0 on success, NZ on error
;============================================================================
cpm_ch2_open_file:
		push	hl			; Preserve HL
		call	cpm_ch2_set_dma		; Initialize channel 2 DMA buffer
		call	nz, cpm_ch2_open_retry ; If previously open, flush and reopen
		pop	hl			; Restore HL
		ret	nz			; Return error if open failed
		ld	(cpm_ch2_sector_count), a ; Reset channel 2 sector count
		ret				; Return

;============================================================================
; Function : cpm_set_dma_buffer
; Purpose  : Set active DMA transfer address for Channel 1
; Inputs   : None
; Outputs  : HL = cpm_ch1_control_block, flags set
; Modifies : A, HL
;============================================================================
cpm_set_dma_buffer:				; CODE XREF: cpm_bdos_read_record+1 (call)
					; cpm_bdos_open_file+1 (call)
		ld	hl, cpm_ch1_control_block ; HL points to channel 1 control block
		ld	a, (cpm_dma_sector_count) ; Load active sector count
		ld	(hl), a			; Store into control block header
		or	a			; Test sector count
		ret				; Return
; End of function cpm_set_dma_buffer

;----------------------------------------------------------------------------

;============================================================================
; Function : cpm_ch2_set_dma
; Purpose  : Set DMA address and sector count for Channel 2
; Inputs   : None
; Outputs  : HL = cpm_ch2_control_block, flags set
; Modifies : A, HL
;============================================================================
cpm_ch2_set_dma:
		ld	hl, cpm_ch2_control_block ; HL points to channel 2 control block
		ld	a, (cpm_ch2_sector_count) ; Load active sector count
		ld	(hl), a			; Store into control block header
		or	a			; Test sector count
		ret				; Return
cpm_dma_sector_count:	.db 0			; Channel 1 sector count (0x1C35)
cpm_ch2_sector_count:	.db 0			; Channel 2 sector count (0x1C36)

;============================================================================
; Function : cpm_bdos_file_read_loop
; Purpose  : Open file and initialize read buffer on Channel 1
; Inputs   : DE = FCB pointer, HL = control block pointer
; Outputs  : A = 0 on success, NZ on error
; Modifies : All registers
;============================================================================
cpm_bdos_file_read_loop:			; CODE XREF: cpm_bdos_read_record+4 (call)
		push	bc			; Preserve BC
		push	de			; Preserve FCB pointer
		ld	a, (hl)			; Check buffer state flag
		or	a
		ld	a, 7			; Error code 7 (already open)
		jr	nz, cpm_bdos_file_br_1 ; If already open, abort
		ld	(cpm_active_buf_ptr), hl ; Save active channel buffer pointer
		inc	hl			; Advance past header to FCB area (+4)
		inc	hl
		inc	hl
		inc	hl
		push	hl			; Preserve destination FCB pointer
		ld	bc, FCB_SIZE		; 36 bytes (CP/M FCB length)
		ex	de, hl			; HL = source FCB, DE = destination FCB
		ldir				; Copy caller FCB into channel control block
		pop	de			; Restore DE = channel FCB pointer
		call	cpm_restore_user_drive	; Set drive and user area for FCB
		call	bdos_open_file_raw	; Open file via BDOS Function 15
		ld	a, 3			; Error code 3 (open failed)
		jr	nz, cpm_bdos_file_br_1 ; If open failed, exit
		call	cpm3_get_dpb_info	; Read first block into buffer
		ld	a, 4			; Error code 4 (read failed)
		jr	nz, cpm_bdos_file_br_1 ; If read failed, exit

cpm_file_init_buffer_state:
		ld	hl, (cpm_active_buf_ptr) ; HL = active control block
		ld	(hl), 0FFh		; Mark buffer as active/open
		inc	hl
		ld	(hl), 80h		; Initialize buffer pointer index (128 bytes)
		inc	hl
		ex	de, hl			; DE points into control block
		ld	hl, CIO_BUF_OFF		; Offset to sector data buffer (+38)
		add	hl, de			; HL points to sector data buffer
		ex	de, hl			; Swap: DE = buffer data, HL = control block
		ld	(hl), e			; Store data pointer low byte
		inc	hl
		ld	(hl), d			; Store data pointer high byte
		xor	a			; Return success (A = 0)

cpm_bdos_file_br_1:				; CODE XREF: cpm_bdos_file_read_loop+6 (jump)
					; cpm_bdos_file_read_loop+1F (jump) ...
		jp	cpm_bdos_file_step_2	; Exit with status in A
; End of function cpm_bdos_file_read_loop

;----------------------------------------------------------------------------

;============================================================================
; Function : cpm_ch2_read_block
; Purpose  : Create/open file on Channel 2 and initialize write buffer
; Inputs   : DE = FCB pointer, HL = control block pointer
; Outputs  : A = 0 on success, NZ on error
;============================================================================
cpm_ch2_read_block:
		push	bc			; Preserve BC
		push	de			; Preserve FCB pointer
		ld	a, (hl)			; Check buffer state flag
		or	a
		ld	a, 7			; Error code 7 (already open)
		jr	nz, cpm_bdos_file_br_1 ; If already open, abort
		ld	(cpm_active_buf_ptr), hl ; Save active channel buffer pointer
		inc	hl			; Advance past header to FCB area (+4)
		inc	hl
		inc	hl
		inc	hl
		push	hl			; Preserve destination FCB pointer
		ld	bc, FCB_SIZE		; 36 bytes (CP/M FCB length)
		ex	de, hl			; HL = source FCB, DE = destination FCB
		ldir				; Copy caller FCB into channel control block
		pop	de			; Restore DE = channel FCB pointer
		call	cpm_restore_user_drive	; Set drive and user area for FCB
		call	bdos_make_file		; Create file via BDOS Function 22 (Make File)
		jr	z, cpm_file_init_buffer_state ; If created, initialize buffer
		ld	a, 5			; Error code 5 (create failed)
		jr	cpm_bdos_file_br_1	; Abort

;============================================================================
; Function : cpm_ch1_get_byte
; Purpose  : Read next single byte from Channel 1 buffered file stream
; Inputs   : HL = cpm_ch1_control_block
; Outputs  : A = byte read, NZ on EOF/error
; Modifies : All registers
;============================================================================
cpm_ch1_get_byte:
		push	bc			; Preserve BC
		push	de			; Preserve DE
		ld	a, (hl)			; Check if file is open
		or	a
		ld	a, 1			; Error 1 (file not open)
		jr	z, cpm_byte_exit_status ; Return error if not open
		ld	(cpm_active_buf_ptr), hl ; Save active buffer pointer
		inc	hl			; Advance to buffer data pointer (+2)
		inc	hl
		ld	e, (hl)			; DE = current buffer data pointer
		inc	hl
		ld	d, (hl)
		ld	a, d			; Pointer null?
		or	e
		ld	a, 4			; Error 4 (buffer empty / EOF)
		jr	z, cpm_byte_exit_status ; Exit if null
		ld	a, (de)			; Fetch byte from buffer
		ld	(cpm_io_last_byte), a	; Save byte
		inc	de			; Advance buffer pointer
		ld	(hl), d			; Save updated pointer
		dec	hl
		ld	(hl), e
		dec	hl			; Point to remaining byte counter
		dec	(hl)			; Decrement byte counter
		jr	nz, cpm_byte_return_saved ; If bytes remain, return saved byte
		ld	(hl), 80h		; Reset sector byte counter = 128
		inc	hl
		ex	de, hl			; Reset buffer pointer to base
		ld	hl, CIO_BUF_OFF
		add	hl, de
		ex	de, hl
		ld	(hl), e
		inc	hl
		ld	(hl), d
		call	cpm3_get_dpb_info	; Refill 128-byte sector from disk
		jr	z, cpm_byte_return_saved ; If refilled successfully, continue
		ld	hl, (cpm_active_buf_ptr) ; On EOF, clear buffer data pointer
		inc	hl
		inc	hl
		ld	(hl), 0
		inc	hl
		ld	(hl), 0

cpm_byte_return_saved:
		ld	a, (cpm_io_last_byte)	; A = saved byte read
		cp	a			; Set Z flag (success)
		jr	cpm_byte_exit_ok	; Exit success

;============================================================================
; Function : cpm_ch2_put_byte
; Purpose  : Write single byte into Channel 2 buffered file stream
; Inputs   : A = byte to write
; Outputs  : A = 0 on success, NZ on error
;============================================================================
cpm_ch2_put_byte:
		push	hl			; Preserve HL
		ld	hl, (cpm_active_buf_ptr) ; HL = active channel 2 buffer

cpm_ch2_put_byte_entry:
		push	bc			; Preserve BC
		push	de			; Preserve DE
		ld	(cpm_io_last_byte), a	; Save byte to write
		ld	a, (hl)			; Check if file is open
		or	a
		ld	a, 1			; Error 1 (file not open)
		jr	z, cpm_byte_exit_status ; Exit if not open
		ld	(cpm_active_buf_ptr), hl ; Save active buffer pointer
		inc	hl			; Advance to buffer data pointer (+2)
		inc	hl
		ld	e, (hl)			; DE = current buffer write pointer
		inc	hl
		ld	d, (hl)
		ld	a, (cpm_io_last_byte)	; Load byte to write
		ld	(de), a			; Write byte into buffer
		inc	de			; Advance buffer pointer
		ld	(hl), d			; Save updated write pointer
		dec	hl
		ld	(hl), e
		dec	hl			; Point to sector byte counter
		dec	(hl)			; Decrement remaining bytes in sector
		jr	nz, cpm_byte_return_saved ; If sector not full, return success
		ld	(hl), 80h		; Reset sector byte counter = 128
		inc	hl
		ex	de, hl			; Reset buffer pointer to base
		ld	hl, CIO_BUF_OFF
		add	hl, de
		ex	de, hl
		ld	(hl), e
		inc	hl
		ld	(hl), d
		call	cpm_dpb_read_seq	; Flush full 128-byte sector to disk
		jr	z, cpm_byte_return_saved ; If written successfully, continue
		ld	a, 2			; Error 2 (write error / disk full)

cpm_byte_exit_status:
		or	a			; Set NZ status flag on error

cpm_byte_exit_ok:
		pop	de			; Restore DE
		pop	bc			; Restore BC
		pop	hl			; Restore HL
		ret				; Return

;============================================================================
; Function : cpm_bdos_file_open_retry
; Purpose  : Close open file on Channel 1 and reset buffer state
; Inputs   : HL = control block pointer
; Outputs  : A = 0 on success, NZ on error
;============================================================================
cpm_bdos_file_open_retry:			; CODE XREF: cpm_bdos_open_file+4 (call)
		push	bc			; Preserve BC
		push	de			; Preserve DE
		ld	a, (hl)			; Check if file is open
		or	a
		jr	z, cpm_bdos_file_step_2 ; If already closed, exit success
		ld	(cpm_active_buf_ptr), hl ; Save active control block pointer
		jr	cpm_bdos_file_step_1	; Jump to close file

;============================================================================
; Function : cpm_ch2_open_retry
; Purpose  : Flush remaining data, pad sector with EOF, and close Channel 2
; Inputs   : HL = control block pointer
; Outputs  : A = 0 on success, NZ on error
;============================================================================
cpm_ch2_open_retry:
		push	bc			; Preserve BC
		push	de			; Preserve DE
		ld	a, (hl)			; Check if file is open
		or	a
		jr	z, cpm_bdos_file_step_2 ; If already closed, exit success
		ld	(cpm_active_buf_ptr), hl ; Save active control block pointer
		inc	hl			; Check sector byte count
		ld	a, (hl)
		cp	80h			; Is sector buffer empty (count == 128)?
		jr	z, cpm_ch2_open_flush_done ; If empty, no padding needed
		ld	a, 1Ah			; Pad with CP/M EOF character (Ctrl-Z = 1Ah)
		call	cpm_ch2_put_byte	; Write EOF character

cpm_ch2_open_flush_loop:
		ld	a, (hl)			; Check sector byte count
		cp	80h			; Reached sector boundary?
		jr	z, cpm_ch2_open_flush_done ; When boundary reached, sector flushed
		xor	a			; Pad remainder of sector with 00h
		call	cpm_ch2_put_byte
		jr	cpm_ch2_open_flush_loop ; Loop until sector boundary

cpm_ch2_open_flush_done:

cpm_bdos_file_step_1:				; CODE XREF: cpm_bdos_file_open_retry+9 (jump)
		ld	hl, (cpm_active_buf_ptr) ; HL = active control block
		ld	(hl), 0			; Mark buffer as closed
		inc	hl			; Advance past header to FCB (+4)
		inc	hl
		inc	hl
		inc	hl
		ex	de, hl			; DE = FCB pointer
		call	bdos_close_file		; Close file via BDOS Function 16
		ld	a, 6			; Error code 6 (close failed)
		jr	nz, cpm_bdos_file_step_2 ; If close failed, return error
		xor	a			; Return success (A = 0)

cpm_bdos_file_step_2:				; CODE XREF: cpm_bdos_file_read_loop+3B (jump)
					; cpm_bdos_file_open_retry+4 (jump) ...
		pop	de			; Restore DE
		pop	bc			; Restore BC
		or	a			; Set flags based on status code
		ret				; Return
; End of function cpm_bdos_file_open_retry


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : cpm3_get_dpb_info
; Purpose  : Read sequential record from open file into active channel buffer
; Inputs   : (cpm_active_buf_ptr) = active channel control block
; Outputs  : A = 0 on success, NZ on EOF/error
; Modifies : All registers
;============================================================================
cpm3_get_dpb_info:				; CODE XREF: cpm_bdos_file_read_loop+21 (call)
		ld	hl, (cpm_active_buf_ptr) ; HL = active channel control block
		ld	de, 28h			; Offset to sector data buffer (+40)
		add	hl, de			; HL points to sector DMA buffer
		call	bdos_set_dma_addr	; Set DMA address via BDOS Function 26
		ld	de, (cpm_active_buf_ptr) ; DE = control block
		inc	de			; Advance past header to FCB (+4)
		inc	de
		inc	de
		inc	de
		call	bdos_read_random_record	; Read sequential record via BDOS Function 20
		jr	cpm3_get_dpb_i_call_1	; Restore DMA buffer and exit

cpm_dpb_read_seq:
		ld	hl, (cpm_active_buf_ptr) ; HL = active channel control block
		ld	de, 28h			; Offset to sector data buffer (+40)
		add	hl, de			; HL points to sector DMA buffer
		call	bdos_set_dma_addr	; Set DMA address via BDOS Function 26
		ld	de, (cpm_active_buf_ptr) ; DE = control block
		inc	de			; Advance past header to FCB (+4)
		inc	de
		inc	de
		inc	de
		call	bdos_write_seq_record	; Write sequential record via BDOS Function 21

cpm3_get_dpb_i_call_1:				; CODE XREF: cpm3_get_dpb_info+15 (jump)
		push	af			; Preserve BDOS return status
		ld	hl, 80h			; Restore default DMA buffer address (0080h)
		call	bdos_set_dma_addr
		pop	af			; Restore status
		or	a			; Set flags
		ret				; Return
; End of function cpm3_get_dpb_info


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : bdos_call_wrapper
; Purpose  : Query current drive (BDOS 25) and user area (BDOS 32)
; Inputs   : None
; Outputs  : B = current drive (0..15), C = current user area (0..31)
; Modifies : A, BC
;============================================================================
get_cur_drive_user:
bdos_call_wrapper:				; CODE XREF: parse_fcb_drive_user+8 (call)
					; init_fcb_spaces+A (call)
		push	af			; Preserve AF
		push	de			; Preserve DE
		push	hl			; Preserve HL
		ld	c, 19h			; BDOS Function 25: Return Current Disk
		call	bdos_con_write_char	; Returns current drive in A (0=A, 1=B...)
		push	af			; Preserve drive number
		ld	e, 0FFh			; 0FFh = query current user area
		ld	c, 20h			; BDOS Function 32: Get/Set User Code
		call	bdos_con_write_char	; Returns current user area in A
		ld	c, a			; C = user area (0..31)
		pop	af			; Restore drive number
		ld	b, a			; B = drive number (0..15)
		pop	hl			; Restore HL
		pop	de			; Restore DE
		pop	af			; Restore AF
		ret				; Return
; End of function bdos_call_wrapper


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : bdos_compute_file_size
; Purpose  : Compute total file size in records via BDOS function 35 (F_SIZE)
; Inputs   : DE = FCB pointer
; Outputs  : Random record bytes 33-35 set in FCB, HL = size in records
; Modifies : All registers
;============================================================================
bdos_compute_file_size:				; CODE XREF: tx_file_transfer+3 (call)
		ld	a, F_SIZE		; BDOS Function 35: Compute File Size (F_SIZE)
		jr	bdos_compute_size_call	; Execute call

bdos_set_random_record:
		ld	a, F_RANDREC		; BDOS Function 36: Set Random Record (F_RANDREC)

bdos_compute_size_call:				; CODE XREF: bdos_compute_file_size+2 (jump)
		push	de			; Preserve caller FCB pointer
		push	bc			; Preserve BC
		push	af			; Preserve function code in A
		ld	hl, cpm_io_scratch_fcb	; Destination = scratch FCB buffer
		ld	bc, FCB_SIZE		; 36 bytes (FCB length)
		push	hl			; Preserve scratch FCB pointer
		ex	de, hl			; HL = caller FCB, DE = scratch FCB
		ldir				; Copy caller FCB into scratch buffer
		pop	de			; DE = scratch FCB pointer
		pop	af			; A = BDOS function code
		call	bdos_sys_call		; Execute BDOS call
		ld	hl, 21h			; Offset 33 (21h) = random record field (R0, R1)
		add	hl, de			; HL points to random record count in FCB
		ld	e, (hl)			; E = low byte of record count
		inc	hl
		ld	d, (hl)			; D = high byte of record count
		inc	hl
		ld	a, (hl)			; A = overflow byte (R2)
		ex	de, hl			; HL = total 128-byte record count
		pop	bc			; Restore BC
		pop	de			; Restore caller FCB pointer
		or	a			; Set flags
		ret				; Return
; End of function bdos_compute_file_size

;----------------------------------------------------------------------------
; Function : bdos_make_file
; Purpose  : Open existing file or create new file via BDOS Function 22 (F_MAKE)
; Inputs   : DE = FCB pointer
; Outputs  : A = 0 on success, 0FFh on error
;----------------------------------------------------------------------------
bdos_make_file:
		call	bdos_open_file_raw	; Attempt to open existing file (BDOS 15)
		ret	z			; If opened successfully, return (Z flag set)
		ld	a, 16h			; BDOS Function 22: Make File (F_MAKE)
		jp	bdos_open_file_call	; Create file and return

;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : bdos_close_file
; Purpose  : Close open file via BDOS function 16 (F_CLOSE)
; Inputs   : DE = FCB pointer
; Outputs  : File closed in CP/M filesystem
; Modifies : All registers
;============================================================================
bdos_close_file:				; CODE XREF: cpm_bdos_file_open_retry+34 (call)
		ld	a, 10h			; BDOS Function 16: Close File (F_CLOSE)
		jp	bdos_open_file_call	; Execute call
; End of function bdos_close_file


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : bdos_open_file_raw
; Purpose  : Open existing file via BDOS function 15 (F_OPEN)
; Inputs   : DE = FCB pointer
; Outputs  : File opened in CP/M
; Modifies : All registers
;============================================================================
bdos_open_file_raw:				; CODE XREF: cpm_bdos_file_read_loop+1A (call)
		ld	a, 0Fh			; BDOS Function 15: Open File (F_OPEN)

bdos_open_file_call:				; CODE XREF: bdos_close_file+2 (jump)
		call	bdos_sys_call		; Execute BDOS file operation
		ret	m			; Return negative (0FFh) on error
		xor	a			; Return 0 on success (Z flag set)
		ret				; Return
; End of function bdos_open_file_raw


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : bdos_read_random_record
; Purpose  : Read sequential record from disk via BDOS function 20 (F_READ)
; Inputs   : DE = FCB pointer
; Outputs  : Record read into DMA buffer
; Modifies : All registers
;============================================================================
bdos_read_random_record:			; CODE XREF: cpm3_get_dpb_info+12 (call)
		ld	a, 14h			; BDOS Function 20: Read Sequential (F_READ)
		jp	bdos_sys_call		; Execute call
; End of function bdos_read_random_record

;----------------------------------------------------------------------------
; Function : bdos_write_seq_record
; Purpose  : Write sequential record to disk via BDOS function 21 (F_WRITE)
; Inputs   : DE = FCB pointer
; Outputs  : Return code in A
;----------------------------------------------------------------------------
bdos_write_seq_record:
		ld	a, 15h			; BDOS Function 21: Write Sequential (F_WRITE)
		jp	bdos_sys_call		; Execute call

;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : bdos_set_dma_addr
; Purpose  : Set DMA buffer address via BDOS function 26 (F_DMAOFF)
; Inputs   : HL = DMA address
; Outputs  : DMA buffer address configured
; Modifies : A, C, DE
;============================================================================
bdos_set_dma_addr:				; CODE XREF: cpm3_get_dpb_info+7 (call)
					; cpm3_get_dpb_info+30 (call)
		push	af			; Preserve AF
		ld	a, 1Ah			; BDOS Function 26: Set DMA Address (F_DMAOFF)
		ex	de, hl			; DE = DMA address
		call	bdos_sys_call		; Execute BDOS call
		ex	de, hl			; Restore DE
		pop	af			; Restore AF
		ret				; Return
; End of function bdos_set_dma_addr


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : cpm_restore_user_drive
; Purpose  : Zero out FCB extent and record allocation fields before opening
; Inputs   : DE = FCB pointer
; Outputs  : Allocation bytes 12..32 in FCB cleared to zero
; Modifies : All registers
;============================================================================
cpm_restore_user_drive:			; CODE XREF: cpm_bdos_file_read_loop+17 (call)
		push	hl			; Preserve HL
		push	de			; Preserve DE
		push	af			; Preserve AF
		ex	de, hl			; HL points to FCB
		ld	de, 0Ch			; Offset 12 (extent field)
		ld	(hl), d			; Clear byte 0 (drive)
		add	hl, de			; HL points to byte 12 (EX)
		ld	e, 15h			; Clear 21 bytes (12..32)

cpm_restore_us_step_1:				; CODE XREF: cpm_restore_user_drive+E (jump)
		ld	(hl), d			; Zero byte (D = 0)
		inc	hl			; Advance pointer
		dec	e			; Decrement loop counter
		jr	nz, cpm_restore_us_step_1 ; Loop until all 21 bytes cleared
		pop	af			; Restore AF
		pop	de			; Restore DE
		pop	hl			; Restore HL
		ret				; Return
; End of function cpm_restore_user_drive


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

#include "num_ascii.inc"


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

#include "strlen.inc"

;----------------------------------------------------------------------------
; Function : print_inline_str_z
; Purpose  : Print string to console up to null terminator or non-printable char
; Inputs   : HL = string pointer
; Outputs  : Characters output to console
;----------------------------------------------------------------------------
print_inline_str_z:
		push	af			; Preserve AF

print_inline_str_z_loop:
		ld	a, (hl)			; Fetch character
		inc	hl			; Advance pointer
		or	a			; Null terminator?
		jr	z, calc_strlen_lo_step_1 ; If null, exit
		call	memcpy_string		; Check printable character
		jr	z, print_inline_str_z_loop ; If printable, loop

calc_strlen_lo_step_1:				; CODE XREF: print_inline_string+4 (jump)
					; print_inline_string+B (jump)
		dec	hl			; Point back to terminator
		pop	af			; Restore AF
		ret				; Return

;============================================================================
; Function : print_inline_string
; Purpose  : Print string at HL to console until delimiter reached
; Inputs   : HL = string pointer
; Outputs  : String displayed on console
; Modifies : A, HL
;============================================================================
print_inline_string:				; CODE XREF: tx_send_file_data+20 (call)
					; tx_send_file_data+54 (call) ...
		push	af			; Preserve AF

print_inline_loop:				; CODE XREF: print_inline_string+9 (jump)
		ld	a, (hl)			; Fetch character
		inc	hl			; Advance pointer
		or	a			; Null terminator?
		jr	z, calc_strlen_lo_step_1 ; If null, finish
		call	memcpy_string		; Check printable character
		jr	nz, print_inline_loop	; If printable, continue
		jr	calc_strlen_lo_step_1	; If non-printable delimiter, exit
; End of function print_inline_string


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

#include "cmdline.inc"
#include "memset.inc"

;----------------------------------------------------------------------------
; Function : is_alpha_char
; Purpose  : Test if character in A is alphabetic ('A'..'Z' or 'a'..'z')
; Inputs   : A = ASCII character
; Outputs  : Z flag set if alphabetic, NZ if not; A preserved
; Modifies : Flags
;----------------------------------------------------------------------------
is_alpha_char:
memset_loop_step_1:				; CODE XREF: tx_send_file_data+12 (call)
		push	bc			; Preserve BC
		ld	c, a			; Save original character in C
		and	7Fh			; Mask 7-bit ASCII
		call	to_upper		; Convert lowercase to uppercase
		cp	'A'			; Less than 'A'?
		jr	c, is_not_alpha		; If < 'A', not alphabetic
		cp	'Z'+1			; Less than or equal to 'Z'?
		jr	c, is_alpha		; If <= 'Z', is alphabetic

is_not_alpha:
unk_0_1F1F:	.db	0F6h			; Opcode for 'or n' (absorbs next byte: xor a = AFh, sets NZ)

is_alpha:
unk_0_1F1F_step_1:
		xor	a			; Set Zero flag (is alphabetic character)
		ld	a, c			; Restore original character in A
		pop	bc			; Restore BC
		ret				; Return

;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : memcpy_string
; Purpose  : Classify ASCII character in A as whitespace/control vs printable
; Inputs   : A = character
; Outputs  : Z flag if whitespace (null, DEL, space, tabs), NZ if printable
; Modifies : Flags
;============================================================================
memcpy_string:				; CODE XREF: print_inline_string+6 (call)
		push	af			; Preserve AF
		and	7Fh			; Mask 7-bit ASCII
		jr	z, memcpy_string_step_1 ; Null character -> Z flag
		cp	7Fh			; DEL (rubout)?
		jr	z, memcpy_string_step_1 ; DEL -> Z flag
		cp	' '			; Space?
		jr	z, memcpy_string_step_1 ; Space -> Z flag
		cp	8			; Backspace or lower?
		jr	c, memcpy_string_step_2 ; Control char -> NZ flag
		cp	0Eh			; Tab, LF, VT, FF, CR (8..13)?
		jr	nc, memcpy_string_step_2 ; Printable char -> NZ flag

memcpy_string_step_1:				; CODE XREF: memcpy_string+3 (jump)
					; memcpy_string+7 (jump) ...
		pop	af			; Restore AF
		cp	a			; Set Z flag (whitespace/control delimiter)
		ret				; Return

memcpy_string_step_2:				; CODE XREF: memcpy_string+F (jump)
					; memcpy_string+13 (jump)
		pop	af			; Restore AF
		or	a			; Set NZ flag (printable character)
		ret				; Return
; End of function memcpy_string


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

#include "to_upper.inc"


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : get_top_of_tpa
; Purpose  : Read top of available Transient Program Area (TPA) from BDOS vector
; Inputs   : None
; Outputs  : HL = top of TPA address
; Modifies : A, HL
;============================================================================
get_top_of_tpa:				; CODE XREF: dir_entry_insert+33 (call)
		ld	hl, (6)			; Address of BDOS entry vector at 0006h
		ld	l, 0			; Page-align to 256-byte boundary
		ld	a, (2)			; Warm boot vector page at 0002h
		sub	16h			; Safety margin below BIOS
		cp	h			; Compare against BDOS page
		ret	nc			; If BDOS page is lower, use BDOS page
		ld	h, a			; Otherwise use BIOS margin page
		ret				; Return
; End of function get_top_of_tpa


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : check_wildcard_char
; Purpose  : Compare characters at HL and DE with '?' wildcard support for B bytes
; Inputs   : HL = pattern pointer, DE = target pointer, B = character count
; Outputs  : Z flag set if all B characters match, NZ if mismatch
; Modifies : A, B, C, DE, HL
;============================================================================
check_wildcard_char:				; CODE XREF: dir_sort_table+16 (call)
					; dir_sort_table+27 (call) ...
		ld	a, (hl)			; Fetch pattern character
		and	7Fh			; Mask 7-bit ASCII
		cp	'?'			; Question mark wildcard?
		jr	z, check_wildcard_loop_1 ; If '?', matches any character
		ld	c, a			; C = pattern character
		ld	a, (de)			; Fetch target character
		and	7Fh			; Mask 7-bit ASCII
		cp	c			; Compare characters
		ret	nz			; Return mismatch (NZ flag)

check_wildcard_loop_1:				; CODE XREF: check_wildcard_char+5 (jump)
		inc	hl			; Advance pattern pointer
		inc	de			; Advance target pointer
		djnz	check_wildcard_char	; Loop for all B characters
		ret				; Return match (Z flag)
; End of function check_wildcard_char


;----------------------------------------------------------------------------

;		S u b r	o u t i	n e

;============================================================================
; Function : get_next_token_char
; Purpose  : Compare B characters between HL and DE (case/parity insensitive)
; Inputs   : HL = first string, DE = second string, B = byte count
; Outputs  : Z flag if all B bytes equal, NZ if mismatch
; Modifies : A, B, C, DE, HL
;============================================================================
get_next_token_char:				; CODE XREF: dir_filter_system_files+12 (call)
					; get_next_token_char+B (jump)
		ld	a, (hl)			; Fetch byte from first string
		and	7Fh			; Mask 7-bit ASCII
		ld	c, a			; C = first character
		ld	a, (de)			; Fetch byte from second string
		and	7Fh			; Mask 7-bit ASCII
		cp	c			; Compare characters
		ret	nz			; Return mismatch (NZ)
		inc	hl			; Advance first pointer
		inc	de			; Advance second pointer
		djnz	get_next_token_char	; Loop for all B bytes
		ret				; Return match (Z)
; End of function get_next_token_char

;----------------------------------------------------------------------------
; Free memory heap base pointer and trailing reserved storage
;----------------------------------------------------------------------------
free_mem_base:	.dw	28DCh		; Pointer to start of free TPA heap (28DCh)
		.db	0			; Trailing padding / alignment bytes
		.db	0
		.db	0
		.db	0
		.db	0
		.db	0

		.end	; start


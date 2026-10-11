;============================================================================
; zmodem.inc - ZMODEM Protocol Constants and Frame Definitions
;============================================================================
; Based on the ZMODEM protocol specification by Chuck Forsberg (Omen Tech)
; Reconstructed for Zmodem CP/M suite
; Targets: uz80as / TASM cross-assembler
;============================================================================

;----------------------------------------------------------------------------
; Frame Framing & Control Characters
;----------------------------------------------------------------------------
ZPAD            .equ    2Ah             ; '*' (42) Frame synchronization padding character
ZDLE            .equ    18h             ; Control-X (24) Data Link Escape character
ZDLEE           .equ    58h             ; Escaped ZDLE ('X' ^ 0100h)

; Header Encodings
ZBIN            .equ    41h             ; 'A' (65) Binary frame header with 16-bit CRC
ZHEX            .equ    42h             ; 'B' (66) Hexadecimal frame header with 16-bit CRC
ZBIN32          .equ    43h             ; 'C' (67) Binary frame header with 32-bit CRC
ZBINR32         .equ    44h             ; 'D' (68) Binary frame header with 32-bit CRC (RLE encoded)

;----------------------------------------------------------------------------
; Frame Types (F_TYPE)
;----------------------------------------------------------------------------
ZRQINIT         .equ    0               ; Request receive init from sender
ZRINIT          .equ    1               ; Receiver capabilities declaration
ZSINIT          .equ    2               ; Sender init sequence (optional capabilities)
ZACK            .equ    3               ; Acknowledgment to previous frame
ZFILE           .equ    4               ; File name and metadata subpacket
ZSKIP           .equ    5               ; Receiver skips this file
ZNAK            .equ    6               ; Negative acknowledgment (corrupted frame)
ZABORT          .equ    7               ; Receiver requests session abort
ZFIN            .equ    8               ; Session termination / finish
ZRPOS           .equ    9               ; Resume file transmission at position
ZDATA           .equ    10              ; Data subpacket(s) header with 32-bit file offset
ZEOF            .equ    11              ; End of file header with 32-bit file size
ZFERR           .equ    12              ; Fatal disk or system I/O error
ZCRC            .equ    13              ; Request remote file CRC calculation
ZCHALLENGE      .equ    14              ; Challenge receiver with security sequence
ZCOMPL          .equ    15              ; Request completed
ZCAN            .equ    16              ; Remote end cancelled session (sent 5x CAN)
ZFREECNT        .equ    17              ; Query free disk space on remote system
ZCOMMAND        .equ    18              ; Execute remote command string
ZSTDERR         .equ    19              ; Stream data to remote stderr

;----------------------------------------------------------------------------
; Subpacket Framing End Characters (Follows ZDLE)
;----------------------------------------------------------------------------
ZCRCE           .equ    68h             ; 'h' CRC follows; frame ends; header follows immediately
ZCRCG           .equ    69h             ; 'i' CRC follows; frame continues without waiting for ACK
ZCRCQ           .equ    6Ah             ; 'j' CRC follows; frame continues; sender expects ZACK
ZCRCW           .equ    6Bh             ; 'k' CRC follows; frame ends; sender expects ZACK
ZRUB0           .equ    6Ch             ; 'l' Translate next character to rubout (0177h)
ZRUB1           .equ    6Dh             ; 'm' Translate next character to rubout (0377h)

;----------------------------------------------------------------------------
; Header Flag Byte Positions (in 4-byte header payload)
;----------------------------------------------------------------------------
ZF0             .equ    3               ; Flag byte 0 (LSB / type-dependent flags)
ZF1             .equ    2               ; Flag byte 1 (transfer options)
ZF2             .equ    1               ; Flag byte 2 (transport options)
ZF3             .equ    0               ; Flag byte 3 (MSB / extended flags)

ZP0             .equ    0               ; Position byte 0 (least significant byte)
ZP1             .equ    1               ; Position byte 1
ZP2             .equ    2               ; Position byte 2
ZP3             .equ    3               ; Position byte 3 (most significant byte)

;----------------------------------------------------------------------------
; Receiver Capability Bitmasks (advertised in ZRINIT ZF0)
;----------------------------------------------------------------------------
CANFDX          .equ    01h             ; Rx can handle full duplex communication
CANOVIO         .equ    02h             ; Rx can overlap disk and serial I/O
CANBRK          .equ    04h             ; Rx can send a break signal
CANCRY          .equ    08h             ; Rx can decrypt data stream
CANLZW          .equ    10h             ; Rx can decompress Lempel-Ziv stream
CANFC32         .equ    20h             ; Rx can process 32-bit Frame Check Sequence (CRC-32)
ESCCTL          .equ    40h             ; Control characters (00-1F, 80-9F) must be escaped
ESC8            .equ    80h             ; 8th bit must be escaped (7-bit clean link)

;----------------------------------------------------------------------------
; ZFILE Transfer Mode Flags (ZF0)
;----------------------------------------------------------------------------
ZF0_ZCBIN       .equ    1               ; Binary transfer (no newline or EOF translation)
ZF0_ZCNL        .equ    2               ; Text transfer (convert Unix LF <-> CP/M CR+LF)
ZF0_ZCRESUM     .equ    3               ; Resume interrupted file transfer

;----------------------------------------------------------------------------
; ZFILE File Management Flags (ZF1)
;----------------------------------------------------------------------------
ZF1_ZMNEW       .equ    1               ; Transfer file only if source is newer or longer
ZF1_ZMCRC       .equ    2               ; Transfer file only if CRC or length differs
ZF1_ZMAPND      .equ    3               ; Append received data to destination file
ZF1_ZMCLOB      .equ    4               ; Replace destination unconditionally (clobber)
ZF1_ZMNEWL      .equ    5               ; Transfer file only if source is newer
ZF1_ZMDIFF      .equ    6               ; Transfer file only if date or length differs
ZF1_ZMPROT      .equ    7               ; Protect destination; do not overwrite if exists

;----------------------------------------------------------------------------
; ZFILE Transport Compression Flags (ZF2)
;----------------------------------------------------------------------------
ZF2_ZTLZW       .equ    1               ; Lempel-Ziv compression
ZF2_ZTCRYPT     .equ    2               ; Encryption
ZF2_ZTRLE       .equ    3               ; Run Length Encoding (RLE)

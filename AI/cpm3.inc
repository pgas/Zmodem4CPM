;============================================================================
; cpm3.inc - CP/M 3 (CP/M Plus) System Definitions and BDOS Call Equates
;============================================================================
; Reconstructed for Zmodem CP/M suite
; Targets: uz80as / TASM cross-assembler
;============================================================================

;----------------------------------------------------------------------------
; Page Zero System Vectors & Offsets
;----------------------------------------------------------------------------
cpm             .equ    0000h           ; Warm Boot Jump Vector (0000h: JP BIOS+3)
iobyte          .equ    0004h           ; Intel I/O Byte (CP/M 2.2) / Current Drive & User (CP/M 3)
bdos            .equ    0005h           ; BDOS Function Call Entry Point (0005h: JP BDOS)
default_fcb     .equ    005Ch           ; Default File Control Block 1 (FCB)
default_fcb2    .equ    006Ch           ; Default File Control Block 2 (FCB)
default_dma     .equ    0080h           ; Default DMA / Command Tail Buffer (128 bytes)

;----------------------------------------------------------------------------
; BDOS Console & Character I/O Function Equates
;----------------------------------------------------------------------------
C_READ          .equ    1               ; Function 1: Console Input (waits for char)
C_WRITE         .equ    2               ; Function 2: Console Output (char in E)
A_READ          .equ    3               ; Function 3: Auxiliary / Reader Input
A_WRITE         .equ    4               ; Function 4: Auxiliary / Punch Output
C_RAWIO         .equ    6               ; Function 6: Direct Console I/O
A_STATIN        .equ    7               ; Function 7: Auxiliary Input Status (A=00h not ready, FFh ready)
A_STATOUT       .equ    8               ; Function 8: Auxiliary Output Status (A=00h not ready, FFh ready)
A_STAT_OUT      .equ    8               ; Compatibility alias for A_STATOUT
C_WRITESTR      .equ    9               ; Function 9: Write String to Console (DE points to string ending in '$')
C_STAT          .equ    11              ; Function 11: Console Status (A=00h not ready, FFh ready)
S_BDOSVER       .equ    12              ; Function 12: Return BDOS Version Number (A=30h for CP/M 3.0+)

;----------------------------------------------------------------------------
; BDOS File System & Disk Management Function Equates
;----------------------------------------------------------------------------
DRV_RESET       .equ    13              ; Function 13: Reset Disk System
DRV_SET         .equ    14              ; Function 14: Select Active Disk Drive (E = drive 0=A, 1=B, ...)
F_OPEN          .equ    15              ; Function 15: Open File (DE points to FCB)
F_CLOSE         .equ    16              ; Function 16: Close File (DE points to FCB)
F_SFIRST        .equ    17              ; Function 17: Search for First Directory Match (DE points to FCB)
F_SNEXT         .equ    18              ; Function 18: Search for Next Directory Match
F_DELETE        .equ    19              ; Function 19: Delete File (DE points to FCB)
F_READ          .equ    20              ; Function 20: Read Sequential 128-byte Record
F_WRITE         .equ    21              ; Function 21: Write Sequential 128-byte Record
F_MAKE          .equ    22              ; Function 22: Create New File (DE points to FCB)
DRV_GET         .equ    25              ; Function 25: Return Current Disk Drive (A = 0=A, 1=B, ...)
F_DMAOFF        .equ    26              ; Function 26: Set DMA Offset Buffer Address (DE = buffer)
DRV_DPB         .equ    31              ; Function 31: Return Disk Parameter Block Address (HL = DPB pointer)
F_USERNUM       .equ    32              ; Function 32: Get / Set User Number (E=FFh get, E=0-15 set)
F_READRAND      .equ    33              ; Function 33: Read Random Record
F_SIZE          .equ    35              ; Function 35: Compute File Size in 128-byte records (into FCB r0,r1,r2)
F_RANDREC       .equ    36              ; Function 36: Set Random Record Pointer from FCB sequential pointer
F_MULTISEC      .equ    44              ; Function 44: Set Multi-Sector Count (E = record count 1-128)
S_SYSVAR        .equ    49              ; Function 49: Get / Set System Control Block (SCB) Variables

;----------------------------------------------------------------------------
; CP/M 3 System Control Block (SCB) Field Offsets (Accessed via BDOS 49)
;----------------------------------------------------------------------------
SCB_QERR        .equ    0006h           ; Quiet BDOS error mode flag (00=display, FF=return error code)
SCB_DMAERR      .equ    003Ch           ; DMA boundary / overrun error vector offset
SCB_DISKERR     .equ    003Eh           ; Disk hardware error vector offset

;----------------------------------------------------------------------------
; CP/M File Control Block (FCB) Field Offsets & Constants
;----------------------------------------------------------------------------
FCB_SIZE        .equ    36              ; Standard CP/M FCB size (36 bytes)
FCB_DRV         .equ    0               ; Drive code (0=default, 1=A, 2=B, ...)
FCB_NAME        .equ    1               ; File name (8 ASCII bytes)
FCB_EXT         .equ    9               ; File extension (3 ASCII bytes)
FCB_EX          .equ    12              ; Extent byte (low byte)
FCB_S1          .equ    13              ; Reserved / S1
FCB_S2          .equ    14              ; Reserved / S2 (extent high bits in CP/M 3)
FCB_RC          .equ    15              ; Record count in current extent (0-128)
FCB_AL          .equ    16              ; Allocation block map (16 bytes, d0..d15)
FCB_CR          .equ    32              ; Current record number within extent (0-127)
FCB_R0          .equ    33              ; Random record pointer byte 0 (LSB)
FCB_R1          .equ    34              ; Random record pointer byte 1
FCB_R2          .equ    35              ; Random record pointer byte 2 (MSB / overflow)

;----------------------------------------------------------------------------
; ZCPR3 / Z-System Environment Descriptor Offsets
;----------------------------------------------------------------------------
Z3_NDR_OFF      .equ    15h             ; Named Directory table pointer offset (16-bit word)
Z3_MDRV_OFF     .equ    2Ch             ; Maximum drive number offset (1 byte)
Z3_MUSR_OFF     .equ    2Dh             ; Maximum user number offset (1 byte)
Z3_WHEEL_OFF    .equ    2Eh             ; Wheel security byte offset (00h=normal, FFh=wheel)

;----------------------------------------------------------------------------
; Buffered File Channel Control Block (CIO) Offsets (168 bytes total)
; Used by cpm_ch1_control_block and cpm_ch2_control_block in sz.asm
;----------------------------------------------------------------------------
CIO_FLAG        .equ    0               ; Channel state / open flag (00h=closed, FFh=open)
CIO_COUNT       .equ    1               ; Remaining bytes in sector buffer (0..128)
CIO_PTR         .equ    2               ; Pointer to current byte in sector buffer (16-bit)
CIO_FCB         .equ    4               ; Embedded CP/M File Control Block (36 bytes)
CIO_BUF         .equ    28h             ; Sector data buffer (128 bytes)
CIO_BUF_OFF     .equ    26h             ; Offset from CIO_PTR (+2) to CIO_BUF (+28h)
CIO_SIZE        .equ    0A8h            ; Total channel control block size (168 bytes)


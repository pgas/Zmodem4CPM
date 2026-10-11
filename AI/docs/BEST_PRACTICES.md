# Assembly Engineering Best Practices & Reverse Engineering Guide

When recovering, deobfuscating, and modernizing vintage 8-bit Z80 assembly code for CP/M, transforming raw disassembly dumps (`loc_XXX`, `sub_XXX`, undocumented raw byte sequences) into maintainable, production-grade source code requires systematic assembly engineering standards.

This guide codifies the exact principles, idioms, and methodologies developed and proven during the complete 100% deobfuscation and annotation of [`rz.asm`](../rz.asm) and [`sz.asm`](../sz.asm).

---

## 1. Subroutine Documentation Standard (Interface Contracts)

Every subroutine must feature a standardized header block that clearly defines its functional role and register contract. In assembly language, subroutines lack formal type signatures; the documentation header serves as the canonical interface specification.

```asm
;============================================================================
; Function : tx_hex_header
; Purpose  : Formats and transmits a Zmodem hex frame header (ZHEX) with type,
;            four parameter/position flags, and 16-bit CRC-CCITT
; Inputs   : A  = Frame type (ZRINIT, ZFILE, ZACK, etc.)
;            HL = Pointer to 4-byte header data array (hdr_f0..hdr_f3)
; Outputs  : Frame transmitted over serial AUX port
; Modifies : A, BC, DE, HL, flags
; Notes    : Computes 16-bit CRC-CCITT on the fly and appends \r\n[XON].
;            Uses tx_hex_byte to emit 2 ASCII hex nibbles per binary byte.
;============================================================================
tx_hex_header:
    ld      (tx_frame_type), a
    ...
```

### Essential Header Fields:
1. **Function**: Canonical, descriptive name using standard verb-noun naming conventions (`get_`, `set_`, `parse_`, `format_`, `tx_`, `rx_`, `bdos_`).
2. **Purpose**: Clear English explanation of the routine's business logic, algorithm, and role within the larger subsystem.
3. **Inputs**: Explicit register preconditions, required pointer targets, data types, and status flags.
4. **Outputs**: Register return values, carry/zero flag contracts (e.g., Carry=1 on error, Carry=0 on success), and memory mutations.
5. **Modifies**: Registers destroyed or modified (callee-saved vs. caller-saved guarantees).
6. **Notes**: Algorithmic subtleties, self-modifying code side effects, calling conventions, or hardware timing constraints.

---

## 2. Symbolic Equates for Magic Numbers & Data Structures

Disassembled machine code is inundated with raw hexadecimal literals that obscure programmer intent. Production-grade assembly replaces every literal with a meaningful symbolic equate.

### 2.1 CP/M BDOS Function Equates
```asm
; Poor Disassembly:
ld      c, 15
call    5

; Clean Production Assembly:
F_OPEN      .equ    15          ; BDOS Function 15: Open File
bdos        .equ    0005h       ; CP/M BDOS entry vector
ld          c, F_OPEN
call        bdos
```

### 2.2 Protocol Manifests & Framing Constants
```asm
; Zmodem framing constants
ZPAD        .equ    '*'         ; 2Ah: Synchronization pad character
ZDLE        .equ    18h         ; Control-X: Data Link Escape
ZBIN        .equ    'A'         ; 41h: 16-bit binary header indicator
ZHEX        .equ    'B'         ; 42h: Hexadecimal header indicator
ZBIN32      .equ    'C'         ; 43h: 32-bit binary header indicator

; Frame type identifiers
ZRQINIT     .equ    0           ; Request receiver initialization
ZRINIT      .equ    1           ; Receiver capabilities declaration
ZFILE       .equ    4           ; File metadata frame
ZDATA       .equ    10          ; Streaming data frame
ZEOF        .equ    11          ; End of file marker
```

### 2.3 CP/M Data Structure Offsets (FCB & Buffered I/O)
Rather than hardcoding arbitrary numerical offsets into data structures, define explicit layout equates:

```asm
; CP/M File Control Block (FCB) Structure Layout
FCB_DRIVE   .equ    0           ; Drive byte (0=default, 1=A, 2=B...)
FCB_NAME    .equ    1           ; 8-byte filename (ASCII uppercase)
FCB_EXT     .equ    9           ; 3-byte extension (ASCII uppercase)
FCB_EX      .equ    12          ; Extent counter
FCB_S1      .equ    13          ; Reserved / S1
FCB_S2      .equ    14          ; Reserved / S2
FCB_RC      .equ    15          ; Record count in current extent (0..128)
FCB_AL      .equ    16          ; 16-byte disk allocation map
FCB_CR      .equ    32          ; Current sequential record index
FCB_R0      .equ    33          ; Random record pointer low
FCB_R1      .equ    34          ; Random record pointer mid
FCB_R2      .equ    35          ; Random record pointer high

; Dual-Channel Buffered I/O Structure Offsets (168-byte Control Block)
CIO_FCB     .equ    0           ; Base of embedded 36-byte CP/M FCB
CIO_BUF_PTR .equ    36          ; Current byte pointer within sector FIFO
CIO_BUF_CNT .equ    38          ; Remaining unread/unwritten bytes in FIFO
CIO_FLAGS   .equ    40          ; Channel state flags (open, dirty, EOF)
CIO_FIFO    .equ    42          ; Base of 128-byte disk sector staging FIFO
```

---

## 3. Advanced Vintage Z80 Optimization Idioms & Deobfuscation

Vintage programmers writing high-performance assembly in the 1970s and 1980s utilized specialized idioms to conserve every byte and CPU clock cycle. Disassemblers often misidentify these idioms as code flow anomalies or corrupted data bytes.

### 3.1 Idiom 1: CPIR Reverse Lookup & Dispatch Tables
In both `rz.asm` and `sz.asm`, command-line switch parsing and inbound frame type dispatching utilize the Z80 `cpir` (Compare and Increment with Repeat) instruction in a reverse lookup pattern:

```asm
; Parse command-line switch character in register A:
    ld      hl, sw_table        ; Pointer to ASCII switch list: "?PBCXYZR"
    ld      bc, 8               ; Number of recognized switch characters
    cpir                        ; Search: compares A against (HL), HL++, BC--
    jp      nz, usage_error     ; If not found, switch is invalid
    
; BC was decremented for every non-matching character:
; If match was 1st character ('?'), BC is now 7.
; If match was 8th character ('R'), BC is now 0.
    ld      hl, sw_jump_table   ; Pointer to base of word jump table
    add     hl, bc              ; Index into jump table from the end!
    add     hl, bc              ; Multiply by 2 for 16-bit word offset
    ld      e, (hl)
    inc     hl
    ld      d, (hl)
    ex      de, hl
    jp      (hl)                ; Indirect dispatch to switch handler
```
*Key Understanding*: The jump table is ordered inversely relative to the search string because `BC` counts down toward zero.

### 3.2 Idiom 2: Opcode Absorption (Branchless Skips)
When a routine needs to return two different constant values (or conditionally skip an instruction) without the byte and cycle penalty of a `jr` instruction, vintage programmers used **opcode absorption** (also known as byte swallowing):

```asm
; Character classifier: tests if A is an alphabetic character
is_alpha_char:
    cp      'A'
    jr      c, not_alpha
    cp      'Z'+1
    jr      c, is_alpha
    cp      'a'
    jr      c, not_alpha
    cp      'z'+1
    jr      nc, not_alpha

is_alpha:
    .db     0F6h                ; Opcode for 'OR n' (absorbs following byte!)
not_alpha:
    xor     a                   ; 0xAF: Returns A=0 (clears Carry and Zero)
    ret
```
*How it works*:
- When execution falls through `is_alpha`, the processor encounters `0F6h`.
- The opcode `0F6h` is `OR imm8`. The CPU reads the next byte (`0AFh`, which is the `xor a` instruction) as the literal immediate operand of the `OR` instruction!
- Thus, `is_alpha` executes `or 0AFh` (preserving non-zero) and skips the `xor a` without any conditional branch instruction, saving 1 byte of code and 7 CPU cycles.

### 3.3 Idiom 3: Self-Modifying Code (SMC) with Immediate Relocation
On Z80 systems where RAM is writable across the entire TPA, modifying immediate operand bytes inside instructions was faster than memory loads or stack pushes:

```asm
; Fast 16-bit CRC accumulator seed reload:
crc16:
    push    af
crc_seed:   .equ    $+1         ; TARGET OF SMC: points to the 16-bit operand
    ld      hl, 0000h           ; Overwritten by ld (crc_seed), hl
    ld      de, 1021h           ; CRC-16 polynomial
    ...

; Calling code updating running seed:
    ld      (crc_seed), hl      ; Patches the immediate operand of ld hl, imm16
```
*Documentation Standard*: Always declare the patched operand explicitly using `.equ $+1`, document the writer routines, and note that the routine is non-reentrant and cannot run from ROM.

### 3.4 Idiom 4: Synthetic Return Address Stack Manipulation
To eliminate duplicated cleanup and register restoration blocks across multiple exit branches, routines push a synthetic return address onto the stack before proceeding:

```asm
    ld      bc, file_stream_exit ; Address of synthetic return handler
    push    bc                  ; Place on stack as return target
    ...                         ; Execute complex file I/O operations
    ret                         ; Jumps to file_stream_exit!

; Shared epilogue handler:
file_stream_exit:
    pop     de                  ; Clean up saved caller state
    pop     hl
    ret                         ; Final return to caller
```

### 3.5 Idiom 5: Unrolled Block Memory Transfers (`LDI`)
To achieve peak memory transfer throughput for small fixed-size structures without the loop overhead of `LDIR` (which incurs 21 clock cycles per byte), critical routines unroll `LDI` instructions (16 cycles per byte):

```asm
; Fast 16-byte block copy:
    ldi                         ; 16 cycles per byte vs 21 cycles for ldir
    ldi
    ldi
    ldi
    ... (16 times)
```

---

## 4. CP/M 3 System Architecture & TPA Resource Management

### 4.1 Dynamic TPA Sizing
Hardcoding buffer boundaries is brittle because CP/M 3 system sizes vary depending on installed drivers and banked memory configurations:
1. Interrogate the BDOS entry address at `0006h`.
2. Compute available RAM: $	ext{HeapCapacity} = 	ext{TopAddress} - 	ext{BSS\_End}$.
3. Dynamically position the stack pointer (`SP`) safely below the dynamic buffer boundaries to prevent catastrophic stack-heap collisions during recursive operations.

### 4.2 CP/M 3 System Control Block (SCB) Hooking
CP/M 2.2 aborts programs unconditionally on disk read/write errors (the infamous `BDOS Err on A: Bad Sector`). CP/M 3 provides BDOS Function 49 (`F_SCB`) allowing applications to hook the error vector and handle media errors gracefully:
1. At startup, save original SCB error handlers via `cpm3_sysvar_hook`.
2. Install local error trap routines that intercept disk full and hardware errors, returning error codes to the protocol engine rather than terminating to the console.
3. On termination (normal or abort), restore the original vectors via `cpm3_sysvar_unhook`.

---

## 5. Modernization & Modular Organization

While legacy CP/M binaries were assembled from monolithic files due to vintage disk constraints, modern development benefits from modular source organization:

```text
AI/
├── cpm3.inc            ; Standard CP/M 3 BDOS calls, SCB offsets, FCB structures
├── zmodem.inc          ; Zmodem frame manifests, packet types, capability flags
├── rz.asm              ; Primary receiver engine (assembles rz.com)
├── sz.asm              ; Primary sender engine (assembles sz.com)
├── Makefile            ; Automated build, clean, and verification pipeline
└── docs/               ; Authoritative technical documentation
    ├── ARCHITECTURE.md ; System topology, memory maps, Shell sort, dual-channel I/O
    ├── SUBROUTINE_CATALOG.md ; Complete 213+ subroutine register interface catalog
    ├── ZMODEM_PROTOCOL.md    ; Protocol framing, state machines, and windowing
    └── BEST_PRACTICES.md     ; Engineering guide, optimization idioms, and testing
```

---

## 6. Test-Driven Reverse Engineering & Verification Pipeline

The cardinal rule of reverse engineering and assembly deobfuscation is:
> **The generated binary must match the original reference binary byte-for-byte at every step.**

### 6.1 Automated CI Regression Pipeline
The build pipeline enforces binary identity via `make test`:

```makefile
test: rz.com sz.com
	@echo "Comparing rz.com against original binary..."
	cmp ../Archive/zmodem-cpm-binaries/rz.com rz.com
	@echo "Comparing sz.com against original binary..."
	cmp ../Archive/zmodem-cpm-binaries/sz.com sz.com
	@echo "All binaries match reference bit-for-bit!"
```

### 6.2 Assembler Syntax Quirks (`uz80as`)
When working with cross-assemblers like `uz80as`:
1. **String Literal Quotation**: Double quotes (`"..."`) and single quotes (`'...'`) must be applied consistently. Single quotes for character constants (`'A'`), double quotes for text strings.
2. **Relative Jump Limits**: Z80 `jr` instructions have a signed 8-bit displacement ($-128$ to $+127$ bytes). If an edit shifts code beyond this boundary, the assembler will fail.
3. **Symbol Length Limits**: Older Z80 assemblers truncate labels at 8 characters; `uz80as` supports modern identifier lengths, but avoid duplicate prefixes within the first 8 characters when targeting vintage assemblers.

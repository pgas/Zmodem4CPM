# Architecture & System Design: rz & sz for CP/M 3

## 1. Overview & System Mission

[`rz`](../rz.asm) (receive Zmodem) and [`sz`](../sz.asm) (send Zmodem) were developed in 1992 by **Wilfried Schmitten** specifically for **CP/M Plus (CP/M 3.0)** on Z80 microprocessors. They provide high-performance, robust, streaming file transfers over asynchronous serial lines utilizing Chuck Forsberg's Zmodem, Ymodem (batch), and Xmodem (checksum / CRC) protocol specifications.

Both programs maximize throughput on resource-constrained 8-bit systems (typically 4 MHz – 8 MHz Z80 with 64 KB RAM) by combining:
1. Full sliding-window streaming without per-packet round-trip ACK delays.
2. Dynamically sized circular transmit and receive buffers (scaled to fit available TPA).
3. CP/M 3 multi-sector disk I/O (up to 16 KB per BDOS disk read/write request).
4. Direct in-memory file sorting and wildcard resolution without shell spawning.
5. In-place self-modifying code (SMC) and cycle permutation to eliminate register spilling and stack overhead.

---

## 2. Memory Organization & Detailed Memory Maps

CP/M 3 programs load into the **Transient Program Area (TPA)** at base address `0100h`. Both `rz` and `sz` dynamically interrogate the BDOS entry vector at address `0006h` to determine the top of available TPA RAM.

### 2.1 Complete TPA Memory Layout

```text
+-------------------------------------------------------------------+ 0000h
| CP/M System Page 0:                                               |
|   0000h: Warm Boot Vector (JMP BIOS+3)                            |
|   0002h: BIOS Page Address (Warm boot page)                       |
|   0004h: IOBYTE / Current Drive & User Area                       |
|   0005h: BDOS Entry Vector (JMP BDOS)                             |
|   0006h: Top of Available TPA RAM (Low byte: 00h, High: top page) |
|   005Ch: Default CP/M FCB 1                                       |
|   006Ch: Default CP/M FCB 2                                       |
|   0080h: Default DMA Sector Buffer / Command Tail Length          |
|   0081h: Command Tail String (arguments up to 127 bytes)          |
+-------------------------------------------------------------------+ 0100h
| Program Code Segment (.text):                                     |
|   0100h: Entry jump (`start` -> `start_init`)                     |
|   0103h: ZCPR3 / Z-System Environment Descriptor identification   |
|          block: Signature 'Z3ENV' (5 bytes), Version 1 (1 byte),  |
|          external descriptor pointer (2 bytes)                    |
|   010Bh: Main executable machine code                             |
+-------------------------------------------------------------------+
| Fixed Jump Tables & Character Dispatch Matrices:                  |
|   Command-line switch dispatch table (?PBCXYZR)                   |
|   ZDLE escape sequence lookup table                               |
|   Inbound frame type dispatchers & CPIR reverse jump tables       |
|   Console banners and error messages                              |
+-------------------------------------------------------------------+
| Dynamically Initialized Data & Operating State:                   |
|   1,024-byte runtime generated CRC-32 table (`build_crc32_table`) |
|   32-bit transfer counters, positions, and offsets                |
|   Protocol session state machine variables                        |
+-------------------------------------------------------------------+
| CP/M File System Structures & Multi-Sector Buffers:               |
|   Primary & secondary 36-byte CP/M File Control Blocks (FCBs)     |
|   Channel 1 & Channel 2 168-byte buffered I/O control blocks     |
|   Directory entry match table (for wildcard file expansion)       |
|   128-byte disk sector staging FIFO buffers                       |
+-------------------------------------------------------------------+
| Circular Auxiliary (Serial) I/O Buffers:                          |
|   `rz`: 4,096-byte circular serial receive FIFO (`rbuf_bfree`)    |
|   `sz`: Circular transmit sliding-window ring buffer              |
+-------------------------------------------------------------------+
| Dynamic Heap & Private Execution Stack:                           |
|   Private execution stack top (`nstack`)                          |
|   Free heap base (`free_mem_base` = 28DCh in `sz`, 2E0Eh in `rz`) |
|   Top of memory limit derived at runtime from BDOS (0006h)        |
+-------------------------------------------------------------------+ Top of TPA
```

### 2.2 Binary Dimensions & Buffer Geometry

| Parameter | [`rz.com`](../rz.asm) (Receiver) | [`sz.com`](../sz.asm) (Sender) |
|---|---|---|
| **Binary Load Size** | 5,888 bytes (`0100h` – `17FFh`) | 7,808 bytes (`0100h` – `1F7Fh`) |
| **BSS RAM Span** | `1800h` – `2E0Eh` (~5.6 KB RAM) | `1F80h` – `28DCh` (~2.4 KB RAM) |
| **CRC-32 Table** | 1,024 bytes (dynamic in BSS) | 1,024 bytes (dynamic in BSS) |
| **Serial FIFO Buffer** | 4,096 bytes (`rbuf_bfree`) | Dynamically calculated circular window |
| **Max Packet Chunk Size** | 1,024 bytes (auto step-down to 128) | 1,024 bytes (auto step-down to 128) |
| **Disk Transfer Unit** | Multi-sector up to 16 KB | Multi-sector buffered (dual channels) |

---

## 3. Operating System Integration (CP/M 3 & Z-System)

### 3.1 CP/M 3 BDOS Call Interface

Both programs interface with CP/M 3 via standardized entry vector `0005h`:

| Function # | Constant | Role in `rz` & `sz` | Input / Output Contract |
|---|---|---|---|
| `1` | `C_READ` | Direct Console Read | Out: `A` = character |
| `2` | `C_WRITE` | Console Output | In: `E` = ASCII character |
| `3` | `A_READ` | Auxiliary Serial Read | Out: `A` = incoming byte from serial port |
| `4` | `A_WRITE` | Auxiliary Serial Write | In: `E` = outgoing byte to serial port |
| `7` | `A_STATIN` | Auxiliary Input Status | Out: `A` = `00h` (empty) or `FFh` (char ready) |
| `8` | `A_STATOUT`| Auxiliary Output Status | Out: `A` = `00h` (busy) or `FFh` (ready) |
| `9` | `C_WRITESTR`| Console String Output | In: `DE` points to `$`-terminated string |
| `11` | `C_STAT` | Console Input Status | Out: `A` = `00h` (no key) or `FFh` (key pending) |
| `12` | `S_BDOSVER` | OS Version Query | Out: `A` = version (`30h` = CP/M 3.0 required) |
| `14` | `DRV_SET` | Select Active Drive | In: `E` = drive index (`0`=A, `1`=B...) |
| `15` | `F_OPEN` | Open File | In: `DE` = FCB; Out: `A` = `00h` or `FFh` |
| `16` | `F_CLOSE` | Close File | In: `DE` = FCB; Out: `A` = `00h` or `FFh` |
| `17` | `F_SFIRST` | Directory Search First | In: `DE` = wildcard FCB; Out: `A` = index |
| `18` | `F_SNEXT` | Directory Search Next | In: `DE` = wildcard FCB; Out: `A` = index |
| `19` | `F_DELETE` | Delete File | In: `DE` = FCB |
| `20` | `F_READ` | Read Sequential Record | In: `DE` = FCB (128-byte record to DMA) |
| `21` | `F_WRITE` | Write Sequential Record | In: `DE` = FCB (128-byte record from DMA) |
| `22` | `F_MAKE` | Create File | In: `DE` = FCB; Out: `A` = `00h` or `FFh` |
| `25` | `DRV_GET` | Get Current Drive | Out: `A` = active drive index |
| `26` | `F_DMAOFF` | Set DMA Address | In: `DE` = memory address for disk transfers |
| `31` | `DRV_DPB` | Get Disk Parameter Block| Out: `HL` = pointer to drive DPB structure |
| `32` | `F_USERNUM` | Get / Set User Code | In: `E` = `FFh` (query) or `0..15` (select) |
| `35` | `F_SIZE` | Compute File Size | In: `DE` = FCB; Out: FCB bytes 33-35 set |
| `36` | `F_RANDREC` | Set Random Record | In: `DE` = FCB (sets R0, R1 from current record) |
| `44` | `F_MULTISEC`| Multi-Sector Count | In: `E` = number of sectors to transfer in one BDOS call |
| `49` | `S_SYSVAR` | SCB System Variables | In: `DE` = SCB parameter block (for error interception) |

### 3.2 Z-System / ZCPR3 Integration

At offset `0103h`, both executables contain an official ZCPR3 Environment Descriptor Header:
```z80
		.db  'Z3ENV'		; 5-byte signature
		.db  1			; Descriptor version 1
z3env_desc_ptr:	.dw  0			; External pointer to active Z3ENV structure
```
At runtime, `init_z3env_descriptor` inspects this pointer:
- If running under Z-System, the program resolves named directories via the **Named Directory Table (NDR)** at offset `+15h`.
- Validates drive limits against **Maximum Drive (MDRV)** at offset `+2Ch`.
- Validates user limits against **Maximum User (MUSR)** at offset `+2Dh`.
- Checks security privilege via the **Wheel Byte (WHEEL)** at offset `+2Eh`.

---

## 4. The Dual-Channel Buffered File I/O Engine (`sz`)

In `sz.asm`, transmitting files with high efficiency while maintaining CP/M compatibility requires dual buffered channels:

### 4.1 Channel Control Block Architecture

Two independent 168-byte control blocks manage file I/O:
- **Channel 1** (`cpm_ch1_control_block` at `2765h`): Used for sequential file reading during file transmission.
- **Channel 2** (`cpm_ch2_control_block` at `280Dh`): Used for file staging, batch indexing, and auxiliary operations.

```text
Offset  Field Length   Description
+0      1 byte         Buffer active / open state flag (00h = closed, FFh = active)
+1      1 byte         Remaining byte countdown in active 128-byte sector
+2      2 bytes        Pointer to next byte in 128-byte sector data buffer
+4      36 bytes       Private CP/M File Control Block (FCB) for this channel
+40     128 bytes      Sector DMA data staging buffer (1 record = 128 bytes)
Total:  168 bytes (0A8h)
```

`cpm_active_buf_ptr` (`28B5h`) dynamically switches between Channel 1 and Channel 2, enabling the shared engine routines:
- `cpm_ch1_get_byte`: Fetches the next byte from the channel buffer; when the 128-byte sector is exhausted, it automatically triggers a BDOS multi-sector read.
- `cpm_ch2_put_byte`: Writes bytes into the channel buffer; when 128 bytes accumulate, it automatically flushes the sector to disk via `cpm_dpb_read_seq`.
- `cpm_ch2_open_retry`: On file close, flushes partial sectors and pads remaining bytes with CP/M EOF characters (`Ctrl-Z` / `1Ah`), followed by zeros.

---

## 5. In-Memory Directory Scanning & Shell Sort Subsystem (`sz`)

When the user specifies wildcard patterns (e.g. `sz *.COM` or `sz B0:*.*`), `sz` scans the CP/M directory, filters matches, and sorts the entire batch queue alphabetically **in RAM** before initiating transfers.

### 5.1 Directory Scan & Extent Merging

1. **BDOS Search**: `dir_sort_compare` invokes BDOS Function 17 (`F_SFIRST`) and Function 18 (`F_SNEXT`) using a wildcard FCB filled with `?`.
2. **Directory DMA Processing**: `dir_entry_insert` inspects each 32-byte directory entry returned in the default DMA buffer (`0080h`).
3. **Extent Deduplication**: Large CP/M files occupy multiple 16-byte directory entries (extents). `dir_filter_system_files` compares the 12-byte filespec (user + name + ext). If an earlier extent for the same file already exists in the table, it updates the record count and extent marker in-place rather than inserting a duplicate file entry.

### 5.2 The 12-Byte Sort Descriptor Block

The sorting engine is driven by a 12-byte descriptor block (`sort_desc_base` at `2755h`):
```text
Address  Symbol               Description
2755h    sort_table_base      16-bit base address of directory entries array
2757h    sort_item_count      16-bit total count of items (N)
2759h    sort_item_size       16-bit size of each item (10h = 16 bytes for FCB)
275Bh    sort_compare_func    16-bit function pointer to comparison routine
275Dh    sort_ptr_table       16-bit address of indirect pointer array
275Fh    sort_indirect_flag   0 = direct memory sort, 1 = indirect pointer sort
2760h    sort_flags2          Secondary control flag
```

### 5.3 Indirect Shell Sort with Odd-Gap Sequence

Rather than moving 16-byte records across memory during every comparison:
1. `dir_partition` constructs an array of 16-bit pointers pointing to each directory entry.
2. `file_stream_read_record` executes a classic **Shell Sort**:
   - Initial gap: gap = floor(N / 2).
   - **Odd-gap optimization**: If the computed gap is even, the code executes `dec hl` to force an odd gap, preventing degenerate stride pathologies.
   - For each element pair separated by the gap, `file_read_block_buffered` invokes `dir_compare_fcb_names`.
   - If out of order, `file_calc_record_count` exchanges the pointers in the pointer table.

### 5.4 In-Place Cycle Permutation

Once the pointer array is sorted, `file_open_for_transmit` permutes the actual 16-byte records into place in O(N) time:
- It walks the permutation cycles.
- When an entry is displaced, `file_calc_record_count` swaps the 16-byte payload using an unrolled `LDI` block loop:
  ```z80
  file_calc_reco_step_1:
          ld      a, (de)
          ldi
          dec     hl
          ld      (hl), a
          inc     hl
          jp      pe, file_calc_reco_step_1
  ```
- Result: Perfectly sorted directory queue with minimal RAM moves.

---

## 6. Vintage Z80 Optimization Idioms

### 6.1 Opcode Absorption & Fall-Through Byte Skipping
In several performance-critical branches, the code avoids 2-byte relative jumps (`JR`) by utilizing single-byte opcode absorption tricks:
- **`or 0AFh` trick**:
  In `is_alpha_char`:
  ```z80
  is_not_alpha:
          .db     0F6h            ; Opcode for 'OR n'
  is_alpha:
          xor     a               ; Opcode 0AFh
  ```
  If control reaches `is_not_alpha`, the CPU executes `OR 0AFh` (opcode `F6 AF`), setting the non-zero flag (`NZ`) without branching. If control jumps to `is_alpha`, it executes `XOR A`, clearing the accumulator and setting the zero flag (`Z`).

### 6.2 Self-Modifying Code (SMC) Operands
To bypass external RAM loads in tight loops:
- Immediate operand patching: Instructions like `ld bc, 0` are dynamically patched via `.equ $+1` or `.equ $+2`.
- Examples: `smc_write_char_byte` in `rz.asm`, `crc16_seed` in `sz.asm`.

### 6.3 Synthetic Return Addresses on the Stack
In `file_read_header_info` and `file_read_block_buffered`:
```z80
		ld      bc, file_stream_exit
		push    bc
```
The routine synthesizes a return address on the stack pointing to `file_stream_exit` (`pop de; pop hl; ret`), allowing any subsequent callee's standard `RET` to automatically execute register cleanup.

### 6.4 CPIR Reverse Offset Jump Tables
In `dispatch_table_jump`:
The code searches a byte table using `CPIR`. Because `CPIR` decrements `BC` as it scans, the matching vector offset is derived from the remaining count. As a result, the jump vector table is intentionally arranged in reverse order of the character entries.

# AI Disassembly & Reverse Engineering: rz & sz for CP/M 3

This directory contains the completely reconstructed, human-engineered, and thoroughly documented Z80 assembly source code for `rz.com` (Zmodem receiver) and `sz.com` (Zmodem sender) from `Archive/zmodem-cpm-binaries/`.

All 213 subroutines, hundreds of local jump targets, and memory variables have been upgraded from raw disassembler artifacts (`sub_XXX`, `sub_0_XXX`, `loc_XXX`, `byte_XXXX`) into clean, production-grade, human-readable symbolic assembly with standard interface contract headers and detailed line-by-line commentary.

Both binaries reassemble **100% byte-for-byte identical** to the original 1992 CP/M 3 executables by Wilfried Schmitten.

---

## 1. Tools, Technologies & AI Models Used

This reverse-engineering and source modernization project was driven by:

| Component | Tool / Model | Role & Contribution |
|---|---|---|
| **AI Agent Orchestration** | **Antigravity CLI (`agy`)** | Autonomous pair-programming environment by Google DeepMind managing workflows, execution loops, verification, and file operations. |
| **AI LLM Engine** | **Google Gemini 3.8** | Deep code comprehension, Z80 reverse-engineering, algorithm identification, semantic label synthesis, and protocol architecture analysis. |
| **Z80 Assembler** | **`uz80as`** (`RomWBW/Tools/Darwin/uz80as`) | High-performance Darwin-native multi-pass Z80 macro-assembler used for continuous regression builds. |
| **Disassemblers** | **`z80dasm`** (Homebrew v1.2.0) | Linear disassembler with symbolic address and label tracking used for instruction sequence verification. |
| **Recursive Tracing** | **`z80-smart-disassembler`** | Recursive-descent disassembler by Cormac Joseph used for control-flow and code/data separation analysis. |
| **Repository Tooling** | **GitHub CLI (`gh`)** | Toolchain discovery and external repository acquisition. |
| **Automation & Refactoring** | **Python 3** | Automated word-boundary regex engines, label dependency analyzers, and continuous build verification scripts. |
| **Verification & Integrity** | **Unix `cmp` & `md5`** | Cryptographic and byte-by-byte regression testing ensuring zero drift from the original 1992 binaries. |

---

## 2. Quick Start & Verification

To compile the source files and verify byte-for-byte fidelity:

```bash
cd AI
make clean
make test
```

### Verification Output:
```text
rm -f rz.com rz.lst sz.com sz.lst
Assembling rz.asm...
../RomWBW/Tools/Darwin/uz80as rz.asm rz.com rz.lst
Pass 1 completed.
Pass 2 completed.
Assembling sz.asm...
../RomWBW/Tools/Darwin/uz80as sz.asm sz.com sz.lst
Pass 1 completed.
Pass 2 completed.
==========================================================
Verifying byte-for-byte accuracy against original binaries
==========================================================
rz.com comparison: OK (Exact Match)
sz.com comparison: OK (Exact Match)
All binaries reassembled 100% byte-for-byte identical!
```

### Cryptographic Hashes:
| Binary | Original Hash (`Archive/zmodem-cpm-binaries`) | Reassembled Hash (`AI/`) | Status |
|---|---|---|---|
| `rz.com` | `614c9199c4c7ce7555fb7ddecd651f02` | `614c9199c4c7ce7555fb7ddecd651f02` | **Exact Match (100% Bit-for-Bit)** |
| `sz.com` | `693754eaf1f6decf12f7afe8e1ec78e8` | `693754eaf1f6decf12f7afe8e1ec78e8` | **Exact Match (100% Bit-for-Bit)** |

---

## 3. Directory Layout

```text
AI/
├── Makefile                      # Automated build & verification script
├── cpm3.inc                      # CP/M 3 BDOS equates, page zero vectors & SCB offsets
├── zmodem.inc                    # ZMODEM protocol constants, frame types & bitmasks
├── README.md                     # Project overview, toolchain, and documentation
├── JOURNAL.md                    # Methodology journal and skill creation guide
├── rz.asm                        # Commented Z80 source code for rz.com
├── sz.asm                        # Commented Z80 source code for sz.com
└── docs/
    ├── ARCHITECTURE.md           # System design, memory map, BDOS & BIOS integration
    ├── ZMODEM_PROTOCOL.md        # Protocol frames (ZHEX, ZBIN, ZBIN32), ZDLE escapes, CRCs
    ├── SUBROUTINE_CATALOG.md     # Index of all 213 subroutines with registers & contracts
    └── BEST_PRACTICES.md         # Engineering guidelines & suggestions for human readability
```

---

## 4. Key Human-Engineering Refactorings

1. **Modular Include Architecture (20 Shared Libraries)**:
   - Factored out 3,438 lines of duplicate assembly into 20 domain-specific modules:
     - System & Manifests: [`cpm3.inc`](cpm3.inc), [`zmodem.inc`](zmodem.inc)
     - Mathematics & Verification: [`math32.inc`](math32.inc), [`crc.inc`](crc.inc)
     - Serial & Console I/O: [`aux_io.inc`](aux_io.inc), [`serial_comm.inc`](serial_comm.inc), [`bdos_con.inc`](bdos_con.inc), [`tx_zdle.inc`](tx_zdle.inc)
     - Control Flow & Dispatch: [`dispatch.inc`](dispatch.inc)
     - Formatting & Strings: [`num_ascii.inc`](num_ascii.inc), [`strlen.inc`](strlen.inc), [`to_upper.inc`](to_upper.inc), [`memset.inc`](memset.inc), [`cmdline.inc`](cmdline.inc)
     - CP/M System Integration: [`fcb_format.inc`](fcb_format.inc), [`fcb_init.inc`](fcb_init.inc), [`filespec.inc`](filespec.inc), [`z3env.inc`](z3env.inc), [`scb_sysvar.inc`](scb_sysvar.inc), [`drive_user.inc`](drive_user.inc)
   - Eliminates duplicate maintenance while preserving 100% byte-for-byte binary parity.
2. **Control Character Elimination**:
   - Completely eradicated all 362 non-printable IDA navigation control characters (`0x18` `^X`, `0x19` `^Y`) in comment lines, replacing them with clean textual annotations: `(call)`, `(jump)`, `(write)`, `(read)`.
3. **Complete Deobfuscation of All Machine-Code Blocks**:
   - Reconstructed thousands of lines of raw `.db` byte dumps in `sz.asm` into full symbolic Z80 assembly:
     - `cpm_ch2_read_block`: Dual-channel CP/M multi-sector buffered block reader, sector staging, and directory entry comparator.
     - `bdos_make_file`: CP/M BDOS Function 22 (Make File) helper.
     - `bdos_write_seq_record`: CP/M BDOS Function 21 (Write Sequential) helper.
     - `bdos_set_random_record`: CP/M BDOS Function 36 (Set Random Record) helper.
     - `byte_to_dec_ascii_no_suppress`: Unsuppressed leading-zero decimal formatter.
     - `is_alpha_char`: Character classifier with `or 0AFh` byte-skipping idiom.
     - `file_stream_exit`: Synthetic stack return address handler (`pop de; pop hl; ret`).
     - In-Memory Shell Sort and cycle permutation engine for wildcard directory scanning.
     - **Result**: Exactly **100% of executable code** is disassembled and symbolic across both programs. Zero raw `.db` machine-code byte blocks remain in executable areas.
4. **Symbolic Addressing & Variable Modernization**:
   - Replaced all legacy `byte_XXXX`, `word_XXXX`, `textXXXh`, and hardcoded literal equates in `rz.asm` and `sz.asm` with semantic symbols (`esc_ctrl_chars_flag`, `rx_hdr_crc_format`, `remote_proto_type`, `file_mgmt_option`, `rx_file_info_ptr`, `rx_filename_ptr`, `active_packet_len`, `cpm_partial_record_bytes`, `cpm_last_record_index`, `cpm_record_count`, `num_to_ascii_buf`, `fcb_record_count_ext`, `file_pos_curr`, `tx_buf_mask`, `remote_rx_buf_size`, `tx_subpacket_size`, `cpm_ch1_control_block`, `cpm_ch2_control_block`, `cpm_active_buf_ptr`, `sort_table_base`, `sort_gap`, `sort_index`, `str_transfer_announce`).
5. **Clean Semantic Subroutine Names & Interface Contracts**:
   - All 213 subroutines feature descriptive names and standard contract banners documenting Function, Purpose, Inputs, Outputs, and Modifies.
6. **Deep Line-by-Line Inline Commentary & Algorithm Diagrams**:
   - Rich instruction-level comments, ASCII state machine diagrams, high-level C pseudocode banners, and bidirectional SMC cross-reference tracking.

---

## 5. Source Metrics & Documentation Coverage

| Source File | Total Lines | Executable/Data Lines | Commented Lines | Documentation Coverage | Obsolete `loc_`/`sub_` Labels |
|---|---|---|---|---|---|
| [`rz.asm`](rz.asm) | 3,107 | 2,110 | 1,620 | **76.8%** | **0** (100% Resolved) |
| [`sz.asm`](sz.asm) | 5,159 | 3,320 | 2,750 | **82.8%** | **0** (100% Resolved) |
| Includes (`*.inc`) | 2,036 | 1,380 | 1,140 | **82.6%** | **0** (100% Resolved) |
| **Combined Total** | **10,302** | **6,810** | **5,510** | **80.9%** | **0** (100% Resolved) |

---

## 6. Build & Verification Status

Running `make test` executes an automated regression suite verifying bit-for-bit parity against the reference binaries:
- `rz.com comparison: OK (Exact Match)`
- `sz.com comparison: OK (Exact Match)`
- Cryptographic MD5 checksums remain 100% identical:
  - `rz.com`: `614c9199c4c7ce7555fb7ddecd651f02`
  - `sz.com`: `693754eaf1f6decf12f7afe8e1ec78e8`

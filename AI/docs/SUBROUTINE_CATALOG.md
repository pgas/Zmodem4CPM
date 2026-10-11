# Complete Subroutine Catalog: rz & sz for CP/M 3

This catalog indexes all subroutines across [`rz.asm`](../rz.asm) (receiver) and [`sz.asm`](../sz.asm) (sender). Every subroutine has been upgraded from raw disassembler artifacts (`sub_XXX`, `sub_0_XXX`, `loc_XXX`) into clean, production-grade, human-readable symbolic assembly with standardized interface contract headers.

---

## 1. `rz.asm` Subroutines (Receiver Engine)

| Original Name | Canonical Name | Functional Purpose & Contract | Register Interface |
|---|---|---|---|
| `sub_195` | `get_init_drive_user` | Query default drive & user area from CP/M Page 0 IOBYTE (0004h) | A, B, HL |
| `sub_1B0` | `set_drive_user` | Select active drive (BDOS 14) and user area (BDOS 32) | A, C, DE |
| `sub_39A` | `parse_options_cmdline` | Parse CLI argument switches (`?`, `-p`, `-b`, `-c`, `-x`, `-y`, `-z`, `-r`) | A, BC, DE, HL |
| `sub_3EF` | `cpm3_sysvar_hook` | Hook CP/M 3 SCB system variables (BDOS 49) for disk error trapping | A, C, DE, HL |
| `sub_451` | `cpm3_sysvar_unhook` | Restore original CP/M 3 SCB error vectors on program termination | A, HL |
| `sub_482` | `print_error_count` | Format and display retry/error count message to console | A, C, DE |
| `sub_4A4` | `print_transfer_file_msg`| Display file reception header banner (filespec, user area, drive) | A, B, C, DE, HL |
| `sub_50B` | `print_transfer_stats` | Compute and display received byte count statistics upon file completion | A, C, DE, HL |
| `sub_552` | `print_file_skipped` | Display "File skipped" status message to console | C, DE |
| `sub_555` | `bdos_print_string` | Print `$`-terminated string to console (BDOS 9 C_WRITESTR) | C, DE |
| `sub_57F` | `rx_buffer_init_ptrs` | Initialize 4KB circular serial receive FIFO buffer head/tail pointers | HL |
| `sub_588` | `rx_buffer_poll` | Poll serial AUX input status (BDOS 7) and buffer pending bytes | A, C, DE, HL |
| `sub_5B4` | `rx_buffer_get_byte` | Pop next received character from circular serial FIFO buffer | A, HL |
| `sub_5CD` | `aux_tx_ready` | Check AUX transmit ready status (BDOS 8 A_STATOUT) | A, C |
| `sub_5D4` | `rx_byte_timeout` | Read byte from AUX port with countdown timeout timer | A, BC |
| `sub_61C` | `rx_buffer_put_byte` | Push incoming serial byte into circular FIFO buffer | DE, HL |
| `sub_643` | `clear_transfer_state` | Clear 37 bytes of transfer state variables in BSS | A, B, HL |
| `sub_64A` | `clear_3_bytes` | Zero out 3 consecutive bytes starting at memory address HL | A, B |
| `sub_64E` | `clear_6_bytes` | Zero out 6 consecutive bytes starting at memory address HL | A, B |
| `sub_654` | `aux_fifo_advance` | Advance AUX FIFO buffer read index pointer | A, DE, HL |
| `sub_669` | `aux_fifo_push` | Append byte to AUX FIFO buffer with wrap-around check | A, DE, HL |
| `sub_688` | `clear_4bytes` | Zero out 4-byte buffer (32-bit integer) at HL | A, BC, DE, HL |
| `sub_692` | `copy_4bytes` | Copy 4-byte buffer (32-bit integer) from HL to DE | BC, DE, HL |
| `sub_6D3` | `cmp_4bytes_eq` | Compare two 4-byte 32-bit values for equality (sets Z flag if equal) | A, B, DE, HL |
| `sub_6E4` | `add32` | 32-bit unsigned addition with carry: `(BC) = (HL) + (DE)` | A, BC, DE, HL |
| `sub_6FA` | `sub32` | 32-bit unsigned subtraction with borrow: `(BC) = (HL) - (DE)` | A, BC, DE, HL |
| `sub_729` | `dec32` | Decrement 32-bit integer stored at memory address (HL) | A, B, HL |
| `sub_7DD` | `checksum8_update` | Update running 8-bit arithmetic checksum in accumulator | A (SMC) |
| `sub_7ED` | `crc32_update` | Update 32-bit CRC accumulator with byte in A via table lookup | A, BC, HL, IX, IY |
| `sub_825` | `build_crc32_table` | Dynamically generate 1,024-byte CRC-32 table in RAM at startup | A, B, DE, HL, IX, IY |
| `sub_8A0` | `init_crc_acc` | Reset CRC-16 seed, CRC-32 accumulator, and 8-bit checksum | A, HL |
| `sub_8B6` | `calc_buffer_mask` | Compute power-of-two buffer capacity and wrap mask from TPA limit | A, BC, HL |
| `sub_8D1` | `rx_batch_engine` | Main protocol reception dispatcher loop (orchestrates file batch) | All registers |
| `sub_961` | `rx_file_transfer` | Receive file payload stream, decode subpackets, and manage disk writes | All registers |
| `sub_A09` | `init_file_progress` | Reset transfer progress counters, timers, and error accumulators | A |
| `sub_BB4` | `rx_zfile_header` | Process incoming ZFILE frame, parse metadata, and create disk file | All registers |
| `sub_BD3` | `check_zfile_attr` | Parse file length, timestamp, and mode from ZFILE payload | All registers |
| `sub_C97` | `calc_pos_offset` | Calculate file repositioning offset for ZRPOS crash recovery | All registers |
| `sub_D0E` | `flush_sector_buffer` | Flush remaining 128-byte sectors in memory FIFO to CP/M disk | All registers |
| `sub_D30` | `disk_write_flush` | Commit 128-byte sector to disk via BDOS Function 21 (F_WRITE) | All registers |
| `sub_D9B` | `tx_zack_frame` | Transmit ZACK frame acknowledging received 32-bit file position | All registers |
| `sub_DD9` | `tx_can_sequence` | Transmit 8x CAN (`0x18`) sequence with backspaces to abort transfer | A, HL |
| `sub_DDC` | `tx_raw_string` | Transmit null-terminated ASCII string directly to serial AUX port | A, HL |
| `sub_DE7` | `comm_rx_char_filtered` | Receive byte from AUX with flow control, timeout, and CAN checks | A, BC |
| `sub_E2F` | `rx_zdle_byte` | Decode ZDLE-escaped byte and detect abort signals | A, BC, DE, HL |
| `sub_F0E` | `zdle_dispatch_tbl` | Dispatch vector table for ZDLE framing terminators | None |
| `sub_F4E` | `handle_zcrce` | Handle ZCRCE terminator: frame ends, next frame header follows | A, F |
| `sub_F52` | `handle_zcrcg` | Handle ZCRCG terminator: continuous streaming, no pause | F |
| `sub_F54` | `handle_zcrcq` | Handle ZCRCQ terminator: continuous streaming with requested ZACK | A, F |
| `sub_F58` | `rx_chk_crc16` | Compare received 16-bit CRC with locally computed CRC-16 | A, B, HL |
| `sub_F7C` | `rx_chk_crc32` | Compare received 32-bit CRC with locally computed CRC-32 | A, B, DE, HL |
| `sub_FA2` | `check_rx_overrun` | Inspect serial receiver status flags for hardware overrun/framing errors | A, F |
| `sub_FAA` | `save_file_pos` | Snapshot current 32-bit file write position to backup register | DE, HL |
| `sub_FBA` | `restore_file_pos` | Rollback 32-bit file position to snapshot upon transmission error | DE, HL |
| `sub_FC9` | `sync_file_pos` | Align local write pointer with sender's advertised file offset | DE, HL |
| `sub_FD1` | `rx_header_search` | Scan serial stream for ZPAD / ZDLE header synchronizer sequences | All registers |
| `sub_10C5`| `rx_bin32_header` | Decode incoming 32-bit binary frame header (`ZBIN32`) | All registers |
| `sub_1100`| `rx_bin16_header` | Decode incoming 16-bit binary frame header (`ZBIN`) | All registers |
| `sub_113F`| `rx_hex_header` | Decode incoming hexadecimal ASCII frame header (`ZHEX`) | All registers |
| `sub_1194`| `rx_hex_byte` | Read two ASCII hex characters from AUX and assemble binary byte | A, B |
| `sub_11B3`| `ascii_hex_to_nibble` | Convert ASCII hex character (`'0'..'9'`, `'a'..'f'`) to 4-bit nibble | A, L |
| `sub_11C1`| `tx_zrinit_frame` | Transmit ZRINIT frame advertising receiver buffer size & CRC32 capability | All registers |
| `sub_11FA`| `tx_zrpos_frame` | Transmit ZRPOS frame requesting sender resume at 32-bit file offset | All registers |
| `sub_1289`| `rx_frame_dispatcher` | Dispatch incoming frame by frame type to specific protocol handlers | All registers |
| `sub_13BA`| `tx_hex_header` | Format and transmit frame header as ASCII hexadecimal (`ZHEX`) | All registers |
| `sub_1418`| `tx_hex_byte` | Output binary byte as two uppercase ASCII hexadecimal characters | A, BC, HL |
| `sub_142F`| `tx_zdle_escaped_char` | Transmit byte over serial AUX port with ZDLE escape translation (`tx_zdle.inc`) | A, BC, HL |
| `sub_1492`| `parse_cpm_filespec` | Parse filename string into standard 36-byte CP/M FCB structure | All registers |
| `sub_14A7`| `parse_fcb_drive_user` | Extract explicit drive letter and user area number into FCB | All registers |
| `sub_1522`| `validate_fcb_char` | Validate legal character for CP/M filename compatibility | A, F |
| `sub_1543`| `inc_file_counter` | Increment count of parsed wildcard characters in filespec | HL |
| `sub_154A`| `fcb_check_wildcards` | Inspect FCB filename for `?` or `*` wildcard characters | DE, HL |
| `sub_1552`| `fcb_match_drive` | Match explicit drive specifier against valid CP/M drive range | A, B, DE, HL |
| `sub_159D`| `fcb_set_attributes` | Match directory name against Z-System Named Directory (NDR) table | DE, HL |
| `sub_15A5`| `fcb_expand_wildcards` | Expand named directory into corresponding drive and user area | All registers |
| `sub_15FA`| `parse_numeric_user` | Parse decimal user area string (`0..15`) into binary numeric value | All registers |
| `sub_1625`| `ascii_to_digit` | Convert ASCII digit (`'0'..'9'`) to binary value with Carry flag validation | A, F |
| `sub_162C`| `init_empty_fcb` | Initialize 36-byte FCB with default drive and space padding | A, DE |
| `sub_1632`| `init_fcb_spaces` | Fill FCB filename (8 bytes) and extension (3 bytes) with spaces | A, B, DE |
| `sub_1645`| `memset_de_spaces` | Memory fill helper (stores byte in A to destination DE for B bytes) | B, DE |
| `sub_164A`| `get_fcb_ext_ptr` | Read Wheel byte offset (`+2Eh`) from Z3ENV descriptor | A, DE, HL |
| `sub_1652`| `get_fcb_name_ptr` | Read Maximum Drive offset (`+2Ch`) from Z3ENV descriptor | A, DE, HL |
| `sub_165A`| `get_fcb_drive_ptr`| Read Maximum User offset (`+2Dh`) from Z3ENV descriptor | A, DE, HL |
| `sub_1662`| `get_fcb_record_ptr`| Read Named Directory Table pointer (`+15h`) from Z3ENV descriptor | DE, HL |
| `sub_1687`| `get_cur_drive_user`| Query current drive (BDOS 25) and user area (BDOS 32) | A, B, C, DE, HL |
| `sub_169E`| `bdos_search_first` | Search first matching directory entry (BDOS 17 F_SFIRST) | A |
| `sub_16A5`| `bdos_con_read` | Direct console character read (BDOS 1 C_READ) | A |
| `sub_16AA`| `bdos_con_stat` | Query console input status (BDOS 11 C_STAT) | A |
| `sub_16C4`| `format_fcb_name` | Format FCB 8.3 filename into printable `d:filename.ext` string | All registers |
| `sub_16DA`| `check_fcb_char` | Check and copy non-space filename character to output buffer | A |
| `sub_16E7`| `byte_to_dec_ascii` | Convert 8-bit unsigned integer in A to 3-digit decimal string | All registers |
| `sub_16ED`| `byte_to_signed_dec`| Convert 8-bit signed integer to decimal string with `+`/`-` sign | All registers |
| `sub_1703`| `div_mod_8` | 8-bit unsigned division: divide A by H, return quotient and remainder | A, L |
| `sub_1717`| `store_ascii_char` | Store ASCII digit at (DE) and advance buffer pointer | A, B, DE |
| `sub_171E`| `calc_strlen` | Calculate length of null-terminated string and convert to uppercase | A, BC, HL |
| `sub_172E`| `tokenize_cmdline` | Tokenize CP/M default command tail buffer at 0080h into arguments | All registers |
| `sub_176B`| `skip_spaces` | Advance string pointer DE past spaces and tabs | A, DE |
| `sub_1779`| `check_delimiter` | Test if character at DE is whitespace or null terminator | A |
| `sub_1793`| `to_upper` | Convert lowercase ASCII character (`'a'..'z'`) to uppercase (`'A'..'Z'`) | A, F |

---

## 2. `sz.asm` Subroutines (Sender Engine)

| Original Name | Canonical Name | Functional Purpose & Contract | Register Interface |
|---|---|---|---|
| `sub_0_1F1` | `get_init_drive_user` | Query default drive & user area from CP/M Page 0 IOBYTE | A, B, HL |
| `sub_0_20C` | `set_drive_user` | Set active drive (BDOS 14) and user area (BDOS 32) | A, C, DE |
| `sub_0_3B3` | `parse_options_cmdline`| Parse CLI option switches (`?`, `-p`, `-b`, `-c`, `-x`, `-y`, `-z`, `-r`) | A, BC, DE, HL |
| `sub_0_408` | `cpm3_sysvar_hook` | Hook CP/M 3 SCB system variables (BDOS 49) for error interception | A, C, DE, HL |
| `sub_0_46A` | `cpm3_sysvar_unhook` | Restore original CP/M 3 SCB error vectors upon termination | A, HL |
| `sub_0_4AC` | `print_transfer_file_msg`| Display file transmission header banner to console | A, B, C, DE, HL |
| `sub_0_508` | `print_transfer_stats` | Compute and display transferred byte count statistics | A, C, DE, HL |
| `sub_0_526` | `print_file_skipped` | Display "File skipped" message on console | C, DE |
| `sub_0_52B` | `bdos_print_string` | Print `$`-terminated string to console (BDOS 9 C_WRITESTR) | C |
| `sub_0_558` | `rx_buffer_init_ptrs` | Initialize circular serial receive buffer head/tail pointers | HL |
| `sub_0_561` | `rx_buffer_poll` | Poll serial AUX input status (BDOS 7) and buffer pending bytes | A, C, DE, HL |
| `sub_0_58D` | `rx_buffer_get_byte` | Pop next received character from circular serial FIFO buffer | A, HL |
| `sub_0_5A6` | `aux_tx_ready` | Check AUX transmit ready status (BDOS 8 A_STATOUT) | A, C |
| `sub_0_5AD` | `rx_byte_timeout` | Read byte from AUX port with countdown timeout timer | A, BC |
| `sub_0_5C4` | `comm_tx_char_raw` | Transmit raw byte to AUX port via BDOS Function 4 (A_WRITE) | A, C, DE |
| `sub_0_5F5` | `rx_buffer_put_byte` | Push incoming serial byte into circular FIFO buffer | DE, HL |
| `sub_0_61C` | `clear_transfer_state` | Clear 37 bytes of transfer state variables in BSS | A, B, HL |
| `sub_0_623` | `clear_6_bytes` | Zero out 6 consecutive bytes starting at HL | A, B |
| `sub_0_629` | `dispatch_table_jump`| Search byte matrix using CPIR and execute reverse jump vector | A, BC, HL |
| `sub_0_632` | `clear_4bytes` | Zero out 4-byte buffer (32-bit integer) at HL | A, BC, DE, HL |
| `sub_0_63C` | `copy_4bytes` | Copy 4-byte buffer (32-bit integer) from HL to DE | BC, DE, HL |
| `sub_0_6A4` | `sub32` | 32-bit unsigned subtraction with borrow: `(BC) = (HL) - (DE)` | A, BC, DE, HL |
| `sub_0_787` | `checksum8_update` | Update running 8-bit arithmetic checksum in accumulator | None (SMC) |
| `sub_0_7CF` | `build_crc32_table` | Dynamically generate 1,024-byte CRC-32 table in RAM at startup | A, B, DE, HL, IX, IY |
| `sub_0_82F` | `crc16` | Update running 16-bit CRC-CCITT with byte in A | A, B, DE, HL |
| `sub_0_854` | `calc_buffer_mask` | Compute power-of-two buffer capacity and wrap mask from TPA limit | A, BC, HL |
| `sub_0_88A` | `init_crc_acc` | Reset CRC-16 seed, CRC-32 accumulator, and 8-bit checksum | A, HL |
| `sub_0_8C1` | `tx_batch_engine` | Main sender batch queue loop (iterates through files to transmit) | All registers |
| `sub_0_922` | `tx_file_transfer` | Send single file through protocol state machine (open, stream, close) | All registers |
| `sub_0_972` | `tx_send_file_data` | Format ZFILE header and stream data sectors in subpackets | All registers |
| `sub_0_9D9` | `tx_dispatch_protocol`| Select active protocol sender engine (Zmodem, Ymodem, Xmodem) | All registers |
| `sub_0_A4C` | `tx_zmodem_file_session`| Execute full Zmodem handshaked file transmission session | All registers |
| `sub_0_10DD`| `tx_zack_frame` | Transmit ZACK frame acknowledging file position | All registers |
| `sub_0_118C`| `tx_bin_header` | Transmit binary frame header (`ZBIN` with CRC-16 or `ZBIN32` with CRC-32)| All registers |
| `sub_0_1204`| `tx_hex_header` | Transmit hexadecimal ASCII frame header (`ZHEX`) with CRC-16 | All registers |
| `sub_0_1262`| `tx_hex_byte` | Output byte as two uppercase ASCII hexadecimal characters | A, BC, HL |
| `sub_0_128A`| `tx_zdle_escaped_char` | Transmit byte over serial AUX port with ZDLE escape translation (`tx_zdle.inc`) | A, BC, HL |
| `sub_0_12DC`| `reset_crc_checksum` | Reset CRC accumulator state variables | A, HL |
| `sub_0_12EB`| `rx_header_search` | Search serial stream for ZPAD/ZDLE frame start sequences | All registers |
| `sub_0_15A8`| `tx_can_sequence` | Transmit 8x CAN (`0x18`) sequence with backspaces to abort transfer | A, HL |
| `sub_0_15AB`| `tx_raw_string` | Send null-terminated ASCII string directly to serial AUX port | A, HL |
| `sub_0_15B6`| `comm_rx_char_filtered` | Receive byte from AUX with flow control, timeout, and CAN checks | A, BC |
| `sub_0_15D4`| `parse_cpm_filespec` | Parse filename into standard 36-byte CP/M FCB structure | All registers |
| `sub_0_15E9`| `parse_fcb_drive_user` | Extract explicit drive letter and user area number into FCB | All registers |
| `sub_0_1664`| `validate_fcb_char` | Validate legal CP/M filename character and count wildcards | A, F |
| `sub_0_1685`| `inc_file_counter` | Increment processed wildcard characters counter | HL |
| `sub_0_168C`| `fcb_check_wildcards` | Inspect FCB filename for `?` or `*` wildcard characters | DE, HL |
| `sub_0_1694`| `fcb_match_drive` | Validate explicit drive specifier against valid CP/M drive range | A, B, DE, HL |
| `sub_0_16DF`| `fcb_set_attributes` | Match directory name against Z-System Named Directory (NDR) table | DE, HL |
| `sub_0_16E7`| `fcb_expand_wildcards` | Expand named directory into corresponding drive and user area | All registers |
| `sub_0_171B`| `check_delimiter_or_term`| Test if character is a filespec delimiter or string terminator | A |
| `sub_0_173C`| `parse_numeric_user` | Parse decimal user area string (`0..15`) into binary numeric value | All registers |
| `sub_0_1767`| `ascii_to_digit` | Convert ASCII digit (`'0'..'9'`) to binary value with Carry validation | A, F |
| `sub_0_176E`| `init_empty_fcb` | Initialize 36-byte FCB with default drive and space padding | A, DE |
| `sub_0_1774`| `init_fcb_spaces` | Fill FCB filename (8 bytes) and extension (3 bytes) with spaces | A, B, DE |
| `sub_0_1787`| `memset_de_spaces` | Memory fill helper (stores byte in A to destination DE for B bytes) | B, DE |
| `sub_0_178C`| `get_fcb_ext_ptr` | Read Wheel byte offset (`+2Eh`) from Z3ENV descriptor | A, DE, HL |
| `sub_0_1794`| `get_fcb_name_ptr` | Read Maximum Drive offset (`+2Ch`) from Z3ENV descriptor | A, DE, HL |
| `sub_0_179C`| `get_fcb_drive_ptr`| Read Maximum User offset (`+2Dh`) from Z3ENV descriptor | A, DE, HL |
| `sub_0_17A4`| `get_fcb_record_ptr`| Read Named Directory Table pointer (`+15h`) from Z3ENV descriptor | DE, HL |
| `sub_0_17C5`| `init_z3env_descriptor`| Store external Z3ENV (Z-System environment) pointer | HL |
| `sub_0_17C9`| `dir_search_wildcard` | Scan directory via BDOS, filter matches, and sort queue in RAM | All registers |
| `sub_0_17D6`| `dir_search_wil_next_entry`| Secondary entry point for directory search with xor a mode | All registers |
| `sub_0_17F2`| `dir_read_entry` | Set up sort descriptor and launch indirect Shell sort on directory entries | All registers |
| `sub_0_181A`| `dir_compare_fcb_names`| Callback: Compare two FCB entries (filename, ext, extent, user) | All registers |
| `sub_0_185C`| `dir_sort_compare` | Scan CP/M directory via BDOS Search First/Next and collect entries | All registers |
| `sub_0_18A8`| `dir_entry_insert` | Insert matched directory entry from CP/M DMA buffer into table | All registers |
| `sub_0_18EB`| `dir_filter_system_files`| Deduplicate directory extents: merge higher extents into table | All registers |
| `sub_0_1938`| `dir_format_entry` | Compact matched entries (marked with bit 7) to front of buffer | All registers |
| `sub_0_1979`| `dir_alloc_entry_buffer`| Query DPB parameters and initialize directory table buffers | All registers |
| `sub_0_19A1`| `dir_free_entry_buffer` | Read CP/M Disk Parameter Block (DPB) parameters via BDOS 31 | All registers |
| `sub_0_19CB`| `dir_sort_table` | Scan directory list and mark entries matching wildcard filespec (bit 7)| All registers |
| `sub_0_1A0B`| `dir_swap_entries` | Check file attributes (DIR vs SYS bit 7 of F2') and user area against filter| All registers |
| `sub_0_1A30`| `dir_partition` | Construct 16-bit pointer array below BDOS top of TPA and start Shell sort| All registers |
| `sub_0_1A81`| `file_open_for_transmit`| In-place cycle permutation: reorder 16-byte records using sorted pointers| All registers |
| `sub_0_1AF9`| `file_read_header_info`| Swap two items during sort (synthetic tail-call through `file_stream_exit`)| All registers |
| `sub_0_1B08`| `file_calc_record_count`| Block swap: exchange memory blocks of length `sort_item_size` | All registers |
| `---`       | `file_stream_exit` | Shared tail-call cleanup handler (`pop de; pop hl; ret`) | DE, HL |
| `sub_0_1B25`| `file_seek_record` | Compute direct memory addresses for two item indices | All registers |
| `sub_0_1B29`| `file_compute_block_offset`| Compute memory address: `base + (index - 1) * size` via 16-bit multiply | All registers |
| `sub_0_1B55`| `file_read_block_buffered`| Invoke comparison callback function for item pair | All registers |
| `sub_0_1B7C`| `file_advance_block` | Compute address in 16-bit pointer table: `ptr_table + (index - 1) * 2` | BC, HL |
| `sub_0_1B84`| `file_stream_init` | Load 12-byte sort descriptor block into internal state variables | BC, DE, HL |
| `sub_0_1B91`| `file_stream_read_next`| Restore internal sort descriptor block back to caller structure | BC, DE, HL |
| `sub_0_1B9A`| `file_stream_read_record`| **In-Memory Shell Sort**: odd-gap reduction, callbacks, pointer sorting | All registers |
| `sub_0_1BDB`| `cpm_bdos_read_record` | Read multi-sector block on Channel 1 (sequential disk read BDOS 20) | All registers |
| `---`       | `cpm_ch2_read_record` | Read multi-sector block on Channel 2 | All registers |
| `---`       | `cpm_ch1_read_buffered_byte`| Read next single byte from Channel 1 buffered stream | All registers |
| `---`       | `cpm_ch2_write_buffered_byte`| Write single byte into Channel 2 buffered stream | All registers |
| `sub_0_1C09`| `cpm_bdos_open_file` | Open file on Channel 1 with multi-sector mode (BDOS 15) | All registers |
| `---`       | `cpm_ch2_open_file` | Open file on Channel 2 with flush and retry | All registers |
| `sub_0_1C23`| `cpm_set_dma_buffer` | Set active DMA transfer address for Channel 1 | A, HL |
| `---`       | `cpm_ch2_set_dma` | Set active DMA transfer address for Channel 2 | A, HL |
| `sub_0_1C37`| `cpm_bdos_file_read_loop`| Open file and initialize read buffer on Channel 1 | All registers |
| `---`       | `cpm_ch2_read_block` | Create/open file on Channel 2 and initialize write buffer | All registers |
| `---`       | `cpm_ch1_get_byte` | Read next byte from Channel 1 buffer; auto-refill sector on empty | All registers |
| `---`       | `cpm_ch2_put_byte` | Write byte to Channel 2 buffer; auto-flush sector on boundary | All registers |
| `sub_0_1D16`| `cpm_bdos_file_open_retry`| Close open file on Channel 1 and reset buffer state | All registers |
| `---`       | `cpm_ch2_open_retry` | Flush Channel 2 buffer, pad with Ctrl-Z (`1Ah`), and close file | All registers |
| `sub_0_1D56`| `cpm3_get_dpb_info` | Read sequential sector from disk into active channel buffer (BDOS 20) | All registers |
| `---`       | `cpm_dpb_read_seq` | Write sequential sector from active channel buffer to disk (BDOS 21) | All registers |
| `sub_0_1D8C`| `bdos_call_wrapper` | Query current drive (BDOS 25) and user area (BDOS 32) | A, BC |
| `sub_0_1DA3`| `bdos_compute_file_size`| Compute total file size in records via BDOS Function 35 (F_SIZE) | All registers |
| `---`       | `bdos_set_random_record`| Set random record pointer via BDOS Function 36 (F_RANDREC) | All registers |
| `---`       | `bdos_make_file` | Open existing file or create new file via BDOS Function 22 (F_MAKE) | All registers |
| `sub_0_1DD2`| `bdos_close_file` | Close open file via BDOS Function 16 (F_CLOSE) | All registers |
| `sub_0_1DD7`| `bdos_open_file_raw` | Open existing file via BDOS Function 15 (F_OPEN) | All registers |
| `sub_0_1DDF`| `bdos_read_random_record`| Read sequential record from disk via BDOS Function 20 (F_READ) | All registers |
| `---`       | `bdos_write_seq_record`| Write sequential record to disk via BDOS Function 21 (F_WRITE) | All registers |
| `sub_0_1DE9`| `bdos_set_dma_addr` | Set DMA buffer address via BDOS Function 26 (F_DMAOFF) | A, C, DE |
| `sub_0_1DF3`| `cpm_restore_user_drive`| Zero out FCB extent and record allocation fields before opening | All registers |
| `sub_0_1E07`| `bdos_con_read` | Read character from console directly (BDOS 1 C_READ) | A, C |
| `sub_0_1E0C`| `bdos_con_stat` | Check console input status (BDOS 11 C_STAT) | A, C |
| `sub_0_1E11`| `bdos_con_write_char` | Low-level BDOS wrapper invoking Function C with parameter E | A, C, DE |
| `sub_0_1E1A`| `bdos_sys_call` | Generic BDOS system call dispatcher with function in A, parameter in DE | A, BC, DE, HL |
| `sub_0_1E26`| `format_fcb_name` | Format 8.3 FCB filename into printable ASCII string (`NAME.EXT`) | All registers |
| `sub_0_1E3C`| `check_fcb_char` | Copy non-space ASCII characters from DE to HL for B bytes | A, B, DE, HL |
| `sub_0_1E49`| `byte_to_dec_ascii` | Convert 8-bit unsigned integer in A to 3-digit decimal string | All registers |
| `---`       | `byte_to_dec_ascii_no_suppress`| Convert 8-bit unsigned integer without suppressing leading zeros | All registers |
| `sub_0_1E65`| `div_mod_8` | 8-bit integer division: divide A by H, return quotient and remainder | A, L |
| `sub_0_1E79`| `store_ascii_char` | Convert numeric digit (0..9) to ASCII digit and store at (DE) | A, B, DE |
| `sub_0_1E80`| `calc_strlen` | Calculate length of string and convert characters to uppercase | A, HL |
| `---`       | `print_inline_str_z` | Print string to console up to null terminator or non-printable character | A, HL |
| `sub_0_1E9E`| `print_inline_string` | Print string at HL to console until delimiter reached | A, HL |
| `sub_0_1EAB`| `tokenize_cmdline` | Split CP/M command tail into whitespace-separated argument tokens | All registers |
| `sub_0_1EE8`| `skip_spaces` | Advance pointer DE past whitespace characters (spaces and tabs) | A, DE |
| `sub_0_1EF6`| `check_delimiter` | Advance pointer DE until whitespace or null delimiter is found | A, DE |
| `sub_0_1F03`| `memset_buffer` | Fill memory buffer at HL of length BC with byte in A | All registers |
| `sub_0_1F09`| `memset_loop` | Fill memory at HL for B bytes with byte in A | B, HL |
| `---`       | `is_alpha_char` | Test if character in A is alphabetic using `or 0AFh` opcode absorption | Flags (A preserved) |
| `sub_0_1F24`| `memcpy_string` | Classify ASCII character as whitespace/control delimiter vs printable | Flags |
| `sub_0_1F3F`| `to_upper` | Convert lowercase ASCII character (`'a'..'z'`) to uppercase (`'A'..'Z'`) | A, Flags |
| `sub_0_1F4A`| `get_top_of_tpa` | Query top of available TPA from BDOS entry vector at 0006h | A, HL |
| `sub_0_1F58`| `check_wildcard_char`| Compare characters at HL and DE with `?` wildcard support | A, B, C, DE, HL |
| `sub_0_1F6A`| `get_next_token_char`| Compare B characters between HL and DE (case and parity insensitive) | A, B, C, DE, HL |

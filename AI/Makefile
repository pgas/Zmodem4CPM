# Makefile for building, testing, and verifying rz and sz Z80 CP/M binaries

UZ80AS ?= ../RomWBW/Tools/Darwin/uz80as
ORIGINAL_DIR ?= ../Archive/zmodem-cpm-binaries

all: rz.com sz.com test

rz.com: rz.asm cpm3.inc zmodem.inc math32.inc
	@echo "Assembling rz.asm..."
	$(UZ80AS) rz.asm rz.com rz.lst

sz.com: sz.asm cpm3.inc zmodem.inc math32.inc
	@echo "Assembling sz.asm..."
	$(UZ80AS) sz.asm sz.com sz.lst

test: rz.com sz.com
	@echo "=========================================================="
	@echo "Verifying byte-for-byte accuracy against original binaries"
	@echo "=========================================================="
	@printf "rz.com comparison: "
	@if cmp -s rz.com $(ORIGINAL_DIR)/rz.com; then \
		echo "OK (Exact Match)"; \
	else \
		echo "FAILED"; \
		cmp -l rz.com $(ORIGINAL_DIR)/rz.com | head -n 20; \
		exit 1; \
	fi
	@printf "sz.com comparison: "
	@if cmp -s sz.com $(ORIGINAL_DIR)/sz.com; then \
		echo "OK (Exact Match)"; \
	else \
		echo "FAILED"; \
		cmp -l sz.com $(ORIGINAL_DIR)/sz.com | head -n 20; \
		exit 1; \
	fi
	@echo "All binaries reassembled 100% byte-for-byte identical!"

clean:
	rm -f rz.com rz.lst sz.com sz.lst

.PHONY: all test clean

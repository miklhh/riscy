
.PHONY:
	clean

INIT_ASM=init.S
LINK_SCRIPT=link.ld

# RISC-V toolchain prefix
RISCV_TOOLCHAIN_PREFIX=riscv64-unknown-elf

# ABI setting passed to gcc and g++
RISCV_ABI=ilp32

# Architecture setting passed to gcc and g++
RISCV_ARCH=rv32i

# Default toolchain flags
CFLAGS=-ffreestanding -O2 -Wall -march=$(RISCV_ARCH) -mabi=$(RISCV_ABI)
ASFLAGS=-march=$(RISCV_ARCH) -mabi=$(RISCV_ABI)
LINK_FLAGS=-T$(LINK_SCRIPT) -nostdlib

test.elf: test.c init.S link.ld
	$(RISCV_TOOLCHAIN_PREFIX)-as $(ASFLAGS) init.S -o init.o
	$(RISCV_TOOLCHAIN_PREFIX)-gcc $(CFLAGS) -c test.c -o test.o
	$(RISCV_TOOLCHAIN_PREFIX)-gcc $(CFLAGS) $(LINK_FLAGS) init.o test.o -o test.elf

clean:
	@rm -rfv init.o test.o test.elf

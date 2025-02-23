ASM = nasm
CC = gcc
CC_FLAGS = -m32 -ffreestanding -fno-builtin -nostdlib -nostartfiles -nodefaultlibs

BUILD_DIR ?= build

.PHONY: asmKernel cKernel

asmKernel: $(BUILD_DIR)/asmKernel.bin
cKernel: $(BUILD_DIR)/cKernel.bin
clean:
	rm -f $(BUILD_DIR)/*

$(BUILD_DIR)/asmKernel.bin: kernel.asm
	$(ASM) -f bin -o $(BUILD_DIR)/asmKernel.bin kernel.asm

$(BUILD_DIR)/cKernel.o: kernel.c
	$(CC) $(CC_FLAGS) -o $(BUILD_DIR)/cKernel.o -c kernel.c

$(BUILD_DIR)/cKernel.bin: $(BUILD_DIR)/cKernel.o
	ld -m elf_i386 -T linker.ld -o $(BUILD_DIR)/cKernel.elf $(BUILD_DIR)/cKernel.o
	objcopy -O binary $(BUILD_DIR)/cKernel.elf $(BUILD_DIR)/cKernel.bin
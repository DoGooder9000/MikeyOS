ASM = nasm
CC = gcc
CC_FLAGS = -m32 -ffreestanding -fno-builtin -nostdlib -nostartfiles -nodefaultlibs

BUILD_DIR ?= build
TEMP_DIR = tmp

SRC = src
HEADERS = $(SRC)/headers

C_SRCS = $(wildcard $(SRC)/*.c)
C_OBJS = $(patsubst $(SRC)/%.c, $(TEMP_DIR)/%.o, $(C_SRCS))
C_HEADERS = $(wildcard $(HEADERS)/*.h)

.PHONY: all asmKernel Kernel clean

all: asmKernel Kernel

asmKernel: $(BUILD_DIR)/asmKernel.bin

Kernel: $(BUILD_DIR)/Kernel.bin

clean:
	rm -f $(TEMP_DIR)/*

$(BUILD_DIR)/asmKernel.bin: kernel.asm
	$(ASM) -f bin -o $(BUILD_DIR)/asmKernel.bin kernel.asm

$(C_OBJS): $(C_SRCS)
	$(CC) $(CC_FLAGS) -o $@ -I $(HEADERS) -c $(patsubst $(TEMP_DIR)/%.o, $(SRC)/%.c, $@)

$(BUILD_DIR)/Kernel.bin: $(C_OBJS)
	ld -m elf_i386 -T linker.ld -o $(TEMP_DIR)/Kernel.elf $(C_OBJS)
	objcopy -O binary $(TEMP_DIR)/Kernel.elf $(BUILD_DIR)/Kernel.bin


# Dissasemble Command \
objdump -d -M intel build/kernel.o \
objdump -d -M intel src/kernel/tmp/Kernel.elf \
ndisasm -b 32 build/kernel.bin | less
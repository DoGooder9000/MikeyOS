ASM = nasm

SRC_DIR = src
BOOT_DIR = $(SRC_DIR)/bootloader
KERN_DIR = $(SRC_DIR)/kernel
BUILD_DIR = build

STAGE1_DIR = $(BOOT_DIR)/stage1
STAGE2_DIR = $(BOOT_DIR)/stage2

TOOLS = tools
FAT-TOOLS = $(TOOLS)/fat

FAT-TOOLS-FILES = $(wildcard $(FAT-TOOLS)/*.c)

.PHONY: floppy stage1 stage2 kernel clean nogui gui wsl tools

$(BUILD_DIR)/floppy.img: $(BUILD_DIR)/stage1.bin $(BUILD_DIR)/stage2.bin $(BUILD_DIR)/kernel.bin
	dd if=/dev/zero of=$(BUILD_DIR)/floppy.img bs=512 count=2880

	mkfs.fat -F 12 -n "MIKEYOS" $(BUILD_DIR)/floppy.img

	dd if=$(BUILD_DIR)/stage1.bin of=$(BUILD_DIR)/floppy.img conv=notrunc

	mcopy -i $(BUILD_DIR)/floppy.img $(BUILD_DIR)/stage2.bin "::stage2.bin"

	mcopy -i $(BUILD_DIR)/floppy.img $(BUILD_DIR)/kernel.bin "::kernel.bin"


$(BUILD_DIR)/stage1.bin: $(STAGE1_DIR)/stage1.asm
	# Compiles the stage1.asm into stage1.bin

	make --directory $(STAGE1_DIR) BUILD_DIR=$(abspath $(BUILD_DIR))

$(BUILD_DIR)/stage2.bin: $(STAGE2_DIR)/stage2.asm
	# Compiles the stage2.asm into stage2.bin

	make --directory $(STAGE2_DIR) BUILD_DIR=$(abspath $(BUILD_DIR))


$(BUILD_DIR)/kernel.bin: $(KERN_DIR)/kernel.asm
	# Compiles the kernel.asm into kernel.bin

	make --directory $(KERN_DIR) BUILD_DIR=$(abspath $(BUILD_DIR))


floppy: $(BUILD_DIR)/floppy.img

stage1: $(STAGE1_DIR)/stage1.bin

stage2: $(STAGE2_DIR)/stage2.bin

kernel: $(BUILD_DIR)/kernel.bin


$(patsubst %.c, %.exe, $(FAT-TOOLS-FILES)): $(FAT-TOOLS-FILES)
	gcc -o $@ $(patsubst %.exe, %.c, $@)

$(patsubst %.c, %.o, $(FAT-TOOLS-FILES)): $(FAT-TOOLS-FILES)
	gcc -o $@ $(patsubst %.o, %.c, $@)

tools: fat-tools

fat-tools: $(patsubst %.c, %.exe, $(FAT-TOOLS-FILES)) $(patsubst %.c, %.o, $(FAT-TOOLS-FILES))


clean:
	rm -f $(BUILD_DIR)/floppy.img
	rm -f $(BUILD_DIR)/*.bin
	rm -f $(FAT-TOOLS)/*.o
	rm -f $(FAT-TOOLS)/*.exe

nogui:
	qemu-system-i386 -nographic -fda $(BUILD_DIR)/floppy.img

gui:
	qemu-system-i386 -fda $(BUILD_DIR)/floppy.img

wsl:
	wsl make
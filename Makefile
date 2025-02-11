ASM = nasm

SRC_DIR = src
BUILD_DIR = build

$(BUILD_DIR)/floppy.img: $(BUILD_DIR)/main.bin
	cp $(BUILD_DIR)/main.bin $(BUILD_DIR)/floppy.img
	truncate -s 1440K $(BUILD_DIR)/floppy.img

$(BUILD_DIR)/main.bin: $(SRC_DIR)/main.asm
	$(ASM) -f bin -o $(BUILD_DIR)/main.bin $(SRC_DIR)/main.asm

run:
	qemu-system-i386 -nographic -fda build/floppy.img

ASM = nasm

BUILD_DIR? = build/

.PHONY: kernel

stage1: $(BUILD_DIR)/kernel.bin

$(BUILD_DIR)/kernel.bin: kernel.asm
	$(ASM) -f bin -o $(BUILD_DIR)/kernel.bin kernel.asm
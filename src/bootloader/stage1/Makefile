ASM = nasm

BUILD_DIR? = build/

.PHONY: stage1

stage1: $(BUILD_DIR)/stage1.bin

$(BUILD_DIR)/stage1.bin: stage1.asm
	$(ASM) -f bin -o $(BUILD_DIR)/stage1.bin stage1.asm
ASM = nasm

BUILD_DIR? = build/

.PHONY: stage2

stage2: $(BUILD_DIR)/stage2.bin

$(BUILD_DIR)/stage2.bin: stage2.asm
	$(ASM) -f bin -o $(BUILD_DIR)/stage2.bin stage2.asm
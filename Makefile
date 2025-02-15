ASM = nasm

SRC_DIR = src
BOOT_DIR = $(SRC_DIR)/bootloader
KERN_DIR = $(SRC_DIR)/kernel
BUILD_DIR = build

.PHONY: floppy bootloader kernel clean always

$(BUILD_DIR)/floppy.img: $(BUILD_DIR)/bootloader.bin $(BUILD_DIR)/kernel.bin
	dd if=/dev/zero of=$(BUILD_DIR)/floppy.img bs=512 count=2880				# Fills a file with 1.44 MB of zeros

	mkfs.fat -F 12 -n "MIKEYOS" $(BUILD_DIR)/floppy.img							# Formats the file to Fat 12

	dd if=$(BUILD_DIR)/bootloader.bin of=$(BUILD_DIR)/floppy.img conv=notrunc	# Moves the bootloader.bin into the start of the file

	mcopy -i $(BUILD_DIR)/floppy.img $(BUILD_DIR)/kernel.bin "::kernel.bin"		# Copies the kernel.bin into the right place in the file

$(BUILD_DIR)/bootloader.bin: $(BOOT_DIR)/bootloader.asm
	# Compiles the Bootloader.asm into bootloader.bin

	$(ASM) -f bin -o $(BUILD_DIR)/bootloader.bin $(BOOT_DIR)/bootloader.asm


$(BUILD_DIR)/kernel.bin: $(KERN_DIR)/kernel.asm
	# Compiles the kernel.asm into kernel.bin

	$(ASM) -f bin -o $(BUILD_DIR)/kernel.bin $(KERN_DIR)/kernel.asm

floppy: $(BUILD_DIR)/floppy.img

bootloader: $(BUILD_DIR)/bootloader.bin

kernel: $(BUILD_DIR)/kernel.bin

always:
	mkdir $(BUILD_DIR)

clean:
	rm $(BUILD_DIR)/floppy.img
	rm $(BUILD_DIR)/*.bin

nogui:
	qemu-system-i386 -nographic -fda $(BUILD_DIR)/floppy.img

gui:
	qemu-system-i386 -fda $(BUILD_DIR)/floppy.img

wsl:
	wsl make
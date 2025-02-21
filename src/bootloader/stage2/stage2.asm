org 0x0000
bits 16

%define ENDL 0x0D, 0x0A
%define STAGE2_BASE 0x18000

start:
	mov si, Stage2Loaded
	call print

	; Our first objective is to switch into 32-bit protected mode
	jmp ProtectedModeEntry

ProtectedModeEntry:
	cli				; disable interrupts

	lgdt [GDT_DESC]		; load GDT register with start address of Global Descriptor Table

	; Enable the A20 Line
	call EnableA20

	mov eax, cr0 
	or eax, 1		; set PE ( Protection Enable ) bit in CR0 ( Control Register 0 )
	mov cr0, eax

	; Once PE bit is set, the CPU assumes segment selectors point to GDT descriptors, not real-mode segments.
	; Now we need to do a far jump
	jmp dword 0x8:(STAGE2_BASE+AfterProtectedModeJump)

print: ; Put the address of the line in SI
	push ax		; Store AX on the stack
	push si		; Store SI on the stack	
	
	jmp .printloop	; Goto .printloop

.printloop:
	lodsb			; Load the byte at DS:SI into AL ( lower half of AX )
	
	or al, al		; Check if AL is 0 ( End of the string )
	jz .printdone	; If AL is 0 jmp to .printdone

	mov ah, 0x0E	; Set the interrupt code for TTY Character Output
	int 0x10		; Call interrupt 0x10

	jmp .printloop

.printdone:
	pop si		; Put the previous value of SI back into SI
	pop ax		; Put the previous value of AX back into AX

	ret			; Return

Stage2Loaded: db "Bootloader Stage 2 is loaded", ENDL, 0

EnableA20:
	in al, 0x92
	or al, 0b00000010
	out 0x92, al

	ret

GDT:
	; Entries are 8 bytes long
	; First entry is always null
GDT_NULL:
	dq 0    ; The first entry is null
			; Define a quad word ( 8 bytes )

GDT_CODE_SEG_32:
	; Size
	dw 0xFFFF  ; Size / Limit ( max size at 4kb granularity )

	; Base
	dw 0        ; Low bits of the base / starting point
	db 0        ; High Byte of the base

	; Access Byte
	; Present Bit, DPL ( 2 Bits ), Descriptor Type, Executable Bit, Direction/Conforming Bit, Readable/Writable, Accessed Bit
	db 0b10011010
	
	; Flags plus the rest of the limit
	; Granularity Flag, Size Flag, Long-Mode Code Flag + the rest of the Limit
	db 0b1100_1111

	; Highest Byte of the Base
	db 0

GDT_DATA_SEG_32:
	; Size
	dw 0xFFFF  ; Size / Limit ( max size at 4kb granularity )

	; Base
	dw 0        ; Low bits of the base / starting point
	db 0        ; High Byte of the base

	; Access Byte
	; Present Bit, DPL ( 2 Bits ), Descriptor Type, Executable Bit, Direction/Conforming Bit, Readable/Writable, Accessed Bit
	db 0b10010010
	
	; Flags plus the rest of the limit
	; Granularity Flag, Size Flag, Long-Mode Code Flag + the rest of the Limit
	db 0b1100_1111

	; Highest Byte of the Base
	db 0

GDT_CODE_SEG_16:
	; Size
	dw 0xFFFF  ; Size / Limit ( max size at 4kb granularity )

	; Base
	dw 0        ; Low bits of the base / starting point
	db 0        ; High Byte of the base

	; Access Byte
	; Present Bit, DPL ( 2 Bits ), Descriptor Type, Executable Bit, Direction/Conforming Bit, Readable/Writable, Accessed Bit
	db 0b10011010
	
	; Flags plus the rest of the limit
	; Granularity Flag, Size Flag, Long-Mode Code Flag + the rest of the Limit
	db 0b0000_1111

	; Highest Byte of the Base
	db 0

GDT_DATA_SEG_16:
	; Size
	dw 0xFFFF  ; Size / Limit ( max size at 4kb granularity )

	; Base
	dw 0        ; Low bits of the base / starting point
	db 0        ; High Byte of the base

	; Access Byte
	; Present Bit, DPL ( 2 Bits ), Descriptor Type, Executable Bit, Direction/Conforming Bit, Readable/Writable, Accessed Bit
	db 0b10010010
	
	; Flags plus the rest of the limit
	; Granularity Flag, Size Flag, Long-Mode Code Flag + the rest of the Limit
	db 0b0000_1111

	; Highest Byte of the Base
	db 0

GDT_DESC:
	dw GDT_DESC - GDT - 1
	dd (GDT+STAGE2_BASE)

bits 32
AfterProtectedModeJump:
	cli
	hlt
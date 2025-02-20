org 0x00
bits 16

%define ENDL 0x0D, 0x0A

start:
	jmp main

main:
    mov si, KernelLoadedMsg
    call print

	; Our first objective is to switch into 32-bit protected mode
    ; 1. Turn off interrupts ( and NMI's too )
    cli

	jmp haltloop

haltloop:
	hlt
	jmp haltloop

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

KernelLoadedMsg: db "Kernel Loaded", ENDL, 0

GDT:
    ; Entries are 8 bytes long
    ; First entry is always null
GDT_NULL:
    dq 0    ; The first entry is null
            ; Define a quad word ( 8 bytes )
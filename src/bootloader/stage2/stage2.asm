org 0x500
bits 16

%define ENDL 0x0D, 0x0A
%define STAGE2_BASE 0x0000

OEM_IDEN:	db "MSWIN4.1"
BYTES_PER_SEC:	dw 512
SEC_PER_CLUST:	db 1
NUM_RES_SECT:	dw 1
FAT_ALLOC_TB:	db 2
ROOT_DIR_ENT:	dw 0xE0
NUM_SECTORS:	dw 2880
MED_DES_TYPE:	db 0xF0
SEC_PER_FAT:	dw 9
SEC_PER_TRCK:	dw 18
NUM_HEADS:	dw 2
HIDDEN_SEC:	dd 0
LARGE_SEC:	dd 0

; EXTENDED BOOT RECORD

DRIVE_NUM:	db 0
WINDOWS_FLAG:	db 0
DRIVE_SIG:	db 0x29
VOLUME_ID:	db 0x01, 0x23, 0x45, 0x67
VOLUME_LABEL:	db "MIKEYOS    "
SYS_IDEN_STR:	db "FAT12   "

RootDirectoryEnd: db 0
CurrentCluster: dw 0
DirectoryEntrySize: db 32

KernelFileName: db "KERNEL  BIN"

start:
	mov si, Stage2Loaded
	call print

	call LoadKernel

	; Our first objective is to switch into 32-bit protected mode
	jmp ProtectedModeEntry

LoadKernel:
	call ReadRootDirectory
	call SearchRootDirectory
	call ReadFAT
	call ReadKernel

	ret

LBAtoCHS:
	push bx				; Push BX to the Stack
	push si				; Push SI to the Stack

	mov si, ax			; Put the LBA into SI from AX
	mov ax, [NUM_HEADS]		; HPC
	mul word [SEC_PER_TRCK]	; SPT
	mov bx, ax	; BX = HPC * SPT
	mov ax, si
	xor dx, dx	; Set DX:AX to the LBA
	div bx
	push ax		; Push AX to the Stack to get the value later

	mov ax, si
	xor dx, dx		; Set DX:AX to LBA
	div word [SEC_PER_TRCK]	; ( LBA / SPT )
	xor dx, dx		; Set DX:AX to ( LBA / SPT )
	div word [NUM_HEADS]	; % HPC
	mov dh, dl		; Move it to DH
	push dx

	mov ax, si
	xor dx, dx		; Set DX:AX to LBA
	div word [SEC_PER_TRCK]	; % SPT
	inc dx
	mov di, dx

	pop dx				; Pop DX
	pop cx				; Pop CX

	pop si				; Pop SI off the Stack
	pop bx				; Pop BX off the Stack

	mov ax, cx	; Copy the Cylinder Value into AX from CX
	and cx, 0xFF	; AND CX with 255 ( This gets the low 8 bits )
	shl cx, 8	; Shift CX left by 8, into CH
	and ax, 0x300	; AND AX with 768 ( 0b 0000001100000000 ) ( This gets the high 2 bits )
	shr ax, 2	; Shift AX right by 2
	or cx, ax	; OR CX and AX
	or cx, di	; OR CX and DI to get the cylinder and sector together
	
	ret			; Return

ReadSectorsFromDrive:
	mov ah, 0x02	; Make sure 0x02 is in AH

	int 0x13	; Trigger the interrupt

	jc DiskError	; If the carry flag was set ( There was an Error ), jump to DiskError

	ret		; Return

DiskError:
	cli
	hlt

ReadRootDirectory:
	pusha	; Push all registers to the Stack

	mov ax, [FAT_ALLOC_TB]
	xor ah, ah
	mul word [SEC_PER_FAT]

	add ax, [NUM_RES_SECT]

	mov [RootDirectoryEnd], ax

	call LBAtoCHS	; Takes the LBA in AX ( already there )

	push cx
	push dx

	mov ax, [ROOT_DIR_ENT]
	mul byte [DirectoryEntrySize]	; (bootsec.ROOT_DIR_ENT * EntrySize)

	add ax, [BYTES_PER_SEC]		; + bootsec.BYTES_PER_SEC
	dec ax						; - 1
	xor dx, dx
	div word [BYTES_PER_SEC]	; / bootsec.BYTES_PER_SEC. This is a word the result should end up in DX ( remainder ) AX ( Result )

	add [RootDirectoryEnd], ax

	mov ah, 0x02

	pop dx
	pop cx

	mov dl, [DRIVE_NUM]

	mov bx, Buffer

	call ReadSectorsFromDrive

	popa		; Pop all the registers off of the Stack

	ret			; Return


SearchRootDirectory:
	xor ax, ax		; Also sets AX to 0 for the start of the entry count

	mov si, Buffer	; Start SI at the Buffer address

.searchrootdirectoryloop:
	push si		; Push SI so we can update it later

	mov di, KernelFileName

	mov cx, 11		; The name of an entry is 11 bytes, so we need to compare 11 bytes

	repe cmpsb		; Compare the strings

	pop si

	je .searchrootdirectorysuccess	; If they are equal, then jump to success

	cmp ax, [ROOT_DIR_ENT]			; If we are at the end of the Root Directory

	je .searchrootdirectoryfail		; Jump to fail

	mov cl, [DirectoryEntrySize]	; We can use CX here real quick
	add si, cx						; Go to the start of the next entry

	inc ax

	jmp .searchrootdirectoryloop	; If not equal but still have more entries, jump to the loop start

.searchrootdirectorysuccess:
	mov ax, [si + 26]			; 26 is the offset of the low first cluster of the entry
	mov [CurrentCluster], ax	; Move the starting cluster number into the Current Cluster

	ret		; Return

.searchrootdirectoryfail:
	cli	
	hlt

ReadFAT:
	pusha

	mov ax, [NUM_RES_SECT]	; Set the LBA to the start of the FAT. NUM_RES_SECT is 1

	call LBAtoCHS			; Convert the LBA into CHS

	mov ax, [SEC_PER_FAT]
	mul byte [FAT_ALLOC_TB]

	mov ah, 0x02
	mov dl, [DRIVE_NUM]
	mov bx, Buffer	; Set BX to the address of the Buffer

	call ReadSectorsFromDrive

	popa

	ret

ReadKernel:
	mov bx, KERNEL_SEGMENT
	mov es, bx
	mov bx, KERNEL_OFFSET

.readkernelloop:
	mov ax, [CurrentCluster]
	sub ax, 2
	mul byte [SEC_PER_CLUST]
	add al, [RootDirectoryEnd]		; AL because RootDirectoryEnd is a byte

	call LBAtoCHS	; Convert the LBA in CHS

	mov ah, 0x02
	mov al, [SEC_PER_CLUST]
	mov dl, [DRIVE_NUM]

	call ReadSectorsFromDrive	; Read the Sectors

	mov al, [SEC_PER_CLUST]	; bootsec.SEC_PER_CLUST. AL because SEC_PER_CLUST is a byte
	mul word [BYTES_PER_SEC]	; bootsec.SEC_PER_CLUST * bootsec.BYTES_PER_SEC
	add bx, ax	; buffer +=

	mov ax, [CurrentCluster]
	mov cx, 3
	mul cx
	mov cx, 2
	div cx

	mov di, ax	; Move the result to DI ( temporarily )

	mov si, Buffer
	add si, di		; (FileAllocationTable + fatIndex)
	mov di, [ds:si] ; Get the actual value on the FAT Table

	mov ax, [CurrentCluster]
	div cx	; CX should still be 2

	test dx, dx

	jz .currentclustereven
	jmp .currentclusterodd

.currentclustereven:
	and di, 0x0FFF	; & 0x0FFF

	mov [CurrentCluster], di	; CurrentCluster =
	
	jmp .readkernelloopend

.currentclusterodd:
	shr di, 4	; >> 4

	mov [CurrentCluster], di	; CurrentCluster =

	jmp .readkernelloopend

.readkernelloopend:
	cmp word [CurrentCluster], 0x0FF8

	jl .readkernelloop	; If the Current Cluster is less than 0x0FF8, then do the loop again
	
	ret		; If its done, return back


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
	; We can't turn on interrupts until we have an IDT

	; We need to set all the segment registers to their proper values
	mov ax, 0x10
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax

	; The stack pointer is probably fine where it is

	; We need to load the Kernel now
	; Get FAT working? No more interrupts until an IDT
	jmp 0x8:KERNEL_ADDRESS

	hlt	; Shouldn't get here if Kernel Jump is Successful

KERNEL_ADDRESS	equ 0x18000		; The Kernel will be loaded at address 0x18000
KERNEL_SEGMENT	equ 0x1800
KERNEL_OFFSET	equ 0x0000

Buffer equ 0x7E00

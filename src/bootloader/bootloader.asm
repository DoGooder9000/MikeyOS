org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

; FAT 12 HEADERS

jmp short start
nop

OEM_IDEN: 		db "MSWIN4.1"
BYTES_PER_SEC:	dw 512
SEC_PER_CLUST:	db 1
NUM_RES_SECT:	dw 1
FAT_ALLOC_TB:	db 2
ROOT_DIR_ENT:	dw 0xE0
NUM_SECTORS:	dw 2880
MED_DES_TYPE:	db 0xF0
SEC_PER_FAT:	dw 9
SEC_PER_TRCK:	dw 18
NUM_HEADS:		dw 2
HIDDEN_SEC:		dd 0
LARGE_SEC:		dd 0

; EXTENDED BOOT RECORD

DRIVE_NUM:		db 0
WINDOWS_FLAG:	db 0
DRIVE_SIG:		db 0x29
VOLUME_ID:		db 0x01, 0x23, 0x45, 0x67
VOLUME_LABEL:	db "MIKEYOS    "
SYS_IDEN_STR:	db "FAT12   "


start:
	mov [DriveNumber], dx	; BIOS puts the drive number in DX, so move it into a permanent memory location

	jmp main

print: ; Put the address of the line in SI
	push ax		; Store AX on the stack
	push si		; Store SI on the stack	
	
	jmp .printloop	; Goto .printloop

.printloop:
	lodsb		; Load the byte at DS:SI into AL ( lower half of AX )
	
	or al, al	; Check if AL is 0 ( End of the string )
	jz .printdone	; If AL is 0 jmp to .printdone

	mov ah, 0x0E	; Set the interrupt code for TTY Character Output
	int 0x10	; Call interrupt 0x10

	jmp .printloop

.printdone:
	pop si		; Put the previous value of SI back into SI
	pop ax		; Put the previous value of AX back into AX
	ret		; Return

printchar:
	; AL should hold the character

	push ax

	mov al, 'M'

	mov ah, 0x0E	; Move 0x02 into AH
	int 0x10	; Trigger interrupt 0x10

	pop ax

	ret		; Return

main:
	; Set all the segment registers to 0 ( boot sector )
	; Can't write directly to most of the registers	

	xor ax, ax	; Set AX to 0

	; Data segment registers

	; Segment Registers:
	; SS - Stack Segment Register
	; CS - Code Segment Register
	; DS - Data Segment Register
	; ES - Extra Data Segment Register
	; FS - More Extra Data Segment Register
	; GS - Even More Extra Data Segment Register

	mov ds, ax	; Set the Data Segment Register to 0
	mov es, ax	; Set the Extra Segment Register to 0

	mov ss, ax	; Set the Stack Segment Register to 0	

	; Stack Pointer
	; The Stack Pointer points to the top of the stack
	; The stack grows downwards, so put it at the start of the program

	mov sp, 0x7C00	; Stack Point to top of program

	mov si, msg
	call print

	mov ax, 1

	call LBAtoCHS
	call CHStoRightPlace

	; mov ch, 0	; Cylinder
	; mov dh, 0	; Head
	; mov cl, 2	; Sector

	mov ah, 0x02			; Interrupt funciton 0x02
	mov al, 0x01			; Sectors to read ( 1 )
	mov dl, [DriveNumber]	; The Drive number to read from

	xor bx, bx
	mov es, bx

	mov bx, 0x7E00	; ( ES:BX ) ( 0 : 0x7E00 )

	call ReadSectorsFromDrive

	jmp 0x7E00

	jmp haltloop
	
haltloop:
	hlt
	jmp haltloop

; DISK FUNCITONS

LBAtoCHS:
	; Parameters
	; AX - LBA

	; HPC - Heads per Cylinder ( Probably 2 )
	; SPT - Sectors per track ( Probably 18 )

	; Return
	; CX - Cylinder
	; DH - Head
	; DI - Sector

	; Cylinder 	= 	LBA / ( HPC * SPT )
	; Head		=	( LBA / SPT ) % HPT
	; Sector	=	( LBA % SPT ) + 1

	; We are going to use BX as an intermediary so

	push bx				; Push BX to the Stack
	push si				; Push SI to the Stack

	mov si, ax			; Put the LBA into SI from AX

	mov ax, [HeadsPerCylinder]	; Put the HPC into AX
	mov bx, [SectorsPerTrack]		; Put the SPT into BX

	mul bx				; Multiply HPC * SPT

	mov bx, ax			; Move AX into BX

	mov ax, si			; Move the LBA into AX

	xor dx, dx			; Set DX to 0

	div bx				; LBA / ( HPC * SPT )

	and ax, 0x00FF			; Keep only the lower 8 bits of AX

	mov cx, ax			; Move the result ( cylinder value ) into cx

	push CX				; Push CX to the Stack just in case

	; Cylinder is done

	
	; Head time
	; Head = ( LBA / SPT ) % HPC

	mov ax, si			; Move LBA into AX from SI

	mov bx, [SectorsPerTrack]		; Set BX to SPT

	xor dx, dx			; Set DX to 0

	div bx				; Divide AX ( LBA ) by BX ( SPT )

	and ax, 0x00FF			; We only want the bottom 8 bits ( the result )

	mov bx, [HeadsPerCylinder]	; Set BX to the HeadsPerCylinder

	xor dx, dx			; Set DX to 0

	div bx				; Divide ( or in our case modulus ) AX ( LBA / SPT ) and BX ( HPC )

	mov dh, dl			; Move the Modulus result ( stored in DL ) to DH ( where the Head value is stored )

	xor dl, dl			; Set DL to 0

	push dx				; Push DX to the Stack just in case

	; Head is done

	
	; Sector time
	; Sector = ( LBA % SPT ) + 1

	mov ax, si			; Move LBA from SI into AX

	mov bx, [SectorsPerTrack]		; Move SPT into BX

	xor dx, dx			; Set DX to 0

	div bx				; Divide ( modulus ) AX ( LBA ) by BX ( SPT )

	mov ax, dx			; Modulus result is stored in DX, so move it to AX

	mov di, ax			; Move the reminder into DI

	inc di				; Add one to DI

	push di				; Push DI to the Stack just in case

	; Sectors are done

	; Cleanup time

	pop di				; Pop DI
	pop dx				; Pop DX
	pop cx				; Pop CX

	pop si				; Pop SI off the Stack
	pop bx				; Pop BX off the Stack

	ret				; Return

CHStoRightPlace:
	; Put HEAD in DH

	; PUT CYLINDER IN 	CX
	; PUT SECTOR IN 	DI

	push ax		; Push AX onto the Stack so we can use it as an intermediary

	mov ax, cx	; Copy the Cylinder Value into AX from CX

	and cx, 0xFF	; AND CX with 255 ( This gets the low 8 bits )
	shl cx, 8	; Shift CX left by 8, into CH
	
	; Next, move Sector into the right place

	and ax, 0x300	; AND AX with 768 ( 0b 0000001100000000 ) ( This gets the high 2 bits )
	shr ax, 2	; Shift AX right by 2

	; Or the Cylinder and Sector together

	or cx, ax	; OR CX and AX
	
	or cx, di	; OR CX and DI to get the cylinder and sector together

	pop ax		; Pop the previous value of AX from the stack

	
	ret			; Return


ResetDiskSystem:
	; Parameters
	;
	; Interrupt 0x13 0x00
	; AH - 0x00
	; DL - Drive ( probably 0x00 )

	push ax		; Push AX to the Stack
	push dx		; Push DX to the Stack

	clc		; Clear the carry flag

	mov ah, 0x00	; Set AH to 0x00
	mov dl, 0x00	; First Floppy Disk

	int 0x13	; Trigger interrupt 0x13

	jc DiskError	; Jump if the carry flag was set ( if something went wrong )

	pop dx		; Pop DX
	pop ax		; Pop AX

	ret		; Return

ReadSectorsFromDrive:
	; Parameters
	;
	; Interrupt 0x13
	; AH 	- 0x02
	; AL 	- Sectors to Read Count
	; CH 	- Cylinder
	; CL 	- Sector
	; DH 	- Head
	; DL 	- Drive
	; ES:BX - Buffer Address Pointer

	; CX		= ---CH--- ---CL---
	; Cylinder	= 0000000 00
	; Sector	=           000000

	; Addressing of Buffer should guarantee that the complete buffer is inside the given segment
	; ( BX + size_of_buffer ) <= 0x10000

	; Start of calling the actual interrupt

	mov ah, 0x02	; Make sure 0x02 is in AH

	int 0x13	; Trigger the interrupt

	jc DiskError	; If the carry flag was set ( There was an Error ), jump to DiskError


	ret		; Return

GetStatusOfLastDriveOperation:
	; Parameters
	;
	; AH	- 01h
	; DL	- Drive ( Probably 0x00 )

	; We will return the value of this function in AH
	; AH will hold the return code

	push dx		; Push DX to the Stack

	mov ah, 0x01	; Set AH to 0x01
	mov dl, 0x00	; Set DL to 0x00

	int 0x13	; Trigger interrupt 0x13

	pop dx		; Pop DX
	
	ret		; Return

DiskError:
	mov si, DiskErrorMessage	; Move the Error Message into SI
	call print			; Call the print function

	; TODO - Add error code printing

	; Halt the OS

	hlt				; Halt

	jmp haltloop

msg: db "Hello, World!", ENDL, 0

HeadsPerCylinder: db 2
SectorsPerTrack: db 18

DriveNumber: db 0x00

; Error Messages
DiskErrorMessage: db "Disk Error", ENDL, 0

times 510-($-$$) db 0x00	; Run ( db 0x00 ) 510-($-$$) times
				; $ = Current Location ; $$ = Start of program location

dw 0xAA55
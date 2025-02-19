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
	mov [DRIVE_NUM], dl	; BIOS puts the drive number in DX, so move it into a permanent memory location

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

	; Perform a far jump to make sure that we are at Code Segment 0
	; Retf ( Return Far ) takes the Instruction Pointer and Code Segment Register from the stack
	; We need to push 0 ( for the code segment reg ) and the address to jump to

	push es			; Push 0 to the Stack
	push word main	; Push where we want to jump to ( main )
	retf			; Far jump which gets us to CS 0

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

main:
	jmp LoadKernel
	
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

	mov ax, [NUM_HEADS]		; HPC
	mul word [SEC_PER_TRCK]	; SPT

	mov bx, ax	; BX = HPC * SPT

	mov ax, si
	xor dx, dx	; Set DX:AX to the LBA

	div bx
	; Result should be in AX

	push ax		; Push AX to the Stack to get the value later

	; Cylinder is done
	
	; Head time
	; Head = ( LBA / SPT ) % HPC

	mov ax, si
	xor dx, dx		; Set DX:AX to LBA

	div word [SEC_PER_TRCK]	; ( LBA / SPT )
	; Result should be in AX
	xor dx, dx		; Set DX:AX to ( LBA / SPT )

	div word [NUM_HEADS]	; % HPC
	; Modulus result should be in DX ( DL )
	mov dh, dl		; Move it to DH
	push dx

	; Head is done
	
	; Sector time
	; Sector = ( LBA % SPT ) + 1

	mov ax, si
	xor dx, dx		; Set DX:AX to LBA

	div word [SEC_PER_TRCK]	; % SPT

	inc dx

	mov di, dx

	; Sectors are done

	; Cleanup time

	pop dx				; Pop DX
	pop cx				; Pop CX

	pop si				; Pop SI off the Stack
	pop bx				; Pop BX off the Stack

	; Convert to proper places expected by the BIOS

	; Put HEAD in DH

	; PUT CYLINDER IN 	CX
	; PUT SECTOR IN 	DI

	mov ax, cx	; Copy the Cylinder Value into AX from CX

	and cx, 0xFF	; AND CX with 255 ( This gets the low 8 bits )
	shl cx, 8	; Shift CX left by 8, into CH
	
	; Next, move Sector into the right place

	and ax, 0x300	; AND AX with 768 ( 0b 0000001100000000 ) ( This gets the high 2 bits )
	shr ax, 2	; Shift AX right by 2

	; Or the Cylinder and Sector together

	or cx, ax	; OR CX and AX
	
	or cx, di	; OR CX and DI to get the cylinder and sector together
	
	ret			; Return

ResetDiskSystem:
	; Parameters
	;
	; Interrupt 0x13 0x00
	; AH - 0x00
	; DL - Drive ( probably 0x00 )

	clc		; Clear the carry flag

	mov ah, 0x00	; Set AH to 0x00
	mov dl, 0x00	; First Floppy Disk

	int 0x13	; Trigger interrupt 0x13

	jc DiskError	; Jump if the carry flag was set ( if something went wrong )

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

	mov ah, 0x01	; Set AH to 0x01
	mov dl, 0x00	; Set DL to 0x00

	int 0x13	; Trigger interrupt 0x13
	
	ret		; Return

DiskError:
	mov si, DiskErrorMessage	; Move the Error Message into SI
	call print			; Call the print function

	; TODO - Add error code printing

	jmp haltloop

LoadKernel:
	; Process of Loading Kernel
	; 1. Read / Load the Root Directory
	; 2. Lookup Kernel.bin in the Root Directory
	; 3. Read / Load the File Allocation Table ( FAT )
	; 4. Read Kernel.bin into a memory location
	; 5. Jump to the start of Kernel.bin in memory

	; 1. Read the Root Directory
	call ReadRootDirectory

	; 2. Lookup Kernel.bin in the Root Directory
	; We need to compare the "KERNEL  BIN" to the Root Directory
	call SearchRootDirectory
	; DS:SI should have the address of "KERNEL  BIN"

	; 3. Read FAT
	call ReadFAT
	; FAT should be in Buffer now
	
	; 4. Read Kernel.bin into a memory location
	call ReadKernel

	; 5. Jump to the start of Kernel.bin in memory
	mov ax, KERNEL_SEGMENT
	mov ds, ax
	mov es, ax

	jmp KERNEL_SEGMENT:KERNEL_OFFSET

	; should never get here

ReadRootDirectory:
	; Read / Load the Root Directory

	; First, we need to read the Root Directory into memory
	
	pusha	; Push all registers to the Stack
	
	; RootDirectoryStart = bootsec.NUM_RES_SECT + FATSectorCount
	; First, calculate the FAT Sector Count
	; FATSectorCount = bootsec.FAT_ALLOC_TB * bootsec.SEC_PER_FAT
	mov ax, [FAT_ALLOC_TB]
	xor ah, ah
	mul word [SEC_PER_FAT]

	; AX should now have the FAT Sector Count
	; Now add the number of Reserved Sectors
	add ax, [NUM_RES_SECT]
	; AX now has the Root Directory Start value

	mov [RootDirectoryEnd], ax		; Make the calculations shorter for ReadKernel

	; Now we need to read the Root Directory into Memory
	; We will use the Buffer location

	; First we need to convert LBA into CHS
	call LBAtoCHS	; Takes the LBA in AX ( already there )

	push cx
	push dx

	; We need to calculate the number of sectors to read
	; RootDirectorySectorLength = (RootDirectoryByteLength + bootsec.BYTES_PER_SEC - 1) / bootsec.BYTES_PER_SEC
	; RootDirectoryByteLength = (bootsec.ROOT_DIR_ENT * EntrySize)
	; EntrySize = 32

	; First calculate the RootDirectoryByteLength
	mov ax, [ROOT_DIR_ENT]
	mul byte [DirectoryEntrySize]	; (bootsec.ROOT_DIR_ENT * EntrySize)
	; RootDirectoryByteLength is in AX

	; Now calculate the Sector Length
	add ax, [BYTES_PER_SEC]		; + bootsec.BYTES_PER_SEC
	dec ax						; - 1
	xor dx, dx
	div word [BYTES_PER_SEC]	; / bootsec.BYTES_PER_SEC. This is a word the result should end up in DX ( remainder ) AX ( Result )
	; Result is in AX
	; AX has the number of sectors to read

	add [RootDirectoryEnd], ax		; Make the calculations shorter for ReadKernel	

	; Read the sectors
	; AH 	- 0x02
	; AL 	- Sectors to Read Count
	; CH 	- Cylinder
	; CL 	- Sector
	; DH 	- Head
	; DL 	- Drive
	; ES:BX - Buffer Address Pointer

	mov ah, 0x02

	pop dx
	pop cx

	mov dl, [DRIVE_NUM]

	mov bx, Buffer

	call ReadSectorsFromDrive

	; Root Directory should be in Buffer

	popa		; Pop all the registers off of the Stack

	ret			; Return

SearchRootDirectory:
	; Byte Name[11]
	; Byte Attributes
	; Byte _Reserved
	; Byte CreatedTimeTenths
	; Word CreatedTime
	; Word CreatedDate
	; Word AccessedDate
	; Word FirstClusterHigh
	; Word ModifiedTime
	; Word ModifiedDate
	; Word FirstClusterLow
	; Double Size

	; We need to compare "KERNEL  BIN" to every directory entry until we find it
	
	; CMPSB - Compares byte at address DS:(E)SI with byte at address ES:(E)DI
	; REPE/REPZ - RCX or (E)CX = 0	ZF = 0

	xor ax, ax		; Also sets AX to 0 for the start of the entry count

	mov si, Buffer	; Start SI at the Buffer address

	jmp .searchrootdirectoryloop

.searchrootdirectoryloop:
	; DS and ES should both be 0

	; SI is the entry location
	push si		; Push SI so we can update it later
	
	; DI is going to be a pointer to "KERNEL  BIN"
	mov di, FATKernelFileName

	mov cx, 11		; The name of an entry is 11 bytes, so we need to compare 11 bytes

	repe cmpsb						; Compare the strings

	pop si

	je .searchrootdirectorysuccess	; If they are equal, then jump to success

	cmp ax, [ROOT_DIR_ENT]			; If we are at the end of the Root Directory

	je .searchrootdirectoryfail		; Jump to fail

	mov cl, [DirectoryEntrySize]	; We can use CX here real quick
	add si, cx						; Go to the start of the next entry

	inc ax

	jmp .searchrootdirectoryloop	; If not equal but still have more entries, jump to the loop start

.searchrootdirectorysuccess:
	; DS:SI should point to the address of the right entry

	mov ax, [si + 26]			; 26 is the offset of the low first cluster of the entry
	mov [CurrentCluster], ax	; Move the starting cluster number into the Current Cluster

	ret		; Return

.searchrootdirectoryfail:
	mov si, RootDirSearchFailed
	call print

	jmp haltloop

ReadFAT:
	pusha

	; AX - LBA
	mov ax, [NUM_RES_SECT]	; Set the LBA to the start of the FAT. NUM_RES_SECT is 1

	call LBAtoCHS			; Convert the LBA into CHS

	; Actually read the Sectors
	; AH 	- 0x02
	; AL 	- Sectors to Read Count
	; CH 	- Cylinder
	; CL 	- Sector
	; DH 	- Head
	; DL 	- Drive
	; ES:BX - Buffer Address Pointer
	
	; Set the Sectors to Read
	mov ax, [SEC_PER_FAT]
	mul byte [FAT_ALLOC_TB]
	; AX ( or AL because the value is so small ) should have the Sectors to Read
	; AL should be 18 ( Num of FAT Sectors )

	mov ah, 0x02

	; Set the Drive in DL. Really not necessary because the drive is almost always goina be 0 ( for floppies at least )
	mov dl, [DRIVE_NUM]

	; ES is already set to 0
	mov bx, Buffer	; Set BX to the address of the Buffer

	; Call ReadSectorsFromDrive
	call ReadSectorsFromDrive

	; The FAT Sectors should be loaded into the Buffer now

	popa

	ret

ReadKernel:
	; The FAT is in the Buffer

	; We are going to put the Kernel load location in ES:BX
	mov bx, KERNEL_SEGMENT
	mov es, bx
	mov bx, KERNEL_OFFSET

.readkernelloop:
	; This is the loop for reading the Kernel.bin File

	; LBA = RootDirectoryEnd + ((CurrentCluster - 2) * bootsec.SEC_PER_CLUST);
	; Calculate LBA
	mov ax, [CurrentCluster]
	sub ax, 2
	mul byte [SEC_PER_CLUST]
	add al, [RootDirectoryEnd]		; AL because RootDirectoryEnd is a byte
	; LBA is in AX

	call LBAtoCHS	; Convert the LBA in CHS

	; Read the Kernel
	; AH 	- 0x02
	; AL 	- Sectors to Read Count
	; CH 	- Cylinder
	; CL 	- Sector
	; DH 	- Head
	; DL 	- Drive
	; ES:BX - Buffer Address Pointer

	mov ah, 0x02
	mov al, [SEC_PER_CLUST]
	mov dl, [DRIVE_NUM]

	call ReadSectorsFromDrive	; Read the Sectors

	; Increment the Kernel Pointer
	; buffer += bootsec.SEC_PER_CLUST * bootsec.BYTES_PER_SEC
	mov al, [SEC_PER_CLUST]	; bootsec.SEC_PER_CLUST. AL because SEC_PER_CLUST is a byte
	mul word [BYTES_PER_SEC]	; bootsec.SEC_PER_CLUST * bootsec.BYTES_PER_SEC
	add bx, ax	; buffer +=
	; NOTE! THE ABOVE OPERATION COULD OVERFLOW IF KERNEL.BIN IS OVER 64 KB

	; Calculate FAT index
	; fatIndex = CurrentCluster * 3 / 2;
	mov ax, [CurrentCluster]
	mov cx, 3
	mul cx
	mov cx, 2
	div cx
	; Result should be in AX
	mov di, ax	; Move the result to DI ( temporarily )
	; DI should have the FAT Index

	; (FileAllocationTable + fatIndex)
	mov si, Buffer
	add si, di		; (FileAllocationTable + fatIndex)
	mov di, [ds:si] ; Get the actual value on the FAT Table
	; DI had the FAT index

	; (CurrentCluster % 2 == 0)
	mov ax, [CurrentCluster]
	div cx	; CX should still be 2
	; Remainder should be in DX

	test dx, dx

	jz .currentclustereven
	jmp .currentclusterodd

.currentclustereven:
	; CurrentCluster = (*(FileAllocationTable + fatIndex)) & 0x0FFF
	and di, 0x0FFF	; & 0x0FFF

	mov [CurrentCluster], di	; CurrentCluster =
	
	jmp .readkernelloopend

.currentclusterodd:
	; CurrentCluster = (*(FileAllocationTable + fatIndex)) >> 4
	shr di, 4	; >> 4

	mov [CurrentCluster], di	; CurrentCluster =

	jmp .readkernelloopend

.readkernelloopend:
	; while (good && CurrentCluster < 0x0FF8);

	cmp word [CurrentCluster], 0x0FF8

	jl .readkernelloop	; If the Current Cluster is less than 0x0FF8, then do the loop again
	
	ret		; If its done, return back

FATKernelFileName: db "KERNEL  BIN"

; FATStart = 1 = bootsec.NUM_RES_SECT
; FATSectorCount = 18 = bootsec.FAT_ALLOC_TB * bootsec.SEC_PER_FAT
; FATSize = 0x2400 = FATSectorCount * bootsec.BYTES_PER_SEC
; 
; EntrySize = 32 Bytes
; 
; RootDirectoryStart = 19 = bootsec.NUM_RES_SECT + FATSectorCount
; RootDirectoryByteLength = 0x1C00 = (bootsec.ROOT_DIR_ENT * EntrySize)
; RootDirectorySectorLength = 14 = (RootDirectoryByteLength + bootsec.BYTES_PER_SEC - 1) / bootsec.BYTES_PER_SEC // Rounds up to the nearest whole sector
; RootDirectoryPaddedByteLength = 0x1C00 = RootDirectorySectorLength * bootsec.BYTES_PER_SEC
; RootDirectoryEnd = 34 = RootDirectoryStart + RootDirectorySectorLength

; Error Messages
DiskErrorMessage: db "DError", ENDL, 0
RootDirSearchFailed: db "RDSF", ENDL, 0

DirectoryEntrySize: db 32
RootDirectoryEnd: db 0

CurrentCluster: dw 0

KERNEL_SEGMENT	equ 0x1800
KERNEL_OFFSET	equ 0

times 510-($-$$) db 0x00	; Run ( db 0x00 ) 510-($-$$) times
				; $ = Current Location ; $$ = Start of program location

dw 0xAA55

Buffer:
	; The Buffer label has no physical size. It is just a location for the assembler to point to in the code
	; This means that "Buffer" will not cause the Bootloader to exceed the maximum 512 bytes in the boot sector
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
	mov [DRIVE_NUM], dl

	xor ax, ax

	mov ds, ax
	mov es, ax
	mov ss, ax

	mov sp, 0x7C00

	push es
	push word LoadStage2
	retf
	
haltloop:
	hlt
	jmp haltloop

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

ResetDiskSystem:
	clc		; Clear the carry flag

	mov ah, 0x00	; Set AH to 0x00
	mov dl, 0x00	; First Floppy Disk

	int 0x13	; Trigger interrupt 0x13

	jc DiskError	; Jump if the carry flag was set ( if something went wrong )

	ret		; Return

ReadSectorsFromDrive:
	mov ah, 0x02	; Make sure 0x02 is in AH

	int 0x13	; Trigger the interrupt

	jc DiskError	; If the carry flag was set ( There was an Error ), jump to DiskError

	ret		; Return

DiskError:
	jmp haltloop

LoadStage2:
	call ReadRootDirectory
	call SearchRootDirectory
	call ReadFAT
	call ReadStage2
	mov ax, STAGE2_SEGMENT
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax

	jmp STAGE2_SEGMENT:STAGE2_OFFSET

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

	mov di, Stage2FileName

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
	mov ax, [si + 26]			; 26 is the offset of the low first cluster of the entry
	mov [CurrentCluster], ax	; Move the starting cluster number into the Current Cluster

	ret		; Return

.searchrootdirectoryfail:
	jmp haltloop

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

ReadStage2:
	mov bx, STAGE2_SEGMENT
	mov es, bx
	mov bx, STAGE2_OFFSET

.readstage2loop:
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
	
	jmp .readstage2loopend

.currentclusterodd:
	shr di, 4	; >> 4

	mov [CurrentCluster], di	; CurrentCluster =

	jmp .readstage2loopend

.readstage2loopend:
	cmp word [CurrentCluster], 0x0FF8

	jl .readstage2loop	; If the Current Cluster is less than 0x0FF8, then do the loop again
	
	ret		; If its done, return back


Stage2FileName: db "STAGE2  BIN"

DirectoryEntrySize: db 32
RootDirectoryEnd: db 0

CurrentCluster: dw 0

STAGE2_SEGMENT	equ 0x1800
STAGE2_OFFSET	equ 0

times 510-($-$$) db 0x00	; Run ( db 0x00 ) 510-($-$$) times

dw 0xAA55

Buffer:
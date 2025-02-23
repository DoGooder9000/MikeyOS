org 0x18000
bits 32

%define ENDL 0x0D, 0x0A
%define WhiteOnBlack 0x0F
%define BlackOnBlack 0x00

CHAR_WIDE equ 80
CHAR_ROWS equ 25

start:
	; Write to the screen without interrupts
	call ClearScreen

	mov esi, msg
	mov ecx, 0
	call PrintString

	cli
	hlt

PrintString:
	; Input: ECX = Upper 16 bits is the row ( y-val ), lower 16 bits is the column ( x-val )
	mov bl, WhiteOnBlack

	jmp .printstringloop

.printstringloop:

	; Input: ESI = address of string to print
	mov al, [esi]

	cmp al, 0
	je .printstringdone

	call printchar
	inc ecx
	inc esi

	jmp .printstringloop

.printstringdone:
	ret

ClearScreen:
	mov edx, (CHAR_ROWS * CHAR_WIDE)

	mov al, ' '
	mov bl, BlackOnBlack
	mov ecx, 0

	jmp .clearscreenloop

.clearscreenloop:
	cmp ecx, edx
	je .clearscreenend

	call printchar
	inc ecx

	jmp .clearscreenloop

.clearscreenend:
	ret

printchar:
	; Print a character to the screen
	; Input: AL = character to print
	; Input: BL = fore/background color
	; Bit 76543210
    ;	  ||||||||
    ;	  |||||^^^-fore colour
    ;	  ||||^----fore colour bright bit
    ;	  |^^^-----back colour
    ;	  ^--------back colour bright bit OR enables blinking Text
	; Input: ECX = Upper 16 bits is the row ( y-val ), lower 16 bits is the column ( x-val )


	pusha
	mov esi, 0xB8000

	; position = (y_position * characters_per_line) + x_position;

	push eax

	; Calculate the (y_position * characters_per_line) part
	mov eax, ecx
	and eax, 0xFFFF0000
	shr eax, 16				; 0x0000FFFF

	; We already pushed edx with pusha
	mov edx, CHAR_WIDE
	mul edx

	; Done with the (y_position * characters_per_line) part

	; Calculate the + x_position part
	and ecx, 0x0000FFFF
	add eax, ecx

	mov edx, 2
	mul edx		; Multiply by 2 because each character is 2 bytes

	add esi, eax

	pop eax

	mov [esi], al

	mov [esi+1], bl

	popa

	ret

msg: db "Hello from the Kernel!", 0
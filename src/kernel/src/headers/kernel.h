#ifndef KERNEL_H
#define KERNEL_H

#define VIDEO_MEMORY 0xB8000
#define CHAR_PER_LINE 80
#define LINES 25

#define WhiteOnBlack 0x0F
#define GreyOnBlack 0x07
#define BlackOnBlack 0x00

#define uint8 unsigned char
#define uint16 unsigned short int
#define uint32 unsigned long int

#define sint8 signed char
#define sint16 signed short int
#define sint32 signed long int

void cli();
void halt();

void ClearScreen();
void Print(char* msg, int msg_len, uint8 color);

#endif
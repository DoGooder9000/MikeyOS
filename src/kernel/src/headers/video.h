#ifndef VIDEO_H
#define VIDEO_H

#include "stdint.h"

#define VIDEO_MEMORY 0xB8000
#define CHAR_PER_LINE 80
#define LINES 25

#define WhiteOnBlack 0x0F
#define GreyOnBlack 0x07
#define BlackOnBlack 0x00

void ClearScreen();
int Print(char* msg, uint8 color, int char_offset);
int StartOfLine(int char_offset);
int NewLine(int char_offset);

#endif
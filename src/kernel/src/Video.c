#include "headers/video.h"
#include "headers/stdint.h"
#include "headers/string.h"

void ClearScreen(){
	char *VidMemAddr = (char *)VIDEO_MEMORY;

	for(int i = 0; i < CHAR_PER_LINE * LINES * 2; i += 2){
		VidMemAddr[i] = ' '; // Set character to space
		VidMemAddr[i + 1] = BlackOnBlack; // Set attribute byte
	}
}

int Print(char* msg, uint8 color, int start_offset){
	uint8* VidMemAddr = (uint8 *)VIDEO_MEMORY + start_offset * 2;
	int char_offset = start_offset;

	for(int i = 0; i < strlen(msg); i++){
		if (msg[i] == '\n'){
			char_offset = NewLine(char_offset);
			continue;
		}

		VidMemAddr[char_offset*2] = msg[i]; // Set character
		VidMemAddr[char_offset*2 + 1] = color; // Set attribute byte

		char_offset++;
	}

	return char_offset;
}

int StartOfLine(int char_offset){
	return char_offset - (char_offset % CHAR_PER_LINE);
}

int NewLine(int char_offset){
	return StartOfLine(char_offset + CHAR_PER_LINE);
}
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

int Print(char* msg, uint8 color, int start_offset){	// start_offset is in characters, not bytes
	uint8* vid_addr = (uint8*)VIDEO_MEMORY + (start_offset*2);
	int cursor_pos = start_offset;	// cursor_pos is in characters not bytes

	for (int i=0; i<strlen(msg); i++){
		if (msg[i] == '\n'){
			cursor_pos = NewLine(cursor_pos);
			continue;
		}

		vid_addr[0] = msg[i];
		vid_addr[1] = color;

		vid_addr += 2;
		cursor_pos++;
	}

	return cursor_pos;
}

int StartOfLine(int char_offset){
	return char_offset - (char_offset % CHAR_PER_LINE);
}

int NewLine(int char_offset){
	return StartOfLine(char_offset + CHAR_PER_LINE);
}
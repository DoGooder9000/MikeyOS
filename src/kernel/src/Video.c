#include "headers/kernel.h"

void ClearScreen(){
	char *VidMemAddr = (char *)VIDEO_MEMORY;
	for(int i = 0; i < CHAR_PER_LINE * LINES * 2; i += 2){
		VidMemAddr[i] = ' '; // Set character to space
		VidMemAddr[i + 1] = BlackOnBlack; // Set attribute byte
	}
}

void Print(char* msg, int msg_len, uint8 color){
	char *VidMemAddr = (char *)VIDEO_MEMORY;
	for(int i = 0; i < msg_len; i++){
		VidMemAddr[i * 2] = msg[i]; // Set character
		VidMemAddr[i * 2 + 1] = color; // Set attribute byte
	}
}
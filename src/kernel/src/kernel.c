#include "headers/kernel.h"

void KernelMain();

const char* msg = "C Kernel Loaded";
int msg_len = 16;

__attribute__((section(".text._start"))) void _start(){
	KernelMain();

	while(1){
		halt();
	}
}

void KernelMain(){
	cli();

	ClearScreen();
	Print(msg, strlen(msg), GreyOnBlack, 0);

	halt();
}
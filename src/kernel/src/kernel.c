#include "headers/kernel.h"

void KernelMain();

char* msg = "C Kernel Loaded";
int msg_len = 15;

__attribute__((section(".text._start"))) void _start(){
	// Call the kernel main function
	KernelMain();

	while(1){
		halt();
	}
}

void KernelMain(){
	cli();

	ClearScreen();
	Print(msg, msg_len, GreyOnBlack);

	halt();
}
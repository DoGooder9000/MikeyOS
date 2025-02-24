#include "headers/kernel.h"
#include "headers/video.h"
#include "headers/idt.h"

void KernelMain();

int CursorPos = 0;

__attribute__((section(".text._start"))) void _start(){
	KernelMain();

	while(1){
		halt();
	}
}

void KernelMain(){
	cli();

	ClearScreen();
	CursorPos = Print((char*)"C Kernel Loaded\n", GreyOnBlack, CursorPos);

	LoadIDT();
	CursorPos = Print((char*)"Loaded IDT\n", GreyOnBlack, CursorPos);

	halt();
}
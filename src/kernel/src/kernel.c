#include "headers/kernel.h"
#include "headers/video.h"
#include "headers/idt.h"
#include "headers/string.h"

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
	CursorPos = Print((char*)"C Kernel is Loaded\n", GreyOnBlack, CursorPos);

	LoadIDT();
	CursorPos = Print((char*)"IDT is loaded", GreyOnBlack, CursorPos);

	halt();
}
#include "headers/idt.h"
#include "headers/stdint.h"

IDT_Entry IDT[IDT_SIZE] = {0};

IDT_Descriptor IDT_Desc = {
	sizeof(IDT) - 1,
	IDT
};

void SetEntry(int interrupt, uint32 base, uint16 gdt_selector, uint8 flags){
	IDT[interrupt].Base_Low = base & 0xFFFF;
	IDT[interrupt].Base_High = (base >> 16) & 0xFFFF;
	IDT[interrupt].Selector = gdt_selector;
	IDT[interrupt].Reserved = 0;
	IDT[interrupt].Flags = flags;
}

void LoadIDT(){
	asm volatile("lidt %0" : : "m" (IDT_Desc));
}
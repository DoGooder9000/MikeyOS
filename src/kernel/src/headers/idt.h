#ifndef IDT_H
#define IDT_H

#include "stdint.h"

#define IDT_SIZE 256

typedef struct {
	uint16 Base_Low;
	uint16 Selector;
	uint8 Reserved;
	uint8 Flags;
	uint16 Base_High;
} __attribute__((packed)) IDT_Entry;

typedef struct{
	uint16 Limit;
	IDT_Entry* Base;
} __attribute__((packed)) IDT_Descriptor;

typedef enum{
	TASK_GATE		= 0x05,
	BIT_16_INT		= 0x06,
	BIT_16_TRAP		= 0x07,
	BIT_32_INT		= 0x0E,
	BIT_32_TRAP		= 0x0F,

	PRIVILAGE_0		= 0x00,
	PRIVILAGE_1		= 0x20,
	PRIVILAGE_2		= 0x40,
	PRIVILAGE_3		= 0x60,

	PRESENT			= 0x80
} __attribute__((packed)) IDT_FLAGS;

void LoadIDT();
void SetEntry(int interrupt, uint32 base, uint16 gdt_selector, uint8 flags);

#endif
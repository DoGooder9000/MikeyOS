ENTRY(_start)

SECTIONS {
    . = 0x18000;
    
    .text ALIGN(4K) : {
        *(.text._start)
        *(.text)
    }

    .rodata ALIGN(4K) : {
        *(.rodata)
    }

    .data ALIGN(4K) : {
        *(.data)
    }

    .bss ALIGN(4K) : {
        *(COMMON)
        *(.bss)
    }
}
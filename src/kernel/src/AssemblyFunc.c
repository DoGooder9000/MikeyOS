#include "headers/kernel.h"

void cli(){
    asm("cli");
}

void halt(){
    asm("hlt");
}
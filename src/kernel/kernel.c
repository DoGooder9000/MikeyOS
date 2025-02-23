#define VIDEO_MEMORY 0xB8000
#define CHAR_PER_LINE 80
#define LINES 25

#define WhiteOnBlack 0x0F

void KernelMain();
void cli();
void halt();

char* msg = "C Kernel Loaded";
int msg_len = 15;

void _start(){
	// Call the kernel main function
	KernelMain();

	while(1){
		halt();
	}
}

void KernelMain(){
	cli();

	char* msg = "C Kernel Loaded";
	int msg_len = 15;

	// Clear the screen
	char *VidMemAddr = (char *)VIDEO_MEMORY;
	for(int i = 0; i < CHAR_PER_LINE * LINES * 2; i++){
		VidMemAddr[i] = 0;
	}

	// Print a message
	for(int i = 0; i < msg_len; i++){
		VidMemAddr[i * 2] = msg[i];
		VidMemAddr[i * 2 + 1] = WhiteOnBlack;	// Light Grey on black
	}

	//return;
}

void cli(){
	asm("cli");
}

void halt(){
	// Halt the CPU
	asm("hlt");
}
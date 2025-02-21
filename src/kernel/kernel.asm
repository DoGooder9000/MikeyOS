org 0x18000
bits 32

%define ENDL 0x0D, 0x0A

start:
	cli
	hlt

msg: db "Hello from the Kernel!", ENDL, 0

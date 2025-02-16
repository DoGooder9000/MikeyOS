#include <stdio.h>
#include <stdint.h>

int main(int argc, char* argv[]){
	if (argc < 3){
		printf("Argmument format: <Disk Image> <File name (in FAT form)> ");
		return -1;
	}

	printf("Disk Image: %s\n", argv[1]);
	printf("File Name: \"%s\"\n", argv[1]);
	
	return 0;
}
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

typedef uint8_t bool;
#define true 1
#define false 0

bool readBootSector(FILE* disk);
bool readSectors(FILE* disk, uint32_t lba, uint32_t count, void* bufferOut);
bool readFat(FILE* disk);
bool readRootDirectory(FILE* disk);
struct DirectoryEntry* findFile(const char* name);
bool readFile(struct DirectoryEntry* fileEntry, FILE* disk, uint8_t* outputBuffer);

struct __attribute__((packed)) BootSector{
	uint8_t BootJumpInstruction[3];
	uint8_t OemIdentifier[8];
	uint16_t BytesPerSector;
	uint8_t SectorsPerCluster;
	uint16_t ReservedSectors;
	uint8_t FatCount;
	uint16_t DirEntryCount;
	uint16_t TotalSectors;
	uint8_t MediaDescriptorType;
	uint16_t SectorsPerFat;
	uint16_t SectorsPerTrack;
	uint16_t Heads;
	uint32_t HiddenSectors;
	uint32_t LargeSectorCount;

	// extended boot record
	uint8_t DriveNumber;
	uint8_t _Reserved;
	uint8_t Signature;
	uint32_t VolumeId;          // serial number, value doesn't matter
	uint8_t VolumeLabel[11];    // 11 bytes, padded with spaces
	uint8_t SystemId[8];
};

struct __attribute__((packed)) DirectoryEntry{
	uint8_t Name[11];
	uint8_t Attributes;
	uint8_t _Reserved;
	uint8_t CreatedTimeTenths;
	uint16_t CreatedTime;
	uint16_t CreatedDate;
	uint16_t AccessedDate;
	uint16_t FirstClusterHigh;
	uint16_t ModifiedTime;
	uint16_t ModifiedDate;
	uint16_t FirstClusterLow;
	uint32_t Size;
};

struct BootSector bootsec;
uint8_t* g_Fat = NULL;
struct DirectoryEntry* g_RootDirectory = NULL;
uint32_t g_RootDirectoryEnd;

int main(int argc, char* argv[]){
	if (argc < 3) {
		printf("Syntax: %s <disk image> <file name>\n", argv[0]);
		return -1;
	}

	FILE* disk = fopen(argv[1], "rb");
	if (!disk) {
		printf("Cannot open disk image %s!\n", argv[1]);
		return -1;
	}

	if (!readBootSector(disk)) {
		printf("Could not read boot sector!\n");
		return -2;
	}

	if (!readFat(disk)) {
		printf("Could not read FAT!\n");
		free(g_Fat);
		return -3;
	}

	if (!readRootDirectory(disk)) {
		printf("Could not read FAT!\n");
		free(g_Fat);
		free(g_RootDirectory);
		return -4;
	}

	struct DirectoryEntry* fileEntry = findFile(argv[2]);
	if (!fileEntry) {
		printf("Could not find file %s!\n", argv[2]);
		free(g_Fat);
		free(g_RootDirectory);
		return -5;
	}

	uint8_t* buffer = (uint8_t*) malloc(fileEntry->Size + bootsec.BytesPerSector);
	if (!readFile(fileEntry, disk, buffer)) {
		printf("Could not read file %s!\n", argv[2]);
		free(g_Fat);
		free(g_RootDirectory);
		free(buffer);
		return -5;
	}

	for (size_t i = 0; i < fileEntry->Size; i++)
	{
		if (isprint(buffer[i])) {putc(buffer[i], stdout);}
		else printf("<%02x>", buffer[i]);
	}
	printf("\n");

	free(buffer);
	free(g_Fat);
	free(g_RootDirectory);
	return 0;
}

bool readBootSector(FILE* disk){
	return fread(&bootsec, sizeof(bootsec), 1, disk) > 0;
}

bool readSectors(FILE* disk, uint32_t lba, uint32_t count, void* bufferOut){
	bool ok = true;
	ok = ok && (fseek(disk, lba * bootsec.BytesPerSector, SEEK_SET) == 0);
	ok = ok && (fread(bufferOut, bootsec.BytesPerSector, count, disk) == count);
	return ok;
}

bool readFat(FILE* disk){
	g_Fat = (uint8_t*) malloc(bootsec.SectorsPerFat * bootsec.BytesPerSector);
	return readSectors(disk, bootsec.ReservedSectors, bootsec.SectorsPerFat, g_Fat);
}

bool readRootDirectory(FILE* disk){
	uint32_t lba = bootsec.ReservedSectors + bootsec.SectorsPerFat * bootsec.FatCount;
	uint32_t size = sizeof(struct DirectoryEntry) * bootsec.DirEntryCount;
	uint32_t sectors = (size / bootsec.BytesPerSector);
	if (size % bootsec.BytesPerSector > 0){sectors++;}

	g_RootDirectoryEnd = lba + sectors;
	g_RootDirectory = (struct DirectoryEntry*) malloc(sectors * bootsec.BytesPerSector);
	return readSectors(disk, lba, sectors, g_RootDirectory);
}

struct DirectoryEntry* findFile(const char* name){
	for (uint32_t i = 0; i < bootsec.DirEntryCount; i++)
	{
		if (memcmp(name, g_RootDirectory[i].Name, 11) == 0)
			return &g_RootDirectory[i];
	}

	return NULL;
}

bool readFile(struct DirectoryEntry* fileEntry, FILE* disk, uint8_t* outputBuffer){
	bool ok = true;
	uint16_t currentCluster = fileEntry->FirstClusterLow;

	do {
		uint32_t lba = g_RootDirectoryEnd + (currentCluster - 2) * bootsec.SectorsPerCluster;
		ok = ok && readSectors(disk, lba, bootsec.SectorsPerCluster, outputBuffer);
		outputBuffer += bootsec.SectorsPerCluster * bootsec.BytesPerSector;

		uint32_t fatIndex = currentCluster * 3 / 2;
		if (currentCluster % 2 == 0)
			currentCluster = (*(uint16_t*)(g_Fat + fatIndex)) & 0x0FFF;
		else
			currentCluster = (*(uint16_t*)(g_Fat + fatIndex)) >> 4;

	} while (ok && currentCluster < 0x0FF8);

	return ok;
}
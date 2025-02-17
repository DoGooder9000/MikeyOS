#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#define Byte uint8_t
#define Word uint16_t
#define Double uint32_t

// FAT HEADERS

struct BootSector_Struct{
	Byte OEM_IDEN[8];		// "MSWIN4.1"
	Word BYTES_PER_SEC;		// 512
	Byte SEC_PER_CLUST;		// 1
	Word NUM_RES_SECT;		// 1
	Byte FAT_ALLOC_TB;		// 2
	Word ROOT_DIR_ENT;		// 0xE0
	Word NUM_SECTORS;		// 2880
	Byte MED_DES_TYPE;		// 0xF0
	Word SEC_PER_FAT;		// 9
	Word SEC_PER_TRCK;		// 18
	Word NUM_HEADS;			// 2
	Double HIDDEN_SEC;		// 0
	Double LARGE_SEC;			// 0

	// EXTENDED BOOT RECORD

	Byte DRIVE_NUM;			// 0
	Byte WINDOWS_FLAG;		// 0
	Byte DRIVE_SIG;			// 0x29
	Byte VOLUME_ID[4];		// "ABCD"
	Byte VOLUME_LABEL[11];	// "MIKEYOS    "
	Byte SYS_IDEN_STR[8];	// "FAT12   "
} const BootSector_defualt = {"MSWIN4.1", 512, 1, 1, 2, 0xE0, 2880, 0xF0, 9, 18, 2, 0, 0, 0, 0, 0x29, "ABCD", "MIKEYOS    ", "FAT12   "};

// ROOT DIRECTORY ENTRIES

struct DirectoryEntry_Struct{
	Byte Name[11];
	Byte Attributes;
	Byte _Reserved;
	Byte CreatedTimeTenths;
	Word CreatedTime;
	Word CreatedDate;
	Word AccessedDate;
	Word FirstClusterHigh;
	Word ModifiedTime;
	Word ModifiedDate;
	Word FirstClusterLow;
	Double Size;
};

typedef struct BootSector_Struct BootSector;
typedef struct DirectoryEntry_Struct DirectoryEntry;

// FUNCTIONS

bool ReadSectors(FILE* disk, int LBA, int numSectors, void* buffer);
bool ReadFileAllocationTable(FILE* disk);
bool ReadRootDirectory(FILE* disk);
DirectoryEntry LookupFile(const char* name);

const BootSector bootsec = BootSector_defualt;

const int FATSectorCount = bootsec.FAT_ALLOC_TB * bootsec.SEC_PER_FAT;
const int FATSize = FATSectorCount * bootsec.BYTES_PER_SEC;

const int EntrySize = sizeof(DirectoryEntry); // Should just be 32

const int RootDirectoryStart = bootsec.NUM_RES_SECT + FATSectorCount;
const int RootDirectoryByteLength = (bootsec.ROOT_DIR_ENT * EntrySize);
const int RootDirectorySectorLength = (RootDirectoryByteLength + bootsec.BYTES_PER_SEC - 1) / bootsec.BYTES_PER_SEC; // Rounds up to the nearest whole sector
const int RootDirectoryPaddedByteLength = RootDirectorySectorLength * bootsec.BYTES_PER_SEC;

Byte* FileAllocationTable = NULL;
DirectoryEntry* RootDirectory = NULL;

int main(int argc, char* argv[]){
	if (argc < 3){
		printf("Argmument format: <Disk Image> <File name (in FAT form)>\n");
		return -1;
	}

	printf("Disk Image: %s\n", argv[1]);
	printf("File Name: \"%s\"\n", argv[2]);

	FILE* disk = fopen(argv[1], "rb");

	if (!disk){
		printf("Failed to open the Disk Image\n");
		return -2;
	}

	if (!ReadFileAllocationTable(disk)){
		printf("Failed to read the FAT\n");
		free(FileAllocationTable);
		return -3;
	}

	if (!ReadRootDirectory(disk)){
		printf("Failed to read the Root Directory\n");
		free(FileAllocationTable);
		free(RootDirectory);
		return -4;
	}

	DirectoryEntry entry = LookupFile(argv[2]);
	
	printf("Name: %s\n", entry.Name);

	free(FileAllocationTable);
	free(RootDirectory);
	
	return 0;
}

bool ReadSectors(FILE* disk, int LBA, int numSectors, void* buffer){
	// First, we need to set the LBA ( where in the disk the sectors are going to be read from )
	// Then, we can read the sectors into the buffer, checking along the way.

	bool good = true;

	good = good && (fseek(disk, LBA * bootsec.BYTES_PER_SEC, SEEK_SET) == 0);
	good = good && (fread(buffer, bootsec.BYTES_PER_SEC, numSectors, disk) == numSectors);	// Read the sectors into the buffer

	return good;
}

bool ReadFileAllocationTable(FILE* disk){
	FileAllocationTable = malloc(FATSize);

	int FATStart = bootsec.NUM_RES_SECT;
	return ReadSectors(disk, FATStart, FATSectorCount, FileAllocationTable);
}

bool ReadRootDirectory(FILE* disk){
	// (DirectoryEntry*) is not needed in C. It is used for code clarity and compatibility with C++.
	RootDirectory = (DirectoryEntry*) malloc(RootDirectoryPaddedByteLength);

	return ReadSectors(disk, RootDirectoryStart, RootDirectorySectorLength, RootDirectory);
}

DirectoryEntry LookupFile(const char* name){
	for (int i = 0; i < bootsec.ROOT_DIR_ENT; i++){
		if (memcmp(name, RootDirectory[i].Name, 11) == 0){
			return RootDirectory[i];
		}
	}
}
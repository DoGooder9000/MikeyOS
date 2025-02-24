#include "headers/string.h"

int strlen(const char* str){
	int len = 0;
	while (str[len]){ len++; }

	return len;
}

char single_to_char(int num){
	return num + '0';
}

char* IntToStr(int num){
	char* str;

	int i = 0;

	// Process each digit (in reverse order)
	do {
		str[i++] = (num % 10) + '0';  // Convert digit to character
		num /= 10;
	} while (num > 0);

	str[i] = '\0';  // Null-terminate the string

	// Reverse the string
	int start = 0, end = i - 1;
	while (start < end) {
		char temp = str[start];
		str[start] = str[end];
		str[end] = temp;
		start++;
		end--;
	}

	return str;
}
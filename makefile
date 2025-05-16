CC = gcc
CFLAGS = -Wall -Wextra -pthread
TARGET = lab04

all: $(TARGET)

$(TARGET): lab04.c
	$(CC) $(CFLAGS) -o $(TARGET) lab04.c

clean:
	rm -f $(TARGET)

.PHONY: all clean
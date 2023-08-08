all:
	fasm test86.asm test86.bin
	sjasm main.asm main.bin
	vmzx -x -b main.bin 8000 -p 8000 -d
clean:
	rm -f *.lst *.bin
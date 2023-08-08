all:
	z80asm main.asm -o main.rom
	dd conv=notrunc if=../lib/font.bin of=main.rom seek=15616 bs=1 2>/dev/null
	php ../../utils/bin2mif.php main.rom 32 > ../../de0/rom32.mif
	vmzx -x -h -r1 main.rom

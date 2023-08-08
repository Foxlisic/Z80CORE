all:
	z80asm main.asm -o main.rom
	php ../../utils/bin2mif.php main.rom 32 > ../../de0/rom32.mif
	vmzx -r1 main.rom
	rm main.rom

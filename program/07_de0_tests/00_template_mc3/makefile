all:
	sjasm main.asm main.rom
	dd if=../lib/font.bin of=main.rom seek=15616 bs=1
	php ../../utils/bin2mif.php main.rom 16 > ../../mc3/rom32.mif
    
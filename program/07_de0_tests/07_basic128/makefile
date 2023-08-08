# https://github.com/anotherlin/z80emu/blob/master/testfiles/zexall.z80
R48  =../../basic48.rom
R128 =../../basic128.rom
TRD  =../../trdos.rom
MIF  =../../utils/bin2mif.php

all:

	dd if=$(R128) of=rom.bin
	dd if=$(R48) of=rom.bin seek=16384 bs=1 conv=notrunc

	# Тестовый ROM для 48К режима
	php $(MIF) rom.bin 32 > ../../de0/rom32.mif
	php $(MIF) $(TRD) 16 > ../../de0/romtr.mif

	vmzx -2 -x -h -r0 $(R128) -r1 $(R48)

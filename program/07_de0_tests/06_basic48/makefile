# https://github.com/anotherlin/z80emu/blob/master/testfiles/zexall.z80

ROM=../../basic48.rom
MIF=../../utils/bin2mif.php
TAP=../../utils/maketap.php

all:

	# Тестовый ROM для 48К режима
	dd if=$(ROM) of=rom.bin
	php $(MIF) rom.bin 32 > ../../de0/rom32.mif

	# Zexall
	dd if=zexall of=ram128.bin bs=1 seek=32768
	php $(TAP) zexall zexall.tap 32768
	php $(MIF) zexall.tap 16 > ../../de0/tapdata.mif

	vmzx -x -h -r1 rom.bin

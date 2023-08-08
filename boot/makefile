#PLATFORM=linux
PLATFORM=win32

# /dev/sdX
FLASHDEV=/dev/sde

all: $(PLATFORM)

linux: assemble example update
	./update
	qemu-system-i386 -soundhw sb16 -vga std -drive format=raw,file=c.img
	#bochs -f c.bxrc -q
win32: assemble update.exe
	update.exe
	bochsdbg -f c.win.bxrc -q
assemble:
	fasm boot.asm dist/boot.bin
	fasm speccy.asm dist/speccy.bin
update:
	g++ update.c -o update
	strip update
update.exe:
	g++ update.c -o update.exe
	strip update.exe
example:
	z80asm example.asm -o rom/other.rom
flash:
	dd if=dist/boot.bin of=$(FLASHDEV) bs=446 count=1 conv=notrunc
	dd if=dist/program.img of=$(FLASHDEV) bs=512 seek=1 conv=notrunc
clean:
	rm -f boot.bin bochsout.txt bx_enh_dbg.ini $(UPDATEFILE)

VLIB=/usr/share/verilator/include

all: tbc
	./zxspectrum

icarus:
	iverilog -g2005-sv -DICARUS=1 -o tb.qqq tb.v z80.v mmap.v clockdiv.v sd.v
	vvp tb.qqq > NUL

tbc: verilate
	g++ -o zxspectrum -I$(VLIB) $(VLIB)/verilated.cpp zx.cc \
		obj_dir/Vz80__ALL.a \
		obj_dir/Vula__ALL.a \
		obj_dir/Vmmap__ALL.a \
		obj_dir/Vps2__ALL.a \
		obj_dir/Vkbd__ALL.a \
		-lSDL2
	strip zxspectrum
verilate:
	verilator -cc z80.v
	verilator -cc ula.v
	verilator -cc mmap.v
	verilator -cc ps2.v
	verilator -cc kbd.v
	cd obj_dir && make -f Vz80.mk
	cd obj_dir && make -f Vula.mk
	cd obj_dir && make -f Vmmap.mk
	cd obj_dir && make -f Vps2.mk
	cd obj_dir && make -f Vkbd.mk
vcd:
	gtkwave tb.vcd
wave:
	gtkwave tb.gtkw
clean:
	rm -rf db incremental_db simulation timing greybox_tmp *.jdi *.pof *.sld
	rm -rf *.rpt *.summary *.sof *.done *.pin *.qws *.bak *.smsg *.qws *.vcd
	rm -rf *.qqq *.jic *.map .qsys_edit undo_redo.txt PLLJ_PLLSPE_INFO.txt c5_pin_model_dump.txt


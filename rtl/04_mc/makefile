LIB=/usr/share/verilator/include

all: icarus verl app
icarus:
	iverilog -g2005-sv -DICARUS=1 -o tb.qqq tb.v z80.v
	vvp tb.qqq >> /dev/null
	rm tb.qqq
verl:
	verilator -cc ga.v
	verilator -cc z80.v
	cd obj_dir && make -f Vga.mk
	cd obj_dir && make -f Vz80.mk
app:
	g++ -o tb -I$(LIB) $(LIB)/verilated.cpp tb.cc obj_dir/Vga__ALL.a obj_dir/Vz80__ALL.a -lSDL2
	strip tb
	./tb
clean:
	rm -rf tb tb.vcd obj_dir

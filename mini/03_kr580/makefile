VLIB=/usr/share/verilator/include
all: icarus program

icarus:
	iverilog -g2005-sv -DICARUS=1 tb.v kr580.v -o tb.qqq
	vvp tb.qqq >> /dev/null
	rm tb.qqq
vcd:
	gtkwave tb.vcd
wave:
	gtkwave tb.gtkw
program: comp
	g++ -o tb -I$(VLIB) $(VLIB)/verilated.cpp tb.cc obj_dir/Vtext__ALL.a obj_dir/Vkr580__ALL.a obj_dir/Vps2__ALL.a -lSDL2
	strip tb
	./tb
comp:
	verilator -cc text.v
	verilator -cc kr580.v
	verilator -cc ps2.v
	cd obj_dir && make -f Vtext.mk
	cd obj_dir && make -f Vkr580.mk
	cd obj_dir && make -f Vps2.mk
clean:
	rm -f *.vcd *.qqq

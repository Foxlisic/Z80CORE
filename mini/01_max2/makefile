all:
	iverilog -g2005-sv -DICARUS=1 -o tb.qqq tb.v core.v
	vvp tb.qqq >> /dev/null
	rm tb.qqq
vcd:
	gtkwave tb.vcd
wave:
	gtkwave tb.gtkw
clean:
	rm -rf *.vcd *.qqq


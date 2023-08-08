`timescale 10ns / 1ns
module tb;

// -----------------------------------------------------------------------------
reg clock;      always #0.5 clock    = ~clock;
reg clock_25;   always #1.0 clock_25 = ~clock_25;
// -----------------------------------------------------------------------------
initial begin clock = 0; clock_25 = 0; #2000 $finish; end
initial begin $dumpfile("tb.vcd"); $dumpvars(0, tb); end
// -----------------------------------------------------------------------------
reg  [ 7:0] ram[65536];
wire [15:0] address;
wire [ 7:0] din = ram[address];
wire [ 7:0] dout;
wire        we;

always @(posedge clock) if (we) ram[address] <= dout;
// -----------------------------------------------------------------------------

endmodule

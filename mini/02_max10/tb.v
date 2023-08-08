`timescale 10ns / 1ns

module tb;
// ---------------------------------------------------------------------
reg locked;
reg clock;     always #0.5 clock    = ~clock;
reg clock_25;  always #1.0 clock_50 = ~clock_50;
reg clock_50;  always #2.0 clock_25 = ~clock_25;
// ---------------------------------------------------------------------
initial begin locked = 0; clock = 0; clock_25 = 0; clock_50 = 0; #5 locked = 1; #2000 $finish; end
initial begin $dumpfile("tb.vcd"); $dumpvars(0, tb); end
initial begin $readmemh("tb.hex", mem); end
// ---------------------------------------------------------------------
reg [ 7:0] mem[65536];
always @(posedge clock) if (we) mem[address] <= out;
// ---------------------------------------------------------------------

wire [15:0] address;
wire [ 7:0] in = mem[address];
wire [ 7:0] out;
wire        we;

core ZXSpectrum
(
    .clock      (clock_25),
    .reset_n    (locked),
    .address    (address),
    .in         (in),
    .out        (out),
    .we         (we)
);

endmodule

`timescale 10ns / 1ns
module tb;

// ---------------------------------------------------------------------
reg clock;
reg clock_25;
reg clock_50;

always #0.5 clock    = ~clock;
always #1.0 clock_50 = ~clock_50;
always #2.0 clock_25 = ~clock_25;
// ---------------------------------------------------------------------
initial begin clock = 0; clock_25 = 0; clock_50 = 0; #2000 $finish; end
initial begin $dumpfile("tb.vcd"); $dumpvars(0, tb); end
initial begin $readmemh("tb.hex", memory); end
// ---------------------------------------------------------------------
reg  [ 7:0] memory[65536];
wire [ 7:0] in = memory[address];
wire [ 7:0] out;
wire [15:0] address;
wire        we;

always @(posedge clock) if (we) memory[address] <= out;
// ---------------------------------------------------------------------

core core_inst
(
    .clock          (clock_25),
    .locked         (1'b1),
    .reset_n        (1'b1),
    .address        (address),
    .in             (in),
    .out            (out),
    .we             (we)
);

endmodule

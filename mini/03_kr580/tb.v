`timescale 10ns / 1ns

module tb;
// -----------------------------------------------------------------------------
reg         clk;
reg         clock_cpu;
reg         pin_intr;
always #0.5 clk         = ~clk;
always #2.0 clock_cpu   = ~clock_cpu;
// -----------------------------------------------------------------------------
initial begin pin_intr = 0; clk = 0; clock_cpu = 0; #20 pin_intr = 1; #30 pin_intr = 0; #2000 $finish; end
initial begin $dumpfile("tb.vcd"); $dumpvars(0, tb); end
initial $readmemh("tb.hex", memory);
// -----------------------------------------------------------------------------

reg  [ 7:0] memory[65536];
wire [15:0] address;
wire [ 7:0] in = memory[address];
wire [ 7:0] out;
wire        we;

always @(posedge clk) if (we) memory[ address ] <= out;
// -----------------------------------------------------------------------------

wire [7:0] pin_pa;
wire [7:0] pin_pi = 0;
wire [7:0] pin_po;
wire       pin_pw;

kr580 cpu
(
    .pin_clk    (clock_cpu),
    .pin_rstn   (1'b1),
    .pin_i      (in),
    .pin_a      (address),
    .pin_enw    (we),
    .pin_o      (out),

    // Порты
    .pin_pa     (pin_pa),
    .pin_pi     (pin_pi),
    .pin_po     (pin_po),
    .pin_pw     (pin_pw),

    // Interrupt
    .pin_intr   (pin_intr)
);

endmodule

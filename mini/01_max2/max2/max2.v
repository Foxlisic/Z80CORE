module max2
(
    input  wire         clock,
    input  wire [3:0]   key,
    output reg  [7:0]   led,
    inout  wire [9:0]   f0,
    inout  wire [9:0]   f1,
    inout  wire [9:0]   f2,
    inout  wire [9:0]   f3,
    inout  wire [9:0]   f4,
    inout  wire [9:0]   f5,
    inout  wire         dp,
    inout  wire         dn,
    inout  wire         pt
);

assign f0 = 10'hz; assign f1 = 10'hz; assign f2 = 10'hz;
assign f3 = 10'hz; assign f4 = 10'hz; assign f5 = 10'hz;

wire [15:0] address;
wire [15:0] datain;
wire        ready;
wire [ 7:0] out;
wire        we;

// Выдача информации на-гора
always @(posedge osc) if (we) led <= out;

coremax2 core_inst
(
    .clock          (osc),
    .locked         (ready),
    .reset_n        (key[0]),
    .address        (address),
    .in             (address[0] ? datain[15:8] : datain[7:0]),
    .out            (out),
    .we             (we)
);

altufm_reader altufm_reader_inst
(
    .osc        (osc),
    .address    (address[8:1]),
    .datain     (datain),
    .ready      (ready)
);

endmodule

`include "../coremax2.v"

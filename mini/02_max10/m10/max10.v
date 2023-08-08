module max10
(
    output wire [13:0] IO,
    output wire [ 3:0] LED,
    input  wire [ 1:0] KEY,
    input  wire        SERIAL_RX,
    output wire        SERIAL_TX,
    input  wire        CLK100MHZ
);

// Генерация частот
wire locked;
wire clock_25;

reg [3:0] cnt;
assign LED = ~cnt; // {2'b11, KEY};
always @(posedge clock_25) if (uart_rdy) cnt <= cnt + 1;

// -----------------------------------------------------------------------------

wire [7:0]  uart_out;
wire        uart_rdy;
reg  [7:0]  uart_in;
reg         uart_we;
wire        uart_tx_rdy;

uart_rx U0
(
    .clock    (clock_25),
    .reset_n  (locked),
    .delay    (12'd2604),
    .parity   (1'b0),
    // ---
    .rx       (SERIAL_RX),
    .out      (uart_out),
    .ready    (uart_rdy)
);

// Передатчик данных
uart_tx U1
(
    .clock    (clock_25),
    .reset_n  (locked),
    .delay    (12'd2604),
    .parity   (1'b0),
    // ---
    .in       (uart_in),
    .we       (uart_we),
    .tx       (SERIAL_TX),
    .ready    (uart_tx_rdy)
);

// -----------------------------------------------------------------------------

pll unit_pll
(
    .clk       (CLK100MHZ),
    .m25       (clock_25),
    .locked    (locked)
);

endmodule

`include "../uart_rx.v"
`include "../uart_tx.v"

// delay=2604, parity=0
module uart_tx
(
  input        clock,
  input        reset_n,
  input [11:0] delay,
  input        parity,
  input [7:0]  in,
  input        we,
  output reg   tx,
  output       ready
);
assign ready = (st == 1'b0);
reg [ 1:0] st       = 1'b0;
reg [11:0] timer    = 1'b0;
reg [10:0] data     = 1'b0;
reg [ 3:0] cnt      = 1'b0;
always @(posedge clock)
if (reset_n == 1'b0) begin tx <= 1'b1; st <= 2'b0; end
else case (st)
0: begin
  cnt <= 10 + parity;
  if (we) st <= 1;
  if (we) data <= {1'b1, ~parity | ~^in, in, 1'b0};
end
1: begin
  st    <= cnt == 0 ? 0 : 2;
  tx    <= data[0];
  data  <= data[10:1];
  cnt   <= cnt - 1;
  timer <= delay;
end
2: begin if (timer == 2) begin st <= 1; end timer <= timer - 1'b1; end
endcase
endmodule
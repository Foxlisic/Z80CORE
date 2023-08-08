// delay=2604, parity=0
module uart_rx
(
  input            clock,
  input            reset_n,
  input [11:0]     delay,
  input            parity,
  input            rx,
  output reg [7:0] out,
  output reg       ready
);
reg  [ 1:0] st;
reg  [ 1:0] rxr;
reg  [12:0] timer;
reg  [ 3:0] cnt;
reg  [ 8:0] recv;
wire [ 8:0] recv_next = {rx, recv[8:1]};

always @(posedge clock)
if (reset_n == 1'b0) begin st <= 0; ready <= 0; end
else begin
  ready <= 1'b0;
  rxr   <= {rxr[0], rx};
  case (st)
    // (IDLE) Ожидание RX=0, старт-бит
    0: if (rxr == 2'b10) begin
       st      <= 2;
       cnt     <= 8 + parity;
       timer   <= delay + (delay>>1);
    end
    // Прием бита MSB
    1: begin
       st    <= 2;
       recv  <= recv_next;
       cnt   <= cnt - 1;
       timer <= delay;
       out   <= parity ? recv_next[7:0] : recv_next[8:1];
       ready <= (cnt == 1) && (parity ? rx == ~^recv_next[7:0] : 1'b1);
    end
    // Ожидание, отсчет времени
    2: begin if (timer == 1) begin st <= (cnt == 0) ? 0 : 1; end timer <= timer - 1; end
    endcase
end
endmodule
/* verilator lint_off WIDTH */
/* verilator lint_off CASEINCOMPLETE */

// Доступ к памяти
// F000h - F400h Страница 1
// F400h - F800h Страница 2
// F800h - FFFFh Знакогенератор

module ga
(
    // Физический интерфейс
    input               clock,
    output  reg [3:0]   r,
    output  reg [3:0]   g,
    output  reg [3:0]   b,
    output              hs,
    output              vs,
    input       [ 7:0]  xs,         // Скролл по X
    input       [ 7:0]  ys,         // Скролл по Y
    output  reg [11:0]  address,
    input       [ 7:0]  data        // Данные
);

// ---------------------------------------------------------------------
// Тайминги для горизонтальной|вертикальной развертки (640x400)
// ---------------------------------------------------------------------
parameter
    hz_visible = 640, vt_visible = 400,
    hz_front   = 16,  vt_front   = 12,
    hz_sync    = 96,  vt_sync    = 2,
    hz_back    = 48,  vt_back    = 35,
    hz_whole   = 800, vt_whole   = 449;
// ---------------------------------------------------------------------
assign hs = x  < (hz_back + hz_visible + hz_front); // NEG.
assign vs = y >= (vt_back + vt_visible + vt_front); // POS.
// ---------------------------------------------------------------------
wire   xmax  = (x == hz_whole - 1);
wire   ymax  = (y == vt_whole - 1);
wire   shown =  x >= hz_back && x < hz_visible + hz_back &&
                y >= vt_back && y < vt_visible + vt_back;
wire   paper = (x >= hz_back + 64) && (x < hz_back + 64 + 512) &&
               (y >= vt_back +  8) && (y < vt_back +  8 + 384);
// ---------------------------------------------------------------------
// Регистры
// ---------------------------------------------------------------------
reg  [ 9:0] x    = 1'b0;
reg  [ 8:0] y    = 1'b0;
reg  [ 7:0] mask;
// ---------------------------------------------------------------------
wire [ 9:0] X    = (x - hz_back - 48) + (xs << 1);
wire [ 9:0] Y    = (y - vt_back -  8) + (ys << 1);
wire        K    = X[9] ^ Y[9];
// ---------------------------------------------------------------------

// Вывод видеосигнала
always @(posedge clock) begin

    {r, g, b} <= 12'h000;

    // Кадровая развертка
    x <= xmax ?         0 : x + 1;
    y <= xmax ? (ymax ? 0 : y + 1) : y;

    // Вывод окна видеоадаптера
    if (shown) {r, g, b} <= paper & mask[ ~X[3:1] ] ? 12'hCCC : 12'h111;

    // Считывание символа
    case (X[3:0])

    4'h0: begin address <= {2'b0,  K, Y[8:4], X[8:4]}; end
    4'h1: begin address <= {2'b11, data[7:0], Y[3:1]}; end
    4'hF: begin mask    <= data; end

    endcase

end

endmodule

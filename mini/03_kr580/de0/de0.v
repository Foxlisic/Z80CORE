module de0(

      // Reset
      input              RESET_N,

      // Clocks
      input              CLOCK_50,
      input              CLOCK2_50,
      input              CLOCK3_50,
      inout              CLOCK4_50,

      // DRAM
      output             DRAM_CKE,
      output             DRAM_CLK,
      output      [1:0]  DRAM_BA,
      output      [12:0] DRAM_ADDR,
      inout       [15:0] DRAM_DQ,
      output             DRAM_CAS_N,
      output             DRAM_RAS_N,
      output             DRAM_WE_N,
      output             DRAM_CS_N,
      output             DRAM_LDQM,
      output             DRAM_UDQM,

      // GPIO
      inout       [35:0] GPIO_0,
      inout       [35:0] GPIO_1,

      // 7-Segment LED
      output      [6:0]  HEX0,
      output      [6:0]  HEX1,
      output      [6:0]  HEX2,
      output      [6:0]  HEX3,
      output      [6:0]  HEX4,
      output      [6:0]  HEX5,

      // Keys
      input       [3:0]  KEY,

      // LED
      output      [9:0]  LEDR,

      // PS/2
      inout              PS2_CLK,
      inout              PS2_DAT,
      inout              PS2_CLK2,
      inout              PS2_DAT2,

      // SD-Card
      output             SD_CLK,
      inout              SD_CMD,
      inout       [3:0]  SD_DATA,

      // Switch
      input       [9:0]  SW,

      // VGA
      output      [3:0]  VGA_R,
      output      [3:0]  VGA_G,
      output      [3:0]  VGA_B,
      output             VGA_HS,
      output             VGA_VS
);

// MISO: Input Port
assign SD_DATA[0] = 1'bZ;

// SDRAM Enable
assign DRAM_CKE  = 1;   // ChipEnable
assign DRAM_CS_N = 0;   // ChipSelect

// Zstate
assign DRAM_DQ = 16'hzzzz;
assign GPIO_0  = 36'hzzzzzzzz;
assign GPIO_1  = 36'hzzzzzzzz;

// LED OFF
assign HEX0 = 7'b1111111;
assign HEX1 = 7'b1111111;
assign HEX2 = 7'b1111111;
assign HEX3 = 7'b1111111;
assign HEX4 = 7'b1111111;
assign HEX5 = 7'b1111111;

// -----------------------------------------------------------------------------
// PLL
// -----------------------------------------------------------------------------

wire clk;
wire clk25;
wire locked;

pll u0
(
    .clkin      (CLOCK_50),
    .m25        (clk25),
    .m100       (clk),
    .locked     (locked)
);

// -----------------------------------------------------------------------------
// Память программ 64K
// -----------------------------------------------------------------------------

ram M1
(
    .clock      (clk),

    // Процессор
    .address_a  (pin_a),
    .q_a        (pin_i),
    .data_a     (pin_o),
    .wren_a     (pin_enw),

    // Видео
    .address_b  ({3'b111, video_addr}),
    .q_b        (video_data),
);

// -----------------------------------------------------------------------------
// Центральный процессор
// -----------------------------------------------------------------------------

wire        pin_enw;
wire [15:0] pin_a;
wire [ 7:0] pin_i;
wire [ 7:0] pin_o;
wire [ 7:0] pin_pa;
wire [ 7:0] pin_pi;
wire [ 7:0] pin_po;
wire        pin_pw;

kr580 C1
(
    // Шина данных
    .pin_clk    (clk25),
    .pin_rstn   (locked & RESET_N),
    .pin_i      (pin_i),
    .pin_a      (pin_a),
    .pin_enw    (pin_enw),
    .pin_o      (pin_o),

    // Порты
    .pin_pa     (pin_pa),
    .pin_pi     (pin_pi),
    .pin_po     (pin_po),
    .pin_pw     (pin_pw),

    // Interrupt
    .pin_intr   (VGA_VS)
);

// -----------------------------------------------------------------------------
// Контроллер портов ввода-вывода
// -----------------------------------------------------------------------------

// Положение курсора
reg [7:0] cursor_x = 0;
reg [7:0] cursor_y = 0;

// Очередь клавиш
reg [7:0] key0;
reg [7:0] key1;
reg [7:0] key2;
reg [7:0] key3;
reg [1:0] keyhit;

always @(posedge clk25) begin

    spi_sent <= 1'b0;

    // Очередь из 4 клавиш
    if (ps2_hit) begin

        key3    <= key2;
        key2    <= key1;
        key1    <= key0;
        key0    <= ps2_data;
        keyhit  <= keyhit + 1'b1;

    end

    if (pin_pw)
    case (pin_pa[7:0])

    // Положение курсора
    4: cursor_x <= pin_po;
    5: cursor_y <= pin_po;

    // Байт на отправку к SPI
    6: spi_out <= pin_po;

    // Отослать команду на SPI
    7: begin spi_sent <= 1'b1; spi_cmd <= pin_po[1:0]; end

    endcase

end

// Вывод в процессор
assign pin_pi =

    pin_pa[7:0] == 0 ? key0 :
    pin_pa[7:0] == 1 ? key1 :
    pin_pa[7:0] == 2 ? key2 :
    pin_pa[7:0] == 3 ? key3 :
    pin_pa[7:0] == 4 ? cursor_x :
    pin_pa[7:0] == 5 ? cursor_y :
    // SPI Interface
    pin_pa[7:0] == 6 ? spi_din :
    //                  BUSY       TIMEOUT             KEYID
    pin_pa[7:0] == 7 ? {spi_st[0], spi_st[1], 4'b0000, keyhit[1:0]} :
    8'hFF;

// -----------------------------------------------------------------------------
// Видеоадаптер
// -----------------------------------------------------------------------------

wire [12:0] video_addr;
wire [ 7:0] video_data;
wire [11:0] cursor = cursor_x + cursor_y*80;

text V1
(
    .clock      (clk25),
    .r          (VGA_R),
    .g          (VGA_G),
    .b          (VGA_B),
    .hs         (VGA_HS),
    .vs         (VGA_VS),
    .address    (video_addr),
    .data       (video_data),
    .cursor     (cursor),
);

// -----------------------------------------------------------------------------
// КЛАВИАТУРА
// -----------------------------------------------------------------------------

wire        ps2_hit;
wire [7:0]  ps2_data;

ps2 ps2_inst
(
    .clock      (clk25),
    .ps_clock   (PS2_CLK),
    .ps_data    (PS2_DAT),
    .done       (ps2_hit),
    .data       (ps2_data)
);

// -----------------------------------------------------------------------------
// КОНТРОЛЛЕР SPI
// -----------------------------------------------------------------------------

reg         spi_sent;
reg  [1:0]  spi_cmd;
reg  [7:0]  spi_out;
wire [1:0]  spi_st;
wire [7:0]  spi_din;

sdcard SD1
(
    // 25 Mhz
    .clock      (clk25),
    .reset_n    (locked),

    // Физический интерфейс
    .spi_cs     (SD_DATA[3]),  // Выбор чипа
    .spi_sclk   (SD_CLK),      // Тактовая частота
    .spi_miso   (SD_DATA[0]),  // Входящие данные
    .spi_mosi   (SD_CMD),      // Исходящие

    // Интерфейс
    .spi_sent   (spi_sent),    // IN    Сообщение отослано на SPI
    .spi_cmd    (spi_cmd),     // IN    Команда
    .spi_din    (spi_din),     // OUT   Принятое сообщение из SPI
    .spi_out    (spi_out),     // IN    Байт на отправку в SPI
    .spi_st     (spi_st)       // OUT   bit 0: timeout (1); bit 1: busy
);
// -----------------------------------------------------------------------------


endmodule

`include "../kr580.v"
`include "../text.v"
`include "../ps2.v"
`include "../sdcard.v"

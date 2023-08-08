`timescale 10ns / 1ns
module tb;

reg clock;
reg clock_25;
reg clock_50;
reg irq;

always #0.5 clock    = ~clock;
always #1.0 clock_50 = ~clock_50;
always #1.5 clock_25 = ~clock_25;

initial begin clock = 1; clock_25 = 0; clock_50 = 0; irq = 0; #100 irq=1; #200 irq=0; #2000 $finish; end
initial begin $dumpfile("tb.vcd"); $dumpvars(0, tb); end
initial begin $readmemh("tb.hex", rom); end

// Контроллер памяти
// -----------------------------------------------------------------------------

reg  [7:0]  rom[ 32*1024];
reg  [7:0]  ram[128*1024];

wire [7:0]  i_data;
wire [7:0]  o_data;
wire [15:0] address;
wire        we;
wire        m0;
wire        hold;
wire [ 7:0] portin;
wire        portwe;
wire        ram_we;

reg  [ 7:0] ram_idata;
wire [16:0] ram_address;

wire [1:0]  sd_cmd;
wire [7:0]  sd_din;
wire [7:0]  sd_out;
wire        sd_signal;
wire        sd_busy;
wire        sd_timeout;

// Физический интерфейс
wire        SD_CLK;
wire        SD_CMD;
wire [3:0]  SD_DATA;

always @(posedge clock) begin

    ram_idata <= ram[ram_address];
    if (ram_we) ram[ram_address] <= o_data;

end

// Управление троттлингом
// -----------------------------------------------------------------------------

// Делитель частоты
clockdiv ClockDivUnit
(
    .reset_n    (1'b1),
    .active     (1'b0),     // Троттлинг отключен
    .clock      (clock_25),
    .freq       (8'd43),    // 4.3 Mhz
    .fref       (8'd250),
    .hold       (hold)
);

// Центральный процессор
// -----------------------------------------------------------------------------

z80 Z80Tb
(
    // Основной интерфейс
    .clock      (clock_25),
    .reset_n    (1'b1),
    .compat     (1'b0),
    .hold       (hold),
    .irq        (irq),
    .address    (address),
    .i_data     (i_data),
    .o_data     (o_data),
    .we         (we),
    .m0         (m0),
    .portin     (portin),
    .portwe     (portwe)
);

// Контроллер памяти
// -----------------------------------------------------------------------------

mmap MemMapTb
(
    // Сброс
    .reset_n        (1'b1),
    .hold           (1'b1),

    // Подключение к процессору
    .clock          (clock_25),
    .m0             (m0),
    .address        (address),
    .i_data         (i_data),
    .o_data         (o_data),
    .we             (we),
    .portin         (portin),
    .portwe         (portwe),

    // ROM: 0=BASIC128, 1=BASIC48
    .rom_idata      (rom[ address[13:0] ]),

    // Запись или чтение из 128k памяти
    .ram_address    (ram_address),
    .ram_idata      (ram_idata),
    .ram_we         (ram_we),
    
    // SD-интерфейс
    .sd_signal      (sd_signal),   // In   =1 Сообщение отослано на spi
    .sd_cmd         (sd_cmd),      // In      Команда
    .sd_din         (sd_din),      // Out     Принятое сообщение от карты
    .sd_out         (sd_out),      // In      Сообщение на отправку к карте
    .sd_busy        (sd_busy),     // Out  =1 Занято
    .sd_timeout     (sd_timeout)   // Out  =1 Таймаут    
);

// Контроллер SD
// -----------------------------------------------------------------------------

sd UnitSD
(
    // 50 Mhz
    .clock50    (clock_50),

    // Физический интерфейс
    .SPI_CS     (SD_DATA[3]),   // Выбор чипа
    .SPI_SCLK   (SD_CLK),       // Тактовая частота
    .SPI_MISO   (SD_DATA[0]),   // Входящие данные
    .SPI_MOSI   (SD_CMD),       // Исходящие

    // Интерфейс
    .sd_signal  (sd_signal),   // In   =1 Сообщение отослано на spi
    .sd_cmd     (sd_cmd),      // In      Команда
    .sd_din     (sd_din),      // Out     Принятое сообщение от карты
    .sd_out     (sd_out),      // In      Сообщение на отправку к карте
    .sd_busy    (sd_busy),     // Out  =1 Занято
    .sd_timeout (sd_timeout)   // Out  =1 Таймаут
);

endmodule

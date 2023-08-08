/* verilator lint_off WIDTH */

module mmap
(
    input   wire        reset_n,    // =0 Сигнал сброса
    input   wire        clock,      // Частота процессора
    input   wire        m0,
    input   wire        hold,
    input   wire [15:0] address,
    output  reg  [ 7:0] i_data,     // Входящие данные в процессор
    input   wire [ 7:0] o_data,     // Исходящие из процессора данных
    input   wire        we,
    output  reg  [ 7:0] portin,
    input   wire        portwe,

    // Управление памятью
    output reg   [14:0] rom_address, // 32k
    input  wire  [ 7:0] rom_idata,
    input  wire  [ 7:0] rom_trdos,
    output reg   [16:0] ram_address, // 128k
    input  wire  [ 7:0] ram_idata,
    output reg          ram_we,
    output reg          tap_we,

    // Видеопамять
    output wire         vidpage,
    output reg   [ 2:0] border,

    // Клавиатура, микрофон
    input  wire  [ 7:0] kbd,
    input  wire         mic,
    input  wire  [ 7:0] inreg,
    input  wire         klatch,
    output wire  [16:0] tap_address,        // К памяти TAP/ExtVideo
    input  wire  [16:0] tap_address_blk,    // TAP-модуль

    // Регистры AY
    output reg  [3:0]   ay_reg,
    output reg  [7:0]   ay_data_o,
    input  wire [7:0]   ay_data_i,
    output reg          ay_req,


    // Интерфейс
    output reg          sd_signal,  // 0->1 Команда на позитивном фронте
    output reg  [ 1:0]  sd_cmd,     // ID команды
    input  wire [ 7:0]  sd_din,     // Данные от SD
    output reg  [ 7:0]  sd_out,     // Запись на SD
    input  wire         sd_busy,    // =1 Устройство занято
    input  wire         sd_timeout  // =1 Истек таймаут
);

initial begin

    sd_signal = 0;
    sd_cmd    = 0;
    sd_out    = 0;

end

wire [15:0] A = address;

// http://speccy.info/Порт_7FFD
reg  [7:0]  port7ffd = 0;
reg         trdos    = 0;

// Выбранный банк памяти
wire [2:0]  bank     = port7ffd[5] ? 3'd0 : port7ffd[2:0];

// Видеоадаптер (5-й или 7-й банк). Если D5, заблокирован на 5-й экран
assign      vidpage  = port7ffd[5] ? 1'b0 : port7ffd[3];

// Если D5, то зафиксировать 48k ROM
wire        rompage  = port7ffd[5] ? 1'b1 : port7ffd[4];

// Доступ к памяти видеоадаптера при включенном 7-м бите порта port7ffd
assign      tap_address = port7ffd[7] ? ram_address : tap_address_blk;

// Роутеры
always @(*) begin

    i_data      = ram_idata;
    portin      = 8'hFF;
    ram_we      = 1'b0;
    tap_we      = 1'b0;
    ram_address = A[15:0];
    rom_address = {rompage, A[13:0]};

    // 16-битная адресная шина
    case (A[15:14])

        // Выбрана область ROM (или TRDOS)
        2'b00: begin i_data = trdos ? rom_trdos : rom_idata; end

        // Всегда отображается банк 5/2
        2'b01,
        2'b10: begin ram_we = we; ram_address = {A[14], 2'b01, A[13:0]}; end

        // Выбор банка памяти
        2'b11: begin

            tap_we = we &  port7ffd[7]; // Активен когда 1
            ram_we = we & ~port7ffd[7]; // Активен когда 0

            ram_address = {bank, A[13:0]};

        end

    endcase

    // AY-чип
    if      (A == 16'hFFFD)   portin = ay_reg;
    else if (A == 16'hBFFD)   portin = ay_data_i;
    // Порты Лисиона
    else if (A == 16'h00EF)   portin = inreg;
    else if (A == 16'h01EF)   portin = klatch;
    else if (A[7:0] == 8'h0F) portin = sd_din;
    else if (A[7:0] == 8'h1F) portin = {sd_timeout, 6'b000000, sd_busy};
    // ZX Spectrum +2/+3
    else if (A == 16'h1FFD)   portin = 8'hFF;
    // Порт 7FFD
    else if (A[7:0] == 8'hFD) portin = port7ffd;
    // Клавиатура и микрофон (базовый запрос)
    else if (A[0]   == 1'b0)  portin = {1'b1, /*D6*/ mic, 1'b1, /*D4..D0*/ kbd[4:0]};
    // Kempston-джойстик
    else if (A[7:5] == 3'b0)  portin = 0;

end

// Запись в порты
always @(posedge clock) begin

    sd_signal <= 1'b0;

    if (reset_n == 0) begin

        port7ffd  <= 0; // Выбор 128K
        ay_req    <= 0;

    end
    else if (portwe && hold) begin

        // AY адрес регистра
        if      (A == 16'hFFFD) begin ay_reg <= o_data[3:0]; end
        // AY данные
        else if (A == 16'hBFFD) begin ay_data_o <= o_data; ay_req <= ~ay_req; end
        // Порты Лисиона
        // -- Команда для чтения или записи на SD (1=R/W cmd)
        else if (A[7:0] == 8'h0F) begin sd_out <= o_data; sd_signal <= 1'b1; sd_cmd <= 1; end
        // -- Отсылка команды
        else if (A[7:0] == 8'h1F) begin sd_cmd <= o_data; sd_signal <= 1'b1; end
        // http://speccy.info/Порт_1FFD
        else if (A == 16'h1FFD) begin /* пустота */ end
        // Запись страницы 7FFDh (упрощенная дешифрация)
        else if (A[7:0] == 8'hFD) begin

            // Управлять памятью можно пока D5=0
            if (port7ffd[5] == 1'b0)
                port7ffd <= o_data;

        end
        // Запись бордера
        else if (A[0] == 1'b0) begin border[2:0] <= o_data[2:0]; end

    end

end

// Переключение в TRDOS
always @(negedge clock) begin

    if (reset_n == 1'b0) begin
        trdos <= 0;
    end
    // TRDOS активируется только в 48k режиме
    else if (hold && m0 && port7ffd[5:4]) begin

        // Вход в область TRDOS
        if (A[15:8] == 8'h3D) trdos <= 1'b1;
        // Выход из TRDOS при выходе из ROM
        else if (A[15:14])    trdos <= 1'b0;

    end

end

endmodule

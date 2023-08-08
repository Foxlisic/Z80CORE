/*  Модуль SPI

Top Level Schema:

    .spi_miso   (SD_DATA[0]),       // Входящие данные
    .spi_mosi   (SD_CMD),           // Исходящие
    .spi_sclk   (SD_CLK),           // Тактовая частота
    .spi_cs     (SD_DATA[3]),       // Выбор чипа

COMMAND
------------------
00  INIT
01  TRANSMIT
02  CS=0
03  CS=1
------------------
*/

module sdcard
(
    // 25 Mhz
    input               clock,
    input               reset_n,

    // SPI
    output reg          spi_cs,
    output reg          spi_sclk,
    input               spi_miso,
    output reg          spi_mosi,

    // Интерфейс
    input               spi_sent,    // =1 Сообщение отослано на spi
    input       [ 1:0]  spi_cmd,     // Команда
    output reg  [ 7:0]  spi_din,     // Принятое сообщение
    input       [ 7:0]  spi_out,     // Сообщение на отправку
    output      [ 1:0]  spi_st       // bit 1: timeout (1); bit 0: busy
);

localparam SPI_TIMEOUT_CNT = 5000000;

initial begin

    spi_cs   = 1'b1;
    spi_sclk = 1'b0;
    spi_mosi = 1'b0;
    spi_din  = 8'h00;

end

// ---------------------------------------------------------------------
// SPI SdCard
// ---------------------------------------------------------------------

// Сигнал о том, занято ли устройство
assign      spi_st      = {spi_timeout == SPI_TIMEOUT_CNT, spi_busy};
reg         spi_busy    = 1'b0;

reg  [2:0]  spi_process = 0;
reg  [3:0]  spi_cycle   = 0;
reg  [7:0]  spi_data_w  = 0;

// INIT SPI MODE
reg  [7:0]  spi_counter   = 1'b0;
reg  [7:0]  spi_slow_tick = 1'b0;
reg  [24:0] spi_timeout   = SPI_TIMEOUT_CNT;

always @(posedge clock)
if (reset_n == 1'b0) begin

    spi_cs      <= 1'b1;
    spi_sclk    <= 1'b0;
    spi_mosi    <= 1'b0;
    spi_din     <= 8'h00;
    spi_process <= 1'b0;
    spi_busy    <= 1'b0;
    spi_timeout <= SPI_TIMEOUT_CNT;

end
else begin

    // Счетчик таймаута
    if (spi_timeout < SPI_TIMEOUT_CNT && spi_process == 1'b0)
        spi_timeout <= spi_timeout + 1'b1;

    case (spi_process)

        // Инициировать процессинг
        0: if (spi_sent) begin

            spi_process <= 1'b1 + spi_cmd;
            spi_busy    <= 1'b1;
            spi_counter <= 1'b0;
            spi_cycle   <= 1'b0;
            spi_timeout <= 1'b0;
            spi_data_w  <= spi_out;

        end

        // Command-1: 80 тактов в slow-режиме
        1: begin

            spi_cs   <= 1'b1;
            spi_mosi <= 1'b1;

            // 125*200`000
            if (spi_slow_tick == (125 - 1)) begin

                spi_slow_tick <= 1'b0;
                spi_sclk      <= ~spi_sclk;
                spi_counter   <= spi_counter + 1;

                // 80 ticks
                if (spi_counter == (2*80 - 1)) begin

                    spi_process <= 1'b0;
                    spi_sclk    <= 1'b0;
                    spi_busy    <= 1'b0;

                end

            end
            // Оттикивание таймера
            else begin spi_slow_tick <= spi_slow_tick + 1'b1; end

        end

        // Command 1: Read/Write SPI
        2: case (spi_cycle)

            // CLK-DN
            0: begin spi_cycle <= 1; spi_sclk <= 1'b0; spi_mosi <= 1'b0;end
            1: begin spi_cycle <= 2; spi_mosi <= spi_data_w[7]; spi_data_w <= {spi_data_w[6:0], 1'b0}; end
            // CLK-UP
            2: begin spi_cycle <= 3; spi_sclk <= 1'b1; spi_counter <= spi_counter + 1'b1; end
            3: begin

                spi_cycle <= 1'b0;
                spi_din   <= {spi_din[6:0], spi_miso};

                if (spi_counter == 8) begin

                    spi_sclk    <= 1'b0;
                    spi_busy    <= 1'b0;
                    spi_counter <= 1'b0;
                    spi_process <= 1'b0;
                    spi_mosi    <= 1'b0;

                end
            end

        endcase

        // Переключиться за 2 такта, чтобы среагировал CPU
        3: case (spi_cycle)

            0: spi_cycle <= 1;
            1: begin spi_cs <= 1'b0; spi_process <= 0; spi_busy <= 0; end

        endcase

        4: case (spi_cycle)

            0: spi_cycle <= 1;
            1: begin spi_cs <= 1'b1; spi_process <= 0; spi_busy <= 0; end

        endcase

    endcase

end

endmodule

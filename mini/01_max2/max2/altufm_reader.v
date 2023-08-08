module altufm_reader
(
    output              osc,            // Осциллятор
    input        [ 8:0] address,        // Заданный адрес
    output  reg  [15:0] datain,         // Полученные данные
    output              ready           // Признак готовности данных
);

assign      ready = (cnt == 27);
reg [4:0]   cnt     = 1'b0;
reg         ardin   = 1'b0;
reg         drshft  = 1'b0;
wire        drdout;

altufm AltUFMUnit
(
    .arclk  (osc),
    .drclk  (osc),
    .drdin  (1'b0),     // Данные для программирования Flash
    .drdout (drdout),   // Выходные данные
    .drshft (drshft),   // 0: Защелка, 1: Задвижка
    .ardin  (ardin),    // Данные для адреса
    .arshft (1'b1),     // Всегда последовательный адрес
    .oscena (1'b1),     // Активировать осциллятор
    .osc    (osc)       // Осциллятор 5.56 Мгц
);

always @(posedge osc)
begin

    cnt    <= cnt + 1;
    drshft <= cnt > 9;
    ardin  <= cnt < 9 ? address[8 - cnt] : 1'b0;
    datain <= {datain[14:0], drdout};

    // Данные готовы
    if (ready) cnt <= 0;

end

endmodule
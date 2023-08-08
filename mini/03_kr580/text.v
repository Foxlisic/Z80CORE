/* verilator lint_off WIDTH */

module text
(
    // Опорная частота 25 мгц
    input   wire        clock,

    // Выходные данные
    output  reg  [3:0]  r,       // 4 бит на красный
    output  reg  [3:0]  g,       // 4 бит на зеленый
    output  reg  [3:0]  b,       // 4 бит на синий
    output  wire        hs,      // горизонтальная развертка
    output  wire        vs,      // вертикальная развертка

    // Доступ к памяти
    output  reg  [12:0] address, // 4k Видеоданные; 4K Шрифты
    input   wire [ 7:0] data,    // data = videoram[ address ]

    // Внешний интерфейс
    input   wire [10:0] cursor   // Положение курсора от 0 до 2047
);

// ---------------------------------------------------------------------
// Тайминги для горизонтальной|вертикальной развертки (640x400)
// ---------------------------------------------------------------------

localparam

    hz_visible = 640, vt_visible = 400,
    hz_front   = 16,  vt_front   = 12,
    hz_sync    = 96,  vt_sync    = 2,
    hz_back    = 48,  vt_back    = 35,
    hz_whole   = 800, vt_whole   = 449;

assign hs = x  < (hz_back + hz_visible + hz_front); // NEG.
assign vs = y >= (vt_back + vt_visible + vt_front); // POS.
// ---------------------------------------------------------------------
wire        xmax = (x == hz_whole - 1);
wire        ymax = (y == vt_whole - 1);
reg  [10:0] x    = 0;
reg  [10:0] y    = 0;
wire [10:0] X    = x - hz_back + 8; // X=[0..639]
wire [ 9:0] Y    = y - vt_back;     // Y=[0..399]
// ---------------------------------------------------------------------

// ---------------------------------------------------------------------
// Текстовый видеоадаптер
// ---------------------------------------------------------------------
reg  [ 7:0] char;  reg [7:0] tchar; // Битовая маска
reg  [ 7:0] attr;  reg [7:0] tattr; // Атрибут
reg  [23:0] timer;                  // Мерцание курсора
reg         flash;
// ---------------------------------------------------------------------

// Текущая позиция курсора
wire [10:0] id = X[9:3] + (Y[8:4] * 80);

// Если появляется курсор [1..4000], то он использует нижние 2 строки у линии
wire maskbit = (char[ ~X[2:0] ]) | (flash && (id == cursor + 1) && Y[3:0] >= 14);

// Текущий цвет
wire [3:0] kcolor = maskbit ? (attr[7] & flash ? attr[6:4] : attr[3:0]) : attr[6:4];

// Разбираем цветовую компоненту (нижние 4 бита отвечают за цвет символа)
wire [15:0] color =

    kcolor == 4'h0 ? 12'h111 : // 0 Черный (почти)
    kcolor == 4'h1 ? 12'h008 : // 1 Синий (темный)
    kcolor == 4'h2 ? 12'h080 : // 2 Зеленый (темный)
    kcolor == 4'h3 ? 12'h088 : // 3 Бирюзовый (темный)
    kcolor == 4'h4 ? 12'h800 : // 4 Красный (темный)
    kcolor == 4'h5 ? 12'h808 : // 5 Фиолетовый (темный)
    kcolor == 4'h6 ? 12'h880 : // 6 Коричневый
    kcolor == 4'h7 ? 12'hCCC : // 7 Серый -- тут что-то не то
    kcolor == 4'h8 ? 12'h888 : // 8 Темно-серый
    kcolor == 4'h9 ? 12'h66F : // 9 Синий (темный)
    kcolor == 4'hA ? 12'h0F0 : // 10 Зеленый
    kcolor == 4'hB ? 12'h0FF : // 11 Бирюзовый
    kcolor == 4'hC ? 12'hF00 : // 12 Красный
    kcolor == 4'hD ? 12'hF0F : // 13 Фиолетовый
    kcolor == 4'hE ? 12'hFF0 : // 14 Желтый
                     12'hFFF;  // 15 Белый

// Вывод видеосигнала
always @(posedge clock) begin

    // Кадровая развертка
    x <= xmax ?         0 : x + 1;
    y <= xmax ? (ymax ? 0 : y + 1) : y;

    // Вывод окна видеоадаптера
    if (x >= hz_back && x < hz_visible + hz_back &&
        y >= vt_back && y < vt_visible + vt_back)
    begin
         {r, g, b} <= color;
    end
    else {r, g, b} <= 12'h000;

    // Извлечение битовой маски и атрибутов для генерации шрифта
    case (X[2:0])

        // Запрос на ASCII-символ
        0: begin address <= {1'b0, id[10:0], 1'b0}; end

        // Сохранить ASCII -> tchar, запрос на атрибут
        1: begin tchar <= data; address[0] <= 1'b1; end

        // Сохранить атрибут, запрос на знакогенератор
        2: begin tattr <= data; address <= {1'b1, tchar[7:0], Y[3:0]}; end

        // Сохранить значение битовой маски
        3: begin tchar <= data; end

        // Обновить данные для рисования символа
        7: begin attr  <= tattr; char <= tchar; end

    endcase

    // Каждые 0,5 секунды перебрасывается регистр flash
    if (timer == 12500000) begin
        timer <= 0;
        flash <= ~flash;
    end else
        timer <= timer + 1;
end

endmodule

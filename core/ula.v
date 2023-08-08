/* verilator lint_off WIDTH */
/* verilator lint_off CASEINCOMPLETE */

module ula
(
    // 25 мегагерц
    input   wire        clock,

    // Выходные данные
    output  reg  [3:0]  VGA_R,
    output  reg  [3:0]  VGA_G,
    output  reg  [3:0]  VGA_B,
    output  wire        HS,
    output  wire        VS,

    // Данные для вывода
    input   wire [ 7:0] port7ffd,
    output  reg  [12:0] vaddr,
    input   wire [ 7:0] vdata,
    input   wire [ 2:0] border,

    // Разрешение 320x200x8
    output  reg  [16:0] addrhi,
    input   wire [ 7:0] datahi,

    // Генерация сигнала для IRQ
    input   wire        sync50,         // Включить 50 Гц экран
    output  reg         irq
);

// Тайминги для горизонтальной развертки (640)
parameter horiz_visible = 640;
parameter horiz_back    = 48;
parameter horiz_sync    = 96;
parameter horiz_front   = 16;
parameter horiz_whole   = 800;

// Тайминги для вертикальной развертки (400)
//                              // 400  480
parameter vert_visible = 400;   // 400  480
parameter vert_back    = 35;    // 35   33
parameter vert_sync    = 2;     // 2    2
parameter vert_front   = 12;    // 12   10
parameter vert_whole   = 449;   // 449  525

// visible (видимая область) + front (передний порожек) + sync (синхронизация) + back (задний порожек)
assign HS = x >= (horiz_visible + horiz_front) && x < (horiz_visible + horiz_front + horiz_sync);
assign VS = y >= (vert_visible  + vert_front)  && y < (vert_visible  + vert_front  + vert_sync);

// В этих регистрах мы будем хранить текущее положение луча на экране
reg [9:0] x = 1'b0;
reg [9:0] y = 1'b0;

// Чтобы правильно начинались данные, нужно их выровнять
wire [7:0] X  = x[9:1] - 24;
wire [7:0] Y  = y[9:1] - 4;

// ---------------------------------------------------------------------

reg [7:0] current_char;
reg [7:0] current_attr;
reg [7:0] tmp_current_char;

// Получаем текущий бит
wire current_bit = current_char[ 7^X[2:0] ];

// Если бит атрибута 7 = 1, то бит flash будет менять current_bit каждые 0.5 секунд
wire flashed_bit = (current_attr[7] & flash) ^ current_bit;

// Текущий цвет точки
wire [ 2:0] src_color = flashed_bit ? current_attr[2:0] : current_attr[5:3];
wire [11:0] color = {

    // Если current_attr[6] = 1, то переходим в повышенную яркость (в 2 раза)
    /* Красный цвет - это бит 1 */ src_color[1] ? (current_attr[6] ? 4'hF : 4'hC) : 4'h01,
    /* Зеленый цвет - это бит 2 */ src_color[2] ? (current_attr[6] ? 4'hF : 4'hC) : 4'h01,
    /* Синий цвет   - это бит 0 */ src_color[0] ? (current_attr[6] ? 4'hF : 4'hC) : 4'h01

};

wire [11:0] bgcolor =
{
    border[1] ? 4'hC : 4'h1,
    border[2] ? 4'hC : 4'h1,
    border[0] ? 4'hC : 4'h1
};

reg         flash;
reg [23:0]  timer;
reg [18:0]  t50hz;
reg [ 7:0]  data8;

wire [15:0] v320addr = x[9:1] + y[9:1]*320;

initial     irq = 1'b0;

always @(posedge clock) begin

    if (timer == 24'd12500000) begin /* полсекунды */
        timer <= 1'b0;
        flash <= flash ^ 1'b1; // мигать каждые 0.5 секунд
    end else begin
        timer <= timer + 1'b1;
    end

    // Счетчик
    t50hz <= t50hz == 499999 ? 0 : t50hz + 1;

    // Генератор 50/60 Гц сигнала
    // Если включен sync50, то синхроимпульс идет после 4.8/5 пройденного экрана
    irq <= sync50 ? (t50hz > 480000) : VS;

end

// Генератор на 25 Мгц
always @(posedge clock) begin

    x <= x == (horiz_whole - 1) ? 1'b0 : (x + 1'b1);
    if (x == (horiz_whole - 1)) y <= y == (vert_whole - 1) ? 1'b0 : (y + 1'b1);

    // Обязательно надо тут использовать попиксельный выход, а то пиксели наполовину съезжают
    case (x[3:0])

        // Видеоадрес в ZX Spectrum непросто вычислить
        //         FEDC BA98 7654 3210
        // Адрес =    Y Yzzz yyyx xxxx

                               // БанкY  СмещениеY ПолубанкY СмещениеX
        4'b0000: vaddr <= { Y[7:6], Y[2:0], Y[5:3], X[7:3] };

        // Запись временного значения, чтобы на 16-м такте его обновить
        4'b0001: tmp_current_char <= vdata;

        // Запрос атрибута по x=0..31, y=0..23
        // [110] [yyyyy] [xxxxx]
        4'b0010: vaddr <= { 3'b110, Y[7:3], X[7:3] };

        // Подготовка к выводу символа
        4'b1111: begin

            // Записать в текущий регистр выбранную "маску" битов
            current_char <= tmp_current_char;

            // И атрибутов
            // Атрибут в спектруме представляет собой битовую маску
            //  7     6      5 4 3    2 1 0
            // [Flash Bright BgColor  FrColor]

            // Flash   - мерцание
            // Bright  - яркость
            // BgColor - цвет фона
            // FrColor - цвет пикселей

            current_attr <= vdata;

        end

    endcase

    // Видеоразрешение 320x200x8 [банк 0, 1]
    case (x[0])

        0: addrhi <= {port7ffd[3], v320addr};
        1: data8  <= datahi;

    endcase

    // Мы находимся в видимой области рисования
    if (x < horiz_visible && y < vert_visible) begin

        // Экран 320x200x8
        if (port7ffd[6]) begin

            {VGA_R, VGA_G, VGA_B} <= {
                /*R*/ data8[7:5],1'b0,
                /*G*/ data8[4:2],1'b0,
                /*B*/ data8[1:0],2'b00
            };

        end
        // Спектрум-экран
        else begin

            if (x >= 64 && x < (64 + 512) && y >= 8 && y < (8 + 384))
                 {VGA_R, VGA_G, VGA_B} <= color;
            else {VGA_R, VGA_G, VGA_B} <= bgcolor;

        end
    end else {VGA_R, VGA_G, VGA_B} <= 12'h000;

end

endmodule

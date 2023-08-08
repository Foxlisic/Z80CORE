// =====================================================================
// Контроллер клавиатуры
// =====================================================================
/* verilator lint_off WIDTH */
/* verilator lint_off CASEINCOMPLETE */

module kbd
(
    input   wire            reset_n,
    input   wire            clock_50,
    input   wire    [ 7:0]  ps2data,
    input   wire            ps2hit,
    input   wire    [15:0]  A,
    output  reg     [ 7:0]  D,          // ZX-spectrum
    output  reg     [ 7:0]  inreg,      // ASCII-символы
    output  reg             klatch      // Признак изменения символа
);

initial begin D = 0; klatch = 0; end

reg         released = 1'b0;
reg  [5:0]  zx_keys[8];

/* Чтение из портов */
always @(*) begin

    D[0] =  (zx_keys[0][0] | A[ 8]) &
            (zx_keys[1][0] | A[ 9]) &
            (zx_keys[2][0] | A[10]) &
            (zx_keys[3][0] | A[11]) &
            (zx_keys[4][0] | A[12]) &
            (zx_keys[5][0] | A[13]) &
            (zx_keys[6][0] | A[14]) &
            (zx_keys[7][0] | A[15]);

    D[1] =  (zx_keys[0][1] | A[ 8]) &
            (zx_keys[1][1] | A[ 9]) &
            (zx_keys[2][1] | A[10]) &
            (zx_keys[3][1] | A[11]) &
            (zx_keys[4][1] | A[12]) &
            (zx_keys[5][1] | A[13]) &
            (zx_keys[6][1] | A[14]) &
            (zx_keys[7][1] | A[15]);

    D[2] =  (zx_keys[0][2] | A[ 8]) &
            (zx_keys[1][2] | A[ 9]) &
            (zx_keys[2][2] | A[10]) &
            (zx_keys[3][2] | A[11]) &
            (zx_keys[4][2] | A[12]) &
            (zx_keys[5][2] | A[13]) &
            (zx_keys[6][2] | A[14]) &
            (zx_keys[7][2] | A[15]);

    D[3] =  (zx_keys[0][3] | A[ 8]) &
            (zx_keys[1][3] | A[ 9]) &
            (zx_keys[2][3] | A[10]) &
            (zx_keys[3][3] | A[11]) &
            (zx_keys[4][3] | A[12]) &
            (zx_keys[5][3] | A[13]) &
            (zx_keys[6][3] | A[14]) &
            (zx_keys[7][3] | A[15]);

    D[4] =  (zx_keys[0][4] | A[ 8]) &
            (zx_keys[1][4] | A[ 9]) &
            (zx_keys[2][4] | A[10]) &
            (zx_keys[3][4] | A[11]) &
            (zx_keys[4][4] | A[12]) &
            (zx_keys[5][4] | A[13]) &
            (zx_keys[6][4] | A[14]) &
            (zx_keys[7][4] | A[15]);

    D[5]    = 1'b1;
    D[6]    = 1'b1;
    D[7]    = 1'b1;

end

reg  ALT = 1'b1;          // Left Alt
wire CS  = zx_keys[0][0]; // Caps Shift [L]
wire SS  = zx_keys[7][1]; // Symbol Shift [R]
reg  shift = 1'b0;

// https://ru.wikipedia.org/wiki/Скан-код
// Данные принимаются только по тактовому сигналу и при наличии ps2_data_clk
always @(posedge clock_50) begin

    if (reset_n == 0)
    begin

        //                           0 1 2 3 4
        zx_keys[0] = 5'b11111; // Symb Z X C V
        zx_keys[1] = 5'b11111; //    A S D F G
        zx_keys[2] = 5'b11111; //    Q W E R T
        zx_keys[3] = 5'b11111; //    1 2 3 4 5
        zx_keys[4] = 5'b11111; //    0 9 8 7 6
        zx_keys[5] = 5'b11111; //    P O I U Y
        zx_keys[6] = 5'b11111; // Ent  L K J H
        zx_keys[7] = 5'b11111; // Spc Cs M N B

    end
    else if (ps2hit) begin

        // Принят сигнал отпускания клавиши
        if (ps2data == 8'hF0) begin
            released <= 1'b1;

        end else begin

            case (ps2data)

                /* РЯД 0 */
                /* CS */ 8'h12: zx_keys[0][0] <= released; // CAPS SHIFT [Левый Shift]
                /*  Z */ 8'h1A: zx_keys[0][1] <= released;
                /*  X */ 8'h22: zx_keys[0][2] <= released;
                /*  C */ 8'h21: zx_keys[0][3] <= released;
                /*  V */ 8'h2A: zx_keys[0][4] <= released;

                /* РЯД 1 */
                /*  A */ 8'h1C: zx_keys[1][0] <= released;
                /*  S */ 8'h1B: zx_keys[1][1] <= released;
                /*  D */ 8'h23: zx_keys[1][2] <= released;
                /*  F */ 8'h2B: zx_keys[1][3] <= released;
                /*  G */ 8'h34: zx_keys[1][4] <= released;

                /* РЯД 2 */
                /*  Q */ 8'h15: zx_keys[2][0] <= released;
                /*  W */ 8'h1D: zx_keys[2][1] <= released;
                /*  E */ 8'h24: zx_keys[2][2] <= released;
                /*  R */ 8'h2D: zx_keys[2][3] <= released;
                /*  T */ 8'h2C: zx_keys[2][4] <= released;

                /* РЯД 3 */
                /*  1 */ 8'h16: zx_keys[3][0] <= released;
                /*  2 */ 8'h1E: zx_keys[3][1] <= released;
                /*  3 */ 8'h26: zx_keys[3][2] <= released;
                /*  4 */ 8'h25: zx_keys[3][3] <= released;
                /*  5 */ 8'h2E: zx_keys[3][4] <= released;

                /* РЯД 4 */
                /*  0 */ 8'h45: zx_keys[4][0] <= released;
                /*  9 */ 8'h46: zx_keys[4][1] <= released;
                /*  8 */ 8'h3E: zx_keys[4][2] <= released;
                /*  7 */ 8'h3D: zx_keys[4][3] <= released;
                /*  6 */ 8'h36: zx_keys[4][4] <= released;

                /* РЯД 5 */
                /*  P */ 8'h4D: zx_keys[5][0] <= released;
                /*  O */ 8'h44: zx_keys[5][1] <= released;
                /*  I */ 8'h43: zx_keys[5][2] <= released;
                /*  U */ 8'h3C: zx_keys[5][3] <= released;
                /*  Y */ 8'h35: zx_keys[5][4] <= released;

                /* РЯД 6 */
                /* EN */ 8'h5A: zx_keys[6][0] <= released; // ENTER
                /*  L */ 8'h4B: zx_keys[6][1] <= released;
                /*  K */ 8'h42: zx_keys[6][2] <= released;
                /*  J */ 8'h3B: zx_keys[6][3] <= released;
                /*  H */ 8'h33: zx_keys[6][4] <= released;

                /* РЯД 7 */
                /* SP */ 8'h29: zx_keys[7][0] <= released; // SPACE
                /* SS */ 8'h59: zx_keys[7][1] <= released; // SYMBOL SHIFT [Правый Shift]
                /*  M */ 8'h3A: zx_keys[7][2] <= released;
                /*  N */ 8'h31: zx_keys[7][3] <= released;
                /*  B */ 8'h32: zx_keys[7][4] <= released;

                /* Кнопки специальных символов */
                // При нажатии CS выдается <b> иначе <a>
                /* ,< */ 8'h41: begin zx_keys[7][1] <= released;
                             if (ALT) zx_keys[7][3] <= released; else zx_keys[2][3] <= released; end
                /* .> */ 8'h49: begin zx_keys[7][1] <= released;
                             if (ALT) zx_keys[7][2] <= released; else zx_keys[2][4] <= released; end
                /* /? */ 8'h4A: begin zx_keys[7][1] <= released;
                             if (ALT) zx_keys[0][4] <= released; else zx_keys[0][3] <= released; end
                /* ;: */ 8'h4C: begin zx_keys[7][1] <= released;
                             if (ALT) zx_keys[5][1] <= released; else zx_keys[0][1] <= released; end
                /* '" */ 8'h52: begin zx_keys[7][1] <= released;
                             if (ALT) zx_keys[4][3] <= released; else zx_keys[5][0] <= released; end
                /* -_ */ 8'h4E: begin zx_keys[7][1] <= released;
                             if (ALT) zx_keys[6][3] <= released; else zx_keys[4][0] <= released; end
                /* =+ */ 8'h55: begin zx_keys[7][1] <= released;
                             if (ALT) zx_keys[6][1] <= released; else zx_keys[6][2] <= released; end

                // Специальные клавиши
                /* CAP  */ 8'h58: begin zx_keys[0][0] <= released; zx_keys[7][1] <= released; end
                /* TAB  */ 8'h0D: begin zx_keys[0][0] <= released; zx_keys[3][0] <= released; end
                /* DEL  */ 8'h66: begin zx_keys[0][0] <= released; zx_keys[4][0] <= released; end
                /* ESC  */ 8'h76: begin zx_keys[0][0] <= released; zx_keys[7][0] <= released; end

                // При нажатии на левый альт активизируется симулятор Caps Shift для спецсимволов
                /* LALT */ 8'h11: begin ALT <= released; end

                // Стрелочки, в том числе на цифровой клавиатуре
                /* 8UP */ 8'h75: begin zx_keys[0][0] <= released; zx_keys[4][3] <= released; end
                /* 4LF */ 8'h6B: begin zx_keys[0][0] <= released; zx_keys[3][4] <= released; end
                /* 2DN */ 8'h72: begin zx_keys[0][0] <= released; zx_keys[4][4] <= released; end
                /* 6RT */ 8'h74: begin zx_keys[0][0] <= released; zx_keys[4][2] <= released; end

            endcase

            released <= 1'b0;

        end
    end

end

// Прием ASCII символов с расширенной клавиатуры
always @(posedge clock_50) begin

    if (ps2hit && ps2data != 8'hF0) begin

        // Левый или правый шифт
        if (ps2data == 8'h12 || ps2data == 8'h59) begin
            shift <= ~released;
        end
        // Учитывать только нажатие клавиш
        else if (released == 1'b0) begin

            case (ps2data)

                // Цифробуквенная клавиатура
                /* A  */ 8'h1C: inreg <= shift ? 8'h41 : 8'h61;
                /* B  */ 8'h32: inreg <= shift ? 8'h42 : 8'h62;
                /* C  */ 8'h21: inreg <= shift ? 8'h43 : 8'h63;
                /* D  */ 8'h23: inreg <= shift ? 8'h44 : 8'h64;
                /* E  */ 8'h24: inreg <= shift ? 8'h45 : 8'h65;
                /* F  */ 8'h2B: inreg <= shift ? 8'h46 : 8'h66;
                /* G  */ 8'h34: inreg <= shift ? 8'h47 : 8'h67;
                /* H  */ 8'h33: inreg <= shift ? 8'h48 : 8'h68;
                /* I  */ 8'h43: inreg <= shift ? 8'h49 : 8'h69;
                /* J  */ 8'h3B: inreg <= shift ? 8'h4A : 8'h6A;
                /* K  */ 8'h42: inreg <= shift ? 8'h4B : 8'h6B;
                /* L  */ 8'h4B: inreg <= shift ? 8'h4C : 8'h6C;
                /* M  */ 8'h3A: inreg <= shift ? 8'h4D : 8'h6D;
                /* N  */ 8'h31: inreg <= shift ? 8'h4E : 8'h6E;
                /* O  */ 8'h44: inreg <= shift ? 8'h4F : 8'h6F;
                /* P  */ 8'h4D: inreg <= shift ? 8'h50 : 8'h70;
                /* Q  */ 8'h15: inreg <= shift ? 8'h51 : 8'h71;
                /* R  */ 8'h2D: inreg <= shift ? 8'h52 : 8'h72;
                /* S  */ 8'h1B: inreg <= shift ? 8'h53 : 8'h73;
                /* T  */ 8'h2C: inreg <= shift ? 8'h54 : 8'h74;
                /* U  */ 8'h3C: inreg <= shift ? 8'h55 : 8'h75;
                /* V  */ 8'h2A: inreg <= shift ? 8'h56 : 8'h76;
                /* W  */ 8'h1D: inreg <= shift ? 8'h57 : 8'h77;
                /* X  */ 8'h22: inreg <= shift ? 8'h58 : 8'h78;
                /* Y  */ 8'h35: inreg <= shift ? 8'h59 : 8'h79;
                /* Z  */ 8'h1A: inreg <= shift ? 8'h5A : 8'h7A;
                /* 0) */ 8'h45: inreg <= shift ? 8'h29 : 8'h30;
                /* 1! */ 8'h16: inreg <= shift ? 8'h21 : 8'h31;
                /* 2@ */ 8'h1E: inreg <= shift ? 8'h40 : 8'h32;
                /* 3# */ 8'h26: inreg <= shift ? 8'h23 : 8'h33;
                /* 4$ */ 8'h25: inreg <= shift ? 8'h24 : 8'h34;
                /* 5% */ 8'h2E: inreg <= shift ? 8'h25 : 8'h35;
                /* 6^ */ 8'h36: inreg <= shift ? 8'h5E : 8'h36;
                /* 7& */ 8'h3D: inreg <= shift ? 8'h26 : 8'h37;
                /* 8* */ 8'h3E: inreg <= shift ? 8'h2A : 8'h38;
                /* 9( */ 8'h46: inreg <= shift ? 8'h28 : 8'h39;

                // Спецсимволы
                /* `~ */ 8'h0E: inreg <= shift ? 8'h7E : 8'h60;
                /* -_ */ 8'h4E: inreg <= shift ? 8'h5F : 8'h2D;
                /* =+ */ 8'h55: inreg <= shift ? 8'h2B : 8'h3D;
                /* ,< */ 8'h41: inreg <= shift ? 8'h3C : 8'h2C;
                /* .> */ 8'h49: inreg <= shift ? 8'h3E : 8'h2E;
                /* \| */ 8'h5D: inreg <= shift ? 8'h7C : 8'h5C;
                /* [{ */ 8'h54: inreg <= shift ? 8'h7B : 8'h5B;
                /* ]} */ 8'h5B: inreg <= shift ? 8'h7D : 8'h5D;
                /* ;: */ 8'h4C: inreg <= shift ? 8'h3A : 8'h3B;
                /* '" */ 8'h52: inreg <= shift ? 8'h22 : 8'h27;
                /* /? */ 8'h4A: inreg <= shift ? 8'h3F : 8'h2F;

                // Разные клавиши
                /* SP */ 8'h29: inreg <= 8'h20;
                /* TB */ 8'h0D: inreg <= 8'h09;
                /* EN */ 8'h5A: inreg <= 8'h0A;
                /* BS */ 8'h66: inreg <= 8'h08;
                /* ES */ 8'h76: inreg <= 8'h1B;

                // Стрелочки, в том числе на цифровой клавиатуре
                /* UP */ 8'h75: inreg <= 8'h01;
                /* RT */ 8'h74: inreg <= 8'h02;
                /* DN */ 8'h72: inreg <= 8'h03;
                /* LF */ 8'h6B: inreg <= 8'h04;

            endcase

            klatch <= klatch ^ 1;

        end

    end

end

endmodule


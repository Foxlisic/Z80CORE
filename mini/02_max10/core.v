module core
(
    input               clock,
    input               reset_n,
    output      [15:0]  address,
    input       [ 7:0]  in,
    output reg  [ 7:0]  out,
    output reg          we
);

assign address =
    bus == BUS_HL ? hl : pc;

initial begin we = 1'b0; out = 1'b0; end

localparam

    WB_R16 = 1,
    WB_R8  = 2;

localparam

    SRC_IN = 1,
    SRC_R8 = 2;

localparam

    BUS_PC = 0,
    BUS_HL = 1;

localparam
    ALU_ADD = 0,
    ALU_ADC = 1,
    ALU_SUB = 2,
    ALU_SBC = 3,
    ALU_AND = 4,
    ALU_XOR = 5,
    ALU_OR  = 6,
    ALU_CP  = 7;

// Все необходимые регистры (96 бит)
// -----------------------------------------------------------------------------

reg [15:0] bc = 16'h23FF;
reg [15:0] de = 16'h0000;
reg [15:0] hl = 16'h0003;
reg [15:0] af = 16'h0000;
reg [15:0] sp = 16'h0000;
reg [15:0] pc = 16'h0000;

// Логика
// -----------------------------------------------------------------------------

reg [ 1:0]  bus = 1'b0;
reg [ 3:0]  cp  = 1'b0;
reg [ 7:0]  opc = 1'b0;     // Сохраненный опкод
reg [ 7:0]  tmp = 1'b0;

// Управляющие провода
// -----------------------------------------------------------------------------

reg         _pcnext = 1'b0;
reg         _cpterm;
reg [3:0]   _cpnext;
reg         _tmpl;
reg [1:0]   _wreg;
reg [2:0]   _regr;
reg [2:0]   _regw;
reg [2:0]   _src;
reg [2:0]   _alu;

// Комбинаторная логика
// -----------------------------------------------------------------------------

always @* begin

    bus     = 0;                // Выбранная шина данных PC
    we      = 0;
    out     = 0;
    _alu    = 0;
    _cpnext = 0;                // Переход к определенному CP (если не 0)
    _cpterm = 0;                // При =1, переход к исполнению следующего
    _pcnext = (cp == 0);        // На первом такте _pcnext=1 всегда
    _tmpl   = 1'b0;             // Запись IN в TMP
    _wreg   = 1'b0;             // Ничего не писать в регистры
    _regr   = 1'b0;             // Номер регистра 8 или 16 бит
    _regw   = 1'b0;             // Номер регистра для записи
    _src    = 1'b0;

    casex (cp ? opc : in)

    // 3T LD r16, nn
    8'b00xx0001: case (cp)

        1: begin _pcnext = 1; _tmpl = 1; end
        2: begin _pcnext = 1; _wreg = WB_R16; _regw = opc[5:4]; _src = 1; _cpterm = 1; end

    endcase

    // 1T INC|DEC r16
    8'b00xxx011: begin

        _pcnext     = 1;
        _regr       = opc[5:4];
        _regw       = opc[5:4];
        _wreg       = 1;
        _src        = {1'b1, in[3]};
        _cpterm     = 1;

    end

    // 3T LD (HL), imm
    8'b00110110: case (cp)

        1: begin _pcnext = 1; _tmpl = 1; end
        2: begin _cpterm = 1; bus = BUS_HL; we = 1; out = tmp; end

    endcase

    // 2T LD r8, imm
    8'b00xxx110: if (cp == 1) begin

        _pcnext = 1;
        _tmpl   = 1;
        _src    = SRC_IN;
        _regw   = opc[5:3];
        _wreg   = WB_R8;
        _cpterm = 1;

    end

    // 1T HALT
    8'b01110110: begin _cpterm = 1; _pcnext = 0; end

    // 2T LD r, (HL)
    8'b01xxx110: if (cp == 1) begin

        _cpterm = 1;
        _src    = SRC_IN;
        _regw   = opc[5:3];
        _wreg   = WB_R8;
        bus     = BUS_HL;

    end

    // 2T LD (HL), r
    8'b01110xxx: if (cp == 1) begin

        _cpterm = 1;
        _src    = SRC_R8;
        _regr   = opc[2:0];
        bus     = BUS_HL;
        we      = 1;
        out     = src8;

    end

    // 1T LD r, r
    8'b01xxxxxx: begin

        _src    = SRC_R8;
        _wreg   = WB_R8;
        _regr   = in[2:0];
        _regw   = in[5:3];
        _cpterm = 1;

    end

    endcase

end

// Выборка данных
// -----------------------------------------------------------------------------

// Регистр 8 бит
wire [ 7:0] r8 =
    _regr == 0 ? bc[15:8] :
    _regr == 1 ? bc[ 7:0] :
    _regr == 2 ? de[15:8] :
    _regr == 3 ? de[ 7:0] :
    _regr == 4 ? hl[15:8] :
    _regr == 5 ? hl[ 7:0] :
    _regr == 6 ? in :
                 af[ 7:0];

// Регистр 16 бит
wire [15:0] r16 =
    _regr == 0 ? bc :
    _regr == 1 ? de :
    _regr == 2 ? hl :
    _regr == 3 ? sp :
                 af;

// Вычисление данных для 8 bit
wire [7:0] src8 =
    _src == SRC_R8 ? r8 :
    _src == SRC_IN ? in :
                     1'b0;

// Вычисление данных для 16 bit
wire [15:0] src16 =
    _src == 1 ? {in, tmp} :     // LD r16, nn
    _src == 2 ? r16 + 1'b1 :    // INC r16
    _src == 3 ? r16 - 1'b1 :    // DEC r16
                1'b0;

// Вычисление АЛУ
// -----------------------------------------------------------------------------

wire [8:0] alur =
    _alu == ALU_ADD ? af[15:8] + src8 :
    _alu == ALU_ADC ? af[15:8] + src8 + af[0] :
    _alu == ALU_SBC ? af[15:8] - src8 - af[0] :
    _alu == ALU_AND ? af[15:8] & src8 :
    _alu == ALU_XOR ? af[15:8] ^ src8 :
    _alu == ALU_OR  ? af[15:8] | src8 :
                      af[15:8] - src8; // SUB, CP

wire sf = alur[7];
wire zf = alur[7:0] == 1'b0;
wire hf = af[12] ^ src8[4] ^ alur[4];
wire pf = ~^alur[7:0];
wire cf = alur[8];

// Исполнительный блок
// -----------------------------------------------------------------------------

always @(posedge clock)
if (reset_n == 1'b0) begin

    pc  <= 16'h0000;
    cp  <= 1'b0;

end
else begin

    if (cp == 1'b0) opc <= in;

    if (_pcnext) pc <= pc + 1'b1;
    if (_tmpl)   tmp <= in;

    // Либо запись в CP=0, либо к следующему
    cp <= _cpterm ? 0 : (_cpnext ? _cpnext : cp + 1);

    // Запись в регистры
    case (_wreg)

        // Запись src16 в регистр
        WB_R16:
        case (_regw)
        0: bc <= src16;
        1: de <= src16;
        2: hl <= src16;
        3: sp <= src16;
        4: af <= src16;
        endcase

        // Запись src8 в регистр
        WB_R8:
        case (_regw)
        0: bc[15:8] <= src8;
        1: bc[ 7:0] <= src8;
        2: de[15:8] <= src8;
        3: de[ 7:0] <= src8;
        4: hl[15:8] <= src8;
        5: hl[ 7:0] <= src8;
        // 6: -- сюда не пишется ничего
        7: af[15:8] <= src8;
        endcase

    endcase

end

endmodule

/* Все инструкции, кроме EX AF, AF'; EXX; Битовые CB; ED; IX; IY */

/* verilator lint_off WIDTH */
/* verilator lint_off CASEX */
/* verilator lint_off CASEOVERLAP */
/* verilator lint_off CASEINCOMPLETE */

module kr580
(
    // Шина данных
    input   wire         pin_clk,
    input   wire         pin_rstn,
    input   wire [ 7:0]  pin_i,
    output  wire [15:0]  pin_a,         // Указатель на адрес
    output  reg          pin_enw,       // Разрешить запись ы(высокий уровень)
    output  reg  [ 7:0]  pin_o,

    // Порты
    output  reg  [ 7:0]  pin_pa,
    input   wire [ 7:0]  pin_pi,
    output  reg  [ 7:0]  pin_po,
    output  reg          pin_pw,

    // Interrupt
    input   wire         pin_intr

);

localparam

    // Базовый набор
    ALU_ADD     = 4'h0,
    ALU_ADC     = 4'h1,
    ALU_SUB     = 4'h2,
    ALU_SBC     = 4'h3,
    ALU_AND     = 4'h4,
    ALU_XOR     = 4'h5,
    ALU_OR      = 4'h6,
    ALU_CP      = 4'h7,

    // Дополнительный набор
    ALU_RLC     = 4'h8,
    ALU_RRC     = 4'h9,
    ALU_RL      = 4'hA,
    ALU_RR      = 4'hB,
    ALU_DAA     = 4'hC,
    ALU_CPL     = 4'hD,
    ALU_SCF     = 4'hE,
    ALU_CCF     = 4'hF;

localparam

    CARRY       = 0,
    PARITY      = 2,
    AUX         = 4,
    ZERO        = 6,
    SIGN        = 7;

localparam

    REG_B = 0, REG_C = 1,
    REG_D = 2, REG_E = 3,
    REG_H = 4, REG_L = 5,
    REG_F = 6, REG_A = 7;

localparam

    REG_BC  = 0,
    REG_DE  = 1,
    REG_HL  = 2,
    REG_SP  = 3;

initial begin

    pin_enw = 0;
    pin_o   = 0;
    pin_pa  = 0;
    pin_po  = 0;

end

// Указатель на необходимые данные
assign pin_a = alt_a ? cursor : pc;

// Управляющие регистры
reg  [ 3:0] t       = 0;        // Это t-state
reg         halt    = 0;        // Процессор остановлен
reg         ei      = 0;        // Enabled Interrupt
reg         ei_ff   = 0;        // Отложенный EI
reg  [15:0] cursor  = 0;
reg         alt_a   = 1'b0;     // =0 pc  =1 cursor

// Регистры общего назначения
reg  [15:0] bc = 16'h0012;
reg  [15:0] de = 16'h0000;
reg  [15:0] hl = 16'hAFC7;
reg  [15:0] pc = 16'h0000;
reg  [15:0] sp = 16'h0000;
reg  [ 7:0] a  = 8'hEF;
reg  [ 7:0] f  = 8'h00;

// Сохраненный опкод
wire [ 7:0] opcode       = t ? opcode_latch : pin_i;
reg  [ 7:0] opcode_latch = 8'h00;
reg         prev_intr    = 1'b0;

// Управление записью в регистры
reg         reg_b = 1'b0;       // Сигнал на запись 8 битного регистра
reg         reg_w = 1'b0;       // Сигнал на запись 16 битного регистра (reg_u:reg_v)
reg  [ 2:0] reg_n = 3'h0;       // Номер регистра
reg  [ 7:0] reg_l = 8'h00;      // Что писать
reg  [ 7:0] reg_u = 8'h00;      // Что писать
reg         ex_de_hl;           // Сигнал на EX DE,HL

// Определение условий
wire reg_hl  = (reg_n == 3'b110);

// Короткий переход
wire cc =
    (opcode[4] == 2'b0) & (f[ZERO]  == opcode[3]) | // NZ, Z
    (opcode[4] == 2'b1) & (f[CARRY] == opcode[3]) | // NC, C
     opcode == 8'h18; // JR

// Условие перехода
wire ccc =
    (opcode[5:4] == 2'b00) & (f[ZERO]   == opcode[3]) | // NZ, Z,
    (opcode[5:4] == 2'b01) & (f[CARRY]  == opcode[3]) | // NC, C,
    (opcode[5:4] == 2'b10) & (f[PARITY] == opcode[3]) | // PO, PE
    (opcode[5:4] == 2'b11) & (f[SIGN]   == opcode[3]) | // P, M
     opcode == 8'b11_001_001 | // RET
     opcode == 8'b11_000_011 | // JP
     opcode == 8'b11_001_101;  // CALL

// Результат сложения HL + R16
wire [15:0] addhl2 = (opcode[5:4] == 2'b00 ? bc : opcode[5:4] == 2'b01 ? de : opcode[5:4] == 2'b10 ? hl : sp);
wire [16:0] addhl1 = hl + addhl2;

always @(posedge pin_clk)
// Мягкий сброс
if (pin_rstn == 1'b0) begin t <= 1'b0; alt_a <= 1'b0; pc <= 1'b0; ei_ff <= 1'b0; ei <= 1'b0; prev_intr <= 1'b0; end
// Исполнение инструкции
else begin

    // Подготовка управляющих сигналов
    alt_a    <= 1'b0;
    reg_b    <= 1'b0;
    reg_w    <= 1'b0;
    pin_enw  <= 1'b0;
    pin_pw   <= 1'b0;
    halt     <= 1'b0;
    ex_de_hl <= 1'b0;

    // Получение внешнего запроса INTR на позитивном фронте
    if (t == 0 && pin_intr != prev_intr && pin_intr && ei) begin

        t            <= 1;
        opcode_latch <= 8'hCF;          // RST #08
        prev_intr    <= 1'b1;
        alt_a        <= 1;
        ei           <= 1'b0;
        ei_ff        <= 1'b0;
        pc           <= pc + halt;
        cursor       <= sp;

    end
    // Исполнение опкодов
    else begin

        // Запись опкода на будущее
        if (t == 0) begin opcode_latch <= pin_i; ei <= ei_ff; prev_intr <= pin_intr; end

        casex (opcode)

            // 1T NOP
            8'b00_000_000: pc <= pc + 1;

            // 1-2T DJNZ *
            8'b00_010_000: case (t)

                0: begin

                    pc    <= pc + 1;
                    reg_l <= bc[15:8] - 1;
                    reg_n <= 0;
                    reg_b <= 1;

                    if (bc[15:8] != 1) t <= 1; else pc <= pc + 2;

                end

                1: begin

                    t   <= 0;
                    pc  <= pc + 1 + {{8{pin_i[7]}}, pin_i};

                end

            endcase

            // 2T   JR *
            // 1-2T JR cc, n
            8'b00_011_000,
            8'b00_1xx_000: case (t)

                0: begin

                    if (cc) begin pc <= pc + 1; t <= 1; end
                    else    begin pc <= pc + 2; end

                end
                1: begin

                    t   <= 0;
                    pc  <= pc + 1 + {{8{pin_i[7]}}, pin_i};

                end

            endcase

            // 3T LD r, i16
            8'b00_xx0_001: case (t)

                0: begin t <= 1; pc <= pc + 1; reg_n <= opcode[5:4]; end
                1: begin t <= 2; pc <= pc + 1; reg_l <= pin_i; end
                2: begin t <= 0; pc <= pc + 1; reg_u <= pin_i; reg_w <= 1'b1; end

            endcase

            // 1T ADD HL, r
            8'b00_xx1_001: begin

                pc      <= pc + 1;
                reg_w   <= 1;
                reg_n   <= 2;

                f[CARRY] <= addhl1[16];
                f[ZERO]  <= addhl2[15:8] == 1'b0;
                f[SIGN]  <= addhl2[15];
                f[AUX]   <= hl[12] ^ addhl1[12]  ^ addhl2[12];

                {reg_u, reg_l} <= addhl1[15:0];

            end

            // 2T LD (r16), A
            8'b00_0x0_010: case (t)

                0: begin

                    t       <= 1;
                    pc      <= pc + 1;
                    alt_a   <= 1;
                    pin_enw <= 1;
                    cursor  <= opcode[4] ? de : bc;
                    pin_o   <= a;

                end
                1: t <= 0;

            endcase

            // 2T LD A, (r16)
            8'b00_0x1_010: case (t)

                0: begin t <= 1; alt_a <= 1; reg_n <= REG_A; pc <= pc + 1; cursor <= opcode[4] ? de : bc; end
                1: begin t <= 0; reg_b <= 1; reg_l <= pin_i; end

            endcase

            // 5T LD (**), HL
            8'b00_100_010: case (t)

                0: begin t <= 1; pc <= pc + 1; end
                1: begin t <= 2; pc <= pc + 1; cursor[7:0]  <= pin_i; end
                2: begin t <= 3; pin_enw <= 1; cursor[15:8] <= pin_i; alt_a <= 1; pin_o <= hl[ 7:0]; end
                3: begin t <= 4; pin_enw <= 1; cursor <= cursor + 1;  alt_a <= 1; pin_o <= hl[15:8]; end
                4: begin t <= 0; pc <= pc + 1; end

            endcase

            // 5T LD HL, (**)
            8'b00_101_010: case (t)

                0: begin t <= 1; pc <= pc + 1; end
                1: begin t <= 2; pc <= pc + 1; cursor[ 7:0] <= pin_i; end
                2: begin t <= 3; pc <= pc + 1; cursor[15:8] <= pin_i; alt_a <= 1; end
                3: begin t <= 4; reg_b <= 1; reg_n <= REG_L; reg_l <= pin_i; alt_a <= 1; cursor <= cursor + 1; end
                4: begin t <= 0; reg_b <= 1; reg_n <= REG_H; reg_l <= pin_i; end

            endcase

            // 4T LD (**), A
            8'b00_110_010: case (t)

                0: begin t <= 1; pc <= pc + 1; end
                1: begin t <= 2; pc <= pc + 1; cursor[ 7:0] <= pin_i; end
                2: begin t <= 3; pin_enw <= 1; cursor[15:8] <= pin_i; alt_a <= 1; pin_o <= a[7:0]; end
                3: begin t <= 0; pc <= pc + 1; end

            endcase

            // 4T LD A, (**)
            8'b00_111_010: case (t)

                0: begin t <= 1; pc <= pc + 1; end
                1: begin t <= 2; pc <= pc + 1; cursor[ 7:0] <= pin_i; end
                2: begin t <= 3; pc <= pc + 1; cursor[15:8] <= pin_i; alt_a <= 1; end
                3: begin t <= 0; reg_b <= 1; reg_n <= REG_A; reg_l <= pin_i; end

            endcase

            // 1T INC, DEC r16
            8'b00_xxx_011: begin

                pc      <= pc + 1;
                reg_w   <= 1;
                reg_n   <= opcode[5:4];

                {reg_u, reg_l} <= opcode[3] ? addhl2 - 1 : addhl2 + 1;

            end

            // 3-4T INC, DEC r8
            8'b00_xxx_10x: case (t)

                0: begin // Установка курсора на (HL), выбор регистра

                    t       <= 1;
                    pc      <= pc + 1;
                    reg_n   <= opcode[5:3];
                    cursor  <= hl;
                    alt_a   <= 1;

                end
                1: begin // Чтение операндов, выбор АЛУ

                    t       <= 2;
                    op1     <= reg_hl ? pin_i : reg_r8;
                    op2     <= 1;
                    alu_m   <= opcode[0] ? ALU_SUB : ALU_ADD;

                end
                2: begin // Запись результатов

                    t       <= reg_hl ? 3 : 0;
                    pin_enw <= reg_hl;
                    reg_b   <= ~reg_hl;
                    reg_l   <= alu_r;
                    pin_o   <= alu_r;
                    f       <= alu_f;
                    alt_a   <= reg_hl;

                end
                3: t <= 0;

            endcase

            // 2T/3T LD r, i8
            8'b00_xxx_110: case (t)

                0: begin // Установка курсора на (HL), выбор регистра для записи

                    t       <= 1;
                    pc      <= pc + 1;
                    reg_n   <= opcode[5:3];
                    cursor  <= hl;

                end
                1: begin // Запись данных в (HL) или в регистр

                    t       <= reg_hl ? 2 : 0;
                    pc      <= pc + 1;
                    reg_b   <= ~reg_hl;
                    pin_enw <= reg_hl;
                    reg_l   <= pin_i;
                    pin_o   <= pin_i;
                    alt_a   <= reg_hl;

                end
                2: t <= 0;

            endcase

            // 2T RLCA, RRCA, RLA, RRA, DAA, CPL, SCF, CCF
            8'b00_xxx_111: case (t)

                0: begin

                    t       <= 1;
                    pc      <= pc + 1;
                    alu_m   <= {1'b1, opcode[5:3]};
                    op1     <= a;

                end
                1: begin

                    t       <= 0;
                    reg_b   <= 1;
                    reg_l   <= alu_r;
                    reg_n   <= REG_A;
                    f       <= alu_f;
                end

            endcase

            // 1T HALT
            8'b01_110_110: halt <= 1;

            // 2T LD r, (HL)
            8'b01_xxx_110: case (t)

                0: begin t <= 1; pc    <= pc + 1; alt_a <= 1; cursor <= hl; end
                1: begin t <= 0; reg_l <= pin_i;  reg_b <= 1; reg_n  <= opcode[5:3];  end

            endcase

            // 3T LD (HL), r
            8'b01_110_xxx: case (t)

                0: begin t <= 1; reg_n <= opcode[2:0]; pc    <= pc + 1; cursor  <= hl; end
                1: begin t <= 2; pin_o <= reg_r8;      alt_a <= 1;      pin_enw <= 1; end
                2: begin t <= 0; end

            endcase

            // 1T LD r, r
            8'b01_xxx_xxx: begin

                pc    <= pc + 1;
                reg_b <= 1;
                reg_n <= opcode[5:3];
                reg_l <= r20;

            end

            // 3T <alu> A, r
            8'b10_xxx_xxx: case (t)

                0: begin t <= 1; op1   <= a; pc <= pc + 1; alt_a <= 1; cursor <= hl; end
                1: begin t <= 2; op2   <= reg_hl ? pin_i : r20; alu_m <= opcode[5:3]; end
                2: begin t <= 0; reg_b <= (alu_m != 3'b111); reg_n <= REG_A; reg_l <= alu_r; f <= alu_f; end

            endcase

            // RET c | RET
            8'b11_001_001,
            8'b11_xxx_000: case (t)

                0: begin t <= ccc; alt_a <= ccc; pc <= pc + 1; cursor <= sp; end
                1: begin t <= 2; pc[ 7:0] <= pin_i; alt_a <= 1; cursor <= cursor + 1; end
                2: begin t <= 0; pc[15:8] <= pin_i; {reg_u, reg_l} <= cursor + 1; reg_n <= REG_SP; reg_w <= 1; end

            endcase

            // POP r16
            8'b11_xx0_001: case (t)

                0: begin t <= 1; cursor <= sp;         alt_a <= 1;  pc    <= pc + 1; end
                1: begin t <= 2; cursor <= cursor + 1; alt_a <= 1;  reg_l <= pin_i; end
                2: begin

                    t       <= 3;
                    cursor  <= cursor + 1;
                    reg_u   <= pin_i;

                     if (opcode[5:4] == 2'b11) // POP AF
                          begin reg_n <= REG_A;       reg_b <= 1; reg_l <= pin_i; f <= reg_l; end
                     else begin reg_n <= opcode[5:4]; reg_w <= 1; end

                end
                3: begin t <= 0; reg_n <= REG_SP; reg_w <= 1; {reg_u, reg_l} <= cursor; end

            endcase

            // JP (HL)
            8'b11_101_001: begin pc <= hl; end

            // LD SP, HL
            8'b11_111_001: begin pc <= pc + 1; reg_n <= REG_SP; reg_w <= 1; {reg_u, reg_l} <= hl; end

            // JP c, ** | JP **
            8'b11_000_011,
            8'b11_xxx_010: case (t)

                0: begin t <= 1; pc <= pc + 1'b1; end
                1: begin t <= 2; pc <= pc + 1'b1; reg_l <= pin_i; end
                2: begin t <= 3; pc <= pc + 1'b1; reg_u <= pin_i; end
                3: begin t <= 0; if (ccc) pc <= {reg_u, reg_l}; end

            endcase

            // OUT (*), A
            8'b11_010_011: case (t)

                0: begin t <= 1; pc <= pc + 1; end
                1: begin t <= 0; pc <= pc + 1; pin_pa <= pin_i; pin_po <= a; pin_pw <= 1; end

            endcase

            // IN  A, (*)
            8'b11_011_011: case (t)

                0: begin t <= 1; pc <= pc + 1; end
                1: begin t <= 2; pc <= pc + 1; pin_pa <= pin_i; end
                2: begin t <= 0; reg_l <= pin_pi; reg_b <= 1; reg_n <= REG_A; end

            endcase

            // EX (SP), HL
            8'b11_100_011: case (t)

                0: begin t <= 1; alt_a <= 1; cursor <= sp; pc <= pc + 1;  end
                1: begin t <= 2; alt_a <= 1; reg_l <= pin_i; pin_o <= hl[7:0]; pin_enw <= 1; end
                2: begin t <= 3; alt_a <= 1; cursor <= cursor + 1; end
                3: begin t <= 4; alt_a <= 1; reg_u <= pin_i; reg_w <= 1; reg_n <= REG_HL; pin_o <= hl[15:8]; pin_enw <= 1; end
                4: begin t <= 0; end

            endcase

            // EX DE, HL
            8'b11_101_011: begin pc <= pc + 1; ex_de_hl <= 1; end

            // DI, EI
            8'b11_11x_011: begin pc <= pc + 1; ei_ff <= opcode[3]; end

            // CALL c, **
            8'b11_001_101,
            8'b11_xxx_100: case (t)

                0: begin t <= 1; pc <= pc + 1; end
                1: begin t <= 2; pc <= pc + 1; reg_l <= pin_i; end
                2: begin

                    t       <= ccc ? 3 : 0;
                    pc      <= pc + 1;
                    reg_u   <= pin_i;
                    cursor  <= sp;

                end
                3: begin t <= 4; pin_o <= pc[15:8]; pin_enw <= 1; alt_a <= 1; cursor <= cursor - 1; end
                4: begin t <= 5; pin_o <= pc[ 7:0]; pin_enw <= 1; alt_a <= 1; cursor <= cursor - 1; end
                5: begin t <= 0; reg_w <= 1; reg_n <= REG_SP; pc <= {reg_u, reg_l}; {reg_u, reg_l} <= cursor; end

            endcase

            // PUSH r16
            8'b11_xx0_101: case (t)

                0: begin t <= 1; pc <= pc + 1; reg_n <= opcode[5:4]; cursor <= sp; end
                1: begin t <= 2; alt_a <= 1; pin_o <= (reg_n == 2'b11) ? a : reg_r16[15:8]; pin_enw <= 1; cursor <= cursor - 1; end
                2: begin t <= 3; alt_a <= 1; pin_o <= (reg_n == 2'b11) ? f : reg_r16[ 7:0]; pin_enw <= 1; cursor <= cursor - 1; end
                3: begin t <= 0; reg_w <= 1; reg_n <= REG_SP; {reg_u, reg_l} <= cursor; end

            endcase

            // <ALU> A, i8
            8'b11_xxx_110: case (t)

                0: begin t <= 1; pc <= pc + 1; alu_m <= opcode[5:3]; op1 <= a; end
                1: begin t <= 2; pc <= pc + 1; op2 <= pin_i; end
                2: begin t <= 0; reg_l <= alu_r; f <= alu_f; reg_n <= REG_A; reg_b <= (alu_m != 3'b111); end

            endcase

            // RST #
            8'b11_xxx_111: case (t)

                0: begin t <= 1; cursor <= sp; alt_a <= 1; end
                1: begin t <= 2; pin_o <= pc[15:8]; pin_enw <= 1; cursor <= cursor - 1; alt_a <= 1; end
                2: begin t <= 3; pin_o <= pc[ 7:0]; pin_enw <= 1; cursor <= cursor - 1; alt_a <= 1; end
                3: begin t <= 0; reg_w <= 1; reg_n <= REG_SP; {reg_u, reg_l} <= cursor; pc <= {opcode[5:3], 3'b000}; end

            endcase

        endcase

    end

end

// -----------------------------------------------------------------------------
// Арифметико-логическое устройство
// -----------------------------------------------------------------------------

reg  [ 3:0] alu_m = 0;
reg  [ 7:0] op1 = 0;
reg  [ 7:0] op2 = 0;

// Вычисление результата АЛУ
wire [8:0] alu_r =
    alu_m == ALU_ADD ? op1 + op2 :
    alu_m == ALU_ADC ? op1 + op2 + f[ CARRY ] :
    alu_m == ALU_SBC ? op1 - op2 - f[ CARRY ] :
    alu_m == ALU_SUB ||
    alu_m == ALU_CP  ? op1 - op2 :
    alu_m == ALU_AND ? op1 & op2 :
    alu_m == ALU_XOR ? op1 ^ op2 :
    alu_m == ALU_OR  ? op1 | op2 :
    alu_m == ALU_RLC ? {op1[6:0], op1[7]} :
    alu_m == ALU_RRC ? {op1[0],   op1[7:1]} :
    alu_m == ALU_RL  ? {op1[6:0], f[CARRY]} :
    alu_m == ALU_RR  ? {f[CARRY], op1[7:1]} :
    alu_m == ALU_DAA ? (a + ((f[AUX] | (a[3:0] >  4'h9)) ? 8'h06 : 0) + ((f[CARRY] | (a[7:0] > 8'h99)) ? 8'h60 : 0)) :
    alu_m == ALU_CPL ? ~a : a;

// Некоторые флаги
wire flag_sign =   alu_r[7];
wire flag_zero = ~|alu_r[7:0];
wire flag_prty = ~^alu_r[7:0];
wire flag_cf   =   alu_r[8];

// Вычисление флагов
wire [7:0] alu_f =
    alu_m == ALU_ADD ? {flag_sign, flag_zero, 1'b0,   op1[3:0] + op2[3:0] > 5'hF, 1'b0, flag_prty, 1'b0, flag_cf} :
    alu_m == ALU_ADC ? {flag_sign, flag_zero, 1'b0,   op1[3:0] + op2[3:0] + f[CARRY] > 5'hF, 1'b0, flag_prty, 1'b0, flag_cf} :
    alu_m == ALU_SUB ||
    alu_m == ALU_CP  ? {flag_sign, flag_zero, 1'b0,   op1[3:0] < op2[3:0], 1'b0, flag_prty, 1'b1, flag_cf} :
    alu_m == ALU_SBC ? {flag_sign, flag_zero, 1'b0,   op1[3:0] < op2[3:0] + f[CARRY], 1'b0, flag_prty, 1'b1, flag_cf} :
    alu_m == ALU_AND ? {flag_sign, flag_zero, 3'b000, flag_prty, 1'b0, 1'b0} :
    alu_m == ALU_XOR ? {flag_sign, flag_zero, 3'b000, flag_prty, 1'b0, 1'b0} :
    alu_m == ALU_OR  ? {flag_sign, flag_zero, 3'b000, flag_prty, 1'b0, 1'b0} :
    alu_m == ALU_RLC ? {flag_sign, flag_zero, 3'b000, flag_prty, 1'b0, op1[7]} :
    alu_m == ALU_RRC ? {flag_sign, flag_zero, 3'b000, flag_prty, 1'b0, op1[0]} :
    alu_m == ALU_RL  ? {flag_sign, flag_zero, 3'b000, flag_prty, 1'b0, op1[7]} :
    alu_m == ALU_RR  ? {flag_sign, flag_zero, 3'b000, flag_prty, 1'b0, op1[0]} :
    alu_m == ALU_DAA ? {flag_sign, flag_zero, 1'b0, a[4] ^ alu_r[4], 1'b0, flag_prty, f[1], f[CARRY] | (a > 8'h99)} :
    alu_m == ALU_CPL ? {f[SIGN],   f[ZERO],   3'b010, f[PARITY], 1'b1, f[CARRY]} :
    alu_m == ALU_SCF ? {f[SIGN],   f[ZERO],   1'b0, f[AUX], 1'b0, f[PARITY], 1'b0, 1'b1} :
    alu_m == ALU_CCF ? {f[SIGN],   f[ZERO],   1'b0, f[AUX], 1'b0, f[PARITY], 1'b0, f[CARRY] ^ 1'b1} : f;

// -----------------------------------------------------------------------------
// Чтение и запись регистров
// -----------------------------------------------------------------------------

wire [7:0] reg_r8 =
    reg_n == 3'h0 ? bc[15:8] : reg_n == 3'h1 ? bc[ 7:0] :
    reg_n == 3'h2 ? de[15:8] : reg_n == 3'h3 ? de[ 7:0] :
    reg_n == 3'h4 ? hl[15:8] : reg_n == 3'h5 ? hl[ 7:0] :
    reg_n == 3'h6 ? f : a;

// Значение из [2:0]
wire [ 7:0] r20 =
    opcode[2:0] == 3'h0 ? bc[15:8] : opcode[2:0] == 3'h1 ? bc[ 7:0] :
    opcode[2:0] == 3'h2 ? de[15:8] : opcode[2:0] == 3'h3 ? de[ 7:0] :
    opcode[2:0] == 3'h4 ? hl[15:8] : opcode[2:0] == 3'h5 ? hl[ 7:0] :
    opcode[2:0] == 3'h6 ? f : a;

wire [15:0] reg_r16 =
    reg_n == 3'h0 ? bc :
    reg_n == 3'h1 ? de :
    reg_n == 3'h2 ? hl :
    reg_n == 3'h3 ? sp : {a, f};

// Запись в регистры
always @(negedge pin_clk) begin

    if (ex_de_hl) begin

        de <= hl;
        hl <= de;

    end else if (reg_w)

        case (reg_n)
        3'h0: bc <= {reg_u, reg_l};
        3'h1: de <= {reg_u, reg_l};
        3'h2: hl <= {reg_u, reg_l};
        3'h3: sp <= {reg_u, reg_l};
        endcase

    else if (reg_b)

        case (reg_n)
        3'h0: bc[15:8] <= reg_l;
        3'h1: bc[ 7:0] <= reg_l;
        3'h2: de[15:8] <= reg_l;
        3'h3: de[ 7:0] <= reg_l;
        3'h4: hl[15:8] <= reg_l;
        3'h5: hl[ 7:0] <= reg_l;
        // (hl)
        3'h7: a <= reg_l;
        endcase

end

endmodule

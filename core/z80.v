/* verilator lint_off WIDTH */
/* verilator lint_off CASEX */
/* verilator lint_off CASEINCOMPLETE */
/* verilator lint_off CASEOVERLAP */

module z80
(
    input               clock,          // 3.5 или 25 Мгц
    input               reset_n,        // =0 Сброс процессора
    input               compat,         // =1 Включена совместимость с Z80 Cycles
    input               hold,           // Если 0: не выполнять инструкции
    input               irq,            // Вызов IRQ на позитивном фронте
    output       [15:0] address,        // Адресная шина
    input        [ 7:0] i_data,         // Входящие данные с шины
    output  reg  [ 7:0] o_data,         // Данные на запись
    output  reg         we,             // =1 Запись в память
    output              m0,             // =1 Сигнал начала инструкции
    input        [ 7:0] portin,         // portin=port[address]
    output  reg         portwe          // Сигнал записи в порт address
);

// LOCALPARAM
// -----------------------------------------------------------------------------

localparam
    CF = 8, NF = 9, PF = 10, F3F = 11, HF = 12, F5F = 13, ZF = 14, SF = 15;

localparam
    alu_add = 0, alu_rlc =  8, alu_inc = 16, alu_rlca = 24,
    alu_adc = 1, alu_rrc =  9, alu_dec = 17, alu_rrca = 25,
    alu_sub = 2, alu_rl  = 10,               alu_rla  = 26,
    alu_sbc = 3, alu_rr  = 11,               alu_rra  = 27,
    alu_and = 4, alu_sla = 12, alu_daa = 20, alu_bit  = 28,
    alu_xor = 5, alu_sra = 13, alu_cpl = 21, alu_set  = 29,
    alu_or  = 6, alu_sll = 14, alu_scf = 22, alu_res  = 30,
    alu_cp  = 7, alu_srl = 15, alu_ccf = 23;

localparam
    spec_exaf   = 1,
    spec_exx    = 2,
    spec_exdehl = 3;

localparam
    ldcmd_ldi   = 1,
    ldcmd_ldd   = 2,
    ldcmd_cpi   = 3,
    ldcmd_cpd   = 4;

assign address = bus ? cp : pc;
assign m0 = (t_state == 0 && prefix == 0 && delay == 0);

// Основная логика работы процессора
// -----------------------------------------------------------------------------

always @(posedge clock) if (hold) begin

// Сброс регистров управления
exxw     <= 0;
ldcmd    <= 0;
reg_w8   <= 0;
reg_w16  <= 0;
reg_wf   <= 0;
reg_wfex <= 0;
we       <= 0;
portwe   <= 0;

// Ожидание задержки после исполнения инструкции
if (compat && delay) delay <= delay - 1;
// Сброс процессора
else if (reset_n == 1'b0) begin

    pc          <= 0;
    bus         <= 0;
    t_state     <= 0;
    set_prefix  <= 0;
    i_mode      <= 0;
    hptr        <= 0;

    iff1 <= 1'b0; iff1_ <= 1'b0;
    iff2 <= 1'b0; iff2_ <= 1'b0;

end
// Обработка прерывания
else if (irq_process) case (t_state)

    // Запись PC[7:0]
    0: begin

        t_state <= 1;

        // Писать в память
        bus <= 1; we <= 1; cp <= sp - 2; o_data <= pc[7:0];

        // SP=SP-2
        reg_w16 <= 1; reg_dt <= sp - 2; reg_id <= 3;

    end
    // Запись PC[15:8]
    1: begin t_state <= 2; we <= 1; o_data <= pc[15:8]; cp <= cp + 1; end
    // Считывание адреса
    2: begin

        if (i_mode == 2) begin

            t_state <= 3;
            hptr    <= ir[15:8];
            cp      <= {ir[15:8], 8'hFF};

        end
        // imode=0 [8080], imode=1 [standart]
        else begin

            t_state <= 0;
            bus     <= 0;
            pc      <= 8'h38;
            delay   <= 13-3-1;
            irq_process <= 0;

        end

    end
    3: begin t_state <= 4; cp <= cp + 1; pc[7:0] <= i_data; end
    4: begin

        t_state  <= 0;
        bus      <= 0;
        pc[15:8] <= i_data;
        delay    <= 19-5-1;
        irq_process <= 0;

    end

endcase
// На первом такте инструкции обнаружен вызов IRQ (и прерывания разрешены)
else if (iff1 && prefix == 0 && t_state == 0 && irq ^ irq_latch) begin

    // Проверить, что прерывания разрешены и что IRQ=0->1
    if (irq) begin

        irq_process <= 1;
        iff1 <= 1'b0; iff1_ <= 1'b0;
        iff2 <= 1'b0; iff2_ <= 1'b0;

        // Если текущая инструкция HALT
        if (i_data == 8'h76) pc <= pc + 1;

    end

    irq_latch <= irq;

end
// Исполнение инструкции
else begin

    // Защелкнуть опкод и увеличить R+1
    if (t_state == 0) begin

        // Если запрошено прерывание imode=0, то выбирает FF
        opcode_latch <= i_data;

        pc      <= pc + 1;
        ir[6:0] <= ir[6:0] + 1;

        // Защелкивание DI/EI через одну инструкцию
        if (prefix == 0) begin

            iff1 <= iff1_;
            iff2 <= iff2_;

        end

    end

    t_state <= t_state + 1;

    casex (opcode)

        // 1T|4T: EX AF,AF'
        8'b00_001_000: begin exxw <= spec_exaf; {set_prefix, t_state} <= 0; delay <= 4-1; end

        // 1/2T|8/13T: DJNZ *
        8'b00_010_000: case (t_state)

            0: begin

                // Запись в регистр B
                reg_w8 <= 1;
                reg_id <= 0;
                reg_dt <= bc[15:8] - 1;
                set_prefix <= 0;

                // Выход из цикла
                if (bc[15:8] == 1) begin pc <= pc + 2; t_state <= 0; delay <= 8-1; end

            end
            // Прочитать следующий байт и перейти
            1: begin

                pc <= pc + 1 + signex;
                t_state <= 0;
                delay   <= 13-2;

            end

        endcase

        // 2T|12T: JR *
        8'b00_011_000: case (t_state)

            1: begin pc <= pc + signex + 1; {set_prefix, t_state} <= 0; delay <= 12-2; end

        endcase

        // 1/2T|12/7T: JR cc, *
        8'b00_1xx_000: case (t_state)

            0: begin

                set_prefix <= 0;

                // Если условие не совпало, пропуск +2 байта вперед
                // Пример, opcode[4:3]=0, то если ZF=1, то произойдет выход из JR
                if (condition[ opcode[4:3] ]) begin

                    t_state <= 0;
                    pc      <= pc + 2;
                    delay   <= 7-1;

                end

            end
            // Иначе дочитать байт и перейти по метке
            1: begin

                pc <= pc + 1 + signex;
                t_state <= 0;
                delay   <= 12-2;

            end

        endcase

        // 3T|10T: LD r16, nn
        8'b00_xx_0001: case (t_state)

            1: begin pc <= pc + 1; reg_dt[ 7:0] <= i_data; end
            2: begin pc <= pc + 1; reg_dt[15:8] <= i_data;
                     reg_w16    <= 1;
                     reg_id     <= opcode[5:4];
                     {set_prefix, t_state} <= 0;
                     delay <= 10-3;
            end

        endcase

        // 1T/11T: ADD HL, r16
        8'b00_xx_1001: case (t_state)

            0: begin

                reg_w16  <= 1;
                reg_wfex <= 1;
                reg_id   <= 2;
                reg_dt   <= do_hl_add[15:0];
                flag_ex  <= do_hl_flag;
                {set_prefix, t_state} <= 0; delay <= 11-1;

            end

        endcase

        // 2T|7T: LD (BC|DE), A
        8'b00_0x_0010: case (t_state)

            0: begin

                cp      <= opcode[4] ? de : bc;
                bus     <= 1;
                we      <= 1;
                o_data  <= af[7:0];
                hptr    <= af[7:0];

            end
            1: begin {set_prefix, t_state, bus} <= 0; delay <= 7-2; end

        endcase

        // 2T|7T: LD A, (BC|DE)
        8'b00_0x_1010: case (t_state)

            0: begin cp <= opcode[4] ? de : bc; bus <= 1; end
            1: begin

                reg_w8 <= 1;
                reg_id <= 7;
                reg_dt <= i_data;
                {set_prefix, t_state, bus} <= 0; delay <= 7-2;

            end

        endcase

        // 5T|16T: LD (**), HL
        8'b00_10_0010: case (t_state)

            1: begin cp[ 7:0] <= i_data; pc <= pc + 1; end
            2: begin

                bus      <= 1;
                cp[15:8] <= i_data;
                hptr     <= i_data;
                pc       <= pc + 1;
                o_data   <= hlx[7:0];
                we       <= 1;

            end
            3: begin cp <= cp + 1; o_data <= hlx[15:8]; we <= 1; end
            4: begin {set_prefix, t_state, bus} <= 0; delay <= 16-5; end

        endcase

        // 4T|13T: LD (**), A
        8'b00_11_0010: case (t_state)

            1: begin cp[ 7:0] <= i_data; pc <= pc + 1; end
            2: begin

                we       <= 1;
                bus      <= 1;
                cp[15:8] <= i_data;
                pc       <= pc + 1;
                o_data   <= af[7:0];
                hptr     <= af[7:0];

            end
            3: begin {set_prefix, t_state, bus} <= 0; delay <= 16-4; end

        endcase

        // 5T|16T: LD HL, (**)
        8'b00_10_1010: case (t_state)

            1: begin cp[ 7:0] <= i_data; pc <= pc + 1; end
            2: begin cp[15:8] <= i_data; pc <= pc + 1; bus <= 1; hptr <= i_data; end
            3: begin reg_id <= /*L*/ 5; reg_dt <= i_data; reg_w8 <= 1; cp <= cp + 1; end
            4: begin

                reg_id <= /*H*/ 4; reg_dt <= i_data; reg_w8 <= 1;
                {set_prefix, t_state, bus} <= 0; delay <= 16-5;

            end

        endcase

        // 4T|13T: LD A, (**)
        8'b00_11_1010: case (t_state)

            1: begin cp[ 7:0] <= i_data; pc <= pc + 1; end
            2: begin cp[15:8] <= i_data; pc <= pc + 1; bus <= 1; hptr <= i_data; end
            3: begin

                reg_id <= /*A*/ 7; reg_dt <= i_data; reg_w8 <= 1;
                {set_prefix, t_state, bus} <= 0; delay <= 13-4;

            end

        endcase

        // 1T|6T: INC|DEC r16
        8'b00_xx_x011: case (t_state)

            0: begin

                reg_w16 <= 1;
                reg_id  <= opcode[5:4];
                case (opcode[5:4])
                    2'b00: reg_dt <= opcode[3] ? bc  - 1 : bc + 1;
                    2'b01: reg_dt <= opcode[3] ? de  - 1 : de + 1;
                    2'b10: reg_dt <= opcode[3] ? hlx - 1 : hlx + 1;
                    2'b11: reg_dt <= opcode[3] ? sp  - 1 : sp + 1;
                endcase
                {set_prefix, t_state} <= 0; delay <= 6-1;

            end

        endcase

        // 4T|11T: INC|DEC (HL)
        // 6T|23T: INC|DEC (IX|IY+d)
        8'b00_110_10x: case (t_state)

            // Запрос в память или чтение смещения
            0: begin

                bus     <= prefix ? 0 : 1;
                t_state <= prefix ? 1 : 2;
                alu_m   <= opcode[0] ? alu_dec : alu_inc;
                cp      <= hl;

            end
            // Дочитать смещение к IX|IY
            1: begin

                bus     <= 1;
                cp      <= hlx + signex;
                pc      <= pc + 1;

            end
            // Вычисление
            2: begin op1 <= i_data; op2 <= 1; end
            // Запись в память
            3: begin we <= 1; o_data <= alu_r[7:0]; reg_wf <= 1; end
            // Завершение инструкции
            4: begin {set_prefix, t_state, bus} <= 0; delay <= prefix ? 23-4-5: 11-4; end

        endcase

        // 2T|4T: INC|DEC r8
        8'b00_xxx_10x: case (t_state)

            0: begin op1 <= reg8_53; op2 <= 1; alu_m <= opcode[0] ? alu_dec : alu_inc; end
            1: begin

                reg_wf <= 1;
                reg_w8 <= 1;
                reg_id <= opcode[5:3];
                reg_dt <= alu_r[7:0];
                {set_prefix, t_state} <= 0; delay <= 4-2;

            end

        endcase

        // 3T|10T: LD (HL), *
        // 5T|19T: LD (IX|IY+d), *
        8'b00_110_110: case (t_state)

            // Писать в зависимости от префикса
            1: begin

                we      <= prefix ? 0 : 1;
                bus     <= prefix ? 0 : 1;
                t_state <= prefix ? 2 : 3;
                cp      <= prefix ? (hlx + signex) : hl;
                pc      <= pc + 1;
                o_data  <= i_data;

            end
            // Префиксированный
            2: begin

                we      <= 1;
                bus     <= 1;
                pc      <= pc + 1;
                o_data  <= i_data;

            end
            3: begin {bus, set_prefix, t_state} <= 0; delay <= prefix ? 19-4-4 : 10-3; end

        endcase

        // 2T|7T: LD r8, *
        8'b00_xxx_110: case (t_state)

            1: begin

                pc      <= pc + 1;
                reg_w8  <= 1;
                reg_id  <= opcode[5:3];
                reg_dt  <= i_data;
                {set_prefix, t_state} <= 0; delay <= 7-2;

            end

        endcase

        // 4T: <RLCA,RRCA,RLA,RRA,DAA,CPL,SCF,CCF>
        8'b00_xxx_111: case (t_state)

            0: begin op1 <= af[7:0]; alu_m <= (opcode[5] ? alu_daa : alu_rlca) + opcode[4:3]; end
            1: begin

                reg_w8 <= 1;
                reg_wf <= 1;
                reg_id <= 7;
                reg_dt <= alu_r;
                {set_prefix, t_state} <= 0; delay <= 4-2;

            end

        endcase

        // 1T: HALT
        8'b01_110_110: begin pc <= pc; {set_prefix, t_state} <= 0; delay <= 4-1; end

        // 2T|7T: LD (HL), r8
        // 4T|19T: LD (IX|IY+d), r8
        8'b01_110_xxx: case (t_state)

            0: begin

                bus     <= prefix ? 0 : 1;
                we      <= prefix ? 0 : 1;
                t_state <= prefix ? 1 : 2;
                cp      <= hl;
                o_data  <= reg8_20;

            end
            // Считывание смещения для префикса
            1: begin

                we      <= 1;
                bus     <= 1;
                cp      <= hlx + signex;
                pc      <= pc + 1;
                o_data  <= hl20_org;

            end
            2: begin {set_prefix, t_state, bus} <= 0; delay <= prefix ? 19-4-3 : 7-2; end

        endcase

        // 2T|7T: LD r8, (HL)
        // 4T|19T: LD r8, (IX|IY+d)
        8'b01_xxx_110: case (t_state)

            0: begin

                bus     <= prefix ? 0 : 1;
                t_state <= prefix ? 1 : 2;
                t_pref  <= prefix ? 1 : 0;
                cp      <= hl;

            end
            // Считывание смещения для префикса
            1: begin

                bus     <= 1;
                cp      <= hlx + signex;
                pc      <= pc + 1;
                set_prefix <= 0;

            end
            // Запись в регистр
            2: begin

                reg_w8 <= 1;
                reg_id <= opcode[5:3];
                reg_dt <= i_data;

                {t_state, bus} <= 0; delay <= t_pref ? 19-4-3 : 7-2;

            end

        endcase

        // 1T|4T: LD r8, r8
        8'b01_xxx_xxx: case (t_state)

            0: begin

                reg_w8 <= 1;
                reg_id <= opcode[5:3];
                reg_dt <= reg8_20;
                {set_prefix, t_state} <= 0; delay <= 4-1;

            end

        endcase

        // 3T|7T: <ALU> a, (HL)
        // 5T|19T: <ALU> a, (IX|IY+d)
        8'b10_xxx_110: case (t_state)

            // Установить адрес на шину (если это HL)
            0: begin

                bus     <= prefix ? 0 : 1;
                t_state <= prefix ? 1 : 2;
                alu_m   <= opcode[5:3];
                op1     <= af[7:0];
                cp      <= hl;

            end
            // Дочитывание смещения к префиксу и адрес IX|IY+d
            1: begin

                bus     <= 1;
                cp      <= hlx + signex;
                pc      <= pc + 1;

            end
            // Лишний такт тратится впустую
            2: begin op2 <= i_data; bus <= 0; end
            3: begin

                reg_wf <= 1;
                reg_id <= 7;
                reg_w8 <= opcode[5:3] != alu_cp;
                reg_dt <= alu_r[7:0];
                {set_prefix, t_state} <= 0; delay <= prefix ? 19-4-4: 7-3;

            end

        endcase

        // 2T|4T: <ALU> a, r8
        8'b10_xxx_xxx: case (t_state)

            0: begin op1 <= af[7:0]; op2 <= reg8_20; alu_m <= opcode[5:3]; end
            1: begin

                reg_wf <= 1;
                reg_id <= 7;
                reg_w8 <= opcode[5:3] != alu_cp;
                reg_dt <= alu_r[7:0];
                {set_prefix, t_state} <= 0; delay <= 4-2;

            end

        endcase

        // 1/3T|10/11/5T: RET ccc|RET
        8'b11_001_001,
        8'b11_xxx_000: case (t_state)

            0: begin

                set_prefix <= 0;

                // Условие не сработало, к следующей инструкции
                // Если opcode[0]=1, то RET безусловный
                if (condition[ opcode[5:3] ] && (opcode[0] == 1'b0)) begin

                    t_state <= 0;
                    delay   <= 5-1;

                end
                else begin

                    bus     <= 1;
                    cp      <= sp;
                    reg_w16 <= 1;
                    reg_dt  <= sp + 2;
                    reg_id  <= 3;

                end

            end
            1: begin pc[7:0] <= i_data; cp <= cp + 1; end
            2: begin

                pc[15:8] <= i_data;
                {t_state, bus} <= 0; delay <= opcode[0] ? 10-3 : 11-3;

            end

        endcase

        // 3T|10T: POP r16
        8'b11_xx0_001: case (t_state)

            0: begin

                bus     <= 1;
                cp      <= sp;
                reg_w16 <= 1;
                reg_dt  <= sp + 2;
                reg_id  <= 3;

            end
            1: begin

                // POP AF
                if (opcode[5:4] == 2'b11) begin

                    reg_wfex <= 1;
                    flag_ex  <= i_data;

                end else begin

                    reg_w8 <= 1;
                    reg_id <= {opcode[5:4], 1'b1};
                    reg_dt <= i_data;

                end

                cp <= cp + 1;

            end
            2: begin

                reg_w8 <= 1;
                reg_id <= opcode[5:4] == 2'b11 ? 7 : {opcode[5:4], 1'b0};
                reg_dt <= i_data;

                {set_prefix, t_state, bus} <= 0; delay <= 10-3;

            end

        endcase

        // 1T/4T: EXX
        8'b11_011_001: case (t_state)

            0: begin {set_prefix, t_state} <= 0; exxw <= spec_exx; delay <= 4-1; end

        endcase

        // 1T/4T: JP (HL)
        8'b11_101_001: case (t_state)

            0: begin pc <= hlx; {set_prefix, t_state} <= 0; delay <= 4-1; end

        endcase

        // 1T/6T: LD SP, HL
        8'b11_111_001: case (t_state)

            0: begin

                reg_w16 <= 1;
                reg_dt  <= hlx;
                reg_id  <= 3;

                {set_prefix, t_state} <= 0; delay <= 6-1;

            end

        endcase

        // 2/3T|10T: JP ccc, **; JP **
        8'b11_000_011,
        8'b11_xxx_010: case (t_state)

            0: begin

                set_prefix <= 0;

                // Условие не сработало, к следующей инструкции
                // Если opcode[0]=1, то переход безусловный
                if (condition[ opcode[5:3] ] && (opcode[0] == 1'b0)) begin
                    pc      <= pc + 2;
                    t_state <= 3;
                end

            end
            1: begin reg_dt <= i_data; pc <= pc + 1; end
            2: begin hptr <= i_data; pc <= {i_data, reg_dt[7:0]}; t_state <= 0; delay <= 10-3; end
            // Необходимо для получения HPTR
            3: begin hptr <= i_data; pc <= pc + 1; t_state <= 0; delay <= 10-2; end

        endcase

        // CB: Битовые инструкции
        // 4T/8T:  <opcode> r8
        // 5T/15T: <opcode> (HL)
        // 5T/23T: <opcode> (IX+*)
        // 4T/12T: BIT n,(HL)
        // 4T/20T: BIT n,(IX+*)
        8'b11_001_011: case (t_state)

            // Чтение опкода или смещения
            1: begin

                pc  <= pc + 1;
                cp  <= prefix ? hlx + signex : hl;
                bus <= prefix ? 0 : 1; // Если (Ixy+*), дочитать PC+1

                opcode_ext <= i_data;
                ir[6:0]    <= ir[6:0] + 1;

                if (prefix == 0) t_state <= 3;

            end

            // Считывание опкода для префиксированной инструкции
            2: begin opcode_ext <= i_data; pc <= pc + 1; bus <= 1; end

            // Чтение данных из памяти или регистра
            3: begin

                op1     <= prefix ? i_data : reg8_cb20;
                op2     <= opcode_ext[6:3];
                alu_m   <= opcode_ext[5:3] + alu_rlc;

                // Убрать префиксирование для BIT
                t_pref     <= prefix ? 1 : 0;
                set_prefix <= 0;

            end

            // Исполнение и сохранение
            4: casex (opcode_ext[7:6])

                // BIT n, r8
                // BIT n, (HL)
                8'b01: begin

                    reg_wfex <= 1;
                    flag_ex  <= t_pref ? bit_flags_xx : bit_flags;

                    // BIT n, (HL)
                    if (t_pref == 0 && opcode_ext[2:0] == 6)
                        {flag_ex[5],flag_ex[3]} <= {hptr[5],hptr[3]};

                    // Все префиксированные выполняются за 20T
                    {bus, t_state} <= 0;
                    delay <= t_pref ? 20-4-5 : (opcode_ext[2:0] == 6 ? 12-4 : 8-4);

                end

                // SHIFT|RES|SET n, reg|idata
                // Сохранение в регистры и в память (если выбрано)
                8'b00,
                8'b1x: begin

                    // Кроме HL и префиксированных
                    we      <= (opcode_ext[2:0] == 6) || t_pref;
                    reg_w8  <= (opcode_ext[2:0] != 6);
                    reg_id  <=  opcode_ext[2:0];

                    // Если это RES|SET, то из rsop, иначе из alu_r
                    reg_dt  <= opcode_ext[7] ? rsop : alu_r;
                    o_data  <= opcode_ext[7] ? rsop : alu_r;

                    // Операции сдвига меняют флаги
                    if (opcode_ext[7] == 1'b0) reg_wf <= 1;

                    // Нет префикса и нет (HL)
                    if (t_pref == 0 && (opcode_ext[2:0] != 6)) begin
                        {bus, t_state} <= 0; delay <= 8-4;
                    end

                end

            endcase

            // Завершение записи для инструкции [00-3F,80-FF]
            5: begin {bus, t_state} <= 0; delay <= t_pref ? 23-4-6 : 15-5; end

        endcase

        // 3T/11T: OUT (*), A
        8'b11_010_011: case (t_state)

            1: begin

                bus     <= 1;
                portwe  <= 1;
                o_data  <= af[7:0];
                hptr    <= af[7:0];
                cp      <= {af[7:0], i_data};
                pc      <= pc + 1;

            end
            2: begin {set_prefix, t_state, bus} <= 0; delay <= 11-3; end

        endcase

        // 3T/11T: IN A,(*)
        8'b11_011_011: case (t_state)

            1: begin bus <= 1; cp <= {af[7:0], i_data}; hptr <= af[7:0]; pc <= pc + 1; end
            2: begin

                reg_id <= 7;
                reg_w8 <= 1;
                reg_dt <= portin;
                {set_prefix, t_state, bus} <= 0; delay <= 11-3;

            end

        endcase

        // 5T/19T: EX (SP), HL
        8'b11_100_011: case (t_state)

            0: begin bus <= 1; cp <= sp; end
            1: begin reg_dt[ 7:0] <= i_data; cp <= cp + 1; end
            2: begin reg_dt[15:8] <= i_data; cp <= cp - 1; we <= 1; o_data <= hlx[7:0]; end
            3: begin

                reg_w16 <= 1;
                reg_id  <= 2;

                we <= 1;
                cp <= cp + 1;
                o_data <= hlx[15:8];

            end
            4: begin {set_prefix, t_state, bus} <= 0; delay <= 19-5; end

        endcase

        // 1T/4T: EX DE,HL
        8'b11_101_011: case (t_state)

            0: begin {set_prefix, t_state} <= 0; exxw <= spec_exdehl; delay <= 4-1; end

        endcase

        // 1T/4T: DI/EI
        8'b11_11x_011: case (t_state)

            // Срабатывает активация iff1/2 через одну инструкцию
            0: begin

                iff1_ <= opcode[3];
                iff2_ <= opcode[3];
                {set_prefix, t_state} <= 0; delay <= 4-1;

            end

        endcase

        // 2/5T|10/17T: CALL ccc, **; CALL **
        8'b11_001_101,
        8'b11_xxx_100: case (t_state)

            0: begin

                set_prefix <= 0;

                // Условие не сработало, к следующей инструкции
                // Если opcode[0]=1, то переход безусловный
                if (condition[ opcode[5:3] ] && (opcode[0] == 1'b0)) begin

                    pc      <= pc + 2;
                    t_state <= 5;

                end
                // Иначе считывать адрес памяти
                else begin

                    reg_w16 <= 1;
                    reg_dt  <= sp - 2;
                    reg_id  <= 3;

                end

            end
            1: begin reg_dt <= i_data; pc <= pc + 1; end
            2: begin

                bus     <= 1;
                we      <= 1;
                cp      <= sp;
                pc      <= {i_data, reg_dt[7:0]};
                hptr    <= i_data;
                o_data  <= pc1[7:0];
                reg_dt  <= pc1;

            end
            3: begin

                we      <= 1;
                cp      <= cp + 1;
                o_data  <= reg_dt[15:8];

            end
            4: begin {t_state, bus} <= 0; delay <= 17-5; end
            // Для получения HPTR
            5: begin hptr <= i_data; pc <= pc + 1; t_state <= 0; delay <= 10-2; end

        endcase

        // 3T|11T: PUSH r16
        8'b11_xx0_101: case (t_state)

            // Запись младшего байта
            0: begin

                bus <= 1;
                we  <= 1;
                cp  <= sp - 2;

                // sp = sp - 2
                reg_w16 <= 1;
                reg_dt  <= sp - 2;
                reg_id  <= 3;

                case (opcode[5:4])
                    0: o_data <=  bc[ 7:0];
                    1: o_data <=  de[ 7:0];
                    2: o_data <= hlx[ 7:0];
                    3: o_data <=  af[15:8]; // Флаги (LO)
                endcase

            end

            // Запись старшего байта
            1: begin

                we <= 1;
                cp <= cp + 1;
                case (opcode[5:4])
                    0: o_data <=  bc[15:8];
                    1: o_data <=  de[15:8];
                    2: o_data <= hlx[15:8];
                    3: o_data <=  af[ 7:0]; // Аккумулятор (HI)
                endcase

            end
            2: begin {set_prefix, t_state, bus} <= 0; delay <= 11-3; end

        endcase

        // EXTENDED
        8'b11_101_101: case (t_state)

            0: begin set_prefix <= 0; n_state <= 0; end
            1: begin

                pc <= pc + 1;
                opcode_ext <= i_data;

                casex (i_data)

                    // IN r8, (C)
                    8'b01_xxx_000: begin cp <= bc; bus <= 1; end

                    // OUT (C), r8
                    8'b01_xxx_001: begin

                        bus     <= 1;
                        portwe  <= 1;
                        cp      <= bc;
                        o_data  <= reg8_outc;

                     end

                    // 2T: SBC|ADC hl, r16
                    8'b01_xxx_010: begin

                        reg_w16  <= 1;
                        reg_wfex <= 1;
                        reg_id   <= 2; // HL
                        reg_dt   <= i_data[3] ? ed_hl_adc   : ed_hl_sbc;
                        flag_ex  <= i_data[3] ? hl_adc_flag : hl_sbc_flag;

                        t_state <= 0; delay <= 15-2;

                    end

                    // 6T: LD (**),r16 | r16,(**)
                    8'b01_xxx_011: begin /* nothing */ end

                    // NEG
                    8'b01_xxx_100: begin

                        op1   <= 0;
                        op2   <= af[7:0];
                        alu_m <= alu_sub;

                    end

                    // RETN/RETI
                    8'b01_xxx_101: begin

                        bus     <= 1;
                        cp      <= sp;
                        reg_w16 <= 1;
                        reg_dt  <= sp + 2;
                        reg_id  <= 3;

                        // RETN, кроме RETI
                        if (i_data[5:3] != 3'b001) begin

                            iff1  <= iff2;
                            iff1_ <= iff2_;

                        end

                    end

                    // IM n: [00120012]
                    8'b01_xxx_110: begin

                        i_mode <= i_data[4] ? (i_data[3] ? 2 : 1) : 0;
                        t_state <= 0; delay <= 8-2;

                    end

                    // LD i|r, a
                    // LD a, i|r
                    8'b01_0xx_111: begin

                        reg_id <= 7;
                        reg_dt <= i_data[3] ? ir[7:0] : ir[15:8];

                        if      (i_data[4]) reg_w8 <= 1;
                        else if (i_data[3]) ir[7:0] <= af[7:0]; else ir[15:8] <= af[7:0];

                        // LD A, I|R записывает флаги
                        if (i_data[4]) begin

                            reg_wfex <= 1;

                            if (i_data[3]) // Если выполняется прерывание то PV=0
                                 flag_ex <= {ir[ 7], ir[ 7:0] == 0, ir[ 5], 1'b0, ir[ 3], (irqcause ? 1'b0 : iff2), 1'b0, af[CF]};
                            else flag_ex <= {ir[15], ir[15:8] == 0, ir[13], 1'b0, ir[11], (irqcause ? 1'b0 : iff2), 1'b0, af[CF]};

                        end

                        t_state <= 0; delay <= 9-2;

                    end

                    // RRD |RLD
                    // LDI |LDD |LDIR|LDDR
                    // CPI |CPD |CPIR|CPDR
                    // OUTI|OUTD|OTIR|OTDR
                    8'b01_10x_111,
                    8'b10_1xx_00x,
                    8'b10_1xx_011: begin cp <= hl; bus <= 1; end
                    // INI |IND |INIR|INDR
                    8'b10_1xx_010: begin

                        cp      <= {b_dec, bc[7:0]};
                        bus     <= 1;
                        alu_m   <= alu_dec;
                        op1     <= bc[15:8];
                        op2     <= 1;

                    end

                    // NOP инструкция
                    default: begin t_state <= 0; delay <= 8-2; end

                endcase

            end
            2: begin

                t_state <= 2;
                n_state <= n_state + 1;

                casex (opcode_ext)

                // 3T: IN r8, (C)
                8'b01_xxx_000: begin

                    reg_w8   <= 1;
                    reg_wfex <= 1;

                    // При записи в 6-й регистр ничего не происходит
                    reg_id <= opcode_ext[5:3];
                    reg_dt <= portin;

                    // Вычисление флагов
                    flag_ex <= {
                        portin[7],      // S
                        portin == 0,    // Z
                        portin[5],      // F5
                        1'b0,           // H
                        portin[3],      // F3
                        ~^portin[7:0],  // P
                        1'b0,           // N
                        af[CF]          // C
                    };

                    {t_state, bus} <= 0; delay <= 12-3;

                end

                // 3T: OUT (C), r8
                8'b01_xxx_001: begin {t_state, bus} <= 0; delay <= 12-3; end

                // 6T: LD (**), r16
                8'b01_xx0_011: case (n_state)

                    0: begin cp[7:0] <= i_data; pc <= pc + 1; end

                    // Запись младшего байта
                    1: begin

                        cp[15:8] <= i_data;
                        hptr     <= i_data;

                        pc  <= pc + 1;
                        bus <= 1;
                        we  <= 1;

                        case (opcode_ext[5:4])

                            2'b00: o_data <= bc[7:0];
                            2'b01: o_data <= de[7:0];
                            2'b10: o_data <= hl[7:0];
                            2'b11: o_data <= sp[7:0];

                        endcase

                    end

                    // Запись старшего байта
                    2: begin

                        we <= 1;
                        cp <= cp + 1;

                        case (opcode_ext[5:4])

                            2'b00: o_data <= bc[15:8];
                            2'b01: o_data <= de[15:8];
                            2'b10: o_data <= hl[15:8];
                            2'b11: o_data <= sp[15:8];

                        endcase

                    end

                    // Завершение записи
                    3: begin {t_state, bus} <= 0; delay <= 20-6; end

                endcase

                // 6T: LD r16, (**)
                8'b01_xx1_011: case (n_state)

                    0: begin cp[ 7:0] <= i_data; pc <= pc + 1; end
                    1: begin cp[15:8] <= i_data; pc <= pc + 1; bus <= 1; hptr <= i_data; end
                    2: begin reg_dt[7:0] <= i_data; cp <= cp + 1; end
                    3: begin

                        reg_w16 <= 1;
                        reg_id  <= opcode_ext[5:4];
                        reg_dt[15:8] <= i_data;

                        {t_state, bus} <= 0; delay <= 20-6;

                    end

                endcase

                // 4T: RETN/RETI
                8'b01_xxx_101: case (n_state)

                    0: begin pc[ 7:0] <= i_data; cp <= cp + 1; end
                    1: begin pc[15:8] <= i_data; {t_state, bus} <= 0; delay <= 14-4; end

                endcase

                // 3T: NEG
                8'b01_xxx_100: begin

                    reg_id <= 7;
                    reg_wf <= 1;
                    reg_w8 <= 1;
                    reg_dt <= alu_r;

                    t_state <= 0; delay <= 8-3;

                end

                // 4T: RRD|RLD
                8'b01_10x_111: case (n_state)

                    0: begin

                        we       <= 1; // Запись в память
                        reg_w8   <= 1; // Запись в регистр A
                        reg_wfex <= 1; // Писать кастомные флаги
                        reg_id   <= 7;
                        o_data   <= opcode_ext[3] ? rld_w : rrd_w;
                        reg_dt   <= opcode_ext[3] ? rld_a : rrd_a;

                        flag_ex <= opcode_ext[3] ? {
                            rld_a[7],   rld_a == 0, rld_a[5], 1'b0,
                            rld_a[3], ~^rld_a[7:0],     1'b0, af[CF]
                        } : {
                            rrd_a[7],   rrd_a == 0, rrd_a[5], 1'b0,
                            rrd_a[3], ~^rrd_a[7:0],     1'b0, af[CF]
                        };

                    end

                    1: begin {t_state, bus} <= 0; delay <= 18-4; end

                endcase

                // 4T: LDI|LDD|LDIR|LDDR
                8'b10_1xx_000: case (n_state)

                    // Запись в память
                    0: begin

                        we       <= 1;
                        cp       <= de;
                        o_data   <= i_data;
                        reg_wfex <= 1;
                        flag_ex  <= {
                            af[SF],   af[ZF],  ldixy[1], 1'b0,
                            ldixy[3], bc != 1, 1'b0,     af[CF]
                        };

                        // Уменьшить BC--; икремент/декремент HL/DE
                        ldcmd <= opcode_ext[3] ? ldcmd_ldd : ldcmd_ldi;

                    end

                    // Завершение инструкции
                    1: begin

                        delay <= 16-4;
                        // Если это LDIR, LDDR то проверить BC на 0
                        if (opcode_ext[4] && bc) begin pc <= pc - 2; delay <= 21-4; end
                        {t_state, bus} <= 0;

                    end

                endcase

                // 4T: CPI|CPD|CPIR|CPDR
                8'b10_1xx_001: case (n_state)

                    // Запрос к АЛУ на вычисление CP
                    0: begin

                        alu_m <= alu_cp;
                        op1   <= af[7:0];
                        op2   <= i_data;
                        ldcmd <= opcode_ext[3] ? ldcmd_cpd : ldcmd_cpi;

                    end

                    // Обновление флагов
                    1: begin

                        reg_wfex <= 1;
                        flag_ex  <= {
                            alu_f[7], alu_f[6], cpixy[1], alu_f[4],
                            cpixy[3], bc != 0,  1'b1,     af[CF]
                        };

                        delay <= 16-4;
                        // Если это CPIR, CPDR то проверить BC на 0 и чтобы ZF=0
                        if (opcode_ext[4] && !alu_f[6] && bc)
                        begin pc <= pc - 2; delay <= 21-4; end

                        {t_state, bus} <= 0;

                    end

                endcase

                // 4T: INI|IND|INIR|INDR
                8'b10_1xx_010: case (n_state)

                    0: begin

                        // Чтение из порта
                        we      <= 1;
                        cp      <= hl;
                        o_data  <= portin;

                        // Обновление B
                        reg_wf  <= 1;
                        reg_w8  <= 1;
                        reg_id  <= 0;
                        reg_dt  <= alu_r;

                    end

                    1: begin

                        // Икремент или декремент HL
                        reg_w16 <= 1;
                        reg_id  <= 2;
                        reg_dt  <= opcode_ext[3] ? hl - 1 : hl + 1;

                        delay  <= 16-4;
                        // Если это CPIR, CPDR то проверить B на 0
                        if (opcode_ext[4] && alu_r[7:0]) begin pc <= pc - 2; delay <= 21-4; end
                        {t_state, bus} <= 0;

                    end

                endcase

                // 4T: OUTI|OUTD|OTIR|OTDR
                8'b10_1xx_011: case (n_state)

                    // Запись в порт, HL++/--, декремент B
                    0: begin

                        // Запись в порт значения из памяти
                        portwe  <= 1;
                        cp      <= bc;
                        o_data  <= i_data;

                        // Инкремент или декремент HL
                        reg_w16 <= 1;
                        reg_id  <= 2;
                        reg_dt  <= opcode_ext[3] ? hl - 1 : hl + 1;

                        // Декремент B через АЛУ
                        alu_m <= alu_dec;
                        op1   <= bc[15:8];
                        op2   <= 1;

                    end

                    1: begin

                        reg_wf <= 1;
                        reg_w8 <= 1;
                        reg_dt <= alu_r;
                        reg_id <= 0;

                        delay  <= 16-4;
                        // Если это CPIR, CPDR то проверить B на 0
                        if (opcode_ext[4] && alu_r[7:0]) begin pc <= pc - 2; delay <= 21-4; end
                        {t_state, bus} <= 0;

                    end

                endcase

                endcase

            end

        endcase

        // 3T|7T: <ALU> a,*
        8'b11_xxx_110: case (t_state)

            0: begin op1 <= af[7:0]; alu_m <= opcode[5:3]; end
            1: begin op2 <= i_data; pc <= pc + 1; end
            2: begin

                reg_wf <= 1;
                reg_id <= 7;
                reg_w8 <= opcode[5:3] != alu_cp;
                reg_dt <= alu_r[7:0];
                {set_prefix, t_state} <= 0; delay <= 7-3;

            end

        endcase

        // 3T|11T: RST #n
        8'b11_xxx_111: case (t_state)

            0: begin

                bus <= 1;
                we  <= 1;
                cp  <= sp - 2;
                o_data <= pc1[7:0];

                reg_w16 <= 1;
                reg_dt  <= sp - 2;
                reg_id  <= 3;

                set_prefix <= 0;

            end
            1: begin we <= 1; o_data <= pc[15:8]; cp <= cp + 1; end
            2: begin pc <= {opcode[5:3], 3'b000}; {t_state, bus} <= 0; delay <= 11-3; end

        endcase

        // 1T|4T: Префиксы IX и IY
        8'b1101_1101: begin t_state <= 0; set_prefix <= 1; delay <= 4-1; end
        8'b1111_1101: begin t_state <= 0; set_prefix <= 2; delay <= 4-1; end

        // Пропуск инструкции
        default: begin {set_prefix, t_state} <= 0; delay <= 4-1; end

    endcase

    // В "быстром режиме" работы нет задержек
    if (compat == 0) delay <= 0;

end
end

// Регистры процессора z80
// -----------------------------------------------------------------------------
// Основной и дополнительный наборы регистров

reg [15:0]  bc = 16'h03EF; reg [15:0] bc_prime = 16'h0000;
reg [15:0]  de = 16'h4732; reg [15:0] de_prime = 16'h0000;
reg [15:0]  hl = 16'h4005; reg [15:0] hl_prime = 16'h0000;
reg [15:0]  af = 16'h0120; reg [15:0] af_prime = 16'h1234;
// Индексные регистры
reg [15:0]  ix = 16'h000E; reg [15:0] iy = 16'h0306;
// Регистры управления программой
reg [15:0]  pc = 16'h0000;
reg [15:0]  sp = 16'hFFFE;
reg [15:0]  ir = 16'h0000;

// Предварительные инициализации
// -----------------------------------------------------------------------------

initial begin o_data = 0; we = 0; portwe = 0; end

// Состояние процессора
// -----------------------------------------------------------------------------

reg [ 3:0]  t_state     = 0;        // Фаза исполнения опкода
reg [ 2:0]  n_state     = 0;        // Фаза исполнения EDh опкода
reg [ 4:0]  delay       = 0;        // Задержка для совместимости
reg         bus         = 1'b0;     // Выбор источника адреса
reg [15:0]  cp          = 16'h0000; // CurrentPointer: альтернативный address
reg [ 7:0]  opcode_latch;           // Защелка для опкода
reg [ 7:0]  opcode_ext;             // Дополнительный опкод
reg [ 1:0]  set_prefix  = 0;        // Команда для установки префикса на обратном фронте
reg [ 1:0]  prefix      = 0;        // Текущий префикс, 0=нет, 1=IX, 2=IY
reg         t_pref      = 0;        // Наличие префикса в запросе инструкции
reg [ 1:0]  exxw        = 0;        // Специальная запись в регистры
reg [ 2:0]  ldcmd       = 0;        // =1 HL++,DE++,BC--; =2 HL++,BC--;
                                    // =3 HL--,DE--,BC--; =4 HL--,BC--
reg         reg_w8      = 0;        // Писать результат в регистр 8 бит
reg         reg_w16     = 0;        // Писать результат в регистр 16 бит
reg         reg_wfex    = 0;        // Запись специальных флагов
reg         reg_wf      = 0;        // Запись флагов из alu_f в af[15:8]
reg [ 3:0]  reg_id      = 0;        // Номер регистра для записи
reg [15:0]  reg_dt      = 0;        // Данные для записи в регистр
reg [ 7:0]  flag_ex     = 0;        // Специальные флаги для reg_wfex=1
reg [ 7:0]  hptr        = 0;        // Специальный регистр для BIT n,(HL)

// Аппаратное прерывание
// -----------------------------------------------------------------------------

reg [ 1:0]  i_mode      = 2'b00;
reg         iff1        = 1'b0;
reg         iff2        = 1'b0;
reg         iff1_       = 1'b0;
reg         iff2_       = 1'b1;
reg         irq_latch   = 1'b0;
reg         irq_process = 1'b0;

// Вычисление проводов
// -----------------------------------------------------------------------------

// Выбор опкода
wire [7:0]  opcode   = t_state? opcode_latch : i_data;
wire [15:0] hlx      = prefix == 1 ? ix : (prefix == 2 ? iy : hl);
wire [15:0] signex   = {{8{i_data[7]}}, i_data[7:0]};
wire        irqcause = irq ^ irq_latch;

// Выбор регистра из opcode[2:0]
wire [7:0] reg8_20 =
    opcode[2:0] == 0 ?  bc[15:8] : opcode[2:0] == 1 ?  bc[ 7:0] :
    opcode[2:0] == 2 ?  de[15:8] : opcode[2:0] == 3 ?  de[ 7:0] :
    opcode[2:0] == 4 ? hlx[15:8] : opcode[2:0] == 5 ? hlx[ 7:0] :
    opcode[2:0] == 6 ? i_data    : af[7:0];

// Выбор регистра из opcode[5:3]
wire [7:0] reg8_53 =
    opcode[5:3] == 0 ?  bc[15:8] : opcode[5:3] == 1 ?  bc[ 7:0] :
    opcode[5:3] == 2 ?  de[15:8] : opcode[5:3] == 3 ?  de[ 7:0] :
    opcode[5:3] == 4 ? hlx[15:8] : opcode[5:3] == 5 ? hlx[ 7:0] :
    opcode[5:3] == 6 ? i_data    : af[7:0];

// Для префикса CB **
wire [7:0] reg8_cb20 =
    opcode_ext[2:0] == 0 ? bc[15:8] : opcode_ext[2:0] == 1 ? bc[ 7:0] :
    opcode_ext[2:0] == 2 ? de[15:8] : opcode_ext[2:0] == 3 ? de[ 7:0] :
    opcode_ext[2:0] == 4 ? hl[15:8] : opcode_ext[2:0] == 5 ? hl[ 7:0] :
    opcode_ext[2:0] == 6 ? i_data   : af[7:0];

// Для OUT (C), r8
wire [7:0] reg8_outc =
    i_data[5:3] == 0 ? bc[15:8] : i_data[5:3] == 1 ? bc[ 7:0] :
    i_data[5:3] == 2 ? de[15:8] : i_data[5:3] == 3 ? de[ 7:0] :
    i_data[5:3] == 4 ? hl[15:8] : i_data[5:3] == 5 ? hl[ 7:0] :
    i_data[5:3] == 6 ? 0        : af[7:0];

// Выбор оригинального H,L при префиксированных инструкциях
wire [7:0] hl20_org = opcode[2:0] == 4 ? hl[15:8] :
                      opcode[2:0] == 5 ? hl[ 7:0] : reg8_20;

wire [15:0] pc1 = pc + 1;

// 0-nz, 1-z,  2-nc, 3-c
// 4-po, 5-pe, 6-p,  7-m
wire [7:0] condition = {
    ~af[SF], af[SF], // 7,6 s
    ~af[PF], af[PF], // 5,4 p
    ~af[CF], af[CF], // 3,2 c
    ~af[ZF], af[ZF]  // 1,0 Z
};

// АЛУ
// -----------------------------------------------------------------------------

reg  [4:0] alu_m;   // Режим работы АЛУ
reg  [7:0] op1;     // Операнды
reg  [7:0] op2;

wire zf8 = alu_r[7:0]==0;           // Zero
wire pf8 = ~^alu_r[7:0];            // Parity
wire sf8 = alu_r[7];                // Sign
wire cf8 = alu_r[8];                // Carry
wire f58 = alu_r[5];                // H5 Undocumented
wire f38 = alu_r[3];                // H3 Undocumented
wire hf8 = alu_r[4]^op1[4]^op2[4];  // Half-Carry
wire oa8 = (op1[7] == op2[7]) & (op1[7] != alu_r[7]);
wire os8 = (op1[7] != op2[7]) & (op1[7] != alu_r[7]);

// Специальный расчет флага H
wire [4:0] ha8 = op1[3:0] + op2[3:0] + af[CF];
wire [4:0] hs8 = op1[3:0] - op2[3:0] - af[CF];

// Вычисление результата
wire [8:0] alu_r =
    alu_m == alu_add  ? op1 + op2 :
    alu_m == alu_adc  ? op1 + op2 + af[CF] :
    alu_m == alu_sub  ? op1 - op2 :
    alu_m == alu_sbc  ? op1 - op2 - af[CF] :
    alu_m == alu_and  ? op1 & op2 :
    alu_m == alu_xor  ? op1 ^ op2 :
    alu_m == alu_or   ? op1 | op2 :
    alu_m == alu_cp   ? op1 - op2 :
    alu_m == alu_inc  ? op1 + op2 :
    alu_m == alu_dec  ? op1 - op2 :
    // Сдвиговые операции
    alu_m == alu_rlca || alu_m == alu_rlc ? {op1[6:0], op1[7]}   : // a << 1
    alu_m == alu_rrca || alu_m == alu_rrc ? {op1[0],   op1[7:1]} : // a >> 1
    alu_m == alu_rla  || alu_m == alu_rl  ? {op1[6:0], af[CF]}   : // a << 1
    alu_m == alu_rra  || alu_m == alu_rr  ? {af[CF],   op1[7:1]} : // a >> 1
    alu_m == alu_sla ? {op1[6:0], 1'b0}   : // a << 1
    alu_m == alu_sll ? {op1[6:0], 1'b1}   : // a << 1
    alu_m == alu_sra ? {op1[7], op1[7:1]} : // a >> 1
    alu_m == alu_srl ? {1'b0,   op1[7:1]} : // a >> 1
    // Коррекции
    alu_m == alu_daa  ? daa_2 :
    alu_m == alu_cpl  ? ~op1 :
    // Все остальные
    op1;

// Результат флаговых вычислений [S Z F5 H F3 P/V N C]
wire [7:0] alu_f =

    // Группа ADD, ADC
    (alu_m == alu_add) ? {sf8, zf8, f58,    hf8,    f38,    oa8, 1'b0, cf8} :
    (alu_m == alu_adc) ? {sf8, zf8, f58,    ha8[4], f38,    oa8, 1'b0, cf8} :
    (alu_m == alu_sbc) ? {sf8, zf8, f58,    hs8[4], f38,    os8, 1'b1, cf8} :
    (alu_m == alu_sub) ? {sf8, zf8, f58,    hf8,    f38,    os8, 1'b1, cf8} :
    (alu_m == alu_cp)  ? {sf8, zf8, op2[5], hf8,    op2[3], os8, 1'b1, cf8} :
    // Для AND выставляет H=1
    (alu_m == alu_and) ? {sf8, zf8, f58, 1'b1, f38, pf8, 2'b00} :
    // Другие логические (XOR|OR)
    (alu_m == alu_xor || alu_m == alu_or) ? {sf8, zf8, f58, 1'b0, f38, pf8, 2'b00} :
    // INC, DEC не меняют флаг CF
    (alu_m == alu_inc)  ? {sf8, zf8, f58, hf8, f38, oa8, 1'b0, af[CF]} :
    (alu_m == alu_dec)  ? {sf8, zf8, f58, hf8, f38, os8, 1'b1, af[CF]} :
    // Сдвиговые
    (alu_m == alu_rlca || alu_m == alu_rla) ?
        {af[SF], af[ZF], f58, 1'b0, f38, af[PF], 1'b0, op1[7]} :

    (alu_m == alu_rrca || alu_m == alu_rra) ?
        {af[SF], af[ZF], f58, 1'b0, f38, af[PF], 1'b0, op1[0]} :

    (alu_m == alu_rlc || alu_m == alu_rl || alu_m == alu_sla || alu_m == alu_sll) ?
        {sf8, zf8, f58, 1'b0, f38, pf8, 1'b0, op1[7]} :

    (alu_m == alu_rrc || alu_m == alu_rr || alu_m == alu_sra || alu_m == alu_srl) ?
        {sf8, zf8, f58, 1'b0, f38, pf8, 1'b0, op1[0]} :

    // Специальные
    (alu_m == alu_daa) ? {sf8, zf8, f58, af[4]^daa_2[4], f38, pf8, af[NF], daa_cf} :
    (alu_m == alu_cpl) ? {af[SF], af[ZF], f58, 1'b1,   f38, af[PF], 1'b1, af[CF]} :
    (alu_m == alu_scf) ? {af[SF], af[ZF], f58, 1'b0,   f38, af[PF], 1'b0, 1'b1} :
    (alu_m == alu_ccf) ? {af[SF], af[ZF], f58, af[CF], f38, af[PF], 1'b0, ~af[CF]} :

    // Все остальные
        af[15:8];

// DAA
// -----------------------------------------------------------------------------

wire daa_hf = af[HF] | (af[3:0] > 8'h09);
wire daa_cf = af[CF] | (af[7:0] > 8'h99);

// Первый этап
wire [7:0] daa_1 =
    af[NF] ? (daa_hf ? af[7:0] - 6 : af[7:0]) : // SUB
             (daa_hf ? af[7:0] + 6 : af[7:0]);  // ADD

// Второй этап
wire [7:0] daa_2 =
    af[NF] ? (daa_cf ? daa_1 - 16'h60 : daa_1) : // SUB
             (daa_cf ? daa_1 + 16'h60 : daa_1);  // ADD


// 16-битная операция HL +/- r16
// -----------------------------------------------------------------------------

// Второй операнд для ADD HL, r16
wire [15:0] do_hl_op2 =
    opcode[5:4] == 2'b00 ? bc :
    opcode[5:4] == 2'b01 ? de :
    opcode[5:4] == 2'b10 ? hlx : sp;

// Второй операнд для ADC|SBC HL, r16
wire [16:0] ed_hl_op2 = (
    i_data[5:4] == 2'b00 ? bc :
    i_data[5:4] == 2'b01 ? de :
    i_data[5:4] == 2'b10 ? hl : sp) + af[CF];

// Расчет результата
wire [16:0] do_hl_add = hlx + do_hl_op2;
wire [16:0] ed_hl_adc = hl  + ed_hl_op2;
wire [16:0] ed_hl_sbc = hl  - ed_hl_op2;

// Расстановка флагов
wire [ 7:0] do_hl_flag = {
    af[SF],
    af[ZF],
    do_hl_add[5+8],
    hlx[12]^do_hl_op2[12]^do_hl_add[12], // H
    do_hl_add[3+8],
    af[PF],
    1'b0,           // N=0
    do_hl_add[16]   // C=x
};

// Флаги после сложения HL + r16
wire [ 7:0] hl_adc_flag = {

    ed_hl_adc[15],
    ed_hl_adc[15:0] == 0,
    ed_hl_adc[13],
    ed_hl_adc[12]^hl[12]^ed_hl_op2[12],
    ed_hl_adc[11],
    (hl[15] == ed_hl_op2[15]) && (ed_hl_adc[15] ^ hl[15]),
    1'b0,
    ed_hl_adc[16]
};

// Флаги после вычитания HL - r16
wire [ 7:0] hl_sbc_flag = {

    ed_hl_sbc[15],
    ed_hl_sbc[15:0] == 0,
    ed_hl_sbc[13],
    ed_hl_sbc[12]^hl[12]^ed_hl_op2[12],
    ed_hl_sbc[11],
    (hl[15] ^ ed_hl_op2[15]) && (ed_hl_sbc[15] ^ hl[15]),
    1'b1,
    ed_hl_sbc[16]
};

// RLD|RRD
// -----------------------------------------------------------------------------

wire [7:0] rrd_w = {af[3:0], i_data[7:4]};
wire [7:0] rrd_a = {af[7:4], i_data[3:0]};

wire [7:0] rld_w = {i_data[3:0], af[3:0]};
wire [7:0] rld_a = {af[7:4], i_data[7:4]};

// LDI, CPI, INI, OUTI
// -----------------------------------------------------------------------------

wire [3:0] ldixy = af[7:0] + i_data;
wire [3:0] cpixy = op1 - op2 - alu_f[4];
wire [7:0] b_dec = bc[15:8] - 1;

// BIT
// -----------------------------------------------------------------------------

wire bit_zf = ~op1[ op2[2:0] ];
wire bit_sf = (op2[2:0] == 7) && !bit_zf;

// Не префиксированные BITs устанавливают Y/X флаги
wire [7:0] bit_flags    = {bit_sf, bit_zf, op1[5],  1'b1, op1[3],  bit_zf, 1'b0, af[CF]};
wire [7:0] bit_flags_xx = {bit_sf, bit_zf, af[F5F], 1'b1, af[F3F], bit_zf, 1'b0, af[CF]};

// RES|SET, зависит от op2[3]
// -----------------------------------------------------------------------------

wire [7:0] rsop =
    op2[2:0] == 0 ? {op1[7:1], op2[3]} :
    op2[2:0] == 1 ? {op1[7:2], op2[3], op1[  0]} :
    op2[2:0] == 2 ? {op1[7:3], op2[3], op1[1:0]} :
    op2[2:0] == 3 ? {op1[7:4], op2[3], op1[2:0]} :
    op2[2:0] == 4 ? {op1[7:5], op2[3], op1[3:0]} :
    op2[2:0] == 5 ? {op1[7:6], op2[3], op1[4:0]} :
    op2[2:0] == 6 ? {op1[7],   op2[3], op1[5:0]} :
                   {           op2[3], op1[6:0]};

// Запись в регистры на обратном фронте
// -----------------------------------------------------------------------------

always @(negedge clock)
if (reset_n == 1'b0) begin

    af <= 16'hFFFF;
    sp <= 16'hFFFF;

end
else if (hold) begin

    // Особая запись в регистры
    if (exxw)
    case (exxw)

        // EX AF, AF'
        spec_exaf: begin af <= af_prime; af_prime <= af; end

        // EXX
        spec_exx: begin

            bc_prime <= bc; bc <= bc_prime;
            de_prime <= de; de <= de_prime;
            hl_prime <= hl; hl <= hl_prime;

        end

        // EX DE, HL
        spec_exdehl: begin de <= hl; hl <= de; end

    endcase
    // Работа со строками
    else if (ldcmd)
    case (ldcmd)

        ldcmd_ldi: begin bc <= bc - 1; hl <= hl + 1; de <= de + 1; end
        ldcmd_ldd: begin bc <= bc - 1; hl <= hl - 1; de <= de - 1; end
        ldcmd_cpi: begin bc <= bc - 1; hl <= hl + 1; end
        ldcmd_cpd: begin bc <= bc - 1; hl <= hl - 1; end

    endcase
    // Запись результата в 16-битный регистр
    else if (reg_w16)
    case (reg_id)
        0: bc <= reg_dt;
        1: de <= reg_dt;
        2: case (prefix) 0: hl <= reg_dt; 1: ix <= reg_dt; 2: iy <= reg_dt; endcase
        3: sp <= reg_dt;
    endcase
    // Запись в 8-битный регистр
    else if (reg_w8)
    case (reg_id)
        0: bc[15:8] <= reg_dt;
        1: bc[ 7:0] <= reg_dt;
        2: de[15:8] <= reg_dt;
        3: de[ 7:0] <= reg_dt;
        4: case (prefix) 0: hl[15:8] <= reg_dt; 1: ix[15:8] <= reg_dt; 2: iy[15:8] <= reg_dt; endcase
        5: case (prefix) 0: hl[ 7:0] <= reg_dt; 1: ix[ 7:0] <= reg_dt; 2: iy[ 7:0] <= reg_dt; endcase
        7: af[ 7:0] <= reg_dt;
    endcase

    // Запись флагов из АЛУ
    if      (reg_wfex) af[15:8] <= flag_ex;
    else if (reg_wf)   af[15:8] <= alu_f;

    // Установка следующего префикса
    prefix <= set_prefix;

end

endmodule

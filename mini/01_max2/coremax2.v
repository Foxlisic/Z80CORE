/**
 * Упрощенный медленный процессор для того, чтобы проверить,
 * как он вместится в MAX2
 */
 
module coremax2
(
    input               clock,
    input               locked,
    input               reset_n,
    output      [15:0]  address,
    input       [ 7:0]  in,
    output  reg [ 7:0]  out,
    output  reg         we
);

assign address = bus | we ? {h,l} : pc;

initial begin out = 8'h00; we = 1'b0; end

localparam
    INIT    = 0,
    EXEC    = 1,
    READM   = 2,
    STOPW   = 3;

// Память регистров 96 бит
// ---------------------------------------------------------------------
reg [ 7:0] b = 8'h00; reg [ 7:0] c = 8'h00;
reg [ 7:0] d = 8'h00; reg [ 7:0] e = 8'h00;
reg [ 7:0] h = 8'h00; reg [ 7:0] l = 8'h00;
reg [ 7:0] a = 8'h00; reg [ 7:0] f = 8'b00000000;
reg [15:0] pc = 16'h0000;
reg [15:0] sp = 16'h0000;
// ---------------------------------------------------------------------
reg [ 2:0]  t       = 3'b0;
reg [ 2:0]  m       = 3'b0;
reg [ 7:0]  opcode  = 8'h00;
reg         bus     = 1'b0;
reg [ 7:0]  wb      = 8'h00;
// ---------------------------------------------------------------------

// АЛУ
// ---------------------------------------------------------------------

reg [ 3:0]  alu     = 3'b000;
reg [ 8:0]  alu_r   = 8'h00;
reg [ 7:0]  alu_f   = 8'h00;

wire zero  = alu_r[7:0]==0;            // Zero
wire par   = ~^alu_r[7:0];             // Parity
wire sign  = alu_r[7];                 // Sign
wire carry = alu_r[8];                 // Carry
wire half  = alu_r[4] ^ a[4] ^ wb[4];  // Half-Carry
wire overa = (a[7] == wb[7]) & (a[7] != alu_r[7]);
wire overs = (a[7] != wb[7]) & (a[7] != alu_r[7]);

// Условия для переходов
wire [2:0] condition = {f[7], f[2], f[0], f[6]};

always @* begin

    alu_f = f;

    case (alu)
    0: alu_r = a + wb;          // ADD
    1: alu_r = a + wb + f[0];   // ADC
    2: alu_r = a - wb;          // SUB
    3: alu_r = a - wb - f[0];   // SBC
    4: alu_r = a & wb;          // AND
    5: alu_r = a ^ wb;          // XOR
    6: alu_r = a | wb;          // OR
    7: alu_r = a - wb;          // CP
    endcase

    case (alu)
    //             7     6        5      4        3       2    1        0
    0: alu_f = {sign, zero, alu_r[5], half, alu_r[3], overa, 1'b0, carry}; // ADD
    1: alu_f = {sign, zero, alu_r[5], half, alu_r[3], overa, 1'b0, carry}; // ADC
    2: alu_f = {sign, zero, alu_r[5], half, alu_r[3], overs, 1'b0, carry}; // SUB
    3: alu_f = {sign, zero, alu_r[5], half, alu_r[3], overs, 1'b0, carry}; // SBC
    4: alu_f = {sign, zero, alu_r[5], 1'b1, alu_r[3], par,   1'b0, 1'b0};  // AND
    5: alu_f = {sign, zero, alu_r[5], 1'b0, alu_r[3], par,   1'b0, 1'b0};  // XOR
    6: alu_f = {sign, zero, alu_r[5], 1'b0, alu_r[3], par,   1'b0, 1'b0};  // OR
    7: alu_f = {sign, zero, wb[5],    half,    wb[3], overs, 1'b0, carry}; // CP
    endcase

end

always @(posedge clock)
if (locked)
if (reset_n == 1'b0) begin pc <= 16'h0000; bus <= 1'b0; t <= INIT; end
else case (t)

    // Декодирование опкода
    INIT: begin

        t       <= EXEC;
        m       <= 1'b0;
        opcode  <= in;
        pc      <= pc + 1'b1;    
        alu     <= in[5:3];

        casex (in)

        // SCF|CCF
        8'b0011_0111: f[0] <= 1'b1;
        8'b0011_1111: f[0] <= ~f[0];      

        // DJNZ *
        8'b0001_0000: begin

            if (b == 1) begin pc <= pc + 2; t <= INIT; end
            b <= b - 1;

        end

        // JR NZ,Z,NC,C *
        // Пропуск JR, если не совпало с условием
        8'b001x_x000: begin
        
            if (condition[ in[4] ] == in[3]) begin

                t  <= INIT;
                pc <= pc + 2;
                
            end

        end
        
        // INC HL
        8'b0010_0011: begin {h,l} <= {h,l} + 1; t <= INIT; end

        // JP ccc, **
        8'b11_xxx_010: begin

            if (condition[ in[5:4] ] == in[3]) begin

                t  <= INIT;
                pc <= pc + 3;
                
            end

        end

        // LD  r8, r8
        // ALU A,  r8
        8'b01_xxx_xxx,
        8'b10_xxx_xxx: begin

            case (in[2:0])
            0: wb <= b; 1: wb <= c;
            2: wb <= d; 3: wb <= e;
            4: wb <= h; 5: wb <= l;
            6: begin t <= READM; bus <= 1; end
            7: wb <= a;
            endcase

        end

        // ALU *
        8'b11_xxx_110: begin t <= READM; end

        // JP (HL)
        8'b1110_1001: begin t <= INIT; pc <= {h,l}; end

        // EX DE, HL
        8'b1110_1011: begin t <= INIT; {d,e} <= {h,l}; {h,l} <= {d,e}; end

        endcase

    end

    EXEC: casex (opcode)

        // DJNZ,JR,JR ссс *
        8'b0001_x000,
        8'b001x_x000: begin

            t  <= INIT;
            pc <= pc + {{8{in[7]}}, in} + 1;
        
        end

        // LD r8, *
        8'b00xx_x110: begin

            t <= INIT;

            case (opcode[5:3])
            0: b <= in; 1: c <= in;
            2: d <= in; 3: e <= in;
            4: h <= in; 5: l <= in;
            6: begin t <= STOPW; out <= in; we <= 1; end
            7: a <= in;
            endcase

        end
        
        // LD r8, r8
        8'b01xx_xxxx: begin

            t   <= INIT;
            bus <= 0;

            case (opcode[5:3])
            0: b <= wb; 1: c <= wb;
            2: d <= wb; 3: e <= wb;
            4: h <= wb; 5: l <= wb;
            6: begin t <= STOPW; out <= wb; we <= 1; end
            7: a <= wb;
            endcase                

        end

        // ALU A, reg|imm
        8'b10_xxx_xxx,
        8'b11_xxx_110: begin

            t <= INIT;
            f <= alu_f;

            // Инструкция CP
            if (opcode[5:3] != 3'b111) a <= alu_r;

            // Immediate
            if (opcode[6]) pc <= pc + 1;

        end

        // JP, JP ccc
        8'b11_000_011,
        8'b11_xxx_010: case (m)

            0: begin m <= 1; wb <= in; pc <= pc + 1; end
            1: begin t <= INIT; pc <= {in, wb}; end

        endcase

    endcase

    READM: begin t <= EXEC; wb <= in; end
    STOPW: begin t <= INIT; we <= 0; bus <= 0; end

endcase

endmodule

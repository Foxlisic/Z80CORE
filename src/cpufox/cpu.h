// Макросы для упрощения чтения
#define FetchB read(C->pc++)
#define IncR   C->ir = (C->ir + 1) & 0x7F + (C->ir & 0xFF00);

struct CPU
{
    uint16_t    bc, de, hl, af;
    uint16_t    bc_,de_,hl_,af_;
    uint16_t    pc,sp,ir,ix,iy;
    uint8_t     imode, iff1, iff2;
    char        d; // Для IX+d, IY+d
};

enum CPUFlags {
    CF  = 0x01,
    NF  = 0x02,
    PF  = 0x04,
    F3F = 0x08,
    HF  = 0x10,
    F5F = 0x20,
    ZF  = 0x40,
    SF  = 0x80
};

enum ALUMode
{
    alu_add = 0, alu_rlc =  8, alu_inc = 16, alu_rlca = 24,
    alu_adc = 1, alu_rrc =  9, alu_dec = 17, alu_rrca = 25,
    alu_sub = 2, alu_rl  = 10,               alu_rla  = 26,
    alu_sbc = 3, alu_rr  = 11,               alu_rra  = 27,
    alu_and = 4, alu_sla = 12, alu_daa = 20, alu_bit  = 28,
    alu_xor = 5, alu_sra = 13, alu_cpl = 21, alu_set  = 29,
    alu_or  = 6, alu_sll = 14, alu_scf = 22, alu_res  = 30,
    alu_cp  = 7, alu_srl = 15, alu_ccf = 23
};

enum Mnemonics
{
    NOP  = 0,   LDW     = 1,    LDBCA   = 2,    INCW    = 3,
    INCB = 4,   DECB    = 5,    LDBN    = 6,    RXA     = 7,
    EXAF = 8,   ADDHLW  = 9,    DECW    = 10,   LDABC   = 11,
    DJNZ = 12,  LDADE   = 13,   LDDEA   = 14,   JR      = 15,
    JRC  = 16,  LDNHL   = 17,   LDHLN   = 18,   DAA     = 19,
    CPL  = 20,  SCF     = 21,   CCF     = 22,   LDNA    = 23,
    LDAN = 24,  LD      = 25,   HALT    = 26,   ALU     = 27,
    RETC = 28,  POPW    = 29,   JPC     = 30,   JP      = 31,
    PUSHW = 32, ALUN    = 33,   RST     = 34,   CALLC   = 35,
    RET  = 36,  BITS    = 37,   CALL    = 38,   OUTA    = 39,
    INA  = 40,  IXP     = 41,   IYP     = 42,   MISC    = 43,
    EXX  = 44,  EXSP    = 45,   EXDH    = 46,   DI      = 47,
    EI   = 48,  JPHL    = 49,   LDSP    = 50,
};

// Типы инструкции
static const int cpu_basic[256] = {

//  0       1       2       3       4       5       6       7
//  8       9       A       B       C       D       E       F
    NOP,    LDW,    LDBCA,  INCW,   INCB,   DECB,   LDBN,   RXA,        // 00
    EXAF,   ADDHLW, LDABC,  DECW,   INCB,   DECB,   LDBN,   RXA,        // 08
    DJNZ,   LDW,    LDADE,  INCW,   INCB,   DECB,   LDBN,   RXA,        // 10
    JR,     ADDHLW, LDDEA,  DECW,   INCB,   DECB,   LDBN,   RXA,        // 18
    JRC,    LDW,    LDNHL,  INCW,   INCB,   DECB,   LDBN,   DAA,        // 20
    JRC,    ADDHLW, LDHLN,  DECW,   INCB,   DECB,   LDBN,   CPL,        // 28
    JRC,    LDW,    LDNA,   INCW,   INCB,   DECB,   LDBN,   SCF,        // 30
    JRC,    ADDHLW, LDAN,   INCW,   INCB,   DECB,   LDBN,   CCF,        // 38
    LD,     LD,     LD,     LD,     LD,     LD,     LD,     LD,         // 40
    LD,     LD,     LD,     LD,     LD,     LD,     LD,     LD,         // 48
    LD,     LD,     LD,     LD,     LD,     LD,     LD,     LD,         // 50
    LD,     LD,     LD,     LD,     LD,     LD,     LD,     LD,         // 58
    LD,     LD,     LD,     LD,     LD,     LD,     LD,     LD,         // 60
    LD,     LD,     LD,     LD,     LD,     LD,     LD,     LD,         // 68
    LD,     LD,     LD,     LD,     LD,     LD,     HALT,   LD,         // 70
    LD,     LD,     LD,     LD,     LD,     LD,     LD,     LD,         // 78
    ALU,    ALU,    ALU,    ALU,    ALU,    ALU,    ALU,    ALU,        // 80
    ALU,    ALU,    ALU,    ALU,    ALU,    ALU,    ALU,    ALU,        // 88
    ALU,    ALU,    ALU,    ALU,    ALU,    ALU,    ALU,    ALU,        // 90
    ALU,    ALU,    ALU,    ALU,    ALU,    ALU,    ALU,    ALU,        // 98
    ALU,    ALU,    ALU,    ALU,    ALU,    ALU,    ALU,    ALU,        // A0
    ALU,    ALU,    ALU,    ALU,    ALU,    ALU,    ALU,    ALU,        // A8
    ALU,    ALU,    ALU,    ALU,    ALU,    ALU,    ALU,    ALU,        // B0
    ALU,    ALU,    ALU,    ALU,    ALU,    ALU,    ALU,    ALU,        // B8
    RETC,   POPW,   JPC,    JP,     CALLC,  PUSHW,  ALUN,   RST,        // C0
    RETC,   RET,    JPC,    BITS,   CALLC,  CALL,   ALUN,   RST,        // C8
    RETC,   POPW,   JPC,    OUTA,   CALLC,  PUSHW,  ALUN,   RST,        // D0
    RETC,   EXX,    JPC,    INA,    CALLC,  IXP,    ALUN,   RST,        // D8
    RETC,   POPW,   JPC,    EXSP,   CALLC,  PUSHW,  ALUN,   RST,        // E0
    RETC,   JPHL,   JPC,    EXDH,   CALLC,  MISC,   ALUN,   RST,        // E8
    RETC,   POPW,   JPC,    DI,     CALLC,  PUSHW,  ALUN,   RST,        // F0
    RETC,   LDSP,   JPC,    EI,     CALLC,  IYP,    ALUN,   RST         // F8
};

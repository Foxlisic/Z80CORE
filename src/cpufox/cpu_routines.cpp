// Сохранить 16-битный регистр
void VMX::cpu_put16(int reg_id, uint16_t w)
{
    switch (reg_id & 3) {

        case 0: C->bc = w; break;
        case 1: C->de = w; break;
        case 2:

            if      (prefix == 1) C->ix = w;
            else if (prefix == 2) C->iy = w;
            else                  C->hl = w;
            break;

        case 3: C->sp = w; break;
    }
}

uint16_t VMX::cpu_get16(int reg_id)
{
    switch (reg_id & 3) {

        case 0: return C->bc;
        case 1: return C->de;
        case 2:

            if      (prefix == 1) return C->ix;
            else if (prefix == 2) return C->iy;
            else                  return C->hl;
            break;

        case 3: return C->sp;
    }

    return 0;
}

// cond=0-7
int VMX::cpu_condition(int cond)
{
    switch (cond & 7) {

        case 0: return (C->af & ZF) ? 0 : 1; // NZ
        case 1: return (C->af & ZF) ? 1 : 0; // Z
        case 2: return (C->af & CF) ? 0 : 1;
        case 3: return (C->af & CF) ? 1 : 0;
        case 4: return (C->af & PF) ? 0 : 1;
        case 5: return (C->af & PF) ? 1 : 0;
        case 6: return (C->af & SF) ? 0 : 1;
        case 7: return (C->af & SF) ? 1 : 0;
    }

    return 0;
}

// Получение значения 8 бит из регистра-памяти
uint8_t VMX::cpu_get8(int reg_id)
{
    switch (reg_id & 7)
    {
        case 0: return C->bc >> 8;
        case 1: return C->bc;
        case 2: return C->de >> 8;
        case 3: return C->de;
        case 4:

            if (prefix == 0) return C->hl >> 8;
            if (prefix == 1) return C->ix >> 8;
            if (prefix == 2) return C->iy >> 8;
            break;

        case 5:

            if (prefix == 0) return C->hl;
            if (prefix == 1) return C->ix;
            if (prefix == 2) return C->iy;
            break;

        case 6:

            if (prefix == 0) return read(C->hl);
            if (prefix == 1) return read(C->ix + C->d);
            if (prefix == 2) return read(C->iy + C->d);
            break;

        case 7:

            return C->af >> 8;
    }

    return 0;
}

// Сохранить в регистр или HL, IX+d, IY+d
void VMX::cpu_put8(int reg_id, uint8_t d)
{
    switch (reg_id & 7)
    {
        case 0: C->bc = (C->bc & 0x00FF) | (d << 8); break;
        case 1: C->bc = (C->bc & 0xFF00) | d;        break;
        case 2: C->de = (C->de & 0x00FF) | (d << 8); break;
        case 3: C->de = (C->de & 0xFF00) | d;        break;
        case 4:

            if (prefix == 0) C->hl = (C->hl & 0x00FF) | (d << 8);
            if (prefix == 1) C->ix = (C->ix & 0x00FF) | (d << 8);
            if (prefix == 2) C->iy = (C->ix & 0x00FF) | (d << 8);
            break;

        case 5:

            if (prefix == 0) C->hl = (C->hl & 0xFF00) | d;
            if (prefix == 1) C->ix = (C->ix & 0xFF00) | d;
            if (prefix == 2) C->iy = (C->ix & 0xFF00) | d;
            break;

        case 6:

            if (prefix == 0) write(C->hl, d);
            if (prefix == 1) write(C->ix + C->d, d);
            if (prefix == 2) write(C->iy + C->d, d);
            break;

        case 7:

            C->af = (C->af & 0x00FF) | (d << 8);
            break;
    }
}

// Обновить флаги 5 и 3
void VMX::cpu_update53(uint8_t data)
{
    C->af = (C->af & ~F5F) | (data & F5F);
    C->af = (C->af & ~F3F) | (data & F3F);
}

void VMX::cpu_setsf(uint8_t a)
{
    C->af = (C->af & ~SF) | (a ? SF : 0);
}

void VMX::cpu_setzf(uint8_t a)
{
    C->af = (C->af & ~SF) | (a ? 0 : ZF);
}

void VMX::cpu_setnf(uint8_t a)
{
    C->af = (C->af & ~NF) | (a ? NF : 0);
}

// Overflow flag
void VMX::cpu_setof(uint8_t a)
{
    C->af = (C->af & ~PF) | (a ? PF : 0);
}

// Вычислить Parity и записать
void VMX::cpu_setpf(uint8_t a)
{
    a = (a >> 4) ^ a;
    a = (a >> 2) ^ a;
    a = (a >> 1) ^ a;
    C->af = (C->af & ~PF) | (a & 1 ? 0 : 1);
}

// Set Carry Flag
void VMX::cpu_setcf(uint8_t data)
{
    C->af = (C->af & ~CF) | (data ? CF : 0);
}

// Set Half Carry Flag
void VMX::cpu_sethf(uint8_t data)
{
    C->af = (C->af & ~HF) | (data ? HF : 0);
}

// Вычисление
uint8_t VMX::cpu_alu(int mode, uint8_t a, uint8_t b)
{
    int     c = a;
    int     daa_hf, daa_cf;
    uint8_t daa_1;

    switch (mode)
    {
        case alu_add: c = a + b; break;
        case alu_adc: c = a + b + (C->af & CF); break;
        case alu_sub:
        case alu_cp:  c = a - b; break;
        case alu_sbc: c = a - b - (C->af & CF); break;
        case alu_and: c = a & b; break;
        case alu_xor: c = a ^ b; break;
        case alu_or:  c = a | b; break;
        case alu_rlca:
        case alu_rlc: c = (a << 1) | (a >> 7); break;
        case alu_rrca:
        case alu_rrc: c = (a >> 1) | ((a & 1) << 7); break;
        case alu_rla:
        case alu_rl:  c = (a << 1) | (C->af & CF); break;
        case alu_rra:
        case alu_rr:  c = (a >> 1) | ((C->af & CF) << 7); break;
        case alu_sla: c = a << 1; break;
        case alu_sll: c = (a << 1) | 1; break;
        case alu_sra: c = (a >> 1) | (a & SF); break;
        case alu_srl: c = (a >> 1); break;
        case alu_cpl: c = a ^ 0xFF; break;
        case alu_daa:

            daa_hf = (C->af & HF) || a > 0x09;
            daa_cf = (C->af & CF) || a > 0x99;
            daa_1  = (C->af & NF) ? (daa_hf ? a     - 0x06 : a    ) : (daa_hf ? a     + 0x06 : a    );
            c      = (C->af & NF) ? (daa_cf ? daa_1 - 0x60 : daa_1) : (daa_cf ? daa_1 + 0x60 : daa_1);
            break;
    }

    // Установка флагов
    switch (mode)
    {
        case alu_add:
        case alu_adc:

            cpu_setsf(c);
            cpu_setzf(c);
            cpu_update53(c);
            cpu_sethf(mode == alu_add ? a ^ b ^ c : (a & 15) + (b & 15) + (C->af & CF) >= 0x10);
            cpu_setof((a ^ b ^ 0x80) & (a ^ c) & 0x80);
            cpu_setnf(0);
            cpu_setcf(c >> 8);
            break;

        case alu_sub:
        case alu_sbc:

            cpu_setsf(c);
            cpu_setzf(c);
            cpu_update53(c);
            cpu_sethf(mode == alu_sub ? a ^ b ^ c : (a & 15) - (b & 15) - (C->af & CF) < 0);
            cpu_setof((a ^ b) & (a ^ c) & 0x80);
            cpu_setnf(1);
            cpu_setcf(c >> 8);
            break;

        // Флаги 5 и 3 обновляются из B, а не из результата
        case alu_cp:

            cpu_setsf(c);
            cpu_setzf(c);
            cpu_update53(b);
            cpu_sethf(a ^ b ^ c);
            cpu_setof((a ^ b) & (a ^ c) & 0x80);
            cpu_setnf(1);
            cpu_setcf(c >> 8);
            break;
    }

    return 0;
}


// Исполнение инструкции
int VMX::step(int core_id)
{
    int retry = 0;

    uint8_t  a1, a2;
    uint16_t b1, b2;
    int      c1;

    prefix = 0;

    C = & cpu[core_id];
    C->d = 0;

    int cycles = compat ? 4 : 1;
    uint8_t opcode = FetchB; IncR;

    do {

        switch (cpu_basic[opcode])
        {
            // 1T/4T NOP
            case NOP: break;

            // 1T/4T EX AF, AF'
            case EXAF: {

                a1     = C->af;
                C->af  = C->af_;
                C->af_ = a1;
                break;
            }

            // 1/2T|8/13T
            case DJNZ: {

                a1 = FetchB;
                C->bc -= 0x0100;
                if (C->bc >= 0x100) {
                    C->pc += (char) a1;
                    cycles = compat ? 13 : 2;
                } else {
                    cycles = compat ? 2 : 8;
                }

                break;
            }

            // 2T|12T
            case JR: {

                a1 = FetchB;
                C->pc += (char) a1;
                cycles = compat ? 12 : 2;
                break;
            }

            // 1/2T|12/7T Переход по условию
            case JRC: {

                a1 = FetchB;
                if (cpu_condition(opcode >> 3)) {
                    C->pc += (char) a1;
                    cycles = compat ? 12 : 2;
                } else {
                    cycles = compat ? 7 : 1;
                }

                break;
            }

            // 3T|10T LD Reg16, nn
            case LDW: {

                a1 = FetchB;
                b1 = FetchB*256 + a1;
                cpu_put16(opcode >> 4, b1);
                cycles = compat ? 10 : 3;
                break;
            }

            // 1T/11T ADD HL, x
            case ADDHLW: {

                b1 = cpu_get16(2); // HL
                b2 = cpu_get16(opcode >> 4);
                c1 = b1 + b2;

                cpu_put16(2, c1);

                cpu_update53(c1 >> 8);
                cpu_setcf(c1 >> 16);
                cpu_sethf((b1 ^ b2 ^ c1) & 0x1000);
                cpu_setnf(0);

                cycles = compat ? 11 : 1;
                break;
            }

            // 2T|7T: LD (BC|DE), A :: LD A, (BC|DE)
            case LDBCA: cycles = compat ? 7 : 2; write(C->bc, C->af >> 8); break;
            case LDDEA: cycles = compat ? 7 : 2; write(C->de, C->af >> 8); break;
            case LDABC: cycles = compat ? 7 : 2; cpu_put8(7, read(C->bc)); break;
            case LDADE: cycles = compat ? 7 : 2; cpu_put8(7, read(C->de)); break;

            // 5T|16T: LD (**), HL
            case LDNHL: {

                b1 = FetchB; b1 += 256*FetchB;
                b2 = cpu_get16(2);
                write(b1,   b2);            // L
                write(b1+1, b2>>8);         // H
                cycles = compat ? 16 : 5;
                break;
            }

            // 5T|16T: LD HL, (**)
            case LDHLN: {

                b1 = FetchB; b1 += 256*FetchB;
                cpu_put8(5, read(b1));      // L
                cpu_put8(4, read(b1+1));    // H
                cycles = compat ? 16 : 5;
                break;
            }

            // 4T|13T: LD (**), A
            case LDNA: {

                b1 = FetchB; b1 += 256*FetchB;
                write(b1, C->af >> 8);
                cycles = compat ? 13 : 4;
                break;
            }

            // 4T|13T: LD A, (**)
            case LDAN: {

                b1 = FetchB; b1 += 256*FetchB;
                cpu_put8(7, read(b1));
                cycles = compat ? 13 : 4;
                break;
            }

            // 1T|6T: INC r16
            case INCW: {

                cpu_put16(opcode >> 4, cpu_get16(opcode >> 4) + 1);
                cycles = compat ? 6 : 1;
                break;
            }

            // 1T|6T: DEC r16
            case DECW: {

                cpu_put16(opcode >> 4, cpu_get16(opcode >> 4) - 1);
                cycles = compat ? 6 : 1;
                break;
            }
        }
    }
    // В случае префиксированной инструкции
    while (retry);

    return cycles;
}



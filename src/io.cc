
/*
 * Интерфейс
 */

// 0x0000-0x3fff ROM
// 0x4000-0x7fff BANK 2
// 0x8000-0xbfff BANK 5
// 0xc000-0xffff BANK 0..7

int Z80Spectrum::get_bank(int address) {

    int bank = 0;
    switch (address & 0xc000) {

        case 0x0000: bank = (port_7ffd & 0x30) ? 1 : 0; break;
        case 0x4000: bank = 5; break;
        case 0x8000: bank = 2; break;
        case 0xc000: bank = (port_7ffd & 7); break;
    }

    return bank*16384 + (address & 0x3fff);
}

// Чтение байта
int Z80Spectrum::mem_read(int address) {

    // Обращение к ROM 128k|48k (0 или 16384)
    if (address < 0x4000) {
        return trdos_latch ? trdos[address] : rom[get_bank(address)];
    }

    // Обнаружено чтение из конкурентной памяти
    if (contended_mem && beam_drawing && beam_in_paper && address < 0x8000) { cycle_counter++; }

    return memory[get_bank(address)];
}

// Запись байта
void Z80Spectrum::mem_write(int address, int data) {

    address &= 0xffff;
    if (address < 0x4000) return;

    // Обнаружена запись в конкурентную память
    if (contended_mem && beam_drawing && beam_in_paper && address < 0x8000) { cycle_counter++; }

    memory[get_bank(address)] = data;
}

// Чтение из порта
int Z80Spectrum::io_read(int port) {

    // Управление памятью и режимами
    if (port == 0x7FFD) { return port_7ffd; }
    // SD
    else if ((port & 0xFF) == 0x3F) { return spi_data;  }  // SD Read Data
    else if ((port & 0xFF) == 0x7F) { return sd_status; } // SD: Timeout=0, Busy=0
    // AY
    else if (port == 0xFFFD) { return ay_register; }
    else if (port == 0xBFFD) { return ay_regs[ay_register%15]; }
    // Чтение клавиатуры
    else if ((port & 1) == 0) {

        // Чтение из порта во время движения луча по бордеру
        if (contended_mem && beam_drawing && !beam_in_paper) { cycle_counter++; }

        int result = 0xff;
        for (int row = 0; row < 8; row++) {
            if (!(port & (1 << (row + 8)))) {
                result &= key_states[ row ];
            }
        }
        return result;
    }
    // Kempston Joystick
    else if ((port & 0x00E0) == 0x0000) {
        return 0x00;
    }

    return 0xff;
}

// Запись в порт
void Z80Spectrum::io_write(int port, int data) {

    if (port == 0x7ffd) {

        // Не менять бит D5 если он 1
        if ((port_7ffd & 0x20) && (data & 0x20) == 0)
            data |= 0x20;

        port_7ffd = data;
    }
    // SD DATA SEND/RECV
    else if ((port & 0xFF) == 0x3F) {

        sd_status = 0x00;
        sd_cmd(data);
    }
    // SD COMMAND :: Случай CMD=1, отсылается FFh
    else if ((port & 0xFF) == 0x7F) {

        sd_status = 0x00;
        if ((data & 3) == 1) sd_cmd(0xFF);
    }
    // AY address register
    else if (port == 0xFFFD) { ay_register = data & 15; }
    // AY address data
    else if (port == 0xBFFD) { ay_write_data(data); }
    else if (port == 0x1FFD) { /* ничего пока что */ }
    else if ((port & 1) == 0) {

        // Чтение в порт во время движения луча по бордеру
        if (contended_mem && beam_drawing && !beam_in_paper) { cycle_counter++; }

        border_id = (data & 7);
        port_fe = data;
    }
}

// Проверяется наличие входа и выхода из TRDOS
void Z80Spectrum::trdos_handler() {

    // Only 48k ROM allowed
    if (port_7ffd & 0x10) {

        // Вход в TRDOS : инструкция находится в адресе 3Dh
        if      (!trdos_latch && (pc & 0xff00) == 0x3d00) { trdos_latch = 1; }
        // Выход из TRDOS
        else if ( trdos_latch && (pc & 0xc000))           { trdos_latch = 0; }
    }
}

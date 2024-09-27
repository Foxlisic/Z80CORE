// -----------------------------------------------------------------
// Команда отсылки данных
// -----------------------------------------------------------------

uint8_t Z80Spectrum::sd_cmd(uint8_t data) {

    // printf("D=%02X | S=%d | P=%d\n", data, spi_status, spi_phase);

    switch (spi_status) {

        // IDLE
        case 0:

            // Чтение в 0-м дает последний ответ от команды
            if (data == 0xFF) {

                spi_data = spi_resp;
                spi_resp = 0xFF;
            }
            // Запуск приема команды
            else if ((data & 0xC0) == 0x40) {

                spi_status  = 1;
                spi_command = data & 0x3F;
                spi_arg     = 0;
                spi_phase   = 0;
            }

            break;

        // COMMAND (прием)
        case 1: {

            if (spi_phase < 4) {

                spi_arg = (spi_arg << 8) | data;
                spi_phase++;

            } else {

                spi_phase = 0;
                spi_crc   = data;

                /* Ответ зависит от команды */
                switch (spi_command) {

                    /* CMDxx */
                    case 0:  spi_status = 0; spi_resp = 0x01; break;
                    case 8:  spi_status = 2; spi_resp = 0x00; break;
                    case 13: spi_status = 6; spi_resp = 0x00; break;    // STATUS
                    case 17: spi_status = 4; spi_lba  = spi_arg; break; // BLOCK SEARCH READ
                    case 24: spi_status = 5; spi_lba  = spi_arg; break; // BLOCK SEARCH WRITE
                    case 41: spi_status = 0; spi_resp = 0x00; break;    // READY=0
                    case 55: spi_status = 0; spi_resp = 0x01; break;    // ACMD=1
                    case 58: spi_status = 3; spi_resp = 0x00; break;    // CHECK=0
                    default: spi_status = 0; spi_resp = 0xFF; break;    // Unknown
                }
            }

            break;
        }

        // OCR Read (5 bytes)
        case 2: {

            if (data == 0xFF) {

                if (spi_phase == 4) {
                    spi_data = 0xAA;
                    spi_status = 0;
                } else {
                    spi_data = 0x00;
                }

                spi_phase++;
            }
            else {
                printf("SPI Illegal Write #1"); exit(1);
            }

            break;
        }

        // Информация о SDHC поддержке
        case 3: {

            if (data == 0xFF) {

                if (spi_phase == 0) {
                    spi_data = 0x00;
                } else if (spi_phase == 1) {
                    spi_data = 0xC0;
                } else if (spi_phase < 4) {
                    spi_data = 0xFF;
                } else {
                    spi_data = 0xFF;
                    spi_status = 0;
                }

                spi_phase++;

            } else {
                printf("SPI Illegal Write #2"); exit(1);
            }

            break;
        }

        // Чтение с диска
        case 4: {

            if (spi_phase == 0) {

                spi_data = 0x00;
                spi_file = fopen("sd.img", "ab+");
                if (spi_file == NULL) { printf("Error open file\n"); exit(0); }
                fseek(spi_file, 512 * spi_lba, SEEK_SET);
                (void) fread(spi_sector, 1, 512, spi_file);
                fclose(spi_file);

            } else if (spi_phase == 1) {
                spi_data = 0xFE;
            } else if (spi_phase < 514) {
                spi_data = spi_sector[spi_phase - 2];
            }

            spi_phase++;
            if (spi_phase == 514) {

                spi_status = 0;
                spi_resp   = 0xFF;
            }

            break;
        }

        // Запись на диск
        case 5: {

            if (spi_phase == 0) {
                spi_data = 0x00; // ACK

            } else if (spi_phase == 1) {

                if (data != 0xFE) {
                    printf("Illegal opcode (non FE)\n"); exit(1);
                }

            } else if (spi_phase < 514) {
                spi_sector[spi_phase - 2] = data;

            } else if (spi_phase == 516) {
                spi_data = 0x05; // ACK

            } else if (spi_phase < 520) {
                spi_data = 0xFF;
            }

            spi_phase++;

            // Окончание программирования
            if (spi_phase == 520) {

                spi_status = 0;
                spi_resp   = 0x00;

                // Запись новых данных на диск
                spi_file = fopen("sd.img", "r+b");
                if (spi_file == NULL) { printf("Error open file\n"); exit(0); }
                fseek(spi_file, 512 * spi_lba, SEEK_SET);
                (void) fwrite(spi_sector, 1, 512, spi_file);
                fclose(spi_file);
            }

            break;
        }

        // STATUS [2 Byte 00 00]
        case 6: {

            if (data == 0xFF) {

                if (spi_phase == 1)
                    spi_status = 0;

                spi_data = 0x00;
                spi_phase++;
            }
            else {
                printf("SPI Illegal Write #1"); exit(1);
            }
        }
    }

    return spi_data;
}

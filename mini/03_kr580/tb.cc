#include "app.cc"

void App::init() {

    mod_cpu->pin_rstn = 1;
}

// Один такт
void App::tick() {

    // Обработка событий клавиатуры
    kbd_pop(ps_clock, ps_data);

    mod_ps2->ps_clock = ps_clock;
    mod_ps2->ps_data  = ps_data;

    // Запись в порт
    if (mod_ps2->done) {

        ps_key3    = ps_key2;
        ps_key2    = ps_key1;
        ps_key1    = ps_key0;
        ps_key0    = mod_ps2->data;
        ps_latch   = (ps_latch + 1) & 3;
    }

    // Обработка ввода-вывода процессора
    if (mod_cpu->pin_enw) mem[mod_cpu->pin_a] = mod_cpu->pin_o;

    mod_cpu->pin_i = mem[mod_cpu->pin_a];

    // Вызов прерывания на VSync
    mod_cpu->pin_intr = mod_text->vs;

    // Для отладки
    if (debug_fp) fprintf(debug_fp, "%04x [%02x] o=%02x %c\n", mod_cpu->pin_a, mem[mod_cpu->pin_a], mod_cpu->pin_o, mod_cpu->pin_enw ? 'w' : ' ');

    // Считывание из портов
    switch (mod_cpu->pin_pa & 255) {

        case 0: mod_cpu->pin_pi = ps_key0;  break;
        case 1: mod_cpu->pin_pi = ps_key1;  break;
        case 2: mod_cpu->pin_pi = ps_key2;  break;
        case 3: mod_cpu->pin_pi = ps_key3;  break;
        case 4: mod_cpu->pin_pi = cursor_x; break;
        case 5: mod_cpu->pin_pi = cursor_y; break;

        // STATUS kbd, SPI
        case 6: mod_cpu->pin_pi = sd_in;    break;
        case 7: mod_cpu->pin_pi = (ps_latch & 3) | (sd_timeout ? 0x40 : 0); break;
    }

    if (mod_cpu->pin_pw) {

        switch (mod_cpu->pin_pa & 255) {

            // Положение курсора
            case 4: cursor_x = mod_cpu->pin_po; mod_text->cursor = cursor_x + cursor_y*80; break;
            case 5: cursor_y = mod_cpu->pin_po; mod_text->cursor = cursor_x + cursor_y*80; break;

            // SD-Card
            case 6: sd_out = mod_cpu->pin_po; break;
            case 7: sd_cmd = mod_cpu->pin_po & 3; sdcard(); break;
        }
    }

    // Здесь находится видеопамять
    mod_text->data = mem[mod_text->address + 0xE000];

    mod_ps2->clock = 0; mod_ps2->eval();
    mod_ps2->clock = 1; mod_ps2->eval();

    mod_cpu->pin_clk = 0; mod_cpu->eval();
    mod_cpu->pin_clk = 1; mod_cpu->eval();

    mod_text->clock = 0; mod_text->eval();
    mod_text->clock = 1; mod_text->eval();

    vga(mod_text->hs, mod_text->vs, (mod_text->r*16)*65536 + (mod_text->g*16)*256 + (mod_text->b*16));
}

int main(int argc, char** argv) {

    int   instr   = 125000;
    int   maximum = 0;
    float target  = 100;

    Verilated::commandArgs(argc, argv);
    App* app = new App(argc, argv);

    while (app->main()) {
        app->exec();
    }

    return app->destroy();
}

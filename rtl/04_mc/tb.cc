#include "obj_dir/Vga.h"
#include "obj_dir/Vz80.h"

#include "tb.h"

void App::init() {

    memory = (uint8_t*) malloc(65536);

    for (int i = 0; i < 65536; i++) memory[i] = 0x00;
    for (int i = 0; i < 2048; i++) {

        memory[0xF000 + i] = (i < 1024 ? i & 255 : 0x01);
        memory[0xF800 + i] = font8x8[i];
    }

    z80->reset_n = 1;
    z80->compat  = 0;
    z80->hold    = 1;
    z80->irq     = 0;
}

void App::load(int argc, char* argv[]) {

    if (argc > 1) {

        // Открыть файл и загрузить ROM
        FILE* fp = fopen(argv[1], "rb");
        if (fp) {

            fread(memory, 1, 65536, fp);
            fclose(fp);
        }
    }
}

// Код фрейма
void App::frame() {

    Uint32 ticks = SDL_GetTicks();

    // Коррекция тактов для получения 50 кадров в секунду
    for (int i = 0; i < tframe; i++) {

        int A = z80->address;

        z80->i_data = memory[ A ];
        if (z80->we) memory[ A ] = z80->o_data;
        if (z80->portwe) {
printf("%d ", A & 255);
            switch (A & 255) {

                // Параметры скроллинга
                case 0x01: vga->xs = z80->o_data; break;
                case 0x03: vga->ys = z80->o_data; break;
            }
        }

        z80->clock = 0; z80->eval();
        z80->clock = 1; z80->eval();

        vga->data = memory[0xF000 + vga->address];

        vga->clock = 0; vga->eval();
        vga->clock = 1; vga->eval();

        dsub(vga->hs, vga->vs, 65536*(vga->r*16) + 256*(vga->g*16) + vga->b*16);
    }

    // Автоматическая коррекция тактов
    int delay = SDL_GetTicks() - ticks;
    if (delay > 20) { tframe = (tframe * 20 / delay); }
}

int main(int argc, char* argv[]) {

    App* app = new App();   // Создать окно приложения

    app->load(argc, argv);

    while (app->main());    // Выполнение цикла каждые 1/50 сек
    return app->destroy();  // Закрыть окно
}

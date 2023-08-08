#define SDL_MAIN_HANDLED

#include <SDL2/SDL.h>
#include <stdlib.h>
#include <stdio.h>

class ZXSpectrum {
protected:

    SDL_Window*         sdl_window;
    SDL_Renderer*       sdl_renderer;
    SDL_Texture*        sdl_screen_texture;
    Uint32*             screen_buffer;

    Uint32  width, height, _scale, _width, _height;
    Uint32  frame_id;
    Uint32  frame_length;
    Uint32  frame_prev_ticks;

    int     x, y, _hs, _vs;

    unsigned char* mem128;
    unsigned char* roms;
    unsigned char kbd[256];

    // Модули
    Vz80*       mod_z80;
    Vula*       mod_ula;
    Vmmap*      mod_mmap;
    Vps2*       mod_ps2;
    Vkbd*       mod_kbd;

    int ps_clock = 0, ps_data = 0, kbd_phase = 0, kbd_ticker = 0, kbd_top = 0;

public:

    int irq = 0;

    void init() {

        mod_z80     = new Vz80();
        mod_ula     = new Vula();
        mod_mmap    = new Vmmap();
        mod_ps2     = new Vps2();
        mod_kbd     = new Vkbd();

        mem128  = (unsigned char*) malloc(128*1024);
        roms    = (unsigned char*) malloc(64*1024);

        FILE* fp;

        // Загрузка ROM (128,48,TRDOS)
        if (fp = fopen("basic128.rom", "rb")) { fread(roms+0,     1, 16384, fp); fclose(fp); }
        if (fp = fopen("basic48.rom", "rb"))  { fread(roms+16384, 1, 16384, fp); fclose(fp); }
        if (fp = fopen("trdos.rom", "rb"))    { fread(roms+32768, 1, 16384, fp); fclose(fp); }

        // Сброс процессора
        mod_z80->reset_n = 0;
        mod_z80->clock   = 0; mod_z80->eval();
        mod_z80->clock   = 1; mod_z80->eval();
        mod_z80->reset_n = 1;
        mod_z80->compat  = 1;
        mod_z80->hold    = 1;
        mod_z80->irq     = 0;

        // Сброс Memory Mapper
        mod_mmap->reset_n = 0;
        mod_mmap->clock   = 0; mod_mmap->eval();
        mod_mmap->clock   = 1; mod_mmap->eval();
        mod_mmap->reset_n = 1;
        mod_mmap->hold    = 1;

        // Сброс Memory Mapper
        mod_kbd->reset_n  = 0;
        mod_kbd->clock_50 = 0; mod_kbd->eval();
        mod_kbd->clock_50 = 1; mod_kbd->eval();
        mod_kbd->reset_n  = 1;

        // По умолчанию
        mod_mmap->kbd    = 255;
        mod_mmap->mic    = 1;
        mod_mmap->inreg  = 255;
        mod_mmap->klatch = 0;
    }

    // Основной обработчик (TOP-уровень)
    void tick(int id) {

        // Обработка событий клавиатуры
        kbd_pop(ps_clock, ps_data);

        // Контроллер PS/2
        mod_ps2->ps_clock = ps_clock;
        mod_ps2->ps_data = ps_data;

        // Установить
        mod_mmap->address = mod_z80->address;
        mod_mmap->o_data  = mod_z80->o_data;
        mod_mmap->m0      = mod_z80->m0;
        mod_mmap->we      = mod_z80->we;
        mod_mmap->portwe  = mod_z80->portwe;

        // Такт контроллера памяти
        mod_mmap->clock = 0; mod_mmap->eval();
        mod_mmap->clock = 1; mod_mmap->eval();

        // Запись в память после выполнения такта
        if (mod_mmap->ram_we) mem128[ mod_mmap->ram_address ] = mod_z80->o_data;

        // Ввод-вывод в память
        mod_mmap->rom_idata = roms[ (mod_mmap->rom_address & 0x7FFF) ];
        mod_mmap->rom_trdos = roms[ (mod_mmap->rom_address & 0x3FFF) + 0x8000 ];
        mod_mmap->ram_idata = mem128[ mod_mmap->ram_address ];

        // Присвоение внешних данных
        mod_kbd->A       = mod_mmap->address;
        mod_kbd->ps2data = mod_ps2->data;
        mod_kbd->ps2hit  = mod_ps2->done;

        // Выполнить такт именно здесь
        mod_kbd->clock_50 = 0; mod_kbd->eval();
        mod_kbd->clock_50 = 1; mod_kbd->eval();

        // Чтобы получить результаты в memmap модуле
        mod_mmap->kbd    = mod_kbd->D;
        mod_mmap->inreg  = mod_kbd->inreg;
        mod_mmap->klatch = mod_kbd->klatch;

        // Обновить данные из контроллера к Z80
        mod_mmap->eval();

        // Роутер памяти
        mod_z80->i_data   = mod_mmap->i_data;
        mod_z80->portin   = mod_mmap->portin;

        // Отдельная логика по IRQ здесь
        mod_z80->irq      = id > 70000;

        // Видеоадаптер
        mod_ula->border = mod_mmap->border;
        mod_ula->vdata  = mem128[ 0x14000 | (mod_mmap->vidpage*0x8000) | (mod_ula->vaddr & 0x1FFF) ];

        // Исполнение одного такта
        mod_z80->clock = 0; mod_z80->eval();
        mod_z80->clock = 1; mod_z80->eval();

        mod_ula->clock = 0; mod_ula->eval();
        mod_ula->clock = 1; mod_ula->eval();

        // Keyb
        mod_ps2->clock      = 0; mod_ps2->eval();
        mod_ps2->clock      = 1; mod_ps2->eval();

        vga(mod_ula->HS, mod_ula->VS, 65536*(mod_ula->VGA_R*16) + 256*(mod_ula->VGA_G*16) + (mod_ula->VGA_B*16));
    }

    // -----------------------------------------------------------------------------
    // ОБЩИЕ МЕТОДЫ
    // -----------------------------------------------------------------------------

    ZXSpectrum(int w, int h, int scale = 2, int fps = 25) {

        _scale   = scale;
        _width   = w; width  = w * scale;
        _height  = h; height = h * scale;
        frame_id = 0;
        ps_clock = 1;
        mem128   = NULL;

        _hs = 1; _vs = 0; x = 0; y = 0;

        if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO)) {
            exit(1);
        }

        SDL_ClearError();
        sdl_window          = SDL_CreateWindow("ZX Spectrum 128K", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, width, height, SDL_WINDOW_SHOWN);
        sdl_renderer        = SDL_CreateRenderer(sdl_window, -1, SDL_RENDERER_PRESENTVSYNC);
        screen_buffer       = (Uint32*) malloc(w * h * sizeof(Uint32));
        sdl_screen_texture  = SDL_CreateTexture(sdl_renderer, SDL_PIXELFORMAT_BGRA32, SDL_TEXTUREACCESS_STREAMING, w, h);
        SDL_SetTextureBlendMode(sdl_screen_texture, SDL_BLENDMODE_NONE);

        // Настройка FPS
        frame_length     = 1000 / (fps ? fps : 1);
        frame_prev_ticks = SDL_GetTicks();

        FILE* fp = fopen("out/record.ppm", "w");
        if (fp) fclose(fp);

        init();
    }

    // Ожидание событий
    int main() {

        SDL_Event evt;

        for (;;) {

            Uint32 ticks = SDL_GetTicks();

            // Ожидать наступления события
            while (SDL_PollEvent(& evt)) {

                switch (evt.type) {

                    // Выход из программы по нажатии "крестика"
                    case SDL_QUIT: {
                        return 0;
                    }

                    // https://wiki.machinesdl.org/SDL_Scancode

                    // Нажатие на клавишу
                    case SDL_KEYDOWN: kbd_scancode(evt.key.keysym.scancode, 0); break;
                    case SDL_KEYUP:   kbd_scancode(evt.key.keysym.scancode, 1); break;
                }
            }

            // Истечение таймаута: обновление экрана
            if (ticks - frame_prev_ticks >= frame_length) {

                frame_prev_ticks = ticks;
                update();
                return 1;
            }

            SDL_Delay(1);
        }
    }

    // Обновить окно
    void update() {

        SDL_Rect dstRect;

        dstRect.x = 0;
        dstRect.y = 0;
        dstRect.w = width;
        dstRect.h = height;

        SDL_UpdateTexture       (sdl_screen_texture, NULL, screen_buffer, _width * sizeof(Uint32));
        SDL_SetRenderDrawColor  (sdl_renderer, 0, 0, 0, 0);
        SDL_RenderClear         (sdl_renderer);
        SDL_RenderCopy          (sdl_renderer, sdl_screen_texture, NULL, &dstRect);
        SDL_RenderPresent       (sdl_renderer);
    }

    // Уничтожение окна
    int destroy() {

        if (sdl_screen_texture) { SDL_DestroyTexture(sdl_screen_texture);   sdl_screen_texture  = NULL; }
        if (sdl_renderer)       { SDL_DestroyRenderer(sdl_renderer);        sdl_renderer        = NULL; }

        free(screen_buffer);
        if (mem128) free(mem128);

        SDL_DestroyWindow(sdl_window);
        SDL_Quit();

        return 0;
    }

    // -----------------------------------------------------------------------------
    // ФУНКЦИИ РИСОВАНИЯ
    // -----------------------------------------------------------------------------

    // Установка точки
    void pset(int x, int y, Uint32 cl) {

        if (x < 0 || y < 0 || x >= _width || y >= _height)
            return;

        screen_buffer[y*_width + x] = cl;
    }

    // Отслеживание сигнала RGB по HS/VS; save=1 сохранить фрейм как ppm, 2=как png
    void vga(int hs, int vs, int color) {

        if (hs == 0) x++;

        // Отслеживание изменений HS/VS
        if (_hs == 1 && hs == 0) { x = 0; y++; }
        if (_vs == 1 && vs == 0) { x = 0; y = 0; saveframe(); }

        // Сохранить предыдущее значение
        _hs = hs;
        _vs = vs;

        // Вывод на экран
        pset(x - 48, y - 35, color);
    }

    // Сохранение фрейма
    void saveframe() {

        char fn[256];

        FILE* fp = fopen("out/record.ppm", "ab");
        if (fp) {

            fprintf(fp, "P6\n# Verilator\n%d %d\n255\n", _width, _height);
            for (int y = 0; y < _height; y++)
            for (int x = 0; x < _width; x++) {

                int cl = screen_buffer[y*_width + x];
                int vl = ((cl >> 16) & 255) + (cl & 0xFF00) + ((cl&255)<<16);
                fwrite(&vl, 1, 3, fp);
            }

            fclose(fp);
        }

        frame_id++;
    }

    // -----------------------------------------------------------------------------
    // РАБОТА С КЛАВИАТУРОЙ
    // -----------------------------------------------------------------------------

    // Сканирование нажатой клавиши
    // https://ru.wikipedia.org/wiki/Скан-код
    void kbd_scancode(int scancode, int release) {

        switch (scancode) {

            // Коды клавиш A-Z
            case SDL_SCANCODE_A: if (release) kbd_push(0xF0); kbd_push(0x1C); break;
            case SDL_SCANCODE_B: if (release) kbd_push(0xF0); kbd_push(0x32); break;
            case SDL_SCANCODE_C: if (release) kbd_push(0xF0); kbd_push(0x21); break;
            case SDL_SCANCODE_D: if (release) kbd_push(0xF0); kbd_push(0x23); break;
            case SDL_SCANCODE_E: if (release) kbd_push(0xF0); kbd_push(0x24); break;
            case SDL_SCANCODE_F: if (release) kbd_push(0xF0); kbd_push(0x2B); break;
            case SDL_SCANCODE_G: if (release) kbd_push(0xF0); kbd_push(0x34); break;
            case SDL_SCANCODE_H: if (release) kbd_push(0xF0); kbd_push(0x33); break;
            case SDL_SCANCODE_I: if (release) kbd_push(0xF0); kbd_push(0x43); break;
            case SDL_SCANCODE_J: if (release) kbd_push(0xF0); kbd_push(0x3B); break;
            case SDL_SCANCODE_K: if (release) kbd_push(0xF0); kbd_push(0x42); break;
            case SDL_SCANCODE_L: if (release) kbd_push(0xF0); kbd_push(0x4B); break;
            case SDL_SCANCODE_M: if (release) kbd_push(0xF0); kbd_push(0x3A); break;
            case SDL_SCANCODE_N: if (release) kbd_push(0xF0); kbd_push(0x31); break;
            case SDL_SCANCODE_O: if (release) kbd_push(0xF0); kbd_push(0x44); break;
            case SDL_SCANCODE_P: if (release) kbd_push(0xF0); kbd_push(0x4D); break;
            case SDL_SCANCODE_Q: if (release) kbd_push(0xF0); kbd_push(0x15); break;
            case SDL_SCANCODE_R: if (release) kbd_push(0xF0); kbd_push(0x2D); break;
            case SDL_SCANCODE_S: if (release) kbd_push(0xF0); kbd_push(0x1B); break;
            case SDL_SCANCODE_T: if (release) kbd_push(0xF0); kbd_push(0x2C); break;
            case SDL_SCANCODE_U: if (release) kbd_push(0xF0); kbd_push(0x3C); break;
            case SDL_SCANCODE_V: if (release) kbd_push(0xF0); kbd_push(0x2A); break;
            case SDL_SCANCODE_W: if (release) kbd_push(0xF0); kbd_push(0x1D); break;
            case SDL_SCANCODE_X: if (release) kbd_push(0xF0); kbd_push(0x22); break;
            case SDL_SCANCODE_Y: if (release) kbd_push(0xF0); kbd_push(0x35); break;
            case SDL_SCANCODE_Z: if (release) kbd_push(0xF0); kbd_push(0x1A); break;

            // Цифры
            case SDL_SCANCODE_0: if (release) kbd_push(0xF0); kbd_push(0x45); break;
            case SDL_SCANCODE_1: if (release) kbd_push(0xF0); kbd_push(0x16); break;
            case SDL_SCANCODE_2: if (release) kbd_push(0xF0); kbd_push(0x1E); break;
            case SDL_SCANCODE_3: if (release) kbd_push(0xF0); kbd_push(0x26); break;
            case SDL_SCANCODE_4: if (release) kbd_push(0xF0); kbd_push(0x25); break;
            case SDL_SCANCODE_5: if (release) kbd_push(0xF0); kbd_push(0x2E); break;
            case SDL_SCANCODE_6: if (release) kbd_push(0xF0); kbd_push(0x36); break;
            case SDL_SCANCODE_7: if (release) kbd_push(0xF0); kbd_push(0x3D); break;
            case SDL_SCANCODE_8: if (release) kbd_push(0xF0); kbd_push(0x3E); break;
            case SDL_SCANCODE_9: if (release) kbd_push(0xF0); kbd_push(0x46); break;

            // Keypad
            case SDL_SCANCODE_KP_0: if (release) kbd_push(0xF0); kbd_push(0x70); break;
            case SDL_SCANCODE_KP_1: if (release) kbd_push(0xF0); kbd_push(0x69); break;
            case SDL_SCANCODE_KP_2: if (release) kbd_push(0xF0); kbd_push(0x72); break;
            case SDL_SCANCODE_KP_3: if (release) kbd_push(0xF0); kbd_push(0x7A); break;
            case SDL_SCANCODE_KP_4: if (release) kbd_push(0xF0); kbd_push(0x6B); break;
            case SDL_SCANCODE_KP_5: if (release) kbd_push(0xF0); kbd_push(0x73); break;
            case SDL_SCANCODE_KP_6: if (release) kbd_push(0xF0); kbd_push(0x74); break;
            case SDL_SCANCODE_KP_7: if (release) kbd_push(0xF0); kbd_push(0x6C); break;
            case SDL_SCANCODE_KP_8: if (release) kbd_push(0xF0); kbd_push(0x75); break;
            case SDL_SCANCODE_KP_9: if (release) kbd_push(0xF0); kbd_push(0x7D); break;

            // Специальные символы
            case SDL_SCANCODE_GRAVE:        if (release) kbd_push(0xF0); kbd_push(0x0E); break;
            case SDL_SCANCODE_MINUS:        if (release) kbd_push(0xF0); kbd_push(0x4E); break;
            case SDL_SCANCODE_EQUALS:       if (release) kbd_push(0xF0); kbd_push(0x55); break;
            case SDL_SCANCODE_BACKSLASH:    if (release) kbd_push(0xF0); kbd_push(0x5D); break;
            case SDL_SCANCODE_LEFTBRACKET:  if (release) kbd_push(0xF0); kbd_push(0x54); break;
            case SDL_SCANCODE_RIGHTBRACKET: if (release) kbd_push(0xF0); kbd_push(0x5B); break;
            case SDL_SCANCODE_SEMICOLON:    if (release) kbd_push(0xF0); kbd_push(0x4C); break;
            case SDL_SCANCODE_APOSTROPHE:   if (release) kbd_push(0xF0); kbd_push(0x52); break;
            case SDL_SCANCODE_COMMA:        if (release) kbd_push(0xF0); kbd_push(0x41); break;
            case SDL_SCANCODE_PERIOD:       if (release) kbd_push(0xF0); kbd_push(0x49); break;
            case SDL_SCANCODE_SLASH:        if (release) kbd_push(0xF0); kbd_push(0x4A); break;
            case SDL_SCANCODE_BACKSPACE:    if (release) kbd_push(0xF0); kbd_push(0x66); break;
            case SDL_SCANCODE_SPACE:        if (release) kbd_push(0xF0); kbd_push(0x29); break;
            case SDL_SCANCODE_TAB:          if (release) kbd_push(0xF0); kbd_push(0x0D); break;
            case SDL_SCANCODE_CAPSLOCK:     if (release) kbd_push(0xF0); kbd_push(0x58); break;
            case SDL_SCANCODE_LSHIFT:       if (release) kbd_push(0xF0); kbd_push(0x12); break;
            case SDL_SCANCODE_LCTRL:        if (release) kbd_push(0xF0); kbd_push(0x14); break;
            case SDL_SCANCODE_LALT:         if (release) kbd_push(0xF0); kbd_push(0x11); break;
            case SDL_SCANCODE_RSHIFT:       if (release) kbd_push(0xF0); kbd_push(0x59); break;
            case SDL_SCANCODE_RETURN:       if (release) kbd_push(0xF0); kbd_push(0x5A); break;
            case SDL_SCANCODE_ESCAPE:       if (release) kbd_push(0xF0); kbd_push(0x76); break;
            case SDL_SCANCODE_NUMLOCKCLEAR: if (release) kbd_push(0xF0); kbd_push(0x77); break;
            case SDL_SCANCODE_KP_MULTIPLY:  if (release) kbd_push(0xF0); kbd_push(0x7C); break;
            case SDL_SCANCODE_KP_MINUS:     if (release) kbd_push(0xF0); kbd_push(0x7B); break;
            case SDL_SCANCODE_KP_PLUS:      if (release) kbd_push(0xF0); kbd_push(0x79); break;
            case SDL_SCANCODE_KP_PERIOD:    if (release) kbd_push(0xF0); kbd_push(0x71); break;
            case SDL_SCANCODE_SCROLLLOCK:   if (release) kbd_push(0xF0); kbd_push(0x7E); break;

            // F1-F12 Клавиши
            case SDL_SCANCODE_F1:   if (release) kbd_push(0xF0); kbd_push(0x05); break;
            case SDL_SCANCODE_F2:   if (release) kbd_push(0xF0); kbd_push(0x06); break;
            case SDL_SCANCODE_F3:   if (release) kbd_push(0xF0); kbd_push(0x04); break;
            case SDL_SCANCODE_F4:   if (release) kbd_push(0xF0); kbd_push(0x0C); break;
            case SDL_SCANCODE_F5:   if (release) kbd_push(0xF0); kbd_push(0x03); break;
            case SDL_SCANCODE_F6:   if (release) kbd_push(0xF0); kbd_push(0x0B); break;
            case SDL_SCANCODE_F7:   if (release) kbd_push(0xF0); kbd_push(0x83); break;
            case SDL_SCANCODE_F8:   if (release) kbd_push(0xF0); kbd_push(0x0A); break;
            case SDL_SCANCODE_F9:   if (release) kbd_push(0xF0); kbd_push(0x01); break;
            case SDL_SCANCODE_F10:  if (release) kbd_push(0xF0); kbd_push(0x09); break;
            case SDL_SCANCODE_F11:  if (release) kbd_push(0xF0); kbd_push(0x78); break;
            case SDL_SCANCODE_F12:  if (release) kbd_push(0xF0); kbd_push(0x07); break;

            // Расширенные клавиши
            case SDL_SCANCODE_LGUI:         kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x1F); break;
            case SDL_SCANCODE_RGUI:         kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x27); break;
            case SDL_SCANCODE_APPLICATION:  kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x2F); break;
            case SDL_SCANCODE_RCTRL:        kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x14); break;
            case SDL_SCANCODE_RALT:         kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x11); break;
            case SDL_SCANCODE_KP_DIVIDE:    kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x4A); break;
            case SDL_SCANCODE_KP_ENTER:     kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x5A); break;

            case SDL_SCANCODE_INSERT:       kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x70); break;
            case SDL_SCANCODE_HOME:         kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x6C); break;
            case SDL_SCANCODE_END:          kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x69); break;
            case SDL_SCANCODE_PAGEUP:       kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x7D); break;
            case SDL_SCANCODE_PAGEDOWN:     kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x7A); break;
            case SDL_SCANCODE_DELETE:       kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x71); break;

            case SDL_SCANCODE_UP:           kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x75); break;
            case SDL_SCANCODE_DOWN:         kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x72); break;
            case SDL_SCANCODE_LEFT:         kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x6B); break;
            case SDL_SCANCODE_RIGHT:        kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x74); break;

            // Клавиша PrnScr
            case SDL_SCANCODE_PRINTSCREEN: {

                if (release == 0) {

                    kbd_push(0xE0); kbd_push(0x12);
                    kbd_push(0xE0); kbd_push(0x7C);

                } else {

                    kbd_push(0xE0); kbd_push(0xF0); kbd_push(0x7C);
                    kbd_push(0xE0); kbd_push(0xF0); kbd_push(0x12);
                }

                break;
            }

            // Клавиша Pause
            case SDL_SCANCODE_PAUSE: {

                kbd_push(0xE1);
                kbd_push(0x14); if (release) kbd_push(0xF0); kbd_push(0x77);
                kbd_push(0x14); if (release) kbd_push(0xF0); kbd_push(0x77);
                break;
            }
        }
    }

    // Нажатие на клавишу
    void kbd_push(int data) {

        if (kbd_top >= 255) return;
        kbd[kbd_top] = data;
        kbd_top++;
    }

    // Извлечение PS/2
    void kbd_pop(int& ps_clock, int& ps_data) {

        // В очереди нет клавиш для нажатия
        if (kbd_top == 0) return;

        // 25000000/2000 = 12.5 kHz Очередной полутакт для PS/2
        if (++kbd_ticker >= 2000) {

            ps_clock = kbd_phase & 1;

            switch (kbd_phase) {

                // Старт-бит [=0]
                case 0: case 1: ps_data = 0; break;

                // Бит четности
                case 18: case 19:

                    ps_data = 1;
                    for (int i = 0; i < 8; i++)
                        ps_data ^= !!(kbd[0] & (1 << i));

                    break;

                // Стоп-бит [=1]
                case 20: case 21: ps_data = 1; break;

                // Небольшая задержка между нажатиями клавиш
                case 22: case 23:
                case 24: case 25:

                    ps_clock = 1;
                    ps_data  = 1;
                    break;

                // Завершение
                case 26:

                    // Удалить символ из буфера
                    for (int i = 0; i < kbd_top - 1; i++)
                        kbd[i] = kbd[i+1];

                    kbd_top--;
                    kbd_phase = -1;
                    ps_clock  = 1;
                    break;

                // Отсчет битов от 0 до 7
                // 0=2,3   | 1=4,5   | 2=6,7   | 3=8,9
                // 4=10,11 | 5=12,13 | 6=14,15 | 7=16,17
                default:

                    ps_data = !!(kbd[0] & (1 << ((kbd_phase >> 1) - 1)));
                    break;
            }

            kbd_ticker = 0;
            kbd_phase++;
        }
    }

};

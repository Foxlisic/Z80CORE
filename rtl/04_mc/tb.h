#include <SDL2/SDL.h>
#include <stdlib.h>
#include <stdio.h>

#include "font.h"

class App {
protected:

    SDL_Window*         sdl_window;
    SDL_Renderer*       sdl_renderer;
    SDL_Texture*        sdl_screen_texture;
    Uint32*             screen_buffer;

    int  pticks = 0;
    int  _hs = 1, _vs = 0, x = 0, y = 0;
    int  tframe = 100000;

    uint8_t* memory;

    Vga*  vga;
    Vz80* z80;

public:

    App() {

        if (SDL_Init(SDL_INIT_VIDEO)) {
            exit(1);
        }

        screen_buffer = (Uint32*) malloc(640 * 400 * sizeof(Uint32));
        sdl_window    = SDL_CreateWindow("M80", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 2*640, 2*400, SDL_WINDOW_SHOWN);
        sdl_renderer  = SDL_CreateRenderer(sdl_window, -1, SDL_RENDERER_PRESENTVSYNC);
        sdl_screen_texture  = SDL_CreateTexture(sdl_renderer, SDL_PIXELFORMAT_BGRA32, SDL_TEXTUREACCESS_STREAMING, 640, 400);
        SDL_SetTextureBlendMode(sdl_screen_texture, SDL_BLENDMODE_NONE);

        vga = new Vga;
        z80 = new Vz80;

        init();
    }

    // Реализация
    void init();
    void frame();
    void load(int, char**);

    // Ожидание событий
    int main() {

        SDL_Event evt;

        for (;;) {

            Uint32 ticks = SDL_GetTicks();

            // Обработать все новые события
            while (SDL_PollEvent(& evt)) {

                switch (evt.type) {

                    // Выход из программы
                    case SDL_QUIT: return 0;
                }
            }

            // Истечение таймаута: обновление экрана
            if (ticks - pticks >= 20) {

                pticks = ticks;

                frame();   // Вызов обработчика кадра
                update();  // Вызов обновления экрана

                return 1;
            }

            SDL_Delay(1);
        }
    }

    // Обновить экран
    void update() {

        SDL_Rect dstRect;

        dstRect.x = 0;
        dstRect.y = 0;
        dstRect.w = 1280;
        dstRect.h = 800;

        SDL_UpdateTexture       (sdl_screen_texture, NULL, screen_buffer, 640 * sizeof(Uint32));
        SDL_SetRenderDrawColor  (sdl_renderer, 0, 0, 0, 0);
        SDL_RenderClear         (sdl_renderer);
        SDL_RenderCopy          (sdl_renderer, sdl_screen_texture, NULL, &dstRect);
        SDL_RenderPresent       (sdl_renderer);
    }

    // Установка точки
    void pset(int x, int y, Uint32 color) {

        if (x < 0 || y < 0 || x > 640 || y >= 400)
            return;

        screen_buffer[y*640 + x] = color;
    }

    // Рендеринг области VGA рисования
    void dsub(int hs, int vs, uint color) {

        if (hs) x++;

        // Отслеживание изменений HS/VS
        if (_hs == 0 && hs == 1) { x = 0; y++; }
        if (_vs == 1 && vs == 0) { x = 0; y = 0; }

        // Сохранить предыдущее значение
        _hs = hs;
        _vs = vs;

        // Вывод на экран
        pset(x - 48, y - 35, color);
    }

    int destroy() {

        free(screen_buffer);

        SDL_DestroyTexture  (sdl_screen_texture);
        SDL_DestroyRenderer (sdl_renderer);
        SDL_DestroyWindow   (sdl_window);
        SDL_Quit();

        return 0;
    }
};

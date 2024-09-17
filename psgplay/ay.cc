enum AY_PARAM
{
    AY_ENV_HOLD     = 1,
    AY_ENV_ALT      = 2,
    AY_ENV_ATTACK   = 4,
    AY_ENV_CONT     = 8
};

// AY-3-8910 Уровни
static const int ay_levels[16] =
{
    0x0000, 0x0385, 0x053D, 0x0770,
    0x0AD7, 0x0FD5, 0x15B0, 0x230C,
    0x2B4C, 0x43C1, 0x5A4B, 0x732F,
    0x9204, 0xAFF1, 0xD921, 0xFFFF
};

// 44 байта https://audiocoding.ru/articles/2008-05-22-wav-file-structure/
struct __attribute__((__packed__)) WAVEFMTHEADER 
{
    unsigned int    chunkId;        // RIFF 0x52494646
    unsigned int    chunkSize;
    unsigned int    format;         // WAVE 0x57415645
    unsigned int    subchunk1Id;    // fmt (0x666d7420)
    unsigned int    subchunk1Size;  // 16
    unsigned short  audioFormat;    // 1
    unsigned short  numChannels;    // 2
    unsigned int    sampleRate;     // 44100
    unsigned int    byteRate;       // 88200
    unsigned short  blockAlign;     // 2
    unsigned short  bitsPerSample;  // 8
    unsigned int    subchunk2Id;    // data 0x64617461
    unsigned int    subchunk2Size;  // Количество байт в области данных.
};

class AYChip 
{
protected:

    int ay_regs[16],
		ay_amp[3],
		ay_tone_tick[3],
        ay_tone_period[3],
        ay_tone_high[3],
        ay_tone_levels[16],
		ay_noise_toggle,
        ay_noise_period,
        ay_noise_tick,
        ay_rng,
		ay_env_tick,
        ay_env_period,
        ay_env_first,
        ay_env_rev,
        ay_env_counter = 0,
        ay_env_internal_tick = 0,
        ay_env_cycles,
		ay_mono,
		cur_cycle;

    // ---
    unsigned char* psg;
    int psg_size = 0,
		chan = 0,
		is_speaker = 0,
		frequency = 44100, // 44100, 22050, 11025
		maxsize = 33554432;

    int* _left;
    int* _center;
    int* _right;

    float time = 0;

public:

    AYChip() 
	{
        int i;

        // Коррекция уровня (128 == 0 уровень)
        for (int i = 0; i < 16; i++) {
            ay_tone_levels[i] = (ay_levels[i]*256 + 0x8000) / 0xFFFF;
        }

        // Первичная инициализация
        for (int i = 0; i < 3; i++) {

            ay_tone_high[i]   = 0;
            ay_tone_tick[i]   = 0;
            ay_tone_period[i] = 1;
        }

        ay_mono     = 0;
        ay_env_tick = 0;
        cur_cycle   = 0;
        ay_rng      = 1;
        ay_env_internal_tick = 0;

        // Инициализация регистров в FFh изначально всех
        for (int i = 0; i < 16; i++) ay_regs[i] = i == 7 ? 0xFF : 0x00;

        psg = NULL;

        // Выделить по 32 Мб, этого хватит на 760 секунд (12 минут)
        maxsize = 1024*1024*32;
        _left   = (int*) malloc(maxsize * sizeof(int));
        _center = (int*) malloc(maxsize * sizeof(int));
        _right  = (int*) malloc(maxsize * sizeof(int));

        for (int i = 0; i < maxsize; i++) {

            _left[i]    = 0;
            _center[i]  = 0;
            _right[i]   = 0;
        }
    }

    // Запись данных в регистр
    void write(int ay_register, int ay_data)
	{
        int reg_id  = ay_register & 15;
        int tone_id = reg_id >> 1;        // Биты [3:1] Номер частоты тона

        ay_regs[reg_id] = ay_data;

        switch (reg_id) {

            // Тоны (0-2)
            case 0: case 1:
            case 2: case 3:
            case 4: case 5:

                // Получение значения тона из регистров AY
                ay_tone_period[tone_id] = (ay_regs[reg_id & ~1] + 256*(ay_regs[(reg_id & ~1) | 1] & 15));

                // Недопуск бесконечной частоты
                if (ay_tone_period[tone_id] == 0) {
                    ay_tone_period[tone_id] = 1;
                }

                // Это типа чтобы звук не был такой обалдевший
                if (ay_tone_tick[tone_id] >= 2*ay_tone_period[tone_id])
                    ay_tone_tick[tone_id] %= 2*ay_tone_period[tone_id];

                break;

            // Сброс шума
            case 6:

                ay_noise_tick   = 0;
                ay_noise_period = ay_regs[6] & 0x0F;
                break;

            // Период огибающей
            case 11:
            case 12:

                ay_env_period = ay_regs[11] | (ay_regs[12] << 8);
                break;

            // Запись команды для огибающей, сброс всех счетчиков
            case 13:

                ay_env_first         = 1;
                ay_env_rev           = 0;
                ay_env_internal_tick = 0;
                ay_env_tick          = 0;
                ay_env_cycles        = 0;
                ay_env_counter       = (ay_regs[13] & AY_ENV_ATTACK) ? 0 : 15;
                break;
        }
    }

    // Срабатывает каждые 32 такта Z80 процессора 3.5 Мгц (109.375 Khz)
    int tick()
	{
        int mixer    = ay_regs[7];
        int envshape = ay_regs[13];

        // Задание уровней звука для тонов
        int levels[3];

        // Генерация начальных значений громкости
        for (int n = 0; n < 3; n++) {

            int g = ay_regs[8 + n];

            // Если на 4-м бите громкости тона стоит единица, то взять громкость огибающей
            levels[n] = ay_tone_levels[(g & 16 ? ay_env_counter : g) & 15];
        }

        // Обработчик "огибающей" (envelope)
        ay_env_tick++;

        // Если резко поменялся period, то может быть несколько проходов
        while (ay_env_tick >= ay_env_period) {
        //if (ay_env_tick >= ay_env_period) {

            ay_env_tick -= ay_env_period;

            // Внутренний таймер
            ay_env_internal_tick++;

            // Выполнить первые 1/16 периодический INC/DEC если нужно
            // 1. Это первая запись в регистр r13
            // 2. Или это Cont=1 и Hold=0
            if (ay_env_first || ((envshape & AY_ENV_CONT) && !(envshape & AY_ENV_HOLD))) {

                // Направление движения: вниз (ATTACK=1) или вверх
                if (ay_env_rev)
                     ay_env_counter -= (envshape & AY_ENV_ATTACK) ? 1 : -1;
                else ay_env_counter += (envshape & AY_ENV_ATTACK) ? 1 : -1;

                // Проверка на достижения предела
                if      (ay_env_counter <  0) ay_env_counter = 0;
                else if (ay_env_counter > 15) ay_env_counter = 15;
            }

            // Срабатывает каждые 16 циклов AY
            if (ay_env_internal_tick >= 16) {

                // Сброс счетчика (ay_env_internal_tick -= 16;)
                ay_env_internal_tick = 0;

                // Конец цикла для CONT, если CONT=0, то остановка счетчика
                if ((envshape & AY_ENV_CONT) == 0) {
                    ay_env_counter = 0;

                } else {

                    // Опция HOLD=1
                    if (envshape & AY_ENV_HOLD) {

                        // Пилообразная фигура
                        if (ay_env_first && (envshape & AY_ENV_ALT))
                            ay_env_counter = (ay_env_counter ? 0 : 15);
                    }
                    // Опция HOLD=0
                    else {

                        if (envshape & AY_ENV_ALT)
                             ay_env_rev     = !ay_env_rev;
                        else ay_env_counter = (envshape & AY_ENV_ATTACK) ? 0 : 15;
                    }
                }

                ay_env_first = 0;
            }

            // Выход, если период нулевой
            if (!ay_env_period) break;
        }

        // Обработка тонов
        for (int _tone = 0; _tone < 3; _tone++) {

            int level = levels[_tone];

            // При деактивированном тоне тут будет либо огибающая,
            // либо уровень, указанный в регистре тона
            ay_amp[_tone] = level;

            // Тон активирован
            if ((mixer & (1 << _tone)) == 0) {

                // Счетчик следующей частоты
                ay_tone_tick[_tone] += 2;

                // Переброска состояния 0->1,1->0
                if (ay_tone_tick[_tone] >= ay_tone_period[_tone]) {
                    ay_tone_tick[_tone] %= ay_tone_period[_tone];
                    ay_tone_high[_tone] = !ay_tone_high[_tone];
                }

                // Генерация меандра
                ay_amp[_tone] = ay_tone_high[_tone] ? level : 0;
            }

            // Включен шум на этом канале. Он работает по принципу
            // что если включен тон, и есть шум, то он притягивает к нулю
            if ((mixer & (8 << (_tone))) == 0 && ay_noise_toggle) {
                ay_amp[_tone] = 0;
            }
        }

        // Обновление noise-фильтра
        ay_noise_tick += 1;

        // Использовать генератор шума пока не будет достигнут нужный период
        while (ay_noise_tick >= ay_noise_period) {
        //if (ay_noise_tick >= ay_noise_period) {

            // Если тут 0, то все равно учитывать, чтобы не пропускать шум
            ay_noise_tick -= ay_noise_period;

            // Это псевдогенератор случайных чисел на регистре 17 бит
            // Бит 0: выход; вход: биты 0 xor 3.
            if ((ay_rng & 1) ^ ((ay_rng & 2) ? 1 : 0))
                ay_noise_toggle = !ay_noise_toggle;

            // Обновление значения
            if (ay_rng & 1) ay_rng ^= 0x24000; /* и сдвиг */ ay_rng >>= 1;

            // Если период нулевой, то этот цикл не закончится
            if (!ay_noise_period) break;
        }

        // +32 такта
        cur_cycle += 32*frequency;

        // Частота хост-процессора 3.5 Мгц
        if (cur_cycle  > 3500000) {
            cur_cycle %= 3500000;
            return 0;
        } else {
            return 1;
        }
    }

    // Добавить уровень
    void get(int& left, int& right) 
	{
        // Каналы A-слева; B-посередине; C-справа
        left  = 128 + (ay_amp[0] + (ay_amp[1]/2)) / 4;
        right = 128 + (ay_amp[2] + (ay_amp[1]/2)) / 4;

        // PC Speaker
        // -------------
        if (is_speaker) {

            chan = (chan + 1) % 3;
            int mid = 96 + ay_amp[chan];
            if (mid < 120) left = 64; else left = 192;
            if (mid < 120) right = 64; else right = 192;
        }
        // -------------

        // Потому что уши режет такой звук
        if (ay_mono) {

            int center = (left + right) / 2;

            left  = center;
            right = center;
        }

        if (left  > 255) left  = 255; else if (left  < 0) left  = 0;
        if (right > 255) right = 255; else if (right < 0) right = 0;
    }

    // -----------------------------
    // ПРОИГРЫВАТЕЛЬ PSG
    // -----------------------------

    void loadpsg(const char* fn) 
	{
        FILE* fp = fopen(fn, "rb");

        if (fp) {

            fseek(fp, 0, SEEK_END);
            psg_size = ftell(fp) - 16;
            fseek(fp, 16, SEEK_SET);

            psg = (unsigned char*) malloc(psg_size);
            fread(psg, 1, psg_size, fp);
            fclose(fp);

        } else {
            psg = NULL;
        }
    }

    // Проиграть PSG
    void play() 
	{
        int id = 0, i, left, right;
        unsigned int  wp = 0;
        unsigned char bf[2];

        if (psg) {

            FILE* fp = fopen("result.wav", "wb+");
            fseek(fp, sizeof(WAVEFMTHEADER), SEEK_SET);

            while (id < psg_size) {

                int cmd = psg[id++];

                // 20/80*n секунд ожидания
                if (cmd == 0xFF || cmd == 0xFE) {

                    int n = 1;

                    // Сколько раз выждать по 4*20 мс
                    if (cmd == 0xFE) n = 4 * psg[id++];

                    // Проиграть следующие 20 мс
                    for (i = 0; i < n * (frequency/50); i++) {

                        while (tick());

                        int l = 128, r = 128; get(l, r);

                        _left  [ wp ] = ay_amp[0];
                        _center[ wp ] = ay_amp[1];
                        _right [ wp ] = ay_amp[2];

                        wp++;
                    }
                }
                // Конец композиции
                else if (cmd == 0xFD) {
                    break;
                }
                // Запись в регистр AY
                else if (cmd < 16) {

                    int data = psg[id++];
                    write(cmd, data);
                }
            }

            int ch0 = 1, // LEFT
                ch1 = 1, // CENTER
                ch2 = 1; // RIGHT

            // Выдать звуки на-гора
            for (int i = 0; i < wp; i++) {

                // Временной шифт (G)
                int L  = 128,  R  = 128,
                    GL = 1*32, GR = 1*64;

                L += (1.1*ch0*(float)_left[i+GL] + 0.5*ch1*(float)_center[i] + 0.9*ch2*(float)_right[i]   ) / 3;
                R += (0.9*ch0*(float)_left[i   ] + 0.5*ch1*(float)_center[i] + 1.1*ch2*(float)_right[i+GR]) / 3;

                if (L < 0) L = 0; else if (L > 255) L = 255;
                if (R < 0) R = 0; else if (R > 255) R = 255;

                bf[0] = L;
                bf[1] = R;

                fwrite(bf, 1, 2, fp);

                time += (1. / (float)frequency);
            }

            // Финализация
            struct WAVEFMTHEADER head = {
                0x46464952,
                (2*wp + 0x24),
                0x45564157,
                0x20746d66,
                16,             // 16=PCM
                1,              // Тип
                2,              // Каналы
                (unsigned int)frequency,      // Частота дискретизации
                (unsigned int)frequency*2,    // Байт в секунду
                2,              // Байт на семпл (1+1)
                8,              // Битность
                0x61746164,     // "data"
                2*wp
            };

            fseek(fp, 0, SEEK_SET);
            fwrite(& head, 1, sizeof(WAVEFMTHEADER), fp);
            fclose(fp);
        }
    }
};

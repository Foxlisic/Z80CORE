; ОШИБКИ SD
; =========
;
;   #1 Нет ответа от команды
;   #2 От команды не получен BSY=0
;   #3 Неправильный ответ от IDLE инициализации
;   #4 Ошибка чтения/записи
;   #5 Сектор не записан
;
; ТИП КАРТЫ
; =========
;
;   #0 Неизвестный
;   #1 SDv1
;   #2 SDv2
;   #3 SDHC

; МЕТОДЫ
;
;   sd_init()           -- инициализация карты
;   sd_read(hl:de, bc)  -- чтение из сектора hl:de в память bc
;   sd_write(hl:de, bc) -- запись

; ----------------------------------------------------------------------
PORT_SD_DATA:       equ     0x0f
PORT_SD_CMD:        equ     0x1f

PTR_SD_ARG:         equ     0x5B0E
PTR_SD_CMD:         equ     0x5B12
PTR_SD_TYPE:        equ     0x5B13
PTR_SD_START:       equ     0x5B14
; ----------------------------------------------------------------------

            ; Отсылка команды A=0/2/3
sd_cmd:     out     (PORT_SD_CMD), a
            call    sd_wait
            ret

            ; Отсылка и прием байта A, cmd=1
sd_rd:      ld      a, $ff
sd_wr:      out     (PORT_SD_DATA), a
            call    sd_wait
            in      a, (PORT_SD_DATA)
            ret

            ; Ожидание BUSY=1
sd_wait:    in      a, (PORT_SD_CMD)
            rra
            jr      c, sd_wait
            ret

; ----------------------------------------------------------------------
; Инициализация устройства
; ----------------------------------------------------------------------

sd_init:    xor     a
            call    sd_cmd

            ; Тест на возможность войти в IDLE (CMD0, ARG=0)
            xor     a
            ld      h, a
            ld      l, a
            ld      d, a
            ld      e, a
            call    sd_command
            and     a
            jp      nz, sd_end          ; Статус должен быть 0
            ld      a, b
            cp      $01
            jp      nz, sd_err2         ; Ответ должен быть 1

            ; Определить тип карты (SD1)
            ld      a,  8
            ld      hl, 0x0000
            ld      de, 0x01AA
            call    sd_command
            and     a
            jr      nz, sd_end          ; Статус должен быть 0

            ; Тест на тип карты SD1
            ld      hl, $0000           ; Для аргумента ACMD
            ld      a, 1
            ld      (PTR_SD_TYPE), a    ; Отметить что это SD1
            ld      a, b
            and     $04                 ; & R1_ILLEGAL_COMMAND
            jr      nz, sd_cmd8         ; Если есть этот бит, то это SD1

            ; Это SD2? Проверить последний байт, чтобы убедиться
            call    sd_rd
            call    sd_rd
            call    sd_rd
            call    sd_rd
            cp      $AA                 ; Должен быть $AA
            jr      nz, sd_err2         ; Если нет, то ошибка #3

            ld      a, 2
            ld      (PTR_SD_TYPE), a    ; Все верно, ставим SD2
            ld      hl, $4000           ; Только для SD2

            ; Отсылать команду 0x29
sd_cmd8:    ld      bc, 4096
sd_cmd9:    push    bc
            push    hl
            ld      a, 0x29             ; SD_CMD41
            ld      de, 0
            call    sd_acmd
            ld      e, b                ; Временно записать B => E
            pop     hl
            pop     bc
            and     a
            jr      nz, sd_end          ; Возникла ошибка?
            ld      a, e
            and     a                   ; Проверка на R1_READY_STATE
            jr      z, sd_cmd10         ; Если A=0, успешно
            dec     bc
            ld      a, b
            or      c
            jr      nz, sd_cmd9         ; Повторять несколько раз
            jr      sd_err2             ; Если достигли максимума

sd_cmd10:   ; Проверка наличия SDHC
            ld      a, (PTR_SD_TYPE)
            cp      $2                  ; Если это не SD2, пропуск
            jr      nz, sd_cmd11

            ; Проверка наличия байта в ответе CMD58 (должно быть 0)
            ld      de, $0000
            ld      h, d
            ld      l, e
            ld      a, 58
            call    sd_command
            and     a
            jr      nz, sd_end          ; Если статус не 0, ошибка
            ld      a, b
            and     a
            jr      nz, sd_err2         ; Должен быть 0

            ; Прочесть ответ от карты и определить тип (SDHC если есть)
            call    sd_rd
            and     $c0
            cp      $c0
            jr      nz, sd_err2         ; Старшие 2 бита не получены!
            call    sd_rd             ; Удалить остатки
            call    sd_rd
            call    sd_rd
            ld      a, 3                ; Это SDHC
            ld      (PTR_SD_TYPE), a
sd_cmd11:   xor     a
            jr      sd_end              ; Все ОК

            ; Завершение команды
sd_err2:    ld      a, 3                ; Ошибка #3
sd_end:     call    sd_disable
            ret

            ; Отсоединить чип
sd_disable: push    af
            ld      a, 3
            call    sd_cmd
            pop     af
            ret

; ----------------------------------------------------------------------
; Реинициализация при таймауте Read/Write
; ----------------------------------------------------------------------

sd_reinit:  ld      (PTR_SD_START), bc
            ; Проверка на таймаут
            in      a, (PORT_SD_CMD)
            rlca
            ; Таймаут не вышел, все ОК
            ret     nc
            push    de
            push    hl
            call    sd_init
            pop     hl
            pop     de
            ret

; ----------------------------------------------------------------------
; Отсылка команды A с аргументом  [HL:DE] (32 битное число)
; Если A==0, то ответ команды валидный, и тогда в B будет ответ
;      A<>0, то будет код ошибки
; ----------------------------------------------------------------------

sd_command: ; Сохранить аргумент и команду
            ld      (PTR_SD_CMD), a
            ld      (PTR_SD_ARG+2), hl
            ld      h, d
            ld      l, e
            ld      (PTR_SD_ARG), hl
            ex      af, af'

            ; CE=0 Включить чип
            ld      a, 2
            call    sd_cmd

            ; Принимать байты, пока не будет 0xFF
            ld      de, 4096
sd_cmd1:    call    sd_rd
            cp      $ff
            jr      z, sd_cmd2
            dec     de
            ld      a, d
            or      e
            jr      nz, sd_cmd1
            ld      a, 1        ; Ошибка #1
            ret

sd_cmd2:    ; Отсылка команды к SD
            ex      af, af'
            or      $40
            call    sd_wr

            ; Отослать 32-х битный аргумент (BigEndian)
            ld      hl, PTR_SD_ARG+3
            ld      b, 4
sd_cmd3:    ld      a, (hl)
            dec     hl
            call    sd_wr
            djnz    sd_cmd3

            ; Вычислить и отправить CRC
            ld      a, (PTR_SD_CMD)
            ld      b, 0x95     ; CRC
            and     a           ; SD_CMD0
            jr      z, sd_cmd4
            ld      b, 0x87     ; SD_CMD8 (и другие)
sd_cmd4:    ld      a, b
            call    sd_wr

            ; Ждать снятия флага BSY
            ld      de, 255
            ld      b, 0
sd_cmd5:    call    sd_rd
            ld      b, a        ; Ответ команды
            and     $80
            jr      z, sd_cmd6  ; Ответ пришел BSY=0
            dec     de
            ld      a, d
            or      e
            jr      nz, sd_cmd5
            ld      a, 2        ; Error #2 Не дождались ответа
sd_cmd6:    ret                 ; Если ответ валидный, A=0

; Вспомогательная команда ACMD(cmd, arg)
sd_acmd:    push    af
            push    de
            push    hl
            ld      de, $0000
            ld      h, d
            ld      l, e
            ld      a, 55       ; SD_CMD55
            call    sd_command
            pop     hl
            pop     de
            pop     af
            call    sd_command  ; Запрошенная команда
            ret

; ----------------------------------------------------------------------
; Чтение сектора с устройства, номер (HL:DE) по адресу BC
; ----------------------------------------------------------------------

sd_read:    push    hl
            push    de
            push    bc
            call    sd_reinit
            and     a
            jr      nz, sd_read.e1

            ; Отослать команду поиска блока
            ld      a, 17           ; SD_CMD17
            call    sd_command
            and     a
            jr      nz, sd_read.e1

            ; Ожидание ответа от SD
            ld      bc, 4096
sd_cmd13:   call    sd_rd
            cp      $ff
            jr      nz, sd_cmd14
            dec     bc
            ld      a, b
            or      c
            jr      nz, sd_cmd13
            jr      sd_read.e2      ; Ответа не дождались
sd_cmd14:   cp      $fe
            jr      nz, sd_read.e2  ; Ответ не $FE

            ; Чтение данных
            ld      hl, (PTR_SD_START)
            ld      bc, 512
sd_cmd15:   call    sd_rd
            ld      (hl), a
            inc     hl
            dec     bc
            ld      a, b
            or      c
            jr      nz, sd_cmd15
            jr      sd_read.e1      ; Завершено
sd_read.e2: ld      a, 4
sd_read.e1: call    sd_disable
            pop     bc
            pop     de
            pop     hl
            ret

; ----------------------------------------------------------------------
; Запись сектора на устройство, номер (HL:DE) по адресу BC
; ----------------------------------------------------------------------

sd_write:   push    hl
            push    de
            push    bc
            call    sd_reinit
            and     a
            jr      nz, sd_read.e1

            ; Отослать команду поиска блока
            ld      a, 24           ; SD_CMD24
            call    sd_command
            and     a
            jr      nz, sd_read.e1

            ; Старт записи
            ld      a, 0xFE
            call    sd_wr

            ; Запись данных
            ld      bc, 512
            ld      hl, (PTR_SD_START)
sd_cmd16:   ld      a, (hl)
            call    sd_wr
            inc     hl
            dec     bc
            ld      a, b
            or      c
            jr      nz, sd_cmd16

            ; CRC Dummy и статус ответа
            ld      a, 0xFF
            call    sd_rd
            call    sd_rd
            call    sd_rd
            and     $1f
            cp      $05
            jr      nz, sd_read.e2

            ; Ждем, пока не появится что-то кроме $FF с входа
            ld      bc, 4096
sd_cmd17:   call    sd_rd
            cp      $FF
            jr      nz, sd_cmd18
            dec     bc
            ld      a, b
            or      c
            jr      nz, sd_cmd17
            ld      a, 5
            jr      sd_read.e1

sd_cmd18:   ; Выполнить запрос на проверку целостности
            ld      h, 0
            ld      l, h
            ld      d, l
            ld      e, l
            ld      a, 13

            ; Должен быть ответ 0
            call    sd_command  ; SD_CMD13
            and     a
            jr      nz, sd_read.e2
            ld      a, b
            and     a
            jr      nz, sd_read.e2

            ; Читать второй байт, должен быть 0
            call    sd_rd
            and     a
            jr      nz, sd_read.e2

            ; Все в порядке
            xor     a
            jr      sd_read.e1

; ------------------------------------------------------------------------------
sdcard:
; ------------------------------------------------------------------------------
.error: defb    0                       ; (public)  Номер ошибки, если не 0
.cmdn:  defb    0                       ; (private) Номер команды
.addr:  defw    0                       ; (private) Адрес чтения или записи
.type:  defb    0                       ; (private) Тип диска
.arg:   dword   0                       ; (public)  Аргумент к sdcard.command
.lba:   dword   0                       ; (public)  Номер сектора
; ------------------------------------------------------------------------------
; Если процедура .read / .write возвращают CF=0, то это ошибка, код в .error
;  1: При выполнении Command не дождались очистки входящего буфера
;  2: Command, получен таймаут снятия флага BSY у карточки
;  3: Не получен валидный R1_IDLE_STATE
;  4: Неправильный ответ на команду с аргументом 0x01AA
;  5: Неверный ответ от ACMD, таймаут
;  6: Должен быть 0 на CMD58
;  7: При чтении не таймаут при опросе ответа FE
;  8: После записи ответ не равен 05
;  9: Таймаут окончания записи на флешку
; 10 Не дождались валидного ответа FF
; 11 Первый байт ответа не 0
; 12 Второй байт ответа не 0
; ------------------------------------------------------------------------------

; Запуск 80 тактов и сразу к ожиданию BSY
.start: xor     a
        out     (7), a
        nop                             ; На всякий случай, вдруг модуль не успеет

; Ожидание установки BSY=0
.wait:  in      a, (7)
        and     $80
        ret     z
        jr      .wait

; Прием и отсылка байта
.get:   ld      a, 0xFF
.put:   out     (6), a
        ld      a, 1
        out     (7), a                  ; Отослать байт
        call    .wait
        in      a, (6)                  ; Получение принятого байта
        ret

; Возврат с ошибкой
.erret: ld      (.error), a             ; Возникла ошибка!
        ld      a, 3
        out     (7), a                  ; CE=1
        scf
        ccf
        ret

; ------------------------------------------------------------------------------
; Отослать команду `A` к SPI с аргументами в .arg
; Результат A и также необходимо проверить наличие .error != 0
; Если CF=1, ошибок нет
; ------------------------------------------------------------------------------

.command:

        ld      (.cmdn), a
        xor     a
        ld      (.error), a
        call    .start              ; Инициализация
        ld      bc, 4096
        ld      a, 2
        out     (7), a              ; Включить устройство CE=0
.R1:    call    .get                ; Ждать пока не появится FF на выходе
        cp      $FF
        jr      z, .R2
        dec     bc
        ld      a, b
        or      c
        jr      nz, .R1
        ld      a, 1
        jp      .erret
.R2:    ld      a, (.cmdn)          ; Отсылка номера команды к SD
        or      $40
        call    .put
        ld      de, .arg + 3        ; Отослать 32-х битную команду
        ld      b, 4
.R3:    ld      a, (de)
        dec     de
        call    .put
        djnz    .R3
        ld      a, (.cmdn)          ; Выслать CRC в зависимости от команды
        and     a
        jr      nz, .R4
        ld      a, 0x95             ; CMD0 with arg 0
        jr      .R5
.R4:    cp      $08
        ld      a, 0xFF             ; CRC=255 при любом другом
        jr      nz, .R5
        ld      a, 0x87             ; CMD8 with arg 0x1AA
.R5:    call    .put
        ld      b, 0                ; Ожидать снятия флага BUSY в контроллере
.R6:    call    .get
        cp      $80
        ret     c                   ; Если A < $80, выход, CF=1
        djnz    .R6
        ld      a, 2
        jp      .erret

; ------------------------------------------------------------------------------
; ACMD специальная команда
; ------------------------------------------------------------------------------

.acmd:  push    bc
        push    af
        ld      hl, (.arg)              ; Сохранить ARG
        push    hl
        ld      hl, (.arg+2)
        push    hl
        ld      hl, $0000
        ld      (.arg), hl
        ld      (.arg+2), hl
        ld      a, 55
        call    .command                ; Command(55, 0)
        pop     hl
        ld      (.arg+2), hl
        pop     hl
        ld      (.arg), hl
        pop     af
        call    .command                ; Command(A, arg)
        pop     bc
        ret

; ------------------------------------------------------------------------------
; Инициализация устройства после включения SPI или таймаута
; ------------------------------------------------------------------------------

.init:  ld      hl, 0                   ; ARG=0
        ld      (sdcard.arg), hl
        ld      (sdcard.arg+2), hl
        xor     a
        ld      (.type), a
        call    .command                ; command(SD_CMD0, 0)
        ret     nc
        cp      1                       ; Если не равно R1_IDLE_STATE
        jr      z, .K1
        ld      a, 3
        jp      .erret                  ; CF=0, ошибка
.K1:    ld      hl, 0x01AA
        ld      (.arg), hl
        ld      a, 8                    ; SD_CMD8
        call    .command
        ret     nc
        and     a, 4                    ; Если второй бит установлен
        jr      z, .K2
        ld      a, 1
        ld      (.type), a              ; То это карта типа 1
        jr      .K4
.K2:    call    .get                    ; Прочесть 4 байта
        call    .get
        call    .get
        call    .get
        cp      $AA                     ; Проверить чтобы правильный ответ был
        jr      z, .K3
        ld      a, 4
        jp      .erret
.K3:    ld      a, 2
        ld      (.type), a              ; Карта второго типа
        ld      a, $40
        ld      (.arg+3), a             ; ARG=$40000000
.K4:    ld      hl, $0000
        ld      (.arg), hl
        ld      bc, 4096
.K5:    ld      a, 0x29
        call    .acmd                   ; Отсылка ACMD
        ret     nc                      ; В случае ошибки
        and     a
        jr      z, .K6                  ; Все нормально
        dec     bc
        ld      a, b
        or      c
        jr      nz, .K5
        ld      a, 5
        jp      .erret                  ; Не удалось прочитать ACMD
.K6:    ld      a, (.type)
        cp      2
        jp      nz, .KEX                ; Если != 2, то пропуск
        ld      a, 0
        ld      (.arg+3), a             ; ARG=0
        ld      a, 58
        call    .command                ; command(58, 0)
        and     a
        jr      z, .K7
        ld      a, 6
        jp      .erret                  ; Ошибка, должен быть 0
.K7:    call    .get
        and     $c0
        cp      $c0
        jr      nz, .K8
        ld      a, 3
        ld      (.type), a              ; SDHC карта
.K8:    call    .get
        call    .get
        call    .get                    ; Удалить остатки
.KEX:   ld      a, 3
        out     (7), a                  ; CE=1
        scf
        ret                             ; CF=1, успешная инициализация

; ------------------------------------------------------------------------------
; Общая процедура для Read/Write
; ------------------------------------------------------------------------------

.rwck:  xor     a
        ld      (.error), a
        ld      (.addr), hl
        in      a, (7)
        and     $40
        jr      z, .C1
        call    .init                   ; Если таймаут, то инициализация
        ret     nc                      ; В случае ошибки
.C1:    ld      a, (.type)
        cp      3                       ; 3=SDHC
        jr      z, .C2
        ld      a, 7
        jp      .erret                  ; Тип не поддерживается
.C2:    ld      hl, (.lba)
        ld      (.arg), hl
        ld      hl, (.lba+2)
        ld      (.arg+2), hl
        scf
        ret

; ------------------------------------------------------------------------------
; Чтение сектора в sdcard.lba и запись результата в HL
; ------------------------------------------------------------------------------

.read:  call    .rwck                   ; Проверка карты
        ret     nc
        ld      a, 17
        call    .command                ; Команда чтения
        ret     nc
        ld      bc, 4096
.A1:    call    .get                    ; Ждать ответ от SD
        cp      0xFE
        jr      z, .A3
        cp      0xFF
        jr      nz, .A2
        dec     bc
        ld      a, b
        or      c
        jr      nz, .A1
.A2:    ld      a, 8
        jp      .erret                  ; Неверный ответ (FEh) или не дождались
.A3:    ld      hl, (.addr)
        ld      bc, 512
.A4:    call    .get
        ld      (hl), a
        inc     hl
        dec     bc
        ld      a, b
        or      c
        jr      nz, .A4
        ld      a, 3
        out     (7), a                  ; CE=1
        scf                             ; Успешное чтение
        ret

; ------------------------------------------------------------------------------
; Запись сектора в sdcard.lba из HL
; ------------------------------------------------------------------------------

.write: call    .rwck
        ld      a, 24
        call    .command                ; Команда записи
        ret     nc
        ld      a, 0xFE
        call    .put                    ; DATA_START_BLOCK
        ld      bc, 512
        ld      hl, (.addr)
.B1:    ld      a, (hl)
        call    .put
        inc     hl
        dec     bc
        ld      a, b
        or      c
        jr      nz, .B1
        ld      a, 0xFF                 ; Dummy 16-bit CRC
        call    .put
        call    .put
        call    .get                    ; status
        and     $1F
        cp      $05
        jr      z, .B2                  ; (status & 0x1F) != 0x05
        ld      a, 9
        jp      .erret
.B2:    ld      bc, 4096                ; Ожидание окончания программирования
.B3:    call    .get
        cp      $FF
        jr      z, .B4
        dec     bc
        ld      a, b
        or      c
        jr      nz, .B3
        ld      a, 10
        jp      .erret
.B4:    ld      hl, 0
        ld      (.arg), hl
        ld      (.arg+2), hl
        ld      a, 13
        call    .command                ; Должен быть 0
        ret     nc
        and     a
        jr      z, .B5
        ld      a, 11
        jp      .erret
.B5:    call    .get                    ; Должен быть 0
        and     a
        jr      z, .B6
        ld      a, 12
        call    .erret
.B6:    ld      a, 3
        out     (7), a
        scf
        ret

; ------------------------------------------------------------------------------
;       Очистка всего экрана в цвет A
; ------------------------------------------------------------------------------

cls:    ld      hl, $e000
        ld      (cursor.cl), a
        ld      e, 0
        ld      c, 8
M2:     ld      b, 0
M1:     ld      (hl), e
        inc     hl
        ld      (hl), a
        inc     hl
        djnz    M1
        dec     c
        jr      nz, M2
        ld      hl, $0000
        ld      (cursor), hl
        ret

; ------------------------------------------------------------------------------
; Вывод строки из HL на экране
; 7F XX YY -- установка X,Y
; FF CL    -- установка цвета
; ------------------------------------------------------------------------------

print:  ld      a, (hl)
        cp      $7f
        jr      z, .setxy
        cp      $ff
        jr      z, .setcl
        and     a
        ret     z
        inc     hl
        call    term
        jr      print

.setxy: inc     hl
        ld      a, (hl)
        ld      (cursor.x), a
        inc     hl
        ld      a, (hl)
        ld      (cursor.y), a
        inc     hl
        jr      print
.setcl: inc     hl
        ld      a, (hl)
        ld      (cursor.cl), a
        inc     hl
        jr      print

; ------------------------------------------------------------------------------
; Печать HEX-числа A на экране
; ------------------------------------------------------------------------------

phex8:  push    af
        rlca
        rlca
        rlca
        rlca
        call    .A1
        pop     af
.A1:    and     $0F
        cp      10
        jr      c, .A2
        add     a, 7
.A2:    add     $30
        call    term
        ret

; ------------------------------------------------------------------------------
; Вывод символа на экране
; ------------------------------------------------------------------------------

term:   push    af
        push    bc
        push    de
        push    hl
        cp      10
        jr      z, .NL
        call    cursor2hl
        ld      (hl), a                 ; Знакоместо
        inc     hl
        ld      a, (cursor.cl)
        ld      (hl), a                 ; Цветоместо
        ld      a, (cursor.x)
        inc     a
        cp      a, 80
        jr      nz, .N1
.NL:    ld      a, (cursor.y)
        inc     a
        cp      a, 25
        jr      nz, .N2
        dec     a
        ; Не делать скроллинг
.N2:    ld      (cursor.y), a
        xor     a
.N1:    ld      (cursor.x), a       ; Установка нового курсора
        call    update_cursor
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

; ------------------------------------------------------------------------------
; Обновление положения курсора
; ------------------------------------------------------------------------------

update_cursor:

        push    af
        ld      a, (cursor.x)
        out     ($04), a
        ld      a, (cursor.y)
        out     ($05), a
        pop     af
        ret

; ------------------------------------------------------------------------------
; Вычисление позиции HL
; ------------------------------------------------------------------------------

cursor2hl:

        push    bc
        push    de
        ld      hl, (cursor)
        ld      e, h
        ld      h, 0
        add     hl, hl
        add     hl, hl
        add     hl, hl
        add     hl, hl
        add     hl, hl
        ld      b, h
        ld      c, l
        add     hl, hl
        add     hl, hl
        add     hl, bc          ; hl = 160*y
        ld      d, 0
        add     hl, de
        add     hl, de          ; hl = 160*y + 2*x
        ld      de, $E000
        add     hl, de
        pop     de
        pop     bc
        ret

; ------------------------------------------------------------------------------
; Копирование строки DE -> HL, кол-во BC
; ------------------------------------------------------------------------------

copy:   ld      a, (de)
        ld      (hl), a
        inc     de
        inc     hl
        dec     bc
        ld      a, b
        or      a, c
        jr      nz, copy
        ret

; ------------------------------------------------------------------------------
; Делить HL / DE -> Результат HL, Остаток DE
; ------------------------------------------------------------------------------

udivmod16:

        push    bc
        ld      (.temp), hl         ; Здесь будет результат
        ld      hl, $0000
        ld      b, 16
.RT:    add     hl, hl              ; Сдвиг 16:16 битного числа
        push    hl
        ld      hl, (.temp)
        add     hl, hl
        ld      (.temp), hl
        pop     hl
        jr      nc, .N1
        inc     hl
.N1:    ld      a, l                ; HL минус DE и проверка результата
        sub     e
        ld      l, a
        ld      a, h
        sbc     d
        ld      h, a
        jr      c, .CR              ; Если есть перенос, то пишем 0 в результат
        ld      a, (.temp)
        or      1
        ld      (.temp), a          ; Иначе пишем 1 в результат
        jr      .NX
.CR:    add     hl, de              ; Восстановление HL
.NX:    djnz    .RT
        ld      d, h
        ld      e, l
        ld      hl, (.temp)
        pop     bc
        ret

.temp:  defw    0

; ------------------------------------------------------------------------------
; Перевод беззнакового числа HL в ASCIIZ строку => ссылка на строку HL
; ------------------------------------------------------------------------------

ui2a:   push    bc
        push    de
        ld      bc, .out + 5
.R:     ld      de, 10
        call    udivmod16
        ld      a, e
        add     $30
        dec     bc
        ld      (bc), a
        ld      a, l
        or      a, h
        jr      nz, .R
        ld      h, b
        ld      l, c
        pop     de
        pop     bc
        ret

.out:   defb    "65535",0

; ------------------------------------------------------------------------------
; Обработка прерывания клавиатуры
; ------------------------------------------------------------------------------

keyboad_irq:

        push    hl
        push    de
        push    bc
        push    af
        ld      a, (.hitp)      ; Старое значение счетчика
        ld      b, a
        in      a, (7)          ; Прочесть счетчик нажатий
        ld      (.hitp), a      ; Зафиксировать новый счетчик
        sub     b
        and     3               ; cnt = (new - old) & 3
        jr      z, .idle
        dec     a
        jr      z, .hit0        ; Разница в 1-м символе
        dec     a
        jr      z, .hit1        ; Разница в 2-х символах
        dec     a
        jr      z, .hit2        ; Разница в 3-х символах
.hit3:  in      a, (3)          ; Прием до 4-х символов за 1 кадр
        call    .push_key
.hit2:  in      a, (2)
        call    .push_key
.hit1:  in      a, (1)
        call    .push_key
.hit0:  in      a, (0)
        call    .push_key
.idle:  pop     af
        pop     bc
        pop     de
        pop     hl
        ei
        ret

; -----------
; Распознавание и запись клавиши в потоке
; -----------

.push_key:

        ld      hl, .keyup
        cp      $F0
        jr      nz, .K1         ; Получен F0h, установить .keyup = 1
        ld      (hl), a         ; Установка маркера, что следующая клавиша - отпущена
        ret
.K1:    ld      c, a
        ld      a, (hl)         ; Проверить, был ли F0h
        and     a
        ld      a, c
        jr      z, .K3
        cp      $12
        jr      z, .K2          ; Отпущен LSHIFT?
        cp      $59
        jr      z, .K2          ; Отпущен RSHIFT?
        jp      .DN             ; Иначе пропустить клавишу
.K2:    xor     a
        ld      (.shift), a
        jp      .DN             ; Если предыдущее значение было F0h -- пропуск клавиши
.K3:    cp      $12
        jr      z, .K4
        cp      $59
        jr      nz, .K5
.K4:    ld      a, $FF          ; Нажатие на L/R SHIFT
        ld      (.shift), a
        jr      .DN
.K5:    ld      b, 0            ; Декодирование клавиши в ASCII
        ld      hl, .symbols
        add     hl, bc
        ld      c, (hl)         ; XLATB
        ld      a, (.shift)     ; Тест на SHIFT
        and     a
        jr      z, .K6          ; SHIFT не нажат, преобразований не нужно


.K6:    ld      hl, .hitk
        ld      a, (hl)         ; Добавить клавишу в клавиатурный буфер
        inc     a
        and     $0F             ; Всего 16 символов в буфере
        ld      (hl), a
        ld      hl, .buf
        ld      d, 0
        ld      e, a
        add     hl, de
        ld      (hl), c         ; Запись в конец
.DN:    xor     a
        ld      (.keyup), a
        ret

; Буфер и переменные
.press: defb    0               ; 0=Если предыдущее значение не было F0h
.hitp:  defb    0               ; Зафиксированное значение счетчика
.hitk:  defb    0               ; Текущая позиция в буфере клавиатуры
.keyup: defb    0               ; =F0 предыдущая клавиша отпущена
.shift: defb    0               ; =1 Клавиша SHIFT нажата ранее
.buf:   defb    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.symbols:
        ;    0    1    2    3    4    5    6    7    8    9    A    B    C    D    E    F
        defb 0,0x18,   0 ,0x14,0x12,0x10,0x11,0x1E,  0 ,0x19,0x17,0x15,0x13,  9,  '`',  0 ; 0
        defb 0 ,  0 ,  1 ,  0 ,  0 , 'Q', '1',  0 ,  0 ,  0 , 'Z', 'S', 'A', 'W', '2',  0 ; 1
        defb 0 , 'C', 'X', 'D', 'E', '4', '3',  0 ,  0 , ' ', 'V', 'F', 'T', 'R', '5',  0 ; 2
        defb 0 , 'N', 'B', 'H', 'G', 'Y', '6',  0 ,  0 ,  0 , 'M', 'J', 'U', '7', '8',  0 ; 3
        defb 0 , ',', 'K', 'I', 'O', '0', '9',  0 ,  0 , '.', '/', 'L', ';', 'P', '-',  0 ; 4
        defb 0 ,  0 ,0x27,  0 , '[', '=',  0 ,  0 ,  0 ,  1 ,  10, ']',  0, 0x5C,  0 ,  0 ; 5
        defb 0 ,  0 ,  0 ,  0 ,  0 ,  0 ,   8,  0 ,  0 ,0x0C,  0 ,0x06,0x0B,  0 ,  0 ,  0 ; 6
        defb 0 ,0x0F,0x05,  0 ,0x07,0x04,  27,  0 ,0x1A,  0 ,0x0E,  0 ,  0 ,0x0D,  0 ,  0 ; 7
        defb 0 ,  0 ,  0 ,0x16,  0 ,  0 ,   0,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ; 8

; Данные
PTR_CURSOR_XY:      equ  5B00h          ; XY курсора
PTR_COLOR_DEF:      equ  5B02h          ; INK+PAPER

; Функции

;   cls(a)
;   scrollup()
;   prn_hide() -- скрыть курсор
;   prn_hide() -- скрыть курсор
;   prn_show() -- показать курсор
;   prn_str(hl)
;   prn_hex(a) -- печатать %02x
;   prn_term(a)
;   prn_print(a) -- печать с курсором
;   prn_locate(h, l)
;   prn_char(b, c, a)
;   prn_get_char_address(a)
;   prn_get_cursor_address(b, c)

; ----------------------------------------------------------------------
; Очистка экрана и бордера в цвет A
; ----------------------------------------------------------------------

cls:        ld      (PTR_COLOR_DEF), a
            rrca
            rrca
            rrca
            out     ($fe), a
            ld      hl, $0000
            ld      (PTR_CURSOR_XY), hl
            ld      h, $40
cls.n2:     xor     a
cls.n1:     ld      (hl), a
            inc     l
            jr      nz, cls.n1
            inc     h
            ld      a, h
            cp      $58
            jr      c, cls.n2
            cp      $5b
            ret     z
            ld      a, (PTR_COLOR_DEF)
            jr      cls.n1

; ----------------------------------------------------------------------
; Печать строки, указанной в HL
; ----------------------------------------------------------------------

prn_str:    ld      a, (hl)
            and     a
            ret     z
            call    prn_term
            inc     hl
            jr      prn_str

; ----------------------------------------------------------------------
; Печать HEX-4x4 из A
; ----------------------------------------------------------------------

prn_hex:    push    af
            push    bc
            ld      b, 2
prn_hex.n2: rlca
            rlca
            rlca
            rlca
            push    af
            and     $0f
            or      a           ; Потому что AND ставит HF=1
            daa
            add     a, $f0
            adc     a, $40
            call    prn_term
            pop     af
            djnz    prn_hex.n2
            pop     bc
            pop     af
            ret

; ----------------------------------------------------------------------
; Печать символа A в телетайп-режиме
; ----------------------------------------------------------------------

prn_term:   push    af
            push    bc
            push    hl

            ld      hl, (PTR_CURSOR_XY)
            ld      b, h
            ld      c, l
            cp      $08
            jr      z, prn_term.bs      ; Удаление символа
            cp      $0A
            jr      z, prn_term.nl      ; New Line?
            call    prn_char            ; Пропечатать символ в BC
            inc     c
            ld      a, c
            cp      $20
            jr      c, prn_term.xoff    ; X < 32 ? Пропуск

prn_term.nl:

            ld      c, 0
            inc     b
            ld      a, b
            cp      $18
            jr      c, prn_term.xoff    ; Y < 24 ? Пропуск
            call    scroll
            ld      b, $17

prn_term.xoff:

            ld      h, b
            ld      l, c
            ld      (PTR_CURSOR_XY), hl

            pop     hl
            pop     bc
            pop     af
            ret

prn_term.bs: ; Очистка предыдущего символа

            ; Если нельзя удалить символ, выход
            ld      a, c
            and     a
            jr      z, prn_term.xoff
            dec     c
            ld      a, ' '
            call    prn_char
            jr      prn_term.xoff

            ; Печать символа с учетом курсора
prn_print:  call    prn_hide
            call    prn_term
            call    prn_show
            ret

; ----------------------------------------------------------------------
; Сброс и установка курсора на позиции, цвета
; ----------------------------------------------------------------------
prn_color:

            ld      (PTR_COLOR_DEF), a
            ret

; Сброс мерцания атрибута
prn_hide:   push    hl
            call    prn_cursor_pos
            res     7, (hl)
            pop     hl
            ret

; Установка мерцания
prn_show:   push    hl
            call    prn_cursor_pos
            set     7, (hl)
            pop     hl
            ret

; ----------------------------------------------------------------------
; Установка курсора в H=Y, L=X с проверкой на ограничения по X,Y
; ----------------------------------------------------------------------

prn_locate: ld      a, l
            and     $1f
            ld      l, a
            ld      a, h
            cp      $18
            jr      c, prn_locate.noset18
            ld      h, $17
prn_locate.noset18:
            ld      (PTR_CURSOR_XY), hl
            ret

; ----------------------------------------------------------------------
; Вход: B(y=0..23), C(x=0..31) A(символ)
; ----------------------------------------------------------------------

prn_char:   push    af
            push    bc
            push    de
            push    hl
            push    hl
            call    prn_get_char_address
            ex      de, hl
            call    prn_get_cursor_address
            ld      b, 8
prn_char.pc1:
            ld      a, (de)
            ld      (hl), a
            inc     h
            inc     de
            djnz    prn_char.pc1
            pop     hl
            call    prn_cursor_pos
            ld      a, (PTR_COLOR_DEF)
            ld      (hl), a
            pop     hl
            pop     de
            pop     bc
            pop     af
            ret

; ----------------------------------------------------------------------
; HL - позиция курсора в области атрибутов
; ----------------------------------------------------------------------

prn_cursor_pos:

            push    af
            ld      hl, (PTR_CURSOR_XY)
            ld      a, l
            ld      l, h
            ld      h, 0
            add     hl, hl
            add     hl, hl
            add     hl, hl
            add     hl, hl
            add     hl, hl
            add     a, l
            ld      l, a
            ld      a, h
            adc     a, 0
            add     a, $58
            ld      h, a        ; HL=H*32+L
            pop     af
            ret

; ----------------------------------------------------------------------
; Вычисление адреса HL по символу A
; ----------------------------------------------------------------------

prn_get_char_address:

            sub     0x20
            ld      h, 0
            ld      l, a
            add     hl, hl
            add     hl, hl
            add     hl, hl
            ld      a, h
            add     0x3d
            ld      h, a
            ret

; ----------------------------------------------------------------------
; Вход:  B(Y=0..23), C(X=0..31)
; Выход: HL(адрес)
; ----------------------------------------------------------------------

prn_get_cursor_address:

            ld      a, c
            and     0x1f
            ld      l, a    ; L = X & 31
            ld      a, b
            and     0x07    ; Нужно ограничить 3 битами
            rrca            ; Легче дойти с [0..2] до позиции [5..7]
            rrca            ; Если вращать направо
            rrca            ; ... три раза
            or      l       ; Объединив с 0..4 уже готовыми ранее
            ld      l, a    ; Загрузить новый результат в L
            ld      a, b    ; Т.к. Y[3..5] уже на месте
            and     0x18    ; Его двигать даже не надо
            or      0x40    ; Ставим видеоадрес $4000
            ld      h, a    ; И загружаем результат
            ret

; ----------------------------------------------------------------------
; Проскроллить экран вверх
; ----------------------------------------------------------------------

scroll:     push    hl
            push    de
            push    bc
            push    af

            ; Перемотка экрана наверх
            ld      hl, $4000
            ld      de, $4020
            ld      a, 3
            ld      c, 0
scroll.n3:  push    af
scroll.n2:  ld      b, 8
            push    de              ; Сохранить DE/HL
            push    hl
scroll.n1:  ld      a, (de)         ; Скопировать букву
            ld      (hl), a
            inc     h
            inc     d
            djnz    scroll.n1
            pop     hl              ; Восстановить HL/DE
            pop     de
            inc     hl
            inc     de
            ld      a, e
            and     a
            jr      nz, scroll.x1
            ld      a, d
            add     7
            ld      d, a
scroll.x1:  dec     c
            jr      nz, scroll.n2
            ld      a, h
            add     7
            ld      h, a
            pop     af
            cp      2
            jr      nz, scroll.x2
            ld      c, $e0
scroll.x2:  dec     a
            jr      nz, scroll.n3

            ; Очистка нижней строки
            xor     a
            ld      h, $50  ; Банк
            ld      c, $08  ; 8 строк
scroll.m2:  ld      l, $e0  ; 7-я строка
            ld      b, $20  ; 32 символа
scroll.m1:  ld      (hl), a ; Удалить область
            inc     hl
            djnz    scroll.m1
            dec     c       ; Здесь будет H++
            jr      nz, scroll.m2

            ; Сдвиг атрибутов
            ld      bc, 768-32
            ld      e, $20
            ; Заменить на LDIR
scroll.m3:  ex      de, hl
            ldir
            ex      de, hl

            ; Заполнить нижнюю строку атрибутов
            ld      b, $20
            ld      a, (PTR_COLOR_DEF)
scroll.m4:  ld      (hl), a
            inc     hl
            djnz    scroll.m4

            pop     af
            pop     bc
            pop     de
            pop     hl
            ret

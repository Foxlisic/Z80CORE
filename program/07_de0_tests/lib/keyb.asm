
; Данные
PTR_KBD_LATCH:      equ 5B03h
PTR_KBD_LASCII:     equ 5B0Bh

; Функции
;   kb_init()
;   kb_get()
;   kb_ascii()

; ----------------------------------------------------------------------
; Инициализация клавиатурного буфера
; ----------------------------------------------------------------------

kb_init:    ld      hl, PTR_KBD_LATCH
            ld      b, 8
            ld      a, $ff
kb_init.a1: ld      (hl), a
            inc     hl
            djnz    kb_init.a1
            xor     a
            ld      (PTR_KBD_LATCH+8), a
            ret

; ----------------------------------------------------------------------
; Получение кода символа ASCII
; ----------------------------------------------------------------------

kb_get:     ld      c, $fe
            ld      hl, PTR_KBD_LATCH
            ld      de, keyboard_codes
kb_get.n1:  ld      a, c
            in      a, ($fe)            ; Значение из порта
            ld      b, a
            xor     (hl)
            ld      (hl), b             ; Сохранить новое значение
            ld      b, 5
kb_get.n2:  rra
            jr      nc, kb_get.n3
            ld      a, 6                ; Проверить какой там был бит
            sub     b
            ld      b, a
            ld      a, (hl)
kb_get.n4:  rra
            djnz    kb_get.n4
            ld      a, (de)
            jr      nc, kb_hit          ; если там был 0, то кнопка нажата
            jr      kb_get
kb_get.n3:  inc     de
            djnz    kb_get.n2
            inc     hl
            rlc     c
            jr      c, kb_get.n1
            jr      kb_get
kb_hit:     cp      $03
            jr      c, kb_get           ; CS и SS не учитываются
            ret                         ; Тест на SHIFT

; Таблица с символами
keyboard_codes:

            ; Нижний регистр
            defb    1,'zxcv'        ; A8
            defb    'asdfg'         ; A9
            defb    'qwert'         ; A10
            defb    '12345'         ; A11
            defb    '09876'         ; A12
            defb    'poiuy'         ; A13
            defb    10,'lkjh'       ; A14
            defb    32,2,'mnb'      ; A15

; ----------------------------------------------------------------------
; Получить данные из порта $00-$01
; ----------------------------------------------------------------------

kb_ascii:   push    bc
            ld      a, (PTR_KBD_LASCII)
            ld      b, a
kb_ascii.n1:
            ld      a, $01
            in      a, ($ef)
            ld      (PTR_KBD_LASCII), a
            and     1
            xor     b
            jr      z, kb_ascii.n1
            xor     a
            in      a, ($ef)
            pop     bc
            ret

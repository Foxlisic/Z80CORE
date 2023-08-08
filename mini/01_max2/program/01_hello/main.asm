
        ; Указатель на буйзную память
; ------------------------------------------------------------------------------
        ld      l, $00
        ld      h, $80
        ld      a, (hl)
        ex      de, hl
        add     a, a
        ld      l, a
        ld      a, $04
        adc     a, a
        ld      h, a            ; hl=2*a
        ld      a, (hl)
        ld      c, a
        ld      a, l
        add     a, 1
        ld      l, a
        ld      a, h
        adc     0
        ld      h, a
        ld      b, (hl)
        ld      h, b
        ld      l, c
        jp      (hl)            ; переход к метке
; ------------------------------------------------------------------------------        

        ; Декотер
        ld      hl, $1234
        ld      a, (hl)
        ex      de, hl          ; Теперь в DE адрес PC
        ld      l, a
        ld      h, $02          ; 400h - стартовый адрес
        add     hl, hl
        ld      c, (hl)
        inc     hl
        ld      h, (hl)
        ld      l, a
        jp      (hl)

        
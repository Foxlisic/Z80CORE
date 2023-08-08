        org     $5b00

        di
        ld      a, 7
        out     ($fe), a
        ld      sp, $bfff

        ; Установить банк 7
        ld      bc, $7ffd
        ld      a, $7
        out     (c), a

repeat:

        ; Распаковка в банк 7
        ld      hl, source2
        ld      de, $c000
        call    dzx0_standard

        ; Переключимся на 7 банк
        ld      bc, $7ffd
        ld      a, $7 + $8
        out     (c), a

        ; Распаковка в банк 5
        ld      hl, source1
        ld      de, $4000
        call    dzx0_standard

        ; Переключимся на 5 банк
        ld      bc, $7ffd
        ld      a, $7 + $0
        out     (c), a

        jr      repeat

        include "dzx0_standard.asm"

; -----------------------------------------------------------------------------
source1: incbin  "screen1.scr.zx0"
source2: incbin  "screen2.scr.zx0"



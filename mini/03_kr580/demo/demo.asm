
        org     0
        ld      sp, $8000   ; 3
        jr      _start      ; 2

; Переменные для вывода на экран
cursor:
.y:     defb    0           ; Положение по X
.x:     defb    0           ; Положение по Y
.cl:    defb    0x07        ; Цвет курсора

; Обработка V-Sync прерывания
; ------------------------------------------------------------------------------

rst8:   jp      keyboad_irq

; Старт программы "биоса"
; ------------------------------------------------------------------------------

_start:

        ld      a, $07
        call    cls

        ei

R1:     ld      hl, $0000
        ld      (cursor), hl
        ld      a, (keyboad_irq.hitk)
        call    phex8

        ;call    splash_scr
        ;call    memtest
        ;call    bios_main

        jr      R1

; Подключения либрариев
; ------------------------------------------------------------------------------

        include "splash.asm"
        include "func.asm"
        include "bios.asm"
        include "sdcard.asm"

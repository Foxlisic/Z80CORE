
            org     0

            di

            ; Установить бордер
            ld      a, $07
            call    cls

            ; Очистить экран в определенный цвет
            ld      hl, $5800
            ld      a, $07
            ld      bc, $0003
cls0:       ld      (hl), a
            inc     hl
            djnz    cls0
            dec     c
            jr      nz, cls0

            ; LOCATE
            ld      hl, $1700
            call    prn_locate

            ; PRINT "Hello World"
            ld      hl, HelloWorld
            call    prn_str

            ; FOR () PRINT
            ld      a, ' '
            ld      b, 64
pt1:        call    prn_term
            inc     a
            dec     b
            jr      nz, pt1
            jr      $

; Data
; ----------------------------------------------------------------------
HelloWorld: defb    "Hello, this",10,"strange evil :]",10,"World!",10,10,0

; Libs
; ----------------------------------------------------------------------
include     "../lib/print.asm"


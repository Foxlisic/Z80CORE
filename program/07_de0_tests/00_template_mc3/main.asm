
            org     0

            di
            ld      a, $38
            call    cls
            ld      hl, HelloWorld
            call    prn_str
            jr      $

HelloWorld: defb    "Hello World",0

; Libs
; ----------------------------------------------------------------------
include     "../lib/print.asm"



; Declare
; ----------------------------------------------------------------------
PTR_CURSOR_XY:      equ  5b00h
PTR_COLOR_DEF:      equ  5b02h
PTR_KBD_LATCH:      equ  5b03h
; ----------------------------------------------------------------------

            org     0

            di
            ld      a, $38
            call    cls
            call    kb_init
            
            ld      hl, HelloWorld
            call    prn_str
            call    prn_show
            
            ; Ожидание нажатия
L1:         call    kb_get
            call    prn_print            
            jr      L1

HelloWorld: defb    "Hello World",0

; Libs
; ----------------------------------------------------------------------
include     "../lib/keyb.asm"
include     "../lib/print.asm"


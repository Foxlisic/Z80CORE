
            org     8000h

            di
            ld      sp, 0xfff0
            ld      a, 0x07
            call    cls

            ld      hl, testprogram
            ld      (_param_ip), hl

            call    decode_line
            jr      $

; Бинарные данные от x86
; ----------------------------------------------------------------------
testprogram:

            incbin  "test86.bin"

; Реальный IP (в данном случае совпадает с адресом в памяти спектрума)
_param_ip:  defw    0

; ----------------------------------------------------------------------

include     "decoder.asm"
include     "opcodes.asm"
include     "nametables.asm"
include     "routines.asm"
include     "functions.asm"


            org     0

            ld      a, $07
            call    cls
            call    sd_init

            ; --------
            ld      hl, $0000
            ld      de, $0000
            ld      bc, $5c00
            call    sd_read

            ld      hl, $5c00
            inc     (hl)

            ld      hl, $0000
            ld      de, $0000
            ld      bc, $5c00
            call    sd_write
            ; --------

            ld      b, 0
            ld      hl, $5c00
n1:         ld      a, (hl)
            inc     hl
            call    prn_hex
            djnz    n1

            jr      $

; ----------------------------------------------------------------------
include     "../lib/print.asm"
include     "../lib/sd.asm"
; ----------------------------------------------------------------------


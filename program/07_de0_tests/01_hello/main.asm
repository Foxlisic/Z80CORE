
        org     0

        xor     a
        ld      hl, $4000
        ld      bc, $001b
xa:     ld      (hl), a
        inc     hl
        inc     a
        djnz    xa
        dec     c
        jr      nz, xa
        inc     a
        jr      xa

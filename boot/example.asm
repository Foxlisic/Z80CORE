
        org     0
A:      ld      hl, $5800
        ld      bc, $0300
        ;ld      a, $8F
L2:     ld      (hl), a
        inc     a
        inc     l
        jr      nz, L2
        inc     h
        djnz    L2

        ld      hl, $4000
        ld      bc, $1800
        ;ld      a, $00
L3:     ld      (hl), a
        inc     a
        inc     l
        jr      nz, L3
        inc     h
        djnz    L3

L1:     out     (254), a
        inc     a
        ;jr      L1

        jr      A

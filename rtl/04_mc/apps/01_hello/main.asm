
        org     0

        di

        ld      b, 3
        ld      hl, $f000
        ld      a, '*'
.a:     ld      (hl), a
        inc     l
        jr      nz, .a
        inc     h
        djnz    .a
        jr      $

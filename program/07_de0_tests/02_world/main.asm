
        org     0

        ; rst #0
        jp      main
        defb    0, 0, 0, 0, 0
        ; rst #08
        defb    0, 0, 0, 0, 0, 0, 0, 0
        ; rst #10
        defb    0, 0, 0, 0, 0, 0, 0, 0
        ; rst #18
        defb    0, 0, 0, 0, 0, 0, 0, 0
        ; rst #20
        defb    0, 0, 0, 0, 0, 0, 0, 0
        ; rst #28
        defb    0, 0, 0, 0, 0, 0, 0, 0
        ; rst #30
        defb    0, 0, 0, 0, 0, 0, 0, 0
        ; rst #38
        ld      a, ($4002)
        inc     a
        ld      ($4002), a
        ei
        ret

; ----------------------------------------------------------------------
main:   ld      sp, $0000
        ld      hl, $5800
        ld      a, 0x0f
        ld      bc, $0003
aa:     ld      (hl), a
        inc     hl
        djnz    aa
        dec     c
        jr      nz, aa
        ld      a, $55
        ld      ($4001), a
        ei
        jr      $


        org     7c00h
macro   brk     {  xchg    bx, bx }
; ----------------------------------------------------------------------

        cli
        cld
        xor     ax, ax
        mov     ds, ax
        mov     es, ax
        mov     ss, ax
        mov     sp, 7c00h
        mov     ah, 42h
        mov     si, DAP
        mov     [7c00h], dl
        int     13h                 ; Прочесть программу
        jmp     800h : 0

        ; Скачать с диска нужное количество килобайтов
DAP:    dw 0010h  ; 0 | размер DAP = 16
        dw 007Fh  ; 2 | 127 секторов
        dw 0000h  ; 4 | смещение
        dw 0800h  ; 6 | сегмент
        dq 1      ; 8 | номер сектора [0..n - 1]

        ; Заполнить FFh
        times 7c00h + (446) - $ db 255

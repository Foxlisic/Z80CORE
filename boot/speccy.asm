
        org     0h
; ---------------------------------------------
include "define.asm"
; ---------------------------------------------

        cli
        mov     ax, $0013
        int     10h
        call    init
        call    load_bios
        call    init_timer
        call    do_reset
        sti
@@:     jmp     @b

; Вызов таймера
; ------------------------------------------------------------------------------

timer_handler:

        ; Отсчет времени фреймов
        rdtsc
        mov     [t_zx_frame], eax
        mov     ebx, eax
        sub     eax, [t_all_frame]  ; Высчитать разницу
        mov     [d_all_frame], eax
        mov     [t_all_frame], ebx  ; Сохранить новое значение
        ; ---
        call    draw_frame          ; Рисование фрейма
        ; ---
        rdtsc
        mov     [t_zx_copy], eax
        sub     eax, [t_zx_frame]
        mov     [t_zx_frame], eax   ; => Тактов на фрейм
        call    copy_frame
        rdtsc
        sub     eax, [t_zx_copy]
        mov     [t_zx_copy], eax    ; => Тактов на копирование фрейма
        call    draw_osd

        mov     al, $20
        out     $20, al
        out     $a0, al
        iret

; ----------------------------------------------------------------------
include "tables.asm"
include "routines.asm"
include "z80.asm"
include "io.asm"
include "video.asm"
include "ay.asm"
; ----------------------------------------------------------------------
font:   file "font.bin"
; ----------------------------------------------------------------------




; Memory Bank https://worldofspectrum.org/faq/reference/128kreference.htm

macro       brk     {  xchg    bx, bx }

P_FRM_MAX   equ     71680
P_IRQ_ROW   equ     304
IRQ_POINT   equ     (232*224+8)

; Маппинг банков памяти на блоки памяти
; ----------------------------------------------------------------------
; $0000 Bank Блок 16k
; $4000 5    -> 0 +$0000
; $8000 2    -> 1 +$0400
; $C000 0    -> 2 +$0800
;       1    -> 3
;       2    -> 1
;       3    -> 4
;       4    -> 5
;       5    -> 0
;       6    -> 6
;       7    -> 7

; Алиасы к регистрам
; ----------------------------------------------------------------------
REG_A       equ     af+1
REG_F       equ     af+0
REG_B       equ     bc+1
REG_C       equ     bc+0
REG_D       equ     de+1
REG_E       equ     de+0
REG_H       equ     hl+1
REG_L       equ     hl+0

; Биты к флагам
FLAG_C      equ     $01
FLAG_N      equ     $02
FLAG_P      equ     $04
FLAG_3      equ     $08
FLAG_H      equ     $10
FLAG_5      equ     $20
FLAG_Z      equ     $40
FLAG_S      equ     $80

macro outp p, a {

    mov     dx, p
    mov     al, a
    out     dx, al
}

macro outb p, a {
    mov     al, a
    out     p, al
}

; Сдвиги в CBh секции
macro mcsh OP {

    if OP eq sll
    shl     al, 1
    lahf
    or      al, 1           ; SLL
    else
    OP      al, 1
    lahf
    end if
    jmp     fl_shifts
}

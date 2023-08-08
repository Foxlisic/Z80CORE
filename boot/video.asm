;
; Процедура полной отрисовки окна на 70k инструкции
; С вызовом прерываний, исполнении инструкции
; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

draw_frame:

        ; 48; 72; 72+128; 224
        mov     [ppu_x], word -56
        mov     [ppu_y], word -60
        mov     [t_st],  dword 0
        mov     [irq_match], byte 0
        mov     di, word -56*2 - 60*320

; Исполнение очередной инструкции
.next_instr:

        push    di
        call    trdos_handler
        call    instr
        add     [t_st], ebp
        pop     di

        ; Нарисовать несколько точек
        push    si
        mov     dx, [ppu_x]
        mov     si, [ppu_y]

        ; Точка вызова IRQ
        ; if (t_states_cycle > (irq_row*232+8) && req_int)
        cmp     [t_st], dword IRQ_POINT
        jbe     .ploop
        cmp     [irq_match], byte 0
        jne     .ploop
        mov     [irq_match], byte 1
        call    do_interrupt

.ploop:

        ; Тест такта AY (в 32 раза медленнее CPU)
        dec     byte [ay_count]
        jne     .scr
        mov     byte [ay_count], 32
        call    ay_tick

        ; if (x >= 0 && x < (320/2) && y >= 0 && y < 200)
.scr:   cmp     dx, 160
        jnb     .next_cycle
        cmp     si, 200
        jnb     .next_cycle

        mov     ax, dx
        mov     bx, si

        ; if (x >= 16 && x < 16 + 128 && y >= 4 && y < 4+192)
        sub     ax, 16          ; paper.x=32
        cmp     ax, 128
        jnb     .border
        sub     bx, 4           ; paper.y=4
        cmp     bx, 192
        jb      .paper

.border:

        ; Рисуется бордер [2x точки на 1 CPU такт]
        push    es
        mov     es, [es_back]
        mov     al, [border_cl]
        stosb
        stosb
        pop     es
        jmp     .next_cycle_nodi

.paper:

        ; Чтобы char рисовался только 1 раз
        ; if ((ppu_x - 72) & 3 == 0)
        test    ax, 11b
        jne     .next_cycle

        ; BX(Y)=0..191; AX=0..127
        push    es
        shr     ax, 2                   ; X >>= 2
        shl     bx, 1                   ; Для извлечения из таблицы адресов
        mov     cx, [NT_addr + bx]
        add     cx, ax                  ; BASE = NT[Y] + (X>>2)
        shr     bx, 4
        shl     bx, 5
        add     bx, ax                  ; BX = 32*(Y>>3)
        mov     es, [vidbase]           ; ES: Активная страница
        xchg    bx, cx
        mov     ah, byte [es:bx]        ; Чтение битовой маски (видеоданные)
        xchg    bx, cx
        movzx   ebx, byte [es:bx+$1800] ; Чтение атрибутов (BL)
        and     bl, [flash]             ; Включить или выключить FLASH
        mov     bx, [NT_attr + 2*ebx]   ; Получение Fore/Back для атрибута
        mov     es, [es_back]
        mov     cx, 8                   ; Рендеринг 8 бит
.bit:   shl     ah, 1
        mov     al, bh
        jnb     @f
        mov     al, bl
@@:     stosb
        loop    .bit
        pop     es
        sub     di, 8
; --------------------------------------
.next_cycle:
        add     di, 2
.next_cycle_nodi:
        inc     dx
        cmp     dx, (224-56)
        jne     @f
        add     di, word -224*2 + 320
        mov     dx, -56
        inc     si
@@:     dec     bp
        jne     .ploop
        mov     [ppu_x], dx
        mov     [ppu_y], si
        pop     si

.next:  ; Проверить окончание фрейма
        cmp     dword [t_st], P_FRM_MAX
        jbe     .next_instr

        ; Перещелкивание FLASH
        inc     byte [flash_cnt]
        cmp     byte [flash_cnt], 25
        jne     @f
        xor     byte [flash], 0x80
        mov     byte [flash_cnt], 0
@@:     ret

; Другие процедуры
; ------------------------------------------------------------------------------

; Перебросить кадр
copy_frame:

        push    ds es si
        mov     es, [es_a000]
        mov     ds, [es_back]
        xor     si, si
        xor     di, di
        mov     cx, 16384
        rep     movsd
        pop     si es ds
        ret

; AL-что печатать
pchar:  push    ax bx cx dx di es
        mov     es, [prn_buf]
        imul    di, [cursor+2], 320
        add     di, [cursor]
        movzx   bx, al
        shl     bx, 3
        mov     dx, 8
.row:   mov     cx, 8
        mov     ah, [font + bx]
        inc     bx
.col:   shl     ah, 1
        jnb     @f
        mov     al, [fore_cl]
        mov     [es:di+321], byte 0     ; Тень
        mov     [es:di], al
@@:     inc     di
        loop    .col
        add     di, 320-8
        dec     dx
        jne     .row
        add     [cursor], word 8        ; X += 8
        cmp     [cursor], word 320
        jb      .exit
        mov     [cursor], word 0
        add     [cursor+2], word 8      ; Y += 8
        cmp     [cursor+2], word 200
        jb      .exit
        sub     [cursor+2], word 8
        mov     di, 0                   ; ScrollUP
        mov     cx, 320*192
.up:    mov     al, [es:di+320*8]
        mov     [es:di], al
        mov     [es:di+320*8], byte 0
        inc     di
        loop    .up
.exit:  pop     es di dx cx bx ax
        ret

; Печать строки из DS:BX
print:  mov     al, [bx]
        inc     bx
        and     al, al
        je      .exit
        call    pchar
        jmp     print
.exit:  ret

; Печать десятичного числа EAX => BX
; ------------------------------------------------------------------------------

get_decimal:

        mov     bx, number + 11
.rept:  and     eax, eax
        je      .exit
        xor     edx, edx
        div     dword [.v10]
        add     dl, '0'
        dec     bx
        mov     [bx], dl
        jmp     .rept
.exit:  ret
.v10:   dd      10
number: db      1,1,1,1,1,1,1,1,1,1,1,0

; Показать OSD
; ------------------------------------------------------------------------------

draw_osd:

        ; Можно и не показывать

        ; Количество затраченных тактов на фрейм
        mov     [cursor],   word 0
        mov     [cursor+2], word 200-24
        mov     eax, [t_zx_frame]
        call    get_decimal
        call    print

        ; Такты на 1/50
        mov     [cursor],   word 0
        mov     [cursor+2], word 200-16
        mov     eax, [t_zx_copy]
        call    get_decimal
        call    print

         ; Такты на 1/50
        mov     [cursor],   word 0
        mov     [cursor+2], word 200-8
        mov     eax, [d_all_frame]
        call    get_decimal
        call    print
        ret

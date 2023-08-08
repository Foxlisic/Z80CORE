
; Арифметико-логические операции и сдвиги
; ----------------------------------------------------------------------

; AH - ALU функция, AL - аргумент
do_alu:     and     ah, 7
            movzx   ebx, ah
            jmp     word [NT_alu + 2*ebx]
do_add:     add     [REG_A], al
            mov     al, [REG_A]
            call    setflag_over
            ret
do_adc:     mov     ah, [REG_F]
            sahf
            adc     [REG_A], al
            mov     al, [REG_A]
            call    setflag_over
            ret
do_sub:     sub     [REG_A], al
            mov     al, [REG_A]
            call    setflag_over
            or      [REG_F], byte FLAG_N
            ret
do_sbc:     mov     ah, [REG_F]
            sahf
            sbb     [REG_A], al
            mov     al, [REG_A]
            call    setflag_over
            or      [REG_F], byte FLAG_N
            ret
do_and:     and     [REG_A], al
            mov     al, [REG_A]
            call    setflag_logic
            or      [REG_F], byte FLAG_H
            ret
do_xor:     xor     [REG_A], al
            mov     al, [REG_A]
            call    setflag_logic
            ret
do_or:      or      [REG_A], al
            mov     al, [REG_A]
            call    setflag_logic
            ret
do_cp:      cmp     [REG_A], al
            call    setflag_over
            ret

; Сдвиги в битовых операциях CBxx
; AL - входящий/исходящий операнд
do_rlc:     mcsh    rol ; 0
do_rrc:     mcsh    ror ; 1
do_rl:      mcsh    rcl ; 2
do_rr:      mcsh    rcr ; 3
do_sla:     mcsh    shl ; 4
do_sra:     mcsh    sar ; 5
do_sll:     mcsh    sll ; 6
do_srl:     mcsh    shr ; 7

; Установка флагов после операции
fl_shifts:  and     ah, 11000101b   ; N=0,H=0; SZPC
            mov     bh, al          ; XY
            and     bh, 00101000b
            or      bh, ah
            mov     [REG_F], bh
            ret

; ----------------------------------------------------------------------
; Чтение из памяти AL=(DI)
; ----------------------------------------------------------------------

read:       cmp     di, $4000           ; Банки памяти?
            jb      .rom
            cmp     di, $c000
            jb      .ram
            mov     al, [es:di+$4000]   ; Банк памяти
            ret
.ram:       mov     al, [gs:di-$4000]   ; Банк RAM 5,2
            ret
.rom:       mov     al, [fs:di]         ; ROM можно выбрать
            ret

; ----------------------------------------------------------------------
; Запись в память (DI)=AL
; ----------------------------------------------------------------------

write:      cmp     di, $4000
            jb      .rom
            cmp     di, $c000
            jb      .ram
            mov     [es:di+$4000], al   ; Банк памяти
            ret
.ram:       mov     [gs:di-$4000], al   ; MEM
.rom:       ret

; ----------------------------------------------------------------------
; Сброс процессора
; ----------------------------------------------------------------------

do_reset:   mov     dword [bc], 0
            mov     dword [de], 0
            mov     dword [hl], 0
            mov     word [stk], 0
            mov     word [ix], 0
            mov     word [iy], 0
            mov     byte [imode], 0
            mov     byte [rdram], 0
            mov     byte [rdram7], 0
            mov     word [iff], 0
            mov     byte [flash], $FF
            mov     byte [pch], $FF
            mov     byte [prefix], $00
            xor     si, si

            ; Назначение цветов
            mov     cx, 16
            mov     dx, 968
            xor     ax, ax
            out     dx, al
            inc     dx
            mov     bx, zxcolor
@@:         mov     al, [bx]
            shr     al, 2
            out     dx, al
            mov     al, [bx+1]
            shr     al, 2
            out     dx, al
            mov     al, [bx+2]
            shr     ax, 2
            out     dx, al
            add     bx, 3
            loop    @b

            ; Настройка окружения
            call    sel_vid5        ; По умолчанию показывается из банка 5
            call    set_rom3        ; set_48k -> Пока что по умолчанию 48K
            ret

; Расчет флагов после инкремента или декремента
; ------------------------------------------------------------------------------
flag_incdec:

            mov     bh, [REG_F]
            mov     bl, al
            lahf
            jno     .clr
            ;           SZ5H3P-C
            or      bh, 00000100b       ; OF=1
            jmp     short .next
.clr:       and     bh, 11111011b       ; OF=0
.next:      and     ah, 11010000b       ; SZ,A
            and     bl, 00101000b       ; 5/3 Undoc
            and     bh, 00000101b       ; Prev.C
            or      ah, bl
            or      ah, bh              ; Overflow + OldC
            mov     byte [REG_F], ah
            ret

; Работа с R16/R8
; ----------------------------------------------------------------------

; Получение адреса регистра R16
get_r16:    movzx   bx, al
            shr     bl, 3
            and     bl, 06h
            mov     bx, [NT_r16m + bx]
            ret

; Получение адреса регистров BC,DE,HL,SP
gethreg:    movzx   bx, al
            shr     bl, 3
            and     bl, 06h
            mov     bx, [NT_r16h + bx]
            ret

; Чтение из регистра или памяти HL => AL
get_r8:     and     al, 7
            cmp     al, 6
            je      .hl
            movzx   ebx, al
            mov     bx, [NT_r8 + 2*ebx]
            mov     al, [bx]
            ret

; Указатель в память
.hl:        mov     di, [xptr]
            call    read
            ret

; Регистр AL, значение AH
put_r8:     and     al, 7
            cmp     al, 6
            je      .hl
            movzx   ebx, al
            mov     bx, [NT_r8 + 2*ebx]
            mov     [bx], ah
            ret

; Указатель в память
.hl:        mov     di, [xptr]
            mov     al, ah
            call    write
            ret

; Считывание +D для IX/IY
aptr:       cmp     [prefix], byte 0
            je      .no
            push    ax
            and     al, 7
            cmp     al, 6
            jne     @f          ; Только при (IX+d)
            call    fetchb
            cbw
            add     [xptr], ax
            add     bp, 4
@@:         pop     ax
.no:        ret

; Вернуть IX/IY обратно
revert_xx:  cmp     [prefix], byte 0
            je      .no
            push    ax
            mov     ax, [hl]
            cmp     [prefix], byte 2
            je      .iy
            mov     [ix], ax
            jmp     .do
.iy:        mov     [iy], ax
.do:        mov     ax, [hltmp]             ; Восстановить значения
            mov     [hl], ax
            mov     [prefix], byte 0
            pop     ax
.no:        ret

; 0=NZ,1=Z,2=NC,3=C
; 4=PO,5=PE,6=P,7=M

; Если условие совпадает, то AL=1
getcond:    shr     al, 3
            and     al, 7
            movzx   bx, al
            shr     bx, 1
            mov     cl, [NT_flags + bx]
            mov     ah, [REG_F]
            shr     ah, cl
            and     ax, 0101h
            xor     al, ah
            xor     al, 1
            ret

; ----------------------------------------------------------------------

; Флаги с PARITY
setflag_logic:

            lahf    ;   SZ5H3P-C
            mov     bl, al
            and     ah, 11000100b       ; SZ/A/PC
            and     bl, 00101000b
            or      ah, bl
            mov     byte [REG_F], ah
            ret

; Флаги с OVERFLOW
setflag_over:

            mov     bl, al
            lahf
            jno     .clr
            ;           SZ5H3P-C
            or      ah, 00000100b       ; OF=1
            jmp     short .next
.clr:       and     ah, 11111011b       ; OF=0
.next:      and     ah, 11010101b       ; SZAOC
            and     bl, 00101000b       ; 5/3 Undoc
            or      ah, bl
            mov     byte [REG_F], ah
            ret

; Читать следующий байт
; ----------------------------------------------------------------------

fetchb:     mov     di, si
            call    read
            inc     si
            ret

fetchw:     mov     di, si
            call    read
            xchg    ah, al
            inc     di
            call    read
            xchg    ah, al
            add     si, 2
            ret

; Работа со стеком
; ----------------------------------------------------------------------

; Запись AX в стек
pushword:   mov     di, [stk]
            dec     di
            xchg    ah, al
            call    write
            dec     di
            mov     [stk], di
            xchg    ah, al
            call    write
            ret

; Извлечение из стека
popword:    mov     di, [stk]
            call    read
            xchg    ah, al
            inc     di
            call    read
            xchg    ah, al
            inc     di
            mov     [stk], di
            ret

; Переключение ROM
; ------------------------------------------------------------------------------
set_128k:   mov     fs, [rombase]       ; +0K
            ret
set_48k:    mov     ax, [rombase]
            add     ax, 1024            ; +16K
            mov     fs, ax
            ret
set_trdos:  mov     ax, [rombase]
            add     ax, 2048            ; +32K
            mov     fs, ax
            ret
set_rom3:   mov     ax, [rombase]
            add     ax, 3072            ; +48K
            mov     fs, ax
            ret

; Определить переключить TRDOS
trdos_handler:

            ; Проверить что PC.H изменился
            mov     ax, si
            cmp     ah, [pch]
            je      .exit
            mov     [pch], ah

            ; Разрешен только 48k ROM
            test    byte [p7ffd], 10h
            je      .exit

            ; Вход в TRDOS : инструкция находится в адресе 3Dh
            ; if (trdos_latch == 0 && ((PC & 0xFF00) == 0x3D00))
            cmp     [trdos_latch], byte 0
            jne     .has_trdos
            cmp     ah, 3Dh
            jne     .exit
            mov     [trdos_latch], byte 1
            call    set_trdos
            jmp     .exit

.has_trdos: ; Выход из TRDOS
            ; if (trdos_latch == 1 && (PC & 0xC000))
            mov     ax, si
            and     ah, 0xC0
            je      .exit
            mov     [trdos_latch], byte 0
            call    set_rombank
.exit:      ret

; Установка ROM-банка в зависимости от порта 7FFDh
; if (port_7ffd & 0x30) set48; else set128
set_rombank:

            cmp     [trdos_latch], byte 1
            je      .rtrdos
            mov     al, [p7ffd]
            test    al, 0x30
            je      .r128
            call    set_48k
            ret
.r128:      call    set_128k
            ret
.rtrdos:    call    set_trdos
            ret

; Установка базы, откуда будет считываться информация для видеовыхода
; ------------------------------------------------------------------------------
sel_vid5:   mov     ax, gs
            mov     [vidbase], ax       ; 5-й банк как есть
            ret
sel_vid7:   mov     ax, gs
            add     ax, 7*1024          ; 1024=16384/16
            mov     [vidbase], ax
            ret

; Вызов прерывания
; ------------------------------------------------------------------------------
do_interrupt:

            ret

; Инициализация сегментов и прерываний перед запуском
; ------------------------------------------------------------------------------

init:       ; Установка сегментов
            mov     ax, cs
            mov     ds, ax      ; CS=DS, SS=0
            add     ax, $1000
            mov     fs, ax      ; FS=BIOS
            mov     [rombase], fs
            add     ax, $1000
            mov     gs, ax      ; GS=DATA
            mov     [rambase], gs
            mov     ax, gs      ; ES=BANK (0)
            add     ax, $0800   ; Т.к. начинается память с $4000
            mov     es, ax      ; То ES + $800 будет указывать на $c000
            mov     [bnkbase], es
            ret

; Инициализировать вектор INT#8 (IRQ#0) Timer
init_timer: mov     [ss: 8*4+0], word timer_handler
            mov     [ss: 8*4+2], cs

            ; 5D36 -- 50 Hz
            mov     al, 0x34              ; 50Hz
            out     0x43, al
            mov     al, 0x36              ; lsb
            out     0x40, al
            mov     al, 0x5D              ; msb
            out     0x40, al
            ret

; Загрузка ROM 128K/48K/TRDOS
; ------------------------------------------------------------------------------

load_bios:  ; 32K
            mov     [DAP+6], fs
            mov     ah, 42h
            mov     si, DAP
            mov     dl, [ss:7C00h]
            int     13h
            jb      .error

            ; 32K
            add     [DAP+6], word 2048  ; +32K
            add     [DAP+8], word 64    ; +64 Sector
            mov     ah, 42h
            mov     dl, [ss:7C00h]
            int     13h
            jb      .error
            ret

; Фатальная ошибка
.error:     mov     bx, .mesg
            call    print
            jmp     $

.mesg:      db      "Can't load roms",0

DAP:        dw 0010h    ; 0 | размер DAP = 16
            dw 0040h    ; 2 | 3 x 16 x 512 = 48k
            dw 0000h    ; 4 | смещение
            dw 0800h    ; 6 | сегмент
            dq 128+1    ; 8 | номер сектора [0..n - 1]

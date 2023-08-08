
; ----------------------------------------------------------------------
; Исполнение инструкции
; Вход:  SI - регистр PC
; Выход: BP - количество циклов
; ----------------------------------------------------------------------

instr:      inc     byte [rdram]                ; R++
            xor     ebp, ebp
            mov     al, [iff+1]                 ; Delayed->New IFF
            mov     [iff], al
            mov     bx, [hl]
            mov     [xptr], bx                  ; Для сохранения в HL
            call    fetchb                      ; Прочесть инструкию
            movzx   bx, al
            movzx   ebx, byte [opcodes + bx]    ; NameTable ID
;brk
            call    word [nametable + 2*ebx]    ; Запуск инструкции (AL-опкод)
            ret

; ----------------------------------------------------------------------
; Исполнение инструкции
; ----------------------------------------------------------------------

; NOP
op_nop:     add     bp, 4
            ret

; LD R, nn
op_ldr16nn: call    get_r16
            call    fetchw
            mov     [bx], ax
            add     bp, 10
            ret

; LD r, N
op_ldmn:    add     bp, 3
op_ldrn:    add     bp, 7
            call    aptr
            mov     ah, al
            call    fetchb
            xchg    ah, al
            shr     al, 3
            call    put_r8
            ret

; INC r/m
op_incm:    add     bp, 7
op_incr:    add     bp, 4
            call    aptr
            shr     al, 3
            mov     ch, al
            call    get_r8
            inc     al
            mov     cl, al
            call    flag_incdec
            mov     al, ch
            mov     ah, cl
            call    put_r8
            ret

; DEC r/m
op_decm:    add     bp, 7
op_decr:    add     bp, 4
            call    aptr
            shr     al, 3
            mov     ch, al
            call    get_r8
            dec     al
            mov     cl, al
            call    flag_incdec
            mov     al, ch
            mov     ah, cl
            call    put_r8
            or      [REG_F], byte FLAG_N
            ret

; LD r, r
op_ldm:     add     bp, 3
op_ldr:     add     bp, 4
.nx:        mov     ah, al
            call    aptr
            call    revert_xx       ; Вернуть обратно HL
            call    get_r8          ; REG(AL) -> AL
            xchg    al, ah          ; AH содержит значение
            shr     al, 3
            call    put_r8          ; Запись AH в регистр [5:3]
            ret

; INC R16
op_inc16:   call    get_r16
            inc     word [bx]
            add     bp, 6
            ret

; DEC R16
op_dec16:   call    get_r16
            dec     word [bx]
            add     bp, 6
            ret

; Базовые сдвиги
op_rlca:    rol     byte [REG_A], 1
            lahf
            jmp     base_sh
op_rrca:    ror     byte [REG_A], 1
            lahf
            jmp     base_sh
op_rla:     mov     ah, [REG_F]
            sahf
            rcl     byte [REG_A], 1
            jmp     base_sh
op_rra:     mov     ah, [REG_F]
            sahf
            rcr     byte [REG_A], 1
base_sh:    mov     al, [REG_F]
            and     al, 11101100b ; H=0,N=0
            and     ah, 00000001b
            or      al, ah
            mov     [REG_F], al
            ret

; EX AF, AF'
op_exaf:    mov     ax, [REG_F]
            xchg    ax, [REG_F + 2]
            mov     [REG_F], ax
            add     bp, 4
            ret
; EI
op_ei:      mov     byte [iff+1], 11h
            add     bp, 4
            ret
; DI
op_di:      mov     byte [iff+1], 00h
            add     bp, 4
            ret

; ALU r/m
op_alum:    add     bp, 3
op_alur:    add     bp, 4
            call    aptr
            mov     ah, al
            call    get_r8
            shr     ah, 3
            call    do_alu          ; AH=FUNC, REG_A, AL
            ret

; LD (BC), A; LD (DE), A
op_ldma:    call    get_r16
            mov     di, [bx]
            mov     al, [REG_A]
            call    write
            add     bp, 7
            ret

; LD A, (BC); LD A, (DE)
op_ldam:    call    get_r16
            mov     di, [bx]
            call    read
            mov     [REG_A], al
            add     bp, 7
            ret

; ADD HL, R16
op_addhlr:  call    get_r16
            mov     ax, [hl]    ; HL
            mov     bx, [bx]    ; R
            add     al, bl
            adc     ah, bh
            mov     [hl], ax
            lahf
            mov     al, [REG_F]
            and     ah, 0001001b
            and     al, 1110100b
            or      al, ah
            mov     [REG_F], al
            add     bp, 11
            ret

; LD (nn), HL
op_ldnnhl:  call    fetchw
            xchg    ax, di
            mov     ax, [hl]
            call    write
            mov     al, ah
            inc     di
            call    write
            add     bp, 16
            ret

; LD HL, (nn)
op_ldhlnn:  call    fetchw
            xchg    ax, di
            call    read
            xchg    al, ah
            inc     di
            call    read
            xchg    al, ah
            mov     [hl], ax
            add     bp, 16
            ret

; LD (nn), A
op_ldnna:   call    fetchw
            xchg    ax, di
            mov     al, [REG_A]
            call    write
            add     bp, 13
            ret

; LD A, (nn)
op_ldann:   call    fetchw
            xchg    ax, di
            call    read
            mov     [REG_A], al
            add     bp, 13
            ret

; DJNZ *
op_djnz:    dec     byte [REG_B]
            je      .next
            call    fetchb
            cbw
            add     si, ax
            add     bp, 13
            ret
.next:      inc     si
            add     bp, 8
            ret

; Jump Relative
op_jr:      call    fetchb
            cbw
            add     si, ax
            add     bp, 12
            ret

; Переход по условию
op_jrcc:    and     al, $18
            call    getcond
            je      .skip
            call    fetchb
            cbw
            add     si, ax
            add     bp, 12
            ret
.skip:      inc     si
            add     bp, 7
            ret

; DAA -- Десятичная коррекция после сложения
op_daa:     mov     al, [REG_A]
            mov     ah, al
            mov     bl, al
            and     bl, 0Fh
            mov     cx, 6006h
            test    byte [REG_F], FLAG_N
            je      .run
            mov     cx, 0xA0FA ; -60h,-06h

            ; ------------------------------------------ ADD
            ; if (flags.H || ((A & 0x0F) > 9))
.run:       test    byte [REG_F], FLAG_H
            jne     .a06
            cmp     bl, 09h
            jbe     .second
.a06:       add     ah, cl      ; +06/-06h

            ; if (flags.C || A > 0x99)
.second:    test    byte [REG_F], FLAG_C
            jne     .a60
            cmp     al, 99h
            jbe     .next
.a60:       add     ah, ch      ; +60/-60h

            ; Set S,Z,P; H,C
.next:      push    ax
            and     ah, ah
            lahf
            and     ah, 11000100b       ; S,Z,P
            mov     bh, ah
            pop     ax
            mov     bl, ah
            and     bl, 00101000b       ; XY
            or      bh, bl
            mov     bl, [REG_F]
            and     bl, 00000010b
            or      bh, bl              ; N
            mov     bl, al
            xor     bl, ah
            and     bl, 10h
            or      bh, bl              ; H = ((A & 0x10) ^ (temp & 0x10))

            ; if (flags.C || A > 0x99)
            test    byte [REG_F], FLAG_C
            jne     .setc
            cmp     al, 99h
            jbe     .exit
.setc:      or      bh, FLAG_C
.exit:      mov     [REG_A], ah
            add     bp, 4
            ret

; One's complement
op_cpl:     not     byte [REG_A]
            mov     ax, [REG_F]     ; AH=A, AL=Flags
            and     ah, 00101000b   ; XY
            and     al, 11000101b
            or      al, 00010010b   ; H=1,N=1
            or      al, ah
            mov     [REG_F], al
            add     bp, 4
            ret

; Set Carry Flag
op_scf:     mov     ax, [REG_F]
            and     ah, 00101000b   ; XY
            and     al, 11000110b
            or      al, 00000001b   ; H=0,C=1
            or      al, ah
            mov     [REG_F], al
            add     bp, 4
            ret

; Complement Carry Flag
op_ccf:     mov     ax, [REG_F]
            and     ah, 00101000b   ; XY
            and     al, 11000101b   ; N=0
            or      al, ah
            mov     bl, al
            and     bl, 00000001b
            shl     bl, 4
            or      al, bl          ; C->H
            xor     al, 1           ; C=1-C
            mov     [REG_F], al
            add     bp, 4
            ret

; PUSH bc,de,hl,af
op_pushw:   call    gethreg
            mov     ax, [bx]
            call    pushword
            add     bp, 11
            ret

; POP bc,de,hl,af
op_popw:    call    gethreg
            call    popword
            mov     [bx], ax
            add     bp, 10
            ret

; JP <ccc>, nn
op_jpccc:   add     bp, 10
            call    getcond
            je      .skip
            call    fetchw
            mov     si, ax
            ret
.skip:      add     si, 2
            ret

; CALL <ccc>, nn
op_callccc: add     bp, 10
            call    getcond
            je      @f
            call    fetchw
            xchg    ax, si
            call    pushword
            add     bp, 7
            ret
@@:         add     si, 2
            ret

; RET <ccc>
op_retccc:  add     bp, 5
            call    getcond
            je      @f
            call    popword
            mov     si, ax
            add     bp, 6
@@:         ret

; ALU A, n
op_alun:    add     bp, 7
            call    aptr
            mov     ah, al
            call    fetchb
            shr     ah, 3
            call    do_alu
            ret

; RST #n
op_rst:     and     ax, $38
            xchg    ax, si
            call    pushword
            add     bp, 11
            ret

; JP nn
op_jpnn:    call    fetchw
            xchg    ax, si
            add     bp, 10
            ret

; RET
op_ret:     call    popword
            xchg    ax, si
            add     bp, 10
            ret

; CALL nnnn
op_call:    call    fetchw
            xchg    ax, si
            call    pushword
            add     bp, 17
            ret

; EXX -- отключить IX/IY
op_exx:     mov     ax, [bc]
            xchg    ax, [bc+2]
            mov     [bc], ax        ; EX BC, BC'
            mov     ax, [de]
            xchg    ax, [de+2]
            mov     [de], ax        ; EX DE, DE'
            mov     ax, [hl]
            xchg    ax, [hl+2]
            mov     [hl], ax        ; EX HL, HL'
            add     bp, 4
            ret

; EX (SP), HL
op_exsphl:  mov     di, [stk]
            call    read
            mov     bl, al
            mov     al, [REG_L]
            mov     [REG_L], bl
            call    write           ; SWAP L, (SP)
            inc     di

            call    read
            mov     bl, al
            mov     al, [REG_H]
            mov     [REG_H], bl
            call    write           ; SWAP H, (SP+1)
            add     bp, 19
            ret

; JP (HL)
op_jphl:    mov     si, [hl]
            add     bp, 4
            ret

; EX DE, HL -- отключить IX/IY
op_exdehl:  mov     ax, [hl]
            xchg    ax, [de]
            mov     [hl], ax
            add     bp, 4
            ret

; LD SP, HL
op_ldsphl:  mov     ax, [hl]
            mov     [stk], ax
            add     bp, 6
            ret

; OUT (n), A
op_outna:   call    fetchb
            mov     bh, [REG_A]
            mov     bl, al
            mov     al, bh
            call    do_out      ; BX-port, AL-value
            add     bp, 11
            ret

; IN A, (n)
op_inan:    call    fetchb
            mov     bh, [REG_A]
            mov     bl, al
            call    do_in
            mov     [REG_A], al
            add     bp, 11
            ret

; HALT
op_halt:    dec     si              ; PC--
            add     bp, 4
            ret

; BITs Prefix
; ------------------------------------------------------------------------------

op_cb:      inc     byte [rdram]
            call    fetchb              ; Получение опкода
            add     bp, 8               ; +8T
            mov     dl, al              ; Сохранить опкод
            mov     cl, al
            shr     cl, 3
            and     cl, 7               ; Номер бита [5:3]
            mov     ch, 1
            shl     ch, cl              ; CH = 1 << ((opcode & 0x38) >> 3)
            ; IX читает всегда с памяти
            cmp     [prefix], byte 0
            je      .read
            mov     al, 6
            call    fetchb
            cbw
            add     [xptr], ax
            mov     di, [xptr]
            call    read                ; Получить данные из памяти
            call    revert_xx
            add     bp, 15
            jmp     .exec
.read:      and     al, 7
            cmp     al, 6
            jne     @f
            add     bp, 7               ; Операнд (HL) добавляет +7T
            call    get_r8
.exec:      movzx   bx, dl
            and     bl, $c0
            shr     bl, 5
            jmp     word [NT_bits + bx]     ; Переход на процедуру

; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Операции сдвига
op_bit00:   movzx   ebx, dl
            shr     bl, 3
            and     bl, 7
            call    word [NT_bt00 + 2*ebx]
            mov     ah, al
            mov     al, dl
            call    put_r8
            ret

; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Инструкции BIT
op_bit40:   mov     bl, al              ; Результат (AH) или HPTR
            and     dl, 7
            cmp     dl, 6
            jne     @f
            sub     bp, 3               ; Если (HL)
@@:         mov     bh, [REG_F]
            and     bh, 11000101b       ; N=0
            and     bl, 00101000b
            or      bh, 00010000b       ; H=1
            or      bh, bl              ; Обновить Y,X
            and     al, ch              ; Z=!(R & (1 << bit_number))
            jne     .clr
            or      bh, 01000100b       ; Z=1, P=1, если бит нулевой
            jmp     .sf
.clr:       and     bh, 10111011b       ; Z=0, P=0, в ином случае
.sf:        cmp     cl, 7               ; BitNumber=7?
            jne     .s0                 ; Если нет, то SF=0
            test    bh, 6               ; ZF==0?
            je      .s0                 ; Если да, то SF=0
            or      bh, 10000000b       ; S=1 если BitNumber=7 && ZF=1
            jmp     .wbbt
.s0:        and     bh, 01111111b       ; S=0
.wbbt:      mov     [REG_F], bh
            ret

; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ RES
op_bit80:   not     ch
            and     al, ch
            mov     ah, al
            mov     al, dl
            call    put_r8
            ret

; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ SET
op_bitc0:   or      al, ch
            mov     ah, al
            mov     al, dl
            call    put_r8
            ret

; ------------------------------------------------------------------------------

op_ed:

; Префиксированные инструкции: замещается HL на IX/IY
; ------------------------------------------------------------------------------
op_ix:      mov     [prefix], byte 1
            mov     ax, [ix]
            mov     bx, [hl]
            jmp     op_prefix
op_iy:      mov     [prefix], byte 2
            mov     ax, [iy]
            mov     bx, [hl]
; ------------------------------------------------------------------------------
op_prefix:  mov     [hl], ax        ; Новый IX, IY
            mov     [hltmp], bx     ; Старый HL
            mov     [xptr], ax
            inc     word [rdram]    ; R++
            add     bp, 4
            call    fetchb
            cmp     al, 0xDD        ; Вторичный IX/IY игнорируется
            je      .nop
            cmp     al, 0xFD
            je      .nop

;brk
            ; Выполнение инструкции
            movzx   ebx, al
            movzx   ebx, byte [opcodes + bx]    ; NameTable ID
            call    word [nametable + 2*ebx]    ; Запуск инструкции (AL-опкод)
.nop:       call    revert_xx
            ret


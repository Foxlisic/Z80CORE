ay_tick:

        ret

; https://wiki.osdev.org/Sound_Blaster_16
init_sb16:

        outp    0x227, 1        ; Reset port
        mov     ah, 86h
        mov     cx, 0x0000
        mov     dx, 0xFFFF
        sti
        int     15h             ; Ожидание
        cli
        outp    0x227, 0        ; Reset port
        outp    0x22C, 0xD1     ; Включить спикер

        ; DMA channel 1
        outb    0x0A, 5         ; Disable channel 1 (number of channel + 0x04)
        outb    0x0C, 1         ; Flip flop
        outb    0x0B, 0x49      ; Transfer mode (0x48-Single; 0x58-Auto) + Channel
        outb    0x83, 0x08      ; PAGE TRANSFER     (POSITION IN MEMORY 0x[xx]0000)
        outb    0x02, 0x00      ; POSITION LOW BIT  (POSITION IN MEMORY 0x0000[xx])
        outb    0x02, 0x00      ; POSITON HIGH BIT  (POSITION IN MEMORY 0x00[xx]00)
        outb    0x03, 0xFF      ; COUNT LOW BIT     (0x00[xx])
        outb    0x03, 0x0F      ; COUNT HIGH BIT    (0x[xx]00)
        outb    0x0A, 1         ; Enable channel 1

        ; Программирование SB
        outp    0x22C, 0x40     ; Set time constant
        ; Аргументы
        outp    0x22C, 0xA5     ; 10989 Hz
        outp    0x22C, 0xC0     ; 8 bit sound
        outp    0x22C, 0x00     ; Mono and unsigned sound data
        outp    0x22C, 0xFE     ; COUNT LOW BIT  - COUNT LENGTH-1 (EXAMPLE 0x0FFF SO 0x0FFE)
        outp    0x22C, 0x0F     ; COUNT HIGH BIT - COUNT LENGTH-1 (EXAMPLE 0x0FFF SO 0x0FFE)

        ; Установка IRQ
        ; 0x01=IRQ 2;  0x02=IRQ 5; 0x04=IRQ 7;  0x08=IRQ 10
        outp    0x224, 0x80     ; Запись в Mixer Port
        outp    0x225, 0x02     ; 2=IRQ5

        ; Установка Volume
        outp    0x224, 0x22
        outp    0x225, 0xFF

        ; Now transfer start
        mov     [ss: (8+5)*4+0], word sb_handle
        mov     [ss: (8+5)*4+2], cs

        ret

; ------------------------------------------------------------------------------

sb_handle:

        push    ax
        mov     al, $20
        out     $20, al
        out     $a0, al
        pop     ax
        iret

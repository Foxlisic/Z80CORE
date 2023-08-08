bios_main:

        call    .main_scr
        jr      $

.main_scr:

        ld      a, $1F
        call    cls

        ; Вывод рамки
        ld      hl, .str1
        call    print       ; Надписи
        ld      de, .frm1
        call    .FRAM1      ; Верхняя линия
        ld      b, 13
        ld      c, $b3
        call    .LINE1      ; Список меню
        ld      de, .frm2
        call    .FRAM1      ; Средняя линия
        ld      b, 2
        ld      c, 0
        call    .LINE1      ; Напоминания
        ld      de, .frm3
        call    .FRAM1      ; Предпоследняя линия
        ld      b, 3
        ld      c, 0
        call    .LINE1      ; Область помощи
        ld      de, .frm4
        call    .FRAM1      ; Нижняя

        ; Вывод меню
        call    .SHOWMENU
        ld      hl, .mnu_main_tip
        call    print


        ret

; Вывод обновления меню
.SHOWMENU:

        ld      a, $1E
        ld      (cursor.cl), a
        ld      de, .mnu_main
.M1:    ld      a, (de)
        inc     de
        ld      l, a
        ld      a, (de)
        inc     de
        ld      h, a
        ld      a, l
        or      h
        ret     z
        call    print
        jr      .M1

; Рисовать одну линию
.FRAM1: ld      a, (de)
        inc     de
        call    term        ; Символ слева
        ld      b, 40
        ld      a, (de)
        inc     de
.K1:    call    term        ; Линия слева
        djnz    .K1
        ld      a, (de)
        inc     de
        call    term        ; Символ посередине
        ld      b, 37
        ld      a, (de)
        inc     de
.K2:    call    term        ; Линия справа
        djnz    .K2
        ld      a, (de)
        inc     de
        call    term        ; Символ справа
        ret

; Линия слева и справа (и посередине)
.LINE1: ld      a, $ba
        call    term
        ld      a, 41
        ld      (cursor.x), a
        ld      a, c
        call    term
        ld      a, 79
        ld      (cursor.x), a
        ld      a, $ba
        call    term
        djnz    .LINE1
        ret

; Рамки
.frm1:  defb    $c9, $cd, $d1, $cd, $bb
.frm2:  defb    $c7, $c4, $c1, $c4, $b6
.frm3:  defb    $c7, $c4, $c4, $c4, $b6
.frm4:  defb    $c8, $cd, $cd, $cd, $bc

.str1:  defb    $7F,$1C,$00,"ROM PCI/ISA BIOS (2A59GH2B)"
        defb    $7F,$1F,$01,"CMOS SETUP UTILITY"
        defb    $7F,$1E,$02,"AWARD SOFTWARE, INC."
        defb    $7F,$00,$03,0

; Выбор главного меню
.mnu_main: defw .mm0, .mm1, .mm2, .mm3, .mm4, .mm5, .mm6, .mm7, .mm8, .mm9, .mmA, .mmB, .mmC, 0

.mm0:  defb    $7f,$05,$04,"STANDARD CMOS SETUP",0
.mm1:  defb    $7f,$05,$06,"BIOS FEATURES SETUP",0
.mm2:  defb    $7f,$05,$08,"CHIPSET FEATURES SETUP",0
.mm3:  defb    $7f,$05,$0A,"POWER MANAGEMENT SETUP",0
.mm4:  defb    $7f,$05,$0C,"PNP/PCI CONFIGURATION",0
.mm5:  defb    $7f,$05,$0E,"LOAD BIOS DEFAULTS",0
.mm6:  defb    $7f,$05,$10,"LOAD SETUP DEFAULTS",0
.mm7:  defb    $7f,$2E,$04,"INTEGRATED PERIPHERALS",0
.mm8:  defb    $7f,$2E,$06,"SUPERVISOR PASSWORD",0
.mm9:  defb    $7f,$2E,$08,"USER PASSWORD",0
.mmA:  defb    $7f,$2E,$0A,"IDE HDD AUTO DETECTION",0
.mmB:  defb    $7f,$2E,$0C,"SAVE & EXIT SETUP",0
.mmC:  defb    $7f,$2E,$0E,"EXIT WITHOUT SAVING",0

.mnu_main_tip:

    defb $FF,$1F
    defb $7F,$02,$12,"Esc : Quit"
    defb $7F,$02,$13,"F10 : Save & Exit Setup"
    defb $7F,$2B,$12,$18," ",$19," ",$1A," ",$1B,"   : Select Item"
    defb $7F,$2B,$13,"(Shift)F2 : Change Color", 0

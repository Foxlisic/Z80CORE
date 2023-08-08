; Memory Bank https://worldofspectrum.org/faq/reference/128kreference.htm
; ------------------------------------------------------------------------------

P_FRM_MAX       equ     71680
P_ROW_PPR       equ     64
P_COL_PPR       equ     200
P_IRQ_ROW       equ     304

; Алиасы к регистрам
; ------------------------------------------------------------------------------

REG_A           equ     af+1
REG_F           equ     af+0
REG_B           equ     bc+1
REG_C           equ     bc+0
REG_D           equ     de+1
REG_E           equ     de+0
REG_H           equ     hl+1
REG_L           equ     hl+0

; Биты к флагам
; ------------------------------------------------------------------------------

FLAG_C          equ     $01
FLAG_N          equ     $02
FLAG_P          equ     $04
FLAG_3          equ     $08
FLAG_H          equ     $10
FLAG_5          equ     $20
FLAG_Z          equ     $40
FLAG_S          equ     $80

; Набор регистров
; ------------------------------------------------------------------------------

RegFile:
;                   PRI     AUX
bc:             dw      $A5B1, $0000
de:             dw      $1234, $0000
hl:             dw      $5678, $0000
af:             dw      $2B00, $0000
stk:            dw      $0000        ; SP
ix:             dw      $24AB
iy:             dw      $0000
imode:          db      $00
rdram:          db      $00         ; R[6:0]
rdram7:         db      $00         ; R[7]
iff:            dw      $0000       ; LO-IFF, HI-Delay
hltmp:          dw      $0000       ; IX/IY префиксы
prefix:         db      $00
xptr:           dw      $0000
; ------------------------------------------------------------------------------
rombase:        dw      $0000       ; Сегмент с ROM-ами
rambase:        dw      $0000       ; Сегмент с RAM
bnkbase:        dw      $0000       ; Текущий сегмент банка
vidbase:        dw      $0000       ; Сегмент текущего видеобуфера (5 или 7)
es_sound:       dw      $8000       ; Где находится звуковой буфер
es_back:        dw      $8800       ; Теневой буфер (чтобы не затронуть BIOS)
es_a000:        dw      $a000       ; CONST A000h
prn_buf:        dw      $a000       ; Куда печатать символы
; ------------------------------------------------------------------------------
NT_r8:          dw      REG_B, REG_C, REG_D, REG_E, REG_H, REG_L, 0, REG_A
NT_r16m:        dw      bc, de, hl, stk
NT_r16h:        dw      bc, de, hl, af
NT_alu:         dw      do_add, do_adc, do_sub, do_sbc, do_and, do_xor, do_or, do_cp
NT_bits:        dw      op_bit00, op_bit40, op_bit80, op_bitc0
NT_bt00:        dw      do_rlc, do_rrc, do_rl, do_rr, do_sla, do_sra, do_sll, do_srl
NT_flags:       db      6,0,2,7 ; Z,C,P,S
; ------------------------------------------------------------------------------
t_st:           dd      0           ; Текущий t_state на фрейме
p7ffd:          db      255         ; Порт 7FFDh
ay_count:       db      32
border_cl:      db      7           ; Текущий цвет бордера
pch:            db      255         ; Предыдушее значение PC[15:8]
trdos_latch:    db      0           ; =1 Включен ROM TRDOS
irq_match:      db      0           ; =1 IRQ был вызван для фрейма
ppu_x:          dw      0           ; Положение луча X
ppu_y:          dw      0           ; А также Y
flash:          db      0FFh        ; 7Fh или FFh каждые 25 кадров
flash_cnt:      db      0           ; Счетчик кадров
; Печать
cursor:         dw      0, 192      ; X,Y
fore_cl:        db      15          ; Цвет символов
; Статистика
t_zx_frame:     dd      0           ; Тактов на фрейм
t_zx_copy:      dd      0           ; Тактов на копирование REP MOVSD
d_all_frame:    dd      0           ; Тактов на 1/50 сек
t_all_frame:    dd      0           ; Фиксакциия RDTSC
; ------------------------------------------------------------------------------

zxcolor:

    db      $00,$00,$00 ; 0
    db      $00,$00,$c0 ; 1
    db      $c0,$00,$00 ; 2
    db      $c0,$00,$c0 ; 3
    db      $00,$c0,$00 ; 4
    db      $00,$c0,$c0 ; 5
    db      $c0,$c0,$00 ; 6
    db      $c0,$c0,$c0 ; 7
    db      $00,$00,$00 ; 8
    db      $00,$00,$ff ; 9
    db      $ff,$00,$00 ; 10
    db      $ff,$00,$ff ; 11
    db      $00,$ff,$00 ; 12
    db      $00,$ff,$ff ; 13
    db      $ff,$ff,$00 ; 14
    db      $ff,$ff,$ff ; 15

; ------------------------------------------------------------------------------
; Конвертирование Y => ADDRESS
NT_addr:

    dw $0000, $0100, $0200, $0300, $0400, $0500, $0600, $0700
    dw $0020, $0120, $0220, $0320, $0420, $0520, $0620, $0720
    dw $0040, $0140, $0240, $0340, $0440, $0540, $0640, $0740
    dw $0060, $0160, $0260, $0360, $0460, $0560, $0660, $0760
    dw $0080, $0180, $0280, $0380, $0480, $0580, $0680, $0780
    dw $00a0, $01a0, $02a0, $03a0, $04a0, $05a0, $06a0, $07a0
    dw $00c0, $01c0, $02c0, $03c0, $04c0, $05c0, $06c0, $07c0
    dw $00e0, $01e0, $02e0, $03e0, $04e0, $05e0, $06e0, $07e0
    dw $0800, $0900, $0a00, $0b00, $0c00, $0d00, $0e00, $0f00
    dw $0820, $0920, $0a20, $0b20, $0c20, $0d20, $0e20, $0f20
    dw $0840, $0940, $0a40, $0b40, $0c40, $0d40, $0e40, $0f40
    dw $0860, $0960, $0a60, $0b60, $0c60, $0d60, $0e60, $0f60
    dw $0880, $0980, $0a80, $0b80, $0c80, $0d80, $0e80, $0f80
    dw $08a0, $09a0, $0aa0, $0ba0, $0ca0, $0da0, $0ea0, $0fa0
    dw $08c0, $09c0, $0ac0, $0bc0, $0cc0, $0dc0, $0ec0, $0fc0
    dw $08e0, $09e0, $0ae0, $0be0, $0ce0, $0de0, $0ee0, $0fe0
    dw $1000, $1100, $1200, $1300, $1400, $1500, $1600, $1700
    dw $1020, $1120, $1220, $1320, $1420, $1520, $1620, $1720
    dw $1040, $1140, $1240, $1340, $1440, $1540, $1640, $1740
    dw $1060, $1160, $1260, $1360, $1460, $1560, $1660, $1760
    dw $1080, $1180, $1280, $1380, $1480, $1580, $1680, $1780
    dw $10a0, $11a0, $12a0, $13a0, $14a0, $15a0, $16a0, $17a0
    dw $10c0, $11c0, $12c0, $13c0, $14c0, $15c0, $16c0, $17c0
    dw $10e0, $11e0, $12e0, $13e0, $14e0, $15e0, $16e0, $17e0

; Преобразование атрибута в цвет
NT_attr:

    ; Flash=0,BR=0
    dw $0000, $0001, $0002, $0003, $0004, $0005, $0006, $0007
    dw $0100, $0101, $0102, $0103, $0104, $0105, $0106, $0107
    dw $0200, $0201, $0202, $0203, $0204, $0205, $0206, $0207
    dw $0300, $0301, $0302, $0303, $0304, $0305, $0306, $0307
    dw $0400, $0401, $0402, $0403, $0404, $0405, $0406, $0407
    dw $0500, $0501, $0502, $0503, $0504, $0505, $0506, $0507
    dw $0600, $0601, $0602, $0603, $0604, $0605, $0606, $0607
    dw $0700, $0701, $0702, $0703, $0704, $0705, $0706, $0707
    ; Flash=0,BR=1
    dw $0808, $0809, $080a, $080b, $080c, $080d, $080e, $080f
    dw $0908, $0909, $090a, $090b, $090c, $090d, $090e, $090f
    dw $0a08, $0a09, $0a0a, $0a0b, $0a0c, $0a0d, $0a0e, $0a0f
    dw $0b08, $0b09, $0b0a, $0b0b, $0b0c, $0b0d, $0b0e, $0b0f
    dw $0c08, $0c09, $0c0a, $0c0b, $0c0c, $0c0d, $0c0e, $0c0f
    dw $0d08, $0d09, $0d0a, $0d0b, $0d0c, $0d0d, $0d0e, $0d0f
    dw $0e08, $0e09, $0e0a, $0e0b, $0e0c, $0e0d, $0e0e, $0e0f
    dw $0f08, $0f09, $0f0a, $0f0b, $0f0c, $0f0d, $0f0e, $0f0f
    ; Flash=1,BR=0
    dw $0000, $0100, $0200, $0300, $0400, $0500, $0600, $0700
    dw $0001, $0101, $0201, $0301, $0401, $0501, $0601, $0701
    dw $0002, $0102, $0202, $0302, $0402, $0502, $0602, $0702
    dw $0003, $0103, $0203, $0303, $0403, $0503, $0603, $0703
    dw $0004, $0104, $0204, $0304, $0404, $0504, $0604, $0704
    dw $0005, $0105, $0205, $0305, $0405, $0505, $0605, $0705
    dw $0006, $0106, $0206, $0306, $0406, $0506, $0606, $0706
    dw $0007, $0107, $0207, $0307, $0407, $0507, $0607, $0707
    ; Flash=1,BR=1
    dw $0808, $0908, $0a08, $0b08, $0c08, $0d08, $0e08, $0f08
    dw $0809, $0909, $0a09, $0b09, $0c09, $0d09, $0e09, $0f09
    dw $080a, $090a, $0a0a, $0b0a, $0c0a, $0d0a, $0e0a, $0f0a
    dw $080b, $090b, $0a0b, $0b0b, $0c0b, $0d0b, $0e0b, $0f0b
    dw $080c, $090c, $0a0c, $0b0c, $0c0c, $0d0c, $0e0c, $0f0c
    dw $080d, $090d, $0a0d, $0b0d, $0c0d, $0d0d, $0e0d, $0f0d
    dw $080e, $090e, $0a0e, $0b0e, $0c0e, $0d0e, $0e0e, $0f0e
    dw $080f, $090f, $0a0f, $0b0f, $0c0f, $0d0f, $0e0f, $0f0f


nametable:

    dw  op_nop          ; 0
    dw  op_nop          ; 1
    dw  op_ldr16nn      ; 2
    dw  op_inc16        ; 3
    dw  op_dec16        ; 4
    dw  op_exaf         ; 5
    dw  op_halt         ; 6
    dw  op_di           ; 7
    dw  op_ei           ; 8
    dw  op_ldr          ; 9
    dw  op_ldm          ; 10
    dw  op_ldrn         ; 11
    dw  op_ldmn         ; 12
    dw  op_incr         ; 13
    dw  op_incm         ; 14
    dw  op_decr         ; 15
    dw  op_decm         ; 16
    dw  op_alur         ; 17
    dw  op_alum         ; 18
    dw  op_ldma         ; 19
    dw  op_ldam         ; 20
    dw  op_addhlr       ; 21
    dw  op_rlca         ; 22
    dw  op_rrca         ; 23
    dw  op_rla          ; 24
    dw  op_rra          ; 25
    dw  op_ldnnhl       ; 26
    dw  op_ldhlnn       ; 27
    dw  op_ldnna        ; 28
    dw  op_ldann        ; 29
    dw  op_djnz         ; 30
    dw  op_jr           ; 31
    dw  op_jrcc         ; 32
    dw  op_daa          ; 33
    dw  op_cpl          ; 34
    dw  op_scf          ; 35
    dw  op_ccf          ; 36
    dw  op_pushw        ; 37
    dw  op_popw         ; 38
    dw  op_jpccc        ; 39
    dw  op_retccc       ; 40
    dw  op_alun         ; 41
    dw  op_callccc      ; 42
    dw  op_rst          ; 43
    dw  op_jpnn         ; 44
    dw  op_ret          ; 45
    dw  op_call         ; 46
    dw  op_exx          ; 47
    dw  op_exsphl       ; 48
    dw  op_jphl         ; 49
    dw  op_exdehl       ; 50
    dw  op_ldsphl       ; 51
    dw  op_outna        ; 52
    dw  op_inan         ; 53
    dw  op_cb           ; 54
    dw  op_ed           ; 55
    dw  op_ix           ; 56
    dw  op_iy           ; 57

; БАЗОВЫЙ НАБОР ИНСТРУКЦИИ
; ------------------------------------------------------------------------------

opcodes:

    db  1               ; 00 NOP
    db  2               ; 01 LD BC, nn
    db  19              ; 02 LD (BC), A
    db  3               ; 03 INC BC
    db  13              ; 04 INC B
    db  15              ; 05 DEC B
    db  11              ; 06 LD B, n
    db  22              ; 07 RLCA
    db  5               ; 08 EX AF, AF'
    db  21              ; 09 ADD HL, BC
    db  20              ; 0A LD A, (BC)
    db  4               ; 0B DEC BC
    db  13              ; 0C INC C
    db  15              ; 0D DEC C
    db  11              ; 0E LD C, n
    db  23              ; 0F RRCA
    db  30              ; 10 DJNZ *
    db  2               ; 11 LD DE, nn
    db  19              ; 12 LD (DE), A
    db  3               ; 13 INC DE
    db  13              ; 14 INC D
    db  15              ; 15 DEC D
    db  11              ; 16 LD D, n
    db  24              ; 17 RLA
    db  31              ; 18 JR *
    db  21              ; 19 ADD HL, DE
    db  20              ; 1A LD A, (DE)
    db  4               ; 1B DEC DE
    db  13              ; 1C INC E
    db  15              ; 1D DEC E
    db  11              ; 1E LD E, n
    db  25              ; 1F RRA
    db  32              ; 20 JR NZ, *
    db  2               ; 21 LD HL, nn
    db  26              ; 22 LD (nn), HL
    db  3               ; 23 INC HL
    db  13              ; 24 INC H
    db  15              ; 25 DEC H
    db  11              ; 26 LD H, n
    db  33              ; 27 DAA
    db  32              ; 28 JR Z, *
    db  21              ; 29 ADD HL, HL
    db  27              ; 2A LD HL, (nn)
    db  4               ; 2B DEC HL
    db  13              ; 2C INC L
    db  15              ; 2D DEC L
    db  11              ; 2E LD L, n
    db  34              ; 2F CPL
    db  32              ; 30 JR NC, *
    db  2               ; 31 LD SP, nn
    db  28              ; 32 LD (nn), A
    db  3               ; 33 INC SP
    db  14              ; 34 INC (HL)
    db  16              ; 35 DEC (HL)
    db  12              ; 36 LD (HL), n
    db  35              ; 37 SCF
    db  32              ; 38 JR C, *
    db  21              ; 39 ADD HL, SP
    db  29              ; 3A LD A, (nn)
    db  4               ; 3B DEC SP
    db  13              ; 3C INC A
    db  15              ; 3D DEC A
    db  11              ; 3E LD A, n
    db  36              ; 3F CCF
    db  9               ; 40 LD B, B
    db  9               ; 41 LD B, C
    db  9               ; 42 LD B, D
    db  9               ; 43 LD B, E
    db  9               ; 44 LD B, H
    db  9               ; 45 LD B, L
    db  10              ; 46 LD B, (HL)
    db  9               ; 47 LD B, A
    db  9               ; 48 LD C, B
    db  9               ; 49 LD C, C
    db  9               ; 4A LD C, D
    db  9               ; 4B LD C, E
    db  9               ; 4C LD C, H
    db  9               ; 4D LD C, L
    db  10              ; 4E LD C, (HL)
    db  9               ; 4F LD C, A
    db  9               ; 50 LD D, B
    db  9               ; 51 LD D, C
    db  9               ; 52 LD D, D
    db  9               ; 53 LD D, E
    db  9               ; 54 LD D, H
    db  9               ; 55 LD D, L
    db  10              ; 56 LD D, (HL)
    db  9               ; 57 LD D, A
    db  9               ; 58 LD E, B
    db  9               ; 59 LD E, C
    db  9               ; 5A LD E, D
    db  9               ; 5B LD E, E
    db  9               ; 5C LD E, H
    db  9               ; 5D LD E, L
    db  10              ; 5E LD E, (HL)
    db  9               ; 5F LD E, A
    db  9               ; 60 LD H, B
    db  9               ; 61 LD H, C
    db  9               ; 62 LD H, D
    db  9               ; 63 LD H, E
    db  9               ; 64 LD H, H
    db  9               ; 65 LD H, L
    db  10              ; 66 LD H, (HL)
    db  9               ; 67 LD H, A
    db  9               ; 68 LD L, B
    db  9               ; 69 LD L, C
    db  9               ; 6A LD L, D
    db  9               ; 6B LD L, E
    db  9               ; 6C LD L, H
    db  9               ; 6D LD L, L
    db  10              ; 6E LD L, (HL)
    db  9               ; 6F LD L, A
    db  10              ; 70 LD (HL), B
    db  10              ; 71 LD (HL), C
    db  10              ; 72 LD (HL), D
    db  10              ; 73 LD (HL), E
    db  10              ; 74 LD (HL), H
    db  10              ; 75 LD (HL), L
    db  6               ; 76 HALT
    db  10              ; 77 LD (HL), A
    db  9               ; 78 LD A, B
    db  9               ; 79 LD A, C
    db  9               ; 7A LD A, D
    db  9               ; 7B LD A, E
    db  9               ; 7C LD A, H
    db  9               ; 7D LD A, L
    db  10              ; 7E LD A, (HL)
    db  9               ; 7F LD A, A
    db  17              ; 80 ADD B
    db  17              ; 81 ADD C
    db  17              ; 82 ADD D
    db  17              ; 83 ADD E
    db  17              ; 84 ADD H
    db  17              ; 85 ADD L
    db  18              ; 86 ADD (HL)
    db  17              ; 87 ADD A
    db  17              ; 88 ADC B
    db  17              ; 89 ADC C
    db  17              ; 8A ADC D
    db  17              ; 8B ADC E
    db  17              ; 8C ADC H
    db  17              ; 8D ADC L
    db  18              ; 8E ADC (HL)
    db  17              ; 8F ADC A
    db  17              ; 90 SUB B
    db  17              ; 91 SUB C
    db  17              ; 92 SUB D
    db  17              ; 93 SUB E
    db  17              ; 94 SUB H
    db  17              ; 95 SUB L
    db  18              ; 96 SUB (HL)
    db  17              ; 97 SUB A
    db  17              ; 98 SBC B
    db  17              ; 99 SBC C
    db  17              ; 9A SBC D
    db  17              ; 9B SBC E
    db  17              ; 9C SBC H
    db  17              ; 9D SBC L
    db  18              ; 9E SBC (HL)
    db  17              ; 9F SBC A
    db  17              ; A0 AND B
    db  17              ; A1 AND C
    db  17              ; A2 AND D
    db  17              ; A3 AND E
    db  17              ; A4 AND H
    db  17              ; A5 AND L
    db  18              ; A6 AND (HL)
    db  17              ; A7 AND A
    db  17              ; A8 XOR B
    db  17              ; A9 XOR C
    db  17              ; AA XOR D
    db  17              ; AB XOR E
    db  17              ; AC XOR H
    db  17              ; AD XOR L
    db  18              ; AE XOR (HL)
    db  17              ; AF XOR A
    db  17              ; B0 OR B
    db  17              ; B1 OR C
    db  17              ; B2 OR D
    db  17              ; B3 OR E
    db  17              ; B4 OR H
    db  17              ; B5 OR L
    db  18              ; B6 OR (HL)
    db  17              ; B7 OR A
    db  17              ; B8 CP B
    db  17              ; B9 CP C
    db  17              ; BA CP D
    db  17              ; BB CP E
    db  17              ; BC CP H
    db  17              ; BD CP L
    db  18              ; BE CP (HL)
    db  17              ; BF CP A
    db  40              ; C0 RET NZ
    db  38              ; C1 POP BC
    db  39              ; C2 JP NZ, nn
    db  44              ; C3 JP nn
    db  42              ; C4 CALL NZ, nn
    db  37              ; C5 PUSH BC
    db  41              ; C6 ADD n
    db  43              ; C7 RST #00
    db  40              ; C8 RET Z
    db  45              ; C9 RET
    db  39              ; CA JP Z, nn
    db  54              ; CB <BIT>
    db  42              ; CC CALL Z, nn
    db  46              ; CD CALL nn
    db  41              ; CE ADC n
    db  43              ; CF RST #08
    db  40              ; D0 RET NC
    db  38              ; D1 POP DE
    db  39              ; D2 JP NC, nn
    db  52              ; D3 OUT (n), A
    db  42              ; D4 CALL NC, nn
    db  37              ; D5 PUSH DE
    db  41              ; D6 SUB n
    db  43              ; D7 RST #10
    db  40              ; D8 RET C
    db  47              ; D9 EXX
    db  39              ; DA JP C, nn
    db  53              ; DB IN A, (n)
    db  42              ; DC CALL C, nn
    db  56              ; DD <IX>
    db  41              ; DE SBC n
    db  43              ; DF RST #18
    db  40              ; E0 RET PO
    db  38              ; E1 POP HL
    db  39              ; E2 JP PO, nn
    db  48              ; E3 EX (SP), HL
    db  42              ; E4 CALL PO, nn
    db  37              ; E5 PUSH HL
    db  41              ; E6 AND n
    db  43              ; E7 RST #20
    db  40              ; E8 RET PE
    db  49              ; E9 JP (HL)
    db  39              ; EA JP PE, nn
    db  50              ; EB EX DE, HL
    db  42              ; EC CALL PE, nn
    db  55              ; ED <MISC>
    db  41              ; EE XOR n
    db  43              ; EF RST #28
    db  40              ; F0 RET P
    db  38              ; F1 POP AF
    db  39              ; F2 JP P, nn
    db  7               ; F3 DI
    db  42              ; F4 CALL P, nn
    db  37              ; F5 PUSH AF
    db  41              ; F6 OR n
    db  43              ; F7 RST #30
    db  40              ; F8 RET M
    db  51              ; F9 LD SP, HL
    db  39              ; FA JP M, nn
    db  8               ; FB EI
    db  42              ; FC CALL M, nn
    db  57              ; FD <IY>
    db  41              ; FE CP n
    db  43              ; FF RST #38

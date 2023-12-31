; Таблица мнемоник
opcodes_table:

    ;           0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
    defb        1,  1,  1,  1,  1,  1,  9, 10,  2,  2,  2,  2,  2,  2,  9,  0   ; 0
    defb        3,  3,  3,  3,  3,  3,  9, 10,  4,  4,  4,  4,  4,  4,  9, 10   ; 1
    defb        5,  5,  5,  5,  5,  5,  0, 11,  6,  6,  6,  6,  6,  6,  0, 12   ; 2
    defb        7,  7,  7,  7,  7,  7,  0, 13,  8,  8,  8,  8,  8,  8,  0, 14   ; 3

    ;           0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
    defb       18, 18, 18, 18, 18, 18, 18, 18, 19, 19, 19, 19, 19, 19, 19, 19   ; 4
    defb        9,  9,  9,  9,  9,  9,  9,  9, 10, 10, 10, 10, 10, 10, 10, 10   ; 5
    defb       20, 21, 22, 23,  0,  0,  0,  0,  9, 24,  9, 24, 25, 26, 27, 28   ; 6
    defb       37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52   ; 7

    ;           0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
    defb        0,  0,  0,  0, 53, 53, 54, 54, 55, 55, 55, 55, 55, 57, 55, 10   ; 8
    defb       56, 54, 54, 54, 54, 54, 54, 54, 58, 59, 60, 61, 62, 63, 64, 65   ; 9
    defb       55, 55, 55, 55, 66, 67, 68, 69, 53, 53, 70, 71, 72, 73, 74, 75   ; A
    defb       55, 55, 55, 55, 55, 55, 55, 55, 55, 55, 55, 55, 55, 55, 55, 55   ; B

    ;           0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
    defb        0,  0, 76, 76, 83, 84, 55, 55, 85, 86, 77, 77, 87, 89, 90, 78   ; C
    defb        0,  0,  0,  0, 79, 80, 81, 82,  0,  0,  0,  0,  0,  0,  0,  0   ; D
    defb       91, 92, 93, 94, 95, 95, 96, 96, 60, 97, 97, 97, 95, 95, 96, 96   ; E
    defb       15, 88, 16, 17, 29, 30,  0,  0, 31, 32, 33, 34, 35, 36,  0,  0   ; F

; Процедуры вызова операндов
operand_table:

    ;           0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
    defb        1,  1,  1,  1,  2,  2,  5,  5,  1,  1,  1,  1,  2,  2,  5, 41   ; 0
    defb        1,  1,  1,  1,  2,  2,  5,  5,  1,  1,  1,  1,  2,  2,  5,  5   ; 1
    defb        1,  1,  1,  1,  2,  2,  0,  0,  1,  1,  1,  1,  2,  2,  0,  0   ; 2
    defb        1,  1,  1,  1,  2,  2,  0,  0,  1,  1,  1,  1,  2,  2,  0,  0   ; 3

    ;           0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
    defb        3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3   ; 4
    defb        3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3   ; 5
    defb        0,  0, 12, 13,  0,  0,  0,  0, 14, 17, 16, 18,  0,  0,  0,  0   ; 6
    defb        4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4   ; 7

    ;           0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
    defb        6,  7,  6,  8,  1,  1,  1,  1,  1,  1,  1,  1, 26, 12, 27, 28   ; 8
    defb        0, 11, 11, 11, 11, 11, 11, 11,  0,  0, 19,  0,  0,  0,  0,  0   ; 9
    defb       22, 23, 24, 25,  0,  0,  0,  0,  2,  2,  0,  0,  0,  0,  0,  0   ; A
    defb        9,  9,  9,  9,  9,  9,  9,  9, 10, 10, 10, 10, 10, 10, 10, 10   ; B

    ;           0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
    defb       35, 35, 14,  0, 12, 12, 29, 30, 21,  0, 14,  0,  0, 15,  0,  0   ; C
    defb       36, 36, 37, 37,  0,  0,  0,  0, 42, 42, 42, 42, 42, 42, 42, 42   ; D
    defb        4,  4,  4,  4, 31, 31, 33, 33, 20, 20, 19,  4, 32, 32, 34, 34   ; E
    defb        0,  0,  0,  0,  0,  0, 38, 38,  0,  0,  0,  0,  0,  0, 39, 40   ; F

; Таблица расширенных опкодов
opcodes_0f_table:

    ;           0/8     1/9     2/A     3/B     4/C     5/D     6/E     7/F
    defw        0,      0,      0,      0,      0,      0,      0,      0       ; 00
    defw        0,      0,      0,      0,      0,      0,      0,      0       ; 08
    defw        0,      0,      0,      0,      0,      0,      0,      0       ; 10
    defw        0,      0,      0,      0,      0,      0,      0,      0       ; 18
    defw        0,      0,      0,      0,      0,      0,      0,      0       ; 20
    defw        0,      0,      0,      0,      0,      0,      0,      0       ; 28
    defw        0,   ie31,      0,      0,      0,      0,      0,      0       ; 30
    defw        0,      0,      0,      0,      0,      0,      0,      0       ; 38
    defw     ie40,   ie40,   ie40,   ie40,   ie40,   ie40,   ie40,   ie40       ; 40
    defw     ie40,   ie40,   ie40,   ie40,   ie40,   ie40,   ie40,   ie40       ; 48
    defw        0,      0,      0,      0,      0,      0,      0,      0       ; 50
    defw        0,      0,      0,      0,      0,      0,      0,      0       ; 58
    defw        0,      0,      0,      0,      0,      0,      0,      0       ; 60
    defw        0,      0,      0,      0,      0,      0,      0,      0       ; 68
    defw        0,      0,      0,      0,      0,      0,      0,      0       ; 70
    defw        0,      0,      0,      0,      0,      0,      0,      0       ; 78
    defw    ie80h,  ie80h,  ie80h,  ie80h,  ie80h,  ie80h,  ie80h,  ie80h       ; 80
    defw    ie80h,  ie80h,  ie80h,  ie80h,  ie80h,  ie80h,  ie80h,  ie80h       ; 88
    defw        0,      0,      0,      0,      0,      0,      0,      0       ; 90
    defw        0,      0,      0,      0,      0,      0,      0,      0       ; 98
    defw        0,      0,      0,      0,      0,      0,      0,      0       ; A0
    defw        0,      0,      0,      0,      0,      0,      0,   ieaf       ; A8
    defw        0,      0,      0,      0,      0,      0,   ieb6,   ieb6       ; B0
    defw        0,      0,      0,      0,      0,      0,   iebe,   iebe       ; B8
    defw        0,      0,      0,      0,      0,      0,      0,      0       ; C0
    defw        0,      0,      0,      0,      0,      0,      0,      0       ; C8
    defw        0,      0,      0,      0,      0,      0,      0,      0       ; D0
    defw        0,      0,      0,      0,      0,      0,      0,      0       ; D8
    defw        0,      0,      0,      0,      0,      0,      0,      0       ; E0
    defw        0,      0,      0,      0,      0,      0,      0,      0       ; E8
    defw        0,      0,      0,      0,      0,      0,      0,      0       ; F0
    defw        0,      0,      0,      0,      0,      0,      0,      0       ; F8

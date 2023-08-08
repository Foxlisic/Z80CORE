; ------------------------------------------------------------------------------

; BX-port, AL-add
do_out:     test    bl, 1
            je      .set_border
            ret

; Установка бордера как минимум, а также запись на ленту
.set_border:

            and     al, 7
            mov     [border_cl], al
            ret

; BX-port, AL-result
do_in:      mov     al, 0xFF
            ret


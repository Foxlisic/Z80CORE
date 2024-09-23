class VMX
{
protected:

    // Процессоры (для мультипроцессорной системы)
    int                 cpu_current = 0;
    uint8_t             compat = 1;
    CPU                 cpu[4];
    CPU*                C;
    uint8_t             prefix;

public:

    // Память
    uint8_t     read(uint16_t a);
    void        write(uint16_t a, uint8_t b);

    // Процессор
    int         step(int core_id);
    void        cpu_put16(int reg_id, uint16_t w);
    uint16_t    cpu_get16(int reg_id);
    int         cpu_condition(int cond);
    void        cpu_update53(uint8_t data);
    void        cpu_setsf(uint8_t a);
    void        cpu_setzf(uint8_t a);
    void        cpu_setof(uint8_t a);
    void        cpu_setpf(uint8_t a);
    void        cpu_setnf(uint8_t a);
    void        cpu_setcf(uint8_t a);
    void        cpu_sethf(uint8_t a);
    uint8_t     cpu_get8(int reg_id);
    void        cpu_put8(int reg_id, uint8_t d);
    uint8_t     cpu_alu(int mode, uint8_t a, uint8_t b);
};

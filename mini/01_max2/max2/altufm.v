//synopsys translate_off
`timescale 1 ps / 1 ps

//synopsys translate_on
module altufm
(
    input   arclk,      // Запись на позитивном фронте АДРЕС
    input   ardin,      // Входящий бит адреса (MSB), первый бит старший
    input   arshft,     // =1 последовательная загрузка адреса, =0 то +1 к адресу
    output  busy,       // =1 Устройство занято
    input   drclk,      // Запись на позитивном фронте ДАННЫХ
    input   drdin,      // Входящие бит MSB
    output  drdout,     // Исходящий бит MSB
    input   drshft,     // =0 @posedge drclk, копирование из/в UFM, =1 вдвиг бита
    input   erase,      // =1 очистить блок
    output  osc,        // Тактовый осциллятор ~ 5.5 Мгц
    input   oscena,     // =1 Разрешение тактового генератора
    input   program,    // =1 Программирование UFM
    output  rtpbusy     // =1 Устройство занято программированием
);

maxii_ufm maxii_ufm_block1
(
    .arclk          (arclk),
    .ardin          (ardin),
    .arshft         (arshft),
    .bgpbusy        (rtpbusy),
    .busy           (busy),
    .drclk          (drclk),
    .drdin          (drdin),
    .drdout         (drdout),
    .drshft         (drshft),
    .erase          (erase),
    .osc            (osc),
    .oscena         (oscena),
    .program        (program),
    // synopsys translate_off
    .ctrl_bgpbusy   (1'b0),
    .devclrn        (1'b1),
    .devpor         (1'b1),
    .sbdin          (1'b0),
    .sbdout         ()
    // synopsys translate_on
);

defparam
    maxii_ufm_block1.address_width   = 9,
    maxii_ufm_block1.erase_time      = 500000000,
    maxii_ufm_block1.init_file       = "ufm.mif",
    // Копия тестовых данных 1Кб
    maxii_ufm_block1.mem1            = 512'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
    maxii_ufm_block1.mem2            = 512'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
    maxii_ufm_block1.mem3            = 512'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
    maxii_ufm_block1.mem4            = 512'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
    maxii_ufm_block1.mem5            = 512'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
    maxii_ufm_block1.mem6            = 512'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
    maxii_ufm_block1.mem7            = 512'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
    maxii_ufm_block1.mem8            = 512'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
    maxii_ufm_block1.mem9            = 512'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
    maxii_ufm_block1.mem10           = 512'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
    maxii_ufm_block1.mem11           = 512'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
    maxii_ufm_block1.mem12           = 512'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
    maxii_ufm_block1.mem13           = 512'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
    maxii_ufm_block1.mem14           = 512'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
    maxii_ufm_block1.mem15           = 512'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
    maxii_ufm_block1.mem16           = 512'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
    maxii_ufm_block1.osc_sim_setting = 180000,
    maxii_ufm_block1.program_time    = 1600000,
    maxii_ufm_block1.lpm_type        = "maxii_ufm";

endmodule
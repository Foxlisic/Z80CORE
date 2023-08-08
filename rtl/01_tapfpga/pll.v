// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
module pll
(
    input  wire clk,
    output wire m3h,
    output wire locked
);

altpll altpll_component
(
    .inclk         ({1'h0, clk}),
    .clk           ({m3h}),
    .activeclock   (),
    .areset        (1'b0),
    .clkbad        (),
    .clkena        ({6{1'b1}}),
    .clkloss       (),
    .clkswitch     (1'b0),
    .configupdate  (1'b0),
    .enable0       (),
    .enable1       (),
    .extclk        (),
    .extclkena     ({1{1'b1}}),
    .fbin          (1'b1),
    .fbmimicbidir  (),
    .fbout         (),
    .fref          (),
    .icdrclk       (),
    .locked        (locked),
    .pfdena        (1'b1),
    .phasecounterselect ({1{1'b1}}),
    .phasedone     (),
    .phasestep     (1'b1),
    .phaseupdown   (1'b1),
    .pllena        (1'b1),
    .scanaclr      (1'b0),
    .scanclk       (1'b0),
    .scanclkena    (1'b1),
    .scandata      (1'b0),
    .scandataout   (),
    .scandone      (),
    .scanread      (1'b0),
    .scanwrite     (1'b0),
    .sclkout0      (),
    .sclkout1      (),
    .vcooverrange  (),
    .vcounderrange ()
);
defparam
altpll_component.bandwidth_type     = "AUTO",

altpll_component.clk0_multiply_by   = 7,
altpll_component.clk0_divide_by     = 200,
altpll_component.clk0_duty_cycle    = 50,
altpll_component.clk0_phase_shift   = "0",

altpll_component.inclk0_input_frequency = 10000,
altpll_component.intended_device_family = "Cyclone III",
altpll_component.lpm_type           = "altpll",
altpll_component.operation_mode     = "NO_COMPENSATION",
altpll_component.pll_type           = "AUTO",
altpll_component.port_activeclock   = "PORT_UNUSED",
altpll_component.port_areset        = "PORT_UNUSED",
altpll_component.port_clkbad0       = "PORT_UNUSED",
altpll_component.port_clkbad1       = "PORT_UNUSED",
altpll_component.port_clkloss       = "PORT_UNUSED",
altpll_component.port_clkswitch     = "PORT_UNUSED",
altpll_component.port_configupdate  = "PORT_UNUSED",
altpll_component.port_fbin          = "PORT_UNUSED",
altpll_component.port_inclk0        = "PORT_USED",
altpll_component.port_inclk1        = "PORT_UNUSED",
altpll_component.port_locked        = "PORT_UNUSED",
altpll_component.port_pfdena        = "PORT_UNUSED",
altpll_component.port_phasecounterselect = "PORT_UNUSED",
altpll_component.port_phasedone     = "PORT_UNUSED",
altpll_component.port_phasestep     = "PORT_UNUSED",
altpll_component.port_phaseupdown   = "PORT_UNUSED",
altpll_component.port_pllena        = "PORT_UNUSED",
altpll_component.port_scanaclr      = "PORT_UNUSED",
altpll_component.port_scanclk       = "PORT_UNUSED",
altpll_component.port_scanclkena    = "PORT_UNUSED",
altpll_component.port_scandata      = "PORT_UNUSED",
altpll_component.port_scandataout   = "PORT_UNUSED",
altpll_component.port_scandone      = "PORT_UNUSED",
altpll_component.port_scanread      = "PORT_UNUSED",
altpll_component.port_scanwrite     = "PORT_UNUSED",
altpll_component.port_clk0          = "PORT_USED",
altpll_component.port_clkena0       = "PORT_USED",
altpll_component.port_clk1          = "PORT_UNUSED",
altpll_component.port_clkena1       = "PORT_UNUSED",
altpll_component.port_clk2          = "PORT_UNUSED",
altpll_component.port_clkena2       = "PORT_UNUSED",
altpll_component.port_clk3          = "PORT_UNUSED",
altpll_component.port_clkena3       = "PORT_UNUSED",
altpll_component.port_clk4          = "PORT_UNUSED",
altpll_component.port_clkena4       = "PORT_UNUSED",
altpll_component.port_clk5          = "PORT_UNUSED",
altpll_component.port_clkena5       = "PORT_UNUSED",
altpll_component.port_extclk0       = "PORT_UNUSED",
altpll_component.port_extclk1       = "PORT_UNUSED",
altpll_component.port_extclk2       = "PORT_UNUSED",
altpll_component.port_extclk3       = "PORT_UNUSED",
altpll_component.port_extclk4       = "PORT_UNUSED",
altpll_component.width_clock       = 5;
endmodule

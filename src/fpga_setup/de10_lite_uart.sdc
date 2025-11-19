## DE10-Lite UART Test - Timing Constraints
## Clock constraint for 50 MHz system clock (MAX10_CLK1_50)

create_clock -name {clk} -period 20.000 -waveform { 0.000 10.000 } [get_ports {clk}]

derive_pll_clocks
derive_clock_uncertainty

# Create clock constraint - 50 MHz (20 ns period)
create_clock -name {clk} -period 20.000 -waveform { 0.000 10.000 } [get_ports {clk}]

# UART RX is asynchronous input
set_false_path -from [get_ports {uart_rx}] -to [all_registers]

# UART TX output - asynchronous
set_false_path -from [all_registers] -to [get_ports {uart_tx}]

# LED outputs - no timing constraints needed
set_false_path -from [all_registers] -to [get_ports {led[*]}]

# Reset is asynchronous
set_false_path -from [get_ports {resetn}]

# Derive clock uncertainty
derive_clock_uncertainty

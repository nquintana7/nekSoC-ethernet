create_clock -name clk50 -period 20 -waveform {0 10} [get_ports {netrmii_clk50m}]
create_clock -name clk_125m -period 8.0 [get_nets {clk125}]
set_clock_groups -asynchronous -group [get_clocks {clk50}] -group [get_clocks {clk_125m}]
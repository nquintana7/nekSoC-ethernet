create_clock -name clk50 -period 20 -waveform {0 10} [get_ports {netrmii_clk50m}]
create_clock -name clk_125m -period 8.0 [get_nets {clk125}]
set_false_path -from [get_clocks {clk_125m}] -to [get_clocks {clk50}] 
set_false_path -from [get_clocks {clk50}] -to [get_clocks {clk_125m}] 
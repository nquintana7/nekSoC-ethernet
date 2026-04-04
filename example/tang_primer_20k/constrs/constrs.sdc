create_clock -period 20.0 -name netrmii_clk50m [get_ports {netrmii_clk50m}]
create_clock -period 8.0 -name clk125 [get_nets {clk125}]
set_clock_groups -asynchronous -group [get_clocks {netrmii_clk50m}] -group [get_clocks {clk125}]
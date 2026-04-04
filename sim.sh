#!/bin/bash

# Exit on any error
set -e

echo "--- Starting Verilator Compilation ---"

# 1. Run Verilator to build the binary
# --binary: Creates the executable in obj_dir
# --timing: Enables SystemVerilog timing support (delays, etc.)
# --trace: Enables VCD generation
verilator --binary --timing --trace --no-std-waiver \
          -Irtl verilator.vlt \
          --top tb_loopback \
          tb/gowin_rpll_sim.sv \
          example/tang_primer_20k/rtl/top_loopback.sv \
          rtl/*.sv \
          tb//tb_loopback.sv

echo "--- Running Simulation ---"

# 2. Execute the generated simulation binary
./obj_dir/Vtb_loopback

# 3. Open GTKWave if the VCD file exists
if [ -f "top_waveform.vcd" ]; then
    echo "--- Opening GTKWave ---"
    gtkwave ./top_waveform.vcd
else
    echo "Error: top_waveform.vcd not found."
    exit 1
fi
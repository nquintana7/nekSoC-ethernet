# nekSoC-ethernet
# FPGA Ethernet Stack (RMII/MAC/UDP to AXI-Stream)

An in-progress Ethernet stack for FPGA designs. The goal is to bridge raw RMII signals from an Ethernet PHY through MAC/ARP/IPv4/UDP, and to transmit/receive data via a standard AXI-Stream interface.

**Target device:** Tang Primer 20K 

**Toolchain:** Verilator, Yosys, nextpnr, openFPGALoader (all open source)

## Current Project Status
**Current state:** RMII + Ethernet MAC connected to AXI-Stream.  
The design can transmit and receive raw Ethernet frames through AXI-Stream.

**In progress:**
- ARP
- IPv4
- UDP

## Architecture

The stack is designed with a modular, layered approach to maximize reusability and clarity.

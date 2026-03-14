# nekSoC-ethernet
# FPGA Ethernet Stack (RMII/MAC/UDP/IPv4 to AXI-Stream)

An in-progress Ethernet modular stack. The goal is to bridge raw RMII signals from an Ethernet PHY through MAC/ARP/IPv4/UDP, and to transmit/receive data payload via a standard AXI-Stream interface.

**Target device:** Tang Primer 20K 

**Toolchain:** Verilator, Yosys, nextpnr, openFPGALoader (all open source)

## Current Project Status
**Current state:** RMII + Ethernet MAC connected to AXI-Stream.  
* **Rx Path Completed:** Successfully strip Ethernet, IPv4, and UDP headers. ARP Cache write on received ARP Request or Reply. Trigger reply on received request.

**In progress:**
- Tx path:
  - Frame Builder
  - ARP
  - IPv4
  - UDP

## Architecture

The stack is designed with a modular, layered approach to maximize reusability and clarity.
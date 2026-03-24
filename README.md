# nekSoC-ethernet
# FPGA Ethernet Stack (RMII/MAC/UDP/IPv4 to AXI-Stream)

An in-progress Ethernet modular stack. The goal is to bridge raw RMII signals from an Ethernet PHY through MAC/ARP/IPv4/UDP, and to transmit/receive data payload via a standard AXI-Stream interface.

**Target device:** Tang Primer 20K 

**Toolchain:** Verilator, Yosys, nextpnr, openFPGALoader (all open source)

## Current Project Status
* **Full Path Completed in Simulation:** Builds/Parses Ethernet ARP/IP/UDP Packets. 
Replies to ARP requests, saves in arp cache IP/MAC pairs. Triggers request if MAC address for IP packet not found.

## Architecture

The stack is designed with a modular, layered approach to maximize reusability and clarity.

- To be configurable over axi4lite:
  - Local MAC Address
  - Static local IPv4 address
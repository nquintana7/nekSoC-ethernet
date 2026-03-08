# nekSoC-ethernet
# FPGA Ethernet MAC Stack (RMII/MAC/UDP to AXI-Stream)

A in-progress Ethernet MAC + UDP implementation made for my **Nexys A7**. This project implements a complete Layer 2 stack that bridges raw RMII from an Ethernet PHY signals to industry a standard AXI-Stream interface.

## Current Project Status
**Current State:** A AXI-S Ethernet MAC+RMII Interface. The design successfully transmits and receives raw Ethernet frames via AXI-Stream.
* Next steps: 
    - Implementation of the ARP Responder and UDP/IP Engine.
    - Run on Nexys A7 when ARP/UDP is working

## Architecture

The stack is designed with a modular, layered approach to maximize reusability and clarity.

## Structure

```text
├── rtl/
│   ├── eth_mac_axi_top.sv        # Top wrapper
│   ├── axis_tx_packet_buffer.sv  # TX Buffer to AXI-S Slave
│   ├── axis_rx_packet_buffer.sv  # RX Buffer to AXI-S Master
│   ├── eth_tx_mac.sv             # TX MAC
│   ├── eth_rx_mac.sv             # RX MAC
│   └── rmii_phy.sv               # RMII Interface
└── sim/
    └── tb_eth_mac_axi.sv        # AXI Testbench with Loopback between TX and RX
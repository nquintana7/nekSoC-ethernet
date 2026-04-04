# nekSoC-ethernet
## Modular FPGA 100Mbps Ethernet Stack (RMII → MAC → IPv4/ARP/UDP → AXI-Stream) 

An in-progress modular Ethernet hardware stack. Built with a low-latency cut-through architecture and a standard AXI-Stream interface for user applications. Currently in a working state.

### Architecture Overview
All data is cut-through/streaming, there is no buffering/FIFO except at the TX CDC boundary since the RMII runs a slower clock. User must accept all incoming packets and take care of the buffering. Headers are parsed/builded on-the-fly. 
![nekSoC Ethernet Architecture](doc/architecture.png)

### Specs
- Internal clock running at 125MHz
- RMII @ 50MHz (100Mbps link mode)
- Non-matching MAC/IP packets dropped 
- Hardware header parsing with crc validation/generation
- ARP Request/Reply logic with a cache
- Standard 8-bit AXI-Stream for app layer

### Perfomance & Verification
- Verified on the Tang Primer 20K.
- Tested with a Python script burst sending random UDP packets directly from a PC to the FPGA (tested with 100k packets) and verify looped back packets. The FPGA runs a top full-duplex loopback module.

### To-Do List
- Fix default state on start-up. (Now first packet reply fails unless reset button was pressed after flashing.)
- Implement AXI4-Lite registers for dynamic configuration of:
    * Local MAC & IPv4 Address
    * App Ports
- Add AXI4-Lite status registers to track statistics like dropped packets, CRC errors, frame faults, filtered packets.
- Upgrade ARP cache to a more intelligent approach  
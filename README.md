# nekSoC-ethernet
## Modular FPGA 100Mbps Ethernet Stack (RMII → MAC → IPv4/ARP/UDP → AXI-Stream) 

An in-progress modular Ethernet hardware stack. Built with a low-latency cut-through architecture and a standard AXI-Stream interface for user applications.

### Specs
- Internal clock running at 125MHz
- **PHY:** RMII @ 50MHz (100Mbps link mode)
- **Filtering:** Non-matching MAC/IP packets dropped 
- **IPv4/UDP:** Hardware header parsing with crc validation/generation
- **ARP Engine:** Hardware Request/Reply logic with an 8-entry naive cache
- **Interface:** Standard 8-bit AXI-Stream for app layer

### Perfomance & Verification
- Verified on the Tang Primer 20K.
- Tested with a Python script blasting random UDP packets directly from a PC to the FPGA. The FPGA runs a top loopback module. The script waits for the successful loopback return before dispatching the next packet.
- Achieved 100% success rate with this script, with a 1.25 ms avg latency (including python/OS overhead)

Round trip latency is 1.25 ms

### To-Do List
- Stress test for non-stop receiving packets
- Implement AXI4-Lite registers for dynamic configuration of:
    * Local MAC & IPv4 Address
    * App Ports
- Add AXI4-Lite status registers to track statistics like dropped packets, CRC errors, frame faults, filtered packets.
- Upgrade ARP cache to a more intelligent approach  
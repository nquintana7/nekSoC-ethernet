# nekSoC-ethernet
## Modular FPGA 100Mbps Ethernet Stack (RMII → MAC → IPv4/ARP/UDP → AXI-Stream) 

An in-progress modular Ethernet hardware stack. Built with low-latency **cut-through architecture**, providing a standard AXI-Stream interface for user applications.

### Specs
- **PHY:** RMII @ 50MHz (100Mbps link mode)
- **Filtering:** Non-matching MAC/IP packets dropped 
- **IPv4/UDP:** Hardware header parsing with crc validation/generation
- **ARP Engine:** Hardware Request/Reply logic with an 8-entry naive cache
- **Interface:** Standard 8-bit AXI-Stream for app layer

### Hardware Verification
Verified on the Tang Primer 20K.

### Measurements
Testing was performed with a loopback in the top module and using a Python stimulus blasting random UDP packets directly from a PC, with over 50k packets sent.

Result was 94% success rate with a round trip latency of 1.08 ms (including Python/Scapy overhead).

### To-Do List
- Find culprit of only 94% success rate and not higher
- Implement AXI4-Lite registers for dynamic configuration of:
    * Local MAC & IP Addresses
    * App Ports
- AXI4-Lite registers also for status dropped packets/crc errors
- More intelligent ARP cache  
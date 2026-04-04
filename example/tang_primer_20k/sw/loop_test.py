from scapy.all import Ether, ARP, IP, UDP, srp1, sendp, Raw, AsyncSniffer
import os
import random
import time
import struct
import threading

# --- CONFIGURATION ---
INTERFACE = "enp9s0" 
FPGA_IP = "192.168.1.10"
PC_IP = "192.168.1.100"
UDP_PORT = 5005
NUM_PACKETS = 10000  # Cranked up for a real stress test!

def run_full_duplex_test():
    print(f"--- Targeting FPGA at {FPGA_IP} ---")
    print("Step 1: Sending Initial ARP Request...")

    base_arp = Ether(dst="ff:ff:ff:ff:ff:ff") / ARP(pdst=FPGA_IP, psrc=PC_IP)
    pad_length = 60 - len(base_arp)
    arp_request = base_arp / Raw(b"\x00" * pad_length)

    answered = srp1(arp_request, iface=INTERFACE, timeout=2, verbose=False)

    if not answered:
        print("FAILED: No ARP response. Is the FPGA connected and programmed?")
        return

    fpga_mac = answered.hwsrc
    print(f"SUCCESS: FPGA MAC found -> {fpga_mac}")
    
    # ---------------------------------------------------------
    # 1. Pre-generate Packets
    # ---------------------------------------------------------
    print(f"\nStep 2: Pre-generating {NUM_PACKETS} packets...")
    tx_packets = []
    expected_payloads = {}
    
    for seq in range(NUM_PACKETS):
        # We need at least 4 bytes for the sequence number
        payload_len = random.randint(18, 1472) 
        
        # Pack the sequence number (4 bytes, big-endian) and append random data
        seq_bytes = struct.pack("!I", seq)
        rand_bytes = os.urandom(payload_len - 4)
        payload = seq_bytes + rand_bytes
        
        expected_payloads[seq] = payload
        
        pkt = (Ether(dst=fpga_mac)/ 
               IP(src=PC_IP, dst=FPGA_IP) / 
               UDP(sport=1234, dport=UDP_PORT) / 
               Raw(load=payload))
        
        tx_packets.append(pkt)

    # Dictionary to store exact transmit times
    tx_times = {}

    # ---------------------------------------------------------
    # 2. Setup the Background Sniffer (Receiver)
    # ---------------------------------------------------------
    print("\nStep 3: Starting Background Sniffer (RX Thread)...")
    # Only capture UDP packets coming FROM the FPGA
    rx_filter = f"udp and src host {FPGA_IP} and dst port 1234"
    sniffer = AsyncSniffer(iface=INTERFACE, filter=rx_filter)
    sniffer.start()
    
    time.sleep(0.5)

    # ---------------------------------------------------------
    # 3. Burst Transmission (TX Thread)
    # ---------------------------------------------------------
    print(f"Step 4: Blasting {NUM_PACKETS} packets! (TX Thread)...")
    
    burst_start = time.perf_counter()
    for seq, pkt in enumerate(tx_packets):
        tx_times[seq] = time.perf_counter()
        sendp(pkt, iface=INTERFACE, verbose=False)
    burst_end = time.perf_counter()
    
    burst_duration = burst_end - burst_start
    print(f"  -> Burst complete in {burst_duration:.3f}s (Avg rate: {NUM_PACKETS/burst_duration:.0f} pkts/sec)")

    # ---------------------------------------------------------
    # 4. Wait & Stop Sniffer
    # ---------------------------------------------------------
    print("Step 5: Waiting for trailing loopback packets...")
    time.sleep(1.0) # Wait 1 second to catch any stragglers in the pipeline
    
    sniffer.stop()
    captured_packets = sniffer.results
    
    # ---------------------------------------------------------
    # 5. Analyze Results
    # ---------------------------------------------------------
    print(f"\n--- Analysis ---")
    print(f"Captured {len(captured_packets)} total packets from FPGA.")
    
    success_count = 0
    corrupt_count = 0
    latencies = []
    seen_seqs = set()

    for pkt in captured_packets:
        if pkt.haslayer(Raw):
            received_data = pkt[Raw].load
            
            if len(received_data) >= 4:
                # Unpack the 4-byte sequence number
                seq = struct.unpack("!I", received_data[:4])[0]
                
                if seq in expected_payloads:
                    seen_seqs.add(seq)
                    
                    if received_data == expected_payloads[seq]:
                        success_count += 1
                        # Calculate latency using the timestamp we recorded right before sending
                        latency_ms = (time.perf_counter() - tx_times[seq]) * 1000
                        latencies.append(latency_ms)
                    else:
                        corrupt_count += 1

    missing_count = NUM_PACKETS - len(seen_seqs)

    print(f"\n--- Full Duplex Test Complete ---")
    print(f"Successfully Looped Back : {success_count}/{NUM_PACKETS} ({(success_count/NUM_PACKETS)*100:.1f}%)")
    
    if missing_count > 0 or corrupt_count > 0:
        print(f"Dropped Packets          : {missing_count}")
        print(f"Corrupted Payloads       : {corrupt_count}")
    else:
        print("ZERO DROPS. Full-duplex verified!")

    if latencies:
        print(f"\nMin Latency: {min(latencies):.2f} ms")
        print(f"Max Latency: {max(latencies):.2f} ms")
        print(f"Avg Latency: {(sum(latencies) / len(latencies)):.2f} ms")

if __name__ == "__main__":
    run_full_duplex_test()
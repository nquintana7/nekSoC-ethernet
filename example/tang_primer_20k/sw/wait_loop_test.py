from scapy.all import Ether, ARP, IP, UDP, srp1, sendp, Raw, AsyncSniffer
import os
import random
import time

# --- CONFIGURATION ---
INTERFACE = "enp9s0" 
FPGA_IP = "192.168.1.10"
PC_IP = "192.168.1.100"
UDP_PORT = 5005
NUM_PACKETS = 15000

def run_wait_loop_test():
    print(f"--- Targeting FPGA at {FPGA_IP} ---")
    print("Step 1: Sending ARP Request...")

    base_arp = Ether(dst="ff:ff:ff:ff:ff:ff") / ARP(pdst=FPGA_IP, psrc=PC_IP)
    pad_length = 60 - len(base_arp)
    arp_request = base_arp / Raw(b"\x00" * pad_length)

    answered = srp1(arp_request, iface=INTERFACE, timeout=2, verbose=False)

    if not answered:
        print("FAILED: No ARP response.")
        return

    fpga_mac = answered.hwsrc
    print(f"SUCCESS: FPGA MAC found -> {fpga_mac}")
    print(f"Step 2: Starting Loopback Test ({NUM_PACKETS} packets)...")

    success_count = 0
    fail_count = 0
    odd_fail_count = 0
    latencies = []
    
    current_streak = 0
    streaks_between_failures = []

    for i in range(NUM_PACKETS):
        if (i + 1) % 1000 == 0:
            print(f"--- Progress: Reached packet {i + 1} ---")

        payload_len = random.randint(800, 1472)
        payload_data = os.urandom(payload_len)

        if (i == 5):
            new_ip = "192.168.1.55"
            new_mac = "02:00:00:11:22:33"
            
            packet = (Ether(dst=fpga_mac, src=new_mac)/ 
            IP(src=new_ip, dst=FPGA_IP) / 
            UDP(sport=1234, dport=UDP_PORT) / 
            Raw(load=payload_data))

            print(f"  -> [Packet {i+1}] Starting background sniffer for {new_ip}...")
            # 1. Start the sniffer in the background FIRST
            sniffer = AsyncSniffer(iface=INTERFACE, filter=f"arp host {new_ip}", count=1, timeout=2.0)
            sniffer.start()
            
            time.sleep(0.1)

            # 3. Fire the UDP packet to trigger the cache miss
            print(f"  -> [Packet {i+1}] Trigger UDP sent. Waiting for FPGA ARP request...")
            sendp(packet, iface=INTERFACE, verbose=False)

            # 4. Wait for the sniffer to finish (either it catches 1 packet or times out)
            sniffer.join()
            captured = sniffer.results

            if captured and captured[0].haslayer(ARP) and captured[0][ARP].op == 1:
                req = captured[0][ARP]
                print(f"  -> [Packet {i+1}] ARP Request captured! Sending ARP Reply...")
                
                base_reply = Ether(dst=req.hwsrc, src=new_mac) / \
                             ARP(op=2, hwsrc=new_mac, psrc=new_ip, hwdst=req.hwsrc, pdst=req.psrc)
                
                pad_len = 60 - len(base_reply)
                arp_reply = base_reply / Raw(b"\x00" * max(0, pad_len))
                
                sendp(arp_reply, iface=INTERFACE, verbose=False)
                
                # Give the FPGA logic a tiny margin to register the cache update
                time.sleep(0.01) 
            else:
                print(f"  -> [Packet {i+1}] FAILED: No ARP request captured by Sniffer.")

        else:
            packet = (Ether(dst=fpga_mac)/ 
            IP(src=PC_IP, dst=FPGA_IP) / 
            UDP(sport=1234, dport=UDP_PORT) / 
            Raw(load=payload_data))


        start_time = time.perf_counter()
        
        response = srp1(packet, iface=INTERFACE, timeout=1, verbose=False)
        
        end_time = time.perf_counter()
        
        if response and response.haslayer(Raw):
            received_data = response[Raw].load
            if received_data == payload_data:
                success_count += 1
                current_streak += 1
                latencies.append((end_time - start_time) * 1000)
            else:
                streaks_between_failures.append(current_streak)
                current_streak = 0
                fail_count += 1
                if (payload_len % 2 != 0): odd_fail_count += 1
        else:
            streaks_between_failures.append(current_streak)
            current_streak = 0
            fail_count += 1
            if (payload_len % 2 != 0): odd_fail_count += 1

    print(f"\n--- Test Complete: {success_count}/{NUM_PACKETS} packets looped back successfully ---")
    
    if fail_count > 0:
        even_fail_count = fail_count - odd_fail_count
        print(f"Total Failures: {fail_count}")
        print(f"  -> Odd Length Failures:  {odd_fail_count} ({(odd_fail_count/fail_count)*100:.1f}%)")
        print(f"  -> Even Length Failures: {even_fail_count} ({(even_fail_count/fail_count)*100:.1f}%)")
        if streaks_between_failures:
            avg_streak = sum(streaks_between_failures) / len(streaks_between_failures)
            print(f"  -> Avg Packets Between Failures: {avg_streak:.1f} packets")
    else:
        print("Total Failures: 0")

    if latencies:
        print(f"\nMin Latency: {min(latencies):.2f} ms")
        print(f"Max Latency: {max(latencies):.2f} ms")
        print(f"Avg Latency: {(sum(latencies) / len(latencies)):.2f} ms")

if __name__ == "__main__":
    run_wait_loop_test()
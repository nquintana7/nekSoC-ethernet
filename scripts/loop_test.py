from scapy.all import Ether, ARP, IP, UDP, srp1, Raw
import os
import random
import time

# --- CONFIGURATION ---
INTERFACE = "Ethernet" 
FPGA_IP = "192.168.1.10"
PC_IP = "192.168.1.11"
UDP_PORT = 5005
NUM_PACKETS = 50000

def run_stress_test():
    print(f"--- Targeting FPGA at {FPGA_IP} ---")
    print("Step 1: Sending ARP Request...")
    arp_request = Ether(dst="ff:ff:ff:ff:ff:ff") / ARP(pdst=FPGA_IP)
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

        # Create random bytes for the payload
        payload_data = os.urandom(payload_len)
        
        packet = (Ether(dst=fpga_mac) / 
                  IP(src=PC_IP, dst=FPGA_IP) / 
                  UDP(sport=1234, dport=UDP_PORT) / 
                  Raw(load=payload_data))

        start_time = time.perf_counter()
        
        # Send packet and wait for 1 reply
        response = srp1(packet, iface=INTERFACE, timeout=1, verbose=False)
        
        end_time = time.perf_counter()
        
        if response and response.haslayer(Raw):
            received_data = response[Raw].load
            if received_data == payload_data:
                success_count += 1
                current_streak += 1
                
                # Calculate and store latency
                latency_ms = (end_time - start_time) * 1000
                latencies.append(latency_ms)
                
                #print(f"[Packet {i+1}/{NUM_PACKETS}] SUCCESS - Size: {payload_len} bytes | Latency: {latency_ms:.2f} ms")
            else:
                streaks_between_failures.append(current_streak)
                current_streak = 0
                
                fail_count += 1
                is_odd = (payload_len % 2 != 0)
                if is_odd:
                    odd_fail_count += 1
                
                parity = "ODD" if is_odd else "EVEN"
                #print(f"[Packet {i+1}/{NUM_PACKETS}] FAILED: Payload mismatch! Length: {payload_len} ({parity})")
        else:
            streaks_between_failures.append(current_streak)
            current_streak = 0
            
            fail_count += 1
            is_odd = (payload_len % 2 != 0)
            if is_odd:
                odd_fail_count += 1
                
            parity = "ODD" if is_odd else "EVEN"
            #print(f"[Packet {i+1}/{NUM_PACKETS}] FAILED: No response or missing payload. Length: {payload_len} ({parity})")

    print(f"\n--- Test Complete: {success_count}/{NUM_PACKETS} packets looped back successfully ---")
    
    # --- PRINT FAILURE STATS ---
    if fail_count > 0:
        even_fail_count = fail_count - odd_fail_count
        print(f"Total Failures: {fail_count}")
        print(f"  -> Odd Length Failures:  {odd_fail_count} ({(odd_fail_count/fail_count)*100:.1f}%)")
        print(f"  -> Even Length Failures: {even_fail_count} ({(even_fail_count/fail_count)*100:.1f}%)")
        
        avg_streak = sum(streaks_between_failures) / len(streaks_between_failures)
        print(f"  -> Avg Packets Between Failures: {avg_streak:.1f} packets")
    else:
        print("Total Failures: 0")

    # --- PRINT LATENCY STATS ---
    if latencies:
        avg_lat = sum(latencies) / len(latencies)
        min_lat = min(latencies)
        max_lat = max(latencies)
        print(f"\nMin Latency: {min_lat:.2f} ms")
        print(f"Max Latency: {max_lat:.2f} ms")
        print(f"Avg Latency: {avg_lat:.2f} ms")

if __name__ == "__main__":
    run_stress_test()
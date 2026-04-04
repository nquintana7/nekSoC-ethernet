`timescale 1ns/1ps

module tb_loopback();

    // --- Clocks and Resets ---
    logic clk_100m = 0;
    logic clk_50m  = 0;
    logic rstn     = 0;

    always #5  clk_100m = ~clk_100m; // App Clock
    always #10 clk_50m  = ~clk_50m;  // RMII Clock

    // --- Configuration ---
    parameter logic [47:0] REMOTE_MAC = 48'h00_0E_7F_5F_F1_DF; 
    parameter logic [47:0] DUT_MAC    = 48'h00_1A_2B_3C_4D_5E; 
    
    // --- RMII Interconnect (TB MAC <--> DUT) ---
    logic [1:0] tb_to_dut_data, dut_to_tb_data;
    logic       tb_to_dut_en,   dut_to_tb_en;

    logic [7:0]  tb_ip_tx_tdata;  logic tb_ip_tx_tvalid = 0, tb_ip_tx_tready, tb_ip_tx_tlast = 0;
    logic [47:0] tb_ip_tx_tuser = 0;
    
    logic [7:0]  tb_arp_tx_tdata; logic tb_arp_tx_tvalid = 0, tb_arp_tx_tready, tb_arp_tx_tlast = 0;
    logic [47:0] tb_arp_tx_tuser = 0;
    
    logic [7:0]  tb_ip_rx_tdata;  logic tb_ip_rx_tvalid, tb_ip_rx_tready = 1, tb_ip_rx_tlast, tb_ip_rx_tuser;
    logic [7:0]  tb_arp_rx_tdata; logic tb_arp_rx_tvalid, tb_arp_rx_tready = 0, tb_arp_rx_tlast, tb_arp_rx_tuser;

    // --- Physical Pins for DUT ---
    logic phyrst, mdc;
    wire  mdio;

    typedef logic [7:0] payload_arr_t [];
    payload_arr_t exp_payload_queue [$];

    // ==========================================
    // 1. Remote PC MAC (Testbench Stimulus)
    // ==========================================
    eth_mac_axi_top u_tb_mac (
        .clk_i(clk_100m), .rstn_i(rstn),
        .clk_50M_i(clk_50m), .rstn_500M_i(rstn),
        .local_mac_i(REMOTE_MAC), 
        
        .rmii_txd_o(tb_to_dut_data), .rmii_tx_en_o(tb_to_dut_en),
        .rmii_rxd_i(dut_to_tb_data), .rmii_crs_dv_i(dut_to_tb_en), .rmii_rxer_i(1'b0),
        
        .s_ip_tx_axis_tdata(tb_ip_tx_tdata),   .s_ip_tx_axis_tvalid(tb_ip_tx_tvalid),
        .s_ip_tx_axis_tlast(tb_ip_tx_tlast),   .s_ip_tx_axis_tuser(tb_ip_tx_tuser),
        .s_ip_tx_axis_tready(tb_ip_tx_tready),
        
        .s_arp_tx_axis_tdata(tb_arp_tx_tdata), .s_arp_tx_axis_tvalid(tb_arp_tx_tvalid),
        .s_arp_tx_axis_tlast(tb_arp_tx_tlast), .s_arp_tx_axis_tuser(tb_arp_tx_tuser),
        .s_arp_tx_axis_tready(tb_arp_tx_tready),
        
        .m_ip_rx_axis_tdata(tb_ip_rx_tdata),   .m_ip_rx_axis_tvalid(tb_ip_rx_tvalid),
        .m_ip_rx_axis_tlast(tb_ip_rx_tlast),   .m_ip_rx_axis_tuser(tb_ip_rx_tuser),
        .m_ip_rx_axis_tready(tb_ip_rx_tready),
        
        .m_arp_rx_axis_tdata(tb_arp_rx_tdata), .m_arp_rx_axis_tvalid(tb_arp_rx_tvalid),
        .m_arp_rx_axis_tlast(tb_arp_rx_tlast), .m_arp_rx_axis_tuser(tb_arp_rx_tuser),
        .m_arp_rx_axis_tready(tb_arp_rx_tready)
    );

    top_loopback u_top (
        .rst(rstn),
        .netrmii_clk50m(clk_50m),
        .phyrst(phyrst),
        .netrmii_rx_crs(tb_to_dut_en),
        .netrmii_rxd(tb_to_dut_data),
        .netrmii_txen(dut_to_tb_en),
        .netrmii_txd(dut_to_tb_data),
        .netrmii_mdc(mdc),
        .netrmii_mdio(mdio)
    );

    logic [7:0] arp_req_payload [] = '{
        8'h00, 8'h01, 8'h08, 8'h00, 8'h06, 8'h04, 8'h00, 8'h01,
        8'h00, 8'h0E, 8'h7F, 8'h5F, 8'hF1, 8'hDF,                 // Sender MAC (Remote PC)
        8'hC0, 8'hA8, 8'h01, 8'h84,                               // Sender IP: 192.168.1.132
        8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,                 // Target MAC (Blank)
        8'hC0, 8'hA8, 8'h01, 8'd10                                // Target IP: 192.168.1.10 (DUT)
    };    

    logic [7:0] exp_arp_reply [] = '{
        8'h00, 8'h01, 8'h08, 8'h00, 8'h06, 8'h04, 8'h00, 8'h02,
        8'h00, 8'h1A, 8'h2B, 8'h3C, 8'h4D, 8'h5E,                 // Sender MAC (DUT)
        8'hC0, 8'hA8, 8'h01, 8'd10,                               // Sender IP: 192.168.1.10 (DUT)
        8'h00, 8'h0E, 8'h7F, 8'h5F, 8'hF1, 8'hDF,                 // Target MAC: Remote PC
        8'hC0, 8'hA8, 8'h01, 8'h84                                // Target IP: 192.168.1.132
    };

    initial begin
        $dumpfile("top_waveform.vcd");
        $dumpvars(0, tb_loopback);

        $display("[%0t] TB: Resetting system...", $time);
        rstn = 0; 
        repeat(20) @(posedge clk_100m);
        rstn = 1; 
        repeat(100) @(posedge clk_100m);

        // 2. Static ARP Resolution
        $display("[%0t] TB: Sending ARP Request to DUT...", $time);
        send_arp_to_mac(28, arp_req_payload, 48'hFF_FF_FF_FF_FF_FF);
        
        $display("[%0t] TB: Waiting for ARP Reply...", $time);
        wait_for_arp_reply(28, exp_arp_reply); 

        repeat(50) @(posedge clk_100m);

        // 3. FULL DUPLEX Dynamic Random UDP BURST Test
        $display("\n[%0t] TB: Starting FULL DUPLEX Burst UDP Loopback Test...", $time);
        
        fork
            // ---------------------------------------------------------
            // THREAD 1: TRANSMITTER
            // ---------------------------------------------------------
            begin
                for (int p = 1; p <= 100; p++) begin
                    int rand_len = $urandom_range(18, 256);
                    $display("[%0t] --- TX: Injecting Packet %0d/100 (Payload size: %0d bytes) ---", $time, p, rand_len);
                    
                    generate_and_send_udp(rand_len);

                    // Zero IPG on the AXI-Stream side! Blast them continuously to 
                    // ensure the DUT is receiving and transmitting simultaneously.
                    @(posedge clk_100m);
                end
                $display("[%0t] TB: TX Thread completed packet injection.", $time);
            end

            // ---------------------------------------------------------
            // THREAD 2: RECEIVER
            // ---------------------------------------------------------
            begin
                for (int p = 1; p <= 100; p++) begin
                    logic pkt_success;
                    payload_arr_t exp_payload;

                    wait(exp_payload_queue.size() > 0);
                    exp_payload = exp_payload_queue.pop_front();
                    
                    receive_looped_udp_dynamic(exp_payload.size(), exp_payload, pkt_success);

                    if (!pkt_success) begin
                        $display("\n[%0t] FATAL ERROR: Loopback check failed on packet %0d! Halting.", $time, p);
                        $stop;
                    end
                end
                $display("[%0t] TB: RX Thread verified all packets successfully.", $time);
            end
        join

        $display("\n[%0t] TB: SIMULATION SUCCESSFUL - All 100 packets survived Full-Duplex line-rate stress!", $time);
        repeat(100) @(posedge clk_100m);
        $finish;
    end

    // ==========================================
    // Synchronous AXI-Stream Tasks 
    // ==========================================

task automatic generate_and_send_udp(input int payload_len);
        logic [7:0] tx_pkt [];
        payload_arr_t exp_payload;
        int ip_len, udp_len;
        logic [15:0] ip_csum;
        logic [31:0] csum_acc;

        ip_len  = 20 + 8 + payload_len; // 20b IP + 8b UDP + Payload
        udp_len = 8 + payload_len;
        tx_pkt  = new[ip_len];
        exp_payload = new[payload_len];

        // 1. Construct IP Header
        tx_pkt[0] = 8'h45; tx_pkt[1] = 8'h00;
        tx_pkt[2] = ip_len >> 8; tx_pkt[3] = ip_len & 8'hFF;
        tx_pkt[4] = 8'h12; tx_pkt[5] = 8'h34; // ID
        tx_pkt[6] = 8'h00; tx_pkt[7] = 8'h00; // Flags/Frag
        tx_pkt[8] = 8'h40; tx_pkt[9] = 8'h11; // TTL, Protocol (UDP)
        tx_pkt[10]= 8'h00; tx_pkt[11]= 8'h00; // Checksum placeholder
        tx_pkt[12]= 8'hC0; tx_pkt[13]= 8'hA8; tx_pkt[14]= 8'h01; tx_pkt[15]= 8'h84; // Src IP
        tx_pkt[16]= 8'hC0; tx_pkt[17]= 8'hA8; tx_pkt[18]= 8'h01; tx_pkt[19]= 8'h0A; // Dst IP

        // Calculate IPv4 Checksum
        csum_acc = 0;
        for (int i=0; i<20; i+=2) csum_acc += {tx_pkt[i], tx_pkt[i+1]};
        csum_acc = (csum_acc & 16'hFFFF) + (csum_acc >> 16);
        csum_acc = (csum_acc & 16'hFFFF) + (csum_acc >> 16);
        ip_csum = ~csum_acc;
        tx_pkt[10] = ip_csum >> 8; tx_pkt[11] = ip_csum & 8'hFF;

        // 2. Construct UDP Header
        tx_pkt[20] = 8'h13; tx_pkt[21] = 8'h88; // Src Port 5000
        tx_pkt[22] = 8'h13; tx_pkt[23] = 8'h89; // Dst Port 5001
        tx_pkt[24] = udp_len >> 8; tx_pkt[25] = udp_len & 8'hFF;
        tx_pkt[26] = 8'h00; tx_pkt[27] = 8'h00; // UDP Checksum (Optional, leave 0)

        // 3. Construct Random Payload
        for (int i=0; i<payload_len; i++) begin
            tx_pkt[28+i] = $urandom_range(0, 255);
            exp_payload[i] = tx_pkt[28+i];
        end

        exp_payload_queue.push_back(exp_payload);

        // --- PRINT INJECTED PACKET ---
        $display("\n===========================================================");
        $display("[%0t ns] ---> TB INJECTING UDP PACKET", $time);
        $display("    Length : %0d bytes (Total IP Packet)", ip_len);
        $write("    Data   : ");
        for (int i = 28; i < ip_len; i++) begin
            $write("%02h ", tx_pkt[i]);
            if ((i + 1) % 16 == 0 && i != ip_len - 1) $write("\n             ");
        end
        $display("\n===========================================================\n");

        send_ip_to_mac(ip_len, tx_pkt, DUT_MAC);
    endtask

    task automatic receive_looped_udp_dynamic(input int expected_len, input logic [7:0] exp_payload [], output logic success);
        logic done = 0;
        int k = 0;
        int p_idx = 0;
        logic [7:0] rx_pkt_cap [$]; // Buffer to capture packet for printing
        
        while (!done) begin
            // Introduce random backpressure to heavily stress the DUT's TX state machine
            tb_ip_rx_tready <= ($urandom_range(0, 10) > 2); // 70% ready
            
            @(posedge clk_100m);
            if (tb_ip_rx_tvalid && tb_ip_rx_tready) begin
                rx_pkt_cap.push_back(tb_ip_rx_tdata); // Capture byte for print

                if (k >= 28) begin
                    p_idx = k - 28;
                    if (p_idx < expected_len) begin
                        if (tb_ip_rx_tdata !== exp_payload[p_idx]) begin
                            $display("[%0t] UDP ERR: Byte %0d mismatch! Exp:%h Got:%h", $time, p_idx, exp_payload[p_idx], tb_ip_rx_tdata);
                        end
                    end
                end
                
                if (tb_ip_rx_tlast) begin
                    if (p_idx + 1 == expected_len) begin
                        $display("[%0t] TB: SUCCESS - Verified %0d bytes", $time, expected_len);
                        success = 1'b1;
                    end else begin
                        $display("[%0t] TB: LENGTH ERR - Expected %0d bytes, got %0d", $time, expected_len, p_idx + 1);
                        success = 1'b0;
                    end

                    // --- PRINT RECEIVED PACKET ---
                    $display("\n<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<");
                    $display("[%0t ns] <--- TB RECEIVED LOOPBACK PACKET", $time);
                    $display("    Length : %0d bytes", rx_pkt_cap.size());
                    $write("    Data   : ");
                    foreach(rx_pkt_cap[i]) begin
                        $write("%02h ", rx_pkt_cap[i]);
                        if ((i + 1) % 16 == 0 && i != rx_pkt_cap.size() - 1) $write("\n             ");
                    end
                    $display("\n<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n");

                    done = 1'b1;
                end
                k++;
            end
        end
        tb_ip_rx_tready <= 1'b1; // Leave ready high between packets
    endtask

    // Fully synchronous AXI-Stream driver
    task automatic send_ip_to_mac(input int len, input logic [7:0] pkt [], input logic [47:0] dest_mac);
        @(posedge clk_100m);
        tb_ip_tx_tuser <= dest_mac;
        for (int i = 0; i < len; i++) begin
            tb_ip_tx_tdata  <= pkt[i];
            tb_ip_tx_tvalid <= 1'b1;
            tb_ip_tx_tlast  <= (i == len - 1);
            @(posedge clk_100m);
            while (!tb_ip_tx_tready) @(posedge clk_100m);
        end
        tb_ip_tx_tvalid <= 1'b0;
        tb_ip_tx_tlast  <= 1'b0;
    endtask

    task automatic send_arp_to_mac(input int len, input logic [7:0] pkt [], input logic [47:0] dest_mac);
        int actual_len = (len < 60) ? 60 : len;
        @(posedge clk_100m);
        tb_arp_tx_tuser <= dest_mac;
        for (int i = 0; i < actual_len; i++) begin
            tb_arp_tx_tdata  <= (i < len) ? pkt[i] : 8'h00;
            tb_arp_tx_tvalid <= 1'b1;
            tb_arp_tx_tlast  <= (i == actual_len - 1);
            @(posedge clk_100m);
            while (!tb_arp_tx_tready) @(posedge clk_100m);
        end
        tb_arp_tx_tvalid <= 1'b0;
        tb_arp_tx_tlast  <= 1'b0;
    endtask

    task automatic wait_for_arp_reply(input int len, input logic [7:0] exp []);
        logic done = 0;
        int byte_cnt = 0;
        tb_arp_rx_tready <= 1;

        while (!done) begin
            @(posedge clk_100m);
            if (tb_arp_rx_tvalid && tb_arp_rx_tready) begin
                if (byte_cnt < len) begin
                    if (tb_arp_rx_tdata !== exp[byte_cnt]) begin
                        $display("[%0t] ARP ERR: Byte %0d mismatch! Exp:%h Got:%h", $time, byte_cnt, exp[byte_cnt], tb_arp_rx_tdata);
                    end
                end
                if (tb_arp_rx_tlast) begin
                    $display("[%0t] TB: ARP Reply Received & Verified! Length: %0d bytes", $time, byte_cnt+1);
                    done = 1;
                end
                byte_cnt++;
            end
        end
        tb_arp_rx_tready <= 0;
    endtask

endmodule
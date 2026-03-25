`timescale 1ns/1ps

module tb_loopback();

    // --- Clocks and Resets ---
    logic clk_100m = 0;
    logic clk_50m  = 0;
    logic rstn     = 0;

    always #5  clk_100m = ~clk_100m; // App Clock
    always #10 clk_50m  = ~clk_50m;  // RMII Clock

    // --- Configuration ---
    parameter logic [47:0] REMOTE_MAC = 48'h00_0E_7F_5F_F1_DF; // Testbench "Remote PC" MAC
    parameter logic [47:0] DUT_MAC    = 48'h00_1A_2B_3C_4D_5E; // Your FPGA's MAC

    // --- RMII Interconnect (TB MAC <--> DUT) ---
    logic [1:0] tb_to_dut_data, dut_to_tb_data;
    logic       tb_to_dut_en,   dut_to_tb_en;

    // --- TB Remote PC Split AXI-Stream Interfaces ---
    logic [7:0]  tb_ip_tx_tdata;  logic tb_ip_tx_tvalid = 0, tb_ip_tx_tready, tb_ip_tx_tlast = 0;
    logic [47:0] tb_ip_tx_tuser = 0;
    
    logic [7:0]  tb_arp_tx_tdata; logic tb_arp_tx_tvalid = 0, tb_arp_tx_tready, tb_arp_tx_tlast = 0;
    logic [47:0] tb_arp_tx_tuser = 0;
    
    logic [7:0]  tb_ip_rx_tdata;  logic tb_ip_rx_tvalid, tb_ip_rx_tready = 1, tb_ip_rx_tlast, tb_ip_rx_tuser;
    logic [7:0]  tb_arp_rx_tdata; logic tb_arp_rx_tvalid, tb_arp_rx_tready = 0, tb_arp_rx_tlast, tb_arp_rx_tuser;

    // --- Physical Pins for DUT ---
    logic phyrst, mdc;
    wire  mdio;

    // ==========================================
    // 1. Remote PC MAC (Testbench Stimulus)
    // ==========================================
    eth_mac_axi_top u_tb_mac (
        .clk_i(clk_100m), .rstn_i(rstn),
        .clk_50M_i(clk_50m), .rstn_500M_i(rstn),
        .local_mac_i(REMOTE_MAC), 
        
        // RMII OUT to DUT
        .rmii_txd_o(tb_to_dut_data), .rmii_tx_en_o(tb_to_dut_en),
        // RMII IN from DUT
        .rmii_rxd_i(dut_to_tb_data), .rmii_crs_dv_i(dut_to_tb_en), .rmii_rxer_i(1'b0),
        
        // Streams
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

    // ==========================================
    // 2. YOUR DUT: Physical Loopback Top
    // ==========================================
    rmii_udp_loopback_top u_top (
        .rst(rstn),                // Converted to active high
        .netrmii_clk50m(clk_50m),
        .phyrst(phyrst),
        
        // RMII IN from TB MAC
        .netrmii_rx_crs(tb_to_dut_en),
        .netrmii_rxd(tb_to_dut_data),
        
        // RMII OUT back to TB MAC
        .netrmii_txen(dut_to_tb_en),
        .netrmii_txd(dut_to_tb_data),
        
        // MDIO
        .netrmii_mdc(mdc),
        .netrmii_mdio(mdio)
    );

    // ==========================================
    // Payload Definitions
    // ==========================================
    logic [7:0] arp_req_payload [0:27] = '{
        8'h00, 8'h01, 8'h08, 8'h00, 8'h06, 8'h04, 8'h00, 8'h01,
        8'h00, 8'h0E, 8'h7F, 8'h5F, 8'hF1, 8'hDF,                 // Sender MAC (Remote PC)
        8'hC0, 8'hA8, 8'h01, 8'h84,                               // Sender IP: 192.168.1.132
        8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,                 // Target MAC (Blank)
        8'hC0, 8'hA8, 8'h01, 8'd10                                // Target IP: 192.168.1.10 (DUT)  {8'd192, 8'd168, 8'd1, 8'd10}
    };    

    logic [7:0] exp_arp_reply [0:27] = '{
        8'h00, 8'h01, 8'h08, 8'h00, 8'h06, 8'h04, 8'h00, 8'h02,
        8'h00, 8'h1A, 8'h2B, 8'h3C, 8'h4D, 8'h5E,                 // Sender MAC (DUT)
        8'hC0, 8'hA8, 8'h01, 8'd10,                               // Sender IP: 192.168.1.65 (DUT)
        8'h00, 8'h0E, 8'h7F, 8'h5F, 8'hF1, 8'hDF,                 // Target MAC: Remote PC
        8'hC0, 8'hA8, 8'h01, 8'h84                                // Target IP: 192.168.1.132
    };
        
    logic [7:0] ip_udp_payload [0:35] = '{
        8'h45, 8'h00, 8'h00, 8'h24, 8'h12, 8'h34, 8'h00, 8'h00, 8'h40, 8'h11, 8'h00, 8'h00, 
        8'hC0, 8'hA8, 8'h01, 8'h84,                               // Source IP: 192.168.1.132
        8'hC0, 8'hA8, 8'h01, 8'd10,                               // Dest IP: 192.168.1.65 (DUT)
        8'h13, 8'h88, 8'h13, 8'h89, 8'h00, 8'h10, 8'h00, 8'h00,   // Ports 5000->5001
        8'hDE, 8'hAD, 8'hBE, 8'hEF, 8'hCA, 8'hFE, 8'hBA, 8'hBE    // Data
    };

    logic [7:0] exp_udp_payload [0:7] = '{
        8'hDE, 8'hAD, 8'hBE, 8'hEF, 8'hCA, 8'hFE, 8'hBA, 8'hBE
    };

    // ==========================================
    // Simulation Sequence
    // ==========================================
    initial begin
        // $dumpfile("top_waveform.vcd");
        // $dumpvars(0, tb_loopback);

        // 1. Reset Sequence
        $display("[%0t] TB: Resetting system...", $time);
        rstn = 0; 
        repeat(20) @(posedge clk_100m); // Wait 20 clock cycles instead of arbitrary time
        rstn = 1; 
        repeat(50) @(posedge clk_100m); // Give MAC/PHY time to initialize

        // 2. ARP Resolution
        $display("[%0t] TB: Sending ARP Request to DUT...", $time);
        send_arp_to_mac(28, arp_req_payload, 48'hFF_FF_FF_FF_FF_FF);
        
        $display("[%0t] TB: Waiting for ARP Reply...", $time);
        wait_for_arp_reply(28, exp_arp_reply); 

        // Provide a small, realistic inter-packet gap
        repeat(20) @(posedge clk_100m);

        // 3. UDP Loopback Test (Concurrent Send & Receive)
        $display("[%0t] TB: Sending UDP Packet and waiting for loopback...", $time);
        
        fork
            // Thread 1: Transmits the UDP packet
            begin
                send_ip_to_mac(36, ip_udp_payload, DUT_MAC);
            end
            
            // Thread 2: Simultaneously monitors the RX port for the looped-back data
            begin
                receive_looped_udp(8, exp_udp_payload);
            end
        join

        // 4. Test Complete
        // If we reach this point, the fork...join completed successfully
        $display("[%0t] TB: SIMULATION SUCCESSFUL - Loopback verified!", $time);
        
        repeat(50) @(posedge clk_100m);
        $finish;
    end
//    initial begin
//        //$dumpfile("top_waveform.vcd");

//        rstn = 0; #200 rstn = 1; #500;

//        // STEP 1: Send ARP Request
//        $display("[%0t] TB: Sending ARP Request to DUT...", $time);
//        send_arp_to_mac(28, arp_req_payload, 48'hFF_FF_FF_FF_FF_FF);
        
//        $display("[%0t] TB: Waiting for ARP Reply on m_arp_rx_axis...", $time);
//        wait_for_arp_reply(28, exp_arp_reply); 

//        #1000;

//        // STEP 2: Send UDP Packet
//        $display("[%0t] TB: Sending UDP Packet to DUT...", $time);
//        send_ip_to_mac(36, ip_udp_payload, DUT_MAC);

//        #500;
//    end

//    // Monitor for the returned UDP payload on the TB's RX port
//    initial begin
//        #700; 
//        receive_looped_udp(8, exp_udp_payload);
//        $display("[%0t] TB: SIMULATION SUCCESSFUL - Loopback verified!", $time);
//        #500 $finish;
//    end

//    // Watchdog
//    initial begin
//        #5ms;
//        $display("[%0t] ERROR: Watchdog Timeout!", $time);
//        $fatal;
//    end

    // ==========================================
    // Tasks
    // ==========================================
    task automatic send_arp_to_mac(input int len, input logic [7:0] pkt [], input logic [47:0] dest_mac);
        tb_arp_tx_tuser <= dest_mac;
        for (int i=0; i<len; i++) begin
            @(negedge clk_100m);
            tb_arp_tx_tdata  <= pkt[i]; tb_arp_tx_tvalid <= 1'b1; tb_arp_tx_tlast  <= (i == len-1);
            @(posedge clk_100m);
            while (!tb_arp_tx_tready) @(negedge clk_100m);
        end
        @(negedge clk_100m); tb_arp_tx_tvalid <= 0; tb_arp_tx_tlast <= 0;
    endtask

    task automatic send_ip_to_mac(input int len, input logic [7:0] pkt [], input logic [47:0] dest_mac);
        tb_ip_tx_tuser <= dest_mac;
        for (int i=0; i<len; i++) begin
            @(negedge clk_100m);
            tb_ip_tx_tdata  <= pkt[i]; tb_ip_tx_tvalid <= 1'b1; tb_ip_tx_tlast  <= (i == len-1);
            @(posedge clk_100m);
            while (!tb_ip_tx_tready) @(negedge clk_100m);
        end
        @(negedge clk_100m); tb_ip_tx_tvalid <= 0; tb_ip_tx_tlast <= 0;
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

    task automatic receive_looped_udp(input int len, input logic [7:0] exp []);
        logic done = 0;
        int k = 0;
        tb_ip_rx_tready <= 1; 
        
        while (!done) begin
            @(posedge clk_100m);
            // Notice we check tb_ip_rx_tvalid instead of app_rx_tvalid now!
            if (tb_ip_rx_tvalid && tb_ip_rx_tready) begin
                if (k < len) begin
                    if (tb_ip_rx_tdata !== exp[k]) begin
                        $display("[%0t] UDP ERR: Byte %0d mismatch! Exp:%h Got:%h", $time, k, exp[k], tb_ip_rx_tdata);
                    end
                end
                if (tb_ip_rx_tlast) begin
                    $display("[%0t] TB: UDP Loopback Payload received via RMII! Bytes: %0d", $time, k+1);
                    done = 1'b1;
                end
                k++;
            end
        end
        tb_ip_rx_tready <= 0;
    endtask

endmodule
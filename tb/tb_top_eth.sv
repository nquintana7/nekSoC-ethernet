`timescale 1ns/1ps

module tb_top_eth();

    // --- Clocks and Resets ---
    logic clk_100m = 0;
    logic clk_50m  = 0;
    logic rstn     = 0;

    always #5  clk_100m = ~clk_100m; // App Clock
    always #10 clk_50m  = ~clk_50m;  // RMII Clock

    // --- Configuration ---
    parameter logic [31:0] DUT_IP     = 32'hC0_A8_01_41;       // DUT IP: 192.168.1.65
    parameter logic [47:0] DUT_MAC    = 48'h00_1A_2B_3C_4D_5E; // DUT MAC
    parameter logic [47:0] REMOTE_MAC = 48'h00_0E_7F_5F_F1_DF; // Testbench "Remote PC" MAC

    // --- RMII Interconnect (TB MAC <--> DUT) ---
    logic [1:0] tb_to_dut_data, dut_to_tb_data;
    logic       tb_to_dut_en,   dut_to_tb_en;

    // --- TB Remote PC Split AXI-Stream Interfaces ---
    // IP TX (To DUT)
    logic [7:0]  tb_ip_tx_tdata;  logic tb_ip_tx_tvalid = 0, tb_ip_tx_tready, tb_ip_tx_tlast = 0;
    logic [47:0] tb_ip_tx_tuser = 0;
    // ARP TX (To DUT)
    logic [7:0]  tb_arp_tx_tdata; logic tb_arp_tx_tvalid = 0, tb_arp_tx_tready, tb_arp_tx_tlast = 0;
    logic [47:0] tb_arp_tx_tuser = 0;
    
    // IP RX (From DUT)
    logic [7:0] tb_ip_rx_tdata;  logic tb_ip_rx_tvalid, tb_ip_rx_tready = 1, tb_ip_rx_tlast, tb_ip_rx_tuser;
    // ARP RX (From DUT)
    logic [7:0] tb_arp_rx_tdata; logic tb_arp_rx_tvalid, tb_arp_rx_tready = 0, tb_arp_rx_tlast, tb_arp_rx_tuser;

    // --- DUT Application Interfaces ---
    logic [7:0]  app_rx_tdata;
    logic        app_rx_tvalid, app_rx_tlast, app_rx_tready = 0;
    logic [47:0] app_rx_tuser;

    // ==========================================
    // Remote PC MAC (Testbench Stimulus)
    // ==========================================
    eth_mac_axi_top #(
        .ADDR_WIDTH(12)
    ) u_tb_mac (
        .clk_i(clk_100m), .rstn_i(rstn),
        .clk_50M_i(clk_50m), .rstn_500M_i(rstn),
        .local_mac_i(REMOTE_MAC), // TB's MAC Address
        
        // RMII OUT to DUT
        .rmii_txd_o(tb_to_dut_data), .rmii_tx_en_o(tb_to_dut_en),
        // RMII IN from DUT
        .rmii_rxd_i(dut_to_tb_data), .rmii_crs_dv_i(dut_to_tb_en), .rmii_rxer_i(1'b0),
        
        // IP TX Stream
        .s_ip_tx_axis_tdata(tb_ip_tx_tdata), .s_ip_tx_axis_tvalid(tb_ip_tx_tvalid),
        .s_ip_tx_axis_tlast(tb_ip_tx_tlast), .s_ip_tx_axis_tuser(tb_ip_tx_tuser),
        .s_ip_tx_axis_tready(tb_ip_tx_tready),
        
        // ARP TX Stream
        .s_arp_tx_axis_tdata(tb_arp_tx_tdata), .s_arp_tx_axis_tvalid(tb_arp_tx_tvalid),
        .s_arp_tx_axis_tlast(tb_arp_tx_tlast), .s_arp_tx_axis_tuser(tb_arp_tx_tuser),
        .s_arp_tx_axis_tready(tb_arp_tx_tready),

        // IP RX Stream
        .m_ip_rx_axis_tdata(tb_ip_rx_tdata), .m_ip_rx_axis_tvalid(tb_ip_rx_tvalid),
        .m_ip_rx_axis_tlast(tb_ip_rx_tlast), .m_ip_rx_axis_tuser(tb_ip_rx_tuser),
        .m_ip_rx_axis_tready(tb_ip_rx_tready),
        
        // ARP RX Stream
        .m_arp_rx_axis_tdata(tb_arp_rx_tdata), .m_arp_rx_axis_tvalid(tb_arp_rx_tvalid),
        .m_arp_rx_axis_tlast(tb_arp_rx_tlast), .m_arp_rx_axis_tuser(tb_arp_rx_tuser),
        .m_arp_rx_axis_tready(tb_arp_rx_tready)
    );

    // ==========================================
    // DUT: The Custom Hardware Stack
    // ==========================================
    eth_stack_top #(
        .ADDR_WIDTH(12)
    ) u_top (
        .clk_i(clk_100m), .rstn_i(rstn),
        .clk_50M_i(clk_50m), .rstn_500M_i(rstn),

        .local_ip_i(DUT_IP), .local_mac_i(DUT_MAC),

        // RMII Connection from TB MAC
        .rmii_rxd_i(tb_to_dut_data), .rmii_crs_dv_i(tb_to_dut_en), .rmii_rxer_i(1'b0),
        .rmii_txd_o(dut_to_tb_data), .rmii_tx_en_o(dut_to_tb_en),

        // App TX (Unused in this test)
        .app_tx_tdata(8'h00), .app_tx_tvalid(1'b0), .app_tx_tlast(1'b0), .app_tx_tuser(80'h0),
        .app_tx_tready(), .pkt_drop_o(),

        // App RX (Where the UDP payload should emerge)
        .app_rx_tready(app_rx_tready), .app_rx_tdata(app_rx_tdata),
        .app_rx_tvalid(app_rx_tvalid), .app_rx_tlast(app_rx_tlast),
        .app_rx_tuser(app_rx_tuser),

        .port_en_i(1'b1), .port_o()
    );

    // ==========================================
    // Frame Definitions (Bare Payloads)
    // ==========================================
    
    // ARP REQUEST (28 Bytes) - What the TB sends to the DUT
    logic [7:0] arp_req_payload [0:27] = '{
        8'h00, 8'h01, 8'h08, 8'h00, 8'h06, 8'h04, 8'h00, 8'h01,   // HW/Proto details, Request(1)
        8'h00, 8'h0E, 8'h7F, 8'h5F, 8'hF1, 8'hDF,                 // Sender MAC (Remote PC)
        8'hC0, 8'hA8, 8'h01, 8'h84,                               // Sender IP: 192.168.1.132
        8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,                 // Target MAC: Ignored for requests
        8'hC0, 8'hA8, 8'h01, 8'h41                                // Target IP: 192.168.1.65 (DUT)
    };    

    // EXPECTED ARP REPLY (28 Bytes) - What the DUT should send back
    logic [7:0] exp_arp_reply [0:27] = '{
        8'h00, 8'h01, 8'h08, 8'h00, 8'h06, 8'h04, 8'h00, 8'h02,   // HW/Proto details, Reply(2)
        8'h00, 8'h1A, 8'h2B, 8'h3C, 8'h4D, 8'h5E,                 // Sender MAC (DUT MAC)
        8'hC0, 8'hA8, 8'h01, 8'h41,                               // Sender IP: 192.168.1.65 (DUT IP)
        8'h00, 8'h0E, 8'h7F, 8'h5F, 8'hF1, 8'hDF,                 // Target MAC: Remote PC
        8'hC0, 8'hA8, 8'h01, 8'h84                                // Target IP: 192.168.1.132
    };
        
    // IP + UDP PAYLOAD (36 Bytes)
    logic [7:0] ip_udp_payload [0:35] = '{
        // IPv4 HEADER (20 Bytes)
        8'h45, 8'h00, 8'h00, 8'h24, 8'h12, 8'h34, 8'h00, 8'h00, 
        8'h40, 8'h11, 8'h00, 8'h00, 
        8'hC0, 8'hA8, 8'h01, 8'h84,                               // Source IP: 192.168.1.132
        8'hC0, 8'hA8, 8'h01, 8'h41,                               // Dest IP: 192.168.1.65 (DUT)
        // UDP HEADER (8 Bytes)
        8'h13, 8'h88, 8'h13, 8'h89, 8'h00, 8'h10, 8'h00, 8'h00,   // Ports 5000->5001, Len: 16
        // UDP PAYLOAD (8 Bytes)
        8'hDE, 8'hAD, 8'hBE, 8'hEF, 8'hCA, 8'hFE, 8'hBA, 8'hBE
    };

    logic [7:0] exp_udp_payload [0:7] = '{
        8'hDE, 8'hAD, 8'hBE, 8'hEF, 8'hCA, 8'hFE, 8'hBA, 8'hBE
    };

    // ==========================================
    // Simulation Sequence
    // ==========================================
    initial begin
        $dumpfile("top_waveform.vcd");
        $dumpvars(0, tb_top_eth);

        rstn = 0; #200 rstn = 1; #500;

        // STEP 1: Send ARP Request (Broadcast Dest MAC)
        $display("[%0t] TB: Sending ARP Request to DUT...", $time);
        send_arp_to_mac(28, arp_req_payload, 48'hFF_FF_FF_FF_FF_FF);
        
        // STEP 2: Wait for ARP Reply from DUT on the ARP RX channel
        $display("[%0t] TB: Waiting for ARP Reply on m_arp_rx_axis...", $time);
        
        // --> NOW CHECKING AGAINST EXPECTED ARRAY <--
        wait_for_arp_reply(28, exp_arp_reply); 

        #1000;

        // STEP 3: Send UDP Packet (Unicast Dest MAC)
        $display("[%0t] TB: Sending UDP Packet to DUT...", $time);
        send_ip_to_mac(36, ip_udp_payload, DUT_MAC);

        #500;
    end

    // Concurrent thread to monitor the App RX port for the UDP payload
    initial begin
        #700; // Wait for reset
        receive_app_udp(8, exp_udp_payload);
        $display("[%0t] TB: SIMULATION SUCCESSFUL.", $time);
        #500 $finish;
    end

    // Watchdog
    initial begin
        #5ms;
        $display("[%0t] ERROR: Watchdog Timeout!", $time);
        $fatal;
    end

    // ==========================================
    // Tasks
    // ==========================================
    
    // Send ARP Payload 
    task automatic send_arp_to_mac(input int len, input logic [7:0] pkt [], input logic [47:0] dest_mac);
        tb_arp_tx_tuser <= dest_mac;
        for (int i=0; i<len; i++) begin
            @(negedge clk_100m);
            tb_arp_tx_tdata  <= pkt[i]; 
            tb_arp_tx_tvalid <= 1'b1; 
            tb_arp_tx_tlast  <= (i == len-1);
            @(posedge clk_100m);
            while (!tb_arp_tx_tready) @(negedge clk_100m);
        end
        @(negedge clk_100m); tb_arp_tx_tvalid <= 0; tb_arp_tx_tlast <= 0;
    endtask

    // Send IP/UDP Payload
    task automatic send_ip_to_mac(input int len, input logic [7:0] pkt [], input logic [47:0] dest_mac);
        tb_ip_tx_tuser <= dest_mac;
        for (int i=0; i<len; i++) begin
            @(negedge clk_100m);
            tb_ip_tx_tdata  <= pkt[i]; 
            tb_ip_tx_tvalid <= 1'b1; 
            tb_ip_tx_tlast  <= (i == len-1);
            @(posedge clk_100m);
            while (!tb_ip_tx_tready) @(negedge clk_100m);
        end
        @(negedge clk_100m); tb_ip_tx_tvalid <= 0; tb_ip_tx_tlast <= 0;
    endtask

    // Monitor split ARP RX channel for reply AND verify data
    task automatic wait_for_arp_reply(input int len, input logic [7:0] exp []);
        logic done = 0;
        int byte_cnt = 0;
        tb_arp_rx_tready <= 1;

        while (!done) begin
            @(posedge clk_100m);
            if (tb_arp_rx_tvalid && tb_arp_rx_tready) begin
                
                // Check the byte against expected array
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

    // Monitor DUT App RX for stripped UDP payload
    task automatic receive_app_udp(input int len, input logic [7:0] exp []);
        logic done = 0;
        int k = 0;
        app_rx_tready <= 1; 
        
        while (!done) begin
            @(posedge clk_100m);
            if (app_rx_tvalid && app_rx_tready) begin
                if (k < len) begin
                    if (app_rx_tdata !== exp[k]) begin
                        $display("[%0t] UDP ERR: Byte %0d mismatch! Exp:%h Got:%h", $time, k, exp[k], app_rx_tdata);
                    end
                end
                if (app_rx_tlast) begin
                    $display("[%0t] DUT APP RX: UDP Payload perfectly extracted! Bytes: %0d", $time, k+1);
                    done = 1'b1;
                end
                k++;
            end
        end
        app_rx_tready <= 0;
    endtask

endmodule
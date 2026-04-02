`timescale 1ns/1ps

module tb_rx_path();
    logic clk_100m = 0, clk_50m = 0, rstn = 0;
    always #4  clk_100m = ~clk_100m; // App Clock
    always #10 clk_50m  = ~clk_50m;  // RMII Clock

    logic [1:0] loop_data;
    logic       loop_en;

    logic [7:0] tx_tdata; logic tx_tvalid = 0, tx_tready = 0, tx_tlast = 0;
    logic [7:0] rx_mac_tdata; logic rx_mac_tvalid = 0, rx_mac_tready = 0, rx_mac_tlast = 0;

    parameter logic [31:0] local_ip  = 32'hC0_A8_01_41; 
    parameter logic [47:0] local_mac = 48'h00_1A_2B_3C_4D_5E;

    eth_mac_axi_top u_mac (
        .clk_50M_i(clk_50m), .rstn_500M_i(rstn),
        .rmii_txd_o(loop_data), .rmii_tx_en_o(loop_en),
        .rmii_rxd_i(loop_data), .rmii_crs_dv_i(loop_en), .rmii_rxer_i(1'b0),
        .s_axis_clk(clk_100m), .s_axis_resetn(rstn),
        .s_axis_tdata(tx_tdata), .s_axis_tvalid(tx_tvalid),
        .s_axis_tready(tx_tready), .s_axis_tlast(tx_tlast),
        .m_axis_clk(clk_100m), .m_axis_resetn(rstn),
        .m_axis_tdata(rx_mac_tdata), .m_axis_tvalid(rx_mac_tvalid),
        .m_axis_tready(rx_mac_tready), .m_axis_tlast(rx_mac_tlast), .m_axis_tuser()
    );

    // --- Signals for IP/UDP Side ---
    logic [7:0]  rx_ip_tdata; logic rx_ip_tvalid, rx_ip_tready, rx_ip_tlast;
    logic [48:0] rx_ip_tuser_49; // From new Parser ({src_mac, error})
    logic        rx_ip_tuser;    // To IP Rx (Just the error bit)
    assign rx_ip_tuser = rx_ip_tuser_49[0];

    logic [7:0]  rx_udp_stdata; logic rx_udp_stvalid = 0, rx_udp_stready = 0, rx_udp_stlast = 0;
    logic [31:0] rx_udp_stuser;

    logic [7:0]  rx_udp_mtdata; logic rx_udp_mtvalid = 0, rx_udp_mtready = 0, rx_udp_mtlast = 0;
    logic [47:0] rx_udp_tuser;

    // --- Signals for ARP Side ---
    logic [7:0]  rx_arp_tdata; logic rx_arp_tvalid, rx_arp_tready, rx_arp_tlast;
    logic [48:0] rx_arp_tuser_49; // From new Parser ({src_mac, error})
    logic        rx_arp_tuser;    // To ARP Top (Just the error bit)
    assign rx_arp_tuser = rx_arp_tuser_49[0];

    // ==========================================
    // MODULE INSTANTIATIONS
    // ==========================================

    frame_parser u_frame_parser (
        .clk_i(clk_100m),
        .rstn_i(rstn),

        .local_mac_addr_i(local_mac),

        // Input from MAC
        .s_axis_tdata(rx_mac_tdata),
        .s_axis_tvalid(rx_mac_tvalid),
        .s_axis_tlast(rx_mac_tlast),
        .s_axis_tuser(1'b0),
        .s_axis_tready(rx_mac_tready),

        // Output IP Stream directly to IP_RX
        .m_ip_axis_tready(rx_ip_tready),
        .m_ip_axis_tdata(rx_ip_tdata),
        .m_ip_axis_tvalid(rx_ip_tvalid),
        .m_ip_axis_tlast(rx_ip_tlast),
        .m_ip_axis_tuser(rx_ip_tuser_49), 

        // Output ARP Stream directly to ARP_TOP
        .m_arp_axis_tready(rx_arp_tready),
        .m_arp_axis_tdata(rx_arp_tdata),
        .m_arp_axis_tvalid(rx_arp_tvalid),
        .m_arp_axis_tlast(rx_arp_tlast),
        .m_arp_axis_tuser(rx_arp_tuser_49) 
    );    

    arp_top u_arp (
        .clk_i(clk_100m),
        .rstn_i(rstn),

        .local_ip_i(local_ip),

        .rd_ip_i(),
        .rd_mac_o(),
        .rd_miss_o(),

        .s_axis_tdata(rx_arp_tdata),
        .s_axis_tvalid(rx_arp_tvalid),
        .s_axis_tlast(rx_arp_tlast),
        .s_axis_tuser(rx_arp_tuser),
        .s_axis_tready(rx_arp_tready),

        .trigger_reply_o()
    );

    ip_rx u_ip_rx (
        .clk_i(clk_100m),
        .rstn_i(rstn),
        .local_ip_i(local_ip),

        // From Frame Parser Router
        .s_axis_tdata(rx_ip_tdata),
        .s_axis_tvalid(rx_ip_tvalid),
        .s_axis_tlast(rx_ip_tlast),
        .s_axis_tuser(rx_ip_tuser),
        .s_axis_tready(rx_ip_tready),
        
        // Out to UDP
        .m_axis_tdata(rx_udp_stdata),
        .m_axis_tvalid(rx_udp_stvalid),
        .m_axis_tlast(rx_udp_stlast),
        .m_axis_tuser(rx_udp_stuser), // Source IP 
        .m_axis_tready(rx_udp_stready)
    );

    udp_rx u_udp_rx (
        .clk_i(clk_100m),
        .rstn_i(rstn),

        // Check Ports
        .port_en_i(1'b1),
        .port_o(),

        // From IP Rx
        .s_axis_tdata(rx_udp_stdata),
        .s_axis_tvalid(rx_udp_stvalid),
        .s_axis_tlast(rx_udp_stlast),
        .s_axis_tuser(rx_udp_stuser),
        .s_axis_tready(rx_udp_stready),
        
        // Output to App Demux
        .m_axis_tready(rx_udp_mtready), 
        .m_axis_tdata(rx_udp_mtdata),
        .m_axis_tvalid(rx_udp_mtvalid),
        .m_axis_tlast(rx_udp_mtlast),
        .m_axis_tuser(rx_udp_tuser) // {Source IP, Source Port}
    );  

    // FRAME 1: ARP Request (Who has 192.168.1.65? Tell 192.168.1.132)
    logic [7:0] frame1 [0:59] = '{
            // --- ETHERNET HEADER (14 Bytes) ---
            8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, // Dest MAC: Broadcast
            8'h00, 8'h0E, 8'h7F, 8'h5F, 8'hF1, 8'hDF, // Src MAC: Remote Device
            8'h08, 8'h06,                             // EtherType: ARP (0x0806)
            // --- ARP PAYLOAD (28 Bytes) ---
            8'h00, 8'h01, 8'h08, 8'h00, 8'h06, 8'h04, 8'h00, 8'h01, 
            8'h00, 8'h0E, 8'h7F, 8'h5F, 8'hF1, 8'hDF, 
            8'hC0, 8'hA8, 8'h01, 8'h84,               
            8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 
            8'hC0, 8'hA8, 8'h01, 8'h41,               
            // --- PADDING (18 Bytes to reach 60 byte min frame size) ---
            8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 
            8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00
    };    
        
    // FRAME 2: UDP Packet (Src Port 5000, Dest Port 5001)
    logic [7:0] frame2 [0:63] = '{
        // --- ETHERNET HEADER (14 Bytes) ---
        8'h00, 8'h1A, 8'h2B, 8'h3C, 8'h4D, 8'h5E, 8'h00, 8'h0E, 8'h7F, 8'h5F, 8'hF1, 8'hDF, 8'h08, 8'h00,                             
        // --- IPv4 HEADER (20 Bytes) ---
        8'h45, 8'h00, 8'h00, 8'h24, 8'h12, 8'h34, 8'h00, 8'h00, 8'h40, 8'h11, 8'h00, 8'h00, 
        8'hC0, 8'hA8, 8'h01, 8'h84, 8'hC0, 8'hA8, 8'h01, 8'h41,               
        // --- UDP HEADER (8 Bytes) ---
        8'h13, 8'h88, 8'h13, 8'h89, 8'h00, 8'h10, 8'h00, 8'h00,                             
        // --- UDP PAYLOAD (8 Bytes) ---
        8'hDE, 8'hAD, 8'hBE, 8'hEF, 8'hCA, 8'hFE, 8'hBA, 8'hBE,
        // --- PADDING (14 Bytes) ---
        8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00
    };

    logic [7:0] exp_udp [0:21] = '{
        8'hDE, 8'hAD, 8'hBE, 8'hEF, 8'hCA, 8'hFE, 8'hBA, 8'hBE, 
        8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00
    };

    initial begin
        $dumpfile("tb_rx_path.vcd");
        $dumpvars(0, tb_rx_path);

        rstn = 0; #200 rstn = 1;

        fork
            begin // TX Thread
                send_axis(60, frame1);
                #2000;
                send_axis(64, frame2);
            end
            begin // RX Thread
                receive_udp_payload(22, exp_udp);
                $display("FINISH FRAME 2 (UDP).");
                $finish;
            end
        join_any
    end

    task send_axis(input int len, input logic [7:0] pkt []);
        for (int i=0; i<len; i++) begin
            @(negedge clk_100m);
            tx_tdata  <= pkt[i]; 
            tx_tvalid <= 1'b1; 
            tx_tlast  <= (i == len-1);
            @(posedge clk_100m);
            while (!tx_tready) begin
                @(negedge clk_100m);
            end
        end
        @(negedge clk_100m); tx_tvalid <= 0; tx_tlast <= 0;
    endtask

    initial begin
        #1ms;
        $display("ERROR: Simulation Watchdog Timeout!");
        $fatal;
    end

    task automatic receive_udp_payload(input int len, input logic [7:0] exp []);
        logic done = 0;
        int k = 0;
        rx_udp_mtready <= 1;
        
        while (!done) begin
            @(posedge clk_100m);
            if (rx_udp_mtvalid && rx_udp_mtready) begin
                if (k < len) begin
                    if (rx_udp_mtdata !== exp[k]) begin
                        $display("[%0t] UDP ERR: Byte %0d mismatch! Exp:%h Got:%h", $time, k, exp[k], rx_udp_mtdata);
                    end
                end
                
                if (rx_udp_mtlast) begin
                    $display("[%0t] UDP RX: TLAST detected. Payload bytes matched: %0d", $time, k+1);
                    $display("[%0t] UDP RX METADATA: Source IP: %h, Source Port: %h", $time, rx_udp_tuser[47:16], rx_udp_tuser[15:0]);
                    done = 1'b1;
                end
                k++;
            end
        end
        rx_udp_mtready <= 0;
    endtask

endmodule
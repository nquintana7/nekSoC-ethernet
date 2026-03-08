`timescale 1ns/1ps

module tb_eth_mac();

    // --- Clock & Reset ---
    logic clk_100m = 0;
    logic clk_50m  = 0;
    logic rstn     = 0;

    always #5  clk_100m = ~clk_100m; // Application Domain
    always #10 clk_50m  = ~clk_50m;  // RMII Domain

    // --- Physical Loopback ---
    logic [1:0] loop_data;
    logic       loop_en;

    // --- App Interface Signals ---
    logic [7:0] tx_data_in  = 0;
    logic       tx_wren     = 0;
    logic       tx_commit   = 0;
    logic       tx_full;

    logic       rx_rden     = 0;
    logic       rx_len_rden = 0;
    logic       rx_ready;
    logic [10:0] rx_len;
    logic [7:0]  rx_data_out;
    logic        rx_valid;
    
    logic [10:0] pkt_len;

    // DUT
    eth_mac dut (
        .clk_i               (clk_100m),
        .ref_mac_clk_i       (clk_50m),
        .rstn_i              (rstn),
        .mac_rstn_i          (rstn),

        // Physical Loopback
        .phy_rxd_i           (loop_data),
        .phy_crs_dv          (loop_en),
        .phy_rxer_i          (1'b0),
        .phy_txd_o           (loop_data),
        .phy_txen_o          (loop_en),

        // Application TX
        .pkt_tx_data_i       (tx_data_in),
        .pkt_tx_wren_i       (tx_wren),
        .pkt_tx_commit_i     (tx_commit),
        .pkt_tx_full_o       (tx_full),

        // Application RX
        .pkt_rx_data_rden_i  (rx_rden),
        .pkt_rx_len_rden_i   (rx_len_rden),
        .pkt_rx_ready_o      (rx_ready),
        .pkt_rx_len_o        (rx_len),
        .pkt_rx_data_o       (rx_data_out),
        .pkt_rx_data_valid_o (rx_valid)
    );
        
        logic [7:0] real_ethernet_frame [0:59] = '{
            // --- MAC HEADER (14 bytes) ---
            8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, // Dest MAC: Broadcast
            8'h00, 8'h0E, 8'h7F, 8'h5F, 8'hF1, 8'hDF, // Src MAC: 00:0e:7f:5f:f1:df
            8'h08, 8'h06,                             // EtherType: ARP (0x0806)
    
            // --- ARP PAYLOAD (28 bytes) ---
            8'h00, 8'h01, 8'h08, 8'h00, 8'h06, 8'h04, // Hardware/Protocol types & sizes
            8'h00, 8'h01,                             // Opcode: Request
            8'h00, 8'h0E, 8'h7F, 8'h5F, 8'hF1, 8'hDF, // Sender MAC
            8'hC0, 8'hA8, 8'h01, 8'h84,               // Sender IP: 192.168.1.132
            8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, // Target MAC: 00:00:00:00:00:00 (Unknown)
            8'hC0, 8'hA8, 8'h01, 8'h41,               // Target IP: 192.168.1.65
    
            // --- PADDING (18 bytes) ---
            // Ethernet requires a minimum 60-byte payload before the FCS
            8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 
            8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 
            8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00
    
            // --- FCS / CRC-32 (4 bytes) ---
            // This is the actual hardware-calculated CRC appended by the source PHY
            //8'hF9, 8'hA6, 8'hDF, 8'h13                
        };
        
        logic [7:0] real_ethernet_frame2 [0:65] = '{
            // --- MAC HEADER (14 bytes) ---
            8'hAB, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, // Dest MAC: Broadcast
            8'h00, 8'h0E, 8'hCD, 8'h5F, 8'hF1, 8'hDF, // Src MAC: 00:0e:7f:5f:f1:df
            8'h08, 8'h06,                             // EtherType: ARP (0x0806)
    
            // --- ARP PAYLOAD (28 bytes) ---
            8'h00, 8'h01, 8'h08, 8'h00, 8'hFF, 8'h04, // Hardware/Protocol types & sizes
            8'h00, 8'h01,                             // Opcode: Request
            8'h00, 8'hAA, 8'h7F, 8'h5F, 8'hEE, 8'hDF, // Sender MAC
            8'hC0, 8'hA8, 8'h01, 8'h84,               // Sender IP: 192.168.1.132
            8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, // Target MAC: 00:00:00:00:00:00 (Unknown)
            8'hC0, 8'hA8, 8'h01, 8'h41,               // Target IP: 192.168.1.65
    
            // --- PADDING (18 bytes) ---
            // Ethernet requires a minimum 60-byte payload before the FCS
            8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 
            8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 
            8'h00, 8'h00, 8'hDA, 8'h00, 8'hEE, 8'hAA,
            8'h00, 8'h00, 8'hDA, 8'h00, 8'hBB, 8'hBC         
        };
// ---------------------------------------------------------
    // Test Procedure
    // ---------------------------------------------------------
    logic error_found = 0;
    initial begin
        rstn = 0;
        #200 rstn = 1;
        
        // --- 1. TRANSMIT ---
        wait(!tx_full);
        $display("[%0t] APP: TX Buffer clear. Writing ARP Frame...", $time);

        for (int i=0; i<60; i++) begin
            @(posedge clk_100m);
            tx_data_in <= real_ethernet_frame[i];
            tx_wren    <= 1'b1;
        end

        @(posedge clk_100m);
        tx_wren   <= 1'b0;
        tx_commit <= 1'b1;
        @(posedge clk_100m);
        tx_commit <= 1'b0;
        $display("[%0t] APP: Frame committed to TX Buffer.", $time);

        // --- 2. RECEIVE ---
        wait(rx_ready);
        $display("[%0t] APP: RX Packet detected! Length: %0d", $time, rx_len);

        // Pop length
        @(posedge clk_100m);
        rx_len_rden <= 1'b1;
        pkt_len <= rx_len;
        @(posedge clk_100m);
        rx_len_rden <= 1'b0;

        // Stream out data and verify
        rx_rden <= 1'b1;
        for (int j=0; j<pkt_len; j++) begin
            @(posedge clk_100m);
            
            while (!rx_valid) begin
                @(posedge clk_100m);
            end
            
            if (rx_data_out !== real_ethernet_frame[j]) begin
                $display("[%0t] ERR: Byte %0d mismatch! Exp:%h Got:%h", $time, j, real_ethernet_frame[j], rx_data_out);
                error_found <= 1;
            end else begin
                $display("[%0t] OK: Byte %02d: %h", $time, j, rx_data_out);
            end

        end

        @(posedge clk_100m);
        rx_rden <= 1'b0;
        if (error_found) begin
            $display("[%0t] TEST FAILED: Logic errors detected.", $time);
        end else begin
            $display("[%0t] TEST COMPLETE: Frame loopback verified. No Errors.", $time);
        end
        #1000;
        
        // --- 2. TRANSMIT ---
        wait(!tx_full);
        $display("[%0t] APP: TX Buffer clear. Writing ARP Frame...", $time);

        for (int i=0; i<63; i++) begin
            @(posedge clk_100m);
            tx_data_in <= real_ethernet_frame2[i];
            tx_wren    <= 1'b1;
        end

        @(posedge clk_100m);
        tx_wren   <= 1'b0;
        tx_commit <= 1'b1;
        @(posedge clk_100m);
        tx_commit <= 1'b0;
        $display("[%0t] APP: Frame committed to TX Buffer.", $time);

        // --- 2. RECEIVE ---
        wait(rx_ready);
        $display("[%0t] APP: RX Packet detected! Length: %0d", $time, rx_len);

        // Pop length
        @(posedge clk_100m);
        rx_len_rden <= 1'b1;
        pkt_len <= rx_len;
        @(posedge clk_100m);
        rx_len_rden <= 1'b0;

        // Stream out data and verify
        rx_rden <= 1'b1;
        for (int j=0; j<pkt_len; j++) begin
            @(posedge clk_100m);
            
            while (!rx_valid) begin
                @(posedge clk_100m);
            end
            
            if (rx_data_out !== real_ethernet_frame2[j]) begin
                $display("[%0t] ERR: Byte %0d mismatch! Exp:%h Got:%h", $time, j, real_ethernet_frame2[j], rx_data_out);
                error_found <= 1;
            end else begin
                $display("[%0t] OK: Byte %02d: %h", $time, j, rx_data_out);
            end

        end

        @(posedge clk_100m);
        rx_rden <= 1'b0;
        if (error_found) begin
            $display("[%0t] TEST FAILED: Logic errors detected.", $time);
        end else begin
            $display("[%0t] TEST COMPLETE: Frame loopback verified. No Errors.", $time);
        end
        
        
        #1000 $finish;
    end

    // Monitor for CRC Failures
    initial begin
        forever begin
            @(posedge clk_50m);
            if (dut.u_rx_mac.mac_rx_fcs_err_o) begin
                $display("[%0t] !!! ALERT !!! RX MAC reported CRC Error!", $time);
            end
        end
    end

endmodule
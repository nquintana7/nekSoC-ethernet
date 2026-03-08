`timescale 1ns/1ps

module tb_rx_packet_buffer();

    // -----------------------------------------
    // Clock and Reset Signals
    // -----------------------------------------
    logic wclk = 0;
    logic rclk = 0;
    logic wrstn = 0;
    logic rrstn = 0;

    // MAC Side (Write)
    logic       mac_rx_sof;
    logic       mac_rx_eof;
    logic [7:0] mac_rx_data;
    logic       mac_rx_valid;
    logic       mac_rx_fcs_err;

    // ARP/UDP Side (Read)
    logic        rd_en = 0;
    logic        pkt_rden = 0;
    logic        pkt_done = 0;
    logic        pkt_ready;
    logic [10:0] pkt_len;
    logic [7:0]  data_out;
    logic        data_valid;
    
    // -----------------------------------------
    // PHY -> MAC Signals (Stimulus)
    // -----------------------------------------
    logic       phy_rx_active_i = 0;
    logic [7:0] phy_rx_data_i = 0;
    logic       phy_rx_dv_i = 0;
    logic       phy_rx_err_i = 0;

    // -----------------------------------------
    // Clock Generation
    // wclk = 50 MHz (RMII), rclk = 100 MHz (System)
    // -----------------------------------------
    always #10 wclk = ~wclk; 
    always #5  rclk = ~rclk;

    // -----------------------------------------
    // DUT Instantiation
    // -----------------------------------------
    eth_mac u_mac (
        .clk_i            (wclk),
        .rstn_i           (wrstn),
        // From PHY
        .phy_rx_active_i  (phy_rx_active_i),
        .phy_rx_data_i    (phy_rx_data_i),
        .phy_rx_dv_i      (phy_rx_dv_i),
        .phy_rx_err_i     (phy_rx_err_i),
        // To Buffer
        .mac_rx_sof_o     (mac_rx_sof),
        .mac_rx_eof_o     (mac_rx_eof),
        .mac_rx_data_o    (mac_rx_data),
        .mac_rx_valid_o   (mac_rx_valid),
        .mac_rx_fcs_err_o (mac_rx_fcs_err),
        
        // TX ports ignored for this RX test
        .phy_tx_data_o    (),
        .phy_tx_en_o      (),
        .phy_tx_ready_i   (1'b0)
    );
    
    rx_packet_buffer #(
        .ADDR_WIDTH(12),
        .DATA_WIDTH(8)
    ) dut (
        .wclk_i           (wclk),
        .wrstn_i          (wrstn),
        .mac_din          (mac_rx_data),
        .mac_valid_i      (mac_rx_valid),
        .mac_start_i      (mac_rx_sof),
        .mac_end_i        (mac_rx_eof),
        .mac_crc_fail_i   (mac_rx_fcs_err),

        .rclk_i(rclk),
        .rrstn_i(rrstn),
        .data_rden_i(rd_en),
        .pkt_len_rden_i(pkt_rden),
        .pkt_done_i(pkt_done),
        .pkt_ready_o(pkt_ready),
        .pkt_len_o(pkt_len),
        .data_o(data_out),
        .data_valid_o(data_valid)
    );

        
    logic [7:0] real_ethernet_frame [0:63] = '{
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
            8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
    
            // --- FCS / CRC-32 (4 bytes) ---
            // This is the actual hardware-calculated CRC appended by the source PHY
            8'hF9, 8'hA6, 8'hDF, 8'h13                
        };

    logic [31:0] fcs;
    logic [7:0] fcs_bytes [3:0];
    int frame_len;
    initial begin
        // Reset
        phy_rx_active_i = 0;
        phy_rx_dv_i = 0;
        wrstn = 0; rrstn = 0;
        #100;
        wrstn = 1; rrstn = 1;
        #100;
        
        // Send packet byte by byte
        @(posedge wclk);
        phy_rx_active_i = 1;
        @(posedge wclk);  
        foreach (real_ethernet_frame[i]) begin
            @(posedge wclk);           // keep byte valid for 1 clock
            phy_rx_data_i = real_ethernet_frame[i];
            phy_rx_dv_i = 1;
            @(posedge wclk);           // keep byte valid for 1 clock
            phy_rx_dv_i = 0;
            @(posedge wclk);           // gap of 1 clock   
        end
        
        // End of packet
        phy_rx_active_i = 0;
        phy_rx_dv_i = 0;

        #1000;
        $finish;
    end

    initial begin
        int length;
        logic [7:0] extracted_header [0:13];

        // Wait for the Buffer to signal a good packet
        wait(pkt_ready == 1'b1);
        @(posedge rclk);
        
        pkt_rden <= 1'b1;
        @(posedge rclk);
        pkt_rden <= 1'b0;
        
        length = pkt_len;
        $display("-------------------------------------------------");
        $display("Packet Received in App Domain! Length: %0d bytes", length);

        // Assert Read Enable
        rd_en <= 1'b1;
        
        // Loop through the packet (compensating for 1-cycle read latency)
        for (int i = 0; i < length; i++) begin
            @(posedge rclk);
            
            // Stop asserting rd_en on the very last byte
            if (i == length - 1) rd_en <= 1'b0;

            // Capture the first 14 bytes into our header array
            if (data_valid && i > 0 && i <= 14) begin
                extracted_header[i-1] = data_out;
            end
        end

        // Print the parsed results
        $display("Destination MAC: %02x:%02x:%02x:%02x:%02x:%02x", 
            extracted_header[0], extracted_header[1], extracted_header[2], 
            extracted_header[3], extracted_header[4], extracted_header[5]);
            
        $display("Source MAC:      %02x:%02x:%02x:%02x:%02x:%02x", 
            extracted_header[6], extracted_header[7], extracted_header[8], 
            extracted_header[9], extracted_header[10], extracted_header[11]);
            
        $display("EtherType:       0x%02x%02x", extracted_header[12], extracted_header[13]);
        $display("-------------------------------------------------");
    end

endmodule
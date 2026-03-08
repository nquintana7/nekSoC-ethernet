module eth_mac (
    input logic clk_i,
    input logic ref_mac_clk_i,
    input logic rstn_i,
    input logic mac_rstn_i,

    // --- Physical RMII Pins ---
    input  logic [1:0] phy_rxd_i,
    input  logic       phy_crs_dv,
    input  logic       phy_rxer_i,
    output logic [1:0] phy_txd_o,
    output logic       phy_txen_o,

    // --- Upper Layer Interface ---
    // Transmit Side
    input  logic [7:0]  pkt_tx_data_i,
    input  logic        pkt_tx_wren_i,
    input  logic        pkt_tx_commit_i,
    output logic        pkt_tx_full_o,

    // Receive Side
    input  logic        pkt_rx_data_rden_i,
    input  logic        pkt_rx_len_rden_i,
    output logic        pkt_rx_ready_o,
    output logic [10:0] pkt_rx_len_o,
    output logic [7:0]  pkt_rx_data_o,
    output logic        pkt_rx_data_valid_o
);

    // ---------------------------------------------------------
    // Internal Interconnect Wires
    // ---------------------------------------------------------
    
    // Bridge <-> MACs
    logic [7:0] rmii_mac_rx_data;
    logic       rmii_mac_rx_valid, rmii_mac_rx_active, rmii_mac_rx_err;
    
    logic [7:0] rmii_mac_tx_data;
    logic       rmii_mac_tx_valid, rmii_mac_tx_last, bridge_to_tx_mac_ready;

    // MACs <-> Buffers
    logic       rx_mac_sof, rx_mac_eof, rx_mac_valid, rx_mac_fcs_err;
    logic [7:0] rx_mac_data;
    
    logic       tx_buf_start, tx_buf_last, tx_mac_rd_en, tx_mac_ready;
    logic [7:0] tx_buf_data;

    // ---------------------------------------------------------
    // RMII
    // ---------------------------------------------------------
    rmii_phy u_rmii (
        .clk_i           (ref_mac_clk_i),
        .rstn_i          (mac_rstn_i),
        // To Physical Pins
        .rxd_i           (phy_rxd_i),
        .crs_dv          (phy_crs_dv),
        .rxer_i          (phy_rxer_i),
        .txd_o           (phy_txd_o),
        .txen_o          (phy_txen_o),
        // To MACs
        .tx_byte_i       (rmii_mac_tx_data),
        .tx_byte_valid_i (rmii_mac_tx_valid),
        .tx_last_byte_i  (rmii_mac_tx_last),
        .tx_ready_o      (bridge_to_tx_mac_ready),
        .rx_byte_o       (rmii_mac_rx_data),
        .rx_byte_valid_o (rmii_mac_rx_valid),
        .rx_active_o     (rmii_mac_rx_active),
        .byte_error_o    (rmii_mac_rx_err)
    );

    // ---------------------------------------------------------
    // RX MAC + CDC BUFFER
    // ---------------------------------------------------------
    eth_rx_mac u_rx_mac (
        .clk_i           (ref_mac_clk_i),
        .rstn_i          (mac_rstn_i),
        .phy_rx_active_i (rmii_mac_rx_active),
        .phy_rx_data_i   (rmii_mac_rx_data),
        .phy_rx_dv_i     (rmii_mac_rx_valid),
        .phy_rx_err_i    (rmii_mac_rx_err),
        .mac_rx_sof_o    (rx_mac_sof),
        .mac_rx_eof_o    (rx_mac_eof),
        .mac_rx_data_o   (rx_mac_data),
        .mac_rx_valid_o  (rx_mac_valid),
        .mac_rx_fcs_err_o(rx_mac_fcs_err)
    );

    eth_rx_packet_buffer #(
        .ADDR_WIDTH(12)
    ) u_rx_buffer (
        .wclk_i          (ref_mac_clk_i),
        .wrstn_i         (mac_rstn_i),
        .mac_din         (rx_mac_data),
        .mac_valid_i     (rx_mac_valid),
        .mac_start_i     (rx_mac_sof),
        .mac_end_i       (rx_mac_eof),
        .mac_crc_fail_i  (rx_mac_fcs_err),
        .rclk_i          (clk_i),
        .rrstn_i         (rstn_i),
        .data_rden_i     (pkt_rx_data_rden_i),
        .pkt_len_rden_i  (pkt_rx_len_rden_i),
        .pkt_ready_o     (pkt_rx_ready_o),
        .pkt_len_o       (pkt_rx_len_o),
        .data_o          (pkt_rx_data_o),
        .data_valid_o    (pkt_rx_data_valid_o)
    );

    // ---------------------------------------------------------
    // TX MAC + CDC BUFFER
    // ---------------------------------------------------------
    tx_packet_buffer #(
        .ADDR_WIDTH(12)
    ) u_tx_buffer (
        .pkt_clk_i       (clk_i),
        .pkt_rstn_i      (rstn_i),
        .pkt_data_i      (pkt_tx_data_i),
        .pkt_wren_i      (pkt_tx_wren_i),
        .pkt_commit_i    (pkt_tx_commit_i),
        .pkt_fifo_full_o (pkt_tx_full_o),
        .mac_clk_i       (ref_mac_clk_i),
        .mac_rstn_i      (rstn_i),
        .tx_start_o      (tx_buf_start),
        .tx_data_o       (tx_buf_data),
        .tx_last_o       (tx_buf_last),
        .tx_rd_en_i      (tx_mac_rd_en),
        .tx_ready_i      (tx_mac_ready)
    );

    eth_tx_mac u_tx_mac (
        .clk_i               (ref_mac_clk_i),
        .rstn_i              (rstn_i),
        .tx_start_i          (tx_buf_start),
        .tx_last_i           (tx_buf_last),
        .tx_data_i           (tx_buf_data),
        .tx_rd_en_o          (tx_mac_rd_en),
        .tx_ready_o          (tx_mac_ready),
        .phy_tx_ready_i      (bridge_to_tx_mac_ready),
        .phy_tx_data_o       (rmii_mac_tx_data),
        .phy_tx_valid_data_o (rmii_mac_tx_valid),
        .phy_tx_last_byte_o  (rmii_mac_tx_last)
    );

endmodule
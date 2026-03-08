module eth_mac_axi_top #(
    parameter ADDR_WIDTH = 12 // 4KB buffers
)(
    // --- Clock and Reset ---
    input  logic        clk_mac_ref_i,
    input  logic        mac_rstn_i,
    // --- Physical RMII Pins (Nexys A7) ---
    output logic [1:0]  rmii_txd_o,
    output logic        rmii_tx_en_o,
    input  logic [1:0]  rmii_rxd_i,
    input  logic        rmii_crs_dv_i,
    input  logic        rmii_rxer_i,
    // --- AXI-Stream Slave (connected to TX) ---
    input  logic        s_axis_clk,
    input  logic        s_axis_aresetn,
    input  logic [7:0]  s_axis_tx_tdata,
    input  logic        s_axis_tx_tvalid,
    output logic        s_axis_tx_tready,
    input  logic        s_axis_tx_tlast,
    // --- AXI-Stream Master (connected to RX) ---
    input  logic        m_axis_clk,
    input  logic        m_axis_aresetn,
    output logic [7:0]  m_axis_rx_tdata,
    output logic        m_axis_rx_tvalid,
    input  logic        m_axis_rx_tready,
    output logic        m_axis_rx_tlast
);

    logic [7:0] rmii_mac_rx_data;
    logic       rmii_mac_rx_valid, rmii_mac_rx_active, rmii_mac_rx_err;
    
    logic [7:0] rmii_mac_tx_data;
    logic       rmii_mac_tx_valid, rmii_mac_tx_last, rmii_tx_mac_ready;

    logic [7:0] tx_mac_data;
    logic       tx_mac_start, tx_mac_last, tx_mac_rd_en, tx_mac_ready;

    logic [7:0] rx_mac_data;
    logic       rx_mac_valid, rx_mac_sof, rx_mac_eof, rx_mac_fcs_err;

    // ---------------------------------------------------------
    // RMII
    // ---------------------------------------------------------
    rmii_phy u_rmii (
        .clk_i           (clk_mac_ref_i),
        .rstn_i          (mac_rstn_i),
        // To Physical Pins
        .rxd_i           (rmii_rxd_i),
        .crs_dv          (rmii_crs_dv_i),
        .rxer_i          (rmii_rxer_i),
        .txd_o           (rmii_txd_o),
        .txen_o          (rmii_tx_en_o),
        // To MACs
        .tx_byte_i       (rmii_mac_tx_data),
        .tx_byte_valid_i (rmii_mac_tx_valid),
        .tx_last_byte_i  (rmii_mac_tx_last),
        .tx_ready_o      (rmii_tx_mac_ready),
        .rx_byte_o       (rmii_mac_rx_data),
        .rx_byte_valid_o (rmii_mac_rx_valid),
        .rx_active_o     (rmii_mac_rx_active),
        .byte_error_o    (rmii_mac_rx_err)
    );


    // ==========================================================
    // TX PIPELINE
    // ==========================================================
    
    axis_tx_packet_buffer #(ADDR_WIDTH) u_tx_buffer (
        .s_axis_clk      (s_axis_clk),
        .s_axis_aresetn  (s_axis_aresetn),
        .s_axis_tdata    (s_axis_tx_tdata),
        .s_axis_tvalid   (s_axis_tx_tvalid),
        .s_axis_tready   (s_axis_tx_tready),
        .s_axis_tlast    (s_axis_tx_tlast),
        
        .mac_clk_i         (clk_mac_ref_i),
        .mac_rstn_i      (mac_rstn_i),
        .tx_data_o       (tx_mac_data),
        .tx_start_o      (tx_mac_start),
        .tx_last_o       (tx_mac_last),
        .tx_rd_en_i      (tx_mac_rd_en),
        .tx_ready_i      (tx_mac_ready)
    );

    eth_tx_mac u_tx_mac (
        .clk_i           (clk_mac_ref_i),
        .rstn_i          (mac_rstn_i),
        .tx_data_i       (tx_mac_data),
        .tx_start_i      (tx_mac_start),
        .tx_last_i       (tx_mac_last),
        .tx_rd_en_o      (tx_mac_rd_en),
        .tx_ready_o      (tx_mac_ready),
        .phy_tx_ready_i      (rmii_tx_mac_ready),
        .phy_tx_data_o       (rmii_mac_tx_data),
        .phy_tx_valid_data_o (rmii_mac_tx_valid),
        .phy_tx_last_byte_o  (rmii_mac_tx_last)
    );

    // ======================================
    // RX PIPELINE
    // ==========================================================

    axis_rx_packet_buffer #(ADDR_WIDTH) u_rx_buffer (
        .mac_clk_i       (clk_mac_ref_i),
        .mac_rstn_i      (mac_rstn_i),
        .mac_din         (rx_mac_data),
        .mac_valid_i     (rx_mac_valid),
        .mac_start_i     (rx_mac_sof),
        .mac_end_i       (rx_mac_eof),
        .mac_crc_fail_i  (rx_mac_fcs_err),
        
        .m_axis_clk      (m_axis_clk),
        .m_axis_aresetn  (m_axis_aresetn),
        .m_axis_tdata    (m_axis_rx_tdata),
        .m_axis_tvalid   (m_axis_rx_tvalid),
        .m_axis_tready   (m_axis_rx_tready),
        .m_axis_tlast    (m_axis_rx_tlast)
    );

    eth_rx_mac u_rx_mac (
        .clk_i           (clk_mac_ref_i),
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

endmodule
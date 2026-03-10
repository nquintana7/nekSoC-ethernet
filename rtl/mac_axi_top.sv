module eth_mac_axi_top #(
    parameter ADDR_WIDTH = 12 // 4KB buffers
)(
    // --- Clock and Reset ---
    input  logic        clk_50M_i,
    input  logic        rstn_500M_i,
    // --- Physical RMII Pins (Nexys A7) ---
    output logic [1:0]  rmii_txd_o,
    output logic        rmii_tx_en_o,
    input  logic [1:0]  rmii_rxd_i,
    input  logic        rmii_crs_dv_i,
    input  logic        rmii_rxer_i,
    // --- AXI-Stream Slave (connected to TX) ---
    input  logic        s_axis_clk,
    input  logic        s_axis_resetn,
    input  logic [7:0]  s_axis_tdata,
    input  logic        s_axis_tvalid,
    output logic        s_axis_tready,
    input  logic        s_axis_tlast,
    // --- AXI-Stream Master (connected to RX) ---
    input  logic        m_axis_clk,
    input  logic        m_axis_resetn,
    output logic [7:0]  m_axis_tdata,
    output logic        m_axis_tvalid,
    input  logic        m_axis_tready,
    output logic        m_axis_tlast,
    output logic        m_axis_tuser
);

    logic [7:0] rmii_rx_data_s;
    logic       rmii_rx_valid_s, rmii_rx_active_s, rmii_rx_err_s;
    logic [7:0] rmii_cdc_tx_data_s;
    logic       rmii_cdc_tx_valid_s, rmii_cdc_tx_last_s, rmii_cdc_tx_ready_s;

    logic [7:0] mac_tx_data;
    logic       mac_tx_valid, mac_tx_last, fifo_tx_full;

    logic [7:0] mac_rx_data;
    logic       mac_rx_dv, mac_rx_active, mac_rx_err;

    // ---------------------------------------------------------
    // RMII
    // ---------------------------------------------------------
    rmii_phy u_rmii (
        .clk_i           (clk_50M_i),
        .rstn_i          (rstn_500M_i),
        // To Physical Pins
        .rxd_i           (rmii_rxd_i),
        .crs_dv          (rmii_crs_dv_i),
        .rxer_i          (rmii_rxer_i),
        .txd_o           (rmii_txd_o),
        .txen_o          (rmii_tx_en_o),
        // To MACs
        .tx_byte_i       (rmii_cdc_tx_data_s),
        .tx_byte_valid_i (rmii_cdc_tx_valid_s),
        .tx_last_byte_i  (rmii_cdc_tx_last_s),
        .tx_ready_o      (rmii_cdc_tx_ready_s),
        .rx_byte_o       (rmii_rx_data_s),
        .rx_byte_valid_o (rmii_rx_valid_s),
        .rx_active_o     (rmii_rx_active_s),
        .byte_error_o    (rmii_rx_err_s)
    );


    // ==========================================================
    // TX PIPELINE
    // ==========================================================
    
    tx_mac u_tx_mac (
        .s_axis_clk           (s_axis_clk),
        .s_axis_resetn          (s_axis_resetn),
        .data_valid_o       (mac_tx_valid),
        .data_o      (mac_tx_data),
        .data_last_o       (mac_tx_last),
        .fifo_full_i      (fifo_tx_full),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast)
    );

    rmii_cdc_tx_mac u_rmii_cdc_tx_bridge (
        .clk_i           (s_axis_clk),
        .rstn_i          (s_axis_resetn),
        
        .data_i          (mac_tx_data),
        .data_valid_i    (mac_tx_valid),
        .data_last_i     (mac_tx_last),
        .fifo_full_o     (fifo_tx_full),

        .clk_50m_i       (clk_50M_i),
        .rstn_50m_i      (rstn_500M_i),
        
        .phy_tx_byte_o   (rmii_cdc_tx_data_s),
        .phy_tx_valid_o  (rmii_cdc_tx_valid_s),
        .phy_tx_last_o   (rmii_cdc_tx_last_s),
        .phy_tx_ready_i  (rmii_cdc_tx_ready_s)
    );


    // ======================================
    // RX PIPELINE
    // ==========================================================

    rx_mac u_rx_mac (
        .m_axis_clk           (m_axis_clk),
        .m_axis_resetn          (m_axis_resetn),
        .phy_rx_active_i (mac_rx_active),
        .phy_rx_data_i   (mac_rx_data),
        .phy_rx_dv_i     (mac_rx_dv),
        .phy_rx_err_i    (mac_rx_err),
        .m_axis_tready(m_axis_tready),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tlast(m_axis_tlast),
        .m_axis_tuser(m_axis_tuser)
    );

    rmii_cdc_rx_mac u_cdc_rx (
        .clk_i           (s_axis_clk),
        .rstn_i           (m_axis_resetn),

        .phy_rx_data_i   (rmii_rx_data_s),
        .phy_rx_dv_i     (rmii_rx_valid_s),
        .phy_rx_active_i (rmii_rx_active_s),
        .phy_rx_err_i    (rmii_rx_err_s),

        .mac_data_o      (mac_rx_data),
        .mac_dv_o        (mac_rx_dv),
        .mac_active_o    (mac_rx_active),
        .mac_err_o       (mac_rx_err)
    );

endmodule


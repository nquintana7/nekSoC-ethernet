module eth_mac_axi_top #(
    parameter ADDR_WIDTH = 12 // 4KB buffers
)(
    // --- Clock and Reset ---
    input  logic        clk_i,
    input  logic        rstn_i,
    input  logic        clk_50M_i,
    input  logic        rstn_500M_i,
    //
    input  logic [47:0] local_mac_i,
    // --- Physical RMII Pins ---
    output logic [1:0]  rmii_txd_o,
    output logic        rmii_tx_en_o,
    input  logic [1:0]  rmii_rxd_i,
    input  logic        rmii_crs_dv_i,
    input  logic        rmii_rxer_i,

    // IP TX Stream
    input  logic [7:0]  s_ip_tx_axis_tdata,
    input  logic        s_ip_tx_axis_tvalid,
    input  logic        s_ip_tx_axis_tlast,
    input  logic [47:0] s_ip_tx_axis_tuser,
    output logic        s_ip_tx_axis_tready,
    
    // ARP TX Stream
    input  logic [7:0]  s_arp_tx_axis_tdata,
    input  logic        s_arp_tx_axis_tvalid,
    input  logic        s_arp_tx_axis_tlast,
    input  logic [47:0] s_arp_tx_axis_tuser,
    output logic        s_arp_tx_axis_tready,

    // IP RX Stream
    output logic [7:0]  m_ip_rx_axis_tdata,
    output logic        m_ip_rx_axis_tvalid,
    output logic        m_ip_rx_axis_tlast,
    output logic        m_ip_rx_axis_tuser,
    input  logic        m_ip_rx_axis_tready,
    
    // ARP RX Stream
    output logic [7:0]  m_arp_rx_axis_tdata,
    output logic        m_arp_rx_axis_tvalid,
    output logic        m_arp_rx_axis_tlast,
    output logic        m_arp_rx_axis_tuser,
    input  logic        m_arp_rx_axis_tready
);

    logic [7:0] rmii_rx_data_s;
    logic       rmii_rx_valid_s, rmii_rx_active_s, rmii_rx_err_s;
    logic [7:0] rmii_cdc_tx_data_s;
    logic       rmii_cdc_tx_valid_s, rmii_cdc_tx_last_s, rmii_cdc_tx_ready_s;

    logic [7:0] mac_tx_data;
    logic       mac_tx_valid, mac_tx_last, fifo_tx_full;

    logic [7:0] mac_rx_data;
    logic       mac_rx_dv, mac_rx_active, mac_rx_err;

    // Frame Builder Output (TX MAC Input)
    logic        tx_frame_axis_tready;
    logic [7:0]  tx_frame_axis_tdata;
    logic        tx_frame_axis_tvalid;
    logic        tx_frame_axis_tlast;

    // RX MAC Output (Frame Parser Input)
    logic        rx_frame_axis_tready;
    logic [7:0]  rx_frame_axis_tdata;
    logic        rx_frame_axis_tvalid;
    logic        rx_frame_axis_tlast;
    logic        rx_frame_axis_tuser; 

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

    rmii_cdc_tx_mac u_rmii_cdc_tx_bridge (
        .clk_i           (clk_i),
        .rstn_i          (rstn_i),
        
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
    
    eth_mac_tx u_tx_mac (
        .s_axis_clk           (clk_i),
        .s_axis_resetn          (rstn_i),
        .data_valid_o       (mac_tx_valid),
        .data_o      (mac_tx_data),
        .data_last_o       (mac_tx_last),
        .fifo_full_i      (fifo_tx_full),
        .s_axis_tdata   (tx_frame_axis_tdata),  
        .s_axis_tvalid  (tx_frame_axis_tvalid),
        .s_axis_tready  (tx_frame_axis_tready),
        .s_axis_tlast   (tx_frame_axis_tlast)
    );

    frame_builder u_frame_builder (
        .clk_i             (clk_i),
        .rstn_i            (rstn_i),
        .local_mac_i       (local_mac_i),

        // AXI-Stream In (From ARP)
        .s_arp_axis_tdata  (s_arp_tx_axis_tdata),
        .s_arp_axis_tvalid (s_arp_tx_axis_tvalid),
        .s_arp_axis_tlast  (s_arp_tx_axis_tlast),
        .s_arp_axis_tuser  (s_arp_tx_axis_tuser),
        .s_arp_axis_tready (s_arp_tx_axis_tready),

        // AXI-Stream In (From IP)
        .s_udp_axis_tdata  (s_ip_tx_axis_tdata),
        .s_udp_axis_tvalid (s_ip_tx_axis_tvalid),
        .s_udp_axis_tlast  (s_ip_tx_axis_tlast),
        .s_udp_axis_tuser  (s_ip_tx_axis_tuser),
        .s_udp_axis_tready (s_ip_tx_axis_tready),

        // AXI-Stream Out (To TX MAC)
        .m_axis_tready     (tx_frame_axis_tready),
        .m_axis_tdata      (tx_frame_axis_tdata),
        .m_axis_tvalid     (tx_frame_axis_tvalid),
        .m_axis_tlast      (tx_frame_axis_tlast)
    );

    // ======================================
    // RX PIPELINE
    // ==========================================================

    rmii_cdc_rx_mac u_cdc_rx (
        .clk_i           (clk_i),
        .rstn_i           (rstn_i),

        .phy_rx_data_i   (rmii_rx_data_s),
        .phy_rx_dv_i     (rmii_rx_valid_s),
        .phy_rx_active_i (rmii_rx_active_s),
        .phy_rx_err_i    (rmii_rx_err_s),

        .mac_data_o      (mac_rx_data),
        .mac_dv_o        (mac_rx_dv),
        .mac_active_o    (mac_rx_active),
        .mac_err_o       (mac_rx_err)
    );

    eth_mac_rx u_rx_mac (
        .m_axis_clk           (clk_i),
        .m_axis_resetn          (rstn_i),
        .phy_rx_active_i (mac_rx_active),
        .phy_rx_data_i   (mac_rx_data),
        .phy_rx_dv_i     (mac_rx_dv),
        .phy_rx_err_i    (mac_rx_err),
        .m_axis_tready(rx_frame_axis_tready),
        .m_axis_tdata(rx_frame_axis_tdata),
        .m_axis_tvalid(rx_frame_axis_tvalid),
        .m_axis_tlast(rx_frame_axis_tlast),
        .m_axis_tuser(rx_frame_axis_tuser)
    );

    frame_parser u_frame_parser (
        .clk_i            (clk_i),
        .rstn_i           (rstn_i),
        .local_mac_addr_i (local_mac_i),

        .s_axis_tdata     (rx_frame_axis_tdata),
        .s_axis_tvalid    (rx_frame_axis_tvalid),
        .s_axis_tlast     (rx_frame_axis_tlast),
        .s_axis_tuser     (rx_frame_axis_tuser),
        .s_axis_tready    (rx_frame_axis_tready),

        .m_ip_axis_tready (m_ip_rx_axis_tready),
        .m_ip_axis_tdata  (m_ip_rx_axis_tdata),
        .m_ip_axis_tvalid (m_ip_rx_axis_tvalid),
        .m_ip_axis_tlast  (m_ip_rx_axis_tlast),
        .m_ip_axis_tuser  (m_ip_rx_axis_tuser), 

        .m_arp_axis_tready(m_arp_rx_axis_tready),
        .m_arp_axis_tdata (m_arp_rx_axis_tdata),
        .m_arp_axis_tvalid(m_arp_rx_axis_tvalid),
        .m_arp_axis_tlast (m_arp_rx_axis_tlast),
        .m_arp_axis_tuser (m_arp_rx_axis_tuser)
    );

endmodule


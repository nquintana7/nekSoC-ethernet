`timescale 1ns / 1ps


module eth_stack_top (
    // --- System Clock and Reset ---
    input  logic        clk_i,
    input  logic        rstn_i,
    input  logic        clk_50M_i,    // RMII Clock
    input  logic        rstn_500M_i,  // RMII Reset

    // --- System Configuration ---
    input  logic [31:0] local_ip_i,
    input  logic [47:0] local_mac_i,

    // --- Physical RMII Pins ---
    output logic [1:0]  rmii_txd_o,
    output logic        rmii_tx_en_o,
    input  logic [1:0]  rmii_rxd_i,
    input  logic        rmii_crs_dv_i,
    input  logic        rmii_rxer_i,

    // App to UDP TX
    input  logic [7:0]  app_tx_tdata,
    input  logic        app_tx_tvalid,
    input  logic        app_tx_tlast,
    input  logic [79:0] app_tx_tuser, // [dest_ip, src_port, dest_port, length]
    output logic        app_tx_tready,
    output logic        pkt_drop_o,

    // UDP RX to App
    // Data is streaming only ! 
    // App layer must assert always rx tready or data will get corrupted
    input  logic        app_rx_tready,
    output logic [7:0]  app_rx_tdata,
    output logic        app_rx_tvalid, 
    output logic        app_rx_tlast,
    output logic [47:0] app_rx_tuser, // {Source IP, Source Port}

    // App/UDP Rx Port Checks
    input  logic        port_en_i,
    output logic [15:0] port_o
);

    // IP TX Stream (UDP/IP -> MAC)
    logic [7:0]  ip_tx_tdata;
    logic        ip_tx_tvalid;
    logic        ip_tx_tlast;
    logic [47:0] ip_tx_tuser;
    logic        ip_tx_tready;

    // ARP TX Stream (UDP/IP -> MAC)
    logic [7:0]  arp_tx_tdata;
    logic        arp_tx_tvalid;
    logic        arp_tx_tlast;
    logic [47:0]       arp_tx_tuser;
    logic        arp_tx_tready;

    // IP RX Stream (MAC -> UDP/IP)
    logic [7:0]  ip_rx_tdata;
    logic        ip_rx_tvalid;
    logic        ip_rx_tlast;
    logic        ip_rx_tuser;
    logic        ip_rx_tready;

    // ARP RX Stream (MAC -> UDP/IP)
    logic [7:0]  arp_rx_tdata;
    logic        arp_rx_tvalid;
    logic        arp_rx_tlast;
    logic        arp_rx_tuser;
    logic        arp_rx_tready;

    // Protocol Stack (UDP + IP + ARP)
    udp_ip_top u_udp_ip_top (
        .clk_i             (clk_i),
        .rstn_i            (rstn_i),

        .local_ip_i        (local_ip_i),
        .local_mac_i       (local_mac_i),

        // App TX
        .app_tx_tdata      (app_tx_tdata),
        .app_tx_tvalid     (app_tx_tvalid),
        .app_tx_tlast      (app_tx_tlast),
        .app_tx_tuser      (app_tx_tuser),
        .app_tx_tready     (app_tx_tready),
        .pkt_drop_o        (pkt_drop_o),

        // App RX
        .app_rx_tready     (app_rx_tready),
        .app_rx_tdata      (app_rx_tdata),
        .app_rx_tvalid     (app_rx_tvalid),
        .app_rx_tlast      (app_rx_tlast),
        .app_rx_tuser      (app_rx_tuser),

        // Port Checks
        .port_en_i         (port_en_i),
        .port_o            (port_o),

        // IP TX -> MAC
        .mac_ip_tx_tready  (ip_tx_tready),
        .mac_ip_tx_tdata   (ip_tx_tdata),
        .mac_ip_tx_tvalid  (ip_tx_tvalid),
        .mac_ip_tx_tlast   (ip_tx_tlast),
        .mac_ip_tx_tuser   (ip_tx_tuser),

        // ARP TX -> MAC
        .mac_arp_tx_tready (arp_tx_tready),
        .mac_arp_tx_tdata  (arp_tx_tdata),
        .mac_arp_tx_tvalid (arp_tx_tvalid),
        .mac_arp_tx_tlast  (arp_tx_tlast),
        .mac_arp_tx_tuser  (arp_tx_tuser),

        // MAC -> IP RX
        .mac_ip_rx_tdata   (ip_rx_tdata),
        .mac_ip_rx_tvalid  (ip_rx_tvalid),
        .mac_ip_rx_tlast   (ip_rx_tlast),
        .mac_ip_rx_tuser   (ip_rx_tuser),
        .mac_ip_rx_tready  (ip_rx_tready),

        // MAC -> ARP RX
        .mac_arp_rx_tdata  (arp_rx_tdata),
        .mac_arp_rx_tvalid (arp_rx_tvalid),
        .mac_arp_rx_tlast  (arp_rx_tlast),
        .mac_arp_rx_tuser  (arp_rx_tuser),
        .mac_arp_rx_tready (arp_rx_tready)
    );

    // MAC Layer (Ethernet + RMII PHY)
    eth_mac_axi_top u_eth_mac_axi_top (
        .clk_i                (clk_i),
        .rstn_i               (rstn_i),
        .clk_50M_i            (clk_50M_i),
        .rstn_500M_i          (rstn_500M_i),
        
        .local_mac_i          (local_mac_i),
        
        // RMII Pins
        .rmii_txd_o           (rmii_txd_o),
        .rmii_tx_en_o         (rmii_tx_en_o),
        .rmii_rxd_i           (rmii_rxd_i),
        .rmii_crs_dv_i        (rmii_crs_dv_i),
        .rmii_rxer_i          (rmii_rxer_i),

        // IP TX from UDP/IP
        .s_ip_tx_axis_tdata   (ip_tx_tdata),
        .s_ip_tx_axis_tvalid  (ip_tx_tvalid),
        .s_ip_tx_axis_tlast   (ip_tx_tlast),
        .s_ip_tx_axis_tuser   (ip_tx_tuser),
        .s_ip_tx_axis_tready  (ip_tx_tready),
        
        // ARP TX from UDP/IP
        .s_arp_tx_axis_tdata  (arp_tx_tdata),
        .s_arp_tx_axis_tvalid (arp_tx_tvalid),
        .s_arp_tx_axis_tlast  (arp_tx_tlast),
        .s_arp_tx_axis_tuser  (arp_tx_tuser), 
        .s_arp_tx_axis_tready (arp_tx_tready),

        // IP RX to UDP/IP
        .m_ip_rx_axis_tdata   (ip_rx_tdata),
        .m_ip_rx_axis_tvalid  (ip_rx_tvalid),
        .m_ip_rx_axis_tlast   (ip_rx_tlast),
        .m_ip_rx_axis_tuser   (ip_rx_tuser),
        .m_ip_rx_axis_tready  (ip_rx_tready),
        
        // ARP RX to UDP/IP
        .m_arp_rx_axis_tdata  (arp_rx_tdata),
        .m_arp_rx_axis_tvalid (arp_rx_tvalid),
        .m_arp_rx_axis_tlast  (arp_rx_tlast),
        .m_arp_rx_axis_tuser  (arp_rx_tuser),
        .m_arp_rx_axis_tready (arp_rx_tready)
    );

endmodule
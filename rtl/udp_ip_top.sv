`timescale 1ns / 1ps

module udp_ip_top (
    input  logic        clk_i,
    input  logic        rstn_i,

    // System Configuration
    input  logic [31:0] local_ip_i,
    input  logic [47:0] local_mac_i,

    // App to UDP TX
    input  logic [7:0]  app_tx_tdata,
    input  logic        app_tx_tvalid,
    input  logic        app_tx_tlast,
    input  logic [79:0] app_tx_tuser, // [dest_ip, src_port, dest_port, length]
    output logic        app_tx_tready,
    output logic        pkt_drop_o,

    // UDP RX to App
    input  logic        app_rx_tready,
    output logic [7:0]  app_rx_tdata,
    output logic        app_rx_tvalid,
    output logic        app_rx_tlast,
    output logic [47:0] app_rx_tuser, // {Source IP, Source Port}

    // App/UDP Rx Port Checks
    input  logic        port_en_i,
    output logic [15:0] port_o,

    // IP TX -> MAC Frame Builder
    input  logic        mac_ip_tx_tready,
    output logic [7:0]  mac_ip_tx_tdata,
    output logic        mac_ip_tx_tvalid,
    output logic        mac_ip_tx_tlast,
    output logic [47:0] mac_ip_tx_tuser,

    // ARP TX -> MAC Frame Builder (New Stream)
    input  logic        mac_arp_tx_tready,
    output logic [7:0]  mac_arp_tx_tdata,
    output logic        mac_arp_tx_tvalid,
    output logic        mac_arp_tx_tlast,
    output logic [47:0] mac_arp_tx_tuser,

    // MAC Frame Parser -> IP RX
    input  logic [7:0]  mac_ip_rx_tdata,
    input  logic        mac_ip_rx_tvalid,
    input  logic        mac_ip_rx_tlast,
    input  logic        mac_ip_rx_tuser,
    output logic        mac_ip_rx_tready,

    // MAC Frame Parser -> ARP Top
    input  logic [7:0]  mac_arp_rx_tdata,
    input  logic        mac_arp_rx_tvalid,
    input  logic        mac_arp_rx_tlast,
    input  logic        mac_arp_rx_tuser,
    output logic        mac_arp_rx_tready
);

    // UDP TX -> IP TX
    logic [7:0]  udp_ip_tx_tdata;
    logic        udp_ip_tx_tvalid;
    logic        udp_ip_tx_tlast;
    logic [47:0] udp_ip_tx_tuser;
    logic        udp_ip_tx_tready;
    logic        ip_udp_tx_packet_drop;

    // IP RX -> UDP RX
    logic [7:0]  ip_udp_rx_tdata;
    logic        ip_udp_rx_tvalid;
    logic        ip_udp_rx_tlast;
    logic [31:0] ip_udp_rx_tuser;
    logic        ip_udp_rx_tready;

    // IP TX <-> ARP Top 
    logic [31:0] ip_arp_rd_ip;
    logic [47:0] arp_ip_rd_mac;
    logic        arp_ip_rd_miss;
    logic        ip_tx_req_trigger;

    assign pkt_drop_o = ip_udp_tx_packet_drop;

    // UDP Transmit
    udp_tx udp_tx_inst (
        .clk_i         (clk_i),
        .rstn_i        (rstn_i),
        .s_axis_tdata  (app_tx_tdata),
        .s_axis_tvalid (app_tx_tvalid),
        .s_axis_tlast  (app_tx_tlast),
        .s_axis_tuser  (app_tx_tuser),
        .s_axis_tready (app_tx_tready),
        
        .packet_drop_i (ip_udp_tx_packet_drop),
        .m_axis_tready (udp_ip_tx_tready),
        .m_axis_tdata  (udp_ip_tx_tdata),
        .m_axis_tvalid (udp_ip_tx_tvalid),
        .m_axis_tlast  (udp_ip_tx_tlast),
        .m_axis_tuser  (udp_ip_tx_tuser)
    );

    // IP Transmit
    ip_tx ip_tx_inst (
        .clk_i             (clk_i),
        .rstn_i            (rstn_i),
        .local_ip_i        (local_ip_i),
        
        // ARP Interface
        .rd_ip_o           (ip_arp_rd_ip),
        .miss_i            (arp_ip_rd_miss),
        .rd_mac_i          (arp_ip_rd_mac),
        .trigger_request_o (ip_tx_req_trigger), // Triggers ARP Top
        
        // From UDP TX
        .s_axis_tdata      (udp_ip_tx_tdata),
        .s_axis_tvalid     (udp_ip_tx_tvalid),
        .s_axis_tlast      (udp_ip_tx_tlast),
        // Zero-padding the length. 
        .s_axis_tuser      (udp_ip_tx_tuser), 
        .s_axis_tready     (udp_ip_tx_tready),
        .packet_drop_o     (ip_udp_tx_packet_drop),
        
        // To MAC (Stream 1)
        .m_axis_tready     (mac_ip_tx_tready),
        .m_axis_tdata      (mac_ip_tx_tdata),
        .m_axis_tvalid     (mac_ip_tx_tvalid),
        .m_axis_tlast      (mac_ip_tx_tlast),
        .m_axis_tuser      (mac_ip_tx_tuser)
    );

    // IP Receive
    ip_rx ip_rx_inst (
        .clk_i         (clk_i),
        .rstn_i        (rstn_i),
        .local_ip_i    (local_ip_i),
        
        // From MAC Parser
        .s_axis_tdata  (mac_ip_rx_tdata),
        .s_axis_tvalid (mac_ip_rx_tvalid),
        .s_axis_tlast  (mac_ip_rx_tlast),
        .s_axis_tuser  (mac_ip_rx_tuser),
        .s_axis_tready (mac_ip_rx_tready),
        
        // To UDP RX
        .m_axis_tready (ip_udp_rx_tready),
        .m_axis_tdata  (ip_udp_rx_tdata),
        .m_axis_tvalid (ip_udp_rx_tvalid),
        .m_axis_tlast  (ip_udp_rx_tlast),
        .m_axis_tuser  (ip_udp_rx_tuser)
    );

    // UDP Receive
    udp_rx udp_rx_inst (
        .clk_i         (clk_i),
        .rstn_i        (rstn_i),
        
        .port_en_i     (port_en_i),
        .port_o        (port_o),
        
        // From IP RX
        .s_axis_tdata  (ip_udp_rx_tdata),
        .s_axis_tvalid (ip_udp_rx_tvalid),
        .s_axis_tlast  (ip_udp_rx_tlast),
        .s_axis_tuser  (ip_udp_rx_tuser),
        .s_axis_tready (ip_udp_rx_tready),
        
        // To App
        .m_axis_tready (app_rx_tready),
        .m_axis_tdata  (app_rx_tdata),
        .m_axis_tvalid (app_rx_tvalid),
        .m_axis_tlast  (app_rx_tlast),
        .m_axis_tuser  (app_rx_tuser)
    );

    // ARP Block
    arp_top arp_top_inst (
        .clk_i               (clk_i),
        .rstn_i              (rstn_i),
        .local_ip_i          (local_ip_i),
        .local_mac_i         (local_mac_i),
        
        // Cache read & triggers from IP TX
        .rd_ip_i             (ip_arp_rd_ip),
        .rd_mac_o            (arp_ip_rd_mac),
        .rd_miss_o           (arp_ip_rd_miss),
        .ip_tx_req_trigger_i (ip_tx_req_trigger),
        
        // From MAC Parser
        .s_rx_axis_tdata     (mac_arp_rx_tdata),
        .s_rx_axis_tvalid    (mac_arp_rx_tvalid),
        .s_rx_axis_tlast     (mac_arp_rx_tlast),
        .s_rx_axis_tuser     (mac_arp_rx_tuser),
        .s_rx_axis_tready    (mac_arp_rx_tready),
        
        // To MAC (Stream 2)
        .m_tx_axis_tdata     (mac_arp_tx_tdata),
        .m_tx_axis_tvalid    (mac_arp_tx_tvalid),
        .m_tx_axis_tlast     (mac_arp_tx_tlast),
        .m_tx_axis_tuser     (mac_arp_tx_tuser),
        .m_tx_axis_tready    (mac_arp_tx_tready)
    );

endmodule
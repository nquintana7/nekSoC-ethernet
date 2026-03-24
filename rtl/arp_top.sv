`timescale 1ns/1ps
module arp_top ( //Tx side missing
    input  logic        clk_i,
    input  logic        rstn_i,

    input logic [31:0] local_ip_i,
    input logic [47:0] local_mac_i,

    input  logic [31:0] rd_ip_i,
    output logic [47:0] rd_mac_o,
    output logic rd_miss_o,
    input  logic ip_tx_req_trigger_i,

    // AXI-Stream In (From Frame Parser)
    input  logic [7:0]  s_rx_axis_tdata,
    input  logic        s_rx_axis_tvalid,
    input  logic        s_rx_axis_tlast,
    input  logic        s_rx_axis_tuser,
    output logic        s_rx_axis_tready,

    // To Frame Builder
    output  logic [7:0]  m_tx_axis_tdata,
    output  logic        m_tx_axis_tvalid,
    output  logic        m_tx_axis_tlast,
    output  logic  [47:0]      m_tx_axis_tuser,
    input logic        m_tx_axis_tready
);
    logic [31:0] wr_ip_s;
    logic [47:0] wr_mac_s;
    logic wr_cache_s, trigger_reply_s;

    logic [47:0] tx_dest_mac;
    logic [31:0] tx_dest_ip;
    logic        tx_start;
    logic        tx_type;
    logic        arp_tx_busy_s;

    arp_cache u_arp_cache (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .wr_ip_i(wr_ip_s),
        .wr_mac_i(wr_mac_s),
        .store_pair_i(wr_cache_s),
        .rd_ip_i(rd_ip_i),
        .rd_mac_o(rd_mac_o),
        .miss_o(rd_miss_o)
    );

    arp_rx u_arp_rx (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .local_ip_i(local_ip_i),

        .s_axis_tdata(s_rx_axis_tdata),
        .s_axis_tvalid(s_rx_axis_tvalid),
        .s_axis_tlast(s_rx_axis_tlast),
        .s_axis_tuser(s_rx_axis_tuser), 
        .s_axis_tready(s_rx_axis_tready),

        .wr_mac_o(wr_mac_s),
        .wr_ip_o(wr_ip_s),
        .wr_cache_o(wr_cache_s),
        .trigger_reply_o(trigger_reply_s)
    );

    arp_tx u_arp_tx (
        .clk_i(clk_i),
        .rstn_i(rstn_i),

        .local_mac_i(local_mac_i),
        .local_ip_i(local_ip_i),
    
        .dest_mac_i(tx_dest_mac),
        .dest_ip_i(tx_dest_ip),
        .start_i(tx_start),
        .type_i(tx_type),
        .busy_o(arp_tx_busy_s),
    
        .m_axis_tready(m_tx_axis_tready), 
        .m_axis_tdata(m_tx_axis_tdata),
        .m_axis_tvalid(m_tx_axis_tvalid),
        .m_axis_tlast(m_tx_axis_tlast),
        .m_axis_tuser(m_tx_axis_tuser)

    );

    // ==========================================
    // ARP TX Arbiter FSM
    // ==========================================
    always_comb begin
        tx_start    = 1'b0;
        tx_type     = 1'b0;
        tx_dest_mac = 48'h0;
        tx_dest_ip  = 32'h0;

        if (!arp_tx_busy_s) begin
            if (trigger_reply_s) begin
                tx_start    = 1'b1;
                tx_type     = 1'b1;
                tx_dest_mac = wr_mac_s;
                tx_dest_ip  = wr_ip_s;
            end 
            else if (ip_tx_req_trigger_i) begin
                tx_start    = 1'b1;
                tx_type     = 1'b0;
                tx_dest_mac = 48'hFFFFFFFFFFFF;
                tx_dest_ip  = rd_ip_i;
            end
        end
    end


endmodule
`timescale 1ns/1ps
module arp_top ( //Tx side missing
    input  logic        clk_i,
    input  logic        rstn_i,

    input logic [31:0] local_ip_i,

    input  logic [31:0] rd_ip_i,
    output logic [47:0] rd_mac_o,
    output logic rd_miss_o,

    // AXI-Stream In (From Frame Parser)
    input  logic [7:0]  s_axis_tdata,
    input  logic        s_axis_tvalid,
    input  logic        s_axis_tlast,
    input  logic        s_axis_tuser,
    output logic        s_axis_tready,

    output logic        trigger_reply_o
);
    logic [31:0] wr_ip_s;
    logic [47:0] wr_mac_s;
    logic wr_cache_s;

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

        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tuser(s_axis_tuser), 
        .s_axis_tready(s_axis_tready),

        .wr_mac_o(wr_mac_s),
        .wr_ip_o(wr_ip_s),
        .wr_cache_o(wr_cache_s),
        .trigger_reply_o(trigger_reply_o)
);

endmodule
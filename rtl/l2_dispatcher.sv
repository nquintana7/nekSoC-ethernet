import eth_pkg::*;

module l2_rx_dispatcher (
    
    input  logic        s_axis_clk,
    input  logic        s_axis_resetn,

    input  logic [47:0] local_mac_addr_i,

    input  logic [7:0]  s_axis_tdata,
    input  logic        s_axis_tvalid,
    input  logic        s_axis_tlast,
    input  logic        s_axis_tuser,
    output logic        s_axis_tready
);

enum logic [1:0] {IDLE, PREAMBLE, FILTER, RECEIVE} rx_state;

    
endmodule
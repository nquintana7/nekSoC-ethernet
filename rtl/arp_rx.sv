`timescale 1ns/1ps
module arp_rx (
    input  logic        clk_i,
    input  logic        rstn_i,

    input logic [31:0] local_ip_i,

    // AXI-Stream In (From Frame Parser)
    input  logic [7:0]  s_axis_tdata,
    input  logic        s_axis_tvalid,
    input  logic        s_axis_tlast,
    input  logic        s_axis_tuser,   // 1 = Bad CRC
    output logic        s_axis_tready,

    // Outputs straight to Cache and ARP TX
    output logic [47:0] wr_mac_o,
    output logic [31:0] wr_ip_o,
    output logic        wr_cache_o,
    output logic        trigger_reply_o
);

    assign s_axis_tready = 1'b1;

    logic [5:0]  byte_cnt;
    logic [15:0] opcode_reg;
    logic [31:0] target_ip_reg;

    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            byte_cnt      <= '0;
            wr_mac_o      <= '0;
            wr_ip_o       <= '0;
            opcode_reg    <= '0;
            target_ip_reg <= '0;
            wr_cache_o    <= 1'b0;
            trigger_reply_o <= 1'b0;
        end else begin
            wr_cache_o    <= 1'b0;
            trigger_reply_o <= 1'b0;

            if (s_axis_tvalid) begin
                if (byte_cnt == 6 || byte_cnt == 7) begin
                    opcode_reg <= {opcode_reg[7:0], s_axis_tdata};
                end
                else if (byte_cnt >= 8 && byte_cnt <= 13) begin
                    wr_mac_o <= {wr_mac_o[39:0], s_axis_tdata};
                end
                else if (byte_cnt >= 14 && byte_cnt <= 17) begin
                    wr_ip_o <= {wr_ip_o[23:0], s_axis_tdata};
                end
                else if (byte_cnt >= 24 && byte_cnt <= 27) begin
                    target_ip_reg <= {target_ip_reg[23:0], s_axis_tdata};
                end

                byte_cnt <= byte_cnt + 1'b1;

                if (s_axis_tlast) begin
                    byte_cnt <= '0;
                    
                    // Only process if the packet passed the CRC check
                    if (!s_axis_tuser) begin
                        
                        wr_cache_o <= 1'b1;

                        if (opcode_reg == 16'h0001 && target_ip_reg == local_ip_i) begin
                            trigger_reply_o <= 1'b1;
                        end
                    
                    end
                end
            end
        end
    end

endmodule
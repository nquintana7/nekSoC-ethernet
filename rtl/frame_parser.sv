`timescale 1ns/1ps
import eth_pkg::*;

module frame_parser (
    input  logic        clk_i,
    input  logic        rstn_i,

    input  logic [47:0] local_mac_addr_i,

    input  logic [7:0]  s_axis_tdata,
    input  logic        s_axis_tvalid,
    input  logic        s_axis_tlast,
    input  logic        s_axis_tuser,
    output logic        s_axis_tready,

    input  logic        m_axis_tready,
    output logic [7:0]  m_axis_tdata,
    output logic        m_axis_tvalid,
    output logic        m_axis_tlast,
    output logic [48:0] m_axis_tuser, // {src_mac, error}
    output logic        m_axis_tdest
);

    enum logic [1:0] {HEADER, DATA, IGNORE} state;

    logic [3:0]  hdr_cnt;
    logic [47:0] dest_mac;
    logic [47:0] src_mac;
    logic [7:0]  ethtype;

    assign m_axis_tvalid = (state == DATA) ? s_axis_tvalid : 1'b0;
    assign m_axis_tdata  = s_axis_tdata;
    assign m_axis_tlast  = s_axis_tlast;
    assign m_axis_tuser  = {src_mac, s_axis_tuser}; 
    assign s_axis_tready = (state == HEADER || state == IGNORE) ? 1'b1 : m_axis_tready;

    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            state        <= HEADER;
            hdr_cnt      <= '0;
            m_axis_tdest <= 1'b0;
            dest_mac     <= '0;
            src_mac      <= '0;
            ethtype<= '0;
        end else begin
            
            if (s_axis_tvalid && s_axis_tready) begin
                
                if (s_axis_tlast) begin
                    state   <= HEADER;
                    hdr_cnt <= '0;
                end else begin
                    case (state)
                        HEADER: begin
                            // Shift bytes into the correct registers based on the counter
                            if (hdr_cnt < 6)
                                dest_mac <= {dest_mac[39:0], s_axis_tdata};
                            else if (hdr_cnt < 12)
                                src_mac  <= {src_mac[39:0], s_axis_tdata};
                            else if (hdr_cnt == 12)
                                ethtype <= s_axis_tdata;

                            hdr_cnt <= hdr_cnt + 1'b1;

                            if (hdr_cnt == 13) begin

                                // Address filter and check if IPv4 or ARP
                                if (dest_mac == local_mac_addr_i || dest_mac == 48'hFF_FF_FF_FF_FF_FF) begin

                                    if ({ethtype, s_axis_tdata} == 16'h0800) begin
                                        m_axis_tdest <= 1'b0; // To UDP RX
                                        state        <= DATA;
                                    end 
                                    else if ({ethtype, s_axis_tdata} == 16'h0806) begin
                                        m_axis_tdest <= 1'b1; // To ARP RX
                                        state        <= DATA;
                                    end 
                                    else begin
                                        state <= IGNORE;
                                    end
                                end else begin
                                    state <= IGNORE;
                                end

                            end
                        end

                        DATA: begin
                        end

                        IGNORE: begin
                        end

                        default : state <= HEADER;

                    endcase
                end
            end
        end
    end

endmodule
module arp_tx (
    input  logic        clk_i,
    input  logic        rstn_i,

    input logic [47:0] local_mac_i,
    input logic [31:0] local_ip_i,
    
    input logic [47:0] dest_mac_i,
    input logic [31:0] dest_ip_i,
    input logic start_i,
    input logic type_i, // 0 -> request, 1 -> reply
    output logic busy_o,
    
    // Output to Frame Builder
    input   logic        m_axis_tready, 
    output  logic [7:0]  m_axis_tdata,
    output  logic        m_axis_tvalid,
    output  logic        m_axis_tlast,
    output  logic [47:0] m_axis_tuser
);  

    logic [5:0] byte_cnt;
    logic sending;

    typedef struct packed {
        logic [15:0] htype;
        logic [15:0] ptype;
        logic [7:0]  hlen;
        logic [7:0]  plen;
        logic [15:0] opcode;
        logic [47:0] sha;
        logic [31:0] spa;
        logic [47:0] tha;
        logic [31:0] tpa;
    } arp_packet_t;

    arp_packet_t shift_packet;

    assign m_axis_tdata = shift_packet[223:216];
    assign m_axis_tlast = sending && byte_cnt == 45 && m_axis_tvalid;
    assign m_axis_tvalid = sending;

    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            byte_cnt      <= '0;
            shift_packet <= '0;
            sending <= 1'b0;
            busy_o <= 1'b0;
        end else begin


            if (!sending) begin
                byte_cnt <= 'd0;
                busy_o <= 1'b0;
                if (start_i) begin
                    busy_o <= 1'b1;
                    shift_packet.htype <= 16'b1;
                    shift_packet.ptype <= 16'h800;
                    shift_packet.hlen <= 8'd6;
                    shift_packet.plen <= 8'd4; // only IPv4
                    shift_packet.opcode <= type_i ? 16'd2 : 16'd1;
                    shift_packet.sha <= local_mac_i;
                    shift_packet.spa <= local_ip_i;
                    shift_packet.tha <= type_i ?  dest_mac_i : 48'd0;
                    m_axis_tuser <= type_i ?  dest_mac_i : 48'hFF_FF_FF_FF_FF_FF;
                    shift_packet.tpa <= dest_ip_i;
                    sending <= 1'b1;
                end
            end else begin
                
                if (m_axis_tready) begin
                    
                    if (byte_cnt == 45) begin
                        sending <= 1'b0;
                    end

                    shift_packet <= {shift_packet[215:0],8'd0};
                    byte_cnt <= byte_cnt + 1;

                end

            end
         
        end
    end


endmodule
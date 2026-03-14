module frame_builder (
    input logic clk_i,
    input logic rstn_i,

    input logic [47:0] local_mac_i,

    input  logic [7:0]  s_arp_axis_tdata,
    input  logic        s_arp_axis_tvalid,
    input  logic        s_arp_axis_tlast,
    input  logic [47:0] s_arp_axis_tuser,
    output logic        s_arp_axis_tready,

    input  logic [7:0]  s_udp_axis_tdata,
    input  logic        s_udp_axis_tvalid,
    input  logic        s_udp_axis_tlast,
    input  logic [47:0] s_udp_axis_tuser,
    output logic        s_udp_axis_tready,

    // TO TX MAC
    input   logic        m_axis_tready,
    output  logic [7:0]  m_axis_tdata,
    output  logic        m_axis_tvalid, 
    output  logic        m_axis_tlast
);

    typedef struct packed {
        logic [47:0] dmac;
        logic [47:0] smac;
        logic [15:0] ethtype;
    } eth_header_t;

    eth_header_t header_shift;
    logic [3:0] byte_cnt;
    logic pkt_type; // 0-> ARP , 1-> UDP

    enum logic [1:0] {IDLE, HEADER, DATA} state;

    always_comb begin
        
        if (state == HEADER) begin
            m_axis_tvalid = 1'b1;
            s_udp_axis_tready = 1'b0;
            s_arp_axis_tready = 1'b0;
            m_axis_tlast = 1'b0;
            m_axis_tdata = header_shift[111:104];
        end else if (state == DATA) begin
            if (pkt_type) begin
                m_axis_tvalid = s_udp_axis_tvalid;
                s_udp_axis_tready = m_axis_tready;
                m_axis_tdata = s_udp_axis_tdata;
                s_arp_axis_tready = 1'b0;
                m_axis_tlast = s_udp_axis_tlast;
            end else begin
                m_axis_tvalid = s_arp_axis_tvalid;
                m_axis_tdata = s_arp_axis_tdata;
                s_arp_axis_tready = m_axis_tready;
                s_udp_axis_tready = 1'b0;
                m_axis_tlast = s_arp_axis_tlast;
            end
        end else begin
            m_axis_tvalid = 1'b0;
            s_udp_axis_tready = 1'b0;
            s_arp_axis_tready = 1'b0;
            m_axis_tlast = 1'b0;
        end

    end

    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            byte_cnt <= 'd0;
            sending <= 1'b0;
            pkt_type <= 1'b0;
            state <= IDLE;
            header_shift <= 'd0;
        end else begin

            case (state)

                IDLE : begin
                    byte_cnt <= 'd0;
                    
                    if (s_arp_axis_tvalid | s_udp_axis_tvalid) begin
                        pkt_type <= (s_arp_axis_tvalid) ? 1'b0 : 1'b1;
                        header_shift.dmac <= (arp_axis_tvalid) ? s_arp_axis_tuser : s_udp_axis_tuser;
                        header_shift.smac <= local_mac_i;
                        header_shift.ethtype <= (s_arp_axis_tvalid) ? 16'h806 : 16'h800;
                        state <= HEADER;
                    end

                end

                HEADER : begin
                    
                    if (m_axis_tready) begin
                        
                        header_shift <= {header_shift[103:0], 8'd0};
                        byte_cnt <= byte_cnt + 1;

                        if (byte_cnt == 13) begin
                            state <= DATA;
                        end

                    end

                end

                DATA : begin
                    state <= (m_axis_tready & m_axis_tready & m_axis_tlast) ? IDLE : state; 
                end

                default : state <= IDLE;

            endcase
         
        end
    end
endmodule
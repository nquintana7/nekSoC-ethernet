module udp_tx (
    input  logic        clk_i,
    input  logic        rstn_i,    

    input  logic [7:0]  s_axis_tdata,
    input  logic        s_axis_tvalid,
    input  logic        s_axis_tlast,
    input  logic [79:0] s_axis_tuser, // [dest_ip, src_port, dest_port, length]
    output logic        s_axis_tready,
    
    // Output to IP TX
    input   logic packet_drop_i,
    input   logic        m_axis_tready, 
    output  logic [7:0]  m_axis_tdata,
    output  logic        m_axis_tvalid,
    output  logic        m_axis_tlast,
    output  logic [47:0] m_axis_tuser // dest ip
);

typedef struct packed {
    logic [15:0] src_port;
    logic [15:0] dst_port;
    logic [15:0] length;
    logic [15:0] checksum;
} udp_header_t; // later in eth_pkg

enum logic [2:0] {IDLE, HEADER, DATA, DROP} state;
udp_header_t header_shift;
logic [2:0] byte_cnt;
assign s_axis_tready = (state == DATA) && m_axis_tready;
assign m_axis_tvalid = (state == HEADER) || ( (state == DATA) & s_axis_tvalid );
assign m_axis_tlast  = (state == DATA) && s_axis_tlast;
assign m_axis_tdata  = (state == DATA) ? s_axis_tdata : header_shift[63:56];
always_ff @(posedge clk_i or negedge rstn_i) begin
    if (!rstn_i) begin
        byte_cnt <= 'd0;
        state <= IDLE;
        header_shift <= 'd0;
        m_axis_tuser <= 'd0;
    end else begin
        header_shift.checksum <= 'd0;

        case (state)

            IDLE : begin
                byte_cnt <= 3'd0;
                if (s_axis_tvalid) begin
                    header_shift.src_port <= s_axis_tuser[47:32];
                    header_shift.dst_port <= s_axis_tuser[31:16];
                    header_shift.length   <= 8'd8 + s_axis_tuser[15:0];
                    header_shift.checksum <= 16'h0000;
                    m_axis_tuser <= {s_axis_tuser[79:48], 8'd8 + s_axis_tuser[15:0]};
                    state <= HEADER;
                end

            end

            HEADER : begin
                if (m_axis_tready) begin
                    header_shift <= {header_shift[55:0], 8'h00};
                    byte_cnt     <= byte_cnt + 1;
                    if (byte_cnt == 3'd7) begin
                        state <= DATA;
                    end
                end
            end

            DATA : begin
                state <= (m_axis_tready & m_axis_tvalid & m_axis_tlast) ? IDLE : state; 
            end
            
            DROP : begin // assumes upper layer also gets drop signal
                state <= IDLE;   
            end

            default : state <= IDLE;

        endcase

        if (packet_drop_i) begin
            state <= DROP;
        end
        
    end
end

endmodule
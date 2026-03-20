module ip_tx (
    input  logic        clk_i,
    input  logic        rstn_i,

    input logic [31:0] local_ip_i,
    
    // Connection to ARP CACHE
    output logic [31:0] rd_ip_o,
    input  logic miss_i,
    input logic [47:0] rd_mac_i,
    output logic trigger_request_o,

    // From UDP TX
    input  logic [7:0]  s_axis_tdata,
    input  logic        s_axis_tvalid,
    input  logic        s_axis_tlast,
    input  logic [47:0] s_axis_tuser, // [dest ip, length]
    output logic        s_axis_tready,
    output logic        packet_drop_o,
    
    // Output to Frame Builder
    input   logic        m_axis_tready, 
    output  logic [7:0]  m_axis_tdata,
    output  logic        m_axis_tvalid,
    output  logic        m_axis_tlast,
    output  logic [47:0] m_axis_tuser // dest mac
);  

typedef struct packed {
    logic [3:0]  version;      // Version (4 for IPv4)
    logic [3:0]  ihl;          // Internet Header Length (5 if no options)
    logic [7:0]  tos;          // Type of Service / DSCP
    logic [15:0] total_length; // Total length (Header + Payload)
    logic [15:0] id;            // Identification
    logic [2:0]  flags;         // Flags (Don't Fragment, etc.)
    logic [12:0] frag_offset;   // Fragment Offset
    logic [7:0]  ttl;           // Time to Live
    logic [7:0]  protocol;      // Protocol (UDP = 17, TCP = 6)
    logic [15:0] checksum;      // Header Checksum
    logic [31:0] src_ip;        // Source IP Address
    logic [31:0] dst_ip;        // Destination IP Address
} ipv4_header_t;

enum logic [2:0] {IDLE, CHECKSUM, CHECK_IP, HEADER, DATA, DROP} state;

logic [4:0] byte_cnt;
ipv4_header_t header_shift_reg, dest_ip_reg;
logic [15:0] checksum_ff;
logic [10:0] timeout_cnt;
logic [19:0] sum_reg;
assign rd_ip_o = dest_ip_reg;

always_ff @(posedge clk_i or negedge rstn_i) begin
    if (!rstn_i) begin
        byte_cnt <= 'd0;
        state <= IDLE;
        timeout_cnt <= '0;
        m_axis_tuser <= 'd0;
        header_shift_reg <= '0;
        dest_ip_reg <= '0;
        packet_drop_o <= 1'b0;
        m_axis_tvalid <= 1'b0;
    end else begin
        packet_drop_o <= 1'b0;
        case (state)

            IDLE : begin
                byte_cnt <= 5'd0;
                m_axis_tvalid <= 1'b0;
                if (s_axis_tvalid) begin
                    header_shift_reg.version      <= 4'h4;
                    header_shift_reg.ihl          <= 4'h5;
                    header_shift_reg.tos          <= 8'h00;
                    header_shift_reg.total_length <= 16'd20 + s_axis_tuser[15:0];
                    header_shift_reg.id           <= 16'h0000;
                    header_shift_reg.flags        <= 3'b010;
                    header_shift_reg.frag_offset  <= 13'h0000;
                    header_shift_reg.ttl          <= 8'h40;
                    header_shift_reg.protocol     <= 8'd17;
                    header_shift_reg.checksum     <= 16'h0000;
                    header_shift_reg.src_ip       <= local_ip_i;
                    header_shift_reg.dst_ip       <= s_axis_tuser[47:16];
                    dest_ip_reg <= s_axis_tuser[47:16];
                    state <= CHECKSUM;
                end

            end

            CHECKSUM : begin

                state <= CHECK_IP; 
            end

            CHECK_IP : begin
                
                if (miss_i) begin
                    packet_drop_o <= 1'b1;
                    trigger_request_o <= 1'b1;
                    state <= DROP;
                end else begin
                    state <= HEADER;
                    m_axis_tvalid <= 1'b1;
                end

            end

            HEADER : begin
                if (m_axis_tready) begin
                    header_shift_reg <= {header_shift_reg[151:0], 8'h00};
                    byte_cnt     <= byte_cnt + 1;
                    m_axis_tdata  <= header_shift_reg[159:152];
                    m_axis_tvalid <= 1'b1;
                    if (byte_cnt == 5'd19) begin
                        state <= DATA;
                    end
                end
            end

            DATA : begin
                s_axis_tready <= m_axis_tready;
                m_axis_tvalid <= s_axis_tvalid;
                m_axis_tdata  <= s_axis_tdata;
                m_axis_tlast  <= s_axis_tlast;
                state <= (m_axis_tready & m_axis_tvalid & m_axis_tlast) ? IDLE : state; 
            end

            DROP :begin
                state <= IDLE;
            end 

            default : state <= IDLE;

        endcase
        
    end
end

endmodule
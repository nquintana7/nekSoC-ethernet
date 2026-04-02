module udp_rx (
    input  logic        clk_i,
    input  logic        rstn_i,

    // Check Ports
    input  logic port_en_i,
    output logic [15:0] port_o,

    // From IP Rx
    input  logic [7:0]  s_axis_tdata,
    input  logic        s_axis_tvalid,
    input  logic        s_axis_tlast,
    input  logic [31:0] s_axis_tuser,
    output logic        s_axis_tready,
    
    // Output to App Demux
    input   logic        m_axis_tready, 
    output  logic [7:0]  m_axis_tdata,
    output  logic        m_axis_tvalid,
    output  logic        m_axis_tlast,
    output  logic [47:0] m_axis_tuser // {Source IP, Source Port}
);  
    typedef enum logic [1:0] {HEADER, DATA, IGNORE} state_e;
    state_e state;

    logic [2:0]  byte_cnt;
    logic [7:0]  last_byte;

    logic [15:0] src_port;
    logic [31:0] src_ip;

    always_comb begin
        if (state == DATA) begin
            s_axis_tready = m_axis_tready;
            m_axis_tdata  = s_axis_tdata;
            m_axis_tlast  = s_axis_tlast;
            m_axis_tvalid = s_axis_tvalid;
        end else begin
            s_axis_tready = 1'b1;
            m_axis_tdata  = 8'h00;
            m_axis_tvalid = 1'b0;
            m_axis_tlast  = 1'b0;
        end
    end

    logic [31:0] err_cnt;

    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            byte_cnt     <= '0;
            state        <= HEADER;
            m_axis_tuser <= '0;
            last_byte    <= '0;
            src_port     <= '0;
            src_ip <= '0;
            port_o <= '0;
            err_cnt <= '0;
        end else begin

            if (s_axis_tvalid && s_axis_tready && s_axis_tlast) begin
                state     <= HEADER;
                last_byte <= '0;
                byte_cnt  <= '0;
            
            end else if (s_axis_tvalid && s_axis_tready) begin

                case (state)

                    HEADER : begin
                        last_byte <= s_axis_tdata;
                        byte_cnt  <= byte_cnt + 1'b1;

                        // Source IP
                        if (byte_cnt == 3'd0) begin
                            src_ip <= s_axis_tuser;
                        end
                        
                        if (byte_cnt == 3'd1) begin
                            src_port <= {last_byte, s_axis_tdata};
                        end 

                        // Check Destination Port Enabled
                        if (byte_cnt == 3'd3) begin
                            port_o <= {last_byte, s_axis_tdata};
                        end

                        if (byte_cnt == 3'd4 && !port_en_i) begin
                            err_cnt <= err_cnt + 1'b1;
                            state <= IGNORE;   
                        end

                        if (byte_cnt == 3'd7) begin
                            m_axis_tuser <= {src_ip, src_port};
                            state        <= DATA;
                        end
                    end

                    DATA : begin
                    end

                    IGNORE : begin
                    end

                    default : state <= HEADER;

                endcase
            end
        end
    end

endmodule
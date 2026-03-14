module ip_rx (
    input  logic        clk_i,
    input  logic        rstn_i,

    input  logic [31:0] local_ip_i,

    // From Frame Parser
    input  logic [7:0]  s_axis_tdata,
    input  logic        s_axis_tvalid,
    input  logic        s_axis_tlast,
    input  logic        s_axis_tuser,
    output logic        s_axis_tready,
    
    // Output to UDP
    input   logic        m_axis_tready, 
    output  logic [7:0]  m_axis_tdata,
    output  logic        m_axis_tvalid,
    output  logic        m_axis_tlast,
    output  logic [31:0] m_axis_tuser
);  
    typedef enum logic [1:0] {HEADER, DATA, IGNORE} state_e;
    state_e state;

    logic [4:0] byte_cnt;
    logic [31:0] last_bytes;

    always_comb begin
        if (state == DATA) begin
            s_axis_tready = m_axis_tready;
            m_axis_tdata = s_axis_tdata;
            m_axis_tlast = s_axis_tlast;
            m_axis_tvalid = s_axis_tvalid;
        end else begin
            s_axis_tready = 1'b1;
            m_axis_tdata = 1'b0;
            m_axis_tvalid = 1'b0;
            m_axis_tlast = 1'b0;
        end
    end

    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            byte_cnt <= '0;
            state <= HEADER;
            m_axis_tuser <= '0;
            last_bytes <= '0;
        end else begin

            if (s_axis_tvalid && s_axis_tready && s_axis_tlast) begin
                state <= HEADER;
                last_bytes <= '0;
                byte_cnt <= '0;
            end else if (s_axis_tvalid && s_axis_tready) begin
                case (state)

                    HEADER : begin

                            last_bytes <= {last_bytes[23:0], s_axis_tdata};
                            
                            byte_cnt <= byte_cnt+1;

                            if ((byte_cnt == 'd9 && s_axis_tdata != 8'h11)) begin
                                state <= IGNORE;
                            end
                            
                            // Source IP
                            if (byte_cnt == 'd15) begin
                                m_axis_tuser <= {last_bytes[23:0], s_axis_tdata};
                            end 

                            if (byte_cnt == 'd19) begin
                                if (local_ip_i == {last_bytes[23:0], s_axis_tdata} || {last_bytes[23:0], s_axis_tdata} == 32'hFFFFFFFF) begin
                                    state <= DATA;
                                end else begin
                                    state <= IGNORE;
                                end
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
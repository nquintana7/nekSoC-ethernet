import eth_pkg::*;

module eth_mac_rx (
    input logic         m_axis_clk,
    input logic         m_axis_resetn,

    input logic phy_rx_active_i,
    input logic [7:0] phy_rx_data_i,
    input logic phy_rx_dv_i,
    input logic phy_rx_err_i,

    input  logic m_axis_tready,
    output logic [7:0]  m_axis_tdata,
    output logic        m_axis_tvalid,
    output logic        m_axis_tlast,
    output logic        m_axis_tuser
);

    enum logic [1:0] {IDLE, PREAMBLE, RECEIVE} rx_state;
    logic [31:0] crc_reg, crc_next;
    logic [7:0] data_shift_reg [0:4];
    logic [3:0] data_shift_cnt;
    
    lfsr_eth_crc32 u_eth_crc32 (
        .data_in(phy_rx_data_i),
        .state_in(crc_reg),
        .state_out(crc_next)
    );

    logic [31:0] err_cnt;
    logic [31:0] correct_cnt;

    // Error Counters
    always_ff @(posedge m_axis_clk) begin
        if (!m_axis_resetn) begin
            err_cnt <= '0;
            correct_cnt <= '0;
        end else begin
            if (m_axis_tlast && m_axis_tvalid && m_axis_tready) begin
                if (m_axis_tuser) err_cnt <= err_cnt + 1'b1;
                else              correct_cnt <= correct_cnt + 1'b1;
            end
        end
    end

    // Main MAC State Machine
    always_ff @(posedge m_axis_clk or negedge m_axis_resetn) begin
        if (!m_axis_resetn) begin
            rx_state <= IDLE;
            data_shift_cnt <= '0;
            crc_reg <= 32'hFFFFFFFF;
            m_axis_tuser <= 1'b0;
            m_axis_tdata <= '0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast <= 1'b0;
        end else begin
            
            case (rx_state)
                IDLE: begin
                    m_axis_tvalid <= 1'b0;
                    m_axis_tlast  <= 1'b0;
                    m_axis_tuser  <= 1'b0;
                    crc_reg       <= 32'hFFFFFFFF;

                    if (phy_rx_active_i & !phy_rx_err_i) begin
                        rx_state <= PREAMBLE;    
                    end
                end

                PREAMBLE: begin
                    m_axis_tvalid <= 1'b0; 
                    
                    if (!phy_rx_active_i) begin
                        rx_state <= IDLE;
                        data_shift_cnt <= '0;
                    end else if (phy_rx_dv_i) begin 
                        if (phy_rx_data_i == 8'hD5) begin
                            rx_state <= RECEIVE;
                        end
                    end
                end 

                RECEIVE: begin
                    if (!phy_rx_active_i) begin
                        if (data_shift_cnt > 'd4) begin
                            m_axis_tdata  <= data_shift_reg[0];
                            m_axis_tvalid <= 1'b1;
                            m_axis_tlast  <= 1'b1; 
                            m_axis_tuser  <= (crc_reg != 32'hDEBB20E3) | phy_rx_err_i;
                        end else begin
                            m_axis_tvalid <= 1'b0;
                            m_axis_tlast  <= 1'b0;
                            m_axis_tuser  <= 1'b0;
                        end
                        rx_state <= IDLE;
                        data_shift_cnt <= '0;
                    end else begin
                        m_axis_tlast <= 1'b0;
                        m_axis_tuser <= 1'b0;
                        
                        if (phy_rx_dv_i) begin
                            crc_reg <= crc_next; 
                            
                            data_shift_reg[4] <= phy_rx_data_i;
                            data_shift_reg[3] <= data_shift_reg[4];
                            data_shift_reg[2] <= data_shift_reg[3];
                            data_shift_reg[1] <= data_shift_reg[2];
                            data_shift_reg[0] <= data_shift_reg[1];

                            if (data_shift_cnt > 'd4) begin
                                m_axis_tdata  <= data_shift_reg[0];
                                m_axis_tvalid <= 1'b1;
                            end else begin
                                data_shift_cnt <= data_shift_cnt + 1;
                                m_axis_tvalid  <= 1'b0;
                            end
                        end else begin
                            m_axis_tvalid <= 1'b0;
                        end
                    end
                end

                default: rx_state <= IDLE;
            endcase
        end
    end

endmodule
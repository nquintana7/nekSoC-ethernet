import eth_pkg::*;

module rx_mac (
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

    parameter logic [47:0] SELF_MAC_ADDRESS = 48'h001A2B3C4D5E;

    enum logic [1:0] {IDLE, PREAMBLE, FILTER, RECEIVE} rx_state;

    logic [11:0] rx_byte_counter;
    logic [31:0] crc_reg, crc_next;
    
    logic [47:0] address_buffer; 
    logic [2:0] mac_cnt;

    logic [7:0] data_shift_reg [0:4];
    logic [3:0] data_shift_cnt;
    
    logic ignore_pkt;

    lfsr_eth_crc32 u_eth_crc32 (
        .data_in(phy_rx_data_i),
        .state_in(crc_reg),
        .state_out(crc_next)
    );

    always_ff @(posedge m_axis_clk) begin
        
        if (!m_axis_resetn) begin
            rx_state <= IDLE;
            data_shift_cnt <= '0;
            crc_reg <= 32'hFFFFFFFF;
            m_axis_tuser <= 1'b0;
            m_axis_tdata <= '0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast <= 1'b0;
            address_buffer <= SELF_MAC_ADDRESS;
            mac_cnt <= 3'd0;
            ignore_pkt <= 1'b0;;
        end else begin
            m_axis_tvalid <= 1'b0;
            m_axis_tlast <= 1'b0;
            m_axis_tuser <= 1'b0;
            
            case (rx_state)

                IDLE: begin
                    m_axis_tuser <= 1'b0;
                    crc_reg <= 32'hFFFFFFFF;
                    rx_byte_counter <= '0;
                    m_axis_tvalid <= 1'b0;
                    address_buffer <= SELF_MAC_ADDRESS;

                    if (!ignore_pkt & phy_rx_active_i & !phy_rx_err_i) begin
                        rx_state <= PREAMBLE;    
                    end

                    if (ignore_pkt & !phy_rx_active_i) begin
                        ignore_pkt <= 1'b0;
                    end

                end

                PREAMBLE : begin
                    
                    if (phy_rx_dv_i) begin 
                        if (phy_rx_data_i == 8'hD5) begin
                            rx_state <= FILTER;
                            mac_cnt <= 'd6;
                        end else if (phy_rx_data_i != 8'h55) begin
                            rx_state <= IDLE;
                        end
                    end

                end 

                FILTER: begin
                    
                    if (phy_rx_dv_i) begin
                        
                        mac_cnt <= mac_cnt - 1;
                        address_buffer <= {address_buffer[39:0], 8'd0};

                        if ((address_buffer[47:40] != phy_rx_data_i) && (phy_rx_data_i != 8'hFF)) begin
                            ignore_pkt <= 1'b1;
                            rx_state <= IDLE;
                        end else if (mac_cnt == 1) begin
                            rx_state <= RECEIVE;
                        end

                    end

                end

                RECEIVE : begin

                    if (phy_rx_dv_i) begin
                    
                        crc_reg <= crc_next; 
                    
                        data_shift_reg[4] <= phy_rx_data_i;
                        data_shift_reg[3] <= data_shift_reg[4];
                        data_shift_reg[2] <= data_shift_reg[3];
                        data_shift_reg[1] <= data_shift_reg[2];
                        data_shift_reg[0] <= data_shift_reg[1];

                        if (data_shift_cnt > 'd4) begin
                            m_axis_tdata <= data_shift_reg[0];
                            m_axis_tvalid <= 1'b1;
                        end else begin
                            data_shift_cnt <= data_shift_cnt + 1;
                        end
                        
                    end

                    if (!phy_rx_active_i) begin
                        
                        m_axis_tdata  <= data_shift_reg[0];
                        m_axis_tvalid <= 1'b1;
                        m_axis_tlast  <= 1'b1; 
                        m_axis_tuser <= (crc_reg != 32'hDEBB20E3);

                        rx_state <= IDLE;
                        data_shift_cnt <= '0;

                    end

                end

                default: rx_state <= IDLE;
            endcase

            if ((m_axis_tvalid && !m_axis_tready) || phy_rx_err_i) begin
                rx_state <= IDLE;
                m_axis_tdata  <= '0;
                ignore_pkt <= 1'b1;
                m_axis_tuser <= 1'b1;
                m_axis_tvalid <= 1'b1;
                m_axis_tlast  <= 1'b1;
            end

        end

    end

endmodule


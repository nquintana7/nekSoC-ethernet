import eth_pkg::*;

module eth_rx_mac (
    input logic         clk_i,
    input logic         rstn_i,

    input logic phy_rx_active_i,
    input logic [7:0] phy_rx_data_i,
    input logic phy_rx_dv_i,
    input logic phy_rx_err_i,
    // Higher layers interface

    output logic mac_rx_sof_o,
    output logic mac_rx_eof_o,
    output logic [7:0]  mac_rx_data_o,
    output logic        mac_rx_valid_o,
    output logic mac_rx_fcs_err_o
);

    enum logic [2:0] {RX_IDLE, RX_PREAMBLE, RX_RECEIVE, RX_CRC_CHECK} rx_state;

    logic [11:0] rx_byte_counter;
    logic [31:0] crc_reg, crc_next;
    logic phy_rx_dv_ff;

    lfsr_eth_crc32 u_eth_crc32 (
        .data_in(phy_rx_data_i),
        .state_in(crc_reg),
        .state_out(crc_next)
    );

    always_ff @(posedge clk_i ) begin
        
        if (!rstn_i) begin
            rx_state <= RX_IDLE;
            rx_byte_counter <= '0;
            crc_reg <= 32'hFFFFFFFF;
            phy_rx_dv_ff <= 1'b0;
            mac_rx_eof_o <= 1'b0;
            mac_rx_sof_o <= 1'b0;
            mac_rx_data_o <= '0;
            mac_rx_valid_o <= 1'b0;
            mac_rx_fcs_err_o <= 1'b0;
        end else begin
            phy_rx_dv_ff <= phy_rx_dv_i;
            mac_rx_valid_o <= 1'b0;
            mac_rx_eof_o <= 1'b0;
            mac_rx_sof_o <= 1'b0;

            case (rx_state)

                RX_IDLE: begin
                    mac_rx_fcs_err_o <= 1'b0;
                    crc_reg <= 32'hFFFFFFFF;
                    rx_byte_counter <= '0;
                    if (phy_rx_active_i & !phy_rx_err_i) begin
                        rx_state <= RX_PREAMBLE;    
                    end

                end

                RX_PREAMBLE : begin
                    
                    if (phy_rx_dv_i) begin 
                        if (phy_rx_data_i == 8'hD5) begin
                            mac_rx_sof_o <= 1'b1;
                            rx_state <= RX_RECEIVE;
                        end else if (phy_rx_data_i != 8'h55) begin
                            rx_state <= RX_IDLE;
                        end
                    end
                end 

                RX_RECEIVE : begin

                    if (phy_rx_dv_i) begin 
                        mac_rx_data_o <= phy_rx_data_i;
                        mac_rx_valid_o <= 1'b1;
                        rx_byte_counter <= rx_byte_counter + 1;
                        crc_reg <= crc_next; 
                    end

                    if (!phy_rx_active_i) begin
                        rx_state <= RX_CRC_CHECK;
                    end

                    if (phy_rx_err_i) begin
                        rx_state <= RX_IDLE;
                        mac_rx_fcs_err_o <= 1'b1;
                        mac_rx_eof_o <= 1'b1;
                    end

                end

                RX_CRC_CHECK : begin

                    mac_rx_fcs_err_o <= (crc_reg != 32'hDEBB20E3);
                    mac_rx_eof_o <= 1'b1;
                    rx_state <= RX_IDLE;
                    
                end

                default: rx_state <= RX_IDLE;
            endcase

        end

    end

endmodule
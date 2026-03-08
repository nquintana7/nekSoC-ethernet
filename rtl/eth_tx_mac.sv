module eth_tx_mac (
    input logic         clk_i,
    input logic         rstn_i,

    // Upper layer
    input  logic tx_start_i,
    input  logic tx_last_i,
    input  logic [7:0]  tx_data_i,
    output logic tx_rd_en_o,
    output logic tx_ready_o,

    // Signals to RMII interface
    input logic phy_tx_ready_i,
    output logic [7:0] phy_tx_data_o,
    output logic phy_tx_valid_data_o,
    output logic phy_tx_last_byte_o
);

    enum logic [2:0] {TX_IDLE, TX_PREAMBLE, TX_DATA, TX_CRC} tx_state;

    logic [31:0] crc_reg, crc_next;
    logic [2:0] preamble_cnt;
    logic [1:0] crc_cnt;

    lfsr_eth_crc32 u_eth_crc32 (
        .data_in(tx_data_i),
        .state_in(crc_reg),
        .state_out(crc_next)
    );

    always_ff@(posedge clk_i) begin
        
        if (!rstn_i) begin
            crc_reg <= 32'hFFFFFFFF;
            phy_tx_valid_data_o <= 1'b0;
            tx_rd_en_o <= 1'b0;
            phy_tx_last_byte_o <= 1'b0;
            crc_cnt <= '0;
            tx_state <= TX_IDLE;
            tx_ready_o <= 1'b1;
        end else begin
            phy_tx_valid_data_o <= 1'b0;
            tx_rd_en_o <= 1'b0;
            phy_tx_last_byte_o <= 1'b0;
            
            case (tx_state)
                
                TX_IDLE : begin
                    tx_ready_o <= 1'b1;
                    preamble_cnt <= '0;
                    crc_cnt <= '0;
                    crc_reg <= 32'hFFFFFFFF;

                    if (tx_start_i) begin
                        tx_state <= TX_PREAMBLE;
                        tx_ready_o <= 1'b0;
                    end

                end

                TX_PREAMBLE : begin

                    if (phy_tx_ready_i & !phy_tx_valid_data_o) begin

                        preamble_cnt <= preamble_cnt + 1; 
                        phy_tx_valid_data_o <= 1'b1;
                        phy_tx_data_o <= 8'h55;

                        if (preamble_cnt == 3'd7) begin
                            tx_state <= TX_DATA;
                            phy_tx_valid_data_o <= 1'b1;
                            phy_tx_data_o <= 8'hD5;
                        end

                    end

                end

                TX_DATA :  begin

                    if (phy_tx_ready_i & !phy_tx_valid_data_o) begin
                        phy_tx_valid_data_o <= 1'b1;
                        tx_rd_en_o <= 1'b1;
                        phy_tx_data_o <= tx_data_i;
                        crc_reg <= crc_next;
                    end

                    if (tx_last_i) begin
                        tx_state <= TX_CRC;
                    end
                    
                end

                TX_CRC : begin

                    if (phy_tx_ready_i) begin
                        
                        phy_tx_data_o <= ~crc_reg[7:0];
                        crc_reg <= {8'h00, crc_reg[31:8]};
                        
                        phy_tx_valid_data_o <= 1'b1;
                        crc_cnt <= crc_cnt + 1;
            
                        if (crc_cnt == 3'd3) begin
                            phy_tx_last_byte_o <= 1'b1;
                            tx_state <= TX_IDLE;
                        end

                    end

                end

            endcase

        end

    end

endmodule
module eth_mac_tx (
    input  logic        s_axis_clk,
    input  logic        s_axis_resetn,

    input  logic [7:0]  s_axis_tdata,
    input  logic        s_axis_tvalid,
    output logic        s_axis_tready,
    input  logic        s_axis_tlast,

    output logic data_valid_o,
    output logic [7:0] data_o,
    output logic data_last_o,
    input  logic fifo_full_i
);


    enum logic [1:0] {IDLE, PREAMBLE, DATA, CRC} tx_state;

    logic [31:0] crc_reg, crc_next;
    logic [2:0] preamble_cnt;
    logic [1:0] crc_cnt;

    lfsr_eth_crc32 u_eth_crc32 (
        .data_in(s_axis_tdata),
        .state_in(crc_reg),
        .state_out(crc_next)
    );

    assign s_axis_tready = !fifo_full_i && tx_state == DATA && !data_valid_o;

    always_ff@(posedge s_axis_clk or negedge s_axis_resetn) begin
        
        if (!s_axis_resetn) begin
            crc_reg <= 32'hFFFFFFFF;
            crc_cnt <= '0;
            data_last_o <= 1'b0;
            data_valid_o <= 1'b0;
            data_o <= '0;
            tx_state <= IDLE;
        end else begin
            data_last_o <= 1'b0;
            data_valid_o <= 1'b0;
            
            case (tx_state)
                
                IDLE : begin

                    preamble_cnt <= '0;
                    crc_cnt <= '0;
                    crc_reg <= 32'hFFFFFFFF;

                    if (s_axis_tvalid & !fifo_full_i) begin
                        tx_state <= PREAMBLE;
                    end

                end

                PREAMBLE : begin

                        if (!fifo_full_i & !data_valid_o) begin
                            
                            preamble_cnt <= preamble_cnt + 1; 
                            data_valid_o <= 1'b1;
                            data_o <= 8'h55;

                            if (preamble_cnt == 3'd7) begin
                                tx_state <= DATA;
                                data_valid_o <= 1'b1;
                                data_o <= 8'hD5;
                            end

                        end

                end

                DATA :  begin

                    if (!fifo_full_i & !data_valid_o) begin

                        if (s_axis_tvalid) begin
                            data_valid_o <= 1'b1;
                            data_o <= s_axis_tdata;
                            crc_reg <= crc_next;
                        end

                        if (s_axis_tlast) begin
                            tx_state <= CRC;
                        end

                    end
                    
                end

                CRC : begin

                    if (!fifo_full_i & !data_valid_o) begin
                        
                        data_o <= ~crc_reg[7:0];
                        crc_reg <= {8'h00, crc_reg[31:8]};
                        
                        data_valid_o <= 1'b1;
                        crc_cnt <= crc_cnt + 1;
            
                        if (crc_cnt == 3'd3) begin
                            data_last_o <= 1'b1;
                            tx_state <= IDLE;
                        end

                    end 

                end

            endcase

        end

    end

endmodule


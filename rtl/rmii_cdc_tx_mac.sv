module rmii_cdc_tx_mac (
    input  logic       clk_i,
    input  logic       rstn_i,
    
    input  logic [7:0] data_i,
    input  logic       data_valid_i,
    input  logic       data_last_i,
    output logic       fifo_full_o,

    input  logic       clk_50m_i,
    input  logic       rstn_50m_i,
    
    output logic [7:0] phy_tx_byte_o,
    output logic       phy_tx_valid_o,
    output logic       phy_tx_last_o,
    input  logic       phy_tx_ready_i   
);

    logic fifo_empty, fifo_empty_ff;
    logic [8:0] fifo_dout;
    
    always_ff @(posedge clk_50m_i or negedge rstn_i)
    begin
        if (!rstn_i) begin
            phy_tx_valid_o <= 1'b0;
        end else begin
        
            if (phy_tx_valid_o & phy_tx_last_o & phy_tx_ready_i) begin // make sure RMII read the last value
                phy_tx_valid_o <= 1'b0;    
            end else begin
                phy_tx_valid_o <= ~fifo_empty;
            end
               
        end
    end

    assign phy_tx_byte_o = fifo_dout[7:0];
    assign phy_tx_last_o = fifo_dout[8];

    fifo_async #(
        .DATA_WIDTH(9),
        .ADDR_WIDTH(11)  
    ) u_tx_fifo (
        .wclk_i  (clk_i),
        .wrstn_i (rstn_i),
        .wen_i   (data_valid_i),
        .din_i   ({data_last_i, data_i}),
        .wfull   (),
        .walmost_full(fifo_full_o),
        .rclk_i  (clk_50m_i),
        .rrstn_i (rstn_50m_i),
        .rden_i  (phy_tx_ready_i && ~fifo_empty),
        .dout_o  (fifo_dout),
        .empty_o (fifo_empty)
    );

endmodule
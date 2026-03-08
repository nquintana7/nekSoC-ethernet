module tx_packet_buffer #(
    parameter ADDR_WIDTH = 12
)(

    input  logic        pkt_clk_i,
    input  logic        pkt_rstn_i,
    input  logic [7:0]  pkt_data_i,
    input  logic        pkt_wren_i,
    input  logic        pkt_commit_i,
    output logic        pkt_fifo_full_o,

    input  logic        mac_clk_i,
    input  logic        mac_rstn_i,
    output logic        tx_start_o,
    output logic [7:0]  tx_data_o,
    output logic        tx_last_o,
    input  logic        tx_rd_en_i,
    input  logic        tx_ready_i
);

    logic [7:0] mem [0:(1<<ADDR_WIDTH)-1];
    logic [ADDR_WIDTH-1:0] wptr, rptr;
    logic [ADDR_WIDTH-1:0] pkt_start_ptr, pkt_end_ptr;
    
    logic [ADDR_WIDTH-1:0] metafifo_dout;
    logic metafifo_empty, metafifo_rden;
    logic [ADDR_WIDTH-1:0] rd_pkt_len, s_rptr;

    logic [ADDR_WIDTH-1:0] wr_pkt_len;
    assign wr_pkt_len = wptr - pkt_start_ptr;
    
    logic tx_state;

    async_fifo_sync #(
        .DATA_WIDTH(ADDR_WIDTH), 
        .ADDR_WIDTH(4)
    ) u_meta_fifo (
        .wclk_i(pkt_clk_i), .wrstn_i(pkt_rstn_i),
        .wen_i(pkt_commit_i),
        .din_i(wr_pkt_len),
        .rclk_i(mac_clk_i), .rrstn_i(mac_rstn_i),
        .rden_i(metafifo_rden),
        .dout_o(metafifo_dout),
        .empty_o(metafifo_empty),
        .wfull(pkt_fifo_full_o)
    );

    always_ff @(posedge pkt_clk_i) begin
        if (!pkt_rstn_i) begin
            wptr <= '0;
            pkt_start_ptr <= '0;
        end else begin
         
            if (pkt_wren_i) begin
                mem[wptr] <= pkt_data_i;
                wptr      <= wptr + 1;
            end
            
            if (pkt_commit_i) begin
                pkt_start_ptr <= wptr;    
            end
            
        end
    end

    always_ff @(posedge mac_clk_i) begin
        if (!mac_rstn_i) begin
            rptr <= '0;
            tx_state <= 1'b0;
            metafifo_rden <= 1'b0;
            tx_last_o <= 1'b0;
            tx_start_o <= 1'b0;
            pkt_end_ptr <= '0;
            
        end else begin
            metafifo_rden <= 1'b0;
            tx_start_o <= 1'b0;
            
            if (!tx_state) begin
            
                tx_last_o <= 1'b0;
                
                if (!metafifo_empty & tx_ready_i) begin
                    tx_state <= 1'b1;
                    tx_start_o <= 1'b1;
                    pkt_end_ptr <= rptr + metafifo_dout - 1;
                    metafifo_rden <= 1'b1;
                end
            
            end else begin
            
                if (tx_rd_en_i && rptr == pkt_end_ptr) begin
                    tx_state <= 1'b0;
                    tx_last_o <= 1'b1;
                end
                
            end
        
            if (tx_rd_en_i) begin
                rptr <= rptr + 1;
            end
            
            tx_data_o <= mem[rptr];
        
        end
    end

endmodule
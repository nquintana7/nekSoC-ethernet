module axis_tx_packet_buffer #(
    parameter ADDR_WIDTH = 12
)(

    input  logic        s_axis_clk,
    input  logic        s_axis_aresetn,
    input  logic [7:0]  s_axis_tdata,
    input  logic        s_axis_tvalid,
    output logic        s_axis_tready,
    input  logic        s_axis_tlast,

    input  logic        mac_clk_i,
    input  logic        mac_rstn_i,
    output logic        tx_start_o,
    output logic [7:0]  tx_data_o,
    output logic        tx_last_o,
    input  logic        tx_rd_en_i,
    input  logic        tx_ready_i
);

    logic [7:0] mem [0:(1<<ADDR_WIDTH)-1];

    logic wren, pkt_commit;
    logic [ADDR_WIDTH-1:0] wptr, rptr;
    logic [ADDR_WIDTH-1:0] pkt_start_ptr, pkt_end_ptr;
    logic [ADDR_WIDTH-1:0] wr_pkt_len;
    
    logic [ADDR_WIDTH-1:0] metafifo_dout;
    logic metafifo_empty, metafifo_rden, metafifo_full;

    logic [ADDR_WIDTH-1:0] rd_pkt_len, s_rptr;

    logic rd_state;
    
    assign wr_pkt_len = wptr - pkt_start_ptr;
    assign s_axis_tready = !metafifo_full;

    async_fifo_sync #(
        .DATA_WIDTH(ADDR_WIDTH), 
        .ADDR_WIDTH(4)
    ) u_meta_fifo (
        .wclk_i(s_axis_clk), .wrstn_i(s_axis_aresetn),
        .wen_i(pkt_commit),
        .din_i(wr_pkt_len),
        .rclk_i(mac_clk_i), .rrstn_i(mac_rstn_i),
        .rden_i(metafifo_rden),
        .dout_o(metafifo_dout),
        .empty_o(metafifo_empty),
        .wfull(metafifo_full)
    );

    always_ff @(posedge s_axis_clk) begin
        if (!s_axis_aresetn) begin
            wptr <= '0;
            pkt_start_ptr <= '0;
            pkt_commit <= 1'b0;
        end else begin
            pkt_commit <= 1'b0;
         
            if (s_axis_tvalid && s_axis_tready) begin
                mem[wptr] <= s_axis_tdata;
                wptr      <= wptr + 1;
                
                if (s_axis_tlast) begin
                    pkt_commit <= 1'b1;
                end
                
            end
            
            if (pkt_commit) begin
                pkt_start_ptr <= wptr;    
            end
            
        end
    end

    always_ff @(posedge mac_clk_i) begin
        if (!mac_rstn_i) begin
            rptr <= '0;
            rd_state <= 1'b0;
            metafifo_rden <= 1'b0;
            tx_last_o <= 1'b0;
            tx_start_o <= 1'b0;
            pkt_end_ptr <= '0;
            
        end else begin
            metafifo_rden <= 1'b0;
            tx_start_o <= 1'b0;
            
            if (!rd_state) begin
            
                tx_last_o <= 1'b0;
                
                if (!metafifo_empty & tx_ready_i) begin
                    rd_state <= 1'b1;
                    tx_start_o <= 1'b1;
                    pkt_end_ptr <= rptr + metafifo_dout - 1;
                    metafifo_rden <= 1'b1;
                end
            
            end else begin
            
                if (tx_rd_en_i && rptr == pkt_end_ptr) begin
                    rd_state <= 1'b0;
                    tx_last_o <= 1'b1;
                    rptr <= rptr + 1;
                end
                
            end
        
            if (tx_rd_en_i) begin
                rptr <= rptr + 1;
            end
            
            tx_data_o <= mem[rptr];
        
        end
    end

endmodule
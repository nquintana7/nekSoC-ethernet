// Store-and-Fordward in BRAM
// Wait for crc check to decide if packet is kept or discarded
module axis_rx_packet_buffer #(
    parameter ADDR_WIDTH = 12, // 4096 Bytes (Enough for ~2.7 Jumbo Frames)
    parameter DATA_WIDTH = 8
)(
    
    // Write Clock Domain = MAC Side
    input logic mac_clk_i,
    input logic mac_rstn_i,
    input  logic [7:0] mac_din,
    input  logic       mac_valid_i,
    input  logic       mac_start_i,
    input  logic       mac_end_i,
    input  logic       mac_crc_fail_i,

    // Read Clock Domain = App Side
    input  logic        m_axis_clk,
    input  logic        m_axis_aresetn,
    output logic [7:0]  m_axis_tdata,
    output logic        m_axis_tvalid,
    input  logic        m_axis_tready,
    output logic        m_axis_tlast
);
    localparam DEPTH = 1 << ADDR_WIDTH;
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    logic overflow;
    logic [ADDR_WIDTH:0] s_wptr, wptr, wptr_gray;
    logic [ADDR_WIDTH:0] rptr, rptr_gray, rptr_gray_next, wq1_rptr, wq2_rptr;
    logic mem_full;
    
    logic [10:0] pkt_len_din, pkt_len_dout;
    logic metafifo_wren, metafifo_rden;
    logic metafifo_full, metafifo_empty;
    
    logic [10:0] pkt_rd_cnt;

    assign pkt_ready_o = ~metafifo_empty;

    async_fifo_sync #(
        .DATA_WIDTH (11),
        .ADDR_WIDTH (4)
    ) u_metadata_fifo (
        // --- Write Domain (MAC / 50MHz RMII Clock) ---
        .wclk_i  (mac_clk_i), 
        .wrstn_i (mac_rstn_i), 
        .wen_i   (metafifo_wren),
        .din_i   (pkt_len_din),
        .wfull   (metafifo_full),

        // --- Read Domain  ---
        .rclk_i  (m_axis_clk),
        .rrstn_i (m_axis_aresetn),
        .rden_i  (metafifo_rden),
        .dout_o  (pkt_len_dout),
        .empty_o (metafifo_empty)
    );

    // Write Logic
    always_ff @(posedge mac_clk_i) begin

        if (!mac_rstn_i) begin
            wptr <= '0;
            s_wptr <= '0;
            pkt_len_din <= '0;
            metafifo_wren <= 1'b0;
            overflow <= 1'b0;
            wptr_gray <= '0;
        end else begin
            metafifo_wren <= 1'b0;

            if (mac_start_i) begin
                s_wptr <= wptr;
                overflow <= 1'b0;
            end

            if (mac_end_i) begin
                if (mac_crc_fail_i) begin
                    wptr <= s_wptr; 
                end else begin
                    pkt_len_din <= wptr - s_wptr - 4;
                    wptr <= wptr - 4;
                    metafifo_wren <= 1'b1;
                end
            end else if (mac_valid_i && !overflow && !mem_full) begin
                mem[wptr[ADDR_WIDTH-1:0]] <= mac_din;
                wptr <= wptr + 1;
            end 

            if (mac_valid_i && mem_full) begin
                overflow <= 1'b1;
                wptr <= s_wptr;
            end 

            wptr_gray <= wptr_gray_next;

        end

    end

    assign wptr_gray_next = wptr ^ (wptr >> 1);

    always_ff @(posedge mac_clk_i) begin
        if (!mac_rstn_i) begin
            wq2_rptr <= '0;
            wq1_rptr <= '0;
        end else begin
            wq1_rptr <= rptr_gray;
            wq2_rptr <= wq1_rptr;
        end
    end

    assign mem_full = (wptr_gray_next == {~wq2_rptr[ADDR_WIDTH], wq2_rptr[ADDR_WIDTH-1:0]});
    // --- End Write Logic
    
    // Read Logic
    enum logic [1:0] {IDLE, STREAM} rd_state;
    always_ff @(posedge m_axis_clk) begin

        if (!m_axis_aresetn) begin
            rptr <= '0;
            rptr_gray <= '0;
            pkt_rd_cnt <= '0;
            metafifo_rden <= 1'b0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast <= 1'b0;
            rd_state <= IDLE;
        end else begin
            metafifo_rden <= 1'b0;
            m_axis_tlast <= 1'b0;

            case (rd_state)

                IDLE : begin

                    m_axis_tvalid <= 1'b0;
                    m_axis_tlast <= 1'b0;

                    if (!metafifo_empty & m_axis_tready) begin
                        rd_state <= STREAM;
                        pkt_rd_cnt <= pkt_len_dout;
                        metafifo_rden <= 1'b1;
                    end

                end

                STREAM : begin
                    if (m_axis_tready) begin
                        m_axis_tvalid <= 1'b1;
                        pkt_rd_cnt <= pkt_rd_cnt - 1;    
                        rptr <= rptr + 1;
                        if (pkt_rd_cnt == 1) begin
                            m_axis_tlast <= 1'b1;
                            rd_state      <= IDLE;
                        end
                    end  
                end
                
            endcase

            m_axis_tdata <= mem[rptr[ADDR_WIDTH-1:0]];
            rptr_gray <= rptr_gray_next;

        end

    end

    assign rptr_gray_next = rptr ^ (rptr >> 1);
    
endmodule
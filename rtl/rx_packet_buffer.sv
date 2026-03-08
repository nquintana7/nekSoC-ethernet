// Store-and-Fordward in BRAM
// Wait for crc check to decide if packet is kept or discarded
module rx_packet_buffer #(
    parameter ADDR_WIDTH = 12, // 4096 Bytes (Enough for ~2.7 Jumbo Frames)
    parameter DATA_WIDTH = 8
)(
    
    // Write Clock Domain = MAC Side
    input logic wclk_i,
    input logic wrstn_i,
    input  logic [7:0] mac_din,
    input  logic       mac_valid_i,
    input  logic       mac_start_i,
    input  logic       mac_end_i,
    input  logic       mac_crc_fail_i,

    // Read Clock Domain = App Side
    input logic rclk_i,
    input logic rrstn_i,
    input  logic        data_rden_i,
    input  logic        pkt_len_rden_i,
    output logic        pkt_ready_o,
    output logic [10:0] pkt_len_o,
    output logic [7:0]  data_o,
    output logic data_valid_o
);
    localparam DEPTH = 1 << ADDR_WIDTH;
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    logic overflow;
    logic [ADDR_WIDTH:0] s_wptr, wptr, wptr_gray;
    logic [ADDR_WIDTH:0] rptr, rptr_gray, rptr_gray_next, wq1_rptr, wq2_rptr;
    logic mem_full;
    
    logic [10:0] pkt_len;
    logic metafifo_wren;
    logic metafifo_full, metafifo_empty;

    assign pkt_ready_o = ~metafifo_empty;

    async_fifo_sync #(
        .DATA_WIDTH (11),
        .ADDR_WIDTH (4)
    ) u_metadata_fifo (
        // --- Write Domain (MAC / 50MHz RMII Clock) ---
        .wclk_i  (wclk_i), 
        .wrstn_i (wrstn_i), 
        .wen_i   (metafifo_wren),
        .din_i   (pkt_len),
        .wfull   (metafifo_full),

        // --- Read Domain  ---
        .rclk_i  (rclk_i),
        .rrstn_i (rrstn_i),
        .rden_i  (pkt_len_rden_i),
        .dout_o  (pkt_len_o),
        .empty_o (metafifo_empty)
    );

    // Write Logic
    always_ff @(posedge wclk_i) begin

        if (!wrstn_i) begin
            wptr <= '0;
            s_wptr <= '0;
            pkt_len <= '0;
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
                    pkt_len <= wptr - s_wptr - 4;
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

    always_ff @(posedge wclk_i) begin
        if (!wrstn_i) begin
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
    always_ff @(posedge rclk_i) begin

        if (!rrstn_i) begin
            rptr <= '0;
            rptr_gray <= '0;
            data_valid_o <= 1'b0;
        end else begin
            data_valid_o <= 1'b0;

            if (data_rden_i) begin
                rptr <= rptr + 1;
                data_valid_o <= 1'b1;
            end

            data_o <= mem[rptr[ADDR_WIDTH-1:0]];

            rptr_gray <= rptr_gray_next;

        end

    end

    assign rptr_gray_next = rptr ^ (rptr >> 1);
    
endmodule
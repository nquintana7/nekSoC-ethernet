`timescale 1ns/1ps

module async_fifo_sync #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4  // FIFO Depth = 2^ADDR_WIDTH
)(
    // -----------------------------------------
    // Write Clock Domain
    // -----------------------------------------
    input  logic                  wclk_i,
    input  logic                  wrstn_i,  // Synchronous active-low reset
    input  logic                  wen_i,    // Write Enable
    input  logic [DATA_WIDTH-1:0] din_i,   // Data in
    output logic                  wfull,   // FIFO Full flag (Pessimistic)
    output logic walmost_full,
    // -----------------------------------------
    // Read Clock Domain
    // -----------------------------------------
    input  logic                  rclk_i,
    input  logic                  rrstn_i,  // Synchronous active-low reset
    input  logic                  rden_i,    // Read Enable
    output logic [DATA_WIDTH-1:0] dout_o,   // Data out
    output logic                  empty_o   // FIFO Empty flag (Pessimistic)
);

    localparam DEPTH = 1 << ADDR_WIDTH;
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    logic [ADDR_WIDTH:0] wptr_bin, wptr_gray, wptr_gray_next, wptr_bin_next;
    logic [ADDR_WIDTH:0] rptr_bin, rptr_gray, rptr_gray_next, rptr_bin_next;

    logic [ADDR_WIDTH:0] wq1_rptr, wq2_rptr; 
    logic [ADDR_WIDTH:0] rq1_wptr, rq2_wptr; 


    always_ff @(posedge wclk_i) begin
        if (wen_i && !wfull) begin 
            mem[wptr_bin[ADDR_WIDTH-1:0]] <= din_i;
        end
    end

    assign dout_o = mem[rptr_bin[ADDR_WIDTH-1:0]];

    // -----------------------------------------
    // 2. Write Pointer & Gray Code Generation
    // -----------------------------------------
    always_ff @(posedge wclk_i or negedge wrstn_i) begin
        if (!wrstn_i) begin
            wptr_bin  <= '0;
            wptr_gray <= '0;
        end else begin
            wptr_bin  <= wptr_bin_next;
            wptr_gray <= wptr_gray_next;
        end
    end

    always_comb begin
        wptr_bin_next  = wptr_bin + (wen_i & ~wfull);
        wptr_gray_next = wptr_bin_next ^ (wptr_bin_next >> 1);
    end

    // -----------------------------------------
    // 3. Read Pointer & Gray Code Generation
    // -----------------------------------------
    always_ff @(posedge rclk_i or negedge rrstn_i) begin
        if (!rrstn_i) begin
            rptr_bin  <= '0;
            rptr_gray <= '0;
        end else begin
            rptr_bin  <= rptr_bin_next;
            rptr_gray <= rptr_gray_next;
        end
    end

    always_comb begin
        rptr_bin_next  = rptr_bin + (rden_i & ~empty_o);
        rptr_gray_next = rptr_bin_next ^ (rptr_bin_next >> 1);
    end

    // -----------------------------------------
    // 4. Synchronizers (Crossing the Domains)
    // -----------------------------------------
    always_ff @(posedge wclk_i or negedge wrstn_i) begin
        if (!wrstn_i) begin
            wq2_rptr <= '0;
            wq1_rptr <= '0;
        end else begin
            wq1_rptr <= rptr_gray;
            wq2_rptr <= wq1_rptr;
        end
    end

    always_ff @(posedge rclk_i or negedge rrstn_i) begin
        if (!rrstn_i) begin
            rq2_wptr <= '0;
            rq1_wptr <= '0;
        end else begin
            rq1_wptr <= wptr_gray;
            rq2_wptr <= rq1_wptr;
        end
    end

    // -----------------------------------------
    // 5. Full and Empty Flag Generation
    // -----------------------------------------
    logic rempty_val;
    always_comb begin
        rempty_val = (rptr_gray_next == rq2_wptr);
    end

    always_ff @(posedge rclk_i or negedge rrstn_i) begin
        if (!rrstn_i) empty_o <= 1'b1;
        else         empty_o <= rempty_val;
    end

    logic wfull_val, walmost_full_val;
    logic [ADDR_WIDTH:0] wptr_bin_plus2;
    logic [ADDR_WIDTH:0] wptr_gray_plus2;
    always_comb begin
        wfull_val = (wptr_gray_next == {~wq2_rptr[ADDR_WIDTH:ADDR_WIDTH-1], wq2_rptr[ADDR_WIDTH-2:0]});

        wptr_bin_plus2  = wptr_bin_next + 1'b1;
        wptr_gray_plus2 = wptr_bin_plus2 ^ (wptr_bin_plus2 >> 1);
        
        walmost_full_val = (wptr_gray_plus2 == {~wq2_rptr[ADDR_WIDTH:ADDR_WIDTH-1], wq2_rptr[ADDR_WIDTH-2:0]});
    end

    always_ff @(posedge wclk_i or negedge wrstn_i) begin
        if (!wrstn_i) begin
            wfull       <= 1'b0;
            walmost_full <= 1'b0;
        end else begin
            wfull       <= wfull_val;
            walmost_full <= walmost_full_val || wfull_val;
        end
    end
endmodule


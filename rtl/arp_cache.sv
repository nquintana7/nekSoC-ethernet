`timescale 1ns/1ps

module arp_cache (
    input logic clk_i,
    input logic rstn_i,

    input logic [31:0] wr_ip_i,
    input logic [47:0] wr_mac_i,
    input logic store_pair_i,

    input logic [31:0] rd_ip_i,
    output logic [47:0] rd_mac_o,
    output logic miss_o
);

    logic [79:0] cache [0:7]; // store at least 8 pairs
    logic [7:0] flags;
    logic [2:0] oldest;
    logic [3:0] select_rd;
    
    always_ff@(posedge clk_i or negedge rstn_i) begin
        
        if (!rstn_i) begin
            oldest <= '0; 
            flags <= '0;
        end else if (store_pair_i) begin
            logic stop;
            logic found;

            found = 0;
            stop = 0;

            for (int i = 0; i < 8; i++) begin
                if (!flags[i] & !stop) begin
                    cache[i] <= {wr_mac_i, wr_ip_i};
                    flags[i] <= 1'b1;
                    stop = 1'b1;
                end    
            end

//            if (!stop) begin

//                for (int i = 0; i < 8; i++) begin
//                    if (!flags[i] && !stop) begin
//                        cache[i]      <= {wr_mac_i, wr_ip_i};
//                        flags[i] <= 1'b1;
//                        found     = 1'b1;
//                    end
//                end

                if (!stop) begin 
                    cache[oldest] <= {wr_mac_i, wr_ip_i};
                    oldest        <= oldest + 1'b1;
               end

//            end

        end
    end
    
always_ff @(posedge clk_i or negedge rstn_i) begin
    if (!rstn_i) begin
        miss_o   <= 1'b1;
        rd_mac_o <= 48'h0;
        select_rd <= '0;
    end else begin
        // Default values for the clock cycle
        select_rd <= '0;
        miss_o   <= select_rd == '0;
        rd_mac_o <= 48'h0;

        // Parallel search, but the result is locked into a flip-flop
        for (int i = 0; i < 8; i++) begin
            if (flags[i] && (cache[i][31:0] == rd_ip_i)) begin
                select_rd <= i;
            end
        end

        
        rd_mac_o <= cache[select_rd][79:32];
    end
end

endmodule
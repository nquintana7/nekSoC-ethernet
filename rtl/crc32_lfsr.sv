//
// Manually get the 1-byte parallel combinational logic
// 
module lfsr_eth_crc32 (
    input  logic [7:0]  data_in,
    input  logic [31:0] state_in,
    output logic [31:0] state_out
);
    logic [31:0] crc_temp;
    logic        lsb;

    always_comb begin
        crc_temp = state_in;
        
        for (int i = 0; i < 8; i++) begin
            // Ethernet processes LSB first, so we check data_in[i] against the CRC's LSB
            lsb = crc_temp[0] ^ data_in[i];
            
            if (lsb) begin
                crc_temp = (crc_temp >> 1) ^ 32'hEDB8_8320; 
            end else begin
                crc_temp = (crc_temp >> 1);
            end
        end
        
        state_out = crc_temp;
    end
    
endmodule


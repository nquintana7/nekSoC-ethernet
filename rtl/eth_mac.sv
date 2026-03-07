import eth_pkg::*;

module eth_mac (
    input logic         clk_i,
    input logic         rstn_i,

    // RMI Interface
    output logic [7:0] tx_byte_o,
    output logic tx_byte_valid_o,
    output logic tx_last_byte_o,
    input  logic tx_ready_i,

    input logic rx_active_i,
    input logic [7:0] rx_byte_i,
    input logic rx_byte_valid_i,
    input logic byte_error_i,

    // Higher layers interface
    input ethernet_packet_t tx_ethernet_packet_i,
    input logic        tx_packet_valid_i,

    output ethernet_packet_t rx_ethernet_packet_o,
    output logic        rx_packet_valid_o
);

    // RX Signals
    enum logic [2:0] {RX_IDLE, RX_RECEIVE, RX_CRC_CHECK} rx_state;

    logic [7:0] packet_buffer [0:MAX_FRAME_BYTELENGTH-1];
    logic [11:0] rx_byte_counter, tx_byte_counter;
    logic [31:0] crc_reg, crc_next;
    logic rx_byte_valid_ff;

    // RX Logic
    lfsr_eth_crc32 eth_crc_8 (
        .data_in(rx_byte_i),
        .state_in(crc_reg),
        .state_out(crc_next)
    );

    always_ff @(posedge clk_i ) begin
        
        if (!rstn_i) begin
            rx_state <= RX_IDLE;
            rx_byte_counter <= '0;
            crc_reg <= 32'hFFFFFFFF;
            rx_byte_valid_ff <= 1'b0;
            rx_packet_valid_o <= 1'b0;
            rx_ethernet_packet_o <= '0;
        end else begin
            rx_byte_valid_ff <= rx_byte_valid_i;
            
            case (rx_state)

                RX_IDLE: begin
                    crc_reg <= 32'hFFFFFFFF;
                    rx_byte_counter <= '0;
                    if (rx_active_i & !byte_error_i) begin
                        rx_state <= RX_RECEIVE;   
                    end
                    rx_packet_valid_o <= 1'b0;
                end 

                RX_RECEIVE : begin

                    if (rx_byte_valid_i) begin 
                        packet_buffer[rx_byte_counter] <= rx_byte_i;
                        rx_byte_counter <= rx_byte_counter + 1;
                    end
                    
                    if (rx_byte_valid_ff) begin
                        crc_reg <= crc_next; 
                    end

                    if (!rx_active_i) begin
                        rx_state <= RX_CRC_CHECK;
                    end

                    if (byte_error_i) begin
                        rx_state <= RX_IDLE;
                    end

                end

                RX_CRC_CHECK : begin
                    
                    rx_ethernet_packet_o.mac_dst_addr <= {packet_buffer[0], packet_buffer[1], packet_buffer[2], packet_buffer[3], packet_buffer[4], packet_buffer[5]};
                    rx_ethernet_packet_o.mac_src_addr <= {packet_buffer[6], packet_buffer[7], packet_buffer[8], packet_buffer[9], packet_buffer[10], packet_buffer[11]};
                    rx_ethernet_packet_o.eth_type <= {packet_buffer[12], packet_buffer[13]};
                    for (int j = 0; j < 1500; j++) begin
                        rx_ethernet_packet_o.payload[j] <= packet_buffer[14 + j];
                    end
                    rx_ethernet_packet_o.payload_len <= rx_byte_counter - 18;
                    rx_packet_valid_o <= (crc_reg == 32'hDEBB20E3);
                    rx_state <= RX_IDLE;
                    
                end

                default: rx_state <= RX_IDLE;
            endcase

        end

    end
    // End RX Logic

endmodule
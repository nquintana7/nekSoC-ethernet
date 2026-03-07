`timescale 1ns/1ps
import eth_pkg::*;

module tb_eth_mac;

    // Clock / Reset
    logic clk, rstn;

    // RX signals
    logic [7:0] rx_byte_i;
    logic rx_byte_valid_i, rx_active_i, byte_error_i;

    // TX signals (unused)
    logic [7:0] tx_byte_o;
    logic tx_byte_valid_o, tx_last_byte_o, tx_ready_i;

    // MAC output
    ethernet_packet_t rx_packet_o;
    logic rx_packet_valid_o;

    // Packet data
    logic [7:0] packet[0:13];   // 14-byte header
    logic [7:0] payload[0:3];   // 4-byte payload
    integer i;                   // loop variable
    logic [31:0] crc;

    // Instantiate DUT
    eth_mac dut (
        .clk_i(clk),
        .rstn_i(rstn),
        .tx_byte_o(tx_byte_o),
        .tx_byte_valid_o(tx_byte_valid_o),
        .tx_last_byte_o(tx_last_byte_o),
        .tx_ready_i(tx_ready_i),
        .rx_active_i(rx_active_i),
        .rx_byte_i(rx_byte_i),
        .rx_byte_valid_i(rx_byte_valid_i),
        .byte_error_i(byte_error_i),
        .tx_ethernet_packet_i('0),
        .tx_packet_valid_i(0),
        .rx_ethernet_packet_o(rx_packet_o),
        .rx_packet_valid_o(rx_packet_valid_o)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;
        
        
    logic [7:0] real_ethernet_frame [0:63] = '{
            // --- MAC HEADER (14 bytes) ---
            8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, // Dest MAC: Broadcast
            8'h00, 8'h0E, 8'h7F, 8'h5F, 8'hF1, 8'hDF, // Src MAC: 00:0e:7f:5f:f1:df
            8'h08, 8'h06,                             // EtherType: ARP (0x0806)
    
            // --- ARP PAYLOAD (28 bytes) ---
            8'h00, 8'h01, 8'h08, 8'h00, 8'h06, 8'h04, // Hardware/Protocol types & sizes
            8'h00, 8'h01,                             // Opcode: Request
            8'h00, 8'h0E, 8'h7F, 8'h5F, 8'hF1, 8'hDF, // Sender MAC
            8'hC0, 8'hA8, 8'h01, 8'h84,               // Sender IP: 192.168.1.132
            8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, // Target MAC: 00:00:00:00:00:00 (Unknown)
            8'hC0, 8'hA8, 8'h01, 8'h41,               // Target IP: 192.168.1.65
    
            // --- PADDING (18 bytes) ---
            // Ethernet requires a minimum 60-byte payload before the FCS
            8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 
            8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 
            8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
    
            // --- FCS / CRC-32 (4 bytes) ---
            // This is the actual hardware-calculated CRC appended by the source PHY
            8'hF9, 8'hA6, 8'hDF, 8'h13                
        };

    logic [31:0] fcs;
    logic [7:0] fcs_bytes [3:0];
    int frame_len;
    initial begin
        // Reset
        rstn = 0;
        rx_active_i = 0;
        rx_byte_valid_i = 0;
        byte_error_i = 0;
        #0 rstn = 1;

        // Send packet byte by byte
        @(posedge clk);
        rx_active_i = 1;
        @(posedge clk);  
        foreach (real_ethernet_frame[i]) begin
            @(posedge clk);           // keep byte valid for 1 clock
            rx_byte_i = real_ethernet_frame[i];
            rx_byte_valid_i = 1;
            @(posedge clk);           // keep byte valid for 1 clock
            rx_byte_valid_i = 0;
            @(posedge clk);           // gap of 1 clock   
        end
        
        // Deassert signals
        rx_active_i = 0;
        rx_byte_valid_i = 0;

        // Wait for MAC to process
        @(posedge clk);
        @(posedge clk);
        if (rx_packet_valid_o) begin
            $display("Packet received successfully!");
            $display("DST MAC: %0h", rx_packet_o.mac_dst_addr);
            $display("SRC MAC: %0h", rx_packet_o.mac_src_addr);
            $display("Ethertype: %0h", rx_packet_o.eth_type);
            $display("Payload length: %0d bytes", rx_packet_o.payload_len);
        end else begin
            $display("Packet reception failed (CRC mismatch?)");
        end

        $finish;
    end

endmodule
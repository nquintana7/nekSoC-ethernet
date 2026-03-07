`timescale 1ns/1ps

module tb_rmii_phy;

    logic clk_50mhz;
    logic rstn;

    // TX/MAC signals
    logic [7:0] tx_byte_i;
    logic tx_byte_valid_i;
    logic tx_last_byte_i;
    logic tx_ready_o;

    // PHY TX
    logic [1:0] txd_o;
    logic txen_o;

    // PHY RX
    logic [1:0] rxd_i;
    logic crs_dv;
    logic rxer_i;
    logic [8-1:0] rx_byte_o;
    logic rx_byte_valid_o;
    logic byte_error_o;
    logic frame_start_o;

    // Instantiate PHY
    rmii_phy uut (
        .clk_i(clk_50mhz),
        .rstn_i(rstn),
        .tx_byte_i(tx_byte_i),
        .tx_byte_valid_i(tx_byte_valid_i),
        .tx_last_byte_i(tx_last_byte_i),
        .tx_ready_o(tx_ready_o),
        .txd_o(txd_o),
        .txen_o(txen_o),
        .rxd_i(txd_o),        // loopback
        .crs_dv(txen_o),
        .rxer_i(1'b0),
        .rx_byte_o(rx_byte_o),
        .rx_byte_valid_o(rx_byte_valid_o),
        .byte_error_o(byte_error_o),
        .frame_start_o(frame_start_o)
    );

    // Clock
    initial clk_50mhz = 0;
    always #10 clk_50mhz = ~clk_50mhz;  // 50 MHz

    // Reset
    initial begin
        rstn = 0;
        tx_byte_i = 0;
        tx_byte_valid_i = 0;
        tx_last_byte_i = 0;
        #100;
        rstn = 1;
    end

    // Stimulus: send 4-byte frame
    initial begin
        wait(rstn);

        send_byte(8'hDE, 0);
        send_byte(8'hAD, 0);
        send_byte(8'hBE, 0);
        send_byte(8'hEF, 1);  
        #500; 
        send_byte(8'hAE, 0);
        send_byte(8'hBC, 1);
        #500 $finish;
    end

    task send_byte(input [7:0] by, input last);
        begin
            @(posedge clk_50mhz);
            wait(tx_ready_o);
            tx_byte_i = by;
            tx_byte_valid_i = 1;
            tx_last_byte_i = last;
            @(posedge clk_50mhz);
            wait(!tx_ready_o);
            tx_byte_valid_i = 0;
            tx_last_byte_i = 0;
        end
    endtask

    // Monitor RX
    always @(posedge clk_50mhz) begin
        if (rx_byte_valid_o)
            $display("RX_BYTE=%02h ERROR=%b FRAME_START=%b", 
                     rx_byte_o, byte_error_o, frame_start_o);
    end

endmodule
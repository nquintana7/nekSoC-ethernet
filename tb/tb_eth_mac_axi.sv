`timescale 1ns/1ps

module tb_eth_mac_axi();
    logic clk_100m = 0, clk_50m = 0, rstn = 0;
    always #4  clk_100m = ~clk_100m; // App Clock
    always #10 clk_50m  = ~clk_50m;  // RMII Clock

    logic [1:0] loop_data;
    logic       loop_en;

    logic [7:0] tx_tdata; logic tx_tvalid = 0, tx_tready = 0, tx_tlast = 0;
    logic [7:0] rx_tdata; logic rx_tvalid = 0, rx_tready = 0, rx_tlast = 0;

    eth_mac_axi_top dut (
        .clk_50M_i(clk_50m), .rstn_500M_i(rstn),
        .rmii_txd_o(loop_data), .rmii_tx_en_o(loop_en),
        .rmii_rxd_i(loop_data), .rmii_crs_dv_i(loop_en), .rmii_rxer_i(1'b0),
        .s_axis_clk(clk_100m), .s_axis_resetn(rstn),
        .s_axis_tdata(tx_tdata), .s_axis_tvalid(tx_tvalid),
        .s_axis_tready(tx_tready), .s_axis_tlast(tx_tlast),
        .m_axis_clk(clk_100m), .m_axis_resetn(rstn),
        .m_axis_tdata(rx_tdata), .m_axis_tvalid(rx_tvalid),
        .m_axis_tready(rx_tready), .m_axis_tlast(rx_tlast), .m_axis_tuser()
    );

    logic [7:0] frame1 [0:59] = '{8'h00, 8'h1A, 8'h2B, 8'h3C, 8'h4D, 8'h5E, 8'h00, 8'h0E, 8'h7F, 8'h5F, 8'hF1, 8'hDF, 8'h08, 8'h06, 8'h00, 8'h01, 8'h08, 8'h00, 8'h06, 8'h04, 8'h00, 8'h01, 8'h00, 8'h0E, 8'h7F, 8'h5F, 8'hF1, 8'hDF, 8'hC0, 8'hA8, 8'h01, 8'h84, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'hC0, 8'hA8, 8'h01, 8'h41, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'HEA};
    logic [7:0] frame2 [0:63] = '{8'h00, 8'h1A, 8'h2B, 8'h3C, 8'h4D, 8'h5E, 8'h00, 8'h0E, 8'hCD, 8'h5F, 8'hF1, 8'hDF, 8'h08, 8'h06, 8'h00, 8'h01, 8'h08, 8'h00, 8'hFF, 8'h04, 8'h00, 8'h01, 8'h00, 8'hAA, 8'h7F, 8'h5F, 8'hEE, 8'hDF, 8'hC0, 8'hA8, 8'h01, 8'h84, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'hC0, 8'hA8, 8'h01, 8'h41, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'hDA, 8'h00, 8'hEE, 8'hAA, 8'h00, 8'h00, 8'hDA, 8'h00, 8'hBB, 8'hBC};

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_eth_mac_axi);

        rstn = 0; #200 rstn = 1;

        fork
            begin // TX Thread
                send_axis(60, frame1);
                #2000;
                send_axis(64, frame2);
            end
            begin // RX Thread
                receive_axis(60, frame1);
                $display("FINISH FRAME 1.");
                receive_axis(64, frame2);
                $display("FINISH FRAME 2");
                $finish;
            end
        join_any
    end

    task send_axis(input int len, input logic [7:0] pkt []);
        for (int i=0; i<len; i++) begin
            @(negedge clk_100m);
            tx_tdata  <= pkt[i]; 
            tx_tvalid <= 1'b1; 
            tx_tlast  <= (i == len-1);
            @(posedge clk_100m);
            while (!tx_tready) begin
                @(negedge clk_100m);
            end
        end
        @(negedge clk_100m); tx_tvalid <= 0; tx_tlast <= 0;
    endtask

    initial begin
        // Watchdog: Force stop if simulation exceeds 1ms of virtual time
        #1ms;
        $display("ERROR: Simulation Watchdog Timeout!");
        $fatal;
    end

    
    task automatic receive_axis(input int len, input logic [7:0] exp []);

        logic done;
        int k;
        k = 0;
        done = 0;
        rx_tready <= 1;
        while (!done) begin
            @(posedge clk_100m);
            if (rx_tvalid && rx_tready) begin

                if (rx_tdata !== exp[k]) begin
                    $display("[%0t] ERR: Byte %0d mismatch! Exp:%h Got:%h", $time, k, exp[k], rx_tdata);
                end
                
                if (rx_tlast) begin
                    $display("[%0t] RX: TLAST detected. Packet complete. Total bytes: %0d", $time, k+1);
                    done = 1'b1;
                end
                
                k++;
            end
        end
        
        rx_tready <= 0;
    endtask
    
endmodule
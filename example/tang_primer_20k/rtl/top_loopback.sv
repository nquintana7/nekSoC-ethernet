`timescale 1ns/1ps

module top_loopback (
    // --- Physical RMII Pins ---
    input  logic        rst,       // Active-low reset
    input  logic        netrmii_clk50m,
    output logic        phyrst,
    output logic [1:0]  netrmii_txd,
    output logic        netrmii_txen,
    input  logic        netrmii_rx_crs,
    input  logic [1:0]  netrmii_rxd,
    output logic        netrmii_mdc,
    inout  logic        netrmii_mdio
);

    // --- Reset Generation ---
    assign phyrst = rst;

    assign netrmii_mdc  = 1'b0;
    assign netrmii_mdio = 1'bz;

    // --- System Configuration Constants ---
    logic [31:0] local_ip  = {8'd192, 8'd168, 8'd1, 8'd10};
    logic [47:0] local_mac = 48'h00_1A_2B_3C_4D_5E;
    logic [15:0] local_port = 16'd5005;

    // --- AXI-Stream Signals ---
    logic        app_tx_tvalid, app_tx_tlast, app_tx_tready;
    logic [7:0]  app_tx_tdata;
    logic [79:0] app_tx_tuser;
    logic        pkt_drop;

    logic        app_rx_tready, app_rx_tvalid, app_rx_tlast;
    logic [7:0]  app_rx_tdata;
    logic [47:0] app_rx_tuser;

    logic clk125;

    Gowin_rPLL pll(
       .clkout(clk125),
       .clkin(netrmii_clk50m)
    );

    // --- Instantiate Ethernet Stack ---
    eth_stack_top u_eth_stack (
        .clk_i         (clk125),
        .rstn_i        (rst),
        .clk_50M_i     (netrmii_clk50m),
        .rstn_500M_i   (rst),
        .local_ip_i    (local_ip),
        .local_mac_i   (local_mac),
        .rmii_txd_o    (netrmii_txd),
        .rmii_tx_en_o  (netrmii_txen),
        .rmii_rxd_i    (netrmii_rxd),
        .rmii_crs_dv_i (netrmii_rx_crs),
        .rmii_rxer_i   (1'b0),

        .app_tx_tdata  (app_tx_tdata),
        .app_tx_tvalid (app_tx_tvalid),
        .app_tx_tlast  (app_tx_tlast),
        .app_tx_tuser  (app_tx_tuser),
        .app_tx_tready (app_tx_tready),
        .pkt_drop_o    (pkt_drop),

        .app_rx_tready (app_rx_tready),
        .app_rx_tdata  (app_rx_tdata),
        .app_rx_tvalid (app_rx_tvalid),
        .app_rx_tlast  (app_rx_tlast),
        .app_rx_tuser  (app_rx_tuser),
        
        .port_en_i     (1'b1),
        .port_o        ()
    );

    // Payload FIFO (9-bit width: 8-bit data + 1-bit tlast)
    logic       payload_wfull, payload_walmost_full, payload_empty;
    logic       payload_wen, payload_rden;
    logic [8:0] payload_din, payload_dout;

    fifo_async #(
        .DATA_WIDTH(9),
        .ADDR_WIDTH(11)
    ) u_payload_fifo (
        .wclk_i(clk125), .wrstn_i(rst), .wen_i(payload_wen), .din_i(payload_din),
        .wfull(payload_wfull), .walmost_full(payload_walmost_full),
        .rclk_i(clk125), .rrstn_i(rst), .rden_i(payload_rden), .dout_o(payload_dout),
        .empty_o(payload_empty)
    );

    // Metadata FIFO (80-bit width: TX tuser header info)
    logic        meta_wfull, meta_walmost_full, meta_empty;
    logic        meta_wen, meta_rden;
    logic [79:0] meta_din, meta_dout;

    fifo_async #(
        .DATA_WIDTH(80),
        .ADDR_WIDTH(5)  // Depth: 32 (Can track 32 in-flight packets)
    ) u_meta_fifo (
        .wclk_i(clk125), .wrstn_i(rst), .wen_i(meta_wen), .din_i(meta_din),
        .wfull(meta_wfull), .walmost_full(meta_walmost_full),
        .rclk_i(clk125), .rrstn_i(rst), .rden_i(meta_rden), .dout_o(meta_dout),
        .empty_o(meta_empty)
    );


    logic [15:0] rx_pkt_len;

    // Throttle reception if either FIFO is nearing capacity
    assign app_rx_tready = !payload_walmost_full && !meta_walmost_full;

    assign payload_wen = app_rx_tvalid && app_rx_tready;
    assign payload_din = {app_rx_tlast, app_rx_tdata};

    always_ff @(posedge clk125) begin
        if (!rst) begin
            rx_pkt_len <= '0;
            meta_wen   <= 1'b0;
            meta_din   <= '0;
        end else begin
            meta_wen <= 1'b0; // Default to zero

            if (payload_wen) begin
                rx_pkt_len <= rx_pkt_len + 16'd1;

                // When a packet completes, construct the TX header and push to Meta FIFO
                if (app_rx_tlast) begin
                    meta_wen <= 1'b1;
                    meta_din <= {
                        app_rx_tuser[47:16], // Route Back: Dest IP = Sender's IP
                        local_port,          // Route Back: Src Port = Our local port
                        app_rx_tuser[15:0],  // Route Back: Dest Port = Sender's Port
                        rx_pkt_len + 16'd1   // Payload Length
                    };
                    rx_pkt_len <= '0; // Reset length for next packet
                end
            end
        end
    end

    typedef enum logic [1:0] {TX_IDLE, TX_POP_META, TX_LOAD_META, TX_STREAM} tx_state_t;
    tx_state_t tx_state;

    logic [15:0] tx_bytes_left;
    logic        rden_q;
    logic        pipeline_en;
    assign pipeline_en = !app_tx_tvalid || app_tx_tready;

    assign payload_rden = (tx_state == TX_STREAM) && (tx_bytes_left > 0) && pipeline_en;

    always_ff @(posedge clk125) begin
        if (!rst) begin
            tx_state      <= TX_IDLE;
            meta_rden     <= 1'b0;
            rden_q        <= 1'b0;
            app_tx_tvalid <= 1'b0;
            app_tx_tlast  <= 1'b0;
            app_tx_tdata  <= '0;
            app_tx_tuser  <= '0;
            tx_bytes_left <= '0;
        end else begin
            meta_rden <= 1'b0; // Default

            if (pipeline_en) begin
                rden_q        <= payload_rden;
                app_tx_tvalid <= rden_q;
                app_tx_tdata  <= payload_dout[7:0];
                app_tx_tlast  <= payload_dout[8];
            end

            case (tx_state)
                TX_IDLE: begin
                    if (!meta_empty) begin
                        meta_rden <= 1'b1;
                        tx_state  <= TX_POP_META;
                    end
                end

                TX_POP_META: begin

                    tx_state <= TX_LOAD_META;
                end

                TX_LOAD_META: begin
                    app_tx_tuser  <= meta_dout;
                    tx_bytes_left <= meta_dout[15:0]; 
                    tx_state      <= TX_STREAM;
                end

                TX_STREAM: begin
                    if (payload_rden) begin
                        tx_bytes_left <= tx_bytes_left - 1'b1;
                    end

                    if ((tx_bytes_left == 0) && !rden_q && pipeline_en) begin
                        tx_state <= TX_IDLE;
                    end
                end
            endcase
        end
    end
endmodule
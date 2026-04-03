// Loopback test
module rmii_udp_loopback_top (
    // --- Physical RMII Pins - --
    input  logic        rst,
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
    logic [7:0] rst_cnt = 0;

    assign phyrst = rst; // Release PHY reset when system is ready

    // Tie off unused MDIO interface
    assign netrmii_mdc  = 1'b0;
    assign netrmii_mdio = 1'bz;

    // --- System Configuration Constants ---
    logic [31:0] local_ip  = {8'd192, 8'd168, 8'd1, 8'd10}; // 192.168.1.10
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

    logic        port_en;
    logic [15:0] listen_port;

    logic clk125;

   Gowin_rPLL your_instance_name(
       .clkout(clk125), //output clkout
       .clkin(netrmii_clk50m) //input clkin
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
        .rmii_rxer_i   (1'b0), // Tied to 0 (not mapped in your CST)

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
    logic [31:0] rx_pkt_cnt;
    logic [31:0] tx_pkt_cnt;
    
    // Track completed RX and TX packet transfers using the AXI-Stream handshake
    always_ff @(posedge clk125) begin
        if (!rst) begin
            rx_pkt_cnt <= '0;
            tx_pkt_cnt <= '0;
        end else begin

            if (app_rx_tvalid && app_rx_tready && app_rx_tlast) begin
                rx_pkt_cnt <= rx_pkt_cnt + 1'b1;
            end
            
            if (app_tx_tvalid && app_tx_tready && app_tx_tlast) begin
                tx_pkt_cnt <= tx_pkt_cnt + 1'b1;
            end
        end
    end

    // --- UDP Store-and-Forward Loopback Logic ---
    typedef enum logic [1:0] {IDLE, RX_PKT, TX_PKT} state_t;
    state_t state;

    logic [7:0]  pkt_buffer [0:2047]; // 2KB buffer for MTU
    logic [10:0] rx_ptr;
    logic [10:0] tx_ptr;
    logic [10:0] pkt_length;
    logic [47:0] saved_rx_tuser;

    assign app_rx_tready = (state == IDLE) || (state == RX_PKT);

    always_ff @(posedge clk125) begin
        if (!rst) begin
            state         <= IDLE;
            app_tx_tvalid <= 1'b0;
            app_tx_tlast  <= 1'b0;
            rx_ptr        <= '0;
            tx_ptr        <= '0;
        end else begin
            case (state)
                IDLE: begin
                    rx_ptr <= '0;
                    if (app_rx_tvalid && app_rx_tready) begin
                        pkt_buffer[rx_ptr]  <= app_rx_tdata;
                        saved_rx_tuser <= app_rx_tuser; // Capture {Source IP, Source Port}
                        rx_ptr         <= 11'd1;
                        state          <= app_rx_tlast ? TX_PKT : RX_PKT;
                        pkt_length     <= app_rx_tlast ? 11'd1 : '0;
                    end
                end

                RX_PKT: begin
                    if (app_rx_tvalid && app_rx_tready) begin
                        pkt_buffer[rx_ptr] <= app_rx_tdata;
                        rx_ptr             <= rx_ptr + 11'd1;
                        if (app_rx_tlast) begin
                            pkt_length <= rx_ptr + 11'd1;
                            state      <= TX_PKT;
                            tx_ptr     <= '0;
                        end
                    end
                end

                TX_PKT: begin
                    app_tx_tvalid <= 1'b1;
                    app_tx_tdata  <= pkt_buffer[tx_ptr];
                    app_tx_tlast  <= (tx_ptr == (pkt_length - 11'd1));
                    
                    // Route back to sender: [Dest IP (32), Src Port (16), Dest Port (16), Length (16)]
                    app_tx_tuser  <= {
                        saved_rx_tuser[47:16], // Dest IP = Sender's IP
                        local_port,              // Src Port = Our local port
                        saved_rx_tuser[15:0],  // Dest Port = Sender's Port
                        16'(pkt_length)        // Payload Length
                    };

                    if (app_tx_tready && app_tx_tvalid) begin
                        if (app_tx_tlast) begin
                            app_tx_tvalid <= 1'b0;
                            app_tx_tlast  <= 1'b0;
                            state         <= IDLE;
                        end else begin
                            tx_ptr <= tx_ptr + 11'd1;
                        end
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
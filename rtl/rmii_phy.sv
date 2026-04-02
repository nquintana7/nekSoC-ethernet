module rmii_phy (
    input logic clk_i,
    input logic rstn_i,
    
    // PHY Interface
    input logic [1:0] rxd_i,
    input logic crs_dv,
    input logic rxer_i,

    output logic [1:0] txd_o,
    output logic txen_o,

    // MAC Interface
    input logic [7:0] tx_byte_i,
    input logic tx_byte_valid_i,
    input logic tx_last_byte_i,
    output logic tx_ready_o,

    output logic [7:0] rx_byte_o,
    output logic rx_byte_valid_o,
    output logic byte_error_o,
    output logic rx_active_o
);

    logic [7:0] rx_shift_reg;
    logic [1:0] rx_cnt;
    logic frame_error;
    logic sfd_locked;

    logic [7:0] tx_shift_reg;
    logic [1:0] tx_cnt;
    logic last_byte;

    assign byte_error_o = frame_error & rx_byte_valid_o;

    logic rx_is_active;
    logic crs_dv_d;

    assign rx_is_active = crs_dv | crs_dv_d;

    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) crs_dv_d <= 1'b0;
        else crs_dv_d <= crs_dv;
    end

    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i | !rx_is_active) begin
            rx_shift_reg <= 8'd0;
            rx_byte_valid_o <= 1'b0;
            rx_cnt <= 2'd0;
            frame_error <= 1'b0;
            rx_active_o <= 1'b0;
            sfd_locked <= 1'b0;
            rx_byte_o <= 8'd0;
        end else begin
            rx_active_o <= 1'b1;
            rx_shift_reg <= {rxd_i, rx_shift_reg[7:2]};
            
            if (rxer_i) frame_error <= 1'b1;

            if (!sfd_locked) begin

                if ({rxd_i, rx_shift_reg[7:2]} == 8'hD5) begin
                    sfd_locked <= 1'b1;
                    rx_byte_o <= 8'hD5;
                    rx_byte_valid_o <= 1'b1;
                    rx_cnt <= 2'd0;
                end else begin
                    rx_byte_valid_o <= 1'b0; 
                end
            end else begin

                rx_cnt <= rx_cnt + 2'd1;
                if (rx_cnt == 2'd3) begin
                    rx_byte_o <= {rxd_i, rx_shift_reg[7:2]};
                    rx_byte_valid_o <= 1'b1;
                end else begin
                    rx_byte_valid_o <= 1'b0;
                end
            end
            
        end
    end

    // TX Logic 
    assign txd_o = tx_shift_reg[1:0]; 
    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            tx_shift_reg <= '0;
            txen_o <= 1'b0;
            tx_cnt <= 2'd0;
            last_byte <= 1'b0;
            tx_ready_o <= 1'b1;
        end else begin
            tx_cnt <= tx_cnt + 1;
            if (tx_cnt == 2'd0 && tx_byte_valid_i) begin
                tx_shift_reg <= tx_byte_i;
                txen_o <= 1'b1;
                tx_ready_o <= 1'b0;
                last_byte <= tx_last_byte_i;
            end else begin
                tx_shift_reg <= {2'd0, tx_shift_reg[7:2]};
                tx_ready_o <= (tx_cnt == 2'd2) ? 1'b1 : 1'b0;
            end
            if (tx_cnt == 2'd0 && last_byte) begin
                txen_o <= 1'b0;
                last_byte <= 1'b0;
            end
        end
    end
endmodule
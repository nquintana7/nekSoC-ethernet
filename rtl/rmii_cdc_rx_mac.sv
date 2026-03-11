module rmii_cdc_rx_mac (
    input  logic       clk_i,
    input  logic       rstn_i,

    input  logic [7:0] phy_rx_data_i,
    input  logic       phy_rx_dv_i,
    input  logic       phy_rx_active_i,
    input  logic       phy_rx_err_i,

    output logic [7:0] mac_data_o,
    output logic       mac_dv_o, 
    output logic       mac_active_o,
    output logic       mac_err_o
);
    logic       phy_rx_active_ff, phy_rx_active_ff2;
    logic       last_dv_ff, dv_ff,   dv_ff2;

    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            dv_ff     <= 1'b0;
            dv_ff2     <= 1'b0;
            phy_rx_active_ff <= 1'b0;
            phy_rx_active_ff2 <= 1'b0;    
            last_dv_ff <= 1'b0;
        end else begin
            dv_ff     <= phy_rx_dv_i;
            dv_ff2     <= dv_ff;
            last_dv_ff <= dv_ff2;
            phy_rx_active_ff <= phy_rx_active_i;
            phy_rx_active_ff2 <= phy_rx_active_ff;   
        end
    end

    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            mac_dv_o <= 1'b0;
            mac_active_o <= 1'b0;
            mac_err_o <= 1'b0;
            mac_data_o <= '0;
        end else if (dv_ff2) begin
            mac_data_o   <= phy_rx_data_i;
            mac_dv_o     <= dv_ff2 & !last_dv_ff;
            mac_active_o <= phy_rx_active_ff2;
            mac_err_o    <= phy_rx_err_i;
        end else begin
            mac_dv_o     <= 1'b0;
            mac_active_o <= phy_rx_active_ff2; 
        end
    end

endmodule
`timescale 1ns / 1ps

module axis_skid_buffer #(
    parameter int USER_WIDTH = 48
)(
    input  logic                  clk,
    input  logic                  rstn,

    input  logic [7:0]            s_axis_tdata,
    input  logic [USER_WIDTH-1:0] s_axis_tuser,
    input  logic                  s_axis_tlast,
    input  logic                  s_axis_tvalid,
    output logic                  s_axis_tready,
    output logic [7:0]            m_axis_tdata,
    output logic [USER_WIDTH-1:0] m_axis_tuser,
    output logic                  m_axis_tlast,
    output logic                  m_axis_tvalid,
    input  logic                  m_axis_tready
);

    logic [7:0]            data_reg [2];
    logic [USER_WIDTH-1:0] user_reg [2];
    logic                  last_reg [2];
    
    logic       wr_ptr;
    logic       rd_ptr;
    logic [1:0] count;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            wr_ptr <= 1'b0;
            rd_ptr <= 1'b0;
            count  <= 2'b00;
        end else begin
            logic s_fire;
            logic m_fire;
            
            s_fire = s_axis_tvalid && s_axis_tready;
            m_fire = m_axis_tvalid && m_axis_tready;

            if (s_fire && !m_fire) begin
                // Write only: Fill a slot, increment count
                data_reg[wr_ptr] <= s_axis_tdata;
                user_reg[wr_ptr] <= s_axis_tuser;
                last_reg[wr_ptr] <= s_axis_tlast;
                wr_ptr           <= ~wr_ptr;
                count            <= count + 2'd1;
                
            end else if (!s_fire && m_fire) begin
                // Read only: Empty a slot, decrement count
                rd_ptr           <= ~rd_ptr;
                count            <= count - 2'd1;
                
            end else if (s_fire && m_fire) begin
                // Simultaneous read and write: Data flows, count remains unchanged
                data_reg[wr_ptr] <= s_axis_tdata;
                user_reg[wr_ptr] <= s_axis_tuser;
                last_reg[wr_ptr] <= s_axis_tlast;
                wr_ptr           <= ~wr_ptr;
                rd_ptr           <= ~rd_ptr;
            end
        end
    end
    
    assign s_axis_tready = (count < 2'd2);
    
    assign m_axis_tvalid = (count > 2'd0);
    
    assign m_axis_tdata  = data_reg[rd_ptr];
    assign m_axis_tuser  = user_reg[rd_ptr];
    assign m_axis_tlast  = last_reg[rd_ptr];

endmodule
`timescale 1ns/1ps

module Gowin_rPLL (
    output logic clkout,
    input  logic clkin
);
    initial begin
        clkout = 1'b0;
    end

    // 125 MHz = 8 ns period. 
    // Toggle every 4 ns to create a 50% duty cycle.
    always #4 clkout = ~clkout;

endmodule
module Gowin_rPLL (
    output logic clkout,
    input  logic clkin
);

    // 125 MHz clock generation
    // Frequency: 125 MHz -> Period: 8 ns -> Half-Period: 4 ns
    initial begin
        clkout = 0;
    end

    // Toggle the output clock every 4ns
    always #4 clkout = ~clkout;

    // Note: In a real PLL, clkout is phase-locked to clkin.
    // For testing an Ethernet UDP loopback, FPGAs use asynchronous 
    // FIFOs to cross the 50MHz RMII and 125MHz App domains, 
    // so phase alignment in simulation is rarely strictly necessary.

endmodule
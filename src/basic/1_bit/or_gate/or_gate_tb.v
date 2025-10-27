// Testbench for OR gate module
// This testbench verifies the functionality of the OR gate

`timescale 1ns/1ps

module or_gate_tb;

    // Testbench signals
    reg a, b;           // Inputs (reg type for testbench)
    wire y;             // Output (wire type)

    // Instantiate the Device Under Test (DUT)
    or_gate dut (
        .a(a),
        .b(b),
        .y(y)
    );

    // Generate VCD file for waveform viewing
    initial begin
        $dumpfile("build/waveform.vcd");
        $dumpvars(0, or_gate_tb);
    end

    // Test stimulus
    initial begin
        // Display header
        $display("Time\ta\tb\ty\t| 4bit_in");
        $display("----\t-\t-\t-\t| -------");
        
        // Test all combinations for 2-input OR gate
        a = 0; b = 0; #10;
        $display("%4t\t%b\t%b\t%b", $time, a, b, y);

        a = 0; b = 1; #10;
        $display("%4t\t%b\t%b\t%b", $time, a, b, y);

        a = 1; b = 0; #10;
        $display("%4t\t%b\t%b\t%b", $time, a, b, y);

        a = 1; b = 1; #10;
        $display("%4t\t%b\t%b\t%b", $time, a, b, y);
    end

    // Monitor changes (optional)
    initial begin
        $monitor("At time %t: a=%b, b=%b, y=%b", $time, a, b, y);
    end

endmodule

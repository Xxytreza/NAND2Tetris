// Testbench for AND gate module
// This testbench verifies the functionality of the AND gate

`timescale 1ns/1ps

module xor_gate_tb;

    // Testbench signals
    reg a, b;           // Inputs (reg type for testbench)
    wire y;             // Output (wire type)

    // Instantiate the Device Under Test (DUT)
    xor_gate dut (
        .a(a),
        .b(b),
        .y(y)
    );

    // Test stimulus
    initial begin
        // Waveform dump
        $dumpfile({`BUILD_DIR, "/xor_gate_tb.vcd"});        
        $dumpvars(0, xor_gate_tb);

        // Display header
        $display("Time\ta\tb\ty\t| 4bit_in");
        $display("----\t-\t-\t-\t| -------");

        // Test all combinations for 2-input XOR gate
        a = 0; b = 0; #10;
        $display("%4t\t%b\t%b\t%b", $time, a, b, y);

        a = 0; b = 1; #10;
        $display("%4t\t%b\t%b\t%b", $time, a, b, y);

        a = 1; b = 0; #10;
        $display("%4t\t%b\t%b\t%b", $time, a, b, y);

        a = 1; b = 1; #10;
        $display("%4t\t%b\t%b\t%b", $time, a, b, y);

        $finish; // End simulation
    end

endmodule

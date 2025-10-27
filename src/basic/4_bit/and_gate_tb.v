// Testbench for AND gate module
// This testbench verifies the functionality of the AND gate

`timescale 1ns/1ps

module and_gate_tb;

    // Testbench signals
    reg a, b;           // Inputs (reg type for testbench)
    wire y;             // Output (wire type)
    
    // Signals for 4-bit AND gate test
    reg [3:0] inputs_4bit;
    wire result_4bit;

    // Instantiate the Device Under Test (DUT)
    and_gate dut (
        .a(a),
        .b(b),
        .y(y)
    );
    
    // Instantiate 4-bit AND gate
    and_gate_4bit dut_4bit (
        .inputs(inputs_4bit),
        .result(result_4bit)
    );

    // Generate VCD file for waveform viewing
    initial begin
        $dumpfile("build/waveform.vcd");
        $dumpvars(0, and_gate_tb);
    end

    // Test stimulus
    initial begin
        // Display header
        $display("Time\ta\tb\ty\t| 4bit_in\t4bit_out");
        $display("----\t-\t-\t-\t| -------\t--------");
        
        // Test all combinations for 2-input AND gate
        a = 0; b = 0; inputs_4bit = 4'b0000; #10;
        $display("%4t\t%b\t%b\t%b\t| %4b\t\t%b", $time, a, b, y, inputs_4bit, result_4bit);
        
        a = 0; b = 1; inputs_4bit = 4'b0001; #10;
        $display("%4t\t%b\t%b\t%b\t| %4b\t\t%b", $time, a, b, y, inputs_4bit, result_4bit);
        
        a = 1; b = 0; inputs_4bit = 4'b1010; #10;
        $display("%4t\t%b\t%b\t%b\t| %4b\t\t%b", $time, a, b, y, inputs_4bit, result_4bit);
        
        a = 1; b = 1; inputs_4bit = 4'b1111; #10;
        $display("%4t\t%b\t%b\t%b\t| %4b\t\t%b", $time, a, b, y, inputs_4bit, result_4bit);
        
        // Additional test cases for 4-bit AND
        inputs_4bit = 4'b1110; #10;
        $display("%4t\t%b\t%b\t%b\t| %4b\t\t%b", $time, a, b, y, inputs_4bit, result_4bit);
        
        inputs_4bit = 4'b1101; #10;
        $display("%4t\t%b\t%b\t%b\t| %4b\t\t%b", $time, a, b, y, inputs_4bit, result_4bit);

        // Finish simulation
        $display("\nSimulation completed successfully!");
        $finish;
    end

    // Monitor changes (optional)
    initial begin
        $monitor("At time %t: a=%b, b=%b, y=%b", $time, a, b, y);
    end

endmodule

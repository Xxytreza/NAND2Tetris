`timescale 1ns/1ps

module bit_adder_1_tb;

    reg a, b;
    wire sum, carry;

    bit_adder_1 dut (
        .a(a),
        .b(b),
        .sum(sum),
        .carry(carry)
    );

    // Combine VCD setup with stimulus
    initial begin
        // Waveform dump
        $dumpfile("build/waves/bit_adder_1_tb.vcd");
        $dumpvars(0, bit_adder_1_tb);

        // Header
        $display("Time\ta\tb\tsum\tcarry");
        $display("----\t-\t-\t---\t-----");

        // Stimulus
        a = 0; b = 0; #10;
        $display("%4t\t%b\t%b\t%b\t%b", $time, a, b, sum, carry);

        a = 0; b = 1; #10;
        $display("%4t\t%b\t%b\t%b\t%b", $time, a, b, sum, carry);

        a = 1; b = 0; #10;
        $display("%4t\t%b\t%b\t%b\t%b", $time, a, b, sum, carry);

        a = 1; b = 1; #10;
        $display("%4t\t%b\t%b\t%b\t%b", $time, a, b, sum, carry);

        $finish; // Finish simulation
    end

endmodule

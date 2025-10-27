`timescale 1ns/1ps

module bit_adder_32_tb;

    reg [31:0] a, b;
    wire [31:0] sum;

    bit_adder_32 dut (
        .a(a),
        .b(b),
        .sum(sum)
    );

    // Combine VCD setup with stimulus
    initial begin
        // Waveform dump
        $dumpfile("build/waves/bit_adder_32_tb.vcd");
        $dumpvars(0, bit_adder_32_tb);

        // Header
        $display("Time\ta\tb\tsum");
        $display("----\t-\t-\t---");

        // Stimulus
        a = 0; b = 0; #10;
        $display("%4t\t%d\t%d\t%d", $time, a, b, sum);

        a = 0; b = 14; #10;
        $display("%4t\t%d\t%d\t%d", $time, a, b, sum);

        a = 5; b = 26; #10;
        $display("%4t\t%d\t%d\t%d", $time, a, b, sum);

        a = 999; b = 120; #10;
        $display("%4t\t%d\t%d\t%d", $time, a, b, sum);

        $finish; // Finish simulation
    end

endmodule

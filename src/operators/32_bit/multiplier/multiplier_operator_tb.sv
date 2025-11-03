`timescale 1ns/1ps

module bit_multiplier_32_tb;

    reg signed [31:0] a, b;
    wire signed [31:0] product;

    bit_multiplier_32 dut (
        .a(a),
        .b(b),
        .product(product)
    );

    // Combine VCD setup with stimulus
    initial begin
        // Waveform dump
        $dumpfile("build/waves/bit_multiplier_32_tb.vcd");
        $dumpvars(0, bit_multiplier_32_tb);

        // Header
        $display("Time\ta\tb\tproduct");
        $display("----\t-\t-\t-------");

        // Stimulus
        a = 2; b = 1; #10;
        $display("%4t\t%d\t%d\t%d", $time, a, b, product);

        a = 6; b = 7; #10;
        $display("%4t\t%d\t%d\t%d", $time, a, b, product);

        a = 12; b = 12; #10;
        $display("%4t\t%d\t%d\t%d", $time, a, b, product);

        a = 999; b = 999; #10;
        $display("%4t\t%d\t%d\t%d", $time, a, b, product);

        a = -2_147_483_648; b = -1; #10;
        $display("%4t\t%d\t%d\t%d", $time, a, b, product);


        $finish; // Finish simulation
    end

endmodule

`timescale 1ns/1ps

module cpu_wrapper_vector #(parameter int MAX_N = 128);

    reg clk = 0;
    reg [7:0] opcode;
    reg [31:0] n;
    reg [MAX_N-1:0][31:0] a, b;
    reg [MAX_N-1:0][31:0] result;
    wire done;

    // Instantiate CPU
    cpu_main_vector #(.MAX_N(MAX_N)) cpu(
        .clk(clk),
        .opcode(opcode),
        .n(n),
        .a(a),
        .b(b),
        .result(result),
        .done(done)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        // Read values from command line plusargs
        if (!$value$plusargs("opcode=%h", opcode)) opcode = 0;
        if (!$value$plusargs("n=%d", n)) n = 0;
        if (!$value$plusargs("a=%d", a)) a = 0;
        if (!$value$plusargs("b=%d", b)) b = 0;

        // Wait a few ns for combinational logic
        #10;

        // Print result in a single line for Python
        $display("Result=%d", result);

        $finish;
    end

endmodule

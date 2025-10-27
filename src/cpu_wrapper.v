`timescale 1ns/1ps

module cpu_wrapper;

    reg clk = 0;
    reg [7:0] opcode;
    reg [31:0] a, b;
    wire [31:0] result;
    wire done;

    // Instantiate CPU
    cpu_main cpu(
        .clk(clk),
        .opcode(opcode),
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
        if (!$value$plusargs("a=%d", a)) a = 0;
        if (!$value$plusargs("b=%d", b)) b = 0;

        // Wait a few ns for combinational logic
        #10;

        // Print result in a single line for Python
        $display("Result=%d", result);

        $finish;
    end

endmodule

// Simple 2-input 32_bit adder module

module bit_adder_32 (
    input wire [31:0] a,      // First input
    input wire [31:0] b,      // Second input
    output wire [31:0] sum    // Sum output
);

    assign sum = a + b;      // Sum calculation

endmodule
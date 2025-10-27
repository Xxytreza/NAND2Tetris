// Simple 2-input 32_bit multiplier module

module bit_multiplier_32 (
    input wire [31:0] a,      // First input
    input wire [31:0] b,      // Second input
    output wire [31:0] product // Product output
);

    assign product = a * b;   // Product calculation

endmodule
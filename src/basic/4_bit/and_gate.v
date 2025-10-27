// Simple 2-input AND gate module
// This is a basic Verilog module demonstrating combinational logic

module and_gate (
    input wire a,      // First input
    input wire b,      // Second input
    output wire y      // Output
);

    // AND gate logic
    assign y = a & b;

endmodule

// Additional example: 4-input AND gate
module and_gate_4bit (
    input wire [3:0] inputs,    // 4-bit input vector
    output wire result          // Single bit output
);

    // AND all 4 bits together
    assign result = &inputs;    // Reduction AND operator

endmodule

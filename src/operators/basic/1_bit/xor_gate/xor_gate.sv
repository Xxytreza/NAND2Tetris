// Simple 2-input XOR gate module
// This is a basic Verilog module demonstrating combinational logic

module xor_gate (
    input wire a,      // First input
    input wire b,      // Second input
    output wire y      // Output
);

    // XOR gate logic
    assign y = a ^ b;

endmodule
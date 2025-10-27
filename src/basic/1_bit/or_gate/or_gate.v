// Simple 2-input OR gate module
// This is a basic Verilog module demonstrating combinational logic

module or_gate (
    input wire a,      // First input
    input wire b,      // Second input
    output wire y      // Output
);

    // OR gate logic
    assign y = a | b;

endmodule
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
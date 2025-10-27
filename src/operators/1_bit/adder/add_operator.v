// Simple 2-input 1_bit adder module

module one_bit_adder (
    input wire a,      // First input
    input wire b,      // Second input
    output wire sum,   // Sum output
    output wire carry  // Carry output
);

    xor_gate u_xor (
        .a(a),
        .b(b),
        .y(sum_internal)
    );

    // Instantiate AND gate for carry
    and_gate u_and (
        .a(a),
        .b(b),
        .y(carry_internal)
    );

    // Full adder logic
    assign sum = sum_internal;
    assign carry = carry_internal;

endmodule
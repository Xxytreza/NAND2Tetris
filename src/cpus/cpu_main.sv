`timescale 1ns/1ps

module cpu_main(
    input        clk,
    input  [7:0] opcode,       // instruction code
    input  [31:0] a, b,        // operands
    output reg [31:0] result,
    output reg done            // high when computation finishes
);

    wire [31:0] sum;
    wire [31:0] product;

    // Instantiate operators
    bit_adder_32 adder(.a(a), .b(b), .sum(sum));
    bit_multiplier_32 mult(.a(a), .b(b), .product(product));

    always @(posedge clk) begin
        done <= 0;
        case (opcode)
            8'h01: result <= sum;      // ADD_INTEGER
            8'h02: result <= product;  // MULT_INTEGER
            default: result <= 0;
        endcase
        done <= 1;
    end

endmodule

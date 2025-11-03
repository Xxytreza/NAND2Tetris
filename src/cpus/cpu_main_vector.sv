`timescale 1ns/1ps

module cpu_main_vector #(parameter int MAX_N = 128)(
    input        clk,
    input  [7:0] opcode,       // instruction code
    input  [31:0] n,           // vector length
    input  [MAX_N-1:0][31:0] a, b,        // operands
    output reg [MAX_N-1:0][31:0] result,
    output reg done            // high when computation finishes
);

    wire [MAX_N-1:0][31:0] sum;
    wire [MAX_N-1:0][31:0] product;

    // Instantiate operators
    vect_add_operator #(.MAX_N(MAX_N)) adder(.n(n), .v1(a), .v2(b), .result(sum));
    vect_mult_operator #(.MAX_N(MAX_N)) mult(.n(n), .v1(a), .v2(b), .result(product));

    always @(posedge clk) begin
        done <= 0;
        case (opcode)
            8'h01: result <= sum;      // ADD_VECTOR
            8'h02: result <= product;  // MULT_VECTOR
            default: result <= 0;
        endcase
        done <= 1;
    end

endmodule

`timescale 1ns/1ps

module cpu_main_vector #(parameter int MAX_N = 128)(
    input        clk,
    input  [7:0] opcode,       // instruction code
    input  [31:0] n,           // vector length
    input  [31:0] a [MAX_N-1:0], 
    input  [31:0] b [MAX_N-1:0],        // operands
    output reg [31:0] result [MAX_N-1:0], // result vector
    output reg done            // high when computation finishes
);

    wire [31:0] sum [MAX_N-1:0];
    wire [31:0] product [MAX_N-1:0];

    // Instantiate operators
    vect_add_operator #(.MAX_N(MAX_N)) adder(.n(n), .v1(a), .v2(b), .result(sum));
    vect_mult_operator #(.MAX_N(MAX_N)) mult(.n(n), .v1(a), .v2(b), .result(product));

    integer i;
    always @(posedge clk) begin
        done <= 0;

        case (opcode)
            8'h01: begin  // ADD_VECTOR
                for (i = 0; i < n; i = i + 1) begin
                    result[i] <= sum[i];
                end
            end
            8'h02: begin  // MULT_VECTOR
                for (i = 0; i < n; i = i + 1) begin
                    result[i] <= product[i];
                end
            end
            default: begin
                for (i = 0; i < MAX_N; i = i + 1) begin
                    result[i] <= 0;
                end
            end
        endcase

        done <= 1;
    end

endmodule

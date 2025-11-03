module vect_dot_operator #(
    parameter int MAX_N = 128 
)(
    input wire [31:0] n,
    input wire [MAX_N-1][31:0] v1,
    input wire [MAX_N-1][31:0] v2,
    output reg [31:0] result
);

    always_comb begin 
        result = 32'b0;
        for (int i = 0; i < MAX_N; i++) begin
            if (i < n) begin
                result += v1[i] * v2[i];
            end
        end
    end
endmodule
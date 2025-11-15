module vect_add_operator #(
    parameter int MAX_N = 128
)(
    input wire [31:0] n,
    input wire [31:0] v1 [MAX_N-1:0],
    input wire [31:0] v2 [MAX_N-1:0],
    output reg [31:0] result [MAX_N-1:0]
);

    always_comb begin
        for (int i = 0; i < MAX_N; i++) begin
            if (i < n) begin
                result[i] = v1[i] + v2[i];
            end else begin
                result[i] = 0;
            end
        end
    end
endmodule
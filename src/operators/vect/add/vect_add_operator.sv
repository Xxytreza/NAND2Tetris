module vect_add_operator #(
    parameter int MAX_N = 128
)(
    input wire [31:0] n,
    input wire [MAX_N-1:0][31:0] v1,
    input wire [MAX_N-1:0][31:0] v2,
    output reg [MAX_N-1:0][31:0] result
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
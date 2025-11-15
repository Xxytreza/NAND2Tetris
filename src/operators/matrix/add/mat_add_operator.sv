module mat_add_operator #(
    parameter int MAX_N = 128,
    parameter int MAX_M = 128
)(
    input  wire [31:0] n,
    input  wire [31:0] m,
    input  wire [31:0] m1 [MAX_N-1:0][MAX_M-1:0],
    input  wire [31:0] m2 [MAX_N-1:0][MAX_M-1:0],
    output reg [31:0] result [MAX_N-1:0][MAX_M-1:0]
);
    integer i,j;
    always_comb begin
        for (i=0; i < MAX_N; i=i+1) begin
            for (j=0; j < MAX_M; j=j+1) begin
                result[i][j] = m1[i][j] + m2[i][j];
            end
        end
    end

endmodule

module vect_mult_operator(
    parameter int MAX_N = 128 
)(
    input wire [31:0] n,
    input wire [MAX_N-1][31:0] v1,
    input wire [MAX_N-1][31:0] v2,
    output wire [MAX_N-1][31:0] result
);

    initial begin 
        for (int i = 0; int < MAX_N; i++) begin
            if (i < n) begin
                



    end
endmodule
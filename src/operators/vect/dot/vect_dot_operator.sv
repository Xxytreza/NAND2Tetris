module vect_dot_operator #(
    parameter int MAX_N = 128 
)(
    input wire [31:0] n,
    input wire [31:0] v1 [MAX_N-1:0],
    input wire [31:0] v2 [MAX_N-1:0],
    output reg [31:0] result
);

    always_comb begin 
        logic [31:0] temp_sum;
        temp_sum = 32'b0;
        for (int i = 0; i < MAX_N; i++) begin
            if (i < n) begin
                temp_sum += v1[i] * v2[i];
            end
        end
        result = temp_sum >> 16;
    end
endmodule
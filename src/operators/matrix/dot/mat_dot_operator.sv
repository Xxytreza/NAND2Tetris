module mat_dot_operator #(
    parameter int MAX_M = 128,
    parameter int MAX_N = 128,
    parameter int MAX_O = 128
)(
    input  wire [31:0] m,
    input  wire [31:0] n,
    input  wire [31:0] o,
    
    input  wire [31:0] m1 [MAX_M-1:0][MAX_N-1:0],
    input  wire [31:0] m2 [MAX_N-1:0][MAX_O-1:0],
    output reg [31:0] result [MAX_M-1:0][MAX_O-1:0]
);

    // Temp vectors (1-D) for dot operator
    logic [31:0] Arow [MAX_N-1:0];
    logic [31:0] Bcol [MAX_O-1:0];
    logic [31:0] dot_value;

    // Instantiate vector dot-product unit
    vect_dot_operator #(.MAX_N(MAX_N)) dot_unit (
        .n(n),
        .v1(Arow),
        .v2(Bcol),
        .result(dot_value)
    );

    integer i,j,x;
    always_comb begin
        for (i=0; i < MAX_M; i=i+1) begin
            for (j=0; j < MAX_O; j=j+1) begin

                // Construct row vector
                for (x=0; x<MAX_N; x=x+1)
                    Arow[x] = m1[i][x];

                // Construct column vector
                for (x=0; x<MAX_N; x=x+1)
                    Bcol[x] = m2[x][j];

                // Dot-product output is one scalar
                result[i][j] = dot_value;
            end
        end
    end

endmodule

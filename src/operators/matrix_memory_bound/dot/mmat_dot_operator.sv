module mmat_dot_operator #(
    parameter int MAX_M = 128,
    parameter int MAX_N = 128,
    parameter int MAX_O = 128,
    // block over output matrix
    parameter int BLK_M = 4,   // rows of C per tile
    parameter int BLK_O = 4    // cols of C per tile
)(
    input  wire                 clk,
    input  wire                 rst_n,

    input  wire                 start,
    output reg                  busy,
    output reg                  done,

    input  wire [31:0]          m,   // rows of A / C
    input  wire [31:0]          n,   // inner dimension
    input  wire [31:0]          o,   // cols of B / C

    input  wire [31:0]          m1 [MAX_M-1:0][MAX_N-1:0], // A
    input  wire [31:0]          m2 [MAX_N-1:0][MAX_O-1:0], // B
    output reg  [31:0]          result [MAX_M-1:0][MAX_O-1:0] // C
);

    // tile origins in output matrix C
    integer tile_i; // 0 .. m-1
    integer tile_j; // 0 .. o-1

    // indices within current tile
    integer bi;     // 0 .. eff_blk_m-1
    integer bj;     // 0 .. eff_blk_o-1

    // effective tile size (handles edges)
    integer eff_blk_m;
    integer eff_blk_o;

    // accumulation index along N
    integer k;

    // accumulator for current C[i][j]
    reg [63:0] acc;   // widen if needed; here just a simple 64‑bit sum

    typedef enum logic [2:0] {
        IDLE,
        INIT_TILE,
        INIT_ELEM,
        MAC_LOOP,
        WRITE_ELEM,
        NEXT_ELEM,
        NEXT_TILE,
        DONE
    } state_t;

    state_t state, state_next;

    // effective tile size computation
    always @* begin
        int rem_m = m - tile_i;
        int rem_o = o - tile_j;
        eff_blk_m = (rem_m > BLK_M) ? BLK_M : (rem_m > 0 ? rem_m : 0);
        eff_blk_o = (rem_o > BLK_O) ? BLK_O : (rem_o > 0 ? rem_o : 0);
    end

    // sequential control + datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= IDLE;
            busy    <= 1'b0;
            done    <= 1'b0;
            tile_i  <= 0;
            tile_j  <= 0;
            bi      <= 0;
            bj      <= 0;
            k       <= 0;
            acc     <= 0;
        end
        else begin
            state <= state_next;
            done  <= 1'b0;

            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    if (start && m != 0 && n != 0 && o != 0) begin
                        busy   <= 1'b1;
                        tile_i <= 0;
                        tile_j <= 0;
                    end
                end

                INIT_TILE: begin
                    // prepare to process first element in tile
                    bi  <= 0;
                    bj  <= 0;
                    k   <= 0;
                    acc <= 0;
                end

                INIT_ELEM: begin
                    k   <= 0;
                    acc <= 0;
                end

                MAC_LOOP: begin
                    // one multiply‑accumulate step: acc += A * B
                    acc <= acc + m1[tile_i + bi][k] * m2[k][tile_j + bj];
                    k   <= k + 1;
                end

                WRITE_ELEM: begin
                    // write completed dot product to result
                    result[tile_i + bi][tile_j + bj] <= acc[31:0]; // trunc or round if needed
                end

                NEXT_ELEM: begin
                    // move to next (bi,bj) inside tile
                    if (bj + 1 < eff_blk_o) begin
                        bj  <= bj + 1;
                        k   <= 0;
                        acc <= 0;
                    end
                    else begin
                        bj <= 0;
                        if (bi + 1 < eff_blk_m) begin
                            bi  <= bi + 1;
                            k   <= 0;
                            acc <= 0;
                        end
                    end
                end

                NEXT_TILE: begin
                    // advance tile_j, then tile_i
                    if (tile_j + eff_blk_o < o) begin
                        tile_j <= tile_j + eff_blk_o;
                    end
                    else begin
                        tile_j <= 0;
                        if (tile_i + eff_blk_m < m)
                            tile_i <= tile_i + eff_blk_m;
                    end
                end

                DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // next‑state logic
    always @* begin
        state_next = state;
        case (state)
            IDLE: begin
                if (start && m != 0 && n != 0 && o != 0)
                    state_next = INIT_TILE;
                else if (start)
                    state_next = DONE; // any zero dimension -> trivial
            end

            INIT_TILE:  state_next = INIT_ELEM;

            INIT_ELEM:  state_next = (n > 0) ? MAC_LOOP : WRITE_ELEM;

            MAC_LOOP: begin
                if (k + 1 >= n)  // last MAC
                    state_next = WRITE_ELEM;
            end

            WRITE_ELEM: begin
                // check if more elements remain in current tile
                if ((bi + 1 < eff_blk_m) || (bj + 1 < eff_blk_o))
                    state_next = NEXT_ELEM;
                else
                    state_next = NEXT_TILE;
            end

            NEXT_ELEM:  state_next = INIT_ELEM;

            NEXT_TILE: begin
                // if this was last tile, we are done
                if ((tile_i + eff_blk_m >= m) && (tile_j + eff_blk_o >= o))
                    state_next = DONE;
                else
                    state_next = INIT_TILE;
            end

            DONE: begin
                if (!start)
                    state_next = IDLE;
            end
        endcase
    end

endmodule

module mmat_mult_operator #(
    parameter int MAX_N = 128,
    parameter int MAX_M = 128,
    // block size: max rows/cols updated per cycle
    parameter int BLK_N = 8,
    parameter int BLK_M = 8
)(
    input  wire                 clk,
    input  wire                 rst_n,

    input  wire                 start,
    output reg                  busy,
    output reg                  done,

    input  wire [31:0]          n,
    input  wire [31:0]          m,
    input  wire [31:0]          m1 [MAX_N-1:0][MAX_M-1:0],
    input  wire [31:0]          m2 [MAX_N-1:0][MAX_M-1:0],
    output reg  [31:0]          result [MAX_N-1:0][MAX_M-1:0]
);

    // tile origin (top‑left index of current block)
    integer tile_i, tile_j;
    // effective block size (handles edges)
    integer eff_blk_n, eff_blk_m;

    typedef enum logic [1:0] {IDLE, CALC_TILE, NEXT_TILE, DONE} state_t;
    state_t state, state_next;

    // compute effective block size from current tile origin
    always @* begin
        int rem_n = n - tile_i;
        int rem_m = m - tile_j;
        eff_blk_n = (rem_n > BLK_N) ? BLK_N : (rem_n > 0 ? rem_n : 0);
        eff_blk_m = (rem_m > BLK_M) ? BLK_M : (rem_m > 0 ? rem_m : 0);
    end

    integer i, j;

    // main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= IDLE;
            busy    <= 1'b0;
            done    <= 1'b0;
            tile_i  <= 0;
            tile_j  <= 0;
        end else begin
            state <= state_next;
            done  <= 1'b0;

            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    if (start && n != 0 && m != 0) begin
                        busy   <= 1'b1;
                        tile_i <= 0;
                        tile_j <= 0;
                        // optional: clear out‑of‑range region once
                        for (i = 0; i < MAX_N; i = i + 1)
                            for (j = 0; j < MAX_M; j = j + 1)
                                if (i >= n || j >= m)
                                    result[i][j] <= 32'd0;
                    end
                end

                CALC_TILE: begin
                    // update at most BLK_N × BLK_M elements this cycle
                    for (i = 0; i < eff_blk_n; i = i + 1) begin
                        for (j = 0; j < eff_blk_m; j = j + 1) begin
                            result[tile_i + i][tile_j + j]
                                <= m1[tile_i + i][tile_j + j]
                                 *  m2[tile_i + i][tile_j + j];
                        end
                    end
                end

                NEXT_TILE: begin
                    // move tile across columns, then down rows
                    if (tile_j + eff_blk_m < m) begin
                        tile_j <= tile_j + eff_blk_m;
                    end else begin
                        tile_j <= 0;
                        if (tile_i + eff_blk_n < n)
                            tile_i <= tile_i + eff_blk_n;
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
                if (start && n != 0 && m != 0)
                    state_next = CALC_TILE;
                else if (start)
                    state_next = DONE; // n==0 or m==0
            end

            CALC_TILE: begin
                // after one tile is updated, decide whether more tiles remain
                if ((tile_i + eff_blk_n >= n) && (tile_j + eff_blk_m >= m))
                    state_next = DONE;
                else
                    state_next = NEXT_TILE;
            end

            NEXT_TILE: state_next = CALC_TILE;

            DONE: begin
                if (!start)
                    state_next = IDLE;
            end
        endcase
    end

endmodule

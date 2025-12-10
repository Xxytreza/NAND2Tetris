module mmat_add_operator #(
    parameter int MAX_N = 128,
    parameter int MAX_M = 128,
    // block (tile) size – how many elements are updated per clock
    parameter int BLK_N = 8,
    parameter int BLK_M = 8
)(
    input  wire                 clk,
    input  wire                 rst_n,

    input  wire                 start,      // pulse to start operation
    output reg                  busy,       // high while running
    output reg                  done,       // 1‑clk pulse when finished

    input  wire [31:0]          n,
    input  wire [31:0]          m,
    input  wire [31:0]          m1 [MAX_N-1:0][MAX_M-1:0],
    input  wire [31:0]          m2 [MAX_N-1:0][MAX_M-1:0],
    output reg  [31:0]          result [MAX_N-1:0][MAX_M-1:0]
);

    // tile origin (top‑left of current block)
    integer tile_i, tile_j;
    // indices inside current tile
    integer bi, bj;

    // effective tile size at matrix edges
    integer eff_blk_n, eff_blk_m;

    typedef enum logic [1:0] {IDLE, CALC, NEXT_TILE} state_t;
    state_t state, state_next;

    // compute effective tile size (handles last partial tile)
    always @* begin
        int rem_n = n - tile_i;
        int rem_m = m - tile_j;
        eff_blk_n = (rem_n > BLK_N) ? BLK_N : (rem_n > 0 ? rem_n : 0);
        eff_blk_m = (rem_m > BLK_M) ? BLK_M : (rem_m > 0 ? rem_m : 0);
    end

    // main FSM + counters
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= IDLE;
            busy    <= 1'b0;
            done    <= 1'b0;
            tile_i  <= 0;
            tile_j  <= 0;
            bi      <= 0;
            bj      <= 0;
        end
        else begin
            state <= state_next;
            done  <= 1'b0;  // default, may be set below

            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    if (start && n != 0 && m != 0) begin
                        busy   <= 1'b1;
                        tile_i <= 0;
                        tile_j <= 0;
                        bi     <= 0;
                        bj     <= 0;
                    end
                end

                CALC: begin
                    // update up to BLK_N × BLK_M elements this clock
                    for (bi = 0; bi < eff_blk_n; bi = bi + 1) begin
                        for (bj = 0; bj < eff_blk_m; bj = bj + 1) begin
                            result[tile_i + bi][tile_j + bj]
                                <= m1[tile_i + bi][tile_j + bj]
                                 +  m2[tile_i + bi][tile_j + bj];
                        end
                    end

                    // zero the rest of the row/col area outside matrix bounds
                    // (optional: only if you want full zeroing like original)
                    if (tile_i == 0 && tile_j == 0) begin
                        integer zi, zj;
                        for (zi = n; zi < MAX_N; zi = zi + 1)
                            for (zj = 0; zj < MAX_M; zj = zj + 1)
                                result[zi][zj] <= 32'd0;
                        for (zi = 0; zi < n; zi = zi + 1)
                            for (zj = m; zj < MAX_M; zj = zj + 1)
                                result[zi][zj] <= 32'd0;
                    end
                end

                NEXT_TILE: begin
                    // advance to next tile
                    if (tile_j + eff_blk_m < m) begin
                        tile_j <= tile_j + eff_blk_m;
                    end
                    else begin
                        tile_j <= 0;
                        if (tile_i + eff_blk_n < n)
                            tile_i <= tile_i + eff_blk_n;
                    end
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
                    state_next = CALC;
            end

            CALC: begin
                // after writing this tile, decide if more tiles remain
                if ( (tile_i + eff_blk_n >= n) && (tile_j + eff_blk_m >= m) ) begin
                    state_next = IDLE;
                end
                else begin
                    state_next = NEXT_TILE;
                end
            end

            NEXT_TILE: begin
                state_next = CALC;
            end
        endcase

        // signal done when transitioning back to IDLE
        if (state == CALC &&
            (tile_i + eff_blk_n >= n) && (tile_j + eff_blk_m >= m))
            done = 1'b1;
    end

endmodule

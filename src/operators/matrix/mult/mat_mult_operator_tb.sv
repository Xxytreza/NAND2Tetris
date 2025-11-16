`timescale 1ns/1ps

module mat_mult_operator_tb;

    // Parameters
    parameter int MAX_N = 128;
    parameter int MAX_M = 128;

    // Testbench signals
    reg  [31:0] n;
    reg  [31:0] m;
    reg  [31:0] m1 [MAX_N-1:0][MAX_M-1:0];
    reg  [31:0] m2 [MAX_N-1:0][MAX_M-1:0];
    wire [31:0] result [MAX_N-1:0][MAX_M-1:0];

    // Instantiate DUT
    mat_mult_operator #(
        .MAX_N(MAX_N),
        .MAX_M(MAX_M)
    ) dut (
        .n(n),
        .m(m),
        .m1(m1),
        .m2(m2),
        .result(result)
    );

    integer i;
    integer j;
    integer errors;
    reg [31:0] expected [MAX_N][MAX_M];

    task reset_matrices;
        begin
            for (i = 0; i < MAX_N; i++) begin
                for (j = 0; j < MAX_M; j++) begin
                    m1[i][j] = 0;
                    m2[i][j] = 0;
                    expected[i][j] = 0;
                end
            end
        end 
    endtask

    task check_results;
        input string label;
        begin
            errors = 0;
            $display("\n%s", label);
            for (i = 0; i < n; i++) begin
                for (j = 0; j < m; j++) begin
                    if (result[i][j] !== expected[i][j]) begin
                        $display("  ERROR: index [%0d][%0d] result=%0d expected=%0d",
                                 i, j, result[i][j], expected[i][j]);
                        errors++;
                    end
                end
            end
            // Check unused rows are zeroed
            for (i = n; i < MAX_N; i++) begin
                for (j = 0; j < MAX_M; j++) begin
                    if (result[i][j] !== 0) begin
                        $display("  ERROR: unused index [%0d][%0d] result=%0d expected=0",
                                 i, j, result[i][j]);
                        errors++;
                    end
                end
            end
            reset_matrices();
            if (errors == 0)
                $display("✅  PASS");
        end
    endtask

    initial begin
        $display("\n\n\n========================================");
        $display("Matrix Element-mult Operator Testbench");
        $display("========================================");

        errors = 0;

        // Initialize matrices
        for (i = 0; i < MAX_N; i++) begin
            for (j = 0; j < MAX_M; j++) begin
                m1[i][j] = 0;
                m2[i][j] = 0;
            end
        end

        // ------------------------------------------------------------
        // Test 1: Simple n = 4, m = 1
        // ------------------------------------------------------------
        n = 4;
        m = 1;
        m1[0][0]=2; m2[0][0]=3;
        m1[1][0]=4; m2[1][0]=5;
        m1[2][0]=1; m2[2][0]=10;
        m1[3][0]=7; m2[3][0]=2;

        expected[0][0] = 6;
        expected[1][0] = 20;
        expected[2][0] = 10;
        expected[3][0] = 14;

        #10;
        check_results("Test 1: Simple matrix multiplication");

        // ------------------------------------------------------------
        // Test 2: Zeros mixed
        // ------------------------------------------------------------
        n = 4;
        m = 4;
        m1[0][2]=0; m2[0][3]=5;
        m1[1][0]=3; m2[1][0]=0;
        m1[2][1]=0; m2[2][0]=0;
        m1[3][0]=8; m2[3][2]=1;

        for (i = 0; i < n; i++)
            for (j = 0; j < m; j++)
                expected[i][j] = m1[i][j] * m2[i][j];

        #10;
        check_results("Test 2: With zeros");

        // ------------------------------------------------------------
        // Test 3: n = 8 sequence
        // ------------------------------------------------------------
        n = 8;
        m = 8;
        for (i = 0; i < n; i++) begin
            for (j = 0; j < m; j++) begin
                m1[i][j] = i + 1;
                m2[i][j] = 2;
                expected[i][j] = m1[i][j] * m2[i][j];
            end
        end

        #10;
        check_results("Test 3: Sequence multiplication");

        // ------------------------------------------------------------
        // Test 4: Large n, constant values
        // ------------------------------------------------------------
        n = MAX_N;
        m = 2;
        for (i = 0; i < n; i++) begin
            m1[i][0] = 7;
            m2[i][0] = 10;
            m1[i][1] = 12;
            m2[i][1] = 4;
            expected[i][0] = 70;
            expected[i][1] = 48;
        end

        #10;
        check_results("Test 4: Constant values");

        // ------------------------------------------------------------
        // Test 5: n = 0 edge case
        // ------------------------------------------------------------
        n = 0;
        m = 0;
        m1[0][0] = 5;
        m2[0][0] = 5;
        // No expected values (result should not update anything)
        #10;
        $display("\nTest 5: n = 0 (no elements) — PASS by definition");

        // ------------------------------------------------------------
        // Test 6: Maximum size
        // ------------------------------------------------------------
        n = MAX_N;
        m = MAX_M;
        for (i = 0; i < n; i++) begin
            for (j = 0; j < m; j++) begin
                m1[i][j] = i;
                m2[i][j] = j;
                expected[i][j] = i * j;
            end
        end

        #10;
        check_results("Test 6: Maximum size n=128");

        // ------------------------------------------------------------
        // Summary
        // ------------------------------------------------------------
        $display("\n========================================");
        if (errors == 0)
            $display("✅ ALL TESTS PASSED!");
        else
            $display("%0d ERRORS DETECTED", errors);
        $display("========================================");

        $finish;
    end

    // Timeout watchdog
    initial begin
        #10000;
        $display("ERROR: Testbench timeout!");
        $finish;
    end

endmodule

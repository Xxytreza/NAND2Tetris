`timescale 1ns/1ps

module vect_mult_operator_tb;

    // Parameters
    parameter int MAX_N = 128;

    // DUT interface signals
    reg  [31:0] n;
    reg  [31:0] v1 [MAX_N-1:0];
    reg  [31:0] v2 [MAX_N-1:0];
    wire [31:0] result [MAX_N-1:0];

    // Instantiate DUT
    vect_mult_operator #(
        .MAX_N(MAX_N)
    ) dut (
        .n(n),
        .v1(v1),
        .v2(v2),
        .result(result)
    );

    // Testbench variables
    integer i;
    integer errors;

    // Expected results array
    reg [31:0] expected [MAX_N];

    // ------------------------------------------------------------
    // Task: Compare expected[] and result[]
    // ------------------------------------------------------------
    task check_results;
        input string label;
        begin
            $display("\n%s", label);
            for (i = 0; i < n; i++) begin
                if (result[i] !== expected[i]) begin
                    $display("  ERROR index %0d: got %0d expected %0d",
                        i, result[i], expected[i]);
                    errors++;
                end
            end
            
            // Ensure elements >= n are forced to zero (per DUT behavior)
            for (i = n; i < MAX_N; i++) begin
                if (result[i] !== 32'd0) begin
                    $display("  ERROR index %0d: expected zero but got %0d",
                        i, result[i]);
                    errors++;
                end
            end

            if (errors == 0)
                $display("✅  PASS");
        end
    endtask

    // ------------------------------------------------------------
    // Main stimulus
    // ------------------------------------------------------------
    initial begin
        $display("\n\n\n========================================");
        $display("Vector Multiply Operator Testbench");
        $display("========================================");

        errors = 0;

        // Ensure inputs initialized
        for (i = 0; i < MAX_N; i++) begin
            v1[i] = 0;
            v2[i] = 0;
            expected[i] = 0;
        end

        // ------------------------------------------------------------
        // Test 1: Simple multiplication
        // ------------------------------------------------------------
        n = 4;
        v1[0]=2; v2[0]=3;     // 6
        v1[1]=4; v2[1]=5;     // 20
        v1[2]=1; v2[2]=10;    // 10
        v1[3]=7; v2[3]=2;     // 14

        for (i = 0; i < n; i++)
            expected[i] = v1[i] * v2[i];

        #10;
        check_results("Test 1: Basic element-wise multiplication");

        // ------------------------------------------------------------
        // Test 2: Multiplication with zeros
        // ------------------------------------------------------------
        n = 4;
        v1[0]=0; v2[0]=12;    // 0
        v1[1]=5; v2[1]=0;     // 0
        v1[2]=0; v2[2]=0;     // 0
        v1[3]=9; v2[3]=7;     // 63

        for (i = 0; i < n; i++)
            expected[i] = v1[i] * v2[i];

        #10;
        check_results("Test 2: Mixed zero multiplication");

        // ------------------------------------------------------------
        // Test 3: n = 8, linear sequence
        // ------------------------------------------------------------
        n = 8;
        for (i = 0; i < n; i++) begin
            v1[i] = i + 1;   // 1,2,3,...
            v2[i] = 3;       // constant
            expected[i] = v1[i] * v2[i];
        end

        #10;
        check_results("Test 3: Sequence × constant");

        // ------------------------------------------------------------
        // Test 4: All 10 × 10, n=5
        // ------------------------------------------------------------
        n = 5;
        for (i = 0; i < MAX_N; i++) begin
            v1[i] = 10;
            v2[i] = 10;
            if (i < n)
                expected[i] = 100;
            else
                expected[i] = 0;
        end

        #10;
        check_results("Test 4: Solid values n=5");

        // ------------------------------------------------------------
        // Test 5: Edge case n = 0
        // ------------------------------------------------------------
        n = 0;
        v1[0] = 9;
        v2[0] = 9;
        // All outputs must be zero
        for (i = 0; i < MAX_N; i++)
            expected[i] = 0;

        #10;
        check_results("Test 5: n = 0");

        // ------------------------------------------------------------
        // Test 6: Maximum size
        // ------------------------------------------------------------
        n = MAX_N;
        for (i = 0; i < MAX_N; i++) begin
            v1[i] = 2;
            v2[i] = 3;
            expected[i] = 6;
        end

        #10;
        check_results("Test 6: Full-size vector multiply");

        // ------------------------------------------------------------
        // Summary
        // ------------------------------------------------------------
        $display("\n========================================");
        if (errors == 0)
            $display("✅ ALL TESTS PASSED!");
        else
            $display("TEST FAILED with %0d errors", errors);
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

`timescale 1ns/1ps

module vect_add_operator_tb;

    // Parameters
    parameter int MAX_N = 128;

    // Testbench signals
    reg  [31:0] n;
    reg  [MAX_N-1:0][31:0] v1;
    reg  [MAX_N-1:0][31:0] v2;
    wire [MAX_N-1:0][31:0] result;

    // Instantiate DUT
    vect_add_operator #(
        .MAX_N(MAX_N)
    ) dut (
        .n(n),
        .v1(v1),
        .v2(v2),
        .result(result)
    );

    integer i;
    integer errors;
    reg [31:0] expected [MAX_N];

    task check_results;
        input string label;
        begin
            $display("\n%s", label);
            for (i = 0; i < n; i++) begin
                if (result[i] !== expected[i]) begin
                    $display("  ERROR: index %0d result=%0d expected=%0d",
                             i, result[i], expected[i]);
                    errors++;
                end
            end
            if (errors == 0)
                $display("✅  PASS");
        end
    endtask

    initial begin
        $display("\n\n\n========================================");
        $display("Vector Add Operator Testbench");
        $display("========================================");

        errors = 0;

        // Initialize vectors
        for (i = 0; i < MAX_N; i++) begin
            v1[i] = 0;
            v2[i] = 0;
        end

        // ------------------------------------------------------------
        // Test 1: Simple n = 4
        // ------------------------------------------------------------
        n = 4;
        v1[0]=2; v2[0]=3;
        v1[1]=4; v2[1]=5;
        v1[2]=1; v2[2]=10;
        v1[3]=7; v2[3]=2;

        for (i = 0; i < n; i++)
            expected[i] = v1[i] + v2[i];

        #10;
        check_results("Test 1: Simple vector addition");

        // ------------------------------------------------------------
        // Test 2: Zeros mixed
        // ------------------------------------------------------------
        n = 4;
        v1[0]=0; v2[0]=5;
        v1[1]=3; v2[1]=0;
        v1[2]=0; v2[2]=0;
        v1[3]=8; v2[3]=1;

        for (i = 0; i < n; i++)
            expected[i] = v1[i] + v2[i];

        #10;
        check_results("Test 2: With zeros");

        // ------------------------------------------------------------
        // Test 3: n = 8 sequence
        // ------------------------------------------------------------
        n = 8;
        for (i = 0; i < n; i++) begin
            v1[i] = i + 1;
            v2[i] = 2;
            expected[i] = v1[i] + v2[i];
        end

        #10;
        check_results("Test 3: Sequence addition");

        // ------------------------------------------------------------
        // Test 4: Large n, constant values
        // ------------------------------------------------------------
        n = 3;
        for (i = 0; i < MAX_N; i++) begin
            v1[i] = 10;
            v2[i] = 10;
        end
        for (i = 0; i < n; i++)
            expected[i] = 20;

        #10;
        check_results("Test 4: Constant values");

        // ------------------------------------------------------------
        // Test 5: n = 0 edge case
        // ------------------------------------------------------------
        n = 0;
        v1[0] = 5;
        v2[0] = 5;
        // No expected values (result should not update anything)
        #10;
        $display("\nTest 5: n = 0 (no elements) — PASS by definition");

        // ------------------------------------------------------------
        // Test 6: Maximum size
        // ------------------------------------------------------------
        n = MAX_N;
        for (i = 0; i < MAX_N; i++) begin
            v1[i] = 1;
            v2[i] = 1;
            expected[i] = 2;
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

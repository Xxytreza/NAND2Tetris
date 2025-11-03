`timescale 1ns/1ps

module vect_dot_operator_tb;

    // Parameters
    parameter int MAX_N = 128;
    parameter int TEST_SIZE_1 = 4;
    parameter int TEST_SIZE_2 = 8;
    
    // Testbench signals
    reg [31:0] n;
    reg [MAX_N-1:0][31:0] v1;
    reg [MAX_N-1:0][31:0] v2;
    wire [31:0] result;
    
    // Instantiate the module under test
    vect_dot_operator #(
        .MAX_N(MAX_N)
    ) dut (
        .n(n),
        .v1(v1),
        .v2(v2),
        .result(result)
    );
    
    // Test variables
    integer i;
    integer errors;
    
    // Main test procedure
    initial begin
        $display("========================================");
        $display("Vector Multiplication Testbench");
        $display("========================================");
        
        errors = 0;
        
        // Initialize all vectors to zero
        for (i = 0; i < MAX_N; i = i + 1) begin
            v1[i] = 32'd0;
            v2[i] = 32'd0;
        end
        
        // Test 1: Simple multiplication with n=4
        $display("\nTest 1: Vector size n=4, simple values");
        n = 32'd4;
        v1[0] = 32'd2;  v2[0] = 32'd3;   // Expected: 6
        v1[1] = 32'd4;  v2[1] = 32'd5;   // Expected: 20
        v1[2] = 32'd1;  v2[2] = 32'd10;  // Expected: 10
        v1[3] = 32'd7;  v2[3] = 32'd2;   // Expected: 14
        #10;
        
        $display("Results:");
        for (i = 0; i < TEST_SIZE_1; i = i + 1) begin
            $display("  result[%0d] = %0d (v1[%0d]=%0d * v2[%0d]=%0d)", 
                     i, result[i], i, v1[i], i, v2[i]);
        end
        
        // Test 2: Multiplication with zeros
        $display("\nTest 2: Vector size n=4, with zeros");
        n = 32'd4;
        v1[0] = 32'd0;  v2[0] = 32'd5;   // Expected: 0
        v1[1] = 32'd3;  v2[1] = 32'd0;   // Expected: 0
        v1[2] = 32'd0;  v2[2] = 32'd0;   // Expected: 0
        v1[3] = 32'd8;  v2[3] = 32'd1;   // Expected: 8
        #10;
        
        $display("Results:");
        for (i = 0; i < TEST_SIZE_1; i = i + 1) begin
            $display("  result[%0d] = %0d", i, result[i]);
        end
        
        // Test 3: Larger vector size n=8
        $display("\nTest 3: Vector size n=8");
        n = 32'd8;
        for (i = 0; i < 8; i = i + 1) begin
            v1[i] = i + 1;      // 1, 2, 3, 4, 5, 6, 7, 8
            v2[i] = 2;          // All 2s
        end
        #10;
        
        $display("Results (expected: 2, 4, 6, 8, 10, 12, 14, 16):");
        for (i = 0; i < TEST_SIZE_2; i = i + 1) begin
            $display("  result[%0d] = %0d", i, result[i]);
        end
        
        // Test 4: Variable size - only first n elements should be computed
        $display("\nTest 4: Variable size test (n=3, but arrays have more data)");
        n = 32'd3;
        for (i = 0; i < MAX_N; i = i + 1) begin
            v1[i] = 32'd10;
            v2[i] = 32'd10;     // All should be 100
        end
        #10;
        
        $display("Results (only first 3 should be non-zero):");
        for (i = 0; i < 6; i = i + 1) begin
            $display("  result[%0d] = %0d (expected: %0d)", 
                     i, result[i], (i < 3) ? 100 : 0);
            if (i < 3 && result[i] != 32'd100) errors = errors + 1;
            if (i >= 3 && result[i] != 32'd0) errors = errors + 1;
        end
        
        // Test 5: Edge case - n=0
        $display("\nTest 5: Edge case n=0");
        n = 32'd0;
        v1[0] = 32'd5;  v2[0] = 32'd5;
        #10;
        
        $display("Results (all should be zero):");
        for (i = 0; i < 4; i = i + 1) begin
            $display("  result[%0d] = %0d", i, result[i]);
            if (result[i] != 32'd0) errors = errors + 1;
        end
        
        // Test 6: Maximum size
        $display("\nTest 6: Maximum size n=128");
        n = 32'd128;
        for (i = 0; i < MAX_N; i = i + 1) begin
            v1[i] = 32'd1;
            v2[i] = 32'd1;
        end
        #10;
        
        $display("Results (showing first and last few):");
        $display("  result[0] = %0d", result[0]);
        $display("  result[1] = %0d", result[1]);
        $display("  result[126] = %0d", result[126]);
        $display("  result[127] = %0d", result[127]);
        
        // Summary
        $display("\n========================================");
        if (errors == 0) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("TESTS FAILED: %0d errors detected", errors);
        end
        $display("========================================");
        
        $finish;
    end
    
    // Optional: Timeout watchdog
    initial begin
        #10000;
        $display("ERROR: Testbench timeout!");
        $finish;
    end

endmodule

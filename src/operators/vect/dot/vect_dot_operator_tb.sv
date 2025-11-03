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
    reg [31:0] expected;
    
    // Main test procedure
    initial begin
        $display("========================================");
        $display("Vector Dot Product Testbench");
        $display("========================================");
        
        errors = 0;
        
        // Initialize all vectors to zero
        for (i = 0; i < MAX_N; i = i + 1) begin
            v1[i] = 32'd0;
            v2[i] = 32'd0;
        end
        
        // Test 1: Simple dot product with n=4
        // Expected: 2*3 + 4*5 + 1*10 + 7*2 = 6 + 20 + 10 + 14 = 50
        $display("\nTest 1: Vector size n=4, simple values");
        // Reset vectors
        for (i = 0; i < MAX_N; i = i + 1) begin
            v1[i] = 32'd0;
            v2[i] = 32'd0;
        end
        n = 32'd4;
        v1[0] = 32'd2;  v2[0] = 32'd3;
        v1[1] = 32'd4;  v2[1] = 32'd5;
        v1[2] = 32'd1;  v2[2] = 32'd10;
        v1[3] = 32'd7;  v2[3] = 32'd2;
        expected = 32'd50;
        #10;
        
        $display("Result: %0d (expected: %0d)", result, expected);
        if (result != expected) begin
            $display("  ERROR: Mismatch!");
            errors = errors + 1;
        end else begin
            $display("  PASS");
        end
        
        // Test 2: Dot product with zeros
        // Expected: 0*5 + 3*0 + 0*0 + 8*1 = 8
        $display("\nTest 2: Vector size n=4, with zeros");
        // Reset vectors
        for (i = 0; i < MAX_N; i = i + 1) begin
            v1[i] = 32'd0;
            v2[i] = 32'd0;
        end
        n = 32'd4;
        v1[0] = 32'd0;  v2[0] = 32'd5;
        v1[1] = 32'd3;  v2[1] = 32'd0;
        v1[2] = 32'd0;  v2[2] = 32'd0;
        v1[3] = 32'd8;  v2[3] = 32'd1;
        expected = 32'd8;
        #10;
        
        $display("Result: %0d (expected: %0d)", result, expected);
        if (result != expected) begin
            $display("  ERROR: Mismatch!");
            errors = errors + 1;
        end else begin
            $display("  PASS");
        end
        
        // Test 3: Larger vector size n=8
        // Expected: 1*2 + 2*2 + 3*2 + 4*2 + 5*2 + 6*2 + 7*2 + 8*2 = 72
        $display("\nTest 3: Vector size n=8");
        // Reset vectors
        for (i = 0; i < MAX_N; i = i + 1) begin
            v1[i] = 32'd0;
            v2[i] = 32'd0;
        end
        n = 32'd8;
        for (i = 0; i < 8; i = i + 1) begin
            v1[i] = i + 1;
            v2[i] = 2;
        end
        expected = 32'd72;
        #10;
        
        $display("Result: %0d (expected: %0d)", result, expected);
        if (result != expected) begin
            $display("  ERROR: Mismatch!");
            errors = errors + 1;
        end else begin
            $display("  PASS");
        end
        
        // Test 4: Variable size - only first n elements computed
        // Expected: 10*10 + 10*10 + 10*10 = 300
        $display("\nTest 4: Variable size test (n=3)");
        n = 32'd3;
        for (i = 0; i < MAX_N; i = i + 1) begin
            v1[i] = 32'd10;
            v2[i] = 32'd10;
        end
        expected = 32'd300;
        #10;
        
        $display("Result: %0d (expected: %0d)", result, expected);
        if (result != expected) begin
            $display("  ERROR: Mismatch!");
            errors = errors + 1;
        end else begin
            $display("  PASS");
        end
        
        // Test 5: Edge case - n=0
        // Expected: 0 (no elements)
        $display("\nTest 5: Edge case n=0");
        n = 32'd0;
        v1[0] = 32'd5;  v2[0] = 32'd5;
        expected = 32'd0;
        #10;
        
        $display("Result: %0d (expected: %0d)", result, expected);
        if (result != expected) begin
            $display("  ERROR: Mismatch!");
            errors = errors + 1;
        end else begin
            $display("  PASS");
        end
        
        // Test 6: Maximum size
        // Expected: 128 (1*1 + 1*1 + ... 128 times)
        $display("\nTest 6: Maximum size n=128");
        n = 32'd128;
        for (i = 0; i < MAX_N; i = i + 1) begin
            v1[i] = 32'd1;
            v2[i] = 32'd1;
        end
        expected = 32'd128;
        #10;
        
        $display("Result: %0d (expected: %0d)", result, expected);
        if (result != expected) begin
            $display("  ERROR: Mismatch!");
            errors = errors + 1;
        end else begin
            $display("  PASS");
        end
        
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

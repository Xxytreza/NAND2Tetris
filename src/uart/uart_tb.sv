`timescale 1ns / 1ps

module uart_tb;

// ============================================
// TEST PARAMETERS
// ============================================
localparam int CLK_FREQ = 50_000_000;     // 50 MHz
localparam int BIT_RATE = 115200;         // 115200 baud (faster for simulation)
localparam int PAYLOAD_BITS = 8;
localparam real CLK_PERIOD = 1_000_000_000.0 / CLK_FREQ;  // in ns
localparam real BIT_PERIOD = 1_000_000_000.0 / BIT_RATE;  // in ns


// ============================================
// SIGNALS
// ============================================
logic clk;
logic resetn;

// Transmitter signals
logic [PAYLOAD_BITS-1:0] tx_data;
logic tx_start;
logic tx_line;
logic tx_busy;

// Receiver signals
logic rx_enabled;
logic [PAYLOAD_BITS-1:0] rx_data;
logic rx_valid;
logic rx_break;

// Test control
int test_count;
int pass_count;
int fail_count;


// ============================================
// DEVICE UNDER TEST (DUT)
// ============================================

// UART Transmitter
uart_transmitter #(
    .BIT_RATE(BIT_RATE),
    .CLK_FREQ(CLK_FREQ),
    .PAYLOAD_BITS(PAYLOAD_BITS),
    .STOP_BITS(1)
) tx_inst (
    .clk(clk),
    .resetn(resetn),
    .tx_data(tx_data),
    .tx_start(tx_start),
    .tx(tx_line),
    .tx_busy(tx_busy)
);

// UART Receiver
uart_receiver #(
    .BIT_RATE(BIT_RATE),
    .CLK_FREQ(CLK_FREQ),
    .PAYLOAD_BITS(PAYLOAD_BITS),
    .EOF_BITS(1)
) rx_inst (
    .clk(clk),
    .resetn(resetn),
    .receiver_pin(tx_line),  // Connect TX to RX (loopback)
    .enabled(rx_enabled),
    .data(rx_data),
    .is_valid(rx_valid),
    .got_break(rx_break)
);


// ============================================
// CLOCK GENERATION
// ============================================
initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end


// ============================================
// TEST STIMULUS
// ============================================
initial begin
    // Initialize
    test_count = 0;
    pass_count = 0;
    fail_count = 0;
    
    resetn = 0;
    tx_data = 0;
    tx_start = 0;
    rx_enabled = 1;
    
    // Display test info
    $display("===============================================");
    $display("UART Testbench");
    $display("Clock Frequency: %0d Hz", CLK_FREQ);
    $display("Baud Rate: %0d", BIT_RATE);
    $display("Bit Period: %0.2f ns", BIT_PERIOD);
    $display("Clock Period: %0.2f ns", CLK_PERIOD);
    $display("===============================================");
    
    // Reset
    repeat(10) @(posedge clk);
    resetn = 1;
    repeat(5) @(posedge clk);
    
    // Test 1: Send single byte 0x55 (01010101)
    test_uart_byte(8'h55, "Test 1: 0x55 (alternating bits)");
    
    // Test 2: Send 0xAA (10101010)
    test_uart_byte(8'hAA, "Test 2: 0xAA (alternating bits)");
    
    // Test 3: Send 0x00 (all zeros)
    test_uart_byte(8'h00, "Test 3: 0x00 (all zeros)");
    
    // Test 4: Send 0xFF (all ones)
    test_uart_byte(8'hFF, "Test 4: 0xFF (all ones)");
    
    // Test 5: Send ASCII 'A' (0x41)
    test_uart_byte(8'h41, "Test 5: 0x41 (ASCII 'A')");
    
    // Test 6: Send ASCII 'Z' (0x5A)
    test_uart_byte(8'h5A, "Test 6: 0x5A (ASCII 'Z')");
    
    // Test 7: Multiple consecutive bytes
    $display("\n--- Test 7: Multiple consecutive bytes ---");
    test_uart_byte(8'h12, "Byte 1: 0x12");
    test_uart_byte(8'h34, "Byte 2: 0x34");
    test_uart_byte(8'h56, "Byte 3: 0x56");
    test_uart_byte(8'h78, "Byte 4: 0x78");
    
    // Summary
    repeat(100) @(posedge clk);
    $display("\n===============================================");
    $display("TEST SUMMARY");
    $display("Total Tests: %0d", test_count);
    $display("Passed: %0d", pass_count);
    $display("Failed: %0d", fail_count);
    $display("===============================================");
    
    if (fail_count == 0) begin
        $display("✅ ALL TESTS PASSED!");
    end else begin
        $display("❌ SOME TESTS FAILED!");
    end
    
    $finish;
end


// ============================================
// TASK: Test UART Byte Transmission
// ============================================
task test_uart_byte(input logic [7:0] data_to_send, input string test_name);
    logic [7:0] received_data;
    int timeout_counter;
    
    test_count++;
    $display("\n--- %s ---", test_name);
    $display("Sending: 0x%02h (%08b)", data_to_send, data_to_send);
    
    // Start transmission
    @(posedge clk);
    tx_data = data_to_send;
    tx_start = 1;
    @(posedge clk);
    tx_start = 0;
    
    // Wait for transmission to complete
    timeout_counter = 0;
    while (tx_busy && timeout_counter < 100000) begin
        @(posedge clk);
        timeout_counter++;
    end
    
    if (timeout_counter >= 100000) begin
        $display("❌ TIMEOUT: TX didn't complete");
        fail_count++;
    end else begin
        // Wait for receiver to get data
        timeout_counter = 0;
        while (!rx_valid && timeout_counter < 100000) begin
            @(posedge clk);
            timeout_counter++;
        end
        
        if (timeout_counter >= 100000) begin
            $display("❌ TIMEOUT: RX didn't receive data");
            fail_count++;
        end else begin
            // Check received data
            @(posedge clk);
            received_data = rx_data;
            
            if (received_data === data_to_send) begin
                $display("✅ PASS: Received 0x%02h (%08b)", received_data, received_data);
                pass_count++;
            end else begin
                $display("❌ FAIL: Expected 0x%02h, got 0x%02h", data_to_send, received_data);
                fail_count++;
            end
        end
    end
    
    // Wait a bit before next test
    repeat(50) @(posedge clk);
endtask


// ============================================
// MONITOR: Display RX events
// ============================================
always @(posedge clk) begin
    if (rx_valid) begin
        $display("[%0t ns] RX: Received byte 0x%02h (%08b) '%c'", 
                 $time, rx_data, rx_data, 
                 (rx_data >= 32 && rx_data < 127) ? rx_data : ".");
    end
    
    if (rx_break) begin
        $display("[%0t ns] RX: Break condition detected!", $time);
    end
end

// Monitor TX events
always @(posedge clk) begin
    if (tx_start) begin
        $display("[%0t ns] TX: Starting transmission of 0x%02h", $time, tx_data);
    end
end


// ============================================
// WAVEFORM DUMP (for viewing in GTKWave)
// ============================================
initial begin
    $dumpfile("uart_tb.vcd");
    $dumpvars(0, uart_tb);
end

endmodule

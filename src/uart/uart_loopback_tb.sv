`timescale 1ns/1ns

//
// Module: uart_loopback_tb
// 
// Simple loopback testbench - TX connects directly to RX
//

module uart_loopback_tb;

// Clock and reset
reg clk;
reg resetn;

// UART signals
reg uart_rx_in;          // External UART input (from testbench)
wire uart_tx_out;        // UART output from transmitter
wire uart_loopback;      // Internal loopback connection

// Control signals
reg [7:0] tx_data;
reg tx_start;
wire tx_busy;

// Receiver signals
wire [7:0] rx_data;
wire rx_valid;
wire rx_break;

// Test parameters
localparam BIT_RATE = 115200;
localparam CLK_HZ   = 50000000;
localparam BIT_P    = 1000000000 / BIT_RATE;  // Bit period in ns
localparam CLK_P    = 1000000000 / CLK_HZ;     // Clock period in ns

// Test counters
integer test_count = 0;
integer pass_count = 0;
integer fail_count = 0;

//
// Clock generation
//
initial begin
    clk = 0;
    forever #(CLK_P/2) clk = ~clk;
end

//
// DUT: UART Transmitter
//
uart_transmitter #(
    .BIT_RATE(BIT_RATE),
    .CLK_FREQ(CLK_HZ),
    .PAYLOAD_BITS(8),
    .STOP_BITS(1)
) i_uart_tx (
    .clk(clk),
    .resetn(resetn),
    .tx_data(tx_data),
    .tx_start(tx_start),
    .tx(uart_tx_out),
    .tx_busy(tx_busy)
);

//
// DUT: UART Receiver  
//
uart_receiver #(
    .BIT_RATE(BIT_RATE),
    .CLK_FREQ(CLK_HZ),
    .PAYLOAD_BITS(8),
    .EOF_BITS(1)
) i_uart_rx (
    .clk(clk),
    .resetn(resetn),
    .receiver_pin(uart_loopback),
    .enabled(1'b1),
    .data(rx_data),
    .is_valid(rx_valid),
    .got_break(rx_break)
);

// Loopback: TX -> RX
assign uart_loopback = uart_tx_out;

//
// Task: Send a byte using the transmitter
//
task send_byte_via_tx;
    input [7:0] byte_to_send;
    begin
        @(posedge clk);
        tx_data = byte_to_send;
        tx_start = 1'b1;
        @(posedge clk);
        tx_start = 1'b0;
        
        // Wait for transmission to complete
        wait(tx_busy == 1'b0);
        repeat(1000) @(posedge clk);  // Wait longer between transmissions
    end
endtask

//
// Task: Test sending and receiving a byte
//
task test_byte;
    input [7:0] test_data;
    input [255:0] test_name;  // String
    reg [7:0] received;
    integer timeout;
    begin
        test_count = test_count + 1;
        $display("\n[%0t] Test %0d: %0s", $time, test_count, test_name);
        $display("  Sending: 0x%02h (%08b)", test_data, test_data);
        
        send_byte_via_tx(test_data);
        
        // Wait for RX to receive (with timeout)
        timeout = 0;
        while (!rx_valid && timeout < 100000) begin
            @(posedge clk);
            timeout = timeout + 1;
        end
        
        if (timeout >= 100000) begin
            $display("  ❌ FAIL: Timeout waiting for RX");
            fail_count = fail_count + 1;
        end else begin
            @(posedge clk);
            received = rx_data;
            if (received == test_data) begin
                $display("  ✅ PASS: Received 0x%02h (%08b)", received, received);
                pass_count = pass_count + 1;
            end else begin
                $display("  ❌ FAIL: Expected 0x%02h, got 0x%02h", test_data, received);
                fail_count = fail_count + 1;
            end
        end
        
        repeat(100) @(posedge clk);
    end
endtask

//
// Main test sequence
//
initial begin
    // Initialize
    resetn = 0;
    tx_data = 0;
    tx_start = 0;
    uart_rx_in = 1;
    
    // Setup waveform dump
    $dumpfile("uart_loopback_tb.vcd");
    $dumpvars(0, uart_loopback_tb);
    
    $display("========================================");
    $display("UART Loopback Testbench");
    $display("Clock: %0d Hz, Baud: %0d", CLK_HZ, BIT_RATE);
    $display("========================================");
    
    // Reset
    repeat(20) @(posedge clk);
    resetn = 1;
    repeat(20) @(posedge clk);
    
    // Run tests
    test_byte(8'h55, "Alternating bits (0x55)");
    test_byte(8'hAA, "Alternating bits (0xAA)");
    test_byte(8'h00, "All zeros");
    test_byte(8'hFF, "All ones");
    test_byte(8'h41, "ASCII 'A'");
    test_byte(8'h5A, "ASCII 'Z'");
    test_byte(8'h12, "Random 1");
    test_byte(8'h34, "Random 2");
    test_byte(8'h56, "Random 3");
    test_byte(8'h78, "Random 4");
    test_byte(8'h9A, "Random 5");
    test_byte(8'hBC, "Random 6");
    test_byte(8'hDE, "Random 7");
    test_byte(8'hF0, "Random 8");
    
    // Summary
    repeat(100) @(posedge clk);
    $display("\n========================================");
    $display("TEST SUMMARY");
    $display("Total:  %0d", test_count);
    $display("Passed: %0d", pass_count);
    $display("Failed: %0d", fail_count);
    $display("========================================");
    
    if (fail_count == 0) begin
        $display("✅ ALL TESTS PASSED!");
    end else begin
        $display("❌ %0d TEST(S) FAILED!", fail_count);
    end
    
    $display("\n[%0t] Simulation finished", $time);
    $finish;
end

// Monitor RX events
always @(posedge clk) begin
    if (rx_valid) begin
        $display("  [%0t] RX received: 0x%02h", $time, rx_data);
    end
end

endmodule

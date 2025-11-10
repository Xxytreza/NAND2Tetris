// UART Loopback Test Module
// Connects TX directly to RX for testing on FPGA hardware

module uart_loopback_top #(
    parameter int BIT_RATE = 9600,
    parameter int CLK_FREQ = 50_000_000,
    parameter int PAYLOAD_BITS = 8
)(
    input wire clk,               // System clock
    input wire resetn,            // Active-low reset (button)
    input wire [7:0] sw,          // Switches to set data to send
    input wire btn_send,          // Button to trigger send
    output wire [7:0] led,        // LEDs show received data
    output wire led_tx_busy,      // TX busy indicator LED
    output wire led_rx_valid      // RX valid indicator LED
);

    // Internal UART connection (TX -> RX loopback)
    wire uart_line;
    
    // TX signals
    wire tx_busy;
    
    // RX signals
    wire [7:0] rx_data;
    wire rx_valid;
    
    // Button edge detection
    reg btn_send_reg, btn_send_prev;
    wire btn_pulse;
    
    // Edge detector for send button
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            btn_send_reg <= 0;
            btn_send_prev <= 0;
        end else begin
            btn_send_reg <= btn_send;
            btn_send_prev <= btn_send_reg;
        end
    end
    
    // Generate pulse on button press (rising edge)
    assign btn_pulse = btn_send_reg && !btn_send_prev;
    
    
    // ============================================
    // UART TRANSMITTER
    // ============================================
    uart_transmitter #(
        .BIT_RATE(BIT_RATE),
        .CLK_FREQ(CLK_FREQ),
        .PAYLOAD_BITS(PAYLOAD_BITS),
        .STOP_BITS(1)
    ) uart_tx (
        .clk(clk),
        .resetn(resetn),
        .tx_data(sw),           // Data from switches
        .tx_start(btn_pulse),   // Trigger on button press
        .tx(uart_line),         // TX output
        .tx_busy(tx_busy)
    );
    
    
    // ============================================
    // UART RECEIVER
    // ============================================
    uart_receiver #(
        .BIT_RATE(BIT_RATE),
        .CLK_FREQ(CLK_FREQ),
        .PAYLOAD_BITS(PAYLOAD_BITS),
        .EOF_BITS(1)
    ) uart_rx (
        .clk(clk),
        .resetn(resetn),
        .receiver_pin(uart_line),  // Connected to TX (loopback)
        .enabled(1'b1),            // Always enabled
        .data(rx_data),
        .is_valid(rx_valid),
        .got_break()               // Not used
    );
    
    
    // ============================================
    // LED OUTPUTS
    // ============================================
    
    // Store received data to display on LEDs
    reg [7:0] led_reg;
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            led_reg <= 8'h00;
        end else if (rx_valid) begin
            led_reg <= rx_data;  // Update LEDs when new data received
        end
    end
    
    // Output assignments
    assign led = led_reg;
    assign led_tx_busy = tx_busy;
    assign led_rx_valid = rx_valid;

endmodule

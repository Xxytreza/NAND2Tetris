module uart_receiver #(
    parameter int BIT_RATE = 9600,         // UART baud rate (bits per second)
    parameter int CLK_FREQ = 50_000_000,   // Clock frequency in Hz (50 MHz)
    parameter int PAYLOAD_BITS = 8,        // Number of data bits per frame
    parameter int EOF_BITS = 1             // Number of stop bits
)(
    // Clock and reset
    input wire clk,                        // System clock
    input wire resetn,                     // Active-low reset
    
    // UART interface
    input wire receiver_pin,               // UART RX input pin
    input wire enabled,                    // Enable signal for receiver
    
    // Output signals
    output wire got_break,                 // Break condition detected flag
    output wire is_valid,                  // Valid data received flag
    output logic [PAYLOAD_BITS-1:0] data   // Received data output
);

// ============================================
// LOCAL PARAMETERS (Timing calculations)
// ============================================
localparam int CLK_PER_BIT = CLK_FREQ / BIT_RATE;      // Clock cycles per UART bit
localparam int HALF_BIT = CLK_PER_BIT / 2;              // Half bit period for start bit detection
localparam int COUNT_REG_LEN = 1 + $clog2(CLK_PER_BIT); // Bit width for cycle counter register


// ============================================
// STATE MACHINE DEFINITION
// ============================================
typedef enum logic [2:0] {
    IDLE       ,    // Waiting for start bit
    START_BIT  ,    // Verifying start bit
    DATA_BITS  ,    // Receiving data bits
    STOP_BIT   ,    // Checking stop bit
    CLEANUP         // Cleanup before returning to IDLE
} state_t;


// ============================================
// INTERNAL REGISTERS
// ============================================

// State machine registers
state_t curr_state, next_state;           // Current and next FSM states

// Input synchronization (metastability protection)
reg rx_sync1;                             // First stage synchronizer for receiver_pin
reg rx_sync2;                             // Second stage synchronizer for receiver_pin

// Data reception registers
reg [PAYLOAD_BITS-1:0] rx_shift_reg;        // Shift register to accumulate received bits

// Timing and counting registers
reg [COUNT_REG_LEN-1:0] cycle_counter;   // Counts clock cycles within a bit period

reg [$clog2(PAYLOAD_BITS):0] bit_counter;   // Counts which data bit is being received (0-7)

// Output registers
reg data_valid;                           // Indicates when valid data is available
reg break_detected;                       // Indicates if a break condition was detected

always_ff @(posedge clk or negedge resetn) begin 
    if(!resetn) begin
        curr_state <= IDLE;
        cycle_counter <= 0;
        bit_counter <= 0;
        rx_shift_reg <= 0;
        data <= 0;
        data_valid <= 0;
        break_detected <= 0;
        rx_sync1 <= 1;
        rx_sync2 <= 1;
    end else if (enabled) begin 
        rx_sync1 <= receiver_pin;
        rx_sync2 <= rx_sync1;
        curr_state <= next_state;
        data_valid <= 0;

        case (curr_state) 
            IDLE: begin
                cycle_counter <= 0;
                bit_counter <= 0;
                break_detected <= 0;
            end
            START_BIT: begin
                if(cycle_counter == HALF_BIT - 1) begin
                    cycle_counter <= 0;
                end else begin 
                    cycle_counter <= cycle_counter + 1;
                end 
            end
            DATA_BITS: begin
                if(cycle_counter == CLK_PER_BIT - 1) begin
                    cycle_counter <= 0;
                    rx_shift_reg[bit_counter] <= rx_sync2;
                    bit_counter <= bit_counter + 1;
                end else begin 
                    cycle_counter <= cycle_counter + 1;
                end
            end
            STOP_BIT: begin 
                if(cycle_counter == CLK_PER_BIT - 1) begin
                    cycle_counter <= 0;
                    if(rx_sync2 == 1) begin
                        data <= rx_shift_reg;
                        data_valid <= 1;
                    end else begin
                        break_detected <= 1;
                    end
                end else begin
                    cycle_counter <= cycle_counter + 1;
                end
            end
            CLEANUP: begin
                cycle_counter <= 0;
                bit_counter <= 0;
            end
        endcase
    end 
end 


always_comb begin
    next_state = curr_state;

    case (curr_state)
        IDLE: begin
            if(rx_sync2 == 0) begin
                next_state = START_BIT;
            end
        end
        START_BIT: begin
            if (cycle_counter == HALF_BIT - 1) begin
                if(rx_sync2 == 0) begin
                    next_state = DATA_BITS;
                end else begin
                    next_state = IDLE;
                end
            end 
        end 
        DATA_BITS: begin
            if (cycle_counter == CLK_PER_BIT - 1) begin
                if (bit_counter >= PAYLOAD_BITS) begin
                    next_state = STOP_BIT;
                end
            end 
        end
        STOP_BIT: begin
            if(cycle_counter == CLK_PER_BIT - 1) begin
                next_state = CLEANUP;
            end
        end
        CLEANUP: begin
            next_state = IDLE;
        end
        default: begin
            next_state = IDLE;
        end
    endcase
end 

assign is_valid = data_valid;
assign got_break = break_detected;

endmodule

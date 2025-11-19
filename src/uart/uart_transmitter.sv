module uart_transmitter #(
    parameter int BIT_RATE = 9600,         // UART baud rate (bits per second)
    parameter int CLK_FREQ = 50_000_000,   // Clock frequency in Hz (50 MHz)
    parameter int PAYLOAD_BITS = 8,        // Number of data bits per frame
    parameter int STOP_BITS = 1            // Number of stop bits
)(
    // Clock and reset
    input wire clk,                        // System clock
    input wire resetn,                     // Active-low reset
    
    // Data input interface
    input wire [PAYLOAD_BITS-1:0] tx_data, // Data to transmit
    input wire tx_start,                   // Start transmission (pulse)
    
    // UART output
    output logic tx,                       // UART TX output pin
    output logic tx_busy                   // Busy flag (transmission in progress)
);

// ============================================
// LOCAL PARAMETERS (Timing calculations)
// ============================================
localparam int CLK_PER_BIT = CLK_FREQ / BIT_RATE;      // Clock cycles per UART bit
localparam int COUNT_REG_LEN = 1 + $clog2(CLK_PER_BIT); // Bit width for cycle counter register


// ============================================
// STATE MACHINE DEFINITION
// ============================================
typedef enum logic [2:0] {
    IDLE       ,    // Idle, waiting for tx_start
    START_BIT  ,    // Transmitting start bit (0)
    DATA_BITS  ,    // Transmitting data bits
    STOP_BIT   ,    // Transmitting stop bit (1)
    CLEANUP         // Cleanup before returning to IDLE
} state_t;


// ============================================
// INTERNAL REGISTERS
// ============================================

// State machine registers
state_t curr_state, next_state;           // Current and next FSM states

// Data transmission registers
reg [PAYLOAD_BITS-1:0] tx_shift_reg;      // Shift register holding data to transmit

// Timing and counting registers
reg [COUNT_REG_LEN-1:0] cycle_counter;    // Counts clock cycles within a bit period
reg [$clog2(PAYLOAD_BITS):0] bit_counter; // Counts which data bit is being sent (0-7)

// Output registers
reg tx_reg;                               // TX output register
reg busy_reg;                             // Busy flag register


// ============================================
// SEQUENTIAL LOGIC (Register Updates)
// ============================================

always_ff @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        cycle_counter <= 0;
        bit_counter <= 0;
        tx_shift_reg <= 0;
        tx_reg <= 1;          
        busy_reg <= 0;
    end else begin
        curr_state <= next_state;
        
        case (curr_state)
            IDLE: begin
                tx_reg <= 1;
                busy_reg <= 0;
                cycle_counter <= 0;
                bit_counter <= 0;
                
                if (tx_start) begin
                    tx_shift_reg <= tx_data;
                    busy_reg <= 1;
                end
            end
            
            START_BIT: begin
                tx_reg <= 0;
                
                if (cycle_counter == CLK_PER_BIT - 1) begin
                    cycle_counter <= 0;
                end else begin
                    cycle_counter <= cycle_counter + 1;
                end
            end
            
            DATA_BITS: begin
                tx_reg <= tx_shift_reg[bit_counter];
                
                if (cycle_counter == CLK_PER_BIT - 1) begin
                    cycle_counter <= 0;
                    bit_counter <= bit_counter + 1;
                end else begin
                    cycle_counter <= cycle_counter + 1;
                end
            end
            
            STOP_BIT: begin
                tx_reg <= 1;
                
                if (cycle_counter == CLK_PER_BIT - 1) begin
                    cycle_counter <= 0;
                end else begin
                    cycle_counter <= cycle_counter + 1;
                end
            end
            
            CLEANUP: begin
                tx_reg <= 1;
                busy_reg <= 0;
                cycle_counter <= 0;
                bit_counter <= 0;
            end
        endcase
    end
end


// ============================================
// COMBINATIONAL LOGIC (Next State Logic)
// ============================================

always_comb begin
    next_state = curr_state;
    
    case (curr_state)
        IDLE: begin
            if (tx_start) begin
                next_state = START_BIT;
            end
        end
        
        START_BIT: begin
            if (cycle_counter == CLK_PER_BIT - 1) begin
                next_state = DATA_BITS;
            end
        end
        
        DATA_BITS: begin
            if (cycle_counter == CLK_PER_BIT - 1) begin
                if (bit_counter == PAYLOAD_BITS - 1) begin
                    next_state = STOP_BIT;
                end
            end
        end
        
        STOP_BIT: begin
            if (cycle_counter == CLK_PER_BIT - 1) begin
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


// ============================================
// OUTPUT ASSIGNMENTS
// ============================================

assign tx = tx_reg;
assign tx_busy = busy_reg;

endmodule
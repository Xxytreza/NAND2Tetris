// UART Vector/Matrix Processor
// Receives vectors/matrices via UART, performs operations, sends results back
//
// Protocol (all values 32-bit, sent as 4 bytes little-endian):
// Command byte:
//   0x01: Vector Add
//   0x02: Vector Multiply (element-wise)
//   0x03: Vector Dot Product
//   0x04: Matrix Add
//
// Vector Operations Format:
//   [CMD][N][V1_0][V1_1]...[V1_N-1][V2_0][V2_1]...[V2_N-1]
//   Response: [RESULT_0][RESULT_1]...[RESULT_N-1] (or single value for dot)
//
// Matrix Operations Format:
//   [CMD][ROWS][COLS][M1_row0_col0][M1_row0_col1]...[M2_row0_col0]...
//   Response: [RESULT_row0_col0][RESULT_row0_col1]...

module uart_vector_processor #(
    parameter int BIT_RATE = 115200,      // Higher baud rate for faster data transfer
    parameter int CLK_FREQ = 50_000_000,
    parameter int MAX_VECT_SIZE = 16,     // Maximum vector size
    parameter int MAX_MAT_ROWS = 8,       // Maximum matrix rows
    parameter int MAX_MAT_COLS = 8        // Maximum matrix cols
)(
    input wire clk,
    input wire resetn,
    
    // UART interface
    input wire uart_rx,
    output wire uart_tx,
    
    // Status LEDs
    output wire led_busy,          // Processing
    output wire led_rx_active,     // Receiving data
    output wire led_tx_active,     // Transmitting result
    output wire led_error          // Error occurred
);

    // ============================================
    // STATE MACHINE
    // ============================================
    typedef enum logic [3:0] {
        IDLE,
        RX_SIZE_N,
        RX_SIZE_M,
        RX_VECTOR1,
        RX_VECTOR2,
        RX_MATRIX1,
        RX_MATRIX2,
        COMPUTE,
        TX_RESULT,
        ERROR
    } state_t;
    
    state_t state, next_state;
    
    // ============================================
    // UART SIGNALS
    // ============================================
    wire [7:0] rx_data;
    wire rx_valid;
    reg [7:0] tx_data;
    reg tx_start;
    wire tx_busy;
    
    // ============================================
    // DATA STORAGE
    // ============================================
    reg [7:0] command;
    reg [31:0] size_n;         // Vector size or matrix rows
    reg [31:0] size_m;         // Matrix columns
    
    // Vectors
    reg [31:0] vector1 [MAX_VECT_SIZE-1:0];
    reg [31:0] vector2 [MAX_VECT_SIZE-1:0];
    reg [31:0] vect_result [MAX_VECT_SIZE-1:0];
    
    // Matrices
    reg [31:0] matrix1 [MAX_MAT_ROWS-1:0][MAX_MAT_COLS-1:0];
    reg [31:0] matrix2 [MAX_MAT_ROWS-1:0][MAX_MAT_COLS-1:0];
    reg [31:0] mat_result [MAX_MAT_ROWS-1:0][MAX_MAT_COLS-1:0];
    
    // Scalar result (for dot product)
    reg [31:0] scalar_result;
    
    // ============================================
    // BYTE RECEPTION STATE
    // ============================================
    reg [1:0] byte_index;      // 0-3 for 32-bit values
    reg [31:0] temp_value;     // Accumulate 32-bit value
    reg [31:0] element_count;  // Current element being received
    reg [31:0] total_elements; // Total elements to receive
    
    // TX state tracking
    reg tx_busy_prev;          // Previous tx_busy state
    
    // ============================================
    // OPERATOR WIRES
    // ============================================
    wire [31:0] vect_add_out [MAX_VECT_SIZE-1:0];
    wire [31:0] vect_mult_out [MAX_VECT_SIZE-1:0];
    wire [31:0] vect_dot_out;
    wire [31:0] mat_add_out [MAX_MAT_ROWS-1:0][MAX_MAT_COLS-1:0];
    
    // ============================================
    // UART MODULES
    // ============================================
    uart_receiver #(
        .BIT_RATE(BIT_RATE),
        .CLK_FREQ(CLK_FREQ),
        .PAYLOAD_BITS(8),
        .EOF_BITS(1)
    ) uart_rx_inst (
        .clk(clk),
        .resetn(resetn),
        .receiver_pin(uart_rx),
        .enabled(1'b1),
        .data(rx_data),
        .is_valid(rx_valid),
        .got_break()
    );
    
    uart_transmitter #(
        .BIT_RATE(BIT_RATE),
        .CLK_FREQ(CLK_FREQ),
        .PAYLOAD_BITS(8),
        .STOP_BITS(1)
    ) uart_tx_inst (
        .clk(clk),
        .resetn(resetn),
        .tx_data(tx_data),
        .tx_start(tx_start),
        .tx(uart_tx),
        .tx_busy(tx_busy)
    );
    
    // ============================================
    // OPERATOR INSTANCES
    // ============================================
    vect_add_operator #(
        .MAX_N(MAX_VECT_SIZE)
    ) vect_add (
        .n(size_n),
        .v1(vector1),
        .v2(vector2),
        .result(vect_add_out)
    );
    
    vect_mult_operator #(
        .MAX_N(MAX_VECT_SIZE)
    ) vect_mult (
        .n(size_n),
        .v1(vector1),
        .v2(vector2),
        .result(vect_mult_out)
    );
    
    vect_dot_operator #(
        .MAX_N(MAX_VECT_SIZE)
    ) vect_dot (
        .n(size_n),
        .v1(vector1),
        .v2(vector2),
        .result(vect_dot_out)
    );
    
    mat_add_operator #(
        .MAX_N(MAX_MAT_ROWS),
        .MAX_M(MAX_MAT_COLS)
    ) mat_add (
        .n(size_n),
        .m(size_m),
        .m1(matrix1),
        .m2(matrix2),
        .result(mat_add_out)
    );
    
    // ============================================
    // MAIN STATE MACHINE
    // ============================================
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= IDLE;
            command <= 0;
            size_n <= 0;
            size_m <= 0;
            byte_index <= 0;
            temp_value <= 0;
            element_count <= 0;
            total_elements <= 0;
            tx_start <= 0;
            tx_data <= 0;
            tx_busy_prev <= 0;
            
            for (int i = 0; i < MAX_VECT_SIZE; i++) begin
                vector1[i] <= 0;
                vector2[i] <= 0;
                vect_result[i] <= 0;
            end
            
            for (int i = 0; i < MAX_MAT_ROWS; i++) begin
                for (int j = 0; j < MAX_MAT_COLS; j++) begin
                    matrix1[i][j] <= 0;
                    matrix2[i][j] <= 0;
                    mat_result[i][j] <= 0;
                end
            end
            
            scalar_result <= 0;
        end else begin
            state <= next_state;
            tx_start <= 0;  // Default
            
            case (state)
                IDLE: begin
                    if (rx_valid) begin
                        command <= rx_data;
                        byte_index <= 0;
                        element_count <= 0;
                        temp_value <= 0;
                    end
                end
                
                RX_SIZE_N: begin
                    if (rx_valid) begin
                        if (byte_index == 3) begin
                            size_n <= {rx_data, temp_value[23:0]};
                            byte_index <= 0;
                            temp_value <= 0;
                        end else begin
                            temp_value[byte_index*8 +: 8] <= rx_data;
                            byte_index <= byte_index + 1;
                        end
                    end
                end
                
                RX_SIZE_M: begin
                    if (rx_valid) begin
                        if (byte_index == 3) begin
                            size_m <= {rx_data, temp_value[23:0]};
                            byte_index <= 0;
                            temp_value <= 0;
                            total_elements <= {rx_data, temp_value[23:0]} * size_n;
                        end else begin
                            temp_value[byte_index*8 +: 8] <= rx_data;
                            byte_index <= byte_index + 1;
                        end
                    end
                end
                
                RX_VECTOR1, RX_VECTOR2: begin
                    if (rx_valid) begin
                        if (byte_index == 3) begin
                            if (state == RX_VECTOR1)
                                vector1[element_count] <= {rx_data, temp_value[23:0]};
                            else
                                vector2[element_count] <= {rx_data, temp_value[23:0]};
                            
                            byte_index <= 0;
                            temp_value <= 0;
                            // Reset element_count when transitioning to next state
                            if ((state == RX_VECTOR1 && element_count == size_n - 1) ||
                                (state == RX_VECTOR2 && element_count == size_n - 1)) begin
                                element_count <= 0;
                            end else begin
                                element_count <= element_count + 1;
                            end
                        end else begin
                            temp_value[byte_index*8 +: 8] <= rx_data;
                            byte_index <= byte_index + 1;
                        end
                    end
                end
                
                RX_MATRIX1, RX_MATRIX2: begin
                    if (rx_valid) begin
                        if (byte_index == 3) begin
                            // Calculate row and column from element_count
                            if (state == RX_MATRIX1)
                                matrix1[element_count / size_m][element_count % size_m] <= {rx_data, temp_value[23:0]};
                            else
                                matrix2[element_count / size_m][element_count % size_m] <= {rx_data, temp_value[23:0]};
                            
                            byte_index <= 0;
                            temp_value <= 0;
                            // Reset element_count when transitioning to next state
                            if ((state == RX_MATRIX1 && element_count == total_elements - 1) ||
                                (state == RX_MATRIX2 && element_count == total_elements - 1)) begin
                                element_count <= 0;
                            end else begin
                                element_count <= element_count + 1;
                            end
                        end else begin
                            temp_value[byte_index*8 +: 8] <= rx_data;
                            byte_index <= byte_index + 1;
                        end
                    end
                end
                
                COMPUTE: begin
                    // Copy results based on operation
                    case (command)
                        8'h01: begin // Vector Add
                            for (int i = 0; i < MAX_VECT_SIZE; i++)
                                vect_result[i] <= vect_add_out[i];
                        end
                        8'h02: begin // Vector Multiply
                            for (int i = 0; i < MAX_VECT_SIZE; i++)
                                vect_result[i] <= vect_mult_out[i];
                        end
                        8'h03: begin // Dot Product
                            scalar_result <= vect_dot_out;
                        end
                        8'h04: begin // Matrix Add
                            for (int i = 0; i < MAX_MAT_ROWS; i++)
                                for (int j = 0; j < MAX_MAT_COLS; j++)
                                    mat_result[i][j] <= mat_add_out[i][j];
                        end
                    endcase
                    element_count <= 0;
                    byte_index <= 0;
                    tx_busy_prev <= 0;  // Reset for TX_RESULT state
                end
                
                TX_RESULT: begin
                    // Track previous tx_busy state
                    tx_busy_prev <= tx_busy;
                    
                    // Send next byte when transmitter becomes ready (not busy and not just finishing)
                    if (!tx_busy && !tx_busy_prev && !tx_start) begin
                        // Send result bytes
                        if (command == 8'h03) begin
                            // Dot product - send single 32-bit value
                            tx_data <= scalar_result[byte_index*8 +: 8];
                        end else if (command == 8'h04) begin
                            // Matrix result - send matrix elements
                            tx_data <= mat_result[element_count / size_m][element_count % size_m][byte_index*8 +: 8];
                        end else begin
                            // Vector result - send array
                            tx_data <= vect_result[element_count][byte_index*8 +: 8];
                        end
                        
                        tx_start <= 1;
                    end
                    
                    // Update counters after completing transmission (falling edge of tx_busy)
                    if (tx_busy_prev && !tx_busy) begin
                        if (byte_index == 3) begin
                            byte_index <= 0;
                            element_count <= element_count + 1;
                        end else begin
                            byte_index <= byte_index + 1;
                        end
                    end
                end
                
                ERROR: begin
                    // Stay in error state until reset
                end
            endcase
        end
    end
    
    // ============================================
    // NEXT STATE LOGIC
    // ============================================
    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (rx_valid) begin
                    if (rx_data >= 8'h01 && rx_data <= 8'h04)
                        next_state = RX_SIZE_N;
                    else
                        next_state = ERROR;
                end
            end
            
            RX_SIZE_N: begin
                if (rx_valid && byte_index == 3) begin
                    if (command == 8'h04) // Matrix needs M dimension
                        next_state = RX_SIZE_M;
                    else
                        next_state = RX_VECTOR1;
                end
            end
            
            RX_SIZE_M: begin
                if (rx_valid && byte_index == 3)
                    next_state = RX_MATRIX1;
            end
            
            RX_VECTOR1: begin
                if (rx_valid && byte_index == 3 && element_count == size_n - 1)
                    next_state = RX_VECTOR2;
            end
            
            RX_VECTOR2: begin
                if (rx_valid && byte_index == 3 && element_count == size_n - 1)
                    next_state = COMPUTE;
            end
            
            RX_MATRIX1: begin
                if (rx_valid && byte_index == 3 && element_count == total_elements - 1)
                    next_state = RX_MATRIX2;
            end
            
            RX_MATRIX2: begin
                if (rx_valid && byte_index == 3 && element_count == total_elements - 1)
                    next_state = COMPUTE;
            end
            
            COMPUTE: begin
                next_state = TX_RESULT;
            end
            
            TX_RESULT: begin
                if (command == 8'h03) begin
                    // Dot product - 4 bytes total (element_count goes 0->1 after sending)
                    if (element_count >= 1 && byte_index == 0 && !tx_busy && !tx_start)
                        next_state = IDLE;
                end else if (command == 8'h04) begin
                    // Matrix - Rows*Cols*4 bytes
                    if (element_count >= total_elements && byte_index == 0 && !tx_busy && !tx_start)
                        next_state = IDLE;
                end else begin
                    // Vector - N*4 bytes (element_count reaches size_n after last element)
                    if (element_count >= size_n && byte_index == 0 && !tx_busy && !tx_start)
                        next_state = IDLE;
                end
            end
            
            ERROR: begin
                next_state = ERROR;
            end
        endcase
    end
    
    // ============================================
    // STATUS OUTPUTS
    // ============================================
    assign led_busy = (state != IDLE && state != ERROR);
    assign led_rx_active = (state >= RX_SIZE_N && state <= RX_MATRIX2);
    assign led_tx_active = (state == TX_RESULT);
    assign led_error = (state == ERROR);

endmodule

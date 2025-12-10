// UART Matrix Echo Module
// Receives matrices via UART and echoes them back
// Protocol:
//   1. Receive Op Code (1 byte)
//   2. Receive Matrix1 Rows (1 byte)
//   3. Receive Matrix1 Cols (1 byte)
//   4. Receive Matrix1 Elements (Rows*Cols * 4 bytes, little-endian)
//   5. Receive Matrix2 Rows (1 byte)
//   6. Receive Matrix2 Cols (1 byte)
//   7. Receive Matrix2 Elements (Rows*Cols * 4 bytes, little-endian)
//   8. Perform operation: 
//      - If Op Code == 0: result = mat1 + mat2 (element-wise)
//      - If Op Code == 1: result = mat1 * mat2 (element-wise)
//      - If Op Code == 2: result = mat1 x mat2 (matrix multiplication)
//   9. Echo back result: Rows (1 byte) + Cols (1 byte) + Elements

module matrix_processor (
    input wire clk,           // 50MHz clock
    input wire resetn,        // Active low reset
    
    // UART
    input wire uart_rx,
    output wire uart_tx,
    
    // Status LEDs
    output wire [7:0] led
);

    // Parameters
    parameter CLK_HZ = 50_000_000;
    parameter BIT_RATE = 115200;
    parameter PAYLOAD_BITS = 8;
    parameter MAX_ELEMENTS = 1024; // Max total elements (e.g. 32x32)

    // UART RX signals
    wire [PAYLOAD_BITS-1:0] uart_rx_data;
    wire uart_rx_valid;
    wire uart_rx_break;

    // UART TX signals
    wire uart_tx_busy;
    reg [PAYLOAD_BITS-1:0] uart_tx_data;
    reg uart_tx_en;

    // Matrix storage
    reg [7:0] mat1_rows, mat1_cols;
    reg [31:0] mat1_data [0:MAX_ELEMENTS-1];
    reg [7:0] mat2_rows, mat2_cols;
    reg [31:0] mat2_data [0:MAX_ELEMENTS-1];
    
    // Result matrix
    reg [31:0] result_data [0:MAX_ELEMENTS-1];
    
    // Operation code
    reg [7:0] op_code;

    // State machine
    typedef enum logic [4:0] {
        IDLE,           // Wait for Op Code
        RECV_M1_ROWS,
        RECV_M1_COLS,
        RECV_M1_DATA,
        RECV_M2_ROWS,
        RECV_M2_COLS,
        RECV_M2_DATA,
        COMPUTE_FETCH,
        COMPUTE_EXEC,
        COMPUTE_MUL_INIT,
        COMPUTE_MUL_PRE,
        COMPUTE_MUL_WAIT,
        COMPUTE_MUL_ACC,
        COMPUTE_MUL_SAVE,
        PRE_SEND,
        SEND_ROWS,
        WAIT_ROWS,
        SEND_COLS,
        WAIT_COLS,
        SEND_DATA_FETCH,
        SEND_DATA,
        WAIT_DATA
    } state_t;
    
    state_t state, next_state;
    
    // Counters
    reg [15:0] element_count;      // Which element we're on
    reg [15:0] total_elements;     // Total elements to receive/send
    reg [1:0] byte_count;         // Which byte of current element (0-3)
    reg [15:0] total_bytes_sent;   // Total bytes transmitted
    
    // Temporary storage
    reg [31:0] temp_element;
    
    // Pipeline registers for RAM access
    reg [31:0] mat1_q, mat2_q, result_q;
    
    // Multiplication counters
    reg [7:0] mul_i, mul_j, mul_k;
    reg [31:0] mul_acc;
    reg [15:0] addr_a, addr_b, addr_a_start, addr_b_start;
    
    // LED status register
    reg [7:0] led_reg;
    assign led = led_reg;

    // UART RX instance
    uart_rx #(
        .BIT_RATE(BIT_RATE),
        .PAYLOAD_BITS(PAYLOAD_BITS),
        .CLK_HZ(CLK_HZ)
    ) i_uart_rx (
        .clk(clk),
        .resetn(resetn),
        .uart_rxd(uart_rx),
        .uart_rx_en(1'b1),
        .uart_rx_break(uart_rx_break),
        .uart_rx_valid(uart_rx_valid),
        .uart_rx_data(uart_rx_data)
    );

    // UART TX instance
    uart_tx #(
        .BIT_RATE(BIT_RATE),
        .PAYLOAD_BITS(PAYLOAD_BITS),
        .CLK_HZ(CLK_HZ)
    ) i_uart_tx (
        .clk(clk),
        .resetn(resetn),
        .uart_txd(uart_tx),
        .uart_tx_en(uart_tx_en),
        .uart_tx_busy(uart_tx_busy),
        .uart_tx_data(uart_tx_data)
    );

    // RAM Read Logic
    always_ff @(posedge clk) begin
        if (state == COMPUTE_MUL_PRE || state == COMPUTE_MUL_WAIT || state == COMPUTE_MUL_ACC) begin
            mat1_q <= mat1_data[addr_a];
            mat2_q <= mat2_data[addr_b];
        end else begin
            mat1_q <= mat1_data[element_count];
            mat2_q <= mat2_data[element_count];
        end
        result_q <= result_data[element_count];
    end

    // State machine - next state logic
    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (uart_rx_valid)
                    next_state = RECV_M1_ROWS;
            end

            RECV_M1_ROWS: begin
                if (uart_rx_valid)
                    next_state = RECV_M1_COLS;
            end

            RECV_M1_COLS: begin
                if (uart_rx_valid)
                    next_state = RECV_M1_DATA;
            end
            
            RECV_M1_DATA: begin
                if (uart_rx_valid && byte_count == 3 && element_count == total_elements - 1)
                    next_state = RECV_M2_ROWS;
            end

            RECV_M2_ROWS: begin
                if (uart_rx_valid)
                    next_state = RECV_M2_COLS;
            end

            RECV_M2_COLS: begin
                if (uart_rx_valid)
                    next_state = RECV_M2_DATA;
            end
            
            RECV_M2_DATA: begin
                if (uart_rx_valid && byte_count == 3 && element_count == total_elements - 1) begin
                    if (op_code == 8'd2)
                        next_state = COMPUTE_MUL_INIT;
                    else
                        next_state = COMPUTE_FETCH;
                end
            end
            
            COMPUTE_FETCH: begin
                next_state = COMPUTE_EXEC;
            end

            COMPUTE_EXEC: begin
                if (element_count >= total_elements - 1) // -1 because we increment in this state
                    next_state = PRE_SEND;
                else
                    next_state = COMPUTE_FETCH;
            end
            
            COMPUTE_MUL_INIT: next_state = COMPUTE_MUL_PRE;
            
            COMPUTE_MUL_PRE: next_state = COMPUTE_MUL_WAIT;
            
            COMPUTE_MUL_WAIT: next_state = COMPUTE_MUL_ACC;

            COMPUTE_MUL_ACC: begin
                if (mul_k == mat1_cols - 1)
                    next_state = COMPUTE_MUL_SAVE;
                else
                    next_state = COMPUTE_MUL_WAIT;
            end

            COMPUTE_MUL_SAVE: begin
                if (mul_j == mat2_cols - 1 && mul_i == mat1_rows - 1)
                    next_state = PRE_SEND;
                else
                    next_state = COMPUTE_MUL_PRE;
            end
            
            PRE_SEND: begin
                if (!uart_tx_busy)
                    next_state = SEND_ROWS;
            end
            
            SEND_ROWS: begin
                next_state = WAIT_ROWS;
            end
            
            WAIT_ROWS: begin
                if (!uart_tx_busy && !uart_tx_en)
                    next_state = SEND_COLS;
            end
            
            SEND_COLS: begin
                next_state = WAIT_COLS;
            end
            
            WAIT_COLS: begin
                if (!uart_tx_busy && !uart_tx_en)
                    next_state = SEND_DATA_FETCH;
            end
            
            SEND_DATA_FETCH: begin
                next_state = SEND_DATA;
            end

            SEND_DATA: begin
                next_state = WAIT_DATA;
            end
            
            WAIT_DATA: begin
                if (!uart_tx_busy && !uart_tx_en) begin
                    if (total_bytes_sent > (mat1_rows * mat1_cols * 4))
                        next_state = IDLE;
                    else begin
                        // If we just finished a word (byte_count wrapped to 0), we need to fetch next
                        if (byte_count == 0)
                             next_state = SEND_DATA_FETCH;
                        else
                             next_state = SEND_DATA;
                    end
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

    // State machine - state register
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Main control logic
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            op_code <= 8'd0;
            mat1_rows <= 8'd0; mat1_cols <= 8'd0;
            mat2_rows <= 8'd0; mat2_cols <= 8'd0;
            element_count <= 16'd0;
            total_elements <= 16'd0;
            byte_count <= 2'd0;
            temp_element <= 32'd0;
            uart_tx_data <= 8'd0;
            uart_tx_en <= 1'b0;
            total_bytes_sent <= 16'd0;
            led_reg <= 8'h00;
            
            // Clear storage - REMOVED to allow BRAM inference
            // for (int i = 0; i < MAX_ELEMENTS; i++) begin
            //     mat1_data[i] <= 32'd0;
            //     mat2_data[i] <= 32'd0;
            // end
                
        end else begin
            uart_tx_en <= 1'b0;  // Default: no transmission
            
            case (state)
                IDLE: begin
                    byte_count <= 2'd0;
                    total_bytes_sent <= 16'd0;
                    temp_element <= 32'd0;
                    
                    if (uart_rx_valid) begin
                        op_code <= uart_rx_data;
                        led_reg <= 8'h01;
                    end else begin
                        led_reg <= 8'h00;
                    end
                end

                RECV_M1_ROWS: begin
                    if (uart_rx_valid) begin
                        mat1_rows <= uart_rx_data;
                    end
                end

                RECV_M1_COLS: begin
                    if (uart_rx_valid) begin
                        mat1_cols <= uart_rx_data;
                        total_elements <= {8'd0, mat1_rows} * {8'd0, uart_rx_data}; // Calculate total elements (16-bit)
                        element_count <= 16'd0;
                        byte_count <= 2'd0;
                        led_reg <= {4'h0, uart_rx_data[3:0]};
                    end
                end
                
                RECV_M1_DATA: begin
                    if (uart_rx_valid) begin
                        case (byte_count)
                            2'd0: temp_element[7:0]   <= uart_rx_data;
                            2'd1: temp_element[15:8]  <= uart_rx_data;
                            2'd2: temp_element[23:16] <= uart_rx_data;
                            2'd3: temp_element[31:24] <= uart_rx_data;
                        endcase
                        
                        if (byte_count == 2'd3) begin
                            mat1_data[element_count] <= {uart_rx_data, temp_element[23:0]};
                            if (element_count == total_elements - 1) begin
                                element_count <= 16'd0;
                            end else begin
                                element_count <= element_count + 1'b1;
                            end
                            byte_count <= 2'd0;
                        end else begin
                            byte_count <= byte_count + 1'b1;
                        end
                    end
                end

                RECV_M2_ROWS: begin
                    if (uart_rx_valid) begin
                        mat2_rows <= uart_rx_data;
                    end
                end

                RECV_M2_COLS: begin
                    if (uart_rx_valid) begin
                        mat2_cols <= uart_rx_data;
                        total_elements <= {8'd0, mat2_rows} * {8'd0, uart_rx_data};
                        element_count <= 16'd0;
                        byte_count <= 2'd0;
                        led_reg <= {4'hF, uart_rx_data[3:0]};
                    end
                end
                
                RECV_M2_DATA: begin
                    if (uart_rx_valid) begin
                        case (byte_count)
                            2'd0: temp_element[7:0]   <= uart_rx_data;
                            2'd1: temp_element[15:8]  <= uart_rx_data;
                            2'd2: temp_element[23:16] <= uart_rx_data;
                            2'd3: temp_element[31:24] <= uart_rx_data;
                        endcase
                        
                        if (byte_count == 2'd3) begin
                            mat2_data[element_count] <= {uart_rx_data, temp_element[23:0]};
                            if (element_count == total_elements - 1) begin
                                element_count <= 16'd0; // Reset for COMPUTE
                            end else begin
                                element_count <= element_count + 1'b1;
                            end
                            byte_count <= 2'd0;
                        end else begin
                            byte_count <= byte_count + 1'b1;
                        end
                    end
                end
                
                COMPUTE_FETCH: begin
                    // Wait for RAM read
                end

                COMPUTE_EXEC: begin
                    if (op_code == 8'd0) begin
                        // Addition
                        result_data[element_count] <= mat1_q + mat2_q;
                    end else if (op_code == 8'd1) begin
                        // Element-wise Multiplication
                        result_data[element_count] <= mat1_q * mat2_q;
                    end else begin
                        // Default echo mat1
                        result_data[element_count] <= mat1_q;
                    end
                    
                    element_count <= element_count + 1'b1;
                end
                
                COMPUTE_MUL_INIT: begin
                    mul_i <= 8'd0;
                    mul_j <= 8'd0;
                    addr_a_start <= 16'd0;
                    addr_b_start <= 16'd0;
                    element_count <= 16'd0; // Used for result index
                end
                
                COMPUTE_MUL_PRE: begin
                    mul_k <= 8'd0;
                    mul_acc <= 32'd0;
                    addr_a <= addr_a_start;
                    addr_b <= addr_b_start;
                end

                COMPUTE_MUL_ACC: begin
                    // acc += A[addr_a] * B[addr_b]
                    mul_acc <= mul_acc + mat1_q * mat2_q;
                    
                    addr_a <= addr_a + 1'b1;
                    addr_b <= addr_b + mat2_cols;
                    
                    if (mul_k == mat1_cols - 1) begin
                        // Done with this cell
                    end else begin
                        mul_k <= mul_k + 1'b1;
                    end
                end

                COMPUTE_MUL_SAVE: begin
                    result_data[element_count] <= mul_acc;
                    element_count <= element_count + 1'b1;
                    
                    if (mul_j == mat2_cols - 1) begin
                        mul_j <= 8'd0;
                        addr_b_start <= 16'd0;
                        
                        if (mul_i == mat1_rows - 1) begin
                            // Finished all
                            mat1_cols <= mat2_cols; // Update cols for sending
                        end else begin
                            mul_i <= mul_i + 1'b1;
                            addr_a_start <= addr_a_start + mat1_cols;
                        end
                    end else begin
                        mul_j <= mul_j + 1'b1;
                        addr_b_start <= addr_b_start + 1'b1;
                    end
                end
                
                SEND_ROWS: begin
                    uart_tx_data <= mat1_rows;
                    uart_tx_en <= 1'b1;
                end
                
                WAIT_ROWS: begin
                    // Wait for transmission to complete
                end
                
                SEND_COLS: begin
                    uart_tx_data <= mat1_cols;
                    uart_tx_en <= 1'b1;
                    element_count <= 16'd0;
                    byte_count <= 2'd0;
                    total_bytes_sent <= 16'd1;
                end
                
                WAIT_COLS: begin
                    // Wait
                end
                
                SEND_DATA_FETCH: begin
                    // Wait for RAM read
                end
                
                SEND_DATA: begin
                    if (total_bytes_sent <= (mat1_rows * mat1_cols * 4)) begin
                        case (byte_count)
                            2'd0: uart_tx_data <= result_q[7:0];
                            2'd1: uart_tx_data <= result_q[15:8];
                            2'd2: uart_tx_data <= result_q[23:16];
                            2'd3: uart_tx_data <= result_q[31:24];
                        endcase
                        uart_tx_en <= 1'b1;
                        
                        total_bytes_sent <= total_bytes_sent + 1'b1;
                        
                        if (byte_count == 2'd3) begin
                            byte_count <= 2'd0;
                            element_count <= element_count + 1'b1;
                        end else begin
                            byte_count <= byte_count + 1'b1;
                        end
                    end
                end
                
                WAIT_DATA: begin
                    // Wait
                end
                
                default: begin
                    // Do nothing
                end
            endcase
        end
    end

endmodule

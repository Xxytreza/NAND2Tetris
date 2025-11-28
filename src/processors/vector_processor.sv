// UART Vector Echo Module
// Receives vectors via UART and echoes them back
// Protocol:
//   1. Receive Op Code (1 byte)
//   2. Receive vector1 size (1 byte: n, where 1 <= n <= 128)
//   3. Receive n vector1 elements (4 bytes each, little-endian)
//   4. Receive vector2 size (1 byte: m, where 1 <= m <= 128)
//   5. Receive m vector2 elements (4 bytes each, little-endian)
//   6. Perform operation: 
//      - If Op Code == 0: result = vector1 + vector2 (element-wise)
//      - If Op Code == 1: result = dot_product(vector1, vector2) (scalar)
//      - If Op Code == 2: result = vector1 * vector2 (element-wise)
//   7. Echo back result vector: size + elements (size = min(n, m) for add/mult, 1 for dot)

module vector_processor (
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
    parameter MAX_VECTOR_SIZE = 128;

    // UART RX signals
    wire [PAYLOAD_BITS-1:0] uart_rx_data;
    wire uart_rx_valid;
    wire uart_rx_break;

    // UART TX signals
    wire uart_tx_busy;
    reg [PAYLOAD_BITS-1:0] uart_tx_data;
    reg uart_tx_en;

    // Vector storage
    reg [7:0] vector1_size;
    reg [31:0] vector1_data [0:MAX_VECTOR_SIZE-1];
    reg [7:0] vector2_size;
    reg [31:0] vector2_data [0:MAX_VECTOR_SIZE-1];
    
    // Result vector from addition
    reg [31:0] result_data [0:MAX_VECTOR_SIZE-1];
    reg [7:0] result_size;
    
    // Operation code
    reg [7:0] op_code;

    // State machine
    typedef enum logic [3:0] {
        IDLE,           // Wait for Op Code
        RECV_V1_SIZE,   // Wait for Vector 1 Size
        RECV_VECTOR1,
        RECV_V2_SIZE,   // Wait for Vector 2 Size
        RECV_VECTOR2,
        COMPUTE,
        SEND_SIZE,
        SEND_RESULT
    } state_t;
    
    state_t state, next_state;
    
    // Counters
    reg [7:0] element_count;      // Which element we're on (0 to vector_size-1)
    reg [1:0] byte_count;         // Which byte of current element (0-3)
    reg [7:0] total_bytes_sent;   // Total bytes transmitted
    
    // Temporary storage for building 32-bit elements
    reg [31:0] temp_element;
    reg [31:0] dot_prod_acc;
    
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

    // State machine - next state logic
    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (uart_rx_valid)
                    next_state = RECV_V1_SIZE;
            end

            RECV_V1_SIZE: begin
                if (uart_rx_valid)
                    next_state = RECV_VECTOR1;
            end
            
            RECV_VECTOR1: begin
                if (uart_rx_valid && byte_count == 3 && element_count == vector1_size - 1)
                    next_state = RECV_V2_SIZE;
            end

            RECV_V2_SIZE: begin
                if (uart_rx_valid)
                    next_state = RECV_VECTOR2;
            end
            
            RECV_VECTOR2: begin
                if (uart_rx_valid && byte_count == 3 && element_count == vector2_size - 1)
                    next_state = COMPUTE;
            end
            
            COMPUTE: begin
                if (op_code == 8'd0) begin
                    if (element_count >= result_size)
                        next_state = SEND_SIZE;
                    else
                        next_state = COMPUTE;
                end else if (op_code == 8'd1) begin
                    if (element_count >= result_size)
                        next_state = SEND_SIZE;
                    else
                        next_state = COMPUTE;
                end else if (op_code == 8'd2) begin
                    if (element_count >= result_size)
                        next_state = SEND_SIZE;
                    else
                        next_state = COMPUTE;
                end else
                    next_state = SEND_SIZE;
            end

            SEND_SIZE: begin
                if (uart_tx_en)
                    next_state = SEND_RESULT;
            end
            
            SEND_RESULT: begin
                if (!uart_tx_busy && total_bytes_sent > (result_size * 4))
                    next_state = IDLE;
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
            vector1_size <= 8'd0;
            vector2_size <= 8'd0;
            result_size <= 8'd0;
            element_count <= 8'd0;
            byte_count <= 2'd0;
            temp_element <= 32'd0;
            uart_tx_data <= 8'd0;
            uart_tx_en <= 1'b0;
            total_bytes_sent <= 8'd0;
            led_reg <= 8'h00;
            
            // Clear vector storage
            for (int i = 0; i < MAX_VECTOR_SIZE; i++) begin
                vector1_data[i] <= 32'd0;
                vector2_data[i] <= 32'd0;
                result_data[i] <= 32'd0;
            end
                
        end else begin
            uart_tx_en <= 1'b0;  // Default: no transmission
            
            case (state)
                IDLE: begin
                    byte_count <= 2'd0;
                    total_bytes_sent <= 8'd0;
                    temp_element <= 32'd0;
                    dot_prod_acc <= 32'd0;
                    
                    if (uart_rx_valid) begin
                        op_code <= uart_rx_data;
                        // Reset sizes for new transaction
                        vector1_size <= 8'd0;
                        vector2_size <= 8'd0;
                        result_size <= 8'd0;
                        led_reg <= 8'h01; // Indicate Op Code received
                    end else begin
                        led_reg <= 8'h00;
                    end
                end

                RECV_V1_SIZE: begin
                    if (uart_rx_valid) begin
                        vector1_size <= uart_rx_data;
                        element_count <= 8'd0;
                        byte_count <= 2'd0;
                        led_reg <= {4'h0, uart_rx_data[3:0]};
                    end
                end
                
                RECV_VECTOR1: begin
                    if (uart_rx_valid) begin
                        // Build element byte by byte (little-endian)
                        case (byte_count)
                            2'd0: temp_element[7:0]   <= uart_rx_data;
                            2'd1: temp_element[15:8]  <= uart_rx_data;
                            2'd2: temp_element[23:16] <= uart_rx_data;
                            2'd3: temp_element[31:24] <= uart_rx_data;
                        endcase
                        
                        if (byte_count == 2'd3) begin
                            // Store complete element
                            vector1_data[element_count] <= {uart_rx_data, temp_element[23:0]};
                            
                            if (element_count == vector1_size - 1) begin
                                element_count <= 8'd0; // Reset for next state
                            end else begin
                                element_count <= element_count + 1'b1;
                            end
                            
                            byte_count <= 2'd0;
                        end else begin
                            byte_count <= byte_count + 1'b1;
                        end
                    end
                end

                RECV_V2_SIZE: begin
                    if (uart_rx_valid) begin
                        vector2_size <= uart_rx_data;
                        // Calculate result size as minimum of the two
                        result_size <= (uart_rx_data < vector1_size) ? uart_rx_data : vector1_size;
                        element_count <= 8'd0;
                        byte_count <= 2'd0;
                        led_reg <= {4'hF, uart_rx_data[3:0]};
                    end
                end
                
                RECV_VECTOR2: begin
                    if (uart_rx_valid) begin
                        // Build element byte by byte (little-endian)
                        case (byte_count)
                            2'd0: temp_element[7:0]   <= uart_rx_data;
                            2'd1: temp_element[15:8]  <= uart_rx_data;
                            2'd2: temp_element[23:16] <= uart_rx_data;
                            2'd3: temp_element[31:24] <= uart_rx_data;
                        endcase
                        
                        if (byte_count == 2'd3) begin
                            // Store complete element
                            vector2_data[element_count] <= {uart_rx_data, temp_element[23:0]};
                            
                            if (element_count == vector2_size - 1) begin
                                element_count <= 8'd0; // Reset for COMPUTE
                            end else begin
                                element_count <= element_count + 1'b1;
                            end
                            
                            byte_count <= 2'd0;
                        end else begin
                            byte_count <= byte_count + 1'b1;
                        end
                    end
                end
                
                COMPUTE: begin
                    if (op_code == 8'd0) begin
                        // Perform vector addition iteratively
                        if (element_count < result_size) begin
                            result_data[element_count] <= vector1_data[element_count] + vector2_data[element_count];
                            element_count <= element_count + 1'b1;
                        end else begin
                            // Done
                        end
                    end else if (op_code == 8'd1) begin
                        // Perform dot product iteratively
                        if (element_count < result_size) begin
                            dot_prod_acc <= dot_prod_acc + (vector1_data[element_count] * vector2_data[element_count]);
                            element_count <= element_count + 1'b1;
                        end else begin
                            result_data[0] <= dot_prod_acc;
                            result_size <= 8'd1;
                        end
                    end else if (op_code == 8'd2) begin
                        // Perform vector multiplication iteratively
                        if (element_count < result_size) begin
                            result_data[element_count] <= vector1_data[element_count] * vector2_data[element_count];
                            element_count <= element_count + 1'b1;
                        end else begin
                            // Done
                        end
                    end
                    led_reg <= 8'hCC;  // Computing pattern
                end
                
                SEND_SIZE: begin
                    if (!uart_tx_busy) begin
                        uart_tx_data <= result_size;
                        uart_tx_en <= 1'b1;
                        element_count <= 8'd0;
                        byte_count <= 2'd0;
                        total_bytes_sent <= 8'd1;
                        led_reg <= 8'hFF;  // All LEDs on during transmission
                    end
                end
                
                SEND_RESULT: begin
                    if (!uart_tx_busy && !uart_tx_en && total_bytes_sent <= (result_size * 4)) begin
                        // Send current byte from result
                        case (byte_count)
                            2'd0: uart_tx_data <= result_data[element_count][7:0];
                            2'd1: uart_tx_data <= result_data[element_count][15:8];
                            2'd2: uart_tx_data <= result_data[element_count][23:16];
                            2'd3: uart_tx_data <= result_data[element_count][31:24];
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
                
                default: begin
                    // Do nothing
                end
            endcase
        end
    end

endmodule

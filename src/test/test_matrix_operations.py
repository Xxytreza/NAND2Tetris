#!/usr/bin/env python3
"""
UART Matrix Operations Test
Tests Addition, Element-wise Multiplication, and Matrix Multiplication
with formatted output.
"""

import serial
import time
import sys
import struct

def format_matrix_output(data, rows, cols):
    """Formats matrix data for display based on dimensions"""
    if not data:
        return "[]"
        
    if rows == 1 or cols == 1:
        # Vector format: [1, 2, 3]
        return str(data)
    else:
        # Matrix format: [[1, 2], [3, 4]]
        matrix = []
        for r in range(rows):
            row = data[r*cols : (r+1)*cols]
            matrix.append(row)
        return str(matrix)

def send_op_code(ser, op_code):
    """Send operation code via UART"""
    ser.write(bytes([op_code]))
    # print(f"Sent Op Code: {op_code}")

def send_matrix(ser, matrix, rows, cols, label=""):
    """Send a matrix via UART"""
    if not matrix or len(matrix) > 32:
        raise ValueError(f"Matrix size {len(matrix)} exceeds limit of 32 elements")
    
    ser.write(bytes([rows]))
    ser.write(bytes([cols]))
    
    # Format for display
    display_str = format_matrix_output(matrix, rows, cols)
    print(f"{label} ({rows}x{cols}): {display_str}")
    
    for val in matrix:
        packed = struct.pack('<i', val)
        ser.write(packed)
    
    ser.flush()

def receive_matrix(ser, label=""):
    """Receive a matrix via UART"""
    rows_byte = ser.read(1)
    if len(rows_byte) != 1:
        raise Exception(f"{label}Failed to receive rows byte")
    rows = rows_byte[0]
    
    cols_byte = ser.read(1)
    if len(cols_byte) != 1:
        raise Exception(f"{label}Failed to receive cols byte")
    cols = cols_byte[0]
    
    size = rows * cols
    vector = []
    for i in range(size):
        element_bytes = ser.read(4)
        if len(element_bytes) != 4:
            raise Exception(f"{label}Failed to receive element {i}")
        
        val = struct.unpack('<i', element_bytes)[0]
        vector.append(val)
    
    display_str = format_matrix_output(vector, rows, cols)
    print(f"{label} ({rows}x{cols}): {display_str}")
    
    return vector

def run_test_case(ser, op_code, name, m1_dims, m1_data, m2_dims, m2_data, expected):
    print(f"\nTest: {name}")
    print("-" * 60)
    
    try:
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        time.sleep(0.1)
        
        # Send Op Code
        send_op_code(ser, op_code)
        time.sleep(0.05)

        # Send Matrices
        send_matrix(ser, m1_data, m1_dims[0], m1_dims[1], "Sent M1")
        time.sleep(0.05)
        send_matrix(ser, m2_data, m2_dims[0], m2_dims[1], "Sent M2")
        
        # Wait for processing
        time.sleep(0.2 + (len(m1_data) + len(m2_data)) * 0.01)
        
        # Receive result
        result = receive_matrix(ser, "Received")
        
        # Verify
        if result == expected:
            print("STATUS: PASS")
            return True
        else:
            print(f"STATUS: FAIL")
            print(f"Expected: {format_matrix_output(expected, m1_dims[0] if op_code!=2 else m1_dims[0], m1_dims[1] if op_code!=2 else m2_dims[1])}")
            return False
            
    except Exception as e:
        print(f"STATUS: ERROR ({e})")
        return False

def main(port='COM3', baudrate=115200):
    print(f"Opening {port} at {baudrate} baud...")
    
    try:
        with serial.Serial(port, baudrate, timeout=5) as ser:
            time.sleep(1) # Wait for board to reset/stabilize
            
            # ==========================================
            # Op Code 0: Matrix Addition
            # ==========================================
            print("\n" + "="*40)
            print("=== Testing Matrix Addition (Op Code 0) ===")
            print("="*40)
            
            # 3x3 Addition
            run_test_case(ser, 0, "3x3 Matrix Addition",
                         (3, 3), [1, 2, 3, 4, 5, 6, 7, 8, 9],
                         (3, 3), [9, 8, 7, 6, 5, 4, 3, 2, 1],
                         [10, 10, 10, 10, 10, 10, 10, 10, 10])

            # 5x5 Addition (Max Square)
            m_5x5_ones = [1] * 25
            m_5x5_twos = [2] * 25
            m_5x5_threes = [3] * 25
            run_test_case(ser, 0, "5x5 Matrix Addition",
                         (5, 5), m_5x5_ones,
                         (5, 5), m_5x5_twos,
                         m_5x5_threes)

            # Max Size 4x8 (Edge Case)
            m1_max = list(range(32))
            m2_max = list(range(32, 0, -1))
            expected_max = [32] * 32
            run_test_case(ser, 0, "Max Size (4x8) Addition",
                         (4, 8), m1_max,
                         (4, 8), m2_max,
                         expected_max)

            # ==========================================
            # Op Code 1: Element-wise Multiplication
            # ==========================================
            print("\n" + "="*40)
            print("=== Testing Element-wise Multiplication (Op Code 1) ===")
            print("="*40)
            
            # 3x3 Element-wise
            run_test_case(ser, 1, "3x3 Element-wise",
                         (3, 3), [1, 2, 3, 4, 5, 6, 7, 8, 9],
                         (3, 3), [2, 2, 2, 2, 2, 2, 2, 2, 2],
                         [2, 4, 6, 8, 10, 12, 14, 16, 18])

            # 5x5 Element-wise
            run_test_case(ser, 1, "5x5 Element-wise",
                         (5, 5), m_5x5_twos,
                         (5, 5), m_5x5_threes,
                         [6] * 25)

            # ==========================================
            # Op Code 2: Matrix Multiplication
            # ==========================================
            print("\n" + "="*40)
            print("=== Testing Matrix Multiplication (Op Code 2) ===")
            print("="*40)
            
            # 3x3 * 3x3
            # Identity check
            run_test_case(ser, 2, "3x3 * 3x3 Identity",
                         (3, 3), [1, 2, 3, 4, 5, 6, 7, 8, 9],
                         (3, 3), [1, 0, 0, 0, 1, 0, 0, 0, 1],
                         [1, 2, 3, 4, 5, 6, 7, 8, 9])

            # 4x4 * 4x4 (All 1s)
            # Result should be 4x4 of 4s
            m_4x4_ones = [1] * 16
            m_4x4_fours = [4] * 16
            run_test_case(ser, 2, "4x4 * 4x4 (All Ones)",
                         (4, 4), m_4x4_ones,
                         (4, 4), m_4x4_ones,
                         m_4x4_fours)

            # 5x5 * 5x5 (All 1s * All 2s)
            # Result should be 5x5 of 10s (1*2 + 1*2 + 1*2 + 1*2 + 1*2)
            m_5x5_tens = [10] * 25
            run_test_case(ser, 2, "5x5 * 5x5 (Ones * Twos)",
                         (5, 5), m_5x5_ones,
                         (5, 5), m_5x5_twos,
                         m_5x5_tens)

            # 4x8 * 8x1 (Max Input Size -> Small Output)
            # 4x8 of 1s * 8x1 of 1s
            # Result 4x1 of 8s
            m_4x8_ones = [1] * 32
            m_8x1_ones = [1] * 8
            m_4x1_eights = [8] * 4
            run_test_case(ser, 2, "4x8 * 8x1 (Max Input)",
                         (4, 8), m_4x8_ones,
                         (8, 1), m_8x1_ones,
                         m_4x1_eights)

            # 1x8 * 8x1 (Dot Product Max Length)
            # [1...1] * [1...1]^T = [8]
            run_test_case(ser, 2, "1x8 * 8x1 (Dot Product)",
                         (1, 8), [1]*8,
                         (8, 1), [1]*8,
                         [8])

    except serial.SerialException as e:
        print(f"Error opening serial port: {e}")
    except KeyboardInterrupt:
        print("\nTest interrupted by user")

if __name__ == "__main__":
    port = sys.argv[1] if len(sys.argv) > 1 else 'COM3'
    main(port)

#!/usr/bin/env python3
"""
UART Vector/Matrix Processor Client
Send vectors/matrices to FPGA, receive computed results

Protocol:
- Command: 1 byte
  0x01 = Vector Add
  0x02 = Vector Multiply (element-wise)
  0x03 = Vector Dot Product
  0x04 = Matrix Add
  
- Vector format: [CMD][N (4 bytes)][V1 elements (N*4 bytes)][V2 elements (N*4 bytes)]
- Matrix format: [CMD][ROWS (4 bytes)][COLS (4 bytes)][M1 elements][M2 elements]

All 32-bit values sent as little-endian.
"""

import serial
import struct
import sys
import time

class UARTVectorProcessor:
    def __init__(self, port='COM3', baudrate=115200):
        """
        Initialize UART connection to FPGA
        
        Args:
            port: Serial port (e.g., 'COM3' on Windows, '/dev/ttyUSB0' on Linux)
            baudrate: Baud rate (default 115200)
        """
        self.ser = serial.Serial(port, baudrate, timeout=2)
        time.sleep(0.1)  # Wait for connection
        print(f"Connected to {port} at {baudrate} baud")
    
    def _send_u32(self, value):
        """Send 32-bit unsigned integer as 4 bytes (little-endian)"""
        self.ser.write(struct.pack('<I', value))
    
    def _recv_u32(self):
        """Receive 32-bit unsigned integer (4 bytes, little-endian)"""
        data = self.ser.read(4)
        if len(data) != 4:
            raise TimeoutError("Did not receive expected 4 bytes")
        return struct.unpack('<I', data)[0]
    
    def _send_vector(self, vec):
        """Send vector elements"""
        for val in vec:
            self._send_u32(val)
    
    def _recv_vector(self, n):
        """Receive n vector elements"""
        return [self._recv_u32() for _ in range(n)]
    
    def vector_add(self, v1, v2):
        """
        Compute v1 + v2 on FPGA
        
        Args:
            v1, v2: Lists of integers (same length)
        Returns:
            List of results
        """
        if len(v1) != len(v2):
            raise ValueError("Vectors must have same length")
        
        n = len(v1)
        print(f"Vector Add: {n} elements")
        
        # Send command and size
        self.ser.write(b'\x01')  # Command: Vector Add
        self._send_u32(n)
        
        # Send vectors
        self._send_vector(v1)
        self._send_vector(v2)
        
        # Receive result
        result = self._recv_vector(n)
        print(f"Result received: {result}")
        return result
    
    def vector_multiply(self, v1, v2):
        """
        Compute element-wise v1 * v2 on FPGA
        
        Args:
            v1, v2: Lists of integers (same length)
        Returns:
            List of results
        """
        if len(v1) != len(v2):
            raise ValueError("Vectors must have same length")
        
        n = len(v1)
        print(f"Vector Multiply: {n} elements")
        
        self.ser.write(b'\x02')  # Command: Vector Multiply
        self._send_u32(n)
        self._send_vector(v1)
        self._send_vector(v2)
        
        result = self._recv_vector(n)
        print(f"Result received: {result}")
        return result
    
    def vector_dot(self, v1, v2):
        """
        Compute dot product v1 · v2 on FPGA
        
        Args:
            v1, v2: Lists of integers (same length)
        Returns:
            Scalar result
        """
        if len(v1) != len(v2):
            raise ValueError("Vectors must have same length")
        
        n = len(v1)
        print(f"Vector Dot Product: {n} elements")
        
        self.ser.write(b'\x03')  # Command: Dot Product
        self._send_u32(n)
        self._send_vector(v1)
        self._send_vector(v2)
        
        result = self._recv_u32()
        print(f"Dot product result: {result}")
        return result
    
    def matrix_add(self, m1, m2):
        """
        Compute m1 + m2 on FPGA
        
        Args:
            m1, m2: 2D lists (matrices) of same dimensions
        Returns:
            2D list (result matrix)
        """
        rows = len(m1)
        cols = len(m1[0])
        
        if len(m2) != rows or len(m2[0]) != cols:
            raise ValueError("Matrices must have same dimensions")
        
        print(f"Matrix Add: {rows}x{cols}")
        
        self.ser.write(b'\x04')  # Command: Matrix Add
        self._send_u32(rows)
        self._send_u32(cols)
        
        # Send matrix 1 (row-major order)
        for row in m1:
            for val in row:
                self._send_u32(val)
        
        # Send matrix 2
        for row in m2:
            for val in row:
                self._send_u32(val)
        
        # Receive result
        result = []
        for i in range(rows):
            row = []
            for j in range(cols):
                row.append(self._recv_u32())
            result.append(row)
        
        print("Result matrix:")
        for row in result:
            print(row)
        return result
    
    def close(self):
        """Close serial connection"""
        self.ser.close()
        print("Connection closed")


def main():
    """Example usage"""
    # Adjust port for your system
    # Windows: 'COM3', 'COM4', etc.
    # WSL: '/dev/ttyS3' (for COM3), '/dev/ttyS4' (for COM4), etc.
    # Linux: '/dev/ttyUSB0', '/dev/ttyUSB1', etc.
    
    # For Windows native Python: use 'COM3' directly
    # For WSL: use '/dev/ttyS2' (but may have issues with WSL2)
    # For native Linux: use '/dev/ttyUSB0' or '/dev/ttyACM0'
    PORT = 'COM3'  # Use 'COM3' for Windows Python, '/dev/ttyS2' for WSL/Linux
    
    try:
        fpga = UARTVectorProcessor(port=PORT)
        
        print("\n=== Vector Addition ===")
        v1 = [1, 2, 3, 4]
        v2 = [10, 20, 30, 40]
        result = fpga.vector_add(v1, v2)
        print(f"{v1} + {v2} = {result}")
        
        print("\n=== Vector Multiplication ===")
        v1 = [2, 3, 4, 5]
        v2 = [10, 10, 10, 10]
        result = fpga.vector_multiply(v1, v2)
        print(f"{v1} * {v2} = {result}")
        
        print("\n=== Dot Product ===")
        v1 = [1, 2, 3]
        v2 = [4, 5, 6]
        result = fpga.vector_dot(v1, v2)
        print(f"{v1} · {v2} = {result}")
        print(f"Expected: {1*4 + 2*5 + 3*6} = 32")
        
        print("\n=== Matrix Addition ===")
        m1 = [[1, 2, 3],
              [4, 5, 6]]
        m2 = [[10, 20, 30],
              [40, 50, 60]]
        result = fpga.matrix_add(m1, m2)
        
        fpga.close()
        
    except serial.SerialException as e:
        print(f"Error: Could not open serial port {PORT}")
        print(f"Make sure:")
        print(f"  1. USB-UART adapter is connected")
        print(f"  2. Correct port is selected")
        print(f"  3. Port is not in use by another program")
        print(f"\nError details: {e}")
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()


if __name__ == '__main__':
    main()

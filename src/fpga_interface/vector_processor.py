"""
Vector Processor Interface
Handles communication with the FPGA vector processor via UART.
"""

import serial
import struct
import time
from typing import List, Tuple
from .operations import Operation


class VectorProcessor:
    """
    Interface to FPGA Vector Processor.
    
    Supports three operations:
    - ADD (0): Element-wise addition
    - DOT (1): Dot product (returns scalar)
    - MULTIPLY (2): Element-wise multiplication
    
    Protocol:
    1. Send operation code (1 byte)
    2. Send vector1 size (1 byte)
    3. Send vector1 elements (size * 4 bytes, little-endian)
    4. Send vector2 size (1 byte)
    5. Send vector2 elements (size * 4 bytes, little-endian)
    6. Receive result size (1 byte)
    7. Receive result elements (size * 4 bytes, little-endian)
    """
    
    MAX_VECTOR_SIZE = 1024
    
    def __init__(self, port: str, baudrate: int = 115200, timeout: float = 5.0):
        """
        Initialize connection to vector processor.
        
        Args:
            port: Serial port (e.g., 'COM3', '/dev/ttyUSB0')
            baudrate: Communication speed (default: 115200)
            timeout: Read timeout in seconds (default: 5.0)
        """
        self.port = port
        self.baudrate = baudrate
        self.timeout = timeout
        self._serial = None
        
    def __enter__(self):
        """Context manager entry."""
        self.connect()
        return self
        
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        self.disconnect()
        
    def connect(self):
        """Open serial connection to FPGA."""
        if self._serial is None or not self._serial.is_open:
            self._serial = serial.Serial(
                self.port,
                self.baudrate,
                timeout=self.timeout
            )
            time.sleep(1)
            
    def disconnect(self):
        """Close serial connection."""
        if self._serial and self._serial.is_open:
            self._serial.close()
            
    def is_connected(self) -> bool:
        """Check if connected to FPGA."""
        return self._serial is not None and self._serial.is_open
    
    def _validate_vector(self, vector: List[int], name: str = "Vector"):
        """Validate vector size and format."""
        if not isinstance(vector, (list, tuple)):
            raise TypeError(f"{name} must be a list or tuple")
        
        if len(vector) == 0:
            raise ValueError(f"{name} cannot be empty")
            
        if len(vector) > self.MAX_VECTOR_SIZE:
            raise ValueError(
                f"{name} size {len(vector)} exceeds maximum {self.MAX_VECTOR_SIZE}"
            )
            
        for i, val in enumerate(vector):
            if not isinstance(val, int):
                raise TypeError(f"{name}[{i}] must be an integer, got {type(val)}")
                
    def _send_vector(self, vector: List[int]):
        """Send a vector via UART."""
        size = len(vector)
        # Send size as 2 bytes (unsigned short, little-endian)
        self._serial.write(struct.pack('<H', size))
        
        for val in vector:
            packed = struct.pack('<i', val)
            self._serial.write(packed)
            
        self._serial.flush()
        
    def _receive_vector(self) -> List[int]:
        """Receive a vector via UART."""
        # Read size (2 bytes)
        size_bytes = self._serial.read(2)
        if len(size_bytes) != 2:
            raise IOError("Failed to receive result size")
        
        size = struct.unpack('<H', size_bytes)[0]
        
        result = []
        for i in range(size):
            element_bytes = self._serial.read(4)
            if len(element_bytes) != 4:
                raise IOError(f"Failed to receive element {i}")
            
            val = struct.unpack('<i', element_bytes)[0]
            result.append(val)
            
        return result
    
    def execute(
        self,
        operation: Operation,
        vector1: List[int],
        vector2: List[int]
    ) -> List[int]:
        """
        Execute an operation on two vectors.
        
        Args:
            operation: Operation to perform (ADD, DOT, or MULTIPLY)
            vector1: First input vector
            vector2: Second input vector
            
        Returns:
            Result vector (single element for DOT operation)
            
        Raises:
            ValueError: Invalid vector sizes
            IOError: Communication error
        """
        if not self.is_connected():
            raise IOError("Not connected to FPGA. Call connect() first.")
            
        self._validate_vector(vector1, "Vector1")
        self._validate_vector(vector2, "Vector2")
        
        if operation not in [Operation.ADD, Operation.DOT, Operation.MULTIPLY]:
            raise ValueError(f"Invalid operation: {operation}")
        
        self._serial.reset_input_buffer()
        self._serial.reset_output_buffer()
        time.sleep(0.1)
        
        self._serial.write(bytes([int(operation)]))
        time.sleep(0.05)
        
        self._send_vector(vector1)
        time.sleep(0.05)
        self._send_vector(vector2)
        
        wait_time = 0.2 + (len(vector1) + len(vector2)) * 0.01
        time.sleep(wait_time)
        
        result = self._receive_vector()
        
        return result
    
    def add(self, vector1: List[int], vector2: List[int]) -> List[int]:
        """
        Element-wise vector addition.
        
        Args:
            vector1: First vector
            vector2: Second vector
            
        Returns:
            Result vector with min(len(v1), len(v2)) elements
        """
        return self.execute(Operation.ADD, vector1, vector2)
    
    def dot(self, vector1: List[int], vector2: List[int]) -> int:
        """
        Dot product of two vectors.
        
        Args:
            vector1: First vector
            vector2: Second vector
            
        Returns:
            Scalar dot product result
        """
        result = self.execute(Operation.DOT, vector1, vector2)
        return result[0] if result else 0
    
    def multiply(self, vector1: List[int], vector2: List[int]) -> List[int]:
        """
        Element-wise vector multiplication.
        
        Args:
            vector1: First vector
            vector2: Second vector
            
        Returns:
            Result vector with min(len(v1), len(v2)) elements
        """
        return self.execute(Operation.MULTIPLY, vector1, vector2)

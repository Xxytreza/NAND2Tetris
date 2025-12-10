"""
Matrix Processor Interface
Handles communication with the FPGA matrix processor via UART.
"""

import serial
import struct
import time
from typing import List, Tuple
from .operations import Operation


class MatrixProcessor:
    """
    Interface to FPGA Matrix Processor.
    
    Supports three operations:
    - ADD (0): Element-wise matrix addition
    - DOT (1): Matrix multiplication (dot product)
    - MULTIPLY (2): Element-wise matrix multiplication
    
    Protocol:
    1. Send operation code (1 byte)
    2. Send matrix1 rows (1 byte)
    3. Send matrix1 cols (1 byte)
    4. Send matrix1 elements (rows*cols * 4 bytes, little-endian, row-major)
    5. Send matrix2 rows (1 byte)
    6. Send matrix2 cols (1 byte)
    7. Send matrix2 elements (rows*cols * 4 bytes, little-endian, row-major)
    8. Receive result rows (1 byte)
    9. Receive result cols (1 byte)
    10. Receive result elements (rows*cols * 4 bytes, little-endian, row-major)
    """
    
    MAX_ELEMENTS = 1024  # Maximum elements per FPGA operation (32x32)
    TILE_SIZE = 32  # Process matrices in 32x32 tiles
    
    def __init__(self, port: str, baudrate: int = 115200, timeout: float = 5.0):
        """
        Initialize connection to matrix processor.
        
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
            time.sleep(0.1)
            
    def disconnect(self):
        """Close serial connection."""
        if self._serial and self._serial.is_open:
            self._serial.close()
            
    def is_connected(self) -> bool:
        """Check if connected to FPGA."""
        return self._serial is not None and self._serial.is_open
    
    def _validate_matrix(self, matrix: List[List[int]], name: str = "Matrix", check_size: bool = False):
        """Validate matrix size and format."""
        if not isinstance(matrix, (list, tuple)):
            raise TypeError(f"{name} must be a list or tuple")
        
        if len(matrix) == 0:
            raise ValueError(f"{name} cannot be empty")
        
        rows = len(matrix)
        cols = len(matrix[0]) if matrix else 0
        
        if cols == 0:
            raise ValueError(f"{name} rows cannot be empty")
        
        # Check all rows have same length
        for i, row in enumerate(matrix):
            if not isinstance(row, (list, tuple)):
                raise TypeError(f"{name}[{i}] must be a list or tuple")
            if len(row) != cols:
                raise ValueError(
                    f"{name}[{i}] has {len(row)} columns, expected {cols}"
                )
            for j, val in enumerate(row):
                if not isinstance(val, int):
                    raise TypeError(
                        f"{name}[{i}][{j}] must be an integer, got {type(val)}"
                    )
        
        # Check total size only if requested (for tile operations)
        if check_size:
            total = rows * cols
            if total > self.MAX_ELEMENTS:
                raise ValueError(
                    f"{name} size {rows}x{cols} ({total} elements) "
                    f"exceeds maximum {self.MAX_ELEMENTS} elements"
                )
            
        return rows, cols
    
    def _flatten_matrix(self, matrix: List[List[int]]) -> List[int]:
        """Flatten matrix to row-major order."""
        flat = []
        for row in matrix:
            flat.extend(row)
        return flat
    
    def _unflatten_matrix(self, flat: List[int], rows: int, cols: int) -> List[List[int]]:
        """Convert flat list to 2D matrix."""
        matrix = []
        for i in range(rows):
            row = flat[i * cols:(i + 1) * cols]
            matrix.append(row)
        return matrix
    
    def _send_matrix(self, matrix: List[List[int]]):
        """Send a matrix via UART."""
        rows, cols = self._validate_matrix(matrix)
        
        # Send dimensions
        self._serial.write(bytes([rows]))
        self._serial.write(bytes([cols]))
        
        # Send elements in row-major order
        flat = self._flatten_matrix(matrix)
        for val in flat:
            packed = struct.pack('<i', val)
            self._serial.write(packed)
            
        self._serial.flush()
        
    def _receive_matrix(self) -> List[List[int]]:
        """Receive a matrix via UART."""
        # Read dimensions
        rows_byte = self._serial.read(1)
        if len(rows_byte) != 1:
            raise IOError("Failed to receive result rows")
        rows = rows_byte[0]
        
        cols_byte = self._serial.read(1)
        if len(cols_byte) != 1:
            raise IOError("Failed to receive result cols")
        cols = cols_byte[0]
        
        # Read elements
        total = rows * cols
        flat = []
        for i in range(total):
            element_bytes = self._serial.read(4)
            if len(element_bytes) != 4:
                raise IOError(f"Failed to receive element {i}")
            
            val = struct.unpack('<i', element_bytes)[0]
            flat.append(val)
        
        # Convert to 2D matrix
        matrix = self._unflatten_matrix(flat, rows, cols)
        return matrix
    def _execute_tile(
        self,
        operation: Operation,
        matrix1: List[List[int]],
        matrix2: List[List[int]]
    ) -> List[List[int]]:
        """
        Execute an operation on two matrices (must fit in FPGA memory).
        Internal method - use execute() for automatic tiling.
        """
        if not self.is_connected():
            raise IOError("Not connected to FPGA. Call connect() first.")
        
        # Validate tile sizes
        self._validate_matrix(matrix1, "Tile1", check_size=True)
        self._validate_matrix(matrix2, "Tile2", check_size=True)
        
        # Clear buffers
        self._serial.reset_input_buffer()
        self._serial.reset_output_buffer()
        self._serial.reset_output_buffer()
        
        hw_op_code = operation
        if operation == Operation.DOT:
            hw_op_code = 2
        elif operation == Operation.MULTIPLY:
            hw_op_code = 1
            
        self._serial.write(bytes([int(hw_op_code)]))
        self._serial.flush()
        
        # Send matrices
        self._send_matrix(matrix1)
        self._send_matrix(matrix2)
        
        rows1, cols1 = len(matrix1), len(matrix1[0])
        rows2, cols2 = len(matrix2), len(matrix2[0])
        total_elements = (rows1 * cols1) + (rows2 * cols2)
        
        if operation == Operation.DOT:
            wait_time = 0.01 + total_elements * 0.0001
        else:
            wait_time = 0.001 + total_elements * 0.00001
        time.sleep(wait_time)
        
        # Receive result
        result = self._receive_matrix()
        return result
    
    def execute(
        self,
        operation: Operation,
        matrix1: List[List[int]],
        matrix2: List[List[int]]
    ) -> List[List[int]]:
        """
        Execute an operation on two matrices with automatic tiling for large matrices.
        
        Args:
            operation: Operation to perform (ADD, DOT, or MULTIPLY)
            matrix1: First input matrix (list of lists, row-major)
            matrix2: Second input matrix (list of lists, row-major)
            
        Returns:
            Result matrix (list of lists, row-major)
            
        Raises:
            ValueError: Invalid matrix dimensions
            IOError: Communication error
        """
        if not self.is_connected():
            raise IOError("Not connected to FPGA. Call connect() first.")
            
        # Validate inputs
        rows1, cols1 = self._validate_matrix(matrix1, "Matrix1")
        rows2, cols2 = self._validate_matrix(matrix2, "Matrix2")
        
        if operation not in [Operation.ADD, Operation.DOT, Operation.MULTIPLY]:
            raise ValueError(f"Invalid operation: {operation}")
        
        # Validate dimensions for specific operations
        if operation == Operation.DOT:
            if cols1 != rows2:
                raise ValueError(
                    f"Matrix multiplication requires matrix1 cols ({cols1}) "
                    f"to equal matrix2 rows ({rows2})"
                )
        elif operation in [Operation.ADD, Operation.MULTIPLY]:
            if rows1 != rows2 or cols1 != cols2:
                raise ValueError(
                    f"Element-wise operations require same dimensions. "
                    f"Got {rows1}x{cols1} and {rows2}x{cols2}"
                )
        
        # Check if tiling is needed
        if rows1 <= self.TILE_SIZE and cols1 <= self.TILE_SIZE and rows2 <= self.TILE_SIZE and cols2 <= self.TILE_SIZE:
            # Small enough - process directly
            return self._execute_tile(operation, matrix1, matrix2)
        
        # Large matrices - use tiling
        if operation in [Operation.ADD, Operation.MULTIPLY]:
            return self._execute_tiled_elementwise(operation, matrix1, matrix2)
        else:  # DOT
            return self._execute_tiled_matmul(matrix1, matrix2)
    
    def _execute_tiled_elementwise(
        self,
        operation: Operation,
        matrix1: List[List[int]],
        matrix2: List[List[int]]
    ) -> List[List[int]]:
        """Execute element-wise operation using tiling."""
        rows, cols = len(matrix1), len(matrix1[0])
        result = [[0] * cols for _ in range(rows)]
        
        # Process in tiles
        for i in range(0, rows, self.TILE_SIZE):
            for j in range(0, cols, self.TILE_SIZE):
                # Extract tile
                tile_rows = min(self.TILE_SIZE, rows - i)
                tile_cols = min(self.TILE_SIZE, cols - j)
                
                tile1 = [matrix1[i + r][j:j + tile_cols] for r in range(tile_rows)]
                tile2 = [matrix2[i + r][j:j + tile_cols] for r in range(tile_rows)]
                
                # Process tile
                tile_result = self._execute_tile(operation, tile1, tile2)
                
                # Copy result back
                for r in range(tile_rows):
                    for c in range(tile_cols):
                        result[i + r][j + c] = tile_result[r][c]
        
        return result
    
    def _execute_tiled_matmul(
        self,
        matrix1: List[List[int]],
        matrix2: List[List[int]]
    ) -> List[List[int]]:
        """Execute matrix multiplication using tiling."""
        rows1, cols1 = len(matrix1), len(matrix1[0])
        rows2, cols2 = len(matrix2), len(matrix2[0])
        result = [[0] * cols2 for _ in range(rows1)]
        
        # Process in tiles: C[i:i+t, j:j+t] += A[i:i+t, k:k+t] @ B[k:k+t, j:j+t]
        for i in range(0, rows1, self.TILE_SIZE):
            for j in range(0, cols2, self.TILE_SIZE):
                for k in range(0, cols1, self.TILE_SIZE):
                    # Extract tiles
                    tile_rows1 = min(self.TILE_SIZE, rows1 - i)
                    tile_cols1 = min(self.TILE_SIZE, cols1 - k)
                    tile_rows2 = min(self.TILE_SIZE, rows2 - k)
                    tile_cols2 = min(self.TILE_SIZE, cols2 - j)
                    
                    tile1 = [matrix1[i + r][k:k + tile_cols1] for r in range(tile_rows1)]
                    tile2 = [matrix2[k + r][j:j + tile_cols2] for r in range(tile_rows2)]
                    
                    # Compute tile product
                    tile_result = self._execute_tile(Operation.DOT, tile1, tile2)
                    
                    # Accumulate result
                    for r in range(len(tile_result)):
                        for c in range(len(tile_result[0])):
                            result[i + r][j + c] += tile_result[r][c]
        
        return result
    
    def add(
        self,
        matrix1: List[List[int]],
        matrix2: List[List[int]]
    ) -> List[List[int]]:
        """
        Element-wise matrix addition.
        
        Args:
            matrix1: First matrix (must have same dimensions as matrix2)
            matrix2: Second matrix
            
        Returns:
            Result matrix with element-wise sum
        """
        return self.execute(Operation.ADD, matrix1, matrix2)
    
    def dot(
        self,
        matrix1: List[List[int]],
        matrix2: List[List[int]]
    ) -> List[List[int]]:
        """
        Matrix multiplication (dot product).
        
        Args:
            matrix1: First matrix (m x n)
            matrix2: Second matrix (n x o)
            
        Returns:
            Result matrix (m x o)
        """
        return self.execute(Operation.DOT, matrix1, matrix2)
    
    def multiply(
        self,
        matrix1: List[List[int]],
        matrix2: List[List[int]]
    ) -> List[List[int]]:
        """
        Element-wise matrix multiplication (Hadamard product).
        
        Args:
            matrix1: First matrix (must have same dimensions as matrix2)
            matrix2: Second matrix
            
        Returns:
            Result matrix with element-wise product
        """
        return self.execute(Operation.MULTIPLY, matrix1, matrix2)
    
    @staticmethod
    def print_matrix(matrix: List[List[int]], label: str = "Matrix"):
        """
        Pretty print a matrix.
        
        Args:
            matrix: Matrix to print
            label: Label for the matrix
        """
        if not matrix:
            print(f"{label}: []")
            return
            
        rows = len(matrix)
        cols = len(matrix[0]) if matrix else 0
        
        print(f"{label} ({rows}x{cols}):")
        
        # Find max width for alignment
        max_width = max(
            len(str(val))
            for row in matrix
            for val in row
        )
        
        for row in matrix:
            formatted = [str(val).rjust(max_width) for val in row]
            print(f"  [{', '.join(formatted)}]")

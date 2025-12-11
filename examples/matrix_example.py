#!/usr/bin/env python3

import sys
sys.path.insert(0, '../src')

from fpga_interface import MatrixProcessor
from fpga_interface.operations import Operation

def python_matrix_add(m1, m2):
    """Python reference: element-wise matrix addition."""
    rows = len(m1)
    cols = len(m1[0])
    return [[m1[i][j] + m2[i][j] for j in range(cols)] for i in range(rows)]


def python_matrix_multiply(m1, m2):
    """Python reference: element-wise matrix multiplication (Hadamard product)."""
    rows = len(m1)
    cols = len(m1[0])
    return [[m1[i][j] * m2[i][j] for j in range(cols)] for i in range(rows)]


def python_matrix_dot(m1, m2):
    """Python reference: matrix multiplication (dot product)."""
    rows1 = len(m1)
    cols1 = len(m1[0])
    cols2 = len(m2[0])
    
    result = [[0 for _ in range(cols2)] for _ in range(rows1)]
    for i in range(rows1):
        for j in range(cols2):
            for k in range(cols1):
                result[i][j] += m1[i][k] * m2[k][j]
    return result


def verify_matrix_result(fpga_result, python_result, operation_name):
    """Compare FPGA matrix result with Python calculation."""
    if fpga_result == python_result:
        print(f"✅ PASS - {operation_name} matches Python calculation")
        return True
    else:
        print(f"❌ FAIL - {operation_name} doesn't match!")
        print(f"FPGA result:")
        for row in fpga_result:
            print(f"  {row}")
        print(f"Python result:")
        for row in python_result:
            print(f"  {row}")
        return False


def main():
    # Configure your serial port
    port = 'COM3'  # Change to your port (e.g., 'COM3' on Windows)
    
    print("="*60)
    print("FPGA Matrix Processor Example")
    print("="*60)
    
    # Use context manager for automatic connection handling
    with MatrixProcessor(port) as mp:
        print(f"\nConnected to {port}")
        
        # Example 1: Matrix Addition
        print("\n" + "-"*60)
        print("Example 1: Matrix Addition (3x3)")
        print("-"*60)
        
        m1 = [
            [1, 2, 3],
            [4, 5, 6],
            [7, 8, 9]
        ]
        
        m2 = [
            [9, 8, 7],
            [6, 5, 4],
            [3, 2, 1]
        ]
        
        mp.print_matrix(m1, "Matrix 1")
        mp.print_matrix(m2, "Matrix 2")
        
        fpga_result = mp.add(m1, m2)
        python_result = python_matrix_add(m1, m2)
        
        mp.print_matrix(fpga_result, "FPGA Result")
        mp.print_matrix(python_result, "Python Result")
        verify_matrix_result(fpga_result, python_result, "Matrix Addition")
        
        # Example 2: Matrix Multiplication
        print("\n" + "-"*60)
        print("Example 2: Matrix Multiplication (2x3 × 3x2)")
        print("-"*60)
        
        m1 = [
            [1, 2, 3],
            [4, 5, 6]
        ]
        
        m2 = [
            [7, 8],
            [9, 10],
            [11, 12]
        ]
        
        mp.print_matrix(m1, "Matrix 1 (2x3)")
        mp.print_matrix(m2, "Matrix 2 (3x2)")
        
        fpga_result = mp.dot(m1, m2)
        python_result = python_matrix_dot(m1, m2)
        
        mp.print_matrix(fpga_result, "FPGA Result (2x2)")
        mp.print_matrix(python_result, "Python Result (2x2)")
        verify_matrix_result(fpga_result, python_result, "Matrix Multiplication")
        
        # Example 3: Element-wise Multiplication
        print("\n" + "-"*60)
        print("Example 3: Element-wise Multiplication (2x2)")
        print("-"*60)
        
        m1 = [
            [2, 3],
            [4, 5]
        ]
        
        m2 = [
            [10, 20],
            [30, 40]
        ]
        
        mp.print_matrix(m1, "Matrix 1")
        mp.print_matrix(m2, "Matrix 2")
        
        fpga_result = mp.multiply(m1, m2)
        python_result = python_matrix_multiply(m1, m2)
        
        mp.print_matrix(fpga_result, "FPGA Result")
        mp.print_matrix(python_result, "Python Result")
        verify_matrix_result(fpga_result, python_result, "Element-wise Multiplication")
        
        # Example 4: Identity Matrix Test
        print("\n" + "-"*60)
        print("Example 4: Identity Matrix Multiplication")
        print("-"*60)
        
        m1 = [
            [1, 2, 3],
            [4, 5, 6],
            [7, 8, 9]
        ]
        
        identity = [
            [1, 0, 0],
            [0, 1, 0],
            [0, 0, 1]
        ]
        
        mp.print_matrix(m1, "Matrix")
        mp.print_matrix(identity, "Identity")
        
        fpga_result = mp.dot(m1, identity)
        python_result = python_matrix_dot(m1, identity)
        
        mp.print_matrix(fpga_result, "FPGA Result")
        mp.print_matrix(python_result, "Python Result (should equal original)")
        verify_matrix_result(fpga_result, python_result, "Identity Multiplication")
        
        # Example 5: Vector as Matrix (1xN and Nx1)
        print("\n" + "-"*60)
        print("Example 5: Vector-like Matrices (1x4 × 4x1)")
        print("-"*60)
        
        m1 = [[1, 2, 3, 4]]  # 1x4 row vector
        m2 = [[5], [6], [7], [8]]  # 4x1 column vector
        
        mp.print_matrix(m1, "Row Vector (1x4)")
        mp.print_matrix(m2, "Column Vector (4x1)")
        
        fpga_result = mp.dot(m1, m2)
        python_result = python_matrix_dot(m1, m2)
        
        mp.print_matrix(fpga_result, "FPGA Result (1x1 scalar)")
        mp.print_matrix(python_result, "Python Result (1x1 scalar)")
        verify_matrix_result(fpga_result, python_result, "Vector Dot Product")
        
        # Example 6: Using execute() directly
        print("\n" + "-"*60)
        print("Example 6: Using execute() method directly")
        print("-"*60)
        
        m1 = [[1, 2], [3, 4]]
        m2 = [[5, 6], [7, 8]]
        
        mp.print_matrix(m1, "Matrix 1")
        mp.print_matrix(m2, "Matrix 2")
        
        fpga_add = mp.execute(Operation.ADD, m1, m2)
        python_add = python_matrix_add(m1, m2)
        mp.print_matrix(fpga_add, "Addition (FPGA)")
        verify_matrix_result(fpga_add, python_add, "Addition")
        
        fpga_mul = mp.execute(Operation.MULTIPLY, m1, m2)
        python_mul = python_matrix_multiply(m1, m2)
        mp.print_matrix(fpga_mul, "Element-wise Multiply (FPGA)")
        verify_matrix_result(fpga_mul, python_mul, "Element-wise Multiply")
        
        fpga_dot = mp.execute(Operation.DOT, m1, m2)
        python_dot_result = python_matrix_dot(m1, m2)
        mp.print_matrix(fpga_dot, "Matrix Multiply (FPGA)")
        verify_matrix_result(fpga_dot, python_dot_result, "Matrix Multiply")
        
        # Example 7: Maximum Size Test
        print("\n" + "-"*60)
        print("Example 7: Maximum Size (4x8 matrix)")
        print("-"*60)
        
        m1 = [[i + j for j in range(8)] for i in range(4)]
        m2 = [[1 for j in range(8)] for i in range(4)]
        
        mp.print_matrix(m1, "Matrix 1 (4x8)")
        mp.print_matrix(m2, "Matrix 2 (4x8, all ones)")
        
        fpga_result = mp.add(m1, m2)
        python_result = python_matrix_add(m1, m2)
        
        mp.print_matrix(fpga_result, "FPGA Result (addition)")
        verify_matrix_result(fpga_result, python_result, "Maximum Size Addition")

        # Example 8: 32x32 Matrix Addition
        print("\n" + "-"*60)
        print("Example 8: 32x32 Matrix Addition")
        print("-"*60)
        
        m1 = [[i + j for j in range(32)] for i in range(32)]
        m2 = [[1 for j in range(32)] for i in range(32)]
        
        print("Matrix 1 (32x32) - generated")
        print("Matrix 2 (32x32) - all ones")
        
        fpga_result = mp.add(m1, m2)
        python_result = python_matrix_add(m1, m2)
        
        # Print only top-left corner to avoid spam
        print("FPGA Result (top-left 5x5):")
        for i in range(5):
            print(f"  {fpga_result[i][:5]}")
            
        verify_matrix_result(fpga_result, python_result, "32x32 Matrix Addition")
    
    print("\n" + "="*60)
    print("Examples completed successfully!")
    print("="*60)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nInterrupted by user")
    except Exception as e:
        print(f"\nError: {e}")
        import traceback
        traceback.print_exc()

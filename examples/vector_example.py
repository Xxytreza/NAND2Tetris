#!/usr/bin/env python3
"""
Example usage of the VectorProcessor library.
Demonstrates vector addition, dot product, and element-wise multiplication.
Verifies FPGA results against Python calculations.
"""

import sys
sys.path.insert(0, '../src')

from fpga_interface import VectorProcessor
from fpga_interface.operations import Operation


def python_add(v1, v2):
    """Python reference: element-wise addition."""
    size = min(len(v1), len(v2))
    return [v1[i] + v2[i] for i in range(size)]


def python_dot(v1, v2):
    """Python reference: dot product."""
    size = min(len(v1), len(v2))
    return sum(v1[i] * v2[i] for i in range(size))


def python_multiply(v1, v2):
    """Python reference: element-wise multiplication."""
    size = min(len(v1), len(v2))
    return [v1[i] * v2[i] for i in range(size)]


def verify_result(fpga_result, python_result, operation_name):
    """Compare FPGA result with Python calculation."""
    if fpga_result == python_result:
        print(f"✅ PASS - {operation_name} matches Python calculation")
        return True
    else:
        print(f"❌ FAIL - {operation_name} doesn't match!")
        print(f"  FPGA result:   {fpga_result}")
        print(f"  Python result: {python_result}")
        return False


def main():
    # Configure your serial port
    port = 'COM3'  # Change to your port (e.g., 'COM3' on Windows)
    
    print("="*60)
    print("FPGA Vector Processor Example")
    print("="*60)
    
    # Use context manager for automatic connection handling
    with VectorProcessor(port) as vp:
        print(f"\nConnected to {port}")
        
        # Example 1: Vector Addition
        print("\n" + "-"*60)
        print("Example 1: Vector Addition")
        print("-"*60)
        
        v1 = [1, 2, 3, 4, 5]
        v2 = [10, 20, 30, 40, 50]
        
        print(f"Vector 1: {v1}")
        print(f"Vector 2: {v2}")
        
        fpga_result = vp.add(v1, v2)
        python_result = python_add(v1, v2)
        
        print(f"FPGA result:   {fpga_result}")
        print(f"Python result: {python_result}")
        verify_result(fpga_result, python_result, "Addition")
        
        # Example 2: Dot Product
        print("\n" + "-"*60)
        print("Example 2: Dot Product")
        print("-"*60)
        
        v1 = [1, 2, 3, 4]
        v2 = [5, 6, 7, 8]
        
        print(f"Vector 1: {v1}")
        print(f"Vector 2: {v2}")
        
        fpga_result = vp.dot(v1, v2)
        python_result = python_dot(v1, v2)
        
        print(f"FPGA result:   {fpga_result}")
        print(f"Python result: {python_result} (1*5 + 2*6 + 3*7 + 4*8)")
        verify_result(fpga_result, python_result, "Dot Product")
        
        # Example 3: Element-wise Multiplication
        print("\n" + "-"*60)
        print("Example 3: Element-wise Multiplication")
        print("-"*60)
        
        v1 = [1, 2, 3, 4, 5]
        v2 = [2, 2, 2, 2, 2]
        
        print(f"Vector 1: {v1}")
        print(f"Vector 2: {v2}")
        
        fpga_result = vp.multiply(v1, v2)
        python_result = python_multiply(v1, v2)
        
        print(f"FPGA result:   {fpga_result}")
        print(f"Python result: {python_result}")
        verify_result(fpga_result, python_result, "Element-wise Multiply")
        
        # Example 4: Using execute() directly
        print("\n" + "-"*60)
        print("Example 4: Using execute() method directly")
        print("-"*60)
        
        v1 = [10, 20, 30]
        v2 = [1, 2, 3]
        
        print(f"Vector 1: {v1}")
        print(f"Vector 2: {v2}")
        
        fpga_add = vp.execute(Operation.ADD, v1, v2)
        python_add_result = python_add(v1, v2)
        print(f"Addition - FPGA: {fpga_add}, Python: {python_add_result}")
        verify_result(fpga_add, python_add_result, "Addition")
        
        fpga_dot = vp.execute(Operation.DOT, v1, v2)
        python_dot_result = python_dot(v1, v2)
        print(f"Dot      - FPGA: {fpga_dot}, Python: {python_dot_result}")
        verify_result(fpga_dot, python_dot_result, "Dot Product")
        
        fpga_mul = vp.execute(Operation.MULTIPLY, v1, v2)
        python_mul_result = python_multiply(v1, v2)
        print(f"Multiply - FPGA: {fpga_mul}, Python: {python_mul_result}")
        verify_result(fpga_mul, python_mul_result, "Multiply")
        
        # Example 5: Large vectors
        print("\n" + "-"*60)
        print("Example 5: Large Vectors (up to 128 elements)")
        print("-"*60)
        
        v1 = list(range(1, 65))  # 64 elements
        v2 = [1] * 64
        
        print(f"Vector 1: [1, 2, 3, ..., 64] (64 elements)")
        print(f"Vector 2: [1, 1, 1, ..., 1] (64 elements)")
        
        fpga_add = vp.add(v1, v2)
        python_add_result = python_add(v1, v2)
        print(f"Addition - FPGA (first 10): {fpga_add[:10]}")
        print(f"Addition - Python (first 10): {python_add_result[:10]}")
        verify_result(fpga_add, python_add_result, "Large Vector Addition")
        
        fpga_dot = vp.dot(v1, v2)
        python_dot_result = python_dot(v1, v2)
        print(f"Dot product - FPGA:   {fpga_dot}")
        print(f"Dot product - Python: {python_dot_result} (sum of 1 to 64)")
        verify_result(fpga_dot, python_dot_result, "Large Vector Dot Product")

        # Example 6: Max Size Vectors (1024 elements)
        print("\n" + "-"*60)
        print("Example 6: Max Size Vectors (1024 elements)")
        print("-"*60)
        
        v1 = list(range(1, 1025))  # 1024 elements
        v2 = [1] * 1024
        
        print(f"Vector 1: [1, 2, ..., 1024] (1024 elements)")
        print(f"Vector 2: [1, 1, ..., 1] (1024 elements)")
        
        fpga_add = vp.add(v1, v2)
        python_add_result = python_add(v1, v2)
        print(f"Addition - FPGA (first 10): {fpga_add[:10]}")
        verify_result(fpga_add, python_add_result, "1024 Element Vector Addition")
        
        fpga_dot = vp.dot(v1, v2)
        python_dot_result = python_dot(v1, v2)
        print(f"Dot product - FPGA:   {fpga_dot}")
        print(f"Dot product - Python: {python_dot_result}")
        verify_result(fpga_dot, python_dot_result, "1024 Element Vector Dot Product")
    
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

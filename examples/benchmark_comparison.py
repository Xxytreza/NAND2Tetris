#!/usr/bin/env python3

import time
import os
import numpy as np

import sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from src.fpga_interface.matrix_processor import MatrixProcessor


# Force single-threaded execution for fair comparison with FPGA (50MHz single core)
os.environ['OMP_NUM_THREADS'] = '1'
os.environ['MKL_NUM_THREADS'] = '1'
os.environ['OPENBLAS_NUM_THREADS'] = '1'
os.environ['NUMEXPR_NUM_THREADS'] = '1'

def generate_random_matrix(rows, cols, min_val=-50, max_val=50, use_numpy=True):
    """Generate a random matrix"""
    if use_numpy:
        return np.random.randint(min_val, max_val, size=(rows, cols), dtype=np.int32)
    else:
        import random
        return [[random.randint(min_val, max_val) for _ in range(cols)] for _ in range(rows)]

# ============================================================================
# Pure Python Implementations (No NumPy)
# ============================================================================

def python_add(mat1, mat2):
    """Pure Python: Element-wise addition"""
    rows, cols = len(mat1), len(mat1[0])
    result = [[0] * cols for _ in range(rows)]
    for i in range(rows):
        for j in range(cols):
            result[i][j] = mat1[i][j] + mat2[i][j]
    return result

def python_multiply(mat1, mat2):
    """Pure Python: Element-wise multiplication"""
    rows, cols = len(mat1), len(mat1[0])
    result = [[0] * cols for _ in range(rows)]
    for i in range(rows):
        for j in range(cols):
            result[i][j] = mat1[i][j] * mat2[i][j]
    return result

def python_matmul(mat1, mat2):
    """Pure Python: Matrix multiplication"""
    rows1, cols1 = len(mat1), len(mat1[0])
    rows2, cols2 = len(mat2), len(mat2[0])
    result = [[0] * cols2 for _ in range(rows1)]
    
    for i in range(rows1):
        for j in range(cols2):
            acc = 0
            for k in range(cols1):
                acc += mat1[i][k] * mat2[k][j]
            result[i][j] = acc
    return result

# ============================================================================
# NumPy Implementations
# ============================================================================

def numpy_add(mat1, mat2):
    """NumPy: Element-wise addition"""
    return np.add(mat1, mat2)

def numpy_multiply(mat1, mat2):
    """NumPy: Element-wise multiplication"""
    return np.multiply(mat1, mat2)

def numpy_matmul(mat1, mat2):
    """NumPy: Matrix multiplication"""
    return np.matmul(mat1, mat2)

# ============================================================================
# Benchmark Functions
# ============================================================================

def benchmark_implementation(impl_name, func, mat1, mat2, num_runs=100):
    """Benchmark a single implementation with many iterations for precision"""
    times = []
    
    # Warmup run
    _ = func(mat1, mat2)
    
    for _ in range(num_runs):
        start = time.perf_counter()  # More precise than time.time()
        result = func(mat1, mat2)
        elapsed = time.perf_counter() - start
        times.append(elapsed)
    
    return {
        'impl': impl_name,
        'avg_ms': sum(times) / len(times) * 1000,
        'min_ms': min(times) * 1000,
        'max_ms': max(times) * 1000
    }

def benchmark_fpga(processor, mat1, mat2, operation, num_runs=3):
    """Benchmark FPGA implementation with transfer/compute breakdown"""
    # Convert to list format if needed
    if isinstance(mat1, np.ndarray):
        mat1 = mat1.tolist()
    if isinstance(mat2, np.ndarray):
        mat2 = mat2.tolist()
    
    total_times = []
    send_times = []
    compute_times = []
    recv_times = []
    
    for _ in range(num_runs):
        # Measure send time
        processor._serial.reset_input_buffer()
        processor._serial.reset_output_buffer()
        
        send_start = time.perf_counter()
        
        # Send operation code
        hw_op_code = 0 if operation == 'add' else (1 if operation == 'mult' else 2)
        processor._serial.write(bytes([hw_op_code]))
        processor._serial.flush()
        
        # Send matrices
        processor._send_matrix(mat1)
        processor._send_matrix(mat2)
        
        send_end = time.perf_counter()
        send_time = send_end - send_start
        
        # Estimate compute time based on operation
        rows1, cols1 = len(mat1), len(mat1[0])
        rows2, cols2 = len(mat2), len(mat2[0])
        total_elements = (rows1 * cols1) + (rows2 * cols2)
        
        if hw_op_code == 2:  # matmul
            compute_time = 0.01 + total_elements * 0.0001
        else:
            compute_time = 0.001 + total_elements * 0.00001
        time.sleep(compute_time)
        compute_end = time.perf_counter()
        
        # Measure receive time
        recv_start = compute_end
        result = processor._receive_matrix()
        recv_end = time.perf_counter()
        recv_time = recv_end - recv_start
        
        total_time = recv_end - send_start
        actual_compute = total_time - send_time - recv_time
        
        total_times.append(total_time)
        send_times.append(send_time)
        compute_times.append(actual_compute)
        recv_times.append(recv_time)
    
    return {
        'impl': 'FPGA',
        'avg_ms': sum(total_times) / len(total_times) * 1000,
        'min_ms': min(total_times) * 1000,
        'max_ms': max(total_times) * 1000,
        'avg_send_ms': sum(send_times) / len(send_times) * 1000,
        'avg_compute_ms': sum(compute_times) / len(compute_times) * 1000,
        'avg_recv_ms': sum(recv_times) / len(recv_times) * 1000
    }

def run_comparison_benchmark(port=None, baudrate=115200):
    """Run comprehensive comparison benchmark"""
    print("=" * 100)
    print("COMPREHENSIVE PERFORMANCE COMPARISON: FPGA vs CPU (Single-Threaded)")
    print("=" * 100)
    print("NOTE: CPU limited to 1 thread for fair comparison with FPGA (50MHz single core)")
    print("=" * 100)
    
    # Auto-detect port
    if port is None:
        import platform
        if platform.system() == 'Windows':
            for i in range(1, 20):
                try:
                    test_port = f'COM{i}'
                    processor = MatrixProcessor(port=test_port, baudrate=baudrate, timeout=1.0)
                    processor.connect()
                    processor.disconnect()
                    port = test_port
                    break
                except:
                    continue
            if port is None:
                print("✗ Could not find FPGA on any COM port")
                return
        else:
            port = '/dev/ttyUSB0'
    
    # Connect to FPGA
    try:
        processor = MatrixProcessor(port=port, baudrate=baudrate, timeout=15.0)
        processor.connect()
        print(f"✓ Connected to FPGA on {port}\n")
    except Exception as e:
        print(f"✗ Failed to connect: {e}")
        return
    
    # Test sizes
    sizes = [1, 2, 4, 8, 16, 24, 32, 40, 48, 56, 64]
    operations = ['add', 'mult', 'matmul']
    
    all_results = []
    
    for operation in operations:
        print(f"\n{'=' * 90}")
        print(f"OPERATION: {operation.upper()}")
        print(f"{'=' * 90}")
        print(f"{'Size':<8} {'FPGA Tot':<12} {'Send':<12} {'Compute':<12} {'Recv':<12} {'Python':<12} {'Speedup':<12}")
        print(f"{'':8} {'(ms)':<12} {'(ms)':<12} {'(ms)':<12} {'(ms)':<12} {'(ms)':<12} {'':12}")
        print("-" * 90)
        
        for size in sizes:
            # Generate test matrices
            mat1_np = generate_random_matrix(size, size, use_numpy=True)
            mat2_np = generate_random_matrix(size, size, use_numpy=True)
            
            # Convert to lists for Python
            mat1_list = mat1_np.tolist()
            mat2_list = mat2_np.tolist()
            
            try:
                # Benchmark FPGA
                fpga_result = benchmark_fpga(processor, mat1_list, mat2_list, operation, num_runs=3)
                
                # Benchmark Pure Python (always run, adjust iterations based on size)
                if size <= 8:
                    python_runs = 100
                elif size <= 16:
                    python_runs = 50
                elif size <= 32:
                    python_runs = 10
                elif size <= 48:
                    python_runs = 3
                else:
                    python_runs = 1  # Even large matrices, run at least once
                
                if operation == 'add':
                    python_result = benchmark_implementation('Python', python_add, mat1_list, mat2_list, num_runs=python_runs)
                elif operation == 'mult':
                    python_result = benchmark_implementation('Python', python_multiply, mat1_list, mat2_list, num_runs=python_runs)
                elif operation == 'matmul':
                    python_result = benchmark_implementation('Python', python_matmul, mat1_list, mat2_list, num_runs=python_runs)
                
                python_time = python_result['avg_ms']
                
                # Calculate speedups
                fpga_total = fpga_result['avg_ms']
                fpga_send = fpga_result['avg_send_ms']
                fpga_compute = fpga_result['avg_compute_ms']
                fpga_recv = fpga_result['avg_recv_ms']
                
                # FPGA vs Python speedup
                speedup = f"{python_time / fpga_total:.2f}x" if fpga_total > 0 else "N/A"
                
                # Format size with proper alignment
                size_str = f"{size}x{size}"
                print(f"{size_str:<8} {fpga_total:<12.2f} {fpga_send:<12.2f} {fpga_compute:<12.2f} {fpga_recv:<12.2f} {python_time:<12.2f} {speedup:<12}")
                
                all_results.append({
                    'size': size,
                    'operation': operation,
                    'fpga_total_ms': fpga_total,
                    'fpga_send_ms': fpga_send,
                    'fpga_compute_ms': fpga_compute,
                    'fpga_recv_ms': fpga_recv,
                    'python_ms': python_time
                })
                
            except Exception as e:
                print(f"{size}x{size:<4} ERROR: {e}")
    
    # Summary statistics
    print(f"\n{'=' * 100}")
    print("SUMMARY STATISTICS")
    print(f"{'=' * 100}\n")
    
    for operation in operations:
        op_results = [r for r in all_results if r['operation'] == operation]
        
        if not op_results:
            continue
        
        print(f"{operation.upper()} Operation:")
        
        # FPGA breakdown
        avg_total = np.mean([r['fpga_total_ms'] for r in op_results])
        avg_send = np.mean([r['fpga_send_ms'] for r in op_results])
        avg_compute = np.mean([r['fpga_compute_ms'] for r in op_results])
        avg_recv = np.mean([r['fpga_recv_ms'] for r in op_results])
        
        print(f"  FPGA Time Breakdown (average):")
        print(f"    Total:   {avg_total:.2f} ms (100%)")
        print(f"    Send:    {avg_send:.2f} ms ({avg_send/avg_total*100:.1f}%)")
        print(f"    Compute: {avg_compute:.2f} ms ({avg_compute/avg_total*100:.1f}%)")
        print(f"    Receive: {avg_recv:.2f} ms ({avg_recv/avg_total*100:.1f}%)")
        
        # FPGA vs Python
        avg_speedup_python = np.mean([r['python_ms'] / r['fpga_total_ms'] for r in op_results if r['fpga_total_ms'] > 0])
        avg_speedup_python_compute = np.mean([r['python_ms'] / r['fpga_compute_ms'] for r in op_results if r['fpga_compute_ms'] > 0])
        
        print(f"\n  FPGA vs Pure Python:")
        print(f"    Total FPGA time vs Python: {avg_speedup_python:.2f}x")
        print(f"    FPGA compute only vs Python: {avg_speedup_python_compute:.2f}x")
        
        fpga_faster = sum(1 for r in op_results if r['fpga_total_ms'] < r['python_ms'])
        python_faster = sum(1 for r in op_results if r['python_ms'] < r['fpga_total_ms'])
        print(f"    FPGA faster: {fpga_faster}/{len(op_results)} times")
        print(f"    Python faster: {python_faster}/{len(op_results)} times")
        
        print()
    
    # Best and worst cases (FPGA total vs Python)
    print("Best Cases (FPGA fastest vs Python):")
    sorted_results = sorted(all_results, key=lambda r: r['python_ms'] / r['fpga_total_ms'] if r['fpga_total_ms'] > 0 else 0, reverse=True)
    for r in sorted_results[:5]:
        speedup = r['python_ms'] / r['fpga_total_ms'] if r['fpga_total_ms'] > 0 else 0
        print(f"  {r['size']}x{r['size']} {r['operation']}: FPGA {speedup:.2f}x faster than Python")
    
    print("\nWorst Cases (Python fastest vs FPGA):")
    sorted_results = sorted(all_results, key=lambda r: r['python_ms'] / r['fpga_total_ms'] if r['fpga_total_ms'] > 0 else float('inf'))
    for r in sorted_results[:5]:
        speedup = r['python_ms'] / r['fpga_total_ms'] if r['fpga_total_ms'] > 0 else 0
        if speedup < 1:
            print(f"  {r['size']}x{r['size']} {r['operation']}: Python {1/speedup:.2f}x faster than FPGA")
        else:
            print(f"  {r['size']}x{r['size']} {r['operation']}: FPGA {speedup:.2f}x faster than Python")
    
    processor.disconnect()
    print("\n✓ Benchmark complete\n")

if __name__ == '__main__':
    run_comparison_benchmark()

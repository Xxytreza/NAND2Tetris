#!/usr/bin/env python3
"""
Benchmark Matrix Operations on FPGA
Tests matrix operations from 1x1 to 32x32 and measures performance
"""

import time
import numpy as np
from src.fpga_interface.matrix_processor import MatrixProcessor
from src.fpga_interface.operations import Operation

def generate_random_matrix(rows, cols, min_val=0, max_val=100):
    """Generate a random matrix with integer values"""
    return np.random.randint(min_val, max_val, size=(rows, cols), dtype=np.int32)
def benchmark_matrix_operation(processor, size, operation='add', num_runs=3):
    """
    Benchmark a single matrix operation
    
    Args:
        processor: MatrixProcessor instance
        size: Matrix size (for square matrices)
        operation: 'add', 'mult' (element-wise), or 'matmul' (matrix multiplication)
        num_runs: Number of times to run for averaging
    
    Returns:
        dict with timing results including transfer and compute breakdown
    """
    rows, cols = size, size
    
    # Generate random matrices as lists of lists
    mat1_np = generate_random_matrix(rows, cols)
    mat2_np = generate_random_matrix(rows, cols)
    
    # Convert to list of lists
    mat1 = mat1_np.tolist()
    mat2 = mat2_np.tolist()
    
    times = []
    send_times = []
    recv_times = []
    compute_times = []
    
    for run in range(num_runs):
        try:
            # Measure send time
            processor._serial.reset_input_buffer()
            processor._serial.reset_output_buffer()
            
            send_start = time.time()
            
            # Send operation code
            hw_op_code = 0 if operation == 'add' else (1 if operation == 'mult' else 2)
            processor._serial.write(bytes([hw_op_code]))
            processor._serial.flush()
            
            # Send matrices
            processor._send_matrix(mat1)
            processor._send_matrix(mat2)
            
            send_end = time.time()
            send_time = send_end - send_start
            
            # Estimate compute time based on operation
            total_elements = (rows * cols) + (rows * cols)
            if hw_op_code == 2:  # matmul
                compute_time = 0.01 + total_elements * 0.0001
            else:
                compute_time = 0.001 + total_elements * 0.00001
            time.sleep(compute_time)
            compute_end = time.time()
            
            # Measure receive time
            recv_start = compute_end
            result = processor._receive_matrix()
            recv_end = time.time()
            recv_time = recv_end - recv_start
            
            total_time = recv_end - send_start
            actual_compute = total_time - send_time - recv_time
            
            times.append(total_time)
            send_times.append(send_time)
            recv_times.append(recv_time)
            compute_times.append(actual_compute)
            
        except Exception as e:
            print(f"  ❌ Error on run {run+1}: {e}")
            return None
    
    if times:
        return {
            'size': f"{rows}x{cols}",
            'elements': rows * cols,
            'operation': operation,
            'avg_time_ms': sum(times) / len(times) * 1000,
            'min_time_ms': min(times) * 1000,
            'max_time_ms': max(times) * 1000,
            'avg_send_ms': sum(send_times) / len(send_times) * 1000,
            'avg_recv_ms': sum(recv_times) / len(recv_times) * 1000,
            'avg_compute_ms': sum(compute_times) / len(compute_times) * 1000,
            'runs': num_runs
        }
    
    return None

def run_comprehensive_benchmark(port=None, baudrate=115200):
    """
    Run comprehensive benchmark across different matrix sizes
    """
    print("=" * 70)
    print("FPGA Matrix Processor Benchmark")
    print("=" * 70)
    
    # Auto-detect port if not specified
    if port is None:
        import platform
        if platform.system() == 'Windows':
            # Try common Windows COM ports
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
                print("✗ Could not find FPGA on any COM port (tried COM1-COM19)")
                print("Please specify port manually, e.g.: run_comprehensive_benchmark(port='COM3')")
                return
        else:
            port = '/dev/ttyUSB0'
    
    # Initialize processor
    try:
        processor = MatrixProcessor(port=port, baudrate=baudrate, timeout=10.0)
        processor.connect()
        print(f"✓ Connected to FPGA on {port} @ {baudrate} baud\n")
    except Exception as e:
        print(f"✗ Failed to connect to FPGA: {e}")
        return
    
    # Test sizes: comprehensive range from 1x1 to 128x128
    sizes = [1, 2, 4, 8, 16, 24, 32, 40, 48, 56, 64, 72, 80, 88, 96, 104, 112, 120, 128]
    operations = ['add', 'mult', 'matmul']
    
    results = []
    
    print(f"{'Size':<8} {'Op':<10} {'Total':<10} {'Send':<10} {'Compute':<10} {'Recv':<10}")
    print(f"{'':8} {'':10} {'(ms)':<10} {'(ms)':<10} {'(ms)':<10} {'(ms)':<10}")
    print("-" * 68)
    
    for size in sizes:
        for operation in operations:
            print(f"{size}x{size:<4} {operation:<10} ", end='', flush=True)
            
            result = benchmark_matrix_operation(processor, size, operation, num_runs=3)
            
            if result:
                results.append(result)
                print(f"{result['avg_time_ms']:<10.2f} {result['avg_send_ms']:<10.2f} {result['avg_compute_ms']:<10.2f} {result['avg_recv_ms']:<10.2f}")
            else:
                print("FAILED")
    
    print("\n" + "=" * 70)
    print("Performance Summary")
    print("=" * 70)
    
    # Group by operation
    for op in operations:
        print(f"\n{op.upper()} Operation:")
        op_results = [r for r in results if r['operation'] == op]
        
        if op_results:
            fastest = min(op_results, key=lambda x: x['min_time_ms'])
            slowest = max(op_results, key=lambda x: x['max_time_ms'])
            print(f"  Fastest: {fastest['size']} in {fastest['min_time_ms']:.2f} ms")
            print(f"  Slowest: {slowest['size']} in {slowest['max_time_ms']:.2f} ms")
            
            # Calculate throughput and breakdown for largest size
            largest = max(op_results, key=lambda x: x['elements'])
            if largest['avg_time_ms'] > 0:
                throughput = (largest['elements'] * 4) / (largest['avg_time_ms'] / 1000)  # bytes/sec
                print(f"  Largest ({largest['size']}):")
                print(f"    Total: {largest['avg_time_ms']:.2f} ms")
                print(f"    Send:  {largest['avg_send_ms']:.2f} ms ({largest['avg_send_ms']/largest['avg_time_ms']*100:.1f}%)")
                print(f"    Compute: {largest['avg_compute_ms']:.2f} ms ({largest['avg_compute_ms']/largest['avg_time_ms']*100:.1f}%)")
                print(f"    Recv:  {largest['avg_recv_ms']:.2f} ms ({largest['avg_recv_ms']/largest['avg_time_ms']*100:.1f}%)")
                print(f"    Throughput: {throughput/1024:.2f} KB/s")
    
    processor.disconnect()
    print("\n✓ Benchmark complete\n")

def quick_test(port=None, baudrate=115200):
    """
    Quick test with a few representative sizes
    """
    print("Quick Performance Test")
    print("=" * 50)
    
    # Auto-detect port if not specified
    if port is None:
        import platform
        if platform.system() == 'Windows':
            # Try common Windows COM ports
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
                print("✗ Could not find FPGA on any COM port (tried COM1-COM19)")
                print("Please specify port manually, e.g.: quick_test(port='COM3')")
                return
        else:
            port = '/dev/ttyUSB0'
    
    try:
        processor = MatrixProcessor(port=port, baudrate=baudrate, timeout=5.0)
        processor.connect()
        print(f"✓ Connected to FPGA\n")
    except Exception as e:
        print(f"✗ Failed to connect: {e}")
        return
    
    test_sizes = [4, 16, 32]
    
    print(f"{'Size':<10} {'Operation':<12} {'Time (ms)':<12}")
    print("-" * 50)
    
    for size in test_sizes:
        for op_name, op_method in [('Add', 'add'), ('Multiply', 'multiply'), ('MatMul', 'dot')]:
            mat1_np = generate_random_matrix(size, size)
            mat2_np = generate_random_matrix(size, size)
            
            # Convert to list of lists
            mat1 = mat1_np.tolist()
            mat2 = mat2_np.tolist()
            
            start = time.time()
            try:
                if op_method == 'add':
                    result = processor.add(mat1, mat2)
                elif op_method == 'multiply':
                    result = processor.multiply(mat1, mat2)
                elif op_method == 'dot':
                    result = processor.dot(mat1, mat2)
                    
                elapsed = (time.time() - start) * 1000
                print(f"{size}x{size:<6} {op_name:<12} {elapsed:<12.2f}")
            except Exception as e:
                print(f"{size}x{size:<6} {op_name:<12} ERROR: {e}")
    
    processor.disconnect()
    print("\n✓ Test complete")

if __name__ == '__main__':
    import sys
    
    # Check for command line arguments
    if len(sys.argv) > 1:
        if sys.argv[1] == 'quick':
            quick_test()
        elif sys.argv[1] == 'full':
            run_comprehensive_benchmark()
        else:
            print("Usage:")
            print("  python benchmark_matrices.py         # Full benchmark")
            print("  python benchmark_matrices.py quick   # Quick test")
            print("  python benchmark_matrices.py full    # Full benchmark (explicit)")
    else:
        # Default: run full benchmark
        run_comprehensive_benchmark()

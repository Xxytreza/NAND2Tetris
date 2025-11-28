"""
FPGA Interface Library
A Python library for communicating with FPGA vector and matrix processors via UART.
"""

from .vector_processor import VectorProcessor
from .matrix_processor import MatrixProcessor
from .operations import Operation

__all__ = ['VectorProcessor', 'MatrixProcessor', 'Operation']
__version__ = '1.0.0'

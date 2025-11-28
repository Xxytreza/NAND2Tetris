"""
Operation codes for FPGA processors.
"""

from enum import IntEnum


class Operation(IntEnum):
    """Operation codes supported by FPGA processors."""
    
    ADD = 0              # Element-wise addition
    DOT = 1              # Dot product (vectors) / Matrix multiplication (matrices)
    MULTIPLY = 2         # Element-wise multiplication
    
    def __str__(self):
        names = {
            0: "Addition",
            1: "Dot Product / Matrix Multiply",
            2: "Element-wise Multiply"
        }
        return names.get(self.value, "Unknown")

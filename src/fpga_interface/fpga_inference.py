#!/usr/bin/env python3

import numpy as np
from typing import List, Tuple, Optional, Callable
import time
from .matrix_processor import MatrixProcessor


class FPGAInference:
    def __init__(self, port: str = 'COM3', baudrate: int = 115200, verbose: bool = True):
        self.processor = MatrixProcessor(port=port, baudrate=baudrate, timeout=30.0)
        self.verbose = verbose
        self.layers = []
        self.is_connected = False
        
    def connect(self):
        if self.verbose:
            print(f"Connecting to FPGA on {self.processor.port}...")
        self.processor.connect()
        self.is_connected = True
        if self.verbose:
            print("✓ Connected to FPGA")
    
    def disconnect(self):
        if self.is_connected:
            self.processor.disconnect()
            self.is_connected = False
            if self.verbose:
                print("✓ Disconnected from FPGA")
    
    def add_linear_layer(self, weights: np.ndarray, bias: Optional[np.ndarray] = None, name: str = "linear"):
        if weights.dtype != np.int32:
            if self.verbose:
                print(f"⚠ Converting {name} weights from {weights.dtype} to int32")
            weights = weights.astype(np.int32)
        
        if bias is not None and bias.dtype != np.int32:
            if self.verbose:
                print(f"⚠ Converting {name} bias from {bias.dtype} to int32")
            bias = bias.astype(np.int32)
        
        self.layers.append({
            'type': 'linear',
            'name': name,
            'weights': weights,
            'bias': bias,
            'device': 'fpga'
        })
        
        if self.verbose:
            print(f"Added Linear layer '{name}': {weights.shape[0]}×{weights.shape[1]}" + 
                  (f" + bias({bias.shape[0]})" if bias is not None else ""))
    
    def add_relu(self, name: str = "relu"):
        self.layers.append({
            'type': 'relu',
            'name': name,
            'device': 'cpu'
        })
        if self.verbose:
            print(f"Added ReLU layer '{name}' (CPU)")
    
    def add_sigmoid(self, name: str = "sigmoid"):
        self.layers.append({
            'type': 'sigmoid',
            'name': name,
            'device': 'cpu'
        })
        if self.verbose:
            print(f"Added Sigmoid layer '{name}' (CPU)")
    
    def add_tanh(self, name: str = "tanh"):
        self.layers.append({
            'type': 'tanh',
            'name': name,
            'device': 'cpu'
        })
        if self.verbose:
            print(f"Added Tanh layer '{name}' (CPU)")
    
    def add_softmax(self, name: str = "softmax"):
        self.layers.append({
            'type': 'softmax',
            'name': name,
            'device': 'cpu'
        })
        if self.verbose:
            print(f"Added Softmax layer '{name}' (CPU)")
    
    def add_custom(self, func: Callable, name: str = "custom", device: str = "cpu"):
        self.layers.append({
            'type': 'custom',
            'name': name,
            'func': func,
            'device': device
        })
        if self.verbose:
            print(f"Added Custom layer '{name}' ({device.upper()})")
    
    def forward(self, x: np.ndarray, return_timing: bool = False) -> np.ndarray:

        if not self.is_connected:
            raise RuntimeError("FPGA not connected. Call connect() first.")
        
        # Ensure input is 2D
        if x.ndim == 1:
            x = x.reshape(1, -1)  # (features,) → (1, features)
        
        # Convert to int32 if needed
        if x.dtype != np.int32:
            if self.verbose:
                print(f"⚠ Converting input from {x.dtype} to int32")
            x = x.astype(np.int32)
        
        timing = {}
        total_start = time.perf_counter()
        
        if self.verbose:
            print(f"\n{'='*60}")
            print(f"Forward pass - Input shape: {x.shape}")
            print(f"{'='*60}")
        
        current = x
        
        for i, layer in enumerate(self.layers):
            layer_start = time.perf_counter()
            layer_name = f"{layer['name']} (#{i})"
            
            if layer['type'] == 'linear':
                # Matrix multiplication: current @ weights + bias
                weights = layer['weights']
                bias = layer['bias']
                
                if self.verbose:
                    print(f"\n[{layer_name}] Linear: {current.shape} @ {weights.shape}")
                
                # Perform matmul on FPGA
                # Note: current is (batch, in_features), weights is (in_features, out_features)
                from .operations import Operation
                result = self.processor.execute(
                    Operation.DOT,
                    current.tolist(),
                    weights.tolist()
                )
                current = np.array(result, dtype=np.int32)
                
                # Add bias if present
                if bias is not None:
                    if self.verbose:
                        print(f"  Adding bias: {bias.shape}")
                    # Bias broadcast across batch dimension
                    current = current + bias.reshape(1, -1)
                
            elif layer['type'] == 'relu':
                if self.verbose:
                    print(f"\n[{layer_name}] ReLU: {current.shape}")
                current = np.maximum(0, current)
            
            elif layer['type'] == 'sigmoid':
                if self.verbose:
                    print(f"\n[{layer_name}] Sigmoid: {current.shape}")
                current = np.clip(current, -500, 500)
                current = 1.0 / (1.0 + np.exp(-current))
            
            elif layer['type'] == 'tanh':
                if self.verbose:
                    print(f"\n[{layer_name}] Tanh: {current.shape}")
                current = np.tanh(current)
            
            elif layer['type'] == 'softmax':
                if self.verbose:
                    print(f"\n[{layer_name}] Softmax: {current.shape}")
                # Numerical stability: subtract max
                exp_x = np.exp(current - np.max(current, axis=-1, keepdims=True))
                current = exp_x / np.sum(exp_x, axis=-1, keepdims=True)
            
            elif layer['type'] == 'custom':
                if self.verbose:
                    print(f"\n[{layer_name}] Custom: {current.shape}")
                current = layer['func'](current)
            
            layer_time = time.perf_counter() - layer_start
            timing[layer_name] = layer_time
            
            if self.verbose:
                print(f"  Output shape: {current.shape}")
                print(f"  Time: {layer_time*1000:.2f} ms")
        
        total_time = time.perf_counter() - total_start
        timing['total'] = total_time
        
        if self.verbose:
            print(f"\n{'='*60}")
            print(f"Total inference time: {total_time*1000:.2f} ms")
            print(f"{'='*60}\n")
        
        if return_timing:
            return current, timing
        return current
    
    def predict(self, x: np.ndarray) -> int:
        output = self.forward(x)
        return int(np.argmax(output))
    
    def predict_proba(self, x: np.ndarray) -> np.ndarray:

        output = self.forward(x)
        if output.min() < 0 or output.max() > 1:
            exp_x = np.exp(output - np.max(output))
            output = exp_x / np.sum(exp_x)
        return output.flatten()
    
    def summary(self):
        total_params = 0
        for i, layer in enumerate(self.layers):
            layer_name = f"{i}. {layer['name']}"
            layer_type = layer['type']
            device = layer['device'].upper()
            
            if layer_type == 'linear':
                weights = layer['weights']
                bias = layer['bias']
                params = weights.size + (bias.size if bias is not None else 0)
                total_params += params
                param_str = f"{params:,}"
            else:
                param_str = "0"
            
            print(f"{layer_name:<30} {layer_type:<15} {device:<10} {param_str}")

    
    def __enter__(self):
        self.connect()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.disconnect()


def load_pytorch_weights(pytorch_model, convert_to_int: bool = True, scale_factor: float = 100.0):
    import torch
    
    layers = []
    for module in pytorch_model.modules():
        if isinstance(module, torch.nn.Linear):
            weights = module.weight.detach().cpu().numpy().T  # Transpose
            bias = module.bias.detach().cpu().numpy() if module.bias is not None else None
            
            if convert_to_int:
                weights = (weights * scale_factor).astype(np.int32)
                if bias is not None:
                    bias = (bias * scale_factor).astype(np.int32)
            
            layers.append((weights, bias))
    
    return layers

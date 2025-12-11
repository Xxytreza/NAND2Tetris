#!/usr/bin/env python3


import numpy as np
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from src.fpga_interface.fpga_inference import FPGAInference
from src.utils.train_mnist_model import load_fpga_weights
import platform
import serial

import torch
from torchvision import datasets, transforms
import matplotlib.pyplot as plt


def auto_detect_port():
    if platform.system() == 'Windows':
        for i in range(1, 20):
            try:
                port = f'COM{i}'
                ser = serial.Serial(port, 115200, timeout=0.5)
                ser.close()
                print(f"Found FPGA on {port}")
                return port
            except:
                continue
        return None
    else:
        import glob
        ports = glob.glob('/dev/ttyUSB*') + glob.glob('/dev/ttyACM*')
        if ports:
            print(f"Found FPGA on {ports[0]}")
            return ports[0]
        return None


def preprocess_mnist_image(image, scale_factor=100):
    mean = 0.1307
    std = 0.3081
    
    image_denorm = (image * std) + mean
    image_255 = (image_denorm * 255).numpy().flatten()
    
    image_int = (image_255 * scale_factor / 255).astype(np.int32)
    
    return image_int


def load_mnist_test_images(num_images=10):

    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.1307,), (0.3081,))
    ])
    
    test_dataset = datasets.MNIST('./data', train=False, download=True, transform=transform)
    
    indices = np.random.choice(len(test_dataset), num_images, replace=False)
    
    images = []
    labels = []
    for idx in indices:
        image, label = test_dataset[idx]
        images.append(image)
        labels.append(label)
    
    return images, labels, test_dataset


def display_predictions(images, true_labels, predictions, num_show=5):
    num_show = min(num_show, len(images))
    
    fig, axes = plt.subplots(1, num_show, figsize=(15, 3))
    
    for i in range(num_show):
        ax = axes[i] if num_show > 1 else axes
        
        img = images[i].squeeze()
        img = (img * 0.3081) + 0.1307
        
        ax.imshow(img, cmap='gray')
        ax.axis('off')
        
        is_correct = predictions[i] == true_labels[i]
        color = 'green' if is_correct else 'red'
        
        ax.set_title(f'True: {true_labels[i]}\nPred: {predictions[i]}', 
                    color=color, fontsize=12, fontweight='bold')
    
    plt.tight_layout()
    plt.savefig('mnist_fpga_predictions.png', dpi=150, bbox_inches='tight')
    print(f"\nPredictions saved to mnist_fpga_predictions.png")
    plt.show()


def run_fpga_inference():
    print("\nLoading pre-trained weights...")
    weights = load_fpga_weights('mnist_weights_fpga.pkl')
    
    fc1_weight = weights['fc1_weight']
    fc1_bias = weights['fc1_bias']
    fc2_weight = weights['fc2_weight']
    fc2_bias = weights['fc2_bias']
    scale_factor = weights['scale_factor']
    
    # Auto-detect port
    port = auto_detect_port()
    if port is None:
        print("\nCould not find FPGA. Please check connection.")
        return
    
    # Load test images
    print("\nLoading MNIST test images...")
    images, labels, test_dataset = load_mnist_test_images(num_images=10)
    
    if images is None:
        print("\nCould not load MNIST dataset")
        return
    
    print(f"Loaded {len(images)} test images")
    
    print("\nBuilding FPGA inference model...")
    with FPGAInference(port=port, baudrate=115200, verbose=False) as model:
        model.add_linear_layer(fc1_weight, fc1_bias, name="fc1")
        model.add_relu(name="relu1")
        model.add_linear_layer(fc2_weight, fc2_bias, name="fc2")

        predictions = []
        total_time = 0
        
        for i, (image, label) in enumerate(zip(images, labels)):
            print(f"\nImage {i+1}/{len(images)}: True label = {label}")
            
            image_int = preprocess_mnist_image(image, scale_factor)
            
            output, timing = model.forward(image_int, return_timing=True)
            pred = int(np.argmax(output))
            
            predictions.append(pred)
            total_time += timing['total']
            
            is_correct = pred == label
            print(f"  Predicted: {pred} {'✓ CORRECT' if is_correct else '✗ WRONG'}")
            print(f"  Time: {timing['total']*1000:.2f} ms")
            print(f"  Output logits: {output.flatten()[:10]}")
        
        accuracy = 100.0 * sum(p == l for p, l in zip(predictions, labels)) / len(labels)
        avg_time = total_time / len(images)
        
        print(f"Accuracy: {accuracy:.1f}% ({sum(p == l for p, l in zip(predictions, labels))}/{len(labels)})")
        print(f"Average time per image: {avg_time*1000:.2f} ms")
        print(f"Total time: {total_time:.2f} seconds")
        
        for i, (label, pred) in enumerate(zip(labels, predictions)):
            print(f"  Image {i+1}: True={label}, Pred={pred}")

if __name__ == '__main__':
    run_fpga_inference()

#!/usr/bin/env python3

import numpy as np
import pickle
import os
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
from torchvision import datasets, transforms

class SmallMNIST(nn.Module):
    
    def __init__(self):
        super(SmallMNIST, self).__init__()
        self.fc1 = nn.Linear(784, 32)
        self.fc2 = nn.Linear(32, 10)
    
    def forward(self, x):
        x = x.view(-1, 784)
        x = torch.relu(self.fc1(x))
        x = self.fc2(x)
        return x


def train_model(epochs=5, batch_size=64, lr=0.01):
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"Using device: {device}")
    
    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.1307,), (0.3081,))
    ])
    
    train_dataset = datasets.MNIST('./data', train=True, download=True, transform=transform)
    test_dataset = datasets.MNIST('./data', train=False, download=True, transform=transform)
    
    train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True)
    test_loader = DataLoader(test_dataset, batch_size=batch_size, shuffle=False)
    
    print(f"Training samples: {len(train_dataset)}")
    print(f"Test samples: {len(test_dataset)}")
    
    model = SmallMNIST().to(device)
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=lr)
    
    total_params = sum(p.numel() for p in model.parameters())
    print(f"\nModel parameters: {total_params:,}")
    print(f"  fc1: {784 * 32 + 32:,}")
    print(f"  fc2: {32 * 10 + 10:,}")
    
    print(f"\nTraining for {epochs} epochs...")
    for epoch in range(epochs):
        model.train()
        train_loss = 0
        correct = 0
        total = 0
        
        for batch_idx, (data, target) in enumerate(train_loader):
            data, target = data.to(device), target.to(device)
            
            optimizer.zero_grad()
            output = model(data)
            loss = criterion(output, target)
            loss.backward()
            optimizer.step()
            
            train_loss += loss.item()
            pred = output.argmax(dim=1, keepdim=True)
            correct += pred.eq(target.view_as(pred)).sum().item()
            total += target.size(0)
            
            if batch_idx % 100 == 0:
                print(f'  Epoch {epoch+1}/{epochs} [{batch_idx * len(data)}/{len(train_loader.dataset)} '
                      f'({100. * batch_idx / len(train_loader):.0f}%)] '
                      f'Loss: {loss.item():.4f}')
        
        train_acc = 100. * correct / total
        print(f'Epoch {epoch+1}/{epochs} - Train Loss: {train_loss/len(train_loader):.4f}, '
              f'Train Acc: {train_acc:.2f}%')
        
        model.eval()
        test_loss = 0
        correct = 0
        total = 0
        
        with torch.no_grad():
            for data, target in test_loader:
                data, target = data.to(device), target.to(device)
                output = model(data)
                test_loss += criterion(output, target).item()
                pred = output.argmax(dim=1, keepdim=True)
                correct += pred.eq(target.view_as(pred)).sum().item()
                total += target.size(0)
        
        test_acc = 100. * correct / total
        print(f'         Test Loss: {test_loss/len(test_loader):.4f}, '
              f'Test Acc: {test_acc:.2f}%\n')
    
    return model


def save_weights_for_fpga(model, filename='mnist_weights_fpga.pkl', scale_factor=100):
    
    print(f"\nSaving weights to {filename}...")
    
    model.eval()
    
    # Extract weights
    fc1_weight = model.fc1.weight.detach().cpu().numpy().T  # (784, 32)
    fc1_bias = model.fc1.bias.detach().cpu().numpy()  # (32,)
    
    fc2_weight = model.fc2.weight.detach().cpu().numpy().T  # (32, 10)
    fc2_bias = model.fc2.bias.detach().cpu().numpy()  # (10,)
    
    print(f"  fc1 weights: {fc1_weight.shape} (float32)")
    print(f"  fc1 bias: {fc1_bias.shape} (float32)")
    print(f"  fc2 weights: {fc2_weight.shape} (float32)")
    print(f"  fc2 bias: {fc2_bias.shape} (float32)")
    
    # Convert to int32 with scaling
    fc1_weight_int = (fc1_weight * scale_factor).astype(np.int32)
    fc1_bias_int = (fc1_bias * scale_factor).astype(np.int32)
    fc2_weight_int = (fc2_weight * scale_factor).astype(np.int32)
    fc2_bias_int = (fc2_bias * scale_factor).astype(np.int32)
    
    print(f"\nScaled by {scale_factor}x and converted to int32:")
    print(f"  fc1 weights: min={fc1_weight_int.min()}, max={fc1_weight_int.max()}")
    print(f"  fc1 bias: min={fc1_bias_int.min()}, max={fc1_bias_int.max()}")
    print(f"  fc2 weights: min={fc2_weight_int.min()}, max={fc2_weight_int.max()}")
    print(f"  fc2 bias: min={fc2_bias_int.min()}, max={fc2_bias_int.max()}")
    
    # Save
    weights_dict = {
        'fc1_weight': fc1_weight_int,
        'fc1_bias': fc1_bias_int,
        'fc2_weight': fc2_weight_int,
        'fc2_bias': fc2_bias_int,
        'scale_factor': scale_factor,
        'architecture': '784->32->10',
        'accuracy': None  # Will be filled if provided
    }
    
    with open(filename, 'wb') as f:
        pickle.dump(weights_dict, f)
    
    return weights_dict


def load_fpga_weights(filename='mnist_weights_fpga.pkl'):
    
    with open(filename, 'rb') as f:
        weights_dict = pickle.load(f)
    
    print(f"Loaded weights from {filename}")
    print(f"  Architecture: {weights_dict['architecture']}")
    print(f"  Scale factor: {weights_dict['scale_factor']}")
    if weights_dict['accuracy'] is not None:
        print(f"  Model accuracy: {weights_dict['accuracy']:.2f}%")
    
    return weights_dict


def test_on_sample_images(model, num_samples=10):
    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.1307,), (0.3081,))
    ])
    
    test_dataset = datasets.MNIST('./data', train=False, download=False, transform=transform)
    
    model.eval()
    device = next(model.parameters()).device
    
    indices = np.random.choice(len(test_dataset), num_samples, replace=False)
    
    correct = 0
    for i, idx in enumerate(indices):
        image, label = test_dataset[idx]
        
        with torch.no_grad():
            output = model(image.unsqueeze(0).to(device))
            pred = output.argmax(dim=1).item()
        
        is_correct = pred == label
        correct += is_correct
        
        print(f"Sample {i+1}: True={label}, Predicted={pred} {'✓' if is_correct else '✗'}")
    
    print(f"\nAccuracy on {num_samples} samples: {100. * correct / num_samples:.1f}%")


if __name__ == '__main__':

    # Train
    model = train_model(epochs=5, batch_size=64, lr=0.01)
    
    if model is None:
        exit(1)
    
    # Test on samples
    test_on_sample_images(model, num_samples=10)
    
    # Save weights
    weights_dict = save_weights_for_fpga(model, 'mnist_weights_fpga.pkl', scale_factor=100)
    
    print("Training complete!")

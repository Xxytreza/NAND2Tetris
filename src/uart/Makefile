# UART Testbench Makefile

# Tools
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

# Directories
SRC_DIR = .
BUILD_DIR = build

# Files
SOURCES = uart_transmitter.sv uart_receiver.sv uart_loopback_tb.sv
TB_TOP = uart_loopback_tb
VVP_FILE = $(BUILD_DIR)/$(TB_TOP).vvp
VCD_FILE = $(BUILD_DIR)/$(TB_TOP).vcd

# Default target
.PHONY: all
all: sim

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Compile
.PHONY: compile
compile: $(BUILD_DIR)
	@echo "Compiling UART modules..."
	$(IVERILOG) -g2012 -o $(VVP_FILE) $(SOURCES)
	@echo "Compilation successful!"

# Simulate
.PHONY: sim
sim: compile
	@echo "Running simulation..."
	cd $(BUILD_DIR) && $(VVP) $(TB_TOP).vvp
	@echo "Simulation complete!"

# View waveform
.PHONY: wave
wave: sim
	@echo "Opening waveform viewer..."
	$(GTKWAVE) $(VCD_FILE) &

# Clean
.PHONY: clean
clean:
	@echo "Cleaning build directory..."
	rm -rf $(BUILD_DIR)
	@echo "Clean complete!"

# Help
.PHONY: help
help:
	@echo "UART Testbench Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  make          - Compile and run simulation (default)"
	@echo "  make compile  - Compile only"
	@echo "  make sim      - Compile and simulate"
	@echo "  make wave     - Run simulation and open waveform viewer"
	@echo "  make clean    - Remove build directory"
	@echo "  make help     - Show this help message"

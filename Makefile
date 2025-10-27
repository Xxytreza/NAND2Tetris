# Verilog Project Makefile

# Tools
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

# Directories
SRC_DIR = src/basic/1_bit/and_gate
BUILD_DIR = build

TOP_MODULE = and_gate_tb
VCD_FILE = $(BUILD_DIR)/waveform.vcd
VVP_FILE = $(BUILD_DIR)/$(TOP_MODULE).vvp

# Source files
VERILOG_SOURCES = $(wildcard $(SRC_DIR)/*.v)


# Default target
all: simulate

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Compile Verilog files
compile: $(BUILD_DIR) $(VVP_FILE)

$(VVP_FILE): $(VERILOG_SOURCES)
	$(IVERILOG) -o $(VVP_FILE) -I$(SRC_DIR) $(VERILOG_SOURCES)

# Run simulation
simulate: compile
	$(VVP) $(VVP_FILE)

# View waveform
view: $(VCD_FILE)
	$(GTKWAVE) $(VCD_FILE) &

# Run simulation and view waveform
run: simulate view

# Synthesis (using yosys if available)
synth: $(BUILD_DIR)
	@if command -v yosys > /dev/null; then \
		yosys -p "read_verilog $(SRC_DIR)/and_gate.v; synth -top and_gate; show" 2>/dev/null || echo "Synthesis completed (graphical output may not be available)"; \
	else \
		echo "Yosys not available for synthesis"; \
	fi

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)
	rm -f *.vcd *.vvp

# Lint Verilog code (if verilator is available)
lint:
	@if command -v verilator > /dev/null; then \
		verilator --lint-only -Wall $(SRC_DIR)/*.v; \
	else \
		echo "Verilator not available for linting"; \
	fi




# ------------------------- Make test target -------------------------
# Automatically find all testbenches
TESTBENCHES := $(shell find src -name "*_tb.v")
VVP_FILES := $(TESTBENCHES:src/%.v=build/%.vvp)

# Compile each testbench
build/%.vvp: src/%.v
	@mkdir -p $(dir $@)
	@echo "Compiling $< ..."
	$(IVERILOG) -o $@ -I$(dir $<) $(wildcard $(dir $<)*.v)

# Run all testbenches
test: $(VVP_FILES)
	@for vvp_file in $(VVP_FILES); do \
		echo "Running $$vvp_file..."; \
		$(VVP) $$vvp_file || exit 1; \
	done
	@echo "✅ All testbenches completed successfully"


# Help target
help:
	@echo "Available targets:"
	@echo "  all      - Compile and simulate (default)"
	@echo "  compile  - Compile Verilog sources"
	@echo "  simulate - Run simulation"
	@echo "  view     - View waveform with GTKWave"
	@echo "  run      - Simulate and view waveform"
	@echo "  synth    - Synthesize with Yosys (if available)"
	@echo "  lint     - Lint code with Verilator (if available)"
	@echo "  clean    - Remove build artifacts"
	@echo "  help     - Show this help message"

.PHONY: all compile simulate view run synth lint clean help


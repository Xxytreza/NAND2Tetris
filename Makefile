# ===============================
# Top-Level Verilog Project Makefile
# ===============================

# Tools
IVERILOG = iverilog -g2012
VVP = vvp
GTKWAVE = gtkwave

# Centralized build folder
BUILD_DIR := $(abspath build)
WAVES_DIR := $(BUILD_DIR)/waves
LOGS_DIR := $(BUILD_DIR)/logs

# Source directories
SRC_DIR := src
BASIC_DIR := $(SRC_DIR)/basic
OPERATORS_DIR := $(SRC_DIR)/operators
CPU_DIR := $(SRC_DIR)/cpus

# Find all testbenches recursively
TESTBENCHES := $(shell find $(SRC_DIR) -name "*_tb.sv")

# Map testbenches to build outputs
VVP_FILES := $(TESTBENCHES:$(SRC_DIR)/%.sv=$(BUILD_DIR)/%.vvp)

# Default target
all: $(BUILD_DIR)/cpu_wrapper.vvp | $(BUILD_DIR) $(WAVES_DIR) $(LOGS_DIR)

# ===============================
# 1️⃣ Create build directories
# ===============================
$(BUILD_DIR) $(WAVES_DIR) $(LOGS_DIR):
	mkdir -p $@

# ===============================
# 2️⃣ Compile each testbench
# ===============================
# Generic rule: compile testbench with all sources it may depend on
# Precompute source file lists once
# Find all non-testbench source files
BASIC_SRC := $(shell find $(BASIC_DIR) -name "*.sv" ! -name "*_tb.sv" 2>/dev/null)
OPERATORS_SRC := $(shell find $(OPERATORS_DIR) -name "*.sv" ! -name "*_tb.sv" 2>/dev/null)
CPU_SRC := $(shell find $(CPU_DIR) -name "*.sv" ! -name "*_tb.sv" 2>/dev/null)


$(BUILD_DIR)/%.vvp: $(SRC_DIR)/%.sv | $(BUILD_DIR) $(WAVES_DIR) $(LOGS_DIR)
	@mkdir -p $(dir $@)
	@echo "🔧 Compiling $< ..."
	$(IVERILOG) -o $@ \
		-DBUILD_DIR=\"$(WAVES_DIR)\" \
		$(BASIC_SRC) $(OPERATORS_SRC) $(CPU_SRC) $<
	@echo "✅ Compiled $< to $@"


# ===============================
# 3️⃣ Run testbenches
# ===============================
test: $(VVP_FILES)
	@echo "🚀 Running all testbenches..."
	@for vvp_file in $(VVP_FILES); do \
		log_file=$(LOGS_DIR)/$$(basename $$vvp_file .vvp).log; \
		echo "▶️  Running $$vvp_file..."; \
		$(VVP) $$vvp_file > $$log_file 2>&1 && cat $$log_file || { echo "❌ Simulation failed for $$vvp_file. See $$log_file"; exit 1; } \
	done
	@echo "✅ All testbenches completed successfully!"

# ===============================
# 4️⃣ Utilities
# ===============================
view: 
	@if [ -f $(WAVES_DIR) ]; then \
		$(GTKWAVE) $(WAVES_DIR) & \
	else \
		echo "No waveforms found"; \
	fi

clean:
	rm -rf $(BUILD_DIR)
	@echo "🧹 Cleaned all build artifacts"

.PHONY: all test clean view

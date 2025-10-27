IVERILOG = iverilog
VVP = vvp
BUILD_DIR ?= build


all: test

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)/waves

$(BUILD_DIR)/waves/xor_gate_tb.vvp: xor_gate.v xor_gate_tb.v | $(BUILD_DIR)
	$(IVERILOG) -o $@ -DBUILD_DIR=\"$(BUILD_DIR)/waves\" xor_gate.v xor_gate_tb.v

test: $(BUILD_DIR)/waves/xor_gate_tb.vvp
	$(VVP) $<

clean:
	rm -rf $(BUILD_DIR) *.vvp *.vcd

.PHONY: all test clean

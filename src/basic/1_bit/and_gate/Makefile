IVERILOG = iverilog
VVP = vvp
BUILD_DIR ?= build


all: test

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/waves/and_gate_tb.vvp: and_gate.v and_gate_tb.v | $(BUILD_DIR)
	$(IVERILOG) -o $@ -DBUILD_DIR=\"$(BUILD_DIR)/waves\" and_gate.v and_gate_tb.v

test: $(BUILD_DIR)/waves/and_gate_tb.vvp
	$(VVP) $<

clean:
	rm -rf $(BUILD_DIR) *.vvp *.vcd

.PHONY: all test clean

IVERILOG = iverilog
VVP = vvp
BUILD_DIR ?= build


all: test

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)/waves

$(BUILD_DIR)/waves/add_operator_tb.vvp: add_operator.v add_operator_tb.v | $(BUILD_DIR)
	$(IVERILOG) -o $@ -DBUILD_DIR=\"$(BUILD_DIR)/waves\" add_operator.v add_operator_tb.v

test: $(BUILD_DIR)/waves/add_operator_tb.vvp
	$(VVP) $<

clean:
	rm -rf $(BUILD_DIR) *.vvp *.vcd

.PHONY: all test clean

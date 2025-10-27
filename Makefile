BUILD_DIR := $(abspath build)
SUBDIRS := $(shell find src -mindepth 1 -maxdepth 1 -type d)

all: test

test: build
	@echo "🚀 Running all testbenches..."
	${MAKE} --silent -B -C src BUILD_DIR=$(BUILD_DIR) test || exit 1
	@echo "✅ All testbenches completed!"

build: 
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(BUILD_DIR)/waves

clean: 
	@echo "🧹 Cleaning up all generated files..."
	${MAKE} -C src --silent clean || exit 1
	rm -rf $(BUILD_DIR)
	@echo "🧼 Cleanup completed!"

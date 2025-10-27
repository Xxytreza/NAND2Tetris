BUILD_DIR := $(abspath build)
SUBDIRS := $(shell find src -mindepth 1 -maxdepth 1 -type d)

all: test

test: build
	@echo "🚀 Running all testbenches..."
	@for dir in $(SUBDIRS); do \
		if [ -f $$dir/Makefile ]; then \
			echo "➡️  Entering $$dir"; \
			$(MAKE) --silent -C $$dir BUILD_DIR=$(BUILD_DIR) test || exit 1; \
		fi \
	done
	@echo "✅ All testbenches completed!"

build: 
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(BUILD_DIR)/waves

clean: 
	@echo "🧹 Cleaning up all generated files..."
	@for dir in $(SUBDIRS); do \
		if [ -f $$dir/Makefile ]; then \
			$(MAKE) --silent -C $$dir clean || exit 1; \
		fi \
	done
	rm -rf $(BUILD_DIR)
	@echo "🧼 Cleanup completed!"

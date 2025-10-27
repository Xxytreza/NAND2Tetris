.ONESHELL:
.SILENT:
SUBDIRS := $(shell find -mindepth 1 -maxdepth 3 -type d)

all: test

test:
	@for dir in $(SUBDIRS); do \
		if [ -f $$dir/Makefile ]; then \
			$(MAKE) --silent -C $$dir BUILD_DIR=$(BUILD_DIR) test || exit 1; \
		fi \
	done

clean: 
	@for dir in $(SUBDIRS); do \
		if [ -f $$dir/Makefile ]; then \
			$(MAKE) --silent -C $$dir clean || exit 1; \
		fi \
	done
all: test

test: basic

operators: basic
	${MAKE} -B -C operators BUILD_DIR=$(BUILD_DIR) test

basic:
	${MAKE} -B -C basic BUILD_DIR=$(BUILD_DIR) test

clean: 
	${MAKE} -C operators --silent BUILD_DIR=$(BUILD_DIR) clean
	${MAKE} -C basic --silent BUILD_DIR=$(BUILD_DIR) clean

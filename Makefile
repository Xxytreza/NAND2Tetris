.PHONY: test

test: 
	bazel build -c opt //...

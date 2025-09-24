
load("@rules_cc//cc:defs.bzl", "cc_library", "cc_binary", "cc_test")

filegroup(
    name = "verilog_sources",
    srcs = glob([
        "src/**/*.v",
        "src/**/*.vh",
        "src/**/*.sv",
    ]),
    visibility = ["//visibility:public"],
)

cc_library(
    name = "accelerator_lib",
    srcs = [],
    hdrs = [],
    visibility = ["//visibility:public"],
)

cc_test(
    name = "accelerator_test",
    srcs = [],
    deps = [":accelerator_lib"],
)

genrule(
    name = "verilog_test",
    srcs = [":verilog_sources"],
    outs = ["verilog_test.log"],
    cmd = """
        echo "VeriLog files found:" > $@
        for f in $(SRCS); do
            echo "  $$f" >> $@
        done
        echo "Use iverilog or other VeriLog simulator to compile and run" >> $@
    """,
    visibility = ["//visibility:public"],
)

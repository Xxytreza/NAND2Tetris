import subprocess

INSTR_ADD = 0x01
INSTR_MUL = 0x02


def run_cpu(opcode, a, b):
    # Run simulation with plusargs for operands
    result = subprocess.run(
        ["vvp", "./build/cpu_wrapper.vvp", f"+opcode={opcode}", f"+a={a}", f"+b={b}"],
        capture_output=True,
        text=True,
    )
    # Parse stdout to extract result
    for line in result.stdout.splitlines():
        if "Result=" in line:
            return int(line.split("Result=")[1].split(",")[0])
    return None


# Compile Verilog
subprocess.run(["make"], check=True)

print("10 + 20: ", run_cpu(INSTR_ADD, 10, 20))  # Should print 30
print("5 * 7: ", run_cpu(INSTR_MUL, 5, 7))  # Should print 35

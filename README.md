# RISC-V CPU (Learning Project)

This repository contains my personal implementation of a single-cycle RISC-V CPU in SystemVerilog, as part of my self-learning path into RTL design and verification.

## Implemented so far
- Program Counter (PC)
  - Synchronous active-low reset
  - Increment by +4
  - External load for branch/jump
- Self-checking Testbench
  - Reset sequence
  - Increment checks
  - External load check
  - Mid-run reset

## Next steps
- Register File (32x32, x0 hardwired to 0)
- ALU
- Instruction Decode
- Integration into a single-cycle CPU

## Simulation
- Written in SystemVerilog
- Simulated using ModelSim Intel Edition
- Includes `modelsim.do` & `cpu_pkg.sv` scripts for compilation and run


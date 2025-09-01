# RISC-V RV32I — PC & IMEM (Single-Cycle, Learning Project)

This repository documents my learning path into RTL **design & verification** using **SystemVerilog**, focusing (for now) on the **Program Counter (PC)** and **Instruction Memory (IMEM)** of a single-cycle **RV32I** CPU.  

---

## What’s Implemented

### Program Counter (PC)
- **Synchronous, active-low reset** (`rst_ni`).
- **+4 increment** each cycle (RV32 word stride).
- **External load path** for branch/jump targets (muxed vs. `PC+4`).

### Instruction Memory (IMEM)
- ROM that **loads instructions from an external HEX file** at sim time.
- **Safety on invalid addresses** (out-of-range or unaligned): returns a **NOP** (RV32I `ADDI x0, x0, 0`).
- Optional compile-time checks to assert bad addresses during simulation.

---

## Verification (Self-Checking Testbenches)

### PC Testbench
- **Reset sequence**: PC comes up at the defined reset value.
- **Increment checks**: continuous `PC ← PC + 4`.
- **External load check**: branch/jump target overrides `PC+4` as expected.
- **Mid-run reset**: re-enters a known state and resumes correctly.

### IMEM Testbench
- **HEX file load & read **: reads known words from the HEX file.
- **Invalid address handling**: out-of-range / unaligned → **NOP** on `rd_o`.

---

 **ModelSim - Intel FPGA Staeter Edition** (used here).

### Quick Start
```tcl
# The repository includes a 'modelsim.do' script.
# From ModelSim console: do modelsim.do

# RISC-V RV32I — Single-Cycle CPU

Personal learning project for RTL **design & verification** in **SystemVerilog**.  
Currently implemented: full **RV32I Single-Cycle CPU** including **Program Counter (PC)**, **Instruction Memory (IMEM)**, **Control Unit**, **Register File**, **Immediate Generator**, **ALU**, **Data Memory**, and full **CPU Testbench**.

---

## Implemented Blocks

### Program Counter (PC)
- Synchronous, active-low reset (`rst_ni`)
- `PC + 4` on each cycle
- External load path for branch/jump targets (muxed vs. `PC+4`)

### Instruction Memory (IMEM)
- ROM that loads instructions from an external HEX file at simulation time
- Invalid addresses (out-of-range or unaligned) return a **NOP** (`ADDI x0, x0, 0`)
- Optional sim checks for bad addresses

### Control Unit
RV32I decode to CPU control signals.
- **Inputs:** `instr_i[31:0]`, ALU flags: `zero_i`, `lt_i`, `ltu_i`
- **Outputs:**
  - `reg_write_o`, `alu_src_o`, `mem_write_o`, `pc_src_o`
  - `imm_src_o` ∈ `{IMM_I, IMM_S, IMM_B, IMM_U, IMM_J}`
  - `result_src_o` ∈ `{RES_ALU, RES_MEM, RES_PC4}`
  - `alu_ctrl_o` ∈ `{ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_XOR, ALU_SLL, ALU_SRL, ALU_SRA, ALU_SLT, ALU_SLTU}`
  - `load_type_o` ∈ `{LD_LB, LD_LH, LD_LW, LD_LBU, LD_LHU}`
  - `store_type_o` ∈ `{ST_SB, ST_SH, ST_SW}`
- **Coverage:**
  `OP_OP` / `OP_OPIMM` (including SUB/SRA via `instr[30]`)  
  `OP_LOAD` / `OP_STORE` (`funct3` → load/store types)  
  `OP_BRANCH` (BEQ, BNE, BLT, BGE, BLTU, BGEU) via ALU flags  
  `OP_JAL`, `OP_JALR`, `OP_LUI`, `OP_AUIPC`
- **Safe default (unknown opcode):** no register/memory write, no branch; defaults remain  
  (`imm_src_o=IMM_I`, `result_src_o=RES_ALU`, `alu_ctrl_o=ALU_ADD`, `load_type_o=LD_LW`, `store_type_o=ST_SW`)

### Register File (REGFILE)
- 32 × 32-bit registers (`x0..x31`), **x0 hard-wired to zero**
- 2 **combinational** read ports, 1 **synchronous** write port (commit on `posedge clk`)
- Active-low synchronous reset
- Typical read-during-write behavior: pre-commit reads show the old value; immediately after the write clock edge, reads reflect the new value

### Immediate Generator (IMMGEN)
- Decodes `instr_i[31:0]` into a sign-extended immediate according to `imm_src_i`
- Supported formats: **I/S/B/U/J** (RV32I)
- Output: `imm_o[31:0]` (sign-extended as per spec)
- Defensive default: if `imm_src_i` is out of range, `imm_o` falls back to zero

### ALU
- Implements all RV32I arithmetic/logical ops:
  - ADD, SUB
  - AND, OR, XOR
  - SLL, SRL, SRA
  - SLT, SLTU
- Combinational design, one-cycle latency
- Verification included deterministic tests + randomized smoke tests (fixed seed for reproducibility)

### Data Memory (DMEM)
- Word/half/byte read & write
- Same-cycle read-after-write support (forwarded new value)
- Defensive checks for out-of-range accesses
- Simple byte-enable interface

---

## Verification (Self-Checking Testbenches)

### PC TB
- Reset sequence
- Increment (`PC ← PC + 4`)
- External load (branch/jump)
- Mid-run reset

### IMEM TB
- HEX load & readback
- Invalid address handling ⇒ NOP on `rd_o`

### Control TB
- Instruction builders for R/I/LOAD/STORE/BRANCH/JAL/JALR/U using `cpu_pkg.sv` enums/fields
- Tests:
  - R/I ALU ops (including SRLI/SRAI via `instr[30]`)
  - LOAD/STORE type mapping from `funct3`
  - BRANCH **taken & not-taken** for each variant
  - JAL / JALR / LUI / AUIPC
  - **Unknown opcode** ⇒ safe defaults (no side-effects)
- Output: compact, **one-line table row per test** (ALU/LOAD/STORE printed as strings)

### REGFILE TB 
- Reset brings all registers to zero; x0 is immutable
- Basic write/read; write-enable guard (`we=0` does not modify state)
- Back-to-back writes on consecutive cycles
- **Same-cycle read-during-write** check (pre/post commit)
- Mid-run reset
- Table-style console output (one line per check)

### IMMGEN TB 
- Per-format checks (I/S/B/U/J) including edge cases and sign-extension boundaries
- Negative immediates, maximum offsets, and zero immediates
- Self-checking with clear pass/fail messages

### ALU TB 
- Deterministic tests for each opcode
- Edge-case checks (overflow, borrow, shift by max amount)
- Randomized smoke tests with fixed seed
- Console output with per-op summary

### DMEM TB 
- Word/half/byte read/write
- Same-cycle read-after-write behavior
- Out-of-range addresses checked
- Clear pass/fail log

### CPU TB 
- Full integration testbench for the CPU
- Loads HEX into IMEM and executes real instruction sequences
- Monitors **PC, register file, DMEM writes**
- Self-checking features:
  - **x31 as error counter**, incremented via BEQ checks
  - **End-of-program instructions** for clean termination
  - **Watchdog** timer to prevent infinite loops or stalls
  - Stall detection (no progress over cycles)
- Outputs cycle-by-cycle trace, pass/fail status, and final error count

---

## Tools
- Language: **SystemVerilog**
- Simulator: **ModelSim – Intel FPGA Starter Edition**
- Included scripts: `modelsim.do`, `cpu_pkg.sv`

### Quick Start
```tcl
# From ModelSim console:
do modelsim.do

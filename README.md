# RISC-V RV32I — PC, IMEM & CONTROL (Single-Cycle, Learning Project)

Personal learning project for RTL **design & verification** in **SystemVerilog**.  
Currently implemented: **Program Counter (PC)**, **Instruction Memory (IMEM)**, and **Control Unit**.

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
- **Inputs:** `instr_i[31:0]`, flags from ALU: `zero_i`, `lt_i`, `ltu_i`
- **Outputs:**  
  - `reg_write_o`, `alu_src_o`, `mem_write_o`, `pc_src_o`  
  - `imm_src_o` ∈ `{IMM_I, IMM_S, IMM_B, IMM_U, IMM_J}`  
  - `result_src_o` ∈ `{RES_ALU, RES_MEM, RES_PC4}`  
  - `alu_ctrl_o` ∈ `{ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_XOR, ALU_SLL, ALU_SRL, ALU_SRA, ALU_SLT, ALU_SLTU}`  
  - `load_type_o` ∈ `{LD_LB, LD_LH, LD_LW, LD_LBU, LD_LHU}`  
  - `store_type_o` ∈ `{ST_SB, ST_SH, ST_SW}`
- **Coverage:**  
  `OP_OP` / `OP_OPIMM` (including SUB/SRA via `instr[30]`)  
  `OP_LOAD` / `OP_STORE` (`funct3` to load/store types)  
  `OP_BRANCH` (BEQ, BNE, BLT, BGE, BLTU, BGEU) via ALU flags  
  `OP_JAL`, `OP_JALR`, `OP_LUI`, `OP_AUIPC`
- **Safe default (unknown opcode):** no register/memory write, no branch; defaults remain
  (`imm_src_o=IMM_I`, `result_src_o=RES_ALU`, `alu_ctrl_o=ALU_ADD`, `load_type_o=LD_LW`, `store_type_o=ST_SW`)

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

### Control TB (`control_tb.sv`)
- Instruction builders for R/I/LOAD/STORE/BRANCH/JAL/JALR/U using `cpu_pkg.sv` enums/fields
- Tests:
  - R/I ALU ops (including SRLI/SRAI via `instr[30]`)
  - LOAD/STORE type mapping from `funct3`
  - BRANCH **taken & not-taken** for each variant
  - JAL / JALR / LUI / AUIPC
  - **Unknown opcode** ⇒ safe defaults (no side-effects)
- Output: compact, one-line table row per test (ALU/LOAD/STORE printed as strings)

---

## Tools
- Language: **SystemVerilog**
- Simulator: **ModelSim – Intel FPGA Starter Edition**
- Included scripts: `modelsim.do`, `cpu_pkg.sv`

### Quick Start
```tcl
# From ModelSim console:
do modelsim.do

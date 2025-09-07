// * * * CPU Testbench (RV32I) * * * //

`timescale 1ns/1ps
`default_nettype none

module cpu_tb;
  import cpu_pkg::*;

  // DUT inputs
  reg clk_i;
  reg rst_n_i;

  // DUT
  cpu dut(.*);

  // Clock 100 MHz
  initial clk_i = 1'b0;
  always #5 clk_i = ~clk_i;

  // Reset
  initial begin
    rst_n_i = 1'b0;
    repeat (10) @(posedge clk_i);
    rst_n_i = 1'b1;
  end

  // Watchdog / progress
  int unsigned cycle_counter                = 0;
  localparam int unsigned MAX_CYCLES        = 1_000_000;
  localparam int unsigned NO_PROGRESS_LIMIT = 256;
  bit test_done                             = 1'b0;

  // PC progress tracking
  logic [WIDTH-1:0] last_pc_value  = '0;
  int unsigned no_progress_counter = 0;

  // Current instruction
  logic [31:0] curr_instr;

  // Halt instruction (ECALL/EBREAK)
  function automatic bit halt_instruction(input logic [31:0] instr);
    // ECALL = 0x00000073, EBREAK = 0x00100073
    return (instr == 32'h0000_0073) || (instr == 32'h0010_0073);
  endfunction

  // Decode fields
  logic [4:0] rd, rs1, rs2;

  // Register values
  logic [31:0] rs1_val, rs2_val;

  // ALU op to string 
  function automatic string decode_alu_op(alu_op op);
    unique case (op)
      ALU_ADD:   return "ADD";
      ALU_SUB:   return "SUB";
      ALU_AND:   return "AND";
      ALU_OR:    return "OR";
      ALU_XOR:   return "XOR";
      ALU_SLT:   return "SLT";
      ALU_SLTU:  return "SLTU";
      ALU_SLL:   return "SLL";
      ALU_SRL:   return "SRL";
      ALU_SRA:   return "SRA";
      default:   return "UNKNOWN";
    endcase
  endfunction

  // Mnemonic using OP/F3/F7 
  function automatic string decode_mnemonic(input logic [31:0] instr);
    logic [6:0] opc = instr[6:0];
    logic [2:0] f3  = instr[14:12];
    logic [6:0] f7  = instr[31:25];

    if (instr == 32'h0010_0073) return "EBREAK";
    if (instr == 32'h0000_0073) return "ECALL";

    if (opc == OP_OP) begin
      unique case ({f7,f3})
        {7'b0000000,F3_ADD_SUB}: return "ADD";
        {7'b0100000,F3_ADD_SUB}: return "SUB";
        {7'b0000000,F3_AND}:     return "AND";
        {7'b0000000,F3_OR}:      return "OR";
        {7'b0000000,F3_XOR}:     return "XOR";
        {7'b0000000,F3_SLT}:     return "SLT";
        {7'b0000000,F3_SLTU}:    return "SLTU";
        {7'b0000000,F3_SLL}:     return "SLL";
        {7'b0000000,F3_SRL_SRA}: return "SRL";
        {7'b0100000,F3_SRL_SRA}: return "SRA";
        default:                 return "R-UNK";
      endcase
    end

    if (opc == OP_OPIMM) begin
      unique case (f3)
        F3_ADD_SUB: return "ADDI";
        F3_AND:     return "ANDI";
        F3_OR:      return "ORI";
        F3_XOR:     return "XORI";
        F3_SLT:     return "SLTI";
        F3_SLTU:    return "SLTIU";
        F3_SLL:     return "SLLI";
        F3_SRL_SRA: return (f7==7'b0100000) ? "SRAI" : "SRLI";
        default:    return "I-UNK";
      endcase
    end

    if (opc == OP_LOAD)  return (f3==F3_LW) ? "LW" : "L?";
    if (opc == OP_STORE) return (f3==F3_SW) ? "SW" : "S?";

    if (opc == OP_BRANCH) begin
      unique case (f3)
        F3_BEQ:  return "BEQ";
        F3_BNE:  return "BNE";
        F3_BLT:  return "BLT";
        F3_BGE:  return "BGE";
        F3_BLTU: return "BLTU";
        F3_BGEU: return "BGEU";
        default: return "B?";
      endcase
    end

    if (opc == OP_JAL)   return "JAL";
    if (opc == OP_JALR)  return "JALR";
    if (opc == OP_LUI)   return "LUI";
    if (opc == OP_AUIPC) return "AUIPC";
    return "UNK";
  endfunction

  // Choose immediate to print (I/S/B/J/U or shamt)
  function automatic logic [31:0] select_imm_for_print(input logic [31:0] instr);
    logic [6:0]  opc   = instr[6:0];
    logic [2:0]  f3    = instr[14:12];
    logic [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    logic [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    logic [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    logic [31:0] imm_u = {instr[31:12], 12'b0};
    logic [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
    logic [31:0] shamt = {27'b0, instr[24:20]};

    if (opc == OP_LOAD)         return imm_i;
    if (opc == OP_STORE)        return imm_s;
    if (opc == OP_BRANCH)       return imm_b;
    if (opc == OP_JAL)          return imm_j;
    if (opc == OP_LUI ||
        opc == OP_AUIPC)        return imm_u;
    if (opc == OP_OPIMM) begin
      if ((f3==F3_SLL) || (f3==F3_SRL_SRA)) return shamt;
      else return imm_i;
    end
    return 32'h0;
  endfunction

  // Memory tag (effective address for LW/SW)
  function automatic string mem_tag(input logic [31:0] instr, input logic [31:0] rs1_val);
    logic [6:0]  opc   = instr[6:0];
    logic [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    logic [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    if (opc == OP_LOAD)  return $sformatf("LW@%08h", rs1_val + imm_i);
    if (opc == OP_STORE) return $sformatf("SW@%08h", rs1_val + imm_s);
    return "-";
  endfunction

  // Fixed-width helpers for aligned printing
  function automatic string mem_tag_fixed(input logic [31:0] instr, input logic [31:0] rs1_val);
    string t = mem_tag(instr, rs1_val);
    return $sformatf("%-16s", t);
  endfunction
  string mnem_str, alu_str, mem_str;  // fixed-width fields

  // Header line (printed once after reset release)
  initial begin
    @(posedge rst_n_i);
    $display("\n==== Start Simulation ====");
    $display("\nCYCLE     | PC       | INSTR    | OP      |  rd  rs1  rs2 | rs1_val   rs2_val  | IMM       | ALU   | MEM");
    $display("----------+----------+----------+---------+---------------+--------------------+-----------+-------+------------");
  end

  // Per-cycle trace
  always_ff @(posedge clk_i) if (rst_n_i) begin
    cycle_counter++;

    // Fetch current instruction
    curr_instr = dut.u_imem.rom[dut.pc_q[WIDTH-1:2]];
    if ($isunknown(curr_instr)) $error("X/Z instruction at PC=%08h", dut.pc_q);

    // Decode fields
    rd  = curr_instr[11:7];
    rs1 = curr_instr[19:15];
    rs2 = curr_instr[24:20];

    // Read source register values
    rs1_val = (rs1 == 0) ? 32'b0 : dut.u_regfile.regs[rs1];
    rs2_val = (rs2 == 0) ? 32'b0 : dut.u_regfile.regs[rs2];

    // Fixed-width strings
    mnem_str = $sformatf("%-7s", decode_mnemonic(curr_instr));
    alu_str  = $sformatf("%-5s", decode_alu_op(dut.alu_ctrl));
    mem_str  = mem_tag_fixed(curr_instr, rs1_val);

    // One-line aligned trace
    $display(" %8d | %08h | %08h | %s | %3d %4d %4d | %08h  %08h | %08h  | %s | %s",
             cycle_counter, dut.pc_q, curr_instr,
             mnem_str, rd, rs1, rs2, rs1_val, rs2_val,
             select_imm_for_print(curr_instr),
             alu_str, mem_str);

    // Halt on ECALL/EBREAK
    if (halt_instruction(curr_instr)) begin
      test_done <= 1'b1;
      $display("       HALT @%0t (instr=%08h, pc=%08h)", $time, curr_instr, dut.pc_q);
    end

    // No-progress detector
    if (dut.pc_q == last_pc_value) begin
      no_progress_counter++;
      if (no_progress_counter >= NO_PROGRESS_LIMIT) begin
        test_done <= 1'b1;
        $display("No-progress halt @%0t (PC stuck at %08h for %0d cycles)",
                 $time, dut.pc_q, NO_PROGRESS_LIMIT);
      end
    end else begin
      no_progress_counter = 0;
      last_pc_value       = dut.pc_q;
    end

    // Watchdog
    if (cycle_counter >= MAX_CYCLES)
      $fatal(1, "Watchdog timeout after %0d cycles", MAX_CYCLES);
  end

  // Show DMEM writes
  always_ff @(posedge clk_i) if (rst_n_i) begin
    if (dut.u_dmem.we_i) begin
      $display("       DMEM write: addr=%08h data=%08h wem=%b",
               dut.u_dmem.addr_i, dut.u_dmem.wd_i, dut.u_dmem.wem_i);
    end
  end

  // Show DMEM read data on LOAD cycles
  always_ff @(posedge clk_i) if (rst_n_i) begin
    if (curr_instr[6:0] == OP_LOAD) begin
     $display("       DMEM-RD: ea=%08h data=%08h  we=%b wem=%b",
               rs1_val + {{20{curr_instr[31]}}, curr_instr[31:20]},
               dut.u_dmem.rd_o, dut.u_dmem.we_i, dut.u_dmem.wem_i);
    end
  end


  // End of test
  initial begin
    @(posedge rst_n_i);
    wait (test_done);

    $display("\n===== CPU TB DONE =====");
    // Software verdict: x31 is error counter (0 = PASS)
    if (dut.u_regfile.regs[31] == 0) $display("RESULT: PASS");
    else                             $display("RESULT: FAIL (errors=%0d)", dut.u_regfile.regs[31]);
    $finish;
  end

endmodule

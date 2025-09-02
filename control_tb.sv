// * * * Control Unit Testbench  * * * // 

`timescale 1ns/1ps
`default_nettype none

module control_tb;
  import cpu_pkg::*;

  // Inputs
  reg [31:0] instr_i;
  reg        zero_i;
  reg        lt_i;
  reg        ltu_i;
  // Outputs
  logic      reg_write_o;
  logic      alu_src_o;
  logic      mem_write_o;
  logic      pc_src_o;
  imm_src    imm_src_o;
  result_src result_src_o;
  alu_op     alu_ctrl_o;
  load_type  load_type_o;
  store_type store_type_o;
  // DUT
  control dut (.*);

  integer tb_error = 0;

  // R-type funct7 encodings
  localparam logic [6:0] F7_ADD_SRL = 7'b0000000;
  localparam logic [6:0] F7_SUB_SRA = 7'b0100000;

  // JALR funct3
  localparam logic [2:0] F3_JALR = 3'b000;

  // Immediates
  localparam logic [11:0] IMM12_ADDI   = 12'h001;
  localparam logic [11:0] IMM12_LOGIC = 12'h0F0;
  localparam logic [11:0] IMM12_LOAD   = 12'h004;
  localparam logic [11:0] IMM12_STORE  = 12'h008;

  // Branch/jump offsets (LSB=0)
  localparam logic [12:0] BR_OFF_2 = 13'h0002;
  localparam logic [20:1] J_OFF_2  = 21'h00002;

  // Shifts
  localparam logic [4:0]  SHAMT_1  = 5'd1;
  localparam bit          F7I_SRLI = 1'b0; // imm[30] = 0
  localparam bit          F7I_SRAI = 1'b1; // imm[30] = 1

  // U-type immediate sample
  localparam logic [19:0] U_IMM_00010 = 20'h00010;

  // --------------------------------------------------------------------
  // Instruction builders
  // --------------------------------------------------------------------

  // R-type
  function automatic logic [31:0] build_r(input logic [6:0] f7, input logic [2:0] f3);
    logic [31:0] instr = '0;
    instr [31:25] = f7;
    instr [14:12] = f3;
    instr [6:0]   = OP_OP;
    return instr;
  endfunction

  // I-type (no shift)
  function automatic logic [31:0] build_i(input logic [2:0] f3, input logic [11:0] imm12);
    logic [31:0] instr = '0;
    instr [31:20] = imm12;
    instr [14:12] = f3;
    instr [6:0]   = OP_OPIMM;
    return instr;
  endfunction

  // I-type shifts: imm[11:5] = {0, bit30, 00000}, imm[4:0] = shamt
  function automatic logic [31:0] build_i_shamt(input logic [2:0] f3, input bit bit30, input logic [4:0] shamt);
    logic [31:0] instr = '0;
    instr [31:25] = {1'b0, bit30, 5'b00000};
    instr [24:20] = shamt;
    instr [14:12] = f3;       
    instr [6:0]   = OP_OPIMM;
    return instr;
  endfunction

  function automatic logic [31:0] build_load(input logic [2:0] f3, input logic [11:0] imm12);
    logic [31:0] instr = '0;
    instr [31:20] = imm12;
    instr [14:12] = f3;     
    instr [6:0]   = OP_LOAD;
    return instr;
  endfunction

  function automatic logic [31:0] build_store(input logic [2:0] f3, input logic [11:0] imm12);
    logic [31:0] instr = '0;
    instr [31:25] = imm12[11:5];
    instr [11:7]  = imm12[4:0];
    instr [14:12] = f3;      
    instr [6:0]   = OP_STORE;
    return instr;
  endfunction

  function automatic logic [31:0] build_u(input logic [6:0] opcode, input logic [19:0] imm20);
    logic [31:0] instr = '0;
    instr [31:12] = imm20;
    instr [6:0]   = opcode; // OP_LUI / OP_AUIPC
    return instr;
  endfunction

  function automatic logic [31:0] build_branch(input logic [2:0] f3, input logic [12:0] imm13 /*LSB=0*/);
    logic [31:0] instr = '0;
    instr [31]    = imm13[12];
    instr [30:25] = imm13[10:5];
    instr [11:8]  = imm13[4:1];
    instr [7]     = imm13[11];
    instr [14:12] = f3;       
    instr [6:0]   = OP_BRANCH;
    return instr;
  endfunction

  function automatic logic [31:0] build_jal(input logic [20:1] imm /*LSB=0*/);
    logic [31:0] instr = '0;
    instr [31]    = imm[20];
    instr [19:12] = imm[19:12];
    instr [20]    = imm[11];
    instr [30:21] = imm[10:1];
    instr [6:0]   = OP_JAL;
    return instr;
  endfunction

  function automatic logic [31:0] build_jalr(input logic [11:0] imm12);
    logic [31:0] instr = '0;
    instr [31:20] = imm12;
    instr [14:12] = F3_JALR; // fixed funct3
    instr [6:0]   = OP_JALR;
    return instr;
  endfunction

  // Unknown / illegal opcode to hit the default case in control
  localparam logic [6:0] OP_ILL = 7'b1111111;

  // --------------------------------------------------------------------
  // Print helpers
  // --------------------------------------------------------------------
  
  function automatic string alu_to_str(alu_op v);
    case (v)
      ALU_ADD : return "ALU_ADD";
      ALU_SUB : return "ALU_SUB";
      ALU_AND : return "ALU_AND";
      ALU_OR  : return "ALU_OR";
      ALU_XOR : return "ALU_XOR";
      ALU_SLL : return "ALU_SLL";
      ALU_SRL : return "ALU_SRL";
      ALU_SRA : return "ALU_SRA";
      ALU_SLT : return "ALU_SLT";
      ALU_SLTU: return "ALU_SLTU";
      default : return "ALU_???";
    endcase
  endfunction

function automatic string load_to_str(load_type v);
  case (v)
    LD_LB :  return "LD_LB";
    LD_LH :  return "LD_LH";
    LD_LW :  return "LD_LW";
    LD_LBU:  return "LD_LBU";
    LD_LHU:  return "LD_LHU";
    default: return "LD_???";
  endcase
endfunction

function automatic string store_to_str(store_type v);
  case (v)
    ST_SB :  return "ST_SB";
    ST_SH :  return "ST_SH";
    ST_SW :  return "ST_SW";
    default: return "ST_???";
  endcase
endfunction


  // --------------------------------------------------------------------
  // Self-Check
  // --------------------------------------------------------------------
  task automatic check_control(
    string     name,
    bit        exp_reg_write,
    imm_src    exp_imm_src,
    bit        exp_alu_src,
    bit        exp_mem_write,
    result_src exp_result_src,
    bit        exp_pc_src,
    alu_op     exp_alu_ctrl,
    load_type  exp_load_type,
    store_type exp_store_type
  );
    #1;

    if (reg_write_o !== exp_reg_write) begin
      tb_error++;
      $error("FAIL %-16s RegWrite got=%0b exp=%0b", name, reg_write_o, exp_reg_write);
    end
    if (imm_src_o !== exp_imm_src) begin
      tb_error++;
      $error("FAIL %-16s ImmSrc   got=%0d exp=%0d", name, imm_src_o, exp_imm_src);
    end
    if (alu_src_o !== exp_alu_src) begin
      tb_error++;
      $error("FAIL %-16s ALUSrc  got=%0b exp=%0b", name, alu_src_o, exp_alu_src);
    end
    if (mem_write_o !== exp_mem_write) begin
      tb_error++;
      $error("FAIL %-16s MemWrite got=%0b exp=%0b", name, mem_write_o, exp_mem_write);
    end
    if (result_src_o !== exp_result_src) begin
      tb_error++;
      $error("FAIL %-16s Result  got=%0d exp=%0d", name, result_src_o, exp_result_src);
    end
    if (pc_src_o !== exp_pc_src) begin
      tb_error++;
      $error("FAIL %-16s PCSrc   got=%0b exp=%0b", name, pc_src_o, exp_pc_src);
    end
    if (alu_ctrl_o !== exp_alu_ctrl) begin
      tb_error++;
      $error("FAIL %-16s ALUCtrl got=%s(%0d) exp=%s(%0d)",
             name, alu_to_str(alu_ctrl_o), alu_ctrl_o,
                   alu_to_str(exp_alu_ctrl), exp_alu_ctrl);
    end
    if (load_type_o !== exp_load_type) begin
      tb_error++;
      $error("FAIL %-16s LoadTyp got=%s(%0d) exp=%s(%0d)",name, 
             load_to_str(load_type_o), load_type_o,
             load_to_str(exp_load_type), exp_load_type);
    end
    if (store_type_o !== exp_store_type) begin
      tb_error++;
      $error("FAIL %-16s StoreTy got=%s(%0d) exp=%s(%0d)", name, 
             store_to_str(store_type_o), store_type_o,
             store_to_str(exp_store_type), exp_store_type);
    end

    if ( (reg_write_o  === exp_reg_write)  &&
         (imm_src_o    === exp_imm_src)    &&
         (alu_src_o    === exp_alu_src)    &&
         (mem_write_o  === exp_mem_write)  &&
         (result_src_o === exp_result_src) &&
         (pc_src_o     === exp_pc_src)     &&
         (alu_ctrl_o   === exp_alu_ctrl)   &&
         (load_type_o  === exp_load_type)  &&
         (store_type_o === exp_store_type) ) begin
        // print header once
        static bit header_shown = 1'b0;
        if (!header_shown) begin
          $display("");
          $display("%-14s | %-34s | %-8s | %-6s | %-5s",
                   "Test", "Control", "ALU", "Load", "Store");
          $display("---------------+------------------------------------+----------+--------+--------------");
          header_shown = 1'b1;
        end
        // one compact row per test
        $display("%-14s | RW=%0b  IS=%0d  AS=%0b  MW=%0b  RS=%0d  PC=%0b | %-8s | %-6s | %-5s",
                 name, reg_write_o, imm_src_o, alu_src_o, mem_write_o, result_src_o, pc_src_o,
                alu_to_str(alu_ctrl_o), load_to_str(load_type_o), store_to_str(store_type_o));
      end
  endtask

  task automatic check_basic(string name,
                             bit rw, imm_src imm, bit as, bit mw,
                             result_src res, bit pcs, alu_op ac);
    check_control(name, rw, imm, as, mw, res, pcs, ac, LD_LW, ST_SW);
  endtask

  task automatic check_load(string name, load_type ld);
    check_control(name, 1'b1, IMM_I, 1'b1, 1'b0, RES_MEM, 1'b0, ALU_ADD, ld, ST_SW);
  endtask

  task automatic check_store(string name, store_type st);
    check_control(name, 1'b0, IMM_S, 1'b1, 1'b1, RES_ALU, 1'b0, ALU_ADD, LD_LW, st);
  endtask

  task automatic set_branch_flags(bit z, bit lt, bit ltu);
    begin
      zero_i = z;
      lt_i   = lt;
      ltu_i  = ltu;
    end
  endtask

  // --------------------------------------------------------------------
  // Tests 
  // --------------------------------------------------------------------
  initial begin
    $display("\n==== Control Unit TB START ====\n");

    instr_i = '0;
    set_branch_flags(1'b0, 1'b0, 1'b0);
    #1;

    // R-type
    instr_i = build_r(F7_ADD_SRL, F3_ADD_SUB);
    check_basic("R-ADD", 1, IMM_I, 0, 0, RES_ALU, 0, ALU_ADD);

    instr_i = build_r(F7_SUB_SRA, F3_ADD_SUB);
    check_basic("R-SUB", 1, IMM_I, 0, 0, RES_ALU, 0, ALU_SUB);

    instr_i = build_r(F7_ADD_SRL, F3_AND);
    check_basic("R-AND", 1, IMM_I, 0, 0, RES_ALU, 0, ALU_AND);

    instr_i = build_r(F7_ADD_SRL, F3_OR);
    check_basic("R-OR ", 1, IMM_I, 0, 0, RES_ALU, 0, ALU_OR);

    instr_i = build_r(F7_ADD_SRL, F3_XOR);
    check_basic("R-XOR", 1, IMM_I, 0, 0, RES_ALU, 0, ALU_XOR);

    instr_i = build_r(F7_ADD_SRL, F3_SLT);
    check_basic("R-SLT", 1, IMM_I, 0, 0, RES_ALU, 0, ALU_SLT);

    instr_i = build_r(F7_ADD_SRL, F3_SLTU);
    check_basic("R-SLTU", 1, IMM_I, 0, 0, RES_ALU, 0, ALU_SLTU);

    instr_i = build_r(F7_ADD_SRL, F3_SLL);
    check_basic("R-SLL", 1, IMM_I, 0, 0, RES_ALU, 0, ALU_SLL);

    instr_i = build_r(F7_ADD_SRL, F3_SRL_SRA);
    check_basic("R-SRL", 1, IMM_I, 0, 0, RES_ALU, 0, ALU_SRL);

    instr_i = build_r(F7_SUB_SRA, F3_SRL_SRA);
    check_basic("R-SRA", 1, IMM_I, 0, 0, RES_ALU, 0, ALU_SRA);

    // I-type
    instr_i = build_i(F3_ADD_SUB, IMM12_ADDI);
    check_basic("I-ADDI", 1, IMM_I, 1, 0, RES_ALU, 0, ALU_ADD);

    instr_i = build_i(F3_AND, IMM12_LOGIC);
    check_basic("I-ANDI", 1, IMM_I, 1, 0, RES_ALU, 0, ALU_AND);

    instr_i = build_i(F3_OR, IMM12_LOGIC);
    check_basic("I-ORI ", 1, IMM_I, 1, 0, RES_ALU, 0, ALU_OR);

    instr_i = build_i(F3_XOR, IMM12_LOGIC);
    check_basic("I-XORI", 1, IMM_I, 1, 0, RES_ALU, 0, ALU_XOR);

    instr_i = build_i(F3_SLT, IMM12_ADDI);
    check_basic("I-SLTI", 1, IMM_I, 1, 0, RES_ALU, 0, ALU_SLT);

    instr_i = build_i(F3_SLTU, IMM12_ADDI);
    check_basic("I-SLTIU", 1, IMM_I, 1, 0, RES_ALU, 0, ALU_SLTU);

    instr_i = build_i_shamt(F3_SLL,      F7I_SRLI, SHAMT_1);
    check_basic("I-SLLI", 1, IMM_I, 1, 0, RES_ALU, 0, ALU_SLL);

    instr_i = build_i_shamt(F3_SRL_SRA,  F7I_SRLI, SHAMT_1);
    check_basic("I-SRLI", 1, IMM_I, 1, 0, RES_ALU, 0, ALU_SRL);

    instr_i = build_i_shamt(F3_SRL_SRA,  F7I_SRAI, SHAMT_1);
    check_basic("I-SRAI", 1, IMM_I, 1, 0, RES_ALU, 0, ALU_SRA);

    // LOAD
    instr_i = build_load(F3_LB,  IMM12_LOAD);
    check_load("LOAD-LB",  LD_LB);

    instr_i = build_load(F3_LH,  IMM12_LOAD);
    check_load("LOAD-LH",  LD_LH);

    instr_i = build_load(F3_LW,  IMM12_LOAD);
    check_load("LOAD-LW",  LD_LW);

    instr_i = build_load(F3_LBU, IMM12_LOAD);
    check_load("LOAD-LBU", LD_LBU);

    instr_i = build_load(F3_LHU, IMM12_LOAD);
    check_load("LOAD-LHU", LD_LHU);

    // STORE
    instr_i = build_store(F3_SB, IMM12_STORE);
    check_store("STORE-BYTE", ST_SB);

    instr_i = build_store(F3_SH, IMM12_STORE);
    check_store("STORE-HALF", ST_SH);

    instr_i = build_store(F3_SW, IMM12_STORE);
    check_store("STORE-WORD", ST_SW);

    // BRANCH 
    instr_i = build_branch(F3_BEQ, BR_OFF_2);
    set_branch_flags(1'b1, 1'b0, 1'b0);
    check_basic("BEQ-taken", 0, IMM_B, 0, 0, RES_ALU, 1, ALU_ADD);

    instr_i = build_branch(F3_BEQ, BR_OFF_2);
    set_branch_flags(1'b0, 1'b0, 1'b0);
    check_basic("BEQ-Not taken", 0, IMM_B, 0, 0, RES_ALU, 0, ALU_ADD);

    instr_i = build_branch(F3_BNE, BR_OFF_2);
    set_branch_flags(1'b0, 1'b0, 1'b0);
    check_basic("BNE-taken", 0, IMM_B, 0, 0, RES_ALU, 1, ALU_ADD);

    instr_i = build_branch(F3_BNE, BR_OFF_2);
    set_branch_flags(1'b1, 1'b0, 1'b0);
    check_basic("BNE-Not taken", 0, IMM_B, 0, 0, RES_ALU, 0, ALU_ADD);

    instr_i = build_branch(F3_BLT, BR_OFF_2);
    set_branch_flags(1'b0, 1'b1, 1'b0);
    check_basic("BLT-taken", 0, IMM_B, 0, 0, RES_ALU, 1, ALU_ADD);

    instr_i = build_branch(F3_BLT, BR_OFF_2);
    set_branch_flags(1'b0, 1'b0, 1'b0);
    check_basic("BLT-Not taken", 0, IMM_B, 0, 0, RES_ALU, 0, ALU_ADD);

    instr_i = build_branch(F3_BGE, BR_OFF_2);
    set_branch_flags(1'b0, 1'b0, 1'b0);
    check_basic("BGE-taken", 0, IMM_B, 0, 0, RES_ALU, 1, ALU_ADD);

    instr_i = build_branch(F3_BGE, BR_OFF_2);
    set_branch_flags(1'b0, 1'b1, 1'b0);
    check_basic("BGE-Not taken", 0, IMM_B, 0, 0, RES_ALU, 0, ALU_ADD);

    instr_i = build_branch(F3_BLTU, BR_OFF_2);
    set_branch_flags(1'b0, 1'b0, 1'b1);
    check_basic("BLTU-taken", 0, IMM_B, 0, 0, RES_ALU, 1, ALU_ADD);

    instr_i = build_branch(F3_BLTU, BR_OFF_2);
    set_branch_flags(1'b0, 1'b0, 1'b0);
    check_basic("BLTU-Not taken", 0, IMM_B, 0, 0, RES_ALU, 0, ALU_ADD);

    instr_i = build_branch(F3_BGEU, BR_OFF_2);
    set_branch_flags(1'b0, 1'b0, 1'b0);
    check_basic("BGEU-taken", 0, IMM_B, 0, 0, RES_ALU, 1, ALU_ADD);

    instr_i = build_branch(F3_BGEU, BR_OFF_2);
    set_branch_flags(1'b0, 1'b0, 1'b1);
    check_basic("BGEU-Not taken", 0, IMM_B, 0, 0, RES_ALU, 0, ALU_ADD);

    // JUMP
    instr_i = build_jal(J_OFF_2);
    check_basic("JAL    ", 1, IMM_J, 0, 0, RES_PC4, 1, ALU_ADD);

    instr_i = build_jalr(IMM12_LOAD);
    check_basic("JALR   ", 1, IMM_I, 1, 0, RES_PC4, 1, ALU_ADD);

    // U-type
    instr_i = build_u(OP_LUI,   U_IMM_00010);
    check_basic("LUI    ", 1, IMM_U, 1, 0, RES_ALU, 0, ALU_ADD);

    instr_i = build_u(OP_AUIPC, U_IMM_00010);
    check_basic("AUIPC  ", 1, IMM_U, 1, 0, RES_ALU, 0, ALU_ADD);

    // Unknown opcode → expect safe defaults (no reg/mem write, no branch)
    instr_i = '0;
    instr_i[6:0] = OP_ILL;        // only opcode field set; rest zeros
    set_branch_flags(1'b1, 1'b1, 1'b1); // flags shouldn't affect default
    check_basic("Illegal-OP  ", 0, IMM_I, 0, 0, RES_ALU, 0, ALU_ADD);

    $display("\n===== Control Unit TB DONE =====\n");
    $display("* SUMMARY * Error: %0d", tb_error);
    if (tb_error == 0) begin
      $display("RESULT: PASS");
    end else begin
      $display("RESULT: FAIL");
    end
    $finish;
  end
endmodule

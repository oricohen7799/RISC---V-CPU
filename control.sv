// * * * Control Unit * * * //

`timescale 1ns/1ps
`default_nettype none

module control
  import cpu_pkg::*;
(
  input  wire [31:0]   instr_i,
  input  wire          zero_i,
  input  wire          lt_i,
  input  wire          ltu_i,

  output logic         reg_write_o,
  output imm_src       imm_src_o,
  output logic         alu_src_o,
  output logic         mem_write_o,
  output result_src    result_src_o,
  output logic         pc_src_o,
  output alu_op        alu_ctrl_o,
  output load_type     load_type_o,
  output store_type    store_type_o
);

  // Decoded fields
  logic [6:0] op;
  logic [2:0] f3;
  logic       bit30;

  assign op    = instr_i[6:0];
  assign f3    = instr_i[14:12];
  assign bit30 = instr_i[30]; // ADD/SUB and SRL/SRA selector

  always_comb begin
    // Defaults
    reg_write_o   = 1'b0;
    imm_src_o     = IMM_I;
    alu_src_o     = 1'b0;
    mem_write_o   = 1'b0;
    result_src_o  = RES_ALU;
    pc_src_o      = 1'b0;
    alu_ctrl_o    = ALU_ADD;
    load_type_o   = LD_LW;
    store_type_o  = ST_SW;

    unique case (op)

      // R-type
      OP_OP: begin
        reg_write_o  = 1'b1;
        result_src_o = RES_ALU;
        unique case (f3)
          F3_ADD_SUB : alu_ctrl_o = (bit30 ? ALU_SUB : ALU_ADD);
          F3_AND     : alu_ctrl_o = ALU_AND;
          F3_OR      : alu_ctrl_o = ALU_OR;
          F3_XOR     : alu_ctrl_o = ALU_XOR;
          F3_SLT     : alu_ctrl_o = ALU_SLT;
          F3_SLTU    : alu_ctrl_o = ALU_SLTU;
          F3_SLL     : alu_ctrl_o = ALU_SLL;
          F3_SRL_SRA : alu_ctrl_o = (bit30 ? ALU_SRA : ALU_SRL);
          default    : /* keep default */;
        endcase
      end

      // I-type
      OP_OPIMM: begin
        reg_write_o  = 1'b1;
        alu_src_o    = 1'b1;   // select immediate
        imm_src_o    = IMM_I;
        result_src_o = RES_ALU;
        unique case (f3)
          F3_ADD_SUB : alu_ctrl_o = ALU_ADD;
          F3_AND     : alu_ctrl_o = ALU_AND;
          F3_OR      : alu_ctrl_o = ALU_OR;
          F3_XOR     : alu_ctrl_o = ALU_XOR;
          F3_SLT     : alu_ctrl_o = ALU_SLT;
          F3_SLTU    : alu_ctrl_o = ALU_SLTU;
          F3_SLL     : alu_ctrl_o = ALU_SLL;
          F3_SRL_SRA : alu_ctrl_o = (bit30 ? ALU_SRA : ALU_SRL);
          default    : /* keep default */;
        endcase
      end

      // LOAD
      OP_LOAD: begin
        reg_write_o   = 1'b1;  // write loaded data
        alu_src_o     = 1'b1;  // base + imm
        imm_src_o     = IMM_I;
        result_src_o  = RES_MEM;
        alu_ctrl_o    = ALU_ADD; // address = rs1 + imm
        unique case (f3)
          F3_LB  : load_type_o = LD_LB;
          F3_LH  : load_type_o = LD_LH;
          F3_LW  : load_type_o = LD_LW;
          F3_LBU : load_type_o = LD_LBU;
          F3_LHU : load_type_o = LD_LHU;
          default: load_type_o = LD_LW;
        endcase
      end

      // STORE
      OP_STORE: begin
        mem_write_o  = 1'b1;
        alu_src_o    = 1'b1;  // base + imm
        imm_src_o    = IMM_S;
        alu_ctrl_o   = ALU_ADD; // address = rs1 + imm
        unique case (f3)
          F3_SB  : store_type_o = ST_SB;
          F3_SH  : store_type_o = ST_SH;
          F3_SW  : store_type_o = ST_SW;
          default: store_type_o = ST_SW;
        endcase
      end

      // BRANCH
      OP_BRANCH: begin
        imm_src_o  = IMM_B;
        unique case (f3)
          F3_BEQ  : pc_src_o =  zero_i;
          F3_BNE  : pc_src_o = ~zero_i;
          F3_BLT  : pc_src_o =  lt_i;
          F3_BGE  : pc_src_o = ~lt_i;
          F3_BLTU : pc_src_o =  ltu_i;
          F3_BGEU : pc_src_o = ~ltu_i;
          default : pc_src_o = 1'b0;
        endcase
      end

      // JUMP
      OP_JAL: begin
        reg_write_o  = 1'b1;   // rd <- PC+4
        result_src_o = RES_PC4;
        pc_src_o     = 1'b1;   // PC <- PC + imm (J)
        imm_src_o    = IMM_J;
      end
      OP_JALR: begin
        reg_write_o  = 1'b1;   // rd <- PC+4
        result_src_o = RES_PC4;
        pc_src_o     = 1'b1;   // PC <- rs1 + imm 
        alu_src_o    = 1'b1;
        imm_src_o    = IMM_I;
        alu_ctrl_o   = ALU_ADD;
      end

      // LUI / AUIPC
      OP_LUI: begin
        reg_write_o  = 1'b1;   // rd <- immU
        result_src_o = RES_ALU;
        imm_src_o    = IMM_U;
        alu_src_o    = 1'b1;  
        alu_ctrl_o   = ALU_ADD;
      end
      OP_AUIPC: begin
        reg_write_o  = 1'b1;   // rd <- PC + immU
        result_src_o = RES_ALU;
        imm_src_o    = IMM_U;
        alu_src_o    = 1'b1;  
        alu_ctrl_o   = ALU_ADD;
      end

      default: /* keep defaults */ ;
    endcase
  end
endmodule

`timescale 1ns/1ps
`default_nettype none

package cpu_pkg;

// CPU word width
parameter int WIDTH = 32;

// Reset address for the pc
parameter logic [WIDTH-1:0] RESET_PC_ADDR = '0;

// ALU ops
typedef enum logic [3:0] {
ALU_ADD  = 4'd0,  // Addition
ALU_SUB  = 4'd1,  // Subtraction
ALU_AND  = 4'd2,  // Bitwise AND
ALU_OR   = 4'd3,  // Bitwise OR
ALU_XOR  = 4'd4,  // Bitwise XOR
ALU_SLL  = 4'd5,  // Logical left shift
ALU_SRL  = 4'd6,  // Logical right shift
ALU_SRA  = 4'd7,  // Arithmetic right shift
ALU_SLT  = 4'd8,  // Set if less than (signed)
ALU_SLTU = 4'd9   // Set if less than (unsigned)
} alu_op;

// Shift amount width
localparam int SHAMT_W = $clog2(WIDTH);

// ROM / Imem
localparam int IMEM_DEPTH = 1024;
localparam logic [31:0] INSN_NOP = 32'h0000_0013;  // addi x0, x0, 0

// RAM / Data-Memory
localparam int DMEM_DEPTH = 1024;

// Opcodes
localparam logic [6:0] OP_LUI    = 7'b0110111;
localparam logic [6:0] OP_AUIPC  = 7'b0010111;
localparam logic [6:0] OP_JAL    = 7'b1101111;
localparam logic [6:0] OP_JALR   = 7'b1100111;
localparam logic [6:0] OP_BRANCH = 7'b1100011;
localparam logic [6:0] OP_LOAD   = 7'b0000011;
localparam logic [6:0] OP_STORE  = 7'b0100011;
localparam logic [6:0] OP_OPIMM  = 7'b0010011;
localparam logic [6:0] OP_OP     = 7'b0110011;

// fanct3 for OP / OP_IMM
localparam logic [2:0] F3_ADD_SUB = 3'b000;
localparam logic [2:0] F3_SLL     = 3'b001;
localparam logic [2:0] F3_SLT     = 3'b010;
localparam logic [2:0] F3_SLTU    = 3'b011;
localparam logic [2:0] F3_XOR     = 3'b100;
localparam logic [2:0] F3_SRL_SRA = 3'b101;
localparam logic [2:0] F3_OR      = 3'b110;
localparam logic [2:0] F3_AND     = 3'b111;

// funct3 for BRANCH
localparam logic [2:0] F3_BEQ  = 3'b000;
localparam logic [2:0] F3_BNE  = 3'b001;
localparam logic [2:0] F3_BLT  = 3'b100;
localparam logic [2:0] F3_BGE  = 3'b101;
localparam logic [2:0] F3_BLTU = 3'b110;
localparam logic [2:0] F3_BGEU = 3'b111;

// funct3 for LOAD
localparam logic [2:0] F3_LB  = 3'b000;
localparam logic [2:0] F3_LH  = 3'b001;
localparam logic [2:0] F3_LW  = 3'b010;
localparam logic [2:0] F3_LBU = 3'b100;
localparam logic [2:0] F3_LHU = 3'b101;


// funct3 for STORE
localparam logic [2:0] F3_SB = 3'b000;
localparam logic [2:0] F3_SH = 3'b001;
localparam logic [2:0] F3_SW = 3'b010;

// Immediate source select
typedef enum logic [2:0] { 
  IMM_I, 
  IMM_S, 
  IMM_B, 
  IMM_U, 
  IMM_J 
} imm_src;

// Result mux select (write-back)
typedef enum logic [1:0] { 
  RES_ALU = 2'b00, 
  RES_MEM = 2'b01, 
  RES_PC4 = 2'b10 
} result_src;

// Branch type for PCSrc computation
typedef enum logic [2:0] { 
  BR_NONE = 3'b000, 
  BR_EQ   = 3'b001, 
  BR_NE   = 3'b010,
  BR_LTS  = 3'b011, // signed <
  BR_GES  = 3'b100, // signed >=
  BR_LTU  = 3'b101, // unsigned <
  BR_GEU  = 3'b110 // unsigned >= 
} branch;

// [ADDED] Load/Store type enums to support full RV32I memory sizes
typedef enum logic [2:0] {
LD_LB  = 3'b000,
LD_LH  = 3'b001,
LD_LW  = 3'b010,
LD_LBU = 3'b100,
LD_LHU = 3'b101
} load_type;

typedef enum logic [1:0] {
ST_SB = 2'b00,
ST_SH = 2'b01,
ST_SW = 2'b10
} store_type;

endpackage : cpu_pkg

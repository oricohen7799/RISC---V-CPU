// * * * Immediate Generator * * * // 

`timescale 1ns/1ps
`default_nettype none

module imm_gen
  import cpu_pkg::*;
(
  input  wire [31:0]       instr_i,
  input  var imm_src       imm_src_i,
  output logic [WIDTH-1:0] imm_o
);

  // I-type: instr[31:20]
  wire [11:0] i_imm12    = instr_i[31:20];
  wire [WIDTH-1:0] imm_i = {{(WIDTH-12){i_imm12[11]}}, i_imm12};

  // S-type: {31:25, 11:7}
  wire [11:0] s_imm12    = {instr_i[31:25], instr_i[11:7]};
  wire [WIDTH-1:0] imm_s = {{(WIDTH-12){s_imm12[11]}}, s_imm12};

  // B-type: {31, 7, 30:25, 11:8, 0}
  wire [12:0] b_imm13    = {instr_i[31], instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};
  wire [WIDTH-1:0] imm_b = {{(WIDTH-13){b_imm13[12]}}, b_imm13};

  // U-type: {31:12, 12'b0}
  wire [31:12] u_imm20   = instr_i[31:12];
  wire [WIDTH-1:0] imm_u = {u_imm20, 12'b0};

  // J-type: {31, 19:12, 20, 30:21, 0}
  wire [20:0] j_imm21    = {instr_i[31], instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0};
  wire [WIDTH-1:0] imm_j = {{(WIDTH-21){j_imm21[20]}}, j_imm21};

  always_comb begin
    unique case (imm_src_i)
      IMM_I: imm_o = imm_i;
      IMM_S: imm_o = imm_s;   
      IMM_B: imm_o = imm_b; 
      IMM_U: imm_o = imm_u;
      IMM_J: imm_o = imm_j;
      default: imm_o = '0;
    endcase
  end
endmodule

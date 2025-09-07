// * * * Single-Cycle RISC-V CPU (RV32I) * * * //

`timescale 1ns/1ps
`default_nettype none

module cpu
  import cpu_pkg::*;
  (
    input wire clk_i,
    input wire rst_n_i
  );

  // --------------- INTERNALS ---------------

  // Fetch
  logic [WIDTH-1:0] pc_q;
  logic [WIDTH-1:0] pc_plus4;
  logic [WIDTH-1:0] pc_load_val;
  logic [31:0]      instr;
  logic             pc_load;

  // Decode
  logic [4:0] rs1, rs2, rd;
  logic [2:0] f3;
  logic [6:0] op, f7;

  assign op  = instr[6:0];
  assign rd  = instr[11:7];
  assign f3  = instr[14:12];
  assign rs1 = instr[19:15];
  assign rs2 = instr[24:20];
  assign f7  = instr[31:25];

  // Register File
  logic [WIDTH-1:0] rs1_data;
  logic [WIDTH-1:0] rs2_data;
  logic [WIDTH-1:0] wb_data;

  // Control
  logic       reg_write;
  imm_src     imm_src_sel;
  logic       alu_src_sel;
  logic       mem_write;
  result_src  result_src_sel;
  logic       pc_src_sel;
  alu_op      alu_ctrl;
  load_type   load_t;
  store_type  store_t;

  // Immediate
  logic [WIDTH-1:0] imm_ext;

  // ALU
  logic [WIDTH-1:0] alu_a;
  logic [WIDTH-1:0] alu_b;
  logic [WIDTH-1:0] alu_y;
  logic             alu_zero;

  // Data-Memory
  logic [31:0] dmem_wdata;
  logic [31:0] dmem_rdata;
  logic [3:0]  dmem_wem;
  logic [1:0]  addr_off;

  // Write-Back
  logic [31:0] load_ext;
  logic [15:0] load_half;
  logic [7:0]  load_byte; 

  // --------------- FETCH ---------------
  pc u_pc (
    .clk_i         (clk_i),
    .rst_n_i       (rst_n_i),
    .pc_load_i     (pc_load),
    .pc_load_val_i (pc_load_val),
    .pc_o          (pc_q),
    .pc_plus4_o    (pc_plus4) 
  );
  
  // Instruction memory
  imem u_imem (
    .addr_i  (pc_q),
    .instr_o (instr)
  );

  // --------------- REGISTER FILE ---------------
  regfile u_regfile (
    .clk_i    (clk_i),
    .rst_n_i  (rst_n_i),
    .we_i     (reg_write),
    .rs1_i    (rs1),
    .rs2_i    (rs2),
    .rd_i     (rd),
    .wd_i     (wb_data),
    .rs1_o    (rs1_data),
    .rs2_o    (rs2_data)
  );

  // --------------- CONTROL ---------------
  control u_ctrl (
    .instr_i      (instr),
    .zero_i       (alu_zero),
    .lt_i         ($signed(rs1_data) <  $signed(rs2_data)),
    .ltu_i        (        rs1_data  <          rs2_data ),
    .reg_write_o  (reg_write),
    .imm_src_o    (imm_src_sel),
    .alu_src_o    (alu_src_sel),
    .mem_write_o  (mem_write),
    .result_src_o (result_src_sel),
    .pc_src_o     (pc_src_sel),
    .alu_ctrl_o   (alu_ctrl),
    .load_type_o  (load_t),
    .store_type_o (store_t)
  );

  // --------------- IMMEDIATE ---------------
  imm_gen u_imm (
    .instr_i    (instr),
    .imm_src_i  (imm_src_sel),
    .imm_o      (imm_ext)
  );

  // --------------- EXECUTE / ALU ---------------
  // A selection
  always_comb begin
    unique case (op)
      OP_AUIPC: alu_a = pc_q;
      OP_LUI:   alu_a = '0;
      default:  alu_a = rs1_data;
    endcase
  end

  // B selection
  assign alu_b = (alu_src_sel) ? imm_ext : rs2_data;

  alu u_alu (
    .a_i        (alu_a),
    .b_i        (alu_b),
    .alu_ctrl_i (alu_ctrl),
    .y_o        (alu_y),
    .zero_o     (alu_zero)
  );

  // --------------- DATA-MEMORY ---------------
  assign addr_off = alu_y[1:0];

  always_comb begin
    dmem_wem   = 4'b0000;
    dmem_wdata = 32'h0000_0000;
    // Generate byte-enables only when mem_write is asserted
    if (mem_write) begin
      unique case (store_t)
        ST_SB: begin
          dmem_wem   = 4'b0001 << addr_off;
          // SB must use rs2_data (store source)
          dmem_wdata = {4{rs2_data[7:0]}} << (8*addr_off);
        end
        ST_SH: begin
          dmem_wem   = (addr_off[1]) ? 4'b1100 : 4'b0011;
          dmem_wdata = {2{rs2_data[15:0]}} << (16*addr_off[1]);
        end
        default: begin // ST_SW
          dmem_wem   = 4'b1111;
          dmem_wdata = rs2_data;
        end
      endcase
    end
  end

  dmem u_dmem (
    .clk_i    (clk_i),
    .we_i     (mem_write),
    .wem_i    (dmem_wem),
    .addr_i   (alu_y),
    .wd_i     (dmem_wdata),
    .rd_o     (dmem_rdata)
  );

  // --------------- LOAD EXTEND / WRITE-BACK ---------------
  always_comb begin
    load_byte = (dmem_rdata >> (8*addr_off)) & 8'hff;
    load_half = (addr_off[1]) ? dmem_rdata[31:16] : dmem_rdata[15:0];
    
    unique case (load_t)
      LD_LB:    load_ext = {{24{load_byte[7]}}, load_byte};
      LD_LBU:   load_ext = {24'h0, load_byte};
      LD_LH:    load_ext = {{16{load_half[15]}}, load_half};
      LD_LHU:   load_ext = {16'h0, load_half};
      default:  load_ext = dmem_rdata; // load word
   endcase
  end

  always_comb begin
    unique case (result_src_sel)
      RES_ALU: wb_data = alu_y;
      RES_MEM: wb_data = load_ext;
      RES_PC4: wb_data = pc_plus4;
      default: wb_data = pc_plus4;
    endcase
  end

  // --------------- NEXT PC ---------------
  always_comb begin
    pc_load = pc_src_sel;
    pc_load_val = pc_plus4;

    // PC load value multiplexer
    unique case (op)
      OP_JAL:    pc_load_val = pc_q + imm_ext;
      OP_JALR:   pc_load_val = (rs1_data + imm_ext) & ~32'h1;
      OP_BRANCH: pc_load_val = pc_q + imm_ext;
      default:   pc_load_val = pc_plus4;
    endcase
  end
endmodule

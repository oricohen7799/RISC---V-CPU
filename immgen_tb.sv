// * * * Immediate Generator Testbench  * * * //

`timescale 1ns/1ps
`default_nettype none

module immgen_tb;
  import cpu_pkg::*;

  // DUT signals
  logic [31:0]      instr_i;
  imm_src           imm_src_i;
  logic [WIDTH-1:0] imm_o;

  // DUT
  imm_gen dut (.*);

  // Error counter
  integer tb_error = 0;

  // Helpers: sign-extend 
  function automatic logic [WIDTH-1:0] i_type_imm(input logic [11:0] imm12);
    return {{(WIDTH-12){imm12[11]}}, imm12};
  endfunction

  function automatic logic [WIDTH-1:0] u_type_imm(input logic [19:0] imm20);
    return {imm20, 12'h000};
  endfunction

  function automatic logic [WIDTH-1:0] s_type_imm(input logic [11:0] imm12);
    return {{(WIDTH-12){imm12[11]}}, imm12};
  endfunction

  function automatic logic [WIDTH-1:0] b_type_imm(input logic [12:0] imm13);
    return {{(WIDTH-13){imm13[12]}}, imm13};
  endfunction

  function automatic logic [WIDTH-1:0] j_type_imm(input logic [20:0] imm21);
    return {{(WIDTH-21){imm21[20]}}, imm21};
  endfunction

  // Instruction builders 
  function automatic logic [31:0] build_i_instr(input logic [11:0] imm12);
    logic [31:0] instr = '0; instr[31:20] = imm12; return instr;
  endfunction

  function automatic logic [31:0] build_u_instr(input logic [19:0] imm20);
    logic [31:0] instr = '0; instr[31:12] = imm20; return instr;
  endfunction

  function automatic logic [31:0] build_s_instr(input logic [11:0] imm12);
    logic [31:0] instr = '0; instr[31:25] = imm12[11:5]; instr[11:7] = imm12[4:0]; return instr;
  endfunction

  function automatic logic [31:0] build_b_instr(input logic [12:0] imm13);
    logic [31:0] instr = '0;
    instr[31]          = imm13[12];
    instr[30:25]       = imm13[10:5];
    instr[11:8]        = imm13[4:1];
    instr[7]           = imm13[11];
    return instr;
  endfunction

  function automatic logic [31:0] build_j_instr(input logic [20:0] imm21);
    logic [31:0] instr = '0;
    instr[31]          = imm21[20];
    instr[30:21]       = imm21[10:1];
    instr[20]          = imm21[11];
    instr[19:12]       = imm21[19:12];
    return instr;
  endfunction

  // Checkers
  task automatic check_i(input string name, input logic [11:0] imm12);
    logic [WIDTH-1:0] exp;
    imm_src_i = IMM_I; 
    instr_i = build_i_instr(imm12); 
    #1;
    exp = i_type_imm(imm12);
    if (imm_o !== exp) begin 
      tb_error++; 
      $error("FAIL %s: imm12=%03h got=%08h exp=%08h", name, imm12, imm_o, exp);
    end else 
      $display("PASS %s: %08h", name, imm_o);
  endtask

  task automatic check_u(input string name, input logic [19:0] imm20);
    logic [WIDTH-1:0] exp;
    imm_src_i = IMM_U; 
    instr_i = build_u_instr(imm20); 
    #1;
    exp = u_type_imm(imm20);
    if (imm_o !== exp) begin 
      tb_error++; 
      $error("FAIL %s: imm20=%05h got=%08h exp=%08h", name, imm20, imm_o, exp);
    end else 
      $display("PASS %s: %08h", name, imm_o);
  endtask

  task automatic check_s(input string name, input logic [11:0] imm12);
    logic [WIDTH-1:0] exp;
    imm_src_i = IMM_S; 
    instr_i = build_s_instr(imm12); 
    #1;
    exp = s_type_imm(imm12);
    if (imm_o !== exp) begin 
      tb_error++; 
      $error("FAIL %s: imm12=%03h got=%08h exp=%08h", name, imm12, imm_o, exp);
    end else 
      $display("PASS %s: %08h", name, imm_o);
  endtask

  task automatic check_b(input string name, input logic [12:0] imm13);
    logic [WIDTH-1:0] exp;
    imm_src_i = IMM_B; 
    instr_i = build_b_instr(imm13); 
    #1;
    exp = b_type_imm(imm13);
    if (imm_o !== exp) begin 
      tb_error++; 
      $error("FAIL %s: imm13=%04h got=%08h exp=%08h", name, imm13, imm_o, exp);
    end else 
      $display("PASS %s: %08h", name, imm_o);
  endtask

  task automatic check_j(input string name, input logic [20:0] imm21);
    logic [WIDTH-1:0] exp;
    imm_src_i = IMM_J; 
    instr_i = build_j_instr(imm21); 
    #1;
    exp = j_type_imm(imm21);
    if (imm_o !== exp) begin 
      tb_error++; 
      $error("FAIL %s: imm21=%06h got=%08h exp=%08h", name, imm21, imm_o, exp);
    end else 
      $display("PASS %s: %08h", name, imm_o);
  endtask

 
  initial begin
    $display("\n==== ImmGen TB START ====\n");
    instr_i = '0; imm_src_i = IMM_I; #1;    // default

    // I-type
    check_i("I +1        ", 12'h001);
    check_i("I -1        ", 12'hFFF);
    check_i("I +MAX      ", 12'h7FF);
    check_i("I -MIN      ", 12'h800);

    // U-type
    check_u("U 0x00001   ", 20'h00001);
    check_u("U 0xABCDE   ", 20'hABCDE);

    // S-type
    check_s("S +1        ", 12'h001); 
    check_s("S -1        ", 12'hFFF); 
    check_s("S +MAX      ", 12'h7FF);
    check_s("S -MIN      ", 12'h800);

    // B-type
    check_b("B +2        ", 13'h0002);
    check_b("B -2        ", 13'h1FFE);
    check_b("B +MAX      ", 13'h0FFE);
    check_b("B -MIN      ", 13'h1000);

    // J-type
    check_j("J +2        ", 21'h000002);
    check_j("J -2        ", 21'h1FFFFE);
    check_j("J +MAX      ", 21'h0FFFFE);
    check_j("J -MIN      ", 21'h100000);

    $display("\n===== ImmGen TB DONE =====");
    $display("* SUMMARY *  Error: %0d", tb_error);
    if (tb_error == 0) $display("RESULT: PASS");
    else               $display("RESULT: FAIL");
    $finish;
  end
endmodule

// * * * Register File Testbench * * * // 

`timescale 1ns/1ps
`default_nettype none

module regfile_tb;
  import cpu_pkg::*;

  // DUT signals
  reg               clk_i;
  reg               rst_n_i;
  reg               we_i;
  reg  [4:0]        rs1_i;
  reg  [4:0]        rs2_i;
  reg  [4:0]        rd_i;
  reg  [WIDTH-1:0]  wd_i;
  wire [WIDTH-1:0]  rs1_o;
  wire [WIDTH-1:0]  rs2_o;

  // DUT
  regfile dut (.*);

  // Clock 100 MHz
  initial clk_i = 1'b0;
  always #5 clk_i = ~clk_i;

  integer tb_error = 0;
  integer counter  = 0;

  // Print helpers
  task automatic print_header;
    $display("");
    $display("  %-14s | %-5s %-10s %-9s | %-5s %-10s %-10s",
             "Test", "rs1", "actual", "expect", "rs2", "actual", "expect");
    $display("  ---------------+----------------------------+-----------------------------");
  endtask

  task automatic print_row(string name,
                                int addr1, logic [WIDTH-1:0] act1, logic [WIDTH-1:0] exp1,
                                int addr2, logic [WIDTH-1:0] act2, logic [WIDTH-1:0] exp2);
    $display("  %-14s | x%-3d 0x%08h 0x%08h | x%-3d 0x%08h 0x%08h",
             name, addr1, act1, exp1, addr2, act2, exp2);
  endtask

  // Synchronous write + cleanup
  task automatic write_reg(input [4:0] rd, input [WIDTH-1:0] data, input wd);
    @(negedge clk_i);
    rd_i = rd;
    wd_i = data;
    we_i = wd;
    @(posedge clk_i);
    @(negedge clk_i);
    we_i = 1'b0;
  endtask

  // Hold-write (no cleanup)
  task automatic write_reg_hold(input [4:0] rd, input [WIDTH-1:0] data);
    @(negedge clk_i);
    rd_i = rd;
    wd_i = data;
    we_i = 1'b1;
    @(posedge clk_i);
  endtask

  task automatic write_cleanup;
    @(negedge clk_i);
    we_i = 1'b0;
  endtask

  // Set read addresses and allow comb settle
  task automatic set_reads(input [4:0] addr1, input [4:0] addr2);
    rs1_i = addr1;
    rs2_i = addr2;
    #1;
  endtask

  // Read & check
  task automatic read_check(
    input string            name,
    input logic [4:0]       addr1, input logic [WIDTH-1:0] exp1,
    input logic [4:0]       addr2, input logic [WIDTH-1:0] exp2
  );
    set_reads(addr1, addr2);
    if ((rs1_o !== exp1) || (rs2_o !== exp2)) begin
      tb_error++;
      print_row(name, addr1, rs1_o, exp1, addr2, rs2_o, exp2);
    end else
      print_row(name, addr1, rs1_o, exp1, addr2, rs2_o, exp2);
  endtask


  initial begin
    $display("\n==== RegFile TB START ====\n");

    // defaults
    we_i  = 1'b0;
    rs1_i = '0;
    rs2_i = '0;
    rd_i  = '0;
    wd_i  = '0;

    // Reset
    rst_n_i = 1'b0;
    repeat (2) @(posedge clk_i);
    rst_n_i = 1'b1; #1;

    print_header();

    // After reset
    read_check("RESET-SPOT   ", 5'd0, '0, 5'd31, '0);
    for (int i = 0; i < 32; i++) begin
      set_reads(i[4:0], i[4:0]);
      if (rs1_o !== '0) begin
        tb_error++;
        print_row("FAIL", i[4:0], rs1_o, '0, i[4:0], rs2_o, '0);
      end
    end
    if (tb_error == 0) $display("  RST PASS: All registers holds 0");

    // x0 hardwired to zero
    write_reg(5'd0, 32'hFFFF_FFFF, 1'b1);
    read_check("X0 CONST-ZERO", 5'd0, '0, 5'd0, '0);

    // Basic write/read
    write_reg(5'd1, 32'h1111_1111, 1'b1);
    write_reg(5'd2, 32'h2222_2222, 1'b1);
    read_check("BASIC W/R    ", 5'd1, 32'h1111_1111, 5'd2, 32'h2222_2222);

    // Write-enable guard (we=0)
    write_reg(5'd3, 32'hAAAA_AAAA, 1'b0);
    read_check("WE=0 GUARD   ", 5'd3, '0, 5'd1, 32'h1111_1111);

    // Back-to-back writes
    write_reg_hold(5'd4, 32'h4444_4444);
    write_reg_hold(5'd5, 32'h5555_5555);
    write_cleanup();
    read_check("B2B WRITES   ", 5'd4, 32'h4444_4444, 5'd5, 32'h5555_5555);

    // Same-cycle read-after-write (The last write wins)
    write_reg(5'd6, 32'h6060_6060, 1'b1);
    @(negedge clk_i);
    rd_i  = 5'd6;
    wd_i  = 32'h6666_6666;
    we_i  = 1'b1;
    rs1_i = 5'd6; rs2_i = 5'd6;
    @(posedge clk_i); #1;
    read_check("R/W SAMECYCLE", 5'd6, 32'h6666_6666, 5'd6, 32'h6666_6666);
    write_cleanup();

    // Mid-run reset
    rst_n_i = 1'b0; 
    @(posedge clk_i);
    rst_n_i = 1'b1; #1;
    read_check("MID-RST      ", 5'd6, '0, 5'd5, '0);
    for (int i = 0; i < 32; i++) begin
      set_reads(i[4:0], i[4:0]);
      if (rs1_o !== '0) begin
        tb_error++; counter++;
        print_row("FAIL", i[4:0], rs1_o, '0, i[4:0], rs2_o, '0);
      end
    end
    if (counter == 0) $display("  RST PASS: All registers holds 0");

    // Write sweep & read
    for (int i = 1; i < 9; i++) begin
      write_reg(i[4:0], (32'hFFFF_FFF7 + i[4:0]), 1'b1);
    end
    read_check("SWEEP        ", 5'd1, 32'hFFFF_FFF8, 5'd2, 32'hFFFF_FFF9);
    read_check("SWEEP        ", 5'd3, 32'hFFFF_FFFA, 5'd4, 32'hFFFF_FFFB);
    read_check("SWEEP        ", 5'd5, 32'hFFFF_FFFC, 5'd6, 32'hFFFF_FFFD);
    read_check("SWEEP        ", 5'd7, 32'hFFFF_FFFE, 5'd8, 32'hFFFF_FFFF);

    $display("\n===== RegFile TB DONE =====");
    $display("* SUMMARY * Error: %0d", tb_error);
    if (tb_error == 0) $display("RESULT: PASS");
    else               $display("RESULT: FAIL");
    $finish;
  end
endmodule

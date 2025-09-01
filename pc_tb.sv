// * * * PC Testbench  * * * // 

`timescale 1ns/1ps  
`default_nettype none

module pc_tb;
  import cpu_pkg::*;

  // DUT
  reg           clk_i;      
  reg           rst_n_i;        
  reg           pc_load_i;      
  reg [31:0]    pc_load_val_i; 
  wire [31:0]   pc_o;         
  wire [31:0]   pc_plus4_o;
  pc dut (.*);

  // Clock : 100 MHz
  initial clk_i    = 1'b0;
  always #5 clk_i = ~clk_i;

  // Global error counter
  integer tb_error = 0;

  // Self-check: compare PC to expected value
  task automatic check_pc(input string name, input [31:0] expected);
    if (pc_o !== expected) begin
      tb_error++;
      $error("FAIL %-12s got=%h exp=%h", name, pc_o, expected);
    end else
      $display("PASS %-12s %h", name, pc_o);
  endtask

  // Self-check: verify pc_plus4_o matches pc_o + 4
  task automatic check_plus4(input string name);
    if (pc_plus4_o !== (pc_o + 32'd4)) begin
      tb_error++;
      $error("FAIL %-12s pc_plus4_o got=%h exp=%h", name, pc_plus4_o, pc_o + 32'd4);
    end else   
      $display("PASS %-12s pc_plus4_o=%h", name, pc_plus4_o);
  endtask

  initial begin
    $display("\n==== PC TB START ====\n");
    
    // Initialize inputs
    rst_n_i       = 1'b0;       // keep reset active (active-low)
    pc_load_i     = 1'b0;       // Disable load at startup
    pc_load_val_i = '0;         // Default load value = 0

    // Hold reset for two clock edges
    repeat (2)@(posedge clk_i); #1;
  
    // Check reset (assumes RESET_PC_ADDR == 0)
    check_pc("reset", 32'h0000_0000);
    check_plus4("reset");
  
    // Release reset
    rst_n_i = 1'b1;

    // +4 increments (two cycles)
    @(posedge clk_i); #1; check_pc("inc #1", 32'h0000_0004); check_plus4("inc #1");
    @(posedge clk_i); #1; check_pc("inc #2", 32'h0000_0008); check_plus4("inc #2");

    // External load (Brench / Jump) - drive on negedge, sample next posedge
    @(negedge clk_i);
    pc_load_val_i = 32'h0000_0100;
    pc_load_i     = 1'b1;
    @(posedge clk_i);  #1;
    check_pc("load 0x100", 32'h0000_0100); check_plus4("after load");

    // Back to +4 increment
    @(negedge clk_i);
    pc_load_i = 1'b0;
    @(posedge clk_i); #1;
    check_pc("inc #3", 32'h0000_0104); check_plus4("inc #3");

    // Mid-run reset: assert, hold, deassert, check again
    @(negedge clk_i);
    rst_n_i = 1'b0;           // assert reset
    @(posedge clk_i); #1;     // hold for 1 clock
    check_pc("mid-reset", 32'h0000_0000);
    check_plus4("mid-reset");
    @(negedge clk_i);
    rst_n_i = 1'b1;           // deassert reset
    @(posedge clk_i); #1;     // allow update

    // One increment after mid-reset
    check_pc("post mid-reset inc", 32'h0000_0004);
    check_plus4("post mid-reset inc");

    $display("\n===== ALU TB DONE =====\n");
    $display("\n* SUMMARY *\nError: %0d", tb_error);
    if (tb_error == 0) $display("RESULT: PASS\n");
    else               $display("RESULT: FAIL\n");
    $finish;
  end
endmodule

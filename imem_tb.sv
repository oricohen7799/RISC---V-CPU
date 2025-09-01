// * * * IMEM Testbench  * * * // 

`timescale 1ns/1ps
`default_nettype none

module imem_tb;
  import cpu_pkg::*;

  // DUT
  reg [WIDTH-1:0] addr_i;
  wire [31:0]     instr_o;
  imem dut (.*);

  integer tb_error = 0;

  // Check helper
  task automatic Check_imem(input string name,
                           input logic [31:0] addr,
                           input logic [31:0] exp );
    begin
      addr_i = addr;
      #1;      // settle
      if (instr_o !== exp) begin
        tb_error++;
        $error("FAIL: %s", name);
        $display("    Address: 0x%08h", addr);
        $display("    Expected: 0x%08h", exp);
        $display("    Got: 0x%08h", instr_o);
      end else 
        $display("PASS %s: addr=0x%08h -> 0x%08h", name, addr, instr_o);
    end
  endtask

  initial begin
    $display("\n==== IMEM TB START\n");

    $display("Instructions in ROM:");
    $display("NOP            (0x00000013)");
    $display("addi x1,x0,1   (0x00100093)");
    $display("addi x2,x1,2   (0x00208113)");
    $display("jal x0,0       (0xh0000006F)\n");

    // Read words from ROM
    $display("Read words from ROM");
    Check_imem("Read word 0   ", 32'h0000_0000, 32'h00000013); // NOP
    Check_imem("Read word 1   ", 32'h0000_0004, 32'h00100093); // addi x1,x0,1
    Check_imem("Read word 2   ", 32'h0000_0008, 32'h00208113); // addi x2,x1,2
    Check_imem("Read word 3   ", 32'h0000_000C, 32'h0000006F); // jal x0,0
    
    // Out of range -> NOP
    $display("\nOut-of-range addr");
    Check_imem("OOR           ", 32'h0000_1000, INSN_NOP);

    // Unaligned addresses -> NOP
    $display("\nUnaligned addr (should get error and read NOP)");
    Check_imem("Unaligned addr", 32'h0000_0001, 32'h00000013); // NOP

    $display("\n==== IMEM TB END ====");
    $display("* SUMMARY * Errors: %0d", tb_error);
    if (tb_error == 0)
      $display("RESULT: PASS\n"); 
    else
      $display("RESULT: FAIL\n");
    $finish;
  end

endmodule

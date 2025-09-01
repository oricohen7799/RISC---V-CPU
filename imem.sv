// * * * Instruction Memory (ROM) * * * //

`timescale 1ns/1ps
`default_nettype none

module imem
  import cpu_pkg::*;
(
  input  wire  [WIDTH-1:0] addr_i,
  output logic [31:0]      instr_o
);

  // ROM array
  logic [31:0] rom [0:IMEM_DEPTH-1];

  // Address decode
  logic [$clog2(IMEM_DEPTH)-1:0] idx;
  always_comb begin
    idx     = addr_i[WIDTH-1:2];
    instr_o = rom[idx];
  end

`ifdef IMEM_CHECKS
  // Enforce word-aligned fetch
  always @(*) if (addr_i[1:0] != 2'b00)
    $error("IMEM: unaligned fetch addr=0x%08h", addr_i);
`endif

  // Always load from file
  string imem_file = "imem.hex";
  initial begin
    // init to NOPs so undefined locations are safe
    for (int i = 0; i < IMEM_DEPTH; i++) rom[i] = INSN_NOP;
    $display("IMEM: Loading instruction memory from %s", imem_file);
    $readmemh(imem_file, rom);
  end

endmodule

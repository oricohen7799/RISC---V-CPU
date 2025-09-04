// * * * Register File * * * //

`timescale 1ns/1ps
`default_nettype none

module regfile
  import cpu_pkg::*;
(
  input wire               clk_i,   // clock
  input wire               rst_n_i, // active-low synchronous reset
  input wire               we_i,    // write enable
  input wire  [4:0]        rs1_i,   // source register 1 address
  input wire  [4:0]        rs2_i,   // source register 2 address
  input wire  [4:0]        rd_i,    // destination register address
  input wire  [WIDTH-1:0]  wd_i,    // data to write

  output wire [WIDTH-1:0]  rs1_o,   // data read from rs1
  output wire [WIDTH-1:0]  rs2_o    // data read from rs2
);

logic [WIDTH-1:0] regs [0:31];

// Combinational read ports, x0 always harwired to 0
assign rs1_o = (rs1_i == 5'd0) ? '0 : regs[rs1_i];
assign rs2_o = (rs2_i == 5'd0) ? '0 : regs[rs2_i];

// Write port
always_ff @(posedge clk_i) begin
  if (!rst_n_i) begin
          // reset all registers to 0
    for (int i = 0 ; i < 32; i++) begin
      regs[i] <= '0; 
      end
  end else begin 
    if (we_i && (rd_i != 5'd0)) begin
         // write data to rd register
       regs[rd_i] <= wd_i;
    end
  end
end

endmodule

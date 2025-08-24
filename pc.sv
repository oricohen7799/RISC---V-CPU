// * * * PC - Program Caunter * * * //

`timescale 1ns/1ps
`default_nettype none

module pc #(parameter WIDTH_P = 32)
(
  input wire                  clk_i ,          // clock input
  input wire                  rst_n_i,         // ative-low, synchronous resset
  input wire                  pc_load_i,       // 0 for PC+4 value, 1 for external value
  input wire  [WIDTH_P-1:0]   pc_load_val_i,   // value to load to PC when pc_load_i = 1

  output wire [WIDTH_P-1:0]   pc_q_o,          // current PC value
  output wire [WIDTH_P-1:0]   pc_plus4_o       // current PC + 4 , may be used for jal 
);

import cpu_pkg::*;

logic [WIDTH_P-1:0] pc_q;

// PC register with synchronous, active-low reset
always_ff @( posedge clk_i ) begin
  if (!rst_n_i) pc_q <= RESET_PC_ADDR;
  else begin
    if (pc_load_i) pc_q <= pc_load_val_i;
    else           pc_q <= pc_q + WIDTH_P'(32'd4);
  end
end

assign pc_q_o       = pc_q;
assign pc_plus4_o   = pc_q + WIDTH_P'(32'd4); 

endmodule


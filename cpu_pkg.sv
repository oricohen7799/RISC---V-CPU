`timescale 1ns/1ps
`default_nettype none

package cpu_pkg;

// CPU word width
parameter int WIDTH = 32;

// Reset address for the pc
parameter logic [WIDTH-1:0] RESET_PC_ADDR = '0;
  
endpackage : cpu_pkg

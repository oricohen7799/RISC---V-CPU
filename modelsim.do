transcript on
vlib work
vmap work work

set INC "+incdir+../rtl/pkg"
vlog -sv $INC ../rtl/pkg/cpu_pkg.sv
vlog -sv ../rtl/core/pc.sv
vlog -sv ../tb/pc_tb.sv

vsim work.pc_tb
add wave -r sim:/pc_tb/*
add wave -r sim:/pc_tb/dut/*
run -all


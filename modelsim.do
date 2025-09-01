transcript on

# Clean & setup work lib
if {[file exists work]} { vdel -all -lib work }
vlib work
vmap work work

# Include path for packages
set INC "+incdir+../rtl/pkg"

# Compile options
set DEFINES   "+define+IMEM_CHECKS+DMEM_CHECKS"
set VLOG_RTL  [list -sv $INC $DEFINES]
set VLOG_TB   [list -sv $INC $DEFINES +acc]

# -------- Compile: package and RTL --------
vlog {*}$VLOG_RTL ../rtl/pkg/cpu_pkg.sv
vlog {*}$VLOG_RTL ../rtl/core/pc.sv
vlog {*}$VLOG_RTL ../rtl/core/regfile.sv
vlog {*}$VLOG_RTL ../rtl/core/alu.sv
vlog {*}$VLOG_RTL ../rtl/core/immgen.sv
vlog {*}$VLOG_RTL ../rtl/core/control.sv
vlog {*}$VLOG_RTL ../rtl/mem/imem.sv
vlog {*}$VLOG_RTL ../rtl/mem/dmem.sv
# Top-level CPU
vlog {*}$VLOG_RTL ../rtl/top/cpu.sv

# -------- Compile: testbenches --------
vlog {*}$VLOG_TB  ../tb/pc_tb.sv
vlog {*}$VLOG_TB  ../tb/regfile_tb.sv
vlog {*}$VLOG_TB  ../tb/alu_tb.sv
vlog {*}$VLOG_TB  ../tb/immgen_tb.sv
vlog {*}$VLOG_TB  ../tb/imem_tb.sv
vlog {*}$VLOG_TB  ../tb/dmem_tb.sv
vlog {*}$VLOG_TB  ../tb/control_tb.sv
vlog {*}$VLOG_TB  ../tb/cpu_tb.sv   ;# module: cpu_tb

# -------- Choose TB (uncomment one) --------
# set TB cpu_tb
# set TB control_tb
# set TB imem_tb
# set TB alu_tb
# set TB pc_tb
# set TB regfile_tb
# set TB immgen_tb
# set TB dmem_tb

# -------- Program file (for cpu_tb) --------
# imem.hex is expected next to this .do
set IMEM_FILE "imem.hex"
set DMEM_FILE ""

# Build plusargs as a Tcl list
set PLUSARGS [list +IMEM=$IMEM_FILE +TRACE=1 +MAX_CYCLES=2000]
if {$DMEM_FILE ne ""} { lappend PLUSARGS +DMEM=$DMEM_FILE }

# Keep ModelSim open after run
# (no 'onfinish' here; we pass it to vsim)

# -------- Launch simulation --------
vsim -voptargs=+acc -onfinish stop work.$TB {*}$PLUSARGS
radix hex

# Waves (recursive)
add wave -r sim:/$TB/*
catch { add wave -r sim:/$TB/u_dut/* }
catch { add wave -r sim:/$TB/dut/* }

run -all

#File auto-generated during release generation


vlib work_testbench 
vmap work_testbench work_testbench 
vlog -suppress 2583 -suppress 13314 \
    -timescale "1ns/1ps" \
    -work \
    work_testbench \
    -f \
    ${PANTHER_ROOT}/scripts/tb/filelist_tb/files.0.work_testbench.VERILOG.f
vlog -suppress 2583 -suppress 13314 \
    -timescale "1ns/1ps" \
    -define CV32E40P_TRACE_EXECUTION \
    -work \
    work_testbench \
    +incdir+${PANTHER_ROOT}/testbench/bhv/panther/verification/acceptance/src/sv_axi \
    +incdir+${PANTHER_ROOT}/testbench/bhv/panther/verification/acceptance/tests \
    +incdir+${PANTHER_ROOT}/testbench/bhv/panther/verification/acceptance/src/bhv \
    +incdir+${PANTHER_ROOT}/testbench/bhv/panther/verification/acceptance/src/bhv/include \
    -f \
    ${PANTHER_ROOT}/scripts/tb/filelist_tb/files.1.work_testbench.VERILOG.f

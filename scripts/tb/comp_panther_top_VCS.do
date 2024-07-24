#File auto-generated during release generation


echo  "work_testbench : ./work_testbench" >> synopsys_sim.setup
mkdir -p  work_testbench
vlogan -full64 -q -sverilog -assert svaext   \
    -timescale=1ns/1ps \
    -work \
    work_testbench \
    -f \
    ${PANTHER_ROOT}/scripts/tb/filelist_tb/files.0.work_testbench.VERILOG.f
vlogan -full64 -q -sverilog -assert svaext   \
    -timescale=1ns/1ps \
    -work \
    work_testbench \
    +incdir+${PANTHER_ROOT}/testbench/bhv/panther/verification/src/sv_axi \
    +incdir+${PANTHER_ROOT}/testbench/bhv/panther/verification/tests \
    +incdir+${PANTHER_ROOT}/testbench/bhv/panther/verification/src/bhv \
    +incdir+${PANTHER_ROOT}/testbench/bhv/panther/verification/src/bhv/include \
    -f \
    ${PANTHER_ROOT}/scripts/tb/filelist_tb/files.1.work_testbench.VERILOG.f

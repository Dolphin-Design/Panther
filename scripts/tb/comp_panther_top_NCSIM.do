#File auto-generated during release generation


xmvhdl -64 -quiet > /dev/null  
echo  "DEFINE work_testbench work_testbench" >> xcelium.d/cds.lib
mkdir -p  xcelium.d/work_testbench
xmvlog -vtimescale 1ns/1ps -64 -sv    -nocopyright -cdslib xcelium.d/cds.lib -hdlvar xcelium.d/hdl.var  \
    -work \
    work_testbench \
    -pkgsearch \
    work_testbench \
    -f \
    ${PANTHER_ROOT}/scripts/tb/filelist_tb/files.0.work_testbench.VERILOG.f
xmvlog -vtimescale 1ns/1ps -64 -sv    -nocopyright -cdslib xcelium.d/cds.lib -hdlvar xcelium.d/hdl.var  \
    -work \
    work_testbench \
    -pkgsearch \
    work_testbench \
    +incdir+${PANTHER_ROOT}/testbench/bhv/panther/verification/acceptance/src/sv_axi \
    +incdir+${PANTHER_ROOT}/testbench/bhv/panther/verification/acceptance/tests \
    +incdir+${PANTHER_ROOT}/testbench/bhv/panther/verification/acceptance/src/bhv \
    +incdir+${PANTHER_ROOT}/testbench/bhv/panther/verification/acceptance/src/bhv/include \
    -f \
    ${PANTHER_ROOT}/scripts/tb/filelist_tb/files.1.work_testbench.VERILOG.f

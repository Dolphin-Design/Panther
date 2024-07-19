#File auto-generated during release generation


xmvhdl -64 -quiet > /dev/null  
echo  "DEFINE work_design work_design" >> xcelium.d/cds.lib
mkdir -p  xcelium.d/work_design
xmvlog -vtimescale 1ns/1ps -64 -sv    -nocopyright -cdslib xcelium.d/cds.lib -hdlvar xcelium.d/hdl.var  \
    -work \
    work_design \
    -pkgsearch \
    work_design \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.0.work_design.VERILOG.f
xmvlog -vtimescale 1ns/1ps -64 -sv    -nocopyright -cdslib xcelium.d/cds.lib -hdlvar xcelium.d/hdl.var  \
    -work \
    work_design \
    -pkgsearch \
    work_design \
    +incdir+${PANTHER_ROOT}/model/rtl/common/common_cells/upstream/include \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.1.work_design.VERILOG.f
xmvlog -vtimescale 1ns/1ps -64 -sv    -nocopyright -cdslib xcelium.d/cds.lib -hdlvar xcelium.d/hdl.var  \
    -work \
    work_design \
    -pkgsearch \
    work_design \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.2.work_design.VERILOG.f
xmvlog -vtimescale 1ns/1ps -64 -sv    -nocopyright -cdslib xcelium.d/cds.lib -hdlvar xcelium.d/hdl.var  \
    -work \
    work_design \
    -pkgsearch \
    work_design \
    +incdir+${PANTHER_ROOT}/model/rtl/common/hci/upstream/rtl/common \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.3.work_design.VERILOG.f
xmvlog -vtimescale 1ns/1ps -64 -sv    -nocopyright -cdslib xcelium.d/cds.lib -hdlvar xcelium.d/hdl.var  \
    -work \
    work_design \
    -pkgsearch \
    work_design \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.4.work_design.VERILOG.f
xmvlog -vtimescale 1ns/1ps -64 -sv    -nocopyright -cdslib xcelium.d/cds.lib -hdlvar xcelium.d/hdl.var  \
    -work \
    work_design \
    -pkgsearch \
    work_design \
    +incdir+${PANTHER_ROOT}/model/rtl/common/axi/axi/upstream/include \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.5.work_design.VERILOG.f
xmvlog -vtimescale 1ns/1ps -64 -sv    -nocopyright -cdslib xcelium.d/cds.lib -hdlvar xcelium.d/hdl.var  \
    -work \
    work_design \
    -pkgsearch \
    work_design \
    +incdir+${PANTHER_ROOT}/model/rtl/common/axi/axi/upstream/include \
    +incdir+${PANTHER_ROOT}/model/rtl/common/common_cells/upstream/include \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.6.work_design.VERILOG.f
xmvlog -vtimescale 1ns/1ps -64 -sv    -nocopyright -cdslib xcelium.d/cds.lib -hdlvar xcelium.d/hdl.var  \
    -work \
    work_design \
    -pkgsearch \
    work_design \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.7.work_design.VERILOG.f
xmvlog -vtimescale 1ns/1ps -64 -sv    -nocopyright -cdslib xcelium.d/cds.lib -hdlvar xcelium.d/hdl.var  \
    -work \
    work_design \
    -pkgsearch \
    work_design \
    +incdir+${PANTHER_ROOT}/model/rtl/common/axi/axi/upstream/include \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.8.work_design.VERILOG.f
xmvlog -vtimescale 1ns/1ps -64 -sv    -nocopyright -cdslib xcelium.d/cds.lib -hdlvar xcelium.d/hdl.var  \
    -work \
    work_design \
    -pkgsearch \
    work_design \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.9.work_design.VERILOG.f
xmvlog -vtimescale 1ns/1ps -64 -sv    -nocopyright -cdslib xcelium.d/cds.lib -hdlvar xcelium.d/hdl.var  \
    -work \
    work_design \
    -pkgsearch \
    work_design \
    +incdir+${PANTHER_ROOT}/model/rtl/common/cv32e40p/upstream/rtl/include \
    +incdir+${PANTHER_ROOT}/model/rtl/common/cv32e40p/upstream/rtl/vendor/pulp_platform_common_cells/include \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.10.work_design.VERILOG.f
xmvlog -vtimescale 1ns/1ps -64 -sv    -nocopyright -cdslib xcelium.d/cds.lib -hdlvar xcelium.d/hdl.var  \
    -work \
    work_design \
    -pkgsearch \
    work_design \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.11.work_design.VERILOG.f
xmvlog -vtimescale 1ns/1ps -64 -sv    -nocopyright -cdslib xcelium.d/cds.lib -hdlvar xcelium.d/hdl.var  \
    -work \
    work_design \
    -pkgsearch \
    work_design \
    +incdir+${PANTHER_ROOT}/model/rtl/common/panther/upstream/packages \
    +incdir+${PANTHER_ROOT}/model/rtl/common/axi/axi/upstream/include \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.12.work_design.VERILOG.f
xmvlog -vtimescale 1ns/1ps -64 -sv    -nocopyright -cdslib xcelium.d/cds.lib -hdlvar xcelium.d/hdl.var  \
    -work \
    work_design \
    -pkgsearch \
    work_design \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.13.work_design.VERILOG.f
xmvlog -vtimescale 1ns/1ps -64 -sv    -nocopyright -cdslib xcelium.d/cds.lib -hdlvar xcelium.d/hdl.var  \
    -work \
    work_design \
    -pkgsearch \
    work_design \
    +incdir+${PANTHER_ROOT}/model/rtl/common/axi/axi/upstream/include \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.14.work_design.VERILOG.f

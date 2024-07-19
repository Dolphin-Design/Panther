#File auto-generated during release generation


echo  "WORK_DESIGN > DEFAULT" >> synopsys_sim.setup
echo  "DEFAULT : ./work_design" >> synopsys_sim.setup
echo  "work_design : ./work_design" >> synopsys_sim.setup
mkdir -p  work_design
vlogan -full64 -q -sverilog -assert svaext   \
    -timescale=1ns/1ps \
    -work \
    work_design \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.0.work_design.VERILOG.f
vlogan -full64 -q -sverilog -assert svaext   \
    -timescale=1ns/1ps \
    -work \
    work_design \
    +incdir+${PANTHER_ROOT}/model/rtl/common/common_cells/upstream/include \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.1.work_design.VERILOG.f
vlogan -full64 -q -sverilog -assert svaext   \
    -timescale=1ns/1ps \
    -work \
    work_design \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.2.work_design.VERILOG.f
vlogan -full64 -q -sverilog -assert svaext   \
    -timescale=1ns/1ps \
    -work \
    work_design \
    +incdir+${PANTHER_ROOT}/model/rtl/common/hci/upstream/rtl/common \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.3.work_design.VERILOG.f
vlogan -full64 -q -sverilog -assert svaext   \
    -timescale=1ns/1ps \
    -work \
    work_design \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.4.work_design.VERILOG.f
vlogan -full64 -q -sverilog -assert svaext   \
    -timescale=1ns/1ps \
    -work \
    work_design \
    +incdir+${PANTHER_ROOT}/model/rtl/common/axi/axi/upstream/include \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.5.work_design.VERILOG.f
vlogan -full64 -q -sverilog -assert svaext   \
    -timescale=1ns/1ps \
    -work \
    work_design \
    +incdir+${PANTHER_ROOT}/model/rtl/common/axi/axi/upstream/include \
    +incdir+${PANTHER_ROOT}/model/rtl/common/common_cells/upstream/include \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.6.work_design.VERILOG.f
vlogan -full64 -q -sverilog -assert svaext   \
    -timescale=1ns/1ps \
    -work \
    work_design \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.7.work_design.VERILOG.f
vlogan -full64 -q -sverilog -assert svaext   \
    -timescale=1ns/1ps \
    -work \
    work_design \
    +incdir+${PANTHER_ROOT}/model/rtl/common/axi/axi/upstream/include \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.8.work_design.VERILOG.f
vlogan -full64 -q -sverilog -assert svaext   \
    -timescale=1ns/1ps \
    -work \
    work_design \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.9.work_design.VERILOG.f
vlogan -full64 -q -sverilog -assert svaext   \
    -timescale=1ns/1ps \
    -work \
    work_design \
    +incdir+${PANTHER_ROOT}/model/rtl/common/cv32e40p/upstream/rtl/include \
    +incdir+${PANTHER_ROOT}/model/rtl/common/cv32e40p/upstream/rtl/vendor/pulp_platform_common_cells/include \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.10.work_design.VERILOG.f
vlogan -full64 -q -sverilog -assert svaext   \
    -timescale=1ns/1ps \
    -work \
    work_design \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.11.work_design.VERILOG.f
vlogan -full64 -q -sverilog -assert svaext   \
    -timescale=1ns/1ps \
    -work \
    work_design \
    +incdir+${PANTHER_ROOT}/model/rtl/common/panther/upstream/packages \
    +incdir+${PANTHER_ROOT}/model/rtl/common/axi/axi/upstream/include \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.12.work_design.VERILOG.f
vlogan -full64 -q -sverilog -assert svaext   \
    -timescale=1ns/1ps \
    -work \
    work_design \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.13.work_design.VERILOG.f
vlogan -full64 -q -sverilog -assert svaext   \
    -timescale=1ns/1ps \
    -work \
    work_design \
    +incdir+${PANTHER_ROOT}/model/rtl/common/axi/axi/upstream/include \
    -f \
    ${PANTHER_ROOT}/scripts/partition_panther_top/filelist_sim/files.14.work_design.VERILOG.f
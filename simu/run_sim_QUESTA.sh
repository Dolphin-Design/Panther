#!/usr/bin/env bash

#Create and move to test directory
rm -rf run_dir_QUESTA
rm -rf run_dir_QUESTA
mkdir run_dir_QUESTA
cd run_dir_QUESTA
cp ../*dat* .

#Compile the design & its testbench
${PANTHER_ROOT}/scripts/partition_panther_top/comp_panther_top_panther_top_QUESTA.do | tee comp_rtl.log
${PANTHER_ROOT}/scripts/tb/comp_panther_top_QUESTA.do | tee comp_tb.log

#Run the simulation
vsim -64 -voptargs=+acc -L work_design -L work_testbench -lib work_testbench top_tb -c -do "run -all"  | tee simu.log

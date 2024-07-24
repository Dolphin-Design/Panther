#!/usr/bin/env bash

#Create and move to test directory
rm -rf run_dir_NCSIM
rm -rf run_dir_NCSIM
mkdir run_dir_NCSIM
cd run_dir_NCSIM
cp ../*dat* .

#Compile the design & its testbench
${PANTHER_ROOT}/scripts/partition_panther_top/comp_panther_top_panther_top_NCSIM.do | tee comp_rtl.log
${PANTHER_ROOT}/scripts/tb/comp_panther_top_NCSIM.do | tee comp_tb.log

#Run the simulation
xrun -q -licqueue -cdslib xcelium.d/cds.lib -64 -reflib work_testbench -top panther_top_tb | tee simu.log

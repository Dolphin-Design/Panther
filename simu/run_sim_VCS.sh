#!/usr/bin/env bash

#Create and move to test directory
rm -rf run_dir_VCS
rm -rf run_dir_VCS
mkdir run_dir_VCS
cd run_dir_VCS
cp ../*dat* .

#Compile the design & its testbench
${PANTHER_ROOT}/scripts/partition_panther_top/comp_panther_top_panther_top_VCS.do | tee comp_rtl.log
${PANTHER_ROOT}/scripts/tb/comp_panther_top_VCS.do | tee comp_tb.log

#Run the simulation
vcs -licqueue -full64 top_tb | tee elab.log
./simv -licqueue | tee simu.log

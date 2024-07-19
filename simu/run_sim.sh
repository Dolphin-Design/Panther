#!/bin/sh

# Display script usage
display_usage () {
	echo -e "Usage of the script: "
	echo -e "	./run_test.sh <tool_name> <test_name>"
	echo -e "	with"
	echo -e "		<tool_name> = NCSIM, QUESTA, VCS"
	echo -e "		<test_name> = panther_coremark_test, panther_matmul_32b_float_test, panther_matmul_32b_int_test"
	echo -e ""
}

# Check help argument
if [[ $1 == --help ]] || [[ $1 == -h ]]; then
	display_usage
	exit 0
fi

# Check right number of arguments
if [ $# -ne 2 ]; then
	echo -e "2 command line arguments are needed !"
	display_usage
	exit 1
fi

# Check right argument usage
if [ ! -f "run_sim_${1}.sh" ]; then
	echo -e "Wrong configuration run_sim_${1}.sh !!!"
	display_usage
	exit 0
fi

PANTHER_ROOT="../.."
export PANTHER_ROOT

cp -f ../testbench/bhv/panther/verification/acceptance/tests/${2}/*.dat* .
if [ -d "../testbench/bhv/panther/verification/acceptance/tests/${2}" ]; then
	./run_sim_${1}.sh
else
	echo -e "Wrong test name: ${2}"
	exit 0
fi



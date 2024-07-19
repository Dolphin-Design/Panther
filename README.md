# Dolphin Design Panther IP

Panther is a multi-core platform originated from [ETHZ Pulp Cluster](https://github.com/pulp-platform/pulp_cluster).
It went through a full industrial level verification using a full platform UVM test-bench and 4 additionnal block level test-benches targetting following Panther sub-modules:
- MCHAN DMA
- 2-level Shared Instruction Cache
- Event Unit
- a new module called cluster_mem_sys_wrap containing the logarithmic interconnect, the AXI Master and Slave size converters, the AXI crossbar, the axi2mem, axi2per and per2axi modules and finally the AXI Master and Slaves filters and busy modules.

## Panther IP configuration

This repository contains Panther RTL (in model/rtl) with parameters set to:
- 16 OpenHW Group CV32E40Pv2 cores (cv32e40p_v1.8.3 tag)
- FPU enabled
- 256 KB Shared Tightly Coupled Data Memory
- 32 KB Shared Instruction Cache caching a Level 2 256 KB memory area
- 32-b AXI Slave and Master interface (no dedicated Shared Instruction Cache refill interface)
- AXI interfaces synchronous interfaces

It contains additional technology dependent modules in model/rtl_user which need to be replaced by their targetted technology macros before going to implementation.
Due to its delivery model, cv32e40p core has its own technology dependent clock gating cell in model/rtl/common/cv32e40p/design/rtl to be replaced as well.

## Simulation

This repository contains an simple test-bench consisting of:
- a clock generator
- an AXI interface that is passed to test (data_slave_if) connected to Panther’s slave data interface
- an AXI RAM model (data_slave_L2) connected to Panther’s master data interface
- an AXI RAM model (instr_slave_L2) connected to Panther’s master instruction interface if the Shared Instruction Cache has its own refill interface.
- panther_acceptance_test that instantiates an AXI environment (axi_data_slave_env) that is used to generate transactions on AXI slave data interface and to check the responses

Additionally to the test-bench, there are 3 tests that can be run on this test-bench:
- panther_matmul_32b_float_test
- panther_matmul_32b_int_test
- panther_coremark_test

They consist in pre-generated AXI memories content in Verilog readmemh format.

To execute one of the test:
- Setup your evironment with your simulation tool (Siemens QUESTA, Cadence NCSIM or Synopsys VCS)
- Go to simu directory
- launch following command
  ./run_sim.sh TOOL test_name

### Tracer

The CV32E40P original tracer module generating the executed program instructions log file is instantiated in the test-bench and is producing one trace file per core.
The new CV32E40P RVFI tracer module was not intended to be used in a multi-core platform so it was not possible to add it in this simple test-bench.
As it is the up-to-date tracer module going together with the last v1.8.3 CV32E40P core version, some future work would be needed to adapt it to make it suitable for a multi-core platform.

> [!NOTE]
> Due to some tool setup or installation, uvm packages are not correctly found when compiling the test-bench for NCSIM and VCS.
> So right now this trace log file generation is only working with Siemens QUESTA Simulation tool.

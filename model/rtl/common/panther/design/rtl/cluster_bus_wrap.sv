// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

/*
 * cluster_bus_wrap.sv
 * Davide Rossi <davide.rossi@unibo.it>
 * Antonio Pullini <pullinia@iis.ee.ethz.ch>
 * Igor Loi <igor.loi@unibo.it>
 * Francesco Conti <fconti@iis.ee.ethz.ch>
 */


`include "axi/assign.svh"
`include "axi/typedef.svh"


module cluster_bus_wrap
    import axi_pkg::xbar_cfg_t;
    import pulp_cluster_package::addr_map_rule_t;
#(
  parameter NB_CORES              = 4 ,
  parameter bit USE_DEDICATED_INSTR_IF      = 0 ,
  parameter AXI_ADDR_WIDTH        = 32,
  parameter AXI_DATA_WIDTH        = 64,
  parameter AXI_ID_IN_WIDTH       = 4 ,
  parameter AXI_ID_OUT_WIDTH      = 6 ,
  parameter AXI_USER_WIDTH        = 6 ,
  parameter DMA_NB_OUTSND_BURSTS  = 8 ,
  parameter TCDM_SIZE             = 0

)
(
  input logic       clk_i,
  input logic       rst_ni,
  input logic       test_en_i,
  input logic [9:0] base_addr_i,
  AXI_BUS.Slave     data_slave,
  AXI_BUS.Slave     instr_slave,
  AXI_BUS.Slave     dma_slave,
  AXI_BUS.Slave     ext_slave,
  //INITIATOR
  AXI_BUS.Master    tcdm_master,
  AXI_BUS.Master    periph_master,
  AXI_BUS.Master    ext_master
);

  localparam NB_MASTER = 3 ;
  localparam NB_SLAVE  = (USE_DEDICATED_INSTR_IF) ? 3 : 4 ;

  //Ensure that AXI_ID out width has the correct size with an elaboration system task
  if (AXI_ID_OUT_WIDTH < AXI_ID_IN_WIDTH + $clog2(NB_SLAVE))
    $error("ID width of AXI output ports is to small. The output id width must be input ID width + clog2(<nr slave ports>) which is %d but it was %d", AXI_ID_IN_WIDTH + $clog2(NB_SLAVE), AXI_ID_OUT_WIDTH);
  else if (AXI_ID_OUT_WIDTH > AXI_ID_IN_WIDTH + $clog2(NB_SLAVE))
    $warning("ID width of the AXI output port has the wrong length. It is larger than the required value. Trim it to the right length to get rid of this warning.");

  if (AXI_ADDR_WIDTH != 32)
    $fatal(1,"Address map is only defined for 32-bit addresses!");
  if (TCDM_SIZE == 0)
    $fatal(1,"TCDM size must be non-zero!");
  if (TCDM_SIZE >256*1024)
    $fatal(1,"TCDM size exceeds available address space in cluster bus!");


  // Crossbar
  AXI_BUS #(
    .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH  ),
    .AXI_DATA_WIDTH ( AXI_DATA_WIDTH  ),
    .AXI_ID_WIDTH   ( AXI_ID_IN_WIDTH ),
    .AXI_USER_WIDTH ( AXI_USER_WIDTH  )
  ) axi_slaves [NB_SLAVE-1:0]();

  // assign here your axi slaves
  generate
    if (USE_DEDICATED_INSTR_IF == 0) begin : g_bus_wrap_slave4
      `AXI_ASSIGN(axi_slaves[0] , data_slave )
      `AXI_ASSIGN(axi_slaves[1] , instr_slave)
      `AXI_ASSIGN(axi_slaves[2] , dma_slave  )
      `AXI_ASSIGN(axi_slaves[3] , ext_slave  )
    end else begin : g_bus_wrap_slave3
      `AXI_ASSIGN(axi_slaves[0] , data_slave )
      `AXI_ASSIGN(axi_slaves[1] , dma_slave  )
      `AXI_ASSIGN(axi_slaves[2] , ext_slave  )
    end
  endgenerate

  generate
    if(USE_DEDICATED_INSTR_IF) begin
        assign instr_slave.aw_ready = '0;
        assign instr_slave.w_ready  = '0;
        assign instr_slave.b_id     = '0;
        assign instr_slave.b_resp   = '0;
        assign instr_slave.b_user   = '0;
        assign instr_slave.b_valid  = '0;
        assign instr_slave.ar_ready = '0;
        assign instr_slave.r_id     = '0;
        assign instr_slave.r_data   = '0;
        assign instr_slave.r_resp   = '0;
        assign instr_slave.r_last   = '0;
        assign instr_slave.r_user   = '0;
        assign instr_slave.r_valid  = '0;
    end
  endgenerate

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH    ),
    .AXI_DATA_WIDTH ( AXI_DATA_WIDTH    ),
    .AXI_ID_WIDTH   ( AXI_ID_OUT_WIDTH  ),
    .AXI_USER_WIDTH ( AXI_USER_WIDTH    )
  ) axi_masters [NB_MASTER-1:0]();

  // assign here your axi masters
  `AXI_ASSIGN(tcdm_master  , axi_masters[0])
  `AXI_ASSIGN(periph_master, axi_masters[1])
  `AXI_ASSIGN(ext_master   , axi_masters[2])

  // address map
  logic [31:0] cluster_base_addr;
  always_comb begin
      cluster_base_addr        = 32'h0;
      cluster_base_addr[31:22] = base_addr_i;
  end

  localparam int unsigned N_RULES = 4;
  pulp_cluster_package::addr_map_rule_t [N_RULES-1:0] addr_map;


  assign addr_map[0] = '{ // TCDM
    idx:  0,
    start_addr: cluster_base_addr,
    end_addr:   cluster_base_addr + TCDM_SIZE - 1
  };
  assign addr_map[1] = '{ // Peripherals
    idx:  1,
    start_addr: cluster_base_addr + 32'h0020_0000,
    end_addr:   cluster_base_addr + 32'h0040_0000 -1
  };
  assign addr_map[2] = '{ // everything above cluster to ext_slave
    idx:  2,
    start_addr: cluster_base_addr + 32'h0040_0000,
    end_addr:   32'hFFFF_FFFF
  };

  assign addr_map[3] = '{ // everything below cluster to ext_slave
    idx:  2,
    start_addr: 32'h0000_0000,
    end_addr:   cluster_base_addr - 1
  };

  localparam int unsigned MAX_TXNS_PER_SLV_PORT = (DMA_NB_OUTSND_BURSTS > NB_CORES) ?
                                                    DMA_NB_OUTSND_BURSTS : NB_CORES;


    localparam xbar_cfg_t AXI_XBAR_CFG = '{
                                                    NoSlvPorts: NB_SLAVE,
                                                    NoMstPorts: NB_MASTER,
                                                    MaxMstTrans: MAX_TXNS_PER_SLV_PORT,       //The TCDM ports do not support
                                                    //outstanding transactiions anyways
                                                    MaxSlvTrans: DMA_NB_OUTSND_BURSTS + NB_CORES,       //Allow up to 4 in-flight transactions
                                                    //per slave port
                                                    FallThrough: 1'b0,       //Use the reccomended default config
                                                    LatencyMode: axi_pkg::NO_LATENCY, // CUT_ALL_AX | axi_pkg::DemuxW,
                                                    AxiIdWidthSlvPorts: AXI_ID_IN_WIDTH,
                                                    AxiIdUsedSlvPorts: 4,
                                                    UniqueIds: 1'b0,
                                                    AxiAddrWidth: AXI_ADDR_WIDTH,
                                                    AxiDataWidth: AXI_DATA_WIDTH,
                                                    NoAddrRules: N_RULES
                                                    };


  axi_xbar_intf #(
    .AXI_USER_WIDTH         ( AXI_USER_WIDTH                        ),
    .Cfg                    ( AXI_XBAR_CFG                          ),
    .rule_t                 ( addr_map_rule_t                       )
  ) i_xbar (
    .clk_i,
    .rst_ni,
    .test_i                 (test_en_i),
    .slv_ports              (axi_slaves),
    .mst_ports              (axi_masters),
    .addr_map_i             (addr_map),
    .en_default_mst_port_i  ('0), // disable default master port for all slave ports
    .default_mst_port_i     ('0)
  );

endmodule

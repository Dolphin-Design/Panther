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
 * cluster_peripherals.sv
 * Davide Rossi <davide.rossi@unibo.it>
 * Antonio Pullini <pullinia@iis.ee.ethz.ch>
 * Igor Loi <igor.loi@unibo.it>
 * Francesco Conti <fconti@iis.ee.ethz.ch>
 */

import pulp_cluster_package::*;

module cluster_peripherals
#(
  parameter int           NB_CORES             = 8,
  parameter int           NB_HW_MUT            = 1,
  parameter bit           PRIVATE_ICACHE       = 1,
  parameter int           NB_MPERIPHS          = pulp_cluster_package::NB_MPERIPHS,
  parameter int           NB_CACHE_BANKS       = 4,
  parameter int           NB_SPERIPHS          = pulp_cluster_package::NB_SPERIPHS,
  parameter int           NB_TCDM_BANKS        = 8,
  parameter logic [31:0]  ROM_BOOT_ADDR        = 32'h1A000000,
  parameter logic [31:0]  BOOT_ADDR            = 32'h1C000000,
  parameter int           EVNT_WIDTH           = 8,
  parameter int           FEATURE_DEMUX_MAPPED = 1,
  parameter int unsigned  NB_L1_CUTS           = 16,
  parameter int unsigned  RW_MARGIN_WIDTH      = 4,
  parameter HWPE_PRESENT                       = 1,
  parameter FPU                                = 0,
  parameter TCDM_SIZE                          = 32*1024,
  parameter ICACHE_SIZE                        = 4,
  parameter bit USE_REDUCED_TAG                = 0,
  parameter L2_SIZE                            = 256*1024
)
(
  input  logic                        clk_i,
  input  logic                        rst_ni,
  input  logic                        ref_clk_i,
  input  logic                        scan_ckgt_enable_i,

  input  logic                        en_sa_boot_i,
  input  logic                        fetch_en_i,
  input  logic [NB_CORES-1:0]         core_busy_i,
  output logic [NB_CORES-1:0]         core_clk_en_o,
  output logic                        fregfile_disable_o,

  input  logic                        i_isolate_cluster,

  output logic [NB_CORES-1:0][31:0]   boot_addr_o,

  output logic                        cluster_cg_en_o,

  output logic                        busy_o,

  XBAR_PERIPH_BUS.Slave               speriph_slave[NB_SPERIPHS-2:0], // SPER_EXT_ID NOT PLUGGED HERE
  XBAR_PERIPH_BUS.Slave               core_eu_direct_link[NB_CORES-1:0],

  input  logic [NB_CORES-1:0]         dma_event_i,
  input  logic [NB_CORES-1:0]         dma_irq_i,

  XBAR_PERIPH_BUS.Master              dma_cfg_master[1:0],
  input logic                         dma_cl_event_i,
  input logic                         dma_cl_irq_i,

  input logic                         dma_fc_event_i,
  input logic                         dma_fc_irq_i,

  output logic                        soc_periph_evt_ready_o,
  input  logic                        soc_periph_evt_valid_i,
  input  logic [EVNT_WIDTH-1:0]       soc_periph_evt_data_i,


  input  logic [NB_CORES-1:0]         dbg_core_halted_i,
  output logic [NB_CORES-1:0]         dbg_core_halt_o,
  output logic [NB_CORES-1:0]         dbg_core_resume_o,


  output logic                        eoc_o,
  output logic [NB_CORES-1:0]         fetch_enable_reg_o, //fetch enable driven by the internal register
  output logic [NB_CORES-1:0][4:0]    irq_id_o,
  input  logic [NB_CORES-1:0][4:0]    irq_ack_id_i,
  output logic [NB_CORES-1:0]         irq_req_o,
  input  logic [NB_CORES-1:0]         irq_ack_i,

  input  logic [NB_CORES-1:0]         dbg_req_i,
  output logic [NB_CORES-1:0]         dbg_req_o,

  // SRAM SPEED REGULATION --> TCDM
  output logic [1:0]                  TCDM_arb_policy_o,

  XBAR_PERIPH_BUS.Master              hwpe_cfg_master,
  input logic [NB_CORES-1:0][3:0]     hwpe_events_i,
  output logic                        hwpe_en_o,
  output hci_package::hci_interconnect_ctrl_t hci_ctrl_o,

  // Control ports
  SP_ICACHE_CTRL_UNIT_BUS.Master      IC_ctrl_unit_bus_main[NB_CACHE_BANKS],
  PRI_ICACHE_CTRL_UNIT_BUS.Master     IC_ctrl_unit_bus_pri[NB_CORES],
  output logic [NB_CORES-1:0]         enable_l1_l15_prefetch_o

  );

  logic                      s_timer_out_lo_event;
  logic                      s_timer_out_hi_event;
  logic                      s_timer_in_lo_event;
  logic                      s_timer_in_hi_event;

  logic [NB_CORES-1:0][31:0] s_cluster_events;
  logic [NB_CORES-1:0][3:0]  s_acc_events;
  logic [NB_CORES-1:0][1:0]  s_timer_events;
  logic [NB_CORES-1:0][1:0]  s_dma_events;

  logic [NB_CORES-1:0]  s_fetch_en_cc;

  MESSAGE_BUS eu_message_master();

  logic [NB_SPERIPH_PLUGS_EU-1:0]             eu_speriph_plug_req;
  logic [NB_SPERIPH_PLUGS_EU-1:0][31:0]       eu_speriph_plug_add;
  logic [NB_SPERIPH_PLUGS_EU-1:0]             eu_speriph_plug_we_n;
  logic [NB_SPERIPH_PLUGS_EU-1:0][31:0]       eu_speriph_plug_wdata;
  logic [NB_SPERIPH_PLUGS_EU-1:0][3:0]        eu_speriph_plug_be;
  logic [NB_SPERIPH_PLUGS_EU-1:0][NB_CORES:0] eu_speriph_plug_id;

  logic soc_periph_evt_valid, soc_periph_evt_ready;
  logic [7:0] soc_periph_evt_data;

  logic [NB_CORES-1:0]                fetch_enable_event_unit;
  logic [NB_CORES-1:0]                core_first_fetch_q, core_first_fetch_qq;
  logic [NB_CORES-1:0]                core_clk_en_eu;

  // internal speriph bus to combine multiple plugs to new event unit
  XBAR_PERIPH_BUS#(.ID_WIDTH(NB_CORES+1)) speriph_slave_eu_comb();

  // decide between common or core-specific event sources
  generate
    for (genvar I=0; I<NB_CORES; I++) begin : g_core_specific_events_sources
      assign s_cluster_events[I] = 32'd0;
      assign s_acc_events[I]     = hwpe_events_i[I];
      assign s_timer_events[I]   = {s_timer_out_hi_event,s_timer_out_lo_event};
      assign s_dma_events[I][0] = dma_event_i[I];
      assign s_dma_events[I][1] = dma_irq_i[I];
    end
  endgenerate

  generate
    for (genvar i=0; i<NB_CORES; i++) begin : g_core_reset_clock_gate
      always_ff @(posedge clk_i, negedge rst_ni) begin
        if(!rst_ni) begin
          core_first_fetch_q[i] <= 1'b0;
          core_first_fetch_qq[i] <= 1'b0;
        end else begin
          core_first_fetch_qq[i] <= core_first_fetch_q[i];
          if(!core_first_fetch_q[i]) begin
            core_first_fetch_q[i]  <= s_fetch_en_cc[i];
          end
        end
      end
      assign core_clk_en_o[i]      = (core_first_fetch_q[i])  ? core_clk_en_eu[i] : 1'b0;
      assign fetch_enable_reg_o[i] = (core_first_fetch_qq[i]) ? s_fetch_en_cc[i] : 1'b0;
    end
  endgenerate

  //********************************************************
  //************ END OF COMPUTATION UNIT *******************
  //********************************************************
  cluster_control_unit #(
    .PER_ID_WIDTH   ( NB_CORES+NB_MPERIPHS         ),
    .NB_CORES       ( NB_CORES                     ),
    .ROM_BOOT_ADDR  ( ROM_BOOT_ADDR                ),
    .BOOT_ADDR      ( BOOT_ADDR                    ),
    .HWPE_PRESENT   ( HWPE_PRESENT                 ),
    .FPU            ( FPU                          ),
    .TCDM_SIZE      ( TCDM_SIZE                    ),
    .ICACHE_SIZE    ( ICACHE_SIZE                  ),
    .USE_REDUCED_TAG( USE_REDUCED_TAG              ),
    .L2_SIZE        ( L2_SIZE                      )
    //.NB_L1_CUTS      ( NB_L1_CUTS                 ),
    //.RW_MARGIN_WIDTH ( RW_MARGIN_WIDTH            )
  ) cluster_control_unit_i (
    .clk_i          ( clk_i                        ),
    .rst_ni         ( rst_ni                       ),

    .en_sa_boot_i   ( en_sa_boot_i                 ),
    .fetch_en_i     ( fetch_en_i                   ),
    .speriph_slave  ( speriph_slave[SPER_EOC_ID]  ),

    .event_o        (                              ),
    .eoc_o          ( eoc_o                        ),

    .cluster_cg_en_o( cluster_cg_en_o              ),
    .boot_addr_o    ( boot_addr_o                  ),

    // SRAM SPEED REGULATION --> TCDM
    .hwpe_en_o      ( hwpe_en_o                    ),
    .hci_ctrl_o     ( hci_ctrl_o                   ),

    .fregfile_disable_o ( fregfile_disable_o       ),


    .core_halted_i  ( dbg_core_halted_i            ),
    .core_halt_o    ( dbg_core_halt_o              ),
    .core_resume_o  ( dbg_core_resume_o            ),

    .fetch_enable_o ( s_fetch_en_cc                ),
    .TCDM_arb_policy_o (TCDM_arb_policy_o          )
    //.rw_margin_L1_o    ( rw_margin_L1_o            )
  );



  //********************************************************
  //******************** TIMER *****************************
  //********************************************************

  cluster_timer_wrap #(
    .ID_WIDTH     ( NB_CORES+NB_MPERIPHS         )
  ) cluster_timer_wrap_i (
    .clk_i              ( clk_i                        ),
    .rst_ni             ( rst_ni                       ),
    .ref_clk_i          ( ref_clk_i                    ),
    .periph_slave       ( speriph_slave[SPER_TIMER_ID] ),
    .event_lo_i         ( 1'b0                         ),
    .event_hi_i         ( 1'b0                         ),
    .irq_lo_o           ( s_timer_out_lo_event         ),
    .irq_hi_o           ( s_timer_out_hi_event         ),
    .busy_o             ( busy_o                       ),
    .scan_ckgt_enable_i ( scan_ckgt_enable_i           )
  );

  //********************************************************
  //******************** NEW EVENT UNIT ********************
  //********************************************************

  // event unit binding
  assign eu_message_master.r_valid = 1'b1;
  assign eu_message_master.r_id    = '0;
  assign eu_message_master.r_rdata = 32'b0;
  assign eu_message_master.r_opc   = 1'b0;
  assign eu_message_master.gnt     = 1'b1;

  // With new interconnect xbar_pe, all requests to EU pass through SPER_EVENT_U_ID speriph_slave. The other plugs are tied to 0.
  generate
    for (genvar I = 1; I < NB_SPERIPH_PLUGS_EU; I++ ) begin : g_obi_req
      assign speriph_slave[SPER_EVENT_U_ID+I].gnt     =  '0;
      assign speriph_slave[SPER_EVENT_U_ID+I].r_valid =  '0;
      assign speriph_slave[SPER_EVENT_U_ID+I].r_opc   =  '0;
      assign speriph_slave[SPER_EVENT_U_ID+I].r_id    =  '0;
      assign speriph_slave[SPER_EVENT_U_ID+I].r_rdata =  32'hDEADB33F;
    end
  endgenerate

logic s_soc_periph_evt_ready;

  event_unit_top #(
    .NB_CORES     ( NB_CORES   ),
    .NB_BARR      ( NB_CORES   ),
    .NB_HW_MUT    ( NB_HW_MUT  ),
    .PER_ID_WIDTH ( NB_CORES+1 ),
    .EVNT_WIDTH   ( EVNT_WIDTH )
  ) event_unit_flex_i (
    .clk_i                  ( clk_i                  ),
    .rst_ni                 ( rst_ni                 ),
    .scan_ckgt_enable_i     ( scan_ckgt_enable_i     ),

    .acc_events_i           ( s_acc_events           ),
    .dma_events_i           ( s_dma_events           ),
    .timer_events_i         ( s_timer_events         ),
    .cluster_events_i       ( s_cluster_events       ),


    .core_irq_id_o          ( irq_id_o               ),
    .core_irq_ack_id_i      ( irq_ack_id_i           ),
    .core_irq_req_o         ( irq_req_o              ),
    .core_irq_ack_i         ( irq_ack_i              ),
    .dbg_req_i              ( dbg_req_i              ),
    .core_dbg_req_o         ( dbg_req_o              ),


    .core_busy_i            ( core_busy_i            ),
    .core_clock_en_o        ( core_clk_en_eu         ),

    .speriph_slave          ( speriph_slave[SPER_EVENT_U_ID]  ),
    .eu_direct_link         ( core_eu_direct_link    ),

    .soc_periph_evt_valid_i ( soc_periph_evt_valid_i &!i_isolate_cluster),
    .soc_periph_evt_ready_o ( s_soc_periph_evt_ready),//soc_periph_evt_ready_o ),
    .soc_periph_evt_data_i  ( soc_periph_evt_data_i  ),

    .message_master         ( eu_message_master      )
  );

  assign soc_periph_evt_ready_o = s_soc_periph_evt_ready & !i_isolate_cluster;
  //********************************************************
  //******************** icache_ctrl_unit ******************
  //********************************************************


//generate
//  if (PRIVATE_ICACHE == 1) begin : g_hier_icache_ctrl_unit_wrap   //to be integrated hier_icache

    hier_icache_ctrl_unit_wrap #(
      .NB_CACHE_BANKS ( NB_CACHE_BANKS       ),
      .NB_CORES       ( NB_CORES             ),
      .ID_WIDTH       ( NB_CORES+NB_MPERIPHS )
    ) icache_ctrl_unit_i (
      .clk_i                       (  clk_i                           ),
      .rst_ni                      (  rst_ni                          ),

      .speriph_slave               (  speriph_slave[SPER_ICACHE_CTRL] ),
      .IC_ctrl_unit_bus_pri        (  IC_ctrl_unit_bus_pri            ),
      .IC_ctrl_unit_bus_main       (  IC_ctrl_unit_bus_main           ),
      .enable_l1_l15_prefetch_o    (  enable_l1_l15_prefetch_o        )
    );

//  end else
//  begin : g_no_hier_icache_ctrl_unit_wrap
//
//    assign speriph_slave[SPER_ICACHE_CTRL].gnt     = '0;
//    assign speriph_slave[SPER_ICACHE_CTRL].r_rdata = '0;
//    assign speriph_slave[SPER_ICACHE_CTRL].r_opc   = '0;
//    assign speriph_slave[SPER_ICACHE_CTRL].r_id    = '0;
//    assign speriph_slave[SPER_ICACHE_CTRL].r_valid = '0;
//
//    assign IC_ctrl_unit_bus_pri.bypass_req         = '0;
//    assign IC_ctrl_unit_bus_pri.flush_req          = '0;
//    assign IC_ctrl_unit_bus_pri.sel_flush_req      = '0;
//    assign IC_ctrl_unit_bus_pri.sel_flush_addr     = '0;
//
//    assign IC_ctrl_unit_bus_main.bypass_req        = '0;
//    assign IC_ctrl_unit_bus_main.flush_req         = '0;
//    assign IC_ctrl_unit_bus_main.sel_flush_req     = '0;
//    assign IC_ctrl_unit_bus_main.sel_flush_addr    = '0;
//
//    assign enable_l1_l15_prefetch_o                = '0;
//  end
//endgenerate


  //********************************************************
  //******************** DMA CL CONFIG PORT ****************
  //********************************************************

  assign speriph_slave[SPER_DMA_CL_ID].gnt     = dma_cfg_master[0].gnt;
  assign speriph_slave[SPER_DMA_CL_ID].r_rdata = dma_cfg_master[0].r_rdata;
  assign speriph_slave[SPER_DMA_CL_ID].r_opc   = dma_cfg_master[0].r_opc;
  assign speriph_slave[SPER_DMA_CL_ID].r_id    = dma_cfg_master[0].r_id;
  assign speriph_slave[SPER_DMA_CL_ID].r_valid = dma_cfg_master[0].r_valid;

  assign dma_cfg_master[0].req   = speriph_slave[SPER_DMA_CL_ID].req;
  assign dma_cfg_master[0].add   = speriph_slave[SPER_DMA_CL_ID].add;
  assign dma_cfg_master[0].we_n   = speriph_slave[SPER_DMA_CL_ID].we_n;
  assign dma_cfg_master[0].wdata = speriph_slave[SPER_DMA_CL_ID].wdata;
  assign dma_cfg_master[0].be    = speriph_slave[SPER_DMA_CL_ID].be;
  assign dma_cfg_master[0].id    = speriph_slave[SPER_DMA_CL_ID].id;

  //********************************************************
  //******************** DMA FC CONFIG PORT ****************
  //********************************************************

  assign speriph_slave[SPER_DMA_FC_ID].gnt     = dma_cfg_master[1].gnt;
  assign speriph_slave[SPER_DMA_FC_ID].r_rdata = dma_cfg_master[1].r_rdata;
  assign speriph_slave[SPER_DMA_FC_ID].r_opc   = dma_cfg_master[1].r_opc;
  assign speriph_slave[SPER_DMA_FC_ID].r_id    = dma_cfg_master[1].r_id;
  assign speriph_slave[SPER_DMA_FC_ID].r_valid = dma_cfg_master[1].r_valid;

  assign dma_cfg_master[1].req   = speriph_slave[SPER_DMA_FC_ID].req;
  assign dma_cfg_master[1].add   = speriph_slave[SPER_DMA_FC_ID].add;
  assign dma_cfg_master[1].we_n   = speriph_slave[SPER_DMA_FC_ID].we_n;
  assign dma_cfg_master[1].wdata = speriph_slave[SPER_DMA_FC_ID].wdata;
  assign dma_cfg_master[1].be    = speriph_slave[SPER_DMA_FC_ID].be;
  assign dma_cfg_master[1].id    = speriph_slave[SPER_DMA_FC_ID].id;

  //********************************************************
  //******************** HW ACC  ***************************
  //********************************************************

  assign speriph_slave[SPER_HWPE_ID].gnt     = hwpe_cfg_master.gnt;
  assign speriph_slave[SPER_HWPE_ID].r_rdata = hwpe_cfg_master.r_rdata;
  assign speriph_slave[SPER_HWPE_ID].r_opc   = hwpe_cfg_master.r_opc;
  assign speriph_slave[SPER_HWPE_ID].r_id    = hwpe_cfg_master.r_id;
  assign speriph_slave[SPER_HWPE_ID].r_valid = hwpe_cfg_master.r_valid;

  assign hwpe_cfg_master.req   = speriph_slave[SPER_HWPE_ID].req;
  assign hwpe_cfg_master.add   = speriph_slave[SPER_HWPE_ID].add;
  assign hwpe_cfg_master.we_n   = speriph_slave[SPER_HWPE_ID].we_n;
  assign hwpe_cfg_master.wdata = speriph_slave[SPER_HWPE_ID].wdata;
  assign hwpe_cfg_master.be    = speriph_slave[SPER_HWPE_ID].be;
  assign hwpe_cfg_master.id    = speriph_slave[SPER_HWPE_ID].id;

  // assign speriph_slave[SPER_DECOMP_ID].gnt     = '0;
  // assign speriph_slave[SPER_DECOMP_ID].r_rdata = '0;
  // assign speriph_slave[SPER_DECOMP_ID].r_opc   = '0;
  // assign speriph_slave[SPER_DECOMP_ID].r_id    = '0;
  // assign speriph_slave[SPER_DECOMP_ID].r_valid = '0;
  per_error_plug decomp_per_error_plug_i
  (
      .i_clk        ( clk_i         ),
      .i_rst_n      ( rst_ni        ),
      .periph_slave ( speriph_slave[SPER_DECOMP_ID] )
  );


  generate
    if(FEATURE_DEMUX_MAPPED == 0) begin : g_eu_not_demux_mapped_gen
      for(genvar i=0;i< NB_CORES; i++) begin
        assign core_eu_direct_link[i].gnt     = 1'b0;
        assign core_eu_direct_link[i].r_rdata = 32'h0000_0000;
        assign core_eu_direct_link[i].r_valid = 1'b0;
        assign core_eu_direct_link[i].r_opc   = 1'b0;
      end
    end
  endgenerate

endmodule // cluster_peripherals

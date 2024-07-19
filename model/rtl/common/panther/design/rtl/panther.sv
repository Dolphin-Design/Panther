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
 * pulp_cluster.sv
 * Davide Rossi <davide.rossi@unibo.it>
 * Antonio Pullini <pullinia@iis.ee.ethz.ch>
 * Igor Loi <igor.loi@unibo.it>
 * Francesco Conti <fconti@iis.ee.ethz.ch>
 * Angelo Garofalo <angelo.garofalo@unibo.it>
 */

import pulp_cluster_package::*;
import hci_package::*;

import panther_global_config_pkg::*;

`include "axi/typedef.svh"
`include "axi/assign.svh"

module panther
(
  input                                                                            i_clk                  ,
  input                                                                            i_rst_n                ,
  input                                                                            i_ref_clk              ,

  input                                                                            i_test_mode            ,
  input                                                                            i_bist_mode            ,
  input                                                                            i_scan_ckgt_enable     ,

  input  [                    5:0 ]                                                i_cluster_id           ,
  input  [                    9:0 ]                                                i_base_addr            ,
  input                                                                            i_en_sa_boot           ,
  input                                                                            i_fetch_en             ,

  output                                                                           o_busy                 ,
  output                                                                           o_eoc                  ,

  input  [           NB_CORES-1:0 ]                                                i_dbg_irq_valid        ,

  input                                                                            i_dma_pe_evt_ack       ,
  output                                                                           o_dma_pe_evt_valid     ,

  input                                                                            i_dma_pe_irq_ack       ,
  output                                                                           o_dma_pe_irq_valid     ,

  input                                                                            i_events_valid         ,
  output                                                                           o_events_ready         ,
  input  [   EVNT_WIDTH-1:0 ]                                                      i_events_data          ,

  //***************************************************************************
  // AXI4 SLAVE
  //***************************************************************************
  // WRITE ADDRESS CHANNEL
  input                                                                            i_data_slave_aw_valid  ,
  input  [     AXI_ADDR_WIDTH-1:0 ]                                                i_data_slave_aw_addr   ,
  input  [                    2:0 ]                                                i_data_slave_aw_prot   ,
  input  [                    3:0 ]                                                i_data_slave_aw_region ,
  input  [                    7:0 ]                                                i_data_slave_aw_len    ,
  input  [                    2:0 ]                                                i_data_slave_aw_size   ,
  input  [                    1:0 ]                                                i_data_slave_aw_burst  ,
  input                                                                            i_data_slave_aw_lock   ,
  input  [                    3:0 ]                                                i_data_slave_aw_cache  ,
  input  [                    3:0 ]                                                i_data_slave_aw_qos    ,
  input  [    AXI_ID_IN_WIDTH-1:0 ]                                                i_data_slave_aw_id     ,
  input  [     AXI_USER_WIDTH-1:0 ]                                                i_data_slave_aw_user   ,
  output                                                                           o_data_slave_aw_ready  ,

  // READ ADDRESS CHANNEL
  input                                                                            i_data_slave_ar_valid  ,
  input  [     AXI_ADDR_WIDTH-1:0 ]                                                i_data_slave_ar_addr   ,
  input  [                    2:0 ]                                                i_data_slave_ar_prot   ,
  input  [                    3:0 ]                                                i_data_slave_ar_region ,
  input  [                    7:0 ]                                                i_data_slave_ar_len    ,
  input  [                    2:0 ]                                                i_data_slave_ar_size   ,
  input  [                    1:0 ]                                                i_data_slave_ar_burst  ,
  input                                                                            i_data_slave_ar_lock   ,
  input  [                    3:0 ]                                                i_data_slave_ar_cache  ,
  input  [                    3:0 ]                                                i_data_slave_ar_qos    ,
  input  [    AXI_ID_IN_WIDTH-1:0 ]                                                i_data_slave_ar_id     ,
  input  [     AXI_USER_WIDTH-1:0 ]                                                i_data_slave_ar_user   ,
  output                                                                           o_data_slave_ar_ready  ,

  // WRITE DATA CHANNEL
  input                                                                            i_data_slave_w_valid   ,
  input  [ AXI_DATA_S2C_WIDTH-1:0 ]                                                i_data_slave_w_data    ,
  input  [ AXI_STRB_S2C_WIDTH-1:0 ]                                                i_data_slave_w_strb    ,
  input  [     AXI_USER_WIDTH-1:0 ]                                                i_data_slave_w_user    ,
  input                                                                            i_data_slave_w_last    ,
  output                                                                           o_data_slave_w_ready   ,

  // READ DATA CHANNEL
  output                                                                           o_data_slave_r_valid   ,
  output [ AXI_DATA_S2C_WIDTH-1:0 ]                                                o_data_slave_r_data    ,
  output [                    1:0 ]                                                o_data_slave_r_resp    ,
  output                                                                           o_data_slave_r_last    ,
  output [    AXI_ID_IN_WIDTH-1:0 ]                                                o_data_slave_r_id      ,
  output [     AXI_USER_WIDTH-1:0 ]                                                o_data_slave_r_user    ,
  input                                                                            i_data_slave_r_ready   ,

  // WRITE RESPONSE CHANNEL
  output                                                                           o_data_slave_b_valid   ,
  output [                    1:0 ]                                                o_data_slave_b_resp    ,
  output [    AXI_ID_IN_WIDTH-1:0 ]                                                o_data_slave_b_id      ,
  output [     AXI_USER_WIDTH-1:0 ]                                                o_data_slave_b_user    ,
  input                                                                            i_data_slave_b_ready   ,

  //***************************************************************************
  // AXI4 MASTER
  //***************************************************************************
  // WRITE ADDRESS CHANNEL
  output                                                                           o_data_master_aw_valid ,
  output [     AXI_ADDR_WIDTH-1:0 ]                                                o_data_master_aw_addr  ,
  output [                    2:0 ]                                                o_data_master_aw_prot  ,
  output [                    3:0 ]                                                o_data_master_aw_region,
  output [                    7:0 ]                                                o_data_master_aw_len   ,
  output [                    2:0 ]                                                o_data_master_aw_size  ,
  output [                    1:0 ]                                                o_data_master_aw_burst ,
  output                                                                           o_data_master_aw_lock  ,
  output [                    3:0 ]                                                o_data_master_aw_cache ,
  output [                    3:0 ]                                                o_data_master_aw_qos   ,
  output [   AXI_ID_OUT_WIDTH-1:0 ]                                                o_data_master_aw_id    ,
  output [     AXI_USER_WIDTH-1:0 ]                                                o_data_master_aw_user  ,
  input                                                                            i_data_master_aw_ready ,

  // READ ADDRESS CHANNEL
  output                                                                           o_data_master_ar_valid ,
  output [     AXI_ADDR_WIDTH-1:0 ]                                                o_data_master_ar_addr  ,
  output [                    2:0 ]                                                o_data_master_ar_prot  ,
  output [                    3:0 ]                                                o_data_master_ar_region,
  output [                    7:0 ]                                                o_data_master_ar_len   ,
  output [                    2:0 ]                                                o_data_master_ar_size  ,
  output [                    1:0 ]                                                o_data_master_ar_burst ,
  output                                                                           o_data_master_ar_lock  ,
  output [                    3:0 ]                                                o_data_master_ar_cache ,
  output [                    3:0 ]                                                o_data_master_ar_qos   ,
  output [   AXI_ID_OUT_WIDTH-1:0 ]                                                o_data_master_ar_id    ,
  output [     AXI_USER_WIDTH-1:0 ]                                                o_data_master_ar_user  ,
  input                                                                            i_data_master_ar_ready ,

  // WRITE DATA CHANNEL
  output                                                                           o_data_master_w_valid  ,
  output [ AXI_DATA_C2S_WIDTH-1:0 ]                                                o_data_master_w_data   ,
  output [ AXI_STRB_C2S_WIDTH-1:0 ]                                                o_data_master_w_strb   ,
  output [     AXI_USER_WIDTH-1:0 ]                                                o_data_master_w_user   ,
  output                                                                           o_data_master_w_last   ,
  input                                                                            i_data_master_w_ready  ,

  // READ DATA CHANNEL
  input                                                                            i_data_master_r_valid  ,
  input  [ AXI_DATA_C2S_WIDTH-1:0 ]                                                i_data_master_r_data   ,
  input  [                    1:0 ]                                                i_data_master_r_resp   ,
  input                                                                            i_data_master_r_last   ,
  input  [   AXI_ID_OUT_WIDTH-1:0 ]                                                i_data_master_r_id     ,
  input  [     AXI_USER_WIDTH-1:0 ]                                                i_data_master_r_user   ,
  output                                                                           o_data_master_r_ready  ,

  // WRITE RESPONSE CHANNEL
  input                                                                            i_data_master_b_valid  ,
  input  [                    1:0 ]                                                i_data_master_b_resp   ,
  input  [   AXI_ID_OUT_WIDTH-1:0 ]                                                i_data_master_b_id     ,
  input  [     AXI_USER_WIDTH-1:0 ]                                                i_data_master_b_user   ,
  output                                                                           o_data_master_b_ready  ,

  // INSTR CACHE MASTER
  //***************************************
  // WRITE ADDRESS CHANNEL
  output                                                                           o_instr_master_aw_valid ,
  output  [      AXI_ADDR_WIDTH-1:0 ]                                              o_instr_master_aw_addr  ,
  output  [                     2:0 ]                                              o_instr_master_aw_prot  ,
  output  [                     3:0 ]                                              o_instr_master_aw_region,
  output  [                     7:0 ]                                              o_instr_master_aw_len   ,
  output  [                     2:0 ]                                              o_instr_master_aw_size  ,
  output  [                     1:0 ]                                              o_instr_master_aw_burst ,
  output                                                                           o_instr_master_aw_lock  ,
  output  [                     3:0 ]                                              o_instr_master_aw_cache ,
  output  [                     3:0 ]                                              o_instr_master_aw_qos   ,
  output  [     AXI_ID_IC_WIDTH-1:0 ]                                              o_instr_master_aw_id    ,
  output  [    AXI_USER_WIDTH-1:0   ]                                              o_instr_master_aw_user  ,
  input                                                                            i_instr_master_aw_ready ,

  // READ ADDRESS CHANNEL
  output                                                                           o_instr_master_ar_valid ,
  output  [      AXI_ADDR_WIDTH-1:0 ]                                              o_instr_master_ar_addr  ,
  output  [                     2:0 ]                                              o_instr_master_ar_prot  ,
  output  [                     3:0 ]                                              o_instr_master_ar_region,
  output  [                     7:0 ]                                              o_instr_master_ar_len   ,
  output  [                     2:0 ]                                              o_instr_master_ar_size  ,
  output  [                     1:0 ]                                              o_instr_master_ar_burst ,
  output                                                                           o_instr_master_ar_lock  ,
  output  [                     3:0 ]                                              o_instr_master_ar_cache ,
  output  [                     3:0 ]                                              o_instr_master_ar_qos   ,
  output  [     AXI_ID_IC_WIDTH-1:0 ]                                              o_instr_master_ar_id    ,
  output  [      AXI_USER_WIDTH-1:0 ]                                              o_instr_master_ar_user  ,
  input                                                                            i_instr_master_ar_ready ,

  // WRITE DATA CHANNEL
  output                                                                           o_instr_master_w_valid  ,
  output  [      AXI_INSTR_WIDTH-1:0  ]                                            o_instr_master_w_data   ,
  output  [ AXI_STRB_INSTR_WIDTH-1:0  ]                                            o_instr_master_w_strb   ,
  output  [        AXI_USER_WIDTH-1:0 ]                                            o_instr_master_w_user   ,
  output                                                                           o_instr_master_w_last   ,
  input                                                                            i_instr_master_w_ready  ,

  // READ DATA CHANNEL
  input                                                                            i_instr_master_r_valid  ,
  input   [     AXI_INSTR_WIDTH-1:0 ]                                              i_instr_master_r_data   ,
  input   [                     1:0 ]                                              i_instr_master_r_resp   ,
  input                                                                            i_instr_master_r_last   ,
  input   [     AXI_ID_IC_WIDTH-1:0 ]                                              i_instr_master_r_id     ,
  input   [      AXI_USER_WIDTH-1:0 ]                                              i_instr_master_r_user   ,
  output                                                                           o_instr_master_r_ready  ,

  // WRITE RESPONSE CHANNEL
  input                                                                            i_instr_master_b_valid  ,
  input   [                     1:0 ]                                              i_instr_master_b_resp   ,
  input   [     AXI_ID_IC_WIDTH-1:0 ]                                              i_instr_master_b_id     ,
  input   [      AXI_USER_WIDTH-1:0 ]                                              i_instr_master_b_user   ,
  output                                                                           o_instr_master_b_ready  ,

  //***************************************************************************
  // Private icache memories
  //***************************************************************************
  output [     NB_CORES*PRI_NB_WAYS*PRI_TAG_ADDR_WIDTH -1:0 ]                      o_pri_tag_addr         ,
  output [     NB_CORES*PRI_NB_WAYS                    -1:0 ]                      o_pri_tag_ce_n         ,
  output [     NB_CORES*PRI_NB_WAYS                    -1:0 ]                      o_pri_tag_we_n         ,
  output [     NB_CORES*PRI_NB_WAYS*PRI_TAG_WIDTH      -1:0 ]                      o_pri_tag_wdata        ,
  input  [     NB_CORES*PRI_NB_WAYS*PRI_TAG_WIDTH      -1:0 ]                      i_pri_tag_rdata        ,

  output [     NB_CORES*PRI_NB_WAYS*PRI_DATA_ADDR_WIDTH-1:0 ]                      o_pri_data_addr        ,
  output [     NB_CORES*PRI_NB_WAYS                    -1:0 ]                      o_pri_data_ce_n        ,
  output [     NB_CORES*PRI_NB_WAYS                    -1:0 ]                      o_pri_data_we_n        ,
  output [     NB_CORES*PRI_NB_WAYS*PRI_DATA_WIDTH     -1:0 ]                      o_pri_data_wdata       ,
  input  [     NB_CORES*PRI_NB_WAYS*PRI_DATA_WIDTH     -1:0 ]                      i_pri_data_rdata       ,

  //***************************************************************************
  // Share icache memories
  //***************************************************************************
  output [   SH_NB_BANKS           *SH_TAG_ADDR_WIDTH  -1:0 ]                      o_sh_tag_addr          ,
  output [   SH_NB_BANKS*SH_NB_WAYS                    -1:0 ]                      o_sh_tag_ce_n          ,
  output [   SH_NB_BANKS                               -1:0 ]                      o_sh_tag_we_n          ,
  output [   SH_NB_BANKS           *SH_TAG_DATA_WIDTH  -1:0 ]                      o_sh_tag_wdata         ,
  input  [   SH_NB_BANKS*SH_NB_WAYS*SH_TAG_DATA_WIDTH  -1:0 ]                      i_sh_tag_rdata         ,

  output [   SH_NB_BANKS           *SH_DATA_ADDR_WIDTH -1:0 ]                      o_sh_data_addr         ,
  output [   SH_NB_BANKS*SH_NB_WAYS                    -1:0 ]                      o_sh_data_ce_n         ,
  output [   SH_NB_BANKS                               -1:0 ]                      o_sh_data_we_n         ,
  output [   SH_NB_BANKS           *SH_DATA_BE_WIDTH   -1:0 ]                      o_sh_data_be_n         ,
  output [   SH_NB_BANKS           *SH_DATA_DATA_WIDTH -1:0 ]                      o_sh_data_wdata        ,
  input  [   SH_NB_BANKS*SH_NB_WAYS*SH_DATA_DATA_WIDTH -1:0 ]                      i_sh_data_rdata        ,

  //***************************************************************************
  // TCDM memory bank memories
  //***************************************************************************
  output [   NB_TCDM_BANKS         *ADDR_WIDTH         -1:0 ]                      o_tcdm_bank_addr       ,
  output [   NB_TCDM_BANKS                             -1:0 ]                      o_tcdm_bank_ce_n       ,
  output [   NB_TCDM_BANKS                             -1:0 ]                      o_tcdm_bank_we_n       ,
  output [   NB_TCDM_BANKS         *BE_WIDTH           -1:0 ]                      o_tcdm_bank_be_n       ,
  output [   NB_TCDM_BANKS         *DATA_WIDTH         -1:0 ]                      o_tcdm_bank_wdata      ,
  input  [   NB_TCDM_BANKS         *DATA_WIDTH         -1:0 ]                      i_tcdm_bank_rdata      ,

  output logic [      NB_CORES-1:0][PRI_NB_WAYS-1:0]                               o_pri_tag_ckgt         ,
  output logic [      NB_CORES-1:0]                                                o_pri_tagm_ckgt        ,
  output logic [      NB_CORES-1:0][PRI_NB_WAYS-1:0]                               o_pri_data_ckgt        ,
  output logic [   SH_NB_BANKS-1:0][ SH_NB_WAYS-1:0]                               o_sh_tag_ckgt          ,
  output logic [   SH_NB_BANKS-1:0]                                                o_sh_tagm_ckgt         ,
  output logic [   SH_NB_BANKS-1:0][ SH_NB_WAYS-1:0]                               o_sh_data_ckgt         ,
  output logic [ NB_TCDM_BANKS-1:0]                                                o_tcdm_ckgt

);

  localparam int AXI_DATA_INT_WIDTH = 64;
  //********************************************************
  //***************** SIGNALS DECLARATION ******************
  //********************************************************
  // CLK reset, and other control signals
  logic [NB_CORES-1:0][31:0]                                                     boot_addr                ;
  logic [NB_CORES-1:0]                                                           fetch_en_int             ;
  logic                                                                          s_rst_n                  ;
  logic                                                                          s_rst_ckg_n              ;
  logic                                                                          clk_cluster              ;
  logic [NB_CORES-1:0]                                                           core_busy                ;
  logic [NB_CORES-1:0]                                                           clk_core_en              ;
  logic [NB_CORES-1:0]                                                           fetch_enable_reg_int     ;

  // Debug
  logic [NB_CORES-1:0]                                                           dbg_core_halt            ;
  logic [NB_CORES-1:0]                                                           dbg_core_resume          ;
  logic [NB_CORES-1:0]                                                           dbg_core_halted          ;
  logic [NB_CORES-1:0]                                                           s_dbg_irq                ;
  logic [NB_CORES-1:0]                                                           s_core_dbg_irq           ;

  // Clusters
  logic                                                                          s_cluster_periphs_busy   ;
  logic                                                                          s_cluster_int_busy       ;
  logic                                                                          s_cluster_cg_en          ;
  logic                                                                          s_fregfile_disable       ;

  logic                                                                          s_incoming_req           ;
  logic                                                                          s_isolate_cluster        ;
  // AXI
  logic                                                                          s_axi2mem_busy           ;
  logic                                                                          s_per2axi_busy           ;
  logic                                                                          s_axi2per_busy           ;
  logic                                                                          s_fifo_busy              ;
  logic                                                                          s_converter_busy         ;
  logic                                                                          s_axi_busy               ;

  // DMA
  logic                                                                          s_dmac_busy              ;

  logic                                                                          s_dma_fc_event           ;
  logic                                                                          s_dma_fc_irq             ;
  logic [NB_CORES-1:0]                                                           s_dma_event              ;
  logic [NB_CORES-1:0]                                                           s_dma_irq                ;

  // HWPE
  logic                                                                          s_hwpe_en                ;
  logic [NB_CORES-1:0][3:0]                                                      s_hwpe_remap_evt         ;
  logic [NB_CORES-1:0][1:0]                                                      s_hwpe_evt               ;
  logic                                                                          s_hwpe_busy              ;

  // HCI
  hci_package::hci_interconnect_ctrl_t                                           s_hci_ctrl               ;

  // Signals Between CORE_ISLAND and INSTRUCTION CACHES
  logic [NB_CORES-1:0]                                                           instr_req                ;
  logic [NB_CORES-1:0][31:0]                                                     instr_addr               ;
  logic [NB_CORES-1:0]                                                           instr_gnt                ;
  logic [NB_CORES-1:0]                                                           instr_r_valid            ;
  logic [NB_CORES-1:0][INSTR_RDATA_WIDTH-1:0]                                    instr_r_rdata            ;

  // TDCM
  logic [1:0]                                                                    s_TCDM_arb_policy        ;
  logic                                                                          tcdm_sleep               ;

  // Interrupts
  logic [NB_CORES-1:0][4:0]                                                      irq_id                   ;
  logic [NB_CORES-1:0][4:0]                                                      irq_ack_id               ;
  logic [NB_CORES-1:0]                                                           irq_req                  ;
  logic [NB_CORES-1:0]                                                           irq_ack                  ;

  // Shared FPU Cluster
  // handshake signals
  logic [NB_CORES-1:0]                                                           s_apu_master_req         ;
  logic [NB_CORES-1:0]                                                           s_apu_master_gnt         ;
  // request channel
  logic [NB_CORES-1:0][APU_NARGS_CPU-1:0][31:0]                                  s_apu_master_operands    ;
  logic [NB_CORES-1:0][APU_WOP_CPU-1:0]                                          s_apu_master_op          ;
  logic [NB_CORES-1:0][WAPUTYPE-1:0]                                             s_apu_master_type        ;
  logic [NB_CORES-1:0][APU_NDSFLAGS_CPU-1:0]                                     s_apu_master_flags       ;
  // response channel
  logic [NB_CORES-1:0]                                                           s_apu_master_rready      ;
  logic [NB_CORES-1:0]                                                           s_apu_master_rvalid      ;
  logic [NB_CORES-1:0][31:0]                                                     s_apu_master_rdata       ;
  logic [NB_CORES-1:0][APU_NUSFLAGS_CPU-1:0]                                     s_apu_master_rflags      ;

  logic                                                                          s_special_core_icache_cfg;
  logic [NB_CORES-1:0]                                                           s_enable_l1_l15_prefetch ;

  logic [     NB_CORES-1:0 ][  PRI_NB_WAYS-1:0 ][       PRI_TAG_ADDR_WIDTH-1:0 ] w_pri_tag_addr           ;
  logic [     NB_CORES-1:0 ][  PRI_NB_WAYS-1:0 ]                                 w_pri_tag_req            ;
  logic [     NB_CORES-1:0 ][  PRI_NB_WAYS-1:0 ]                                 w_pri_tag_we             ;
  logic [     NB_CORES-1:0 ][  PRI_NB_WAYS-1:0 ][            PRI_TAG_WIDTH-1:0 ] w_pri_tag_wdata          ;
  logic [     NB_CORES-1:0 ][  PRI_NB_WAYS-1:0 ][            PRI_TAG_WIDTH-1:0 ] w_pri_tag_rdata          ;

  logic [     NB_CORES-1:0 ][  PRI_NB_WAYS-1:0 ][      PRI_DATA_ADDR_WIDTH-1:0 ] w_pri_data_addr          ;
  logic [     NB_CORES-1:0 ][  PRI_NB_WAYS-1:0 ]                                 w_pri_data_req           ;
  logic [     NB_CORES-1:0 ][  PRI_NB_WAYS-1:0 ]                                 w_pri_data_we            ;
  logic [     NB_CORES-1:0 ][  PRI_NB_WAYS-1:0 ][           PRI_DATA_WIDTH-1:0 ] w_pri_data_wdata         ;
  logic [     NB_CORES-1:0 ][  PRI_NB_WAYS-1:0 ][           PRI_DATA_WIDTH-1:0 ] w_pri_data_rdata         ;

  logic [  SH_NB_BANKS-1:0 ]                    [        SH_TAG_ADDR_WIDTH-1:0 ] w_sh_tag_addr            ;
  logic [  SH_NB_BANKS-1:0 ][   SH_NB_WAYS-1:0 ]                                 w_sh_tag_req             ;
  logic [  SH_NB_BANKS-1:0 ]                                                     w_sh_tag_we              ;
  logic [  SH_NB_BANKS-1:0 ]                    [        SH_TAG_DATA_WIDTH-1:0 ] w_sh_tag_wdata           ;
  logic [  SH_NB_BANKS-1:0 ][   SH_NB_WAYS-1:0 ][        SH_TAG_DATA_WIDTH-1:0 ] w_sh_tag_rdata           ;

  logic [  SH_NB_BANKS-1:0 ]                    [       SH_DATA_ADDR_WIDTH-1:0 ] w_sh_data_addr           ;
  logic [  SH_NB_BANKS-1:0 ][   SH_NB_WAYS-1:0 ]                                 w_sh_data_req            ;
  logic [  SH_NB_BANKS-1:0 ]                                                     w_sh_data_we             ;
  logic [  SH_NB_BANKS-1:0 ]                    [         SH_DATA_BE_WIDTH-1:0 ] w_sh_data_be             ;
  logic [  SH_NB_BANKS-1:0 ]                    [       SH_DATA_DATA_WIDTH-1:0 ] w_sh_data_wdata          ;
  logic [  SH_NB_BANKS-1:0 ][   SH_NB_WAYS-1:0 ][       SH_DATA_DATA_WIDTH-1:0 ] w_sh_data_rdata          ;

  logic [     NB_CORES-1:0 ]                                                     w_pri_tagm_req           ;
  logic [  SH_NB_BANKS-1:0 ]                                                     w_sh_tagm_req            ;

  logic                                                                          w_scan_ckgt_bist_enable  ;


//**********************************************************************************//
//  ██╗███╗   ██╗████████╗███████╗██████╗ ███████╗ █████╗  ██████╗███████╗███████╗  //
//  ██║████╗  ██║╚══██╔══╝██╔════╝██╔══██╗██╔════╝██╔══██╗██╔════╝██╔════╝██╔════╝  //
//  ██║██╔██╗ ██║   ██║   █████╗  ██████╔╝█████╗  ███████║██║     █████╗  ███████╗  //
//  ██║██║╚██╗██║   ██║   ██╔══╝  ██╔══██╗██╔══╝  ██╔══██║██║     ██╔══╝  ╚════██║  //
//  ██║██║ ╚████║   ██║   ███████╗██║  ██║██║     ██║  ██║╚██████╗███████╗███████║  //
//  ╚═╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝ ╚═════╝╚══════╝╚══════╝  //
//**********************************************************************************//

  XBAR_PERIPH_BUS#(.ID_WIDTH(NB_CORES+1)) s_xbar_speriph_bus[NB_SPERIPHS-2:0]()  ; // periph interconnect -> slave peripherals
  XBAR_PERIPH_BUS#(.ID_WIDTH(NB_CORES+1)) s_hwpe_cfg_bus()                       ; // periph interconnect -> HWPE subsystem
  XBAR_PERIPH_BUS#(.ID_WIDTH(NB_CORES+1)) s_core_periph_bus[NB_CORES-1:0]()      ; // cores -> periph interconnect
  XBAR_PERIPH_BUS#(.ID_WIDTH(NB_CORES+1)) s_periph_dma_bus[1:0]()                ; // periph interconnect -> DMA
  XBAR_TCDM_BUS                           s_debug_bus[NB_CORES-1:0]()            ; // debug
  XBAR_TCDM_BUS                           s_core_dmactrl_bus[NB_CORES-1:0]()     ; // cores -> DMA ctrl
  XBAR_PERIPH_BUS#(.ID_WIDTH(NB_CORES+1)) s_core_euctrl_bus[NB_CORES-1:0]()      ; // cores -> event unit ctrl
  XBAR_TCDM_BUS                           s_dma_plugin_xbar_bus[NB_DMAS-1:0]()   ;
  XBAR_TCDM_BUS                           s_mperiph_xbar_bus[NB_MPERIPHS-1:0]()  ; // ext -> xbar periphs FIXME                                                               //
  SP_ICACHE_CTRL_UNIT_BUS                 IC_ctrl_unit_bus_main[SH_NB_BANKS]()   ; // Interfaces between ICache - L0 - Icache_Interco and Icache_ctrl_unit
  PRI_ICACHE_CTRL_UNIT_BUS                IC_ctrl_unit_bus_pri[NB_CORES]()       ; // Interfaces between ICache - L0 - Icache_Interco and Icache_ctrl_unit

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH     ),
    .AXI_DATA_WIDTH ( AXI_DATA_INT_WIDTH ),
    .AXI_ID_WIDTH   ( AXI_ID_IC_WIDTH    ),
    .AXI_USER_WIDTH ( AXI_USER_WIDTH     )
  ) s_core_instr_bus(); // synchronous AXI interfaces at CLUSTER/SOC interface


  AXI_BUS #(
    .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH     ),
    .AXI_DATA_WIDTH ( AXI_DATA_INT_WIDTH ),
    .AXI_ID_WIDTH   ( AXI_ID_IN_WIDTH    ),
    .AXI_USER_WIDTH ( AXI_USER_WIDTH     )
  ) s_dma_ext_bus(); // synchronous AXI interfaces internal to the cluster

  hci_core_intf #(
    .DW ( 32 ),
    .AW ( 32 ),
    .OW ( 1  )
  ) s_hci_ext[NB_DMAS-1:0] (
    .clk ( clk_cluster )
  ); // ext -> log interconnect

  hci_core_intf #(
    .DW ( 32 ),
    .AW ( 32 ),
    .OW ( 1  )
  ) s_hci_dma[NB_DMAS-1:0] (
    .clk ( clk_cluster )
  ); // DMA -> log interconnect

  localparam int HCI_HWPE_DW = (NB_HWPE_PORTS==0)? 32 : NB_HWPE_PORTS*32;//Avoid DW=0 to fix compilation issue with VCS
  hci_core_intf #(
    .DW ( HCI_HWPE_DW      ),
    .AW ( 32               ),
    .OW ( 1                )
  ) s_hci_hwpe [0:0] (
    .clk ( clk_cluster )
  );  // cores & accelerators -> log interconnect

  hci_core_intf #(
    .DW ( 32 ),
    .AW ( 32 ),
    .OW ( 1  )
  ) s_hci_core [NB_CORES-1:0] (
    .clk ( clk_cluster )
  );  // cores & accelerators -> log interconnect

  hci_mem_intf #(
    .IW ( TCDM_ID_WIDTH )
  ) s_tcdm_bus_sram[NB_TCDM_BANKS-1:0](
    .clk ( clk_cluster )
  );  // log interconnect -> TCDM memory banks (SRAM)

//*******************************************************************************************************//
//   ██████╗██╗     ██╗  ██╗     █████╗ ███╗   ██╗██████╗     ██████╗ ███████╗███████╗███████╗████████╗  //
//  ██╔════╝██║     ██║ ██╔╝    ██╔══██╗████╗  ██║██╔══██╗    ██╔══██╗██╔════╝██╔════╝██╔════╝╚══██╔══╝  //
//  ██║     ██║     █████╔╝     ███████║██╔██╗ ██║██║  ██║    ██████╔╝█████╗  ███████╗█████╗     ██║     //
//  ██║     ██║     ██╔═██╗     ██╔══██║██║╚██╗██║██║  ██║    ██╔══██╗██╔══╝  ╚════██║██╔══╝     ██║     //
//  ╚██████╗███████╗██║  ██╗    ██║  ██║██║ ╚████║██████╔╝    ██║  ██║███████╗███████║███████╗   ██║     //
//   ╚═════╝╚══════╝╚═╝  ╚═╝    ╚═╝  ╚═╝╚═╝  ╚═══╝╚═════╝     ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝   ╚═╝     //
//*******************************************************************************************************//

//****************************
//** RESET GENERATOR
//****************************
  rstgen rstgen_i (
    .clk_i      ( i_clk       ),
    .rst_ni     ( i_rst_n     ),
    .test_mode_i( i_test_mode ),
    .rst_no     ( s_rst_n     ),
    .rst_ckg_no ( s_rst_ckg_n ),
    .init_no    (             )
  );

//****************************
//** CENTRALIZED CLOCK GATING
//****************************
  cluster_clock_gate #(
    .NB_CORES ( NB_CORES )
  ) u_clustercg (
    .clk_i              ( i_clk              ),
    .rstn_i             ( s_rst_ckg_n        ),
    .test_mode_i        ( i_scan_ckgt_enable ),
    .cluster_cg_en_i    ( s_cluster_cg_en    ),
    .cluster_int_busy_i ( s_cluster_int_busy ),
    .cores_busy_i       ( core_busy          ),
    .events_i           ( i_events_valid     ),
    .incoming_req_i     ( s_incoming_req     ),
    .isolate_cluster_o  ( s_isolate_cluster  ),
    .cluster_clk_o      ( clk_cluster        )
  );

  assign s_incoming_req = i_data_slave_ar_valid | i_data_slave_aw_valid | i_data_slave_w_valid;

//*********************************************************************//
//  ██████╗ ███╗   ███╗ █████╗     ██╗    ██╗██████╗  █████╗ ██████╗   //
//  ██╔══██╗████╗ ████║██╔══██╗    ██║    ██║██╔══██╗██╔══██╗██╔══██╗  //
//  ██║  ██║██╔████╔██║███████║    ██║ █╗ ██║██████╔╝███████║██████╔╝  //
//  ██║  ██║██║╚██╔╝██║██╔══██║    ██║███╗██║██╔══██╗██╔══██║██╔═══╝   //
//  ██████╔╝██║ ╚═╝ ██║██║  ██║    ╚███╔███╔╝██║  ██║██║  ██║██║       //
//  ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝     ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝       //
//*********************************************************************//

  dmac_wrap #(
    .NB_CTRLS           ( NB_CORES+2         ),
    .NB_CORES           ( NB_CORES           ),
    .NB_OUTSND_BURSTS   ( NB_OUTSND_BURSTS   ),
    .MCHAN_BURST_LENGTH ( MCHAN_BURST_LENGTH ),
    .AXI_ADDR_WIDTH     ( AXI_ADDR_WIDTH     ),
    .AXI_DATA_WIDTH     ( AXI_DATA_INT_WIDTH ),
    .AXI_ID_WIDTH       ( AXI_ID_IN_WIDTH    ),
    .AXI_USER_WIDTH     ( AXI_USER_WIDTH     ),
    .PE_ID_WIDTH        ( NB_CORES+1         ),
    .TCDM_ADD_WIDTH     ( TCDM_ADD_WIDTH     ),
    .DATA_WIDTH         ( DATA_WIDTH         ),
    .ADDR_WIDTH         ( ADDR_WIDTH         ),
    .BE_WIDTH           ( BE_WIDTH           )
  ) dmac_wrap_i (
    .i_clk              ( clk_cluster        ),
    .i_rst_n            ( s_rst_n            ),
    .i_scan_ckgt_enable ( i_scan_ckgt_enable ),
    .ctrl_slave         ( s_core_dmactrl_bus ),
    .cl_ctrl_slave      ( s_periph_dma_bus[0]),
    .fc_ctrl_slave      ( s_periph_dma_bus[1]),
    .tcdm_master        ( s_hci_dma          ),
    .ext_master         ( s_dma_ext_bus      ),
    .o_term_event_cl    ( /* Not used */     ),
    .o_term_irq_cl      ( /* Not used */     ),
    .o_term_event_pe    ( s_dma_fc_event     ),
    .o_term_irq_pe      ( s_dma_fc_irq       ),
    .o_term_event       ( s_dma_event        ),
    .o_term_irq         ( s_dma_irq          ),
    .o_busy             ( s_dmac_busy        )
  );

//**********************************************************************//
//   ██████╗██╗     ██╗   ██╗███████╗████████╗███████╗██████╗ ███████╗  //
//  ██╔════╝██║     ██║   ██║██╔════╝╚══██╔══╝██╔════╝██╔══██╗██╔════╝  //
//  ██║     ██║     ██║   ██║███████╗   ██║   █████╗  ██████╔╝███████╗  //
//  ██║     ██║     ██║   ██║╚════██║   ██║   ██╔══╝  ██╔══██╗╚════██║  //
//  ╚██████╗███████╗╚██████╔╝███████║   ██║   ███████╗██║  ██║███████║  //
//   ╚═════╝╚══════╝ ╚═════╝ ╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚══════╝  //
//**********************************************************************//

  // fetch & busy genertion
  assign s_cluster_int_busy = s_cluster_periphs_busy | s_per2axi_busy | s_axi2per_busy | s_axi2mem_busy | s_dmac_busy | s_hwpe_busy | s_fifo_busy | s_converter_busy | s_axi_busy;
  assign o_busy = s_cluster_int_busy | (|core_busy);
  assign fetch_en_int = fetch_enable_reg_int;

//****************************
//** CLUSTER MEM
//****************************

  cluster_mem_sys_wrap #(
    .NB_CORES                       (NB_CORES                      ),
    .TCDM_SIZE                      (TCDM_SIZE                     ),

    .CLUSTER_ALIAS                  (CLUSTER_ALIAS                 ),
    .CLUSTER_ALIAS_BASE             (CLUSTER_ALIAS_BASE            ),

    .NB_SPERIPHS                    (NB_SPERIPHS                   ),
    .NB_MPERIPHS                    (NB_MPERIPHS                   ),

    .NB_DMAS                        (NB_DMAS                       ),
    .NB_OUTSND_BURSTS               (NB_OUTSND_BURSTS              ),

    .HWPE_PRESENT                   (HWPE_PRESENT                  ),
    .NB_HWPE_PORTS                  (NB_HWPE_PORTS                 ),
    .NB_TCDM_BANKS                  (NB_TCDM_BANKS                 ),
    .DATA_WIDTH                     (DATA_WIDTH                    ),
    .ADDR_WIDTH                     (ADDR_WIDTH                    ),
    .BE_WIDTH                       (BE_WIDTH                      ),
    .TEST_SET_BIT                   (TEST_SET_BIT                  ),
    .ADDR_MEM_WIDTH                 (ADDR_MEM_WIDTH                ),
    .LOG_CLUSTER                    (LOG_CLUSTER                   ),
    .PE_ROUTING_LSB                 (PE_ROUTING_LSB                ),
    .USE_HETEROGENEOUS_INTERCONNECT (USE_HETEROGENEOUS_INTERCONNECT),

    .AXI_ID_IC_WIDTH                (AXI_ID_IC_WIDTH               ),
    .AXI_SYNCH_INTERF               (AXI_SYNCH_INTERF              ),
    .USE_DEDICATED_INSTR_IF         (USE_DEDICATED_INSTR_IF        ),
    .AXI_ADDR_WIDTH                 (AXI_ADDR_WIDTH                ),
    .AXI_INSTR_WIDTH                (AXI_INSTR_WIDTH               ),
    .AXI_DATA_C2S_WIDTH             (AXI_DATA_C2S_WIDTH            ),
    .AXI_DATA_S2C_WIDTH             (AXI_DATA_S2C_WIDTH            ),
    .AXI_ID_IN_WIDTH                (AXI_ID_IN_WIDTH               ),
    .AXI_ID_OUT_WIDTH               (AXI_ID_OUT_WIDTH              ),
    .AXI_USER_WIDTH                 (AXI_USER_WIDTH                ),
    .AXI_STRB_INSTR_WIDTH           (AXI_STRB_INSTR_WIDTH          ),
    .AXI_STRB_C2S_WIDTH             (AXI_STRB_C2S_WIDTH            ),
    .AXI_STRB_S2C_WIDTH             (AXI_STRB_S2C_WIDTH            )
  ) cluster_mem_sys_wrap_i (
    .i_clk                          (clk_cluster                   ),
    .i_rst_n                        (s_rst_n                       ),
    .i_test_mode                    (i_scan_ckgt_enable            ),
    .i_scan_ckgt_enable             (i_scan_ckgt_enable            ),
    .i_TCDM_arb_policy              (s_TCDM_arb_policy             ),

    .i_base_addr                    (i_base_addr                   ),

    .i_isolate_cluster              (s_isolate_cluster             ),

    .o_axi2mem_busy                 (s_axi2mem_busy                ),
    .o_axi2per_busy                 (s_axi2per_busy                ),
    .o_per2axi_busy                 (s_per2axi_busy                ),
    .o_fifo_busy                    (s_fifo_busy                   ),
    .o_converter_busy               (s_converter_busy              ),
    .o_axi_busy                     (s_axi_busy                    ),

    .i_hci_ctrl                     (s_hci_ctrl                    ),

    .hci_core                       (s_hci_core                    ),
    .hci_dma                        (s_hci_dma                     ),
    .hci_hwpe                       (s_hci_hwpe                    ),
    .tcdm_bus_sram                  (s_tcdm_bus_sram               ),
    .core_periph_bus                (s_core_periph_bus             ),
    .xbar_speriph_bus               (s_xbar_speriph_bus            ),
    .core_instr_bus                 (s_core_instr_bus              ),
    .dma_ext_bus                    (s_dma_ext_bus                 ),

    //***************************************
    // AXI4 SLAVE
    //***************************************
    // WRITE ADDRESS CHANNEL
    .data_slave_aw_valid_i          (i_data_slave_aw_valid         ),
    .data_slave_aw_addr_i           (i_data_slave_aw_addr          ),
    .data_slave_aw_prot_i           (i_data_slave_aw_prot          ),
    .data_slave_aw_region_i         (i_data_slave_aw_region        ),
    .data_slave_aw_len_i            (i_data_slave_aw_len           ),
    .data_slave_aw_size_i           (i_data_slave_aw_size          ),
    .data_slave_aw_burst_i          (i_data_slave_aw_burst         ),
    .data_slave_aw_lock_i           (i_data_slave_aw_lock          ),
    .data_slave_aw_cache_i          (i_data_slave_aw_cache         ),
    .data_slave_aw_qos_i            (i_data_slave_aw_qos           ),
    .data_slave_aw_id_i             (i_data_slave_aw_id            ),
    .data_slave_aw_user_i           (i_data_slave_aw_user          ),
    .data_slave_aw_ready_o          (o_data_slave_aw_ready         ),

    // READ ADDRESS CHANNEL
    .data_slave_ar_valid_i          (i_data_slave_ar_valid         ),
    .data_slave_ar_addr_i           (i_data_slave_ar_addr          ),
    .data_slave_ar_prot_i           (i_data_slave_ar_prot          ),
    .data_slave_ar_region_i         (i_data_slave_ar_region        ),
    .data_slave_ar_len_i            (i_data_slave_ar_len           ),
    .data_slave_ar_size_i           (i_data_slave_ar_size          ),
    .data_slave_ar_burst_i          (i_data_slave_ar_burst         ),
    .data_slave_ar_lock_i           (i_data_slave_ar_lock          ),
    .data_slave_ar_cache_i          (i_data_slave_ar_cache         ),
    .data_slave_ar_qos_i            (i_data_slave_ar_qos           ),
    .data_slave_ar_id_i             (i_data_slave_ar_id            ),
    .data_slave_ar_user_i           (i_data_slave_ar_user          ),
    .data_slave_ar_ready_o          (o_data_slave_ar_ready         ),

    // WRITE DATA CHANNEL
    .data_slave_w_valid_i           (i_data_slave_w_valid          ),
    .data_slave_w_data_i            (i_data_slave_w_data           ),
    .data_slave_w_strb_i            (i_data_slave_w_strb           ),
    .data_slave_w_user_i            (i_data_slave_w_user           ),
    .data_slave_w_last_i            (i_data_slave_w_last           ),
    .data_slave_w_ready_o           (o_data_slave_w_ready          ),

    // READ DATA CHANNEL
    .data_slave_r_valid_o           (o_data_slave_r_valid          ),
    .data_slave_r_data_o            (o_data_slave_r_data           ),
    .data_slave_r_resp_o            (o_data_slave_r_resp           ),
    .data_slave_r_last_o            (o_data_slave_r_last           ),
    .data_slave_r_id_o              (o_data_slave_r_id             ),
    .data_slave_r_user_o            (o_data_slave_r_user           ),
    .data_slave_r_ready_i           (i_data_slave_r_ready          ),

    // WRITE RESPONSE CHANNEL
    .data_slave_b_valid_o           (o_data_slave_b_valid          ),
    .data_slave_b_resp_o            (o_data_slave_b_resp           ),
    .data_slave_b_id_o              (o_data_slave_b_id             ),
    .data_slave_b_user_o            (o_data_slave_b_user           ),
    .data_slave_b_ready_i           (i_data_slave_b_ready          ),

    //***************************************
    // AXI4 MASTER
    //***************************************
    // WRITE ADDRESS CHANNEL
    .data_master_aw_valid_o         (o_data_master_aw_valid        ),
    .data_master_aw_addr_o          (o_data_master_aw_addr         ),
    .data_master_aw_prot_o          (o_data_master_aw_prot         ),
    .data_master_aw_region_o        (o_data_master_aw_region       ),
    .data_master_aw_len_o           (o_data_master_aw_len          ),
    .data_master_aw_size_o          (o_data_master_aw_size         ),
    .data_master_aw_burst_o         (o_data_master_aw_burst        ),
    .data_master_aw_lock_o          (o_data_master_aw_lock         ),
    .data_master_aw_cache_o         (o_data_master_aw_cache        ),
    .data_master_aw_qos_o           (o_data_master_aw_qos          ),
    .data_master_aw_id_o            (o_data_master_aw_id           ),
    .data_master_aw_user_o          (o_data_master_aw_user         ),
    .data_master_aw_ready_i         (i_data_master_aw_ready        ),

    // READ ADDRESS CHANNEL
    .data_master_ar_valid_o         (o_data_master_ar_valid        ),
    .data_master_ar_addr_o          (o_data_master_ar_addr         ),
    .data_master_ar_prot_o          (o_data_master_ar_prot         ),
    .data_master_ar_region_o        (o_data_master_ar_region       ),
    .data_master_ar_len_o           (o_data_master_ar_len          ),
    .data_master_ar_size_o          (o_data_master_ar_size         ),
    .data_master_ar_burst_o         (o_data_master_ar_burst        ),
    .data_master_ar_lock_o          (o_data_master_ar_lock         ),
    .data_master_ar_cache_o         (o_data_master_ar_cache        ),
    .data_master_ar_qos_o           (o_data_master_ar_qos          ),
    .data_master_ar_id_o            (o_data_master_ar_id           ),
    .data_master_ar_user_o          (o_data_master_ar_user         ),
    .data_master_ar_ready_i         (i_data_master_ar_ready        ),

    // WRITE DATA CHANNEL
    .data_master_w_valid_o          (o_data_master_w_valid         ),
    .data_master_w_data_o           (o_data_master_w_data          ),
    .data_master_w_strb_o           (o_data_master_w_strb          ),
    .data_master_w_user_o           (o_data_master_w_user          ),
    .data_master_w_last_o           (o_data_master_w_last          ),
    .data_master_w_ready_i          (i_data_master_w_ready         ),

    // READ DATA CHANNEL
    .data_master_r_valid_i          (i_data_master_r_valid         ),
    .data_master_r_data_i           (i_data_master_r_data          ),
    .data_master_r_resp_i           (i_data_master_r_resp          ),
    .data_master_r_last_i           (i_data_master_r_last          ),
    .data_master_r_id_i             (i_data_master_r_id            ),
    .data_master_r_user_i           (i_data_master_r_user          ),
    .data_master_r_ready_o          (o_data_master_r_ready         ),

    // WRITE RESPONSE CHANNEL
    .data_master_b_valid_i          (i_data_master_b_valid         ),
    .data_master_b_resp_i           (i_data_master_b_resp          ),
    .data_master_b_id_i             (i_data_master_b_id            ),
    .data_master_b_user_i           (i_data_master_b_user          ),
    .data_master_b_ready_o          (o_data_master_b_ready         ),

    //***************************************
    // INSTR MASTER
    //***************************************
    // WRITE ADDRESS CHANNEL
    .instr_master_aw_valid_o         (o_instr_master_aw_valid        ),
    .instr_master_aw_addr_o          (o_instr_master_aw_addr         ),
    .instr_master_aw_prot_o          (o_instr_master_aw_prot         ),
    .instr_master_aw_region_o        (o_instr_master_aw_region       ),
    .instr_master_aw_len_o           (o_instr_master_aw_len          ),
    .instr_master_aw_size_o          (o_instr_master_aw_size         ),
    .instr_master_aw_burst_o         (o_instr_master_aw_burst        ),
    .instr_master_aw_lock_o          (o_instr_master_aw_lock         ),
    .instr_master_aw_cache_o         (o_instr_master_aw_cache        ),
    .instr_master_aw_qos_o           (o_instr_master_aw_qos          ),
    .instr_master_aw_id_o            (o_instr_master_aw_id           ),
    .instr_master_aw_user_o          (o_instr_master_aw_user         ),
    .instr_master_aw_ready_i         (i_instr_master_aw_ready        ),

    // READ ADDRESS CHANNEL
    .instr_master_ar_valid_o         (o_instr_master_ar_valid        ),
    .instr_master_ar_addr_o          (o_instr_master_ar_addr         ),
    .instr_master_ar_prot_o          (o_instr_master_ar_prot         ),
    .instr_master_ar_region_o        (o_instr_master_ar_region       ),
    .instr_master_ar_len_o           (o_instr_master_ar_len          ),
    .instr_master_ar_size_o          (o_instr_master_ar_size         ),
    .instr_master_ar_burst_o         (o_instr_master_ar_burst        ),
    .instr_master_ar_lock_o          (o_instr_master_ar_lock         ),
    .instr_master_ar_cache_o         (o_instr_master_ar_cache        ),
    .instr_master_ar_qos_o           (o_instr_master_ar_qos          ),
    .instr_master_ar_id_o            (o_instr_master_ar_id           ),
    .instr_master_ar_user_o          (o_instr_master_ar_user         ),
    .instr_master_ar_ready_i         (i_instr_master_ar_ready        ),

    // WRITE DATA CHANNEL
    .instr_master_w_valid_o          (o_instr_master_w_valid         ),
    .instr_master_w_data_o           (o_instr_master_w_data          ),
    .instr_master_w_strb_o           (o_instr_master_w_strb          ),
    .instr_master_w_user_o           (o_instr_master_w_user          ),
    .instr_master_w_last_o           (o_instr_master_w_last          ),
    .instr_master_w_ready_i          (i_instr_master_w_ready         ),

    // READ DATA CHANNEL
    .instr_master_r_valid_i          (i_instr_master_r_valid         ),
    .instr_master_r_data_i           (i_instr_master_r_data          ),
    .instr_master_r_resp_i           (i_instr_master_r_resp          ),
    .instr_master_r_last_i           (i_instr_master_r_last          ),
    .instr_master_r_id_i             (i_instr_master_r_id            ),
    .instr_master_r_user_i           (i_instr_master_r_user          ),
    .instr_master_r_ready_o          (o_instr_master_r_ready         ),

    // WRITE RESPONSE CHANNEL
    .instr_master_b_valid_i          (i_instr_master_b_valid         ),
    .instr_master_b_resp_i           (i_instr_master_b_resp          ),
    .instr_master_b_id_i             (i_instr_master_b_id            ),
    .instr_master_b_user_i           (i_instr_master_b_user          ),
    .instr_master_b_ready_o          (o_instr_master_b_ready         )

  );

//****************************
//** CLUSTER PERIPHERALS
//****************************

  cluster_peripherals #(
    .NB_CORES               ( NB_CORES                           ),
    .PRIVATE_ICACHE         ( PRIVATE_ICACHE                     ),
    .NB_MPERIPHS            ( NB_MPERIPHS                        ),
    .NB_CACHE_BANKS         ( SH_NB_BANKS                        ),
    .NB_SPERIPHS            ( NB_SPERIPHS                        ),
    .NB_TCDM_BANKS          ( NB_TCDM_BANKS                      ),
    .ROM_BOOT_ADDR          ( ROM_BOOT_ADDR                      ),
    .BOOT_ADDR              ( BOOT_ADDR                          ),
    .EVNT_WIDTH             ( EVNT_WIDTH                         ),

    .NB_L1_CUTS             ( 0                                  ),
    .RW_MARGIN_WIDTH        ( 0                                  ),
    .HWPE_PRESENT           ( HWPE_PRESENT                       ),
    .FPU                    ( FPU                                ),
    .TCDM_SIZE              ( TCDM_SIZE                          ),
    .ICACHE_SIZE            ( ICACHE_SIZE                        ),
    .USE_REDUCED_TAG        ( USE_REDUCED_TAG                    ),
    .L2_SIZE                ( L2_SIZE                            )

  ) cluster_peripherals_i (

    .clk_i                    ( clk_cluster                        ),
    .rst_ni                   ( s_rst_n                            ),
    .ref_clk_i                ( i_ref_clk                          ),
    .scan_ckgt_enable_i       ( i_scan_ckgt_enable                 ),
    .busy_o                   ( s_cluster_periphs_busy             ),

    .en_sa_boot_i             ( i_en_sa_boot                       ),
    .fetch_en_i               ( i_fetch_en                         ),
    .boot_addr_o              ( boot_addr                          ),
    .core_busy_i              ( core_busy                          ),
    .core_clk_en_o            ( clk_core_en                        ),

    .i_isolate_cluster        ( s_isolate_cluster                  ),

    .speriph_slave            ( s_xbar_speriph_bus                 ),
    .core_eu_direct_link      ( s_core_euctrl_bus                  ),

    .dma_cfg_master           ( s_periph_dma_bus                   ),

    .dma_cl_event_i           ( 1'b0                               ),
    .dma_cl_irq_i             ( 1'b0                               ),
    .dma_event_i              ( s_dma_event                        ),
    .dma_irq_i                ( s_dma_irq                          ),

    .dma_fc_event_i           ( 1'b0                               ),
    .dma_fc_irq_i             ( 1'b0                               ),

    .soc_periph_evt_ready_o   ( o_events_ready                     ),
    .soc_periph_evt_valid_i   ( i_events_valid                     ),
    .soc_periph_evt_data_i    ( i_events_data                      ),

    .dbg_core_halt_o          ( dbg_core_halt                      ),
    .dbg_core_halted_i        ( dbg_core_halted                    ),
    .dbg_core_resume_o        ( dbg_core_resume                    ),

    .eoc_o                    ( o_eoc                              ),
    .cluster_cg_en_o          ( s_cluster_cg_en                    ),
    .fetch_enable_reg_o       ( fetch_enable_reg_int               ),
    .irq_id_o                 ( irq_id                             ),
    .irq_ack_id_i             ( irq_ack_id                         ),
    .irq_req_o                ( irq_req                            ),
    .irq_ack_i                ( irq_ack                            ),
    .dbg_req_i                ( s_dbg_irq                          ),
    .dbg_req_o                ( s_core_dbg_irq                     ),

    .fregfile_disable_o       ( s_fregfile_disable                 ),

    .TCDM_arb_policy_o        ( s_TCDM_arb_policy                  ),

    .hwpe_cfg_master          ( s_hwpe_cfg_bus                     ),
    .hwpe_events_i            ( s_hwpe_remap_evt                   ),
    .hwpe_en_o                ( s_hwpe_en                          ),
    .hci_ctrl_o               ( s_hci_ctrl                         ),
    .IC_ctrl_unit_bus_main    ( IC_ctrl_unit_bus_main              ),
    .IC_ctrl_unit_bus_pri     ( IC_ctrl_unit_bus_pri               ),
    .enable_l1_l15_prefetch_o ( s_enable_l1_l15_prefetch           )

  );

//***********************************************
//   ██████╗ ██████╗ ██████╗ ███████╗███████╗  //
//  ██╔════╝██╔═══██╗██╔══██╗██╔════╝██╔════╝  //
//  ██║     ██║   ██║██████╔╝█████╗  ███████╗  //
//  ██║     ██║   ██║██╔══██╗██╔══╝  ╚════██║  //
//  ╚██████╗╚██████╔╝██║  ██║███████╗███████║  //
//   ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝  //
//***********************************************

  generate
    for (genvar i=0; i<NB_CORES; i++) begin : g_core

      pulp_sync dbg_irq_sync (
        .clk_i                 (clk_cluster               ),
        .rstn_i                (s_rst_n                   ),
        .serial_i              (i_dbg_irq_valid[i]        ),
        .serial_o              (s_dbg_irq[i]              )
      );

      core_region #(
        .NB_CORES              ( NB_CORES                 ),
        .CORE_ID               ( i                        ),
        .ADDR_WIDTH            ( 32                       ),
        .DATA_WIDTH            ( 32                       ),
        .INSTR_RDATA_WIDTH     ( INSTR_RDATA_WIDTH        ),
        .CLUSTER_ALIAS         ( CLUSTER_ALIAS            ),
        .CLUSTER_ALIAS_BASE    ( CLUSTER_ALIAS_BASE       ),
        .REMAP_ADDRESS         ( REMAP_ADDRESS            ),
        .APU_NARGS_CPU         ( APU_NARGS_CPU            ),
        .APU_WOP_CPU           ( APU_WOP_CPU              ),
        .WAPUTYPE              ( WAPUTYPE                 ),
        .APU_NDSFLAGS_CPU      ( APU_NDSFLAGS_CPU         ),
        .APU_NUSFLAGS_CPU      ( APU_NUSFLAGS_CPU         ),

        .FPU                   ( FPU                      ),
        .FPU_ADDMUL_LAT        ( FPU_ADDMUL_LAT           ),
        .FPU_OTHERS_LAT        ( FPU_OTHERS_LAT           ),
        .FP_DIVSQRT            ( CLUST_FP_DIVSQRT         ),
        .SHARED_FP             ( CLUST_SHARED_FP          ),
        .SHARED_FP_DIVSQRT     ( CLUST_SHARED_FP_DIVSQRT  ),
        .DEBUG_FETCH_INTERFACE ( DEBUG_FETCH_INTERFACE    )
      ) core_region_i (
        .clk_i                 ( clk_cluster              ),
        .rst_ni                ( s_rst_n                  ),
        .base_addr_i           ( i_base_addr              ),

        .cluster_id_i          ( i_cluster_id             ),
        .clock_en_i            ( clk_core_en[i]           ),
        .fetch_en_i            ( fetch_en_int[i]          ),

        .boot_addr_i           ( boot_addr[i]             ),
        .debug_req_i           ( s_core_dbg_irq[i]        ),
        .dm_halt_addr_i        ( DM_HALT_ADDR             ),
        .dm_exception_addr_i   ( DM_EXCEPTION_ADDR        ),

        .irq_id_i              ( irq_id[i]                ),
        .irq_ack_id_o          ( irq_ack_id[i]            ),
        .irq_req_i             ( irq_req[i]               ),
        .irq_ack_o             ( irq_ack[i]               ),

        .scan_cg_en_i          ( i_scan_ckgt_enable       ),
        .core_busy_o           ( core_busy[i]             ),

        .instr_req_o           ( instr_req[i]             ),
        .instr_gnt_i           ( instr_gnt[i]             ),
        .instr_addr_o          ( instr_addr[i]            ),
        .instr_r_rdata_i       ( instr_r_rdata[i]         ),
        .instr_r_valid_i       ( instr_r_valid[i]         ),

        .tcdm_data_master      ( s_hci_core[i]            ),

        .dma_ctrl_master       ( s_core_dmactrl_bus[i]    ),
        .eu_ctrl_master        ( s_core_euctrl_bus[i]     ),
        .periph_data_master    ( s_core_periph_bus[i]     ),

        .fregfile_disable_i    ( s_fregfile_disable       ),

        .apu_master_req_o      ( s_apu_master_req     [i] ),
        .apu_master_gnt_i      ( s_apu_master_gnt     [i] ),
        .apu_master_type_o     ( s_apu_master_type    [i] ),
        .apu_master_operands_o ( s_apu_master_operands[i] ),
        .apu_master_op_o       ( s_apu_master_op      [i] ),
        .apu_master_flags_o    ( s_apu_master_flags   [i] ),
        .apu_master_valid_i    ( s_apu_master_rvalid  [i] ),
        .apu_master_ready_o    ( s_apu_master_rready  [i] ),
        .apu_master_result_i   ( s_apu_master_rdata   [i] ),
        .apu_master_flags_i    ( s_apu_master_rflags  [i] )
      );
    end
  endgenerate

//***************************************************************************************************************************************************************************//
//  ███████╗██╗  ██╗ █████╗ ██████╗ ███████╗██████╗     ███████╗██╗  ██╗███████╗ ██████╗██╗   ██╗████████╗██╗ ██████╗ ███╗   ██╗    ██╗   ██╗███╗   ██╗██╗████████╗███████╗  //
//  ██╔════╝██║  ██║██╔══██╗██╔══██╗██╔════╝██╔══██╗    ██╔════╝╚██╗██╔╝██╔════╝██╔════╝██║   ██║╚══██╔══╝██║██╔═══██╗████╗  ██║    ██║   ██║████╗  ██║██║╚══██╔══╝██╔════╝  //
//  ███████╗███████║███████║██████╔╝█████╗  ██║  ██║    █████╗   ╚███╔╝ █████╗  ██║     ██║   ██║   ██║   ██║██║   ██║██╔██╗ ██║    ██║   ██║██╔██╗ ██║██║   ██║   ███████╗  //
//  ╚════██║██╔══██║██╔══██║██╔══██╗██╔══╝  ██║  ██║    ██╔══╝   ██╔██╗ ██╔══╝  ██║     ██║   ██║   ██║   ██║██║   ██║██║╚██╗██║    ██║   ██║██║╚██╗██║██║   ██║   ╚════██║  //
//  ███████║██║  ██║██║  ██║██║  ██║███████╗██████╔╝    ███████╗██╔╝ ██╗███████╗╚██████╗╚██████╔╝   ██║   ██║╚██████╔╝██║ ╚████║    ╚██████╔╝██║ ╚████║██║   ██║   ███████║  //
//  ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═════╝     ╚══════╝╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝    ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝     ╚═════╝ ╚═╝  ╚═══╝╚═╝   ╚═╝   ╚══════╝  //
//***************************************************************************************************************************************************************************//

  //****************************
  //** SHARED FPU CLUSTER
  //****************************

  generate
    if(SHARED_FPU_CLUSTER == 1) begin : g_shared_fpu_cluster
      shared_fpu_cluster #(
        .NB_CORES              ( NB_CORES                   ),
        .NB_APUS               ( 1                          ),
        .NB_FPNEW              ( NB_CORES/2                 ),
        .FP_TYPE_WIDTH         ( 3                          ),

        .NB_CORE_ARGS          ( 3                          ),
        .CORE_DATA_WIDTH       ( 32                         ),
        .CORE_OPCODE_WIDTH     ( 6                          ),
        .CORE_DSFLAGS_CPU      ( 15                         ),
        .CORE_USFLAGS_CPU      ( 5                          ),

        .NB_APU_ARGS           ( 2                          ),
        .APU_OPCODE_WIDTH      ( 6                          ),
        .APU_DSFLAGS_CPU       ( 15                         ),
        .APU_USFLAGS_CPU       ( 5                          ),

        .NB_FPNEW_ARGS         ( 3                          ),
        .FPNEW_OPCODE_WIDTH    ( 6                          ),
        .FPNEW_DSFLAGS_CPU     ( 15                         ),
        .FPNEW_USFLAGS_CPU     ( 5                          ),
        .FPU_ADDMUL_LAT        ( FPU_ADDMUL_LAT             ),
        .FPU_OTHERS_LAT        ( FPU_OTHERS_LAT             ),

        .APUTYPE_ID            ( 1                          ),
        .FPNEWTYPE_ID          ( 0                          ),

        .C_FPNEW_FMTBITS       ( fpnew_pkg::FP_FORMAT_BITS  ),
        .C_FPNEW_IFMTBITS      ( fpnew_pkg::INT_FORMAT_BITS ),
        .C_ROUND_BITS          ( 3                          ),
        .C_FPNEW_OPBITS        ( fpnew_pkg::OP_BITS         ),
        .USE_FPU_OPT_ALLOC     ( "FALSE"                    ),
        .USE_FPNEW_OPT_ALLOC   ( "TRUE"                     ),
        .FPNEW_INTERCO_TYPE    ( "CUSTOM_INTERCO"           )
      ) i_shared_fpu_cluster (
        .clk                   ( clk_cluster                ),
        .rst_n                 ( s_rst_n                    ),
        .scan_ckgt_enable_i    ( i_scan_ckgt_enable         ),
        .core_slave_req_i      ( s_apu_master_req           ),
        .core_slave_gnt_o      ( s_apu_master_gnt           ),
        .core_slave_type_i     ( s_apu_master_type          ),
        .core_slave_operands_i ( s_apu_master_operands      ),
        .core_slave_op_i       ( s_apu_master_op            ),
        .core_slave_flags_i    ( s_apu_master_flags         ),
        .core_slave_rready_i   ( s_apu_master_rready        ),
        .core_slave_rvalid_o   ( s_apu_master_rvalid        ),
        .core_slave_rdata_o    ( s_apu_master_rdata         ),
        .core_slave_rflags_o   ( s_apu_master_rflags        )
      );
    end
    else begin
      assign s_apu_master_gnt    = '1;
      assign s_apu_master_rvalid = '0;
      assign s_apu_master_rdata  = '0;
      assign s_apu_master_rflags = '0;
    end
  endgenerate

//*********************************************************************************************************************************************************************//
//  ██╗  ██╗██╗    ██╗    ██████╗ ██████╗  ██████╗  ██████╗███████╗███████╗███████╗██╗███╗   ██╗ ██████╗     ███████╗███╗   ██╗ ██████╗ ██╗███╗   ██╗███████╗███████╗  //
//  ██║  ██║██║    ██║    ██╔══██╗██╔══██╗██╔═══██╗██╔════╝██╔════╝██╔════╝██╔════╝██║████╗  ██║██╔════╝     ██╔════╝████╗  ██║██╔════╝ ██║████╗  ██║██╔════╝██╔════╝  //
//  ███████║██║ █╗ ██║    ██████╔╝██████╔╝██║   ██║██║     █████╗  ███████╗███████╗██║██╔██╗ ██║██║  ███╗    █████╗  ██╔██╗ ██║██║  ███╗██║██╔██╗ ██║█████╗  ███████╗  //
//  ██╔══██║██║███╗██║    ██╔═══╝ ██╔══██╗██║   ██║██║     ██╔══╝  ╚════██║╚════██║██║██║╚██╗██║██║   ██║    ██╔══╝  ██║╚██╗██║██║   ██║██║██║╚██╗██║██╔══╝  ╚════██║  //
//  ██║  ██║╚███╔███╔╝    ██║     ██║  ██║╚██████╔╝╚██████╗███████╗███████║███████║██║██║ ╚████║╚██████╔╝    ███████╗██║ ╚████║╚██████╔╝██║██║ ╚████║███████╗███████║  //
//  ╚═╝  ╚═╝ ╚══╝╚══╝     ╚═╝     ╚═╝  ╚═╝ ╚═════╝  ╚═════╝╚══════╝╚══════╝╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝     ╚══════╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝  //
//*********************************************************************************************************************************************************************//

  generate
    if(HWPE_PRESENT == 1) begin : g_hwpe
      hwpe_subsystem #(
        .N_CORES           ( NB_CORES             ),
        .N_MASTER_PORT     ( NB_HWPE_PORTS        ),
        .ID_WIDTH          ( NB_CORES+NB_MPERIPHS )
      ) hwpe_subsystem_i (
        .clk               ( clk_cluster          ),
        .rst_n             ( s_rst_n              ),
        .test_mode         ( i_scan_ckgt_enable   ),
        .hwpe_xbar_master  ( s_hci_hwpe [0]       ),
        .hwpe_cfg_slave    ( s_hwpe_cfg_bus       ),
        .evt_o             ( s_hwpe_evt           ),
        .busy_o            ( s_hwpe_busy          )
      );
    end
    else begin : no_hwpe_gen
      per_error_plug per_error_plug_i
      (
        .i_clk        ( clk_cluster    ),
        .i_rst_n      ( s_rst_n        ),
        .periph_slave ( s_hwpe_cfg_bus )
      );

      assign s_hci_hwpe[0].req      = '0;
      assign s_hci_hwpe[0].add      = '0;
      assign s_hci_hwpe[0].we_n     = '1;
      assign s_hci_hwpe[0].data     = '0;
      assign s_hci_hwpe[0].be       = '0;
      assign s_hci_hwpe[0].boffs    = '0;
      assign s_hci_hwpe[0].user     = '0;
      assign s_hci_hwpe[0].lrdy     = '1;
      assign s_hwpe_busy            = '0;
      assign s_hwpe_evt             = '0;
    end
  endgenerate

  generate
    for( genvar i = 0 ; i < NB_CORES ; i++ ) begin : g_hwpe_event_interrupt
      assign s_hwpe_remap_evt[i][3:2] = '0;
      assign s_hwpe_remap_evt[i][1:0] = s_hwpe_evt[i];
    end
  endgenerate

//**************************************************************************************************************************************//
//  ██╗  ██╗██╗███████╗██████╗  █████╗ ██████╗  ██████╗██╗  ██╗██╗ ██████╗ █████╗ ██╗          ██████╗ █████╗  ██████╗██╗  ██╗███████╗  //
//  ██║  ██║██║██╔════╝██╔══██╗██╔══██╗██╔══██╗██╔════╝██║  ██║██║██╔════╝██╔══██╗██║         ██╔════╝██╔══██╗██╔════╝██║  ██║██╔════╝  //
//  ███████║██║█████╗  ██████╔╝███████║██████╔╝██║     ███████║██║██║     ███████║██║         ██║     ███████║██║     ███████║█████╗    //
//  ██╔══██║██║██╔══╝  ██╔══██╗██╔══██║██╔══██╗██║     ██╔══██║██║██║     ██╔══██║██║         ██║     ██╔══██║██║     ██╔══██║██╔══╝    //
//  ██║  ██║██║███████╗██║  ██║██║  ██║██║  ██║╚██████╗██║  ██║██║╚██████╗██║  ██║███████╗    ╚██████╗██║  ██║╚██████╗██║  ██║███████╗  //
//  ╚═╝  ╚═╝╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝     ╚═════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝  //
//**************************************************************************************************************************************//

  icache_hier_top #(
    .FETCH_ADDR_WIDTH         ( FETCH_ADDR_WIDTH           ),
    .PRI_FETCH_DATA_WIDTH     ( INSTR_RDATA_WIDTH          ), // Tested for 32 and 128
    .SH_FETCH_DATA_WIDTH      ( SH_FETCH_DATA_WIDTH        ),

    .NB_CORES                 ( NB_CORES                   ),
    .PRIVATE_ICACHE           ( PRIVATE_ICACHE             ),
    .HIERARCHY_ICACHE_32BIT   ( HIERARCHY_ICACHE_32BIT     ),

    .SH_NB_BANKS              ( SH_NB_BANKS                ),
    .SH_NB_WAYS               ( SH_NB_WAYS                 ),
    .SH_CACHE_SIZE            ( SH_CACHE_SIZE              ), // N*1024,  // in Byte
    .SH_CACHE_LINE            ( SH_CACHE_LINE              ), // in word of [SH_FETCH_DATA_WIDTH]
    .TAGRAM_ADDR_WIDTH        ( SH_TAG_ADDR_WIDTH          ),
    .TAGRAM_DATA_WIDTH        ( SH_TAG_DATA_WIDTH          ),
    .DATARAM_ADDR_WIDTH       ( SH_DATA_ADDR_WIDTH         ),
    .DATARAM_DATA_WIDTH       ( SH_DATA_DATA_WIDTH         ),
    .DATARAM_BE_WIDTH         ( SH_DATA_BE_WIDTH           ),

    .PRI_NB_WAYS              ( PRI_NB_WAYS                ),
    .PRI_CACHE_SIZE           ( PRI_CACHE_SIZE             ), // in Byte
    .PRI_CACHE_LINE           ( PRI_CACHE_LINE             ), // in word of [PRI_FETCH_DATA_WIDTH]
    .SCM_TAG_ADDR_WIDTH       ( PRI_TAG_ADDR_WIDTH         ),
    .TAG_WIDTH                ( PRI_TAG_WIDTH              ),
    .SCM_DATA_ADDR_WIDTH      ( PRI_DATA_ADDR_WIDTH        ),
    .DATA_WIDTH               ( PRI_DATA_WIDTH             ),

    .AXI_ID                   ( AXI_ID_IC_WIDTH            ),
    .AXI_ADDR                 ( AXI_ADDR_WIDTH             ),
    .AXI_USER                 ( AXI_USER_WIDTH             ),
    .AXI_DATA                 ( AXI_DATA_INT_WIDTH         ),

    .USE_REDUCED_TAG          ( USE_REDUCED_TAG            ), // 1 | 0
    .L2_SIZE                  ( L2_SIZE                    )  // N*1024 - Size of max(L2 ,ROM) program memory in Byte
  ) icache_top_i (
    .clk                      ( clk_cluster                ),
    .rst_n                    ( s_rst_n                    ),
    .test_en_i                ( i_scan_ckgt_enable         ),

    .fetch_req_i              ( instr_req                  ),
    .fetch_addr_i             ( instr_addr                 ),
    .fetch_gnt_o              ( instr_gnt                  ),

    .fetch_rvalid_o           ( instr_r_valid              ),
    .fetch_rdata_o            ( instr_r_rdata              ),

    .enable_l1_l15_prefetch_i ( s_enable_l1_l15_prefetch   ), // set it to 1 to use prefetch feature

    //AXI read address bus -------------------------------
    .axi_master_arid_o        ( s_core_instr_bus.ar_id     ),
    .axi_master_araddr_o      ( s_core_instr_bus.ar_addr   ),
    .axi_master_arlen_o       ( s_core_instr_bus.ar_len    ), //burst length - 1 to 16
    .axi_master_arsize_o      ( s_core_instr_bus.ar_size   ), //size of each transfer in burst
    .axi_master_arburst_o     ( s_core_instr_bus.ar_burst  ), //accept only incr burst=01
    .axi_master_arlock_o      ( s_core_instr_bus.ar_lock   ), //only normal access supported axs_awlock=00
    .axi_master_arcache_o     ( s_core_instr_bus.ar_cache  ),
    .axi_master_arprot_o      ( s_core_instr_bus.ar_prot   ),
    .axi_master_arregion_o    ( s_core_instr_bus.ar_region ),
    .axi_master_aruser_o      ( s_core_instr_bus.ar_user   ),
    .axi_master_arqos_o       ( s_core_instr_bus.ar_qos    ),
    .axi_master_arvalid_o     ( s_core_instr_bus.ar_valid  ), //master addr valid
    .axi_master_arready_i     ( s_core_instr_bus.ar_ready  ), //slave ready to accept

    //AXI BACKWARD read data bus -------------------------
    .axi_master_rid_i         ( s_core_instr_bus.r_id      ),
    .axi_master_rdata_i       ( s_core_instr_bus.r_data    ),
    .axi_master_rresp_i       ( s_core_instr_bus.r_resp    ),
    .axi_master_rlast_i       ( s_core_instr_bus.r_last    ), //last transfer in burst
    .axi_master_ruser_i       ( s_core_instr_bus.r_user    ),
    .axi_master_rvalid_i      ( s_core_instr_bus.r_valid   ), //slave data valid
    .axi_master_rready_o      ( s_core_instr_bus.r_ready   ), //master ready to accept

    // NOT USED ------------------------------------------
    .axi_master_awid_o        ( s_core_instr_bus.aw_id     ),
    .axi_master_awaddr_o      ( s_core_instr_bus.aw_addr   ),
    .axi_master_awlen_o       ( s_core_instr_bus.aw_len    ),
    .axi_master_awsize_o      ( s_core_instr_bus.aw_size   ),
    .axi_master_awburst_o     ( s_core_instr_bus.aw_burst  ),
    .axi_master_awlock_o      ( s_core_instr_bus.aw_lock   ),
    .axi_master_awcache_o     ( s_core_instr_bus.aw_cache  ),
    .axi_master_awprot_o      ( s_core_instr_bus.aw_prot   ),
    .axi_master_awregion_o    ( s_core_instr_bus.aw_region ),
    .axi_master_awuser_o      ( s_core_instr_bus.aw_user   ),
    .axi_master_awqos_o       ( s_core_instr_bus.aw_qos    ),
    .axi_master_awvalid_o     ( s_core_instr_bus.aw_valid  ),
    .axi_master_awready_i     ( s_core_instr_bus.aw_ready  ),

    .axi_master_wdata_o       ( s_core_instr_bus.w_data    ),
    .axi_master_wstrb_o       ( s_core_instr_bus.w_strb    ),
    .axi_master_wlast_o       ( s_core_instr_bus.w_last    ),
    .axi_master_wuser_o       ( s_core_instr_bus.w_user    ),
    .axi_master_wvalid_o      ( s_core_instr_bus.w_valid   ),
    .axi_master_wready_i      ( s_core_instr_bus.w_ready   ),

    .axi_master_bid_i         ( s_core_instr_bus.b_id      ),
    .axi_master_bresp_i       ( s_core_instr_bus.b_resp    ),
    .axi_master_buser_i       ( s_core_instr_bus.b_user    ),
    .axi_master_bvalid_i      ( s_core_instr_bus.b_valid   ),
    .axi_master_bready_o      ( s_core_instr_bus.b_ready   ),
    // END NOT USED --------------------------------------

    .IC_ctrl_unit_bus_pri     ( IC_ctrl_unit_bus_pri       ),
    .IC_ctrl_unit_bus_main    ( IC_ctrl_unit_bus_main      ),

    .PRI_TAG_addr_o           ( w_pri_tag_addr             ),
    .PRI_TAG_req_o            ( w_pri_tag_req              ),
    .PRI_TAG_we_o             ( w_pri_tag_we               ),
    .PRI_TAG_wdata_o          ( w_pri_tag_wdata            ),
    .PRI_TAG_rdata_i          ( w_pri_tag_rdata            ),

    .PRI_DATA_addr_o          ( w_pri_data_addr            ),
    .PRI_DATA_req_o           ( w_pri_data_req             ),
    .PRI_DATA_we_o            ( w_pri_data_we              ),
    .PRI_DATA_wdata_o         ( w_pri_data_wdata           ),
    .PRI_DATA_rdata_i         ( w_pri_data_rdata           ),

    .SH_TAG_addr_o            ( w_sh_tag_addr              ),
    .SH_TAG_req_o             ( w_sh_tag_req               ),
    .SH_TAG_write_o           ( w_sh_tag_we                ),
    .SH_TAG_wdata_o           ( w_sh_tag_wdata             ),
    .SH_TAG_rdata_i           ( w_sh_tag_rdata             ),

    .SH_DATA_addr_o           ( w_sh_data_addr             ),
    .SH_DATA_req_o            ( w_sh_data_req              ),
    .SH_DATA_write_o          ( w_sh_data_we               ),
    .SH_DATA_be_o             ( w_sh_data_be               ),
    .SH_DATA_wdata_o          ( w_sh_data_wdata            ),
    .SH_DATA_rdata_i          ( w_sh_data_rdata            )

  );

  assign s_core_instr_bus.aw_atop = 'h0; // LINT fix

  assign w_scan_ckgt_bist_enable = i_scan_ckgt_enable | i_bist_mode;

  genvar pri_i,pri_j;
  generate
      for(pri_j=0; pri_j<NB_CORES; pri_j++)
      begin : g_tag

          assign w_pri_tagm_req        [pri_j] = |w_pri_tag_req[pri_j][PRI_NB_WAYS-1:0];

          clkgating pri_tagm_ckgt (
            .i_clk        ( i_clk                            ),
            .i_test_mode  ( w_scan_ckgt_bist_enable          ),
            .i_enable     ( w_pri_tagm_req [pri_j]           ),
            .o_gated_clk  ( o_pri_tagm_ckgt[pri_j]           )
          );

          for(pri_i=0; pri_i<PRI_NB_WAYS; pri_i++)
          begin : g_tag_way

              clkgating pri_tag_ckgt (
                .i_clk        ( i_clk                            ),
                .i_test_mode  ( w_scan_ckgt_bist_enable          ),
                .i_enable     ( w_pri_tag_req [pri_j][pri_i]     ),
                .o_gated_clk  ( o_pri_tag_ckgt[pri_j][pri_i]     )
              );

              clkgating pri_data_ckgt (
                .i_clk       ( i_clk                             ),
                .i_test_mode ( w_scan_ckgt_bist_enable           ),
                .i_enable    ( w_pri_data_req [pri_j][pri_i]     ),
                .o_gated_clk ( o_pri_data_ckgt[pri_j][pri_i]     )
              );

              assign o_pri_tag_ce_n  [pri_j*PRI_NB_WAYS                    +  pri_i                                                                                            ] = ~w_pri_tag_req [pri_j][pri_i];
              assign o_pri_tag_addr  [pri_j*PRI_NB_WAYS*PRI_TAG_ADDR_WIDTH + (pri_i + 1)*PRI_TAG_ADDR_WIDTH - 1:pri_j*PRI_NB_WAYS*PRI_TAG_ADDR_WIDTH + pri_i*PRI_TAG_ADDR_WIDTH] = w_pri_tag_addr [pri_j][pri_i];
              assign o_pri_tag_we_n  [pri_j*PRI_NB_WAYS                    +  pri_i                                                                                            ] = ~w_pri_tag_we  [pri_j][pri_i];
              assign o_pri_tag_wdata [pri_j*PRI_NB_WAYS*PRI_TAG_WIDTH      + (pri_i + 1)*PRI_TAG_WIDTH - 1     :pri_j*PRI_NB_WAYS*PRI_TAG_WIDTH      + pri_i*PRI_TAG_WIDTH     ] = w_pri_tag_wdata[pri_j][pri_i];
              assign w_pri_tag_rdata [pri_j][pri_i] = i_pri_tag_rdata[pri_j*PRI_NB_WAYS*PRI_TAG_WIDTH + (pri_i + 1)*PRI_TAG_WIDTH - 1:pri_j*PRI_NB_WAYS*PRI_TAG_WIDTH + pri_i*PRI_TAG_WIDTH];

              assign o_pri_data_ce_n [pri_j*PRI_NB_WAYS                     +  pri_i                                                                                               ] = ~w_pri_data_req [pri_j][pri_i];
              assign o_pri_data_addr [pri_j*PRI_NB_WAYS*PRI_DATA_ADDR_WIDTH + (pri_i + 1)*PRI_DATA_ADDR_WIDTH - 1:pri_j*PRI_NB_WAYS*PRI_DATA_ADDR_WIDTH + pri_i*PRI_DATA_ADDR_WIDTH] = w_pri_data_addr [pri_j][pri_i];
              assign o_pri_data_we_n [pri_j*PRI_NB_WAYS                     +  pri_i                                                                                               ] = ~w_pri_data_we  [pri_j][pri_i];
              assign o_pri_data_wdata[pri_j*PRI_NB_WAYS*PRI_DATA_WIDTH      + (pri_i + 1)*PRI_DATA_WIDTH - 1     :pri_j*PRI_NB_WAYS*PRI_DATA_WIDTH      + pri_i*PRI_DATA_WIDTH     ] = w_pri_data_wdata[pri_j][pri_i];
              assign w_pri_data_rdata[pri_j][pri_i] = i_pri_data_rdata[pri_j*PRI_NB_WAYS*PRI_DATA_WIDTH + (pri_i + 1)*PRI_DATA_WIDTH - 1:pri_j*PRI_NB_WAYS*PRI_DATA_WIDTH + pri_i*PRI_DATA_WIDTH];
          end

      end
  endgenerate

  genvar sh_i, sh_j;
  generate
      for(sh_j = 0; sh_j< SH_NB_BANKS; sh_j++)
      begin : g_sh

          assign w_sh_tagm_req        [sh_j] = |w_sh_tag_req[sh_j][SH_NB_WAYS-1:0];

          clkgating sh_tagm_ckgt (
            .i_clk        ( i_clk                           ),
            .i_test_mode  ( w_scan_ckgt_bist_enable         ),
            .i_enable     ( w_sh_tagm_req [sh_j]            ),
            .o_gated_clk  ( o_sh_tagm_ckgt[sh_j]            )
          );

          assign o_sh_tag_we_n     [sh_j                                                                   ] = ~w_sh_tag_we  [sh_j];
          assign o_sh_tag_addr     [sh_j*SH_TAG_ADDR_WIDTH  +  SH_TAG_ADDR_WIDTH - 1:sh_j*SH_TAG_ADDR_WIDTH] = w_sh_tag_addr [sh_j];
          assign o_sh_tag_wdata    [sh_j*SH_TAG_DATA_WIDTH  +  SH_TAG_DATA_WIDTH - 1:sh_j*SH_TAG_DATA_WIDTH] = w_sh_tag_wdata[sh_j];

          assign o_sh_data_we_n    [sh_j                                                                    ] = ~w_sh_data_we  [sh_j];
          assign o_sh_data_addr    [sh_j*SH_DATA_ADDR_WIDTH + SH_DATA_ADDR_WIDTH - 1:sh_j*SH_DATA_ADDR_WIDTH] = w_sh_data_addr [sh_j];
          assign o_sh_data_be_n    [sh_j*SH_DATA_BE_WIDTH   +   SH_DATA_BE_WIDTH - 1:sh_j*  SH_DATA_BE_WIDTH] = ~w_sh_data_be  [sh_j];
          assign o_sh_data_wdata   [sh_j*SH_DATA_DATA_WIDTH + SH_DATA_DATA_WIDTH - 1:sh_j*SH_DATA_DATA_WIDTH] = w_sh_data_wdata[sh_j];

          for(sh_i = 0; sh_i< SH_NB_WAYS; sh_i++)
          begin : g_sh_way

              clkgating sh_tag_ckgt (
                .i_clk        ( i_clk                      ),
                .i_test_mode  ( w_scan_ckgt_bist_enable    ),
                .i_enable     ( w_sh_tag_req [sh_j][sh_i]  ),
                .o_gated_clk  ( o_sh_tag_ckgt[sh_j][sh_i]  )
              );

              clkgating sh_data_ckgt (
                .i_clk       ( i_clk                        ),
                .i_test_mode ( w_scan_ckgt_bist_enable      ),
                .i_enable    ( w_sh_data_req [sh_j][sh_i]   ),
                .o_gated_clk ( o_sh_data_ckgt[sh_j][sh_i]   )
              );

              assign o_sh_tag_ce_n     [sh_j*SH_NB_WAYS        +  sh_i                                       ] = ~w_sh_tag_req [sh_j][sh_i];
              assign w_sh_tag_rdata    [sh_j][sh_i] = i_sh_tag_rdata[sh_j*SH_NB_WAYS*SH_TAG_DATA_WIDTH + (sh_i + 1)*SH_TAG_DATA_WIDTH - 1:sh_j*SH_NB_WAYS*SH_TAG_DATA_WIDTH + sh_i*SH_TAG_DATA_WIDTH];

              assign o_sh_data_ce_n    [sh_j*SH_NB_WAYS        +  sh_i                                       ] = ~w_sh_data_req [sh_j][sh_i];
              assign w_sh_data_rdata   [sh_j][sh_i] = i_sh_data_rdata[sh_j*SH_NB_WAYS*SH_DATA_DATA_WIDTH + (sh_i + 1)*SH_DATA_DATA_WIDTH - 1:sh_j*SH_NB_WAYS*SH_DATA_DATA_WIDTH + sh_i*SH_DATA_DATA_WIDTH];
          end

      end
  endgenerate


//******************************************************************************//
//  ████████╗ ██████╗██████╗ ███╗   ███╗    ██████╗  █████╗ ███╗   ██╗██╗  ██╗  //
//  ╚══██╔══╝██╔════╝██╔══██╗████╗ ████║    ██╔══██╗██╔══██╗████╗  ██║██║ ██╔╝  //
//     ██║   ██║     ██║  ██║██╔████╔██║    ██████╔╝███████║██╔██╗ ██║█████╔╝   //
//     ██║   ██║     ██║  ██║██║╚██╔╝██║    ██╔══██╗██╔══██║██║╚██╗██║██╔═██╗   //
//     ██║   ╚██████╗██████╔╝██║ ╚═╝ ██║    ██████╔╝██║  ██║██║ ╚████║██║  ██╗  //
//     ╚═╝    ╚═════╝╚═════╝ ╚═╝     ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝  //
//******************************************************************************//

  generate
    for(genvar i = 0 ; i < NB_TCDM_BANKS ; i++) begin: g_tcdm_bank

        clkgating tdcm_ckgt (
         .i_clk       ( i_clk                   ),
         .i_test_mode ( w_scan_ckgt_bist_enable ),
         .i_enable    ( s_tcdm_bus_sram[i].req  ),
         .o_gated_clk ( o_tcdm_ckgt    [i]      )
        );

        // handshake signals
        assign o_tcdm_bank_ce_n[i]      = ~s_tcdm_bus_sram[i].req; // was inverted in tcdm bank wrap
        assign s_tcdm_bus_sram[i].gnt   = 1'b1                   ; // was always 1 in tcdm bank wrap

        // request phase payload
        assign o_tcdm_bank_addr [i*ADDR_WIDTH + ADDR_WIDTH - 1:i*ADDR_WIDTH] = s_tcdm_bus_sram [i].add ;
        assign o_tcdm_bank_we_n [i                                         ] = s_tcdm_bus_sram [i].we_n; // we_n=1'b1 for LOAD, we_n=1'b0 for STORE
        assign o_tcdm_bank_be_n [i * BE_WIDTH +   BE_WIDTH - 1:i*  BE_WIDTH] = ~s_tcdm_bus_sram[i].be  ; // was inverted in tcdm bank wrap
        assign o_tcdm_bank_wdata[i*DATA_WIDTH + DATA_WIDTH - 1:i*DATA_WIDTH] = s_tcdm_bus_sram [i].data;

        // response phase payload
        assign s_tcdm_bus_sram[i].r_data = i_tcdm_bank_rdata[i*DATA_WIDTH + DATA_WIDTH - 1:i*DATA_WIDTH];
        assign s_tcdm_bus_sram[i].r_id   = '0;
        assign s_tcdm_bus_sram[i].r_user = '0; //was not connected in tcdm bank wrap

    end
  endgenerate

//**************************************************************************************************************//
//  ███╗   ███╗██╗███████╗ ██████╗███████╗██╗     ██╗      █████╗ ███╗   ██╗███████╗ ██████╗ ██╗   ██╗███████╗  //
//  ████╗ ████║██║██╔════╝██╔════╝██╔════╝██║     ██║     ██╔══██╗████╗  ██║██╔════╝██╔═══██╗██║   ██║██╔════╝  //
//  ██╔████╔██║██║███████╗██║     █████╗  ██║     ██║     ███████║██╔██╗ ██║█████╗  ██║   ██║██║   ██║███████╗  //
//  ██║╚██╔╝██║██║╚════██║██║     ██╔══╝  ██║     ██║     ██╔══██║██║╚██╗██║██╔══╝  ██║   ██║██║   ██║╚════██║  //
//  ██║ ╚═╝ ██║██║███████║╚██████╗███████╗███████╗███████╗██║  ██║██║ ╚████║███████╗╚██████╔╝╚██████╔╝███████║  //
//  ╚═╝     ╚═╝╚═╝╚══════╝ ╚═════╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝ ╚═════╝  ╚═════╝ ╚══════╝  //
//**************************************************************************************************************//

  edge_propagator_tx ep_dma_pe_evt_i (
    .clk_i              ( i_clk              ),
    .rstn_i             ( s_rst_n            ),
    .valid_i            ( s_dma_fc_event     ),
    .ack_i              ( i_dma_pe_evt_ack   ),
    .valid_o            ( o_dma_pe_evt_valid )
  );


  edge_propagator_tx ep_dma_pe_irq_i (
    .clk_i              ( i_clk              ),
    .rstn_i             ( s_rst_n            ),
    .valid_i            ( s_dma_fc_irq       ),
    .ack_i              ( i_dma_pe_irq_ack   ),
    .valid_o            ( o_dma_pe_irq_valid )
  );

  // For clean LINT
  assign dbg_core_halted = 'h0; // LINT fix, TODO : must be connected properly

  // ***********************************************
  // Assertions about Panther User Config parameters
  // ***********************************************

  //synthesis translate_off
  initial begin: panther_user_config_assertions
    // Floating Point parameters (if FPU present)
    a_fpu_addmul_lat: assert (FPU_ADDMUL_LAT == 0 || FPU_ADDMUL_LAT == 1 || FPU_ADDMUL_LAT == 2 || FPU_ADDMUL_LAT == 3) else $fatal(1,"[INCORRECT PARAMETER SETTING] FPU_ADDMUL_LAT not equal to 0, 1, 2 or 3") ;
    a_fpu_others_lat: assert (FPU_OTHERS_LAT == 0 || FPU_OTHERS_LAT == 1 || FPU_OTHERS_LAT == 2 || FPU_OTHERS_LAT == 3) else $fatal(1,"[INCORRECT PARAMETER SETTING] FPU_OTHERS_LAT not equal to 0, 1, 2 or 3");
    a_fpu_same_lat:   assert (FPU_ADDMUL_LAT == FPU_OTHERS_LAT) else $fatal(1,"[INCORRECT PARAMETER SETTING] FPU_ADDMUL_LAT not equal to FPU_OTHERS_LAT");

    // TCDM and log interconnect parameters
    a_tcdm_size:   assert (TCDM_SIZE_KB == 32 || TCDM_SIZE_KB == 64 || TCDM_SIZE_KB == 128 || TCDM_SIZE_KB == 256) else $fatal(1,"[INCORRECT PARAMETER SETTING] TCDM_SIZE_KB not equal to 32, 64, 128 or 256 kB");

    // I$ parameters
    a_icache_size: assert (ICACHE_SIZE_KB == 4 || ICACHE_SIZE_KB == 8 || ICACHE_SIZE_KB == 16 || ICACHE_SIZE_KB == 32) else $fatal(1,"[INCORRECT PARAMETER SETTING] ICACHE_SIZE_KB not equal to 4, 8, 16 or 32 kB");
    a_use_reduced_tag: assert (USE_REDUCED_TAG == 1 || USE_REDUCED_TAG == 0) else $fatal(1,"[INCORRECT PARAMETER SETTING] USE_REDUCED_TAG not equal to 1 or 0");
    a_cache_size: assert (((USE_REDUCED_TAG == 1) && (L2_SIZE_KB > ICACHE_SIZE_KB)) || (USE_REDUCED_TAG == 0)) else $fatal(1,"[INCORRECT PARAMETER SETTING] L2_SIZE_KB must be >>> ICACHE_SIZE_KB");
    a_icache_stat: assert (ICACHE_STAT == 1 || ICACHE_STAT == 0) else $fatal(1,"[INCORRECT PARAMETER SETTING] ICACHE_STAT not equal to 0 or 1");
    a_l2_size_kb_power_of_2: assert ($onehot(L2_SIZE_KB)) else $fatal(1,"[INCORRECT PARAMETER SETTING] L2_SIZE_KB is not a power of 2");

    // AXI parameters
    a_axi_synch_interf: assert (AXI_SYNCH_INTERF == 0 || AXI_SYNCH_INTERF == 1) else $fatal(1,"[INCORRECT PARAMETER SETTING] AXI_SYNCH_INTERF not equal to 0 or 1");

    a_use_dedicated_instr_if: assert (USE_DEDICATED_INSTR_IF == 0 || USE_DEDICATED_INSTR_IF == 1) else $fatal(1,"[INCORRECT PARAMETER SETTING] USE_DEDICATED_INSTR_IF not equal to 0 or 1");

    a_axi_data_s2c_width: assert (AXI_DATA_S2C_WIDTH == 32 || AXI_DATA_S2C_WIDTH == 64)
                          else $fatal(1,"[INCORRECT PARAMETER SETTING] AXI_DATA_S2C_WIDTH not equal to 32 or 64");

    a_axi_data_c2s_width: assert (AXI_DATA_C2S_WIDTH == 32 || AXI_DATA_C2S_WIDTH == 64)
                          else $fatal(1,"[INCORRECT PARAMETER SETTING] AXI_DATA_C2S_WIDTH not equal to 32 or 64");

    a_axi_instr_c2s_width: assert (((USE_DEDICATED_INSTR_IF == 1) && (AXI_INSTR_WIDTH == 32 || AXI_INSTR_WIDTH == 64)) || (USE_DEDICATED_INSTR_IF == 0))
                          else $fatal(1,"[INCORRECT PARAMETER SETTING] AXI_INSTR_WIDTH not equal to 32 or 64");

    a_axi_id_in_width: assert (AXI_ID_IN_WIDTH >=7) else $fatal(1,"[INCORRECT PARAMETER SETTING] AXI_ID_IN_WIDTH not equal to 7 or more");

    // Events parameter
    //TODO : to check if it is necessary
    a_evnt_width: assert (EVNT_WIDTH == 4 || EVNT_WIDTH == 8 || EVNT_WIDTH == 16) else $fatal(1,"[INCORRECT PARAMETER SETTING] EVNT_WIDTH not equal to 4, 8 or 16");
  end //panther_user_config_assertions
  // synthesis translate_on

endmodule

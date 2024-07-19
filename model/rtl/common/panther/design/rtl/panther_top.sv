// Copyright 2024 Dolphin Design
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the "License");
// you may not use this file except in compliance with the License, or,
// at your option, the Apache License version 2.0.
// You may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import panther_global_config_pkg::*;

module panther_top
(
  input                                                                            i_clk                   ,
  input                                                                            i_rst_n                 ,
  input                                                                            i_ref_clk               ,

  input                                                                            i_test_mode             ,
  input                                                                            i_scan_ckgt_enable      ,

  input  [                    5:0 ]                                                i_cluster_id            ,
  input  [                    9:0 ]                                                i_base_addr             ,
  input                                                                            i_en_sa_boot            ,
  input                                                                            i_fetch_en              ,

  output                                                                           o_busy                  ,
  output                                                                           o_eoc                   ,

  input  [           NB_CORES-1:0 ]                                                i_dbg_irq_valid         ,

  input                                                                            i_dma_pe_evt_ack        ,
  output                                                                           o_dma_pe_evt_valid      ,

  input                                                                            i_dma_pe_irq_ack        ,
  output                                                                           o_dma_pe_irq_valid      ,

  input                                                                            i_events_valid          ,
  output                                                                           o_events_ready          ,
  input  [   EVNT_WIDTH-1:0 ]                                                      i_events_data           ,


  //***************************************************************************
  // AXI4 SLAVE
  //***************************************************************************
  // WRITE ADDRESS CHANNEL
  input                                                                            i_data_slave_aw_valid   ,
  input  [     AXI_ADDR_WIDTH-1:0 ]                                                i_data_slave_aw_addr    ,
  input  [                    2:0 ]                                                i_data_slave_aw_prot    ,
  input  [                    3:0 ]                                                i_data_slave_aw_region  ,
  input  [                    7:0 ]                                                i_data_slave_aw_len     ,
  input  [                    2:0 ]                                                i_data_slave_aw_size    ,
  input  [                    1:0 ]                                                i_data_slave_aw_burst   ,
  input                                                                            i_data_slave_aw_lock    ,
  input  [                    3:0 ]                                                i_data_slave_aw_cache   ,
  input  [                    3:0 ]                                                i_data_slave_aw_qos     ,
  input  [    AXI_ID_IN_WIDTH-1:0 ]                                                i_data_slave_aw_id      ,
  input  [     AXI_USER_WIDTH-1:0 ]                                                i_data_slave_aw_user    ,
  output                                                                           o_data_slave_aw_ready   ,

  // READ ADDRESS CHANNEL
  input                                                                            i_data_slave_ar_valid   ,
  input  [     AXI_ADDR_WIDTH-1:0 ]                                                i_data_slave_ar_addr    ,
  input  [                    2:0 ]                                                i_data_slave_ar_prot    ,
  input  [                    3:0 ]                                                i_data_slave_ar_region  ,
  input  [                    7:0 ]                                                i_data_slave_ar_len     ,
  input  [                    2:0 ]                                                i_data_slave_ar_size    ,
  input  [                    1:0 ]                                                i_data_slave_ar_burst   ,
  input                                                                            i_data_slave_ar_lock    ,
  input  [                    3:0 ]                                                i_data_slave_ar_cache   ,
  input  [                    3:0 ]                                                i_data_slave_ar_qos     ,
  input  [    AXI_ID_IN_WIDTH-1:0 ]                                                i_data_slave_ar_id      ,
  input  [     AXI_USER_WIDTH-1:0 ]                                                i_data_slave_ar_user    ,
  output                                                                           o_data_slave_ar_ready   ,

  // WRITE DATA CHANNEL
  input                                                                            i_data_slave_w_valid    ,
  input  [ AXI_DATA_S2C_WIDTH-1:0 ]                                                i_data_slave_w_data     ,
  input  [ AXI_STRB_S2C_WIDTH-1:0 ]                                                i_data_slave_w_strb     ,
  input  [     AXI_USER_WIDTH-1:0 ]                                                i_data_slave_w_user     ,
  input                                                                            i_data_slave_w_last     ,
  output                                                                           o_data_slave_w_ready    ,

  // READ DATA CHANNEL
  output                                                                           o_data_slave_r_valid    ,
  output [ AXI_DATA_S2C_WIDTH-1:0 ]                                                o_data_slave_r_data     ,
  output [                    1:0 ]                                                o_data_slave_r_resp     ,
  output                                                                           o_data_slave_r_last     ,
  output [    AXI_ID_IN_WIDTH-1:0 ]                                                o_data_slave_r_id       ,
  output [     AXI_USER_WIDTH-1:0 ]                                                o_data_slave_r_user     ,
  input                                                                            i_data_slave_r_ready    ,

  // WRITE RESPONSE CHANNEL
  output                                                                           o_data_slave_b_valid    ,
  output [                    1:0 ]                                                o_data_slave_b_resp     ,
  output [    AXI_ID_IN_WIDTH-1:0 ]                                                o_data_slave_b_id       ,
  output [     AXI_USER_WIDTH-1:0 ]                                                o_data_slave_b_user     ,
  input                                                                            i_data_slave_b_ready    ,


  //***************************************************************************
  // AXI4 MASTER
  //***************************************************************************
  // WRITE ADDRESS CHANNEL
  output                                                                           o_data_master_aw_valid  ,
  output [     AXI_ADDR_WIDTH-1:0 ]                                                o_data_master_aw_addr   ,
  output [                    2:0 ]                                                o_data_master_aw_prot   ,
  output [                    3:0 ]                                                o_data_master_aw_region ,
  output [                    7:0 ]                                                o_data_master_aw_len    ,
  output [                    2:0 ]                                                o_data_master_aw_size   ,
  output [                    1:0 ]                                                o_data_master_aw_burst  ,
  output                                                                           o_data_master_aw_lock   ,
  output [                    3:0 ]                                                o_data_master_aw_cache  ,
  output [                    3:0 ]                                                o_data_master_aw_qos    ,
  output [   AXI_ID_OUT_WIDTH-1:0 ]                                                o_data_master_aw_id     ,
  output [     AXI_USER_WIDTH-1:0 ]                                                o_data_master_aw_user   ,
  input                                                                            i_data_master_aw_ready  ,

  // READ ADDRESS CHANNEL
  output                                                                           o_data_master_ar_valid  ,
  output [     AXI_ADDR_WIDTH-1:0 ]                                                o_data_master_ar_addr   ,
  output [                    2:0 ]                                                o_data_master_ar_prot   ,
  output [                    3:0 ]                                                o_data_master_ar_region ,
  output [                    7:0 ]                                                o_data_master_ar_len    ,
  output [                    2:0 ]                                                o_data_master_ar_size   ,
  output [                    1:0 ]                                                o_data_master_ar_burst  ,
  output                                                                           o_data_master_ar_lock   ,
  output [                    3:0 ]                                                o_data_master_ar_cache  ,
  output [                    3:0 ]                                                o_data_master_ar_qos    ,
  output [   AXI_ID_OUT_WIDTH-1:0 ]                                                o_data_master_ar_id     ,
  output [     AXI_USER_WIDTH-1:0 ]                                                o_data_master_ar_user   ,
  input                                                                            i_data_master_ar_ready  ,

  // WRITE DATA CHANNEL
  output                                                                           o_data_master_w_valid   ,
  output [ AXI_DATA_C2S_WIDTH-1:0 ]                                                o_data_master_w_data    ,
  output [ AXI_STRB_C2S_WIDTH-1:0 ]                                                o_data_master_w_strb    ,
  output [     AXI_USER_WIDTH-1:0 ]                                                o_data_master_w_user    ,
  output                                                                           o_data_master_w_last    ,
  input                                                                            i_data_master_w_ready   ,

  // READ DATA CHANNEL
  input                                                                            i_data_master_r_valid   ,
  input  [ AXI_DATA_C2S_WIDTH-1:0 ]                                                i_data_master_r_data    ,
  input  [                    1:0 ]                                                i_data_master_r_resp    ,
  input                                                                            i_data_master_r_last    ,
  input  [   AXI_ID_OUT_WIDTH-1:0 ]                                                i_data_master_r_id      ,
  input  [     AXI_USER_WIDTH-1:0 ]                                                i_data_master_r_user    ,
  output                                                                           o_data_master_r_ready   ,

  // WRITE RESPONSE CHANNEL
  input                                                                            i_data_master_b_valid   ,
  input  [                    1:0 ]                                                i_data_master_b_resp    ,
  input  [   AXI_ID_OUT_WIDTH-1:0 ]                                                i_data_master_b_id      ,
  input  [     AXI_USER_WIDTH-1:0 ]                                                i_data_master_b_user    ,
  output                                                                           o_data_master_b_ready   ,


  // INSTR MASTER
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
  output  [    AXI_INSTR_WIDTH-1:0  ]                                              o_instr_master_w_data   ,
  output  [ AXI_STRB_C2S_WIDTH-1:0  ]                                              o_instr_master_w_strb   ,
  output  [      AXI_USER_WIDTH-1:0 ]                                              o_instr_master_w_user   ,
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
  output                                                                           o_instr_master_b_ready

);

    logic [                                  NB_CORES*PRI_NB_WAYS*PRI_TAG_ADDR_WIDTH -1:0 ]  w_pri_tag_addr        ;
    logic [                                  NB_CORES*PRI_NB_WAYS                    -1:0 ]  w_pri_tag_ce_n        ;
    logic [                                  NB_CORES*PRI_NB_WAYS                    -1:0 ]  w_pri_tag_we_n        ;
    logic [                                  NB_CORES*PRI_NB_WAYS*PRI_TAG_WIDTH      -1:0 ]  w_pri_tag_wdata       ;
    logic [                                  NB_CORES*PRI_NB_WAYS*PRI_TAG_WIDTH      -1:0 ]  w_pri_tag_rdata       ;

    logic [                                  NB_CORES*PRI_NB_WAYS*PRI_DATA_ADDR_WIDTH-1:0 ]  w_pri_data_addr       ;
    logic [                                  NB_CORES*PRI_NB_WAYS                    -1:0 ]  w_pri_data_ce_n       ;
    logic [                                  NB_CORES*PRI_NB_WAYS                    -1:0 ]  w_pri_data_we_n       ;
    logic [                                  NB_CORES*PRI_NB_WAYS*PRI_DATA_WIDTH     -1:0 ]  w_pri_data_wdata      ;
    logic [                                  NB_CORES*PRI_NB_WAYS*PRI_DATA_WIDTH     -1:0 ]  w_pri_data_rdata      ;

    logic [                                SH_NB_BANKS*SH_TAG_ADDR_WIDTH             -1:0 ]  w_sh_tag_addr         ;
    logic [                                SH_NB_BANKS*SH_NB_WAYS                    -1:0 ]  w_sh_tag_ce_n         ;
    logic [                                SH_NB_BANKS                               -1:0 ]  w_sh_tag_we_n         ;
    logic [                                SH_NB_BANKS*SH_TAG_DATA_WIDTH             -1:0 ]  w_sh_tag_wdata        ;
    logic [                                SH_NB_BANKS*SH_NB_WAYS*SH_TAG_DATA_WIDTH  -1:0 ]  w_sh_tag_rdata        ;

    logic [                                SH_NB_BANKS*SH_DATA_ADDR_WIDTH            -1:0 ]  w_sh_data_addr        ;
    logic [                                SH_NB_BANKS*SH_NB_WAYS                    -1:0 ]  w_sh_data_ce_n        ;
    logic [                                SH_NB_BANKS                               -1:0 ]  w_sh_data_we_n        ;
    logic [                                SH_NB_BANKS*SH_DATA_BE_WIDTH              -1:0 ]  w_sh_data_be_n        ;
    logic [                                SH_NB_BANKS*SH_DATA_DATA_WIDTH            -1:0 ]  w_sh_data_wdata       ;
    logic [                                SH_NB_BANKS*SH_NB_WAYS*SH_DATA_DATA_WIDTH -1:0 ]  w_sh_data_rdata       ;

    logic [                                NB_TCDM_BANKS         *ADDR_WIDTH         -1:0 ]  w_tcdm_bank_addr      ;
    logic [                                NB_TCDM_BANKS                             -1:0 ]  w_tcdm_bank_ce_n      ;
    logic [                                NB_TCDM_BANKS                             -1:0 ]  w_tcdm_bank_we_n      ;
    logic [                                NB_TCDM_BANKS         *BE_WIDTH           -1:0 ]  w_tcdm_bank_be_n      ;
    logic [                                NB_TCDM_BANKS         *DATA_WIDTH         -1:0 ]  w_tcdm_bank_wdata     ;
    logic [                                NB_TCDM_BANKS         *DATA_WIDTH         -1:0 ]  w_tcdm_bank_rdata     ;


    logic [     NB_CORES-1:0 ]  [  PRI_NB_WAYS-1:0 ]  [            PRI_TAG_ADDR_WIDTH-1:0 ]  PRI_TAG_addr          ;
    logic [     NB_CORES-1:0 ]                        [            PRI_TAG_ADDR_WIDTH-1:0 ]  PRI_TAG_addr_merged   ;
    logic [     NB_CORES-1:0 ]                                                               PRI_TAG_ce_n          ;
    logic [     NB_CORES-1:0 ]  [  PRI_NB_WAYS-1:0 ]                                         PRI_TAG_be_n          ;
    logic [     NB_CORES-1:0 ]                                                               PRI_TAG_we_n          ;
    logic [     NB_CORES-1:0 ]  [  PRI_NB_WAYS-1:0 ]  [                 PRI_TAG_WIDTH-1:0 ]  PRI_TAG_wdata         ;
    logic [     NB_CORES-1:0 ]                        [     PRI_NB_WAYS*PRI_TAG_WIDTH-1:0 ]  PRI_TAG_wdata_merged  ;
    logic [     NB_CORES-1:0 ]                        [     PRI_NB_WAYS*PRI_TAG_WIDTH-1:0 ]  PRI_TAG_rdata         ;

    logic [     NB_CORES-1:0 ]  [  PRI_NB_WAYS-1:0 ]  [           PRI_DATA_ADDR_WIDTH-1:0 ]  PRI_DATA_addr         ;
    logic [     NB_CORES-1:0 ]  [  PRI_NB_WAYS-1:0 ]                                         PRI_DATA_ce_n         ;
    logic [     NB_CORES-1:0 ]  [  PRI_NB_WAYS-1:0 ]                                         PRI_DATA_we_n         ;
    logic [     NB_CORES-1:0 ]  [  PRI_NB_WAYS-1:0 ]  [                PRI_DATA_WIDTH-1:0 ]  PRI_DATA_wdata        ;
    logic [     NB_CORES-1:0 ]  [  PRI_NB_WAYS-1:0 ]  [                PRI_DATA_WIDTH-1:0 ]  PRI_DATA_rdata        ;

    logic [  SH_NB_BANKS-1:0 ]                        [             SH_TAG_ADDR_WIDTH-1:0 ]  SH_TAG_addr           ;
    logic [  SH_NB_BANKS-1:0 ]                        [             SH_TAG_ADDR_WIDTH-1:0 ]  SH_TAG_addr_merged    ;
    logic [  SH_NB_BANKS-1:0 ]                                                               SH_TAG_ce_n           ;
    logic [  SH_NB_BANKS-1:0 ]  [   SH_NB_WAYS-1:0 ]                                         SH_TAG_be_n           ;
    logic [  SH_NB_BANKS-1:0 ]                                                               SH_TAG_we_n           ;
    logic [  SH_NB_BANKS-1:0 ]                        [             SH_TAG_DATA_WIDTH-1:0 ]  SH_TAG_wdata          ;
    logic [  SH_NB_BANKS-1:0 ]                        [  SH_NB_WAYS*SH_TAG_DATA_WIDTH-1:0 ]  SH_TAG_wdata_merged   ;
    logic [  SH_NB_BANKS-1:0 ]                        [  SH_NB_WAYS*SH_TAG_DATA_WIDTH-1:0 ]  SH_TAG_rdata          ;

    logic [  SH_NB_BANKS-1:0 ]                        [            SH_DATA_ADDR_WIDTH-1:0 ]  SH_DATA_addr          ;
    logic [  SH_NB_BANKS-1:0 ]  [   SH_NB_WAYS-1:0 ]                                         SH_DATA_ce_n          ;
    logic [  SH_NB_BANKS-1:0 ]                                                               SH_DATA_we_n          ;
    logic [  SH_NB_BANKS-1:0 ]                        [              SH_DATA_BE_WIDTH-1:0 ]  SH_DATA_be_n          ;
    logic [  SH_NB_BANKS-1:0 ]                        [            SH_DATA_DATA_WIDTH-1:0 ]  SH_DATA_wdata         ;
    logic [  SH_NB_BANKS-1:0 ]  [   SH_NB_WAYS-1:0 ]  [            SH_DATA_DATA_WIDTH-1:0 ]  SH_DATA_rdata         ;

    logic [ NB_TCDM_BANKS-1:0]                                                               TCDM_BANK_ce_n        ;
    logic [ NB_TCDM_BANKS-1:0]                        [                              31:0 ]  TCDM_BANK_addr        ;
    logic [ NB_TCDM_BANKS-1:0]                                                               TCDM_BANK_we_n        ;
    logic [ NB_TCDM_BANKS-1:0]                        [                               3:0 ]  TCDM_BANK_be_n        ;
    logic [ NB_TCDM_BANKS-1:0]                        [                              31:0 ]  TCDM_BANK_wdata       ;
    logic [ NB_TCDM_BANKS-1:0]                        [                              31:0 ]  TCDM_BANK_rdata       ;

    logic [      NB_CORES-1:0][PRI_NB_WAYS-1:0]                                              w_pri_tag_ckgt         ;
    logic [      NB_CORES-1:0]                                                               w_pri_tagm_ckgt        ;
    logic [      NB_CORES-1:0][PRI_NB_WAYS-1:0]                                              w_pri_data_ckgt        ;
    logic [   SH_NB_BANKS-1:0][ SH_NB_WAYS-1:0]                                              w_sh_tag_ckgt          ;
    logic [   SH_NB_BANKS-1:0]                                                               w_sh_tagm_ckgt         ;
    logic [   SH_NB_BANKS-1:0][ SH_NB_WAYS-1:0]                                              w_sh_data_ckgt         ;
    logic [ NB_TCDM_BANKS-1:0]                                                               w_tcdm_ckgt            ;


//**************************************************************************//
//  ██████╗ ██████╗ ██╗        ██╗ ██████╗ █████╗  ██████╗██╗  ██╗███████╗  //
//  ██╔══██╗██╔══██╗██║        ██║██╔════╝██╔══██╗██╔════╝██║  ██║██╔════╝  //
//  ██████╔╝██████╔╝██║        ██║██║     ███████║██║     ███████║█████╗    //
//  ██╔═══╝ ██╔══██╗██║        ██║██║     ██╔══██║██║     ██╔══██║██╔══╝    //
//  ██║     ██║  ██║██║███████╗██║╚██████╗██║  ██║╚██████╗██║  ██║███████╗  //
//  ╚═╝     ╚═╝  ╚═╝╚═╝╚══════╝╚═╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝  //
//**************************************************************************//

    genvar pri_i,pri_j, i;
    generate
      for(pri_j=0; pri_j<NB_CORES; pri_j++)
        begin : g_pri_nb_cores

          //****************************
          //** TAG MEMORIES
          //****************************
          assign PRI_TAG_ce_n        [pri_j] = &w_pri_tag_ce_n[(pri_j+1)*PRI_NB_WAYS-1 : pri_j*PRI_NB_WAYS];
          assign PRI_TAG_we_n        [pri_j] = &w_pri_tag_we_n[(pri_j+1)*PRI_NB_WAYS-1 : pri_j*PRI_NB_WAYS];
          for(i=0; i<PRI_NB_WAYS; i++)
            begin
              assign PRI_TAG_be_n        [pri_j][i] = w_pri_tag_ce_n[pri_j*PRI_NB_WAYS+i];
            end

          assign PRI_TAG_addr        [pri_j] = w_pri_tag_addr [(pri_j+1)*PRI_NB_WAYS*PRI_TAG_ADDR_WIDTH - 1 : pri_j*PRI_NB_WAYS*PRI_TAG_ADDR_WIDTH];
          assign PRI_TAG_addr_merged [pri_j] = PRI_TAG_addr   [pri_j][0];

          assign PRI_TAG_wdata       [pri_j] = w_pri_tag_wdata[(pri_j+1)*PRI_TAG_WIDTH - 1 : pri_j*PRI_TAG_WIDTH];
          assign PRI_TAG_wdata_merged[pri_j] = w_pri_tag_wdata[(pri_j+1)*PRI_NB_WAYS*PRI_TAG_WIDTH - 1 : pri_j*PRI_NB_WAYS*PRI_TAG_WIDTH];

          assign w_pri_tag_rdata  [(pri_j+1)*PRI_NB_WAYS*PRI_TAG_WIDTH - 1 : pri_j*PRI_NB_WAYS*PRI_TAG_WIDTH] = PRI_TAG_rdata[pri_j];

          sram_pri_tag_wrapper #(
              .ADDR_WIDTH ( PRI_TAG_ADDR_WIDTH          ),
              .DATA_WIDTH ( PRI_TAG_WIDTH*PRI_NB_WAYS   ),
              .PRI_NB_WAYS( PRI_NB_WAYS                 )
          )
          PRI_TAG_BANK (
              .CLK        ( w_pri_tagm_ckgt     [pri_j] ),
              .CEN        ( PRI_TAG_ce_n        [pri_j] ),
              .WEN        ( PRI_TAG_we_n        [pri_j] ),
              .BEN        ( PRI_TAG_be_n        [pri_j] ),
              .A          ( PRI_TAG_addr_merged [pri_j] ),
              .D          ( PRI_TAG_wdata_merged[pri_j] ),
              .Q          ( PRI_TAG_rdata       [pri_j] ),
              .T_LOGIC    ( i_test_mode                 )
          );

          //****************************
          //** DATA MEMORIES
          //****************************
          for(pri_i=0; pri_i<PRI_NB_WAYS; pri_i++)
          begin : g_pri_nb_ways

            assign PRI_DATA_ce_n        [pri_j][pri_i] = w_pri_data_ce_n  [pri_j*PRI_NB_WAYS                     +  pri_i                                                                                               ];
            assign PRI_DATA_addr        [pri_j][pri_i] = w_pri_data_addr  [pri_j*PRI_NB_WAYS*PRI_DATA_ADDR_WIDTH + (pri_i+1)*PRI_DATA_ADDR_WIDTH - 1 : pri_j*PRI_NB_WAYS*PRI_DATA_ADDR_WIDTH + pri_i*PRI_DATA_ADDR_WIDTH];
            assign PRI_DATA_we_n        [pri_j][pri_i] = w_pri_data_we_n  [pri_j*PRI_NB_WAYS                     +  pri_i                                                                                               ];
            assign PRI_DATA_wdata       [pri_j][pri_i] = w_pri_data_wdata [pri_j*PRI_NB_WAYS*PRI_DATA_WIDTH      + (pri_i+1)*PRI_DATA_WIDTH - 1      : pri_j*PRI_NB_WAYS*PRI_DATA_WIDTH      + pri_i*PRI_DATA_WIDTH     ];

            assign w_pri_data_rdata  [pri_j*PRI_NB_WAYS*PRI_DATA_WIDTH + (pri_i + 1)*PRI_DATA_WIDTH - 1:pri_j*PRI_NB_WAYS*PRI_DATA_WIDTH + pri_i*PRI_DATA_WIDTH] = PRI_DATA_rdata[pri_j][pri_i][PRI_DATA_WIDTH-1:0];

            sram_pri_data_wrapper #(
              .ADDR_WIDTH  (PRI_DATA_ADDR_WIDTH                ),
              .DATA_WIDTH  (PRI_DATA_WIDTH                     )
            )
            PRI_DATA_BANK (
              .CLK         ( w_pri_data_ckgt[pri_j][pri_i]      ),
              .CEN         ( PRI_DATA_ce_n  [pri_j][pri_i]      ),
              .WEN         ( PRI_DATA_we_n  [pri_j][pri_i]      ),
              .BEN         ( '0                                 ),
              .A           ( PRI_DATA_addr  [pri_j][pri_i]      ),
              .D           ( PRI_DATA_wdata [pri_j][pri_i]      ),
              .Q           ( PRI_DATA_rdata [pri_j][pri_i]      ),
              .T_LOGIC     ( i_test_mode                        )
            );

           end //PRI_NB_WAYS

        end // NB_CORES

    endgenerate


//******************************************************************************************************
//  ███████╗██╗  ██╗ █████╗ ██████╗ ███████╗        ██╗ ██████╗ █████╗  ██████╗██╗  ██╗███████╗
//  ██╔════╝██║  ██║██╔══██╗██╔══██╗██╔════╝        ██║██╔════╝██╔══██╗██╔════╝██║  ██║██╔════╝
//  ███████╗███████║███████║██████╔╝█████╗          ██║██║     ███████║██║     ███████║█████╗
//  ╚════██║██╔══██║██╔══██║██╔══██╗██╔══╝          ██║██║     ██╔══██║██║     ██╔══██║██╔══╝
//  ███████║██║  ██║██║  ██║██║  ██║███████╗███████╗██║╚██████╗██║  ██║╚██████╗██║  ██║███████╗
//  ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝
//******************************************************************************************************

    genvar sh_i, sh_j;
    generate
      for(sh_j = 0; sh_j< SH_NB_BANKS; sh_j++)
        begin : g_sh_nb_banks

          //****************************
          //** TAG MEMORIES
          //****************************
          assign SH_TAG_ce_n        [sh_j] = &w_sh_tag_ce_n[(sh_j+1)*SH_NB_WAYS-1 : sh_j*SH_NB_WAYS];
          assign SH_TAG_we_n        [sh_j] = w_sh_tag_we_n [sh_j];
          for(i=0; i<SH_NB_WAYS; i++)
            begin
              assign SH_TAG_be_n        [sh_j][i] = w_sh_tag_ce_n[sh_j*SH_NB_WAYS+i];
            end

          assign SH_TAG_addr        [sh_j] = w_sh_tag_addr  [(sh_j +1)*SH_TAG_ADDR_WIDTH - 1:sh_j*SH_TAG_ADDR_WIDTH];
          assign SH_TAG_addr_merged [sh_j] = SH_TAG_addr    [sh_j];

          assign SH_TAG_wdata       [sh_j] = w_sh_tag_wdata[sh_j*SH_TAG_DATA_WIDTH + SH_TAG_DATA_WIDTH - 1 :sh_j*SH_TAG_DATA_WIDTH];
          assign SH_TAG_wdata_merged[sh_j] = {SH_TAG_wdata   [sh_j] , SH_TAG_wdata[sh_j] , SH_TAG_wdata[sh_j] , SH_TAG_wdata[sh_j]};

          assign w_sh_tag_rdata  [(sh_j+1)*SH_NB_WAYS*SH_TAG_DATA_WIDTH - 1:sh_j*SH_NB_WAYS*SH_TAG_DATA_WIDTH]=  SH_TAG_rdata[sh_j];

          assign SH_DATA_addr    [sh_j] = w_sh_data_addr [sh_j*SH_DATA_ADDR_WIDTH + SH_DATA_ADDR_WIDTH - 1:sh_j*SH_DATA_ADDR_WIDTH];
          assign SH_DATA_we_n    [sh_j] = w_sh_data_we_n [sh_j                                                                    ];
          assign SH_DATA_wdata   [sh_j] = w_sh_data_wdata[sh_j*SH_DATA_DATA_WIDTH + SH_DATA_DATA_WIDTH - 1:sh_j*SH_DATA_DATA_WIDTH];
          assign SH_DATA_be_n    [sh_j] = w_sh_data_be_n [sh_j*SH_DATA_BE_WIDTH   + SH_DATA_BE_WIDTH   - 1:sh_j*SH_DATA_BE_WIDTH  ];

          sram_sh_tag_wrapper #(
            .ADDR_WIDTH   ( SH_TAG_ADDR_WIDTH            ),
            .DATA_WIDTH   ( SH_TAG_DATA_WIDTH*SH_NB_WAYS ),
            .SH_NB_WAYS   ( SH_NB_WAYS                   )
          )
          SH_TAG_BANK (
            .CLK          ( w_sh_tagm_ckgt      [sh_j]   ),
            .CEN          ( SH_TAG_ce_n         [sh_j]   ),
            .WEN          ( SH_TAG_we_n         [sh_j]   ),
            .BEN          ( SH_TAG_be_n         [sh_j]   ),
            .A            ( SH_TAG_addr_merged  [sh_j]   ),
            .D            ( SH_TAG_wdata_merged [sh_j]   ),
            .Q            ( SH_TAG_rdata        [sh_j]   ),
            .T_LOGIC      ( i_test_mode                  )
          );

          //****************************
          //** DATA MEMORIES
          //****************************
          for(sh_i = 0; sh_i< SH_NB_WAYS; sh_i++)
            begin : g_sh_nb_ways

              assign SH_DATA_ce_n     [sh_j][sh_i] = w_sh_data_ce_n [sh_j*SH_NB_WAYS + sh_i];
              assign w_sh_data_rdata  [sh_j*SH_NB_WAYS*SH_DATA_DATA_WIDTH + (sh_i + 1)*SH_DATA_DATA_WIDTH - 1:sh_j*SH_NB_WAYS*SH_DATA_DATA_WIDTH + sh_i*SH_DATA_DATA_WIDTH] = SH_DATA_rdata[sh_j][sh_i][SH_DATA_DATA_WIDTH-1:0];

              sram_sh_data_wrapper #(
                .ADDR_WIDTH (SH_DATA_ADDR_WIDTH              ),
                .DATA_WIDTH (SH_DATA_DATA_WIDTH              )
              )
              SH_DATA_BANK  (
                .CLK        ( w_sh_data_ckgt [sh_j][sh_i]    ),
                .CEN        ( SH_DATA_ce_n   [sh_j][sh_i]    ),
                .WEN        ( SH_DATA_we_n   [sh_j]          ),
                .BEN        ( SH_DATA_be_n   [sh_j]          ),
                .A          ( SH_DATA_addr   [sh_j]          ),
                .D          ( SH_DATA_wdata  [sh_j]          ),
                .Q          ( SH_DATA_rdata  [sh_j][sh_i]    ),
                .T_LOGIC    ( i_test_mode                    )
              );

          end // SH_NB_WAYS

        end // SH_NB_BANK

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
      for(genvar i=0; i<NB_TCDM_BANKS; i++)
        begin : g_tcdm_mem

          assign TCDM_BANK_addr     [i] = w_tcdm_bank_addr [i*ADDR_WIDTH + ADDR_WIDTH - 1:i*ADDR_WIDTH];
          assign TCDM_BANK_we_n     [i] = w_tcdm_bank_we_n [i                                         ];
          assign TCDM_BANK_wdata    [i] = w_tcdm_bank_wdata[i*DATA_WIDTH + DATA_WIDTH - 1:i*DATA_WIDTH];
          assign TCDM_BANK_be_n     [i] = w_tcdm_bank_be_n [i*BE_WIDTH   + BE_WIDTH   - 1:i*BE_WIDTH  ];

          assign TCDM_BANK_ce_n     [i] = w_tcdm_bank_ce_n [i                                         ];
          assign w_tcdm_bank_rdata  [i*DATA_WIDTH + DATA_WIDTH - 1:i*DATA_WIDTH] = TCDM_BANK_rdata[i][DATA_WIDTH-1:0];


          sram_tcdm_wrapper #(
            .ADDR_WIDTH(ADDR_MEM_WIDTH)
          )
          i_bank (
            .CLK        ( w_tcdm_ckgt    [i]                       ),
            .CEN        ( TCDM_BANK_ce_n [i]                       ),
            .WEN        ( TCDM_BANK_we_n [i]                       ),
            .BEN        ( TCDM_BANK_be_n [i]                       ),
            .A          ( TCDM_BANK_addr [i] [ADDR_MEM_WIDTH+2-1:2]),
            .D          ( TCDM_BANK_wdata[i]                       ),
            .Q          ( TCDM_BANK_rdata[i]                       ),
            .T_LOGIC    ( i_test_mode                              )
          );

        end // NB_TCDM_BANKS

    endgenerate


//*******************************//
//   ██████╗ ██╗   ██╗████████╗  //
//   ██╔══██╗██║   ██║╚══██╔══╝  //
//   ██║  ██║██║   ██║   ██║     //
//   ██║  ██║██║   ██║   ██║     //
//   ██████╔╝╚██████╔╝   ██║     //
//   ╚═════╝  ╚═════╝    ╚═╝     //
//*******************************//

    panther dut_panther (

        .i_clk                   (i_clk                   ),
        .i_rst_n                 (i_rst_n                 ),
        .i_ref_clk               (i_ref_clk               ),

        .i_test_mode             (i_test_mode             ),
        .i_bist_mode             ('0                      ),
        .i_scan_ckgt_enable      (i_scan_ckgt_enable      ),

        .i_cluster_id            (i_cluster_id            ),
        .i_base_addr             (i_base_addr             ),
        .i_en_sa_boot            (i_en_sa_boot            ),
        .i_fetch_en              (i_fetch_en              ),

        .o_busy                  (o_busy                  ),
        .o_eoc                   (o_eoc                   ),

        .i_dbg_irq_valid         (i_dbg_irq_valid         ),

        .i_dma_pe_evt_ack        (i_dma_pe_evt_ack        ),
        .o_dma_pe_evt_valid      (o_dma_pe_evt_valid      ),

        .i_dma_pe_irq_ack        (i_dma_pe_irq_ack        ),
        .o_dma_pe_irq_valid      (o_dma_pe_irq_valid      ),

        .i_events_valid          (i_events_valid          ),
        .o_events_ready          (o_events_ready          ),
        .i_events_data           (i_events_data           ),

        //***************************************************************************
        // AXI4 SLAVE
        //***************************************************************************
        // WRITE ADDRESS CHANNEL
        .i_data_slave_aw_valid   (i_data_slave_aw_valid   ),
        .i_data_slave_aw_addr    (i_data_slave_aw_addr    ),
        .i_data_slave_aw_prot    (i_data_slave_aw_prot    ),
        .i_data_slave_aw_region  (i_data_slave_aw_region  ),
        .i_data_slave_aw_len     (i_data_slave_aw_len     ),
        .i_data_slave_aw_size    (i_data_slave_aw_size    ),
        .i_data_slave_aw_burst   (i_data_slave_aw_burst   ),
        .i_data_slave_aw_lock    (i_data_slave_aw_lock    ),
        .i_data_slave_aw_cache   (i_data_slave_aw_cache   ),
        .i_data_slave_aw_qos     (i_data_slave_aw_qos     ),
        .i_data_slave_aw_id      (i_data_slave_aw_id      ),
        .i_data_slave_aw_user    (i_data_slave_aw_user    ),
        .o_data_slave_aw_ready   (o_data_slave_aw_ready   ),

        // READ ADDRESS CHANNEL
        .i_data_slave_ar_valid   (i_data_slave_ar_valid   ),
        .i_data_slave_ar_addr    (i_data_slave_ar_addr    ),
        .i_data_slave_ar_prot    (i_data_slave_ar_prot    ),
        .i_data_slave_ar_region  (i_data_slave_ar_region  ),
        .i_data_slave_ar_len     (i_data_slave_ar_len     ),
        .i_data_slave_ar_size    (i_data_slave_ar_size    ),
        .i_data_slave_ar_burst   (i_data_slave_ar_burst   ),
        .i_data_slave_ar_lock    (i_data_slave_ar_lock    ),
        .i_data_slave_ar_cache   (i_data_slave_ar_cache   ),
        .i_data_slave_ar_qos     (i_data_slave_ar_qos     ),
        .i_data_slave_ar_id      (i_data_slave_ar_id      ),
        .i_data_slave_ar_user    (i_data_slave_ar_user    ),
        .o_data_slave_ar_ready   (o_data_slave_ar_ready   ),

        // WRITE DATA CHANNEL
        .i_data_slave_w_valid    (i_data_slave_w_valid    ),
        .i_data_slave_w_data     (i_data_slave_w_data     ),
        .i_data_slave_w_strb     (i_data_slave_w_strb     ),
        .i_data_slave_w_user     (i_data_slave_w_user     ),
        .i_data_slave_w_last     (i_data_slave_w_last     ),
        .o_data_slave_w_ready    (o_data_slave_w_ready    ),

        // READ DATA CHANNEL
        .o_data_slave_r_valid    (o_data_slave_r_valid    ),
        .o_data_slave_r_data     (o_data_slave_r_data     ),
        .o_data_slave_r_resp     (o_data_slave_r_resp     ),
        .o_data_slave_r_last     (o_data_slave_r_last     ),
        .o_data_slave_r_id       (o_data_slave_r_id       ),
        .o_data_slave_r_user     (o_data_slave_r_user     ),
        .i_data_slave_r_ready    (i_data_slave_r_ready    ),

        // WRITE RESPONSE CHANNEL
        .o_data_slave_b_valid    (o_data_slave_b_valid    ),
        .o_data_slave_b_resp     (o_data_slave_b_resp     ),
        .o_data_slave_b_id       (o_data_slave_b_id       ),
        .o_data_slave_b_user     (o_data_slave_b_user     ),
        .i_data_slave_b_ready    (i_data_slave_b_ready    ),

        //***************************************************************************
        // AXI4 MASTER
        //***************************************************************************
        // WRITE ADDRESS CHANNEL
        .o_data_master_aw_valid  (o_data_master_aw_valid  ),
        .o_data_master_aw_addr   (o_data_master_aw_addr   ),
        .o_data_master_aw_prot   (o_data_master_aw_prot   ),
        .o_data_master_aw_region (o_data_master_aw_region ),
        .o_data_master_aw_len    (o_data_master_aw_len    ),
        .o_data_master_aw_size   (o_data_master_aw_size   ),
        .o_data_master_aw_burst  (o_data_master_aw_burst  ),
        .o_data_master_aw_lock   (o_data_master_aw_lock   ),
        .o_data_master_aw_cache  (o_data_master_aw_cache  ),
        .o_data_master_aw_qos    (o_data_master_aw_qos    ),
        .o_data_master_aw_id     (o_data_master_aw_id     ),
        .o_data_master_aw_user   (o_data_master_aw_user   ),
        .i_data_master_aw_ready  (i_data_master_aw_ready  ),

        // READ ADDRESS CHANNEL
        .o_data_master_ar_valid  (o_data_master_ar_valid  ),
        .o_data_master_ar_addr   (o_data_master_ar_addr   ),
        .o_data_master_ar_prot   (o_data_master_ar_prot   ),
        .o_data_master_ar_region (o_data_master_ar_region ),
        .o_data_master_ar_len    (o_data_master_ar_len    ),
        .o_data_master_ar_size   (o_data_master_ar_size   ),
        .o_data_master_ar_burst  (o_data_master_ar_burst  ),
        .o_data_master_ar_lock   (o_data_master_ar_lock   ),
        .o_data_master_ar_cache  (o_data_master_ar_cache  ),
        .o_data_master_ar_qos    (o_data_master_ar_qos    ),
        .o_data_master_ar_id     (o_data_master_ar_id     ),
        .o_data_master_ar_user   (o_data_master_ar_user   ),
        .i_data_master_ar_ready  (i_data_master_ar_ready  ),

        // WRITE DATA CHANNEL
        .o_data_master_w_valid   (o_data_master_w_valid   ),
        .o_data_master_w_data    (o_data_master_w_data    ),
        .o_data_master_w_strb    (o_data_master_w_strb    ),
        .o_data_master_w_user    (o_data_master_w_user    ),
        .o_data_master_w_last    (o_data_master_w_last    ),
        .i_data_master_w_ready   (i_data_master_w_ready   ),

        // READ DATA CHANNEL
        .i_data_master_r_valid   (i_data_master_r_valid   ),
        .i_data_master_r_data    (i_data_master_r_data    ),
        .i_data_master_r_resp    (i_data_master_r_resp    ),
        .i_data_master_r_last    (i_data_master_r_last    ),
        .i_data_master_r_id      (i_data_master_r_id      ),
        .i_data_master_r_user    (i_data_master_r_user    ),
        .o_data_master_r_ready   (o_data_master_r_ready   ),

        // WRITE RESPONSE CHANNEL
        .i_data_master_b_valid   (i_data_master_b_valid   ),
        .i_data_master_b_resp    (i_data_master_b_resp    ),
        .i_data_master_b_id      (i_data_master_b_id      ),
        .i_data_master_b_user    (i_data_master_b_user    ),
        .o_data_master_b_ready   (o_data_master_b_ready   ),

        // INSTR CACHE MASTER
        //***************************************
        // WRITE ADDRESS CHANNEL
        .o_instr_master_aw_valid (o_instr_master_aw_valid ),
        .o_instr_master_aw_addr  (o_instr_master_aw_addr  ),
        .o_instr_master_aw_prot  (o_instr_master_aw_prot  ),
        .o_instr_master_aw_region(o_instr_master_aw_region),
        .o_instr_master_aw_len   (o_instr_master_aw_len   ),
        .o_instr_master_aw_size  (o_instr_master_aw_size  ),
        .o_instr_master_aw_burst (o_instr_master_aw_burst ),
        .o_instr_master_aw_lock  (o_instr_master_aw_lock  ),
        .o_instr_master_aw_cache (o_instr_master_aw_cache ),
        .o_instr_master_aw_qos   (o_instr_master_aw_qos   ),
        .o_instr_master_aw_id    (o_instr_master_aw_id    ),
        .o_instr_master_aw_user  (o_instr_master_aw_user  ),
        .i_instr_master_aw_ready (i_instr_master_aw_ready ),

        // READ ADDRESS CHANNEL
        .o_instr_master_ar_valid (o_instr_master_ar_valid ),
        .o_instr_master_ar_addr  (o_instr_master_ar_addr  ),
        .o_instr_master_ar_prot  (o_instr_master_ar_prot  ),
        .o_instr_master_ar_region(o_instr_master_ar_region),
        .o_instr_master_ar_len   (o_instr_master_ar_len   ),
        .o_instr_master_ar_size  (o_instr_master_ar_size  ),
        .o_instr_master_ar_burst (o_instr_master_ar_burst ),
        .o_instr_master_ar_lock  (o_instr_master_ar_lock  ),
        .o_instr_master_ar_cache (o_instr_master_ar_cache ),
        .o_instr_master_ar_qos   (o_instr_master_ar_qos   ),
        .o_instr_master_ar_id    (o_instr_master_ar_id    ),
        .o_instr_master_ar_user  (o_instr_master_ar_user  ),
        .i_instr_master_ar_ready (i_instr_master_ar_ready ),

        // WRITE DATA CHANNEL
        .o_instr_master_w_valid  (o_instr_master_w_valid  ),
        .o_instr_master_w_data   (o_instr_master_w_data   ),
        .o_instr_master_w_strb   (o_instr_master_w_strb   ),
        .o_instr_master_w_user   (o_instr_master_w_user   ),
        .o_instr_master_w_last   (o_instr_master_w_last   ),
        .i_instr_master_w_ready  (i_instr_master_w_ready  ),

        // READ DATA CHANNEL
        .i_instr_master_r_valid  (i_instr_master_r_valid  ),
        .i_instr_master_r_data   (i_instr_master_r_data   ),
        .i_instr_master_r_resp   (i_instr_master_r_resp   ),
        .i_instr_master_r_last   (i_instr_master_r_last   ),
        .i_instr_master_r_id     (i_instr_master_r_id     ),
        .i_instr_master_r_user   (i_instr_master_r_user   ),
        .o_instr_master_r_ready  (o_instr_master_r_ready  ),

        // WRITE RESPONSE CHANNEL
        .i_instr_master_b_valid  (i_instr_master_b_valid  ),
        .i_instr_master_b_resp   (i_instr_master_b_resp   ),
        .i_instr_master_b_id     (i_instr_master_b_id     ),
        .i_instr_master_b_user   (i_instr_master_b_user   ),
        .o_instr_master_b_ready  (o_instr_master_b_ready  ),

    //****************************************************************************
    // Interface with TAG and DATA memories
    //****************************************************************************
        .o_pri_tag_addr          ( w_pri_tag_addr         ),
        .o_pri_tag_ce_n          ( w_pri_tag_ce_n         ),
        .o_pri_tag_we_n          ( w_pri_tag_we_n         ),
        .o_pri_tag_wdata         ( w_pri_tag_wdata        ),
        .i_pri_tag_rdata         ( w_pri_tag_rdata        ),

        .o_pri_data_addr         ( w_pri_data_addr        ),
        .o_pri_data_ce_n         ( w_pri_data_ce_n        ),
        .o_pri_data_we_n         ( w_pri_data_we_n        ),
        .o_pri_data_wdata        ( w_pri_data_wdata       ),
        .i_pri_data_rdata        ( w_pri_data_rdata       ),

        .o_sh_tag_addr           ( w_sh_tag_addr          ),
        .o_sh_tag_ce_n           ( w_sh_tag_ce_n          ),
        .o_sh_tag_we_n           ( w_sh_tag_we_n          ),
        .o_sh_tag_wdata          ( w_sh_tag_wdata         ),
        .i_sh_tag_rdata          ( w_sh_tag_rdata         ),

        .o_sh_data_addr          ( w_sh_data_addr         ),
        .o_sh_data_ce_n          ( w_sh_data_ce_n         ),
        .o_sh_data_we_n          ( w_sh_data_we_n         ),
        .o_sh_data_be_n          ( w_sh_data_be_n         ),
        .o_sh_data_wdata         ( w_sh_data_wdata        ),
        .i_sh_data_rdata         ( w_sh_data_rdata        ),

    //****************************************************************************
    // TCDM memory bank interface
    //****************************************************************************
        .o_tcdm_bank_addr        ( w_tcdm_bank_addr       ),
        .o_tcdm_bank_ce_n        ( w_tcdm_bank_ce_n       ),
        .o_tcdm_bank_we_n        ( w_tcdm_bank_we_n       ),
        .o_tcdm_bank_be_n        ( w_tcdm_bank_be_n       ),
        .o_tcdm_bank_wdata       ( w_tcdm_bank_wdata      ),
        .i_tcdm_bank_rdata       ( w_tcdm_bank_rdata      ),

        .o_pri_tag_ckgt          ( w_pri_tag_ckgt         ),
        .o_pri_tagm_ckgt         ( w_pri_tagm_ckgt        ),
        .o_pri_data_ckgt         ( w_pri_data_ckgt        ),
        .o_sh_tag_ckgt           ( w_sh_tag_ckgt          ),
        .o_sh_tagm_ckgt          ( w_sh_tagm_ckgt         ),
        .o_sh_data_ckgt          ( w_sh_data_ckgt         ),
        .o_tcdm_ckgt             ( w_tcdm_ckgt            )
    );


endmodule

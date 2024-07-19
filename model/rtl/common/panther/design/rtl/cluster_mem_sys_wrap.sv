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

import pulp_cluster_package::*;
import hci_package::*;

`include "axi/typedef.svh"
`include "axi/assign.svh"

`define TCDM_ASSIGN_MASTER(lhs, rhs)      \
    assign lhs.req       = rhs.req;       \
    assign lhs.add       = rhs.add;       \
    assign lhs.we_n      = rhs.we_n;      \
    assign lhs.wdata     = rhs.wdata;     \
    assign lhs.be        = rhs.be;        \
                                          \
    assign rhs.gnt       = lhs.gnt;       \
    assign rhs.r_valid   = lhs.r_valid;   \
    assign rhs.r_opc     = lhs.r_opc;     \
    assign rhs.r_rdata   = lhs.r_rdata;

module cluster_mem_sys_wrap
#(
    parameter NB_CORES                       = 8,
    parameter TCDM_SIZE                      = 64*1024,

    parameter CLUSTER_ALIAS_BASE             = 0,
    parameter CLUSTER_ALIAS                  = 0,

    parameter NB_SPERIPHS                    = NB_SPERIPHS,
    parameter NB_MPERIPHS                    = NB_MPERIPHS,

    parameter NB_DMAS                        = 4,
    parameter NB_OUTSND_BURSTS               = 8,

    parameter HWPE_PRESENT                   = 1,
    parameter NB_HWPE_PORTS                  = 9,
    parameter NB_TCDM_BANKS                  = 2*NB_CORES,
    parameter DATA_WIDTH                     = 32,
    parameter ADDR_WIDTH                     = 32,
    parameter BE_WIDTH                       = DATA_WIDTH/8,
    parameter TEST_SET_BIT                   = 1,
    parameter ADDR_MEM_WIDTH                 = 32,
    parameter LOG_CLUSTER                    = 5,
    parameter PE_ROUTING_LSB                 = 10,
    parameter USE_HETEROGENEOUS_INTERCONNECT = 1,

    parameter AXI_ID_IC_WIDTH                = 1,
    parameter bit USE_DEDICATED_INSTR_IF     = 0,
    parameter bit AXI_SYNCH_INTERF           = 1,
    parameter AXI_ADDR_WIDTH                 = 32,
    parameter AXI_INSTR_WIDTH                = 64,
    parameter AXI_DATA_C2S_WIDTH             = 64,
    parameter AXI_DATA_S2C_WIDTH             = 64,
    parameter AXI_ID_IN_WIDTH                = 5,
    parameter AXI_ID_OUT_WIDTH               = 7,
    parameter AXI_USER_WIDTH                 = 6,
    parameter AXI_STRB_INSTR_WIDTH           = AXI_INSTR_WIDTH/8,
    parameter AXI_STRB_C2S_WIDTH             = AXI_DATA_C2S_WIDTH/8,
    parameter AXI_STRB_S2C_WIDTH             = AXI_DATA_S2C_WIDTH/8
)(
    input logic                          i_clk,
    input logic                          i_rst_n,
    input logic                          i_test_mode,
    input logic                          i_scan_ckgt_enable,
    input logic [1:0]                    i_TCDM_arb_policy,

    input logic [9:0]                    i_base_addr,

    input  logic                         i_isolate_cluster,

    output logic                         o_axi2mem_busy   ,
    output logic                         o_axi2per_busy   ,
    output logic                         o_per2axi_busy   ,
    output logic                         o_fifo_busy      ,
    output logic                         o_converter_busy ,
    output logic                         o_axi_busy       ,

    input hci_interconnect_ctrl_t        i_hci_ctrl,

    hci_core_intf.slave                  hci_core [NB_CORES-1:0],
    hci_core_intf.slave                  hci_dma  [NB_DMAS-1:0], //FIXME IGOR --> check NB_CORES depend ASK DAVIDE
    hci_core_intf.slave                  hci_hwpe [0:0],

    hci_mem_intf.master                  tcdm_bus_sram[NB_TCDM_BANKS-1:0],

    XBAR_PERIPH_BUS.Slave                core_periph_bus[NB_CORES-1:0],

    XBAR_PERIPH_BUS.Master               xbar_speriph_bus[NB_SPERIPHS-2:0],

    AXI_BUS.Slave                        core_instr_bus       ,
    AXI_BUS.Slave                        dma_ext_bus          ,

    // AXI4 SLAVE
    //***************************************
    // WRITE ADDRESS CHANNEL
    input  logic                             data_slave_aw_valid_i ,
    input  logic [AXI_ADDR_WIDTH-1:0]        data_slave_aw_addr_i  ,
    input  logic [2:0]                       data_slave_aw_prot_i  ,
    input  logic [3:0]                       data_slave_aw_region_i,
    input  logic [7:0]                       data_slave_aw_len_i   ,
    input  logic [2:0]                       data_slave_aw_size_i  ,
    // input  logic [5:0]                       data_slave_aw_atop_i  ,
    input  logic [1:0]                       data_slave_aw_burst_i ,
    input  logic                             data_slave_aw_lock_i  ,
    input  logic [3:0]                       data_slave_aw_cache_i ,
    input  logic [3:0]                       data_slave_aw_qos_i   ,
    input  logic [AXI_ID_IN_WIDTH-1:0]       data_slave_aw_id_i    ,
    input  logic [AXI_USER_WIDTH-1:0]        data_slave_aw_user_i  ,
    output logic                             data_slave_aw_ready_o ,

    // READ ADDRESS CHANNEL
    input  logic                             data_slave_ar_valid_i ,
    input  logic [AXI_ADDR_WIDTH-1:0]        data_slave_ar_addr_i  ,
    input  logic [2:0]                       data_slave_ar_prot_i  ,
    input  logic [3:0]                       data_slave_ar_region_i,
    input  logic [7:0]                       data_slave_ar_len_i   ,
    input  logic [2:0]                       data_slave_ar_size_i  ,
    input  logic [1:0]                       data_slave_ar_burst_i ,
    input  logic                             data_slave_ar_lock_i  ,
    input  logic [3:0]                       data_slave_ar_cache_i ,
    input  logic [3:0]                       data_slave_ar_qos_i   ,
    input  logic [AXI_ID_IN_WIDTH-1:0]       data_slave_ar_id_i    ,
    input  logic [AXI_USER_WIDTH-1:0]        data_slave_ar_user_i  ,
    output logic                             data_slave_ar_ready_o ,

    // WRITE DATA CHANNEL
    input  logic                             data_slave_w_valid_i,
    input  logic [AXI_DATA_S2C_WIDTH-1:0]    data_slave_w_data_i ,
    input  logic [AXI_STRB_S2C_WIDTH-1:0]    data_slave_w_strb_i ,
    input  logic [AXI_USER_WIDTH-1:0]        data_slave_w_user_i ,
    input  logic                             data_slave_w_last_i ,
    output logic                             data_slave_w_ready_o,

    // READ DATA CHANNEL
    output logic                             data_slave_r_valid_o,
    output logic [AXI_DATA_S2C_WIDTH-1:0]    data_slave_r_data_o ,
    output logic [1:0]                       data_slave_r_resp_o ,
    output logic                             data_slave_r_last_o ,
    output logic [AXI_ID_IN_WIDTH-1:0]       data_slave_r_id_o   ,
    output logic [AXI_USER_WIDTH-1:0]        data_slave_r_user_o ,
    input  logic                             data_slave_r_ready_i,

    // WRITE RESPONSE CHANNEL
    output logic                             data_slave_b_valid_o,
    output logic [1:0]                       data_slave_b_resp_o ,
    output logic [AXI_ID_IN_WIDTH-1:0]       data_slave_b_id_o   ,
    output logic [AXI_USER_WIDTH-1:0]        data_slave_b_user_o ,
    input  logic                             data_slave_b_ready_i,

    // AXI4 MASTER
    //***************************************
    // WRITE ADDRESS CHANNEL
    output logic                             data_master_aw_valid_o ,
    output logic [AXI_ADDR_WIDTH-1:0]        data_master_aw_addr_o  ,
    output logic [2:0]                       data_master_aw_prot_o  ,
    output logic [3:0]                       data_master_aw_region_o,
    output logic [7:0]                       data_master_aw_len_o   ,
    output logic [2:0]                       data_master_aw_size_o  ,
    output logic [1:0]                       data_master_aw_burst_o ,
    // output logic [5:0]                       data_master_aw_atop_o  ,
    output logic                             data_master_aw_lock_o  ,
    output logic [3:0]                       data_master_aw_cache_o ,
    output logic [3:0]                       data_master_aw_qos_o   ,
    output logic [AXI_ID_OUT_WIDTH-1:0]      data_master_aw_id_o    ,
    output logic [AXI_USER_WIDTH-1:0]        data_master_aw_user_o  ,
    input  logic                             data_master_aw_ready_i ,

    // READ ADDRESS CHANNEL
    output logic                             data_master_ar_valid_o ,
    output logic [AXI_ADDR_WIDTH-1:0]        data_master_ar_addr_o  ,
    output logic [2:0]                       data_master_ar_prot_o  ,
    output logic [3:0]                       data_master_ar_region_o,
    output logic [7:0]                       data_master_ar_len_o   ,
    output logic [2:0]                       data_master_ar_size_o  ,
    output logic [1:0]                       data_master_ar_burst_o ,
    output logic                             data_master_ar_lock_o  ,
    output logic [3:0]                       data_master_ar_cache_o ,
    output logic [3:0]                       data_master_ar_qos_o   ,
    output logic [AXI_ID_OUT_WIDTH-1:0]      data_master_ar_id_o    ,
    output logic [AXI_USER_WIDTH-1:0]        data_master_ar_user_o  ,
    input  logic                             data_master_ar_ready_i ,

    // WRITE DATA CHANNEL
    output logic                             data_master_w_valid_o,
    output logic [AXI_DATA_C2S_WIDTH-1:0]    data_master_w_data_o ,
    output logic [AXI_STRB_C2S_WIDTH-1:0]    data_master_w_strb_o ,
    output logic [AXI_USER_WIDTH-1:0]        data_master_w_user_o ,
    output logic                             data_master_w_last_o ,
    input  logic                             data_master_w_ready_i,

    // READ DATA CHANNEL
    input  logic                             data_master_r_valid_i,
    input  logic [AXI_DATA_C2S_WIDTH-1:0]    data_master_r_data_i ,
    input  logic [1:0]                       data_master_r_resp_i ,
    input  logic                             data_master_r_last_i ,
    input  logic [AXI_ID_OUT_WIDTH-1:0]      data_master_r_id_i   ,
    input  logic [AXI_USER_WIDTH-1:0]        data_master_r_user_i ,
    output logic                             data_master_r_ready_o,

    // WRITE RESPONSE CHANNEL
    input  logic                             data_master_b_valid_i,
    input  logic [1:0]                       data_master_b_resp_i ,
    input  logic [AXI_ID_OUT_WIDTH-1:0]      data_master_b_id_i   ,
    input  logic [AXI_USER_WIDTH-1:0]        data_master_b_user_i ,
    output logic                             data_master_b_ready_o,

    // INSTR MASTER
    //***************************************
    // WRITE ADDRESS CHANNEL
    output logic                             instr_master_aw_valid_o ,
    output logic [AXI_ADDR_WIDTH-1:0]        instr_master_aw_addr_o  ,
    output logic [2:0]                       instr_master_aw_prot_o  ,
    output logic [3:0]                       instr_master_aw_region_o,
    output logic [7:0]                       instr_master_aw_len_o   ,
    output logic [2:0]                       instr_master_aw_size_o  ,
    output logic [1:0]                       instr_master_aw_burst_o ,
    output logic                             instr_master_aw_lock_o  ,
    output logic [3:0]                       instr_master_aw_cache_o ,
    output logic [3:0]                       instr_master_aw_qos_o   ,
    output logic [AXI_ID_IC_WIDTH-1:0]       instr_master_aw_id_o    ,
    output logic [AXI_USER_WIDTH-1:0]        instr_master_aw_user_o  ,
    input  logic                             instr_master_aw_ready_i ,

    // READ ADDRESS CHANNEL
    output logic                             instr_master_ar_valid_o ,
    output logic [AXI_ADDR_WIDTH-1:0]        instr_master_ar_addr_o  ,
    output logic [2:0]                       instr_master_ar_prot_o  ,
    output logic [3:0]                       instr_master_ar_region_o,
    output logic [7:0]                       instr_master_ar_len_o   ,
    output logic [2:0]                       instr_master_ar_size_o  ,
    output logic [1:0]                       instr_master_ar_burst_o ,
    output logic                             instr_master_ar_lock_o  ,
    output logic [3:0]                       instr_master_ar_cache_o ,
    output logic [3:0]                       instr_master_ar_qos_o   ,
    output logic [AXI_ID_IC_WIDTH-1:0]       instr_master_ar_id_o    ,
    output logic [AXI_USER_WIDTH-1:0]        instr_master_ar_user_o  ,
    input  logic                             instr_master_ar_ready_i ,

    // WRITE DATA CHANNEL
    output logic                             instr_master_w_valid_o,
    output logic [AXI_INSTR_WIDTH-1:0]       instr_master_w_data_o ,
    output logic [AXI_STRB_INSTR_WIDTH-1:0]  instr_master_w_strb_o ,
    output logic [AXI_USER_WIDTH-1:0]        instr_master_w_user_o ,
    output logic                             instr_master_w_last_o ,
    input  logic                             instr_master_w_ready_i,

    // READ DATA CHANNEL
    input  logic                             instr_master_r_valid_i,
    input  logic [AXI_INSTR_WIDTH-1:0]       instr_master_r_data_i ,
    input  logic [1:0]                       instr_master_r_resp_i ,
    input  logic                             instr_master_r_last_i ,
    input  logic [AXI_ID_IC_WIDTH-1:0]       instr_master_r_id_i   ,
    input  logic [AXI_USER_WIDTH-1:0]        instr_master_r_user_i ,
    output logic                             instr_master_r_ready_o,

    // WRITE RESPONSE CHANNEL
    input  logic                             instr_master_b_valid_i,
    input  logic [1:0]                       instr_master_b_resp_i ,
    input  logic [AXI_ID_IC_WIDTH-1:0]       instr_master_b_id_i   ,
    input  logic [AXI_USER_WIDTH-1:0]        instr_master_b_user_i ,
    output logic                             instr_master_b_ready_o

);

    localparam int AXI_DATA_INT_WIDTH = 64;

    logic s_s2c_up_busy, s_s2c_fifo_busy, s_c2s_fifo_busy, s_inst_fifo_busy, s_c2s_down_busy, s_instr_down_busy;
    logic s_data_slave_busy, s_data_master_busy, s_instr_master_busy;
    assign o_axi_busy = s_data_slave_busy | s_data_master_busy | s_instr_master_busy;
    assign o_fifo_busy      = s_s2c_fifo_busy | s_c2s_fifo_busy | s_inst_fifo_busy;
    assign o_converter_busy = s_s2c_up_busy | s_c2s_down_busy | s_instr_down_busy;
    logic [AXI_ID_IN_WIDTH+1:0] s_data_master_aw_id_full;
    logic [AXI_ID_IN_WIDTH+1:0] s_data_master_ar_id_full;
    logic [AXI_ID_IN_WIDTH+1:0] s_data_master_r_id_full ;
    logic [AXI_ID_IN_WIDTH+1:0] s_data_master_b_id_full ;

    assign data_master_aw_id_o  = {s_data_master_aw_id_full[AXI_ID_IN_WIDTH+1:AXI_ID_IN_WIDTH] , s_data_master_aw_id_full[AXI_ID_OUT_WIDTH-3:0]};
    assign data_master_ar_id_o  = {s_data_master_ar_id_full[AXI_ID_IN_WIDTH+1:AXI_ID_IN_WIDTH] , s_data_master_ar_id_full[AXI_ID_OUT_WIDTH-3:0]};

    always_comb begin : axi_id_width_convertion
        s_data_master_r_id_full                                    = '0;
        s_data_master_r_id_full[AXI_ID_IN_WIDTH+1:AXI_ID_IN_WIDTH] = data_master_r_id_i[AXI_ID_OUT_WIDTH-1:AXI_ID_OUT_WIDTH-2];
        s_data_master_r_id_full[AXI_ID_OUT_WIDTH-3:0]              = data_master_r_id_i[AXI_ID_OUT_WIDTH-3:0];

        s_data_master_b_id_full                                    = '0;
        s_data_master_b_id_full[AXI_ID_IN_WIDTH+1:AXI_ID_IN_WIDTH] = data_master_b_id_i[AXI_ID_OUT_WIDTH-1:AXI_ID_OUT_WIDTH-2];
        s_data_master_b_id_full[AXI_ID_OUT_WIDTH-3:0]              = data_master_b_id_i[AXI_ID_OUT_WIDTH-3:0];
    end

    XBAR_PERIPH_BUS#(.ID_WIDTH(NB_CORES+1)) s_xbar_speriph_bus[NB_SPERIPHS:0](); //Adding on bus for error
    generate
        for(genvar i=0; i<NB_SPERIPHS-1; i++) begin : gen_connect_sperpih_bus
            assign xbar_speriph_bus[i].req     = s_xbar_speriph_bus[i].req   ;
            assign xbar_speriph_bus[i].add     = s_xbar_speriph_bus[i].add   ;
            assign xbar_speriph_bus[i].we_n    = s_xbar_speriph_bus[i].we_n  ;
            assign xbar_speriph_bus[i].wdata   = s_xbar_speriph_bus[i].wdata ;
            assign xbar_speriph_bus[i].be      = s_xbar_speriph_bus[i].be    ;
            assign s_xbar_speriph_bus[i].gnt   = xbar_speriph_bus[i].gnt     ;
            assign xbar_speriph_bus[i].id      = s_xbar_speriph_bus[i].id    ;

            assign s_xbar_speriph_bus[i].r_valid = xbar_speriph_bus[i].r_valid;
            assign s_xbar_speriph_bus[i].r_opc   = xbar_speriph_bus[i].r_opc  ;
            assign s_xbar_speriph_bus[i].r_id    = xbar_speriph_bus[i].r_id   ;
            assign s_xbar_speriph_bus[i].r_rdata = xbar_speriph_bus[i].r_rdata;
        end
    endgenerate
    XBAR_TCDM_BUS s_mperiph_xbar_bus[NB_MPERIPHS-1:0]();

    // periph demux
    XBAR_TCDM_BUS s_mperiph_bus();
    XBAR_TCDM_BUS s_mperiph_demux_bus[1:0]();

    /* logarithmic and peripheral interconnect interfaces */
    // ext -> log interconnect
    hci_core_intf #(
        .DW ( 32 ),
        .AW ( 32 ),
        .OW ( 1  )
    ) s_hci_ext[NB_DMAS-1:0] (
        .clk ( i_clk )
    );

  //***************************************************
  /* synchronous AXI interfaces internal to the cluster */
  //***************************************************
    // core per2axi -> ext
    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH     ),
        .AXI_DATA_WIDTH ( AXI_DATA_INT_WIDTH ),
        .AXI_ID_WIDTH   ( AXI_ID_IN_WIDTH    ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH     )
    ) s_core_ext_bus();

    // ext -> axi2mem
    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH     ),
        .AXI_DATA_WIDTH ( AXI_DATA_INT_WIDTH ),
        .AXI_ID_WIDTH   ( AXI_ID_IN_WIDTH+2  ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH     )
    ) s_ext_tcdm_bus();

    // cluster bus -> axi2per
    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH     ),
        .AXI_DATA_WIDTH ( AXI_DATA_INT_WIDTH ),
        .AXI_ID_WIDTH   ( AXI_ID_IN_WIDTH+2  ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH     )
    ) s_ext_mperiph_bus();

    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH     ),
        .AXI_DATA_WIDTH ( AXI_DATA_INT_WIDTH ),
        .AXI_ID_WIDTH   ( AXI_ID_IN_WIDTH    ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH     )
    ) s_data_slave_64();

    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH     ),
        .AXI_DATA_WIDTH ( AXI_DATA_INT_WIDTH ),
        .AXI_ID_WIDTH   ( AXI_ID_IN_WIDTH    ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH     )
    ) s_data_slave_64_filtered();

    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH     ),
        .AXI_DATA_WIDTH ( AXI_DATA_INT_WIDTH ),
        .AXI_ID_WIDTH   ( AXI_ID_OUT_WIDTH   ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH     )
    ) s_instr_select();

    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH     ),
        .AXI_DATA_WIDTH ( AXI_DATA_INT_WIDTH ),
        .AXI_ID_WIDTH   ( AXI_ID_IN_WIDTH+2  ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH     )
    ) s_data_master();

    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH     ),
        .AXI_DATA_WIDTH ( AXI_DATA_S2C_WIDTH ),
        .AXI_ID_WIDTH   ( AXI_ID_IN_WIDTH    ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH     )
    ) s_data_slave_size_converted();

    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH     ),
        .AXI_DATA_WIDTH ( AXI_DATA_C2S_WIDTH ),
        .AXI_ID_WIDTH   ( AXI_ID_IN_WIDTH+2  ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH     )
    ) s_data_master_size_converted();

    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH     ),
        .AXI_DATA_WIDTH ( AXI_INSTR_WIDTH    ),
        .AXI_ID_WIDTH   ( AXI_ID_IC_WIDTH    ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH     )
    ) core_instr_bus_size_converted();



    // ***********************************************************************************************+
    // ***********************************************************************************************+
    // ***********************************************************************************************+
    // ***********************************************************************************************+
    // ***********************************************************************************************+

    // address map
    logic [31:0] cluster_base_addr;
    always_comb begin
        cluster_base_addr        = 32'h0;
        cluster_base_addr[31:22] = i_base_addr;
    end

    axi_filter #(
        .AXI_ADDR_WIDTH      (AXI_ADDR_WIDTH     ),
        .AXI_DATA_WIDTH      (AXI_DATA_INT_WIDTH ),
        .AXI_ID_WIDTH        (AXI_ID_IN_WIDTH    ),
        .AXI_USER_WIDTH      (AXI_USER_WIDTH     ),
        .NBR_RANGE           (2                  ),
        .NBR_OUTSTANDING_REQ (4                  )
    ) axi_filter_i (
        .i_clk              (i_clk                            ),
        .i_rst_n            (i_rst_n                          ),
        .i_scan_ckgt_enable (i_scan_ckgt_enable               ),
        .START_ADDR         ({32'h0000_0000, cluster_base_addr+32'h0040_0000}),
        .STOP_ADDR          ({cluster_base_addr-1, 32'hFFFF_FFFF}),
    // INPUT
    // WRITE ADDRESS CHANNEL
    .axi_in_aw_valid_i   (s_data_slave_64.aw_valid ),
    .axi_in_aw_addr_i    (s_data_slave_64.aw_addr  ),
    .axi_in_aw_prot_i    (s_data_slave_64.aw_prot  ),
    .axi_in_aw_region_i  (s_data_slave_64.aw_region),
    .axi_in_aw_len_i     (s_data_slave_64.aw_len   ),
    .axi_in_aw_size_i    (s_data_slave_64.aw_size  ),
    .axi_in_aw_atop_i    (s_data_slave_64.aw_atop  ),
    .axi_in_aw_burst_i   (s_data_slave_64.aw_burst ),
    .axi_in_aw_lock_i    (s_data_slave_64.aw_lock  ),
    .axi_in_aw_cache_i   (s_data_slave_64.aw_cache ),
    .axi_in_aw_qos_i     (s_data_slave_64.aw_qos   ),
    .axi_in_aw_id_i      (s_data_slave_64.aw_id    ),
    .axi_in_aw_user_i    (s_data_slave_64.aw_user  ),
    .axi_in_aw_ready_o   (s_data_slave_64.aw_ready ),
    // READ ADDRESS CHANNEL
    .axi_in_ar_valid_i   (s_data_slave_64.ar_valid ),
    .axi_in_ar_addr_i    (s_data_slave_64.ar_addr  ),
    .axi_in_ar_prot_i    (s_data_slave_64.ar_prot  ),
    .axi_in_ar_region_i  (s_data_slave_64.ar_region),
    .axi_in_ar_len_i     (s_data_slave_64.ar_len   ),
    .axi_in_ar_size_i    (s_data_slave_64.ar_size  ),
    .axi_in_ar_burst_i   (s_data_slave_64.ar_burst ),
    .axi_in_ar_lock_i    (s_data_slave_64.ar_lock  ),
    .axi_in_ar_cache_i   (s_data_slave_64.ar_cache ),
    .axi_in_ar_qos_i     (s_data_slave_64.ar_qos   ),
    .axi_in_ar_id_i      (s_data_slave_64.ar_id    ),
    .axi_in_ar_user_i    (s_data_slave_64.ar_user  ),
    .axi_in_ar_ready_o   (s_data_slave_64.ar_ready ),
    // WRITE DATA CHANNEL
    .axi_in_w_valid_i    (s_data_slave_64.w_valid  ),
    .axi_in_w_data_i     (s_data_slave_64.w_data   ),
    .axi_in_w_strb_i     (s_data_slave_64.w_strb   ),
    .axi_in_w_user_i     (s_data_slave_64.w_user   ),
    .axi_in_w_last_i     (s_data_slave_64.w_last   ),
    .axi_in_w_ready_o    (s_data_slave_64.w_ready  ),
    // READ DATA CHANNEL
    .axi_in_r_valid_o    (s_data_slave_64.r_valid  ),
    .axi_in_r_data_o     (s_data_slave_64.r_data   ),
    .axi_in_r_resp_o     (s_data_slave_64.r_resp   ),
    .axi_in_r_last_o     (s_data_slave_64.r_last   ),
    .axi_in_r_id_o       (s_data_slave_64.r_id     ),
    .axi_in_r_user_o     (s_data_slave_64.r_user   ),
    .axi_in_r_ready_i    (s_data_slave_64.r_ready  ),
    // WRITE RESPONSE CHANNEL
    .axi_in_b_valid_o    (s_data_slave_64.b_valid  ),
    .axi_in_b_resp_o     (s_data_slave_64.b_resp   ),
    .axi_in_b_id_o       (s_data_slave_64.b_id     ),
    .axi_in_b_user_o     (s_data_slave_64.b_user   ),
    .axi_in_b_ready_i    (s_data_slave_64.b_ready  ),
    // OUTPUT
    // WRITE ADDRESS CHANNEL
    .axi_out_aw_valid_o  (s_data_slave_64_filtered.aw_valid ),
    .axi_out_aw_addr_o   (s_data_slave_64_filtered.aw_addr  ),
    .axi_out_aw_prot_o   (s_data_slave_64_filtered.aw_prot  ),
    .axi_out_aw_region_o (s_data_slave_64_filtered.aw_region),
    .axi_out_aw_len_o    (s_data_slave_64_filtered.aw_len   ),
    .axi_out_aw_size_o   (s_data_slave_64_filtered.aw_size  ),
    .axi_out_aw_atop_o   (s_data_slave_64_filtered.aw_atop  ),
    .axi_out_aw_burst_o  (s_data_slave_64_filtered.aw_burst ),
    .axi_out_aw_lock_o   (s_data_slave_64_filtered.aw_lock  ),
    .axi_out_aw_cache_o  (s_data_slave_64_filtered.aw_cache ),
    .axi_out_aw_qos_o    (s_data_slave_64_filtered.aw_qos   ),
    .axi_out_aw_id_o     (s_data_slave_64_filtered.aw_id    ),
    .axi_out_aw_user_o   (s_data_slave_64_filtered.aw_user  ),
    .axi_out_aw_ready_i  (s_data_slave_64_filtered.aw_ready ),
    // READ ADDRESS CHANNEL
    .axi_out_ar_valid_o  (s_data_slave_64_filtered.ar_valid ),
    .axi_out_ar_addr_o   (s_data_slave_64_filtered.ar_addr  ),
    .axi_out_ar_prot_o   (s_data_slave_64_filtered.ar_prot  ),
    .axi_out_ar_region_o (s_data_slave_64_filtered.ar_region),
    .axi_out_ar_len_o    (s_data_slave_64_filtered.ar_len   ),
    .axi_out_ar_size_o   (s_data_slave_64_filtered.ar_size  ),
    .axi_out_ar_burst_o  (s_data_slave_64_filtered.ar_burst ),
    .axi_out_ar_lock_o   (s_data_slave_64_filtered.ar_lock  ),
    .axi_out_ar_cache_o  (s_data_slave_64_filtered.ar_cache ),
    .axi_out_ar_qos_o    (s_data_slave_64_filtered.ar_qos   ),
    .axi_out_ar_id_o     (s_data_slave_64_filtered.ar_id    ),
    .axi_out_ar_user_o   (s_data_slave_64_filtered.ar_user  ),
    .axi_out_ar_ready_i  (s_data_slave_64_filtered.ar_ready ),
    // WRITE DATA CHANNEL
    .axi_out_w_valid_o   (s_data_slave_64_filtered.w_valid  ),
    .axi_out_w_data_o    (s_data_slave_64_filtered.w_data   ),
    .axi_out_w_strb_o    (s_data_slave_64_filtered.w_strb   ),
    .axi_out_w_user_o    (s_data_slave_64_filtered.w_user   ),
    .axi_out_w_last_o    (s_data_slave_64_filtered.w_last   ),
    .axi_out_w_ready_i   (s_data_slave_64_filtered.w_ready  ),
    // READ DATA CHANNEL
    .axi_out_r_valid_i   (s_data_slave_64_filtered.r_valid  ),
    .axi_out_r_data_i    (s_data_slave_64_filtered.r_data   ),
    .axi_out_r_resp_i    (s_data_slave_64_filtered.r_resp   ),
    .axi_out_r_last_i    (s_data_slave_64_filtered.r_last   ),
    .axi_out_r_id_i      (s_data_slave_64_filtered.r_id     ),
    .axi_out_r_user_i    (s_data_slave_64_filtered.r_user   ),
    .axi_out_r_ready_o   (s_data_slave_64_filtered.r_ready  ),
    // WRITE RESPONSE CHANNEL
    .axi_out_b_valid_i   (s_data_slave_64_filtered.b_valid  ),
    .axi_out_b_resp_i    (s_data_slave_64_filtered.b_resp   ),
    .axi_out_b_id_i      (s_data_slave_64_filtered.b_id     ),
    .axi_out_b_user_i    (s_data_slave_64_filtered.b_user   ),
    .axi_out_b_ready_o   (s_data_slave_64_filtered.b_ready  )
    );
    //***************************************************
    /* synchronous AXI interfaces internal to the cluster */
    //***************************************************


    /* cluster bus and attached peripherals */
    cluster_bus_wrap #(
        .NB_CORES               ( NB_CORES               ),
        .USE_DEDICATED_INSTR_IF ( USE_DEDICATED_INSTR_IF ),
        .DMA_NB_OUTSND_BURSTS   ( NB_OUTSND_BURSTS       ),
        .TCDM_SIZE              ( TCDM_SIZE              ),
        .AXI_ADDR_WIDTH         ( AXI_ADDR_WIDTH         ),
        .AXI_DATA_WIDTH         ( AXI_DATA_INT_WIDTH     ),
        .AXI_USER_WIDTH         ( AXI_USER_WIDTH         ),
        .AXI_ID_IN_WIDTH        ( AXI_ID_IN_WIDTH        ),
        .AXI_ID_OUT_WIDTH       ( AXI_ID_IN_WIDTH+2      ) //AXI_ID_OUT_WIDTH
    ) cluster_bus_wrap_i (
        .clk_i         ( i_clk                    ),
        .rst_ni        ( i_rst_n                  ),
        .test_en_i     ( i_test_mode              ),
        .base_addr_i   ( i_base_addr              ),
        .instr_slave   ( s_instr_select           ),
        .data_slave    ( s_data_slave_64_filtered ),
        .dma_slave     ( dma_ext_bus              ),
        .ext_slave     ( s_core_ext_bus           ),
        .tcdm_master   ( s_ext_tcdm_bus           ),
        .periph_master ( s_ext_mperiph_bus        ),
        .ext_master    ( s_data_master            )
    );

    axi2mem_wrap #(
        .NB_DMAS        ( NB_DMAS            ),
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH     ),
        .AXI_DATA_WIDTH ( AXI_DATA_INT_WIDTH ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH     ),
        .AXI_ID_WIDTH   ( AXI_ID_IN_WIDTH+2  )
    ) axi2mem_wrap_i (
        .clk_i       ( i_clk          ),
        .rst_ni      ( i_rst_n        ),
        .test_en_i   ( i_test_mode    ),
        .axi_slave   ( s_ext_tcdm_bus ),
        .tcdm_master ( s_hci_ext      ),
        .busy_o      ( o_axi2mem_busy )
    );

    axi2per_wrap #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH     ),
        .AXI_DATA_WIDTH ( AXI_DATA_INT_WIDTH ),
        .AXI_ID_WIDTH   ( AXI_ID_IN_WIDTH+2  ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH     )
    ) axi2per_wrap_i (
        .clk_i         ( i_clk             ),
        .rst_ni        ( i_rst_n           ),
        .test_en_i     ( i_test_mode       ),
        .axi_slave     ( s_ext_mperiph_bus ),
        .periph_master ( s_mperiph_bus     ),
        .busy_o        ( o_axi2per_busy    )
    );

    per_demux_wrap #(
        .NB_MASTERS  (  2 ),
        .ADDR_OFFSET ( 20 )
    ) per_demux_wrap_i (
        .clk_i   ( i_clk               ),
        .rst_ni  ( i_rst_n             ),
        .slave   ( s_mperiph_bus       ),
        .masters ( s_mperiph_demux_bus )
    );

    `TCDM_ASSIGN_MASTER (s_mperiph_xbar_bus[NB_MPERIPHS-1], s_mperiph_demux_bus[0])
    tcdm_error_plug tcdm_error_plug_i
    (
        .i_clk        (i_clk                 ),
        .i_rst_n      (i_rst_n               ),
        .tcdm_slave   (s_mperiph_demux_bus[1])
    );

    per2axi_wrap #(
        .NB_CORES       ( NB_CORES             ),
        .PER_ADDR_WIDTH ( 32                   ),
        .PER_ID_WIDTH   ( NB_CORES+NB_MPERIPHS ),
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH       ),
        .AXI_DATA_WIDTH ( AXI_DATA_INT_WIDTH   ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH       ),
        .AXI_ID_WIDTH   ( AXI_ID_IN_WIDTH      )
    ) per2axi_wrap_i (
        .clk_i          ( i_clk                           ),
        .rst_ni         ( i_rst_n                         ),
        .test_en_i      ( i_test_mode                     ),
        .periph_slave   ( s_xbar_speriph_bus[SPER_EXT_ID] ),
        .axi_master     ( s_core_ext_bus                  ),
        .busy_o         ( o_per2axi_busy                  )
    );


    per_error_plug per_error_plug_i
    (
        .i_clk        (i_clk                            ),
        .i_rst_n      (i_rst_n                          ),
        .periph_slave (s_xbar_speriph_bus[SPER_ERROR_ID])
    );

    //***************************************************
    /* cluster (log + periph) interconnect and attached peripherals */
    //***************************************************

    cluster_interconnect_wrap #(
        .NB_CORES           ( NB_CORES           ),
        .HWPE_PRESENT       ( HWPE_PRESENT       ),
        .NB_HWPE_PORTS      ( NB_HWPE_PORTS      ),
        .NB_DMAS            ( NB_DMAS            ),
        .NB_MPERIPHS        ( NB_MPERIPHS        ),
        .NB_TCDM_BANKS      ( NB_TCDM_BANKS      ),
        .NB_SPERIPHS        ( NB_SPERIPHS+1      ), //adding on bus for error

        .DATA_WIDTH         ( DATA_WIDTH         ),
        .ADDR_WIDTH         ( ADDR_WIDTH         ),
        .BE_WIDTH           ( BE_WIDTH           ),

        .TEST_SET_BIT       ( TEST_SET_BIT       ),
        .ADDR_MEM_WIDTH     ( ADDR_MEM_WIDTH     ),

        .LOG_CLUSTER        ( LOG_CLUSTER        ),
        .PE_ROUTING_LSB     ( PE_ROUTING_LSB     ),

        .CLUSTER_ALIAS      ( CLUSTER_ALIAS      ),
        .CLUSTER_ALIAS_BASE ( CLUSTER_ALIAS_BASE ),
        .USE_HETEROGENEOUS_INTERCONNECT ( USE_HETEROGENEOUS_INTERCONNECT )

    ) cluster_interconnect_wrap_i (
        .clk_i              ( i_clk                               ),
        .rst_ni             ( i_rst_n                             ),
        .base_addr_i        ( i_base_addr                         ),

        .core_tcdm_slave    ( hci_core                            ),
        .hwpe_tcdm_slave    ( hci_hwpe                            ),
        .ext_slave          ( s_hci_ext                           ),
        .dma_slave          ( hci_dma                             ),

        .tcdm_sram_master   ( tcdm_bus_sram                       ),

        .core_periph_slave  ( core_periph_bus                     ),
        .mperiph_slave      ( s_mperiph_xbar_bus                  ),
        .speriph_master     ( s_xbar_speriph_bus                  ),

        .hci_ctrl_i         ( i_hci_ctrl                          ),
        .TCDM_arb_policy_i  ( i_TCDM_arb_policy                   )
    );

    //***************************************
    // AXI4 SLAVE
    //***************************************
    axi_busy_unit
    #(
      .COUNTER_SIZE(6)
    )
    data_slave_busy_unit_i (
      .clk_i       ( i_clk                             ),
      .rst_ni      ( i_rst_n                           ),

      // WRITE INTERFACE
      .aw_sync_i   ( data_slave_aw_valid_i & data_slave_aw_ready_o ),
      .b_sync_i    ( data_slave_b_valid_o & data_slave_b_ready_i    ),

      // READ INTERFACE
      .ar_sync_i   ( data_slave_ar_valid_i & data_slave_ar_ready_o ),
      .r_sync_i    ( data_slave_r_valid_o & data_slave_r_ready_i & data_slave_r_last_o  ),

      // BUSY SIGNAL
      .busy_o      ( s_data_slave_busy                            )
    );

    generate
      if(AXI_DATA_S2C_WIDTH == 32) begin : gen_axi_slave_32
        axi_dw_converter_intf #(
              .AXI_ID_WIDTH            ( AXI_ID_IN_WIDTH    ),
              .AXI_ADDR_WIDTH          ( AXI_ADDR_WIDTH     ),
              .AXI_SLV_PORT_DATA_WIDTH ( AXI_DATA_S2C_WIDTH ),
              .AXI_MST_PORT_DATA_WIDTH ( AXI_DATA_INT_WIDTH ),
              .AXI_USER_WIDTH          ( AXI_USER_WIDTH     ),
              .AXI_MAX_READS           ( 4                  ),
              .UniqueIds               ( 0                  ),
              .AxiLookBits             ( 5                  )
          ) axi_dw_s2c_upsizer_32_64_wrap_i (
              .clk_i  ( i_clk           ),
              .rst_ni ( i_rst_n         ),
              .slv    ( s_data_slave_size_converted ),
              .mst    ( s_data_slave_64 ),
              .busy_o ( s_s2c_up_busy   )
          );
      end else begin : gen_axi_slave_64
        `AXI_ASSIGN(s_data_slave_64, s_data_slave_size_converted) //dst, src  | slv, mst
        assign s_s2c_up_busy = 1'b0;
      end
    endgenerate

    generate
        if(!AXI_SYNCH_INTERF) begin : gen_axi_slave_asynch

            assign s_s2c_fifo_busy = 1'b0;

            // WRITE ADDRESS CHANNEL
            assign s_data_slave_size_converted.aw_valid  = data_slave_aw_valid_i &!i_isolate_cluster  ;
            assign s_data_slave_size_converted.aw_addr   = data_slave_aw_addr_i    ;
            assign s_data_slave_size_converted.aw_prot   = data_slave_aw_prot_i    ;
            assign s_data_slave_size_converted.aw_region = data_slave_aw_region_i  ;
            assign s_data_slave_size_converted.aw_len    = data_slave_aw_len_i     ;
            assign s_data_slave_size_converted.aw_size   = data_slave_aw_size_i    ;
            //  assign s_data_slave_32.aw_atop   = data_slave_aw_atop_i    ;
            //TODO: get this atomic operation signal right
            assign s_data_slave_size_converted.aw_atop   = '0                      ;
            assign s_data_slave_size_converted.aw_burst  = data_slave_aw_burst_i   ;
            assign s_data_slave_size_converted.aw_lock   = data_slave_aw_lock_i    ;
            assign s_data_slave_size_converted.aw_cache  = data_slave_aw_cache_i   ;
            assign s_data_slave_size_converted.aw_qos    = data_slave_aw_qos_i     ;
            assign s_data_slave_size_converted.aw_id     = data_slave_aw_id_i      ;
            assign s_data_slave_size_converted.aw_user   = data_slave_aw_user_i    ;
            assign data_slave_aw_ready_o     = s_data_slave_size_converted.aw_ready &!i_isolate_cluster;

            // READ ADDRESS CHANNEL
            assign s_data_slave_size_converted.ar_valid  = data_slave_ar_valid_i   &!i_isolate_cluster;
            assign s_data_slave_size_converted.ar_addr   = data_slave_ar_addr_i    ;
            assign s_data_slave_size_converted.ar_prot   = data_slave_ar_prot_i    ;
            assign s_data_slave_size_converted.ar_region = data_slave_ar_region_i  ;
            assign s_data_slave_size_converted.ar_len    = data_slave_ar_len_i     ;
            assign s_data_slave_size_converted.ar_size   = data_slave_ar_size_i    ;
            assign s_data_slave_size_converted.ar_burst  = data_slave_ar_burst_i   ;
            assign s_data_slave_size_converted.ar_lock   = data_slave_ar_lock_i    ;
            assign s_data_slave_size_converted.ar_cache  = data_slave_ar_cache_i   ;
            assign s_data_slave_size_converted.ar_qos    = data_slave_ar_qos_i     ;
            assign s_data_slave_size_converted.ar_id     = data_slave_ar_id_i      ;
            assign s_data_slave_size_converted.ar_user   = data_slave_ar_user_i    ;
            assign data_slave_ar_ready_o     = s_data_slave_size_converted.ar_ready &!i_isolate_cluster;

            // WRITE DATA CHANNEL
            assign s_data_slave_size_converted.w_valid = data_slave_w_valid_i   &!i_isolate_cluster;
            assign s_data_slave_size_converted.w_data  = data_slave_w_data_i    ;
            assign s_data_slave_size_converted.w_strb  = data_slave_w_strb_i    ;
            assign s_data_slave_size_converted.w_user  = data_slave_w_user_i    ;
            assign s_data_slave_size_converted.w_last  = data_slave_w_last_i    ;
            assign data_slave_w_ready_o    = s_data_slave_size_converted.w_ready &!i_isolate_cluster;

            // READ DATA CHANNEL
            assign data_slave_r_valid_o    = s_data_slave_size_converted.r_valid;
            assign data_slave_r_data_o     = s_data_slave_size_converted.r_data ;
            assign data_slave_r_resp_o     = s_data_slave_size_converted.r_resp ;
            assign data_slave_r_last_o     = s_data_slave_size_converted.r_last ;
            assign data_slave_r_id_o       = s_data_slave_size_converted.r_id   ;
            assign data_slave_r_user_o     = s_data_slave_size_converted.r_user ;
            assign s_data_slave_size_converted.r_ready = data_slave_r_ready_i   ;

            // WRITE RESPONSE CHANNEL
            assign data_slave_b_valid_o    = s_data_slave_size_converted.b_valid;
            assign data_slave_b_resp_o     = s_data_slave_size_converted.b_resp ;
            assign data_slave_b_id_o       = s_data_slave_size_converted.b_id   ;
            assign data_slave_b_user_o     = s_data_slave_size_converted.b_user ;
            assign s_data_slave_size_converted.b_ready = data_slave_b_ready_i   ;

        end else begin : gen_axi_slave_synch

            localparam int AXI_DATA_SLAVE_ADDRESS_CHANNEL_WIDTH    = AXI_ADDR_WIDTH+3+4+8+3+2+1+4+4+AXI_ID_IN_WIDTH+AXI_USER_WIDTH;
            localparam int AXI_DATA_SLAVE_WRITE_DATA_CHANNEL_WIDTH = AXI_DATA_S2C_WIDTH+AXI_STRB_S2C_WIDTH+AXI_USER_WIDTH+1;
            localparam int AXI_DATA_SLAVE_READ_DATA_CHANNEL_WIDTH  = AXI_DATA_S2C_WIDTH+2+1+AXI_ID_IN_WIDTH+AXI_USER_WIDTH;
            localparam int AXI_DATA_SLAVE_WRITE_RESP_CHANNEL_WIDTH = 2+AXI_ID_IN_WIDTH+AXI_USER_WIDTH;

            // WRITE ADDRESS CHANNEL
            logic s_data_slave_aw_queue_empty;
            logic s_data_slave_aw_queue_full;
            logic s_data_slave_aw_queue_push;
            logic s_data_slave_aw_queue_pop;
            logic [AXI_DATA_SLAVE_ADDRESS_CHANNEL_WIDTH-1:0] s_data_slave_aw_data_in;
            logic [AXI_DATA_SLAVE_ADDRESS_CHANNEL_WIDTH-1:0] s_data_slave_aw_data_out;

            assign s_data_slave_aw_data_in    = {data_slave_aw_addr_i, data_slave_aw_prot_i, data_slave_aw_region_i, data_slave_aw_len_i, data_slave_aw_size_i, data_slave_aw_burst_i, data_slave_aw_lock_i, data_slave_aw_cache_i, data_slave_aw_qos_i, data_slave_aw_id_i, data_slave_aw_user_i};
            assign {s_data_slave_size_converted.aw_addr, s_data_slave_size_converted.aw_prot, s_data_slave_size_converted.aw_region, s_data_slave_size_converted.aw_len, s_data_slave_size_converted.aw_size, s_data_slave_size_converted.aw_burst, s_data_slave_size_converted.aw_lock, s_data_slave_size_converted.aw_cache, s_data_slave_size_converted.aw_qos, s_data_slave_size_converted.aw_id, s_data_slave_size_converted.aw_user} = s_data_slave_aw_data_out;

            //  assign s_data_slave_32.aw_atop   = data_slave_aw_atop_i    ;
            //TODO: get this atomic operation signal right
            assign s_data_slave_size_converted.aw_atop    = '0;

            assign s_data_slave_size_converted.aw_valid   = !s_data_slave_aw_queue_empty;
            assign data_slave_aw_ready_o      = !s_data_slave_aw_queue_full & !i_isolate_cluster;

            assign s_data_slave_aw_queue_push = data_slave_aw_valid_i    & data_slave_aw_ready_o;
            assign s_data_slave_aw_queue_pop  = s_data_slave_size_converted.aw_valid & s_data_slave_size_converted.aw_ready;

            fifo_v3 #(
              .FALL_THROUGH (1'b0),
              .DATA_WIDTH   (AXI_DATA_SLAVE_ADDRESS_CHANNEL_WIDTH),
              .DEPTH        (2)
            ) data_slave_aw_queue_i (
              .clk_i        (i_clk),
              .rst_ni       (i_rst_n),
              .flush_i      (1'b0),
              .unpush_i     (1'b0),
              .testmode_i   (i_scan_ckgt_enable),
              // status flags
              .full_o       (s_data_slave_aw_queue_full),
              .empty_o      (s_data_slave_aw_queue_empty),
              .usage_o      (/* Not Used */),
              // as long as the queue is not full we can push new data
              .data_i       (s_data_slave_aw_data_in),
              .push_i       (s_data_slave_aw_queue_push),
              // as long as the queue is not empty we can pop new elements
              .data_o       (s_data_slave_aw_data_out),
              .pop_i        (s_data_slave_aw_queue_pop)
            );

            // READ ADDRESS CHANNEL
            logic s_data_slave_ar_queue_empty;
            logic s_data_slave_ar_queue_full;
            logic s_data_slave_ar_queue_push;
            logic s_data_slave_ar_queue_pop;
            logic [AXI_DATA_SLAVE_ADDRESS_CHANNEL_WIDTH-1:0] s_data_slave_ar_data_in;
            logic [AXI_DATA_SLAVE_ADDRESS_CHANNEL_WIDTH-1:0] s_data_slave_ar_data_out;

            assign s_data_slave_ar_data_in    = {data_slave_ar_addr_i, data_slave_ar_prot_i, data_slave_ar_region_i, data_slave_ar_len_i, data_slave_ar_size_i, data_slave_ar_burst_i, data_slave_ar_lock_i, data_slave_ar_cache_i, data_slave_ar_qos_i, data_slave_ar_id_i, data_slave_ar_user_i};
            assign {s_data_slave_size_converted.ar_addr, s_data_slave_size_converted.ar_prot, s_data_slave_size_converted.ar_region, s_data_slave_size_converted.ar_len, s_data_slave_size_converted.ar_size, s_data_slave_size_converted.ar_burst, s_data_slave_size_converted.ar_lock, s_data_slave_size_converted.ar_cache, s_data_slave_size_converted.ar_qos, s_data_slave_size_converted.ar_id, s_data_slave_size_converted.ar_user} = s_data_slave_ar_data_out;

            assign s_data_slave_size_converted.ar_valid   = !s_data_slave_ar_queue_empty;
            assign data_slave_ar_ready_o      = !s_data_slave_ar_queue_full & !i_isolate_cluster;

            assign s_data_slave_ar_queue_push = data_slave_ar_valid_i & data_slave_ar_ready_o;
            assign s_data_slave_ar_queue_pop  = s_data_slave_size_converted.ar_valid & s_data_slave_size_converted.ar_ready;

            fifo_v3 #(
              .FALL_THROUGH (1'b0),
              .DATA_WIDTH   (AXI_DATA_SLAVE_ADDRESS_CHANNEL_WIDTH),
              .DEPTH        (2)
            ) data_slave_ar_queue_i (
              .clk_i        (i_clk),
              .rst_ni       (i_rst_n),
              .flush_i      (1'b0),
              .unpush_i     (1'b0),
              .testmode_i   (i_scan_ckgt_enable),
              // status flags
              .full_o       (s_data_slave_ar_queue_full),
              .empty_o      (s_data_slave_ar_queue_empty),
              .usage_o      (/* Not Used */),
              // as long as the queue is not full we can push new data
              .data_i       (s_data_slave_ar_data_in),
              .push_i       (s_data_slave_ar_queue_push),
              // as long as the queue is not empty we can pop new elements
              .data_o       (s_data_slave_ar_data_out),
              .pop_i        (s_data_slave_ar_queue_pop)
            );

            // WRITE DATA CHANNEL
            logic s_data_slave_w_queue_empty;
            logic s_data_slave_w_queue_full;
            logic s_data_slave_w_queue_push;
            logic s_data_slave_w_queue_pop;
            logic [AXI_DATA_SLAVE_WRITE_DATA_CHANNEL_WIDTH-1:0] s_data_slave_w_data_in;
            logic [AXI_DATA_SLAVE_WRITE_DATA_CHANNEL_WIDTH-1:0] s_data_slave_w_data_out;

            assign s_data_slave_w_data_in    = {data_slave_w_data_i, data_slave_w_strb_i, data_slave_w_user_i, data_slave_w_last_i};
            assign {s_data_slave_size_converted.w_data, s_data_slave_size_converted.w_strb, s_data_slave_size_converted.w_user, s_data_slave_size_converted.w_last} = s_data_slave_w_data_out;

            assign s_data_slave_size_converted.w_valid   = !s_data_slave_w_queue_empty;
            assign data_slave_w_ready_o      = !s_data_slave_w_queue_full & !i_isolate_cluster;

            assign s_data_slave_w_queue_push = data_slave_w_valid_i    & data_slave_w_ready_o;
            assign s_data_slave_w_queue_pop  = s_data_slave_size_converted.w_valid & s_data_slave_size_converted.w_ready;

            fifo_v3 #(
              .FALL_THROUGH (1'b0),
              .DATA_WIDTH   (AXI_DATA_SLAVE_WRITE_DATA_CHANNEL_WIDTH),
              .DEPTH        (2)
            ) data_slave_w_queue_i (
              .clk_i        (i_clk),
              .rst_ni       (i_rst_n),
              .flush_i      (1'b0),
              .unpush_i     (1'b0),
              .testmode_i   (i_scan_ckgt_enable),
              // status flags
              .full_o       (s_data_slave_w_queue_full),
              .empty_o      (s_data_slave_w_queue_empty),
              .usage_o      (/* Not Used */),
              // as long as the queue is not full we can push new data
              .data_i       (s_data_slave_w_data_in),
              .push_i       (s_data_slave_w_queue_push),
              // as long as the queue is not empty we can pop new elements
              .data_o       (s_data_slave_w_data_out),
              .pop_i        (s_data_slave_w_queue_pop)
            );

            // READ DATA CHANNEL
            logic s_data_slave_r_queue_empty;
            logic s_data_slave_r_queue_full;
            logic s_data_slave_r_queue_push;
            logic s_data_slave_r_queue_pop;
            logic [AXI_DATA_SLAVE_READ_DATA_CHANNEL_WIDTH-1:0] s_data_slave_r_data_in;
            logic [AXI_DATA_SLAVE_READ_DATA_CHANNEL_WIDTH-1:0] s_data_slave_r_data_out;

            assign s_data_slave_r_data_in    = {s_data_slave_size_converted.r_data, s_data_slave_size_converted.r_resp, s_data_slave_size_converted.r_last, s_data_slave_size_converted.r_id, s_data_slave_size_converted.r_user};
            assign {data_slave_r_data_o, data_slave_r_resp_o, data_slave_r_last_o, data_slave_r_id_o, data_slave_r_user_o} = s_data_slave_r_data_out;

            assign data_slave_r_valid_o      = !s_data_slave_r_queue_empty & !i_isolate_cluster;
            assign s_data_slave_size_converted.r_ready   = !s_data_slave_r_queue_full;

            assign s_data_slave_r_queue_push = s_data_slave_size_converted.r_valid & s_data_slave_size_converted.r_ready;
            assign s_data_slave_r_queue_pop  = data_slave_r_valid_o    & data_slave_r_ready_i;

            fifo_v3 #(
              .FALL_THROUGH (1'b0),
              .DATA_WIDTH   (AXI_DATA_SLAVE_READ_DATA_CHANNEL_WIDTH),
              .DEPTH        (2)
            ) data_slave_r_queue_i (
              .clk_i        (i_clk),
              .rst_ni       (i_rst_n),
              .flush_i      (1'b0),
              .unpush_i     (1'b0),
              .testmode_i   (i_scan_ckgt_enable),
              // status flags
              .full_o       (s_data_slave_r_queue_full),
              .empty_o      (s_data_slave_r_queue_empty),
              .usage_o      (/* Not Used */),
              // as long as the queue is not full we can push new data
              .data_i       (s_data_slave_r_data_in),
              .push_i       (s_data_slave_r_queue_push),
              // as long as the queue is not empty we can pop new elements
              .data_o       (s_data_slave_r_data_out),
              .pop_i        (s_data_slave_r_queue_pop)
            );

            // WRITE RESPONSE CHANNEL
            logic s_data_slave_b_queue_empty;
            logic s_data_slave_b_queue_full;
            logic s_data_slave_b_queue_push;
            logic s_data_slave_b_queue_pop;
            logic [AXI_DATA_SLAVE_WRITE_RESP_CHANNEL_WIDTH-1:0] s_data_slave_b_data_in;
            logic [AXI_DATA_SLAVE_WRITE_RESP_CHANNEL_WIDTH-1:0] s_data_slave_b_data_out;

            assign s_data_slave_b_data_in    = {s_data_slave_size_converted.b_resp, s_data_slave_size_converted.b_id, s_data_slave_size_converted.b_user};
            assign {data_slave_b_resp_o, data_slave_b_id_o, data_slave_b_user_o} = s_data_slave_b_data_out;

            assign data_slave_b_valid_o      = !s_data_slave_b_queue_empty & !i_isolate_cluster;
            assign s_data_slave_size_converted.b_ready   = !s_data_slave_b_queue_full;

            assign s_data_slave_b_queue_push = s_data_slave_size_converted.b_valid & s_data_slave_size_converted.b_ready;
            assign s_data_slave_b_queue_pop  = data_slave_b_valid_o & data_slave_b_ready_i;

            fifo_v3 #(
              .FALL_THROUGH (1'b0),
              .DATA_WIDTH   (AXI_DATA_SLAVE_WRITE_RESP_CHANNEL_WIDTH),
              .DEPTH        (2)
            ) data_slave_b_queue_i (
              .clk_i        (i_clk),
              .rst_ni       (i_rst_n),
              .flush_i      (1'b0),
              .unpush_i     (1'b0),
              .testmode_i   (i_scan_ckgt_enable),
              // status flags
              .full_o       (s_data_slave_b_queue_full),
              .empty_o      (s_data_slave_b_queue_empty),
              .usage_o      (/* Not Used */),
              // as long as the queue is not full we can push new data
              .data_i       (s_data_slave_b_data_in),
              .push_i       (s_data_slave_b_queue_push),
              // as long as the queue is not empty we can pop new elements
              .data_o       (s_data_slave_b_data_out),
              .pop_i        (s_data_slave_b_queue_pop)
            );
            assign s_s2c_fifo_busy = ~s_data_slave_aw_queue_empty | ~s_data_slave_ar_queue_empty | ~s_data_slave_w_queue_empty | ~s_data_slave_r_queue_empty | ~s_data_slave_b_queue_empty;
        end
    endgenerate

    //***************************************
    // AXI4 MASTER
    //***************************************
    axi_busy_unit
    #(
      .COUNTER_SIZE(6)
    ) data_master_busy_unit_i (
      .clk_i       ( i_clk                             ),
      .rst_ni      ( i_rst_n                           ),

      // WRITE INTERFACE
      .aw_sync_i   ( data_master_aw_valid_o & data_master_aw_ready_i ),
      .b_sync_i    ( data_master_b_valid_i & data_master_b_ready_o    ),

      // READ INTERFACE
      .ar_sync_i   ( data_master_ar_valid_o & data_master_ar_ready_i ),
      .r_sync_i    ( data_master_r_valid_i & data_master_r_ready_o & data_master_r_last_i  ),

      // BUSY SIGNAL
      .busy_o      ( s_data_master_busy                            )
    );

    //Adding downsizer on C2S interface when needed

    generate
      if(AXI_DATA_C2S_WIDTH == 32) begin : gen_axi_master_32
        axi_dw_converter_intf #(
            .AXI_ID_WIDTH            ( AXI_ID_IN_WIDTH+2  ),
            .AXI_ADDR_WIDTH          ( AXI_ADDR_WIDTH     ),
            .AXI_SLV_PORT_DATA_WIDTH ( AXI_DATA_INT_WIDTH ), // If 64, dw_converter is pass through
            .AXI_MST_PORT_DATA_WIDTH ( AXI_DATA_C2S_WIDTH ),
            .AXI_USER_WIDTH          ( AXI_USER_WIDTH     ),
            .AXI_MAX_READS           ( 12                 ),
            .ReadDataReordering      ( 0                  ),
            .UniqueIds               ( 0                  ),
            .AxiLookBits             ( 5                  )
        ) axi_dw_c2s_downsizer_64_32_wrap_i (
            .clk_i  ( i_clk                        ),
            .rst_ni ( i_rst_n                      ),
            .slv    ( s_data_master                ),
            .mst    ( s_data_master_size_converted ),
            .busy_o ( s_c2s_down_busy              )
        );
      end else begin : no_gen_axi_master_downsizer
        `AXI_ASSIGN(s_data_master_size_converted, s_data_master) //dst, src  | slv, mst
        assign s_c2s_down_busy = 1'b0;
      end
    endgenerate

    generate
        if(!AXI_SYNCH_INTERF) begin : gen_axi_data_master_asynch

            assign s_c2s_fifo_busy          = 1'b0                   ;
            // WRITE ADDRESS CHANNEL
            assign data_master_aw_valid_o   = s_data_master_size_converted.aw_valid ;
            assign data_master_aw_addr_o    = s_data_master_size_converted.aw_addr  ;
            assign data_master_aw_prot_o    = s_data_master_size_converted.aw_prot  ;
            assign data_master_aw_region_o  = s_data_master_size_converted.aw_region;
            assign data_master_aw_len_o     = s_data_master_size_converted.aw_len   ;
            assign data_master_aw_size_o    = s_data_master_size_converted.aw_size  ;
            assign data_master_aw_burst_o   = s_data_master_size_converted.aw_burst ;
            assign data_master_aw_lock_o    = s_data_master_size_converted.aw_lock  ;
            assign data_master_aw_cache_o   = s_data_master_size_converted.aw_cache ;
            assign data_master_aw_qos_o     = s_data_master_size_converted.aw_qos   ;
            assign s_data_master_aw_id_full = s_data_master_size_converted.aw_id    ;
            assign data_master_aw_user_o    = s_data_master_size_converted.aw_user  ;
            assign s_data_master_size_converted.aw_ready   = data_master_aw_ready_i ;

            // READ ADDRESS CHANNEL
            assign data_master_ar_valid_o   = s_data_master_size_converted.ar_valid ;
            assign data_master_ar_addr_o    = s_data_master_size_converted.ar_addr  ;
            assign data_master_ar_prot_o    = s_data_master_size_converted.ar_prot  ;
            assign data_master_ar_region_o  = s_data_master_size_converted.ar_region;
            assign data_master_ar_len_o     = s_data_master_size_converted.ar_len   ;
            assign data_master_ar_size_o    = s_data_master_size_converted.ar_size  ;
            assign data_master_ar_burst_o   = s_data_master_size_converted.ar_burst ;
            assign data_master_ar_lock_o    = s_data_master_size_converted.ar_lock  ;
            assign data_master_ar_cache_o   = s_data_master_size_converted.ar_cache ;
            assign data_master_ar_qos_o     = s_data_master_size_converted.ar_qos   ;
            assign s_data_master_ar_id_full = s_data_master_size_converted.ar_id    ;
            assign data_master_ar_user_o    = s_data_master_size_converted.ar_user  ;
            assign s_data_master_size_converted.ar_ready   = data_master_ar_ready_i ;

            // WRITE DATA CHANNEL
            assign data_master_w_valid_o    = s_data_master_size_converted.w_valid  ;
            assign data_master_w_data_o     = s_data_master_size_converted.w_data   ;
            assign data_master_w_strb_o     = s_data_master_size_converted.w_strb   ;
            assign data_master_w_user_o     = s_data_master_size_converted.w_user   ;
            assign data_master_w_last_o     = s_data_master_size_converted.w_last   ;
            assign s_data_master_size_converted.w_ready    = data_master_w_ready_i  ;

            // READ DATA CHANNEL
            assign s_data_master_size_converted.r_valid    = data_master_r_valid_i  ;
            assign s_data_master_size_converted.r_data     = data_master_r_data_i   ;
            assign s_data_master_size_converted.r_resp     = data_master_r_resp_i   ;
            assign s_data_master_size_converted.r_last     = data_master_r_last_i   ;
            assign s_data_master_size_converted.r_id       = s_data_master_r_id_full;
            assign s_data_master_size_converted.r_user     = data_master_r_user_i   ;
            assign data_master_r_ready_o    = s_data_master_size_converted.r_ready  ;

            // WRITE RESPONSE CHANNEL
            assign s_data_master_size_converted.b_valid    = data_master_b_valid_i  ;
            assign s_data_master_size_converted.b_resp     = data_master_b_resp_i   ;
            assign s_data_master_size_converted.b_id       = s_data_master_b_id_full;
            assign s_data_master_size_converted.b_user     = data_master_b_user_i   ;
            assign data_master_b_ready_o    = s_data_master_size_converted.b_ready  ;

        end else begin : gen_axi_data_master_synch

            localparam int AXI_DATA_MASTER_ADDRESS_CHANNEL_WIDTH    = AXI_ADDR_WIDTH+3+4+8+3+2+1+4+4+AXI_ID_IN_WIDTH+2+AXI_USER_WIDTH;
            localparam int AXI_DATA_MASTER_WRITE_DATA_CHANNEL_WIDTH = AXI_DATA_C2S_WIDTH+AXI_STRB_C2S_WIDTH+AXI_USER_WIDTH+1;
            localparam int AXI_DATA_MASTER_READ_DATA_CHANNEL_WIDTH  = AXI_DATA_C2S_WIDTH+2+1+AXI_ID_IN_WIDTH+2+AXI_USER_WIDTH;
            localparam int AXI_DATA_MASTER_WRITE_RESP_CHANNEL_WIDTH = 2+AXI_ID_IN_WIDTH+2+AXI_USER_WIDTH;

            // WRITE ADDRESS CHANNEL
            logic s_data_master_aw_queue_empty;
            logic s_data_master_aw_queue_full;
            logic s_data_master_aw_queue_push;
            logic s_data_master_aw_queue_pop;
            logic [AXI_DATA_MASTER_ADDRESS_CHANNEL_WIDTH-1:0] s_data_master_aw_data_in;
            logic [AXI_DATA_MASTER_ADDRESS_CHANNEL_WIDTH-1:0] s_data_master_aw_data_out;

            assign s_data_master_aw_data_in    = {s_data_master_size_converted.aw_addr, s_data_master_size_converted.aw_prot, s_data_master_size_converted.aw_region, s_data_master_size_converted.aw_len, s_data_master_size_converted.aw_size, s_data_master_size_converted.aw_burst, s_data_master_size_converted.aw_lock, s_data_master_size_converted.aw_cache, s_data_master_size_converted.aw_qos, s_data_master_size_converted.aw_id, s_data_master_size_converted.aw_user};
            assign {data_master_aw_addr_o, data_master_aw_prot_o, data_master_aw_region_o, data_master_aw_len_o, data_master_aw_size_o, data_master_aw_burst_o, data_master_aw_lock_o, data_master_aw_cache_o, data_master_aw_qos_o, s_data_master_aw_id_full, data_master_aw_user_o} = s_data_master_aw_data_out;

            assign data_master_aw_valid_o      = !s_data_master_aw_queue_empty;
            assign s_data_master_size_converted.aw_ready      = !s_data_master_aw_queue_full;

            assign s_data_master_aw_queue_push = s_data_master_size_converted.aw_valid & !s_data_master_aw_queue_full;
            assign s_data_master_aw_queue_pop  = data_master_aw_valid_o & data_master_aw_ready_i;

            fifo_v3 #(
              .FALL_THROUGH (1'b0),
              .DATA_WIDTH   (AXI_DATA_MASTER_ADDRESS_CHANNEL_WIDTH),
              .DEPTH        (2)
            ) data_master_aw_queue_i (
              .clk_i        (i_clk),
              .rst_ni       (i_rst_n),
              .flush_i      (1'b0),
              .unpush_i     (1'b0),
              .testmode_i   (i_scan_ckgt_enable),
              // status flags
              .full_o       (s_data_master_aw_queue_full),
              .empty_o      (s_data_master_aw_queue_empty),
              .usage_o      (/* Not Used */),
              // as long as the queue is not full we can push new data
              .data_i       (s_data_master_aw_data_in),
              .push_i       (s_data_master_aw_queue_push),
              // as long as the queue is not empty we can pop new elements
              .data_o       (s_data_master_aw_data_out),
              .pop_i        (s_data_master_aw_queue_pop)
            );

            // READ ADDRESS CHANNEL
            logic s_data_master_ar_queue_empty;
            logic s_data_master_ar_queue_full;
            logic s_data_master_ar_queue_push;
            logic s_data_master_ar_queue_pop;
            logic [AXI_DATA_MASTER_ADDRESS_CHANNEL_WIDTH-1:0] s_data_master_ar_data_in;
            logic [AXI_DATA_MASTER_ADDRESS_CHANNEL_WIDTH-1:0] s_data_master_ar_data_out;

            assign s_data_master_ar_data_in    = {s_data_master_size_converted.ar_addr, s_data_master_size_converted.ar_prot, s_data_master_size_converted.ar_region, s_data_master_size_converted.ar_len, s_data_master_size_converted.ar_size, s_data_master_size_converted.ar_burst, s_data_master_size_converted.ar_lock, s_data_master_size_converted.ar_cache, s_data_master_size_converted.ar_qos, s_data_master_size_converted.ar_id, s_data_master_size_converted.ar_user};
            assign {data_master_ar_addr_o, data_master_ar_prot_o, data_master_ar_region_o, data_master_ar_len_o, data_master_ar_size_o, data_master_ar_burst_o, data_master_ar_lock_o, data_master_ar_cache_o, data_master_ar_qos_o, s_data_master_ar_id_full, data_master_ar_user_o} = s_data_master_ar_data_out;

            assign data_master_ar_valid_o      = !s_data_master_ar_queue_empty;
            assign s_data_master_size_converted.ar_ready      = !s_data_master_ar_queue_full;

            assign s_data_master_ar_queue_push = s_data_master_size_converted.ar_valid & !s_data_master_ar_queue_full;
            assign s_data_master_ar_queue_pop  = data_master_ar_valid_o & data_master_ar_ready_i;

            fifo_v3 #(
              .FALL_THROUGH (1'b0),
              .DATA_WIDTH   (AXI_DATA_MASTER_ADDRESS_CHANNEL_WIDTH),
              .DEPTH        (2)
            ) data_master_ar_queue_i (
              .clk_i        (i_clk),
              .rst_ni       (i_rst_n),
              .flush_i      (1'b0),
              .unpush_i     (1'b0),
              .testmode_i   (i_scan_ckgt_enable),
              // status flags
              .full_o       (s_data_master_ar_queue_full),
              .empty_o      (s_data_master_ar_queue_empty),
              .usage_o      (/* Not Used */),
              // as long as the queue is not full we can push new data
              .data_i       (s_data_master_ar_data_in),
              .push_i       (s_data_master_ar_queue_push),
              // as long as the queue is not empty we can pop new elements
              .data_o       (s_data_master_ar_data_out),
              .pop_i        (s_data_master_ar_queue_pop)
            );

            // WRITE DATA CHANNEL
            logic s_data_master_w_queue_empty;
            logic s_data_master_w_queue_full;
            logic s_data_master_w_queue_push;
            logic s_data_master_w_queue_pop;
            logic [AXI_DATA_MASTER_WRITE_DATA_CHANNEL_WIDTH-1:0] s_data_master_w_data_in;
            logic [AXI_DATA_MASTER_WRITE_DATA_CHANNEL_WIDTH-1:0] s_data_master_w_data_out;

            assign s_data_master_w_data_in    = {s_data_master_size_converted.w_data, s_data_master_size_converted.w_strb, s_data_master_size_converted.w_user, s_data_master_size_converted.w_last};
            assign {data_master_w_data_o, data_master_w_strb_o, data_master_w_user_o, data_master_w_last_o} = s_data_master_w_data_out;

            assign data_master_w_valid_o      = !s_data_master_w_queue_empty;
            assign s_data_master_size_converted.w_ready      = !s_data_master_w_queue_full;

            assign s_data_master_w_queue_push = s_data_master_size_converted.w_valid & !s_data_master_w_queue_full;
            assign s_data_master_w_queue_pop  = data_master_w_valid_o & data_master_w_ready_i;

            fifo_v3 #(
              .FALL_THROUGH (1'b0),
              .DATA_WIDTH   (AXI_DATA_MASTER_WRITE_DATA_CHANNEL_WIDTH),
              .DEPTH        (2)
            ) data_master_w_queue_i (
              .clk_i        (i_clk),
              .rst_ni       (i_rst_n),
              .flush_i      (1'b0),
              .unpush_i     (1'b0),
              .testmode_i   (i_scan_ckgt_enable),
              // status flags
              .full_o       (s_data_master_w_queue_full),
              .empty_o      (s_data_master_w_queue_empty),
              .usage_o      (/* Not Used */),
              // as long as the queue is not full we can push new data
              .data_i       (s_data_master_w_data_in),
              .push_i       (s_data_master_w_queue_push),
              // as long as the queue is not empty we can pop new elements
              .data_o       (s_data_master_w_data_out),
              .pop_i        (s_data_master_w_queue_pop)
            );

            // READ DATA CHANNEL
            logic s_data_master_r_queue_empty;
            logic s_data_master_r_queue_full;
            logic s_data_master_r_queue_push;
            logic s_data_master_r_queue_pop;
            logic [AXI_DATA_MASTER_READ_DATA_CHANNEL_WIDTH-1:0] s_data_master_r_data_in;
            logic [AXI_DATA_MASTER_READ_DATA_CHANNEL_WIDTH-1:0] s_data_master_r_data_out;

            assign s_data_master_r_data_in    = {data_master_r_data_i, data_master_r_resp_i, data_master_r_last_i, s_data_master_r_id_full, data_master_r_user_i};
            assign {s_data_master_size_converted.r_data, s_data_master_size_converted.r_resp, s_data_master_size_converted.r_last, s_data_master_size_converted.r_id, s_data_master_size_converted.r_user} = s_data_master_r_data_out;

            assign s_data_master_size_converted.r_valid      = !s_data_master_r_queue_empty;
            assign data_master_r_ready_o      = !s_data_master_r_queue_full;

            assign s_data_master_r_queue_push = data_master_r_valid_i & data_master_r_ready_o;
            assign s_data_master_r_queue_pop  = s_data_master_size_converted.r_valid & s_data_master_size_converted.r_ready;

            fifo_v3 #(
              .FALL_THROUGH (1'b0),
              .DATA_WIDTH   (AXI_DATA_MASTER_READ_DATA_CHANNEL_WIDTH),
              .DEPTH        (2)
            ) data_master_r_queue_i (
              .clk_i        (i_clk),
              .rst_ni       (i_rst_n),
              .flush_i      (1'b0),
              .unpush_i     (1'b0),
              .testmode_i   (i_scan_ckgt_enable),
              // status flags
              .full_o       (s_data_master_r_queue_full),
              .empty_o      (s_data_master_r_queue_empty),
              .usage_o      (/* Not Used */),
              // as long as the queue is not full we can push new data
              .data_i       (s_data_master_r_data_in),
              .push_i       (s_data_master_r_queue_push),
              // as long as the queue is not empty we can pop new elements
              .data_o       (s_data_master_r_data_out),
              .pop_i        (s_data_master_r_queue_pop)
            );

            // WRITE RESPONSE CHANNEL
            logic s_data_master_b_queue_empty;
            logic s_data_master_b_queue_full;
            logic s_data_master_b_queue_push;
            logic s_data_master_b_queue_pop;
            logic [AXI_DATA_MASTER_WRITE_RESP_CHANNEL_WIDTH-1:0] s_data_master_b_data_in;
            logic [AXI_DATA_MASTER_WRITE_RESP_CHANNEL_WIDTH-1:0] s_data_master_b_data_out;

            assign s_data_master_b_data_in    = {data_master_b_resp_i, s_data_master_b_id_full, data_master_b_user_i};
            assign {s_data_master_size_converted.b_resp, s_data_master_size_converted.b_id, s_data_master_size_converted.b_user} = s_data_master_b_data_out;

            assign s_data_master_size_converted.b_valid      = !s_data_master_b_queue_empty;
            assign data_master_b_ready_o      = !s_data_master_b_queue_full;

            assign s_data_master_b_queue_push = data_master_b_valid_i & data_master_b_ready_o;
            assign s_data_master_b_queue_pop  = s_data_master_size_converted.b_valid & s_data_master_size_converted.b_ready;

            fifo_v3 #(
              .FALL_THROUGH (1'b0),
              .DATA_WIDTH   (AXI_DATA_MASTER_WRITE_RESP_CHANNEL_WIDTH),
              .DEPTH        (2)
            ) data_master_b_queue_i (
              .clk_i        (i_clk),
              .rst_ni       (i_rst_n),
              .flush_i      (1'b0),
              .unpush_i     (1'b0),
              .testmode_i   (i_scan_ckgt_enable),
              // status flags
              .full_o       (s_data_master_b_queue_full),
              .empty_o      (s_data_master_b_queue_empty),
              .usage_o      (/* Not Used */),
              // as long as the queue is not full we can push new data
              .data_i       (s_data_master_b_data_in),
              .push_i       (s_data_master_b_queue_push),
              // as long as the queue is not empty we can pop new elements
              .data_o       (s_data_master_b_data_out),
              .pop_i        (s_data_master_b_queue_pop)
            );
            assign s_c2s_fifo_busy = ~s_data_master_aw_queue_empty | ~s_data_master_ar_queue_empty | ~s_data_master_w_queue_empty | ~s_data_master_r_queue_empty | ~s_data_master_b_queue_empty;
        end
    endgenerate

    generate
        if (USE_DEDICATED_INSTR_IF) begin : g_bus_wrap_slave3
          axi_busy_unit
          #(
              .COUNTER_SIZE(6)
          ) instr_master_busy_unit_i (
              .clk_i       ( i_clk                             ),
              .rst_ni      ( i_rst_n                           ),

              // WRITE INTERFACE
              .aw_sync_i   ( instr_master_aw_valid_o & instr_master_aw_ready_i ),
              .b_sync_i    ( instr_master_b_valid_i & instr_master_b_ready_o    ),

              // READ INTERFACE
              .ar_sync_i   ( instr_master_ar_valid_o & instr_master_ar_ready_i ),
              .r_sync_i    ( instr_master_r_valid_i & instr_master_r_ready_o & instr_master_r_last_i  ),

              // BUSY SIGNAL
              .busy_o      ( s_instr_master_busy                            )
          );

            assign s_instr_select.aw_id     = '0;
            assign s_instr_select.aw_addr   = '0;
            assign s_instr_select.aw_len    = '0;
            assign s_instr_select.aw_size   = '0;
            assign s_instr_select.aw_burst  = '0;
            assign s_instr_select.aw_lock   = '0;
            assign s_instr_select.aw_cache  = '0;
            assign s_instr_select.aw_prot   = '0;
            assign s_instr_select.aw_qos    = '0;
            assign s_instr_select.aw_region = '0;
            assign s_instr_select.aw_atop   = '0;
            assign s_instr_select.aw_user   = '0;
            assign s_instr_select.aw_valid  = '0;

            assign s_instr_select.w_data    = '0;
            assign s_instr_select.w_strb    = '0;
            assign s_instr_select.w_last    = '0;
            assign s_instr_select.w_user    = '0;
            assign s_instr_select.w_valid   = '0;

            assign s_instr_select.b_ready   = '0;

            assign s_instr_select.ar_id     = '0;
            assign s_instr_select.ar_addr   = '0;
            assign s_instr_select.ar_len    = '0;
            assign s_instr_select.ar_size   = '0;
            assign s_instr_select.ar_burst  = '0;
            assign s_instr_select.ar_lock   = '0;
            assign s_instr_select.ar_cache  = '0;
            assign s_instr_select.ar_prot   = '0;
            assign s_instr_select.ar_qos    = '0;
            assign s_instr_select.ar_region = '0;
            assign s_instr_select.ar_user   = '0;
            assign s_instr_select.ar_valid  = '0;

            assign s_instr_select.r_ready   = '0;

        end else begin : g_bus_wrap_slave4
            assign s_instr_master_busy      = 1'b0;

            assign s_instr_select.aw_id     = core_instr_bus.aw_id    ;
            assign s_instr_select.aw_addr   = core_instr_bus.aw_addr  ;
            assign s_instr_select.aw_len    = core_instr_bus.aw_len   ;
            assign s_instr_select.aw_size   = core_instr_bus.aw_size  ;
            assign s_instr_select.aw_burst  = core_instr_bus.aw_burst ;
            assign s_instr_select.aw_lock   = core_instr_bus.aw_lock  ;
            assign s_instr_select.aw_cache  = core_instr_bus.aw_cache ;
            assign s_instr_select.aw_prot   = core_instr_bus.aw_prot  ;
            assign s_instr_select.aw_qos    = core_instr_bus.aw_qos   ;
            assign s_instr_select.aw_region = core_instr_bus.aw_region;
            assign s_instr_select.aw_atop   = core_instr_bus.aw_atop  ;
            assign s_instr_select.aw_user   = core_instr_bus.aw_user  ;
            assign s_instr_select.aw_valid  = core_instr_bus.aw_valid ;
            assign core_instr_bus.aw_ready  = s_instr_select.aw_ready ;

            assign s_instr_select.w_data    = core_instr_bus.w_data ;
            assign s_instr_select.w_strb    = core_instr_bus.w_strb ;
            assign s_instr_select.w_last    = core_instr_bus.w_last ;
            assign s_instr_select.w_user    = core_instr_bus.w_user ;
            assign s_instr_select.w_valid   = core_instr_bus.w_valid;
            assign core_instr_bus.w_ready   = s_instr_select.w_ready;

            assign core_instr_bus.b_id      = s_instr_select.b_id   ;
            assign core_instr_bus.b_resp    = s_instr_select.b_resp ;
            assign core_instr_bus.b_user    = s_instr_select.b_user ;
            assign core_instr_bus.b_valid   = s_instr_select.b_valid;
            assign s_instr_select.b_ready   = core_instr_bus.b_ready;

            assign s_instr_select.ar_id     = core_instr_bus.ar_id    ;
            assign s_instr_select.ar_addr   = core_instr_bus.ar_addr  ;
            assign s_instr_select.ar_len    = core_instr_bus.ar_len   ;
            assign s_instr_select.ar_size   = core_instr_bus.ar_size  ;
            assign s_instr_select.ar_burst  = core_instr_bus.ar_burst ;
            assign s_instr_select.ar_lock   = core_instr_bus.ar_lock  ;
            assign s_instr_select.ar_cache  = core_instr_bus.ar_cache ;
            assign s_instr_select.ar_prot   = core_instr_bus.ar_prot  ;
            assign s_instr_select.ar_qos    = core_instr_bus.ar_qos   ;
            assign s_instr_select.ar_region = core_instr_bus.ar_region;
            assign s_instr_select.ar_user   = core_instr_bus.ar_user  ;
            assign s_instr_select.ar_valid  = core_instr_bus.ar_valid ;
            assign core_instr_bus.ar_ready  = s_instr_select.ar_ready ;

            assign core_instr_bus.r_id      = s_instr_select.r_id   ;
            assign core_instr_bus.r_data    = s_instr_select.r_data ;
            assign core_instr_bus.r_resp    = s_instr_select.r_resp ;
            assign core_instr_bus.r_last    = s_instr_select.r_last ;
            assign core_instr_bus.r_user    = s_instr_select.r_user ;
            assign core_instr_bus.r_valid   = s_instr_select.r_valid;
            assign s_instr_select.r_ready   = core_instr_bus.r_ready;

            //***************************************
            // INSTR MASTER
            //***************************************
            // WRITE ADDRESS CHANNEL
            assign instr_master_aw_valid_o   = '0;
            assign instr_master_aw_addr_o    = '0;
            assign instr_master_aw_prot_o    = '0;
            assign instr_master_aw_region_o  = '0;
            assign instr_master_aw_len_o     = '0;
            assign instr_master_aw_size_o    = '0;
            assign instr_master_aw_burst_o   = '0;
            assign instr_master_aw_lock_o    = '0;
            assign instr_master_aw_cache_o   = '0;
            assign instr_master_aw_qos_o     = '0;
            assign instr_master_aw_id_o      = '0;
            assign instr_master_aw_user_o    = '0;

            // READ ADDRESS CHANNEL
            assign instr_master_ar_valid_o   = '0;
            assign instr_master_ar_addr_o    = '0;
            assign instr_master_ar_prot_o    = '0;
            assign instr_master_ar_region_o  = '0;
            assign instr_master_ar_len_o     = '0;
            assign instr_master_ar_size_o    = '0;
            assign instr_master_ar_burst_o   = '0;
            assign instr_master_ar_lock_o    = '0;
            assign instr_master_ar_cache_o   = '0;
            assign instr_master_ar_qos_o     = '0;
            assign instr_master_ar_id_o      = '0;
            assign instr_master_ar_user_o    = '0;

            // WRITE DATA CHANNEL
            assign instr_master_w_valid_o    = '0;
            assign instr_master_w_data_o     = '0;
            assign instr_master_w_strb_o     = '0;
            assign instr_master_w_user_o     = '0;
            assign instr_master_w_last_o     = '0;

            // READ DATA CHANNEL
            assign instr_master_r_ready_o    = '0;

            // WRITE RESPONSE CHANNEL
            assign instr_master_b_ready_o    = '0;

        end
    endgenerate

    generate
      if(USE_DEDICATED_INSTR_IF & AXI_INSTR_WIDTH == 32) begin : gen_axi_instr_master_32
        axi_dw_converter_intf #(
            .AXI_ID_WIDTH            ( AXI_ID_IC_WIDTH    ),
            .AXI_ADDR_WIDTH          ( AXI_ADDR_WIDTH     ),
            .AXI_SLV_PORT_DATA_WIDTH ( AXI_DATA_INT_WIDTH ),
            .AXI_MST_PORT_DATA_WIDTH ( AXI_INSTR_WIDTH    ),
            .AXI_USER_WIDTH          ( AXI_USER_WIDTH     ),
            .AXI_MAX_READS           ( 4                  ),
            .ReadDataReordering      ( 0                  ),
            .UniqueIds               ( 0                  ),
            .AxiLookBits             ( 5                  )
        ) axi_dw_c2s_instr_downsizer_64_32_wrap_i (
            .clk_i  ( i_clk                         ),
            .rst_ni ( i_rst_n                       ),
            .slv    ( core_instr_bus                ),
            .mst    ( core_instr_bus_size_converted ),
            .busy_o ( s_instr_down_busy             )
        );
      end else if (USE_DEDICATED_INSTR_IF & AXI_INSTR_WIDTH == 64) begin : no_gen_axi_instr_master_downsizer
          `AXI_ASSIGN(core_instr_bus_size_converted, core_instr_bus) //dst, src  | slv, mst
          assign s_instr_down_busy = 1'b0;
      end else begin //No dedicated interface, busy still need to be driven
          assign s_instr_down_busy = 1'b0;
      end
    endgenerate

    generate
        if(USE_DEDICATED_INSTR_IF & !AXI_SYNCH_INTERF) begin : gen_axi_instr_master_asynch

            assign s_inst_fifo_busy          = 1'b0                    ;
            //***************************************
            // INSTR MASTER
            //***************************************
            // WRITE ADDRESS CHANNEL
            assign instr_master_aw_valid_o   = core_instr_bus_size_converted.aw_valid ;
            assign instr_master_aw_addr_o    = core_instr_bus_size_converted.aw_addr  ;
            assign instr_master_aw_prot_o    = core_instr_bus_size_converted.aw_prot  ;
            assign instr_master_aw_region_o  = core_instr_bus_size_converted.aw_region;
            assign instr_master_aw_len_o     = core_instr_bus_size_converted.aw_len   ;
            assign instr_master_aw_size_o    = core_instr_bus_size_converted.aw_size  ;
            assign instr_master_aw_burst_o   = core_instr_bus_size_converted.aw_burst ;
            assign instr_master_aw_lock_o    = core_instr_bus_size_converted.aw_lock  ;
            assign instr_master_aw_cache_o   = core_instr_bus_size_converted.aw_cache ;
            assign instr_master_aw_qos_o     = core_instr_bus_size_converted.aw_qos   ;
            assign instr_master_aw_id_o      = core_instr_bus_size_converted.aw_id    ;
            assign instr_master_aw_user_o    = core_instr_bus_size_converted.aw_user  ;
            assign core_instr_bus_size_converted.aw_ready   = instr_master_aw_ready_i ;

            // READ ADDRESS CHANNEL
            assign instr_master_ar_valid_o   = core_instr_bus_size_converted.ar_valid ;
            assign instr_master_ar_addr_o    = core_instr_bus_size_converted.ar_addr  ;
            assign instr_master_ar_prot_o    = core_instr_bus_size_converted.ar_prot  ;
            assign instr_master_ar_region_o  = core_instr_bus_size_converted.ar_region;
            assign instr_master_ar_len_o     = core_instr_bus_size_converted.ar_len   ;
            assign instr_master_ar_size_o    = core_instr_bus_size_converted.ar_size  ;
            assign instr_master_ar_burst_o   = core_instr_bus_size_converted.ar_burst ;
            assign instr_master_ar_lock_o    = core_instr_bus_size_converted.ar_lock  ;
            assign instr_master_ar_cache_o   = core_instr_bus_size_converted.ar_cache ;
            assign instr_master_ar_qos_o     = core_instr_bus_size_converted.ar_qos   ;
            assign instr_master_ar_id_o      = core_instr_bus_size_converted.ar_id    ;
            assign instr_master_ar_user_o    = core_instr_bus_size_converted.ar_user  ;
            assign core_instr_bus_size_converted.ar_ready   = instr_master_ar_ready_i ;

            // WRITE DATA CHANNEL
            assign instr_master_w_valid_o    = core_instr_bus_size_converted.w_valid  ;
            assign instr_master_w_data_o     = core_instr_bus_size_converted.w_data   ;
            assign instr_master_w_strb_o     = core_instr_bus_size_converted.w_strb   ;
            assign instr_master_w_user_o     = core_instr_bus_size_converted.w_user   ;
            assign instr_master_w_last_o     = core_instr_bus_size_converted.w_last   ;
            assign core_instr_bus_size_converted.w_ready    = instr_master_w_ready_i  ;

            // READ DATA CHANNEL
            assign core_instr_bus_size_converted.r_valid    = instr_master_r_valid_i  ;
            assign core_instr_bus_size_converted.r_data     = instr_master_r_data_i   ;
            assign core_instr_bus_size_converted.r_resp     = instr_master_r_resp_i   ;
            assign core_instr_bus_size_converted.r_last     = instr_master_r_last_i   ;
            assign core_instr_bus_size_converted.r_id       = instr_master_r_id_i     ;
            assign core_instr_bus_size_converted.r_user     = instr_master_r_user_i   ;
            assign instr_master_r_ready_o    = core_instr_bus_size_converted.r_ready  ;

            // WRITE RESPONSE CHANNEL
            assign core_instr_bus_size_converted.b_valid    = instr_master_b_valid_i  ;
            assign core_instr_bus_size_converted.b_resp     = instr_master_b_resp_i   ;
            assign core_instr_bus_size_converted.b_id       = instr_master_b_id_i     ;
            assign core_instr_bus_size_converted.b_user     = instr_master_b_user_i   ;
            assign instr_master_b_ready_o    = core_instr_bus_size_converted.b_ready  ;

        end else if(USE_DEDICATED_INSTR_IF & AXI_SYNCH_INTERF) begin : gen_axi_instr_master_synch

            localparam int AXI_INSTR_MASTER_ADDRESS_CHANNEL_WIDTH    = AXI_ADDR_WIDTH+3+4+8+3+2+1+4+4+AXI_ID_IC_WIDTH+2+AXI_USER_WIDTH;
            //addr + prot + region + len + size + burst + lock + cache + qos + id + user
            localparam int AXI_INSTR_MASTER_WRITE_DATA_CHANNEL_WIDTH = AXI_INSTR_WIDTH+AXI_STRB_INSTR_WIDTH+AXI_USER_WIDTH+1;
            localparam int AXI_INSTR_MASTER_READ_DATA_CHANNEL_WIDTH  = AXI_INSTR_WIDTH+2+1+AXI_ID_IC_WIDTH+2+AXI_USER_WIDTH;
            localparam int AXI_INSTR_MASTER_WRITE_RESP_CHANNEL_WIDTH = 2+AXI_ID_IC_WIDTH+2+AXI_USER_WIDTH;

            //***************************************
            // INSTR MASTER
            //***************************************
            // WRITE ADDRESS CHANNEL
            logic s_instr_master_aw_queue_empty;
            logic s_instr_master_aw_queue_full;
            logic s_instr_master_aw_queue_push;
            logic s_instr_master_aw_queue_pop;

            logic [AXI_INSTR_MASTER_ADDRESS_CHANNEL_WIDTH-1:0] s_instr_master_aw_data_in;
            logic [AXI_INSTR_MASTER_ADDRESS_CHANNEL_WIDTH-1:0] s_instr_master_aw_data_out;

            assign s_instr_master_aw_data_in    = {core_instr_bus_size_converted.aw_addr, core_instr_bus_size_converted.aw_prot, core_instr_bus_size_converted.aw_region, core_instr_bus_size_converted.aw_len, core_instr_bus_size_converted.aw_size, core_instr_bus_size_converted.aw_burst, core_instr_bus_size_converted.aw_lock, core_instr_bus_size_converted.aw_cache, core_instr_bus_size_converted.aw_qos, core_instr_bus_size_converted.aw_id, core_instr_bus_size_converted.aw_user};
            assign {instr_master_aw_addr_o, instr_master_aw_prot_o, instr_master_aw_region_o, instr_master_aw_len_o, instr_master_aw_size_o, instr_master_aw_burst_o, instr_master_aw_lock_o, instr_master_aw_cache_o, instr_master_aw_qos_o, instr_master_aw_id_o, instr_master_aw_user_o} = s_instr_master_aw_data_out;

            assign instr_master_aw_valid_o      = !s_instr_master_aw_queue_empty;
            assign core_instr_bus_size_converted.aw_ready      = !s_instr_master_aw_queue_full;

            assign s_instr_master_aw_queue_push = core_instr_bus_size_converted.aw_valid & !s_instr_master_aw_queue_full;
            assign s_instr_master_aw_queue_pop  = instr_master_aw_valid_o & instr_master_aw_ready_i;

            fifo_v3 #(
              .FALL_THROUGH (1'b0),
              .DATA_WIDTH   (AXI_INSTR_MASTER_ADDRESS_CHANNEL_WIDTH),
              .DEPTH        (2)
            ) instr_master_aw_queue_i (
              .clk_i        (i_clk),
              .rst_ni       (i_rst_n),
              .flush_i      (1'b0),
              .unpush_i     (1'b0),
              .testmode_i   (i_scan_ckgt_enable),
              // status flags
              .full_o       (s_instr_master_aw_queue_full),
              .empty_o      (s_instr_master_aw_queue_empty),
              .usage_o      (/* Not Used */),
              // as long as the queue is not full we can push new data
              .data_i       (s_instr_master_aw_data_in),
              .push_i       (s_instr_master_aw_queue_push),
              // as long as the queue is not empty we can pop new elements
              .data_o       (s_instr_master_aw_data_out),
              .pop_i        (s_instr_master_aw_queue_pop)
            );

            // READ ADDRESS CHANNEL
            logic s_instr_master_ar_queue_empty;
            logic s_instr_master_ar_queue_full;
            logic s_instr_master_ar_queue_push;
            logic s_instr_master_ar_queue_pop;
            logic [AXI_INSTR_MASTER_ADDRESS_CHANNEL_WIDTH-1:0] s_instr_master_ar_data_in;
            logic [AXI_INSTR_MASTER_ADDRESS_CHANNEL_WIDTH-1:0] s_instr_master_ar_data_out;

            assign s_instr_master_ar_data_in    = {core_instr_bus_size_converted.ar_addr, core_instr_bus_size_converted.ar_prot, core_instr_bus_size_converted.ar_region, core_instr_bus_size_converted.ar_len, core_instr_bus_size_converted.ar_size, core_instr_bus_size_converted.ar_burst, core_instr_bus_size_converted.ar_lock, core_instr_bus_size_converted.ar_cache, core_instr_bus_size_converted.ar_qos, core_instr_bus_size_converted.ar_id, core_instr_bus_size_converted.ar_user};
            assign {instr_master_ar_addr_o, instr_master_ar_prot_o, instr_master_ar_region_o, instr_master_ar_len_o, instr_master_ar_size_o, instr_master_ar_burst_o, instr_master_ar_lock_o, instr_master_ar_cache_o, instr_master_ar_qos_o, instr_master_ar_id_o, instr_master_ar_user_o} = s_instr_master_ar_data_out;

            assign instr_master_ar_valid_o      = !s_instr_master_ar_queue_empty;
            assign core_instr_bus_size_converted.ar_ready      = !s_instr_master_ar_queue_full;

            assign s_instr_master_ar_queue_push = core_instr_bus_size_converted.ar_valid & !s_instr_master_ar_queue_full;
            assign s_instr_master_ar_queue_pop  = instr_master_ar_valid_o & instr_master_ar_ready_i;

            fifo_v3 #(
              .FALL_THROUGH (1'b0),
              .DATA_WIDTH   (AXI_INSTR_MASTER_ADDRESS_CHANNEL_WIDTH),
              .DEPTH        (2)
            ) instr_master_ar_queue_i (
              .clk_i        (i_clk),
              .rst_ni       (i_rst_n),
              .flush_i      (1'b0),
              .unpush_i     (1'b0),
              .testmode_i   (i_scan_ckgt_enable),
              // status flags
              .full_o       (s_instr_master_ar_queue_full),
              .empty_o      (s_instr_master_ar_queue_empty),
              .usage_o      (/* Not Used */),
              // as long as the queue is not full we can push new data
              .data_i       (s_instr_master_ar_data_in),
              .push_i       (s_instr_master_ar_queue_push),
              // as long as the queue is not empty we can pop new elements
              .data_o       (s_instr_master_ar_data_out),
              .pop_i        (s_instr_master_ar_queue_pop)
            );

            // WRITE DATA CHANNEL
            logic s_instr_master_w_queue_empty;
            logic s_instr_master_w_queue_full;
            logic s_instr_master_w_queue_push;
            logic s_instr_master_w_queue_pop;
            logic [AXI_INSTR_MASTER_WRITE_DATA_CHANNEL_WIDTH-1:0] s_instr_master_w_data_in;
            logic [AXI_INSTR_MASTER_WRITE_DATA_CHANNEL_WIDTH-1:0] s_instr_master_w_data_out;

            assign s_instr_master_w_data_in    = {core_instr_bus_size_converted.w_data, core_instr_bus_size_converted.w_strb, core_instr_bus_size_converted.w_user, core_instr_bus_size_converted.w_last};
            assign {instr_master_w_data_o, instr_master_w_strb_o, instr_master_w_user_o, instr_master_w_last_o} = s_instr_master_w_data_out;

            assign instr_master_w_valid_o      = !s_instr_master_w_queue_empty;
            assign core_instr_bus_size_converted.w_ready      = !s_instr_master_w_queue_full;

            assign s_instr_master_w_queue_push = core_instr_bus_size_converted.w_valid & !s_instr_master_w_queue_full;
            assign s_instr_master_w_queue_pop  = instr_master_w_valid_o & instr_master_w_ready_i;

            fifo_v3 #(
              .FALL_THROUGH (1'b0),
              .DATA_WIDTH   (AXI_INSTR_MASTER_WRITE_DATA_CHANNEL_WIDTH),
              .DEPTH        (2)
            ) instr_master_w_queue_i (
              .clk_i        (i_clk),
              .rst_ni       (i_rst_n),
              .flush_i      (1'b0),
              .unpush_i     (1'b0),
              .testmode_i   (i_scan_ckgt_enable),
              // status flags
              .full_o       (s_instr_master_w_queue_full),
              .empty_o      (s_instr_master_w_queue_empty),
              .usage_o      (/* Not Used */),
              // as long as the queue is not full we can push new data
              .data_i       (s_instr_master_w_data_in),
              .push_i       (s_instr_master_w_queue_push),
              // as long as the queue is not empty we can pop new elements
              .data_o       (s_instr_master_w_data_out),
              .pop_i        (s_instr_master_w_queue_pop)
            );

            // READ DATA CHANNEL
            logic s_instr_master_r_queue_empty;
            logic s_instr_master_r_queue_full;
            logic s_instr_master_r_queue_push;
            logic s_instr_master_r_queue_pop;
            logic [AXI_INSTR_MASTER_READ_DATA_CHANNEL_WIDTH-1:0] s_instr_master_r_data_in;
            logic [AXI_INSTR_MASTER_READ_DATA_CHANNEL_WIDTH-1:0] s_instr_master_r_data_out;

            assign s_instr_master_r_data_in    = {instr_master_r_data_i, instr_master_r_resp_i, instr_master_r_last_i, instr_master_r_id_i, instr_master_r_user_i};
            assign {core_instr_bus_size_converted.r_data, core_instr_bus_size_converted.r_resp, core_instr_bus_size_converted.r_last, core_instr_bus_size_converted.r_id, core_instr_bus_size_converted.r_user} = s_instr_master_r_data_out;

            assign core_instr_bus_size_converted.r_valid      = !s_instr_master_r_queue_empty;
            assign instr_master_r_ready_o      = !s_instr_master_r_queue_full;

            assign s_instr_master_r_queue_push = instr_master_r_valid_i & instr_master_r_ready_o;
            assign s_instr_master_r_queue_pop  = core_instr_bus_size_converted.r_valid & core_instr_bus_size_converted.r_ready;

            fifo_v3 #(
              .FALL_THROUGH (1'b0),
              .DATA_WIDTH   (AXI_INSTR_MASTER_READ_DATA_CHANNEL_WIDTH),
              .DEPTH        (2)
            ) instr_master_r_queue_i (
              .clk_i        (i_clk),
              .rst_ni       (i_rst_n),
              .flush_i      (1'b0),
              .unpush_i     (1'b0),
              .testmode_i   (i_scan_ckgt_enable),
              // status flags
              .full_o       (s_instr_master_r_queue_full),
              .empty_o      (s_instr_master_r_queue_empty),
              .usage_o      (/* Not Used */),
              // as long as the queue is not full we can push new data
              .data_i       (s_instr_master_r_data_in),
              .push_i       (s_instr_master_r_queue_push),
              // as long as the queue is not empty we can pop new elements
              .data_o       (s_instr_master_r_data_out),
              .pop_i        (s_instr_master_r_queue_pop)
            );

            // WRITE RESPONSE CHANNEL
            logic s_instr_master_b_queue_empty;
            logic s_instr_master_b_queue_full;
            logic s_instr_master_b_queue_push;
            logic s_instr_master_b_queue_pop;
            logic [AXI_INSTR_MASTER_WRITE_RESP_CHANNEL_WIDTH-1:0] s_instr_master_b_data_in;
            logic [AXI_INSTR_MASTER_WRITE_RESP_CHANNEL_WIDTH-1:0] s_instr_master_b_data_out;

            assign s_instr_master_b_data_in    = {instr_master_b_resp_i, instr_master_b_id_i, instr_master_b_user_i};
            assign {core_instr_bus_size_converted.b_resp, core_instr_bus_size_converted.b_id, core_instr_bus_size_converted.b_user} = s_instr_master_b_data_out;

            assign core_instr_bus_size_converted.b_valid      = !s_instr_master_b_queue_empty;
            assign instr_master_b_ready_o      = !s_instr_master_b_queue_full;

            assign s_instr_master_b_queue_push = instr_master_b_valid_i & instr_master_b_ready_o;
            assign s_instr_master_b_queue_pop  = core_instr_bus_size_converted.b_valid & core_instr_bus_size_converted.b_ready;

            fifo_v3 #(
              .FALL_THROUGH (1'b0),
              .DATA_WIDTH   (AXI_INSTR_MASTER_WRITE_RESP_CHANNEL_WIDTH),
              .DEPTH        (2)
            ) instr_master_b_queue_i (
              .clk_i        (i_clk),
              .rst_ni       (i_rst_n),
              .flush_i      (1'b0),
              .unpush_i     (1'b0),
              .testmode_i   (i_scan_ckgt_enable),
              // status flags
              .full_o       (s_instr_master_b_queue_full),
              .empty_o      (s_instr_master_b_queue_empty),
              .usage_o      (/* Not Used */),
              // as long as the queue is not full we can push new data
              .data_i       (s_instr_master_b_data_in),
              .push_i       (s_instr_master_b_queue_push),
              // as long as the queue is not empty we can pop new elements
              .data_o       (s_instr_master_b_data_out),
              .pop_i        (s_instr_master_b_queue_pop)
            );

            assign s_inst_fifo_busy = ~s_instr_master_aw_queue_empty | ~s_instr_master_ar_queue_empty | ~s_instr_master_r_queue_empty | ~s_instr_master_w_queue_empty | ~s_instr_master_b_queue_empty;
        end else begin
          assign s_inst_fifo_busy = 1'b0;
        end
    endgenerate

endmodule

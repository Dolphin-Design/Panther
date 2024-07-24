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

//==============================================================================
//
//      Function: Panther testbench
//
//==============================================================================

//******************************************************************************
// TB specific include
//******************************************************************************

`include "sv_axi_interface.sv"
`include "test_code.sv"

//******************************************************************************
// Includes
//******************************************************************************

import panther_global_config_pkg::* ;


module panther_top_tb ();

    localparam int BASE_ADDR_WIDTH  = 10;
    localparam int EVNT_WIDTH       = 8;


    //******************************************************************************
    //
    // ███████╗██╗ ██████╗ ███╗   ██╗ █████╗ ██╗     ███████╗
    // ██╔════╝██║██╔════╝ ████╗  ██║██╔══██╗██║     ██╔════╝
    // ███████╗██║██║  ███╗██╔██╗ ██║███████║██║     ███████╗
    // ╚════██║██║██║   ██║██║╚██╗██║██╔══██║██║     ╚════██║
    // ███████║██║╚██████╔╝██║ ╚████║██║  ██║███████╗███████║
    // ╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝╚══════╝
    //
    //******************************************************************************
    //****************************************************************************
    // Clocks and resets
    //****************************************************************************
    logic sys_clk ;
    logic ref_clk ;
    logic rst_n   ;

    //****************************************************************************
    // DFT
    //****************************************************************************
    logic w_test_mode        ;
    logic w_scan_ckgt_enable ;

    //****************************************************************************
    // Control
    //****************************************************************************
    logic [BASE_ADDR_WIDTH-1:0]  w_base_addr  ;
    logic                        w_en_sa_boot ;
    logic                        w_fetch_en   ;

    //****************************************************************************
    // Status
    //****************************************************************************
    logic w_busy ;
    logic w_eoc  ;

    //****************************************************************************
    // Debug
    //****************************************************************************
    logic [NB_CORES-1:0] w_dbg_irq_valid ;

    //****************************************************************************
    // MCHAN completion event
    //****************************************************************************
    logic w_dma_pe_evt_ack   ;
    logic w_dma_pe_evt_valid ;
    logic w_dma_pe_irq_ack   ;
    logic w_dma_pe_irq_valid ;

    //****************************************************************************
    // Event
    //****************************************************************************
    logic                  w_events_valid ;
    logic                  w_events_ready ;
    logic [EVNT_WIDTH-1:0] w_events_data  ;

    //****************************************************************************
    // AXI Data Slave
    //****************************************************************************
    // WRITE ADDRESS CHANNEL
    logic                              w_data_slave_aw_valid  ;
    logic [AXI_ADDR_WIDTH-1:0]         w_data_slave_aw_addr   ;
    logic [2:0]                        w_data_slave_aw_prot   ;
    logic [AXI4_REGION_MAP_SIZE-1:0]   w_data_slave_aw_region ;
    logic [7:0]                        w_data_slave_aw_len    ;
    logic [2:0]                        w_data_slave_aw_size   ;
    logic [1:0]                        w_data_slave_aw_burst  ;
    logic                              w_data_slave_aw_lock   ;
    logic [3:0]                        w_data_slave_aw_cache  ;
    logic [3:0]                        w_data_slave_aw_qos    ;
    logic [AXI_ID_IN_WIDTH-1:0]        w_data_slave_aw_id     ;
    logic [AXI_USER_WIDTH-1 :0]        w_data_slave_aw_user   ;
    logic                              w_data_slave_aw_ready  ;

    // READ ADDRESS CHANNEL
    logic                              w_data_slave_ar_valid  ;
    logic [AXI_ADDR_WIDTH-1 :0]        w_data_slave_ar_addr   ;
    logic [2:0]                        w_data_slave_ar_prot   ;
    logic [AXI4_REGION_MAP_SIZE-1:0]   w_data_slave_ar_region ;
    logic [7:0]                        w_data_slave_ar_len    ;
    logic [2:0]                        w_data_slave_ar_size   ;
    logic [1:0]                        w_data_slave_ar_burst  ;
    logic                              w_data_slave_ar_lock   ;
    logic [3:0]                        w_data_slave_ar_cache  ;
    logic [3:0]                        w_data_slave_ar_qos    ;
    logic [AXI_ID_IN_WIDTH-1:0]        w_data_slave_ar_id     ;
    logic [AXI_USER_WIDTH-1 :0]        w_data_slave_ar_user   ;
    logic                              w_data_slave_ar_ready  ;

    // WRITE DATA CHANNEL
    logic                              w_data_slave_w_valid   ;
    logic [AXI_DATA_S2C_WIDTH-1:0]     w_data_slave_w_data    ;
    logic [AXI_STRB_S2C_WIDTH-1:0]     w_data_slave_w_strb    ;
    logic [AXI_USER_WIDTH-1 :0]        w_data_slave_w_user    ;
    logic                              w_data_slave_w_last    ;
    logic                              w_data_slave_w_ready   ;

    // READ DATA CHANNEL
    logic                              w_data_slave_r_valid   ;
    logic [AXI_DATA_S2C_WIDTH-1:0]     w_data_slave_r_data    ;
    logic [1:0]                        w_data_slave_r_resp    ;
    logic                              w_data_slave_r_last    ;
    logic [AXI_ID_IN_WIDTH-1:0]        w_data_slave_r_id      ;
    logic [AXI_USER_WIDTH-1 :0]        w_data_slave_r_user    ;
    logic                              w_data_slave_r_ready   ;

    // WRITE RESPONSE CHANNEL
    logic                              w_data_slave_b_valid   ;
    logic [1:0]                        w_data_slave_b_resp    ;
    logic [AXI_ID_IN_WIDTH-1:0]        w_data_slave_b_id      ;
    logic [AXI_USER_WIDTH-1 :0]        w_data_slave_b_user    ;
    logic                              w_data_slave_b_ready   ;

    //****************************************************************************
    // AXI Data Master
    //****************************************************************************
    // WRITE ADDRESS CHANNEL
    logic                              w_data_master_aw_valid  ;
    logic [AXI_ADDR_WIDTH-1:0]         w_data_master_aw_addr   ;
    logic [2:0]                        w_data_master_aw_prot   ;
    logic [AXI4_REGION_MAP_SIZE-1:0]   w_data_master_aw_region ;
    logic [7:0]                        w_data_master_aw_len    ;
    logic [2:0]                        w_data_master_aw_size   ;
    logic [1:0]                        w_data_master_aw_burst  ;
    logic                              w_data_master_aw_lock   ;
    logic [3:0]                        w_data_master_aw_cache  ;
    logic [3:0]                        w_data_master_aw_qos    ;
    logic [AXI_ID_OUT_WIDTH-1:0]       w_data_master_aw_id     ;
    logic [AXI_USER_WIDTH-1 :0]        w_data_master_aw_user   ;
    logic                              w_data_master_aw_ready  ;

    // READ ADDRESS CHANNEL
    logic                              w_data_master_ar_valid  ;
    logic [AXI_ADDR_WIDTH-1 :0]        w_data_master_ar_addr   ;
    logic [2:0]                        w_data_master_ar_prot   ;
    logic [AXI4_REGION_MAP_SIZE-1:0]   w_data_master_ar_region ;
    logic [7:0]                        w_data_master_ar_len    ;
    logic [2:0]                        w_data_master_ar_size   ;
    logic [1:0]                        w_data_master_ar_burst  ;
    logic                              w_data_master_ar_lock   ;
    logic [3:0]                        w_data_master_ar_cache  ;
    logic [3:0]                        w_data_master_ar_qos    ;
    logic [AXI_ID_OUT_WIDTH-1:0]       w_data_master_ar_id     ;
    logic [AXI_USER_WIDTH-1 :0]        w_data_master_ar_user   ;
    logic                              w_data_master_ar_ready  ;

    // WRITE DATA CHANNEL
    logic                              w_data_master_w_valid   ;
    logic [AXI_DATA_C2S_WIDTH-1:0]     w_data_master_w_data    ;
    logic [AXI_STRB_C2S_WIDTH-1:0]     w_data_master_w_strb    ;
    logic [AXI_USER_WIDTH-1 :0]        w_data_master_w_user    ;
    logic                              w_data_master_w_last    ;
    logic                              w_data_master_w_ready   ;

    // READ DATA CHANNEL
    logic                              w_data_master_r_valid   ;
    logic [AXI_DATA_C2S_WIDTH-1:0]     w_data_master_r_data    ;
    logic [1:0]                        w_data_master_r_resp    ;
    logic                              w_data_master_r_last    ;
    logic [AXI_ID_OUT_WIDTH-1:0]       w_data_master_r_id      ;
    logic [AXI_USER_WIDTH-1 :0]        w_data_master_r_user    ;
    logic                              w_data_master_r_ready   ;

    // WRITE RESPONSE CHANNEL
    logic                              w_data_master_b_valid   ;
    logic [1:0]                        w_data_master_b_resp    ;
    logic [AXI_ID_OUT_WIDTH-1:0]       w_data_master_b_id      ;
    logic [AXI_USER_WIDTH-1 :0]        w_data_master_b_user    ;
    logic                              w_data_master_b_ready   ;

    //****************************************************************************
    // AXI INSTR Master
    //****************************************************************************
    // WRITE ADDRESS CHANNEL
    logic                              w_instr_master_aw_valid  ;
    logic [AXI_ADDR_WIDTH-1:0]         w_instr_master_aw_addr   ;
    logic [2:0]                        w_instr_master_aw_prot   ;
    logic [AXI4_REGION_MAP_SIZE-1:0]   w_instr_master_aw_region ;
    logic [7:0]                        w_instr_master_aw_len    ;
    logic [2:0]                        w_instr_master_aw_size   ;
    logic [1:0]                        w_instr_master_aw_burst  ;
    logic                              w_instr_master_aw_lock   ;
    logic [3:0]                        w_instr_master_aw_cache  ;
    logic [3:0]                        w_instr_master_aw_qos    ;
    logic [AXI_ID_OUT_WIDTH-1:0]       w_instr_master_aw_id     ;
    logic [AXI_USER_WIDTH-1 :0]        w_instr_master_aw_user   ;
    logic                              w_instr_master_aw_ready  ;

    // READ ADDRESS CHANNEL
    logic                              w_instr_master_ar_valid  ;
    logic [AXI_ADDR_WIDTH-1 :0]        w_instr_master_ar_addr   ;
    logic [2:0]                        w_instr_master_ar_prot   ;
    logic [AXI4_REGION_MAP_SIZE-1:0]   w_instr_master_ar_region ;
    logic [7:0]                        w_instr_master_ar_len    ;
    logic [2:0]                        w_instr_master_ar_size   ;
    logic [1:0]                        w_instr_master_ar_burst  ;
    logic                              w_instr_master_ar_lock   ;
    logic [3:0]                        w_instr_master_ar_cache  ;
    logic [3:0]                        w_instr_master_ar_qos    ;
    logic [AXI_ID_OUT_WIDTH-1:0]       w_instr_master_ar_id     ;
    logic [AXI_USER_WIDTH-1 :0]        w_instr_master_ar_user   ;
    logic                              w_instr_master_ar_ready  ;

    // WRITE DATA CHANNEL
    logic                              w_instr_master_w_valid   ;
    logic [AXI_DATA_C2S_WIDTH-1:0]     w_instr_master_w_data    ;
    logic [AXI_STRB_C2S_WIDTH-1:0]     w_instr_master_w_strb    ;
    logic [AXI_USER_WIDTH-1 :0]        w_instr_master_w_user    ;
    logic                              w_instr_master_w_last    ;
    logic                              w_instr_master_w_ready   ;

    // READ DATA CHANNEL
    logic                              w_instr_master_r_valid   ;
    logic [AXI_DATA_C2S_WIDTH-1:0]     w_instr_master_r_data    ;
    logic [1:0]                        w_instr_master_r_resp    ;
    logic                              w_instr_master_r_last    ;
    logic [AXI_ID_OUT_WIDTH-1:0]       w_instr_master_r_id      ;
    logic [AXI_USER_WIDTH-1 :0]        w_instr_master_r_user    ;
    logic                              w_instr_master_r_ready   ;

    // WRITE RESPONSE CHANNEL
    logic                              w_instr_master_b_valid   ;
    logic [1:0]                        w_instr_master_b_resp    ;
    logic [AXI_ID_OUT_WIDTH-1:0]       w_instr_master_b_id      ;
    logic [AXI_USER_WIDTH-1 :0]        w_instr_master_b_user    ;
    logic                              w_instr_master_b_ready   ;

    //****************************************************************************
    // TCDM banks
    //****************************************************************************
    logic [ NB_TCDM_BANKS * ADDR_WIDTH - 1 : 0 ] w_tcdm_bank_addr ;
    logic [ NB_TCDM_BANKS              - 1 : 0 ] w_tcdm_bank_ce_n ;
    logic [ NB_TCDM_BANKS              - 1 : 0 ] w_tcdm_bank_we_n ;
    logic [ NB_TCDM_BANKS * BE_WIDTH   - 1 : 0 ] w_tcdm_bank_be_n ;
    logic [ NB_TCDM_BANKS * DATA_WIDTH - 1 : 0 ] w_tcdm_bank_wdata;
    logic [ NB_TCDM_BANKS * DATA_WIDTH - 1 : 0 ] w_tcdm_bank_rdata;

    //****************************************************************************
    // PRI_ICACHE
    //****************************************************************************
    logic [ NB_CORES*PRI_NB_WAYS*PRI_TAG_ADDR_WIDTH   - 1 : 0 ] w_pri_tag_addr  ;
    logic [ NB_CORES*PRI_NB_WAYS                      - 1 : 0 ] w_pri_tag_ce_n  ;
    logic [ NB_CORES*PRI_NB_WAYS                      - 1 : 0 ] w_pri_tag_we_n  ;
    logic [ NB_CORES*PRI_NB_WAYS*PRI_TAG_WIDTH        - 1 : 0 ] w_pri_tag_wdata ;
    logic [ NB_CORES*PRI_NB_WAYS*PRI_TAG_WIDTH        - 1 : 0 ] w_pri_tag_rdata ;

    logic [ NB_CORES*PRI_NB_WAYS*PRI_DATA_ADDR_WIDTH  - 1 : 0 ] w_pri_data_addr ;
    logic [ NB_CORES*PRI_NB_WAYS                      - 1 : 0 ] w_pri_data_ce_n ;
    logic [ NB_CORES*PRI_NB_WAYS                      - 1 : 0 ] w_pri_data_we_n ;
    logic [ NB_CORES*PRI_NB_WAYS*PRI_DATA_WIDTH       - 1 : 0 ] w_pri_data_wdata;
    logic [ NB_CORES*PRI_NB_WAYS*PRI_DATA_WIDTH       - 1 : 0 ] w_pri_data_rdata;

    //****************************************************************************
    // SHARE_ICACHE
    //****************************************************************************
    logic [ SH_NB_BANKS*SH_TAG_ADDR_WIDTH             - 1 : 0 ] w_sh_tag_addr   ;
    logic [ SH_NB_BANKS*SH_NB_WAYS                    - 1 : 0 ] w_sh_tag_ce_n   ;
    logic [ SH_NB_BANKS                               - 1 : 0 ] w_sh_tag_we_n   ;
    logic [ SH_NB_BANKS*SH_TAG_DATA_WIDTH             - 1 : 0 ] w_sh_tag_wdata  ;
    logic [ SH_NB_BANKS*SH_NB_WAYS*SH_TAG_DATA_WIDTH  - 1 : 0 ] w_sh_tag_rdata  ;

    logic [ SH_NB_BANKS*SH_DATA_ADDR_WIDTH            - 1 : 0 ] w_sh_data_addr  ;
    logic [ SH_NB_BANKS*SH_NB_WAYS                    - 1 : 0 ] w_sh_data_ce_n  ;
    logic [ SH_NB_BANKS                               - 1 : 0 ] w_sh_data_we_n  ;
    logic [ SH_NB_BANKS*SH_DATA_BE_WIDTH              - 1 : 0 ] w_sh_data_be_n  ;
    logic [ SH_NB_BANKS*SH_DATA_DATA_WIDTH            - 1 : 0 ] w_sh_data_wdata ;
    logic [ SH_NB_BANKS*SH_NB_WAYS*SH_DATA_DATA_WIDTH - 1 : 0 ] w_sh_data_rdata ;

    genvar i;
    genvar j;

    //******************************************************************************
    //
    // ██╗███╗   ██╗████████╗███████╗██████╗ ███████╗ █████╗  ██████╗███████╗███████╗
    // ██║████╗  ██║╚══██╔══╝██╔════╝██╔══██╗██╔════╝██╔══██╗██╔════╝██╔════╝██╔════╝
    // ██║██╔██╗ ██║   ██║   █████╗  ██████╔╝█████╗  ███████║██║     █████╗  ███████╗
    // ██║██║╚██╗██║   ██║   ██╔══╝  ██╔══██╗██╔══╝  ██╔══██║██║     ██╔══╝  ╚════██║
    // ██║██║ ╚████║   ██║   ███████╗██║  ██║██║     ██║  ██║╚██████╗███████╗███████║
    // ╚═╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝ ╚═════╝╚══════╝╚══════╝
    //
    //******************************************************************************

    //****************************************************************************
    // Clock and Reset
    //****************************************************************************

    //clock generation
    always #5ns    sys_clk = ~sys_clk;
    always #7812ps ref_clk = ~ref_clk;

    //reset Generation
    initial begin
        rst_n     = 0;
        sys_clk   = 0;
        ref_clk   = 0;
        #1us;
        rst_n = 1;
    end

    initial begin
        w_en_sa_boot = 0;
        w_fetch_en   = 0; 
        #2us;
        w_en_sa_boot = 1;
    end

    assign w_test_mode        = '0;
    assign w_scan_ckgt_enable = '0;

    assign w_base_addr        = 'h040;

    assign w_dbg_irq_valid    = '0;

    assign w_dma_pe_evt_ack   = '0;
    assign w_dma_pe_irq_ack   = '0;

    assign w_events_valid     = '0;
    assign w_events_data      = '0;

    sv_axi_interface #(
        AXI_ADDR_WIDTH     ,
        AXI_DATA_S2C_WIDTH ,
        AXI_ID_IN_WIDTH    ,
        AXI_USER_WIDTH
    ) data_slave_if (
        .aclk    ( sys_clk ), 
        .aresetn ( rst_n   )
    );


    assign data_slave_if.awready  = w_data_slave_aw_ready  ;
    assign data_slave_if.arready  = w_data_slave_ar_ready  ;
    assign data_slave_if.wready   = w_data_slave_w_ready   ;
    assign data_slave_if.rvalid   = w_data_slave_r_valid   ;
    assign data_slave_if.rlast    = w_data_slave_r_last    ;
    assign data_slave_if.rdata    = w_data_slave_r_data    ;
    assign data_slave_if.rresp    = w_data_slave_r_resp    ;
    assign data_slave_if.rid      = w_data_slave_r_id      ;
    assign data_slave_if.ruser    = w_data_slave_r_user    ;
    assign data_slave_if.bvalid   = w_data_slave_b_valid   ;
    assign data_slave_if.bresp    = w_data_slave_b_resp    ;
    assign data_slave_if.bid      = w_data_slave_b_id      ;
    assign data_slave_if.buser    = w_data_slave_b_user    ;

    assign w_data_slave_aw_valid  = data_slave_if.awvalid  ;
    assign w_data_slave_aw_addr   = data_slave_if.awaddr   ;
    assign w_data_slave_aw_size   = data_slave_if.awsize   ;
    assign w_data_slave_aw_burst  = data_slave_if.awburst  ;
    assign w_data_slave_aw_cache  = data_slave_if.awcache  ;
    assign w_data_slave_aw_prot   = data_slave_if.awprot   ;
    assign w_data_slave_aw_id     = data_slave_if.awid     ;
    assign w_data_slave_aw_len    = data_slave_if.awlen    ;
    assign w_data_slave_aw_lock   = data_slave_if.awlock   ;
    assign w_data_slave_aw_qos    = data_slave_if.awqos    ;
    assign w_data_slave_aw_region = data_slave_if.awregion ;
    assign w_data_slave_aw_user   = data_slave_if.awuser   ;
    assign w_data_slave_w_valid   = data_slave_if.wvalid   ;
    assign w_data_slave_w_last    = data_slave_if.wlast    ;
    assign w_data_slave_w_data    = data_slave_if.wdata    ;
    assign w_data_slave_w_strb    = data_slave_if.wstrb    ;
    assign w_data_slave_w_user    = data_slave_if.wuser    ;
    assign w_data_slave_b_ready   = data_slave_if.bready   ;
    assign w_data_slave_ar_valid  = data_slave_if.arvalid  ;
    assign w_data_slave_ar_addr   = data_slave_if.araddr   ;
    assign w_data_slave_ar_size   = data_slave_if.arsize   ;
    assign w_data_slave_ar_burst  = data_slave_if.arburst  ;
    assign w_data_slave_ar_cache  = data_slave_if.arcache  ;
    assign w_data_slave_ar_prot   = data_slave_if.arprot   ;
    assign w_data_slave_ar_id     = data_slave_if.arid     ;
    assign w_data_slave_ar_len    = data_slave_if.arlen    ;
    assign w_data_slave_ar_lock   = data_slave_if.arlock   ;
    assign w_data_slave_ar_qos    = data_slave_if.arqos    ;
    assign w_data_slave_ar_region = data_slave_if.arregion ;
    assign w_data_slave_ar_user   = data_slave_if.aruser   ;
    assign w_data_slave_r_ready   = data_slave_if.rready   ;

    assign data_slave_if.eoc      = w_eoc                  ;
           
             

    panther_top_test #(
        AXI_ADDR_WIDTH     ,
        AXI_DATA_S2C_WIDTH ,
        AXI_ID_IN_WIDTH    ,
        AXI_USER_WIDTH
    ) test (data_slave_if);




    //******************************************************************************
    //
    // ██████╗ ██╗   ██╗████████╗
    // ██╔══██╗██║   ██║╚══██╔══╝
    // ██║  ██║██║   ██║   ██║
    // ██║  ██║██║   ██║   ██║
    // ██████╔╝╚██████╔╝   ██║
    // ╚═════╝  ╚═════╝    ╚═╝
    //
    //******************************************************************************

    panther_top dut_panther (
        .i_clk                      ( sys_clk               ),
        .i_rst_n                    ( rst_n                 ),
        .i_ref_clk                  ( ref_clk               ),

        .i_test_mode                ( w_test_mode           ),
        .i_scan_ckgt_enable         ( w_scan_ckgt_enable    ),

        .i_cluster_id               ('0                     ),
        .i_base_addr                ( w_base_addr           ),
        .i_en_sa_boot               ( w_en_sa_boot          ),
        .i_fetch_en                 ( w_fetch_en            ),

        .o_busy                     ( w_busy                ),
        .o_eoc                      ( w_eoc                 ),

        .i_dbg_irq_valid            ( w_dbg_irq_valid       ),

        .i_dma_pe_evt_ack           ( w_dma_pe_evt_ack      ),
        .o_dma_pe_evt_valid         ( w_dma_pe_evt_valid    ),
        .i_dma_pe_irq_ack           ( w_dma_pe_irq_ack      ),
        .o_dma_pe_irq_valid         ( w_dma_pe_irq_valid    ),

        .i_events_valid             ( w_events_valid        ),
        .o_events_ready             ( w_events_ready        ),
        .i_events_data              ( w_events_data         ),

    // AXI4 SLAVE
    //***************************************
    // WRITE ADDRESS CHANNEL
        .i_data_slave_aw_valid      ( w_data_slave_aw_valid       ),
        .i_data_slave_aw_addr       ( w_data_slave_aw_addr        ),
        .i_data_slave_aw_prot       ( w_data_slave_aw_prot        ),
        .i_data_slave_aw_region     ( w_data_slave_aw_region      ),
        .i_data_slave_aw_len        ( w_data_slave_aw_len         ),
        .i_data_slave_aw_size       ( w_data_slave_aw_size        ),
        .i_data_slave_aw_burst      ( w_data_slave_aw_burst       ),
        .i_data_slave_aw_lock       ( w_data_slave_aw_lock        ),
        .i_data_slave_aw_cache      ( w_data_slave_aw_cache       ),
        .i_data_slave_aw_qos        ( w_data_slave_aw_qos         ),
        .i_data_slave_aw_id         ( w_data_slave_aw_id          ),
        .i_data_slave_aw_user       ( w_data_slave_aw_user        ),
        .o_data_slave_aw_ready      ( w_data_slave_aw_ready       ),

    // READ ADDRESS CHANNEL
        .i_data_slave_ar_valid      ( w_data_slave_ar_valid       ),
        .i_data_slave_ar_addr       ( w_data_slave_ar_addr        ),
        .i_data_slave_ar_prot       ( w_data_slave_ar_prot        ),
        .i_data_slave_ar_region     ( w_data_slave_ar_region      ),
        .i_data_slave_ar_len        ( w_data_slave_ar_len         ),
        .i_data_slave_ar_size       ( w_data_slave_ar_size        ),
        .i_data_slave_ar_burst      ( w_data_slave_ar_burst       ),
        .i_data_slave_ar_lock       ( w_data_slave_ar_lock        ),
        .i_data_slave_ar_cache      ( w_data_slave_ar_cache       ),
        .i_data_slave_ar_qos        ( w_data_slave_ar_qos         ),
        .i_data_slave_ar_id         ( w_data_slave_ar_id          ),
        .i_data_slave_ar_user       ( w_data_slave_ar_user        ),
        .o_data_slave_ar_ready      ( w_data_slave_ar_ready       ),

    // WRITE DATA CHANNEL
        .i_data_slave_w_valid       ( w_data_slave_w_valid        ),
        .i_data_slave_w_data        ( w_data_slave_w_data         ),
        .i_data_slave_w_strb        ( w_data_slave_w_strb         ),
        .i_data_slave_w_user        ( w_data_slave_w_user         ),
        .i_data_slave_w_last        ( w_data_slave_w_last         ),
        .o_data_slave_w_ready       ( w_data_slave_w_ready        ),

    // READ DATA CHANNEL
        .o_data_slave_r_valid       ( w_data_slave_r_valid        ),
        .o_data_slave_r_data        ( w_data_slave_r_data         ),
        .o_data_slave_r_resp        ( w_data_slave_r_resp         ),
        .o_data_slave_r_last        ( w_data_slave_r_last         ),
        .o_data_slave_r_id          ( w_data_slave_r_id           ),
        .o_data_slave_r_user        ( w_data_slave_r_user         ),
        .i_data_slave_r_ready       ( w_data_slave_r_ready        ),

    // WRITE RESPONSE CHANNEL
        .o_data_slave_b_valid       ( w_data_slave_b_valid        ),
        .o_data_slave_b_resp        ( w_data_slave_b_resp         ),
        .o_data_slave_b_id          ( w_data_slave_b_id           ),
        .o_data_slave_b_user        ( w_data_slave_b_user         ),
        .i_data_slave_b_ready       ( w_data_slave_b_ready        ),

    // AXI4 MASTER
    //***************************************
    // WRITE ADDRESS CHANNEL
        .o_data_master_aw_valid     ( w_data_master_aw_valid      ),
        .o_data_master_aw_addr      ( w_data_master_aw_addr       ),
        .o_data_master_aw_prot      ( w_data_master_aw_prot       ),
        .o_data_master_aw_region    ( w_data_master_aw_region     ),
        .o_data_master_aw_len       ( w_data_master_aw_len        ),
        .o_data_master_aw_size      ( w_data_master_aw_size       ),
        .o_data_master_aw_burst     ( w_data_master_aw_burst      ),
        .o_data_master_aw_lock      ( w_data_master_aw_lock       ),
        .o_data_master_aw_cache     ( w_data_master_aw_cache      ),
        .o_data_master_aw_qos       ( w_data_master_aw_qos        ),
        .o_data_master_aw_id        ( w_data_master_aw_id         ),
        .o_data_master_aw_user      ( w_data_master_aw_user       ),
        .i_data_master_aw_ready     ( w_data_master_aw_ready      ),

    // READ ADDRESS CHANNEL
        .o_data_master_ar_valid     ( w_data_master_ar_valid      ),
        .o_data_master_ar_addr      ( w_data_master_ar_addr       ),
        .o_data_master_ar_prot      ( w_data_master_ar_prot       ),
        .o_data_master_ar_region    ( w_data_master_ar_region     ),
        .o_data_master_ar_len       ( w_data_master_ar_len        ),
        .o_data_master_ar_size      ( w_data_master_ar_size       ),
        .o_data_master_ar_burst     ( w_data_master_ar_burst      ),
        .o_data_master_ar_lock      ( w_data_master_ar_lock       ),
        .o_data_master_ar_cache     ( w_data_master_ar_cache      ),
        .o_data_master_ar_qos       ( w_data_master_ar_qos        ),
        .o_data_master_ar_id        ( w_data_master_ar_id         ),
        .o_data_master_ar_user      ( w_data_master_ar_user       ),
        .i_data_master_ar_ready     ( w_data_master_ar_ready      ),

    // WRITE DATA CHANNEL
        .o_data_master_w_valid      ( w_data_master_w_valid       ),
        .o_data_master_w_data       ( w_data_master_w_data        ),
        .o_data_master_w_strb       ( w_data_master_w_strb        ),
        .o_data_master_w_user       ( w_data_master_w_user        ),
        .o_data_master_w_last       ( w_data_master_w_last        ),
        .i_data_master_w_ready      ( w_data_master_w_ready       ),

    // READ DATA CHANNEL
        .i_data_master_r_valid      ( w_data_master_r_valid       ),
        .i_data_master_r_data       ( w_data_master_r_data        ),
        .i_data_master_r_resp       ( w_data_master_r_resp        ),
        .i_data_master_r_last       ( w_data_master_r_last        ),
        .i_data_master_r_id         ( w_data_master_r_id          ),
        .i_data_master_r_user       ( w_data_master_r_user        ),
        .o_data_master_r_ready      ( w_data_master_r_ready       ),

    // WRITE RESPONSE CHANNEL
        .i_data_master_b_valid      ( w_data_master_b_valid       ),
        .i_data_master_b_resp       ( w_data_master_b_resp        ),
        .i_data_master_b_id         ( w_data_master_b_id          ),
        .i_data_master_b_user       ( w_data_master_b_user        ),
        .o_data_master_b_ready      ( w_data_master_b_ready       ),

    // INSTR MASTER
    //***************************************
    // WRITE ADDRESS CHANNEL
        .o_instr_master_aw_valid    ( w_instr_master_aw_valid     ),
        .o_instr_master_aw_addr     ( w_instr_master_aw_addr      ),
        .o_instr_master_aw_prot     ( w_instr_master_aw_prot      ),
        .o_instr_master_aw_region   ( w_instr_master_aw_region    ),
        .o_instr_master_aw_len      ( w_instr_master_aw_len       ),
        .o_instr_master_aw_size     ( w_instr_master_aw_size      ),
        .o_instr_master_aw_burst    ( w_instr_master_aw_burst     ),
        .o_instr_master_aw_lock     ( w_instr_master_aw_lock      ),
        .o_instr_master_aw_cache    ( w_instr_master_aw_cache     ),
        .o_instr_master_aw_qos      ( w_instr_master_aw_qos       ),
        .o_instr_master_aw_id       ( w_instr_master_aw_id        ),
        .o_instr_master_aw_user     ( w_instr_master_aw_user      ),
        .i_instr_master_aw_ready    ( w_instr_master_aw_ready     ),

    // READ ADDRESS CHANNEL
        .o_instr_master_ar_valid    ( w_instr_master_ar_valid     ),
        .o_instr_master_ar_addr     ( w_instr_master_ar_addr      ),
        .o_instr_master_ar_prot     ( w_instr_master_ar_prot      ),
        .o_instr_master_ar_region   ( w_instr_master_ar_region    ),
        .o_instr_master_ar_len      ( w_instr_master_ar_len       ),
        .o_instr_master_ar_size     ( w_instr_master_ar_size      ),
        .o_instr_master_ar_burst    ( w_instr_master_ar_burst     ),
        .o_instr_master_ar_lock     ( w_instr_master_ar_lock      ),
        .o_instr_master_ar_cache    ( w_instr_master_ar_cache     ),
        .o_instr_master_ar_qos      ( w_instr_master_ar_qos       ),
        .o_instr_master_ar_id       ( w_instr_master_ar_id        ),
        .o_instr_master_ar_user     ( w_instr_master_ar_user      ),
        .i_instr_master_ar_ready    ( w_instr_master_ar_ready     ),

    // WRITE DATA CHANNEL
        .o_instr_master_w_valid     ( w_instr_master_w_valid      ),
        .o_instr_master_w_data      ( w_instr_master_w_data       ),
        .o_instr_master_w_strb      ( w_instr_master_w_strb       ),
        .o_instr_master_w_user      ( w_instr_master_w_user       ),
        .o_instr_master_w_last      ( w_instr_master_w_last       ),
        .i_instr_master_w_ready     ( w_instr_master_w_ready      ),

    // READ DATA CHANNEL
        .i_instr_master_r_valid     ( w_instr_master_r_valid      ),
        .i_instr_master_r_data      ( w_instr_master_r_data       ),
        .i_instr_master_r_resp      ( w_instr_master_r_resp       ),
        .i_instr_master_r_last      ( w_instr_master_r_last       ),
        .i_instr_master_r_id        ( w_instr_master_r_id         ),
        .i_instr_master_r_user      ( w_instr_master_r_user       ),
        .o_instr_master_r_ready     ( w_instr_master_r_ready      ),

    // WRITE RESPONSE CHANNEL
        .i_instr_master_b_valid     ( w_instr_master_b_valid      ),
        .i_instr_master_b_resp      ( w_instr_master_b_resp       ),
        .i_instr_master_b_id        ( w_instr_master_b_id         ),
        .i_instr_master_b_user      ( w_instr_master_b_user       ),
        .o_instr_master_b_ready     ( w_instr_master_b_ready      )
    );



    //*************************************************************************************//
    //  ██████╗  █████╗ ████████╗ █████╗        ███████╗██╗      █████╗ ██╗   ██╗███████╗  //
    //  ██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗       ██╔════╝██║     ██╔══██╗██║   ██║██╔════╝  //
    //  ██║  ██║███████║   ██║   ███████║       ███████╗██║     ███████║██║   ██║█████╗    //
    //  ██║  ██║██╔══██║   ██║   ██╔══██║       ╚════██║██║     ██╔══██║╚██╗ ██╔╝██╔══╝    //
    //  ██████╔╝██║  ██║   ██║   ██║  ██║██████╗███████║███████╗██║  ██║ ╚████╔╝ ███████╗  //
    //  ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝══════╝╚══════╝╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝  //
    //*************************************************************************************//
    ram_axi #(
        .PARAMETER_ADDRESS_SIZE  ( AXI_ADDR_WIDTH-1        ), 
        .PARAMETER_WORD_SIZE     ( AXI_DATA_C2S_WIDTH      ), 
        .PARAMETER_USER_SIZE     ( AXI_USER_WIDTH          ), 
        .PARAMETER_ID_SIZE       ( AXI_ID_OUT_WIDTH        ), 
        .PARAMETER_DATA_FILENAME ( "progmem.dat"           )
    ) data_slave_L2 (
        .clk          ( sys_clk                 ),
        .rst_n        ( rst_n                   ),

        .axi_awvalid  ( w_data_master_aw_valid  ),
        .axi_awready  ( w_data_master_aw_ready  ),
        .axi_awaddr   ( w_data_master_aw_addr   ),
        .axi_awsize   ( w_data_master_aw_size   ),
        .axi_awburst  ( w_data_master_aw_burst  ),
        .axi_awcache  ( w_data_master_aw_cache  ),
        .axi_awprot   ( w_data_master_aw_prot   ),
        .axi_awid     ( w_data_master_aw_id     ),
        .axi_awlen    ( w_data_master_aw_len    ),
        .axi_awlock   ( w_data_master_aw_lock   ),
        .axi_awqos    ( w_data_master_aw_qos    ),
        .axi_awregion ( w_data_master_aw_region ),
        .axi_awuser   ( w_data_master_aw_user   ),

        .axi_wvalid   ( w_data_master_w_valid   ),
        .axi_wready   ( w_data_master_w_ready   ),
        .axi_wlast    ( w_data_master_w_last    ),
        .axi_wdata    ( w_data_master_w_data    ),
        .axi_wstrb    ( w_data_master_w_strb    ),
        .axi_wuser    ( w_data_master_w_user    ),

        .axi_bvalid   ( w_data_master_b_valid   ),
        .axi_bready   ( w_data_master_b_ready   ),
        .axi_bresp    ( w_data_master_b_resp    ),
        .axi_bid      ( w_data_master_b_id      ),
        .axi_buser    ( w_data_master_b_user    ),

        .axi_arvalid  ( w_data_master_ar_valid  ),
        .axi_arready  ( w_data_master_ar_ready  ),
        .axi_araddr   ( w_data_master_ar_addr   ),
        .axi_arsize   ( w_data_master_ar_size   ),
        .axi_arburst  ( w_data_master_ar_burst  ),
        .axi_arcache  ( w_data_master_ar_cache  ),
        .axi_arprot   ( w_data_master_ar_prot   ),
        .axi_arid     ( w_data_master_ar_id     ),
        .axi_arlen    ( w_data_master_ar_len    ),
        .axi_arlock   ( w_data_master_ar_lock   ),
        .axi_arqos    ( w_data_master_ar_qos    ),
        .axi_arregion ( w_data_master_ar_region ),
        .axi_aruser   ( w_data_master_ar_user   ),

        .axi_rvalid   ( w_data_master_r_valid   ),
        .axi_rready   ( w_data_master_r_ready   ),
        .axi_rlast    ( w_data_master_r_last    ),
        .axi_rdata    ( w_data_master_r_data    ),
        .axi_rresp    ( w_data_master_r_resp    ),
        .axi_rid      ( w_data_master_r_id      ),
        .axi_ruser    ( w_data_master_r_user    )
    );
    

    //**********************************************************************************//
    //   ██████╗ ██████╗ ██████╗ ███████╗       ██╗███╗   ██╗███████╗████████╗██████╗   //
    //  ██╔════╝██╔═══██╗██╔══██╗██╔════╝       ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗  //
    //  ██║     ██║   ██║██████╔╝█████╗         ██║██╔██╗ ██║███████╗   ██║   ██████╔╝  //
    //  ██║     ██║   ██║██╔══██╗██╔══╝         ██║██║╚██╗██║╚════██║   ██║   ██╔══██╗  //
    //  ╚██████╗╚██████╔╝██║  ██║███████╗██████╗██║██║ ╚████║███████║   ██║   ██║  ██║  //
    //   ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝══════╝╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝  //
    //**********************************************************************************//
    generate
        if (USE_DEDICATED_INSTR_IF) begin : g_instr_slave_L2
            //TODO: Decide if we keep ram_axi or switch to sv_axi
            ram_axi #(
                .PARAMETER_ADDRESS_SIZE  ( AXI_ADDR_WIDTH          ), 
                .PARAMETER_WORD_SIZE     ( AXI_INSTR_WIDTH         ), 
                .PARAMETER_USER_SIZE     ( AXI_USER_WIDTH          ), 
                .PARAMETER_ID_SIZE       ( AXI_ID_OUT_WIDTH        ), 
                .PARAMETER_DATA_FILENAME ( "core_instr_input.dat"  )
            ) instr_slave_L2 (
                .clk          ( sys_clk                  ),
                .rst_n        ( rst_n                    ),

                .axi_awvalid  ( w_instr_master_aw_valid  ),
                .axi_awready  ( w_instr_master_aw_ready  ),
                .axi_awaddr   ( w_instr_master_aw_addr   ),
                .axi_awsize   ( w_instr_master_aw_size   ),
                .axi_awburst  ( w_instr_master_aw_burst  ),
                .axi_awcache  ( w_instr_master_aw_cache  ),
                .axi_awprot   ( w_instr_master_aw_prot   ),
                .axi_awid     ( w_instr_master_aw_id     ),
                .axi_awlen    ( w_instr_master_aw_len    ),
                .axi_awlock   ( w_instr_master_aw_lock   ),
                .axi_awqos    ( w_instr_master_aw_qos    ),
                .axi_awregion ( w_instr_master_aw_region ),
                .axi_awuser   ( w_instr_master_aw_user   ),

                .axi_wvalid   ( w_instr_master_w_valid   ),
                .axi_wready   ( w_instr_master_w_ready   ),
                .axi_wlast    ( w_instr_master_w_last    ),
                .axi_wdata    ( w_instr_master_w_data    ),
                .axi_wstrb    ( w_instr_master_w_strb    ),
                .axi_wuser    ( w_instr_master_w_user    ),

                .axi_bvalid   ( w_instr_master_b_valid   ),
                .axi_bready   ( w_instr_master_b_ready   ),
                .axi_bresp    ( w_instr_master_b_resp    ),
                .axi_bid      ( w_instr_master_b_id      ),
                .axi_buser    ( w_instr_master_b_user    ),

                .axi_arvalid  ( w_instr_master_ar_valid  ),
                .axi_arready  ( w_instr_master_ar_ready  ),
                .axi_araddr   ( w_instr_master_ar_addr   ),
                .axi_arsize   ( w_instr_master_ar_size   ),
                .axi_arburst  ( w_instr_master_ar_burst  ),
                .axi_arcache  ( w_instr_master_ar_cache  ),
                .axi_arprot   ( w_instr_master_ar_prot   ),
                .axi_arid     ( w_instr_master_ar_id     ),
                .axi_arlen    ( w_instr_master_ar_len    ),
                .axi_arlock   ( w_instr_master_ar_lock   ),
                .axi_arqos    ( w_instr_master_ar_qos    ),
                .axi_arregion ( w_instr_master_ar_region ),
                .axi_aruser   ( w_instr_master_ar_user   ),

                .axi_rvalid   ( w_instr_master_r_valid   ),
                .axi_rready   ( w_instr_master_r_ready   ),
                .axi_rlast    ( w_instr_master_r_last    ),
                .axi_rdata    ( w_instr_master_r_data    ),
                .axi_rresp    ( w_instr_master_r_resp    ),
                .axi_rid      ( w_instr_master_r_id      ),
                .axi_ruser    ( w_instr_master_r_user    )
            );
        end

        else begin: instr_slave_0
            assign w_instr_master_aw_ready = '0;
            assign w_instr_master_ar_ready = '0;
            assign w_instr_master_w_ready  = '0;
            assign w_instr_master_r_valid  = '0;
            assign w_instr_master_r_data   = '0;
            assign w_instr_master_r_resp   = '0;
            assign w_instr_master_r_last   = '0;
            assign w_instr_master_r_id     = '0;
            assign w_instr_master_r_user   = '0;
            assign w_instr_master_b_valid  = '0;
            assign w_instr_master_b_resp   = '0;
            assign w_instr_master_b_id     = '0;
            assign w_instr_master_b_user   = '0;
        end 
    endgenerate 

`ifdef CV32E40P_TRACE_EXECUTION

    `define DUT_PATH panther_top_tb.dut_panther.dut_panther

    generate
        for(genvar i=0; i<NB_CORES; i++) begin : gen_core_tracers
            cv32e40p_tracer
            #(
                    .FPU        ( FPU ),
                    .ZFINX      ( 0   ))
            tracer_i (
                .clk_i(`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.clk_i),  // always-running clock for tracing
                .rst_n(`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.rst_ni),

                .hart_id_i(`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.hart_id_i),

                .pc                (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.pc_id_i),
                .instr             (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.instr),
//              .controller_state_i(`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.controller_i.ctrl_fsm_cs),
                .controller_state_i(                                                                                        ),
                .compressed        (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.is_compressed_i),
                .id_valid          (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.id_valid_o),
                .is_decoding       (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.is_decoding_o),
                .is_illegal        (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.illegal_insn_dec),
                .trigger_match     (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.trigger_match_i),
                .rs1_value         (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.operand_a_fw_id),
                .rs2_value         (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.operand_b_fw_id),
                .rs3_value         (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.alu_operand_c),
                .rs2_value_vec     (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.alu_operand_b),

                .rs1_is_fp(`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.regfile_fp_a),
                .rs2_is_fp(`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.regfile_fp_b),
                .rs3_is_fp(`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.regfile_fp_c),
                .rd_is_fp (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.regfile_fp_d),

                .ex_valid    (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.ex_valid),
                .ex_reg_addr (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.regfile_alu_waddr_fw),
                .ex_reg_we   (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.regfile_alu_we_fw),
                .ex_reg_wdata(`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.regfile_alu_wdata_fw),

                .ex_data_addr   (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.data_addr_o),
                .ex_data_req    (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.data_req_o),
                .ex_data_gnt    (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.data_gnt_i),
                .ex_data_we     (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.data_we_o),
                .ex_data_wdata  (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.data_wdata_o),
                .data_misaligned(`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.data_misaligned),

                .ebrk_insn            (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.ebrk_insn_dec),
                .debug_mode           (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.debug_mode),
                .ebrk_force_debug_mode(`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.controller_i.ebrk_force_debug_mode),

                .wb_bypass(`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.ex_stage_i.branch_in_ex_i),

                .wb_valid    (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.wb_valid),
                .wb_reg_addr (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.regfile_waddr_fw_wb_o),
                .wb_reg_we   (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.regfile_we_wb),
                .wb_reg_wdata(`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.regfile_wdata),

                .imm_u_type      (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.imm_u_type),
                .imm_uj_type     (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.imm_uj_type),
                .imm_i_type      (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.imm_i_type),
                .imm_iz_type     (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.imm_iz_type[11:0]),
                .imm_z_type      (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.imm_z_type),
                .imm_s_type      (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.imm_s_type),
                .imm_sb_type     (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.imm_sb_type),
                .imm_s2_type     (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.imm_s2_type),
                .imm_s3_type     (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.imm_s3_type),
                .imm_vs_type     (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.imm_vs_type),
                .imm_vu_type     (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.imm_vu_type),
                .imm_shuffle_type(`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.imm_shuffle_type),
                .imm_clip_type   (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.id_stage_i.instr[11:7]),

                .apu_en_i         (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.ex_stage_i.apu_req),
                .apu_singlecycle_i(`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.ex_stage_i.apu_singlecycle),
                .apu_multicycle_i (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.ex_stage_i.apu_multicycle),
                .apu_rvalid_i     (`DUT_PATH.g_core[i].core_region_i.RISCV_CORE.ex_stage_i.apu_valid)

            );
        end
    endgenerate
`endif  // CV32E40P_TRACE_EXECUTION


endmodule

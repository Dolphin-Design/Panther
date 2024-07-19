// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Davide Rossi <davide.rossi@unibo.it>

import mchan_pkg::*;

module mchan
#( 
    parameter int NB_CTRLS                 = 4,  // NUMBER OF CTRLS
    parameter int NB_TRANSFERS             = 8,  // NUMBER OF TRANSFERS
    
    parameter int CTRL_TRANS_QUEUE_DEPTH   = 2,  // DEPTH OF PRIVATE PER-CTRL COMMAND QUEUE (CTRL_UNIT)
    parameter int GLOBAL_TRANS_QUEUE_DEPTH = 2,  // DEPTH OF GLOBAL COMMAND QUEUE (CTRL_UNIT)
    parameter int TWD_QUEUE_DEPTH          = 4,  // DEPTH OF GLOBAL 2D COMMAND QUEUE (CTRL_UNIT)
    
    parameter int CTRL_ADD_WIDTH           = 10, // WIDTH OF CONTROL ADDRESS
    parameter int TCDM_ADD_WIDTH           = 16, // WIDTH OF TCDM ADDRESS
    parameter int EXT_ADD_WIDTH            = 32, // WIDTH OF GLOBAL EXTERNAL ADDRESS
    
    parameter int NB_OUTSND_TRANS          = 8,  // NUMBER OF OUTSTANDING TRANSACTIONS
    parameter int MCHAN_BURST_LENGTH       = 64, // ANY POWER OF 2 VALUE FROM 8 TO 2048
    
    parameter int AXI_ADDR_WIDTH           = 32,
    parameter int AXI_DATA_WIDTH           = 64,
    parameter int AXI_USER_WIDTH           = 6,
    parameter int AXI_ID_WIDTH             = 4,
    parameter int AXI_STRB_WIDTH           = AXI_DATA_WIDTH/8,

    parameter int PE_ID_WIDTH              = 1,
    parameter int TRANS_SID_WIDTH          = (NB_TRANSFERS == 1) ? 1 : $clog2(NB_TRANSFERS)
)
(
    
    input  logic                                 i_clk,
    input  logic                                 i_rst_n,
    
    input logic                                  i_scan_ckgt_enable,
    
    // CONTROL TARGET
    //***************************************
    input  logic [NB_CTRLS-1:0]                  i_ctrl_targ_req,
    input  logic [NB_CTRLS-1:0]                  i_ctrl_targ_we_n,
    input  logic [NB_CTRLS-1:0][3:0]             i_ctrl_targ_be,
    input  logic [NB_CTRLS-1:0][CTRL_ADD_WIDTH-1:0] i_ctrl_targ_add,
    input  logic [NB_CTRLS-1:0][31:0]            i_ctrl_targ_data,
    input  logic [NB_CTRLS-1:0][PE_ID_WIDTH-1:0] i_ctrl_targ_id,
    output logic [NB_CTRLS-1:0]                  o_ctrl_targ_gnt,
    
    output logic [NB_CTRLS-1:0]                  o_ctrl_targ_r_valid,
    output logic [NB_CTRLS-1:0][31:0]            o_ctrl_targ_r_data,
    output logic [NB_CTRLS-1:0]                  o_ctrl_targ_r_opc,
    output logic [NB_CTRLS-1:0][PE_ID_WIDTH-1:0] o_ctrl_targ_r_id,
    
    // TCDM INITIATOR
    //***************************************
    output logic [3:0]                           o_tcdm_init_req,
    output logic [3:0][31:0]                     o_tcdm_init_add,
    output logic [3:0]                           o_tcdm_init_we_n,
    output logic [3:0][3:0]                      o_tcdm_init_be,
    output logic [3:0][31:0]                     o_tcdm_init_data,
    output logic [3:0][TRANS_SID_WIDTH-1:0]      o_tcdm_init_sid,
    input  logic [3:0]                           i_tcdm_init_gnt,
    
    input  logic [3:0]                           i_tcdm_init_r_valid,
    input  logic [3:0][31:0]                     i_tcdm_init_r_data,
    // AXI4 MASTER
    //***************************************
    // WRITE ADDRESS CHANNEL
    output logic                                 o_axi_master_aw_valid,
    output logic [AXI_ADDR_WIDTH-1:0]            o_axi_master_aw_addr,
    output logic [2:0]                           o_axi_master_aw_prot,
    output logic [3:0]                           o_axi_master_aw_region,
    output logic [7:0]                           o_axi_master_aw_len,
    output logic [2:0]                           o_axi_master_aw_size,
    output logic [1:0]                           o_axi_master_aw_burst,
    output logic                                 o_axi_master_aw_lock,
    output logic [3:0]                           o_axi_master_aw_cache,
    output logic [3:0]                           o_axi_master_aw_qos,
    output logic [AXI_ID_WIDTH-1:0]              o_axi_master_aw_id,
    output logic [AXI_USER_WIDTH-1:0]            o_axi_master_aw_user,
    input  logic                                 i_axi_master_aw_ready,
    
    // READ ADDRESS CHANNEL
    output logic                                 o_axi_master_ar_valid,
    output logic [AXI_ADDR_WIDTH-1:0]            o_axi_master_ar_addr,
    output logic [2:0]                           o_axi_master_ar_prot,
    output logic [3:0]                           o_axi_master_ar_region,
    output logic [7:0]                           o_axi_master_ar_len,
    output logic [2:0]                           o_axi_master_ar_size,
    output logic [1:0]                           o_axi_master_ar_burst,
    output logic                                 o_axi_master_ar_lock,
    output logic [3:0]                           o_axi_master_ar_cache,
    output logic [3:0]                           o_axi_master_ar_qos,
    output logic [AXI_ID_WIDTH-1:0]              o_axi_master_ar_id,
    output logic [AXI_USER_WIDTH-1:0]            o_axi_master_ar_user,
    input  logic                                 i_axi_master_ar_ready,
    
    // WRITE DATA CHANNEL
    output logic                                 o_axi_master_w_valid,
    output logic [AXI_DATA_WIDTH-1:0]            o_axi_master_w_data,
    output logic [AXI_STRB_WIDTH-1:0]            o_axi_master_w_strb,
    output logic [AXI_USER_WIDTH-1:0]            o_axi_master_w_user,
    output logic                                 o_axi_master_w_last,
    input  logic                                 i_axi_master_w_ready,
    
    // READ DATA CHANNEL
    input  logic                                 i_axi_master_r_valid,
    input  logic [AXI_DATA_WIDTH-1:0]            i_axi_master_r_data,
    input  logic [1:0]                           i_axi_master_r_resp,
    input  logic                                 i_axi_master_r_last,
    input  logic [AXI_ID_WIDTH-1:0]              i_axi_master_r_id,
    input  logic [AXI_USER_WIDTH-1:0]            i_axi_master_r_user,
    output logic                                 o_axi_master_r_ready,
    
    // WRITE RESPONSE CHANNEL
    input  logic                                 i_axi_master_b_valid,
    input  logic [1:0]                           i_axi_master_b_resp,
    input  logic [AXI_ID_WIDTH-1:0]              i_axi_master_b_id,
    input  logic [AXI_USER_WIDTH-1:0]            i_axi_master_b_user,
    output logic                                 o_axi_master_b_ready,
    
    // TERMINATION EVENTS
    //***************************************
    output logic [NB_CTRLS-1:0]                  o_term_evt,
    output logic [NB_CTRLS-1:0]                  o_term_int,
    
    // BUSY SIGNAL
    //***************************************
    output logic                                 o_busy
    
    );
   
   // LOCAL PARAMETERS
   
   localparam int TCDM_OPC_WIDTH  = TCDM_OPC_WIDTH;
   localparam int EXT_OPC_WIDTH   = EXT_OPC_WIDTH;
   localparam int MCHAN_LEN_WIDTH = MCHAN_LEN_WIDTH;
   localparam int EXT_TID_WIDTH   = (NB_OUTSND_TRANS ==1) ? 1 : $clog2(NB_OUTSND_TRANS);
   
   // SIGNALS
   logic                              s_clk_gated;

   logic                              s_tcdm_tx_req;
   logic                              s_tcdm_rx_req;
   logic                              s_ext_tx_req;
   logic                              s_ext_rx_req;
   logic                              s_tcdm_tx_gnt;
   logic                              s_tcdm_rx_gnt;
   logic                              s_ext_tx_gnt;
   logic                              s_ext_rx_gnt;
   logic                              s_ext_tx_bst;
   logic                              s_ext_rx_bst;
   logic [MCHAN_LEN_WIDTH-1:0]        s_tcdm_tx_len;
   logic [MCHAN_LEN_WIDTH-1:0]        s_tcdm_rx_len;
   logic [MCHAN_LEN_WIDTH-1:0]        s_ext_tx_len;
   logic [MCHAN_LEN_WIDTH-1:0]        s_ext_rx_len;
   logic [TCDM_OPC_WIDTH-1:0]         s_tcdm_tx_opc;
   logic [TCDM_OPC_WIDTH-1:0]         s_tcdm_rx_opc;
   logic [TCDM_OPC_WIDTH-1:0]         s_ext_tx_opc;
   logic [TCDM_OPC_WIDTH-1:0]         s_ext_rx_opc;
   logic [TCDM_ADD_WIDTH-1:0]         s_tcdm_tx_add;
   logic [TCDM_ADD_WIDTH-1:0]         s_tcdm_rx_add;
   logic [EXT_ADD_WIDTH-1:0]          s_ext_tx_add;
   logic [EXT_ADD_WIDTH-1:0]          s_ext_rx_add;
   logic [TCDM_ADD_WIDTH-1:0]         s_ext_rx_tcdm_add;
   logic [TRANS_SID_WIDTH-1:0]        s_tcdm_tx_sid;
   logic [TRANS_SID_WIDTH-1:0]        s_tcdm_rx_sid;
   logic [TRANS_SID_WIDTH-1:0]        s_ext_tx_sid;
   logic [TRANS_SID_WIDTH-1:0]        s_ext_rx_sid;
   
   logic [1:0]                        s_tx_data_push_req;
   logic [1:0]                        s_tx_data_push_gnt;
   logic [1:0]                        s_rx_data_pop_req;
   logic [1:0]                        s_rx_data_pop_gnt;
   logic [1:0][31:0]                  s_tx_data_push_dat;
   logic [1:0][31:0]                  s_rx_data_pop_dat;
   logic                              s_rx_data_push_gnt;
   logic                              s_tx_data_pop_req;
   logic                              s_rx_data_push_req;
   logic                              s_tx_data_pop_gnt;
   logic [7:0]                        s_tx_data_pop_strb;
   logic [1:0][3:0]                   s_rx_data_pop_strb;
   
   logic [63:0]                       s_rx_data_push_dat;
   logic [63:0]                       s_tx_data_pop_dat;
   
   logic [2:0]                        s_trans_tx_ext_add;
   logic [2:0]                        s_trans_rx_ext_add;
   logic [2:0]                        s_trans_tx_tcdm_add;
   logic [2:0]                        s_trans_rx_tcdm_add;
   logic [MCHAN_LEN_WIDTH-1:0]        s_trans_tx_len;
   logic [MCHAN_LEN_WIDTH-1:0]        s_trans_rx_len;
   logic                              s_trans_tx_req;
   logic                              s_trans_rx_req;
   logic                              s_trans_tx_gnt;
   logic                              s_trans_rx_gnt;
   
   logic                              s_tx_tcdm_synch_req;
   logic                              s_rx_tcdm_synch_req;
   logic                              s_tx_ext_synch_req;
   logic                              s_rx_ext_synch_req;
   logic [TRANS_SID_WIDTH-1:0]        s_tx_tcdm_synch_sid;
   logic [TRANS_SID_WIDTH-1:0]        s_rx_tcdm_synch_sid;
   logic [TRANS_SID_WIDTH-1:0]        s_tx_ext_synch_sid;
   logic [TRANS_SID_WIDTH-1:0]        s_rx_ext_synch_sid;
   
   //**********************************************************
   //*************** CTRL UNIT ********************************
   //**********************************************************
   
   ctrl_unit
     #(
       .NB_CTRLS                 ( NB_CTRLS                 ),
       .NB_TRANSFERS             ( NB_TRANSFERS             ),
       .CTRL_TRANS_QUEUE_DEPTH   ( CTRL_TRANS_QUEUE_DEPTH   ),
       .GLOBAL_TRANS_QUEUE_DEPTH ( GLOBAL_TRANS_QUEUE_DEPTH ),
       .TWD_QUEUE_DEPTH          ( TWD_QUEUE_DEPTH          ),
       .CTRL_ADD_WIDTH           ( CTRL_ADD_WIDTH           ),
       .TCDM_ADD_WIDTH           ( TCDM_ADD_WIDTH           ),
       .EXT_ADD_WIDTH            ( EXT_ADD_WIDTH            ),
       .TRANS_SID_WIDTH          ( TRANS_SID_WIDTH          ),
       .MCHAN_BURST_LENGTH       ( MCHAN_BURST_LENGTH       ),
       .PE_ID_WIDTH              ( PE_ID_WIDTH              )
       )
   ctrl_unit_i
     (
      
      .clk_i(i_clk),
      .rst_ni(i_rst_n),
      
      .scan_ckgt_enable_i(i_scan_ckgt_enable),
      
      .clk_gated_o(s_clk_gated),
      
      .ctrl_targ_req_i(i_ctrl_targ_req),
      .ctrl_targ_add_i(i_ctrl_targ_add),
      .ctrl_targ_we_n_i(i_ctrl_targ_we_n),
      .ctrl_targ_be_i(i_ctrl_targ_be),
      .ctrl_targ_data_i(i_ctrl_targ_data),
      .ctrl_targ_id_i(i_ctrl_targ_id),
      .ctrl_targ_gnt_o(o_ctrl_targ_gnt),
      
      .ctrl_targ_r_valid_o(o_ctrl_targ_r_valid),
      .ctrl_targ_r_data_o(o_ctrl_targ_r_data),
      .ctrl_targ_r_opc_o(o_ctrl_targ_r_opc),
      .ctrl_targ_r_id_o(o_ctrl_targ_r_id),
      
      .tcdm_tx_sid_o(s_tcdm_tx_sid),
      .tcdm_tx_add_o(s_tcdm_tx_add),
      .tcdm_tx_opc_o(s_tcdm_tx_opc),
      .tcdm_tx_len_o(s_tcdm_tx_len),
      .tcdm_tx_req_o(s_tcdm_tx_req),
      .tcdm_tx_gnt_i(s_tcdm_tx_gnt),
      
      .ext_tx_sid_o(s_ext_tx_sid),
      .ext_tx_add_o(s_ext_tx_add),
      .ext_tx_opc_o(s_ext_tx_opc),
      .ext_tx_len_o(s_ext_tx_len),
      .ext_tx_req_o(s_ext_tx_req),
      .ext_tx_bst_o(s_ext_tx_bst),
      .ext_tx_gnt_i(s_ext_tx_gnt),
      
      .ext_rx_sid_o(s_ext_rx_sid),
      .ext_rx_add_o(s_ext_rx_add),
      .ext_rx_tcdm_add_o(s_ext_rx_tcdm_add),
      .ext_rx_opc_o(s_ext_rx_opc),
      .ext_rx_len_o(s_ext_rx_len),
      .ext_rx_bst_o(s_ext_rx_bst),
      .ext_rx_req_o(s_ext_rx_req),
      .ext_rx_gnt_i(s_ext_rx_gnt),
      
      .trans_tx_ext_add_o(s_trans_tx_ext_add),
      .trans_tx_tcdm_add_o(s_trans_tx_tcdm_add),
      .trans_tx_len_o(s_trans_tx_len),
      .trans_tx_req_o(s_trans_tx_req),
      .trans_tx_gnt_i(s_trans_tx_gnt),
      
      .tcdm_tx_synch_req_i(s_tx_tcdm_synch_req),
      .tcdm_tx_synch_sid_i(s_tx_tcdm_synch_sid),
      
      .tcdm_rx_synch_req_i(s_rx_tcdm_synch_req),
      .tcdm_rx_synch_sid_i(s_rx_tcdm_synch_sid),
      
      .ext_tx_synch_req_i(s_tx_ext_synch_req),
      .ext_tx_synch_sid_i(s_tx_ext_synch_sid),
      
      .ext_rx_synch_req_i(s_rx_ext_synch_req),
      .ext_rx_synch_sid_i(s_rx_ext_synch_sid),
      
      .term_evt_o(o_term_evt),
      .term_int_o(o_term_int),
      
      .busy_o(o_busy)
      
      );
   
   //**********************************************************
   //*************** EXTRENAL MODULE **************************
   //**********************************************************
   
   ext_unit
     #(
       .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
       .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
       .AXI_USER_WIDTH(AXI_USER_WIDTH),
       .AXI_ID_WIDTH(AXI_ID_WIDTH),
       .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
       .TRANS_SID_WIDTH(TRANS_SID_WIDTH),
       .EXT_ADD_WIDTH(EXT_ADD_WIDTH),
       .EXT_OPC_WIDTH(EXT_OPC_WIDTH),
       .EXT_TID_WIDTH(EXT_TID_WIDTH),
       .TCDM_ADD_WIDTH(TCDM_ADD_WIDTH),
       .TCDM_OPC_WIDTH(TCDM_OPC_WIDTH),
       .MCHAN_LEN_WIDTH(MCHAN_LEN_WIDTH)
       )
   ext_unit_i
     (
      
      .clk_i(s_clk_gated),
      .rst_ni(i_rst_n),

      .scan_ckgt_enable_i(i_scan_ckgt_enable),
      
      .axi_master_aw_valid_o(o_axi_master_aw_valid),
      .axi_master_aw_addr_o(o_axi_master_aw_addr),
      .axi_master_aw_prot_o(o_axi_master_aw_prot),
      .axi_master_aw_region_o(o_axi_master_aw_region),
      .axi_master_aw_len_o(o_axi_master_aw_len),
      .axi_master_aw_size_o(o_axi_master_aw_size),
      .axi_master_aw_burst_o(o_axi_master_aw_burst),
      .axi_master_aw_lock_o(o_axi_master_aw_lock),
      .axi_master_aw_cache_o(o_axi_master_aw_cache),
      .axi_master_aw_qos_o(o_axi_master_aw_qos),
      .axi_master_aw_id_o(o_axi_master_aw_id),
      .axi_master_aw_user_o(o_axi_master_aw_user),
      .axi_master_aw_ready_i(i_axi_master_aw_ready),
      
      .axi_master_ar_valid_o(o_axi_master_ar_valid),
      .axi_master_ar_addr_o(o_axi_master_ar_addr),
      .axi_master_ar_prot_o(o_axi_master_ar_prot),
      .axi_master_ar_region_o(o_axi_master_ar_region),
      .axi_master_ar_len_o(o_axi_master_ar_len),
      .axi_master_ar_size_o(o_axi_master_ar_size),
      .axi_master_ar_burst_o(o_axi_master_ar_burst),
      .axi_master_ar_lock_o(o_axi_master_ar_lock),
      .axi_master_ar_cache_o(o_axi_master_ar_cache),
      .axi_master_ar_qos_o(o_axi_master_ar_qos),
      .axi_master_ar_id_o(o_axi_master_ar_id),
      .axi_master_ar_user_o(o_axi_master_ar_user),
      .axi_master_ar_ready_i(i_axi_master_ar_ready),
      
      .axi_master_w_valid_o(o_axi_master_w_valid),
      .axi_master_w_data_o(o_axi_master_w_data),
      .axi_master_w_strb_o(o_axi_master_w_strb),
      .axi_master_w_user_o(o_axi_master_w_user),
      .axi_master_w_last_o(o_axi_master_w_last),
      .axi_master_w_ready_i(i_axi_master_w_ready),
      
      .axi_master_r_valid_i(i_axi_master_r_valid),
      .axi_master_r_data_i(i_axi_master_r_data),
      .axi_master_r_resp_i(i_axi_master_r_resp),
      .axi_master_r_last_i(i_axi_master_r_last),
      .axi_master_r_id_i(i_axi_master_r_id),
      .axi_master_r_user_i(i_axi_master_r_user),
      .axi_master_r_ready_o(o_axi_master_r_ready),
      
      .axi_master_b_valid_i(i_axi_master_b_valid),
      .axi_master_b_resp_i(i_axi_master_b_resp),
      .axi_master_b_id_i(i_axi_master_b_id),
      .axi_master_b_user_i(i_axi_master_b_user),
      .axi_master_b_ready_o(o_axi_master_b_ready),
      
      .ext_rx_sid_i(s_ext_rx_sid),
      .ext_rx_add_i(s_ext_rx_add),
      .ext_rx_r_add_i(s_ext_rx_tcdm_add),
      .ext_rx_opc_i(s_ext_rx_opc),
      .ext_rx_len_i(s_ext_rx_len),
      .ext_rx_bst_i(s_ext_rx_bst),
      .ext_rx_req_i(s_ext_rx_req),
      .ext_rx_gnt_o(s_ext_rx_gnt),
      
      .ext_tx_sid_i(s_ext_tx_sid),
      .ext_tx_add_i(s_ext_tx_add),
      .ext_tx_opc_i(s_ext_tx_opc),
      .ext_tx_len_i(s_ext_tx_len),
      .ext_tx_bst_i(s_ext_tx_bst),
      .ext_tx_req_i(s_ext_tx_req),
      .ext_tx_gnt_o(s_ext_tx_gnt),
      
      .tcdm_rx_sid_o(s_tcdm_rx_sid),
      .tcdm_rx_add_o(s_tcdm_rx_add),
      .tcdm_rx_opc_o(s_tcdm_rx_opc),
      .tcdm_rx_len_o(s_tcdm_rx_len),
      .tcdm_rx_req_o(s_tcdm_rx_req),
      .tcdm_rx_gnt_i(s_tcdm_rx_gnt),
      
      .trans_rx_ext_add_o(s_trans_rx_ext_add),
      .trans_rx_tcdm_add_o(s_trans_rx_tcdm_add),
      .trans_rx_len_o(s_trans_rx_len),
      .trans_rx_req_o(s_trans_rx_req),
      .trans_rx_gnt_i(s_trans_rx_gnt),
      
      .tx_synch_req_o(s_tx_ext_synch_req),
      .tx_synch_sid_o(s_tx_ext_synch_sid),
      
      .rx_synch_req_o(s_rx_ext_synch_req),
      .rx_synch_sid_o(s_rx_ext_synch_sid),
      
      .tx_data_dat_i(s_tx_data_pop_dat),
      .tx_data_strb_i(s_tx_data_pop_strb),
      .tx_data_req_o(s_tx_data_pop_req),
      .tx_data_gnt_i(s_tx_data_pop_gnt),
      
      .rx_data_dat_o(s_rx_data_push_dat),
      .rx_data_req_o(s_rx_data_push_req),
      .rx_data_gnt_i(s_rx_data_push_gnt)
      
      );
   
   //**********************************************************
   //*************** TCDM UNIT ********************************
   //**********************************************************
   
   tcdm_unit
   #(
       .TRANS_SID_WIDTH(TRANS_SID_WIDTH),
       .TCDM_ADD_WIDTH(TCDM_ADD_WIDTH),
       .TCDM_OPC_WIDTH(TCDM_OPC_WIDTH),
       .MCHAN_LEN_WIDTH(MCHAN_LEN_WIDTH)
   )
   tcdm_unit_i
   (
      
      .clk_i(s_clk_gated),
      .rst_ni(i_rst_n),

      .scan_ckgt_enable_i(i_scan_ckgt_enable),
      
      .tcdm_req_o(o_tcdm_init_req),
      .tcdm_add_o(o_tcdm_init_add),
      .tcdm_we_n_o(o_tcdm_init_we_n),
      .tcdm_be_o(o_tcdm_init_be),
      .tcdm_wdata_o(o_tcdm_init_data),
      .tcdm_sid_o(o_tcdm_init_sid),
      .tcdm_gnt_i(i_tcdm_init_gnt),
      .tcdm_r_valid_i(i_tcdm_init_r_valid),
      .tcdm_r_rdata_i(i_tcdm_init_r_data),
      
      .tcdm_tx_sid_i(s_tcdm_tx_sid),
      .tcdm_tx_add_i(s_tcdm_tx_add),
      .tcdm_tx_opc_i(s_tcdm_tx_opc),
      .tcdm_tx_len_i(s_tcdm_tx_len),
      .tcdm_tx_req_i(s_tcdm_tx_req),
      .tcdm_tx_gnt_o(s_tcdm_tx_gnt),
      
      .tcdm_rx_sid_i(s_tcdm_rx_sid),
      .tcdm_rx_add_i(s_tcdm_rx_add),
      .tcdm_rx_opc_i(s_tcdm_rx_opc),
      .tcdm_rx_len_i(s_tcdm_rx_len),
      .tcdm_rx_req_i(s_tcdm_rx_req),
      .tcdm_rx_gnt_o(s_tcdm_rx_gnt),
      
      .tx_data_dat_o(s_tx_data_push_dat),
      .tx_data_req_o(s_tx_data_push_req),
      .tx_data_gnt_i(s_tx_data_push_gnt),
      
      .rx_data_dat_i(s_rx_data_pop_dat),
      .rx_data_strb_i(s_rx_data_pop_strb),
      .rx_data_req_o(s_rx_data_pop_req),
      .rx_data_gnt_i(s_rx_data_pop_gnt),
      
      .tx_synch_req_o(s_tx_tcdm_synch_req),
      .tx_synch_sid_o(s_tx_tcdm_synch_sid),
      
      .rx_synch_req_o(s_rx_tcdm_synch_req),
      .rx_synch_sid_o(s_rx_tcdm_synch_sid)
      
    );
   
   //**********************************************************
   //*************** TRANSACTIONS BUFFER **********************
   //**********************************************************
   
   trans_unit
     #(
       .MCHAN_LEN_WIDTH(MCHAN_LEN_WIDTH)
       )
   trans_unit_i
     (
      
      .clk_i(s_clk_gated),
      .rst_ni(i_rst_n),
      
      .scan_ckgt_enable_i(i_scan_ckgt_enable),

      .tx_trans_ext_addr_i(s_trans_tx_ext_add),
      .tx_trans_tcdm_addr_i(s_trans_tx_tcdm_add),
      .tx_trans_len_i(s_trans_tx_len),
      .tx_trans_req_i(s_trans_tx_req),
      .tx_trans_gnt_o(s_trans_tx_gnt),
      
      .rx_trans_tcdm_addr_i(s_trans_rx_tcdm_add),
      .rx_trans_ext_addr_i(s_trans_rx_ext_add),
      .rx_trans_len_i(s_trans_rx_len),
      .rx_trans_req_i(s_trans_rx_req),
      .rx_trans_gnt_o(s_trans_rx_gnt),
      
      .tx_data_push_dat_i(s_tx_data_push_dat),
      .tx_data_push_req_i(s_tx_data_push_req),
      .tx_data_push_gnt_o(s_tx_data_push_gnt),
      
      .tx_data_pop_dat_o(s_tx_data_pop_dat),
      .tx_data_pop_strb_o(s_tx_data_pop_strb),
      .tx_data_pop_req_i(s_tx_data_pop_req),
      .tx_data_pop_gnt_o(s_tx_data_pop_gnt),
      
      .rx_data_push_dat_i(s_rx_data_push_dat),
      .rx_data_push_req_i(s_rx_data_push_req),
      .rx_data_push_gnt_o(s_rx_data_push_gnt),
      
      .rx_data_pop_dat_o(s_rx_data_pop_dat),
      .rx_data_pop_strb_o(s_rx_data_pop_strb),
      .rx_data_pop_req_i(s_rx_data_pop_req),
      .rx_data_pop_gnt_o(s_rx_data_pop_gnt)
      
      );
   
endmodule

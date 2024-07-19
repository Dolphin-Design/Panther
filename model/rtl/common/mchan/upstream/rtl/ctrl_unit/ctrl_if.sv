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

module ctrl_if #(
  // OVERRIDDEN FROM TOP
  parameter int NB_TRANSFERS           = 4                               ,
  parameter int TWD_QUEUE_DEPTH        = 4                               ,
  parameter int CTRL_TRANS_QUEUE_DEPTH = 2                               ,
  parameter int CTRL_ADD_WIDTH         = 10                              ,
  parameter int TCDM_ADD_WIDTH         = 12                              ,
  parameter int EXT_ADD_WIDTH          = 29                              ,
  parameter int TWD_COUNT_WIDTH        = 16                              ,
  parameter int TWD_STRIDE_WIDTH       = 16                              ,
  parameter int TWD_QUEUE_WIDTH        = TWD_STRIDE_WIDTH+TWD_COUNT_WIDTH,
  parameter int PE_ID_WIDTH            = 1                               ,
  // DEFINED IN MCHAN_PKG
  parameter int MCHAN_OPC_WIDTH        = MCHAN_OPC_WIDTH                ,
  parameter int MCHAN_LEN_WIDTH        = MCHAN_LEN_WIDTH                ,
  parameter int TWD_QUEUE_ADD_WIDTH    = (TWD_QUEUE_DEPTH == 1) ? 1 : $clog2(TWD_QUEUE_DEPTH),
  parameter int TRANS_SID_WIDTH        = (NB_TRANSFERS == 1) ? 1 : $clog2(NB_TRANSFERS)
)
(
  input  logic                           clk_i               ,
  input  logic                           rst_ni              ,
  input  logic                           scan_ckgt_enable_i  ,
  // CONTROL TARGET
  //***************************************
  input  logic                           ctrl_targ_req_i     ,
  input  logic                           ctrl_targ_we_n_i    ,
  input  logic [3:0]                     ctrl_targ_be_i      ,
  input  logic [     CTRL_ADD_WIDTH-1:0] ctrl_targ_add_i     ,
  input  logic [                   31:0] ctrl_targ_data_i    ,
  input  logic [        PE_ID_WIDTH-1:0] ctrl_targ_id_i      ,
  output logic                           ctrl_targ_gnt_o     ,
  output logic                           ctrl_targ_r_valid_o ,
  output logic [                   31:0] ctrl_targ_r_data_o  ,
  output logic                           ctrl_targ_r_opc_o   ,
  output logic [        PE_ID_WIDTH-1:0] ctrl_targ_r_id_o    ,
  // TRANSFERS ALLCOATOR INTERFACE
  //***************************************
  // RETRIVE SID SIGNALS
  output logic                           trans_alloc_req_o   ,
  input  logic                           trans_alloc_gnt_i   ,
  input  logic [    TRANS_SID_WIDTH-1:0] trans_alloc_ret_i   ,
  // CLEAR SID SIGNALS
  output logic [       NB_TRANSFERS-1:0] trans_alloc_clr_o   ,
  // STATUS SIGNALS
  input  logic [       NB_TRANSFERS-1:0] trans_alloc_status_i,
  // CMD QUEUE INTERFACE
  //***************************************
  output logic                           cmd_req_o           ,
  input  logic                           cmd_gnt_i           ,
  output logic [    MCHAN_LEN_WIDTH-1:0] cmd_len_o           ,
  output logic [    MCHAN_OPC_WIDTH-1:0] cmd_opc_o           ,
  output logic                           cmd_inc_o           ,
  output logic                           cmd_twd_ext_o       ,
  output logic                           cmd_ele_o           ,
  output logic                           cmd_ile_o           ,
  output logic                           cmd_ble_o           ,
  output logic                           cmd_twd_tcdm_o      ,
  output logic [TWD_QUEUE_ADD_WIDTH-1:0] cmd_twd_ext_add_o   ,
  output logic [TWD_QUEUE_ADD_WIDTH-1:0] cmd_twd_tcdm_add_o  ,
  output logic [    TRANS_SID_WIDTH-1:0] cmd_sid_o           ,
  output logic [     TCDM_ADD_WIDTH-1:0] tcdm_add_o          ,
  output logic [      EXT_ADD_WIDTH-1:0] ext_add_o           ,
  output logic                           twd_ext_alloc_req_o ,
  input  logic                           twd_ext_alloc_gnt_i ,
  input  logic [TWD_QUEUE_ADD_WIDTH-1:0] twd_ext_alloc_add_i ,
  output logic                           twd_ext_queue_req_o ,
  output logic [TWD_QUEUE_ADD_WIDTH-1:0] twd_ext_queue_add_o ,
  output logic [    TWD_QUEUE_WIDTH-1:0] twd_ext_queue_dat_o ,
  output logic [    TRANS_SID_WIDTH-1:0] twd_ext_queue_sid_o ,
  output logic                           twd_tcdm_alloc_req_o,
  input  logic                           twd_tcdm_alloc_gnt_i,
  input  logic [TWD_QUEUE_ADD_WIDTH-1:0] twd_tcdm_alloc_add_i,
  output logic                           twd_tcdm_queue_req_o,
  output logic [TWD_QUEUE_ADD_WIDTH-1:0] twd_tcdm_queue_add_o,
  output logic [    TWD_QUEUE_WIDTH-1:0] twd_tcdm_queue_dat_o,
  output logic [    TRANS_SID_WIDTH-1:0] twd_tcdm_queue_sid_o,
  // SYNCH UNIT INTERFACE
  //***************************************
  input  logic                           arb_gnt_i           ,
  input  logic                           arb_req_i           ,
  input  logic [    TRANS_SID_WIDTH-1:0] arb_sid_i           ,
  // SYNCHRONIZATION INTERFACE
  //***************************************
  input  logic [       NB_TRANSFERS-1:0] trans_registered_i  ,
  input  logic [       NB_TRANSFERS-1:0] trans_status_i      ,
  // BUSY SIGNAL
  //***************************************
  output logic                           busy_o
);
   
  localparam int COMMAND_FIFO_WIDTH = TWD_QUEUE_ADD_WIDTH + TWD_QUEUE_ADD_WIDTH + MCHAN_LEN_WIDTH + TRANS_SID_WIDTH + 7; // INC, OPC, TWD_EXT, ELE, ILE, BLE, TWD_TCDM

  logic [ TWD_COUNT_WIDTH-1:0]    s_twd_ext_queue_count  ;
  logic [TWD_STRIDE_WIDTH-1:0]    s_twd_ext_queue_stride ;
  logic [ TWD_COUNT_WIDTH-1:0]    s_twd_tcdm_queue_count ;
  logic [TWD_STRIDE_WIDTH-1:0]    s_twd_tcdm_queue_stride;

  logic                           s_cmd_req         ;
  logic                           s_cmd_req_fifo    ;
  logic                           s_cmd_full        ;
  logic                           s_cmd_gnt_fifo    ;
  logic [    MCHAN_LEN_WIDTH-1:0] s_cmd_len         ;
  logic [    MCHAN_OPC_WIDTH-1:0] s_cmd_opc         ;
  logic                           s_cmd_inc         ;
  logic                           s_cmd_twd_ext     ;
  logic                           s_cmd_ele         ;
  logic                           s_cmd_ile         ;
  logic                           s_cmd_ble         ;
  logic                           s_cmd_twd_tcdm    ;
  logic [TWD_QUEUE_ADD_WIDTH-1:0] s_cmd_twd_ext_add ;
  logic [TWD_QUEUE_ADD_WIDTH-1:0] s_cmd_twd_tcdm_add;
  logic [    TRANS_SID_WIDTH-1:0] s_cmd_sid         ;
  logic                           s_cmd_empty       ;
  logic                           s_cmd_unpush_elem ;

  logic [TCDM_ADD_WIDTH-1:0]      s_tcdm_add     ;
  logic                           s_tcdm_req     ;
  logic                           s_tcdm_req_fifo;
  logic                           s_tcdm_full    ;
  logic                           s_tcdm_gnt_fifo;
  logic                           s_tcdm_empty   ;
  logic                           s_tcdm_unpush_elem ;

  logic [EXT_ADD_WIDTH-1:0]       s_ext_add     ;
  logic                           s_ext_req     ;
  logic                           s_ext_req_fifo;
  logic                           s_ext_full    ;
  logic                           s_ext_gnt_fifo;
  logic                           s_ext_empty   ;

  logic                           s_twd_ext_trans      ;
  logic                           s_twd_tcdm_trans     ;
  logic                           s_twd_ext_last_trans ;
  logic                           s_twd_tcdm_last_trans;
  logic                           s_twd_last_trans     ;

  logic                           s_decoder_busy;

  logic                           s_clk_enable;
  logic                           s_clk_gated ;
   
  genvar                          i;
  
  //**********************************************************
  //*************** ADDRESS DECODER **************************
  //**********************************************************
  
  ctrl_fsm
  #(
    .CTRL_ADD_WIDTH(CTRL_ADD_WIDTH),
    .TCDM_ADD_WIDTH(TCDM_ADD_WIDTH),
    .EXT_ADD_WIDTH(EXT_ADD_WIDTH),
    .NB_TRANSFERS(NB_TRANSFERS),
    .TWD_COUNT_WIDTH(TWD_COUNT_WIDTH),
    .TWD_STRIDE_WIDTH(TWD_STRIDE_WIDTH),
    .TWD_QUEUE_DEPTH(TWD_QUEUE_DEPTH),
    .PE_ID_WIDTH(PE_ID_WIDTH)
  )
  ctrl_fsm_i
  (
    .clk_i(s_clk_gated),
    .rst_ni(rst_ni),
    
    .ctrl_targ_req_i(ctrl_targ_req_i),
    .ctrl_targ_we_n_i(ctrl_targ_we_n_i),
    .ctrl_targ_be_i(ctrl_targ_be_i),
    .ctrl_targ_add_i(ctrl_targ_add_i),
    .ctrl_targ_data_i(ctrl_targ_data_i),
    .ctrl_targ_id_i(ctrl_targ_id_i),
    .ctrl_targ_gnt_o(ctrl_targ_gnt_o),
    
    .ctrl_targ_r_valid_o(ctrl_targ_r_valid_o),
    .ctrl_targ_r_data_o(ctrl_targ_r_data_o),
    .ctrl_targ_r_opc_o(ctrl_targ_r_opc_o),
    .ctrl_targ_r_id_o(ctrl_targ_r_id_o),
    
    .cmd_gnt_i(~s_cmd_full),
    .cmd_req_o(s_cmd_req),
    .cmd_len_o(s_cmd_len),
    .cmd_opc_o(s_cmd_opc),
    .cmd_inc_o(s_cmd_inc),
    .cmd_twd_ext_o(s_cmd_twd_ext),
    .cmd_ele_o(s_cmd_ele),
    .cmd_ile_o(s_cmd_ile),
    .cmd_ble_o(s_cmd_ble),
    .cmd_twd_tcdm_o(s_cmd_twd_tcdm),
    .cmd_twd_ext_add_o(s_cmd_twd_ext_add),
    .cmd_twd_tcdm_add_o(s_cmd_twd_tcdm_add),
    .cmd_sid_o(s_cmd_sid),
    .cmd_unpush_elem_o(s_cmd_unpush_elem),
    
    .tcdm_gnt_i(~s_tcdm_full),
    .tcdm_req_o(s_tcdm_req),
    .tcdm_add_o(s_tcdm_add),
    .tcdm_unpush_elem_o(s_tcdm_unpush_elem),
    
    .ext_gnt_i(~s_ext_full),
    .ext_req_o(s_ext_req),
    .ext_add_o(s_ext_add),
    
    .arb_gnt_i(arb_gnt_i),
    .arb_req_i(arb_req_i),
    .arb_sid_i(arb_sid_i),
    
    .twd_ext_trans_o(s_twd_ext_trans),
    
    .twd_ext_alloc_req_o(twd_ext_alloc_req_o),
    .twd_ext_alloc_gnt_i(twd_ext_alloc_gnt_i),
    .twd_ext_alloc_add_i(twd_ext_alloc_add_i),
    
    .twd_ext_queue_req_o(twd_ext_queue_req_o),
    .twd_ext_queue_add_o(twd_ext_queue_add_o),
    .twd_ext_queue_count_o(s_twd_ext_queue_count),
    .twd_ext_queue_stride_o(s_twd_ext_queue_stride),
    .twd_ext_queue_sid_o(twd_ext_queue_sid_o),
    
    .twd_tcdm_trans_o(s_twd_tcdm_trans),
    
    .twd_tcdm_alloc_req_o(twd_tcdm_alloc_req_o),
    .twd_tcdm_alloc_gnt_i(twd_tcdm_alloc_gnt_i),
    .twd_tcdm_alloc_add_i(twd_tcdm_alloc_add_i),
    
    .twd_tcdm_queue_req_o(twd_tcdm_queue_req_o),
    .twd_tcdm_queue_add_o(twd_tcdm_queue_add_o),
    .twd_tcdm_queue_count_o(s_twd_tcdm_queue_count),
    .twd_tcdm_queue_stride_o(s_twd_tcdm_queue_stride),
    .twd_tcdm_queue_sid_o(twd_tcdm_queue_sid_o),
    
    .trans_alloc_req_o(trans_alloc_req_o),
    .trans_alloc_gnt_i(trans_alloc_gnt_i),
    .trans_alloc_ret_i(trans_alloc_ret_i),
    .trans_alloc_clr_o(trans_alloc_clr_o),
    .trans_alloc_status_i(trans_alloc_status_i),
    
    .trans_registered_i(trans_registered_i),
    .trans_status_i(trans_status_i),
    
    .busy_o(s_decoder_busy)
  );
   
  //**********************************************************
  //*************** COMMAND FIFO *****************************
  //**********************************************************
  
  assign s_cmd_req_fifo = ~ s_cmd_empty; 

  fifo_v3 #(
    .FALL_THROUGH (1'b0), // fifo is in fall-through mode
    .DATA_WIDTH   (COMMAND_FIFO_WIDTH), // default data width if the fifo is of type logic
    .DEPTH        (CTRL_TRANS_QUEUE_DEPTH) // depth can be arbitrary from 0 to 2**32
  ) command_fifo_i (
    .clk_i         (s_clk_gated),         // Clock
    .rst_ni        (rst_ni),              // Asynchronous reset active low
    .flush_i       (1'b0),                // flush the queue
    .unpush_i      (s_cmd_unpush_elem),   // unpush one element
    .testmode_i    (scan_ckgt_enable_i),  // test_mode to bypass clock gating
    // status flags
    .full_o  (s_cmd_full),                // queue is full
    .empty_o (s_cmd_empty),               // queue is empty
    .usage_o (/* Not Used */),            // fill pointer
    // as long as the queue is not full we can push new data
    .data_i ({s_cmd_sid,s_cmd_twd_tcdm,s_cmd_ble,s_cmd_ile,s_cmd_ele,s_cmd_twd_ext,s_cmd_twd_tcdm_add,s_cmd_twd_ext_add,s_cmd_inc,s_cmd_opc,s_cmd_len}),           // data to push into the queue
    .push_i (s_cmd_req),                  // data is valid and can be pushed to the queue
    // as long as the queue is not empty we can pop new elements
    .data_o ({cmd_sid_o,cmd_twd_tcdm_o,cmd_ble_o,cmd_ile_o,cmd_ele_o,cmd_twd_ext_o,cmd_twd_tcdm_add_o,cmd_twd_ext_add_o,cmd_inc_o,cmd_opc_o,cmd_len_o}),           // output data
    .pop_i  (s_cmd_gnt_fifo)              // pop head from queue
  );

  //**********************************************************
  //*************** TCDM ADDR FIFO ***************************
  //**********************************************************
   
  assign s_tcdm_req_fifo = ~ s_tcdm_empty; 

  fifo_v3 #(
    .FALL_THROUGH (1'b0), // fifo is in fall-through mode
    .DATA_WIDTH   (TCDM_ADD_WIDTH), // default data width if the fifo is of type logic
    .DEPTH        (CTRL_TRANS_QUEUE_DEPTH) // depth can be arbitrary from 0 to 2**32
  ) tcdm_addr_fifo_i (
    .clk_i         (s_clk_gated),         // Clock
    .rst_ni        (rst_ni),              // Asynchronous reset active low
    .flush_i       (1'b0),                // flush the queue
    .unpush_i      (s_tcdm_unpush_elem),  // unpush one element
    .testmode_i    (scan_ckgt_enable_i),  // test_mode to bypass clock gating
    // status flags
    .full_o  (s_tcdm_full),               // queue is full
    .empty_o (s_tcdm_empty),              // queue is empty
    .usage_o (/* Not Used */),            // fill pointer
    // as long as the queue is not full we can push new data
    .data_i (s_tcdm_add),                 // data to push into the queue
    .push_i (s_tcdm_req),                 // data is valid and can be pushed to the queue
    // as long as the queue is not empty we can pop new elements
    .data_o (tcdm_add_o),                 // output data
    .pop_i  (s_tcdm_gnt_fifo)             // pop head from queue
  );

  //**********************************************************
  //*************** EXT ADDR FIFO ****************************
  //**********************************************************
  
  assign s_ext_req_fifo = ~ s_ext_empty; 

  fifo_v3 #(
    .FALL_THROUGH (1'b0), // fifo is in fall-through mode
    .DATA_WIDTH   (EXT_ADD_WIDTH), // default data width if the fifo is of type logic
    .DEPTH        (CTRL_TRANS_QUEUE_DEPTH) // depth can be arbitrary from 0 to 2**32
  ) ext_addr_fifo_i (
    .clk_i         (s_clk_gated),         // Clock
    .rst_ni        (rst_ni),              // Asynchronous reset active low
    .flush_i       (1'b0),                // flush the queue
    .unpush_i      (1'b0),                // unpush one element
    .testmode_i    (scan_ckgt_enable_i),  // test_mode to bypass clock gating
    // status flags
    .full_o  (s_ext_full),                // queue is full
    .empty_o (s_ext_empty),               // queue is empty
    .usage_o (/* Not Used */),            // fill pointer
    // as long as the queue is not full we can push new data
    .data_i (s_ext_add),                  // data to push into the queue
    .push_i (s_ext_req),                  // data is valid and can be pushed to the queue
    // as long as the queue is not empty we can pop new elements
    .data_o (ext_add_o),                  // output data
    .pop_i  (s_ext_gnt_fifo)              // pop head from queue
  );

  clkgating mchan_ctrl_ckgate
  (
   .i_clk       ( clk_i              ),
   .i_test_mode ( scan_ckgt_enable_i ),
   .i_enable    ( s_clk_enable       ),
   .o_gated_clk ( s_clk_gated        )
  );

  //**********************************************************
  //******* BINDING OF QUEUE SIGNALS TWD ARBITER *************
  //**********************************************************
   
  assign busy_o                = s_decoder_busy;
  assign s_clk_enable          = s_decoder_busy | !s_cmd_empty | !s_tcdm_empty | !s_ext_empty;
  
  // MANAGE 2D TRANS
  assign s_twd_ext_last_trans  = ( s_twd_ext_trans  == 1'b1 ) && ( s_twd_tcdm_trans == 1'b0 );
  assign s_twd_tcdm_last_trans = ( s_twd_tcdm_trans == 1'b1 );
  
  assign s_twd_last_trans      = ( s_twd_ext_last_trans == 1 && twd_ext_queue_req_o == 0 ) || ( s_twd_tcdm_last_trans == 1 && twd_tcdm_queue_req_o == 0 );
  
  assign cmd_req_o        = s_ext_req_fifo && s_tcdm_req_fifo && s_cmd_req_fifo && ( ! s_twd_last_trans ) ;
  assign s_ext_gnt_fifo   = cmd_gnt_i;
  assign s_tcdm_gnt_fifo  = cmd_gnt_i;
  assign s_cmd_gnt_fifo   = cmd_gnt_i;
  
  assign twd_ext_queue_dat_o  = {s_twd_ext_queue_stride,s_twd_ext_queue_count};
  assign twd_tcdm_queue_dat_o = {s_twd_tcdm_queue_stride,s_twd_tcdm_queue_count};
   
endmodule

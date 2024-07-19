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

module tcdm_tx_if
#(
  parameter int TRANS_SID_WIDTH = 2,
  parameter int TCDM_ADD_WIDTH  = 12
)
(   
  input  logic                       clk_i,
  input  logic                       rst_ni,
  input  logic                       scan_ckgt_enable_i,
  
  // CMD LD INTERFACE
  //***************************************
  input  logic                       beat_eop_i,
  input  logic [TRANS_SID_WIDTH-1:0] beat_sid_i,
  input  logic [TCDM_ADD_WIDTH-1:0]  beat_add_i,
  input  logic                       beat_we_n_i,
  input  logic                       beat_req_i,
  output logic                       beat_gnt_o,
  
  // OUT SYNCHRONIZATION INTERFACE
  //***************************************
  output logic                       synch_req_o,
  output logic [TRANS_SID_WIDTH-1:0] synch_sid_o,
  
  // WRITE DATA INTERFACE
  //***************************************
  output logic [31:0]                tx_data_dat_o,
  output logic                       tx_data_req_o,
  input  logic                       tx_data_gnt_i,
  
  // EXTERNAL INITIATOR
  //***************************************
  output logic                       tcdm_req_o,
  output logic [31:0]                tcdm_add_o,
  output logic                       tcdm_we_n_o,
  output logic [31:0]                tcdm_wdata_o,
  output logic [TRANS_SID_WIDTH-1:0] tcdm_sid_o,
  output logic [3:0]                 tcdm_be_o,
  input  logic                       tcdm_gnt_i,
  
  input  logic [31:0]                tcdm_r_rdata_i,
  input  logic                       tcdm_r_valid_i
);
   
  logic [TRANS_SID_WIDTH-1:0]        s_beat_sid;
  logic                              s_beat_eop;

  logic                              s_cmd_full;
  logic                              s_cmd_empty;
  logic                              s_push_cmd_gnt;
  logic                              s_pop_cmd_gnt;
  logic                              s_push_cmd_req;

  logic                              s_data_full;
  logic                              s_data_empty;
  logic                              s_push_data_gnt;
  logic                              s_pop_data_gnt; 
  logic                              s_push_data_req;

  //**********************************************************
  //*************** REQUEST CHANNEL **************************
  //**********************************************************
   
  always_comb begin : p_cmd_req_compute_state 
    tcdm_req_o       = '0;
    beat_gnt_o       = '0;
    s_push_cmd_req   = '0;
    if ( beat_req_i == 1'b1 && beat_we_n_i == 1'b1 && s_push_cmd_gnt == 1'b1 ) begin // REQUEST FROM COMMAND QUEUE && RX OPERATION && TX BUFFER AVAILABLE
      tcdm_req_o = 1'b1;
      if ( tcdm_gnt_i == 1'b1 ) begin // THE TRANSACTION IS GRANTED FROM THE TCDM
        beat_gnt_o  = 1'b1;
        s_push_cmd_req  = 1'b1;
      end
    end
  end
   
  //*****************************************************************************
  //********** 2 INDEPENDENT FIFO DECOUPLE REQUEST AND RESPONE CHANNEL **********
  //*****************************************************************************
  assign s_push_cmd_gnt   = ~s_cmd_full;
  assign s_pop_cmd_gnt    = ~s_cmd_empty; 

  fifo_v3 #(
    .FALL_THROUGH (1'b0),
    .DATA_WIDTH   (TRANS_SID_WIDTH+1),
    .DEPTH        (2)
  ) tcdm_tx_cmd_queue_i (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),
    .flush_i      (1'b0),
    .unpush_i     (1'b0),
    .testmode_i   (scan_ckgt_enable_i),
    // status flags
    .full_o       (s_cmd_full),
    .empty_o      (s_cmd_empty),
    .usage_o      (/* Not Used */),
    // as long as the queue is not full we can push new data
    .data_i       ({beat_sid_i,beat_eop_i}),
    .push_i       (s_push_cmd_req),
    // as long as the queue is not empty we can pop new elements
    .data_o       ({s_beat_sid,s_beat_eop}),
    .pop_i        (tx_data_req_o)
  );


  assign s_push_data_gnt   = ~s_data_full;
  assign s_pop_data_gnt    = ~s_data_empty; 

  fifo_v3 #(
    .FALL_THROUGH (1'b0),
    .DATA_WIDTH   (32),
    .DEPTH        (2)
  ) tcdm_tx_data_queue_i (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),
    .flush_i      (1'b0),
    .unpush_i     (1'b0),
    .testmode_i   (scan_ckgt_enable_i),
    // status flags
    .full_o       (s_data_full),
    .empty_o      (s_data_empty),
    .usage_o      (/* Not Used */),
    // as long as the queue is not full we can push new data
    .data_i       (tcdm_r_rdata_i),
    .push_i       (tcdm_r_valid_i),
    // as long as the queue is not empty we can pop new elements
    .data_o       (tx_data_dat_o),
    .pop_i        (tx_data_req_o)
  );
   
  //**********************************************************
  //********** BINDING OF INPUT/OUTPUT SIGNALS ***************
  //**********************************************************
  
  assign tcdm_add_o   = 32'd0 | beat_add_i;
  assign tcdm_be_o    = 4'b1111;
  assign tcdm_we_n_o  = beat_we_n_i;
  assign tcdm_wdata_o = '0;
  assign tcdm_sid_o   = beat_sid_i;

  assign tx_data_req_o = s_pop_cmd_gnt & s_pop_data_gnt & tx_data_gnt_i ;

  assign synch_req_o = tx_data_req_o & s_beat_eop ;
  assign synch_sid_o = s_beat_sid;
   
endmodule

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

module tcdm_unit
#(
  parameter int TRANS_SID_WIDTH = 1,
  parameter int TCDM_ADD_WIDTH  = 12,
  parameter int TCDM_OPC_WIDTH  = 12,
  parameter int MCHAN_LEN_WIDTH  = 15
)
(
    
  input  logic                       clk_i,
  input  logic                       rst_ni,
  input  logic                       scan_ckgt_enable_i,
  
  // EXTERNAL INITIATOR
  //***************************************
  output logic [3:0]                      tcdm_req_o,
  output logic [3:0][31:0]                tcdm_add_o,
  output logic [3:0]                      tcdm_we_n_o,
  output logic [3:0][31:0]                tcdm_wdata_o,
  output logic [3:0][TRANS_SID_WIDTH-1:0] tcdm_sid_o,
  output logic [3:0][3:0]                 tcdm_be_o,
  input  logic [3:0]                      tcdm_gnt_i,
  
  input  logic [3:0][31:0]                tcdm_r_rdata_i,
  input  logic [3:0]                      tcdm_r_valid_i,
  
  // TX CMD INTERFACE
  //***************************************
  input  logic [TRANS_SID_WIDTH-1:0] tcdm_tx_sid_i,
  input  logic [TCDM_ADD_WIDTH-1:0]  tcdm_tx_add_i,
  input  logic [TCDM_OPC_WIDTH-1:0]  tcdm_tx_opc_i,
  input  logic [MCHAN_LEN_WIDTH-1:0] tcdm_tx_len_i,
  input  logic                       tcdm_tx_req_i,
  output logic                       tcdm_tx_gnt_o,
  
  // RX CMD INTERFACE
  //***************************************
  input  logic [TRANS_SID_WIDTH-1:0] tcdm_rx_sid_i,
  input  logic [TCDM_ADD_WIDTH-1:0]  tcdm_rx_add_i,
  input  logic [TCDM_OPC_WIDTH-1:0]  tcdm_rx_opc_i,
  input  logic [MCHAN_LEN_WIDTH-1:0] tcdm_rx_len_i,
  input  logic                       tcdm_rx_req_i,
  output logic                       tcdm_rx_gnt_o,
  
  // OUT SYNCHRONIZATION INTERFACE
  //***************************************
  output logic                       tx_synch_req_o,
  output logic [TRANS_SID_WIDTH-1:0] tx_synch_sid_o,
 
  output logic                       rx_synch_req_o,
  output logic [TRANS_SID_WIDTH-1:0] rx_synch_sid_o,
  
  // TX DATA INTERFACE
  //***************************************
  output logic [1:0][31:0]           tx_data_dat_o,
  output logic [1:0]                 tx_data_req_o,
  input  logic [1:0]                 tx_data_gnt_i,
  
  // RX DATA INTERFACE
  //***************************************
  input  logic [1:0][31:0]           rx_data_dat_i,
  input  logic [1:0][3:0]            rx_data_strb_i,
  output logic [1:0]                 rx_data_req_o,
  input  logic [1:0]                 rx_data_gnt_i 
);
   
  localparam int TCDM_CMD_QUEUE_WIDTH  = TCDM_OPC_WIDTH + MCHAN_LEN_WIDTH + TCDM_ADD_WIDTH + TRANS_SID_WIDTH;
  localparam int TCDM_BEAT_QUEUE_WIDTH = TCDM_OPC_WIDTH + TCDM_ADD_WIDTH + TRANS_SID_WIDTH + 1;
  
  logic [TRANS_SID_WIDTH-1:0]        s_tcdm_rx_sid;
  logic [TRANS_SID_WIDTH-1:0]        s_tcdm_tx_sid;
  logic [TCDM_ADD_WIDTH-1:0]         s_tcdm_rx_add;
  logic [TCDM_ADD_WIDTH-1:0]         s_tcdm_tx_add;
  logic [TCDM_OPC_WIDTH-1:0]         s_tcdm_rx_opc;
  logic [TCDM_OPC_WIDTH-1:0]         s_tcdm_tx_opc;
  logic [MCHAN_LEN_WIDTH-1:0]        s_tcdm_rx_len;
  logic [MCHAN_LEN_WIDTH-1:0]        s_tcdm_tx_len;
  logic                              s_tcdm_rx_req;
  logic                              s_tcdm_tx_req;
  logic                              s_tcdm_rx_gnt;
  logic                              s_tcdm_tx_gnt;
  logic                              s_tcdm_rx_full;
  logic                              s_tcdm_tx_full;
  logic                              s_tcdm_rx_empty;
  logic                              s_tcdm_tx_empty;
  
  logic [1:0][TCDM_ADD_WIDTH-1:0]    s_beat_tx_add;
  logic [1:0][TCDM_ADD_WIDTH-1:0]    s_beat_rx_add;
  logic [1:0][TCDM_ADD_WIDTH-1:0]    s_beat_tx_add_s;
  logic [1:0][TCDM_ADD_WIDTH-1:0]    s_beat_rx_add_s;
  logic [1:0][TCDM_OPC_WIDTH-1:0]    s_beat_tx_opc;
  logic [1:0][TCDM_OPC_WIDTH-1:0]    s_beat_rx_opc;
  logic [1:0][TCDM_OPC_WIDTH-1:0]    s_beat_tx_opc_s;
  logic [1:0][TCDM_OPC_WIDTH-1:0]    s_beat_rx_opc_s;
  logic [1:0][TRANS_SID_WIDTH-1:0]   s_beat_tx_sid;
  logic [1:0][TRANS_SID_WIDTH-1:0]   s_beat_rx_sid;
  logic [1:0][TRANS_SID_WIDTH-1:0]   s_beat_tx_sid_s;
  logic [1:0][TRANS_SID_WIDTH-1:0]   s_beat_rx_sid_s;
  logic [1:0]                        s_beat_tx_req;
  logic [1:0]                        s_beat_rx_req;
  logic [1:0]                        s_beat_tx_req_s;
  logic [1:0]                        s_beat_rx_req_s;
  logic [1:0]                        s_beat_tx_gnt;
  logic [1:0]                        s_beat_rx_gnt;
  logic [1:0]                        s_beat_tx_gnt_s;
  logic [1:0]                        s_beat_rx_gnt_s;
  logic [1:0]                        s_beat_tx_eop;
  logic [1:0]                        s_beat_rx_eop;
  logic [1:0]                        s_beat_tx_eop_s;
  logic [1:0]                        s_beat_rx_eop_s;
  logic [1:0]                        s_beat_tx_full;
  logic [1:0]                        s_beat_rx_full;
  logic [1:0]                        s_beat_tx_empty;
  logic [1:0]                        s_beat_rx_empty;
  
  logic [1:0]                        s_tx_synch_req;
  logic [1:0]                        s_rx_synch_req;
  logic [1:0][TRANS_SID_WIDTH-1:0]   s_tx_synch_sid;
  logic [1:0][TRANS_SID_WIDTH-1:0]   s_rx_synch_sid;
  
  genvar             i;
  
  //**********************************************************
  //*************** TCDM TX COMMAND QUEUE ********************
  //**********************************************************
   
  assign tcdm_tx_gnt_o = ~s_tcdm_tx_full;
  assign s_tcdm_tx_req = ~s_tcdm_tx_empty; 

  fifo_v3 #(
    .FALL_THROUGH (1'b0),
    .DATA_WIDTH   (TCDM_CMD_QUEUE_WIDTH),
    .DEPTH        (2)
  ) tcdm_tx_cmd_queue_i (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),
    .flush_i      (1'b0),
    .unpush_i     (1'b0),
    .testmode_i   (scan_ckgt_enable_i),
    // status flags
    .full_o       (s_tcdm_tx_full),
    .empty_o      (s_tcdm_tx_empty),
    .usage_o      (/* Not Used */),
    // as long as the queue is not full we can push new data
    .data_i       ({tcdm_tx_opc_i,tcdm_tx_len_i,tcdm_tx_add_i,tcdm_tx_sid_i}),
    .push_i       (tcdm_tx_req_i),
    // as long as the queue is not empty we can pop new elements
    .data_o       ({s_tcdm_tx_opc,s_tcdm_tx_len,s_tcdm_tx_add,s_tcdm_tx_sid}),
    .pop_i        (s_tcdm_tx_gnt)
  );
   
  //**********************************************************
  //*************** TCDM RX COMMAND QUEUE ********************
  //**********************************************************
   
  assign tcdm_rx_gnt_o = ~s_tcdm_rx_full;
  assign s_tcdm_rx_req = ~s_tcdm_rx_empty; 

  fifo_v3 #(
    .FALL_THROUGH (1'b0),
    .DATA_WIDTH   (TCDM_CMD_QUEUE_WIDTH),
    .DEPTH        (2)
  ) tcdm_rx_cmd_queue_i (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),
    .flush_i      (1'b0),
    .unpush_i     (1'b0),
    .testmode_i   (scan_ckgt_enable_i),
    // status flags
    .full_o       (s_tcdm_rx_full),
    .empty_o      (s_tcdm_rx_empty),
    .usage_o      (/* Not Used */),
    // as long as the queue is not full we can push new data
    .data_i       ({tcdm_rx_opc_i,tcdm_rx_len_i,tcdm_rx_add_i,tcdm_rx_sid_i}),
    .push_i       (tcdm_rx_req_i),
    // as long as the queue is not empty we can pop new elements
    .data_o       ({s_tcdm_rx_opc,s_tcdm_rx_len,s_tcdm_rx_add,s_tcdm_rx_sid}),
    .pop_i        (s_tcdm_rx_gnt)
  );
   
  //**********************************************************
  //*************** TCDM CMD UNPACK TX ***********************
  //**********************************************************
  
  tcdm_cmd_unpack 
  #(
    .TRANS_SID_WIDTH(TRANS_SID_WIDTH),
    .TCDM_ADD_WIDTH(TCDM_ADD_WIDTH),
    .TCDM_OPC_WIDTH(TCDM_OPC_WIDTH),
    .MCHAN_LEN_WIDTH(MCHAN_LEN_WIDTH)
  )
  tcdm_tx_cmd_unpack_i
  (   
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    
    .cmd_sid_i(s_tcdm_tx_sid),
    .cmd_opc_i(s_tcdm_tx_opc),
    .cmd_len_i(s_tcdm_tx_len),
    .cmd_add_i(s_tcdm_tx_add),
    .cmd_req_i(s_tcdm_tx_req),
    .cmd_gnt_o(s_tcdm_tx_gnt),
    
    .beat_sid_o(s_beat_tx_sid),
    .beat_add_o(s_beat_tx_add),
    .beat_opc_o(s_beat_tx_opc),
    .beat_eop_o(s_beat_tx_eop),
    .beat_req_o(s_beat_tx_req),
    .beat_gnt_i(s_beat_tx_gnt)
  );
  
  //**********************************************************
  //*************** TCDM CMD UNPACK RX ***********************
  //**********************************************************
   
  tcdm_cmd_unpack 
  #(
    .TRANS_SID_WIDTH(TRANS_SID_WIDTH),
    .TCDM_ADD_WIDTH(TCDM_ADD_WIDTH),
    .TCDM_OPC_WIDTH(TCDM_OPC_WIDTH),
    .MCHAN_LEN_WIDTH(MCHAN_LEN_WIDTH)
  )
  tcdm_rx_cmd_unpack_i
  (   
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    
    .cmd_sid_i(s_tcdm_rx_sid),
    .cmd_opc_i(s_tcdm_rx_opc),
    .cmd_len_i(s_tcdm_rx_len),
    .cmd_add_i(s_tcdm_rx_add),
    .cmd_req_i(s_tcdm_rx_req),
    .cmd_gnt_o(s_tcdm_rx_gnt),
    
    .beat_sid_o(s_beat_rx_sid),
    .beat_add_o(s_beat_rx_add),
    .beat_opc_o(s_beat_rx_opc),
    .beat_eop_o(s_beat_rx_eop),
    .beat_req_o(s_beat_rx_req),
    .beat_gnt_i(s_beat_rx_gnt)   
  );
  
  //**********************************************************
  //*************** TCDM BEAT QUEUE TX ***********************
  //**********************************************************
  
  generate     
    for (i=0; i<2; i++) begin : g_beat_queue_tx

      assign s_beat_tx_gnt[i]   = ~s_beat_tx_full[i];
      assign s_beat_tx_req_s[i] = ~s_beat_tx_empty[i]; 

      fifo_v3 #(
        .FALL_THROUGH (1'b0),
        .DATA_WIDTH   (TCDM_BEAT_QUEUE_WIDTH),
        .DEPTH        (2)
      ) tcdm_beat_queue_tx_i (
        .clk_i        (clk_i),
        .rst_ni       (rst_ni),
        .flush_i      (1'b0),
        .unpush_i     (1'b0),
        .testmode_i   (scan_ckgt_enable_i),
        // status flags
        .full_o       (s_beat_tx_full[i]),
        .empty_o      (s_beat_tx_empty[i]),
        .usage_o      (/* Not Used */),
        // as long as the queue is not full we can push new data
        .data_i       ({s_beat_tx_sid[i],s_beat_tx_eop[i],s_beat_tx_opc[i],s_beat_tx_add[i]}),
        .push_i       (s_beat_tx_req[i]),
        // as long as the queue is not empty we can pop new elements
        .data_o       ({s_beat_tx_sid_s[i],s_beat_tx_eop_s[i],s_beat_tx_opc_s[i],s_beat_tx_add_s[i]}),
        .pop_i        (s_beat_tx_gnt_s[i])
      );
    end
  endgenerate
  
  //**********************************************************
  //*************** TCDM BEAT QUEUE RX ***********************
  //**********************************************************
  
  generate
    for (i=0; i<2; i++) begin : g_beat_queue_rx    

      assign s_beat_rx_gnt[i]   = ~s_beat_rx_full[i];
      assign s_beat_rx_req_s[i] = ~s_beat_rx_empty[i]; 

      fifo_v3 #(
        .FALL_THROUGH (1'b0),
        .DATA_WIDTH   (TCDM_BEAT_QUEUE_WIDTH),
        .DEPTH        (2)
      ) tcdm_beat_queue_rx_i (
        .clk_i        (clk_i),
        .rst_ni       (rst_ni),
        .flush_i      (1'b0),
        .unpush_i     (1'b0),
        .testmode_i   (scan_ckgt_enable_i),
        // status flags
        .full_o       (s_beat_rx_full[i]),
        .empty_o      (s_beat_rx_empty[i]),
        .usage_o      (/* Not Used */),
        // as long as the queue is not full we can push new data
        .data_i       ({s_beat_rx_sid[i],s_beat_rx_eop[i],s_beat_rx_opc[i],s_beat_rx_add[i]}),
        .push_i       (s_beat_rx_req[i]),
        // as long as the queue is not empty we can pop new elements
        .data_o       ({s_beat_rx_sid_s[i],s_beat_rx_eop_s[i],s_beat_rx_opc_s[i],s_beat_rx_add_s[i]}),
        .pop_i        (s_beat_rx_gnt_s[i])
      );
    end     
  endgenerate
  
  //**********************************************************
  //*************** TCDM INTERFACE TX ************************
  //**********************************************************
  
  generate 
    for (i=0; i<2; i++) begin : g_tcdm_if_tx    
      tcdm_tx_if
      #(
        .TRANS_SID_WIDTH(TRANS_SID_WIDTH),
        .TCDM_ADD_WIDTH(TCDM_ADD_WIDTH)
      )
      tcdm_if_tx_i
      (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .scan_ckgt_enable_i(scan_ckgt_enable_i),
        
        .beat_sid_i(s_beat_tx_sid_s[i]),
        .beat_eop_i(s_beat_tx_eop_s[i]),
        .beat_add_i(s_beat_tx_add_s[i]),
        .beat_we_n_i(s_beat_tx_opc_s[i][0]),
        .beat_req_i(s_beat_tx_req_s[i]),
        .beat_gnt_o(s_beat_tx_gnt_s[i]),
        
        .synch_req_o(s_tx_synch_req[i]),
        .synch_sid_o(s_tx_synch_sid[i]),
        
        .tx_data_dat_o(tx_data_dat_o[i]),
        .tx_data_req_o(tx_data_req_o[i]),
        .tx_data_gnt_i(tx_data_gnt_i[i]),
        
        .tcdm_req_o(tcdm_req_o[i]),
        .tcdm_add_o(tcdm_add_o[i]),
        .tcdm_we_n_o(tcdm_we_n_o[i]),
        .tcdm_wdata_o(tcdm_wdata_o[i]),
        .tcdm_sid_o(tcdm_sid_o[i]),
        .tcdm_be_o(tcdm_be_o[i]),
        .tcdm_gnt_i(tcdm_gnt_i[i]),
        
        .tcdm_r_rdata_i(tcdm_r_rdata_i[i]),
        .tcdm_r_valid_i(tcdm_r_valid_i[i])     
      );
    end 
  endgenerate
  
  //**********************************************************
  //*************** TCDM INTERFACE RX ************************
  //**********************************************************
  
  generate
    for (i=0; i<2; i++) begin : g_tcdm_if_rx    
      tcdm_rx_if
      #(
        .TRANS_SID_WIDTH(TRANS_SID_WIDTH),
        .TCDM_ADD_WIDTH(TCDM_ADD_WIDTH)
      )
      tcdm_if_rx_i
      (
        .clk_i          ( clk_i),
        .rst_ni         ( rst_ni),
        
        .beat_sid_i     ( s_beat_rx_sid_s [i]   ),
        .beat_eop_i     ( s_beat_rx_eop_s [i]   ),
        .beat_add_i     ( s_beat_rx_add_s [i]   ),
        .beat_we_n_i    ( s_beat_rx_opc_s [i][0]),
        .beat_req_i     ( s_beat_rx_req_s [i]   ),
        .beat_gnt_o     ( s_beat_rx_gnt_s [i]   ),
        
        .synch_req_o    ( s_rx_synch_req  [i]   ),
        .synch_sid_o    ( s_rx_synch_sid  [i]   ),
        
        .rx_data_dat_i  ( rx_data_dat_i   [i]   ),
        .rx_data_strb_i ( rx_data_strb_i  [i]   ),
        .rx_data_req_o  ( rx_data_req_o   [i]   ),
        .rx_data_gnt_i  ( rx_data_gnt_i   [i]   ),
        
        .tcdm_req_o     ( tcdm_req_o      [i+2] ),
        .tcdm_add_o     ( tcdm_add_o      [i+2] ),
        .tcdm_we_n_o    ( tcdm_we_n_o     [i+2] ),
        .tcdm_wdata_o   ( tcdm_wdata_o    [i+2] ),
        .tcdm_sid_o     ( tcdm_sid_o      [i+2] ),
        .tcdm_be_o      ( tcdm_be_o       [i+2] ),
        .tcdm_gnt_i     ( tcdm_gnt_i      [i+2] ),
        
        .tcdm_r_rdata_i ( tcdm_r_rdata_i  [i+2] ),
        .tcdm_r_valid_i ( tcdm_r_valid_i  [i+2] )         
      );     
    end     
  endgenerate
   
  //**********************************************************
  //*************** TCDM SYNCH TX ****************************
  //**********************************************************
  
  tcdm_synch
  #(
    .TRANS_SID_WIDTH(TRANS_SID_WIDTH)
  )
  tcdm_synch_tx_i
  (    
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .scan_ckgt_enable_i(scan_ckgt_enable_i),
    
    .synch_req_i(s_tx_synch_req),
    .synch_sid_i(s_tx_synch_sid),
    
    .synch_req_o(tx_synch_req_o),
    .synch_sid_o(tx_synch_sid_o)      
  );
  
  //**********************************************************
  //*************** TCDM SYNCH RX ****************************
  //**********************************************************
   
  tcdm_synch 
  #(
    .TRANS_SID_WIDTH(TRANS_SID_WIDTH)
  )
  tcdm_synch_rx_i
  (   
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    
    .scan_ckgt_enable_i(scan_ckgt_enable_i),
    .synch_req_i(s_rx_synch_req),
    .synch_sid_i(s_rx_synch_sid),
    
    .synch_req_o(rx_synch_req_o),
    .synch_sid_o(rx_synch_sid_o)   
  );
  
endmodule

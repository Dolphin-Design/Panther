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

module trans_buffers
#(
  parameter int TX_BUFFER_DEPTH = 2,
  parameter int RX_BUFFER_DEPTH = 2
)
(
  input  logic             clk_i,
  input  logic             rst_ni,
  input  logic             scan_ckgt_enable_i,
  // TCDM SIDE
  input  logic [1:0][31:0] tx_data_push_dat_i,
  input  logic [1:0]       tx_data_push_req_i,
  output logic [1:0]       tx_data_push_gnt_o,
  // TCDM SIDE
  output logic [1:0][31:0] rx_data_pop_dat_o,
  output logic [1:0][3:0]  rx_data_pop_strb_o,
  input  logic [1:0]       rx_data_pop_req_i,
  output logic [1:0]       rx_data_pop_gnt_o,
  // EXT SIDE
  output logic [63:0]      tx_data_pop_dat_o,
  input  logic             tx_data_pop_req_i,
  output logic             tx_data_pop_gnt_o,
  // EXT SIDE
  input  logic [63:0]      rx_data_push_dat_i,
  input  logic [7:0]       rx_data_push_strb_i,
  input  logic             rx_data_push_req_i,
  output logic             rx_data_push_gnt_o
);


  logic [1:0][31:0]         s_tx_data_pop_dat;
  logic [1:0]               s_tx_data_pop_req;
  logic [1:0]               s_tx_data_pop_gnt;
  logic [1:0]               s_tx_data_full;
  logic [1:0]               s_tx_data_empty;
  
  logic [1:0][31:0]         s_rx_data_push_dat;
  logic [1:0][3:0]          s_rx_data_push_strb;
  logic [1:0]               s_rx_data_push_req;
  logic [1:0]               s_rx_data_push_gnt;
  logic [1:0]               s_rx_data_full;
  logic [1:0]               s_rx_data_empty;
  
  genvar                  i;
  
  //**********************************************************
  //*************** TX BUFFER ********************************
  //**********************************************************
  
  generate
    for (i=0; i<2; i++) begin : g_tx_buffer
      assign tx_data_push_gnt_o[i]   = ~s_tx_data_full[i];
      assign s_tx_data_pop_gnt[i]    = ~s_tx_data_empty[i]; 

      fifo_v3 #(
        .FALL_THROUGH (1'b0),
        .DATA_WIDTH   (32),
        .DEPTH        (TX_BUFFER_DEPTH)
      ) tx_buffer_i (
        .clk_i        (clk_i),
        .rst_ni       (rst_ni),
        .flush_i      (1'b0),
        .unpush_i     (1'b0),
        .testmode_i   (scan_ckgt_enable_i),
        // status flags
        .full_o       (s_tx_data_full[i]),
        .empty_o      (s_tx_data_empty[i]),
        .usage_o      (/* Not Used */),
        // as long as the queue is not full we can push new data
        .data_i       (tx_data_push_dat_i[i]),
        .push_i       (tx_data_push_req_i[i]),
        // as long as the queue is not empty we can pop new elements
        .data_o       (s_tx_data_pop_dat[i]),
        .pop_i        (s_tx_data_pop_req[i])
      );
    end      
  endgenerate
   
   //**********************************************************
   //*************** RX BUFFER ********************************
   //**********************************************************
   
  generate
    for (i=0; i<2; i++) begin : g_rx_buffer
      assign s_rx_data_push_gnt[i]   = ~s_rx_data_full[i];
      assign rx_data_pop_gnt_o[i]    = ~s_rx_data_empty[i]; 

      fifo_v3 #(
        .FALL_THROUGH (1'b0),
        .DATA_WIDTH   (36),
        .DEPTH        (RX_BUFFER_DEPTH)
      ) rx_buffer_i (
        .clk_i        (clk_i),
        .rst_ni       (rst_ni),
        .flush_i      (1'b0),
        .unpush_i     (1'b0),
        .testmode_i   (scan_ckgt_enable_i),
        // status flags
        .full_o       (s_rx_data_full[i]),
        .empty_o      (s_rx_data_empty[i]),
        .usage_o      (/* Not Used */),
        // as long as the queue is not full we can push new data
        .data_i       ({s_rx_data_push_strb[i],s_rx_data_push_dat[i]}),
        .push_i       (s_rx_data_push_req[i]),
        // as long as the queue is not empty we can pop new elements
        .data_o       ({rx_data_pop_strb_o[i],rx_data_pop_dat_o[i]}),
        .pop_i        (rx_data_pop_req_i[i])
      );
    end      
  endgenerate
   
   assign tx_data_pop_gnt_o        = s_tx_data_pop_gnt[0] & s_tx_data_pop_gnt[1];
   assign rx_data_push_gnt_o       = s_rx_data_push_gnt[0] & s_rx_data_push_gnt[1];
   assign s_tx_data_pop_req[0]     = tx_data_pop_req_i & s_tx_data_pop_gnt[0] & s_tx_data_pop_gnt[1];
   assign s_tx_data_pop_req[1]     = tx_data_pop_req_i & s_tx_data_pop_gnt[0] & s_tx_data_pop_gnt[1];
   assign s_rx_data_push_req[0]    = rx_data_push_req_i & s_rx_data_push_gnt[0] & s_rx_data_push_gnt[1];
   assign s_rx_data_push_req[1]    = rx_data_push_req_i & s_rx_data_push_gnt[0] & s_rx_data_push_gnt[1];
   assign tx_data_pop_dat_o[31:0]  = s_tx_data_pop_dat[0];
   assign tx_data_pop_dat_o[63:32] = s_tx_data_pop_dat[1];
   assign s_rx_data_push_dat[0]    = rx_data_push_dat_i[31:0];
   assign s_rx_data_push_dat[1]    = rx_data_push_dat_i[63:32];
   assign s_rx_data_push_strb[0]   = rx_data_push_strb_i[3:0];
   assign s_rx_data_push_strb[1]   = rx_data_push_strb_i[7:4];
   
endmodule

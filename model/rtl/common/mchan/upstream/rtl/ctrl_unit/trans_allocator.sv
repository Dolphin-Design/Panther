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

module trans_allocator
#(
  parameter int NB_CTRLS           = 1,
  parameter int NB_TRANSFERS       = 1,
  parameter int TRANS_SID_WIDTH    = 1,
  parameter int TRANS_CID_WIDTH    = 1
)
(
  input  logic                                     clk_i,
  input  logic                                     rst_ni,
  
  // REQUEST ENTRY
  input  logic [NB_CTRLS-1:0]                      trans_req_i,
  output logic [NB_CTRLS-1:0]                      trans_gnt_o,
  output logic [NB_CTRLS-1:0][TRANS_SID_WIDTH-1:0] trans_sid_o,
  // CELEAR TABLE
  input  logic [NB_CTRLS-1:0][NB_TRANSFERS-1:0]    trans_sid_i,
  
  output logic [NB_CTRLS-1:0][NB_TRANSFERS-1:0]    trans_status_o,
  
  input  logic                                     cmd_req_i,
  input  logic                                     cmd_gnt_i,
  input  logic [TRANS_SID_WIDTH-1:0]               cmd_sid_i,
  input  logic [TRANS_CID_WIDTH-1:0]               cmd_cid_i,
  input  logic                                     cmd_ele_i,
  input  logic                                     cmd_ile_i,
  input  logic                                     cmd_ble_i,
  
  input  logic [NB_TRANSFERS-1:0]                  term_sig_i,
  output logic [NB_CTRLS-1:0]                      term_evt_o,
  output logic [NB_CTRLS-1:0]                      term_int_o
);
 
  logic                                            s_trans_req_arb;
  logic                                            s_trans_gnt_arb;
  logic [TRANS_CID_WIDTH-1:0]                      s_trans_cid_arb;
  
  logic [NB_TRANSFERS-1:0]                         s_busy;
  logic [TRANS_SID_WIDTH-1:0]                      s_trans_sid;
  logic [NB_TRANSFERS-1:0]                         s_clear_sid;
  
  logic [NB_TRANSFERS-1:0][TRANS_CID_WIDTH-1:0]    s_cid;
  logic [NB_TRANSFERS-1:0][TRANS_CID_WIDTH-1:0]    s_cid_buf;
  logic [NB_TRANSFERS-1:0]                         s_ele;
  logic [NB_TRANSFERS-1:0]                         s_ele_buf;
  logic [NB_TRANSFERS-1:0]                         s_ile;
  logic [NB_TRANSFERS-1:0]                         s_ile_buf;
  logic [NB_TRANSFERS-1:0]                         s_ble;
  logic [NB_TRANSFERS-1:0]                         s_ble_buf;
  
  logic [TRANS_SID_WIDTH-1:0]                      s_term_id_buf;
  logic [NB_TRANSFERS-1:0]                         s_term_sig_buf;
  logic [NB_TRANSFERS-1:0]                         s_term_sig_ser;
  
  logic [NB_TRANSFERS-1:0][NB_CTRLS-1:0]           s_term_int;
  logic [NB_TRANSFERS-1:0][NB_CTRLS-1:0]           s_term_evt;
  
  integer                                          s_loop1;
  integer                                          s_loop2;
  integer                                          s_loop3;
  integer                                          s_loop5;
  integer                                          s_loop6;
  integer                                          s_loop7;
  integer                                          s_loop8;
  integer                                          s_loop9;
  integer                                          s_loop10;
  integer                                          s_loop11;
  integer                                          s_loop12;
  genvar                                           i;
  genvar                                           j;
  
  logic [(2**(TRANS_CID_WIDTH))-1:0]               s_trans_req;
  logic [(2**(TRANS_CID_WIDTH))-1:0]               s_trans_gnt;
 
  //**********************************************************
  //*** TRANSACTION ARBITER **********************************
  //**********************************************************
  generate
    for (i=0; i<NB_CTRLS; i++) begin : g_reg_inputs
      assign s_trans_req[i] = trans_req_i[i];
      assign trans_gnt_o[i] = s_trans_gnt[i];
    end
  endgenerate
  
  generate
    for (i = NB_CTRLS; i<2**(TRANS_CID_WIDTH); i++) begin : g_reset
      assign s_trans_req[i] = '0;
    end
  endgenerate
  
  mchan_arbiter
  #(
    .DATA_WIDTH(0),
    .N_MASTER((2**(TRANS_CID_WIDTH))),
    .LOG_MASTER(TRANS_CID_WIDTH)
  )
  trans_manager_arbiter_i
  (
    .clk     ( clk_i       ),
    .rst_n   ( rst_ni      ),
    
    .data_i  ( '0          ),
    .req_i   ( s_trans_req ),
    .gnt_o   ( s_trans_gnt ),
    
    .req_o   ( s_trans_req_arb ),
    .gnt_i   ( s_trans_gnt_arb ),
    .id_o    ( s_trans_cid_arb ),
    .data_o  (                 )
  );
   
  //-**********************************************************
  //-*** GENERATE TRANSACTION ID ******************************
  //-**********************************************************
  
  // COMPUTE INTERNAL TRANS_ID
  always_comb begin : p_s_trans_sid
    s_trans_sid = '0;
    for (s_loop1 = NB_TRANSFERS-1 ; s_loop1 >= 0  ; s_loop1 = s_loop1 - 1) begin
      if (s_busy[s_loop1] == 1'b0) begin
        s_trans_sid = s_loop1;
      end
    end
  end
  
  // COMPUTE THE OUTPUT TRANS ID
  always_comb begin : p_trans_sid_o
    for (s_loop2 = 0 ; s_loop2 < NB_CTRLS ; s_loop2++ ) begin
      if ( &s_busy != 1'b1 ) begin // IF AT LEAST ONE ID IS AVAILABLE
        trans_sid_o[s_loop2] = s_trans_sid; // UPDATE THE ID
        s_trans_gnt_arb      = 1'b1;
      end else begin
        trans_sid_o[s_loop2] = '0; // OTHERWISE BLOCK REQUEST
        s_trans_gnt_arb      = 1'b0;
      end
    end
  end
   
  // MERGE TRANS SID COMING FROM CTRLS INTO A SINGLE VECTOR WITH OR REDUCTION
  always_comb begin : p_merge_sid
    for (s_loop11 = 0 ; s_loop11 < NB_TRANSFERS ; s_loop11++ ) begin
      s_clear_sid[s_loop11] = 0;
      for (s_loop12 = 0 ; s_loop12 < NB_CTRLS ; s_loop12++ ) begin
        s_clear_sid[s_loop11] = s_clear_sid[s_loop11] | trans_sid_i[s_loop12][s_loop11];
      end
    end
  end
  
  // UPDATE BUSY VECTOR
  generate
    for (i=0; i<NB_TRANSFERS; i++) begin : g_update_busy
      always_ff @(posedge clk_i or negedge rst_ni) begin : p_update_busy
        if (rst_ni == 1'b0) begin
          s_busy[i] <= 1'b0;
        end else begin
          if ( s_clear_sid[i] == 1'b1 ) begin
            s_busy[i] <= 1'b0;
          end else begin
            if ( ( s_trans_req_arb == 1'b1 ) && ( s_trans_gnt_arb == 1'b1 ) && ( trans_sid_o[s_trans_cid_arb] == i ) ) begin
              s_busy[i] <= 1'b1;
            end
          end
        end
      end
    end   
  endgenerate
   
  //-**********************************************************
  //-*** MEMORY WITH TERMINATION INFO FOR EACH TRANS SID ******
  //-**********************************************************
  
  always_ff @(posedge clk_i or negedge rst_ni) begin : p_mem_term
    if (rst_ni == 1'b0) begin
      for (s_loop3 = 0 ; s_loop3 <NB_TRANSFERS ; s_loop3 = s_loop3 + 1) begin
        s_cid[s_loop3] <= 0;
        s_ele[s_loop3] <= 0;
        s_ile[s_loop3] <= 0;
        s_ble[s_loop3] <= 0;
      end
    end else begin
      if ( ( cmd_req_i == 1'b1 ) && ( cmd_gnt_i == 1'b1 ) ) begin
        s_cid[cmd_sid_i] <= cmd_cid_i;
        s_ele[cmd_sid_i] <= cmd_ele_i;
        s_ile[cmd_sid_i] <= cmd_ile_i;
        s_ble[cmd_sid_i] <= cmd_ble_i;
      end
    end
  end
   
  //-**********************************************************
  //-*** BUFFER TERMINATION SIGNALS AND INFO ******************
  //-**********************************************************
  
  generate
    for ( i=0; i < NB_TRANSFERS; i++ ) begin : g_buf_term
      always_ff @(posedge clk_i or negedge rst_ni) begin : p_buf_term
        if (rst_ni == 1'b0) begin
          s_term_sig_buf[i] <= 1'b0;
          s_cid_buf[i]      <= '0;
          s_ele_buf[i]      <= 1'b0;
          s_ile_buf[i]      <= 1'b0;
          s_ble_buf[i]      <= 1'b0;
        end else begin
          if (term_sig_i[i] == 1'b1) begin // WHEN THE INPUT TERM SIGNAL ARRIVES FILL THE BUFFER
            s_term_sig_buf[i] <= 1'b1;
            s_cid_buf[i]      <= s_cid[i];
            s_ele_buf[i]      <= s_ele[i];
            s_ile_buf[i]      <= s_ile[i];
            s_ble_buf[i]      <= s_ble[i];
          end else begin
            if (s_term_sig_ser[i] == 1'b1) begin // WHEN THE TERM SIGNAL HAS BEEN DELIVERED CLEAR THE BUFFER
              s_term_sig_buf[i] <= 1'b0;
              s_cid_buf[i]      <= '0;
              s_ele_buf[i]      <= 1'b0;
              s_ile_buf[i]      <= 1'b0;
              s_ble_buf[i]      <= 1'b0;
            end
          end
        end
      end
    end
  endgenerate
   
  //-**********************************************************
  //-*** SERIALIZE BUFFERED TERMINATION SIGNALS ***************
  //-**********************************************************
  
  always_comb begin : p_ser_buf
    s_term_sig_ser = '0;
    s_term_id_buf  = '0;
    for ( s_loop5=0; s_loop5 < NB_TRANSFERS; s_loop5++ ) begin
      if ( s_term_sig_buf[s_loop5] == 1'b1 ) begin
           s_term_id_buf = s_loop5;
      end
    end
    for ( s_loop6=0; s_loop6 < NB_TRANSFERS; s_loop6++ ) begin
      if ( s_term_id_buf == s_loop6 ) begin
           s_term_sig_ser[s_loop6] = 1'b1;
      end
    end
  end
  
  //-**********************************************************
  //-*** GENERATE EVENT AND INTERRUPT SIGNALS *****************
  //-**********************************************************
   
  always_comb begin : p_evt_int
    s_term_int = '0;
    s_term_evt = '0;
    term_int_o = '0;
    term_evt_o = '0;
    for ( s_loop7=0; s_loop7 < NB_TRANSFERS; s_loop7++ ) begin
      for ( s_loop8=0; s_loop8 < NB_CTRLS; s_loop8++ ) begin
        if ( s_term_sig_ser[s_loop7] == 1'b1 ) begin // TERMINATION SIGNAL
          if ( ( s_ble_buf[s_loop7] == 1'b1 )  ) begin // BROADCAST ENABLED
            if ( s_ile_buf[s_loop7] == 1'b1 ) begin // INTERRUPT LINES ENABLED
              s_term_int[s_loop7][s_loop8] = 1'b1;
            end
            if ( s_ele_buf[s_loop7] == 1'b1 ) begin // EVENT LINES ENABLED
              s_term_evt[s_loop7][s_loop8] = 1'b1;
            end
          end else begin // BROADCAST NOT ENABLED
            if ( ( s_ile_buf[s_loop7] == 1'b1 ) && ( s_cid_buf[s_loop7] == s_loop8 ) ) begin // INTERRUPT LINES ENABLED
              s_term_int[s_loop7][s_loop8] = 1'b1;
            end
            if ( ( s_ele_buf[s_loop7] == 1'b1 )  && ( s_cid_buf[s_loop7] == s_loop8 ) ) begin // EVENT LINES ENABLED
              s_term_evt[s_loop7][s_loop8] = 1'b1;
            end
          end
        end
      end
    end
    
    for ( s_loop9=0; s_loop9 < NB_CTRLS; s_loop9++ ) begin
      for ( s_loop10=0; s_loop10 < NB_TRANSFERS; s_loop10++ ) begin
        if ( s_term_int[s_loop10][s_loop9] == 1'b1 ) begin
          term_int_o[s_loop9] = 1'b1;
        end
        if ( s_term_evt[s_loop10][s_loop9] == 1'b1 ) begin
          term_evt_o[s_loop9] = 1'b1;
        end
      end
    end
  end
  
  //-**********************************************************
  //-*** GENERATE TRANS STATUS ********************************
  //-**********************************************************
  
  generate
    for (i = 0; i< NB_CTRLS; i++) begin : g_trans_status
      for (j = 0; j<NB_TRANSFERS; j++) begin
        assign trans_status_o[i][j] = s_busy[j];
      end
    end 
  endgenerate
   
endmodule

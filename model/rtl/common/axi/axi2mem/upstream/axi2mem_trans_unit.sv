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

module axi2mem_trans_unit
#(
    parameter LD_BUFFER_SIZE = 2,
    parameter ST_BUFFER_SIZE = 2
)
(
    input  logic             clk_i,
    input  logic             rst_ni,
    input  logic             test_en_i,

    // TCDM SIDE
    input  logic [1:0][31:0] rd_data_push_dat_i,
    input  logic [1:0]       rd_data_push_req_i,
    output logic [1:0]       rd_data_push_gnt_o,
    input  logic [5:0]       rd_data_push_id_i,
    input  logic             rd_data_push_last_i,

    // EXT SIDE
    output logic [63:0]      rd_data_pop_dat_o,
    input  logic             rd_data_pop_req_i,
    output logic             rd_data_pop_gnt_o,
    output logic [5:0]       rd_data_pop_id_o,
    output logic             rd_data_pop_last_o,

    // EXT SIDE
    input  logic [63:0]      wr_data_push_dat_i,
    input  logic [7:0]       wr_data_push_strb_i,
    input  logic             wr_data_push_req_i,
    output logic             wr_data_push_gnt_o,

    // TCDM SIDE
    output logic [1:0][31:0] wr_data_pop_dat_o,
    output logic [1:0][3:0]  wr_data_pop_strb_o,
    input  logic [1:0]       wr_data_pop_req_i,
    output logic [1:0]       wr_data_pop_gnt_o
);

   logic [1:0][31:0]         s_rd_data_pop_dat;
   logic [1:0]               s_rd_data_pop_req;
   logic [1:0]               s_rd_data_pop_gnt;
   logic [1:0]               s_rd_data_full;
   logic [1:0]               s_rd_data_empty;

   logic [1:0][31:0]         s_wr_data_push_dat;
   logic [1:0][3:0]          s_wr_data_push_strb;
   logic [1:0]               s_wr_data_push_req;
   logic [1:0]               s_wr_data_push_gnt;
   logic [1:0]               s_wr_data_full;
   logic [1:0]               s_wr_data_empty;

   logic                     s_rd_last_pop_req;
   logic                     s_rd_last_pop_gnt;
   logic                     s_rd_last_empty;
   genvar                    i;

   //**********************************************************
   //*************** RD LAST BUFFER ***************************
   //**********************************************************

   assign s_rd_last_pop_gnt = ~s_rd_last_empty;

   fifo_v3 #(
     .FALL_THROUGH ( 1'b0 ),
     .DATA_WIDTH   ( 1 ),
     .DEPTH        ( LD_BUFFER_SIZE )
   ) last_buffer_i (
     .clk_i        ( clk_i ),
     .rst_ni       ( rst_ni ),
     .flush_i      ( 1'b0 ),
     .unpush_i     ( 1'b0 ),
     .testmode_i   ( test_en_i ),
     // status flags
     .full_o       ( /* Not Used */  ),
     .empty_o      ( s_rd_last_empty ),
     .usage_o      ( /* Not Used */  ), 
     // as long as the queue is not full we can push new data
     .data_i       ( rd_data_push_last_i ),
     .push_i       ( rd_data_push_req_i[0] ),
     // as long as the queue is not empty we can pop new elements
     .data_o       ( rd_data_pop_last_o ),
     .pop_i        ( s_rd_last_pop_req ) 
   );

   //**********************************************************
   //*************** RD BUFFER ********************************
   //**********************************************************

   generate

      for (i=0; i<2; i++)
      begin : rd_buffer
        assign rd_data_push_gnt_o[i] = ~s_rd_data_full[i];
        assign s_rd_data_pop_gnt[i]  = ~s_rd_data_empty[i];

        fifo_v3 #(
          .FALL_THROUGH ( 1'b0 ),
          .DATA_WIDTH   ( 32 ),
          .DEPTH        ( LD_BUFFER_SIZE )
        ) rd_buffer_i (
          .clk_i        ( clk_i     ),
          .rst_ni       ( rst_ni    ),
          .flush_i      ( 1'b0      ),
          .unpush_i     ( 1'b0      ),
          .testmode_i   ( test_en_i ),
          // status flags
          .full_o       ( s_rd_data_full[i]  ),
          .empty_o      ( s_rd_data_empty[i] ),
          .usage_o      ( /* Not Used */     ), 
          // as long as the queue is not full we can push new data
          .data_i       ( rd_data_push_dat_i[i] ),
          .push_i       ( rd_data_push_req_i[i] ),
          // as long as the queue is not empty we can pop new elements
          .data_o       ( s_rd_data_pop_dat[i] ),
          .pop_i        ( s_rd_data_pop_req[i] ) 
        );
      end

   endgenerate

   //**********************************************************
   //*************** WR BUFFER ********************************
   //**********************************************************

   generate

      for (i=0; i<2; i++)
      begin : wr_buffer
        assign s_wr_data_push_gnt[i] = ~s_wr_data_full[i];
        assign wr_data_pop_gnt_o[i]  = ~s_wr_data_empty[i];

        fifo_v3 #(
          .FALL_THROUGH ( 1'b0 ),
          .DATA_WIDTH   ( 36 ),
          .DEPTH        ( ST_BUFFER_SIZE )
        ) wr_buffer_i (
          .clk_i        ( clk_i     ),
          .rst_ni       ( rst_ni    ),
          .flush_i      ( 1'b0      ),
          .unpush_i     ( 1'b0      ),
          .testmode_i   ( test_en_i ),
          // status flags
          .full_o       ( s_wr_data_full[i]  ),
          .empty_o      ( s_wr_data_empty[i] ),
          .usage_o      ( /* Not Used */     ), 
          // as long as the queue is not full we can push new data
          .data_i       ( {s_wr_data_push_strb[i],s_wr_data_push_dat[i]} ),
          .push_i       ( s_wr_data_push_req[i] ),
          // as long as the queue is not empty we can pop new elements
          .data_o       ( {wr_data_pop_strb_o[i],wr_data_pop_dat_o[i]} ),
          .pop_i        ( wr_data_pop_req_i[i] ) 
        );
      end

   endgenerate

   // REAL SIGNALS
   assign rd_data_pop_gnt_o        = s_rd_data_pop_gnt[0] & s_rd_data_pop_gnt[1] & s_rd_last_pop_gnt;
   assign wr_data_push_gnt_o       = s_wr_data_push_gnt[0] & s_wr_data_push_gnt[1];
   assign s_rd_data_pop_req[0]     = rd_data_pop_req_i;
   assign s_rd_data_pop_req[1]     = rd_data_pop_req_i;
   assign s_rd_last_pop_req        = rd_data_pop_req_i;
   assign s_wr_data_push_req[0]    = wr_data_push_req_i;
   assign s_wr_data_push_req[1]    = wr_data_push_req_i;
   assign rd_data_pop_dat_o[31:0]  = s_rd_data_pop_dat[0];
   assign rd_data_pop_dat_o[63:32] = s_rd_data_pop_dat[1];
   assign s_wr_data_push_dat[0]    = wr_data_push_dat_i[31:0];
   assign s_wr_data_push_dat[1]    = wr_data_push_dat_i[63:32];
   assign s_wr_data_push_strb[0]   = wr_data_push_strb_i[3:0];
   assign s_wr_data_push_strb[1]   = wr_data_push_strb_i[7:4];

endmodule

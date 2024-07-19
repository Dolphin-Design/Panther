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

module axi2mem_tcdm_synch
(
   input  logic            clk_i,
   input  logic            rst_ni,
   input  logic            test_en_i,

   input  logic [1:0]      synch_req_i,
   input  logic [1:0][5:0] synch_id_i,

   input  logic            synch_gnt_i,
   output logic            synch_req_o,
   output logic [5:0]      synch_id_o
);

   logic [1:0]             s_synch_req;
   logic                   s_synch_gnt;
   logic [1:0][5:0]        s_synch_id;
   logic [1:0]             s_synch_empty;

   genvar  i;
   generate
      for (i=0; i<2; i++)
      begin : synch
        assign s_synch_req[i] = ~s_synch_empty[i];

        fifo_v3 #(
          .FALL_THROUGH ( 1'b0 ),
          .DATA_WIDTH   ( 6 ),
          .DEPTH        ( 4 ) // IMPORTANT: DATA DEPTH MUST BE THE SAME AS CMD QUEUE DATA DEPTH
        ) synch_i (
          .clk_i        ( clk_i     ),
          .rst_ni       ( rst_ni    ),
          .flush_i      ( 1'b0      ),
          .unpush_i     ( 1'b0      ),
          .testmode_i   ( test_en_i ),
          // status flags
          .full_o       ( /* Not Used */   ),
          .empty_o      ( s_synch_empty[i] ),
          .usage_o      ( /* Not Used */   ), 
          // as long as the queue is not full we can push new data
          .data_i       ( synch_id_i[i]  ),
          .push_i       ( synch_req_i[i] ),
          // as long as the queue is not empty we can pop new elements
          .data_o       ( s_synch_id[i] ),
          .pop_i        ( s_synch_gnt && synch_gnt_i ) 
        );   
      end
   endgenerate



   assign s_synch_gnt = s_synch_req[0] & s_synch_req[1];

   assign synch_req_o = s_synch_gnt;
   assign synch_id_o  = s_synch_id[0];

endmodule

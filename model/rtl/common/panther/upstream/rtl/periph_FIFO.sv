// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

/*
 * periph_FIFO.sv
 * Davide Rossi <davide.rossi@unibo.it>
 * Antonio Pullini <pullinia@iis.ee.ethz.ch>
 * Igor Loi <igor.loi@unibo.it>
 * Francesco Conti <fconti@iis.ee.ethz.ch>
 */

module periph_FIFO
#(
  parameter ADDR_WIDTH=32,
  parameter DATA_WIDTH=32,
  parameter BYTE_ENABLE_BIT=DATA_WIDTH/8
)
(
  input  logic                         clk_i,
  input  logic                         rst_ni,
  input  logic                         test_en_i,

  //Input SIde REQ
  input  logic                         data_req_i,
  input  logic [ADDR_WIDTH - 1:0]      data_add_i,
  input  logic                         data_we_n_i,
  input  logic [DATA_WIDTH - 1:0]      data_wdata_i,
  input  logic [BYTE_ENABLE_BIT - 1:0] data_be_i,
  output logic                         data_gnt_o,

  //Output side REQ
  output logic                         data_req_o,
  output logic [ADDR_WIDTH - 1:0]      data_add_o,
  output logic                         data_we_n_o,
  output logic [DATA_WIDTH - 1:0]      data_wdata_o,
  output logic [BYTE_ENABLE_BIT - 1:0] data_be_o,
  input logic                          data_gnt_i,

  //Input SIde RESP
  input logic                          data_r_valid_i,
  input logic                          data_r_opc_i,
  input logic [DATA_WIDTH - 1:0]       data_r_rdata_i,

  //Output SIde RESP
  output logic                         data_r_valid_o,
  output logic                         data_r_opc_o,
  output logic [DATA_WIDTH - 1:0]      data_r_rdata_o
);

  localparam FIFO_DW = ADDR_WIDTH + 1 + DATA_WIDTH + BYTE_ENABLE_BIT;

  logic fifo_full;
  logic fifo_empty;
  logic [FIFO_DW-1:0] DATA_IN;
  logic [FIFO_DW-1:0] DATA_OUT;
  
  assign data_gnt_o = ~fifo_full;
  assign data_req_o = ~fifo_empty;
  assign DATA_IN  = { data_add_i, data_we_n_i, data_wdata_i, data_be_i };
  assign            { data_add_o, data_we_n_o, data_wdata_o, data_be_o } = DATA_OUT;

  //generic_fifo #( 
  //  .DATA_WIDTH ( FIFO_DW ),
  //  .DATA_DEPTH ( 2       )
  //) FIFO_REQ (
  //  .clk          ( clk_i      ),
  //  .rst_n        ( rst_ni     ),
  //  .test_mode_i  ( test_en_i  ),
  //  .data_i       ( DATA_IN    ),
  //  .valid_i      ( data_req_i ),
  //  .grant_o      ( data_gnt_o ),
  //  .unpush_elem_i( 1'b0       ),
  //  .data_o       ( DATA_OUT   ),
  //  .valid_o      ( data_req_o ),
  //  .grant_i      ( data_gnt_i )
  //);

  fifo_v3 #( 
    .FALL_THROUGH ( 1'b0       ),
    .DATA_WIDTH   ( FIFO_DW    ),
    .DEPTH        ( 2          )
  ) FIFO_REQ ( 
    .clk_i        ( clk_i      ),      
    .rst_ni       ( rst_ni     ),
    .flush_i      ( 1'b0       ),    
    .unpush_i     ( 1'b0       ),   
    .testmode_i   ( test_en_i  ), 
    .full_o       ( fifo_full  ),
    .empty_o      ( fifo_empty ),
    .usage_o      (            ), // was not used in generic_fifo
    .data_i       ( DATA_IN    ),   
    .push_i       ( data_req_i ),    
    .data_o       ( DATA_OUT   ),    
    .pop_i        ( data_gnt_i )
  );

  assign data_r_valid_o = data_r_valid_i;
  assign data_r_opc_o   = data_r_opc_i;
  assign data_r_rdata_o = data_r_rdata_i;

endmodule

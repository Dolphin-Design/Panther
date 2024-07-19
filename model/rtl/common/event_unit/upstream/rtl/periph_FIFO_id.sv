/*
 * Copyright (C) 2013-2017 ETH Zurich, University of Bologna
 * All rights reserved.
 *
 * This code is under development and not yet released to the public.
 * Until it is released, the code is under the copyright of ETH Zurich and
 * the University of Bologna, and may contain confidential and/or unpublished 
 * work. Any reuse/redistribution is strictly forbidden without written
 * permission from ETH Zurich.
 *
 * Bug fixes and contributions will eventually be released under the
 * SolderPad open hardware license in the context of the PULP platform
 * (http://www.pulp-platform.org), under the copyright of ETH Zurich and the
 * University of Bologna.
 */
 
module periph_FIFO_id
#(
    parameter int ADDR_WIDTH=32,
    parameter int DATA_WIDTH=32,
    parameter int ID_WIDTH=8,
    parameter int BYTE_ENABLE_BIT=DATA_WIDTH/8
)
(
    input  logic			 clk_i,
    input  logic			 rst_ni,
    input  logic             scan_ckgt_enable_i,

    //Input SIde REQ
    input  logic 			 data_req_i,
    input  logic [ADDR_WIDTH - 1:0] 	 data_add_i,
    input  logic 			 data_we_n_i,
    input  logic [DATA_WIDTH - 1:0] 	 data_wdata_i,
    input  logic [BYTE_ENABLE_BIT - 1:0] data_be_i,
    input  logic [ID_WIDTH - 1:0] data_id_i,
    output logic 			 data_gnt_o,

    //Output side REQ
    output logic 			 data_req_o,
    output logic [ADDR_WIDTH - 1:0] 	 data_add_o,
    output logic 			 data_we_n_o,
    output logic [DATA_WIDTH - 1:0] 	 data_wdata_o,
    output logic [BYTE_ENABLE_BIT - 1:0] data_be_o,
    output logic [ID_WIDTH - 1:0] data_id_o,
    input logic 			 data_gnt_i,

    //Input SIde RESP
    input logic 			 data_r_valid_i,
    input logic 			 data_r_opc_i,
    input logic [ID_WIDTH - 1:0] data_r_id_i,
    input logic [DATA_WIDTH - 1:0] 	 data_r_rdata_i,

    //Output SIde RESP
    output logic 			 data_r_valid_o,
    output logic 			 data_r_opc_o,
    output logic [ID_WIDTH - 1:0] data_r_id_o,
    output logic [DATA_WIDTH - 1:0] 	 data_r_rdata_o
);

localparam FIFO_DW = ADDR_WIDTH + 1 + DATA_WIDTH + ID_WIDTH + BYTE_ENABLE_BIT;

logic [FIFO_DW-1:0]	DATA_IN;
logic [FIFO_DW-1:0]	DATA_OUT;
logic               s_full;
logic               s_empty;

assign DATA_IN  = { data_add_i, data_we_n_i, data_wdata_i, data_id_i, data_be_i };
assign            { data_add_o, data_we_n_o, data_wdata_o, data_id_o, data_be_o } = DATA_OUT;
assign data_req_o = ~ s_empty ;
assign data_gnt_o = ~ s_full ;

  fifo_v3 #(
    .FALL_THROUGH (1'b0), // fifo is in fall-through mode
    .DATA_WIDTH   (FIFO_DW), // default data width if the fifo is of type logic
    .DEPTH        (2) // depth can be arbitrary from 0 to 2**32
  ) FIFO_REQ (
    .clk_i         (clk_i),               // Clock
    .rst_ni        (rst_ni),              // Asynchronous reset active low
    .flush_i       (1'b0),                // flush the queue
    .unpush_i      (1'b0),                // unpush one element
    .testmode_i    (scan_ckgt_enable_i),  // test_mode to bypass clock gating
    // status flags
    .full_o  (s_full),                    // queue is full
    .empty_o (s_empty),                   // queue is empty
    .usage_o (/* Not Used */),            // fill pointer
    // as long as the queue is not full we can push new data
    .data_i (DATA_IN),                    // data to push into the queue
    .push_i (data_req_i),                 // data is valid and can be pushed to the queue
    // as long as the queue is not empty we can pop new elements
    .data_o (DATA_OUT),                  // output data
    .pop_i  (data_gnt_i)                 // pop head from queue
  );


// response channel is forwarded (no FIFO)
assign data_r_valid_o = data_r_valid_i;
assign data_r_opc_o   = data_r_opc_i;
assign data_r_id_o    = data_r_id_i;
assign data_r_rdata_o = data_r_rdata_i;



endmodule

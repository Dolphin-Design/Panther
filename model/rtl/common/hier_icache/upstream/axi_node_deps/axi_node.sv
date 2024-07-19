// Copyright 2014-2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// ============================================================================= //
// Company:        Multitherman Laboratory @ DEIS - University of Bologna        //
//                    Viale Risorgimento 2 40136                                 //
//                    Bologna - fax 0512093785 -                                 //
//                                                                               //
// Engineer:       Igor Loi - igor.loi@unibo.it                                  //
//                                                                               //
//                                                                               //
// Additional contributions by:                                                  //
//                                                                               //
//                                                                               //
//                                                                               //
// Create Date:    01/02/2014                                                    //
// Design Name:    AXI 4 INTERCONNECT                                            //
// Module Name:    axi_node                                                      //
// Project Name:   PULP                                                          //
// Language:       SystemVerilog                                                 //
//                                                                               //
// Description:    Axi Node wrapper with exploded ports (Verilog style)          //
//                                                                               //
// Revision:                                                                     //
// Revision v0.1 - 01/02/2014 : File Created                                     //
//                                                                               //
//                                                                               //
//                                                                               //
//                                                                               //
//                                                                               //
//                                                                               //
// ============================================================================= //

module axi_node #(
   parameter int                   AXI_ADDRESS_W      = 32,
   parameter int                   AXI_DATA_W         = 64,
   parameter int                   AXI_NUMBYTES       = AXI_DATA_W/8,
   parameter int                   AXI_USER_W         = 6,
   parameter int                   N_MASTER_PORT      = 8,
   parameter int                   N_SLAVE_PORT       = 4,
   parameter int                   AXI_ID_IN          = 16,
   parameter int                   AXI_ID_OUT         = AXI_ID_IN + $clog2(N_SLAVE_PORT),
   parameter int                   FIFO_DEPTH_DW      = 8,
   parameter int                   N_REGION           = 2
)(
   input logic                                                           clk,
   input logic                                                           rst_n,
   input logic                                                           test_en_i,
   // ---------------------------------------------------------------
   // AXI TARG Port Declarations -----------------------------------------
   // ---------------------------------------------------------------
   //AXI write address bus -------------- // USED// --------------
   input  logic [N_SLAVE_PORT-1:0][AXI_ID_IN-1:0]                        slave_awid_i,   //
   input  logic [N_SLAVE_PORT-1:0][AXI_ADDRESS_W-1:0]                    slave_awaddr_i, //
   input  logic [N_SLAVE_PORT-1:0][ 7:0]                                 slave_awlen_i,          //burst length is 1 + (0 - 15)
   input  logic [N_SLAVE_PORT-1:0][ 2:0]                                 slave_awsize_i,         //size of each transfer in burst
   input  logic [N_SLAVE_PORT-1:0][ 1:0]                                 slave_awburst_i,        //for bursts>1, accept only incr burst=01
   input  logic [N_SLAVE_PORT-1:0]                                       slave_awlock_i,         //only normal access supported axs_awlock=00
   input  logic [N_SLAVE_PORT-1:0][ 3:0]                                 slave_awcache_i,        //
   input  logic [N_SLAVE_PORT-1:0][ 2:0]                                 slave_awprot_i, //
   input  logic [N_SLAVE_PORT-1:0][ 3:0]                                 slave_awregion_i,       //
   input  logic [N_SLAVE_PORT-1:0][ AXI_USER_W-1:0]                      slave_awuser_i, //
   input  logic [N_SLAVE_PORT-1:0][ 3:0]                                 slave_awqos_i,  //
   input  logic [N_SLAVE_PORT-1:0]                                       slave_awvalid_i,        //master addr valid
   output logic [N_SLAVE_PORT-1:0]                                       slave_awready_o,        //slave ready to accept
   //AXI write data bus -------------- // USED// --------------
   input  logic [N_SLAVE_PORT-1:0] [AXI_DATA_W-1:0]                      slave_wdata_i,
   input  logic [N_SLAVE_PORT-1:0] [AXI_NUMBYTES-1:0]                    slave_wstrb_i,   //1 strobe per byte
   input  logic [N_SLAVE_PORT-1:0]                                       slave_wlast_i,   //last transfer in burst
   input  logic [N_SLAVE_PORT-1:0][AXI_USER_W-1:0]                       slave_wuser_i,   // User sideband signal
   input  logic [N_SLAVE_PORT-1:0]                                       slave_wvalid_i,  //master data valid
   output logic [N_SLAVE_PORT-1:0]                                       slave_wready_o,  //slave ready to accept
   //AXI write response bus -------------- // USED// --------------
   output  logic [N_SLAVE_PORT-1:0]  [AXI_ID_IN-1:0]                     slave_bid_o,
   output  logic [N_SLAVE_PORT-1:0]  [ 1:0]                              slave_bresp_o,
   output  logic [N_SLAVE_PORT-1:0]                                      slave_bvalid_o,
   output  logic [N_SLAVE_PORT-1:0]  [AXI_USER_W-1:0]                    slave_buser_o,   // User sideband signal
   input   logic [N_SLAVE_PORT-1:0]                                      slave_bready_i,
   //AXI read address bus -------------------------------------------
   input  logic [N_SLAVE_PORT-1:0][AXI_ID_IN-1:0]                        slave_arid_i,
   input  logic [N_SLAVE_PORT-1:0][AXI_ADDRESS_W-1:0]                    slave_araddr_i,
   input  logic [N_SLAVE_PORT-1:0][ 7:0]                                 slave_arlen_i,   //burst length - 1 to 16
   input  logic [N_SLAVE_PORT-1:0][ 2:0]                                 slave_arsize_i,  //size of each transfer in burst
   input  logic [N_SLAVE_PORT-1:0][ 1:0]                                 slave_arburst_i, //for bursts>1, accept only incr burst=01
   input  logic [N_SLAVE_PORT-1:0]                                       slave_arlock_i,  //only normal access supported axs_awlock=00
   input  logic [N_SLAVE_PORT-1:0][ 3:0]                                 slave_arcache_i,
   input  logic [N_SLAVE_PORT-1:0][ 2:0]                                 slave_arprot_i,
   input  logic [N_SLAVE_PORT-1:0][ 3:0]                                 slave_arregion_i,       //
   input  logic [N_SLAVE_PORT-1:0][ AXI_USER_W-1:0]                      slave_aruser_i, //
   input  logic [N_SLAVE_PORT-1:0][ 3:0]                                 slave_arqos_i,  //
   input  logic [N_SLAVE_PORT-1:0]                                       slave_arvalid_i, //master addr valid
   output logic [N_SLAVE_PORT-1:0]                                       slave_arready_o, //slave ready to accept
   //AXI read data bus ----------------------------------------------
   output logic [N_SLAVE_PORT-1:0][AXI_ID_IN-1:0]                        slave_rid_o,
   output logic [N_SLAVE_PORT-1:0][AXI_DATA_W-1:0]                       slave_rdata_o,
   output logic [N_SLAVE_PORT-1:0][ 1:0]                                 slave_rresp_o,
   output logic [N_SLAVE_PORT-1:0]                                       slave_rlast_o,   //last transfer in burst
   output logic [N_SLAVE_PORT-1:0][AXI_USER_W-1:0]                       slave_ruser_o,   //last transfer in burst
   output logic [N_SLAVE_PORT-1:0]                                       slave_rvalid_o,  //slave data valid
   input  logic [N_SLAVE_PORT-1:0]                                       slave_rready_i,   //master ready to accept
   // ---------------------------------------------------------------
   // AXI INIT Port Declarations -----------------------------------------
   // ---------------------------------------------------------------
   //AXI write address bus -------------- // // --------------
   output logic [N_MASTER_PORT-1:0][AXI_ID_OUT-1:0]                      master_awid_o,  //
   output logic [N_MASTER_PORT-1:0][AXI_ADDRESS_W-1:0]                   master_awaddr_o,        //
   output logic [N_MASTER_PORT-1:0][ 7:0]                                master_awlen_o,         //burst length is 1 + (0 - 15)
   output logic [N_MASTER_PORT-1:0][ 2:0]                                master_awsize_o,        //size of each transfer in burst
   output logic [N_MASTER_PORT-1:0][ 1:0]                                master_awburst_o,       //for bursts>1, accept only incr burst=01
   output logic [N_MASTER_PORT-1:0]                                      master_awlock_o,        //only normal access supported axs_awlock=00
   output logic [N_MASTER_PORT-1:0][ 3:0]                                master_awcache_o,       //
   output logic [N_MASTER_PORT-1:0][ 2:0]                                master_awprot_o,        //
   output logic [N_MASTER_PORT-1:0][ 3:0]                                master_awregion_o,      //
   output logic [N_MASTER_PORT-1:0][ AXI_USER_W-1:0]                     master_awuser_o,        //
   output logic [N_MASTER_PORT-1:0][ 3:0]                                master_awqos_o, //
   output logic [N_MASTER_PORT-1:0]                                      master_awvalid_o,       //master addr valid
   input  logic [N_MASTER_PORT-1:0]                                      master_awready_i,       //slave ready to accept
   // ---------------------------------------------------------------

   //AXI write data bus -------------- // // --------------
   output logic [N_MASTER_PORT-1:0] [AXI_DATA_W-1:0]                     master_wdata_o,
   output logic [N_MASTER_PORT-1:0] [AXI_NUMBYTES-1:0]                   master_wstrb_o,   //1 strobe per byte
   output logic [N_MASTER_PORT-1:0]                                      master_wlast_o,   //last transfer in burst
   output logic [N_MASTER_PORT-1:0] [ AXI_USER_W-1:0]                    master_wuser_o,   //user sideband signals
   output logic [N_MASTER_PORT-1:0]                                      master_wvalid_o,  //master data valid
   input  logic [N_MASTER_PORT-1:0]                                      master_wready_i,  //slave ready to accept
   // ---------------------------------------------------------------

   //AXI BACKWARD write response bus -------------- // // --------------
   input  logic [N_MASTER_PORT-1:0] [AXI_ID_OUT-1:0]                     master_bid_i,
   input  logic [N_MASTER_PORT-1:0] [ 1:0]                               master_bresp_i,
   input  logic [N_MASTER_PORT-1:0] [ AXI_USER_W-1:0]                    master_buser_i,
   input  logic [N_MASTER_PORT-1:0]                                      master_bvalid_i,
   output logic [N_MASTER_PORT-1:0]                                      master_bready_o,
   // ---------------------------------------------------------------

   //AXI read address bus -------------------------------------------
   output  logic [N_MASTER_PORT-1:0][AXI_ID_OUT-1:0]                     master_arid_o,
   output  logic [N_MASTER_PORT-1:0][AXI_ADDRESS_W-1:0]                  master_araddr_o,
   output  logic [N_MASTER_PORT-1:0][ 7:0]                               master_arlen_o,   //burst length - 1 to 16
   output  logic [N_MASTER_PORT-1:0][ 2:0]                               master_arsize_o,  //size of each transfer in burst
   output  logic [N_MASTER_PORT-1:0][ 1:0]                               master_arburst_o, //for bursts>1, accept only incr burst=01
   output  logic [N_MASTER_PORT-1:0]                                     master_arlock_o,  //only normal access supported axs_awlock=00
   output  logic [N_MASTER_PORT-1:0][ 3:0]                               master_arcache_o,
   output  logic [N_MASTER_PORT-1:0][ 2:0]                               master_arprot_o,
   output  logic [N_MASTER_PORT-1:0][ 3:0]                               master_arregion_o,      //
   output  logic [N_MASTER_PORT-1:0][ AXI_USER_W-1:0]                    master_aruser_o,        //
   output  logic [N_MASTER_PORT-1:0][ 3:0]                               master_arqos_o, //
   output  logic [N_MASTER_PORT-1:0]                                     master_arvalid_o, //master addr valid
   input logic [N_MASTER_PORT-1:0]                                       master_arready_i, //slave ready to accept
   // ---------------------------------------------------------------

   //AXI BACKWARD read data bus ----------------------------------------------
   input  logic [N_MASTER_PORT-1:0][AXI_ID_OUT-1:0]                      master_rid_i,
   input  logic [N_MASTER_PORT-1:0][AXI_DATA_W-1:0]                      master_rdata_i,
   input  logic [N_MASTER_PORT-1:0][ 1:0]                                master_rresp_i,
   input  logic [N_MASTER_PORT-1:0]                                      master_rlast_i,   //last transfer in burst
   input  logic [N_MASTER_PORT-1:0][ AXI_USER_W-1:0]                     master_ruser_i,
   input  logic [N_MASTER_PORT-1:0]                                      master_rvalid_i,  //slave data valid
   output logic [N_MASTER_PORT-1:0]                                      master_rready_o,   //master ready to accept

   //Initial Memory map
   input  logic [N_REGION-1:0][N_MASTER_PORT-1:0][AXI_ADDRESS_W-1:0]     cfg_START_ADDR_i,
   input  logic [N_REGION-1:0][N_MASTER_PORT-1:0][AXI_ADDRESS_W-1:0]     cfg_END_ADDR_i,
   input  logic [N_REGION-1:0][N_MASTER_PORT-1:0]                        cfg_valid_rule_i,
   input  logic [N_SLAVE_PORT-1:0][N_MASTER_PORT-1:0]                    cfg_connectivity_map_i
);

genvar i,j,k;

logic  [N_SLAVE_PORT-1:0][N_MASTER_PORT-1:0]                    arvalid_int;
logic  [N_MASTER_PORT-1:0][N_SLAVE_PORT-1:0]                    arready_int;
logic  [N_MASTER_PORT-1:0][N_SLAVE_PORT-1:0]                    arvalid_int_reverse;
logic  [N_SLAVE_PORT-1:0][N_MASTER_PORT-1:0]                    arready_int_reverse;


logic  [N_SLAVE_PORT-1:0][N_MASTER_PORT-1:0]                    awvalid_int;
logic  [N_MASTER_PORT-1:0][N_SLAVE_PORT-1:0]                    awready_int;
logic  [N_MASTER_PORT-1:0][N_SLAVE_PORT-1:0]                    awvalid_int_reverse;
logic  [N_SLAVE_PORT-1:0][N_MASTER_PORT-1:0]                    awready_int_reverse;


logic  [N_SLAVE_PORT-1:0][N_MASTER_PORT-1:0]                    wvalid_int;
logic  [N_MASTER_PORT-1:0][N_SLAVE_PORT-1:0]                    wready_int;
logic  [N_MASTER_PORT-1:0][N_SLAVE_PORT-1:0]                    wvalid_int_reverse;
logic  [N_SLAVE_PORT-1:0][N_MASTER_PORT-1:0]                    wready_int_reverse;


logic [N_MASTER_PORT-1:0][N_SLAVE_PORT-1:0]                     bvalid_int;
logic [N_SLAVE_PORT-1:0][N_MASTER_PORT-1:0]                     bready_int;
logic [N_SLAVE_PORT-1:0][N_MASTER_PORT-1:0]                     bvalid_int_reverse;
logic [N_MASTER_PORT-1:0][N_SLAVE_PORT-1:0]                     bready_int_reverse;


logic [N_MASTER_PORT-1:0][N_SLAVE_PORT-1:0]                     rvalid_int;
logic [N_SLAVE_PORT-1:0][N_MASTER_PORT-1:0]                     rready_int;
logic [N_SLAVE_PORT-1:0][N_MASTER_PORT-1:0]                     rvalid_int_reverse;
logic [N_MASTER_PORT-1:0][N_SLAVE_PORT-1:0]                     rready_int_reverse;




logic [N_REGION-1:0][N_MASTER_PORT-1:0][AXI_ADDRESS_W-1:0]      START_ADDR;
logic [N_REGION-1:0][N_MASTER_PORT-1:0][AXI_ADDRESS_W-1:0]      END_ADDR;
logic [N_REGION-1:0][N_MASTER_PORT-1:0]                         valid_rule;
logic [N_SLAVE_PORT-1:0][N_MASTER_PORT-1:0]                     connectivity_map;


generate

// 2D REQ AND GRANT MATRIX REVERSING (TRANSPOSE)
for(i=0;i<N_MASTER_PORT;i++)
begin : g_reversing_valid_ready_master
    for(j=0;j<N_SLAVE_PORT;j++)
    begin : g_reversing_valid_ready_slave
      assign arvalid_int_reverse[i][j] = arvalid_int[j][i];
      assign awvalid_int_reverse[i][j] = awvalid_int[j][i];
      assign wvalid_int_reverse[i][j]  = wvalid_int[j][i];
      assign bvalid_int_reverse[j][i]  = bvalid_int[i][j];
      assign rvalid_int_reverse[j][i]  = rvalid_int[i][j];


      assign arready_int_reverse[j][i] = arready_int[i][j];
      assign awready_int_reverse[j][i] = awready_int[i][j];
      assign wready_int_reverse[j][i]  = wready_int[i][j];
      assign bready_int_reverse[i][j]  = bready_int[j][i];
      assign rready_int_reverse[i][j]  = rready_int[j][i];
    end
end


for(i=0; i<N_MASTER_PORT; i++)
begin : g_req_block_gen

   axi_request_block
   #(
       .AXI_ADDRESS_W  (  AXI_ADDRESS_W   ),
       .AXI_DATA_W     (  AXI_DATA_W      ),
       .AXI_USER_W     (  AXI_USER_W      ),
       .N_INIT_PORT    (  N_MASTER_PORT   ),
       .N_TARG_PORT    (  N_SLAVE_PORT    ),
       .FIFO_DW_DEPTH  (  FIFO_DEPTH_DW   ),
       .AXI_ID_IN      (  AXI_ID_IN       )
   )
   REQ_BLOCK
   (
     .clk         (   clk                   ),
     .rst_n       (   rst_n                 ),
     .test_en_i   (   test_en_i             ),
     // -----------------------------------------------------------------------------------//
     //                           INTERNAL (N_TARGET PORT )                                //
     // -----------------------------------------------------------------------------------//
     //AXI write address bus --------------------------------------------------------------//
     .awid_i      (  slave_awid_i           ), //
     .awaddr_i    (  slave_awaddr_i         ), //
     .awlen_i     (  slave_awlen_i          ), //burst length is 1 + (0 - 15)
     .awsize_i    (  slave_awsize_i         ), //size of each transfer in burst
     .awburst_i   (  slave_awburst_i        ), //for bursts>1,  accept only incr burst=01
     .awlock_i    (  slave_awlock_i         ), //only normal access supported axs_awlock=00
     .awcache_i   (  slave_awcache_i        ), //
     .awprot_i    (  slave_awprot_i         ), //
     .awregion_i  (  slave_awregion_i       ), //
     .awuser_i    (  slave_awuser_i         ), //
     .awqos_i     (  slave_awqos_i          ), //
     .awvalid_i   (  awvalid_int_reverse[i] ), //master addr valid
     .awready_o   (  awready_int[i]         ), //slave ready to accept
     //AXI write data bus -----------------------------------------------------------------//
     .wdata_i    (  slave_wdata_i           ),
     .wstrb_i    (  slave_wstrb_i           ), //1 strobe per byte
     .wlast_i    (  slave_wlast_i           ), //last transfer in burst
     .wuser_i    (  slave_wuser_i           ),
     .wvalid_i   (  wvalid_int_reverse[i]   ), //master data valid
     .wready_o   (  wready_int[i]           ), //slave ready to accept
     //AXI read address bus ---------------------------------------------------------------//
     .arid_i     (  slave_arid_i            ),
     .araddr_i   (  slave_araddr_i          ),
     .arlen_i    (  slave_arlen_i           ), //burst length - 1 to 16
     .arsize_i   (  slave_arsize_i          ), //size of each transfer in burst
     .arburst_i  (  slave_arburst_i         ), //for bursts>1,  accept only incr burst=01
     .arlock_i   (  slave_arlock_i          ), //only normal access supported axs_awlock=00
     .arcache_i  (  slave_arcache_i         ),
     .arprot_i   (  slave_arprot_i          ),
     .arregion_i (  slave_arregion_i        ), //
     .aruser_i   (  slave_aruser_i          ), //
     .arqos_i    (  slave_arqos_i           ), //
     .arvalid_i  (  arvalid_int_reverse[i]  ), //master addr valid
     .arready_o  (  arready_int[i]          ), //slave ready to accept
     // ------------------------------------------------------------------------------------//
     //                           SLAVE SIDE (ONE PORT ONLY)                                //
     // ------------------------------------------------------------------------------------//
     //AXI BACKWARD write response bus -----------------------------------------------------//
     .bid_i      (  master_bid_i[i]         ),
     .bvalid_i   (  master_bvalid_i[i]      ),
     .bready_o   (  master_bready_o[i]      ),
     // To BW ALLOC --> FROM BW DECODER
     .bvalid_o   (  bvalid_int[i]           ),
     .bready_i   (  bready_int_reverse[i]   ),
     //AXI BACKWARD read data bus ----------------------------------------------------------//
     .rid_i     (  master_rid_i[i]          ),
     .rvalid_i  (  master_rvalid_i[i]       ),   //slave data valid
     .rready_o  (  master_rready_o[i]       ),   //master ready to accept
     // To BR ALLOC --> FROM BW DECODER
     .rvalid_o  (  rvalid_int[i]            ),
     .rready_i  (  rready_int_reverse[i]    ),
     //AXI write address bus --------------------------------------------------------------//
     .awid_o    (  master_awid_o[i]         ), //
     .awaddr_o  (  master_awaddr_o[i]       ), //
     .awlen_o   (  master_awlen_o[i]        ), //burst length is 1 + (0 - 15)
     .awsize_o  (  master_awsize_o[i]       ), //size of each transfer in burst
     .awburst_o (  master_awburst_o[i]      ), //for bursts>1,  accept only incr burst=01
     .awlock_o  (  master_awlock_o[i]       ), //only normal access supported axs_awlock=00
     .awcache_o (  master_awcache_o[i]      ), //
     .awprot_o  (  master_awprot_o[i]       ), //
     .awregion_o(  master_awregion_o[i]     ), //
     .awuser_o  (  master_awuser_o[i]       ), //
     .awqos_o   (  master_awqos_o[i]        ), //
     .awvalid_o (  master_awvalid_o[i]      ), //master addr valid
     .awready_i (  master_awready_i[i]      ), //slave ready to accept
     //AXI write data bus -----------------------------------------------------------------//
     .wdata_o  (  master_wdata_o[i]         ),
     .wstrb_o  (  master_wstrb_o[i]         ), //1 strobe per byte
     .wlast_o  (  master_wlast_o[i]         ), //last transfer in burst
     .wuser_o  (  master_wuser_o[i]         ),
     .wvalid_o (  master_wvalid_o[i]        ), //master data valid
     .wready_i (  master_wready_i[i]        ), //slave ready to accept
     //AXI read address bus ---------------------------------------------------------------//
     .arid_o    (  master_arid_o[i]         ),
     .araddr_o  (  master_araddr_o[i]       ),
     .arlen_o   (  master_arlen_o[i]        ), //burst length - 1 to 16
     .arsize_o  (  master_arsize_o[i]       ), //size of each transfer in burst
     .arburst_o (  master_arburst_o[i]      ), //for bursts>1,  accept only incr burst=01
     .arlock_o  (  master_arlock_o[i]       ), //only normal access supported axs_awlock=00
     .arcache_o (  master_arcache_o[i]      ),
     .arprot_o  (  master_arprot_o[i]       ),
     .arregion_o(  master_arregion_o[i]     ), //
     .aruser_o  (  master_aruser_o[i]       ), //
     .arqos_o   (  master_arqos_o[i]        ), //
     .arvalid_o (  master_arvalid_o[i]      ), //master addr valid
     .arready_i (  master_arready_i[i]      )  //slave ready to accept
     // -----------------------------------------------------------------------------------//
   );
end

for (i = 0; i < N_SLAVE_PORT; i++) begin : g_resp_block_gen
axi_response_block
#(
    .AXI_ADDRESS_W  (AXI_ADDRESS_W ),
    .AXI_DATA_W     (AXI_DATA_W    ),
    .AXI_USER_W     (AXI_USER_W    ),

    .N_INIT_PORT    (N_MASTER_PORT ),
    .N_TARG_PORT    (N_SLAVE_PORT  ),
    .FIFO_DEPTH_DW  (FIFO_DEPTH_DW ),

    .AXI_ID_IN      (AXI_ID_IN     ),
    .N_REGION       (N_REGION      )
)
RESP_BLOCK
(
   .clk                (  clk                     ),
   .rst_n              (  rst_n                   ),
   .test_en_i          (  test_en_i               ),

   //AXI BACKWARD read data bus ----------------------------------------------
   .rid_i              (  master_rid_i            ),
   .rdata_i            (  master_rdata_i          ),
   .rresp_i            (  master_rresp_i          ),
   .rlast_i            (  master_rlast_i          ),    //last transfer in burst
   .ruser_i            (  master_ruser_i          ),    //last transfer in burst
   .rvalid_i           (  rvalid_int_reverse[i]   ),    //slave data valid
   .rready_o           (  rready_int[i]           ),    //master ready to accept

   //AXI BACKWARD WRITE data bus ----------------------------------------------
   .bid_i              (  master_bid_i            ),
   .bresp_i            (  master_bresp_i          ),
   .buser_i            (  master_buser_i          ),    //last transfer in burst
   .bvalid_i           (  bvalid_int_reverse[i]   ),    //slave data valid
   .bready_o           (  bready_int[i]           ),    //master ready to accept



   //AXI BACKWARD read data bus ----------------------------------------------
   .rid_o              (  slave_rid_o[i]          ),
   .rdata_o            (  slave_rdata_o[i]        ),
   .rresp_o            (  slave_rresp_o[i]        ),
   .rlast_o            (  slave_rlast_o[i]        ),    //last transfer in burst
   .ruser_o            (  slave_ruser_o[i]        ),
   .rvalid_o           (  slave_rvalid_o[i]       ),    //slave data valid
   .rready_i           (  slave_rready_i[i]       ),    //master ready to accept

   //AXI BACKWARD WRITE data bus ----------------------------------------------
   .bid_o              (  slave_bid_o[i]          ),
   .bresp_o            (  slave_bresp_o[i]        ),
   .buser_o            (  slave_buser_o[i]        ),    //last transfer in burst
   .bvalid_o           (  slave_bvalid_o[i]       ),    //slave data valid
   .bready_i           (  slave_bready_i[i]       ),    //master ready to accept



   // ADDRESS READ DECODER
   .arvalid_i          (  slave_arvalid_i[i]      ),
   .araddr_i           (  slave_araddr_i[i]       ),
   .arready_o          (  slave_arready_o[i]      ),
   .arlen_i            (  slave_arlen_i[i]        ),
   .aruser_i           (  slave_aruser_i[i]       ),
   .arid_i             (  slave_arid_i[i]         ),

   .arvalid_o          (  arvalid_int[i]          ),
   .arready_i          (  arready_int_reverse[i]  ),


   // ADDRESS WRITE DECODER
   .awvalid_i          (  slave_awvalid_i[i]      ),
   .awaddr_i           (  slave_awaddr_i[i]       ),
   .awready_o          (  slave_awready_o[i]      ),

   .awuser_i           (  slave_awuser_i[i]       ),
   .awid_i             (  slave_awid_i[i]         ),

   .awvalid_o          (  awvalid_int[i]          ),
   .awready_i          (  awready_int_reverse[i]  ),

   // DATA WRITE DECODER
   .wvalid_i           (  slave_wvalid_i[i]       ),
   .wlast_i            (  slave_wlast_i[i]        ),
   .wready_o           (  slave_wready_o[i]       ),

   .wvalid_o           (  wvalid_int[i]           ),
   .wready_i           (  wready_int_reverse[i]   ),


   // FROM CFG REGS
   .START_ADDR_i       ( START_ADDR               ),
   .END_ADDR_i         ( END_ADDR                 ),
   .enable_region_i    ( valid_rule               ),
   .connectivity_map_i ( connectivity_map[i]      )
);
end
endgenerate

assign START_ADDR       = cfg_START_ADDR_i;
assign END_ADDR         = cfg_END_ADDR_i;
assign connectivity_map = cfg_connectivity_map_i;

generate
  for (i = 0; i < N_REGION; i++) begin : g_valid_rule_region
    for (j = 0; j < N_MASTER_PORT; j++) begin : g_valid_rule_master
      assign valid_rule[i][j] = cfg_valid_rule_i[i][j];
    end
  end
endgenerate

endmodule
